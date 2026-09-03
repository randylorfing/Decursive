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

local ADDON_NAME, ns = ...

local SCHEMA = 1
local CRITICAL_MAX_ENTRIES = 192
local CRITICAL_MAX_BYTES = 96 * 1024
local VERBOSE_MAX_ENTRIES = 768
local VERBOSE_MAX_BYTES = 512 * 1024
local MAX_FIELDS = 64
local MAX_STRING_BYTES = 80
local CONVERGENCE_DELAYS = {0.10, 0.35, 1.00, 2.00, 4.00, 7.00, 10.00}

local globals = _G
local diagnostics = ns.Diagnostics
local session
local database
local initialized = false
local pendingRecords = {}
local pendingVerbose
local persistentAPI
local convergenceGeneration = 0
local PENDING_RECORD_MAX = 64

local function Accessible(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then
      return false, "<secret>"
    end
  end
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    if not ok or accessible ~= true then
      return false, "<unavailable>"
    end
  end
  return true
end

local function PublicType(value)
  local accessible, sentinel = Accessible(value)
  if not accessible then
    return nil, sentinel
  end
  local ok, kind = pcall(type, value)
  if not ok then
    return nil, "<unavailable>"
  end
  return kind
end

local function NewRing(maxEntries, maxBytes)
  return {
    entries = {},
    bytes = 0,
    maxEntries = maxEntries,
    maxBytes = maxBytes,
  }
end

local function NormalizeRing(value, maxEntries, maxBytes)
  if type(value) ~= "table" then
    return NewRing(maxEntries, maxBytes)
  end
  if type(value.entries) ~= "table" then
    value.entries = {}
  end
  value.maxEntries = maxEntries
  value.maxBytes = maxBytes
  value.bytes = tonumber(value.bytes) or 0
  return value
end

local function BoundLoadedRing(ring)
  local bytes = 0
  for i = #ring.entries, 1, -1 do
    local entry = ring.entries[i]
    if type(entry) ~= "table" then
      table.remove(ring.entries, i)
    else
      local entryBytes = math.max(1, math.floor(tonumber(entry._bytes) or 256))
      entry._bytes = entryBytes
      bytes = bytes + entryBytes
    end
  end
  ring.bytes = bytes
  while #ring.entries > ring.maxEntries or ring.bytes > ring.maxBytes do
    local removed = table.remove(ring.entries, 1)
    ring.bytes = math.max(0, ring.bytes - (tonumber(removed and removed._bytes) or 0))
  end
end

local function NewDatabase()
  return {
    schema = SCHEMA,
    enabled = false,
    nextSession = 1,
    nextSequence = 1,
    critical = NewRing(CRITICAL_MAX_ENTRIES, CRITICAL_MAX_BYTES),
    verbose = NewRing(VERBOSE_MAX_ENTRIES, VERBOSE_MAX_BYTES),
    counters = {},
    lastSnapshot = {},
  }
end

local function InitializeDatabase()
  local raw = globals and rawget(globals, "ZDecursiveDiagnosticsDB") or nil
  if type(raw) == "table" and type(raw.schema) == "number" and raw.schema > SCHEMA then
    database = NewDatabase()
    database.forwardSchema = true
    return
  end
  if type(raw) ~= "table" then
    raw = NewDatabase()
    if globals then
      globals.ZDecursiveDiagnosticsDB = raw
    end
  end
  raw.critical = NormalizeRing(raw.critical, CRITICAL_MAX_ENTRIES, CRITICAL_MAX_BYTES)
  raw.verbose = NormalizeRing(raw.verbose, VERBOSE_MAX_ENTRIES, VERBOSE_MAX_BYTES)
  BoundLoadedRing(raw.critical)
  BoundLoadedRing(raw.verbose)
  raw.counters = type(raw.counters) == "table" and raw.counters or {}
  raw.lastSnapshot = type(raw.lastSnapshot) == "table" and raw.lastSnapshot or {}
  raw.enabled = raw.enabled == true
  raw.nextSession = math.max(1, math.floor(tonumber(raw.nextSession) or 1))
  raw.nextSequence = math.max(1, math.floor(tonumber(raw.nextSequence) or 1))
  raw.schema = SCHEMA
  database = raw
end

local function SessionVersion()
  local api = C_AddOns and C_AddOns.GetAddOnMetadata
  if type(api) ~= "function" then
    return "unavailable"
  end
  local ok, value = pcall(api, ADDON_NAME, "Version")
  local kind, sentinel = PublicType(value)
  if not ok or kind ~= "string" or #value > MAX_STRING_BYTES or value:find("[\\/]") then
    return sentinel or "unavailable"
  end
  return value
end

local function StartSession()
  session = database.nextSession
  database.nextSession = database.nextSession + 1
  database.lastSession = session
  database.lastVersion = SessionVersion()
end

local function PublicScalar(value)
  local kind, sentinel = PublicType(value)
  if not kind then
    return sentinel
  end
  if kind == "boolean" then
    return value
  end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "<unavailable>"
    end
    return math.floor(value * 1000 + 0.5) / 1000
  end
  if kind == "string" then
    if #value > MAX_STRING_BYTES then
      return "<redacted>"
    end
    if value == "<secret>" or value == "<unavailable>" or value == "<redacted>" then
      return value
    end
    if value:match("^[A-Za-z0-9_.:+-]+$") then
      return value
    end
    return "<redacted>"
  end
  return "<unavailable>"
end

local function SafeFields(fields)
  local result = {}
  if PublicType(fields) ~= "table" then
    return result
  end
  local count = 0
  for key, value in pairs(fields) do
    local keyType = PublicType(key)
    if keyType == "string" and #key <= 32 and key:match("^[A-Za-z][A-Za-z0-9]*$") then
      count = count + 1
      if count > MAX_FIELDS then
        break
      end
      result[key] = PublicScalar(value)
    end
  end
  return result
end

local function StableSignature(record)
  local keys = {}
  for key in pairs(record.fields) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local parts = {record.kind}
  for i = 1, #keys do
    local key = keys[i]
    parts[#parts + 1] = key .. "=" .. tostring(record.fields[key])
  end
  return table.concat(parts, "|")
end

local function EstimateBytes(record)
  local bytes = 72 + #record.kind + #record.stamp + #record.version
  for key, value in pairs(record.fields) do
    bytes = bytes + #key + #tostring(value) + 8
  end
  return bytes
end

local function TrimRing(ring)
  while #ring.entries > ring.maxEntries or ring.bytes > ring.maxBytes do
    local removed = table.remove(ring.entries, 1)
    ring.bytes = math.max(0, ring.bytes - (tonumber(removed and removed._bytes) or 0))
  end
end

local function Stamp()
  if type(time) == "function" then
    local ok, value = pcall(time)
    local kind = ok and PublicType(value)
    if kind == "number" then
      return tostring(math.floor(value))
    end
  end
  return "unavailable"
end

local function Record(kind, fields, verbose)
  kind = PublicScalar(kind)
  if type(kind) ~= "string" or kind:sub(1, 1) == "<" then
    kind = "UNKNOWN"
  end
  fields = SafeFields(fields)
  if not initialized or type(database) ~= "table" then
    if #pendingRecords >= PENDING_RECORD_MAX then
      table.remove(pendingRecords, 1)
    end
    pendingRecords[#pendingRecords + 1] = {
      kind = kind,
      fields = fields,
      verbose = verbose == true,
    }
    return false
  end
  local ring = verbose == true and database.verbose or database.critical
  local counterKey = verbose == true and "verboseSeen" or "criticalSeen"
  database.counters[counterKey] = (tonumber(database.counters[counterKey]) or 0) + 1
  if verbose == true and database.enabled ~= true then
    database.counters.verboseSuppressed = (tonumber(database.counters.verboseSuppressed) or 0) + 1
    return false
  end
  local record = {
    sequence = database.nextSequence,
    session = session,
    stamp = Stamp(),
    version = database.lastVersion or "unavailable",
    kind = kind,
    fields = fields,
  }
  database.nextSequence = database.nextSequence + 1
  record._signature = StableSignature(record)
  local previous = ring.entries[#ring.entries]
  if previous and previous._signature == record._signature then
    previous.repeatCount = math.min(9999, (tonumber(previous.repeatCount) or 1) + 1)
    previous.lastStamp = record.stamp
    database.counters.deduplicated = (tonumber(database.counters.deduplicated) or 0) + 1
    return true
  end
  record._bytes = EstimateBytes(record)
  ring.entries[#ring.entries + 1] = record
  ring.bytes = ring.bytes + record._bytes
  TrimRing(ring)
  return true
end

local function PublicCall(callback, ...)
  if type(callback) ~= "function" then
    return nil, "<unavailable>"
  end
  local ok, value = pcall(callback, ...)
  if not ok then
    return nil, "<unavailable>"
  end
  local kind, sentinel = PublicType(value)
  if not kind then
    return nil, sentinel
  end
  return value
end

local function Marker(callback, ...)
  local value, sentinel = PublicCall(callback, ...)
  if sentinel then
    return sentinel
  end
  if value == true or value == 1 then
    return "TRUE"
  end
  if value == false or value == 0 or value == nil then
    return "FALSE"
  end
  return "<unavailable>"
end

local function PublicCount(callback, ...)
  local value, sentinel = PublicCall(callback, ...)
  if sentinel then
    return sentinel
  end
  if type(value) == "number" and value >= 0 then
    return math.floor(value)
  end
  return "<unavailable>"
end

local function PublicInstanceType()
  if type(GetInstanceInfo) ~= "function" then
    return "<unavailable>"
  end
  local ok, _name, instanceType = pcall(GetInstanceInfo)
  local kind, sentinel = PublicType(instanceType)
  if not ok or kind ~= "string" then
    return sentinel or "<unavailable>"
  end
  return PublicScalar(instanceType)
end

local function UnitMarkers(fields, prefix, unit)
  fields[prefix .. "Exists"] = Marker(UnitExists, unit)
  fields[prefix .. "Connected"] = Marker(UnitIsConnected, unit)
  fields[prefix .. "Dead"] = Marker(UnitIsDeadOrGhost, unit)
end

local function EnvironmentFields(fields)
  local addon = ns.addon
  if not addon or type(addon.GetEnvironmentProfileStatus) ~= "function" then
    return
  end
  local ok, status = pcall(addon.GetEnvironmentProfileStatus, addon)
  if not ok or type(status) ~= "table" then
    return
  end
  fields.routingMode = status.environmentMode
  fields.detected = status.detectedEnvironment
  fields.resolvedPack = status.resolvedEnvironment
  fields.appliedPack = status.appliedEnvironment
  fields.editingPack = status.editingEnvironment
  fields.pendingPack = status.pendingEnvironment or "NONE"
end

local function CaptureSnapshot(reason, pass)
  local fields = {
    reason = reason,
    pass = pass or 0,
    combat = Marker(InCombatLockdown),
    inGroup = Marker(IsInGroup),
    inRaid = Marker(IsInRaid),
    instanceType = PublicInstanceType(),
    subgroup = PublicCount(GetNumSubgroupMembers),
    groupMembers = PublicCount(GetNumGroupMembers),
  }
  UnitMarkers(fields, "player", "player")
  UnitMarkers(fields, "pet", "pet")
  for i = 1, 4 do
    UnitMarkers(fields, "p" .. i, "party" .. i)
    UnitMarkers(fields, "pp" .. i, "partypet" .. i)
  end
  if type(ns.GetRosterContextStatus) == "function" then
    local ok, context = pcall(ns.GetRosterContextStatus)
    if ok and type(context) == "table" then
      fields.rosterContext = context.kind
      fields.contextReady = context.ready == true
      fields.contextReason = context.reason or context.transitionReason or "NONE"
      fields.realPartyCount = context.realPartyCount
    end
  end
  EnvironmentFields(fields)
  if initialized and type(database) == "table" then
    database.lastSnapshot = SafeFields(fields)
  end
  Record("SNAPSHOT", fields, false)
  return fields
end

local function ScheduleSnapshots(reason)
  if not initialized then
    Record("SNAPSHOT_REQUEST", {reason = reason}, true)
    return false
  end
  convergenceGeneration = convergenceGeneration + 1
  local generation = convergenceGeneration
  CaptureSnapshot(reason, 0)
  if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
    return
  end
  for i = 1, #CONVERGENCE_DELAYS do
    local delay = CONVERGENCE_DELAYS[i]
    C_Timer.After(delay, function()
      if generation == convergenceGeneration then
        CaptureSnapshot(reason, i)
      end
    end)
  end
end

local function Clear()
  if not initialized or type(database) ~= "table" then
    pendingRecords = {}
    return false
  end
  database.critical = NewRing(CRITICAL_MAX_ENTRIES, CRITICAL_MAX_BYTES)
  database.verbose = NewRing(VERBOSE_MAX_ENTRIES, VERBOSE_MAX_BYTES)
  database.counters = {}
  database.lastSnapshot = {}
  if diagnostics and diagnostics.ClearRuntimeLog then
    diagnostics.ClearRuntimeLog()
  end
  Record("CLEARED", {reason = "USER"}, false)
end

local function Status()
  if not initialized or type(database) ~= "table" then
    return {
      schema = SCHEMA,
      initialized = false,
      forwardSchema = false,
      verbose = pendingVerbose == true,
      session = nil,
      criticalEntries = 0,
      criticalBytes = 0,
      verboseEntries = 0,
      verboseBytes = 0,
      deduplicated = 0,
      verboseSuppressed = 0,
      pendingRecords = #pendingRecords,
    }
  end
  return {
    schema = database.schema,
    initialized = true,
    forwardSchema = database.forwardSchema == true,
    verbose = database.enabled == true,
    session = session,
    criticalEntries = #database.critical.entries,
    criticalBytes = database.critical.bytes,
    verboseEntries = #database.verbose.entries,
    verboseBytes = database.verbose.bytes,
    deduplicated = tonumber(database.counters.deduplicated) or 0,
    verboseSuppressed = tonumber(database.counters.verboseSuppressed) or 0,
  }
end

local function AppendEntry(lines, channel, entry)
  local fields = {}
  for key, value in pairs(entry.fields or {}) do
    fields[#fields + 1] = key .. "=" .. tostring(value)
  end
  table.sort(fields)
  lines[#lines + 1] = table.concat({
    channel,
    tostring(entry.sequence or 0),
    tostring(entry.session or 0),
    tostring(entry.stamp or "unavailable"),
    tostring(entry.kind or "UNKNOWN"),
    table.concat(fields, " "),
    (entry.repeatCount and "repeat=" .. tostring(entry.repeatCount) or ""),
  }, " | ")
end

local function BuildExport()
  local status = Status()
  local lines = {
    "Zhaohu's Decursive Persistent Diagnostics",
    "Privacy: no names, realms, GUIDs, profile names, raw spell/aura/item IDs, macros, or filesystem paths.",
    "Run /reload before sharing the SavedVariables file. WoW writes SavedVariables on logout or reload.",
    "schema=" .. tostring(status.schema) .. " session=" .. tostring(status.session) .. " verbose=" .. tostring(status.verbose),
    "critical=" .. tostring(status.criticalEntries) .. "/" .. tostring(status.criticalBytes) .. "B verbose=" .. tostring(status.verboseEntries) .. "/" .. tostring(status.verboseBytes) .. "B",
    "",
  }
  if initialized and type(database) == "table" then
    for i = 1, #database.critical.entries do
      AppendEntry(lines, "critical", database.critical.entries[i])
    end
    for i = 1, #database.verbose.entries do
      AppendEntry(lines, "verbose", database.verbose.entries[i])
    end
  end
  return table.concat(lines, "\n")
end

local function ShowText(text)
  if diagnostics and type(diagnostics.ShowText) == "function" then
    return diagnostics.ShowText(text)
  end
  if diagnostics and type(diagnostics.Show) == "function" then
    return diagnostics.Show()
  end
  return false
end

local function ShowStatus()
  local status = Status()
  local lines = {
    "Zhaohu's Decursive Diagnostic Status",
    "schema=" .. tostring(status.schema),
    "session=" .. tostring(status.session),
    "verbose=" .. tostring(status.verbose),
    "critical entries=" .. tostring(status.criticalEntries) .. " bytes=" .. tostring(status.criticalBytes),
    "verbose entries=" .. tostring(status.verboseEntries) .. " bytes=" .. tostring(status.verboseBytes),
    "deduplicated=" .. tostring(status.deduplicated),
    "Run /reload before sharing the SavedVariables file. WoW writes it only on logout or reload.",
  }
  return ShowText(table.concat(lines, "\n"))
end

local function HandleCommand(message)
  local command = type(message) == "string" and message:match("^%s*(%S+)") or nil
  command = command and command:lower() or ""
  if not initialized or type(database) ~= "table" then
    return ShowText(table.concat({
      "Zhaohu's Decursive Diagnostic Status",
      "Diagnostics are waiting for ADDON_LOADED.",
      "No SavedVariables have been read or changed.",
    }, "\n"))
  end
  if command == "clear" then
    Clear()
    return ShowStatus()
  elseif command == "start" then
    database.enabled = true
    Record("MONITOR", {state = "STARTED"}, false)
    return ShowStatus()
  elseif command == "stop" then
    Record("MONITOR", {state = "STOPPED"}, false)
    database.enabled = false
    return ShowStatus()
  elseif command == "mark" then
    database.counters.marks = (tonumber(database.counters.marks) or 0) + 1
    Record("MARK", {marker = database.counters.marks}, false)
    return ShowStatus()
  elseif command == "status" then
    CaptureSnapshot("STATUS", 0)
    return ShowStatus()
  elseif command == "export" then
    CaptureSnapshot("EXPORT", 0)
    return ShowText(BuildExport())
  elseif command == "monitor" then
    database.enabled = true
    Record("MONITOR", {state = "STARTED"}, false)
    if type(ns.RequestRosterConvergence) == "function" then
      ns.RequestRosterConvergence("DIAGNOSTIC_MONITOR")
    end
    ScheduleSnapshots("MONITOR")
    return ShowText(BuildExport())
  elseif command == "health" then
    if diagnostics and type(diagnostics.RunHealthCheck) == "function" then
      return diagnostics.RunHealthCheck(true)
    end
    Record("HEALTH_CHECK", {verdict = "UNAVAILABLE", firstStage = "DIAGNOSTICS"}, false)
    return ShowStatus()
  end
  if diagnostics and diagnostics.Show then
    return diagnostics.Show()
  end
  return false
end

local function RegisterEvents()
  if type(CreateFrame) ~= "function" then
    return
  end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_self, event, arg1)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
      local kind = PublicType(arg1)
      if kind == "string" and arg1 == ADDON_NAME then
        Record("ADDON_ERROR", {event = event}, false)
      end
      return
    end
    Record("EVENT", {event = event}, false)
    ScheduleSnapshots(event)
  end)
  local events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LEAVING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE",
    "GROUP_JOINED",
    "GROUP_LEFT",
    "UNIT_PET",
    "LFG_UPDATE",
    "LFG_COMPLETION_REWARD",
    "SCENARIO_UPDATE",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "PLAYER_DIFFICULTY_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
    "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN",
    "PLAYER_LOGOUT",
  }
  for i = 1, #events do
    local event = events[i]
    local valid = true
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
      local ok, result = pcall(C_EventUtils.IsEventValid, event)
      valid = ok and result == true
    end
    if valid then
      pcall(frame.RegisterEvent, frame, event)
    end
  end
end

local function RegisterSlashCommands()
  SlashCmdList = SlashCmdList or {}
  SLASH_ZDECURSIVEDIAGNOSTICS1 = "/zdiag"
  SLASH_ZDECURSIVEDIAGNOSTICS2 = "/zdiagnostics"
  SlashCmdList.ZDECURSIVEDIAGNOSTICS = HandleCommand
end

local function FlushPendingRecords()
  local queued = pendingRecords
  pendingRecords = {}
  for i = 1, #queued do
    local entry = queued[i]
    Record(entry.kind, entry.fields, entry.verbose)
  end
end

local function InitializeAfterAddonLoaded()
  if initialized then
    return false
  end
  InitializeDatabase()
  StartSession()
  initialized = true
  if pendingVerbose ~= nil then
    database.enabled = pendingVerbose == true
  end
  persistentAPI.Database = database
  RegisterEvents()
  RegisterSlashCommands()
  Record("SESSION", {state = "STARTED", session = session}, false)
  FlushPendingRecords()
  return true
end

persistentAPI = {
  Record = Record,
  CaptureSnapshot = CaptureSnapshot,
  ScheduleSnapshots = ScheduleSnapshots,
  BuildExport = BuildExport,
  Status = Status,
  Clear = Clear,
  HandleCommand = HandleCommand,
  Database = nil,
  SetVerbose = function(enabled)
    if initialized and type(database) == "table" then
      database.enabled = enabled == true
    else
      pendingVerbose = enabled == true
    end
  end,
  HashSignature = function(value)
    local kind, sentinel = PublicType(value)
    if kind ~= "string" then
      return sentinel or "<unavailable>"
    end
    local hash = 2166136261
    for i = 1, #value do
      hash = (hash * 16777619 + value:byte(i)) % 4294967291
    end
    return string.format("%08x", hash)
  end,
}

ns.PersistentDiagnostics = persistentAPI

ns.DiagnosticRecord = Record
ns.DiagnosticCaptureSnapshot = CaptureSnapshot

if diagnostics and type(diagnostics.RegisterProvider) == "function" then
  diagnostics.RegisterProvider("PersistentDiagnostics", Status)
end

if type(CreateFrame) == "function" then
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:SetScript("OnEvent", function(self, event, loadedName)
    if event ~= "ADDON_LOADED" then
      return
    end
    local kind = PublicType(loadedName)
    if kind ~= "string" or loadedName ~= ADDON_NAME then
      return
    end
    if self and type(self.UnregisterEvent) == "function" then
      self:UnregisterEvent("ADDON_LOADED")
    end
    InitializeAfterAddonLoaded()
  end)
end
