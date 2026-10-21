--- Square, customizable replacements for Blizzard's remaining cooldown-icon effects:
--- pandemic glow, Cooldown Manager visual alerts (marching ants / flash), ready flash and debuff border.
--- Blizzard drives effect visibility and ready-flash timing.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:NewModule("NativeGlows", "AceEvent-3.0")
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
local Glow = Addon:GetModule("Glow")
local KEYS = { "Essential", "Utility", "BuffIcon" }
local WHITE = "Interface\\Buttons\\WHITE8X8"

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

local owners = setmetatable({}, { __mode = "k" }) -- item -> viewer key
local hooked = setmetatable({}, { __mode = "k" })
local edges = setmetatable({}, { __mode = "k" }) -- Blizzard effect frame -> our square edge
local dashes = setmetatable({}, { __mode = "k" }) -- marching-ants alert -> our pixel dashes
local pandemicStyled = setmetatable({}, { __mode = "k" }) -- pandemic frame -> { item, revision }
local debuffColors = setmetatable({}, { __mode = "k" }) -- item -> last dispel color
local iconSizes = setmetatable({}, { __mode = "k" }) -- item -> { width, height } read out of combat
local revision = 0
local trace
local traceIDs = setmetatable({}, { __mode = "k" })
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
        for item in pairs(owners) do
            local s = self.db.profile[owners[item]]
            traceEvent(item, "ready", "custom", s.flash.custom)
            traceEvent(item, "pandemic", "custom", s.pandemic.custom)
        end
        Printer:Print("Glow tracing started. Reproduce the flicker, then use /rcm glowtrace stop.")
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

local function traceEdge(frame, item, effect)
    frame.traceItem = item
    if frame.traceHooked then return end
    frame.traceHooked = true
    frame:HookScript("OnShow", function() traceEvent(frame.traceItem, effect, "edge-show") end)
    frame:HookScript("OnHide", function() traceEvent(frame.traceItem, effect, "edge-hide") end)
    hooksecurefunc(frame, "SetAlpha", function(_, alpha) traceEvent(frame.traceItem, effect, "edge-alpha", alpha) end)
    hooksecurefunc(frame.anim, "Play", function() traceEvent(frame.traceItem, effect, "pulse-play") end)
    if frame.anim.PlaySynced then
        hooksecurefunc(frame.anim, "PlaySynced", function() traceEvent(frame.traceItem, effect, "pulse-play-synced") end)
    end
    hooksecurefunc(frame.anim, "Stop", function() traceEvent(frame.traceItem, effect, "pulse-stop") end)
end

local function settings(item, effect)
    local key = owners[item]
    return key and NativeGlows:IsEnabled() and NativeGlows.db.profile[key][effect], key
end

--- Four solid lines inside the icon border, with an optional alpha animation.
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
    frame.anim = frame:CreateAnimationGroup()
    frame.alpha = frame.anim:CreateAnimation("Alpha")
    frame.alpha:SetSmoothing("IN_OUT")
    frame:SetScript("OnShow", function(f) if f.animated then f.anim:Play() end end)
    frame:SetScript("OnHide", function(f) f.anim:Stop() end)
    edges[parent] = frame
    return frame
end

--- @param animation table|nil { from, to, duration, looping }
local function styleEdge(frame, item, key, color, thickness, animation)
    local icon = item.Icon or item
    local inset = Skin.db.profile[key].borderSize
    local level = (frame.levelAnchor or frame:GetParent()):GetFrameLevel() + 1
    local previous = frame.edgeStyle
    local alpha = color.a or 1
    if not previous or previous.icon ~= icon or previous.inset ~= inset then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
        frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
    end
    if not previous or previous.level ~= level then frame:SetFrameLevel(level) end
    if not previous or previous.r ~= color.r or previous.g ~= color.g or previous.b ~= color.b
        or previous.a ~= alpha or previous.thickness ~= thickness then
        for _, line in ipairs(frame.lines) do
            line:SetVertexColor(color.r, color.g, color.b, alpha)
            if line.horizontal then line:SetHeight(thickness) else line:SetWidth(thickness) end
        end
    end
    local from = animation and animation.from
    local to = animation and animation.to
    local duration = animation and animation.duration
    local looping = animation and (animation.looping or "NONE")
    -- Geometry/color refreshes must not reset the phase of an active alpha animation.
    if not previous or previous.from ~= from or previous.to ~= to
        or previous.duration ~= duration or previous.looping ~= looping then
        if frame.animated then frame.anim:Stop() end
        frame.animated = animation ~= nil
        if animation then
            frame.anim:SetLooping(looping)
            frame.alpha:SetFromAlpha(from)
            frame.alpha:SetToAlpha(to)
            frame.alpha:SetDuration(duration)
            if frame:IsVisible() then frame.anim:Play() end
        end
    end
    frame.edgeStyle = {
        icon = icon, inset = inset, level = level, r = color.r, g = color.g, b = color.b,
        a = alpha, thickness = thickness, from = from, to = to, duration = duration, looping = looping,
    }
end

-- Pandemic -------------------------------------------------------------------------------------

--- Blizzard re-checks pandemic state every frame; restyle only a newly acquired frame or after a settings change.
local function stylePandemic(item)
    local frame = item.PandemicIcon
    if not frame then return end
    local done = pandemicStyled[frame]
    if done and done.item == item and done.revision == revision then return end
    pandemicStyled[frame] = { item = item, revision = revision }
    local s, key = settings(item, "pandemic")
    local custom = s and s.custom
    if custom then
        local square = edge(frame)
        traceEdge(square, item, "pandemic")
        styleEdge(square, item, key, s.color, s.thickness,
            s.pulse and { from = 1, to = 0.35, duration = s.speed, looping = "BOUNCE" } or nil)
        square:Show()
    elseif edges[frame] then
        edges[frame]:Hide()
    end
    if frame.Border then
        frame.Border:SetAlpha(1)
        frame.Border:SetShown(not custom)
    end
    if frame.FX then
        frame.FX:SetAlpha(1)
        frame.FX:SetShown(not custom)
        for _, anim in ipairs({ frame.FX:GetAnimationGroups() }) do
            if custom then anim:Stop() else anim:Play() end
        end
    end
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

local function styleAlert(item, alert)
    local s, key = settings(item, "alerts")
    local custom = s and s.custom
    local native = alert.Flipbook or alert.Glow
    local ants = alert.Flipbook ~= nil
    local drawn = false
    if custom and ants then
        local frame = dashes[alert]
        if not frame then
            frame = Glow.CreateDashes(alert, item.Icon or item, alert:GetFrameLevel() + 1)
            dashes[alert] = frame
        end
        frame:ClearAllPoints()
        frame:SetAllPoints(item.Icon or item)
        frame:SetFrameLevel(alert:GetFrameLevel() + 1)
        local size = iconSizes[item]
        if size then frame.readableWidth, frame.readableHeight = size[1], size[2] end
        drawn = Glow.StartDashes(frame, s, key, alertColor(alert, s))
    elseif dashes[alert] then
        Glow.StopDashes(dashes[alert])
    end
    if custom and not ants then
        local square = edge(alert)
        styleEdge(square, item, key, alertColor(alert, s), s.thickness,
            { from = 0.25, to = 1, duration = 0.5, looping = "BOUNCE" })
        square:Show()
        drawn = true
    elseif edges[alert] then
        edges[alert]:Hide()
    end
    -- Keep Blizzard's art when our dashes have no readable geometry yet.
    if native then native:SetShown(not drawn) end
end

local function styleAlerts(item)
    for _, alert in ipairs(item.alertContainer or {}) do styleAlert(item, alert) end
end

-- Ready flash --------------------------------------------------------------------------------

-- The custom edge reads the cooldown itself instead of Blizzard's flash timeline: Blizzard restarts that timeline
-- on every cooldown refresh (GCD, procs) and hides it while the spell reports the GCD.
local readyCurves = {} -- brighten duration -> curve of seconds remaining -> alpha
local readyDurations = setmetatable({}, { __mode = "k" }) -- item -> duration object of the tracked cooldown

local function readyCurve(duration)
    local curve = readyCurves[duration]
    if curve then return curve end
    curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    -- Invisible once ready, brightest just before, easing in over the configured duration.
    curve:AddPoint(0, 0)
    for step = 4, 0, -1 do
        local progress = step / 4
        curve:AddPoint(math.max(duration * (1 - progress), 0.01), progress * progress)
    end
    curve:AddPoint(86400, 0)
    readyCurves[duration] = curve
    return curve
end

--- Duration object for the cooldown Blizzard flashes on; values may be secret, so it is only evaluated by the engine.
local function readyCooldown(item)
    local spellID = item.GetSpellID and item:GetSpellID()
    if not issecretvalue(spellID) and not spellID then return end
    if not C_Spell or not C_Spell.GetSpellCooldownDuration then return end
    local charges = item.HasVisualDataSource_Charges and item:HasVisualDataSource_Charges()
    if not issecretvalue(charges) and charges and C_Spell.GetSpellChargeDuration then
        return C_Spell.GetSpellChargeDuration(spellID)
    end
    return C_Spell.GetSpellCooldownDuration(spellID, true)
end

local function updateReady(square, elapsed)
    if elapsed then
        square.readyElapsed = (square.readyElapsed or 0) + elapsed
        if square.readyElapsed < 1 / 30 then return end
        square.readyElapsed = 0
    end
    local duration, curve = readyDurations[square.item], square.curve
    if duration and curve then square:SetAlpha(duration:EvaluateRemainingDuration(curve)) end
end

local function stopReady(item)
    readyDurations[item] = nil
    local square = edges[item]
    if square and square.readyEdge then
        square:SetScript("OnUpdate", nil)
        square:Hide()
    end
end

--- Track the latest cooldown while Blizzard has a flash pending; refreshes keep the pulse phase intact.
local function trackReady(item, started)
    local s = settings(item, "flash")
    local square = edges[item]
    if not s or not s.custom or not square or not square.readyEdge then return end
    if not started and not readyDurations[item] then return end
    local duration = readyCooldown(item)
    if not duration then
        stopReady(item)
        return
    end
    local zero = duration:IsZero()
    if not issecretvalue(zero) and zero then
        stopReady(item)
        return
    end
    if not readyDurations[item] then traceEvent(item, "ready", "pulse-track") end
    readyDurations[item] = duration
    square.curve = readyCurve(s.duration)
    updateReady(square)
    square:SetScript("OnUpdate", updateReady)
    square:Show()
end

local function styleFlash(item)
    local flash = item.CooldownFlash
    if not flash or not flash.Flipbook then return end
    local s, key = settings(item, "flash")
    local custom = s and s.custom
    local square = edges[item]
    if custom then
        square = edge(item)
        square.item = item
        square.levelAnchor = flash
        traceEdge(square, item, "ready")
        styleEdge(square, item, key, s.color, s.thickness)
        if not square.readyEdge then
            square.readyEdge = true
            square:Hide()
        end
        if readyDurations[item] then square.curve = readyCurve(s.duration) end
    elseif square then
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

local function styleDebuff(item)
    local border = item.DebuffBorder
    if not border or not border.Texture then return end
    local s, key = settings(item, "debuff")
    local custom = s and s.custom
    border.Texture:SetAlpha(custom and 0 or 1)
    if custom then
        local square = edge(border)
        styleEdge(square, item, key, debuffColors[item] or dispelColor(nil), s.thickness)
        local shown = border.Texture:IsShown()
        square:SetShown(issecretvalue(shown) or shown)
    elseif edges[border] then
        edges[border]:Hide()
    end
end

-- Wiring -------------------------------------------------------------------------------------

local function hook(item)
    if hooked[item] then return end
    hooked[item] = true
    if item.ShowPandemicStateFrame then hooksecurefunc(item, "ShowPandemicStateFrame", stylePandemic) end
    if item.HidePandemicStateFrame then
        hooksecurefunc(item, "HidePandemicStateFrame", function()
            for frame, styled in pairs(pandemicStyled) do
                if styled.item == item then pandemicStyled[frame] = nil end
            end
        end)
    end
    -- AddAlert/RemoveAlert re-sort through UpdateAlerts after the alert is anchored and before it shows.
    if item.UpdateAlerts then hooksecurefunc(item, "UpdateAlerts", styleAlerts) end
    local flash = item.CooldownFlash
    if flash and flash.FlashAnim then
        hooksecurefunc(flash.FlashAnim, "Play", function()
            traceEvent(item, "ready", "native-play")
            trackReady(item, true)
        end)
        -- Blizzard also stops the flash when the spell reports the GCD or its cooldown resets: re-read the cooldown.
        hooksecurefunc(flash.FlashAnim, "Stop", function()
            traceEvent(item, "ready", "native-stop")
            trackReady(item, false)
        end)
        local cooldown = item.GetCooldownFrame and item:GetCooldownFrame() or item.Cooldown
        if cooldown then cooldown:HookScript("OnCooldownDone", function() stopReady(item) end) end
        item:HookScript("OnHide", function() stopReady(item) end)
        flash.FlashAnim:HookScript("OnFinished", function()
            traceEvent(item, "ready", "native-finished")
            stopReady(item)
        end)
        flash:HookScript("OnShow", function() traceEvent(item, "ready", "parent-show") end)
        flash:HookScript("OnHide", function() traceEvent(item, "ready", "parent-hide") end)
    end
    if item.DebuffBorder and item.DebuffBorder.UpdateFromAuraData then
        hooksecurefunc(item.DebuffBorder, "UpdateFromAuraData", function(_, auraData)
            if auraData then debuffColors[item] = dispelColor(auraData) end
            styleDebuff(item)
        end)
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
                    "Replace Blizzard's end-of-cooldown flash with a square edge that brightens toward the end, then disappears."),
                color = color("flash", 2, "Color"),
                thickness = range("flash", "thickness", 3, "Thickness", 1, 5, 1),
                duration = range("flash", "duration", 4, "Brighten duration", 0.2, 2, 0.05),
            },
        }
    end
    return args
end

function NativeGlows:OnInitialize()
    self.db = Addon.db:RegisterNamespace("NativeGlows", defaults)
end

function NativeGlows:OnEnable()
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() traceEvent(self, "cooldowns", "update") end)
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
