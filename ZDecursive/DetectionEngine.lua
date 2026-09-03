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

local ENGINE_VERSION = 6
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
  self:SetState(STATES.COMBAT_DEFERRED, "combat deferred")
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_DEFER", {reason = self.pendingReason}, false)
  end
  if type(self.ScheduleRetry) == "function" then
    self:ScheduleRetry(self.pendingReason)
  end
  return false, LockedDown() and STATUS.DEFERRED_COMBAT or STATUS.DEFERRED_RESTRICTED
end

local function SetCarrierInteraction(container)
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

function Engine:ConfigureCarrier(record, pack)
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
  record.slotFrames = record.slotFrames or {}
  record.slotKeys = record.slotKeys or {}
  local wanted = {}
  local configured = true
  for i = 1, #slots do
    local slot = slots[i]
    local key = type(slot) == "table" and slot.key or nil
    local filter = type(slot) == "table" and slot.filter or nil
    if type(key) ~= "string" or key == "" or type(filter) ~= "string" or filter == "" then
      self:RecordFailure("SLOT_MALFORMED", false)
      configured = false
    else
      wanted[key] = true
      local function Initialize(frame)
        record.slotFrames[key] = frame
        SetCarrierInteraction(frame)
        if type(record.initialize) == "function" then
          local initOk = pcall(record.initialize, frame, key, slot, pack)
          if not initOk then
            self:RecordFailure("CONSUMER_PAINT_FAILED", false)
            configured = false
          end
        end
      end
      if record.slotKeys[key] then
        local setFilter = record.container.SetAuraSlotFilterString
        local setCandidates = record.container.SetAuraSlotCandidateFilters
        if type(setFilter) == "function" then
          local filterOk = pcall(setFilter, record.container, key, filter)
          if not filterOk then
            self:RecordFailure("FILTER_REFRESH_FAILED", false)
            configured = false
          end
        else
          self:RecordFailure("FILTER_REFRESH_UNAVAILABLE", false)
          configured = false
        end
        if type(setCandidates) == "function" then
          local candidateOk = pcall(setCandidates, record.container, key, slot.candidateFilters)
          if not candidateOk then
            self:RecordFailure("PROVIDER_REFRESH_FAILED", false)
            configured = false
          else
            self.providerRefreshGeneration = self.providerRefreshGeneration + 1
          end
        else
          self:RecordFailure("PROVIDER_REFRESH_UNAVAILABLE", false)
          configured = false
        end
        local frame = record.slotFrames[key]
        if frame and type(record.initialize) == "function" then
          local initOk = pcall(record.initialize, frame, key, slot, pack)
          if not initOk then
            self:RecordFailure("CONSUMER_PAINT_FAILED", false)
            configured = false
          end
        end
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
  if type(record.container.SetAuraSlotCandidateFilters) == "function" then
    for key in pairs(record.slotKeys) do
      if not wanted[key] then
        local clearOk = pcall(record.container.SetAuraSlotCandidateFilters, record.container, key, {includeDispelTypes = {}})
        if not clearOk then
          self:RecordFailure("STALE_SLOT_CLEAR_FAILED", false)
          configured = false
        end
      end
    end
  end
  if not configured then
    return false
  end
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
      if not self:ConfigureCarrier(record, CurrentPack()) then
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
    if not self:ConfigureCarrier(record, CurrentPack()) then
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

function Engine:RefreshConsumers(reason)
  local refreshed = true
  local status = STATUS.SUCCESS
  local failedConsumer
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    local consumer = self.consumers[name]
    if consumer and type(consumer.refresh) == "function" then
      consumer.expectedCount = nil
      local ok, result, resultStatus, expectedCount = pcall(consumer.refresh, reason)
      if type(expectedCount) == "number" and expectedCount >= 0 then
        consumer.expectedCount = math.floor(expectedCount)
      end
      if resultStatus == STATUS.DEFERRED_COMBAT or resultStatus == STATUS.DEFERRED_RESTRICTED or resultStatus == STATUS.FAILURE then
        result = resultStatus
      end
      if ok and (result == true or result == STATUS.SUCCESS) and not MutationBlocked() then
        consumer.refreshes = consumer.refreshes + 1
        consumer.available = true
      else
        consumer.failures = consumer.failures + 1
        consumer.available = false
        if result == STATUS.DEFERRED_COMBAT or LockedDown() or self.deferredStatus == STATUS.DEFERRED_COMBAT then
          status = STATUS.DEFERRED_COMBAT
        elseif result == STATUS.DEFERRED_RESTRICTED or self.deferredStatus == STATUS.DEFERRED_RESTRICTED then
          status = STATUS.DEFERRED_RESTRICTED
        else
          status = STATUS.FAILURE
          self:RecordFailure("CONSUMER_REFRESH_FAILED", false)
        end
        refreshed = false
        failedConsumer = failedConsumer or name
      end
    end
  end
  return refreshed, status, failedConsumer
end

function Engine:ValidateExpectedBanks(requireShown)
  local requiredReady = self:RequiredConsumersRegistered()
  if not requiredReady then
    return false, 0
  end
  local expectedTotal = 0
  for i = 1, #self.consumerOrder do
    local name = self.consumerOrder[i]
    local consumer = self.consumers[name]
    local expected = consumer and consumer.expectedCount
    if type(expected) == "number" then
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
        return false, expectedTotal
      end
    elseif REQUIRED_CONSUMER_SET[name] and consumer and consumer.registered == true then
      return false, expectedTotal
    end
  end
  return true, expectedTotal
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

function Engine:Configure(reason)
  if MutationBlocked() then
    return self:Defer(reason or "CONFIGURE_COMBAT")
  end
  local pack = CurrentPack()
  if type(pack) ~= "table" then
    self:RecordFailure("PACK_UNAVAILABLE", true)
    return false
  end
  self:SetState(STATES.CONFIGURING, "configuring")
  self.configurationGeneration = self.configurationGeneration + 1
  local configured = true
  local failedRecord
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if not SetCarrierEnabled(record, false) then
      configured = false
      failedRecord = record
      self:RecordFailure("CARRIER_DISABLE_FAILED", false)
      break
    end
    if not self:ConfigureCarrier(record, pack) then
      configured = false
      failedRecord = record
      break
    end
    if record.active == true and PublicUnitToken(record.unit) ~= nil then
      if not SetCarrierEnabled(record, true) or not SetCarrierShown(record, true) then
        configured = false
        failedRecord = record
        self:RecordFailure("CARRIER_ENABLE_FAILED", false)
        break
      end
      record.quarantined = false
    end
  end
  local desiredCount, activeCount, configuredCount, _shownBefore, pendingCount, transactionValid = self:GetCarrierTransactionCounts()
  local banksValid = self:ValidateExpectedBanks(false)
  if configured and (not transactionValid or not banksValid or pendingCount ~= 0 or desiredCount ~= activeCount or activeCount ~= configuredCount) then
    configured = false
    self:RecordFailure("CARRIER_TRANSACTION_INCOMPLETE", false)
  end
  if not configured then
    self:RecordFailure("TRANSACTION_CONFIGURE_FAILED", false)
    return self:FailClosed("TRANSACTION_CONFIGURE_FAILED", failedRecord and {record = failedRecord} or nil)
  end
  local desiredAfter, activeAfter, configuredAfter, shownAfter, pendingAfter, transactionValidAfter = self:GetCarrierTransactionCounts()
  local banksVisible, expectedAfter = self:ValidateExpectedBanks(true)
  if not transactionValidAfter or not banksVisible or pendingAfter ~= 0 or desiredAfter ~= activeAfter or activeAfter ~= configuredAfter or configuredAfter ~= shownAfter then
    self:RecordFailure("CARRIER_TRANSACTION_NOT_VISIBLE", false)
    return self:FailClosed("CARRIER_TRANSACTION_NOT_VISIBLE")
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
  self.deferredStatus = nil
  self:SetState(STATES.RECOVERING, "recovering")
  self.preparingConsumers = true
  local requiredReady, missingConsumer = self:RequiredConsumersRegistered()
  if not requiredReady then
    self.reconciling = false
    self.started = false
    self:RecordFailure("REQUIRED_CONSUMER_MISSING_" .. tostring(missingConsumer), false)
    self:SetState(STATES.RECOVERING, "required consumer missing")
    self:ScheduleRetry("REQUIRED_CONSUMERS_MISSING")
    return false, STATUS.FAILURE
  end
  self.started = true
  local consumersReady, consumerStatus, failedConsumer = self:RefreshConsumers(reason)
  self.preparingConsumers = false
  if not consumersReady then
    self.reconciling = false
    if consumerStatus == STATUS.DEFERRED_COMBAT or consumerStatus == STATUS.DEFERRED_RESTRICTED then
      self:Defer(consumerStatus)
      if ns.DiagnosticRecord then
        ns.DiagnosticRecord("ENGINE_RECONCILE", {
          reason = reason or "NONE",
          result = consumerStatus,
          desiredGeneration = self.desiredGeneration,
          configuredGeneration = self.configuredPackGeneration,
          failClosed = self.failClosed == true,
        }, false)
      end
      return false, consumerStatus
    end
    self:RecordFailure("CONSUMER_TRANSACTION_FAILED", false)
    if not self.failClosed then
      self:FailClosed("CONSUMER_TRANSACTION_FAILED", failedConsumer and {consumer = failedConsumer} or nil)
    end
    return false, STATUS.FAILURE
  end
  for i = 1, #self.carriers do
    local record = self.carriers[i]
    if record.pendingAssignment and not self.transactionFailed then
      if record.pendingUnit == nil then
        local ok = self:UnassignCarrier(record.owner)
        if not ok then
          self.transactionFailed = true
        end
      else
        local ok = self:AssignCarrier(record.owner, record.pendingUnit)
        if not ok then
          self.transactionFailed = true
        end
      end
    end
  end
  local configured = not self.transactionFailed and self:Configure(reason)
  if configured then
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
    self:SetState(STATES.READY, "reconciled")
  elseif not self.failClosed then
    self:FailClosed(consumersReady and "ASSIGNMENT_FAILED" or "TRANSACTION_FAILED", failedConsumer and {consumer = failedConsumer} or nil)
  end
  self.reconciling = false
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ENGINE_RECONCILE", {
      reason = reason or "NONE",
      result = configured and "APPLIED" or "FAIL_CLOSED",
      fromRegen = fromRegen == true,
      carriers = #self.carriers,
      desiredGeneration = self.desiredGeneration,
      configuredGeneration = self.configuredPackGeneration,
      failClosed = self.failClosed == true,
    }, false)
  end
  return configured, configured and STATUS.SUCCESS or STATUS.FAILURE
end

function Engine:Refresh(reason)
  local fromRegen = self.pending and not MutationBlocked()
  return self:Reconcile(reason or "REFRESH", fromRegen)
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
  self.started = false
  self.startRequested = false
  self.pendingReasons = {}
  self.dirtyGeneration = 0
  self.committedGeneration = 0
  self.assignmentGeneration = self.assignmentGeneration + 1
  self:SetState(STATES.COLD, "reset")
  return true
end

function Engine:OnEvent(event, arg1, arg2)
  if event == "PLAYER_REGEN_DISABLED" then
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
  if event == "BAG_UPDATE_DELAYED" or event == "ITEM_COUNT_CHANGED"
    or event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
    if (event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT") and arg2 == false then
      return
    end
    if self.itemActionRefreshScheduled then
      return
    end
    self.itemActionRefreshScheduled = true
    local function refreshItemActions()
      Engine.itemActionRefreshScheduled = false
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
  if event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" then
    if ns.InvalidateDetection then
      ns.InvalidateDetection()
    end
    if ns.ScheduleFollowerRosterGuard then
      ns.ScheduleFollowerRosterGuard()
    end
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

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("DetectionEngine", function()
    return Engine:GetDiagnostics()
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("DetectionEngine")
end
