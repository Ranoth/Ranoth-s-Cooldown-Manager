local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local Printer = Addon:GetModule("Printer")
local SLOTS = Trackers.SLOTS
local setIconTexture = Internal.SetIconTexture
local function setItemCooldown(frame, start, duration, enabled, gcd, label)
    if issecretvalue(start) or issecretvalue(duration) or issecretvalue(enabled) or issecretvalue(gcd) then
        if not frame.warnedCooldown then
            Printer:Print("Cooldown data for " .. label .. " is restricted and cannot be displayed.")
            frame.warnedCooldown = true
        end
    elseif start and duration and duration > 0 and (enabled == 1 or enabled == true) and not gcd then
        frame.Cooldown:SetCooldown(start, duration)
        frame.Icon:SetDesaturated(start + duration > GetTime())
    end
end

function Internal.UpdateEquippedCooldown(frame, entry)
    local texture = GetInventoryItemTexture("player", entry.slot)
    setIconTexture(frame, texture)
    local shown = GetInventoryItemID("player", entry.slot) ~= nil
    if shown then
        local start, duration, enabled, gcd = GetInventoryItemCooldown("player", entry.slot)
        setItemCooldown(frame, start, duration, enabled, gcd, SLOTS[entry.slot])
    end
    return shown
end

function Internal.UpdateBagCooldown(frame, entry)
    local count = frame.Applications.Applications
    setIconTexture(frame, C_Item.GetItemIconByID(entry.itemID) or 134400)
    local _, spellID = C_Item.GetItemSpell(entry.itemID)
    frame.spellID = spellID
    if not C_Item.IsItemDataCachedByID(entry.itemID) and frame.requestedItemID ~= entry.itemID then
        frame.requestedItemID = entry.itemID
        C_Item.RequestLoadItemDataByID(entry.itemID)
    end
    local quantity = C_Item.GetItemCount(entry.itemID, false, false, false, false)
    count:SetText(quantity)
    local start, duration, enabled = C_Item.GetItemCooldown(entry.itemID)
    setItemCooldown(frame, start, duration, enabled, false, "item " .. entry.itemID)
    if not issecretvalue(quantity) and quantity == 0 then frame.Icon:SetDesaturated(true) end
end
