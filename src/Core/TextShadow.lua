--- TextShadow module for RanothsCooldownManager.
--- Drop shadows drawn as a black copy of a FontString, placed just under it.
--- The native FontString shadow is not used: it widens the text, which pushes right-aligned text to the side,
--- and on the cooldown viewer icons it ends up behind the icon art.
--- @module "TextShadow"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local TextShadow = RanothsCooldownManager:NewModule("TextShadow")

local shadows = setmetatable({}, { __mode = "k" }) -- text -> shadow FontString
local polled = setmetatable({}, { __mode = "k" }) -- texts updated from C code, which no Lua hook can see

local LAYER_BELOW = { HIGHLIGHT = "OVERLAY", OVERLAY = "ARTWORK", ARTWORK = "BORDER", BORDER = "BACKGROUND" }

local function syncShown(text)
    local shadow = shadows[text]
    if not shadow or not shadow.enabled then return end
    -- This API accepts secret booleans; SetShown does not.
    shadow:SetAlphaFromBoolean(text:IsShown(), 1, 0)
end

local function syncText(text)
    local shadow = shadows[text]
    if not shadow or not shadow.enabled then return end
    local value = text:GetText()
    if issecretvalue(value) then
        shadow.lastText = nil
        shadow.hasText = false
    else
        if shadow.hasText and shadow.lastText == value then return end
        shadow.lastText = value
        shadow.hasText = true
    end
    shadow:SetText(value)
end

local function syncFont(text)
    local shadow = shadows[text]
    if not shadow or not shadow.enabled then return end
    local font, size, flags = text:GetFont()
    if font then shadow:SetFont(font, size, flags) end
    shadow:SetJustifyH(text:GetJustifyH())
    shadow:SetJustifyV(text:GetJustifyV())
end

local HOOKED = {
    SetText = syncText, SetFormattedText = syncText,
    SetFont = syncFont, SetFontObject = syncFont,
    SetJustifyH = syncFont, SetJustifyV = syncFont,
    Show = syncShown, Hide = syncShown, SetShown = syncShown,
}

local function create(text)
    local shadow = text:GetParent():CreateFontString(nil, "OVERLAY")
    shadow:SetTextColor(0, 0, 0, 1)
    shadow:SetShadowOffset(0, 0)
    shadows[text] = shadow
    for method, callback in pairs(HOOKED) do
        if text[method] then hooksecurefunc(text, method, callback) end
    end
    return shadow
end

local poller = CreateFrame("Frame")
local elapsedSince = 0
local function onPoll(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.05 then return end
    elapsedSince = 0
    for text in pairs(polled) do
        syncText(text)
        syncShown(text)
    end
end

--- Turn the drop shadow of a FontString on or off. The text itself is never moved.
--- @param text FontString
--- @param enabled boolean
--- @param offset number|nil Shadow distance in pixels, down and to the right (default 2)
--- @param poll boolean|nil Text changed by C code (cooldown countdown), refreshed at most 20 times per second
function TextShadow:Set(text, enabled, offset, poll)
    if not text then return end
    local shadow = shadows[text]
    if not enabled then
        if shadow then
            shadow.enabled = false
            shadow:Hide()
        end
        polled[text] = nil
        poller:SetScript("OnUpdate", next(polled) and onPoll or nil)
        return
    end

    shadow = shadow or create(text)
    shadow.enabled = true
    shadow:Show()
    offset = offset or 2
    local layer = text:GetDrawLayer()
    -- Sublevels are not reliable for FontStrings, so the shadow goes on the top of the layer just below the text.
    local below = LAYER_BELOW[layer]
    if below then
        shadow:SetDrawLayer(below, 7)
    else
        shadow:SetDrawLayer(layer, -8)
    end
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", text, "TOPLEFT", offset, -offset)
    shadow:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", offset, -offset)
    -- Clear any native shadow we may have set before.
    text:SetShadowOffset(0, 0)
    syncFont(text)
    syncText(text)
    syncShown(text)

    polled[text] = poll and true or nil
    poller:SetScript("OnUpdate", next(polled) and onPoll or nil)
end
