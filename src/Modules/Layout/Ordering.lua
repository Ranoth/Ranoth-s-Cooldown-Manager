--- Stack ordering, key resolution and ordering diagnostics.
local addon_name = ...
local RanothsCooldownManager = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local Layout = RanothsCooldownManager:GetModule("Layout")
local Internal = Layout.Internal
local defaults = Internal.defaults
local Printer = RanothsCooldownManager:GetModule("Printer")
local Options = RanothsCooldownManager:GetModule("Options")

--- Stack keys sorted by position, ties broken alphabetically.
--- @param includeDisabled boolean
--- @return string[]
function Layout:GetOrderedKeys(includeDisabled)
    local profile = self.db.profile
    local keys = {}
    for key, entry in pairs(profile.stack) do
        -- Ignore stale saved entries for frames that are no longer part of the stack (e.g. BuffBar).
        if defaults.profile.stack[key] and (includeDisabled or entry.enabled or key == profile.anchorKey) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        local pa, pb = profile.stack[a].position, profile.stack[b].position
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return keys
end

--- Resolve a case-insensitive key name to a stack key.
--- @param name string
--- @return string|nil
function Layout:ResolveKey(name)
    name = name and name:lower()
    for key in pairs(self.db.profile.stack) do
        if defaults.profile.stack[key] and key:lower() == name then return key end
    end
end

--- Move an entry to a position; the other entries are renumbered 1..n.
--- @param key string
--- @param position number
--- @return boolean success
function Layout:SetPosition(key, position)
    local stack = self.db.profile.stack
    if not stack[key] or type(position) ~= "number" then return false end

    local keys = self:GetOrderedKeys(true)
    for i, k in ipairs(keys) do
        if k == key then
            table.remove(keys, i)
            break
        end
    end
    table.insert(keys, math.max(1, math.min(math.floor(position), #keys + 1)), key)
    for i, k in ipairs(keys) do
        stack[k].position = i
    end

    self:Request()
    Options:Refresh()
    return true
end

--- Print the current stack, top to bottom.
function Layout:Describe()
    local profile = self.db.profile
    for i, key in ipairs(self:GetOrderedKeys(true)) do
        local entry = profile.stack[key]
        local flags = (entry.enabled and "" or " (disabled)") .. (key == profile.anchorKey and " (anchor)" or "")
        Printer:Print(i .. ". " .. key .. flags)
    end
end
