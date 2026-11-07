--- Centered, compact and combined custom/native icon placement.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:GetModule("IconLayout")
local Internal = IconLayout.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local applying, combined = Internal.applying, Internal.combined
local hasCustomItems, setContentHeight = Internal.HasCustomItems, Internal.SetContentHeight
local restore, place = Internal.Restore, Internal.Place
local getActive, getStride, groupRows = Internal.GetActive, Internal.GetStride, Internal.GroupRows
--- Re-anchor a viewer's active icons according to its settings. Icons are not protected frames,
--- so this also runs in combat, which matters because buffs mostly change during combat.
--- @param key string One of IconLayout.KEYS
function IconLayout:Apply(key)
    local settings = self.db.profile[key] or {}
    local custom = hasCustomItems(key)
    if applying[key] then return end
    if combined[key] and not custom then
        restore(key)
        combined[key] = nil
        setContentHeight(key, nil)
    end
    if not custom and not (settings.center or settings.compact) then return end

    local viewer = Viewers:Get(key)
    if not viewer or not viewer:GetLeft() or not viewer:GetTop() then return end

    local active = getActive(key)
    if #active == 0 then setContentHeight(key, nil); return end

    applying[key] = true
    local vs = viewer:GetEffectiveScale()
    local viewerLeft, viewerTop = viewer:GetLeft() * vs, viewer:GetTop() * vs
    local viewerWidth = viewer:GetWidth() * vs
    local spacingPx = self.db.profile.spacing * vs
    local rowSpacingPx = spacingPx
    if custom and not settings.compact then
        local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer
        -- Blizzard's grid applies padding in each icon's local coordinates, before its icon scale.
        local scale = active[1].scale
        spacingPx = (container.childXPadding or 0) * scale
        rowSpacingPx = (container.childYPadding or 0) * scale
    end

    if custom and not settings.compact then
        local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer
        local stride = getStride(viewer, active, spacingPx)
        local horizontal = container.isHorizontal ~= false
        local across = horizontal and math.min(stride, #active) or math.ceil(#active / stride)
        local down = horizontal and math.ceil(#active / stride) or math.min(stride, #active)
        local width, height = active[1].width, active[1].height
        local totalHeight = down * height + (down - 1) * rowSpacingPx
        for i, m in ipairs(active) do
            local column = horizontal and ((i - 1) % stride) or math.floor((i - 1) / stride)
            local row = horizontal and math.floor((i - 1) / stride) or ((i - 1) % stride)
            local count = across
            if horizontal then count = math.min(stride, #active - row * stride) end
            local rowWidth = count * width + (count - 1) * spacingPx
            local left = viewerLeft
            if settings.center or key == "Essential" then left = left + (viewerWidth - rowWidth) / 2
            elseif container.layoutFramesGoingRight == false then left = left + viewerWidth - rowWidth end
            if container.layoutFramesGoingRight == false then column = count - 1 - column end
            if container.layoutFramesGoingUp then row = down - 1 - row end
            place(m, viewer, left + column * (width + spacingPx), viewerTop - row * (height + rowSpacingPx))
        end
        combined[key] = true
        setContentHeight(key, totalHeight / vs, (across * width + (across - 1) * spacingPx) / vs)
    elseif settings.compact then
        local stride = getStride(viewer, active, spacingPx)
        local rowTop = viewerTop
        local contentWidth = 0
        for start = 1, #active, stride do
            local row, rowWidth, rowHeight = {}, 0, 0
            for i = start, math.min(start + stride - 1, #active) do
                row[#row + 1] = active[i]
                rowWidth = rowWidth + active[i].width + (#row > 1 and spacingPx or 0)
                rowHeight = math.max(rowHeight, active[i].height)
            end

            local x = viewerLeft
            contentWidth = math.max(contentWidth, rowWidth)
            if settings.center or key == "Essential" then x = viewerLeft + (viewerWidth - rowWidth) / 2 end
            for _, m in ipairs(row) do
                place(m, viewer, x, rowTop)
                x = x + m.width + spacingPx
            end
            rowTop = rowTop - rowHeight - rowSpacingPx
        end
        if custom then
            combined[key] = true
            setContentHeight(key, (viewerTop - rowTop - rowSpacingPx) / vs, contentWidth / vs)
        end
    else
        for _, row in ipairs(groupRows(active)) do
            local rowLeft = row[1].left
            local last = row[#row]
            local rowWidth = last.left + last.width - rowLeft
            local target = viewerLeft + (viewerWidth - rowWidth) / 2
            for _, m in ipairs(row) do
                place(m, viewer, target + (m.left - rowLeft), m.top)
            end
        end
    end
    applying[key] = false
    RanothsCooldownManager:GetModule("Borders"):Request()
end

function IconLayout:ApplyAll()
    for _, key in ipairs({ "Essential", "Utility", "BuffIcon" }) do
        self:Apply(key)
    end
end
