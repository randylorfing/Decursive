local ADDON_NAME, ns = ...

local TYPE_KEYS = {"magic", "curse", "poison", "disease", "enrage", "charm", "bleed"}

local TYPE_BLIZZ = {
  magic = "Magic",
  curse = "Curse",
  poison = "Poison",
  disease = "Disease",
  enrage = "Enrage",
  charm = "Magic",
  bleed = "Bleed",
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
  DRUID = {88423, 2782, 2908},
  SHAMAN = {77130, 51886},
  MONK = {115450, 218164},
  EVOKER = {360823, 365585, 374251},
  MAGE = {475},
  WARLOCK = {89808},
  HUNTER = {19801},
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
  [374251] = {"bleed", "poison", "curse", "disease"},
  [475] = {"curse"},
  [89808] = {"magic"},
  [2908] = {"enrage"},
  [19801] = {"enrage"},
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

local eventsOn = false
local eventFrame
local pendingCombatSlots = false
local pendingRestrictionSlots = false
local restrictionState = {}

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

function ns.HasActiveAddonRestriction()
  local api = C_RestrictedActions
  local types = Enum and Enum.AddOnRestrictionType
  local states = Enum and Enum.AddOnRestrictionState
  local inactive = RestrictionInactive()
  local activating = states and states.Activating
  local active = RestrictionActiveToken()
  if type(api) ~= "table" then
    return false
  end
  if type(types) == "table" then
    for _name, restrictionType in pairs(types) do
      if type(restrictionType) == "number" then
        local state = restrictionState[restrictionType]
        if state == activating or state == active then
          return true
        end
        if state == nil and api.GetAddOnRestrictionState then
          local latest = Public(api.GetAddOnRestrictionState(restrictionType))
          if type(latest) == "number" then
            restrictionState[restrictionType] = latest
            state = latest
          else
            restrictionState[restrictionType] = active
            state = active
          end
        end
        if type(state) == "number" and state ~= inactive then
          return true
        end
      end
    end
    return false
  end
  if api.IsAddOnRestrictionActive then
    return IsTrue(api.IsAddOnRestrictionActive())
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
  if addon and addon.GetEditingPack then
    return addon:GetEditingPack()
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
  if IsPlayerSpell and IsTrue(IsPlayerSpell(spellId)) then
    return true
  end
  if IsSpellKnown and IsTrue(IsSpellKnown(spellId)) then
    return true
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
  if type(pack) ~= "table" or type(pack.cure) ~= "table" then
    return true
  end
  if key == "charm" then
    return pack.cure.charm ~= false or pack.cure.magicCharmed ~= false
  end
  if pack.cure[key] == false then
    return false
  end
  return true
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
  if C_Item and C_Item.GetItemCount then
    count = Public(C_Item.GetItemCount(itemId, false, false, false, false))
  elseif GetItemCount then
    count = Public(GetItemCount(itemId, false))
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
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff52dbd1Decursive|r cannot test for Poison Cleansing Totem. No poison gap.")
  end
end

local function KnowsPoisonCleansingTotem()
  local sb = C_SpellBook
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if sb and bank and sb.IsSpellInSpellBook then
    local known = sb.IsSpellInSpellBook(POISON_CLEANSING_TOTEM, bank, true)
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
  if IsPlayerSpell then
    local known = IsPlayerSpell(POISON_CLEANSING_TOTEM)
    if not Accessible(known) then
      return nil
    end
    if known == true then
      return true
    end
    if known == false then
      return false
    end
  end
  LogPoisonProbeOnce()
  return nil
end

function ns.GetEngineDispelGaps(selfOnly)
  local classFile = PlayerClassFile()
  local poison = false
  if classFile == "SHAMAN" then
    poison = KnowsPoisonCleansingTotem() == true
  end
  local bleed = false
  if selfOnly then
    local race = PlayerRaceFile()
    bleed = race == "Dwarf"
  end
  if not poison and not bleed then
    return nil
  end
  local names = {}
  if poison then
    names.Poison = true
  end
  if bleed then
    names.Bleed = true
  end
  return names
end

local function MapSize(map)
  if type(map) ~= "table" then
    return 0
  end
  local n = 0
  for _ in pairs(map) do
    n = n + 1
  end
  return n
end

local function BlizzMap(keys)
  local names = {}
  for i = 1, #keys do
    local blizz = TYPE_BLIZZ[keys[i]]
    if type(blizz) == "string" then
      names[blizz] = true
    end
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

local function LiveMainFilter(allMode)
  if allMode then
    local token = AuraToken("Dispellable")
    if token then
      return "HARMFUL|" .. token
    end
  end
  local rpd = AuraToken("RaidPlayerDispellable", "RAID_PLAYER_DISPELLABLE")
  return "HARMFUL|" .. rpd
end

local function LiveGapFilter()
  local rpd = AuraToken("RaidPlayerDispellable", "RAID_PLAYER_DISPELLABLE")
  return "HARMFUL|!" .. rpd
end

local function BuildSlots(enabled, pack, selfOnly)
  local allMode = ns.IsAllDispellableMode(pack)
  local mainFilter = LiveMainFilter(allMode)
  local nativeKeys = {}
  for i = 1, #enabled do
    local key = enabled[i]
    if FRIENDLY_NATIVE[key] then
      nativeKeys[#nativeKeys + 1] = key
    end
  end
  local slots = {}
  local nativeMap = BlizzMap(nativeKeys)
  local nativeCount = MapSize(nativeMap)
  local main = {
    key = "dispel",
    filter = mainFilter,
    candidateFilters = nil,
    mode = allMode and "all" or "byme",
  }
  if nativeCount > 0 and nativeCount < 4 then
    main.candidateFilters = {includeDispelTypes = nativeMap}
  elseif nativeCount == 0 then
    main = nil
  end
  if main then
    slots[#slots + 1] = main
  end
  if not allMode then
    local gap = ns.GetEngineDispelGaps(selfOnly)
    if type(gap) == "table" then
      if pack and pack.cure and pack.cure.poison == false then
        gap.Poison = nil
      end
      if pack and pack.cure and pack.cure.bleed == false then
        gap.Bleed = nil
      end
      if MapSize(gap) > 0 then
        slots[#slots + 1] = {
          key = "gap",
          filter = LiveGapFilter(),
          candidateFilters = {includeDispelTypes = gap},
        }
      end
    end
  end
  if #slots == 0 then
    slots[1] = {
      key = "dispel",
      filter = mainFilter,
      candidateFilters = nil,
      mode = allMode and "all" or "byme",
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
  local slots = BuildSlots(enabled, pack, false)
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
  local selfOnly = false
  if type(unit) == "string" and unit ~= "" then
    selfOnly = ns.IsPlayerUnit(unit) == true
  end
  return BuildSlots(model.enabledTypes, pack, selfOnly)
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
  local index
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    index = Public(C_SpecializationInfo.GetSpecialization())
  elseif GetSpecialization then
    index = Public(GetSpecialization())
  end
  if type(index) ~= "number" then
    return nil
  end
  local specId
  if GetSpecializationInfo then
    specId = Public(GetSpecializationInfo(index))
  elseif C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    local info = C_SpecializationInfo.GetSpecializationInfo(index)
    if type(info) == "table" then
      specId = Public(info.id or info.specID)
    else
      specId = Public(info)
    end
  end
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

local function CaptureFollowerSnapshot(units)
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
end

local function RestoreFollowerUnits(units, seen)
  if not FollowerGuardActive() or not follower.units then
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
  return units
end

function ns.ScheduleFollowerRosterGuard()
  follower.generation = follower.generation + 1
  local generation = follower.generation
  follower.untilTime = Now() + FOLLOWER_GUARD_SECONDS
  local timer = C_Timer
  if not timer or type(timer.After) ~= "function" then
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
    timer.After(delay, function()
      if generation ~= follower.generation then
        return
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

local function AppendUnit(units, seen, unit, pack, allowMissing)
  if type(unit) ~= "string" or seen[unit] then
    return
  end
  if unit:find("^arena%d+$") then
    return
  end
  if not allowMissing and not UnitPresent(unit) then
    return
  end
  if pack.sorting and pack.sorting.includePlayer == false and IsPlayerToken(unit) then
    return
  end
  if pack.sorting and pack.sorting.skipDead and IsPubliclyDead(unit) then
    return
  end
  seen[unit] = true
  units[#units + 1] = unit
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

function ns.BuildRoster(pack)
  pack = pack or GetPack()
  local units = {}
  local seen = {}
  local inArena = ns.IsArenaInstance()
  local size = GroupSize()
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
    if IsInGroup and IsInGroup() then
      for i = 1, partyMax do
        local unit = "party" .. i
        AppendUnit(units, seen, unit, pack)
        AppendPet(units, seen, unit, pack)
      end
    end
  end
  RestoreFollowerUnits(units, seen)
  CaptureFollowerSnapshot(units)
  if ns.WrapRosterLists then
    return ns.WrapRosterLists(units, pack)
  end
  if ns.ApplyUnitLists then
    return ns.ApplyUnitLists(units, pack)
  end
  return units
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
    for i = 1, #model.actions do
      local action = model.actions[i]
      local tag = action.kind == "custom" and "custom" or "class"
      lines[#lines + 1] = tag .. "  " .. tostring(action.name) .. "  " .. table.concat(action.types, "/")
    end
  end
  local sl = model.soulLink
  if sl and sl.enabled then
    if sl.hasClassBattleRez then
      lines[#lines + 1] = "Soul Link idle: class battle-rez present"
    elseif sl.available then
      lines[#lines + 1] = "Soul Link fallback ready (item " .. tostring(sl.itemId) .. ")"
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
    if slots[2] then
      lines[#lines + 1] = "Gap: " .. tostring(slots[2].filter)
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
  local restricted = ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction()
  for i = 1, #slots do
    local slot = slots[i]
    if type(slot.filter) ~= "string" or slot.filter == "" or slot.filter == "HARMFUL" then
      slot.filter = LiveMainFilter(false)
    end
    local info = {
      initializeFrame = initFn,
      candidateFilters = slot.candidateFilters,
    }
    if container._dcrSlotKeys[slot.key] then
      if not inCombat and not restricted then
        if container.SetAuraSlotFilterString then
          container:SetAuraSlotFilterString(slot.key, slot.filter)
        end
        if container.SetAuraSlotCandidateFilters then
          container:SetAuraSlotCandidateFilters(slot.key, slot.candidateFilters)
        end
      elseif inCombat then
        pendingCombatSlots = true
      else
        pendingRestrictionSlots = true
      end
    elseif inCombat then
      pendingCombatSlots = true
    elseif restricted then
      pendingRestrictionSlots = true
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
  if container._dcrSlotKeys.gap and not wanted.gap and container.SetAuraSlotCandidateFilters then
    if not inCombat and not restricted then
      container:SetAuraSlotCandidateFilters("gap", {includeDispelTypes = {}})
    end
  end
  return true
end

function ns.AttachDetectionContainer(container, unit, pack, initFn)
  if not container then
    return false
  end
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  pack = pack or GetPack()
  if ns.AuraDisplayMutationBlocked and ns.AuraDisplayMutationBlocked() then
    pendingRestrictionSlots = true
    return false
  end
  if container.SetUnit then
    container:SetUnit(unit)
  end
  if not ns.ApplyDetectionSlots(container, pack, initFn, unit) then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    return false
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  return true
end

function ns.AttachDetector(parent, unit, pack, initFn)
  if type(unit) ~= "string" or unit == "" then
    return nil
  end
  if InCombatLockdown and InCombatLockdown() then
    return nil
  end
  if not parent then
    return nil
  end
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  if not ok or not container then
    return nil
  end
  if container.SetAllPoints then
    container:SetAllPoints(parent)
  end
  if container.EnableMouse then
    container:EnableMouse(false)
  end
  if not container.SetUnit then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    return nil
  end
  container:SetUnit(unit)
  if ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction() then
    pendingRestrictionSlots = true
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    return container
  end
  if not ns.ApplyDetectionSlots(container, pack, initFn, unit) then
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    return nil
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  if container.Show then
    container:Show()
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
    Enrage = C(colors.enrage),
    Charm = C(colors.charm),
    Bleed = C(colors.bleed),
    None = C(colors.afflicted),
  }
end

ns.DETECTION_TYPES = TYPE_KEYS
ns.BY_ME_DISPEL_FILTER = BY_ME_FILTER
ns.ALL_DISPEL_FILTER = ALL_FILTER
ns.NATIVE_DISPEL_FILTER = BY_ME_FILTER
ns.GAP_DISPEL_FILTER = GAP_FILTER
ns.SOUL_LINK_SPELL_ID = SOUL_LINK_SPELL_ID
ns.SOUL_LINK_ITEM_ID = SOUL_LINK_ITEM_ID
ns.POISON_CLEANSING_TOTEM = POISON_CLEANSING_TOTEM

local function SoulLinkChat(msg)
  local addon = Addon()
  if addon and addon.Print then
    addon:Print(msg)
    return
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff52dbd1Decursive|r " .. msg)
  end
end

function ns.PrintAddonStatus(pack)
  pack = pack or GetPack()
  local addon = Addon()
  local version
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
  elseif GetAddOnMetadata then
    version = GetAddOnMetadata(ADDON_NAME, "Version")
  end
  version = Public(version)
  local lines = {}
  if type(version) == "string" and version ~= "" then
    lines[#lines + 1] = "Zhaohu's Decursive " .. version
  else
    lines[#lines + 1] = "Zhaohu's Decursive"
  end
  if addon and addon.db and addon.db.GetCurrentProfile then
    lines[#lines + 1] = "profile: " .. tostring(addon.db:GetCurrentProfile())
  end
  if addon and addon.GetEditingEnvironment then
    lines[#lines + 1] = "editing environment: " .. tostring(addon:GetEditingEnvironment())
  end
  if addon and addon.GetSpecAssignment then
    local row, spec = addon:GetSpecAssignment()
    if spec then
      local specName = addon.GetSpecName and addon:GetSpecName(spec) or tostring(spec)
      if row and row.enabled then
        lines[#lines + 1] = "spec " .. tostring(specName) .. " assignment: " .. tostring(row.profile)
      else
        lines[#lines + 1] = "spec " .. tostring(specName) .. " assignment: off"
      end
    else
      lines[#lines + 1] = "spec assignment: dormant this login"
    end
  end
  if ns.DetectionSummary then
    local summary = ns.DetectionSummary(pack)
    if type(summary) == "string" and summary ~= "" then
      local startAt = 1
      while true do
        local stopAt = string.find(summary, "\n", startAt, true)
        if not stopAt then
          lines[#lines + 1] = string.sub(summary, startAt)
          break
        end
        if stopAt > startAt then
          lines[#lines + 1] = string.sub(summary, startAt, stopAt - 1)
        end
        startAt = stopAt + 1
      end
    end
  end
  for i = 1, #lines do
    SoulLinkChat(lines[i])
  end
end

function ns.PrintSlashHelp()
  SoulLinkChat("/zd /zdecursive  options")
  SoulLinkChat("/dcr /dcrhelp  this list")
  SoulLinkChat("/dcrstatus  profile, environment, spec, detection dump")
  SoulLinkChat("/dcrdiag  12.1 API, combat, packs, macro drop")
  SoulLinkChat("/dcrreport  identity plus diagnostics")
  SoulLinkChat("/dcridentity  character, current spec, dormant spec rows")
  SoulLinkChat("/dcralerts [on|off|status|move]  editing-pack alerts, drag text")
  SoulLinkChat("/dcralertdiag  aura sound diagnostic")
  SoulLinkChat("/dcrreset [pack|profile|all]  reset editing pack by default")
  SoulLinkChat("/dcrpr /dcrsk  priority and skip lists")
  SoulLinkChat("/dcrsoullink [on|off|status]  emergency Soul Link fallback")
  SoulLinkChat("/dcrsoullinkstatus  Soul Link item/spell dump")
  SoulLinkChat("/zdsound [spellID] [unit]  aura sound diagnostic")
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

function ns.PrintIdentity()
  local addon = Addon()
  local lines = {"identity"}
  if addon and addon.GetCharacterKey then
    lines[#lines + 1] = "character: " .. tostring(addon:GetCharacterKey() or "unknown")
  end
  local className, classFile
  if UnitClass then
    className, classFile = UnitClass("player")
  end
  className = Public(className)
  classFile = Public(classFile)
  if type(className) == "string" and className ~= "" then
    lines[#lines + 1] = "class: " .. className .. " (" .. tostring(classFile or "") .. ")"
  end
  local current
  if addon and addon.GetSpecIndex then
    current = addon:GetSpecIndex()
  end
  if current then
    local name = addon.GetSpecName and addon:GetSpecName(current) or tostring(current)
    lines[#lines + 1] = "current spec: " .. tostring(name) .. " (" .. tostring(current) .. ")"
  else
    lines[#lines + 1] = "current spec: dormant this login"
  end
  if addon and addon.EnsureSpecAssignments then
    local specMap = addon:EnsureSpecAssignments()
    local count = addon.SpecSlotCount and addon:SpecSlotCount() or 4
    for spec = 1, count do
      local row = specMap and specMap[spec]
      local label = addon.GetSpecName and addon:GetSpecName(spec) or ("Spec " .. tostring(spec))
      local state
      if spec == current then
        state = "current"
      else
        state = "dormant"
      end
      if type(row) == "table" and row.enabled then
        lines[#lines + 1] = state .. " spec " .. tostring(label) .. ": " .. tostring(row.profile)
      else
        lines[#lines + 1] = state .. " spec " .. tostring(label) .. ": off"
      end
    end
  end
  if addon and addon.db and addon.db.GetCurrentProfile then
    lines[#lines + 1] = "resolved profile: " .. tostring(addon.db:GetCurrentProfile())
  end
  for i = 1, #lines do
    SoulLinkChat(lines[i])
  end
end

local function HasAPI(root, name)
  return type(root) == "table" and type(root[name]) == "function"
end

function ns.PrintReport()
  ns.PrintIdentity()
  ns.PrintDiagnostics()
end

function ns.PrintDiagnostics()
  ns.PrintAddonStatus()
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
  for i = 1, #lines do
    SoulLinkChat(lines[i])
  end
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
  SoulLinkChat("Emergency Soul Link fallback " .. state .. ".")
  return pack.mufs.soulLinkFallback ~= false
end

function ns.PrintSoulLinkStatus()
  local sl = ns.GetSoulLinkState()
  local lines = {
    "Emergency Soul Link status",
    "toggle: " .. (sl.enabled and "on" or "off"),
    "item " .. tostring(sl.itemId) .. " count: " .. tostring(sl.count),
    "spell " .. tostring(sl.spellId) .. ": " .. (sl.knows and "known" or "not publicly known"),
    "class battle-rez: " .. (sl.hasClassBattleRez and "yes" or "no"),
    "available: " .. (sl.available and "yes" or "no"),
  }
  if sl.name then
    lines[#lines + 1] = "name: " .. sl.name
  end
  SoulLinkChat(table.concat(lines, " | "))
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
    SoulLinkChat("Emergency Soul Link fallback enabled.")
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
    SoulLinkChat("Emergency Soul Link fallback disabled.")
    return
  end
  ns.ToggleSoulLinkFallback()
end

function ns.EnableDetection()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    local unit = arg1
    ns.InvalidateDetection()
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
      ns.RememberRestrictionState(arg1, arg2)
      if ns.HasActiveAddonRestriction() then
        pendingRestrictionSlots = true
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
      if ns.RefreshMUFs then
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
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
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
