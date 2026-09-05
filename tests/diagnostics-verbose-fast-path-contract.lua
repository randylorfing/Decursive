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

-- Verify the public-value sanitizer is not entered for suppressed verbose data,
-- while initialization records, counters, and critical sanitation remain intact.
local reads=0
issecretvalue=function() reads=reads+1; return false end
canaccessvalue=function() reads=reads+1; return true end
local frames={}
CreateFrame=function()
  local f={}
  function f:RegisterEvent() end
  function f:UnregisterEvent() end
  function f:SetScript(_,fn) self.callback=fn end
  frames[#frames+1]=f; return f
end
time=function() return 1 end
ZDecursiveDiagnosticsDB=nil
local ns={Diagnostics={RegisterProvider=function() end}}
assert(loadfile("ZDecursive/PersistentDiagnostics.lua"))("ZDecursive",ns)
local api=ns.PersistentDiagnostics
api.Record("BEFORE",{state="SAFE"},false)
assert(api.Status().pendingRecords==1)
frames[1].callback(frames[1],"ADDON_LOADED","ZDecursive")
assert(api.Status().criticalEntries==2, "pre-init critical record retained")
local seen=api.Database.counters.verboseSeen or 0
local suppressed=api.Database.counters.verboseSuppressed or 0
reads=0
assert(not api.Record("VERBOSE",{state="SAFE"},true))
assert(reads==0, "disabled verbose rejects before value scans/field allocation")
assert(api.Database.counters.verboseSeen==seen+1 and api.Database.counters.verboseSuppressed==suppressed+1)
assert(api.Record("CRITICAL",{state="SAFE"},false) and reads>0, "critical fields still sanitized")
api.SetVerbose(true)
reads=0
assert(api.Record("VERBOSE",{state="SAFE"},true) and reads>0, "enabled verbose still sanitized")
print("diagnostics-verbose-fast-path-contract: ok")
