--- Screen-space seam ownership and non-overlapping border rectangles.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Internal = Addon:GetModule("Borders").Internal
local pixelSize

local function snap(value)
    return math.floor(value / pixelSize + 0.5) * pixelSize
end

local function pixelThickness(value)
    return math.max(1, math.floor(value / pixelSize + 0.5)) * pixelSize
end

local function rect(owner, left, bottom, right, top)
    return { owner = owner, left = left, bottom = bottom, right = right, top = top }
end

local function append(list, owner, left, bottom, right, top)
    if right > left and top > bottom then
        list[#list + 1] = rect(owner, left, bottom, right, top)
    end
end

-- Subtract a rectangle into at most four non-overlapping pieces.
local function subtract(source, cut, result)
    local left, bottom = math.max(source.left, cut.left), math.max(source.bottom, cut.bottom)
    local right, top = math.min(source.right, cut.right), math.min(source.top, cut.top)
    if left >= right or bottom >= top then
        result[#result + 1] = source
        return
    end
    append(result, source.owner, source.left, source.bottom, left, source.top)
    append(result, source.owner, right, source.bottom, source.right, source.top)
    append(result, source.owner, left, source.bottom, right, bottom)
    append(result, source.owner, left, top, right, source.top)
end

local function cutPieces(pieces, cut)
    local intersects = false
    for _, piece in ipairs(pieces) do
        if piece.left < cut.right and piece.right > cut.left and piece.bottom < cut.top and piece.top > cut.bottom then
            intersects = true
            break
        end
    end
    if not intersects then return pieces end
    local result = {}
    for _, piece in ipairs(pieces) do subtract(piece, cut, result) end
    return result
end

local function sharedVertical(a, b, seams)
    local bottom, top = math.max(a.bottom, b.bottom), math.min(a.top, b.top)
    local gap = b.left - a.right
    local reach = a.thickness + b.thickness
    if top <= bottom or a.left >= b.left or a.right >= b.right or gap > 0.01 or gap < -reach - 0.01 then return end
    -- Native icon padding can overlap frame bounds. Do not treat diagonal corner overlap as a neighbor.
    if gap < -0.01 and top - bottom <= reach then return end
    local thickness = pixelThickness(math.max(a.thickness, b.thickness))
    local left = snap((a.right + b.left - thickness) / 2)
    bottom, top = snap(bottom), snap(top)
    if top <= bottom then return end
    seams[#seams + 1] = rect(a, left, bottom, left + thickness, top)
    -- Overlapping icon bounds move the centered seam farther inside both icons.
    a.glowRight = math.max(a.glowRight or 0, a.right - left)
    b.glowLeft = math.max(b.glowLeft or 0, left + thickness - b.left)
    local cut = rect(a, -math.huge, bottom, math.huge, top)
    a.sides[4] = cutPieces(a.sides[4], cut)
    b.sides[3] = cutPieces(b.sides[3], cut)
end

local function sharedHorizontal(a, b, seams)
    local left, right = math.max(a.left, b.left), math.min(a.right, b.right)
    local gap = a.bottom - b.top
    local reach = a.thickness + b.thickness
    if right <= left or a.top <= b.top or a.bottom <= b.bottom or gap > 0.01 or gap < -reach - 0.01 then return end
    if gap < -0.01 and right - left <= reach then return end
    local thickness = pixelThickness(math.max(a.thickness, b.thickness))
    local bottom = snap((a.bottom + b.top - thickness) / 2)
    if a.kind == "bars" or b.kind == "bars" then
        -- Continue the centered line across overhangs instead of stepping back to an inset edge.
        left, right = math.min(a.left, b.left), math.max(a.right, b.right)
        a.sides[2], b.sides[1] = {}, {}
    end
    left, right = snap(left), snap(right)
    if right <= left then return end
    seams[#seams + 1] = rect(a, left, bottom, right, bottom + thickness)
    -- Use the rendered seam, including mixed-width bar overhangs, rather than a nominal half border.
    a.glowBottom = math.max(a.glowBottom or -math.huge, bottom + thickness - a.bottom)
    b.glowTop = math.max(b.glowTop or -math.huge, b.top - bottom)
    local cut = rect(a, left, -math.huge, right, math.huge)
    a.sides[2] = cutPieces(a.sides[2], cut)
    b.sides[1] = cutPieces(b.sides[1], cut)
end

local function buildPieces(active, currentPixelSize)
    pixelSize = currentPixelSize
    local candidates = {}
    for _, entry in ipairs(active) do
        local l, b, r, t = snap(entry.left), snap(entry.bottom), snap(entry.right), snap(entry.top)
        local s = pixelThickness(entry.thickness)
        entry.glowLeft, entry.glowRight = nil, nil
        entry.glowTop, entry.glowBottom = nil, nil
        entry.sides = {
            { rect(entry, l, t - s, r, t) }, { rect(entry, l, b, r, b + s) },
            { rect(entry, l, b, l + s, t) }, { rect(entry, r - s, b, r, t) },
        }
    end
    for i, a in ipairs(active) do
        for j = i + 1, #active do
            local b = active[j]
            if b.top < a.bottom - 0.01 then break end
            if b.left <= a.right + 0.01 and b.right >= a.left - 0.01 then
                sharedVertical(a, b, candidates)
                sharedVertical(b, a, candidates)
                sharedHorizontal(a, b, candidates)
                sharedHorizontal(b, a, candidates)
            end
        end
    end
    for _, seam in ipairs(candidates) do seam.shared = true end
    for _, entry in ipairs(active) do
        for _, side in ipairs(entry.sides) do
            for _, piece in ipairs(side) do candidates[#candidates + 1] = piece end
        end
        entry.sides = nil
    end
    -- Seams take priority. Removing all overlap also avoids darker translucent corners and junctions.
    local drawn = {}
    for _, candidate in ipairs(candidates) do
        local pieces = { candidate }
        for _, previous in ipairs(drawn) do
            pieces = cutPieces(pieces, previous)
            if #pieces == 0 then break end
        end
        for _, piece in ipairs(pieces) do
            piece.shared = candidate.shared
            drawn[#drawn + 1] = piece
        end
    end
    return drawn
end

Internal.BuildPieces = buildPieces
