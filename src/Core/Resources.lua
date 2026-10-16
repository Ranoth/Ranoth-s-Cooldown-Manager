--- Resources module for RanothsCooldownManager.
--- Single point of contact with Blizzard's player resource frames (mana bar, class power, cast bar).
--- Mirrors Viewers: lookup, hooks, and messages. Feature modules should not touch these globals directly.
--- @module "Resources"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Resources = RanothsCooldownManager:NewModule("Resources", "AceEvent-3.0", "AceHook-3.0")

local Safe = RanothsCooldownManager:GetModule("Safe")
local Printer = RanothsCooldownManager:GetModule("Printer")

--- Handlers receive (message, key, frame).
Resources.MESSAGES = {
    AVAILABLE = "RCM_RESOURCE_AVAILABLE",
    SHOWN = "RCM_RESOURCE_SHOWN",
    HIDDEN = "RCM_RESOURCE_HIDDEN",
    CHANGED = "RCM_RESOURCE_CHANGED",
}

--- Stable iteration order.
Resources.KEYS = { "Mana", "ClassPower", "CastBar" }

--- Candidate lookups per key, tried in order; the first frame that exists wins.
--- Strings are dotted paths from _G; ClassPower is a table of such lists keyed by class token.
--- Blizzard moves these between patches, so edit this table only.
Resources.CANDIDATES = {
    Mana = {
        "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar",
        "PlayerFrameManaBar",
        "PlayerFrame.manabar",
    },
    -- Blizzard creates every class's frame and hides the irrelevant ones, so this is keyed by class token.
    ClassPower = {
        DEATHKNIGHT = { "RuneFrame" },
        DRUID = { "DruidComboPointBarFrame", "ComboPointPlayerFrame" },
        EVOKER = { "EssencePlayerFrame" },
        MAGE = { "MageArcaneChargesFrame" },
        MONK = { "MonkHarmonyBarFrame" },
        PALADIN = { "PaladinPowerBarFrame" },
        ROGUE = { "ComboPointPlayerFrame" },
        WARLOCK = { "WarlockPowerFrame" },
    },
    CastBar = {
        "PlayerCastingBarFrame",
        "CastingBarFrame",
    },
}

local resolved = {}
local hooked = {}

local function resolvePath(path)
    local obj = _G
    for part in path:gmatch("[^%.]+") do
        if type(obj) ~= "table" then return nil end
        obj = obj[part]
        if obj == nil then return nil end
    end
    return obj
end

--- Find the frame for a key, caching the result once found.
--- @param key string One of Resources.KEYS
--- @return Frame|nil frame
--- @return string|nil path Which candidate matched
function Resources:Get(key)
    local cached = resolved[key]
    if cached and cached.frame then
        return cached.frame, cached.path
    end

    local list = self.CANDIDATES[key]
    if key == "ClassPower" then
        local _, classToken = UnitClass("player")
        list = list and list[classToken]
    end

    for _, path in ipairs(list or {}) do
        local frame = resolvePath(path)
        if type(frame) == "table" and frame.GetObjectType then
            resolved[key] = { frame = frame, path = path }
            return frame, path
        end
    end
    return nil
end

--- Iterate over every resource frame that currently exists.
--- @usage `for key, frame in Resources:Iterate() do ... end`
function Resources:Iterate()
    local i = 0
    return function()
        while i < #self.KEYS do
            i = i + 1
            local key = self.KEYS[i]
            local frame = self:Get(key)
            if frame then return key, frame end
        end
    end
end

--- Run a function now, or as soon as combat ends if in lockdown.
--- @param func function
function Resources:RunWhenSafe(func)
    Safe:RunWhenSafe(func)
end

--- Print which candidate matched for each key. Useful after a Blizzard patch.
function Resources:Describe()
    for _, key in ipairs(self.KEYS) do
        local frame, path = self:Get(key)
        Printer:Print(key, frame and ("-> " .. path) or "-> not found")
    end
end

local function notify(message, key, frame)
    Safe:Notify(message, key, frame)
end

local function hookResource(key, frame)
    if not frame or hooked[frame] then return end
    hooked[frame] = true

    Resources:SecureHookScript(frame, "OnShow", function()
        notify(Resources.MESSAGES.SHOWN, key, frame)
    end)
    Resources:SecureHookScript(frame, "OnHide", function()
        notify(Resources.MESSAGES.HIDDEN, key, frame)
    end)

    Resources:SendMessage(Resources.MESSAGES.AVAILABLE, key, frame)
end

--- Hook any resource frame that exists and is not hooked yet.
function Resources:Scan()
    for key, frame in self:Iterate() do
        hookResource(key, frame)
    end
end

-- Spec, form, and talent changes can swap the class power frame or its contents.
local function onResourcesChanged()
    resolved.ClassPower = nil
    Resources:Scan()
    local frame = Resources:Get("ClassPower")
    if frame then
        notify(Resources.MESSAGES.CHANGED, "ClassPower", frame)
    end
end

function Resources:PLAYER_SPECIALIZATION_CHANGED(_, unit)
    if unit == "player" then onResourcesChanged() end
end

function Resources:PLAYER_ENTERING_WORLD()
    onResourcesChanged()
end

function Resources:UPDATE_SHAPESHIFT_FORM()
    onResourcesChanged()
end

function Resources:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:Scan()
end

function Resources:OnDisable()
    -- AceHook and AceEvent clean up automatically; hooks must be re-created on next enable.
    wipe(hooked)
    wipe(resolved)
end
