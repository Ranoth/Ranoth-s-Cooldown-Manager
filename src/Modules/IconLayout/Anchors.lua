--- Original-anchor preservation, restoration and incremental icon attachment.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:GetModule("IconLayout")
local Internal = IconLayout.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Safe = RanothsCooldownManager:GetModule("Safe")
local savedPoints = Internal.savedPoints
local function savePoints(item)
    if savedPoints[item] then return end
    local points = {}
    for i = 1, item:GetNumPoints() do
        points[i] = { item:GetPoint(i) }
    end
    savedPoints[item] = points
end

--- Put the icons of a viewer back where Blizzard anchored them.
local function restore(key)
    for _, item in ipairs(Viewers:GetItems(key)) do
        local points = savedPoints[item]
        if points then
            savedPoints[item] = nil
            Safe.ClearAllPoints(item)
            for _, p in ipairs(points) do
                Safe.SetPoint(item, p[1], p[2], p[3], p[4], p[5])
            end
            RanothsCooldownManager:GetModule("Borders"):Request()
        end
    end
end

local function place(m, viewer, left, top)
    local vs = viewer:GetEffectiveScale()
    local x = (left - viewer:GetLeft() * vs) / m.scale
    local y = (top - viewer:GetTop() * vs) / m.scale
    local item = m.frame
    savePoints(item)
    -- Layout passes repeat for unchanged icons; re-anchoring them would only dirty the client's layout.
    if item:GetNumPoints() == 1 then
        local point, relative, relativePoint, px, py = item:GetPoint(1)
        if not (issecretvalue(point) or issecretvalue(relativePoint) or issecretvalue(px) or issecretvalue(py))
            and point == "TOPLEFT" and relative == viewer and relativePoint == "TOPLEFT"
            and type(px) == "number" and type(py) == "number"
            and math.abs(px - x) < 1e-4 and math.abs(py - y) < 1e-4 then
            return
        end
    end
    Safe.ClearAllPoints(item)
    Safe.SetPoint(item, "TOPLEFT", viewer, "TOPLEFT", x, y)
end

Internal.Restore = restore
Internal.Place = place
