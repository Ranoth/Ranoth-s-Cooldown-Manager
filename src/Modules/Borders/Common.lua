--- Border module, persistent settings and shared registration state.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Borders = Addon:NewModule("Borders", "AceEvent-3.0")

Borders.Internal = {
    defaults = { profile = { enabled = false } },
    REQUESTED = "RCM_BORDERS_REQUESTED",
    entries = {},
    active = {},
    dirty = false,
    refreshChanged = false,
}
