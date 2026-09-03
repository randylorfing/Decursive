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

local secret = setmetatable({}, {
  __tostring = function()
    error("secret value was stringified")
  end,
})

issecretvalue = function(value)
  return rawequal(value, secret)
end

canaccessvalue = function(value)
  return not issecretvalue(value)
end

issecrettable = function(value)
  if type(value) ~= "table" then
    error("issecrettable only accepts tables")
  end
  return false
end

local combat = false
InCombatLockdown = function()
  return combat
end

InChatMessagingLockdown = function()
  return combat
end

GetBuildInfo = function()
  return "12.1.0", "63305", "Sep 2026", 120100
end

C_AddOns = {
  GetAddOnMetadata = function(_name, field)
    if field == "Version" then
      return "13.0.0-detect.77"
    end
    if field == "Interface" then
      return "120100"
    end
  end,
  IsAddOnLoaded = function()
    return true
  end,
  GetAddOnInfo = function()
    return "ZDecursive", "Zhaohu's Decursive", "Detect Dispel Protect", true, "NONE", "INSECURE"
  end,
  GetAddOnEnableState = function()
    return 2
  end,
}

UnitName = function()
  return "PrivateCharacter"
end

C_EventUtils = {
  IsEventValid = function()
    return true
  end,
}

local function Region()
  local region = {shown = false, text = ""}
  local methods = {
    "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "SetTextInsets", "SetMultiLine", "SetAutoFocus", "SetFontObject",
    "SetWidth", "SetCursorPosition", "ClearFocus", "SetScrollChild", "SetHeight", "SetFont",
  }
  for i = 1, #methods do
    region[methods[i]] = function()
    end
  end
  function region:SetScript(kind, callback)
    self.scripts = self.scripts or {}
    self.scripts[kind] = callback
  end
  function region:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
  end
  function region:CreateFontString()
    return Region()
  end
  function region:SetText(value)
    self.text = value
  end
  function region:Show()
    self.shown = true
  end
  function region:Hide()
    self.shown = false
  end
  function region:IsShown()
    return self.shown
  end
  return region
end

CreateFrame = function()
  return Region()
end

UIParent = Region()
GameMenuFrame = Region()
GameMenuButtonAddons = Region()
SlashCmdList = {}
DecursiveRebuildDB = {global = {schema = 3}}

LibStub = setmetatable({}, {
  __call = function(_self, name)
    if name == "AceAddon-3.0" or name == "AceDB-3.0" then
      return {}
    end
  end,
})

local recorded = {}
local ns = {
  addon = {},
  DiagnosticRecord = function(kind, fields)
    recorded[#recorded + 1] = {kind = kind, fields = fields}
  end,
  GetProfileStoragePreflightStatus = function()
    return {ok = true, reason = "current-or-older", nodes = 20, bytes = 400, maxDepth = 4}
  end,
  GetResolvedClickStatus = function()
    return {
      available = true,
      pending = false,
      mode = "AUTO",
      generation = 4,
      mappings = {{}, {}, {}},
    }
  end,
}

assert(loadfile("ZDecursive/Diagnostics.lua"))("ZDecursive", ns)
local diagnostics = ns.Diagnostics
diagnostics.State.coreInitialize = "success"
diagnostics.State.coreEnable = "success"

local core = {
  aceDBBound = true,
  currentProfileAvailable = true,
  environmentMode = "solo",
  detectedEnvironment = "DUNGEON",
  resolvedEnvironment = "SOLO",
  appliedEnvironment = "SOLO",
  editingEnvironment = "SOLO",
  profileResolvePending = false,
  worldEntryRecoveryPending = false,
  worldEntryRecoveryRetryPending = false,
  worldEntryRecoveryRetryExhausted = false,
  fullWorldRecoveryPending = false,
  fullWorldRecoveryScheduled = false,
  rosterRecoveryPending = false,
  rosterRecoveryRetryPending = false,
  rosterRecoveryRetryExhausted = false,
  rosterUnitCount = 1,
}

local detection = {
  rosterContextReady = true,
  rosterContext = "NO_PARTY",
  restrictionActive = false,
  attachmentAttempts = 1,
  attachments = 1,
  attachmentFailures = 0,
  attachmentPendingCombat = false,
  attachmentPendingRestriction = false,
  actionableTypeCount = 4,
  enabledActionableTypeCount = 4,
  knownCureActionCount = 1,
  customCureActionCount = 0,
  rosterTokenCounts = {player = 1, party = 0, raid = 0, pets = 0, total = 1},
}

local engine = {
  lifecycleState = "READY",
  started = true,
  eventsRegistered = true,
  pendingReconcile = false,
  failClosed = false,
  retryExhausted = false,
  retryScheduled = false,
  requiredConsumerCount = 3,
  registeredRequiredConsumerCount = 3,
  desiredCarrierCount = 1,
  activeCarrierCount = 1,
  transactionConfiguredCarrierCount = 1,
  transactionShownCarrierCount = 1,
  pendingAssignmentCount = 0,
  consumerStates = {
    MUFs = {registered = true, available = true, expectedCount = 1, desired = 1, active = 1, configured = 1, shown = 1},
    Alerts = {registered = true, available = true, expectedCount = 0, desired = 0, active = 0, configured = 0, shown = 0},
    LiveList = {registered = true, available = true, expectedCount = 0, desired = 0, active = 0, configured = 0, shown = 0},
  },
}

local mufs = {
  assignedCount = 1,
  visibleCount = 1,
  configured = true,
  pendingRefresh = false,
  clickModelBuilt = true,
  clickInstalledCount = 1,
  clickRebuildPending = false,
}

local alerts = {
  soundConfigured = true,
  soundMode = "NATIVE_ADDED",
  nativeRegistrations = 1,
  nativeDesiredRegistrations = 1,
  nativeExactRegistrations = 1,
  nativeStaleRegistrations = 0,
  nativeAddFailures = 0,
  nativeRemoveFailures = 0,
  nativeLastResult = "SUCCESS",
  nativeReplayExhausted = false,
  nativeRemoveRetryExhausted = false,
  pendingRefresh = false,
  chatLockdown = false,
}

local function RegisterHealthyProviders()
  ns.RegisterDiagnosticProvider("Core", function()
    return core
  end)
  ns.RegisterDiagnosticProvider("Detection", function()
    return detection
  end)
  ns.RegisterDiagnosticProvider("DetectionEngine", function()
    return engine
  end)
  ns.RegisterDiagnosticProvider("MUFs", function()
    return mufs
  end)
  ns.RegisterDiagnosticProvider("Alerts", function()
    return alerts
  end)
end

RegisterHealthyProviders()

local report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "HEALTHY", "healthy runtime verdict")
Check(report:find("First actionable stage: None", 1, true), "healthy report has no actionable failure")
Check(recorded[#recorded].kind == "HEALTH_CHECK", "health summary is persisted as one bounded event")
Check(recorded[#recorded].fields.verdict == "HEALTHY", "persisted health summary contains only verdict fields")

alerts.nativeLastResult = "NEVER"
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "FAILED", "enabled sound that never reconciled is detected")
Equal(result.firstActionable.key, "SOUND_REGISTRY", "never-reconciled sound identifies the registry stage")
alerts.nativeLastResult = "SUCCESS"

engine.registeredRequiredConsumerCount = 2
engine.consumerStates.LiveList.registered = false
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "FAILED", "missing startup consumer fails health")
Equal(result.firstActionable.key, "REQUIRED_CONSUMERS", "missing startup consumer is first actionable stage")
engine.registeredRequiredConsumerCount = 3
engine.consumerStates.LiveList.registered = true

engine.activeCarrierCount = 0
engine.transactionConfiguredCarrierCount = 0
engine.transactionShownCarrierCount = 0
engine.consumerStates.MUFs.active = 0
engine.consumerStates.MUFs.configured = 0
engine.consumerStates.MUFs.shown = 0
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "FAILED", "READY desired-one active-zero cannot report healthy")
Equal(result.firstActionable.key, "CARRIER_BANKS", "false APPLIED regression identifies carrier coverage")

combat = true
engine.lifecycleState = "COMBAT_DEFERRED"
engine.pendingReconcile = true
engine.pendingAssignmentCount = 1
detection.attachmentPendingCombat = true
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "DEFERRED", "combat mutation is deferred rather than failed")

combat = false
engine.lifecycleState = "RECOVERING"
detection.attachmentPendingCombat = false
detection.attachmentPendingRestriction = true
detection.restrictionActive = true
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "DEFERRED", "addon restriction mutation is deferred")

engine.lifecycleState = "READY"
engine.pendingReconcile = false
engine.pendingAssignmentCount = 0
engine.activeCarrierCount = 1
engine.transactionConfiguredCarrierCount = 1
engine.transactionShownCarrierCount = 1
engine.consumerStates.MUFs.active = 1
engine.consumerStates.MUFs.configured = 1
engine.consumerStates.MUFs.shown = 1
detection.attachmentPendingRestriction = false
detection.restrictionActive = false
core.fullWorldRecoveryPending = true
detection.rosterContextReady = false
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "RECOVERING", "provisional world recovery is distinguished from failure")
Equal(result.firstActionable.key, "ROSTER_RECOVERY", "world recovery is first provisional stage")
core.fullWorldRecoveryPending = false
detection.rosterContextReady = true

alerts.soundConfigured = false
alerts.soundMode = "OFF"
alerts.nativeRegistrations = 0
alerts.nativeDesiredRegistrations = 0
alerts.nativeExactRegistrations = 0
alerts.nativeStaleRegistrations = 0
alerts.pendingRefresh = false
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "HEALTHY", "sound disabled by setting is healthy and not applicable")

alerts.nativeRegistrations = 1
alerts.nativeStaleRegistrations = 1
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "FAILED", "disabled sound with stale owned handles fails")
Equal(result.firstActionable.key, "SOUND_REGISTRY", "stale sound handle identifies sound registry")
alerts.nativeRegistrations = 0
alerts.nativeStaleRegistrations = 0

ns.RegisterDiagnosticProvider("DetectionEngine", function()
  error("private path and identity must not escape")
end)
report, result = diagnostics.RunHealthCheck(false)
Equal(result.verdict, "FAILED", "provider failure is isolated and fails its stage")
Check(not report:find("private path", 1, true), "provider error text is not exposed")
ns.RegisterDiagnosticProvider("DetectionEngine", function()
  return engine
end)

local savedMode = core.environmentMode
core.environmentMode = secret
local ok, redactedReport = pcall(function()
  return diagnostics.RunHealthCheck(false)
end)
Check(ok, "secret provider input cannot break health check")
Check(not redactedReport:find("PrivateCharacter", 1, true), "character identity is absent")
Check(redactedReport:find("raw signatures, spell IDs", 1, true), "health report states its spell-identity redaction policy")
core.environmentMode = savedMode

report, result = diagnostics.RunHealthCheck(true)
Equal(result.verdict, "HEALTHY", "healthy state restored")
local window = diagnostics.GetWindow()
Check(window and window.shown and window.editBox.text:find("Zhaohu's Decursive Health Check", 1, true),
  "health check renders in the existing copyable diagnostics window")

local options = assert(io.open("ZDecursive/Options.lua", "rb")):read("*a")
local persistent = assert(io.open("ZDecursive/PersistentDiagnostics.lua", "rb")):read("*a")
Check(options:find('"Run Health Check"', 1, true), "Options exposes Run Health Check")
Check(options:find('OptionsAccessAllowed("DIAGNOSTICS_HEALTH")', 1, true), "Options health button preserves combat guard")
Check(persistent:find('command == "health"', 1, true), "/zdiag health is routed by persistent diagnostics")
Check(not options:find("print(", 1, true), "Options health output is never chat debug")
Check(not persistent:find("DEFAULT_CHAT_FRAME", 1, true), "persistent health output is never chat debug")

io.write("diagnostics-health-contract: ok\n")
