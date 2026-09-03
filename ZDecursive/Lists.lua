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
  ns.DiagnosticCheckpoint("module", "Lists file start")
end

local MAX_ENTRIES = 99

local ROLE_ALIASES = {
  tank = "TANK",
  healer = "HEALER",
  heal = "HEALER",
  dps = "DAMAGER",
  damager = "DAMAGER",
}

local ROLE_LABELS = {
  TANK = "Tank",
  HEALER = "Healer",
  DAMAGER = "DPS",
}

local CLASS_ALIASES = {
  warrior = "WARRIOR",
  paladin = "PALADIN",
  hunter = "HUNTER",
  rogue = "ROGUE",
  priest = "PRIEST",
  shaman = "SHAMAN",
  mage = "MAGE",
  warlock = "WARLOCK",
  monk = "MONK",
  druid = "DRUID",
  demonhunter = "DEMONHUNTER",
  deathknight = "DEATHKNIGHT",
  evoker = "EVOKER",
}

local CLASS_LABELS = {
  WARRIOR = "Warrior",
  PALADIN = "Paladin",
  HUNTER = "Hunter",
  ROGUE = "Rogue",
  PRIEST = "Priest",
  SHAMAN = "Shaman",
  MAGE = "Mage",
  WARLOCK = "Warlock",
  MONK = "Monk",
  DRUID = "Druid",
  DEMONHUNTER = "Demon Hunter",
  DEATHKNIGHT = "Death Knight",
  EVOKER = "Evoker",
}

local function Addon()
  return ns.addon
end

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

local function PublicString(value)
  value = Public(value)
  if type(value) ~= "string" then
    return nil
  end
  value = strtrim(value)
  if value == "" then
    return nil
  end
  return value
end

local function PublicNumber(value)
  value = Public(value)
  if type(value) ~= "number" then
    return nil
  end
  return value
end

local function PublicBoolean(value)
  value = Public(value)
  if type(value) ~= "boolean" then
    return nil
  end
  return value
end

local function PublicTable(value)
  if type(value) ~= "table" then
    return nil
  end
  if type(issecrettable) == "function" and issecrettable(value) then
    if type(canaccesstable) ~= "function" or canaccesstable(value) ~= true then
      return nil
    end
  end
  return value
end

local function CallGlobal(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    return nil
  end
  return value
end

local function ReadField(value, key)
  local ok, field = pcall(function()
    return value and value[key]
  end)
  if not ok then
    return nil
  end
  return field
end

local function CallFrameNumber(frame, method)
  local fn = ReadField(frame, method)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, frame)
  if not ok then
    return nil
  end
  return PublicNumber(value)
end

local function Fold(text)
  if type(text) ~= "string" then
    return nil
  end
  return string.lower(text)
end

local function Chat(msg)
  if type(msg) ~= "string" or msg == "" then
    return
  end
  local addon = Addon()
  if addon and addon.Print then
    addon:Print(msg)
    return
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff52dbd1Decursive|r " .. msg)
  end
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

local function CaptureFullName(unit)
  local name
  local realm
  if UnitFullName then
    name, realm = UnitFullName(unit)
  elseif UnitName then
    name, realm = UnitName(unit)
  end
  name = PublicString(name)
  realm = PublicString(realm)
  if not name then
    return nil
  end
  if realm then
    realm = realm:gsub("%s+", "")
    if realm ~= "" then
      return name .. "-" .. realm
    end
  end
  local fallback = PublicString(GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName())
  if fallback then
    fallback = fallback:gsub("%s+", "")
    if fallback ~= "" then
      return name .. "-" .. fallback
    end
  end
  return name
end

local function CaptureGUID(unit)
  if not UnitGUID then
    return nil
  end
  return PublicString(UnitGUID(unit))
end

local function CaptureClass(unit)
  if not UnitClass then
    return nil
  end
  local _name, classFile = UnitClass(unit)
  classFile = PublicString(classFile)
  if classFile then
    return string.upper(classFile)
  end
  return nil
end

local function CaptureRole(unit)
  local role
  if UnitGroupRolesAssigned then
    role = UnitGroupRolesAssigned(unit)
  end
  role = PublicString(role)
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
    return role
  end
  return nil
end

local function CaptureGroup(unit)
  if not GetRaidRosterInfo then
    return nil
  end
  local index
  if UnitInRaid then
    index = PublicNumber(UnitInRaid(unit))
  end
  if not index then
    return nil
  end
  local _name, _rank, subgroup = GetRaidRosterInfo(index)
  return PublicNumber(subgroup)
end

local function EnsureLists()
  local addon = Addon()
  if not addon or not addon.db or not addon.db.profile then
    return {priority = {}, skip = {}}
  end
  if addon.EnsureLists then
    addon:EnsureLists()
  end
  local lists = addon.db.profile.lists
  if type(lists) ~= "table" then
    lists = {priority = {}, skip = {}}
    addon.db.profile.lists = lists
  end
  if type(lists.priority) ~= "table" then
    lists.priority = {}
  end
  if type(lists.skip) ~= "table" then
    lists.skip = {}
  end
  return lists
end

local function GetList(which)
  local lists = EnsureLists()
  if which == "skip" then
    return lists.skip
  end
  return lists.priority
end

local function OtherList(which)
  if which == "skip" then
    return GetList("priority")
  end
  return GetList("skip")
end

local function NotifyLists()
  if ns.MarkUnitPriorityRevision then
    ns.MarkUnitPriorityRevision()
  end
  if ns.Notify then
    ns.Notify()
  else
    if ns.RequestUnitSortRefresh then
      ns.RequestUnitSortRefresh("priority-list")
    elseif ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    if ns.RefreshAlerts then
      ns.RefreshAlerts()
    end
    if ns.RefreshLiveList then
      ns.RefreshLiveList()
    end
    if ns.RefreshOptions then
      ns.RefreshOptions()
    end
  end
  if ns.RefreshListPanel then
    ns.RefreshListPanel()
  end
end

local function EntryLabel(entry)
  if type(entry) ~= "table" then
    return "?"
  end
  if entry.kind == "role" then
    return "[ " .. (ROLE_LABELS[entry.role] or "Role") .. " ]"
  end
  if entry.kind == "class" then
    return "[ " .. (CLASS_LABELS[entry.class] or entry.class or "Class") .. " ]"
  end
  if entry.kind == "group" then
    return "[ Group " .. tostring(entry.group) .. " ]"
  end
  if type(entry.name) == "string" and entry.name ~= "" then
    return entry.name
  end
  if entry.player then
    return "player"
  end
  if type(entry.guid) == "string" and entry.guid ~= "" then
    return "unit"
  end
  return "?"
end

local function SameId(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  if a.kind ~= "id" or b.kind ~= "id" then
    return false
  end
  if a.player and b.player then
    return true
  end
  if type(a.guid) == "string" and a.guid ~= "" and a.guid == b.guid then
    return true
  end
  if type(a.name) == "string" and type(b.name) == "string" and Fold(a.name) == Fold(b.name) then
    return true
  end
  return false
end

local function SameEntry(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  if a.kind ~= b.kind then
    return false
  end
  if a.kind == "role" then
    return a.role == b.role
  end
  if a.kind == "class" then
    return a.class == b.class
  end
  if a.kind == "group" then
    return a.group == b.group
  end
  return SameId(a, b)
end

local function FindIndex(list, entry)
  for i = 1, #list do
    if SameEntry(list[i], entry) then
      return i
    end
  end
  return nil
end

local function RemoveMatching(list, entry)
  local removed = 0
  for i = #list, 1, -1 do
    if SameEntry(list[i], entry) then
      table.remove(list, i)
      removed = removed + 1
    end
  end
  return removed
end

local function CaptureUnit(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil, "unit"
  end
  if UnitExists then
    local exists = UnitExists(unit)
    if Accessible(exists) and exists ~= true then
      return nil, "absent"
    end
  end
  local entry = {kind = "id"}
  if IsPlayerToken(unit) then
    entry.player = true
  end
  local guid = CaptureGUID(unit)
  if guid then
    entry.guid = guid
  end
  local name = CaptureFullName(unit)
  if name then
    entry.name = name
  end
  if not entry.player and not entry.guid and not entry.name then
    return nil, "secret"
  end
  return entry
end

local function ParseToken(text)
  text = strtrim(text or "")
  if text == "" then
    return nil
  end
  local folded = Fold(text)
  if folded == "player" or folded == "me" then
    return {kind = "id", player = true}
  end
  local role = ROLE_ALIASES[folded]
  if role then
    return {kind = "role", role = role}
  end
  local class = CLASS_ALIASES[folded:gsub("[%s%-]", "")]
  if class then
    return {kind = "class", class = class}
  end
  local group = folded:match("^g(%d+)$") or folded:match("^group%s*(%d+)$")
  if group then
    group = tonumber(group)
    if group and group >= 1 and group <= 8 then
      return {kind = "group", group = group}
    end
  end
  if text:match("^Player%-%d+%-%x+$") or text:match("^Pet%-%d+%-%x+$") then
    return {kind = "id", guid = text}
  end
  return {kind = "id", name = text}
end

local function EntryMatches(entry, unit)
  if type(entry) ~= "table" or type(unit) ~= "string" then
    return false
  end
  if entry.kind == "role" then
    return CaptureRole(unit) == entry.role
  end
  if entry.kind == "class" then
    return CaptureClass(unit) == entry.class
  end
  if entry.kind == "group" then
    return CaptureGroup(unit) == entry.group
  end
  if entry.kind == "id" then
    if entry.player and IsPlayerToken(unit) then
      return true
    end
    if type(entry.guid) == "string" and entry.guid ~= "" then
      local guid = CaptureGUID(unit)
      if guid and guid == entry.guid then
        return true
      end
    end
    if type(entry.name) == "string" and entry.name ~= "" then
      local name = CaptureFullName(unit)
      if name and Fold(name) == Fold(entry.name) then
        return true
      end
      local short = PublicString(UnitName and UnitName(unit))
      local storedShort = entry.name:match("^([^%-]+)")
      if short and storedShort and Fold(short) == Fold(storedShort) then
        return true
      end
    end
  end
  return false
end

function ns.IsUnitSkipped(unit)
  local list = GetList("skip")
  for i = 1, #list do
    if EntryMatches(list[i], unit) then
      return true
    end
  end
  return false
end

function ns.UnitPrioRank(unit)
  local list = GetList("priority")
  for i = 1, #list do
    if EntryMatches(list[i], unit) then
      return i
    end
  end
  return 1000
end

local dandersCallbackOwner = {}
local dandersCallbackProvider
local dandersLoadFrame
local sortState = {
  revision = 0,
  priorityRevision = 0,
  signatureGeneration = 0,
  refreshGeneration = 0,
  pending = false,
  configuredMode = "GROUP",
  effectiveMode = "GROUP",
  environmentPackID = "unknown",
  dandersApplied = nil,
  pendingControlMode = nil,
  pendingControlPack = nil,
  signature = nil,
}

local function SortLockedDown()
  return InCombatLockdown and InCombatLockdown()
end

function ns.InvalidateUnitSort(_reason)
  sortState.revision = sortState.revision + 1
  sortState.dandersApplied = nil
end

function ns.MarkUnitPriorityRevision()
  sortState.priorityRevision = sortState.priorityRevision + 1
end

function ns.MarkUnitSortRefreshPending(reason)
  ns.InvalidateUnitSort(reason)
  sortState.pending = true
end

function ns.GetUnitSortRefreshGeneration()
  return sortState.refreshGeneration
end

local function ApplyPendingOrderControl()
  local pack = sortState.pendingControlPack
  local mode = sortState.pendingControlMode
  if not mode then
    return false
  end
  if type(pack) == "table" and type(pack.mufs) == "table" then
    pack.mufs.order = mode
  end
  sortState.pendingControlMode = nil
  sortState.pendingControlPack = nil
  return true
end

function ns.RequestUnitSortRefresh(reason)
  ns.InvalidateUnitSort(reason)
  if SortLockedDown() then
    sortState.pending = true
    return false
  end
  ApplyPendingOrderControl()
  sortState.pending = false
  sortState.refreshGeneration = sortState.refreshGeneration + 1
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  return true
end

function ns.FlushUnitSortRefresh(_reason)
  if not sortState.pending or SortLockedDown() then
    return false
  end
  ApplyPendingOrderControl()
  sortState.pending = false
  sortState.refreshGeneration = sortState.refreshGeneration + 1
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  return true
end

local function CurrentPackUsesDandersFrames()
  local addon = Addon()
  if not addon or not addon.GetAppliedEnvironmentPack then
    return false
  end
  local pack = addon:GetAppliedEnvironmentPack()
  return type(pack) == "table" and type(pack.mufs) == "table" and pack.mufs.order == "DANDERSFRAMES"
end

local function OnDandersFramesSorted(_event, sortType)
  sortType = PublicString(sortType)
  if sortType ~= "party" and sortType ~= "raid" then
    return
  end
  if not CurrentPackUsesDandersFrames() then
    return
  end
  ns.RequestUnitSortRefresh("danders-callback")
end

function ns.EnsureDandersFramesOrderCallback()
  local provider = rawget(_G, "DandersFrames")
  if provider == dandersCallbackProvider then
    return provider ~= nil
  end
  local unregister = type(dandersCallbackProvider) == "table" and rawget(dandersCallbackProvider, "UnregisterCallback")
  if type(unregister) == "function" then
    pcall(unregister, dandersCallbackOwner, "OnFramesSorted")
  end
  dandersCallbackProvider = nil
  local register = type(provider) == "table" and rawget(provider, "RegisterCallback")
  if type(register) ~= "function" then
    return false
  end
  local ok, registered = pcall(register, dandersCallbackOwner, "OnFramesSorted", OnDandersFramesSorted)
  if not ok or registered == false then
    return false
  end
  dandersCallbackProvider = provider
  return true
end

local function DandersFramesReady()
  local readyFn = rawget(_G, "DandersFrames_IsReady")
  if type(readyFn) == "function" then
    local ok, ready = pcall(readyFn)
    if not ok or PublicBoolean(ready) ~= true then
      return false
    end
  end
  return type(rawget(_G, "DandersFrames_GetFrameForUnit")) == "function"
end

local function ConfiguredOrder(pack)
  local order = type(pack) == "table" and type(pack.mufs) == "table" and pack.mufs.order or nil
  if order == "PRIORITY" or order == "DANDERSFRAMES" then
    return order
  end
  return "GROUP"
end

local function EffectiveOrder(pack)
  local configured = ConfiguredOrder(pack)
  if configured == "DANDERSFRAMES" then
    if not DandersFramesReady() or sortState.dandersApplied == false then
      return "GROUP"
    end
  end
  return configured
end

local function UpdateSortState(pack)
  local addon = Addon()
  local environment = "unknown"
  local value = addon and addon.GetAppliedEnvironment and addon:GetAppliedEnvironment() or nil
  if type(value) == "string" and ns.ENV_SET and ns.ENV_SET[value] then
    environment = value
  end
  local profileGeneration = addon and type(addon.profileChangeGeneration) == "number" and addon.profileChangeGeneration or 0
  local configured = ConfiguredOrder(pack)
  local effective = EffectiveOrder(pack)
  local signature = table.concat({configured, effective, environment, tostring(profileGeneration), tostring(sortState.revision), tostring(sortState.priorityRevision)}, "|")
  if signature ~= sortState.signature then
    sortState.signature = signature
    sortState.signatureGeneration = sortState.signatureGeneration + 1
  end
  sortState.configuredMode = configured
  sortState.effectiveMode = effective
  sortState.environmentPackID = environment
  return effective
end

function ns.GetConfiguredMUFOrder(pack)
  return ConfiguredOrder(pack)
end

function ns.GetEffectiveMUFOrder(pack)
  local addon = Addon()
  pack = pack or (addon and addon.GetAppliedEnvironmentPack and addon:GetAppliedEnvironmentPack())
  return UpdateSortState(pack)
end

function ns.SetConfiguredMUFOrder(pack, value)
  if type(pack) ~= "table" or type(pack.mufs) ~= "table" then
    return false, "pack"
  end
  if value ~= "GROUP" and value ~= "PRIORITY" and value ~= "DANDERSFRAMES" then
    value = "GROUP"
  end
  if SortLockedDown() then
    sortState.pendingControlMode = value
    sortState.pendingControlPack = pack
    ns.MarkUnitSortRefreshPending("order-control")
    return true, value
  end
  pack.mufs.order = value
  ns.RequestUnitSortRefresh("order-control")
  return true, value
end

function ns.GetPendingMUFOrder()
  return sortState.pendingControlMode
end

function ns.GetUnitSortDiagnostics(pack)
  local addon = Addon()
  if not pack then
    local db = addon and addon.db
    local profile = type(db) == "table" and db.profile or nil
    local environments = type(profile) == "table" and profile.environments or nil
    local char = type(db) == "table" and db.char or nil
    local environment = type(char) == "table" and rawget(char, "editingEnvironment") or nil
    if type(environments) == "table" and type(environment) == "string" and ns.ENV_SET and ns.ENV_SET[environment] then
      pack = environments[environment]
    end
  end
  UpdateSortState(pack)
  return {
    configuredMode = sortState.configuredMode,
    effectiveMode = sortState.effectiveMode,
    environmentPackID = sortState.environmentPackID,
    profileChangeGeneration = addon and addon.profileChangeGeneration or 0,
    sortRevision = sortState.revision,
    priorityRevision = sortState.priorityRevision,
    sortSignatureGeneration = sortState.signatureGeneration,
    sortCacheGeneration = sortState.signatureGeneration,
    sortRefreshGeneration = sortState.refreshGeneration,
    pendingSortRefresh = sortState.pending,
    pendingConfiguredMode = sortState.pendingControlMode or "unknown",
  }
end

local function AddHeaderSlots(slots, header, maximum, nextSlot)
  local getAttribute = ReadField(header, "GetAttribute")
  if type(getAttribute) ~= "function" then
    return nextSlot
  end
  for i = 1, maximum do
    local ok, child = pcall(getAttribute, header, "child" .. tostring(i))
    if ok then
      child = Public(child)
    end
    if ok and child and slots[child] == nil then
      slots[child] = nextSlot
      nextSlot = nextSlot + 1
    end
  end
  return nextSlot
end

local function DandersFrameSlots()
  local slots = {}
  local nextSlot = 1
  local inRaid = PublicBoolean(CallGlobal("IsInRaid")) == true
  if inRaid then
    local grouped = PublicBoolean(CallGlobal("DandersFrames_IsRaidGrouped"))
    if grouped then
      local headers = PublicTable(CallGlobal("DandersFrames_GetRaidGroupHeaders"))
      if headers then
        for group = 1, 8 do
          nextSlot = AddHeaderSlots(slots, ReadField(headers, group), 5, nextSlot)
        end
      end
    else
      nextSlot = AddHeaderSlots(slots, CallGlobal("DandersFrames_GetFlatRaidHeader"), 40, nextSlot)
    end
  else
    nextSlot = AddHeaderSlots(slots, CallGlobal("DandersFrames_GetPartyHeader"), 5, nextSlot)
  end
  return slots
end

local function DandersHorizontalLayout()
  local inRaid = PublicBoolean(CallGlobal("IsInRaid")) == true
  local configName = inRaid and "DandersFrames_GetRaidConfig" or "DandersFrames_GetPartyConfig"
  local config = PublicTable(CallGlobal(configName))
  if not config then
    return false
  end
  local growDirection = PublicString(ReadField(config, "growDirection"))
  return growDirection == "HORIZONTAL"
end

local function DandersOrder(units)
  if not DandersFramesReady() then
    return nil
  end
  ns.EnsureDandersFramesOrderCallback()
  local slots = DandersFrameSlots()
  local horizontal = DandersHorizontalLayout()
  local positioned = {}
  local ownerCount = 0
  local getFrame = rawget(_G, "DandersFrames_GetFrameForUnit")
  for i = 1, #units do
    local unit = units[i]
    local isPet = unit == "pet" or (type(unit) == "string" and (
      unit:match("^partypet%d+$") ~= nil or unit:match("^raidpet%d+$") ~= nil
    ))
    if type(unit) == "string" and not isPet then
      ownerCount = ownerCount + 1
      local ok, frame = pcall(getFrame, unit)
      if ok then
        frame = Public(frame)
      end
      if ok and frame then
        local entry = {
          unit = unit,
          source = i,
          left = CallFrameNumber(frame, "GetLeft"),
          top = CallFrameNumber(frame, "GetTop"),
          width = CallFrameNumber(frame, "GetWidth") or 1,
          height = CallFrameNumber(frame, "GetHeight") or 1,
          slot = slots[frame],
        }
        if (entry.left ~= nil and entry.top ~= nil) or entry.slot ~= nil then
          positioned[#positioned + 1] = entry
        end
      end
    end
  end
  if #positioned < 2 or #positioned ~= ownerCount then
    return nil
  end
  table.sort(positioned, function(a, b)
    local aPositioned = a.left ~= nil and a.top ~= nil
    local bPositioned = b.left ~= nil and b.top ~= nil
    if aPositioned ~= bPositioned then
      return aPositioned
    end
    if aPositioned then
      if horizontal then
        local rowTolerance = math.max(1, math.min(a.height, b.height) * 0.5)
        if math.abs(a.top - b.top) > rowTolerance then
          return a.top > b.top
        end
        if a.left ~= b.left then
          return a.left < b.left
        end
      else
        local columnTolerance = math.max(1, math.min(a.width, b.width) * 0.5)
        if math.abs(a.left - b.left) > columnTolerance then
          return a.left < b.left
        end
        if a.top ~= b.top then
          return a.top > b.top
        end
      end
    end
    if a.slot ~= b.slot then
      if a.slot == nil then
        return false
      end
      if b.slot == nil then
        return true
      end
      return a.slot < b.slot
    end
    return a.source < b.source
  end)
  local ranks = {}
  for rank = 1, #positioned do
    ranks[positioned[rank].unit] = rank
  end
  return ranks
end

local function OwnerToken(unit)
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
  return unit
end

function ns.WrapRosterLists(units, pack)
  if type(units) ~= "table" then
    return units
  end
  local kept = {}
  for i = 1, #units do
    local unit = units[i]
    if type(unit) == "string" and not ns.IsUnitSkipped(unit) then
      kept[#kept + 1] = unit
    end
  end
  local ranked = {}
  local anyPrio = false
  for i = 1, #kept do
    local rank = ns.UnitPrioRank(kept[i])
    if rank < 1000 then
      anyPrio = true
    end
    ranked[i] = {
      unit = kept[i],
      i = i,
      rank = rank,
    }
  end
  if not anyPrio then
    return kept
  end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.i < b.i
  end)
  local out = {}
  for i = 1, #ranked do
    out[i] = ranked[i].unit
  end
  return out
end

function ns.ApplyUnitLists(units, pack)
  if type(units) ~= "table" then
    return units
  end
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("Lists")
  end
  local skippedOwners = {}
  for i = 1, #units do
    local unit = units[i]
    if type(unit) == "string" and OwnerToken(unit) == unit and ns.IsUnitSkipped(unit) then
      skippedOwners[unit] = true
    end
  end
  local kept = {}
  for i = 1, #units do
    local unit = units[i]
    local owner = OwnerToken(unit)
    if type(unit) == "string" and not skippedOwners[owner] and not ns.IsUnitSkipped(unit) then
      kept[#kept + 1] = unit
    end
  end
  local order = UpdateSortState(pack)
  local ranks
  if order == "PRIORITY" then
    ranks = {}
    for i = 1, #kept do
      local owner = OwnerToken(kept[i])
      if ranks[owner] == nil then
        ranks[owner] = ns.UnitPrioRank(owner)
      end
    end
  elseif order == "DANDERSFRAMES" then
    ranks = DandersOrder(kept)
    sortState.dandersApplied = type(ranks) == "table"
    UpdateSortState(pack)
  end
  if type(ranks) ~= "table" then
    return kept
  end
  local ranked = {}
  for i = 1, #kept do
    local owner = OwnerToken(kept[i])
    ranked[i] = {
      unit = kept[i],
      i = i,
      rank = ranks[owner] or 1000,
    }
  end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.i < b.i
  end)
  local out = {}
  for i = 1, #ranked do
    out[i] = ranked[i].unit
  end
  return out
end

function ns.ListSummary(which)
  local list = GetList(which)
  if #list == 0 then
    return "(empty)"
  end
  local parts = {}
  for i = 1, #list do
    parts[i] = i .. ". " .. EntryLabel(list[i])
  end
  return table.concat(parts, "  ")
end

function ns.ListCount(which)
  return #GetList(which)
end

local function ListName(which)
  if which == "skip" then
    return "skip"
  end
  return "priority"
end

function ns.AddListEntry(which, entry)
  if type(entry) ~= "table" then
    return false, "invalid"
  end
  local list = GetList(which)
  if #list >= MAX_ENTRIES then
    return false, "full"
  end
  if FindIndex(list, entry) then
    return false, "exists"
  end
  RemoveMatching(OtherList(which), entry)
  list[#list + 1] = entry
  NotifyLists()
  return true
end

function ns.RemoveListEntry(which, entry)
  local removed = RemoveMatching(GetList(which), entry)
  if removed > 0 then
    NotifyLists()
    return true
  end
  return false, "missing"
end

function ns.ClearList(which)
  local list = GetList(which)
  if #list == 0 then
    return false, "empty"
  end
  for i = #list, 1, -1 do
    list[i] = nil
  end
  NotifyLists()
  return true
end

function ns.AddUnitToList(which, unit)
  local entry, err = CaptureUnit(unit)
  if not entry then
    return false, err or "unit", entry
  end
  local ok, addErr = ns.AddListEntry(which, entry)
  return ok, addErr, entry
end

function ns.RemoveUnitFromList(which, unit)
  local entry, err = CaptureUnit(unit)
  if not entry then
    return false, err or "unit", entry
  end
  local ok, remErr = ns.RemoveListEntry(which, entry)
  return ok, remErr, entry
end

local function PrintList(which)
  local list = GetList(which)
  local title = ListName(which)
  if #list == 0 then
    Chat("The " .. title .. " list is empty.")
    return
  end
  Chat(title .. " list (" .. tostring(#list) .. "):")
  for i = 1, #list do
    Chat("  " .. i .. ". " .. EntryLabel(list[i]))
  end
end

local function PrintHelp(which)
  local cmd = which == "skip" and "/dcrsk" or "/dcrpr"
  Chat(cmd .. " add [name | tank | healer | dps | class | group N]")
  Chat(cmd .. " remove [name]")
  Chat(cmd .. " show")
  Chat(cmd .. " clear")
end

local function Report(ok, err, which, action, entry)
  local title = ListName(which)
  if ok then
    if action == "add" then
      Chat("Added " .. EntryLabel(entry) .. " to the " .. title .. " list.")
    elseif action == "remove" then
      Chat("Removed " .. EntryLabel(entry) .. " from the " .. title .. " list.")
    elseif action == "clear" then
      Chat("Cleared the " .. title .. " list.")
    end
    return
  end
  if err == "exists" then
    Chat(EntryLabel(entry) .. " is already on the " .. title .. " list.")
  elseif err == "missing" then
    Chat(EntryLabel(entry) .. " is not on the " .. title .. " list.")
  elseif err == "empty" then
    Chat("The " .. title .. " list is empty.")
  elseif err == "full" then
    Chat("The " .. title .. " list is full.")
  elseif err == "secret" then
    Chat("Cannot change the " .. title .. " list: unit identity is not public.")
  elseif err == "absent" or err == "unit" then
    Chat("No target.")
  else
    Chat("Could not update the " .. title .. " list.")
  end
end

function ns.HandleListSlash(which, msg)
  msg = strtrim(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = Fold(cmd or "")
  rest = rest or ""
  if cmd == "" or cmd == "show" or cmd == "list" then
    PrintList(which)
    return
  end
  if cmd == "help" or cmd == "?" then
    PrintHelp(which)
    return
  end
  if cmd == "clear" or cmd == "reset" then
    local ok, err = ns.ClearList(which)
    Report(ok, err, which, "clear")
    return
  end
  if cmd == "add" then
    if strtrim(rest) == "" then
      local ok, err, entry = ns.AddUnitToList(which, "target")
      Report(ok, err, which, "add", entry or {kind = "id", name = "target"})
      return
    end
    local entry = ParseToken(rest)
    if not entry then
      PrintHelp(which)
      return
    end
    local ok, err = ns.AddListEntry(which, entry)
    Report(ok, err, which, "add", entry)
    return
  end
  if cmd == "remove" or cmd == "del" or cmd == "rm" then
    if strtrim(rest) == "" then
      local ok, err, entry = ns.RemoveUnitFromList(which, "target")
      Report(ok, err, which, "remove", entry or {kind = "id", name = "target"})
      return
    end
    local entry = ParseToken(rest)
    if not entry then
      PrintHelp(which)
      return
    end
    local ok, err = ns.RemoveListEntry(which, entry)
    Report(ok, err, which, "remove", entry)
    return
  end
  PrintHelp(which)
end

function ns.RegisterLists(addon)
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Lists", false)
  end
  if not addon or not addon.RegisterChatCommand then
    return
  end
  addon:RegisterChatCommand("dcrpr", function(msg)
    ns.HandleListSlash("priority", msg)
  end)
  addon:RegisterChatCommand("dcrsk", function(msg)
    ns.HandleListSlash("skip", msg)
  end)
  addon:RegisterChatCommand("dcrpradd", function()
    ns.HandleListSlash("priority", "add")
  end)
  addon:RegisterChatCommand("dcrprshow", function()
    ns.HandleListSlash("priority", "show")
  end)
  addon:RegisterChatCommand("dcrprclear", function()
    ns.HandleListSlash("priority", "clear")
  end)
  addon:RegisterChatCommand("dcrprremove", function()
    ns.HandleListSlash("priority", "remove")
  end)
  addon:RegisterChatCommand("dcrskadd", function()
    ns.HandleListSlash("skip", "add")
  end)
  addon:RegisterChatCommand("dcrskshow", function()
    ns.HandleListSlash("skip", "show")
  end)
  addon:RegisterChatCommand("dcrskclear", function()
    ns.HandleListSlash("skip", "clear")
  end)
  addon:RegisterChatCommand("dcrskremove", function()
    ns.HandleListSlash("skip", "remove")
  end)
  ns.EnsureDandersFramesOrderCallback()
  if not dandersLoadFrame and CreateFrame then
    dandersLoadFrame = CreateFrame("Frame")
    dandersLoadFrame:RegisterEvent("ADDON_LOADED")
    dandersLoadFrame:SetScript("OnEvent", function(_, _event, loadedName)
      if PublicString(loadedName) == "DandersFrames" then
        ns.EnsureDandersFramesOrderCallback()
        if CurrentPackUsesDandersFrames() then
          ns.RequestUnitSortRefresh("danders-loaded")
        end
      end
    end)
  end
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Lists", true)
  end
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("Lists", function()
    local dandersLoaded = false
    local loadedAPI = C_AddOns and C_AddOns.IsAddOnLoaded
    if type(loadedAPI) == "function" then
      local ok, loaded = pcall(loadedAPI, "DandersFrames")
      local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(loaded) or nil
      dandersLoaded = ok and public == true
    end
    local sort = ns.GetUnitSortDiagnostics()
    local addon = Addon()
    local profile = addon and addon.db and addon.db.profile
    local lists = type(profile) == "table" and profile.lists or nil
    local priority = type(lists) == "table" and lists.priority or nil
    local skip = type(lists) == "table" and lists.skip or nil
    return {
      priorityCount = type(priority) == "table" and #priority or 0,
      skipCount = type(skip) == "table" and #skip or 0,
      dandersFramesLoaded = dandersLoaded,
      dandersFramesReady = DandersFramesReady(),
      dandersAdapterRegistered = dandersCallbackProvider ~= nil,
      dandersOrderSelected = sort.configuredMode == "DANDERSFRAMES",
      effectiveSortMode = sort.effectiveMode,
      configuredSortMode = sort.configuredMode,
      environmentPackID = sort.environmentPackID,
      profileChangeGeneration = sort.profileChangeGeneration,
      sortRevision = sort.sortRevision,
      priorityRevision = sort.priorityRevision,
      sortSignatureGeneration = sort.sortSignatureGeneration,
      sortCacheGeneration = sort.sortCacheGeneration,
      sortRefreshGeneration = sort.sortRefreshGeneration,
      pendingSortRefresh = sort.pendingSortRefresh,
      pendingConfiguredMode = sort.pendingConfiguredMode,
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Lists")
end
