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

local f = assert(io.open('tests/profile-transaction.lua', 'rb'))
local fixture = f:read('*a'); f:close()
local stop = assert(fixture:find('local modeProfile = db.profile', 1, true))
fixture = fixture:sub(1, stop - 1) .. [[
return ns, addon, db, timerQueue, function() instanceType = 'party'; grouped = true; challengeMapID = 123 end
]]
local ns, addon, db, timers, enterChallenge = assert(load(fixture, '@profile-fixture'))()
local blocked, packsSeen = false, {}
assert(loadfile('ZDecursive/DetectionEngine.lua'))('ZDecursive', ns)
local engine = ns.DetectionEngine
engine:RegisterConsumer('MUFs', function()
  packsSeen[#packsSeen + 1] = addon:GetAppliedEnvironment()
  return true, 'SUCCESS', 0
end)
engine:RegisterConsumer('LiveList', function() return true, 'SUCCESS', 0 end)
engine:RegisterConsumer('Alerts', function()
  return not blocked, blocked and 'DEFERRED_RESTRICTED' or 'SUCCESS', 0
end)
assert(engine:Refresh('BASELINE'))
assert(addon:GetAppliedEnvironment() == 'OPEN_WORLD')
enterChallenge()
blocked = true
local ok, status = addon:ApplyResolvedEnvironment('CHALLENGE_MODE_START')
assert(not ok and status == 'DEFERRED_RESTRICTED', 'fixture must defer runtime application')
assert(engine.retryScheduled, 'real engine retry must be armed')
blocked = false
local iterations = 0
while #timers > 0 do
  iterations = iterations + 1; assert(iterations < 100, 'bounded timers')
  table.remove(timers, 1)()
end
io.write('after native recovery: engine=', engine.state, ' applied=', addon:GetAppliedEnvironment(),
  ' pending=', tostring(addon.pendingEnvironment), ' consumer packs=', table.concat(packsSeen, ','), '\n')
assert(engine.state == 'READY', 'real engine must recover before checking environment ownership')
assert(addon:GetAppliedEnvironment() == 'MYTHIC_PLUS' and addon.pendingEnvironment == nil,
  'Recovery must finish the requested environment instead of committing the old pack')

-- A permanently rejected destination must exhaust the existing retry budget,
-- retain the last-good environment, and remain eligible for a later fresh edge.
local ns2, addon2, _db2, timers2, enterChallenge2 = assert(load(fixture, '@bounded-profile-fixture'))()
assert(loadfile('ZDecursive/DetectionEngine.lua'))('ZDecursive', ns2)
local engine2, blocked2 = ns2.DetectionEngine, false
engine2:RegisterConsumer('MUFs', function() return true, 'SUCCESS', 0 end)
engine2:RegisterConsumer('LiveList', function() return true, 'SUCCESS', 0 end)
engine2:RegisterConsumer('Alerts', function()
  return not blocked2, blocked2 and 'DEFERRED_RESTRICTED' or 'SUCCESS', 0
end)
assert(engine2:Refresh('BASELINE'))
enterChallenge2()
blocked2 = true
assert(addon2:ApplyResolvedEnvironment('CHALLENGE_MODE_START') == false)
local bounded = 0
while #timers2 > 0 do
  bounded = bounded + 1
  assert(bounded < 100, 'persistent destination failure must not reset its retry budget')
  table.remove(timers2, 1)()
end
assert(engine2.retryExhausted == true, 'persistent failure reaches explicit exhaustion')
assert(addon2:GetAppliedEnvironment() == 'OPEN_WORLD' and addon2.pendingEnvironment == 'MYTHIC_PLUS',
  'exhaustion retains the last-good pack and requested target')
assert(engine2.state ~= 'READY', 'exhausted destination must not be reported ready')
blocked2 = false
assert(addon2:ApplyResolvedEnvironment('FRESH_ENVIRONMENT_EDGE'))
assert(engine2.state == 'READY' and addon2:GetAppliedEnvironment() == 'MYTHIC_PLUS')
assert(addon2.pendingEnvironment == nil and not engine2.retryExhausted)
print('pending environment permanent failure: bounded exhaustion and fresh-edge recovery passed')
