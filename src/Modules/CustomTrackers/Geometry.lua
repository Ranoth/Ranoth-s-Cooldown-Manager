local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local Viewers = Addon:GetModule("Viewers")
local frames = Internal.frames
local GROUPS = Trackers.GROUPS
local visuals = {
    Essential = { font = "GameFontHighlightHugeOutline", x = 9, y = 8 },
    Utility = { font = "GameFontHighlightOutline", x = 6, y = 5 },
    BuffIcon = { x = 8, y = 7 },
}
local function byTrackerID(a, b) return a.trackerID < b.trackerID end

function Trackers:GetItems(key)
    local result = {}
    if not self:IsEnabled() then return result end
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if entry.enabled and self:IsAvailable(entry) and entry.group == key and frame and frame:GetParent() == Viewers:Get(key) then
            result[#result + 1] = frame
        end
    end
    table.sort(result, byTrackerID)
    return result
end

function Trackers:HasActiveItems(key)
    for _, frame in ipairs(self:GetItems(key)) do
        if frame:IsShown() then return true end
    end
    return false
end

function Trackers:GetReservedHeight(key)
    local items = self:GetItems(key)
    local viewer = Viewers:Get(key)
    if #items == 0 or not viewer then return nil end
    local height, width, iconScale = 0, 0, 1
    for _, item in ipairs(items) do
        local value = item:GetHeight()
        local scale = item:GetEffectiveScale() / viewer:GetEffectiveScale()
        if not issecretvalue(value) and not issecretvalue(scale) then
            height = math.max(height, value * scale)
            local itemWidth = item:GetWidth()
            if not issecretvalue(itemWidth) then width = math.max(width, itemWidth * scale) end
            iconScale = scale
        end
    end
    local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer
    local settings = Addon:GetModule("IconLayout").db.profile
    local spacing = settings[key] and settings[key].compact and settings.spacing
        or (container.childYPadding or 0) * iconScale
    local stride = container.stride or viewer.iconLimit
    if issecretvalue(stride) or type(stride) ~= "number" or stride < 1 then
        local gap = settings[key] and settings[key].compact and settings.spacing
            or (container.childXPadding or 0) * iconScale
        stride = math.max(1, math.floor((viewer:GetWidth() + gap) / math.max(width + gap, 1)))
    end
    local total = #Viewers:GetNativeItems(key) + #items
    local horizontal = (settings[key] and settings[key].compact) or container.isHorizontal ~= false
    local rows = horizontal and math.ceil(total / stride) or math.min(total, stride)
    -- Reserve the combined grid's capacity, not extra rows on top of already available native slots.
    return rows * height + math.max(0, rows - 1) * spacing
end

function Trackers:SyncGeometry(key)
    local viewer = Viewers:Get(key)
    if not viewer then return end
    local native = Viewers:GetNativeItems(key)[1]
    local width, height, scale
    if native then
        width, height = native:GetWidth(), native:GetHeight()
        scale = native:GetEffectiveScale() / viewer:GetEffectiveScale()
        if issecretvalue(width) or issecretvalue(height) or issecretvalue(scale)
            or width <= 0 or height <= 0 or scale <= 0 then return end
    end
    for _, frame in ipairs(self:GetItems(key)) do
        if native then
            frame:SetSize(width, height)
            frame:SetScale(scale)
        end
        if frame.skinGroup ~= key then
            local style = visuals[key]
            frame.skinGroup = key
            if style.font then
                frame.Cooldown:SetCountdownFont(style.font)
            else
                frame.countdownText:SetFont(unpack(frame.defaultCountdownFont))
            end
            frame.IconOverlay:ClearAllPoints()
            frame.IconOverlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -style.x, style.y)
            frame.IconOverlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style.x, -style.y)
        end
        frame.Cooldown:SetHideCountdownNumbers(viewer.timerShown == false)
        -- Same as Blizzard's items: tooltips only need mouse motion, and clicks pass through.
        local tooltips = viewer.tooltipsShown ~= false
        if frame.tooltipsShown ~= tooltips then
            frame.tooltipsShown = tooltips
            frame:SetMouseClickEnabled(false)
            frame:SetMouseMotionEnabled(tooltips)
            if not tooltips and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        end
    end
end

function Trackers:OrderItems(active)
    local custom = {}
    for i = #active, 1, -1 do
        if active[i].frame.trackerID then custom[#custom + 1] = table.remove(active, i) end
    end
    table.sort(custom, function(a, b)
        local pa = self.db.profile.entries[a.frame.trackerID].position
        local pb = self.db.profile.entries[b.frame.trackerID].position
        if pa ~= pb then return pa < pb end
        return a.frame.trackerID < b.frame.trackerID
    end)
    local previousPosition = 0
    for _, item in ipairs(custom) do
        local position = self.db.profile.entries[item.frame.trackerID].position
        -- Keep ties and positions beyond the last slot in the same sorted order.
        position = math.min(math.max(position, previousPosition + 1), #active + 1)
        table.insert(active, position, item)
        previousPosition = position
    end
end
function Trackers:OnViewerMessage(_, key)
    if not GROUPS[key] then return end
    self:SyncGeometry(key)
    -- Only reconcile geometry here: publishing another viewer message would create a refresh loop.
    for _, frame in ipairs(self:GetItems(key)) do
        frame:SetFrameStrata(Viewers:Get(key):GetFrameStrata())
    end
end

function Trackers:OnStackLayout()
    for key in pairs(GROUPS) do self:OnViewerMessage(nil, key) end
end
