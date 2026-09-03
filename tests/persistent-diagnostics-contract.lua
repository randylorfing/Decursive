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

local frames = {}
local timers = {}
local shownText
local healthRuns = 0
local secret = setmetatable({}, {
  __tostring = function()
    error("secret tostring attempted")
  end,
})

issecretvalue = function(value)
  return value == secret
end

canaccessvalue = function(value)
  return value ~= secret
end

time = function()
  return 123456
end

C_AddOns = {
  GetAddOnMetadata = function()
    return "13.0.0-detect.65"
  end,
}

GetInstanceInfo = function()
  return "Private Name", "party"
end

IsInGroup = function()
  return true
end

IsInRaid = function()
  return false
end

GetNumSubgroupMembers = function()
  return 0
end

GetNumGroupMembers = function()
  return 5
end

InCombatLockdown = function()
  return false
end

UnitExists = function(unit)
  return unit == "player" or unit == "party1"
end

UnitIsConnected = function()
  return true
end

UnitIsDeadOrGhost = function()
  return false
end

C_EventUtils = {
  IsEventValid = function()
    return true
  end,
}

C_Timer = {
  After = function(delay, callback)
    timers[#timers + 1] = {delay = delay, callback = callback}
  end,
}

CreateFrame = function()
  local frame = {events = {}}
  function frame:SetScript(_name, callback)
    self.callback = callback
  end
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  frames[#frames + 1] = frame
  return frame
end

SlashCmdList = {}
ZDecursiveDiagnosticsDB = nil

local ns = {
  Diagnostics = {
    RegisterProvider = function()
      return true
    end,
    ClearRuntimeLog = function()
    end,
    ShowText = function(text)
      shownText = text
      return true
    end,
    Show = function()
      return true
    end,
    RunHealthCheck = function()
      healthRuns = healthRuns + 1
      shownText = "Zhaohu's Decursive Health Check"
      return shownText, {verdict = "HEALTHY"}
    end,
  },
  GetRosterContextStatus = function()
    return {
      kind = "PARTY_INSTANCE",
      ready = true,
      reason = "PARTY_INSTANCE_TYPE",
      realPartyCount = 0,
    }
  end,
}

assert(loadfile("ZDecursive/PersistentDiagnostics.lua"))("ZDecursive", ns)

local persistent = ns.PersistentDiagnostics
Check(ZDecursiveDiagnosticsDB == nil, "SavedVariables are untouched while the file loads")
Check(persistent.Database == nil, "runtime database is unavailable before ADDON_LOADED")
Check(persistent.Status().initialized == false, "pre-load status is safe and uninitialized")
persistent.Record("PRELOAD", {state = "QUEUED"}, false)
Check(persistent.Status().pendingRecords == 1, "pre-load records use the bounded memory queue")
Check(type(SlashCmdList.ZDECURSIVEDIAGNOSTICS) ~= "function", "slash router is deferred until ADDON_LOADED")
Check(frames[1].events.ADDON_LOADED == true, "only the initialization event is registered at file load")
frames[1].callback(frames[1], "ADDON_LOADED", "AnotherAddon")
Check(ZDecursiveDiagnosticsDB == nil, "another addon's load event cannot initialize SavedVariables")
frames[1].callback(frames[1], "ADDON_LOADED", "ZDecursive")

local database = persistent.Database
Check(type(ZDecursiveDiagnosticsDB) == "table", "declared diagnostics SavedVariable is initialized")
Check(database.schema == 1, "diagnostics schema migrates to schema one")
Check(database.enabled == false, "verbose diagnostics default off")
Check(#database.critical.entries == 2, "session start and queued file-load record initialize exactly once")
local sessionAfterLoad = database.lastSession
frames[1].callback(frames[1], "ADDON_LOADED", "ZDecursive")
Check(database.lastSession == sessionAfterLoad and #database.critical.entries == 2, "repeated ADDON_LOADED cannot start another session")
local runtimeFrame = frames[2]

database.critical.maxEntries = 3
database.critical.maxBytes = 100000
persistent.Record("TEST", {state = "ONE"}, false)
persistent.Record("TEST", {state = "TWO"}, false)
persistent.Record("TEST", {state = "THREE"}, false)
persistent.Record("TEST", {state = "FOUR"}, false)
Check(#database.critical.entries == 3, "critical ring enforces its entry cap")

persistent.Clear()
database.critical.maxEntries = 192
database.critical.maxBytes = 180
persistent.Record("BYTES", {state = "ONE", reason = "ABCDEFGHIJKLMNOP"}, false)
persistent.Record("BYTES", {state = "TWO", reason = "ABCDEFGHIJKLMNOP"}, false)
Check(database.critical.bytes <= database.critical.maxBytes, "critical ring enforces its byte cap")

persistent.Clear()
local before = #database.critical.entries
persistent.Record("DEDUPE", {state = "SAME"}, false)
persistent.Record("DEDUPE", {state = "SAME"}, false)
Check(#database.critical.entries == before + 1, "consecutive equivalent records deduplicate")
Check(database.critical.entries[#database.critical.entries].repeatCount == 2, "dedupe retains repeat count")

local ok = pcall(persistent.Record, "SECRET", {value = secret}, false)
Check(ok, "secret values are never stringified")
Check(database.critical.entries[#database.critical.entries].fields.value == "<secret>", "secret values use explicit sentinel")

local verboseBefore = #database.verbose.entries
persistent.Record("VERBOSE", {state = "OFF"}, true)
Check(#database.verbose.entries == verboseBefore, "verbose records are suppressed by default")
persistent.HandleCommand("start")
persistent.Record("VERBOSE", {state = "ON"}, true)
Check(database.enabled == true and #database.verbose.entries == verboseBefore + 1, "start enables verbose persistence")
persistent.HandleCommand("stop")
Check(database.enabled == false, "stop disables verbose persistence")
persistent.HandleCommand("mark anything-private-is-ignored")
Check(database.counters.marks == 1, "mark stores only an anonymous counter")

persistent.CaptureSnapshot("TEST", 0)
Check(database.lastSnapshot.routingMode == nil, "missing routing status is tolerated")
Check(database.lastSnapshot.rosterContext == "PARTY_INSTANCE", "roster context is stored independently")
Check(database.lastSnapshot.playerExists == "TRUE", "fixed unit marker is captured")
Check(database.lastSnapshot.p2Exists == "FALSE", "absent fixed unit marker is captured")

persistent.HandleCommand("monitor")
Check(database.enabled == true, "monitor enables verbose mode")
Check(shownText:find("Run /reload before sharing", 1, true), "monitor explains SavedVariables flush requirement")
persistent.HandleCommand("health")
Check(healthRuns == 1 and shownText:find("Health Check", 1, true), "/zdiag health opens the evaluated copyable report")

Check(type(SlashCmdList.ZDECURSIVEDIAGNOSTICS) == "function", "zdiag command router is installed")
Check(runtimeFrame.events.PLAYER_LEAVING_WORLD, "diagnostics captures follower exit world edge")
Check(runtimeFrame.events.GROUP_ROSTER_UPDATE, "diagnostics captures roster event order")
Check(runtimeFrame.events.LFG_UPDATE and runtimeFrame.events.SCENARIO_UPDATE, "diagnostics captures delayed context APIs")
Check(#timers >= 7, "snapshot monitoring uses bounded delayed convergence samples")

local toc = assert(io.open("ZDecursive/ZDecursive.toc", "rb")):read("*a")
local source = assert(io.open("ZDecursive/PersistentDiagnostics.lua", "rb")):read("*a")
local exporter = assert(io.open("ZDecursive/Tools/Export-ZDecursiveDiagnostics.ps1", "rb")):read("*a")
Check(toc:find("ZDecursiveDiagnosticsDB", 1, true), "diagnostics SavedVariable is declared")
Check(not source:find('SetScript("OnUpdate"', 1, true), "persistent diagnostics never polls OnUpdate")
Check(not source:find("UnitAura", 1, true), "persistent diagnostics never enumerates auras")
Check(not source:find("seterrorhandler", 1, true), "persistent diagnostics does not replace the global error handler")
Check(not source:find("print(", 1, true), "persistent diagnostics emits no chat debug")
Check(exporter:find("Get%-DiagnosticsTableText"), "exporter uses a restricted parser")
Check(exporter:find("Get%-Content %-LiteralPath"), "exporter reads SavedVariables literally")
Check(not exporter:find("Set%-Content %-LiteralPath %$candidate%.FullName"), "exporter never writes the SavedVariables source")
Check(not exporter:find("Start%-Sleep"), "exporter does not poll")

ZDecursiveDiagnosticsDB = {
  enabled = true,
  nextSession = 4,
  critical = {entries = {}, bytes = 0},
  verbose = {entries = {}, bytes = 0},
}
local migratedNS = {Diagnostics = ns.Diagnostics}
assert(loadfile("ZDecursive/PersistentDiagnostics.lua"))("ZDecursive", migratedNS)
local migratedLoader = frames[#frames]
Check(ZDecursiveDiagnosticsDB.schema == nil, "legacy storage is not migrated at file load")
migratedLoader.callback(migratedLoader, "ADDON_LOADED", "ZDecursive")
Check(ZDecursiveDiagnosticsDB.schema == 1, "legacy diagnostics storage migrates idempotently")
Check(ZDecursiveDiagnosticsDB.enabled == true, "legacy verbose preference is preserved")
Check(ZDecursiveDiagnosticsDB.lastSession == 4, "legacy session sequence is preserved")

local forward = {schema = 9, preserved = true}
ZDecursiveDiagnosticsDB = forward
local forwardNS = {Diagnostics = ns.Diagnostics}
assert(loadfile("ZDecursive/PersistentDiagnostics.lua"))("ZDecursive", forwardNS)
local forwardLoader = frames[#frames]
Check(forwardNS.PersistentDiagnostics.Database == nil, "future schema is not inspected at file load")
forwardLoader.callback(forwardLoader, "ADDON_LOADED", "ZDecursive")
Check(ZDecursiveDiagnosticsDB == forward and forward.preserved == true, "future diagnostics schema is never overwritten")
Check(forwardNS.PersistentDiagnostics.Status().forwardSchema == true, "future schema uses isolated runtime fallback")

io.write("persistent-diagnostics-contract: ok\n")
