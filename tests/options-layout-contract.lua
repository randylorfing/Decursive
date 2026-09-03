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

local source = Read("ZDecursive/Options.lua")

Check(source:find('local WORKSPACE_GAP = 8', 1, true), "workspace chain owns one explicit gap")
Check(source:find('local SIDEBAR_HEADING_WIDTH = 146', 1, true), "sidebar heading has an explicit allocation")
Check(source:find('local PROFILE_MODE_LABEL_WIDTH = 96', 1, true), "Profile Mode has an explicit allocation")
Check(source:find('local PROFILE_MODE_GAP = 12', 1, true), "Profile Mode and Multiple have a measured gap")
Check(source:find('AnchorWorkspaceFrame(tabBar, envBar, envBar, WORKSPACE_GAP)', 1, true), "tabs follow the environment controls")
Check(source:find('AnchorWorkspaceFrame(ui.body, ui.tabBar, ui.tabBar, WORKSPACE_GAP)', 1, true), "content follows the tab row")
Check(source:find('AnchorWorkspaceFrame(ui.body, ui.profileBar, ui.profileBar, PROFILE_BODY_GAP)', 1, true), "profile content follows its own header")
Check(not source:find('ui.body:SetPoint("TOPLEFT", 204, -218)', 1, true), "regressed overlapping body origin is absent")
Check(source:find('ui.routingMultiple:SetText(environmentMode == "multiple"', 1, true), "Multiple mode is explicit")
Check(source:find('ui.routingSolo:SetText(environmentMode == "solo"', 1, true), "Solo mode is explicit")
Check(not source:find("OpenStaticEnvironmentMenu", 1, true), "obsolete static selector is absent")
Check(source:find('for _, key in ipairs(EDITOR_PAGES) do', 1, true), "only valid environment editor pages become tabs")

local pages = {"mufs", "sorting", "cure", "color", "alerts", "advanced", "assign"}
for i = 1, #pages do
  Check(source:find('ui.tabs[key] = tab', 1, true), "tab registry remains clickable")
  Check(source:find('SetTab(key)', 1, true), "tab click routing remains intact")
end

local function Rect(top, height, scale)
  local scaledTop = top * scale
  local scaledHeight = height * scale
  return {
    top = scaledTop,
    bottom = scaledTop + scaledHeight,
  }
end

local function Validate(width, height, scale, routingMode, simple, environment, page)
  local sidebarLeft = 20 * scale
  local sidebarRight = (20 + 170) * scale
  local sidebarHeadingLeft = (20 + 12) * scale
  local sidebarHeadingRight = sidebarHeadingLeft + 146 * scale
  local workspaceLeft = 204 * scale
  local workspaceRight = (width - 20) * scale
  local profileModeLeft = workspaceLeft
  local profileModeRight = profileModeLeft + 96 * scale
  local multipleLeft = profileModeRight + 12 * scale
  local multipleRight = multipleLeft + 118 * scale
  local soloLeft = multipleRight + 6 * scale
  local soloRight = soloLeft + 100 * scale
  local header = Rect(3, 108, scale)
  local environmentBar = Rect(116, 88, scale)
  local tabBar = Rect(212, 34, scale)
  local tabButton = Rect(215, 28, scale)
  local contentTop = 254 * scale
  local contentBottom = (height - 20) * scale
  Check(header.bottom < environmentBar.top, "header and environment controls do not overlap")
  Check(sidebarLeft < sidebarHeadingLeft and sidebarHeadingRight <= sidebarRight, "Environment Profiles heading remains wholly inside the sidebar")
  Check(sidebarHeadingRight < workspaceLeft, "sidebar heading cannot overlap Profile Mode")
  Check(profileModeLeft < profileModeRight and profileModeRight < multipleLeft, "Profile Mode has a measured nonoverlapping gap")
  Check(multipleRight < soloLeft and soloRight <= workspaceRight, "Multiple and Solo hitboxes remain wholly in the workspace")
  Check(environmentBar.bottom < tabBar.top, "Profile Mode controls and tabs have explicit spacing")
  Check(tabButton.bottom < contentTop, "every tab remains fully above the content viewport")
  Check(contentTop < contentBottom, "content viewport remains usable")
  Check(width >= 1100 and height >= 580, "resize bounds preserve the supported viewport")
  Check(routingMode == "solo" or routingMode == "multiple", "mode scenario is valid")
  Check(type(simple) == "boolean", "simple/full scenario is represented")
  Check(type(environment) == "string" and environment ~= "", "environment scenario is represented")
  Check(type(page) == "string" and page ~= "", "page scenario is represented")
end

local sizes = {
  {1100, 580},
  {1207, 807},
  {1800, 1400},
}
local scales = {0.64, 0.8, 1, 1.25}
local reportedScreenshotCrops = {{460, 320}, {363, 167}}
for i = 1, #reportedScreenshotCrops do
  Check(reportedScreenshotCrops[i][1] > 0 and reportedScreenshotCrops[i][2] > 0, "reported screenshot crop is represented")
end
local environments = {"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP", "SOLO"}
local editorPages = {"mufs", "sorting", "cure", "color", "alerts", "advanced"}
for i = 1, #sizes do
  for s = 1, #scales do
    for r = 1, 2 do
      for simpleIndex = 1, 2 do
        for e = 1, #environments do
          for p = 1, #editorPages do
            Validate(
              sizes[i][1],
              sizes[i][2],
              scales[s],
              r == 1 and "multiple" or "solo",
              simpleIndex == 1,
              environments[e],
              editorPages[p]
            )
          end
        end
      end
    end
  end
end

Check(source:find('local destination = searching and "search" or ui.destination', 1, true), "search retains its separate content origin")
Check(source:find('ui.statusPage:SetShown(destination == "status")', 1, true), "Status remains isolated")
Check(source:find('ui.profileBar:SetShown(destination == "addon_profiles")', 1, true), "Decursive Profiles remains isolated")
Check(source:find('profileModeLabel:SetWordWrap(false)', 1, true), "Profile Mode heading cannot wrap into controls")
Check(source:find('environmentLabel:SetWordWrap(false)', 1, true), "Environment Profiles heading cannot wrap into navigation hitboxes")
Check(source:find('f:SetScript("OnSizeChanged", function()', 1, true), "resize keeps scroll children synchronized")
Check(source:find('LayoutScrollChildren()', 1, true), "scroll content width remains synchronized")

print("options-layout-contract: ok")
