--- Session-only, bounded native/proc glow diagnostics.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local weak = Internal.weak
local owners = Internal.owners
local trace
local traceIDs = weak()
local nextTraceID = 0
local TRACE_LIMIT = 100

local function traceEvent(item, effect, event, value)
    if not trace then return end
    local id = traceIDs[item]
    if not id then
        nextTraceID = nextTraceID + 1
        id = nextTraceID
        traceIDs[item] = id
    end
    local detail = ""
    if issecretvalue(value) then
        detail = " secret"
    elseif value ~= nil then
        detail = " " .. tostring(value)
    end
    if #trace.events == TRACE_LIMIT then table.remove(trace.events, 1) end
    trace.events[#trace.events + 1] = string.format("%.3f %s#%d %s %s%s",
        GetTime() - trace.start, owners[item] or "icon", id, effect, event, detail)
end

function NativeGlows:TracePixel(item, active)
    traceEvent(item, "pixel", active and "show" or "hide")
end

function NativeGlows:TraceCommand(arg)
    local Printer = Addon:GetModule("Printer")
    if arg == "start" then
        trace = { start = GetTime(), events = {} }
        Printer:Print("Glow tracing started. Reproduce the issue, then use /rcm glowtrace stop.")
    elseif arg == "stop" then
        if not trace then
            Printer:Print("Glow tracing is not running. Use /rcm glowtrace start first.")
            return
        end
        local events = trace.events
        trace = nil
        Printer:Print("Glow trace (last " .. #events .. " events):")
        for _, event in ipairs(events) do Printer:Print(event) end
    else
        Printer:Print("Use /rcm glowtrace start, reproduce the issue, then /rcm glowtrace stop.")
    end
end


Internal.TraceEvent = traceEvent
