--- Viewers module for RanothsCooldownManager.
--- Single point of contact with Blizzard's Cooldown Manager frames.
--- Feature modules should use this instead of touching the viewer globals directly.
--- @module "Viewers"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Viewers = RanothsCooldownManager:NewModule("Viewers", "AceEvent-3.0", "AceHook-3.0")

--- Messages sent through AceEvent. Subscribe with `module:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "Handler")`.
--- Handlers receive (message, key, viewer).
Viewers.MESSAGES = {
    AVAILABLE = "RCM_VIEWER_AVAILABLE",
    LAYOUT_UPDATED = "RCM_VIEWER_LAYOUT_UPDATED",
    SHOWN = "RCM_VIEWER_SHOWN",
}

--- Logical key -> global frame name of the Blizzard viewer.
Viewers.FRAME_NAMES = {
    Essential = "EssentialCooldownViewer",
    Utility = "UtilityCooldownViewer",
    BuffIcon = "BuffIconCooldownViewer",
    BuffBar = "BuffBarCooldownViewer",
}
 
--- Stable iteration order.
Viewers.KEYS = { "Essential", "Utility", "BuffIcon", "BuffBar" }

local Safe = RanothsCooldownManager:GetModule("Safe")

local hooked = {}

--- Get a viewer frame by key.
--- @param key string One of Viewers.KEYS
--- @return Frame|nil
function Viewers:Get(key)
    local name = self.FRAME_NAMES[key]
    return name and _G[name] or nil
end

--- Iterate over every viewer that currently exists.
--- @usage `for key, viewer in Viewers:Iterate() do ... end`
function Viewers:Iterate()
    local i = 0
    return function()
        while i < #self.KEYS do
            i = i + 1
            local key = self.KEYS[i]
            local viewer = self:Get(key)
            if viewer then return key, viewer end
        end
    end
end

--- Get the currently active item frames (icons or bars) of a viewer.
--- @param key string One of Viewers.KEYS
--- @return table items
function Viewers:GetNativeItems(key)
    local viewer = self:Get(key)
    local items = {}
    if not viewer then return items end

    if viewer.GetItemFrames then
        for _, item in ipairs(viewer:GetItemFrames()) do
            items[#items + 1] = item
        end
        return items
    end

    -- Fallback when the mixin method is unavailable: cooldown items carry a cooldown ID.
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.GetCooldownID or child.cooldownID then
            items[#items + 1] = child
        end
    end
    return items
end

function Viewers:GetItems(key)
    local items = self:GetNativeItems(key)
    local Trackers = RanothsCooldownManager:GetModule("CustomTrackers", true)
    if Trackers and Trackers.db then
        for _, item in ipairs(Trackers:GetItems(key)) do items[#items + 1] = item end
    end
    return items
end

--- Thin wrapper kept for convenience; see Safe:RunWhenSafe.
--- @param func function
function Viewers:RunWhenSafe(func)
    Safe:RunWhenSafe(func)
end

local function queueNotify(message, key, viewer)
    Safe:Notify(message, key, viewer)
end

local function hookViewer(key, viewer)
    if hooked[key] or not viewer then return end
    hooked[key] = true

    if viewer.RefreshLayout then
        Viewers:SecureHook(viewer, "RefreshLayout", function()
            queueNotify(Viewers.MESSAGES.LAYOUT_UPDATED, key, viewer)
        end)
    end
    -- Edit Mode changes such as icon size only re-run Layout(), without RefreshLayout, but still resize the viewer.
    if viewer.Layout then
        Viewers:SecureHook(viewer, "Layout", function()
            queueNotify(Viewers.MESSAGES.LAYOUT_UPDATED, key, viewer)
        end)
    end
    for _, setter in ipairs({ "SetTimerShown", "SetTooltipsShown" }) do
        if viewer[setter] then
            Viewers:SecureHook(viewer, setter, function()
                queueNotify(Viewers.MESSAGES.LAYOUT_UPDATED, key, viewer)
            end)
        end
    end
    Viewers:SecureHookScript(viewer, "OnShow", function()
        queueNotify(Viewers.MESSAGES.SHOWN, key, viewer)
    end)

    Viewers:SendMessage(Viewers.MESSAGES.AVAILABLE, key, viewer)
end

--- Hook any viewer that exists and is not hooked yet.
function Viewers:Scan()
    for key, viewer in self:Iterate() do
        hookViewer(key, viewer)
    end
end

function Viewers:ADDON_LOADED(_, loadedName)
    if loadedName == "Blizzard_CooldownViewer" then
        self:Scan()
    end
end

function Viewers:OnEnable()
    self:RegisterEvent("ADDON_LOADED")
    self:Scan()
end

function Viewers:OnDisable()
    -- AceHook and AceEvent clean up automatically; hooks must be re-created on next enable.
    wipe(hooked)
end
