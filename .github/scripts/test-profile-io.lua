if arg and arg[1] == "--self-test-failure" then
	error("intentional profile IO harness failure", 0)
end

strmatch = string.match
assert(loadfile("Decursive/Libs/LibStub/LibStub.lua"))()
assert(loadfile("Decursive/Libs/AceSerializer-3.0/AceSerializer-3.0.lua"))()

InCombatLockdown = function() return false end
GetBuildInfo = function() return "12.1.0", "120100", "Aug 31 2026", 120100 end

local Serializer = assert(LibStub("AceSerializer-3.0"))
local environments = { "OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP" }

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
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = { "table:" .. seen.count }
	for _, key in ipairs(keys) do
		parts[#parts + 1] = snapshot(key, seen) .. "=" .. snapshot(value[key], seen)
	end
	return table.concat(parts, "|")
end

local defaults = {
	profile = {
		Scan_Pets = true,
		ShowDebuffsFrame = true,
		DebuffsFrameRefreshRate = 0.1,
		MF_colors = { { 0.8, 0, 0, 1 }, { 0, 0.4, 0.8, 1 }, { 1, 0.5, 0, 1 } },
		ClassSettings = {},
		CureBindingMode = "AUTO",
		CureBindingManual = {},
		MouseButtons = {},
	},
}

local variants = {}
for index, environment in ipairs(environments) do
	variants[environment] = clone(defaults.profile)
	variants[environment].Scan_Pets = index % 2 == 0
	variants[environment].DebuffsFrameRefreshRate = index / 100
end

local manager = {
	ENVIRONMENT_ORDER = environments,
	activationMode = "AUTO",
	failImport = false,
}

function manager:IsReadOnly()
	return false
end

function manager:ResolveActiveProfileID()
	return "default"
end

function manager:GetProfileName()
	return "Default"
end

function manager:GetEditEnvironment()
	return "OPEN_WORLD"
end

function manager:ExportLogicalProfile()
	return { activationMode = self.activationMode, variants = clone(variants) }
end

function manager:ImportLogicalProfile(_, candidates, activationMode)
	if self.failImport then return false, "injected manager failure" end
	for _, environment in ipairs(environments) do variants[environment] = clone(candidates[environment]) end
	self.activationMode = activationMode
	return true
end

local D = {
	defaults = defaults,
	db = { profile = variants.OPEN_WORLD },
	ProfileManager = manager,
	version = "v12.1.4-alpha.4-test",
	configurationResult = true,
}

function D.db:GetCurrentProfile()
	return "Default"
end

function D:SetConfiguration()
	return self.configurationResult
end

local T = { Dcr = D }
assert(loadfile("Decursive/Dcr_ProfileIO.lua"))("Decursive", T)

local function stateSnapshot()
	return snapshot({ variants = variants, active = D.db.profile })
end

local function assertRejected(text, label, expectedStatus)
	local before = stateSnapshot()
	assert(D:ImportProfileString(text) == false, label .. " unexpectedly imported")
	assert(stateSnapshot() == before, label .. " changed profile state")
	if expectedStatus then
		assert(D:GetProfileIOStatus():lower():find(expectedStatus, 1, true), label .. " returned the wrong status")
	end
end

local function payload(scope)
	local result = {
		format = "DECursiveProfile",
		version = 2,
		addon = "Decursive",
		addonVersion = "test",
		interface = 120100,
		scope = scope or "environment",
	}
	if result.scope == "logical" then
		result.activationMode = "AUTO"
		result.variants = clone(variants)
	else
		result.profile = clone(variants.OPEN_WORLD)
	end
	return result
end

local logicalExport = assert(D:GetProfileExportString("logical"))
local logicalBefore = clone(variants)
for _, environment in ipairs(environments) do variants[environment].Scan_Pets = nil end
assert(D:ImportProfileString(logicalExport) == true)
assert(snapshot(variants) == snapshot(logicalBefore), "logical round trip did not restore all five environments")

D.db.profile = variants.OPEN_WORLD
local environmentExport = assert(D:GetProfileExportString("environment"))
local environmentBefore = snapshot(D.db.profile)
D.db.profile.Scan_Pets = not D.db.profile.Scan_Pets
assert(D:ImportProfileString(environmentExport) == true)
assert(snapshot(D.db.profile) == environmentBefore, "single-environment round trip did not restore the profile")

assertRejected(string.rep("x", 1024 * 1024 + 1), "oversized wire input", "too large")
assertRejected(Serializer:Serialize(payload()):sub(1, -3), "truncated input", "incomplete")
assertRejected("^2^T^t^^", "invalid header", "invalid serializer header")
assertRejected("^1^T^t^t^^", "unmatched table marker", "more than one root")
assertRejected("^1^T^t^Ssecond^^", "multiple roots", "more than one root")
assertRejected(Serializer:Serialize("not a table"), "non-table root", "root must be a table")

local future = payload()
future.version = 3
assertRejected(Serializer:Serialize(future), "future format", "not a supported")

local oversizedString = payload()
oversizedString.extra = string.rep("x", 4097)
assertRejected(Serializer:Serialize(oversizedString), "oversized decoded string", "oversized string")

local oversizedKey = payload()
oversizedKey[string.rep("k", 257)] = true
assertRejected(Serializer:Serialize(oversizedKey), "oversized decoded key", "invalid table key")

local deeplyNested = payload()
local cursor = deeplyNested
for _ = 1, 17 do
	cursor.child = {}
	cursor = cursor.child
end
assertRejected(Serializer:Serialize(deeplyNested), "deeply nested input", "nested too deeply")

local validWire = "^1^T^t^^"
local originalDeserialize = Serializer.Deserialize

local function rejectDecoded(label, decoded, expectedStatus)
	Serializer.Deserialize = function() return true, decoded end
	local ok, failure = pcall(assertRejected, validWire, label, expectedStatus)
	Serializer.Deserialize = originalDeserialize
	assert(ok, failure)
end

local cyclic = payload()
cyclic.loop = cyclic
rejectDecoded("cyclic decoded graph", cyclic, "cyclic or shared")

local shared = {}
local sharedPayload = payload()
sharedPayload.first = shared
sharedPayload.second = shared
rejectDecoded("shared decoded graph", sharedPayload, "cyclic or shared")

local manyNodes = payload()
manyNodes.values = {}
for index = 1, 100001 do manyNodes.values[index] = false end
rejectDecoded("decoded node limit", manyNodes, "too many values")

Serializer.Deserialize = function() error("injected serializer exception", 0) end
local deserializeOK, deserializeFailure = pcall(assertRejected, validWire, "serializer exception", "invalid serialized data")
Serializer.Deserialize = originalDeserialize
assert(deserializeOK, deserializeFailure)

local managerFailureText = Serializer:Serialize(payload("logical"))
manager.failImport = true
assertRejected(managerFailureText, "manager transaction failure", "no environment profiles were changed")
manager.failImport = false

local rollbackText = Serializer:Serialize(payload("environment"))
local rollbackBefore = stateSnapshot()
local configurationCalls = 0
function D:SetConfiguration()
	configurationCalls = configurationCalls + 1
	return configurationCalls > 1
end
assert(D:ImportProfileString(rollbackText) == false, "configuration failure unexpectedly imported")
assert(configurationCalls == 2, "single-environment rollback did not reconfigure twice")
assert(stateSnapshot() == rollbackBefore, "single-environment rollback did not restore exact state")

io.write("PASS: serialized ProfileIO adversarial and rollback harness\n")
