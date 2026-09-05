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

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text:gsub("\r\n", "\n")
end

local core = Read("ZDecursive/Core.lua")
local options = Read("ZDecursive/Options.lua")
local diagnostics = Read("ZDecursive/Diagnostics.lua")

for _, token in ipairs({
  "function Decursive:GetUIProfileStatus()",
  "status.actualProfile = current",
  "status.resolvedProfile = resolved",
  "status.resolvedTier = tier",
  "status.pendingProfile = resolved",
  "profileGeneration = self.profileChangeGeneration or 0",
}) do
  Check(core:find(token, 1, true), "missing UI status contract: " .. token)
end

for _, token in ipairs({
  "function Decursive:GetEnvironmentProfileStatus()",
  "function Decursive:GetAppliedEnvironmentPack()",
  "function Decursive:ApplyResolvedEnvironment(_reason, isRetry)",
  "appliedEnvironment = applied",
  "resolvedEnvironment = resolved",
  "detectedEnvironment = detected",
  "environmentMode = environmentMode",
  "pendingEnvironment = pendingEnvironment",
  "editingEnvironment = editing",
  "return false, \"combat\"",
}) do
  Check(core:find(token, 1, true), "missing environment status contract: " .. token)
end

for _, token in ipairs({
  'assign = "Decursive Profiles"',
  '"Active profile: " .. profile',
  '"Pending after combat: "',
  '"Resolved source: "',
  "local actual = status and status.available and status.actualProfile or nil",
  "return selected == name",
  "if getCurrent then selected = getCurrent() end",
  'f:SetScript("OnShow"',
  '"Applied: " .. appliedLabel',
  '"Editing: " .. editingLabel',
  '"Detected: " .. detectedLabel',
  '"Mode: " .. (environmentMode == "solo" and "Solo" or "Multiple")',
  '"Detected Environment: "',
  '"Pending after combat: " .. (ns.ENV_LABELS[pendingEnvironment]',
  'root:CreateRadio(row.label, function() return Addon():GetEditingEnvironment() == row.key end',
}) do
  Check(options:find(token, 1, true), "missing Options visibility contract: " .. token)
end

Check(not diagnostics:find("actualProfile", 1, true), "diagnostics must not expose profile names")
Check(not diagnostics:find("pendingProfile", 1, true), "diagnostics must not expose pending profile names")
Check(not options:find("Active Profile on login", 1, true), "stale resolved-as-active label removed")
Check(options:find('label = "Maximum displayed MUFs"', 1, true), "display cap has an unambiguous UI label")
Check(options:find('label = "Out of range", description = "Underlying RGB color for unafflicted out-of-range squares. Out-of-range brightness dims the whole MUF once, including affliction colors, icons and countdown numbers.", kind = "color", hasOpacity = false', 1, true), "range picker is explicitly RGB-only")
Check(options:find('["color|Out of range"] = {group = "Squares", simple = true}', 1, true), "Colors catalog retains the range picker")
Check(options:find("widget = MakeColorSwatch(row, spec.hasOpacity)", 1, true), "color rows propagate opacity policy")
Check(options:find("hasOpacity = alphaEnabled", 1, true), "picker opacity mode is data-driven")
Check(options:find("local function Pack()\n  return Addon():GetEditingPack()", 1, true), "Options edits the selected editing environment")
Check(options:find("Caps non-pet MUF members after sorting.", 1, true), "display cap explains member-only post-sort semantics")
Check(options:find("Enabled pets are additional and follow their displayed owners", 1, true), "display cap explains additional owner-pet semantics")
Check(options:find("detection is not limited.", 1, true), "display cap explains detection remains complete")
Check(not options:find(utf8 and utf8.char and utf8.char(0x2713) or "\226\156\147", 1, true), "Options runtime must not use a raw Unicode check glyph")
Check(not options:find("APPLIED_ENVIRONMENT_ICON", 1, true), "top environment chips must not have an applied marker")
Check(not options:find("UI-CheckBox-Check", 1, true), "top environment chips must not use an inline checkbox texture")
Check(options:find('ui.environmentEditing:SetText("Editing: " .. editingLabel)', 1, true), "editing selector remains independent from the applied status")
Check(options:find('ui.environmentEditing:SetScript("OnClick", function(self)', 1, true), "editing dropdown retains a click handler")
Check(options:find('SetDestination("environment", row.key)', 1, true), "dropdown choices select only the editing environment")
Check(options:find('label = "Multiple - follow content"', 1, true), "mode menu exposes Multiple behavior")
Check(options:find('label = "Solo - use one settings pack"', 1, true), "mode menu explains Solo behavior")
Check(not options:find("OpenStaticEnvironmentMenu", 1, true), "Environment Profiles removes the obsolete static selector")
Check(options:find("simpleModeAvailable = false", 1, true), "all controls remain available without a Simple filter")
Check(options:find('row.searchSpec = spec', 1, true), "search navigation remains environment-aware")
Check(options:find('ui.statusPage:SetShown(destination == "status")', 1, true), "Status destination remains independent")
Check(options:find('ui.profileBar:SetShown(destination == "addon_profiles")', 1, true), "Decursive Profiles destination remains independent")
Check(core:find('self.pendingEnvironment = resolved', 1, true), "combat transition retains a pending environment")
Check(core:find('if ns.RefreshOptions then', 1, true), "environment transitions refresh the selected editor and pending state")

io.write("options-profile-status-contract: ok\n")
