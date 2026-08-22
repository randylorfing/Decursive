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
