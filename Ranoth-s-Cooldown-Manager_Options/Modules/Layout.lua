local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon("Ranoth-s-Cooldown-Manager")
local Addon = RanothsCooldownManager
local Layout = Addon:GetModule("Layout")
local Options = Addon:GetModule("Options")
local Viewers = Addon:GetModule("Viewers")
local function isViewerKey(key) return Viewers.FRAME_NAMES[key] ~= nil end

local STACK_LABELS = {
    CastBar = "Cast bar",
    ClassPower = "Class power",
    Mana = "Mana bar",
    Essential = "Essential cooldowns",
    Utility = "Utility cooldowns",
    BuffIcon = "Buff icons",
}

--- Options group for the settings window. Returned as a function so the stack order is rebuilt on every refresh.
--- @return function
function Layout:GetOptions()
    return function()
        local function profile() return self.db.profile end

        local anchorValues = {}
        for key in pairs(STACK_LABELS) do
            if isViewerKey(key) then anchorValues[key] = STACK_LABELS[key] end
        end

        local args = {
            description = {
                type = "description",
                order = 1,
                name = "Stacks the resource bars and cooldown viewers vertically. The anchor viewer stays where "
                    .. "Edit Mode puts it, and the other entries are placed above or below it in the order below.",
            },
            anchorKey = {
                type = "select",
                order = 2,
                name = "Anchor viewer",
                desc = "The viewer you position with Edit Mode. Entries above it in the list go above, entries below it go below.",
                values = anchorValues,
                get = function() return profile().anchorKey end,
                set = function(_, value)
                    profile().anchorKey = value
                    profile().stack[value].enabled = true
                    self:Request()
                    Options:Refresh()
                end,
            },
            spacing = {
                type = "range",
                order = 3,
                name = "Spacing",
                desc = "Gap between stacked entries.",
                min = 0, max = 20, step = 1,
                get = function() return profile().spacing end,
                set = function(_, value)
                    profile().spacing = value
                    self:Request()
                end,
            },
            strata = {
                type = "select",
                order = 3.5,
                name = "Frame strata",
                desc = "Drawing layer for the managed viewers and resource bars. LOW keeps them below MEDIUM-layer UI such as Dragon Rider. Changes wait until combat ends.",
                values = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High" },
                sorting = { "BACKGROUND", "LOW", "MEDIUM", "HIGH" },
                get = function() return profile().strata end,
                set = function(_, value)
                    profile().strata = value
                    self:Request()
                end,
            },
            widthMode = {
                type = "select",
                order = 4,
                name = "Bar width",
                values = { anchor = "Match anchor viewer", fixed = "Fixed width" },
                get = function() return profile().width.mode end,
                set = function(_, value)
                    profile().width.mode = value
                    self:Request()
                end,
            },
            widthValue = {
                type = "range",
                order = 5,
                name = "Fixed width",
                min = 50, max = 800, step = 1,
                hidden = function() return profile().width.mode ~= "fixed" end,
                get = function() return profile().width.value end,
                set = function(_, value)
                    profile().width.value = value
                    self:Request()
                end,
            },
            overlay = {
                type = "execute",
                order = 6,
                name = "Toggle slot overlay",
                desc = "Shows colored, labelled boxes on each slot of the stack.",
                func = function() self:ToggleDebug() end,
            },
            stackHeader = {
                type = "header",
                order = 10,
                name = "Stack order (top to bottom)",
            },
        }

        local ordered = self:GetOrderedKeys(true)
        for i, key in ipairs(ordered) do
            local isViewer = isViewerKey(key)
            local label = i .. ". " .. STACK_LABELS[key] .. (key == profile().anchorKey and " (anchor)" or "")
            args["entry_" .. key] = {
                type = "group",
                inline = true,
                order = 10 + i,
                name = label,
                args = {
                    enabled = {
                        type = "toggle",
                        order = 1,
                        name = "Enabled",
                        disabled = key == profile().anchorKey,
                        get = function() return profile().stack[key].enabled end,
                        set = function(_, value)
                            profile().stack[key].enabled = value
                            self:Request()
                        end,
                    },
                    up = {
                        type = "execute",
                        order = 2,
                        name = "Up",
                        width = "half",
                        disabled = i == 1,
                        func = function() self:SetPosition(key, i - 1) end,
                    },
                    down = {
                        type = "execute",
                        order = 3,
                        name = "Down",
                        width = "half",
                        disabled = i == #ordered,
                        func = function() self:SetPosition(key, i + 1) end,
                    },
                    height = {
                        type = "range",
                        order = 4,
                        name = "Height",
                        min = 4, max = 60, step = 1,
                        hidden = isViewer,
                        get = function() return profile().stack[key].height end,
                        set = function(_, value)
                            profile().stack[key].height = value
                            self:Request()
                        end,
                    },
                    collapse = {
                        type = "toggle",
                        order = 5,
                        name = "Collapse when hidden",
                        desc = "Take no space in the stack while this bar is not shown.",
                        hidden = isViewer,
                        get = function() return profile().stack[key].collapse end,
                        set = function(_, value)
                            profile().stack[key].collapse = value
                            self:Request()
                        end,
                    },
                },
            }
        end

        return { type = "group", name = "Layout", args = args }
    end
end
