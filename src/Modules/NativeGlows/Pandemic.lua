--- Pandemic replacement and pooled-frame styling cache.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local weak = Internal.weak
local edges = Internal.edges
local settings = Internal.settings
local edge = Internal.edge
local styleEdge = Internal.styleEdge
local setPulse = Internal.setPulse
local traceEvent = Internal.TraceEvent
local pandemicStyled = weak()

--- Blizzard calls ShowPandemicStateFrame every frame during pandemic time; only a pooled frame newly acquired for
--- this item, a level change by Skin, or a settings change restyles it.
local function stylePandemic(item)
    local frame = item.PandemicIcon
    if not frame then return end
    local level = frame:GetFrameLevel()
    local done = pandemicStyled[frame]
    if done and done.item == item and done.revision == Internal.revision and done.level == level then return end
    done = done or {}
    done.item, done.revision, done.level = item, Internal.revision, level
    pandemicStyled[frame] = done
    local s, key = settings(item, "pandemic")
    local custom = s and s.custom
    Internal.SetCustomClipping(frame, custom)
    traceEvent(item, "pandemic", "style", custom and "custom" or "native")
    if custom then
        local square = edge(frame)
        styleEdge(square, item, key, s.color, s.thickness, level + 1)
        setPulse(square, s.pulse and 1, 0.35, s.speed)
        square:Show()
    elseif edges[frame] then
        setPulse(edges[frame])
        edges[frame]:Hide()
    end
    if frame.Border then frame.Border:SetShown(not custom) end
    if frame.FX then frame.FX:SetShown(not custom) end
    Internal.RaiseReady(item)
end

Internal.StylePandemic = stylePandemic
Internal.pandemicStyled = pandemicStyled

function Internal.HookPandemic(item)
    if item.ShowPandemicStateFrame then hooksecurefunc(item, "ShowPandemicStateFrame", stylePandemic) end
end
