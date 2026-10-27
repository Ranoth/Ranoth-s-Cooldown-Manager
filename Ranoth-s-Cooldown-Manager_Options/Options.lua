local Addon = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Options = Addon:GetModule("Options")
local Debug = Addon:GetModule("Debug")
local AceConfig = LibStub("AceConfig-3.0")
local Dialog = LibStub("AceConfigDialog-3.0")
local Registry = LibStub("AceConfigRegistry-3.0")
local DBOptions = LibStub("AceDBOptions-3.0")
local APP = "Ranoth-s-Cooldown-Manager"
local groups = {
    { "Layout", 10, true }, { "BuffBars", 20 }, { "IconLayout", 30 },
    { "CustomTrackers", 35, true }, { "Skin", 40 }, { "Glow", 42 },
    { "Bars", 45 }, { "ResourceSkin", 50 },
}
local cached = {}
local initialized = false

function Options:Build()
    local root = {
        type = "group", name = "Ranoth's Cooldown Manager", childGroups = "tree",
        args = {
            general = {
                type = "group", name = "General", order = 1,
                args = {
                    debug = {
                        type = "toggle", name = "Debug mode",
                        desc = "Print extra diagnostic messages.", order = 1,
                        get = function() return Debug:IsEnabled() end,
                        set = function(_, value)
                            if value ~= Debug:IsEnabled() then Debug:Toggle() end
                        end,
                    },
                },
            },
        },
    }
    for _, entry in ipairs(groups) do
        local name, order, dynamic = unpack(entry)
        local group = cached[name]
        if not group or dynamic then
            group = Addon:GetModule(name):GetOptions()
            if type(group) == "function" then group = group() end
            if not dynamic then cached[name] = group end
        end
        group.order = group.order or order
        root.args[name] = group
    end
    local profiles = DBOptions:GetOptionsTable(Addon.db)
    profiles.order = 100
    root.args.profiles = profiles
    return root
end

function Options:InitializeUI()
    if initialized then return end
    AceConfig:RegisterOptionsTable(APP, function() return self:Build() end)
    Dialog:SetDefaultSize(APP, 780, 560)
    initialized = true
end

function Options:RefreshUI()
    if initialized then Registry:NotifyChange(APP) end
end

function Options:OpenUI() Dialog:Open(APP) end
function Options:CloseUI() Dialog:Close(APP) end
function Options:IsUIOpen() return Dialog.OpenFrames[APP] ~= nil end
