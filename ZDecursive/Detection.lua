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

local ADDON_NAME, ns = ...

if ns.DiagnosticCheckpoint then
  ns.DiagnosticCheckpoint("module", "Detection file start")
end

local TYPE_KEYS = ns.ACTIONABLE_CURE_TYPES or {"magic", "curse", "poison", "disease"}
local ACTIONABLE_TYPES = ns.ACTIONABLE_CURE_TYPE_SET or {
  magic = true,
  curse = true,
  poison = true,
  disease = true,
}

local TYPE_BLIZZ = {
  magic = "Magic",
  curse = "Curse",
  poison = "Poison",
  disease = "Disease",
}

local FRIENDLY_NATIVE = {
  magic = true,
  curse = true,
  poison = true,
  disease = true,
}

local CLASS_SPELLS = {
  PALADIN = {4987, 213644},
  PRIEST = {527, 213634},
  DRUID = {88423, 2782},
  SHAMAN = {77130, 51886},
  MONK = {115450, 218164},
  EVOKER = {360823, 365585, 374251},
  MAGE = {475},
  WARLOCK = {89808},
}

local SPELL_TYPES = {
  [4987] = {"magic", "poison", "disease"},
  [213644] = {"poison", "disease"},
  [527] = {"magic", "disease"},
  [213634] = {"disease"},
  [88423] = {"magic", "curse", "poison"},
  [2782] = {"curse", "poison"},
  [77130] = {"magic", "curse"},
  [51886] = {"curse"},
  [115450] = {"magic", "poison", "disease"},
  [218164] = {"poison", "disease"},
  [360823] = {"magic", "poison"},
  [365585] = {"poison"},
  [374251] = {"poison", "curse", "disease"},
  [475] = {"curse"},
  [89808] = {"magic"},
}

local BATTLE_REZ = {20484, 61999, 391054}
local NORMAL_REZ = {50769, 7328, 2006, 2008, 115178, 361227}
local SOUL_LINK_SPELL_ID = 1259646
local SOUL_LINK_ITEM_ID = 269586
local POISON_CLEANSING_TOTEM = 383013
local BY_ME_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"
local ALL_FILTER = "HARMFUL|DISPELLABLE"
local GAP_FILTER = "HARMFUL|!RAID_PLAYER_DISPELLABLE"
local NATIVE_FILTER = BY_ME_FILTER
local FOLLOWER_GUARD_SECONDS = 12
local FOLLOWER_RETRY = {0.10, 0.35, 1.00, 2.00, 4.00, 7.00, 10.00}

local cache = {
  signature = nil,
  model = nil,
}

local smartRezCache

local follower = {
  untilTime = 0,
  generation = 0,
  coreCount = 0,
  units = nil,
}

local rosterContext = {
  kind = "UNKNOWN",
  ready = false,
  instanceClass = "UNKNOWN",
  realPartyCount = 0,
  reason = "INITIAL",
  transitionReason = "NONE",
}

local eventsOn = false
local eventFrame
local pendingCombatSlots = false
local pendingRestrictionSlots = false
local restrictionState = {}
local diagnosticAttachAttempts = 0
local diagnosticAttachments = 0
local diagnosticAttachFailures = 0

local function Accessible(value)
  if value == nil then
    return true
  end
  if type(issecretvalue) == "function" and issecretvalue(value) then
    if type(canaccessvalue) == "function" then
      return canaccessvalue(value) == true
    end
    return false
  end
  return true
end

local function Public(value)
  if not Accessible(value) then
    return nil
  end
  return value
end

local function ShowDiagnosticText(title, lines)
  if not Accessible(title) or type(title) ~= "string" then
    return false
  end
  if type(lines) ~= "table" then
    return false
  end
  local output = {title}
  for i = 1, #lines do
    local line = lines[i]
    if not Accessible(line) or type(line) ~= "string" then
      return false
    end
    output[#output + 1] = line
  end
  local diagnostics = ns.Diagnostics
  if type(diagnostics) ~= "table" or type(diagnostics.ShowText) ~= "function" then
    return false
  end
  local ok, shown = pcall(diagnostics.ShowText, table.concat(output, "\n"))
  return ok and shown ~= false
end

local function IsTrue(value)
  if not Accessible(value) then
    return false
  end
  return value == true or value == 1
end

function ns.IsAccessible(value)
  return Accessible(value)
end

function ns.PublicValue(value)
  return Public(value)
end

function ns.IsPublicTrue(value)
  return IsTrue(value)
end

function ns.SafeNativeSetUnit(container, unit)
  if type(InCombatLockdown) == "function" and InCombatLockdown() == true then
    return false, "DEFERRED_COMBAT"
  end
  if not Accessible(unit) or type(unit) ~= "string" or unit == "" then
    return false, "UNIT_INVALID"
  end
  if not container or type(container.SetUnit) ~= "function" then
    return false, "SET_UNIT_UNAVAILABLE"
  end
  local ok = pcall(container.SetUnit, container, unit)
  if not ok then
    return false, "UNIT_ASSIGN_FAILED"
  end
  return true, "ASSIGNED"
end

local function RestrictionInactive()
  local states = Enum and Enum.AddOnRestrictionState
  if states and type(states.Inactive) == "number" then
    return states.Inactive
  end
  return 0
end

local function RestrictionActiveToken()
  local states = Enum and Enum.AddOnRestrictionState
  if states and type(states.Active) == "number" then
    return states.Active
  end
  return 1
end

function ns.RememberRestrictionState(restrictionType, restrictionStateValue)
  restrictionType = Public(restrictionType)
  restrictionStateValue = Public(restrictionStateValue)
  if type(restrictionType) == "number" and type(restrictionStateValue) == "number" then
    restrictionState[restrictionType] = restrictionStateValue
  end
end

function ns.RefreshAddonRestrictionState(reason)
  local api = C_RestrictedActions
  if type(api) ~= "table" or type(api.GetAddOnRestrictionState) ~= "function" then
    return false
  end
  local refreshed = 0
  for restrictionType in pairs(restrictionState) do
    if type(restrictionType) == "number" then
      local ok, latest = pcall(api.GetAddOnRestrictionState, restrictionType)
      latest = ok and Public(latest) or nil
      if type(latest) == "number" then
        restrictionState[restrictionType] = latest
        refreshed = refreshed + 1
      end
    end
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("RESTRICTION_REFRESH", {
      reason = type(reason) == "string" and reason or "POLL",
      refreshed = refreshed,
    }, true)
  end
  return refreshed > 0
end

function ns.HasActiveAddonRestriction()
  local states = Enum and Enum.AddOnRestrictionState
  local inactive = RestrictionInactive()
  local activating = states and states.Activating
  local active = RestrictionActiveToken()
  for restrictionType, state in pairs(restrictionState) do
    if type(restrictionType) == "number" and type(state) == "number" then
      if state == activating or state == active or state ~= inactive then
        return true
      end
    end
  end
  return false
end

function ns.AuraDisplayMutationBlocked()
  if InCombatLockdown and InCombatLockdown() then
    return true
  end
  return ns.HasActiveAddonRestriction()
end

local function Addon()
  return ns.addon
end

local function GetPack()
  local addon = Addon()
  if addon and addon.GetAppliedEnvironmentPack then
    return addon:GetAppliedEnvironmentPack()
  end
  return ns.PACK
end

local function PlayerClassFile()
  if not UnitClass then
    return nil
  end
  local _name, file = UnitClass("player")
  return Public(file)
end

local function PlayerRaceFile()
  if not UnitRace then
    return nil
  end
  local _name, race = UnitRace("player")
  return Public(race)
end

local function SpellName(spellId)
  local name
  if C_Spell and C_Spell.GetSpellName then
    name = C_Spell.GetSpellName(spellId)
  elseif C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if type(info) == "table" then
      name = info.name
    end
  end
  if type(name) == "string" and Accessible(name) and name ~= "" then
    return name
  end
  return nil
end

local function ResolveOverride(spellId)
  if type(spellId) ~= "number" then
    return spellId
  end
  if C_Spell and C_Spell.GetOverrideSpell then
    local override = Public(C_Spell.GetOverrideSpell(spellId))
    if type(override) == "number" and override > 0 then
      return override
    end
  end
  return spellId
end

local function SpellInBook(spellId, includeOverrides)
  if type(spellId) ~= "number" or spellId <= 0 then
    return false
  end
  if C_SpellBook then
    local banks = Enum and Enum.SpellBookSpellBank
    if C_SpellBook.IsSpellInSpellBook then
      if banks then
        if includeOverrides == false then
          if IsTrue(C_SpellBook.IsSpellInSpellBook(spellId, banks.Player, false)) then
            return true
          end
        else
          if IsTrue(C_SpellBook.IsSpellInSpellBook(spellId, banks.Player, true)) then
            return true
          end
          if IsTrue(C_SpellBook.IsSpellInSpellBook(spellId, banks.Player)) then
            return true
          end
          if IsTrue(C_SpellBook.IsSpellInSpellBook(spellId)) then
            return true
          end
        end
      elseif IsTrue(C_SpellBook.IsSpellInSpellBook(spellId)) then
        return true
      end
    end
    if C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId)) then
      return true
    end
    if banks and C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId, banks.Player)) then
      return true
    end
    if banks and C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId, banks.Pet)) then
      return true
    end
  end
  return false
end

local function ResolveKnownSpell(baseId)
  if type(baseId) ~= "number" or baseId <= 0 then
    return nil, nil, nil
  end
  local overrideId = ResolveOverride(baseId)
  local useId = baseId
  if overrideId ~= baseId then
    local baseInBook = SpellInBook(baseId, false)
    local overrideInBook = SpellInBook(overrideId, true)
    if not baseInBook and overrideInBook then
      useId = overrideId
    elseif SpellInBook(overrideId, true) then
      useId = overrideId
    end
  end
  if not SpellInBook(useId, true) and not SpellInBook(baseId, true) then
    return nil, nil, nil
  end
  local name = SpellName(useId) or SpellName(baseId)
  if not name then
    return nil, nil, nil
  end
  return name, useId, baseId
end

function ns.EnsureCureOrder(pack)
  if type(pack) ~= "table" then
    return TYPE_KEYS
  end
  if type(pack.cure) ~= "table" then
    pack.cure = {}
  end
  local order = pack.cure.order
  if type(order) ~= "table" then
    order = {}
    pack.cure.order = order
  end
  local seen = {}
  local cleaned = {}
  for i = 1, #order do
    local key = order[i]
    if type(key) == "string" and not seen[key] then
      for t = 1, #TYPE_KEYS do
        if TYPE_KEYS[t] == key then
          seen[key] = true
          cleaned[#cleaned + 1] = key
          break
        end
      end
    end
  end
  for t = 1, #TYPE_KEYS do
    local key = TYPE_KEYS[t]
    if not seen[key] then
      cleaned[#cleaned + 1] = key
    end
  end
  pack.cure.order = cleaned
  return cleaned
end

function ns.EnsureCustomSpells(pack)
  if type(pack) ~= "table" then
    return {}
  end
  if type(pack.customSpells) ~= "table" then
    pack.customSpells = {}
  end
  return pack.customSpells
end

local function TypeEnabled(pack, key)
  if not ACTIONABLE_TYPES[key] then
    return false
  end
  if type(pack) ~= "table" or type(pack.cure) ~= "table" then
    return true
  end
  if pack.cure[key] == false then
    return false
  end
  return true
end

function ns.GetActionableCureTypes(types)
  local out = {}
  local seen = {}
  if type(types) ~= "table" then
    return out
  end
  for i = 1, #types do
    local key = types[i]
    if ACTIONABLE_TYPES[key] and not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  return out
end

function ns.GetEnabledTypes(pack)
  pack = pack or GetPack()
  local order = ns.EnsureCureOrder(pack)
  local enabled = {}
  for i = 1, #order do
    local key = order[i]
    if TypeEnabled(pack, key) then
      enabled[#enabled + 1] = key
    end
  end
  return enabled
end

function ns.MoveCureType(pack, key, direction)
  pack = pack or GetPack()
  local order = ns.EnsureCureOrder(pack)
  local index
  for i = 1, #order do
    if order[i] == key then
      index = i
      break
    end
  end
  if not index then
    return false
  end
  local target = index + (direction or 0)
  if target < 1 or target > #order then
    return false
  end
  order[index], order[target] = order[target], order[index]
  ns.InvalidateDetection()
  return true
end

function ns.AddCustomSpell(pack, spellId, types)
  pack = pack or GetPack()
  local list = ns.EnsureCustomSpells(pack)
  spellId = tonumber(spellId)
  if type(spellId) ~= "number" or spellId <= 0 then
    return false, "id"
  end
  if not Accessible(spellId) then
    return false, "secret"
  end
  local typeList = {}
  local seen = {}
  if type(types) == "string" then
    types = {types}
  end
  if type(types) == "table" then
    for i = 1, #types do
      local key = types[i]
      if type(key) == "string" and not seen[key] then
        for t = 1, #TYPE_KEYS do
          if TYPE_KEYS[t] == key then
            seen[key] = true
            typeList[#typeList + 1] = key
            break
          end
        end
      end
    end
  end
  if #typeList == 0 then
    typeList[1] = "magic"
  end
  for i = 1, #list do
    local row = list[i]
    if type(row) == "table" and row.spellId == spellId then
      row.enabled = true
      row.types = row.types or {}
      local have = {}
      for t = 1, #row.types do
        have[row.types[t]] = true
      end
      for t = 1, #typeList do
        if not have[typeList[t]] then
          row.types[#row.types + 1] = typeList[t]
        end
      end
      ns.InvalidateDetection()
      return true, "merged"
    end
  end
  list[#list + 1] = {
    spellId = spellId,
    types = typeList,
    enabled = true,
    pet = false,
  }
  ns.InvalidateDetection()
  return true, "added"
end

function ns.RemoveCustomSpell(pack, spellId)
  pack = pack or GetPack()
  local list = ns.EnsureCustomSpells(pack)
  spellId = tonumber(spellId)
  local kept = {}
  local removed = false
  for i = 1, #list do
    local row = list[i]
    if type(row) == "table" and row.spellId == spellId then
      removed = true
    else
      kept[#kept + 1] = row
    end
  end
  pack.customSpells = kept
  if removed then
    ns.InvalidateDetection()
  end
  return removed
end

local function TypeRank(enabled, key)
  for i = 1, #enabled do
    if enabled[i] == key then
      return i
    end
  end
  return 99
end

local function CollectClassActions(pack, enabled)
  local actions = {}
  local seen = {}
  local classFile = PlayerClassFile()
  local ids = CLASS_SPELLS[classFile]
  if type(ids) ~= "table" then
    ids = {}
    for _, more in pairs(CLASS_SPELLS) do
      for i = 1, #more do
        ids[#ids + 1] = more[i]
      end
    end
  end
  for i = 1, #ids do
    local baseId = ids[i]
    local name, useId, original = ResolveKnownSpell(baseId)
    if name and useId and not seen[useId] then
      local covered = SPELL_TYPES[baseId] or SPELL_TYPES[useId]
      local keep = {}
      if type(covered) == "table" then
        for t = 1, #covered do
          local key = covered[t]
          if ACTIONABLE_TYPES[key] and TypeEnabled(pack, key) then
            keep[#keep + 1] = key
          end
        end
      end
      if #keep > 0 then
        table.sort(keep, function(a, b)
          return TypeRank(enabled, a) < TypeRank(enabled, b)
        end)
        seen[useId] = true
        actions[#actions + 1] = {
          kind = "class",
          spellId = useId,
          baseId = original,
          name = name,
          types = keep,
          firstType = keep[1],
        }
      end
    end
  end
  table.sort(actions, function(a, b)
    local ra = TypeRank(enabled, a.firstType)
    local rb = TypeRank(enabled, b.firstType)
    if ra ~= rb then
      return ra < rb
    end
    return a.spellId < b.spellId
  end)
  return actions, seen
end

local function CollectCustomActions(pack, enabled, seen)
  local actions = {}
  local list = ns.EnsureCustomSpells(pack)
  for i = 1, #list do
    local row = list[i]
    if type(row) == "table" and row.enabled ~= false then
      local spellId = tonumber(row.spellId)
      if type(spellId) == "number" and Accessible(spellId) then
        local name, useId = ResolveKnownSpell(spellId)
        if not name then
          name = SpellName(spellId)
          useId = spellId
        end
        if type(name) == "string" and useId and not seen[useId] then
          local keep = {}
          local types = row.types
          if type(types) == "table" then
            for t = 1, #types do
              local key = types[t]
              if TypeEnabled(pack, key) then
                keep[#keep + 1] = key
              end
            end
          end
          if #keep > 0 then
            table.sort(keep, function(a, b)
              return TypeRank(enabled, a) < TypeRank(enabled, b)
            end)
            seen[useId] = true
            actions[#actions + 1] = {
              kind = "custom",
              spellId = useId,
              baseId = spellId,
              name = name,
              types = keep,
              firstType = keep[1],
              pet = row.pet == true,
            }
          end
        end
      end
    end
  end
  table.sort(actions, function(a, b)
    local ra = TypeRank(enabled, a.firstType)
    local rb = TypeRank(enabled, b.firstType)
    if ra ~= rb then
      return ra < rb
    end
    return a.spellId < b.spellId
  end)
  return actions
end

local function PublicItemCount(itemId)
  if type(itemId) ~= "number" then
    return 0
  end
  local count
  if C_Item and type(C_Item.GetItemCount) == "function" then
    count = Public(C_Item.GetItemCount(itemId, false, false, false, false))
  end
  if type(count) == "number" and count > 0 then
    return count
  end
  return 0
end

function ns.HasClassBattleRez()
  for i = 1, #BATTLE_REZ do
    if SpellInBook(BATTLE_REZ[i], true) then
      return true
    end
  end
  return false
end

local function SoulLinkState(pack)
  local enabled = pack and pack.mufs and pack.mufs.soulLinkFallback ~= false
  local hasBR = ns.HasClassBattleRez()
  local name = SpellName(SOUL_LINK_SPELL_ID)
  local count = PublicItemCount(SOUL_LINK_ITEM_ID)
  local knows = SpellInBook(SOUL_LINK_SPELL_ID, true)
  local carried = count > 0 or knows
  local available = enabled and (not hasBR) and carried
  return {
    enabled = enabled == true,
    available = available == true,
    hasClassBattleRez = hasBR,
    knows = knows,
    spellId = SOUL_LINK_SPELL_ID,
    itemId = SOUL_LINK_ITEM_ID,
    name = name,
    count = count,
  }
end

local function BlizzNames(keys)
  local names = {}
  local seen = {}
  for i = 1, #keys do
    local blizz = TYPE_BLIZZ[keys[i]]
    if type(blizz) == "string" and not seen[blizz] then
      seen[blizz] = true
      names[#names + 1] = blizz
    end
  end
  return names
end

local poisonProbeLogged = false

local function LogPoisonProbeOnce()
  if poisonProbeLogged then
    return
  end
  poisonProbeLogged = true
  ShowDiagnosticText("ZDecursive Detection Notice", {
    "Poison capability probe unavailable.",
    "Poison support remains disabled until the spellbook API reports a public result.",
  })
end

local function KnowsPoisonCleansingTotem()
  local sb = C_SpellBook
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if sb and type(sb.IsSpellInSpellBook) == "function" then
    local known
    if bank then
      known = sb.IsSpellInSpellBook(POISON_CLEANSING_TOTEM, bank, true)
    else
      known = sb.IsSpellInSpellBook(POISON_CLEANSING_TOTEM)
    end
    if not Accessible(known) then
      return nil
    end
    if known == true then
      return true
    end
    if known == false then
      return false
    end
    return nil
  end
  LogPoisonProbeOnce()
  return nil
end

function ns.GetEngineDispelGaps(_selfOnly)
  local classFile = PlayerClassFile()
  local poison = false
  if classFile == "SHAMAN" then
    poison = KnowsPoisonCleansingTotem() == true
  end
  if not poison then
    return nil
  end
  local names = {}
  if poison then
    names.Poison = true
  end
  return names
end

function ns.IsAllDispellableMode(pack)
  if type(pack) ~= "table" or type(pack.cure) ~= "table" then
    return false
  end
  local mode = pack.cure.filterMode or pack.cure.dispellableMode
  if mode == "ALL" or mode == "DISPELLABLE" then
    return true
  end
  return pack.cure.showAllDispellable == true
end

local function AuraToken(key, fallback)
  local filters = AuraUtil and AuraUtil.AuraFilters
  local token = filters and filters[key]
  token = Public(token)
  if type(token) == "string" and token ~= "" then
    return token
  end
  if type(fallback) == "string" and fallback ~= "" then
    return fallback
  end
  return nil
end

local function LiveMainFilter()
  local token = AuraToken("Dispellable")
  if token then
    return "HARMFUL|" .. token
  end
  local rpd = AuraToken("RaidPlayerDispellable", "RAID_PLAYER_DISPELLABLE")
  return "HARMFUL|" .. rpd
end

local function ActionableTypeMap(actions)
  local capable = {}
  for i = 1, type(actions) == "table" and #actions or 0 do
    local types = actions[i] and actions[i].types
    for t = 1, type(types) == "table" and #types or 0 do
      local key = types[t]
      if ACTIONABLE_TYPES[key] then
        capable[key] = true
      end
    end
  end
  return capable
end

local function BuildSlots(enabled, pack, actions)
  local allMode = ns.IsAllDispellableMode(pack)
  local mainFilter = LiveMainFilter()
  local enabledMap = {}
  for i = 1, #enabled do
    local key = enabled[i]
    if FRIENDLY_NATIVE[key] then
      enabledMap[key] = i
    end
  end
  local capable = ActionableTypeMap(actions)
  local slots = {}
  for i = 1, #TYPE_KEYS do
    local typeKey = TYPE_KEYS[i]
    local dispelType = TYPE_BLIZZ[typeKey]
    local priority = enabledMap[typeKey] or (#TYPE_KEYS + 1)
    local active = enabledMap[typeKey] ~= nil and (allMode or capable[typeKey] == true)
    local include = {}
    if active and dispelType then
      include[dispelType] = true
    end
    slots[#slots + 1] = {
      key = "dispel-" .. typeKey,
      filter = mainFilter,
      candidateFilters = {includeDispelTypes = include},
      mode = allMode and "all" or "byme",
      typeKey = typeKey,
      dispelType = dispelType,
      priority = priority,
      active = active,
    }
  end
  return slots
end

local function Signature(pack)
  local bits = {}
  local enabled = ns.GetEnabledTypes(pack)
  bits[#bits + 1] = table.concat(enabled, ",")
  local order = ns.EnsureCureOrder(pack)
  bits[#bits + 1] = table.concat(order, ",")
  local list = ns.EnsureCustomSpells(pack)
  for i = 1, #list do
    local row = list[i]
    if type(row) == "table" then
      bits[#bits + 1] = tostring(row.spellId) .. ":" .. tostring(row.enabled)
      local effectiveTypes = ns.GetActionableCureTypes(row.types)
      bits[#bits + 1] = table.concat(effectiveTypes, ",")
    end
  end
  local classFile = PlayerClassFile() or "?"
  bits[#bits + 1] = classFile
  local race = PlayerRaceFile() or "?"
  bits[#bits + 1] = race
  bits[#bits + 1] = tostring(KnowsPoisonCleansingTotem())
  bits[#bits + 1] = ns.IsAllDispellableMode(pack) and "all" or "byme"
  return table.concat(bits, "|")
end

function ns.InvalidateDetection()
  cache.signature = nil
  cache.model = nil
  smartRezCache = nil
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("Detection")
  end
end

function ns.GetDetectionModel(pack)
  pack = pack or GetPack()
  local sig = Signature(pack)
  if cache.model and cache.signature == sig then
    return cache.model
  end
  local enabled = ns.GetEnabledTypes(pack)
  local classActions, seen = CollectClassActions(pack, enabled)
  local customActions = CollectCustomActions(pack, enabled, seen)
  local actions = {}
  for i = 1, #classActions do
    actions[#actions + 1] = classActions[i]
  end
  for i = 1, #customActions do
    actions[#actions + 1] = customActions[i]
  end
  local slots = BuildSlots(enabled, pack, actions)
  local primary = actions[1]
  local model = {
    enabledTypes = enabled,
    order = ns.EnsureCureOrder(pack),
    actions = actions,
    classActions = classActions,
    customActions = customActions,
    slots = slots,
    filter = slots[1] and slots[1].filter or NATIVE_FILTER,
    primaryName = primary and primary.name or nil,
    primaryId = primary and primary.spellId or nil,
    soulLink = SoulLinkState(pack),
    engineGaps = ns.GetEngineDispelGaps(false),
  }
  cache.signature = sig
  cache.model = model
  return model
end

function ns.GetDetectionSlots(pack, unit)
  pack = pack or GetPack()
  local model = ns.GetDetectionModel(pack)
  return BuildSlots(model.enabledTypes, pack, model.actions)
end

function ns.GetAuraFilter(pack)
  local model = ns.GetDetectionModel(pack)
  return model.filter
end

function ns.GetPrimaryCure(pack)
  local model = ns.GetDetectionModel(pack)
  return model.primaryName, model.primaryId
end

function ns.GetKnownCures(pack)
  local model = ns.GetDetectionModel(pack)
  return model.actions
end

function ns.GetSoulLinkFallback(pack)
  local model = ns.GetDetectionModel(pack)
  return model.soulLink
end

function ns.GetSoulLinkState(pack)
  return ns.GetSoulLinkFallback(pack)
end

function ns.GetKnownRezSpellName(spellIDs)
  if type(spellIDs) ~= "table" then
    return nil
  end
  for i = 1, #spellIDs do
    local id = spellIDs[i]
    if SpellInBook(id, true) then
      local name = SpellName(id)
      if name then
        return name, id
      end
    end
  end
  return nil
end

function ns.GetSmartRezActions(pack)
  if InCombatLockdown and InCombatLockdown() then
    if type(smartRezCache) == "table" then
      return smartRezCache.battleRezName, smartRezCache.outOfCombatRezName, smartRezCache.combatSoulLink, smartRezCache.outOfCombatSoulLink
    end
    return nil, nil, false, false
  end
  local battleRezName = ns.GetKnownRezSpellName(BATTLE_REZ)
  local normalRezName = ns.GetKnownRezSpellName(NORMAL_REZ)
  local outOfCombatRezName = normalRezName or battleRezName
  local soul = ns.GetSoulLinkFallback(pack)
  local soulEnabled = soul and soul.enabled == true
  local carried = soul and type(soul.count) == "number" and soul.count > 0
  local hasCarriedSoulLink = soulEnabled and carried
  local combatSoulLink = hasCarriedSoulLink and not battleRezName
  local outOfCombatSoulLink = hasCarriedSoulLink and not outOfCombatRezName
  smartRezCache = {
    battleRezName = battleRezName,
    outOfCombatRezName = outOfCombatRezName,
    combatSoulLink = combatSoulLink,
    outOfCombatSoulLink = outOfCombatSoulLink,
  }
  return battleRezName, outOfCombatRezName, combatSoulLink, outOfCombatSoulLink
end

function ns.IsMUFRezEligibleUnitToken(unit)
  if type(unit) ~= "string" then
    return false
  end
  return not unit:lower():find("pet", 1, true)
end

local RANGE_FRIENDLY_SPEC = {
  [105] = 774,
  [102] = 8936,
  [103] = 8936,
  [104] = 8936,
  [256] = 17,
  [258] = 17,
  [257] = 2061,
  [65] = 19750,
  [66] = 19750,
  [70] = 19750,
  [262] = 8004,
  [263] = 8004,
  [264] = 8004,
  [268] = 116670,
  [269] = 116670,
  [270] = 116670,
  [1467] = 355913,
  [1468] = 355913,
  [1473] = 355913,
  [62] = 1459,
  [63] = 1459,
  [64] = 1459,
  [265] = 20707,
  [266] = 20707,
  [267] = 20707,
}

local RANGE_FRIENDLY_CLASS = {
  DRUID = 8936,
  PRIEST = 17,
  PALADIN = 19750,
  SHAMAN = 8004,
  MONK = 116670,
  EVOKER = 355913,
  MAGE = 1459,
  WARLOCK = 20707,
}

local RANGE_HOSTILE_CLASS = {
  DEATHKNIGHT = 47541,
  DEMONHUNTER = 185123,
  WARRIOR = 355,
}

local RANGE_REZ_CLASS = {
  DRUID = 20484,
  PRIEST = 2006,
  PALADIN = 7328,
  SHAMAN = 2008,
  MONK = 115178,
  DEATHKNIGHT = 61999,
  WARLOCK = 20707,
  EVOKER = 361227,
}

local function PlayerSpecId()
  local specialization = C_SpecializationInfo
  if type(specialization) ~= "table" or type(specialization.GetSpecialization) ~= "function" then
    return nil
  end
  local ok, index = pcall(specialization.GetSpecialization)
  index = ok and Public(index) or nil
  if type(index) ~= "number" then
    return nil
  end
  if type(specialization.GetSpecializationInfo) ~= "function" then
    return nil
  end
  local infoOK, info = pcall(specialization.GetSpecializationInfo, index)
  if not infoOK then
    return nil
  end
  local specId = type(info) == "table" and Public(info.id or info.specID) or Public(info)
  if type(specId) == "number" then
    return specId
  end
  return nil
end

local function KnownProbe(spellId)
  if type(spellId) ~= "number" or spellId <= 0 then
    return nil
  end
  if SpellInBook(spellId, true) then
    return spellId
  end
  return nil
end

local function SpellRangeResult(spellId, unit)
  if type(spellId) ~= "number" or not C_Spell or not C_Spell.IsSpellInRange then
    return nil
  end
  local result = C_Spell.IsSpellInRange(spellId, unit)
  if not Accessible(result) then
    return nil
  end
  if result == true or result == 1 then
    return true
  end
  if result == false or result == 0 then
    return false
  end
  return nil
end

local function InteractDistance(unit)
  if not CheckInteractDistance then
    return nil
  end
  local d = CheckInteractDistance(unit, 4)
  if not Accessible(d) then
    return nil
  end
  if d == true or d == 1 then
    return true
  end
  if d == false or d == 0 then
    return false
  end
  return d and true or false
end

local function FriendlyProbeId(spellId)
  local id = KnownProbe(RANGE_FRIENDLY_SPEC[PlayerSpecId()])
  if id then
    return id
  end
  id = KnownProbe(RANGE_FRIENDLY_CLASS[PlayerClassFile()])
  if id then
    return id
  end
  return KnownProbe(spellId)
end

local function HostileProbeId()
  return KnownProbe(RANGE_HOSTILE_CLASS[PlayerClassFile()])
end

local function RezProbeId()
  return KnownProbe(RANGE_REZ_CLASS[PlayerClassFile()])
end

function ns.SpellRangeState(unit, spell, spellId)
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  if unit == "player" or ns.IsPlayerUnit(unit) then
    return true
  end
  if not UnitExists then
    return false
  end
  local exists = UnitExists(unit)
  if not Accessible(exists) then
    return false
  end
  if exists ~= true then
    return false
  end
  if UnitPhaseReason then
    local phase = UnitPhaseReason(unit)
    if Accessible(phase) and phase then
      return false
    end
  end

  local inCombat = InCombatLockdown and InCombatLockdown()
  local friendlyId = FriendlyProbeId(spellId)
  local hostileId = HostileProbeId()
  local rezId = RezProbeId()

  if UnitCanAttack then
    local attack = UnitCanAttack("player", unit)
    if Accessible(attack) and attack then
      if not hostileId then
        return true
      end
      local hostile = SpellRangeResult(hostileId, unit)
      if hostile == true then
        return true
      end
      if hostile == false then
        return false
      end
    end
  end

  local friendly
  if friendlyId then
    friendly = SpellRangeResult(friendlyId, unit)
    if friendly == true then
      return true
    end
    if friendly == false then
      if not inCombat then
        local d = InteractDistance(unit)
        if d == true then
          return true
        end
      end
      return false
    end
  end

  if ns.IsUnitDeadPublic(unit) and rezId then
    local rez = SpellRangeResult(rezId, unit)
    if rez == true then
      return true
    end
    if rez == false then
      return false
    end
  end

  if not inCombat then
    local d = InteractDistance(unit)
    if d == true then
      return true
    end
    return false
  end

  if UnitInRange then
    local inRange, checked = UnitInRange(unit)
    if type(issecretvalue) == "function" and issecretvalue(inRange) then
      return false
    end
    if Accessible(checked) and checked == true and Accessible(inRange) then
      return inRange == true
    end
    local connected = true
    if UnitIsConnected then
      local c = UnitIsConnected(unit)
      if Accessible(c) then
        connected = c == true
      end
    end
    if not friendlyId and connected and not ns.IsUnitDeadPublic(unit) then
      return false
    end
    return false
  end

  if not friendlyId then
    return true
  end
  return false
end

function ns.IsSpellInRangePublic(unit, spell, spellId)
  return ns.SpellRangeState(unit, spell, spellId)
end

function ns.UnitInRangeKeep(unit, spell, spellId)
  return ns.SpellRangeState(unit, spell, spellId) == true
end

function ns.FilterRosterRange(units, pack)
  if type(units) ~= "table" then
    return units
  end
  if not pack or not pack.alerts or not pack.alerts.liveListOnlyInRange then
    return units
  end
  local spell, spellId = ns.GetPrimaryCure(pack)
  local kept = {}
  for i = 1, #units do
    local unit = units[i]
    if ns.UnitInRangeKeep(unit, spell, spellId) then
      kept[#kept + 1] = unit
    end
  end
  return kept
end

function ns.GetPublicInstanceType()
  if GetInstanceInfo then
    local _name, instanceType = GetInstanceInfo()
    instanceType = Public(instanceType)
    if type(instanceType) == "string" and instanceType ~= "" then
      return instanceType
    end
  end
  return nil
end

local function ReadRosterContext()
  local instanceType = ns.GetPublicInstanceType()
  local instanceClass = "UNKNOWN"
  if instanceType == "party" or instanceType == "scenario" then
    instanceClass = "PARTY"
  elseif type(instanceType) == "string" then
    instanceClass = "NONPARTY"
  end

  if IsInRaid then
    local ok, value = pcall(IsInRaid)
    value = ok and Public(value) or nil
    if value == true then
      rosterContext.kind = "RAID"
      rosterContext.ready = true
      rosterContext.reason = "IS_IN_RAID"
      rosterContext.instanceClass = instanceClass
      rosterContext.realPartyCount = 0
      return rosterContext
    end
    if value ~= false and value ~= nil then
      rosterContext.kind = "UNKNOWN"
      rosterContext.ready = false
      rosterContext.reason = "RAID_STATE_UNAVAILABLE"
      rosterContext.instanceClass = instanceClass
      rosterContext.realPartyCount = 0
      return rosterContext
    end
  end

  local realPartyCount
  if type(GetNumSubgroupMembers) == "function" then
    local ok, value = pcall(GetNumSubgroupMembers)
    value = ok and Public(value) or nil
    if type(value) == "number" and value >= 0 then
      realPartyCount = math.floor(value)
    end
  end

  rosterContext.instanceClass = instanceClass
  rosterContext.realPartyCount = realPartyCount or 0
  if instanceClass == "PARTY" then
    rosterContext.kind = "PARTY_INSTANCE"
    rosterContext.ready = true
    rosterContext.reason = "PARTY_INSTANCE_TYPE"
  elseif realPartyCount and realPartyCount > 0 then
    rosterContext.kind = "REAL_PARTY"
    rosterContext.ready = true
    rosterContext.reason = "PUBLIC_SUBGROUP_COUNT"
  elseif instanceClass == "NONPARTY" and realPartyCount == 0 then
    rosterContext.kind = "NO_PARTY"
    rosterContext.ready = true
    rosterContext.reason = "NONPARTY_ZERO_GROUP"
  else
    rosterContext.kind = "UNKNOWN"
    rosterContext.ready = false
    rosterContext.reason = "CONTEXT_CONVERGING"
  end
  return rosterContext
end

function ns.GetRosterContextStatus()
  local context = ReadRosterContext()
  return {
    kind = context.kind,
    ready = context.ready,
    instanceClass = context.instanceClass,
    realPartyCount = context.realPartyCount,
    reason = context.reason,
    transitionReason = rosterContext.transitionReason,
  }
end

local lastArenaHint

function ns.IsArenaInstance()
  if IsInInstance then
    local inInstance, instanceType = IsInInstance()
    instanceType = Public(instanceType)
    if instanceType == "arena" then
      lastArenaHint = "arena"
      return true
    end
    if lastArenaHint == "arena" and (instanceType == nil or instanceType == "" or instanceType == "none") then
      return true
    end
  end
  if IsActiveBattlefieldArena then
    local inArena = IsActiveBattlefieldArena()
    if IsTrue(inArena) then
      lastArenaHint = "arena"
      return true
    end
  end
  if C_PvP and C_PvP.IsArena and IsTrue(C_PvP.IsArena()) then
    lastArenaHint = "arena"
    return true
  end
  if ns.GetPublicInstanceType() == "arena" then
    lastArenaHint = "arena"
    return true
  end
  return lastArenaHint == "arena"
end

local function UnitPresent(unit)
  if not unit or not UnitExists then
    return unit ~= nil
  end
  local exists = UnitExists(unit)
  if not Accessible(exists) then
    return true
  end
  return exists == true
end

function ns.UnitExistsPublic(unit)
  return UnitPresent(unit)
end

local function IsPlayerToken(unit)
  if unit == "player" then
    return true
  end
  if UnitIsUnit then
    local same = UnitIsUnit(unit, "player")
    if Accessible(same) and same then
      return true
    end
  end
  return false
end

function ns.IsPlayerUnit(unit)
  return IsPlayerToken(unit)
end

local function IsPubliclyDead(unit)
  if not UnitIsDeadOrGhost then
    return false
  end
  local dead = UnitIsDeadOrGhost(unit)
  if not Accessible(dead) then
    return false
  end
  return dead == true
end

local function IsPubliclyUnavailable(unit)
  if IsPubliclyDead(unit) then
    return true
  end
  if UnitIsPlayer and UnitIsConnected then
    local isPlayer = UnitIsPlayer(unit)
    if not Accessible(isPlayer) or (isPlayer ~= true and isPlayer ~= 1) then
      return false
    end
    local connected = UnitIsConnected(unit)
    if Accessible(connected) and connected == false then
      return true
    end
  end
  return false
end

function ns.IsUnitDeadPublic(unit)
  return IsPubliclyDead(unit)
end

local function Now()
  if GetTime then
    return GetTime()
  end
  return 0
end

local function FollowerGuardActive()
  return Now() < follower.untilTime
end

local function IsCorePartyUnit(unit)
  return unit == "player" or (type(unit) == "string" and unit:match("^party[1-4]$") ~= nil)
end

local function CountCore(units)
  local count = 0
  for i = 1, #units do
    if IsCorePartyUnit(units[i]) then
      count = count + 1
    end
  end
  return count
end

local function GroupSize()
  local n
  if GetNumGroupMembers then
    n = Public(GetNumGroupMembers())
  end
  if type(n) == "number" and n > 0 then
    return n
  end
  return 0
end

local function ClearFollowerSnapshot()
  follower.units = nil
  follower.coreCount = 0
  follower.untilTime = 0
end

function ns.ResetRosterForWorldTransition(reason)
  follower.generation = follower.generation + 1
  ClearFollowerSnapshot()
  rosterContext.transitionReason = type(reason) == "string" and reason or "WORLD_TRANSITION"
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FOLLOWER_SNAPSHOT", {
      action = "CLEARED",
      generation = follower.generation,
      reason = rosterContext.transitionReason,
    }, false)
  end
  return true
end

function ns.PrepareWorldEntryRoster()
  if InCombatLockdown and InCombatLockdown() then
    return false, "combat"
  end
  local context = ReadRosterContext()
  if context.kind == "NO_PARTY" or context.kind == "RAID" then
    ClearFollowerSnapshot()
    return true, string.lower(context.kind)
  end
  if ns.ScheduleFollowerRosterGuard then
    ns.ScheduleFollowerRosterGuard()
  end
  return true, "group"
end

local function InStablePartyContext(context)
  context = context or ReadRosterContext()
  return context.kind == "PARTY_INSTANCE" or context.kind == "REAL_PARTY"
end

local function CaptureFollowerSnapshot(units, context)
  context = context or ReadRosterContext()
  if context.kind == "NO_PARTY" or context.kind == "RAID" then
    ClearFollowerSnapshot()
    return
  end
  if not InStablePartyContext(context) then
    return
  end
  local coreCount = CountCore(units)
  if coreCount < 2 then
    return
  end
  if FollowerGuardActive() and follower.units and coreCount < follower.coreCount then
    return
  end
  local copy = {}
  for i = 1, #units do
    copy[i] = units[i]
  end
  follower.coreCount = coreCount
  follower.units = copy
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FOLLOWER_SNAPSHOT", {
      action = "CAPTURED",
      rosterContext = context.kind,
      coreCount = coreCount,
    }, true)
  end
end

local function RestoreFollowerUnits(units, seen, context)
  context = context or ReadRosterContext()
  if context.kind == "NO_PARTY" or context.kind == "RAID" then
    ClearFollowerSnapshot()
    return units
  end
  if not InStablePartyContext(context) and context.kind ~= "UNKNOWN" then
    return units
  end
  if not FollowerGuardActive() or not follower.units then
    if context.kind == "UNKNOWN" then
      ClearFollowerSnapshot()
    end
    return units
  end
  if CountCore(units) >= follower.coreCount then
    return units
  end
  for i = 1, #follower.units do
    local unit = follower.units[i]
    if type(unit) == "string" and not seen[unit] then
      seen[unit] = true
      units[#units + 1] = unit
    end
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FOLLOWER_SNAPSHOT", {
      action = "RESTORED",
      rosterContext = context.kind,
      coreCount = follower.coreCount,
    }, false)
  end
  return units
end

function ns.ScheduleFollowerRosterGuard()
  follower.generation = follower.generation + 1
  local generation = follower.generation
  follower.untilTime = Now() + FOLLOWER_GUARD_SECONDS
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("FOLLOWER_GUARD", {
      action = "SCHEDULED",
      generation = generation,
      duration = FOLLOWER_GUARD_SECONDS,
      snapshotCount = follower.coreCount,
    }, false)
  end
  local timer = C_Timer
  if not timer or type(timer.After) ~= "function" then
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    if ns.RefreshLiveList then
      ns.RefreshLiveList()
    end
    if ns.RefreshAlerts then
      ns.RefreshAlerts()
    end
    return
  end
  for i = 1, #FOLLOWER_RETRY do
    local delay = FOLLOWER_RETRY[i]
    local passIndex = i
    timer.After(delay, function()
      if generation ~= follower.generation then
        if ns.DiagnosticRecord then
          ns.DiagnosticRecord("FOLLOWER_GUARD", {
            action = "CANCELLED",
            generation = generation,
            pass = passIndex,
          }, true)
        end
        return
      end
      if ns.RequestRosterReconcile then
        ns.RequestRosterReconcile("FOLLOWER_GUARD")
        return
      end
      if ns.RefreshMUFs then
        ns.RefreshMUFs()
      end
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
      end
    end)
  end
end

function ns.BeginRosterContextTransition(reason)
  rosterContext.transitionReason = type(reason) == "string" and reason or "CONTEXT_EVENT"
  ns.ScheduleFollowerRosterGuard()
end

local activeRosterAudit

local function CountRosterAudit(key)
  if activeRosterAudit then
    activeRosterAudit[key] = (activeRosterAudit[key] or 0) + 1
  end
end

local function RosterUnitCategory(unit)
  if unit == "player" then
    return "Player"
  end
  if unit == "pet" or type(unit) == "string" and unit:match("pet%d+$") then
    return "Pets"
  end
  if type(unit) == "string" and unit:match("^party%d+$") then
    return "Party"
  end
  if type(unit) == "string" and unit:match("^raid%d+$") then
    return "Raid"
  end
  return "Other"
end

local function AppendUnit(units, seen, unit, pack, allowMissing)
  CountRosterAudit("attempted")
  if type(unit) ~= "string" or seen[unit] then
    CountRosterAudit("omittedDuplicate")
    return
  end
  if unit:find("^arena%d+$") then
    CountRosterAudit("omittedArena")
    return
  end
  if not allowMissing and not UnitPresent(unit) then
    CountRosterAudit("omittedMissing")
    return
  end
  if pack.sorting and pack.sorting.includePlayer == false and IsPlayerToken(unit) then
    CountRosterAudit("omittedPlayer")
    return
  end
  if pack.sorting and pack.sorting.skipDead and IsPubliclyUnavailable(unit) then
    CountRosterAudit("omittedUnavailable")
    return
  end
  seen[unit] = true
  units[#units + 1] = unit
  CountRosterAudit("accepted" .. RosterUnitCategory(unit))
end

local function OwnerTokenForPet(unit)
  if unit == "pet" then
    return "player"
  end
  local partyIndex = type(unit) == "string" and unit:match("^partypet(%d+)$")
  if partyIndex then
    return "party" .. partyIndex
  end
  local raidIndex = type(unit) == "string" and unit:match("^raidpet(%d+)$")
  if raidIndex then
    return "raid" .. raidIndex
  end
  return nil
end

local function PairPetsWithOwners(units, pack)
  if type(units) ~= "table" then
    return units
  end
  local includePets = not pack or not pack.sorting or pack.sorting.includePets ~= false
  if pack and pack.cure and pack.cure.curePets == false then
    includePets = false
  end
  local owners = {}
  local petsByOwner = {}
  for i = 1, #units do
    local unit = units[i]
    if type(unit) == "string" then
      local owner = OwnerTokenForPet(unit)
      if owner then
        if not petsByOwner[owner] then
          petsByOwner[owner] = unit
        end
      else
        owners[#owners + 1] = unit
      end
    end
  end
  if pack and pack.sorting and pack.sorting.centerPlayer then
    local playerIndex
    for i = 1, #owners do
      if IsPlayerToken(owners[i]) then
        playerIndex = i
        break
      end
    end
    if playerIndex then
      local player = table.remove(owners, playerIndex)
      local centerIndex = math.floor(#owners / 2) + 1
      table.insert(owners, centerIndex, player)
    end
  end
  local out = {}
  local placed = {}
  local function place(unit)
    if type(unit) ~= "string" or placed[unit] or unit:find("^arena%d+$") then
      return
    end
    placed[unit] = true
    out[#out + 1] = unit
  end
  for i = 1, #owners do
    local owner = owners[i]
    place(owner)
    if includePets then
      local pet = petsByOwner[owner]
      if not pet and IsPlayerToken(owner) then
        pet = petsByOwner["player"]
      end
      if pet then
        place(pet)
      end
    end
  end
  for owner in pairs(petsByOwner) do
    if not placed[petsByOwner[owner]] then
      CountRosterAudit("omittedOrphanPet")
    end
  end
  return out
end

local function AppendPet(units, seen, owner, pack)
  if not pack.sorting or not pack.sorting.includePets then
    return
  end
  if pack.cure and pack.cure.curePets == false then
    return
  end
  if owner == "player" then
    AppendUnit(units, seen, "pet", pack)
    return
  end
  local partyIndex = type(owner) == "string" and owner:match("^party(%d+)$")
  if partyIndex then
    AppendUnit(units, seen, "partypet" .. partyIndex, pack)
    return
  end
  local raidIndex = type(owner) == "string" and owner:match("^raid(%d+)$")
  if raidIndex then
    AppendUnit(units, seen, "raidpet" .. raidIndex, pack)
  end
end

function ns.BuildRoster(pack)
  pack = pack or GetPack()
  activeRosterAudit = {}
  local units = {}
  local seen = {}
  local inArena = ns.IsArenaInstance()
  local size = GroupSize()
  local context = ReadRosterContext()
  if IsInRaid and IsInRaid() then
    local maxIndex = 40
    if inArena then
      if size > 0 and size < maxIndex then
        maxIndex = size
      else
        maxIndex = 5
      end
    elseif size > 0 and size < maxIndex then
      maxIndex = size
    end
    for i = 1, maxIndex do
      local unit = "raid" .. i
      AppendUnit(units, seen, unit, pack)
      AppendPet(units, seen, unit, pack)
    end
  else
    if not pack.sorting or pack.sorting.includePlayer ~= false then
      AppendUnit(units, seen, "player", pack)
      AppendPet(units, seen, "player", pack)
    end
    local partyMax = 4
    if inArena and size > 1 then
      partyMax = math.min(4, size - 1)
    end
    local allowParty = context.kind == "PARTY_INSTANCE" or context.kind == "REAL_PARTY"
    if allowParty then
      for i = 1, partyMax do
        local unit = "party" .. i
        AppendUnit(units, seen, unit, pack)
        AppendPet(units, seen, unit, pack)
      end
    end
  end
  RestoreFollowerUnits(units, seen, context)
  CaptureFollowerSnapshot(units, context)
  if ns.ApplyUnitLists then
    units = ns.ApplyUnitLists(units, pack)
  elseif ns.WrapRosterLists then
    units = ns.WrapRosterLists(units, pack)
  end
  local result = PairPetsWithOwners(units, pack)
  local audit = activeRosterAudit
  activeRosterAudit = nil
  audit.rosterContext = context.kind
  audit.contextReason = context.reason
  audit.resultCount = #result
  ns.LastRosterBuildDiagnostics = audit
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("ROSTER_BUILD", audit, true)
  end
  return result
end

function ns.GetLastRosterBuildDiagnostics()
  local source = ns.LastRosterBuildDiagnostics or {}
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

function ns.DetectionSummary(pack)
  local model = ns.GetDetectionModel(pack)
  local lines = {}
  local enabled = model.enabledTypes
  if #enabled == 0 then
    lines[#lines + 1] = "No affliction types enabled."
  else
    lines[#lines + 1] = "Order: " .. table.concat(enabled, " > ")
  end
  if #model.actions == 0 then
    lines[#lines + 1] = "No known public cure spells for this spec."
  else
    local classCount = 0
    local customCount = 0
    for i = 1, #model.actions do
      local action = model.actions[i]
      if action.kind == "custom" then
        customCount = customCount + 1
      else
        classCount = classCount + 1
      end
    end
    lines[#lines + 1] = "Public cure actions: class " .. tostring(classCount) .. ", custom " .. tostring(customCount)
  end
  local sl = model.soulLink
  if sl and sl.enabled then
    if sl.hasClassBattleRez then
      lines[#lines + 1] = "Soul Link idle: class battle-rez present"
    elseif sl.available then
      lines[#lines + 1] = "Soul Link fallback ready"
    else
      lines[#lines + 1] = "Soul Link fallback armed, item or spell not publicly counted"
    end
  end
  if ns.IsArenaInstance() then
    lines[#lines + 1] = "Arena instance: Live List and Alerts use group roster, not arenaN"
  end
  local slots = model.slots
  if type(slots) == "table" and slots[1] then
    lines[#lines + 1] = "Filter: " .. tostring(slots[1].filter) .. " (" .. tostring(slots[1].mode or "byme") .. ")"
    for i = 1, #slots do
      local slot = slots[i]
      lines[#lines + 1] = "Native type slot: " .. tostring(slot.dispelType or "NONE") .. " priority " .. tostring(slot.priority or 0) .. " " .. (slot.active and "active" or "inactive")
    end
  end
  lines[#lines + 1] = "Clicks: MUFs.lua type=macro + [@mouseover] macrotext. Detection paints only."
  return table.concat(lines, "\n")
end

function ns.ApplyDetectionSlots(container, pack, initFn, unit)
  if not container then
    return false
  end
  local slots = ns.GetDetectionSlots(pack, unit)
  if type(container._dcrSlotKeys) ~= "table" then
    container._dcrSlotKeys = {}
  end
  local inCombat = InCombatLockdown and InCombatLockdown()
  for i = 1, #slots do
    local slot = slots[i]
    if type(slot.filter) ~= "string" or slot.filter == "" or slot.filter == "HARMFUL" then
      slot.filter = LiveMainFilter(false)
    end
    local info = {
      initializeFrame = function(frame)
        if type(initFn) == "function" then
          initFn(frame, slot.key, slot)
        end
      end,
      candidateFilters = slot.candidateFilters,
    }
    if container._dcrSlotKeys[slot.key] then
      if container.SetAuraSlotFilterString then
        container:SetAuraSlotFilterString(slot.key, slot.filter)
      end
      if container.SetAuraSlotCandidateFilters then
        container:SetAuraSlotCandidateFilters(slot.key, slot.candidateFilters)
      end
    elseif container.AddAuraSlot then
      container:AddAuraSlot(slot.key, slot.filter, info)
      container._dcrSlotKeys[slot.key] = true
    else
      return false
    end
  end
  local wanted = {}
  for i = 1, #slots do
    wanted[slots[i].key] = true
  end
  if container.SetAuraSlotCandidateFilters and not inCombat then
    for key in pairs(container._dcrSlotKeys) do
      if not wanted[key] then
        container:SetAuraSlotCandidateFilters(key, {includeDispelTypes = {}})
      end
    end
  end
  return true
end

function ns.AttachDetectionContainer(container, unit, pack, initFn)
  diagnosticAttachAttempts = diagnosticAttachAttempts + 1
  if not container then
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return false
  end
  if type(unit) ~= "string" or unit == "" then
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return false
  end
  pack = pack or GetPack()
  local assigned, assignReason = ns.SafeNativeSetUnit(container, unit)
  if not assigned then
    pendingCombatSlots = assignReason == "DEFERRED_COMBAT" or pendingCombatSlots
    pendingRestrictionSlots = assignReason == "DEFERRED_RESTRICTION" or pendingRestrictionSlots
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return false
  end
  if not ns.ApplyDetectionSlots(container, pack, initFn, unit) then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return false
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  if not container._dcrDiagnosticAttached then
    container._dcrDiagnosticAttached = true
    diagnosticAttachments = diagnosticAttachments + 1
  end
  return true
end

function ns.AttachDetector(parent, unit, pack, initFn)
  diagnosticAttachAttempts = diagnosticAttachAttempts + 1
  if type(unit) ~= "string" or unit == "" then
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return nil
  end
  if not parent then
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return nil
  end
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  if not ok or not container then
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return nil
  end
  if container.SetAllPoints then
    container:SetAllPoints(parent)
  end
  if not (InCombatLockdown and InCombatLockdown()) then
    if container.EnableMouse then
      container:EnableMouse(false)
    end
  end
  if not container.SetUnit then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return nil
  end
  local assigned, assignReason = ns.SafeNativeSetUnit(container, unit)
  if not assigned then
    pendingCombatSlots = assignReason == "DEFERRED_COMBAT" or pendingCombatSlots
    pendingRestrictionSlots = assignReason == "DEFERRED_RESTRICTION" or pendingRestrictionSlots
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return container
  end
  if not ns.ApplyDetectionSlots(container, pack, initFn, unit) then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    diagnosticAttachFailures = diagnosticAttachFailures + 1
    return nil
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  if container.Show then
    container:Show()
  end
  if not container._dcrDiagnosticAttached then
    container._dcrDiagnosticAttached = true
    diagnosticAttachments = diagnosticAttachments + 1
  end
  return container
end

function ns.GetDispelColorMap(pack)
  if not CreateColor then
    return nil
  end
  pack = pack or GetPack()
  local colors = pack.colors
  if type(colors) ~= "table" then
    return nil
  end
  local function C(c)
    if type(c) ~= "table" then
      return nil
    end
    return CreateColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
  end
  return {
    Magic = C(colors.magic),
    Curse = C(colors.curse),
    Poison = C(colors.poison),
    Disease = C(colors.disease),
  }
end

ns.DETECTION_TYPES = TYPE_KEYS
ns.ACTIONABLE_CURE_TYPE_SET = ACTIONABLE_TYPES
ns.BY_ME_DISPEL_FILTER = BY_ME_FILTER
ns.ALL_DISPEL_FILTER = ALL_FILTER
ns.NATIVE_DISPEL_FILTER = ALL_FILTER
ns.GAP_DISPEL_FILTER = GAP_FILTER
ns.SOUL_LINK_SPELL_ID = SOUL_LINK_SPELL_ID
ns.SOUL_LINK_ITEM_ID = SOUL_LINK_ITEM_ID
ns.POISON_CLEANSING_TOTEM = POISON_CLEANSING_TOTEM

-- USER_NOTIFICATION_SINK_BEGIN
local function NotifyUser(msg)
  local addon = Addon()
  if addon and addon.Print then
    addon:Print(msg)
    return
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff52dbd1Decursive|r " .. msg)
  end
end
-- USER_NOTIFICATION_SINK_END

local function AppendTextLines(lines, text)
  if not Accessible(text) or type(text) ~= "string" or text == "" then
    return
  end
  local startAt = 1
  while true do
    local stopAt = string.find(text, "\n", startAt, true)
    if not stopAt then
      lines[#lines + 1] = string.sub(text, startAt)
      return
    end
    if stopAt > startAt then
      lines[#lines + 1] = string.sub(text, startAt, stopAt - 1)
    end
    startAt = stopAt + 1
  end
end

local function BuildAddonStatusLines(pack)
  pack = pack or GetPack()
  local addon = Addon()
  local version
  if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
    local ok, value = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
    if ok then
      version = value
    end
  end
  version = Public(version)
  local lines = {}
  if type(version) == "string" and version ~= "" then
    lines[#lines + 1] = "Zhaohu's Decursive " .. version
  else
    lines[#lines + 1] = "Zhaohu's Decursive"
  end
  if addon and addon.db then
    lines[#lines + 1] = "profile state: loaded"
  else
    lines[#lines + 1] = "profile state: unavailable"
  end
  if addon and addon.GetEditingEnvironment then
    local environment = Public(addon:GetEditingEnvironment())
    if type(environment) == "string" and environment ~= "" then
      lines[#lines + 1] = "editing environment: " .. environment
    else
      lines[#lines + 1] = "editing environment: unavailable"
    end
  end
  if addon and addon.GetSpecAssignment then
    local row, spec = addon:GetSpecAssignment()
    if Accessible(spec) and spec then
      if type(row) == "table" and row.enabled == true then
        lines[#lines + 1] = "spec assignment: enabled"
      else
        lines[#lines + 1] = "spec assignment: off"
      end
    else
      lines[#lines + 1] = "spec assignment: dormant this login"
    end
  end
  if ns.DetectionSummary then
    local summary = ns.DetectionSummary(pack)
    AppendTextLines(lines, summary)
  end
  local mufs = type(pack) == "table" and pack.mufs or nil
  local cure = type(pack) == "table" and pack.cure or nil
  local advanced = type(pack) == "table" and pack.advanced or nil
  local mode = "AUTO"
  if type(cure) == "table" and cure.mode == "MANUAL" then
    mode = "MANUAL"
  end
  local poolMax = 80
  local mufShow = true
  if type(mufs) == "table" then
    if type(mufs.maxUnits) == "number" then
      poolMax = mufs.maxUnits
    end
    mufShow = mufs.show ~= false
  end
  lines[#lines + 1] = "MUF show: " .. (mufShow and "on" or "off")
  lines[#lines + 1] = "MUF pool max: " .. tostring(poolMax)
  lines[#lines + 1] = "click mode: " .. mode
  local combat = InCombatLockdown and InCombatLockdown()
  if combat then
    lines[#lines + 1] = "combat: in combat"
  else
    lines[#lines + 1] = "combat: out of combat"
  end
  local macro = type(advanced) == "table" and advanced.customMacro or nil
  if type(macro) == "string" and macro ~= "" then
    lines[#lines + 1] = "customMacro: " .. tostring(#macro) .. " bytes"
  else
    lines[#lines + 1] = "customMacro: empty"
  end
  return lines
end

function ns.PrintAddonStatus(pack)
  return ShowDiagnosticText("ZDecursive Status", BuildAddonStatusLines(pack))
end

function ns.PrintSlashHelp()
  return ShowDiagnosticText("ZDecursive Commands", {
    "/zdecursive /zd /dcr  options",
    "/dcrhelp  this list",
    "/dcrstatus  sanitized profile, environment, spec, and MUF status",
    "/dcrdiag  sanitized API, combat, pack, and macro status",
    "/dcrreport  sanitized identity plus diagnostics",
    "/dcridentity  sanitized identity and specialization state",
    "/dcridentity alldebuffs  native tooltip HARMFUL vs dispellable",
    "/dcralerts [on|off|status|move]  editing-pack alerts, drag text",
    "/dcralertdiag  aura sound diagnostic",
    "/dcrreset [pack|profile|all]  reset editing pack by default",
    "/dcrpr /dcrsk  priority and skip lists",
    "/dcrsoullink [on|off|status]  emergency Soul Link fallback",
    "/dcrsoullinkstatus  sanitized Soul Link status",
    "/zdsound [public spell] [unit]  aura sound diagnostic",
  })
end

local MACRO_BYTE_LIMIT = 255
local MACRO_STRING_KEYS = {
  customMacro = true,
  customMacroLeft = true,
  customMacroRight = true,
  customMacroShift = true,
  customMacroCtrl = true,
  customMacroAlt = true,
  mouseoverMacro = true,
  userMacro = true,
  macrotext = true,
}

ns.lastMacroDrops = 0

local function DropMacroString(parent, key)
  local value = parent[key]
  if type(value) ~= "string" then
    return 0
  end
  if #value <= MACRO_BYTE_LIMIT then
    return 0
  end
  parent[key] = nil
  return 1
end

local function DropMacroTable(tbl)
  local dropped = 0
  if type(tbl) ~= "table" then
    return 0
  end
  for key, value in pairs(tbl) do
    if type(value) == "string" then
      if #value > MACRO_BYTE_LIMIT then
        tbl[key] = nil
        dropped = dropped + 1
      end
    elseif type(value) == "table" then
      dropped = dropped + DropMacroTable(value)
    end
  end
  return dropped
end

function ns.DropOversizedMacros(pack)
  local dropped = 0
  if type(pack) ~= "table" then
    return 0
  end
  local mufs = pack.mufs
  if type(mufs) == "table" then
    for key in pairs(MACRO_STRING_KEYS) do
      dropped = dropped + DropMacroString(mufs, key)
    end
    if type(mufs.customMacros) == "table" then
      dropped = dropped + DropMacroTable(mufs.customMacros)
    end
  end
  local advanced = pack.advanced
  if type(advanced) == "table" then
    for key in pairs(MACRO_STRING_KEYS) do
      dropped = dropped + DropMacroString(advanced, key)
    end
    if type(advanced.customMacros) == "table" then
      dropped = dropped + DropMacroTable(advanced.customMacros)
    end
  end
  ns.lastMacroDrops = (ns.lastMacroDrops or 0) + dropped
  return dropped
end

function ns.IdentityShowAllDebuffs()
  local addon = Addon()
  if addon and addon.db and addon.db.global then
    return addon.db.global.identityShowAllDebuffs == true
  end
  return ns.identityShowAllDebuffs == true
end

function ns.SetIdentityShowAllDebuffs(enabled)
  local on = enabled == true
  ns.identityShowAllDebuffs = on
  local addon = Addon()
  if addon and addon.db and addon.db.global then
    addon.db.global.identityShowAllDebuffs = on
  end
end

local BuildIdentityLines

function ns.PrintIdentity(msg)
  local cmd = ""
  if type(msg) == "string" then
    cmd = msg:match("^%s*(.-)%s*$") or ""
    cmd = cmd:lower()
  end
  if cmd == "alldebuffs" then
    local on = not ns.IdentityShowAllDebuffs()
    ns.SetIdentityShowAllDebuffs(on)
    if on then
      NotifyUser("Native tooltip will show ALL harmful debuffs.")
    else
      NotifyUser("Native tooltip will show dispellable debuffs only.")
    end
    NotifyUser("Identity alldebuffs applies on /reload.")
    return
  end
  return ShowDiagnosticText("ZDecursive Identity", BuildIdentityLines())
end

BuildIdentityLines = function()
  local addon = Addon()
  local lines = {"identity (sanitized)"}
  if addon and addon.GetCharacterKey then
    lines[#lines + 1] = "character identity: available"
  else
    lines[#lines + 1] = "character identity: unavailable"
  end
  local className, classFile
  if UnitClass then
    className, classFile = UnitClass("player")
  end
  className = Public(className)
  classFile = Public(classFile)
  if type(className) == "string" and className ~= "" and type(classFile) == "string" and classFile ~= "" then
    lines[#lines + 1] = "class data: public"
  else
    lines[#lines + 1] = "class data: unavailable"
  end
  local current
  if addon and addon.GetSpecIndex then
    current = Public(addon:GetSpecIndex())
  end
  if type(current) == "number" then
    lines[#lines + 1] = "current specialization: active"
  else
    lines[#lines + 1] = "current specialization: dormant this login"
  end
  if addon and addon.EnsureSpecAssignments then
    local specMap = addon:EnsureSpecAssignments()
    local count = addon.SpecSlotCount and addon:SpecSlotCount() or 4
    if not Accessible(count) or type(count) ~= "number" or count < 1 or count > 16 then
      count = 4
    end
    local enabledCount = 0
    local offCount = 0
    for spec = 1, count do
      local row = specMap and specMap[spec]
      if type(row) == "table" and row.enabled then
        enabledCount = enabledCount + 1
      else
        offCount = offCount + 1
      end
    end
    lines[#lines + 1] = "specialization assignments: enabled " .. tostring(enabledCount) .. ", off " .. tostring(offCount)
  end
  if addon and addon.db then
    lines[#lines + 1] = "resolved profile: ready"
  else
    lines[#lines + 1] = "resolved profile: unavailable"
  end
  if ns.IdentityShowAllDebuffs() then
    lines[#lines + 1] = "identity tooltip: ALL harmful debuffs"
  else
    lines[#lines + 1] = "identity tooltip: dispellable plus alldebuffs carrier"
  end
  return lines
end

local function HasAPI(root, name)
  return type(root) == "table" and type(root[name]) == "function"
end

local function BuildDiagnosticLines()
  local lines = {
    "display path: AuraContainer + AddAuraSlot",
    "C_UnitAuras.AddAuraSound: " .. (HasAPI(C_UnitAuras, "AddAuraSound") and "yes" or "no"),
    "C_Spell.IsSpellInRange: " .. (HasAPI(C_Spell, "IsSpellInRange") and "yes" or "no"),
    "InCombatLockdown: " .. tostring(InCombatLockdown and InCombatLockdown() or false),
    "InChatMessagingLockdown: " .. tostring(InChatMessagingLockdown and InChatMessagingLockdown() or false),
    "canaccessvalue: " .. (type(canaccessvalue) == "function" and "yes" or "no"),
    "issecretvalue: " .. (type(issecretvalue) == "function" and "yes" or "no"),
    "macro byte drop last pass: " .. tostring(ns.lastMacroDrops or 0),
  }
  local addon = Addon()
  if addon and addon.db and addon.db.profile and type(addon.db.profile.lists) == "table" then
    local lists = addon.db.profile.lists
    local prio = type(lists.priority) == "table" and #lists.priority or 0
    local skip = type(lists.skip) == "table" and #lists.skip or 0
    lines[#lines + 1] = "lists: prio " .. tostring(prio) .. " skip " .. tostring(skip)
  end
  return lines
end

function ns.PrintReport()
  local lines = BuildIdentityLines()
  lines[#lines + 1] = ""
  AppendTextLines(lines, "status")
  local statusLines = BuildAddonStatusLines()
  for i = 1, #statusLines do
    lines[#lines + 1] = statusLines[i]
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "diagnostics"
  local diagnosticLines = BuildDiagnosticLines()
  for i = 1, #diagnosticLines do
    lines[#lines + 1] = diagnosticLines[i]
  end
  return ShowDiagnosticText("ZDecursive Report", lines)
end

function ns.PrintDiagnostics()
  local lines = BuildAddonStatusLines()
  lines[#lines + 1] = ""
  lines[#lines + 1] = "diagnostics"
  local diagnosticLines = BuildDiagnosticLines()
  for i = 1, #diagnosticLines do
    lines[#lines + 1] = diagnosticLines[i]
  end
  return ShowDiagnosticText("ZDecursive Diagnostics", lines)
end

function ns.ToggleSoulLinkFallback()
  local pack = GetPack()
  if type(pack) ~= "table" then
    return false
  end
  if type(pack.mufs) ~= "table" then
    pack.mufs = {}
  end
  local currentlyEnabled = pack.mufs.soulLinkFallback ~= false
  pack.mufs.soulLinkFallback = not currentlyEnabled
  ns.InvalidateDetection()
  if ns.Notify then
    ns.Notify()
  end
  local state = pack.mufs.soulLinkFallback == false and "disabled" or "enabled"
  NotifyUser("Emergency Soul Link fallback " .. state .. ".")
  return pack.mufs.soulLinkFallback ~= false
end

function ns.PrintSoulLinkStatus()
  local sl = ns.GetSoulLinkState()
  local lines = {
    "toggle: " .. (sl.enabled and "on" or "off"),
    "carried count: " .. tostring(sl.count),
    "spellbook state: " .. (sl.knows and "known" or "not publicly known"),
    "class battle-rez: " .. (sl.hasClassBattleRez and "yes" or "no"),
    "available: " .. (sl.available and "yes" or "no"),
  }
  return ShowDiagnosticText("ZDecursive Soul Link Status", lines)
end

function ns.HandleSoulLinkSlash(msg)
  msg = strtrim(msg or "")
  local cmd = string.lower(msg)
  if cmd == "status" or cmd == "show" or cmd == "info" then
    ns.PrintSoulLinkStatus()
    return
  end
  if cmd == "on" then
    local pack = GetPack()
    if pack and pack.mufs then
      pack.mufs.soulLinkFallback = true
      ns.InvalidateDetection()
      if ns.Notify then
        ns.Notify()
      end
    end
    NotifyUser("Emergency Soul Link fallback enabled.")
    return
  end
  if cmd == "off" then
    local pack = GetPack()
    if pack and pack.mufs then
      pack.mufs.soulLinkFallback = false
      ns.InvalidateDetection()
      if ns.Notify then
        ns.Notify()
      end
    end
    NotifyUser("Emergency Soul Link fallback disabled.")
    return
  end
  ns.ToggleSoulLinkFallback()
end

function ns.EnableDetection()
  if eventsOn then
    return
  end
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Detection", false)
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if ns.DetectionEngine and ns.addon and (
      event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD"
    ) then
      -- Core owns roster and world transactions. A second direct consumer
      -- refresh here can race the canonical signature and native carrier bank.
      return
    end
    local unit = arg1
    ns.InvalidateDetection()
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
      ns.RememberRestrictionState(arg1, arg2)
      if ns.DetectionEngine then
        -- DetectionEngine owns restriction recovery and the required-consumer
        -- transaction. Do not race it with a direct MUF refresh.
        return
      end
      pendingRestrictionSlots = false
      if ns.RefreshMUFs then
        ns.RefreshMUFs()
      end
      return
    end
    if event == "PLAYER_REGEN_ENABLED" then
      pendingCombatSlots = false
      if not ns.HasActiveAddonRestriction() then
        pendingRestrictionSlots = false
      end
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
      end
      if (not ns.addon or type(ns.addon.OnRegenEnabled) ~= "function") and ns.RefreshMUFs then
        ns.RefreshMUFs()
      end
      return
    end
    if event == "UNIT_IN_RANGE_UPDATE" then
      local pet
      if unit == "player" then
        pet = "pet"
      elseif type(unit) == "string" then
        local party = unit:match("^party(%d+)$")
        if party then
          pet = "partypet" .. party
        end
        local raid = unit:match("^raid(%d+)$")
        if raid then
          pet = "raidpet" .. raid
        end
      end
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" or event == "TRAIT_CONFIG_UPDATED" then
      ns.ScheduleFollowerRosterGuard()
    end
    local talentEvent = event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE"
    if talentEvent and InCombatLockdown and InCombatLockdown() then
      pendingCombatSlots = true
      if ns.RefreshOptions then
        ns.RefreshOptions()
      end
      return
    end
    if talentEvent then
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
      end
      if ns.RefreshCureEnginePanel then
        ns.RefreshCureEnginePanel()
      end
      if ns.RefreshOptions then
        ns.RefreshOptions()
      end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then
      if GroupSize() < 2 then
        ClearFollowerSnapshot()
      end
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
      end
      if ns.RefreshMUFs then
        ns.RefreshMUFs()
      end
    end
  end)
  eventFrame:RegisterEvent("SPELLS_CHANGED")
  eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  eventFrame:RegisterEvent("UNIT_PET")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  eventFrame:RegisterEvent("UNIT_IN_RANGE_UPDATE")
  local extra = {
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_TALENT_UPDATE",
    "ADDON_RESTRICTION_STATE_CHANGED",
  }
  for i = 1, #extra do
    local name = extra[i]
    local ok = true
    if C_EventUtils and C_EventUtils.IsEventValid then
      ok = C_EventUtils.IsEventValid(name) == true
    end
    if ok then
      eventFrame:RegisterEvent(name)
    end
  end
  local addon = Addon()
  if addon and addon.RegisterChatCommand then
    addon:RegisterChatCommand("dcridentity", function(msg)
      ns.PrintIdentity(msg)
    end)
  end
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Detection", true)
  end
end

ns.Detection = {
  Accessible = ns.IsAccessible,
  Public = ns.PublicValue,
  Roster = ns.BuildRoster,
  FilterRange = ns.FilterRosterRange,
  InRange = ns.UnitInRangeKeep,
  ApplySlots = ns.ApplyDetectionSlots,
  Attach = ns.AttachDetector,
  Restriction = ns.HasActiveAddonRestriction,
  SoulLink = ns.GetSoulLinkState,
  InArena = ns.IsArenaInstance,
  EngineGaps = ns.GetEngineDispelGaps,
  Invalidate = ns.InvalidateDetection,
  Enable = ns.EnableDetection,
}

local function DiagnosticRosterCounts()
  local counts = {player = 0, party = 0, raid = 0, pets = 0, total = 0}
  local function Count(unit, category)
    if type(UnitExists) ~= "function" then
      return
    end
    local ok, exists = pcall(UnitExists, unit)
    local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(exists) or nil
    if ok and public == true then
      counts[category] = counts[category] + 1
      counts.total = counts.total + 1
    end
  end
  Count("player", "player")
  Count("pet", "pets")
  for i = 1, 4 do
    Count("party" .. tostring(i), "party")
    Count("partypet" .. tostring(i), "pets")
  end
  for i = 1, 40 do
    Count("raid" .. tostring(i), "raid")
    Count("raidpet" .. tostring(i), "pets")
  end
  return counts
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("Detection", function()
    local model = ns.GetDetectionModel(GetPack())
    return {
      eventsRegistered = eventsOn,
      attachmentAttempts = diagnosticAttachAttempts,
      attachments = diagnosticAttachments,
      attachmentFailures = diagnosticAttachFailures,
      attachmentPendingCombat = pendingCombatSlots,
      attachmentPendingRestriction = pendingRestrictionSlots,
      restrictionActive = ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction() or false,
      actionableTypeCount = #TYPE_KEYS,
      enabledActionableTypeCount = #model.enabledTypes,
      knownCureActionCount = #model.actions,
      customCureActionCount = #model.customActions,
      rosterTokenCounts = DiagnosticRosterCounts(),
      rosterContext = rosterContext.kind,
      rosterContextReady = rosterContext.ready,
      rosterInstanceClass = rosterContext.instanceClass,
      rosterRealPartyCount = rosterContext.realPartyCount,
      rosterContextTransitionReason = rosterContext.transitionReason,
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Detection")
end
