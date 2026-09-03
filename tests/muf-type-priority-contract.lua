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
  if actual ~= expected then
    error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

UnitClass = function()
  return "Evoker", "EVOKER"
end
UnitRace = function()
  return "Dracthyr", "Dracthyr"
end
UnitIsUnit = function(a, b)
  return a == b
end
IsPlayerSpell = function(id)
  return id == 360823 or id == 374251
end
C_SpellBook = {
  IsSpellInSpellBook = function(id)
    return IsPlayerSpell(id)
  end,
  IsSpellKnown = function(id)
    return IsPlayerSpell(id)
  end,
}
C_Spell = {
  GetOverrideSpell = function(id)
    return id
  end,
  GetSpellName = function(id)
    return "Spell " .. tostring(id)
  end,
}
Enum = {
  SpellBookSpellBank = {Player = 0, Pet = 1},
  CustomAuraButtonDispelTypeTextureStyle = {PreserveAsset = 3},
}
AuraUtil = {
  AuraFilters = {
    Dispellable = "DISPELLABLE",
    RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE",
  },
}
CreateColor = function(r, g, b, a)
  return {r = r, g = g, b = b, a = a}
end

local function NewFrame(parent)
  local frame = {parent = parent, shown = true, level = 0}
  function frame:GetParent()
    return self.parent
  end
  function frame:SetAllPoints(target)
    self.bounds = target
  end
  function frame:ClearAllPoints()
    self.bounds = nil
  end
  function frame:SetFrameLevel(level)
    self.level = level
  end
  function frame:GetFrameLevel()
    return self.level
  end
  function frame:EnableMouse(value)
    self.mouse = value
  end
  function frame:SetMouseClickEnabled(value)
    self.click = value
  end
  function frame:SetMouseMotionEnabled(value)
    self.motion = value
  end
  function frame:SetIgnoreParentAlpha(value)
    self.ignoreParentAlpha = value
  end
  function frame:Hide()
    self.shown = false
  end
  function frame:Show()
    self.shown = true
  end
  function frame:CreateTexture(_name, _layer, _template, sublevel)
    Check(sublevel >= -8 and sublevel <= 7, "texture sublevel remains valid")
    local texture = {sublevel = sublevel}
    function texture:SetAllPoints(target)
      self.bounds = target
    end
    function texture:SetColorTexture(r, g, b, a)
      self.color = {r, g, b, a}
    end
    function texture:SetIgnoreParentAlpha(value)
      self.ignoreParentAlpha = value
    end
    return texture
  end
  return frame
end

CreateFrame = function(_kind, _name, parent)
  return NewFrame(parent)
end

local ns = {
  DiagnosticModuleLoaded = function() end,
  DiagnosticModuleRefresh = function() end,
}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/DispelData.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFPresentation.lua"))("ZDecursive", ns)

local paralyzing
for i = 1, #ns.CURATED_DISPEL_ALERTS do
  local row = ns.CURATED_DISPEL_ALERTS[i]
  if row.id == 1294569 then
    paralyzing = row
    break
  end
end
Check(paralyzing ~= nil, "Paralyzing Shots public aura ID remains curated")
Equal(paralyzing.cureType, "MAGIC", "Paralyzing Shots is classified as Magic")

local function NewSlot()
  local slot = NewFrame(nil)
  function slot:ClearDispelTypeTextures()
    self.registration = nil
  end
  function slot:AddDispelTypeTexture(texture, options)
    self.registration = {texture = texture, options = options}
    return 1
  end
  return slot
end

local typeNames = {magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease"}
local environments = ns.MakeEnvironments()
for environmentIndex, environment in ipairs(ns.ENVIRONMENTS) do
  local pack = environments[environment.key]
  pack.colors.magic = {0.10 + environmentIndex * 0.01, 0.20, 0.30, 1}
  pack.colors.curse = {0.20, 0.10 + environmentIndex * 0.01, 0.30, 1}
  pack.colors.poison = {0.20, 0.30, 0.10 + environmentIndex * 0.01, 1}
  pack.colors.disease = {0.30, 0.20, 0.10 + environmentIndex * 0.01, 1}
  local slots = ns.GetDetectionSlots(pack, "party1")
  Equal(#slots, 4, environment.key .. " has exactly four native type slots")
  for i = 1, #slots do
    local info = slots[i]
    local expectedType = typeNames[info.typeKey]
    local include = info.candidateFilters.includeDispelTypes
    Check(include[expectedType] == true, environment.key .. " includes its exact type " .. expectedType)
    local count = 0
    for _ in pairs(include) do
      count = count + 1
    end
    Equal(count, 1, environment.key .. " provider slot is single-type")
    local slot = NewSlot()
    local owner = NewFrame(nil)
    local host = ns.ConfigureMUFDispelPresentation(slot, pack, owner, 0, owner, info)
    local map = slot.registration.options.customDispelColorMap
    Check(map[expectedType] ~= nil, environment.key .. " registers applied color for " .. expectedType)
    local mapCount = 0
    for _ in pairs(map) do
      mapCount = mapCount + 1
    end
    Equal(mapCount, 1, environment.key .. " presentation palette is single-type")
    Equal(host.level, 40 + 4 - info.priority, environment.key .. " uses configured priority frame level")
  end
end

local pack = environments.SOLO
pack.cure.order = {"magic", "curse", "poison", "disease"}
ns.InvalidateDetection()
local first = ns.GetDetectionSlots(pack, "player")
local levels = {}
for i = 1, #first do
  local info = first[i]
  local slot = NewSlot()
  local owner = NewFrame(nil)
  local host = ns.ConfigureMUFDispelPresentation(slot, pack, owner, 0, owner, info)
  levels[info.typeKey] = host.level
end
Check(levels.magic > levels.poison, "simultaneous Magic wins when configured above Poison")

pack.cure.order = {"poison", "curse", "magic", "disease"}
ns.InvalidateDetection()
local second = ns.GetDetectionSlots(pack, "player")
for i = 1, #second do
  local info = second[i]
  local slot = NewSlot()
  local owner = NewFrame(nil)
  local host = ns.ConfigureMUFDispelPresentation(slot, pack, owner, 0, owner, info)
  levels[info.typeKey] = host.level
end
Check(levels.poison > levels.magic, "simultaneous Poison wins when configured above Magic")
Check(levels.magic < ns.MUF_PRESENTATION.deathLevelOffset, "affliction fill remains below death and skull precedence")

local engineSource = assert(io.open("ZDecursive/DetectionEngine.lua", "rb"))
local engineText = engineSource:read("*a")
engineSource:close()
Check(engineText:find("slotType = slot.dispelType", 1, true), "diagnostics record public configured slot type")
Check(engineText:find("priority = slot.priority", 1, true), "diagnostics record public configured priority")
Check(not engineText:find("winner =", 1, true), "diagnostics never infer or persist a secret native winner")

print("muf-type-priority-contract: ok")
