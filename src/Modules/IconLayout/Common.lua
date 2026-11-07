--- IconLayout module for RanothsCooldownManager.
--- Optional alternate layouts for the icon viewers (Essential, Utility, BuffIcon):
---  * center: every row of icons is centered in the viewer instead of growing from the left.
---  * compact: active icons are packed together in order, with no gaps for inactive ones.
--- Both default to off, which leaves Blizzard's layout untouched. The viewer's own position stays with Edit Mode.
--- @module "IconLayout"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local IconLayout = RanothsCooldownManager:NewModule("IconLayout", "AceEvent-3.0", "AceHook-3.0")

-- Essential is already centered and never hides icons, Utility never hides icons, so only BuffIcon can compact.
IconLayout.KEYS = { "Utility", "BuffIcon" }

local defaults = {
    profile = {
        spacing = 2, -- gap between icons, only used by compact
        Utility = { center = false },
        BuffIcon = { center = false, compact = false },
    },
}

IconLayout.Internal = {
    defaults = defaults,
    REQUESTED = "RCM_ICON_LAYOUT_REQUESTED",
    applying = {},
    savedPoints = {},
    combined = {},
}
local Internal = IconLayout.Internal

local contentHeights, contentWidths = {}, {}

local function hasCustomItems(key)
    local Trackers = RanothsCooldownManager:GetModule("CustomTrackers", true)
    return Trackers and Trackers.db and Trackers:HasActiveItems(key)
end

function IconLayout:GetContentHeight(key)
    return contentHeights[key]
end

function IconLayout:GetContentWidth(key)
    return contentWidths[key]
end

local function setContentHeight(key, height, width)
    if contentHeights[key] == height and contentWidths[key] == width then return end
    contentHeights[key] = height
    contentWidths[key] = width
    RanothsCooldownManager:GetModule("Layout"):Request()
end

Internal.HasCustomItems = hasCustomItems
Internal.SetContentHeight = setContentHeight
