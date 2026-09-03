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

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local classFile = "EVOKER"
local raceFile = "Dwarf"
local known = {
  [360823] = true,
  [374251] = true,
  [900001] = true,
  [900002] = true,
}

UnitClass = function()
  return "Test", classFile
end
UnitRace = function()
  return "Dwarf", raceFile
end
UnitIsUnit = function(unit, other)
  return unit == other
end
IsPlayerSpell = function(spellId)
  return known[spellId] == true
end
C_SpellBook = {
  IsSpellInSpellBook = function(spellId)
    return known[spellId] == true
  end,
  IsSpellKnown = function(spellId)
    return known[spellId] == true
  end,
}
C_Spell = {
  GetOverrideSpell = function(spellId)
    return spellId
  end,
  GetSpellName = function(spellId)
    return "Spell " .. tostring(spellId)
  end,
}
Enum = {
  SpellBookSpellBank = {Player = 0, Pet = 1},
}
AuraUtil = {
  AuraFilters = {
    Dispellable = "DISPELLABLE",
    RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE",
  },
}

local providers = {}
local ns = {
  RegisterDiagnosticProvider = function(name, callback)
    providers[name] = callback
  end,
  DiagnosticModuleLoaded = function() end,
  DiagnosticModuleRefresh = function() end,
}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)

local expected = {"magic", "curse", "poison", "disease"}
Equal(#ns.ACTIONABLE_CURE_TYPES, 4, "actionable domain has four types")
for i = 1, #expected do
  Equal(ns.ACTIONABLE_CURE_TYPES[i], expected[i], "actionable type order " .. i)
end

local environments = ns.MakeEnvironments()
Equal(#ns.ENVIRONMENTS, 6, "all six environment packs exist")
local canonicalColors = {
  magic = {255 / 255, 7 / 255, 9 / 255, 1},
  curse = {153 / 255, 51 / 255, 255 / 255, 1},
  poison = {51 / 255, 204 / 255, 51 / 255, 1},
  disease = {255 / 255, 95 / 255, 36 / 255, 1},
}
for _, row in ipairs(ns.ENVIRONMENTS) do
  local pack = environments[row.key]
  Equal(table.concat(pack.cure.order, ","), "magic,curse,poison,disease", row.key .. " default cure order")
  for key, expectedColor in pairs(canonicalColors) do
    for channel = 1, 4 do
      Equal(pack.colors[key][channel], expectedColor[channel], row.key .. " canonical " .. key .. " channel " .. channel)
    end
  end
  Equal(pack.colors.range[1], 248 / 255, row.key .. " range stays separate from cure colors")
  Equal(pack.colors.range[2], 200 / 255, row.key .. " range green stays canonical")
  Equal(pack.colors.range[3], 3 / 255, row.key .. " range blue stays canonical")
  Equal(pack.colors.range[4], 1, row.key .. " range stays opaque")
  Check(pack.cure.enrage == nil and pack.cure.bleed == nil and pack.cure.charm == nil, row.key .. " has no false cure defaults")
  Equal(table.concat(ns.GetEnabledTypes(pack), ","), "magic,curse,poison,disease", row.key .. " enables only actionable types")
end

local legacy = ns.DeepCopy(environments.OPEN_WORLD)
legacy.cure.enrage = true
legacy.cure.bleed = true
legacy.cure.charm = true
legacy.cure.magicCharmed = true
legacy.cure.bleedDetection = true
legacy.cure.order = {"bleed", "enrage", "magic", "charm", "curse", "poison", "disease"}
Equal(table.concat(ns.GetEnabledTypes(legacy), ","), "magic,curse,poison,disease", "legacy true flags and order cannot reactivate false types")
Equal(table.concat(legacy.cure.order, ","), "magic,curse,poison,disease", "legacy order is normalized to the strict domain")

local byMe = ns.GetDetectionSlots(legacy, "party1")
Equal(#byMe, 4, "BY_ME declares four stable type slots")
for index, name in ipairs({"Magic", "Curse", "Poison", "Disease"}) do
  local slot = byMe[index]
  Equal(slot.priority, index, "default singleton priority follows canonical order " .. name)
  Equal(slot.filter, "HARMFUL|DISPELLABLE", "BY_ME uses broad provider gate " .. name)
  Check(slot.candidateFilters.includeDispelTypes[name] == true, "BY_ME singleton includes " .. name)
  local count = 0
  for _ in pairs(slot.candidateFilters.includeDispelTypes) do
    count = count + 1
  end
  Equal(count, 1, "BY_ME slot cannot select another type " .. name)
end
Check(byMe[1].candidateFilters.includeDispelTypes.Enrage == nil, "BY_ME excludes hostile Enrage")
Check(byMe[1].candidateFilters.includeDispelTypes.Bleed == nil, "BY_ME excludes Bleed")

AuraUtil.AuraFilters.Dispellable = nil
local fallback = ns.GetDetectionSlots(legacy, "party1")
for i = 1, #fallback do
  Equal(fallback[i].filter, "HARMFUL|RAID_PLAYER_DISPELLABLE", "missing broad token falls back to the supported raid-player filter")
end
AuraUtil.AuraFilters.Dispellable = "DISPELLABLE"

legacy.cure.filterMode = "ALL"
local allMode = ns.GetDetectionSlots(legacy, "party1")
Equal(#allMode, 4, "ALL declares four stable type slots")
Equal(allMode[1].filter, "HARMFUL|DISPELLABLE", "ALL retains the supported provider filter")
Check(allMode[1].candidateFilters.includeDispelTypes.Enrage == nil, "ALL excludes hostile Enrage")
Check(allMode[1].candidateFilters.includeDispelTypes.Bleed == nil, "ALL excludes Bleed")

legacy.cure.order = {"poison", "disease", "curse", "magic"}
local reordered = ns.GetDetectionSlots(legacy, "party1")
local priorities = {}
for i = 1, #reordered do
  priorities[reordered[i].typeKey] = reordered[i].priority
end
Equal(priorities.poison, 1, "configured Poison priority is preserved")
Equal(priorities.magic, 4, "configured Magic priority is preserved")

legacy.cure.magic = false
legacy.cure.curse = false
legacy.cure.poison = false
legacy.cure.disease = false
local none = ns.GetDetectionSlots(legacy, "party1")
Equal(#none, 4, "zero enabled types preserves stable slot declarations")
for i = 1, #none do
  Check(type(none[i].candidateFilters.includeDispelTypes) == "table", "zero enabled types still uses strict empty provider maps")
  Check(next(none[i].candidateFilters.includeDispelTypes) == nil, "zero enabled types cannot fall back to generic dispellable auras")
end

local autoPack = ns.DeepCopy(environments.SOLO)
autoPack.cure.mode = "AUTO"
autoPack.customSpells = {
  {spellId = 900001, enabled = true, types = {"bleed", "enrage", "magic"}},
  {spellId = 900002, enabled = true, types = {"bleed", "enrage", "charm"}},
}
local autoModel = ns.GetDetectionModel(autoPack)
local customById = {}
for _, action in ipairs(autoModel.customActions) do
  customById[action.spellId] = action
end
Equal(table.concat(customById[900001].types, ","), "magic", "mixed custom action retains only actionable coverage")
Check(customById[900002] == nil, "legacy-only custom action is ignored")

local manualPack = ns.DeepCopy(autoPack)
manualPack.cure.mode = "MANUAL"
manualPack.customSpells[1].types = {"poison", "bleed"}
local manualModel = ns.GetDetectionModel(manualPack)
local manualCustom
for _, action in ipairs(manualModel.customActions) do
  if action.spellId == 900001 then
    manualCustom = action
  end
end
Equal(table.concat(manualCustom.types, ","), "poison", "Manual mode uses the same strict custom scope")
Check(manualModel ~= autoModel, "profile pack signature includes effective custom types")

local evokerAction
for _, action in ipairs(autoModel.classActions) do
  if action.spellId == 374251 then
    evokerAction = action
  end
end
Equal(table.concat(evokerAction.types, ","), "curse,poison,disease", "Evoker friendly cure drops Bleed coverage")

classFile = "DRUID"
known = {[2908] = true}
ns.InvalidateDetection()
Equal(#ns.GetKnownCures(environments.RAID), 0, "hostile Druid Enrage purge is absent from the cure catalog")
classFile = "HUNTER"
known = {[19801] = true}
ns.InvalidateDetection()
Equal(#ns.GetKnownCures(environments.PVP), 0, "hostile Hunter Enrage purge is absent from the cure catalog")

classFile = "SHAMAN"
known = {[383013] = true}
local gaps = ns.GetEngineDispelGaps(true)
Check(gaps.Poison == true and gaps.Bleed == nil, "engine gap supports Poison only and never Dwarf Bleed")

local copied = ns.DeepCopy(legacy)
copied.cure.enrage = true
copied.cure.bleed = true
Equal(table.concat(ns.GetEnabledTypes(copied), ","), "", "copy cannot reactivate legacy flags when four actionable toggles are disabled")
local reset = ns.MakePack("SOLO")
Equal(table.concat(ns.GetEnabledTypes(reset), ","), "magic,curse,poison,disease", "reset restores exactly four actionable defaults")

local detectionDiagnostic = providers.Detection()
Equal(detectionDiagnostic.actionableTypeCount, 4, "diagnostics reports four-type domain")
Check(type(detectionDiagnostic.enabledActionableTypeCount) == "number", "diagnostics reports sanitized enabled count")
Check(type(detectionDiagnostic.knownCureActionCount) == "number", "diagnostics reports sanitized action count")

local soundPack = ns.MakePack("DUNGEON")
local soundCalls = {}
local nextRegistration = 0
ns.addon = {
  db = {global = {learnedDispelSpellIds = {999999}}},
  rosterOrderSignature = "player|party1|partypet1",
  GetAppliedEnvironmentPack = function()
    return soundPack
  end,
}
ns.CURATED_DISPEL_ALERTS = {
  {id = 910001, cureType = "MAGIC"},
  {id = 910002, cureType = "CURSE"},
  {id = 910003, cureType = "POISON"},
  {id = 910004, cureType = "DISEASE"},
  {id = 910005, cureType = "BLEED"},
}
ns.GetKnownCures = function(pack)
  return {{types = ns.GetEnabledTypes(pack)}}
end
C_UnitAuras = {
  AddAuraSound = function(_trigger, options)
    nextRegistration = nextRegistration + 1
    soundCalls[#soundCalls + 1] = options.spellID
    return nextRegistration
  end,
  RemoveAuraSound = function() end,
}
Enum.UnitAuraSoundTrigger = {Added = 1}
IsInRaid = function()
  return false
end
UnitExists = function()
  return true
end
assert(loadfile("ZDecursive/Alerts.lua"))("ZDecursive", ns)

local function SoundSet()
  local set = {}
  for i = 1, #soundCalls do
    set[soundCalls[i]] = true
  end
  return set
end

ns.RefreshAlerts()
local registeredSpells = SoundSet()
for spellId = 910001, 910004 do
  Check(registeredSpells[spellId] == true, "BY_ME sound includes actionable curated spell " .. spellId)
end
Check(registeredSpells[910005] == nil, "BY_ME sound excludes curated Bleed")
Check(registeredSpells[999999] == nil, "BY_ME sound excludes untyped learned IDs")

soundCalls = {}
soundPack.cure.filterMode = "ALL"
ns.RefreshAlerts()
registeredSpells = SoundSet()
Check(registeredSpells[910005] == nil and registeredSpells[999999] == nil, "ALL sound retains strict actionable scope")

soundCalls = {}
soundPack = ns.MakePack("RAID")
soundPack.cure.poison = false
ns.RefreshAlerts()
registeredSpells = SoundSet()
Check(registeredSpells[910003] == nil, "applied-profile sound refresh removes a disabled actionable type")
Check(#soundCalls == 0, "applied-profile sound refresh retains unchanged enabled registrations without duplicate adds")
local soundStatus = ns.GetAuraSoundRegistryStatus()
Check(soundStatus.desired == 9 and soundStatus.exact == 9 and soundStatus.active == 9 and soundStatus.stale == 0, "applied-profile sound refresh retains exact enabled actionable coverage")

local alertDiagnostic = providers.Alerts()
Equal(alertDiagnostic.actionableTypeCount, 4, "alert diagnostics reports four-type scope")
Equal(alertDiagnostic.learnedStoredIgnoredCount, 1, "alert diagnostics reports ignored learned storage without IDs")

local options = Read("ZDecursive/Options.lua")
for _, label in ipairs({"Enrage", "Bleed", "Charm", "Magic (charmed)"}) do
  Check(not options:find('page = "cure", label = "' .. label .. '"', 1, true), "Cure Types omits " .. label)
  Check(not options:find('page = "color", label = "' .. label .. '"', 1, true), "Color UI omits false-support label " .. label)
end
for _, label in ipairs({"Magic", "Curse", "Poison", "Disease"}) do
  Check(options:find('page = "cure", label = "' .. label .. '"', 1, true), "Cure Types includes " .. label)
end

local alerts = Read("ZDecursive/Alerts.lua")
local syncStart = assert(alerts:find("SyncNativeSounds = function", 1, true))
local syncEnd = assert(alerts:find("local moveMode", syncStart, true))
local sync = alerts:sub(syncStart, syncEnd - 1)
Check(not sync:find("EnsureLearnedStore", 1, true), "untyped learned IDs cannot enter actionable sound registration")
Check(not alerts:find('BLEED = "bleed"', 1, true), "Bleed cannot pass curated sound capability filtering")
Check(not alerts:find('Bleed = "DISPEL"', 1, true), "Bleed cannot render provider DISPEL text")

local presentation = Read("ZDecursive/MUFPresentation.lua")
Check(not presentation:find('{"Enrage", "enrage"}', 1, true), "provider palette excludes Enrage")
Check(not presentation:find('{"Bleed", "bleed"}', 1, true), "provider palette excludes Bleed")

io.write("actionable-cure-types-contract: ok\n")
