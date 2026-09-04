--[[
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ZDecursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ZDecursive. If not, see <https://www.gnu.org/licenses/>.
--]]

local function Check(value, message)
  if not value then
    error(message or "check failed", 2)
  end
end

local function Equal(actual, expected, message)
  if actual ~= expected then
    error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local instanceType = "party"
local blocked = false
local inCombat = false
local showAll = false
local created = {}

IsInInstance = function()
  return instanceType ~= "none", instanceType
end

InCombatLockdown = function()
  return inCombat
end

local function NewSlot()
  local slot = {calls = {}, shown = false}
  local function Record(name)
    return function(self, ...)
      self.calls[#self.calls + 1] = {name, ...}
    end
  end
  slot.ClearAllPoints = Record("ClearAllPoints")
  slot.SetAllPoints = Record("SetAllPoints")
  slot.SetTooltipAnchorPoint = Record("SetTooltipAnchorPoint")
  slot.SetHideTooltipInCombat = Record("SetHideTooltipInCombat")
  slot.EnableMouse = Record("EnableMouse")
  slot.SetMouseClickEnabled = Record("SetMouseClickEnabled")
  slot.SetPropagateMouseClicks = Record("SetPropagateMouseClicks")
  slot.SetPassThroughButtons = Record("SetPassThroughButtons")
  slot.SetMouseMotionEnabled = Record("SetMouseMotionEnabled")
  return slot
end

local function FindCall(slot, name)
  for i = 1, #slot.calls do
    if slot.calls[i][1] == name then
      return slot.calls[i]
    end
  end
end

local auraByUnit = {}

local function NewContainer(parent)
  local container = {
    parent = parent,
    enabled = false,
    shown = false,
    unit = nil,
    addSlotCount = 0,
    addGroupCount = 0,
    nativeShowCount = 0,
    nativeUpdateCount = 0,
    nativeClearCount = 0,
    nativeHideCount = 0,
  }
  function container:RefreshNative(kind)
    local hasAura = self.enabled and self.shown and self.unit and auraByUnit[self.unit] == true
    if hasAura then
      if not self.slot.shown then
        self.nativeShowCount = self.nativeShowCount + 1
      else
        self.nativeUpdateCount = self.nativeUpdateCount + 1
      end
      self.slot.shown = true
    elseif self.slot and self.slot.shown then
      self.slot.shown = false
      if kind == "clear" then
        self.nativeClearCount = self.nativeClearCount + 1
      else
        self.nativeHideCount = self.nativeHideCount + 1
      end
    end
  end
  function container:SetAllPoints()
  end
  function container:EnableMouse()
  end
  function container:SetUnit(unit)
    if unit == nil or type(unit) ~= "string" or unit == "" then
      error("Retail native SetUnit requires a public nonempty unit token")
    end
    self.unit = unit
    self:RefreshNative("update")
  end
  function container:AddAuraSlot(key, filter, options)
    self.addSlotCount = self.addSlotCount + 1
    self.slotKey = key
    self.filter = filter
    self.slot = NewSlot()
    options.initializeFrame(self.slot)
  end
  function container:AddAuraGroup()
    self.addGroupCount = self.addGroupCount + 1
  end
  function container:SetAuraSlotFilterString(key, filter)
    self.slotKey = key
    self.filter = filter
    self:RefreshNative("update")
  end
  function container:SetEnabled(enabled)
    self.enabled = enabled
    self:RefreshNative(enabled and "update" or "hide")
  end
  function container:Show()
    self.shown = true
    self:RefreshNative("update")
  end
  function container:Hide()
    self.shown = false
    self:RefreshNative("hide")
  end
  created[#created + 1] = container
  return container
end

CreateFrame = function(kind, _name, parent, template)
  Check(kind == "AuraContainer", "identity carrier creates only an AuraContainer")
  Equal(template, "CustomAuraContainerTemplate", "identity carrier uses Blizzard's native template")
  return NewContainer(parent)
end

local ns = {
  IdentityShowAllDebuffs = function()
    return showAll
  end,
  AuraDisplayMutationBlocked = function()
    return blocked
  end,
  SafeNativeSetUnit = function(container, unit)
    if blocked then
      return false, "DEFERRED_RESTRICTION"
    end
    if type(unit) ~= "string" or unit == "" then
      return false, "UNIT_INVALID"
    end
    local ok = pcall(container.SetUnit, container, unit)
    return ok, ok and "ASSIGNED" or "UNIT_ASSIGN_FAILED"
  end,
}

assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)

local function NewButton()
  return {secureUnit = "party1", secureType = "macro"}
end

local pack = {mufs = {tooltip = true}}
local button = NewButton()
auraByUnit.party1 = true
ns.AttachMUFIdentityTooltipForValidation(button, pack, "party1")

local container = assert(button.identityContainer)
Equal(container.addSlotCount, 1, "default mode registers exactly one native AuraSlot")
Equal(container.addGroupCount, 0, "identity carrier never registers an AuraGroup")
Equal(container.filter, "HARMFUL|RAID_PLAYER_DISPELLABLE", "default mode uses dispellable harmful filter")
Equal(container.slotKey, "identity", "identity slot key remains stable")
Check(container.slot.shown, "native provider shows the slot for an afflicted unit")

local anchor = assert(FindCall(container.slot, "SetTooltipAnchorPoint"))
Equal(anchor[2], "ANCHOR_RIGHT", "native tooltip anchors right")
Equal(anchor[3], 8, "native tooltip horizontal offset")
Equal(anchor[4], 0, "native tooltip vertical offset")
Equal(assert(FindCall(container.slot, "SetHideTooltipInCombat"))[2], false, "native tooltip remains allowed in combat")
Equal(assert(FindCall(container.slot, "EnableMouse"))[2], false, "native slot cannot capture secure MUF mouse input")
Equal(assert(FindCall(container.slot, "SetMouseMotionEnabled"))[2], false, "native slot cannot capture secure MUF mouse motion")
Equal(assert(FindCall(container.slot, "SetMouseClickEnabled"))[2], false, "native slot cannot consume clicks")
Equal(assert(FindCall(container.slot, "SetPropagateMouseClicks"))[2], true, "native slot propagates clicks")
local pass = assert(FindCall(container.slot, "SetPassThroughButtons"))
Equal(table.concat({pass[2], pass[3], pass[4], pass[5], pass[6]}, ","), "LeftButton,RightButton,MiddleButton,Button4,Button5", "all secure MUF buttons pass through")
Equal(button.secureUnit, "party1", "tooltip setup preserves secure unit state")
Equal(button.secureType, "macro", "tooltip setup preserves secure click state")

inCombat = true
ns.AttachMUFIdentityTooltipForValidation(button, pack, "party1")
Check(container.enabled and container.shown, "native tooltip carrier remains active during combat")
inCombat = false

container:RefreshNative("update")
Check(container.nativeUpdateCount > 0, "native provider owns aura updates")
auraByUnit.party1 = false
container:RefreshNative("clear")
Check(not container.slot.shown and container.nativeClearCount > 0, "native provider clears a healthy unit without a stale tooltip")
auraByUnit.party1 = true
container:RefreshNative("update")
Check(container.slot.shown, "native provider can show a later affliction")

for _, scenario in ipairs({
  {name = "DUNGEON", instanceType = "party", allowed = true},
  {name = "MYTHIC_PLUS", instanceType = "party", allowed = true},
  {name = "RAID", instanceType = "raid", allowed = true},
  {name = "OPEN_WORLD", instanceType = "none", allowed = false},
  {name = "BATTLEGROUND", instanceType = "pvp", allowed = false},
  {name = "ARENA", instanceType = "arena", allowed = false},
}) do
  instanceType = scenario.instanceType
  ns.AttachMUFIdentityTooltipForValidation(button, pack, "party1")
  if scenario.allowed then
    Check(container.enabled and container.shown, scenario.name .. " permits the native tooltip")
  else
    Check(not container.enabled and not container.shown and container.unit == "party1", scenario.name .. " disables the identity carrier while retaining its valid native binding")
  end
end

instanceType = "party"
pack.mufs.tooltip = false
ns.AttachMUFIdentityTooltipForValidation(button, pack, "party1")
Check(not container.enabled and not container.shown and container.unit == "party1", "per-environment tooltip toggle disables the carrier without a nil native assignment")
pack.mufs.tooltip = true

showAll = true
local allButton = NewButton()
ns.AttachMUFIdentityTooltipForValidation(allButton, pack, "party1")
Equal(allButton.identityContainer.addSlotCount, 1, "all-harmful mode still registers one AuraSlot")
Equal(allButton.identityContainer.filter, "HARMFUL", "optional mode widens only the native filter")
Equal(allButton.identityContainer.addGroupCount, 0, "all-harmful mode never creates an AuraGroup")
showAll = false

blocked = true
local oldUnit = allButton.identityContainer.unit
ns.AttachMUFIdentityTooltipForValidation(allButton, pack, "party2")
Equal(allButton.identityContainer.unit, oldUnit, "active restriction defers provider mutation")
blocked = false
auraByUnit.party2 = true
ns.AttachMUFIdentityTooltipForValidation(allButton, pack, "party2")
Equal(allButton.identityContainer.unit, "party2", "provider reassignment resumes after restriction")

ns.DisableMUFIdentityTooltipForValidation(allButton, true)
Check(not allButton.identityContainer.enabled and not allButton.identityContainer.shown, "roster removal disables and hides the carrier")
Equal(allButton.identityContainer.unit, "party2", "roster removal retains the last valid provider unit")
Check(allButton.identityContainer.nativeHideCount > 0, "native provider owns carrier hide lifecycle")

local reloadButton = NewButton()
ns.AttachMUFIdentityTooltipForValidation(reloadButton, pack, "party1")
Check(reloadButton.identityContainer ~= container, "reload-style reconstruction creates an independent carrier")

local source = Read("ZDecursive/MUFs.lua")
local startAt = assert(source:find("local function IdentitySlotOptions", 1, true))
local endAt = assert(source:find("local function AttachPaint", startAt, true))
local identity = source:sub(startAt, endAt - 1)
for _, forbidden in ipairs({
  "AddAuraGroup",
  "SetAuraGroup",
  "GetChildren",
  "GetRegions",
  "AuraButtonTooltip",
  "C_UnitAuras",
  "GetAuraData",
  "auraInstanceID",
  "spellId",
  "SetScript(\"OnEnter\"",
  "SetScript(\"OnLeave\"",
}) do
  Check(not identity:find(forbidden, 1, true), "identity bridge leaves opaque provider state untouched: " .. forbidden)
end

io.write("muf-native-tooltip-contract: ok\n")
