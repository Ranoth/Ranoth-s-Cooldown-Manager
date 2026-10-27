local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Skin = Addon:GetModule("Skin")
local LSM = LibStub("LibSharedMedia-3.0")

local LABELS = {
    Essential = "Essential cooldowns",
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

function Skin:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Change how the cooldown icons look. Every option defaults to Blizzard's look.",
        },
        itemCount = {
            type = "toggle",
            order = 2,
            name = "Healthstone charges",
            desc = "Show how many uses a Healthstone or Demonic Healthstone has left, in whichever viewer displays it.",
            get = function() return self.db.profile.itemCount end,
            set = function(_, value)
                self.db.profile.itemCount = value
                self:ApplyAll()
            end,
        },
    }

    for i, key in ipairs(self.KEYS) do
        local function s() return self.db.profile[key] end
        local function set(field)
            return function(_, value)
                s()[field] = value
                self:Apply(key)
            end
        end
        args[key] = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                square = {
                    type = "toggle",
                    order = 1,
                    name = "Square icons",
                    desc = "Remove Blizzard's rounded corners and frame.",
                    get = function() return s().square end,
                    set = set("square"),
                },
                zoom = {
                    type = "range",
                    order = 2,
                    name = "Zoom",
                    desc = "Crop the edges of the icon artwork.",
                    min = 0, max = 0.3, step = 0.01, isPercent = true,
                    get = function() return s().zoom end,
                    set = set("zoom"),
                },
                borderSize = {
                    type = "range",
                    order = 3,
                    name = "Border size",
                    desc = "0 hides the border.",
                    min = 0, max = 6, step = 1,
                    get = function() return s().borderSize end,
                    set = set("borderSize"),
                },
                borderColor = {
                    type = "color",
                    order = 4,
                    name = "Border color",
                    hasAlpha = true,
                    disabled = function() return s().borderSize == 0 end,
                    get = function()
                        local c = s().borderColor
                        return c.r, c.g, c.b, c.a
                    end,
                    set = function(_, r, g, b, a)
                        s().borderColor = { r = r, g = g, b = b, a = a }
                        self:Apply(key)
                    end,
                },
                countSize = {
                    type = "range",
                    order = 5,
                    name = "Stack text size",
                    desc = "0 keeps Blizzard's size.",
                    min = 0, max = 32, step = 1,
                    get = function() return s().countSize end,
                    set = set("countSize"),
                },
                countFont = {
                    type = "select",
                    order = 5.5,
                    name = "Stack text font",
                    desc = "Font of the stack count and the Healthstone charges.",
                    values = function()
                        local values = { [""] = "Blizzard default" }
                        for _, name in ipairs(LSM:List("font")) do values[name] = name end
                        return values
                    end,
                    get = function() return s().countFont end,
                    set = set("countFont"),
                },
                textOutline = {
                    type = "select",
                    order = 6.2,
                    name = "Text outline",
                    desc = "Outline of the cooldown countdown and the stack count.",
                    values = { [""] = "Blizzard default", NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" },
                    sorting = { "", "NONE", "OUTLINE", "THICKOUTLINE" },
                    get = function() return s().textOutline end,
                    set = set("textOutline"),
                },
                activeOpaque = {
                    type = "toggle",
                    order = 7,
                    name = "Full opacity when active",
                    desc = "Icons whose buff or aura is running are shown at 100% opacity, while the others keep the viewer's opacity set in Edit Mode.",
                    width = "double",
                    get = function() return s().activeOpaque end,
                    set = set("activeOpaque"),
                },
            },
        }
    end

    return { type = "group", name = "Icon skin", args = args }
end
