--- Custom tracker module, persistent settings and shared frame registry.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:NewModule("CustomTrackers", "AceEvent-3.0")
local GROUPS = { Essential = "Essential cooldowns", Utility = "Utility cooldowns", BuffIcon = "Buff icons" }
local defaults = { profile = { entries = {}, nextID = 1 } }
local frames = {}
local pool = {}
local SLOTS = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest",
    [6] = "Waist (belt)", [7] = "Legs", [8] = "Feet", [9] = "Wrists", [10] = "Hands",
    [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back", [16] = "Main hand", [17] = "Off hand", [19] = "Tabard",
}
Trackers.SLOTS, Trackers.GROUPS = SLOTS, GROUPS

Trackers.Internal = {
    defaults = defaults,
    frames = frames,
    pool = pool,
}
