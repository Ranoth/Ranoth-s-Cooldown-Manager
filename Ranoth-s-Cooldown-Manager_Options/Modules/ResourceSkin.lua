local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local ResourceSkin = Addon:GetModule("ResourceSkin")
local LSM = LibStub("LibSharedMedia-3.0")
local DEFAULT_TEXTURE = "Default"
local STATUS_BAR = { CastBar = true, Mana = true }

local LABELS = {
    CastBar = "Cast bar",
    Mana = "Mana bar",
    ClassPower = "Class power",
}

local function textureValues()
    local values = { [DEFAULT_TEXTURE] = "Blizzard default" }
    for _, name in ipairs(LSM:List("statusbar")) do
        values[name] = name
    end
    return values
end

function ResourceSkin:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Restyle Blizzard's resource bars. Every option defaults to Blizzard's look. "
                .. "Turning a color or texture option off may need a /reload to fully restore Blizzard's color.",
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
        local function colorOption(order, name, field, disabled)
            return {
                type = "color",
                order = order,
                name = name,
                hasAlpha = true,
                disabled = disabled,
                get = function()
                    local c = s()[field]
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    s()[field] = { r = r, g = g, b = b, a = a }
                    self:Apply(key)
                end,
            }
        end

        local group = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                background = {
                    type = "toggle",
                    order = 10,
                    name = "Background",
                    get = function() return s().background end,
                    set = set("background"),
                },
                backgroundColor = colorOption(11, "Background color", "backgroundColor",
                    function() return not s().background end),
                borderSize = {
                    type = "range",
                    order = 12,
                    name = "Border size",
                    desc = "0 hides the border.",
                    min = 0, max = 6, step = 1,
                    get = function() return s().borderSize end,
                    set = set("borderSize"),
                },
                borderColor = colorOption(13, "Border color", "borderColor",
                    function() return s().borderSize == 0 end),
            },
        }
        if STATUS_BAR[key] then
            group.args.texture = {
                type = "select",
                order = 1,
                name = "Bar texture",
                values = textureValues,
                get = function() return s().texture end,
                set = set("texture"),
            }
            group.args.useColor = {
                type = "toggle",
                order = 2,
                name = "Custom color",
                get = function() return s().useColor end,
                set = set("useColor"),
            }
            group.args.color = colorOption(3, "Bar color", "color", function() return not s().useColor end)
            group.args.hideArt = {
                type = "toggle",
                order = 4,
                name = "Hide Blizzard frame art",
                desc = "Hide Blizzard's border and background artwork on this bar.",
                get = function() return s().hideArt end,
                set = set("hideArt"),
            }
        end
        args[key] = group
    end

    return { type = "group", name = "Resource skin", args = args }
end
