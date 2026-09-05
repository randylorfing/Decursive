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

local checks = 0
local function Check(value, message)
  checks = checks + 1
  if not value then error(message, 2) end
end

local function Harness()
  local h = {combat = false, marker = "Zhaohu-Decursive", loading = true, loaded = true,
    metadataCalls = 0, loadedCalls = 0, displayCalls = 0, messages = {}, events = {}}
  h.secret = setmetatable({}, {__eq = function() error("secret comparison") end,
    __tostring = function() error("secret serialization") end})
  issecretvalue = function(value) return rawequal(value, h.secret) end
  canaccessvalue = function(value) return not rawequal(value, h.secret) end
  InCombatLockdown = function() return h.combat end
  C_Timer = {After = function() error("upgrade notice must not create a timer") end}
  local function Forbidden() error("upgrade notice must not load, disable or modify addons") end
  C_AddOns = {
    GetAddOnMetadata = function(name, key)
      Check(name == "Decursive" and key == "X-Zhaohu-Build", "lookup uses only the exact old folder and project marker")
      h.metadataCalls = h.metadataCalls + 1
      if h.metadataThrows then error("metadata unavailable") end
      return h.marker
    end,
    IsAddOnLoaded = function(name)
      Check(name == "Decursive", "only the old main addon is queried; options need not be loaded")
      h.loadedCalls = h.loadedCalls + 1
      if h.loadedThrows then error("loaded state unavailable") end
      return h.loading, h.loaded
    end,
    LoadAddOn = Forbidden, DisableAddOn = Forbidden, EnableAddOn = Forbidden,
  }
  DecursiveDB = {profiles = {legacy = {value = "keep"}}}
  DecursiveRebuildDB = {profiles = {current = {value = "keep"}}}
  h.oldDB, h.newDB = DecursiveDB, DecursiveRebuildDB
  local addon = {db = {profile = {unchanged = true}}}
  local function Noop() end
  function addon:RegisterEvent(event, method) h.events[event] = method end
  function addon:Print() error("notice must use copyable diagnostics, not chat") end
  LibStub = function(name)
    if name == "AceAddon-3.0" then return {NewAddon = function() return addon end} end
    if name == "AceDB-3.0" then return {} end
    error("unexpected library")
  end
  local ns = {Diagnostics = {State = {}}, DiagnosticCheckpoint = Noop, DiagnosticModuleEnabled = Noop}
  h.show = function(message)
    Check(not h.combat, "notice never opens during combat")
    h.displayCalls = h.displayCalls + 1
    if h.displayThrows then error("window unavailable") end
    if h.reenter then addon:CheckLegacyUpgradeWarning() end
    if h.displayRejects then return false end
    h.messages[#h.messages + 1] = message
    return true
  end
  ns.Diagnostics.ShowText = h.show
  assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)
  -- Exercise real lifecycle methods while isolating unrelated profile and
  -- roster transactions, which have their own comprehensive contracts.
  addon.EnsureSpecAssignments = Noop
  addon.ApplyResolvedProfile = Noop
  addon.CommitRosterIdentity = Noop
  addon.ApplyResolvedEnvironment = Noop
  addon.EnsureEnvironments = Noop
  h.addon, h.ns = addon, ns
  function h:World()
    addon.worldEntryRecoveryPending, addon.fullWorldRecoveryPending = false, false
    return addon:OnEnteringWorld()
  end
  function h:Regen()
    addon.worldEntryRecoveryPending, addon.fullWorldRecoveryPending = false, false
    return addon:OnRegenEnabled()
  end
  function h:CheckData()
    Check(DecursiveDB == self.oldDB and DecursiveDB.profiles.legacy.value == "keep", "legacy SavedVariables remain untouched")
    Check(DecursiveRebuildDB == self.newDB and DecursiveRebuildDB.profiles.current.value == "keep", "new SavedVariables remain untouched")
    Check(addon.db.profile.unchanged == true and next(addon.db.profile, "unchanged") == nil, "notice adds no profile setting")
  end
  return h
end

do
  local h = Harness()
  h.addon:OnEnable()
  Check(h.displayCalls == 1 and #h.messages == 1, "successful addon startup shows the exact legacy coexistence notice")
  Check(h.events.PLAYER_REGEN_ENABLED == "OnRegenEnabled" and h.events.PLAYER_ENTERING_WORLD == "OnEnteringWorld", "notice uses existing lifecycle events")
  local message = h.messages[1]
  for _, text in ipairs({"Exit World of Warcraft completely", "Decursive and Decursive_Options folders",
    "Keep the ZDecursive folder", "Keep your WTF folder", "SavedVariables backups", "Old DecursiveDB profiles are not imported"}) do
    Check(message:find(text, 1, true), "notice explains migration action: " .. text)
  end
  local reads = h.metadataCalls + h.loadedCalls
  h.addon:OnEnable()
  h:World()
  h:Regen()
  h.addon:CheckLegacyUpgradeWarning()
  Check(h.displayCalls == 1 and h.metadataCalls + h.loadedCalls == reads, "once displayed, repeated lifecycle events do no extra lookups or notices")
  h:CheckData()
end

for _, marker in ipairs({false, "", "Decursive", "Zhaohu-Decursive-other", "zhaohu-decursive"}) do
  local h = Harness()
  h.marker = marker
  h.addon:OnEnable()
  h:World()
  Check(h.displayCalls == 0 and h.loadedCalls == 0, "upstream or unrelated metadata never triggers or queries loading state")
end

do
  local h = Harness()
  h.marker = nil
  Check(not h.addon:CheckLegacyUpgradeWarning() and h.displayCalls == 0, "absent old project is silent")
  h.marker = h.secret
  Check(not h.addon:CheckLegacyUpgradeWarning() and h.displayCalls == 0, "inaccessible metadata is ignored without inspecting it")
end

for _, state in ipairs({{false, false}, {true, false}, {true}, {true, "true"}}) do
  local h = Harness()
  h.loading, h.loaded = state[1], state[2]
  h.addon:OnEnable()
  h:World()
  Check(h.displayCalls == 0, "disabled, unloaded, still-loading or malformed results never warn")
end

do
  local h = Harness()
  h.loaded = h.secret
  Check(not h.addon:CheckLegacyUpgradeWarning(), "inaccessible loaded result is ignored")
  h.loaded = false
  h.addon:OnEnable()
  h.loaded = true
  h:World()
  Check(h.displayCalls == 1, "world entry catches a legacy build that finished loading after startup")
end

for _, missing in ipairs({"namespace", "GetAddOnMetadata", "IsAddOnLoaded"}) do
  local h = Harness()
  if missing == "namespace" then C_AddOns = nil else C_AddOns[missing] = nil end
  Check(not h.addon:CheckLegacyUpgradeWarning() and h.displayCalls == 0, "missing addon API fails safely: " .. missing)
end

for _, failure in ipairs({"metadataThrows", "loadedThrows"}) do
  local h = Harness()
  h[failure] = true
  Check(not h.addon:CheckLegacyUpgradeWarning() and h.displayCalls == 0, "throwing addon API cannot break startup: " .. failure)
end

do
  local h = Harness()
  h.combat = true
  h.addon:OnEnable()
  h:Regen()
  Check(h.displayCalls == 0, "combat retains the pending notice even if a recovery callback occurs early")
  h.combat = false
  h:Regen()
  h:Regen()
  Check(h.displayCalls == 1, "existing combat-exit recovery shows a deferred notice exactly once")
  h:CheckData()
end

do
  local h = Harness()
  h.combat = true
  h.addon:OnEnable()
  h.combat = false
  h:World()
  Check(h.displayCalls == 1, "world entry recovers combat deferral when no regen event arrives")
end

do
  local h = Harness()
  h.combat = true
  h.addon:OnEnable()
  h.combat, h.loaded = false, false
  h:Regen()
  local reads = h.metadataCalls + h.loadedCalls
  h:Regen()
  Check(h.displayCalls == 0 and h.metadataCalls + h.loadedCalls == reads, "no-longer-loaded legacy build clears pending recovery")
end

for _, failure in ipairs({"noDiagnostics", "noShowText", "displayThrows", "displayRejects"}) do
  local h = Harness()
  if failure == "noDiagnostics" then
    h.ns.Diagnostics = nil
  elseif failure == "noShowText" then
    h.ns.Diagnostics.ShowText = nil
  else
    h[failure] = true
  end
  Check(not h.addon:CheckLegacyUpgradeWarning(), "unavailable diagnostics remains recoverable: " .. failure)
  Check(#h.messages == 0, "failed presentation does not claim the notice was shown")
  h.displayThrows, h.displayRejects = false, false
  h.ns.Diagnostics = {ShowText = h.show}
  h:Regen()
  h:Regen()
  Check(#h.messages == 1, "existing recovery displays the notice once when diagnostics becomes available")
end

do
  local h = Harness()
  h.reenter = true
  Check(h.addon:CheckLegacyUpgradeWarning() and h.displayCalls == 1, "reentrant UI callback cannot duplicate the session notice")
  h:CheckData()
end

io.write("legacy-upgrade-warning-contract: " .. checks .. " checks passed\n")
