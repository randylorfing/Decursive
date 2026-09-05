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

-- Inventory choice is public/OOC configuration; secure clicks stay frozen in combat.
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/ClickBindings.lua"))("ZDecursive", ns)
local pack = ns.MakePack("PVP")
local editingPack = ns.MakePack("OPEN_WORLD")
ns.addon = {GetAppliedEnvironmentPack = function() return pack end}
ns.GetKnownCures = function() return {} end
ns.GetSmartRezActions = function() return nil, nil, false, false end
ns.GetDetectionItemActionSignature = function() return "SOUL0" end
local combat, apiCalls, requests = false, 0, {}
InCombatLockdown = function() return combat end
local secret = setmetatable({}, {__tostring = function() error("secret stringify") end, __lt = function() error("secret compare") end})
issecretvalue = function(value) return value == secret end
canaccessvalue = function(value) return value ~= secret end
NUM_BAG_SLOTS = 0
local data = {
  [239711] = {name = "Bright Linen", level = 150, count = 3, usable = true, class = 0, sub = 7},
  [224442] = {name = "Weavercloth", level = 90, count = 5, usable = true, class = 0, sub = 7},
  [194050] = {name = "Wildercloth", level = 90, count = 2, usable = true, class = 0, sub = 7},
  [1000] = {name = "Not a player bandage", level = 200, count = 7, usable = true, class = 0, sub = 8},
}
local slots = {239711, 224442, 194050, 1000, 239711}
local function ApiCall()
  assert(not combat, "no inventory/metadata calls in combat")
  apiCalls = apiCalls + 1
end
C_Container = {
  GetContainerNumSlots = function() ApiCall(); return #slots end,
  GetContainerItemInfo = function(_, slot) ApiCall(); return {itemID = slots[slot]} end,
}
C_Item = {
  GetItemInfoInstant = function(itemID)
    ApiCall(); local d = data[itemID]
    if d.cold then return end
    return itemID, nil, nil, nil, nil, d.class, d.sub
  end,
  GetItemInfo = function(itemID)
    ApiCall(); local d = data[itemID]
    if d.coldName then return end
    return d.name, nil, 1, d.level
  end,
  GetItemCount = function(itemID, bank, uses, reagent, account)
    ApiCall(); assert(not bank and not uses and not reagent and not account, "count carried bags only")
    return data[itemID].count
  end,
  IsUsableItem = function(itemID) ApiCall(); return data[itemID].usable end,
  RequestLoadItemDataByID = function(itemID) ApiCall(); requests[itemID] = (requests[itemID] or 0) + 1 end,
}
C_TradeSkillUI = {
  GetItemReagentQualityByItemInfo = function(itemID) ApiCall(); return itemID == 239711 and 1 or nil end,
  GetItemCraftedQualityByItemInfo = function(itemID) ApiCall(); return itemID == 224442 and 3 or nil end,
}
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
local function Equal(actual, expected, message)
  assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Refresh()
  ns.MarkBandageInventoryDirty()
  return ns.GetBandageInventoryStatus(pack)
end
local status = Refresh()
Equal(#status.items, 3, "all three expansion bandages detected, duplicates/non-bandage excluded")
Equal(status.itemID, 239711, "AUTO orders highest public item level")
Equal(status.items[2].itemID, 224442, "equal item levels have deterministic item-ID tie break")
Equal(status.items[1].count, 3, "duplicate bag stack does not duplicate total item count")
Equal(status.items[1].quality, 1, "public reagent quality available for distinct rank labels")
Equal(status.items[2].quality, 3, "crafted quality fallback available for distinct rank labels")
Equal(status.items[3].quality, nil, "unranked quality stays unknown without blocking inventory")
status.items[1].count = 999
Equal(ns.GetBandageInventoryStatus(pack).items[1].count, 3, "status cannot mutate internal inventory")
local firstSignature = ns.GetBandageInventorySignature()
slots = {1000, 194050, 224442, 239711}
Equal(Refresh().itemID, 239711, "bag order cannot change selection")
Equal(ns.GetBandageInventorySignature(), firstSignature, "bag order cannot invalidate identical inventory")

local defaultModel = ns.RebuildClickModel(pack)
local function Row(model, binding)
  for _, row in ipairs(model.rows) do if row.binding == binding then return row end end
end
Equal(Row(defaultModel, "*%s5").secureType, "assist", "new selector does not silently overwrite default Assist")
assert(ns.SetClickBindingOverride(pack, "button5", "BANDAGE"))
local selectedModel = ns.RebuildClickModel(pack)
assert(Row(selectedModel, "*%s5").macroText:find("item:239711", 1, true), "explicit bandage assignment overrides Assist")
assert(Row(selectedModel, "*%s5").macroText:find("[@mouseover,help,exists,nodead]", 1, true), "secure hardware macro keeps target conditions")
pack.cure.bandageMode, pack.cure.bandageItemID = "SELECTED", 194050
local pinned = ns.RebuildClickModel(pack)
assert(Row(pinned, "*%s5").macroText:find("item:194050", 1, true), "selection change invalidates cached click model before cache return")
editingPack.cure.bandageMode, editingPack.cure.bandageItemID = "SELECTED", 224442
Equal(ns.GetBandageInventoryStatus(editingPack).itemID, 224442, "editing pack has independent selection preview")
Equal(ns.RebuildClickModel(pack), pinned, "editing inventory preview cannot replace applied click model")
data[194050].count = 0
status = Refresh()
Equal(status.status, "SELECTED_MISSING", "depleted pin remains visibly selected and missing")
Equal(status.selectedItemID, 194050, "depleted pin persists")
Equal(status.itemID, nil, "depleted pin never silently falls back")
Equal(Row(ns.RebuildClickModel(pack), "*%s5").secureType, "", "unavailable explicit bandage prevents wildcard fallthrough")
data[194050].count, data[194050].usable = 2, false
Equal(Refresh().status, "SELECTED_UNUSABLE", "unusable carried pin shown but cannot be bound")
data[194050].usable = secret
Equal(Refresh().status, "UNKNOWN", "restricted usability is unknown rather than ready")
data[194050].usable, data[194050].count = true, secret
Equal(Refresh().status, "UNKNOWN", "restricted count is unknown rather than empty")
data[194050].count = 2
pack.cure.bandageMode = "OFF"
Equal(Refresh().status, "OFF", "OFF disables selection")
Equal(Row(ns.RebuildClickModel(pack), "*%s5").secureType, "", "OFF explicit bandage never inherits another action")

pack.cure.bandageMode = "AUTO"
data[239711].cold = true
status = Refresh()
Equal(status.status, "LOADING", "cold classification never guesses a bandage or alternative")
Equal(status.itemID, nil, "AUTO waits for complete public ranking")
Equal(requests[239711], 1, "metadata requested once")
Refresh(); Refresh()
Equal(requests[239711], 1, "bag refresh cannot duplicate in-flight metadata request")
assert(ns.BandageItemDataResult(239711))
Refresh()
Equal(requests[239711], 2, "failed/empty metadata completion permits one bounded retry")
assert(ns.BandageItemDataResult(239711))
Refresh(); Refresh()
Equal(requests[239711], 2, "automatic failed metadata requests are bounded")
ns.RefreshBandageInventory("OPTIONS_BANDAGES")
Equal(requests[239711], 3, "explicit user refresh can retry failed metadata")
data[239711].cold = false
assert(ns.BandageItemDataResult(239711))
Equal(Refresh().itemID, 239711, "metadata completion restores inventory choice")

local timers = {}
C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}
assert(loadfile("ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
local engine, refreshes = ns.DetectionEngine, 0
engine.Refresh = function(self)
  if combat then self.pending = true; return false end
  refreshes = refreshes + 1
  ns.RebuildClickModel(pack)
  self.itemActionSignature = "SOUL0|bandages:" .. ns.GetBandageInventorySignature()
  self.pending = false
  return true
end
local function Drain()
  while #timers > 0 do table.remove(timers, 1)() end
end
engine:Refresh()
local generation = refreshes
data[239711].count = 0
engine:OnEvent("ITEM_COUNT_CHANGED", 239711, 0)
engine:OnEvent("BAG_UPDATE_DELAYED")
Equal(#timers, 1, "bandage item and bag events coalesce")
Drain()
Equal(refreshes, generation + 1, "bandage removal refreshes even when Soul Link count unchanged")
Equal(ns.RebuildClickModel(pack).bandage.itemID, 224442, "event clears stale removed bandage and resolves next AUTO item")
generation = refreshes
engine:OnEvent("GET_ITEM_INFO_RECEIVED", 88888, true)
Equal(#timers, 0, "unobserved item-cache event does not scan inventory")
engine:OnEvent("BAG_UPDATE_DELAYED"); Drain()
Equal(refreshes, generation, "unchanged bag inventory skips engine reconciliation")

local frozen = ns.RebuildClickModel(pack)
local callsBeforeCombat = apiCalls
combat = true
data[239711].count = 3
engine:OnEvent("ITEM_COUNT_CHANGED", 239711, 3)
Drain()
Equal(ns.RebuildClickModel(pack), frozen, "combat acquisition preserves installed click model")
Equal(ns.GetBandageInventoryStatus(pack).status, "DEFERRED_COMBAT", "pending inventory is visible without protected mutation")
Equal(apiCalls, callsBeforeCombat, "combat inventory events/status never rescan bags or metadata")
assert(engine.pending, "combat change keeps recovery pending")
combat = false
engine:Refresh()
Equal(ns.RebuildClickModel(pack).bandage.itemID, 239711, "out-of-combat recovery discovers acquired bandage")
Equal(ns.GetBandageInventoryStatus(pack).pending, false, "recovery clears inventory pending")
io.write("bandage-inventory-contract: ok\n")
