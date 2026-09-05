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

-- ZDecursive: automatic sorting follows available public DandersFrames geometry,
-- while every explicit environment choice remains independent and persistent.
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local packs = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  assert(packs[row.key].mufs.order == "AUTO", row.key .. " starts with the automatic policy")
end
local appliedEnvironment, combat = "OPEN_WORLD", false
local arena, raid = false, false
local eventFrames, geometryCalls, layouts = {}, 0, 0
local units = {"player", "party1", "party2", "partypet2"}
local lastOrder
strtrim = function(value) return value:match("^%s*(.-)%s*$") end
InCombatLockdown = function() return combat end
IsInRaid = function() return raid end
IsActiveBattlefieldArena = function() return arena end
UnitIsUnit = function(left, right) return left == right end
UnitName = function(unit) return unit end
UnitFullName = function(unit) return unit, "Realm" end
GetRealmName = function() return "Realm" end
GetNormalizedRealmName = GetRealmName
CreateFrame = function(kind, _name, _parent, template)
  assert(kind == "Frame" and template == nil, "adapter registration is nonsecure")
  local frame = {events = {}, scripts = {}}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  eventFrames[#eventFrames + 1] = frame
  return frame
end
local addon = {db = {profile = {environments = packs, lists = {priority = {}, skip = {}}}}}
function addon:GetAppliedEnvironmentPack() return packs[appliedEnvironment] end
function addon:GetAppliedEnvironment() return appliedEnvironment end
function addon:RegisterChatCommand() end
ns.addon = addon
assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", ns)
ns.RefreshMUFs = function()
  assert(not combat, "secure layout is never requested during combat")
  layouts = layouts + 1
  lastOrder = ns.ApplyUnitLists(units, addon:GetAppliedEnvironmentPack())
end
local function Same(actual, expected, label)
  assert(table.concat(actual, ",") == expected, label .. ": " .. table.concat(actual, ","))
end
local groupOrder, dandersOrder = "player,party1,party2,partypet2", "party1,party2,partypet2,player"
assert(ns.GetConfiguredMUFOrder(packs.OPEN_WORLD) == "AUTO")
assert(ns.GetEffectiveMUFOrder(packs.OPEN_WORLD) == "GROUP", "absent provider falls back without rewriting the policy")
Same(ns.ApplyUnitLists(units, packs.OPEN_WORLD), groupOrder, "default roster is retained without DandersFrames")
ns.RegisterLists(addon)
local loader = eventFrames[1]
assert(loader and loader.events.ADDON_LOADED, "late addon loading has a registered entry")

local callback, callbackRegistrations, ready = nil, 0, false
DandersFrames = {
  RegisterCallback = function(_owner, event, handler)
    assert(event == "OnFramesSorted")
    callback, callbackRegistrations = handler, callbackRegistrations + 1
  end,
  UnregisterCallback = function() callback = nil end,
}
local function GeometryCall()
  assert(not combat, "combat must retain existing layout without provider geometry reads")
  geometryCalls = geometryCalls + 1
end
local function Frame(left)
  return {
    GetLeft = function() GeometryCall(); return left end,
    GetTop = function() GeometryCall(); return 500 end,
    GetWidth = function() GeometryCall(); return 80 end,
    GetHeight = function() GeometryCall(); return 30 end,
  }
end
local positions = {player = Frame(300), party1 = Frame(100), party2 = Frame(200)}
DandersFrames_IsReady = function() return ready end
DandersFrames_GetFrameForUnit = function(unit) GeometryCall(); return positions[unit] end
DandersFrames_GetPartyConfig = function() return {growDirection = "HORIZONTAL"} end
loader.scripts.OnEvent(loader, "ADDON_LOADED", "DandersFrames")
assert(type(callback) == "function" and callbackRegistrations == 1, "late detection registers sorting callback")
assert(packs.OPEN_WORLD.mufs.order == "AUTO" and ns.GetEffectiveMUFOrder() == "GROUP", "loaded but unready provider stays a safe fallback")
Same(lastOrder, groupOrder, "unready late load keeps the current roster order")
ready = true
callback("OnFramesSorted", "party")
Same(lastOrder, dandersOrder, "ready geometry becomes the automatic ordering, including pet ownership")
assert(ns.GetConfiguredMUFOrder(packs.OPEN_WORLD) == "AUTO" and ns.GetEffectiveMUFOrder() == "DANDERSFRAMES")

local savedFrame = positions.party2
positions.party2 = nil
callback("OnFramesSorted", "party")
Same(lastOrder, groupOrder, "partial provider coverage falls back for the entire roster")
assert(ns.GetEffectiveMUFOrder() == "GROUP" and packs.OPEN_WORLD.mufs.order == "AUTO")
positions.party2 = savedFrame
callback("OnFramesSorted", "party")
Same(lastOrder, dandersOrder, "a later complete callback restores automatic DandersFrames order")

local normalPositions = positions
local arenaSlots = {"party2", "player", "party1"}
local wrongArenaReads = 0
arena, raid = true, true -- Arena APIs take precedence over a lingering raid state.
positions = {player = Frame(nil), party1 = Frame(nil), party2 = Frame(nil)}
DandersFrames_GetArenaHeader = function()
  return {GetAttribute = function(_, key)
    GeometryCall()
    local unit = arenaSlots[tonumber(key:match("^child(%d+)$"))]
    return unit and positions[unit]
  end}
end
DandersFrames_GetFlatRaidHeader = function() wrongArenaReads = wrongArenaReads + 1 end
DandersFrames_GetRaidConfig = function() wrongArenaReads = wrongArenaReads + 1 end
callback("OnFramesSorted", "arena")
Same(lastOrder, "party2,partypet2,player,party1", "arena callback uses native header order when frame geometry is unavailable")
assert(wrongArenaReads == 0 and ns.GetEffectiveMUFOrder() == "DANDERSFRAMES", "arena header and party configuration take priority over raid fallback")
arena, raid, positions = false, false, normalPositions
callback("OnFramesSorted", "party")
Same(lastOrder, dandersOrder, "leaving arena returns to the ordinary provider layout")

combat = true
local beforeLayouts, beforeGeometry = layouts, geometryCalls
positions.player, positions.party1 = Frame(100), Frame(300)
callback("OnFramesSorted", "arena")
assert(layouts == beforeLayouts and geometryCalls == beforeGeometry, "combat callback never refreshes secure layout or geometry")
assert(ns.GetUnitSortDiagnostics().pendingSortRefresh == true, "combat callback retains pending refresh")
Same(lastOrder, dandersOrder, "last committed ordering is retained in combat")
combat = false
assert(ns.FlushUnitSortRefresh("test-regen"))
assert(layouts == beforeLayouts + 1)
Same(lastOrder, "player,party2,partypet2,party1", "regen applies the new provider order once")

assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "GROUP"))
Same(lastOrder, groupOrder, "explicit Group overrides the available provider")
beforeLayouts = layouts
callback("OnFramesSorted", "party")
loader.scripts.OnEvent(loader, "ADDON_LOADED", "DandersFrames")
assert(layouts == beforeLayouts and packs.OPEN_WORLD.mufs.order == "GROUP", "callbacks/repeated detection cannot overwrite or refresh an explicit Group choice")
assert(ns.GetEffectiveMUFOrder() == "GROUP")
addon.db.profile.lists.priority = {{kind = "id", player = true}}
assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "PRIORITY"))
beforeLayouts = layouts
callback("OnFramesSorted", "party")
assert(layouts == beforeLayouts and ns.GetEffectiveMUFOrder() == "PRIORITY", "explicit Priority remains authoritative")
assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "DANDERSFRAMES"))
ready = false
callback("OnFramesSorted", "party")
assert(packs.OPEN_WORLD.mufs.order == "DANDERSFRAMES" and ns.GetEffectiveMUFOrder() == "GROUP", "explicit DandersFrames retains its configured preference while unavailable")
ready = true
callback("OnFramesSorted", "party")
assert(ns.GetEffectiveMUFOrder() == "DANDERSFRAMES")

assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "GROUP"))
combat = true
beforeLayouts, beforeGeometry = layouts, geometryCalls
assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "AUTO"), "Automatic can be selected through the real sort control")
assert(packs.OPEN_WORLD.mufs.order == "GROUP" and ns.GetPendingMUFOrder() == "AUTO", "combat selection queues the new policy without changing the applied setting")
assert(layouts == beforeLayouts and geometryCalls == beforeGeometry)
combat = false
assert(ns.FlushUnitSortRefresh("test-regen"))
assert(packs.OPEN_WORLD.mufs.order == "AUTO" and ns.GetEffectiveMUFOrder() == "DANDERSFRAMES")
assert(ns.SetConfiguredMUFOrder(packs.OPEN_WORLD, "GROUP"))
appliedEnvironment = "DUNGEON"
callback("OnFramesSorted", "party")
assert(packs.DUNGEON.mufs.order == "AUTO" and ns.GetEffectiveMUFOrder() == "DANDERSFRAMES", "a separate environment keeps its automatic policy")
assert(packs.OPEN_WORLD.mufs.order == "GROUP", "another environment's automatic behavior cannot overwrite the manual choice")
assert(ns.GetConfiguredMUFOrder({mufs = {order = "invalid"}}) == "GROUP", "invalid persisted values retain the previous safe fallback")

-- Exercise actual AceDB default materialization and stripping, rather than
-- assuming a plain-table fixture proves explicit Group survives a reload.
UnitClass = function() return "Warrior", "WARRIOR" end
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance" end
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 1 end
local aceDB = {}
LibStub = {NewLibrary = function() return aceDB end, GetLibrary = function() return nil end}
assert(loadfile("ZDecursive/Libs/AceDB-3.0/AceDB-3.0.lua"))()
local saved = {profiles = {Existing = {environments = {
  OPEN_WORLD = {mufs = {order = "GROUP"}}, DUNGEON = {mufs = {order = "PRIORITY"}},
  PVP = {mufs = {order = "DANDERSFRAMES"}},
}}}}
local db = aceDB:New(saved, ns.defaults, "Existing")
assert(db.profile.environments.OPEN_WORLD.mufs.order == "GROUP")
assert(db.profile.environments.DUNGEON.mufs.order == "PRIORITY")
assert(db.profile.environments.PVP.mufs.order == "DANDERSFRAMES")
assert(db.profile.environments.RAID.mufs.order == "AUTO", "missing legacy order receives the new factory policy")
db:SetProfile("Copied")
db:CopyProfile("Existing", true)
assert(db.profile.environments.OPEN_WORLD.mufs.order == "GROUP" and db.profile.environments.RAID.mufs.order == "AUTO", "AceDB copy carries manual and automatic intent")
db:RegisterDefaults(nil)
assert(saved.profiles.Copied.environments.OPEN_WORLD.mufs.order == "GROUP", "default stripping cannot discard an explicit Group choice after this change")
assert(saved.profiles.Copied.environments.DUNGEON.mufs.order == "PRIORITY")
assert(saved.profiles.Copied.environments.PVP.mufs.order == "DANDERSFRAMES")
db:RegisterDefaults(ns.defaults)
assert(db.profile.environments.RAID.mufs.order == "AUTO" and db.profile.environments.OPEN_WORLD.mufs.order == "GROUP", "defaults rematerialize Automatic while preserving serialized Group")
io.write("danders-default-contract: ok\n")
