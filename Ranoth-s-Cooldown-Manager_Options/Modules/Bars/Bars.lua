local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")

function Bars:GetOptions()
    return {
        type = "group", name = "Custom bars",
        args = {
            description = {
                type = "description",
                order = 1,
                name = "Draw your own cast bar, power bar and class power. The cast bar and power bar can also keep "
                    .. "Blizzard's bar (restyled in Resource skin). Blizzard's version of a bar is hidden while ours is used.",
            },
            CastBar = self:GetCastBarOptions(),
            Mana = self:GetPrimaryPowerOptions(),
            ClassPower = self:GetClassPowerOptions(),
        },
    }
end
