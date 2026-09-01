local function readFile(path)
	if type(io.open) ~= "function" and type(readfile) == "function" then return assert(readfile(path)) end
	local file = assert(io.open(path, "rb"))
	local text = assert(file:read("*a"))
	file:close()
	return text
end

local function contains(text, value)
	return text:find(value, 1, true) ~= nil
end

local theme = readFile("Decursive/V13/Presentation/Theme.lua")
local navigationOrder = {
	'{ key = "OVERVIEW", label = "Overview" }',
	'{ key = "PROFILES", label = "Profiles" }',
	'{ key = "MUFS", label = "MUF Setup", groupLabel = "ENVIRONMENT PROFILE SETTINGS" }',
	'{ key = "CURE", label = "Cures & Mouse Bindings" }',
	'{ key = "ALERTS", label = "Alerts & Feedback" }',
	'{ key = "ADVANCED", label = "Advanced & Diagnostics" }',
}
local lastPosition = 0
for _, marker in ipairs(navigationOrder) do
	local position = assert(theme:find(marker, 1, true), "missing canonical navigation: " .. marker)
	assert(position > lastPosition, "canonical navigation is out of order")
	lastPosition = position
end
assert(not contains(theme, 'key = "SETTINGS"'))
assert(not contains(theme, 'label = "All Settings"'))

local shell = readFile("Decursive_Options/V13/Shell.lua")
for _, label in ipairs({
	"Decursive Profile: ",
	"Editing Environment Profile: ",
	"Active Environment Profile: ",
}) do
	assert(contains(shell, label), "missing persistent context label: " .. label)
end
assert(contains(shell, 'frame.navigation = navigation'))
assert(contains(shell, 'groupLabel'))
assert(not contains(shell, 'self:ShowPage("SETTINGS")'))
for route, destination in pairs({
	frames = 'page = "MUFS", route = "frames"',
	range = 'page = "MUFS", route = "units"',
	bindings = 'page = "CURE", route = "bindings"',
	curing = 'page = "CURE", route = "curing"',
	messages = 'page = "ALERTS", route = "messages"',
	sounds = 'page = "ALERTS", route = "sounds"',
	filtering = 'page = "ADVANCED", route = "filtering"',
	diagnostics = 'page = "ADVANCED", route = "diagnostics"',
}) do
	assert(contains(shell, route .. " = { " .. destination), "legacy route is not canonical: " .. route)
end

local workspaces = readFile("Decursive_Options/V13/Pages/Settings.lua")
assert(not contains(workspaces, 'RegisterPage("SETTINGS"'))
assert(not contains(workspaces, '"All Settings"'))
for _, label in ipairs({
	"MUF Setup",
	"Units & Visibility",
	"Layout & Appearance",
	"Range / LoS / Cooldowns",
	"Cures & Mouse Bindings",
	"Automatic / Manual",
	"Cure Order & Priority",
	"Custom / Additional Actions",
	"Alerts & Feedback",
	"Advanced & Diagnostics",
	"Profile Settings",
	"Affliction Filtering",
	"Detection & Integrations",
}) do
	assert(contains(workspaces, label), "environment workspace missing task label: " .. label)
end
for _, builder in ipairs({
	"BuildGeneral", "BuildFrames", "BuildCuring", "BuildBleeds", "BuildCooldowns",
	"BuildRangeVisibility", "BuildLists", "BuildBindings", "BuildIntegrations",
	"BuildCompatibility121", "BuildDiagnostics", "BuildDispelDB", "BuildAdvanced",
	"BuildSounds", "BuildFiltering", "BuildLiveList", "BuildMessages", "BuildMacro",
	"BuildTestMode",
}) do
	assert(contains(workspaces, 'builder = "' .. builder .. '"'), "legacy feature builder lost: " .. builder)
end
assert(contains(workspaces, "DECURSIVE PROFILE  >  ENVIRONMENT PROFILE"))
assert(contains(workspaces, "Every control below is stored in this complete environment configuration."))

local overview = readFile("Decursive_Options/V13/Pages/Overview.lua")
assert(contains(overview, "Environment Profile Overview"))
assert(contains(overview, "Complete Environment Profile settings"))
for _, page in ipairs({ "MUFS", "CURE", "ALERTS", "ADVANCED" }) do
	assert(contains(overview, 'UI:ShowPage("' .. page .. '")'))
end

local profiles = readFile("Decursive_Options/V13/Pages/Profiles.lua")
assert(contains(profiles, 'page:RegisterRoute("DECURSIVE"'))
assert(contains(profiles, 'page:RegisterRoute("ENVIRONMENT"'))
assert(contains(profiles, "for _, entry in ipairs(editEnvironmentValues) do"))
assert(contains(profiles, "Edit Selected Environment Profile"))
assert(contains(profiles, "Copy Into Selected"))
assert(contains(profiles, "Reset Selected to Defaults"))
assert(contains(profiles, 'UI:ShowPage("OVERVIEW")'))
assert(contains(profiles, "Account-wide default Decursive Profile"))
assert(contains(profiles, "Specialization assignment state"))
assert(contains(profiles, "Saved, inactive: "))
assert(contains(profiles, "if state.perSpecEnabled ~= true then return USE_CHARACTER_PROFILE end"))
assert(not contains(profiles, "Reset Edited to Preset"))
assert(not contains(profiles, "Edit and preview complete variant"))

local search = readFile("Decursive_Options/Modern/ZD_UI.lua")
assert(contains(search, 'frames = "MUF Setup — Layout & Appearance"'))
assert(contains(search, 'bindings = "Cures & Mouse Bindings — Automatic / Manual"'))
assert(contains(search, 'messages = "Alerts & Feedback"'))
assert(contains(search, 'diagnostics = "Advanced & Diagnostics — Diagnostics"'))
assert(contains(search, '{ "Edit Selected Environment Profile"'))
assert(contains(search, '{ "Affliction Priority Colors", "MUF center border cure action priority mouse gesture", "colors" }'))
assert(contains(search, 'skipKeys={c1=true,c2=true,c3=true,c4=true,c5=true,c6=true,c7=true}'))
assert(contains(search, 'buildBefore=buildAfflictionPriorityColorEditor'))
assert(contains(search, 'self.pendingOptionTab = result.tab'))
assert(not contains(search, '{ "Edit environment"'))

local manager = readFile("Decursive/Dcr_ProfileManager.lua")
assert(contains(manager, "SCHEMA_VERSION = 6"))
assert(contains(manager, 'for key in pairs(saved) do saved[key] = nil end'))
assert(contains(manager, 'return nil, "future-schema"'))
assert(contains(manager, "ensureEnvironmentClassSettings"))
assert(contains(manager, 'reset = { completed = true, schemaVersion = Manager.SCHEMA_VERSION }'))
assert(contains(manager, "self.aceDBCharacterKey"))
assert(contains(manager, "storedSpec = storedSpecID"))
assert(contains(manager, "record and record.perSpecEnabled"))

local initialization = readFile("Decursive/DCR_init.lua")
assert(contains(initialization, "D.profile.ClassSettings[classToken]"))
assert(contains(initialization, "D.classprofile = D.profile.ClassSettings[classToken]"))
assert(contains(initialization, "D.ProfileManager:IsReadOnly()"))

local profileIO = readFile("Decursive/Dcr_ProfileIO.lua")
assert(contains(profileIO, "validateClassSettings"))
assert(contains(profileIO, "cloneSerializable"))
assert(contains(profileIO, 'elseif key == "ClassSettings" then'))

if arg and arg[1] == "--self-test-failure" then error("intentional profile-page harness failure") end

io.write("PASS: canonical six-node profile-first IA, complete Environment Profile workspaces, five-profile edit/copy/reset UX, legacy/search aliases, persistent context and schema-6 reset wiring\n")
