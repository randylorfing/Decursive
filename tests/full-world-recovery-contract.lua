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

local combat = false
local restricted = false
local timers = {}
local diagnostics = {}

InCombatLockdown = function()
  return combat
end

C_Timer = {
  After = function(delay, callback)
    timers[#timers + 1] = {delay = delay, callback = callback}
  end,
}

GetInstanceInfo = function()
  return "World", "none"
end

local addon = {}
function addon:RegisterEvent()
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

local ns = {
  DiagnosticRecord = function(kind, fields)
    diagnostics[#diagnostics + 1] = {kind = kind, fields = fields}
  end,
}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)

addon.db = {
  profile = {
    routingMode = "multiple",
    environments = ns.MakeEnvironments(),
    lists = {priority = {}, skip = {}},
  },
  char = {editingEnvironment = "OPEN_WORLD"},
  global = {accountProfile = "Default", characters = {}, specs = {}},
  GetCurrentProfile = function()
    return "Default"
  end,
  GetProfiles = function()
    return {"Default"}
  end,
}
addon.appliedEnvironment = "OPEN_WORLD"

local context = {kind = "PARTY_INSTANCE", ready = true}
local snapshot = true
local resetRoster = 0
local resetMUFs = 0
local full = {"player", "party1", "party2", "party3", "party4", "pet"}

ns.GetRosterContextStatus = function()
  return context
end

ns.RefreshAddonRestrictionState = function()
  return not restricted
end

ns.HasActiveAddonRestriction = function()
  return restricted
end

ns.ResetRosterForWorldTransition = function()
  resetRoster = resetRoster + 1
  snapshot = false
  return true
end

ns.ResetMUFsForWorldTransition = function()
  Check(not combat, "managed MUF reset is never attempted in combat")
  resetMUFs = resetMUFs + 1
  return true
end

ns.BuildRoster = function()
  local source
  if context.kind == "PARTY_INSTANCE" or context.kind == "REAL_PARTY" then
    source = full
    snapshot = true
  elseif context.kind == "UNKNOWN" and snapshot then
    source = full
  else
    source = {"player", "pet"}
  end
  local result = {}
  for i = 1, #source do
    result[i] = source[i]
  end
  return result
end

local engine = {
  refreshGeneration = 0,
  refreshes = 0,
  pending = false,
  assigned = {"player"},
}
function engine:Defer(reason)
  self.pending = true
  self.pendingReason = reason
  return false
end
function engine:Refresh(reason)
  Check(not combat, "provider transaction is never mutated in combat")
  self.pending = false
  self.refreshGeneration = self.refreshGeneration + 1
  self.refreshes = self.refreshes + 1
  self.reason = reason
  self.assigned = ns.BuildRoster()
  return true
end
function engine:Recover(reason)
  return self:Refresh(reason)
end
ns.DetectionEngine = engine

addon.rosterRecoveryPending = false
addon.rosterRecoveryRetryToken = 0
addon.rosterRecoveryRetryCount = 0
addon.rosterRecoveryGeneration = 0
addon.rosterConvergenceGeneration = 0

combat = true
addon:BeginFullWorldRecovery("PLAYER_LEAVING_WORLD", true)
local generation = addon.fullWorldRecoveryGeneration
Check(not addon:RunFullWorldRecoveryPass("PLAYER_ENTERING_WORLD", generation, 0, false), "combat world entry defers")
Equal(resetMUFs, 0, "combat does not touch managed MUFs")
Check(addon.fullWorldRecoveryPending, "combat preserves the noncancellable full-world dirty bit")
Equal(table.concat(engine.assigned, ","), "player", "combat retains the last-good visible bank")

combat = false
restricted = true
Check(addon:RunFullWorldRecoveryPass("RESTRICTION_ACTIVE", generation, 0, false), "addon restriction category does not block an unlocked candidate commit")
Equal(resetMUFs, 0, "successful candidate commit does not use the destructive reset path")
Equal(table.concat(engine.assigned, ","), table.concat(full, ","), "valid follower instance is preserved")
Check(not addon.fullWorldRecoveryPending, "authoritative candidate commits exactly once")
restricted = false

local fullGeneration = addon.fullWorldRecoveryGeneration
addon:StartRosterConvergence("GROUP_LEFT")
addon:StartRosterConvergence("LFG_UPDATE")
addon:StartRosterConvergence("ZONE_CHANGED_NEW_AREA")
Equal(addon.fullWorldRecoveryGeneration, fullGeneration, "routine event generations cannot cancel full-world recovery")

context = {kind = "UNKNOWN", ready = false}
addon:BeginFullWorldRecovery("PLAYER_LEAVING_WORLD", true)
generation = addon.fullWorldRecoveryGeneration
local refreshesBeforeUnknown = engine.refreshes
Check(not addon:RunFullWorldRecoveryPass("SETTLING", generation, 8, false), "ambiguous context remains provisional beyond ten seconds")
Equal(engine.refreshes, refreshesBeforeUnknown, "ambiguous context cannot produce an APPLIED provider transaction")
Check(addon.fullWorldRecoveryPending, "ambiguous context cannot commit or clear recovery")

Check(addon:RunFullWorldRecoveryPass("TERMINAL", generation, 9, true), "terminal sample makes the bounded teardown decision")
Equal(table.concat(engine.assigned, ","), "player,pet", "terminal ambiguous teardown rejects lingering followers and keeps own pet")
Check(not addon.fullWorldRecoveryPending, "terminal teardown completes recovery")

for _, mode in ipairs({"multiple", "solo"}) do
  addon.db.profile.routingMode = mode
  context = {kind = "REAL_PARTY", ready = true}
  addon:BeginFullWorldRecovery("MODE_" .. mode, true)
  Check(addon:RunFullWorldRecoveryPass("TERMINAL", addon.fullWorldRecoveryGeneration, 9, true), mode .. " real party converges")
  Equal(table.concat(engine.assigned, ","), table.concat(full, ","), mode .. " does not alter roster truth")
end

local core = assert(io.open("ZDecursive/Core.lua", "rb")):read("*a")
local detection = assert(io.open("ZDecursive/Detection.lua", "rb")):read("*a")
local engineSource = assert(io.open("ZDecursive/DetectionEngine.lua", "rb")):read("*a")
local mufs = assert(io.open("ZDecursive/MUFs.lua", "rb")):read("*a")
Check(core:find("13.00, 16.00", 1, true), "full-world cadence extends beyond the twelve-second follower guard")
Check(core:find('phase = "PROVISIONAL"', 1, true), "diagnostics distinguish provisional context")
Check(core:find('"TERMINAL_APPLIED"', 1, true), "diagnostics identify terminal convergence")
Check(detection:find("function ns.ResetRosterForWorldTransition", 1, true), "world reset clears follower snapshot state")
Check(mufs:find("function ns.ResetMUFsForWorldTransition", 1, true), "world reset owns full managed MUF cleanup")
Check(not core:find("ns.ResetMUFsForWorldTransition(self.fullWorldRecoveryReason)", 1, true), "Core never eagerly hides the MUF bank during world entry")
Check(engineSource:find('ResumeCoreWorldRecovery("ENGINE_RETRY")', 1, true), "engine retries cannot bypass the Core world candidate transaction")
Check(engineSource:find('ResumeCoreWorldRecovery("RESTRICTION_EVENT_SETTLED")', 1, true), "restriction wakeups resume the Core candidate transaction")
Check(mufs:find("FinishCooldown(priority)", 1, true), "world reset clears cooldown state")
Check(mufs:find("PaintManagedOverlays(btn, GetPack(), nil)", 1, true), "world reset clears skull, range, death, and presentation state")

io.write("full-world-recovery-contract: ok\n")
