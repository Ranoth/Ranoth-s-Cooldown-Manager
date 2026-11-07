local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local LSM = LibStub("LibSharedMedia-3.0")
local function countFontString(item)
    if item.ChargeCount and item.ChargeCount.Current then return item.ChargeCount.Current end
    if item.Applications and item.Applications.Applications then return item.Applications.Applications end
end
local countdownCache = setmetatable({}, { __mode = "kv" })
local function countdownFontString(item)
    local cooldown = item.Cooldown
    if not cooldown or not cooldown.GetRegions then return nil end
    local cached = countdownCache[cooldown]
    if cached then return cached end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            countdownCache[cooldown] = region
            return region
        end
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

local function applyCountFont(text, st, s)
    if not text then return end
    local path = s.countFont ~= "" and LSM:Fetch("font", s.countFont, true) or nil
    if s.countSize > 0 or path or s.textOutline ~= "" then
        st.font = st.font or { text:GetFont() }
        text:SetFont(path or st.font[1], s.countSize > 0 and s.countSize or st.font[2], outlineFlags(s, st.font[3]))
    elseif st.font then
        text:SetFont(unpack(st.font))
        st.font = nil
    end
end

Internal.CountFontString = countFontString
Internal.CountdownFontString = countdownFontString
Internal.OutlineFlags = outlineFlags
Internal.ApplyCountdownOutline = applyCountdownOutline
Internal.ApplyCountFont = applyCountFont
