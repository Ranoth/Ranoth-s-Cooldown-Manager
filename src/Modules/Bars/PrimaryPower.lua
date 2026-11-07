--- Custom primary resource / mana bar.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:GetModule("Bars")
local Internal = Bars.Internal
local frames, profile = Internal.frames, Internal.profile
local newFrame = Internal.newFrame
local newStatusBar = Internal.newStatusBar
local newText = Internal.newText
local styleBorder = Internal.styleBorder
local styleBar = Internal.styleBar
local styleText = Internal.styleText
local setShown = Internal.setShown
local powerColor = Internal.powerColor
local movedPrimary = Internal.movedPrimary
local hasValue = Internal.hasValue
local setPowerText = Internal.setPowerText
local MANA = Internal.MANA

Internal.defaults.profile.Mana = Internal.merge(Internal.common(), {
    mode = "custom",
    usePowerColor = true,
    color = { r = 0, g = 0.5, b = 1, a = 1 },
    showText = false,
    textFormat = "value",
})

function Bars:RefreshPower()
    local frame, s = frames.Mana, profile("Mana")
    if not frame or s.mode ~= "custom" then return end

    local powerType, token = UnitPowerType("player")
    if movedPrimary() then powerType, token = MANA, "MANA" end
    local max = UnitPowerMax("player", powerType)
    if not powerType or not hasValue(max) then
        setShown("Mana", false)
        return
    end

    if frame.styledPower ~= powerType then
        local c = s.color
        local r, g, b, a = c.r, c.g, c.b, c.a
        if s.usePowerColor then
            r, g, b = powerColor(token, powerType)
            a = 1
        end
        frame.bar:SetStatusBarColor(r, g, b, a)
        frame.styledPower = powerType
    end
    -- Secret maxima cannot be compared or retained as cache keys.
    if issecretvalue(max) then
        frame.bar:SetMinMaxValues(0, max)
        frame.powerMax = nil
    elseif frame.powerMax ~= max then
        frame.bar:SetMinMaxValues(0, max)
        frame.powerMax = max
    end
    local value = UnitPower("player", powerType)
    frame.bar:SetValue(value)
    frame.text:SetShown(s.showText)
    if s.showText then setPowerText(frame.text, s.textFormat, powerType, value, max) end
    setShown("Mana", true)
end

function Internal.BuildPrimaryPower()
    local power = newFrame()
    power.bar = newStatusBar(power)
    power.text = newText(power.bar, "CENTER")
    power.text:SetPoint("CENTER")
    frames.Mana = power
end

function Internal.StylePrimaryPower()
    local frame, s = frames.Mana, profile("Mana")
    frame.bg:SetVertexColor(s.background.r, s.background.g, s.background.b, s.background.a)
    styleBorder(frame, s, "Mana")
    styleBar(frame.bar, s)
    styleText(frame.text, s)
    -- Reapply power-dependent styling after settings/profile changes, not on every value update.
    frame.styledPower = nil
    frame.powerMax = nil
end
