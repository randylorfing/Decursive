--[[
    Decursive WoW 12.1 Compatibility Utilities
    
    Safe wrapper functions for APIs that return secrets or are restricted
    in WoW 12.1 protected contexts (combat, raids, M+, PvP).
    
    This module provides safe alternatives to dangerous API calls.
--]]

local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C

if not D or not DC or not DC.TWELVEONE then return end

-- Safe unit tokens that can always be accessed
local SAFE_UNIT_TOKENS = {
    player = true,
    pet = true,
    vehicle = true,
}

-- ============================================================================
-- Context Detection
-- ============================================================================

local function IsSafeUnitToken(unitToken)
    return SAFE_UNIT_TOKENS[unitToken] or false
end

local function IsProtectedContext()
    -- On Retail 12.1, Lua aura detail access can become secret in several
    -- contexts beyond a simple raid/arena combat check. Decursive does not
    -- need direct aura-data reads on 12.1, so treat the entire 12.1 runtime as
    -- managed-only for aura inspection purposes.
    return DC.TWELVEONE == true
end

local function ShouldUseAuraContainer()
    return DC.TWELVEONE == true
end

-- ============================================================================
-- Safe Unit Information Access
-- ============================================================================

-- Safe wrapper for UnitClass. 12.1 unit-identity APIs can return secret
-- values for identity-restricted units; combat alone is not a reason to drop
-- otherwise-readable class information. Preserve each accessible return value.
local canaccessvalue = _G.canaccessvalue or function(_) return true end

local function AccessibleOrNil(value)
    if value == nil then return nil end
    return canaccessvalue(value) and value or nil
end

function D:GetUnitClassSafe(unitToken)
    if not unitToken then return nil end
    local ok, className, classFile, classID = pcall(UnitClass, unitToken)
    if not ok then return nil end
    return AccessibleOrNil(className), AccessibleOrNil(classFile), AccessibleOrNil(classID)
end

-- Safe wrapper for UnitRace. Treat secrecy per returned value rather than
-- assuming every non-player unit is unreadable during combat.
function D:GetUnitRaceSafe(unitToken)
    if not unitToken then return nil end
    local ok, localizedRace, englishRace, raceID = pcall(UnitRace, unitToken)
    if not ok then return nil end
    return AccessibleOrNil(localizedRace), AccessibleOrNil(englishRace), AccessibleOrNil(raceID)
end

-- UnitIsCharmed / UnitIsPossessed can return secret booleans while aura access
-- is secret. Never branch on a value until canaccessvalue() confirms access.
function D:IsUnitCharmedSafe(unitToken)
    if not unitToken then return false end
    local ok, value = pcall(UnitIsCharmed, unitToken)
    if not ok or not canaccessvalue(value) then return false end
    return value and true or false
end

function D:IsUnitPossessedSafe(unitToken)
    if not unitToken then return false end
    local ok, value = pcall(UnitIsPossessed, unitToken)
    if not ok or not canaccessvalue(value) then return false end
    return value and true or false
end

-- ============================================================================
-- Safe Aura Information Access
-- ============================================================================

-- Safe wrapper for getting aura application count
function D:GetAuraApplicationCountSafe(unit, auraInstanceID)
    if not unit or not auraInstanceID then
        return nil
    end
    
    if IsProtectedContext() then
        if D.Debug then D:Debug("Cannot read aura count in protected context") end
        return nil
    end
    
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 1)
    if not ok then
        if D.errln then D:errln("Failed to get aura application count:", unit, auraInstanceID) end
        return nil
    end
    
    return count
end

-- Get dispel type color safely
function D:GetDispelTypeColorSafe(unit, auraInstanceID)
    if not unit or not auraInstanceID then
        return nil
    end
    
    if IsProtectedContext() then
        return nil
    end
    
    local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, auraInstanceID, D.Status.dsCurve)
    if not ok then
        return nil
    end
    
    return color
end

-- ============================================================================
-- Context Helpers
-- ============================================================================

-- Get environment profile (for settings)
function D:GetEnvironmentProfile()
    if not DC.TWELVEONE then
        return "LEGACY"
    end
    
    local _, _, _, _, instanceType = GetInstanceInfo()
    local isChallengeMode = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive()
    
    if isChallengeMode then
        return "MYTHIC_PLUS"
    elseif instanceType == "raid" then
        return "RAID"
    elseif instanceType == "arena" or instanceType == "pvp" then
        return "PVP"
    elseif instanceType == "party" then
        return "DUNGEON"
    else
        return "OPEN_WORLD"
    end
end

-- Get detection mode (STRICT_MANAGED vs MANAGED vs LEGACY)
function D:GetDetectionMode()
    if not DC.TWELVEONE then
        return "LEGACY"
    end
    return "STRICT_MANAGED"
end

-- Check if legacy aura scanning is safe
function D:CanUseLegacyScanning()
    -- Mainline 12.1 uses Blizzard-managed aura detection exclusively.
    return not DC.TWELVEONE
end

-- ============================================================================
-- Exported Utilities
-- ============================================================================

D.Compat121 = {
    IsSafeUnitToken = IsSafeUnitToken,
    IsProtectedContext = IsProtectedContext,
    ShouldUseAuraContainer = ShouldUseAuraContainer,
    CanUseLegacyScanning = function() 
        -- Delegate to Dcr_12_1.lua function if available
        if D.Can121UseLegacyScanning then
            return D:Can121UseLegacyScanning()
        end
        return false -- Safe 12.1 fallback: never enumerate protected auras
    end,
}

if D.Debug then
    D:Debug("12.1 Compatibility Utils loaded")
end
