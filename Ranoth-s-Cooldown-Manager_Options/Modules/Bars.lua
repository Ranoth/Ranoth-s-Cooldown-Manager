local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")
local LSM = LibStub("LibSharedMedia-3.0")
local DESTRUCTION = 3
local function profile(key) return Bars.db.profile[key] end

local LABELS = { CastBar = "Cast bar", Mana = "Primary power bar", ClassPower = "Class power" }

local function mediaValues(kind)
    local values = {}
    for _, name in ipairs(LSM:List(kind)) do values[name] = name end
    return values
end

function Bars:GetOptions()
    local args = {
        sharedBorders = RanothsCooldownManager:GetModule("Borders"):GetToggle("bars"),
        description = {
            type = "description",
            order = 1,
            name = "Draw your own cast bar, power bar and class power. The cast bar and power bar can also keep "
                .. "Blizzard's bar (restyled in Resource skin). Blizzard's version of a bar is hidden while ours is used.",
        },
    }

    for i, key in ipairs(self.KEYS) do
        local function s() return profile(key) end
        local function custom() return key == "ClassPower" or s().mode == "custom" end
        local function set(field)
            return function(_, value)
                s()[field] = value
                self:RefreshAll()
            end
        end
        local function color(order, name, field, disabled)
            return {
                type = "color", order = order, name = name, hasAlpha = true, disabled = disabled,
                get = function() local c = s()[field]; return c.r, c.g, c.b, c.a end,
                set = function(_, r, g, b, a)
                    s()[field] = { r = r, g = g, b = b, a = a }
                    self:RefreshAll()
                end,
            }
        end
        local function hiddenUnlessCustom() return not custom() end

        local group = {
            type = "group", inline = true, order = 10 + i, name = LABELS[key],
            args = {
                texture = {
                    type = "select", order = 2, name = "Bar texture",
                    values = function() return mediaValues("statusbar") end,
                    hidden = hiddenUnlessCustom,
                    get = function() return s().texture end, set = set("texture"),
                },
                background = color(3, "Background color", "background", nil),
                borderSize = {
                    type = "range", order = 4, name = "Border size", min = 0, max = 6, step = 1,
                    get = function() return s().borderSize end, set = set("borderSize"),
                },
                borderColor = color(5, "Border color", "borderColor", function()
                    return s().borderSize == 0 and (key ~= "ClassPower" or s().dividerSize == 0)
                end),
            },
        }
        group.args.background.hidden = function() return key == "ClassPower" or not custom() end
        group.args.borderSize.hidden = hiddenUnlessCustom
        group.args.borderColor.hidden = hiddenUnlessCustom

        if key ~= "ClassPower" then
            group.args.mode = {
                type = "select", order = 1, name = "Bar", style = "dropdown",
                values = { blizzard = "Blizzard's bar (restyled)", custom = "Custom bar" },
                get = function() return s().mode end,
                set = function(_, value) self:SetMode(key, value) end,
            }
        end
        group.args.font = {
            type = "select", order = 6, name = "Font",
            values = function() return mediaValues("font") end, hidden = hiddenUnlessCustom,
            get = function() return s().font end, set = set("font"),
        }
        group.args.fontSize = {
            type = "range", order = 7, name = "Font size", min = 6, max = 32, step = 1, hidden = hiddenUnlessCustom,
            get = function() return s().fontSize end, set = set("fontSize"),
        }
        group.args.textShadow = {
            type = "toggle", order = 7.5, name = "Text shadow", hidden = hiddenUnlessCustom,
            get = function() return s().textShadow end, set = set("textShadow"),
        }
        group.args.shadowOffset = {
            type = "range", order = 7.6, name = "Shadow offset", min = 1, max = 4, step = 1,
            hidden = hiddenUnlessCustom, disabled = function() return not s().textShadow end,
            get = function() return s().shadowOffset end, set = set("shadowOffset"),
        }
        group.args.fontOutline = {
            type = "select", order = 7.7, name = "Text outline", hidden = hiddenUnlessCustom,
            desc = "An outline hides most of a shadow. Pick \"None\" for a pure drop shadow.",
            values = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" },
            sorting = { "NONE", "OUTLINE", "THICKOUTLINE" },
            get = function() return s().fontOutline end, set = set("fontOutline"),
        }
        group.args.showText = {
            type = "toggle", order = 8, name = key == "CastBar" and "Show spell name" or "Show value",
            hidden = hiddenUnlessCustom,
            get = function() return s().showText end, set = set("showText"),
        }

        if key == "CastBar" then
            group.args.showTime = {
                type = "toggle", order = 9, name = "Show time left", hidden = hiddenUnlessCustom,
                get = function() return s().showTime end, set = set("showTime"),
            }
            group.args.color = color(20, "Cast color", "color", nil)
            group.args.channelColor = color(21, "Channel color", "channelColor", nil)
            group.args.shieldColor = color(22, "Not interruptible color", "shieldColor", nil)
            group.args.preview = {
                type = "execute", order = 30, name = "Preview cast", hidden = hiddenUnlessCustom,
                func = function() self:PreviewCast() end,
            }
            group.args.interruptEffect = {
                type = "toggle", order = 24, name = "Interrupt effect", hidden = hiddenUnlessCustom,
                desc = "Flash the bar and fade it out when your cast is interrupted.",
                get = function() return s().interruptEffect end, set = set("interruptEffect"),
            }
            group.args.interruptColor = color(25, "Interrupt color", "interruptColor",
                function() return not s().interruptEffect end)
            group.args.interruptColor.hidden = hiddenUnlessCustom
            group.args.previewInterrupt = {
                type = "execute", order = 31, name = "Preview interrupt", hidden = hiddenUnlessCustom,
                func = function() self:ShowInterrupt() end,
            }
            for _, name in ipairs({ "color", "channelColor", "shieldColor" }) do
                group.args[name].hidden = hiddenUnlessCustom
            end
        else
            group.args.usePowerColor = {
                type = "toggle", order = 20, name = "Use power color", hidden = hiddenUnlessCustom,
                get = function() return s().usePowerColor end, set = set("usePowerColor"),
            }
            group.args.textFormat = {
                type = "select", order = 8.5, name = "Text format", hidden = hiddenUnlessCustom,
                disabled = function() return not s().showText end,
                values = { value = "Value", percent = "Percentage", both = "Value - Percentage" },
                get = function() return s().textFormat end, set = set("textFormat"),
            }
            group.args.color = color(21, "Bar color", "color", function() return s().usePowerColor end)
            group.args.color.hidden = hiddenUnlessCustom
        end

        if key == "ClassPower" then
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
        end
        if key ~= "CastBar" then
            -- The height lives in Layout, which sizes every stacked entry; this is the same setting.
            group.args.height = {
                type = "range", order = 3.5, name = "Height", min = 4, max = 60, step = 1,
                get = function()
                    return RanothsCooldownManager:GetModule("Layout").db.profile.stack[key].height
                end,
                set = function(_, value)
                    local layout = RanothsCooldownManager:GetModule("Layout")
                    layout.db.profile.stack[key].height = value
                    layout:Request()
                end,
            }
        end
        args[key] = group
    end

    return { type = "group", name = "Custom bars", args = args }
end
