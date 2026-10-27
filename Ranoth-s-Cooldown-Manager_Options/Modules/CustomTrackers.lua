local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Trackers = Addon:GetModule("CustomTrackers")
local Options = Addon:GetModule("Options")
local SLOTS, GROUPS = Trackers.SLOTS, Trackers.GROUPS
local draft = { spellID = "", itemID = "", kind = "cooldown", slot = 6, group = "Utility" }

function Trackers:GetOptions()
    local args = {
        description = { type = "description", order = 1,
            name = "Track spell cooldowns, equipped items, or bag items by item ID. Empty equipment slots hide their icon; bag items stay visible and desaturated with a count of 0 when depleted. Custom buff tracking is not supported. Position is a slot in the combined icon group, managed here, not in Blizzard's menu. Custom icons follow the group's native icon scale, spacing, and row limit; RCM compact spacing only applies when Compact icons is enabled. Extra row space stays reserved while trackers are enabled to avoid combat overlap." },
        spellID = { type = "input", name = "Spell ID", order = 2,
            hidden = function() return draft.kind ~= "cooldown" end,
            get = function() return draft.spellID end, set = function(_, value) draft.spellID = value end },
        itemID = { type = "input", name = "Item ID", order = 2,
            desc = "For example, Goblin Glider Kit: 109076. Uses the item cooldown, not the associated spell's cooldown.",
            hidden = function() return draft.kind ~= "item" end,
            get = function() return draft.itemID end, set = function(_, value) draft.itemID = value end },
        slot = { type = "select", name = "Equipment slot", order = 2, values = SLOTS,
            hidden = function() return draft.kind ~= "slot" end,
            get = function() return draft.slot end, set = function(_, value) draft.slot = value end },
        kind = { type = "select", name = "Track", order = 1.5,
            values = { slot = "Equipped item cooldown", cooldown = "Spell cooldown", item = "Bag item cooldown" },
            get = function() return draft.kind end, set = function(_, value) draft.kind = value end },
        group = { type = "select", name = "Group", order = 4, values = GROUPS,
            get = function() return draft.group end, set = function(_, value) draft.group = value end },
        add = { type = "execute", name = "Add tracker", order = 5,
            func = function()
                self:Add(draft.kind == "slot" and draft.slot or draft.kind == "item" and draft.itemID or draft.spellID,
                    draft.kind, draft.group)
            end },
    }
    for id, entry in pairs(self.db.profile.entries) do
        local info = entry.kind == "cooldown" and C_Spell.GetSpellInfo(entry.spellID)
        local name = entry.kind == "slot" and (SLOTS[entry.slot] .. " (equipped item)")
            or entry.kind == "item" and ((C_Item.GetItemNameByID(entry.itemID) or tostring(entry.itemID)) .. " (bag item)")
            or ((info and info.name or tostring(entry.spellID)) .. " (cooldown)")
        local function set(field, value)
            entry[field] = value
            self:Refresh()
            Options:Refresh()
        end
        args["tracker" .. id] = { type = "group", name = name, order = 10 + id,
            args = {
                hideUnavailable = { type = "toggle", name = "Hide unavailable ability", order = 1.5,
                    hidden = entry.kind ~= "cooldown",
                    desc = "Hide unless the ability is known or in your player or current pet spellbook. Checked outside combat; the last result is kept during combat.",
                    get = function() return entry.hideUnavailable ~= false end,
                    set = function(_, value) set("hideUnavailable", value) end },
                enabled = { type = "toggle", name = "Enabled", order = 1,
                    get = function() return entry.enabled end, set = function(_, value) set("enabled", value) end },
                group = { type = "select", name = "Group", order = 2, values = GROUPS,
                    get = function() return entry.group end, set = function(_, value) set("group", value) end },
                position = { type = "range", name = "Position", order = 3, min = 1, max = 100, step = 1,
                    desc = "Slot in the combined icon group. Positions past the last icon append in ascending order; ties use tracker creation order.",
                    get = function() return entry.position end, set = function(_, value) set("position", value) end },
                remove = { type = "execute", name = "Remove tracker", order = 4, confirm = true,
                    func = function() self.db.profile.entries[id] = nil; self:Refresh(); Options:Refresh() end },
            } }
    end
    return { type = "group", name = "Custom trackers", args = args }
end
