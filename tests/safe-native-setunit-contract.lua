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
    error((message or "values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
  end
end

local combat = false
local restricted = false
local secret = {}
local calls = 0
local restrictionQueries = {}
local restrictionAPIState = {[1] = 0, [2] = 1, [3] = 1, [4] = 1}

Enum = {
  AddOnRestrictionType = {Combat = 1, Encounter = 2, ChallengeMode = 3, Map = 4},
  AddOnRestrictionState = {Inactive = 0, Active = 1, Activating = 2},
}

C_RestrictedActions = {
  GetAddOnRestrictionState = function(restrictionType)
    restrictionQueries[#restrictionQueries + 1] = restrictionType
    return restrictionAPIState[restrictionType]
  end,
}

InCombatLockdown = function()
  return combat
end

issecretvalue = function(value)
  return rawequal(value, secret)
end

canaccessvalue = function(value)
  return not rawequal(value, secret)
end

local ns = {}
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
Check(not ns.RefreshAddonRestrictionState("COLD"), "cold refresh does not enumerate unobserved restriction types")
Equal(#restrictionQueries, 0, "all-enum restriction polling is forbidden")

local container = {}
function container:SetUnit(unit)
  Check(rawequal(self, container), "native SetUnit receives the container as self")
  Check(type(unit) == "string" and unit ~= "", "native SetUnit receives a valid public token")
  calls = calls + 1
  self.unit = unit
end

local ok, status = ns.SafeNativeSetUnit(container, "player")
Check(ok, "dot-call wrapper assignment succeeds")
Equal(status, "ASSIGNED", "dot-call wrapper status")
Equal(calls, 1, "dot-call wrapper invokes native SetUnit once")
Equal(container.unit, "player", "dot-call wrapper preserves argument order")

ok, status = ns:SafeNativeSetUnit(container, "party1")
Check(not ok, "accidental colon-call fails closed")
Equal(status, "UNIT_INVALID", "accidental colon-call cannot shift arguments into native SetUnit")
Equal(calls, 1, "accidental colon-call never reaches native SetUnit")

combat = true
ok, status = ns.SafeNativeSetUnit(container, "party1")
Check(not ok and status == "DEFERRED_COMBAT", "combat assignment is explicitly deferred")
Equal(calls, 1, "combat assignment never reaches native SetUnit")
combat = false

restricted = true
ns.RememberRestrictionState(Enum.AddOnRestrictionType.Encounter, Enum.AddOnRestrictionState.Active)
Check(ns.HasActiveAddonRestriction(), "observed restriction remains available to scoped consumers")
ok, status = ns.SafeNativeSetUnit(container, "party1")
Check(ok and status == "ASSIGNED", "addon restriction categories do not substitute for combat lockdown")
Equal(calls, 2, "out-of-combat native assignment proceeds despite an addon restriction category")
restrictionAPIState[Enum.AddOnRestrictionType.Encounter] = Enum.AddOnRestrictionState.Inactive
Check(ns.RefreshAddonRestrictionState("SETTLED"), "settled poll refreshes an observed restriction type")
Equal(#restrictionQueries, 1, "settled poll queries only the observed restriction type")
Equal(restrictionQueries[1], Enum.AddOnRestrictionType.Encounter, "unobserved challenge and map types are never imported")
Check(not ns.HasActiveAddonRestriction(), "observed active restriction clears from the public API")
restricted = false

ok, status = ns.SafeNativeSetUnit(container, secret)
Check(not ok and status == "UNIT_INVALID", "secret unit token fails closed")
ok, status = ns.SafeNativeSetUnit(container, "")
Check(not ok and status == "UNIT_INVALID", "empty unit token fails closed")
Equal(calls, 2, "invalid tokens never reach native SetUnit")

local throwing = {}
function throwing:SetUnit()
  error("injected native failure")
end
ok, status = ns.SafeNativeSetUnit(throwing, "player")
Check(not ok and status == "UNIT_ASSIGN_FAILED", "native SetUnit exception becomes an explicit failure")

io.write("safe-native-setunit-contract: ok\n")
