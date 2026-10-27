local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Borders = Addon:GetModule("Borders")

function Borders:GetToggle(kind)
    return {
        type = "toggle", order = 3, name = "Shared borders",
        desc = "Draw touching " .. (kind == "icons" and "icon-to-icon" or "bar-to-bar and bar-to-viewer icon")
            .. " borders as a single centered seam without changing layout. Uses the thicker border and the upper/left element's color.",
        get = function() return self.db.profile[kind] end,
        set = function(_, value)
            self:SetShared(kind, value)
        end,
    }
end
