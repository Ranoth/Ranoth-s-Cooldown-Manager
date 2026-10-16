--- Registers additional slash commands for the addon and some utility without strings attached.
--- @module "Commands"

local addon_name, _ = ...
local CODE_NAME = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Commands = CODE_NAME:NewModule("Commands")

local Printer = CODE_NAME:GetModule("Printer")
local Debug = CODE_NAME:GetModule("Debug")

local addonShortHand = string.lower(addon_name)

local function colorizeShortHand(shortHand)
    return "|cffffff00" .. shortHand .. "|r"
end

local function colorizeArgHelp(argsHelp)
    return "|cff00ff00" .. argsHelp .. "|r"
end

--- @type table<string, table>
local commandList = {
    ["help"] = {
        func = function() Commands:PrintHelp() end,
        help = "Prints this message"
    },
    ["debug"] = {
        func = Debug.Toggle,
        help = "Toggles debug mode"
    },
    ["examplewithargs"] = {
        func = function(args) Printer:Print("Example command with args: " .. args) end,
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
CODE_NAME:RegisterChatCommand(addonShortHand, function(input)
    local command, args = input:match("^(%S*)%s*(.-)$") -- match the first word as command then the rest of the input as a string of arguments

    local commandInfo = commandList[command]
    if commandInfo and commandInfo.func then
        commandInfo.func(args)
    else
        Printer:Print("Unknown or invalid command " .. command)
        Commands:PrintHelp()
    end
end)