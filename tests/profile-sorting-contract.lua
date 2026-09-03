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

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Same(actual, expected, message)
  Equal(table.concat(actual, ","), table.concat(expected, ","), message)
end

strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

GetInstanceInfo = function()
  return "Open World", "none"
end

IsInRaid = function()
  return false
end

IsInGroup = function()
  return false
end

local combat = false
local currentSpec = 1
InCombatLockdown = function()
  return combat
end
UnitFullName = function()
  return "Tester", "Realm"
end
UnitName = function(unit)
  return unit or "Tester"
end
GetRealmName = function()
  return "Realm"
end
GetNormalizedRealmName = function()
  return "Realm"
end
UnitIsUnit = function(left, right)
  return left == right
end
UnitGUID = function(unit)
  return "Player-1-" .. tostring(unit)
end

C_SpecializationInfo = {
  GetSpecialization = function()
    return currentSpec
  end,
  GetSpecializationInfo = function(index)
    return 70 + index, "Spec"
  end,
  GetNumSpecializations = function()
    return 3
  end,
}

local addon = {commands = {}}
function addon:RegisterChatCommand(name, callback)
  self.commands[name] = callback
end
function addon:RegisterEvent()
end
function addon:Print()
end

local AceAddon = {}
function AceAddon:NewAddon()
  return addon
end
local AceDB = {}
LibStub = function(name)
  if name == "AceAddon-3.0" then
    return AceAddon
  end
  if name == "AceDB-3.0" then
    return AceDB
  end
  error("unexpected library")
end

local ns = {}
local providers = {}
ns.RegisterDiagnosticProvider = function(name, callback)
  providers[name] = callback
end
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)

local function Copy(value)
  return ns.DeepCopy(value)
end

local db = {
  profiles = {},
  global = Copy(ns.defaults.global),
  char = Copy(ns.defaults.char),
  current = "A",
  profileKeys = {Tester = "A"},
}
db.profiles.A = {environments = ns.MakeEnvironments(), lists = {priority = {}, skip = {}}}
db.profiles.B = {environments = ns.MakeEnvironments(), lists = {priority = {{kind = "id", name = "party2"}}, skip = {}}}
db.profile = db.profiles.A
function db:GetCurrentProfile()
  return self.current
end
function db:GetProfiles()
  local result = {}
  for name in pairs(self.profiles) do
    result[#result + 1] = name
  end
  table.sort(result)
  return result
end
function db:SetProfile(name)
  self.current = name
  self.profiles[name] = self.profiles[name] or {}
  self.profile = self.profiles[name]
  self.profileKeys.Tester = name
end
function db:CopyProfile(source)
  self.profiles[self.current] = Copy(self.profiles[source])
  self.profile = self.profiles[self.current]
end
function db:DeleteProfile(name)
  self.profiles[name] = nil
end
function db:ResetDB(defaultProfile)
  self.profiles = {[defaultProfile] = {environments = ns.MakeEnvironments(), lists = {priority = {}, skip = {}}}}
  self.global = Copy(ns.defaults.global)
  self.char = Copy(ns.defaults.char)
  self.current = defaultProfile
  self.profile = self.profiles[defaultProfile]
end

addon.db = db
db.global.accountProfile = "A"
db.profiles.A.environments.OPEN_WORLD.mufs.order = "GROUP"
db.profiles.A.environments.DUNGEON.mufs.order = "DANDERSFRAMES"
db.profiles.B.environments.OPEN_WORLD.mufs.order = "PRIORITY"
db.profiles.B.environments.DUNGEON.mufs.order = "GROUP"

assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)

local layouts = 0
ns.RefreshMUFs = function()
  layouts = layouts + 1
end

addon:EnsureEnvironments()
addon:EnsureSpecAssignments()
ns.Notify()

local units = {"player", "pet", "party1", "party2", "partypet2"}
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "GROUP", "profile A configured order")
Same(ns.ApplyUnitLists(units, addon:GetEditingPack()), units, "profile A group order")

local before = layouts
local ok = addon:ActivateProfile("B")
Check(ok, "manual profile switch")
Equal(layouts, before + 1, "manual switch rebuilds immediately once")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "PRIORITY", "menu getter follows profile B")
Same(ns.ApplyUnitLists(units, addon:GetEditingPack()), {"party2", "partypet2", "player", "pet", "party1"}, "profile B priority order with pets")

ok = addon:SetEditingEnvironment("DUNGEON")
Check(ok, "pack switch")
Equal(ns.GetEffectiveMUFOrder(), "PRIORITY", "nonactive editor does not change applied sort order")
addon.appliedEnvironment = "DUNGEON"
ns.Notify()
Equal(ns.GetEffectiveMUFOrder(), "GROUP", "applied Dungeon pack controls runtime order")
ok = addon:SetEditingEnvironment("OPEN_WORLD")
Check(ok, "pack switch back")
Equal(ns.GetEffectiveMUFOrder(), "GROUP", "editor switch back still does not change applied order")
addon.appliedEnvironment = "OPEN_WORLD"
ns.Notify()
Equal(ns.GetEffectiveMUFOrder(), "PRIORITY", "profile B open world pack order")

ns.SetConfiguredMUFOrder(addon:GetEditingPack(), "DANDERSFRAMES")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "DANDERSFRAMES", "Danders control retained while unavailable")
Equal(ns.GetEffectiveMUFOrder(), "GROUP", "unavailable Danders falls back to group")
DandersFrames_GetFrameForUnit = function()
  return {}
end
Equal(ns.GetEffectiveMUFOrder(), "DANDERSFRAMES", "available Danders becomes effective")
DandersFrames_GetFrameForUnit = nil
Equal(ns.GetEffectiveMUFOrder(), "GROUP", "Danders unload returns to group without changing control")

ns.SetConfiguredMUFOrder(addon:GetEditingPack(), "PRIORITY")
local diagnosticBefore = ns.GetUnitSortDiagnostics()
ns.AddListEntry("priority", {kind = "id", name = "party1"})
local diagnosticAfter = ns.GetUnitSortDiagnostics()
Check(diagnosticAfter.sortRevision > diagnosticBefore.sortRevision, "priority edit advances sort revision")
Check(diagnosticAfter.priorityRevision > diagnosticBefore.priorityRevision, "priority edit advances priority revision")
Check(diagnosticAfter.sortSignatureGeneration > diagnosticBefore.sortSignatureGeneration, "priority edit advances signature generation")

ok = addon:SetCharacterProfileAssignment("A")
Check(ok and db.current == "A", "assignment switch applies profile A")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "GROUP", "assignment switch updates control getter")
ok = addon:SetCharacterProfileAssignment(nil)
Check(ok and db.current == "B", "character inheritance returns to account profile")
ok = addon:SetAccountProfileAssignment("A")
Check(ok and db.current == "A", "account assignment switch applies profile A")
ok = addon:SetAccountProfileAssignment("B")
Check(ok and db.current == "B", "account assignment switch applies profile B")
ok = addon:ActivateProfile("B")
Check(ok and db.current == "B", "manual switch returns to B")

ok = addon:CopyProfile("CopyB")
Check(ok, "copy profile")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "PRIORITY", "copy retains order")
ok = addon:RenameProfile("RenamedB")
Check(ok, "rename profile")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "PRIORITY", "rename retains order")
ok = addon:ResetCurrentProfile()
Check(ok, "reset profile")
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "GROUP", "reset restores group default")

for _ = 1, 3 do
  Check(addon:ActivateProfile("A"), "repeated switch A")
  Check(addon:ActivateProfile("B"), "repeated switch B")
end
Equal(ns.GetConfiguredMUFOrder(addon:GetEditingPack()), "PRIORITY", "repeated switches keep B order")

currentSpec = 1
addon:SetSpecProfileAssignment(1, "A")
addon:SetSpecProfileAssignmentEnabled(1, true)
addon:SetSpecProfileAssignment(2, "B")
addon:SetSpecProfileAssignmentEnabled(2, true)
currentSpec = 1
addon:ApplyResolvedProfile("test")
Equal(db.current, "A", "spec one profile")
ns.IsOptionsShown = function()
  return true
end
combat = true
currentSpec = 2
before = layouts
addon:OnSpecChanged()
Equal(db.current, "A", "combat keeps old runtime profile")
Check(addon.profileResolvePending == true, "combat marks profile pending")
Check(ns.GetUnitSortDiagnostics().pendingSortRefresh == true, "combat marks sort pending")
Equal(layouts, before, "combat performs no MUF layout")
combat = false
addon:OnRegenEnabled()
Equal(db.current, "B", "regen applies spec profile even with options open")
Equal(layouts, before + 1, "regen performs exactly one sort rebuild")
Check(ns.GetUnitSortDiagnostics().pendingSortRefresh == false, "regen clears sort pending")

local activePack = addon:GetEditingPack()
Equal(ns.GetConfiguredMUFOrder(activePack), "PRIORITY", "combat order test starts from stored priority")
combat = true
before = layouts
Check(ns.SetConfiguredMUFOrder(activePack, "GROUP"), "combat accepts pending menu order")
Equal(ns.GetConfiguredMUFOrder(activePack), "PRIORITY", "combat does not mutate profile order")
Equal(ns.GetPendingMUFOrder(), "GROUP", "menu getter can retain pending combat order")
Check(ns.GetUnitSortDiagnostics().pendingSortRefresh == true, "combat menu order marks sort pending")
Equal(layouts, before, "combat menu order performs no MUF layout")
combat = false
addon:OnRegenEnabled()
Equal(ns.GetConfiguredMUFOrder(activePack), "GROUP", "regen applies pending menu order")
Check(ns.GetPendingMUFOrder() == nil, "regen clears pending menu order")
Equal(layouts, before + 1, "regen applies pending menu order exactly once")
Check(ns.SetConfiguredMUFOrder(activePack, "PRIORITY"), "restore priority for diagnostics")

local malformed = {mufs = "bad"}
Equal(ns.GetConfiguredMUFOrder(malformed), "GROUP", "malformed pack falls back safely")
Equal(ns.GetEffectiveMUFOrder(malformed), "GROUP", "malformed effective mode")

local listProvider = providers.Lists
Check(type(listProvider) == "function", "Lists diagnostics provider")
local report = listProvider()
Equal(report.effectiveSortMode, "PRIORITY", "diagnostics effective mode")
Equal(report.environmentPackID, "OPEN_WORLD", "diagnostics environment pack")
Check(type(report.profileChangeGeneration) == "number", "diagnostics profile generation")
Check(type(report.sortSignatureGeneration) == "number", "diagnostics signature generation")
Check(type(report.sortCacheGeneration) == "number", "diagnostics cache generation")
Check(report.pendingSortRefresh == false, "diagnostics pending state")

io.write("profile-sorting-contract: ok\n")
