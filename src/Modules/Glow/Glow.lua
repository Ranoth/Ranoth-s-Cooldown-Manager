--- Viewer ownership, cached geometry, profiles and lifecycle/events.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:GetModule("Glow")
local Internal = Glow.Internal
local Skin = Addon:GetModule("Skin")
local Viewers = Addon:GetModule("Viewers")
local owners, states, previews = Internal.owners, Internal.states, Internal.previews
local defaults, KEYS = Internal.defaults, Internal.KEYS
local apply, suppress = Internal.Apply, Internal.Suppress
local setActive, hookManager = Internal.SetActive, Internal.HookManager
local bordersHooked = false

function Glow:OnViewerMessage(_, key)
    if not self.db.profile[key] then return end
    hookManager()
    for item, owner in pairs(owners) do
        if owner == key then owners[item] = nil end
    end
    for _, item in ipairs(Viewers:GetItems(key)) do
        owners[item] = key
        Skin:CacheGlowRaster(item)
        if not states[item] then
            local alert = item.SpellActivationAlert
            local shown = alert and alert:IsShown()
            states[item] = { active = not issecretvalue(shown) and shown == true }
            item:HookScript("OnHide", function(frame)
                local glow = states[frame].frame
                if glow then glow:SetScript("OnUpdate", nil); glow:Hide() end
                local preview = states[frame].previewAlert
                if preview then preview:Hide() end
            end)
            item:HookScript("OnShow", apply)
            if item.ResetCooldownData then
                hooksecurefunc(item, "ResetCooldownData", function(frame) setActive(frame, false) end)
            end
        end
        local icon = item.Icon or item
        local width, height = icon:GetWidth(), icon:GetHeight()
        if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
            states[item].width, states[item].height = width, height
        end
        apply(item)
    end
    for item in pairs(states) do
        if not owners[item] then apply(item) end
    end
end

function Glow:OnProfileRefresh()
    for item in pairs(states) do apply(item) end
end

function Glow:OnInitialize()
    self.db = Addon.db:RegisterNamespace("Glow", defaults)
end

function Glow:OnEnable()
    if not bordersHooked then
        bordersHooked = true
        local borders = Addon:GetModule("Borders")
        hooksecurefunc(borders, "Refresh", function()
            if borders.Internal.refreshChanged then Glow:RefreshLayers() end
        end)
        hooksecurefunc(Skin, "Apply", function() Glow:RefreshLayers() end)
    end
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshGeometry")
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function Glow:RefreshGeometry()
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function Glow:OnDisable()
    wipe(previews)
    for _, st in pairs(states) do
        if st.frame then st.frame:SetScript("OnUpdate", nil); st.frame:Hide() end
        if st.previewAlert then st.previewAlert:Hide() end
        suppress(st.alert, false)
    end
end
