local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local state = Internal.state
local countFontString = Internal.CountFontString
local countdownFontString = Internal.CountdownFontString
local applyCountdownOutline = Internal.ApplyCountdownOutline
local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SQUARE_MIN_ZOOM = 0.08
local BLIZZARD_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
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

local function applyBorder(item, st, icon, s, key)
    local Borders = RanothsCooldownManager:GetModule("Borders")
    if s.borderSize <= 0 then
        if st.border then st.border:Hide() end
        if st.border then Borders:Register(item, st.border, icon, 0, s.borderColor, "icons", key) end
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
    Borders:Register(item, st.border, icon, size, c, "icons", key)
end
local function applyItem(item, s, countdown, native, key)
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

    applyBorder(item, st, icon, s, key)

    local text = countFontString(item)
    Internal.ApplyCountFont(text, st, s)

    applyCountdownOutline(countdown, st, s)
end

Internal.ApplyItem = applyItem
