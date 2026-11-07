--- Border refresh coordination, combat guards, profiles and lifecycle.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Borders = Addon:GetModule("Borders")
local Safe = Addon:GetModule("Safe")
local Internal = Borders.Internal
local entries, active = Internal.entries, Internal.active
local REQUESTED = Internal.REQUESTED
local pixelSize

function Borders:Request()
    if not self.db then return end
    if InCombatLockdown() then
        Internal.dirty = true
        return
    end
    if not self.db.profile.enabled and #active == 0 then return end
    Safe:Notify(REQUESTED, "all")
end

function Borders:Refresh()
    Internal.refreshChanged = false
    -- A queued message may run after combat starts, even if its request was safe.
    if InCombatLockdown() then
        Internal.dirty = true
        return
    end
    local changed = Internal.dirty
    local _, screenHeight = GetPhysicalScreenSize()
    -- GetEffectiveScale gives global UI coordinates, not physical display pixels.
    local currentPixelSize = UIParent:GetHeight() * UIParent:GetEffectiveScale() / screenHeight
    if pixelSize ~= currentPixelSize then changed = true; pixelSize = currentPixelSize end
    Internal.dirty = false
    wipe(active)
    for _, entry in pairs(entries) do
        local enabled = self.db.profile.enabled and not self:IsExcluded(entry.key)
        if enabled and entry.kind == "bars" then
            local layout, bars, resources = Addon:GetModule("Layout"), Addon:GetModule("Bars"), Addon:GetModule("Resources")
            local settings = layout.db.profile.stack[entry.key]
            local selected = bars:GetFrame(entry.key) or resources:Get(entry.key)
            enabled = settings and settings.enabled and selected == entry.frame
        end
        local visible = enabled and entry.size > 0 and entry.frame:IsVisible() and entry.border:IsShown()
        local left, bottom, width, height, scale, borderScale
        if visible then
            local strata = entry.border:GetFrameStrata()
            local level = entry.frame:GetFrameLevel() + entry.levelOffset
            if entry.strata ~= strata or entry.level ~= level then changed = true end
            entry.strata, entry.level = strata, level
            scale = entry.anchor:GetEffectiveScale()
            borderScale = entry.border:GetEffectiveScale()
            left, bottom = entry.anchor:GetLeft(), entry.anchor:GetBottom()
            width, height = entry.anchor:GetWidth(), entry.anchor:GetHeight()
            visible = not issecretvalue(left) and not issecretvalue(bottom)
                and not issecretvalue(width) and not issecretvalue(height)
                and not issecretvalue(scale) and not issecretvalue(borderScale)
                and left ~= nil and bottom ~= nil and width > 0 and height > 0 and scale > 0 and borderScale > 0
        end
        if visible then
            entry.glowScale = scale
            local right, top = (left + width) * scale, (bottom + height) * scale
            left, bottom = left * scale, bottom * scale
            local thickness = math.min(entry.size * borderScale, (right - left) / 2, (top - bottom) / 2)
            if entry.left ~= left or entry.bottom ~= bottom or entry.right ~= right
                or entry.top ~= top or entry.thickness ~= thickness then changed = true end
            entry.left, entry.bottom, entry.right, entry.top, entry.thickness = left, bottom, right, top, thickness
            active[#active + 1] = entry
        elseif entry.collapsed then
            Internal.Restore(entry)
        end
        if entry.visible ~= visible then changed = true; entry.visible = visible end
    end
    if not changed then return end
    Internal.refreshChanged = true
    -- Stable ownership: upper/left elements supply the shared color; wider borders supply the thickness.
    table.sort(active, function(a, b)
        if a.top ~= b.top then return a.top > b.top end
        return a.left < b.left
    end)
    Internal.Render(active, pixelSize)
end

function Borders:SetShared(value)
    self.db.profile.enabled = value
    Internal.dirty = true
    self:Request()
end

function Borders:MigrateProfile()
    local profile = self.db.profile
    if rawget(profile, "enabled") == nil then
        profile.enabled = profile.icons == true or profile.bars == true
    end
    profile.icons, profile.bars = nil, nil
end

function Borders:OnProfileRefresh()
    self:MigrateProfile()
    self:SetShared(self.db.profile.enabled)
end

function Borders:OnInitialize()
    self.db = Addon.db:RegisterNamespace("Borders", Internal.defaults)
    self:MigrateProfile()
end

function Borders:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Request")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnProfileRefresh")
    self:RegisterEvent("UI_SCALE_CHANGED", "OnProfileRefresh")
    self:RegisterMessage(REQUESTED, "Refresh")
    self:RegisterMessage(Addon:GetModule("Layout").MESSAGES.APPLIED, "Request")
    local Viewers, Resources, Bars = Addon:GetModule("Viewers"), Addon:GetModule("Resources"), Addon:GetModule("Bars")
    for _, message in pairs(Viewers.MESSAGES) do self:RegisterMessage(message, "Request") end
    for _, message in pairs(Resources.MESSAGES) do self:RegisterMessage(message, "Request") end
    self:RegisterMessage(Bars.MESSAGES.CHANGED, "Request")
    self:Request()
end

function Borders:OnDisable()
    for _, entry in pairs(entries) do
        if entry.collapsed then Internal.Restore(entry) end
    end
    wipe(active)
end
