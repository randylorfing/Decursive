-- Zhaohu's Decursive - local encounter mechanic database core
-- Tracks enemy-cast mechanics (interrupts, purges, tank busters) that fall
-- outside the friendly-debuff scope of DispelDB_Core.lua. Each dungeon module
-- calls D:RegisterEncounterDBExpansion(name, metadata, entries).
--
-- This is deliberately a SEPARATE table from DispelDB: a dispel is something
-- on YOUR party that you cure; an encounter entry is an ENEMY cast you react
-- to (interrupt/purge/positioning). Where a mechanic is both (e.g. an
-- uninterrupted cast that applies a curable debuff), the encounter entry's
-- `seeDispel` field points at the DispelDB spellId rather than duplicating
-- cureType data in two places.
local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" then return end

D.EncounterDB = D.EncounterDB or { expansions = {}, bySpellID = {}, duplicates = {} }

function D:RegisterEncounterDBExpansion(key, meta, entries)
    if type(key) ~= "string" or type(entries) ~= "table" then return end
    local bucket = { key = key, meta = meta or {}, entries = entries }
    self.EncounterDB.expansions[key] = bucket
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and type(e.spellId) == "number" and e.spellId > 0 then
            e.expansion = e.expansion or key
            if self.EncounterDB.bySpellID[e.spellId] then
                self.EncounterDB.duplicates[e.spellId] = true
            else
                self.EncounterDB.bySpellID[e.spellId] = e
            end
        end
    end
end

function D:GetEncounterDBEntry(spellId)
    return self.EncounterDB and self.EncounterDB.bySpellID and self.EncounterDB.bySpellID[spellId]
end
