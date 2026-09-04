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

local root = (... and ... ~= "") and ... or "."

local function Check(value, message)
  if not value then
    error(message or "check failed", 2)
  end
end

local function Equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
  end
end

local combat = false
local restriction = false
local deferNativeAssignment = false
local forbiddenMutations = 0
local invalidSetUnitCalls = 0
local secretBoolean = {}
local nativeBooleanValues = {}
local providers = {}
local eventFrames = {}
local timerQueue = {}
local diagnosticEvents = {}

local function HasDiagnostic(kind)
  for i = 1, #diagnosticEvents do
    if diagnosticEvents[i].kind == kind then
      return true
    end
  end
  return false
end

local function CountDiagnostic(kind, result)
  local count = 0
  for i = 1, #diagnosticEvents do
    local event = diagnosticEvents[i]
    if event.kind == kind and (result == nil or event.fields and event.fields.result == result) then
      count = count + 1
    end
  end
  return count
end

InCombatLockdown = function()
  return combat
end

issecretvalue = function(value)
  return rawequal(value, secretBoolean)
end

C_EventUtils = {
  IsEventValid = function()
    return true
  end,
}

C_Timer = {
  After = function(_delay, callback)
    timerQueue[#timerQueue + 1] = callback
  end,
}

local function Mutation()
  if combat then
    forbiddenMutations = forbiddenMutations + 1
    error("native configuration mutation during combat")
  end
end

local function NewTexture()
  local texture = {}
  function texture:SetVertexColorFromBoolean(value)
    nativeBooleanValues[#nativeBooleanValues + 1] = value
  end
  return texture
end

local function NewSlot()
	local slot = {mouse = true, shown = true}
  function slot:EnableMouse(value)
    Mutation()
    self.mouse = value
  end
  function slot:SetMouseClickEnabled(value)
    Mutation()
    self.click = value
  end
  function slot:SetMouseMotionEnabled(value)
    Mutation()
    self.motion = value
  end
  function slot:CreateTexture()
    return NewTexture()
  end
  function slot:AddDispelTypeTexture(texture)
    self.dispelTexture = texture
  end
	function slot:DriveNativeBoolean(value)
		self.dispelTexture:SetVertexColorFromBoolean(value, {}, {})
	end
	function slot:IsShown()
		return self.shown
	end
	return slot
end

local function NewContainer(parent)
  local container = {
    parent = parent,
    shown = false,
    alpha = 1,
    mouse = true,
    slots = {},
    addCounts = {},
    filterRefreshes = 0,
    providerRefreshes = 0,
    operations = {},
  }
  function container:SetAllPoints()
    Mutation()
  end
  function container:EnableMouse(value)
    Mutation()
    self.mouse = value
  end
  function container:SetMouseClickEnabled(value)
    Mutation()
    self.click = value
  end
  function container:SetMouseMotionEnabled(value)
    Mutation()
    self.motion = value
  end
  function container:Show()
    Mutation()
    self.shown = true
    self.operations[#self.operations + 1] = "show"
  end
  function container:Hide()
    Mutation()
    self.shown = false
    self.operations[#self.operations + 1] = "hide"
  end
  function container:IsShown()
    return self.shown
  end
  function container:GetAlpha()
    return self.alpha
  end
  function container:IsMouseEnabled()
    return self.mouse
  end
  function container:SetEnabled(value)
    Mutation()
    self.enabled = value
    self.operations[#self.operations + 1] = value and "enable" or "disable"
  end
  function container:SetUnit(unit)
    Mutation()
    if unit == nil or type(unit) ~= "string" or unit == "" then
      invalidSetUnitCalls = invalidSetUnitCalls + 1
      error("Retail native SetUnit requires a public nonempty unit token")
    end
    if self.failSetUnit ~= nil and self.failSetUnit == unit then
      error("injected SetUnit failure")
    end
    self.unit = unit
    self.operations[#self.operations + 1] = "setunit"
  end
  function container:AddAuraSlot(key, filter, info)
    Mutation()
    self.operations[#self.operations + 1] = "addslot"
    self.addCounts[key] = (self.addCounts[key] or 0) + 1
    self.filters = self.filters or {}
    self.filters[key] = filter
    local slot = NewSlot()
    self.slots[key] = slot
    if info and info.initializeFrame then
      info.initializeFrame(slot)
    end
    return slot
  end
  function container:SetAuraSlotFilterString(key, filter)
    Mutation()
    self.filters[key] = filter
    self.filterRefreshes = self.filterRefreshes + 1
  end
  function container:SetAuraSlotCandidateFilters(key, filters)
    Mutation()
    if self.failCandidateRefresh then
      error("injected candidate refresh failure")
    end
    self.candidates = self.candidates or {}
    self.candidates[key] = filters
    self.providerRefreshes = self.providerRefreshes + 1
  end
  return container
end

CreateFrame = function(kind, _name, parent)
  if kind == "AuraContainer" then
    return NewContainer(parent)
  end
  local frame = {events = {}}
  function frame:SetScript(_script, callback)
    self.callback = callback
  end
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  eventFrames[#eventFrames + 1] = frame
  return frame
end

local function NewNamespace()
	local pack = {useGap = true, environment = "OPEN_WORLD"}
	local currentPack = pack
	local ns = {
		addon = {
			GetAppliedEnvironmentPack = function()
				return currentPack
			end,
      OnRegenEnabled = function()
      end,
    },
    Diagnostics = {
      SafePublicBoolean = function(value)
        if rawequal(value, secretBoolean) then
          return nil
        end
        if value == true or value == false then
          return value
        end
        return nil
      end,
    },
	}
	ns.SetAppliedPack = function(nextPack)
		currentPack = nextPack
	end
	ns.GetDetectionSlots = function(currentPack)
		ns.lastDetectionPack = currentPack
    local primaryType = currentPack.primaryType or "Magic"
    local slots = {
      {
        key = "main",
        filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
        candidateFilters = {includeDispelTypes = {[primaryType] = true}},
        dispelType = primaryType,
        priority = currentPack.priority or 1,
      },
    }
    if currentPack.useGap then
      slots[2] = {key = "gap", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", candidateFilters = {includeDispelTypes = {Curse = true}}}
    end
    return slots
  end
  ns.RegisterDiagnosticProvider = function(name, callback)
    providers[name] = callback
  end
  ns.HasActiveAddonRestriction = function()
    return restriction
  end
  ns.RememberRestrictionState = function(_kind, value)
    restriction = value == true
  end
  ns.SafeNativeSetUnit = function(container, unit)
    if combat then
      return false, "DEFERRED_COMBAT"
    end
    if rawequal(unit, secretBoolean) or type(unit) ~= "string" or unit == "" then
      return false, "UNIT_INVALID"
    end
    if deferNativeAssignment then
      return false, "DEFERRED_RESTRICTION"
    end
    local ok = pcall(container.SetUnit, container, unit)
    return ok, ok and "ASSIGNED" or "UNIT_ASSIGN_FAILED"
  end
  ns.DiagnosticRecord = function(kind, fields)
    diagnosticEvents[#diagnosticEvents + 1] = {kind = kind, fields = fields}
  end
  ns.InvalidateDetection = function()
    ns.invalidations = (ns.invalidations or 0) + 1
  end
  ns.ScheduleFollowerRosterGuard = function()
    ns.followerGuards = (ns.followerGuards or 0) + 1
  end
  return ns, pack
end

local function LoadEngine(ns)
  local chunk = assert(loadfile(root .. "/ZDecursive/DetectionEngine.lua"))
  chunk("ZDecursive", ns)
  return ns.DetectionEngine
end

local function Read(path)
  local file = assert(io.open(root .. "/" .. path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local toc = Read("ZDecursive/ZDecursive.toc")
local detectionAt = assert(toc:find("Detection.lua", 1, true))
local engineAt = assert(toc:find("DetectionEngine.lua", 1, true))
local presentationAt = assert(toc:find("MUFPresentation.lua", 1, true))
local mufsAt = assert(toc:find("MUFs.lua", 1, true))
Check(detectionAt < engineAt and engineAt < presentationAt and presentationAt < mufsAt, "engine and presentation load-order seam")
local engineSource = Read("ZDecursive/DetectionEngine.lua")
Check(not engineSource:find("GetAuraData", 1, true), "engine never reads aura payloads")
Check(not engineSource:find("COMBAT_LOG", 1, true), "engine does not parse combat log")
Check(not engineSource:find('SetScript("OnUpdate"', 1, true), "engine does not poll")
Check(engineSource:find("MAX_RETRY_ATTEMPTS", 1, true), "engine bounds native recovery retries")
Check(engineSource:find("C_Timer", 1, true), "engine uses a coalesced timer retry without polling")
Check(engineSource:find("0.15, 0.50, 1.00, 2.00, 4.00, 7.00, 10.00, 13.00, 16.00", 1, true), "engine retains the full bounded convergence cadence")
local coreSource = Read("ZDecursive/Core.lua")
Check(coreSource:find('RegisterEvent("PLAYER_LEAVING_WORLD"', 1, true), "Core arms world-transition recovery")
Check(coreSource:find('engine:Refresh("CORE_WORLD_ENTRY")', 1, true), "world entry has authoritative engine reconcile")
Check(coreSource:find('engine:Defer("WORLD_ENTRY_LOCKED")', 1, true), "locked world entry remains deferred")
local enableMUFsAt = assert(coreSource:find("if ns.EnableMUFs then", 1, true))
local enableAlertsAt = assert(coreSource:find("if ns.EnableAlerts then", 1, true))
local enableLiveListAt = assert(coreSource:find("if ns.EnableLiveList then", 1, true))
local enableDetectionAt = assert(coreSource:find("if ns.EnableDetection then", 1, true))
Check(enableMUFsAt < enableDetectionAt and enableAlertsAt < enableDetectionAt and enableLiveListAt < enableDetectionAt, "all required consumers register before engine startup")
local detectionSource = Read("ZDecursive/Detection.lua")
Check(detectionSource:find("function ns.PrepareWorldEntryRoster", 1, true), "world entry can clear stale follower snapshot")
Check(detectionSource:find("ns.ScheduleFollowerRosterGuard()", 1, true), "group world entry keeps bounded follower convergence")
local mufSource = Read("ZDecursive/MUFs.lua")
local liveSource = Read("ZDecursive/LiveList.lua")
local alertSource = Read("ZDecursive/Alerts.lua")
Check(mufSource:find('RegisterConsumer("MUFs"', 1, true) and mufSource:find('BindCarrier("MUFs"', 1, true), "MUF consumer migrated")
Check(liveSource:find('RegisterConsumer("LiveList"', 1, true) and liveSource:find('BindCarrier("LiveList"', 1, true), "LiveList consumer migrated")
Check(alertSource:find('RegisterConsumer("Alerts"', 1, true), "Alerts consumer migrated")
local optionSource = Read("ZDecursive/Options.lua")
for _, label in ipairs({
  "Bleed-effect detection",
  "Do not skip priority-list units",
  "Skip stealthed",
  "Learn spell IDs from successful dispels",
  "MUF refresh rate",
  "Disable macro creation",
}) do
  Check(not optionSource:find(label, 1, true), "unsupported menu control removed: " .. label)
end

local function RegisterEmptyConsumer(engine, name)
  engine:RegisterConsumer(name, function()
    return true, "SUCCESS", 0
  end)
end

local function RegisterEmptyRequiredConsumers(engine)
  RegisterEmptyConsumer(engine, "MUFs")
  RegisterEmptyConsumer(engine, "Alerts")
  RegisterEmptyConsumer(engine, "LiveList")
end

local function RegisterNonMUFConsumers(engine)
  RegisterEmptyConsumer(engine, "Alerts")
  RegisterEmptyConsumer(engine, "LiveList")
end

local ns, pack = NewNamespace()
local engine = LoadEngine(ns)
Equal(engine.state, "COLD", "engine begins cold")
local coldReport = engine:GetDiagnostics()
Check(coldReport.consumerStates.MUFs.registered == false and coldReport.consumerStates.Alerts.registered == false and coldReport.consumerStates.LiveList.registered == false, "cold diagnostics expose sanitized required-bank absence")
Check(not engine:Start(), "cold start waits for required consumers")
Check(engine.state ~= "READY", "zero-consumer startup cannot claim ready")
RegisterEmptyRequiredConsumers(engine)
Check(engine:Start(), "cold start succeeds after all required consumers register")
Equal(engine.state, "READY", "start reaches ready")
local initialConfiguration = engine.configurationGeneration
Check(engine:Start(), "repeated start is idempotent")
Equal(engine.configurationGeneration, initialConfiguration, "repeated start does not reconfigure")
Check(engine.eventsRegistered, "engine registers lifecycle events")
local startupReport = engine:GetDiagnostics()
Equal(startupReport.requiredConsumerCount, 3, "startup declares three required consumer banks")
Equal(startupReport.registeredRequiredConsumerCount, 3, "startup registers all required banks before ready")
Equal(startupReport.dirtyGeneration, startupReport.committedGeneration, "successful startup commits its coalesced dirty generation")
Equal(startupReport.consumerStates.Alerts.expectedCount, 0, "registered noncarrier Alerts bank reports explicit expected zero")
Equal(startupReport.consumerStates.Alerts.desired, 0, "Alerts diagnostics expose no carrier identity")

restriction = true
local restrictedNS = NewNamespace()
local restrictedEngine = LoadEngine(restrictedNS)
local restrictedOwner = {}
restrictedEngine:RegisterConsumer("MUFs", function()
  local _container, assigned, status = restrictedEngine:BindCarrier("MUFs", {}, "player", function()
  end, restrictedOwner)
  return assigned, status, 1
end)
RegisterNonMUFConsumers(restrictedEngine)
local restrictedTimerBaseline = #timerQueue
Check(restrictedEngine:Start(), "addon restriction categories do not block topology startup")
Check(restrictedEngine.eventsRegistered, "restriction-time startup still registers lifecycle wakeups")
Equal(#timerQueue, restrictedTimerBaseline, "addon restriction category does not schedule a global topology retry")
restriction = false
Equal(restrictedEngine.state, "READY", "restriction category leaves topology ready")
local restrictedReport = restrictedEngine:GetDiagnostics()
Equal(restrictedReport.desiredCarrierCount, 1, "restriction-only startup recovers the desired Solo player carrier")
Equal(restrictedReport.activeCarrierCount, 1, "restriction-only startup activates the Solo player carrier")
Equal(restrictedReport.transactionConfiguredCarrierCount, 1, "restriction-only startup configures the Solo player carrier")
Equal(restrictedReport.transactionShownCarrierCount, 1, "restriction-only startup shows the Solo player carrier")

local consumerRefreshes = {MUFs = 0, LiveList = 0, Alerts = 0}
for name in pairs(consumerRefreshes) do
  engine:RegisterConsumer(name, function()
    consumerRefreshes[name] = consumerRefreshes[name] + 1
    local expected = 0
    for i = 1, #engine.carriers do
      local record = engine.carriers[i]
      if record.consumer == name and type(record.desiredUnit) == "string" then
        expected = expected + 1
      end
    end
    return true, "SUCCESS", expected
  end)
end

local function PaintSlot(slot)
  local texture = slot:CreateTexture()
  slot:AddDispelTypeTexture(texture, {})
  slot._decursivePresentationRegistered = true
  slot._decursivePresentationHost = {
    GetParent = function()
      return slot
    end,
  }
end

local owners = {{}, {}, {}, {}, {}}
local parents = {{}, {}, {}, {}, {}}
local units = {"player", "pet", "party1", "partypet1", "raid2"}
for i = 1, #owners do
  local container = engine:CreateCarrier(i == 5 and "LiveList" or "MUFs", parents[i], PaintSlot, owners[i])
	Check(container ~= nil, "carrier precreated out of combat")
	Check(engine:AssignCarrier(owners[i], units[i]), "carrier assigned")
	Check(container.shown and container.enabled == true and container.unit == units[i] and container.mouse == false, "native carrier is assigned, enabled, shown, and noninteractive")
	Equal(table.concat(container.operations, ","), "disable,setunit,addslot,addslot,enable,show", "native carrier lifecycle order")
	Equal(container.addCounts.main, 1, "main slot created once")
	Check(container.slots.main:IsShown(), "native slot is shown after assignment")
	Check(container.slots.main.dispelTexture ~= nil, "native slot callback binds the addon presentation texture")
end
engine.consumers.MUFs.expectedCount = 4
engine.consumers.LiveList.expectedCount = 1
engine.consumers.Alerts.expectedCount = 0

local firstContainer = engine.carrierByOwner[owners[1]].container
firstContainer.slots.main:DriveNativeBoolean(false)
firstContainer.slots.main:DriveNativeBoolean(false)
firstContainer.slots.main:DriveNativeBoolean(true)
firstContainer.slots.main:DriveNativeBoolean(secretBoolean)
Equal(nativeBooleanValues[1], false, "native idle boolean")
Equal(nativeBooleanValues[2], false, "native nondispellable boolean")
Equal(nativeBooleanValues[3], true, "native dispellable boolean")
Check(rawequal(nativeBooleanValues[4], secretBoolean), "secret boolean reaches native widget unchanged")

local assignmentGeneration = engine.assignmentGeneration
Check(engine:AssignCarrier(owners[1], "player"), "same assignment succeeds")
Equal(engine.assignmentGeneration, assignmentGeneration, "same assignment is idempotent")
local dungeonPack = {useGap = false, environment = "DUNGEON"}
ns.SetAppliedPack(dungeonPack)
Check(engine:Configure("PROFILE"), "profile filter configure succeeds")
Check(rawequal(ns.lastDetectionPack, dungeonPack), "provider configures from the applied environment pack object")
Equal(firstContainer.addCounts.main, 1, "configure does not duplicate native slots")
Check(firstContainer.providerRefreshes > 0, "provider candidates refreshed out of combat")
Equal(engine:GetDiagnostics().appliedPackType, "table", "diagnostic applied pack type is sanitized")
Equal(engine:GetDiagnostics().providerType, "NATIVE_AURA_CONTAINER", "diagnostic provider type")
Equal(engine:GetDiagnostics().presentationType, "NATIVE_SLOT_CALLBACK", "diagnostic presentation type")

local beforeRegen = engine.regenReconcileGeneration
local beforeAssignments = engine.assignmentGeneration
combat = true
engine:OnEvent("PLAYER_REGEN_DISABLED")
Equal(engine.state, "COMBAT_DEFERRED", "combat enters deferred state")
Check(not engine:AssignCarrier(owners[1], "party2"), "changed combat assignment defers")
Check(not engine:UnassignCarrier(owners[2]), "combat unassignment defers")
local raidPack = {useGap = true, environment = "RAID"}
ns.SetAppliedPack(raidPack)
Check(not engine:Configure("COMBAT_PROFILE"), "combat filter configure defers")
Check(not engine:Refresh("COMBAT_ROSTER"), "combat refresh defers")
Equal(firstContainer.unit, "player", "combat preserves existing assignment")
firstContainer.slots.main:DriveNativeBoolean(secretBoolean)
Equal(forbiddenMutations, 0, "no addon native configuration mutation in combat")
local combatTimerCount = #timerQueue
timerQueue[#timerQueue]()
Equal(forbiddenMutations, 0, "scheduled recovery samples in combat never call native SetUnit")
Equal(#timerQueue, combatTimerCount + 1, "blocked timer schedules one bounded not-locked replay sample")
combat = false
engine:OnEvent("PLAYER_REGEN_ENABLED")
Equal(engine.regenSeenGeneration, 1, "regen event observed")
Check(engine:Recover("CORE_REGEN"), "regen recovery succeeds: " .. tostring(engine.lastFailure) .. "/" .. tostring(engine.state) .. "/" .. tostring(engine.pendingReason))
Check(not engine:Recover("CORE_REGEN_REPEAT"), "regen recovery runs exactly once")
Check(rawequal(ns.lastDetectionPack, raidPack), "regen provider reconfigure uses the newly applied environment pack")
Equal(engine.regenReconcileGeneration, beforeRegen + 1, "one regen reconcile generation")
Equal(firstContainer.unit, "party2", "pending assignment applied after combat")
Check(firstContainer.enabled == true and firstContainer.shown == true and firstContainer.slots.main:IsShown(), "applied-environment combat transition leaves assigned native carrier and slot active")
Check(firstContainer.candidates.gap.includeDispelTypes.Curse == true, "applied-environment transition refreshes the native gap provider")
Check(engine.carrierByOwner[owners[2]].active == false, "pending logical unassignment applied after combat")
Equal(engine.carrierByOwner[owners[2]].unit, "pet", "logical unassignment retains the last valid native binding")
Check(engine.carrierByOwner[owners[2]].container.enabled == false and engine.carrierByOwner[owners[2]].container.shown == false, "logically unassigned native carrier is disabled and hidden")
Check(engine.assignmentGeneration >= beforeAssignments + 2, "pending assignments advance generation")
Check(HasDiagnostic("ASSIGNMENT_DEFERRED_COMBAT"), "sanitized diagnostics record combat-deferred assignment")
Check(HasDiagnostic("ASSIGNMENT_REPLAYED_OOC"), "sanitized diagnostics record out-of-combat assignment replay")
Check(engine:GetDiagnostics().assignmentDeferredCombatCount > 0, "diagnostics count coalesced combat assignment deferrals")
Check(engine:GetDiagnostics().assignmentReplayedOOCCount > 0, "diagnostics count out-of-combat assignment replays")
for name, count in pairs(consumerRefreshes) do
  Equal(count, 1, name .. " reconciled once")
end

local detectionSource = Read("ZDecursive/Detection.lua")
local ownershipGuard = detectionSource:find("if ns.DetectionEngine and ns.addon and (", 1, true)
local legacyRosterRefresh = detectionSource:find('elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then', 1, true)
Check(ownershipGuard and legacyRosterRefresh and ownershipGuard < legacyRosterRefresh, "Core ownership guard precedes fallback roster refresh")

local randomizedOrders = {
  {"core", "engine", "detection"},
  {"detection", "core", "engine"},
  {"engine", "detection", "core"},
  {"engine", "core", "detection"},
}
ns.addon.OnGroupRosterUpdate = function()
end
for i = 1, #randomizedOrders do
  local refreshes = 0
  for j = 1, #randomizedOrders[i] do
    local owner = randomizedOrders[i][j]
    if owner == "core" then
      refreshes = refreshes + 1
    elseif owner == "engine" then
      local generation = engine.refreshGeneration
      engine:OnEvent("GROUP_ROSTER_UPDATE")
      Equal(engine.refreshGeneration, generation, "engine event handler defers roster ownership to Core")
    else
      Check(ownershipGuard < legacyRosterRefresh, "Detection fallback is gated while Core owns the transaction")
    end
  end
  Equal(refreshes, 1, "randomized event order has one canonical roster transaction")
end

restriction = true
engine:OnEvent("ADDON_RESTRICTION_STATE_CHANGED", "TEST", true)
Equal(engine.state, "READY", "restriction event does not globally defer the engine")
restriction = false
engine:OnEvent("ADDON_RESTRICTION_STATE_CHANGED", "TEST", false)
Equal(engine.state, "READY", "restriction clear leaves the engine ready")

Check(engine:AssignCarrier(owners[3], "raid1"), "party to raid transition")
Check(engine:AssignCarrier(owners[4], "raidpet1"), "follower pet transition")
local report = engine:GetDiagnostics()
Equal(report.engineVersion, 7, "diagnostic engine version")
Equal(report.lifecycleState, "READY", "diagnostic lifecycle")
Equal(report.assignedCarrierCount, 4, "diagnostic assigned count")
Equal(report.carrierCategoryCounts.party, 1, "diagnostic party category")
Equal(report.carrierCategoryCounts.raid, 2, "diagnostic raid category")
Equal(report.carrierCategoryCounts.pets, 1, "diagnostic pet category")
Equal(report.carrierShownCount, 4, "diagnostic shown carriers exclude logically unassigned native carriers")
Equal(report.carrierAlphaZeroCount, 0, "diagnostic carrier alpha")
Equal(report.carrierMouseEnabledCount, 0, "diagnostic carrier mouse state")
Check(report.slotCreationGeneration > 0 and report.providerRefreshGeneration > 0, "diagnostic slot and provider generations")
Equal(report.presentationRegisteredSlotCount, 10, "diagnostics count presentation registrations separately from carriers")
Equal(report.presentationVisibilityGatedSlotCount, 10, "diagnostics prove registered presentations inherit their slot visibility gate")
Equal(report.nativeCombatGeneration, 1, "diagnostic native combat milestone")
Equal(report.pendingAssignmentCount, 0, "diagnostic pending assignments")
Equal(report.logicallyUnassignedCarrierCount, 1, "diagnostics distinguish logical unassignment from native binding")
Equal(report.retainedNativeBindingCount, 1, "diagnostics count retained last-valid native bindings")
Equal(report.desiredCarrierCount, 4, "diagnostics expose the desired carrier transaction count")
Equal(report.activeCarrierCount, 4, "diagnostics expose the active carrier transaction count")
Equal(report.transactionConfiguredCarrierCount, 4, "diagnostics expose the configured carrier transaction count")
Equal(report.transactionShownCarrierCount, 4, "diagnostics expose the shown carrier transaction count")
Check(type(report.consumerStates.MUFs) == "table", "diagnostic consumer states")
Check(report.consumerMUFs.available, "diagnostic MUF consumer state")
for _, name in ipairs({"MUFs", "Alerts", "LiveList"}) do
  local state = report.consumerStates[name]
  Check(type(state.expectedCount) == "number" and type(state.desired) == "number" and type(state.active) == "number" and type(state.configured) == "number" and type(state.shown) == "number", "consumer diagnostics expose sanitized bank counts for " .. name)
  Equal(state.expectedCount, state.desired, name .. " expected count matches desired bank")
  Equal(state.desired, state.active, name .. " desired count matches active bank")
  Equal(state.active, state.configured, name .. " active count matches configured bank")
  Equal(state.configured, state.shown, name .. " configured count matches shown bank")
end
Check(type(providers.DetectionEngine) == "function", "diagnostic provider survives bootstrap")
Check(pcall(providers.DetectionEngine), "diagnostic provider is failure contained")

engine:RegisterConsumer("InjectedFailure", function()
  error("injected consumer failure")
end)
Check(not engine:Refresh("CONSUMER_FAILURE"), "consumer failure rejects the transaction")
Equal(engine.state, "RECOVERING", "consumer failure remains pending instead of claiming applied")
Check(engine.failClosed == true and engine.pending == true, "consumer failure fail-closes and retains recovery")
Check(engine:GetDiagnostics().consumerStates.InjectedFailure.available == false, "consumer failure reported")
engine:RegisterConsumer("InjectedFailure", function()
  return true
end)
Check(engine:Refresh("CONSUMER_RECOVERY"), "consumer recovery restores the transaction")

local invalidations = ns.invalidations or 0
engine:OnEvent("PLAYER_SPECIALIZATION_CHANGED")
Check((ns.invalidations or 0) == invalidations + 1, "specialization invalidates capability model")
Check((ns.followerGuards or 0) > 0, "specialization schedules follower convergence")

local itemInvalidations = ns.invalidations or 0
local itemRefreshGeneration = engine.refreshGeneration
local itemTimerBaseline = #timerQueue
engine:OnEvent("BAG_UPDATE_DELAYED")
engine:OnEvent("ITEM_COUNT_CHANGED", 269586, 1)
Equal(#timerQueue, itemTimerBaseline + 1, "inventory events coalesce into one click action refresh")
Equal(ns.invalidations or 0, itemInvalidations, "inventory refresh waits for the coalesced callback")
timerQueue[#timerQueue]()
Equal(ns.invalidations or 0, itemInvalidations + 1, "inventory refresh invalidates detection and click actions")
Check(engine.refreshGeneration > itemRefreshGeneration, "inventory refresh reconciles every required consumer")

Check(engine:Reset(), "reset succeeds")
Equal(engine.state, "COLD", "reset returns cold")
Equal(engine:GetDiagnostics().assignedCarrierCount, 0, "reset clears assignments")
Equal(invalidSetUnitCalls, 0, "assignment, unassignment, fail-close, and reset never call native SetUnit with nil or invalid tokens")
Check(engine:AssignCarrier(owners[1], "player"), "Solo reload rebinds the destination player with a valid token")
Check(engine:Start(), "Solo reload configures the rebound player carrier")
local soloReload = engine:GetDiagnostics()
Equal(soloReload.assignedCarrierCount, 1, "stale multi-unit bank converges to an authoritative no-party player roster while the Solo pack remains applied")
Equal(soloReload.configuredCarrierCount, 1, "Solo reload configures an active detection carrier")
Equal(soloReload.carrierShownCount, 1, "Solo reload shows the configured detection carrier")
Check(soloReload.failClosed == false and soloReload.pendingAssignmentCount == 0, "Solo reload clears recovery without a retry storm")
Equal(invalidSetUnitCalls, 0, "Solo reload uses only valid native unit assignments")

local combatNS = NewNamespace()
local combatEngine = LoadEngine(combatNS)
local recoveredConsumer = 0
combatEngine:RegisterConsumer("MUFs", function()
  recoveredConsumer = recoveredConsumer + 1
  return true, "SUCCESS", 0
end)
RegisterNonMUFConsumers(combatEngine)
combat = true
Check(not combatEngine:Start(), "combat reload start defers")
Equal(combatEngine.state, "COMBAT_DEFERRED", "combat reload state")
Check(combatEngine.eventsRegistered, "combat reload registers regen before deferring")
combat = false
Check(combatEngine:Recover("COMBAT_RELOAD_REGEN"), "combat reload converges on regen")
Equal(recoveredConsumer, 1, "combat reload consumer reconciled")

local incompleteNS = NewNamespace()
local incompleteEngine = LoadEngine(incompleteNS)
RegisterEmptyRequiredConsumers(incompleteEngine)
Check(incompleteEngine:Start(), "incomplete transaction engine starts")
local incompleteOwner = {}
Check(incompleteEngine:CreateCarrier("MUFs", {}, PaintSlot, incompleteOwner) ~= nil, "incomplete transaction carrier exists")
local injectRestriction = true
incompleteEngine:RegisterConsumer("MUFs", function()
  if injectRestriction then
    injectRestriction = false
    deferNativeAssignment = true
    local assigned, status = incompleteEngine:AssignCarrier(incompleteOwner, "player")
    deferNativeAssignment = false
    return assigned, status, 1
  end
  local assigned, status = incompleteEngine:AssignCarrier(incompleteOwner, "player")
  return assigned, status, 1
end)
local appliedBeforeIncomplete = CountDiagnostic("ENGINE_RECONCILE", "APPLIED")
Check(not incompleteEngine:Refresh("INCOMPLETE_DESIRED_BANK"), "desired one active zero transaction is rejected")
local incompleteReport = incompleteEngine:GetDiagnostics()
Equal(incompleteReport.desiredCarrierCount, 1, "incomplete transaction retains one desired carrier")
Equal(incompleteReport.activeCarrierCount, 0, "incomplete transaction has no active carrier")
Equal(incompleteReport.transactionConfiguredCarrierCount, 0, "incomplete transaction has no configured carrier")
Equal(CountDiagnostic("ENGINE_RECONCILE", "APPLIED"), appliedBeforeIncomplete, "incomplete transaction never logs APPLIED")
Check(incompleteReport.pendingReconcile == true, "incomplete transaction retains its pending generation")
timerQueue[#timerQueue]()
local recoveredIncomplete = incompleteEngine:GetDiagnostics()
Equal(recoveredIncomplete.desiredCarrierCount, 1, "restriction retry retains desired carrier")
Equal(recoveredIncomplete.activeCarrierCount, 1, "restriction retry activates desired carrier")
Equal(recoveredIncomplete.transactionConfiguredCarrierCount, 1, "restriction retry configures desired carrier")
Equal(recoveredIncomplete.transactionShownCarrierCount, 1, "restriction retry shows desired carrier")
local logicalBefore = CountDiagnostic("CARRIER_ASSIGN", "LOGICALLY_UNASSIGNED")
Check(incompleteEngine:UnassignCarrier(incompleteOwner), "first logical unassignment succeeds")
Check(incompleteEngine:UnassignCarrier(incompleteOwner), "repeated logical unassignment is idempotent")
Equal(CountDiagnostic("CARRIER_ASSIGN", "LOGICALLY_UNASSIGNED"), logicalBefore + 1, "repeated logical unassignment is deduplicated")

local missingBankNS = NewNamespace()
local missingBankEngine = LoadEngine(missingBankNS)
RegisterEmptyRequiredConsumers(missingBankEngine)
Check(missingBankEngine:Start(), "missing-bank engine starts")
missingBankEngine:RegisterConsumer("MUFs", function()
  return true, "SUCCESS", 1
end)
local missingBankApplied = CountDiagnostic("ENGINE_RECONCILE", "APPLIED")
Check(not missingBankEngine:Refresh("EXPECTED_BANK_MISSING"), "consumer cannot claim success with an absent expected carrier")
Equal(CountDiagnostic("ENGINE_RECONCILE", "APPLIED"), missingBankApplied, "absent expected bank never logs APPLIED")
Check(missingBankEngine.failClosed == true and missingBankEngine.pending == true, "absent expected bank retains bounded recovery")

local staleExpectedNS = NewNamespace()
local staleExpectedEngine = LoadEngine(staleExpectedNS)
RegisterEmptyRequiredConsumers(staleExpectedEngine)
Check(staleExpectedEngine:Start(), "fresh expected-count engine starts")
staleExpectedEngine:RegisterConsumer("Alerts", function()
  return true, "SUCCESS"
end)
local staleExpectedApplied = CountDiagnostic("ENGINE_RECONCILE", "APPLIED")
Check(not staleExpectedEngine:Refresh("STALE_EXPECTED_COUNT"), "required consumer must report its expected count on every reconcile")
Equal(CountDiagnostic("ENGINE_RECONCILE", "APPLIED"), staleExpectedApplied, "stale expected count cannot authorize APPLIED")

local modeNS, multiplePack = NewNamespace()
multiplePack.primaryType = "Magic"
multiplePack.priority = 1
local soloPack = {useGap = false, environment = "SOLO", primaryType = "Poison", priority = 4}
local modeEngine = LoadEngine(modeNS)
local modeOwners = {{}, {}}
local modeUnits = {"player", "party1"}
local configuredPacks = {}
local configuredTypes = {}
modeEngine:RegisterConsumer("MUFs", function()
  local ready = true
  for i = 1, #modeOwners do
    local index = i
    local _container, assigned = modeEngine:BindCarrier("MUFs", {}, modeUnits[index], function(_frame, key, slotInfo, configuredPack)
      if key == "main" then
        configuredPacks[index] = configuredPack
        configuredTypes[index] = slotInfo.dispelType
      end
    end, modeOwners[index])
    if not assigned then
      ready = false
    end
  end
  return ready, ready and "SUCCESS" or "FAILURE", #modeOwners
end)
RegisterNonMUFConsumers(modeEngine)
Check(modeEngine:Start(), "mode engine starts with its required banks")
Check(modeEngine.state == "READY", "initial Multiple transaction applies")
Check(rawequal(configuredPacks[1], multiplePack) and configuredTypes[1] == "Magic", "initial presentation consumes current Multiple pack: " .. tostring(configuredPacks[1]) .. "/" .. tostring(configuredTypes[1]))
modeNS.SetAppliedPack(soloPack)
Check(modeEngine:Refresh("MULTIPLE_TO_SOLO"), "same-roster Multiple to Solo transaction applies")
Check(rawequal(configuredPacks[1], soloPack) and configuredTypes[1] == "Poison", "same-unit presentation consumes current Solo pack without stale closure")
Check(modeEngine.carrierByOwner[modeOwners[1]].container.candidates.main.includeDispelTypes.Poison == true, "Solo provider candidates apply in the same transaction")
Equal(modeEngine.carrierByOwner[modeOwners[2]].unit, "party1", "Profile Mode Solo retains the full applicable group roster")
modeNS.SetAppliedPack(multiplePack)
Check(modeEngine:Refresh("SOLO_TO_MULTIPLE"), "same-roster Solo to Multiple transaction applies")
Check(rawequal(configuredPacks[2], multiplePack) and configuredTypes[2] == "Magic", "repeated toggle returns every carrier presentation to Multiple")

local failingRecord = modeEngine.carrierByOwner[modeOwners[1]]
local healthyRecord = modeEngine.carrierByOwner[modeOwners[2]]
modeUnits[1] = "raid1"
failingRecord.container.failSetUnit = "raid1"
local retryBaseline = #timerQueue
Check(not modeEngine:Refresh("MODE_ASSIGN_FAILURE"), "SetUnit failure rejects the environment transaction")
Check(modeEngine.failClosed == true and modeEngine.state == "RECOVERING", "SetUnit failure enters fail-closed recovery")
Check(failingRecord.container.enabled == false and failingRecord.container.shown == false, "failed carrier is hidden and disabled")
Check(healthyRecord.container.enabled == true and healthyRecord.container.shown == true, "owner failure retains unrelated last-good carrier")
Equal(#timerQueue, retryBaseline + 1, "assignment failure schedules one generation-coalesced retry")
failingRecord.container.failSetUnit = nil
timerQueue[#timerQueue]()
Check(modeEngine.state == "READY" and modeEngine.failClosed == false, "bounded retry restores the carrier bank")
Equal(failingRecord.container.unit, "raid1", "retry binds the exact intended secure MUF unit")
Check(rawequal(configuredPacks[1], multiplePack), "retry presentation still consumes the currently applied pack")

combat = true
modeNS.SetAppliedPack(soloPack)
Check(not modeEngine:Refresh("MULTIPLE_TO_SOLO_COMBAT"), "combat defers the mode transaction")
Check(rawequal(configuredPacks[1], multiplePack), "combat preserves the previously configured presentation pack")
combat = false
Check(modeEngine:Recover("MODE_REGEN"), "regen applies the deferred Solo transaction")
Check(rawequal(configuredPacks[1], soloPack) and configuredTypes[1] == "Poison", "regen configures presentation and provider from current Solo pack")

local configureRetryBaseline = #timerQueue
failingRecord.container.failCandidateRefresh = true
Check(not modeEngine:Refresh("RECOVERY_CONFIG_FAILURE"), "forced provider refresh failure rejects the environment transaction")
Check(failingRecord.container.enabled == false and healthyRecord.container.enabled == true, "configuration failure quarantines only the affected owner bank")
Equal(#timerQueue, configureRetryBaseline + 1, "configuration failure schedules one coalesced retry")
failingRecord.container.failCandidateRefresh = nil
timerQueue[#timerQueue]()
Check(modeEngine.state == "READY" and modeEngine.failClosed == false, "configuration retry restores the full carrier bank")
local modeReport = modeEngine:GetDiagnostics()
Check(modeReport.configuredPackGeneration == modeReport.desiredGeneration, "diagnostics distinguish current applied/configured generation")
Check(modeReport.retryExhausted == false and modeReport.pendingReconcile == false, "successful retry clears sanitized retry state")

combat = true
Check(not modeEngine:UnassignCarrier(modeOwners[2]), "combat logical unassignment remains pending")
combat = false
modeEngine:FailClosed("INJECTED_AFTER_PENDING_UNASSIGN")
Check(healthyRecord.active == false and healthyRecord.desiredUnit == nil, "fail-close preserves a requested logical unassignment")
Check(healthyRecord.container.enabled == false and healthyRecord.container.shown == false, "fail-close cannot resurrect a logically unassigned carrier")
Equal(invalidSetUnitCalls, 0, "fail-close after pending unassignment never attempts SetUnit nil")

local failedNS = NewNamespace()
failedNS.GetDetectionSlots = function()
  error("injected provider failure")
end
local failedEngine = LoadEngine(failedNS)
local failedOwner = {}
local failedContainer = failedEngine:CreateCarrier("MUFs", {}, PaintSlot, failedOwner)
Check(failedContainer ~= nil, "native carrier still created before provider configure")
failedEngine:RegisterConsumer("MUFs", function()
  local assigned, status = failedEngine:AssignCarrier(failedOwner, "player")
  return assigned, status, 1
end)
RegisterNonMUFConsumers(failedEngine)
local failedRetryBaseline = #timerQueue
Check(not failedEngine:Start(), "provider failure prevents startup transaction apply")
Equal(failedEngine.state, "RECOVERING", "provider failure fail-closes into bounded recovery")
Check(failedEngine.failClosed == true and failedContainer.enabled == false and failedContainer.shown == false, "provider failure clears and hides the managed carrier bank")
Equal(#timerQueue, failedRetryBaseline + 1, "provider failure schedules one coalesced retry")
Check(failedEngine.failureCount > 0, "provider failure counted")
Check(pcall(function()
  return failedEngine:GetDiagnostics()
end), "failed engine diagnostics remain available")

local reuseNS = NewNamespace()
local reuseEngine = LoadEngine(reuseNS)
local reuseOwner = {}
local reuseContainer = reuseEngine:CreateCarrier("MUFs", {}, PaintSlot, reuseOwner)
reuseEngine:RegisterConsumer("MUFs", function()
  local ok, status = reuseEngine:AssignCarrier(reuseOwner, "player")
  return ok, status, 1
end)
RegisterNonMUFConsumers(reuseEngine)
Check(reuseEngine:Start(), "reuse fixture starts")
local refreshCount = reuseContainer.providerRefreshes
local operationCount = #reuseContainer.operations
Check(reuseEngine:Refresh("UNCHANGED"), "unchanged bank applies")
Equal(reuseContainer.providerRefreshes, refreshCount, "unchanged bank avoids provider writes")
Equal(#reuseContainer.operations, operationCount, "unchanged bank avoids disable/enable/show")
reuseNS.SetAppliedPack({priority = 4, useGap = true})
Check(reuseEngine:Refresh("PRESENTATION_EDIT"), "presentation change applies")
Equal(reuseContainer.providerRefreshes, refreshCount, "priority edit avoids unchanged provider writes")
reuseNS.SetAppliedPack({primaryType = "Poison"})
Check(reuseEngine:Refresh("FILTER_EDIT"), "changed filter applies")
Check(reuseContainer.providerRefreshes > refreshCount, "changed filter reaches provider")
Check(reuseContainer.candidates.main.includeDispelTypes.Poison, "new candidate map committed")
refreshCount = reuseContainer.providerRefreshes
combat = true
Check(not reuseEngine:Refresh("COMBAT_EDIT"), "combat defers")
Equal(reuseContainer.providerRefreshes, refreshCount, "no provider writes in combat")
combat = false
Check(reuseEngine:Recover("REGEN"), "regen recovers")
Check(reuseContainer.providerRefreshes > refreshCount, "regen forces provider reapplication")
Check(reuseEngine.eventFrame.events.UNIT_AURA, "trace starts automatically for applied pack")
Check(reuseEngine:SetAuraTrace(true), "trace starts")
combat = true
reuseEngine:OnEvent("UNIT_AURA", "party1", secretBoolean)
reuseEngine:OnEvent("UNIT_AURA", secretBoolean, secretBoolean)
reuseEngine:OnEvent("UNIT_AURA", "raid0001")
reuseEngine:OnEvent("UNIT_AURA", "raid41")
combat = false
local trace = reuseEngine:GetDiagnostics()
Equal(trace.auraTraceTotal, 1, "only canonical public roster token counted")
Equal(trace.auraTraceCombat, 1, "combat events counted without reading payload")
trace.auraTraceUnits.party1 = 999
Equal(reuseEngine:GetDiagnostics().auraTraceUnits.party1, 1, "snapshot cannot mutate trace")
reuseEngine:SetAuraTrace(false)
Check(not reuseEngine.eventFrame.events.UNIT_AURA, "trace unregisters on stop")
reuseEngine:OnEvent("UNIT_AURA", "party1")
Equal(reuseEngine.auraTraceTotal, 1, "stopped trace retains bounded report")
Check(reuseEngine:Refresh("SAME_ENVIRONMENT"), "same pack refresh succeeds")
Check(not reuseEngine.auraTraceEnabled, "same pack refresh respects manual off")
Equal(reuseEngine.auraTraceTotal, 1, "same pack preserves report")
reuseNS.SetAppliedPack({primaryType = "Curse"})
combat = true
Check(not reuseEngine:Refresh("ENVIRONMENT_CHANGED"), "environment waits for combat")
Check(not reuseEngine.auraTraceEnabled, "deferred environment does not restart trace")
Equal(reuseEngine.auraTraceTotal, 1, "deferred environment preserves report")
combat = false
Check(reuseEngine:Recover("REGEN"), "new environment commits")
Check(reuseEngine.auraTraceEnabled, "new applied environment restarts trace")
Equal(reuseEngine.auraTraceTotal, 0, "new environment starts fresh counters")
reuseEngine:OnEvent("UNIT_AURA", "player")
Check(reuseEngine:Refresh("SAME_ENVIRONMENT"), "routine refresh succeeds")
Equal(reuseEngine.auraTraceTotal, 1, "routine refresh retains active counters")
local tracePack = {advanced = {autoAuraTrace = false}}
reuseNS.SetAppliedPack(tracePack)
Check(reuseEngine:Refresh("DISABLED_ENVIRONMENT"), "disabled environment applies")
Check(not reuseEngine.auraTraceEnabled, "per-environment off disables trace")
Equal(reuseEngine.auraTraceTotal, 0, "disabled environment clears previous environment counts")
tracePack.advanced.autoAuraTrace = true
Check(reuseEngine:Refresh("OPTIONS"), "current environment toggle on applies")
Check(reuseEngine.auraTraceEnabled, "same pack on starts trace")
reuseEngine:OnEvent("UNIT_AURA", "player")
tracePack.advanced.autoAuraTrace = false
Check(reuseEngine:Refresh("OPTIONS"), "current environment toggle off applies")
Check(not reuseEngine.auraTraceEnabled, "same pack off stops trace")
Equal(reuseEngine.auraTraceTotal, 1, "turning off preserves captured evidence")
io.write("detection-engine-contract: ok\n")
