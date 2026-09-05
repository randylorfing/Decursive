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


local countNS = {}
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", countNS)
local count = 2
local countError = false
C_Item = {GetItemCount = function(item, bank, uses, reagent, account)
  Check(item == 269586 or item == 248486, "signature samples both inventory-backed qualities")
  Check(not bank and not uses and not reagent and not account, "signature uses carried-item counts only")
  if item == 248486 then return 0 end
  if countError then error("unavailable item count") end
  return count
end}
Equal(countNS.GetDetectionItemActionSignature(), "269586:2:0|248486:0:0", "public count signature includes both qualities")
count = 0
Equal(countNS.GetDetectionItemActionSignature(), "269586:0:0|248486:0:0", "zero is a known empty inventory")
count = secretBoolean
Equal(countNS.GetDetectionItemActionSignature(), nil, "secret count is unknown, not zero")
countError = true
Equal(countNS.GetDetectionItemActionSignature(), nil, "API failure is unknown, not zero")
countError, count = false, 2

local ns = NewNamespace()
ns.SOUL_LINK_ITEM_ID = countNS.SOUL_LINK_ITEM_ID
ns.IsSoulLinkItemID = countNS.IsSoulLinkItemID
ns.GetDetectionItemActionSignature = countNS.GetDetectionItemActionSignature
local engine = LoadEngine(ns)
for _, name in ipairs({"MUFs", "Alerts", "LiveList"}) do
  engine:RegisterConsumer(name, function() return true, "SUCCESS", 0 end)
end
Check(engine:Start(), "engine starts with public item state")
local function Drain()
  local callbacks = timerQueue
  timerQueue = {}
  for i = 1, #callbacks do callbacks[i]() end
end
Drain()
local generation = engine.refreshGeneration
local invalidations = ns.invalidations or 0
for i = 1, 100 do
  engine:OnEvent("GET_ITEM_INFO_RECEIVED", 10000 + i, true)
  engine:OnEvent("ITEM_DATA_LOAD_RESULT", 10000 + i, true)
  engine:OnEvent("ITEM_COUNT_CHANGED", 10000 + i, 5)
  Drain()
end
Equal(engine.refreshGeneration, generation, "unrelated item events do not reconcile")
Equal(ns.invalidations or 0, invalidations, "unrelated item events preserve cure/click cache")
engine:OnEvent("GET_ITEM_INFO_RECEIVED", secretBoolean, true)
Equal(#timerQueue, 0, "nonpublic item IDs are ignored without comparison")
engine:OnEvent("BAG_UPDATE_DELAYED")
engine:OnEvent("BAG_UPDATE_DELAYED")
Equal(#timerQueue, 1, "broad bag events share a single deferred public sample")
Drain()
Equal(engine.refreshGeneration, generation, "unchanged relevant count skips reconciliation")

count = 1
engine:OnEvent("ITEM_COUNT_CHANGED", 269586, 1)
engine:OnEvent("ITEM_DATA_LOAD_RESULT", 269586, true)
Equal(#timerQueue, 1, "relevant item changes coalesce")
Drain()
Equal(engine.refreshGeneration, generation + 1, "changed count refreshes all consumers once")
Equal(ns.invalidations or 0, invalidations + 1, "changed count invalidates installed action model")
engine:OnEvent("GET_ITEM_INFO_RECEIVED", 269586, false)
Equal(#timerQueue, 0, "failed item load does not refresh")
engine:OnEvent("BAG_UPDATE_DELAYED")
Drain()
Equal(engine.refreshGeneration, generation + 1, "successful commit remembers changed count")

combat, count = true, 0
engine:OnEvent("ITEM_COUNT_CHANGED", 269586, 0)
Drain()
Equal(engine.refreshGeneration, generation + 1, "item change cannot apply during combat")
Check(engine.pending, "combat item change retains recovery")
combat = false
Check(engine:Recover("ITEM_REGEN"), "regen applies inventory change")
Equal(forbiddenMutations, 0, "no native topology mutation in combat")

generation = engine.refreshGeneration
count = secretBoolean
engine:OnEvent("BAG_UPDATE_DELAYED")
Drain()
Check(engine.refreshGeneration > generation, "unknown count falls back to conservative refresh")
count = 0
engine:OnEvent("BAG_UPDATE_DELAYED")
Drain()
generation = engine.refreshGeneration
engine:OnEvent("BAG_UPDATE_DELAYED")
Drain()
Equal(engine.refreshGeneration, generation, "public count resuming restores deduplication")
io.write("detection-item-events-contract: ok\n")
