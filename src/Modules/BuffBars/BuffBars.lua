--- BuffBars module for RanothsCooldownManager.
--- Optional alternate behaviour for the tracked-buff bar viewer: active bars are packed together
--- with no gaps for inactive buffs. When disabled, Blizzard's own layout is used untouched.
--- The viewer's own position stays under Edit Mode's control; only the bars inside it are re-anchored.
--- @module "BuffBars"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local BuffBars = RanothsCooldownManager:NewModule("BuffBars", "AceEvent-3.0", "AceHook-3.0")

local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Safe = RanothsCooldownManager:GetModule("Safe")
local Options = RanothsCooldownManager:GetModule("Options")

local KEY = "BuffBar"

local defaults = {
    profile = {
        compact = false, -- false = Blizzard's default behaviour
        growth = "DOWN", -- "DOWN" packs bars against the top of the viewer, "UP" against the bottom
        spacing = 2,
    },
}

local hookedItems = {}
local applying = false

--- Active bars in display order. Uses each item's layoutIndex when all items have one,
--- otherwise keeps the order GetItemFrames returned.
local function getActiveItems()
    local active = {}
    for _, item in ipairs(Viewers:GetItems(KEY)) do
        if item:IsShown() then
            active[#active + 1] = item
        end
    end

    local allIndexed = #active > 0
    for _, item in ipairs(active) do
        if type(item.layoutIndex) ~= "number" then
            allIndexed = false
            break
        end
    end
    if allIndexed then
        table.sort(active, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    return active
end

--- Re-anchor the active bars one after another. Item frames are not protected, so this also runs in combat,
--- which matters because buffs mostly change during combat.
function BuffBars:Apply()
    if applying or not self.db.profile.compact then return end
    local viewer = Viewers:Get(KEY)
    if not viewer then return end

    applying = true
    local profile = self.db.profile
    local selfPoint, relPoint, viewerPoint, sign = "TOPLEFT", "BOTTOMLEFT", "TOPLEFT", -1
    if profile.growth == "UP" then
        selfPoint, relPoint, viewerPoint, sign = "BOTTOMLEFT", "TOPLEFT", "BOTTOMLEFT", 1
    end

    local prev
    for _, item in ipairs(getActiveItems()) do
        Safe.ClearAllPoints(item)
        if prev then
            Safe.SetPoint(item, selfPoint, prev, relPoint, 0, sign * profile.spacing)
        else
            Safe.SetPoint(item, selfPoint, viewer, viewerPoint)
        end
        prev = item
    end
    applying = false
end

--- Hide/show of a single bar changes who is active, so repack immediately.
--- Hooked once per pooled item frame.
local function hookItems()
    for _, item in ipairs(Viewers:GetItems(KEY)) do
        if not hookedItems[item] then
            hookedItems[item] = true
            BuffBars:SecureHookScript(item, "OnShow", "Apply")
            BuffBars:SecureHookScript(item, "OnHide", "Apply")
        end
    end
end

function BuffBars:OnViewerRefreshed()
    hookItems()
    self:Apply()
end

local function hookViewer()
    local viewer = Viewers:Get(KEY)
    if viewer and viewer.RefreshLayout and not BuffBars:IsHooked(viewer, "RefreshLayout") then
        BuffBars:SecureHook(viewer, "RefreshLayout", "OnViewerRefreshed")
    end
    hookItems()
end

function BuffBars:OnViewerAvailable(_, key)
    if key == KEY then
        hookViewer()
        self:Apply()
    end
end

--- Turn the alternate behaviour on or off. Turning it off needs no action: the next time Blizzard refreshes
--- the viewer it lays the bars out itself. We do not call RefreshLayout, since that would run Blizzard code tainted.
--- @param enabled boolean
function BuffBars:SetCompact(enabled)
    self.db.profile.compact = enabled and true or false
    if enabled then
        hookViewer()
        self:Apply()
    end
end

function BuffBars:GetOptions()
    local function profile() return self.db.profile end
    return {
        type = "group",
        name = "Buff bars",
        args = {
            description = {
                type = "description",
                order = 1,
                name = "Blizzard leaves a gap for every inactive tracked buff. Compacting packs the active bars together.",
            },
            compact = {
                type = "toggle",
                order = 2,
                name = "Compact active bars",
                get = function() return profile().compact end,
                set = function(_, value) self:SetCompact(value) end,
            },
            growth = {
                type = "select",
                order = 3,
                name = "Pack towards",
                values = { DOWN = "Top of the viewer", UP = "Bottom of the viewer" },
                disabled = function() return not profile().compact end,
                get = function() return profile().growth end,
                set = function(_, value)
                    profile().growth = value
                    self:Apply()
                end,
            },
            spacing = {
                type = "range",
                order = 4,
                name = "Spacing",
                min = 0, max = 20, step = 1,
                disabled = function() return not profile().compact end,
                get = function() return profile().spacing end,
                set = function(_, value)
                    profile().spacing = value
                    self:Apply()
                end,
            },
        },
    }
end

function BuffBars:OnProfileRefresh()
    if self.db.profile.compact then
        hookViewer()
        self:Apply()
    end
end

function BuffBars:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("BuffBars", defaults)
    Options:Register("BuffBars", self:GetOptions(), 20)
end

function BuffBars:OnEnable()
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerAvailable")
    hookViewer()
    self:Apply()
end

function BuffBars:OnDisable()
    wipe(hookedItems)
end
