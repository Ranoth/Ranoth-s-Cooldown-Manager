--- Lightweight settings loader and runtime profile dispatcher.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Options = Addon:NewModule("Options")
local Printer = Addon:GetModule("Printer")
local COMPANION = addon_name .. "_Options"

function Options:Refresh()
    if self.RefreshUI then self:RefreshUI() end
end

function Options:Open()
    if not self.InitializeUI and InCombatLockdown() then
        Printer:Print("Settings cannot be loaded during combat. Try again after combat.")
        return false
    end
    if not self.InitializeUI then
        local loaded, reason = C_AddOns.LoadAddOn(COMPANION)
        if not loaded and reason == "DISABLED" then
            C_AddOns.EnableAddOn(COMPANION, UnitName("player"))
            loaded, reason = C_AddOns.LoadAddOn(COMPANION)
        end
        if not loaded then
            Printer:Print("Unable to load " .. COMPANION .. ": " .. tostring(reason)
                .. ". Install and enable the options companion alongside the main addon.")
            return false
        end
        if not self.InitializeUI then
            Printer:Print("The options companion did not initialize. Check its Lua errors and installation.")
            return false
        end
    end
    self:InitializeUI()
    if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then HideUIPanel(SettingsPanel) end
    self:OpenUI()
    return true
end

function Options:Close()
    if self.CloseUI then self:CloseUI() end
end

function Options:Toggle()
    if self.IsUIOpen and self:IsUIOpen() then self:Close() else self:Open() end
end

function Options:OnProfileRefresh()
    for _, module in Addon:IterateModules() do
        if module ~= self and module.OnProfileRefresh then module:OnProfileRefresh() end
    end
    self:Refresh()
end

function Options:OnInitialize()
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetScript("OnShow", function(frame)
        if frame.initialized then return end
        frame.initialized = true
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Ranoth's Cooldown Manager")
        local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
        description:SetText("Open settings to load the configuration interface.")
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(160, 24)
        button:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
        button:SetText("Open settings")
        button:SetScript("OnClick", function() self:Open() end)
    end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Ranoth's Cooldown Manager")
    Settings.RegisterAddOnCategory(category)

    local db = Addon.db
    db.RegisterCallback(self, "OnProfileChanged", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileCopied", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileReset", "OnProfileRefresh")
end
