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

-- ZDecursive test support, Copyright (C) 2026 Randy Lorfing.
-- GPL-3.0-or-later; distributed without warranty. See the repository LICENSE.
local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local CATALOG =", 1, true))
local last = assert(source:find("local function ShowModal", first, true))
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local environments = ns.MakeEnvironments()
local editing = environments.DUNGEON
local env = setmetatable({
  ns = {},
  PathGet = function(section, key) return function() return editing[section][key] end end,
  PathSet = function(section, key) return function(value) editing[section][key] = value end end,
}, {__index = function(_, key) return _G[key] or function() return function() end end end})
local catalog = assert(load(source:sub(first, last - 1) .. "\nreturn CATALOG", "Options catalog", "t", env))()
local warning, dim, brightness
for _, spec in ipairs(catalog) do
  if spec.label == "Out-of-range dispel warning" then assert(not warning); warning = spec end
  assert(spec.label ~= "Dim afflicted targets out of range", "obsolete separate afflicted control is removed")
  if spec.label == "Dim out-of-range MUFs" then assert(not dim); dim = spec end
  if spec.label == "Out-of-range brightness" then assert(not brightness); brightness = spec end
end
assert(warning and warning.kind == "toggle" and warning.page == "alerts" and warning.group == "Text Alerts",
  "warning has one reachable Alerts / Text Alerts toggle")
assert(dim and dim.kind == "toggle" and dim.page == "color" and dim.group == "Range",
  "whole-MUF dimming has one reachable Colors / Range toggle")
assert(brightness and brightness.kind == "slider" and brightness.page == "color" and brightness.group == "Range",
  "whole-MUF brightness has one reachable Colors / Range slider")
assert(warning.description:find("Text alerts", 1, true) and warning.description:find("Cure-failure sound", 1, true),
  "warning description explains visual and audio gates")
assert(dim.description:find("50%", 1, true) and dim.description:find("icons and countdown numbers", 1, true)
  and dim.description:find("Unknown range", 1, true), "dim description explains default brightness and whole-MUF scope")
assert(brightness.description:find("afflicted and unafflicted", 1, true)
  and brightness.description:find("lower values", 1, true) and brightness.description:find("Unknown range", 1, true),
  "brightness description explains both unit states, strength and unknown range")
assert(warning.get() == true and dim.get() == true, "both new controls initially enabled")
warning.set(false)
dim.set(false)
assert(editing.alerts.outOfRangeDispel == false and editing.mufs.dimOutOfRange == false,
  "active controls persist into their existing keys")
assert(editing.alerts.range == true and editing.mufs.dimAfflictedOutOfRange == true and editing.mufs.dimAmount == 0.50,
  "active controls leave obsolete saved preferences and brightness untouched")
assert(environments.OPEN_WORLD.alerts.outOfRangeDispel == true and environments.OPEN_WORLD.mufs.dimAfflictedOutOfRange == true,
  "editing an inactive environment preserves the applied pack")
editing = environments.OPEN_WORLD
assert(warning.get() and dim.get(), "controls read the newly selected editing environment")
assert(brightness.get() == 0.50, "Open World starts with whole-MUF 50% dimming")
brightness.set(0.35)
dim.set(false)
assert(environments.OPEN_WORLD.mufs.dimAmount == 0.35 and environments.OPEN_WORLD.mufs.dimOutOfRange == false,
  "explicit whole-MUF custom choices remain independently editable")
assert(environments.OPEN_WORLD.mufs.dimAfflictedOutOfRange == true and environments.DUNGEON.mufs.dimAmount == 0.50,
  "active editing does not erase obsolete saved keys or alter another environment")
print("out-of-range-options-contract: defaults, descriptions, placement and independent editing passed")
