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

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Same(actual, expected, message)
  Equal(table.concat(actual, ","), table.concat(expected, ","), message)
end

local combat = false
local timerQueue = {}
local registeredEvents = {}
local diagnosticProviders = {}

InCombatLockdown = function()
  return combat
end

GetInstanceInfo = function()
  return "World", "none"
end

IsInGroup = function()
  return false
end

IsInRaid = function()
  return false
end

C_Timer = {
  After = function(_delay, callback)
    timerQueue[#timerQueue + 1] = callback
  end,
}

local addon = {}
function addon:RegisterEvent(event, method)
  registeredEvents[event] = method
end
function addon:RegisterChatCommand()
end

local AceAddon = {}
function AceAddon:NewAddon()
  return addon
end

local AceDB = {}
LibStub = function(name)
  if name == "AceAddon-3.0" then
    return AceAddon
  end
  if name == "AceDB-3.0" then
    return AceDB
  end
  error("unexpected library")
end

local ns = {}
ns.RegisterDiagnosticProvider = function(name, callback)
  diagnosticProviders[name] = callback
end
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)

addon.db = {
  profile = {
    environments = ns.MakeEnvironments(),
    lists = {priority = {}, skip = {}},
  },
  char = {editingEnvironment = "OPEN_WORLD"},
  global = {
    accountProfile = "Default",
    characters = {},
    specs = {},
  },
  GetCurrentProfile = function()
    return "Default"
  end,
  GetProfiles = function()
    return {"Default"}
  end,
}
addon.appliedEnvironment = "OPEN_WORLD"

local roster = {"player", "party1", "party2", "party3", "party4", "pet", "partypet2"}
ns.BuildRoster = function()
  local copy = {}
  for i = 1, #roster do
    copy[i] = roster[i]
  end
  return copy
end

local sortInvalidations = 0
ns.InvalidateUnitSort = function()
  sortInvalidations = sortInvalidations + 1
end

local function PresentedRoster(units)
  local members = {}
  local pets = {}
  for i = 1, #units do
    local unit = units[i]
    if unit == "pet" or unit:match("pet%d+$") then
      pets[#pets + 1] = unit
    elseif #members < 5 then
      members[#members + 1] = unit
    end
  end
  for i = 1, #pets do
    members[#members + 1] = pets[i]
  end
  return members
end

local engine = {
  refreshGeneration = 0,
  pending = false,
  refreshes = 0,
  providerAssignments = {},
  displayed = {},
}
function engine:Defer(reason)
  self.pending = true
  self.pendingReason = reason
  return false
end
function engine:Refresh(reason)
  if combat then
    return self:Defer(reason)
  end
  self.pending = false
  self.pendingReason = nil
  self.refreshGeneration = self.refreshGeneration + 1
  self.refreshes = self.refreshes + 1
  self.lastReason = reason
  self.providerAssignments = ns.BuildRoster()
  self.displayed = PresentedRoster(self.providerAssignments)
  return true
end
function engine:Recover(reason)
  if not self.pending then
    return false
  end
  return self:Refresh(reason)
end
ns.DetectionEngine = engine

addon.rosterRecoveryPending = false
addon.rosterRecoveryReason = "NONE"
addon.rosterRecoveryRetryToken = 0
addon.rosterRecoveryRetryCount = 0
addon.rosterRecoveryGeneration = 0
Check(addon:CommitRosterIdentity("TEST_BASELINE"), "baseline identity commits")

local baselineGeneration = addon.rosterRecoveryGeneration
Check(not addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "identical roster payload is a no-op")
Equal(engine.refreshes, 0, "identical payload does not rebuild")
Equal(addon.rosterRecoveryGeneration, baselineGeneration, "identical payload does not advance generation")

roster = {"party1", "player", "party2", "party3", "party4", "pet", "partypet2"}
Check(addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "order-only change rebuilds")
Equal(engine.refreshes, 1, "order change performs one complete rebuild")
Equal(sortInvalidations, 1, "order change invalidates roster sort once")
Same(engine.providerAssignments, roster, "provider assignments receive complete ordered roster")

Check(not addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "duplicate ordered roster is idempotent")
Equal(engine.refreshes, 1, "duplicate ordered roster does not reconfigure providers")

roster = {"player", "party1", "party2", "party4", "party5", "pet", "partypet2", "partypet5"}
Check(addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "membership payload rebuilds")
Equal(engine.refreshes, 2, "membership change performs one rebuild")
Same(engine.providerAssignments, roster, "detection provider assignment remains uncapped")
Equal(#engine.providerAssignments, 8, "detection retains all members and pets")
Same(engine.displayed, {"player", "party1", "party2", "party4", "party5", "pet", "partypet2", "partypet5"}, "five-member cap keeps additional pets")
Check(not table.concat(engine.providerAssignments, ","):find("party3", 1, true), "stale departed assignment is removed")

combat = true
roster = {"player", "party1", "party2", "party4", "pet", "partypet2"}
Check(not addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "combat roster change defers")
Check(addon.rosterRecoveryPending == true and engine.pending == true, "combat keeps explicit roster and engine pending state")
Equal(engine.refreshes, 2, "combat performs no provider mutation")
local queuedAfterFirstCombatEvent = #timerQueue
Check(not addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), "repeated combat payload remains deferred")
Equal(#timerQueue, queuedAfterFirstCombatEvent, "combat payloads coalesce to one bounded retry")
combat = false
Check(addon:OnRegenEnabled(), "regen flushes pending roster immediately")
Equal(engine.refreshes, 3, "regen performs exactly one roster rebuild")
Check(addon.rosterRecoveryPending == false, "regen clears roster pending state")

for i = 1, #timerQueue do
  timerQueue[i]()
end
Equal(engine.refreshes, 3, "stale bounded callbacks are token-cancelled after regen")

timerQueue = {}
combat = true
roster = {"player", "party1", "party4", "pet"}
addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE")
Equal(#timerQueue, 8, "missed-regen path schedules one reconcile callback plus seven convergence samples")
combat = false
timerQueue[1]()
Equal(engine.refreshes, 4, "bounded callback reconciles after combat when regen is missed")
Check(addon.rosterRecoveryPending == false, "bounded recovery clears pending state")
Same(engine.providerAssignments, roster, "bounded recovery applies authoritative roster")

for i = 2, #timerQueue do
  timerQueue[i]()
end
timerQueue = {}

local function VerifyDelayedFollowerExit(mode)
  addon.db.profile.routingMode = mode
  addon.appliedEnvironment = mode == "solo" and "SOLO" or "OPEN_WORLD"
  roster = {"player", "party1", "party2", "party3", "party4", "pet"}
  addon:CommitRosterIdentity("DELAYED_BASELINE")
  local before = engine.refreshes
  Check(not addon:OnGroupRosterUpdate("GROUP_ROSTER_UPDATE"), mode .. " initial contradictory event keeps the committed roster")
  Equal(engine.refreshes, before, mode .. " initial stale API snapshot is idempotent")
  Equal(#timerQueue, 7, mode .. " event retains seven bounded convergence samples")
  roster = {"player", "pet"}
  table.remove(timerQueue, 1)()
  Equal(engine.refreshes, before + 1, mode .. " delayed authoritative no-party roster triggers a complete rebuild")
  Same(engine.providerAssignments, {"player", "pet"}, mode .. " delayed convergence removes every stale follower")
  while #timerQueue > 0 do
    table.remove(timerQueue, 1)()
  end
end

VerifyDelayedFollowerExit("multiple")
VerifyDelayedFollowerExit("solo")

Equal(registeredEvents.GROUP_ROSTER_UPDATE, nil, "test does not invoke OnEnable registration")
local report = diagnosticProviders.Core()
Equal(report.rosterIdentityData, "UNIT_TOKENS_ONLY", "diagnostics declare sanitized identity source")
Equal(report.rosterUnitCount, 2, "diagnostics expose only aggregate unit count")
Equal(report.rosterPetCount, 1, "diagnostics expose only aggregate pet count")
Check(report.rosterMembershipSignature == nil and report.rosterOrderSignature == nil, "diagnostics never expose roster signatures")

local coreSource = assert(io.open("ZDecursive/Core.lua", "rb")):read("*a")
Check(coreSource:find('RegisterEvent("GROUP_LEFT", "OnGroupRosterUpdate")', 1, true) ~= nil, "group exit event drives roster reconciliation")
Check(coreSource:find('RegisterEvent("GROUP_JOINED", "OnGroupRosterUpdate")', 1, true) ~= nil, "group join event drives roster reconciliation")
Check(coreSource:find('BeginRosterContextTransition(reason)', 1, true) ~= nil, "zone and instance context events start bounded roster recovery")
Check(coreSource:find('self:StartRosterConvergence(event or "GROUP_ROSTER_UPDATE")', 1, true) ~= nil, "plain roster bursts also start convergence")

io.write("roster-rebuild-contract: ok\n")
