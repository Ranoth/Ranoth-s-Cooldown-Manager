--- Border texture reuse, shared layering and original-edge restoration.
local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Internal = Addon:GetModule("Borders").Internal
local WHITE = "Interface\\Buttons\\WHITE8X8"

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

local function render(active, pixelSize)
    local levels = {}
    for _, entry in ipairs(active) do
        local strata = entry.border:GetFrameStrata()
        levels[strata] = math.max(levels[strata] or 0, entry.frame:GetFrameLevel() + entry.levelOffset)
    end
    for _, entry in ipairs(active) do
        -- A seam extends into its neighbor, so it must render above both elements' contents.
        entry.border:SetFrameLevel(levels[entry.border:GetFrameStrata()])
        entry.used = 0
    end
    for _, piece in ipairs(Internal.BuildPieces(active, pixelSize)) do
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
    for _, entry in ipairs(active) do
        for i = entry.used + 1, #entry.border.edges do entry.border.edges[i]:Hide() end
        entry.collapsed = true
    end
end

Internal.Restore = restore
Internal.Render = render
