--- Custom class resources: segments, runes, shards and moved primary power.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:GetModule("Bars")
local Internal = Bars.Internal
local frames, profile = Internal.frames, Internal.profile
local newFrame = Internal.newFrame
local newText = Internal.newText
local styleBorder = Internal.styleBorder
local styleBar = Internal.styleBar
local styleText = Internal.styleText
local setShown = Internal.setShown
local powerColor = Internal.powerColor
local classPowerInfo = Internal.classPowerInfo
local movedPrimary = Internal.movedPrimary
local hasValue = Internal.hasValue
local setPowerText = Internal.setPowerText
local WHITE, MAX_SEGMENTS = Internal.WHITE, Internal.MAX_SEGMENTS
local DESTRUCTION = 3 -- Destruction always shows shard fragments.

Internal.defaults.profile.ClassPower = Internal.merge(Internal.common(), {
    usePowerColor = true,
    color = { r = 1, g = 0.8, b = 0.2, a = 1 },
    inactive = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
    dividerSize = 1,
    primaryPower = false, -- show the main resource here and mana on the primary power bar
    showText = false,
    textFormat = "value",
    wholeShards = true, -- Affliction/Demonology soul shards fill only when complete, hiding regen fragments
})

local function setClassText(frame, s, powerType, value, max)
    frame.text:SetShown(s.showText)
    if s.showText then setPowerText(frame.text, s.textFormat, powerType, value, max) end
end

local function layoutSegments(frame, count)
    local s = profile("ClassPower")
    local width = frame:GetWidth()
    if width <= 0 or count <= 0 then return end
    -- Segments touch each other; dividers are drawn over the seams.
    local segmentWidth = width / count
    for i = 1, MAX_SEGMENTS do
        local seg = frame.segments[i]
        if i <= count then
            seg:ClearAllPoints()
            seg:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * segmentWidth, 0)
            seg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * segmentWidth, 0)
            seg:SetWidth(segmentWidth)
            seg:Show()
        else
            seg:Hide()
        end
    end

    local c = s.borderColor
    for i = 1, MAX_SEGMENTS - 1 do
        local divider = frame.dividers[i]
        if i < count and s.dividerSize > 0 then
            divider:ClearAllPoints()
            divider:SetPoint("TOP", frame, "TOPLEFT", i * segmentWidth, 0)
            divider:SetPoint("BOTTOM", frame, "BOTTOMLEFT", i * segmentWidth, 0)
            divider:SetWidth(s.dividerSize)
            divider:SetVertexColor(c.r, c.g, c.b, c.a)
            divider:Show()
        else
            divider:Hide()
        end
    end
    frame.count = count
end

local updateRunes
local function onRuneUpdate(frame, elapsed)
    frame.runeElapsed = (frame.runeElapsed or 0) + elapsed
    if frame.runeElapsed < 0.05 then return end
    frame.runeElapsed = 0
    updateRunes(frame)
end

updateRunes = function(frame)
    local anyCharging = false
    local ready = 0
    for i = 1, 6 do
        local start, duration, isReady = GetRuneCooldown(i)
        local value = 1
        if not isReady and start and duration and duration > 0 then
            value = math.min(1, (GetTime() - start) / duration)
            anyCharging = true
        else
            ready = ready + 1
        end
        frame.segments[i]:SetValue(value)
    end
    -- The rune poll runs at 20Hz; the text only changes when a rune finishes or starts recharging.
    if frame.lastText ~= ready then
        frame.lastText = ready
        setClassText(frame, profile("ClassPower"), nil, ready, 6)
    end
    frame:SetScript("OnUpdate", anyCharging and onRuneUpdate or nil)
end

local function segmentValue(current, divisor, index)
    return math.max(0, math.min(1, current / divisor - (index - 1)))
end

--- Show the moved main resource as one continuous bar. Secret values go straight to the StatusBar.
local function refreshMovedPrimary(frame, s, powerType, token)
    local max = UnitPowerMax("player", powerType)
    if not hasValue(max) then
        setShown("ClassPower", false)
        return
    end
    if frame.count ~= 1 then layoutSegments(frame, 1) end
    local seg = frame.segments[1]
    if frame.styledPower ~= powerType then
        local r, g, b = s.color.r, s.color.g, s.color.b
        if s.usePowerColor then r, g, b = powerColor(token, powerType) end
        seg:SetStatusBarColor(r, g, b, 1)
        seg.bg:SetVertexColor(s.inactive.r, s.inactive.g, s.inactive.b, s.inactive.a)
        frame.styledPower = powerType
    end
    seg:SetMinMaxValues(0, max)
    local value = UnitPower("player", powerType)
    seg:SetValue(value)
    setClassText(frame, s, powerType, value, max)
    frame.lastText = nil
    frame.continuous = true
    setShown("ClassPower", true)
end

local function pollFragments(frame, elapsed)
    frame.pollElapsed = frame.pollElapsed + elapsed
    if frame.pollElapsed < 0.1 then return end
    frame.pollElapsed = 0
    Bars:RefreshClassPower()
end

function Bars:RefreshClassPower()
    local frame, s = frames.ClassPower, profile("ClassPower")
    if not frame then return end

    local info = classPowerInfo()
    if not info then
        frame:SetScript("OnUpdate", nil)
        frame.pollElapsed = nil
        local powerType, token = movedPrimary()
        if powerType then
            refreshMovedPrimary(frame, s, powerType, token)
        else
            setShown("ClassPower", false)
        end
        return
    end
    if frame.continuous then
        frame.segments[1]:SetMinMaxValues(0, 1)
        frame.continuous = nil
    end

    local max = info.runes and 6 or UnitPowerMax("player", info.type)
    if issecretvalue(max) or not max or max <= 0 then
        setShown("ClassPower", false)
        return
    end
    max = math.min(max, MAX_SEGMENTS)

    if frame.count ~= max then layoutSegments(frame, max) end
    if frame.styledPower ~= info then
        local r, g, b = s.color.r, s.color.g, s.color.b
        if s.usePowerColor then r, g, b = powerColor(info.token, info.type) end
        for _, seg in ipairs(frame.segments) do
            seg:SetStatusBarColor(r, g, b, 1)
            seg.bg:SetVertexColor(s.inactive.r, s.inactive.g, s.inactive.b, s.inactive.a)
        end
        frame.styledPower = info
    end

    if info.runes then
        updateRunes(frame)
    else
        local fractional = info.fractional and not (s.wholeShards and GetSpecialization() ~= DESTRUCTION)
        local divisor = fractional and UnitPowerDisplayMod(info.type) or 1
        if not divisor or divisor == 0 then divisor = 1 end
        local current = UnitPower("player", info.type, fractional)
        local partial = false
        for i = 1, max do
            local ok2, value = pcall(segmentValue, current, divisor, i)
            value = ok2 and value or 0
            if value > 0 and value < 1 then partial = true end
            frame.segments[i]:SetValue(value)
        end
        local whole = fractional and UnitPower("player", info.type) or current
        if issecretvalue(whole) or frame.lastText ~= whole then
            frame.lastText = not issecretvalue(whole) and whole or nil
            setClassText(frame, s, info.type, whole, max)
        end
        -- UNIT_POWER_* can skip the last fragment change, so poll while a shard is partially filled.
        if fractional and partial then
            if not frame.pollElapsed then
                frame.pollElapsed = 0
                frame:SetScript("OnUpdate", pollFragments)
            end
        elseif frame.pollElapsed then
            frame.pollElapsed = nil
            frame:SetScript("OnUpdate", nil)
        end
    end
    setShown("ClassPower", true)
end

function Internal.BuildClassPower()
    local classPower = newFrame()
    classPower.segments = {}
    for i = 1, MAX_SEGMENTS do
        local seg = CreateFrame("StatusBar", nil, classPower)
        seg:SetMinMaxValues(0, 1)
        seg:SetValue(0)
        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints()
        seg.bg:SetTexture(WHITE)
        classPower.segments[i] = seg
    end
    classPower.dividerFrame = CreateFrame("Frame", nil, classPower)
    classPower.dividerFrame:SetAllPoints(classPower)
    classPower.dividerFrame:SetFrameLevel(classPower:GetFrameLevel() + 5)
    classPower.dividerFrame:EnableMouse(false)
    classPower.dividers = {}
    for i = 1, MAX_SEGMENTS - 1 do
        local divider = classPower.dividerFrame:CreateTexture(nil, "OVERLAY")
        divider:SetTexture(WHITE)
        divider:Hide()
        classPower.dividers[i] = divider
    end
    -- Above the dividers so they never cross the text.
    classPower.textFrame = CreateFrame("Frame", nil, classPower)
    classPower.textFrame:SetAllPoints(classPower)
    classPower.textFrame:SetFrameLevel(classPower:GetFrameLevel() + 6)
    classPower.textFrame:EnableMouse(false)
    classPower.text = newText(classPower.textFrame, "CENTER")
    classPower.text:SetPoint("CENTER")
    classPower:SetScript("OnSizeChanged", function(f) f.count = nil; Bars:RefreshClassPower() end)
    frames.ClassPower = classPower
end

function Internal.StyleClassPower()
    local frame, s = frames.ClassPower, profile("ClassPower")
    frame.bg:SetVertexColor(s.background.r, s.background.g, s.background.b, s.background.a)
    styleBorder(frame, s, "ClassPower")
    frame.bg:SetShown(false)
    for _, seg in ipairs(frame.segments) do
        styleBar(seg, s)
    end
    styleText(frame.text, s)
    frame.lastText = nil
    frame.count = nil
    frame.styledPower = nil
end
