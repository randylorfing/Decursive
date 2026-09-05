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
  ns.DiagnosticCheckpoint("module", "DetectionEngine file start")
end

local ENGINE_VERSION = 7
local RETRY_DELAYS = {0.15, 0.50, 1.00, 2.00, 4.00, 7.00, 10.00, 13.00, 16.00}
local MAX_RETRY_ATTEMPTS = #RETRY_DELAYS
local STATES = {
  COLD = "COLD",
  CONFIGURING = "CONFIGURING",
  READY = "READY",
  COMBAT_DEFERRED = "COMBAT_DEFERRED",
  RECOVERING = "RECOVERING",
  FAILED = "FAILED",
}

local STATUS = {
  SUCCESS = "SUCCESS",
  DEFERRED_COMBAT = "DEFERRED_COMBAT",
  DEFERRED_RESTRICTED = "DEFERRED_RESTRICTED",
  FAILURE = "FAILURE",
}

local STATUS_SEVERITY = {
  SUCCESS = 0, DEFERRED_RESTRICTED = 1, DEFERRED_COMBAT = 2, FAILURE = 3,
}

local function StrongerStatus(left, right)
  return (STATUS_SEVERITY[right] or 3) > (STATUS_SEVERITY[left] or 3) and right or left
end

-- Initializers historically return nil; consumer refreshes require explicit success.
local function CallbackStatus(ok, result, status, allowNil)
  if not ok then return STATUS.FAILURE end
  if status == STATUS.FAILURE or result == STATUS.FAILURE then return STATUS.FAILURE end
  if status == STATUS.DEFERRED_COMBAT or result == STATUS.DEFERRED_COMBAT then return STATUS.DEFERRED_COMBAT end
  if status == STATUS.DEFERRED_RESTRICTED or result == STATUS.DEFERRED_RESTRICTED then return STATUS.DEFERRED_RESTRICTED end
  if result == false then return STATUS.FAILURE end
  if result == true or result == STATUS.SUCCESS or allowNil and result == nil then return STATUS.SUCCESS end
  return STATUS.FAILURE
end

local REQUIRED_CONSUMERS = {"MUFs", "Alerts", "LiveList"}
local REQUIRED_CONSUMER_SET = {MUFs = true, Alerts = true, LiveList = true}

local Engine = {
  version = ENGINE_VERSION,
  state = STATES.COLD,
  stateGeneration = 0,
  configurationGeneration = 0,
  assignmentGeneration = 0,
  refreshGeneration = 0,
  carrierGeneration = 0,
  slotCreationGeneration = 0,
  providerRefreshGeneration = 0,
  slotProviderRefreshGeneration = 0,
  combatEntryGeneration = 0,
  nativeCombatGeneration = 0,
  regenSeenGeneration = 0,
  regenReconcileGeneration = 0,
  pending = false,
  pendingReason = "NONE",
  failureCount = 0,
  lastFailure = "NONE",
  carriers = {},
  carrierByOwner = {},
  carrierByContainer = {},
  consumers = {},
  consumerOrder = {},
  eventsRegistered = false,
  reconciling = false,
  preparingConsumers = false,
  transactionFailed = false,
  scopedFailureConsumers = {},
  failClosed = false,
  desiredGeneration = 0,
  configuredPackGeneration = 0,
  retryGeneration = 0,
  retryAttempts = 0,
  retryScheduled = false,
  retryExhausted = false,
  retryToken = 0,
  assignmentDeferredCombatCount = 0,
  assignmentReplayedOOCCount = 0,
  deferredStatus = nil,
  started = false,
  startRequested = false,
  requiredConsumerCount = #REQUIRED_CONSUMERS,
  registeredRequiredConsumerCount = 0,
  isolatedFailureCount = 0,
  pendingReasons = {},
  dirtyGeneration = 0,
  committedGeneration = 0,
  itemActionRefreshScheduled = false,
  capabilityRefreshPending = false,
  capabilityRefreshScheduled = false,
  capabilityRefreshToken = 0,
  capabilityRefreshReasons = {},
  providerReuseCount = 0,
  auraTraceEnabled = false,
  auraTraceTotal = 0,
  auraTraceCombat = 0,
  auraTraceUnits = {},
  auraTraceRegistrationFailures = 0,
}

local function LockedDown()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function Restricted()
  if type(ns.HasActiveAddonRestriction) ~= "function" then
    return false
  end
  local ok, active = pcall(ns.HasActiveAddonRestriction)
  return not ok or active == true
end

local function MutationBlocked()
  return LockedDown()
end

local function ResumeCoreWorldRecovery(reason)
  local owner = ns.addon
  if type(owner) ~= "table" or owner.fullWorldRecoveryPending ~= true
    or type(owner.RunFullWorldRecoveryPass) ~= "function" then
    return false
  end
  owner:RunFullWorldRecoveryPass(
    reason or "ENGINE_WAKEUP",
    owner.fullWorldRecoveryGeneration or 0,
    owner.fullWorldRecoveryPass or 0,
    false
  )
  if owner.fullWorldRecoveryPending == true and type(owner.ScheduleFullWorldRecovery) == "function" then
    owner:ScheduleFullWorldRecovery(reason or "ENGINE_WAKEUP")
  end
  return true
end

local function CurrentPack()
  local addon = ns.addon
  if addon and type(addon.GetAppliedEnvironmentPack) == "function" then
    local ok, pack = pcall(addon.GetAppliedEnvironmentPack, addon)
    if ok and type(pack) == "table" then
      return pack
    end
  end
  if type(ns.PACK) == "table" then
    return ns.PACK
  end
  return nil
end

local function ItemActionSignature()
  if type(ns.GetDetectionItemActionSignature) ~= "function" then
    return nil
  end
  local ok, signature = pcall(ns.GetDetectionItemActionSignature)
  if ok and type(signature) == "string" then
    if type(ns.GetBandageInventorySignature) == "function" then
      local bandageOK, bandageSignature = pcall(ns.GetBandageInventorySignature)
      if not bandageOK or type(bandageSignature) ~= "string" then return nil end
      return signature .. "|bandages:" .. bandageSignature
    end
    return signature
  end
  return nil
end

local function PublicBoolean(value)
  if ns.Diagnostics and type(ns.Diagnostics.SafePublicBoolean) == "function" then
    return ns.Diagnostics.SafePublicBoolean(value)
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then
      return nil
    end
  end
  if value == true or value == false then
    return value
  end
  return nil
end

local function PublicNumber(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then
      return nil
    end
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function PublicUnitToken(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then
      return nil
    end
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function UnitCategory(unit)
  if unit == "player" then
    return "player"
  end
  if unit == "pet" or type(unit) == "string" and (unit:match("^partypet%d+$") or unit:match("^raidpet%d+$")) then
    return "pets"
  end
  if type(unit) == "string" and unit:match("^party%d+$") then
    return "party"
  end
  if type(unit) == "string" and unit:match("^raid%d+$") then
    return "raid"
  end
  return "other"
end

function Engine:SetState(nextState, milestone)
  local previous = self.state
  if self.state ~= nextState then
    self.state = nextState
    self.stateGeneration = self.stateGeneration + 1
  end
  if ns.DiagnosticCheckpoint and milestone then
    ns.DiagnosticCheckpoint("runtime", "DetectionEngine " .. milestone)
  end
  if ns.DiagnosticRecord and previous ~= nextState then
    ns.DiagnosticRecord("ENGINE_STATE", {previous = previous, current = nextState, reason = milestone or "NONE"}, false)
  end
end

function Engine:RecordFailure(code, fatal)
  self.failureCount = self.failureCount + 1
  self.lastFailure = type(code) == "string" and code or "UNKNOWN"
  if fatal then
    self:SetState(STATES.FAILED, "failed")
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_FAILURE", {code = self.lastFailure, fatal = fatal == true, count = self.failureCount}, false)
  end
end

function Engine:MarkDirty(reason)
  reason = type(reason) == "string" and reason or "DEFERRED"
  if self.pendingReasons[reason] ~= true then
    self.pendingReasons[reason] = true
    self.dirtyGeneration = self.dirtyGeneration + 1
  end
  self.pending = true
  self.pendingReason = reason
  return reason
end

function Engine:ClearDirty()
  self.pendingReasons = {}
  self.pending = false
  self.pendingReason = "NONE"
  self.committedGeneration = self.dirtyGeneration
end

function Engine:Defer(reason)
  self:MarkDirty(reason)
  self.deferredStatus = LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED
  self:SetState(LockedDown() and STATES.COMBAT_DEFERRED or STATES.RECOVERING, "mutation deferred")
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_DEFER", {reason = self.pendingReason}, false)
  end
  if type(self.ScheduleRetry) == "function" then
    self:ScheduleRetry(self.pendingReason)
  end
  return false, LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED
end

local function SetCarrierInteraction(container)
  if type(container) ~= "table" and type(container) ~= "userdata" then
    return
  end
  if LockedDown() then
    return
  end
  if type(container.EnableMouse) == "function" then
    pcall(container.EnableMouse, container, false)
  end
  if type(container.SetMouseClickEnabled) == "function" then
    pcall(container.SetMouseClickEnabled, container, false)
  end
  if type(container.SetMouseMotionEnabled) == "function" then
    pcall(container.SetMouseMotionEnabled, container, false)
  end
end

local function SetCarrierEnabled(record, enabled)
  local container = record and record.container
  if container and type(container.SetEnabled) == "function" then
    local ok = pcall(container.SetEnabled, container, enabled == true)
    if ok then
      record.enabled = enabled == true
    end
    return ok
  end
  if record then
    record.enabled = enabled == true
  end
  return true
end

local function SetCarrierShown(record, shown)
  local container = record and record.container
  if not container then
    return true
  end
  if shown and type(container.Show) == "function" then
    local ok = pcall(container.Show, container)
    if ok then
      record.shown = true
    end
    return ok
  elseif not shown and type(container.Hide) == "function" then
    local ok = pcall(container.Hide, container)
    if ok then
      record.shown = false
    end
    return ok
  end
  record.shown = shown == true
  return true
end

function Engine:ScheduleRetry(reason)
  self:MarkDirty(type(reason) == "string" and reason or "NATIVE_RETRY")
  if self.retryScheduled or self.retryAttempts >= MAX_RETRY_ATTEMPTS then
    if self.retryAttempts >= MAX_RETRY_ATTEMPTS then
      self.retryExhausted = true
      if ns.DiagnosticRecord then
        ns.DiagnosticRecord("ENGINE_RETRY", {
          reason = self.pendingReason,
          generation = self.desiredGeneration,
          attempt = self.retryAttempts,
          result = "EXHAUSTED",
        }, false)
      end
    end
    return false
  end
  local timerAPI = C_Timer
  if type(timerAPI) ~= "table" or type(timerAPI.After) ~= "function" then
    return false
  end
  self.retryAttempts = self.retryAttempts + 1
  self.retryGeneration = self.desiredGeneration
  self.retryScheduled = true
  self.retryToken = self.retryToken + 1
  local token = self.retryToken
  local generation = self.retryGeneration
  timerAPI.After(RETRY_DELAYS[self.retryAttempts] or RETRY_DELAYS[#RETRY_DELAYS], function()
    if token ~= self.retryToken or generation ~= self.retryGeneration or generation ~= self.desiredGeneration then
      return
    end
    self.retryScheduled = false
    if ns.RefreshAddonRestrictionState then
      pcall(ns.RefreshAddonRestrictionState, "ENGINE_RETRY")
    end
    if MutationBlocked() then
      self:ScheduleRetry(self.pendingReason)
      return
    end
    if ResumeCoreWorldRecovery("ENGINE_RETRY") then
      return
    end
    local addon = ns.addon
    if addon and type(addon.RetryPendingEnvironment) == "function" then
      local ok, handled, applied = pcall(addon.RetryPendingEnvironment, addon, "engine-retry")
      if not ok or handled == true then
        if not ok then self:RecordFailure("PENDING_ENVIRONMENT_RETRY_FAILED", false) end
        if not ok or applied ~= true then
          self:ScheduleRetry("PENDING_ENVIRONMENT_RETRY")
        end
        return
      end
    end
    self:Reconcile("NATIVE_RETRY", false, true)
  end)
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_RETRY", {
      reason = self.pendingReason,
      generation = generation,
      attempt = self.retryAttempts,
      result = "SCHEDULED",
    }, false)
  end
  return true
end

local function FailureScopeMatches(record, scope)
  if not scope then
    return true
  end
  if scope.record then
    return record == scope.record
  end
  if scope.consumer then
    return record.consumer == scope.consumer
  end
  return false
end

function Engine:FailClosed(reason, scope)
  self.transactionFailed = true
  if scope and scope.record then
    self.scopedFailureConsumers[scope.record.consumer] = true
  end
  self.failClosed = true
  self.deferredStatus = nil
  local affected = 0
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if FailureScopeMatches(record, scope) then
      SetCarrierEnabled(record, false)
      SetCarrierShown(record, false)
      local desiredUnit = PublicUnitToken(record.desiredUnit)
      if desiredUnit == nil then
        record.active = false
      end
      record.pendingUnit = record.active and desiredUnit or nil
      record.pendingAssignment = record.pendingUnit ~= nil
      record.configuredGeneration = 0
      record.quarantined = true
      affected = affected + 1
    end
  end
  if scope then
    self.isolatedFailureCount = self.isolatedFailureCount + 1
  end
  self:SetState(STATES.RECOVERING, "fail closed")
  self:ScheduleRetry(reason or "NATIVE_FAIL_CLOSED")
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_FAIL_CLOSED", {
      reason = reason or "NATIVE_FAIL_CLOSED",
      generation = self.desiredGeneration,
      carriers = affected,
      scope = scope and (scope.consumer or scope.record and "OWNER" or "UNKNOWN") or "GLOBAL",
      result = "DISABLED_RETAINING_LAST_VALID_BINDING",
    }, false)
  end
  return false
end

-- Only serialize our public configuration, never aura data. Unknown values
-- deliberately disable reuse so future filter extensions remain conservative.
local function ConfigurationKey(value, depth)
  if issecretvalue and issecretvalue(value) then return nil end
  local kind = type(value)
  if kind == "nil" then return "nil" end
  if kind == "string" then return string.format("%q", value) end
  if kind == "number" or kind == "boolean" then return kind .. tostring(value) end
  if kind ~= "table" or depth > 6 then return nil end
  local parts = {}
  for key, item in pairs(value) do
    if #parts >= 64 then return nil end
    local left = ConfigurationKey(key, depth + 1)
    local right = ConfigurationKey(item, depth + 1)
    if not left or not right then return nil end
    parts[#parts + 1] = left .. "=" .. right
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ";") .. "}"
end

function Engine:ConfigureCarrier(record, pack, allowReuse)
  if not record or not record.container then
    return false
  end
  if record.active ~= true or PublicUnitToken(record.unit) == nil then
    return true
  end
  if MutationBlocked() then
    return self:Defer("CONFIGURE_COMBAT")
  end
  local getSlots = ns.GetDetectionSlots
  if type(getSlots) ~= "function" then
    self:RecordFailure("SLOTS_UNAVAILABLE", true)
    return false
  end
  local ok, slots = pcall(getSlots, pack, record.unit)
  if not ok or type(slots) ~= "table" then
    self:RecordFailure("SLOTS_FAILED", true)
    return false
  end
  local providerPlan = {}
  for i = 1, #slots do
    local slot = slots[i]
    if type(slot) == "table" then
      providerPlan[i] = {key = slot.key, filter = slot.filter, candidateFilters = slot.candidateFilters}
    else
      providerPlan[i] = slot
    end
  end
  local signature = ConfigurationKey(providerPlan, 0)
  local reuse = allowReuse == true and signature ~= nil
    and record.providerSignature == signature and record.providerUnit == record.unit
    and record.quarantined ~= true and record.configuredGeneration ~= nil
    and record.configuredGeneration > 0
  record.providerReused = reuse
  if not reuse then record.providerSignature = nil end
  if allowReuse ~= nil and not reuse and not SetCarrierEnabled(record, false) then
    self:RecordFailure("CARRIER_DISABLE_FAILED", false)
    return false
  end
  record.slotFrames = record.slotFrames or {}
  record.slotKeys = record.slotKeys or {}
  local wanted = {}
  local configured = true
  local configureStatus = STATUS.SUCCESS
  local function InitializePresentation(frame, key, slot)
    if type(record.initialize) ~= "function" then return end
    local ok, result, resultStatus = pcall(record.initialize, frame, key, slot, pack)
    local status = CallbackStatus(ok, result, resultStatus, true)
    if status ~= STATUS.SUCCESS then
      configured = false
      configureStatus = StrongerStatus(configureStatus, status)
      if status == STATUS.FAILURE then self:RecordFailure("CONSUMER_PAINT_FAILED", false) end
    end
  end
  for i = 1, #slots do
    local slot = slots[i]
    local key = type(slot) == "table" and slot.key or nil
    local filter = type(slot) == "table" and slot.filter or nil
    if type(key) ~= "string" or key == "" or type(filter) ~= "string" or filter == "" then
      self:RecordFailure("SLOT_MALFORMED", false)
      configured = false
      configureStatus = STATUS.FAILURE
    else
      wanted[key] = true
      local function Initialize(frame)
        record.slotFrames[key] = frame
        SetCarrierInteraction(frame)
        InitializePresentation(frame, key, slot)
      end
      if record.slotKeys[key] then
        local setFilter = record.container.SetAuraSlotFilterString
        local setCandidates = record.container.SetAuraSlotCandidateFilters
        if reuse then
          -- Presentation still runs below: palette/layout edits are independent.
        elseif type(setFilter) == "function" then
          local filterOk = pcall(setFilter, record.container, key, filter)
          if not filterOk then
            self:RecordFailure("FILTER_REFRESH_FAILED", false)
            configured = false
            configureStatus = STATUS.FAILURE
          end
        else
          self:RecordFailure("FILTER_REFRESH_UNAVAILABLE", false)
          configured = false
          configureStatus = STATUS.FAILURE
        end
        if reuse then
          self.providerReuseCount = self.providerReuseCount + 1
        elseif type(setCandidates) == "function" then
          local candidateOk = pcall(setCandidates, record.container, key, slot.candidateFilters)
          if not candidateOk then
            self:RecordFailure("PROVIDER_REFRESH_FAILED", false)
            configured = false
            configureStatus = STATUS.FAILURE
          else
            self.providerRefreshGeneration = self.providerRefreshGeneration + 1
          end
        else
          self:RecordFailure("PROVIDER_REFRESH_UNAVAILABLE", false)
          configured = false
          configureStatus = STATUS.FAILURE
        end
        local frame = record.slotFrames[key]
        if frame then InitializePresentation(frame, key, slot) end
      elseif type(record.container.AddAuraSlot) == "function" then
        local addOk, added = pcall(record.container.AddAuraSlot, record.container, key, filter, {
          initializeFrame = Initialize,
          candidateFilters = slot.candidateFilters,
        })
        if addOk and added ~= false then
          record.slotKeys[key] = true
          self.slotCreationGeneration = self.slotCreationGeneration + 1
          self.providerRefreshGeneration = self.providerRefreshGeneration + 1
        else
          self:RecordFailure("SLOT_CREATE_FAILED", true)
          return false
        end
      else
        self:RecordFailure("NATIVE_SLOT_API_UNAVAILABLE", true)
        return false
      end
      if ns.DiagnosticRecord then
        ns.DiagnosticRecord("NATIVE_PROVIDER", {
          carrier = record.diagnosticID or 0,
          consumer = record.consumer,
          slot = key,
          slotType = slot.dispelType or "NONE",
          priority = slot.priority or 0,
          mode = slot.mode or "NONE",
          action = record.slotKeys[key] and "CONFIGURED" or "FAILED",
        }, true)
      end
    end
  end
  if not reuse and type(record.container.SetAuraSlotCandidateFilters) == "function" then
    for key in pairs(record.slotKeys) do
      if not wanted[key] then
        local clearOk = pcall(record.container.SetAuraSlotCandidateFilters, record.container, key, {includeDispelTypes = {}})
        if not clearOk then
          self:RecordFailure("STALE_SLOT_CLEAR_FAILED", false)
          configured = false
          configureStatus = STATUS.FAILURE
        end
      end
    end
  end
  if not configured then
    record.providerSignature = nil
    return false, configureStatus ~= STATUS.SUCCESS and configureStatus or STATUS.FAILURE
  end
  record.providerSignature = signature
  record.providerUnit = record.unit
  record.configuredGeneration = self.configurationGeneration
  record.configuredPackGeneration = self.desiredGeneration
  self.slotProviderRefreshGeneration = self.slotProviderRefreshGeneration + 1
  return true
end

function Engine:CreateCarrier(consumer, parent, initialize, owner)
  if owner and self.carrierByOwner[owner] then
    local record = self.carrierByOwner[owner]
    record.initialize = initialize or record.initialize
    return record.container, record
  end
  if MutationBlocked() then
    self:Defer("CREATE_COMBAT")
    return nil
  end
  if type(CreateFrame) ~= "function" or not parent then
    self:RecordFailure("NATIVE_CONTAINER_API_UNAVAILABLE", true)
    return nil
  end
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  if not ok or not container or type(container.SetUnit) ~= "function" or type(container.AddAuraSlot) ~= "function" then
    self:RecordFailure("NATIVE_CONTAINER_CREATE_FAILED", true)
    return nil
  end
  if type(container.SetAllPoints) == "function" then
    pcall(container.SetAllPoints, container, parent)
  end
  SetCarrierInteraction(container)
  local record = {
    consumer = type(consumer) == "string" and consumer or "Unknown",
    owner = owner,
    parent = parent,
    container = container,
    initialize = initialize,
    unit = nil,
    pendingUnit = nil,
    pendingAssignment = false,
    desiredUnit = nil,
    active = false,
    enabled = false,
    shown = false,
    slotKeys = {},
    slotFrames = {},
    configuredGeneration = 0,
    diagnosticID = self.carrierGeneration + 1,
  }
  self.carriers[#self.carriers + 1] = record
  self.carrierByContainer[container] = record
  if owner then
    self.carrierByOwner[owner] = record
  end
  self.carrierGeneration = self.carrierGeneration + 1
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("CARRIER", {carrier = record.diagnosticID, consumer = record.consumer, action = "CREATED"}, true)
  end
  return container, record
end

function Engine:AssignCarrier(owner, unit)
  local record = owner and self.carrierByOwner[owner]
  if not record then
    return false, "CARRIER_UNAVAILABLE"
  end
  unit = PublicUnitToken(unit)
  if unit == nil then
    return false, "UNIT_INVALID"
  end
  record.desiredUnit = unit
  if MutationBlocked() then
    if record.active == true and record.unit == unit then
      return true
    end
    local newlyDeferred = record.pendingAssignment ~= true or record.pendingUnit ~= unit
    record.pendingUnit = unit
    record.pendingAssignment = true
    if newlyDeferred and LockedDown() then
      self.assignmentDeferredCombatCount = self.assignmentDeferredCombatCount + 1
      if ns.DiagnosticRecord then
        ns.DiagnosticRecord("ASSIGNMENT_DEFERRED_COMBAT", {
          carrier = record.diagnosticID or 0,
          generation = self.desiredGeneration,
          unit = UnitCategory(unit),
        }, false)
      end
    end
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("CARRIER_ASSIGN", {
        carrier = record.diagnosticID or 0,
        previous = UnitCategory(record.unit),
        current = UnitCategory(unit),
        result = "DEFERRED",
      }, false)
    end
    return self:Defer(LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED)
  end
  if record.active == true and record.unit == unit and not record.pendingAssignment then
    if self.preparingConsumers then
      return true
    end
    if unit ~= nil and record.configuredGeneration ~= self.configurationGeneration then
      local configured, status = self:ConfigureCarrier(record, CurrentPack())
      if not configured then
        if status == STATUS.DEFERRED_COMBAT or status == STATUS.DEFERRED_RESTRICTED then
          self:Defer(status)
          return false, status
        end
        self:RecordFailure("CARRIER_CONFIGURE_FAILED", false)
        return self:FailClosed("CARRIER_CONFIGURE_FAILED", {record = record}), "CARRIER_CONFIGURE_FAILED"
      end
    end
    return true
  end
  local container = record.container
  local previousUnit = record.unit
  if not SetCarrierEnabled(record, false) then
    self:RecordFailure("CARRIER_DISABLE_FAILED", false)
    return self:FailClosed("CARRIER_DISABLE_FAILED", {record = record}), "CARRIER_DISABLE_FAILED"
  end
  local wasDeferred = record.pendingAssignment == true
  -- Even a return to the same token is a native binding lifecycle transition.
  record.providerSignature = nil
  local ok, assignReason = ns.SafeNativeSetUnit(container, unit)
  if not ok and (assignReason == "DEFERRED_COMBAT" or assignReason == "DEFERRED_RESTRICTION") then
    record.pendingUnit = unit
    record.pendingAssignment = true
    if assignReason == "DEFERRED_COMBAT" then
      self.assignmentDeferredCombatCount = self.assignmentDeferredCombatCount + 1
    end
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord(assignReason == "DEFERRED_COMBAT" and "ASSIGNMENT_DEFERRED_COMBAT" or "ASSIGNMENT_DEFERRED_RESTRICTION", {
        carrier = record.diagnosticID or 0,
        generation = self.desiredGeneration,
        unit = UnitCategory(unit),
      }, false)
    end
    local status = assignReason == "DEFERRED_COMBAT" and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED
    self:Defer(status)
    return false, status
  end
  if not ok then
    self:RecordFailure("UNIT_ASSIGN_FAILED", false)
    return self:FailClosed("UNIT_ASSIGN_FAILED", {record = record}), "UNIT_ASSIGN_FAILED"
  end
  record.unit = unit
  record.active = true
  record.pendingUnit = nil
  record.pendingAssignment = false
  record.quarantined = false
  self.assignmentGeneration = self.assignmentGeneration + 1
  if wasDeferred then
    self.assignmentReplayedOOCCount = self.assignmentReplayedOOCCount + 1
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("ASSIGNMENT_REPLAYED_OOC", {
        carrier = record.diagnosticID or 0,
        generation = self.desiredGeneration,
        unit = UnitCategory(unit),
      }, false)
    end
  end
  if self.preparingConsumers or self.started ~= true then
    return true
  end
  if record.configuredGeneration ~= self.configurationGeneration then
    local configured, status = self:ConfigureCarrier(record, CurrentPack())
    if not configured then
      if status == STATUS.DEFERRED_COMBAT or status == STATUS.DEFERRED_RESTRICTED then
        self:Defer(status)
        return false, status
      end
      self:RecordFailure("CARRIER_CONFIGURE_FAILED", false)
      return self:FailClosed("CARRIER_CONFIGURE_FAILED", {record = record}), "CARRIER_CONFIGURE_FAILED"
    end
  end
  if not SetCarrierEnabled(record, true) or not SetCarrierShown(record, true) then
    self:RecordFailure("CARRIER_ENABLE_FAILED", false)
    return self:FailClosed("CARRIER_ENABLE_FAILED", {record = record}), "CARRIER_ENABLE_FAILED"
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("CARRIER_ASSIGN", {
      carrier = record.diagnosticID or 0,
      previous = UnitCategory(previousUnit),
      current = UnitCategory(unit),
      result = "ASSIGNED",
    }, false)
  end
  return true
end

function Engine:BindCarrier(consumer, parent, unit, initialize, owner)
  owner = owner or parent
  local record = owner and self.carrierByOwner[owner]
  local container
  if not record then
    container, record = self:CreateCarrier(consumer, parent, initialize, owner)
    if not record then
      return nil
    end
  else
    record.initialize = initialize or record.initialize
    container = record.container
  end
  local assigned, reason = self:AssignCarrier(owner, unit)
  if not assigned then
    return container, false, reason
  end
  return container, true, STATUS.SUCCESS
end

function Engine:UnassignCarrier(owner)
  local record = owner and self.carrierByOwner[owner]
  if not record then
    return false, "CARRIER_UNAVAILABLE"
  end
  record.desiredUnit = nil
  if record.active ~= true and record.pendingAssignment ~= true then
    return true, STATUS.SUCCESS
  end
  if MutationBlocked() then
    local newlyDeferred = record.pendingAssignment ~= true or record.pendingUnit ~= nil
    record.pendingUnit = nil
    record.pendingAssignment = true
    if newlyDeferred and LockedDown() then
      self.assignmentDeferredCombatCount = self.assignmentDeferredCombatCount + 1
      if ns.DiagnosticRecord then
        ns.DiagnosticRecord("ASSIGNMENT_DEFERRED_COMBAT", {
          carrier = record.diagnosticID or 0,
          generation = self.desiredGeneration,
          unit = "other",
        }, false)
      end
    end
    local status = LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED
    self:Defer(status)
    return false, status
  end
  local disabled = SetCarrierEnabled(record, false)
  local hidden = SetCarrierShown(record, false)
  if not disabled or not hidden then
    self:RecordFailure("CARRIER_DEACTIVATE_FAILED", false)
    return self:FailClosed("CARRIER_DEACTIVATE_FAILED", {record = record}), "CARRIER_DEACTIVATE_FAILED"
  end
  record.active = false
  record.pendingUnit = nil
  record.pendingAssignment = false
  record.configuredGeneration = 0
  self.assignmentGeneration = self.assignmentGeneration + 1
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("CARRIER_ASSIGN", {
      carrier = record.diagnosticID or 0,
      previous = UnitCategory(record.unit),
      current = "other",
      result = "LOGICALLY_UNASSIGNED",
    }, false)
  end
  return true, STATUS.SUCCESS
end

function Engine:RegisterConsumer(name, refresh)
  if type(name) ~= "string" or name == "" or type(refresh) ~= "function" then
    return false
  end
  if not self.consumers[name] then
    self.consumerOrder[#self.consumerOrder + 1] = name
  end
  self.consumers[name] = self.consumers[name] or {refreshes = 0, failures = 0}
  self.consumers[name].refresh = refresh
  self.consumers[name].registered = true
  if self.startRequested and self.started ~= true and self:RequiredConsumersRegistered() then
    self:ScheduleRetry("REQUIRED_CONSUMERS_REGISTERED")
  end
  return true
end

function Engine:RequiredConsumersRegistered()
  local count = 0
  for i = 1, #REQUIRED_CONSUMERS do
    local consumer = self.consumers[REQUIRED_CONSUMERS[i]]
    if not consumer or consumer.registered ~= true or type(consumer.refresh) ~= "function" then
      self.registeredRequiredConsumerCount = count
      return false, REQUIRED_CONSUMERS[i]
    end
    count = count + 1
  end
  self.registeredRequiredConsumerCount = count
  return true
end

local function RefreshConsumerBanks(self, reason)
  local refreshed = true
  local status = STATUS.SUCCESS
  local failedConsumer
  local outcomes = {}
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    local consumer = self.consumers[name]
    if consumer and type(consumer.refresh) == "function" then
      consumer.expectedCount = nil
      local ok, result, resultStatus, expectedCount = pcall(consumer.refresh, reason)
      if type(expectedCount) == "number" and expectedCount >= 0 then
        consumer.expectedCount = math.floor(expectedCount)
      end
      local outcome = CallbackStatus(ok, result, resultStatus, false)
      if outcome == STATUS.SUCCESS and MutationBlocked() then outcome = STATUS.DEFERRED_COMBAT end
      outcomes[name] = outcome
      consumer.status = outcome
      consumer.deferred = outcome == STATUS.DEFERRED_COMBAT or outcome == STATUS.DEFERRED_RESTRICTED
      consumer.available = outcome == STATUS.SUCCESS
      if consumer.available then
        consumer.refreshes = consumer.refreshes + 1
      else
        consumer.failures = consumer.failures + 1
        if outcome == STATUS.FAILURE then self:RecordFailure("CONSUMER_REFRESH_FAILED", false) end
        status = StrongerStatus(status, outcome)
        refreshed = false
        failedConsumer = failedConsumer or name
      end
    end
  end
  return refreshed, status, failedConsumer, outcomes
end

function Engine:RefreshConsumers(reason)
  local token
  local begin = ns.BeginRosterTransaction
  local finish = ns.EndRosterTransaction
  local ready = type(begin) ~= "function" or type(finish) == "function"
  if ready and type(begin) == "function" then
    local ok, result = pcall(begin, CurrentPack())
    ready = ok and result ~= nil
    if ready then token = result end
  end
  local ok, refreshed, status, failedConsumer, outcomes
  if ready then
    ok, refreshed, status, failedConsumer, outcomes = pcall(RefreshConsumerBanks, self, reason)
  end
  if token then
    local ended, result = pcall(finish, token)
    ready = ready and ended and result == true
  end
  if not ready or not ok then
    self:RecordFailure("ROSTER_CONSUMER_TRANSACTION_FAILED", false)
    outcomes = {}
    for i = 1, #self.consumerOrder do
      local name = self.consumerOrder[i]
      outcomes[name] = STATUS.FAILURE
      local consumer = self.consumers[name]
      if consumer then
        consumer.status = STATUS.FAILURE
        consumer.available = false
        consumer.deferred = false
      end
    end
    return false, STATUS.FAILURE, nil, outcomes
  end
  return refreshed, status, failedConsumer, outcomes
end

function Engine:ValidateExpectedBanks(requireShown, outcomes)
  local requiredReady = self:RequiredConsumersRegistered()
  if not requiredReady then
    return false, 0
  end
  local expectedTotal = 0
  local invalidBanks = {}
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    local consumer = self.consumers[name]
    local expected = consumer and consumer.expectedCount
    if outcomes and outcomes[name] ~= STATUS.SUCCESS then
      -- An unavailable bank cannot veto completion of an independent bank.
    elseif type(expected) == "number" then
      expectedTotal = expectedTotal + expected
      local desired = 0
      local active = 0
      local configured = 0
      local shown = 0
      for c = 1, #self.carriers do
        local record = self.carriers[c]
        if record.consumer == name then
          if PublicUnitToken(record.desiredUnit) ~= nil then
            desired = desired + 1
          end
          if record.active == true and PublicUnitToken(record.unit) ~= nil then
            active = active + 1
            if record.configuredGeneration == self.configurationGeneration then
              configured = configured + 1
            end
            if record.shown == true then
              shown = shown + 1
            end
          end
        end
      end
      if desired ~= expected or active ~= expected or configured ~= expected or requireShown and shown ~= expected then
        invalidBanks[#invalidBanks + 1] = name
      end
    elseif REQUIRED_CONSUMER_SET[name] and consumer and consumer.registered == true then
      invalidBanks[#invalidBanks + 1] = name
    end
  end
  return #invalidBanks == 0, expectedTotal, invalidBanks
end

function Engine:GetCarrierTransactionCounts()
  local desired = 0
  local active = 0
  local configured = 0
  local shown = 0
  local pending = 0
  local valid = true
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    local desiredUnit = PublicUnitToken(record.desiredUnit)
    if desiredUnit ~= nil then
      desired = desired + 1
    end
    if record.pendingAssignment == true then
      pending = pending + 1
    end
    if record.active == true and PublicUnitToken(record.unit) ~= nil then
      active = active + 1
      if record.configuredGeneration == self.configurationGeneration then
        configured = configured + 1
      end
      if record.shown == true then
        shown = shown + 1
      end
    end
    if desiredUnit ~= nil then
      if record.active ~= true or record.unit ~= desiredUnit or record.pendingAssignment == true then
        valid = false
      end
    elseif record.active == true or record.pendingAssignment == true then
      valid = false
    end
  end
  return desired, active, configured, shown, pending, valid
end

function Engine:Configure(reason, allowReuse, outcomes)
  if MutationBlocked() then
    return self:Defer(reason or "CONFIGURE_COMBAT")
  end
  local pack = CurrentPack()
  if type(pack) ~= "table" then
    self:RecordFailure("PACK_UNAVAILABLE", true)
    return false, STATUS.FAILURE
  end
  self:SetState(STATES.CONFIGURING, "configuring")
  self.configurationGeneration = self.configurationGeneration + 1
  local status = self.transactionFailed and STATUS.FAILURE or STATUS.SUCCESS
  for _, outcome in pairs(outcomes or {}) do status = StrongerStatus(status, outcome) end
  local failedBanks = {}
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if not outcomes or outcomes[record.consumer] == nil or outcomes[record.consumer] == STATUS.SUCCESS then
      local ok, recordStatus = true, STATUS.SUCCESS
      if MutationBlocked() then
        ok, recordStatus = false, STATUS.DEFERRED_COMBAT
      elseif record.active ~= true and not SetCarrierEnabled(record, false) then
        ok, recordStatus = false, STATUS.FAILURE
        self:RecordFailure("CARRIER_DISABLE_FAILED", false)
      else
        ok, recordStatus = self:ConfigureCarrier(record, pack, allowReuse == true)
        recordStatus = ok and STATUS.SUCCESS or recordStatus or STATUS.FAILURE
      end
      if ok and record.active == true and PublicUnitToken(record.unit) ~= nil then
        if (not record.providerReused or record.enabled ~= true or record.shown ~= true)
          and (not SetCarrierEnabled(record, true) or not SetCarrierShown(record, true)) then
          ok, recordStatus = false, STATUS.FAILURE
          self:RecordFailure("CARRIER_ENABLE_FAILED", false)
        else
          record.quarantined = false
        end
      end
      if not ok then
        status = StrongerStatus(status, recordStatus)
        failedBanks[record.consumer] = StrongerStatus(failedBanks[record.consumer] or STATUS.SUCCESS, recordStatus)
        if recordStatus == STATUS.FAILURE then
          self:FailClosed("TRANSACTION_CONFIGURE_FAILED", {record = record})
        else
          self:Defer(recordStatus)
        end
      end
    end
  end
  -- Validate only the banks which completed this pass. A sound deferral must
  -- withhold global success without disabling a newly configured MUF provider.
  local completed = {}
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    completed[name] = failedBanks[name] or outcomes and outcomes[name] or STATUS.SUCCESS
  end
  local banksVisible, expectedAfter, invalidBanks = self:ValidateExpectedBanks(true, completed)
  if not banksVisible then
    status = STATUS.FAILURE
    self:RecordFailure("CARRIER_TRANSACTION_INCOMPLETE", false)
    for i = 1, #(invalidBanks or {}) do
      local name = invalidBanks[i]
      failedBanks[name] = STATUS.FAILURE
      self:FailClosed("CARRIER_TRANSACTION_INCOMPLETE", {consumer = name})
    end
  end
  for name, outcome in pairs(failedBanks) do
    local consumer = self.consumers[name]
    if consumer then
      consumer.status = outcome
      consumer.available = false
      consumer.deferred = outcome == STATUS.DEFERRED_COMBAT or outcome == STATUS.DEFERRED_RESTRICTED
    end
  end
  if status ~= STATUS.SUCCESS then
    self:ScheduleRetry("TRANSACTION_INCOMPLETE")
    self:SetState(LockedDown() and STATES.COMBAT_DEFERRED or STATES.RECOVERING, "transaction incomplete")
    return false, status
  end
  local desiredAfter, activeAfter, configuredAfter, shownAfter, pendingAfter, transactionValidAfter = self:GetCarrierTransactionCounts()
  if not transactionValidAfter or pendingAfter ~= 0 or desiredAfter ~= activeAfter or activeAfter ~= configuredAfter or configuredAfter ~= shownAfter then
    self:RecordFailure("CARRIER_TRANSACTION_NOT_VISIBLE", false)
    return self:FailClosed("CARRIER_TRANSACTION_NOT_VISIBLE"), STATUS.FAILURE
  end
  self.failClosed = false
  self.configuredPackGeneration = self.desiredGeneration
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_CONFIGURE", {
      result = "CONFIGURED",
      desiredGeneration = self.desiredGeneration,
      configuredGeneration = self.configuredPackGeneration,
      carriers = #self.carriers,
      desired = desiredAfter,
      active = activeAfter,
      configured = configuredAfter,
      shown = shownAfter,
      expected = expectedAfter,
    }, false)
  end
  self:SetState(STATES.READY, "ready")
  return true, STATUS.SUCCESS
end

function Engine:ConsumeCapabilityRefresh()
  if not self.capabilityRefreshPending then return false end
  -- Consume before invoking callbacks: re-entrant events belong to the next
  -- batch and must not be cleared when this transaction completes.
  self.capabilityRefreshPending = false
  self.capabilityRefreshScheduled = false
  self.capabilityRefreshToken = self.capabilityRefreshToken + 1
  self.capabilityRefreshReasons = {}
  if ns.InvalidateDetection then ns.InvalidateDetection() end
  if ns.ScheduleFollowerRosterGuard then ns.ScheduleFollowerRosterGuard() end
  return true
end

function Engine:QueueCapabilityRefresh(reason)
  self.capabilityRefreshPending = true
  self.capabilityRefreshReasons[reason or "CAPABILITY_CHANGED"] = true
  if MutationBlocked() then return self:Defer("CAPABILITY_CHANGED") end
  if self.capabilityRefreshScheduled then return true end
  if not C_Timer or type(C_Timer.After) ~= "function" then
    if self.reconciling then
      self:MarkDirty("CAPABILITY_CHANGED")
      return false
    end
    return self:Refresh("CAPABILITY_CHANGED")
  end
  self.capabilityRefreshScheduled = true
  self.capabilityRefreshToken = self.capabilityRefreshToken + 1
  local token = self.capabilityRefreshToken
  C_Timer.After(0, function()
    if token ~= Engine.capabilityRefreshToken then return end
    Engine.capabilityRefreshScheduled = false
    if Engine.capabilityRefreshPending then Engine:Refresh("CAPABILITY_CHANGED") end
  end)
  return true
end

function Engine:Reconcile(reason, fromRegen, isRetry)
  if self.reconciling then
    return false
  end
  if MutationBlocked() then
    return self:Defer(reason or "REFRESH_COMBAT")
  end
  self.reconciling = true
  -- Immediate profile/world/recovery transactions cover queued capability
  -- work using their current applied pack and invalidate its old timer token.
  local invalidated = pcall(self.ConsumeCapabilityRefresh, self)
  if not invalidated then
    self.reconciling = false
    self.capabilityRefreshPending = true
    self:RecordFailure("CAPABILITY_INVALIDATION_FAILED", false)
    self:ScheduleRetry("CAPABILITY_INVALIDATION_FAILED")
    self:SetState(STATES.RECOVERING, "capability invalidation failed")
    return false, STATUS.FAILURE
  end
  if MutationBlocked() then
    self.reconciling = false
    return self:Defer(reason or "REFRESH_COMBAT")
  end
  local allowReuse = self.state == STATES.READY and not fromRegen and not isRetry
    and not self.failClosed and not self.pending
    and not (type(reason) == "string" and (reason:find("WORLD", 1, true) or reason:find("RECOVER", 1, true)))
  if not isRetry then
    self:MarkDirty(reason or "REFRESH")
    self.desiredGeneration = self.desiredGeneration + 1
    self.retryGeneration = self.desiredGeneration
    self.retryAttempts = 0
    self.retryScheduled = false
    self.retryToken = self.retryToken + 1
    self.retryExhausted = false
  end
  self.transactionFailed = false
  self.scopedFailureConsumers = {}
  self.deferredStatus = nil
  self:SetState(STATES.RECOVERING, "recovering")
  self.preparingConsumers = true
  local requiredReady, missingConsumer = self:RequiredConsumersRegistered()
  if not requiredReady then
    self.reconciling = false
    self.preparingConsumers = false
    self.started = false
    self:RecordFailure("REQUIRED_CONSUMER_MISSING_" .. tostring(missingConsumer), false)
    self:SetState(STATES.RECOVERING, "required consumer missing")
    self:ScheduleRetry("REQUIRED_CONSUMERS_MISSING")
    return false, STATUS.FAILURE
  end
  self.started = true
  local consumersReady, consumerStatus, failedConsumer, outcomes = self:RefreshConsumers(reason)
  self.preparingConsumers = false
  if not consumersReady then
    -- Every failed bank gets its own isolation. A lower-level owner failure
    -- already identified its scope, so retain that consumer's healthy owners.
    for name, outcome in pairs(outcomes) do
      if outcome == STATUS.FAILURE then
        if not self.scopedFailureConsumers[name] and not MutationBlocked() then
          self:FailClosed("CONSUMER_TRANSACTION_FAILED", {consumer = name})
        end
      elseif outcome ~= STATUS.SUCCESS then
        self:MarkDirty(outcome)
        self.deferredStatus = StrongerStatus(self.deferredStatus or STATUS.SUCCESS, outcome)
      end
    end
    if consumerStatus == STATUS.FAILURE then self:RecordFailure("CONSUMER_TRANSACTION_FAILED", false) end
  end
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if record.pendingAssignment and (outcomes[record.consumer] == nil or outcomes[record.consumer] == STATUS.SUCCESS) then
      local ok, assignmentStatus
      if record.pendingUnit == nil then
        ok, assignmentStatus = self:UnassignCarrier(record.owner)
      else
        ok, assignmentStatus = self:AssignCarrier(record.owner, record.pendingUnit)
      end
      if not ok then
        local outcome = CallbackStatus(true, false, assignmentStatus, false)
        outcomes[record.consumer] = outcome
        if outcome == STATUS.FAILURE then self.transactionFailed = true end
        local consumer = self.consumers[record.consumer]
        if consumer then
          consumer.status = outcome
          consumer.available = false
          consumer.deferred = outcome == STATUS.DEFERRED_COMBAT or outcome == STATUS.DEFERRED_RESTRICTED
        end
      end
    end
  end
  local configured, configureStatus = self:Configure(reason, allowReuse, outcomes)
  local finalStatus = StrongerStatus(consumerStatus, configureStatus or STATUS.FAILURE)
  for _, consumer in pairs(self.consumers) do
    local outcome = consumer.status
    if outcome == STATUS.DEFERRED_COMBAT or outcome == STATUS.DEFERRED_RESTRICTED then
      self.deferredStatus = StrongerStatus(self.deferredStatus or STATUS.SUCCESS, outcome)
    end
  end
  if configured then
    -- A committed applied pack starts its own trace. Ordinary refreshes and
    -- combat recovery of that same pack must preserve evidence and manual off.
    local appliedPack = CurrentPack()
    local tracePolicy = appliedPack and (not appliedPack.advanced or appliedPack.advanced.autoAuraTrace ~= false)
    if appliedPack and (self.auraTracePack ~= appliedPack or self.auraTracePolicy ~= tracePolicy) then
      if self:SetAuraTrace(tracePolicy) then
        if self.auraTracePack ~= appliedPack and not tracePolicy then
          self.auraTraceTotal, self.auraTraceCombat, self.auraTraceUnits = 0, 0, {}
        end
        self.auraTracePack = appliedPack
        self.auraTracePolicy = tracePolicy
      end
    end
    local oldItemActionSignature = self.itemActionSignature
    self.itemActionSignature = ItemActionSignature()
    if oldItemActionSignature ~= self.itemActionSignature and type(ns.RefreshBandageOptions) == "function" then
      pcall(ns.RefreshBandageOptions)
    end
    if type(ns.RefreshBandageLowStockReminder) == "function" then
      pcall(ns.RefreshBandageLowStockReminder)
    end
    self:ClearDirty()
    self.deferredStatus = nil
    self.retryAttempts = 0
    self.retryScheduled = false
    self.retryToken = self.retryToken + 1
    self.retryExhausted = false
    self.refreshGeneration = self.refreshGeneration + 1
    if fromRegen then
      self.regenReconcileGeneration = self.regenReconcileGeneration + 1
    end
    if self.capabilityRefreshPending then
      self:MarkDirty("CAPABILITY_CHANGED")
      self:SetState(STATES.RECOVERING, "capability change queued")
    else
      self:SetState(STATES.READY, "reconciled")
    end
  else
    -- Retry continuity is independent of whether a previous pass quarantined
    -- a bank: this pass may have invalidated that previous timer generation.
    self:ScheduleRetry("TRANSACTION_INCOMPLETE")
    self:SetState(LockedDown() and STATES.COMBAT_DEFERRED or STATES.RECOVERING, "reconcile incomplete")
  end
  self.reconciling = false
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_RECONCILE", {
      reason = reason or "NONE",
      result = configured and "APPLIED" or finalStatus,
      fromRegen = fromRegen == true,
      carriers = #self.carriers,
      desiredGeneration = self.desiredGeneration,
      configuredGeneration = self.configuredPackGeneration,
      failClosed = self.failClosed == true,
    }, false)
  end
  return configured, configured and STATUS.SUCCESS or finalStatus
end

function Engine:Refresh(reason, isRetry)
  local fromRegen = self.pending and not MutationBlocked()
  return self:Reconcile(reason or "REFRESH", fromRegen, isRetry == true)
end

function Engine:Recover(reason)
  if MutationBlocked() then
    return self:Defer(reason or "REGEN_WAIT")
  end
  if not self.pending and self.state ~= STATES.COMBAT_DEFERRED then
    return false
  end
  return self:Reconcile(reason or "REGEN", true)
end

function Engine:Reset()
  if MutationBlocked() then
    return self:Defer("RESET_COMBAT")
  end
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if type(record.container.SetEnabled) == "function" then
      pcall(record.container.SetEnabled, record.container, false)
    end
    SetCarrierShown(record, false)
    record.active = false
    record.desiredUnit = nil
    record.pendingUnit = nil
    record.pendingAssignment = false
    record.configuredGeneration = 0
  end
  self.pending = false
  self.pendingReason = "NONE"
  self.failClosed = false
  self.transactionFailed = false
  self.retryScheduled = false
  self.retryToken = self.retryToken + 1
  self.retryAttempts = 0
  self.retryExhausted = false
  self.retryGeneration = self.retryGeneration + 1
  self.capabilityRefreshPending = false
  self.capabilityRefreshScheduled = false
  self.capabilityRefreshToken = self.capabilityRefreshToken + 1
  self.capabilityRefreshReasons = {}
  self.started = false
  self.startRequested = false
  self.pendingReasons = {}
  self.dirtyGeneration = 0
  self.committedGeneration = 0
  self.assignmentGeneration = self.assignmentGeneration + 1
  self:SetState(STATES.COLD, "reset")
  return true
end

function Engine:SetAuraTrace(enabled)
  if not self.eventFrame then self:RegisterEvents() end
  if not self.eventFrame then return false end
  enabled = enabled == true
  local method = enabled and self.eventFrame.RegisterEvent or self.eventFrame.UnregisterEvent
  if type(method) ~= "function" or not pcall(method, self.eventFrame, "UNIT_AURA") then
    self.auraTraceRegistrationFailures = self.auraTraceRegistrationFailures + 1
    return false
  end
  if enabled then
    self.auraTraceTotal, self.auraTraceCombat = 0, 0
    self.auraTraceUnits = {}
  end
  self.auraTraceEnabled = enabled
  return true
end

function Engine:OnEvent(event, arg1, arg2)
  if event == "PLAYER_ENTERING_WORLD" and type(ns.MarkBandageInventoryDirty) == "function" then
    ns.MarkBandageInventoryDirty()
  end
  if event == "UNIT_AURA" then
    if not self.auraTraceEnabled then return end
    local unit = PublicUnitToken(arg1)
    -- Bound the key space to canonical friendly roster tokens. Payload ignored.
    if not unit then return end
    local index = unit:match("^party(%d+)$") or unit:match("^partypet(%d+)$")
    local raidIndex = unit:match("^raid(%d+)$") or unit:match("^raidpet(%d+)$")
    if index and index ~= tostring(tonumber(index)) then return end
    if raidIndex and raidIndex ~= tostring(tonumber(raidIndex)) then return end
    if unit ~= "player" and unit ~= "pet"
      and not (index and tonumber(index) >= 1 and tonumber(index) <= 4)
      and not (raidIndex and tonumber(raidIndex) >= 1 and tonumber(raidIndex) <= 40) then return end
    self.auraTraceTotal = self.auraTraceTotal + 1
    if LockedDown() then self.auraTraceCombat = self.auraTraceCombat + 1 end
    self.auraTraceUnits[unit] = (self.auraTraceUnits[unit] or 0) + 1
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    if type(ns.HideBandageLowStockReminder) == "function" then ns.HideBandageLowStockReminder() end
    self.combatEntryGeneration = self.combatEntryGeneration + 1
    self.nativeCombatGeneration = self.nativeCombatGeneration + 1
    self:Defer("COMBAT_ENTERED")
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    self.regenSeenGeneration = self.regenSeenGeneration + 1
    if not ns.addon or type(ns.addon.OnRegenEnabled) ~= "function" then
      self:Recover("REGEN_EVENT")
    end
    return
  end
  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if ns.RememberRestrictionState then
      ns.RememberRestrictionState(arg1, arg2)
    end
    local active = ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction()
    if not active and self.pending == true and self.deferredStatus == STATUS.DEFERRED_RESTRICTED then
      if not ResumeCoreWorldRecovery("RESTRICTION_CLEARED") then
        self:Refresh("RESTRICTION_CLEARED")
      end
    end
    if C_Timer and type(C_Timer.After) == "function" then
      C_Timer.After(0, function()
        if ns.RefreshAddonRestrictionState then
          pcall(ns.RefreshAddonRestrictionState, "RESTRICTION_EVENT_SETTLED")
        end
        if not Restricted() and not LockedDown() and Engine.pending
          and Engine.deferredStatus == STATUS.DEFERRED_RESTRICTED then
          if not ResumeCoreWorldRecovery("RESTRICTION_EVENT_SETTLED") then
            Engine:Refresh("RESTRICTION_EVENT_SETTLED")
          end
        end
      end)
    end
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" or event == "ITEM_COUNT_CHANGED"
    or event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
    if event ~= "BAG_UPDATE_DELAYED" and event ~= "PLAYER_LEVEL_UP" and event ~= "SKILL_LINES_CHANGED" then
      local itemID = PublicNumber(arg1)
      if itemID == nil then return end
      local soulLinkItem = type(ns.IsSoulLinkItemID) == "function" and ns.IsSoulLinkItemID(itemID)
        or itemID == ns.SOUL_LINK_ITEM_ID
      local bandageItem = type(ns.IsBandageInventoryEventItem) == "function" and ns.IsBandageInventoryEventItem(itemID, event)
      if not soulLinkItem and not bandageItem then
        return
      end
    end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
      local bandageDataResult = type(ns.BandageItemDataResult) == "function" and ns.BandageItemDataResult(PublicNumber(arg1))
      if PublicBoolean(arg2) == false and not bandageDataResult then return end
    end
    if type(ns.MarkBandageInventoryDirty) == "function" then ns.MarkBandageInventoryDirty() end
    if self.itemActionRefreshScheduled then
      return
    end
    self.itemActionRefreshScheduled = true
    local function refreshItemActions()
      Engine.itemActionRefreshScheduled = false
      local signature = ItemActionSignature()
      if signature ~= nil and signature == Engine.itemActionSignature then
        return
      end
      if ns.InvalidateDetection then
        ns.InvalidateDetection()
      elseif ns.InvalidateClickModel then
        ns.InvalidateClickModel("ITEM_ACTIONS_CHANGED")
      end
      Engine:Refresh("ITEM_ACTIONS_CHANGED")
    end
    if C_Timer and type(C_Timer.After) == "function" then
      C_Timer.After(0, refreshItemActions)
    else
      refreshItemActions()
    end
    return
  end
  if event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" then
    return self:QueueCapabilityRefresh(event)
  end
  -- Core owns specialization/profile routing and keeps that transition
  -- immediate. It also subsumes any earlier capability event in this burst.
  if event == "PLAYER_SPECIALIZATION_CHANGED" and not self:ConsumeCapabilityRefresh() then
    if ns.InvalidateDetection then ns.InvalidateDetection() end
    if ns.ScheduleFollowerRosterGuard then ns.ScheduleFollowerRosterGuard() end
  end
  if (event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET") and ns.addon and type(ns.addon.OnGroupRosterUpdate) == "function" then
    return
  end
  if event == "PLAYER_SPECIALIZATION_CHANGED" and ns.addon and type(ns.addon.OnSpecChanged) == "function" then
    return
  end
  if event == "PLAYER_ENTERING_WORLD" and ns.addon and type(ns.addon.OnEnteringWorld) == "function" then
    return
  end
  self:Refresh("EVENT_REFRESH")
end

function Engine:RegisterEvents()
  if self.eventsRegistered or type(CreateFrame) ~= "function" then
    return self.eventsRegistered
  end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    Engine:OnEvent(event, arg1, arg2)
  end)
  local events = {
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "UNIT_PET",
    "SPELLS_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_TALENT_UPDATE",
    "ADDON_RESTRICTION_STATE_CHANGED",
    "BAG_UPDATE_DELAYED",
    "PLAYER_LEVEL_UP",
    "SKILL_LINES_CHANGED",
    "ITEM_COUNT_CHANGED",
    "GET_ITEM_INFO_RECEIVED",
    "ITEM_DATA_LOAD_RESULT",
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
  self.eventFrame = frame
  self.eventsRegistered = true
  return true
end

function Engine:Start()
  self:RegisterEvents()
  self.startRequested = true
  if self.state == STATES.READY then
    return true
  end
  local requiredReady, missingConsumer = self:RequiredConsumersRegistered()
  if not requiredReady then
    self.started = false
    self:MarkDirty("REQUIRED_CONSUMER_MISSING_" .. tostring(missingConsumer))
    self:SetState(STATES.RECOVERING, "waiting for consumers")
    self:ScheduleRetry("REQUIRED_CONSUMERS_MISSING")
    return false, STATUS.FAILURE
  end
  self.started = true
  if MutationBlocked() then
    return self:Defer(LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED)
  end
  return self:Reconcile("START", false)
end

function Engine:GetDiagnostics()
  local auraTraceUnits = {}
  for unit, count in pairs(self.auraTraceUnits) do auraTraceUnits[unit] = count end
  local categories = {player = 0, party = 0, raid = 0, pets = 0, other = 0}
  local assigned = 0
  local configured = 0
  local shown = 0
  local alphaPublic = 0
  local alphaZero = 0
  local mouseEnabled = 0
  local pendingAssignments = 0
  local logicallyUnassigned = 0
  local retainedNativeBindings = 0
  local presentationRegisteredSlots = 0
  local presentationVisibilityGatedSlots = 0
  local consumerStates = {}
  local desiredCount, activeCount, configuredTransactionCount, shownTransactionCount = self:GetCarrierTransactionCounts()
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if record.active == true and record.configuredGeneration > 0 then
      configured = configured + 1
    end
    if record.active == true and record.unit then
      assigned = assigned + 1
      local category = UnitCategory(record.unit)
      categories[category] = categories[category] + 1
    end
    if record.pendingAssignment then
      pendingAssignments = pendingAssignments + 1
    end
    if record.active ~= true then
      logicallyUnassigned = logicallyUnassigned + 1
      if PublicUnitToken(record.unit) ~= nil then
        retainedNativeBindings = retainedNativeBindings + 1
      end
    end
    if type(record.slotFrames) == "table" then
      for _, slot in pairs(record.slotFrames) do
        if type(slot) == "table" and slot._decursivePresentationRegistered == true then
          presentationRegisteredSlots = presentationRegisteredSlots + 1
          local host = slot._decursivePresentationHost
          if host and type(host.GetParent) == "function" then
            local ok, parent = pcall(host.GetParent, host)
            if ok and parent == slot then
              presentationVisibilityGatedSlots = presentationVisibilityGatedSlots + 1
            end
          end
        end
      end
    end
    local container = record.container
    if container and type(container.IsShown) == "function" then
      local ok, value = pcall(container.IsShown, container)
      if ok and PublicBoolean(value) == true then
        shown = shown + 1
      end
    end
    if container and type(container.GetAlpha) == "function" then
      local ok, value = pcall(container.GetAlpha, container)
      value = ok and PublicNumber(value) or nil
      if value ~= nil then
        alphaPublic = alphaPublic + 1
        if value == 0 then
          alphaZero = alphaZero + 1
        end
      end
    end
    if container and type(container.IsMouseEnabled) == "function" then
      local ok, value = pcall(container.IsMouseEnabled, container)
      if ok and PublicBoolean(value) == true then
        mouseEnabled = mouseEnabled + 1
      end
    end
  end
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    local consumer = self.consumers[name]
    local desired = 0
    local active = 0
    local configuredForConsumer = 0
    local shownForConsumer = 0
    for c = 1, #self.carriers do
      local record = self.carriers[c]
      if record.consumer == name then
        if PublicUnitToken(record.desiredUnit) ~= nil then
          desired = desired + 1
        end
        if record.active == true and PublicUnitToken(record.unit) ~= nil then
          active = active + 1
          if record.configuredGeneration == self.configurationGeneration then
            configuredForConsumer = configuredForConsumer + 1
          end
          if record.shown == true then
            shownForConsumer = shownForConsumer + 1
          end
        end
      end
    end
    consumerStates[name] = {
      registered = consumer.registered == true,
      available = consumer.available ~= false,
      status = consumer.status or STATUS.SUCCESS,
      deferred = consumer.deferred == true,
      refreshes = consumer.refreshes or 0,
      failures = consumer.failures or 0,
      expectedCount = type(consumer.expectedCount) == "number" and consumer.expectedCount or 0,
      desired = desired,
      active = active,
      configured = configuredForConsumer,
      shown = shownForConsumer,
    }
  end

  for i = 1, #REQUIRED_CONSUMERS do
    local name = REQUIRED_CONSUMERS[i]
    if not consumerStates[name] then
      consumerStates[name] = {
        registered = false,
        available = false,
        refreshes = 0,
        failures = 0,
        expectedCount = 0,
        desired = 0,
        active = 0,
        configured = 0,
        shown = 0,
      }
    end
  end
	return {
		engineVersion = self.version,
		providerType = "NATIVE_AURA_CONTAINER",
		presentationType = "NATIVE_SLOT_CALLBACK",
		appliedPackType = type(CurrentPack()),
    lifecycleState = self.state,
    lifecycleGeneration = self.stateGeneration,
    configurationGeneration = self.configurationGeneration,
    assignmentGeneration = self.assignmentGeneration,
    assignmentDeferredCombatCount = self.assignmentDeferredCombatCount,
    assignmentReplayedOOCCount = self.assignmentReplayedOOCCount,
    refreshGeneration = self.refreshGeneration,
    carrierGeneration = self.carrierGeneration,
    slotCreationGeneration = self.slotCreationGeneration,
    providerRefreshGeneration = self.providerRefreshGeneration,
    providerReuseCount = self.providerReuseCount,
    auraTraceEnabled = self.auraTraceEnabled,
    auraTraceAutomatic = self.auraTracePolicy,
    auraTraceRegistrationFailures = self.auraTraceRegistrationFailures,
    auraTraceTotal = self.auraTraceTotal,
    auraTraceCombat = self.auraTraceCombat,
    auraTraceUnits = auraTraceUnits,
    presentationRegisteredSlotCount = presentationRegisteredSlots,
    presentationVisibilityGatedSlotCount = presentationVisibilityGatedSlots,
    configuredCarrierCount = configured,
    assignedCarrierCount = assigned,
    desiredCarrierCount = desiredCount,
    activeCarrierCount = activeCount,
    transactionConfiguredCarrierCount = configuredTransactionCount,
    transactionShownCarrierCount = shownTransactionCount,
    carrierCategoryCounts = categories,
    carrierShownCount = shown,
    carrierAlphaPublicCount = alphaPublic,
    carrierAlphaZeroCount = alphaZero,
    carrierMouseEnabledCount = mouseEnabled,
    slotProviderRefreshGeneration = self.slotProviderRefreshGeneration,
    combatEntryGeneration = self.combatEntryGeneration,
    nativeCombatGeneration = self.nativeCombatGeneration,
    regenSeenGeneration = self.regenSeenGeneration,
    regenReconcileGeneration = self.regenReconcileGeneration,
    pendingReconcile = self.pending,
    failClosed = self.failClosed,
    desiredGeneration = self.desiredGeneration,
    configuredPackGeneration = self.configuredPackGeneration,
    retryGeneration = self.retryGeneration,
    retryAttempts = self.retryAttempts,
    retryScheduled = self.retryScheduled,
    retryExhausted = self.retryExhausted,
    pendingAssignmentCount = pendingAssignments,
    logicallyUnassignedCarrierCount = logicallyUnassigned,
    retainedNativeBindingCount = retainedNativeBindings,
    pendingReason = self.pendingReason,
    failureCount = self.failureCount,
    lastFailure = self.lastFailure,
    eventsRegistered = self.eventsRegistered,
    started = self.started == true,
    requiredConsumerCount = self.requiredConsumerCount,
    registeredRequiredConsumerCount = self.registeredRequiredConsumerCount,
    isolatedFailureCount = self.isolatedFailureCount,
    dirtyGeneration = self.dirtyGeneration,
    committedGeneration = self.committedGeneration,
    consumerStates = consumerStates,
    consumerMUFs = consumerStates.MUFs or {registered = false, available = false, refreshes = 0, failures = 0},
    consumerLiveList = consumerStates.LiveList or {registered = false, available = false, refreshes = 0, failures = 0},
    consumerAlerts = consumerStates.Alerts or {registered = false, available = false, refreshes = 0, failures = 0},
  }
end

ns.DetectionEngine = Engine
ns.GetDetectionEngine = function()
  return Engine
end

ns.EnableDetection = function()
  return Engine:Start()
end

ns.AttachDetector = function(parent, unit, _pack, initialize)
  return Engine:BindCarrier("Compatibility", parent, unit, initialize, parent)
end

ns.AttachDetectionContainer = function(container, unit, _pack, initialize)
  local record = container and Engine.carrierByContainer[container]
  if not record then
    return false
  end
  record.initialize = initialize or record.initialize
  return Engine:AssignCarrier(record.owner, unit)
end

ns.ApplyDetectionSlots = function(container, _pack, initialize)
  local record = container and Engine.carrierByContainer[container]
  if not record then
    return false
  end
  record.initialize = initialize or record.initialize
  return Engine:ConfigureCarrier(record, CurrentPack())
end

if type(ns.Detection) == "table" then
  ns.Detection.Enable = ns.EnableDetection
  ns.Detection.Engine = Engine
  ns.Detection.Attach = ns.AttachDetector
  ns.Detection.ApplySlots = ns.ApplyDetectionSlots
end

if ns.RegisterPerformanceTarget then
  ns.RegisterPerformanceTarget("engine.reconcile", function() return Engine.Reconcile end,
    function(fn) Engine.Reconcile = fn end)
  ns.RegisterPerformanceTarget("engine.consumers", function() return Engine.RefreshConsumers end,
    function(fn) Engine.RefreshConsumers = fn end)
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("DetectionEngine", function()
    return Engine:GetDiagnostics()
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("DetectionEngine")
end
