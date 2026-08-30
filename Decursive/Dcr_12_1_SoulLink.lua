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
local SOUL_LINK_ITEM_ID = DC.SoulLinkItemID or 269586
local MAX_ACTION_SLOTS = 180
local canaccessvalue = _G.canaccessvalue or function(_) return true end
local issecretvalue = _G.issecretvalue
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local ActionBar = _G.C_ActionBar
local GetActionInfo = ActionBar and ActionBar.GetActionInfo or _G.GetActionInfo
local GetActionText = ActionBar and ActionBar.GetActionText or _G.GetActionText
local GetMacroIndexByName = _G.GetMacroIndexByName
local GetMacroBody = _G.GetMacroBody
local soulLinkRunning = true
local soulLinkActionSlot
local soulLinkActionKind
local actionSlotRescanPending
local actionSlotRescanQueued
local actionSlotDirty = true
local actionScanState = {
    result = "not-scanned",
    actionInfo = "not-scanned",
    macro = "not-scanned",
}
local passiveStateByUnit = {}
local lastDeadStateByUnit = {}
local recentAPIErrors = {}
local lastGlobalState = {}
local updateAll

local function isSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end

local function isAccessiblePublicValue(value)
    if isSecretValue(value) then return false end
    local ok, accessible = pcall(canaccessvalue, value)
    if not ok or accessible ~= true then return false end
    if type(value) == "table" then
        if type(_G.issecrettable) == "function" then
            local secretOK, secret = pcall(_G.issecrettable, value)
            if not secretOK or secret == true then return false end
        end
        if type(_G.canaccesstable) == "function" then
            local tableOK, tableAccessible = pcall(_G.canaccesstable, value)
            if not tableOK or tableAccessible ~= true then return false end
        end
    end
    return true
end

local function recordAPIError(category)
    if type(category) ~= "string" or category == "" then return end
    if recentAPIErrors[#recentAPIErrors] == category then return end
    recentAPIErrors[#recentAPIErrors + 1] = category
    if #recentAPIErrors > 12 then table.remove(recentAPIErrors, 1) end
end

local function classifyBooleanValue(value)
    if isSecretValue(value) then return value, "secret" end
    if not isAccessiblePublicValue(value) then return nil, "error" end
    if value == true or value == 1 then return true, "true" end
    if value == false or value == 0 then return false, "false" end
    if value == nil then return nil, "nil" end
    return nil, "error"
end

local function callBoolean(func, category, ...)
    if type(func) ~= "function" then
        recordAPIError(category .. ":missing")
        return nil, "error"
    end
    local ok, value = pcall(func, ...)
    if not ok then
        recordAPIError(category .. ":error")
        return nil, "error"
    end
    local raw, valueCategory = classifyBooleanValue(value)
    if valueCategory == "error" then recordAPIError(category .. ":value") end
    return raw, valueCategory
end

-- Consume the exact action table published while the secure MUF macros are
-- built. Never rediscover spells, cooldowns or charges here: the visual must
-- describe the action that the protected click will actually execute.
local function stateUsesInstalledSoulLink()
    local actions = D.Status and D.Status.SmartRezActions
    if type(actions) ~= "table" then return false, "no-smart-rez-actions", "unavailable", "nil" end

    local inCombat, combatCategory = callBoolean(InCombatLockdown, "combat")
    local flags = "combatSL=" .. (actions.combatSoulLink == true and "true" or "false")
        .. " oocSL=" .. (actions.outOfCombatSoulLink == true and "true" or "false")
        .. " nativeBR=" .. (actions.battleRezName and "present" or "none")
        .. " normalRez=" .. (actions.outOfCombatRezName and "present" or "none")
    if combatCategory ~= "true" and combatCategory ~= "false" then
        return false, "combat-unknown", flags, combatCategory
    end
    if inCombat then
        return actions.combatSoulLink == true,
            actions.combatSoulLink == true and "combat-soul-link" or "combat-other-action",
            flags, combatCategory
    end
    return actions.outOfCombatSoulLink == true,
        actions.outOfCombatSoulLink == true and "ooc-soul-link" or "ooc-other-action",
        flags, combatCategory
end

local function isSimpleSoulLinkMacro(body)
    if not isAccessiblePublicValue(body) or type(body) ~= "string" then return false end

    local foundUse
    local foundTooltip
    body = body:gsub("\r\n", "\n") .. "\n"
    for line in body:gmatch("([^\n]*)\n") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local lower = line:lower()
            if lower == "#showtooltip" or lower == "#showtooltip item:269586" then
                if foundTooltip then return false end
                foundTooltip = true
            elseif lower:match("^/use%s+item:269586%s*$") then
                if foundUse then return false end
                foundUse = true
            else
                -- Conditionals, scripts, multiple actions and arbitrary macro
                -- text are intentionally rejected. Only a deterministic item
                -- action can be trusted for passive range feedback.
                return false
            end
        end
    end
    return foundUse == true
end

local function readActionInfo(slot)
    if type(GetActionInfo) ~= "function" then
        recordAPIError("action-info:missing")
        return nil
    end
    local ok, actionType, actionID, subType = pcall(GetActionInfo, slot)
    if not ok then
        recordAPIError("action-info:error")
        return nil
    end
    if not isAccessiblePublicValue(actionType)
        or not isAccessiblePublicValue(actionID)
        or not isAccessiblePublicValue(subType)
    then
        recordAPIError("action-info:secret")
        return nil
    end
    return actionType, actionID, subType
end

local function readMacroBodyForAction(slot, actionID)
    if type(GetMacroBody) ~= "function" then
        recordAPIError("macro-body:missing")
        return nil, "body-api-missing"
    end

    -- On current retail clients a macro action's ID can be the resolved spell
    -- or item ID rather than the macro index. Resolve the index from the
    -- action's displayed macro name first; retain the old ID path only as a
    -- compatibility fallback for clients/mocks that still return an index.
    if type(GetActionText) == "function" and type(GetMacroIndexByName) == "function" then
        local nameOK, macroName = pcall(GetActionText, slot)
        if not nameOK then
            recordAPIError("action-text:error")
        elseif isAccessiblePublicValue(macroName) and type(macroName) == "string" then
            local indexOK, macroIndex = pcall(GetMacroIndexByName, macroName)
            if not indexOK then
                recordAPIError("macro-index:error")
            elseif isAccessiblePublicValue(macroIndex) and type(macroIndex) == "number"
                and macroIndex > 0
            then
                local bodyOK, body = pcall(GetMacroBody, macroIndex)
                if not bodyOK then
                    recordAPIError("macro-body:error")
                elseif isAccessiblePublicValue(body) and type(body) == "string" then
                    return body, "name-index"
                end
            end
        elseif macroName ~= nil then
            recordAPIError("action-text:secret")
        end
    end

    if isAccessiblePublicValue(actionID) and type(actionID) == "number" then
        local bodyOK, body = pcall(GetMacroBody, actionID)
        if not bodyOK then
            recordAPIError("macro-body:error")
        elseif isAccessiblePublicValue(body) and type(body) == "string" then
            return body, "legacy-action-id"
        end
    end
    return nil, "unresolved"
end

local function scanSoulLinkActionSlot()
    local inCombat, combatCategory = callBoolean(InCombatLockdown, "combat")
    if combatCategory ~= "false" then
        -- Real action placement cannot change while protected. Keep the last
        -- OOC-verified cache usable during combat even if an action-bar addon
        -- emits ACTIONBAR_SLOT_CHANGED for page/mouseover state changes.
        actionSlotDirty = true
        actionSlotRescanPending = true
        actionScanState.result = "deferred-combat"
        return false
    end

    local firstMacroSlot
    local firstMacroSource
    local firstMacroInfo
    actionScanState.actionInfo = "none"
    actionScanState.macro = "none"
    for slot = 1, MAX_ACTION_SLOTS do
        local actionType, actionID, subType = readActionInfo(slot)
        if actionType == "item" and actionID == SOUL_LINK_ITEM_ID then
            soulLinkActionSlot = slot
            soulLinkActionKind = "item"
            actionSlotRescanPending = nil
            actionSlotDirty = false
            actionScanState.result = "direct-item"
            actionScanState.actionInfo = "type=item subtype="
                .. (type(subType) == "string" and subType or "none") .. " idMatch=true"
            actionScanState.macro = "not-needed"
            return true
        elseif actionType == "macro" and not firstMacroSlot then
            local body, source = readMacroBodyForAction(slot, actionID)
            local simple = isSimpleSoulLinkMacro(body)
            actionScanState.macro = simple and ("simple:" .. source) or ("rejected:" .. source)
            if simple then
                firstMacroSlot = slot
                firstMacroSource = source
                firstMacroInfo = "type=macro subtype="
                    .. (type(subType) == "string" and subType or "none")
                    .. " resolvedItem=" .. (actionID == SOUL_LINK_ITEM_ID and "true" or "false")
            end
        end
    end

    soulLinkActionSlot = firstMacroSlot
    soulLinkActionKind = firstMacroSlot and "macro" or nil
    actionSlotRescanPending = nil
    actionSlotDirty = false
    if firstMacroSlot then
        actionScanState.result = "simple-macro"
        actionScanState.actionInfo = firstMacroInfo
        actionScanState.macro = "simple:" .. firstMacroSource
    else
        actionScanState.result = "no-match"
    end
    return firstMacroSlot ~= nil
end

local function finishSoulLinkActionSlotRescan()
    actionSlotRescanQueued = nil
    scanSoulLinkActionSlot()
    if updateAll then updateAll() end
end

local function requestSoulLinkActionSlotRescan()
    local inCombat, combatCategory = callBoolean(InCombatLockdown, "combat")
    actionSlotDirty = true
    if combatCategory ~= "false" then
        actionSlotRescanPending = true
        actionScanState.result = "deferred-combat"
        return false
    end
    if actionSlotRescanQueued then return true end

    actionSlotRescanQueued = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, finishSoulLinkActionSlotRescan)
    else
        finishSoulLinkActionSlotRescan()
    end
    return true
end

function D:Get121SoulLinkActionSlot()
    return soulLinkActionSlot, soulLinkActionKind
end

function D:Refresh121SoulLinkActionSlot()
    actionSlotDirty = true
    return requestSoulLinkActionSlotRescan()
end

local function actionCooldownReady(slot)
    if type(slot) ~= "number" then return false, "no-action-slot", "nil", "nil", "nil" end
    if not ActionBar or type(ActionBar.GetActionCooldown) ~= "function" then
        recordAPIError("cooldown:missing")
        return false, "cooldown-api-missing", "error", "error", "error"
    end

    local ok, info = pcall(ActionBar.GetActionCooldown, slot)
    if not ok then
        recordAPIError("cooldown:error")
        return false, "cooldown-api-error", "error", "error", "error"
    end
    if type(info) ~= "table" or not isAccessiblePublicValue(info) then
        recordAPIError("cooldown:table")
        return false, "cooldown-table-unavailable", "error", "error", "error"
    end

    local _, enabledCategory = classifyBooleanValue(info.isEnabled)
    local _, activeCategory = classifyBooleanValue(info.isActive)
    local _, gcdCategory = classifyBooleanValue(info.isOnGCD)
    if enabledCategory ~= "true" then
        return false, "cooldown-disabled-or-unknown", enabledCategory, activeCategory, gcdCategory
    end
    if activeCategory == "false" then
        return true, "inactive", enabledCategory, activeCategory, gcdCategory
    end
    if activeCategory ~= "true" then
        return false, "active-unknown", enabledCategory, activeCategory, gcdCategory
    end
    if gcdCategory == "true" then
        return true, "gcd-only", enabledCategory, activeCategory, gcdCategory
    end
    if gcdCategory == "false" then
        return false, "real-cooldown", enabledCategory, activeCategory, gcdCategory
    end
    return false, "active-gcd-unknown", enabledCategory, activeCategory, gcdCategory
end

local function carriedSoulLinkItem()
    if type(D.HasCarriedSoulLinkItem) ~= "function" then
        recordAPIError("carried-item:missing")
        return false, "error"
    end
    local ok, value = pcall(D.HasCarriedSoulLinkItem, D)
    if not ok then
        recordAPIError("carried-item:error")
        return false, "error"
    end
    local _, category = classifyBooleanValue(value)
    return category == "true", category
end

-- Item-specific range APIs are blocked in Decursive's tainted combat context.
-- A real action slot is the combat-safe bridge Blizzard exposes. Discovery is
-- done only out of combat; the cached slot may be on any hidden/unselected page.
-- The returned boolean may be secret and is forwarded unchanged to the MUF's
-- native boolean-aware color method.
local function soulLinkRange(unit)
    if type(soulLinkActionSlot) ~= "number" then return nil, "nil" end
    if not ActionBar or type(ActionBar.IsActionInRange) ~= "function" then
        recordAPIError("range:missing")
        return nil, "error"
    end
    return callBoolean(ActionBar.IsActionInRange, "range", soulLinkActionSlot, unit)
end

local function clearMUFState(MF)
    if type(MF) ~= "table" then return end
    MF.Decursive121SoulLinkSmartLeftReady121 = false
    MF.Decursive121SoulLinkPriority2Ready121 = false
    MF.Decursive121SoulLinkAttemptUnit121 = nil
    if D.Clear121MUFDeathSoulLinkRange then
        local ok = pcall(D.Clear121MUFDeathSoulLinkRange, D, MF)
        if not ok then recordAPIError("muf-clear:error") end
    end
    if D.Set121MUFSoulLinkRangeActive then
        local ok = pcall(D.Set121MUFSoulLinkRangeActive, D, MF, false)
        if not ok then recordAPIError("muf-status-light-clear:error") end
    end
end

local function safeUnitToken(unit)
    if not isAccessiblePublicValue(unit) or type(unit) ~= "string" then
        return "<unavailable-unit>", false
    end
    if unit == "player" or unit == "pet"
        or unit:match("^party[1-4]$") or unit:match("^partypet[1-4]$")
        or unit:match("^raid[1-9]$") or unit:match("^raid[1-3][0-9]$")
        or unit == "raid40" or unit:match("^raidpet[1-9]$")
        or unit:match("^raidpet[1-3][0-9]$") or unit == "raidpet40"
    then
        return unit, true
    end
    return "<nonstandard-unit>", false
end

local function safeFlag(value)
    return value == true and "true" or value == false and "false" or "nil"
end

local function copyPassiveState(state)
    local copy = {}
    for key, value in pairs(state) do copy[key] = value end
    return copy
end

updateAll = function()
    if not soulLinkRunning then return end
    if not D.MicroUnitF or not D.MicroUnitF.UnitToMUF then return end

    local enabled = not D.profile or D.profile.SoulLink121Enabled ~= false
    local usesSoulLink, actionReason, actionFlags, combatCategory = stateUsesInstalledSoulLink()
    local carried, carriedCategory = carriedSoulLinkItem()
    local cooldownReady = false
    local cooldownReason = "not-checked"
    local cooldownEnabledCategory = "nil"
    local cooldownActiveCategory = "nil"
    local cooldownGCDCategory = "nil"
    if enabled and usesSoulLink and carried then
        cooldownReady, cooldownReason, cooldownEnabledCategory,
            cooldownActiveCategory, cooldownGCDCategory = actionCooldownReady(soulLinkActionSlot)
    elseif not enabled then
        cooldownReason = "feature-disabled"
    elseif not usesSoulLink then
        cooldownReason = actionReason
    elseif not carried then
        cooldownReason = "item-not-carried"
    end
    local actionReady = enabled and usesSoulLink and carried and cooldownReady
    lastGlobalState = {
        combat = combatCategory,
        enabled = safeFlag(enabled),
        carried = carriedCategory,
        actionFlags = actionFlags,
        actionReason = actionReason,
        cooldownReady = safeFlag(cooldownReady),
        cooldownReason = cooldownReason,
        cooldownEnabled = cooldownEnabledCategory,
        cooldownActive = cooldownActiveCategory,
        cooldownGCD = cooldownGCDCategory,
    }
    local nextPassiveState = {}

    for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
        clearMUFState(MF)
        local unit = MF and MF.CurrUnit
        local unitToken, unitPublic = safeUnitToken(unit)
        local smartLeft = MF and MF.SmartRezLeftEnabled121 == true
        local priorityTwo = MF and MF.SmartRezFallbackPriority2Enabled121 == true
        local ignoredBoolean
        local rezEligibleCategory = "nil"
        if unitPublic and type(D.IsMUFRezEligibleUnitToken) == "function" then
            local eligibleOK, eligibleValue = pcall(D.IsMUFRezEligibleUnitToken, D, unit)
            if eligibleOK then
                ignoredBoolean, rezEligibleCategory = classifyBooleanValue(eligibleValue)
            else
                rezEligibleCategory = "error"
                recordAPIError("rez-eligible:error")
            end
        end
        local existsCategory = "nil"
        if unitPublic then
            ignoredBoolean, existsCategory = callBoolean(UnitExists, "unit-exists", unit)
        end
        local playerCategory = "nil"
        local selfCategory = "nil"
        if unitPublic then
            ignoredBoolean, playerCategory = callBoolean(UnitIsPlayer, "unit-player", unit)
            ignoredBoolean, selfCategory = callBoolean(UnitIsUnit, "unit-self", unit, "player")
        end
        local actionCandidate = actionReady and unitPublic
            and MF.Shown == true and rezEligibleCategory == "true" and (smartLeft or priorityTwo)
            and existsCategory == "true" and playerCategory == "true" and selfCategory == "false"
        local visualCandidate = actionCandidate and smartLeft
        local state = {
            unit = unitToken,
            combat = combatCategory,
            enabled = safeFlag(enabled),
            carried = carriedCategory,
            actionFlags = actionFlags,
            actionReason = actionReason,
            slot = type(soulLinkActionSlot) == "number" and soulLinkActionSlot or 0,
            kind = soulLinkActionKind or "none",
            dirty = safeFlag(actionSlotDirty),
            pending = safeFlag(actionSlotRescanPending == true),
            queued = safeFlag(actionSlotRescanQueued == true),
            scanResult = actionScanState.result,
            actionInfo = actionScanState.actionInfo,
            macro = actionScanState.macro,
            cooldownReady = safeFlag(cooldownReady),
            cooldownReason = cooldownReason,
            cooldownEnabled = cooldownEnabledCategory,
            cooldownActive = cooldownActiveCategory,
            cooldownGCD = cooldownGCDCategory,
            shown = safeFlag(MF and MF.Shown == true),
            eligible = rezEligibleCategory,
            smartLeft = safeFlag(smartLeft),
            priorityTwo = safeFlag(priorityTwo),
            exists = existsCategory or "nil",
            player = playerCategory,
            self = selfCategory,
            dead = "not-checked",
            range = "not-checked",
            gate = "not-ready",
            final = "black",
        }

        if not enabled then state.gate = "feature-disabled"
        elseif not usesSoulLink then state.gate = actionReason
        elseif not carried then state.gate = "item-not-carried"
        elseif type(soulLinkActionSlot) ~= "number" then state.gate = "no-action-slot"
        elseif not cooldownReady then state.gate = cooldownReason
        elseif MF.Shown ~= true then state.gate = "muf-hidden"
        elseif rezEligibleCategory ~= "true" then state.gate = "unit-ineligible-" .. rezEligibleCategory
        elseif not smartLeft and not priorityTwo then state.gate = "no-smart-rez-click"
        elseif existsCategory ~= "true" then state.gate = "unit-exists-" .. (existsCategory or "nil")
        elseif playerCategory ~= "true" then state.gate = "unit-player-" .. playerCategory
        elseif selfCategory ~= "false" then state.gate = "unit-self-" .. selfCategory
        else state.gate = "candidate" end

        if actionCandidate then
            local _, deadCategory = callBoolean(UnitIsDeadOrGhost, "unit-dead", unit)
            state.dead = deadCategory
            local deadIsSecret = deadCategory == "secret"
            if deadIsSecret or deadCategory == "true" then
                state.gate = "dead"
                local inRange, rangeCategory = soulLinkRange(unit)
                state.range = rangeCategory
                if visualCandidate and D.Set121MUFDeathSoulLinkRange then
                    local applied = pcall(D.Set121MUFDeathSoulLinkRange, D, MF, inRange)
                    if applied then
                        if rangeCategory == "true" then state.final = "green"
                        elseif rangeCategory == "false" then state.final = "yellow"
                        elseif rangeCategory == "secret" then state.final = "secret-boolean-forwarded"
                        else state.final = "black" end
                    else
                        recordAPIError("muf-color:error")
                        state.final = "black-render-error"
                    end
                elseif priorityTwo then
                    state.final = "black-priority-two-only"
                end

                -- Attempt tracking deliberately requires a public dead state.
                -- The secure macro remains authoritative when death is secret,
                -- but Lua will not arm an error attribution window by guessing.
                if deadCategory == "true" then
                    MF.Decursive121SoulLinkSmartLeftReady121 = smartLeft
                    MF.Decursive121SoulLinkPriority2Ready121 = priorityTwo
                    MF.Decursive121SoulLinkAttemptUnit121 = unit
                end

                -- The optional status light consumes only a public OOR result.
                -- It is separate from the raw green/yellow death-square range.
                if rangeCategory == "false" and D.Set121MUFSoulLinkRangeActive
                then
                    local ok = pcall(D.Set121MUFSoulLinkRangeActive, D, MF, true)
                    if not ok then recordAPIError("muf-status-light:error") end
                end
                if visualCandidate then state.gate = "range-" .. rangeCategory end
            else
                state.gate = "dead-" .. deadCategory
            end
        end
        nextPassiveState[unitToken] = state
        if state.dead == "true" or state.dead == "secret" then
            lastDeadStateByUnit[unitToken] = copyPassiveState(state)
        end
    end
    passiveStateByUnit = nextPassiveState
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event)
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS"
        or event == "PLAYER_ENTERING_WORLD"
    then
        actionSlotDirty = true
        requestSoulLinkActionSlotRescan()
    elseif event == "PLAYER_REGEN_ENABLED" and actionSlotRescanPending then
        requestSoulLinkActionSlotRescan()
    end
    updateAll()
end)

local function registerWatcherEvents()
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    watcher:RegisterEvent("UPDATE_MACROS")
end

registerWatcherEvents()
requestSoulLinkActionSlotRescan()

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
-- Privacy-safe Emergency Soul Link diagnostics. This intentionally records
-- only controlled categories and stable unit tokens, never character names,
-- GUIDs, macro names/bodies or secret values. The window is ordinary,
-- addon-owned UI and performs no protected action.
-----------------------------------------------------------------

local function diagnosticVersion()
    local version = D.version
    if isAccessiblePublicValue(version) and type(version) == "string"
        and version:match("^[%w%._%-@]+$")
    then
        return version
    end
    return "unknown"
end

local function sortedStateKeys(states)
    local keys = {}
    for unit in pairs(states) do keys[#keys + 1] = unit end
    table.sort(keys)
    return keys
end

local function appendDiagnosticState(lines, heading, state)
    lines[#lines + 1] = heading .. " " .. state.unit
    lines[#lines + 1] = "  gate=" .. state.gate .. " final=" .. state.final
        .. " combat=" .. state.combat .. " enabled=" .. state.enabled
        .. " carried=" .. state.carried
    lines[#lines + 1] = "  flags=" .. state.actionFlags
        .. " actionReason=" .. state.actionReason
    lines[#lines + 1] = "  cache slot=" .. (state.slot > 0 and string.format("%d", state.slot) or "none")
        .. " kind=" .. state.kind .. " dirty=" .. state.dirty
        .. " pending=" .. state.pending .. " queued=" .. state.queued
    lines[#lines + 1] = "  scan=" .. state.scanResult
        .. " actionInfo={" .. state.actionInfo .. "} macro=" .. state.macro
    lines[#lines + 1] = "  cooldown ready=" .. state.cooldownReady
        .. " reason=" .. state.cooldownReason
        .. " enabled=" .. state.cooldownEnabled
        .. " active=" .. state.cooldownActive .. " onGCD=" .. state.cooldownGCD
    lines[#lines + 1] = "  muf shown=" .. state.shown .. " eligible=" .. state.eligible
        .. " smartLeft=" .. state.smartLeft .. " priority2=" .. state.priorityTwo
    lines[#lines + 1] = "  unit exists=" .. state.exists .. " player=" .. state.player
        .. " self=" .. state.self .. " dead=" .. state.dead
        .. " range=" .. state.range
end

function D:Get121SoulLinkStatusText()
    local lines = {
        "Decursive Emergency Soul Link status",
        "build=" .. diagnosticVersion() .. " addon=Decursive",
        "privacy=unit tokens only; no names, GUIDs, macro text, or secret values",
        "global combat=" .. (lastGlobalState.combat or "not-sampled")
            .. " enabled=" .. (lastGlobalState.enabled or "not-sampled")
            .. " carried=" .. (lastGlobalState.carried or "not-sampled"),
        "global flags=" .. (lastGlobalState.actionFlags or "not-sampled")
            .. " actionReason=" .. (lastGlobalState.actionReason or "not-sampled"),
        "global cache slot=" .. (type(soulLinkActionSlot) == "number"
            and string.format("%d", soulLinkActionSlot) or "none")
            .. " kind=" .. (soulLinkActionKind or "none")
            .. " dirty=" .. safeFlag(actionSlotDirty)
            .. " pending=" .. safeFlag(actionSlotRescanPending == true)
            .. " queued=" .. safeFlag(actionSlotRescanQueued == true),
        "global scan=" .. actionScanState.result
            .. " actionInfo={" .. actionScanState.actionInfo .. "} macro=" .. actionScanState.macro,
        "global cooldown ready=" .. (lastGlobalState.cooldownReady or "not-sampled")
            .. " reason=" .. (lastGlobalState.cooldownReason or "not-sampled")
            .. " enabled=" .. (lastGlobalState.cooldownEnabled or "not-sampled")
            .. " active=" .. (lastGlobalState.cooldownActive or "not-sampled")
            .. " onGCD=" .. (lastGlobalState.cooldownGCD or "not-sampled"),
        "recent API categories=" .. (#recentAPIErrors > 0
            and table.concat(recentAPIErrors, ",") or "none"),
        "",
        "CURRENT MUF PASSIVE STATE",
    }

    local currentKeys = sortedStateKeys(passiveStateByUnit)
    if #currentKeys == 0 then lines[#lines + 1] = "  none sampled" end
    for i = 1, #currentKeys do
        appendDiagnosticState(lines, "MUF", passiveStateByUnit[currentKeys[i]])
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "LAST DEAD MUF STATE (retained after resurrection/combat)"
    local deadKeys = sortedStateKeys(lastDeadStateByUnit)
    if #deadKeys == 0 then lines[#lines + 1] = "  none sampled" end
    for i = 1, #deadKeys do
        appendDiagnosticState(lines, "LAST-DEAD", lastDeadStateByUnit[deadKeys[i]])
    end
    return table.concat(lines, "\n")
end

local soulLinkStatusFrame
local function setSoulLinkStatusText()
    if not soulLinkStatusFrame or not soulLinkStatusFrame.editBox then return end
    soulLinkStatusFrame.editBox:SetText(D:Get121SoulLinkStatusText())
    soulLinkStatusFrame.editBox:SetCursorPosition(0)
end

local function createSoulLinkStatusFrame()
    local frame = CreateFrame("Frame", "DecursiveSoulLinkStatusFrame121", UIParent, "BackdropTemplate")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Decursive Emergency Soul Link Status")

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    help:SetText("Refresh after reproducing. Select All, then Ctrl+C to copy.")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -62)
    scroll:SetPoint("BOTTOMRIGHT", -38, 52)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlightSmall)
    editBox:SetWidth(690)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnTextChanged", function(self)
        local height = self.GetStringHeight and self:GetStringHeight() or 1
        self:SetHeight(math.max(1, height + 12))
    end)
    scroll:SetScrollChild(editBox)
    frame.editBox = editBox

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(92, 24)
    refresh:SetPoint("BOTTOMLEFT", 18, 18)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        D:Refresh121SoulLinkActionSlot()
        updateAll()
        setSoulLinkStatusText()
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, function()
                updateAll()
                setSoulLinkStatusText()
            end)
        end
    end)

    local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAll:SetSize(92, 24)
    selectAll:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    selectAll:SetText("Select All")
    selectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(92, 24)
    close:SetPoint("BOTTOMRIGHT", -18, 18)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    if type(_G.UISpecialFrames) == "table" then
        _G.UISpecialFrames[#_G.UISpecialFrames + 1] = "DecursiveSoulLinkStatusFrame121"
    end
    frame:Hide()
    return frame
end

function D:Show121SoulLinkStatus()
    if not soulLinkStatusFrame then soulLinkStatusFrame = createSoulLinkStatusFrame() end
    updateAll()
    setSoulLinkStatusText()
    soulLinkStatusFrame:Show()
    soulLinkStatusFrame:Raise()
end

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcrsoullinkstatus", function() D:Show121SoulLinkStatus() end)
else
    _G.SLASH_DCRSOULLINKSTATUS1 = "/dcrsoullinkstatus"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.DCRSOULLINKSTATUS = function() D:Show121SoulLinkStatus() end
end

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
    soulLinkActionSlot = nil
    soulLinkActionKind = nil
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
    requestSoulLinkActionSlotRescan()
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
