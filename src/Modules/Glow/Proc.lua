--- Proc activation, native alert suppression and selected-effect previews.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:GetModule("Glow")
local Internal = Glow.Internal
local Skin = Addon:GetModule("Skin")
local owners, states, previews = Internal.owners, Internal.states, Internal.previews
local GLOW_LEVEL_OFFSET = Internal.GLOW_LEVEL_OFFSET
local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local suppressed = setmetatable({}, { __mode = "k" })
local alertHooked = setmetatable({}, { __mode = "k" })
local managerHooked = false
local draw, onUpdate = Internal.Draw, Internal.OnUpdate

local function suppress(alert, enabled)
    if not alert then return end
    if enabled then
        if suppressed[alert] == nil then suppressed[alert] = alert:GetAlpha() end
        if not alertHooked[alert] then
            alertHooked[alert] = true
            hooksecurefunc(alert, "SetAlpha", function(frame)
                if suppressed[frame] ~= nil then rawSetAlpha(frame, 0) end
            end)
        end
        rawSetAlpha(alert, 0)
    elseif suppressed[alert] ~= nil then
        local alpha = suppressed[alert]
        suppressed[alert] = nil
        rawSetAlpha(alert, alpha)
    end
end

local function apply(item)
    local st = states[item]
    local key = owners[item]
    if not st then return end
    local s = key and Glow.db.profile[key]
    local enabled = Glow:IsEnabled() and s and s.enabled
    local active = enabled and (st.active or previews[key])
    local nativePreview = Glow:IsEnabled() and s and not s.enabled and previews[key] and item:IsShown()
    if nativePreview then
        if not st.previewAlert then
            st.previewAlert = CreateFrame("Frame", nil, item, "ActionButtonSpellAlertTemplate")
            st.previewAlert:EnableMouse(false)
            st.previewAlert:SetScript("OnShow", function(frame) frame.ProcLoop:Play() end)
            st.previewAlert:SetScript("OnHide", function(frame) frame.ProcLoop:Stop() end)
        end
        Skin:FitNativeEffect(item, st.previewAlert, key, nil, nil, "proc")
        st.previewAlert:Show()
    elseif st.previewAlert then
        st.previewAlert:Hide()
    end
    -- Stopping must never depend on native-frame geometry being readable.
    if not active and st.frame then
        st.frame:SetScript("OnUpdate", nil)
        st.frame:Hide()
    end
    local alert = item.SpellActivationAlert
    if st.alert and st.alert ~= alert then suppress(st.alert, false) end
    st.alert = alert
    if key then Skin:FitNativeEffect(item, alert, key, nil, nil, "proc") end
    suppress(alert, enabled)
    if active then
        st.frame = st.frame or Glow.CreateDashes(item, item.Icon or item, item:GetFrameLevel() + GLOW_LEVEL_OFFSET)
        local frame = st.frame
        frame.glowItem = item
        frame.settings = s
        frame.viewerKey = key
        frame.readableWidth = st.width or frame.readableWidth
        frame.readableHeight = st.height or frame.readableHeight
        local level, strata = Addon:GetModule("Borders"):GetOverlayLevel(frame,
            item:GetFrameLevel() + GLOW_LEVEL_OFFSET, item:GetFrameStrata())
        if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
        if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
        local c = s.color
        for _, line in ipairs(frame.lines) do line:SetVertexColor(c.r, c.g, c.b, c.a) end
        if not draw(frame) then
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
            -- Keep Blizzard's alert visible until usable geometry is available.
            suppress(alert, false)
            return
        end
        frame:SetScript("OnUpdate", onUpdate)
        frame:Show()
    elseif st.frame then
        st.frame:SetScript("OnUpdate", nil)
        st.frame:Hide()
    end
end

local function setActive(item, active)
    local st = states[item]
    if not st then return end
    local NativeGlows = Addon:GetModule("NativeGlows", true)
    if NativeGlows then NativeGlows:TracePixel(item, active) end
    st.active = active
    apply(item)
end

local function hookManager()
    if managerHooked or not ActionButtonSpellAlertManager then return end
    managerHooked = true
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, item) setActive(item, true) end)
    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, item) setActive(item, false) end)
end

Internal.Apply = apply
Internal.Suppress = suppress
Internal.SetActive = setActive
Internal.HookManager = hookManager
