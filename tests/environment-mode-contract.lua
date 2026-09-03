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
  return text
end

local defaults = Read("ZDecursive/Defaults.lua")
local core = Read("ZDecursive/Core.lua")
local options = Read("ZDecursive/Options.lua")

for _, token in ipairs({
  "ns.MULTIPLE_ENVIRONMENTS = {",
  'ns.ENVIRONMENTS[#ns.ENVIRONMENTS + 1] = {key = "SOLO", label = "Solo"}',
  "ns.MULTIPLE_ENV_SET[row.key] = true",
  "ns.ENVIRONMENT_MODE_SCHEMA = 1",
  'routingMode = "multiple"',
  "environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA",
  'multipleEditingEnvironment = "OPEN_WORLD"',
}) do
  Check(defaults:find(token, 1, true), "missing six-pack default contract: " .. token)
end

for _, token in ipairs({
  "function Decursive:GetEnvironmentMode()",
  'local resolved = mode == "solo" and "SOLO" or detected',
  "function Decursive:SetEnvironmentMode(mode)",
  "function Decursive:MigrateEnvironmentMode(environments)",
  'legacyMode == "static"',
  "environments.SOLO = ns.DeepCopy(environments[legacyStatic])",
  "profile.environmentModeSchema = targetSchema",
  "function Decursive:NormalizeEditingEnvironment(mode)",
  'char.editingEnvironment = "SOLO"',
  "char.multipleEditingEnvironment = multipleEditing",
  'return self:RunProfileStorageTransaction("environment-mode"',
  'if LockedDown() then',
  'return false, "combat"',
}) do
  Check(core:find(token, 1, true), "missing environment mode runtime contract: " .. token)
end

local classifierStart = assert(core:find("local function ReadEnvironmentContext()", 1, true))
local classifierEnd = assert(core:find("local function ReplaceTable", classifierStart, true))
local classifier = core:sub(classifierStart, classifierEnd - 1)
Check(not classifier:find('"SOLO"', 1, true), "context classifier must never return Solo")

for _, token in ipairs({
  'Addon():SetEnvironmentMode("multiple")',
  'Addon():SetEnvironmentMode("solo")',
  'ui.envCopyBtn:SetShown(environmentMode == "multiple")',
  'environmentMode == "solo" and key == "SOLO"',
  'environmentMode == "multiple" and ns.MULTIPLE_ENV_SET[key] == true',
}) do
  Check(options:find(token, 1, true), "missing environment mode UI contract: " .. token)
end
Check(not options:find("OpenStaticEnvironmentMenu", 1, true), "obsolete static selector must remain absent")
Check(not options:find("SetStaticEnvironment", 1, true), "obsolete static setter must remain absent")

io.write("environment-mode-contract: ok\n")
