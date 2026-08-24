--[[
    This file is part of Decursive.

    Local dispellable aura database core. This file was solely written by
    Randy Lorfing.
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

    Each expansion module calls D:RegisterDispelDBExpansion(name, metadata, entries).
--]]

local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" then return end

D.DispelDB = D.DispelDB or { expansions = {}, bySpellID = {}, duplicates = {} }

function D:RegisterDispelDBExpansion(key, meta, entries)
    if type(key) ~= "string" or type(entries) ~= "table" then return end
    local bucket = { key = key, meta = meta or {}, entries = entries }
    self.DispelDB.expansions[key] = bucket
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and type(e.id) == "number" and e.id > 0 then
            e.expansion = e.expansion or key
            if self.DispelDB.bySpellID[e.id] then
                self.DispelDB.duplicates[e.id] = true
            else
                self.DispelDB.bySpellID[e.id] = e
            end
        end
    end
end

function D:GetDispelDBEntry(spellID)
    if _G.issecretvalue and _G.issecretvalue(spellID) then return nil end
    return self.DispelDB and self.DispelDB.bySpellID and self.DispelDB.bySpellID[spellID]
end

function D:GetDispelDBStats()
    local stats = { total = 0, friendly = 0, hostile = 0, expansions = {}, types = {} }
    if not self.DispelDB then return stats end
    for key, bucket in pairs(self.DispelDB.expansions or {}) do
        local s = {
            total = 0, friendly = 0, hostile = 0, types = {},
            order = tonumber(bucket.meta and bucket.meta.order) or 999,
            coverage = tostring(bucket.meta and bucket.meta.coverage or "unknown"),
            notes = bucket.meta and bucket.meta.notes or nil,
        }
        for i = 1, #(bucket.entries or {}) do
            local e = bucket.entries[i]
            s.total = s.total + 1
            local ct = tostring(e.cureType or "UNKNOWN")
            s.types[ct] = (s.types[ct] or 0) + 1
            stats.types[ct] = (stats.types[ct] or 0) + 1
            if e.target == "enemy" then s.hostile = s.hostile + 1 else s.friendly = s.friendly + 1 end
        end
        stats.expansions[key] = s
        stats.total = stats.total + s.total
        stats.friendly = stats.friendly + s.friendly
        stats.hostile = stats.hostile + s.hostile
    end
    return stats
end

function D:GetDispelDBExpansionList()
    local out = {}
    local stats = self:GetDispelDBStats()
    for key, s in pairs(stats.expansions or {}) do
        out[#out + 1] = { key = key, stats = s }
    end
    table.sort(out, function(a, b)
        local ao = a.stats and a.stats.order or 999
        local bo = b.stats and b.stats.order or 999
        if ao == bo then return tostring(a.key) < tostring(b.key) end
        return ao < bo
    end)
    return out
end

function D:PrintDispelDBDiagnostics()
    local stats = self:GetDispelDBStats()
    self:Println(("--- Zhaohu DispelDB: %d entries | %d friendly | %d enemy/purge ---"):format(stats.total or 0, stats.friendly or 0, stats.hostile or 0))
    local list = self:GetDispelDBExpansionList()
    for i = 1, #list do
        local row = list[i]
        local s = row.stats or {}
        self:Println(("%s: %d total | %d friendly | %d enemy | %s"):format(row.key, s.total or 0, s.friendly or 0, s.hostile or 0, s.coverage or "unknown"))
    end
    self:Println("Use /zdsound for current-spec aura-sound registration counts.")
end
