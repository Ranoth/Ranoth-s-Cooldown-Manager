--- Shared native-effect rendering, ownership and settings.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local NativeGlows = Addon:NewModule("NativeGlows", "AceEvent-3.0")
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
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
local edges = weak() -- Blizzard effect frame (or item, for the ready flash) -> our square edge
local iconSizes = weak() -- item -> readable icon dimensions
local layers = weak()
local clipping = weak()

local function setCustomClipping(frame, custom)
    if custom then
        if clipping[frame] == nil then clipping[frame] = frame:DoesClipChildren() end
        if frame:DoesClipChildren() then frame:SetClipsChildren(false) end
    elseif clipping[frame] ~= nil then
        frame:SetClipsChildren(clipping[frame])
        clipping[frame] = nil
    end
end

local function refitCustomClipping(frame)
    if frame and clipping[frame] ~= nil then
        -- Skin's native fitting requires clipping; only the custom replacement may extend beyond it.
        clipping[frame] = true
        if frame:DoesClipChildren() then frame:SetClipsChildren(false) end
    end
end

local function setLayer(frame, minimum, owner)
    local parent = frame:GetParent()
    owner = owner or parent
    local entry = layers[frame] or {}
    entry.offset, entry.owner = minimum - owner:GetFrameLevel(), owner
    layers[frame] = entry
    local level, strata = Addon:GetModule("Borders"):GetOverlayLevel(frame, minimum, owner:GetFrameStrata())
    if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
    if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
end

local function refreshLayers()
    for frame, entry in pairs(layers) do
        local minimum = entry.owner:GetFrameLevel() + entry.offset
        local level, strata = Addon:GetModule("Borders"):GetOverlayLevel(frame, minimum, entry.owner:GetFrameStrata())
        if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
        if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
    end
end
local function settings(item, effect)
    local key = item.previewKey or owners[item]
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
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
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
    local left, right, top, bottom, stroke = Skin:GetCustomGlowInsets(item, key, thickness)
    thickness = stroke
    local alpha = color.a or 1
    local previous = frame.edgeStyle
    if not previous or previous.icon ~= icon or previous.left ~= left or previous.right ~= right
        or previous.top ~= top or previous.bottom ~= bottom then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", icon, "TOPLEFT", left, -top)
        frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -right, bottom)
    end
    setLayer(frame, level, item.glowItem or item)
    if not previous or previous.r ~= color.r or previous.g ~= color.g or previous.b ~= color.b
        or previous.a ~= alpha or previous.thickness ~= thickness then
        for _, line in ipairs(frame.lines) do
            line:SetVertexColor(color.r, color.g, color.b, alpha)
            if line.horizontal then line:SetHeight(thickness) else line:SetWidth(thickness) end
        end
    end
    previous = previous or {}
    previous.icon, previous.inset = icon, top
    previous.left, previous.right, previous.top, previous.bottom = left, right, top, bottom
    previous.r, previous.g, previous.b, previous.a = color.r, color.g, color.b, alpha
    previous.thickness = thickness
    frame.edgeStyle = previous
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
        local pulse = frame.pulse or {}
        pulse.from, pulse.to, pulse.duration = from, to, duration
        frame.pulse = pulse
        frame.pulseElapsed = UPDATE_INTERVAL
        frame:SetScript("OnUpdate", updatePulse)
        updatePulse(frame, 0)
    else
        frame.pulse = nil
        frame:SetScript("OnUpdate", nil)
        frame:SetAlpha(1)
    end
end

NativeGlows.Internal = {
    defaults = defaults,
    KEYS = KEYS,
    WHITE = WHITE,
    UPDATE_INTERVAL = UPDATE_INTERVAL,
    revision = 0,
    weak = weak,
    owners = owners,
    edges = edges,
    iconSizes = iconSizes,
    settings = settings,
    edge = edge,
    styleEdge = styleEdge,
    setPulse = setPulse,
    setLayer = setLayer,
    RefreshLayers = refreshLayers,
    SetCustomClipping = setCustomClipping,
    RefitCustomClipping = refitCustomClipping,
}
