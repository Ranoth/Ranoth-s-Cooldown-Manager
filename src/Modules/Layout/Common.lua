--- Layout module for RanothsCooldownManager.
--- Stacks the cast bar, class power, mana bar and cooldown viewers vertically inside one container.
---
--- Design:
--- * The anchor viewer (default Essential) is never moved by us, so Blizzard's Edit Mode keeps owning its position.
--- * Every stack entry gets a "slot" frame. Slots are chained above/below the anchor viewer's slot
---   according to each entry's `position`. Blizzard frames are then attached to their slot.
--- * The container frame spans the whole stack and follows the anchor viewer.
--- @module "Layout"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:NewModule("Layout", "AceEvent-3.0")

local Viewers = RanothsCooldownManager:GetModule("Viewers")
local Resources = RanothsCooldownManager:GetModule("Resources")

Layout.MESSAGES = {
    APPLIED = "RCM_LAYOUT_APPLIED",
}

--- `position` is a plain number per entry (not an array) so AceDB default merging cannot resurrect removed items.
--- Viewers always collapse when hidden; bars collapse only when `collapse` is set.
local defaults = {
    profile = {
        anchorKey = "Essential",
        spacing = 0,
        strata = "LOW",
        width = { mode = "anchor", value = 250 }, -- "anchor" follows the anchor viewer's width, "fixed" uses value
        stack = {
            BuffIcon = { enabled = true, position = 1 },
            CastBar = { enabled = true, position = 2, height = 20, collapse = false },
            ClassPower = { enabled = true, position = 3, height = 12, collapse = true },
            Mana = { enabled = true, position = 4, height = 12, collapse = true },
            Essential = { enabled = true, position = 5 },
            Utility = { enabled = true, position = 6 },
        },
    },
}

local function isViewerKey(key)
    return Viewers.FRAME_NAMES[key] ~= nil
end

local function getFrame(key)
    if isViewerKey(key) then
        return Viewers:Get(key)
    end
    local Bars = RanothsCooldownManager:GetModule("Bars", true)
    return (Bars and Bars:GetFrame(key)) or Resources:Get(key)
end

Layout.Internal = {
    defaults = defaults,
    IsViewerKey = isViewerKey,
    GetFrame = getFrame,
}
