local ADDON_NAME, ns = ...

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
  if ns.Notify then
    ns.Notify()
  else
    if ns.RefreshMUFs then
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
  local kept = {}
  for i = 1, #units do
    local unit = units[i]
    if type(unit) == "string" and not ns.IsUnitSkipped(unit) then
      kept[#kept + 1] = unit
    end
  end
  local order = pack and pack.mufs and pack.mufs.order
  if order ~= "PRIORITY" then
    return kept
  end
  local ranked = {}
  for i = 1, #kept do
    ranked[i] = {
      unit = kept[i],
      i = i,
      rank = ns.UnitPrioRank(kept[i]),
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
end
