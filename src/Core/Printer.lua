--- Printer module for RanothsCooldownManager.
--- @module "Printer"

local addon_name, _ = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Printer = RanothsCooldownManager:NewModule("Printer")

local colorizedAddonName = "|cffc66ff0" .. "Ranoth's Cooldown Manager" .. "|r"

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