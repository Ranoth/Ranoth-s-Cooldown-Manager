--- Skin module for RanothsCooldownManager.
--- Visual options for the icon viewers (Essential, Utility, BuffIcon): square icons, zoom, border and stack text size.
--- Every option defaults to "Blizzard's look". Nothing is written onto Blizzard frames (their fields are never assigned),
--- all our state lives in side tables and in child frames we create, so Edit Mode and the viewers stay untainted.
--- @module "Skin"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Skin = RanothsCooldownManager:NewModule("Skin", "AceEvent-3.0")

Skin.KEYS = { "Essential", "Utility", "BuffIcon" }

local function viewerDefaults()
    return {
        square = false, -- remove Blizzard's rounded mask and frame overlay
        zoom = 0, -- fraction cropped from every edge of the icon texture
        borderSize = 0, -- 0 = no border
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        countSize = 0, -- 0 = Blizzard's size
        countFont = "", -- LibSharedMedia font name, "" = Blizzard's font
        textOutline = "", -- "" = Blizzard's, "NONE", "OUTLINE", "THICKOUTLINE"
        activeOpaque = false, -- icons whose aura is running ignore the viewer's opacity and show at 100%
    }
end

local defaults = {
    profile = {
        itemCount = true, -- show remaining uses on healthstones in any viewer
        Essential = viewerDefaults(),
        Utility = viewerDefaults(),
        BuffIcon = viewerDefaults(),
    },
}

--- item -> { border, mask, overlay, masked, font }
local state = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })
local revisions = {}

Skin.Internal = {
    defaults = defaults,
    state = state,
    applied = applied,
    revisions = revisions,
}
