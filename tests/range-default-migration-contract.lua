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

local file = assert(io.open("tests/profile-transaction.lua", "rb"))
local fixture = file:read("*a")
file:close()
local stop = assert(fixture:find("local modeProfile = db.profile", 1, true))
fixture = fixture:sub(1, stop - 1) .. "\nreturn ns, addon, db\n"
local ns, addon, db = assert(load(fixture, "@range-profile-fixture"))()
local checks = 0
local function Check(value, message)
  checks = checks + 1
  if not value then error(message, 2) end
end
local function Prior()
  local packs = ns.MakeEnvironments()
  for _, row in ipairs(ns.ENVIRONMENTS) do packs[row.key].mufs.dimAmount = 0.60 end
  packs.OPEN_WORLD.mufs.dimOutOfRange = false
  return packs
end
local packs = Prior()
db.profile = {appearanceSchema = 8, environments = packs}
local ok, changes = addon:MigrateAppearanceDefaults(packs)
Check(ok and changes == 7, "six prior brightness values and factory Open World exception migrate")
Check(db.profile.appearanceSchema == 9, "schema advances after completed migration")
for _, row in ipairs(ns.ENVIRONMENTS) do
  Check(packs[row.key].mufs.dimAmount == 0.50, row.key .. " prior brightness becomes 50%")
  Check(packs[row.key].mufs.dimOutOfRange == true, row.key .. " default dimming is enabled")
end
ok, changes = addon:MigrateAppearanceDefaults(packs)
Check(ok and changes == 0, "migration is idempotent")
packs.OPEN_WORLD.mufs.dimOutOfRange = false
packs.OPEN_WORLD.mufs.dimAmount = 0.60
ok, changes = addon:MigrateAppearanceDefaults(packs)
Check(ok and changes == 0 and not packs.OPEN_WORLD.mufs.dimOutOfRange
  and packs.OPEN_WORLD.mufs.dimAmount == 0.60, "later user selections survive")
packs = Prior()
packs.OPEN_WORLD.mufs.centerTransp = 0.27
packs.DUNGEON.mufs.dimAmount = 0.75
packs.RAID.mufs.dimOutOfRange = false
packs.SOLO.colors.range = {0.2, 0.4, 0.6, 1}
local customColor = packs.SOLO.colors.range
db.profile = {appearanceSchema = 8, environments = packs}
ok, changes = addon:MigrateAppearanceDefaults(packs)
Check(ok and changes == 5, "only exact prior brightness values migrate in custom packs")
Check(packs.OPEN_WORLD.mufs.dimOutOfRange == false, "custom Open World appearance preserves its disabled choice")
Check(packs.DUNGEON.mufs.dimAmount == 0.75, "custom brightness survives")
Check(packs.RAID.mufs.dimOutOfRange == false, "other disabled environment stays disabled")
Check(packs.SOLO.colors.range == customColor, "custom range color is not replaced")
db.profile.appearanceSchema = 10
packs.DUNGEON.mufs.dimAmount = 0.60
ok, changes = addon:MigrateAppearanceDefaults(packs)
Check(ok and changes == 0 and db.profile.appearanceSchema == 10
  and packs.DUNGEON.mufs.dimAmount == 0.60, "future schema is untouched")
print("Range defaults migration: " .. tostring(checks) .. " checks passed")
