--- Stack sizing, safe attachment and slot placement around the Edit Mode anchor.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:GetModule("Layout")
local Internal = Layout.Internal
local defaults = Internal.defaults
local getFrame, isViewerKey = Internal.GetFrame, Internal.IsViewerKey
local Safe = RanothsCooldownManager:GetModule("Safe")
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Printer = RanothsCooldownManager:GetModule("Printer")

local function slotHeight(profile, key, frame)
    if isViewerKey(key) then
        if not frame or not frame:IsShown() then return 0 end
        local icons = RanothsCooldownManager:GetModule("IconLayout", true)
        local trackers = RanothsCooldownManager:GetModule("CustomTrackers", true)
        return math.max(frame:GetHeight(), (icons and icons:GetContentHeight(key)) or 0,
            (trackers and trackers.db and trackers:GetReservedHeight(key)) or 0)
    end
    -- Blizzard may not have a frame for the bar at all (e.g. no resource for this spec), which counts as hidden
    local entry = profile.stack[key]
    if entry.collapse and not (frame and frame:IsShown()) then return 0 end
    return entry.height
end

--- True if `frame` is anchored, directly or through other frames, to `target`.
local function dependsOn(frame, target, seen)
    seen = seen or {}
    if seen[frame] then return false end
    seen[frame] = true
    for i = 1, frame:GetNumPoints() do
        local _, relativeTo = frame:GetPoint(i)
        if relativeTo and (relativeTo == target or dependsOn(relativeTo, target, seen)) then
            return true
        end
    end
    return false
end

--- Attach a Blizzard frame to its slot. The anchor viewer is never touched.
--- Anchors are only cleared once the new anchor is known to be valid, so a failure cannot leave the frame unpositioned.
local function anchoredTo(frame, index, point, slot)
    local p, relative, relativePoint, x, y = frame:GetPoint(index)
    if issecretvalue(p) or issecretvalue(relativePoint) or issecretvalue(x) or issecretvalue(y) then return false end
    return p == point and relative == slot and relativePoint == point and x == 0 and y == 0
end

local function attach(profile, key, frame, slot)
    if key == profile.anchorKey then return end
    -- Re-anchoring an unchanged frame makes the client resolve its layout again for nothing.
    local count = frame:GetNumPoints()
    if isViewerKey(key) then
        if count == 1 and anchoredTo(frame, 1, "TOP", slot) then return end
    elseif count == 2 and anchoredTo(frame, 1, "TOPLEFT", slot) and anchoredTo(frame, 2, "BOTTOMRIGHT", slot) then
        return
    end
    local previous = {}
    for i = 1, count do
        previous[i] = { frame:GetPoint(i) }
    end

    Safe.ClearAllPoints(frame)
    local ok
    if isViewerKey(key) then
        ok = pcall(Safe.SetPoint, frame, "TOP", slot, "TOP")
    else
        ok = pcall(Safe.SetPoint, frame, "TOPLEFT", slot, "TOPLEFT")
            and pcall(Safe.SetPoint, frame, "BOTTOMRIGHT", slot, "BOTTOMRIGHT")
    end
    if not ok then
        Safe.ClearAllPoints(frame)
        for _, p in ipairs(previous) do
            pcall(Safe.SetPoint, frame, unpack(p, 1, 5))
        end
    end
end

--- Position one slot relative to `prev`. Collapsed slots take no space and no gap.
--- @return Frame prev The slot the next entry should chain to
--- @return number used Height plus gap consumed by this entry
local function placeSlot(self, key, prev, above, width)
    local profile = self.db.profile
    local frame = getFrame(key)
    local left = false -- true when the frame is left to Edit Mode

    -- Anchoring a frame to the stack would be circular if the anchor viewer already depends on it
    -- (e.g. Edit Mode anchors Essential to it). Leave such frames to Edit Mode.
    local anchorFrame = Viewers:Get(profile.anchorKey)
    if frame and anchorFrame and key ~= profile.anchorKey and dependsOn(anchorFrame, frame) then
        self.skipped = self.skipped or {}
        if not self.skipped[key] then
            self.skipped[key] = true
            Printer:Print(key .. " is anchored to by the anchor viewer in Edit Mode, so it is left where Edit Mode puts it.")
        end
        frame = nil
        left = true
    end

    local slot = self:GetSlot(key)
    local height = left and 0 or slotHeight(profile, key, frame)
    local gap = height > 0 and profile.spacing or 0

    slot:ClearAllPoints()
    slot:SetSize(width, height)
    if above then
        slot:SetPoint("BOTTOM", prev, "TOP", 0, gap)
    else
        slot:SetPoint("TOP", prev, "BOTTOM", 0, -gap)
    end
    slot:Show()
    if self.debug then
        local state = not frame and "no frame" or (frame:IsShown() and "shown" or "hidden")
        slot.label:SetText(key .. " | " .. state .. " | h=" .. height .. (profile.stack[key].collapse and " | collapse" or ""))
    end

    if frame then attach(profile, key, frame, slot) end

    if height > 0 then
        return slot, height + gap
    end
    return prev, 0
end

--- Recompute and apply the whole stack. Call Request() instead unless you are already out of combat.
function Layout:Apply()
    local profile = self.db.profile
    local anchorFrame = Viewers:Get(profile.anchorKey)
    if not anchorFrame then return end
    self:ApplyStrata()

    for key in pairs(defaults.profile.stack) do
        local frame = getFrame(key)
        if frame then
            Internal.SetSuppressed(frame, not (profile.stack[key].enabled or key == profile.anchorKey))
        end
    end

    local keys = self:GetOrderedKeys(false)
    local anchorIndex
    for i, key in ipairs(keys) do
        if key == profile.anchorKey then
            anchorIndex = i
            break
        end
    end
    if not anchorIndex then return end

    local icons = RanothsCooldownManager:GetModule("IconLayout", true)
    local anchorWidth = (icons and icons:GetContentWidth(profile.anchorKey)) or anchorFrame:GetWidth()
    local width = (profile.width.mode == "anchor" and anchorWidth > 0) and anchorWidth or profile.width.value

    local anchorSlot = self:GetSlot(profile.anchorKey)
    anchorSlot:ClearAllPoints()
    anchorSlot:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT")
    anchorSlot:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT")
    anchorSlot:SetHeight(slotHeight(profile, profile.anchorKey, anchorFrame))
    anchorSlot:Show()

    local above, below = 0, 0
    local prev = anchorSlot
    for i = anchorIndex - 1, 1, -1 do
        local used
        prev, used = placeSlot(self, keys[i], prev, true, width)
        above = above + used
    end

    prev = anchorSlot
    for i = anchorIndex + 1, #keys do
        local used
        prev, used = placeSlot(self, keys[i], prev, false, width)
        below = below + used
    end

    -- Hide slots of entries that were disabled since the last apply.
    local active = {}
    for _, key in ipairs(keys) do active[key] = true end
    for key, slot in pairs(self.slots) do
        if not active[key] then slot:Hide() end
    end

    local frame = self:GetContainer()
    frame:ClearAllPoints()
    frame:SetPoint("TOP", anchorFrame, "TOP", 0, above)
    frame:SetSize(width, above + slotHeight(profile, profile.anchorKey, anchorFrame) + below)
    frame:Show()

    self:SendMessage(self.MESSAGES.APPLIED, frame)
end
