--[[
    ZDecursive, based on Decursive, Copyright (C) 2006-2026 John Wellesz.
    ZDecursive rebuild and maintenance, Copyright (C) 2026 Randy Lorfing.
    Licensed under the GNU General Public License version 3 or later.
    Distributed without warranty. See ../LICENSE.
--]]
-- Configuration only: no protected attributes or aura data are read here.
local _, ns = ...

ns.ClickBindingModifiers = {
  NONE = "None", CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt",
  CTRLSHIFT = "Ctrl+Shift", ALTCTRL = "Alt+Ctrl", ALTSHIFT = "Alt+Shift",
  ALTCTRLSHIFT = "Alt+Ctrl+Shift",
}
local modifiers = {
  {"NONE", "", "*"}, {"CTRL", "ctrl-", "ctrl-"},
  {"SHIFT", "shift-", "shift-"}, {"ALT", "alt-", "alt-"},
  {"CTRLSHIFT", "ctrl-shift-", "ctrl-shift-"},
  {"ALTCTRL", "alt-ctrl-", "alt-ctrl-"},
  {"ALTSHIFT", "alt-shift-", "alt-shift-"},
  {"ALTCTRLSHIFT", "alt-ctrl-shift-", "alt-ctrl-shift-"},
}
local buttons = {"left", "right", "middle", "button4", "button5"}
ns.ClickBindingGestures = {}
local byKey = {}
local byModifier = {}
for _, modifier in ipairs(modifiers) do
  byModifier[modifier[1]] = {}
  for index, button in ipairs(buttons) do
    local key = modifier[2] .. button
    local row = {key = key, binding = modifier[3] .. "%s" .. index}
    byKey[key] = row
    byModifier[modifier[1]][button] = key
    ns.ClickBindingGestures[#ns.ClickBindingGestures + 1] = row
  end
end

function ns.ClickBindingKey(modifier, button)
  local group = byModifier[modifier]
  return group and group[button]
end

local function ValidAction(value)
  return type(value) == "string" and (value == "NONE" or value == "TARGET"
    or value == "FOCUS" or value == "ASSIST" or value:match("^CURE[123]$")
    or value:match("^spell:%d+$") or value:match("^item:%d+$"))
end

function ns.GetClickBindingOverride(pack, key)
  local cure = pack and pack.cure
  local bindings = type(cure) == "table" and cure.clickBindings
  local value = type(bindings) == "table" and bindings[key]
  if byKey[key] and ValidAction(value) then return value end
  return nil
end

function ns.SetClickBindingOverride(pack, key, value)
  if InCombatLockdown and InCombatLockdown() then return false, "combat" end
  if not byKey[key] or (value ~= "DEFAULT" and not ValidAction(value)) then
    return false, "binding"
  end
  if type(pack) ~= "table" or type(pack.cure) ~= "table" then return false, "pack" end
  if type(pack.cure.clickBindings) ~= "table" then pack.cure.clickBindings = {} end
  pack.cure.clickBindings[key] = value ~= "DEFAULT" and value or nil
  if ns.InvalidateClickModel then ns.InvalidateClickModel("CLICK_BINDING") end
  return true
end

if ns.DiagnosticModuleLoaded then ns.DiagnosticModuleLoaded("ClickBindings") end
