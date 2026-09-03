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

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function Same(actual, expected, label)
  local actualText = table.concat(actual, ",")
  local expectedText = table.concat(expected, ",")
  Check(actualText == expectedText, label .. ": expected " .. expectedText .. ", got " .. actualText)
end

strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local now = 100
local groupSize = 5
local subgroupSize = 4
local raidMode = false
local instanceType = "party"
local exists = {}
local dead = {}
local connected = {}
local names = {}
local roles = {}

GetTime = function()
  return now
end

GetNumGroupMembers = function()
  return groupSize
end

GetNumSubgroupMembers = function()
  return subgroupSize
end

IsInGroup = function()
  return true
end

IsInRaid = function()
  return raidMode
end

IsInInstance = function()
  return instanceType ~= "none", instanceType
end

GetInstanceInfo = function()
  return "Test", instanceType
end

IsActiveBattlefieldArena = function()
  return false
end

UnitExists = function(unit)
  return exists[unit] == true
end

UnitIsUnit = function(a, b)
  return a == b
end

UnitIsPlayer = function(unit)
  return unit ~= "pet" and unit:match("pet%d*$") == nil
end

UnitIsDeadOrGhost = function(unit)
  return dead[unit] == true
end

UnitIsConnected = function(unit)
  return connected[unit] ~= false
end

UnitName = function(unit)
  return names[unit] or unit
end

UnitFullName = function(unit)
  return names[unit] or unit, "Realm"
end

UnitGUID = function(unit)
  return "Player-1-" .. unit
end

UnitClass = function()
  return "Warrior", "WARRIOR"
end

UnitGroupRolesAssigned = function(unit)
  return roles[unit] or "NONE"
end

C_Timer = {
  After = function()
  end,
}

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)

local pack = ns.MakePack("DUNGEON")
local lists = {priority = {}, skip = {}}
local addon = {
  db = {profile = {lists = lists}},
  commands = {},
}

function addon:GetEditingPack()
  return pack
end

function addon:GetAppliedEnvironmentPack()
  return pack
end

function addon:GetAppliedEnvironment()
  return "DUNGEON"
end

function addon:EnsureLists()
end

function addon:RegisterChatCommand(name, callback)
  self.commands[name] = callback
end

ns.addon = addon
assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)

local function SetRoster(tokens)
  exists = {}
  dead = {}
  connected = {}
  names = {}
  for i = 1, #tokens do
    local unit = tokens[i]
    exists[unit] = true
    connected[unit] = true
    names[unit] = unit
  end
end

local coreParty = {"player", "party1", "party2", "party3", "party4"}

SetRoster({"player", "pet", "party1", "party2", "party3", "party4"})
pack.mufs.order = "GROUP"
pack.sorting.centerPlayer = false
Same(ns.BuildRoster(pack), {"player", "pet", "party1", "party2", "party3", "party4"}, "group player pet")

SetRoster({"player", "party1", "party2", "partypet2", "party3", "party4"})
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "partypet2", "party3", "party4"}, "follower pet adjacency")

lists.priority = {{kind = "id", name = "party3"}}
pack.mufs.order = "PRIORITY"
Same(ns.BuildRoster(pack), {"party3", "player", "party1", "party2", "partypet2", "party4"}, "priority mode")

pack.mufs.order = "GROUP"
pack.sorting.centerPlayer = true
SetRoster({"player", "pet", "party1", "party2", "party3", "party4"})
Same(ns.BuildRoster(pack), {"party1", "party2", "player", "pet", "party3", "party4"}, "center player")
pack.sorting.centerPlayer = false

pack.sorting.includePlayer = false
Same(ns.BuildRoster(pack), {"party1", "party2", "party3", "party4"}, "exclude player and player pet")
pack.sorting.includePlayer = true

pack.sorting.includePets = false
Same(ns.BuildRoster(pack), coreParty, "exclude pets")
pack.sorting.includePets = true

SetRoster(coreParty)
dead.party2 = true
connected.party3 = false
pack.sorting.skipDead = true
Same(ns.BuildRoster(pack), {"player", "party1", "party4"}, "skip dead and offline")
pack.sorting.skipDead = false

SetRoster({"player", "party1", "party2", "partypet2", "party3", "party4"})
lists.skip = {{kind = "id", name = "party2"}}
Same(ns.BuildRoster(pack), {"player", "party1", "party3", "party4"}, "skipped owner removes pet")
lists.skip = {}

local function Frame(left, top, slot)
  return {
    GetLeft = function()
      return left
    end,
    GetTop = function()
      return top
    end,
    GetWidth = function()
      return 80
    end,
    GetHeight = function()
      return 40
    end,
    slot = slot,
  }
end

local callback
local provider = {}
provider.RegisterCallback = function(_owner, event, fn)
  Check(event == "OnFramesSorted", "Danders callback event")
  callback = fn
end
provider.UnregisterCallback = function()
  callback = nil
end

DandersFrames = provider
DandersFrames_IsReady = function()
  return true
end
DandersFrames_GetPartyConfig = function()
  return {growDirection = "HORIZONTAL"}
end
DandersFrames_GetPartyHeader = function()
  return nil
end

local frames = {
  player = Frame(300, 500, 3),
  party1 = Frame(100, 500, 1),
  party2 = Frame(200, 500, 2),
  party3 = Frame(500, 500, 5),
  party4 = Frame(400, 500, 4),
}

DandersFrames_GetFrameForUnit = function(unit)
  return frames[unit]
end

SetRoster({"player", "party1", "party2", "partypet2", "party3", "party4"})
pack.mufs.order = "DANDERSFRAMES"
Same(ns.BuildRoster(pack), {"party1", "party2", "partypet2", "player", "party4", "party3"}, "Danders horizontal geometry")

DandersFrames_GetPartyConfig = function()
  return {growDirection = "VERTICAL"}
end
frames.player = Frame(100, 300, 3)
frames.party1 = Frame(100, 500, 1)
frames.party2 = Frame(100, 400, 2)
frames.party3 = Frame(100, 100, 5)
frames.party4 = Frame(100, 200, 4)
Same(ns.BuildRoster(pack), {"party1", "party2", "partypet2", "player", "party4", "party3"}, "Danders vertical geometry")

raidMode = true
groupSize = 5
DandersFrames_GetRaidConfig = function()
  return {growDirection = "HORIZONTAL", raidUseGroups = true}
end
DandersFrames_IsRaidGrouped = function()
  return true
end
DandersFrames_GetRaidGroupHeaders = function()
  return {}
end
frames = {
  raid1 = Frame(300, 500, 3),
  raid2 = Frame(100, 500, 1),
  raid3 = Frame(500, 500, 5),
  raid4 = Frame(200, 500, 2),
  raid5 = Frame(400, 500, 4),
}
SetRoster({"raid1", "raid2", "raidpet2", "raid3", "raid4", "raid5"})
Same(ns.BuildRoster(pack), {"raid2", "raidpet2", "raid4", "raid1", "raid5", "raid3"}, "Danders grouped raid geometry")

raidMode = false
frames = {
  player = Frame(300, 500, 3),
  party1 = Frame(100, 500, 1),
  party2 = Frame(200, 500, 2),
  party3 = Frame(500, 500, 5),
  party4 = Frame(400, 500, 4),
}

DandersFrames_GetFrameForUnit = nil
SetRoster({"player", "party1", "party2", "partypet2", "party3", "party4"})
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "partypet2", "party3", "party4"}, "Danders unavailable fallback")

DandersFrames_GetFrameForUnit = function(unit)
  if unit == "party4" then
    return nil
  end
  return frames[unit]
end
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "partypet2", "party3", "party4"}, "Danders partial fallback")

DandersFrames_GetFrameForUnit = function()
  error("malformed provider")
end
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "partypet2", "party3", "party4"}, "Danders malformed fallback")

local secretFrame = frames.party4
issecretvalue = function(value)
  return value == secretFrame
end
DandersFrames_GetFrameForUnit = function(unit)
  return frames[unit]
end
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "partypet2", "party3", "party4"}, "Danders secret frame fallback")
issecretvalue = nil

DandersFrames_GetFrameForUnit = function(unit)
  return frames[unit]
end
ns.RegisterLists(addon)
Check(type(callback) == "function", "Danders callback registered")

local combat = true
local pending = false
local layouts = 0
ns.RefreshMUFs = function()
  if combat then
    pending = true
    return
  end
  pending = false
  layouts = layouts + 1
end

callback("OnFramesSorted", "party")
Check(pending and layouts == 0, "Danders callback defers layout in combat")
combat = false
ns.RefreshMUFs()
Check(not pending and layouts == 1, "regen recovery applies deferred layout")

SetRoster(coreParty)
pack.mufs.order = "GROUP"
ns.BuildRoster(pack)
ns.ScheduleFollowerRosterGuard()
now = 101
exists.party4 = false
Same(ns.BuildRoster(pack), coreParty, "follower snapshot preserves transitional member")
now = 120
Same(ns.BuildRoster(pack), {"player", "party1", "party2", "party3"}, "follower snapshot expires")

SetRoster({"player", "pet", "party1", "partypet1", "party2", "party3", "party4"})
groupSize = 5
subgroupSize = 0
instanceType = "none"
Same(ns.BuildRoster(pack), {"player", "pet"}, "authoritative solo rejects lingering follower tokens and keeps own pet")

subgroupSize = 2
Same(ns.BuildRoster(pack), {"player", "pet", "party1", "partypet1", "party2", "party3", "party4"}, "real open-world party is retained")

subgroupSize = 0
instanceType = "scenario"
Same(ns.BuildRoster(pack), {"player", "pet", "party1", "partypet1", "party2", "party3", "party4"}, "follower scenario ignores subgroup count")

instanceType = nil
GetNumSubgroupMembers = function()
  return nil
end
ns.ScheduleFollowerRosterGuard()
now = 121
Same(ns.BuildRoster(pack), {"player", "pet", "party1", "partypet1", "party2", "party3", "party4"}, "ambiguous context retains committed roster inside bounded guard")
now = 140
Same(ns.BuildRoster(pack), {"player", "pet"}, "ambiguous context drops remembered group after bounded guard")

local status = ns.GetRosterContextStatus()
Check(status.kind == "UNKNOWN" and status.ready == false, "roster context diagnostics are sanitized aggregate state")

io.write("sorting-contract: ok\n")
