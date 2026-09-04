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

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local function Check(value, message)
  if not value then
    error(message, 2)
  end
end

local options = Read("ZDecursive/Options.lua")
local mufs = Read("ZDecursive/MUFs.lua")
local detection = Read("ZDecursive/Detection.lua")
local core = Read("ZDecursive/Core.lua")

local required = {
  'destination = "status"',
  'local OPTIONS_DEFAULT_DESTINATION = "STATUS"',
  'local ENVIRONMENT_SUBMENU_ORDER = {"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP", "SOLO"}',
  'MakeButton(navigation, "Status"',
  '"ENVIRONMENT PROFILES"',
  'MakeButton(navigation, "Decursive Profiles"',
  'MakeButton(navigation, "Diagnostics"',
  'MakeButton(card, "Run Health Check"',
  'OptionsAccessAllowed("DIAGNOSTICS_HEALTH")',
  'SetDestination("environment", environment)',
  'local current = MakeCard(child, "Current setup")',
  'local capability = MakeCard(child, "Dispel capability")',
  'local mappings = MakeCard(child, "Click mappings")',
  'local quick = MakeCard(child, "Quick bindings")',
  'local appliedPack = addon and addon.GetAppliedEnvironmentPack and addon:GetAppliedEnvironmentPack() or nil',
  'local actions = ns.GetKnownCures and ns.GetKnownCures(appliedPack) or nil',
  'local clickStatus = ns.GetResolvedClickStatus and ns.GetResolvedClickStatus() or nil',
  'if OptionsCombatReadOnly() then',
  'SetClickMode("AUTO")',
  'SetClickMode("MANUAL")',
  'run = SetMouseAction("left")',
  'run = SetMouseAction("right")',
  'run = SetMouseAction("button4")',
  'run = SetMouseAction("button5")',
  'SetDestination("environment")',
  'currentDestination = tostring(ui.destination or "status"):upper()',
  'statusPanels = {"CURRENT_SETUP", "DISPEL_CAPABILITY", "CLICK_MAPPINGS", "QUICK_BINDINGS"}',
}
for i = 1, #required do
  Check(options:find(required[i], 1, true), "missing options architecture contract: " .. required[i])
end

Check(options:find('assign = "Decursive Profiles"', 1, true), "Decursive Profiles terminology is distinct")
Check(options:find('row.searchSpec = spec', 1, true), "search results retain their environment destination")
Check(options:find('ui.tab = spec.page', 1, true), "search results open the matching full settings page")
Check(options:find('ui.profileBar:SetShown(destination == "addon_profiles")', 1, true), "profile lifecycle is isolated to Decursive Profiles")
Check(options:find('ui.envBar:SetShown(destination == "environment")', 1, true), "environment editor chrome is isolated")
Check(options:find('ui.statusPage:SetShown(destination == "status")', 1, true), "Status is a dedicated destination")
Check(options:find('ui.diagnosticsPage:SetShown(destination == "diagnostics")', 1, true), "persistent Diagnostics is a dedicated destination")
Check(options:find('"Start verbose"', 1, true) and options:find('"Monitor snapshot"', 1, true) and options:find('"Copy/export"', 1, true), "Diagnostics page exposes bounded monitor controls")
Check(options:find('ns.Diagnostics.RunHealthCheck(true)', 1, true), "Diagnostics page opens the evaluated report in the copyable window")
Check(options:find("WoW does not flush SavedVariables to disk continuously", 1, true), "Diagnostics page explains reload flush workflow")
Check(not options:find('SetScript("OnUpdate"', 1, true), "Options must not poll OnUpdate")
Check(not options:find("UNIT_AURA", 1, true), "Options must not duplicate aura discovery")
Check(not options:find("COMBAT_LOG", 1, true), "Options must not parse combat log")
local asciiOnly = true
for i = 1, #options do
  if options:byte(i) > 127 then
    asciiOnly = false
    break
  end
end
Check(asciiOnly, "Options labels must remain ASCII")

Check(mufs:find("function ns.GetResolvedClickStatus()", 1, true), "MUFs exposes authoritative resolved click status")
Check(mufs:find('binding = TARGET_GESTURE, secureType = "target"', 1, true), "default target mapping participates in the configurable model")
Check(mufs:find('binding = FOCUS_GESTURE, secureType = "focus"', 1, true), "default focus mapping participates in the configurable model")
Check(detection:find("if ns.RefreshOptions then\n        ns.RefreshOptions()", 1, true), "existing talent event path refreshes Status")
Check(not detection:find('RegisterEvent("UNIT_AURA")', 1, true), "no Lua aura discovery event introduced")
Check(core:find('self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatOptionsChanged")', 1, true), "combat entry refreshes Status read-only state")
Check(core:find("function Decursive:OnCombatOptionsChanged()", 1, true), "combat Status callback exists")

io.write("options-architecture-contract: ok\n")
