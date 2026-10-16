--- Printer module for CODE_NAME.
--- @module "Printer"

local addon_name, _ = ...
local CODE_NAME = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Printer = CODE_NAME:NewModule("Printer")

local colorizedAddonName = "|cffc66ff0" .. addon_name .. "|r"

--- @name Print
--- Print a message to the chat frame with the colorized addon's name prepended.
--- @param ... any | string | table
--- @usage Printer:Print("Hello, world!")
function Printer:Print(...)
    local args = { ... }
    for i = 1, #args do
        args[i] = tostring(args[i])
    end
    print(colorizedAddonName .. ": " .. table.concat(args, " "))
end