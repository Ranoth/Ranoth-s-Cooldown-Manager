--- Event-driven replacements for Blizzard's cooldown-icon proc alerts.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Glow = Addon:NewModule("Glow", "AceEvent-3.0")
local Viewers = Addon:GetModule("Viewers")
local Skin = Addon:GetModule("Skin")
local rawSetAlpha = getmetatable(UIParent).__index.SetAlpha
local owners, states = {}, {}
local suppressed = setmetatable({}, { __mode = "k" })
local alertHooked = setmetatable({}, { __mode = "k" })
local managerHooked = false
local previews = {} -- Session-only; never saved to a profile.
function Glow:GetPreview(key) return previews[key] == true end
function Glow:SetPreview(key, value) previews[key] = value end
local GLOW_LEVEL_OFFSET = 8
local KEYS = { "Essential", "Utility", "BuffIcon" }

local function settings()
    return {
        enabled = false,
        color = { r = 1, g = 0.82, b = 0, a = 1 },
        thickness = 2,
        length = 10,
        speed = 0.25,
    }
end

local defaults = { profile = {
    Essential = settings(), Utility = settings(), BuffIcon = settings(),
} }

local function suppress(alert, enabled)
    if not alert then return end
    if enabled then
        if suppressed[alert] == nil then suppressed[alert] = alert:GetAlpha() end
        if not alertHooked[alert] then
            alertHooked[alert] = true
            hooksecurefunc(alert, "SetAlpha", function(frame)
                if suppressed[frame] ~= nil then rawSetAlpha(frame, 0) end
            end)
        end
        rawSetAlpha(alert, 0)
    elseif suppressed[alert] ~= nil then
        local alpha = suppressed[alert]
        suppressed[alert] = nil
        rawSetAlpha(alert, alpha)
    end
end

local function draw(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
        frame.readableWidth, frame.readableHeight = width, height
    else
        width, height = frame.readableWidth, frame.readableHeight
    end
    if not width or not height then return false end
    local s = frame.settings
    local inset = Skin:GetGlowInset(frame.viewerKey)
    local innerWidth, innerHeight = width - 2 * inset, height - 2 * inset
    if innerWidth <= 0 or innerHeight <= 0 then
        for _, line in ipairs(frame.lines) do line:Hide() end
        return true
    end
    local thickness = math.min(s.thickness, innerWidth, innerHeight)
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
                line:SetPoint("CENTER", frame, "TOPLEFT", inset + x, -inset - y)
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

local function apply(item)
    local st = states[item]
    local key = owners[item]
    if not st then return end
    local s = key and Glow.db.profile[key]
    local enabled = Glow:IsEnabled() and s and s.enabled
    local active = enabled and (st.active or previews[key])
    -- Stopping must never depend on native-frame geometry being readable.
    if not active and st.frame then
        st.frame:SetScript("OnUpdate", nil)
        st.frame:Hide()
    end
    local alert = item.SpellActivationAlert
    if st.alert and st.alert ~= alert then suppress(st.alert, false) end
    st.alert = alert
    if key then Skin:FitNativeEffect(item, alert, key) end
    suppress(alert, enabled)
    if active then
        st.frame = st.frame or create(item, item.Icon or item, item:GetFrameLevel() + GLOW_LEVEL_OFFSET)
        local frame = st.frame
        frame.settings = s
        frame.viewerKey = key
        frame.readableWidth = st.width or frame.readableWidth
        frame.readableHeight = st.height or frame.readableHeight
        frame:SetFrameLevel(item:GetFrameLevel() + GLOW_LEVEL_OFFSET)
        local c = s.color
        for _, line in ipairs(frame.lines) do line:SetVertexColor(c.r, c.g, c.b, c.a) end
        if not draw(frame) then
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
            -- Keep Blizzard's alert visible until usable geometry is available.
            suppress(alert, false)
            return
        end
        frame:SetScript("OnUpdate", onUpdate)
        frame:Show()
    elseif st.frame then
        st.frame:SetScript("OnUpdate", nil)
        st.frame:Hide()
    end
end

local function setActive(item, active)
    local st = states[item]
    if not st then return end
    local NativeGlows = Addon:GetModule("NativeGlows", true)
    if NativeGlows then NativeGlows:TracePixel(item, active) end
    st.active = active
    apply(item)
end

local function hookManager()
    if managerHooked or not ActionButtonSpellAlertManager then return end
    managerHooked = true
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, item) setActive(item, true) end)
    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, item) setActive(item, false) end)
end

function Glow:OnViewerMessage(_, key)
    if not self.db.profile[key] then return end
    hookManager()
    for item, owner in pairs(owners) do
        if owner == key then owners[item] = nil end
    end
    for _, item in ipairs(Viewers:GetItems(key)) do
        owners[item] = key
        if not states[item] then
            local alert = item.SpellActivationAlert
            local shown = alert and alert:IsShown()
            states[item] = { active = not issecretvalue(shown) and shown == true }
            item:HookScript("OnHide", function(frame)
                local glow = states[frame].frame
                if glow then glow:SetScript("OnUpdate", nil); glow:Hide() end
            end)
            item:HookScript("OnShow", apply)
            if item.ResetCooldownData then
                hooksecurefunc(item, "ResetCooldownData", function(frame) setActive(frame, false) end)
            end
        end
        local icon = item.Icon or item
        local width, height = icon:GetWidth(), icon:GetHeight()
        if not issecretvalue(width) and not issecretvalue(height) and width > 0 and height > 0 then
            states[item].width, states[item].height = width, height
        end
        apply(item)
    end
    for item in pairs(states) do
        if not owners[item] then apply(item) end
    end
end

function Glow:OnProfileRefresh()
    for item in pairs(states) do apply(item) end
end

function Glow:OnInitialize()
    self.db = Addon.db:RegisterNamespace("Glow", defaults)
end

function Glow:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshGeometry")
    self:RegisterMessage(Viewers.MESSAGES.AVAILABLE, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.LAYOUT_UPDATED, "OnViewerMessage")
    self:RegisterMessage(Viewers.MESSAGES.SHOWN, "OnViewerMessage")
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function Glow:RefreshGeometry()
    for _, key in ipairs(KEYS) do self:OnViewerMessage(nil, key) end
end

function Glow:OnDisable()
    wipe(previews)
    for _, st in pairs(states) do
        if st.frame then st.frame:SetScript("OnUpdate", nil); st.frame:Hide() end
        suppress(st.alert, false)
    end
end
