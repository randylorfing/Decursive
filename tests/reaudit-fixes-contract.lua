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

local failures = 0
local checks = 0
local function verify(label, expected, actual)
  checks = checks + 1
  local passed = expected == actual
  if not passed then
    io.write("FAIL: " .. label .. " | expected=" .. tostring(expected) .. " actual=" .. tostring(actual) .. "\n")
  end
  if not passed then failures = failures + 1 end
end
local function upvalue(fn, target)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == target then return value end
  end
  error("Missing audit seam: " .. target)
end

local knownCure = true
local context = "none"
local raid = false
local groupSize = 0
local soulCount = 1
local bandageCount = 0
strtrim = function(value) return value:match("^%s*(.-)%s*$") end
InCombatLockdown = function() return false end
issecretvalue = function() return false end
canaccessvalue = function() return true end
UnitClass = function() if knownCure then return "Mage", "MAGE" end return "Warrior", "WARRIOR" end
UnitRace = function() return "Human", "Human" end
UnitIsUnit = function(a, b) return a == b or (a == "raid1" and b == "player") end
UnitIsDeadOrGhost = function() return false end
UnitIsPlayer = function() return true end
UnitIsConnected = function() return true end
UnitExists = function(unit) return unit == "player" or (raid and unit:match("^raid%d+$") ~= nil) end
IsInInstance = function() return context ~= "none", context end
GetInstanceInfo = function() return "Audit Instance", context end
IsInRaid = function() return raid end
GetNumGroupMembers = function() return groupSize end
GetNumSubgroupMembers = function() return 0 end
IsActiveBattlefieldArena = function() return context == "arena" end
C_PvP = {IsArena = function() return context == "arena" end}
GetTime = function() return 100 end
Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}, BagIndex = {Backpack = 0}}
AuraUtil = {AuraFilters = {Dispellable = "DISPELLABLE", RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE"}}
C_SpellBook = {
  IsSpellInSpellBook = function(id) return knownCure and id == 475 end,
  IsSpellKnown = function(id) return knownCure and id == 475 end,
}
C_Spell = {
  GetOverrideSpell = function(id) return id end,
  GetSpellName = function(id) return id == 475 and "Remove Curse" or "Soul Link" end,
}
C_Item = {
  GetItemCount = function(id) return id == 269586 and soulCount or bandageCount end,
  GetItemSpell = function() return "Bandage", 212640 end,
  IsUsableItem = function() return true end,
}
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and bandageCount > 0 and 1 or 0 end,
  GetContainerItemInfo = function() return {itemID = 133940} end,
}
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
local pack = ns.MakePack("PVP")
pack.sorting.includePets = false
pack.mouse.button5 = "CURE"
ns.addon = {GetAppliedEnvironmentPack = function() return pack end}

local function modelContains(model, needle)
  for i = 1, #(model and model.rows or {}) do
    local text = model.rows[i].macroText
    if type(text) == "string" and text:find(needle, 1, true) then
      return true
    end
  end
  return false
end

-- Runtime regressions for the four defects confirmed by the second audit.
local install = upvalue(ns.LayoutMUFs, "ApplyClickAttributes")
local function button()
  local result = {attributes = {}}
  function result:SetAttribute(key, value)
    assert(not InCombatLockdown(), "secure attributes changed during combat")
    self.attributes[key] = value
  end
  return result
end
local function hasCure(model)
  for _, row in ipairs(model.rows) do
    if row.spellId == 475 then return true end
  end
  return false
end
local function hasSoulMacro(btn)
  local macro = btn.attributes["*macrotext1"]
  return type(macro) == "string" and macro:find("269586", 1, true) ~= nil
end

-- A: Reserve left click; the only known cure must move to a free gesture.
context = "pvp"
pack.mouse.left = "CURE"
ns.InvalidateDetection()
verify("control: default AUTO retains Remove Curse", true, hasCure(ns.RebuildClickModel(pack)))
pack.mouse.left = "TARGET"
ns.InvalidateDetection()
local configured = ns.RebuildClickModel(pack)
local mageButton = button()
assert(install(mageButton, pack, "party1"))
verify("control: selected Target installed", "target", mageButton.attributes["*type1"])
verify("A: AUTO must retain available Remove Curse", true, hasCure(configured))
verify("A: free right click receives primary cure", "macro", mageButton.attributes["*type2"])

-- B: A no-cure character can resurrect using Soul Link, with/without bandages.
knownCure = false
pack.mouse.left = "CURE"
pack.mouse.button5 = "CURE"
bandageCount = 0
ns.InvalidateDetection()
local noBandage = button()
assert(install(noBandage, pack, "party1"))
verify("control: Soul Link works before acquiring bandage", true, hasSoulMacro(noBandage))
bandageCount = 1
ns.InvalidateDetection()
local withBandage = button()
assert(install(withBandage, pack, "party1"))
verify("control: bandage installed on Button5", "macro", withBandage.attributes["*type5"])
verify("B: acquiring bandage must retain left-click Soul Link", true, hasSoulMacro(withBandage))

-- C: The identity matcher rejects a stale GUID, but AddUnit rejects its replacement.
UnitExists = function() return true end
UnitFullName = function() return "Auditname", "RealmOne" end
UnitName = function() return "Auditname" end
UnitGUID = function() return "Player-1-B" end
ns.addon.db = {profile = {lists = {priority = {}, skip = {
  {kind = "id", name = "Auditname-RealmOne", guid = "Player-1-A"},
}}}}
ns.Notify = function() end
assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)
verify("control: stale GUID must not skip replacement character", false, ns.IsUnitSkipped("party1"))
local added, reason = ns.AddUnitToList("skip", "party1")
verify("C: adding current character must succeed", true, added)
verify("C: successful add has no error", nil, reason)
verify("C: added current character must be skipped", true, ns.IsUnitSkipped("party1"))

-- D: An unrelated inventory event in combat must preserve the installed rez state.
bandageCount = 0
ns.InvalidateDetection()
local beforeCombat = button()
assert(install(beforeCombat, pack, "party1"))
local oldModel = ns.RebuildClickModel(pack)
local _, _, soulBefore = ns.GetSmartRezActions(pack)
verify("control: Soul Link available before combat", true, soulBefore)
verify("control: Soul Link macro installed before combat", true, hasSoulMacro(beforeCombat))
local callbacks = {}
C_Timer = {After = function(_, callback) callbacks[#callbacks + 1] = callback end}
assert(loadfile("ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
InCombatLockdown = function() return true end
ns.DetectionEngine:OnEvent("BAG_UPDATE_DELAYED")
assert(#callbacks == 1, "inventory refresh must be scheduled")
table.remove(callbacks, 1)()
local _, _, soulAfter = ns.GetSmartRezActions(pack)
verify("control: secure model remains unchanged in combat", true, oldModel == ns.RebuildClickModel(pack))
verify("control: installed Soul Link macro is unchanged", true, hasSoulMacro(beforeCombat))
verify("D: unrelated combat bag event must retain Soul Link availability", true, soulAfter)

-- The real engine drives a click consumer through removal and acquisition.
-- Native aura carriers are outside this contract, so every bank reports zero.
local engine = ns.DetectionEngine
engine:RegisterConsumer("MUFs", function()
  local installed = install(beforeCombat, pack, "party1")
  return installed, installed and "SUCCESS" or "DEFERRED_COMBAT", 0
end)
for _, name in ipairs({"Alerts", "LiveList"}) do
  engine:RegisterConsumer(name, function() return true, "SUCCESS", 0 end)
end
soulCount = 0
callbacks = {}
engine:OnEvent("ITEM_COUNT_CHANGED", 269586)
engine:OnEvent("BAG_UPDATE_DELAYED")
verify("combat inventory burst schedules one refresh", 1, #callbacks)
table.remove(callbacks, 1)()
local _, _, removedInCombat = ns.GetSmartRezActions(pack)
verify("item removal retains installed combat availability until recovery", true, removedInCombat)
verify("removal cannot mutate the combat macro", true, hasSoulMacro(beforeCombat))
InCombatLockdown = function() return false end
engine:OnEvent("PLAYER_REGEN_ENABLED")
local _, _, removedAfterCombat = ns.GetSmartRezActions(pack)
verify("regen recomputes removed Soul Link availability", false, removedAfterCombat)
verify("regen removes the obsolete Soul Link macro", false, hasSoulMacro(beforeCombat))
verify("regen finishes the pending transaction", false, engine.pending)

InCombatLockdown = function() return true end
engine:OnEvent("PLAYER_REGEN_DISABLED")
soulCount = 1
callbacks = {}
engine:OnEvent("BAG_UPDATE_DELAYED")
table.remove(callbacks, 1)()
local _, _, acquiredInCombat = ns.GetSmartRezActions(pack)
verify("combat acquisition retains the previous unavailable snapshot", false, acquiredInCombat)
verify("combat acquisition cannot install a new macro", false, hasSoulMacro(beforeCombat))
InCombatLockdown = function() return false end
engine:OnEvent("PLAYER_REGEN_ENABLED")
local _, _, acquiredAfterCombat = ns.GetSmartRezActions(pack)
verify("regen discovers acquired Soul Link", true, acquiredAfterCombat)
verify("regen installs acquired Soul Link", true, hasSoulMacro(beforeCombat))

-- Exercise every left/right configured-action combination with 1-3 cures.
local realKnownCures = ns.GetKnownCures
local actions = {
  {spellId = 475, name = "Remove Curse", types = {"curse"}},
  {spellId = 4987, name = "Cleanse", types = {"magic", "poison", "disease"}},
  {spellId = 213644, name = "Cleanse Toxins", types = {"poison", "disease"}},
  {spellId = 527, name = "Purify", types = {"magic", "disease"}},
}
local actionCount = 1
ns.GetKnownCures = function()
  local result = {}
  for i = 1, actionCount do result[i] = actions[i] end
  return result
end
local secureActions = {TARGET = "target", FOCUS = "focus", ASSIST = "assist"}
local clickButton = button()
for count = 1, 3 do
  actionCount = count
  for _, left in ipairs({"CURE", "TARGET", "FOCUS", "ASSIST"}) do
    for _, right in ipairs({"CURE", "TARGET", "FOCUS", "ASSIST"}) do
      pack.cure.mode = "AUTO"
      pack.mouse.left, pack.mouse.right = left, right
      ns.InvalidateDetection()
      local model = ns.RebuildClickModel(pack)
      assert(install(clickButton, pack, "party1"))
      local label = "AUTO " .. count .. " " .. left .. "/" .. right
      local found, bindings = {}, {}
      for _, row in ipairs(model.rows) do
        verify(label .. " has no duplicate gesture", nil, bindings[row.binding])
        bindings[row.binding] = true
        if row.priority then
          found[row.priority] = (found[row.priority] or 0) + 1
          verify(label .. " preserves priority " .. row.priority, actions[row.priority].spellId, row.spellId)
          verify(label .. " installs cure type", "macro", clickButton.attributes[row.binding:format("type")])
          verify(label .. " installs cure macro", true,
            clickButton.attributes[row.binding:format("macrotext")]:find(row.spellName, 1, true) ~= nil)
          verify(label .. " click tracking retains priority", row.priority, clickButton.cureRows[row.binding].priority)
        end
      end
      for priority = 1, count do
        verify(label .. " keeps cure " .. priority .. " exactly once", 1, found[priority])
      end
      if secureActions[left] then verify(label .. " keeps left action", secureActions[left], clickButton.attributes["*type1"]) end
      if secureActions[right] then verify(label .. " keeps right action", secureActions[right], clickButton.attributes["*type2"]) end
      verify(label .. " keeps middle Target", "target", clickButton.attributes["*type3"])
      verify(label .. " keeps Ctrl+Middle Focus", "focus", clickButton.attributes["ctrl-type3"])
    end
  end
end
pack.mouse.left, pack.mouse.right = "TARGET", "FOCUS"
ns.InvalidateDetection()
assert(install(clickButton, pack, "party1"))
verify("both reserved: primary moves to Ctrl+Left", 1, clickButton.cureRows["ctrl-%s1"].priority)
verify("both reserved: secondary moves to Ctrl+Right", 2, clickButton.cureRows["ctrl-%s2"].priority)
verify("both reserved: tertiary moves to Shift+Left", 3, clickButton.cureRows["shift-%s1"].priority)
local status = ns.GetResolvedClickStatus()
local displayed = {}
for _, mapping in ipairs(status.mappings) do displayed[mapping.gesture] = mapping.action end
verify("status displays Ctrl+Right cure", "Cleanse", displayed["Ctrl+Right"])
verify("status displays Shift+Left cure", "Cleanse Toxins", displayed["Shift+Left"])

pack.mouse.left, pack.mouse.right = "CURE", "CURE"
actionCount = 4
ns.InvalidateDetection()
assert(install(clickButton, pack, "party1"))
verify("default primary remains on left", 1, clickButton.cureRows["*%s1"].priority)
verify("default secondary remains on right", 2, clickButton.cureRows["*%s2"].priority)
verify("default tertiary remains on Ctrl+Left", 3, clickButton.cureRows["ctrl-%s1"].priority)
verify("restoring defaults clears Ctrl+Right fallback", nil, clickButton.attributes["ctrl-type2"])
verify("restoring defaults clears Shift+Left fallback", nil, clickButton.attributes["shift-type1"])
local assignedCures = 0
for _ in pairs(clickButton.cureRows) do assignedCures = assignedCures + 1 end
verify("AUTO retains its three-cure limit", 3, assignedCures)
ns.GetKnownCures = realKnownCures

-- Bandages must not consume resurrection fallback in either assignment mode.
for _, mode in ipairs({"AUTO", "MANUAL"}) do
  pack.cure.mode, pack.cure.manual = mode, {}
  pack.mouse.left, pack.mouse.right, pack.mouse.button5 = "CURE", "CURE", "CURE"
  pack.mufs.soulLinkFallback = true
  soulCount = 1
  local rezButton = button()
  for _, count in ipairs({1, 0, 1}) do
    bandageCount = count
    ns.InvalidateDetection()
    assert(install(rezButton, pack, "party1"))
    verify(mode .. " keeps resurrection across bandage changes", true, hasSoulMacro(rezButton))
    verify(mode .. " reflects carried bandage", count > 0, rezButton.attributes["*type5"] == "macro")
  end
  soulCount = 0
  ns.InvalidateDetection()
  assert(install(rezButton, pack, "party1"))
  verify(mode .. " does not invent unavailable Soul Link", false, hasSoulMacro(rezButton))
  soulCount = 1
  pack.mufs.soulLinkFallback = false
  ns.InvalidateDetection()
  assert(install(rezButton, pack, "party1"))
  verify(mode .. " respects disabled Soul Link", false, hasSoulMacro(rezButton))
  pack.mufs.soulLinkFallback = true
  pack.mouse.left = "TARGET"
  ns.InvalidateDetection()
  assert(install(rezButton, pack, "party1"))
  verify(mode .. " does not overwrite reserved left Target", "target", rezButton.attributes["*type1"])
end

-- Identity equality must agree across add, remove, and cross-list operations.
local stale = {kind = "id", name = "Auditname-RealmOne", guid = "Player-1-A"}
local current = {kind = "id", name = "Auditname-RealmOne", guid = "Player-1-B"}
local lists = {priority = {}, skip = {stale}}
ns.addon.db.profile.lists = lists
verify("priority accepts distinct GUID with same name", true, ns.AddListEntry("priority", current))
verify("cross-list add retains the other GUID", stale, lists.skip[1])
verify("moving current identity to skip succeeds", true, ns.AddListEntry("skip", current))
verify("cross-list move removes current GUID from priority", 0, #lists.priority)
verify("skip keeps both GUIDs", 2, #lists.skip)
verify("removing current unit succeeds", true, ns.RemoveUnitFromList("skip", "party1"))
verify("remove only removes the matching GUID", 1, #lists.skip)
verify("stale identity survives other GUID removal", stale, lists.skip[1])
local duplicate, duplicateReason = ns.AddListEntry("skip", {kind = "id", name = "Renamed-RealmOne", guid = stale.guid})
verify("same GUID with changed name remains duplicate", false, duplicate)
verify("same GUID duplicate reports exists", "exists", duplicateReason)
verify("GUID-only removal still works", true, ns.RemoveListEntry("skip", {kind = "id", guid = stale.guid}))
verify("GUID-only removal leaves empty list", 0, #lists.skip)
verify("name-only entry can be added", true, ns.AddListEntry("skip", {kind = "id", name = current.name}))
verify("name-only entry matches current character", true, ns.IsUnitSkipped("party1"))
verify("name-only duplicate behavior remains", false, ns.AddListEntry("skip", current))
verify("empty GUID behaves as missing", false, ns.AddListEntry("skip", {kind = "id", name = current.name, guid = ""}))
verify("another realm remains a different name", true, ns.AddListEntry("skip", {kind = "id", name = "Auditname-RealmTwo"}))
lists.skip = {{kind = "id", player = true, guid = "Player-1-A"}}
verify("player sentinel retains its stable meaning", false, ns.AddListEntry("skip", {kind = "id", player = true, guid = "Player-1-B"}))

if failures > 0 then error("Re-audit regression failures: " .. failures, 0) end
io.write("reaudit-fixes-contract: ok (" .. checks .. " assertions)\n")
