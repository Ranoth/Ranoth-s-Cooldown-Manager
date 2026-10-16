--- ResourceSkin module for RanothsCooldownManager.
--- Restyles Blizzard's own resource bars instead of replacing them:
---  * Mana and CastBar are status bars: texture (LibSharedMedia), optional custom color, background, border.
---  * ClassPower differs per class (runes, combo points, charges...), so it only gets a background and border.
--- Defaults leave Blizzard's look untouched. No fields are written onto Blizzard frames; state lives in side tables.
--- @module "ResourceSkin"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local ResourceSkin = RanothsCooldownManager:NewModule("ResourceSkin", "AceEvent-3.0", "AceHook-3.0")

local Resources = RanothsCooldownManager:GetModule("Resources")
local Options = RanothsCooldownManager:GetModule("Options")
local LSM = LibStub("LibSharedMedia-3.0")

ResourceSkin.KEYS = { "CastBar", "Mana" }

local DEFAULT_TEXTURE = "Default"
local WHITE = "Interface\\Buttons\\WHITE8X8"

--- Child art of the cast bar that draws Blizzard's frame; hidden by the "hide Blizzard frame art" option.
local ART_KEYS = { "Border", "BorderShield", "TextBorder", "Background" }

local function barDefaults(isStatusBar)
    return {
        texture = DEFAULT_TEXTURE,
        useColor = false,
        color = { r = 0.2, g = 0.6, b = 1, a = 1 },
        background = false,
        backgroundColor = { r = 0, g = 0, b = 0, a = 0.6 },
        borderSize = 0,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        hideArt = false,
    }
end

local defaults = {
    profile = {
        CastBar = barDefaults(),
        Mana = barDefaults(),
        ClassPower = barDefaults(),
    },
}

local STATUS_BAR = { CastBar = true, Mana = true }

--- frame -> { background, border, original = { texture, color } }
local state = setmetatable({}, { __mode = "k" })
local hookedBars = {}
local applying = false

local function isNeutral(s)
    return s.texture == DEFAULT_TEXTURE and not s.useColor and not s.background and s.borderSize == 0 and not s.hideArt
end

local function createBorder(frame)
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 5)
    border:EnableMouse(false)
    border.edges = {}
    for i = 1, 4 do
        border.edges[i] = border:CreateTexture(nil, "OVERLAY")
        border.edges[i]:SetTexture(WHITE)
    end
    local top, bottom, left, right = unpack(border.edges)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    return border
end

local function applyBorder(frame, st, s)
    if s.borderSize <= 0 then
        if st.border then st.border:Hide() end
        return
    end
    st.border = st.border or createBorder(frame)
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

local function applyBackground(frame, st, s)
    if not s.background then
        if st.background then st.background:Hide() end
        return
    end
    if not st.background then
        st.background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        st.background:SetAllPoints(frame)
        st.background:SetTexture(WHITE)
    end
    local c = s.backgroundColor
    st.background:SetVertexColor(c.r, c.g, c.b, c.a)
    st.background:Show()
end

local function applyArt(frame, s)
    for _, name in ipairs(ART_KEYS) do
        local region = frame[name]
        if type(region) == "table" and region.SetAlpha then
            -- Only the cast bar owns these; the alpha is restored when the option is turned off.
            region:SetAlpha(s.hideArt and 0 or 1)
        end
    end
end

local function applyStatusBar(frame, st, s)
    local bar = frame.GetStatusBarTexture and frame:GetStatusBarTexture()
    if not bar then return end

    if not st.original then
        st.original = { texture = bar:GetAtlas() or bar:GetTexture() }
        st.original.hadColor = false
    end

    local path = s.texture ~= DEFAULT_TEXTURE and LSM:Fetch("statusbar", s.texture, true) or nil
    applying = true
    if path then
        frame:SetStatusBarTexture(path)
    elseif st.original.texture and st.customTexture then
        frame:SetStatusBarTexture(st.original.texture)
    end
    st.customTexture = path ~= nil
    if s.useColor then
        frame:SetStatusBarColor(s.color.r, s.color.g, s.color.b, s.color.a)
        st.customColor = true
    end
    applying = false
end

local function hookBar(key, frame)
    if hookedBars[frame] or not STATUS_BAR[key] then return end
    hookedBars[frame] = true
    local function reapply()
        if applying then return end
        ResourceSkin:Apply(key)
    end
    ResourceSkin:SecureHook(frame, "SetStatusBarTexture", reapply)
    ResourceSkin:SecureHook(frame, "SetStatusBarColor", reapply)
end

--- Apply the saved look to one resource bar.
--- @param key string One of ResourceSkin.KEYS
function ResourceSkin:Apply(key)
    local s = self.db.profile[key]
    local frame = Resources:Get(key)
    local Bars = RanothsCooldownManager:GetModule("Bars", true)
    if not s or not frame or (Bars and Bars:IsCustom(key)) then return end

    local st = state[frame]
    if not st then
        if isNeutral(s) then return end
        st = {}
        state[frame] = st
    end

    if STATUS_BAR[key] then
        hookBar(key, frame)
        applyStatusBar(frame, st, s)
        applyArt(frame, s)
    end
    applyBackground(frame, st, s)
    applyBorder(frame, st, s)
end

function ResourceSkin:ApplyAll()
    for _, key in ipairs(self.KEYS) do
        self:Apply(key)
    end
end

function ResourceSkin:OnResourceMessage(_, key)
    if self.db.profile[key] then self:Apply(key) end
end

local LABELS = {
    CastBar = "Cast bar",
    Mana = "Mana bar",
    ClassPower = "Class power",
}

local function textureValues()
    local values = { [DEFAULT_TEXTURE] = "Blizzard default" }
    for _, name in ipairs(LSM:List("statusbar")) do
        values[name] = name
    end
    return values
end

function ResourceSkin:GetOptions()
    local args = {
        description = {
            type = "description",
            order = 1,
            name = "Restyle Blizzard's resource bars. Every option defaults to Blizzard's look. "
                .. "Turning a color or texture option off may need a /reload to fully restore Blizzard's color.",
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
        local function colorOption(order, name, field, disabled)
            return {
                type = "color",
                order = order,
                name = name,
                hasAlpha = true,
                disabled = disabled,
                get = function()
                    local c = s()[field]
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    s()[field] = { r = r, g = g, b = b, a = a }
                    self:Apply(key)
                end,
            }
        end

        local group = {
            type = "group",
            inline = true,
            order = 10 + i,
            name = LABELS[key],
            args = {
                background = {
                    type = "toggle",
                    order = 10,
                    name = "Background",
                    get = function() return s().background end,
                    set = set("background"),
                },
                backgroundColor = colorOption(11, "Background color", "backgroundColor",
                    function() return not s().background end),
                borderSize = {
                    type = "range",
                    order = 12,
                    name = "Border size",
                    desc = "0 hides the border.",
                    min = 0, max = 6, step = 1,
                    get = function() return s().borderSize end,
                    set = set("borderSize"),
                },
                borderColor = colorOption(13, "Border color", "borderColor",
                    function() return s().borderSize == 0 end),
            },
        }
        if STATUS_BAR[key] then
            group.args.texture = {
                type = "select",
                order = 1,
                name = "Bar texture",
                values = textureValues,
                get = function() return s().texture end,
                set = set("texture"),
            }
            group.args.useColor = {
                type = "toggle",
                order = 2,
                name = "Custom color",
                get = function() return s().useColor end,
                set = set("useColor"),
            }
            group.args.color = colorOption(3, "Bar color", "color", function() return not s().useColor end)
            group.args.hideArt = {
                type = "toggle",
                order = 4,
                name = "Hide Blizzard frame art",
                desc = "Hide Blizzard's border and background artwork on this bar.",
                get = function() return s().hideArt end,
                set = set("hideArt"),
            }
        end
        args[key] = group
    end

    return { type = "group", name = "Resource skin", args = args }
end

function ResourceSkin:OnProfileRefresh()
    self:ApplyAll()
end

function ResourceSkin:OnInitialize()
    self.db = RanothsCooldownManager.db:RegisterNamespace("ResourceSkin", defaults)
    Options:Register("ResourceSkin", self:GetOptions(), 50)
end

function ResourceSkin:OnEnable()
    self:RegisterMessage(Resources.MESSAGES.AVAILABLE, "OnResourceMessage")
    self:RegisterMessage(Resources.MESSAGES.SHOWN, "OnResourceMessage")
    self:RegisterMessage(Resources.MESSAGES.CHANGED, "OnResourceMessage")
    self:ApplyAll()
end
