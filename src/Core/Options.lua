--- Options module for RanothsCooldownManager.
--- Owns the standalone settings window and the Blizzard Settings entry. Feature modules contribute
--- their own option groups with Options:Register instead of editing this file.
--- @module "Options"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Options = RanothsCooldownManager:NewModule("Options")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local Debug = RanothsCooldownManager:GetModule("Debug")

local APP = addon_name
local BLIZ_APP = addon_name .. "_Blizzard"
local TITLE = "Ranoth's Cooldown Manager"

local registered = {}

--- Add an option group to the settings window.
--- @param name string Unique key, also used as the tree entry's identifier
--- @param group table|function An AceConfig group, or a function returning one (rebuilt on every refresh)
--- @param order number Position in the tree; lower is higher
function Options:Register(name, group, order)
    registered[#registered + 1] = { name = name, group = group, order = order or 50 }
end

local function buildGeneral()
    return {
        type = "group",
        name = "General",
        order = 1,
        args = {
            debug = {
                type = "toggle",
                name = "Debug mode",
                desc = "Print extra diagnostic messages.",
                order = 1,
                get = function() return Debug:IsEnabled() end,
                set = function(_, value)
                    if value ~= Debug:IsEnabled() then Debug:Toggle() end
                end,
            },
        },
    }
end

--- Build the whole options tree. Called by AceConfig whenever the window refreshes.
function Options:Build()
    local root = {
        type = "group",
        name = TITLE,
        childGroups = "tree",
        args = { general = buildGeneral() },
    }

    for _, entry in ipairs(registered) do
        local group = type(entry.group) == "function" and entry.group() or entry.group
        group.order = group.order or entry.order
        root.args[entry.name] = group
    end

    local profiles = AceDBOptions:GetOptionsTable(RanothsCooldownManager.db)
    profiles.order = 100
    root.args.profiles = profiles
    return root
end

--- Re-render the window if it is open.
function Options:Refresh()
    AceConfigRegistry:NotifyChange(APP)
end

function Options:Open()
    -- The Blizzard Settings window would sit on top of ours.
    if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then
        HideUIPanel(SettingsPanel)
    end
    AceConfigDialog:Open(APP)
end

function Options:Close()
    AceConfigDialog:Close(APP)
end

function Options:Toggle()
    if AceConfigDialog.OpenFrames[APP] then
        self:Close()
    else
        self:Open()
    end
end

--- Let every module re-apply its settings after a profile switch, copy, or reset.
function Options:OnProfileRefresh()
    for _, module in RanothsCooldownManager:IterateModules() do
        if module.OnProfileRefresh then
            module:OnProfileRefresh()
        end
    end
    self:Refresh()
end

function Options:OnInitialize()
    AceConfig:RegisterOptionsTable(APP, function() return self:Build() end)
    AceConfigDialog:SetDefaultSize(APP, 780, 560)

    -- A small panel in the Blizzard AddOns tab so the addon shows up in Settings search.
    AceConfig:RegisterOptionsTable(BLIZ_APP, {
        type = "group",
        name = TITLE,
        args = {
            description = {
                type = "description",
                name = "Improves the default Cooldown Manager: stacks resource bars with the viewers, "
                    .. "and adds centering and compacting of icons and buff bars.",
                fontSize = "medium",
                order = 1,
            },
            open = {
                type = "execute",
                name = "Open settings",
                order = 2,
                func = function() self:Open() end,
            },
        },
    })
    AceConfigDialog:AddToBlizOptions(BLIZ_APP, TITLE)

    local db = RanothsCooldownManager.db
    db.RegisterCallback(self, "OnProfileChanged", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileCopied", "OnProfileRefresh")
    db.RegisterCallback(self, "OnProfileReset", "OnProfileRefresh")
end
