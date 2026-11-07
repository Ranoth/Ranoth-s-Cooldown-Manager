--- Glow layer reconciliation and read-only diagnostics.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:GetModule("Glow")
local Internal = Glow.Internal
local Skin = Addon:GetModule("Skin")
local Viewers = Addon:GetModule("Viewers")
local states = Internal.states
local GLOW_LEVEL_OFFSET, KEYS = Internal.GLOW_LEVEL_OFFSET, Internal.KEYS
function Glow:RefreshLayers()
    local borders = Addon:GetModule("Borders")
    Skin:RefreshNativeEffectLayers()
    for item, st in pairs(states) do
        Skin:CacheGlowRaster(item)
        local frame = st.frame
        if frame and frame:IsShown() then
            local level, strata = borders:GetOverlayLevel(frame, item:GetFrameLevel() + GLOW_LEVEL_OFFSET, item:GetFrameStrata())
            if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
            if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
        end
    end
end

function Glow:DescribeLayers()
    local Printer = Addon:GetModule("Printer")
    local function value(v) return issecretvalue(v) and "secret" or tostring(v) end
    for _, key in ipairs(KEYS) do
        Printer:Print(key .. " proc layers:")
        for index, item in ipairs(Viewers:GetItems(key)) do
            local st = states[item]
            local glow = st and st.frame
            if glow and glow:IsShown() then
                Printer:Print(string.format("item %d: icon=%s/%d glow=%s/%d target=%d bounds=%s,%s,%s,%s",
                    index, item:GetFrameStrata(), item:GetFrameLevel(),
                    glow:GetFrameStrata(), glow:GetFrameLevel(),
                    Addon:GetModule("Borders"):GetOverlayLevel(glow, item:GetFrameLevel() + GLOW_LEVEL_OFFSET),
                    value(glow:GetLeft()), value(glow:GetRight()), value(glow:GetTop()), value(glow:GetBottom())))
                local parent = glow:GetParent()
                for depth = 1, 4 do
                    if not parent then break end
                    Printer:Print(string.format("  parent %d: %s %s/%d clips=%s",
                        depth, parent:GetName() or "unnamed", parent:GetFrameStrata(), parent:GetFrameLevel(),
                        value(parent:DoesClipChildren())))
                    parent = parent:GetParent()
                end
            end
        end
        Addon:GetModule("Borders"):DescribeLayers(key)
    end
end
