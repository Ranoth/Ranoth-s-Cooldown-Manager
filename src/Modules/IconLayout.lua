--- IconLayout module for RanothsCooldownManager.
--- Optional alternate layouts for the icon viewers (Essential, Utility, BuffIcon):
---  * center: every row of icons is centered in the viewer instead of growing from the left.
---  * compact: active icons are packed together in order, with no gaps for inactive ones.
--- Both default to off, which leaves Blizzard's layout untouched. The viewer's own position stays with Edit Mode.
--- @module "IconLayout"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:NewModule("IconLayout", "AceEvent-3.0", "AceHook-3.0")

local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Safe = RanothsCooldownManager:GetModule("Safe")

-- Essential is already centered and never hides icons, Utility never hides icons, so only BuffIcon can compact.
IconLayout.KEYS = { "Utility", "BuffIcon" }

local defaults = {
    profile = {
        spacing = 2, -- gap between icons, only used by compact
        Utility = { center = false },
        BuffIcon = { center = false, compact = false },
    },
}

local hookedItems = {}
local applying = {}
local savedPoints = {} -- item -> Blizzard's anchors before we moved it
local REQUESTED = "RCM_ICON_LAYOUT_REQUESTED"
local combined = {}
local contentHeights = {}
local contentWidths = {}

local function hasCustomItems(key)
    local Trackers = RanothsCooldownManager:GetModule("CustomTrackers", true)
    return Trackers and Trackers.db and Trackers:HasActiveItems(key)
end

function IconLayout:GetContentHeight(key)
    return contentHeights[key]
end

function IconLayout:GetContentWidth(key)
    return contentWidths[key]
end

local function setContentHeight(key, height, width)
    if contentHeights[key] == height and contentWidths[key] == width then return end
    contentHeights[key] = height
    contentWidths[key] = width
    RanothsCooldownManager:GetModule("Layout"):Request()
end

function IconLayout:Request(key)
    local settings = self.db.profile[key]
    if not combined[key] and not hasCustomItems(key) and not (settings and (settings.center or settings.compact)) then return end
    Safe:Notify(REQUESTED, key)
end

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

local function isSupported(key)
    if key == "Essential" then return hasCustomItems(key) or combined[key] end
    for _, k in ipairs(IconLayout.KEYS) do
        if k == key then return true end
    end
    return false
end

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

local function hookItems(key)
    for _, item in ipairs(Viewers:GetItems(key)) do
        if not hookedItems[item] then
            hookedItems[item] = true
            local function apply()
                if item.trackerID then
                    for _, group in ipairs({ "Essential", "Utility", "BuffIcon" }) do IconLayout:Request(group) end
                else
                    IconLayout:Request(key)
                end
            end
            IconLayout:SecureHookScript(item, "OnShow", apply)
            IconLayout:SecureHookScript(item, "OnHide", apply)
        end
    end
end

local viewerHooks = {}
local containerHooks = {}

local function hookViewer(key)
    local viewer = Viewers:Get(key)
    if not viewer then return end
    local function relayout()
        -- Blizzard just re-anchored every icon, so any saved anchors are stale
        for _, item in ipairs(Viewers:GetItems(key)) do savedPoints[item] = nil end
        IconLayout:Request(key)
    end
    if not viewerHooks[viewer] then
        viewerHooks[viewer] = true
        -- Layout() also runs on its own when Edit Mode changes the icon size, without RefreshLayout.
        if viewer.RefreshLayout then IconLayout:SecureHook(viewer, "RefreshLayout", relayout) end
        if viewer.Layout then IconLayout:SecureHook(viewer, "Layout", relayout) end
    end
    local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()
    if container and container ~= viewer and not containerHooks[container] then
        containerHooks[container] = true
        IconLayout:SecureHook(container, "Layout", relayout)
    end
    hookItems(key)
end

function IconLayout:OnLayoutRequested(_, key)
    hookItems(key)
    self:Apply(key)
end

function IconLayout:OnViewerAvailable(_, key)
    if isSupported(key) then
        hookViewer(key)
        self:Apply(key)
    end
end

--- Change a setting and apply it. Turning everything off for a viewer needs no action: the next time Blizzard
--- refreshes the viewer it lays the icons out itself. We do not call RefreshLayout, since that would run Blizzard code tainted.
--- @param key string One of IconLayout.KEYS
--- @param option string "center" or "compact"
--- @param value boolean
--- @return boolean success
function IconLayout:SetOption(key, option, value)
    local settings = self.db.profile[key]
    if not settings or settings[option] == nil then return false end

    settings[option] = value and true or false
    hookViewer(key)
    if settings.center or settings.compact or hasCustomItems(key) then
        self:Apply(key)
    else
        restore(key)
    end
    return true
end

--- @param key string One of IconLayout.KEYS
--- @return string
function IconLayout:Describe(key)
    local s = self.db.profile[key]
    local text = key .. ": center " .. (s.center and "on" or "off")
    if s.compact ~= nil then text = text .. ", compact " .. (s.compact and "on" or "off") end
    return text
end

function IconLayout:OnProfileRefresh()
    for _, key in ipairs(self.KEYS) do
        local settings = self.db.profile[key]
        if settings.center or settings.compact or hasCustomItems(key) then
            hookViewer(key)
            self:Apply(key)
        else
            restore(key)
        end
    end
    self:Apply("Essential")
end

function IconLayout:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("IconLayout", defaults)
end

function IconLayout:OnEnable()
    self:RegisterMessage(REQUESTED, "OnLayoutRequested")
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerAvailable")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerAvailable")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerAvailable")
    for _, key in ipairs(self.KEYS) do
        hookViewer(key)
    end
    self:ApplyAll()
end

function IconLayout:OnDisable()
    wipe(hookedItems)
    wipe(viewerHooks)
    wipe(containerHooks)
    wipe(applying)
end
