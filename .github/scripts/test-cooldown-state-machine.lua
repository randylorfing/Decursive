local function readFile(path)
    if type(readfile) == "function" then return assert(readfile(path)) end
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

if arg and arg[1] == "--self-test-failure" then
    error("intentional cooldown state-machine harness failure")
end

local source = readFile("Decursive/Dcr_12_1.lua")
local beginMarker = "-- DCR_COOLDOWN_TX_V1_BEGIN"
local endMarker = "-- DCR_COOLDOWN_TX_V1_END"
local beginAt = assert(source:find(beginMarker, 1, true)) + #beginMarker
local endAt = assert(source:find(endMarker, beginAt, true))
local machineSource = source:sub(beginAt, endAt - 1)

local harness = [[
local now = 0
local timers = {}
local durationCalls = { cooldown = 0, charge = 0 }
local state = {}
local modernSecureUIRunning = true
local combatLocked = false
local cooldownActive = false
local finishPriorityCooldown
local cooldownGeneration = { [1] = 0, [2] = 0, [3] = 0 }
local priorityCooldownActive = { [1] = false, [2] = false, [3] = false }
local activePriorityMUF = { [1] = nil, [2] = nil, [3] = nil }
local trackedPrioritySpellIDs = { [1] = nil, [2] = nil, [3] = nil }
local managedCooldownDurationObjects = {
    [1] = nil,
    [2] = nil,
    [3] = nil,
    pending = {},
    activeSpellIDs = {},
    activeActionKeys = {},
    activePublicUnits = {},
    configuredActionsByPriority = {},
    configuredActionBySpellID = {},
    retryDelays = { .04, .10, .22, .45, .75, 1.40, 2.80 },
}
local cooldownMUFs = {}
local D = {
    profile = {
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Numbers = true,
    },
}
local C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
}
local function GetTime() return now end
local function InCombatLockdown() return combatLocked end
local function isAccessiblePublicValue(value) return value ~= state.inaccessible end
local function initializePriorityCooldownVisuals(MF) MF.initialized = (MF.initialized or 0) + 1 end
local function clearClickedCooldownVisual(MF) MF.cleared = (MF.cleared or 0) + 1 end
local function refreshManagedAfflictedCooldownVisuals() end
local function refreshSharedPriorityCooldownGates() end
local function refreshAllSharedPriorityCooldownGates() end
local function refreshRangeOverlays() end
local function resetTrackedDispelSpell() end
D.Apply121CooldownAppearance = function() end
D.Apply121RangeAppearance = function() end
D.AlertDiag = function() end
D.Is121SharedPriorityCooldownEnabled = function() return true end

local function makeDuration(remaining)
    return {
        GetRemainingDuration = function() return remaining end,
        IsZero = function() return remaining <= .05 end,
    }
end

local C_Spell = {
    GetSpellCooldown = function()
        return state.cooldownInfo
    end,
    GetSpellCharges = function()
        return state.chargeInfo
    end,
    GetSpellCooldownDuration = function(spellID, undocumented)
        assert(undocumented == nil, "cooldown duration received undocumented boolean")
        durationCalls.cooldown = durationCalls.cooldown + 1
        durationCalls.lastSpellID = spellID
        return state.cooldownDuration
    end,
    GetSpellChargeDuration = function(spellID, ignoreGCD)
        assert(ignoreGCD == true, "charge duration did not explicitly ignore the GCD")
        durationCalls.charge = durationCalls.charge + 1
        durationCalls.lastSpellID = spellID
        return state.chargeDuration
    end,
}
]] .. machineSource .. [[
return {
    begin = managedCooldownDurationObjects.BeginPending,
    retry = managedCooldownDurationObjects.RetryPending,
    reconcile = reconcilePriorityCooldown,
    reconcileAll = reconcileActivePriorityCooldowns,
    finish = finishPriorityCooldown,
    setNow = function(value) now = value end,
    setRunning = function(value) modernSecureUIRunning = value end,
    setCombat = function(value) combatLocked = value end,
    state = state,
    durations = durationCalls,
    generations = cooldownGeneration,
    active = priorityCooldownActive,
    activeMUF = activePriorityMUF,
    storage = managedCooldownDurationObjects,
    timers = timers,
    D = D,
    makeDuration = makeDuration,
}
]]

local loader = loadstring or load
local machine = assert(loader(harness, "cooldown-state-machine-test"))()

local function attempt(actionKey, spellID, publicUnit)
    return {
        actionKey = actionKey,
        actionID = spellID,
        aliasSpellIDs = { [spellID] = true },
        publicUnit = publicUnit or "party1",
    }
end

local function resetPriority(priority)
    machine.finish(priority, machine.generations[priority])
    machine.state.cooldownInfo = nil
    machine.state.chargeInfo = nil
    machine.state.cooldownDuration = nil
    machine.state.chargeDuration = nil
    machine.state.inaccessible = nil
    machine.setNow(0)
    machine.setRunning(true)
    machine.setCombat(false)
    machine.D.profile.CooldownOverlay121Enabled = true
end

-- A nil first query and a public zero-span second query must remain pending.
local clicked = { CurrUnit = "party1", Decursive121ExpectedUnit = "party1" }
assert(machine.begin(1, 999, clicked, attempt("SPELL:101", 101)) == false)
local ok, generation = machine.begin(1, 101, clicked, attempt("SPELL:101", 101))
assert(ok and machine.storage.pending[1])
assert(machine.retry(1, generation) == true)
machine.state.cooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 1 }
machine.state.cooldownDuration = machine.makeDuration(0)
assert(machine.retry(1, generation) == true)
assert(machine.storage.pending[1] and not machine.active[1])
machine.state.cooldownDuration = machine.makeDuration(7)
assert(machine.retry(1, generation) == true)
assert(machine.active[1] and machine.storage.pending[1] == nil)
assert(machine.storage.activeSpellIDs[1] == 101)
assert(machine.storage.activeActionKeys[1] == "SPELL:101")
assert(machine.storage.activePublicUnits[1] == "party1")

-- Resolver/profile/environment/spec replacement cannot terminate an immutable
-- active transaction. Public cooldown completion still can.
machine.storage.configuredActionsByPriority = {}
machine.storage.configuredActionBySpellID = {}
machine.reconcile(1)
assert(machine.active[1] and machine.storage.activeSpellIDs[1] == 101)
machine.state.cooldownInfo = { isActive = false, isOnGCD = false, maxCharges = 1 }
machine.reconcile(1)
assert(not machine.active[1] and machine.storage.activeSpellIDs[1] == nil)

-- Event-driven reconciliation promotes pending work even when the scheduled
-- first arm observed nothing.
resetPriority(1)
ok, generation = machine.begin(1, 102, clicked, attempt("SPELL:102", 102))
assert(ok)
machine.state.cooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 1 }
machine.state.cooldownDuration = machine.makeDuration(6)
machine.reconcileAll()
assert(machine.active[1] and machine.storage.activeSpellIDs[1] == 102)

-- Mixed cooldown tables can contain secret numeric fields even though the
-- documented state booleans are public. Whole-table inaccessibility must not
-- hide those public fields.
resetPriority(1)
local mixedCooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 1 }
machine.state.inaccessible = mixedCooldownInfo
machine.state.cooldownInfo = mixedCooldownInfo
machine.state.cooldownDuration = machine.makeDuration(6)
ok, generation = machine.begin(1, 107, clicked, attempt("SPELL:107", 107))
assert(ok and machine.retry(1, generation))
assert(machine.active[1] and machine.storage.activeSpellIDs[1] == 107)
machine.state.inaccessible = nil

-- A GCD-only result is never shared and is cancelled after bounded public
-- confirmation rather than becoming an infinite pending transaction.
resetPriority(1)
machine.state.cooldownInfo = { isActive = true, isOnGCD = true, maxCharges = 1 }
ok, generation = machine.begin(1, 103, clicked, attempt("SPELL:103", 103))
assert(ok)
machine.retry(1, generation)
machine.setNow(.60)
machine.retry(1, generation)
machine.setNow(.61)
machine.retry(1, generation)
assert(machine.storage.pending[1] == nil and not machine.active[1])

-- An exhausted charged cure uses its charge Duration object and finishes when
-- a public usable charge returns.
resetPriority(2)
machine.state.cooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 2 }
local mixedChargeInfo = { currentCharges = 0, maxCharges = 2 }
machine.state.chargeInfo = mixedChargeInfo
machine.state.inaccessible = mixedChargeInfo
machine.state.chargeDuration = machine.makeDuration(9)
local chargedClicked = { CurrUnit = "party2", Decursive121ExpectedUnit = "party2" }
ok, generation = machine.begin(2, 202, chargedClicked, attempt("SPELL:202", 202, "party2"))
assert(ok and machine.retry(2, generation))
assert(machine.active[2] and machine.durations.charge > 0)
machine.state.inaccessible = nil
machine.state.chargeInfo = { currentCharges = 1, maxCharges = 2 }
machine.reconcile(2)
assert(not machine.active[2])

-- A charge spell that still has a usable charge never shares its background
-- recharge as if the curing action were unavailable.
resetPriority(2)
machine.state.cooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 2 }
machine.state.chargeInfo = { currentCharges = 1, maxCharges = 2 }
ok, generation = machine.begin(2, 203, chargedClicked, attempt("SPELL:203", 203, "party2"))
assert(ok)
machine.retry(2, generation)
machine.setNow(.60)
machine.retry(2, generation)
machine.setNow(.61)
machine.retry(2, generation)
assert(machine.storage.pending[2] == nil and not machine.active[2])

-- Clearing mutable resolver maps while pending does not lose the exact event
-- spell/action snapshot captured by the transaction.
resetPriority(3)
machine.setCombat(true)
ok, generation = machine.begin(3, 303, clicked, attempt("SPELL:303", 303))
assert(ok)
machine.storage.configuredActionsByPriority = {}
machine.D.profile = {
    CooldownOverlay121Enabled = true,
    CooldownOverlay121Numbers = false,
    EnvironmentKey = "PVP",
}
machine.state.cooldownInfo = { isActive = true, isOnGCD = false, maxCharges = 1 }
machine.state.cooldownDuration = machine.makeDuration(5)
machine.retry(3, generation)
assert(machine.active[3] and machine.storage.activeSpellIDs[3] == 303)
machine.setCombat(false)

-- A newer success supersedes older timers by monotonic generation.
resetPriority(1)
local _, oldGeneration = machine.begin(1, 104, clicked, attempt("SPELL:104", 104))
local _, newGeneration = machine.begin(1, 105, clicked, attempt("SPELL:105", 105))
assert(newGeneration > oldGeneration)
assert(machine.retry(1, oldGeneration) == false)
assert(machine.storage.pending[1].spellID == 105)

-- Unknown state expires at the hard bound and teardown-style invalidation makes
-- every already-scheduled callback inert.
machine.setNow(2.81)
machine.retry(1, newGeneration)
assert(machine.storage.pending[1] == nil)
local _, teardownGeneration = machine.begin(1, 106, clicked, attempt("SPELL:106", 106))
machine.setRunning(false)
machine.generations[1] = machine.generations[1] + 1
machine.storage.pending[1] = nil
assert(machine.retry(1, teardownGeneration) == false)

-- Production integration contracts that sit outside the extracted pure state
-- block: exact PreClick identity, event promotion, immediate gate sync,
-- fail-closed creation, clicked-unit exclusion, and teardown cleanup.
for _, required in ipairs({
    "actionKey = actionKey,",
    "aliasSpellIDs = aliasSpellIDs,",
    "publicUnit = publicUnit,",
    "managedCooldownDurationObjects.BeginPending(priority, spellID, targetMF, attempt)",
    "if pending then managedCooldownDurationObjects.RetryPending(priority, pending.generation) end",
    "if event == \"SPELL_UPDATE_COOLDOWN\" or event == \"SPELL_UPDATE_CHARGES\" then",
    "and currentPublicUnit == clickedPublicUnit",
    "and actionStillConfigured",
    "setPriorityGateActive(MF, priority, active, managedCooldownDurationObjects[priority])",
    "if not slotConfigured then",
    "managedCooldownDurationObjects.pending[priority] = nil",
    "managedCooldownDurationObjects.activeSpellIDs[priority] = nil",
}) do
    assert(source:find(required, 1, true), "missing cooldown integration contract: " .. required)
end
assert(not source:find("GetSpellCooldownDuration, spellID, true", 1, true))

-- Exercise the production clicked-exclusion/current-action gate directly.
local gateBegin = assert(source:find("local function setPriorityGateActive", 1, true))
local gateEnd = assert(source:find("refreshSharedPriorityCooldownGates = function", gateBegin, true))
local gateSource = source:sub(gateBegin, gateEnd - 1)
local gateHarness = [[
local activePriorityMUF = {}
local managedCooldownDurationObjects = {
    activePublicUnits = {},
    activeActionKeys = {},
    configuredActionsByPriority = {},
}
local D = {
    profile = { CooldownOverlay121Enabled = true, CooldownOverlay121Numbers = true },
    Is121SharedPriorityCooldownEnabled = function() return true end,
}
local function isAccessiblePublicValue() return true end
local function safe(_, callback, object, ...)
    callback(object, ...)
    return true
end
]] .. gateSource .. [[
return setPriorityGateActive, activePriorityMUF, managedCooldownDurationObjects
]]
local setGate, clickedByPriority, gateStorage = assert(loader(gateHarness, "cooldown-gate-test"))()
local function makeMF(unit)
    return {
        CurrUnit = unit,
        Decursive121ExpectedUnit = unit,
        Decursive121PriorityGateContainers = { [1] = {} },
        Decursive121PriorityGateHolders = {
            [1] = { SetAlpha = function(self, value) self.alpha = value end },
        },
        Decursive121PriorityCooldownBindings = {
            [1] = {
                SetDuration = function(self, value) self.duration = value end,
                SetEnabled = function(self, value) self.enabled = value end,
            },
        },
    }
end
local clickedMF = makeMF("party1")
local otherMF = makeMF("party2")
clickedByPriority[1] = clickedMF
gateStorage.activePublicUnits[1] = "party1"
gateStorage.activeActionKeys[1] = "SPELL:101"
gateStorage.configuredActionsByPriority[1] = { actionKey = "SPELL:101" }
setGate(clickedMF, 1, true, {})
assert(clickedMF.Decursive121PriorityGateHolders[1].alpha == 0)
setGate(otherMF, 1, true, {})
assert(otherMF.Decursive121PriorityGateHolders[1].alpha == 1)
clickedMF.Decursive121ExpectedUnit = "party3"
setGate(clickedMF, 1, true, {})
assert(clickedMF.Decursive121PriorityGateHolders[1].alpha == 1)
gateStorage.configuredActionsByPriority[1] = nil
clickedMF.Decursive121PriorityGateAppliedActive[1] = nil
setGate(clickedMF, 1, true, {})
assert(clickedMF.Decursive121PriorityGateHolders[1].alpha == 0)

io.write("PASS: Retail cooldown pending, event, GCD, charge, resolver, generation, expiry, gate and teardown regressions\n")
