--- Coalesced combat-safe layout requests, profiles and lifecycle/events.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:GetModule("Layout")
local Internal = Layout.Internal
local defaults = Internal.defaults
local Safe = RanothsCooldownManager:GetModule("Safe")
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Resources = RanothsCooldownManager:GetModule("Resources")

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

function Layout:OnProfileRefresh()
    self:Request()
end

function Layout:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Layout", defaults)
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
    Internal.HideContainer()
    Safe:RunWhenSafe(function()
        if self:IsEnabled() then return end
        Internal.RestoreStrata()
    end)
end
