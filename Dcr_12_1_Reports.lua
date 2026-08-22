-- Zhaohu's Decursive - DCRREPORTS: temporary diagnostic capture for the
-- 12.1 debuff-identification investigation. Writes to its own SavedVariables
-- table (DCRREPORTS_DB) so data survives /reload and can be read directly
-- from disk afterward, instead of relying on chat screenshots.
--
-- This is a throwaway diagnostic tool, not a feature -- delete this file and
-- its Decursive.toc lines once the investigation is done.
local addonName, T = ...
local D = T and T.Dcr
if type(D) ~= "table" then return end

DCRREPORTS_DB = DCRREPORTS_DB or { events = {}, hovers = {} }
local db = DCRREPORTS_DB
db.events = db.events or {}
db.hovers = db.hovers or {}

local MAX_ENTRIES = 300
local issecretvalue = _G.issecretvalue

local function safe(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    if v == nil then return "<nil>" end
    return tostring(v)
end

local function push(list, entry)
    table.insert(list, entry)
    if #list > MAX_ENTRIES then table.remove(list, 1) end
end

----------------------------------------------------------------
-- Combat log: capture every aura event, unfiltered by unit, with full
-- raw-value diagnostics (type, secret-wrapped or not) per field.
----------------------------------------------------------------

local AURA_SUB = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REFRESH = true,
    SPELL_AURA_REMOVED = true, SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true,
}

-- CONCLUSION (confirmed via repeated in-game testing, multiple timing
-- strategies, with !BugGrabber): RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
-- throws ADDON_ACTION_FORBIDDEN for this addon specifically, unconditionally.
-- Not a combat-timing issue -- reproduced with InCombatLockdown() false and
-- from an async callback seconds after load. Every other addon's combat log
-- access works fine; likely tied to Decursive's secure click-cast MUF
-- template (see Dcr_12_1_DebuffIdentity.lua for the full writeup). This is
-- an addon-level restriction, not fixable by retrying -- intentionally never
-- registered below. db.events stays permanently empty; db.hovers (proven
-- working, 18 real captures during testing) is unaffected.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function()
    local ok, _, subevent, _, sourceGUID, sourceName, _, destGUID, destName, _, _, spellId, spellName, spellSchool =
        pcall(CombatLogGetCurrentEventInfo)

    if not ok then
        push(db.events, { t = GetTime(), sub = "LUA_ERROR", err = safe(subevent) })
        return
    end
    if not AURA_SUB[subevent] then return end

    push(db.events, {
        t = GetTime(),
        sub = subevent,
        srcName = safe(sourceName),
        destName = safe(destName),
        destGUID = safe(destGUID),
        spellId = safe(spellId),
        spellIdType = type(spellId),
        spellIdSecret = safe(issecretvalue and issecretvalue(spellId)),
        spellName = safe(spellName),
        spellSchool = safe(spellSchool),
    })
end)

----------------------------------------------------------------
-- MUF hover: capture unit/GUID/status/debuff-count at the moment of hover,
-- to correlate against combat log entries by timestamp.
----------------------------------------------------------------

if D.MicroUnitF and type(hooksecurefunc) == "function" then
    -- MicroUnitF:OnEnter(frame) is method-call sugar, so hooksecurefunc's
    -- hook receives (MicroUnitF, frame) -- the real frame is the 2nd arg.
    hooksecurefunc(D.MicroUnitF, "OnEnter", function(_, frame)
        local MF = frame and frame.Object
        local unit = MF and MF.CurrUnit
        if not unit then return end

        push(db.hovers, {
            t = GetTime(),
            unit = safe(unit),
            guid = safe(UnitGUID(unit)),
            unitStatus = MF.UnitStatus and safe(MF.UnitStatus) or "?",
            debuffCount = MF.Debuffs and #MF.Debuffs or 0,
            -- Snapshot of Dcr_12_1_DebuffIdentity.lua's cast-inference data at
            -- this exact hover, to tell apart "no cast data captured at all"
            -- from "data exists but the tooltip isn't showing it".
            recentCastsCount = (D.GetRecentAfflictingCasts and #D:GetRecentAfflictingCasts()) or -1,
            recentCastsDump = D.GetRecentAfflictingCasts and (function()
                local parts = {}
                for _, c in ipairs(D:GetRecentAfflictingCasts()) do
                    parts[#parts + 1] = safe(("%s/%s/%ds"):format(c.name, c.npc, math.floor(GetTime() - c.t)))
                end
                return table.concat(parts, " | ")
            end)() or "no-function",
        })
    end)
end

----------------------------------------------------------------
-- Slash command: /dcrreports [clear]
----------------------------------------------------------------

if D.RegisterChatCommand then
    D:RegisterChatCommand("dcrreports", function(msg)
        if msg == "clear" then
            wipe(db.events)
            wipe(db.hovers)
            print("|cFF29B8A8[DCRREPORTS]|r cleared. /reload to persist.")
        else
            print(("|cFF29B8A8[DCRREPORTS]|r %d aura events, %d hover events captured. /reload to save to disk."):format(
                #db.events, #db.hovers))
        end
    end)
end
