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
    error(message, 2)
  end
end

local function Same(actual, expected, message)
  local actualText = table.concat(actual, ",")
  local expectedText = table.concat(expected, ",")
  Check(actualText == expectedText, message .. ": expected " .. expectedText .. ", got " .. actualText)
end

strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local now = 100
local instanceType = "scenario"
local subgroupCount = 0
local raid = false
local exists = {}
local timers = {}
local reconcileReasons = {}

GetTime = function()
  return now
end

GetInstanceInfo = function()
  return "Follower Test", instanceType
end

IsInInstance = function()
  return instanceType ~= "none", instanceType
end

GetNumSubgroupMembers = function()
  return subgroupCount
end

GetNumGroupMembers = function()
  return 5
end

IsInGroup = function()
  return true
end

IsInRaid = function()
  return raid
end

IsActiveBattlefieldArena = function()
  return false
end

UnitExists = function(unit)
  return exists[unit] == true
end

UnitIsUnit = function(left, right)
  return left == right
end

UnitIsPlayer = function(unit)
  return unit ~= "pet" and unit:match("pet%d*$") == nil
end

UnitIsDeadOrGhost = function()
  return false
end

UnitIsConnected = function()
  return true
end

UnitName = function(unit)
  return unit
end

UnitFullName = function(unit)
  return unit, "Realm"
end

UnitGUID = function(unit)
  return "Player-1-" .. unit
end

UnitClass = function()
  return "Warrior", "WARRIOR"
end

UnitGroupRolesAssigned = function()
  return "NONE"
end

C_Timer = {
  After = function(delay, callback)
    timers[#timers + 1] = {delay = delay, callback = callback}
  end,
}

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local pack = ns.MakePack("DUNGEON")
local addon = {
  db = {profile = {lists = {priority = {}, skip = {}}}},
  RegisterChatCommand = function()
  end,
  GetAppliedEnvironmentPack = function()
    return pack
  end,
  GetAppliedEnvironment = function()
    return "DUNGEON"
  end,
  GetEditingPack = function()
    return pack
  end,
  EnsureLists = function()
  end,
}
ns.addon = addon
assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)
ns.RequestRosterReconcile = function(reason)
  reconcileReasons[#reconcileReasons + 1] = reason
end
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)

local function SetExists(tokens)
  exists = {}
  for i = 1, #tokens do
    exists[tokens[i]] = true
  end
end

local full = {"player", "pet", "party1", "partypet1", "party2", "party3", "party4"}
SetExists(full)

for _, environment in ipairs({"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP", "SOLO"}) do
  local environmentPack = ns.MakePack(environment)
  Same(ns.BuildRoster(environmentPack), full, environment .. " pack uses the same follower roster truth")
end

instanceType = "none"
subgroupCount = 0
Same(ns.BuildRoster(pack), {"player", "pet"}, "follower exit rejects stale party and party pets")
local noPartyStatus = ns.GetRosterContextStatus()
Check(noPartyStatus.kind == "NO_PARTY" and noPartyStatus.ready == true, "nonparty plus zero real group is authoritative no-party roster context")

subgroupCount = 2
Same(ns.BuildRoster(pack), full, "real open-world party survives follower exit classification")
Check(ns.GetRosterContextStatus().kind == "REAL_PARTY", "real party context is reported")

instanceType = "party"
subgroupCount = 0
Same(ns.BuildRoster(pack), full, "regular or follower dungeon retains party tokens independently of subgroup count")

SetExists({"player", "pet", "partypet2"})
Same(ns.BuildRoster(pack), {"player", "pet"}, "orphan group pet is rejected while own pet remains")

SetExists(full)
ns.BuildRoster(pack)
timers = {}
ns.BeginRosterContextTransition("GROUP_LEFT")
Check(#timers == 7, "group exit schedules the bounded follower/context retry series")
local staleTimers = timers
timers = {}
ns.BeginRosterContextTransition("ZONE_CHANGED_NEW_AREA")
Check(#timers == 7, "new context event supersedes and restarts bounded retries")
for i = 1, #staleTimers do
  staleTimers[i].callback()
end
Check(#reconcileReasons == 0, "superseded retries are generation-cancelled")
for i = 1, #timers do
  timers[i].callback()
end
Check(#reconcileReasons == 7, "active bounded retries request canonical roster reconciliation")

instanceType = nil
GetNumSubgroupMembers = function()
  return nil
end
now = 101
Same(ns.BuildRoster(pack), full, "ambiguous transition retains committed follower roster inside guard")
now = 120
Same(ns.BuildRoster(pack), {"player", "pet"}, "ambiguous transition cannot retain stale group beyond guard")

local core = assert(io.open("ZDecursive/Core.lua", "rb")):read("*a")
local mufs = assert(io.open("ZDecursive/MUFs.lua", "rb")):read("*a")
local engine = assert(io.open("ZDecursive/DetectionEngine.lua", "rb")):read("*a")
local detection = assert(io.open("ZDecursive/Detection.lua", "rb")):read("*a")
Check(core:find('RegisterEvent("GROUP_LEFT", "OnGroupRosterUpdate")', 1, true), "GROUP_LEFT is a roster trigger")
Check(core:find('RegisterEvent("GROUP_JOINED", "OnGroupRosterUpdate")', 1, true), "GROUP_JOINED is a roster trigger")
Check(core:find('RegisterOptionalEvent(self, "LFG_UPDATE", "OnEnvironmentContextChanged")', 1, true), "LFG state changes restart bounded recovery")
Check(core:find('RegisterOptionalEvent(self, "SCENARIO_UPDATE", "OnEnvironmentContextChanged")', 1, true), "scenario state changes restart bounded recovery")
Check(core:find('self:StartRosterConvergence(reason)', 1, true), "zone and difficulty transitions restart bounded convergence")
Check(core:find('self:StartRosterConvergence(event or "GROUP_ROSTER_UPDATE")', 1, true), "every roster edge starts bounded convergence")
Check(core:find('ROSTER_CONVERGENCE_DELAYS = {0.10, 0.35, 1.00, 2.00, 4.00, 7.00, 10.00}', 1, true), "roster convergence covers delayed public API settlement")
Check(not core:find('SetScript("OnUpdate"', 1, true), "roster recovery does not poll OnUpdate")
Check(mufs:find("ns.DetectionEngine:UnassignCarrier(btn)", 1, true), "unused MUFs unassign native carriers")
Check(mufs:find('return CommitClickAttributes(btn, {})', 1, true), "unused MUFs clear the complete owned secure plan, including unit")
Check(mufs:find("ClearClickAttributes(btn)", 1, true), "unused MUFs clear secure click actions")
Check(mufs:find("DisableIdentityTooltip(btn, true)", 1, true), "unused MUFs clear tooltip state")
Check(mufs:find("PaintManagedOverlays(btn, pack, nil)", 1, true), "unused MUFs clear skull, cooldown, range, and managed presentation")
Check(not engine:find("SetUnit, record.container, nil", 1, true), "native fail-close and reset never clear a carrier with SetUnit nil")
Check(not engine:find("container:SetUnit(nil)", 1, true), "native carrier lifecycle has no direct SetUnit nil call")
Check(not mufs:find("container:SetUnit(nil)", 1, true), "MUF tooltip and cleanup lifecycle has no SetUnit nil call")
Check(engine:find('result = "LOGICALLY_UNASSIGNED"', 1, true), "unused native carriers are disabled and hidden without invalid unit mutation")
Check(detection:find("function ns.SafeNativeSetUnit", 1, true), "all native unit assignment routes through one lowest-level guard")
Check(detection:find('return false, "DEFERRED_COMBAT"', 1, true), "lowest-level native unit guard rejects combat assignment")
Check(engine:find("ns.SafeNativeSetUnit(container, unit)", 1, true), "detection engine has no direct native SetUnit bypass")
Check(mufs:find("ns.SafeNativeSetUnit", 1, true), "MUF native carriers use the central SetUnit guard")

io.write("follower-exit-contract: ok\n")
