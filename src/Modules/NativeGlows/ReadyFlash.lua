--- Secret-safe square ready flashes and custom-tracker flipbook replicas.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:GetModule("NativeGlows")
local Internal = NativeGlows.Internal
local weak = Internal.weak
local edges = Internal.edges
local iconSizes = Internal.iconSizes
local settings = Internal.settings
local WHITE = Internal.WHITE
local UPDATE_INTERVAL = Internal.UPDATE_INTERVAL
local Skin = Addon:GetModule("Skin")
local traceEvent = Internal.TraceEvent
local readyDurations, readyFrames, flipbooks = weak(), weak(), weak()
local raiseReady
local READY_PIECES_PER_EDGE = 16
local READY_LINE_LENGTH = 1 / 8 -- Fraction of the perimeter occupied by each moving line.
local readyCurveSets = setmetatable({}, { __mode = "v" })

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

local function readyCurves(duration, pathWidth, pathHeight)
    local horizontalFraction = pathWidth / (pathWidth + pathHeight)
    local key = string.format("%.17g:%.17g", duration, horizontalFraction)
    local curves = readyCurveSets[key]
    if curves then return curves end
    curves = {}
    for i = 1, 2 * READY_PIECES_PER_EDGE do
        local position = ((i - 1) % READY_PIECES_PER_EDGE + 0.5) / READY_PIECES_PER_EDGE
        local midpoint = i <= READY_PIECES_PER_EDGE and position * horizontalFraction / 2
            or (horizontalFraction + position * (1 - horizontalFraction)) / 2
        curves[i] = readyCurve(duration, midpoint)
    end
    -- Icons retain their active set; unused settings can be collected, including the cache entry.
    readyCurveSets[key] = curves
    return curves
end

local function styleReady(item, s, key)
    local size = iconSizes[item]
    if not size then return false end
    local left, right, inset, bottom, stroke = Skin:GetCustomGlowInsets(item, key, s.thickness)
    local width, height = size[1] - left - right, size[2] - inset - bottom
    if width <= 0 or height <= 0 then return false end
    local thickness = math.min(stroke, width, height)
    local pathWidth, pathHeight = width - thickness, height - thickness
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
                line:SetSnapToPixelGrid(false)
                line:SetTexelSnappingBias(0)
                piece[side] = line
                square.lines[#square.lines + 1] = line
            end
            square.pieces[i] = piece
        end
        square:Hide()
        edges[item] = square
    end
    local icon = item.Icon or item
    local previous = square.readyStyle
    local geometryChanged = not previous or previous.width ~= width or previous.height ~= height
        or previous.thickness ~= thickness or previous.inset ~= inset or previous.left ~= left
    local curvesChanged = not square.readyCurves or not previous or previous.width ~= width or previous.height ~= height
        or previous.thickness ~= thickness or previous.duration ~= s.duration
    local colorChanged = not previous or previous.r ~= s.color.r or previous.g ~= s.color.g
        or previous.b ~= s.color.b or previous.a ~= s.color.a
    if not previous or previous.icon ~= icon then
        square:ClearAllPoints()
        square:SetAllPoints(icon)
    end
    if curvesChanged then square.readyCurves = readyCurves(s.duration, pathWidth, pathHeight) end
    if geometryChanged or curvesChanged or colorChanged then
        for i, piece in ipairs(square.pieces) do
            if curvesChanged then piece.curve = square.readyCurves[i] end
            local horizontal = i <= READY_PIECES_PER_EDGE
            local index = (i - 1) % READY_PIECES_PER_EDGE
            local length = (horizontal and pathWidth or pathHeight) / READY_PIECES_PER_EDGE
            local midpoint = (index + 0.5) * length
            for side, line in ipairs(piece) do
                if geometryChanged then
                    local x = horizontal and midpoint or pathWidth
                    local y = horizontal and 0 or midpoint
                    if side == 2 then x, y = pathWidth - x, pathHeight - y end
                    line:ClearAllPoints()
                    line:SetPoint("CENTER", square, "TOPLEFT", left + thickness / 2 + x, -inset - thickness / 2 - y)
                    line:SetSize(horizontal and length + thickness or thickness,
                        horizontal and thickness or length + thickness)
                end
                if colorChanged then line:SetVertexColor(s.color.r, s.color.g, s.color.b, s.color.a) end
            end
        end
    end
    previous = previous or {}
    previous.width, previous.height, previous.thickness, previous.duration = width, height, thickness, s.duration
    previous.icon, previous.inset = icon, inset
    previous.left, previous.right = left, right
    previous.r, previous.g, previous.b, previous.a = s.color.r, s.color.g, s.color.b, s.color.a
    square.readyStyle = previous
    raiseReady(item)
    return true
end

local function active(duration)
    if not duration then return false end
    local zero = duration:IsZero()
    return issecretvalue(zero) or not zero
end

--- Equipped and bag items cool down as items, like Blizzard displays them: their on-use spell only carries the
--- short lockout shared by on-use items.
--- @return table|nil duration, boolean busy, boolean handled
local function itemCooldown(item)
    local slot = item.GetEquipSlot and item:GetEquipSlot()
    local itemID = item.GetItemID and item:GetItemID()
    if issecretvalue(slot) or issecretvalue(itemID) then return nil, true, true end
    local start, length, enable, gcd
    if slot then
        start, length, enable, gcd = GetInventoryItemCooldown("player", slot)
    elseif itemID then
        start, length, enable = C_Item.GetItemCooldown(itemID)
    else
        return nil, false, false
    end
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

--- Blizzard's flipbook is an animation timed from cooldown values that may be secret; the replica instead gates one
--- texture per animation frame with a curve over the remaining duration, which only the engine evaluates.
local FLIPBOOK_ATLAS, FLIPBOOK_ROWS, FLIPBOOK_COLUMNS, FLIPBOOK_DURATION = "UI-HUD-ActionBar-GCD-Flipbook", 11, 2, 0.75
local FLIPBOOK_FRAMES = FLIPBOOK_ROWS * FLIPBOOK_COLUMNS
local flipbookCurves

local function styleFlipbook(item, key)
    local flipbook = flipbooks[item]
    if not flipbook then
        local atlas = C_Texture.GetAtlasInfo(FLIPBOOK_ATLAS)
        local file = atlas and (atlas.file or atlas.filename)
        if not file then return nil end
        if not flipbookCurves then
            flipbookCurves = {}
            local step, epsilon = FLIPBOOK_DURATION / FLIPBOOK_FRAMES, 0.00001
            for i = 1, FLIPBOOK_FRAMES do
                local first, last = FLIPBOOK_DURATION - i * step, FLIPBOOK_DURATION - (i - 1) * step
                local curve = C_CurveUtil.CreateCurve()
                curve:SetType(Enum.LuaCurveType.Linear)
                curve:AddPoint(0, 0)
                if first > epsilon then curve:AddPoint(first, 0) end
                curve:AddPoint(first + epsilon, 1)
                curve:AddPoint(last, 1)
                curve:AddPoint(last + epsilon, 0)
                curve:AddPoint(86400, 0)
                flipbookCurves[i] = curve
            end
        end
        flipbook = CreateFrame("Frame", nil, item)
        flipbook:EnableMouse(false)
        flipbook.item, flipbook.readyElapsed, flipbook.pieces = item, 0, {}
        local width = (atlas.rightTexCoord - atlas.leftTexCoord) / FLIPBOOK_COLUMNS
        local height = (atlas.bottomTexCoord - atlas.topTexCoord) / FLIPBOOK_ROWS
        for i = 1, FLIPBOOK_FRAMES do
            local column, row = (i - 1) % FLIPBOOK_COLUMNS, math.floor((i - 1) / FLIPBOOK_COLUMNS)
            local left, top = atlas.leftTexCoord + column * width, atlas.topTexCoord + row * height
            local texture = flipbook:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(file)
            texture:SetTexCoord(left, left + width, top, top + height)
            texture:SetAllPoints(flipbook)
            texture:SetAlpha(0)
            flipbook.pieces[i] = { texture, curve = flipbookCurves[i] }
        end
        flipbook:Hide()
        flipbooks[item] = flipbook
    end
    -- Same geometry and layer as the skinned native flash.
    Skin:FitNativeEffect(item, flipbook, key, nil, nil, "flash")
    Internal.setLayer(flipbook, item:GetFrameLevel() + 7, item.glowItem or item)
    return flipbook
end

local function readyLevel(item)
    local level = item:GetFrameLevel()
    if item.Cooldown then level = math.max(level, item.Cooldown:GetFrameLevel()) end
    if item.CooldownFlash then level = math.max(level, item.CooldownFlash:GetFrameLevel()) end
    -- The pandemic edge sits one level above Blizzard's pandemic frame.
    if item.PandemicIcon then
        level = math.max(level, item.PandemicIcon:GetFrameLevel() + 1)
        local pandemic = edges[item.PandemicIcon]
        if pandemic and pandemic:IsShown() then level = math.max(level, pandemic:GetFrameLevel()) end
    end
    return level + 1
end

function raiseReady(item)
    local square = edges[item]
    if square and square.readyEdge then
        local level = readyLevel(item.glowItem or item)
        if item.glowItem then level = math.max(level, item:GetFrameLevel() + 9) end
        Internal.setLayer(square, level, item.glowItem or item)
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
        if square.previewDuration then
            duration:SetTimeFromStart(GetTime() + 0.25, square.previewDuration)
        else
            stopReady(square.item)
            return
        end
    end
    for _, piece in ipairs(square.pieces) do
        local alpha = duration:EvaluateRemainingDuration(piece.curve)
        piece[1]:SetAlpha(alpha)
        if piece[2] then piece[2]:SetAlpha(alpha) end
    end
end

function stopReady(item)
    local frame = readyFrames[item]
    if readyDurations[item] then traceEvent(item, "ready", "stop") end
    readyDurations[item] = nil
    if frame then
        frame.previewDuration = nil
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

--- Runs whenever Blizzard refreshes the item's cooldown (casts, GCD start/end, procs, aura changes).
local function refreshReady(item)
    local frame = readyFrames[item]
    if not frame or not settings(item, "flash") then return end
    if item.isCustomTracker and not item:IsShown() then
        stopReady(item)
        return
    end
    local duration, busy = readyCooldown(item)
    if duration then
        if not readyDurations[item] then traceEvent(item, "ready", "track") end
        readyDurations[item] = duration:Copy()
        raiseReady(item)
        frame.readyElapsed = UPDATE_INTERVAL
        updateReady(frame, 0)
        if readyDurations[item] then
            frame:SetScript("OnUpdate", updateReady)
            frame:Show()
        end
    elseif readyDurations[item] then
        if busy then traceEvent(item, "ready", "keep") else stopReady(item) end
    end
end

--- Custom trackers have no Blizzard flash, so they get a replica unless the custom square replaces it.
local function styleFlash(item)
    local flash = item.CooldownFlash
    local replica = item.isCustomTracker
    if not replica and (not flash or not flash.Flipbook) then return end
    local s, key = settings(item, "flash")
    local custom = s and s.custom and styleReady(item, s, key)
    local ready
    if custom then
        ready = edges[item]
    elseif replica and s then
        ready = styleFlipbook(item, key)
    end
    if readyFrames[item] ~= ready then
        stopReady(item)
        readyFrames[item] = ready
    end
    local square = edges[item]
    if not custom and square then
        square.readyCurves = nil
        for _, piece in ipairs(square.pieces) do piece.curve = nil end
    end
    if ready then
        if not readyDurations[item] then ready:Hide() end
        refreshReady(item)
    end
    if flash and flash.Flipbook then flash.Flipbook:SetShown(not custom) end
end

Internal.StyleFlash = styleFlash
Internal.RefreshReady = refreshReady
Internal.RaiseReady = raiseReady
Internal.readyFrames = readyFrames
Internal.flipbooks = flipbooks
Internal.readyCurveSets = readyCurveSets
Internal.StopReady = stopReady

function Internal.StylePreviewFlash(item)
    local s, key = settings(item, "flash")
    local ready
    if s and s.custom then
        if styleReady(item, s, key) then ready = edges[item] end
    elseif s then
        ready = styleFlipbook(item, key)
    end
    if readyFrames[item] ~= ready then
        stopReady(item)
        readyFrames[item] = ready
    end
    if not ready then return false end
    local length = s.custom and s.duration or FLIPBOOK_DURATION
    if not readyDurations[item] or ready.previewDuration ~= length then
        local duration = readyDurations[item] or C_DurationUtil.CreateDuration()
        duration:SetTimeFromStart(GetTime(), length)
        readyDurations[item] = duration
    end
    ready.previewDuration = length
    ready.readyElapsed = UPDATE_INTERVAL
    updateReady(ready, 0)
    ready:SetScript("OnUpdate", updateReady)
    ready:Show()
    return true
end

function Internal.HookReady(item)
    if item.CooldownFlash then
        if item.RefreshSpellCooldownInfo then
            hooksecurefunc(item, "RefreshSpellCooldownInfo", refreshReady)
        elseif item.CooldownFlash.FlashAnim then
            hooksecurefunc(item.CooldownFlash.FlashAnim, "Stop", function() refreshReady(item) end)
        end
        local cooldown = item.GetCooldownFrame and item:GetCooldownFrame() or item.Cooldown
        if cooldown then cooldown:HookScript("OnCooldownDone", function() refreshReady(item) end) end
    elseif item.isCustomTracker then
        item.Cooldown:HookScript("OnCooldownDone", function() refreshReady(item) end)
    end
end
