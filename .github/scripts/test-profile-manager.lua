local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local loader = loadstring or load
local initSource = readFile("Decursive/DCR_init.lua")
local managerStart = assert(initSource:find("local PROFILE_MANAGER_SCHEMA = 1", 1, true))
local managerEnd = assert(initSource:find("function D:OnInitialize()", managerStart, true))
local managerChunk = initSource:sub(managerStart, managerEnd - 1) .. "\nreturn initializeProfileManagerStorage\n"

UnitName = function() return "Tester" end
GetRealmName = function() return "Test Realm" end

local initializeManager = assert(loader(managerChunk, "profile-manager-migration"))()

local longLegacyProfileName = string.rep("Legacy-", 10)
DecursiveDB = {
    profileKeys = {
        ["Tester - Test Realm"] = "Healer",
        ["Alt - Test Realm"] = longLegacyProfileName,
    },
    profiles = {
        Healer = { scale = 1.25 },
        [longLegacyProfileName] = { scale = 0.8 },
    },
    namespaces = {
        ["LibDualSpec-1.0"] = {
            char = {
                ["Alt - Test Realm"] = { enabled = true, [2] = "Healer" },
            },
        },
    },
}
local originalHealer = DecursiveDB.profiles.Healer
assert(initializeManager() == "Healer")
assert(DecursiveDB.profiles.Healer == originalHealer)
assert(DecursiveDB.profileManager.schemaVersion == 1)
assert(DecursiveDB.profileManager.accountDefault == "Default")
assert(DecursiveDB.profileManager.characterAssignments["Tester - Test Realm"] == "Healer")
assert(DecursiveDB.profileManager.characterAssignments["Alt - Test Realm"] == longLegacyProfileName)
assert(DecursiveDB.profileManager.specializationAssignments["Alt - Test Realm"][2] == "Healer")

DecursiveDB = nil
assert(initializeManager() == "Default")
assert(DecursiveDB.profileManager.characterAssignments["Tester - Test Realm"] == nil)
assert(DecursiveDB.profileKeys["Tester - Test Realm"] == "Default")

DecursiveDB.profileManager.accountDefault = "Raid"
DecursiveDB.profiles = { Raid = { size = 30 } }
DecursiveDB.profileKeys["Tester - Test Realm"] = "Default"
assert(initializeManager() == "Raid")
assert(DecursiveDB.profileKeys["Tester - Test Realm"] == "Raid")

DecursiveDB.profileManager.accountDefault = "Missing"
assert(initializeManager() == "Default")
assert(DecursiveDB.profileManager.accountDefault == "Default")

local coreSource = readFile("Decursive/Modern/ZD_Core.lua")
local apiStart = assert(coreSource:find("local function validProfileName", 1, true))
local apiEnd = assert(coreSource:find("function ZD:GetEnvironmentSetting()", apiStart, true))

local profileData = {
    Default = { value = 1 },
    Healer = { value = 2 },
    Raid = { value = 3 },
}
local currentProfile = "Healer"
local dualEnabled = false
local dualProfile = "Healer"
local copyShouldFail = false
GetSpecialization = function() return 1 end

ZD = {
    CanConfigure = function() return true end,
    GetProfiles = function()
        local profiles = {}
        for name in pairs(profileData) do profiles[#profiles + 1] = name end
        return profiles
    end,
    GetUserProfileName = function() return currentProfile end,
    SetStatus = function(self, text, isError)
        self.lastStatus = text
        self.lastStatusError = isError == true
    end,
}

local dualCharacters = {
    ["Tester - Test Realm"] = { enabled = true, [1] = "Healer", [2] = "Raid" },
    ["Alt - Test Realm"] = { enabled = true, [1] = "Healer" },
}

local db = {
    keys = { char = "Tester - Test Realm" },
    sv = {
        profileManager = {
            schemaVersion = 1,
            accountDefault = "Healer",
            characterAssignments = {
                ["Tester - Test Realm"] = "Healer",
                ["Alt - Test Realm"] = "Healer",
            },
        },
        namespaces = {
            ["LibDualSpec-1.0"] = { char = dualCharacters },
        },
    },
}

function db:GetProfiles(target)
    target = target or {}
    for name in pairs(profileData) do target[#target + 1] = name end
    return target, #target
end
function db:GetCurrentProfile() return currentProfile end
function db:SetProfile(name)
    currentProfile = name
    profileData[name] = profileData[name] or {}
end
function db:CopyProfile(name)
    if copyShouldFail then error("simulated copy failure") end
    assert(name ~= currentProfile)
    profileData[currentProfile] = { value = profileData[name].value }
end
function db:ResetProfile() profileData[currentProfile] = { value = 1 } end
function db:DeleteProfile(name)
    assert(name ~= currentProfile)
    profileData[name] = nil
end
function db:IsDualSpecEnabled() return dualEnabled end
function db:SetDualSpecEnabled(enabled)
    dualEnabled = enabled
    local record = dualCharacters[self.keys.char]
    for spec = 1, 2 do record[spec] = enabled and (record[spec] or currentProfile) or nil end
end
function db:GetDualSpecProfile() return dualProfile end
function db:SetDualSpecProfile(name)
    dualProfile = name
    dualCharacters[self.keys.char][1] = name
    currentProfile = name
end
function db:CheckDualSpecState()
    local profileName = dualCharacters[self.keys.char][1]
    if dualEnabled and profileName then self:SetProfile(profileName) end
end

D = { db = db }
assert(loader(coreSource:sub(apiStart, apiEnd - 1), "profile-manager-api"))()

local assignments = ZD:GetProfileAssignments()
assert(assignments.account == "Healer")
assert(assignments.character == "Healer")
assert(assignments.active == "Healer")

assert(ZD:SetCharacterProfile(nil))
assert(db.sv.profileManager.characterAssignments["Tester - Test Realm"] == nil)
assert(currentProfile == "Healer")
assert(ZD:SetAccountProfile("Raid"))
assert(currentProfile == "Raid")

assert(ZD:CreateUserProfile("Mythic"))
assert(currentProfile == "Mythic")
assert(profileData.Mythic)
assert(db.sv.profileManager.characterAssignments["Tester - Test Realm"] == "Mythic")

assert(ZD:CloneCurrentProfile("Mythic Copy"))
assert(currentProfile == "Mythic Copy")
assert(profileData["Mythic Copy"].value == profileData.Mythic.value)

db.sv.profileManager.accountDefault = "Mythic Copy"
db.sv.profileManager.characterAssignments["Alt - Test Realm"] = "Mythic Copy"
dualCharacters["Alt - Test Realm"][2] = "Mythic Copy"
assert(ZD:RenameCurrentProfile("Renamed Mythic"))
assert(currentProfile == "Renamed Mythic")
assert(profileData["Mythic Copy"] == nil)
assert(profileData["Renamed Mythic"].value == profileData.Mythic.value)
assert(db.sv.profileManager.accountDefault == "Renamed Mythic")
assert(db.sv.profileManager.characterAssignments["Alt - Test Realm"] == "Renamed Mythic")
assert(dualCharacters["Alt - Test Realm"][2] == "Renamed Mythic")

copyShouldFail = true
assert(not ZD:CloneCurrentProfile("Broken Copy"))
copyShouldFail = false
assert(currentProfile == "Renamed Mythic")
assert(profileData["Broken Copy"] == nil)

currentProfile = "Raid"
db.sv.profileManager.accountDefault = "Healer"
db.sv.profileManager.characterAssignments["Tester - Test Realm"] = "Healer"
db.sv.profileManager.characterAssignments["Alt - Test Realm"] = "Healer"
dualEnabled = true
dualProfile = "Raid"
assert(ZD:DeleteUserProfile("Healer"))
assert(profileData.Healer == nil)
assert(db.sv.profileManager.accountDefault == "Default")
assert(db.sv.profileManager.characterAssignments["Tester - Test Realm"] == nil)
assert(db.sv.profileManager.characterAssignments["Alt - Test Realm"] == nil)
assert(dualCharacters["Tester - Test Realm"][1] == nil)
assert(dualCharacters["Alt - Test Realm"][1] == nil)
assert(not ZD:DeleteUserProfile("Default"))

db.sv.profileManager.accountDefault = "Renamed Mythic"
db.sv.profileManager.characterAssignments["Alt - Test Realm"] = "Renamed Mythic"
db.sv.profileManager.specializationAssignments["Alt - Test Realm"] = { [2] = "Renamed Mythic" }
dualCharacters["Alt - Test Realm"][2] = "Renamed Mythic"
assert(ZD:HandleDeletedProfileAssignments("Renamed Mythic"))
assert(db.sv.profileManager.accountDefault == "Default")
assert(db.sv.profileManager.characterAssignments["Alt - Test Realm"] == nil)
assert(db.sv.profileManager.specializationAssignments["Alt - Test Realm"][2] == nil)
assert(dualCharacters["Alt - Test Realm"][2] == nil)

db.sv.profileManager.characterAssignments["Tester - Test Realm"] = "Raid"
currentProfile = "Mythic Copy"
dualEnabled = true
dualCharacters["Tester - Test Realm"][1] = "Mythic"
assert(ZD:SetSpecProfilesEnabled(false))
assert(currentProfile == "Raid")
assert(dualCharacters["Tester - Test Realm"][1] == nil)
assert(db.sv.profileManager.specializationAssignments["Tester - Test Realm"][1] == "Mythic")
assert(ZD:SetSpecProfilesEnabled(true))
assert(dualCharacters["Tester - Test Realm"][1] == "Mythic")
assert(currentProfile == "Mythic")
assert(ZD:SetCurrentSpecProfile(nil))
assert(dualCharacters["Tester - Test Realm"][1] == nil)
assert(currentProfile == "Raid")

io.write("PASS: profile-manager migration, assignments, copy, rename, and deletion mocks\n")
