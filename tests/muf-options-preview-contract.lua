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

local function Equal(actual, expected, message)
  if actual ~= expected then
    error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text:gsub("\r\n", "\n")
end

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Options.lua"))("ZDecursive", ns)

local environments = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  local expected = (row.key == "RAID" or row.key == "PVP") and 40 or 5
  Equal(ns.GetMUFPreviewCount(environments[row.key], row.key), expected, row.key .. " default representative count")
end
environments.DUNGEON.mufs.maxUnits = 8
environments.RAID.mufs.maxUnits = 23
Equal(ns.GetMUFPreviewCount(environments.DUNGEON, "DUNGEON"), 5, "party preview remains a compact five-unit representative strip")
environments.DUNGEON.mufs.maxUnits = 3
Equal(ns.GetMUFPreviewCount(environments.DUNGEON, "DUNGEON"), 3, "party preview respects an intentional cap below five")
Equal(ns.GetMUFPreviewCount(environments.RAID, "RAID"), 23, "raid custom capacity is represented")
Equal(ns.GetMUFPreviewCount(environments.PVP, "PVP"), 40, "PvP preview represents battleground capacity")
environments.RAID.mufs.maxUnits = 80
Equal(ns.GetMUFPreviewCount(environments.RAID, "RAID"), 40, "preview safely caps representation at forty")
for _, row in ipairs({
  {value = 1, expected = 1},
  {value = 5, expected = 40},
  {value = 10, expected = 10},
  {value = 20, expected = 20},
  {value = 40, expected = 40},
}) do
  environments.RAID.mufs.maxUnits = row.value
  Equal(ns.GetMUFPreviewCount(environments.RAID, "RAID"), row.expected, "raid count handles configured/default sentinel " .. row.value)
end

local horizontal = ns.CalculateMUFLayout(5, 20, 2, 2, false, 3, false, false, false)
Equal(horizontal.cols, 3, "horizontal layout fills rows to configured per-line")
Equal(horizontal.rows, 2, "horizontal layout creates the expected row count")
Equal(horizontal.anchor, "TOPLEFT", "horizontal downward growth uses runtime anchor")
Equal(horizontal.positions[4].x, 0, "horizontal second row restarts at first column")
Equal(horizontal.positions[4].y, -22, "horizontal second row uses runtime vertical stride")

local vertical = ns.CalculateMUFLayout(5, 20, 2, 3, true, 3, true, true, true)
Equal(vertical.cols, 2, "vertical layout fills columns to configured per-line")
Equal(vertical.rows, 3, "vertical layout creates the expected row count")
Equal(vertical.anchor, "BOTTOMRIGHT", "vertical right/up growth uses runtime anchor")
Check(vertical.positions[2].y > vertical.positions[1].y, "grow-up positions advance upward")
Check(vertical.positions[4].x < vertical.positions[1].x, "grow-from-right positions advance leftward")
Check(vertical.verticalStride > 23, "status-light reserve is included in runtime and preview stride")

local raid = ns.CalculateMUFLayout(40, 80, 100, 100, true, 40, true, false, false)
Equal(#raid.positions, 40, "raid preview calculates all forty representatives")
Equal(raid.rows, 40, "vertical forty-per-line layout is faithful")
Equal(raid.cols, 1, "vertical forty-per-line layout remains one column")

for _, viewport in ipairs({
  {320},
  {560},
  {760},
  {1200},
  {1600},
}) do
  for _, configuredScale in ipairs({0.5, 1, 1.5, 2}) do
    local geometry = ns.CalculateMUFPreviewGeometry(raid, configuredScale, viewport[1], 88, 152, 80, true)
    Check(geometry ~= nil, "preview geometry exists")
    Check(geometry.drawnWidth <= geometry.availableWidth + 0.001, "preview fits viewport width")
    Check(geometry.drawnHeight <= geometry.availableHeight + 0.001, "preview fits viewport height")
    Check(geometry.drawSize > 0, "preview retains visible positive square size")
    Check(geometry.handleDrawnHeight > 0, "visible handle is included in fitted preview bounds")
    Check(geometry.hostHeight >= 134 and geometry.hostHeight <= 198, "Raid host stays content-driven and modest")
    local nextSectionTop = -(geometry.hostHeight + 8)
    Check(nextSectionTop < -geometry.hostHeight, "next section begins below preview bounds")
  end
end

local partyGeometry = ns.CalculateMUFPreviewGeometry(horizontal, 1, 560, 64, 86, 20, false)
Check(partyGeometry.hostHeight >= 110 and partyGeometry.hostHeight <= 132, "party preview stays near the original compact height")
Check(partyGeometry.drawnWidth <= partyGeometry.availableWidth, "party strip fits a narrow viewport")

local options = Read("ZDecursive/Options.lua")
local previewStart = assert(options:find("local function RefreshPreview", 1, true))
local previewEnd = assert(options:find("ui.RefreshPreview = RefreshPreview", previewStart, true))
local preview = options:sub(previewStart, previewEnd)
Check(preview:find("addon:GetEditingPack()", 1, true), "preview reads only the editing pack")
Check(preview:find("PreviewStateColor(pack, state)", 1, true), "preview colors come from the selected editing pack")
Check(preview:find("addon:GetEditingEnvironment()", 1, true), "preview reads only the editing environment")
Check(not preview:find("GetAppliedEnvironment", 1, true), "preview never substitutes the applied runtime pack")
Check(preview:find("ns.CalculateMUFLayout", 1, true), "preview and runtime share one pure layout calculation")
Check(options:find("for i = 1, PREVIEW_MAX_UNITS do", 1, true), "preview owns forty plain representative frames")
Check(options:find("sq:EnableMouse(false)", 1, true), "preview squares are click-through")
Check(options:find("handle:EnableMouse(false)", 1, true), "preview handle is click-through")
Check(not preview:find("AuraContainer", 1, true), "preview has no native provider")
Check(not preview:find("Secure", 1, true), "preview has no secure frame behavior")
Check(options:find("TeardownMUFPreview()", 1, true), "page and environment switches tear down preview state")
Check(options:find("if MUFPreviewActive() then", 1, true), "search and non-MUF pages remove the preview host from layout")
Check(options:find('f:SetScript("OnHide", function()', 1, true), "closing Options tears down preview state")
Check(options:find("ui.previewHeight or ui.previewHost:GetHeight()", 1, true), "catalog content begins below the measured dynamic preview bounds")
Check(options:find('"Party preview " .. PREVIEW_SEPARATOR .. " %d units"', 1, true), "party caption is concise")
Check(options:find('"Raid preview " .. PREVIEW_SEPARATOR .. " %d units " .. PREVIEW_SEPARATOR .. " %d per line"', 1, true), "Raid caption includes count and units per line")
Check(options:find("PREVIEW_SEPARATOR = string.char(194, 183)", 1, true), "middle-dot caption remains ASCII-safe in source")
Check(not options:find("MUF layout preview", 1, true), "preview has no duplicate heading")
Check(not options:find("H Healthy", 1, true), "preview has no letter legend")
Check(not options:find("sq.state", 1, true), "representative MUFs contain no state letters")
Check(not options:find("PREVIEW_HEIGHT = 300", 1, true), "preview cannot restore the empty fixed 300px viewport")
for _, key in ipairs({"magic", "curse", "poison", "disease", "healthy"}) do
  Check(options:find('{key = "' .. key .. '"', 1, true), "stable representative state exists: " .. key)
end
local statesStart = assert(options:find("local PREVIEW_STATES = {", 1, true))
local statesEnd = assert(options:find("}\nlocal LayoutCatalog", statesStart, true))
local states = options:sub(statesStart, statesEnd)
Check(not states:find('{key = "range"}', 1, true), "five-unit preview does not substitute range for a cure color")
Check(not states:find('{key = "dead"}', 1, true), "five-unit preview does not substitute dead for a cure color")

local mufs = Read("ZDecursive/MUFs.lua")
Check(mufs:find("local layout = ns.CalculateMUFLayout", 1, true), "live MUFs consume the shared layout result")
Check(not preview:find("RefreshMUFs", 1, true), "preview rendering cannot mutate the runtime roster")

print("muf-options-preview-contract: ok")
