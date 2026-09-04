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

local MAX_LOG_ENTRIES = 240
local PROFILE_SCHEMA = 3
local providers = {}
local providerOrder = {}
local runtimeLog = {}
local moduleState = {}
local refreshState = {}
local window
local menuButton
local lastReport = ""
local restoringText = false
local lastHealthCheck

local HEALTH_RANK = {
  HEALTHY = 1,
  RECOVERING = 2,
  DEFERRED = 2,
  FAILED = 3,
}

local HEALTH_CONSUMERS = {"MUFs", "Alerts", "LiveList"}
local MULTIPLE_ENVIRONMENTS = {
  OPEN_WORLD = true,
  DUNGEON = true,
  MYTHIC_PLUS = true,
  RAID = true,
  PVP = true,
}

local state = {
  phase = "diagnostics-file-loaded",
  lastMilestone = "diagnostics file loaded",
  sequence = 0,
  coreInitialize = "not-started",
  coreEnable = "not-started",
}

local REQUIRED_MODULES = {"Core", "Detection", "MUFs", "Lists", "LiveList", "Alerts", "Options"}
for i = 1, #REQUIRED_MODULES do
  moduleState[REQUIRED_MODULES[i]] = {loaded = false, enabled = false}
end

local SAFE_STRINGS = {
  account = true,
  character = true,
  specialization = true,
  default = true,
  unknown = true,
  unavailable = true,
  available = true,
  absent = true,
  present = true,
  valid = true,
  malformed = true,
  forward = true,
  current = true,
  OPEN_WORLD = true,
  DUNGEON = true,
  MYTHIC_PLUS = true,
  RAID = true,
  PVP = true,
  SOLO = true,
  HORIZONTAL = true,
  VERTICAL = true,
  multiple = true,
  solo = true,
  ACTIVE_CHALLENGE = true,
  PVP_INSTANCE = true,
  RAID_INSTANCE = true,
  PARTY_INSTANCE = true,
  RAID_GROUP = true,
  OPEN_WORLD_CONTEXT = true,
  UNKNOWN_INSTANCE = true,
  CONTEXT_UNAVAILABLE = true,
  challenge = true,
  instance = true,
  group = true,
  fallback = true,
  suppressedBySkull = true,
  boot = true,
  combat = true,
  core = true,
  module = true,
  runtime = true,
  started = true,
  success = true,
  ["not-started"] = true,
  ["nil"] = true,
  boolean = true,
  number = true,
  string = true,
  table = true,
  ["function"] = true,
  userdata = true,
  thread = true,
  secret = true,
  inaccessible = true,
}

local function IsSecret(value)
  if type(issecretvalue) ~= "function" then
    if type(canaccessvalue) == "function" then
      local ok, accessible = pcall(canaccessvalue, value)
      return not ok or accessible ~= true
    end
    return false
  end
  local ok, secret = pcall(issecretvalue, value)
  if not ok or secret == true then
    return true
  end
  if type(value) == "table" and type(issecrettable) == "function" then
    local tableOK, secretTable = pcall(issecrettable, value)
    if not tableOK or secretTable == true then
      return true
    end
  end
  if type(canaccessvalue) == "function" then
    local accessOK, accessible = pcall(canaccessvalue, value)
    if not accessOK or accessible ~= true then
      return true
    end
  end
  return false
end

local function SafeType(value)
  if IsSecret(value) then
    return "secret"
  end
  local ok, kind = pcall(type, value)
  if not ok then
    return "inaccessible"
  end
  return kind
end

local function SafeIndex(container, key)
  if IsSecret(container) or IsSecret(key) then
    return nil, false
  end
  if type(container) ~= "table" then
    return nil, false
  end
  local ok, value = pcall(rawget, container, key)
  if not ok then
    return nil, false
  end
  if IsSecret(value) then
    return value, true
  end
  return value, true
end

local function SafePublicBoolean(value)
  if IsSecret(value) then
    return nil
  end
  if value == true then
    return true
  end
  if value == false then
    return false
  end
  return nil
end

local function SafePublicNumber(value)
  if IsSecret(value) then
    return nil
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function SafeToken(value)
  if IsSecret(value) or type(value) ~= "string" then
    return nil
  end
  if SAFE_STRINGS[value] then
    return value
  end
  if value:match("^[A-Z][A-Za-z0-9]*$") and #value <= 40 then
    return value
  end
  if value:match("^[A-Z][A-Z0-9_]*$") and #value <= 40 then
    return value
  end
  return nil
end

local function TimeStamp()
  if type(date) == "function" then
    local ok, value = pcall(date, "%H:%M:%S")
    if ok and not IsSecret(value) and type(value) == "string" then
      return value
    end
  end
  if type(GetTime) == "function" then
    local ok, value = pcall(GetTime)
    if ok and not IsSecret(value) and type(value) == "number" then
      return tostring(math.floor(value * 1000) / 1000)
    end
  end
  return "boot"
end

local function AppendLog(kind, message)
  state.sequence = state.sequence + 1
  runtimeLog[#runtimeLog + 1] = {
    sequence = state.sequence,
    stamp = TimeStamp(),
    kind = SafeToken(kind) or "INFO",
    message = not IsSecret(message) and type(message) == "string" and message or "diagnostic checkpoint",
  }
  while #runtimeLog > MAX_LOG_ENTRIES do
    table.remove(runtimeLog, 1)
  end
end

local function Checkpoint(phase, milestone)
  phase = SafeToken(phase) or "runtime"
  milestone = not IsSecret(milestone) and type(milestone) == "string" and milestone or "checkpoint"
  state.phase = phase
  state.lastMilestone = milestone
  AppendLog("CHECKPOINT", phase .. ": " .. milestone)
end

local function MarkModuleLoaded(name)
  name = SafeToken(name)
  if not name then
    return
  end
  local row = moduleState[name] or {}
  row.loaded = true
  moduleState[name] = row
  Checkpoint("module", name .. " file loaded")
end

local function MarkModuleEnabled(name, enabled)
  name = SafeToken(name)
  if not name then
    return
  end
  local row = moduleState[name] or {}
  row.enabled = enabled == true
  moduleState[name] = row
  Checkpoint("module", name .. (enabled == true and " enabled" or " enable started"))
end

local function MarkModuleRefresh(name)
  name = SafeToken(name)
  if not name then
    return
  end
  refreshState[name] = (refreshState[name] or 0) + 1
  AppendLog("REFRESH", name .. " refresh " .. tostring(refreshState[name]))
end

local function RegisterProvider(name, callback)
  name = SafeToken(name)
  if not name or IsSecret(callback) or type(callback) ~= "function" then
    return false
  end
  if not providers[name] then
    providerOrder[#providerOrder + 1] = name
  end
  providers[name] = callback
  return true
end

local function Probe(callback, ...)
  if IsSecret(callback) or type(callback) ~= "function" then
    return nil, false
  end
  local ok, first, second, third, fourth, fifth, sixth, seventh, eighth = pcall(callback, ...)
  if not ok then
    return nil, false
  end
  return {first, second, third, fourth, fifth, sixth, seventh, eighth}, true
end

local function AddOnMetadata(field)
  local api = C_AddOns and C_AddOns.GetAddOnMetadata
  local values, ok = Probe(api, ADDON_NAME, field)
  if not ok or IsSecret(values[1]) then
    return nil
  end
  local value = values[1]
  if type(value) == "string" and #value <= 80 and not value:find("[\\/]") then
    return value
  end
  return nil
end

local function AddOnRuntimeStatus()
  local result = {
    loaded = "unknown",
    enabled = "unknown",
    loadable = "unknown",
    reason = "unavailable",
  }
  local loadedAPI = C_AddOns and C_AddOns.IsAddOnLoaded
  local loadedValues, loadedOk = Probe(loadedAPI, ADDON_NAME)
  if loadedOk then
    result.loaded = SafePublicBoolean(loadedValues[1])
    if result.loaded == nil then
      result.loaded = "unknown"
    end
  end
  local infoAPI = C_AddOns and C_AddOns.GetAddOnInfo
  local infoValues, infoOk = Probe(infoAPI, ADDON_NAME)
  if infoOk then
    result.loadable = SafePublicBoolean(infoValues[4])
    if result.loadable == nil then
      result.loadable = "unknown"
    end
    result.reason = SafeToken(infoValues[5]) or result.reason
  end
  local enabledAPI = C_AddOns and C_AddOns.GetAddOnEnableState
  local character
  local characterValues, characterOk = Probe(UnitName, "player")
  if characterOk and not IsSecret(characterValues[1]) and type(characterValues[1]) == "string" then
    character = characterValues[1]
  end
  local enabledValues, enabledOk = Probe(enabledAPI, ADDON_NAME, character)
  if enabledOk and not IsSecret(enabledValues[1]) then
    local enabled = enabledValues[1]
    if type(enabled) == "boolean" then
      result.enabled = enabled
    elseif type(enabled) == "number" then
      result.enabled = enabled > 0
    end
  end
  return result
end

local function RawDatabaseStatus()
  local rawValues, rawOk = Probe(rawget, _G, "DecursiveRebuildDB")
  local raw = rawOk and rawValues[1] or nil
  local rawSecret = IsSecret(raw)
  local result = {
    presence = not rawSecret and raw == nil and "absent" or "present",
    valueType = SafeType(raw),
    schema = "unavailable",
    forwardSchema = "unknown",
  }
  if rawSecret then
    return result
  end
  if result.valueType ~= "table" then
    if raw ~= nil then
      result.schema = "malformed"
      result.forwardSchema = "unknown"
    end
    return result
  end
  local global, globalOk = SafeIndex(raw, "global")
  if not globalOk or SafeType(global) ~= "table" then
    result.schema = "malformed"
    return result
  end
  local schema, schemaOk = SafeIndex(global, "schema")
  schema = schemaOk and SafePublicNumber(schema) or nil
  if not schema then
    result.schema = "malformed"
    return result
  end
  result.schema = schema
  result.forwardSchema = schema > PROFILE_SCHEMA and "forward" or "current"
  return result
end

local function AceStatus()
  local libStubType = SafeType(LibStub)
  local result = {
    libStub = libStubType == "table" or libStubType == "function",
    aceAddon = false,
    aceDB = false,
    addonObject = SafeType(ns.addon) == "table",
  }
  if result.libStub then
    local addonOk, addonLibrary = pcall(LibStub, "AceAddon-3.0", true)
    local dbOk, dbLibrary = pcall(LibStub, "AceDB-3.0", true)
    local addonType = addonOk and SafeType(addonLibrary) or "nil"
    local dbType = dbOk and SafeType(dbLibrary) or "nil"
    result.aceAddon = addonType ~= "nil" and addonType ~= "secret" and addonType ~= "inaccessible"
    result.aceDB = dbType ~= "nil" and dbType ~= "secret" and dbType ~= "inaccessible"
  end
  return result
end

local function LockdownStatus()
  local combatValues, combatOk = Probe(InCombatLockdown)
  local chatValues, chatOk = Probe(InChatMessagingLockdown)
  local combat
  local chat
  if combatOk then
    combat = SafePublicBoolean(combatValues[1])
  end
  if chatOk then
    chat = SafePublicBoolean(chatValues[1])
  end
  return {
    combat = combat == nil and "unknown" or combat,
    chat = chat == nil and "unknown" or chat,
  }
end

local PROFILE_PREFLIGHT_REASONS = {
  ["missing"] = "MISSING",
  ["current-or-older"] = "CURRENT_OR_OLDER",
  ["legacy-or-fresh"] = "LEGACY_OR_FRESH",
  ["not-run"] = "NOT_RUN",
  ["unavailable"] = "UNAVAILABLE",
  ["forward-schema"] = "FORWARD_SCHEMA",
  ["malformed-root"] = "MALFORMED_ROOT",
  ["malformed-schema"] = "MALFORMED_SCHEMA",
  ["malformed-global"] = "MALFORMED_GLOBAL",
  ["malformed-section"] = "MALFORMED_SECTION",
  ["malformed-storage"] = "MALFORMED_STORAGE",
  ["malformed-value"] = "MALFORMED_VALUE",
  ["malformed-key"] = "MALFORMED_KEY",
  ["malformed-number"] = "MALFORMED_NUMBER",
  ["secret-storage"] = "SECRET_STORAGE",
  ["secret-value"] = "SECRET_VALUE",
  ["scan-failed"] = "SCAN_FAILED",
  ["node-limit"] = "NODE_LIMIT",
  ["byte-limit"] = "BYTE_LIMIT",
  ["depth-limit"] = "DEPTH_LIMIT",
  ["cycle-or-alias"] = "CYCLE_OR_ALIAS",
  ["metatable"] = "METATABLE",
}

local function PublicField(container, key)
  local value, ok = SafeIndex(container, key)
  if not ok or IsSecret(value) then
    return nil
  end
  return value
end

local function PublicBooleanField(container, key)
  return SafePublicBoolean(PublicField(container, key))
end

local function PublicNumberField(container, key)
  return SafePublicNumber(PublicField(container, key))
end

local function PublicEnumField(container, key, allowed)
  local value = PublicField(container, key)
  if type(value) == "string" and allowed[value] then
    return value
  end
  return nil
end

local function ProfilePreflightStatus()
  local values, ok = Probe(ns.GetProfileStoragePreflightStatus)
  if not ok or SafeType(values[1]) ~= "table" then
    return {available = false, ok = false, reason = "GETTER_UNAVAILABLE"}
  end
  local source = values[1]
  local reason = PublicField(source, "reason")
  return {
    available = true,
    ok = SafePublicBoolean(PublicField(source, "ok")),
    reason = type(reason) == "string" and PROFILE_PREFLIGHT_REASONS[reason] or "UNAVAILABLE",
    nodes = SafePublicNumber(PublicField(source, "nodes")),
    bytes = SafePublicNumber(PublicField(source, "bytes")),
    maxDepth = SafePublicNumber(PublicField(source, "maxDepth")),
  }
end

local CLICK_MODES = {AUTO = true, MANUAL = true}

local function PublicSequenceCount(value, limit)
  if IsSecret(value) or type(value) ~= "table" then
    return nil
  end
  local count = 0
  local maximum = math.max(0, math.floor(limit or 64))
  for i = 1, maximum do
    local child, ok = SafeIndex(value, i)
    if not ok or child == nil then
      break
    end
    count = count + 1
  end
  return count
end

local function ResolvedClickStatus()
  local values, ok = Probe(ns.GetResolvedClickStatus)
  if not ok or SafeType(values[1]) ~= "table" then
    return {getterAvailable = false, available = false, pending = false, mappingCount = 0}
  end
  local source = values[1]
  return {
    getterAvailable = true,
    available = SafePublicBoolean(PublicField(source, "available")),
    pending = SafePublicBoolean(PublicField(source, "pending")),
    mode = PublicEnumField(source, "mode", CLICK_MODES) or "UNAVAILABLE",
    generation = SafePublicNumber(PublicField(source, "generation")),
    mappingCount = PublicSequenceCount(PublicField(source, "mappings"), 32) or 0,
  }
end

local function BuildSnapshot()
  local buildValues, buildOk = Probe(GetBuildInfo)
  local addonStatus = AddOnRuntimeStatus()
  local build = buildOk and buildValues[2] or nil
  if IsSecret(build) or (type(build) ~= "number" and (type(build) ~= "string" or not build:match("^%d+$"))) then
    build = "unavailable"
  end
  local snapshot = {
    addon = {
      version = AddOnMetadata("Version") or "unavailable",
      interface = AddOnMetadata("Interface") or (buildOk and SafePublicNumber(buildValues[4])) or "unavailable",
      build = build,
      loaded = addonStatus.loaded,
      enabled = addonStatus.enabled,
      loadable = addonStatus.loadable,
      loadableReason = addonStatus.reason,
    },
    boot = {
      phase = state.phase,
      lastMilestone = state.lastMilestone,
      sequence = state.sequence,
      coreInitialize = state.coreInitialize,
      coreEnable = state.coreEnable,
    },
    ace = AceStatus(),
    rawDatabase = RawDatabaseStatus(),
    profilePreflight = ProfilePreflightStatus(),
    lockdown = LockdownStatus(),
    clickMapping = ResolvedClickStatus(),
    modules = {},
    providers = {},
    providerAvailability = {},
    recent = {},
  }
  for name, row in pairs(moduleState) do
    snapshot.modules[name] = {
      loaded = row.loaded == true,
      enabled = row.enabled == true,
      refreshes = refreshState[name] or 0,
    }
  end
  for i = 1, #providerOrder do
    local name = providerOrder[i]
    local callback = providers[name]
    local ok, value = pcall(callback)
    if ok then
      snapshot.providers[name] = value
      snapshot.providerAvailability[name] = true
    else
      snapshot.providers[name] = {providerFailure = true}
      snapshot.providerAvailability[name] = true
      AppendLog("ERROR", "provider " .. name .. " failed")
    end
  end
  for i = 1, #REQUIRED_MODULES do
    local name = REQUIRED_MODULES[i]
    if snapshot.providerAvailability[name] == nil then
      snapshot.providerAvailability[name] = false
    end
  end
  local first = math.max(1, #runtimeLog - 59)
  for i = first, #runtimeLog do
    local row = runtimeLog[i]
    snapshot.recent[#snapshot.recent + 1] = {
      sequence = row.sequence,
      stamp = row.stamp,
      kind = row.kind,
      message = row.message,
    }
  end
  return snapshot
end

local function SnapshotProvider(snapshot, name)
  local availability = PublicField(snapshot, "providerAvailability")
  local available = PublicBooleanField(availability, name)
  local providerTable = PublicField(PublicField(snapshot, "providers"), name)
  if available ~= true or SafeType(providerTable) ~= "table" then
    return nil, false
  end
  if PublicBooleanField(providerTable, "providerFailure") == true then
    return nil, false
  end
  return providerTable, true
end

local function AddHealthStage(stages, key, label, verdict, summary, action, integrationRequired)
  stages[#stages + 1] = {
    key = key,
    label = label,
    verdict = HEALTH_RANK[verdict] and verdict or "FAILED",
    summary = summary,
    action = action,
    integrationRequired = integrationRequired == true,
  }
end

local function TransitionVerdict(snapshot, detection, engine)
  local lockdown = PublicField(snapshot, "lockdown")
  if PublicBooleanField(lockdown, "combat") == true
      or PublicBooleanField(detection, "restrictionActive") == true
      or PublicEnumField(engine, "lifecycleState", {COMBAT_DEFERRED = true}) == "COMBAT_DEFERRED" then
    return "DEFERRED"
  end
  return "RECOVERING"
end

local function CountText(value)
  value = SafePublicNumber(value)
  if value == nil then
    return "?"
  end
  return tostring(math.floor(value))
end

local function EvaluateAddonStage(stages, snapshot)
  local addon = PublicField(snapshot, "addon")
  local boot = PublicField(snapshot, "boot")
  local ace = PublicField(snapshot, "ace")
  local loaded = PublicBooleanField(addon, "loaded")
  local enabled = PublicBooleanField(addon, "enabled")
  local loadable = PublicBooleanField(addon, "loadable")
  local initialize = PublicField(boot, "coreInitialize")
  local enable = PublicField(boot, "coreEnable")
  local version = PublicField(addon, "version")

  if loaded == false or enabled == false or loadable == false then
    AddHealthStage(stages, "ADDON_INIT", "Addon, version, and initialization", "FAILED",
      "The addon is not simultaneously loaded, enabled, and loadable.",
      "Enable one complete ZDecursive installation and restart the game client.")
  elseif initialize == "profile-storage-blocked" or enable == "profile-storage-blocked" then
    AddHealthStage(stages, "ADDON_INIT", "Addon, version, and initialization", "FAILED",
      "Initialization was stopped by the profile-storage safety barrier.",
      "Preserve the diagnostics report and inspect the profile preflight stage before changing settings.")
  elseif initialize ~= "success" or enable ~= "success" then
    AddHealthStage(stages, "ADDON_INIT", "Addon, version, and initialization", "RECOVERING",
      "Core initialization or enablement has not reached its success milestone.",
      "Wait for login and world entry to complete, then run the health check again.")
  elseif type(version) ~= "string" or version == "unavailable"
      or PublicBooleanField(ace, "aceAddon") ~= true
      or PublicBooleanField(ace, "aceDB") ~= true
      or PublicBooleanField(ace, "addonObject") ~= true then
    AddHealthStage(stages, "ADDON_INIT", "Addon, version, and initialization", "FAILED",
      "Required version metadata, Ace libraries, or the addon object is unavailable.",
      "Restart with one complete addon copy and capture this report if the failure remains.")
  else
    AddHealthStage(stages, "ADDON_INIT", "Addon, version, and initialization", "HEALTHY",
      "The addon is loaded and Core completed initialization and enablement.")
  end
end

local function EvaluateProfileStage(stages, snapshot, core, coreAvailable)
  local preflight = PublicField(snapshot, "profilePreflight")
  local rawDatabase = PublicField(snapshot, "rawDatabase")
  local preflightAvailable = PublicBooleanField(preflight, "available")
  local preflightOK = PublicBooleanField(preflight, "ok")
  local preflightReason = PublicField(preflight, "reason")
  local schema = PublicField(rawDatabase, "schema")
  local forwardSchema = PublicField(rawDatabase, "forwardSchema")

  if not coreAvailable then
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", "FAILED",
      "The Core diagnostic snapshot is unavailable.",
      "Capture the report after reload. Core must publish a sanitized runtime snapshot.")
  elseif preflightAvailable ~= true then
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", "RECOVERING",
      "Profile preflight cannot be evaluated because its public status getter is unavailable.",
      "Integration requirement: expose GetProfileStoragePreflightStatus without profile contents.", true)
  elseif preflightOK ~= true then
    local pending = preflightReason == "NOT_RUN"
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", pending and "RECOVERING" or "FAILED",
      pending and "Profile preflight has not run yet."
        or "Profile preflight rejected the saved profile structure with " .. tostring(preflightReason or "UNAVAILABLE") .. ".",
      pending and "Wait for initialization, then run the health check again."
        or "Preserve this report and inspect the profile database before any reset or migration.")
  elseif schema ~= PROFILE_SCHEMA or forwardSchema == "forward" then
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", "FAILED",
      "The loaded profile schema is not the supported current schema.",
      "Do not overwrite the profile. Preserve the report for migration review.")
  elseif PublicBooleanField(core, "aceDBBound") ~= true or PublicBooleanField(core, "currentProfileAvailable") ~= true then
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", "FAILED",
      "AceDB is not bound to an available current profile.",
      "Reload outside combat and capture the report if profile binding remains unavailable.")
  else
    AddHealthStage(stages, "PROFILE_PREFLIGHT", "Profile schema and preflight", "HEALTHY",
      "Profile preflight passed with " .. tostring(preflightReason or "UNAVAILABLE")
        .. " and schema " .. CountText(schema) .. " is current.")
  end
end

local ENVIRONMENT_VALUES = {
  OPEN_WORLD = true,
  DUNGEON = true,
  MYTHIC_PLUS = true,
  RAID = true,
  PVP = true,
  SOLO = true,
}

local ENVIRONMENT_MODES = {multiple = true, solo = true}

local function EvaluateRoutingStage(stages, snapshot, core, coreAvailable)
  if not coreAvailable then
    AddHealthStage(stages, "PROFILE_ROUTING", "Mode and environment routing", "FAILED",
      "Routing cannot be evaluated without the Core snapshot.",
      "Capture the report after Core initialization completes.")
    return
  end

  local mode = PublicEnumField(core, "environmentMode", ENVIRONMENT_MODES)
  local detected = PublicEnumField(core, "detectedEnvironment", ENVIRONMENT_VALUES)
  local resolved = PublicEnumField(core, "resolvedEnvironment", ENVIRONMENT_VALUES)
  local applied = PublicEnumField(core, "appliedEnvironment", ENVIRONMENT_VALUES)
  local editing = PublicEnumField(core, "editingEnvironment", ENVIRONMENT_VALUES)
  local pending = PublicEnumField(core, "pendingEnvironment", ENVIRONMENT_VALUES)
  local profilePending = PublicBooleanField(core, "profileResolvePending") == true
  local routingValid = mode ~= nil and detected ~= nil and resolved ~= nil and applied ~= nil and editing ~= nil

  if mode == "solo" then
    routingValid = routingValid and MULTIPLE_ENVIRONMENTS[detected] == true
      and resolved == "SOLO" and applied == "SOLO" and editing == "SOLO"
  elseif mode == "multiple" then
    routingValid = routingValid and MULTIPLE_ENVIRONMENTS[detected] == true
      and MULTIPLE_ENVIRONMENTS[resolved] == true
      and MULTIPLE_ENVIRONMENTS[applied] == true
      and MULTIPLE_ENVIRONMENTS[editing] == true
  end

  if pending or profilePending then
    AddHealthStage(stages, "PROFILE_ROUTING", "Mode and environment routing", TransitionVerdict(snapshot, nil, nil),
      "Routing has a pending resolved pack and keeps the applied pack stable.",
      "Wait until mutation is safe, then run the health check again.")
  elseif not routingValid or applied ~= resolved then
    AddHealthStage(stages, "PROFILE_ROUTING", "Mode and environment routing", "FAILED",
      "Mode, detected, resolved, applied, and editing environments violate their separation contract.",
      "Switch Profile Mode once outside combat, then capture a new report if routing remains inconsistent.")
  else
    local summary = mode == "solo"
      and "Solo mode applies and edits Solo while detected context remains separate."
      or "Multiple mode applies the detected environment while editing remains an independent selection."
    AddHealthStage(stages, "PROFILE_ROUTING", "Mode and environment routing", "HEALTHY", summary)
  end
end

local function EvaluateRosterStage(stages, snapshot, core, coreAvailable, detection, detectionAvailable)
  if not coreAvailable or not detectionAvailable then
    AddHealthStage(stages, "ROSTER_RECOVERY", "Roster, context, and world recovery", "FAILED",
      "Core or Detection roster status is unavailable.",
      "Reload and capture the report after both runtime providers initialize.")
    return
  end

  local exhausted = PublicBooleanField(core, "worldEntryRecoveryRetryExhausted") == true
    or PublicBooleanField(core, "rosterRecoveryRetryExhausted") == true
  local pending = PublicBooleanField(core, "worldEntryRecoveryPending") == true
    or PublicBooleanField(core, "worldEntryRecoveryRetryPending") == true
    or PublicBooleanField(core, "fullWorldRecoveryPending") == true
    or PublicBooleanField(core, "fullWorldRecoveryScheduled") == true
    or PublicBooleanField(core, "rosterRecoveryPending") == true
    or PublicBooleanField(core, "rosterRecoveryRetryPending") == true
  local contextReady = PublicBooleanField(detection, "rosterContextReady")

  if exhausted then
    AddHealthStage(stages, "ROSTER_RECOVERY", "Roster, context, and world recovery", "FAILED",
      "A bounded roster or world recovery series exhausted without convergence.",
      "Use Monitor snapshot, reproduce the transition once, mark it, and reload to flush diagnostics.")
  elseif pending or contextReady ~= true then
    AddHealthStage(stages, "ROSTER_RECOVERY", "Roster, context, and world recovery",
      TransitionVerdict(snapshot, detection, nil),
      "Roster context is provisional or a bounded world-recovery generation is active.",
      "Allow the bounded recovery window to finish, then run the health check again.")
  else
    local rosterCount = PublicNumberField(core, "rosterUnitCount")
      or PublicNumberField(PublicField(detection, "rosterTokenCounts"), "total")
    AddHealthStage(stages, "ROSTER_RECOVERY", "Roster, context, and world recovery", "HEALTHY",
      "Roster context is authoritative with " .. CountText(rosterCount) .. " public unit tokens.")
  end
end

local ENGINE_STATES = {
  COLD = true,
  CONFIGURING = true,
  READY = true,
  COMBAT_DEFERRED = true,
  RECOVERING = true,
  FAILED = true,
}

local function EvaluateEngineStage(stages, snapshot, detection, engine, engineAvailable)
  if not engineAvailable then
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "FAILED",
      "The DetectionEngine diagnostic snapshot is unavailable.",
      "Reload and capture the report before changing detection settings.")
    return
  end
  local lifecycle = PublicEnumField(engine, "lifecycleState", ENGINE_STATES)
  local started = PublicBooleanField(engine, "started")
  local pending = PublicBooleanField(engine, "pendingReconcile") == true
  local failClosed = PublicBooleanField(engine, "failClosed") == true
  local retryExhausted = PublicBooleanField(engine, "retryExhausted") == true
  local eventsRegistered = PublicBooleanField(engine, "eventsRegistered")

  if failClosed or lifecycle == "FAILED" or retryExhausted then
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "FAILED",
      "The engine is failed, fail-closed, or has exhausted bounded retries.",
      "Capture the report before another profile or roster transition.")
  elseif lifecycle == "COMBAT_DEFERRED" or pending and TransitionVerdict(snapshot, detection, engine) == "DEFERRED" then
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "DEFERRED",
      "The engine retained last-good state while mutation is blocked.",
      "Leave combat or wait for addon restrictions to clear, then run the check again.")
  elseif lifecycle == "RECOVERING" or lifecycle == "CONFIGURING" or pending or started ~= true then
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "RECOVERING",
      "The engine is configuring, recovering, or waiting to start.",
      "Allow the bounded reconcile to finish, then run the check again.")
  elseif lifecycle ~= "READY" or eventsRegistered ~= true then
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "FAILED",
      "The engine cannot prove READY with recovery events registered.",
      "Reload and capture the report if READY is not restored.")
  else
    AddHealthStage(stages, "DETECTION_ENGINE", "Detection engine lifecycle", "HEALTHY",
      "The engine is started, READY, and listening for recovery events.")
  end
end

local function EvaluateConsumerStage(stages, snapshot, detection, engine, engineAvailable)
  if not engineAvailable then
    AddHealthStage(stages, "REQUIRED_CONSUMERS", "Required consumer registration", "FAILED",
      "Required consumer banks cannot be evaluated without the engine snapshot.",
      "Reload and capture the report after engine startup.")
    return
  end
  local states = PublicField(engine, "consumerStates")
  local required = PublicNumberField(engine, "requiredConsumerCount")
  local registered = PublicNumberField(engine, "registeredRequiredConsumerCount")
  local missing = false
  local unavailable = false
  for i = 1, #HEALTH_CONSUMERS do
    local row = PublicField(states, HEALTH_CONSUMERS[i])
    if SafeType(row) ~= "table" or PublicBooleanField(row, "registered") ~= true then
      missing = true
    elseif PublicBooleanField(row, "available") == false then
      unavailable = true
    end
  end
  if missing or required ~= #HEALTH_CONSUMERS or registered ~= #HEALTH_CONSUMERS then
    AddHealthStage(stages, "REQUIRED_CONSUMERS", "Required consumer registration", "FAILED",
      "MUFs, Alerts, and LiveList were not all registered before engine startup.",
      "Reload once. If a bank remains missing, preserve this report for initialization-order repair.")
  elseif unavailable then
    local verdict = TransitionVerdict(snapshot, detection, engine)
    if PublicEnumField(engine, "lifecycleState", ENGINE_STATES) == "READY"
        and PublicBooleanField(engine, "pendingReconcile") ~= true then
      verdict = "FAILED"
    end
    AddHealthStage(stages, "REQUIRED_CONSUMERS", "Required consumer registration", verdict,
      "All banks are registered, but at least one bank is not currently available.",
      verdict == "FAILED" and "Capture the report. The first unavailable consumer must be repaired."
        or "Wait for the deferred reconcile, then run the check again.")
  else
    AddHealthStage(stages, "REQUIRED_CONSUMERS", "Required consumer registration", "HEALTHY",
      "MUFs, Alerts, and LiveList are registered and available.")
  end
end

local function BankCoverage(row)
  local expected = PublicNumberField(row, "expectedCount")
  local desired = PublicNumberField(row, "desired")
  local active = PublicNumberField(row, "active")
  local configured = PublicNumberField(row, "configured")
  local shown = PublicNumberField(row, "shown")
  if expected == nil or desired == nil or active == nil or configured == nil or shown == nil then
    return nil
  end
  return expected, desired, active, configured, shown,
    expected == desired and desired == active and active == configured and configured == shown
end

local function EvaluateCoverageStage(stages, snapshot, detection, engine, engineAvailable, mufs, mufsAvailable)
  if not engineAvailable then
    AddHealthStage(stages, "CARRIER_BANKS", "Native carrier bank coverage", "FAILED",
      "Native carrier coverage is unavailable.",
      "Reload and capture the report after engine startup.")
    return
  end
  local desired = PublicNumberField(engine, "desiredCarrierCount")
  local active = PublicNumberField(engine, "activeCarrierCount")
  local configured = PublicNumberField(engine, "transactionConfiguredCarrierCount")
  local shown = PublicNumberField(engine, "transactionShownCarrierCount")
  local pending = PublicNumberField(engine, "pendingAssignmentCount")
  local globalAvailable = desired ~= nil and active ~= nil and configured ~= nil and shown ~= nil and pending ~= nil
  local globalEqual = globalAvailable and pending == 0 and desired == active and active == configured and configured == shown
  local states = PublicField(engine, "consumerStates")
  local detailed = 0
  local bankMismatch = false
  for i = 1, #HEALTH_CONSUMERS do
    local expected, bankDesired, bankActive, bankConfigured, bankShown, equal = BankCoverage(PublicField(states, HEALTH_CONSUMERS[i]))
    if expected ~= nil and bankDesired ~= nil and bankActive ~= nil and bankConfigured ~= nil and bankShown ~= nil then
      detailed = detailed + 1
      if not equal then
        bankMismatch = true
      end
    end
  end
  if globalEqual and mufsAvailable then
    local assignedMUFs = PublicNumberField(mufs, "assignedCount")
    if assignedMUFs and assignedMUFs > 0 and desired == 0 then
      globalEqual = false
      bankMismatch = true
    end
  end
  local summary = "Coverage desired/active/configured/shown is "
    .. CountText(desired) .. "/" .. CountText(active) .. "/" .. CountText(configured) .. "/" .. CountText(shown)
    .. ". Detailed banks " .. tostring(detailed) .. "/" .. tostring(#HEALTH_CONSUMERS) .. "."
  if not globalAvailable then
    AddHealthStage(stages, "CARRIER_BANKS", "Native carrier bank coverage", "RECOVERING",
      "Carrier coverage fields are unavailable from the public engine snapshot.",
      "Integration requirement: publish sanitized desired, active, configured, and shown counts.", true)
  elseif not globalEqual or bankMismatch then
    local lifecycle = PublicEnumField(engine, "lifecycleState", ENGINE_STATES)
    local verdict = lifecycle == "READY" and PublicBooleanField(engine, "pendingReconcile") ~= true
      and "FAILED" or TransitionVerdict(snapshot, detection, engine)
    AddHealthStage(stages, "CARRIER_BANKS", "Native carrier bank coverage", verdict, summary,
      verdict == "FAILED" and "Capture the report. APPLIED is invalid until every bank has exact coverage."
        or "Wait for the pending native transaction, then run the check again.", detailed < #HEALTH_CONSUMERS)
  else
    AddHealthStage(stages, "CARRIER_BANKS", "Native carrier bank coverage", "HEALTHY", summary,
      detailed < #HEALTH_CONSUMERS
        and "Integration requirement: add sanitized per-bank coverage to DetectionEngine diagnostics." or nil,
      detailed < #HEALTH_CONSUMERS)
  end
end

local function EvaluateSetUnitStage(stages, snapshot, detection, detectionAvailable, engine, engineAvailable)
  if not detectionAvailable or not engineAvailable then
    AddHealthStage(stages, "SAFE_SET_UNIT", "Safe native unit assignment", "FAILED",
      "Native assignment counters are unavailable.",
      "Reload and capture the report after Detection and DetectionEngine initialize.")
    return
  end
  local pendingCombat = PublicBooleanField(detection, "attachmentPendingCombat") == true
  local pendingRestriction = PublicBooleanField(detection, "attachmentPendingRestriction") == true
  local restrictionActive = PublicBooleanField(detection, "restrictionActive") == true
  local pendingAssignments = PublicNumberField(engine, "pendingAssignmentCount") or 0
  local attempts = PublicNumberField(detection, "attachmentAttempts")
  local attached = PublicNumberField(detection, "attachments")
  local failures = PublicNumberField(detection, "attachmentFailures")
  local summary = "Assignments attempts/successes/deferred-or-errors are "
    .. CountText(attempts) .. "/" .. CountText(attached) .. "/" .. CountText(failures) .. "."
  if pendingCombat or pendingRestriction or restrictionActive and pendingAssignments > 0 then
    AddHealthStage(stages, "SAFE_SET_UNIT", "Safe native unit assignment", "DEFERRED", summary,
      "Leave combat or wait for restrictions to clear. Assignments will replay through the guarded path.")
  elseif pendingAssignments > 0 then
    local verdict = PublicEnumField(engine, "lifecycleState", ENGINE_STATES) == "READY" and "FAILED" or "RECOVERING"
    AddHealthStage(stages, "SAFE_SET_UNIT", "Safe native unit assignment", verdict, summary,
      verdict == "FAILED" and "Capture the report. READY cannot retain pending native assignments."
        or "Wait for the bounded assignment replay, then run the check again.")
  else
    AddHealthStage(stages, "SAFE_SET_UNIT", "Safe native unit assignment", "HEALTHY", summary)
  end
end

local SOUND_RESULTS = {
  SUCCESS = true,
  FAILURE = true,
  DEFERRED_COMBAT = true,
  DEFERRED_RESTRICTED = true,
  NEVER = true,
  NONE = true,
}

local function EvaluateSoundStage(stages, snapshot, alerts, alertsAvailable)
  if not alertsAvailable then
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "FAILED",
      "The Alerts sound-registry snapshot is unavailable.",
      "Reload and capture the report after Alerts initializes.")
    return
  end
  local configuredByUser = PublicBooleanField(alerts, "soundConfigured") == true
  local mode = PublicField(alerts, "soundMode")
  local enabled = configuredByUser and mode == "NATIVE_ADDED"
  local active = PublicNumberField(alerts, "nativeRegistrations") or 0
  local desired = PublicNumberField(alerts, "nativeDesiredRegistrations") or 0
  local exact = PublicNumberField(alerts, "nativeExactRegistrations") or 0
  local stale = PublicNumberField(alerts, "nativeStaleRegistrations") or 0
  local addFailed = PublicNumberField(alerts, "nativeAddFailures") or 0
  local removeFailed = PublicNumberField(alerts, "nativeRemoveFailures") or 0
  local pending = PublicBooleanField(alerts, "pendingRefresh") == true
  local result = PublicEnumField(alerts, "nativeLastResult", SOUND_RESULTS) or "NONE"
  local retryExhausted = PublicBooleanField(alerts, "nativeReplayExhausted") == true
    or PublicBooleanField(alerts, "nativeRemoveRetryExhausted") == true
  local curated = PublicNumberField(alerts, "actionableCuratedCount") or 0
  local summary = "Sound desired/exact/active/stale is " .. tostring(desired) .. "/" .. tostring(exact)
    .. "/" .. tostring(active) .. "/" .. tostring(stale) .. "."

  if not enabled then
    if active ~= 0 or stale ~= 0 or removeFailed ~= 0 or pending then
      AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "FAILED", summary,
        "Sound is disabled by setting, so every owned native handle must be removed.")
    else
      AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "HEALTHY",
        "Not applicable: native landing sound is disabled by setting and owns no handles.")
    end
  elseif retryExhausted then
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "FAILED", summary,
      "Bounded sound-registry retry exhausted. Capture this report before toggling sound.")
  elseif result == "NEVER" then
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "FAILED", summary,
      "Native landing sound is enabled but its desired-state registry has never reconciled.")
  elseif pending or result == "DEFERRED_COMBAT" or result == "DEFERRED_RESTRICTED" then
    local lockdown = PublicField(snapshot, "lockdown")
    local isDeferred = PublicBooleanField(lockdown, "combat") == true
      or PublicBooleanField(alerts, "chatLockdown") == true
      or result == "DEFERRED_COMBAT" or result == "DEFERRED_RESTRICTED"
    local verdict = isDeferred and "DEFERRED" or "RECOVERING"
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", verdict, summary,
      "Wait for messaging restrictions to clear and the bounded registry replay to finish.")
  elseif stale ~= 0 or addFailed ~= 0 or removeFailed ~= 0 or desired ~= exact or exact ~= active
      or curated > 0 and desired == 0 or result == "FAILURE" then
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "FAILED", summary,
      "Capture the report. Desired sound coverage and owned handles are inconsistent.")
  else
    AddHealthStage(stages, "SOUND_REGISTRY", "Aura sound registry", "HEALTHY", summary)
  end
end

local function EvaluateClickStage(stages, snapshot, detection, detectionAvailable, mufs, mufsAvailable)
  local click = PublicField(snapshot, "clickMapping")
  if not detectionAvailable or not mufsAvailable then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "FAILED",
      "Detection or MUF click status is unavailable.",
      "Reload and capture the report after both modules initialize.")
    return
  end
  local actionable = PublicNumberField(detection, "actionableTypeCount")
  local enabledTypes = PublicNumberField(detection, "enabledActionableTypeCount")
  local knownActions = PublicNumberField(detection, "knownCureActionCount")
  local getterAvailable = PublicBooleanField(click, "getterAvailable") == true
  local mappingAvailable = PublicBooleanField(click, "available") == true
  local mappingPending = PublicBooleanField(click, "pending") == true
  local mappingCount = PublicNumberField(click, "mappingCount") or 0
  local assigned = PublicNumberField(mufs, "assignedCount") or 0
  local installed = PublicNumberField(mufs, "clickInstalledCount") or 0
  local rebuildPending = PublicBooleanField(mufs, "clickRebuildPending") == true
  local summary = "Capability types/actions and click mappings are " .. CountText(enabledTypes)
    .. "/" .. CountText(knownActions) .. "/" .. tostring(mappingCount) .. "."

  if actionable ~= 4 or enabledTypes == nil or enabledTypes < 0 or enabledTypes > 4 then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "FAILED",
      "The actionable friendly-cure domain is not exactly Magic, Curse, Poison, and Disease.",
      "Capture the report before changing cure-type settings.")
  elseif mappingPending or rebuildPending then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping",
      TransitionVerdict(snapshot, detection, nil), summary,
      "Wait for the click model to rebuild outside mutation restrictions.")
  elseif not getterAvailable then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "RECOVERING",
      "The public resolved-click status getter is unavailable.",
      "Integration requirement: expose only mapping mode, readiness, and count.", true)
  elseif knownActions and knownActions > 0 and (not mappingAvailable or mappingCount < 3) then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "FAILED", summary,
      "A public cure action exists, but the resolved secure click map is unavailable or incomplete.")
  elseif installed ~= assigned then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "FAILED", summary,
      "Every assigned MUF must receive the current resolved click model.")
  elseif knownActions == 0 then
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "HEALTHY",
      "Not applicable: the current class/spec exposes no public cure action. Fixed target/focus mappings remain available.")
  else
    AddHealthStage(stages, "CLICK_CAPABILITY", "Click and dispel capability mapping", "HEALTHY", summary)
  end
end

local function EvaluateHealthCheck(snapshot)
  local stages = {}
  local core, coreAvailable = SnapshotProvider(snapshot, "Core")
  local detection, detectionAvailable = SnapshotProvider(snapshot, "Detection")
  local engine, engineAvailable = SnapshotProvider(snapshot, "DetectionEngine")
  local mufs, mufsAvailable = SnapshotProvider(snapshot, "MUFs")
  local alerts, alertsAvailable = SnapshotProvider(snapshot, "Alerts")

  EvaluateAddonStage(stages, snapshot)
  EvaluateProfileStage(stages, snapshot, core, coreAvailable)
  EvaluateRoutingStage(stages, snapshot, core, coreAvailable)
  EvaluateRosterStage(stages, snapshot, core, coreAvailable, detection, detectionAvailable)
  EvaluateEngineStage(stages, snapshot, detection, engine, engineAvailable)
  EvaluateConsumerStage(stages, snapshot, detection, engine, engineAvailable)
  EvaluateCoverageStage(stages, snapshot, detection, engine, engineAvailable, mufs, mufsAvailable)
  EvaluateSetUnitStage(stages, snapshot, detection, detectionAvailable, engine, engineAvailable)
  EvaluateSoundStage(stages, snapshot, alerts, alertsAvailable)
  EvaluateClickStage(stages, snapshot, detection, detectionAvailable, mufs, mufsAvailable)

  local overall = "HEALTHY"
  local firstFailed
  local firstRecovering
  local counts = {HEALTHY = 0, RECOVERING = 0, DEFERRED = 0, FAILED = 0}
  local integrationRequirements = 0
  for i = 1, #stages do
    local stage = stages[i]
    counts[stage.verdict] = (counts[stage.verdict] or 0) + 1
    if stage.integrationRequired then
      integrationRequirements = integrationRequirements + 1
    end
    if stage.verdict == "FAILED" and not firstFailed then
      firstFailed = stage
    elseif HEALTH_RANK[stage.verdict] == HEALTH_RANK.RECOVERING and not firstRecovering then
      firstRecovering = stage
    end
    if HEALTH_RANK[stage.verdict] > HEALTH_RANK[overall] then
      overall = stage.verdict
    elseif HEALTH_RANK[stage.verdict] == HEALTH_RANK[overall] and stage.verdict == "DEFERRED" then
      overall = "DEFERRED"
    end
  end
  local firstActionable = firstFailed or firstRecovering
  return {
    verdict = overall,
    stages = stages,
    firstActionable = firstActionable,
    counts = counts,
    integrationRequirements = integrationRequirements,
  }
end

local function BuildHealthReport(result)
  local first = result.firstActionable
  local lines = {
    "Zhaohu's Decursive Health Check",
    "Privacy: no names, realms, GUIDs, profile names, raw signatures, spell IDs, paths, or secret values.",
    "Overall verdict: " .. result.verdict,
    "First actionable stage: " .. (first and first.label or "None"),
  }
  if first then
    lines[#lines + 1] = "First issue: " .. first.summary
    if first.action then
      lines[#lines + 1] = "Next action: " .. first.action
    end
  end
  lines[#lines + 1] = ""
  for i = 1, #result.stages do
    local stage = result.stages[i]
    lines[#lines + 1] = "[" .. stage.verdict .. "] " .. stage.label
    lines[#lines + 1] = "  " .. stage.summary
    if stage.integrationRequired and stage.action then
      lines[#lines + 1] = "  " .. stage.action
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Stages: healthy=" .. tostring(result.counts.HEALTHY)
    .. " recovering=" .. tostring(result.counts.RECOVERING)
    .. " deferred=" .. tostring(result.counts.DEFERRED)
    .. " failed=" .. tostring(result.counts.FAILED)
    .. " integration=" .. tostring(result.integrationRequirements)
  lines[#lines + 1] = "This report is evaluated from current sanitized runtime snapshots and does not enumerate auras."
  return table.concat(lines, "\n")
end

local function DisplayScalar(value)
  if IsSecret(value) then
    return "<secret>"
  end
  local kind = type(value)
  if kind == "nil" then
    return "unknown"
  end
  if kind == "boolean" or kind == "number" then
    return tostring(value)
  end
  if kind == "string" then
    local safe = SafeToken(value)
    if safe then
      return safe
    end
    if value:match("^%d[%w.%-]*$") and #value <= 80 then
      return value
    end
    if value == state.lastMilestone then
      return value
    end
    if value == state.phase then
      return value
    end
    for i = 1, #runtimeLog do
      local row = runtimeLog[i]
      if value == row.message or value == row.stamp then
        return value
      end
    end
    return "<redacted>"
  end
  return "<" .. kind .. ">"
end

local function AppendTable(lines, prefix, value, depth, seen)
  if IsSecret(value) then
    lines[#lines + 1] = prefix .. " = <secret>"
    return
  end
  if type(value) ~= "table" then
    lines[#lines + 1] = prefix .. " = " .. DisplayScalar(value)
    return
  end
  if seen[value] then
    lines[#lines + 1] = prefix .. " = <cycle>"
    return
  end
  if depth >= 4 then
    lines[#lines + 1] = prefix .. " = <depth-limit>"
    return
  end
  seen[value] = true
  local keys = {}
  for key in pairs(value) do
    if not IsSecret(key) and (type(key) == "string" or type(key) == "number") then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  if #keys == 0 then
    lines[#lines + 1] = prefix .. " = {}"
  else
    for i = 1, #keys do
      local key = keys[i]
      local safeKey = type(key) == "number" and tostring(key) or (key:match("^[A-Za-z][A-Za-z0-9]*$") and key or "redacted-key")
      local child, ok = SafeIndex(value, key)
      if ok then
        AppendTable(lines, prefix .. "." .. safeKey, child, depth + 1, seen)
      else
        lines[#lines + 1] = prefix .. "." .. safeKey .. " = <inaccessible>"
      end
    end
  end
  seen[value] = nil
end

local function BuildReport()
  local snapshot = BuildSnapshot()
  local lines = {
    "Zhaohu's Decursive Diagnostics",
    "Copy this entire report with Ctrl+A, Ctrl+C.",
    "No character names, realms, GUIDs, filesystem paths, or SavedVariables contents are included.",
    "",
  }
  AppendTable(lines, "diagnostics", snapshot, 0, {})
  lastReport = table.concat(lines, "\n")
  return lastReport, snapshot
end

local function ClearRuntimeLog()
  for i = #runtimeLog, 1, -1 do
    runtimeLog[i] = nil
  end
end

local function Paint(frame, fill, border)
  if not frame.SetBackdrop and type(Mixin) == "function" and BackdropTemplateMixin then
    Mixin(frame, BackdropTemplateMixin)
    frame:OnBackdropLoaded()
  end
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
  end
end

local function MakeButton(parent, label, width)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 24)
  button:SetText(label)
  return button
end

local function RefreshWindow()
  local report = BuildReport()
  if window and window.editBox then
    restoringText = true
    window.editBox:SetText(report)
    restoringText = false
    window.editBox:SetCursorPosition(0)
  end
  return report
end

local function CreateWindow()
  if window or type(CreateFrame) ~= "function" or not UIParent then
    return window
  end
  local frame = CreateFrame("Frame", "ZDecursiveDiagnosticsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(760, 540)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)
  Paint(frame, {0.025, 0.04, 0.055, 0.98}, {0.24, 0.72, 0.68, 1})

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("Zhaohu's Decursive Diagnostics")

  local refresh = MakeButton(frame, "Refresh", 90)
  refresh:SetPoint("TOPRIGHT", -206, -10)
  refresh:SetScript("OnClick", RefreshWindow)

  local clear = MakeButton(frame, "Clear runtime log", 130)
  clear:SetPoint("LEFT", refresh, "RIGHT", 6, 0)
  clear:SetScript("OnClick", function()
    ClearRuntimeLog()
    RefreshWindow()
  end)

  local close = MakeButton(frame, "Close", 70)
  close:SetPoint("LEFT", clear, "RIGHT", 6, 0)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -46)
  scroll:SetPoint("BOTTOMRIGHT", -34, 16)

  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  if ChatFontNormal or GameFontHighlightSmall then
    editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  elseif editBox.SetFont and STANDARD_TEXT_FONT then
    editBox:SetFont(STANDARD_TEXT_FONT, 12)
  end
  editBox:SetWidth(700)
  editBox:SetHeight(1)
  editBox:SetTextInsets(4, 4, 4, 4)
  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  editBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and not restoringText then
      restoringText = true
      self:SetText(lastReport)
      restoringText = false
    end
  end)
  scroll:SetScrollChild(editBox)

  frame.editBox = editBox
  frame.refreshButton = refresh
  frame.clearButton = clear
  frame.closeButton = close
  frame:Hide()
  window = frame
  return frame
end

local function ShowWindow()
  local ok, frame = pcall(CreateWindow)
  if not ok or not frame then
    AppendLog("ERROR", "diagnostic window creation failed")
    return false
  end
  local refreshed = pcall(RefreshWindow)
  if not refreshed then
    AppendLog("ERROR", "diagnostic window refresh failed")
    return false
  end
  local shown = pcall(frame.Show, frame)
  if not shown then
    AppendLog("ERROR", "diagnostic window display failed")
    return false
  end
  return true
end

local function ShowText(text)
  if IsSecret(text) or type(text) ~= "string" then
    return false
  end
  local ok, frame = pcall(CreateWindow)
  if not ok or not frame or not frame.editBox then
    return false
  end
  lastReport = text
  restoringText = true
  frame.editBox:SetText(text)
  restoringText = false
  frame.editBox:SetCursorPosition(0)
  return pcall(frame.Show, frame)
end

-- Status messages belong in the report's bounded runtime log. They must not
-- replace or open the copyable report window, and callers provide sanitized
-- text that contains no unit names or other identities.
local function AppendRuntimeMessage(message)
  if IsSecret(message) or type(message) ~= "string" then
    return false
  end
  AppendLog("NOTICE", message)
  if window and window.IsShown and window:IsShown() then
    pcall(RefreshWindow)
  end
  return true
end

local function RunHealthCheck(showWindow)
  local snapshot = BuildSnapshot()
  local result = EvaluateHealthCheck(snapshot)
  local report = BuildHealthReport(result)
  lastHealthCheck = result
  lastReport = report
  AppendLog("HEALTH", "health check " .. result.verdict)
  if type(ns.DiagnosticRecord) == "function" then
    pcall(ns.DiagnosticRecord, "HEALTH_CHECK", {
      verdict = result.verdict,
      firstStage = result.firstActionable and result.firstActionable.key or "NONE",
      healthy = result.counts.HEALTHY,
      recovering = result.counts.RECOVERING,
      deferred = result.counts.DEFERRED,
      failed = result.counts.FAILED,
      integrations = result.integrationRequirements,
    }, false)
  end
  if showWindow ~= false then
    ShowText(report)
  end
  return report, result
end

local function GetLastHealthCheckSummary()
  if type(lastHealthCheck) ~= "table" then
    return nil
  end
  return {
    verdict = lastHealthCheck.verdict,
    firstStage = lastHealthCheck.firstActionable and lastHealthCheck.firstActionable.key or "NONE",
    healthy = lastHealthCheck.counts.HEALTHY,
    recovering = lastHealthCheck.counts.RECOVERING,
    deferred = lastHealthCheck.counts.DEFERRED,
    failed = lastHealthCheck.counts.FAILED,
    integrations = lastHealthCheck.integrationRequirements,
  }
end

local function TryInstallMenuButton()
  if menuButton or type(CreateFrame) ~= "function" or not GameMenuFrame or not GameMenuButtonAddons then
    return menuButton ~= nil
  end
  local combat = LockdownStatus().combat
  if combat == true then
    return false
  end
  local ok, button = pcall(CreateFrame, "Button", "ZDecursiveDiagnosticsMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
  if not ok or not button then
    return false
  end
  local configured = pcall(function()
    button:SetSize(130, 22)
    button:SetPoint("LEFT", GameMenuButtonAddons, "RIGHT", 8, 0)
    button:SetText("Diagnostics")
    button:SetScript("OnClick", ShowWindow)
  end)
  if not configured then
    return false
  end
  menuButton = button
  return true
end

local function RegisterSlashCommands()
  SlashCmdList = SlashCmdList or {}
  SLASH_ZDECURSIVEDIAGNOSTICS1 = "/zdiag"
  SLASH_ZDECURSIVEDIAGNOSTICS2 = "/zdiagnostics"
  SlashCmdList.ZDECURSIVEDIAGNOSTICS = function(message)
    local command = type(message) == "string" and message:match("^%s*(%S+)") or nil
    if command and (command:lower() == "auraon" or command:lower() == "auraoff") then
      if ns.DetectionEngine then
        ns.DetectionEngine:SetAuraTrace(command:lower() == "auraon")
      end
      ShowWindow()
    elseif command and command:lower() == "health" then
      RunHealthCheck(true)
    else
      ShowWindow()
    end
  end
end

local function OnDiagnosticEvent(_frame, event, arg1)
  if event == "ADDON_LOADED" then
    if not IsSecret(arg1) and arg1 == ADDON_NAME then
      if state.coreInitialize == "started" then
        state.coreInitialize = "failure"
        AppendLog("ERROR", "Core OnInitialize failure")
      end
      if state.coreEnable == "started" then
        state.coreEnable = "failure"
        AppendLog("ERROR", "Core OnEnable failure")
      end
      Checkpoint("boot", "ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    if state.coreInitialize == "started" then
      state.coreInitialize = "failure"
      AppendLog("ERROR", "Core OnInitialize failure")
    end
    if state.coreEnable == "started" then
      state.coreEnable = "failure"
      AppendLog("ERROR", "Core OnEnable failure")
    end
    Checkpoint("boot", "PLAYER_LOGIN")
    TryInstallMenuButton()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Checkpoint("boot", "PLAYER_ENTERING_WORLD")
  elseif event == "PLAYER_REGEN_DISABLED" then
    Checkpoint("combat", "PLAYER_REGEN_DISABLED")
  elseif event == "PLAYER_REGEN_ENABLED" then
    Checkpoint("combat", "PLAYER_REGEN_ENABLED")
    TryInstallMenuButton()
  elseif event == "GROUP_ROSTER_UPDATE" then
    AppendLog("EVENT", "GROUP_ROSTER_UPDATE")
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    AppendLog("EVENT", "PLAYER_SPECIALIZATION_CHANGED")
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if not IsSecret(arg1) and arg1 == ADDON_NAME then
      AppendLog("ERROR", event .. " for ZDecursive")
    end
  elseif event == "LUA_WARNING" then
    AppendLog("WARNING", "LUA_WARNING emitted")
  end
end

local function RegisterEvents()
  if type(CreateFrame) ~= "function" then
    return
  end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", OnDiagnosticEvent)
  local events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN",
    "LUA_WARNING",
  }
  for i = 1, #events do
    local event = events[i]
    local valid = true
    if C_EventUtils and C_EventUtils.IsEventValid then
      local values, ok = Probe(C_EventUtils.IsEventValid, event)
      valid = ok and values[1] == true
    end
    if valid then
      pcall(frame.RegisterEvent, frame, event)
    end
  end
end

local Diagnostics = {
  State = state,
  RegisterProvider = RegisterProvider,
  Checkpoint = Checkpoint,
  MarkModuleLoaded = MarkModuleLoaded,
  MarkModuleEnabled = MarkModuleEnabled,
  MarkModuleRefresh = MarkModuleRefresh,
  BuildSnapshot = BuildSnapshot,
  BuildReport = BuildReport,
  RunHealthCheck = RunHealthCheck,
  GetLastHealthCheckSummary = GetLastHealthCheckSummary,
  Show = ShowWindow,
  ShowText = ShowText,
  AppendRuntimeMessage = AppendRuntimeMessage,
  RefreshWindow = RefreshWindow,
  ClearRuntimeLog = ClearRuntimeLog,
  TryInstallMenuButton = TryInstallMenuButton,
  IsSecret = IsSecret,
  SafeType = SafeType,
  SafePublicBoolean = SafePublicBoolean,
  SafePublicNumber = SafePublicNumber,
  GetLogCount = function()
    return #runtimeLog
  end,
  SetLogLimitForTests = function(limit)
    if type(limit) == "number" and limit >= 1 then
      MAX_LOG_ENTRIES = math.floor(limit)
      while #runtimeLog > MAX_LOG_ENTRIES do
        table.remove(runtimeLog, 1)
      end
    end
  end,
  GetWindow = function()
    return window
  end,
  GetMenuButton = function()
    return menuButton
  end,
}

ns.Diagnostics = Diagnostics
ns.RegisterDiagnosticProvider = RegisterProvider
ns.DiagnosticCheckpoint = Checkpoint
ns.DiagnosticModuleLoaded = MarkModuleLoaded
ns.DiagnosticModuleEnabled = MarkModuleEnabled
ns.DiagnosticModuleRefresh = MarkModuleRefresh

RegisterSlashCommands()
RegisterEvents()
AppendLog("CHECKPOINT", "diagnostics file loaded")
