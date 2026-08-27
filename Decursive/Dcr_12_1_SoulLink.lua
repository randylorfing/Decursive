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
-- A dead ally can normally be battle-rezzed at range (Rebirth, Raise Ally,
-- Intercession, Soulstone all use the player's spell-cast range, which is
-- well beyond melee). Emergency Soul Link (Midnight Engineering item 269586,
-- spell 1259646) is different: it's a 5-yard cast, so relying on it means
-- you have to actually be standing next to the corpse. This module lights
-- the dead player's MUF status dot yellow, persistently, whenever Soul Link
-- is the only rez option available and you're out of its range -- so you
-- notice you need to move in, not just that a rez exists.
--
-- Only engages when there's no other battle-rez charge available: a normal
-- battle-rez in range means Soul Link's shorter range isn't the bottleneck,
-- so no indicator is shown.
local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if type(D) ~= "table" or not DC or not DC.TWELVEONE then return end

-- Druid Rebirth, Death Knight Raise Ally, Paladin Intercession -- the
-- classes with an on-demand, click-a-corpse battle-rez. Warlock Soulstone is
-- deliberately excluded: it's a pre-placement buff cast on a LIVING target
-- before they die, not something castable on a corpse, so it doesn't fit
-- this "click the dead ally" model at all -- shared with DCR_init.lua's
-- macro generation (D:SetMacrosPerPrioTable) so both stay in sync.
DC.BattleRezSpellIDs = DC.BattleRezSpellIDs or { 20484, 61999, 391054 }
local BATTLE_REZ_SPELL_IDS = DC.BattleRezSpellIDs

local SOUL_LINK_SPELL_ID = 1259646
local SOUL_LINK_ITEM_ID = 269586
local canaccessvalue = _G.canaccessvalue or function(_) return true end
local issecretvalue = _G.issecretvalue

local function isAccessiblePublicValue(value)
    if not canaccessvalue(value) then return false end
    return not issecretvalue or not issecretvalue(value)
end

local function accessibleBoolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or not isAccessiblePublicValue(value) then return nil end
    return value and true or false
end

-- C_Spell.GetSpellCharges only reports a real number while in combat; it's
-- nil otherwise (confirmed Blizzard API behavior). Outside combat we can't
-- verify charge count, so assume a known battle-rez is available rather than
-- risk a false "you need Soul Link" indicator between pulls.
local function playerHasBattleRezCharge()
    for _, spellID in ipairs(BATTLE_REZ_SPELL_IDS) do
        local known = false
        if IsPlayerSpell then known = accessibleBoolean(IsPlayerSpell, spellID) end
        if known == nil then return true end
        if known == true then
            local charges
            if C_Spell and C_Spell.GetSpellCharges then
                local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
                if ok and isAccessiblePublicValue(info) and type(info) == "table" then
                    charges = info.currentCharges
                end
            end
            if not isAccessiblePublicValue(charges) or charges == nil then return true end
            if type(charges) == "number" and charges > 0 then return true end
        end
    end
    return false
end

local function soulLinkAvailable()
    if not D.profile or D.profile.SoulLink121Enabled == false then return false end
    local count
    if C_Item and C_Item.GetItemCount then
        local ok, value = pcall(C_Item.GetItemCount, SOUL_LINK_ITEM_ID)
        if ok then count = value end
    elseif GetItemCount then
        local ok, value = pcall(GetItemCount, SOUL_LINK_ITEM_ID)
        if ok then count = value end
    end
    if not isAccessiblePublicValue(count) or type(count) ~= "number" or count < 1 then return false end
    local start, duration
    if C_Item and C_Item.GetItemCooldown then
        local ok, value1, value2 = pcall(C_Item.GetItemCooldown, SOUL_LINK_ITEM_ID)
        if ok then start, duration = value1, value2 end
    elseif GetItemCooldown then
        local ok, value1, value2 = pcall(GetItemCooldown, SOUL_LINK_ITEM_ID)
        if ok then start, duration = value1, value2 end
    end
    if not isAccessiblePublicValue(start) or not isAccessiblePublicValue(duration) then return false end
    if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0 then return false end
    return true
end

-- C_Item.IsItemInRange/IsItemInRange are ADDON_ACTION_BLOCKED from
-- Decursive's tainted execution context (confirmed in-game). C_Spell.
-- IsSpellInRange against the item's underlying spell is the same range
-- check without touching a protected item-specific API -- it's already
-- proven safe elsewhere in this file family (Dcr_12_1.lua's dispel-range
-- check uses it the same way). If it's unavailable, don't guess -- assume
-- in range rather than falsely flag someone as needing to move.
local function soulLinkOutOfRange(unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, result = pcall(C_Spell.IsSpellInRange, SOUL_LINK_SPELL_ID, unit)
        if ok and isAccessiblePublicValue(result) and result ~= nil then return result == false end
    end
    return false
end

-- Remembered so the failed-cast notification below (which only gets a
-- spellID from the game, not a target) can name who you were too far from.
local lastOutOfRangeUnit, lastOutOfRangeCount

local function updateAll()
    if not D.MicroUnitF or not D.MicroUnitF.UnitToMUF then return end

    if not D.profile or D.profile.SoulLink121Enabled == false then
        for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
            if D.Set121MUFSoulLinkRangeActive then D:Set121MUFSoulLinkRangeActive(MF, false) end
        end
        lastOutOfRangeUnit, lastOutOfRangeCount = nil, 0
        return
    end

    local relyingOnSoulLink = not playerHasBattleRezCharge() and soulLinkAvailable()
    lastOutOfRangeUnit, lastOutOfRangeCount = nil, 0

    for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
        local active = false
        local unit = MF and MF.CurrUnit
        local isDead = unit and accessibleBoolean(UnitIsDeadOrGhost, unit)
        local isPlayer = unit and accessibleBoolean(UnitIsUnit, unit, "player")
        local exists = unit and accessibleBoolean(UnitExists, unit)
        if relyingOnSoulLink and unit and exists == true and isDead == true and isPlayer == false then
            active = soulLinkOutOfRange(unit)
            if active then
                lastOutOfRangeCount = lastOutOfRangeCount + 1
                lastOutOfRangeUnit = lastOutOfRangeUnit or unit
            end
        end
        if D.Set121MUFSoulLinkRangeActive then D:Set121MUFSoulLinkRangeActive(MF, active) end
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
watcher:SetScript("OnEvent", updateAll)

-- Range and dead-state both need polling: there's no "moved into range" or
-- "released spirit" event to hook. A 1s tick against a handful of MUFs is
-- cheap.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, updateAll)
end

-----------------------------------------------------------------
-- On-screen Alert warning when the item is actually attempted out of
-- range, on top of the persistent yellow dot -- WoW's own native "Out of
-- range" error doesn't say WHICH ability, so this names Soul Link and the
-- target explicitly. Uses the Alert warning system (DecursiveSoulLinkAlert /
-- /dcralerts), not the notification text window (DecursiveTextFrame).
--
-- UI_ERROR_MESSAGE is the reliable path for this (same pattern Dcr_12_1.lua's
-- own cooldownEvents handler already uses for instant/item-use range
-- failures); UNIT_SPELLCAST_FAILED_QUIET/FAILED are kept as a secondary path
-- in case a given cast reaches a full spell-cast attempt instead. Since
-- UI_ERROR_MESSAGE carries no spellID (its args are actually (errorType,
-- message), not a real unit/castGUID/spellID triple), it can't be filtered
-- by spell -- gated instead on "a dead ally currently needs Soul Link and is
-- out of range" (lastOutOfRangeCount > 0), which keeps it from firing on an
-- unrelated out-of-range error most of the time.
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

local function showAlert()
    if D.profile and D.profile.Alert121SoulLinkEnabled == false then
        if D.AlertDiag then D:AlertDiag("BATTLEREZ alert suppressed by toggle") end
        return
    end
    if not lastOutOfRangeUnit or (lastOutOfRangeCount or 0) < 1 then
        if D.AlertDiag then D:AlertDiag("BATTLEREZ showAlert called but no out-of-range unit tracked") end
        return
    end

    local name = D.UnitName and D:UnitName(lastOutOfRangeUnit) or nil
    if not isAccessiblePublicValue(name) or type(name) ~= "string" then name = "your target" end
    local message = lastOutOfRangeCount > 1
        and ("Battle rez: move within range of %s (and %d other%s)!"):format(
            name, lastOutOfRangeCount - 1, lastOutOfRangeCount - 1 > 1 and "s" or "")
        or ("Battle rez: move within range of %s!"):format(name)

    -- Don't log the full `message` -- it embeds UnitName(lastOutOfRangeUnit),
    -- which can be a secret string in some contexts (same class of issue
    -- fixed in Dcr_12_1_Encounters.lua's cast-name logging), and a secret
    -- value embedded in a logged string silently wipes that whole entry to
    -- nil on SavedVariables save.
    if D.AlertDiag then D:AlertDiag("BATTLEREZ alert firing (count=%d)", lastOutOfRangeCount) end
    showCenterAlert(message)
end

local failWatcher = CreateFrame("Frame")
pcall(failWatcher.RegisterEvent, failWatcher, "UI_ERROR_MESSAGE")
failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
failWatcher:SetScript("OnEvent", function(_, event, arg1, arg2, spellID)
    if event == "UI_ERROR_MESSAGE" then
        -- (errorType, message) here -- see comment above.
        local msg = arg2
        if not isAccessiblePublicValue(arg1) or not isAccessiblePublicValue(msg) then return end
        local isRangeError = (SPELL_FAILED_OUT_OF_RANGE and msg == SPELL_FAILED_OUT_OF_RANGE)
            or (ERR_OUT_OF_RANGE and msg == ERR_OUT_OF_RANGE)
        if isRangeError then
            -- Ground-truth logging: this handler has no way to know WHICH
            -- action actually caused the error (UI_ERROR_MESSAGE carries no
            -- spellID), so it reacts to ANY out-of-range error in the game,
            -- not just Soul Link attempts. Logging the raw errorType/msg
            -- here so a real report of "I was in range" can be checked
            -- against exactly what WoW said, instead of guessing.
            if D.AlertDiag then
                D:AlertDiag("BATTLEREZ saw a range-classified UI_ERROR_MESSAGE (raw errorType=%s msg=%s)",
                    tostring(arg1), tostring(msg))
            end
            showAlert()
        end
        return
    end
    if isAccessiblePublicValue(spellID) and spellID == SOUL_LINK_SPELL_ID then showAlert() end
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
        print(("|cFF29B8A8[Decursive]|r Battle rez %s."):format(
            D.profile.SoulLink121Enabled == false and "disabled" or "enabled"))
        if D.UpdateMacro then D:UpdateMacro() end
        updateAll()
    end)
end
