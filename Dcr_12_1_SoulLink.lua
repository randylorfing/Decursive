--[[
    This file is part of Decursive.

    Decursive (v 11.0.10) add-on for World of Warcraft UI
    Copyright (C) 2006-2025 John Wellesz (Decursive AT 2072productions.com) ( http://www.2072productions.com/to/decursive.php )

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

    Decursive is inspired from the original "Decursive v1.9.4" by Patrick Bohnet (Quu).
    The original "Decursive 1.9.4" is in public domain ( www.quutar.com )

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY.

    This file was last updated on 2026-08-22T00:00:00Z
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

-- C_Spell.GetSpellCharges only reports a real number while in combat; it's
-- nil otherwise (confirmed Blizzard API behavior). Outside combat we can't
-- verify charge count, so assume a known battle-rez is available rather than
-- risk a false "you need Soul Link" indicator between pulls.
local function playerHasBattleRezCharge()
    for _, spellID in ipairs(BATTLE_REZ_SPELL_IDS) do
        if IsPlayerSpell and IsPlayerSpell(spellID) then
            local charges
            if C_Spell and C_Spell.GetSpellCharges then
                local info = C_Spell.GetSpellCharges(spellID)
                charges = info and info.currentCharges
            end
            if charges == nil or charges > 0 then return true end
        end
    end
    return false
end

local function soulLinkAvailable()
    if not D.profile or D.profile.SoulLink121Enabled == false then return false end
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(SOUL_LINK_ITEM_ID))
        or (GetItemCount and GetItemCount(SOUL_LINK_ITEM_ID))
    if not count or count < 1 then return false end
    local start, duration
    if C_Item and C_Item.GetItemCooldown then
        start, duration = C_Item.GetItemCooldown(SOUL_LINK_ITEM_ID)
    elseif GetItemCooldown then
        start, duration = GetItemCooldown(SOUL_LINK_ITEM_ID)
    end
    if start and duration and start > 0 and duration > 0 then return false end
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
        if ok and result ~= nil then return result == false end
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
        if relyingOnSoulLink and unit and UnitExists(unit) and UnitIsDeadOrGhost(unit) and not UnitIsUnit(unit, "player") then
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
-- On-screen text notification when the item is actually attempted out of
-- range, on top of the persistent yellow dot -- WoW's own native "Out of
-- range" error doesn't say WHICH ability, so this names Soul Link and the
-- target explicitly. UNIT_SPELLCAST_FAILED_QUIET is what fires for an
-- instant, range-blocked item use; UNIT_SPELLCAST_FAILED is the fallback for
-- anything that reaches a full cast attempt first.
-----------------------------------------------------------------

local failWatcher = CreateFrame("Frame")
failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
failWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
failWatcher:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if spellID ~= SOUL_LINK_SPELL_ID then return end
    if not lastOutOfRangeUnit or (lastOutOfRangeCount or 0) < 1 then return end

    local name = UnitName(lastOutOfRangeUnit) or "your target"
    local message = lastOutOfRangeCount > 1
        and ("Emergency Soul Link: move within range of %s (and %d other%s)!"):format(
            name, lastOutOfRangeCount - 1, lastOutOfRangeCount - 1 > 1 and "s" or "")
        or ("Emergency Soul Link: move within range of %s!"):format(name)

    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
    end
end)

-----------------------------------------------------------------
-- Slash command: /dcrsoullink -- toggles D.profile.SoulLink121Enabled
-- (default on, matching every other profile boolean's nil-is-true idiom
-- used throughout this file family).
-----------------------------------------------------------------

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcrsoullink", function()
        local currentlyEnabled = not D.profile or D.profile.SoulLink121Enabled ~= false
        D.profile.SoulLink121Enabled = not currentlyEnabled
        print(("|cFF29B8A8[Decursive]|r Soul Link %s."):format(
            D.profile.SoulLink121Enabled == false and "disabled" or "enabled"))
        if D.UpdateMacro then D:UpdateMacro() end
        updateAll()
    end)
end
