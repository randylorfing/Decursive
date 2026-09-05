-- ZDecursive, based on Decursive, Copyright (C) 2006-2026 John Wellesz.
-- ZDecursive rebuild and maintenance, Copyright (C) 2026 Randy Lorfing.
-- Licensed under the GNU General Public License version 3 or later.
-- Distributed without warranty. See ../LICENSE.
local function Check(value, message) if not value then error(message, 2) end end
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/ClickBindings.lua"))("ZDecursive", ns)
local editing, applied = ns.MakePack("PVP"), ns.MakePack("DUNGEON")
local combat, refreshes, scans = false, 0, 0
InCombatLockdown = function() return combat end
ns.addon = {
  GetEditingPack = function() return editing end,
  GetEditingEnvironment = function() return "PVP" end,
  GetAppliedEnvironmentPack = function() return applied end,
}
ns.DetectionEngine = {Refresh = function() refreshes = refreshes + 1 end}
local inventory = {status = "READY", selectedName = "Bright Linen", items = {
  {itemID = 239713, name = "Bright Linen", count = 4, itemLevel = 180, status = "READY"},
  {itemID = 1251, name = "Linen", count = 10, itemLevel = 10, status = "UNUSABLE"},
}}
ns.GetBandageInventoryStatus = function(pack)
  Check(pack == editing, "inventory is resolved for editing environment")
  return inventory
end
ns.RefreshBandageInventory = function() scans = scans + 1 return false end
local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a")
file:close()
local api = assert(load(source .. [[
return {choices = BandageChoices, select = SetBandageChoice, menu = OpenBandageMenu,
  button5 = AssignBandageButton5, status = BandageStatusText, binding = BandageBindingText,
  catalog = CATALOG, visible = RowVisible}
]], "@ZDecursive/Options.lua"))("ZDecursive", ns)
ns.RefreshOptions = function() end

local values = api.choices()
Check(values["item:239713"]:find("(4)", 1, true), "selection list shows carried count")
Check(values["item:1251"]:find("Currently unusable", 1, true), "detected unusable item is still visible")
api.select("item:239713")
Check(editing.cure.bandageMode == "SELECTED" and editing.cure.bandageItemID == 239713, "item can be pinned")
Check(applied.cure.bandageMode == "AUTO" and applied.cure.bandageItemID == 0, "editing does not change applied environment settings")
Check(ns.GetClickBindingOverride(editing, "button5") == nil, "item selection does not overwrite click bindings")
api.button5()
Check(ns.GetClickBindingOverride(editing, "button5") == "BANDAGE", "explicit assignment replaces Button 5 action")
Check(api.binding():find("Button 5", 1, true), "assigned bandage click is visible")
api.select("item:999999")
Check(editing.cure.bandageItemID == 239713, "unrecognized item selection cannot enter saved settings")
api.select("OFF")
Check(editing.cure.bandageMode == "OFF" and editing.cure.bandageItemID == 239713, "Off retains pinned preference")
api.select("item:239713")

local entries = {}
MenuUtil = {CreateContextMenu = function(_, build)
  build(nil, {CreateTitle = function() end, CreateDivider = function() end,
    CreateRadio = function(_, label, checked, picked)
      entries[#entries + 1] = {label = label, checked = checked, picked = picked}
    end})
end}
Check(api.menu({}) and scans == 1, "opening inventory requests an out-of-combat refresh")
Check(#entries == 4, "menu contains automatic, off, and both detected items")
Check(entries[3].checked(), "pinned item is selected in the menu")
local priorEditing = editing
editing = ns.MakePack("RAID")
entries[3].picked()
Check(editing.cure.bandageMode == "AUTO", "stale menu cannot change another environment")
Check(priorEditing.cure.bandageItemID == 239713, "stale menu preserves original environment")
editing = priorEditing
combat = true
local beforeRefreshes, beforeScans = refreshes, scans
api.select("OFF")
api.button5()
entries[2].picked()
Check(not api.menu({}), "combat rejects menu construction")
Check(editing.cure.bandageMode == "SELECTED" and refreshes == beforeRefreshes and scans == beforeScans,
  "combat blocks settings, inventory work, and runtime refresh")
combat = false
inventory.items = {}
inventory.status = "SELECTED_MISSING"
Check(api.choices()["item:239713"]:find("not carried", 1, true), "empty inventory retains visible pinned choice")
Check(api.status():find("not in your bags", 1, true), "missing selected item has explanatory status")
local rows = 0
for _, spec in ipairs(api.catalog) do
  if spec.group == "Bandages" then
    rows = rows + 1
    Check(spec.simple and api.visible(spec), "bandage controls are reachable in Simple mode")
    Check(type(spec.description) == "string" and #spec.description > 30, "bandage control has useful help")
  end
end
Check(rows == 5, "all bandage section controls are reachable")
io.write("bandage-options-contract: ok\n")
