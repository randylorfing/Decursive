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

-- Exercises actual Options callbacks with independent editing/storage contexts.
local checks = 0
local function Check(value, message)
  assert(value, message)
  checks = checks + 1
end
local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a")
file:close()
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local packs = {OPEN_WORLD = ns.MakePack("OPEN_WORLD"), DUNGEON = ns.MakePack("DUNGEON")}
local environment, combat, picker, hideCount = "OPEN_WORLD", false, nil, 0
local addon = {db = {profile = {}, global = {}}}
ns.addon = addon
function addon:GetEditingPack() return packs[environment] end
function addon:GetEditingEnvironment() return environment end
function addon:GetCurrentProfileName() return "Default" end
function addon:GetEnvironmentMode() return "multiple" end
function addon:GetUIProfileStatus() return {available = true, actualProfile = "Active"} end
function addon:GetProfileNames() return {"Active", "Assigned"} end
local copies = 0
function addon:CopyEditingPackTo() copies = copies + 1; return true end
InCombatLockdown = function() return combat end
CreateFrame = function()
  return {
    SetSize = function() end, SetBackdrop = function() end,
    SetBackdropColor = function() end, SetBackdropBorderColor = function() end,
    SetScript = function(self, event, callback) self[event] = callback end,
  }
end
ColorPickerFrame = {
  SetupColorPickerAndShow = function(self, options)
    picker = options
    self.owner = options.extraInfo
    -- Retail SetupColorPickerAndShow invokes both callbacks while initializing RGB,
    -- before OnShow installs the initial alpha. Neither callback is a user change.
    options.swatchFunc()
    if options.opacityFunc then options.opacityFunc() end
  end,
  GetExtraInfo = function(self) return self.owner end,
  GetColorRGB = function() return 0.9, 0.8, 0.7 end,
  GetColorAlpha = function() return 0.4 end,
  Hide = function() hideCount = hideCount + 1 end,
}
local Compile = loadstring or load
local access = assert(Compile(source .. [[
return {
  swatch = MakeColorSwatch, setter = PathSet, ui = ui,
  close = CloseOptionsTransients, modal = ShowModal, confirm = ShowConfirm,
  hideModal = HideModal, profileMenu = OpenProfileMenu, copyMenu = OpenEnvCopyMenu,
}
]], "@Options-transients-under-test"))("ZDecursive", ns)
ns.RefreshOptions = function() end
local function Stub()
  return setmetatable({shown = true}, {__index = function(_, key)
    if key == "IsShown" then return function(self) return self.shown end end
    if key == "Hide" then return function(self) self.shown = false end end
    if key == "Show" then return function(self) self.shown = true end end
    return function() end
  end})
end
access.ui.modal = Stub()
for _, name in ipairs({"title", "edit", "hint", "ok"}) do access.ui.modal[name] = Stub() end
local button = access.swatch({}, true)
local colorWrites = 0
button.OnValueChanged = function(_, color)
  colorWrites = colorWrites + 1
  access.setter("colors", "poison")(color)
end
local function OpenPicker()
  button:SetColor(packs[environment].colors.poison)
  button.OnClick(button)
  return picker
end
local original = packs.OPEN_WORLD.colors.poison
local opened = OpenPicker()
Check(colorWrites == 0 and packs.OPEN_WORLD.colors.poison == original, "opening the native picker does not save intermediate setup colors or stale alpha")
opened.swatchFunc()
opened.opacityFunc()
Check(colorWrites == 1, "native paired swatch and opacity callbacks refresh once for one value")
Check(packs.OPEN_WORLD.colors.poison[1] == 0.9 and packs.OPEN_WORLD.colors.poison[4] == 0.4, "valid swatch applies RGBA")
opened.cancelFunc({r = original[1], g = original[2], b = original[3], a = original[4]})
Check(packs.OPEN_WORLD.colors.poison[1] == original[1] and packs.OPEN_WORLD.colors.poison[4] == original[4], "Cancel restores initial color")
opened = OpenPicker()
opened.opacityFunc()
Check(packs.OPEN_WORLD.colors.poison[4] == 0.4, "opacity-only callback applies alpha")
local beforeFirst = packs.OPEN_WORLD.colors.poison
local beforeSecond = packs.DUNGEON.colors.poison
environment = "DUNGEON"
opened.swatchFunc(); opened.opacityFunc(); opened.cancelFunc()
Check(packs.OPEN_WORLD.colors.poison == beforeFirst and packs.DUNGEON.colors.poison == beforeSecond, "stale picker never edits a different environment")
environment = "OPEN_WORLD"
opened = OpenPicker()
addon.db.profile = {}
beforeFirst = packs.OPEN_WORLD.colors.poison
opened.swatchFunc()
Check(packs.OPEN_WORLD.colors.poison == beforeFirst, "replaced profile storage invalidates picker even if pack reference is retained")
opened = OpenPicker()
combat = true
opened.swatchFunc(); opened.opacityFunc(); opened.cancelFunc()
Check(packs.OPEN_WORLD.colors.poison == beforeFirst, "all picker callbacks reject combat")
combat = false
opened = OpenPicker()
local priorHideCount = hideCount
access.close()
opened.swatchFunc()
Check(hideCount == priorHideCount + 1 and packs.OPEN_WORLD.colors.poison == beforeFirst, "closing options hides its owned picker and invalidates callbacks")
opened = OpenPicker()
ColorPickerFrame.owner = {}
priorHideCount = hideCount
local priorWrites = colorWrites
opened.swatchFunc()
Check(colorWrites == priorWrites, "callback rejects a picker now owned by another caller")
access.close()
Check(hideCount == priorHideCount, "cleanup never hides another addon's picker")
opened = OpenPicker()
local newer = OpenPicker()
opened.swatchFunc()
Check(packs.OPEN_WORLD.colors.poison == beforeFirst, "superseded picker callback cannot apply")
newer.cancelFunc()

local writes = 0
local function Write() writes = writes + 1 end
access.modal("Edit", "", Write)
local accept = access.ui.modal.onAccept
accept("value"); accept("twice")
Check(writes == 1, "modal acceptance is single-use")
access.modal("Edit", "", Write)
accept = access.ui.modal.onAccept
environment = "DUNGEON"
accept("wrong environment")
Check(writes == 1, "text modal rejects changed editing context")
environment = "OPEN_WORLD"
access.confirm("Reset", "", Write)
accept = access.ui.modal.onAccept
addon.db.profile = {}
accept()
Check(writes == 1, "reset confirmation rejects replaced storage")
access.confirm("Reset", "", Write)
accept = access.ui.modal.onAccept
access.hideModal(); accept()
Check(writes == 1, "cancelled confirmation callback is inactive")
access.confirm("First", "", Write)
accept = access.ui.modal.onAccept
access.confirm("Second", "", Write)
accept()
Check(writes == 1, "superseded confirmation cannot accept")
access.ui.modal.onAccept()
Check(writes == 2, "current confirmation remains usable")
access.modal("Edit", "", Write)
accept = access.ui.modal.onAccept
combat = true; accept("locked"); combat = false
Check(writes == 2, "modal rejects combat")

local entries = {}
MenuUtil = {CreateContextMenu = function(_, build)
  entries = {}
  build({}, {
    CreateTitle = function() end, CreateDivider = function() end,
    CreateRadio = function(_, label, selected, select) entries[label] = {selected = selected, select = select} end,
    CreateButton = function(_, label, select) entries[label] = {select = select} end,
  })
end}
local selectedProfile
access.profileMenu({}, function(value) selectedProfile = value end, false, function() return "Assigned" end)
Check(entries.Assigned.selected() and not entries.Active.selected(), "assignment menu checks field assignment rather than resolved active profile")
entries.Assigned.select()
Check(selectedProfile == "Assigned", "current profile menu is usable")
access.profileMenu({}, Write, true, function() return nil end)
Check(entries["Use account / Default"].selected() and not entries.Active.selected(), "inherited assignment shows its own checked entry")
local staleMenu = entries.Active.select
environment = "DUNGEON"; staleMenu()
Check(writes == 2, "profile menu rejects a different editing context")
environment = "OPEN_WORLD"
access.copyMenu({})
local copy = entries.Dungeon.select
environment = "DUNGEON"; copy()
Check(copies == 0, "environment copy rejects a changed source")
environment = "OPEN_WORLD"
copy()
Check(copies == 1, "environment copy executes for the captured source")
io.write("options-transients-contract: ", checks, " checks passed\n")
