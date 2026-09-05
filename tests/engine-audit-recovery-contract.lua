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

-- Exercise the production coordinator and its real BindCarrier lifecycle. The
-- native mock models observable configuration only; it never supplies aura data.
local root = (... and ... ~= "") and ... or "."
local cases = 0
local function Check(value, message)
  if not value then error(message, 2) end
end
local function Equal(actual, expected, message)
  if actual ~= expected then
    error(message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
  end
end

local current
InCombatLockdown = function() return current.combat end
issecretvalue = function() return false end
C_EventUtils = {IsEventValid = function() return true end}
C_Timer = {After = function(delay, callback)
  current.timers[#current.timers + 1] = {delay = delay, callback = callback}
end}

local function Mutation()
  current.mutations = current.mutations + 1
  if current.combat then
    current.combatMutations = current.combatMutations + 1
    error("native configuration mutation during combat")
  end
end

local function NewSlot()
  local slot = {}
  function slot:EnableMouse(value) Mutation(); self.mouse = value end
  function slot:SetMouseClickEnabled(value) Mutation(); self.click = value end
  function slot:SetMouseMotionEnabled(value) Mutation(); self.motion = value end
  return slot
end

local function NewContainer(parent)
  Mutation()
  local container = {parent = parent, slots = {}, addCounts = {}, filters = {}, candidates = {}}
  current.containers[#current.containers + 1] = container
  function container:SetAllPoints() Mutation() end
  function container:EnableMouse(value) Mutation(); self.mouse = value end
  function container:SetMouseClickEnabled(value) Mutation(); self.click = value end
  function container:SetMouseMotionEnabled(value) Mutation(); self.motion = value end
  function container:SetEnabled(value) Mutation(); self.enabled = value end
  function container:Show() Mutation(); self.shown = true end
  function container:Hide() Mutation(); self.shown = false end
  function container:SetUnit(unit)
    Mutation()
    Check(type(unit) == "string" and unit ~= "", "native SetUnit needs a public nonempty unit")
    self.unit = unit
  end
  function container:AddAuraSlot(key, filter, options)
    Mutation()
    self.addCounts[key] = (self.addCounts[key] or 0) + 1
    self.filters[key] = filter
    self.candidates[key] = options.candidateFilters
    local slot = NewSlot()
    self.slots[key] = slot
    options.initializeFrame(slot)
    return slot
  end
  function container:SetAuraSlotFilterString(key, filter)
    Mutation(); self.filters[key] = filter
  end
  function container:SetAuraSlotCandidateFilters(key, candidates)
    Mutation()
    if self.failCandidates then error("injected native candidate refresh failure") end
    self.candidates[key] = candidates
  end
  return container
end

CreateFrame = function(kind, _name, parent)
  if kind == "AuraContainer" then return NewContainer(parent) end
  local frame = {events = {}}
  function frame:SetScript(_event, callback) self.callback = callback end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  return frame
end

local function Fixture(outcomes)
  local fixture = {
    combat = false, mutations = 0, combatMutations = 0, timers = {}, timerHead = 1,
    containers = {}, diagnostics = {}, outcomes = outcomes or {}, units = {}, owners = {},
    refreshes = {}, initializeOutcomes = {}, pack = {advanced = {autoAuraTrace = false}},
  }
  current = fixture
  local ns = {
    addon = {GetAppliedEnvironmentPack = function() return fixture.pack end},
    HasActiveAddonRestriction = function() return false end,
    DiagnosticRecord = function(kind, fields)
      fixture.diagnostics[#fixture.diagnostics + 1] = {kind = kind, fields = fields}
    end,
    GetDetectionSlots = function()
      return {
        {key = "poison", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
          dispelType = "Poison", priority = 1,
          candidateFilters = {includeDispelTypes = {Poison = true}}},
        {key = "magic", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
          dispelType = "Magic", priority = 2,
          candidateFilters = {includeDispelTypes = {Magic = true}}},
      }
    end,
    SafeNativeSetUnit = function(container, unit)
      if fixture.combat then return false, "DEFERRED_COMBAT" end
      local ok = pcall(container.SetUnit, container, unit)
      return ok, ok and "ASSIGNED" or "UNIT_ASSIGN_FAILED"
    end,
  }
  assert(loadfile(root .. "/ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
  fixture.engine = ns.DetectionEngine
  for _, name in ipairs({"MUFs", "Alerts", "LiveList"}) do
    local bankName = name
    fixture.owners[name] = {}
    fixture.units[name] = "player"
    fixture.engine:RegisterConsumer(name, function()
      fixture.refreshes[bankName] = (fixture.refreshes[bankName] or 0) + 1
      local outcome = fixture.outcomes[bankName]
      if outcome and outcome ~= "SUCCESS" then return false, outcome, 1 end
      local _, ok, status = fixture.engine:BindCarrier(bankName, fixture.owners[bankName],
        fixture.units[bankName], function(slot)
          slot.painted = true
          local presentationOutcome = fixture.initializeOutcomes[bankName]
          if presentationOutcome then return false, presentationOutcome end
        end, fixture.owners[bankName])
      return ok, status, 1
    end)
  end
  function fixture:Record(bank) return self.engine.carrierByOwner[self.owners[bank]] end
  function fixture:RunNext()
    local timer = self.timers[self.timerHead]
    Check(timer, "a queued timer must exist")
    self.timerHead = self.timerHead + 1
    timer.callback()
  end
  function fixture:Drain(maximum)
    local count = 0
    while self.timerHead <= #self.timers do
      count = count + 1
      Check(count <= (maximum or 30), "retry queue must be bounded")
      self:RunNext()
    end
    return count
  end
  function fixture:ReadyCount()
    local count = 0
    for _, event in ipairs(self.diagnostics) do
      if event.kind == "ENGINE_STATE" and event.fields.current == "READY" then count = count + 1 end
    end
    return count
  end
  function fixture:Healthy(bank, unit)
    local record = self:Record(bank)
    Check(record, bank .. " has a carrier")
    Equal(record.unit, unit or self.units[bank], bank .. " logical unit")
    Equal(record.container.unit, unit or self.units[bank], bank .. " native unit")
    Check(record.active and record.container.enabled and record.container.shown,
      bank .. " native provider remains active and visible")
    Check(not record.quarantined, bank .. " healthy bank is not quarantined")
    Check(record.configuredGeneration > 0, bank .. " has configured native providers")
    for _, key in ipairs({"poison", "magic"}) do
      Check(record.container.slots[key] and record.container.slots[key].painted,
        bank .. " has initialized " .. key .. " presentation")
    end
  end
  function fixture:NoDuplicates()
    for _, container in ipairs(self.containers) do
      for _, count in pairs(container.addCounts) do
        Equal(count, 1, "recovery reuses each existing native slot")
      end
    end
  end
  function fixture:Converged()
    Equal(self.engine.state, "READY", "successful retry converges")
    Check(not self.engine.pending and not self.engine.retryScheduled,
      "complete transaction has no dirty state or pending retry")
    for _, bank in ipairs({"MUFs", "Alerts", "LiveList"}) do self:Healthy(bank) end
    self:NoDuplicates()
    Equal(self.combatMutations, 0, "no native mutation was attempted during combat")
  end
  return fixture
end

local function Case(name, callback)
  callback()
  cases = cases + 1
  io.write("PASS " .. name .. "\n")
end

Case("fresh repeated failure replaces a stale retry without losing recovery", function()
  local f = Fixture()
  Check(f.engine:Start(), "baseline starts")
  f.outcomes.Alerts = "FAILURE"
  Check(not f.engine:Refresh("FIRST_FAILURE"), "first failure rejected")
  Check(f.engine.retryScheduled, "first failure schedules retry")
  Check(not f.engine:Refresh("INTERVENING_SPELLS_CHANGED"), "second failure rejected")
  Check(f.engine.retryScheduled, "fresh failure retains a replacement retry")
  local generation = f.engine.desiredGeneration
  f:RunNext()
  Equal(f.engine.desiredGeneration, generation, "stale timer does not reconcile")
  Check(f.engine.retryScheduled, "stale timer cannot clear the replacement wakeup")
  f.outcomes.Alerts = nil
  f:Drain()
  f:Converged()
end)

Case("persistent failure retries more than once and eventually records bounded exhaustion", function()
  local f = Fixture()
  Check(f.engine:Start(), "baseline starts")
  f.outcomes.Alerts = "FAILURE"
  Check(not f.engine:Refresh("PERSISTENT_FAILURE"), "failure rejected")
  local timers = f:Drain()
  Check(timers > 1, "failure in the first retry schedules another retry")
  Check(f.engine.retryExhausted and not f.engine.retryScheduled and f.engine.pending,
    "bounded exhaustion is explicit while unfinished work remains dirty")
  Check(f.engine.state ~= "READY", "exhaustion never reports READY")
  f:Healthy("MUFs")
  f.outcomes.Alerts = nil
  Check(f.engine:Refresh("FAILURE_CLEARED"), "a new event restarts after retry exhaustion")
  f:Converged()
end)

for _, outcome in ipairs({"DEFERRED_RESTRICTED", "FAILURE"}) do
  local audioOutcome = outcome
  Case("startup visuals survive audio-only " .. audioOutcome, function()
    local f = Fixture({Alerts = audioOutcome})
    local ok, status = f.engine:Start()
    Check(not ok, "audio failure does not commit the global transaction")
    Equal(status, audioOutcome, "startup preserves the audio result")
    Equal(f:ReadyCount(), 0, "partial startup never temporarily reports READY")
    f:Healthy("MUFs")
    f:Healthy("LiveList")
    Check(f.engine.pending and f.engine.retryScheduled, "audio-only failure retains recovery")
    f.outcomes.Alerts = nil
    f:Drain()
    f:Converged()
  end)
  Case("rebound visuals survive audio-only " .. audioOutcome, function()
    local f = Fixture()
    Check(f.engine:Start(), "baseline starts")
    local readyBefore = f:ReadyCount()
    local carrierBefore = f:Record("MUFs")
    f.units.MUFs = "party1"
    f.outcomes.Alerts = audioOutcome
    local ok, status = f.engine:Refresh("ROSTER_WITH_AUDIO_UNAVAILABLE")
    Check(not ok, "audio failure does not commit the global transaction")
    Equal(status, audioOutcome, "rebind preserves the audio result")
    Equal(f:ReadyCount(), readyBefore, "partial rebind never temporarily reports READY")
    Equal(f:Record("MUFs"), carrierBefore, "rebind keeps the MUF carrier")
    f:Healthy("MUFs", "party1")
    f:Healthy("LiveList")
    Check(f.engine.pending and f.engine.retryScheduled, "partial rebind retains recovery")
    f.outcomes.Alerts = nil
    f:Drain()
    f:Converged()
  end)
end

Case("all failed banks are quarantined while healthy banks stay active", function()
  local f = Fixture()
  Check(f.engine:Start(), "baseline starts")
  f.outcomes.Alerts, f.outcomes.LiveList = "FAILURE", "FAILURE"
  local ok, status = f.engine:Refresh("MULTIPLE_BANK_FAILURES")
  Check(not ok and status == "FAILURE", "multiple failure has hard aggregate outcome")
  for _, bank in ipairs({"Alerts", "LiveList"}) do
    local record = f:Record(bank)
    Check(record.quarantined and not record.container.enabled and not record.container.shown,
      bank .. " failed bank is disabled and quarantined")
  end
  f:Healthy("MUFs")
  f.outcomes.Alerts = nil
  f:RunNext()
  f:Healthy("Alerts")
  f:Healthy("MUFs")
  Check(f:Record("LiveList").quarantined and not f:Record("LiveList").container.enabled,
    "still-failed bank remains isolated as another bank recovers")
  Check(f.engine.state ~= "READY" and f.engine.retryScheduled,
    "remaining bank failure retains recovery without READY")
  f.outcomes.LiveList = nil
  f:Drain()
  f:Converged()
end)

for _, deferred in ipairs({"DEFERRED_RESTRICTED", "DEFERRED_COMBAT"}) do
  for _, hardBank in ipairs({"Alerts", "LiveList"}) do
    local deferredOutcome, failedBank = deferred, hardBank
    Case("mixed outcomes retain hard failure for " .. failedBank .. " plus " .. deferredOutcome, function()
      local f = Fixture()
      Check(f.engine:Start(), "baseline starts")
      local deferredBank = failedBank == "Alerts" and "LiveList" or "Alerts"
      f.outcomes[failedBank], f.outcomes[deferredBank] = "FAILURE", deferredOutcome
      local ok, status = f.engine:Refresh("MIXED_CONSUMER_OUTCOMES")
      Check(not ok and status == "FAILURE", "hard failure wins regardless of consumer order")
      local failed = f:Record(failedBank)
      Check(failed.quarantined and not failed.container.enabled and not failed.container.shown,
        "hard-failed bank is isolated even when another bank defers")
      Equal(f.engine.consumers[failedBank].status, "FAILURE", "failed bank retains its own outcome")
      Equal(f.engine.consumers[deferredBank].status, deferredOutcome,
        "deferred bank retains its independent outcome")
      Check(f.engine.consumers[deferredBank].deferred, "deferred bank carries a recovery marker")
      f:Healthy("MUFs")
      Check(f.engine.pending and f.engine.retryScheduled, "mixed result retains recovery")
      f.outcomes[failedBank], f.outcomes[deferredBank] = nil, nil
      f:Drain()
      f:Converged()
    end)
  end
end

Case("combat prevents native mutations during queued recovery and rebind", function()
  local f = Fixture()
  Check(f.engine:Start(), "baseline starts")
  f.outcomes.Alerts = "FAILURE"
  Check(not f.engine:Refresh("FAILURE_BEFORE_COMBAT"), "failure schedules recovery")
  f.combat = true
  local mutationsBefore = f.mutations
  local refreshesBefore = f.refreshes.MUFs
  f.units.MUFs = "party2"
  f.engine:OnEvent("PLAYER_REGEN_DISABLED")
  local ok, status = f.engine:Refresh("ROSTER_IN_COMBAT")
  Check(not ok and status == "DEFERRED_COMBAT", "combat refresh is deferred")
  f:Drain()
  Equal(f.mutations, mutationsBefore, "combat timer/refresh never enters native setters")
  Equal(f.refreshes.MUFs, refreshesBefore, "combat recovery never prepares consumers")
  Equal(f:Record("MUFs").container.unit, "player", "combat preserves last complete binding")
  f.outcomes.Alerts = nil
  f.combat = false
  f.engine:OnEvent("PLAYER_REGEN_ENABLED")
  f:Drain()
  f:Converged()
  f:Healthy("MUFs", "party2")
end)

Case("a presentation deferral cannot mask a native provider hard failure", function()
  local f = Fixture()
  Check(f.engine:Start(), "baseline starts")
  local failed = f:Record("MUFs")
  failed.container.failCandidates = true
  f.initializeOutcomes.MUFs = "DEFERRED_RESTRICTED"
  -- A roster rebind requires native candidate refresh rather than provider reuse.
  f.units.MUFs = "party1"
  local ok, status = f.engine:Refresh("MIXED_NATIVE_AND_PRESENTATION_FAILURE")
  Check(not ok and status == "FAILURE", "native provider hard failure wins over paint deferral")
  Check(failed.quarantined and not failed.container.enabled and not failed.container.shown,
    "native provider rejection is quarantined despite presentation deferral")
  f:Healthy("Alerts")
  f:Healthy("LiveList")
  failed.container.failCandidates = nil
  f.initializeOutcomes.MUFs = nil
  f:Drain()
  f:Converged()
end)

io.write("engine audit recovery contract: " .. cases .. " cases passed\n")
