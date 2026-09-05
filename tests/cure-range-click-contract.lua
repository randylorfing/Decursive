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

-- Real installed bindings and the exact PreClick callback attribute range
-- warnings only to a publicly identified living cure target.
local function Read(path)
  local file = assert(io.open("ZDecursive/" .. path, "rb")); local text = file:read("*a"); file:close(); return text
end
local combat, shift, now = false, false, 100
local secret = setmetatable({}, {__eq = function() error("secret comparison") end, __tostring = function() error("secret serialization") end})
local range, dead, friendly, connected, exists = false, false, true, true, true
local queries, warningCount, sounds, writes = {}, 0, 0, 0
local warningEnabled, soundEnabled, mouseover = true, true, "party1"
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return shift end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
GetTime = function() return now end
UnitExists = function() return exists end
UnitCanAssist = function() return friendly end
UnitIsConnected = function() return connected end
UnitIsDeadOrGhost = function() return dead end
UnitIsUnit = function(left, right) return left == "mouseover" and right == mouseover end
C_Timer, C_Item, C_Container = nil, nil, nil
C_Spell = {IsSpellInRange = function(spellId, unit)
  queries[#queries + 1] = {spellId = spellId, unit = unit}
  return range
end}
local ns = {}
assert(load(Read("Defaults.lua")))("ZDecursive", ns)
assert(load(Read("ClickBindings.lua")))("ZDecursive", ns)
assert(load(Read("Detection.lua")))("ZDecursive", ns)
local pack = ns.MakePack("DUNGEON")
ns.addon = {GetAppliedEnvironmentPack = function() return pack end, GetAppliedEnvironment = function() return "DUNGEON" end}
ns.GetKnownCures = function() return {
  {spellId = 101, baseId = 11, name = "Magic cure", types = {"magic"}},
  {spellId = 102, baseId = 12, name = "Poison cure", types = {"poison"}},
  {spellId = 103, itemId = 900, name = "Item cure", types = {"disease"}},
} end
ns.GetSmartRezActions = function() return nil, "Resurrection", true, false, 248486, 777 end
ns.GetPrimaryCure = function() return "Unrelated primary", 555 end
ns.SpellRangeState = function() error("warning must not use generic range") end
ns.PlayCureFailureSound = function()
  if not soundEnabled then return false end
  sounds = sounds + 1
  return true
end
ns.NotifyCureOutOfRange = function()
  if not warningEnabled then return false, false end
  warningCount = warningCount + 1
  return true, ns.PlayCureFailureSound()
end
local soulUnit = "previous"
ns.BeginSoulLinkAttempt = function(unit) soulUnit = unit end
local source = Read("MUFs.lua")
local runtime = assert(load(source .. [[
return {install=ApplyClickAttributes, gate=ShouldBeginSoulLinkAttempt, beginCure=BeginCureAttempt,
result=OnPlayerSpellResult, pool=pool}
]]))("ZDecursive", ns)
local button = {unit = "party1", assigned = true, attributes = {}}
function button:SetAttribute(key, value)
  assert(not combat, "range observation must not mutate protected attributes")
  writes = writes + 1
  self.attributes[key] = value
end
function button:SetScript(name, handler) self[name] = handler end
assert(ns.SetClickBindingOverride(pack, "shift-left", "CURE2"))
assert(ns.SetClickBindingOverride(pack, "right", "TARGET"))
assert(runtime.install(button, pack, button.unit))
local first = assert(source:find('  btn:SetScript("PreClick", function(self, button)', 1, true))
local last = assert(source:find("  local engine = ns.DetectionEngine", first, true))
local env = setmetatable({btn = button, ns = ns, ShouldBeginSoulLinkAttempt = runtime.gate, BeginCureAttempt = runtime.beginCure}, {__index = _G})
assert(load(source:sub(first, last - 1), "real-MUF-PreClick", "t", env))()
runtime.pool[1] = button
local function Click(which)
  now = now + 2
  button.PreClick(button, which or "LeftButton")
end
local function Failure(spellId)
  runtime.result("UNIT_SPELLCAST_FAILED", "player", spellId or 101)
end
combat = true
local initialWrites = writes
Click()
assert(warningCount == 1 and sounds == 1 and soulUnit == nil, "living dispel warns and clears prior Soul Link attribution")
assert(queries[#queries].spellId == 101 and queries[#queries].unit == "party1", "warning uses the actual installed cure, not primary spell 555")
Failure()
assert(sounds == 1, "matching spell failure does not duplicate the warning sound")
shift = true
Click()
assert(warningCount == 2 and queries[#queries].spellId == 102, "exact modifier override uses its own spell's range")
Failure(101)
assert(sounds == 2, "unrelated result cannot consume the modifier cure attribution")
Failure(102)
assert(sounds == 2)
shift = false
for _, state in ipairs({true, secret, "UNKNOWN"}) do
  if state == "UNKNOWN" then range = nil else range = state end
  local before = warningCount
  Click()
  assert(warningCount == before, "in-range, unknown, and inaccessible values do not warn")
end
range = false
for _, life in ipairs({true, secret}) do
  dead = life
  local before, reads = warningCount, #queries
  Click()
  assert(warningCount == before and #queries == reads, "dead or unknown-life smart-rez clicks are not treated as dispels")
end
dead = false
for _, state in ipairs({"enemy", "offline", "absent"}) do
  friendly, connected, exists = state ~= "enemy", state ~= "offline", state ~= "absent"
  local before = warningCount
  Click()
  assert(warningCount == before, "invalid friendly target does not produce cure warning")
end
friendly, connected, exists = true, true, true
local before = warningCount
Click("RightButton")
assert(warningCount == before and soulUnit == nil, "utility right-click does not warn")
local afterUtility = sounds
Failure()
assert(afterUtility == sounds, "utility click supersedes pending cure attribution")
combat = false
assert(ns.SetClickBindingOverride(pack, "shift-left", "CURE3"))
assert(runtime.install(button, pack, button.unit))
combat, shift = true, true
before = warningCount
Click()
assert(warningCount == before, "item-origin cure row cannot generate a spell-range warning")
shift = false
combat = false
assert(ns.SetClickBindingOverride(pack, "right", "CURE2"))
assert(runtime.install(button, pack, button.unit))
combat = true
Click("RightButton")
assert(warningCount == before + 1 and queries[#queries].spellId == 102, "a deliberately assigned right-click cure remains supported")

now = now + 2
soulUnit = "stale rez"
before = warningCount
ns.BeginKeyboardCureAttempt({index = 1, spellId = 101, baseId = 11, actionKey = "spell:101"})
assert(warningCount == before + 1 and soulUnit == nil, "resolved friendly mouseover keyboard cure also warns and supersedes Soul Link")
local played = sounds
Failure(11)
assert(sounds == played, "base spell alias respects the same-attempt sound guard")
mouseover = "unmapped"
before = warningCount
ns.BeginKeyboardCureAttempt({index = 1, spellId = 101, actionKey = "spell:101"})
assert(warningCount == before, "unresolved keyboard target cannot borrow another MUF's range")
mouseover = "party1"
ns.BeginKeyboardCureAttempt({index = 1, spellId = 103, itemId = 900, actionKey = "item:900"})
assert(warningCount == before, "keyboard item action does not warn")
warningEnabled = false
Click()
assert(warningCount == before, "warning toggle can disable notification")
played = sounds
Failure()
assert(sounds == played + 1, "a warning that played no sound cannot suppress the ordinary failure sound")
warningEnabled, soundEnabled = true, false
Click()
played = sounds
Failure()
assert(sounds == played, "sound-disabled warning and failure remain silent")
assert(writes > initialWrites, "fixture changed bindings only during explicit out-of-combat setup")
initialWrites = writes
Click()
ns.BeginKeyboardCureAttempt({index = 1, spellId = 101, actionKey = "spell:101"})
assert(writes == initialWrites, "click and keyboard range checks perform no combat secure writes")
io.write("cure-range-click-contract: ok\n")
