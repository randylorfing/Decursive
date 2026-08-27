--[[
    This file is part of Decursive.

    WoW 12.1 compatibility module for Decursive. This file was solely
    written by Randy Lorfing.
    Copyright (C) 2026 Randy Lorfing

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive.  If not, see <https://www.gnu.org/licenses/>.

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

local PATCH_VERSION = "@project-version@"

local function isAccessiblePublicValue(value)
    if not canaccessvalue(value) then return false end
    return not issecretvalue or not issecretvalue(value)
end

-- AuraContainer topology is not the same restriction boundary as aura data.
-- Blizzard deliberately permits container/button construction while aura data
-- is secret (initializeFrame runs before the AuraButton is sealed).  The MUF
-- parent is a secure action frame, however, so its child topology/retargeting
-- remains deferred during ordinary combat lockdown.
local function nativeConfigurationBlocked()
    return InCombatLockdown and InCombatLockdown() or false
end

-- Post-initialization access to an AuraButton or a registered child is a
-- separate boundary.  Use this conservative fallback only when the object
-- cannot answer CanBeAccessedInContext() for itself.
local function nativeAuraDisplayMutationBlocked()
    if nativeConfigurationBlocked() then return true end
    return D.HasActiveAddonRestriction and D:HasActiveAddonRestriction() or false
end

local function safe(label, fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        if D and D.errln then D:errln("12.1 compatibility:", label, a) end
        return false
    end
    return true, a, b, c
end

-- ---------------------------------------------------------------------------
-- Dispel detection provider (native Blizzard-managed AuraContainer only)
-- ---------------------------------------------------------------------------
local PROVIDER_NATIVE = "NATIVE"

function D:Get121DispelDetectionProviderStatus()
    return {
        configuredEnabled = false,
        autoDetected = false,
        automaticSelection = false,
        userSet = false,
        configuredAtLatch = false,
        sessionProvider = PROVIDER_NATIVE,
        available = true,
        active = true,
        reloadRequired = false,
        version = nil,
        displayName = "Native Blizzard-managed",
        operational = true,
        reason = nil,
    }
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
}

local ENVIRONMENT_DEFAULTS = {
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
        TextAlerts121Enabled = true,
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
        TextAlerts121Enabled = true,
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
        TextAlerts121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    PVP = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
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
        TextAlerts121Enabled = false,
        EnvironmentChat121Enabled = false,
    },
    OPEN_WORLD = {
        OutOfRange121Enabled = false,
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
        TextAlerts121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
}

-- One canonical table is shared with the modern options layer so resetting an
-- environment from either UI always produces the same behavior.
D.Environment121Defaults = ENVIRONMENT_DEFAULTS

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

    -- Range status is intentionally instance-only. Correct older profiles that
    -- inherited the former global setting into Open World before this gate was
    -- introduced; the player can still tune the instanced profiles separately.
    if not D.profile.OpenWorldRangeDisabled121Migrated then
        D.profile.Environment121Profiles.OPEN_WORLD.OutOfRange121Enabled = false
        D.profile.OpenWorldRangeDisabled121Migrated = true
    end

    -- v11.0.45: shorten the original three-second TIMED warning default to two
    -- seconds. Preserve profiles already set to a duration other than 3 seconds.
    if not D.profile.Alert121DispelDuration2sMigrated then
        local oldDuration = tonumber(D.profile.Alert121DispelDuration)
        if oldDuration == nil or math.abs(oldDuration - 3) < 0.001 then
            D.profile.Alert121DispelDuration = 2
        end
        D.profile.Alert121DispelDuration2sMigrated = true
    end

    -- v12.0.1: PvP profiles start quiet. Apply this once to profiles created by
    -- older builds, then leave the setting user-controlled from that point on.
    if not D.profile.PvPTextAlertsDefaultOff121Migrated then
        local pvp = D.profile.Environment121Profiles.PVP
        if type(pvp) == "table" then
            pvp.TextAlerts121Enabled = false
            pvp.EnvironmentChat121Enabled = false
        end
        D.profile.PvPTextAlertsDefaultOff121Migrated = true
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
                    if ok and isAccessiblePublicValue(mapID) and type(mapID) == "number" and mapID > 0 then
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

function D:Are121TextAlertsEnabled()
    local env = getActiveEnvironmentProfile()
    return not env or env.TextAlerts121Enabled ~= false
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
    D.profile.TextAlerts121Enabled = env.TextAlerts121Enabled ~= false
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
    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
    if D.profile.TextAlerts121Enabled == false and D.Hide121AlertWarning then D:Hide121AlertWarning() end
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
    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
    if D.Are121TextAlertsEnabled and not D:Are121TextAlertsEnabled()
        and D.Hide121AlertWarning then
        D:Hide121AlertWarning()
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
-- WoW 12.1 protected-aura sound trigger
-- ---------------------------------------------------------------------------
-- Protected AuraSlot presentation does not reliably invoke addon-owned script
-- callbacks once Blizzard seals the aura subtree. Live sound therefore uses
-- C_UnitAuras.AddAuraSound: Decursive registers public DispelDB/learned spell
-- IDs for assigned group unit tokens while out of combat, and Blizzard owns the
-- protected detection and playback. Addon Lua never reads AuraSlot visibility
-- or protected aura details.
function D:Is121MUFStateSoundEngineAvailable()
    return type(self.RefreshProtectedAuraSounds) == "function"
        and type(self.IsProtectedAuraSoundEngineAvailable) == "function"
        and self:IsProtectedAuraSoundEngineAvailable()
end

function D:Is121MUFVisibilitySoundDriverEnabled()
    -- Kept for compatibility with older option panels. The former child-frame
    -- OnShow driver is intentionally disabled under the 12.1 protected-aura
    -- rules; reporting it active would suppress every native AddAuraSound
    -- registration and leave live combat alerts silent.
    return false
end

-- Compatibility names retained because other v11 code calls them when MUFs are
-- created/retargeted. They no longer inspect aura state.
function D:Refresh121MUFStateSoundUnit(_unit, _suppressAlert)
    return nil
end

function D:Refresh121MUFStateSoundBaseline()
    -- Native aura-sound registrations are independent of the current aura
    -- state and do not need to be rebuilt after each cure. Re-registering from
    -- the secure click/spellcast path can trigger ADDON_ACTION_BLOCKED even
    -- through pcall. Roster/spec/settings changes request their own refresh;
    -- combat-time requests are centrally deferred to PLAYER_REGEN_ENABLED.
    return nil
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
auraSoundRegistryEventFrame:RegisterEvent("SPELLS_CHANGED")
auraSoundRegistryEventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
auraSoundRegistryEventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
auraSoundRegistryEventFrame:SetScript("OnEvent", function(_, event)
    if not D.DcrFullyInitialized or type(D.RefreshProtectedAuraSounds) ~= "function" then return end
    -- VuhDo's reliable lifecycle synchronizes a unit as soon as its roster
    -- event frame is registered. Do the equivalent reconciliation immediately
    -- on the public roster edge; the guarded call becomes a no-op/deferred
    -- request if Blizzard has already activated a restriction. A later pass
    -- reconciles the authoritative Decursive ordering.
    if event == "GROUP_ROSTER_UPDATE" then
        D:RefreshProtectedAuraSounds(event .. " immediate")
    end
    if C_Timer and C_Timer.After then
        local delay = event == "PLAYER_ENTERING_WORLD" and 1.0
            or (event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED") and 0.50
            or 0.20
        C_Timer.After(delay, function()
            if D.DcrFullyInitialized then D:RefreshProtectedAuraSounds(event) end
        end)
    else
        D:RefreshProtectedAuraSounds(event)
    end
end)

-- Blizzard-managed dispellable aura indicator
-- ---------------------------------------------------------------------------

-- Priority colors are owned by Decursive's existing MUF color table.  The
-- managed-aura layer chooses them from Decursive's public cure-priority setup;
-- addon Lua never reads an aura's protected dispel type.
local function getPriorityColor(priority)
    local c = D.profile and D.profile.MF_colors and D.profile.MF_colors[priority]
    if type(c) == "table" then
        return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
    end
    if priority == 1 then return .8, 0, 0, 1 end
    if priority == 2 then return .25, .45, 1, 1 end
    return .7, .25, 1, 1
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
-- Yellow wins whenever Blizzard reports out of range. When in range,
-- red/green transient result feedback wins over normal gray.
-- LoS remains red only after an actual failed cleanse because WoW does not
-- expose a continuous public line-of-sight query.
local statusLightMUFs = setmetatable({}, { __mode = "k" })
local STATUS_READY   = { .34, .34, .34, 0 }
local STATUS_RANGE   = { 1.00, .82, 0.00, 1.00 }
local STATUS_FAILED  = { 1.00, .08, .08, 1.00 }
local STATUS_SUCCESS = { .10, 1.00, .24, 1.00 }
local STATUS_CLEAR   = { 1.00, 1.00, 1.00, 0.00 }

-- Native range may return a secret boolean (IsSpellInRange / UnitInRange).
-- WoW 12.1 allows that value to be passed directly to
-- Texture:SetVertexColorFromBoolean() without reading, comparing or branching
-- on the protected value.  Alpha.20 uses TWO layers:
--   result/base layer: gray, red, or green when in range; transparent when out
--   range layer:       transparent when in range; yellow when out
-- This makes yellow a secret-safe hard override.
local STATUS_READY_COLOR   = CreateColor and CreateColor(unpack(STATUS_READY)) or nil
local STATUS_RANGE_COLOR   = CreateColor and CreateColor(unpack(STATUS_RANGE)) or nil
local STATUS_FAILED_COLOR  = CreateColor and CreateColor(unpack(STATUS_FAILED)) or nil
local STATUS_SUCCESS_COLOR = CreateColor and CreateColor(unpack(STATUS_SUCCESS)) or nil
local STATUS_CLEAR_COLOR   = CreateColor and CreateColor(unpack(STATUS_CLEAR)) or nil

local function statusColorObject(color)
    if color == STATUS_FAILED then return STATUS_FAILED_COLOR end
    if color == STATUS_SUCCESS then return STATUS_SUCCESS_COLOR end
    return STATUS_READY_COLOR
end

-- Native range source for status lights. Prefer the actual friendly cure spell
-- Decursive selected for this character; if the spell API has no answer,
-- UnitInRange is used as the fallback. A 12.1 secret boolean is NEVER inspected
-- here -- it is returned intact and passed directly to
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
    local unit = MF.CurrUnit
    if unit == "player" then return true, true end

    local value
    local spellID = resolveNativeRangeSpellID()
    if spellID and C_Spell and type(C_Spell.IsSpellInRange) == "function" then
        local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if ok then value = result end
        if issecretvalue and issecretvalue(value) then return value, true end
        if not canaccessvalue(value) then return nil, false end
        if value == true or value == false then return value, true end
        if value == 1 then return true, true end
        if value == 0 then return false, true end
    end

    if UnitInRange then
        local ok, result, checked = pcall(UnitInRange, unit)
        if not ok or not isAccessiblePublicValue(checked)
            or (checked ~= true and checked ~= 1) then
            return nil, false
        end
        if ok then value = result end
        if issecretvalue and issecretvalue(value) then return value, true end
        if not canaccessvalue(value) then return nil, false end
        if value == true or value == false then return value, true end
        if value == 1 then return true, true end
        if value == 0 then return false, true end
    end
    return nil, false
end

local function shouldTrackRange121()
    if not D.profile or D.profile.OutOfRange121Enabled == false then return false end
    if type(IsInInstance) ~= "function" then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance == true and (
        instanceType == "party" or instanceType == "raid"
        or instanceType == "pvp" or instanceType == "arena"
    )
end

function D:ShouldTrack121Range()
    return shouldTrackRange121()
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
    if not MF or not MF.Frame then return end
    if not D:Is121MUFStatusLightEnabled() then return end
    if MF.Decursive121StatusLight then return end
    if nativeConfigurationBlocked() then
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr121_StatusLight_" .. tostring(MF.FrameNum or MF.ID or 0), initializeMUFStatusLight, MF)
        end
        return false
    end

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

    -- A separate, high-frame-level range layer guarantees that yellow visually
    -- wins over red/green verification carriers as well.
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

    -- Text label for Soul Link range: distance in yards isn't available
    -- through any public API (only an in-range/out-of-range boolean is, via
    -- C_Spell.IsSpellInRange -- same constraint documented throughout this
    -- session's other range checks), so this shows status text rather than
    -- a numeric yard readout.
    local soulLinkLabel = MF.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soulLinkLabel:SetPoint("BOTTOM", MF.Frame, "BOTTOM", 0, 2)
    soulLinkLabel:SetText("BATTLE REZ: OUT OF RANGE")
    soulLinkLabel:SetTextColor(1, .15, .15)
    if soulLinkLabel.SetIgnoreParentAlpha then soulLinkLabel:SetIgnoreParentAlpha(true) end
    if light.GetFrameLevel then
        local labelParent = soulLinkLabel:GetParent()
        if labelParent and labelParent.SetFrameLevel then
            labelParent:SetFrameLevel(light:GetFrameLevel() + 60)
        end
    end
    soulLinkLabel:Hide()

    MF.Decursive121StatusLight = light
    MF.Decursive121StatusLightFill = fill
    MF.Decursive121StatusRangeLayer = rangeLayer
    MF.Decursive121StatusRangeFill = rangeFill
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusRangeUntil = 0
    MF.Decursive121StatusSuccessUntil = 0
    MF.Decursive121StatusFailureReason = nil
    MF.Decursive121VerificationGeneration = 0
    MF.Decursive121SoulLinkRangeActive = false
    MF.Decursive121SoulLinkLabel = soulLinkLabel
    statusLightMUFs[MF] = true
end

local function refreshOneMUFStatusLight(MF, now)
    if not MF then return end
    if not D:Is121MUFStatusLightEnabled() then
        local light = MF.Decursive121StatusLight
        if light then light:Hide() end
        if MF.Decursive121SoulLinkLabel then MF.Decursive121SoulLinkLabel:Hide() end
        return
    end
    initializeMUFStatusLight(MF)
    local light, fill = MF.Decursive121StatusLight, MF.Decursive121StatusLightFill
    local rangeLayer, rangeFill = MF.Decursive121StatusRangeLayer, MF.Decursive121StatusRangeFill
    if not light or not fill then return end

    if MF.Shown == false or not MF.Frame:IsShown() then
        light:Hide()
        if MF.Decursive121SoulLinkLabel then MF.Decursive121SoulLinkLabel:Hide() end
        return
    end

    now = now or (GetTime and GetTime() or 0)
    if MF.Decursive121SoulLinkLabel then MF.Decursive121SoulLinkLabel:Hide() end

    -- Determine the transient result color WITHOUT deciding range.
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

    -- Soul Link out-of-range: a dead ally you're relying on Soul Link (not a
    -- normal battle-rez) to revive, but you're outside its 5-yard cast range.
    -- Persistent (not a timed flash). Short-circuits entirely rather than
    -- flowing into the native range layers below: those compute
    -- range against the player's configured DISPEL spell, which is meaningless
    -- against a dead target and would otherwise silently override this.
    if shouldTrackRange121() and MF.Decursive121SoulLinkRangeActive then
        fill:SetVertexColor(unpack(STATUS_RANGE))
        if rangeFill then rangeFill:SetVertexColor(unpack(STATUS_CLEAR)) end
        if rangeLayer then rangeLayer:Show() end
        light:Show()
        if MF.Decursive121SoulLinkLabel then MF.Decursive121SoulLinkLabel:Show() end
        return
    end

    -- Native two-layer contract via C_Spell.IsSpellInRange()/UnitInRange.
    -- Secret booleans go straight into the texture API so yellow hard-wins
    -- over red/green.
    if shouldTrackRange121() and rangeFill and applyNativeRangeToStatusLayers(MF, fill, rangeFill, resultColor) then
        if rangeLayer then rangeLayer:Show() end
        light:Show()
        return
    end

    -- Compatibility fallback only when Blizzard did not produce a usable range
    -- signal.  This path contains no protected aura reads.
    if rangeFill then rangeFill:SetVertexColor(unpack(STATUS_CLEAR)) end
    if rangeLayer then rangeLayer:Show() end
    if shouldTrackRange121() and (MF.Decursive121OutOfRange == true or (MF.Decursive121StatusRangeUntil or 0) > now) then
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
    if D.Refresh121DispelAlertWarning then
        D:Refresh121DispelAlertWarning()
    end
end

function D:Mark121MUFStatusRange(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    if not shouldTrackRange121() then
        MF.Decursive121OutOfRange = false
        MF.Decursive121StatusRangeUntil = 0
        refreshOneMUFStatusLight(MF)
        return
    end
    MF.Decursive121OutOfRange = true
    MF.Decursive121StatusRangeUntil = (GetTime and GetTime() or 0) + 2.5
    refreshOneMUFStatusLight(MF)
end

local function parkVerificationHandles(MF)
    if not MF then return end
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
    parkVerificationHandles(MF)
    MF.Decursive121StatusFailureReason = isAccessiblePublicValue(reason) and reason ~= nil and tostring(reason) or nil
    MF.Decursive121StatusFailureUntil = (GetTime and GetTime() or 0) + 3.0
    refreshOneMUFStatusLight(MF)
end

function D:Set121MUFSoulLinkRangeActive(unitOrMF, active)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    initializeMUFStatusLight(MF)
    active = active and true or false
    if MF.Decursive121SoulLinkRangeActive == active then return end
    MF.Decursive121SoulLinkRangeActive = active
    refreshOneMUFStatusLight(MF)
end

function D:Clear121MUFStatusAttempt(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return end
    MF.Decursive121VerificationGeneration = (MF.Decursive121VerificationGeneration or 0) + 1
    parkVerificationHandles(MF)
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusRangeUntil = 0
    MF.Decursive121StatusSuccessUntil = 0
    MF.Decursive121StatusFailureReason = nil
    refreshOneMUFStatusLight(MF)
end

function D:Refresh121MUFStatusLights()
    refreshMUFStatusLights()
end

function D:Is121MUFStatusLightEnabled()
    return self.profile and self.profile.StatusLight121Enabled == true
end

-- Toggle the per-MUF status indicator and restore pre-status-light layout
-- spacing (party + raid vertical stride, screen clamping, etc.).
function D:Set121MUFStatusLightEnabled(enabled)
    if not self.profile then return end
    enabled = enabled and true or false
    self.profile.StatusLight121Enabled = enabled

    -- Status-light frames are children of secure MUFs. Settings can be changed
    -- through slash commands or the modern panel while combat is active, so
    -- keep the mutation boundary here even though most controls are disabled
    -- in combat. The latest requested value wins when the delayed call runs.
    if InCombatLockdown and InCombatLockdown() then
        self.Pending121MUFStatusLightEnabled = enabled
        if self.AddDelayedFunctionCall then
            self:AddDelayedFunctionCall("Dcr_Apply121MUFStatusLightEnabled", function()
                local pending = D.Pending121MUFStatusLightEnabled
                D.Pending121MUFStatusLightEnabled = nil
                if pending == nil then return true end
                return D:Set121MUFStatusLightEnabled(pending)
            end)
        end
        return false
    end
    self.Pending121MUFStatusLightEnabled = nil

    for MF in pairs(statusLightMUFs) do
        if MF.Decursive121StatusLight then
            if enabled then MF.Decursive121StatusLight:Show() else MF.Decursive121StatusLight:Hide() end
        end
        if MF.Decursive121SoulLinkLabel then MF.Decursive121SoulLinkLabel:Hide() end
    end

    if self.MicroUnitF and self.MicroUnitF.ResetAllPositions then
        self.MicroUnitF:ResetAllPositions()
    end
    refreshMUFStatusLights()
    return true
end

function D:Get121MUFStatus(unitOrMF)
    local MF = resolveStatusMUF(unitOrMF)
    if not MF then return "UNKNOWN" end
    local now = GetTime and GetTime() or 0
    -- This diagnostic helper can only report Decursive's non-secret range state.
    -- Live IsSpellInRange/UnitInRange may be secret and is intentionally never
    -- inspected in Lua; the actual status light still gives yellow top priority.
    if shouldTrackRange121() and (MF.Decursive121OutOfRange == true or (MF.Decursive121StatusRangeUntil or 0) > now) then
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

-- The original Decursive MUF is a 20x20 click frame with a 16x16 visual
-- square centered inside its two-pixel border (pets are 16x16 with a 12x12
-- visual square). Every addon-owned fill must use that inner rectangle. The
-- secure click target and outer class border remain untouched.
local MUF_INNER_INSET = 2
local function getMUFInnerBaseSize(MF)
    local outer = DC.MFSIZE or 20
    local unit = MF and MF.CurrUnit
    if type(unit) == "string" and unit:find("pet", 1, true) then
        outer = math.max(MUF_INNER_INSET * 2 + 1, outer - 4)
    end
    return math.max(1, outer - MUF_INNER_INSET * 2)
end

local function getMUFInnerAnchor(MF)
    return MF and (MF.Texture or MF.Frame) or nil
end

local function syncOwnedOverlayToMUFInner(MF, overlay)
    if not MF or not overlay or not D.MFContainer or not D.MicroUnitF then return end
    if nativeConfigurationBlocked() then return false end

    local slot = MF.ToPlace
    if type(slot) ~= "number" or slot < 1 then slot = MF.ID end
    if type(slot) ~= "number" or slot < 1 then slot = MF.FrameNum end
    if type(slot) ~= "number" or slot < 1 then return end
    local anchor = D.MicroUnitF.GetMUFAnchor and D.MicroUnitF:GetMUFAnchor(slot)
    if not anchor then return end

    overlay:ClearAllPoints()
    overlay:SetPoint(
        anchor[1],
        (anchor[2] or 0) + MUF_INNER_INSET,
        (anchor[3] or 0) + MUF_INNER_INSET,
        anchor[4]
    )
    local size = getMUFInnerBaseSize(MF)
    overlay:SetSize(size, size)
    return true
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
    if not overlay then return end
    -- MUF anchors cannot change during combat, so retain the last safe inner
    -- square geometry instead of issuing structural writes from the ticker.
    return syncOwnedOverlayToMUFInner(MF, overlay)
end

local function initializeRangeOverlay(MF)
    if not MF or not MF.Frame or MF.Decursive121RangeOverlay or not D.MFContainer then return end
    if nativeConfigurationBlocked() then
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr121_RangeOverlay_" .. tostring(MF.FrameNum or MF.ID or 0), initializeRangeOverlay, MF)
        end
        return false
    end
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    local size = getMUFInnerBaseSize(MF)
    overlay:SetSize(size, size)
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
    local enabled = shouldTrackRange121()
    for MF in pairs(rangeMUFs) do
        local overlay = MF.Decursive121RangeOverlay
        if overlay then
            syncRangeOverlayToMUF(MF)
            local outOfRange = false
            -- Range overlays are parented to the shared MUF container rather
            -- than the secure MUF itself.  Explicitly hide inactive slots so a
            -- stale CurrUnit cannot leave a yellow ghost after a roster/zone
            -- rebuild.
            local shown = MF.Shown == true
            local unit = shown and MF.CurrUnit or nil
            if shown and enabled and unit and unit ~= "player" then
                -- Prefer the actual friendly cure spells Decursive has configured.
                -- This is more useful than generic UnitInRange(), particularly in PvP,
                -- and does not inspect protected aura data. If every configured cure
                -- spell reports the unit out of range, show the range state.
                local relevantSpellCount = 0
                local knownSpellCount = 0
                local anyCureInRange = false
                local status = D.Status
                if D.IsSpellInRange and status and status.CuringSpells and status.CuringSpellsPrio then
                    local seen = {}
                    for debuffType, spellName in pairs(status.CuringSpells) do
                        local prio = spellName and status.CuringSpellsPrio[spellName]
                        local friendlyType = debuffType == DC.MAGIC
                            or debuffType == DC.CURSE
                            or debuffType == DC.DISEASE
                            or debuffType == DC.POISON
                            or debuffType == DC.BLEED
                        if friendlyType and spellName and prio and prio >= 1 and prio <= 3 and not seen[spellName] then
                            seen[spellName] = true
                            relevantSpellCount = relevantSpellCount + 1
                            -- D.IsSpellInRange is a plain function, not a colon
                            -- method: its signature is (spellName, unit).
                            local ok, value = pcall(D.IsSpellInRange, spellName, unit)
                            local rangeKnown = ok and isAccessiblePublicValue(value)
                                and (value == true or value == false or value == 1 or value == 0)
                            if rangeKnown then
                                knownSpellCount = knownSpellCount + 1
                                if value == 1 or value == true then
                                    anyCureInRange = true
                                    break
                                end
                            end
                        end
                    end
                end

                if anyCureInRange then
                    outOfRange = false
                elseif relevantSpellCount > 0 then
                    -- An unknown result from even one relevant cure keeps the
                    -- aggregate state unknown. Yellow requires every distinct
                    -- configured friendly cure to report explicit out of range.
                    outOfRange = knownSpellCount == relevantSpellCount
                elseif UnitInRange then
                    -- Generic fallback only when there is no relevant configured
                    -- friendly cure spell. It too must report an explicit check.
                    local ok, value, checked = pcall(UnitInRange, unit)
                    local rangeKnown = ok
                        and isAccessiblePublicValue(value)
                        and isAccessiblePublicValue(checked)
                        and (checked == true or checked == 1)
                        and (value == true or value == false or value == 1 or value == 0)
                    if rangeKnown and (value == false or value == 0) then outOfRange = true end
                end
            end
            MF.Decursive121OutOfRange = outOfRange and true or false
            if shown and outOfRange then overlay:Show() else overlay:Hide() end
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
    if not overlay then return end
    return syncOwnedOverlayToMUFInner(MF, overlay)
end

local function initializeLineOfSightOverlay(MF)
    if not MF or not MF.Frame or MF.Decursive121LineOfSightOverlay or not D.MFContainer then return end
    if nativeConfigurationBlocked() then
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr121_LineOfSightOverlay_" .. tostring(MF.FrameNum or MF.ID or 0), initializeLineOfSightOverlay, MF)
        end
        return false
    end
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    local size = getMUFInnerBaseSize(MF)
    overlay:SetSize(size, size)
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

-- Each priority gets a Blizzard-filtered AuraSlot whose membership is the
-- decision. A slot exists/shows only when the native AuraContainer matches one
-- of the configured dispel types for that priority.
local function initializeProviderPriorityButton(auraButton, priority, MF, anchor)
    if not auraButton or providerPriorityInitializedButtons[auraButton] then return end
    providerPriorityInitializedButtons[auraButton] = true

    -- DISPEL Alert labels are registered with Blizzard as native dispel-type
    -- and duration text inside initializeFrame (before access restrictions).
    -- Blizzard owns both protected visibility and the elapsed-time gate.
    if D.Register121DispelAlertAuraButton then
        D:Register121DispelAlertAuraButton(auraButton)
    end

    local innerSize = getMUFInnerBaseSize(MF)
    if auraButton.SetSize then auraButton:SetSize(innerSize, innerSize) end
    -- Positioning happens HERE, inside Blizzard's own initializeFrame callback
    -- (invoked via securecallfunction), not afterward in plain addon code.
    -- Calling ClearAllPoints/SetAllPoints on this SAME button from OUTSIDE this
    -- callback failed in PvP; AddAuraSlot allows addons to manually anchor
    -- AuraSlots (Patch 12.1.0).
    if anchor then
        if auraButton.ClearAllPoints then
            local ok = pcall(auraButton.ClearAllPoints, auraButton)
            if not ok and D.AlertDiag then D:AlertDiag("Priority button ClearAllPoints FAILED (init)") end
        end
        if auraButton.SetAllPoints then
            local ok = pcall(auraButton.SetAllPoints, auraButton, anchor)
            if not ok and D.AlertDiag then D:AlertDiag("Priority button SetAllPoints FAILED (init)") end
        end
    end
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

    -- Do not call IsShown on Blizzard-owned AuraSlot buttons; presence is
    -- unobservable to addon Lua by design. Trust the parent button's native
    -- Show/Hide to cascade to child fill textures.
    -- Lower-priority simultaneous needs remain visible as a border even when a
    -- higher-priority slot is covering the center.
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
        auraButton.Decursive121PriorityBorderHolder = holder
        auraButton.Decursive121PriorityBorder = edges
    end

    auraButton.Decursive121PriorityIndex = priority
    auraButton.Decursive121PriorityFill = fill
end

local function initializeNativeVerificationButton(auraButton, MF, anchor)
    if not auraButton or not MF then return end
    initializeMUFStatusLight(MF)
    local size = statusLightSizeForMF(MF)
    if auraButton.SetSize then auraButton:SetSize(size, size) end
    -- See initializeProviderPriorityButton's matching comment: positioning
    -- must happen inside this initializeFrame callback, not afterward.
    if anchor then
        if auraButton.ClearAllPoints then
            local ok = pcall(auraButton.ClearAllPoints, auraButton)
            if not ok and D.AlertDiag then D:AlertDiag("Verification button ClearAllPoints FAILED (init)") end
        end
        if auraButton.SetAllPoints then
            local ok = pcall(auraButton.SetAllPoints, auraButton, anchor)
            if not ok and D.AlertDiag then D:AlertDiag("Verification button SetAllPoints FAILED (init)") end
        end
    end
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
    if not MF or not MF.Frame or nativeConfigurationBlocked() then return end
    if not D:Is121MUFStatusLightEnabled() then return end
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
                    initializeFrame = function(btn) initializeNativeVerificationButton(btn, MF, holder) end,
                    candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(p) },
                }
                if container.AddAuraSlot then
                    safe("Native verification AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                end
                -- SetEnabled LAST: this arms Blizzard's aura parsing/event registration
                -- only after SetUnit, AddAuraSlot and the slot geometry are complete.
                if container.SetEnabled then safe("Native verification SetEnabled", container.SetEnabled, container, true) end
                if container.Show then safe("Native verification Show", container.Show, container) end
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

    -- Start every successful cast with a green base. Native verification can
    -- cover it in red if the matching affliction remains after the aura system
    -- has had a fraction of a second to settle.
    MF.Decursive121VerificationGeneration = (MF.Decursive121VerificationGeneration or 0) + 1
    local generation = MF.Decursive121VerificationGeneration
    MF.Decursive121StatusFailureUntil = 0
    MF.Decursive121StatusFailureReason = nil
    MF.Decursive121StatusSuccessUntil = 0
    parkVerificationHandles(MF)
    refreshOneMUFStatusLight(MF)

    attachNativeVerificationCarriers(MF, MF.CurrUnit)
    local priority = resolveCurePriorityFromSpellName(spellName)
    local function enableVerification()
        if not MF or MF.Decursive121VerificationGeneration ~= generation then return end
        -- Wait one short aura-update beat before showing success. This prevents
        -- a false green flash on a cast that succeeds but leaves the protected
        -- dispel need in place. The red native verifier is enabled in the same
        -- update and visually owns the light if the affliction remains.
        MF.Decursive121StatusSuccessUntil = (GetTime and GetTime() or 0) + 3.0
        refreshOneMUFStatusLight(MF)
        local holders = MF.Decursive121VerificationNativeHolders
        if not holders then return end
        for p = 1, 3 do
            local holder = holders[p]
            if holder then holder:SetAlpha(p == priority and 1 or 0) end
        end
        -- The managed containers receive UNIT_AURA and refresh themselves.
        -- Do not manually dirty a protected aura container from this combat
        -- timer; pcall cannot make a restricted call safe.
    end
    local function finishVerification()
        if not MF or MF.Decursive121VerificationGeneration ~= generation then return end
        parkVerificationHandles(MF)
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
    if not overlay then return end
    return syncOwnedOverlayToMUFInner(MF, overlay)
end

local function initializePriorityCooldownVisuals(MF)
    if not MF or not MF.Frame or MF.Decursive121CooldownOverlay then return end
    if not D.MFContainer then return end
    if nativeConfigurationBlocked() then
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr121_CooldownOverlay_" .. tostring(MF.FrameNum or MF.ID or 0), initializePriorityCooldownVisuals, MF)
        end
        return false
    end

    -- Keep all addon-controlled cooldown widgets OUTSIDE Blizzard's managed
    -- AuraButton.  Parenting them to that button causes them to become
    -- forbidden when the protected aura state changes in combat.
    local overlay = CreateFrame("Frame", nil, D.MFContainer)
    local innerSize = getMUFInnerBaseSize(MF)
    overlay:SetSize(innerSize, innerSize)
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
            -- These anchors are structural and only change when the option is
            -- edited. Preserve the last safe geometry while combat is active.
            if not nativeConfigurationBlocked() then
                local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
                top:ClearAllPoints(); top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0); top:SetHeight(thickness)
                bottom:ClearAllPoints(); bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(thickness)
                left:ClearAllPoints(); left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0); left:SetWidth(thickness)
                right:ClearAllPoints(); right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0); right:SetWidth(thickness)
            end
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
    if not isAccessiblePublicValue(spellID) or type(spellID) ~= "number"
        or not D.Status or not D.Status.CuringSpells or not D.Status.FoundSpells
    then
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

local dispelResolverRefreshPending = false

local function resetTrackedDispelSpell()
    -- Rebuilding the shared ColorCurve and managed AuraSlot filters is
    -- configuration work, not cast-result work. Keep it outside combat and
    -- coalesce any spec/settings request until PLAYER_REGEN_ENABLED.
    if nativeConfigurationBlocked() then
        dispelResolverRefreshPending = true
        return false
    end
    dispelResolverRefreshPending = false
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
    if not nativeConfigurationBlocked() and D.MicroUnitF and D.MicroUnitF.ExistingPerUNIT then
        for _, MF in pairs(D.MicroUnitF.ExistingPerUNIT) do
            -- Ensure all provider-specific parity carriers that are now relevant
            -- after a spec/talent/custom-spell change exist before combat.
            for priority = 1, 3 do
                if attachPriorityCooldownGate then attachPriorityCooldownGate(MF, MF.CurrUnit, priority) end
            end
            attachNativeVerificationCarriers(MF, MF.CurrUnit)

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
                            initializeFrame = function(btn) initializeProviderPriorityButton(btn, p, MF, getMUFInnerAnchor(MF)) end,
                            candidateFilters = { includeDispelTypes = include },
                        }
                        local ok, slotButton = safe("Native add detection priority after reconfigure", detector.AddAuraSlot, detector, key,
                            "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                        if ok then
                            keys[p] = key
                        end
                    end
                end
            end
        end
    end
    return true
end

local function refreshManagedAfflictedCooldownVisuals()
    -- Shared cooldown rendering is handled by native priority carriers.
    -- Their aura membership remains Blizzard-managed.
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
    if not isAccessiblePublicValue(spellID) or type(spellID) ~= "number"
        or not C_Spell or not C_Spell.GetSpellCooldownDuration
    then
        return false
    end

    local durationOK, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
    if not durationOK or not durationObject then return false end

    if durationObject.GetRemainingDuration then
        local ok, remaining = pcall(durationObject.GetRemainingDuration, durationObject)
        if ok and isAccessiblePublicValue(remaining) and type(remaining) == "number" and remaining <= 0.05 then
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
    -- native priority-filtered AuraContainer dispel carrier.
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
    if not ok or not isAccessiblePublicValue(remaining) or remaining == nil then return nil end
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
        local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
        local charges
        if ok and isAccessiblePublicValue(chargeInfo) and type(chargeInfo) == "table" then
            charges = chargeInfo.currentCharges
        end
        if isAccessiblePublicValue(charges) and type(charges) == "number" then
            if charges > 0 then
                finishPriorityCooldown(priority, cooldownGeneration[priority])
                return
            end
        end
    end

    if not C_Spell or not C_Spell.GetSpellCooldownDuration then return end
    local durationOK, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
    if not durationOK or not durationObject then
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

-- Confirmed live via BugGrabber: this MUST be declared before cooldownEvents
-- below, which references it starting at its very first event branch.
-- Originally declared much further down the file (near attachClickTracking)
-- -- a Lua local only exists for code AFTER its declaration in the same
-- chunk, so every earlier use here was silently resolving to a nonexistent
-- GLOBAL instead, throwing "attempt to perform arithmetic on ... a nil
-- value" on literally every click outcome (success, failure, and range
-- alike) this entire session, aborting Decursive's own post-cast
-- confirmation/cooldown-arming logic right after the real spell cast fired.
local clickDiagGeneration = 0

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
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "UNIT_SPELLCAST_FAILED_QUIET")
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
            if not isAccessiblePublicValue(msg) or not isAccessiblePublicValue(unit) then return end
            local isRangeError = (SPELL_FAILED_OUT_OF_RANGE and msg == SPELL_FAILED_OUT_OF_RANGE)
                or (ERR_OUT_OF_RANGE and msg == ERR_OUT_OF_RANGE)
            if isRangeError then
                -- User rule: yellow owns out-of-range.  Do not retain a hidden
                -- red failure that could surface if the player steps back into
                -- range before the three-second result window ends.
                lastClickedMUF.Decursive121SuppressFailureUntil = GetTime() + 1.0
                D:Clear121MUFStatusAttempt(lastClickedMUF)
                D:Mark121MUFStatusRange(lastClickedMUF)
                clickDiagGeneration = clickDiagGeneration + 1
                -- Logs the raw errorType/message verbatim too -- classified
                -- as "range" here, but a report that the player was
                -- actually in range means this classification itself may
                -- be catching something else (e.g. line of sight) that
                -- isn't really a range problem. Ground truth beats the
                -- classification next time this fires.
                if D.AlertDiag then
                    D:AlertDiag("CLICK outcome: OUT OF RANGE (raw errorType=%s msg=%s)",
                        tostring(unit), tostring(msg))
                end
            elseif (lastClickedMUF.Decursive121SuppressFailureUntil or 0) > GetTime() then
                -- A cure just succeeded on this MUF (see the post-cure debounce
                -- set below). A spam-click re-cast against an already-cleared
                -- target commonly errors instantly (e.g. "Nothing to Dispel")
                -- here rather than through UNIT_SPELLCAST_FAILED; without this
                -- check that error would paint red over the still-visible green
                -- success result from the click that actually worked.
                clickDiagGeneration = clickDiagGeneration + 1
                if D.AlertDiag then D:AlertDiag("CLICK outcome: suppressed (recent success debounce), msg=%s", tostring(msg)) end
            else
                D:Mark121MUFStatusFailure(lastClickedMUF, msg or unit or event)
                clickDiagGeneration = clickDiagGeneration + 1
                if D.AlertDiag then D:AlertDiag("CLICK outcome: FAILED (UI_ERROR_MESSAGE), msg=%s", tostring(msg)) end
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED_QUIET" then
        -- Diagnostic only -- deliberately does NOT touch the status light.
        -- WoW fires this (not the loud UNIT_SPELLCAST_FAILED) for routine,
        -- expected failures like a GCD-blocked cast, so it's silent by
        -- design and was previously invisible to this whole tracker. Logged
        -- here specifically to tell "silently blocked by GCD" apart from
        -- "genuinely nothing happened" when chasing the multi-click report.
        if isAccessiblePublicValue(unit) and unit == "player" and isFriendlyConfiguredDispelSpellID(spellID)
            and lastClickedMUF and (GetTime() - (lastClickedAt or 0)) <= 2.0 then
            clickDiagGeneration = clickDiagGeneration + 1
            if D.AlertDiag then D:AlertDiag("CLICK outcome: FAILED_QUIET (likely GCD or similar routine block)") end
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not isAccessiblePublicValue(unit) or unit ~= "player" then return end
        if not isFriendlyConfiguredDispelSpellID(spellID) then return end
        if lastClickedMUF and (lastClickedMUF.Decursive121SuppressFailureUntil or 0) > GetTime() then
            return
        end
        if lastClickedMUF and (GetTime() - (lastClickedAt or 0)) <= 2.0 then
            -- Modern 12.1 failure path.  The legacy CLEU ClickedMF path is not
            -- available in Midnight, so result feedback must follow the secure
            -- click tracker + UNIT_SPELLCAST events instead.  The yellow range
            -- layer masks this red flash whenever the unit is currently out of
            -- range.
            D:Mark121MUFStatusFailure(lastClickedMUF, event)
            clickDiagGeneration = clickDiagGeneration + 1
            if D.AlertDiag then D:AlertDiag("CLICK outcome: FAILED (%s)", event) end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not isAccessiblePublicValue(unit) or unit ~= "player" then return end
        if isFriendlyConfiguredDispelSpellID(spellID) then
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

            clickDiagGeneration = clickDiagGeneration + 1
            if D.AlertDiag then D:AlertDiag("CLICK outcome: SUCCESS (priority=%s)", tostring(priority)) end

            -- Modern 12.1 success/result path.  A successful spellcast is only
            -- the start of verification: the native protected verifier paints
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
cooldownEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "ADDON_RESTRICTION_STATE_CHANGED")
-- Role assignment commonly lands just after a player spec swap. Use it as
-- a second nudge for the bounded follower-roster stabilization window.
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PLAYER_ROLES_ASSIGNED")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "PLAYER_TALENT_UPDATE")
pcall(cooldownEvents.RegisterEvent, cooldownEvents, "TRAIT_CONFIG_UPDATED")

local originalCooldownEventScript = cooldownEvents:GetScript("OnEvent")
cooldownEvents:SetScript("OnEvent", function(frame, event, ...)
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- The activating event is delivered before enforcement begins and a
        -- synchronous state query can still say Inactive. Reconcile after the
        -- transition completes; the lifecycle guard then sees the final state.
        local function reconcileAfterRestrictionTransition()
            if dispelResolverRefreshPending then resetTrackedDispelSpell() end
            refreshCooldownOverlay()
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, reconcileAfterRestrictionTransition)
        else
            dispelResolverRefreshPending = true
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if dispelResolverRefreshPending then resetTrackedDispelSpell() end
        return originalCooldownEventScript(frame, event, ...)
    end
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
        -- CuringSpells and UnitFilteringTypes are authoritative only after the
        -- original reconfiguration returns. Reconcile exact-ID sounds here so
        -- talent/spec/cure-option changes cannot leave stale registrations.
        if type(self.RefreshProtectedAuraSounds) == "function" then
            self:RefreshProtectedAuraSounds("cure capabilities reconfigured")
        end
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
    local className = "Unknown"
    if UnitClass then
        local ok, _, value = pcall(UnitClass, "player")
        if ok and isAccessiblePublicValue(value) and type(value) == "string" then className = value end
    end

    local specName = "Unknown"
    if GetSpecialization and GetSpecializationInfo then
        local spec = GetSpecialization()
        if isAccessiblePublicValue(spec) and type(spec) == "number" then
            local ok, _, n = pcall(GetSpecializationInfo, spec)
            if ok and isAccessiblePublicValue(n) and type(n) == "string" then specName = n end
        end
    end

    local spellID, spellName = resolveConfiguredDispelSpellID()
    local spellText = spellID and ((spellName or "Unknown") .. " (" .. tostring(spellID) .. ")") or "None detected"
    local p1ID, p1Name = resolveConfiguredDispelSpellIDByPriority(1)
    local p2ID, p2Name = resolveConfiguredDispelSpellIDByPriority(2)
    local p1Text = p1ID and ((p1Name or "Unknown") .. " (" .. tostring(p1ID) .. ")") or "None detected"
    local p2Text = p2ID and ((p2Name or "Unknown") .. " (" .. tostring(p2ID) .. ")") or "None detected"

    local managed, nativeVerificationCarriers, overlays, shown = 0, 0, 0, 0
    for _, MF in pairs(D.MicroUnitF.ExistingPerUNIT or {}) do
        if MF.ManagedAuraContainer then managed = managed + 1 end
        if MF.Decursive121VerificationNativeContainers then
            for priority = 1, 3 do
                if MF.Decursive121VerificationNativeContainers[priority] then nativeVerificationCarriers = nativeVerificationCarriers + 1 end
            end
        end
        if MF.Shown then shown = shown + 1 end
    end
    for MF in pairs(cooldownMUFs) do
        if MF.Decursive121Priority1Cooldown then overlays = overlays + 1 end
    end

    local providerStatus = D:Get121DispelDetectionProviderStatus()
    local providerText = providerStatus and providerStatus.displayName or "Native Blizzard-managed"

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
        "Detection provider: |cFF55DDDD" .. tostring(providerText) .. "|r",
        "Shared same-priority cooldown: |cFFFFFFFF" .. (((getActiveEnvironmentProfile() or {}).SharedPriorityCooldown121Enabled == true) and "Yes" or "No") .. "|r",
        "Clear cleansed target visual: |cFFFFFFFF" .. (((getActiveEnvironmentProfile() or {}).ClearCleansedTarget121Enabled ~= false) and "Yes" or "No") .. "|r",
        "Interface: |cFFFFFFFF" .. tostring(interfaceVersion or "Unknown") .. "|r",
        "Class / Spec: |cFFFFFFFF" .. className .. " / " .. specName .. "|r",
        "Detected friendly dispel: |cFF55FF55" .. spellText .. "|r",
        "Priority #1 inner/timer: |cFF55FF55" .. p1Text .. "|r",
        "Priority #2 border: |cFF55FF55" .. p2Text .. "|r",
        "Managed aura filter: |cFF55FF55HARMFUL|RAID_PLAYER_DISPELLABLE|r",
        "Native Decursive carriers: |cFFFFFFFF" .. tostring(managed) .. "|r",
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
        local name = D.UnitName and D:UnitName(unit) or nil
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
    local container = nativeContainers and nativeContainers[priority]
    if not container then return end

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
        local holder = MF.Decursive121PriorityGateHolders and MF.Decursive121PriorityGateHolders[priority]
        if holder and holder.SetAlpha then
            holder:SetAlpha(shouldActivate and 1 or 0)
            applied = true
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
            else
                safe("Priority cooldown text disable", binding.SetEnabled, binding, false)
            end
        else
            safe("Priority cooldown text disable", binding.SetEnabled, binding, false)
        end
    end
end

refreshSharedPriorityCooldownGates = function(priority)
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
    if nativeConfigurationBlocked() then return false end
    MF.Decursive121PriorityGateContainers = MF.Decursive121PriorityGateContainers or {}
    MF.Decursive121PriorityGateHolders = MF.Decursive121PriorityGateHolders or {}
    MF.Decursive121PriorityGateFrames = MF.Decursive121PriorityGateFrames or {}
    MF.Decursive121PriorityCooldownBindings = MF.Decursive121PriorityCooldownBindings or {}
    MF.Decursive121PriorityGateAppliedActive = MF.Decursive121PriorityGateAppliedActive or {}

    local function initializeGateAuraButton(auraButton, anchor)
        -- Creation window only. Nothing on this protected aura button or its
        -- child regions is mutated directly after initialization.
        local innerSize = getMUFInnerBaseSize(MF)
        if auraButton.SetSize then auraButton:SetSize(innerSize, innerSize) end
        -- Positioning must happen inside initializeFrame rather than afterward.
        if anchor then
            if auraButton.ClearAllPoints then
                local ok = pcall(auraButton.ClearAllPoints, auraButton)
                if not ok and D.AlertDiag then D:AlertDiag("Gate button ClearAllPoints FAILED (init)") end
            end
            if auraButton.SetAllPoints then
                local ok = pcall(auraButton.SetAllPoints, auraButton, anchor)
                if not ok and D.AlertDiag then D:AlertDiag("Gate button SetAllPoints FAILED (init)") end
            end
        end
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
            if font then text:SetFont(font, math.max(8, math.floor(innerSize * .55)), flags or "OUTLINE") end

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

    if MF.Decursive121PriorityGateContainers[priority] then return end
    -- Blizzard owns the AuraSlot filter continuously; Decursive only changes
    -- the alpha of an addon-owned holder when the public cleanse spell
    -- enters/leaves cooldown.
    local holder = CreateFrame("Frame", nil, MF.Frame)
    holder:SetAllPoints(getMUFInnerAnchor(MF) or MF.Frame)
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
        initializeFrame = function(btn) initializeGateAuraButton(btn, holder) end,
        candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(priority) },
    }
    local gateFrame
    if container.AddAuraSlot then
        local success, returned = safe("Priority AuraContainer AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
        if success then
            gateFrame = returned
        end
    else
        D:errln("12.1 managed priority gate: AuraContainer has no AddAuraSlot method")
    end
    MF.Decursive121PriorityGateFrames[priority] = gateFrame
    if container.SetEnabled then safe("Priority AuraContainer SetEnabled", container.SetEnabled, container, true) end
end

refreshPriorityGateFilters = function(MF)
    if not MF or not MF.Decursive121PriorityGateContainers then return end
    for priority = 1, 3 do
        if not nativeConfigurationBlocked() then
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

local pendingNativeAttach = setmetatable({}, { __mode = "k" })
local attachManagedAura

-- Diagnostic-only click-outcome tracker: logs what actually happens after a
-- MUF click (success / range-blocked / other failure / no event at all,
-- e.g. a silently-ignored GCD-blocked click) so a real "click didn't work"
-- report can be root-caused from /dcralertdiag instead of guessed at.
-- clickDiagGeneration itself is declared once, near cooldownEvents above --
-- NOT re-declared here, since that would shadow it with a second, separate
-- counter unsynchronized with the one cooldownEvents reads/writes.

local function attachClickTracking(MF)
    if MF.Frame and MF.Frame.HookScript and not clickHookedFrames[MF.Frame] then
        clickHookedFrames[MF.Frame] = true
        MF.Frame:HookScript("PostClick", function(_, button)
            lastClickedMUF = MF
            lastClickedPriority = getClickedCurePriority(button)
            lastClickedAt = GetTime()

            if D.AlertDiag then
                clickDiagGeneration = clickDiagGeneration + 1
                local myGen = clickDiagGeneration
                D:AlertDiag("CLICK priority=%s button=%s", tostring(lastClickedPriority), tostring(button))
                if C_Timer and C_Timer.After then
                    C_Timer.After(1.3, function()
                        if clickDiagGeneration == myGen then
                            D:AlertDiag("CLICK priority=%s -> no success/failure/range event observed within 1.3s (likely silently blocked, e.g. GCD)",
                                tostring(lastClickedPriority))
                        end
                    end)
                end
            end
        end)
    end
end

local function attachNativeManagedAura(MF, Unit)
    if not MF or not MF.Frame or not D.MFContainer then return end
    if nativeConfigurationBlocked() then
        pendingNativeAttach[MF] = Unit or MF.CurrUnit
        return
    end
    if MF.ManagedAuraContainer then
        local resolvedUnit = Unit or MF.CurrUnit
        if MF.ManagedAuraContainer.SetUnit and resolvedUnit then
            safe("Native detector SetUnit deferred update", MF.ManagedAuraContainer.SetUnit, MF.ManagedAuraContainer, resolvedUnit)
        end
        if MF.Decursive121PriorityGateContainers then
            for priority = 1, 3 do
                local gate = MF.Decursive121PriorityGateContainers[priority]
                if gate and gate.SetUnit and resolvedUnit then
                    safe("Priority AuraContainer deferred SetUnit", gate.SetUnit, gate, resolvedUnit)
                end
            end
        end
        if MF.Decursive121VerificationNativeContainers then
            for priority = 1, 3 do
                local verifier = MF.Decursive121VerificationNativeContainers[priority]
                if verifier and verifier.SetUnit and resolvedUnit then
                    safe("Native verification deferred SetUnit", verifier.SetUnit, verifier, resolvedUnit)
                end
            end
        end
        attachPriorityCooldownGate(MF, Unit, 1)
        attachPriorityCooldownGate(MF, Unit, 2)
        attachPriorityCooldownGate(MF, Unit, 3)
        attachNativeVerificationCarriers(MF, Unit or MF.CurrUnit)
        attachCooldownOverlay(MF)
        attachClickTracking(MF)
        pendingNativeAttach[MF] = nil
        return
    end

    -- Ask Blizzard's managed AuraContainer for three priority-filtered protected
    -- dispel decisions. Decursive never reads aura identity/presence back into
    -- Lua; the AuraSlot itself is the decision.
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
                    initializeFrame = function(btn) initializeProviderPriorityButton(btn, p, MF, getMUFInnerAnchor(MF)) end,
                    candidateFilters = { includeDispelTypes = include },
                }
                local slotOK = safe("Native detector AddAuraSlot", container.AddAuraSlot, container, key, "HARMFUL|RAID_PLAYER_DISPELLABLE", options)
                if slotOK then
                    MF.Decursive121NativeDetectionKeys[p] = key
                end
            end
        end
    else
        D:errln("12.1 native managed aura: AuraContainer has no AddAuraSlot method")
    end
    -- SetEnabled LAST, after the unit, slot declarations and slot anchors exist.
    if container.SetEnabled then safe("Native detector SetEnabled", container.SetEnabled, container, true) end
    if container.Show then safe("Native detector Show", container.Show, container) end

    attachPriorityCooldownGate(MF, Unit, 1)
    attachPriorityCooldownGate(MF, Unit, 2)
    attachPriorityCooldownGate(MF, Unit, 3)
    attachNativeVerificationCarriers(MF, Unit)
    attachCooldownOverlay(MF)
    attachClickTracking(MF)
    pendingNativeAttach[MF] = nil
end

attachManagedAura = function(MF, Unit)
    attachNativeManagedAura(MF, Unit)
end

local providerRetryFrame = CreateFrame("Frame")
providerRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(providerRetryFrame.RegisterEvent, providerRetryFrame, "ADDON_RESTRICTION_STATE_CHANGED")
providerRetryFrame:SetScript("OnEvent", function(_, event)
    local function retryPendingNativeAttach()
        for MF, unit in pairs(pendingNativeAttach) do
            if MF and MF.Frame then attachNativeManagedAura(MF, MF.CurrUnit or unit) end
        end
    end
    if event == "ADDON_RESTRICTION_STATE_CHANGED" and C_Timer and C_Timer.After then
        C_Timer.After(0, retryPendingNativeAttach)
    else
        retryPendingNativeAttach()
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
    local resolvedUnit = self.CurrUnit or Unit
    if not nativeConfigurationBlocked() then
        D:Refresh121MUFStateSoundUnit(resolvedUnit, true)
        if self.ManagedAuraContainer and self.ManagedAuraContainer.SetUnit then
            safe("AuraContainer SetUnit update", self.ManagedAuraContainer.SetUnit, self.ManagedAuraContainer, resolvedUnit)
            if self.Decursive121PriorityGateContainers then
                for priority = 1, 3 do
                    local gateContainer = self.Decursive121PriorityGateContainers[priority]
                    if gateContainer and gateContainer.SetUnit then
                        safe("Priority AuraContainer SetUnit update", gateContainer.SetUnit, gateContainer, resolvedUnit)
                    end
                end
            end
            if self.Decursive121VerificationNativeContainers then
                for priority = 1, 3 do
                    local verifyContainer = self.Decursive121VerificationNativeContainers[priority]
                    if verifyContainer and verifyContainer.SetUnit then
                        safe("Native verification AuraContainer SetUnit update", verifyContainer.SetUnit, verifyContainer, resolvedUnit)
                    end
                end
            end
            if D.Refresh121IdentityTooltipUnit then
                D:Refresh121IdentityTooltipUnit(self)
            end
        end
    elseif self and self.Frame then
        pendingNativeAttach[self] = resolvedUnit
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
-- Blizzard can briefly expose only player/pet before the final instance party
-- exists. Replaying only GroupChanged() preserves stale Shown
-- flags and UnitShown, so Decursive never fully reconstructs the grid.
--
-- This routine deliberately resets the *runtime state* of existing MUFs without
-- destroying secure frames. Once the roster is stable, the normal Decursive
-- display/update pipeline repopulates the grid and we retarget all managed 12.1
-- aura providers to the final unit tokens.
T._MUFStartupDiag = T._MUFStartupDiag or {}
local MUF_STARTUP_DIAG = T._MUFStartupDiag

local function recordMUFStartupState(reason, phase)
    local muf = D.MicroUnitF
    local status = D.Status
    local actualShown = 0
    local existingCount = 0
    if muf and type(muf.ExistingPerUNIT) == "table" then
        for _, MF in pairs(muf.ExistingPerUNIT) do
            existingCount = existingCount + 1
            if MF and MF.Frame and MF.Frame.IsShown then
                local ok, shown = pcall(MF.Frame.IsShown, MF.Frame)
                if ok and isAccessiblePublicValue(shown) and shown == true then
                    actualShown = actualShown + 1
                end
            end
        end
    end

    local containerShown = false
    if D.MFContainer and D.MFContainer.IsShown then
        local ok, shown = pcall(D.MFContainer.IsShown, D.MFContainer)
        containerShown = ok and isAccessiblePublicValue(shown) and shown == true
    end

    MUF_STARTUP_DIAG.reason = type(reason) == "string" and reason or "unknown"
    MUF_STARTUP_DIAG.phase = phase or "unknown"
    MUF_STARTUP_DIAG.time = GetTime and GetTime() or 0
    MUF_STARTUP_DIAG.initialized = D.DcrFullyInitialized == true
    MUF_STARTUP_DIAG.combat = nativeConfigurationBlocked()
    MUF_STARTUP_DIAG.showSetting = D.profile and D.profile.ShowDebuffsFrame == true or false
    MUF_STARTUP_DIAG.autoHideMode = D.profile and tonumber(D.profile.AutoHideMUFs) or 0
    MUF_STARTUP_DIAG.containerShown = containerShown
    MUF_STARTUP_DIAG.groupInvalid = D.Groups_datas_are_invalid == true
    MUF_STARTUP_DIAG.unitNum = status and tonumber(status.UnitNum) or 0
    MUF_STARTUP_DIAG.unitShown = muf and tonumber(muf.UnitShown) or 0
    MUF_STARTUP_DIAG.actualShown = actualShown
    MUF_STARTUP_DIAG.created = muf and tonumber(muf.Number) or 0
    MUF_STARTUP_DIAG.existing = existingCount
end

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

local function rebuildMUFsAfterZone(reason, updatePasses)
    recordMUFStartupState(reason, "attempt")
    if not D.DcrFullyInitialized then
        recordMUFStartupState(reason, "blocked: initialization incomplete")
        return false
    end
    if nativeConfigurationBlocked() then
        recordMUFStartupState(reason, "blocked: combat lockdown")
        if D.AddDelayedFunctionCall then
            D:AddDelayedFunctionCall("Dcr_PostZoneFullReinit", rebuildMUFsAfterZone, reason, updatePasses)
        end
        return false
    end

    D.Groups_datas_are_invalid = true
    if D.GetUnitArray then D:GetUnitArray() end

    -- ReinitializeDecursiveAfterZone replaces GroupChanged() for full world
    -- transitions, so it must also own GroupChanged's context-size and
    -- auto-hide reconciliation.
    -- At cold login Blizzard can briefly report a solo roster even when the
    -- character is grouped; an early pass may therefore auto-hide the MUFs.
    -- Rechecking on every bounded settling pass restores them as soon as the
    -- real party snapshot is public instead of leaving ShowDebuffsFrame false
    -- until /reload.
    if D.MicroUnitF and D.MicroUnitF.ApplyContextMUFScale then
        D.MicroUnitF:ApplyContextMUFScale()
    end
    if D.AutoHideShowMUFs then D:AutoHideShowMUFs() end

    -- Let the normal updater create any MUFs that did not exist before this zone.
    -- Running several passes here avoids waiting for the periodic updater to
    -- eventually create party3/party4 after a transient player-only snapshot.
    if D.DebuffsFrame_Update then
        local passes = tonumber(updatePasses) or 12
        if passes < 1 then passes = 1 elseif passes > 12 then passes = 12 end
        for _ = 1, passes do D:DebuffsFrame_Update() end
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
                if MF.ManagedAuraContainer then
                    if MF.ManagedAuraContainer.SetUnit then
                        safe("Post-zone native SetUnit", MF.ManagedAuraContainer.SetUnit, MF.ManagedAuraContainer, resolvedUnit)
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
    recordMUFStartupState(reason, "complete")
    return true
end

function D:ReinitializeDecursiveAfterZone(reason)
    ZONE_REINIT_GENERATION = ZONE_REINIT_GENERATION + 1
    local generation = ZONE_REINIT_GENERATION

    MUF_STARTUP_DIAG.generation = generation
    MUF_STARTUP_DIAG.scheduledReason = type(reason) == "string" and reason or "zone"
    MUF_STARTUP_DIAG.scheduledAt = GetTime and GetTime() or 0
    MUF_STARTUP_DIAG.pass = 0
    recordMUFStartupState(reason, "scheduled")

    if not nativeConfigurationBlocked() then resetMUFsForZoneReinit() end
    self.Groups_datas_are_invalid = true

    local function pass(delay, passIndex)
        if generation ~= ZONE_REINIT_GENERATION or not D.DcrFullyInitialized then return end
        MUF_STARTUP_DIAG.pass = passIndex or 0
        MUF_STARTUP_DIAG.passDelay = delay
        D.Groups_datas_are_invalid = true
        rebuildMUFsAfterZone((reason or "zone") .. " @" .. tostring(delay))
    end

    if C_Timer and C_Timer.After then
        for i = 1, #ZONE_REINIT_DELAYS do
            local delay = ZONE_REINIT_DELAYS[i]
            local passIndex = i
            C_Timer.After(delay, function() pass(delay, passIndex) end)
        end
    else
        pass(0, 1)
    end
    return true
end

-- Short roster-only recovery. This preserves visible MUFs while the group list
-- settles and performs six updater passes total instead of the full zone path's
-- 72. It still repairs follower-dungeon roster changes that do not fire
-- PLAYER_ENTERING_WORLD.
local ROSTER_REFRESH_GENERATION = 0
local ROSTER_REFRESH_DELAYS = { 0.20, 1.00 }

function D:RefreshDecursiveAfterRoster(reason)
    ROSTER_REFRESH_GENERATION = ROSTER_REFRESH_GENERATION + 1
    local generation = ROSTER_REFRESH_GENERATION
    self.Groups_datas_are_invalid = true

    local function pass(delay)
        if generation ~= ROSTER_REFRESH_GENERATION or not D.DcrFullyInitialized then return end
        D.Groups_datas_are_invalid = true
        rebuildMUFsAfterZone((reason or "roster") .. " @" .. tostring(delay), 3)
    end

    if C_Timer and C_Timer.After then
        for i = 1, #ROSTER_REFRESH_DELAYS do
            local delay = ROSTER_REFRESH_DELAYS[i]
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

-----------------------------------------------------------------
-- Movable on-screen Alert warning anchor + banners
--
-- Two Decursive-owned banners share one draggable anchor:
--   1) Timed Alert warning — Soul Link battle-rez range text
--   2) DISPEL Alert warning — each priority AuraSlot owns Blizzard-managed
--      FontStrings. UNTIL_CLEARED uses SetDispelTypeText; TIMED uses
--      SetDurationText with an ElapsedDuration color curve. Blizzard therefore
--      owns the protected aura transition and the fixed display timeout. Addon
--      Lua never reads aura data, IsShown(), or protected frame state.
-----------------------------------------------------------------

local alert121Anchor
local alert121MoveMode = false
local alert121Banner -- Soul Link / generic timed messages
local dispelAlertWatchButtons = setmetatable({}, { __mode = "k" })
local dispelAlertLayers = setmetatable({}, { __mode = "k" }) -- auraButton -> native text entry
local dispelAlertPreviewUntil = 0
local dispelAlertNativeCurve
local dispelAlertNativeCurveReady = false
local dispelAlertNativeCurveSignature
local dispelAlertStylePending = false
local DEFAULT_ALERT_FONT_SIZE = 48
local DEFAULT_ALERT_COLOR = { 1, 0.15, 0.15 }
T._Alert121FontObjectUsers = T._Alert121FontObjectUsers or setmetatable({}, { __mode = "k" })

function D:Get121AlertAnchor()
    if alert121Anchor then return alert121Anchor end

    local f = CreateFrame("Frame", "Decursive121AlertAnchor", UIParent)
    f:SetSize(340, 80)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")

    local saved = D.profile and D.profile.Alert121Point
    if saved and saved.point then
        f:SetPoint(saved.point, UIParent, saved.point, saved.x or 0, saved.y or 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8X8]],
            edgeFile = [[Interface\Buttons\WHITE8X8]],
            edgeSize = 2,
        })
        f:SetBackdropColor(.29, .18, .55, .55)
        f:SetBackdropBorderColor(.6, .4, 1, .9)
    end
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText("|cFFFFD200Decursive ALERT WARNING|r\n(DISPEL + Soul Link — NOT notifications)\ndrag to move, /dcralerts move to lock")
    label:SetJustifyH("CENTER")
    f.Label = label

    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        D:Save121AlertPosition()
    end)
    f:Hide()

    alert121Anchor = f
    return f
end

-- One shared Font object keeps preview and protected native labels on the same
-- configured size. Once a FontString is registered with CustomAuraButton it can
-- become inaccessible to addon Lua while aura data is secret, but changing the
-- unprotected Font object still updates every registered user.
function D:Refresh121AlertFontObject()
    local size = (D.profile and D.profile.Alert121FontSize) or DEFAULT_ALERT_FONT_SIZE
    local fontPath = select(1, GameFontNormalHuge:GetFont())
    if not T._Alert121FontObject and CreateFont then
        T._Alert121FontObject = CreateFont("Decursive121AlertWarningFont")
    end
    if T._Alert121FontObject then
        local ok, applied = pcall(T._Alert121FontObject.SetFont, T._Alert121FontObject, fontPath, size, "THICKOUTLINE")
        if ok and applied ~= false then return T._Alert121FontObject end
    end
    return nil, fontPath, size
end

local function styleAlertFontString(text, applyColor)
    if not text then return end
    local fontObject, fontPath, size = D:Refresh121AlertFontObject()
    if fontObject and text.SetFontObject then
        if not T._Alert121FontObjectUsers[text] then
            local ok = pcall(text.SetFontObject, text, fontObject)
            if ok then T._Alert121FontObjectUsers[text] = true end
            if not ok then text:SetFont(select(1, GameFontNormalHuge:GetFont()),
                (D.profile and D.profile.Alert121FontSize) or DEFAULT_ALERT_FONT_SIZE, "THICKOUTLINE") end
        end
    else
        text:SetFont(fontPath, size, "THICKOUTLINE")
    end
    if applyColor ~= false then
        local color = (D.profile and D.profile.Alert121Color) or DEFAULT_ALERT_COLOR
        text:SetTextColor(color[1], color[2], color[3])
    end
end

-- AuraButton children may remain forbidden while aura secrecy is active even
-- outside ordinary combat lockdown (for example during an active challenge or
-- encounter). Query Blizzard's access boundary before touching a registered
-- native label; pcall alone cannot prevent ADDON_ACTION_BLOCKED.
local function canAccessNativeAuraDisplayObject(object)
    if not object then return false end
    if object.CanBeAccessedInContext then
        local ok, accessible = pcall(object.CanBeAccessedInContext, object)
        return ok and isAccessiblePublicValue(accessible) and accessible == true
    end
    return not nativeAuraDisplayMutationBlocked()
end

-- A native label is a descendant of a small/scaled MUF AuraSlot but is anchored
-- to the screen-wide alert anchor. Ignore the MUF scale, then compensate with
-- UIParent's effective scale so a configured 58px label has the same apparent
-- size as the 58px options preview.
function D:Normalize121NativeAlertFontScale(text)
    if not text then return end
    if text.SetIgnoreParentScale then text:SetIgnoreParentScale(true) end
    if text.SetScale and UIParent and UIParent.GetEffectiveScale then
        local uiScale = UIParent:GetEffectiveScale()
        if type(uiScale) == "number" and uiScale > 0 then text:SetScale(uiScale) end
    end
end

function D:Apply121AlertWarningStyle()
    -- FontStrings registered with CustomAuraButton become protected display
    -- elements. Restyle them only out of combat; their timed color is owned by
    -- the native DurationTextBinding curve rather than SetTextColor().
    if nativeAuraDisplayMutationBlocked() then
        dispelAlertStylePending = true
        return false
    end
    self:Refresh121AlertFontObject()
    local size = (D.profile and D.profile.Alert121FontSize) or DEFAULT_ALERT_FONT_SIZE
    local bannerH = math.max(120, math.floor(size * 2.5 + 0.5))
    if alert121Banner then alert121Banner:SetHeight(bannerH) end
    if alert121Banner and alert121Banner.Text then styleAlertFontString(alert121Banner.Text) end
    local styleFailed = false
    for _, layer in pairs(dispelAlertLayers) do
        if layer and layer.Text then
            if canAccessNativeAuraDisplayObject(layer.Text) then
                local ok = pcall(styleAlertFontString, layer.Text)
                if not ok then styleFailed = true end
            else
                styleFailed = true
            end
        end
        if layer and layer.TimedText then
            if canAccessNativeAuraDisplayObject(layer.TimedText) then
                local ok = pcall(styleAlertFontString, layer.TimedText, false)
                if not ok then styleFailed = true end
            else
                styleFailed = true
            end
        end
    end
    if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
    if styleFailed then dispelAlertStylePending = true end
end

D.Apply121SoulLinkAlertStyle = D.Apply121AlertWarningStyle

local function ensureAlert121Banner()
    if alert121Banner then return alert121Banner end
    local f = CreateFrame("Frame", "Decursive121AlertWarning", UIParent)
    f:SetSize(800, 120)
    f:SetPoint("CENTER", D:Get121AlertAnchor(), "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    f.Text = text
    f:Hide()
    alert121Banner = f
    D:Apply121AlertWarningStyle()
    return f
end

local function getDispelAlertMode()
    local mode = D.profile and D.profile.Alert121DispelMode
    if mode == "UNTIL_CLEARED" then return "UNTIL_CLEARED" end
    return "TIMED"
end

local function getDispelAlertDuration()
    local d = tonumber(D.profile and D.profile.Alert121DispelDuration) or 2
    if d < 0.5 then d = 0.5 end
    if d > 30 then d = 30 end
    return d
end

local function isDispelAlertEnabled()
    if D.Are121TextAlertsEnabled and not D:Are121TextAlertsEnabled() then
        return false
    end
    return not (D.profile and D.profile.Alert121DispelEnabled == false)
end

-- A TIMED warning is one fixed pulse. Managed AuraSlots may briefly recycle
-- their child visibility while Blizzard refreshes the same affliction; those
-- internal refreshes must not extend the configured display duration.
local dispelTimedPulseIgnoreUntil = 0

local function normalizeSoundPath(path)
    if not isAccessiblePublicValue(path) then return "" end
    return tostring(path or ""):lower():gsub("/", "\\")
end

function D:Refresh121DispelAlertSoundCache()
    T._DispelAlertSoundFileIDs = T._DispelAlertSoundFileIDs or {}
    if not self.GetDispelNotificationSoundFile then return end
    local path = self:GetDispelNotificationSoundFile()
    if not path then return end
    T._DispelAlertSoundPathNorm = normalizeSoundPath(path)
    local base = T._DispelAlertSoundPathNorm:match("([^\\]+)$") or T._DispelAlertSoundPathNorm
    T._DispelAlertSoundBase = base:lower()
    if C_FileAssets and C_FileAssets.GetFileInfo then
        local ok, info = pcall(C_FileAssets.GetFileInfo, path)
        if ok and isAccessiblePublicValue(info) and type(info) == "table"
            and isAccessiblePublicValue(info.fileID) and type(info.fileID) == "number"
        then
            T._DispelAlertSoundFileIDs[info.fileID] = true
        end
    end
end

local function soundMatchesDispelAlert(sound)
    if not isAccessiblePublicValue(sound) or sound == nil then return false end
    if type(sound) == "number" then
        return T._DispelAlertSoundFileIDs and T._DispelAlertSoundFileIDs[sound] and true or false
    end
    if type(sound) ~= "string" then return false end
    local got = normalizeSoundPath(sound)
    if got == "" then return false end
    local expected = T._DispelAlertSoundPathNorm
    if not expected and D.GetDispelNotificationSoundFile then
        expected = normalizeSoundPath(D:GetDispelNotificationSoundFile())
    end
    if expected and expected ~= "" then
        local expectedFile = expected:match("([^\\]+)$") or expected
        local gotFile = got:match("([^\\]+)$") or got
        if got == expected or gotFile == expectedFile
            or got:find(expectedFile, 1, true) or expected:find(gotFile, 1, true)
        then
            return true
        end
    end
    local base = T._DispelAlertSoundBase
    if base and base ~= "" then
        local gotFile = (got:match("([^\\]+)$") or got):lower()
        if gotFile == base or got:find(base, 1, true) then return true end
    end
    return false
end

local function pulseTimedDispelAlert(reason)
    if not isDispelAlertEnabled() then return false end
    if getDispelAlertMode() ~= "TIMED" then return false end
    local now = GetTime and GetTime() or 0
    if now < dispelTimedPulseIgnoreUntil then return false end

    local dur = getDispelAlertDuration()
    -- Lock for the full visual duration. Another managed refresh or sound
    -- callback cannot increment the banner generation and postpone its hide.
    dispelTimedPulseIgnoreUntil = now + dur
    dispelAlertPreviewUntil = now + dur
    if D.Show121AlertWarning then D:Show121AlertWarning("DISPEL", dur) end
    local safeReason = isAccessiblePublicValue(reason) and reason ~= nil and tostring(reason) or "unknown"
    if D.AlertDiag then D:AlertDiag("DISPEL timed pulse (%s)", safeReason) end
    return true
end

local DISPEL_ALERT_TEXT_MAP = {
    Magic = "DISPEL",
    Curse = "DISPEL",
    Disease = "DISPEL",
    Poison = "DISPEL",
    Bleed = "DISPEL",
}

local function ensureDispelAlertNativeCurve()
    if dispelAlertNativeCurveReady then return dispelAlertNativeCurve ~= nil end
    dispelAlertNativeCurveReady = true
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve
        or not Enum or not Enum.LuaCurveType or not CreateColor
    then
        return false
    end
    dispelAlertNativeCurve = C_CurveUtil.CreateColorCurve()
    dispelAlertNativeCurve:SetType(Enum.LuaCurveType.Step)
    return true
end

-- The curve is evaluated inside Blizzard against the protected aura's native
-- DurationObject. ElapsedDuration is zero at application, stays opaque for the
-- configured window, then becomes transparent without exposing either the
-- application time or the current aura state to addon Lua.
local function rebuildDispelAlertNativeCurve()
    if not ensureDispelAlertNativeCurve() then return false end
    local curve = dispelAlertNativeCurve
    local color = (D.profile and D.profile.Alert121Color) or DEFAULT_ALERT_COLOR
    local enabledTimed = isDispelAlertEnabled() and getDispelAlertMode() == "TIMED"
    local visibleAlpha = enabledTimed and 1 or 0
    local signature = table.concat({
        enabledTimed and "1" or "0",
        tostring(getDispelAlertDuration()),
        tostring(color[1]), tostring(color[2]), tostring(color[3]),
    }, ":")
    if dispelAlertNativeCurveSignature == signature then return true end

    curve:ClearPoints()
    curve:AddPoint(0, CreateColor(color[1], color[2], color[3], visibleAlpha))
    if enabledTimed then
        curve:AddPoint(getDispelAlertDuration(), CreateColor(color[1], color[2], color[3], 0))
    else
        curve:AddPoint(30, CreateColor(color[1], color[2], color[3], 0))
    end
    dispelAlertNativeCurveSignature = signature
    return true
end

-- Created inside CustomAuraContainer's initializeFrame callback, before
-- Blizzard applies access restrictions. Both text paths are registered with
-- supported CustomAuraButton APIs; there are no scripts or AnimationGroups in
-- the protected AuraSlot subtree.
local function ensureDispelAlertLayer(auraButton)
    local layer = dispelAlertLayers[auraButton]
    if layer then return layer end

    if auraButton.SetClipsChildren then pcall(auraButton.SetClipsChildren, auraButton, false) end

    layer = { TimedConfigured = false }
    local anchor = D:Get121AlertAnchor()

    -- TIMED: literal text whose color alpha is driven by the aura's protected
    -- elapsed duration in Blizzard code. This is the path that fixes combat
    -- display and the exact 2/3-second timeout.
    if auraButton.SetDurationText and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
        and Enum and Enum.DurationTextBindingProperty and rebuildDispelAlertNativeCurve()
    then
        local timedText = auraButton:CreateFontString(nil, "OVERLAY")
        timedText:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        D:Normalize121NativeAlertFontScale(timedText)
        styleAlertFontString(timedText, false)

        local binding = C_DurationUtil.CreateDurationTextBinding()
        binding:SetToDefaults()
        binding:SetTextFormat("DISPEL", {})
        binding:SetTextColorCurve(dispelAlertNativeCurve, Enum.DurationTextBindingProperty.ElapsedDuration)
        binding:SetZeroDurationText("")
        binding:SetExpiredText("")
        binding:SetUpdateInterval(0.05)

        local ok = pcall(auraButton.SetDurationText, auraButton, timedText, { binding = binding })
        if ok then
            layer.TimedText = timedText
            layer.TimedConfigured = true
        elseif D.AlertDiag then
            D:AlertDiag("DISPEL native duration text registration FAILED")
        end
    end

    -- UNTIL_CLEARED, plus a compatibility fallback if DurationTextBinding is
    -- unavailable: Blizzard selects and shows this text from dispelName without
    -- exposing the protected value to Decursive.
    if auraButton.SetDispelTypeText then
        local text = auraButton:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        D:Normalize121NativeAlertFontScale(text)
        styleAlertFontString(text)
        local usePersistent = isDispelAlertEnabled()
            and (getDispelAlertMode() == "UNTIL_CLEARED" or not layer.TimedConfigured)
        text:SetAlpha(usePersistent and 1 or 0)
        layer.PersistentAlpha = usePersistent and 1 or 0

        local ok = pcall(auraButton.SetDispelTypeText, auraButton, text, {
            showWhenHarmful = true,
            showWhenHelpful = false,
            showWithoutDispelType = false,
            customDispelTextMap = DISPEL_ALERT_TEXT_MAP,
        })
        if ok then
            layer.Text = text
        elseif D.AlertDiag then
            D:AlertDiag("DISPEL native dispel text registration FAILED")
        end
    end

    dispelAlertLayers[auraButton] = layer
    if D.AlertDiag then
        D:AlertDiag("DISPEL native text registered (timed=%s)", tostring(layer.TimedConfigured))
    end
    return layer
end

function D:Register121DispelAlertAuraButton(auraButton)
    if not auraButton then return end
    dispelAlertWatchButtons[auraButton] = true
    ensureDispelAlertLayer(auraButton)
end

function D:Get121DispelAlertMode()
    return getDispelAlertMode()
end

function D:Get121DispelAlertDuration()
    return getDispelAlertDuration()
end

function D:Pulse121TimedDispelAlert(reason)
    return pulseTimedDispelAlert(reason)
end

function D:Refresh121DispelAlertWarning()
    if nativeAuraDisplayMutationBlocked() then
        dispelAlertStylePending = true
        return false
    end

    -- A challenge/encounter can keep AuraButton descendants forbidden even
    -- after ordinary combat lockdown ends. Do not mutate the shared curve or
    -- a registered FontString until every live native label reports that it is
    -- accessible in the current context.
    for btn in pairs(dispelAlertWatchButtons) do
        local layer = btn and dispelAlertLayers[btn]
        if layer and ((layer.Text and not canAccessNativeAuraDisplayObject(layer.Text))
            or (layer.TimedText and not canAccessNativeAuraDisplayObject(layer.TimedText)))
        then
            dispelAlertStylePending = true
            return false
        end
    end

    local enabled = isDispelAlertEnabled()
    local mode = getDispelAlertMode()
    rebuildDispelAlertNativeCurve()
    local refreshComplete = true

    for btn in pairs(dispelAlertWatchButtons) do
        local layer = btn and dispelAlertLayers[btn]
        if layer and layer.Text then
            local usePersistent = enabled and (mode == "UNTIL_CLEARED" or not layer.TimedConfigured)
            local alpha = usePersistent and 1 or 0
            if layer.PersistentAlpha ~= alpha then
                if canAccessNativeAuraDisplayObject(layer.Text) then
                    local ok = pcall(layer.Text.SetAlpha, layer.Text, alpha)
                    if ok then layer.PersistentAlpha = alpha end
                    if not ok then refreshComplete = false end
                else
                    refreshComplete = false
                end
            end
        end
    end
    dispelAlertStylePending = not refreshComplete
    return refreshComplete
end

local dispelAlertRefreshFrame = CreateFrame("Frame")
dispelAlertRefreshFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
dispelAlertRefreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(dispelAlertRefreshFrame.RegisterEvent, dispelAlertRefreshFrame, "ADDON_RESTRICTION_STATE_CHANGED")
dispelAlertRefreshFrame:SetScript("OnEvent", function(_, event)
    if not dispelAlertStylePending then return end
    local function refreshAfterRestrictionTransition()
        if D.Apply121AlertWarningStyle then
            D:Apply121AlertWarningStyle()
        elseif D.Refresh121DispelAlertWarning then
            D:Refresh121DispelAlertWarning()
        end
    end
    if event == "ADDON_RESTRICTION_STATE_CHANGED" and C_Timer and C_Timer.After then
        C_Timer.After(0, refreshAfterRestrictionTransition)
    else
        refreshAfterRestrictionTransition()
    end
end)

function D:Hide121AlertWarning()
    if not alert121Banner then return end
    alert121Banner.generation = (alert121Banner.generation or 0) + 1
    alert121Banner:Hide()
end

function D:Show121AlertWarning(message, durationSeconds, bypassEnvironmentProfile)
    if not isAccessiblePublicValue(message) or type(message) ~= "string" or message == "" then return false end
    if not bypassEnvironmentProfile and self.Are121TextAlertsEnabled
        and not self:Are121TextAlertsEnabled() then
        return false
    end
    local f = ensureAlert121Banner()
    f.Text:SetText(message)
    f:Show()
    f.generation = (f.generation or 0) + 1
    local generation = f.generation
    local duration = isAccessiblePublicValue(durationSeconds) and tonumber(durationSeconds) or 2.5
    if duration < 0.5 then duration = 0.5 end
    if C_Timer and C_Timer.After then
        C_Timer.After(duration, function()
            if f.generation == generation then f:Hide() end
        end)
    end
    return true
end

-- Settings-only preview.  This deliberately does not consult the live DISPEL
-- warning toggle or either alert debounce: a preview button must remain useful
-- while the feature is disabled, otherwise it looks broken precisely when a
-- user is deciding whether to enable it.  The preview still uses the selected
-- font, color and configured duration, and never mutates live AuraSlot state.
function D:Test121DispelAlertWarning()
    local duration = getDispelAlertDuration()
    ensureAlert121Banner()
    self:Apply121AlertWarningStyle()
    local shown = self:Show121AlertWarning("DISPEL", duration, true)
    if self.AlertDiag then
        self:AlertDiag("DISPEL alert warning preview (%.1fs)", duration)
    end
    return shown
end

-- Options test + explicit public-ID + Decursive-played sound assist.
function D:Show121DispelAlertWarning(reason, bypassIgnoreWindow)
    if not isDispelAlertEnabled() then return false end

    local now = GetTime and GetTime() or 0
    local ignoreSeconds = tonumber(self.profile and self.profile.SoundNotificationIgnoreSeconds) or 2.0
    if ignoreSeconds < 0 then ignoreSeconds = 0 end
    if ignoreSeconds > 10 then ignoreSeconds = 10 end

    local ignoreUntil = tonumber(T._DispelNotificationIgnoreUntil) or 0
    if not bypassIgnoreWindow and now < ignoreUntil then
        return false
    end
    if not bypassIgnoreWindow then
        T._DispelNotificationIgnoreUntil = now + ignoreSeconds
    end

    local alertReason = isAccessiblePublicValue(reason) and reason ~= nil
        and tostring(reason) or "Show121DispelAlertWarning"
    local function presentAlert()
        if not isDispelAlertEnabled() then return end
        if getDispelAlertMode() == "TIMED" then
            pulseTimedDispelAlert(alertReason)
        else
            -- Persistent text is already owned by SetDispelTypeText on each
            -- managed AuraSlot. Profile changes only select its out-of-combat
            -- alpha; Blizzard continues to own protected visibility.
            D:Refresh121DispelAlertWarning()
        end
        if D.AlertDiag then D:AlertDiag("DISPEL alert warning presented (%s)", alertReason) end
    end

    -- This is a public-event/audio fallback. The authoritative combat text is
    -- the native AuraSlot DurationTextBinding above. Defer the fallback one
    -- frame so combat-log and sound hooks unwind before touching UIParent.
    if C_Timer and C_Timer.After then C_Timer.After(0, presentAlert) else presentAlert() end
    if self.AlertDiag then self:AlertDiag("DISPEL alert warning queued (%s)", alertReason) end
    return true
end

-- Build the ordinary fallback/preview banner before combat. Native live text
-- is created only inside AuraSlot initializeFrame and is never mutated in
-- combat by Decursive.
if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
        if D and D.Get121AlertAnchor then ensureAlert121Banner() end
    end)
end

-- AddAuraSound has no Lua callback; hook PlaySoundFile for live TIMED/flash assist.
local function maybePulseFromDispelSound(sound)
    if not isDispelAlertEnabled() then return end
    if not D.profile or not D.profile.PlaySound then return end
    if not soundMatchesDispelAlert(sound) then return end
    if type(sound) == "number" and T._DispelAlertSoundFileIDs then
        T._DispelAlertSoundFileIDs[sound] = true
    end
    if D.Show121DispelAlertWarning then
        D:Show121DispelAlertWarning("PlaySoundFile", false)
    end
end

if C_Timer and C_Timer.After and D.Refresh121DispelAlertSoundCache then
    C_Timer.After(0, function()
        if D.Refresh121DispelAlertSoundCache then D:Refresh121DispelAlertSoundCache() end
    end)
end

if _G.hooksecurefunc and _G.PlaySoundFile then
    hooksecurefunc("PlaySoundFile", function(sound)
        maybePulseFromDispelSound(sound)
    end)
end
if _G.hooksecurefunc and _G.C_Sound and _G.C_Sound.PlaySoundFile then
    hooksecurefunc(_G.C_Sound, "PlaySoundFile", function(sound)
        maybePulseFromDispelSound(sound)
    end)
end

function D:Save121AlertPosition()
    local f = alert121Anchor
    if not f then return end
    if f.StopMovingOrSizing then f:StopMovingOrSizing() end
    local point, _, _, x, y = f:GetPoint(1)
    if D.profile and point then
        D.profile.Alert121Point = { point = point, x = x, y = y }
    end
end

function D:Set121AlertMoveMode(enabled)
    local f = self:Get121AlertAnchor()
    alert121MoveMode = enabled and true or false
    if not alert121MoveMode then
        D:Save121AlertPosition()
    end
    f:EnableMouse(alert121MoveMode)
    if alert121MoveMode then f:Show() else f:Hide() end
end

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcralerts", function(msg)
        if msg == "move" then
            D:Set121AlertMoveMode(not alert121MoveMode)
            print(("|cFF29B8A8[Decursive]|r Alert position %s. Drag the purple box to move it, then run this again to lock it."):format(
                alert121MoveMode and "unlocked" or "locked"))
        else
            print("|cFF29B8A8[Decursive]|r /dcralerts move to reposition Alert warnings (DISPEL + Soul Link). Not the notification text anchor.")
        end
    end)
end

----------------------------------------------------------------
-- Alert diagnostic log: a small ring buffer of what the alert system
-- (interrupts, debuff-landed, Soul Link) actually decided, so testing
-- doesn't require guessing/round-tripping every time something doesn't
-- fire. Piggybacks D.db.global (a fresh top-level SavedVariables entry was
-- confirmed NOT to persist reliably this session; DecursiveDB already
-- does). Always uses plain print() to the single default chat frame, never
-- D:Println -- that one fans out to TWO possible windows (default chat
-- frame vs. Decursive's separate custom message frame, per Print_ChatFrame/
-- Print_CustomFrame), which is exactly the kind of "which window did it go
-- to" ambiguity a diagnostic tool must not have.
----------------------------------------------------------------

local MAX_ALERT_DIAG_LINES = 150

function D:AlertDiag(fmt, ...)
    if not D.db or not D.db.global then return end
    if not isAccessiblePublicValue(fmt) or type(fmt) ~= "string" then
        fmt = "<restricted diagnostic>"
    end
    local count = select("#", ...)
    local args = {}
    for i = 1, count do
        local value = select(i, ...)
        args[i] = isAccessiblePublicValue(value) and value or "<restricted>"
    end
    local ok, message = pcall(string.format, fmt, unpack(args, 1, count))
    if not ok then message = fmt .. " [format error]" end
    D.db.global.DcrAlertDiag = D.db.global.DcrAlertDiag or {}
    local log = D.db.global.DcrAlertDiag
    table.insert(log, ("[%s] %s"):format(date("%H:%M:%S"), message))
    while #log > MAX_ALERT_DIAG_LINES do
        table.remove(log, 1)
    end
end

function D:PrintAlertDiag(count)
    local log = D.db and D.db.global and D.db.global.DcrAlertDiag
    if not log or #log == 0 then
        print("|cFF29B8A8[Decursive]|r Alert diagnostic log is empty.")
        return
    end
    count = math.min(count or 25, #log)
    print(("|cFF29B8A8[Decursive]|r Last %d alert diagnostic lines (default chat frame only):"):format(count))
    for i = #log - count + 1, #log do
        print("|cFF6B7686" .. log[i] .. "|r")
    end
end

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcralertdiag", function(msg)
        if msg == "clear" then
            if D.db and D.db.global then D.db.global.DcrAlertDiag = {} end
            print("|cFF29B8A8[Decursive]|r Alert diagnostic log cleared.")
            return
        end
        D:PrintAlertDiag(tonumber(msg) or 25)
    end)
end

-- Marks every addon load/reload directly in the log, so reload timing can
-- be read straight from the file instead of relying on manual play-by-play.
-- Deferred to PLAYER_ENTERING_WORLD: D.db isn't set up yet at this point in
-- file load (AceDB initializes later, during OnInitialize), so calling
-- D:AlertDiag directly here always silently no-op'd (D.db.global didn't
-- exist yet) -- confirmed live: the marker never once appeared in the saved
-- log across several reload cycles.
local alertDiagLoadMarker = CreateFrame("Frame")
alertDiagLoadMarker:RegisterEvent("PLAYER_ENTERING_WORLD")
alertDiagLoadMarker:SetScript("OnEvent", function(self)
    if D.AlertDiag then D:AlertDiag("===== addon loaded/reloaded =====") end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

D:Debug("WoW 12.1 managed-aura + cooldown compatibility adapter loaded")
