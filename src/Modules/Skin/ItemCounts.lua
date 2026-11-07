local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:GetModule("Skin")
local Internal = Skin.Internal
local state = Internal.state
local LSM = LibStub("LibSharedMedia-3.0")
local countFontString = Internal.CountFontString
local outlineFlags = Internal.OutlineFlags
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

Internal.CategoryItems = CATEGORY_ITEMS
Internal.ItemCounts = itemCounts
Internal.CountItems = countItems
Internal.CountOwners = countOwners
Internal.CountHooked = countHooked
Internal.ApplyItemCount = applyItemCount
Internal.RefreshItemCount = refreshItemCount
