--- Safe module for RanothsCooldownManager.
--- Shared combat-lockdown queue and debounced message dispatch.
--- @module "Safe"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Safe = RanothsCooldownManager:NewModule("Safe", "AceEvent-3.0")

local safeQueue = {}
local pendingNotify = {}

-- Raw C methods. Blizzard's Edit Mode wraps SetPoint/ClearAllPoints on its system frames in Lua,
-- and calling those wrappers from addon code runs them tainted. Use these on any Blizzard frame we anchor.
local frameMethods = getmetatable(UIParent).__index
Safe.SetPoint = frameMethods.SetPoint
Safe.ClearAllPoints = frameMethods.ClearAllPoints

--- Run a function now, or as soon as combat ends if in lockdown.
--- Use for anything that touches protected frames (size, anchors, show/hide).
--- @param func function
function Safe:RunWhenSafe(func)
    if InCombatLockdown() then
        safeQueue[#safeQueue + 1] = func
    else
        func()
    end
end

function Safe:PLAYER_REGEN_ENABLED()
    -- Swap first so functions queued while flushing go to the next flush.
    local queue = safeQueue
    safeQueue = {}
    for _, func in ipairs(queue) do
        xpcall(func, CallErrorHandler)
    end
end

--- Send an AceEvent message once per frame, even if requested several times.
--- Deferring also keeps listeners from re-entering Blizzard's code.
--- Duplicates are merged per message and key; the first call's extra arguments win.
--- @param message string
--- @param key string Distinguishes sources of the same message (e.g. a viewer key)
--- @param ... any Extra arguments passed to listeners after key
function Safe:Notify(message, key, ...)
    local id = message .. key
    if pendingNotify[id] then return end
    pendingNotify[id] = true
    local extra = { ... }
    local extraCount = select("#", ...)
    C_Timer.After(0, function()
        pendingNotify[id] = nil
        Safe:SendMessage(message, key, unpack(extra, 1, extraCount))
    end)
end

function Safe:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Safe:OnDisable()
    wipe(safeQueue)
    wipe(pendingNotify)
end
