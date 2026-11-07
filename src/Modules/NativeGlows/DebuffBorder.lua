--- Debuff-type border color and native texture visibility mirroring.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local edges = Internal.edges
local settings = Internal.settings
local edge = Internal.edge
local styleEdge = Internal.styleEdge
local function dispelColor(auraData)
    local name = auraData and auraData.dispelName
    if name ~= nil and issecretvalue(name) then name = nil end
    local color = AuraUtil and AuraUtil.GetAuraBorderColor and AuraUtil.GetAuraBorderColor(name)
    if color and color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        return { r = r, g = g, b = b, a = a }
    end
    return { r = 0.8, g = 0, b = 0, a = 1 }
end

--- Blizzard shows the border frame while an aura is displayed and its texture only for harmful auras.
local function styleDebuff(item, auraData)
    local border = item.DebuffBorder
    local texture = border and border.Texture
    if not texture then return end
    local s, key = settings(item, "debuff")
    local custom = s and s.custom
    Internal.SetCustomClipping(border, custom)
    texture:SetAlpha(custom and 0 or 1)
    local square = edges[border]
    if custom then
        square = edge(border)
        if auraData then square.color = dispelColor(auraData) end
        styleEdge(square, item, key, square.color or dispelColor(nil), s.thickness, border:GetFrameLevel() + 1)
        square:SetShown(texture:IsShown())
    elseif square then
        square:Hide()
    end
end

Internal.StyleDebuff = styleDebuff

function Internal.HookDebuff(item)
    local border = item.DebuffBorder
    if border and border.Texture then
        if border.UpdateFromAuraData then
            hooksecurefunc(border, "UpdateFromAuraData", function(_, auraData) styleDebuff(item, auraData) end)
        end
        local function mirror()
            local square = edges[border]
            local s = settings(item, "debuff")
            if square and s and s.custom then square:SetShown(border.Texture:IsShown()) end
        end
        hooksecurefunc(border.Texture, "Show", mirror)
        hooksecurefunc(border.Texture, "Hide", mirror)
        hooksecurefunc(border.Texture, "SetShown", mirror)
    end
end
