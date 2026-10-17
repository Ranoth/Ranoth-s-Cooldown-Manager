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
local Options = RanothsCooldownManager:GetModule("Options")

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

function IconLayout:Request(key)
    local settings = self.db.profile[key]
    if not settings or not (settings.center or settings.compact) then return end
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
        end
    end
end

local function isSupported(key)
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
    for _, item in ipairs(Viewers:GetItems(key)) do
        if item:IsShown() then
            local m = measure(item)
            if m then active[#active + 1] = m end
        end
    end

    local allIndexed = #active > 0
    for _, m in ipairs(active) do
        if type(m.frame.layoutIndex) ~= "number" then
            allIndexed = false
            break
        end
    end
    table.sort(active, function(a, b)
        if allIndexed then return a.frame.layoutIndex < b.frame.layoutIndex end
        local ta, tb = math.floor(a.top + 0.5), math.floor(b.top + 0.5)
        if ta ~= tb then return ta > tb end
        return a.left < b.left
    end)
    return active
end

--- Icons per row when compacting: the viewer's own stride when it has one, otherwise what fits in its width.
local function getStride(viewer, active, spacingPx)
    if type(viewer.stride) == "number" and viewer.stride > 0 then
        return viewer.stride
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
    savePoints(m.frame)
    Safe.ClearAllPoints(m.frame)
    Safe.SetPoint(m.frame, "TOPLEFT", viewer, "TOPLEFT", x, y)
end

--- Re-anchor a viewer's active icons according to its settings. Icons are not protected frames,
--- so this also runs in combat, which matters because buffs mostly change during combat.
--- @param key string One of IconLayout.KEYS
function IconLayout:Apply(key)
    local settings = self.db.profile[key]
    if not settings or applying[key] or not (settings.center or settings.compact) then return end

    local viewer = Viewers:Get(key)
    if not viewer or not viewer:GetLeft() or not viewer:GetTop() then return end

    local active = getActive(key)
    if #active == 0 then return end

    applying[key] = true
    local vs = viewer:GetEffectiveScale()
    local viewerLeft, viewerTop = viewer:GetLeft() * vs, viewer:GetTop() * vs
    local viewerWidth = viewer:GetWidth() * vs
    local spacingPx = self.db.profile.spacing * vs

    if settings.compact then
        local stride = getStride(viewer, active, spacingPx)
        local rowTop = viewerTop
        for start = 1, #active, stride do
            local row, rowWidth, rowHeight = {}, 0, 0
            for i = start, math.min(start + stride - 1, #active) do
                row[#row + 1] = active[i]
                rowWidth = rowWidth + active[i].width + (#row > 1 and spacingPx or 0)
                rowHeight = math.max(rowHeight, active[i].height)
            end

            local x = viewerLeft
            if settings.center then x = viewerLeft + (viewerWidth - rowWidth) / 2 end
            for _, m in ipairs(row) do
                place(m, viewer, x, rowTop)
                x = x + m.width + spacingPx
            end
            rowTop = rowTop - rowHeight - spacingPx
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
end

function IconLayout:ApplyAll()
    for _, key in ipairs(self.KEYS) do
        self:Apply(key)
    end
end

local function hookItems(key)
    for _, item in ipairs(Viewers:GetItems(key)) do
        if not hookedItems[item] then
            hookedItems[item] = true
            local function apply() IconLayout:Request(key) end
            IconLayout:SecureHookScript(item, "OnShow", apply)
            IconLayout:SecureHookScript(item, "OnHide", apply)
        end
    end
end

local viewerHooks = {}

local function hookViewer(key)
    local viewer = Viewers:Get(key)
    if not viewer then return end
    if not viewerHooks[viewer] then
        viewerHooks[viewer] = true
        local function relayout()
            -- Blizzard just re-anchored every icon, so any saved anchors are stale
            for _, item in ipairs(Viewers:GetItems(key)) do savedPoints[item] = nil end
            IconLayout:Request(key)
        end
        -- Layout() also runs on its own when Edit Mode changes the icon size, without RefreshLayout.
        if viewer.RefreshLayout then IconLayout:SecureHook(viewer, "RefreshLayout", relayout) end
        if viewer.Layout then IconLayout:SecureHook(viewer, "Layout", relayout) end
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
    if settings.center or settings.compact then
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

local LABELS = {
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

function IconLayout:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Center each row of icons in its viewer, or pack the active icons together without gaps.",
        },
        spacing = {
            type = "range",
            order = 2,
            name = "Compact spacing",
            desc = "Gap between icons when compacting.",
            min = 0, max = 20, step = 1,
            get = function() return self.db.profile.spacing end,
            set = function(_, value)
                self.db.profile.spacing = value
                self:ApplyAll()
            end,
        },
    }

    for i, key in ipairs(self.KEYS) do
        args[key] = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                center = {
                    type = "toggle",
                    order = 1,
                    name = "Center icons",
                    get = function() return self.db.profile[key].center end,
                    set = function(_, value) self:SetOption(key, "center", value) end,
                },
            },
        }
        if self.db.profile[key].compact ~= nil then
            args[key].args.compact = {
                type = "toggle",
                order = 2,
                name = "Compact icons",
                get = function() return self.db.profile[key].compact end,
                set = function(_, value) self:SetOption(key, "compact", value) end,
            }
        end
    end

    return { type = "group", name = "Icons", args = args }
end

function IconLayout:OnProfileRefresh()
    for _, key in ipairs(self.KEYS) do
        local settings = self.db.profile[key]
        if settings.center or settings.compact then
            hookViewer(key)
            self:Apply(key)
        else
            restore(key)
        end
    end
end

function IconLayout:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("IconLayout", defaults)
    Options:Register("IconLayout", self:GetOptions(), 30)
end

function IconLayout:OnEnable()
    self:RegisterMessage(REQUESTED, "OnLayoutRequested")
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerAvailable")
    for _, key in ipairs(self.KEYS) do
        hookViewer(key)
    end
    self:ApplyAll()
end

function IconLayout:OnDisable()
    wipe(hookedItems)
    wipe(viewerHooks)
    wipe(applying)
end
