local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local Printer = Addon:GetModule("Printer")
local availableSpells = {}
local checkedSpells = {}
local availabilityDirty = true
function Trackers:IsAvailable(entry)
    return entry.kind ~= "cooldown" or entry.hideUnavailable == false or availableSpells[entry.spellID] == true
end

--- Queries the spellbook outside combat; returns true when a tracked spell's availability changed.
function Trackers:RefreshAvailability()
    if InCombatLockdown() then return false end
    local force = availabilityDirty
    availabilityDirty = false
    local changed = false
    for _, entry in pairs(self.db.profile.entries) do
        local spellID = entry.spellID
        if entry.kind == "cooldown" and entry.enabled and entry.hideUnavailable ~= false
            and (force or availableSpells[spellID] == nil) then
            local available
            local player = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Player, true)
            local pet = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet, true)
            if issecretvalue(player) or issecretvalue(pet) then
                Printer:Print("Spellbook availability for spell " .. spellID .. " is restricted; hiding its tracker.")
                available = false
            else
                available = player or pet
            end
            if availableSpells[spellID] ~= available then changed = true end
            availableSpells[spellID] = available
            checkedSpells[spellID] = true
        end
    end
    if force then
        -- Skipped entries (disabled or not hiding) must be rechecked when they come back.
        for spellID in pairs(availableSpells) do
            if not checkedSpells[spellID] then availableSpells[spellID] = nil end
        end
    end
    wipe(checkedSpells)
    return changed
end

--- Spellbook and pet events fire often; only a tracked ability appearing or disappearing needs a full refresh.
function Trackers:OnSpellbookChanged(event, unit)
    if (event == "UNIT_PET" or event == "PLAYER_SPECIALIZATION_CHANGED") and unit ~= "player" then return end
    if event == "PLAYER_REGEN_ENABLED" and not availabilityDirty then return end
    availabilityDirty = true
    if InCombatLockdown() then return end
    if self:RefreshAvailability() then
        self:Refresh()
    else
        -- Talents can still change a tracked spell's icon or charges.
        self:Update()
    end
end

function Internal.InvalidateAvailability()
    availabilityDirty = true
end
