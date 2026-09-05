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


local function Empty(engine, name)
  engine:RegisterConsumer(name, function() return true, "SUCCESS", 0 end)
end
local function Fixture()
  combat, restriction, deferNativeAssignment = false, false, false
  timerQueue = {}
  local ns, pack = NewNamespace()
  local engine = LoadEngine(ns)
  local owner = {}
  local desiredUnit = "player"
  engine:RegisterConsumer("MUFs", function()
    local container, ok, status = engine:BindCarrier("MUFs", {}, desiredUnit, function() end, owner)
    return ok, status, 1
  end)
  Empty(engine, "Alerts")
  Empty(engine, "LiveList")
  Check(engine:Start(), "fixture starts with active native carrier")
  return engine, owner, function(unit) desiredUnit = unit end
end

local engine, owner = Fixture()
local liveOwner = {}
local function LiveConsumer()
  local container, ok, status = engine:BindCarrier("LiveList", {}, "player", function() end, liveOwner)
  return ok, status, 1
end
engine:RegisterConsumer("LiveList", LiveConsumer)
Check(engine:Refresh("ENABLE_LIVE_LIST"), "second bank starts")
engine:RegisterConsumer("Alerts", function() return false, "FAILURE", 0 end)
engine:RegisterConsumer("LiveList", function() return false, "FAILURE", 1 end)
Check(not engine:Refresh("TWO_CONSUMERS_FAIL"), "failed transaction rejected")
local record = engine.carrierByOwner[liveOwner]
io.write("two failures: LiveList available=" .. tostring(engine.consumers.LiveList.available) ..
  " enabled=" .. tostring(record.container.enabled) .. " quarantined=" .. tostring(record.quarantined) .. "\n")
Check(record.container.enabled == false and record.quarantined == true, "every failed consumer bank must be quarantined")
