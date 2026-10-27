local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local BuffBars = Addon:GetModule("BuffBars")

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
