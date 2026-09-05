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

-- Current inventory-backed actions: both crafted qualities and real use spells.
local ns = {}
local combat = false
local secret = {}
local counts = {[269586] = 0, [248486] = 0}
local spells = {[269586] = 777001, [248486] = 777002}
local known = {}
local requests = 0
InCombatLockdown = function() return combat end
issecretvalue = function(v) return v == secret end
canaccessvalue = function(v) return v ~= secret end
UnitClass = function() return "Mage", "MAGE" end
UnitRace = function() return "Human", "Human" end
Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}}
AuraUtil = {AuraFilters = {Dispellable = "DISPELLABLE", RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE"}}
C_SpellBook = {IsSpellInSpellBook = function(id) return known[id] == true end,
  IsSpellKnown = function(id) return known[id] == true end}
C_Spell = {GetOverrideSpell = function(id) return id end, GetSpellName = function(id) return "Spell" .. id end}
C_Item = {
  GetItemCount = function(id, bank, charges, reagent, account)
    assert(not bank and not charges and not reagent and not account, "carried stacks only")
    if counts[id] == "throw" then error("temporarily unavailable") end
    return counts[id]
  end,
  GetItemSpell = function(id) if spells[id] then return "Use item " .. id, spells[id] end end,
  RequestLoadItemDataByID = function(id)
    assert(not combat, "item data request stays out of combat")
    requests = requests + 1
  end,
}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
local pack = ns.MakePack("PVP")
local function State()
  ns.InvalidateDetection()
  return ns.GetSoulLinkState(pack)
end
assert(ns.IsSoulLinkItemID(269586) and ns.IsSoulLinkItemID(248486) and not ns.IsSoulLinkItemID(secret))
assert(State().count == 0 and State().itemId == nil, "known empty inventory has no item action")
counts[248486] = 3
local state = State()
assert(state.itemId == 248486 and state.count == 3 and state.available, "lower quality works by itself")
assert(state.spellId == 777002, "use spell is return two of selected item's GetItemSpell")
local _, _, battleItem, normalItem, itemId, spellId = ns.GetSmartRezActions(pack)
assert(battleItem and normalItem and itemId == 248486 and spellId == 777002)
counts[269586] = 2
state = State()
assert(state.itemId == 269586 and state.selectedCount == 2 and state.count == 5, "higher quality wins deterministically")
known[20484] = true
state = State()
local battleRez, normalRez, combatItem, outItem = ns.GetSmartRezActions(pack)
assert(battleRez and normalRez and not combatItem and not outItem, "native resurrection takes priority")
known[20484] = nil
known[2006] = true
State()
battleRez, normalRez, combatItem, outItem = ns.GetSmartRezActions(pack)
assert(not battleRez and normalRez and combatItem and not outItem, "ordinary resurrection wins outside combat")
known[2006] = nil
State()
ns.GetSmartRezActions(pack)
combat = true
counts[269586] = 0
ns.InvalidateDetection()
_, _, _, _, itemId = ns.GetSmartRezActions(pack)
assert(itemId == 269586, "combat cache retains actual installed item until safe rebuild")
combat = false
_, _, _, _, itemId = ns.GetSmartRezActions(pack)
assert(itemId == 248486, "safe rebuild selects remaining lower quality")
for _, unavailable in ipairs({secret, "throw", 0/0, -1, 1.5}) do
  counts[269586] = unavailable
  state = State()
  assert(state.count == nil and state.inventoryKnown == false and state.itemId == nil,
    "unknown preferred count is not absence and cannot silently select lower quality")
  assert(ns.GetDetectionItemActionSignature() == nil, "invalid counts disable signature optimization")
end
counts[269586] = 0
spells[248486] = nil
state = State()
assert(state.itemId == 248486 and state.spellId == nil and requests > 0, "uncached use spell remains unknown and requests item data")
local before = ns.GetDetectionItemActionSignature()
spells[248486] = 777002
assert(ns.GetDetectionItemActionSignature() ~= before, "item data readiness invalidates same-count signature")
state = State()
local other = ns.MakePack("PVP")
other.mufs.soulLinkFallback = false
assert(not ns.GetSoulLinkState(other).enabled, "different environment toggle is part of detection cache identity")
assert(ns.GetSoulLinkState(pack).enabled, "returning to applied pack restores its toggle")
ns.addon = {GetAppliedEnvironmentPack = function() return pack end}
local file = assert(io.open("ZDecursive/MUFs.lua", "rb"))
local mufsSource = file:read("*a")
file:close()
local range = assert(load(mufsSource .. "\nreturn SoulLinkRangeValue"))("ZDecursive", ns)
local calledSpell, rangeCalls = nil, 0
C_Spell.IsSpellInRange = function(id)
  calledSpell, rangeCalls = id, rangeCalls + 1
  return secret
end
local value, available = range("party1")
assert(value == secret and available and calledSpell == 777002, "actual use-spell range stays opaque for native boolean painting")
C_Spell.IsSpellInRange = function() return nil end
value, available = range("party1")
assert(value == nil and not available, "nullable range is unknown, not out of range")
spells[248486] = nil
State()
local previousCalls = rangeCalls
value, available = range("party1")
assert(value == nil and not available and rangeCalls == previousCalls, "unknown use spell never substitutes another item's range")
print("soul-link-items-contract: ok")
