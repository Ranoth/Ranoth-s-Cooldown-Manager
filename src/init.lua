--- Initialize the addon and set up the settings database.
--- @module "Init"

local addon_name, _ = ... -- Gets the addon's name from the API provisioned in the TOC file
local RanothsCooldownManager = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")

local defaults = {
    profile = {
        language = "enUS",
        debug = false,
    },
}

function RanothsCooldownManager:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RanothsCooldownManagerDB", defaults, true)
end

function RanothsCooldownManager:OnEnable()
end

function RanothsCooldownManager:OnDisable()
end
