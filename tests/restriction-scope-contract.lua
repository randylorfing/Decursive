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
    error(message or "check failed", 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat = false
local timers = {}
local setUnitCalls = 0
local failUnit
local desiredUnit = "player"
local soundDeferred = false
local restrictionQueries = {}
local restrictionAPIState = {[1] = 0, [2] = 1, [3] = 1, [4] = 1, [5] = 1}

InCombatLockdown = function()
  return combat
end

issecretvalue = function()
  return false
end

canaccessvalue = function()
  return true
end

Enum = {
  AddOnRestrictionType = {Combat = 1, Encounter = 2, ChallengeMode = 3, PvPMatch = 4, Map = 5},
  AddOnRestrictionState = {Inactive = 0, Active = 1, Activating = 2},
}

C_RestrictedActions = {
  GetAddOnRestrictionState = function(restrictionType)
    restrictionQueries[#restrictionQueries + 1] = restrictionType
    return restrictionAPIState[restrictionType]
  end,
}

C_Timer = {
  After = function(_delay, callback)
    timers[#timers + 1] = callback
  end,
}

local function NewSlot()
  return {
    EnableMouse = function() end,
    SetMouseClickEnabled = function() end,
    SetMouseMotionEnabled = function() end,
  }
end

local function NewContainer()
  local container = {enabled = false, shown = false}
  function container:SetUnit(unit)
    setUnitCalls = setUnitCalls + 1
    if unit == failUnit then
      error("injected SetUnit failure")
    end
    self.unit = unit
  end
  function container:SetEnabled(enabled)
    self.enabled = enabled == true
  end
  function container:Show()
    self.shown = true
  end
  function container:Hide()
    self.shown = false
  end
  function container:EnableMouse() end
  function container:SetMouseClickEnabled() end
  function container:SetMouseMotionEnabled() end
  function container:AddAuraSlot(_key, _filter, options)
    if options and options.initializeFrame then
      options.initializeFrame(NewSlot())
    end
  end
  function container:SetAuraSlotFilterString() end
  function container:SetAuraSlotCandidateFilters() end
  return container
end

CreateFrame = function(frameType)
  if frameType == "AuraContainer" then
    return NewContainer()
  end
  return {
    SetScript = function() end,
    RegisterEvent = function() end,
  }
end

local pack = {}
local ns = {
  addon = {
    GetAppliedEnvironmentPack = function()
      return pack
    end,
  },
  GetDetectionSlots = function()
    return {
      {
        key = "magic",
        filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
        candidateFilters = {includeDispelTypes = {Magic = true}},
      },
    }
  end,
  DiagnosticRecord = function() end,
}

assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
local engine = ns.DetectionEngine
local owner = {}

ns.RememberRestrictionState(Enum.AddOnRestrictionType.Encounter, Enum.AddOnRestrictionState.Active)
Check(ns.HasActiveAddonRestriction(), "observed Encounter restriction is visible to scoped consumers")
Check(ns.RefreshAddonRestrictionState("OBSERVED"), "observed restriction can be refreshed")
Equal(#restrictionQueries, 1, "refresh queries only an event-observed restriction type")
Equal(restrictionQueries[1], Enum.AddOnRestrictionType.Encounter, "ChallengeMode, PvPMatch, and Map are not imported")

engine:RegisterConsumer("MUFs", function()
  local _container, assigned, status = engine:BindCarrier("MUFs", {}, desiredUnit, function() end, owner)
  return assigned, status, 1
end)
engine:RegisterConsumer("Alerts", function()
  if soundDeferred then
    return false, "DEFERRED_RESTRICTED", 0
  end
  return true, "SUCCESS", 0
end)
engine:RegisterConsumer("LiveList", function()
  return true, "SUCCESS", 0
end)

Check(engine:Start(), "cold startup configures topology while unrelated restrictions are active")
local report = engine:GetDiagnostics()
Equal(report.desiredCarrierCount, 1, "cold startup desired count")
Equal(report.activeCarrierCount, 1, "cold startup active count")
Equal(report.transactionConfiguredCarrierCount, 1, "cold startup configured count")
Equal(report.transactionShownCarrierCount, 1, "cold startup shown count")
Equal(report.lifecycleState, "READY", "cold startup reaches APPLIED/READY")

ns.RememberRestrictionState(Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Active)
engine:OnEvent("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Active)
Equal(engine.state, "READY", "Combat restriction category does not replace actual lockdown")

local beforeCombatCalls = setUnitCalls
combat = true
desiredUnit = "party1"
Check(not engine:Refresh("ACTUAL_LOCKDOWN"), "actual combat lockdown defers topology")
Equal(setUnitCalls, beforeCombatCalls, "actual combat lockdown performs zero SetUnit calls")
combat = false
Check(engine:Recover("REGEN"), "topology replays after actual lockdown")
Equal(engine.carrierByOwner[owner].unit, "party1", "postcombat replay binds the desired token")

soundDeferred = true
Check(not engine:Refresh("SOUND_RESTRICTED"), "scoped sound restriction withholds global APPLIED")
local record = engine.carrierByOwner[owner]
Check(record.enabled == true and record.shown == true and record.unit == "party1", "scoped sound deferral retains the working MUF provider")
soundDeferred = false
restrictionAPIState[Enum.AddOnRestrictionType.Encounter] = Enum.AddOnRestrictionState.Inactive
restrictionAPIState[Enum.AddOnRestrictionType.Combat] = Enum.AddOnRestrictionState.Inactive
engine:OnEvent("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Encounter, Enum.AddOnRestrictionState.Inactive)
timers[#timers]()
Check(engine.state == "READY", "scoped restriction clear retries without globally blanking providers")

desiredUnit = "raid1"
failUnit = "raid1"
local retryBaseline = #timers
Check(not engine:Refresh("SETUNIT_FAILURE"), "native SetUnit exception is a typed transaction failure")
Check(engine.failClosed == true and engine.pending == true, "native failure remains pending for bounded retry")
Equal(#timers, retryBaseline + 1, "native failure schedules one bounded retry")

local detectionSource = assert(io.open("ZDecursive/Detection.lua", "rb")):read("*a")
Check(not detectionSource:find("for _name, restrictionType in pairs(types)", 1, true), "all-enum restriction import is absent")

io.write("restriction-scope-contract: ok\n")
