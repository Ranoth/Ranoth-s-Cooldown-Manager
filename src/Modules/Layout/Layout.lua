--- Layout module for RanothsCooldownManager.
--- Stacks the cast bar, class power, mana bar and cooldown viewers vertically inside one container.
---
--- Design:
--- * The anchor viewer (default Essential) is never moved by us, so Blizzard's Edit Mode keeps owning its position.
--- * Every stack entry gets a "slot" frame. Slots are chained above/below the anchor viewer's slot
---   according to each entry's `position`. Blizzard frames are then attached to their slot.
--- * The container frame spans the whole stack and follows the anchor viewer.
--- @module "Layout"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:NewModule("Layout", "AceEvent-3.0")

local Safe = RanothsCooldownManager:GetModule("Safe")
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Resources = RanothsCooldownManager:GetModule("Resources")
local Printer = RanothsCooldownManager:GetModule("Printer")
local Options = RanothsCooldownManager:GetModule("Options")

Layout.MESSAGES = {
    APPLIED = "RCM_LAYOUT_APPLIED",
}

--- `position` is a plain number per entry (not an array) so AceDB default merging cannot resurrect removed items.
--- Viewers always collapse when hidden; bars collapse only when `collapse` is set.
local defaults = {
    profile = {
        anchorKey = "Essential",
        spacing = 0,
        strata = "LOW",
        width = { mode = "anchor", value = 250 }, -- "anchor" follows the anchor viewer's width, "fixed" uses value
        stack = {
            CastBar = { enabled = true, position = 1, height = 20, collapse = false },
            ClassPower = { enabled = true, position = 2, height = 12, collapse = true },
            Mana = { enabled = true, position = 3, height = 12, collapse = true },
            Essential = { enabled = true, position = 4 },
            Utility = { enabled = true, position = 5 },
            BuffIcon = { enabled = true, position = 6 },
        },
    },
}

local function isViewerKey(key)
    return Viewers.FRAME_NAMES[key] ~= nil
end

local function getFrame(key)
    if isViewerKey(key) then
        return Viewers:Get(key)
    end
    local Bars = RanothsCooldownManager:GetModule("Bars", true)
    return (Bars and Bars:GetFrame(key)) or Resources:Get(key)
end

--- Stack keys sorted by position, ties broken alphabetically.
--- @param includeDisabled boolean
--- @return string[]
function Layout:GetOrderedKeys(includeDisabled)
    local profile = self.db.profile
    local keys = {}
    for key, entry in pairs(profile.stack) do
        -- Ignore stale saved entries for frames that are no longer part of the stack (e.g. BuffBar).
        if defaults.profile.stack[key] and (includeDisabled or entry.enabled or key == profile.anchorKey) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        local pa, pb = profile.stack[a].position, profile.stack[b].position
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return keys
end

--- Resolve a case-insensitive key name to a stack key.
--- @param name string
--- @return string|nil
function Layout:ResolveKey(name)
    name = name and name:lower()
    for key in pairs(self.db.profile.stack) do
        if defaults.profile.stack[key] and key:lower() == name then return key end
    end
end

--- Move an entry to a position; the other entries are renumbered 1..n.
--- @param key string
--- @param position number
--- @return boolean success
function Layout:SetPosition(key, position)
    local stack = self.db.profile.stack
    if not stack[key] or type(position) ~= "number" then return false end

    local keys = self:GetOrderedKeys(true)
    for i, k in ipairs(keys) do
        if k == key then
            table.remove(keys, i)
            break
        end
    end
    table.insert(keys, math.max(1, math.min(math.floor(position), #keys + 1)), key)
    for i, k in ipairs(keys) do
        stack[k].position = i
    end

    self:Request()
    Options:Refresh()
    return true
end

--- Print the current stack, top to bottom.
function Layout:Describe()
    local profile = self.db.profile
    for i, key in ipairs(self:GetOrderedKeys(true)) do
        local entry = profile.stack[key]
        local flags = (entry.enabled and "" or " (disabled)") .. (key == profile.anchorKey and " (anchor)" or "")
        Printer:Print(i .. ". " .. key .. flags)
    end
end

local container
local originalStrata = {}
local rawSetFrameStrata = getmetatable(UIParent).__index.SetFrameStrata

local function restoreStrata(frame)
    local original = originalStrata[frame]
    if original then
        rawSetFrameStrata(frame, original)
        originalStrata[frame] = nil
    end
end

function Layout:ApplyStrata()
    local profile = self.db.profile
    local managed = {}
    for key in pairs(defaults.profile.stack) do
        if profile.stack[key].enabled or key == profile.anchorKey then
            local frame = getFrame(key)
            if frame then
                managed[frame] = true
                originalStrata[frame] = originalStrata[frame] or frame:GetFrameStrata()
                if frame:GetFrameStrata() ~= profile.strata then
                    rawSetFrameStrata(frame, profile.strata)
                end
            end
        end
    end
    for frame in pairs(originalStrata) do
        if not managed[frame] then restoreStrata(frame) end
    end
    self:GetContainer():SetFrameStrata(profile.strata)
end

--- The frame that spans the whole stack. Safe to use for alpha, scale, or visibility of the widget.
--- @return Frame
function Layout:GetContainer()
    if not container then
        container = CreateFrame("Frame", "RanothsCooldownManagerContainer", UIParent)
        container:EnableMouse(false)
    end
    return container
end

function Layout:GetSlot(key)
    self.slots = self.slots or {}
    local slot = self.slots[key]
    if not slot then
        slot = CreateFrame("Frame", nil, self:GetContainer())
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(math.random(), math.random(), math.random(), 0.4)
        slot.label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.label:SetPoint("CENTER")
        slot.label:SetText(key)
        self.slots[key] = slot
    end
    slot.bg:SetShown(self.debug == true)
    slot.label:SetShown(self.debug == true)
    return slot
end

--- Toggle colored overlays on the slots to see the stack.
function Layout:ToggleDebug()
    self.debug = not self.debug
    Printer:Print(self.debug and "Layout overlay enabled" or "Layout overlay disabled")
    self:Request()
end

local function slotHeight(profile, key, frame)
    if isViewerKey(key) then
        return (frame and frame:IsShown()) and frame:GetHeight() or 0
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
local function attach(profile, key, frame, slot)
    if key == profile.anchorKey then return end
    local previous = {}
    for i = 1, frame:GetNumPoints() do
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

local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local suppressed = {} -- frame -> true while its entry is disabled
local alphaHooked = {}
local settingAlpha = false

--- Hide or show a Blizzard frame by alpha. Blizzard keeps showing/hiding and fading these frames itself,
--- so the alpha is re-enforced whenever Blizzard changes it. Raw methods avoid running Blizzard code tainted.
local function setSuppressed(frame, hide)
    if hide then
        suppressed[frame] = true
        if not alphaHooked[frame] then
            alphaHooked[frame] = true
            hooksecurefunc(frame, "SetAlpha", function(f)
                if suppressed[f] and not settingAlpha then
                    settingAlpha = true
                    rawSetAlpha(f, 0)
                    settingAlpha = false
                end
            end)
        end
        rawSetAlpha(frame, 0)
    elseif suppressed[frame] then
        suppressed[frame] = nil
        rawSetAlpha(frame, 1)
    end
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
            setSuppressed(frame, not (profile.stack[key].enabled or key == profile.anchorKey))
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

    local anchorWidth = anchorFrame:GetWidth()
    local width = (profile.width.mode == "anchor" and anchorWidth > 0) and anchorWidth or profile.width.value

    local anchorSlot = self:GetSlot(profile.anchorKey)
    anchorSlot:ClearAllPoints()
    anchorSlot:SetAllPoints(anchorFrame)
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
    frame:SetSize(width, above + anchorFrame:GetHeight() + below)
    frame:Show()

    self:SendMessage(self.MESSAGES.APPLIED, frame)
end

--- Request one relayout next frame, or after combat if protected frames cannot be moved yet.
function Layout:Request()
    if self.pending then return end
    self.pending = true
    C_Timer.After(0, function()
        Safe:RunWhenSafe(function()
            self.pending = false
            if self:IsEnabled() then self:Apply() end
        end)
    end)
end

function Layout:OnChange()
    self:Request()
end

function Layout:EDIT_MODE_LAYOUTS_UPDATED()
    self:Request()
end

local STACK_LABELS = {
    CastBar = "Cast bar",
    ClassPower = "Class power",
    Mana = "Mana bar",
    Essential = "Essential cooldowns",
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

--- Options group for the settings window. Returned as a function so the stack order is rebuilt on every refresh.
--- @return function
function Layout:GetOptions()
    return function()
        local function profile() return self.db.profile end

        local anchorValues = {}
        for key in pairs(defaults.profile.stack) do
            if isViewerKey(key) then anchorValues[key] = STACK_LABELS[key] end
        end

        local args = {
            description = {
                type = "description",
                order = 1,
                name = "Stacks the resource bars and cooldown viewers vertically. The anchor viewer stays where "
                    .. "Edit Mode puts it, and the other entries are placed above or below it in the order below.",
            },
            anchorKey = {
                type = "select",
                order = 2,
                name = "Anchor viewer",
                desc = "The viewer you position with Edit Mode. Entries above it in the list go above, entries below it go below.",
                values = anchorValues,
                get = function() return profile().anchorKey end,
                set = function(_, value)
                    profile().anchorKey = value
                    profile().stack[value].enabled = true
                    self:Request()
                    Options:Refresh()
                end,
            },
            spacing = {
                type = "range",
                order = 3,
                name = "Spacing",
                desc = "Gap between stacked entries.",
                min = 0, max = 20, step = 1,
                get = function() return profile().spacing end,
                set = function(_, value)
                    profile().spacing = value
                    self:Request()
                end,
            },
            strata = {
                type = "select",
                order = 3.5,
                name = "Frame strata",
                desc = "Drawing layer for the managed viewers and resource bars. LOW keeps them below MEDIUM-layer UI such as Dragon Rider. Changes wait until combat ends.",
                values = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High" },
                sorting = { "BACKGROUND", "LOW", "MEDIUM", "HIGH" },
                get = function() return profile().strata end,
                set = function(_, value)
                    profile().strata = value
                    self:Request()
                end,
            },
            widthMode = {
                type = "select",
                order = 4,
                name = "Bar width",
                values = { anchor = "Match anchor viewer", fixed = "Fixed width" },
                get = function() return profile().width.mode end,
                set = function(_, value)
                    profile().width.mode = value
                    self:Request()
                end,
            },
            widthValue = {
                type = "range",
                order = 5,
                name = "Fixed width",
                min = 50, max = 800, step = 1,
                hidden = function() return profile().width.mode ~= "fixed" end,
                get = function() return profile().width.value end,
                set = function(_, value)
                    profile().width.value = value
                    self:Request()
                end,
            },
            overlay = {
                type = "execute",
                order = 6,
                name = "Toggle slot overlay",
                desc = "Shows colored, labelled boxes on each slot of the stack.",
                func = function() self:ToggleDebug() end,
            },
            stackHeader = {
                type = "header",
                order = 10,
                name = "Stack order (top to bottom)",
            },
        }

        local ordered = self:GetOrderedKeys(true)
        for i, key in ipairs(ordered) do
            local isViewer = isViewerKey(key)
            local label = i .. ". " .. STACK_LABELS[key] .. (key == profile().anchorKey and " (anchor)" or "")
            args["entry_" .. key] = {
                type = "group",
                inline = true,
                order = 10 + i,
                name = label,
                args = {
                    enabled = {
                        type = "toggle",
                        order = 1,
                        name = "Enabled",
                        disabled = key == profile().anchorKey,
                        get = function() return profile().stack[key].enabled end,
                        set = function(_, value)
                            profile().stack[key].enabled = value
                            self:Request()
                        end,
                    },
                    up = {
                        type = "execute",
                        order = 2,
                        name = "Up",
                        width = "half",
                        disabled = i == 1,
                        func = function() self:SetPosition(key, i - 1) end,
                    },
                    down = {
                        type = "execute",
                        order = 3,
                        name = "Down",
                        width = "half",
                        disabled = i == #ordered,
                        func = function() self:SetPosition(key, i + 1) end,
                    },
                    height = {
                        type = "range",
                        order = 4,
                        name = "Height",
                        min = 4, max = 60, step = 1,
                        hidden = isViewer,
                        get = function() return profile().stack[key].height end,
                        set = function(_, value)
                            profile().stack[key].height = value
                            self:Request()
                        end,
                    },
                    collapse = {
                        type = "toggle",
                        order = 5,
                        name = "Collapse when hidden",
                        desc = "Take no space in the stack while this bar is not shown.",
                        hidden = isViewer,
                        get = function() return profile().stack[key].collapse end,
                        set = function(_, value)
                            profile().stack[key].collapse = value
                            self:Request()
                        end,
                    },
                },
            }
        end

        return { type = "group", name = "Layout", args = args }
    end
end

function Layout:OnProfileRefresh()
    self:Request()
end

function Layout:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Layout", defaults)
    Options:Register("Layout", self:GetOptions(), 10)
end

function Layout:OnEnable()
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnChange")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnChange")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnChange")
    self:RegisterMessage(Resources.MESSAGES.AVAILABLE, "OnChange")
    self:RegisterMessage(Resources.MESSAGES.SHOWN, "OnChange")
    self:RegisterMessage(Resources.MESSAGES.HIDDEN, "OnChange")
    self:RegisterMessage(Resources.MESSAGES.CHANGED, "OnChange")
    self:RegisterMessage("RCM_BARS_CHANGED", "OnChange")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:Request()
end

function Layout:OnDisable()
    -- Frames we moved keep their anchors until Blizzard repositions them or the UI reloads.
    self.pending = false
    if container then container:Hide() end
    Safe:RunWhenSafe(function()
        if self:IsEnabled() then return end
        for frame in pairs(originalStrata) do restoreStrata(frame) end
    end)
end
