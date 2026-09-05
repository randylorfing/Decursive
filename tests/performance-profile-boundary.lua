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

-- Faults after mutation must never become a successful reusable profile plan.
local file = assert(io.open("tests/profile-transaction.lua", "rb"))
local fixture = file:read("*a")
file:close()
local stop = assert(fixture:find("local modeProfile = db.profile", 1, true))
fixture = fixture:sub(1, stop - 1) .. "\nreturn ns, addon, db"

local function EqualTables(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not EqualTables(value, right[key]) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

for _, phase in ipairs({"migration-error", "migration-rejected", "validation-error", "validation-rejected"}) do
  local ns, addon, db = assert(load(fixture, "@profile-boundary-fixture"))()
  db.profile.environments.OPEN_WORLD.cure.bandageMode = "SELECTED"
  db.profile.environments.OPEN_WORLD.cure.bandageItemID = 123
  local before = ns.DeepCopy(db.profile)
  if phase == "migration-error" then
    addon.EnsureEnvironments = function() error("injected migration exception") end
  elseif phase == "migration-rejected" then
    addon.EnsureEnvironments = function() return false, "migration-rejected" end
  elseif phase == "validation-error" then
    addon.ValidateProfileTransactionState = function() error("injected validation exception") end
  else
    addon.ValidateProfileTransactionState = function() return false, "validation-rejected" end
  end
  local mutated = false
  local called, applied = pcall(addon.RunProfileStorageTransaction, addon, "fault-test", function()
    db.profile.environments.OPEN_WORLD = ns.MakePack("OPEN_WORLD")
    mutated = true
    return true, "reset"
  end)
  assert(mutated, phase .. " must exercise the post-mutation boundary")
  assert(called and applied == false, phase .. " must reject without escaping")
  assert(EqualTables(before, db.profile), phase .. " must restore the complete profile")
end
print("performance-profile-boundary: all post-mutation faults restore storage")
