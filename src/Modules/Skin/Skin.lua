local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local Viewers = RanothsCooldownManager:GetModule("Viewers")
local defaults = Internal.defaults
local state, applied, revisions = Internal.state, Internal.applied, Internal.revisions
local rawSetAlpha, itemAlpha = Internal.RawSetAlpha, Internal.ItemAlpha
local alphaItems, alphaItemKeys = Internal.AlphaItems, Internal.AlphaItemKeys
local updateActiveAlpha = Internal.UpdateActiveAlpha
local fitNativeEffects, applyItem = Internal.FitNativeEffects, Internal.ApplyItem
local countdownFontString, countFontString = Internal.CountdownFontString, Internal.CountFontString
local CATEGORY_ITEMS, itemCounts = Internal.CategoryItems, Internal.ItemCounts
local countItems, countOwners, countHooked = Internal.CountItems, Internal.CountOwners, Internal.CountHooked
local applyItemCount, refreshItemCount = Internal.ApplyItemCount, Internal.RefreshItemCount
--- Settings changes invalidate the viewer's styling; layout messages only reconcile changed items.
--- @param key string One of Skin.KEYS
--- @param incremental boolean|nil Keep styling already applied to unchanged frames.
function Skin:Apply(key, incremental)
    local s = self.db.profile[key]
    if not s then return end
    if not incremental then revisions[key] = (revisions[key] or 0) + 1 end
    local revision = revisions[key] or 0
    local items = Viewers:GetItems(key)
    local native = Viewers:GetNativeItems(key)[1]
    alphaItems[key] = items
    for _, item in ipairs(items) do
        if alphaItemKeys[item] and alphaItemKeys[item] ~= key then
            rawSetAlpha(item, 1)
            itemAlpha[item] = nil
            alphaItemKeys[item] = nil
        end
        fitNativeEffects(item, key)
        local countdown = countdownFontString(item)
        local text = countFontString(item)
        local previous = applied[item]
        local dirty = not previous or previous.key ~= key or previous.revision ~= revision
            or previous.cooldownID ~= item.cooldownID or previous.icon ~= item.Icon
            or previous.cooldown ~= item.Cooldown or previous.text ~= text or previous.countdown ~= countdown
        if dirty then
            -- Custom icons reset their countdown font when changing viewer groups.
            if item.trackerID and previous and previous.key ~= key and state[item] then
                state[item].cdFont = nil
            end
            applyItem(item, s, countdown, item.trackerID and native or nil, key)
            applied[item] = {
                key = key, revision = revision, cooldownID = item.cooldownID, icon = item.Icon,
                cooldown = item.Cooldown, text = text, countdown = countdown,
            }
        end
        countOwners[item] = key
        if not countHooked[item] then
            countHooked[item] = true
            if item.SetCooldownID then hooksecurefunc(item, "SetCooldownID", refreshItemCount) end
            item:HookScript("OnShow", refreshItemCount)
        end
        local info = item.cooldownInfo
        local tracked = self.db.profile.itemCount and type(info) == "table" and CATEGORY_ITEMS[info.spellCategoryID]
        countItems[item] = tracked and key or nil
        applyItemCount(item, s, dirty)
    end
    for item, owner in pairs(countItems) do
        if owner == key then
            local active = false
            for _, current in ipairs(items) do
                if current == item then active = true; break end
            end
            if not active then
                countItems[item] = nil
                countOwners[item] = nil
                local text = itemCounts[item]
                if text then text.holder:Hide() end
            end
        end
    end
    updateActiveAlpha(key)
end

--- Bag/cooldown events only revisit known Healthstone icons; viewer refreshes rebuild the registry.
function Skin:UpdateCounts()
    for item, key in pairs(countItems) do
        applyItemCount(item, self.db.profile[key])
    end
end

function Skin:ApplyAll()
    for _, key in ipairs(self.KEYS) do
        self:Apply(key)
    end
end

function Skin:OnViewerMessage(_, key)
    if self.db.profile[key] then self:Apply(key, true) end
end

function Skin:DescribeTrackers()
    local Printer = RanothsCooldownManager:GetModule("Printer")
    local function value(v)
        if issecretvalue(v) then return "<restricted>" end
        if type(v) == "number" then return string.format("%.4g", v) end
        return tostring(v)
    end
    local function describe(item, key, label)
        local st, previous = state[item], applied[item]
        local s = self.db.profile[key]
        local coords = item.Icon and { item.Icon:GetTexCoord() } or {}
        local crop = {}
        for i, coordinate in ipairs(coords) do crop[i] = value(coordinate) end
        local countdown = countdownFontString(item)
        local font, size, flags
        if countdown then font, size, flags = countdown:GetFont() end
        local count = countFontString(item)
        local countFont, countSize
        if count then countFont, countSize = count:GetFont() end
        Printer:Print(label .. " group=" .. key .. " applied=" .. value(previous and previous.key)
            .. " base=" .. value(item.skinGroup) .. " scale=" .. value(item:GetEffectiveScale())
            .. " square=" .. value(s.square) .. " zoom=" .. value(s.zoom)
            .. " alpha=" .. value(item:GetAlpha()) .. " viewerAlpha=" .. value(Viewers:Get(key):GetAlpha())
            .. " alphaOwner=" .. value(alphaItemKeys[item]) .. " activeOpaque=" .. value(s.activeOpaque)
            .. " crop=" .. table.concat(crop, ","))
        Printer:Print("  mask=" .. value(st and st.mask ~= nil) .. " masked=" .. value(st and st.masked)
            .. " overlay=" .. value(st and st.overlay and st.overlay:GetAlpha())
            .. " border=" .. value(s.borderSize) .. "/" .. value(st and st.border and st.border:IsShown())
            .. " countdown=" .. value(font) .. "/" .. value(size) .. "/" .. value(flags)
            .. " count=" .. value(countFont) .. "/" .. value(countSize))
    end
    Printer:Print("Tracker skin diagnostic (run after moving Utility -> Essential; no styling is changed):")
    local Trackers = RanothsCooldownManager:GetModule("CustomTrackers")
    for _, key in ipairs(self.KEYS) do
        local items = Trackers:GetItems(key)
        if #items > 0 then
            local native = Viewers:GetNativeItems(key)[1]
            if native then describe(native, key, "Native") end
            for _, item in ipairs(items) do describe(item, key, "Tracker " .. value(item.trackerID)) end
        end
    end
end

function Skin:MigrateItemCount()
    local profile = self.db.profile
    local enabled = rawget(profile, "itemCount")
    for _, key in ipairs(self.KEYS) do
        if enabled == nil and rawget(profile[key], "itemCount") == false then
            enabled = false
        end
        profile[key].itemCount = nil
    end
    profile.itemCount = enabled ~= false
end

function Skin:OnProfileRefresh()
    self:MigrateItemCount()
    self:ApplyAll()
end

function Skin:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Skin", defaults)
    self:MigrateItemCount()
end

function Skin:OnEnable()
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateCounts")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateCounts")
    self:ApplyAll()
end
