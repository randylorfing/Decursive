local instanceType
local challengeMapID
local inCombat = false

UnitFullName = function() return "Tester", "Test Realm" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Test Realm" end
GetNormalizedRealmName = function() return "Test Realm" end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 256 end
InCombatLockdown = function() return inCombat end
IsInInstance = function()
    return instanceType ~= nil, instanceType or "none"
end
C_ChallengeMode = {
    GetActiveChallengeMapID = function() return challengeMapID end,
}

local defaults = {
    profile = {
        Scan_Pets = true,
        DebuffsFrameElemScale = 1.5,
        MF_colors = { { 0.8, 0, 0 }, { 0, 0.8, 0 } },
        PlaySound = true,
        ShowDebuffsFrame = true,
        MacroBind = false,
        CureBindingMode = "AUTO",
        CureBindingManual = {},
        MouseButtons = {
            "*%s1", "*%s2", "ctrl-%s1", "ctrl-%s2", "shift-%s1", "shift-%s2",
            "shift-%s3", "alt-%s1", "alt-%s2", "alt-%s3", "*%s4", "ctrl-%s4",
            "shift-%s4", "alt-%s4", "*%s5", "ctrl-%s5", "shift-%s5", "alt-%s5",
            "*%s3", "ctrl-%s3",
        },
        Environment121Profiles = {
            OPEN_WORLD = { OutOfRange121Enabled = false, CooldownOverlay121Opacity = 0.62 },
            DUNGEON = { OutOfRange121Enabled = true, CooldownOverlay121Opacity = 0.60 },
            MYTHIC_PLUS = { OutOfRange121Enabled = true, CooldownOverlay121Opacity = 0.70 },
            RAID = { OutOfRange121Enabled = true, CooldownOverlay121Opacity = 0.50 },
            PVP = { OutOfRange121Enabled = true, CooldownOverlay121Opacity = 0.65, TextAlerts121Enabled = false },
        },
    },
}

local function newManager(saved)
    local notifications = 0
    local D = {
        defaults = defaults,
        NotifyConfigurationChanged = function() notifications = notifications + 1 end,
    }
    local T = { Dcr = D, _LoadedFiles = {} }
    local chunk = assert(loadfile("Decursive/Dcr_ProfileManager.lua"))
    chunk("Decursive", T)
    local manager = assert(T.ProfileManager)
    manager:InitializeStorage(saved)
    return manager, D, function() return notifications end
end

local longLegacyName = string.rep("Legacy-", 10)
local saved = {
    global = {
        MacroBind = "CTRL-G",
        MouseButtons = { "legacy-left", "legacy-right", "legacy-third" },
    },
    profileKeys = {
        ["Tester - Test Realm"] = "Healer",
        ["Alt - Test Realm"] = longLegacyName,
    },
    profiles = {
        Healer = {
            Scan_Pets = false,
            DebuffsFrameElemScale = 1.25,
            MF_colors = { { 0.1, 0.2, 0.3 } },
            Environment121Profiles = {
                RAID = { CooldownOverlay121Opacity = 0.42 },
                PVP = { TextAlerts121Enabled = false },
            },
        },
        Raid = { DebuffsFrameElemScale = 0.8 },
        [longLegacyName] = { DebuffsFrameElemScale = 0.7 },
    },
    namespaces = {
        ["LibDualSpec-1.0"] = {
            char = {
                ["Tester - Test Realm"] = { enabled = true, [1] = "Raid", [2] = "Healer" },
                ["Alt - Test Realm"] = { enabled = true, [2] = "Healer" },
            },
        },
    },
    profileManager = {
        schemaVersion = 2,
        profiles = {
            default = { name = "Default", aceKey = "Default", protected = true },
            ["profile-1"] = { name = "Healer", aceKey = "Healer" },
            ["profile-2"] = { name = "Raid", aceKey = "Raid" },
            ["profile-3"] = { name = longLegacyName, aceKey = longLegacyName },
        },
        profileOrder = { "default", "profile-1", "profile-2", "profile-3" },
        nextProfileID = 3,
        selection = {
            account = "profile-2",
            characters = {
                ["Tester - Test Realm"] = {
                    profileID = "profile-1",
                    perSpecEnabled = true,
                    specs = { ["index:1"] = "profile-2" },
                },
                ["Alt - Test Realm"] = {
                    profileID = "profile-3",
                    perSpecEnabled = true,
                    specs = { ["index:2"] = "profile-1" },
                },
            },
        },
    },
}

local healerOriginal = saved.profiles.Healer
local dualSpecOriginal = saved.namespaces["LibDualSpec-1.0"].char
local manager, D, notificationCount = newManager(saved)
local data = saved.profileManager
assert(data.schemaVersion == 4)
assert(data.migration.completed == true)
assert(data.migration.storageModel == "five-full-variants")
assert(data.migration.variantCount == #data.profileOrder * 5)
assert(data.profiles.default.name == "Default")
assert(data.profileOrder[1] == "default")
assert(data.compatibility.libDualSpecMode == "manager-owned")
assert(saved.profiles.Healer == healerOriginal)
assert(saved.namespaces["LibDualSpec-1.0"].char == dualSpecOriginal)

local healerID = assert(manager:FindProfileID("Healer"))
local raidID = assert(manager:FindProfileID("Raid"))
local longID = assert(manager:FindProfileID(longLegacyName))
assert(healerID == "profile-1" and raidID == "profile-2" and longID == "profile-3")
assert(manager:GetProfileName(longID) == longLegacyName)
assert(manager:ResolveActiveProfileID() == raidID)

local variantTables = {}
for _, environment in ipairs(manager.ENVIRONMENT_ORDER) do
    local storageKey = assert(manager:GetAceKey(healerID, environment))
    assert(storageKey:match("^DCRPM:"))
    assert(storageKey ~= "Healer")
    variantTables[environment] = assert(saved.profiles[storageKey])
    assert(variantTables[environment].Scan_Pets == false)
    assert(variantTables[environment].DebuffsFrameElemScale == 1.25)
    assert(variantTables[environment].MacroBind == "CTRL-G")
    assert(variantTables[environment].MouseButtons[1] == "legacy-left")
    assert(variantTables[environment].CureBindingMode == "MANUAL")
    assert(variantTables[environment].Environment121Profiles == nil)
end
assert(variantTables.RAID.CooldownOverlay121Opacity == 0.42)
assert(variantTables.DUNGEON.CooldownOverlay121Opacity == 0.60)
assert(variantTables.PVP.TextAlerts121Enabled == false)

-- Idempotency preserves stable IDs, original tables and all complete variants.
manager:InitializeStorage(saved)
assert(manager:FindProfileID("Healer") == healerID)
assert(saved.profiles.Healer == healerOriginal)
for environment, tableIdentity in pairs(variantTables) do
    assert(saved.profiles[manager:GetAceKey(healerID, environment)] == tableIdentity)
end

-- A partial schema-v3 write is repaired without disturbing valid variants.
local missingKey = manager:GetAceKey(healerID, "MYTHIC_PLUS")
saved.profiles[missingKey] = nil
manager:InitializeStorage(saved)
assert(type(saved.profiles[missingKey]) == "table")
assert(saved.profiles[manager:GetAceKey(healerID, "RAID")] == variantTables.RAID)
assert(saved.profileManager.migration.completed == true)

local callbacks = {}
local currentProfile = saved.profileKeys["Tester - Test Realm"]
local failSetKey
local failAfterSetKey
local failConfiguration
local db = { sv = saved, profile = saved.profiles[currentProfile] }
function db.RegisterCallback(target, event, method)
    callbacks[event] = callbacks[event] or {}
    callbacks[event][#callbacks[event] + 1] = { target = target, method = method }
end
function db:Fire(event, ...)
    for _, record in ipairs(callbacks[event] or {}) do
        record.target[record.method](record.target, event, self, ...)
    end
end
function db:GetCurrentProfile() return currentProfile end
function db:SetProfile(storageKey)
    if storageKey == failSetKey then error("simulated SetProfile failure") end
    currentProfile = storageKey
    if not saved.profiles[storageKey] then
        saved.profiles[storageKey] = {}
        self:Fire("OnNewProfile", storageKey)
    end
    self.profile = saved.profiles[storageKey]
    D.profile = self.profile
    if storageKey == failAfterSetKey then error("simulated callback failure after switch") end
    self:Fire("OnProfileChanged", storageKey)
end
function db:DeleteProfile(storageKey)
    saved.profiles[storageKey] = nil
    self:Fire("OnProfileDeleted", storageKey)
end
D.SetConfiguration = function()
    D.profile = db.profile
    if failConfiguration then error("simulated configuration failure") end
    return true
end

assert(manager:BindDatabase(db))
assert(db.DecursiveProfileManagerCompatibility == true)
assert(db:IsDualSpecEnabled() == true)
assert(manager:GetActiveProfileID() == raidID)

-- Automatic precedence: PvP/arena > Raid > Mythic+ > Party > Open World.
instanceType, challengeMapID = nil, nil
assert(manager:DetectEnvironment() == "OPEN_WORLD")
instanceType = "party"
assert(manager:DetectEnvironment() == "DUNGEON")
challengeMapID = 503
assert(manager:DetectEnvironment() == "MYTHIC_PLUS")
instanceType, challengeMapID = "raid", nil
assert(manager:DetectEnvironment() == "RAID")
instanceType = "arena"
assert(manager:DetectEnvironment() == "PVP")

-- Full settings are isolated, including pets, layout and colors.
assert(manager:SetEnvironmentMode("RAID"))
assert(currentProfile == manager:GetAceKey(raidID, "RAID"))
db.profile.Scan_Pets = false
db.profile.DebuffsFrameElemScale = 2.25
db.profile.MF_colors[1][1] = 0.33
db.profile.MacroBind = "ALT-R"
db.profile.MouseButtons[1] = "raid-left"
db.profile.CureBindingMode = "MANUAL"
db.profile.CureBindingManual = { ["spell:88423"] = "shift-%s1" }
assert(manager:SetEnvironmentMode("DUNGEON"))
assert(currentProfile == manager:GetAceKey(raidID, "DUNGEON"))
assert(db.profile.Scan_Pets == true)
assert(db.profile.DebuffsFrameElemScale == 0.8)
assert(db.profile.MF_colors[1][1] ~= 0.33)
assert(db.profile.MacroBind == "CTRL-G")
assert(db.profile.MouseButtons[1] == "legacy-left")
assert(db.profile.CureBindingManual["spell:88423"] == nil)
assert(manager:SetEnvironmentMode("RAID"))
assert(db.profile.Scan_Pets == false and db.profile.DebuffsFrameElemScale == 2.25)
assert(db.profile.MF_colors[1][1] == 0.33)
assert(db.profile.MacroBind == "ALT-R" and db.profile.MouseButtons[1] == "raid-left")
assert(db.profile.CureBindingMode == "MANUAL")
assert(db.profile.CureBindingManual["spell:88423"] == "shift-%s1")

-- Edit preview switches the complete AceDB table and restores runtime mode.
assert(manager:SetEditEnvironment("PVP", true))
assert(manager:GetContextSnapshot().previewing == true)
assert(currentProfile == manager:GetAceKey(raidID, "PVP"))
db.profile.ShowDebuffsFrame = false
assert(manager:RestoreRuntimeEnvironment())
assert(currentProfile == manager:GetAceKey(raidID, "RAID"))
assert(saved.profiles[manager:GetAceKey(raidID, "PVP")].ShowDebuffsFrame == false)

-- Combat queues the exact logical/environment target and applies it once.
inCombat = true
assert(manager:SetEnvironmentMode("DUNGEON"))
assert(currentProfile == manager:GetAceKey(raidID, "RAID"))
assert(type(manager.pendingResolution) == "table")
local blockedID, blockedCode = manager:CreateProfile("Blocked In Combat")
assert(blockedID == nil and blockedCode == "combat")
assert(not manager:ResetEnvironment(raidID, "RAID"))
inCombat = false
assert(manager:HandleCombatEnded())
assert(currentProfile == manager:GetAceKey(raidID, "DUNGEON"))
assert(manager.pendingResolution == nil)

-- A callback error after AceDB changes its current profile restores the
-- previous complete variant and manager identity without recursing callbacks.
local beforeCallbackFailure = currentProfile
failAfterSetKey = manager:GetAceKey(raidID, "RAID")
assert(not manager:ApplyProfileVariant(raidID, "RAID", "callback-failure-test"))
failAfterSetKey = nil
assert(currentProfile == beforeCallbackFailure)
assert(db.profile == saved.profiles[beforeCallbackFailure])

-- Logical clone copies all five variants and hidden keys never become labels.
saved.profiles[manager:GetAceKey(raidID, "OPEN_WORLD")].marker = "open"
saved.profiles[manager:GetAceKey(raidID, "PVP")].marker = "pvp"
local copiedID, createCode = manager:CreateProfile("Mythic Copy", raidID)
assert(copiedID and createCode == "ok")
assert(manager:GetProfileName(copiedID) == "Mythic Copy")
assert(saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].marker == "open")
assert(saved.profiles[manager:GetAceKey(copiedID, "PVP")].marker == "pvp")
for _, catalogRecord in ipairs(manager:GetCatalog()) do
    assert(not catalogRecord.name:match("^DCRPM:"))
end

-- Failed activation rolls back the catalog and all five raw variants.
local expectedCount = #manager:GetCatalog()
failSetKey = "DCRPM:profile-5:PVP"
local failedID = manager:CreateProfile("Rollback Probe")
failSetKey = nil
assert(failedID == nil)
assert(#manager:GetCatalog() == expectedCount)
assert(manager:FindProfileID("Rollback Probe") == nil)

-- A runtime refresh failure rolls a five-variant logical copy back in place.
local logicalCopyBefore = saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].marker
saved.profiles[manager:GetAceKey(raidID, "OPEN_WORLD")].marker = "copy-should-roll-back"
failConfiguration = true
assert(not manager:CopyProfile(copiedID, raidID))
failConfiguration = false
assert(saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].marker == logicalCopyBefore)

-- Per-environment copy and preset reset affect exactly one variant.
local copiedRaid = saved.profiles[manager:GetAceKey(copiedID, "RAID")]
local copiedDungeon = saved.profiles[manager:GetAceKey(copiedID, "DUNGEON")]
copiedRaid.onlyRaid = 7
copiedRaid.CureBindingMode = "MANUAL"
copiedRaid.CureBindingManual = { ["spell:2006"] = "alt-%s1" }
copiedDungeon.onlyDungeon = 9
assert(manager:CopyEnvironment(copiedID, "DUNGEON", copiedID, "RAID"))
assert(copiedDungeon.onlyRaid == 7 and copiedDungeon.onlyDungeon == nil)
assert(copiedDungeon.CureBindingMode == "MANUAL")
assert(copiedDungeon.CureBindingManual["spell:2006"] == "alt-%s1")
assert(manager:ResetEnvironment(copiedID, "DUNGEON"))
assert(copiedDungeon.onlyRaid == nil)
assert(copiedDungeon.CooldownOverlay121Opacity == 0.60)
assert(copiedDungeon.CureBindingMode == "AUTO")
assert(next(copiedDungeon.CureBindingManual) == nil)
assert(copiedRaid.onlyRaid == 7)

-- Full logical import is all-or-nothing at its validation boundary.
local exported = assert(manager:ExportLogicalProfile(copiedID))
exported.variants.OPEN_WORLD.CureBindingMode = "MANUAL"
exported.variants.OPEN_WORLD.CureBindingManual = { ["spell:527"] = "ctrl-%s2" }
exported.variants.OPEN_WORLD.imported = true
exported.variants.PVP.imported = true
assert(manager:ImportLogicalProfile(copiedID, exported.variants, "AUTO"))
assert(saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].imported == true)
assert(saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].CureBindingManual["spell:527"] == "ctrl-%s2")
assert(saved.profiles[manager:GetAceKey(copiedID, "PVP")].imported == true)
local openBefore = saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].imported
exported.variants.RAID = nil
assert(not manager:ImportLogicalProfile(copiedID, exported.variants, "AUTO"))
assert(saved.profiles[manager:GetAceKey(copiedID, "OPEN_WORLD")].imported == openBefore)

assert(manager:RenameProfile(copiedID, "Renamed Mythic"))
assert(manager:GetProfileName(copiedID) == "Renamed Mythic")
assert(not manager:RenameProfile("default", "Renamed Default"))
local utf8WithinLimit = string.rep("é", 24)
local utf8OverLimit = string.rep("é", 25)
assert(manager:CreateProfile(utf8WithinLimit))
local invalidID, invalidCode = manager:CreateProfile(utf8OverLimit)
assert(invalidID == nil and invalidCode == "invalid-name")

-- Deletion removes every variant and clears online/offline assignments.
local keysToDelete = {}
for _, environment in ipairs(manager.ENVIRONMENT_ORDER) do
    keysToDelete[#keysToDelete + 1] = manager:GetAceKey(copiedID, environment)
end
local offline = manager.data.selection.characters["Alt - Test Realm"]
offline.profileID = copiedID
offline.specs["index:2"] = copiedID
manager.data.selection.account = copiedID
assert(manager:DeleteProfile(copiedID))
assert(manager:FindProfileID("Renamed Mythic") == nil)
assert(manager.data.selection.account == "default")
assert(offline.profileID == nil and offline.specs["index:2"] == nil)
for _, key in ipairs(keysToDelete) do assert(saved.profiles[key] == nil) end
assert(not manager:DeleteProfile("default"))

assert(db:SetDualSpecEnabled(true))
assert(db:SetDualSpecProfile(manager:GetAceKey(healerID, "RAID"), 1))
assert(manager:FindProfileID(db:GetDualSpecProfile(1)) == healerID)
assert(saved.namespaces["LibDualSpec-1.0"].char == dualSpecOriginal)
assert(notificationCount() > 0)

while #manager:GetCatalog() < 50 do
    local id, code = manager:CreateProfile("Limit " .. #manager:GetCatalog())
    assert(id, code)
end
local limitID, limitCode = manager:CreateProfile("One Too Many")
assert(limitID == nil and limitCode == "profile-limit")

local future = {
    profiles = { Future = { value = 9 } },
    profileKeys = { ["Tester - Test Realm"] = "Future" },
    profileManager = { schemaVersion = 99, opaque = { keep = true } },
}
local futureManager = newManager(future)
local futureMetadata = future.profileManager
assert(futureManager:IsReadOnly())
assert(future.profileManager == futureMetadata)
assert(future.profileManager.opaque.keep == true)
assert(future.profiles.Future.value == 9)
assert(not futureManager:SetEnvironmentMode("RAID"))
assert(not futureManager:CreateProfile("Blocked"))

local schemaOne = {
    profiles = { Healer = { Scan_Pets = false }, Raid = { Scan_Pets = true } },
    profileKeys = { ["Tester - Test Realm"] = "Healer" },
    profileManager = {
        schemaVersion = 1,
        accountDefault = "Raid",
        characterAssignments = { ["Tester - Test Realm"] = "Healer" },
        specializationAssignments = { ["Tester - Test Realm"] = { [1] = "Raid" } },
    },
}
local schemaOneManager = newManager(schemaOne)
local schemaOneHealer = assert(schemaOneManager:FindProfileID("Healer"))
local schemaOneRaid = assert(schemaOneManager:FindProfileID("Raid"))
assert(schemaOne.profileManager.selection.account == schemaOneRaid)
assert(schemaOne.profileManager.selection.characters["Tester - Test Realm"].profileID == schemaOneHealer)
assert(schemaOne.profileManager.selection.characters["Tester - Test Realm"].specs["index:1"] == schemaOneRaid)
assert(schemaOne.profiles.Healer.Scan_Pets == false)

if arg and arg[1] == "--self-test-failure" then
    error("intentional profile-manager harness failure")
end

io.write("PASS: five full environment variants, migration/idempotency/repair, pets-MUF isolation, auto/manual selection, combat deferral, preview restore, transactional CRUD, presets, hidden keys, limits, IO contract, LibDualSpec and future-schema safety\n")
