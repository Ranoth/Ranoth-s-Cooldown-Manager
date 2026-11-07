--- Isolated, session-only tests; never acquire Blizzard's live pooled alerts or alter cooldown/aura state.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
local previews, frames = {}, Internal.weak()
Internal.previewFrames = frames
local EFFECTS = { "pandemic", "ants", "alertFlash", "flash", "debuff" }
local TEMPLATES = {
    pandemic = "CooldownPandemicFXTemplate",
    ants = "VisualAlertMarchingAntsBaseTemplate",
    alertFlash = "VisualAlertFlashBaseTemplate",
    debuff = "CooldownViewerItemDebuffBorderTemplate",
}

function NativeGlows:GetPreview(key, effect)
    return previews[key] and previews[key][effect] == true or false
end

function NativeGlows:SetPreview(key, effect, value)
    if value then
        previews[key] = previews[key] or {}
        previews[key][effect] = true
    elseif previews[key] then
        previews[key][effect] = nil
        if not next(previews[key]) then previews[key] = nil end
    end
    if not next(previews) then self:StopPreviews() end
    self:Refresh()
end

local function create(item, effect)
    local root = CreateFrame("Frame", nil, item)
    root:EnableMouse(false)
    root:SetAllPoints(item.Icon or item)
    root.Icon, root.glowItem = item.Icon or item, item
    if effect ~= "flash" then
        local native = CreateFrame("Frame", nil, root, TEMPLATES[effect])
        native:EnableMouse(false)
        root.native = native
        if effect == "pandemic" then
            root.PandemicIcon = native
        elseif effect == "debuff" then
            root.DebuffBorder = native
            native:UpdateFromAuraData({ isHarmful = true, dispelName = "Magic" })
        else
            native:SetManualRelease(true)
            root.alertContainer = { native }
        end
    end
    root:Hide()
    return root
end

local function stop(root)
    Internal.StopReady(root)
    Internal.StopAlerts(root)
    if root.native then Internal.SetCustomClipping(root.native, false) end
    local edge = Internal.edges[root.PandemicIcon or root.DebuffBorder or root.native]
    if edge then Internal.setPulse(edge) end
    if root.PandemicIcon then Internal.pandemicStyled[root.PandemicIcon] = nil end
    root:Hide()
end

function NativeGlows:StopPreviews(item)
    if item then
        for _, root in pairs(frames[item] or {}) do stop(root) end
    else
        for owner in pairs(frames) do self:StopPreviews(owner) end
    end
end

local function style(root, item, key, effect)
    root.previewKey = key
    local icon = item.Icon or item
    if root.Icon ~= icon then root.Icon = icon; root:SetAllPoints(icon) end
    root:SetFrameStrata(item:GetFrameStrata())
    root:SetFrameLevel(item:GetFrameLevel())
    Internal.iconSizes[root] = Internal.iconSizes[item]
    if root.native then
        local padding = effect == "pandemic" and 6 or effect == "debuff" and "debuff" or "alerts"
        Skin:FitNativeEffect(root, root.native, key, nil, nil, padding)
        root.native:Show()
    end
    if effect == "pandemic" then
        Internal.StylePandemic(root)
    elseif effect == "debuff" then
        Internal.StyleDebuff(root, { isHarmful = true, dispelName = "Magic" })
    elseif effect == "flash" then
        if not Internal.StylePreviewFlash(root) then
            stop(root)
            if not root.unavailable then
                Addon:GetModule("Printer"):Print("Ready flash test unavailable: icon dimensions or Blizzard flipbook artwork are not ready.")
                root.unavailable = true
            end
            return
        end
        root.unavailable = nil
    else
        Internal.StyleAlerts(root)
    end
    root:Show()
end

function NativeGlows:RefreshPreviews()
    if not next(previews) then return end
    local current = {}
    if self:IsEnabled() then
        for _, key in ipairs(Internal.KEYS) do
            for _, item in ipairs(Viewers:GetItems(key)) do
                current[item] = true
                local cached = frames[item]
                for _, effect in ipairs(EFFECTS) do
                    if self:GetPreview(key, effect) and item:IsShown() then
                        if not cached then cached = {}; frames[item] = cached end
                        local root = cached[effect]
                        if not root then root = create(item, effect); cached[effect] = root end
                        style(root, item, key, effect)
                    elseif cached and cached[effect] then
                        stop(cached[effect])
                    end
                end
            end
        end
    end
    for item in pairs(frames) do
        if not current[item] then self:StopPreviews(item) end
    end
end

function Internal.ClearPreviews()
    wipe(previews)
    NativeGlows:StopPreviews()
end
