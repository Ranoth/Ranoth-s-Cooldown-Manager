--- Debug module for CODE_NAME.
--- @module "Debug"

local addon_name, _ = ...
local CODE_NAME = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Debug = CODE_NAME:NewModule("Debug")

local Printer = CODE_NAME:GetModule("Printer")

--- Higher order function to neutralize each public function of the module when debug mode is disabled.
--- @param func any
--- @return function
--- @usage `Debug.Print = createToggledFunction(function(self, ...)`
local function createToggledFunction(func)
    return function(...)
        if not Debug:IsEnabled() then return end
        return func(unpack({ ... }))
    end
end

--- Toggle debug mode on or off.
function Debug:Toggle()
    if Debug:IsEnabled() then
        Debug:Disable()
    else
        Debug:Enable()
    end
    Printer:Print(Debug:IsEnabled() and "Debug mode enabled" or "Debug mode disabled")
end

--- Print arguments.
--- @param arg1 string
--- @param arg2 string
--- @usage `Debug:ExampleFunction("UNIT_NAME_UPDATE", "player")`
Debug.ExampleFunction = createToggledFunction(function(self, arg1, arg2)
    Printer.Print(arg1, arg2)
end)

function Debug:OnInitialize()
    self.db = CODE_NAME.db.profile.debug
    if self.db then
        self:Enable()
    else
        self:Disable()
    end
end

function Debug:OnEnable()
    CODE_NAME.db.profile.debug = Debug:IsEnabled()
end

function Debug:OnDisable()
    CODE_NAME.db.profile.debug = Debug:IsEnabled()
end
