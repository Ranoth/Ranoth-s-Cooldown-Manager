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
    return not s.square and s.zoom == 0 and s.borderSize == 0 and s.countSize == 0
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
        if s.countSize > 0 then
            st.font = st.font or { text:GetFont() }
            text:SetFont(st.font[1], s.countSize, st.font[3])
        elseif st.font then
            text:SetFont(unpack(st.font))
            st.font = nil
        end
    end
end

--- Apply the saved look to every icon of one viewer.
--- @param key string One of Skin.KEYS
function Skin:Apply(key)
    local s = self.db.profile[key]
    if not s then return end
    for _, item in ipairs(Viewers:GetItems(key)) do
        applyItem(item, s)
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
    self:ApplyAll()
end
