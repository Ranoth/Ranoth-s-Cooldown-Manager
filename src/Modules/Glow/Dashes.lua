--- Shared moving-dash renderer and active-only animation.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:GetModule("Glow")
local Internal = Glow.Internal
local Skin = Addon:GetModule("Skin")
local function draw(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
        frame.readableWidth, frame.readableHeight = width, height
    else
        width, height = frame.readableWidth, frame.readableHeight
    end
    if not width or not height then return false end
    local s = frame.settings
    local leftInset, rightInset, inset, bottomInset, stroke = Skin:GetCustomGlowInsets(frame.glowItem, frame.viewerKey, s.thickness)
    local innerWidth, innerHeight = width - leftInset - rightInset, height - inset - bottomInset
    if innerWidth <= 0 or innerHeight <= 0 then
        for _, line in ipairs(frame.lines) do line:Hide() end
        return true
    end
    local thickness = math.min(stroke, innerWidth, innerHeight)
    local pathWidth, pathHeight = innerWidth - thickness, innerHeight - thickness
    local perimeter = 2 * (pathWidth + pathHeight)
    if perimeter <= 0 then
        for _, line in ipairs(frame.lines) do line:Hide() end
        return true
    end
    local length = math.min(s.length, perimeter / 8)
    for dash = 1, 8 do
        local start = ((frame.phase + (dash - 1) / 8) % 1) * perimeter
        local edgeStart = 0
        for edge = 1, 4 do
            local horizontal = edge == 1 or edge == 3
            local edgeLength = horizontal and pathWidth or pathHeight
            local edgeEnd = edgeStart + edgeLength
            local first, last = math.max(start, edgeStart), math.min(start + length, edgeEnd)
            if last <= first then
                first = math.max(start - perimeter, edgeStart)
                last = math.min(start + length - perimeter, edgeEnd)
            end
            local line = frame.lines[(dash - 1) * 4 + edge]
            if last > first then
                local midpoint = (first + last) / 2 - edgeStart
                local x, y = thickness / 2, thickness / 2
                if edge == 1 then x = x + midpoint
                elseif edge == 2 then x, y = x + pathWidth, y + midpoint
                elseif edge == 3 then x, y = x + pathWidth - midpoint, y + pathHeight
                else y = y + pathHeight - midpoint end
                line:ClearAllPoints()
                line:SetPoint("CENTER", frame, "TOPLEFT", leftInset + x, -inset - y)
                line:SetSize(horizontal and (last - first + thickness) or thickness,
                    horizontal and thickness or (last - first + thickness))
                line:Show()
            else
                line:Hide()
            end
            edgeStart = edgeEnd
        end
    end
    return true
end

local function onUpdate(frame, elapsed)
    frame.elapsed = frame.elapsed + elapsed
    if frame.elapsed < 1 / 30 then return end
    frame.phase = (frame.phase + frame.elapsed * frame.settings.speed) % 1
    frame.elapsed = 0
    draw(frame)
end

local function create(parent, anchor, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(anchor)
    frame:SetFrameLevel(level)
    frame:EnableMouse(false)
    frame.lines = {}
    frame.phase, frame.elapsed = 0, 0
    -- Four reusable edge pieces let each dash turn a corner without teleporting.
    for i = 1, 32 do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
        frame.lines[i] = line
    end
    frame:Hide()
    return frame
end

--- Moving pixel dashes inside the border of `anchor`, shared with other native-glow replacements.
--- Parent visibility drives the animation: OnUpdate only runs while the parent is shown.
--- @return table frame Call Glow.StartDashes/Glow.StopDashes on it.
function Glow.CreateDashes(parent, anchor, level)
    return create(parent, anchor, level)
end

--- @param settings table { thickness, length, speed }
--- @param color table { r, g, b, a }
function Glow.StartDashes(frame, settings, key, color)
    frame.settings, frame.viewerKey = settings, key
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
        frame.readableWidth, frame.readableHeight = width, height
    end
    for _, line in ipairs(frame.lines) do line:SetVertexColor(color.r, color.g, color.b, color.a or 1) end
    if not draw(frame) then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        return false
    end
    frame:SetScript("OnUpdate", onUpdate)
    frame:Show()
    return true
end

function Glow.StopDashes(frame)
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

Internal.Draw = draw
Internal.OnUpdate = onUpdate
