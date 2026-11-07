local addon_name = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Trackers = Addon:GetModule("CustomTrackers")
local Internal = Trackers.Internal
local frames, pool = Internal.frames, Internal.pool
local function create(id)
    local reused = table.remove(pool)
    if reused then
        reused.trackerID = id
        reused.warnedCooldown = nil
        reused.requestedItemID = nil
        frames[id] = reused
        return reused
    end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.trackerID = id
    frame:SetSize(36, 36)
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetAllPoints()
    local mask = frame:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    mask:SetAllPoints()
    frame.Icon:AddMaskTexture(mask)
    frame.IconOverlay = frame:CreateTexture(nil, "OVERLAY")
    frame.IconOverlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetAllPoints()
    frame.Cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe")
    frame.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
    frame.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
    frame.Cooldown:SetDrawEdge(false)
    for _, region in ipairs({ frame.Cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            frame.countdownText = region
            frame.defaultCountdownFont = { region:GetFont() }
            break
        end
    end
    frame.Cooldown:HookScript("OnCooldownDone", function()
        frame.Icon:SetDesaturated(false)
        frame.desaturationDuration = nil
        frame:SetScript("OnUpdate", nil)
    end)
    frame:SetScript("OnHide", function(self)
        self.desaturationDuration = nil
        self:SetScript("OnUpdate", nil)
    end)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame.Cooldown:GetFrameLevel() - 1)
    local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.Applications = { Applications = count }
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.equipSlot then
            GameTooltip:SetInventoryItem("player", self.equipSlot)
        elseif self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetSpellByID(self.spellID)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.GetSpellID = function(self) return self.spellID end
    frame.GetEquipSlot = function(self) return self.equipSlot end
    frame.GetItemID = function(self) return self.itemID end
    frame.GetCooldownFrame = function(self) return self.Cooldown end
    frame.HasVisualDataSource_Charges = function(self) return self.hasCharges end
    frame.isCustomTracker = true
    frame:Hide()
    frames[id] = frame
    return frame
end

local function setIconTexture(frame, texture)
    if frame.iconTexture == texture then return end
    local coordinates = { frame.Icon:GetTexCoord() }
    frame.Icon:SetTexture(texture)
    frame.Icon:SetTexCoord(unpack(coordinates))
    frame.iconTexture = texture
end

Internal.CreateFrame = create
Internal.SetIconTexture = setIconTexture
