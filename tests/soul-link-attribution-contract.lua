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

-- Test real generated/installed metadata and the exact PreClick callback.
local function Read(name)
  local f=assert(io.open("ZDecursive/"..name,"rb"))
  local s=f:read("*a"); f:close(); return s
end
local combat,shift,now=false,false,100
local secret={}
InCombatLockdown=function() return combat end
IsShiftKeyDown=function() return shift end
IsControlKeyDown=function() return false end
IsAltKeyDown=function() return false end
issecretvalue=function(v) return v==secret end
canaccessvalue=function(v) return v~=secret end
GetTime=function() return now end
UnitIsDeadOrGhost=function(unit) if unit=="party3" then return secret end; return unit=="party1" end
local ns={}
assert(load(Read("Defaults.lua")))("ZDecursive",ns)
assert(load(Read("ClickBindings.lua")))("ZDecursive",ns)
local pack=ns.MakePack("DUNGEON")
ns.addon={GetAppliedEnvironmentPack=function() return pack end,GetAppliedEnvironment=function() return "DUNGEON" end}
local cures={{spellId=527,name="Purify",types={"magic"}}}
ns.GetKnownCures=function() return cures end
local normalRez="Resurrection"
ns.GetSmartRezActions=function() return nil,normalRez,true,normalRez==nil,248486,777 end
ns.IsMUFRezEligibleUnitToken=function(unit) return unit~="partypet1" end
local source=Read("MUFs.lua")
local runtime=assert(load(source.."\nreturn {install=ApplyClickAttributes,gate=ShouldBeginSoulLinkAttempt,beginCure=BeginCureAttempt}"))("ZDecursive",ns)
local btn={unit="party1",assigned=true,attributes={}}
local writes=0
function btn:SetAttribute(k,v) assert(not combat,"no combat secure writes"); writes=writes+1; self.attributes[k]=v end
assert(runtime.install(btn,pack,btn.unit))
assert(btn.attributes["*macrotext1"]:find("dead,nocombat] Resurrection",1,true),"normal rez branch installed")
assert(btn.attributes["*macrotext1"]:find("dead,combat] item:248486",1,true),"actual carried quality installed")
assert(not runtime.gate(btn,"LeftButton"),"ordinary rez cannot arm Soul Link")
combat=true
assert(runtime.gate(btn,"LeftButton"),"combat Soul Link can arm")
btn.unit="party2"; assert(not runtime.gate(btn,"LeftButton"),"living dispel cannot arm")
btn.unit="party3"; assert(not runtime.gate(btn,"LeftButton"),"secret death fails closed")
btn.unit="party1"; btn.assigned=false
assert(not runtime.gate(btn,"LeftButton"),"unassigned MUF cannot arm"); btn.assigned=true
combat=false
assert(ns.SetClickBindingOverride(pack,"shift-left","TARGET")); assert(runtime.install(btn,pack,btn.unit))
assert(btn.attributes["shift-type1"]=="target")
combat,shift=true,true
assert(not runtime.gate(btn,"LeftButton"),"modifier Target blocks wildcard attribution")
shift=false; assert(runtime.gate(btn,"LeftButton"),"wildcard Soul Link survives")
combat=false
assert(ns.SetClickBindingOverride(pack,"shift-left","CURE1")); assert(runtime.install(btn,pack,btn.unit))
assert(not btn.attributes["shift-macrotext1"]:find("item:248486",1,true))
combat,shift=true,true
assert(not runtime.gate(btn,"LeftButton"),"modifier cure-only cannot arm")
shift=false
local first=assert(source:find('  btn:SetScript("PreClick", function(self, button)',1,true))
local last=assert(source:find("  local engine = ns.DetectionEngine",first,true))
function btn:SetScript(name,callback) self[name]=callback end
local env=setmetatable({btn=btn,ns=ns,ShouldBeginSoulLinkAttempt=runtime.gate,BeginCureAttempt=runtime.beginCure},{__index=_G})
assert(load(source:sub(first,last-1),"actual-PreClick","t",env))()
local alertSource=Read("Alerts.lua")
first=assert(alertSource:find("function ns.BeginSoulLinkAttempt(unit)",1,true))
last=assert(alertSource:find("local function RegisterEvents()",first,true))
local warnings=0
local alertEnv=setmetatable({ns=ns,Public=function(v) if v~=secret then return v end end,
  Accessible=function(v) return v~=secret end,UnitName=function() return "Friend" end,
  ShowSoulLinkWarning=function() warnings=warnings+1 end,
  SPELL_FAILED_OUT_OF_RANGE="Out of range",ERR_OUT_OF_RANGE="Out of range"},{__index=_G})
local onError=assert(load("local soulLinkAttempt\n"..alertSource:sub(first,last-1).."\nreturn OnUIError","actual-alerts","t",alertEnv))()
local previousWrites=writes
btn.PreClick(btn,"LeftButton"); onError(1,"Out of range")
assert(warnings==1,"actual Soul Link range failure warns")
btn.PreClick(btn,"LeftButton"); now=now+0.1; btn.unit="party2"; btn.PreClick(btn,"LeftButton"); onError(1,"Out of range")
assert(warnings==1,"new living dispel clears stale attempt")
btn.unit="party1"; btn.PreClick(btn,"LeftButton"); btn.PreClick(btn,"MiddleButton"); onError(1,"Out of range")
assert(warnings==1,"new utility click clears stale attempt")
assert(writes==previousWrites,"combat observations leave secure attributes unchanged")
combat=false; normalRez=nil; cures={}; ns.InvalidateClickModel()
assert(runtime.install(btn,pack,btn.unit))
assert(runtime.gate(btn,"LeftButton"),"rez-only fallback arms without cure row")
pack.advanced.allowMacroEdit=true; pack.advanced.customMacro="/target mouseover"; ns.InvalidateClickModel()
assert(runtime.install(btn,pack,btn.unit))
assert(not runtime.gate(btn,"LeftButton"),"custom macros are not interpreted as Soul Link")
print("soul-link-attribution-contract: ok")
