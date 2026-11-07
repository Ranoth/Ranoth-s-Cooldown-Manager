local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")
local LSM = LibStub("LibSharedMedia-3.0")
local function profile(key) return Bars.db.profile[key] end

local function mediaValues(kind)
    local values = {}
    for _, name in ipairs(LSM:List(kind)) do values[name] = name end
    return values
end

function Bars:CreateBarOptions(key, order, label)
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
        type = "group", inline = true, order = order, name = label,
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

    if key ~= "CastBar" then
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
    return group, s, set, color, hiddenUnlessCustom
end
