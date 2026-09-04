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

local function Check(value, message)
  if not value then
    error(message, 2)
  end
end

local scripts = {}
local regions = {}
local function Region(kind, name, parent)
  local region = {
    kind = kind,
    name = name,
    parent = parent,
    shown = true,
    width = 1100,
    height = 780,
    text = "",
  }
  local methods = {}
  function methods:CreateTexture()
    return Region("Texture", nil, self)
  end
  function methods:CreateFontString()
    return Region("FontString", nil, self)
  end
  function methods:SetScript(event, callback)
    self.scripts = rawget(self, "scripts") or {}
    self.scripts[event] = callback
    scripts[#scripts + 1] = {owner = self, event = event, callback = callback}
  end
  function methods:SetText(value)
    self.text = tostring(value or "")
  end
  function methods:GetText()
    return self.text
  end
  function methods:GetName()
    return self.name
  end
  function methods:GetParent()
    return self.parent
  end
  function methods:GetChildren()
    return nil
  end
  function methods:GetWidth()
    return self.width
  end
  function methods:GetHeight()
    return self.height
  end
  function methods:GetFrameLevel()
    return 1
  end
  function methods:IsShown()
    return self.shown
  end
  function methods:Show()
    self.shown = true
  end
  function methods:Hide()
    self.shown = false
  end
  function methods:SetShown(value)
    self.shown = value == true
  end
  function methods:SetSize(width, height)
    self.width = width
    self.height = height
  end
  function methods:SetWidth(width)
    self.width = width
  end
  function methods:SetHeight(height)
    self.height = height
  end
  function methods:GetVerticalScrollRange()
    return 0
  end
  function methods:GetVerticalScroll()
    return 0
  end
  setmetatable(region, {
    __index = function(_, key)
      if methods[key] then
        return methods[key]
      end
      return function() end
    end,
  })
  regions[#regions + 1] = region
  return region
end

local function HasText(expected)
  for i = 1, #regions do
    if regions[i].text == expected then
      return true
    end
  end
  return false
end

local function HasTextContaining(expected)
  for i = 1, #regions do
    if tostring(regions[i].text or ""):find(expected, 1, true) then
      return true
    end
  end
  return false
end

local function AssertPlainEnvironmentLabels(message)
  for _, label in ipairs({"Open World", "Dungeon", "Mythic+", "Raid", "PvP"}) do
    Check(HasText(label), message .. ": missing exact label " .. label)
  end
  for i = 1, #regions do
    local text = tostring(regions[i].text or "")
    Check(not text:find("|T", 1, true), message .. ": inline texture marker found")
    Check(not text:find("\226\156\147", 1, true), message .. ": Unicode check marker found")
  end
end

UIParent = Region("Frame", "UIParent")
GameFontHighlight = {}
GameFontHighlightLarge = {}
GameFontNormal = {}
GameFontNormalLarge = {}
GameFontDisable = {}
UISpecialFrames = {}
tinsert = table.insert
strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end
local combat = false
local clock = 100
local combatMessages = {}
local diagnosticEvents = {}
InCombatLockdown = function()
  return combat
end
GetTime = function()
  return clock
end
UIErrorsFrame = {
  AddMessage = function(_, message)
    combatMessages[#combatMessages + 1] = message
  end,
}
CreateFrame = function(kind, name, parent)
  return Region(kind, name, parent)
end

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local environments = ns.MakeEnvironments()
local environmentStatus = {
  available = true,
  appliedEnvironment = "OPEN_WORLD",
  detectedEnvironment = "OPEN_WORLD",
  environmentMode = "multiple",
  editingEnvironment = "OPEN_WORLD",
}
local addon = {
  db = {
    profile = {environments = environments},
    global = {accountProfile = "Default", characters = {}, specs = {}, schema = 3},
    char = {editingEnvironment = "OPEN_WORLD", optionsSimple = true},
  },
}
function addon:GetEditingEnvironment()
  return self.db.char.editingEnvironment
end
function addon:GetEditingPack()
  return self.db.profile.environments[self:GetEditingEnvironment()]
end
function addon:GetAppliedEnvironmentPack()
  return self.db.profile.environments.OPEN_WORLD
end
function addon:GetUIProfileStatus()
  return {available = true, actualProfile = "Default", resolvedProfile = "Default", resolvedTier = "default"}
end
function addon:GetEnvironmentProfileStatus()
  environmentStatus.editingEnvironment = self:GetEditingEnvironment()
  return environmentStatus
end
function addon:GetEnvironmentMode()
  return environmentStatus.environmentMode
end
function addon:SetEnvironmentMode(mode)
  environmentStatus.environmentMode = mode
  self.db.char.editingEnvironment = mode == "solo" and "SOLO" or "OPEN_WORLD"
  return true, "selected"
end
function addon:EnsureEnvironments() end
function addon:GetCurrentProfileName() return "Default" end
function addon:GetProfileNames() return {"Default"} end
function addon:GetCharacterKey() return nil end
function addon:GetSpecIndex() return 1 end
function addon:GetSpecName() return "Test specialization" end
function addon:SpecSlotCount() return 1 end
function addon:EnsureSpecAssignments() return {} end
function addon:GetSpecAssignment() return {enabled = false, profile = "Default"} end
function addon:SetEditingEnvironment(environment)
  if not ns.ENV_SET[environment] then
    return false, "env"
  end
  self.db.char.editingEnvironment = environment
  return true, "selected"
end
ns.addon = addon
ns.GetKnownCures = function()
  return {{name = "Test Cure", spellId = 123, types = {"magic"}}}
end
ns.GetResolvedClickStatus = function()
  return {
    available = true,
    mode = "AUTO",
    pending = false,
    mappings = {
      {gesture = "Middle", action = "Target", kind = "TARGET"},
      {gesture = "Ctrl+Middle", action = "Focus", kind = "FOCUS"},
    },
  }
end
ns.RegisterDiagnosticProvider = function(_, callback)
  ns.optionsDiagnosticProvider = callback
end
ns.DiagnosticModuleLoaded = function() end
ns.DiagnosticModuleEnabled = function() end
ns.DiagnosticModuleRefresh = function() end
ns.DiagnosticRecord = function(kind, fields)
  diagnosticEvents[#diagnosticEvents + 1] = {kind = kind, fields = fields}
end

-- Exercise real option-menu callbacks through persisted assignments to secure attributes.
local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Upvalue(fn, target)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == target then return value end
  end
  error("Missing test seam: " .. target)
end

local dungeonActions = {
  {spellId = 475, name = "Remove Curse", types = {"curse"}},
  {spellId = 4987, name = "Cleanse", types = {"magic", "poison", "disease"}},
}
local worldActions = {{spellId = 527, name = "Purify", types = {"magic", "disease"}}}
ns.GetKnownCures = function(pack)
  return pack == environments.DUNGEON and dungeonActions or worldActions
end
ns.GetSmartRezActions = function() return nil, nil, false, false end
local bandageCount = 1
Enum = {BagIndex = {Backpack = 0}}
C_Item = {
  GetItemSpell = function() return "Bandage", 212640 end,
  GetItemCount = function() return bandageCount end,
  IsUsableItem = function() return true end,
}
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and bandageCount > 0 and 1 or 0 end,
  GetContainerItemInfo = function() return {itemID = 133940} end,
}
function addon:GetAppliedEnvironmentPack()
  return self.db.profile.environments[environmentStatus.appliedEnvironment]
end
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
local install = Upvalue(ns.LayoutMUFs, "ApplyClickAttributes")
local secureButton = {attributes = {}}
function secureButton:SetAttribute(key, value)
  Check(not combat, "secure attribute mutation during combat")
  self.attributes[key] = value
end
ns.InvalidateDetection = function() ns.InvalidateClickModel() end
local refreshCount = 0
ns.DetectionEngine = {Refresh = function()
  refreshCount = refreshCount + 1
  return install(secureButton, addon:GetAppliedEnvironmentPack(), "party1")
end}
assert(loadfile("ZDecursive/Options.lua"))("ZDecursive", ns)
assert(ns.ShowOptions())
local ui = Upvalue(ns.ShowOptions, "ui")
local function Binding(label)
  for _, bind in ipairs(ui.binds) do if bind.label == label then return bind end end
  error("Binding not rendered: " .. label)
end
local function Row(label)
  for _, section in ipairs(ui.sections.cure) do
    for _, item in ipairs(section.rows) do if item.spec.label == label then return item.row end end
  end
  error("Row not found: " .. label)
end
local menu = {}
MenuUtil = {CreateContextMenu = function(_, build)
  menu = {}
  build(nil, {CreateRadio = function(_, label, selected, pick)
    menu[label] = {selected = selected, pick = pick}
  end})
end}
local function Open(label)
  local widget = Binding(label).widget
  widget.scripts.OnClick(widget)
  return menu
end
local function Pick(label, choice)
  local entries = Open(label)
  Check(entries[choice], "Menu choice missing: " .. label .. " / " .. choice)
  entries[choice].pick()
end
local function MacroIncludes(attribute, spell)
  local value = secureButton.attributes[attribute]
  return type(value) == "string" and value:find(spell, 1, true) ~= nil
end

ui.navButtons["environment:DUNGEON"].scripts.OnClick()
ui.tabs.cure.scripts.OnClick()
Check(ui.simple, "the reproduced scenario must start in Simple mode")
Check(not Row("Left click"):IsShown(), "AUTO keeps the existing Simple-mode layout")
Pick("Click mode", "MANUAL - per-button")
Equal(environments.DUNGEON.cure.mode, "MANUAL", "mode changes the editing pack")
Equal(environments.OPEN_WORLD.cure.mode, "AUTO", "mode does not change the applied Open World pack")
for _, label in ipairs({"Left click", "Right click", "Middle click", "Button 4", "Button 5"}) do
  Check(Row(label):IsShown(), "Manual exposes " .. label .. " in Simple mode")
end
local entries = Open("Left click")
Check(entries["Remove Curse"] and entries.Cleanse, "manual menu lists known editing-pack spells")
Check(not entries.Purify, "manual choices are not taken from the applied pack")
Pick("Left click", "Remove Curse")
Equal(environments.DUNGEON.cure.manual["spell:475"], "left", "spell assignment persists")
Equal(Binding("Left click").widget:GetText(), "Remove Curse", "button displays the selected spell")
Check(MacroIncludes("*macrotext1", "Purify"), "editing Dungeon leaves Open World runtime bindings intact")
Check(not MacroIncludes("*macrotext1", "Remove Curse"), "editing pack cannot leak into applied macros")

environmentStatus.appliedEnvironment = "DUNGEON"
ns.DetectionEngine:Refresh()
Check(MacroIncludes("*macrotext1", "Remove Curse"), "applying the edited pack installs the chosen spell")
Pick("Right click", "Remove Curse")
Equal(environments.DUNGEON.cure.manual["spell:475"], "right", "moving a spell updates its one assignment")
Equal(Binding("Left click").widget:GetText(), "Automatic cure", "the previous button shows automatic fallback")
Check(MacroIncludes("*macrotext2", "Remove Curse"), "moved spell reaches the new secure button")
Pick("Right click", "Cleanse")
Equal(environments.DUNGEON.cure.manual["spell:475"], nil, "replacement clears the button's prior spell")
Equal(environments.DUNGEON.cure.manual["spell:4987"], "right", "replacement saves the new spell")
Pick("Right click", "Target")
Equal(environments.DUNGEON.cure.manual["spell:4987"], nil, "choosing a utility action clears explicit spell mapping")
Equal(secureButton.attributes["*type2"], "target", "utility choice installs its secure action")

for _, option in ipairs({{"Button 4", "button4", "*macrotext4"}, {"Button 5", "button5", "*macrotext5"}}) do
  Pick(option[1], "Remove Curse")
  Equal(environments.DUNGEON.mouse[option[2]], "CURE", "a spell replaces the utility action")
  Check(MacroIncludes(option[3], "Remove Curse"), "explicit spell wins for " .. option[1])
end
Check(not MacroIncludes("*macrotext5", "133940"), "carried bandage cannot override explicit Button 5 spell")
Pick("Button 5", "Automatic cure / bandage")
Check(MacroIncludes("*macrotext5", "133940"), "clearing explicit Button 5 assignment restores bandage fallback")
Pick("Left click", "Remove Curse")
local selected = Open("Left click")["Remove Curse"]
Check(selected.selected(), "menu checks the stored spell")
ui.simple = false
ns.RefreshOptions()
Check(Row("Left click"):IsShown(), "Manual spell controls are also reachable in All mode")
Pick("Click mode", "AUTO - priority bindings")
Equal(environments.DUNGEON.cure.manual["spell:475"], "left", "AUTO preserves saved manual choices")
Check(not Open("Left click")["Remove Curse"], "AUTO menus keep action choices separate from manual spells")
Pick("Click mode", "MANUAL - per-button")
Equal(Binding("Left click").widget:GetText(), "Remove Curse", "returning to MANUAL restores the stored choice")

-- Switching packs or profiles while a menu is open must not retarget its callback.
local stalePick = Open("Right click").Cleanse.pick
addon:SetEditingEnvironment("OPEN_WORLD")
stalePick()
Equal(environments.OPEN_WORLD.cure.manual["spell:4987"], nil, "stale menu cannot write the next editing pack")
addon:SetEditingEnvironment("DUNGEON")
ns.RefreshOptions()
local oldProfilePick = Open("Right click").Cleanse.pick
local savedDungeon = environments.DUNGEON
environments.DUNGEON = ns.MakePack("DUNGEON")
oldProfilePick()
Equal(environments.DUNGEON.cure.manual["spell:4987"], nil, "stale menu cannot write a replacement profile pack")
environments.DUNGEON = savedDungeon
ns.RefreshOptions()

-- Reopen with saved settings and handle unavailable spells without data loss.
ui.frame:Hide()
assert(ns.ShowOptions())
Equal(Binding("Left click").widget:GetText(), "Remove Curse", "reopening preserves assignment display")
local savedActions = dungeonActions
dungeonActions = {}
ns.InvalidateDetection()
ns.RefreshOptions()
Equal(Binding("Left click").widget:GetText(), "Unavailable (spell:475)", "missing capabilities are explicitly labeled")
Equal(savedDungeon.cure.manual["spell:475"], "left", "unavailable spell remains saved")
Check(Open("Left click")["No known cure spells"], "empty capability menu explains why no spells appear")
dungeonActions = savedActions
ns.InvalidateDetection()
ns.RefreshOptions()
Equal(Binding("Left click").widget:GetText(), "Remove Curse", "returning capability restores spell label")

local middle = Open("Middle click")
Check(middle["Target (fixed)"] and not middle["Remove Curse"], "middle binding is explicitly fixed")
local forbidden = Open("Right click").Cleanse.pick
local savedRight = savedDungeon.mouse.right
combat = true
forbidden()
Equal(savedDungeon.mouse.right, savedRight, "combat rejects menu mutation")
Equal(savedDungeon.cure.manual["spell:4987"], nil, "combat rejects spell assignment")
combat = false
Check(refreshCount > 0, "settings reached the shared refresh path")

-- Load the extended binding model into the same live UI harness. Existing
-- saved manual assignments above remain the defaults until explicitly changed.
assert(loadfile("ZDecursive/ClickBindings.lua"))("ZDecursive", ns)
local keyboardConflicts = {}
local keyboardOverrides = {}
local keyboardWrites = 0
GetBindingAction = function(key) return keyboardConflicts[key] or "" end
SetOverrideBindingClick = function(_, _, key, name)
  Check(not combat, "keyboard override mutation during combat")
  keyboardWrites = keyboardWrites + 1
  keyboardOverrides[key] = name
end
ClearOverrideBindings = function()
  Check(not combat, "keyboard override clearing during combat")
  keyboardWrites = keyboardWrites + 1
  keyboardOverrides = {}
end
assert(loadfile("ZDecursive/KeyboardBindings.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Options.lua"))("ZDecursive", ns)
assert(ns.ShowOptions())
ui = Upvalue(ns.ShowOptions, "ui")
addon:SetEditingEnvironment("DUNGEON")
environmentStatus.appliedEnvironment = "DUNGEON"
ui.tabs.cure.scripts.OnClick()
ns.RefreshOptions()
Pick("Click mode", "AUTO - priority bindings")
Check(Row("Left click"):IsShown(), "extended binding editor is reachable in AUTO Simple mode")
Check(Row("Keyboard mouseover casting"):IsShown(), "keyboard controls are reachable in Simple mode")
Pick("Mouse modifier", "Ctrl+Shift")
Pick("Button 4", "Cleanse")
Equal(savedDungeon.cure.clickBindings["ctrl-shift-button4"], "spell:4987", "combination persists in the editing pack")
Check(MacroIncludes("ctrl-shift-macrotext4", "Cleanse"), "modifier menu updates the real secure attributes")
Equal(savedDungeon.cure.manual["spell:475"], "left", "extended settings preserve old manual choices")
Pick("Mouse modifier", "None")
Pick("Middle click", "Remove Curse")
Check(MacroIncludes("*macrotext3", "Remove Curse"), "middle is now assignable to a cure")
Pick("Mouse modifier", "Ctrl")
Pick("Middle click", "Assist")
Equal(secureButton.attributes["ctrl-type3"], "assist", "Ctrl+Middle can be reassigned")
Pick("Mouse modifier", "Alt")
Pick("Left click", "No action")
Equal(secureButton.attributes["alt-type1"], "", "No action explicitly blocks fallback")
local staleModifierPick = Open("Right click").Cleanse.pick
Pick("Mouse modifier", "Shift")
staleModifierPick()
Equal(savedDungeon.cure.clickBindings["shift-right"], nil, "stale menu cannot write a different modifier")
Pick("Mouse modifier", "Ctrl+Shift")
Pick("Button 4", "Default (AUTO / MANUAL)")
Equal(secureButton.attributes["ctrl-shift-type4"], nil, "Default clears the explicit modifier action")
Pick("Mouse modifier", "None")
Pick("Middle click", "Default (AUTO / MANUAL)")
Equal(secureButton.attributes["*type3"], "target", "Default restores the original middle target")
local combatPick = Open("Middle click").Cleanse.pick
combat = true
combatPick()
Equal(savedDungeon.cure.clickBindings.middle, nil, "extended menu rejects combat-time mutation")
combat = false

-- Use the real keyboard normalizer and status producer through the rendered
-- widgets, including the Save callback, without manually refreshing labels.
local function OpenKeyboardModal()
  local widget = Binding("Keyboard key").widget
  widget.scripts.OnClick(widget)
  Check(ui.modal:IsShown(), "keyboard key opens its input modal")
  return ui.modal.onAccept
end
local function SaveKeyboardKey(text)
  OpenKeyboardModal()
  ui.modal.edit:SetText(text)
  ui.modal.ok.scripts.OnClick(ui.modal.ok)
end
local function SetKeyboardToggle(label, value)
  local widget = Binding(label).widget
  widget:OnValueChanged(value)
end
local function KeyboardReadout()
  return Binding("Active keyboard binding").widget:GetText()
end
SaveKeyboardKey("  f8  ")
Equal(savedDungeon.cure.keyboardKey, "F8", "accepted key is normalized and saved")
Equal(Binding("Keyboard key").widget:GetText(), "F8", "accepted key label refreshes immediately")
Check(KeyboardReadout():find("off", 1, true), "accepted disabled key keeps an accurate status")
SetKeyboardToggle("Keyboard mouseover casting", true)
Equal(savedDungeon.cure.keyboardEnabled, true, "keyboard enable toggle saves")
Equal(Binding("Keyboard mouseover casting").widget._on, true, "enable toggle refreshes its state")
Equal(ns.GetKeyboardBindingStatus().state, "active", "enable installs keyboard casting")
Check(KeyboardReadout():find("F8: Remove Curse", 1, true), "enable immediately shows first active cure")
Check(KeyboardReadout():find("CTRL-F8: Cleanse", 1, true), "enable immediately shows modifier cure")
Check(keyboardOverrides.F8 and keyboardOverrides["CTRL-F8"], "real keyboard refresh installs expected keys")

local activeKeyWrites = keyboardWrites
SaveKeyboardKey("CTRL-F9")
Equal(savedDungeon.cure.keyboardKey, "F8", "invalid key cannot replace saved key")
Equal(Binding("Keyboard key").widget:GetText(), "F8", "invalid input retains displayed accepted key")
Check(KeyboardReadout():find("without Ctrl", 1, true), "invalid input immediately displays normalization guidance")
Equal(keyboardWrites, activeKeyWrites, "invalid input does not touch active bindings")
SaveKeyboardKey("F9")
Equal(Binding("Keyboard key").widget:GetText(), "F9", "correcting input immediately updates label")
Check(KeyboardReadout():find("F9: Remove Curse", 1, true), "accepted input clears prior validation error")

keyboardConflicts.F10 = "ACTIONBUTTON1"
SaveKeyboardKey("F10")
Equal(ns.GetKeyboardBindingStatus().state, "conflict", "existing key is protected by default")
Check(KeyboardReadout():find("ACTIONBUTTON1", 1, true), "conflict is immediately visible")
SetKeyboardToggle("Override existing key bindings", true)
Equal(savedDungeon.cure.keyboardOverride, true, "override toggle saves")
Equal(Binding("Override existing key bindings").widget._on, true, "override toggle refreshes its state")
Equal(ns.GetKeyboardBindingStatus().state, "active", "explicit override resolves key conflict")
Check(KeyboardReadout():find("F10: Remove Curse", 1, true), "override immediately updates status")
SetKeyboardToggle("Override existing key bindings", false)
Equal(ns.GetKeyboardBindingStatus().state, "conflict", "disabling override respects underlying key again")
Check(KeyboardReadout():find("Key already bound", 1, true), "turning override off refreshes conflict status")

SaveKeyboardKey("   ")
Equal(savedDungeon.cure.keyboardKey, "", "empty key clears stored assignment")
Equal(Binding("Keyboard key").widget:GetText(), "empty", "empty key label refreshes immediately")
Equal(ns.GetKeyboardBindingStatus().state, "unconfigured", "enabled empty key has no active binding")
Check(KeyboardReadout():find("Choose a keyboard key", 1, true), "clearing key immediately explains configuration state")
Equal(next(keyboardOverrides), nil, "clearing key restores underlying bindings")
SetKeyboardToggle("Keyboard mouseover casting", false)
Equal(Binding("Keyboard mouseover casting").widget._on, false, "disable toggle refreshes its state")
Check(KeyboardReadout():find("off", 1, true), "disable immediately shows off status")

SaveKeyboardKey("F8")
local staleKeyEnvironment = OpenKeyboardModal()
local worldKeyBefore = environments.OPEN_WORLD.cure.keyboardKey
addon:SetEditingEnvironment("OPEN_WORLD")
staleKeyEnvironment("F11")
Equal(environments.OPEN_WORLD.cure.keyboardKey, worldKeyBefore, "stale modal cannot edit the next environment")
Equal(savedDungeon.cure.keyboardKey, "F8", "stale modal also leaves its original environment unchanged")
addon:SetEditingEnvironment("DUNGEON")
ns.RefreshOptions()
local staleKeyProfile = OpenKeyboardModal()
local replacementDungeon = ns.MakePack("DUNGEON")
environments.DUNGEON = replacementDungeon
staleKeyProfile("F12")
Equal(replacementDungeon.cure.keyboardKey, "", "stale modal cannot edit a replacement profile pack")
Equal(savedDungeon.cure.keyboardKey, "F8", "replaced profile retains its saved key")
environments.DUNGEON = savedDungeon
ns.RefreshOptions()

local forbiddenKeyboardAccept = OpenKeyboardModal()
local writesBeforeCombat = keyboardWrites
local refreshesBeforeCombat = refreshCount
combat = true
forbiddenKeyboardAccept("F11")
Binding("Keyboard key").set("F12") -- The setter itself must also reject combat.
SetKeyboardToggle("Keyboard mouseover casting", true)
SetKeyboardToggle("Override existing key bindings", true)
Equal(savedDungeon.cure.keyboardKey, "F8", "combat blocks modal and direct key changes")
Equal(savedDungeon.cure.keyboardEnabled, false, "combat blocks enable toggle mutation")
Equal(savedDungeon.cure.keyboardOverride, false, "combat blocks override toggle mutation")
Equal(keyboardWrites, writesBeforeCombat, "combat callbacks never modify secure key bindings")
Equal(refreshCount, refreshesBeforeCombat, "rejected combat edits do not dispatch reconfiguration")
combat = false
io.write("manual-click-options-contract: ok\n")
