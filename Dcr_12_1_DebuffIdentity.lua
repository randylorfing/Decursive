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

local WATCHED_UNITS = { "boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus" }
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

local function registerCastEvents(unit)
    watcher:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
end

for _, unit in ipairs(WATCHED_UNITS) do
    registerCastEvents(unit)
end
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")

-- UNIT_SPELLCAST_SUCCEEDED's own event payload already carries spellId
-- (unit, castGUID, spellId), covering instant-cast afflictions that never
-- show a cast bar. UNIT_SPELLCAST_START reads the spellId off the cast
-- bar via UnitCastingInfo instead, matching Dcr_12_1_Encounters.lua.
watcher:SetScript("OnEvent", function(_, event, unit, _, spellId)
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Nameplate unit tokens (nameplate1..40) get reused for different
        -- mobs as they enter/leave visibility; RegisterUnitEvent on the same
        -- token again is harmless, so no unregister-on-remove bookkeeping
        -- is needed.
        if UnitCanAttack("player", unit) then registerCastEvents(unit) end
        return
    end
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
-- exists) -- i.e. DandersFrames integration OFF. With it ON, DandersFrames'
-- own frame already shows this today via the identical mechanism.
--
-- SetMouseClickEnabled(false) + SetMouseMotionEnabled(true) is the specific,
-- separate pair of controls this widget exposes for "hover yes, click no" --
-- needs verifying in-game that click-to-cure on the MUF still works normally
-- with this slot layered on top; that's the one real regression risk here.
----------------------------------------------------------------

-- Originally scoped to dungeons/M+ only ("party" instanceType covers both,
-- IsInInstance() doesn't distinguish the two). Extended to also cover raids
-- ("raid" instanceType) per user request -- same feature, same behavior,
-- just widened to the same content type it already worked in for parties.
local function inDungeonInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

-- Re-enabled with genuine isolation, after a live report that core
-- affliction detection stopped working entirely in the session where this
-- ran. The earlier version added its own aura slot ("zhaohu-identity-
-- tooltip") to MF.ManagedAuraContainer -- the SAME container object the
-- core detection slots live on, not an isolated one -- so even with the
-- taint crash on its follow-up setup calls caught (pcall), the AddAuraSlot
-- call itself still succeeded and still touched that shared container. This
-- version instead builds its own separate AuraContainer, the exact same
-- proven-safe way Dcr_12_1.lua's own core detection container is built
-- (CreateFrame("AuraContainer", ..., "CustomAuraContainerTemplate"),
-- parented to MF.Frame, positioned via container:SetAllPoints(MF.Frame) --
-- that specific call already runs safely there every MUF init). Any failure
-- in this feature now has zero path back to the container core detection
-- depends on.
local function ensureIdentityTooltipSlot(MF)
    if MF.DcrIdentitySlot then return MF.DcrIdentitySlot end
    if not MF or not MF.Frame then return nil end

    local containerOk, container = pcall(CreateFrame, "AuraContainer", nil, MF.Frame, "CustomAuraContainerTemplate")
    if not containerOk or not container then return nil end
    local posOk = pcall(function() container:SetAllPoints(MF.Frame) end)
    if not posOk then return nil end

    local options = {
        -- Confirmed live via BugGrabber: this callback is invoked by
        -- Blizzard's own AddAuraSlot machinery, apparently lazily/later --
        -- NOT synchronously inside the pcall(container.AddAuraSlot, ...)
        -- call below, since the exact same "forbidden object" taint crash
        -- (this time on btn:SetTooltipAnchorPoint/SetHideTooltipInCombat)
        -- still happened even after that call was wrapped. Wrapping the
        -- callback's own body directly so it can't escape protection
        -- regardless of when Blizzard actually calls it.
        initializeFrame = function(btn)
            pcall(function()
                if btn.EnableMouse then btn:EnableMouse(true) end
                if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(false) end
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
    if not addOk or not slot then return nil end

    local setupOk = pcall(function()
        -- Positioned relative to OUR OWN isolated container, not directly to
        -- MF.Frame -- slot:SetAllPoints(MF.Frame) was the exact line that
        -- threw the original taint crash.
        if slot.SetAllPoints then slot:SetAllPoints(container) end
        if slot.SetAlpha then slot:SetAlpha(0) end -- invisible; only its built-in tooltip matters
        if slot.SetFrameLevel and MF.Frame.GetFrameLevel then
            slot:SetFrameLevel(MF.Frame:GetFrameLevel() + 200)
        end
    end)
    if not setupOk then return nil end

    MF.DcrIdentityContainer = container
    MF.DcrIdentitySlot = slot
    return slot
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
        -- MF.ManagedAuraContainer may not exist yet if init happened during
        -- combat lockdown (Dcr_12_1.lua defers native attach in that case);
        -- the PLAYER_REGEN_ENABLED retry below covers that.
        ensureIdentityTooltipSlot(self)
    end
end

-- Retry for MUFs whose native container attach was deferred by combat
-- lockdown at init time (mirrors Dcr_12_1.lua's own providerRetryFrame
-- pattern, decoupled from its private pending-attach table).
local retryFrame = CreateFrame("Frame")
retryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
retryFrame:SetScript("OnEvent", function()
    if not D.MicroUnitF or not D.MicroUnitF.UnitToMUF then return end
    for _, MF in pairs(D.MicroUnitF.UnitToMUF) do
        if MF and not MF.DcrIdentitySlot and MF.ManagedAuraContainer then
            ensureIdentityTooltipSlot(MF)
        end
    end
end)

----------------------------------------------------------------
-- Tooltip extension (fallback): cast-inference guess, used only when the
-- real native tooltip above isn't available (DandersFrames provider active).
----------------------------------------------------------------

if D.MicroUnitF and type(hooksecurefunc) == "function" then
    -- MicroUnitF:OnEnter(frame) is method-call sugar for
    -- MicroUnitF.OnEnter(MicroUnitF, frame) -- hooksecurefunc passes the same
    -- args through, so the real UI frame is the SECOND parameter here, not
    -- the first (the first is MicroUnitF itself).
    hooksecurefunc(D.MicroUnitF, "OnEnter", function(_, frame)
        if not D.profile or not D.profile.AfflictionTooltips then return end

        local MF = frame and frame.Object
        local unit = MF and MF.CurrUnit
        if not unit then return end

        -- (The AuraSlot itself is created at MUF-init time now, not here --
        -- see ensureIdentityTooltipSlot above and its call site further up
        -- this file. Creating it lazily inside this secure OnEnter chain is
        -- what tainted Decursive during earlier testing.)

        local tip = _G.DcrSecretTooltip
        local tracked = D:GetRecentAfflictingCasts()

        -- In a dungeon/M+ with the real native tooltip active for this MUF,
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
        -- Outside this case (open world, or DandersFrames provider active so
        -- no native slot exists), leave Decursive's own tooltip alone and
        -- fall through to the cast-inference guess below.
        if MF.DcrIdentitySlot and inDungeonInstance() then
            if tip then
                tip:ClearLines()
                tip:AddLine(UnitName(unit) or "?", 1, 1, 1)
                tip:ClearAllPoints()
                if UnitAffectingCombat(unit) then
                    tip:SetPoint("TOP", MF.Frame, "BOTTOM", 0, -4)
                else
                    tip:SetPoint("BOTTOM", MF.Frame, "TOP", 0, 4)
                end
                tip:Show()
            end
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
