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
fixture = fixture:sub(1, stop - 1) .. '\nreturn ns, addon, db'
local ns, addon, db = assert(load(fixture, '@current-profile-fixture'))()
local env = addon:GetEditingEnvironment()
db.profile.environments[env].cure.bandageMode = 'SELECTED'
db.profile.environments[env].cure.bandageItemID = 123
local before = ns.DeepCopy(db.profile.environments[env])
local runtimeRefreshes = 0
ns.DetectionEngine = {Refresh = function()
  runtimeRefreshes = runtimeRefreshes + 1
  return true, 'SUCCESS'
end}
ns.RefreshOptions = function() error('injected options refresh exception') end
local called, result, state = pcall(addon.ResetEditingPack, addon)
local after = db.profile.environments[env]
io.write('reset call=', tostring(called), ' result=', tostring(result), '/', tostring(state),
  ' before=', before.cure.bandageMode, '/', tostring(before.cure.bandageItemID),
  ' after=', after.cure.bandageMode, '/', tostring(after.cure.bandageItemID),
  ' runtimeRefreshes=', tostring(runtimeRefreshes), '\n')
assert(runtimeRefreshes == 0, 'reproduction must fail before any engine runtime commit')
assert(after.cure.bandageMode == before.cure.bandageMode and after.cure.bandageItemID == before.cure.bandageItemID,
  'A post-mutation options refresh exception must not leave a failed reset committed')
assert(called and result == false, 'Profile transaction must translate a post-mutation failure into its normal rejected result')
