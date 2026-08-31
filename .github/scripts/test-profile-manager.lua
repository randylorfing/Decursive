local inCombat = false
UnitFullName = function() return "Tester", "Test Realm" end
UnitName = function() return "Tester" end
UnitClass = function() return "Priest", "PRIEST" end
GetRealmName = function() return "Test Realm" end
GetNormalizedRealmName = GetRealmName
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 256 end
InCombatLockdown = function() return inCombat end
IsInInstance = function() return false, "none" end
C_ChallengeMode = { GetActiveChallengeMapID = function() return nil end }

local defaults = {
	global = { debug = false },
	class = { CureOrder = { 1, 2 }, UserSpells = {} },
	profile = {
		ClassSettings = {}, Scan_Pets = true, ShowDebuffsFrame = true,
		MF_colors = { { 0.8, 0, 0 }, { 0, 0.8, 0 } },
		CureBindingMode = "AUTO", CureBindingManual = {},
		MouseButtons = { "*%s1", "*%s2", "ctrl-%s1", "ctrl-%s2", "shift-%s1", "shift-%s2", "shift-%s3", "alt-%s1", "alt-%s2", "alt-%s3", "*%s4", "ctrl-%s4", "shift-%s4", "alt-%s4", "*%s5", "ctrl-%s5", "shift-%s5", "alt-%s5", "*%s3", "ctrl-%s3" },
		Environment121Profiles = {
			OPEN_WORLD = { markerDefault = "open" }, DUNGEON = { markerDefault = "dungeon" },
			MYTHIC_PLUS = { markerDefault = "mythic" }, RAID = { markerDefault = "raid" },
			PVP = { markerDefault = "pvp" },
		},
	},
}

local function clone(value, copies)
	if type(value) ~= "table" then return value end
	copies = copies or {}
	if copies[value] then return copies[value] end
	local result = {}
	copies[value] = result
	for key, child in pairs(value) do result[clone(key, copies)] = clone(child, copies) end
	return result
end

local function snapshot(value, seen)
	if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
	seen = seen or { count = 0 }
	if seen[value] then return "ref:" .. seen[value] end
	seen.count = seen.count + 1
	seen[value] = seen.count
	local parts = { "table:" .. seen.count }
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, key in ipairs(keys) do parts[#parts + 1] = snapshot(key, seen) .. "=" .. snapshot(value[key], seen) end
	return table.concat(parts, "|")
end

local function loadManager(saved)
	local D = { defaults = defaults, NotifyConfigurationChanged = function() end }
	local T = { Dcr = D, _LoadedFiles = {} }
	assert(loadfile("Decursive/Dcr_ProfileManager.lua"))("Decursive", T)
	local manager = assert(T.ProfileManager)
	local key, err = manager:InitializeStorage(saved)
	return manager, D, key, err
end

local classes = { "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local function destructiveFixture(schema)
	local saved = {
		global = { oldGlobal = true }, char = { oldChar = true }, realm = { oldRealm = true },
		locale = { oldLocale = true }, profileKeys = { ["Tester - Test Realm"] = "Healer", ["Alt - Realm"] = "Raid" },
		profiles = { Healer = { oldProfile = true }, Raid = { oldProfile = true }, ["DCRPM:alias"] = { oldAlias = true } },
		namespaces = { ["LibDualSpec-1.0"] = { char = { legacy = true } } },
		profileManager = { schemaVersion = schema, migration = { old = true }, variantScopeVersions = { old = 1 }, aliases = { old = true } },
		unknownLegacyMarker = { survive = false }, class = {},
	}
	for index, classToken in ipairs(classes) do
		saved.class[classToken] = { CureOrder = { index }, ["CureOrder-1"] = { index + 1 }, UserSpells = { [100000 + index] = { legacy = classToken } } }
	end
	return saved
end

local function assertCleanReset(saved, label)
	local manager, _, key, err = loadManager(saved)
	assert(not err and key, label .. ": reset failed")
	assert(saved.profileManager.schemaVersion == 6)
	assert(saved.profileManager.reset.completed == true and saved.profileManager.reset.schemaVersion == 6)
	assert(saved.profileManager.migration == nil and saved.profileManager.variantScopeVersions == nil)
	assert(#saved.profileManager.profileOrder == 1 and saved.profileManager.profileOrder[1] == "default")
	assert(next(saved.profileManager.selection.characters) == nil)
	for topKey in pairs(saved) do
		assert(topKey == "profiles" or topKey == "profileKeys" or topKey == "profileManager", label .. ": survived " .. tostring(topKey))
	end
	local seen, count = {}, 0
	for _, environment in ipairs(manager.ENVIRONMENT_ORDER) do
		local storageKey = assert(manager:GetAceKey("default", environment))
		assert(not seen[storageKey])
		seen[storageKey] = true
		local variant = assert(saved.profiles[storageKey])
		assert(variant.oldProfile == nil and next(variant.ClassSettings.PRIEST.UserSpells) == nil)
		count = count + 1
	end
	local storedCount = 0
	for _ in pairs(saved.profiles) do storedCount = storedCount + 1 end
	assert(count == 5 and storedCount == 5)
	return manager
end

assertCleanReset({}, "nil/empty")
assertCleanReset({ profileManager = "malformed", profiles = { bad = true }, arbitrary = true }, "malformed")
assertCleanReset(destructiveFixture(2), "schema 2 thirteen-class")
assertCleanReset(destructiveFixture(4), "schema 4")
assertCleanReset(destructiveFixture(5), "schema 5")

local saved = destructiveFixture(5)
local manager = assertCleanReset(saved, "upgrade")
local identities = {}
for index, environment in ipairs(manager.ENVIRONMENT_ORDER) do
	local key = manager:GetAceKey("default", environment)
	identities[environment] = saved.profiles[key]
	saved.profiles[key].divergent = index
	saved.profiles[key].MF_colors[1][1] = index / 10
end
local reloaded = loadManager(saved)
for index, environment in ipairs(reloaded.ENVIRONMENT_ORDER) do
	local variant = saved.profiles[reloaded:GetAceKey("default", environment)]
	assert(variant == identities[environment] and variant.divergent == index and variant.MF_colors[1][1] == index / 10)
end
local restarted = loadManager(saved)
for index, environment in ipairs(restarted.ENVIRONMENT_ORDER) do
	assert(saved.profiles[restarted:GetAceKey("default", environment)].divergent == index)
end

local currentProfile = saved.profileKeys["Tester - Test Realm"]
local D
manager, D = loadManager(saved)
local db = { sv = saved, profile = saved.profiles[currentProfile] }
function db.RegisterCallback() end
function db:GetCurrentProfile() return currentProfile end
function db:SetProfile(key) currentProfile = key self.profile = saved.profiles[key] D.profile = self.profile end
assert(manager:BindDatabase(db))
local copyID = assert(manager:CreateProfile("Copy", "default"))
saved.profiles[manager:GetAceKey("default", "RAID")].sourceOnly = 42
assert(manager:CopyEnvironment(copyID, "PVP", "default", "RAID"))
assert(saved.profiles[manager:GetAceKey(copyID, "PVP")].sourceOnly == 42)
assert(manager:ResetEnvironment(copyID, "PVP"))
assert(saved.profiles[manager:GetAceKey(copyID, "PVP")].sourceOnly == nil)
local exported = assert(manager:ExportLogicalProfile("default"))
exported.variants.OPEN_WORLD.ioMarker = true
assert(manager:ImportLogicalProfile(copyID, exported.variants, "AUTO"))
assert(saved.profiles[manager:GetAceKey(copyID, "OPEN_WORLD")].ioMarker == true)
exported.variants.RAID = nil
assert(not manager:ImportLogicalProfile(copyID, exported.variants, "AUTO"))
assert(manager:DeleteProfile(copyID) and #manager:GetCatalog() == 1)

local future = destructiveFixture(7)
future.profileManager.opaque = { nested = { 1, 2, 3 } }
local before = snapshot(future)
local futureManager, _, futureKey, futureError = loadManager(future)
assert(futureKey == nil and futureError == "future-schema" and futureManager:IsReadOnly())
assert(not futureManager:SetEnvironmentMode("RAID"))
assert(not futureManager:CreateProfile("Blocked"))
assert(not futureManager:ResetProfile("default"))
assert(futureManager:HandleCombatEnded() == false)
assert(snapshot(future) == before, "future schema changed")

local initSource = assert(readfile("Decursive/DCR_init.lua"))
assert(initSource:find('profileManager:IsFutureStorage'))
assert(initSource:find('SetEnabledState%(false%)'))
assert(initSource:find('D%.ProfileSchemaIncompatible'))
assert(initSource:find('profileManager:IsFutureStorage') < initSource:find('D:SetSpellsTranslations'))
assert(initSource:find('profileManager:IsFutureStorage') < initSource:find('AceDB%-3%.0'))

if arg and arg[1] == "--self-test-failure" then error("intentional profile-manager harness failure") end
io.write("PASS: schema-6 reset, thirteen-class destruction, five fresh variants, reload/restart, copy/reset/IO, malformed input, and future immutability\n")
