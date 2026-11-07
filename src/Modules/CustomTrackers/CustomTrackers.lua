local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local Viewers = Addon:GetModule("Viewers")
local Options = Addon:GetModule("Options")
local Safe = Addon:GetModule("Safe")
local Printer = Addon:GetModule("Printer")
local GROUPS = Trackers.GROUPS
local defaults, frames, pool = Internal.defaults, Internal.frames, Internal.pool
local create = Internal.CreateFrame
function Trackers:UpdateFrame(frame, entry)
    local shown = entry.enabled and self:IsEnabled() and self:IsAvailable(entry) and Viewers:Get(entry.group) ~= nil
    local count = frame.Applications.Applications
    frame.Cooldown:Clear()
    frame:SetScript("OnUpdate", nil)
    frame.desaturationDuration = nil
    frame.Icon:SetDesaturated(false)
    count:SetText("")
    frame.hasCharges = false
    frame.spellID = entry.kind == "cooldown" and entry.spellID or nil
    frame.equipSlot = entry.kind == "slot" and entry.slot or nil
    frame.itemID = entry.kind == "item" and entry.itemID or nil
    if not frame.itemID then frame.requestedItemID = nil end
    if shown and entry.kind == "slot" then
        shown = Internal.UpdateEquippedCooldown(frame, entry)
    elseif shown and entry.kind == "item" then
        Internal.UpdateBagCooldown(frame, entry)
    elseif shown then
        Internal.UpdateSpellCooldown(frame, entry)
    end
    frame.wasSetFromAura = false
    local changed = frame:IsShown() ~= shown
    frame:SetShown(shown)
    if changed then Safe:Notify(Viewers.MESSAGES.LAYOUT_UPDATED, entry.group, Viewers:Get(entry.group)) end
end
function Trackers:Update(event)
    local spells = event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
    local items = event == "BAG_UPDATE_COOLDOWN"
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if frame and (not spells and not items or spells and entry.kind == "cooldown"
            or items and (entry.kind == "slot" or entry.kind == "item")) then
            self:UpdateFrame(frame, entry)
        end
    end
end

--- Bag contents only affect bag-item trackers.
function Trackers:UpdateItems()
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if frame and entry.kind == "item" then self:UpdateFrame(frame, entry) end
    end
end

--- Item data loads for every item the client sees; only tracked items need an update.
function Trackers:OnItemInfoReceived(_, itemID)
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if frame and entry.kind == "item" and entry.itemID == itemID then self:UpdateFrame(frame, entry) end
    end
end

function Trackers:Refresh()
    self:RemoveBuffEntries()
    self:RefreshAvailability()
    for id, frame in pairs(frames) do
        local entry = self.db.profile.entries[id]
        if not entry then
            frame:Hide()
            frame.Cooldown:Clear()
            frames[id] = nil
            pool[#pool + 1] = frame
        elseif not entry.enabled or not self:IsEnabled() then
            frame:Hide()
        end
    end
    for id, entry in pairs(self.db.profile.entries) do
        if entry.enabled and self:IsEnabled() then
            local viewer = Viewers:Get(entry.group)
            local frame = frames[id] or create(id)
            if viewer then
                if frame:GetParent() ~= viewer then
                    frame:SetParent(viewer)
                    frame:ClearAllPoints()
                    frame:SetPoint("TOPLEFT", viewer, "TOPLEFT")
                end
                frame:SetFrameStrata(viewer:GetFrameStrata())
                self:UpdateFrame(frame, entry)
            else
                frame:Hide()
            end
        end
    end
    local Skin = Addon:GetModule("Skin", true)
    for key in pairs(GROUPS) do
        self:SyncGeometry(key)
        -- Reparenting and the destination countdown font must settle before skin caches are updated.
        if Skin and Skin.db then Skin:Apply(key, true) end
        Safe:Notify(Viewers.MESSAGES.LAYOUT_UPDATED, key, Viewers:Get(key))
    end
    Addon:GetModule("Layout"):Request()
end
function Trackers:OnProfileRefresh()
    Internal.InvalidateAvailability()
    self:Refresh()
end

function Trackers:OnItemDataReceived(_, itemID, success)
    for id, entry in pairs(self.db.profile.entries) do
        if entry.kind == "item" and entry.itemID == itemID then
            local frame = frames[id]
            if frame then
                if success == false then
                    Printer:Print("Unable to load data for tracked item " .. itemID .. ".")
                else
                    self:UpdateFrame(frame, entry)
                end
            end
            Options:Refresh()
            return
        end
    end
end

function Trackers:OnInitialize()
    self.db = Addon.db:RegisterNamespace("CustomTrackers", defaults)
    self:RemoveBuffEntries()
end

function Trackers:OnEnable()
    Internal.InvalidateAvailability()
    self:RegisterEvent("SPELLS_CHANGED", "OnSpellbookChanged")
    self:RegisterEvent("PET_BAR_UPDATE", "OnSpellbookChanged")
    self:RegisterEvent("UNIT_PET", "OnSpellbookChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnSpellbookChanged")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "Update")
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "Update")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "Update")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateItems")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "Refresh")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT", "OnItemDataReceived")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnSpellbookChanged")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpellbookChanged")
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "Refresh")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    self:RegisterMessage(Addon:GetModule("Layout").MESSAGES.APPLIED, "OnStackLayout")
    self:Refresh()
end

function Trackers:OnDisable()
    self:Refresh()
end
