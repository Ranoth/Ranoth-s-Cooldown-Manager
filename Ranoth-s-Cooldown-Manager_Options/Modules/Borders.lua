local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Borders = Addon:GetModule("Borders")

function Borders:GetToggle()
    return {
        type = "toggle", order = 3, name = "Shared borders",
        desc = "Draw touching icon and bar borders as a single centered seam without changing layout. "
            .. "Includes bar-to-viewer contacts and restyled Blizzard bars. Uses the thicker border and the upper/left element's color.",
        get = function() return self.db.profile.enabled end,
        set = function(_, value)
            self:SetShared(value)
        end,
    }
end
