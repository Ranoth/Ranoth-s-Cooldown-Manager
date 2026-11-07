local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Bars = Addon:GetModule("Bars")

function Bars:GetCastBarOptions()
    local group, s, set, color, hiddenUnlessCustom = self:CreateBarOptions("CastBar", 11, "Cast bar")
    group.args.showIcon = {
        type = "toggle", order = 8.5, name = "Show spell icon", hidden = hiddenUnlessCustom,
        desc = "Show a square spell icon inside the left end of the bar.",
        get = function() return s().showIcon end, set = set("showIcon"),
    }
    group.args.iconBorderSize = {
        type = "range", order = 8.6, name = "Icon border size", min = 0, max = 6, step = 1,
        hidden = hiddenUnlessCustom, disabled = function() return not s().showIcon end,
        get = function() return s().iconBorder.borderSize end,
        set = function(_, value)
            s().iconBorder.borderSize = value
            self:RefreshAll()
        end,
    }
    group.args.iconBorderColor = {
        type = "color", order = 8.7, name = "Icon border color", hasAlpha = true,
        hidden = hiddenUnlessCustom,
        disabled = function() return not s().showIcon or s().iconBorder.borderSize == 0 end,
        get = function()
            local c = s().iconBorder.borderColor
            return c.r, c.g, c.b, c.a
        end,
        set = function(_, r, g, b, a)
            s().iconBorder.borderColor = { r = r, g = g, b = b, a = a }
            self:RefreshAll()
        end,
    }
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

    return group
end
