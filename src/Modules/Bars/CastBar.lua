--- Custom cast/channel bar, spell icon, interrupt effect and previews.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:GetModule("Bars")
local Internal = Bars.Internal
local frames, profile = Internal.frames, Internal.profile
local newFrame = Internal.newFrame
local newStatusBar = Internal.newStatusBar
local newText = Internal.newText
local createBorder = Internal.createBorder
local styleBorder = Internal.styleBorder
local styleBar = Internal.styleBar
local styleText = Internal.styleText
local setShown = Internal.setShown
local WHITE = Internal.WHITE
local cast

Internal.defaults.profile.CastBar = Internal.merge(Internal.common(), {
    mode = "custom",
    color = { r = 1, g = 0.7, b = 0, a = 1 },
    channelColor = { r = 0.2, g = 0.9, b = 0.4, a = 1 },
    shieldColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    interruptEffect = true,
    interruptColor = { r = 0.9, g = 0.1, b = 0.1, a = 1 },
    showText = true,
    showTime = true,
    showIcon = true,
    iconBorder = {
        borderSize = 1,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },
})

local function anchorCastText(frame)
    frame.text:ClearAllPoints()
    frame.text:SetPoint("LEFT", frame.bar, "LEFT", 4, 0)
    if frame.timeText:IsShown() then
        frame.text:SetPoint("RIGHT", frame.timeText, "LEFT", -4, 0)
    else
        frame.text:SetPoint("RIGHT", frame.bar, "RIGHT", -4, 0)
    end
end

function Bars:StyleCastBorder()
    local frame, s = frames.CastBar, profile("CastBar")
    if not frame then return end
    styleBorder(frame, s, "CastBar", frame.bar)
    local iconSettings = s.iconBorder
    styleBorder(frame.icon, iconSettings, "CastBar", frame.icon, "icons")
    local borders = RanothsCooldownManager:GetModule("Borders")
    -- The cast bar stays excluded from screen-space sharing; its known internal contact needs no geometry reads.
    local shared = s.showIcon and borders.db.profile.enabled
        and s.borderSize > 0 and iconSettings.borderSize > 0
    local seamSize = shared and math.max(s.borderSize, iconSettings.borderSize) / 2
    local barEdge, iconEdge = frame.border.edges[3], frame.icon.border.edges[4]
    barEdge:SetWidth(shared and seamSize or s.borderSize)
    iconEdge:SetWidth(shared and seamSize or iconSettings.borderSize)
    if shared then
        local c = iconSettings.borderColor
        barEdge:SetVertexColor(c.r, c.g, c.b, c.a)
    end
    -- Independently snapping the two halves could double a one-pixel divider.
    barEdge:SetSnapToPixelGrid(not shared)
    iconEdge:SetSnapToPixelGrid(not shared)
    barEdge:SetTexelSnappingBias(0)
    iconEdge:SetTexelSnappingBias(0)
end

local function layoutCast(frame, s)
    frame.icon:SetShown(s.showIcon)
    frame.bar:ClearAllPoints()
    if s.showIcon then
        frame.bar:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT")
        frame.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    else
        frame.bar:SetAllPoints(frame)
    end
    frame.border:ClearAllPoints()
    frame.border:SetAllPoints(frame.bar)
    anchorCastText(frame)
    Bars:StyleCastBorder()
end

local function castColor(s)
    local c = s.color
    if cast then
        if cast.notInterruptible then c = s.shieldColor
        elseif cast.channel then c = s.channelColor end
    end
    return c
end

local function updateCastTime(frame, remaining)
    if not frame.timeText:IsShown() then return end
    local tenth = math.floor(remaining * 10 + 0.5)
    if frame.timeTenth ~= tenth then
        frame.timeTenth = tenth
        frame.timeText:SetFormattedText("%.1f", tenth / 10)
    end
end

local function onCastUpdate(frame)
    if not cast then return end
    local now = GetTime()
    if now >= cast.finish then
        cast = nil
        Bars:RefreshCast()
        return
    end
    local remaining = cast.finish - now
    frame.bar:SetValue(cast.channel and remaining or (now - cast.start))
    updateCastTime(frame, remaining)
end

local function styleCast()
    local frame, s = frames.CastBar, profile("CastBar")
    local c = castColor(s)
    frame.bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
end

-- Interrupt effect: the bar turns to the interrupt color with a quick flash, holds, then fades out.
local interrupt = nil -- { start = GetTime() } while the effect plays
local INTERRUPT_FLASH, INTERRUPT_HOLD, INTERRUPT_FADE = 0.25, 0.6, 0.4

local function endInterrupt()
    interrupt = nil
    local frame = frames.CastBar
    frame:SetScript("OnUpdate", nil)
    frame:SetAlpha(1)
    frame.flash:SetAlpha(0)
end

local function onInterruptUpdate(frame)
    if not interrupt then return end
    local t = GetTime() - interrupt.start
    if t >= INTERRUPT_HOLD + INTERRUPT_FADE then
        endInterrupt()
        Bars:RefreshCast()
        return
    end
    frame.flash:SetAlpha(t < INTERRUPT_FLASH and 0.6 * (1 - t / INTERRUPT_FLASH) or 0)
    frame:SetAlpha(t > INTERRUPT_HOLD and 1 - (t - INTERRUPT_HOLD) / INTERRUPT_FADE or 1)
end

--- Play the interrupt effect on the custom cast bar.
function Bars:ShowInterrupt()
    local frame, s = frames.CastBar, profile("CastBar")
    if not frame or s.mode ~= "custom" then return false end

    if cast then
        frame.icon.texture:SetTexture(cast.texture)
    else
        frame.icon.texture:SetTexture(136243)
    end
    cast = nil
    interrupt = { start = GetTime() }
    local c = s.interruptColor
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame.bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    frame.text:SetText(INTERRUPTED or "Interrupted")
    frame.text:Show()
    frame.timeText:Hide()
    anchorCastText(frame)
    frame:SetAlpha(1)
    frame:SetScript("OnUpdate", onInterruptUpdate)
    setShown("CastBar", true)
    return true
end

--- Read the player's current cast or channel. If the values cannot be read (secret values), the bar is shown full.
local function readCast()
    local name, _, texture, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo("player")
    local channel = false
    if not name then
        castID = nil
        name, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo("player")
        channel = name ~= nil
    end
    if not name then return nil end

    local ok, state = pcall(function()
        return {
            name = name,
            texture = texture,
            start = startMS / 1000,
            finish = endMS / 1000,
            channel = channel,
            castID = castID,
            notInterruptible = notInterruptible and true or false,
        }
    end)
    return ok and state or { name = name, texture = texture, channel = channel, castID = castID, unknown = true }
end

function Bars:RefreshCast()
    local frame, s = frames.CastBar, profile("CastBar")
    if not frame or s.mode ~= "custom" then return end

    if not (cast and cast.preview) then cast = readCast() end
    if cast and interrupt then endInterrupt() end
    if not cast then
        -- The stop event that follows an interrupt must not cut the effect short.
        if interrupt then return end
        frame:SetScript("OnUpdate", nil)
        setShown("CastBar", false)
        return
    end

    frame.text:SetShown(s.showText)
    frame.text:SetText(cast.name)
    frame.timeText:SetShown(s.showTime and not cast.unknown)
    frame.icon.texture:SetTexture(cast.texture)
    anchorCastText(frame)
    if cast.unknown then
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(1)
        frame:SetScript("OnUpdate", nil)
    else
        frame.bar:SetMinMaxValues(0, cast.finish - cast.start)
        -- Set the starting value now, otherwise the first frame shows the previous cast's (full) value.
        local elapsed = math.max(0, math.min(GetTime() - cast.start, cast.finish - cast.start))
        frame.bar:SetValue(cast.channel and (cast.finish - cast.start - elapsed) or elapsed)
        updateCastTime(frame, cast.finish - cast.start - elapsed)
        frame:SetScript("OnUpdate", onCastUpdate)
    end
    styleCast()
    setShown("CastBar", true)
end

--- Show a three second fake cast so the bar can be styled without casting.
function Bars:PreviewCast()
    if profile("CastBar").mode ~= "custom" then return false end
    if interrupt then endInterrupt() end
    local now = GetTime()
    cast = { name = "Preview", texture = 136243, start = now, finish = now + 3, preview = true }
    self:RefreshCast()
    return true
end

function Internal.BuildCast()
    local castFrame = newFrame()
    castFrame.bar = newStatusBar(castFrame)
    castFrame.text = newText(castFrame.bar, "LEFT")
    castFrame.text:SetPoint("LEFT", 4, 0)
    castFrame.timeText = newText(castFrame.bar, "RIGHT")
    castFrame.timeText:SetPoint("RIGHT", -4, 0)
    castFrame.text:SetWordWrap(false)
    castFrame.icon = CreateFrame("Frame", nil, castFrame)
    castFrame.icon:EnableMouse(false)
    castFrame.icon:SetPoint("TOPLEFT")
    castFrame.icon:SetPoint("BOTTOMLEFT")
    castFrame.icon:SetWidth(20)
    castFrame.icon.texture = castFrame.icon:CreateTexture(nil, "ARTWORK")
    castFrame.icon.texture:SetAllPoints()
    castFrame.icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    castFrame.icon.border = createBorder(castFrame.icon)
    castFrame:SetScript("OnSizeChanged", function(_, _, height) castFrame.icon:SetWidth(height) end)
    frames.CastBar = castFrame
    castFrame.flash = castFrame.bar:CreateTexture(nil, "OVERLAY", nil, 7)
    castFrame.flash:SetAllPoints(castFrame.bar)
    castFrame.flash:SetTexture(WHITE)
    castFrame.flash:SetAlpha(0)

    hooksecurefunc(RanothsCooldownManager:GetModule("Borders"), "SetShared", function() Bars:StyleCastBorder() end)
end

function Internal.StyleCast()
    local frame, s = frames.CastBar, profile("CastBar")
    frame.bg:SetVertexColor(s.background.r, s.background.g, s.background.b, s.background.a)
    layoutCast(frame, s)
    styleBar(frame.bar, s)
    styleText(frame.text, s)
    styleText(frame.timeText, s)
end

function Internal.HandleCastEvent(event, castID)
    local s = profile("CastBar")
    if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
        and s.interruptEffect and s.mode == "custom"
        and cast and not cast.preview and not cast.channel
        and (not castID or not cast.castID or castID == cast.castID) then
        Bars:ShowInterrupt()
        return
    end
    if cast and cast.preview then cast = nil end
    Bars:RefreshCast()
end
