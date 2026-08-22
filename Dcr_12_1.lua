--[[
    Decursive WoW 12.1 compatibility adapter.

    Additive compatibility layer for Decursive 11.0.10.
    It preserves the original Decursive secure MUFs/options/bindings while:
      * using Blizzard's managed AuraContainer path for dispellable harmful auras
      * avoiding reads of protected aura details
      * providing a 12.1-safe dispel cooldown overlay using only Decursive-owned mutable frames

    The addon never reads aura names, dispel types, durations, stacks, or
    visibility state from managed aura buttons. Blizzard owns that state.
--]]

local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if not D or not DC or not DC.TWELVEONE then return end

local _G = _G
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local C_Timer = _G.C_Timer
local C_Spell = _G.C_Spell
local C_UnitAuras = _G.C_UnitAuras
local unpack = _G.unpack
local pairs = _G.pairs
local type = _G.type
local tostring = _G.tostring
local UnitClass = _G.UnitClass
local UnitInRange = _G.UnitInRange
local canaccessvalue = _G.canaccessvalue or function(_) return true end
local issecretvalue = _G.issecretvalue
local CreateColor = _G.CreateColor
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetBuildInfo = _G.GetBuildInfo
local GetTime = _G.GetTime
local IsInInstance = _G.IsInInstance

local PATCH_VERSION = "v@project-version@"

local function safe(label, fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        if D and D.errln then D:errln("12.1 compatibility:", label, a) end
        return false
    end
    return true, a, b, c
end

-- ---------------------------------------------------------------------------
-- Automatic DandersFrames dispel-detection provider
-- ---------------------------------------------------------------------------
-- This integration has one deliberately narrow contract:
--   * DandersFrames owns only the Blizzard-managed aura carrier/filtering that
--     tells us whether a unit has a dispel need matching a Decursive cure priority.
--   * Decursive owns MUFs, spell/binding selection, cooldown overlays/timers,
--     priorities, secure clicks and every other behavior. When DandersFrames is
--     active, the per-MUF status light also mirrors DandersFrames' live range
--     result; true LoS still has no continuous DandersFrames/public WoW query and
--     therefore remains driven by Decursive's actual failed-cast feedback. While
--     this provider is active, one dedicated DandersFrames behavior profile is used.
--
-- Provider selection is latched for the session because protected AuraContainer
-- topology must not be swapped live.  On the first load where the player has never
-- made an explicit choice, DandersFrames is enabled by default when its public
-- AuraContainer API is available.  Once the player uses the integration toggle,
-- that preference is preserved and controls future sessions.  Native Blizzard-
-- managed detection is always the fallback when DandersFrames is disabled or
-- unavailable.
local PROVIDER_NATIVE = "NATIVE"
local PROVIDER_DANDERS = "DANDERSFRAMES"
local detectionProviderSession
local detectionProviderConfiguredAtLatch
local dandersAutoDetectedAtLatch = false
local dandersProviderFailureReason
local dandersProviderHardFailed = false
local dandersProviderOperational = false
local dandersProviderWarned = false

local function configuredDandersIntegration()
    return D.profile and D.profile.DandersFramesDispelIntegrationEnabled == true or false
end

local function dandersPreferenceWasExplicitlySet()
    return D.profile and D.profile.DandersFramesDispelIntegrationUserSet == true or false
end

local function tryLoadDandersFrames()
    if _G.DandersFrames then return true end
    if InCombatLockdown() then return false end
    local api = _G.C_AddOns
    if api and type(api.LoadAddOn) == "function" then
        pcall(api.LoadAddOn, "DandersFrames")
    elseif type(_G.LoadAddOn) == "function" then
        pcall(_G.LoadAddOn, "DandersFrames")
    end
    return _G.DandersFrames ~= nil
end

local function getDandersAuraFactory(allowProbe)
    local DF = _G.DandersFrames
    if type(DF) ~= "table" then return nil, nil, "DandersFrames is not loaded." end
    local factory = DF.AuraContainer
    if type(factory) ~= "table" or type(factory.Create) ~= "function" then
        return nil, DF, "DandersFrames.AuraContainer public API is unavailable."
    end
    if type(factory.IsSupported) == "function" and allowProbe ~= false and not InCombatLockdown() then
        local ok, supported = pcall(factory.IsSupported)
        if not ok or supported ~= true then
            return nil, DF, "DandersFrames AuraContainer API is not supported by this client/build."
        end
    end
    return factory, DF
end

local function latchDetectionProvider()
    if detectionProviderSession then return detectionProviderSession end

    -- OptionalDeps normally causes an enabled DandersFrames to load before us,
    -- but explicitly try to load it as well so late/on-demand configurations are
    -- detected whenever Blizzard permits it.
    local loaded = tryLoadDandersFrames()
    local factory, _, reason
    if loaded then
        factory, _, reason = getDandersAuraFactory(not InCombatLockdown())
    end

    dandersAutoDetectedAtLatch = loaded and factory ~= nil

    -- First-run/default behavior: default to native detection regardless of
    -- whether DandersFrames is installed and usable. DandersFrames integration
    -- is opt-in only -- having it installed should never silently switch the
    -- provider away from native (native is what Decursive's own features,
    -- like the debuff-identity tooltip, are built against). Do NOT mark this
    -- as a user choice; the player can still explicitly enable it later.
    if D.profile and not dandersPreferenceWasExplicitlySet() then
        D.profile.DandersFramesDispelIntegrationEnabled = false
    end

    detectionProviderConfiguredAtLatch = configuredDandersIntegration()

    if detectionProviderConfiguredAtLatch and dandersAutoDetectedAtLatch then
        detectionProviderSession = PROVIDER_DANDERS
        -- The provider and visual-order mirror are intentionally selected
        -- together: if DandersFrames is selected, Decursive's MUFs follow the
        -- same unit order as the DandersFrames unit frames.
        if type(D.RegisterDandersFramesOrderSync) == "function" then
            pcall(D.RegisterDandersFramesOrderSync, D)
        end
    else
        detectionProviderSession = PROVIDER_NATIVE
        -- Missing/disabled/unsupported DandersFrames is not fatal; native
        -- Blizzard-managed detection is the expected fallback.
        dandersProviderFailureReason = detectionProviderConfiguredAtLatch and (loaded and reason or "DandersFrames is not loaded.") or nil
    end

    return detectionProviderSession
end

function D:Get121DispelDetectionProviderStatus()
    local provider = latchDetectionProvider()
    local configured = configuredDandersIntegration()
    local factory, DF, reason = getDandersAuraFactory(not InCombatLockdown())
    local available = factory ~= nil
    local active = provider == PROVIDER_DANDERS and available and not dandersProviderHardFailed
    local reloadRequired = (configured and provider ~= PROVIDER_DANDERS and available)
        or ((not configured) and provider == PROVIDER_DANDERS)
    local version = DF and (DF.VERSION or DF.version) or nil
    local displayName
    if provider == PROVIDER_DANDERS then
        displayName = active and "DandersFrames" or "DandersFrames (unavailable)"
    else
        displayName = "Native Blizzard-managed"
    end
    return {
        configuredEnabled = configured,
        autoDetected = dandersAutoDetectedAtLatch,
        automaticSelection = not dandersPreferenceWasExplicitlySet(),
        userSet = dandersPreferenceWasExplicitlySet(),
        configuredAtLatch = detectionProviderConfiguredAtLatch,
        sessionProvider = provider,
        available = available,
        active = active,
        reloadRequired = reloadRequired,
        version = version,
        displayName = displayName,
        operational = dandersProviderOperational,
        reason = dandersProviderFailureReason or reason,
    }
end

function D:Is121DandersFramesDetectionActive()
    local status = self:Get121DispelDetectionProviderStatus()
    return status.sessionProvider == PROVIDER_DANDERS and status.active == true
end

local function warnDandersUnavailable(reason)
    dandersProviderFailureReason = reason or dandersProviderFailureReason or "Unknown DandersFrames provider error."
    dandersProviderHardFailed = true
    dandersProviderOperational = false
    if dandersProviderWarned then return end
    dandersProviderWarned = true
    if D.Println then
        D:Println("|cFFFF5555Zhaohu's Decursive: the automatically selected DandersFrames provider became unavailable.|r")
        D:Println("|cFFFFFF00" .. tostring(dandersProviderFailureReason) .. " Protected providers cannot be swapped mid-session; fix/enable DandersFrames or disable the addon and reload to return to native detection.|r")
    end
end


-- ---------------------------------------------------------------------------
-- Environment profiles (Raid / Mythic+ / Dungeon / PvP / Open World)
-- ---------------------------------------------------------------------------

local C_ChallengeMode = _G.C_ChallengeMode

local ENVIRONMENT_NAMES = {
    RAID = "Raid",
    MYTHIC_PLUS = "Mythic+",
    DUNGEON = "Dungeon",
    PVP = "PvP",
    OPEN_WORLD = "Open World",
    DANDERSFRAMES = "DandersFrames",
}

local ENVIRONMENT_DEFAULTS = {
    DANDERSFRAMES = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .62,
        CooldownOverlay121Numbers = true,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    RAID = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .45,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .50,
        CooldownOverlay121Numbers = false,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = false,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    MYTHIC_PLUS = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .70,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .70,
        CooldownOverlay121Numbers = true,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    DUNGEON = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .60,
        CooldownOverlay121Numbers = true,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    PVP = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .75,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .65,
        CooldownOverlay121Numbers = true,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    OPEN_WORLD = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
        OutOfRange121Color = {1, 1, 0},
        LineOfSight121Enabled = true,
        LineOfSight121Color = {1, .28, .12},
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .62,
        CooldownOverlay121Numbers = true,
        Detection121Mode = "STRICT_MANAGED",
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
}

local function copyColor(c)
    return { (c and c[1]) or 1, (c and c[2]) or 1, (c and c[3]) or 0 }
end

local function ensureEnvironmentProfiles()
    if not D.profile then return end
    D.profile.Environment121Profiles = D.profile.Environment121Profiles or {}
    for key, defaults in pairs(ENVIRONMENT_DEFAULTS) do
        local env = D.profile.Environment121Profiles[key]
        if type(env) ~= "table" then
            env = {}
            D.profile.Environment121Profiles[key] = env
        end
        for setting, value in pairs(defaults) do
            if env[setting] == nil then
                env[setting] = type(value) == "table" and copyColor(value) or value
            end
        end
        -- v10.41: 12.1 no longer exposes a legacy detection policy. Migrate
        -- profiles created by earlier patch builds to the managed-only path.
        env.Detection121Mode = "STRICT_MANAGED"
    end

    -- One-time migration: preserve the user's pre-v10.38 global visual settings
    -- as the initial Open World profile instead of silently discarding them.
    if not D.profile.Environment121ProfilesInitialized then
        local ow = D.profile.Environment121Profiles.OPEN_WORLD
        if D.profile.OutOfRange121Enabled ~= nil then ow.OutOfRange121Enabled = D.profile.OutOfRange121Enabled end
        if type(D.profile.OutOfRange121DimAmount) == "number" then ow.OutOfRange121DimAmount = D.profile.OutOfRange121DimAmount end
        if type(D.profile.OutOfRange121Color) == "table" then ow.OutOfRange121Color = copyColor(D.profile.OutOfRange121Color) end
        if D.profile.LineOfSight121Enabled ~= nil then ow.LineOfSight121Enabled = D.profile.LineOfSight121Enabled end
        if type(D.profile.LineOfSight121Color) == "table" then ow.LineOfSight121Color = copyColor(D.profile.LineOfSight121Color) end
        if type(D.profile.LineOfSight121Opacity) == "number" then ow.LineOfSight121Opacity = D.profile.LineOfSight121Opacity end
        if type(D.profile.LineOfSight121HoldSeconds) == "number" then ow.LineOfSight121HoldSeconds = D.profile.LineOfSight121HoldSeconds end
        if D.profile.CooldownOverlay121Enabled ~= nil then ow.CooldownOverlay121Enabled = D.profile.CooldownOverlay121Enabled end
        if type(D.profile.CooldownOverlay121Opacity) == "number" then ow.CooldownOverlay121Opacity = D.profile.CooldownOverlay121Opacity end
        if D.profile.CooldownOverlay121Numbers ~= nil then ow.CooldownOverlay121Numbers = D.profile.CooldownOverlay121Numbers end
        D.profile.Environment121ProfilesInitialized = true
    end

    -- v11 alpha.11 one-time behavior migration: cooldown feedback now belongs
    -- on the OTHER still-dispellable targets, never on the square just cleansed.
    -- Enable that remaining-target model for existing environment profiles once;
    -- users can still turn it off per environment afterward.
    if not D.profile.RemainingTargetCooldown121Migrated then
        for _, env in pairs(D.profile.Environment121Profiles) do
            if type(env) == "table" then
                env.SharedPriorityCooldown121Enabled = true
                env.ClearCleansedTarget121Enabled = true
            end
        end
        D.profile.RemainingTargetCooldown121Migrated = true
    end
end

local function getEnvironmentModeSetting()
    -- Provider selection is session-latched. Once DandersFrames owns dispel
    -- detection, behavior also uses one dedicated DandersFrames profile rather
    -- than switching underneath it as the player moves between content types.
    if latchDetectionProvider() == PROVIDER_DANDERS then
        return "DANDERSFRAMES"
    end
    local mode = D.profile and D.profile.Environment121Mode or "AUTO"
    if mode ~= "AUTO" and mode ~= "RAID" and mode ~= "MYTHIC_PLUS" and mode ~= "DUNGEON" and mode ~= "PVP" and mode ~= "OPEN_WORLD" then
        mode = "AUTO"
    end
    return mode
end

local function detectAutomaticEnvironment()
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance == true then
            if instanceType == "pvp" or instanceType == "arena" then
                return "PVP"
            end
            if instanceType == "raid" then
                return "RAID"
            end
            if instanceType == "party" then
                if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
                    local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
                    if ok and type(mapID) == "number" and mapID > 0 then
                        return "MYTHIC_PLUS"
                    end
                end
                -- Follower, Normal, Heroic, Timewalking and Mythic-0 dungeons
                -- are all party instances without an active Challenge Mode map.
                return "DUNGEON"
            end
        end
    end
    return "OPEN_WORLD"
end

function D:Get121EnvironmentMode()
    local setting = getEnvironmentModeSetting()
    local active = setting == "AUTO" and detectAutomaticEnvironment() or setting
    return setting, active, ENVIRONMENT_NAMES[active] or active
end

function D:Is121PvPRestrictedMode()
    local _, active = self:Get121EnvironmentMode()
    return active == "PVP"
end

-- Compatibility alias retained for existing v10.36/v10.37 callers.
function D:Get121PvPProtectedAuraMode()
    local setting, active = self:Get121EnvironmentMode()
    return setting, active == "PVP"
end

local function getActiveEnvironmentProfile()
    ensureEnvironmentProfiles()
    local _, active = D:Get121EnvironmentMode()
    return D.profile and D.profile.Environment121Profiles and D.profile.Environment121Profiles[active], active
end

function D:Get121ActiveBehaviorProfile()
    local env, active = getActiveEnvironmentProfile()
    return env, active, ENVIRONMENT_NAMES[active] or active
end

function D:Should121SuppressLegacyAuraColor()
    -- WoW 12.1 can make aura data fully secret in combat/encounters/M+/PvP.
    -- Keep the 12.1 runtime on Blizzard-managed aura filtering everywhere so
    -- no display behavior depends on Lua-readable aura details.
    return DC.TWELVEONE == true
end

-- Legacy aura enumeration is intentionally disabled on Mainline 12.1.
-- The original scanner remains in the addon for older clients/test fixtures,
-- but real 12.1 dispel detection is owned by AuraContainer/AuraButton.
function D:Can121UseLegacyScanning()
    return not DC.TWELVEONE
end

function D:Is121SharedPriorityCooldownEnabled()
    local env = getActiveEnvironmentProfile()
    return env and env.SharedPriorityCooldown121Enabled == true or false
end

local function applyActiveEnvironmentProfile()
    if not D.profile then return end
    local env = getActiveEnvironmentProfile()
    if not env then return end
    D.profile.OutOfRange121Enabled = env.OutOfRange121Enabled ~= false
    D.profile.OutOfRange121DimAmount = env.OutOfRange121DimAmount
    D.profile.OutOfRange121Color = copyColor(env.OutOfRange121Color)
    D.profile.LineOfSight121Enabled = env.LineOfSight121Enabled ~= false
    D.profile.LineOfSight121Color = copyColor(env.LineOfSight121Color or {1, .28, .12})
    D.profile.LineOfSight121Opacity = env.LineOfSight121Opacity or .78
    D.profile.LineOfSight121HoldSeconds = env.LineOfSight121HoldSeconds or 2.5
    D.profile.CooldownOverlay121Enabled = env.CooldownOverlay121Enabled ~= false
    D.profile.CooldownOverlay121Opacity = env.CooldownOverlay121Opacity
    D.profile.CooldownOverlay121Numbers = env.CooldownOverlay121Numbers ~= false
    D.profile.Detection121Mode = env.Detection121Mode or "STRICT_MANAGED"
    D.profile.CooldownPriority2Border121Enabled = env.SecondaryAffliction121Enabled ~= false
    D.profile.CooldownPriority2Pulse121Enabled = env.SecondaryAffliction121Pulse ~= false
    D.profile.SharedPriorityCooldown121Enabled = env.SharedPriorityCooldown121Enabled == true
    D.profile.ClearCleansedTarget121Enabled = env.ClearCleansedTarget121Enabled ~= false
    D.profile.EnvironmentChat121Enabled = env.EnvironmentChat121Enabled ~= false
end

function D:Set121EnvironmentVisualSetting(key, value)
    if not D.profile then return end
    local env = getActiveEnvironmentProfile()
    if env then env[key] = type(value) == "table" and copyColor(value) or value end
    D.profile[key] = type(value) == "table" and copyColor(value) or value
end

function D:Reset121EnvironmentProfile()
    if not D.profile then return end
    ensureEnvironmentProfiles()
    local _, active = self:Get121EnvironmentMode()
    local defaults = ENVIRONMENT_DEFAULTS[active] or ENVIRONMENT_DEFAULTS.OPEN_WORLD
    local env = D.profile.Environment121Profiles[active]
    if not env then return end
    for key, value in pairs(defaults) do
        env[key] = type(value) == "table" and copyColor(value) or value
    end
    applyActiveEnvironmentProfile()
    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
    if D.Set121OutOfRangeEnabled then D:Set121OutOfRangeEnabled(D.profile.OutOfRange121Enabled ~= false) end
    if D.Apply121LineOfSightAppearance then D:Apply121LineOfSightAppearance() end
    if D.Set121LineOfSightEnabled then D:Set121LineOfSightEnabled(D.profile.LineOfSight121Enabled ~= false) end
    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
    if D.Set121CooldownOverlayEnabled then D:Set121CooldownOverlayEnabled(D.profile.CooldownOverlay121Enabled ~= false) end
end

local lastEnvironment121 = nil
local lastPvPRestrictedModeActive = nil

local function updateEnvironmentState(announce)
    local _, active, displayName = D:Get121EnvironmentMode()
    local pvpActive = active == "PVP"
    local environmentChanged = lastEnvironment121 ~= nil and active ~= lastEnvironment121
    local pvpChanged = lastPvPRestrictedModeActive ~= nil and pvpActive ~= lastPvPRestrictedModeActive

    if lastEnvironment121 == nil then
        lastEnvironment121 = active
        lastPvPRestrictedModeActive = pvpActive
        applyActiveEnvironmentProfile()
        return false, active
    end

    if environmentChanged then
        lastEnvironment121 = active
        applyActiveEnvironmentProfile()
        if announce and D.Println and (not D.profile or D.profile.EnvironmentChat121Enabled ~= false) then
            D:Println("|cFFFFFF00Decursive: Environment mode changed to " .. (displayName or active) .. "|r")
        end
    end

    if pvpChanged then
        lastPvPRestrictedModeActive = pvpActive
        if announce and D.Println and (not D.profile or D.profile.EnvironmentChat121Enabled ~= false) then
            if pvpActive then
                D:Println("|cFFFFFF00Decursive: PvP protected-aura mode ENABLED|r")
            else
                D:Println("|cFFFFFF00Decursive: PvP protected-aura mode DISABLED|r")
            end
        end
    end

    return environmentChanged or pvpChanged, active
end

local function refreshEnvironmentVisuals(announceTransition)
    updateEnvironmentState(announceTransition == true)
    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
    if D.Set121OutOfRangeEnabled and D.profile then
        D:Set121OutOfRangeEnabled(D.profile.OutOfRange121Enabled ~= false)
    end
    if D.Apply121LineOfSightAppearance then D:Apply121LineOfSightAppearance() end
    if D.Set121LineOfSightEnabled and D.profile then
        D:Set121LineOfSightEnabled(D.profile.LineOfSight121Enabled ~= false)
    end
    if D.Set121CooldownOverlayEnabled and D.profile then
        D:Set121CooldownOverlayEnabled(D.profile.CooldownOverlay121Enabled ~= false)
    end
    if not D.MicroUnitF or not D.MicroUnitF.ExistingPerUNIT then return end
    for unit, MF in pairs(D.MicroUnitF.ExistingPerUNIT) do
        if MF and MF.Update then
            safe("environment MUF refresh", MF.Update, MF, false, false, true)
        elseif D.MicroUnitF.UpdateMUFUnit then
            safe("environment MUF unit refresh", D.MicroUnitF.UpdateMUFUnit, D.MicroUnitF, unit, true)
        end
    end
end

function D:Refresh121EnvironmentVisuals(announce)
    refreshEnvironmentVisuals(announce == true)
end

function D:Set121EnvironmentMode(mode)
    if latchDetectionProvider() == PROVIDER_DANDERS then
        -- Keep the user's native environment preference untouched. It resumes
        -- automatically when DandersFrames is not available on the next UI load.
        return
    end
    if mode ~= "AUTO" and mode ~= "RAID" and mode ~= "MYTHIC_PLUS" and mode ~= "DUNGEON" and mode ~= "PVP" and mode ~= "OPEN_WORLD" then return end
    if not D.profile then return end
    D.profile.Environment121Mode = mode
    refreshEnvironmentVisuals(true)
end

-- Compatibility setter: map old PvP choices into the new environment system.
function D:Set121PvPProtectedAuraMode(mode)
    if mode == "ALWAYS_ON" then
        self:Set121EnvironmentMode("PVP")
    elseif mode == "ALWAYS_OFF" then
        self:Set121EnvironmentMode("OPEN_WORLD")
    else
        self:Set121EnvironmentMode("AUTO")
    end
end

local managedAuraButtons = setmetatable({}, { __mode = "k" })
local cooldownMUFs = setmetatable({}, { __mode = "k" })
local rangeMUFs = setmetatable({}, { __mode = "k" })
local lineOfSightMUFs = setmetatable({}, { __mode = "k" })
local managedCooldownDurationObjects = { [1] = nil, [2] = nil, [3] = nil }

local function getAlertColor()
    local c = D.profile and D.profile.MF_colors and D.profile.MF_colors[1]
    if type(c) == "table" then
        return c[1] or .8, c[2] or 0, c[3] or 0, c[4] or 1
    end
    return .8, 0, 0, 1
end

-- ---------------------------------------------------------------------------
-- WoW 12.1 MUF square-state sound trigger
-- ---------------------------------------------------------------------------
-- The managed AuraButton that paints a MUF is in Blizzard's forbidden aura
-- partition. Addon Lua must not install OnShow/OnHide handlers on it or read
-- IsShown(). Instead, mirror the same player-dispellable condition through the
-- public opaque aura-instance-ID API. Aura instance IDs are non-secret; no aura
-- name, spell ID, dispel type, duration, stack count or managed-button state is
-- inspected here.
--
-- In WoW 12.1, HARMFUL|RAID is Blizzard's direct "the active player can
-- dispel this harmful aura" filter. Decursive's managed MUF slots use the
-- broader RAID_PLAYER_DISPELLABLE pool plus the player's configured dispel-type
-- candidate filters; the resulting actionable condition is the same one we need
-- for audio. A unit moves clean -> afflicted when this player-dispellable set
-- goes from empty to non-empty. That transition requests Decursive's existing
-- per-MUF transition alert. Each MUF owns its own clean/afflicted state: a
-- clean -> afflicted transition plays immediately. The normal group burst-ignore
-- window is intentionally bypassed for this square-linked alert path.
-- WoW 12.1 native aura-sound adapter.
--
-- The ManagedAuraContainer that paints the red/blue MUF square owns protected
-- aura visibility. Addon Lua cannot safely inspect that state in combat. Sound
-- notifications therefore use Blizzard's C_UnitAuras.AddAuraSound engine for
-- known/learned dispellable spell IDs. Blizzard detects the protected aura and
-- plays the selected sound; Decursive never reads the protected AuraButton.
function D:Is121MUFStateSoundEngineAvailable()
    return C_UnitAuras ~= nil
        and type(C_UnitAuras.AddAuraSound) == "function"
        and type(C_UnitAuras.RemoveAuraSound) == "function"
end

-- Compatibility names retained because other v11 code calls them when MUFs are
-- created/retargeted. They no longer inspect aura state.
function D:Refresh121MUFStateSoundUnit(_unit, _suppressAlert)
    return nil
end

function D:Refresh121MUFStateSoundBaseline()
    if type(self.RefreshProtectedAuraSounds) == "function" then
        self:RefreshProtectedAuraSounds("MUF baseline refresh")
    end
end

-- UNIT_AURA is intentionally a no-op for sound on 12.1. The Blizzard aura-sound
-- registry receives the protected application directly.
function D:UNIT_AURA(_event, _unit, _auraUpdateInfo)
end

-- Keep the Blizzard registrations synchronized with roster/spec/world changes.
-- No protected aura data is queried here; this only rebuilds registrations for
-- public unit tokens and known public spell IDs.
local auraSoundRegistryEventFrame = CreateFrame("Frame")
auraSoundRegistryEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
auraSoundRegistryEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
auraSoundRegistryEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
auraSoundRegistryEventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
auraSoundRegistryEventFrame:SetScript("OnEvent", function(_, event)
    if not D.DcrFullyInitialized or type(D.RefreshProtectedAuraSounds) ~= "function" then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 1.0 or 0.20, function()
            if D.DcrFullyInitialized then D:RefreshProtectedAuraSounds(event) end
        end)
    else
        D:RefreshProtectedAuraSounds(event)
    end
end)

-- Blizzard-managed dispellable aura indicator
-- ---------------------------------------------------------------------------

local initializedManagedAuraButtons = setmetatable({}, { __mode = "k" })

-- Priority colors are owned by Decursive's existing MUF color table.  The
-- managed-aura layer uses these only to build Blizzard ColorCurves; addon Lua
-- never reads an aura's protected dispel type.
local function getPriorityColor(priority)
    local c = D.profile and D.profile.MF_colors and D.profile.MF_colors[priority]
    if type(c) == "table" then
        return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
    end
    if priority == 1 then return .8, 0, 0, 1 end
    if priority == 2 then return .25, .45, 1, 1 end
    return .7, .25, 1, 1
end

-- Blizzard 12.1 supports secret-safe dispel visualization through
-- CustomAuraButton:AddDispelTypeTexture().  The engine evaluates the protected
-- aura dispel type privately.  The visual model here is based on simultaneous
-- dispellable aura *slots*, not fixed priority layers:
--   first dispellable aura  -> inner square, colored for that aura's configured priority
--   second dispellable aura -> one pulsing border, colored for that aura's configured priority
--
-- A lone Priority #2/#3 affliction still owns the inner square. The border is
-- reserved only for the rare case where a second simultaneous dispellable aura exists.
local managedAnyPriorityCurve
local managedAnyPriorityCurveReady = false

local function newColor(r, g, b, a)
    if _G.CreateColor then return _G.CreateColor(r, g, b, a) end
    return nil
end

local function ensureManagedAnyPriorityCurve()
    if managedAnyPriorityCurveReady then return true end
    if not _G.C_CurveUtil or not _G.C_CurveUtil.CreateColorCurve or not _G.Enum or not _G.Enum.LuaCurveType then
        return false
    end
    managedAnyPriorityCurve = _G.C_CurveUtil.CreateColorCurve()
    managedAnyPriorityCurve:SetType(_G.Enum.LuaCurveType.Step)
    managedAnyPriorityCurveReady = true
    return true
end

local function updateManagedAnyPriorityCurve()
    if not ensureManagedAnyPriorityCurve() then return false end
    managedAnyPriorityCurve:ClearPoints()
    managedAnyPriorityCurve:AddPoint(0, newColor(0, 0, 0, 0))

    local status = D.Status
    local friendlyTypes = { DC.MAGIC, DC.CURSE, DC.DISEASE, DC.POISON, DC.BLEED }
    for _, affType in ipairs(friendlyTypes) do
        local bt = DC.DTtoBT and DC.DTtoBT[affType]
        if bt and bt > 0 then
            local spellName = status and status.CuringSpells and status.CuringSpells[affType]
            local configuredPriority = spellName and status.CuringSpellsPrio and status.CuringSpellsPrio[spellName]
            if type(configuredPriority) == "number" and configuredPriority >= 1 and configuredPriority <= 3 then
                local r, g, b, a = getPriorityColor(configuredPriority)
                managedAnyPriorityCurve:AddPoint(bt, newColor(r, g, b, a))
            else
                managedAnyPriorityCurve:AddPoint(bt, newColor(0, 0, 0, 0))
            end
        end
    end
    return true
end

local function makeManagedBorderStrip(owner, anchor, side, thickness, inset)
    local t = owner:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    inset = inset or 0
    anchor = anchor or owner
    if side == "TOP" then
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT", -inset, inset)
        t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", inset, inset)
        t:SetHeight(thickness)
    elseif side == "BOTTOM" then
        t:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -inset, -inset)
        t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", inset, -inset)
        t:SetHeight(thickness)
    elseif side == "LEFT" then
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT", -inset, inset)
        t:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -inset, -inset)
        t:SetWidth(thickness)
    else
        t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", inset, inset)
        t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", inset, -inset)
        t:SetWidth(thickness)
    end
    return t
end

local function startManagedBorderPulse(holder, phase)
    if not holder or not holder.CreateAnimationGroup then return end
    local ag = holder:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(1)
    a1:SetToAlpha(.25)
    a1:SetDuration(.55)
    if a1.SetSmoothing then a1:SetSmoothing("IN_OUT") end
    if phase and a1.SetStartDelay then a1:SetStartDelay(phase) end
    ag:SetLooping("BOUNCE")
    ag:Play()
end

local function registerManagedAnyPriorityTexture(auraButton, texture)
    if not updateManagedAnyPriorityCurve() then return false end
    local styleEnum = _G.Enum and _G.Enum.CustomAuraButtonDispelTypeTextureStyle
    local preserve = styleEnum and styleEnum.PreserveAsset
    if preserve == nil or not auraButton.AddDispelTypeTexture then return false end
    -- v10.35 strict 12.1 priority mapping: use only the compatibility curve
    -- built from Decursive's currently configured friendly cure mappings.
    -- Do not fall back to the legacy/shared dsCurve; an overly broad curve can
    -- assign Priority #1 color to protected auras that are not actually mapped
    -- to that priority.
    local priorityCurve = managedAnyPriorityCurve
    local options = {
        style = preserve,
        showWhenHarmful = true,
        showWhenHelpful = false,
        showWithoutDispelType = false,
        customDispelColorCurve = priorityCurve,
    }
    return safe("AddDispelTypeTexture stacked priority", auraButton.AddDispelTypeTexture, auraButton, texture, options)
end

local function initializeManagedAuraButton(auraButton, visualSlot, visualAnchor, ownerMF)
    if initializedManagedAuraButtons[auraButton] then return end
    initializedManagedAuraButtons[auraButton] = true

    -- initializeFrame is the one guaranteed-safe setup window before Blizzard
    -- applies DenyTaintedAccessWhenAurasAreSecret to the managed button.
    if auraButton.SetSize then auraButton:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20) end
    if auraButton.EnableMouse then safe("AuraButton EnableMouse", auraButton.EnableMouse, auraButton, false) end
    if auraButton.SetMouseClickEnabled then safe("AuraButton mouse clicks", auraButton.SetMouseClickEnabled, auraButton, false) end
    if auraButton.SetMouseMotionEnabled then safe("AuraButton mouse motion", auraButton.SetMouseMotionEnabled, auraButton, false) end

    updateManagedAnyPriorityCurve()
    visualAnchor = visualAnchor or auraButton
    visualSlot = visualSlot or 1

    -- Slot #1 owns the center regardless of whether its protected dispel type
    -- maps to Decursive curing priority 1, 2, or 3. Blizzard supplies the color.
    if visualSlot == 1 then
        local fill = auraButton:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", visualAnchor, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", visualAnchor, "BOTTOMRIGHT", 0, 0)
        fill:SetColorTexture(1, 1, 1, 1)
        registerManagedAnyPriorityTexture(auraButton, fill)

        -- IMPORTANT: once a Texture/Cooldown is handed to CustomAuraButton,
        -- Blizzard marks its relevant visual aspects secret.  Do not attach our
        -- spell-cooldown widgets to this protected aura button and never mutate
        -- managed display objects after initialization.  The managed button owns
        -- only the pre-click afflicted/priority color.
        managedAuraButtons[auraButton] = { slot = 1, fill = fill, MF = ownerMF }
        return
    end

    -- Slot #2 means a second simultaneous dispellable aura exists.  It gets the
    -- first pulsing border in *its own* configured priority color.
    if visualSlot == 2 then
        local holder = CreateFrame("Frame", nil, auraButton)
        holder:SetPoint("TOPLEFT", visualAnchor, "TOPLEFT", 0, 0)
        holder:SetPoint("BOTTOMRIGHT", visualAnchor, "BOTTOMRIGHT", 0, 0)
        holder:EnableMouse(false)
        local border = {
            makeManagedBorderStrip(holder, visualAnchor, "TOP", 2, 0),
            makeManagedBorderStrip(holder, visualAnchor, "BOTTOM", 2, 0),
            makeManagedBorderStrip(holder, visualAnchor, "LEFT", 2, 0),
            makeManagedBorderStrip(holder, visualAnchor, "RIGHT", 2, 0),
        }
        for _, tex in ipairs(border) do registerManagedAnyPriorityTexture(auraButton, tex) end
        if not D.profile or D.profile.CooldownPriority2Pulse121Enabled ~= false then
            startManagedBorderPulse(holder, 0)
        end
        managedAuraButtons[auraButton] = { slot = 2, holder = holder, border = border }
        return
    end

end

-- ---------------------------------------------------------------------------
-- 12.1-safe per-MUF priority cooldown display
-- ---------------------------------------------------------------------------

-- WoW 12.1 can safely let the selected provider gate a visual when a unit has
-- a matching dispel need, while addon Lua must not inspect the protected aura.
-- After a successful cleanse, the clicked MUF clears immediately. The player's
-- public spell cooldown is then shown only on OTHER provider-matched MUFs that
-- still need the same curing priority.


-- ---------------------------------------------------------------------------
-- Per-MUF status lights (v11 alpha.20)
-- ---------------------------------------------------------------------------
-- The original hidden move handle is intentionally untouched.  Every shown MUF
-- gets one dedicated, non-interactive status light centered above the square.
-- The light is one quarter of the MUF's base size and is hidden while idle,
-- appearing only when there's something to flag:
--   gray   = ready / no known castability problem (rendered fully transparent)
--   yellow = outside configured cleanse range
--   red    = a cure attempt failed or post-cast verification still sees the affliction
--   green  = the cure cleared the affliction (three-second confirmation)
-- Yellow wins whenever DandersFrames reports out of range. When in range,
-- red/green transient result feedback wins over normal gray.
-- LoS remains red only after an actual failed cleanse because neither WoW nor
-- DandersFrames exposes a continuous public line-of-sight query.
local statusLightMUFs = setmetatable({}, { __mode = "k" })
local STATUS_READY   = { .34, .34, .34, 0 }
local STATUS_RANGE   = { 1.00, .82, 0.00, 1.00 }
local STATUS_FAILED  = { 1.00, .08, .08, 1.00 }
local STATUS_SUCCESS = { .10, 1.00, .24, 1.00 }
local STATUS_CLEAR   = { 1.00, 1.00, 1.00, 0.00 }

-- DandersFrames' range engine may store a secret boolean in frame.dfInRange.
-- WoW 12.1 allows that value to be passed directly to
-- Texture:SetVertexColorFromBoolean(), so we mirror DF's result without reading,
-- comparing or branching on a protected value.  Alpha.20 uses TWO layers:
--   result/base layer: gray, red, or green when in range; transparent when out
--   range layer:       transparent when in range; yellow when out
-- This makes yellow a secret-safe hard override.  Result feedback cannot paint
-- over an out-of-range DandersFrames status even though Lua never branches on
-- the protected range boolean.
local STATUS_READY_COLOR   = CreateColor and CreateColor(unpack(STATUS_READY)) or nil
local STATUS_RANGE_COLOR   = CreateColor and CreateColor(unpack(STATUS_RANGE)) or nil
local STATUS_FAILED_COLOR  = CreateColor and CreateColor(unpack(STATUS_FAILED)) or nil
local STATUS_SUCCESS_COLOR = CreateColor and CreateColor(unpack(STATUS_SUCCESS)) or nil
local STATUS_CLEAR_COLOR   = CreateColor and CreateColor(unpack(STATUS_CLEAR)) or nil

local function dandersRangeValueForMUF(MF)
    if not MF or not MF.CurrUnit then return nil, false end
    if type(D.Is121DandersFramesDetectionActive) ~= "function" or not D:Is121DandersFramesDetectionActive() then
        return nil, false
    end

    local lookup = _G.DandersFrames_GetFrameForUnit
    if type(lookup) ~= "function" then return nil, false end
    local ok, dfFrame = pcall(lookup, MF.CurrUnit)
    if not ok or not dfFrame then return nil, false end

    local value = dfFrame.dfInRange
    if issecretvalue and issecretvalue(value) then
        return value, true
    end
    if value == true or value == false then
        return value, true
    end
    return nil, false
end

local function statusColorObject(color)
    if color == STATUS_FAILED then return STATUS_FAILED_COLOR end
    if color == STATUS_SUCCESS then return STATUS_SUCCESS_COLOR end
    return STATUS_READY_COLOR
end

-- Native provider range source.  This deliberately mirrors the DandersFrames
-- status-light contract but asks Blizzard directly.  We prefer the actual
-- friendly cure spell Decursive selected for this character; if the spell API
-- has no answer, UnitInRange is used as the fallback.  A 12.1 secret boolean is
-- NEVER inspected here -- it is returned intact and passed directly to
-- Texture:SetVertexColorFromBoolean().
local function resolveNativeRangeSpellID()
    local status = D.Status
    if not status or not status.CuringSpells or not status.FoundSpells or not status.CuringSpellsPrio then return nil end
    local best
    local seen = {}
    for debuffType, spellName in pairs(status.CuringSpells) do
        if (debuffType == DC.MAGIC or debuffType == DC.DISEASE or debuffType == DC.POISON or debuffType == DC.CURSE or debuffType == DC.BLEED) and spellName and not seen[spellName] then
            seen[spellName] = true
            local data = status.FoundSpells[spellName]
            local spellID = data and data[2]
            local prio = status.CuringSpellsPrio[spellName]
            if spellID and spellID > 0 and prio and prio >= 1 and prio <= 3 then
                local better = tonumber(data[4]) or 0
                if not best or better > best.better or (better == best.better and prio < best.prio) then
                    best = { id = spellID, better = better, prio = prio }
                end
            end
        end
    end
    return best and best.id or nil
end

local function nativeRangeValueForMUF(MF)
    if not MF or not MF.CurrUnit then return nil, false end
    if latchDetectionProvider() ~= PROVIDER_NATIVE then return nil, false end
    local unit = MF.CurrUnit
    if unit == "player" then return true, true end

    local value
    local spellID = resolveNativeRangeSpellID()
    if spellID and C_Spell and type(C_Spell.IsSpellInRange) == "function" then
        local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if ok then value = result end
        if issecretvalue and issecretvalue(value) then return value, true end
        if value == true or value == false then return value, true end
        if value == 1 then return true, true end
        if value == 0 then return false, true end
    end

    if UnitInRange then
        local ok, result = pcall(UnitInRange, unit)
        if ok then value = result end
        if issecretvalue and issecretvalue(value) then return value, true end
        if value == true or value == false then return value, true end
        if value == 1 then return true, true end
        if value == 0 then return false, true end
    end
    return nil, false
end

local function applyNativeRangeToStatusLayers(MF, fill, rangeFill, resultColor)
    if not fill or not rangeFill
        or not fill.SetVertexColorFromBoolean
        or not rangeFill.SetVertexColorFromBoolean
        or not STATUS_CLEAR_COLOR or not STATUS_RANGE_COLOR then
        return false
    end
    local inRange, available = nativeRangeValueForMUF(MF)
    if not available then return false end
    local result = statusColorObject(resultColor)
    if not result then return false end
    fill:SetVertexColorFromBoolean(inRange, result, STATUS_CLEAR_COLOR)
    rangeFill:SetVertexColorFromBoolean(inRange, STATUS_CLEAR_COLOR, STATUS_RANGE_COLOR)
    return true
end

local function applyDandersRangeToStatusLayers(MF, fill, rangeFill, resultColor)
    if not fill or not rangeFill
        or not fill.SetVertexColorFromBoolean
        or not rangeFill.SetVertexColorFromBoolean
        or not STATUS_CLEAR_COLOR or not STATUS_RANGE_COLOR then
        return false
    end
    local inRange, available = dandersRangeValueForMUF(MF)
    if not available then return false end

    local result = statusColorObject(resultColor)
    if not result then return false end

    -- DandersFrames is authoritative for distance.  Never inspect inRange here:
    -- pass the possibly-secret boolean directly to Blizzard's widget API.
    -- Out of range = result layer transparent + top range layer yellow.
    fill:SetVertexColorFromBoolean(inRange, result, STATUS_CLEAR_COLOR)
    rangeFill:SetVertexColorFromBoolean(inRange, STATUS_CLEAR_COLOR, STATUS_RANGE_COLOR)
    return true
end

local function resolveStatusMUF(unitOrMF)
    if type(unitOrMF) == "table" then return unitOrMF end
    if type(unitOrMF) == "string" and D.MicroUnitF and D.MicroUnitF.UnitToMUF then
        return D.MicroUnitF.UnitToMUF[unitOrMF]
    end
end

local function statusLightSizeForMF(MF)
    local width = MF and MF.Frame and MF.Frame.GetWidth and MF.Frame:GetWidth() or (DC.MFSIZE or 20)
    if type(width) ~= "number" or width <= 0 then width = DC.MFSIZE or 20 end
    return math.max(3, width * .25)
end

local function statusLightGap()
    if D.MicroUnitF and D.MicroUnitF.GetStatusLightGap then
        return D.MicroUnitF:GetStatusLightGap()
    end
    return math.max(1, (DC.MFSIZE or 20) * .075)
end

local function initializeMUFStatusLight(MF)
    if not MF or not MF.Frame or MF.Decursive121StatusLight then return end

    local light = CreateFrame("Frame", nil, MF.Frame)
    local size = statusLightSizeForMF(MF)
    light:SetSize(size, size)
    light:SetPoint("BOTTOM", MF.Frame, "TOP", 0, statusLightGap())
    if light.EnableMouse then light:EnableMouse(false) end
    if light.SetFrameLevel and MF.Frame.GetFrameLevel then
        light:SetFrameLevel(MF.Frame:GetFrameLevel() + 60)
    end
    if light.SetIgnoreParentAlpha then light:SetIgnoreParentAlpha(true) end

    local fill = light:CreateTexture(nil, "OVERLAY")
    fill:SetAllPoints(light)
    -- Blizzard's portrait alpha texture gives us a single solid circular alpha
    -- shape.  Vertex color supplies the status color; there is no inner ring.
    fill:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    fill:SetVertexColor(unpack(STATUS_READY))
    if fill.SetIgnoreParentAlpha then fill:SetIgnoreParentAlpha(true) end

    -- A separate, high-frame-level range layer guarantees that DandersFrames'
    -- yellow state visually wins over red/green verification carriers as well.
    local rangeLayer = CreateFrame("Frame", nil, light)
    rangeLayer:SetAllPoints(light)
    if rangeLayer.EnableMouse then rangeLayer:EnableMouse(false) end
    if rangeLayer.SetFrameLevel and light.GetFrameLevel then
        rangeLayer:SetFrameLevel(light:GetFrameLevel() + 120)
    end
    if rangeLayer.SetIgnoreParentAlpha then rangeLayer:SetIgnoreParentAlpha(true) end
    local rangeFill = rangeLayer:CreateTexture(nil, "OVERLAY")
    rangeFill:SetAllPoints(rangeLayer)
    rangeFill:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    rangeFill:SetVertexColor(unpack(STATUS_CLEAR))
    if rangeFill.SetIgnoreParentAlpha then rangeFill:SetIgnoreParentAlpha(true) end

    MF.Decursive121StatusLight = light
    MF.Decursive121StatusLightFill = fill
    MF.Decursive121StatusRangeLayer = rangeLayer
    MF.Decursive121StatusRangeFill = rangeFill
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusRangeUntil = 0
    MF.Decursive121StatusSuccessUntil = 0
    MF.Decursive121StatusFailureReason = nil
    MF.Decursive121VerificationGeneration = 0
    statusLightMUFs[MF] = true
end

local function refreshOneMUFStatusLight(MF, now)
    if not MF then return end
    initializeMUFStatusLight(MF)
    local light, fill = MF.Decursive121StatusLight, MF.Decursive121StatusLightFill
    local rangeLayer, rangeFill = MF.Decursive121StatusRangeLayer, MF.Decursive121StatusRangeFill
    if not light or not fill then return end

    if MF.Shown == false or not MF.Frame:IsShown() then
        light:Hide()
        return
    end

    now = now or (GetTime and GetTime() or 0)

    -- Determine the transient result color WITHOUT deciding DandersFrames range.
    -- Range is potentially secret and is applied afterward through Blizzard's
    -- boolean-aware widget API.
    local resultColor = STATUS_READY
    local lineOfSightFailed = MF.Decursive121LineOfSightUntil
        and MF.Decursive121LineOfSightUntil > now
        and MF.Decursive121LineOfSightUnit == MF.CurrUnit
    if (MF.Decursive121StatusFailureUntil or 0) > now or lineOfSightFailed then
        resultColor = STATUS_FAILED
    elseif (MF.Decursive121StatusSuccessUntil or 0) > now then
        resultColor = STATUS_SUCCESS
    end

    -- DandersFrames mode: yellow is authoritative and always wins.  The range
    -- layer is on top of the result layer AND the protected verification carrier.
    -- If DF says out of range, red/green are visually suppressed automatically.
    if rangeFill and applyDandersRangeToStatusLayers(MF, fill, rangeFill, resultColor) then
        if rangeLayer then rangeLayer:Show() end
        light:Show()
        return
    end

    -- Native mode follows the exact same two-layer contract, but asks Blizzard
    -- directly through C_Spell.IsSpellInRange()/UnitInRange.  Secret booleans
    -- are passed straight into the texture API, so yellow retains the same hard
    -- priority over red/green as it has with DandersFrames.
    if rangeFill and applyNativeRangeToStatusLayers(MF, fill, rangeFill, resultColor) then
        if rangeLayer then rangeLayer:Show() end
        light:Show()
        return
    end

    -- Compatibility fallback only when Blizzard did not produce a usable range
    -- signal.  This path contains no protected aura reads.
    if rangeFill then rangeFill:SetVertexColor(unpack(STATUS_CLEAR)) end
    if rangeLayer then rangeLayer:Show() end
    if MF.Decursive121OutOfRange == true or (MF.Decursive121StatusRangeUntil or 0) > now then
        fill:SetVertexColor(unpack(STATUS_RANGE))
    else
        fill:SetVertexColor(unpack(resultColor))
    end
    light:Show()
end

local function refreshMUFStatusLights()
    local now = GetTime and GetTime() or 0
    for MF in pairs(statusLightMUFs) do
        refreshOneMUFStatusLight(MF, now)
    end
end

function D:Mark121MUFStatusRange(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    MF.Decursive121OutOfRange = true
    MF.Decursive121StatusRangeUntil = (GetTime and GetTime() or 0) + 2.5
    refreshOneMUFStatusLight(MF)
end

local function parkDandersVerificationHandles(MF)
    if not MF then return end
    local handles = MF.Decursive121VerificationDandersHandles
    if handles then
        for priority = 1, 3 do
            local handle = handles[priority]
            if handle then
                if handle.SetIntentShown then
                    safe("DandersFrames park cure verification", handle.SetIntentShown, handle, false)
                elseif not InCombatLockdown() and handle.SetShown then
                    safe("DandersFrames park cure verification", handle.SetShown, handle, false)
                end
            end
        end
    end
    -- Native verification carriers stay structurally alive at all times. Their
    -- addon-owned holder is merely transparent until a post-cure verification
    -- window is active, so no managed AuraContainer topology changes in combat.
    local holders = MF.Decursive121VerificationNativeHolders
    if holders then
        for priority = 1, 3 do
            local holder = holders[priority]
            if holder and holder.SetAlpha then holder:SetAlpha(0) end
        end
    end
end

function D:Mark121MUFStatusFailure(unitOrMF, reason)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    MF.Decursive121VerificationGeneration = (MF.Decursive121VerificationGeneration or 0) + 1
    MF.Decursive121StatusSuccessUntil = 0
    parkDandersVerificationHandles(MF)
    MF.Decursive121StatusFailureReason = reason and tostring(reason) or nil
    MF.Decursive121StatusFailureUntil = (GetTime and GetTime() or 0) + 3.0
    refreshOneMUFStatusLight(MF)
end

function D:Clear121MUFStatusAttempt(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    MF.Decursive121VerificationGeneration = (MF.Decursive121VerificationGeneration or 0) + 1
    parkDandersVerificationHandles(MF)
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusRangeUntil = 0
    MF.Decursive121StatusSuccessUntil = 0
    MF.Decursive121StatusFailureReason = nil
    refreshOneMUFStatusLight(MF)
end

function D:Refresh121MUFStatusLights()
    refreshMUFStatusLights()
end

function D:Get121MUFStatus(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return "UNKNOWN" end
    local now = GetTime and GetTime() or 0
    -- This diagnostic helper can only report Decursive's non-secret range state.
    -- DandersFrames' live dfInRange may be secret and is intentionally never
    -- inspected in Lua; the actual status light still gives yellow top priority.
    if MF.Decursive121OutOfRange == true or (MF.Decursive121StatusRangeUntil or 0) > now then
        return "OUT_OF_RANGE", MF.CurrUnit
    end
    if (MF.Decursive121StatusFailureUntil or 0) > now then
        return "FAILED", MF.Decursive121StatusFailureReason
    end
    if (MF.Decursive121StatusSuccessUntil or 0) > now then
        return "SUCCESS", MF.CurrUnit
    end
    return "READY", MF.CurrUnit
end

local mufStatusLightTicker
if C_Timer and C_Timer.NewTicker then
    mufStatusLightTicker = C_Timer.NewTicker(.10, refreshMUFStatusLights)
end

-- ---------------------------------------------------------------------------
-- Addon-owned out-of-range range-state layer (v10.33)
-- ---------------------------------------------------------------------------
-- This layer never touches Blizzard-managed AuraButtons.  It sits over the
-- normal Decursive MUF and therefore also dims any managed priority color that
-- Blizzard renders underneath it.  UnitInRange is used only when its result is
-- accessible; protected/unknown results are treated as in-range so we never
-- infer secret state.
local function syncRangeOverlayToMUF(MF)
    local overlay = MF and MF.Decursive121RangeOverlay
    if not overlay or not D.MFContainer or not D.MicroUnitF then return end
    local slot = MF.ToPlace
    if type(slot) ~= "number" or slot < 1 then slot = MF.ID end
    if type(slot) ~= "number" or slot < 1 then slot = MF.FrameNum end
    if type(slot) ~= "number" or slot < 1 then return end
    local anchor = D.MicroUnitF.GetMUFAnchor and D.MicroUnitF:GetMUFAnchor(slot)
    if not anchor then return end
    overlay:ClearAllPoints()
    overlay:SetPoint(unpack(anchor))
    overlay:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20)
end

local function initializeRangeOverlay(MF)
    if not MF or not MF.Frame or MF.Decursive121RangeOverlay or not D.MFContainer then return end
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    overlay:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20)
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    -- Keep the addon-owned range state above the Blizzard-managed priority fill.
    -- The range frame is not part of the protected AuraContainer chain.
    if overlay.SetFrameStrata then overlay:SetFrameStrata("HIGH") end
    if overlay.SetFrameLevel and MF.Frame.GetFrameLevel then
        overlay:SetFrameLevel(MF.Frame:GetFrameLevel() + 100)
    end
    overlay:Hide()
    local tint = overlay:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints(overlay)
    tint:SetColorTexture(0, 0, 0, .60)
    MF.Decursive121RangeOverlay = overlay
    MF.Decursive121RangeTint = tint
    rangeMUFs[MF] = true
    syncRangeOverlayToMUF(MF)
end

function D:Apply121RangeAppearance()
    local profile = D.profile or {}
    local c = profile.OutOfRange121Color or { 1, 1, 0 }
    local dim = profile.OutOfRange121DimAmount
    if type(dim) ~= "number" then dim = .60 end
    if dim < 0 then dim = 0 elseif dim > 1 then dim = 1 end
    for MF in pairs(rangeMUFs) do
        local tint = MF.Decursive121RangeTint
        if tint then tint:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, dim) end
    end
end

local function refreshRangeOverlays()
    local profile = D.profile or {}
    local enabled = profile.OutOfRange121Enabled ~= false
    for MF in pairs(rangeMUFs) do
        local overlay = MF.Decursive121RangeOverlay
        if overlay then
            syncRangeOverlayToMUF(MF)
            local outOfRange = false
            local unit = MF.CurrUnit
            if enabled and unit and unit ~= "player" then
                -- Prefer the actual friendly cure spells Decursive has configured.
                -- This is more useful than generic UnitInRange(), particularly in PvP,
                -- and does not inspect protected aura data. If every configured cure
                -- spell reports the unit out of range, show the range state.
                local testedSpell = false
                local anyCureInRange = false
                local status = D.Status
                if D.IsSpellInRange and status and status.CuringSpells and status.CuringSpellsPrio then
                    local seen = {}
                    for _, spellName in pairs(status.CuringSpells) do
                        local prio = spellName and status.CuringSpellsPrio[spellName]
                        if spellName and prio and prio >= 1 and prio <= 3 and not seen[spellName] then
                            seen[spellName] = true
                            local ok, value = pcall(D.IsSpellInRange, D, spellName, unit)
                            if ok and canaccessvalue(value) then
                                testedSpell = true
                                if value == 1 or value == true then
                                    anyCureInRange = true
                                    break
                                end
                            end
                        end
                    end
                end

                if testedSpell then
                    outOfRange = not anyCureInRange
                elseif UnitInRange then
                    -- Fallback only when no configured cure spell could be tested.
                    local ok, value = pcall(UnitInRange, unit)
                    if ok and canaccessvalue(value) and value == false then outOfRange = true end
                end
            end
            MF.Decursive121OutOfRange = outOfRange and true or false
            if outOfRange then overlay:Show() else overlay:Hide() end
        end
    end
    refreshMUFStatusLights()
end

function D:Set121OutOfRangeEnabled(enabled)
    D.profile.OutOfRange121Enabled = enabled and true or false
    refreshRangeOverlays()
end

local rangeTicker
if C_Timer and C_Timer.NewTicker then
    rangeTicker = C_Timer.NewTicker(.20, refreshRangeOverlays)
end

-- ---------------------------------------------------------------------------
-- Addon-owned line-of-sight feedback layer (v11 alpha.14)
-- ---------------------------------------------------------------------------
-- WoW does not expose a continuous friendly-unit LoS query.  Instead we mark
-- the MUF only after our own cleanse attempt receives SPELL_FAILED_LINE_OF_SIGHT.
-- The state is intentionally short-lived and never reads protected aura data.
local function syncLineOfSightOverlayToMUF(MF)
    local overlay = MF and MF.Decursive121LineOfSightOverlay
    if not overlay or not D.MFContainer or not D.MicroUnitF then return end
    local slot = MF.ToPlace
    if type(slot) ~= "number" or slot < 1 then slot = MF.ID end
    if type(slot) ~= "number" or slot < 1 then slot = MF.FrameNum end
    if type(slot) ~= "number" or slot < 1 then return end
    local anchor = D.MicroUnitF.GetMUFAnchor and D.MicroUnitF:GetMUFAnchor(slot)
    if not anchor then return end
    overlay:ClearAllPoints()
    overlay:SetPoint(unpack(anchor))
    overlay:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20)
end

local function initializeLineOfSightOverlay(MF)
    if not MF or not MF.Frame or MF.Decursive121LineOfSightOverlay or not D.MFContainer then return end
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    overlay:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20)
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    if overlay.SetFrameStrata then overlay:SetFrameStrata("HIGH") end
    if overlay.SetFrameLevel and MF.Frame.GetFrameLevel then overlay:SetFrameLevel(MF.Frame:GetFrameLevel() + 120) end
    overlay:Hide()
    local tint = overlay:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints(overlay)
    tint:SetColorTexture(1, .28, .12, .78)
    MF.Decursive121LineOfSightOverlay = overlay
    MF.Decursive121LineOfSightTint = tint
    MF.Decursive121LineOfSightUntil = nil
    MF.Decursive121LineOfSightUnit = nil
    lineOfSightMUFs[MF] = true
    syncLineOfSightOverlayToMUF(MF)
end

function D:Apply121LineOfSightAppearance()
    local profile = D.profile or {}
    local c = profile.LineOfSight121Color or {1, .28, .12}
    local alpha = tonumber(profile.LineOfSight121Opacity) or .78
    if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
    for MF in pairs(lineOfSightMUFs) do
        local tint = MF.Decursive121LineOfSightTint
        if tint then tint:SetColorTexture(c[1] or 1, c[2] or .28, c[3] or .12, alpha) end
    end
end

local function refreshLineOfSightOverlays()
    local now = GetTime and GetTime() or 0
    local enabled = not D.profile or D.profile.LineOfSight121Enabled ~= false
    for MF in pairs(lineOfSightMUFs) do
        local overlay = MF.Decursive121LineOfSightOverlay
        if overlay then
            syncLineOfSightOverlayToMUF(MF)
            local active = enabled
                and MF.Decursive121LineOfSightUntil
                and MF.Decursive121LineOfSightUntil > now
                and MF.CurrUnit
                and MF.CurrUnit == MF.Decursive121LineOfSightUnit
            if active then
                overlay:Show()
            else
                overlay:Hide()
                if MF.Decursive121LineOfSightUntil and MF.Decursive121LineOfSightUntil <= now then
                    MF.Decursive121LineOfSightUntil = nil
                    MF.Decursive121LineOfSightUnit = nil
                end
            end
        end
    end
end

local function resolveLineOfSightMUF(unitOrMF)
    if type(unitOrMF) == "table" and unitOrMF.Frame then return unitOrMF end
    if type(unitOrMF) == "string" then
        for MF in pairs(lineOfSightMUFs) do if MF.CurrUnit == unitOrMF then return MF end end
    end
end

function D:Mark121LineOfSightBlocked(unitOrMF)
    local MF = resolveLineOfSightMUF(unitOrMF)
    if not MF then return end
    initializeLineOfSightOverlay(MF)
    local hold = tonumber((D.profile or {}).LineOfSight121HoldSeconds) or 2.5
    if hold < .5 then hold = .5 elseif hold > 8 then hold = 8 end
    MF.Decursive121LineOfSightUnit = MF.CurrUnit
    MF.Decursive121LineOfSightUntil = (GetTime and GetTime() or 0) + hold
    refreshLineOfSightOverlays()
end

function D:Clear121LineOfSightBlocked(unitOrMF)
    local MF = resolveLineOfSightMUF(unitOrMF)
    if not MF then return end
    MF.Decursive121LineOfSightUntil = nil
    MF.Decursive121LineOfSightUnit = nil
    if MF.Decursive121LineOfSightOverlay then MF.Decursive121LineOfSightOverlay:Hide() end
end

function D:Set121LineOfSightEnabled(enabled)
    if D.profile then D.profile.LineOfSight121Enabled = enabled and true or false end
    refreshLineOfSightOverlays()
end

local lineOfSightTicker
if C_Timer and C_Timer.NewTicker then
    lineOfSightTicker = C_Timer.NewTicker(.10, refreshLineOfSightOverlays)
end

local cooldownActive = false
local finishPriorityCooldown
local cooldownGeneration = { [1] = 0, [2] = 0, [3] = 0 }
local priorityCooldownActive = { [1] = false, [2] = false, [3] = false }
local trackedDispelSpellID = nil
local trackedPrioritySpellIDs = { [1] = nil, [2] = nil, [3] = nil }
-- The cooldown belongs to the player's spell. Keep the MUF that initiated the
-- successful cleanse only as an EXCLUSION marker: that square must clear
-- immediately, while OTHER still-dispellable squares can receive the cooldown
-- overlay for the same curing priority.
local activePriorityMUF = { [1] = nil, [2] = nil, [3] = nil }
local lastClickedMUF = nil
local lastClickedPriority = nil
local lastClickedAt = 0
local clickHookedFrames = setmetatable({}, { __mode = "k" })


-- v10.28 forbidden-object safety boundary.
-- Blizzard-managed AuraContainer/AuraButton objects are used only for Blizzard-
-- controlled affliction visibility/color. Dynamic cooldown UI must never be
-- parented to, shown/hidden under, or otherwise mutated through those objects
-- after initialization because secret aura state can make the entire branch
-- forbidden.
local refreshPriorityGateFilters

local DISPEL_TYPE_NAME_BY_DT = {
    [DC.MAGIC] = "Magic",
    [DC.CURSE] = "Curse",
    [DC.DISEASE] = "Disease",
    [DC.POISON] = "Poison",
    [DC.BLEED] = "Bleed",
}

local function getPriorityDispelTypeFilter(priority)
    local include = {}
    local status = D.Status
    if not status or not status.CuringSpells or not status.CuringSpellsPrio then return include end
    for debuffType, spellName in pairs(status.CuringSpells) do
        local typeName = DISPEL_TYPE_NAME_BY_DT[debuffType]
        if typeName and spellName and status.CuringSpellsPrio[spellName] == priority then
            include[typeName] = true
        end
    end
    return include
end

-- v10.35: the primary Blizzard-managed aura group must never be broader than
-- Decursive's actual friendly cure configuration. Blizzard evaluates this
-- candidate filter internally, so addon Lua never needs to inspect the
-- protected aura's dispel type.
local function getConfiguredDispelTypeFilter()
    local include = {}
    for priority = 1, 3 do
        local byPriority = getPriorityDispelTypeFilter(priority)
        for typeName, enabled in pairs(byPriority) do
            if enabled then include[typeName] = true end
        end
    end
    return include
end

local providerPriorityInitializedButtons = setmetatable({}, { __mode = "k" })

local function tableHasAnyKey(t)
    if type(t) ~= "table" then return false end
    return next(t) ~= nil
end

-- Native AuraSlots do not automatically cover their host. Blizzard returns the
-- created AuraButton from AddAuraSlot(), and overlay consumers are responsible
-- for anchoring that button while it is still in the safe initialization window.
-- DandersFrames does the same thing in its AuraContainer factory. Keep every
-- direct-Blizzard carrier on this one helper so native detection/cooldown/verify
-- all use identical geometry.
local function anchorNativeAuraSlot(auraButton, anchor, label)
    if not auraButton or not anchor then return false end
    if auraButton.ClearAllPoints then safe((label or "Native AuraSlot") .. " ClearAllPoints", auraButton.ClearAllPoints, auraButton) end
    if auraButton.SetAllPoints then
        safe((label or "Native AuraSlot") .. " SetAllPoints", auraButton.SetAllPoints, auraButton, anchor)
        return true
    end
    return false
end

-- DandersFrames' factory never exposes the protected aura type back to Lua.
-- Instead, each priority gets a Blizzard-filtered AuraSlot whose membership is
-- the decision. A slot exists/shows only when DandersFrames' AuraContainer
-- carrier matches one of the configured dispel types for that priority.
local function initializeProviderPriorityButton(auraButton, priority, MF)
    if not auraButton or providerPriorityInitializedButtons[auraButton] then return end
    providerPriorityInitializedButtons[auraButton] = true

    if auraButton.SetSize then auraButton:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20) end
    if auraButton.EnableMouse then auraButton:EnableMouse(false) end
    if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
    if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end

    local baseLevel = MF and MF.Frame and MF.Frame.GetFrameLevel and MF.Frame:GetFrameLevel() or 0
    -- Higher cure priority owns the center when multiple dispel types coexist.
    if auraButton.SetFrameLevel then auraButton:SetFrameLevel(baseLevel + 24 - priority) end

    local r, g, b, a = getPriorityColor(priority)
    local fill = auraButton:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints(auraButton)
    fill:SetColorTexture(r, g, b, a or 1)

    -- Lower-priority simultaneous needs remain visible as a border even when a
    -- higher-priority slot is covering the center. The border holder is given a
    -- separate high frame level while inheriting the secret-safe visibility of
    -- its DandersFrames-owned AuraSlot.
    if priority > 1 and (not D.profile or D.profile.CooldownPriority2Border121Enabled ~= false) then
        local holder = CreateFrame("Frame", nil, auraButton)
        holder:SetAllPoints(auraButton)
        if holder.EnableMouse then holder:EnableMouse(false) end
        if holder.SetFrameLevel then holder:SetFrameLevel(baseLevel + 35 - priority) end
        local thickness = math.max(1, math.floor((D.profile and D.profile.CooldownBorder121Thickness) or 2))
        local edges = {
            makeManagedBorderStrip(holder, holder, "TOP", thickness, 0),
            makeManagedBorderStrip(holder, holder, "BOTTOM", thickness, 0),
            makeManagedBorderStrip(holder, holder, "LEFT", thickness, 0),
            makeManagedBorderStrip(holder, holder, "RIGHT", thickness, 0),
        }
        local alpha = (D.profile and D.profile.CooldownBorder121Alpha) or .95
        for _, tex in ipairs(edges) do tex:SetColorTexture(r, g, b, alpha) end
        -- Do not run an AnimationGroup inside a protected AuraButton subtree.
        -- DandersFrames documents that 12.1 disables those drivers there.
        auraButton.DecursiveDandersBorderHolder = holder
        auraButton.DecursiveDandersBorder = edges
    end

    auraButton.DecursiveDandersPriority = priority
    auraButton.DecursiveDandersFill = fill
end

local function buildDandersPriorityRecords(MF)
    local records = {}
    for priority = 3, 1, -1 do
        local include = getPriorityDispelTypeFilter(priority)
        if tableHasAnyKey(include) then
            local p = priority
            records[#records + 1] = {
                filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
                key = "zhaohu-priority-" .. tostring(p),
                candidateFilters = { includeDispelTypes = include },
                onInit = function(btn) initializeProviderPriorityButton(btn, p, MF) end,
            }
        end
    end
    return records
end

local function makeDandersPriorityGateRecord(priority, candidateFilters, onInit)
    return {
        filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
        key = "zhaohu-cooldown-priority-" .. tostring(priority),
        candidateFilters = candidateFilters,
        onInit = onInit,
    }
end

local validateDandersHandle
local destroyDandersHandle

-- Post-cure verification carriers (v11 alpha.20). These are separate from
-- both the primary dispel detector and the cooldown carriers. They exist only
-- to let DandersFrames/Blizzard answer one protected question visually:
-- "after my cure cast, is a matching dispellable affliction still present?"
-- If yes, a red circle is rendered over the green success light. If no, the
-- carrier has no matching AuraSlot and the three-second green light remains.
local function makeDandersVerificationRecord(priority, onInit)
    return {
        filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
        key = "zhaohu-verify-priority-" .. tostring(priority),
        candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(priority) },
        onInit = onInit,
    }
end

local function initializeDandersVerificationButton(auraButton, MF)
    if not auraButton or not MF then return end
    initializeMUFStatusLight(MF)
    local size = statusLightSizeForMF(MF)
    if auraButton.SetSize then auraButton:SetSize(size, size) end
    if auraButton.EnableMouse then auraButton:EnableMouse(false) end
    if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
    if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end

    local red = auraButton:CreateTexture(nil, "OVERLAY")
    red:SetAllPoints(auraButton)
    red:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    red:SetVertexColor(unpack(STATUS_FAILED))
    if red.SetIgnoreParentAlpha then red:SetIgnoreParentAlpha(true) end
    auraButton.Decursive121VerificationRed = red
end

local function attachDandersVerificationCarriers(MF, Unit)
    if not MF or not MF.Frame or InCombatLockdown() then return end
    initializeMUFStatusLight(MF)
    local light = MF.Decursive121StatusLight
    if not light then return end

    MF.Decursive121VerificationDandersHandles = MF.Decursive121VerificationDandersHandles or {}
    MF.Decursive121VerificationDandersOnInit = MF.Decursive121VerificationDandersOnInit or {}

    local factory, _, reason = getDandersAuraFactory(true)
    if not factory then
        warnDandersUnavailable(reason)
        return
    end

    for priority = 1, 3 do
        if not MF.Decursive121VerificationDandersHandles[priority] and tableHasAnyKey(getPriorityDispelTypeFilter(priority)) then
            local p = priority
            local init = function(btn) initializeDandersVerificationButton(btn, MF) end
            MF.Decursive121VerificationDandersOnInit[p] = init
            local record = makeDandersVerificationRecord(p, init)
            local ok, handle = safe("DandersFrames Create cure verification carrier", factory.Create, factory, light, {
                unit = Unit,
                mode = "overlay",
                filter = { record },
                frameLevelOffset = 8 + p,
                enabled = true,
                tooltips = false,
            })
            if ok and handle then
                local valid, validationReason = validateDandersHandle(handle, false)
                if valid and type(handle.SetIntentShown) ~= "function" and type(handle.SetShown) ~= "function" then
                    valid = false
                    validationReason = "DandersFrames verification carrier is missing SetIntentShown()/SetShown()."
                end
                if valid then
                    MF.Decursive121VerificationDandersHandles[p] = handle
                    if handle.SetIntentShown then
                        safe("DandersFrames park cure verification", handle.SetIntentShown, handle, false)
                    elseif handle.SetShown then
                        safe("DandersFrames park cure verification", handle.SetShown, handle, false)
                    end
                else
                    destroyDandersHandle(handle)
                    warnDandersUnavailable(validationReason)
                end
            end
        end
    end
end

local function initializeNativeVerificationButton(auraButton, MF)
    if not auraButton or not MF then return end
    initializeMUFStatusLight(MF)
    local size = statusLightSizeForMF(MF)
    if auraButton.SetSize then auraButton:SetSize(size, size) end
    if auraButton.EnableMouse then auraButton:EnableMouse(false) end
    if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
    if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end
    local red = auraButton:CreateTexture(nil, "OVERLAY")
    red:SetAllPoints(auraButton)
    red:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    red:SetVertexColor(unpack(STATUS_FAILED))
    -- Do NOT ignore parent alpha here: the native carrier is kept structurally
    -- active and its addon-owned holder alpha is the safe combat-time gate.
    auraButton.Decursive121VerificationRed = red
end

local function attachNativeVerificationCarriers(MF, Unit)
    if not MF or not MF.Frame or InCombatLockdown() then return end
    initializeMUFStatusLight(MF)
    local light = MF.Decursive121StatusLight
    if not light then return end

    MF.Decursive121VerificationNativeContainers = MF.Decursive121VerificationNativeContainers or {}
    MF.Decursive121VerificationNativeHolders = MF.Decursive121VerificationNativeHolders or {}

    for priority = 1, 3 do
        if not MF.Decursive121VerificationNativeContainers[priority] and tableHasAnyKey(getPriorityDispelTypeFilter(priority)) then
            local p = priority
            local holder = CreateFrame("Frame", nil, light)
            holder:SetAllPoints(light)
            if holder.EnableMouse then holder:EnableMouse(false) end
            if holder.SetFrameLevel and light.GetFrameLevel then holder:SetFrameLevel(light:GetFrameLevel() + 8 + p) end
            holder:SetAlpha(0)
            holder:Show()

            local ok, container = safe("Create native cure verification AuraContainer", CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
            if ok and container then
                container:SetAllPoints(holder)
                if container.EnableMouse then safe("Native verification AuraContainer EnableMouse", container.EnableMouse, container, false) end
                if container.SetUnit then safe("Native verification AuraContainer SetUnit", container.SetUnit, container, Unit) end
                local key = "zhaohu-native-verify-priority-" .. tostring(p)
                local options = {
                    initializeFrame = function(btn) initializeNativeVerificationButton(btn, MF) end,
                    candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(p) },
                }
                if container.AddAuraSlot then
                    local slotOK, slotButton = safe("Native verification AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                    if slotOK and slotButton then
                        anchorNativeAuraSlot(slotButton, holder, "Native verification AuraSlot")
                    end
                end
                -- SetEnabled LAST: this arms Blizzard's aura parsing/event registration
                -- only after SetUnit, AddAuraSlot and the slot geometry are complete.
                if container.SetEnabled then safe("Native verification SetEnabled", container.SetEnabled, container, true) end
                if container.Show then safe("Native verification Show", container.Show, container) end
                if container.UpdateAllAuras then safe("Native verification initial refresh", container.UpdateAllAuras, container) end
                MF.Decursive121VerificationNativeContainers[p] = container
                MF.Decursive121VerificationNativeHolders[p] = holder
            end
        end
    end
end

local function resolveCurePriorityFromSpellName(spellName)
    local status = D.Status
    if spellName and status and status.CuringSpellsPrio then
        local priority = status.CuringSpellsPrio[spellName]
        if type(priority) == "number" and priority >= 1 and priority <= 3 then return priority end
    end
    if lastClickedPriority and lastClickedMUF and (GetTime() - (lastClickedAt or 0)) <= 1.5 then
        return lastClickedPriority
    end
    return 1
end

function D:Begin121MUFPostCureVerification(unitOrMF, spellName)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    initializeMUFStatusLight(MF)

    -- Start every successful cast with a green base. DandersFrames verification
    -- can cover it in red if the matching affliction remains after the aura
    -- system has had a fraction of a second to settle.
    MF.Decursive121VerificationGeneration = (MF.Decursive121VerificationGeneration or 0) + 1
    local generation = MF.Decursive121VerificationGeneration
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusFailureReason = nil
    MF.Decursive121StatusSuccessUntil = 0
    parkDandersVerificationHandles(MF)
    refreshOneMUFStatusLight(MF)

    local nativeProvider = latchDetectionProvider() == PROVIDER_NATIVE
    if nativeProvider then
        attachNativeVerificationCarriers(MF, MF.CurrUnit)
    else
        attachDandersVerificationCarriers(MF, MF.CurrUnit)
    end
    local priority = resolveCurePriorityFromSpellName(spellName)
    local function enableVerification()
        if not MF or MF.Decursive121VerificationGeneration ~= generation then return end
        -- Wait one short aura-update beat before showing success. This prevents
        -- a false green flash on a cast that succeeds but leaves the protected
        -- dispel need in place. The red DandersFrames verifier is enabled in
        -- the same update and visually owns the light if the affliction remains.
        MF.Decursive121StatusSuccessUntil = (GetTime and GetTime() or 0) + 3.0
        refreshOneMUFStatusLight(MF)
        if nativeProvider then
            local holders = MF.Decursive121VerificationNativeHolders
            local containers = MF.Decursive121VerificationNativeContainers
            if not holders then return end
            for p = 1, 3 do
                local holder = holders[p]
                if holder then holder:SetAlpha(p == priority and 1 or 0) end
                local container = containers and containers[p]
                if p == priority and container and container.UpdateAllAuras then
                    safe("Native cure verification refresh", container.UpdateAllAuras, container)
                end
            end
        else
            local handles = MF.Decursive121VerificationDandersHandles
            if not handles then return end
            for p = 1, 3 do
                local handle = handles[p]
                if handle then
                    local shown = p == priority
                    if handle.SetIntentShown then
                        safe("DandersFrames cure verification visibility", handle.SetIntentShown, handle, shown)
                    elseif not InCombatLockdown() and handle.SetShown then
                        safe("DandersFrames cure verification visibility", handle.SetShown, handle, shown)
                    end
                end
            end
        end
    end
    local function finishVerification()
        if not MF or MF.Decursive121VerificationGeneration ~= generation then return end
        parkDandersVerificationHandles(MF)
        MF.Decursive121StatusSuccessUntil = 0
        refreshOneMUFStatusLight(MF)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(.10, enableVerification)
        C_Timer.After(3.10, finishVerification)
    else
        enableVerification()
    end
end

local function setPriorityGateCooldownVisual(...) return end
local function refreshPriorityGateCooldownVisuals(...) return end
local function refreshAllPriorityGateCooldownVisuals(...) return end
local refreshSharedPriorityCooldownGates
local refreshAllSharedPriorityCooldownGates
local attachPriorityCooldownGate
local function makePriorityBorderEdge(parent)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetColorTexture(1, 1, 1, 1)
    t:Hide()
    return t
end

local function syncCooldownOverlayToMUF(MF)
    local overlay = MF and MF.Decursive121CooldownOverlay
    if not overlay or not D.MFContainer or not D.MicroUnitF then return end

    -- Do not read geometry from the secure MUF.  Recreate its normal Decursive
    -- layout anchor from public addon state instead.  This keeps our overlay
    -- entirely addon-owned while still following every MUF position/size.
    local slot = MF.ToPlace
    if type(slot) ~= "number" or slot < 1 then slot = MF.ID end
    if type(slot) ~= "number" or slot < 1 then slot = MF.FrameNum end
    if type(slot) ~= "number" or slot < 1 then return end

    local anchor = D.MicroUnitF.GetMUFAnchor and D.MicroUnitF:GetMUFAnchor(slot)
    if not anchor then return end

    overlay:ClearAllPoints()
    overlay:SetPoint(unpack(anchor))
    overlay:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20)

end

local function initializePriorityCooldownVisuals(MF)
    if not MF or not MF.Frame or MF.Decursive121CooldownOverlay then return end
    if not D.MFContainer then return end

    -- Keep all addon-controlled cooldown widgets OUTSIDE Blizzard's managed
    -- AuraButton.  Parenting them to that button causes them to become
    -- forbidden when the protected aura state changes in combat.
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    overlay:SetSize(MF.Frame:GetWidth() or DC.MFSIZE or 20, MF.Frame:GetHeight() or DC.MFSIZE or 20)
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    if overlay.SetFrameLevel and MF.Frame.GetFrameLevel then
        overlay:SetFrameLevel(MF.Frame:GetFrameLevel() + 40)
    end
    overlay:Hide()
    MF.Decursive121CooldownOverlay = overlay
    syncCooldownOverlayToMUF(MF)

    local inner = overlay:CreateTexture(nil, "ARTWORK", nil, 5)
    inner:SetAllPoints(overlay)
    inner:Hide()
    MF.Decursive121Priority1Shade = inner

    local cd1 = CreateFrame("Cooldown", nil, overlay)
    cd1:SetAllPoints(overlay)
    if cd1.SetFrameLevel then cd1:SetFrameLevel(overlay:GetFrameLevel() + 2) end
    if cd1.SetDrawSwipe then cd1:SetDrawSwipe(false) end
    if cd1.SetDrawEdge then cd1:SetDrawEdge(false) end
    if cd1.SetDrawBling then cd1:SetDrawBling(false) end
    if cd1.SetReverse then cd1:SetReverse(false) end
    cd1:Hide()
    if cd1.SetScript then
        cd1:SetScript("OnCooldownDone", function()
            local priority = MF.Decursive121ActiveCooldownPriority
            if priority and finishPriorityCooldown then
                finishPriorityCooldown(priority, cooldownGeneration[priority])
            end
        end)
    end
    MF.Decursive121Priority1Cooldown = cd1

    MF.Decursive121Priority2Edges = {
        makePriorityBorderEdge(overlay),
        makePriorityBorderEdge(overlay),
        makePriorityBorderEdge(overlay),
        makePriorityBorderEdge(overlay),
    }

    local cd2 = CreateFrame("Cooldown", nil, overlay)
    cd2:SetAllPoints(overlay)
    if cd2.SetFrameLevel then cd2:SetFrameLevel(overlay:GetFrameLevel() + 1) end
    if cd2.SetDrawSwipe then cd2:SetDrawSwipe(false) end
    if cd2.SetDrawEdge then cd2:SetDrawEdge(false) end
    if cd2.SetDrawBling then cd2:SetDrawBling(false) end
    if cd2.SetHideCountdownNumbers then cd2:SetHideCountdownNumbers(true) end
    cd2:Hide()
    if cd2.SetScript then
        cd2:SetScript("OnCooldownDone", function()
            finishPriorityCooldown(2, cooldownGeneration[2])
        end)
    end
    MF.Decursive121Priority2Cooldown = cd2

    local cd3 = CreateFrame("Cooldown", nil, overlay)
    cd3:SetAllPoints(overlay)
    if cd3.SetFrameLevel then cd3:SetFrameLevel(overlay:GetFrameLevel() + 1) end
    if cd3.SetDrawSwipe then cd3:SetDrawSwipe(false) end
    if cd3.SetDrawEdge then cd3:SetDrawEdge(false) end
    if cd3.SetDrawBling then cd3:SetDrawBling(false) end
    if cd3.SetHideCountdownNumbers then cd3:SetHideCountdownNumbers(true) end
    cd3:Hide()
    if cd3.SetScript then
        cd3:SetScript("OnCooldownDone", function() finishPriorityCooldown(3, cooldownGeneration[3]) end)
    end
    MF.Decursive121Priority3Cooldown = cd3

    -- v10.28: shared same-priority cooldown rendering no longer uses an
    -- addon-owned overlay that must query AuraSlot:IsShown(). In restricted
    -- 12.1 contexts that getter is forbidden, which made the timer disappear.
    -- The priority-filtered AuraSlot itself is now the visibility gate. Its
    -- initialize callback creates a static faded fill plus a FontString driven
    -- by a DurationTextBinding. Addon Lua only updates the binding and the
    -- container's public candidate filter; it never reads protected aura state.
    MF.Decursive121SharedCooldownOverlays = nil

    cooldownMUFs[MF] = true
    initializeMUFStatusLight(MF)
    initializeRangeOverlay(MF)
    initializeLineOfSightOverlay(MF)
    D:Apply121CooldownAppearance()
    D:Apply121RangeAppearance()
    D:Apply121LineOfSightAppearance()
end

-- Kept for compatibility with the v3-v10 code path.  The active visuals now
-- live on addon-owned per-MUF overlays instead of on managed aura buttons.
local function attachCooldownOverlay(MF)
    initializePriorityCooldownVisuals(MF)
end

local previewGeneration = 0
local previewActive = false
local previewAll = false
local previewMUF = nil

-- Addon-owned animation driver for the single secondary-affliction border.
local priorityBorderPulseDriver = CreateFrame("Frame")
local priorityBorderPulseElapsed = 0
priorityBorderPulseDriver:Hide()
priorityBorderPulseDriver:SetScript("OnUpdate", function(self, elapsed)
    priorityBorderPulseElapsed = priorityBorderPulseElapsed + (elapsed or 0)
    local profile = D.profile or {}
    local p2Alpha = profile.CooldownBorder121Alpha or .95
    local p2Pulse = (profile.CooldownPriority2Pulse121Enabled ~= false) and (0.25 + 0.75 * ((math.sin(priorityBorderPulseElapsed * 6.4) + 1) * .5)) or 1
    local anyVisible = false
    for MF in pairs(cooldownMUFs) do
        local isPreview = previewActive and ((previewAll and MF.Shown) or previewMUF == MF)
        local common = MF.Shown and profile.CooldownOverlay121Enabled ~= false
        -- Addon-owned borders are preview-only. Live cooldown visuals are
        -- provider-gated on other still-dispellable MUFs.
        local p2Visible = common and isPreview and profile.CooldownPriority2Border121Enabled ~= false
        if MF.Decursive121Priority2Edges then
            for _, edge in pairs(MF.Decursive121Priority2Edges) do edge:SetAlpha(p2Visible and p2Alpha*p2Pulse or p2Alpha) end
        end
        if p2Visible then anyVisible = true end
    end
    if not anyVisible then priorityBorderPulseElapsed = 0; self:Hide() end
end)

local function updatePriorityBorderPulseDriver()
    local profile = D.profile or {}
    local p2 = previewActive and profile.CooldownPriority2Border121Enabled ~= false and profile.CooldownPriority2Pulse121Enabled ~= false
    if profile.CooldownOverlay121Enabled ~= false and p2 then priorityBorderPulseDriver:Show() else priorityBorderPulseDriver:Hide() end
end

function D:Apply121CooldownAppearance()
    local profile = D.profile or {}
    local opacity = profile.CooldownOverlay121Opacity or .62
    local showNumbers = profile.CooldownOverlay121Numbers ~= false
    local borderAlpha = profile.CooldownBorder121Alpha or .95
    local thickness = profile.CooldownBorder121Thickness or 2
    local p2r, p2g, p2b = getPriorityColor(2)

    for MF in pairs(cooldownMUFs) do
        syncCooldownOverlayToMUF(MF)
        local overlay = MF.Decursive121CooldownOverlay
        local isPreview = previewActive and ((previewAll and MF.Shown) or previewMUF == MF)

        -- v11 alpha.11: the addon-owned overlay is PREVIEW ONLY. Live post-cleanse
        -- cooldowns are shown by the provider-gated priority carriers on OTHER
        -- still-dispellable MUFs. The clicked/cleansed MUF is never tinted.
        local common = MF.Shown and profile.CooldownOverlay121Enabled ~= false
        local shouldShow = common and isPreview
        if overlay then
            if shouldShow then overlay:Show() else overlay:Hide() end
        end

        local shade = MF.Decursive121Priority1Shade
        if shade then
            if shouldShow then
                local visualPriority = 1
                local ir, ig, ib = getPriorityColor(visualPriority)
                local fade = 0.45
                shade:SetColorTexture(ir * fade, ig * fade, ib * fade, opacity)
                shade:Show()
            else
                shade:Hide()
            end
        end

        local cd1 = MF.Decursive121Priority1Cooldown
        if cd1 then
            if cd1.SetHideCountdownNumbers then cd1:SetHideCountdownNumbers(not showNumbers) end
            if isPreview then
                cd1:Show()
            else
                MF.Decursive121ActiveCooldownPriority = nil
                if cd1.Clear then safe("MUF cooldown clear", cd1.Clear, cd1) end
                cd1:Hide()
            end
        end

        -- v10.28 shared cooldowns are rendered inside the priority-filtered
        -- Blizzard AuraSlot through a static fill and DurationTextBinding.
        -- There is deliberately no IsShown()/SetAlphaFromBoolean() bridge here.
        -- The engine owns presence; the binding owns countdown text.

        -- Addon-owned border is preview-only.  Live pre-click secondary-affliction
        -- border remains Blizzard-managed and therefore secret-safe.
        local edges = MF.Decursive121Priority2Edges
        if edges then
            for _, edge in pairs(edges) do
                edge:SetColorTexture(p2r, p2g, p2b, 1)
                edge:SetAlpha(borderAlpha)
                if isPreview and profile.CooldownPriority2Border121Enabled ~= false then edge:Show() else edge:Hide() end
            end
            local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
            top:ClearAllPoints(); top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0); top:SetHeight(thickness)
            bottom:ClearAllPoints(); bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(thickness)
            left:ClearAllPoints(); left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0); left:SetWidth(thickness)
            right:ClearAllPoints(); right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0); right:SetWidth(thickness)
        end
    end
    updatePriorityBorderPulseDriver()
end

local FRIENDLY_DISPEL_TYPES = {}
if DC.MAGIC then FRIENDLY_DISPEL_TYPES[DC.MAGIC] = true end
if DC.DISEASE then FRIENDLY_DISPEL_TYPES[DC.DISEASE] = true end
if DC.POISON then FRIENDLY_DISPEL_TYPES[DC.POISON] = true end
if DC.CURSE then FRIENDLY_DISPEL_TYPES[DC.CURSE] = true end
if DC.BLEED then FRIENDLY_DISPEL_TYPES[DC.BLEED] = true end

-- Returns the friendly dispel spell Decursive currently considers the best
-- general-purpose cure for this character/spec/talent setup.
--
-- This intentionally uses Decursive's live FoundSpells/CuringSpells tables
-- instead of a class-name lookup. Those tables are rebuilt by Decursive from
-- the player's actual spellbook, specialization and talent enhancements.
-- As a result, this follows things such as:
--   * healer vs non-healer variants of a cleanse
--   * talent-upgraded cleanses
--   * classes with more than one friendly dispel
--   * user-added curing spells that Decursive has actually registered
local function resolveConfiguredDispelSpellID()
    local status = D.Status
    if not status or not status.CuringSpells or not status.FoundSpells then
        return nil
    end

    local candidates = {}

    -- Only consider spells Decursive selected to handle FRIENDLY dispel types.
    -- This excludes Purge/Spellsteal/Consume Magic and charm-only utilities.
    for debuffType, spellName in pairs(status.CuringSpells) do
        if FRIENDLY_DISPEL_TYPES[debuffType] and spellName
            and status.CuringSpellsPrio and status.CuringSpellsPrio[spellName]
        then
            local data = status.FoundSpells[spellName]
            local spellID = data and data[2]
            if spellID and spellID > 0 then
                local c = candidates[spellName]
                if not c then
                    c = {
                        name = spellName,
                        id = spellID,
                        types = 0,
                        better = tonumber(data[4]) or 0,
                        prio = status.CuringSpellsPrio and status.CuringSpellsPrio[spellName] or 99,
                        pet = data[1] and true or false,
                    }
                    candidates[spellName] = c
                end
                c.types = c.types + 1
            end
        end
    end

    local best
    for _, c in pairs(candidates) do
        -- Prefer Decursive's own "Better" ranking first. This is important for
        -- classes that have a normal targeted cleanse plus a longer-cooldown
        -- utility dispel. Then prefer wider friendly-type coverage and finally
        -- the user's current Decursive curing priority.
        if not best
            or c.better > best.better
            or (c.better == best.better and c.types > best.types)
            or (c.better == best.better and c.types == best.types and c.prio < best.prio)
        then
            best = c
        end
    end

    return best and best.id or nil, best and best.name or nil
end

local function resolveConfiguredDispelSpellIDByPriority(priority)
    local status = D.Status
    if not status or not status.CuringSpells or not status.FoundSpells or not status.CuringSpellsPrio then
        return nil
    end

    local best
    for debuffType, spellName in pairs(status.CuringSpells) do
        if FRIENDLY_DISPEL_TYPES[debuffType] and spellName and status.CuringSpellsPrio[spellName] == priority then
            local data = status.FoundSpells[spellName]
            local spellID = data and data[2]
            if spellID and spellID > 0 then
                local better = tonumber(data[4]) or 0
                if not best or better > best.better then
                    best = { id = spellID, name = spellName, better = better }
                end
            end
        end
    end
    return best and best.id or nil, best and best.name or nil
end

local function isFriendlyConfiguredDispelSpellID(spellID)
    if not spellID or not D.Status or not D.Status.CuringSpells or not D.Status.FoundSpells then
        return false
    end

    for debuffType, spellName in pairs(D.Status.CuringSpells) do
        if FRIENDLY_DISPEL_TYPES[debuffType] and spellName
            and D.Status.CuringSpellsPrio and D.Status.CuringSpellsPrio[spellName]
        then
            local data = D.Status.FoundSpells[spellName]
            if data and data[2] == spellID then
                return true
            end
        end
    end
    return false
end

local function resetTrackedDispelSpell()
    updateManagedAnyPriorityCurve()
    -- A spec/talent change can alter what HARMFUL|RAID considers dispellable.
    -- Re-seed silently so that capability changes do not create a false alert.
    if type(D.Refresh121MUFStateSoundBaseline) == "function" then
        D:Refresh121MUFStateSoundBaseline()
    end
    local id = resolveConfiguredDispelSpellID()
    trackedDispelSpellID = id
    trackedPrioritySpellIDs[1] = resolveConfiguredDispelSpellIDByPriority(1)
    trackedPrioritySpellIDs[2] = resolveConfiguredDispelSpellIDByPriority(2)
    trackedPrioritySpellIDs[3] = resolveConfiguredDispelSpellIDByPriority(3)

    -- Do not force-update live Blizzard-managed display AuraButtons here.
    -- Priority ColorCurves remain Blizzard-managed. Priority AuraSlot filters
    -- are configuration-only and refreshed out of combat through their public API.
    if not InCombatLockdown() and D.MicroUnitF and D.MicroUnitF.ExistingPerUNIT then
        for _, MF in pairs(D.MicroUnitF.ExistingPerUNIT) do
            -- Ensure all provider-specific parity carriers that are now relevant
            -- after a spec/talent/custom-spell change exist before combat.
            if latchDetectionProvider() == PROVIDER_NATIVE then
                for priority = 1, 3 do
                    if attachPriorityCooldownGate then attachPriorityCooldownGate(MF, MF.CurrUnit, priority) end
                end
                attachNativeVerificationCarriers(MF, MF.CurrUnit)
            end

            refreshPriorityGateFilters(MF)
            local detector = MF.ManagedAuraContainer
            local keys = MF.Decursive121NativeDetectionKeys
            if detector and keys and detector.SetAuraSlotCandidateFilters and detector.AddAuraSlot then
                for priority = 1, 3 do
                    local include = getPriorityDispelTypeFilter(priority)
                    local key = keys[priority]
                    if key then
                        safe("Native refresh detection filter", detector.SetAuraSlotCandidateFilters, detector, key,
                            { includeDispelTypes = include })
                    elseif tableHasAnyKey(include) then
                        local p = priority
                        key = "zhaohu-native-priority-" .. tostring(p)
                        local options = {
                            initializeFrame = function(btn) initializeProviderPriorityButton(btn, p, MF) end,
                            candidateFilters = { includeDispelTypes = include },
                        }
                        local ok, slotButton = safe("Native add detection priority after reconfigure", detector.AddAuraSlot, detector, key,
                            "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                        if ok then
                            keys[p] = key
                            if slotButton then anchorNativeAuraSlot(slotButton, MF.Frame, "Native reconfigured detection AuraSlot") end
                        end
                    end
                end
                if detector.UpdateAllAuras then safe("Native detector refresh after reconfigure", detector.UpdateAllAuras, detector) end
            end
        end
    end
end

local function refreshManagedAfflictedCooldownVisuals()
    -- Shared cooldown rendering is handled by provider-gated priority carriers.
    -- Their aura membership remains Blizzard/DandersFrames controlled.
    return
end

local function clearClickedCooldownVisual(MF)
    if not MF then return end
    MF.Decursive121ActiveCooldownPriority = nil
    local cd = MF.Decursive121Priority1Cooldown
    if cd then
        if cd.Clear then safe("Clear cleansed MUF cooldown", cd.Clear, cd) end
        cd:Hide()
    end
    if MF.Decursive121Priority2Cooldown then MF.Decursive121Priority2Cooldown:Hide() end
    if MF.Decursive121Priority3Cooldown then MF.Decursive121Priority3Cooldown:Hide() end
    if MF.Decursive121Priority1Shade then MF.Decursive121Priority1Shade:Hide() end
    if MF.Decursive121CooldownOverlay then MF.Decursive121CooldownOverlay:Hide() end
end

finishPriorityCooldown = function(priority, generation)
    if generation and generation ~= cooldownGeneration[priority] then return end
    local targetMF = activePriorityMUF[priority]
    priorityCooldownActive[priority] = false
    managedCooldownDurationObjects[priority] = nil
    activePriorityMUF[priority] = nil

    if targetMF then clearClickedCooldownVisual(targetMF) end

    cooldownActive = priorityCooldownActive[1] or priorityCooldownActive[2] or priorityCooldownActive[3]
    refreshManagedAfflictedCooldownVisuals()
    refreshSharedPriorityCooldownGates(priority)
    D:Apply121CooldownAppearance()
end

local function armPriorityCooldown(priority, spellID, targetMF)
    if not spellID or not C_Spell or not C_Spell.GetSpellCooldownDuration then return false end

    local durationObject = C_Spell.GetSpellCooldownDuration(spellID, true)
    if not durationObject then return false end

    if durationObject.GetRemainingDuration then
        local ok, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if ok and remaining ~= nil and not (issecretvalue and issecretvalue(remaining)) and type(remaining) == "number" and remaining <= 0.05 then
            return false
        end
    end

    cooldownGeneration[priority] = cooldownGeneration[priority] + 1
    local generation = cooldownGeneration[priority]
    priorityCooldownActive[priority] = true
    managedCooldownDurationObjects[priority] = durationObject
    activePriorityMUF[priority] = targetMF
    cooldownActive = true

    -- The just-cleansed square must clear immediately. Never paint the player's
    -- cooldown back onto the MUF that initiated the successful cleanse.
    if targetMF then
        initializePriorityCooldownVisuals(targetMF)
        clearClickedCooldownVisual(targetMF)
    end

    -- Mirror the player's cooldown only to OTHER units that STILL match the
    -- provider's priority-filtered dispel carrier. Native uses its AuraContainer
    -- slot; DandersFrames uses its own pre-filtered carrier visibility.
    refreshSharedPriorityCooldownGates(priority)
    D:Apply121CooldownAppearance()
    return true, generation
end

local function refreshCooldownOverlay()
    if D.profile and D.profile.CooldownOverlay121Enabled == false then
        cooldownActive = false
        priorityCooldownActive[1] = false
        priorityCooldownActive[2] = false
        priorityCooldownActive[3] = false
        activePriorityMUF[1] = nil
        activePriorityMUF[2] = nil
        activePriorityMUF[3] = nil
        managedCooldownDurationObjects[1] = nil
        managedCooldownDurationObjects[2] = nil
        managedCooldownDurationObjects[3] = nil
        refreshManagedAfflictedCooldownVisuals()
        refreshAllSharedPriorityCooldownGates()
        for MF in pairs(cooldownMUFs) do
            if MF.Decursive121Priority1Cooldown then MF.Decursive121Priority1Cooldown:Hide() end
            if MF.Decursive121Priority2Cooldown then MF.Decursive121Priority2Cooldown:Hide() end
            if MF.Decursive121Priority3Cooldown then MF.Decursive121Priority3Cooldown:Hide() end
            MF.Decursive121ActiveCooldownPriority = nil
        end
        D:Apply121CooldownAppearance()
        D:Apply121RangeAppearance()
        refreshRangeOverlays()
        return
    end

    -- Appearance/position refresh only.  Live cooldown activation is armed by
    -- UNIT_SPELLCAST_SUCCEEDED so we never need to branch on protected cooldown
    -- state.  Existing Cooldown widgets continue counting down on their own.
    cooldownActive = priorityCooldownActive[1] or priorityCooldownActive[2] or priorityCooldownActive[3]
    refreshManagedAfflictedCooldownVisuals()
    D:Apply121CooldownAppearance()
end

function D:Set121CooldownOverlayEnabled(enabled)
    if not D.profile then return end
    D.profile.CooldownOverlay121Enabled = enabled and true or false
    if not D.profile.CooldownOverlay121Enabled then
        cooldownActive = false
        priorityCooldownActive[1] = false
        priorityCooldownActive[2] = false
        priorityCooldownActive[3] = false
        activePriorityMUF[1] = nil
        activePriorityMUF[2] = nil
        activePriorityMUF[3] = nil
        managedCooldownDurationObjects[1] = nil
        managedCooldownDurationObjects[2] = nil
        managedCooldownDurationObjects[3] = nil
        refreshManagedAfflictedCooldownVisuals()
        refreshAllSharedPriorityCooldownGates()
        for MF in pairs(cooldownMUFs) do
            local cd1 = MF.Decursive121Priority1Cooldown
            local cd2 = MF.Decursive121Priority2Cooldown
            local cd3 = MF.Decursive121Priority3Cooldown
            if cd1 then cd1:Hide() end
            if cd2 then cd2:Hide() end
            if cd3 then cd3:Hide() end
        end
        D:Apply121CooldownAppearance()
    else
        resetTrackedDispelSpell()
        refreshCooldownOverlay()
    end
end

function D:Refresh121CooldownOverlay()
    refreshCooldownOverlay()
end

local function getReadableRemainingDuration(durationObject)
    if not durationObject or not durationObject.GetRemainingDuration then return nil end
    local ok, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
    if not ok or remaining == nil then return nil end
    if issecretvalue and issecretvalue(remaining) then return nil end
    if type(remaining) ~= "number" then return nil end
    return remaining
end

local function reconcilePriorityCooldown(priority)
    if not priorityCooldownActive[priority] then return end

    local spellID = trackedPrioritySpellIDs[priority]
    local targetMF = activePriorityMUF[priority]
    if not spellID then
        finishPriorityCooldown(priority, cooldownGeneration[priority])
        return
    end

    if C_Spell and C_Spell.GetSpellCharges then
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        if chargeInfo and chargeInfo.currentCharges ~= nil then
            local secret = issecretvalue and issecretvalue(chargeInfo.currentCharges)
            if not secret and chargeInfo.currentCharges > 0 then
                finishPriorityCooldown(priority, cooldownGeneration[priority])
                return
            end
        end
    end

    if not C_Spell or not C_Spell.GetSpellCooldownDuration then return end
    local durationObject = C_Spell.GetSpellCooldownDuration(spellID, true)
    if not durationObject then
        finishPriorityCooldown(priority, cooldownGeneration[priority])
        return
    end

    local remaining = getReadableRemainingDuration(durationObject)
    if remaining ~= nil and remaining <= 0.05 then
        finishPriorityCooldown(priority, cooldownGeneration[priority])
        return
    end

    managedCooldownDurationObjects[priority] = durationObject
    if targetMF then clearClickedCooldownVisual(targetMF) end
    refreshSharedPriorityCooldownGates(priority)
end

local function reconcileActivePriorityCooldowns()
    reconcilePriorityCooldown(1)
    reconcilePriorityCooldown(2)
    reconcilePriorityCooldown(3)
    D:Apply121CooldownAppearance()
end

local cooldownEvents = CreateFrame("Frame")
cooldownEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PVP_MATCH_ACTIVE")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PVP_MATCH_COMPLETE")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "CHALLENGE_MODE_START")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "CHALLENGE_MODE_COMPLETED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "CHALLENGE_MODE_RESET")
cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownEvents:RegisterEvent("SPELL_UPDATE_CHARGES")
cooldownEvents:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
cooldownEvents:RegisterEvent("UNIT_SPELLCAST_FAILED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "UNIT_SPELLCAST_INTERRUPTED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "UI_ERROR_MESSAGE")
cooldownEvents:RegisterEvent("UNIT_AURA")
cooldownEvents:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "UNIT_AURA" then
        -- Aura details may be secret; ignore the payload entirely. Blizzard's
        -- AuraContainer updates the active priority slots itself.
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        -- Args are (errorType, message) here, so `unit` is the public error id
        -- and `castGUID` is the localized message.  Use this only immediately
        -- after a MUF secure click; it is a fallback for instant-cast failures
        -- such as line of sight that may not reach the old CLEU result path.
        if lastClickedMUF and lastClickedPriority and (GetTime() - (lastClickedAt or 0)) <= 1.0 then
            local msg = castGUID
            local isRangeError = (SPELL_FAILED_OUT_OF_RANGE and msg == SPELL_FAILED_OUT_OF_RANGE)
                or (ERR_OUT_OF_RANGE and msg == ERR_OUT_OF_RANGE)
            if isRangeError then
                -- User rule: yellow owns out-of-range.  Do not retain a hidden
                -- red failure that could surface if the player steps back into
                -- range before the three-second result window ends.
                lastClickedMUF.Decursive121SuppressFailureUntil = GetTime() + 1.0
                D:Clear121MUFStatusAttempt(lastClickedMUF)
                D:Mark121MUFStatusRange(lastClickedMUF)
            elseif (lastClickedMUF.Decursive121SuppressFailureUntil or 0) > GetTime() then
                -- A cure just succeeded on this MUF (see the post-cure debounce
                -- set below). A spam-click re-cast against an already-cleared
                -- target commonly errors instantly (e.g. "Nothing to Dispel")
                -- here rather than through UNIT_SPELLCAST_FAILED; without this
                -- check that error would paint red over the still-visible green
                -- success result from the click that actually worked.
            else
                D:Mark121MUFStatusFailure(lastClickedMUF, msg or unit or event)
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit ~= "player" then return end
        if not isFriendlyConfiguredDispelSpellID(spellID) then return end
        if lastClickedMUF and (lastClickedMUF.Decursive121SuppressFailureUntil or 0) > GetTime() then
            return
        end
        if lastClickedMUF and (GetTime() - (lastClickedAt or 0)) <= 2.0 then
            -- Modern 12.1 failure path.  The legacy CLEU ClickedMF path is not
            -- available in Midnight, so result feedback must follow the secure
            -- click tracker + UNIT_SPELLCAST events instead.  DandersFrames'
            -- yellow range layer masks this red flash whenever the unit is
            -- currently out of range.
            D:Mark121MUFStatusFailure(lastClickedMUF, event)
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        if isFriendlyConfiguredDispelSpellID(spellID) then
            resetTrackedDispelSpell()
            trackedDispelSpellID = trackedDispelSpellID or spellID

            local priority
            if lastClickedPriority and (GetTime() - (lastClickedAt or 0)) <= 1.5 then
                priority = lastClickedPriority
            elseif trackedPrioritySpellIDs[1] == spellID then priority = 1
            elseif trackedPrioritySpellIDs[2] == spellID then priority = 2
            elseif trackedPrioritySpellIDs[3] == spellID then priority = 3
            else priority = 1 end

            -- The cooldown object may update a fraction after the successful
            -- cast event. Retry the SAFE DurationObject bind without reading
            -- protected numeric/boolean cooldown state. The clicked MUF is only
            -- remembered so it can be excluded; remaining provider-matched MUFs
            -- receive the cooldown indication.
            local targetMF = nil
            if lastClickedMUF and (GetTime() - (lastClickedAt or 0)) <= 1.5 then
                targetMF = lastClickedMUF
            end
            if not targetMF then return end

            -- Modern 12.1 success/result path.  A successful spellcast is only
            -- the start of verification: DandersFrames' protected verifier paints
            -- the dot red if the matching dispel need remains; otherwise the base
            -- dot is green for three seconds.  Yellow range remains the top layer.
            D:Clear121MUFStatusAttempt(targetMF)
            D:Begin121MUFPostCureVerification(targetMF, nil)

            -- Debounce spam-clicking the same MUF right after a cure lands: a
            -- repeat cast against an already-cleared target commonly errors
            -- instantly ("Nothing to Dispel"), which would otherwise paint red
            -- over the green result from the click that actually worked.
            targetMF.Decursive121SuppressFailureUntil = GetTime() + 2.0

            local function arm() armPriorityCooldown(priority, spellID, targetMF) end
            if C_Timer and C_Timer.After then
                -- Allow Blizzard's cooldown/charge state to settle before the
                -- first visible arm, then repeatedly reconcile. Empty-target
                -- dispels often restore their hidden charge shortly afterward;
                -- these delayed reconciles retire the shared cooldown promptly.
                C_Timer.After(.08, arm)
                C_Timer.After(.16, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
                C_Timer.After(.35, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
                C_Timer.After(.70, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
                C_Timer.After(1.25, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
                C_Timer.After(1.75, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
                C_Timer.After(2.50, function() reconcilePriorityCooldown(priority); D:Apply121CooldownAppearance() end)
            else
                arm()
            end
        end
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        reconcileActivePriorityCooldowns()
    else
        refreshCooldownOverlay()
    end
end)

-- Re-resolve the tracked spell whenever Decursive or the player changes the
-- active spell set.  This keeps the overlay correct after spec/talent swaps,
-- learning/unlearning spells, and Decursive curing-order changes.
local function scheduleDispelResolverRefresh()
    trackedDispelSpellID = nil
    trackedPrioritySpellIDs[1] = nil
    trackedPrioritySpellIDs[2] = nil
    trackedPrioritySpellIDs[3] = nil
    if C_Timer and C_Timer.After then
        C_Timer.After(.10, function()
            resetTrackedDispelSpell()
            refreshCooldownOverlay()
        end)
    else
        resetTrackedDispelSpell()
        refreshCooldownOverlay()
    end
end

function D:Refresh121DispelResolver()
    scheduleDispelResolverRefresh()
end

-- Keep the two long-established events direct; register newer/optional talent
-- events defensively so an event-name difference cannot prevent Decursive from
-- loading on a future Retail build.
cooldownEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
cooldownEvents:RegisterEvent("SPELLS_CHANGED")
-- Role assignment commonly lands just after a player spec swap and is also the
-- point where DandersFrames can move the player to a new sorted slot. Use it as
-- a second nudge for the bounded follower-roster stabilization window.
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PLAYER_ROLES_ASSIGNED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PLAYER_TALENT_UPDATE")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "TRAIT_CONFIG_UPDATED")

local originalCooldownEventScript = cooldownEvents:GetScript("OnEvent")
cooldownEvents:SetScript("OnEvent", function(frame, event, ...)
    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PVP_MATCH_ACTIVE"
        or event == "PVP_MATCH_COMPLETE"
        or event == "CHALLENGE_MODE_START"
        or event == "CHALLENGE_MODE_COMPLETED"
        or event == "CHALLENGE_MODE_RESET"
    then
        if C_Timer and C_Timer.After then
            C_Timer.After(.10, function() refreshEnvironmentVisuals(true) end)
        else
            refreshEnvironmentVisuals(true)
        end
        return originalCooldownEventScript(frame, event, ...)
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_ROLES_ASSIGNED"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "TRAIT_CONFIG_UPDATED"
    then
        if event == "PLAYER_SPECIALIZATION_CHANGED"
            and type(D.SchedulePostSpecializationMUFRecovery) == "function" then
            D:SchedulePostSpecializationMUFRecovery()
        elseif event == "PLAYER_ROLES_ASSIGNED"
            and type(D.IsPostSpecializationMUFRecoveryActive) == "function"
            and D:IsPostSpecializationMUFRecoveryActive()
            and type(D.SchedulePostSpecializationMUFRecovery) == "function" then
            -- Extend/restart the bounded retries from the role-assignment edge.
            -- This catches the Elemental -> Restoration transition after DF has
            -- moved the player into the healer-sorted position.
            D:SchedulePostSpecializationMUFRecovery()
        end
        scheduleDispelResolverRefresh()
        return
    end
    return originalCooldownEventScript(frame, event, ...)
end)

-- Decursive's Configure/ReConfigure path is the authoritative source for
-- FoundSpells/CuringSpells. Hook the reconfiguration endpoint so changing cure
-- options or a class-specific spell setup also updates the cooldown target.
local originalReConfigure121 = D.ReConfigure
if originalReConfigure121 then
    D.ReConfigure = function(self, ...)
        local ret = originalReConfigure121(self, ...)
        scheduleDispelResolverRefresh()
        return ret
    end
end

-- Small diagnostic helper for future troubleshooting. It intentionally reports
-- only the selected spell's public identity, never aura information.
function D:Get121CooldownDispelSpell()
    local id, name = resolveConfiguredDispelSpellID()
    return id, name
end

function D:Get121CompatibilityStatusText()
    local _, className = UnitClass and UnitClass("player")
    className = className or "Unknown"

    local specName = "Unknown"
    if GetSpecialization and GetSpecializationInfo then
        local spec = GetSpecialization()
        if spec then
            local _, n = GetSpecializationInfo(spec)
            if n then specName = n end
        end
    end

    local spellID, spellName = resolveConfiguredDispelSpellID()
    local spellText = spellID and ((spellName or "Unknown") .. " (" .. tostring(spellID) .. ")") or "None detected"
    local p1ID, p1Name = resolveConfiguredDispelSpellIDByPriority(1)
    local p2ID, p2Name = resolveConfiguredDispelSpellIDByPriority(2)
    local p1Text = p1ID and ((p1Name or "Unknown") .. " (" .. tostring(p1ID) .. ")") or "None detected"
    local p2Text = p2ID and ((p2Name or "Unknown") .. " (" .. tostring(p2ID) .. ")") or "None detected"

    local managed, dandersManaged, dandersCooldownCarriers, nativeVerificationCarriers, overlays, shown = 0, 0, 0, 0, 0, 0
    for _, MF in pairs(D.MicroUnitF.ExistingPerUNIT or {}) do
        if MF.ManagedAuraContainer then managed = managed + 1 end
        if MF.DandersFramesDispelHandle then dandersManaged = dandersManaged + 1 end
        if MF.Decursive121VerificationNativeContainers then
            for priority = 1, 3 do
                if MF.Decursive121VerificationNativeContainers[priority] then nativeVerificationCarriers = nativeVerificationCarriers + 1 end
            end
        end
        if MF.Decursive121PriorityGateDandersHandles then
            for priority = 1, 3 do
                if MF.Decursive121PriorityGateDandersHandles[priority] then dandersCooldownCarriers = dandersCooldownCarriers + 1 end
            end
        end
        if MF.Shown then shown = shown + 1 end
    end
    for MF in pairs(cooldownMUFs) do
        if MF.Decursive121Priority1Cooldown then overlays = overlays + 1 end
    end

    local providerStatus = D:Get121DispelDetectionProviderStatus()
    local providerText = providerStatus and providerStatus.displayName or "Native Blizzard-managed"
    local providerDetail = ""
    if providerStatus and providerStatus.sessionProvider == PROVIDER_DANDERS then
        if providerStatus.version then providerDetail = " v" .. tostring(providerStatus.version):gsub("^v", "") end
        if providerStatus.reloadRequired then providerDetail = providerDetail .. " (reload pending)" end
    end

    local interfaceVersion = DC and DC.TOC_VERSION or nil
    if not interfaceVersion and GetBuildInfo then
        local _, _, _, toc = GetBuildInfo()
        interfaceVersion = toc
    end

    return table.concat({
        "|cFFFFFFFFDecursive WoW 12.1 Compatibility Status|r",
        "",
        "Patch version: |cFF55DDDD" .. PATCH_VERSION .. "|r",
        "AceDB profile: |cFFFFFFFF" .. tostring((D.db and D.db.GetCurrentProfile and D.db:GetCurrentProfile()) or "Unknown") .. "|r",
        "Environment setting: |cFFFFFFFF" .. getEnvironmentModeSetting() .. "|r",
        "Active environment: |cFFFFFFFF" .. select(3, D:Get121EnvironmentMode()) .. "|r",
        "PvP restricted-aura mode active: |cFFFFFFFF" .. (D:Is121PvPRestrictedMode() and "Yes" or "No") .. "|r",
        "Detection policy: |cFFFFFFFF" .. tostring((getActiveEnvironmentProfile() or {}).Detection121Mode or "STRICT_MANAGED") .. "|r",
        "Detection provider: |cFF55DDDD" .. tostring(providerText) .. providerDetail .. "|r",
        "Shared same-priority cooldown: |cFFFFFFFF" .. (((getActiveEnvironmentProfile() or {}).SharedPriorityCooldown121Enabled == true) and "Yes" or "No") .. "|r",
        "Clear cleansed target visual: |cFFFFFFFF" .. (((getActiveEnvironmentProfile() or {}).ClearCleansedTarget121Enabled ~= false) and "Yes" or "No") .. "|r",
        "Interface: |cFFFFFFFF" .. tostring(interfaceVersion or "Unknown") .. "|r",
        "Class / Spec: |cFFFFFFFF" .. className .. " / " .. specName .. "|r",
        "Detected friendly dispel: |cFF55FF55" .. spellText .. "|r",
        "Priority #1 inner/timer: |cFF55FF55" .. p1Text .. "|r",
        "Priority #2 border: |cFF55FF55" .. p2Text .. "|r",
        "Managed aura filter: |cFF55FF55HARMFUL|RAID_PLAYER_DISPELLABLE|r",
        "Native Decursive carriers: |cFFFFFFFF" .. tostring(managed) .. "|r",
        "DandersFrames detection carriers: |cFFFFFFFF" .. tostring(dandersManaged) .. "|r",
        "DandersFrames cooldown carriers: |cFFFFFFFF" .. tostring(dandersCooldownCarriers) .. "|r",
        "Native verification carriers: |cFFFFFFFF" .. tostring(nativeVerificationCarriers) .. "|r",
        "Per-square cooldown widgets: |cFFFFFFFF" .. tostring(overlays) .. "|r",
        "MUFs currently shown: |cFFFFFFFF" .. tostring(shown) .. "|r",
        "Cooldown display enabled: |cFFFFFFFF" .. ((D.profile and D.profile.CooldownOverlay121Enabled == false) and "No" or "Yes") .. "|r",
        "Cooldown layout: |cFFFFFFFFCleansed MUF clears immediately; cooldown appears only on other still-dispellable MUFs|r",
        "Countdown numbers: |cFFFFFFFF" .. ((D.profile and D.profile.CooldownOverlay121Numbers == false) and "No" or "Yes") .. "|r",
        "Overlay darkness: |cFFFFFFFF" .. tostring(math.floor((((D.profile and D.profile.CooldownOverlay121Opacity) or .62) * 100) + .5)) .. "%|r",
        "Priority #2 border enabled: |cFFFFFFFF" .. ((D.profile and D.profile.CooldownPriority2Border121Enabled == false) and "No" or "Yes") .. "|r",
        "Priority #2 border pulse: |cFFFFFFFF" .. ((D.profile and D.profile.CooldownPriority2Pulse121Enabled == false) and "Off" or "On") .. "|r",
        "Border opacity: |cFFFFFFFF" .. tostring(math.floor((((D.profile and D.profile.CooldownBorder121Alpha) or .95) * 100) + .5)) .. "%|r",
        "Border thickness: |cFFFFFFFF" .. tostring((D.profile and D.profile.CooldownBorder121Thickness) or 2) .. " px|r",
        "Combat lockdown: |cFFFFFFFF" .. ((D.Status and D.Status.Combat) and "Yes" or "No") .. "|r",
        "",
        "This page intentionally does not inspect aura names, types, durations, stacks, or other protected aura details."
    }, "\n")
end

local function getShownCooldownMUFs()
    local list = {}
    for MF in pairs(cooldownMUFs) do
        if MF.Shown then
            list[#list + 1] = MF
        end
    end
    table.sort(list, function(a, b)
        local ap = (type(a.ToPlace) == "number" and a.ToPlace) or a.ID or a.FrameNum or 999
        local bp = (type(b.ToPlace) == "number" and b.ToPlace) or b.ID or b.FrameNum or 999
        return ap < bp
    end)
    return list
end

function D:Get121MUFTestChoices()
    local values = {}
    local list = getShownCooldownMUFs()
    for i, MF in ipairs(list) do
        local unit = MF.CurrUnit or "unit"
        local name = MF.UnitName
        if name and name ~= "" then
            values[i] = "Square " .. tostring(i) .. " - " .. tostring(name)
        else
            values[i] = "Square " .. tostring(i) .. " - " .. tostring(unit)
        end
    end
    if #values == 0 then values[1] = "No visible MUFs" end
    return values
end

function D:Get121MUFTestIndex()
    D.Status = D.Status or {}
    return D.Status.Test121MUFIndex or 1
end

function D:Set121MUFTestIndex(index)
    D.Status = D.Status or {}
    D.Status.Test121MUFIndex = tonumber(index) or 1
end

function D:Test121MUFVisuals(mode, requestedIndex)
    if InCombatLockdown and InCombatLockdown() then return end

    local list = getShownCooldownMUFs()
    if #list == 0 then
        if D.Println then
            D:Println("No visible Micro Unit Frames are available to preview. Show the MUFs or join a group, then try again.")
        end
        return
    end

    previewGeneration = previewGeneration + 1
    local generation = previewGeneration
    local now = GetTime and GetTime() or 0
    previewActive = true
    previewAll = mode == "all"
    previewMUF = nil

    if not previewAll then
        local index = tonumber(requestedIndex) or D:Get121MUFTestIndex() or 1
        if index < 1 then index = 1 end
        if index > #list then index = #list end
        D:Set121MUFTestIndex(index)
        previewMUF = list[index]
    end

    D:Apply121CooldownAppearance()

    for _, MF in ipairs(list) do
        local selected = previewAll or MF == previewMUF
        local cd1 = MF.Decursive121Priority1Cooldown
        local cd2 = MF.Decursive121Priority2Cooldown
        local cd3 = MF.Decursive121Priority3Cooldown
        if selected then
            if cd1 and cd1.SetCooldown then
                cd1:SetCooldown(now, 8)
                cd1:Show()
            end
            if cd2 then cd2:Hide() end
            if cd3 then cd3:Hide() end
        else
            if cd1 then cd1:Hide() end
            if cd2 then cd2:Hide() end
            if cd3 then cd3:Hide() end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(8, function()
            if generation ~= previewGeneration then return end
            previewActive = false
            previewAll = false
            previewMUF = nil
            refreshCooldownOverlay()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Attach compatibility UI to original MUFs
-- ---------------------------------------------------------------------------

local function getClickedCurePriority(button)
    if not button or not D.db or not D.db.global or not D.db.global.MouseButtons then return nil end
    local base
    if button == "LeftButton" then base = "*%s1"
    elseif button == "RightButton" then base = "*%s2"
    elseif button == "MiddleButton" then base = "*%s3"
    elseif button == "Button4" then base = "*%s4"
    elseif button == "Button5" then base = "*%s5"
    else return nil end

    local modifier
    if IsControlKeyDown() then modifier = "ctrl-"
    elseif IsAltKeyDown() then modifier = "alt-"
    elseif IsShiftKeyDown() then modifier = "shift-" end

    local key = modifier and (modifier .. base:sub(-3)) or base
    if D.tGiveValueIndex then
        local p = D:tGiveValueIndex(D.db.global.MouseButtons, key)
        if type(p) == "number" and p >= 1 and p <= 3 then return p end
    end
    return nil
end


local sharedCooldownFormatter
local function getSharedCooldownFormatter()
    if sharedCooldownFormatter then return sharedCooldownFormatter end
    local cs = _G.C_StringUtil
    local enum = _G.Enum
    if cs and cs.CreateNumericRuleFormatter and enum and enum.NumericRuleFormatRounding then
        local formatter = cs.CreateNumericRuleFormatter()
        local rounding = enum.NumericRuleFormatRounding.Up
        local ok = pcall(formatter.SetBreakpoints, formatter, {
            { threshold = 0, format = "%d", step = 1, rounding = rounding },
        })
        if ok then
            sharedCooldownFormatter = formatter
            return formatter
        end
    end
    if cs and cs.CreateSecondsFormatter then
        local formatter = cs.CreateSecondsFormatter()
        if formatter.SetDefaultAbbreviation and enum and enum.SecondsFormatterAbbreviation then
            formatter:SetDefaultAbbreviation(enum.SecondsFormatterAbbreviation.OneLetter)
        end
        if formatter.SetDesiredUnitCount then formatter:SetDesiredUnitCount(1) end
        sharedCooldownFormatter = formatter
        return formatter
    end
    return nil
end

local function getInactivePriorityFilter()
    -- An empty include set intentionally matches no dispel type. This lets the
    -- AuraSlot stay parked when its spell is not on cooldown without any
    -- Show/Hide calls against the managed aura frame.
    return { includeDispelTypes = {} }
end

local function setPriorityGateActive(MF, priority, active, durationObject)
    if not MF then return end
    local nativeContainers = MF.Decursive121PriorityGateContainers
    local dandersHandles = MF.Decursive121PriorityGateDandersHandles
    local container = nativeContainers and nativeContainers[priority]
    local dandersHandle = dandersHandles and dandersHandles[priority]
    if not container and not dandersHandle then return end
    local key = "decursive-priority-" .. tostring(priority)

    -- The clicked/cleansed MUF is ALWAYS excluded. This is based only on our
    -- known secure click target; no protected aura value is inspected.
    local excludeClicked = activePriorityMUF[priority] == MF
    local shouldActivate = active
        and (not D.profile or D.profile.CooldownOverlay121Enabled ~= false)
        and (not D.Is121SharedPriorityCooldownEnabled or D:Is121SharedPriorityCooldownEnabled())
        and not excludeClicked
    MF.Decursive121PriorityGateAppliedActive = MF.Decursive121PriorityGateAppliedActive or {}
    if MF.Decursive121PriorityGateAppliedActive[priority] ~= shouldActivate then
        local applied = false
        if dandersHandle then
            -- DandersFrames candidate filters are creation-time STATIC in v11.
            -- ApplyTuning defers in combat, so we never use it for post-cleanse
            -- state. Instead, DandersFrames keeps owning aura membership while
            -- its plain handle window is toggled by our PUBLIC spell cooldown.
            if dandersHandle.SetIntentShown then
                local ok = safe("DandersFrames shared cooldown visibility", dandersHandle.SetIntentShown, dandersHandle, shouldActivate)
                applied = ok and true or false
            elseif not InCombatLockdown() and dandersHandle.SetShown then
                local ok = safe("DandersFrames shared cooldown visibility", dandersHandle.SetShown, dandersHandle, shouldActivate)
                applied = ok and true or false
            end
        elseif container then
            local holder = MF.Decursive121PriorityGateHolders and MF.Decursive121PriorityGateHolders[priority]
            if holder and holder.SetAlpha then
                holder:SetAlpha(shouldActivate and 1 or 0)
                if shouldActivate and container.UpdateAllAuras then
                    safe("Native shared cooldown refresh", container.UpdateAllAuras, container)
                end
                applied = true
            end
        end
        if applied then MF.Decursive121PriorityGateAppliedActive[priority] = shouldActivate end
    end

    local bindings = MF.Decursive121PriorityCooldownBindings
    local binding = bindings and bindings[priority]
    if binding then
        if shouldActivate and durationObject then
            safe("Priority cooldown text duration", binding.SetDuration, binding, durationObject)
            local showNumbers = not (D.profile and D.profile.CooldownOverlay121Numbers == false)
            if showNumbers then
                safe("Priority cooldown text enable", binding.SetEnabled, binding, true)
                if binding.UpdateFontString then safe("Priority cooldown text update", binding.UpdateFontString, binding) end
            else
                safe("Priority cooldown text disable", binding.SetEnabled, binding, false)
            end
        else
            safe("Priority cooldown text disable", binding.SetEnabled, binding, false)
        end
    end
end

refreshSharedPriorityCooldownGates = function(priority)
    -- Works with either source-of-truth provider. Native toggles candidateFilters;
    -- DandersFrames keeps static candidateFilters and toggles only its handle window.
    if not D.MicroUnitF or not D.MicroUnitF.ExistingPerUNIT then return end
    local active = priorityCooldownActive[priority] and managedCooldownDurationObjects[priority] ~= nil
    local durationObject = managedCooldownDurationObjects[priority]
    for _, MF in pairs(D.MicroUnitF.ExistingPerUNIT) do
        setPriorityGateActive(MF, priority, active, durationObject)
    end
end

refreshAllSharedPriorityCooldownGates = function()
    refreshSharedPriorityCooldownGates(1)
    refreshSharedPriorityCooldownGates(2)
    refreshSharedPriorityCooldownGates(3)
end

function D:Refresh121SharedPriorityCooldowns()
    refreshAllSharedPriorityCooldownGates()
end

attachPriorityCooldownGate = function(MF, Unit, priority)
    if not MF or not MF.Frame or not D.MFContainer then return end
    MF.Decursive121PriorityGateContainers = MF.Decursive121PriorityGateContainers or {}
    MF.Decursive121PriorityGateHolders = MF.Decursive121PriorityGateHolders or {}
    MF.Decursive121PriorityGateFrames = MF.Decursive121PriorityGateFrames or {}
    MF.Decursive121PriorityGateDandersHandles = MF.Decursive121PriorityGateDandersHandles or {}
    MF.Decursive121PriorityGateDandersOnInit = MF.Decursive121PriorityGateDandersOnInit or {}
    MF.Decursive121PriorityCooldownBindings = MF.Decursive121PriorityCooldownBindings or {}
    MF.Decursive121PriorityGateAppliedActive = MF.Decursive121PriorityGateAppliedActive or {}

    local function initializeGateAuraButton(auraButton)
        -- Creation window only. Nothing on this protected aura button or its
        -- child regions is mutated directly after initialization.
        if auraButton.SetSize then auraButton:SetSize(DC.MFSIZE or 20, DC.MFSIZE or 20) end
        if auraButton.EnableMouse then auraButton:EnableMouse(false) end
        if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
        if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end

        -- Static faded fill. The AuraSlot only exists while this priority's
        -- cooldown gate is active AND the selected provider reports a matching
        -- dispel need for the unit.
        local shade = auraButton:CreateTexture(nil, "OVERLAY")
        shade:SetAllPoints(auraButton)
        local r, g, b = getPriorityColor(priority)
        local alpha = (D.profile and D.profile.CooldownOverlay121Opacity) or .62
        shade:SetColorTexture(r * .45, g * .45, b * .45, alpha)

        -- Secret-safe spell cooldown text. DurationTextBinding updates the text
        -- from a DurationObject in C++ without exposing numeric aura data to Lua.
        if _G.C_DurationUtil and _G.C_DurationUtil.CreateDurationTextBinding then
            local text = auraButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("CENTER", auraButton, "CENTER", 0, 0)
            text:SetJustifyH("CENTER")
            text:SetTextColor(1, 1, 1, 1)
            local font, _, flags = text:GetFont()
            if font then text:SetFont(font, math.max(10, math.floor((DC.MFSIZE or 20) * .55)), flags or "OUTLINE") end

            local binding = _G.C_DurationUtil.CreateDurationTextBinding()
            local formatter = getSharedCooldownFormatter()
            if formatter and binding.SetFormatter then binding:SetFormatter(formatter) end
            if binding.SetUpdateInterval then binding:SetUpdateInterval(.05) end
            if binding.SetZeroDurationText then binding:SetZeroDurationText("") end
            if binding.SetExpiredText then binding:SetExpiredText("") end
            binding:SetFontString(text)
            binding:SetEnabled(false)
            MF.Decursive121PriorityCooldownBindings[priority] = binding
        end
    end

    if latchDetectionProvider() == PROVIDER_DANDERS then
        if MF.Decursive121PriorityGateDandersHandles[priority] then return end
        if InCombatLockdown() then return end
        local factory, _, reason = getDandersAuraFactory(true)
        if not factory then
            warnDandersUnavailable(reason)
            return
        end
        MF.Decursive121PriorityGateDandersOnInit[priority] = initializeGateAuraButton
        -- Keep DandersFrames' dispel candidate filter STATIC for the lifetime of
        -- this carrier. The carrier is hidden until the player's cleanse enters
        -- cooldown, then shown only on non-clicked MUFs. This avoids ApplyTuning
        -- in combat while keeping ALL aura membership decisions in DandersFrames.
        local record = makeDandersPriorityGateRecord(priority, { includeDispelTypes = getPriorityDispelTypeFilter(priority) }, initializeGateAuraButton)
        local ok, handle = safe("DandersFrames Create priority cooldown carrier", factory.Create, factory, MF.Frame, {
            unit = Unit,
            mode = "overlay",
            filter = { record },
            frameLevelOffset = 30 + priority,
            enabled = true,
            tooltips = false,
        })
        if ok and handle then
            local valid, validationReason = validateDandersHandle(handle, false)
            if valid and type(handle.SetIntentShown) ~= "function" and type(handle.SetShown) ~= "function" then
                valid = false
                validationReason = "DandersFrames priority carrier is missing SetIntentShown()/SetShown()."
            end
            if valid then
                dandersProviderOperational = true
                dandersProviderHardFailed = false
                dandersProviderFailureReason = nil
                MF.Decursive121PriorityGateDandersHandles[priority] = handle
                MF.Decursive121PriorityGateAppliedActive[priority] = false
                if handle.SetIntentShown then
                    safe("DandersFrames park shared cooldown carrier", handle.SetIntentShown, handle, false)
                elseif handle.SetShown then
                    safe("DandersFrames park shared cooldown carrier", handle.SetShown, handle, false)
                end
            else
                destroyDandersHandle(handle)
                warnDandersUnavailable(validationReason)
            end
        else
            warnDandersUnavailable("DandersFrames could not create the priority cooldown AuraContainer carrier.")
        end
        return
    end

    if MF.Decursive121PriorityGateContainers[priority] then return end
    -- Native cooldown carriers use the same static-membership strategy as the
    -- DandersFrames provider: Blizzard owns the AuraSlot filter continuously;
    -- Decursive only changes the alpha of an addon-owned holder when the public
    -- cleanse spell enters/leaves cooldown.
    local holder = CreateFrame("Frame", nil, MF.Frame)
    holder:SetAllPoints(MF.Frame)
    if holder.EnableMouse then holder:EnableMouse(false) end
    if holder.SetFrameLevel and MF.Frame.GetFrameLevel then holder:SetFrameLevel(MF.Frame:GetFrameLevel() + 30 + priority) end
    holder:SetAlpha(0)
    holder:Show()

    local ok, container = safe("Create priority AuraContainer", CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not ok or not container then return end
    MF.Decursive121PriorityGateContainers[priority] = container
    MF.Decursive121PriorityGateHolders[priority] = holder
    container:SetAllPoints(holder)
    if container.Show then safe("Priority AuraContainer initial Show", container.Show, container) end
    if container.EnableMouse then safe("Priority AuraContainer EnableMouse", container.EnableMouse, container, false) end

    -- Blizzard's required standing-container order is SetUnit -> AddAuraSlot ->
    -- anchor returned slot -> SetEnabled LAST. Alpha 22 added the slot before
    -- SetUnit and never anchored it, which could leave native cooldown feedback
    -- invisible even when Blizzard matched the aura correctly.
    if container.SetUnit then safe("Priority AuraContainer SetUnit", container.SetUnit, container, Unit) end

    local key = "decursive-priority-" .. tostring(priority)
    local options = {
        initializeFrame = initializeGateAuraButton,
        candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(priority) },
    }
    local gateFrame
    if container.AddAuraSlot then
        local success, returned = safe("Priority AuraContainer AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
        if success then
            gateFrame = returned
            if returned then anchorNativeAuraSlot(returned, holder, "Native cooldown AuraSlot") end
        end
    else
        D:errln("12.1 managed priority gate: AuraContainer has no AddAuraSlot method")
    end
    MF.Decursive121PriorityGateFrames[priority] = gateFrame
    if container.SetEnabled then safe("Priority AuraContainer SetEnabled", container.SetEnabled, container, true) end
    if container.UpdateAllAuras then safe("Priority AuraContainer initial refresh", container.UpdateAllAuras, container) end
end

refreshPriorityGateFilters = function(MF)
    if not MF or (not MF.Decursive121PriorityGateContainers and not MF.Decursive121PriorityGateDandersHandles) then return end
    for priority = 1, 3 do
        -- DandersFrames filter membership remains the source of truth. Configuration
        -- changes may retune the STATIC carrier only out of combat; live post-cast
        -- cooldown state never calls ApplyTuning.
        local dandersHandle = MF.Decursive121PriorityGateDandersHandles and MF.Decursive121PriorityGateDandersHandles[priority]
        if dandersHandle and dandersHandle.ApplyTuning and not InCombatLockdown() then
            local init = MF.Decursive121PriorityGateDandersOnInit and MF.Decursive121PriorityGateDandersOnInit[priority]
            local record = makeDandersPriorityGateRecord(priority, { includeDispelTypes = getPriorityDispelTypeFilter(priority) }, init)
            safe("DandersFrames refresh shared cooldown filter", dandersHandle.ApplyTuning, dandersHandle, { filter = { record } })
        end
        local verifyHandle = MF.Decursive121VerificationDandersHandles and MF.Decursive121VerificationDandersHandles[priority]
        if verifyHandle and verifyHandle.ApplyTuning and not InCombatLockdown() then
            local init = MF.Decursive121VerificationDandersOnInit and MF.Decursive121VerificationDandersOnInit[priority]
            local record = makeDandersVerificationRecord(priority, init)
            safe("DandersFrames refresh cure verification filter", verifyHandle.ApplyTuning, verifyHandle, { filter = { record } })
        end
        if not InCombatLockdown() then
            local nativeGate = MF.Decursive121PriorityGateContainers and MF.Decursive121PriorityGateContainers[priority]
            if nativeGate and nativeGate.SetAuraSlotCandidateFilters then
                safe("Native refresh shared cooldown filter", nativeGate.SetAuraSlotCandidateFilters, nativeGate,
                    "decursive-priority-" .. tostring(priority),
                    { includeDispelTypes = getPriorityDispelTypeFilter(priority) })
            end
            local nativeVerify = MF.Decursive121VerificationNativeContainers and MF.Decursive121VerificationNativeContainers[priority]
            if nativeVerify and nativeVerify.SetAuraSlotCandidateFilters then
                safe("Native refresh cure verification filter", nativeVerify.SetAuraSlotCandidateFilters, nativeVerify,
                    "zhaohu-native-verify-priority-" .. tostring(priority),
                    { includeDispelTypes = getPriorityDispelTypeFilter(priority) })
            end
        end
        MF.Decursive121PriorityGateAppliedActive = MF.Decursive121PriorityGateAppliedActive or {}
        MF.Decursive121PriorityGateAppliedActive[priority] = nil
        local active = priorityCooldownActive[priority] and managedCooldownDurationObjects[priority] ~= nil
        setPriorityGateActive(MF, priority, active, managedCooldownDurationObjects[priority])
    end
end

local pendingDandersAttach = setmetatable({}, { __mode = "k" })
local pendingNativeAttach = setmetatable({}, { __mode = "k" })
local attachManagedAura

local function attachClickTracking(MF)
    if MF.Frame and MF.Frame.HookScript and not clickHookedFrames[MF.Frame] then
        clickHookedFrames[MF.Frame] = true
        MF.Frame:HookScript("PostClick", function(_, button)
            lastClickedMUF = MF
            lastClickedPriority = getClickedCurePriority(button)
            lastClickedAt = GetTime()
        end)
    end
end

validateDandersHandle = function(handle, needsTuning)
    if type(handle) ~= "table" then return false, "DandersFrames returned an invalid AuraContainer handle." end
    if type(handle.SetUnit) ~= "function" then
        return false, "DandersFrames AuraContainer handle is missing SetUnit()."
    end
    if needsTuning and type(handle.ApplyTuning) ~= "function" then
        return false, "DandersFrames AuraContainer handle is missing ApplyTuning(), required for Decursive cooldown gates."
    end
    return true
end

destroyDandersHandle = function(handle)
    if handle and type(handle.Destroy) == "function" and not InCombatLockdown() then
        pcall(handle.Destroy, handle)
    end
end

local function attachDandersManagedAura(MF, Unit)
    if type(D.RegisterDandersFramesOrderSync) == "function" then
        pcall(D.RegisterDandersFramesOrderSync, D)
    end
    if MF.DandersFramesDispelHandle then
        -- Detection only: cooldown UI stays entirely Decursive-owned, while
        -- DandersFrames supplies the pre-filtered membership carrier for each
        -- remaining-target cooldown priority. These must exist BEFORE combat.
        attachPriorityCooldownGate(MF, Unit or MF.CurrUnit, 1)
        attachPriorityCooldownGate(MF, Unit or MF.CurrUnit, 2)
        attachPriorityCooldownGate(MF, Unit or MF.CurrUnit, 3)
        attachDandersVerificationCarriers(MF, Unit or MF.CurrUnit)
        attachCooldownOverlay(MF)
        attachClickTracking(MF)
        return true
    end
    if not D.MFContainer or not MF or not MF.Frame then return false end
    if InCombatLockdown() then
        pendingDandersAttach[MF] = Unit or MF.CurrUnit
        return false
    end

    local factory, _, reason = getDandersAuraFactory(true)
    if not factory then
        warnDandersUnavailable(reason)
        return false
    end

    local records = buildDandersPriorityRecords(MF)
    if #records == 0 then
        -- Never let the factory normalize an empty record list to HELPFUL.
        records[1] = {
            filter = "HARMFUL|RAID_PLAYER_DISPELLABLE",
            key = "zhaohu-no-configured-dispel",
            candidateFilters = { includeDispelTypes = {} },
        }
    end

    local ok, handle = safe("DandersFrames Create dispel detection carrier", factory.Create, factory, MF.Frame, {
        unit = Unit,
        mode = "overlay",
        filter = records,
        frameLevelOffset = 20,
        enabled = true,
        tooltips = false,
    })
    if not ok or not handle then
        warnDandersUnavailable("DandersFrames could not create the dispel detection AuraContainer carrier.")
        return false
    end
    local valid, validationReason = validateDandersHandle(handle, true)
    if not valid then
        destroyDandersHandle(handle)
        warnDandersUnavailable(validationReason)
        return false
    end

    dandersProviderOperational = true
    dandersProviderHardFailed = false
    dandersProviderFailureReason = nil
    MF.DandersFramesDispelHandle = handle
    MF.DandersFramesDispelUnit = Unit
    pendingDandersAttach[MF] = nil

    -- DandersFrames stops here for primary detection. Build the three STATIC
    -- priority-filtered carriers now, out of combat, so a successful cleanse can
    -- immediately reveal cooldown feedback on OTHER still-dispellable MUFs.
    -- Decursive owns the player's cooldown/timer; DandersFrames owns membership.
    attachPriorityCooldownGate(MF, Unit, 1)
    attachPriorityCooldownGate(MF, Unit, 2)
    attachPriorityCooldownGate(MF, Unit, 3)
    attachDandersVerificationCarriers(MF, Unit)
    attachCooldownOverlay(MF)
    attachClickTracking(MF)
    return true
end

local function attachNativeManagedAura(MF, Unit)
    if MF.ManagedAuraContainer then
        attachPriorityCooldownGate(MF, Unit, 1)
        attachPriorityCooldownGate(MF, Unit, 2)
        attachPriorityCooldownGate(MF, Unit, 3)
        attachNativeVerificationCarriers(MF, Unit or MF.CurrUnit)
        attachCooldownOverlay(MF)
        attachClickTracking(MF)
        return
    end
    if not D.MFContainer then return end
    if InCombatLockdown() then
        pendingNativeAttach[MF] = Unit or MF.CurrUnit
        return
    end

    -- Native parity provider: ask Blizzard's managed AuraContainer directly for
    -- the same three priority-filtered protected dispel decisions that the
    -- DandersFrames provider asks through its factory.  Decursive never reads
    -- aura identity/presence back into Lua; the AuraSlot itself is the decision.
    local ok, container = safe("Create native dispel AuraContainer", CreateFrame, "AuraContainer", nil, MF.Frame, "CustomAuraContainerTemplate")
    if not ok or not container then return end

    MF.ManagedAuraContainer = container
    MF.Decursive121NativeDetectionKeys = {}
    container:SetAllPoints(MF.Frame)
    if container.EnableMouse then safe("Native detector EnableMouse", container.EnableMouse, container, false) end
    if container.SetFrameLevel and MF.Frame.GetFrameLevel then container:SetFrameLevel(MF.Frame:GetFrameLevel() + 20) end
    if container.SetUnit then safe("Native detector SetUnit", container.SetUnit, container, Unit) end

    if container.AddAuraSlot then
        for priority = 3, 1, -1 do
            local include = getPriorityDispelTypeFilter(priority)
            if tableHasAnyKey(include) then
                local p = priority
                local key = "zhaohu-native-priority-" .. tostring(p)
                local options = {
                    initializeFrame = function(btn) initializeProviderPriorityButton(btn, p, MF) end,
                    candidateFilters = { includeDispelTypes = include },
                }
                local slotOK, slotButton = safe("Native detector AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                if slotOK then
                    MF.Decursive121NativeDetectionKeys[p] = key
                    if slotButton then
                        anchorNativeAuraSlot(slotButton, MF.Frame, "Native detection AuraSlot")
                    end
                end
            end
        end
    else
        D:errln("12.1 native managed aura: AuraContainer has no AddAuraSlot method")
    end
    -- SetEnabled LAST, after the unit, slot declarations and slot anchors exist.
    if container.SetEnabled then safe("Native detector SetEnabled", container.SetEnabled, container, true) end
    if container.Show then safe("Native detector Show", container.Show, container) end
    -- Force one dirty-mark after initialization so an aura that was already on
    -- the unit when the MUF was created is rendered immediately.
    if container.UpdateAllAuras then safe("Native detector initial refresh", container.UpdateAllAuras, container) end

    attachPriorityCooldownGate(MF, Unit, 1)
    attachPriorityCooldownGate(MF, Unit, 2)
    attachPriorityCooldownGate(MF, Unit, 3)
    attachNativeVerificationCarriers(MF, Unit)
    attachCooldownOverlay(MF)
    attachClickTracking(MF)
    pendingNativeAttach[MF] = nil
end

attachManagedAura = function(MF, Unit)
    if latchDetectionProvider() == PROVIDER_DANDERS then
        -- Strict source-of-truth mode: NEVER build the native detector as a
        -- fallback while DandersFrames integration is selected.
        attachDandersManagedAura(MF, Unit)
        return
    end
    attachNativeManagedAura(MF, Unit)
end

local providerRetryFrame = CreateFrame("Frame")
providerRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
providerRetryFrame:SetScript("OnEvent", function()
    if latchDetectionProvider() == PROVIDER_DANDERS then
        for MF, unit in pairs(pendingDandersAttach) do
            if MF and MF.Frame then attachDandersManagedAura(MF, MF.CurrUnit or unit) end
        end
    else
        for MF, unit in pairs(pendingNativeAttach) do
            if MF and MF.Frame then attachNativeManagedAura(MF, MF.CurrUnit or unit) end
        end
    end
end)

-- Patch the original MUF constructor instead of replacing the original frame.
local MicroUnitF = D.MicroUnitF
if not MicroUnitF or not MicroUnitF.prototype then return end

local originalInit = MicroUnitF.prototype.init
MicroUnitF.prototype.init = function(self, Container, Unit, FrameNum, ID)
    originalInit(self, Container, Unit, FrameNum, ID)
    attachManagedAura(self, Unit)
    D:Refresh121MUFStateSoundUnit(self.CurrUnit or Unit, true)
end

-- Keep the managed container pointed at the exact unit represented by the
-- original secure MUF. Unit changes are protected and already deferred by
-- Decursive until out of combat; we follow the same rule.
local originalUpdateAttributes = MicroUnitF.prototype.UpdateAttributes
MicroUnitF.prototype.UpdateAttributes = function(self, Unit, DoNotDelay)
    local ret = originalUpdateAttributes(self, Unit, DoNotDelay)
    if not InCombatLockdown() then
        local resolvedUnit = self.CurrUnit or Unit
        D:Refresh121MUFStateSoundUnit(resolvedUnit, true)
        if latchDetectionProvider() == PROVIDER_DANDERS then
            local handle = self.DandersFramesDispelHandle
            if handle and handle.SetUnit then
                safe("DandersFrames dispel carrier SetUnit", handle.SetUnit, handle, resolvedUnit)
            elseif self.Frame then
                attachDandersManagedAura(self, resolvedUnit)
            end
            if self.Decursive121PriorityGateDandersHandles then
                for priority = 1, 3 do
                    local gate = self.Decursive121PriorityGateDandersHandles[priority]
                    if gate and gate.SetUnit then
                        safe("DandersFrames priority carrier SetUnit", gate.SetUnit, gate, resolvedUnit)
                    end
                end
            end
            if self.Decursive121VerificationDandersHandles then
                for priority = 1, 3 do
                    local verify = self.Decursive121VerificationDandersHandles[priority]
                    if verify and verify.SetUnit then
                        safe("DandersFrames verification carrier SetUnit", verify.SetUnit, verify, resolvedUnit)
                    end
                end
            end
        elseif self.ManagedAuraContainer and self.ManagedAuraContainer.SetUnit then
            safe("AuraContainer SetUnit update", self.ManagedAuraContainer.SetUnit, self.ManagedAuraContainer, resolvedUnit)
            if self.ManagedAuraContainer.UpdateAllAuras then
                safe("AuraContainer retarget refresh", self.ManagedAuraContainer.UpdateAllAuras, self.ManagedAuraContainer)
            end
            if self.Decursive121PriorityGateContainers then
                for priority = 1, 3 do
                    local gateContainer = self.Decursive121PriorityGateContainers[priority]
                    if gateContainer and gateContainer.SetUnit then
                        safe("Priority AuraContainer SetUnit update", gateContainer.SetUnit, gateContainer, resolvedUnit)
                        if gateContainer.UpdateAllAuras then
                            safe("Priority AuraContainer retarget refresh", gateContainer.UpdateAllAuras, gateContainer)
                        end
                    end
                end
            end
            if self.Decursive121VerificationNativeContainers then
                for priority = 1, 3 do
                    local verifyContainer = self.Decursive121VerificationNativeContainers[priority]
                    if verifyContainer and verifyContainer.SetUnit then
                        safe("Native verification AuraContainer SetUnit update", verifyContainer.SetUnit, verifyContainer, resolvedUnit)
                        if verifyContainer.UpdateAllAuras then
                            safe("Native verification AuraContainer retarget refresh", verifyContainer.UpdateAllAuras, verifyContainer)
                        end
                    end
                end
            end
        end
    end
    return ret
end

-- Sync the separate compatibility layers with original MUF visibility.
local originalDisplayUpdate = MicroUnitF.MFsDisplay_Update
MicroUnitF.MFsDisplay_Update = function(self, ...)
    local ret = originalDisplayUpdate(self, ...)
    if not InCombatLockdown() then
        for _, MF in pairs(self.ExistingPerUNIT or {}) do
            -- ManagedAuraContainer is parented to MF.Frame and therefore follows
            -- Blizzard/Decursive visibility automatically. Never Show/Hide it.
            syncCooldownOverlayToMUF(MF)
            syncRangeOverlayToMUF(MF)
        end
        D:Apply121CooldownAppearance()
    end
    return ret
end

-- square-sound16: true post-zone Decursive soft reinitialization.
--
-- /reload works because the MUF visibility counters, unit roster and managed
-- aura providers all start from one coherent snapshot. On PLAYER_ENTERING_WORLD
-- Blizzard/DandersFrames can briefly expose only player/pet before the final
-- instance party exists. Replaying only GroupChanged() preserves stale Shown
-- flags and UnitShown, so Decursive never fully reconstructs the grid.
--
-- This routine deliberately resets the *runtime state* of existing MUFs without
-- destroying secure frames. Once the roster is stable, the normal Decursive
-- display/update pipeline repopulates the grid and we retarget all managed 12.1
-- aura providers to the final unit tokens.
local ZONE_REINIT_GENERATION = 0
local ZONE_REINIT_DELAYS = { 0.15, 0.50, 1.00, 2.00, 4.00, 7.00 }

local function resetMUFsForZoneReinit()
    local muf = D.MicroUnitF
    if not muf or type(muf.ExistingPerUNIT) ~= "table" then return end

    muf.UnitShown = 0
    muf.LastEffectivePerLine = nil

    for _, MF in pairs(muf.ExistingPerUNIT) do
        if MF then
            MF.Shown = false
            MF.ToPlace = true
            MF.ID = 0
            MF.Debuffs = EMPTY_TABLE or {}
            MF.Debuff1Prio = false
            MF.PrevDebuff1Prio = false
            MF.UnitStatus = 0
            MF.UpdateCountDown = 0
            if MF.Frame and MF.Frame.Hide then
                safe("Post-zone reset MUF Hide", MF.Frame.Hide, MF.Frame)
            end
        end
    end
end

local function rebuildMUFsAfterZone(reason)
    if not D.DcrFullyInitialized then return false end
    if InCombatLockdown() then
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr_PostZoneFullReinit", rebuildMUFsAfterZone, reason)
        end
        return false
    end

    D.Groups_datas_are_invalid = true
    if D.GetUnitArray then D:GetUnitArray() end

    -- Let the normal updater create any MUFs that did not exist before this zone.
    -- Running several passes here avoids waiting for the periodic updater to
    -- eventually create party3/party4 after a transient player-only snapshot.
    if D.DebuffsFrame_Update then
        for _ = 1, 12 do D:DebuffsFrame_Update() end
    end

    if D.MicroUnitF and D.MicroUnitF.MFsDisplay_Update then
        D.MicroUnitF:MFsDisplay_Update()
    end

    local existing = D.MicroUnitF and D.MicroUnitF.ExistingPerUNIT
    if type(existing) == "table" then
        for unit, MF in pairs(existing) do
            if MF and MF.Frame then
                local resolvedUnit = MF.CurrUnit or unit
                if MF.UpdateAttributes then
                    safe("Post-zone MUF UpdateAttributes", MF.UpdateAttributes, MF, resolvedUnit, true)
                end
                if latchDetectionProvider() == PROVIDER_DANDERS then
                    local h = MF.DandersFramesDispelHandle
                    if h and h.SetUnit then
                        safe("Post-zone Danders SetUnit", h.SetUnit, h, resolvedUnit)
                    else
                        attachDandersManagedAura(MF, resolvedUnit)
                    end
                elseif MF.ManagedAuraContainer then
                    if MF.ManagedAuraContainer.SetUnit then
                        safe("Post-zone native SetUnit", MF.ManagedAuraContainer.SetUnit, MF.ManagedAuraContainer, resolvedUnit)
                    end
                    if MF.ManagedAuraContainer.UpdateAllAuras then
                        safe("Post-zone native UpdateAllAuras", MF.ManagedAuraContainer.UpdateAllAuras, MF.ManagedAuraContainer)
                    end
                else
                    attachNativeManagedAura(MF, resolvedUnit)
                end
            end
        end
    end

    if D.MicroUnitF and D.MicroUnitF.Delayed_Force_FullUpdate then
        D.MicroUnitF:Delayed_Force_FullUpdate()
    end
    if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds(reason or "post-zone full reinit") end
    if T and T._AuraSoundDiag then T._AuraSoundDiag.lastZoneReinit = reason or "post-zone full reinit" end
    return true
end

function D:ReinitializeDecursiveAfterZone(reason)
    ZONE_REINIT_GENERATION = ZONE_REINIT_GENERATION + 1
    local generation = ZONE_REINIT_GENERATION

    if not InCombatLockdown() then resetMUFsForZoneReinit() end
    self.Groups_datas_are_invalid = true

    local function pass(delay)
        if generation ~= ZONE_REINIT_GENERATION or not D.DcrFullyInitialized then return end
        D.Groups_datas_are_invalid = true
        rebuildMUFsAfterZone((reason or "zone") .. " @" .. tostring(delay))
    end

    if C_Timer and C_Timer.After then
        for i = 1, #ZONE_REINIT_DELAYS do
            local delay = ZONE_REINIT_DELAYS[i]
            C_Timer.After(delay, function() pass(delay) end)
        end
    else
        pass(0)
    end
    return true
end

-- Backward-compatible name used by earlier square-sound test builds.
D.Reinitialize121MUFProvidersAfterZone = D.ReinitializeDecursiveAfterZone

-- Refresh indicator colors after the original options panel updates MUF colors.
local originalRegisterColors = MicroUnitF.RegisterMUFcolors
if originalRegisterColors then
    MicroUnitF.RegisterMUFcolors = function(self, colors, ...)
        local ret = originalRegisterColors(self, colors, ...)
        -- Managed aura button state is intentionally never enumerated/read here.
        -- Newly-created buttons inherit the updated configured alert color.
        return ret
    end
end

-- Once Decursive finishes configuring its curing spells, initialize the first
-- cooldown target and refresh the compatibility overlays.
if C_Timer and C_Timer.After then
    C_Timer.After(1.0, function()
        resetTrackedDispelSpell()
        refreshCooldownOverlay()
    end)
end

D:Debug("WoW 12.1 managed-aura + cooldown compatibility adapter loaded")
