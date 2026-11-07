local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
function Skin:GetGlowInset(key)
    local size = self.db.profile[key].borderSize
    local borders = RanothsCooldownManager:GetModule("Borders")
    -- Shared seams are centered on the icon boundary rather than fully inset.
    return borders.db.profile.enabled and not borders:IsExcluded(key) and size / 2 or size
end

function Skin:GetGlowInsets(item, key)
    local inset = self:GetGlowInset(key)
    item = item and (item.glowItem or item)
    local left, right = RanothsCooldownManager:GetModule("Borders"):GetHorizontalGlowInsets(item, inset)
    local top, bottom = RanothsCooldownManager:GetModule("Borders"):GetVerticalGlowInsets(item, inset)
    return left, right, top, bottom
end

local glowRaster = setmetatable({}, { __mode = "k" })

function Skin:CacheGlowRaster(item)
    if InCombatLockdown() then return end
    local icon = item.Icon or item
    local left, bottom = icon:GetLeft(), icon:GetBottom()
    local width, height, scale = icon:GetWidth(), icon:GetHeight(), icon:GetEffectiveScale()
    local _, screenHeight = GetPhysicalScreenSize()
    if issecretvalue(left) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height)
        or issecretvalue(scale) or left == nil or bottom == nil or width <= 0 or height <= 0 or scale <= 0 then
        return
    end
    local pixel = UIParent:GetHeight() * UIParent:GetEffectiveScale() / screenHeight / scale
    local raster = glowRaster[item] or {}
    raster.left, raster.top, raster.width, raster.height, raster.pixel = left, bottom + height, width, height, pixel
    glowRaster[item] = raster
end

function Skin:GetCustomGlowInsets(item, key, thickness)
    local left, right, top, bottom = self:GetGlowInsets(item, key)
    local owner = item and (item.glowItem or item)
    local raster = owner and glowRaster[owner]
    if raster then
        local pixel = raster.pixel
        local function snap(value) return math.floor(value / pixel + 0.5) * pixel end
        left = snap(raster.left + left) - raster.left
        right = raster.left + raster.width - snap(raster.left + raster.width - right)
        top = raster.top - snap(raster.top - top)
        bottom = snap(raster.top - raster.height + bottom) - (raster.top - raster.height)
        thickness = math.max(pixel, snap(thickness))
    end
    return left, right, top, bottom, thickness
end

local nativeSizes = setmetatable({}, { __mode = "k" })

function Skin:GetNativeEffectInsets(item, key, kind)
    local left, right, top, bottom = self:GetGlowInsets(item, key)
    if kind == "proc" then
        local icon = item.Icon or item
        local width, height = icon:GetWidth(), icon:GetHeight()
        if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
            local size = nativeSizes[icon] or {}
            size[1], size[2] = width, height
            nativeSizes[icon] = size
        else
            local size = nativeSizes[icon]
            if not size then return end
            width, height = size[1], size[2]
        end
        -- Blizzard's proc art includes transparent margins in its 1.4x button-sized frame.
        local x = math.max(0, width - left - right) * 0.2
        local y = math.max(0, height - top - bottom) * 0.2
        return left - x, right - x, top - y, bottom - y
    elseif kind == "alerts" then
        local owner = item.glowItem or item
        local scale = owner.GetVisualAlertAnchorScale and owner:GetVisualAlertAnchorScale() or 1
        return left - 8 * scale, right - 9 * scale, top - 8 * scale, bottom - 9 * scale
    elseif kind == "debuff" then
        return left - 3, right - 3, top - 3, bottom - 3
    end
    return left, right, top, bottom
end
