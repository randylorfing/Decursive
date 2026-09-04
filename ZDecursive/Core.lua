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

if ns.DiagnosticCheckpoint then
  ns.DiagnosticCheckpoint("core", "Core file start")
end

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

local GetNormalizedRealmName = GetNormalizedRealmName
local GetRealmName = GetRealmName
local UnitFullName = UnitFullName
local UnitName = UnitName
local issecretvalue = issecretvalue
local canaccessvalue = canaccessvalue
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetInstanceInfo = GetInstanceInfo

local PROFILE_SCHEMA = 3
local MAX_PROFILES = 50
local MAX_PROFILE_NAME_BYTES = 48
local MAX_RAW_DB_DEPTH = 32
local MAX_RAW_DB_NODES = 100000
local MAX_RAW_DB_BYTES = 8 * 1024 * 1024
local MAX_ENVIRONMENT_CONTEXT_RETRIES = 5
local ENVIRONMENT_CONTEXT_RETRY_DELAY = 0.20
local MAX_WORLD_ENTRY_RECOVERY_RETRIES = 8
local WORLD_ENTRY_RECOVERY_RETRY_DELAY = 0.20
local MAX_ROSTER_RECOVERY_RETRIES = 8
local ROSTER_RECOVERY_RETRY_DELAY = 0.20
local ROSTER_CONVERGENCE_DELAYS = {0.10, 0.35, 1.00, 2.00, 4.00, 7.00, 10.00}
local FULL_WORLD_RECOVERY_DELAYS = {0.15, 0.50, 1.00, 2.00, 4.00, 7.00, 10.00, 13.00, 16.00}
local environmentContextAPI = "GLOBAL_GET_INSTANCE_INFO"
local environmentContextReady = false

local function ValueAccessible(value)
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

local function InspectRawProfileStorage(raw)
  local status = {
    ok = false,
    reason = "unavailable",
    nodes = 0,
    bytes = 0,
    maxDepth = 0,
  }
  if raw == nil then
    status.ok = true
    status.reason = "missing"
    return true, status
  end
  if not ValueAccessible(raw) or type(raw) ~= "table" then
    status.reason = "malformed-root"
    return false, status
  end
  if issecrettable and issecrettable(raw) then
    status.reason = "secret-storage"
    return false, status
  end

  local seen = {}
  local function Consume(value, depth, isKey)
    if not ValueAccessible(value) then
      return false, "secret-value"
    end
    local valueType = type(value)
    if isKey and valueType ~= "string" and valueType ~= "number" then
      return false, "malformed-key"
    end
    status.nodes = status.nodes + 1
    if status.nodes > MAX_RAW_DB_NODES then
      return false, "node-limit"
    end
    if depth > status.maxDepth then
      status.maxDepth = depth
    end
    if depth > MAX_RAW_DB_DEPTH then
      return false, "depth-limit"
    end
    if valueType == "string" then
      status.bytes = status.bytes + #value
    elseif valueType == "number" then
      if value ~= value or value == math.huge or value == -math.huge then
        return false, "malformed-number"
      end
      status.bytes = status.bytes + 16
    elseif valueType == "boolean" then
      status.bytes = status.bytes + 1
    elseif valueType == "table" then
      if issecrettable and issecrettable(value) then
        return false, "secret-storage"
      end
      if getmetatable(value) ~= nil then
        return false, "metatable"
      end
      if seen[value] then
        return false, "cycle-or-alias"
      end
      seen[value] = true
      status.bytes = status.bytes + 32
      local key, child = next(value)
      while key ~= nil do
        local keyOK, keyReason = Consume(key, depth + 1, true)
        if not keyOK then
          return false, keyReason
        end
        local childOK, childReason = Consume(child, depth + 1, false)
        if not childOK then
          return false, childReason
        end
        key, child = next(value, key)
      end
    elseif valueType ~= "nil" then
      return false, "malformed-value"
    end
    if status.bytes > MAX_RAW_DB_BYTES then
      return false, "byte-limit"
    end
    return true
  end

  local ok, valid, reason = pcall(Consume, raw, 0, false)
  if not ok then
    status.reason = "scan-failed"
    return false, status
  end
  if not valid then
    status.reason = reason or "malformed-storage"
    return false, status
  end
  local global = rawget(raw, "global")
  if global ~= nil and type(global) ~= "table" then
    status.reason = "malformed-global"
    return false, status
  end
  local schema = type(global) == "table" and rawget(global, "schema") or nil
  if schema ~= nil then
    if not ValueAccessible(schema) or type(schema) ~= "number" or schema ~= math.floor(schema) or schema < 0 then
      status.reason = "malformed-schema"
      return false, status
    end
    if schema > PROFILE_SCHEMA then
      status.reason = "forward-schema"
      return false, status
    end
  end
  for _, key in ipairs({"profiles", "profileKeys", "char", "realm", "class", "race", "faction", "factionrealm", "global", "namespaces"}) do
    local section = rawget(raw, key)
    if section ~= nil and type(section) ~= "table" then
      status.reason = "malformed-section"
      return false, status
    end
  end
  status.ok = true
  status.reason = schema == nil and "legacy-or-fresh" or "current-or-older"
  return true, status
end

function ns.PreflightRawProfileStorage(raw)
  return InspectRawProfileStorage(raw)
end

function ns.GetProfileStoragePreflightStatus()
  local source = ns.ProfileStoragePreflight
  if type(source) ~= "table" then
    return {ok = false, reason = "not-run"}
  end
  return {
    ok = source.ok == true,
    reason = source.reason,
    nodes = source.nodes,
    bytes = source.bytes,
    maxDepth = source.maxDepth,
  }
end

local function RegisterOptionalEvent(owner, event, method)
  local eventUtils = C_EventUtils
  if type(eventUtils) == "table" and type(eventUtils.IsEventValid) == "function" then
    local ok, valid = pcall(eventUtils.IsEventValid, event)
    if not ok or valid ~= true then
      return false
    end
  end
  owner:RegisterEvent(event, method)
  return true
end

local Decursive = AceAddon:NewAddon("Decursive", "AceConsole-3.0", "AceEvent-3.0")
ns.addon = Decursive

Decursive.APP_NAME = "Decursive"

local function LockedDown()
  return InCombatLockdown and InCombatLockdown()
end

local function PublicString(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function CleanProfileName(value)
  value = PublicString(value)
  if not value then
    return nil
  end
  value = value:match("^%s*(.-)%s*$")
  if value == "" or #value > MAX_PROFILE_NAME_BYTES or value:find("[%z\1-\31\127]") then
    return nil
  end
  return value
end

local function PublicNumber(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  if type(value) ~= "number" then
    return nil
  end
  return value
end

local function PublicBoolean(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  if value == true or value == false then
    return value
  end
  return nil
end

local function SafeCall(func, ...)
  if type(func) ~= "function" then
    return false
  end
  return pcall(func, ...)
end

local function ReadEnvironmentContext()
  local challengeAPI = C_ChallengeMode
  if type(challengeAPI) == "table" and type(challengeAPI.GetActiveChallengeMapID) == "function" then
    local ok, mapID = SafeCall(challengeAPI.GetActiveChallengeMapID)
    mapID = ok and PublicNumber(mapID) or nil
    if mapID and mapID > 0 then
      environmentContextAPI = "CHALLENGE_MODE_ACTIVE"
      environmentContextReady = true
      return "MYTHIC_PLUS", "ACTIVE_CHALLENGE", "challenge"
    end
  end

  environmentContextAPI = "GLOBAL_GET_INSTANCE_INFO"
  local instanceType
  if type(GetInstanceInfo) ~= "function" then
    environmentContextReady = false
    return nil, "INSTANCE_API_UNAVAILABLE", "unknown"
  end
  local ok, _name, value = SafeCall(GetInstanceInfo)
  instanceType = ok and PublicString(value) or nil
  if not instanceType then
    environmentContextReady = false
    return nil, ok and "INSTANCE_CONTEXT_NOT_READY" or "INSTANCE_CONTEXT_FAILED", "unknown"
  end
  environmentContextReady = true
  if instanceType == "arena" or instanceType == "pvp" then
    return "PVP", "PVP_INSTANCE", "instance"
  end
  if instanceType == "raid" then
    return "RAID", "RAID_INSTANCE", "instance"
  end
  if instanceType == "party" or instanceType == "scenario" then
    return "DUNGEON", "PARTY_INSTANCE", "instance"
  end
  if instanceType and instanceType ~= "none" then
    return nil, "UNKNOWN_INSTANCE", "unknown"
  end

  if type(IsInRaid) == "function" then
    local ok, inRaid = SafeCall(IsInRaid)
    if ok then
      inRaid = PublicBoolean(inRaid)
    else
      inRaid = nil
    end
    if inRaid == true then
      return "RAID", "RAID_GROUP", "group"
    end
    if not ok then
      return nil, "CONTEXT_UNAVAILABLE", "unknown"
    end
  end
  if type(IsInGroup) == "function" then
    local ok, inGroup = SafeCall(IsInGroup)
    if ok then
      inGroup = PublicBoolean(inGroup)
    else
      inGroup = nil
    end
    if not ok or inGroup == nil then
      return nil, "CONTEXT_UNAVAILABLE", "unknown"
    end
  end
  return "OPEN_WORLD", "OPEN_WORLD_CONTEXT", "fallback"
end

local function ReplaceTable(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return false
  end
  for key in pairs(target) do
    target[key] = nil
  end
  for key, value in pairs(source) do
    target[key] = ns.DeepCopy(value)
  end
  return true
end

local function CurrentCharacterIdentity()
  local fullName
  local fullRealm
  if UnitFullName then
    fullName, fullRealm = UnitFullName("player")
  end

  local unitName
  if UnitName then
    unitName = UnitName("player")
  end

  local displayRealm
  if GetRealmName then
    displayRealm = GetRealmName()
  end

  local normalizedRealm
  if GetNormalizedRealmName then
    normalizedRealm = GetNormalizedRealmName()
  end

  local name = PublicString(fullName) or PublicString(unitName)
  normalizedRealm = PublicString(fullRealm) or PublicString(normalizedRealm) or PublicString(displayRealm)
  if not name or not normalizedRealm then
    return nil
  end
  normalizedRealm = normalizedRealm:gsub("%s+", "")
  if normalizedRealm == "" then
    return nil
  end

  -- Assignment keys are normalized for stable lookups. AceDB intentionally uses
  -- the display realm name, so keep its exact key separate.
  local key = name .. " - " .. normalizedRealm
  local legacyKey = name .. "-" .. normalizedRealm
  local aceDBName = PublicString(unitName) or name
  local aceDBRealm = PublicString(displayRealm)

  return {
    key = key,
    legacyKeys = legacyKey ~= key and {legacyKey} or {},
    aceDBKey = aceDBRealm and (aceDBName .. " - " .. aceDBRealm) or nil,
  }
end

local function CopyMissingEntries(destination, source)
  local copied = 0
  if type(destination) ~= "table" or type(source) ~= "table" then
    return copied
  end
  for key, value in pairs(source) do
    if rawget(destination, key) == nil then
      destination[key] = ns.DeepCopy(value)
      copied = copied + 1
    end
  end
  return copied
end

local function Notify()
  local runtimeOK = true
  local runtimeState = "applied"
  local currentProfile
  if Decursive.db and type(Decursive.GetCurrentProfileName) == "function" then
    local ok, value = pcall(Decursive.GetCurrentProfileName, Decursive)
    if ok and type(value) == "string" then
      currentProfile = value
    end
  end
  if currentProfile and currentProfile ~= Decursive.lastRuntimeProfile then
    Decursive.lastRuntimeProfile = currentProfile
    Decursive.profileChangeGeneration = (Decursive.profileChangeGeneration or 0) + 1
  end
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("Core")
  end
  if ns.InvalidateDetection then
    local ok = pcall(ns.InvalidateDetection)
    runtimeOK = runtimeOK and ok
  end
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
  local engine = ns.DetectionEngine
  if engine and type(engine.Refresh) == "function" then
    if ns.InvalidateUnitSort then
      ns.InvalidateUnitSort("profile-notify")
    end
    local ok, refreshed, state = pcall(engine.Refresh, engine, "PROFILE_NOTIFY")
    if not ok or refreshed == false then
      runtimeOK = false
      runtimeState = type(state) == "string" and state or "runtime-refresh"
    end
  else
    if ns.RequestUnitSortRefresh then
      local ok, refreshed = pcall(ns.RequestUnitSortRefresh, "profile-notify")
      runtimeOK = runtimeOK and ok and refreshed ~= false
    elseif ns.RefreshMUFs then
      local ok, refreshed = pcall(ns.RefreshMUFs)
      runtimeOK = runtimeOK and ok and refreshed ~= false
    end
    if ns.RefreshAlerts then
      local ok, refreshed = pcall(ns.RefreshAlerts)
      runtimeOK = runtimeOK and ok and refreshed ~= false
    end
    if ns.RefreshLiveList then
      local ok, refreshed = pcall(ns.RefreshLiveList)
      runtimeOK = runtimeOK and ok and refreshed ~= false
    end
  end
  return runtimeOK, runtimeState
end

ns.Notify = Notify

local function RecordProfileGeneration()
  local currentProfile
  if Decursive.db and type(Decursive.db.GetCurrentProfile) == "function" then
    local ok, value = pcall(Decursive.db.GetCurrentProfile, Decursive.db)
    currentProfile = ok and PublicString(value) or nil
  end
  if currentProfile and currentProfile ~= Decursive.lastRuntimeProfile then
    Decursive.lastRuntimeProfile = currentProfile
    Decursive.profileChangeGeneration = (Decursive.profileChangeGeneration or 0) + 1
  end
end

function Decursive:OnAceProfileUIChanged()
  RecordProfileGeneration()
  if self.db and self.db.profile then
    local ensured = self:EnsureEnvironments()
    if ensured == true then
      self:ApplyResolvedEnvironment("ace-profile")
      self:ReconcileMUFOrientation("ace-profile")
    elseif ns.RefreshOptions then
      ns.RefreshOptions()
    end
  elseif ns.RefreshOptions then
    ns.RefreshOptions()
  end
end

function Decursive:OnInitialize()
  if ns.Diagnostics then
    ns.Diagnostics.State.coreInitialize = "started"
    ns.DiagnosticCheckpoint("core", "Core OnInitialize start")
  end
  local rawStorage = rawget(_G, "DecursiveRebuildDB")
  local preflightOK, preflight = InspectRawProfileStorage(rawStorage)
  ns.ProfileStoragePreflight = preflight
  self.profileStorageBlocked = not preflightOK
  if not preflightOK then
    if ns.Diagnostics then
      ns.Diagnostics.State.coreInitialize = "profile-storage-blocked"
      ns.DiagnosticCheckpoint("core", "Core profile storage preflight blocked")
    end
    return
  end
  self.db = AceDB:New("DecursiveRebuildDB", ns.defaults, true)
  if type(self.db.RegisterCallback) == "function" then
    pcall(self.db.RegisterCallback, self.db, self, "OnProfileChanged", "OnAceProfileUIChanged")
    pcall(self.db.RegisterCallback, self.db, self, "OnProfileCopied", "OnAceProfileUIChanged")
    pcall(self.db.RegisterCallback, self.db, self, "OnProfileReset", "OnAceProfileUIChanged")
  end
  local globalBackup = ns.DeepCopy(self.db.global)
  local assignmentOK = pcall(self.MigrateAssignmentIdentity, self)
  local environmentsOK = false
  if assignmentOK then
    environmentsOK = self:EnsureEnvironments()
  end
  if not assignmentOK or environmentsOK ~= true then
    ReplaceTable(self.db.global, globalBackup)
    self.profileStorageBlocked = true
    if ns.Diagnostics then
      ns.Diagnostics.State.coreInitialize = "profile-migration-blocked"
      ns.DiagnosticCheckpoint("core", "Core profile migration transaction blocked")
    end
    return
  end
  local initialEnvironment, _detectedEnvironment, initialReason, initialTier = self:ResolveRoutedEnvironment()
  self.appliedEnvironment = ns.ENV_SET[initialEnvironment] and initialEnvironment or "OPEN_WORLD"
  self.environmentResolutionReason = initialReason or "CONTEXT_UNAVAILABLE"
  self.environmentResolutionTier = initialTier or "unknown"
  ns.RegisterOptions(self)
  if ns.RegisterLists then
    ns.RegisterLists(self)
  end
  self:RegisterChatCommand("dcr", "OpenOptions")
  self:RegisterChatCommand("zd", "OpenOptions")
  self:RegisterChatCommand("zdecursive", "OpenOptions")
  self:RegisterChatCommand("dcrsoullink", function(msg)
    if ns.HandleSoulLinkSlash then
      ns.HandleSoulLinkSlash(msg)
    end
  end)
  self:RegisterChatCommand("dcrsoullinkstatus", function()
    if ns.PrintSoulLinkStatus then
      ns.PrintSoulLinkStatus()
    end
  end)
  self:RegisterChatCommand("zdsound", function(msg)
    local spellText, unitToken = tostring(msg or ""):match("^%s*(%d+)%s*(%S*)")
    if ns.PrintAuraSoundDiagnostics then
      ns.PrintAuraSoundDiagnostics(tonumber(spellText), unitToken)
    end
  end)
  self:RegisterChatCommand("dcrstatus", function()
    if ns.PrintAddonStatus then
      ns.PrintAddonStatus()
    end
  end)
  self:RegisterChatCommand("dcrhelp", function()
    if ns.PrintSlashHelp then
      ns.PrintSlashHelp()
    end
  end)
  self:RegisterChatCommand("dcrdiag", function()
    if ns.PrintDiagnostics then
      ns.PrintDiagnostics()
    end
  end)
  self:RegisterChatCommand("dcrreset", function(msg)
    self:HandleResetSlash(msg)
  end)
  self:RegisterChatCommand("dcridentity", function(msg)
    if ns.PrintIdentity then
      ns.PrintIdentity(msg)
    end
  end)
  self:RegisterChatCommand("dcralerts", function(msg)
    if ns.HandleAlertsSlash then
      ns.HandleAlertsSlash(msg)
    end
  end)
  self:RegisterChatCommand("dcrreport", function()
    if ns.PrintReport then
      ns.PrintReport()
    elseif ns.PrintDiagnostics then
      ns.PrintDiagnostics()
    end
  end)
  self:RegisterChatCommand("dcralertdiag", function(msg)
    if ns.HandleAlertDiagSlash then
      ns.HandleAlertDiagSlash(msg)
    elseif ns.PrintAuraSoundDiagnostics then
      ns.PrintAuraSoundDiagnostics()
    end
  end)

  self:RegisterChatCommand("dcrshow", function()
    local pack = self:GetEditingPack()
    if not pack or type(pack.mufs) ~= "table" then
      self:Print("no editing pack")
      return
    end
    pack.mufs.show = true
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    self:Print("MUFs shown (editing pack)")
  end)

  self:RegisterChatCommand("dcrhide", function()
    local pack = self:GetEditingPack()
    if not pack or type(pack.mufs) ~= "table" then
      self:Print("no editing pack")
      return
    end
    pack.mufs.show = false
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    self:Print("MUFs hidden (editing pack)")
  end)

  self:RegisterChatCommand("dcrshoworder", function()
    if not ns.BuildRoster then
      self:Print("BuildRoster unavailable")
      return
    end
    local units = ns.BuildRoster()
    if type(units) ~= "table" or #units == 0 then
      self:Print("roster empty")
      return
    end
    local parts = {}
    for i = 1, #units do
      local u = units[i]
      local name = UnitName and UnitName(u)
      parts[#parts + 1] = string.format("%d:%s%s", i, tostring(u), name and ("=" .. name) or "")
    end
    self:Print("order " .. table.concat(parts, " "))
  end)

  self:RegisterChatCommand("zddb", function()
    if ns.PrintAddonStatus then
      ns.PrintAddonStatus()
    elseif ns.PrintDiagnostics then
      ns.PrintDiagnostics()
    else
      self:Print("status dump unavailable")
    end
  end)

  if ns.Diagnostics then
    ns.Diagnostics.State.coreInitialize = "success"
    ns.DiagnosticCheckpoint("core", "Core OnInitialize success")
  end
end

function Decursive:OnEnable()
  if ns.Diagnostics then
    ns.Diagnostics.State.coreEnable = "started"
    ns.DiagnosticCheckpoint("core", "Core OnEnable start")
    ns.DiagnosticModuleEnabled("Core", false)
  end
  if self.profileStorageBlocked == true or type(self.db) ~= "table" then
    if ns.Diagnostics then
      ns.Diagnostics.State.coreEnable = "profile-storage-blocked"
      ns.DiagnosticCheckpoint("core", "Core enable blocked by profile storage preflight")
    end
    return
  end
  self:EnsureSpecAssignments()
  self:ApplyResolvedProfile("login")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
  self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnLeavingWorld")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("UNIT_PET", "OnGroupRosterUpdate")
  self:RegisterEvent("GROUP_JOINED", "OnGroupRosterUpdate")
  self:RegisterEvent("GROUP_LEFT", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatOptionsChanged")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEnvironmentContextChanged")
  self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "OnEnvironmentContextChanged")
  self:RegisterEvent("CHALLENGE_MODE_START", "OnEnvironmentContextChanged")
  self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnEnvironmentContextChanged")
  RegisterOptionalEvent(self, "LFG_UPDATE", "OnEnvironmentContextChanged")
  RegisterOptionalEvent(self, "LFG_COMPLETION_REWARD", "OnEnvironmentContextChanged")
  RegisterOptionalEvent(self, "SCENARIO_UPDATE", "OnEnvironmentContextChanged")
  self.worldEntryRecoveryPending = true
  self.worldEntryRecoveryRetryToken = 0
  self.worldEntryRecoveryRetryCount = 0
  self.rosterRecoveryPending = false
  self.rosterRecoveryReason = "NONE"
  self.rosterRecoveryRetryToken = 0
  self.rosterRecoveryRetryCount = 0
  self.rosterRecoveryGeneration = 0
  self.rosterConvergenceGeneration = 0
  self.rosterConvergenceAppliedKey = nil
  self.rosterConvergencePending = false
  self.rosterConvergenceReason = "NONE"
  self.fullWorldRecoveryGeneration = 0
  self.fullWorldRecoveryPending = true
  self.fullWorldRecoveryScheduled = false
  self.fullWorldRecoveryReset = false
  self.fullWorldRecoveryPass = 0
  self.fullWorldRecoveryReason = "ENABLE"
  if ns.EnableMUFs then
    ns.EnableMUFs(self)
  end
  if ns.EnableAlerts then
    ns.EnableAlerts(self)
  end
  if ns.EnableLiveList then
    ns.EnableLiveList(self)
  end
  -- Detection is the transaction coordinator. Every required consumer must
  -- declare its bank before the engine can perform its only startup reconcile.
  if ns.EnableDetection then
    ns.EnableDetection()
  end
  self:CommitRosterIdentity("ENABLE_BASELINE")
  if ns.Diagnostics then
    ns.Diagnostics.State.coreEnable = "success"
    ns.DiagnosticCheckpoint("core", "Core OnEnable success")
    ns.DiagnosticModuleEnabled("Core", true)
  end
end

function Decursive:OnCombatOptionsChanged()
  if ns.CloseOptionsForCombat then
    ns.CloseOptionsForCombat("PLAYER_REGEN_DISABLED")
  end
end

local function IsCanonicalRosterToken(value)
  value = PublicString(value)
  if not value then
    return nil
  end
  if value == "player" or value == "pet" then
    return value
  end
  if value:match("^party%d+$") or value:match("^partypet%d+$")
    or value:match("^raid%d+$") or value:match("^raidpet%d+$") then
    return value
  end
  return nil
end

function Decursive:ReadRosterIdentity()
  if type(ns.BuildRoster) ~= "function" then
    return nil
  end
  local pack = self:GetAppliedEnvironmentPack()
  local ok, roster = pcall(ns.BuildRoster, pack)
  if not ok or type(roster) ~= "table" then
    return nil
  end
  local ordered = {}
  local seen = {}
  local petCount = 0
  local partyMemberCount = 0
  for i = 1, #roster do
    local unit = IsCanonicalRosterToken(roster[i])
    if unit and not seen[unit] then
      seen[unit] = true
      ordered[#ordered + 1] = unit
      if unit == "pet" or unit:match("pet%d+$") then
        petCount = petCount + 1
      elseif unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$") then
        partyMemberCount = partyMemberCount + 1
      end
    end
  end
  local members = {}
  for i = 1, #ordered do
    members[i] = ordered[i]
  end
  table.sort(members)
  return {
    membership = table.concat(members, "|"),
    order = table.concat(ordered, "|"),
    count = #ordered,
    petCount = petCount,
    partyMemberCount = partyMemberCount,
  }
end

function Decursive:CommitRosterIdentity(reason, identity)
  identity = identity or self:ReadRosterIdentity()
  if not identity then
    return false
  end
  self.rosterMembershipSignature = identity.membership
  self.rosterOrderSignature = identity.order
  self.rosterUnitCount = identity.count
  self.rosterPetCount = identity.petCount
  self.rosterRecoveryPending = false
  self.rosterRecoveryReason = reason or "NONE"
  self.rosterRecoveryRetryPending = nil
  self.rosterRecoveryRetryExhausted = false
  self.rosterRecoveryRetryToken = (self.rosterRecoveryRetryToken or 0) + 1
  self.rosterRecoveryGeneration = (self.rosterRecoveryGeneration or 0) + 1
  if ns.DiagnosticRecord then
    local hash = ns.PersistentDiagnostics and ns.PersistentDiagnostics.HashSignature
    ns.DiagnosticRecord("ROSTER_COMMIT", {
      reason = reason or "NONE",
      membershipHash = hash and hash(identity.membership) or "unavailable",
      orderHash = hash and hash(identity.order) or "unavailable",
      count = identity.count,
      petCount = identity.petCount,
    }, false)
  end
  return true
end

function Decursive:ScheduleRosterRecoveryRetry()
  if self.rosterRecoveryPending ~= true or self.rosterRecoveryRetryPending == true then
    return false
  end
  local count = self.rosterRecoveryRetryCount or 0
  if count >= MAX_ROSTER_RECOVERY_RETRIES then
    self.rosterRecoveryRetryExhausted = true
    self.rosterRecoveryReason = "BOUNDED_RETRY_EXHAUSTED"
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("ROSTER_RETRY", {state = "EXHAUSTED", count = count}, false)
    end
    return false
  end
  local timerAPI = C_Timer
  if type(timerAPI) ~= "table" or type(timerAPI.After) ~= "function" then
    return false
  end
  local token = self.rosterRecoveryRetryToken or 0
  self.rosterRecoveryRetryCount = count + 1
  self.rosterRecoveryRetryPending = true
  self.rosterRecoveryRetryExhausted = false
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ROSTER_RETRY", {state = "SCHEDULED", count = self.rosterRecoveryRetryCount}, true)
  end
  timerAPI.After(ROSTER_RECOVERY_RETRY_DELAY, function()
    if token ~= (self.rosterRecoveryRetryToken or 0) then
      return
    end
    self.rosterRecoveryRetryPending = nil
    if self.rosterRecoveryPending ~= true then
      return
    end
    local recovered = self:ReconcileRoster("BOUNDED_RETRY")
    if not recovered and self.rosterRecoveryPending == true then
      self:ScheduleRosterRecoveryRetry()
    end
  end)
  return true
end

function Decursive:DeferRosterReconcile(reason)
  self.rosterRecoveryPending = true
  self.rosterRecoveryReason = reason or "MUTATION_BLOCKED"
  local engine = ns.DetectionEngine
  if engine and type(engine.Defer) == "function" then
    engine:Defer("CORE_ROSTER_LOCKED")
  end
  self:ScheduleRosterRecoveryRetry()
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ROSTER_DEFER", {reason = self.rosterRecoveryReason}, false)
  end
  return false
end

function Decursive:ReconcileRoster(reason, force)
  if type(ns.BuildRoster) ~= "function" then
    return false, "unavailable"
  end
  local identity = self:ReadRosterIdentity()
  if not identity then
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "IDENTITY_UNAVAILABLE"
    self:ScheduleRosterRecoveryRetry()
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("ROSTER_RECONCILE", {reason = reason or "NONE", result = "IDENTITY_UNAVAILABLE"}, false)
    end
    return false
  end
  local membershipChanged = identity.membership ~= self.rosterMembershipSignature
  local orderChanged = identity.order ~= self.rosterOrderSignature
  if not force and self.rosterRecoveryPending ~= true and not membershipChanged and not orderChanged then
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("ROSTER_RECONCILE", {reason = reason or "NONE", result = "UNCHANGED"}, true)
    end
    return false, "unchanged"
  end
  if LockedDown() then
    return self:DeferRosterReconcile("COMBAT_LOCKDOWN")
  end
  if self.fullWorldRecoveryPending == true and self.fullWorldCandidateApplying ~= true then
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "WORLD_CANDIDATE_PENDING"
    if ns.DiagnosticRecord then
      local context = ns.GetRosterContextStatus and ns.GetRosterContextStatus() or nil
      ns.DiagnosticRecord("ROSTER_RECONCILE", {
        reason = reason or "NONE",
        result = "CANDIDATE_PENDING",
        rosterContext = type(context) == "table" and context.kind or "UNKNOWN",
        retainedLastGood = true,
      }, false)
    end
    return false, "provisional"
  end
  if ns.InvalidateUnitSort then
    ns.InvalidateUnitSort("roster-reconcile")
  end
  local engine = ns.DetectionEngine
  local refreshed = false
  if engine and type(engine.Refresh) == "function" then
    refreshed = engine:Refresh(reason or "CORE_ROSTER") == true
  else
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
      refreshed = true
    end
    if ns.RefreshAlerts then
      ns.RefreshAlerts()
    end
    if ns.RefreshLiveList then
      ns.RefreshLiveList()
    end
  end
  if refreshed then
    self.rosterRecoveryRetryCount = 0
    return self:CommitRosterIdentity("NONE", identity)
  end
  self.rosterRecoveryPending = true
  self.rosterRecoveryReason = "RECONCILE_RETRY"
  self:ScheduleRosterRecoveryRetry()
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ROSTER_RECONCILE", {reason = reason or "NONE", result = "REFRESH_RETRY"}, false)
  end
  return false
end

local function FullWorldContext()
  local context = ns.GetRosterContextStatus and ns.GetRosterContextStatus() or nil
  local kind = type(context) == "table" and context.kind or "UNKNOWN"
  local ready = type(context) == "table" and context.ready == true
  return context, ready and kind ~= "UNKNOWN", kind
end

function Decursive:BeginFullWorldRecovery(reason, newGeneration)
  if newGeneration == true or self.fullWorldRecoveryPending ~= true then
    self.fullWorldRecoveryGeneration = (self.fullWorldRecoveryGeneration or 0) + 1
  end
  self.fullWorldRecoveryPending = true
  self.fullWorldRecoveryScheduled = false
  self.fullWorldRecoveryReset = false
  self.fullWorldRecoveryPass = 0
  self.fullWorldRecoveryReason = PublicString(reason) or "WORLD_TRANSITION"
  self.fullWorldImmediateHandled = false
  self.fullWorldCandidateKey = nil
  self.fullWorldCandidateSamples = 0
  self.fullWorldCandidateCount = 0
  self.fullWorldCandidateReason = "DIRTY"
  self.worldEntryRecoveryPending = true
  self.worldEntryRecoveryReason = self.fullWorldRecoveryReason
  if ns.ResetRosterForWorldTransition then
    ns.ResetRosterForWorldTransition(self.fullWorldRecoveryReason)
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FULL_WORLD_RECOVERY", {
      generation = self.fullWorldRecoveryGeneration,
      phase = "DIRTY",
      reason = self.fullWorldRecoveryReason,
    }, false)
  end
  return self.fullWorldRecoveryGeneration
end

function Decursive:ReadFullWorldCandidate(terminal)
  if LockedDown() then
    return nil, "COMBAT_LOCKDOWN"
  end
  local context, authoritative, kind = FullWorldContext()
  local identity = self:ReadRosterIdentity()
  if not identity then
    return nil, "IDENTITY_UNAVAILABLE", kind
  end
  local key = table.concat({kind or "UNKNOWN", identity.membership, identity.order}, "|")
  if key == self.fullWorldCandidateKey then
    self.fullWorldCandidateSamples = (self.fullWorldCandidateSamples or 0) + 1
  else
    self.fullWorldCandidateKey = key
    self.fullWorldCandidateSamples = 1
  end
  self.fullWorldCandidateCount = identity.count or 0
  local affirmativeParty = kind ~= "PARTY_INSTANCE"
    or (type(context) == "table" and type(context.realPartyCount) == "number" and context.realPartyCount > 0)
    or (identity.partyMemberCount or 0) > 1
  if not authoritative then
    if terminal ~= true then
      return nil, "WORLD_CONTEXT_PROVISIONAL", kind
    end
  elseif kind == "PARTY_INSTANCE" and not affirmativeParty then
    if terminal ~= true then
      return nil, "FOLLOWER_ROSTER_PROVISIONAL", kind
    end
  elseif not affirmativeParty and (self.fullWorldCandidateSamples or 0) < 2 then
    return nil, "CANDIDATE_UNSTABLE", kind
  end
  return identity, terminal and "TERMINAL" or "AUTHORITATIVE", kind
end

function Decursive:RunFullWorldRecoveryPass(reason, generation, pass, terminal)
  if generation ~= (self.fullWorldRecoveryGeneration or 0) or self.fullWorldRecoveryPending ~= true then
    return false, "stale"
  end
  self.fullWorldRecoveryPass = pass or 0
  if LockedDown() then
    self.worldEntryRecoveryPending = true
    self.worldEntryRecoveryReason = "COMBAT_LOCKDOWN"
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "WORLD_ENTRY_LOCKED"
    local engine = ns.DetectionEngine
    if engine and type(engine.Defer) == "function" then
      engine:Defer("FULL_WORLD_LOCKED")
    end
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("FULL_WORLD_RECOVERY", {
        generation = generation,
        pass = pass or 0,
        phase = "DEFERRED",
        reason = "COMBAT_LOCKDOWN",
      }, false)
    end
    return false, "combat"
  end
  local identity, candidateState, kind = self:ReadFullWorldCandidate(terminal)
  if not identity then
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = candidateState or "WORLD_CONTEXT_PROVISIONAL"
    self.fullWorldCandidateReason = self.rosterRecoveryReason
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("FULL_WORLD_RECOVERY", {
        generation = generation,
        pass = pass or 0,
        phase = "PROVISIONAL",
        rosterContext = kind,
        reason = candidateState,
        candidateSamples = self.fullWorldCandidateSamples or 0,
        retainedLastGood = true,
      }, false)
    end
    return false, "provisional"
  end
  self.fullWorldCandidateReason = candidateState
  self.fullWorldTerminalDecision = terminal == true
  local previousEnvironment = self:GetAppliedEnvironment()
  local resolvedEnvironment = self:ResolveRoutedEnvironment()
  if ns.ENV_SET[resolvedEnvironment] then
    self.appliedEnvironment = resolvedEnvironment
    self.pendingEnvironment = nil
  end
  self.fullWorldCandidateApplying = true
  local applied = self:ReconcileRoster("FULL_WORLD_" .. tostring(reason or "WORLD"), true)
  self.fullWorldCandidateApplying = nil
  if not applied then
    self.appliedEnvironment = previousEnvironment
    if ns.ENV_SET[resolvedEnvironment] and resolvedEnvironment ~= previousEnvironment then
      self.pendingEnvironment = resolvedEnvironment
    end
  end
  self.fullWorldTerminalDecision = nil
  if applied then
    self.fullWorldRecoveryReset = true
  end
  if applied then
    self.fullWorldRecoveryPending = false
    self.fullWorldRecoveryScheduled = false
    self.worldEntryRecoveryPending = nil
    self.worldEntryRecoveryReason = "NONE"
    self.worldEntryRecoveryRetryPending = nil
    self.worldEntryRecoveryRetryExhausted = false
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FULL_WORLD_RECOVERY", {
      generation = generation,
      pass = pass or 0,
      phase = terminal and (applied and "TERMINAL_APPLIED" or "TERMINAL_PENDING") or (applied and "PROVISIONAL_APPLIED" or "PENDING"),
      rosterContext = kind,
      authoritative = true,
      candidateSamples = self.fullWorldCandidateSamples or 0,
      retainedLastGood = not applied,
    }, false)
  end
  return applied, terminal and "terminal" or "settling"
end

function Decursive:ScheduleFullWorldRecovery(reason)
  if self.fullWorldRecoveryPending ~= true or self.fullWorldRecoveryScheduled == true then
    return false
  end
  local timer = C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return self:RunFullWorldRecoveryPass(reason, self.fullWorldRecoveryGeneration, 0, true)
  end
  local generation = self.fullWorldRecoveryGeneration
  self.fullWorldRecoveryScheduled = true
  for i = 1, #FULL_WORLD_RECOVERY_DELAYS do
    local delay = FULL_WORLD_RECOVERY_DELAYS[i]
    local passIndex = i
    timer.After(delay, function()
      local terminal = passIndex == #FULL_WORLD_RECOVERY_DELAYS
      self:RunFullWorldRecoveryPass(reason, generation, passIndex, terminal)
    end)
  end
  return true
end

ns.RequestRosterReconcile = function(reason, force)
  return Decursive:ReconcileRoster(reason, force)
end

local function RosterConvergenceKey(owner)
  local identity = owner:ReadRosterIdentity()
  local context = ns.GetRosterContextStatus and ns.GetRosterContextStatus() or nil
  if not identity then
    return nil
  end
  local contextKind = type(context) == "table" and context.kind or "UNKNOWN"
  local contextReady = type(context) == "table" and context.ready == true and "READY" or "WAIT"
  local instanceClass = type(context) == "table" and context.instanceClass or "UNKNOWN"
  local realPartyCount = type(context) == "table" and context.realPartyCount or 0
  return table.concat({
    contextKind,
    contextReady,
    instanceClass,
    tostring(realPartyCount),
    identity.membership,
    identity.order,
  }, "|")
end

function Decursive:RunRosterConvergencePass(reason, generation, pass)
  if generation ~= (self.rosterConvergenceGeneration or 0) then
    return false, "stale"
  end
  if self.fullWorldRecoveryPending == true then
    return false, "world-candidate-pending"
  end
  local key = RosterConvergenceKey(self)
  if not key then
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "CONVERGENCE_IDENTITY_UNAVAILABLE"
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("ROSTER_CONVERGENCE", {reason = reason, pass = pass, result = "UNAVAILABLE"}, false)
    end
    return false, "unavailable"
  end
  local changed = key ~= self.rosterConvergenceAppliedKey
  if pass == 0 or changed or self.rosterRecoveryPending == true then
    local applied, state = self:ReconcileRoster("CONVERGENCE_" .. tostring(reason), false)
    if applied or state == "unchanged" then
      self.rosterConvergenceAppliedKey = key
    end
    if ns.DiagnosticRecord then
      local context = ns.GetRosterContextStatus and ns.GetRosterContextStatus() or {}
      ns.DiagnosticRecord("ROSTER_CONVERGENCE", {
        reason = reason,
        pass = pass,
        result = applied and "APPLIED" or state == "unchanged" and "UNCHANGED" or "PENDING",
        rosterContext = context.kind or "UNKNOWN",
        contextReady = context.ready == true,
      }, false)
    end
    return applied, state
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ROSTER_CONVERGENCE", {reason = reason, pass = pass, result = "STABLE"}, true)
  end
  return false, "stable"
end

function Decursive:StartRosterConvergence(reason)
  reason = PublicString(reason) or "CONTEXT_EVENT"
  if self.rosterConvergencePending == true and self.rosterConvergenceReason == reason then
    return self:RunRosterConvergencePass(reason, self.rosterConvergenceGeneration, 0) == true
  end
  self.rosterConvergenceGeneration = (self.rosterConvergenceGeneration or 0) + 1
  local generation = self.rosterConvergenceGeneration
  self.rosterConvergencePending = true
  self.rosterConvergenceReason = reason
  if ns.BeginRosterContextTransition then
    ns.BeginRosterContextTransition(reason)
  end
  local applied = self:RunRosterConvergencePass(reason, generation, 0) == true
  local timer = C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    self.rosterConvergencePending = false
    return applied
  end
  for i = 1, #ROSTER_CONVERGENCE_DELAYS do
    local delay = ROSTER_CONVERGENCE_DELAYS[i]
    timer.After(delay, function()
      self:RunRosterConvergencePass(reason, generation, i)
      if i == #ROSTER_CONVERGENCE_DELAYS and generation == self.rosterConvergenceGeneration then
        self.rosterConvergencePending = false
        self.rosterConvergenceReason = "NONE"
      end
    end)
  end
  return applied
end

ns.RequestRosterConvergence = function(reason)
  return Decursive:StartRosterConvergence(reason)
end

function Decursive:OnGroupRosterUpdate(event)
  if self.fullWorldRecoveryPending == true then
    local applied = self:RunFullWorldRecoveryPass(
      event or "GROUP_ROSTER_UPDATE",
      self.fullWorldRecoveryGeneration,
      self.fullWorldRecoveryPass or 0,
      false
    ) == true
    if not applied then
      self:ScheduleFullWorldRecovery(event or "GROUP_ROSTER_UPDATE")
    end
    return applied
  end
  local convergenceOK = self:StartRosterConvergence(event or "GROUP_ROSTER_UPDATE")
  local engine = ns.DetectionEngine
  local beforeRefresh = engine and engine.refreshGeneration or 0
  local _environmentOK, environmentState = self:ApplyResolvedEnvironment("roster")
  if environmentState == "applied" then
    if not engine or engine.refreshGeneration > beforeRefresh then
      if self.fullWorldRecoveryPending ~= true then
        self:CommitRosterIdentity("ENVIRONMENT_REFRESH")
      end
      return true
    end
    return self:ReconcileRoster("CORE_ROSTER_ENVIRONMENT") or convergenceOK
  end
  return self:ReconcileRoster(event == "UNIT_PET" and "CORE_UNIT_PET" or "CORE_ROSTER") or convergenceOK
end

function Decursive:OnRegenEnabled()
  local sortGeneration = ns.GetUnitSortRefreshGeneration and ns.GetUnitSortRefreshGeneration() or 0
  local engine = ns.DetectionEngine
  local engineGeneration = engine and engine.refreshGeneration or 0
  if self.profileResolvePending then
    self:ApplyResolvedProfile("regen")
  end
  self:ApplyResolvedEnvironment("regen")
  self:EnsureEnvironments()
  local fullWorldRefreshed = false
  if self.fullWorldRecoveryPending == true then
    fullWorldRefreshed = self:RunFullWorldRecoveryPass(
      "PLAYER_REGEN_ENABLED",
      self.fullWorldRecoveryGeneration,
      self.fullWorldRecoveryPass or 0,
      false
    ) == true
  end
  local orientationRefreshed = false
  if self.pendingMUFOrientation == true then
    orientationRefreshed = self:ReconcileMUFOrientation("regen") == true
  end
  if self.rosterRecoveryPending == true then
    self:ReconcileRoster("PLAYER_REGEN_ENABLED")
  end
  if not engine and ns.InvalidateDetection then
    ns.InvalidateDetection()
  end
  if ns.RebuildClickModel then
    ns.RebuildClickModel()
  end
  local engineRefreshed = engine and engine.refreshGeneration > engineGeneration
  if engine and not engineRefreshed and type(engine.Recover) == "function" then
    engineRefreshed = engine:Recover("CORE_REGEN") == true
  end
  if engineRefreshed and self.worldEntryRecoveryPending and self.fullWorldRecoveryPending ~= true then
    self.worldEntryRecoveryPending = nil
    self.worldEntryRecoveryReason = "NONE"
    self.worldEntryRecoveryRetryPending = nil
    self.worldEntryRecoveryRetryExhausted = false
    self.worldEntryRecoveryGeneration = (self.worldEntryRecoveryGeneration or 0) + 1
  end
  local sortRefreshed = ns.GetUnitSortRefreshGeneration and ns.GetUnitSortRefreshGeneration() > sortGeneration
  if ns.FlushUnitSortRefresh and ns.FlushUnitSortRefresh("regen") then
    sortRefreshed = true
  end
  if not engine and not sortRefreshed and ns.RecoverMUFsAfterCombat then
    ns.RecoverMUFsAfterCombat()
  elseif not engine and not sortRefreshed and ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  if not engine and ns.RefreshAlerts then
    ns.RefreshAlerts()
  end
  if ns.ApplyAlertMoveMode then
    ns.ApplyAlertMoveMode()
  end
  if not engine and ns.RefreshLiveList then
    ns.RefreshLiveList()
  end
  return fullWorldRefreshed or engineRefreshed or sortRefreshed or orientationRefreshed
end

function Decursive:ScheduleWorldEntryRecoveryRetry()
  if self.worldEntryRecoveryPending ~= true or self.worldEntryRecoveryRetryPending == true then
    return false
  end
  local count = self.worldEntryRecoveryRetryCount or 0
  if count >= MAX_WORLD_ENTRY_RECOVERY_RETRIES then
    self.worldEntryRecoveryRetryExhausted = true
    self.worldEntryRecoveryReason = "BOUNDED_RETRY_EXHAUSTED"
    return false
  end
  local timerAPI = C_Timer
  if type(timerAPI) ~= "table" or type(timerAPI.After) ~= "function" then
    return false
  end
  local token = self.worldEntryRecoveryRetryToken or 0
  self.worldEntryRecoveryRetryCount = count + 1
  self.worldEntryRecoveryRetryPending = true
  self.worldEntryRecoveryRetryExhausted = false
  timerAPI.After(WORLD_ENTRY_RECOVERY_RETRY_DELAY, function()
    if token ~= (self.worldEntryRecoveryRetryToken or 0) then
      return
    end
    self.worldEntryRecoveryRetryPending = nil
    if self.worldEntryRecoveryPending ~= true then
      return
    end
    local recovered = self:OnEnteringWorld()
    if not recovered and self.worldEntryRecoveryPending == true then
      self:ScheduleWorldEntryRecoveryRetry()
    end
  end)
  return true
end

function Decursive:OnLeavingWorld()
  self.rosterConvergenceGeneration = (self.rosterConvergenceGeneration or 0) + 1
  self.rosterConvergencePending = false
  self.rosterConvergenceReason = "NONE"
  self.worldEntryRecoveryPending = true
  self.worldEntryRecoveryReason = "WORLD_TRANSITION"
  self.worldEntryRecoveryRetryToken = (self.worldEntryRecoveryRetryToken or 0) + 1
  self.worldEntryRecoveryRetryCount = 0
  self.worldEntryRecoveryRetryPending = nil
  self.worldEntryRecoveryRetryExhausted = false
  self.environmentRetryCount = 0
  self:BeginFullWorldRecovery("PLAYER_LEAVING_WORLD", true)
  if type(ns.BuildRoster) == "function" then
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "WORLD_TRANSITION"
    self.rosterRecoveryRetryToken = (self.rosterRecoveryRetryToken or 0) + 1
    self.rosterRecoveryRetryCount = 0
    self.rosterRecoveryRetryPending = nil
    self.rosterRecoveryRetryExhausted = false
  end
end

function Decursive:OnEnteringWorld()
  local engine = ns.DetectionEngine
  local beforeRefresh = engine and engine.refreshGeneration or 0
  if self.worldEntryRecoveryPending ~= true and self.fullWorldRecoveryPending ~= true then
    return false
  end
  if self.fullWorldRecoveryPending ~= true then
    self:BeginFullWorldRecovery("PLAYER_ENTERING_WORLD", true)
  end
  local environmentApplied = false
  if self.fullWorldRecoveryPending == true then
    local resolved = self:ResolveRoutedEnvironment()
    if ns.ENV_SET[resolved] and resolved ~= self:GetAppliedEnvironment() then
      self.pendingEnvironment = resolved
    elseif not ns.ENV_SET[resolved] then
      self:ScheduleEnvironmentResolutionRetry()
    end
  else
    local _environmentOK, environmentState = self:ApplyResolvedEnvironment("world")
    environmentApplied = environmentState == "applied"
  end
  local needsRecovery = self.worldEntryRecoveryPending == true
    or self.profileResolvePending == true
    or self.pendingMUFOrientation == true
    or engine and engine.pending == true
    or environmentApplied
  if not needsRecovery then
    return false
  end
  if self.fullWorldImmediateHandled == true and self.fullWorldRecoveryScheduled == true then
    return false
  end
  self:MigrateAssignmentIdentity()
  self:EnsureSpecAssignments()
  if ns.PrepareWorldEntryRoster then
    ns.PrepareWorldEntryRoster()
  end
  self:ScheduleFullWorldRecovery("PLAYER_ENTERING_WORLD")
  if self.fullWorldRecoveryPending ~= true then
    self:ApplyResolvedProfile("world")
  end
  if ns.ApplyAlertMoveMode then
    ns.ApplyAlertMoveMode()
  end
  if LockedDown() then
    self:StartRosterConvergence("PLAYER_ENTERING_WORLD")
    self.worldEntryRecoveryPending = true
    self.worldEntryRecoveryReason = "COMBAT_LOCKDOWN"
    if engine and type(engine.Defer) == "function" then
      engine:Defer("WORLD_ENTRY_LOCKED")
    end
    self.rosterRecoveryPending = true
    self.rosterRecoveryReason = "WORLD_ENTRY_LOCKED"
    return false
  end
  local fullWorldRecovered = false
  if not engine or engine.refreshGeneration == beforeRefresh then
    fullWorldRecovered = self:RunFullWorldRecoveryPass(
      "PLAYER_ENTERING_WORLD",
      self.fullWorldRecoveryGeneration,
      0,
      false
    ) == true
  end
  self.fullWorldImmediateHandled = true
  self:StartRosterConvergence("PLAYER_ENTERING_WORLD")
  local orientationRefreshed = false
  if self.pendingMUFOrientation == true then
    orientationRefreshed = self:ReconcileMUFOrientation("world") == true
  end
  local recovered = fullWorldRecovered == true or environmentApplied or engine and engine.refreshGeneration > beforeRefresh
  if engine and not recovered and self.fullWorldRecoveryPending ~= true and type(engine.Refresh) == "function" then
    recovered = engine:Refresh("CORE_WORLD_ENTRY") == true
  end
  if (recovered or not engine) and self.fullWorldRecoveryPending ~= true then
    self:CommitRosterIdentity("WORLD_ENTRY_REFRESH")
    self.worldEntryRecoveryPending = nil
    self.worldEntryRecoveryReason = "NONE"
    self.worldEntryRecoveryRetryPending = nil
    self.worldEntryRecoveryRetryExhausted = false
    self.worldEntryRecoveryGeneration = (self.worldEntryRecoveryGeneration or 0) + 1
  elseif self.worldEntryRecoveryPending == true then
    self.worldEntryRecoveryReason = "RECONCILE_RETRY"
    if self.fullWorldRecoveryScheduled ~= true then
      self:ScheduleWorldEntryRecoveryRetry()
    end
  end
  return recovered or orientationRefreshed
end

function Decursive:OnSpecChanged()
  self:EnsureSpecAssignments()
  if ns.ScheduleFollowerRosterGuard then
    ns.ScheduleFollowerRosterGuard()
  end
  self:ApplyResolvedProfile("spec")
end

function Decursive:OpenOptions()
  if ns.OptionsAccessAllowed and not ns.OptionsAccessAllowed("CORE_OPEN_OPTIONS") then
    return false, "combat"
  end
  if ns.ShowOptions then
    return ns.ShowOptions()
  end
  return false, "unavailable"
end

function Decursive:ToggleOptions()
  if ns.OptionsAccessAllowed and not ns.OptionsAccessAllowed("CORE_TOGGLE_OPTIONS") then
    return false, "combat"
  end
  if ns.ToggleOptions then
    return ns.ToggleOptions()
  end
  return self:OpenOptions()
end

function Decursive:GetCharacterKey()
  local identity = CurrentCharacterIdentity()
  return identity and identity.key or nil
end

function Decursive:OnEnvironmentContextChanged(event)
  local reason = event or "context"
  local convergenceOK = self:StartRosterConvergence(reason)
  local environmentOK, environmentState = self:ApplyResolvedEnvironment(reason)
  if environmentState == "applied" then
    if self.fullWorldRecoveryPending ~= true then
      self:CommitRosterIdentity("CONTEXT_ENVIRONMENT_REFRESH")
    end
    return environmentOK
  end
  local rosterOK = self:ReconcileRoster("CORE_CONTEXT_" .. tostring(reason))
  return environmentOK or rosterOK or convergenceOK
end

function Decursive:GetAceDBCharacterKey()
  local identity = CurrentCharacterIdentity()
  return identity and identity.aceDBKey or nil
end

function Decursive:MigrateAssignmentIdentity(identity)
  identity = identity or CurrentCharacterIdentity()
  local global = self.db and self.db.global
  if not identity or type(global) ~= "table" then
    return false, "identity"
  end

  local characters = global.characters
  local specs = global.specs
  local migrated = {characters = 0, specs = 0}

  -- Copy forward without deleting aliases. Canonical values always win, and a
  -- second pass becomes a no-op while older builds can still read their keys.
  for _, legacyKey in ipairs(identity.legacyKeys or {}) do
    if type(characters) == "table" and rawget(characters, identity.key) == nil then
      local legacyProfile = rawget(characters, legacyKey)
      if legacyProfile ~= nil then
        characters[identity.key] = ns.DeepCopy(legacyProfile)
        migrated.characters = migrated.characters + 1
      end
    end

    if type(specs) == "table" then
      local legacySpecs = rawget(specs, legacyKey)
      local currentSpecs = rawget(specs, identity.key)
      if type(legacySpecs) == "table" then
        if currentSpecs == nil then
          specs[identity.key] = ns.DeepCopy(legacySpecs)
          migrated.specs = migrated.specs + 1
        elseif type(currentSpecs) == "table" then
          migrated.specs = migrated.specs + CopyMissingEntries(currentSpecs, legacySpecs)
        end
      end
    end
  end

  return true, migrated
end

function Decursive:GetSpecIndex()
  local specialization = C_SpecializationInfo
  if type(specialization) ~= "table" or type(specialization.GetSpecialization) ~= "function" then
    return nil
  end
  local ok, spec = pcall(specialization.GetSpecialization)
  if not ok then
    return nil
  end
  spec = PublicNumber(spec)
  if not spec or spec == 0 then
    return nil
  end
  return spec
end

function Decursive:GetSpecName(spec)
  spec = spec or self:GetSpecIndex()
  spec = PublicNumber(spec)
  if not spec then
    return nil
  end
  local specialization = C_SpecializationInfo
  if type(specialization) ~= "table" or type(specialization.GetSpecializationInfo) ~= "function" then
    return "Spec " .. tostring(spec)
  end
  local ok, first, second = pcall(specialization.GetSpecializationInfo, spec)
  if not ok then
    return "Spec " .. tostring(spec)
  end
  local name = type(first) == "table" and first.name or second
  name = PublicString(name)
  return name or ("Spec " .. tostring(spec))
end

function Decursive:ProfileExists(name)
  if not name or name == "" then
    return false
  end
  local profiles = self:GetProfileNames()
  for _, existing in ipairs(profiles) do
    if existing == name then
      return true
    end
  end
  return false
end

function Decursive:GetProfileNames()
  if type(self.db) ~= "table" or type(self.db.GetProfiles) ~= "function" then
    return {}, "storage"
  end
  local ok, profiles = pcall(self.db.GetProfiles, self.db)
  if not ok or type(profiles) ~= "table" then
    return {}, "storage"
  end
  local names = {}
  for _, existing in ipairs(profiles) do
    existing = PublicString(existing)
    if existing then
      names[#names + 1] = existing
    end
  end
  table.sort(names, function(left, right)
    return left:lower() < right:lower()
  end)
  return names
end

function Decursive:GetCurrentProfileName()
  if type(self.db) ~= "table" or type(self.db.GetCurrentProfile) ~= "function" then
    return "Default", "storage"
  end
  local ok, name = pcall(self.db.GetCurrentProfile, self.db)
  name = ok and PublicString(name) or nil
  if not name then
    return "Default", "storage"
  end
  return name
end

function Decursive:ResolveProfileName()
  local key = self:GetCharacterKey()
  local spec = self:GetSpecIndex()
  local g = self.db and self.db.global
  if type(g) ~= "table" then
    return "Default"
  end
  if key and spec and type(g.specs) == "table" then
    local specMap = g.specs[key]
    local row = specMap and specMap[spec]
    if type(row) == "table" and row.enabled == true and self:ProfileExists(row.profile) then
      return row.profile
    end
  end
  if key and type(g.characters) == "table" then
    local charProfile = g.characters[key]
    if self:ProfileExists(charProfile) then
      return charProfile
    end
  end
  if self:ProfileExists(g.accountProfile) then
    return g.accountProfile
  end
  return "Default"
end

function Decursive:ApplyResolvedProfile(_reason)
  local name = self:ResolveProfileName()
  local current, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  if current ~= name then
    if LockedDown() then
      self.profileResolvePending = true
      if ns.MarkUnitSortRefreshPending then
        ns.MarkUnitSortRefreshPending("profile")
      end
      return false, "combat"
    end
    if type(self.db.SetProfile) ~= "function" then
      return false, "storage"
    end
    local ok = pcall(self.db.SetProfile, self.db, name)
    if not ok then
      return false, "transaction"
    end
  end
  self.profileResolvePending = nil
  self:EnsureEnvironments()
  local _environmentOK, environmentState = self:ApplyResolvedEnvironment("profile")
  if environmentState ~= "applied" then
    Notify()
  end
  return true, "applied"
end

function Decursive:GetUIProfileStatus()
  local status = {
    available = false,
    profileGeneration = self.profileChangeGeneration or 0,
    blockedReason = "core-unavailable",
  }
  local db = self.db
  local global = type(db) == "table" and db.global or nil
  if type(db) ~= "table" or type(global) ~= "table" then
    status.blockedReason = "storage"
    return status
  end
  local schema = rawget(global, "schema")
  if type(schema) ~= "number" then
    status.blockedReason = "malformed-schema"
    return status
  end
  if schema > PROFILE_SCHEMA then
    status.blockedReason = "forward-schema"
    return status
  end
  if schema ~= PROFILE_SCHEMA then
    status.blockedReason = "unsupported-schema"
    return status
  end
  if type(global.characters) ~= "table" or type(global.specs) ~= "table" then
    status.blockedReason = "malformed-storage"
    return status
  end
  if type(db.GetProfiles) ~= "function" or type(db.GetCurrentProfile) ~= "function" then
    status.blockedReason = "storage"
    return status
  end
  local profilesOK, profiles = pcall(db.GetProfiles, db)
  local currentOK, current = pcall(db.GetCurrentProfile, db)
  current = currentOK and PublicString(current) or nil
  if not profilesOK or type(profiles) ~= "table" or not current then
    status.blockedReason = "storage"
    return status
  end
  local available = {}
  for _, name in ipairs(profiles) do
    name = PublicString(name)
    if name then
      available[name] = true
    end
  end
  if not available[current] then
    status.blockedReason = "storage"
    return status
  end
  local resolved = "Default"
  local tier = "default"
  local identityOK, key = pcall(self.GetCharacterKey, self)
  local specOK, spec = pcall(self.GetSpecIndex, self)
  key = identityOK and key or nil
  spec = specOK and spec or nil
  if key and spec then
    local specMap = global.specs[key]
    local row = type(specMap) == "table" and specMap[spec] or nil
    if type(row) == "table" and row.enabled == true and available[row.profile] then
      resolved = row.profile
      tier = "specialization"
    end
  end
  if tier == "default" and key and available[global.characters[key]] then
    resolved = global.characters[key]
    tier = "character"
  end
  if tier == "default" and available[global.accountProfile] then
    resolved = global.accountProfile
    tier = "account"
  end
  status.available = true
  status.actualProfile = current
  status.resolvedProfile = resolved
  status.resolvedTier = tier
  if self.profileResolvePending == true and resolved ~= current then
    status.pendingProfile = resolved
  end
  status.blockedReason = nil
  return status
end

function Decursive:ResolveEnvironmentContext()
  return ReadEnvironmentContext()
end

function Decursive:GetEnvironmentMode()
  local profile = self.db and self.db.profile
  local rawMode = type(profile) == "table" and PublicString(rawget(profile, "routingMode")) or nil
  return rawMode == "solo" and "solo" or "multiple"
end

function Decursive:ResolveRoutedEnvironment()
  local detected, reason, tier = self:ResolveEnvironmentContext()
  local mode = self:GetEnvironmentMode()
  local resolved = mode == "solo" and "SOLO" or detected
  return resolved, detected, reason, tier, mode
end

function Decursive:ScheduleEnvironmentResolutionRetry()
  if self.environmentRetryPending == true then
    return false
  end
  local timerAPI = C_Timer
  if type(timerAPI) ~= "table" or type(timerAPI.After) ~= "function" then
    return false
  end
  local count = self.environmentRetryCount or 0
  if count >= MAX_ENVIRONMENT_CONTEXT_RETRIES then
    return false
  end
  self.environmentRetryCount = count + 1
  self.environmentRetryPending = true
  timerAPI.After(ENVIRONMENT_CONTEXT_RETRY_DELAY, function()
    self.environmentRetryPending = nil
    self:ApplyResolvedEnvironment("context-retry")
  end)
  return true
end

function Decursive:GetAppliedEnvironment()
  if ns.ENV_SET and ns.ENV_SET[self.appliedEnvironment] then
    return self.appliedEnvironment
  end
  return "OPEN_WORLD"
end

function Decursive:GetAppliedEnvironmentPack()
  local profile = self.db and self.db.profile
  local environments = type(profile) == "table" and profile.environments or nil
  local environment = self:GetAppliedEnvironment()
  local pack = type(environments) == "table" and environments[environment] or nil
  if type(pack) == "table" then
    return pack
  end
  pack = type(environments) == "table" and environments.OPEN_WORLD or nil
  return type(pack) == "table" and pack or ns.PACK
end

function Decursive:GetEnvironmentProfileStatus()
  local applied = self:GetAppliedEnvironment()
  local resolved, detected, reason, tier, environmentMode = self:ResolveRoutedEnvironment()
  if not ns.ENV_SET[resolved] then
    resolved = "unknown"
    reason = reason or "CONTEXT_UNAVAILABLE"
    tier = tier or "unknown"
  end
  if not ns.MULTIPLE_ENV_SET[detected] then
    detected = "unknown"
  end
  local editing = "unknown"
  local char = self.db and self.db.char
  local rawEditing = type(char) == "table" and rawget(char, "editingEnvironment") or nil
  if ns.ENV_SET[rawEditing] then
    editing = rawEditing
  end
  local pendingEnvironment
  if ns.ENV_SET[self.pendingEnvironment] and self.pendingEnvironment ~= applied then
    pendingEnvironment = self.pendingEnvironment
  end
  return {
    available = self.db ~= nil,
    appliedEnvironment = applied,
    resolvedEnvironment = resolved,
    detectedEnvironment = detected,
    environmentMode = environmentMode,
    pendingEnvironment = pendingEnvironment,
    editingEnvironment = editing,
    reason = reason,
    tier = tier,
  }
end

function Decursive:ApplyResolvedEnvironment(_reason)
  local resolved, detected, reason, tier = self:ResolveRoutedEnvironment()
  self.environmentResolutionReason = reason or "CONTEXT_UNAVAILABLE"
  self.environmentResolutionTier = tier or "unknown"
  self.detectedEnvironment = ns.MULTIPLE_ENV_SET[detected] and detected or nil
  if not ns.MULTIPLE_ENV_SET[detected] then
    self:ScheduleEnvironmentResolutionRetry()
  else
    self.environmentRetryCount = 0
    self.environmentRetryPending = nil
  end
  if not ns.ENV_SET[resolved] then
    if ns.RefreshOptions then
      ns.RefreshOptions()
    end
    return false, "unknown"
  end
  local applied = self:GetAppliedEnvironment()
  if resolved ~= applied and LockedDown() then
    self.pendingEnvironment = resolved
    if ns.MarkUnitSortRefreshPending then
      ns.MarkUnitSortRefreshPending("environment")
    end
    if ns.RefreshOptions then
      ns.RefreshOptions()
    end
    return false, "combat"
  end
  local changed = resolved ~= applied
  self.appliedEnvironment = resolved
  self.pendingEnvironment = nil
  if changed then
    local refreshed, refreshState = Notify()
    if refreshed ~= true then
      self.appliedEnvironment = applied
      self.pendingEnvironment = resolved
      return false, refreshState or "runtime-refresh"
    end
    return true, "applied"
  end
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
  return true, "unchanged"
end

function Decursive:EnvironmentModeMutationReady()
  if type(self.db) ~= "table" or type(self.db.global) ~= "table" or type(self.db.profile) ~= "table" or type(self.db.char) ~= "table" then
    return false, "storage"
  end
  local schema = self.db.global.schema
  if type(schema) ~= "number" then
    return false, "malformed-schema"
  end
  if schema > PROFILE_SCHEMA then
    return false, "forward-schema"
  end
  if schema ~= PROFILE_SCHEMA then
    return false, "unsupported-schema"
  end
  return true
end

function Decursive:SetEnvironmentMode(mode)
  local ready, readyError = self:EnvironmentModeMutationReady()
  if not ready then
    return false, readyError
  end
  if mode ~= "multiple" and mode ~= "solo" then
    return false, "routing-mode"
  end
  return self:RunProfileStorageTransaction("environment-mode", function()
    self.db.profile.routingMode = mode
    self.db.profile.environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA or 1
    self:NormalizeEditingEnvironment(mode)
    return true, "applied"
  end, true, true)
end

function Decursive:ProfileNameExists(name, exceptName)
  name = CleanProfileName(name)
  if not name then
    return false
  end
  local folded = name:lower()
  local ok, profiles = pcall(self.db.GetProfiles, self.db)
  if not ok or type(profiles) ~= "table" then
    return false
  end
  for _, existing in ipairs(profiles) do
    if existing ~= exceptName and type(existing) == "string" and existing:lower() == folded then
      return true, existing
    end
  end
  return false
end

function Decursive:ProfileMutationReady()
  if LockedDown() then
    return false, "combat"
  end
  if type(self.db) ~= "table" or type(self.db.global) ~= "table" then
    return false, "storage"
  end
  local schema = self.db.global.schema
  if type(schema) ~= "number" then
    return false, "malformed-schema"
  end
  if schema > PROFILE_SCHEMA then
    return false, "forward-schema"
  end
  if schema ~= PROFILE_SCHEMA then
    return false, "unsupported-schema"
  end
  if type(self.db.global.characters) ~= "table" or type(self.db.global.specs) ~= "table" then
    return false, "malformed-storage"
  end
  if type(self.db.GetProfiles) ~= "function" or type(self.db.GetCurrentProfile) ~= "function" or type(self.db.SetProfile) ~= "function" then
    return false, "storage"
  end
  local _, profilesError = self:GetProfileNames()
  if profilesError then
    return false, profilesError
  end
  local _, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  return true
end

function Decursive:AssignActivatedProfile(name)
  local key = self:GetCharacterKey()
  local spec = self:GetSpecIndex()
  local global = self.db.global
  if key and spec then
    local specMap = global.specs[key]
    local row = type(specMap) == "table" and specMap[spec]
    if type(row) == "table" and row.enabled == true then
      row.profile = name
      return "specialization"
    end
  end
  if key and rawget(global.characters, key) ~= nil then
    global.characters[key] = name
    return "character"
  end
  global.accountProfile = name
  return "account"
end

local PROFILE_RUNTIME_FIELDS = {
  "appliedEnvironment",
  "pendingEnvironment",
  "detectedEnvironment",
  "environmentResolutionReason",
  "environmentResolutionTier",
  "profileResolvePending",
  "pendingMUFOrientation",
  "lastRuntimeProfile",
  "profileChangeGeneration",
}

function Decursive:CaptureProfileStorageTransaction()
  local db = self.db
  if type(db) ~= "table" then
    return nil
  end
  local snapshot = {
    sv = type(db.sv) == "table" and ns.DeepCopy(db.sv) or nil,
    profiles = type(db.profiles) == "table" and ns.DeepCopy(db.profiles) or nil,
    profile = type(db.profile) == "table" and ns.DeepCopy(db.profile) or nil,
    global = type(db.global) == "table" and ns.DeepCopy(db.global) or nil,
    char = type(db.char) == "table" and ns.DeepCopy(db.char) or nil,
    profileKeys = type(db.profileKeys) == "table" and ns.DeepCopy(db.profileKeys) or nil,
    currentProfile = self:GetCurrentProfileName(),
    runtime = {},
  }
  for i = 1, #PROFILE_RUNTIME_FIELDS do
    local key = PROFILE_RUNTIME_FIELDS[i]
    snapshot.runtime[key] = self[key]
  end
  return snapshot
end

local function RestorePlainDB(db, snapshot)
  if type(snapshot.profiles) == "table" then
    db.profiles = ns.DeepCopy(snapshot.profiles)
  end
  if type(snapshot.global) == "table" then
    db.global = ns.DeepCopy(snapshot.global)
  end
  if type(snapshot.char) == "table" then
    db.char = ns.DeepCopy(snapshot.char)
  end
  if type(snapshot.profileKeys) == "table" then
    db.profileKeys = ns.DeepCopy(snapshot.profileKeys)
  end
  if snapshot.currentProfile then
    db.current = snapshot.currentProfile
    db.profile = db.profiles and db.profiles[snapshot.currentProfile] or ns.DeepCopy(snapshot.profile)
  end
  if type(db.sv) == "table" then
    db.sv.profiles = db.profiles
    db.sv.global = db.global
    db.sv.profileKeys = db.profileKeys
  end
end

function Decursive:RestoreProfileStorageTransaction(snapshot, reason)
  local db = self.db
  if type(snapshot) ~= "table" or type(db) ~= "table" then
    return false
  end
  local aceBacked = type(db.sv) == "table" and getmetatable(db) ~= nil
  if aceBacked and type(snapshot.sv) == "table" then
    ReplaceTable(db.sv, snapshot.sv)
    rawset(db, "profiles", nil)
    rawset(db, "profile", nil)
    rawset(db, "global", nil)
    rawset(db, "char", nil)
    if type(db.keys) == "table" and snapshot.currentProfile then
      db.keys.profile = snapshot.currentProfile
    end
    local _profiles = db.profiles
    local _profile = db.profile
    local _global = db.global
    local _char = db.char
  else
    RestorePlainDB(db, snapshot)
  end
  for i = 1, #PROFILE_RUNTIME_FIELDS do
    local key = PROFILE_RUNTIME_FIELDS[i]
    self[key] = snapshot.runtime and snapshot.runtime[key] or nil
  end
  pcall(Notify)
  for i = 1, #PROFILE_RUNTIME_FIELDS do
    local key = PROFILE_RUNTIME_FIELDS[i]
    self[key] = snapshot.runtime and snapshot.runtime[key] or nil
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("PROFILE_TRANSACTION", {result = "RESTORED", reason = reason or "transaction"}, false)
  end
  return true
end

function Decursive:ValidateProfileTransactionState()
  local db = self.db
  local profile = type(db) == "table" and db.profile or nil
  local environments = type(profile) == "table" and profile.environments or nil
  if type(environments) ~= "table" then
    return false, "environments"
  end
  for _, row in ipairs(ns.ENVIRONMENTS) do
    if type(environments[row.key]) ~= "table" then
      return false, "environment-pack"
    end
  end
  if profile.routingMode ~= "multiple" and profile.routingMode ~= "solo" then
    return false, "routing-mode"
  end
  if profile.mufOrientation ~= "HORIZONTAL" and profile.mufOrientation ~= "VERTICAL" then
    return false, "orientation"
  end
  if type(profile.lists) ~= "table" or type(profile.lists.priority) ~= "table" or type(profile.lists.skip) ~= "table" then
    return false, "lists"
  end
  return true
end

function Decursive:RunProfileStorageTransaction(reason, mutation, resolveEnvironment, refreshRuntime)
  if LockedDown() then
    return false, "combat"
  end
  local snapshot = self:CaptureProfileStorageTransaction()
  if not snapshot then
    return false, "storage"
  end
  local ok, mutationResult, mutationState = pcall(mutation)
  if not ok or mutationResult == false then
    self:RestoreProfileStorageTransaction(snapshot, reason)
    return false, mutationState or "transaction"
  end
  local ensured, ensureState = self:EnsureEnvironments()
  if ensured == false then
    self:RestoreProfileStorageTransaction(snapshot, reason)
    return false, ensureState or "migration"
  end
  local valid, validState = self:ValidateProfileTransactionState()
  if not valid then
    self:RestoreProfileStorageTransaction(snapshot, reason)
    return false, validState
  end
  if refreshRuntime == false then
    if ns.RefreshOptions then
      pcall(ns.RefreshOptions)
    end
  elseif resolveEnvironment == true then
    local applied, environmentState = self:ApplyResolvedEnvironment(reason)
    if applied ~= true then
      self:RestoreProfileStorageTransaction(snapshot, reason)
      return false, environmentState or "runtime"
    end
    if environmentState ~= "applied" then
      local refreshed, refreshState = Notify()
      if refreshed ~= true then
        self:RestoreProfileStorageTransaction(snapshot, reason)
        return false, refreshState or "runtime-refresh"
      end
    end
  else
    local refreshed, refreshState = Notify()
    if refreshed ~= true then
      self:RestoreProfileStorageTransaction(snapshot, reason)
      return false, refreshState or "runtime-refresh"
    end
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("PROFILE_TRANSACTION", {result = "COMMITTED", reason = reason or "mutation"}, false)
  end
  return true, mutationState or "applied"
end

function Decursive:ActivateProfile(name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  if not self:ProfileExists(name) then
    return false, "profile"
  end
  local oldProfile, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local applied
  local state
  local ok = pcall(function()
    self:AssignActivatedProfile(name)
    applied, state = self:ApplyResolvedProfile("profile-activate")
  end)
  if not ok or applied ~= true then
    self:RestoreProfileStorageTransaction(transaction, "profile-activate")
    return false, state or "transaction"
  end
  return true, "activated"
end

function Decursive:MutateAssignment(reason, mutation)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  local oldProfile, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local applied
  local state
  local ok = pcall(function()
    mutation()
    applied, state = self:ApplyResolvedProfile(reason)
  end)
  if not ok or applied ~= true then
    self:RestoreProfileStorageTransaction(transaction, reason)
    return false, state or "transaction"
  end
  return true, "applied"
end

function Decursive:SetAccountProfileAssignment(name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  if not self:ProfileExists(name) then
    return false, "profile"
  end
  return self:MutateAssignment("account-assignment", function()
    self.db.global.accountProfile = name
  end)
end

function Decursive:SetCharacterProfileAssignment(name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  local key = self:GetCharacterKey()
  if not key then
    return false, "character"
  end
  if name ~= nil and not self:ProfileExists(name) then
    return false, "profile"
  end
  return self:MutateAssignment("character-assignment", function()
    self.db.global.characters[key] = name
  end)
end

function Decursive:SetSpecProfileAssignment(specIndex, name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  if name ~= nil and not self:ProfileExists(name) then
    return false, "profile"
  end
  local spec = specIndex or self:GetSpecIndex()
  if type(spec) ~= "number" or spec < 1 or spec > self:SpecSlotCount() then
    return false, "specialization"
  end
  return self:MutateAssignment("specialization-assignment", function()
    local row = self:GetSpecAssignment(spec)
    row.profile = name or "Default"
  end)
end

function Decursive:SetSpecProfileAssignmentEnabled(specIndex, enabled)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  local spec = specIndex or self:GetSpecIndex()
  if type(spec) ~= "number" or spec < 1 or spec > self:SpecSlotCount() then
    return false, "specialization"
  end
  return self:MutateAssignment("specialization-assignment-enabled", function()
    local row = self:GetSpecAssignment(spec)
    row.enabled = enabled == true
  end)
end

function Decursive:EnsureLists()
  local lists = self.db.profile.lists
  if type(lists) ~= "table" then
    self.db.profile.lists = {
      priority = {},
      skip = {},
    }
    return
  end
  if type(lists.priority) ~= "table" then
    lists.priority = {}
  end
  if type(lists.skip) ~= "table" then
    lists.skip = {}
  end
end

function Decursive:EnsureEnvironments()
  if type(self.db) ~= "table" or type(self.db.profile) ~= "table" or type(self.db.char) ~= "table" then
    return false, "storage"
  end
  local profileBackup = ns.DeepCopy(self.db.profile)
  local charBackup = ns.DeepCopy(self.db.char)
  local ok, state = pcall(function()
    ns.lastMacroDrops = 0
    self:EnsureLists()
    local environments = self.db.profile.environments
    if type(environments) ~= "table" then
      self.db.profile.environments = ns.MakeEnvironments()
      environments = self.db.profile.environments
    end
    local modeOK = self:MigrateEnvironmentMode(environments)
    if modeOK == false then
      error("environment-mode-migration")
    end
    local orientationOK = self:MigrateMUFOrientation(environments)
    if orientationOK == false then
      error("orientation-migration")
    end
    local appearanceOK = self:MigrateAppearanceDefaults(environments)
    if appearanceOK == false then
      error("appearance-migration")
    end
    local pvpAlertsOK = self:MigratePvPAlertDefaults(environments)
    if pvpAlertsOK == false then
      error("pvp-alert-defaults-migration")
    end
    for _, row in ipairs(ns.ENVIRONMENTS) do
      if type(environments[row.key]) ~= "table" then
        environments[row.key] = ns.MakePack(row.key)
      else
        self:FillMissing(environments[row.key], ns.MakePack(row.key))
      end
      if ns.DropOversizedMacros then
        ns.DropOversizedMacros(environments[row.key])
      end
    end
    self:MirrorMUFOrientation(environments)
    self:NormalizeEditingEnvironment()
    return "applied"
  end)
  if not ok then
    ReplaceTable(self.db.profile, profileBackup)
    ReplaceTable(self.db.char, charBackup)
    return false, "migration"
  end
  return true, state
end

function Decursive:FillMissing(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = ns.DeepCopy(v)
      else
        self:FillMissing(dst[k], v)
      end
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function Decursive:MigrateEnvironmentMode(environments)
  local profile = self.db and self.db.profile
  local targetSchema = ns.ENVIRONMENT_MODE_SCHEMA or 1
  if type(profile) ~= "table" then
    return false, "profile"
  end
  local currentSchema = rawget(profile, "environmentModeSchema")
  if type(currentSchema) == "number" and currentSchema >= targetSchema then
    if type(environments.SOLO) ~= "table" then
      environments.SOLO = ns.MakePack("SOLO")
    end
    return true, false
  end

  local legacyMode = PublicString(rawget(profile, "routingMode"))
  local legacyStatic = PublicString(rawget(profile, "staticEnvironment"))
  local migratedMode = "multiple"
  if legacyMode == "static"
    and ns.MULTIPLE_ENV_SET[legacyStatic]
    and type(environments[legacyStatic]) == "table"
  then
    environments.SOLO = ns.DeepCopy(environments[legacyStatic])
    migratedMode = "solo"
  elseif legacyMode == "solo" then
    migratedMode = "solo"
    if type(environments.SOLO) ~= "table" then
      environments.SOLO = ns.MakePack("SOLO")
    end
  elseif type(environments.SOLO) ~= "table" then
    environments.SOLO = ns.MakePack("SOLO")
  end

  profile.routingMode = migratedMode
  profile.staticEnvironment = nil
  profile.environmentModeSchema = targetSchema
  return true, true
end

function Decursive:MirrorMUFOrientation(environments)
  local profile = self.db and self.db.profile
  if type(profile) ~= "table" then
    return false
  end
  environments = type(environments) == "table" and environments or profile.environments
  if type(environments) ~= "table" then
    return false
  end
  local vertical = profile.mufOrientation == "VERTICAL"
  for _, row in ipairs(ns.ENVIRONMENTS) do
    local pack = environments[row.key]
    if type(pack) == "table" and type(pack.mufs) == "table" then
      pack.mufs.verticalLayout = vertical
    end
  end
  return true
end

function Decursive:MigrateMUFOrientation(environments)
  local profile = self.db and self.db.profile
  local targetSchema = ns.MUF_ORIENTATION_SCHEMA or 1
  if type(profile) ~= "table" then
    return false, "profile"
  end
  environments = type(environments) == "table" and environments or profile.environments
  local currentSchema = rawget(profile, "mufOrientationSchema")
  if type(currentSchema) == "number" and currentSchema >= targetSchema then
    local orientation = PublicString(rawget(profile, "mufOrientation"))
    profile.mufOrientation = orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
    self:MirrorMUFOrientation(environments)
    return true, false
  end

  local orientation = "HORIZONTAL"
  if type(environments) == "table" then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = environments[row.key]
      if type(pack) == "table" and type(pack.mufs) == "table"
        and rawget(pack.mufs, "verticalLayout") == true
      then
        orientation = "VERTICAL"
        break
      end
    end
  end
  profile.mufOrientation = orientation
  self:MirrorMUFOrientation(environments)
  profile.mufOrientationSchema = targetSchema
  return true, true
end

function Decursive:GetMUFOrientation()
  local profile = self.db and self.db.profile
  return type(profile) == "table" and profile.mufOrientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
end

function Decursive:GetMUFVerticalLayout()
  return self:GetMUFOrientation() == "VERTICAL"
end

function Decursive:ReconcileMUFOrientation(_reason)
  if LockedDown() then
    self.pendingMUFOrientation = true
    if ns.RefreshOptions then
      ns.RefreshOptions()
    end
    return false, "combat"
  end
  self.pendingMUFOrientation = nil
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  return true, "applied"
end

function Decursive:SetMUFOrientation(value)
  local ready, readyError = self:EnvironmentModeMutationReady()
  if not ready then
    return false, readyError
  end
  if value == true then
    value = "VERTICAL"
  elseif value == false then
    value = "HORIZONTAL"
  end
  if value ~= "HORIZONTAL" and value ~= "VERTICAL" then
    return false, "orientation"
  end
  return self:RunProfileStorageTransaction("orientation", function()
    self.db.profile.mufOrientation = value
    self.db.profile.mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA or 1
    self:MirrorMUFOrientation()
    return true, "applied"
  end)
end

function Decursive:NormalizeEditingEnvironment(mode)
  local char = self.db and self.db.char
  if type(char) ~= "table" then
    return "OPEN_WORLD"
  end
  mode = mode or self:GetEnvironmentMode()
  local editing = PublicString(rawget(char, "editingEnvironment"))
  if mode == "solo" then
    if ns.MULTIPLE_ENV_SET[editing] then
      char.multipleEditingEnvironment = editing
    end
    char.editingEnvironment = "SOLO"
    return "SOLO"
  end
  local multipleEditing = PublicString(rawget(char, "multipleEditingEnvironment"))
  if not ns.MULTIPLE_ENV_SET[multipleEditing] and ns.MULTIPLE_ENV_SET[editing] then
    multipleEditing = editing
  end
  if not ns.MULTIPLE_ENV_SET[multipleEditing] and ns.MULTIPLE_ENV_SET[self.detectedEnvironment] then
    multipleEditing = self.detectedEnvironment
  end
  if not ns.MULTIPLE_ENV_SET[multipleEditing] then
    multipleEditing = "OPEN_WORLD"
  end
  char.multipleEditingEnvironment = multipleEditing
  char.editingEnvironment = multipleEditing
  return multipleEditing
end

function Decursive:GetEditingEnvironment()
  self:EnsureEnvironments()
  return self:NormalizeEditingEnvironment()
end

function Decursive:GetEditingPack()
  local env = self:GetEditingEnvironment()
  return self.db.profile.environments[env]
end

function Decursive:SetEditingEnvironment(env)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  self:EnsureEnvironments()
  local mode = self:GetEnvironmentMode()
  if (mode == "solo" and env ~= "SOLO") or (mode == "multiple" and not ns.MULTIPLE_ENV_SET[env]) then
    return false, "env"
  end
  return self:RunProfileStorageTransaction("editing-environment", function()
    self.db.char.editingEnvironment = env
    if mode == "multiple" then
      self.db.char.multipleEditingEnvironment = env
    end
    return true, "applied"
  end, false, false)
end

function Decursive:MigrateAppearanceDefaults(environments)
  local profile = self.db and self.db.profile
  local targetSchema = ns.MUF_APPEARANCE_SCHEMA or 1
  if type(profile) ~= "table" then
    return false, "profile"
  end
  local currentSchema = rawget(profile, "appearanceSchema")
  if type(currentSchema) == "number" and currentSchema >= targetSchema then
    return true, 0
  end
  environments = type(environments) == "table" and environments or profile.environments
  local openWorld = type(environments) == "table" and environments.OPEN_WORLD or nil
  local migrated = 0
  if (type(currentSchema) ~= "number" or currentSchema < 1)
    and ns.HasObsoleteOpenWorldAppearance and ns.HasObsoleteOpenWorldAppearance(openWorld)
  then
    openWorld.mufs.dimOutOfRange = false
    migrated = 1
  end
  if type(currentSchema) ~= "number" or currentSchema < 2 then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = type(environments) == "table" and environments[row.key] or nil
      if ns.HasObsoleteDeathColor and ns.HasObsoleteDeathColor(pack) then
        pack.colors.dead = {0, 0, 0, 1}
        migrated = migrated + 1
      end
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 3 then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = type(environments) == "table" and environments[row.key] or nil
      if ns.HasLegacyMUFDisplayCap and ns.HasLegacyMUFDisplayCap(pack) then
        pack.mufs.maxUnits = ns.DEFAULT_MUF_DISPLAY_CAP or 5
        migrated = migrated + 1
      end
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 4 then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = type(environments) == "table" and environments[row.key] or nil
      if ns.HasLegacyRangeAlpha and ns.HasLegacyRangeAlpha(pack) then
        pack.colors.range[4] = 1
        migrated = migrated + 1
      end
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 5 then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = type(environments) == "table" and environments[row.key] or nil
      if ns.HasLegacyRangeDefault and ns.HasLegacyRangeDefault(pack) then
        pack.colors.range = ns.DeepCopy(ns.DEFAULT_RANGE_COLOR)
        migrated = migrated + 1
      end
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 6 then
    for _, row in ipairs(ns.ENVIRONMENTS) do
      local pack = type(environments) == "table" and environments[row.key] or nil
      if ns.MigrateCanonicalCurePalette then
        migrated = migrated + ns.MigrateCanonicalCurePalette(pack)
      end
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 7 then
    local raid = type(environments) == "table" and environments.RAID or nil
    if ns.HasPriorDefaultRaidMUFDisplayCap and ns.HasPriorDefaultRaidMUFDisplayCap(raid) then
      raid.mufs.maxUnits = ns.DEFAULT_RAID_MUF_DISPLAY_CAP or 40
      migrated = migrated + 1
    end
  end
  if type(currentSchema) ~= "number" or currentSchema < 8 then
    local pvp = type(environments) == "table" and environments.PVP or nil
    if ns.HasPriorDefaultPvPMUFDisplayCap and ns.HasPriorDefaultPvPMUFDisplayCap(pvp) then
      pvp.mufs.maxUnits = ns.DEFAULT_PVP_MUF_DISPLAY_CAP or 40
      migrated = migrated + 1
    end
  end
  profile.appearanceSchema = targetSchema
  return true, migrated
end

function Decursive:MigratePvPAlertDefaults(environments)
  local profile = self.db and self.db.profile
  local targetSchema = ns.PVP_ALERT_DEFAULTS_SCHEMA or 1
  if type(profile) ~= "table" then
    return false, "profile"
  end
  local currentSchema = rawget(profile, "pvpAlertDefaultsSchema")
  if type(currentSchema) == "number" and currentSchema >= targetSchema then
    return true, 0
  end
  environments = type(environments) == "table" and environments or profile.environments
  local pvp = type(environments) == "table" and environments.PVP or nil
  local migrated = 0
  if ns.MigratePvPQuietAlertDefaults then
    migrated = ns.MigratePvPQuietAlertDefaults(pvp)
  end
  profile.pvpAlertDefaultsSchema = targetSchema
  return true, migrated
end

function Decursive:ResetEditingPack()
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  local env = self:GetEditingEnvironment()
  return self:RunProfileStorageTransaction("pack-reset", function()
    self.db.profile.environments[env] = ns.MakePack(env)
    self:MirrorMUFOrientation()
    return true, "reset"
  end)
end

function Decursive:CopyEditingPackTo(targetEnv)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  if self:GetEnvironmentMode() ~= "multiple" or not ns.MULTIPLE_ENV_SET[targetEnv] then
    return false, "env"
  end
  local src = self:GetEditingEnvironment()
  if src == targetEnv then
    return false, "same"
  end
  return self:RunProfileStorageTransaction("pack-copy", function()
    local ensured = self:EnsureEnvironments()
    if ensured == false then
      return false, "migration"
    end
    self.db.profile.environments[targetEnv] = ns.DeepCopy(self:GetEditingPack())
    self:MirrorMUFOrientation()
    return true, "copied"
  end)
end

function Decursive:ResetCurrentProfile()
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  return self:RunProfileStorageTransaction("profile-reset", function()
    self.db.profile.environments = ns.MakeEnvironments()
    self.db.profile.routingMode = "multiple"
    self.db.profile.staticEnvironment = nil
    self.db.profile.environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA or 1
    self.db.profile.pvpAlertDefaultsSchema = ns.PVP_ALERT_DEFAULTS_SCHEMA or 1
    self.db.profile.mufOrientation = "HORIZONTAL"
    self.db.profile.mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA or 1
    self.db.profile.lists = {
      priority = {},
      skip = {},
    }
    self:NormalizeEditingEnvironment("multiple")
    return true, "reset"
  end, true, true)
end

function Decursive:ResetAllSettings()
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  return self:RunProfileStorageTransaction("settings-reset", function()
    self.db:ResetDB("Default")
    return true, "reset"
  end, true, true)
end

function Decursive:CreateProfile(name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  name = CleanProfileName(name)
  if not name then
    return false, "invalid-name"
  end
  if self:ProfileNameExists(name) then
    return false, "exists"
  end
  local profiles, profilesError = self:GetProfileNames()
  if profilesError then
    return false, profilesError
  end
  if #profiles >= MAX_PROFILES then
    return false, "profile-limit"
  end
  local oldProfile, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local applied
  local state
  local ok = pcall(function()
    self.db:SetProfile(name)
    self:EnsureEnvironments()
    self:AssignActivatedProfile(name)
    applied, state = self:ApplyResolvedProfile("profile-create")
  end)
  if not ok or applied ~= true then
    self:RestoreProfileStorageTransaction(transaction, "profile-create")
    return false, state or "transaction"
  end
  return true, "created"
end

function Decursive:CopyProfile(name)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  name = CleanProfileName(name)
  local oldName, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  if not name or name == oldName then
    return false, "invalid-name"
  end
  if self:ProfileNameExists(name) then
    return false, "exists"
  end
  local profiles, profilesError = self:GetProfileNames()
  if profilesError then
    return false, profilesError
  end
  if #profiles >= MAX_PROFILES then
    return false, "profile-limit"
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local applied
  local state
  local ok = pcall(function()
    self.db:SetProfile(name)
    self.db:CopyProfile(oldName, true)
    self:EnsureEnvironments()
    self:AssignActivatedProfile(name)
    applied, state = self:ApplyResolvedProfile("profile-copy")
  end)
  if not ok or applied ~= true then
    self:RestoreProfileStorageTransaction(transaction, "profile-copy")
    return false, state or "transaction"
  end
  return true, "copied"
end

function Decursive:RenameProfile(newName)
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  newName = CleanProfileName(newName)
  local oldName, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  if oldName == "Default" then
    return false, "default"
  end
  if not newName or newName == oldName then
    return false, "invalid-name"
  end
  if self:ProfileNameExists(newName, oldName) then
    return false, "exists"
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local prepared = pcall(function()
    self.db:SetProfile(newName)
    self.db:CopyProfile(oldName, true)
    self:EnsureEnvironments()
    self:RetargetAssignments(oldName, newName)
  end)
  if not prepared then
    self:RestoreProfileStorageTransaction(transaction, "profile-rename")
    return false, "transaction"
  end
  local deleted = pcall(self.db.DeleteProfile, self.db, oldName, true)
  if not deleted then
    self:RestoreProfileStorageTransaction(transaction, "profile-rename")
    return false, "transaction"
  end
  local refreshed, refreshState = Notify()
  if refreshed ~= true then
    self:RestoreProfileStorageTransaction(transaction, "profile-rename")
    return false, refreshState or "runtime-refresh"
  end
  return true, "renamed"
end

function Decursive:DeleteCurrentProfile()
  local ready, readyError = self:ProfileMutationReady()
  if not ready then
    return false, readyError
  end
  local name, currentError = self:GetCurrentProfileName()
  if currentError then
    return false, currentError
  end
  if name == "Default" then
    return false, "default"
  end
  local transaction = self:CaptureProfileStorageTransaction()
  local prepared = pcall(function()
    self.db:SetProfile("Default")
    self:RetargetAssignments(name, "Default")
    self:EnsureEnvironments()
  end)
  if not prepared then
    self:RestoreProfileStorageTransaction(transaction, "profile-delete")
    return false, "transaction"
  end
  local deleted = pcall(self.db.DeleteProfile, self.db, name, true)
  if not deleted then
    self:RestoreProfileStorageTransaction(transaction, "profile-delete")
    return false, "transaction"
  end
  local refreshed, refreshState = Notify()
  if refreshed ~= true then
    self:RestoreProfileStorageTransaction(transaction, "profile-delete")
    return false, refreshState or "runtime-refresh"
  end
  return true, "deleted"
end

function Decursive:RetargetAssignments(oldName, newName)
  local g = self.db.global
  if g.accountProfile == oldName then
    g.accountProfile = newName
  end
  for key, profileName in pairs(g.characters) do
    if profileName == oldName then
      g.characters[key] = newName
    end
  end
  for key, specMap in pairs(g.specs) do
    if type(specMap) == "table" then
      for spec, row in pairs(specMap) do
        if type(row) == "table" and row.profile == oldName then
          row.profile = newName
        end
      end
    end
  end
end

function Decursive:SpecSlotCount()
  local specialization = C_SpecializationInfo
  local count
  if type(specialization) == "table" and type(specialization.GetNumSpecializations) == "function" then
    local ok, result = pcall(specialization.GetNumSpecializations)
    if ok then
      count = PublicNumber(result)
    end
  end
  if type(count) ~= "number" or count < 1 then
    count = 4
  end
  if count > 4 then
    count = 4
  end
  return count
end

function Decursive:EnsureSpecAssignments()
  local key = self:GetCharacterKey()
  if not key then
    return nil
  end
  local global = self.db and self.db.global
  if type(global) ~= "table" or type(global.specs) ~= "table" then
    return nil, "malformed-storage"
  end
  local specMap = global.specs[key]
  if type(specMap) ~= "table" then
    specMap = {}
    global.specs[key] = specMap
  end
  for spec = 1, self:SpecSlotCount() do
    if type(specMap[spec]) ~= "table" then
      specMap[spec] = {enabled = false, profile = "Default"}
    end
  end
  return specMap
end

function Decursive:GetSpecAssignment(specIndex)
  local key = self:GetCharacterKey()
  if not key then
    return nil, nil
  end
  local specMap = self:EnsureSpecAssignments()
  local spec = specIndex or self:GetSpecIndex()
  if not spec or not specMap then
    return nil, nil
  end
  local row = specMap[spec]
  if type(row) ~= "table" then
    row = {enabled = false, profile = "Default"}
    specMap[spec] = row
  end
  return row, spec
end

function Decursive:HandleResetSlash(msg)
  msg = strtrim(tostring(msg or "")):lower()
  if msg == "" or msg == "pack" or msg == "env" then
    local env = self:GetEditingEnvironment()
    local ok, state = self:ResetEditingPack()
    if ok then
      self:Print("reset pack " .. tostring(env))
    else
      self:Print("reset not applied (" .. tostring(state or "unavailable") .. ")")
    end
    return
  end
  if msg == "profile" then
    local ok, state = self:ResetCurrentProfile()
    if ok then
      self:Print("reset profile " .. tostring(self.db:GetCurrentProfile()))
    else
      self:Print("reset not applied (" .. tostring(state or "unavailable") .. ")")
    end
    return
  end
  if msg == "all" then
    local ok, state = self:ResetAllSettings()
    if ok then
      self:Print("reset all settings")
    else
      self:Print("reset not applied (" .. tostring(state or "unavailable") .. ")")
    end
    return
  end
  self:Print("/dcrreset [pack|profile|all]")
end

local function DiagnosticAssignmentTier()
  local db = Decursive.db
  local global = type(db) == "table" and db.global or nil
  if type(global) ~= "table" then
    return "unknown"
  end
  local key = Decursive:GetCharacterKey()
  local spec = Decursive:GetSpecIndex()
  if key and spec and type(global.specs) == "table" then
    local specMap = global.specs[key]
    local row = type(specMap) == "table" and specMap[spec] or nil
    if type(row) == "table" and row.enabled == true and Decursive:ProfileExists(row.profile) then
      return "specialization"
    end
  end
  if key and type(global.characters) == "table" and Decursive:ProfileExists(global.characters[key]) then
    return "character"
  end
  if Decursive:ProfileExists(global.accountProfile) then
    return "account"
  end
  return "default"
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("Core", function()
    local db = Decursive.db
    local bound = type(db) == "table"
    local currentAvailable = false
    if bound and type(db.GetCurrentProfile) == "function" then
      local ok, current = pcall(db.GetCurrentProfile, db)
      currentAvailable = ok and PublicString(current) ~= nil
    end
    local editingEnvironment = "unknown"
    if bound and type(db.char) == "table" then
      editingEnvironment = ns.ENV_SET and ns.ENV_SET[db.char.editingEnvironment] and db.char.editingEnvironment or "unknown"
    end
    local environmentStatus = Decursive:GetEnvironmentProfileStatus()
    return {
      aceDBBound = bound,
      currentProfileAvailable = currentAvailable,
      resolvedAssignmentTier = DiagnosticAssignmentTier(),
      environmentPackID = environmentStatus.appliedEnvironment,
      appliedEnvironment = environmentStatus.appliedEnvironment,
      resolvedEnvironment = environmentStatus.resolvedEnvironment,
      detectedEnvironment = environmentStatus.detectedEnvironment,
      environmentMode = environmentStatus.environmentMode,
      mufOrientation = Decursive:GetMUFOrientation(),
      mufOrientationPending = Decursive.pendingMUFOrientation == true,
      pendingEnvironment = environmentStatus.pendingEnvironment or "absent",
      editingEnvironment = editingEnvironment,
      environmentResolutionReason = environmentStatus.reason,
      environmentResolutionTier = environmentStatus.tier,
      environmentContextAPI = environmentContextAPI,
      environmentContextReady = environmentContextReady,
      environmentRetryCount = Decursive.environmentRetryCount or 0,
      environmentRetryPending = Decursive.environmentRetryPending == true,
      profileResolvePending = Decursive.profileResolvePending == true,
      profileChangeGeneration = Decursive.profileChangeGeneration or 0,
      worldEntryRecoveryGeneration = Decursive.worldEntryRecoveryGeneration or 0,
      worldEntryRecoveryPending = Decursive.worldEntryRecoveryPending == true,
      worldEntryRecoveryReason = Decursive.worldEntryRecoveryReason or "NONE",
      worldEntryRecoveryRetryPolicy = "BOUNDED_TIMER_SAME_WORLD_TOKEN",
      worldEntryRecoveryRetryCount = Decursive.worldEntryRecoveryRetryCount or 0,
      worldEntryRecoveryRetryPending = Decursive.worldEntryRecoveryRetryPending == true,
      worldEntryRecoveryRetryExhausted = Decursive.worldEntryRecoveryRetryExhausted == true,
      fullWorldRecoveryGeneration = Decursive.fullWorldRecoveryGeneration or 0,
      fullWorldRecoveryPending = Decursive.fullWorldRecoveryPending == true,
      fullWorldRecoveryScheduled = Decursive.fullWorldRecoveryScheduled == true,
      fullWorldRecoveryReset = Decursive.fullWorldRecoveryReset == true,
      fullWorldRecoveryPass = Decursive.fullWorldRecoveryPass or 0,
      fullWorldRecoveryReason = Decursive.fullWorldRecoveryReason or "NONE",
      fullWorldCandidateSamples = Decursive.fullWorldCandidateSamples or 0,
      fullWorldCandidateCount = Decursive.fullWorldCandidateCount or 0,
      fullWorldCandidateReason = Decursive.fullWorldCandidateReason or "NONE",
      fullWorldRetainedLastGood = Decursive.fullWorldRecoveryPending == true and Decursive.fullWorldRecoveryReset ~= true,
      rosterRecoveryGeneration = Decursive.rosterRecoveryGeneration or 0,
      rosterRecoveryPending = Decursive.rosterRecoveryPending == true,
      rosterRecoveryReason = Decursive.rosterRecoveryReason or "NONE",
      rosterRecoveryRetryPolicy = "BOUNDED_TIMER_CANONICAL_TOKEN_SIGNATURE",
      rosterRecoveryRetryCount = Decursive.rosterRecoveryRetryCount or 0,
      rosterRecoveryRetryPending = Decursive.rosterRecoveryRetryPending == true,
      rosterRecoveryRetryExhausted = Decursive.rosterRecoveryRetryExhausted == true,
      rosterUnitCount = Decursive.rosterUnitCount or 0,
      rosterPetCount = Decursive.rosterPetCount or 0,
      rosterIdentityData = "UNIT_TOKENS_ONLY",
      notifyAvailable = type(ns.Notify) == "function",
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Core")
end
