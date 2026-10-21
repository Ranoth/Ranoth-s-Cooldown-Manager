--- Registers additional slash commands for the addon and some utility without strings attached.
--- @module "Commands"
local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Commands = RanothsCooldownManager:NewModule("Commands")

local Printer = RanothsCooldownManager:GetModule("Printer")
local Debug = RanothsCooldownManager:GetModule("Debug")
local Options = RanothsCooldownManager:GetModule("Options")

local addonShortHand = "rcm"

--- Colors pink the addon shorthand for display in the help text
local function colorizeShortHand(shortHand)
    return "|cffffff00" .. shortHand .. "|r"
end

--- Colors green the argument help text for display in the help message
local function colorizeArgHelp(argsHelp)
    return "|cff00ff00" .. argsHelp .. "|r"
end

--- Opens or closes the settings window
local function DisplayCoreConfig()
    Options:Toggle()
end

--- @type table<string, table>
local commandList = {
    [""] = {
        func = function()
            DisplayCoreConfig()
        end,
        help = "Opens the settings window"
    },
    ["config"] = {
        func = function()
            DisplayCoreConfig()
        end,
        help = "Opens the settings window"
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
    ["glowtrace"] = {
        func = function(args)
            RanothsCooldownManager:GetModule("NativeGlows"):TraceCommand(args:lower())
        end,
        help = "Captures the last 100 glow lifecycle events for troubleshooting",
        argsHelp = "[start|stop]"
    },
    ["resources"] = {
        func = function()
            RanothsCooldownManager:GetModule("Resources"):Describe()
        end,
        help = "Shows which Blizzard resource frames were found"
    },
    ["stack"] = {
        func = function(args)
            local Layout = RanothsCooldownManager:GetModule("Layout")
            local name, position = args:match("^(%S+)%s+(%d+)$")
            if not name then
                Layout:Describe()
                return
            end
            local key = Layout:ResolveKey(name)
            if key and Layout:SetPosition(key, tonumber(position)) then
                Layout:Describe()
            else
                Printer:Print("Unknown stack entry " .. name)
            end
        end,
        help = "Shows the layout stack, or moves an entry to a position",
        argsHelp = "[<entry> <position>]"
    },
    ["layoutdebug"] = {
        func = function()
            RanothsCooldownManager:GetModule("Layout"):ToggleDebug()
        end,
        help = "Toggles colored overlays on the layout slots"
    },
    ["buffbars"] = {
        func = function(args)
            local BuffBars = RanothsCooldownManager:GetModule("BuffBars")
            local arg = args:lower()
            if arg == "on" or arg == "off" then
                BuffBars:SetCompact(arg == "on")
            elseif arg == "up" or arg == "down" then
                BuffBars.db.profile.growth = arg:upper()
                BuffBars:Apply()
            end
            local profile = BuffBars.db.profile
            Printer:Print("Compact buff bars: " .. (profile.compact and "on" or "off") .. ", growth " .. profile.growth)
        end,
        help = "Packs active buff bars together without gaps",
        argsHelp = "[on|off|up|down]"
    },
    ["icons"] = {
        func = function(args)
            local IconLayout = RanothsCooldownManager:GetModule("IconLayout")
            local name, option, value = args:match("^(%S+)%s+(%S+)%s+(%S+)$")
            local key
            for _, k in ipairs(IconLayout.KEYS) do
                if name and k:lower() == name:lower() then key = k end
            end
            if key and (option == "center" or option == "compact") and (value == "on" or value == "off") then
                IconLayout:SetOption(key, option, value == "on")
                Printer:Print(IconLayout:Describe(key))
            else
                for _, k in ipairs(IconLayout.KEYS) do
                    Printer:Print(IconLayout:Describe(k))
                end
            end
        end,
        help = "Centers or compacts icons in the Utility and BuffIcon viewers",
        argsHelp = "[<viewer> <center|compact> <on|off>]"
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
