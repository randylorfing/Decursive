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

assert(loadfile("ZDecursive/Options.lua"))("ZDecursive", ns)
combat = true
local regionsBeforeBlockedOpen = #regions
local ok, state = ns.ShowOptions()
Check(not ok and state == "combat", "combat blocks direct Options opening")
Check(#regions == regionsBeforeBlockedOpen, "combat open creates zero Options regions")
Check(ns.optionsDiagnosticProvider().frameCreated == false, "combat open leaves the Options frame unconstructed")
Check(combatMessages[1] == "ZDecursive Options cannot be opened during combat.", "combat notice text is exact")
ns.ShowOptions()
Check(#combatMessages == 1, "repeated combat entry is notice-throttled")
clock = clock + 2.1
ok, state = ns.ToggleOptions()
Check(not ok and state == "combat", "combat blocks internal Options toggle")
Check(#combatMessages == 2, "combat notice becomes available after the throttle window")
Check(diagnosticEvents[1].kind == "options_open_blocked", "blocked open records persistent diagnostic event")

combat = false
ok, state = ns.ShowOptions()
Check(ok and state == "shown", "out-of-combat Options opening succeeds")
Check(ns.IsOptionsShown(), "custom Options frame opens")
AssertPlainEnvironmentLabels("initial Open World context")
Check(HasText("Applied: Open World"), "initial applied environment text is accurate")
Check(HasText("Editing: Open World"), "initial editing environment text is accurate")
Check(HasText("Detected: Open World"), "initial detected environment text is accurate")
Check(HasTextContaining("Mode: Multiple"), "initial environment mode is visible on Status")

local contexts = {
  {key = "OPEN_WORLD", label = "Open World"},
  {key = "DUNGEON", label = "Dungeon"},
  {key = "MYTHIC_PLUS", label = "Mythic+"},
  {key = "RAID", label = "Raid"},
  {key = "PVP", label = "PvP"},
}
for i = 1, #contexts do
  local editing = contexts[(i % #contexts) + 1]
  environmentStatus.appliedEnvironment = contexts[i].key
  environmentStatus.detectedEnvironment = contexts[i].key
  environmentStatus.pendingEnvironment = nil
  addon.db.char.editingEnvironment = editing.key
  ns.RefreshOptions()
  AssertPlainEnvironmentLabels(contexts[i].label .. " applied context")
  Check(HasText("Applied: " .. contexts[i].label), contexts[i].label .. " applied text is accurate")
  Check(HasText("Detected: " .. contexts[i].label), contexts[i].label .. " detected text is accurate")
  Check(HasText("Editing: " .. editing.label), contexts[i].label .. " keeps editing separate")
end

environmentStatus.appliedEnvironment = "DUNGEON"
environmentStatus.detectedEnvironment = "RAID"
environmentStatus.environmentMode = "multiple"
environmentStatus.pendingEnvironment = "RAID"
addon.db.char.editingEnvironment = "PVP"
ns.RefreshOptions()
AssertPlainEnvironmentLabels("combat-pending context")
Check(HasText("Applied: Dungeon"), "pending state does not claim the target is applied")
Check(HasText("Editing: PvP"), "pending state preserves the independent editor")
Check(HasText("Pending after combat: Raid"), "pending environment remains explicit")
Check(HasTextContaining("Mode: Multiple"), "Multiple mode remains explicit")
Check(HasTextContaining("Detected Environment: Raid"), "detected environment remains separate")
local snapshot = ns.optionsDiagnosticProvider()
Check(snapshot.defaultDestination == "STATUS", "Status is the runtime default destination")
Check(snapshot.currentDestination == "STATUS", "Options initially opens Status")
Check(snapshot.environmentSubmenuCount == 6, "six environment submenu entries")
Check(snapshot.multipleEnvironmentCount == 5, "Multiple mode has five environment packs")
Check(snapshot.soloEnvironmentCount == 1, "Solo mode has one environment pack")
Check(snapshot.addonProfilesSeparate, "Addon Profiles is a separate destination")
Check(snapshot.quickBindingCount == 6, "six safe quick binding actions")
Check(snapshot.shortcutOnlyCount == 1, "full Cure settings remains shortcut-only")
Check(snapshot.combatReadOnly == false, "out-of-combat dashboard is writable")
combat = true
Check(ns.CloseOptionsForCombat("PLAYER_REGEN_DISABLED"), "combat entry closes an already-open Options frame")
Check(not ns.IsOptionsShown(), "combat entry leaves Options hidden")
Check(not ns.RefreshOptions(), "combat-time external refresh is a no-op")
snapshot = ns.optionsDiagnosticProvider()
Check(snapshot.combatReadOnly == true, "hidden diagnostic state reports combat lockout")
Check(diagnosticEvents[#diagnosticEvents].kind == "options_closed_for_combat", "combat close records persistent diagnostic event")
combat = false
Check(not ns.IsOptionsShown(), "combat exit does not automatically reopen Options")
ok, state = ns.ToggleOptions()
Check(ok and state == "shown" and ns.IsOptionsShown(), "explicit post-combat toggle opens Options")
ok, state = ns.ToggleOptions()
Check(ok and state == "hidden" and not ns.IsOptionsShown(), "out-of-combat toggle hides Options")

io.write("options-runtime-init-contract: ok\n")
