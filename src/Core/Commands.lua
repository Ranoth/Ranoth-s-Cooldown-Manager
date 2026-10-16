--- Registers additional slash commands for the addon and some utility without strings attached.
--- @module "Commands"
local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Commands = RanothsCooldownManager:NewModule("Commands")

local Printer = RanothsCooldownManager:GetModule("Printer")
local Debug = RanothsCooldownManager:GetModule("Debug")

local addonShortHand = "rcm"

--- Colors pink the addon shorthand for display in the help text
local function colorizeShortHand(shortHand)
    return "|cffffff00" .. shortHand .. "|r"
end

--- Colors green the argument help text for display in the help message
local function colorizeArgHelp(argsHelp)
    return "|cff00ff00" .. argsHelp .. "|r"
end

--- Displays the core configuration options for the addon
local function DisplayCoreConfig()
    Printer:Print("Core options for the addon")
end

--- @type table<string, table>
local commandList = {
    [""] = {
        func = function()
            DisplayCoreConfig()
        end,
        help = "Prints this message"
    },
    ["config"] = {
        func = function()
            DisplayCoreConfig()
        end,
        help = "Displays core configuration options"
    },
    ["help"] = {
        func = function()
            Commands:PrintHelp()
        end,
        help = "Prints this message"
    },
    ["debug"] = {
        func = Debug.Toggle,
        help = "Toggles debug mode"
    },
    ["resources"] = {
        func = function()
            RanothsCooldownManager:GetModule("Resources"):Describe()
        end,
        help = "Shows which Blizzard resource frames were found"
    },
    ["examplewithargs"] = {
        func = function(args)
            Printer:Print("Example command with args: " .. args)
        end,
        help = "Example command with arguments",
        argsHelp = "<exampleArgUsage>"
    }
}

--- prints the help message for the addon's slash commands
function Commands:PrintHelp()
    Printer:Print("Available commands")
    for command, info in pairs(commandList) do
        local argText = info.argsHelp and " " .. colorizeArgHelp(info.argsHelp) or ""
        Printer:Print(colorizeShortHand(addonShortHand) .. " " .. command .. argText .. " - " .. info.help)
    end
end

--- Registers additional slash commands for the addon
RanothsCooldownManager:RegisterChatCommand(addonShortHand, function(input)
    local command, args = input:match("^(%S*)%s*(.-)$") -- match the first word as command then the rest of the input as a string of arguments

    local commandInfo = commandList[command]
    if commandInfo and commandInfo.func then
        commandInfo.func(args)
    else
        Printer:Print("Unknown or invalid command " .. command)
        Commands:PrintHelp()
    end
end)
