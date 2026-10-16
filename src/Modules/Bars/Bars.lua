--- Bars module for RanothsCooldownManager.
--- Our own cast bar, primary power bar and segmented class power bar, drawn with plain frames we own.
---  * CastBar and Mana can use either Blizzard's bar (restyled by ResourceSkin) or our custom one: `mode`.
---  * ClassPower is always custom.
--- Blizzard's frames are hidden (by alpha) while a bar is custom and restored when it goes back to Blizzard's.
--- When a bar is custom, Layout stacks our frame instead of Blizzard's (see Bars:GetFrame).
--- @module "Bars"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:NewModule("Bars", "AceEvent-3.0")

local Safe = RanothsCooldownManager:GetModule("Safe")
local Options = RanothsCooldownManager:GetModule("Options")
local LSM = LibStub("LibSharedMedia-3.0")

Bars.KEYS = { "CastBar", "Mana", "ClassPower" }

--- Handlers receive (message, key, frame). Sent when a custom bar is shown or hidden, or its mode changes.
Bars.MESSAGES = {
    CHANGED = "RCM_BARS_CHANGED",
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MAX_SEGMENTS = 10

local function common()
    return {
        texture = "Blizzard",
        background = { r = 0, g = 0, b = 0, a = 0.6 },
        borderSize = 1,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        font = "Friz Quadrata TT",
        fontSize = 12,
    }
end

local function merge(base, extra)
    for k, v in pairs(extra) do base[k] = v end
    return base
end

local defaults = {
    profile = {
        CastBar = merge(common(), {
            mode = "blizzard",
            color = { r = 1, g = 0.7, b = 0, a = 1 },
            channelColor = { r = 0.2, g = 0.9, b = 0.4, a = 1 },
            shieldColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
            interruptEffect = true,
            interruptColor = { r = 0.9, g = 0.1, b = 0.1, a = 1 },
            showText = true,
            showTime = true,
        }),
        Mana = merge(common(), {
            mode = "blizzard",
            usePowerColor = true,
            color = { r = 0, g = 0.5, b = 1, a = 1 },
            showText = false,
            textFormat = "value",
        }),
        ClassPower = merge(common(), {
            usePowerColor = true,
            color = { r = 1, g = 0.8, b = 0.2, a = 1 },
            inactive = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
            dividerSize = 1,
        }),
    },
}

--- Class power per class. `spec`/`form` restrict when it is shown; `fractional` shows partial points (soul shards).
local CLASS_POWER = {
    ROGUE = { type = Enum.PowerType.ComboPoints, token = "COMBO_POINTS" },
    DRUID = { type = Enum.PowerType.ComboPoints, token = "COMBO_POINTS", form = 1 },
    PALADIN = { type = Enum.PowerType.HolyPower, token = "HOLY_POWER" },
    WARLOCK = { type = Enum.PowerType.SoulShards, token = "SOUL_SHARDS", fractional = true },
    MONK = { type = Enum.PowerType.Chi, token = "CHI", spec = 3 },
    MAGE = { type = Enum.PowerType.ArcaneCharges, token = "ARCANE_CHARGES", spec = 1 },
    EVOKER = { type = Enum.PowerType.Essence, token = "ESSENCE" },
    DEATHKNIGHT = { runes = true, token = "RUNES" },
}

local frames = {}
local cast = nil -- active cast state: { name, start, finish, channel, notInterruptible }

local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local hiddenBlizzard = {} -- Blizzard frame -> true while our custom bar replaces it
local alphaHooked = {}
local settingAlpha = false

local function forceHidden(f)
    if hiddenBlizzard[f] and not settingAlpha then
        settingAlpha = true
        rawSetAlpha(f, 0)
        settingAlpha = false
    end
end

local function hasAlphaAnimation(group)
    for _, anim in ipairs({ group:GetAnimations() }) do
        if anim:GetObjectType() == "Alpha" then return true end
    end
    return false
end

--- Blizzard's fade and interrupt displays are Alpha animations, which override the frame's own alpha without
--- calling SetAlpha. Stopping them keeps the frame hidden.
local function stopAlphaAnimations(frame)
    if not frame.GetAnimationGroups then return end
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        if group:IsPlaying() and hasAlphaAnimation(group) then group:Stop() end
    end
end

local function hookAnimations(frame)
    if not frame.GetAnimationGroups then return end
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        if hasAlphaAnimation(group) then
            pcall(hooksecurefunc, group, "Play", function()
                if hiddenBlizzard[frame] then
                    forceHidden(frame)
                    group:Stop()
                end
            end)
        end
    end
end

-- Blizzard also changes alpha through paths a hook cannot see, so the hidden frames are checked every frame.
local enforcer = CreateFrame("Frame")
enforcer:Hide()
enforcer:SetScript("OnUpdate", function()
    for f in pairs(hiddenBlizzard) do
        local ok, visible = pcall(function() return f:GetAlpha() > 0 end)
        if not ok or visible then forceHidden(f) end
        stopAlphaAnimations(f)
    end
end)

--- Hide a Blizzard frame by alpha. Raw methods avoid running Blizzard code tainted.
local function setBlizzardHidden(frame, hide)
    if hide then
        hiddenBlizzard[frame] = true
        if not alphaHooked[frame] then
            alphaHooked[frame] = true
            for _, method in ipairs({ "SetAlpha", "SetAlphaFromBoolean", "Show" }) do
                if frame[method] then pcall(hooksecurefunc, frame, method, forceHidden) end
            end
            pcall(frame.HookScript, frame, "OnShow", forceHidden)
            hookAnimations(frame)
        end
        rawSetAlpha(frame, 0)
        stopAlphaAnimations(frame)
        enforcer:Show()
    elseif hiddenBlizzard[frame] then
        hiddenBlizzard[frame] = nil
        rawSetAlpha(frame, 1)
        if not next(hiddenBlizzard) then enforcer:Hide() end
    end
end

local function profile(key) return Bars.db.profile[key] end

local function notify(key)
    Safe:Notify(Bars.MESSAGES.CHANGED, key, frames[key])
end

local function setShown(key, shown)
    local frame = frames[key]
    if frame:IsShown() ~= shown then
        frame:SetShown(shown)
        notify(key)
    end
end

local function powerColor(token, powerType)
    local info = PowerBarColor and (PowerBarColor[token] or PowerBarColor[powerType])
    if info then return info.r, info.g, info.b end
    return 0, 0.5, 1
end

-- Frame building ---------------------------------------------------------------------------------------------

local function createBorder(frame)
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    border:EnableMouse(false)
    border.edges = {}
    for i = 1, 4 do
        border.edges[i] = border:CreateTexture(nil, "OVERLAY")
        border.edges[i]:SetTexture(WHITE)
    end
    local top, bottom, left, right = unpack(border.edges)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    return border
end

local function styleBorder(frame, s)
    local size, c = s.borderSize, s.borderColor
    frame.border:SetShown(size > 0)
    if size <= 0 then return end
    local top, bottom, left, right = unpack(frame.border.edges)
    top:SetHeight(size)
    bottom:SetHeight(size)
    left:SetWidth(size)
    right:SetWidth(size)
    for _, edge in ipairs(frame.border.edges) do
        edge:SetVertexColor(c.r, c.g, c.b, c.a)
    end
end

local function newFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:EnableMouse(false)
    frame:SetSize(250, 20)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(WHITE)
    frame.border = createBorder(frame)
    frame:Hide()
    return frame
end

local function newStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints(parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function newText(parent, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetJustifyH(justify)
    return text
end

local function styleText(text, s)
    text:SetFont(LSM:Fetch("font", s.font), s.fontSize, "OUTLINE")
end

local function styleBar(bar, s)
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", s.texture))
end

-- Cast bar ---------------------------------------------------------------------------------------------------

local function castColor(s)
    local c = s.color
    if cast then
        if cast.notInterruptible then c = s.shieldColor
        elseif cast.channel then c = s.channelColor end
    end
    return c
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
    if frame.timeText:IsShown() then frame.timeText:SetFormattedText("%.1f", remaining) end
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

    cast = nil
    interrupt = { start = GetTime() }
    local c = s.interruptColor
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame.bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    frame.text:SetText(INTERRUPTED or "Interrupted")
    frame.text:Show()
    frame.timeText:Hide()
    frame:SetAlpha(1)
    frame:SetScript("OnUpdate", onInterruptUpdate)
    setShown("CastBar", true)
    return true
end

--- Read the player's current cast or channel. If the values cannot be read (secret values), the bar is shown full.
local function readCast()
    local name, _, _, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo("player")
    local channel = false
    if not name then
        castID = nil
        name, _, _, startMS, endMS, _, notInterruptible = UnitChannelInfo("player")
        channel = name ~= nil
    end
    if not name then return nil end

    local ok, state = pcall(function()
        return {
            name = name,
            start = startMS / 1000,
            finish = endMS / 1000,
            channel = channel,
            castID = castID,
            notInterruptible = notInterruptible and true or false,
        }
    end)
    return ok and state or { name = name, channel = channel, castID = castID, unknown = true }
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
    if cast.unknown then
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(1)
        frame:SetScript("OnUpdate", nil)
    else
        frame.bar:SetMinMaxValues(0, cast.finish - cast.start)
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
    cast = { name = "Preview", start = now, finish = now + 3, preview = true }
    self:RefreshCast()
    return true
end

-- Power bar --------------------------------------------------------------------------------------------------

local function hasValue(v)
    local ok, positive = pcall(function() return v > 0 end)
    return not ok or positive
end

--- Percentage as a number, or nil when it cannot be computed. Falls back to the game's own percent API
--- when the values are secret and cannot be used in arithmetic.
local function powerPercent(powerType, value, max)
    local ok, pct = pcall(function() return value / max * 100 end)
    if ok then return pct end
    if UnitPowerPercent then
        local ok2, api = pcall(UnitPowerPercent, "player", powerType, false, CurveConstants and CurveConstants.ScaleTo100)
        if ok2 then return api end
    end
end

--- Write the power text in the chosen format. Secret values are passed straight to SetFormattedText.
local function setPowerText(text, format, powerType, value, max)
    local pct = powerPercent(powerType, value, max)
    local ok
    if format == "percent" and pct then
        ok = pcall(text.SetFormattedText, text, "%d%%", pct)
    elseif format == "both" and pct then
        ok = pcall(text.SetFormattedText, text, "%s - %d%%", AbbreviateLargeNumbers and AbbreviateLargeNumbers(value) or value, pct)
    end
    if not ok then pcall(text.SetFormattedText, text, "%s", AbbreviateLargeNumbers and AbbreviateLargeNumbers(value) or value) end
end

function Bars:RefreshPower()
    local frame, s = frames.Mana, profile("Mana")
    if not frame or s.mode ~= "custom" then return end

    local powerType, token = UnitPowerType("player")
    local max = UnitPowerMax("player", powerType)
    if not powerType or not hasValue(max) then
        setShown("Mana", false)
        return
    end

    local c = s.color
    if s.usePowerColor then
        local r, g, b = powerColor(token, powerType)
        c = { r = r, g = g, b = b, a = 1 }
    end
    frame.bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    frame.bar:SetMinMaxValues(0, max)
    local value = UnitPower("player", powerType)
    frame.bar:SetValue(value)
    frame.text:SetShown(s.showText)
    if s.showText then setPowerText(frame.text, s.textFormat, powerType, value, max) end
    setShown("Mana", true)
end

-- Class power ------------------------------------------------------------------------------------------------

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

local function updateRunes(frame)
    local anyCharging = false
    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown(i)
        local value = 1
        if not ready and start and duration and duration > 0 then
            value = math.min(1, (GetTime() - start) / duration)
            anyCharging = true
        end
        frame.segments[i]:SetValue(value)
    end
    frame:SetScript("OnUpdate", anyCharging and function(f)
        f.elapsed = (f.elapsed or 0) + 0.05
        updateRunes(f)
    end or nil)
end

function Bars:RefreshClassPower()
    local frame, s = frames.ClassPower, profile("ClassPower")
    if not frame then return end

    local _, classToken = UnitClass("player")
    local info = CLASS_POWER[classToken]
    if info and info.spec and GetSpecialization() ~= info.spec then info = nil end
    if info and info.form and GetShapeshiftFormID() ~= info.form then info = nil end
    if not info then
        frame:SetScript("OnUpdate", nil)
        setShown("ClassPower", false)
        return
    end

    local r, g, b = s.color.r, s.color.g, s.color.b
    if s.usePowerColor then r, g, b = powerColor(info.token, info.type) end

    local max = info.runes and 6 or UnitPowerMax("player", info.type)
    local ok = pcall(function() max = math.min(max, MAX_SEGMENTS) end)
    if not ok or not max or max <= 0 then
        setShown("ClassPower", false)
        return
    end

    if frame.count ~= max then layoutSegments(frame, max) end
    for i = 1, max do
        local seg = frame.segments[i]
        seg:SetStatusBarColor(r, g, b, 1)
        seg.bg:SetVertexColor(s.inactive.r, s.inactive.g, s.inactive.b, s.inactive.a)
    end

    if info.runes then
        updateRunes(frame)
    else
        local divisor = info.fractional and UnitPowerDisplayMod(info.type) or 1
        if not divisor or divisor == 0 then divisor = 1 end
        local current = UnitPower("player", info.type, info.fractional)
        for i = 1, max do
            local ok2, value = pcall(function() return math.max(0, math.min(1, current / divisor - (i - 1))) end)
            frame.segments[i]:SetValue(ok2 and value or 0)
        end
    end
    setShown("ClassPower", true)
end

-- Styling and updates ----------------------------------------------------------------------------------------

local function styleFrameCommon(key)
    local frame, s = frames[key], profile(key)
    frame.bg:SetVertexColor(s.background.r, s.background.g, s.background.b, s.background.a)
    styleBorder(frame, s)
end

function Bars:StyleAll()
    if not frames.CastBar then return end

    styleFrameCommon("CastBar")
    local cs = profile("CastBar")
    styleBar(frames.CastBar.bar, cs)
    styleText(frames.CastBar.text, cs)
    styleText(frames.CastBar.timeText, cs)

    styleFrameCommon("Mana")
    local ms = profile("Mana")
    styleBar(frames.Mana.bar, ms)
    styleText(frames.Mana.text, ms)

    styleFrameCommon("ClassPower")
    local ps = profile("ClassPower")
    frames.ClassPower.bg:SetShown(false)
    for _, seg in ipairs(frames.ClassPower.segments) do
        styleBar(seg, ps)
    end
    frames.ClassPower.count = nil
end

--- Hide Blizzard's version of every bar we draw ourselves, and show it again for bars that went back to Blizzard.
function Bars:SyncBlizzard()
    local Resources = RanothsCooldownManager:GetModule("Resources")
    local target = {}
    for _, key in ipairs(self.KEYS) do
        local blizzard = Resources:Get(key)
        if blizzard and self:IsCustom(key) then target[blizzard] = true end
    end
    for frame in pairs(hiddenBlizzard) do
        if not target[frame] then setBlizzardHidden(frame, false) end
    end
    for frame in pairs(target) do
        setBlizzardHidden(frame, true)
    end
end

function Bars:RefreshAll()
    self:StyleAll()
    self:SyncBlizzard()
    self:RefreshCast()
    self:RefreshPower()
    self:RefreshClassPower()
    -- A bar that went back to Blizzard's version must stop showing ours.
    for _, key in ipairs({ "CastBar", "Mana" }) do
        if not self:IsCustom(key) and frames[key] then setShown(key, false) end
    end
end

--- True if the bar is drawn by us.
--- @param key string One of Bars.KEYS
function Bars:IsCustom(key)
    if key == "ClassPower" then return frames.ClassPower ~= nil end
    local s = self.db and self.db.profile[key]
    return s ~= nil and s.mode == "custom" and frames[key] ~= nil
end

--- The custom frame Layout should stack for a key, or nil to use Blizzard's frame.
--- @param key string One of Bars.KEYS
--- @return Frame|nil
function Bars:GetFrame(key)
    if self:IsCustom(key) then return frames[key] end
end

--- Switch CastBar or Mana between Blizzard's bar and ours.
--- @param key string "CastBar" or "Mana"
--- @param mode string "blizzard" or "custom"
function Bars:SetMode(key, mode)
    local s = self.db.profile[key]
    if not s or s.mode == nil or (mode ~= "blizzard" and mode ~= "custom") then return false end
    s.mode = mode
    self:RefreshAll()
    notify(key)
    Options:Refresh()
    return true
end

local function buildFrames()
    local castFrame = newFrame()
    castFrame.bar = newStatusBar(castFrame)
    castFrame.text = newText(castFrame.bar, "LEFT")
    castFrame.text:SetPoint("LEFT", 4, 0)
    castFrame.timeText = newText(castFrame.bar, "RIGHT")
    castFrame.timeText:SetPoint("RIGHT", -4, 0)
    frames.CastBar = castFrame
    castFrame.flash = castFrame.bar:CreateTexture(nil, "OVERLAY", nil, 7)
    castFrame.flash:SetAllPoints(castFrame)
    castFrame.flash:SetTexture(WHITE)
    castFrame.flash:SetAlpha(0)

    local power = newFrame()
    power.bar = newStatusBar(power)
    power.text = newText(power.bar, "CENTER")
    power.text:SetPoint("CENTER")
    frames.Mana = power

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
    classPower:SetScript("OnSizeChanged", function(f) f.count = nil; Bars:RefreshClassPower() end)
    frames.ClassPower = classPower
end

-- Events -----------------------------------------------------------------------------------------------------

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}
local POWER_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

local function onEvent(_, event, _, castID)
    if event:find("^UNIT_SPELLCAST") then
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
    elseif event == "RUNE_POWER_UPDATE" then
        Bars:RefreshClassPower()
    elseif event:find("^UNIT_") then
        Bars:RefreshPower()
        Bars:RefreshClassPower()
    else
        Bars:RefreshAll()
    end
end

local function registerUnitEvents(eventFrame, list)
    for _, event in ipairs(list) do
        pcall(eventFrame.RegisterUnitEvent, eventFrame, event, "player")
    end
end

-- Options ----------------------------------------------------------------------------------------------------

local LABELS = { CastBar = "Cast bar", Mana = "Primary power bar", ClassPower = "Class power" }

local function mediaValues(kind)
    local values = {}
    for _, name in ipairs(LSM:List(kind)) do values[name] = name end
    return values
end

function Bars:GetOptions()
    local args = {
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
            group.args.font = {
                type = "select", order = 6, name = "Font",
                values = function() return mediaValues("font") end, hidden = hiddenUnlessCustom,
                get = function() return s().font end, set = set("font"),
            }
            group.args.fontSize = {
                type = "range", order = 7, name = "Font size", min = 6, max = 32, step = 1, hidden = hiddenUnlessCustom,
                get = function() return s().fontSize end, set = set("fontSize"),
            }
            group.args.showText = {
                type = "toggle", order = 8, name = key == "CastBar" and "Show spell name" or "Show value",
                hidden = hiddenUnlessCustom,
                get = function() return s().showText end, set = set("showText"),
            }
        end

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
            group.args.inactive = color(22, "Empty segment color", "inactive", nil)
            group.args.dividerSize = {
                type = "range", order = 23, name = "Divider thickness",
                desc = "Line drawn between segments, in the border color. 0 hides it.",
                min = 0, max = 6, step = 1,
                get = function() return s().dividerSize end, set = set("dividerSize"),
            }
        end
        args[key] = group
    end

    return { type = "group", name = "Custom bars", args = args }
end

function Bars:OnProfileRefresh()
    self:RefreshAll()
end

function Bars:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Bars", defaults)
    Options:Register("Bars", self:GetOptions(), 45)
end

function Bars:OnEnable()
    local Resources = RanothsCooldownManager:GetModule("Resources")
    self:RegisterMessage(Resources.MESSAGES.AVAILABLE, "SyncBlizzard")
    self:RegisterMessage(Resources.MESSAGES.CHANGED, "SyncBlizzard")
    if not frames.CastBar then buildFrames() end
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", onEvent)
    end
    local ef = self.eventFrame
    registerUnitEvents(ef, CAST_EVENTS)
    registerUnitEvents(ef, POWER_EVENTS)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "RUNE_POWER_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
        pcall(ef.RegisterEvent, ef, event)
    end
    self:RefreshAll()
end

function Bars:OnDisable()
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    for frame in pairs(hiddenBlizzard) do setBlizzardHidden(frame, false) end
    for _, frame in pairs(frames) do frame:Hide() end
end
