local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local Printer = Addon:GetModule("Printer")
local Options = Addon:GetModule("Options")
local SLOTS, GROUPS = Trackers.SLOTS, Trackers.GROUPS
function Trackers:RemoveBuffEntries()
    local removed = 0
    for id, entry in pairs(self.db.profile.entries) do
        if entry.kind == "buff" then
            self.db.profile.entries[id] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        Printer:Print("Removed " .. removed .. " custom buff tracker(s). Custom trackers support spell, equipped-item and bag-item cooldowns.")
    end
end
function Trackers:Add(value, kind, group)
    local id = tonumber(value)
    if (kind ~= "slot" and kind ~= "cooldown" and kind ~= "item") or not GROUPS[group] then
        Printer:Print("Choose a supported cooldown type and icon group.")
        return false
    end
    if kind == "slot" and not SLOTS[id] then
        Printer:Print("Choose a valid equipment slot.")
        return false
    end
    if kind == "cooldown" and (not id or id < 1 or id > 2147483647 or id ~= math.floor(id) or not C_Spell.GetSpellInfo(id)) then
        Printer:Print("Enter a valid spell ID. Spell data must be available before adding a tracker.")
        return false
    end
    if kind == "item" and (not id or id < 1 or id > 2147483647 or id ~= math.floor(id) or not C_Item.DoesItemExistByID(id)) then
        Printer:Print("Enter a valid item ID.")
        return false
    end
    for _, entry in pairs(self.db.profile.entries) do
        if entry.kind == kind and ((kind == "slot" and entry.slot == id)
            or (kind == "cooldown" and entry.spellID == id) or (kind == "item" and entry.itemID == id)) then
            Printer:Print("That spell, item or equipment slot already has a tracker.")
            return false
        end
    end
    local key = self.db.profile.nextID
    self.db.profile.nextID = key + 1
    self.db.profile.entries[key] = {
        spellID = kind == "cooldown" and id or nil, slot = kind == "slot" and id or nil,
        itemID = kind == "item" and id or nil,
        kind = kind, group = group, enabled = true, position = 1,
    }
    self:Refresh()
    Options:Refresh()
    return true
end
