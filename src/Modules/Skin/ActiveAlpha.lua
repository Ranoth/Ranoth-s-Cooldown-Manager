local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha

-- Child alpha multiplies with the viewer's, so to lift active icons above the viewer's opacity the viewer itself is
-- kept at 1 and the opacity Blizzard asked for is applied to the icons instead.
local baseAlpha = {} -- key -> opacity Blizzard set on the viewer
local alphaApplied = {} -- key -> true while we own the viewer's alpha
local itemAlpha = setmetatable({}, { __mode = "k" })
local alphaHooked = {}
local alphaItems = {}
local alphaItemKeys = setmetatable({}, { __mode = "k" })
local alphaItemHooked = setmetatable({}, { __mode = "k" })
local updateActiveAlpha

local function hookViewerAlpha(key, viewer)
    if alphaHooked[viewer] then return end
    alphaHooked[viewer] = true
    hooksecurefunc(viewer, "SetAlpha", function(_, alpha)
        baseAlpha[key] = alpha
        if alphaApplied[key] then updateActiveAlpha(key) end
    end)
end

local function isItemActive(key, item)
    return key == "BuffIcon" or item.wasSetFromAura == true
end

local function updateItemAlpha(item)
    local key = alphaItemKeys[item]
    if not key or not alphaApplied[key] then return end
    local a = isItemActive(key, item) and 1 or (baseAlpha[key] or 1)
    if itemAlpha[item] ~= a then
        itemAlpha[item] = a
        rawSetAlpha(item, a)
    end
end

updateActiveAlpha = function(key)
    local viewer = Viewers:Get(key)
    local s = Skin.db.profile[key]
    if not viewer or not s then return end
    local items = alphaItems[key]
    if not items then return end
    hookViewerAlpha(key, viewer)

    if not s.activeOpaque then
        if alphaApplied[key] then
            alphaApplied[key] = nil
            rawSetAlpha(viewer, baseAlpha[key] or 1)
            for _, item in ipairs(items) do
                if alphaItemKeys[item] == key then
                    if itemAlpha[item] then rawSetAlpha(item, 1) end
                    itemAlpha[item] = nil
                    alphaItemKeys[item] = nil
                end
            end
        end
        return
    end

    if not alphaApplied[key] then
        baseAlpha[key] = baseAlpha[key] or viewer:GetAlpha()
        alphaApplied[key] = true
    end
    if viewer:GetAlpha() ~= 1 then rawSetAlpha(viewer, 1) end
    for _, item in ipairs(items) do
        if not item.trackerID or item:GetParent() == viewer then
            alphaItemKeys[item] = key
            -- This finishes after Blizzard has chosen between aura and cooldown display.
            if key ~= "BuffIcon" and not alphaItemHooked[item] and item.CacheCooldownValues then
                hooksecurefunc(item, "CacheCooldownValues", updateItemAlpha)
                alphaItemHooked[item] = true
            end
            updateItemAlpha(item)
        end
    end
end

Internal.RawSetAlpha = rawSetAlpha
Internal.ItemAlpha = itemAlpha
Internal.AlphaItems = alphaItems
Internal.AlphaItemKeys = alphaItemKeys
Internal.UpdateActiveAlpha = updateActiveAlpha
