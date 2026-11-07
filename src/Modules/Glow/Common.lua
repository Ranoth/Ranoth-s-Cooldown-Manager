--- Proc glow module, defaults and shared owner/effect state.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:NewModule("Glow", "AceEvent-3.0")
local owners, states = {}, {}
local previews = {} -- Session-only; never saved to a profile.
function Glow:GetPreview(key) return previews[key] == true end
function Glow:SetPreview(key, value) previews[key] = value end

local function settings()
    return {
        enabled = false,
        color = { r = 1, g = 0.82, b = 0, a = 1 },
        thickness = 2,
        length = 10,
        speed = 0.25,
    }
end

local defaults = { profile = {
    Essential = settings(), Utility = settings(), BuffIcon = settings(),
} }

Glow.Internal = {
    defaults = defaults,
    owners = owners,
    states = states,
    previews = previews,
    GLOW_LEVEL_OFFSET = 8,
    KEYS = { "Essential", "Utility", "BuffIcon" },
}
