local function readFile(path)
	if type(io.open) ~= "function" and type(readfile) == "function" then
		return assert(readfile(path))
	end
	local file = assert(io.open(path, "rb"))
	local text = assert(file:read("*a"))
	file:close()
	return text
end

local function contains(text, value)
	return text:find(value, 1, true) ~= nil
end

local function slice(text, first, last)
	local startAt = assert(text:find(first, 1, true), "missing start marker: " .. first)
	local endAt = assert(text:find(last, startAt + #first, true), "missing end marker: " .. last)
	return text:sub(startAt, endAt - 1)
end

local profiles = readFile("Decursive_Options/V13/Pages/Profiles.lua")
assert(contains(profiles, 'page:RegisterRoute("DECURSIVE",'))
assert(contains(profiles, 'localized("PROFILE_DECURSIVE_PAGE", "Decursive Profiles")'))
assert(contains(profiles, 'page:RegisterRoute("ENVIRONMENT",'))
assert(contains(profiles, 'localized("PROFILE_ENVIRONMENT_PAGE", "Environment Profiles")'))
assert(contains(profiles, 'page.routeFrames.DECURSIVE = decursive'))
assert(contains(profiles, 'page.routeFrames.ENVIRONMENT = environment'))
assert(contains(profiles, 'profile.id, label = profile.name'))
assert(contains(profiles, 'ZD:GetUserProfileID()'))
assert(contains(profiles, 'PROFILE_FUTURE_SCHEMA'))
assert(contains(profiles, 'schema.readOnly == true'))
assert(contains(profiles, 'importButton:SetEnabled(writable)'))

local decursive = slice(profiles,
	'local decursive = CreateFrame("Frame", nil, page)',
	'local environment = CreateFrame("Frame", nil, page)')
for _, operation in ipairs({
	"ZD.SetUserProfile",
	"ZD.CreateUserProfile",
	"ZD.CloneCurrentProfile",
	"ZD.RenameCurrentProfile",
	"ZD.ResetUserProfile",
	"ZD.DeleteUserProfile",
	"D.GetProfileExportString",
	"D.ImportProfileString",
}) do
	assert(contains(decursive, operation), "Decursive Profiles is missing " .. operation)
end
assert(contains(decursive, "Controls:ConfirmButton(deletion"))
assert(contains(decursive, "Controls:ConfirmButton(import"))
for _, misplaced in ipairs({
	"ZD.SetAccountProfile",
	"ZD.SetCharacterProfile",
	"ZD.SetSpecProfilesEnabled",
	"ZD.SetCurrentSpecProfile",
	"ZD.SetEnvironmentSetting",
}) do
	assert(not contains(decursive, misplaced), "assignment control leaked into Decursive Profiles: " .. misplaced)
end

local environment = slice(profiles,
	'local environment = CreateFrame("Frame", nil, page)',
	"function page:SetRoute(route)")
for _, operation in ipairs({
	"ZD.SetAccountProfile",
	"ZD.SetCharacterProfile",
	"ZD.SetSpecProfilesEnabled",
	"ZD.SetCurrentSpecProfile",
	"ZD.SetEnvironmentSetting",
	"ZD.SetEditEnvironment",
	"ZD.ResetEnvironmentProfile",
	"ZD.CopyEnvironmentProfile",
}) do
	assert(contains(environment, operation), "Environment Profiles is missing " .. operation)
end
for _, misplaced in ipairs({
	"ZD.CreateUserProfile",
	"ZD.CloneCurrentProfile",
	"ZD.RenameCurrentProfile",
	"ZD.ResetUserProfile",
	"ZD.DeleteUserProfile",
	"D.GetProfileExportString",
	"D.ImportProfileString",
}) do
	assert(not contains(environment, misplaced), "named-profile control leaked into Environment Profiles: " .. misplaced)
end

local settings = readFile("Decursive_Options/V13/Pages/Settings.lua")
assert(not contains(settings, "Profiles & Modes"))
assert(not contains(settings, 'builder = "BuildProfiles"'))
assert(not contains(settings, 'builder = "BuildSharing"'))

local shell = readFile("Decursive_Options/V13/Shell.lua")
assert(contains(shell, 'return self:OpenProfilesRoute("DECURSIVE")'))
assert(contains(shell, 'return self:OpenProfilesRoute("ENVIRONMENT")'))
assert(contains(shell, 'route == "profiles" or route == "sharing"'))
assert(contains(shell, 'route == "environmentprofiles"'))
assert(contains(shell, 'ZD.BeginEnvironmentEditing'))
assert(contains(shell, 'ZD.EndEnvironmentEditing'))
assert(contains(shell, '"EDIT PREVIEW"'))
assert(contains(shell, 'header.contextSelector = CreateFrame("Button"'))
assert(contains(shell, 'ZD:SetEditEnvironment(nextEnvironment)'))

local manager = readFile("Decursive/Dcr_ProfileManager.lua")
assert(contains(manager, 'SCHEMA_VERSION = 4'))
assert(contains(manager, 'ENVIRONMENT_ORDER = { "OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP" }'))
assert(contains(manager, 'storageModel = "five-full-variants"'))
assert(contains(manager, 'function Manager:SetEditEnvironment'))
assert(contains(manager, 'function Manager:RestoreRuntimeEnvironment'))
assert(contains(manager, 'function Manager:CopyEnvironment'))
assert(contains(manager, 'function Manager:ResetEnvironment'))

local profileIO = readFile("Decursive/Dcr_ProfileIO.lua")
assert(contains(profileIO, 'scope = scope == "environment" and "environment" or "logical"'))
assert(contains(profileIO, 'payload.variants = logical.variants'))
assert(contains(profileIO, 'ImportLogicalProfile(profileID, candidates, payload.activationMode)'))

local legacyOptions = readFile("Decursive_Options/Dcr_opt_tree.lua")
local managedOptions = slice(legacyOptions, "    if D.ProfileManager then", "        -- Older branches retain")
assert(contains(managedOptions, "Open Profiles Workspace"))
assert(contains(managedOptions, "OpenProfilesRoute('DECURSIVE')"))
assert(not contains(managedOptions, 'LibStub("AceDBOptions-3.0")'))

local search = readFile("Decursive_Options/Modern/ZD_UI.lua")
assert(contains(search, 'profiles = "Decursive Profiles"'))
assert(contains(search, 'environmentprofiles = "Environment Profiles"'))
assert(not contains(search, '{ "User profile", "profile character AceDB setup" }'))
assert(contains(search, '{ key = profile.id, name = profile.name }'))
assert(contains(search, 'function() return ZD:GetUserProfileID() end'))
local namedSearch = slice(search, "    profiles = {", "\tenvironmentprofiles = {")
assert(contains(namedSearch, '{ "Create / Switch"'))
assert(not contains(namedSearch, '{ "Account default"'))
local assignmentSearch = slice(search, "\tenvironmentprofiles = {", "    lists = {")
assert(contains(assignmentSearch, '{ "Account default"'))
assert(contains(assignmentSearch, '{ "Per-specialization profiles"'))
assert(not contains(assignmentSearch, '{ "Create / Switch"'))

local schema = readFile("Decursive/V13/Core/SettingsSchema.lua")
assert(contains(schema, 'navigation("profiles.create", "DECURSIVE_PROFILES"'))
assert(contains(schema, 'navigation("profiles.account", "ENVIRONMENT_PROFILES"'))
assert(contains(schema, 'navigation("profiles.specialization", "ENVIRONMENT_PROFILES"'))

io.write("PASS: canonical Decursive and Environment profile pages and routing\n")
