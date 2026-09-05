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

-- ZDecursive, Copyright (C) 2026 Randy Lorfing.
-- Based on Decursive, Copyright (C) 2006-2026 John Wellesz.
-- GPL-3.0-or-later; distributed without warranty. See ../LICENSE.
-- Execute the actual engine and roster builder. Only client services/consumers
-- are mocked; queues are advanced explicitly so event ordering is observable.

local checks = 0
local function Check(value, message)
  checks = checks + 1
  if not value then error(message, 2) end
end
local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Same(actual, expected, message)
  Equal(table.concat(actual, ","), table.concat(expected, ","), message)
end

local combat, timers, memberCount = false, {}, 8
local failRoster, sortCalls = false, 0
local function Advance(zeroOnly)
  local batch = timers
  timers = {}
  for _, timer in ipairs(batch) do
    if not zeroOnly or timer.delay == 0 then timer.callback()
    else timers[#timers + 1] = timer end
  end
end
local function PendingZero()
  local count = 0
  for _, timer in ipairs(timers) do if timer.delay == 0 then count = count + 1 end end
  return count
end

InCombatLockdown = function() return combat end
issecretvalue = function() return false end
canaccessvalue = function() return true end
GetTime = function() return 100 end
GetInstanceInfo = function() return "Raid", "raid" end
IsInRaid = function() return true end
GetNumGroupMembers = function() return memberCount end
GetNumSubgroupMembers = function() return 0 end
UnitExists = function(unit)
  local index = unit:match("^raid(%d+)$")
  return index ~= nil and tonumber(index) <= memberCount
end
UnitIsUnit = function(left, right) return left == right or (left == "raid1" and right == "player") end
UnitIsDeadOrGhost = function() return false end
UnitIsConnected = function() return true end
UnitIsPlayer = function() return true end
C_Timer = {After = function(delay, callback) timers[#timers + 1] = {delay = delay, callback = callback} end}
C_EventUtils = {IsEventValid = function() return true end}
CreateFrame = function()
  local frame = {events = {}, scripts = {}}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  return frame
end

local function NewEngine(realRoster)
  combat, timers, memberCount, failRoster, sortCalls = false, {}, 8, false, 0
  local ns = {}
  assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
  local pack = ns.MakePack("RAID")
  pack.advanced.autoAuraTrace = false
  ns.currentPack = pack
  ns.addon = {GetAppliedEnvironmentPack = function() return ns.currentPack end}
  if realRoster then
    assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
    ns.ApplyUnitLists = function(units)
      sortCalls = sortCalls + 1
      if failRoster then error("injected roster order failure") end
      local ordered = {}
      for i = #units, 1, -1 do ordered[#ordered + 1] = units[i] end
      return ordered
    end
  end
  local invalidate = ns.InvalidateDetection
  ns.InvalidateDetection = function()
    ns.invalidations = (ns.invalidations or 0) + 1
    if invalidate then invalidate() end
    if ns.onInvalidate then ns.onInvalidate() end
  end
  ns.ScheduleFollowerRosterGuard = function() ns.guards = (ns.guards or 0) + 1 end
  ns.GetDetectionItemActionSignature = function() return "test-items-stable" end
  ns.HasActiveAddonRestriction = function() return false end
  ns.lastFailure = nil
  ns.DiagnosticRecord = function(kind, fields)
    if kind == "ENGINE_FAILURE" then ns.lastFailure = fields.code end
  end
  assert(loadfile("ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
  local engine = ns.DetectionEngine
  ns.calls, ns.packs = {}, {}
  for _, name in ipairs({"MUFs", "Alerts", "LiveList"}) do
    engine:RegisterConsumer(name, function()
      Check(not combat, "consumer preparation must not run in combat")
      ns.calls[#ns.calls + 1] = name
      ns.packs[#ns.packs + 1] = ns.currentPack
      if ns.onConsumer then return ns.onConsumer(name) end
      return true, "SUCCESS", 0
    end)
  end
  Check(engine:Start(), "baseline engine starts")
  ns.calls, ns.packs = {}, {}
  return ns, engine, pack
end

-- Same-frame capability signals update the final state once, without making
-- other event families (profile/world/spec routing) asynchronous.
local ns, engine = NewEngine()
local initialGeneration = engine.refreshGeneration
engine:OnEvent("SPELLS_CHANGED")
engine:OnEvent("TRAIT_CONFIG_UPDATED")
engine:OnEvent("PLAYER_TALENT_UPDATE")
Equal(PendingZero(), 1, "burst schedules one next-frame callback")
Equal(#ns.calls, 0, "capability burst does not synchronously rebuild consumers")
Equal(ns.invalidations or 0, 0, "capability invalidation waits for settled flush")
Advance(true)
Equal(#ns.calls, 3, "one capability pass refreshes each consumer once")
Equal(ns.invalidations, 1, "one invalidation covers the burst")
Equal(ns.guards, 1, "one follower guard covers the burst")
Equal(engine.refreshGeneration, initialGeneration + 1, "burst commits one generation")
Check(not engine.capabilityRefreshPending and not engine.capabilityRefreshScheduled, "completed batch is idle")

-- An immediate newer profile/world transaction subsumes the queued work;
-- executing the stale timer later cannot replay it against an older pack.
ns, engine = NewEngine()
engine:OnEvent("SPELLS_CHANGED")
local newPack = ns.MakePack("PVP")
ns.currentPack = newPack
Check(engine:Refresh("CORE_WORLD_ENTRY"), "world/profile apply remains immediate")
Equal(#ns.calls, 3, "immediate transaction prepares consumers")
for _, pack in ipairs(ns.packs) do Check(pack == newPack, "immediate transaction uses current applied pack") end
Equal(ns.invalidations, 1, "immediate transaction consumes capability invalidation")
Advance(true)
Equal(#ns.calls, 3, "stale queued callback is a no-op")

ns, engine = NewEngine()
engine:OnEvent("SPELLS_CHANGED")
Check(engine:Reset(), "reset succeeds outside combat")
Advance(true)
Equal(#ns.calls, 0, "reset invalidates queued capability callbacks")
Equal(engine.state, "COLD", "stale callback does not restart a reset engine")

-- Combat beginning after scheduling must preserve work without invoking a
-- consumer or invalidating a working capability model until recovery.
ns, engine = NewEngine()
engine:OnEvent("SPELLS_CHANGED")
combat = true
Advance(true)
Equal(#ns.calls, 0, "queued work is suppressed after combat starts")
Equal(ns.invalidations or 0, 0, "combat flush does not consume invalidation")
Check(engine.pending and engine.capabilityRefreshPending, "combat retains both native and capability work")
engine:OnEvent("TRAIT_CONFIG_UPDATED")
Check(engine.capabilityRefreshPending, "another combat signal is retained")
combat = false
Check(engine:Recover("REGEN_TEST"), "post-combat recovery applies the pending batch")
Equal(#ns.calls, 3, "recovery refreshes each bank once")
Equal(ns.invalidations, 1, "combat burst is invalidated once")
Advance(false)
Equal(#ns.calls, 3, "older retry callbacks cannot add another successful pass")

-- Re-entrant events, including those raised during invalidation itself, belong
-- to the next batch and cannot be erased by this transaction's completion.
ns, engine = NewEngine()
local queuedDuringFlush = false
ns.onConsumer = function(name)
  if name == "MUFs" and not queuedDuringFlush then
    queuedDuringFlush = true
    engine:OnEvent("TRAIT_CONFIG_UPDATED")
  end
  return true, "SUCCESS", 0
end
engine:OnEvent("SPELLS_CHANGED")
Advance(true)
Equal(#ns.calls, 3, "first flush runs once")
Check(engine.capabilityRefreshPending and engine.capabilityRefreshScheduled, "arrival during consumer flush survives")
Check(engine.pending, "arrival during consumer flush remains visible as pending engine work")
Advance(true)
Equal(#ns.calls, 6, "re-entrant arrival gets exactly one later pass")
Equal(ns.invalidations, 2, "each distinct batch invalidates once")
ns.onInvalidate = function()
  ns.onInvalidate = nil
  engine:OnEvent("PLAYER_TALENT_UPDATE")
end
engine:OnEvent("SPELLS_CHANGED")
Advance(true)
Check(engine.capabilityRefreshPending, "arrival during invalidation survives")
Advance(true)
Equal(#ns.calls, 12, "invalidation arrival also completes a later pass")
Check(not engine.capabilityRefreshPending, "re-entrant batches settle")

ns, engine = NewEngine()
ns.onInvalidate = function()
  ns.onInvalidate = nil
  Check(not engine:Refresh("REENTRANT_IMMEDIATE"), "invalidation cannot recursively enter the consumer transaction")
  combat = true
end
engine:OnEvent("SPELLS_CHANGED")
Advance(true)
Equal(#ns.calls, 0, "combat raised during invalidation suppresses consumer preparation")
Check(engine.pending and not engine.reconciling, "combat interruption leaves a recoverable engine")
combat = false
Check(engine:Recover("INVALIDATION_COMBAT_RECOVERY"), "interrupted invalidation recovers")
Equal(#ns.calls, 3, "interrupted batch applies once after combat")

ns, engine = NewEngine()
ns.onInvalidate = function() ns.onInvalidate = nil; error("injected invalidation failure") end
engine:OnEvent("SPELLS_CHANGED")
Advance(true)
Check(engine.pending and engine.capabilityRefreshPending and engine.retryScheduled, "invalidation error retains retryable capability work")
Check(not engine.reconciling, "invalidation exception releases the transaction guard")
Equal(#ns.calls, 0, "invalid capability state cannot reach consumers")
Advance(false)
Equal(engine.state, "READY", "invalidation failure recovers through the existing retry")
Equal(#ns.calls, 3, "recovered invalidation applies one consumer pass")

-- A failed consumer still owns an engine retry after the batch was consumed.
ns, engine = NewEngine()
local failOnce = true
ns.onConsumer = function(name)
  if name == "MUFs" and failOnce then failOnce = false; return false, "FAILURE", 0 end
  return true, "SUCCESS", 0
end
engine:OnEvent("SPELLS_CHANGED")
Advance(true)
Check(engine.pending and engine.retryScheduled, "failed capability transaction keeps a current retry")
Advance(false)
Equal(engine.state, "READY", "retry finishes the failed transaction")
Equal(ns.invalidations, 1, "retry reuses the settled invalidation")

-- Whole consumer transactions share one immutable backing roster, while each
-- consumer can independently cap/mutate its returned copy.
ns, engine = NewEngine(true)
local seen = {}
ns.onConsumer = function(name)
  local units = ns.BuildRoster(ns.currentPack)
  seen[name] = units
  if name == "MUFs" then
    for i = #units, 3, -1 do units[i] = nil end
    units[1] = "consumer-local-value"
    memberCount = 10 -- even a re-entrant public roster change cannot split this snapshot
  end
  return true, "SUCCESS", 0
end
Check(engine:Refresh("ROSTER_SNAPSHOT"), "roster snapshot transaction commits")
Equal(sortCalls, 1, "one canonical ordering pass covers all consumers")
Equal(#seen.MUFs, 2, "MUF copy can apply its cap")
Equal(#seen.Alerts, 8, "Alerts retains the complete initial roster")
Equal(#seen.LiveList, 8, "LiveList receives a separate complete roster")
Equal(seen.Alerts[1], "raid8", "another consumer cannot mutate the private snapshot")
Check(seen.Alerts ~= seen.LiveList, "consumers never share returned arrays")
local outside = ns.BuildRoster(ns.currentPack)
Equal(#outside, 10, "outside transaction sees current membership, not a persistent cache")
Equal(sortCalls, 2, "outside transaction performs a new build")

-- A consumer exception does not leak its roster snapshot into the next retry.
local consumerFailure = true
ns.onConsumer = function(name)
  local units = ns.BuildRoster(ns.currentPack)
  seen[name] = units
  if name == "MUFs" and consumerFailure then error("injected consumer failure") end
  return true, "SUCCESS", 0
end
memberCount = 11
Check(not engine:Refresh("FAILED_SNAPSHOT"), "consumer error withholds transaction success")
Equal(sortCalls, 3, "failed consumer transaction still builds only once")
Equal(#seen.Alerts, 11, "healthy consumer shares the same failed-pass roster")
memberCount, consumerFailure = 12, false
Advance(false)
Equal(engine.state, "READY", "failed snapshot transaction recovers")
Equal(sortCalls, 4, "retry builds a fresh snapshot")
Equal(#seen.LiveList, 12, "retry uses current membership rather than failed snapshot")

-- A canonical roster builder error is consistent across consumers and never
-- becomes an empty successful roster; the failed result is discarded on exit.
failRoster = true
Check(not engine:Refresh("ROSTER_BUILD_FAILED"), "roster builder error prevents success")
Equal(sortCalls, 5, "failed canonical builder is attempted only once in its transaction")
Check(engine.pending and engine.retryScheduled, "roster error retains recovery")
failRoster, memberCount = false, 13
Advance(false)
Equal(engine.state, "READY", "a later complete roster can recover")
Equal(sortCalls, 6, "failed roster result never persists across transactions")
Equal(#seen.MUFs, 13, "recovered consumer receives complete current roster")

-- Alternate-pack reads must not reuse or corrupt the applied transaction.
local alternate = ns.MakePack("RAID")
local token = ns.BeginRosterTransaction(ns.currentPack)
local first = ns.BuildRoster(ns.currentPack)
memberCount = 14
Equal(#ns.BuildRoster(alternate), 14, "alternate pack is built independently")
Same(ns.BuildRoster(ns.currentPack), first, "alternate read does not replace the applied snapshot")
Check(not ns.EndRosterTransaction({}), "foreign token cannot close the active transaction")
Check(ns.EndRosterTransaction(token), "owner token closes the transaction")
Equal(#ns.BuildRoster(ns.currentPack), 14, "closed transaction leaves no cached roster")

-- Core pending-environment exceptions must never allow an old-pack READY;
-- they retain the existing bounded retry coordinator, not another timer loop.
ns, engine = NewEngine()
ns.addon.RetryPendingEnvironment = function() error("injected pending environment failure") end
engine:Defer("TEST_PENDING_ENVIRONMENT")
for _ = 1, 20 do Advance(false) end
Equal(#ns.calls, 0, "pending environment failure never reconciles the old pack")
Check(engine.pending and engine.retryExhausted, "pending environment exception ends at bounded exhaustion")
Check(not engine.retryScheduled, "exhausted environment retry leaves no unbounded timer")
Equal(engine.lastFailure, "PENDING_ENVIRONMENT_RETRY_FAILED", "environment failure has a bounded public status code")

ns, engine = NewEngine()
ns.onConsumer = function(name)
  if name == "Alerts" then return false, "DEFERRED_RESTRICTED", 0 end
  return true, "SUCCESS", 0
end
Check(not engine:Refresh("PENDING_ENVIRONMENT_START"), "persistent environment consumer defers initially")
local targetGeneration = engine.desiredGeneration
ns.addon.RetryPendingEnvironment = function()
  local applied, state = engine:Refresh("PROFILE_NOTIFY", true)
  return true, applied, state
end
for _ = 1, 20 do Advance(false) end
Equal(engine.desiredGeneration, targetGeneration, "explicit Core retry retains the original desired generation")
Check(engine.pending and engine.retryExhausted and not engine.retryScheduled, "persistent environment consumer failure reaches bounded exhaustion")
Check(engine.state ~= "READY", "exhausted environment retry cannot report ready")
ns.onConsumer = nil
Check(engine:Refresh("EXPLICIT_NEW_PROFILE_REQUEST"), "a new explicit request can recover after exhaustion")
Equal(engine.desiredGeneration, targetGeneration + 1, "fresh requests retain their own new generation")
Equal(engine.retryAttempts, 0, "successful explicit request clears the old retry budget")

print("performance-engine-contract: " .. checks .. " checks passed")
