--- Stack container, cached slots and debug overlays.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:GetModule("Layout")
local Internal = Layout.Internal
local Printer = RanothsCooldownManager:GetModule("Printer")
local container

--- The frame that spans the whole stack. Safe to use for alpha, scale, or visibility of the widget.
--- @return Frame
function Layout:GetContainer()
    if not container then
        container = CreateFrame("Frame", "RanothsCooldownManagerContainer", UIParent)
        container:EnableMouse(false)
    end
    return container
end

function Layout:GetSlot(key)
    self.slots = self.slots or {}
    local slot = self.slots[key]
    if not slot then
        slot = CreateFrame("Frame", nil, self:GetContainer())
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(math.random(), math.random(), math.random(), 0.4)
        slot.label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.label:SetPoint("CENTER")
        slot.label:SetText(key)
        self.slots[key] = slot
    end
    slot.bg:SetShown(self.debug == true)
    slot.label:SetShown(self.debug == true)
    return slot
end

--- Toggle colored overlays on the slots to see the stack.
function Layout:ToggleDebug()
    self.debug = not self.debug
    Printer:Print(self.debug and "Layout overlay enabled" or "Layout overlay disabled")
    self:Request()
end

function Internal.HideContainer()
    if container then container:Hide() end
end
