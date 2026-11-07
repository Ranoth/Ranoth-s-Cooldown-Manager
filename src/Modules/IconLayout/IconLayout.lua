--- Viewer/item hooks, profile controls and icon layout lifecycle.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:GetModule("IconLayout")
local Internal = IconLayout.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Safe = RanothsCooldownManager:GetModule("Safe")
local defaults, REQUESTED = Internal.defaults, Internal.REQUESTED
local applying, combined, savedPoints = Internal.applying, Internal.combined, Internal.savedPoints
local hasCustomItems, restore = Internal.HasCustomItems, Internal.Restore
local hookedItems = {}

function IconLayout:Request(key)
    local settings = self.db.profile[key]
    if not combined[key] and not hasCustomItems(key) and not (settings and (settings.center or settings.compact)) then return end
    Safe:Notify(REQUESTED, key)
end

local function isSupported(key)
    if key == "Essential" then return hasCustomItems(key) or combined[key] end
    for _, k in ipairs(IconLayout.KEYS) do
        if k == key then return true end
    end
    return false
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
