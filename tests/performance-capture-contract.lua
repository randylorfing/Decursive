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

-- Explicit owned callbacks only: opt-in timing, exact returns, nested self time,
-- bounded cleanup during combat, and cleanup after runtime/install/timer faults.
local model = assert(loadfile("tests/fixtures/frame-mock.lua"))()
model.Install(1920, 1080)
local now, combat, assigned = 1000, false, 40
local version = "v13.1.2-Alpha-engine.5"
C_AddOns = {GetAddOnMetadata=function(_, field) if field == "Version" then return version end end}
local timers = {}
C_Timer.After = function(delay, callback) timers[#timers + 1] = {delay=delay, callback=callback} end
InCombatLockdown = function() return combat end
debugprofilestop = function() return now end
issecretvalue = function() return false end
canaccessvalue = function() return true end
local ns = {GetPerformanceAssignedFrameCount=function() return assigned end}
assert(loadfile("ZDecursive/Diagnostics.lua"))("ZDecursive", ns)
local targets = {}
local originals = {}
local function register(name, callback)
  targets[name], originals[name] = callback, callback
  assert(ns.RegisterPerformanceTarget(name, function() return targets[name] end, function(fn) targets[name]=fn end))
end
register("leaf", function() now=now+3; return "leaf" end)
register("outer", function()
  now=now+2; targets.leaf(); targets.leaf(); now=now+4
  return nil, 5, nil, false, "tail", nil
end)
assert(ns.RegisterPerformanceTarget("missing", function() return nil end, function() error("not callable") end))
assert(not ns.GetPerformanceCaptureStatus().active)
assert(ns.BuildPerformanceReport():find("Addon version: v13.1.2-Alpha-engine.5",1,true))
version = "private/path"
assert(ns.BuildPerformanceReport():find("Addon version: unavailable",1,true), "version rejects paths")
version = "Private Name"
assert(ns.BuildPerformanceReport():find("Addon version: unavailable",1,true), "version rejects arbitrary labels")
version = "v13.1.2-Alpha-engine.5"
assert(targets.outer==originals.outer, "no wrapper before explicit capture")
combat=true
local ok, reason=ns.StartPerformanceCapture(15)
assert(not ok and reason=="COMBAT" and targets.outer==originals.outer)
combat=false
assert(not ns.StartPerformanceCapture(31), "only bounded supported durations")
assert(ns.StartPerformanceCapture(15))
assert(timers[#timers].delay==15)
assert(not ns.StartPerformanceCapture(30), "cannot nest a capture")
assert(not ns.RegisterPerformanceTarget("late", function() end, function() end), "registry stable during capture")
local function pack(...) return {n=select("#",...),...} end
combat=true
local result=pack(targets.outer())
assert(result.n==6 and result[1]==nil and result[2]==5 and result[3]==nil and result[4]==false and result[5]=="tail" and result[6]==nil)
assigned=39
now=16000
timers[#timers].callback()
assert(not ns.GetPerformanceCaptureStatus().active, "timeout stops in combat")
assert(targets.outer==originals.outer and targets.leaf==originals.leaf, "restored exact owned functions in combat")
local report=ns.BuildPerformanceReport()
assert(report:find("Addon version: v13.1.2-Alpha-engine.5",1,true), "capture identifies installed version")
assert(report:find("outer | 1 | 12.000 | 6.000 | 12.000 | 0",1,true), "nested child time subtracted")
assert(report:find("leaf | 2 | 6.000 | 6.000 | 3.000 | 0",1,true))
assert(report:find("40/39",1,true) and report:find("Unavailable targets: missing",1,true))
assert(not ns.ShowPerformanceReport(), "report UI cannot open during combat")

combat=false
version = "v13.1.2-Alpha-engine.6"
assert(ns.BuildPerformanceReport():find("Addon version: v13.1.2-Alpha-engine.5",1,true), "completed capture retains original version")
local errorObject={private="must never enter the report"}
register("broken", function() now=now+2; error(errorObject) end)
assert(ns.StartPerformanceCapture(30))
assert(ns.BuildPerformanceReport():find("Addon version: v13.1.2-Alpha-engine.6",1,true), "new capture records its actual version")
local failed, actual=pcall(targets.broken)
assert(not failed and actual==errorObject, "original error object preserved")
assert(ns.GetPerformanceCaptureStatus().state=="TARGET_ERROR")
for name, original in pairs(originals) do assert(targets[name]==original, "fault restores "..name) end
assert(not ns.BuildPerformanceReport():find("private",1,true), "never log raw errors")
timers[#timers].callback()
assert(ns.GetPerformanceCaptureStatus().state=="TARGET_ERROR", "old timeout cannot overwrite failure")

-- Partial setter failure must restore previously installed wrappers and a setter
-- that assigned the wrapper before raising.
local fragile=function() end
local fragileOriginal=fragile
local failInstall=true
assert(ns.RegisterPerformanceTarget("fragile", function() return fragile end, function(fn)
  fragile=fn
  if fn~=fragileOriginal and failInstall then error("setter failed after assignment") end
end))
ok,reason=ns.StartPerformanceCapture(15)
assert(not ok and reason=="INSTALL_FAILED" and fragile==fragileOriginal)
for name, original in pairs(originals) do assert(targets[name]==original) end
failInstall=false
local realTimer=C_Timer.After
C_Timer.After=function() error("timer unavailable") end
ok,reason=ns.StartPerformanceCapture(15)
assert(not ok and reason=="TIMER_FAILED" and fragile==fragileOriginal)
C_Timer.After=realTimer
assert(ns.StartPerformanceCapture(15))
local oldTimer=timers[#timers].callback
assert(ns.StopPerformanceCapture("STOPPED"))
assert(ns.StartPerformanceCapture(30))
oldTimer()
assert(ns.GetPerformanceCaptureStatus().active, "previous capture timer cannot stop new session")
assert(ns.HandlePerformanceCommand("stop"))
assert(SlashCmdList.ZDECURSIVEPERFORMANCE==ns.HandlePerformanceCommand)
assert(ns.ShowPerformanceReport(), "copyable report opens outside combat")
print("performance-capture-contract: ok")
