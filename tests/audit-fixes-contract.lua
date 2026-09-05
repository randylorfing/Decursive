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

local failures = 0
local function verify(label, expected, actual)
  local passed = expected == actual
  if not passed then
    io.write("FAIL: " .. label .. " | expected=" .. tostring(expected) .. " actual=" .. tostring(actual) .. "\n")
  end
  if not passed then failures = failures + 1 end
end
local function upvalue(fn, target)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == target then return value end
  end
  error("Missing audit seam: " .. target)
end

local context = "none"
local raid = false
local groupSize = 0
local soulCount = 1
local bandageCount = 0
strtrim = function(value) return value:match("^%s*(.-)%s*$") end
InCombatLockdown = function() return false end
issecretvalue = function() return false end
canaccessvalue = function() return true end
UnitClass = function() return "Mage", "MAGE" end
UnitRace = function() return "Human", "Human" end
UnitIsUnit = function(a, b) return a == b or (a == "raid1" and b == "player") end
UnitIsDeadOrGhost = function() return false end
UnitIsPlayer = function() return true end
UnitIsConnected = function() return true end
UnitExists = function(unit) return unit == "player" or (raid and unit:match("^raid%d+$") ~= nil) end
IsInInstance = function() return context ~= "none", context end
GetInstanceInfo = function() return "Audit Instance", context end
IsInRaid = function() return raid end
GetNumGroupMembers = function() return groupSize end
GetNumSubgroupMembers = function() return 0 end
IsActiveBattlefieldArena = function() return context == "arena" end
C_PvP = {IsArena = function() return context == "arena" end}
GetTime = function() return 100 end
Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}, BagIndex = {Backpack = 0}}
AuraUtil = {AuraFilters = {Dispellable = "DISPELLABLE", RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE"}}
C_SpellBook = {
  IsSpellInSpellBook = function(id) return id == 475 end,
  IsSpellKnown = function(id) return id == 475 end,
}
C_Spell = {
  GetOverrideSpell = function(id) return id end,
  GetSpellName = function(id) return id == 475 and "Remove Curse" or "Soul Link" end,
}
C_Item = {
  GetItemCount = function(id) if id == 248486 then return 0 end; return id == 269586 and soulCount or bandageCount end,
  GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, 0, 7 end,
  GetItemInfo = function() return "Bandage", nil, 1, 10 end,
  GetItemSpell = function() return "Bandage", 212640 end,
  IsUsableItem = function() return true end,
}
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and bandageCount > 0 and 1 or 0 end,
  GetContainerItemInfo = function() return {itemID = 133940} end,
}
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
local pack = ns.MakePack("PVP")
pack.sorting.includePets = false
pack.mouse.button5 = "CURE"
ns.addon = {GetAppliedEnvironmentPack = function() return pack end}

local function modelContains(model, needle)
  for i = 1, #(model and model.rows or {}) do
    local text = model.rows[i].macroText
    if type(text) == "string" and text:find(needle, 1, true) then
      return true
    end
  end
  return false
end

-- Arena exit followed by a full 40-member battleground/raid.
raid, groupSize, context = true, 40, "pvp"
verify("40-member roster before arena", 40, #ns.BuildRoster(pack))
raid, groupSize, context = false, 3, "arena"
verify("arena detected", true, ns.IsArenaInstance())
ns.ResetRosterForWorldTransition("AUDIT_LEAVING_ARENA")
raid, groupSize, context = true, 40, "pvp"
verify("arena flag cleared on battleground entry", false, ns.IsArenaInstance())
verify("40-member roster after arena", 40, #ns.BuildRoster(pack))

-- The real settings notification invalidates detection, then rebuilds clicks.
local initial = ns.RebuildClickModel(pack)
verify("Soul Link initially in left macro", true, modelContains(initial, "269586"))

pack.mouse.left = "TARGET"
ns.InvalidateDetection()
local autoActions = ns.RebuildClickModel(pack)
local autoTarget
for i = 1, #autoActions.rows do
  if autoActions.rows[i].binding == "*%s1" then
    autoTarget = autoActions.rows[i]
    break
  end
end
verify("configured actions override automatic cure gestures", "target", autoTarget and autoTarget.secureType)
pack.mouse.left = "CURE"
ns.InvalidateDetection()

pack.mufs.soulLinkFallback = false
ns.InvalidateDetection()
local disabled = ns.RebuildClickModel(pack)
verify("Soul Link removed after disabling fallback", false, modelContains(disabled, "269586"))
verify("Soul Link toggle rebuilt click model", false, initial == disabled)

-- Inventory invalidation discovers newly acquired item actions.
verify("no bandage before acquisition", false, disabled.bandage ~= nil)
bandageCount = 1
ns.InvalidateDetection()
local acquired = ns.RebuildClickModel(pack)
verify("acquired bandage mapped after explicit refresh", true, acquired.bandage ~= nil)

-- Manual choices exposed by Options.lua must reach actual secure attributes.
pack.cure.mode = "MANUAL"
pack.cure.manual = {}
pack.mouse = {left = "TARGET", right = "FOCUS", middle = "TARGET", button4 = "ASSIST", button5 = "ASSIST"}
bandageCount = 0
ns.InvalidateDetection()
local install = upvalue(ns.LayoutMUFs, "ApplyClickAttributes")
local button = {attributes = {}}
function button:SetAttribute(key, value) self.attributes[key] = value end
verify("manual secure installer completes", true, install(button, pack, "party1"))
verify("manual left Target installs target", "target", button.attributes["*type1"])
verify("manual right Focus installs focus", "focus", button.attributes["*type2"])
verify("manual Button4 Assist installs assist", "assist", button.attributes["*type4"])
verify("control: fixed middle target works", "target", button.attributes["*type3"])

-- Explicit realm/GUID identities must not match a namesake on another realm.
UnitFullName = function(unit) return "Auditname", unit == "party1" and "RealmOne" or "RealmTwo" end
UnitName = function() return "Auditname" end
UnitGUID = function(unit) return unit == "party1" and "Player-1-A" or "Player-2-B" end
ns.addon.db = {profile = {lists = {priority = {}, skip = {
  {kind = "id", name = "Auditname-RealmOne", guid = "Player-1-A"},
}}}}
assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)
verify("control: exact skip identity matches", true, ns.IsUnitSkipped("party1"))
verify("different GUID and realm remain unskipped", false, ns.IsUnitSkipped("party2"))
ns.addon.db.profile.lists.skip = {
  {kind = "id", name = "Auditname-RealmOne"},
}
verify("realm-qualified names do not fall back to a namesake", false, ns.IsUnitSkipped("party2"))

-- Live List rows declare secure actions and never call restricted target APIs.
assert(loadfile("ZDecursive/LiveList.lua"))("ZDecursive", ns)
local wire = upvalue(upvalue(upvalue(ns.LayoutLiveList, "EnsurePool"), "CreateRow"), "WireRow")
local liveRow = {unit = "party1", scripts = {}, attributes = {}}
function liveRow:RegisterForClicks() end
function liveRow:SetScript(event, callback) self.scripts[event] = callback end
function liveRow:SetAttribute(key, value) self.attributes[key] = value end
wire(liveRow)
verify("Live List left click is secure target", "target", liveRow.attributes["*type1"])
verify("Live List right click is secure focus", "focus", liveRow.attributes["*type2"])
verify("Live List middle click is secure assist", "assist", liveRow.attributes["*type3"])
verify("Live List has no insecure OnClick handler", nil, liveRow.scripts.OnClick)
InCombatLockdown = function() return true end
local layoutOK, layoutStatus = ns.LayoutLiveList()
verify("Live List defers every layout path in combat", false, layoutOK)
verify("Live List reports combat deferral", "DEFERRED_COMBAT", layoutStatus)

local liveSource = assert(io.open("ZDecursive/LiveList.lua", "rb")):read("*a")
verify("Live List uses secure unit buttons", true, liveSource:find("SecureUnitButtonTemplate,BackdropTemplate", 1, true) ~= nil)
verify("Live List has no direct TargetUnit call", false, liveSource:find("TargetUnit(", 1, true) ~= nil)
verify("Live List has no direct FocusUnit call", false, liveSource:find("FocusUnit(", 1, true) ~= nil)
verify("Live List has no direct AssistUnit call", false, liveSource:find("AssistUnit(", 1, true) ~= nil)

if failures > 0 then
  error("audit fix regressions: " .. tostring(failures), 0)
end
io.write("audit-fixes-contract: ok\n")
