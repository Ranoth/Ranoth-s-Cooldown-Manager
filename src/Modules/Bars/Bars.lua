--- Bars facade: lifecycle, Blizzard suppression and coordinated event routing.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Bars = RanothsCooldownManager:GetModule("Bars")
local Internal = Bars.Internal
local frames, profile = Internal.frames, Internal.profile
local setShown = Internal.setShown
local classPowerInfo = Internal.classPowerInfo
local movedPrimary = Internal.movedPrimary
local Options = RanothsCooldownManager:GetModule("Options")
local defaults, notify = Internal.defaults, Internal.notify

local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local hiddenBlizzard = {} -- Blizzard frame -> true while our custom bar replaces it
local alphaHooked = {}
local alphaAnimations = {}
local settingAlpha = false
local enforcer = CreateFrame("Frame")
enforcer:Hide()

local function forceHidden(f)
    if hiddenBlizzard[f] and not settingAlpha then
        settingAlpha = true
        rawSetAlpha(f, 0)
        settingAlpha = false
        enforcer:Show()
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
    local groups = alphaAnimations[frame]
    if not groups then return end
    for _, group in ipairs(groups) do
        if group:IsPlaying() then group:Stop() end
    end
end

local function hookAnimations(frame)
    if not frame.GetAnimationGroups then return end
    local groups = {}
    alphaAnimations[frame] = groups
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        if hasAlphaAnimation(group) then
            groups[#groups + 1] = group
            pcall(hooksecurefunc, group, "Play", function()
                if hiddenBlizzard[frame] then
                    group:Stop()
                    forceHidden(frame)
                end
            end)
        end
    end
end

-- Animation Stop can restore alpha after Play hooks run. Check once on the next frame,
-- then sleep until another alpha/show/animation hook requests enforcement.
enforcer:SetScript("OnUpdate", function()
    for f in pairs(hiddenBlizzard) do
        stopAlphaAnimations(f)
        local alpha = f:GetAlpha()
        if issecretvalue(alpha) or alpha ~= 0 then forceHidden(f) end
    end
    enforcer:Hide()
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

function Bars:StyleAll()
    if not frames.CastBar then return end
    Internal.StyleCast()
    Internal.StylePrimaryPower()
    Internal.StyleClassPower()
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

-- Events -----------------------------------------------------------------------------------------------------

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}
-- UNIT_POWER_FREQUENT reports every change; UNIT_POWER_UPDATE is a throttled duplicate of it.
local POWER_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local IS_CAST_EVENT = {}
for _, event in ipairs(CAST_EVENTS) do IS_CAST_EVENT[event] = true end

local function onEvent(_, event, _, castID)
    if IS_CAST_EVENT[event] then
        Internal.HandleCastEvent(event, castID)
    elseif event == "RUNE_POWER_UPDATE" then
        Bars:RefreshClassPower()
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        -- For power events the second payload argument is the changed power token, not a cast ID.
        local _, primaryToken = UnitPowerType("player")
        local moved = movedPrimary()
        if moved then
            if castID == "MANA" then Bars:RefreshPower() end
            if castID == primaryToken then Bars:RefreshClassPower() end
            return
        end
        if castID == primaryToken then Bars:RefreshPower() end
        local info = classPowerInfo()
        if info and castID == info.token then Bars:RefreshClassPower() end
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

function Bars:OnProfileRefresh()
    self:RefreshAll()
end

function Bars:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Bars", defaults)
end

function Bars:OnEnable()
    local Resources = RanothsCooldownManager:GetModule("Resources")
    self:RegisterMessage(Resources.MESSAGES.AVAILABLE, "SyncBlizzard")
    self:RegisterMessage(Resources.MESSAGES.CHANGED, "SyncBlizzard")
    if not frames.CastBar then
        Internal.BuildCast()
        Internal.BuildPrimaryPower()
        Internal.BuildClassPower()
    end
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
