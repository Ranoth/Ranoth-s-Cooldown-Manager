local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local nativeEffects = setmetatable({}, { __mode = "k" })
--- Fit native ready/proc/pandemic/alert artwork to the area inside our border without replacing its animation.
--- @param force boolean|nil Refit even if cached: pooled frames are re-anchored by Blizzard when acquired.
--- @param levelOffset number|nil Extra level above the base, keeping Blizzard's order between stacked alerts.
--- @param padding number|string|nil Fixed padding (pandemic) or native effect kind for artwork-specific margins.
function Skin:FitNativeEffect(item, effect, key, force, levelOffset, padding)
    if not effect then return end
    local icon = item.Icon or item
    local left, right, top, bottom
    if type(padding) == "string" then
        left, right, top, bottom = self:GetNativeEffectInsets(item, key, padding)
        if left == nil then return end -- Preserve native art until public or cached dimensions are available.
    else
        left = self.db.profile[key].borderSize - (padding or 0)
        right, top, bottom = left, left, left
    end
    local level, strata = RanothsCooldownManager:GetModule("Borders"):GetOverlayLevel(effect,
        item:GetFrameLevel() + 7 + (levelOffset or 0), item:GetFrameStrata())
    local previous = nativeEffects[effect]
    if not force and previous and previous.icon == icon and previous.left == left and previous.right == right
        and previous.top == top and previous.bottom == bottom and previous.level == level
        and previous.strata == strata then
        return
    end
    effect:ClearAllPoints()
    effect:SetPoint("TOPLEFT", icon, "TOPLEFT", left, -top)
    effect:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -right, bottom)
    -- Pandemic frames carry their own MEDIUM strata, which would ignore the Layout strata option.
    if effect:GetFrameStrata() ~= strata then effect:SetFrameStrata(strata) end
    effect:SetFrameLevel(level)
    effect:SetClipsChildren(true)
    for _, name in ipairs({ "Flipbook", "ProcStartFlipbook", "ProcLoopFlipbook", "ProcAltGlow" }) do
        local texture = effect[name]
        if texture then
            texture:ClearAllPoints()
            texture:SetAllPoints(effect)
        end
    end
    nativeEffects[effect] = { icon = icon, left = left, right = right, top = top, bottom = bottom, level = level, strata = strata,
        item = item, offset = 7 + (levelOffset or 0) }
end

function Skin:RefreshNativeEffectLayers()
    local borders = RanothsCooldownManager:GetModule("Borders")
    for effect, previous in pairs(nativeEffects) do
        local item = previous.item
        local level, strata = borders:GetOverlayLevel(effect, item:GetFrameLevel() + previous.offset, item:GetFrameStrata())
        if effect:GetFrameStrata() ~= strata then effect:SetFrameStrata(strata) end
        if effect:GetFrameLevel() ~= level then effect:SetFrameLevel(level) end
        previous.level, previous.strata = level, strata
    end
end

local effectKeys = setmetatable({}, { __mode = "k" }) -- item -> viewer key, for hooks fired outside Apply
local effectHooked = setmetatable({}, { __mode = "k" })
local pandemicFitted = setmetatable({}, { __mode = "k" })
-- Blizzard anchors the pandemic artwork 6px outside the icon so its ring lands on the icon edge.
local PANDEMIC_PADDING = 6

--- Visual alerts (marching ants, flash) chosen in Cooldown Manager's alert settings.
local function fitAlerts(item, force)
    local key = effectKeys[item]
    local container = key and item.alertContainer
    if not container then return end
    for index, alert in ipairs(container) do
        Skin:FitNativeEffect(item, alert, key, force, index, "alerts")
    end
end

-- Blizzard checks the pandemic state every frame; only a newly acquired frame needs fitting.
local function fitPandemic(item)
    local key, frame = effectKeys[item], item.PandemicIcon
    if not key or not frame or pandemicFitted[item] == frame then return end
    pandemicFitted[item] = frame
    Skin:FitNativeEffect(item, frame, key, true, nil, PANDEMIC_PADDING)
end

local function hookNativeEffects(item, key)
    effectKeys[item] = key
    if effectHooked[item] then return end
    effectHooked[item] = true
    if item.ShowPandemicStateFrame then hooksecurefunc(item, "ShowPandemicStateFrame", fitPandemic) end
    if item.HidePandemicStateFrame then
        hooksecurefunc(item, "HidePandemicStateFrame", function(i) pandemicFitted[i] = nil end)
    end
    -- AddAlert and RemoveAlert both re-sort through UpdateAlerts, after the alert was anchored.
    if item.UpdateAlerts then hooksecurefunc(item, "UpdateAlerts", function(i) fitAlerts(i, true) end) end
end

--- Pandemic, visual alerts and the buff debuff border, which Blizzard draws outside the icon.
local function fitNativeEffects(item, key)
    hookNativeEffects(item, key)
    Skin:FitNativeEffect(item, item.CooldownFlash, key, nil, nil, "flash")
    Skin:FitNativeEffect(item, item.SpellActivationAlert, key, nil, nil, "proc")
    Skin:FitNativeEffect(item, item.DebuffBorder, key, nil, nil, "debuff")
    if item.PandemicIcon then
        pandemicFitted[item] = item.PandemicIcon
        Skin:FitNativeEffect(item, item.PandemicIcon, key, nil, nil, PANDEMIC_PADDING)
    end
    fitAlerts(item)
end

Internal.FitNativeEffects = fitNativeEffects
