--- Cooldown Manager marching-ants and flash alerts; reuses Glow's dash renderer.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local weak = Internal.weak
local edges = Internal.edges
local iconSizes = Internal.iconSizes
local settings = Internal.settings
local edge = Internal.edge
local styleEdge = Internal.styleEdge
local setPulse = Internal.setPulse
local Glow = Addon:GetModule("Glow")
local dashes, alertItems = weak(), weak()

local function alertColor(alert, s)
    if s.useAlertColor and alert.GetVertexColor then
        local color = alert:GetVertexColor()
        if color and color.GetRGBA then
            local r, g, b, a = color:GetRGBA()
            return { r = r, g = g, b = b, a = a }
        end
    end
    return s.color
end

local function restoreAlert(alert)
    Internal.SetCustomClipping(alert, false)
    alertItems[alert] = nil
    if dashes[alert] then Glow.StopDashes(dashes[alert]) end
    if edges[alert] then
        setPulse(edges[alert])
        edges[alert]:Hide()
    end
    local native = alert.Flipbook or alert.Glow
    if native then native:Show() end
end

local function styleAlert(item, alert)
    local s, key = settings(item, "alerts")
    if not s or not s.custom then
        if alertItems[alert] then restoreAlert(alert) end
        return
    end
    alertItems[alert] = item
    local native = alert.Flipbook or alert.Glow
    local level = alert:GetFrameLevel() + 1
    local drawn
    if alert.Flipbook then
        local frame = dashes[alert]
        if not frame then
            frame = Glow.CreateDashes(alert, item.Icon or item, level)
            dashes[alert] = frame
        end
        frame:ClearAllPoints()
        frame:SetAllPoints(item.Icon or item)
        frame.glowItem = item.glowItem or item
        Internal.setLayer(frame, level, item.glowItem or item)
        local size = iconSizes[item]
        if size then frame.readableWidth, frame.readableHeight = size[1], size[2] end
        drawn = Glow.StartDashes(frame, s, key, alertColor(alert, s))
    else
        local square = edge(alert)
        styleEdge(square, item, key, alertColor(alert, s), s.thickness, level)
        if not square.pulse then setPulse(square, 0.25, 1, 0.5) end
        square:Show()
        drawn = true
    end
    -- Keep Blizzard's art while our dashes have no readable geometry yet.
    Internal.SetCustomClipping(alert, drawn == true)
    if native then native:SetShown(not drawn) end
end

--- AddAlert and RemoveAlert both re-sort through UpdateAlerts; a removed alert is no longer in the container.
local function styleAlerts(item)
    local current = {}
    for _, alert in ipairs(item.alertContainer or {}) do
        current[alert] = true
        styleAlert(item, alert)
    end
    for alert, owner in pairs(alertItems) do
        if owner == item and not current[alert] then restoreAlert(alert) end
    end
end

Internal.StyleAlerts = styleAlerts
function Internal.StopAlerts(item)
    for alert, owner in pairs(alertItems) do
        if owner == item then restoreAlert(alert) end
    end
end

function Internal.HookAlerts(item)
    if item.UpdateAlerts then hooksecurefunc(item, "UpdateAlerts", styleAlerts) end
end
