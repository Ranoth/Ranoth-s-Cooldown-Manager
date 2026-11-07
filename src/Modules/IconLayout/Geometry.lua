--- Icon measurement, active ordering, native stride and row grouping.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:GetModule("IconLayout")
local Internal = IconLayout.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")

--- Position and size of an item in screen pixels, so frames with different scales compare correctly.
local function measure(item)
    local scale = item:GetEffectiveScale()
    local left, top = item:GetLeft(), item:GetTop()
    if not left or not top then return nil end
    return {
        frame = item,
        scale = scale,
        left = left * scale,
        top = top * scale,
        width = item:GetWidth() * scale,
        height = item:GetHeight() * scale,
    }
end

--- Shown icons in display order. Uses layoutIndex when every icon has one, otherwise reading order.
local function getActive(key)
    local active = {}
    local Trackers = RanothsCooldownManager:GetModule("CustomTrackers", true)
    if Trackers and Trackers.db then Trackers:SyncGeometry(key) end
    for _, item in ipairs(Viewers:GetItems(key)) do
        if item:IsShown() then
            local m = measure(item)
            if m then active[#active + 1] = m end
        end
    end

    local allIndexed = #active > 0
    for _, m in ipairs(active) do
        if not m.frame.trackerID and type(m.frame.layoutIndex) ~= "number" then
            allIndexed = false
            break
        end
    end
    table.sort(active, function(a, b)
        if a.frame.trackerID or b.frame.trackerID then
            if not a.frame.trackerID then return true end
            if not b.frame.trackerID then return false end
            return a.frame.trackerID < b.frame.trackerID
        end
        if allIndexed then return a.frame.layoutIndex < b.frame.layoutIndex end
        local ta, tb = math.floor(a.top + 0.5), math.floor(b.top + 0.5)
        if ta ~= tb then return ta > tb end
        return a.left < b.left
    end)
    if Trackers and Trackers.db then Trackers:OrderItems(active) end
    return active
end

--- Icons per row when compacting: the viewer's own stride when it has one, otherwise what fits in its width.
local function getStride(viewer, active, spacingPx)
    local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer
    local stride = container.stride or viewer.iconLimit
    if type(stride) == "number" and stride > 0 then
        return stride
    end
    local first = active[1]
    if not first then return 1 end
    local viewerWidth = viewer:GetWidth() * viewer:GetEffectiveScale()
    return math.max(1, math.floor((viewerWidth + spacingPx) / (first.width + spacingPx)))
end

--- Rows of the current layout, grouped by vertical position.
local function groupRows(active)
    local byTop, order = {}, {}
    for _, m in ipairs(active) do
        local top = math.floor(m.top + 0.5)
        if not byTop[top] then
            byTop[top] = {}
            order[#order + 1] = top
        end
        table.insert(byTop[top], m)
    end
    table.sort(order, function(a, b) return a > b end)

    local rows = {}
    for _, top in ipairs(order) do
        table.sort(byTop[top], function(a, b) return a.left < b.left end)
        rows[#rows + 1] = byTop[top]
    end
    return rows
end

Internal.GetActive = getActive
Internal.GetStride = getStride
Internal.GroupRows = groupRows
