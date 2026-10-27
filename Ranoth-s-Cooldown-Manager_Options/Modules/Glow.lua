local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Glow = Addon:GetModule("Glow")
local KEYS = { "Essential", "Utility", "BuffIcon" }
local LABELS = { Essential = "Essential cooldowns", Utility = "Utility cooldowns", BuffIcon = "Buff icons" }

function Glow:GetOptions()
    local NativeGlows = Addon:GetModule("NativeGlows", true)
    local args = {
        description = {
            type = "description", order = 1,
            name = "Choose between Blizzard's glows and square custom ones for each icon effect. Only active effects animate. Action-bar alerts are unchanged.",
        },
    }
    for i, key in ipairs(KEYS) do
        local function s() return self.db.profile[key] end
        local function set(field)
            return function(_, value)
                s()[field] = value
                self:OnProfileRefresh()
            end
        end
        local viewerArgs = {
            proc = {
                type = "group", inline = true, order = 1, name = "Proc glow",
                args = {
                    enabled = {
                        type = "toggle", order = 1, name = "Custom proc glow",
                        desc = "Replace Blizzard's proc/activation alert with moving pixel lines.",
                        get = function() return s().enabled end, set = set("enabled"),
                    },
                    preview = {
                        type = "toggle", order = 1.5, name = "Preview glow",
                        desc = "Show the glow on this viewer's icons without requiring a proc. Not saved between reloads.",
                        disabled = function() return not s().enabled end,
                        get = function() return self:GetPreview(key) end,
                        set = function(_, value)
                            self:SetPreview(key, value)
                            self:OnProfileRefresh()
                        end,
                    },
                    color = {
                        type = "color", order = 2, name = "Glow color", hasAlpha = true,
                        disabled = function() return not s().enabled end,
                        get = function() local c = s().color; return c.r, c.g, c.b, c.a end,
                        set = function(_, r, g, b, a)
                            s().color = { r = r, g = g, b = b, a = a }
                            self:OnProfileRefresh()
                        end,
                    },
                    thickness = {
                        type = "range", order = 3, name = "Line thickness", min = 1, max = 5, step = 1,
                        disabled = function() return not s().enabled end,
                        get = function() return s().thickness end, set = set("thickness"),
                    },
                    length = {
                        type = "range", order = 4, name = "Line length", min = 2, max = 20, step = 1,
                        disabled = function() return not s().enabled end,
                        get = function() return s().length end, set = set("length"),
                    },
                    speed = {
                        type = "range", order = 5, name = "Speed", min = 0.05, max = 1, step = 0.05,
                        disabled = function() return not s().enabled end,
                        get = function() return s().speed end, set = set("speed"),
                    },
                },
            },
        }
        if NativeGlows then
            for name, option in pairs(NativeGlows:GetViewerOptions(key)) do viewerArgs[name] = option end
        end
        args[key] = { type = "group", order = i + 1, name = LABELS[key], args = viewerArgs }
    end
    return { type = "group", name = "Icon glows", childGroups = "tab", args = args }
end
