--- Shared bar construction, styling and resource-selection helpers.
local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:NewModule("Bars", "AceEvent-3.0")

local Safe = RanothsCooldownManager:GetModule("Safe")
local TextShadow = RanothsCooldownManager:GetModule("TextShadow")
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
        textShadow = false,
        shadowOffset = 2,
        fontOutline = "OUTLINE",
    }
end

local function merge(base, extra)
    for k, v in pairs(extra) do base[k] = v end
    return base
end

local defaults = { profile = {} }

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

local MANA = Enum.PowerType.Mana

--- Segmented class power for the current class, spec and form, or nil.
local function classPowerInfo()
    local _, classToken = UnitClass("player")
    local info = CLASS_POWER[classToken]
    if info and info.spec and GetSpecialization() ~= info.spec then return nil end
    if info and info.form and GetShapeshiftFormID() ~= info.form then return nil end
    return info
end

local function hasMana()
    local max = UnitPowerMax("player", MANA)
    -- A secret maximum can only come from a pool that exists.
    return issecretvalue(max) or max > 0
end

--- The main resource (Maelstrom, Insanity, Astral Power...) when it is moved to the class power bar so the
--- primary power bar can show mana instead; nil otherwise. Segmented class power keeps the bar.
local function movedPrimary()
    if not (Bars.db.profile.ClassPower.primaryPower and Bars.db.profile.Mana.mode == "custom") then return nil end
    local powerType, token = UnitPowerType("player")
    if not powerType or powerType == MANA or classPowerInfo() or not hasMana() then return nil end
    return powerType, token
end

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

local function styleBorder(frame, s, key, anchor, kind)
    local size, c = s.borderSize, s.borderColor
    RanothsCooldownManager:GetModule("Borders"):Register(frame, frame.border, anchor or frame, size, c, kind or "bars", key)
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
    local outline = s.fontOutline or "OUTLINE"
    text:SetFont(LSM:Fetch("font", s.font), s.fontSize, outline == "NONE" and "" or outline)
    TextShadow:Set(text, s.textShadow, s.shadowOffset)
end

local function styleBar(bar, s)
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", s.texture))
end

local function hasValue(v)
    return issecretvalue(v) or v > 0
end

--- Percentage as a number, or nil when it cannot be computed. Falls back to the game's own percent API
--- when the values are secret and cannot be used in arithmetic.
local function powerPercent(powerType, value, max)
    if not issecretvalue(value) and not issecretvalue(max) then return value / max * 100 end
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

Bars.Internal = {
    frames = frames,
    defaults = defaults,
    common = common,
    merge = merge,
    WHITE = WHITE,
    MAX_SEGMENTS = MAX_SEGMENTS,
    MANA = MANA,
    profile = profile,
    notify = notify,
    newFrame = newFrame,
    newStatusBar = newStatusBar,
    newText = newText,
    createBorder = createBorder,
    styleBorder = styleBorder,
    styleBar = styleBar,
    styleText = styleText,
    setShown = setShown,
    powerColor = powerColor,
    classPowerInfo = classPowerInfo,
    movedPrimary = movedPrimary,
    hasValue = hasValue,
    setPowerText = setPowerText,
}
