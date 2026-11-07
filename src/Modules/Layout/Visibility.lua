--- Managed-frame strata restoration and alpha suppression.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:GetModule("Layout")
local Internal = Layout.Internal
local defaults = Internal.defaults
local getFrame = Internal.GetFrame

local originalStrata = {}
local rawSetFrameStrata = getmetatable(UIParent).__index.SetFrameStrata

local function restoreStrata(frame)
    local original = originalStrata[frame]
    if original then
        rawSetFrameStrata(frame, original)
        originalStrata[frame] = nil
    end
end

function Layout:ApplyStrata()
    local profile = self.db.profile
    local managed = {}
    for key in pairs(defaults.profile.stack) do
        if profile.stack[key].enabled or key == profile.anchorKey then
            local frame = getFrame(key)
            if frame then
                managed[frame] = true
                originalStrata[frame] = originalStrata[frame] or frame:GetFrameStrata()
                if frame:GetFrameStrata() ~= profile.strata then
                    rawSetFrameStrata(frame, profile.strata)
                end
            end
        end
    end
    for frame in pairs(originalStrata) do
        if not managed[frame] then restoreStrata(frame) end
    end
    self:GetContainer():SetFrameStrata(profile.strata)
end

local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local suppressed = {} -- frame -> true while its entry is disabled
local alphaHooked = {}
local settingAlpha = false

--- Hide or show a Blizzard frame by alpha. Blizzard keeps showing/hiding and fading these frames itself,
--- so the alpha is re-enforced whenever Blizzard changes it. Raw methods avoid running Blizzard code tainted.
local function setSuppressed(frame, hide)
    if hide then
        suppressed[frame] = true
        if not alphaHooked[frame] then
            alphaHooked[frame] = true
            hooksecurefunc(frame, "SetAlpha", function(f)
                if suppressed[f] and not settingAlpha then
                    settingAlpha = true
                    rawSetAlpha(f, 0)
                    settingAlpha = false
                end
            end)
        end
        rawSetAlpha(frame, 0)
    elseif suppressed[frame] then
        suppressed[frame] = nil
        rawSetAlpha(frame, 1)
    end
end

Internal.SetSuppressed = setSuppressed

function Internal.RestoreStrata()
    for frame in pairs(originalStrata) do restoreStrata(frame) end
end
