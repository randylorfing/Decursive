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

-- A reminder observes public carried stock; it cannot choose or use an item.
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local packs = ns.MakeEnvironments()
for _, pack in pairs(packs) do
  assert(pack.cure.bandageLowStockEnabled == false, "every fresh pack makes stock reminders opt-in")
  assert(pack.cure.bandageLowStockThreshold == 5, "every fresh pack has a useful threshold")
end
local pack, combat, inventoryCalls = packs.PVP, false, 0
ns.addon = {GetAppliedEnvironmentPack = function() return pack end}
local secret = setmetatable({}, {__tostring = function() error("secret stringify") end})
issecretvalue = function(value) return value == secret end
ns.IsAccessible = function(value) return value ~= secret end
ns.PublicValue = function(value) if value ~= secret then return value end end
InCombatLockdown = function() return combat end
NUM_BAG_SLOTS = 0
local data = {
  [123] = {count = 5, level = 100, usable = true, class = 0, sub = 7},
  [456] = {count = 3, level = 90, usable = true, class = 0, sub = 7},
}
local function Call()
  assert(not combat, "combat never scans bags or reads item metadata")
  inventoryCalls = inventoryCalls + 1
end
C_Container = {
  GetContainerNumSlots = function() Call(); return 2 end,
  GetContainerItemInfo = function(_, slot) Call(); return {itemID = slot == 1 and 123 or 456} end,
}
C_Item = {
  GetItemInfoInstant = function(itemID)
    Call(); local d = data[itemID]
    if not d or d.cold then return end
    return itemID, nil, nil, nil, nil, d.class, d.sub
  end,
  GetItemInfo = function(itemID) Call(); return "Public bandage", nil, 1, data[itemID].level end,
  GetItemCount = function(itemID, bank, uses, reagent, account)
    Call(); assert(not bank and not uses and not reagent and not account)
    return data[itemID].count
  end,
  IsUsableItem = function(itemID) Call(); return data[itemID].usable end,
}
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
local shown, hidden, records = 0, 0, {}
ns.ShowBandageLowStockReminder = function(status) assert(status.low); shown = shown + 1; return true end
ns.HideBandageLowStockReminder = function() hidden = hidden + 1 end
ns.DiagnosticRecord = function(kind, fields)
  if kind ~= "BANDAGE_LOW_STOCK" then return end
  assert(fields.itemID == nil and fields.name == nil, "diagnostics contain no item identities")
  records[#records + 1] = fields
end
local function Refresh()
  ns.MarkBandageInventoryDirty()
  return ns.RefreshBandageLowStockReminder()
end
assert(ns.GetBandageLowStockStatus(pack).status == "DISABLED")
Refresh()
assert(shown == 0 and inventoryCalls == 0, "disabled reminders do no inventory work")
pack.cure.bandageLowStockEnabled = true
assert(Refresh(), "threshold crossing warns once")
assert(shown == 1 and records[1].count == 5)
Refresh(); Refresh()
data[123].count = 4; Refresh()
data[123].count = 3; Refresh()
assert(shown == 1 and #records == 1, "unchanged/declining stock does not spam")
data[123].count = 9; Refresh()
data[123].count = 5; assert(Refresh(), "restock rearms next low-stock episode")
assert(shown == 2)
pack.cure.bandageMode, pack.cure.bandageItemID = "SELECTED", 456
assert(Refresh(), "a different chosen item owns a different episode")
assert(shown == 3)
data[456].count = 0
assert(Refresh(), "complete eligible depleted pin gets one zero-stock reminder")
assert(records[#records].result == "EMPTY" and records[#records].count == 0)
Refresh(); assert(shown == 4, "empty pin is deduplicated")
data[456].count = 2
local hides = hidden
Refresh(); assert(shown == 4 and hidden > hides, "a small restock clears obsolete empty banner without repeating low stock")
data[456].count = 0; assert(Refresh(), "depletion after a small restock is a new empty edge")
local countBefore = shown
pack.cure.bandageLowStockEnabled = false
hides = hidden
ns.RefreshBandageLowStockReminder()
assert(hidden > hides and shown == countBefore, "toggle off immediately dismisses")
pack.cure.bandageLowStockEnabled = true
assert(ns.RefreshBandageLowStockReminder(), "explicit re-enable starts a fresh reminder")

countBefore = shown
combat = true
local callsBefore = inventoryCalls
data[456].count = 9
ns.MarkBandageInventoryDirty()
local emitted, status = ns.RefreshBandageLowStockReminder()
assert(not emitted and status.status == "DEFERRED_COMBAT")
assert(inventoryCalls == callsBefore and shown == countBefore, "combat hides without scanning or reminding")
combat = false
assert(not ns.RefreshBandageLowStockReminder(), "recovery sees healthy stock")
data[456].count = 1; assert(Refresh(), "post-combat low stock can warn")

countBefore = shown
data[456].usable = false
assert(not Refresh() and ns.GetBandageLowStockStatus(pack).status == "UNUSABLE", "unusable carried pin cannot be low stock")
data[456].usable = secret
assert(not Refresh() and ns.GetBandageLowStockStatus(pack).status == "UNKNOWN", "secret usability is unknown")
data[456].usable, data[456].count = true, secret
assert(not Refresh() and ns.GetBandageLowStockStatus(pack).status == "UNKNOWN", "secret count never implies zero")
data[456].count, data[456].cold = 0, true
assert(not Refresh() and ns.GetBandageLowStockStatus(pack).status == "UNKNOWN", "unknown metadata cannot imply depleted pin")
data[456].cold, data[456].count = false, 2
pack.cure.bandageMode = "OFF"
assert(not Refresh() and ns.GetBandageLowStockStatus(pack).status == "OFF")
assert(shown == countBefore, "unavailable items and OFF do not warn")
local editingPack = packs.DUNGEON
editingPack.cure.bandageLowStockEnabled = true
editingPack.cure.bandageLowStockThreshold = 17
assert(ns.GetBandageLowStockStatus(editingPack).low, "editing pack can preview its own threshold")
assert(not ns.RefreshBandageLowStockReminder(), "editing preview does not emit or replace applied pack")
assert(shown == countBefore)

-- Exercise the actual separate banner, timer ownership and combat dismissal.
local timers, frames = {}, {}
C_Timer = {After = function(seconds, callback) assert(seconds == 8); timers[#timers + 1] = callback end}
UIParent = {}
CreateFrame = function(kind, name, parent, template)
  assert(kind == "Frame" and parent == UIParent and template == nil, "reminder is addon-owned and nonsecure")
  local frame = {shown = false, name = name, scripts = {}}
  function frame:SetSize() end
  function frame:SetPoint() end
  function frame:ClearAllPoints() end
  function frame:SetFrameStrata() end
  function frame:SetMovable() end
  function frame:RegisterForDrag() end
  function frame:EnableMouse(value) assert(value == false, "reminder cannot eat clicks") end
  function frame:RegisterEvent(event) assert(event == "PLAYER_REGEN_DISABLED") end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:CreateTexture()
    return {SetAllPoints = function() end, SetColorTexture = function() end}
  end
  function frame:CreateFontString()
    return {SetPoint = function() end, SetTextColor = function() end,
      SetFont = function() end, SetAllPoints = function() end, SetJustifyH = function() end,
      SetText = function(_, text) frame.text = text end}
  end
  frames[#frames + 1] = frame
  return frame
end
assert(loadfile("ZDecursive/Alerts.lua"))("ZDecursive", ns)
local low = {low = true, count = 3}
assert(ns.ShowBandageLowStockReminder(low))
local banner = frames[1]
assert(#frames == 1 and banner.shown and banner.text:find("3 remaining", 1, true))
ns.HideBandageLowStockReminder()
assert(not banner.shown)
assert(ns.ShowBandageLowStockReminder({low = true, count = 0}))
timers[1]()
assert(banner.shown and banner.text:find("out of stock", 1, true), "old timer cannot dismiss a later reminder")
combat = true
banner.scripts.OnEvent(banner, "PLAYER_REGEN_DISABLED")
assert(not banner.shown and not ns.ShowBandageLowStockReminder(low), "combat hides its banner and cannot construct/show another")
combat = false
assert(ns.ShowBandageLowStockReminder(low))
timers[#timers]()
assert(not banner.shown, "current reminder expires")
assert(not ns.ShowBandageLowStockReminder({low = true, count = secret}), "presenter rejects a secret count")
assert(not ns.ShowBandageLowStockReminder({low = true, count = 0 / 0}), "presenter rejects NaN")
assert(#frames == 1, "stock reminder never touches or constructs shared dispel/Soul Link text")

-- Load the full Options module so catalog metadata and the production setters
-- participate in the same applied-pack controller and real banner behavior.
pack = ns.MakePack("PVP")
pack.cure.bandageMode, pack.cure.bandageItemID = "SELECTED", 123
data[123].count, data[456].count = 3, 2
ns.MarkBandageInventoryDirty()
local editing = pack
ns.addon.GetEditingPack = function() return editing end
ns.addon.GetEditingEnvironment = function() return editing == pack and "PVP" or "DUNGEON" end
ns.RebuildClickModel = nil -- This contract does not construct secure click rows.
local engineRefreshes = 0
ns.DetectionEngine = {Refresh = function()
  engineRefreshes = engineRefreshes + 1
  return ns.RefreshBandageLowStockReminder()
end}
local optionsFile = assert(io.open("ZDecursive/Options.lua", "rb"))
local optionsSource = optionsFile:read("*a")
optionsFile:close()
local options = assert(load(optionsSource .. [[
return {catalog = CATALOG, menu = OpenBandageMenu, status = BandageReminderStatusText}
]], "@ZDecursive/Options.lua"))("ZDecursive", ns)
ns.RefreshOptions = function() end
local specs = {}
for _, spec in ipairs(options.catalog) do specs[spec.label] = spec end
local toggle, threshold, readout = specs["Low-stock reminder"], specs["Low-stock threshold"], specs["Stock reminder status"]
assert(toggle and threshold and readout, "stock controls are in the actual catalog")
for _, spec in ipairs({toggle, threshold, readout}) do
  assert(spec.page == "items" and spec.group == "Stock reminders" and spec.simple == true, "all stock controls are together in Supplies and remain visible in Simple mode")
  assert(type(spec.description) == "string" and #spec.description > 40, "each stock control explains its effect")
end
assert(toggle.kind == "toggle" and toggle.get() == false, "catalog exposes opt-in default")
assert(threshold.kind == "slider" and threshold.get() == 5 and threshold.min == 1 and threshold.max == 200 and threshold.step == 1)
assert(readout.get():find("Off", 1, true), "disabled state is explicit")
threshold.set(7)
assert(pack.cure.bandageLowStockThreshold == 7 and not banner.shown)
toggle.set(true)
assert(banner.shown and banner.text:find("3 remaining", 1, true), "actual toggle shows the applied pack's reminder")
assert(readout.get():find("3 carried", 1, true) and readout.get():find("7", 1, true), "readout shows known stock and configured threshold")
assert(ns.PlayTestText(pack), "actual shared dispel/Soul Link alert frame can display independently")
local otherAlert = frames[2]
assert(otherAlert.name == "DecursiveRebuildDispelText" and otherAlert.shown and otherAlert.text == "DISPEL")
toggle.set(false)
assert(not banner.shown and otherAlert.shown and otherAlert.text == "DISPEL", "actual disable dismisses only stock banner")
toggle.set(true)
assert(banner.shown)
editing = ns.MakePack("DUNGEON")
editing.cure.bandageLowStockEnabled = true
toggle.set(false)
assert(editing.cure.bandageLowStockEnabled == false and pack.cure.bandageLowStockEnabled == true)
assert(banner.shown and otherAlert.shown, "editing an inactive environment cannot dismiss applied stock or legitimate alerts")
threshold.set(19)
assert(editing.cure.bandageLowStockThreshold == 19 and pack.cure.bandageLowStockThreshold == 7)
local beforeCalls, beforeRefreshes = inventoryCalls, engineRefreshes
combat = true
toggle.set(true); threshold.set(1)
assert(editing.cure.bandageLowStockEnabled == false and editing.cure.bandageLowStockThreshold == 19)
assert(engineRefreshes == beforeRefreshes and inventoryCalls == beforeCalls, "combat rejects actual settings handlers before runtime or inventory work")
combat = false

-- Blizzard owns the item tooltip. Menu hover receives only the public item ID
-- captured from the OOC inventory; stale or combat callbacks never inspect it.
editing = pack
local entries = {}
MenuUtil = {CreateContextMenu = function(_, build)
  build(nil, {CreateTitle = function() end, CreateDivider = function() end,
    CreateRadio = function(_, label, checked, picked)
      local entry = {label = label, checked = checked, picked = picked}
      function entry:SetTooltip(callback) self.tooltip = callback end
      entries[#entries + 1] = entry
      return entry
    end})
end}
assert(options.menu({}))
local selected
for _, entry in ipairs(entries) do
  if entry.checked() then selected = entry end
end
assert(selected and selected.tooltip, "selected bandage menu row has native tooltip callback")
local tooltipCalls, tooltipItem = 0
local tooltip = {SetItemByID = function(_, itemID)
  assert(not combat, "no native item tooltip work in combat")
  tooltipCalls, tooltipItem = tooltipCalls + 1, itemID
end}
beforeCalls = inventoryCalls
selected.tooltip(tooltip)
assert(tooltipCalls == 1 and tooltipItem == 123 and inventoryCalls == beforeCalls, "hover binds Blizzard tooltip without rescanning or reading target data")
combat = true
selected.tooltip(tooltip)
assert(not options.menu({}) and tooltipCalls == 1 and inventoryCalls == beforeCalls, "combat blocks both stale hover and menu inventory access")
combat = false
editing = ns.MakePack("DUNGEON")
selected.tooltip(tooltip)
assert(tooltipCalls == 1, "stale environment hover cannot show the prior selection")
io.write("bandage-low-stock-contract: ok\n")
