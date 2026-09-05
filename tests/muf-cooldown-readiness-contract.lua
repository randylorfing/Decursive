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

local file = assert(io.open("ZDecursive/MUFs.lua", "rb"))
local source = file:read("*a")
file:close()

-- Append a test-only accessor to the unmodified module, keeping its real
-- timers, state transitions, generation guards, and presentation functions.
local access = [[
return {
  begin = BeginPendingCooldown,
  reconcile = ReconcileCooldowns,
  finish = FinishCooldown,
  attach = AttachCooldownGates,
  states = cooldownStates,
  pending = cooldownPending,
  pool = pool,
  result = OnPlayerSpellResult,
}
]]

local function Harness()
  local h = {now = 0, timers = {}, active = false, gcd = false, charges = nil, readable = true}
  local ns = {PACK = {mufs = {}, alerts = {}}}
  local opaque = setmetatable({}, {__index = function() error("duration object must remain opaque") end})
  h.duration = opaque
  GetTime = function() return h.now end
  h.combat = true
  h.ns = ns
  InCombatLockdown = function() return h.combat end
  issecretvalue = function(value) return value == h.secret end
  canaccessvalue = function(value) return value ~= h.secret end
  h.secret = {}
  h.mouseover = "party1"
  UnitIsUnit = function(left, right)
    Check(left == "mouseover", "keyboard identity is captured from mouseover")
    return right == h.mouseover
  end
  h.successCount, h.failureSounds = 0, 0
  ns.NotifyCureSucceeded = function(unit)
    h.successCount = h.successCount + 1
    h.successUnit = unit
  end
  ns.PlayCureFailureSound = function() h.failureSounds = h.failureSounds + 1 end
  C_Timer = {After = function(delay, callback)
    h.timers[#h.timers + 1] = {at = h.now + delay, callback = callback}
  end}
  C_Spell = {
    GetSpellCooldown = function(spellId)
      Check(spellId == 115450, "queries the successful spell")
      if not h.readable then return nil end
      return {isActive = h.active, isOnGCD = h.gcd, maxCharges = h.charges and 2 or 1}
    end,
    GetSpellCharges = function()
      if h.charges then return {currentCharges = h.charges.current, maxCharges = 2} end
    end,
    GetSpellCooldownDuration = function()
      if h.durationReady ~= false then return opaque end
    end,
    GetSpellChargeDuration = function()
      if h.durationReady ~= false then return opaque end
    end,
  }
  h.runtime = assert(load(source .. "\n" .. access, "@ZDecursive/MUFs.lua"))("ZDecursive", ns)
  local function Button()
    local holder = {alpha = 0}
    function holder:SetAlpha(value) self.alpha = value end
    local binding = {enabled = false}
    function binding:SetDuration(value)
      Check(value == opaque, "native duration is passed through unchanged")
      self.duration = value
    end
    function binding:SetEnabled(value) self.enabled = value end
    return {assigned = true, cooldownGates = {{actionKey = "spell:115450", holder = holder, bindings = {binding}}}}
  end
  h.owner = Button()
  h.follower = Button()
  h.owner.unit, h.follower.unit = "party1", "party2"
  h.runtime.pool[1] = h.owner
  h.runtime.pool[2] = h.follower
  h.pack = ns.PACK
  function h:Begin()
    self.runtime.begin(1, 115450, {actionKey = "spell:115450", targetBtn = self.owner, targetUnit = self.owner.unit})
  end
  function h:Keyboard()
    self.ns.BeginKeyboardCureAttempt({index = 1, spellId = 115450, baseId = 115451, actionKey = "spell:115450"})
  end
  function h:Result(event, unit, spellId)
    self.runtime.result(event or "UNIT_SPELLCAST_SUCCEEDED", unit or "player", spellId or 115450)
  end
  function h:Advance(to)
    while true do
      local nextIndex
      for i, timer in ipairs(self.timers) do
        if timer.at <= to and (not nextIndex or timer.at < self.timers[nextIndex].at) then nextIndex = i end
      end
      if not nextIndex then break end
      local timer = table.remove(self.timers, nextIndex)
      self.now = timer.at
      timer.callback()
    end
    self.now = to
  end
  function h:Event()
    self.runtime.reconcile()
  end
  function h:Visible(button)
    local gate = (button or self.follower).cooldownGates[1]
    return gate.holder.alpha == 1 and gate.bindings[1].enabled and gate.bindings[1].duration == opaque
  end
  return h
end

local cases = {}
local function Case(name, run) cases[#cases + 1] = {name = name, run = run} end

Case("countdown without darkness", function()
  local h = Harness()
  local defaults = {}
  assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", defaults)
  h.pack.alerts = defaults.MakePack("RAID").alerts
  Check(h.pack.alerts.cooldownOpacity == 0, "Raid inherits zero darkness")
  h.active = true
  h:Begin()
  h:Event()
  Check(h:Visible(), "zero darkness keeps the real duration countdown active")
  h.pack.alerts.cooldownNumbers = false
  h:Event()
  Check(not h:Visible(), "explicitly disabling numbers remains supported")
end)

Case("delayed cooldown event", function()
  local h = Harness()
  h:Begin()
  h:Advance(0.55)
  Check(not h:Visible(), "no countdown before the real cooldown is known")
  h:Advance(0.8)
  h.active = true
  h:Event()
  Check(h:Visible(), "late real cooldown must shade and count down on the afflicted follower")
  Check(h.owner.cooldownGates[1].holder.alpha == 0, "clear-cleansed setting still suppresses the clicked unit")
end)

Case("late GCD-to-cooldown transition", function()
  local h = Harness()
  h.active = true
  h.gcd = true
  h:Begin()
  h:Advance(1)
  Check(not h:Visible(), "GCD alone never starts the dispel overlay")
  h.gcd = false
  h:Event()
  Check(h:Visible(), "GCD samples must not cancel later real cooldown discovery")
end)

Case("stale last charge", function()
  local h = Harness()
  h.active = true
  h.charges = {current = 1}
  h:Begin()
  h:Advance(0.12)
  Check(not h:Visible(), "remaining charge does not shade units")
  h.charges.current = 0
  h:Event()
  Check(h:Visible(), "last-charge update must still start the recharge countdown")
end)

Case("deadline sample", function()
  local h = Harness()
  h.readable = false
  h:Begin()
  h:Advance(2.79)
  h.readable = true
  h.active = true
  h:Advance(2.8)
  Check(h:Visible(), "the final scheduled sample must query readiness before expiring")
end)

Case("no cooldown remains bounded", function()
  local h = Harness()
  h:Begin()
  h:Advance(2.8)
  Check(not h:Visible() and h.runtime.pending[1] == nil and h.runtime.states[1] == nil, "no-cooldown attempt expires without a fabricated timer")
  h.active = true
  h:Event()
  Check(not h:Visible(), "an unrelated later cooldown does not resurrect an expired attempt")
end)

Case("charge remains usable", function()
  local h = Harness()
  h.active = true
  h.charges = {current = 1}
  h:Begin()
  h:Advance(2.8)
  Check(not h:Visible() and h.runtime.pending[1] == nil, "usable remaining charges never display a false cooldown")
end)

Case("stale timer generation", function()
  local h = Harness()
  h:Begin()
  h:Advance(0.4)
  h:Begin()
  h:Advance(2.8)
  Check(h.runtime.pending[1] ~= nil, "the older attempt's deadline cannot cancel the newer attempt")
  h.active = true
  h:Event()
  Check(h:Visible(), "new generation can still discover its cooldown")
  h:Advance(4)
  Check(h:Visible(), "leftover retry callbacks cannot clear an active cooldown")
end)

Case("secret charge readiness", function()
  local h = Harness()
  h.active = true
  h.charges = {current = h.secret}
  h:Begin()
  h:Advance(1)
  Check(not h:Visible(), "inaccessible charges defer without interpreting the value")
  h.charges.current = 0
  h:Event()
  Check(h:Visible(), "public zero charges complete deferred discovery")
end)

Case("active cooldown completion", function()
  local h = Harness()
  h.active = true
  h:Begin()
  h:Advance(0)
  Check(h:Visible(), "ready cooldown displays immediately")
  h.active = false
  h:Event()
  Check(not h:Visible() and h.runtime.states[1] == nil, "completion clears shading and countdown")
end)

Case("duration readiness", function()
  local h = Harness()
  h.active = true
  h.durationReady = false
  h:Begin()
  h:Advance(1)
  Check(not h:Visible(), "missing native duration does not create a guessed countdown")
  h.durationReady = true
  h:Advance(1.8)
  Check(h:Visible(), "timer fallback recovers once the duration becomes available")
end)

Case("unknown state expires", function()
  local h = Harness()
  h.readable = false
  h:Begin()
  h:Advance(2.8)
  Check(h.runtime.pending[1] == nil and not h:Visible(), "unavailable API state cannot leave an indefinite pending timer")
end)

Case("keyboard success discovers the real delayed cooldown", function()
  local h = Harness()
  h:Keyboard()
  Check(h.runtime.pending[1] == nil, "key press alone cannot invent a cooldown")
  h:Advance(0.2)
  h:Result()
  Check(h.successCount == 1 and h.successUnit == "party1", "success belongs to the captured friendly MUF")
  Check(h.owner.statusOk == true, "captured MUF receives successful cast feedback")
  Check(h.runtime.pending[1] ~= nil and not h:Visible(), "success waits for actual cooldown readiness")
  h:Advance(0.9)
  h.active = true
  h:Event()
  Check(h:Visible(), "delayed keyboard cooldown reaches other afflicted units")
  Check(not h:Visible(h.owner), "clear cleansed suppresses the actual keyboard target")
  Check(h.runtime.states[1].targetBtn == h.owner, "cooldown retains the captured target")
end)

Case("keyboard targetless success and failure are safe", function()
  local h = Harness()
  h.mouseover = "friendly-outside-roster"
  h:Keyboard()
  h:Result()
  Check(h.successCount == 1 and h.successUnit == nil, "targetless success notification has no guessed unit")
  Check(h.owner.statusOk == nil and h.follower.statusOk == nil, "targetless success cannot mark an unrelated MUF")
  h.active = true
  h:Advance(0)
  Check(h:Visible(h.owner) and h:Visible(), "targetless shared cooldown can shade all matching afflicted units")
  Check(h.runtime.states[1].targetBtn == nil, "targetless cooldown stays targetless")
  h.runtime.finish(1)
  h.active = false
  h:Keyboard()
  h:Result("UNIT_SPELLCAST_FAILED")
  Check(h.failureSounds == 1, "targetless failure can report the failed attempt")
  Check(h.runtime.pending[1] == nil and h.runtime.states[1] == nil, "failed keyboard cast creates no cooldown")
  Check(h.owner.statusOk == nil and h.follower.statusOk == nil, "targetless failure cannot mark an unrelated MUF")
end)

Case("keyboard ignores unrelated and secret cast results", function()
  local h = Harness()
  h:Keyboard()
  h:Result("UNIT_SPELLCAST_SUCCEEDED", "party2", 115450)
  h:Result("UNIT_SPELLCAST_SUCCEEDED", "player", 99999)
  h:Result("UNIT_SPELLCAST_SUCCEEDED", h.secret, 115450)
  h:Result("UNIT_SPELLCAST_SUCCEEDED", "player", h.secret)
  Check(h.successCount == 0 and h.runtime.pending[1] == nil, "unrelated or opaque results cannot start cooldown")
  h:Result()
  Check(h.successCount == 1 and h.runtime.pending[1] ~= nil, "unrelated results preserve the matching attempt")
  h:Result()
  Check(h.successCount == 1, "duplicate success cannot consume an attempt twice")
end)

Case("keyboard target remains the unit captured before mouseover moves", function()
  local h = Harness()
  h:Keyboard()
  h.mouseover = "party2"
  h:Result()
  Check(h.successUnit == "party1", "cast result does not reread the moved mouseover")
  Check(h.owner.statusOk == true and h.follower.statusOk == nil, "only captured target receives feedback")
  h.active = true
  h:Advance(0)
  Check(not h:Visible(h.owner) and h:Visible(), "clear cleansed applies to captured unit, not new hover")
end)

Case("recycled keyboard target is discarded before the cast result", function()
  local h = Harness()
  h:Keyboard()
  h.owner.unit = "party3"
  h:Result()
  Check(h.successUnit == nil and h.owner.statusOk == nil, "recycled MUF cannot receive another unit's success")
  h.active = true
  h:Advance(0)
  Check(h.runtime.states[1].targetBtn == nil, "recycled target falls back to targetless cooldown")
  Check(h:Visible(h.owner) and h:Visible(), "recycled button is not incorrectly treated as cleansed")
end)

Case("unassigned keyboard target is discarded before failure", function()
  local h = Harness()
  h:Keyboard()
  h.owner.assigned = false
  h:Result("UNIT_SPELLCAST_FAILED")
  Check(h.owner.statusOk == nil, "retired MUF cannot receive stale failure feedback")
  Check(h.failureSounds == 1, "failed cast still reports its result")
  Check(h.runtime.pending[1] == nil, "retired-target failure creates no cooldown")
end)

Case("keyboard cooldown respects sharing and clear cleansed settings", function()
  for _, shared in ipairs({true, false}) do
    for _, clearClicked in ipairs({true, false}) do
      local h = Harness()
      h.pack.mufs.shareCooldown = shared
      h.pack.mufs.clearCleansedImmediately = clearClicked
      h:Keyboard()
      h:Result()
      h.active = true
      h:Advance(0)
      Check(h:Visible(h.owner) == not clearClicked, "clicked cooldown follows clear cleansed setting")
      Check(h:Visible() == shared, "other units follow shared cooldown setting")
    end
  end
  local h = Harness()
  h.pack.mufs.shareCooldown = false
  h.pack.mufs.clearCleansedImmediately = false
  h.mouseover = "outside-roster"
  h:Keyboard()
  h:Result()
  h.active = true
  h:Advance(0)
  Check(not h:Visible(h.owner) and not h:Visible(), "targetless nonshared cooldown cannot shade unrelated units")
end)

Case("inaccessible keyboard identities degrade to targetless results", function()
  for _, identityMode in ipairs({"secret-result", "error", "secret-unit", "missing-api"}) do
    local h = Harness()
    if identityMode == "secret-result" then
      UnitIsUnit = function() return h.secret end
    elseif identityMode == "error" then
      UnitIsUnit = function() error("identity temporarily unavailable") end
    elseif identityMode == "secret-unit" then
      h.owner.unit = h.secret
    else
      UnitIsUnit = nil
    end
    h:Keyboard()
    h:Result()
    Check(h.successCount == 1 and h.successUnit == nil, identityMode .. " preserves safe targetless success")
    Check(h.owner.statusOk == nil and h.follower.statusOk == nil, identityMode .. " never guesses a MUF")
    h.active = true
    h:Advance(0)
    Check(h:Visible(h.owner) and h:Visible(), identityMode .. " still permits native shared cooldown display")
  end
end)

Case("expired keyboard attempt cannot attribute a later cast", function()
  local h = Harness()
  h:Keyboard()
  h:Advance(1.6)
  h:Result()
  Check(h.successCount == 0 and h.runtime.pending[1] == nil, "expired keyboard press cannot claim an unrelated later success")
  h:Keyboard()
  h:Result("UNIT_SPELLCAST_FAILED")
  Check(h.owner.statusOk == false and h.failureSounds == 1, "fresh failed keyboard cast marks its target")
  Check(h.runtime.pending[1] == nil, "fresh failure still creates no cooldown")
end)

Case("fourth manual cure cooldown", function()
  local h = Harness()
  h.combat = false
  h.pack.colors = {}
  h.ns.GetKnownCures = function()
    return {
      {spellId = 1, name = "Magic cure", types = {"magic"}},
      {spellId = 2, name = "Curse cure", types = {"curse"}},
      {spellId = 3, name = "Poison cure", types = {"poison"}},
      {spellId = 115450, name = "Fourth cure", types = {"disease"}},
    }
  end
  h.ns.SafeNativeSetUnit = function(container, unit)
    Check(not h.combat and unit == "party2", "native gates bind only outside combat")
    container.unit = unit
    return true
  end
  local function Frame()
    local frame = {}
    function frame:SetAllPoints() end
    function frame:ClearAllPoints() end
    function frame:SetPoint() end
    function frame:SetColorTexture() end
    function frame:SetTextColor() end
    function frame:SetFrameLevel() end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetUnit(unit) self.unit = unit end
    function frame:CreateTexture() return Frame() end
    function frame:CreateFontString() return Frame() end
    function frame:AddAuraSlot(key, filter, options)
      local slot = Frame()
      options.initializeFrame(slot)
      self.slots = self.slots or {}
      self.slots[key] = {filter = filter, include = options.candidateFilters.includeDispelTypes, slot = slot}
      return slot
    end
    return frame
  end
  CreateFrame = Frame
  C_DurationUtil = {CreateDurationTextBinding = function()
    local binding = {}
    function binding:SetFontString() end
    function binding:SetDuration(value)
      Check(value == h.duration, "fourth cure uses the native duration")
      self.duration = value
    end
    function binding:SetEnabled(value) self.enabled = value end
    return binding
  end}
  h.follower.inner = {}
  h.follower.GetFrameLevel = function() return 1 end
  Check(h.runtime.attach(h.follower, h.pack, "party2"), "manual cure gates configure")
  local gate = h.follower.cooldownGates[4]
  Check(gate and gate.container.slots["cooldown-main"].include.Disease, "fourth cure has its own afflicted-unit gate")
  h.combat = true
  h.active = true
  h.runtime.begin(4, 115450, {actionKey = "spell:115450", targetBtn = h.owner, targetUnit = h.owner.unit})
  h:Advance(0)
  Check(gate.holder.alpha == 1 and gate.bindings[1].enabled, "fourth manual spell shows its cooldown in combat")
  h.active = false
  h:Event()
  Check(gate.holder.alpha == 0 and not gate.bindings[1].enabled, "cooldown events also clear the fourth spell")
  h.combat = false
  h.ns.GetKnownCures = function() return {} end
  Check(h.runtime.attach(h.follower, h.pack, "party2"), "shorter cure catalog refreshes")
  Check(h.follower.cooldownGates[4] == nil and not gate.holder.shown, "removed higher-priority gates are retired")
  C_DurationUtil = nil
end)

local failures = {}
for _, case in ipairs(cases) do
  local ok, message = pcall(case.run)
  if not ok then failures[#failures + 1] = case.name .. ": " .. tostring(message) end
end
Check(#failures == 0, table.concat(failures, "\n"))
io.write("muf-cooldown-readiness-contract: " .. tostring(#cases) .. " cases ok\n")
