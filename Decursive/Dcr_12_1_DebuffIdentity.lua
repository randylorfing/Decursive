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
-- Zhaohu's Decursive - debuff identification via enemy-cast inference (12.1-safe)
--
-- CONFIRMED (this session, via repeated in-game testing): no addon with a
-- secure click-cast frame -- Decursive included -- can read a debuff's real
-- identity in this content, through ANY API. Blizzard's own error message,
-- hit by DandersFrames' C_UnitAuras.GetUnitAuras() (a different, newer API
-- than the one Decursive tried) says it outright: "Auras cannot be accessed
-- when secret while tainted by 'DandersFrames'." Combat log access
-- (COMBAT_LOG_EVENT_UNFILTERED) is ALSO unconditionally blocked for this
-- addon specifically (ADDON_ACTION_FORBIDDEN, reproduced regardless of
-- combat timing) -- see git history for that dead end. This is a Blizzard
-- design decision, not a bug: any secure-click addon is tainted, and secret
-- auras cannot be read by tainted code, full stop.
--
-- What's never protected: the enemy's own cast. UNIT_SPELLCAST_START on a
-- boss/target unit is plain public data, and Dcr_12_1_Encounters.lua already
-- proves this works reliably all session (the interrupt alerts). So instead
-- of reading the debuff, this module watches the CAUSE: when a nearby enemy
-- casts a spell that's in the dispel/encounter database, it remembers
-- "NPC X just cast Y" with a timestamp. When you hover a MUF with an active
-- affliction shortly after, that's shown as a best guess -- an inference,
-- not a read. Ambiguous when two different afflicting casts land close
-- together; usually clear in a 5-man pull.
local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if type(D) ~= "table" or not DC or not DC.TWELVEONE then return end

local WATCHED_UNITS = {
    boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
    target = true, focus = true,
}
local RECENT_WINDOW = 12 -- seconds; how long a cast stays a plausible guess
local MAX_RECENT = 20

local recentCasts = {} -- array of { spellId, name, npc, dungeon, cureType, t }

local function pruneRecentCasts()
    local now = GetTime()
    local i = 1
    while i <= #recentCasts do
        if now - recentCasts[i].t > RECENT_WINDOW then
            table.remove(recentCasts, i)
        else
            i = i + 1
        end
    end
end

local function lookupAfflictingSpell(spellId)
    local dispelEntry = D.GetDispelDBEntry and D:GetDispelDBEntry(spellId)
    if dispelEntry and dispelEntry.target == "friendly" then
        return dispelEntry.name, dispelEntry.content, dispelEntry.cureType
    end
    local encEntry = D.GetEncounterDBEntry and D:GetEncounterDBEntry(spellId)
    if encEntry and encEntry.seeDispel then
        local seen = D.GetDispelDBEntry and D:GetDispelDBEntry(encEntry.seeDispel)
        if seen then return seen.name, seen.content or encEntry.dungeon, seen.cureType end
    end
    return nil
end

local function recordCast(unit, spellId)
    local name, dungeon, cureType = lookupAfflictingSpell(spellId)
    if not name then return end

    pruneRecentCasts()
    table.insert(recentCasts, 1, {
        spellId = spellId, name = name, npc = UnitName(unit) or "?",
        dungeon = dungeon, cureType = cureType, t = GetTime(),
    })
    if #recentCasts > MAX_RECENT then table.remove(recentCasts) end
end

-- Confirmed via testing: boss1-5/target/focus alone missed a real case
-- (Paralyzing Shots from Twinfang Harrower -- trash, not a designated
-- "boss" unit token, and not necessarily whoever's target/focus at that
-- moment). Trash in a busy pull is the normal case for M+, not the
-- exception, so nameplates are the real fix -- the same pattern DBM/
-- TidyPlates use to see every nearby enemy, not just the current target.
local watcher = CreateFrame("Frame")

local function isWatchedCastUnit(unit)
    if type(unit) ~= "string" then return false end
    if WATCHED_UNITS[unit] then
        return not UnitCanAttack or UnitCanAttack("player", unit)
    end
    if unit:match("^nameplate%d+$") then
        return not UnitCanAttack or UnitCanAttack("player", unit)
    end
    return false
end

-- RegisterUnitEvent replaces the unit filter for an already-registered event.
-- Use the ordinary events once and filter the public unit token in Lua so boss,
-- target, focus and every active nameplate can all be observed concurrently.
watcher:RegisterEvent("UNIT_SPELLCAST_START")
watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- UNIT_SPELLCAST_SUCCEEDED's own event payload already carries spellId
-- (unit, castGUID, spellId), covering instant-cast afflictions that never
-- show a cast bar. UNIT_SPELLCAST_START reads the spellId off the cast
-- bar via UnitCastingInfo instead, matching Dcr_12_1_Encounters.lua.
watcher:SetScript("OnEvent", function(_, event, unit, _, spellId)
    if not isWatchedCastUnit(unit) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if spellId then recordCast(unit, spellId) end
        return
    end
    if not UnitExists(unit) then return end
    local _, _, _, _, _, _, _, _, castSpellId = UnitCastingInfo(unit)
    if castSpellId then recordCast(unit, castSpellId) end
end)

function D:GetRecentAfflictingCasts()
    pruneRecentCasts()
    return recentCasts
end

----------------------------------------------------------------
-- Real identification: modeled directly on DandersFrames' own mechanism
-- (confirmed in-game and in their source, AuraContainer.lua:1016-1018).
-- Their aura icons aren't Lua reading the debuff -- hovering one triggers
-- Blizzard's OWN built-in tooltip on the native AuraButton widget itself
-- (slot:SetTooltipAnchorPoint(...) / slot:SetHideTooltipInCombat(...)),
-- which renders name/damage/duration client-side without any addon code
-- touching the secret data. Decursive already creates the same kind of
-- native AuraSlot for its own detection (Dcr_12_1.lua's
-- MF.ManagedAuraContainer) -- it just has mouse fully disabled on every one.
-- This adds ONE dedicated, invisible extra slot purely for the tooltip,
-- leaving every existing detection/coloring slot untouched.
--
-- Only available when Decursive owns native detection (MF.ManagedAuraContainer
-- exists). Cast-inference below is the fallback when this slot is missing.
--
-- The slot enables mouse motion for Blizzard's tooltip but explicitly disables
-- click handling and passes all cure-button clicks through to the secure MUF.
----------------------------------------------------------------

-- Native identity tooltip is dungeon/raid only ("party" covers normal + M+;
-- "raid" covers raids). Explicitly excluded: open world, PvP, arena -- those
-- keep no identity tooltip (PvP overlay correlated with priority squares failing).
local function inDungeonOrRaid()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function isIdentityTooltipAllowed()
    if D.Is121PvPRestrictedMode and D:Is121PvPRestrictedMode() then
        return false
    end
    return inDungeonOrRaid()
end

local function setIdentityTooltipInteractive(MF, enabled)
    local slot = MF and MF.DcrIdentitySlot
    if not slot then return end
    pcall(function()
        if slot.EnableMouse then slot:EnableMouse(enabled and true or false) end
        if slot.SetMouseClickEnabled then slot:SetMouseClickEnabled(false) end
        if slot.SetPropagateMouseClicks then slot:SetPropagateMouseClicks(true) end
        if slot.SetPassThroughButtons then
            slot:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
        end
        if slot.SetMouseMotionEnabled then slot:SetMouseMotionEnabled(enabled and true or false) end
    end)
end

local function disableIdentityTooltipSlot(MF)
    if not MF then return end
    setIdentityTooltipInteractive(MF, false)
    local container = MF.DcrIdentityContainer
    if container then
        if container.SetEnabled then pcall(container.SetEnabled, container, false) end
        if container.Hide then pcall(container.Hide, container) end
    end
end

-- Isolated AuraContainer (not the detection container) so failures cannot
-- touch core dispel detection. Positioning of the AuraSlot button must happen
-- inside Blizzard's initializeFrame callback -- same proven pattern as
-- Dcr_12_1.lua priority/verification carriers.
local function ensureIdentityTooltipSlot(MF)
    if MF.DcrIdentitySlot then
        if isIdentityTooltipAllowed() then
            setIdentityTooltipInteractive(MF, true)
            local container = MF.DcrIdentityContainer
            if container then
                if container.SetEnabled then pcall(container.SetEnabled, container, true) end
                if container.Show then pcall(container.Show, container) end
            end
        else
            disableIdentityTooltipSlot(MF)
        end
        return MF.DcrIdentitySlot
    end
    if not MF or not MF.Frame then return nil end
    if not isIdentityTooltipAllowed() then return nil end

    local _, instanceType = IsInInstance()
    local unitName = MF.CurrUnit and (UnitName(MF.CurrUnit) or MF.CurrUnit) or "?"
    local anchor = MF.Frame

    local containerOk, container = pcall(CreateFrame, "AuraContainer", nil, MF.Frame, "CustomAuraContainerTemplate")
    if not containerOk or not container then
        if D.AlertDiag then D:AlertDiag("IdentitySlot FAIL %s [%s]: CreateFrame AuraContainer failed: %s", unitName, tostring(instanceType), tostring(container)) end
        return nil
    end
    local posOk = pcall(function() container:SetAllPoints(MF.Frame) end)
    if not posOk then
        if D.AlertDiag then D:AlertDiag("IdentitySlot FAIL %s [%s]: container:SetAllPoints failed", unitName, tostring(instanceType)) end
        return nil
    end

    local options = {
        initializeFrame = function(btn)
            pcall(function()
                -- Cover the MUF so hover triggers Blizzard's native tooltip.
                -- Do not raise frame level aggressively; that previously hid
                -- priority-color paints in PvP experiments.
                if anchor then
                    if btn.ClearAllPoints then btn:ClearAllPoints() end
                    if btn.SetAllPoints then btn:SetAllPoints(anchor) end
                end
                if btn.EnableMouse then btn:EnableMouse(true) end
                if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(false) end
                if btn.SetPropagateMouseClicks then btn:SetPropagateMouseClicks(true) end
                if btn.SetPassThroughButtons then
                    btn:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
                end
                if btn.SetMouseMotionEnabled then btn:SetMouseMotionEnabled(true) end
                if btn.SetTooltipAnchorPoint and btn.SetHideTooltipInCombat then
                    btn:SetTooltipAnchorPoint("ANCHOR_RIGHT", 8, 0)
                    btn:SetHideTooltipInCombat(false)
                end
            end)
        end,
    }
    -- Toggle: D.profile.DcrIdentityShowAllDebuffs (default false, dispellable
    -- only). "HARMFUL" is a strict superset of "HARMFUL|RAID_PLAYER_DISPELLABLE"
    -- (every dispellable debuff is already harmful), so this just widens or
    -- narrows the same one slot rather than adding a second overlapping one.
    -- Baked in at slot-creation time -- /reload to apply after toggling.
    local filter = (D.profile and D.profile.DcrIdentityShowAllDebuffs)
        and "HARMFUL" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
    local addOk, slot = pcall(container.AddAuraSlot, container,
        "zhaohu-identity-tooltip", filter, options)
    if not addOk or not slot then
        if D.AlertDiag then D:AlertDiag("IdentitySlot FAIL %s [%s]: AddAuraSlot failed: %s", unitName, tostring(instanceType), tostring(slot)) end
        return nil
    end

    MF.DcrIdentityContainer = container
    MF.DcrIdentitySlot = slot

    local unit = MF.CurrUnit
    if container.SetUnit and unit then
        pcall(container.SetUnit, container, unit)
    end
    if container.SetEnabled then pcall(container.SetEnabled, container, true) end
    if container.Show then pcall(container.Show, container) end
    if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end

    if D.AlertDiag then D:AlertDiag("IdentitySlot OK %s [%s]", unitName, tostring(instanceType)) end
    return slot
end

local function refreshIdentityTooltipUnit(MF)
    if not isIdentityTooltipAllowed() then return end
    if not MF or not MF.DcrIdentityContainer or not MF.CurrUnit then return end
    local container = MF.DcrIdentityContainer
    if container.SetUnit then
        pcall(container.SetUnit, container, MF.CurrUnit)
    end
    if container.UpdateAllAuras then
        pcall(container.UpdateAllAuras, container)
    end
end

-- When the native identity AuraSlot is active, Decursive's affliction tooltip
-- becomes a compact class-colored name label on the MUF (same name styling as
-- ShowMUFToolTip's first line). Blizzard's own tooltip carries debuff identity.
local function showMUFNameLabel(MF, unit, tip)
    if not tip or not MF or not MF.Frame or not unit then return end
    local GetRaidTargetIndex = _G.GetRaidTargetIndex
    local index = GetRaidTargetIndex and GetRaidTargetIndex(unit)
    local icon = index and string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t ", index) or ""
    local _, className
    if D.GetUnitClassSafe then
        _, className = D:GetUnitClassSafe(unit)
    else
        _, className = UnitClass(unit)
    end
    local coloredUnitName = D:ColorTextNA(
        (D:PetUnitName(unit, true)),
        (className and DC.HexClassColor[className] or "AAAAAA")
    )
    tip:ClearLines()
    tip:AddLine(string.format("%s %s", icon, coloredUnitName))
    tip:ClearAllPoints()
    if UnitAffectingCombat(unit) then
        tip:SetPoint("TOP", MF.Frame, "BOTTOM", 0, -4)
    else
        tip:SetPoint("BOTTOM", MF.Frame, "TOP", 0, 4)
    end
    tip:Show()
end

local function enableIdentityTooltipSlot(MF)
    if not MF or not MF.DcrIdentityContainer then return end
    local container = MF.DcrIdentityContainer
    if container.SetEnabled then pcall(container.SetEnabled, container, true) end
    if container.Show then pcall(container.Show, container) end
    setIdentityTooltipInteractive(MF, true)
    refreshIdentityTooltipUnit(MF)
end

local function refreshIdentityTooltipSlots()
    if not D.MicroUnitF or not D.MicroUnitF.UnitToMUF then return end
    local want = isIdentityTooltipAllowed()
    for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
        if MF then
            if want then
                ensureIdentityTooltipSlot(MF)
                enableIdentityTooltipSlot(MF)
            else
                disableIdentityTooltipSlot(MF)
            end
        end
    end
end

function D:Refresh121IdentityTooltipUnit(MF)
    refreshIdentityTooltipUnit(MF)
end

-- Corrected creation point (previous attempt tainted Decursive by creating
-- the slot lazily inside the secure MUF's OnEnter chain -- see the entry
-- higher in this file's history). MicroUnitF.prototype.init runs once per
-- MUF during normal roster setup, never inside a secure script chain --
-- Dcr_12_1.lua's OWN attachManagedAura() call already uses this exact same
-- plain-reassignment pattern to wire up MF.ManagedAuraContainer, so wrapping
-- it again here follows an already-proven-safe convention rather than
-- inventing a new one.
if D.MicroUnitF and D.MicroUnitF.prototype and D.MicroUnitF.prototype.init then
    local previousInit = D.MicroUnitF.prototype.init
    D.MicroUnitF.prototype.init = function(self, Container, Unit, FrameNum, ID)
        previousInit(self, Container, Unit, FrameNum, ID)
        -- Only attaches in dungeon/raid; open world / PvP skip until zone change.
        ensureIdentityTooltipSlot(self)
    end
end

-- Retry after combat, and create/disable on zone transitions (MUFs often
-- init in open world before you enter a dungeon or raid).
local retryFrame = CreateFrame("Frame")
retryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
retryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
retryFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
retryFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 1.0 or 0.20, refreshIdentityTooltipSlots)
        return
    end
    refreshIdentityTooltipSlots()
end)

----------------------------------------------------------------
-- Tooltip extension (fallback): cast-inference guess, dungeon/raid only
-- when the native identity slot is unavailable. Disabled in PvP.
----------------------------------------------------------------

if D.MicroUnitF and type(hooksecurefunc) == "function" then
    -- MicroUnitF:OnEnter(frame) is method-call sugar for
    -- MicroUnitF.OnEnter(MicroUnitF, frame) -- hooksecurefunc passes the same
    -- args through, so the real UI frame is the SECOND parameter here, not
    -- the first (the first is MicroUnitF itself).
    hooksecurefunc(D.MicroUnitF, "OnEnter", function(_, frame)
        if not D.profile or not D.profile.AfflictionTooltips then return end
        if not isIdentityTooltipAllowed() then return end

        local MF = frame and frame.Object
        local unit = MF and MF.CurrUnit
        if not unit then return end

        -- (The AuraSlot itself is created at MUF-init time now, not here --
        -- see ensureIdentityTooltipSlot above and its call site further up
        -- this file. Creating it lazily inside this secure OnEnter chain is
        -- what tainted Decursive during earlier testing.)

        local tip = _G.DcrSecretTooltip
        local tracked = D:GetRecentAfflictingCasts()

        -- In a dungeon/raid with the real native tooltip active for this MUF,
        -- repurpose Decursive's own tooltip into a small name label instead
        -- of showing its normal generic content -- can't inject a line into
        -- the native tooltip itself (that's a separate, Blizzard-rendered
        -- window; touching it risks the same taint class of issue as
        -- reading from it), but repositioning our OWN tooltip is safe, since
        -- it's addon-owned with no secret data involved. Anchored BELOW the
        -- square while the HOVERED UNIT (not the local player) is in
        -- combat -- UnitAffectingCombat(unit), not InCombatLockdown(), since
        -- the latter is the local player's own personal combat flag and can
        -- read false even while a party member you're hovering is actively
        -- fighting right next to you (confirmed in testing: InCombatLockdown
        -- stayed on "top" mid-fight because the player personally hadn't
        -- just acted). ABOVE the square when that unit is out of combat.
        -- Outside this case (open world, PvP, or no native identity slot),
        -- leave Decursive's own tooltip alone and fall through to the
        -- cast-inference guess below.
        if MF.DcrIdentitySlot then
            -- Native Blizzard tooltip = debuff identity. Decursive tooltip = name label only.
            showMUFNameLabel(MF, unit, tip)
            return
        end

        if not tracked or not tracked[1] then return end

        if not tip or not tip:IsShown() then return end

        tip:AddLine(" ")
        tip:AddLine("|cFF29B8A8Best guess (recent enemy casts, not a read):|r")
        for i = 1, math.min(3, #tracked) do
            local c = tracked[i]
            local age = math.floor(GetTime() - c.t)
            tip:AddLine(("%s  |cFF6B7686(%s, spellID %d, %ds ago)|r"):format(c.name, c.npc, c.spellId, age))
        end
        tip:Show()
    end)
end

----------------------------------------------------------------
-- Slash command: /dcridentity [alldebuffs] -- toggles
-- D.profile.DcrIdentityShowAllDebuffs. Baked into the AuraSlot at MUF-init
-- time, so this only takes effect after /reload.
----------------------------------------------------------------

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcridentity", function(msg)
        if msg == "alldebuffs" then
            D.profile.DcrIdentityShowAllDebuffs = not D.profile.DcrIdentityShowAllDebuffs
            print(("|cFF29B8A8[Decursive]|r Native tooltip will show %s. /reload to apply."):format(
                D.profile.DcrIdentityShowAllDebuffs and "ALL harmful debuffs" or "dispellable debuffs only"))
        else
            print(("|cFF29B8A8[Decursive]|r Currently showing %s. /dcridentity alldebuffs to toggle."):format(
                (D.profile and D.profile.DcrIdentityShowAllDebuffs) and "ALL harmful debuffs" or "dispellable debuffs only"))
        end
    end)
end
