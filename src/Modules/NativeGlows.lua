--- Square, customizable replacements for Blizzard's cooldown-icon effects:
--- pandemic glow, Cooldown Manager visual alerts (marching ants / flash), ready flash and debuff border.
--- Each replacement is a child of the Blizzard frame it replaces, so Blizzard alone decides when it is visible.
--- Pandemic frames and alerts use AnimateWhileShownTemplate, which plays and stops the animation groups of every
--- descendant, so replacements never own animation groups: pulses are computed from the clock instead.
--- The ready flash follows the cooldown itself, because Blizzard suppresses its own flash while the GCD hides it.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:NewModule("NativeGlows", "AceEvent-3.0")
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
local Glow = Addon:GetModule("Glow")
local KEYS = { "Essential", "Utility", "BuffIcon" }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local UPDATE_INTERVAL = 1 / 30

local function viewerDefaults()
    return {
        pandemic = { custom = true, color = { r = 1, g = 0.42, b = 0.1, a = 1 }, thickness = 2, pulse = true, speed = 0.6 },
        alerts = {
            custom = false, useAlertColor = true, color = { r = 1, g = 0.82, b = 0, a = 1 },
            thickness = 2, length = 10, speed = 0.5,
        },
        flash = { custom = false, color = { r = 1, g = 1, b = 1, a = 1 }, thickness = 2, duration = 0.75 },
        debuff = { custom = false, thickness = 2 },
    }
end

local defaults = { profile = { Essential = viewerDefaults(), Utility = viewerDefaults(), BuffIcon = viewerDefaults() } }

local function weak() return setmetatable({}, { __mode = "k" }) end
local owners = weak() -- item -> viewer key
local hooked = weak()
local edges = weak() -- Blizzard effect frame (or item, for the ready flash) -> our square edge
local dashes = weak() -- marching-ants alert -> our pixel dashes
local pandemicStyled = weak() -- pandemic frame -> { item, revision, level }
local alertItems = weak() -- alert -> item it is styled for
local iconSizes = weak() -- item -> { width, height } read out of combat
local readyDurations = weak() -- item -> duration object of the tracked cooldown
local revision = 0

-- Tracing ------------------------------------------------------------------------------------

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

-- Shared -------------------------------------------------------------------------------------

local function settings(item, effect)
    local key = owners[item]
    return key and NativeGlows:IsEnabled() and NativeGlows.db.profile[key][effect], key
end

--- Four solid lines inside the icon border.
local function edge(parent)
    local frame = edges[parent]
    if frame then return frame end
    frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    frame.lines = {}
    for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetTexture(WHITE)
        line:SetPoint(points[1])
        line:SetPoint(points[2])
        line.horizontal = i <= 2
        frame.lines[i] = line
    end
    edges[parent] = frame
    return frame
end

local function styleEdge(frame, item, key, color, thickness, level)
    local icon = item.Icon or item
    local inset = Skin.db.profile[key].borderSize
    local alpha = color.a or 1
    local previous = frame.edgeStyle
    if not previous or previous.icon ~= icon or previous.inset ~= inset then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
        frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
    end
    if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
    if not previous or previous.r ~= color.r or previous.g ~= color.g or previous.b ~= color.b
        or previous.a ~= alpha or previous.thickness ~= thickness then
        for _, line in ipairs(frame.lines) do
            line:SetVertexColor(color.r, color.g, color.b, alpha)
            if line.horizontal then line:SetHeight(thickness) else line:SetWidth(thickness) end
        end
    end
    frame.edgeStyle = { icon = icon, inset = inset, r = color.r, g = color.g, b = color.b, a = alpha, thickness = thickness }
end

--- Bounces between two alphas on the shared clock: showing again (or Blizzard re-acquiring its pooled frame)
--- continues the pulse instead of restarting it. OnUpdate only runs while the edge is visible.
local function updatePulse(frame, elapsed)
    frame.pulseElapsed = frame.pulseElapsed + elapsed
    if frame.pulseElapsed < UPDATE_INTERVAL then return end
    frame.pulseElapsed = 0
    local pulse = frame.pulse
    local progress = (GetTime() % (2 * pulse.duration)) / pulse.duration
    if progress > 1 then progress = 2 - progress end
    progress = progress * progress * (3 - 2 * progress)
    frame:SetAlpha(pulse.from + (pulse.to - pulse.from) * progress)
end

local function setPulse(frame, from, to, duration)
    if from then
        frame.pulse = { from = from, to = to, duration = duration }
        frame.pulseElapsed = UPDATE_INTERVAL
        frame:SetScript("OnUpdate", updatePulse)
        updatePulse(frame, 0)
    else
        frame.pulse = nil
        frame:SetScript("OnUpdate", nil)
        frame:SetAlpha(1)
    end
end

-- Pandemic -------------------------------------------------------------------------------------

local raiseReady -- Defined with the ready flash, which draws above the pandemic glow.

--- Blizzard calls ShowPandemicStateFrame every frame during pandemic time; only a pooled frame newly acquired for
--- this item, a level change by Skin, or a settings change restyles it.
local function stylePandemic(item)
    local frame = item.PandemicIcon
    if not frame then return end
    local level = frame:GetFrameLevel()
    local done = pandemicStyled[frame]
    if done and done.item == item and done.revision == revision and done.level == level then return end
    pandemicStyled[frame] = { item = item, revision = revision, level = level }
    local s, key = settings(item, "pandemic")
    local custom = s and s.custom
    traceEvent(item, "pandemic", "style", custom and "custom" or "native")
    if custom then
        local square = edge(frame)
        styleEdge(square, item, key, s.color, s.thickness, level + 1)
        setPulse(square, s.pulse and 1, 0.35, s.speed)
        square:Show()
    elseif edges[frame] then
        setPulse(edges[frame])
        edges[frame]:Hide()
    end
    if frame.Border then frame.Border:SetShown(not custom) end
    if frame.FX then frame.FX:SetShown(not custom) end
    raiseReady(item)
end

-- Visual alerts ------------------------------------------------------------------------------

local function alertColor(alert, s)
    if s.useAlertColor and alert.GetVertexColor then
        local color = alert:GetVertexColor()
        if color and color.GetRGBA then
            local r, g, b, a = color:GetRGBA()
            return { r = r, g = g, b = b, a = a }
        end
    end
    return s.color
end

local function restoreAlert(alert)
    alertItems[alert] = nil
    if dashes[alert] then Glow.StopDashes(dashes[alert]) end
    if edges[alert] then
        setPulse(edges[alert])
        edges[alert]:Hide()
    end
    local native = alert.Flipbook or alert.Glow
    if native then native:Show() end
end

local function styleAlert(item, alert)
    local s, key = settings(item, "alerts")
    if not s or not s.custom then
        if alertItems[alert] then restoreAlert(alert) end
        return
    end
    alertItems[alert] = item
    local native = alert.Flipbook or alert.Glow
    local level = alert:GetFrameLevel() + 1
    local drawn
    if alert.Flipbook then
        local frame = dashes[alert]
        if not frame then
            frame = Glow.CreateDashes(alert, item.Icon or item, level)
            dashes[alert] = frame
        end
        frame:ClearAllPoints()
        frame:SetAllPoints(item.Icon or item)
        frame:SetFrameLevel(level)
        local size = iconSizes[item]
        if size then frame.readableWidth, frame.readableHeight = size[1], size[2] end
        drawn = Glow.StartDashes(frame, s, key, alertColor(alert, s))
    else
        local square = edge(alert)
        styleEdge(square, item, key, alertColor(alert, s), s.thickness, level)
        if not square.pulse then setPulse(square, 0.25, 1, 0.5) end
        square:Show()
        drawn = true
    end
    -- Keep Blizzard's art while our dashes have no readable geometry yet.
    if native then native:SetShown(not drawn) end
end

--- AddAlert and RemoveAlert both re-sort through UpdateAlerts; a removed alert is no longer in the container.
local function styleAlerts(item)
    local current = {}
    for _, alert in ipairs(item.alertContainer or {}) do
        current[alert] = true
        styleAlert(item, alert)
    end
    for alert, owner in pairs(alertItems) do
        if owner == item and not current[alert] then restoreAlert(alert) end
    end
end

-- Ready flash --------------------------------------------------------------------------------

local READY_PIECES_PER_EDGE = 16
local READY_LINE_LENGTH = 1 / 8 -- Fraction of the perimeter occupied by each moving line.

local function readyCurve(duration, midpoint)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    -- Gate fixed pieces instead of calculating positions from potentially secret remaining time.
    -- Each piece is paired with the one half a perimeter away; each line travels half the perimeter.
    local epsilon = 0.00001
    curve:AddPoint(0, 0)
    for lap = 1, 0, -1 do
        local first = math.max(0, (1 - 2 * midpoint - lap) * duration)
        local last = math.min(duration, (1 - 2 * midpoint + 2 * READY_LINE_LENGTH - lap) * duration)
        if last > first then
            if first > 0 then curve:AddPoint(first, 0) end
            curve:AddPoint(first + epsilon, 1)
            curve:AddPoint(last, 1)
            curve:AddPoint(last + epsilon, 0)
        end
    end
    curve:AddPoint(86400, 0)
    return curve
end

local function styleReady(item, s, key)
    local size = iconSizes[item]
    if not size then return false end
    local inset = Skin.db.profile[key].borderSize
    local width, height = size[1] - 2 * inset, size[2] - 2 * inset
    if width <= 0 or height <= 0 then return false end
    local thickness = math.min(s.thickness, width, height)
    local pathWidth, pathHeight = width - thickness, height - thickness
    local perimeter = 2 * (pathWidth + pathHeight)
    if pathWidth <= 0 or pathHeight <= 0 then return false end
    local square = edges[item]
    if not square then
        square = CreateFrame("Frame", nil, item)
        square:EnableMouse(false)
        square.item, square.readyEdge = item, true
        square.readyElapsed = 0
        square.lines, square.pieces = {}, {}
        for i = 1, 2 * READY_PIECES_PER_EDGE do
            local piece = {}
            for side = 1, 2 do
                local line = square:CreateTexture(nil, "OVERLAY")
                line:SetTexture(WHITE)
                piece[side] = line
                square.lines[#square.lines + 1] = line
            end
            square.pieces[i] = piece
        end
        square:Hide()
        edges[item] = square
    end
    square:ClearAllPoints()
    square:SetAllPoints(item.Icon or item)
    square:SetAlpha(1)
    local previous = square.readyStyle
    local changed = not previous or previous.width ~= width or previous.height ~= height
        or previous.thickness ~= thickness or previous.duration ~= s.duration
    for i, piece in ipairs(square.pieces) do
        local horizontal = i <= READY_PIECES_PER_EDGE
        local index = (i - 1) % READY_PIECES_PER_EDGE
        local length = (horizontal and pathWidth or pathHeight) / READY_PIECES_PER_EDGE
        local midpoint = (index + 0.5) * length
        if changed then
            piece.curve = readyCurve(s.duration, (horizontal and midpoint or pathWidth + midpoint) / perimeter)
        end
        for side, line in ipairs(piece) do
            local x = horizontal and midpoint or pathWidth
            local y = horizontal and 0 or midpoint
            if side == 2 then x, y = pathWidth - x, pathHeight - y end
            line:ClearAllPoints()
            line:SetPoint("CENTER", square, "TOPLEFT", inset + thickness / 2 + x, -inset - thickness / 2 - y)
            line:SetSize(horizontal and length + thickness or thickness,
                horizontal and thickness or length + thickness)
            line:SetVertexColor(s.color.r, s.color.g, s.color.b, s.color.a)
        end
    end
    square.readyStyle = { width = width, height = height, thickness = thickness, duration = s.duration }
    raiseReady(item)
    return true
end

local function active(duration)
    if not duration then return false end
    local zero = duration:IsZero()
    return issecretvalue(zero) or not zero
end

--- Equipped items (trinkets) cool down as items, like Blizzard displays them: their on-use spell only carries the
--- short lockout shared by on-use items.
--- @return table|nil duration, boolean busy, boolean handled
local function itemCooldown(item)
    local slot = item.GetEquipSlot and item:GetEquipSlot()
    if not slot or issecretvalue(slot) then return nil, false, false end
    local start, length, enable, gcd = GetInventoryItemCooldown("player", slot)
    if issecretvalue(start) or issecretvalue(length) or issecretvalue(enable) or issecretvalue(gcd) then
        return nil, true, true -- Unreadable: keep whatever is tracked rather than guess.
    end
    if not start or not length or length <= 0 or start + length <= GetTime() or (enable ~= 1 and enable ~= true) then
        return nil, false, true
    end
    if gcd then return nil, true, true end
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(start, length)
    return duration, true, true
end

--- The real cooldown (ignoring the GCD) as a duration object, which only the engine evaluates since its values may
--- be secret; and whether the spell is still busy (cooldown or GCD), in which case a tracked pulse is kept: the API
--- reports no cooldown at all while the GCD outlasts the remaining one.
local function readyCooldown(item)
    local duration, busy, handled = itemCooldown(item)
    if handled then return duration, busy end
    local spellID = item.GetSpellID and item:GetSpellID()
    if not issecretvalue(spellID) and not spellID then return nil, false end
    local charges = item.HasVisualDataSource_Charges and item:HasVisualDataSource_Charges()
    if issecretvalue(charges) or not charges then
        duration = C_Spell.GetSpellCooldownDuration(spellID, true)
    else
        duration = C_Spell.GetSpellChargeDuration(spellID)
    end
    if active(duration) then return duration, true end
    return nil, active(C_Spell.GetSpellCooldownDuration(spellID, false))
end

local function readyLevel(item)
    local level = item:GetFrameLevel()
    if item.CooldownFlash then level = math.max(level, item.CooldownFlash:GetFrameLevel()) end
    -- The pandemic edge sits one level above Blizzard's pandemic frame.
    if item.PandemicIcon then level = math.max(level, item.PandemicIcon:GetFrameLevel() + 1) end
    return level + 1
end

function raiseReady(item)
    local square = edges[item]
    if square and square.readyEdge then
        local level = readyLevel(item)
        if square:GetFrameLevel() ~= level then square:SetFrameLevel(level) end
    end
end

local stopReady

local function updateReady(square, elapsed)
    square.readyElapsed = square.readyElapsed + elapsed
    if square.readyElapsed < UPDATE_INTERVAL then return end
    square.readyElapsed = 0
    local duration = readyDurations[square.item]
    if not duration then return end
    if not duration:HasSecretValues() and duration:HasExpired() then
        stopReady(square.item)
        return
    end
    for _, piece in ipairs(square.pieces) do
        local alpha = duration:EvaluateRemainingDuration(piece.curve)
        piece[1]:SetAlpha(alpha)
        piece[2]:SetAlpha(alpha)
    end
end

function stopReady(item)
    local square = edges[item]
    if readyDurations[item] then traceEvent(item, "ready", "stop") end
    readyDurations[item] = nil
    if square and square.readyEdge then
        square:SetScript("OnUpdate", nil)
        square:Hide()
    end
end

--- Runs whenever Blizzard refreshes the item's cooldown (casts, GCD start/end, procs, aura changes).
local function refreshReady(item)
    local s = settings(item, "flash")
    local square = edges[item]
    if not s or not s.custom or not square or not square.readyAvailable then return end
    local duration, busy = readyCooldown(item)
    if duration then
        if not readyDurations[item] then traceEvent(item, "ready", "track") end
        readyDurations[item] = duration:Copy()
        raiseReady(item)
        square.readyElapsed = UPDATE_INTERVAL
        updateReady(square, 0)
        if readyDurations[item] then
            square:SetScript("OnUpdate", updateReady)
            square:Show()
        end
    elseif readyDurations[item] then
        if busy then traceEvent(item, "ready", "keep") else stopReady(item) end
    end
end

local function styleFlash(item)
    local flash = item.CooldownFlash
    if not flash or not flash.Flipbook then return end
    local s, key = settings(item, "flash")
    local custom = s and s.custom and styleReady(item, s, key)
    if edges[item] then edges[item].readyAvailable = custom end
    if custom then
        local square = edges[item]
        if not readyDurations[item] then square:Hide() end
        refreshReady(item)
    elseif edges[item] then
        stopReady(item)
    end
    flash.Flipbook:SetShown(not custom)
end

-- Debuff border ------------------------------------------------------------------------------

local function dispelColor(auraData)
    local name = auraData and auraData.dispelName
    if name ~= nil and issecretvalue(name) then name = nil end
    local color = AuraUtil and AuraUtil.GetAuraBorderColor and AuraUtil.GetAuraBorderColor(name)
    if color and color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        return { r = r, g = g, b = b, a = a }
    end
    return { r = 0.8, g = 0, b = 0, a = 1 }
end

--- Blizzard shows the border frame while an aura is displayed and its texture only for harmful auras.
local function styleDebuff(item, auraData)
    local border = item.DebuffBorder
    local texture = border and border.Texture
    if not texture then return end
    local s, key = settings(item, "debuff")
    local custom = s and s.custom
    texture:SetAlpha(custom and 0 or 1)
    local square = edges[border]
    if custom then
        square = edge(border)
        if auraData then square.color = dispelColor(auraData) end
        styleEdge(square, item, key, square.color or dispelColor(nil), s.thickness, border:GetFrameLevel() + 1)
        square:SetShown(texture:IsShown())
    elseif square then
        square:Hide()
    end
end

-- Wiring -------------------------------------------------------------------------------------

local function hook(item)
    if hooked[item] then return end
    hooked[item] = true
    if item.ShowPandemicStateFrame then hooksecurefunc(item, "ShowPandemicStateFrame", stylePandemic) end
    if item.UpdateAlerts then hooksecurefunc(item, "UpdateAlerts", styleAlerts) end
    if item.CooldownFlash then
        if item.RefreshSpellCooldownInfo then
            hooksecurefunc(item, "RefreshSpellCooldownInfo", refreshReady)
        elseif item.CooldownFlash.FlashAnim then
            hooksecurefunc(item.CooldownFlash.FlashAnim, "Stop", function() refreshReady(item) end)
        end
        local cooldown = item.GetCooldownFrame and item:GetCooldownFrame() or item.Cooldown
        if cooldown then cooldown:HookScript("OnCooldownDone", function() refreshReady(item) end) end
    end
    local border = item.DebuffBorder
    if border and border.Texture then
        if border.UpdateFromAuraData then
            hooksecurefunc(border, "UpdateFromAuraData", function(_, auraData) styleDebuff(item, auraData) end)
        end
        local function mirror()
            local square = edges[border]
            local s = settings(item, "debuff")
            if square and s and s.custom then square:SetShown(border.Texture:IsShown()) end
        end
        hooksecurefunc(border.Texture, "Show", mirror)
        hooksecurefunc(border.Texture, "Hide", mirror)
        hooksecurefunc(border.Texture, "SetShown", mirror)
    end
end

local function refreshItem(item)
    local icon = item.Icon or item
    local width, height = icon:GetWidth(), icon:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
        iconSizes[item] = { width, height }
    end
    stylePandemic(item)
    styleAlerts(item)
    styleFlash(item)
    styleDebuff(item)
end

function NativeGlows:OnViewerMessage(_, key)
    if not self.db.profile[key] then return end
    for _, item in ipairs(Viewers:GetItems(key)) do
        owners[item] = key
        hook(item)
        refreshItem(item)
    end
end

function NativeGlows:Refresh()
    revision = revision + 1
    for item in pairs(owners) do refreshItem(item) end
end

function NativeGlows:OnProfileRefresh()
    self:Refresh()
end
-- Options ------------------------------------------------------------------------------------

function NativeGlows:GetViewerOptions(key)
    local function s(effect) return self.db.profile[key][effect] end
    local function getter(effect, field) return function() return s(effect)[field] end end
    local function setter(effect, field)
        return function(_, value) s(effect)[field] = value; self:Refresh() end
    end
    local function off(effect) return function() return not s(effect).custom end end
    local function color(effect, order, name, disabled)
        return {
            type = "color", order = order, name = name, hasAlpha = true, disabled = disabled or off(effect),
            get = function() local c = s(effect).color; return c.r, c.g, c.b, c.a end,
            set = function(_, r, g, b, a) s(effect).color = { r = r, g = g, b = b, a = a }; self:Refresh() end,
        }
    end
    local function toggle(effect, order, name, desc)
        return { type = "toggle", order = order, name = name, desc = desc,
            get = getter(effect, "custom"), set = setter(effect, "custom") }
    end
    local function range(effect, field, order, name, min, max, step, disabled)
        return { type = "range", order = order, name = name, min = min, max = max, step = step,
            disabled = disabled or off(effect), get = getter(effect, field), set = setter(effect, field) }
    end

    local args = {
        pandemic = {
            type = "group", inline = true, order = 2, name = "Pandemic glow",
            args = {
                custom = toggle("pandemic", 1, "Custom pandemic glow",
                    "Replace Blizzard's rounded pandemic ring with a square edge inside the icon border."),
                color = color("pandemic", 2, "Color"),
                thickness = range("pandemic", "thickness", 3, "Thickness", 1, 5, 1),
                pulse = { type = "toggle", order = 4, name = "Pulse", disabled = off("pandemic"),
                    get = getter("pandemic", "pulse"), set = setter("pandemic", "pulse") },
                speed = range("pandemic", "speed", 5, "Pulse duration", 0.2, 2, 0.1,
                    function() return not s("pandemic").custom or not s("pandemic").pulse end),
            },
        },
        alerts = {
            type = "group", inline = true, order = 3, name = "Visual alerts",
            args = {
                description = { type = "description", order = 0,
                    name = "Marching ants and flash alerts set in Blizzard's Cooldown Manager alert settings." },
                custom = toggle("alerts", 1, "Custom visual alerts",
                    "Marching ants become moving pixel lines; flashes become a pulsing square edge."),
                useAlertColor = { type = "toggle", order = 2, name = "Use alert color",
                    desc = "Use the color chosen for the alert in Blizzard's settings.", disabled = off("alerts"),
                    get = getter("alerts", "useAlertColor"), set = setter("alerts", "useAlertColor") },
                color = color("alerts", 3, "Color",
                    function() return not s("alerts").custom or s("alerts").useAlertColor end),
                thickness = range("alerts", "thickness", 4, "Thickness", 1, 5, 1),
                length = range("alerts", "length", 5, "Ant length", 2, 20, 1),
                speed = range("alerts", "speed", 6, "Ant speed", 0.05, 1, 0.05),
            },
        },
        debuff = {
            type = "group", inline = true, order = 5, name = "Debuff border",
            args = {
                custom = toggle("debuff", 1, "Custom debuff border",
                    "Replace Blizzard's debuff border with a square edge in the debuff type's color."),
                thickness = range("debuff", "thickness", 2, "Thickness", 1, 5, 1),
            },
        },
    }
    if key ~= "BuffIcon" then
        args.flash = {
            type = "group", inline = true, order = 4, name = "Ready flash",
            args = {
                custom = toggle("flash", 1, "Custom ready flash",
                    "Two lines start at opposite corners and each travel clockwise halfway around the icon before the cooldown ends."),
                color = color("flash", 2, "Color"),
                thickness = range("flash", "thickness", 3, "Thickness", 1, 5, 1),
                duration = range("flash", "duration", 4, "Animation duration", 0.2, 2, 0.05),
            },
        }
    end
    return args
end

function NativeGlows:OnInitialize()
    self.db = Addon.db:RegisterNamespace("NativeGlows", defaults)
end

function NativeGlows:OnEnable()
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    -- Border size changes move every replacement; incremental layout passes leave settings untouched.
    hooksecurefunc(Skin, "Apply", function(_, _, incremental)
        if not incremental then NativeGlows:Refresh() end
    end)
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function NativeGlows:OnDisable()
    self:Refresh()
end