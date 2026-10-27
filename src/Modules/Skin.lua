--- Skin module for RanothsCooldownManager.
--- Visual options for the icon viewers (Essential, Utility, BuffIcon): square icons, zoom, border and stack text size.
--- Every option defaults to "Blizzard's look". Nothing is written onto Blizzard frames (their fields are never assigned),
--- all our state lives in side tables and in child frames we create, so Edit Mode and the viewers stay untainted.
--- @module "Skin"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:NewModule("Skin", "AceEvent-3.0")

local Viewers = RanothsCooldownManager:GetModule("Viewers")
local LSM = LibStub("LibSharedMedia-3.0")

Skin.KEYS = { "Essential", "Utility", "BuffIcon" }

local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SQUARE_MIN_ZOOM = 0.08
local BLIZZARD_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

local function viewerDefaults()
    return {
        square = false, -- remove Blizzard's rounded mask and frame overlay
        zoom = 0, -- fraction cropped from every edge of the icon texture
        borderSize = 0, -- 0 = no border
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        countSize = 0, -- 0 = Blizzard's size
        countFont = "", -- LibSharedMedia font name, "" = Blizzard's font
        textOutline = "", -- "" = Blizzard's, "NONE", "OUTLINE", "THICKOUTLINE"
        activeOpaque = false, -- icons whose aura is running ignore the viewer's opacity and show at 100%
    }
end

local defaults = {
    profile = {
        itemCount = true, -- show remaining uses on healthstones in any viewer
        Essential = viewerDefaults(),
        Utility = viewerDefaults(),
        BuffIcon = viewerDefaults(),
    },
}

--- item -> { border, mask, overlay, masked, font }
local state = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })
local revisions = {}
local nativeEffects = setmetatable({}, { __mode = "k" })

function Skin:GetGlowInset(key)
    local size = self.db.profile[key].borderSize
    local sharing = RanothsCooldownManager:GetModule("Borders").db.profile
    -- Shared seams are centered on the icon boundary rather than fully inset.
    return sharing.enabled and size / 2 or size
end

--- Fit native ready/proc/pandemic/alert artwork to the area inside our border without replacing its animation.
--- @param force boolean|nil Refit even if cached: pooled frames are re-anchored by Blizzard when acquired.
--- @param levelOffset number|nil Extra level above the base, keeping Blizzard's order between stacked alerts.
--- @param padding number|nil Transparent margin baked into the artwork, which is pushed out so the visible art lines up.
function Skin:FitNativeEffect(item, effect, key, force, levelOffset, padding)
    if not effect then return end
    local icon = item.Icon or item
    local inset = self.db.profile[key].borderSize - (padding or 0)
    local level = item:GetFrameLevel() + 7 + (levelOffset or 0)
    local strata = item:GetFrameStrata()
    local previous = nativeEffects[effect]
    if not force and previous and previous.icon == icon and previous.inset == inset and previous.level == level
        and previous.strata == strata then
        return
    end
    effect:ClearAllPoints()
    effect:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
    effect:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
    -- Pandemic frames carry their own MEDIUM strata, which would ignore the Layout strata option.
    if effect:GetFrameStrata() ~= strata then effect:SetFrameStrata(strata) end
    effect:SetFrameLevel(level)
    effect:SetClipsChildren(true)
    for _, name in ipairs({ "Flipbook", "ProcStartFlipbook", "ProcLoopFlipbook", "ProcAltGlow" }) do
        local texture = effect[name]
        if texture then
            texture:ClearAllPoints()
            texture:SetAllPoints(effect)
        end
    end
    nativeEffects[effect] = { icon = icon, inset = inset, level = level, strata = strata }
end

local effectKeys = setmetatable({}, { __mode = "k" }) -- item -> viewer key, for hooks fired outside Apply
local effectHooked = setmetatable({}, { __mode = "k" })
local pandemicFitted = setmetatable({}, { __mode = "k" })
-- Blizzard anchors the pandemic artwork 6px outside the icon so its ring lands on the icon edge.
local PANDEMIC_PADDING = 6

--- Visual alerts (marching ants, flash) chosen in Cooldown Manager's alert settings.
local function fitAlerts(item, force)
    local key = effectKeys[item]
    local container = key and item.alertContainer
    if not container then return end
    for index, alert in ipairs(container) do
        Skin:FitNativeEffect(item, alert, key, force, index)
    end
end

-- Blizzard checks the pandemic state every frame; only a newly acquired frame needs fitting.
local function fitPandemic(item)
    local key, frame = effectKeys[item], item.PandemicIcon
    if not key or not frame or pandemicFitted[item] == frame then return end
    pandemicFitted[item] = frame
    Skin:FitNativeEffect(item, frame, key, true, nil, PANDEMIC_PADDING)
end

local function hookNativeEffects(item, key)
    effectKeys[item] = key
    if effectHooked[item] then return end
    effectHooked[item] = true
    if item.ShowPandemicStateFrame then hooksecurefunc(item, "ShowPandemicStateFrame", fitPandemic) end
    if item.HidePandemicStateFrame then
        hooksecurefunc(item, "HidePandemicStateFrame", function(i) pandemicFitted[i] = nil end)
    end
    -- AddAlert and RemoveAlert both re-sort through UpdateAlerts, after the alert was anchored.
    if item.UpdateAlerts then hooksecurefunc(item, "UpdateAlerts", function(i) fitAlerts(i, true) end) end
end

--- Pandemic, visual alerts and the buff debuff border, which Blizzard draws outside the icon.
local function fitNativeEffects(item, key)
    hookNativeEffects(item, key)
    Skin:FitNativeEffect(item, item.CooldownFlash, key)
    Skin:FitNativeEffect(item, item.SpellActivationAlert, key)
    Skin:FitNativeEffect(item, item.DebuffBorder, key)
    if item.PandemicIcon then
        pandemicFitted[item] = item.PandemicIcon
        Skin:FitNativeEffect(item, item.PandemicIcon, key, nil, nil, PANDEMIC_PADDING)
    end
    fitAlerts(item)
end

local function isNeutral(s)
    return not s.square and s.zoom == 0 and s.borderSize == 0 and s.countSize == 0 and s.countFont == ""
        and s.textOutline == ""
end

local function findRegions(item)
    local mask, overlay
    for _, region in ipairs({ item:GetRegions() }) do
        local kind = region:GetObjectType()
        if kind == "MaskTexture" then
            mask = region
        elseif kind == "Texture" and region.GetAtlas and region:GetAtlas() == OVERLAY_ATLAS then
            overlay = region
        end
    end
    return mask, overlay
end

local function countFontString(item)
    if item.ChargeCount and item.ChargeCount.Current then return item.ChargeCount.Current end
    if item.Applications and item.Applications.Applications then return item.Applications.Applications end
end

local function createBorder(item, icon)
    local border = CreateFrame("Frame", nil, item)
    border:SetFrameLevel(item:GetFrameLevel() + 5)
    border:EnableMouse(false)
    border.edges = {}
    for i = 1, 4 do
        border.edges[i] = border:CreateTexture(nil, "OVERLAY")
        border.edges[i]:SetTexture(WHITE)
    end
    local top, bottom, left, right = unpack(border.edges)
    top:SetPoint("TOPLEFT", icon, "TOPLEFT")
    top:SetPoint("TOPRIGHT", icon, "TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    left:SetPoint("TOPLEFT", icon, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
    right:SetPoint("TOPRIGHT", icon, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    return border
end

local function applyBorder(item, st, icon, s)
    local Borders = RanothsCooldownManager:GetModule("Borders")
    if s.borderSize <= 0 then
        if st.border then st.border:Hide() end
        if st.border then Borders:Register(item, st.border, icon, 0, s.borderColor, "icons") end
        return
    end
    st.border = st.border or createBorder(item, icon)
    local size, c = s.borderSize, s.borderColor
    local top, bottom, left, right = unpack(st.border.edges)
    top:SetHeight(size)
    bottom:SetHeight(size)
    left:SetWidth(size)
    right:SetWidth(size)
    for _, edge in ipairs(st.border.edges) do
        edge:SetVertexColor(c.r, c.g, c.b, c.a)
    end
    st.border:Show()
    Borders:Register(item, st.border, icon, size, c, "icons")
end

local function countdownFontString(item)
    local cooldown = item.Cooldown
    if not cooldown or not cooldown.GetRegions then return nil end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then return region end
    end
end

local function outlineFlags(s, original)
    if s.textOutline == "NONE" then return "" end
    if s.textOutline and s.textOutline ~= "" then return s.textOutline end
    return original
end

--- Outline of the cooldown countdown; its font and size are left to Blizzard.
local function applyCountdownOutline(text, st, s)
    if not text then return end
    if s.textOutline ~= "" then
        st.cdFont = st.cdFont or { text:GetFont() }
        text:SetFont(st.cdFont[1], st.cdFont[2], outlineFlags(s, st.cdFont[3]))
    elseif st.cdFont then
        text:SetFont(unpack(st.cdFont))
        st.cdFont = nil
    end
end

local function applyItem(item, s, countdown, native)
    local st = state[item]
    if not st and isNeutral(s) and not native then return end

    local icon = item.Icon
    if type(icon) ~= "table" or not icon.SetTexCoord then return end

    if not st then
        st = { masked = true }
        st.mask, st.overlay = findRegions(item)
        state[item] = st
    end

    if native then
        local original = state[native]
        local nativeCountdown = countdownFontString(native)
        if countdown and nativeCountdown then
            local font = original and original.cdFont or { nativeCountdown:GetFont() }
            countdown:SetFont(unpack(font))
            st.cdFont = nil
        end
        local text, nativeText = countFontString(item), countFontString(native)
        if text and nativeText then
            local font = original and original.font or { nativeText:GetFont() }
            text:SetFont(unpack(font))
            st.font = nil
        end
    end

    -- Spell icons carry a rounded, light edge in their own artwork, so square needs a minimum crop to hide it.
    local z = s.square and math.max(s.zoom, SQUARE_MIN_ZOOM) or s.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)

    local cooldown = item.Cooldown
    if cooldown and cooldown.SetSwipeTexture and s.square ~= (st.squareSwipe or false) then
        cooldown:SetSwipeTexture(s.square and WHITE or BLIZZARD_SWIPE)
        st.squareSwipe = s.square
    end

    if st.mask then
        if s.square and st.masked then
            icon:RemoveMaskTexture(st.mask)
            st.masked = false
        elseif not s.square and not st.masked then
            icon:AddMaskTexture(st.mask)
            st.masked = true
        end
    end
    if st.overlay then st.overlay:SetAlpha(s.square and 0 or 1) end

    applyBorder(item, st, icon, s)

    local text = countFontString(item)
    if text then
        local path = s.countFont ~= "" and LSM:Fetch("font", s.countFont, true) or nil
        if s.countSize > 0 or path or s.textOutline ~= "" then
            st.font = st.font or { text:GetFont() }
            text:SetFont(path or st.font[1], s.countSize > 0 and s.countSize or st.font[2], outlineFlags(s, st.font[3]))
        elseif st.font then
            text:SetFont(unpack(st.font))
            st.font = nil
        end
    end

    applyCountdownOutline(countdown, st, s)
end

local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha

-- Child alpha multiplies with the viewer's, so to lift active icons above the viewer's opacity the viewer itself is
-- kept at 1 and the opacity Blizzard asked for is applied to the icons instead.
local baseAlpha = {} -- key -> opacity Blizzard set on the viewer
local alphaApplied = {} -- key -> true while we own the viewer's alpha
local itemAlpha = setmetatable({}, { __mode = "k" })
local alphaHooked = {}
local alphaItems = {}
local alphaItemKeys = setmetatable({}, { __mode = "k" })
local alphaItemHooked = setmetatable({}, { __mode = "k" })
local updateActiveAlpha

local function hookViewerAlpha(key, viewer)
    if alphaHooked[viewer] then return end
    alphaHooked[viewer] = true
    hooksecurefunc(viewer, "SetAlpha", function(_, alpha)
        baseAlpha[key] = alpha
        if alphaApplied[key] then updateActiveAlpha(key) end
    end)
end

local function isItemActive(key, item)
    return key == "BuffIcon" or item.wasSetFromAura == true
end

local function updateItemAlpha(item)
    local key = alphaItemKeys[item]
    if not key or not alphaApplied[key] then return end
    local a = isItemActive(key, item) and 1 or (baseAlpha[key] or 1)
    if itemAlpha[item] ~= a then
        itemAlpha[item] = a
        rawSetAlpha(item, a)
    end
end

updateActiveAlpha = function(key)
    local viewer = Viewers:Get(key)
    local s = Skin.db.profile[key]
    if not viewer or not s then return end
    local items = alphaItems[key]
    if not items then return end
    hookViewerAlpha(key, viewer)

    if not s.activeOpaque then
        if alphaApplied[key] then
            alphaApplied[key] = nil
            rawSetAlpha(viewer, baseAlpha[key] or 1)
            for _, item in ipairs(items) do
                if alphaItemKeys[item] == key then
                    if itemAlpha[item] then rawSetAlpha(item, 1) end
                    itemAlpha[item] = nil
                    alphaItemKeys[item] = nil
                end
            end
        end
        return
    end

    if not alphaApplied[key] then
        baseAlpha[key] = baseAlpha[key] or viewer:GetAlpha()
        alphaApplied[key] = true
    end
    if viewer:GetAlpha() ~= 1 then rawSetAlpha(viewer, 1) end
    for _, item in ipairs(items) do
        if not item.trackerID or item:GetParent() == viewer then
            alphaItemKeys[item] = key
            -- This finishes after Blizzard has chosen between aura and cooldown display.
            if key ~= "BuffIcon" and not alphaItemHooked[item] and item.CacheCooldownValues then
                hooksecurefunc(item, "CacheCooldownValues", updateItemAlpha)
                alphaItemHooked[item] = true
            end
            updateItemAlpha(item)
        end
    end
end

--- Item cooldowns Blizzard shows without any stack count: spell category -> item whose remaining uses we display.
local CATEGORY_ITEMS = {
    [1711] = 5512, -- Healthstone
    [2566] = 224464, -- Demonic Healthstone
}

local itemCounts = setmetatable({}, { __mode = "k" }) -- item -> our own FontString
local countItems = {} -- Healthstone item frame -> viewer key, including stones with no remaining uses
local countOwners = setmetatable({}, { __mode = "k" })
local countHooked = setmetatable({}, { __mode = "k" })

local function itemCountText(item)
    local text = itemCounts[item]
    if text then return text end
    local holder = CreateFrame("Frame", nil, item)
    holder:SetAllPoints(item)
    holder:SetFrameLevel(item:GetFrameLevel() + 6)
    holder:EnableMouse(false)
    text = holder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
    local source = countFontString(item)
    local font, size, flags = "Fonts\\ARIALN.TTF", 16, "OUTLINE"
    if source then
        local f, sz, fl = source:GetFont()
        font, size, flags = f or font, sz or size, fl or flags
    end
    text:SetFont(font, size, flags)
    text.holder = holder
    itemCounts[item] = text
    return text
end

local function applyItemCount(item, s, style)
    local info = item.cooldownInfo
    local itemID = type(info) == "table" and CATEGORY_ITEMS[info.spellCategoryID]
    local text = itemCounts[item]
    if not (Skin.db.profile.itemCount and itemID) then
        if text then text.holder:Hide() end
        return
    end
    -- The second and third arguments include charges, so this is the number of uses left rather than the stack size.
    local ok, count = pcall(C_Item.GetItemCount, itemID, false, true)
    if not ok or type(count) ~= "number" or count <= 0 then
        if text then text.holder:Hide() end
        return
    end
    local created = not text
    text = itemCountText(item)
    if style or created then
        local st = state[item]
        local font, size, flags
        if st and st.font then
            font, size, flags = unpack(st.font)
        else
            local source = countFontString(item)
            if source then font, size, flags = source:GetFont() end
        end
        font, size, flags = font or "Fonts\\ARIALN.TTF", size or 16, flags or "OUTLINE"
        local path = s.countFont ~= "" and LSM:Fetch("font", s.countFont, true) or nil
        text:SetFont(path or font, s.countSize > 0 and s.countSize or size, outlineFlags(s, flags))
    end
    if text.lastCount ~= count then
        text:SetText(count)
        text.lastCount = count
    end
    text.holder:Show()
end

local function refreshItemCount(item)
    local key = countOwners[item]
    if not key then return end
    local s = Skin.db.profile[key]
    local info = item.cooldownInfo
    local tracked = Skin.db.profile.itemCount and type(info) == "table" and CATEGORY_ITEMS[info.spellCategoryID]
    countItems[item] = tracked and key or nil
    applyItemCount(item, s)
end

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
            applyItem(item, s, countdown, item.trackerID and native or nil)
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
