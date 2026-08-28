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
--]]
-------------------------------------------------------------------------------
-- Zhaohu's Decursive - Emergency Soul Link range indicator
--
-- A dead ally can normally be battle-rezzed at range (Rebirth, Raise Ally and
-- Intercession all use the player's spell-cast range, which is well beyond
-- melee). Emergency Soul Link (Midnight Engineering item 269586,
-- spell 1259646) is different: it's a 5-yard cast, so relying on it means
-- you have to actually be standing next to the corpse. When Soul Link is the
-- exact smart-left action and is ready, this module colors the dead player's
-- MUF green in range or yellow out of range. The optional status-light warning
-- remains separate from that square color.
--
-- Only engages when the secure click has no state-appropriate native
-- resurrection spell. Native and item combat resurrection share the same
-- encounter constraints, so Soul Link is not offered as a second action when
-- a native action already owns that combat state.
local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if type(D) ~= "table" or not DC or not DC.TWELVEONE then return end

local SOUL_LINK_SPELL_ID = 1259646
local SOUL_LINK_ITEM_ID = 269586
local canaccessvalue = _G.canaccessvalue or function(_) return true end
local issecretvalue = _G.issecretvalue
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local soulLinkRunning = true

local function isAccessiblePublicValue(value)
    if issecretvalue and issecretvalue(value) then return false end
    if not canaccessvalue(value) then return false end
    if type(value) == "table" then
        if _G.issecrettable and _G.issecrettable(value) then return false end
        if _G.canaccesstable and not _G.canaccesstable(value) then return false end
    end
    return true
end

local function accessibleBoolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or not isAccessiblePublicValue(value) then return nil end
    if value ~= true and value ~= false and value ~= 1 and value ~= 0 then return nil end
    return value == true or value == 1
end

local function rawBoolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok then return nil end
    if issecretvalue and issecretvalue(value) then return value end
    if not isAccessiblePublicValue(value)
        or (value ~= true and value ~= false)
    then
        return nil
    end
    return value
end

-- Consume the exact action table published while the secure MUF macros are
-- built. Never rediscover spells, cooldowns or charges here: the visual must
-- describe the action that the protected click will actually execute.
local function stateUsesInstalledSoulLink()
    local actions = D.Status and D.Status.SmartRezActions
    if type(actions) ~= "table" then return false end

    local inCombat = accessibleBoolean(InCombatLockdown)
    if inCombat == nil then return false end
    if inCombat then return actions.combatSoulLink == true end
    return actions.outOfCombatSoulLink == true
end

local function soulLinkAvailable()
    if D.profile and D.profile.SoulLink121Enabled == false then return false end
    local count
    if C_Item and C_Item.GetItemCount then
        local ok, value = pcall(C_Item.GetItemCount, SOUL_LINK_ITEM_ID)
        if ok then count = value end
    end
    if not isAccessiblePublicValue(count) or type(count) ~= "number" then return false end
    if count < 1 then return false end

    local cooldownFunction = C_Item and C_Item.GetItemCooldown
        or C_Container and C_Container.GetItemCooldown
    if type(cooldownFunction) ~= "function" then return false end

    local ok, start, duration, enable = pcall(cooldownFunction, SOUL_LINK_ITEM_ID)
    if not ok
        or not isAccessiblePublicValue(start)
        or not isAccessiblePublicValue(duration)
        or not isAccessiblePublicValue(enable)
        or type(start) ~= "number"
        or type(duration) ~= "number"
        or (enable ~= true and enable ~= 1)
    then
        return false
    end
    -- Only an explicit public zero cooldown is proof that the item is ready.
    -- Unknown or malformed data must clear the color instead of preserving it.
    return start <= 0 and duration <= 0
end

-- C_Item.IsItemInRange/IsItemInRange are ADDON_ACTION_BLOCKED from
-- Decursive's tainted execution context (confirmed in-game). C_Spell.
-- IsSpellInRange against the item's underlying spell is the same range
-- check without touching a protected item-specific API. The returned boolean
-- may be secret, so callers pass it directly into a native texture method and
-- only inspect it after proving that it is public.
local function soulLinkRange(unit)
    if not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then return nil end
    return rawBoolean(C_Spell.IsSpellInRange, SOUL_LINK_SPELL_ID, unit)
end

local function clearMUFState(MF)
    if type(MF) ~= "table" then return end
    MF.Decursive121SoulLinkSmartLeftReady121 = false
    MF.Decursive121SoulLinkPriority2Ready121 = false
    MF.Decursive121SoulLinkAttemptUnit121 = nil
    if D.Clear121MUFDeathSoulLinkRange then
        D:Clear121MUFDeathSoulLinkRange(MF)
    end
    if D.Set121MUFSoulLinkRangeActive then
        D:Set121MUFSoulLinkRangeActive(MF, false)
    end
end

local function updateAll()
    if not soulLinkRunning then return end
    if not D.MicroUnitF or not D.MicroUnitF.UnitToMUF then return end

    local actionReady = (not D.profile or D.profile.SoulLink121Enabled ~= false)
        and stateUsesInstalledSoulLink()
        and soulLinkAvailable()

    for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
        clearMUFState(MF)
        local unit = MF and MF.CurrUnit
        local smartLeft = MF and MF.SmartRezLeftEnabled121 == true
        local priorityTwo = MF and MF.SmartRezFallbackPriority2Enabled121 == true
        local rezEligibleUnit = unit and D.IsMUFRezEligibleUnitToken
            and D:IsMUFRezEligibleUnitToken(unit) or false
        local exists = unit and accessibleBoolean(UnitExists, unit)
        local isPlayerUnit = unit and accessibleBoolean(UnitIsPlayer, unit)
        local isSelf = unit and accessibleBoolean(UnitIsUnit, unit, "player")
        local actionCandidate = actionReady and type(unit) == "string"
            and MF.Shown == true and rezEligibleUnit and (smartLeft or priorityTwo)
            and exists == true and isPlayerUnit == true and isSelf == false
        local visualCandidate = actionCandidate and smartLeft

        if actionCandidate then
            local dead = rawBoolean(UnitIsDeadOrGhost, unit)
            local deadIsSecret = issecretvalue and issecretvalue(dead) or false
            if deadIsSecret or dead == true then
                local inRange = soulLinkRange(unit)
                if visualCandidate and D.Set121MUFDeathSoulLinkRange then
                    D:Set121MUFDeathSoulLinkRange(MF, inRange)
                end

                -- Attempt tracking deliberately requires a public dead state.
                -- The secure macro remains authoritative when death is secret,
                -- but Lua will not arm an error attribution window by guessing.
                if not deadIsSecret and dead == true then
                    MF.Decursive121SoulLinkSmartLeftReady121 = smartLeft
                    MF.Decursive121SoulLinkPriority2Ready121 = priorityTwo
                    MF.Decursive121SoulLinkAttemptUnit121 = unit
                end

                -- The optional status light consumes only a public OOR result.
                -- It is separate from the raw green/yellow death-square range.
                local rangeIsSecret = issecretvalue and issecretvalue(inRange) or false
                if not rangeIsSecret and isAccessiblePublicValue(inRange)
                    and inRange == false and D.Set121MUFSoulLinkRangeActive
                then
                    D:Set121MUFSoulLinkRangeActive(MF, true)
                end
            end
        end
    end
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", updateAll)

local function registerWatcherEvents()
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
end

registerWatcherEvents()

-- Range and dead-state both need polling: there's no "moved into range" or
-- "released spirit" event to hook. A 1s tick against a handful of MUFs is
-- cheap.
local soulLinkTicker
local function startSoulLinkTicker()
    if not soulLinkTicker and C_Timer and C_Timer.NewTicker then
        soulLinkTicker = C_Timer.NewTicker(1, updateAll)
    end
end
startSoulLinkTicker()

-----------------------------------------------------------------
-- On-screen Alert warning when the item is actually attempted out of
-- range, on top of the persistent yellow dot -- WoW's own native "Out of
-- range" error doesn't say WHICH ability, so this names Soul Link and the
-- target explicitly. Uses the Alert warning system (DecursiveSoulLinkAlert /
-- /dcralerts), not the notification text window (DecursiveTextFrame).
--
-- UI_ERROR_MESSAGE carries no spellID, so the MUF PreClick hook records a
-- concrete macro-backed Soul Link item attempt before secure execution. Only a
-- whitelisted range error inside that 0.8-second attempt window is consumed.
-- unrelated range errors from other actions are ignored.
-- Dedicated center-screen Alert warning instead of UIErrorsFrame -- that frame
-- is shared with every other error message in the game. Uses the shared
-- D:Show121AlertWarning banner (same frame as DISPEL opportunity alerts).
local function showCenterAlert(message, bypassEnvironmentProfile)
    if D.Show121AlertWarning then
        D:Show121AlertWarning(message, nil, bypassEnvironmentProfile)
    end
end

-- Style changes for Alert121FontSize/Alert121Color apply to the shared banner.
function D:Apply121SoulLinkAlertStyle()
    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
end

local function showAlert(unit)
    if D.profile and D.profile.Alert121SoulLinkEnabled == false then
        if D.AlertDiag then D:AlertDiag("BATTLEREZ alert suppressed by toggle") end
        return
    end
    if not isAccessiblePublicValue(unit) or type(unit) ~= "string" then
        if D.AlertDiag then D:AlertDiag("BATTLEREZ showAlert called without an attributable target") end
        return
    end

    local name = D.UnitName and D:UnitName(unit) or nil
    if not isAccessiblePublicValue(name) or type(name) ~= "string" then name = "your target" end
    local message = ("Battle rez: move within range of %s!"):format(name)

    -- Don't log the full `message` -- it embeds UnitName(unit),
    -- which can be a secret string in some contexts (same class of issue
    -- fixed in Dcr_12_1_Encounters.lua's cast-name logging), and a secret
    -- value embedded in a logged string silently wipes that whole entry to
    -- nil on SavedVariables save.
    if D.AlertDiag then D:AlertDiag("BATTLEREZ range alert firing for stored MUF target") end
    showCenterAlert(message)
end

local failWatcher = CreateFrame("Frame")
local soulLinkAttempt

function D:Begin121SoulLinkAttempt(MF, button, requestedPriority, isUnmodified)
    soulLinkAttempt = nil
    local smartLeft = button == "LeftButton" and isUnmodified == true
        and MF and MF.Decursive121SoulLinkSmartLeftReady121 == true
    local priorityTwoFallback = MF
        and MF.Decursive121SoulLinkPriority2Ready121 == true
        and isUnmodified == true
        and requestedPriority == 2
    local unit = MF and MF.CurrUnit
    if not soulLinkRunning or type(MF) ~= "table"
        or not smartLeft and not priorityTwoFallback
        or type(unit) ~= "string"
        or MF.Decursive121SoulLinkAttemptUnit121 ~= unit
    then
        return false
    end
    soulLinkAttempt = {
        MF = MF,
        unit = unit,
        source = smartLeft and "smart-left" or "priority-2",
        startedAt = GetTime and GetTime() or 0,
    }
    return true
end

local function registerFailureEvents()
    pcall(failWatcher.RegisterEvent, failWatcher, "UI_ERROR_MESSAGE")
    failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
    failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
end

registerFailureEvents()
failWatcher:SetScript("OnEvent", function(_, event, arg1, arg2, spellID)
    local attempt = soulLinkAttempt
    local now = GetTime and GetTime() or 0
    if not attempt or now - (attempt.startedAt or 0) > 0.80 then return end
    if event == "UI_ERROR_MESSAGE" then
        -- (errorType, message) here -- see comment above.
        local msg = arg2
        if not isAccessiblePublicValue(arg1) or not isAccessiblePublicValue(msg) then return end
        local isRangeError = (SPELL_FAILED_OUT_OF_RANGE and msg == SPELL_FAILED_OUT_OF_RANGE)
            or (ERR_OUT_OF_RANGE and msg == ERR_OUT_OF_RANGE)
        if isRangeError then
            soulLinkAttempt = nil
            if D.AlertDiag then
                D:AlertDiag("BATTLEREZ Soul Link attempt failed range check (raw errorType=%s msg=%s)",
                    tostring(arg1), tostring(msg))
            end
            showAlert(attempt.unit)
        end
        return
    end
    -- UNIT_SPELLCAST_FAILED variants identify the attempted item spell but do
    -- not establish why it failed. Preserve the short attribution window for a
    -- possible exact UI range error, but never warn from this generic event.
    if isAccessiblePublicValue(spellID) and spellID == SOUL_LINK_SPELL_ID then
        return
    end
end)

local soulLinkLifecyclePending
local soulLinkLifecycleFrame = CreateFrame("Frame")
soulLinkLifecycleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function clearSoulLinkVisuals()
    if D.MicroUnitF and D.MicroUnitF.UnitToMUF then
        for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
            clearMUFState(MF)
        end
    end
    return true
end

function D:Shutdown121SoulLink()
    soulLinkRunning = false
    soulLinkAttempt = nil
    watcher:UnregisterAllEvents()
    failWatcher:UnregisterAllEvents()
    if soulLinkTicker and soulLinkTicker.Cancel then soulLinkTicker:Cancel() end
    soulLinkTicker = nil
    if not clearSoulLinkVisuals() then
        soulLinkLifecyclePending = "shutdown"
        return false
    end
    return true
end

function D:Startup121SoulLink()
    if InCombatLockdown and InCombatLockdown() then
        soulLinkLifecyclePending = "startup"
        return false
    end
    soulLinkLifecyclePending = nil
    soulLinkRunning = true
    registerWatcherEvents()
    registerFailureEvents()
    startSoulLinkTicker()
    updateAll()
    return true
end

soulLinkLifecycleFrame:SetScript("OnEvent", function()
    local pending = soulLinkLifecyclePending
    soulLinkLifecyclePending = nil
    if pending == "startup" then
        D:Startup121SoulLink()
    elseif pending == "shutdown" then
        clearSoulLinkVisuals()
    end
end)

-- Manual test trigger for the options-panel button (Dcr_opt.lua) -- shows
-- the same on-screen banner used for a real out-of-range attempt, using a
-- fixed placeholder name, so the rendering/styling can be verified on demand
-- without needing to actually reproduce a dead-ally-out-of-range situation.
function D:Test121SoulLinkAlert()
    showCenterAlert("Battle rez: move within range of Test Target!", true)
end

-----------------------------------------------------------------
-- Slash command: /dcrsoullink -- toggles D.profile.SoulLink121Enabled
-- (default on, matching every other profile boolean's nil-is-true idiom
-- used throughout this file family).
-----------------------------------------------------------------

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcrsoullink", function()
        local currentlyEnabled = not D.profile or D.profile.SoulLink121Enabled ~= false
        D.profile.SoulLink121Enabled = not currentlyEnabled
        D:Println(("Emergency Soul Link fallback %s."):format(
            D.profile.SoulLink121Enabled == false and "disabled" or "enabled"))
        if D.RefreshMUFActionMacros then D:RefreshMUFActionMacros("Soul Link slash toggle") end
        updateAll()
    end)
end
