--[[
    This file is part of Decursive.

    Logical profile and full environment-variant manager. This file was solely
    written by Randy Lorfing.
    Copyright (C) 2026 Randy Lorfing

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive. If not, see <https://www.gnu.org/licenses/>.

    A user-visible logical profile owns five complete AceDB profiles. AceDB's
    active profile is always the effective runtime variant or the explicit
    out-of-combat edit preview. Existing option code therefore reads and writes
    the selected environment without a setting allow-list.
--]]

local addonName, T = ...
local D = T and T.Dcr
if not D then return end

local Manager = {
	SCHEMA_VERSION = 4,
	DEFAULT_PROFILE_ID = "default",
	MAX_PROFILES = 50,
	MAX_PROFILE_NAME_BYTES = 48,
	MAX_PROFILE_SERIAL = 1000000,
	ENVIRONMENT_ORDER = { "OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP" },
	ENVIRONMENT_NAMES = {
		OPEN_WORLD = "Open World",
		DUNGEON = "Party / Dungeon",
		MYTHIC_PLUS = "Mythic+",
		RAID = "Raid",
		PVP = "PvP",
	},
	callbacksBound = false,
}

T.ProfileManager = Manager
D.ProfileManager = Manager

local function cloneValue(value, copies)
	if type(value) ~= "table" then return value end
	copies = copies or {}
	if copies[value] then return copies[value] end
	local result = {}
	copies[value] = result
	for key, child in pairs(value) do result[cloneValue(key, copies)] = cloneValue(child, copies) end
	return result
end

local function replaceTable(target, source)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(source or {}) do target[key] = cloneValue(value) end
end

local function overlayTable(target, source)
	for key, value in pairs(type(source) == "table" and source or {}) do
		if type(value) == "table" and type(target[key]) == "table" then
			overlayTable(target[key], value)
		else
			target[key] = cloneValue(value)
		end
	end
	return target
end

local function isPublicValue(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return false end
	if _G.canaccessvalue and not _G.canaccessvalue(value) then return false end
	return true
end

local function isSafeText(value, maximum)
	return isPublicValue(value) and type(value) == "string" and value ~= ""
		and (not maximum or #value <= maximum) and value:find("[%z\1-\31\127]") == nil
end

local function sanitizeNewName(value)
	if not isSafeText(value) then return nil end
	local clean = value:match("^%s*(.-)%s*$")
	if clean == "" or #clean > Manager.MAX_PROFILE_NAME_BYTES then return nil end
	return clean
end

local function validProfileID(value)
	return value == Manager.DEFAULT_PROFILE_ID
		or type(value) == "string" and value:match("^profile%-%d+$") ~= nil and #value <= 32
end

local function validCharacterKey(value)
	return isSafeText(value, 128)
end

local function validEnvironment(value)
	return Manager.ENVIRONMENT_NAMES[value] ~= nil
end

local function sortedKeys(source)
	local result = {}
	for key in pairs(type(source) == "table" and source or {}) do result[#result + 1] = key end
	table.sort(result, function(left, right) return tostring(left) < tostring(right) end)
	return result
end

local function currentIdentity()
	local characterKey
	if type(_G.UnitFullName) == "function" then
		local ok, name, realm = pcall(_G.UnitFullName, "player")
		if ok and isPublicValue(name) and isPublicValue(realm) and isSafeText(name, 64) then
			if type(realm) ~= "string" or realm == "" then
				local realmOK, fallbackRealm = pcall(_G.GetNormalizedRealmName or _G.GetRealmName)
				if realmOK and isPublicValue(fallbackRealm) then realm = fallbackRealm end
			end
			realm = type(realm) == "string" and realm or ""
			local candidate = name .. " - " .. realm
			if validCharacterKey(candidate) then characterKey = candidate end
		end
	end
	if not characterKey and type(_G.UnitName) == "function" and type(_G.GetRealmName) == "function" then
		local nameOK, name = pcall(_G.UnitName, "player")
		local realmOK, realm = pcall(_G.GetRealmName)
		if nameOK and realmOK and isPublicValue(name) and isPublicValue(realm)
			and isSafeText(name, 64) and isSafeText(realm, 64)
		then
			local candidate = name .. " - " .. realm
			if validCharacterKey(candidate) then characterKey = candidate end
		end
	end

	local specIndex
	local specID
	if type(_G.GetSpecialization) == "function" then
		local ok, value = pcall(_G.GetSpecialization)
		if ok and isPublicValue(value) and type(value) == "number" and value > 0 then specIndex = math.floor(value) end
	end
	if specIndex and type(_G.GetSpecializationInfo) == "function" then
		local ok, value = pcall(_G.GetSpecializationInfo, specIndex)
		if ok and isPublicValue(value) and type(value) == "number" and value > 0 then specID = math.floor(value) end
	end
	local specKeys = {}
	if specID then specKeys[#specKeys + 1] = "id:" .. specID end
	if specIndex then specKeys[#specKeys + 1] = "index:" .. specIndex end
	return characterKey, specKeys, specIndex
end

local function isVariantStorageKey(value)
	return type(value) == "string" and value:match("^DCRPM:") ~= nil
end

local function discoverAceProfileKeys(saved)
	local found = { Default = true }
	if type(saved.profiles) == "table" then
		for key in pairs(saved.profiles) do
			if isSafeText(key, 1024) and not isVariantStorageKey(key) then found[key] = true end
		end
	end
	if type(saved.profileKeys) == "table" then
		for _, key in pairs(saved.profileKeys) do
			if isSafeText(key, 1024) and not isVariantStorageKey(key) then found[key] = true end
		end
	end
	return found
end

local function profileIDByStorageKey(data, storageKey)
	for profileID, record in pairs(data.profiles or {}) do
		if record.aceKey == storageKey or record.legacyAceKey == storageKey then return profileID end
		for environment, variantKey in pairs(type(record.variants) == "table" and record.variants or {}) do
			if variantKey == storageKey then return profileID, environment end
		end
	end
	return nil
end

local function allocateProfileID(data)
	local serial = tonumber(data.nextProfileID) or 0
	for _ = 1, Manager.MAX_PROFILE_SERIAL do
		serial = serial >= Manager.MAX_PROFILE_SERIAL and 1 or serial + 1
		local profileID = "profile-" .. serial
		if data.profiles[profileID] == nil then
			data.nextProfileID = serial
			return profileID
		end
	end
	return nil
end

local function normalizeOrder(data)
	local order = { Manager.DEFAULT_PROFILE_ID }
	local included = { [Manager.DEFAULT_PROFILE_ID] = true }
	for _, profileID in ipairs(type(data.profileOrder) == "table" and data.profileOrder or {}) do
		if validProfileID(profileID) and data.profiles[profileID] and not included[profileID] then
			order[#order + 1] = profileID
			included[profileID] = true
		end
	end
	local missing = {}
	for profileID, record in pairs(data.profiles) do
		if not included[profileID] then missing[#missing + 1] = { id = profileID, name = record.name } end
	end
	table.sort(missing, function(left, right)
		local leftName = string.lower(tostring(left.name or ""))
		local rightName = string.lower(tostring(right.name or ""))
		if leftName == rightName then return left.id < right.id end
		return leftName < rightName
	end)
	for _, entry in ipairs(missing) do order[#order + 1] = entry.id end
	data.profileOrder = order
end

local function buildLegacyCatalog(saved, legacy)
	local discovered = discoverAceProfileKeys(saved)
	local names = {}
	for name in pairs(discovered) do if name ~= "Default" then names[#names + 1] = name end end
	table.sort(names, function(left, right)
		local foldedLeft = string.lower(left)
		local foldedRight = string.lower(right)
		if foldedLeft == foldedRight then return left < right end
		return foldedLeft < foldedRight
	end)
	local data = {
		schemaVersion = Manager.SCHEMA_VERSION,
		profiles = {
			[Manager.DEFAULT_PROFILE_ID] = {
				name = "Default", aceKey = "Default", legacyAceKey = "Default", protected = true,
			},
		},
		profileOrder = { Manager.DEFAULT_PROFILE_ID },
		nextProfileID = 0,
		selection = { account = Manager.DEFAULT_PROFILE_ID, characters = {} },
		environmentModes = {},
		editEnvironments = {},
		compatibility = { libDualSpecMode = "manager-owned", migrated = true },
		migration = { sourceSchema = tonumber(legacy and legacy.schemaVersion) or 0 },
	}
	local idForName = { Default = Manager.DEFAULT_PROFILE_ID }
	for _, name in ipairs(names) do
		local profileID = allocateProfileID(data)
		if not profileID then break end
		data.profiles[profileID] = { name = name, aceKey = name, legacyAceKey = name }
		data.profileOrder[#data.profileOrder + 1] = profileID
		idForName[name] = profileID
	end
	local function mappedID(name)
		return isSafeText(name, 1024) and idForName[name] or nil
	end
	local accountName = type(legacy) == "table" and legacy.accountDefault or "Default"
	data.selection.account = mappedID(accountName) or Manager.DEFAULT_PROFILE_ID
	local legacyCharacters = type(legacy) == "table" and legacy.characterAssignments or nil
	local profileKeys = type(saved.profileKeys) == "table" and saved.profileKeys or {}
	local characterSet = {}
	for key in pairs(profileKeys) do if validCharacterKey(key) then characterSet[key] = true end end
	for key in pairs(type(legacyCharacters) == "table" and legacyCharacters or {}) do
		if validCharacterKey(key) then characterSet[key] = true end
	end
	local legacySpecs = type(legacy) == "table" and legacy.specializationAssignments or nil
	for key in pairs(type(legacySpecs) == "table" and legacySpecs or {}) do
		if validCharacterKey(key) then characterSet[key] = true end
	end
	local namespaces = type(saved.namespaces) == "table" and saved.namespaces or nil
	local dualSpec = namespaces and namespaces["LibDualSpec-1.0"] or nil
	local dualCharacters = type(dualSpec) == "table" and dualSpec.char or nil
	for key in pairs(type(dualCharacters) == "table" and dualCharacters or {}) do
		if validCharacterKey(key) then characterSet[key] = true end
	end
	for _, characterKey in ipairs(sortedKeys(characterSet)) do
		local record = { specs = {}, perSpecEnabled = false }
		local baseName = type(legacyCharacters) == "table" and legacyCharacters[characterKey] or nil
		record.profileID = mappedID(baseName) or mappedID(profileKeys[characterKey])
		local sourceSpecs = type(legacySpecs) == "table" and legacySpecs[characterKey] or nil
		if type(sourceSpecs) == "table" then
			for spec, name in pairs(sourceSpecs) do
				local profileID = mappedID(name)
				if type(spec) == "number" and profileID then record.specs["index:" .. math.floor(spec)] = profileID end
			end
		end
		local dualRecord = type(dualCharacters) == "table" and dualCharacters[characterKey] or nil
		if type(dualRecord) == "table" then
			record.perSpecEnabled = dualRecord.enabled == true
			for spec, name in pairs(dualRecord) do
				local profileID = mappedID(name)
				if type(spec) == "number" and profileID then record.specs["index:" .. math.floor(spec)] = profileID end
			end
		end
		data.selection.characters[characterKey] = record
	end
	return data
end

local function normalizeCatalog(saved, source)
	local data = cloneValue(source) or {}
	data.schemaVersion = Manager.SCHEMA_VERSION
	data.profiles = type(data.profiles) == "table" and data.profiles or {}
	data.selection = type(data.selection) == "table" and data.selection or {}
	data.selection.characters = type(data.selection.characters) == "table" and data.selection.characters or {}
	data.environmentModes = type(data.environmentModes) == "table" and data.environmentModes or {}
	data.editEnvironments = type(data.editEnvironments) == "table" and data.editEnvironments or {}
	data.compatibility = type(data.compatibility) == "table" and data.compatibility or {}
	data.compatibility.libDualSpecMode = "manager-owned"
	data.compatibility.migrated = true
	local normalizedProfiles = {}
	local usedLegacyKeys = {}
	local usedVariantKeys = {}
	for _, profileID in ipairs(sortedKeys(data.profiles)) do
		local record = data.profiles[profileID]
		if validProfileID(profileID) and type(record) == "table" then
			local legacyKey = record.legacyAceKey or record.aceKey
			if profileID == Manager.DEFAULT_PROFILE_ID then legacyKey = "Default" end
			if isSafeText(legacyKey, 1024) and not usedLegacyKeys[legacyKey] then
				local normalized = {
					name = profileID == Manager.DEFAULT_PROFILE_ID and "Default"
						or isSafeText(record.name, 1024) and record.name or legacyKey,
					aceKey = legacyKey,
					legacyAceKey = legacyKey,
					protected = profileID == Manager.DEFAULT_PROFILE_ID,
					variants = {},
				}
				for _, environment in ipairs(Manager.ENVIRONMENT_ORDER) do
					local variantKey = type(record.variants) == "table" and record.variants[environment] or nil
					if isSafeText(variantKey, 1024) and isVariantStorageKey(variantKey) and not usedVariantKeys[variantKey] then
						normalized.variants[environment] = variantKey
						usedVariantKeys[variantKey] = true
					end
				end
				normalizedProfiles[profileID] = normalized
				usedLegacyKeys[legacyKey] = true
			end
		end
	end
	if not normalizedProfiles[Manager.DEFAULT_PROFILE_ID] then
		normalizedProfiles[Manager.DEFAULT_PROFILE_ID] = {
			name = "Default", aceKey = "Default", legacyAceKey = "Default", protected = true, variants = {},
		}
		usedLegacyKeys.Default = true
	end
	data.profiles = normalizedProfiles
	data.nextProfileID = math.max(0, math.min(Manager.MAX_PROFILE_SERIAL, math.floor(tonumber(data.nextProfileID) or 0)))
	local discovered = discoverAceProfileKeys(saved)
	local missing = {}
	for aceKey in pairs(discovered) do if not usedLegacyKeys[aceKey] then missing[#missing + 1] = aceKey end end
	table.sort(missing, function(left, right)
		local foldedLeft = string.lower(left)
		local foldedRight = string.lower(right)
		if foldedLeft == foldedRight then return left < right end
		return foldedLeft < foldedRight
	end)
	for _, aceKey in ipairs(missing) do
		local profileID = allocateProfileID(data)
		if profileID then data.profiles[profileID] = { name = aceKey, aceKey = aceKey, legacyAceKey = aceKey, variants = {} } end
	end
	normalizeOrder(data)
	if not data.profiles[data.selection.account] then data.selection.account = Manager.DEFAULT_PROFILE_ID end
	local normalizedCharacters = {}
	for characterKey, sourceRecord in pairs(data.selection.characters) do
		if validCharacterKey(characterKey) and type(sourceRecord) == "table" then
			local record = { specs = {}, perSpecEnabled = sourceRecord.perSpecEnabled == true }
			if data.profiles[sourceRecord.profileID] then record.profileID = sourceRecord.profileID end
			for specKey, profileID in pairs(type(sourceRecord.specs) == "table" and sourceRecord.specs or {}) do
				if isSafeText(specKey, 32) and data.profiles[profileID] then record.specs[specKey] = profileID end
			end
			normalizedCharacters[characterKey] = record
		end
	end
	data.selection.characters = normalizedCharacters
	for profileID in pairs(data.profiles) do
		local mode = data.environmentModes[profileID]
		if mode ~= "AUTO" and not validEnvironment(mode) then data.environmentModes[profileID] = "AUTO" end
		if not validEnvironment(data.editEnvironments[profileID]) then data.editEnvironments[profileID] = "OPEN_WORLD" end
	end
	return data
end

local function variantStorageKey(profileID, environment, used)
	local base = "DCRPM:" .. profileID .. ":" .. environment
	local candidate = base
	local suffix = 2
	while used[candidate] do
		candidate = base .. ":" .. suffix
		suffix = suffix + 1
	end
	used[candidate] = true
	return candidate
end

local function defaultProfile()
	return type(D.defaults) == "table" and type(D.defaults.profile) == "table" and D.defaults.profile or {}
end

local STOCK_MOUSE_BUTTONS = {
	"*%s1", "*%s2", "ctrl-%s1", "ctrl-%s2", "shift-%s1", "shift-%s2",
	"shift-%s3", "alt-%s1", "alt-%s2", "alt-%s3", "*%s4", "ctrl-%s4",
	"shift-%s4", "alt-%s4", "*%s5", "ctrl-%s5", "shift-%s5", "alt-%s5",
	"*%s3", "ctrl-%s3",
}

local VALID_CURE_GESTURES = {}
for _, gesture in ipairs(STOCK_MOUSE_BUTTONS) do VALID_CURE_GESTURES[gesture] = true end

local function stockMouseButtons(mouseButtons)
	if type(mouseButtons) ~= "table" or #mouseButtons ~= #STOCK_MOUSE_BUTTONS then return false end
	for index, gesture in ipairs(STOCK_MOUSE_BUTTONS) do
		if mouseButtons[index] ~= gesture then return false end
	end
	return true
end

local function normalizeManualBindings(value)
	local result = {}
	for actionKey, gesture in pairs(type(value) == "table" and value or {}) do
		if type(actionKey) == "string" and actionKey ~= "" and #actionKey <= 128
			and (gesture == "UNASSIGNED" or VALID_CURE_GESTURES[gesture])
		then
			result[actionKey] = gesture
		end
	end
	return result
end

local function migrateVariantBindingPolicy(profile, legacyGlobal, rawSource)
	if type(profile) ~= "table" then return end
	rawSource = type(rawSource) == "table" and rawSource or profile
	local rawMode = rawSource.CureBindingMode
	local sourceButtons = type(rawSource.MouseButtons) == "table" and rawSource.MouseButtons
		or type(legacyGlobal) == "table" and type(legacyGlobal.MouseButtons) == "table" and legacyGlobal.MouseButtons
		or STOCK_MOUSE_BUTTONS

	if rawMode == "AUTO" or rawMode == "MANUAL" then
		profile.CureBindingMode = rawMode
		profile.CureBindingManual = normalizeManualBindings(rawSource.CureBindingManual)
		if type(rawSource.CureBindingLegacySlots) == "table" then
			profile.CureBindingLegacySlots = cloneValue(rawSource.CureBindingLegacySlots)
		end
		return
	end

	if stockMouseButtons(sourceButtons) then
		profile.CureBindingMode = "AUTO"
		profile.CureBindingManual = {}
		profile.CureBindingLegacySlots = nil
		return
	end

	profile.CureBindingMode = "MANUAL"
	profile.CureBindingManual = normalizeManualBindings(rawSource.CureBindingManual)
	profile.CureBindingLegacySlots = {}
	for priority = 1, 7 do
		local gesture = sourceButtons[priority]
		if VALID_CURE_GESTURES[gesture] then profile.CureBindingLegacySlots[priority] = gesture end
	end
	local targetGesture = sourceButtons[#sourceButtons - 1]
	local focusGesture = sourceButtons[#sourceButtons]
	if VALID_CURE_GESTURES[targetGesture] then profile.CureBindingLegacySlots.target = targetGesture end
	if VALID_CURE_GESTURES[focusGesture] then profile.CureBindingLegacySlots.focus = focusGesture end
end

local function materializeVariant(source, environment, legacyGlobal)
	local result = cloneValue(defaultProfile())
	overlayTable(result, type(source) == "table" and source or {})
	-- Mouse click priorities and the Decursive macro key were global before
	-- schema v3. Copy the user's legacy values into every first-generation
	-- variant, while leaving the original global table untouched.
	if (type(source) ~= "table" or source.MouseButtons == nil)
		and type(legacyGlobal) == "table" and type(legacyGlobal.MouseButtons) == "table"
	then
		result.MouseButtons = cloneValue(legacyGlobal.MouseButtons)
	end
	if (type(source) ~= "table" or source.MacroBind == nil)
		and type(legacyGlobal) == "table" and legacyGlobal.MacroBind ~= nil
	then
		result.MacroBind = legacyGlobal.MacroBind
	end
	local legacyProfiles = type(source) == "table" and source.Environment121Profiles or nil
	local presetProfiles = type(defaultProfile().Environment121Profiles) == "table" and defaultProfile().Environment121Profiles or nil
	local environmentOverlay = type(legacyProfiles) == "table" and legacyProfiles[environment]
		or type(presetProfiles) == "table" and presetProfiles[environment]
	if type(environmentOverlay) == "table" then overlayTable(result, environmentOverlay) end
	result.Environment121Profiles = nil
	result.Environment121ProfilesInitialized = nil
	result.Environment121Mode = nil
	migrateVariantBindingPolicy(result, legacyGlobal, source)
	return result
end

local function ensureVariants(saved, data)
	saved.profiles = type(saved.profiles) == "table" and saved.profiles or {}
	local used = {}
	for key in pairs(saved.profiles) do used[key] = true end
	for _, record in pairs(data.profiles) do
		for _, key in pairs(record.variants or {}) do used[key] = true end
	end
	local planned = {}
	for _, profileID in ipairs(data.profileOrder) do
		local record = data.profiles[profileID]
		if record then
			record.variants = type(record.variants) == "table" and record.variants or {}
			local source = saved.profiles[record.legacyAceKey]
			for _, environment in ipairs(Manager.ENVIRONMENT_ORDER) do
				local key = record.variants[environment]
				if not isSafeText(key, 1024) or not isVariantStorageKey(key) then
					key = variantStorageKey(profileID, environment, used)
					record.variants[environment] = key
				end
				if type(saved.profiles[key]) ~= "table" then planned[key] = materializeVariant(source, environment, saved.global) end
			end
			record.aceKey = record.variants.OPEN_WORLD
		end
	end
	for key, profile in pairs(planned) do saved.profiles[key] = profile end
	for _, record in pairs(data.profiles) do
		for _, environment in ipairs(Manager.ENVIRONMENT_ORDER) do
			local profile = saved.profiles[record.variants[environment]]
			if type(profile) == "table" then migrateVariantBindingPolicy(profile, saved.global, profile) end
		end
	end
	for _, record in pairs(data.profiles) do
		for _, environment in ipairs(Manager.ENVIRONMENT_ORDER) do
			if type(saved.profiles[record.variants[environment]]) ~= "table" then return false end
		end
	end
	return true
end

function Manager:InitializeStorage(saved)
	saved = type(saved) == "table" and saved or {}
	self.saved = saved
	self.editingPreview = false
	self.pendingResolution = nil
	self.characterKey, self.specKeys, self.specIndex = currentIdentity()
	local source = saved.profileManager
	local storedVersion = type(source) == "table" and tonumber(source.schemaVersion) or 0
	self.storedVersion = storedVersion or 0
	self.readOnly = storedVersion and storedVersion > self.SCHEMA_VERSION or false
	if self.readOnly then
		self.data = buildLegacyCatalog(saved, nil)
		local existing = self.characterKey and type(saved.profileKeys) == "table" and saved.profileKeys[self.characterKey]
		self.futureAceKey = isSafeText(existing, 1024) and existing or "Default"
		return self.futureAceKey
	end
	local base
	if storedVersion and storedVersion >= 2 then
		base = normalizeCatalog(saved, source)
	else
		base = normalizeCatalog(saved, buildLegacyCatalog(saved, type(source) == "table" and source or nil))
	end
	local prepared = cloneValue(base)
	if not ensureVariants(saved, prepared) then
		self.data = base
		self.readOnly = true
		return "Default"
	end
	prepared.schemaVersion = self.SCHEMA_VERSION
	prepared.migration = type(prepared.migration) == "table" and prepared.migration or {}
	prepared.migration.completed = true
	prepared.migration.variantCount = #prepared.profileOrder * #self.ENVIRONMENT_ORDER
	prepared.migration.storageModel = "five-full-variants"
	saved.profileManager = prepared
	self.data = prepared
	self.storedVersion = self.SCHEMA_VERSION
	local activeID = self:ResolveActiveProfileID()
	local environment = self:ResolveEnvironment(activeID)
	local aceKey = self:GetAceKey(activeID, environment) or "Default"
	saved.profileKeys = type(saved.profileKeys) == "table" and saved.profileKeys or {}
	if self.characterKey then saved.profileKeys[self.characterKey] = aceKey end
	self.activeProfileID = activeID
	self.activeEnvironment = environment
	return aceKey
end

function Manager:BindDatabase(db)
	if type(db) ~= "table" then return false end
	self.db = db
	self:InstallCompatibilityAdapter(db)
	if not self.callbacksBound and db.RegisterCallback then
		db.RegisterCallback(self, "OnProfileChanged", "OnAceProfileChanged")
		db.RegisterCallback(self, "OnNewProfile", "OnAceNewProfile")
		db.RegisterCallback(self, "OnProfileDeleted", "OnAceProfileDeleted")
		db.RegisterCallback(self, "OnDatabaseReset", "OnAceDatabaseReset")
		self.callbacksBound = true
	end
	local currentID, environment = profileIDByStorageKey(self.data, db.GetCurrentProfile and db:GetCurrentProfile())
	self.activeProfileID = currentID or self:ResolveActiveProfileID()
	self.activeEnvironment = environment or self:ResolveEnvironment(self.activeProfileID)
	return true
end

function Manager:GetSchemaStatus()
	return {
		readOnly = self.readOnly == true,
		storedVersion = self.storedVersion,
		supportedVersion = self.SCHEMA_VERSION,
		message = self.readOnly and "Profile data was created by a newer Decursive version or could not be safely expanded. Profile changes are disabled to protect it." or nil,
	}
end

function Manager:IsReadOnly()
	return self.readOnly == true
end

function Manager:GetAceKey(profileID, environment)
	local record = self.data and self.data.profiles and self.data.profiles[profileID]
	if not record then return nil end
	environment = validEnvironment(environment) and environment or self.activeEnvironment or "OPEN_WORLD"
	return type(record.variants) == "table" and record.variants[environment] or record.aceKey
end

function Manager:GetLegacyAceKey(profileID)
	local record = self.data and self.data.profiles and self.data.profiles[profileID]
	return record and record.legacyAceKey or nil
end

function Manager:GetProfileName(profileID)
	local record = self.data and self.data.profiles and self.data.profiles[profileID]
	return record and record.name or nil
end

function Manager:FindProfileID(value)
	if not self.data or not isSafeText(value, 1024) then return nil end
	if self.data.profiles[value] then return value end
	local storageID = profileIDByStorageKey(self.data, value)
	if storageID then return storageID end
	for profileID, record in pairs(self.data.profiles) do
		if record.name == value then return profileID end
	end
	local folded = string.lower(value)
	for profileID, record in pairs(self.data.profiles) do
		if string.lower(record.name) == folded then return profileID end
	end
	return nil
end

function Manager:GetCatalog()
	local result = {}
	local activeID = self:GetActiveProfileID()
	for _, profileID in ipairs(self.data and self.data.profileOrder or {}) do
		local record = self.data.profiles[profileID]
		if record then
			result[#result + 1] = {
				id = profileID,
				name = record.name,
				protected = record.protected == true,
				deletable = record.protected ~= true,
				active = profileID == activeID,
				accountDefault = self.data.selection.account == profileID,
				variantCount = #self.ENVIRONMENT_ORDER,
			}
		end
	end
	return result
end

function Manager:ResolveActiveProfileID()
	if not self.data then return self.DEFAULT_PROFILE_ID end
	if self.readOnly then return profileIDByStorageKey(self.data, self.futureAceKey) or self.DEFAULT_PROFILE_ID end
	local selection = self.data.selection
	local character = self.characterKey and selection.characters[self.characterKey] or nil
	if character then
		if character.perSpecEnabled then
			for _, specKey in ipairs(self.specKeys or {}) do
				if self.data.profiles[character.specs[specKey]] then return character.specs[specKey], "spec" end
			end
		end
		if self.data.profiles[character.profileID] then return character.profileID, "character" end
	end
	if self.data.profiles[selection.account] then return selection.account, "account" end
	return self.DEFAULT_PROFILE_ID, "fallback"
end

function Manager:DetectEnvironment()
	if type(_G.IsInInstance) == "function" then
		local ok, inInstance, instanceType = pcall(_G.IsInInstance)
		if ok and inInstance == true and isPublicValue(instanceType) then
			if instanceType == "pvp" or instanceType == "arena" then return "PVP" end
			if instanceType == "raid" then return "RAID" end
			if instanceType == "party" then
				local challengeMode = _G.C_ChallengeMode
				if challengeMode and type(challengeMode.GetActiveChallengeMapID) == "function" then
					local mapOK, mapID = pcall(challengeMode.GetActiveChallengeMapID)
					if mapOK and isPublicValue(mapID) and type(mapID) == "number" and mapID > 0 then
						return "MYTHIC_PLUS"
					end
				end
				return "DUNGEON"
			end
		end
	end
	return "OPEN_WORLD"
end

function Manager:GetEnvironmentMode(profileID)
	profileID = profileID or self:ResolveActiveProfileID()
	local mode = self.data and self.data.environmentModes and self.data.environmentModes[profileID] or "AUTO"
	if mode == "AUTO" or validEnvironment(mode) then return mode end
	return "AUTO"
end

function Manager:ResolveEnvironment(profileID)
	local mode = self:GetEnvironmentMode(profileID)
	if mode ~= "AUTO" then return mode, "manual" end
	return self:DetectEnvironment(), "automatic"
end

function Manager:GetActiveProfileID()
	if self.db and self.db.GetCurrentProfile then
		local mapped = profileIDByStorageKey(self.data, self.db:GetCurrentProfile())
		if mapped then return mapped end
	end
	return self:ResolveActiveProfileID()
end

function Manager:GetRuntimeEnvironment()
	if self.db and self.db.GetCurrentProfile then
		local _, environment = profileIDByStorageKey(self.data, self.db:GetCurrentProfile())
		if environment then return environment end
	end
	return self.activeEnvironment or self:ResolveEnvironment(self:ResolveActiveProfileID())
end

function Manager:GetEditEnvironment(profileID)
	profileID = profileID or self:ResolveActiveProfileID()
	local environment = self.data and self.data.editEnvironments and self.data.editEnvironments[profileID]
	return validEnvironment(environment) and environment or "OPEN_WORLD"
end

function Manager:GetContextSnapshot()
	local profileID, assignmentSource = self:ResolveActiveProfileID()
	local activeEnvironment, environmentSource = self:ResolveEnvironment(profileID)
	return {
		profileID = profileID,
		profileName = self:GetProfileName(profileID),
		assignmentSource = assignmentSource,
		activationMode = self:GetEnvironmentMode(profileID),
		activeEnvironment = activeEnvironment,
		environmentSource = environmentSource,
		editEnvironment = self:GetEditEnvironment(profileID),
		previewing = self.editingPreview == true,
		effectiveEnvironment = self:GetRuntimeEnvironment(),
	}
end

function Manager:GetAssignmentSnapshot()
	local character = self.characterKey and self.data.selection.characters[self.characterKey] or nil
	local specID
	if character then
		for _, specKey in ipairs(self.specKeys or {}) do
			if self.data.profiles[character.specs[specKey]] then specID = character.specs[specKey] break end
		end
	end
	local active, source = self:ResolveActiveProfileID()
	return {
		account = self.data.selection.account,
		character = character and character.profileID or nil,
		characterKey = self.characterKey,
		perSpecEnabled = character and character.perSpecEnabled == true or false,
		spec = specID,
		active = active,
		activeSource = source,
		characterAvailable = self.characterKey ~= nil,
		specAvailable = self.specKeys and #self.specKeys > 0 or false,
	}
end

function Manager:NotifyChanged()
	if D.NotifyConfigurationChanged then D:NotifyConfigurationChanged() end
end

function Manager:RefreshMutatedProfile(profileID)
	if not self.db or not self.db.GetCurrentProfile or not D.SetConfiguration then return true end
	local activeID = profileIDByStorageKey(self.data, self.db:GetCurrentProfile())
	if activeID ~= profileID then return true end
	local ok, result = pcall(D.SetConfiguration, D)
	if not ok then return false, tostring(result) end
	if result ~= true then return false, "SetConfiguration did not complete" end
	return true
end

function Manager:ApplyProfileVariant(profileID, environment, reason)
	if not self.data.profiles[profileID] then return false, "unknown-profile" end
	if not validEnvironment(environment) then return false, "unknown-environment" end
	local aceKey = self:GetAceKey(profileID, environment)
	if not aceKey then return false, "variant-unavailable" end
	if not self.db or not self.db.SetProfile then
		self.activeProfileID = profileID
		self.activeEnvironment = environment
		return true, "storage-only"
	end
	if self.db:GetCurrentProfile() == aceKey then
		self.activeProfileID = profileID
		self.activeEnvironment = environment
		self.pendingResolution = nil
		self:NotifyChanged()
		return true, "unchanged"
	end
	if _G.InCombatLockdown and _G.InCombatLockdown() then
		self.pendingResolution = { profileID = profileID, environment = environment, reason = reason or "profile-resolution" }
		return true, "queued"
	end
	local previousAceKey = self.db:GetCurrentProfile()
	local previousProfileID = self.activeProfileID
	local previousEnvironment = self.activeEnvironment
	self.applyingAceProfile = true
	local ok, err = pcall(self.db.SetProfile, self.db, aceKey)
	self.applyingAceProfile = false
	if not ok then
		local rollbackOK = true
		local rollbackError
		if previousAceKey and self.db:GetCurrentProfile() ~= previousAceKey then
			self.applyingAceProfile = true
			rollbackOK, rollbackError = pcall(self.db.SetProfile, self.db, previousAceKey)
			self.applyingAceProfile = false
		end
		self.activeProfileID = previousProfileID
		self.activeEnvironment = previousEnvironment
		if not rollbackOK then
			return false, tostring(err) .. "; rollback failed: " .. tostring(rollbackError)
		end
		return false, tostring(err)
	end
	self.activeProfileID = profileID
	self.activeEnvironment = environment
	self.pendingResolution = nil
	self:NotifyChanged()
	return true, "applied"
end

function Manager:ApplyResolvedProfile(reason)
	local profileID = self:ResolveActiveProfileID()
	local environment = self.editingPreview and self:GetEditEnvironment(profileID) or self:ResolveEnvironment(profileID)
	return self:ApplyProfileVariant(profileID, environment, reason)
end

function Manager:SetEnvironmentMode(mode)
	if self.readOnly then return false, "read-only" end
	if mode ~= "AUTO" and not validEnvironment(mode) then return false, "unknown-environment" end
	local profileID = self:ResolveActiveProfileID()
	self.data.environmentModes[profileID] = mode
	if not self.editingPreview then return self:ApplyResolvedProfile("environment-mode") end
	self:NotifyChanged()
	return true, "preview-preserved"
end

function Manager:SetEditEnvironment(environment, preview)
	if self.readOnly then return false, "read-only" end
	if not validEnvironment(environment) then return false, "unknown-environment" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	local profileID = self:ResolveActiveProfileID()
	self.data.editEnvironments[profileID] = environment
	if preview ~= false then
		self.editingPreview = true
		return self:ApplyProfileVariant(profileID, environment, "environment-edit-preview")
	end
	self:NotifyChanged()
	return true, "selected"
end

function Manager:BeginEnvironmentEditing()
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	return self:SetEditEnvironment(self:GetEditEnvironment(), true)
end

function Manager:RestoreRuntimeEnvironment()
	self.editingPreview = false
	return self:ApplyResolvedProfile("environment-edit-restore")
end

function Manager:RefreshIdentity(reason)
	local characterKey, specKeys, specIndex = currentIdentity()
	self.characterKey = characterKey or self.characterKey
	self.specKeys = #specKeys > 0 and specKeys or self.specKeys
	self.specIndex = specIndex or self.specIndex
	return self:ApplyResolvedProfile(reason or "identity-refresh")
end

function Manager:HandleCombatEnded()
	local pending = self.pendingResolution
	if not pending then return false end
	self.pendingResolution = nil
	return self:ApplyProfileVariant(pending.profileID, pending.environment, pending.reason)
end

function Manager:GetOrCreateCharacterRecord()
	if not self.characterKey then return nil end
	local characters = self.data.selection.characters
	local record = characters[self.characterKey]
	if type(record) ~= "table" then
		record = { specs = {}, perSpecEnabled = false }
		characters[self.characterKey] = record
	end
	record.specs = type(record.specs) == "table" and record.specs or {}
	return record
end

function Manager:SetAssignment(scope, profileID)
	if self.readOnly then return false, "read-only" end
	if profileID ~= nil and not self.data.profiles[profileID] then return false, "unknown-profile" end
	if scope == "account" then
		if not profileID then return false, "account-required" end
		self.data.selection.account = profileID
	elseif scope == "character" then
		local record = self:GetOrCreateCharacterRecord()
		if not record then return false, "character-unavailable" end
		record.profileID = profileID
	elseif scope == "spec" then
		local record = self:GetOrCreateCharacterRecord()
		local specKey = self.specKeys and self.specKeys[1]
		if not record or not specKey then return false, "spec-unavailable" end
		record.specs[specKey] = profileID
	else
		return false, "invalid-scope"
	end
	local ok, state = self:ApplyResolvedProfile("assignment-" .. scope)
	if ok then self:NotifyChanged() end
	return ok, state
end

function Manager:SetPerSpecEnabled(enabled)
	if self.readOnly then return false, "read-only" end
	local record = self:GetOrCreateCharacterRecord()
	if not record then return false, "character-unavailable" end
	record.perSpecEnabled = enabled == true
	local ok, state = self:ApplyResolvedProfile("assignment-spec-toggle")
	if ok then self:NotifyChanged() end
	return ok, state
end

function Manager:ActivateProfile(profileID)
	if self.readOnly then return false, "read-only" end
	if not self.data.profiles[profileID] then return false, "unknown-profile" end
	local record = self:GetOrCreateCharacterRecord()
	if record then
		local specKey = record.perSpecEnabled and self.specKeys and self.specKeys[1]
		if specKey then record.specs[specKey] = profileID else record.profileID = profileID end
	else
		self.data.selection.account = profileID
	end
	return self:ApplyResolvedProfile("profile-activate")
end

function Manager:NameExists(name, exceptID)
	local folded = string.lower(name)
	for profileID, record in pairs(self.data.profiles) do
		if profileID ~= exceptID and string.lower(record.name) == folded then return true end
	end
	return false
end

function Manager:RestoreData(snapshot)
	self.data = snapshot
	self.saved.profileManager = snapshot
end

function Manager:CreateProfile(name, sourceID)
	if self.readOnly then return nil, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return nil, "combat" end
	if #self.data.profileOrder >= self.MAX_PROFILES then return nil, "profile-limit" end
	local clean = sanitizeNewName(name)
	if not clean then return nil, "invalid-name" end
	if self:NameExists(clean) then return nil, "name-exists" end
	if sourceID and not self.data.profiles[sourceID] then return nil, "unknown-source" end
	local dataBackup = cloneValue(self.data)
	local profileID = allocateProfileID(self.data)
	if not profileID then return nil, "profile-id-unavailable" end
	local record = { name = clean, legacyAceKey = "DCRPM:LEGACY:" .. profileID, variants = {} }
	self.data.profiles[profileID] = record
	self.data.profileOrder[#self.data.profileOrder + 1] = profileID
	self.data.environmentModes[profileID] = sourceID and self:GetEnvironmentMode(sourceID) or "AUTO"
	self.data.editEnvironments[profileID] = sourceID and self:GetEditEnvironment(sourceID) or "OPEN_WORLD"
	local used = {}
	for key in pairs(self.saved.profiles or {}) do used[key] = true end
	for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
		local key = variantStorageKey(profileID, environment, used)
		record.variants[environment] = key
		local source = sourceID and self.saved.profiles[self:GetAceKey(sourceID, environment)] or nil
		self.saved.profiles[key] = source and cloneValue(source) or materializeVariant(nil, environment)
	end
	record.aceKey = record.variants.OPEN_WORLD
	local activated, activateError = self:ActivateProfile(profileID)
	if not activated then
		for _, key in pairs(record.variants) do self.saved.profiles[key] = nil end
		self:RestoreData(dataBackup)
		self:ApplyResolvedProfile("profile-create-rollback")
		return nil, activateError or "activate-failed"
	end
	self:NotifyChanged()
	return profileID, "ok"
end

function Manager:RenameProfile(profileID, name)
	if self.readOnly then return false, "read-only" end
	local record = self.data.profiles[profileID]
	if not record then return false, "unknown-profile" end
	if record.protected then return false, "protected-profile" end
	local clean = sanitizeNewName(name)
	if not clean then return false, "invalid-name" end
	if self:NameExists(clean, profileID) then return false, "name-exists" end
	record.name = clean
	self:NotifyChanged()
	return true, "ok"
end

function Manager:PresetVariant(environment)
	if not validEnvironment(environment) then return nil end
	return materializeVariant(nil, environment)
end

function Manager:CopyEnvironment(targetID, targetEnvironment, sourceID, sourceEnvironment)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	if not self.data.profiles[targetID] or not self.data.profiles[sourceID] then return false, "unknown-profile" end
	if not validEnvironment(targetEnvironment) or not validEnvironment(sourceEnvironment) then return false, "unknown-environment" end
	local targetKey = self:GetAceKey(targetID, targetEnvironment)
	local sourceKey = self:GetAceKey(sourceID, sourceEnvironment)
	local target = self.saved.profiles[targetKey]
	local source = self.saved.profiles[sourceKey]
	if type(target) ~= "table" or type(source) ~= "table" then return false, "variant-unavailable" end
	local backup = cloneValue(target)
	local ok, err = pcall(replaceTable, target, source)
	if not ok then
		replaceTable(target, backup)
		return false, "copy-failed:" .. tostring(err)
	end
	local refreshed, refreshError = self:RefreshMutatedProfile(targetID)
	if not refreshed then
		replaceTable(target, backup)
		self:RefreshMutatedProfile(targetID)
		return false, "copy-failed:" .. tostring(refreshError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:CopyProfile(targetID, sourceID)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	if not self.data.profiles[targetID] or not self.data.profiles[sourceID] then return false, "unknown-profile" end
	local backups = {}
	for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
		local targetKey = self:GetAceKey(targetID, environment)
		local sourceKey = self:GetAceKey(sourceID, environment)
		local target = self.saved.profiles[targetKey]
		local source = self.saved.profiles[sourceKey]
		if type(target) ~= "table" or type(source) ~= "table" then return false, "variant-unavailable" end
		backups[targetKey] = cloneValue(target)
	end
	local ok, err = pcall(function()
		for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
			local targetKey = self:GetAceKey(targetID, environment)
			replaceTable(self.saved.profiles[targetKey], self.saved.profiles[self:GetAceKey(sourceID, environment)])
		end
	end)
	if not ok then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		return false, "copy-failed:" .. tostring(err)
	end
	local refreshed, refreshError = self:RefreshMutatedProfile(targetID)
	if not refreshed then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		self:RefreshMutatedProfile(targetID)
		return false, "copy-failed:" .. tostring(refreshError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:ResetEnvironment(profileID, environment)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	if not self.data.profiles[profileID] then return false, "unknown-profile" end
	if not validEnvironment(environment) then return false, "unknown-environment" end
	local key = self:GetAceKey(profileID, environment)
	local target = self.saved.profiles[key]
	if type(target) ~= "table" then return false, "variant-unavailable" end
	local backup = cloneValue(target)
	local ok, err = pcall(replaceTable, target, self:PresetVariant(environment))
	if not ok then
		replaceTable(target, backup)
		return false, "reset-failed:" .. tostring(err)
	end
	local refreshed, refreshError = self:RefreshMutatedProfile(profileID)
	if not refreshed then
		replaceTable(target, backup)
		self:RefreshMutatedProfile(profileID)
		return false, "reset-failed:" .. tostring(refreshError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:ResetProfile(profileID)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	if not self.data.profiles[profileID] then return false, "unknown-profile" end
	local backups = {}
	for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
		local key = self:GetAceKey(profileID, environment)
		if type(self.saved.profiles[key]) ~= "table" then return false, "variant-unavailable" end
		backups[key] = cloneValue(self.saved.profiles[key])
	end
	local ok, err = pcall(function()
		for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
			replaceTable(self.saved.profiles[self:GetAceKey(profileID, environment)], self:PresetVariant(environment))
		end
	end)
	if not ok then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		return false, "reset-failed:" .. tostring(err)
	end
	local refreshed, refreshError = self:RefreshMutatedProfile(profileID)
	if not refreshed then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		self:RefreshMutatedProfile(profileID)
		return false, "reset-failed:" .. tostring(refreshError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:ExportLogicalProfile(profileID)
	profileID = profileID or self:ResolveActiveProfileID()
	if not self.data.profiles[profileID] then return nil, "unknown-profile" end
	local variants = {}
	for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
		local profile = self.saved.profiles[self:GetAceKey(profileID, environment)]
		if type(profile) ~= "table" then return nil, "variant-unavailable" end
		variants[environment] = cloneValue(profile)
	end
	return {
		name = self:GetProfileName(profileID),
		activationMode = self:GetEnvironmentMode(profileID),
		variants = variants,
	}
end

function Manager:ImportLogicalProfile(profileID, variants, activationMode)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	if not self.data.profiles[profileID] then return false, "unknown-profile" end
	if type(variants) ~= "table" then return false, "invalid-import" end
	if activationMode ~= nil and activationMode ~= "AUTO" and not validEnvironment(activationMode) then
		return false, "unknown-environment"
	end
	local backups = {}
	for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
		if type(variants[environment]) ~= "table" then return false, "missing-variant" end
		local key = self:GetAceKey(profileID, environment)
		if type(self.saved.profiles[key]) ~= "table" then return false, "variant-unavailable" end
		backups[key] = cloneValue(self.saved.profiles[key])
	end
	local oldMode = self:GetEnvironmentMode(profileID)
	local ok, err = pcall(function()
		for _, environment in ipairs(self.ENVIRONMENT_ORDER) do
			local imported = cloneValue(variants[environment])
			imported.Environment121Profiles = nil
			imported.Environment121ProfilesInitialized = nil
			imported.Environment121Mode = nil
			replaceTable(self.saved.profiles[self:GetAceKey(profileID, environment)], imported)
		end
		if activationMode then self.data.environmentModes[profileID] = activationMode end
	end)
	if not ok then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		self.data.environmentModes[profileID] = oldMode
		return false, "import-failed:" .. tostring(err)
	end
	local refreshed, refreshError = self:RefreshMutatedProfile(profileID)
	if not refreshed then
		for key, backup in pairs(backups) do replaceTable(self.saved.profiles[key], backup) end
		self.data.environmentModes[profileID] = oldMode
		self:RefreshMutatedProfile(profileID)
		return false, "import-failed:" .. tostring(refreshError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:RemoveAssignments(profileID)
	if self.data.selection.account == profileID then self.data.selection.account = self.DEFAULT_PROFILE_ID end
	for _, record in pairs(self.data.selection.characters) do
		if record.profileID == profileID then record.profileID = nil end
		for specKey, assigned in pairs(record.specs or {}) do
			if assigned == profileID then record.specs[specKey] = nil end
		end
	end
end

function Manager:DeleteProfile(profileID)
	if self.readOnly then return false, "read-only" end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false, "combat" end
	local record = self.data.profiles[profileID]
	if not record then return false, "unknown-profile" end
	if record.protected then return false, "protected-profile" end
	local dataBackup = cloneValue(self.data)
	local deletedProfilesBackup = {}
	for _, key in pairs(record.variants or {}) do
		if self.saved.profiles[key] ~= nil then deletedProfilesBackup[key] = self.saved.profiles[key] end
	end
	if record.legacyAceKey and self.saved.profiles[record.legacyAceKey] ~= nil then
		deletedProfilesBackup[record.legacyAceKey] = self.saved.profiles[record.legacyAceKey]
	end
	local profileKeysBackup = cloneValue(self.saved.profileKeys or {})
	self:RemoveAssignments(profileID)
	self.data.profiles[profileID] = nil
	self.data.environmentModes[profileID] = nil
	self.data.editEnvironments[profileID] = nil
	for index = #self.data.profileOrder, 1, -1 do
		if self.data.profileOrder[index] == profileID then table.remove(self.data.profileOrder, index) end
	end
	local switched, switchError = self:ApplyResolvedProfile("profile-delete-fallback")
	if not switched then
		self:RestoreData(dataBackup)
		return false, switchError or "fallback-failed"
	end
	local deleted, deleteError = pcall(function()
		for _, key in pairs(record.variants or {}) do self.saved.profiles[key] = nil end
		if record.legacyAceKey and record.legacyAceKey ~= "Default" then self.saved.profiles[record.legacyAceKey] = nil end
		for characterKey, key in pairs(self.saved.profileKeys or {}) do
			if key == record.legacyAceKey then self.saved.profileKeys[characterKey] = nil end
			for _, variantKey in pairs(record.variants or {}) do
				if key == variantKey then self.saved.profileKeys[characterKey] = nil end
			end
		end
	end)
	if not deleted then
		self:RestoreData(dataBackup)
		for key, profile in pairs(deletedProfilesBackup) do self.saved.profiles[key] = profile end
		self.saved.profileKeys = profileKeysBackup
		self:ApplyResolvedProfile("profile-delete-rollback")
		return false, "delete-failed:" .. tostring(deleteError)
	end
	self:NotifyChanged()
	return true, "ok"
end

function Manager:AdoptAceProfile(aceKey)
	if self.readOnly or not isSafeText(aceKey, 1024) or isVariantStorageKey(aceKey) then return nil end
	local existing = profileIDByStorageKey(self.data, aceKey)
	if existing then return existing end
	if #self.data.profileOrder >= self.MAX_PROFILES then return nil end
	local name = sanitizeNewName(aceKey)
	if not name or self:NameExists(name) then return nil end
	local profileID = allocateProfileID(self.data)
	if not profileID then return nil end
	local record = { name = name, legacyAceKey = aceKey, aceKey = aceKey, variants = {} }
	self.data.profiles[profileID] = record
	self.data.profileOrder[#self.data.profileOrder + 1] = profileID
	self.data.environmentModes[profileID] = "AUTO"
	self.data.editEnvironments[profileID] = "OPEN_WORLD"
	ensureVariants(self.saved, self.data)
	return profileID
end

function Manager:OnAceNewProfile(_, _, aceKey)
	if self.applyingAceProfile then return end
	self:AdoptAceProfile(aceKey)
	self:NotifyChanged()
end

function Manager:OnAceProfileChanged(_, _, aceKey)
	if self.applyingAceProfile or self.readOnly then return end
	local profileID, environment = profileIDByStorageKey(self.data, aceKey)
	if not profileID then profileID = self:AdoptAceProfile(aceKey) end
	if profileID then
		local record = self:GetOrCreateCharacterRecord()
		if record then
			local specKey = record.perSpecEnabled and self.specKeys and self.specKeys[1]
			if specKey then record.specs[specKey] = profileID else record.profileID = profileID end
		else
			self.data.selection.account = profileID
		end
		self.activeProfileID = profileID
		self.activeEnvironment = environment or self:ResolveEnvironment(profileID)
		if not environment then self:ApplyResolvedProfile("external-profile-adopt") end
	end
	self:NotifyChanged()
end

function Manager:OnAceProfileDeleted(_, _, aceKey)
	if self.readOnly then return end
	local profileID, environment = profileIDByStorageKey(self.data, aceKey)
	if not profileID or profileID == self.DEFAULT_PROFILE_ID then return end
	local record = self.data.profiles[profileID]
	if environment then
		self.saved.profiles[aceKey] = materializeVariant(self.saved.profiles[record.legacyAceKey], environment, self.saved.global)
		self:ApplyResolvedProfile("external-variant-repair")
	else
		record.legacyAceKey = nil
	end
	self:NotifyChanged()
end

function Manager:OnAceDatabaseReset(_, db)
	if type(db) ~= "table" or type(db.sv) ~= "table" then return end
	self.callbacksBound = true
	self:InitializeStorage(db.sv)
	self.db = db
	self:InstallCompatibilityAdapter(db)
	self:ApplyResolvedProfile("database-reset")
	self:NotifyChanged()
end

function Manager:InstallCompatibilityAdapter(db)
	if db.DecursiveProfileManagerCompatibility then return end
	db.DecursiveProfileManagerCompatibility = true
	db.IsDualSpecEnabled = function()
		local state = Manager:GetAssignmentSnapshot()
		return state.perSpecEnabled == true
	end
	db.SetDualSpecEnabled = function(_, enabled)
		return Manager:SetPerSpecEnabled(enabled)
	end
	db.GetDualSpecProfile = function(_, spec)
		local record = Manager.characterKey and Manager.data.selection.characters[Manager.characterKey]
		local profileID = record and record.specs["index:" .. tostring(spec or Manager.specIndex)]
		profileID = profileID or Manager:ResolveActiveProfileID()
		return Manager:GetAceKey(profileID, Manager:ResolveEnvironment(profileID))
	end
	db.SetDualSpecProfile = function(_, value, spec)
		local profileID = value and Manager:FindProfileID(value) or nil
		local record = Manager:GetOrCreateCharacterRecord()
		if Manager.readOnly or not record then return false end
		local specKey = spec and "index:" .. tostring(spec) or Manager.specKeys and Manager.specKeys[1]
		if not specKey then return false end
		record.specs[specKey] = profileID
		return Manager:ApplyResolvedProfile("compat-spec-assignment")
	end
	db.CheckDualSpecState = function()
		return Manager:RefreshIdentity("compat-spec-check")
	end
end

T._LoadedFiles["Dcr_ProfileManager.lua"] = "@project-version@"
