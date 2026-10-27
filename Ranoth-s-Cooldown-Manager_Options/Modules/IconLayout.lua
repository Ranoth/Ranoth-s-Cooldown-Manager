local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local IconLayout = Addon:GetModule("IconLayout")

local LABELS = {
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

function IconLayout:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Center each row of icons in its viewer, or pack the active icons together without gaps.",
        },
        spacing = {
            type = "range",
            order = 2,
            name = "Compact spacing",
            desc = "Gap between icons when compacting.",
            min = 0, max = 20, step = 1,
            get = function() return self.db.profile.spacing end,
            set = function(_, value)
                self.db.profile.spacing = value
                self:ApplyAll()
            end,
        },
    }

    for i, key in ipairs(self.KEYS) do
        args[key] = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                center = {
                    type = "toggle",
                    order = 1,
                    name = "Center icons",
                    get = function() return self.db.profile[key].center end,
                    set = function(_, value) self:SetOption(key, "center", value) end,
                },
            },
        }
        if self.db.profile[key].compact ~= nil then
            args[key].args.compact = {
                type = "toggle",
                order = 2,
                name = "Compact icons",
                get = function() return self.db.profile[key].compact end,
                set = function(_, value) self:SetOption(key, "compact", value) end,
            }
        end
    end

    return { type = "group", name = "Icons", args = args }
end
