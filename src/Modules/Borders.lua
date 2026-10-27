local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Borders = Addon:NewModule("Borders", "AceEvent-3.0")
local Safe = Addon:GetModule("Safe")
local REQUESTED = "RCM_BORDERS_REQUESTED"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local entries, active = {}, {}
local dirty = false
local pixelSize
local defaults = { profile = { enabled = false } }

local function snap(value)
    return math.floor(value / pixelSize + 0.5) * pixelSize
end

local function pixelThickness(value)
    return math.max(1, math.floor(value / pixelSize + 0.5)) * pixelSize
end

function Borders:Request()
    if not self.db then return end
    if InCombatLockdown() then
        dirty = true
        return
    end
    if not self.db.profile.enabled and #active == 0 then return end
    Safe:Notify(REQUESTED, "all")
end

function Borders:IsExcluded(key)
    return key == "CastBar" or key == "BuffIcon" or key == "BuffBar"
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
        dirty = true
    end
    -- Styling can restore the original edge dimensions even when its settings did not change.
    if entry.collapsed then dirty = true end
    if dirty or self.db.profile.enabled then self:Request() end
end

local function restore(entry)
    entry.border:SetFrameLevel(entry.frame:GetFrameLevel() + entry.levelOffset)
    local edges, anchor = entry.border.edges, entry.anchor
    for i, edge in ipairs(edges) do
        edge:ClearAllPoints()
        if i <= 4 then
            edge:SetSnapToPixelGrid(true)
            edge:SetTexelSnappingBias(0)
            edge:Show()
            edge:SetVertexColor(entry.r, entry.g, entry.b, entry.a)
        else
            edge:Hide()
        end
    end
    local top, bottom, left, right = unpack(edges)
    top:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    left:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
    right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    top:SetHeight(entry.size)
    bottom:SetHeight(entry.size)
    left:SetWidth(entry.size)
    right:SetWidth(entry.size)
    entry.collapsed = nil
end

local function rect(owner, left, bottom, right, top)
    return { owner = owner, left = left, bottom = bottom, right = right, top = top }
end

local function append(list, owner, left, bottom, right, top)
    if right > left and top > bottom then
        list[#list + 1] = rect(owner, left, bottom, right, top)
    end
end

-- Subtract a rectangle into at most four non-overlapping pieces.
local function subtract(source, cut, result)
    local left, bottom = math.max(source.left, cut.left), math.max(source.bottom, cut.bottom)
    local right, top = math.min(source.right, cut.right), math.min(source.top, cut.top)
    if left >= right or bottom >= top then
        result[#result + 1] = source
        return
    end
    append(result, source.owner, source.left, source.bottom, left, source.top)
    append(result, source.owner, right, source.bottom, source.right, source.top)
    append(result, source.owner, left, source.bottom, right, bottom)
    append(result, source.owner, left, top, right, source.top)
end

local function cutPieces(pieces, cut)
    local intersects = false
    for _, piece in ipairs(pieces) do
        if piece.left < cut.right and piece.right > cut.left and piece.bottom < cut.top and piece.top > cut.bottom then
            intersects = true
            break
        end
    end
    if not intersects then return pieces end
    local result = {}
    for _, piece in ipairs(pieces) do subtract(piece, cut, result) end
    return result
end

local function sharedVertical(a, b, seams)
    local bottom, top = math.max(a.bottom, b.bottom), math.min(a.top, b.top)
    local gap = b.left - a.right
    local reach = a.thickness + b.thickness
    if top <= bottom or a.left >= b.left or a.right >= b.right or gap > 0.01 or gap < -reach - 0.01 then return end
    -- Native icon padding can overlap frame bounds. Do not treat diagonal corner overlap as a neighbor.
    if gap < -0.01 and top - bottom <= reach then return end
    local thickness = pixelThickness(math.max(a.thickness, b.thickness))
    local left = snap((a.right + b.left - thickness) / 2)
    bottom, top = snap(bottom), snap(top)
    if top <= bottom then return end
    seams[#seams + 1] = rect(a, left, bottom, left + thickness, top)
    local cut = rect(a, -math.huge, bottom, math.huge, top)
    a.sides[4] = cutPieces(a.sides[4], cut)
    b.sides[3] = cutPieces(b.sides[3], cut)
end

local function sharedHorizontal(a, b, seams)
    local left, right = math.max(a.left, b.left), math.min(a.right, b.right)
    local gap = a.bottom - b.top
    local reach = a.thickness + b.thickness
    if right <= left or a.top <= b.top or a.bottom <= b.bottom or gap > 0.01 or gap < -reach - 0.01 then return end
    if gap < -0.01 and right - left <= reach then return end
    local thickness = pixelThickness(math.max(a.thickness, b.thickness))
    local bottom = snap((a.bottom + b.top - thickness) / 2)
    if a.kind == "bars" or b.kind == "bars" then
        -- Continue the centered line across overhangs instead of stepping back to an inset edge.
        left, right = math.min(a.left, b.left), math.max(a.right, b.right)
        a.sides[2], b.sides[1] = {}, {}
    end
    left, right = snap(left), snap(right)
    if right <= left then return end
    seams[#seams + 1] = rect(a, left, bottom, right, bottom + thickness)
    local cut = rect(a, left, -math.huge, right, math.huge)
    a.sides[2] = cutPieces(a.sides[2], cut)
    b.sides[1] = cutPieces(b.sides[1], cut)
end

local function render()
    local levels = {}
    for _, entry in ipairs(active) do
        local strata = entry.border:GetFrameStrata()
        levels[strata] = math.max(levels[strata] or 0, entry.frame:GetFrameLevel() + entry.levelOffset)
    end
    for _, entry in ipairs(active) do
        -- A seam extends into its neighbor, so it must render above both elements' contents.
        entry.border:SetFrameLevel(levels[entry.border:GetFrameStrata()])
    end
    local candidates = {}
    for _, entry in ipairs(active) do
        local l, b, r, t = snap(entry.left), snap(entry.bottom), snap(entry.right), snap(entry.top)
        local s = pixelThickness(entry.thickness)
        entry.sides = {
            { rect(entry, l, t - s, r, t) }, { rect(entry, l, b, r, b + s) },
            { rect(entry, l, b, l + s, t) }, { rect(entry, r - s, b, r, t) },
        }
    end
    for i, a in ipairs(active) do
        for j = i + 1, #active do
            local b = active[j]
            if b.top < a.bottom - 0.01 then break end
            if b.left <= a.right + 0.01 and b.right >= a.left - 0.01 then
                sharedVertical(a, b, candidates)
                sharedVertical(b, a, candidates)
                sharedHorizontal(a, b, candidates)
                sharedHorizontal(b, a, candidates)
            end
        end
    end
    for _, seam in ipairs(candidates) do seam.shared = true end
    for _, entry in ipairs(active) do
        for _, side in ipairs(entry.sides) do
            for _, piece in ipairs(side) do candidates[#candidates + 1] = piece end
        end
        entry.sides = nil
        entry.used = 0
    end
    -- Seams take priority. Removing all overlap also avoids darker translucent corners and junctions.
    local drawn = {}
    for _, candidate in ipairs(candidates) do
        local pieces = { candidate }
        for _, previous in ipairs(drawn) do
            pieces = cutPieces(pieces, previous)
            if #pieces == 0 then break end
        end
        for _, piece in ipairs(pieces) do
            piece.shared = candidate.shared
            drawn[#drawn + 1] = piece
            local entry = piece.owner
            entry.used = entry.used + 1
            local edge = entry.border.edges[entry.used]
            if not edge then
                edge = entry.border:CreateTexture(nil, "OVERLAY")
                edge:SetTexture(WHITE)
                entry.border.edges[entry.used] = edge
            end
            -- All pieces already use shared screen-space boundaries; per-frame snapping can split them.
            edge:SetSnapToPixelGrid(false)
            edge:SetTexelSnappingBias(0)
            local scale = entry.border:GetEffectiveScale()
            edge:ClearAllPoints()
            edge:SetPoint("TOPLEFT", entry.anchor, "TOPLEFT",
                (piece.left - entry.left) / scale, (piece.top - entry.top) / scale)
            edge:SetSize((piece.right - piece.left) / scale, (piece.top - piece.bottom) / scale)
            edge:SetVertexColor(entry.r, entry.g, entry.b, entry.a)
            edge:Show()
        end
    end
    for _, entry in ipairs(active) do
        for i = entry.used + 1, #entry.border.edges do entry.border.edges[i]:Hide() end
        entry.collapsed = true
    end
end

function Borders:Refresh()
    -- A queued message may run after combat starts, even if its request was safe.
    if InCombatLockdown() then
        dirty = true
        return
    end
    local changed = dirty
    local _, screenHeight = GetPhysicalScreenSize()
    -- GetEffectiveScale gives global UI coordinates, not physical display pixels.
    local currentPixelSize = UIParent:GetHeight() * UIParent:GetEffectiveScale() / screenHeight
    if pixelSize ~= currentPixelSize then changed = true; pixelSize = currentPixelSize end
    dirty = false
    wipe(active)
    for _, entry in pairs(entries) do
        local enabled = self.db.profile.enabled and not self:IsExcluded(entry.key)
        if enabled and entry.kind == "bars" then
            local layout, bars, resources = Addon:GetModule("Layout"), Addon:GetModule("Bars"), Addon:GetModule("Resources")
            local settings = layout.db.profile.stack[entry.key]
            local selected = bars:GetFrame(entry.key) or resources:Get(entry.key)
            enabled = settings and settings.enabled and selected == entry.frame
        end
        local visible = enabled and entry.size > 0 and entry.frame:IsVisible() and entry.border:IsShown()
        local left, bottom, width, height, scale, borderScale
        if visible then
            local strata = entry.border:GetFrameStrata()
            local level = entry.frame:GetFrameLevel() + entry.levelOffset
            if entry.strata ~= strata or entry.level ~= level then changed = true end
            entry.strata, entry.level = strata, level
            scale = entry.anchor:GetEffectiveScale()
            borderScale = entry.border:GetEffectiveScale()
            left, bottom = entry.anchor:GetLeft(), entry.anchor:GetBottom()
            width, height = entry.anchor:GetWidth(), entry.anchor:GetHeight()
            visible = not issecretvalue(left) and not issecretvalue(bottom)
                and not issecretvalue(width) and not issecretvalue(height)
                and not issecretvalue(scale) and not issecretvalue(borderScale)
                and left ~= nil and bottom ~= nil and width > 0 and height > 0 and scale > 0 and borderScale > 0
        end
        if visible then
            local right, top = (left + width) * scale, (bottom + height) * scale
            left, bottom = left * scale, bottom * scale
            local thickness = math.min(entry.size * borderScale, (right - left) / 2, (top - bottom) / 2)
            if entry.left ~= left or entry.bottom ~= bottom or entry.right ~= right
                or entry.top ~= top or entry.thickness ~= thickness then changed = true end
            entry.left, entry.bottom, entry.right, entry.top, entry.thickness = left, bottom, right, top, thickness
            active[#active + 1] = entry
        elseif entry.collapsed then
            restore(entry)
        end
        if entry.visible ~= visible then changed = true; entry.visible = visible end
    end
    if not changed then return end
    -- Stable ownership: upper/left elements supply the shared color; wider borders supply the thickness.
    table.sort(active, function(a, b)
        if a.top ~= b.top then return a.top > b.top end
        return a.left < b.left
    end)
    render()
end

function Borders:SetShared(value)
    self.db.profile.enabled = value
    dirty = true
    self:Request()
end

function Borders:MigrateProfile()
    local profile = self.db.profile
    if rawget(profile, "enabled") == nil then
        profile.enabled = profile.icons == true or profile.bars == true
    end
    profile.icons, profile.bars = nil, nil
end

function Borders:OnProfileRefresh()
    self:MigrateProfile()
    self:SetShared(self.db.profile.enabled)
end

function Borders:OnInitialize()
    self.db = Addon.db:RegisterNamespace("Borders", defaults)
    self:MigrateProfile()
end

function Borders:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Request")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnProfileRefresh")
    self:RegisterEvent("UI_SCALE_CHANGED", "OnProfileRefresh")
    self:RegisterMessage(REQUESTED, "Refresh")
    self:RegisterMessage(Addon:GetModule("Layout").MESSAGES.APPLIED, "Request")
    local Viewers, Resources, Bars = Addon:GetModule("Viewers"), Addon:GetModule("Resources"), Addon:GetModule("Bars")
    for _, message in pairs(Viewers.MESSAGES) do self:RegisterMessage(message, "Request") end
    for _, message in pairs(Resources.MESSAGES) do self:RegisterMessage(message, "Request") end
    self:RegisterMessage(Bars.MESSAGES.CHANGED, "Request")
    self:Request()
end

function Borders:OnDisable()
    for _, entry in pairs(entries) do
        if entry.collapsed then restore(entry) end
    end
    wipe(active)
end
