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

local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a")
file:close()

for _, token in ipairs({
  'assign = "Decursive Profiles"',
  'MakeButton(navigation, "Decursive Profiles", 182)',
  'MakeCard(assignChild, "Decursive Profiles and assignments")',
  '"Decursive Profile: "',
  'Font(navigation, "GameFontNormalSmall", "ENVIRONMENT SETTINGS")',
  'MakeButton(envBar, "Editing: Open World"',
  'MakeButton(envBar, "Mode: Multiple"',
  'mufs = "Frames"',
  'sorting = "Roster"',
  'cure = "Actions"',
  'color = "Colors"',
  'items = "Supplies"',
}) do
  Check(source:find(token, 1, true), "missing visible label/layout contract: " .. token)
end

for _, stale in ipairs({
  '"Addon Profiles"',
  '"ADDON PROFILES"',
  '"Addon Profile: "',
  '"ROUTING"',
}) do
  Check(not source:find(stale, 1, true), "stale user-facing label remains: " .. stale)
end

-- Internal destination and AceDB identifiers deliberately remain unchanged.
Check(source:find('destination == "addon_profiles"', 1, true), "internal profile destination remains stable")

io.write("options-visible-labels-contract: ok\n")
