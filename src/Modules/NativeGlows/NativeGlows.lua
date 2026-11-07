--- NativeGlows facade: viewer discovery, refresh coordination and lifecycle.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local weak = Internal.weak
local owners = Internal.owners
local iconSizes = Internal.iconSizes
local defaults = Internal.defaults
local KEYS = Internal.KEYS
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
local hooked = weak()
local bordersHooked = false

local function hook(item)
    if hooked[item] then return end
    hooked[item] = true
    Internal.HookPandemic(item)
    Internal.HookAlerts(item)
    Internal.HookReady(item)
    Internal.HookDebuff(item)
    item:HookScript("OnHide", function() NativeGlows:StopPreviews(item) end)
    item:HookScript("OnShow", function() NativeGlows:RefreshPreviews() end)
end
local function refreshItem(item)
    Skin:CacheGlowRaster(item)
    local icon = item.Icon or item
    local width, height = icon:GetWidth(), icon:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
        local size = iconSizes[item] or {}
        size[1], size[2] = width, height
        iconSizes[item] = size
    end
    Internal.StylePandemic(item)
    Internal.StyleAlerts(item)
    Internal.StyleFlash(item)
    Internal.StyleDebuff(item)
end

function NativeGlows:OnViewerMessage(_, key)
    if not self.db.profile[key] then return end
    for _, item in ipairs(Viewers:GetItems(key)) do
        owners[item] = key
        hook(item)
        refreshItem(item)
    end
    self:RefreshPreviews()
end

function NativeGlows:Refresh()
    Skin:RefreshNativeEffectLayers()
    Internal.revision = Internal.revision + 1
    for item in pairs(owners) do refreshItem(item) end
    self:RefreshPreviews()
end

function NativeGlows:OnProfileRefresh()
    self:Refresh()
end
function NativeGlows:OnInitialize()
    self.db = Addon.db:RegisterNamespace("NativeGlows", defaults)
end

function NativeGlows:RefreshLayers()
    Skin:RefreshNativeEffectLayers()
    Internal.RefreshLayers()
    for item in pairs(owners) do Internal.RaiseReady(item) end
end

function NativeGlows:OnEnable()
    if not bordersHooked then
        bordersHooked = true
        hooksecurefunc(Skin, "FitNativeEffect", function(_, _, effect)
            Internal.RefitCustomClipping(effect)
        end)
        local borders = Addon:GetModule("Borders")
        hooksecurefunc(borders, "Refresh", function()
            if borders.Internal.refreshChanged then
                NativeGlows:Refresh()
                NativeGlows:RefreshLayers()
            end
        end)
        -- Secure post-hooks persist across disable/enable cycles.
        hooksecurefunc(Skin, "Apply", function(_, _, incremental)
            if not incremental then NativeGlows:Refresh() end
            NativeGlows:RefreshLayers()
        end)
        hooksecurefunc(borders, "SetShared", function() NativeGlows:Refresh() end)
        -- Custom trackers update on cooldown events, like Blizzard items do in RefreshSpellCooldownInfo.
        local Trackers = Addon:GetModule("CustomTrackers", true)
        if Trackers then
            hooksecurefunc(Trackers, "UpdateFrame", function(_, frame)
                if owners[frame] then Internal.RefreshReady(frame) end
            end)
        end
    end
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function NativeGlows:OnDisable()
    Internal.ClearPreviews()
    self:Refresh()
end
