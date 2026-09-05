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

-- ZDecursive, Copyright (C) 2026 Randy Lorfing.
-- Based on Decursive, Copyright (C) 2006-2026 John Wellesz.
-- GPL-3.0-or-later; distributed without warranty. See ../LICENSE.

local checks, calls = 0, 0
local function Check(value, message)
  checks = checks + 1
  if not value then error(message, 2) end
end
local secret = setmetatable({}, {
  __eq = function() error("compared an opaque range value") end,
  __tostring = function() error("formatted an opaque range value") end,
})
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
local answer, fail, queriedSpell, queriedUnit
C_Spell = {IsSpellInRange = function(spellId, unit)
  calls = calls + 1
  queriedSpell, queriedUnit = spellId, unit
  if fail then error("range API temporarily unavailable") end
  return answer
end}
UnitInRange = function() error("generic range must not substitute for a cure") end
CheckInteractDistance = UnitInRange
local ns = {}
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
local query = ns.CureSpellRangeValue
answer = false
Check(query("party1", 527) == false, "public false is actual out-of-range evidence")
Check(queriedSpell == 527 and queriedUnit == "party1", "queries the exact cure and target")
answer = true
Check(query("party2", 213634) == true, "public true remains in range")
Check(queriedSpell == 213634 and queriedUnit == "party2", "a different installed cure is not replaced by a healing probe")
answer = nil
Check(query("party1", 527) == nil, "nil is unknown, not out of range")
for _, invalid in ipairs({0, 1, "false", {}, function() end}) do
  answer = invalid
  Check(query("party1", 527) == nil, "invalid public API return is unknown")
end
answer = secret
Check(rawequal(query("party1", 527), secret), "opaque value is forwarded without comparison")
fail = true
Check(query("party1", 527) == nil, "API exception is unknown")
fail, answer = false, false
local oldCalls = calls
for _, invalid in ipairs({0, -1, 0.5, math.huge, 0/0, "527", {}, secret}) do
  Check(query("party1", invalid) == nil, "invalid or inaccessible spell identifier is rejected")
end
Check(query("party1", nil) == nil, "missing spell is rejected")
for _, invalid in ipairs({"", false, 123, {}, secret}) do
  Check(query(invalid, 527) == nil, "invalid or inaccessible unit is rejected")
end
Check(query(nil, 527) == nil, "missing unit is rejected")
Check(calls == oldCalls, "invalid arguments never reach the client API")
C_Spell.IsSpellInRange = nil
Check(query("party1", 527) == nil, "missing method remains unknown")
C_Spell = nil
Check(query("party1", 527) == nil, "missing API table remains unknown")
print("Cure spell range contract: " .. tostring(checks) .. " checks passed")
