local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")

function Bars:GetPrimaryPowerOptions()
    return (self:CreateBarOptions("Mana", 12, "Primary power bar"))
end
