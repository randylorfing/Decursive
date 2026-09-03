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

local options = Read("ZDecursive/Options.lua")
local core = Read("ZDecursive/Core.lua")
local mufs = Read("ZDecursive/MUFs.lua")
local liveList = Read("ZDecursive/LiveList.lua")

Check(options:find('local OPTIONS_COMBAT_MESSAGE = "ZDecursive Options cannot be opened during combat."', 1, true), "combat notice has the exact required text")
Check(options:find("local OPTIONS_COMBAT_NOTICE_SECONDS = 2", 1, true), "combat notice uses a bounded throttle")
Check(options:find('ns.DiagnosticRecord("options_open_blocked"', 1, true), "blocked opens persist a sanitized diagnostic event")
Check(options:find('ns.DiagnosticRecord("options_closed_for_combat"', 1, true), "combat closes persist a sanitized diagnostic event")

Check(core:find('ns.OptionsAccessAllowed("CORE_OPEN_OPTIONS")', 1, true), "slash and internal OpenOptions guard before dispatch")
Check(core:find('ns.OptionsAccessAllowed("CORE_TOGGLE_OPTIONS")', 1, true), "internal ToggleOptions guards before dispatch")
Check(core:find('ns.CloseOptionsForCombat("PLAYER_REGEN_DISABLED")', 1, true), "combat event immediately closes Options")
Check(options:find('OptionsAccessAllowed("SHOW_OPTIONS")', 1, true), "central ShowOptions entry is guarded")
Check(options:find('OptionsAccessAllowed("TOGGLE_OPTIONS")', 1, true), "central ToggleOptions entry is guarded")
Check(options:find('OptionsAccessAllowed("FRAME_BUILD")', 1, true), "frame construction has its own race guard")
Check(options:find('OptionsAccessAllowed("FRAME_SHOW")', 1, true), "frame OnShow has its own race guard")
Check(options:find('OptionsAccessAllowed("INTERFACE_OPTIONS")', 1, true), "Blizzard Settings launcher canvas is guarded")
Check(options:find('OptionsAccessAllowed("PAGE_NAVIGATION")', 1, true), "page navigation is guarded")
Check(options:find('OptionsAccessAllowed("TAB_NAVIGATION")', 1, true), "editor tab navigation is guarded")
Check(options:find('OptionsAccessAllowed("SEARCH")', 1, true), "search entry is guarded")
Check(options:find('OptionsAccessAllowed("PROFILE_MENU")', 1, true), "profile menu entry is guarded")
Check(options:find('OptionsAccessAllowed("PROFILE_NAVIGATION")', 1, true), "profile selection is guarded")
Check(options:find('OptionsAccessAllowed("PROFILE_MODAL")', 1, true), "profile modal entry is guarded")
Check(options:find('OptionsAccessAllowed("PROFILE_MODAL_ACCEPT")', 1, true), "profile modal acceptance is guarded")
Check(options:find('OptionsAccessAllowed("ENVIRONMENT_NAVIGATION")', 1, true), "environment chip navigation is guarded")
Check(options:find('OptionsAccessAllowed("PROFILE_MODE")', 1, true), "profile mode navigation is guarded")
Check(options:find('OptionsAccessAllowed("DIAGNOSTICS_HEALTH")', 1, true), "health-check button preserves the Options combat guard")

Check(mufs:find("ns.ShowOptions()", 1, true), "MUF handle routes through guarded ShowOptions")
Check(liveList:find("ns.ShowOptions()", 1, true), "Live List button routes through guarded ShowOptions")
Check(core:find('self:RegisterChatCommand("zdecursive", "OpenOptions")', 1, true), "/zdecursive routes through guarded OpenOptions")

local closeStart = assert(options:find("function ns.CloseOptionsForCombat", 1, true))
local closeEnd = assert(options:find("\nif ns.RegisterDiagnosticProvider", closeStart, true))
local closeBody = options:sub(closeStart, closeEnd)
Check(closeBody:find("TeardownMUFPreview()", 1, true), "combat close tears down preview state")
Check(closeBody:find("ui.frame:Hide()", 1, true), "combat close hides only the owned Options frame")
for _, forbidden in ipairs({"RefreshMUFs", "DetectionEngine", "SetAttribute", "AuraSlot", "CustomAuraContainer", "ShowOptions"}) do
  Check(not closeBody:find(forbidden, 1, true), "combat close avoids protected/runtime path " .. forbidden)
end

local regenStart = assert(core:find("function Decursive:OnRegenEnabled()", 1, true))
local regenEnd = assert(core:find("\nfunction Decursive:ScheduleWorldEntryRecoveryRetry", regenStart, true))
local regenBody = core:sub(regenStart, regenEnd)
Check(not regenBody:find("ShowOptions", 1, true), "combat exit never queues or reopens Options")
Check(not regenBody:find("ToggleOptions", 1, true), "combat exit never toggles Options")

io.write("options-combat-lockout-contract: ok\n")
