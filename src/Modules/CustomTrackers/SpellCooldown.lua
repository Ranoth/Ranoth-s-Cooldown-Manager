local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local setIconTexture = Internal.SetIconTexture
local cooldownDesaturation, chargeDesaturation
local function desaturationCurves()
    if cooldownDesaturation then return end
    cooldownDesaturation = C_CurveUtil.CreateCurve()
    cooldownDesaturation:SetType(Enum.LuaCurveType.Linear)
    cooldownDesaturation:AddPoint(0, 0)
    cooldownDesaturation:AddPoint(0.000001, 1)
    cooldownDesaturation:AddPoint(86400, 1)
    chargeDesaturation = C_CurveUtil.CreateCurve()
    chargeDesaturation:SetType(Enum.LuaCurveType.Linear)
    chargeDesaturation:AddPoint(0, 1)
    chargeDesaturation:AddPoint(1, 0)
    chargeDesaturation:AddPoint(100, 0)
end

local function updateDesaturation(frame, elapsed)
    frame.desaturationElapsed = frame.desaturationElapsed + elapsed
    if frame.desaturationElapsed < 0.05 then return end
    frame.desaturationElapsed = 0
    -- Remaining time can be secret: only the engine evaluates it and consumes the result.
    frame.Icon:SetDesaturation(frame.desaturationDuration:EvaluateRemainingDuration(cooldownDesaturation))
end

function Internal.UpdateSpellCooldown(frame, entry)
    local count = frame.Applications.Applications
    setIconTexture(frame, C_Spell.GetSpellTexture(entry.spellID))
    local charges = C_Spell.GetSpellCharges(entry.spellID)
    local duration
    if charges then
        frame.hasCharges = true
        duration = C_Spell.GetSpellChargeDuration(entry.spellID)
        count:SetText(charges.currentCharges)
        desaturationCurves()
        frame.Icon:SetDesaturation(chargeDesaturation:Evaluate(charges.currentCharges))
    else
        duration = C_Spell.GetSpellCooldownDuration(entry.spellID, true)
    end
    if duration then frame.Cooldown:SetCooldownFromDurationObject(duration) end
    local zero = duration and not charges and duration:IsZero()
    -- Idle spells start no cooldown, so OnCooldownDone would never stop the poll.
    if duration and not charges and (issecretvalue(zero) or not zero) then
        desaturationCurves()
        frame.desaturationDuration = duration
        frame.desaturationElapsed = 0.05
        updateDesaturation(frame, 0)
        frame:SetScript("OnUpdate", updateDesaturation)
    end
end
