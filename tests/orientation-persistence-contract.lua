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

local function Check(value, message)
  if not value then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local combat = false
InCombatLockdown = function()
  return combat
end

UnitFullName = function()
  return "Tester", "Realm"
end

UnitName = function()
  return "Tester"
end

GetRealmName = function()
  return "Realm"
end

GetNormalizedRealmName = function()
  return "Realm"
end

local addon = {}
function addon:RegisterChatCommand()
end
function addon:RegisterEvent()
end
function addon:Print()
end

local AceAddon = {}
function AceAddon:NewAddon()
  return addon
end

LibStub = function(name)
  if name == "AceAddon-3.0" then
    return AceAddon
  end
  if name == "AceDB-3.0" then
    return {}
  end
  error("unexpected library " .. tostring(name))
end

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)

local refreshes = 0
ns.RefreshMUFs = function()
  refreshes = refreshes + 1
end
ns.RefreshOptions = function()
end
ns.RefreshAlerts = function()
end
ns.RefreshLiveList = function()
end

local function NewDB(environments)
  return {
    global = {
      schema = 3,
      accountProfile = "Default",
      characters = {},
      specs = {},
    },
    char = {
      editingEnvironment = "OPEN_WORLD",
      multipleEditingEnvironment = "OPEN_WORLD",
    },
    profile = {
      routingMode = "multiple",
      environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA,
      environments = environments or ns.MakeEnvironments(),
      lists = {priority = {}, skip = {}},
    },
    GetProfiles = function()
      return {"Default"}
    end,
    GetCurrentProfile = function()
      return "Default"
    end,
    SetProfile = function()
    end,
  }
end

local function AssertSix(vertical, message)
  for _, row in ipairs(ns.ENVIRONMENTS) do
    Equal(addon.db.profile.environments[row.key].mufs.verticalLayout, vertical, message .. " " .. row.key)
  end
end

-- Mixed pre-schema profiles deterministically preserve any explicit Vertical.
addon.db = NewDB()
addon.db.profile.environments.DUNGEON.mufs.verticalLayout = true
addon:EnsureEnvironments()
Equal(addon.db.profile.mufOrientation, "VERTICAL", "mixed legacy migration")
Equal(addon.db.profile.mufOrientationSchema, ns.MUF_ORIENTATION_SCHEMA, "migration schema")
AssertSix(true, "legacy mirrors")

-- Schema-last migration is idempotent and the shared value wins thereafter.
addon.db.profile.environments.RAID.mufs.verticalLayout = false
addon:EnsureEnvironments()
Equal(addon.db.profile.mufOrientation, "VERTICAL", "current schema remains authoritative")
AssertSix(true, "current schema repairs mirror")

-- Editing an inactive environment still changes the one shared orientation.
addon.appliedEnvironment = "OPEN_WORLD"
addon.db.char.editingEnvironment = "DUNGEON"
addon.db.char.multipleEditingEnvironment = "DUNGEON"
refreshes = 0
local ok, state = addon:SetMUFOrientation("HORIZONTAL")
Check(ok and state == "applied", "horizontal setter applies out of combat")
Equal(refreshes, 1, "inactive editor setter refreshes live layout")
AssertSix(false, "horizontal mirrors")
ok, state = addon:SetMUFOrientation(true)
Check(ok and state == "applied", "boolean vertical compatibility setter")
AssertSix(true, "vertical reversal mirrors")

-- Pack copy and reset cannot overwrite or diverge the shared orientation.
addon.db.profile.environments.OPEN_WORLD.mufs.partySize = 33
ok = addon:CopyEditingPackTo("RAID")
Check(ok, "copy succeeds")
AssertSix(true, "copy preserves shared orientation")
ok = addon:ResetEditingPack()
Check(ok, "pack reset succeeds")
AssertSix(true, "pack reset preserves shared orientation")

-- Combat declines before changing shared profile authority.
combat = true
refreshes = 0
ok, state = addon:SetMUFOrientation("HORIZONTAL")
Check(not ok and state == "combat", "combat setter declines before layout storage mutation")
Equal(addon:GetMUFOrientation(), "VERTICAL", "combat decline preserves shared value")
Equal(refreshes, 0, "combat setter does not lay out")
Check(addon.pendingMUFOrientation == nil, "combat decline creates no partial pending marker")
AssertSix(true, "combat decline preserves pack mirrors")
combat = false
ok, state = addon:SetMUFOrientation("HORIZONTAL")
Check(ok and state == "applied", "post-combat orientation applies")
Equal(refreshes, 1, "post-combat orientation refreshes once")
AssertSix(false, "post-combat setter mirrors packs")

-- New and malformed shared values normalize to Horizontal; full profile reset does too.
addon.db = NewDB()
addon.db.profile.mufOrientation = "SIDEWAYS"
addon.db.profile.mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA
addon:EnsureEnvironments()
Equal(addon:GetMUFOrientation(), "HORIZONTAL", "invalid current value is conservative")
AssertSix(false, "invalid current value mirrors Horizontal")
addon.appliedEnvironment = "OPEN_WORLD"
addon.ApplyResolvedEnvironment = function()
  return true, "unchanged"
end
ok = addon:ResetCurrentProfile()
Check(ok, "addon profile reset succeeds")
Equal(addon:GetMUFOrientation(), "HORIZONTAL", "addon profile reset default")
AssertSix(false, "addon profile reset mirrors")

local options = Read("ZDecursive/Options.lua")
Check(options:find("Vertical orientation (all environment profiles)", 1, true), "shared UI label")
Check(options:find("Shared by all six environment profiles", 1, true), "shared UI help")
Check(options:find("local verticalLayout = addon.GetMUFVerticalLayout", 1, true), "preview reads shared authority")
Check(not options:find('PathSet("mufs", "verticalLayout")', 1, true), "generic per-pack setter retired")
Check(not options:find("OnHide", 1, true) or not options:match("OnHide.-SetMUFOrientation"), "OnHide never mutates orientation")

local mufs = Read("ZDecursive/MUFs.lua")
Check(mufs:find("addon:GetMUFVerticalLayout()", 1, true), "party raid and pet layout consume shared authority")
Check(mufs:find("if verticalLayout then", 1, true), "vertical grid branch retained")
Check(mufs:find("ns.BuildRoster", 1, true), "shared grid covers roster and enabled pets")

io.write("orientation-persistence-contract: ok\n")
