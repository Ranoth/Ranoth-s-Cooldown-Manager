local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")
local function profile(key) return Bars.db.profile[key] end

local DESTRUCTION = 3
function Bars:GetClassPowerOptions()
    local group, s, set, color = self:CreateBarOptions("ClassPower", 13, "Class power")
    group.args.primaryPower = {
        type = "toggle", order = 1, name = "Show main resource", width = "double",
        desc = "For specs with a main resource and mana but no class power (Elemental Shaman, Shadow Priest, "
            .. "Balance Druid...), show the main resource here and mana on the primary power bar. "
            .. "Requires the custom primary power bar.",
        disabled = function() return profile("Mana").mode ~= "custom" end,
        get = function() return s().primaryPower end, set = set("primaryPower"),
    }
    group.args.inactive = color(22, "Empty segment color", "inactive", nil)
    group.args.wholeShards = {
        type = "toggle", order = 1.5, name = "Whole shards only", width = "double",
        desc = "Affliction and Demonology: fill a soul shard segment only once the shard is complete, "
            .. "hiding partial fragments from out-of-combat regeneration.",
        hidden = function()
            return select(2, UnitClass("player")) ~= "WARLOCK" or GetSpecialization() == DESTRUCTION
        end,
        get = function() return s().wholeShards end, set = set("wholeShards"),
    }
    group.args.dividerSize = {
        type = "range", order = 23, name = "Divider thickness",
        desc = "Line drawn between segments, in the border color. 0 hides it.",
        min = 0, max = 6, step = 1,
        get = function() return s().dividerSize end, set = set("dividerSize"),
    }

    return group
end
