local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local NativeGlows = Addon:GetModule("NativeGlows")

function NativeGlows:GetViewerOptions(key)
    local function s(effect) return self.db.profile[key][effect] end
    local function getter(effect, field) return function() return s(effect)[field] end end
    local function setter(effect, field)
        return function(_, value) s(effect)[field] = value; self:Refresh() end
    end
    local function off(effect) return function() return not s(effect).custom end end
    local function color(effect, order, name, disabled)
        return {
            type = "color", order = order, name = name, hasAlpha = true, disabled = disabled or off(effect),
            get = function() local c = s(effect).color; return c.r, c.g, c.b, c.a end,
            set = function(_, r, g, b, a) s(effect).color = { r = r, g = g, b = b, a = a }; self:Refresh() end,
        }
    end
    local function toggle(effect, order, name, desc)
        return { type = "toggle", order = order, name = name, desc = desc,
            get = getter(effect, "custom"), set = setter(effect, "custom") }
    end
    local function range(effect, field, order, name, min, max, step, disabled)
        return { type = "range", order = order, name = name, min = min, max = max, step = step,
            disabled = disabled or off(effect), get = getter(effect, field), set = setter(effect, field) }
    end

    local args = {
        pandemic = {
            type = "group", inline = true, order = 2, name = "Pandemic glow",
            args = {
                custom = toggle("pandemic", 1, "Custom pandemic glow",
                    "Replace Blizzard's rounded pandemic ring with a square edge inside the icon border."),
                color = color("pandemic", 2, "Color"),
                thickness = range("pandemic", "thickness", 3, "Thickness", 1, 5, 1),
                pulse = { type = "toggle", order = 4, name = "Pulse", disabled = off("pandemic"),
                    get = getter("pandemic", "pulse"), set = setter("pandemic", "pulse") },
                speed = range("pandemic", "speed", 5, "Pulse duration", 0.2, 2, 0.1,
                    function() return not s("pandemic").custom or not s("pandemic").pulse end),
            },
        },
        alerts = {
            type = "group", inline = true, order = 3, name = "Visual alerts",
            args = {
                description = { type = "description", order = 0,
                    name = "Marching ants and flash alerts set in Blizzard's Cooldown Manager alert settings." },
                custom = toggle("alerts", 1, "Custom visual alerts",
                    "Marching ants become moving pixel lines; flashes become a pulsing square edge."),
                useAlertColor = { type = "toggle", order = 2, name = "Use alert color",
                    desc = "Use the color chosen for the alert in Blizzard's settings.", disabled = off("alerts"),
                    get = getter("alerts", "useAlertColor"), set = setter("alerts", "useAlertColor") },
                color = color("alerts", 3, "Color",
                    function() return not s("alerts").custom or s("alerts").useAlertColor end),
                thickness = range("alerts", "thickness", 4, "Thickness", 1, 5, 1),
                length = range("alerts", "length", 5, "Ant length", 2, 20, 1),
                speed = range("alerts", "speed", 6, "Ant speed", 0.05, 1, 0.05),
            },
        },
        debuff = {
            type = "group", inline = true, order = 5, name = "Debuff border",
            args = {
                custom = toggle("debuff", 1, "Custom debuff border",
                    "Replace Blizzard's debuff border with a square edge in the debuff type's color."),
                thickness = range("debuff", "thickness", 2, "Thickness", 1, 5, 1),
            },
        },
    }
    if key ~= "BuffIcon" then
        args.flash = {
            type = "group", inline = true, order = 4, name = "Ready flash",
            args = {
                custom = toggle("flash", 1, "Custom ready flash",
                    "Two lines start at opposite corners and each travel clockwise halfway around the icon before the cooldown ends."),
                color = color("flash", 2, "Color"),
                thickness = range("flash", "thickness", 3, "Thickness", 1, 5, 1),
                duration = range("flash", "duration", 4, "Animation duration", 0.2, 2, 0.05),
            },
        }
    end
    return args
end
