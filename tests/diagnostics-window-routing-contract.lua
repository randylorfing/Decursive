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

local diagnostics = Read("ZDecursive/Diagnostics.lua")
local alerts = Read("ZDecursive/Alerts.lua")
assert(diagnostics:find("local function AppendRuntimeMessage", 1, true), "runtime notice API exists")
assert(diagnostics:find('AppendLog("NOTICE", message)', 1, true), "notice enters bounded report log")
local start = assert(diagnostics:find("local function AppendRuntimeMessage", 1, true))
local finish = assert(diagnostics:find("local function RunHealthCheck", start, true))
local notice = diagnostics:sub(start, finish - 1)
assert(not notice:find("ShowText(", 1, true), "notice cannot replace report text")
assert(not notice:find("frame:Show", 1, true), "notice cannot open report window")
assert(alerts:find('"Battle rez range warning emitted"', 1, true), "battle-rez log is identity-free")
local printStart = assert(alerts:find("local function PrintLine", 1, true))
local printFinish = assert(alerts:find("local function PlayPreset", printStart, true))
local printLine = alerts:sub(printStart, printFinish - 1)
assert(not printLine:find("ShowCopyableAlertText", 1, true), "ordinary alert status does not use report replacement route")
assert(printLine:find("RecordCopyableAlertText", 1, true), "ordinary alert status uses runtime-log route")
print("diagnostics-window-routing-contract: ok")
