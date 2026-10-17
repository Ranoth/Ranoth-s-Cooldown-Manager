--- Skin module for RanothsCooldownManager.
--- Visual options for the icon viewers (Essential, Utility, BuffIcon): square icons, zoom, border and stack text size.
--- Every option defaults to "Blizzard's look". Nothing is written onto Blizzard frames (their fields are never assigned),
--- all our state lives in side tables and in child frames we create, so Edit Mode and the viewers stay untainted.
--- @module "Skin"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:NewModule("Skin", "AceEvent-3.0")

local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Options = RanothsCooldownManager:GetModule("Options")
local TextShadow = RanothsCooldownManager:GetModule("TextShadow")
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
        textShadow = false,
        shadowOffset = 2,
        textOutline = "", -- "" = Blizzard's, "NONE", "OUTLINE", "THICKOUTLINE"
        activeOpaque = false, -- icons whose aura is running ignore the viewer's opacity and show at 100%
        itemCount = true, -- show remaining uses on healthstones
    }
end

local defaults = {
    profile = {
        Essential = viewerDefaults(),
        Utility = viewerDefaults(),
        BuffIcon = viewerDefaults(),
    },
}

--- item -> { border, mask, overlay, masked, font }
local state = setmetatable({}, { __mode = "k" })

local function isNeutral(s)
    return not s.square and s.zoom == 0 and s.borderSize == 0 and s.countSize == 0 and s.countFont == ""
        and s.textOutline == "" and not s.textShadow
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
    if s.borderSize <= 0 then
        if st.border then st.border:Hide() end
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

local function applyShadow(text, s, poll)
    TextShadow:Set(text, s.textShadow, s.shadowOffset, poll)
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

local function applyItem(item, s)
    local st = state[item]
    if not st and isNeutral(s) then return end

    local icon = item.Icon
    if type(icon) ~= "table" or not icon.SetTexCoord then return end

    if not st then
        st = { masked = true }
        st.mask, st.overlay = findRegions(item)
        state[item] = st
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

    local countdown = countdownFontString(item)
    applyCountdownOutline(countdown, st, s)
    applyShadow(text, s)
    applyShadow(countdown, s, item.Cooldown)
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
                if itemAlpha[item] then rawSetAlpha(item, 1) end
                itemAlpha[item] = nil
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
        alphaItemKeys[item] = key
        -- This finishes after Blizzard has chosen between aura and cooldown display.
        if key ~= "BuffIcon" and not alphaItemHooked[item] and item.CacheCooldownValues then
            hooksecurefunc(item, "CacheCooldownValues", updateItemAlpha)
            alphaItemHooked[item] = true
        end
        updateItemAlpha(item)
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
    if not (s.itemCount and itemID) then
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
        applyShadow(text, s)
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
    local tracked = s.itemCount and type(info) == "table" and CATEGORY_ITEMS[info.spellCategoryID]
    countItems[item] = tracked and key or nil
    applyItemCount(item, s)
end

--- Apply the saved look to every icon of one viewer.
--- @param key string One of Skin.KEYS
function Skin:Apply(key)
    local s = self.db.profile[key]
    if not s then return end
    local items = Viewers:GetItems(key)
    alphaItems[key] = items
    for item, owner in pairs(countItems) do
        if owner == key then
            countItems[item] = nil
            local text = itemCounts[item]
            if text then text.holder:Hide() end
        end
    end
    for _, item in ipairs(items) do
        applyItem(item, s)
        countOwners[item] = key
        if not countHooked[item] then
            countHooked[item] = true
            if item.SetCooldownID then hooksecurefunc(item, "SetCooldownID", refreshItemCount) end
            item:HookScript("OnShow", refreshItemCount)
        end
        local info = item.cooldownInfo
        if s.itemCount and type(info) == "table" and CATEGORY_ITEMS[info.spellCategoryID] then
            countItems[item] = key
        end
        applyItemCount(item, s, true)
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
    if self.db.profile[key] then self:Apply(key) end
end

local LABELS = {
    Essential = "Essential cooldowns",
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

function Skin:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Change how the cooldown icons look. Every option defaults to Blizzard's look.",
        },
    }

    for i, key in ipairs(self.KEYS) do
        local function s() return self.db.profile[key] end
        local function set(field)
            return function(_, value)
                s()[field] = value
                self:Apply(key)
            end
        end
        args[key] = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                square = {
                    type = "toggle",
                    order = 1,
                    name = "Square icons",
                    desc = "Remove Blizzard's rounded corners and frame.",
                    get = function() return s().square end,
                    set = set("square"),
                },
                zoom = {
                    type = "range",
                    order = 2,
                    name = "Zoom",
                    desc = "Crop the edges of the icon artwork.",
                    min = 0, max = 0.3, step = 0.01, isPercent = true,
                    get = function() return s().zoom end,
                    set = set("zoom"),
                },
                borderSize = {
                    type = "range",
                    order = 3,
                    name = "Border size",
                    desc = "0 hides the border.",
                    min = 0, max = 6, step = 1,
                    get = function() return s().borderSize end,
                    set = set("borderSize"),
                },
                borderColor = {
                    type = "color",
                    order = 4,
                    name = "Border color",
                    hasAlpha = true,
                    disabled = function() return s().borderSize == 0 end,
                    get = function()
                        local c = s().borderColor
                        return c.r, c.g, c.b, c.a
                    end,
                    set = function(_, r, g, b, a)
                        s().borderColor = { r = r, g = g, b = b, a = a }
                        self:Apply(key)
                    end,
                },
                countSize = {
                    type = "range",
                    order = 5,
                    name = "Stack text size",
                    desc = "0 keeps Blizzard's size.",
                    min = 0, max = 32, step = 1,
                    get = function() return s().countSize end,
                    set = set("countSize"),
                },
                countFont = {
                    type = "select",
                    order = 5.5,
                    name = "Stack text font",
                    desc = "Font of the stack count and the Healthstone charges.",
                    values = function()
                        local values = { [""] = "Blizzard default" }
                        for _, name in ipairs(LSM:List("font")) do values[name] = name end
                        return values
                    end,
                    get = function() return s().countFont end,
                    set = set("countFont"),
                },
                textShadow = {
                    type = "toggle",
                    order = 6,
                    name = "Text shadow",
                    desc = "Add a shadow to the cooldown countdown and the stack count.",
                    get = function() return s().textShadow end,
                    set = set("textShadow"),
                },
                shadowOffset = {
                    type = "range",
                    order = 6.1,
                    name = "Shadow offset",
                    min = 1, max = 4, step = 1,
                    disabled = function() return not s().textShadow end,
                    get = function() return s().shadowOffset end,
                    set = set("shadowOffset"),
                },
                textOutline = {
                    type = "select",
                    order = 6.2,
                    name = "Text outline",
                    desc = "Blizzard's text has a black outline, which hides most of a shadow. Pick \"None\" for a pure drop shadow.",
                    values = { [""] = "Blizzard default", NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" },
                    sorting = { "", "NONE", "OUTLINE", "THICKOUTLINE" },
                    get = function() return s().textOutline end,
                    set = set("textOutline"),
                },
                activeOpaque = {
                    type = "toggle",
                    order = 7,
                    name = "Full opacity when active",
                    desc = "Icons whose buff or aura is running are shown at 100% opacity, while the others keep the viewer's opacity set in Edit Mode.",
                    width = "double",
                    get = function() return s().activeOpaque end,
                    set = set("activeOpaque"),
                },
                itemCount = {
                    type = "toggle",
                    order = 8,
                    name = "Healthstone charges",
                    desc = "Show how many uses a Healthstone or Demonic Healthstone has left as a stack count.",
                    get = function() return s().itemCount end,
                    set = set("itemCount"),
                },
            },
        }
    end

    return { type = "group", name = "Icon skin", args = args }
end

function Skin:OnProfileRefresh()
    self:ApplyAll()
end

function Skin:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("Skin", defaults)
    Options:Register("Skin", self:GetOptions(), 40)
end

function Skin:OnEnable()
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateCounts")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateCounts")
    self:ApplyAll()
end
