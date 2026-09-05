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

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

strtrim = function(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local combat = false
local instanceType = "none"
local challengeMapID
local raidGroup = false
local grouped = false
local instanceReady = true
local timerQueue = {}
InCombatLockdown = function()
  return combat
end

GetInstanceInfo = function()
  if not instanceReady then
    return nil, nil
  end
  return "Test Instance", instanceType, 1, "Test", 5, 0, false, 2451, 5, 777, false
end

C_Timer = {
  After = function(_delay, callback)
    timerQueue[#timerQueue + 1] = callback
  end,
}

C_ChallengeMode = {
  GetActiveChallengeMapID = function()
    return challengeMapID
  end,
}

IsInRaid = function()
  return raidGroup
end

IsInGroup = function()
  return grouped
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

C_SpecializationInfo = {
  GetSpecialization = function()
    return 1
  end,
  GetSpecializationInfo = function()
    return 71, "Arms"
  end,
  GetNumSpecializations = function()
    return 3
  end,
}

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

local AceDB = {}

LibStub = function(name)
  if name == "AceAddon-3.0" then
    return AceAddon
  end
  if name == "AceDB-3.0" then
    return AceDB
  end
  error("unexpected library " .. tostring(name))
end

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Core.lua"))("ZDecursive", ns)

local preflightOK, preflight = ns.PreflightRawProfileStorage(nil)
Check(preflightOK and preflight.reason == "missing", "missing raw storage passes without materialization")
local normalRaw = {global = {schema = 3}, profiles = {Default = {routingMode = "multiple"}}}
preflightOK, preflight = ns.PreflightRawProfileStorage(normalRaw)
Check(preflightOK and preflight.ok, "bounded normal raw storage passes")
local futureRaw = {global = {schema = 4}, profiles = {Default = {custom = "preserve"}}}
preflightOK, preflight = ns.PreflightRawProfileStorage(futureRaw)
Check(not preflightOK and preflight.reason == "forward-schema", "future raw schema fails closed")
Equal(futureRaw.profiles.Default.custom, "preserve", "future raw storage remains untouched")
local malformedRaw = {global = "bad"}
preflightOK, preflight = ns.PreflightRawProfileStorage(malformedRaw)
Check(not preflightOK and preflight.reason == "malformed-global", "malformed raw section fails closed")
Equal(malformedRaw.global, "bad", "malformed raw section remains untouched")
local cyclicRaw = {global = {schema = 3}}
cyclicRaw.self = cyclicRaw
preflightOK, preflight = ns.PreflightRawProfileStorage(cyclicRaw)
Check(not preflightOK and preflight.reason == "cycle-or-alias", "cyclic raw storage fails closed")
Check(cyclicRaw.self == cyclicRaw, "cyclic raw storage remains untouched")
local deepRaw = {}
local deepCursor = deepRaw
for _ = 1, 34 do
  deepCursor.child = {}
  deepCursor = deepCursor.child
end
preflightOK, preflight = ns.PreflightRawProfileStorage(deepRaw)
Check(not preflightOK and preflight.reason == "depth-limit", "excessively deep raw storage fails closed")
local nodeHeavyRaw = {}
for i = 1, 50001 do
  nodeHeavyRaw[i] = true
end
preflightOK, preflight = ns.PreflightRawProfileStorage(nodeHeavyRaw)
Check(not preflightOK and preflight.reason == "node-limit", "excessive raw storage nodes fail closed")
Equal(nodeHeavyRaw[50001], true, "node-heavy raw storage remains untouched")
local oversizedRaw = {payload = string.rep("x", 8 * 1024 * 1024 + 1)}
preflightOK, preflight = ns.PreflightRawProfileStorage(oversizedRaw)
Check(not preflightOK and preflight.reason == "byte-limit", "oversized raw storage fails closed")
Equal(#oversizedRaw.payload, 8 * 1024 * 1024 + 1, "oversized raw storage remains untouched")
DecursiveRebuildDB = futureRaw
local initialized = pcall(addon.OnInitialize, addon)
Check(initialized and addon.profileStorageBlocked == true and addon.db == nil, "cold initialization blocks before AceDB materialization")
Equal(DecursiveRebuildDB.profiles.Default.custom, "preserve", "blocked initialization never mutates raw storage")
DecursiveRebuildDB = nil
addon.profileStorageBlocked = nil

local function Copy(value)
  return ns.DeepCopy(value)
end

local function DeepEqual(left, right, seen)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  seen = seen or {}
  if seen[left] == right then
    return true
  end
  seen[left] = right
  for key, value in pairs(left) do
    if not DeepEqual(value, right[key], seen) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

local function CheckDefaultRange(color, message)
  Equal(color[1], 248 / 255, message .. " red")
  Equal(color[2], 200 / 255, message .. " green")
  Equal(color[3], 3 / 255, message .. " blue")
  Equal(color[4], 1, message .. " alpha")
end

local function CheckCanonicalCureColors(pack, message)
  local expected = {
    magic = {255 / 255, 7 / 255, 9 / 255, 1},
    curse = {153 / 255, 51 / 255, 255 / 255, 1},
    poison = {51 / 255, 204 / 255, 51 / 255, 1},
    disease = {255 / 255, 95 / 255, 36 / 255, 1},
  }
  for _, key in ipairs({"magic", "curse", "poison", "disease"}) do
    for channel = 1, 4 do
      Equal(pack.colors[key][channel], expected[key][channel], message .. " " .. key .. " channel " .. channel)
    end
  end
  Equal(table.concat(pack.cure.order, ","), "magic,curse,poison,disease", message .. " cure order")
end

local freshEnvironments = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  CheckDefaultRange(freshEnvironments[row.key].colors.range, row.key .. " fresh default range")
  CheckCanonicalCureColors(freshEnvironments[row.key], row.key .. " fresh canonical palette")
  if row.key == "PVP" then
    Equal(freshEnvironments[row.key].alerts.dispelEnabled, false, "PvP fresh landing DISPEL default")
    Equal(freshEnvironments[row.key].alerts.sound, false, "PvP fresh landing sound default")
  else
    Equal(freshEnvironments[row.key].alerts.dispelEnabled, true, row.key .. " fresh landing DISPEL default")
    Equal(freshEnvironments[row.key].alerts.sound, true, row.key .. " fresh landing sound default")
  end
  Equal(freshEnvironments[row.key].alerts.soulLinkAlert, true, row.key .. " fresh Soul Link warning default")
  Equal(freshEnvironments[row.key].alerts.successfulDispelText, false, row.key .. " fresh success text default")
end
Check(freshEnvironments.OPEN_WORLD.colors.range ~= freshEnvironments.DUNGEON.colors.range, "fresh environment range colors are independently owned")
Check(freshEnvironments.OPEN_WORLD.colors.magic ~= freshEnvironments.DUNGEON.colors.magic, "fresh environment cure colors are independently owned")
Check(freshEnvironments.OPEN_WORLD.cure.order ~= freshEnvironments.DUNGEON.cure.order, "fresh environment cure orders are independently owned")

local db = {
  profiles = {
    Default = {
      environments = ns.MakeEnvironments(),
      lists = {priority = {}, skip = {}},
    },
  },
  global = {
    schema = 3,
    accountProfile = "Default",
    characters = {},
    specs = {},
    identityShowAllDebuffs = false,
  },
  char = {
    editingEnvironment = "OPEN_WORLD",
  },
  current = "Default",
  profileKeys = {Tester = "Default"},
}

db.profile = db.profiles.Default
db.sv = {
  profiles = db.profiles,
  global = db.global,
  profileKeys = db.profileKeys,
}

function db:GetCurrentProfile()
  return self.current
end

function db:GetProfiles()
  local result = {}
  local seenCurrent = false
  for name in pairs(self.profiles) do
    result[#result + 1] = name
    if name == self.current then
      seenCurrent = true
    end
  end
  if not seenCurrent then
    result[#result + 1] = self.current
  end
  table.sort(result)
  return result
end

function db:SetProfile(name)
  self.current = name
  if not self.profiles[name] then
    self.profiles[name] = {}
  end
  self.profile = self.profiles[name]
  self.profileKeys.Tester = name
end

function db:CopyProfile(source)
  Check(source ~= self.current, "copy source differs from destination")
  Check(type(self.profiles[source]) == "table", "copy source exists")
  self.profiles[self.current] = Copy(self.profiles[source])
  self.profile = self.profiles[self.current]
end

function db:DeleteProfile(name, silent)
  if name == self.current then
    error("cannot delete active profile")
  end
  if not self.profiles[name] and not silent then
    error("profile missing")
  end
  self.profiles[name] = nil
end

function db:ResetDB(defaultProfile)
  self.profiles = {
    [defaultProfile] = {
      environments = ns.MakeEnvironments(),
      lists = {priority = {}, skip = {}},
    },
  }
  self.global = Copy(ns.defaults.global)
  self.char = Copy(ns.defaults.char)
  self.current = defaultProfile
  self.profile = self.profiles[defaultProfile]
  self.profileKeys = {Tester = defaultProfile}
  self.sv.profiles = self.profiles
  self.sv.global = self.global
  self.sv.profileKeys = self.profileKeys
end

addon.db = db
addon:EnsureEnvironments()
addon:EnsureSpecAssignments()

for _, row in ipairs(ns.ENVIRONMENTS) do
  local expectedCap = (row.key == "RAID" or row.key == "PVP") and 40 or 5
  Equal(db.profile.environments[row.key].mufs.maxUnits, expectedCap, row.label .. " fresh display cap")
end

local function CheckCooldownDefaults(pack, label)
  Equal(pack.alerts.cooldown, true, label .. " keeps cooldown presentation enabled")
  Equal(pack.alerts.cooldownOpacity, 0, label .. " adds no cooldown darkness")
  Equal(pack.alerts.cooldownNumbers, true, label .. " shows countdown numbers")
end
for _, row in ipairs(ns.ENVIRONMENTS) do
  CheckCooldownDefaults(db.profile.environments[row.key], row.key .. " fresh environment")
  Equal(db.profile.environments[row.key].cure.bandageMode, "AUTO", row.key .. " fresh bandage selection")
  Equal(db.profile.environments[row.key].cure.bandageItemID, 0, row.key .. " fresh bandage item")
end
-- Loading an existing profile must preserve explicit cooldown preferences.
local savedCooldown = db.profile.environments.RAID.alerts
savedCooldown.cooldownOpacity = 0.5
savedCooldown.cooldownNumbers = false
addon:EnsureEnvironments()
Equal(savedCooldown.cooldownOpacity, 0.5, "loading retains saved darkness")
Equal(savedCooldown.cooldownNumbers, false, "loading retains disabled countdown numbers")
savedCooldown.cooldownOpacity, savedCooldown.cooldownNumbers = nil, nil
addon:EnsureEnvironments()
CheckCooldownDefaults(db.profile.environments.RAID, "missing saved cooldown fields")

local modeProfile = db.profile
local legacyStaticProfile = {
  routingMode = "static",
  staticEnvironment = "RAID",
  environments = ns.MakeEnvironments(),
  lists = {priority = {}, skip = {}},
}
legacyStaticProfile.environments.RAID.mufs.maxUnits = 23
db.profile = legacyStaticProfile
addon:EnsureEnvironments()
Equal(db.profile.routingMode, "solo", "valid legacy static routing migrates to Solo")
Equal(db.profile.environmentModeSchema, 1, "legacy static migration stamps schema last")
Equal(db.profile.environments.SOLO.mufs.maxUnits, 23, "legacy static pack is copied into Solo")
Check(db.profile.environments.SOLO ~= db.profile.environments.RAID, "legacy static migration deep-copies the pack")
db.profile.environments.RAID.mufs.maxUnits = 31
Equal(db.profile.environments.SOLO.mufs.maxUnits, 23, "Solo migration is independent from the legacy source")
local migratedSolo = db.profile.environments.SOLO
addon:EnsureEnvironments()
Check(db.profile.environments.SOLO == migratedSolo, "mode migration is idempotent after the schema stamp")

for _, legacy in ipairs({
  {},
  {routingMode = "auto"},
  {routingMode = "static", staticEnvironment = "INVALID"},
  {routingMode = "INVALID"},
}) do
  legacy.environments = ns.MakeEnvironments()
  legacy.environments.SOLO = nil
  legacy.lists = {priority = {}, skip = {}}
  db.profile = legacy
  addon:EnsureEnvironments()
  Equal(db.profile.routingMode, "multiple", "non-valid legacy static modes migrate conservatively to Multiple")
  Equal(db.profile.environmentModeSchema, 1, "conservative migration stamps the mode schema")
  Check(type(db.profile.environments.SOLO) == "table", "conservative migration creates the default Solo pack")
end
db.profile = modeProfile
addon:EnsureEnvironments()

local pvpMigrationProfile = {
  routingMode = "multiple",
  environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA,
  mufOrientation = "HORIZONTAL",
  mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA,
  environments = ns.MakeEnvironments(),
  lists = {priority = {}, skip = {}},
}
pvpMigrationProfile.environments.PVP.alerts = Copy(ns.PREVIOUS_PVP_ALERT_DEFAULTS)
db.profile = pvpMigrationProfile
local migrationOK, migrationState = addon:MigratePvPAlertDefaults(pvpMigrationProfile.environments)
Check(migrationOK and migrationState == 1, "exact prior PvP Alerts signature migrates once")
Equal(db.profile.pvpAlertDefaultsSchema, 1, "PvP alert migration stamps schema last")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, false, "pristine prior PvP landing DISPEL migrates off")
Equal(db.profile.environments.PVP.alerts.sound, false, "pristine prior PvP landing sound migrates off")
Equal(db.profile.environments.PVP.alerts.soulLinkAlert, true, "PvP migration preserves Soul Link default")
Equal(db.profile.environments.PVP.alerts.successfulDispelText, false, "PvP migration preserves success text default")
local migratedPvPAlerts = db.profile.environments.PVP.alerts
migrationOK, migrationState = addon:MigratePvPAlertDefaults(pvpMigrationProfile.environments)
Check(migrationOK and migrationState == 0, "PvP alert migration is idempotent")
Check(db.profile.environments.PVP.alerts == migratedPvPAlerts, "idempotent PvP migration keeps table identity")

local customPvPProfile = Copy(pvpMigrationProfile)
customPvPProfile.pvpAlertDefaultsSchema = nil
customPvPProfile.environments.PVP.alerts = Copy(ns.PREVIOUS_PVP_ALERT_DEFAULTS)
customPvPProfile.environments.PVP.alerts.cooldownOpacity = 0.61
db.profile = customPvPProfile
migrationOK, migrationState = addon:MigratePvPAlertDefaults(customPvPProfile.environments)
Check(migrationOK and migrationState == 0, "a customized PvP Alerts table is not migrated")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, true, "custom PvP table preserves landing DISPEL")
Equal(db.profile.environments.PVP.alerts.sound, true, "custom PvP table preserves landing sound")
Equal(db.profile.environments.PVP.alerts.cooldownOpacity, 0.61, "custom PvP alert value is preserved")
Equal(db.profile.pvpAlertDefaultsSchema, 1, "custom PvP table is conservatively stamped")

local customCombinationProfile = Copy(pvpMigrationProfile)
customCombinationProfile.pvpAlertDefaultsSchema = nil
customCombinationProfile.environments.PVP.alerts = Copy(ns.PREVIOUS_PVP_ALERT_DEFAULTS)
customCombinationProfile.environments.PVP.alerts.dispelEnabled = false
db.profile = customCombinationProfile
migrationOK, migrationState = addon:MigratePvPAlertDefaults(customCombinationProfile.environments)
Check(migrationOK and migrationState == 0, "a custom PvP warning combination is not partially migrated")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, false, "custom PvP landing text choice is preserved")
Equal(db.profile.environments.PVP.alerts.sound, true, "custom PvP sound choice is preserved")

local partialPvPProfile = {
  routingMode = "multiple",
  environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA,
  pvpAlertDefaultsSchema = ns.PVP_ALERT_DEFAULTS_SCHEMA,
  mufOrientation = "HORIZONTAL",
  mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA,
  environments = ns.MakeEnvironments(),
  lists = {priority = {}, skip = {}},
}
partialPvPProfile.environments.PVP.alerts.dispelEnabled = nil
partialPvPProfile.environments.PVP.alerts.sound = nil
db.profile = partialPvPProfile
addon:EnsureEnvironments()
Equal(db.profile.environments.PVP.alerts.dispelEnabled, false, "missing PvP landing text fills from the PvP template")
Equal(db.profile.environments.PVP.alerts.sound, false, "missing PvP sound fills from the PvP template")
Equal(db.profile.environments.DUNGEON.alerts.dispelEnabled, true, "environment-specific fill keeps Dungeon landing text on")
Equal(db.profile.environments.DUNGEON.alerts.sound, true, "environment-specific fill keeps Dungeon sound on")

db.profile = modeProfile
addon:EnsureEnvironments()

local uiStatus = addon:GetUIProfileStatus()
Check(uiStatus.available, "UI profile status is available after binding")
Equal(uiStatus.actualProfile, "Default", "UI status reports actual AceDB profile")
Equal(uiStatus.resolvedProfile, "Default", "UI status reports resolved profile")
Equal(uiStatus.resolvedTier, "account", "UI status reports assignment tier")

local environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.appliedEnvironment, "OPEN_WORLD", "cold fallback applies Open World")
Equal(environmentStatus.resolvedEnvironment, "OPEN_WORLD", "Multiple resolves Open World")
Equal(environmentStatus.detectedEnvironment, "OPEN_WORLD", "detected context is reported separately")
Equal(environmentStatus.environmentMode, "multiple", "fresh profile defaults to Multiple")
Equal(environmentStatus.editingEnvironment, "OPEN_WORLD", "editor starts on Open World")

grouped = true
instanceType = "party"
instanceReady = false
addon.appliedEnvironment = "OPEN_WORLD"
addon.worldEntryRecoveryPending = true
Check(not addon:OnEnteringWorld(), "reload-inside waits when instance return #2 is not ready")
Equal(addon:GetAppliedEnvironment(), "OPEN_WORLD", "not-ready instance context retains last applied environment")
Equal(#timerQueue, 17, "not-ready instance context schedules environment, world, and roster convergence samples")
instanceReady = true
table.remove(timerQueue, 1)()
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "bounded retry applies Dungeon after exact Retail return shape becomes ready")
Equal(addon.environmentRetryCount, 0, "successful retry clears retry count")

instanceType = "scenario"
addon.appliedEnvironment = "OPEN_WORLD"
local scenarioOK, scenarioState = addon:ApplyResolvedEnvironment("scenario")
Check(scenarioOK and scenarioState == "applied", "scenario resolves through global GetInstanceInfo return #2")
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "scenario applies Dungeon environment")

grouped = true
instanceType = "party"
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.resolvedEnvironment, "DUNGEON", "party instance resolves Dungeon")
Equal(environmentStatus.reason, "PARTY_INSTANCE", "follower and normal party instances share deterministic source")
local ok, state = addon:ApplyResolvedEnvironment("party")
Check(ok and state == "unchanged", "party environment remains applied outside combat")
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "Dungeon becomes applied environment")
Check(addon:GetAppliedEnvironmentPack() == db.profile.environments.DUNGEON, "runtime pack follows applied environment")
Equal(addon:GetAppliedEnvironmentPack().mufs.maxUnits, 5, "Dungeon applied runtime cap is five")
Equal(addon:GetEditingPack().mufs.maxUnits, 5, "Open World editor remains independent from applied Dungeon")
CheckDefaultRange(addon:GetAppliedEnvironmentPack().colors.range, "applied Dungeon default range")
CheckDefaultRange(addon:GetEditingPack().colors.range, "editing Open World default range")
Check(addon:GetAppliedEnvironmentPack().colors.range ~= addon:GetEditingPack().colors.range, "applied and editing environments own independent range colors")
CheckCanonicalCureColors(addon:GetAppliedEnvironmentPack(), "applied Dungeon canonical palette")
CheckCanonicalCureColors(addon:GetEditingPack(), "editing Open World canonical palette")
Check(addon:GetAppliedEnvironmentPack().colors.magic ~= addon:GetEditingPack().colors.magic, "applied and editing environments own independent cure colors")

challengeMapID = 501
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.resolvedEnvironment, "MYTHIC_PLUS", "active challenge overrides party instance")
db.profile.environments.MYTHIC_PLUS.mufs.maxUnits = 8
db.profile.environments.RAID.mufs.maxUnits = 12
addon:ApplyResolvedEnvironment("challenge")
Equal(addon:GetAppliedEnvironment(), "MYTHIC_PLUS", "Mythic+ applies")
Equal(addon:GetAppliedEnvironmentPack().mufs.maxUnits, 8, "applied environment owns its custom display cap")
Equal(addon:GetEditingPack().mufs.maxUnits, 5, "editing environment cap remains independent")

challengeMapID = nil
instanceType = "raid"
combat = true
ok, state = addon:ApplyResolvedEnvironment("raid-combat")
Check(not ok and state == "combat", "environment swap defers in combat")
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.appliedEnvironment, "MYTHIC_PLUS", "combat preserves applied environment")
Equal(environmentStatus.pendingEnvironment, "RAID", "combat exposes pending environment")
Equal(addon:GetAppliedEnvironmentPack().mufs.maxUnits, 8, "combat keeps applied display cap until environment swap is legal")
Equal(db.char.editingEnvironment, "OPEN_WORLD", "runtime resolution does not change editor selection")
combat = false
addon:ApplyResolvedEnvironment("raid-regen")
Equal(addon:GetAppliedEnvironment(), "RAID", "pending raid applies after combat")
Equal(addon:GetAppliedEnvironmentPack().mufs.maxUnits, 12, "post-combat environment applies its own display cap")

instanceType = "pvp"
addon:ApplyResolvedEnvironment("pvp")
Equal(addon:GetAppliedEnvironment(), "PVP", "PvP instance applies PvP environment")

instanceType = "none"
raidGroup = true
addon:ApplyResolvedEnvironment("raid-group")
Equal(addon:GetAppliedEnvironment(), "RAID", "open-world raid group resolves Raid")
raidGroup = false
grouped = true
addon:ApplyResolvedEnvironment("open-world-party")
Equal(addon:GetAppliedEnvironment(), "OPEN_WORLD", "open-world party stays Open World")

local autoMatrix = {
  {instance = "none", challenge = nil, raid = false, grouped = false, expected = "OPEN_WORLD"},
  {instance = "party", challenge = nil, raid = false, grouped = true, expected = "DUNGEON"},
  {instance = "scenario", challenge = nil, raid = false, grouped = true, expected = "DUNGEON"},
  {instance = "raid", challenge = nil, raid = true, grouped = true, expected = "RAID"},
  {instance = "arena", challenge = nil, raid = false, grouped = true, expected = "PVP"},
  {instance = "pvp", challenge = nil, raid = false, grouped = true, expected = "PVP"},
  {instance = "party", challenge = 777, raid = false, grouped = true, expected = "MYTHIC_PLUS"},
}
for i = 1, #autoMatrix do
  local row = autoMatrix[i]
  instanceType = row.instance
  challengeMapID = row.challenge
  raidGroup = row.raid
  grouped = row.grouped
  local resolved, detected = addon:ResolveRoutedEnvironment()
  Equal(resolved, row.expected, "auto matrix routed target " .. i)
  Equal(detected, row.expected, "auto matrix detected target " .. i)
end
challengeMapID = nil
instanceType = "party"
grouped = true

db.profile.environments.SOLO.mufs.maxUnits = 17
ok, state = addon:SetEnvironmentMode("solo")
Check(ok, "Solo mode can be selected")
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.environmentMode, "solo", "Solo mode remains active")
Equal(environmentStatus.resolvedEnvironment, "SOLO", "Solo pack controls routed target")
Equal(environmentStatus.detectedEnvironment, "DUNGEON", "detected context remains diagnostic in Solo mode")
Equal(addon:GetAppliedEnvironment(), "SOLO", "Solo always becomes applied")
Equal(addon:GetAppliedEnvironmentPack().mufs.maxUnits, 17, "Solo owns an independent full pack")
Equal(addon:GetEditingEnvironment(), "SOLO", "Solo mode isolates the editor")
ok, state = addon:SetEditingEnvironment("RAID")
Check(not ok and state == "env", "inactive Multiple packs cannot be edited in Solo mode")

ok, state = addon:SetEnvironmentMode("multiple")
Check(ok, "Multiple mode can be restored")
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "Multiple resumes detected routing")
Equal(addon:GetEditingEnvironment(), "OPEN_WORLD", "Multiple restores its prior editor")

local appliedBeforeEditing = addon:GetAppliedEnvironment()
ok, state = addon:SetEditingEnvironment("RAID")
Check(ok, "editing environment remains selectable")
Equal(addon:GetAppliedEnvironment(), appliedBeforeEditing, "editing environment never selects runtime")
db.char.editingEnvironment = "OPEN_WORLD"

db.profile.routingMode = "INVALID"
Equal(addon:GetEnvironmentMode(), "multiple", "invalid mode normalizes to Multiple behavior")
Equal(db.profile.routingMode, "INVALID", "read normalization does not rewrite invalid saved mode")
db.profile.routingMode = "solo"
instanceReady = false
timerQueue = {}
addon.appliedEnvironment = "OPEN_WORLD"
ok, state = addon:ApplyResolvedEnvironment("solo-unready")
Check(ok and state == "applied", "Solo applies while detected instance data is unavailable")
Equal(addon:GetAppliedEnvironment(), "SOLO", "unready detection cannot block Solo")
Equal(#timerQueue, 1, "Solo retains bounded detected-context diagnostic retry")
instanceReady = true
table.remove(timerQueue, 1)()
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.detectedEnvironment, "DUNGEON", "Solo diagnostic retry converges detected context")
Equal(environmentStatus.appliedEnvironment, "SOLO", "diagnostic retry does not replace Solo runtime")

combat = true
ok, state = addon:SetEnvironmentMode("multiple")
Check(not ok and state == "combat", "mode mutation declines before storage changes in combat")
Equal(addon:GetEnvironmentMode(), "solo", "combat decline preserves stored Solo mode")
Equal(addon:GetAppliedEnvironment(), "SOLO", "combat keeps Solo applied")
Equal(addon:GetEnvironmentProfileStatus().pendingEnvironment, nil, "combat decline creates no partial pending target")
combat = false
ok, state = addon:SetEnvironmentMode("multiple")
Check(ok and state == "applied", "mode mutation applies after combat")
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "pending Multiple environment reconciles after combat")

db.profile.routingMode = nil
addon:ApplyResolvedEnvironment("legacy-multiple-restore")
Equal(addon:GetAppliedEnvironment(), "DUNGEON", "nil mode uses Multiple detected target")

db.char.editingEnvironment = "STALE_UNKNOWN_KEY"
local staleEditing = db.char.editingEnvironment
environmentStatus = addon:GetEnvironmentProfileStatus()
Equal(environmentStatus.editingEnvironment, "unknown", "stale editor key reports unknown")
Equal(addon:GetEditingEnvironment(), "RAID", "stale active editor restores the saved Multiple editor")
Equal(db.char.editingEnvironment, "RAID", "editor normalization repairs the stale active key")
db.char.editingEnvironment = "OPEN_WORLD"

instanceType = "future-instance"
local appliedBeforeUnknown = addon:GetAppliedEnvironment()
ok, state = addon:ApplyResolvedEnvironment("unknown")
Check(not ok and state == "unknown", "unknown context does not apply guessed environment")
Equal(addon:GetAppliedEnvironment(), appliedBeforeUnknown, "unknown context retains last applied environment")
instanceType = "none"

local obsoleteOpenWorld = ns.MakePack("DUNGEON")
obsoleteOpenWorld.mufs.dimOutOfRange = true
db.profile.environments.OPEN_WORLD = obsoleteOpenWorld
for _, row in ipairs(ns.ENVIRONMENTS) do
  db.profile.environments[row.key].colors.dead = {0.18, 0.18, 0.18, 1}
  db.profile.environments[row.key].mufs.maxUnits = 80
  db.profile.environments[row.key].colors.range = {0.08, 0.08, 0.10, 0.70}
  db.profile.environments[row.key].mufs.dimAmount = 0.60
end
db.profile.environments.RAID.colors.dead = {0.25, 0.10, 0.30, 0.80}
db.profile.environments.PVP.mufs.maxUnits = 37
db.profile.environments.RAID.colors.range = {0.22, 0.33, 0.44, 0.70}
db.profile.environments.PVP.colors.range = {0.08, 0.08, 0.10, 0.25}
db.profile.environments.MYTHIC_PLUS.mufs.dimAmount = 0.55
db.profile.appearanceSchema = nil
addon:EnsureEnvironments()
Equal(db.profile.environments.OPEN_WORLD.mufs.dimOutOfRange, true, "known obsolete Open World range default migrates through current defaults")
Equal(db.profile.appearanceSchema, 9, "appearance migration is versioned")
Equal(db.profile.environments.DUNGEON.colors.dead[1], 0, "old default death red migrates to black")
Equal(db.profile.environments.DUNGEON.colors.dead[4], 1, "migrated death color remains opaque")
Equal(db.profile.environments.RAID.colors.dead[1], 0.25, "custom death color is preserved exactly")
Equal(db.profile.environments.RAID.colors.dead[4], 0.80, "custom death alpha is preserved exactly")
for _, env in ipairs({"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "SOLO"}) do
  Equal(db.profile.environments[env].mufs.maxUnits, 5, env .. " exact legacy display cap migrates")
end
Equal(db.profile.environments.RAID.mufs.maxUnits, 40, "Raid exact prior default migrates to full raid capacity")
Equal(db.profile.environments.PVP.mufs.maxUnits, 37, "custom display cap is preserved exactly")
CheckDefaultRange(db.profile.environments.OPEN_WORLD.colors.range, "schema-zero Open World legacy range sequencing")
CheckDefaultRange(db.profile.environments.DUNGEON.colors.range, "schema-zero Dungeon legacy range sequencing")
Equal(db.profile.environments.RAID.colors.range[4], 0.70, "custom range RGB is preserved exactly")
Equal(db.profile.environments.PVP.colors.range[4], 0.25, "custom range alpha is preserved when signature differs")
Equal(db.profile.environments.MYTHIC_PLUS.colors.range[4], 0.70, "custom range dim prevents ambiguous legacy migration")
Equal(db.profile.environments.MYTHIC_PLUS.colors.range[1], 0.08, "narrow old-alpha signature with custom dim preserves red")
local migratedDeath = db.profile.environments.DUNGEON.colors.dead
local migratedRange = db.profile.environments.DUNGEON.colors.range
addon:EnsureEnvironments()
Check(db.profile.environments.DUNGEON.colors.dead == migratedDeath, "death migration is idempotent")
Equal(db.profile.environments.DUNGEON.mufs.maxUnits, 5, "display-cap migration is idempotent")
Check(db.profile.environments.DUNGEON.colors.range == migratedRange, "range-default migration is idempotent")

local activeProfile = db.profile
local schemaFourEnvironments = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  schemaFourEnvironments[row.key].colors.range = {0.08, 0.08, 0.10, 1}
end
schemaFourEnvironments.DUNGEON.colors.range = {0.08, 0.08, 0.10, 0.70}
schemaFourEnvironments.DUNGEON.mufs.dimAmount = 0.60
schemaFourEnvironments.MYTHIC_PLUS.colors.range = {0.08, 0.08, 0.10, 0.70}
schemaFourEnvironments.MYTHIC_PLUS.mufs.dimAmount = 0.55
schemaFourEnvironments.RAID.colors.range = {0.20, 0.40, 0.60, 1}
schemaFourEnvironments.PVP.colors.range = {0.08, 0.08, 0.10, 0.25}
db.profile = {environments = schemaFourEnvironments, appearanceSchema = 4}
ok, state = addon:MigrateAppearanceDefaults(schemaFourEnvironments)
Check(ok, "schema-four migration succeeds")
Equal(state, 4, "schema-four migration changes exact prior colors and brightness across six packs")
CheckDefaultRange(schemaFourEnvironments.OPEN_WORLD.colors.range, "schema-four normalized legacy default")
CheckDefaultRange(schemaFourEnvironments.DUNGEON.colors.range, "schema-four narrow pre-normalized legacy default")
Equal(schemaFourEnvironments.MYTHIC_PLUS.colors.range[4], 0.70, "schema-four old-alpha custom dim is preserved")
Equal(schemaFourEnvironments.RAID.colors.range[1], 0.20, "schema-four custom RGB is preserved")
Equal(schemaFourEnvironments.PVP.colors.range[4], 0.25, "schema-four custom alpha is preserved")
Equal(db.profile.appearanceSchema, 9, "schema-four profile advances through schema nine")
ok, state = addon:MigrateAppearanceDefaults(schemaFourEnvironments)
Check(ok and state == 0, "schema-nine migration rerun is a no-op")
db.profile = activeProfile

local schemaFiveEnvironments = ns.MakeEnvironments()
local priorColors = ns.PREVIOUS_CURE_COLORS
for _, row in ipairs(ns.ENVIRONMENTS) do
  local pack = schemaFiveEnvironments[row.key]
  for _, key in ipairs(ns.CANONICAL_CURE_ORDER) do
    pack.colors[key] = Copy(priorColors[key])
  end
end
schemaFiveEnvironments.DUNGEON.colors.magic = nil
schemaFiveEnvironments.RAID.colors.magic = {0.11, 0.22, 0.33, 0.44}
schemaFiveEnvironments.PVP.colors.range = {0.31, 0.41, 0.59, 0.67}
local preservedDefaultOrder = schemaFiveEnvironments.OPEN_WORLD.cure.order
local customOrder = {"poison", "disease", "curse", "magic"}
schemaFiveEnvironments.SOLO.cure.order = customOrder
schemaFiveEnvironments.MYTHIC_PLUS.cure.order = nil
db.profile = {environments = schemaFiveEnvironments, appearanceSchema = 5}
ok, state = addon:MigrateAppearanceDefaults(schemaFiveEnvironments)
Check(ok and state == 12, "schema-five migration changes only missing and exact prior palette fields")
for _, env in ipairs({"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "PVP"}) do
  CheckCanonicalCureColors(schemaFiveEnvironments[env], env .. " prior palette migrates")
end
for _, key in ipairs(ns.CANONICAL_CURE_ORDER) do
  for channel = 1, 4 do
    Equal(schemaFiveEnvironments.SOLO.colors[key][channel], ns.CANONICAL_CURE_COLORS[key][channel], "Solo prior " .. key .. " migrates")
  end
end
Equal(schemaFiveEnvironments.RAID.colors.magic[1], 0.11, "custom Magic red is preserved")
Equal(schemaFiveEnvironments.RAID.colors.magic[4], 0.44, "custom Magic alpha is preserved")
for _, key in ipairs({"curse", "poison", "disease"}) do
  for channel = 1, 4 do
    Equal(schemaFiveEnvironments.RAID.colors[key][channel], ns.CANONICAL_CURE_COLORS[key][channel], "Raid noncustom " .. key .. " migrates")
  end
end
Check(schemaFiveEnvironments.OPEN_WORLD.cure.order == preservedDefaultOrder, "existing canonical cure order remains untouched")
Check(schemaFiveEnvironments.SOLO.cure.order == customOrder, "custom cure order remains untouched")
Equal(table.concat(schemaFiveEnvironments.MYTHIC_PLUS.cure.order, ","), "magic,curse,poison,disease", "missing cure order is restored")
Equal(schemaFiveEnvironments.PVP.colors.range[1], 0.31, "custom range red remains separate from cure migration")
Equal(schemaFiveEnvironments.PVP.colors.range[4], 0.67, "custom range alpha remains separate from cure migration")
Equal(db.profile.appearanceSchema, 9, "schema-five profile advances to schema nine")
local migratedMagic = schemaFiveEnvironments.DUNGEON.colors.magic
ok, state = addon:MigrateAppearanceDefaults(schemaFiveEnvironments)
Check(ok and state == 0, "canonical palette migration rerun is a no-op")
Check(schemaFiveEnvironments.DUNGEON.colors.magic == migratedMagic, "canonical palette migration is reference-idempotent")
Check(schemaFiveEnvironments.SOLO.cure.order == customOrder, "canonical palette rerun preserves custom order identity")
local schemaSevenEnvironments = ns.MakeEnvironments()
schemaSevenEnvironments.PVP.mufs.maxUnits = 5
db.profile = {environments = schemaSevenEnvironments, appearanceSchema = 7}
ok, state = addon:MigrateAppearanceDefaults(schemaSevenEnvironments)
Check(ok and state == 1, "schema-seven migration changes only the exact prior PvP display cap")
Equal(schemaSevenEnvironments.PVP.mufs.maxUnits, 40, "schema-seven PvP default migrates to battleground capacity")
Equal(db.profile.appearanceSchema, 9, "schema-seven profile advances to schema nine")
local migratedPvPCap = schemaSevenEnvironments.PVP.mufs.maxUnits
ok, state = addon:MigrateAppearanceDefaults(schemaSevenEnvironments)
Check(ok and state == 0, "schema-nine PvP display-cap migration rerun is a no-op")
Equal(schemaSevenEnvironments.PVP.mufs.maxUnits, migratedPvPCap, "PvP display-cap migration is idempotent")
local missingPalettePack = {}
Equal(ns.MigrateCanonicalCurePalette(missingPalettePack), 2, "missing color and cure tables restore as two bounded sections")
CheckCanonicalCureColors(missingPalettePack, "missing palette sections restore canonical defaults")
CheckDefaultRange(missingPalettePack.colors.range, "missing colors restore canonical range")
Equal(ns.MigrateCanonicalCurePalette(missingPalettePack), 0, "restored missing palette sections are idempotent")
db.profile = activeProfile

db.profile.appearanceSchema = nil
db.profile.environments.OPEN_WORLD.mufs.dimOutOfRange = true
db.profile.environments.OPEN_WORLD.colors.healthy = {0.1, 0.3, 0.1, 0.9}
addon:EnsureEnvironments()
Equal(db.profile.environments.OPEN_WORLD.mufs.dimOutOfRange, true, "custom appearance is not migrated")
db.profile.environments.OPEN_WORLD.colors.healthy = {0, 0.3, 0.1, 0.9}
db.profile.environments.OPEN_WORLD.mufs.dimOutOfRange = false

local ok, state = addon:CreateProfile(" Alpha ")
Check(ok and state == "created", "create profile succeeds")
Equal(db.current, "Alpha", "create activates profile")
Equal(db.global.accountProfile, "Alpha", "create updates active account scope")
Check(type(db.profile.environments.RAID) == "table", "create materializes all environments")
for _, row in ipairs(ns.ENVIRONMENTS) do
  CheckCooldownDefaults(db.profile.environments[row.key], row.key .. " new profile")
  CheckDefaultRange(db.profile.environments[row.key].colors.range, row.key .. " new profile range default")
  CheckCanonicalCureColors(db.profile.environments[row.key], row.key .. " new profile canonical palette")
end

ok, state = addon:CreateProfile("alpha")
Check(not ok and state == "exists", "profile names are case-insensitively unique")
ok, state = addon:CreateProfile(string.rep("x", 49))
Check(not ok and state == "invalid-name", "long profile name rejected")
ok, state = addon:CreateProfile("bad\nname")
Check(not ok and state == "invalid-name", "control character rejected")

db.profile.environments.DUNGEON.mufs.partySize = 37
db.profile.environments.DUNGEON.mufs.maxUnits = 9
db.profile.environments.DUNGEON.colors.range = {0.31, 0.41, 0.59, 1}
db.profile.routingMode = "solo"
db.profile.environments.SOLO.mufs.maxUnits = 13
db.profile.environments.PVP.alerts.dispelEnabled = true
db.profile.environments.PVP.alerts.sound = true
db.profile.environments.DUNGEON.alerts.cooldownOpacity = 0.45
db.profile.environments.DUNGEON.alerts.cooldownNumbers = false
db.profile.environments.DUNGEON.cure.bandageMode = "SELECTED"
db.profile.environments.DUNGEON.cure.bandageItemID = 239713
db.profile.environments.DUNGEON.cure.clickBindings.button5 = "BANDAGE"
ok, state = addon:CopyProfile("Beta")
Check(ok and state == "copied", "copy profile succeeds")
Equal(db.current, "Beta", "copy activates destination")
Equal(db.profile.environments.DUNGEON.alerts.cooldownOpacity, 0.45, "profile copy retains custom darkness")
Equal(db.profile.environments.DUNGEON.alerts.cooldownNumbers, false, "profile copy retains countdown preference")
Equal(db.profile.environments.DUNGEON.cure.bandageItemID, 239713, "profile copy retains selected bandage")
Equal(db.profile.environments.DUNGEON.cure.clickBindings.button5, "BANDAGE", "profile copy retains bandage click")
Equal(db.global.accountProfile, "Beta", "copy updates active scope")
Equal(db.profile.environments.DUNGEON.mufs.partySize, 37, "copy preserves environment data")
Equal(db.profile.environments.DUNGEON.mufs.maxUnits, 9, "copy preserves custom display cap")
Equal(db.profile.environments.DUNGEON.colors.range[1], 0.31, "profile copy preserves custom range color")
Equal(db.profile.routingMode, "solo", "profile copy preserves Solo mode")
Equal(db.profile.environments.SOLO.mufs.maxUnits, 13, "profile copy preserves Solo pack")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, true, "profile copy preserves customized PvP landing text")
Equal(db.profile.environments.PVP.alerts.sound, true, "profile copy preserves customized PvP sound")
Check(db.profiles.Alpha.environments ~= db.profiles.Beta.environments, "copy owns distinct environment tables")
Check(db.profiles.Alpha.environments.DUNGEON.colors.range ~= db.profiles.Beta.environments.DUNGEON.colors.range, "profile copy owns a distinct range color")
Check(addon:GetAppliedEnvironmentPack() == db.profile.environments.SOLO, "profile copy reconciles its Solo applied environment")

db.profiles.Alpha.routingMode = "multiple"
db:SetProfile("Alpha")
addon:OnAceProfileUIChanged()
Equal(addon:GetAppliedEnvironment(), "OPEN_WORLD", "Ace profile switch reconciles source Multiple routing")
db:SetProfile("Beta")
addon:OnAceProfileUIChanged()
Equal(addon:GetAppliedEnvironment(), "SOLO", "Ace profile switch reconciles destination Solo mode")
Equal(db.profile.environments.DUNGEON.alerts.cooldownOpacity, 0.45, "profile switch retains custom darkness")
Equal(db.profile.environments.DUNGEON.alerts.cooldownNumbers, false, "profile switch retains countdown preference")
Equal(db.profile.environments.DUNGEON.cure.bandageMode, "SELECTED", "profile switch retains manual bandage selection")
Equal(db.profile.environments.DUNGEON.cure.bandageItemID, 239713, "profile switch retains selected bandage")

ok, state = addon:ResetCurrentProfile()
Check(ok, "current profile reset succeeds")
for _, row in ipairs(ns.ENVIRONMENTS) do
  CheckCooldownDefaults(db.profile.environments[row.key], row.key .. " profile reset")
  Equal(db.profile.environments[row.key].cure.bandageMode, "AUTO", row.key .. " reset bandage selection")
  Equal(db.profile.environments[row.key].cure.bandageItemID, 0, row.key .. " reset bandage item")
  Equal(db.profile.environments[row.key].cure.clickBindings.button5, nil, row.key .. " reset bandage binding")
end
Equal(db.profile.routingMode, "multiple", "current profile reset restores Multiple mode")
Equal(db.profile.environmentModeSchema, 1, "current profile reset stamps the mode schema")
Equal(db.profile.pvpAlertDefaultsSchema, 1, "current profile reset stamps the PvP alert schema")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, false, "current profile reset restores quiet PvP landing text")
Equal(db.profile.environments.PVP.alerts.sound, false, "current profile reset restores quiet PvP sound")
Equal(db.profile.environments.SOLO.alerts.dispelEnabled, true, "current profile reset keeps Solo landing text independent")
Equal(db.profile.environments.SOLO.alerts.sound, true, "current profile reset keeps Solo sound independent")
Equal(addon:GetAppliedEnvironment(), "OPEN_WORLD", "current profile reset immediately reconciles Multiple runtime")

ok, state = addon:SetEditingEnvironment("DUNGEON")
Check(ok, "Dungeon editor can be selected after reset")
ok, state = addon:ResetEditingPack()
Check(ok, "environment reset succeeds")
CheckCooldownDefaults(db.profile.environments.DUNGEON, "environment reset")
Equal(db.profile.environments.DUNGEON.mufs.maxUnits, 5, "environment reset restores display cap five")
CheckDefaultRange(db.profile.environments.DUNGEON.colors.range, "environment reset restores range default")
CheckCanonicalCureColors(db.profile.environments.DUNGEON, "environment reset restores canonical palette")
db.profile.environments.DUNGEON.mufs.maxUnits = 9
local soloDispelBeforePvPCopy = db.profile.environments.SOLO.alerts.dispelEnabled
db.profile.environments.DUNGEON.cure.bandageMode = "SELECTED"
db.profile.environments.DUNGEON.cure.bandageItemID = 239711
local soloSoundBeforePvPCopy = db.profile.environments.SOLO.alerts.sound
ok, state = addon:CopyEditingPackTo("PVP")
Check(ok, "environment copy succeeds")
Equal(db.profile.environments.PVP.cure.bandageMode, "SELECTED", "environment copy retains bandage selection")
Equal(db.profile.environments.PVP.cure.bandageItemID, 239711, "environment copy retains bandage item")
Equal(db.profile.environments.PVP.mufs.maxUnits, 9, "environment copy preserves display cap")
CheckDefaultRange(db.profile.environments.PVP.colors.range, "environment copy preserves range color")
CheckCanonicalCureColors(db.profile.environments.PVP, "environment copy preserves canonical palette")
Check(db.profile.environments.PVP.mufs ~= db.profile.environments.DUNGEON.mufs, "environment copy owns independent MUF settings")
Check(db.profile.environments.PVP.colors.range ~= db.profile.environments.DUNGEON.colors.range, "environment copy owns an independent range color")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, true, "environment copy preserves source landing text instead of reapplying PvP defaults")
Equal(db.profile.environments.PVP.alerts.sound, true, "environment copy preserves source sound instead of reapplying PvP defaults")
Equal(db.profile.environments.SOLO.alerts.dispelEnabled, soloDispelBeforePvPCopy, "PvP environment copy does not mutate Solo landing text")
Equal(db.profile.environments.SOLO.alerts.sound, soloSoundBeforePvPCopy, "PvP environment copy does not mutate Solo sound")
ok, state = addon:SetEditingEnvironment("PVP")
Check(ok, "PvP editor can be selected after copy")
ok, state = addon:ResetEditingPack()
Check(ok, "PvP environment reset succeeds")
CheckCooldownDefaults(db.profile.environments.PVP, "PvP environment reset")
Equal(db.profile.environments.PVP.cure.bandageMode, "AUTO", "PvP reset restores automatic bandage selection")
Equal(db.profile.environments.PVP.cure.bandageItemID, 0, "PvP reset clears pinned bandage")
Equal(db.profile.environments.PVP.alerts.dispelEnabled, false, "PvP environment reset restores quiet landing text")
Equal(db.profile.environments.PVP.alerts.sound, false, "PvP environment reset restores quiet sound")
Equal(db.profile.environments.PVP.mufs.maxUnits, 40, "PvP environment reset restores battleground capacity")
Equal(db.profile.environments.PVP.alerts.soulLinkAlert, true, "PvP environment reset leaves Soul Link warning enabled")
Equal(db.profile.environments.PVP.alerts.successfulDispelText, false, "PvP environment reset leaves success text disabled")
Equal(db.profile.environments.SOLO.alerts.dispelEnabled, soloDispelBeforePvPCopy, "PvP environment reset does not mutate Solo landing text")
Equal(db.profile.environments.SOLO.alerts.sound, soloSoundBeforePvPCopy, "PvP environment reset does not mutate Solo sound")
db.char.editingEnvironment = "OPEN_WORLD"
db.char.multipleEditingEnvironment = "OPEN_WORLD"

ok, state = addon:SetCharacterProfileAssignment("Alpha")
Check(ok, "character assignment succeeds")
Equal(db.current, "Alpha", "character assignment applies runtime")
ok, state = addon:ActivateProfile("Beta")
Check(ok, "activate character profile succeeds")
Equal(db.global.characters[addon:GetCharacterKey()], "Beta", "activation updates existing character scope")

ok, state = addon:SetSpecProfileAssignment(1, "Alpha")
Check(ok, "spec profile assignment succeeds")
ok, state = addon:SetSpecProfileAssignmentEnabled(1, true)
Check(ok, "spec assignment enable succeeds")
Equal(db.current, "Alpha", "enabled spec assignment applies runtime")
ok, state = addon:ActivateProfile("Beta")
Check(ok, "activate specialization profile succeeds")
local specRow = addon:GetSpecAssignment(1)
Equal(specRow.profile, "Beta", "activation updates enabled specialization scope")

local beforeProfile = db.current
local beforeSpec = specRow.profile
local beforeEditing = db.char.editingEnvironment
combat = true
ok, state = addon:ActivateProfile("Alpha")
Check(not ok and state == "combat", "activation rejected in combat")
Equal(db.current, beforeProfile, "combat rejection keeps runtime profile")
Equal(specRow.profile, beforeSpec, "combat rejection keeps assignment")
ok, state = addon:CreateProfile("CombatProfile")
Check(not ok and state == "combat" and db.profiles.CombatProfile == nil, "creation rejected in combat")
ok, state = addon:SetEditingEnvironment("RAID")
Check(not ok and state == "combat", "environment preview switch rejected in combat")
Equal(db.char.editingEnvironment, beforeEditing, "combat keeps editing environment")
db.global.specs[addon:GetCharacterKey()][1].profile = "Alpha"
addon.profileResolvePending = true
uiStatus = addon:GetUIProfileStatus()
Equal(uiStatus.actualProfile, beforeProfile, "combat status keeps actual applied profile")
Equal(uiStatus.resolvedProfile, "Alpha", "combat status exposes resolved target")
Equal(uiStatus.pendingProfile, "Alpha", "combat status exposes distinct pending target")
Equal(uiStatus.resolvedTier, "specialization", "combat status exposes pending source tier")
addon.profileResolvePending = nil
db.global.specs[addon:GetCharacterKey()][1].profile = beforeSpec
combat = false

db.global.schema = 4
uiStatus = addon:GetUIProfileStatus()
Check(not uiStatus.available and uiStatus.blockedReason == "forward-schema", "forward schema UI status fails closed")
ok, state = addon:ActivateProfile("Alpha")
Check(not ok and state == "forward-schema", "forward schema fails closed")
Equal(db.current, beforeProfile, "forward schema keeps runtime profile")
Equal(addon:ResolveProfileName(), "Beta", "forward schema remains readable")
db.global.schema = 3

local characters = db.global.characters
db.global.characters = "corrupt"
uiStatus = addon:GetUIProfileStatus()
Check(not uiStatus.available and uiStatus.blockedReason == "malformed-storage", "malformed UI status fails closed")
local resolvedOk, resolvedName = pcall(addon.ResolveProfileName, addon)
Check(resolvedOk and resolvedName == db.global.accountProfile, "corrupt character assignments fall through safely")
ok, state = addon:SetAccountProfileAssignment("Alpha")
Check(not ok and state == "malformed-storage", "malformed assignment storage fails closed")
db.global.characters = characters

local specs = db.global.specs
db.global.specs = "corrupt"
local specMap, specError = addon:EnsureSpecAssignments()
Check(specMap == nil and specError == "malformed-storage", "corrupt specialization storage is not rewritten")
resolvedOk, resolvedName = pcall(addon.ResolveProfileName, addon)
Check(resolvedOk and resolvedName == db.global.characters[addon:GetCharacterKey()], "corrupt spec assignments fall through safely")
db.global.specs = specs

local originalGetProfiles = db.GetProfiles
db.GetProfiles = function()
  return "corrupt"
end
local profileNames, profileError = addon:GetProfileNames()
Check(#profileNames == 0 and profileError == "storage", "corrupt profile enumeration fails closed")
resolvedOk, resolvedName = pcall(addon.ResolveProfileName, addon)
Check(resolvedOk and resolvedName == "Default", "corrupt profile enumeration keeps menu resolution safe")
db.GetProfiles = originalGetProfiles

local originalGetCurrentProfile = db.GetCurrentProfile
db.GetCurrentProfile = function()
  error("corrupt current profile")
end
uiStatus = addon:GetUIProfileStatus()
Check(not uiStatus.available and uiStatus.actualProfile == nil, "throwing AceDB read does not leak a stale profile")
local currentName, currentError = addon:GetCurrentProfileName()
Check(currentName == "Default" and currentError == "storage", "corrupt current profile read fails closed")
resolvedOk, state = pcall(addon.ActivateProfile, addon, "Alpha")
Check(resolvedOk and state == false, "corrupt current profile does not escape the transaction boundary")
db.GetCurrentProfile = originalGetCurrentProfile

local refreshed = 0
ns.RefreshOptions = function()
  refreshed = refreshed + 1
end
local generationBeforeCallback = addon.profileChangeGeneration or 0
db.current = "Alpha"
addon:OnAceProfileUIChanged()
Equal(refreshed, 1, "AceDB profile callback refreshes Options")
Equal(addon.profileChangeGeneration, generationBeforeCallback + 1, "AceDB profile callback advances generation")
db.current = beforeProfile
addon:OnAceProfileUIChanged()

local originalEnsure = addon.EnsureEnvironments
addon.EnsureEnvironments = function(self)
  if self.db:GetCurrentProfile() == "Broken" then
    error("injected materialization failure")
  end
  return originalEnsure(self)
end
local rollbackProfile = db.current
local rollbackSpec = addon:GetSpecAssignment(1).profile
ok, state = addon:CreateProfile("Broken")
Check(not ok and state == "transaction", "failed creation reports transaction")
Equal(db.current, rollbackProfile, "failed creation restores runtime profile")
Equal(addon:GetSpecAssignment(1).profile, rollbackSpec, "failed creation restores assignment")
Check(db.profiles.Broken == nil, "failed creation removes partial profile")
addon.EnsureEnvironments = originalEnsure

local function LogicalStorage()
  return {
    profiles = Copy(db.profiles),
    global = Copy(db.global),
    char = Copy(db.char),
    profileKeys = Copy(db.profileKeys),
    current = db.current,
    applied = addon.appliedEnvironment,
  }
end

local function CheckRestored(before, message)
  Check(DeepEqual(LogicalStorage(), before), message)
end

local originalEngine = ns.DetectionEngine
ns.DetectionEngine = {
  Refresh = function()
    return false, "FAILURE"
  end,
}
local beforeTransaction = LogicalStorage()
ok, state = addon:ResetEditingPack()
Check(not ok and state == "FAILURE", "pack reset runtime failure rejects transaction")
CheckRestored(beforeTransaction, "pack reset restores exact logical storage")

beforeTransaction = LogicalStorage()
ok, state = addon:CopyEditingPackTo("PVP")
Check(not ok and state == "FAILURE", "pack copy runtime failure rejects transaction")
CheckRestored(beforeTransaction, "pack copy restores exact logical storage")

beforeTransaction = LogicalStorage()
ok, state = addon:ResetCurrentProfile()
Check(not ok and state == "FAILURE", "profile reset runtime failure rejects transaction")
CheckRestored(beforeTransaction, "profile reset restores all six packs, mode, orientation, lists, editor, and assignments")

beforeTransaction = LogicalStorage()
ok, state = addon:ResetAllSettings()
Check(not ok and state == "FAILURE", "all-settings reset runtime failure rejects transaction")
CheckRestored(beforeTransaction, "all-settings reset restores exact logical database")

beforeTransaction = LogicalStorage()
ok, state = addon:RunProfileStorageTransaction("injected-exception", function()
  db.profile.routingMode = "solo"
  error("injected mutation exception")
end)
Check(not ok and state == "transaction", "mutation exception rejects transaction")
CheckRestored(beforeTransaction, "mutation exception restores exact logical storage")

ns.DetectionEngine.Refresh = function()
  return false, "DEFERRED_RESTRICTED"
end
beforeTransaction = LogicalStorage()
ok, state = addon:ResetEditingPack()
Check(not ok and state == "DEFERRED_RESTRICTED", "runtime defer rejects storage commit")
CheckRestored(beforeTransaction, "runtime defer restores exact logical storage")
ns.DetectionEngine = originalEngine

local originalAppearanceMigration = addon.MigrateAppearanceDefaults
addon.MigrateAppearanceDefaults = function()
  return false, "injected"
end
beforeTransaction = LogicalStorage()
ok, state = addon:EnsureEnvironments()
Check(not ok and state == "migration", "migration failure rejects partial environment materialization")
CheckRestored(beforeTransaction, "migration failure restores exact profile and editor state")
addon.MigrateAppearanceDefaults = originalAppearanceMigration

local originalPvPAlertMigration = addon.MigratePvPAlertDefaults
addon.MigratePvPAlertDefaults = function(self, environments)
  environments.PVP.alerts.sound = true
  return false, "injected"
end
beforeTransaction = LogicalStorage()
ok, state = addon:EnsureEnvironments()
Check(not ok and state == "migration", "PvP alert migration failure rejects partial environment mutation")
CheckRestored(beforeTransaction, "PvP alert migration failure restores exact profile and editor state")
addon.MigratePvPAlertDefaults = originalPvPAlertMigration

combat = true
beforeTransaction = LogicalStorage()
ok, state = addon:ResetAllSettings()
Check(not ok and state == "combat", "combat declines reset before storage mutation")
CheckRestored(beforeTransaction, "combat reset decline leaves storage untouched")
combat = false

ok, state = addon:RenameProfile("Gamma")
Check(ok and state == "renamed", "rename succeeds")
Equal(db.current, "Gamma", "rename keeps renamed profile active")
Check(db.profiles.Beta == nil and type(db.profiles.Gamma) == "table", "rename removes old storage after copy")
Equal(addon:GetSpecAssignment(1).profile, "Gamma", "rename retargets assignments")

ok, state = addon:ActivateProfile("Default")
Check(ok, "activate default succeeds")
ok, state = addon:RenameProfile("Factory")
Check(not ok and state == "default", "Default profile cannot be renamed")

ok, state = addon:ActivateProfile("Gamma")
Check(ok, "reactivate renamed profile")
ok, state = addon:DeleteCurrentProfile()
Check(ok and state == "deleted", "delete profile succeeds")
Equal(db.current, "Default", "delete activates Default")
Check(db.profiles.Gamma == nil, "delete removes profile storage")
Equal(addon:GetSpecAssignment(1).profile, "Default", "delete retargets assignments")

timerQueue = {}
local worldRefreshes = 0
local worldRecovers = 0
local worldDefers = 0
local rosterPreparations = 0
local worldEngine = {
  pending = false,
  refreshGeneration = 0,
}
function worldEngine:Refresh()
  if combat then
    return self:Defer("WORLD_TEST_COMBAT")
  end
  worldRefreshes = worldRefreshes + 1
  self.refreshGeneration = self.refreshGeneration + 1
  self.pending = false
  return true
end
function worldEngine:Defer()
  worldDefers = worldDefers + 1
  self.pending = true
  return false
end
function worldEngine:Recover()
  if combat or not self.pending then
    return false
  end
  worldRecovers = worldRecovers + 1
  self.pending = false
  self.refreshGeneration = self.refreshGeneration + 1
  return true
end
ns.DetectionEngine = worldEngine
ns.BuildRoster = function()
  return {"player"}
end
ns.GetRosterContextStatus = function()
  return {kind = "NO_PARTY", ready = true}
end
ns.ResetRosterForWorldTransition = function()
  return true
end
ns.ResetMUFsForWorldTransition = function()
  return not combat
end
ns.PrepareWorldEntryRoster = function()
  rosterPreparations = rosterPreparations + 1
  return not combat
end

addon:OnLeavingWorld()
Check(addon:OnEnteringWorld(), "unlocked world entry performs authoritative reconcile")
Equal(worldRefreshes, 1, "world entry commits one atomic full-world roster transaction")
Equal(rosterPreparations, 1, "world entry prepares authoritative roster")
addon:OnEnteringWorld()
Equal(worldRefreshes, 1, "duplicate world entry does not rebuild")
while #timerQueue > 0 do
  table.remove(timerQueue, 1)()
end

combat = true
addon:OnLeavingWorld()
Check(not addon:OnEnteringWorld(), "locked world entry remains deferred")
Check(worldEngine.pending and worldDefers > 0, "locked world entry preserves pending engine state")
combat = false
Check(addon:OnRegenEnabled(), "deferred world entry converges on later regen")
Equal(worldRecovers, 0, "full-world recovery uses the canonical roster refresh instead of stale engine recovery")
Check(not addon:OnRegenEnabled(), "repeated regen is idempotent after the atomic candidate commit")
Equal(worldRecovers, 0, "repeated regen does not invoke stale engine recovery")
Equal(#timerQueue, 16, "locked world entry arms independent full-world and roster samples")
while #timerQueue > 0 do
  table.remove(timerQueue, 1)()
end
Check(worldRefreshes >= 2, "stale full-world cadence cannot undo the committed regen transaction")

combat = true
addon:OnLeavingWorld()
Check(not addon:OnEnteringWorld(), "mid-combat world exit defers the destination reconcile")
Equal(#timerQueue, 16, "mid-combat world exit arms independent full-world and roster convergence")
combat = false
while #timerQueue > 0 do
  table.remove(timerQueue, 1)()
end
Check(worldRefreshes >= 2, "bounded retries reconcile when zoning clears combat without a regen event")
Check(not worldEngine.pending and addon.worldEntryRecoveryPending ~= true, "no-regen world retry clears both engine and Core pending state")
Check(addon.worldEntryRecoveryRetryCount <= 1 and addon.worldEntryRecoveryRetryPending ~= true, "no-regen recovery uses bounded event-free sampling")

combat = true
addon:OnLeavingWorld()
Check(not addon:OnEnteringWorld(), "stale transition schedules a retry")
local staleWorldRetries = timerQueue
timerQueue = {}
addon:OnLeavingWorld()
for i = 1, #staleWorldRetries do
  staleWorldRetries[i]()
end
Equal(#timerQueue, 0, "old transition token cannot schedule or reconcile the new world")
combat = false
Check(addon:OnEnteringWorld(), "current transition still reconciles authoritatively")

io.write("profile-transaction: ok\n")
