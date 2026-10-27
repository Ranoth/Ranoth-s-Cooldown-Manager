local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:NewModule("CustomTrackers", "AceEvent-3.0")
local Viewers = Addon:GetModule("Viewers")
local Options = Addon:GetModule("Options")
local Safe = Addon:GetModule("Safe")
local Printer = Addon:GetModule("Printer")
local GROUPS = { Essential = "Essential cooldowns", Utility = "Utility cooldowns", BuffIcon = "Buff icons" }
local defaults = { profile = { entries = {}, nextID = 1 } }
local frames = {}
local pool = {}
local availableSpells = {}
local checkedSpells = {}
local availabilityDirty = true
local SLOTS = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest",
    [6] = "Waist (belt)", [7] = "Legs", [8] = "Feet", [9] = "Wrists", [10] = "Hands",
    [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back", [16] = "Main hand", [17] = "Off hand", [19] = "Tabard",
}
Trackers.SLOTS, Trackers.GROUPS = SLOTS, GROUPS
local cooldownDesaturation, chargeDesaturation
local visuals = {
    Essential = { font = "GameFontHighlightHugeOutline", x = 9, y = 8 },
    Utility = { font = "GameFontHighlightOutline", x = 6, y = 5 },
    BuffIcon = { x = 8, y = 7 },
}

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

local function byTrackerID(a, b) return a.trackerID < b.trackerID end

function Trackers:GetItems(key)
    local result = {}
    if not self:IsEnabled() then return result end
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if entry.enabled and self:IsAvailable(entry) and entry.group == key and frame and frame:GetParent() == Viewers:Get(key) then
            result[#result + 1] = frame
        end
    end
    table.sort(result, byTrackerID)
    return result
end

function Trackers:HasActiveItems(key)
    for _, frame in ipairs(self:GetItems(key)) do
        if frame:IsShown() then return true end
    end
    return false
end

function Trackers:GetReservedHeight(key)
    local items = self:GetItems(key)
    local viewer = Viewers:Get(key)
    if #items == 0 or not viewer then return nil end
    local height, width, iconScale = 0, 0, 1
    for _, item in ipairs(items) do
        local value = item:GetHeight()
        local scale = item:GetEffectiveScale() / viewer:GetEffectiveScale()
        if not issecretvalue(value) and not issecretvalue(scale) then
            height = math.max(height, value * scale)
            local itemWidth = item:GetWidth()
            if not issecretvalue(itemWidth) then width = math.max(width, itemWidth * scale) end
            iconScale = scale
        end
    end
    local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer
    local settings = Addon:GetModule("IconLayout").db.profile
    local spacing = settings[key] and settings[key].compact and settings.spacing
        or (container.childYPadding or 0) * iconScale
    local stride = container.stride or viewer.iconLimit
    if issecretvalue(stride) or type(stride) ~= "number" or stride < 1 then
        local gap = settings[key] and settings[key].compact and settings.spacing
            or (container.childXPadding or 0) * iconScale
        stride = math.max(1, math.floor((viewer:GetWidth() + gap) / math.max(width + gap, 1)))
    end
    local total = #Viewers:GetNativeItems(key) + #items
    local horizontal = (settings[key] and settings[key].compact) or container.isHorizontal ~= false
    local rows = horizontal and math.ceil(total / stride) or math.min(total, stride)
    -- Reserve the combined grid's capacity, not extra rows on top of already available native slots.
    return rows * height + math.max(0, rows - 1) * spacing
end

function Trackers:SyncGeometry(key)
    local viewer = Viewers:Get(key)
    if not viewer then return end
    local native = Viewers:GetNativeItems(key)[1]
    local width, height, scale
    if native then
        width, height = native:GetWidth(), native:GetHeight()
        scale = native:GetEffectiveScale() / viewer:GetEffectiveScale()
        if issecretvalue(width) or issecretvalue(height) or issecretvalue(scale)
            or width <= 0 or height <= 0 or scale <= 0 then return end
    end
    for _, frame in ipairs(self:GetItems(key)) do
        if native then
            frame:SetSize(width, height)
            frame:SetScale(scale)
        end
        if frame.skinGroup ~= key then
            local style = visuals[key]
            frame.skinGroup = key
            if style.font then
                frame.Cooldown:SetCountdownFont(style.font)
            else
                frame.countdownText:SetFont(unpack(frame.defaultCountdownFont))
            end
            frame.IconOverlay:ClearAllPoints()
            frame.IconOverlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -style.x, style.y)
            frame.IconOverlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style.x, -style.y)
        end
        frame.Cooldown:SetHideCountdownNumbers(viewer.timerShown == false)
        -- Same as Blizzard's items: tooltips only need mouse motion, and clicks pass through.
        local tooltips = viewer.tooltipsShown ~= false
        if frame.tooltipsShown ~= tooltips then
            frame.tooltipsShown = tooltips
            frame:SetMouseClickEnabled(false)
            frame:SetMouseMotionEnabled(tooltips)
            if not tooltips and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        end
    end
end

function Trackers:OrderItems(active)
    local custom = {}
    for i = #active, 1, -1 do
        if active[i].frame.trackerID then custom[#custom + 1] = table.remove(active, i) end
    end
    table.sort(custom, function(a, b)
        local pa = self.db.profile.entries[a.frame.trackerID].position
        local pb = self.db.profile.entries[b.frame.trackerID].position
        if pa ~= pb then return pa < pb end
        return a.frame.trackerID < b.frame.trackerID
    end)
    local previousPosition = 0
    for _, item in ipairs(custom) do
        local position = self.db.profile.entries[item.frame.trackerID].position
        -- Keep ties and positions beyond the last slot in the same sorted order.
        position = math.min(math.max(position, previousPosition + 1), #active + 1)
        table.insert(active, position, item)
        previousPosition = position
    end
end

local function create(id)
    local reused = table.remove(pool)
    if reused then
        reused.trackerID = id
        reused.warnedCooldown = nil
        reused.requestedItemID = nil
        frames[id] = reused
        return reused
    end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.trackerID = id
    frame:SetSize(36, 36)
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetAllPoints()
    local mask = frame:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    mask:SetAllPoints()
    frame.Icon:AddMaskTexture(mask)
    frame.IconOverlay = frame:CreateTexture(nil, "OVERLAY")
    frame.IconOverlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetAllPoints()
    frame.Cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe")
    frame.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
    frame.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
    frame.Cooldown:SetDrawEdge(false)
    for _, region in ipairs({ frame.Cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            frame.countdownText = region
            frame.defaultCountdownFont = { region:GetFont() }
            break
        end
    end
    frame.Cooldown:HookScript("OnCooldownDone", function()
        frame.Icon:SetDesaturated(false)
        frame.desaturationDuration = nil
        frame:SetScript("OnUpdate", nil)
    end)
    frame:SetScript("OnHide", function(self)
        self.desaturationDuration = nil
        self:SetScript("OnUpdate", nil)
    end)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame.Cooldown:GetFrameLevel() - 1)
    local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.Applications = { Applications = count }
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.equipSlot then
            GameTooltip:SetInventoryItem("player", self.equipSlot)
        elseif self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetSpellByID(self.spellID)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.GetSpellID = function(self) return self.spellID end
    frame.GetEquipSlot = function(self) return self.equipSlot end
    frame.GetItemID = function(self) return self.itemID end
    frame.GetCooldownFrame = function(self) return self.Cooldown end
    frame.HasVisualDataSource_Charges = function(self) return self.hasCharges end
    frame.isCustomTracker = true
    frame:Hide()
    frames[id] = frame
    return frame
end

local function setIconTexture(frame, texture)
    if frame.iconTexture == texture then return end
    local coordinates = { frame.Icon:GetTexCoord() }
    frame.Icon:SetTexture(texture)
    frame.Icon:SetTexCoord(unpack(coordinates))
    frame.iconTexture = texture
end

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
        local texture = GetInventoryItemTexture("player", entry.slot)
        setIconTexture(frame, texture)
        shown = GetInventoryItemID("player", entry.slot) ~= nil
        if shown then
            local start, duration, enabled, gcd = GetInventoryItemCooldown("player", entry.slot)
            setItemCooldown(frame, start, duration, enabled, gcd, SLOTS[entry.slot])
        end
    elseif shown and entry.kind == "item" then
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
    elseif shown then
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
    frame.wasSetFromAura = false
    local changed = frame:IsShown() ~= shown
    frame:SetShown(shown)
    if changed then Safe:Notify(Viewers.MESSAGES.LAYOUT_UPDATED, entry.group, Viewers:Get(entry.group)) end
end

function Trackers:Update()
    for id, entry in pairs(self.db.profile.entries) do
        local frame = frames[id]
        if frame then self:UpdateFrame(frame, entry) end
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

function Trackers:OnViewerMessage(_, key)
    if not GROUPS[key] then return end
    self:SyncGeometry(key)
    -- Only reconcile geometry here: publishing another viewer message would create a refresh loop.
    for _, frame in ipairs(self:GetItems(key)) do
        frame:SetFrameStrata(Viewers:Get(key):GetFrameStrata())
    end
end

function Trackers:OnStackLayout()
    for key in pairs(GROUPS) do self:OnViewerMessage(nil, key) end
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

function Trackers:OnProfileRefresh()
    availabilityDirty = true
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
    availabilityDirty = true
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
