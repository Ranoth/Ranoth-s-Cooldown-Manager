--- Border registration, glow seam queries and overlay layering.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Borders = Addon:GetModule("Borders")
local Internal = Borders.Internal
local entries = Internal.entries

function Borders:IsExcluded(key)
    return key == "CastBar" or key == "BuffIcon" or key == "BuffBar"
end

local STRATA_ORDER = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4,
    DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

function Borders:GetOverlayLevel(frame, minimum, baseStrata)
    local level = minimum
    local strata = baseStrata or frame:GetFrameStrata()
    for _, entry in pairs(entries) do
        if entry.size > 0 and entry.border:IsShown() and entry.frame:IsVisible() then
            local borderStrata = entry.border:GetFrameStrata()
            if STRATA_ORDER[borderStrata] > STRATA_ORDER[strata] then
                strata, level = borderStrata, minimum
            end
            if borderStrata == strata then level = math.max(level, entry.border:GetFrameLevel() + 1) end
        end
    end
    return level, strata
end

function Borders:GetHorizontalGlowInsets(frame, fallback)
    local entry = entries[frame]
    if not entry or not entry.collapsed then return fallback, fallback end
    local scale = entry.glowScale
    if not scale then return fallback, fallback end
    return entry.glowLeft and entry.glowLeft / scale or fallback,
        entry.glowRight and entry.glowRight / scale or fallback
end

function Borders:GetVerticalGlowInsets(frame, fallback)
    local entry = entries[frame]
    if not entry or not entry.collapsed or not entry.glowScale then return fallback, fallback end
    return entry.glowTop and entry.glowTop / entry.glowScale or fallback,
        entry.glowBottom and entry.glowBottom / entry.glowScale or fallback
end

function Borders:DescribeLayers(key)
    local Printer = Addon:GetModule("Printer")
    for _, entry in pairs(entries) do
        if entry.key == key and entry.size > 0 and entry.frame:IsVisible() then
            Printer:Print(string.format("%s border: owner=%s/%d border=%s/%d shown=%s",
                key, entry.frame:GetFrameStrata(), entry.frame:GetFrameLevel(),
                entry.border:GetFrameStrata(), entry.border:GetFrameLevel(), tostring(entry.border:IsShown())))
        end
    end
end

function Borders:Register(frame, border, anchor, size, color, kind, key)
    local entry = entries[frame]
    if not entry then
        entry = { frame = frame, levelOffset = border:GetFrameLevel() - frame:GetFrameLevel() }
        entries[frame] = entry
        frame:HookScript("OnShow", function() self:Request() end)
        frame:HookScript("OnHide", function() self:Request() end)
        frame:HookScript("OnSizeChanged", function() self:Request() end)
    end
    if entry.border ~= border or entry.anchor ~= anchor or entry.size ~= size or entry.kind ~= kind or entry.key ~= key
        or entry.r ~= color.r or entry.g ~= color.g or entry.b ~= color.b or entry.a ~= color.a then
        entry.border, entry.anchor, entry.size, entry.kind = border, anchor, size, kind
        entry.key = key
        entry.r, entry.g, entry.b, entry.a = color.r, color.g, color.b, color.a
        Internal.dirty = true
    end
    -- Styling can restore the original edge dimensions even when its settings did not change.
    if entry.collapsed then Internal.dirty = true end
    if Internal.dirty or self.db.profile.enabled then self:Request() end
end
