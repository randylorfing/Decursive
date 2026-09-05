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

-- Exercise actual workspace anchors and catalog reachability. The independent
-- options-geometry-contract covers rendered widget geometry at multiple sizes.
local function Check(value, message) assert(value, message) end
local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local environment = "OPEN_WORLD"
ns.addon = {GetEditingEnvironment = function() return environment end}
local Compile = loadstring or load
local access = assert(Compile(source .. [[
return {
  ui = ui, layout = LayoutWorkspace, visible = RowVisible,
  catalog = CATALOG, groups = GROUP_ORDER, pages = EDITOR_PAGES,
  labels = PAGE_LABELS, collapsed = IsCollapsed,
}
]], "@Options-layout-under-test"))("ZDecursive", ns)
local function Frame()
  return {
    points = {},
    ClearAllPoints = function(self) self.points = {} end,
    SetPoint = function(self, ...) self.points[#self.points + 1] = {...} end,
  }
end
access.ui.body, access.ui.tabBar, access.ui.profileBar = Frame(), Frame(), Frame()
for _, destination in ipairs({"environment", "addon_profiles", "search", "environment"}) do
  access.layout(destination)
  local points = access.ui.body.points
  Check(#points == 3, "switching workspace replaces previous anchors")
  if destination == "environment" or destination == "addon_profiles" then
    local header = destination == "environment" and access.ui.tabBar or access.ui.profileBar
    Check(points[1][1] == "TOPLEFT" and points[1][2] == header and points[1][3] == "BOTTOMLEFT", "content starts below its own header")
    Check(points[2][1] == "TOPRIGHT" and points[2][2] == header and points[2][3] == "BOTTOMRIGHT", "content tracks the header width")
    Check(points[1][5] < 0 and points[2][5] == points[1][5], "content and header have a positive gap")
  else
    Check(type(points[1][2]) == "number" and points[1][2] > 0, "search uses the full workspace origin")
  end
  Check(points[3][1] == "BOTTOMRIGHT" and points[3][2] < 0 and points[3][3] > 0, "workspace reserves right and footer margins")
end

local expectedPages = {mufs = "Frames", sorting = "Roster", cure = "Actions", color = "Colors", alerts = "Alerts", items = "Supplies", advanced = "Advanced"}
local pageSet = {}
for _, page in ipairs(access.pages) do
  Check(expectedPages[page] == access.labels[page], "editor category has a clear label")
  Check(not pageSet[page], "editor category is unique")
  pageSet[page] = true
end
for page in pairs(expectedPages) do Check(pageSet[page], "required editor category remains reachable: " .. page) end
Check(not pageSet.assign, "addon-profile lifecycle remains a separate destination")
local rowCount = 0
for _, spec in ipairs(access.catalog) do
  Check(pageSet[spec.page], "catalog row belongs to a reachable category: " .. spec.label)
  local found
  for _, group in ipairs(access.groups[spec.page] or {}) do if group == spec.group then found = true end end
  Check(found, "catalog row belongs to a rendered section: " .. spec.label)
  Check(not access.collapsed(spec.page, spec.group), "sections are expanded by default")
  for _, env in ipairs(ns.ENVIRONMENTS) do
    environment = env.key
    local expected = not (spec.hideEnv and spec.hideEnv[environment])
    Check(access.visible(spec) == expected, "every applicable setting is visible without a Simple filter: " .. spec.label)
  end
  rowCount = rowCount + 1
end
Check(rowCount >= 100, "redesign retains the complete configuration catalog")
Check(source:find('ui.navButtons["page:" .. key], ui.tabs[key] = button, button', 1, true), "category registry routes the sidebar buttons")
Check(source:find('SetTab(key)', 1, true), "sidebar routes into the environment editor")
Check(not source:find('ui.envChips', 1, true), "environment selection has no duplicate chip row")
Check(source:find('ui.profileBar:SetShown(destination == "addon_profiles")', 1, true), "profile lifecycle stays isolated")
Check(source:find('f:SetScript("OnSizeChanged", function()', 1, true), "resizing synchronizes scroll children")
Check(source:find('LayoutScrollChildren()', 1, true), "scroll content has a shared resize path")
io.write("options-layout-contract: actual anchors and ", rowCount, " reachable rows passed\n")
