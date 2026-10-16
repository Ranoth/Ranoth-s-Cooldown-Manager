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

-- In combat the text and its shown state can be secret values. SetText accepts secrets, SetShown does not,
-- so visibility goes through SetAlphaFromBoolean, which does.
local function syncShown(shadow, text)
    local shown = text:IsShown()
    if pcall(shadow.SetShown, shadow, shown) then
        shadow:SetAlpha(1)
        return
    end
    shadow:Show()
    if shadow.SetAlphaFromBoolean then
        pcall(shadow.SetAlphaFromBoolean, shadow, shown, 1, 0)
    end
end

local function sync(text)
    local shadow = shadows[text]
    if not shadow or not shadow.enabled then return end
    local font, size, flags = text:GetFont()
    if font then pcall(shadow.SetFont, shadow, font, size, flags) end
    pcall(shadow.SetJustifyH, shadow, text:GetJustifyH())
    pcall(shadow.SetJustifyV, shadow, text:GetJustifyV())
    pcall(shadow.SetText, shadow, text:GetText())
    syncShown(shadow, text)
end

local HOOKED = { "SetText", "SetFormattedText", "SetFont", "SetFontObject", "Show", "Hide", "SetShown" }

local function create(text)
    local shadow = text:GetParent():CreateFontString(nil, "OVERLAY")
    shadow:SetTextColor(0, 0, 0, 1)
    shadow:SetShadowOffset(0, 0)
    shadows[text] = shadow
    for _, method in ipairs(HOOKED) do
        if text[method] then hooksecurefunc(text, method, sync) end
    end
    return shadow
end

local poller = CreateFrame("Frame")
local function onPoll()
    for text in pairs(polled) do sync(text) end
end

--- Turn the drop shadow of a FontString on or off. The text itself is never moved.
--- @param text FontString
--- @param enabled boolean
--- @param offset number|nil Shadow distance in pixels, down and to the right (default 2)
--- @param poll boolean|nil Text whose content is changed by C code (cooldown countdown), refreshed every frame
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
    sync(text)

    polled[text] = poll and true or nil
    poller:SetScript("OnUpdate", next(polled) and onPoll or nil)
end
