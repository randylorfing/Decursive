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
local harness = f:read('*a'); f:close()
-- Reuse the existing plain-AceDB fixture, through initial default creation only.
local stop = assert(harness:find('local modeProfile = db.profile', 1, true))
harness = harness:sub(1, stop - 1) .. '\nreturn ns, addon, db'
local failures = 0
for _, operation in ipairs({'ActivateProfile', 'CreateProfile', 'CopyProfile', 'SetAccountProfileAssignment'}) do
  local ns, addon, db = assert(load(harness, '@profile-fixture'))()
  if operation ~= 'CreateProfile' and operation ~= 'CopyProfile' then
    db.profiles.Candidate = ns.DeepCopy(db.profile)
  end
  local calls = 0
  ns.DetectionEngine = {Refresh = function()
    calls = calls + 1
    return false, 'FAILURE'
  end}
  local ok, state = addon[operation](addon, 'Candidate')
  io.write(operation, ': returned=', tostring(ok), '/', tostring(state),
    ' active=', db.current, ' assignment=', db.global.accountProfile,
    ' refreshFailures=', calls, '\n')
  if ok ~= false or db.current ~= 'Default' or db.global.accountProfile ~= 'Default' then
    failures = failures + 1
  end
end
assert(failures == 0, tostring(failures) .. ' profile operations committed despite failed runtime refresh')
