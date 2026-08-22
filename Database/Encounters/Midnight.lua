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
local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterEncounterDBExpansion) ~= "function" then return end

D:RegisterEncounterDBExpansion("Midnight", {
    order = 11,
    retail = true,
    coverage = "season2-interrupts",
    notes = "Season 2 (12.1) priority interrupts across all 8 M+ dungeons. Every entry is a `spell_id` (the CAST, not the resulting aura) from the 2026-08-22 'Midnight S2 Mythic+ Mechanics Verified' dataset, filtered to interruptible=True rows with id_verification=verified_live_wowhead (Method.gg ability tracker + live Wowhead spell records) -- the dataset's own accuracy policy is 'verified beats complete, no numeric IDs are guessed.' Altar of Fangs' 4 entries additionally spot-checked directly against wowhead.com. Where a missed interrupt results in a friendly-curable debuff already in Database/Dispels/Midnight.lua, `seeDispel` points at it instead of duplicating cureType data; Addle Mind (Temple of Sethraliss) is flagged as a known dispel-DB gap rather than guessed. This is priority-interrupt coverage only -- purges, soothes and tank busters are a separate future pass, not included here. Dungeon-name spelling (\"Kings' Rest\") matches the existing dispel DB/GetInstanceInfo() detection key, not the dataset's \"King's Rest\".",
}, {
    -- ===== Altar of Fangs (Rav'i -> The Writhing Coil -> Zul'jan) =====

    {
        spellId = 1307571, name = "Envenom", npc = "High Evolutionist", dungeon = "Altar of Fangs",
        encounter = "Writhing Coil trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt. If it lands, the resulting Poison is already tracked as a friendly dispel.",
        seeDispel = 1307571, -- same spellId is already a verified POISON entry in Database/Dispels/Midnight.lua:19
        verified = true, source = "Wowhead spell=1307571 (verified_live_wowhead) + Method.gg Altar of Fangs ability tracker; matches Database/Dispels/Midnight.lua's independently-verified POISON entry",
    },
    {
        spellId = 1294557, name = "Piercing Hiss", npc = "Primal Serpent", dungeon = "Altar of Fangs",
        encounter = "Rav'i trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt. Do not allow repeated casts.",
        verified = true, source = "Wowhead spell=1294557 spot-checked directly (name confirmed) + Method.gg Altar of Fangs ability tracker",
    },
    {
        spellId = 1310358, name = "Toxic Atrophy", npc = "The Writhing Coil / Uncoiled Writhes", dungeon = "Altar of Fangs",
        encounter = "The Writhing Coil", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Boss casts this 3x in a row -- keep an interrupt rotation, stacking DoT if missed.",
        verified = true, source = "Wowhead spell=1310358 (verified_live_wowhead) + Method.gg The Writhing Coil ability tracker",
    },
    {
        spellId = 1307567, name = "Mass Envenom", npc = "Ula'tek's Chosen", dungeon = "Altar of Fangs",
        encounter = "Zul'jan trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt. If missed, the resulting Poison becomes a dispel target.",
        verified = true, source = "Wowhead spell=1307567 spot-checked directly (name confirmed, tagged Buff/exact school unresolved) + Method.gg Zul'jan ability tracker",
    },

    -- ===== Murder Row (Kystia Manaheart -> Zaen Bladesorrow -> Xathuux the Annihilator -> Lithiel Cinderfury) =====

    {
        spellId = 1264106, name = "Felstorm", npc = "Kystia Mirror Image", dungeon = "Murder Row",
        encounter = "Kystia Manaheart", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt on the Mirror Images.",
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker",
    },
    {
        spellId = 474375, name = "Chaos Bolt", npc = "Lithiel Cinderfury", dungeon = "Murder Row",
        encounter = "Lithiel Cinderfury", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Must interrupt. Keep an interrupt rotation.",
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker",
    },
    {
        spellId = 1216570, name = "Fel Missiles", npc = "Felonious Mage", dungeon = "Murder Row",
        encounter = "Kystia trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC the channel.",
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker",
    },
    {
        spellId = 1201554, name = "Seduction", npc = "Seductive Sayaad", dungeon = "Murder Row",
        encounter = "Kystia trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC. If missed, the resulting Magic disorient is already tracked as a friendly dispel.",
        seeDispel = 1201554, -- verified friendly MAGIC entry, Database/Dispels/Midnight.lua:35
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker; cross-checked against Database/Dispels/Midnight.lua's independently-verified MAGIC entry",
    },
    {
        spellId = 1214980, name = "Health Funnel", npc = "Fel Invoker", dungeon = "Murder Row",
        encounter = "Xathuux trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC the channel -- it heals its target while draining the caster.",
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker",
    },
    {
        spellId = 1214922, name = "Fel Rage", npc = "Wrathguard Flayer", dungeon = "Murder Row",
        encounter = "Xathuux trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt, or soothe the resulting Enrage/CC-immunity if missed.",
        verified = true, source = "verified_live_wowhead + Method.gg Murder Row ability tracker",
    },

    -- ===== Den of Nalorakk (The Hoardmonger -> Sentinel of Winter -> Nalorakk) =====

    {
        spellId = 1235829, name = "Winter's Shroud", npc = "Fractured Shivercore", dungeon = "Den of Nalorakk",
        encounter = "Sentinel of Winter", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt. Stacks increase Frost damage taken -- do not let it accumulate.",
        verified = true, source = "verified_live_wowhead + Method.gg Den of Nalorakk ability tracker",
    },
    {
        spellId = 1297696, name = "Healing Breeze", npc = "Earthwhisper Tender", dungeon = "Den of Nalorakk",
        encounter = "Hoardmonger trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt. If missed, purge the enemy healing buff -- this is not a friendly dispel.",
        -- deliberately no seeDispel: Database/Dispels/Midnight.lua:45 has this as target=enemy/ENEMYMAGIC, not a friendly cure
        verified = true, source = "verified_live_wowhead + Method.gg Den of Nalorakk ability tracker",
    },
    {
        spellId = 1239352, name = "Scavenge", npc = "Keen-Eyed Striker", dungeon = "Den of Nalorakk",
        encounter = "Hoardmonger trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt near the berry bushes, or an offering gets stolen.",
        verified = true, source = "verified_live_wowhead + Method.gg Den of Nalorakk ability tracker",
    },
    {
        spellId = 1297778, name = "Arc Lightning", npc = "Stormbound Mystic", dungeon = "Den of Nalorakk",
        encounter = "Nalorakk trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg Den of Nalorakk ability tracker",
    },
    {
        spellId = 1309919, name = "Frigid Roar", npc = "Frigid Mauler", dungeon = "Den of Nalorakk",
        encounter = "Sentinel trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg Den of Nalorakk ability tracker",
    },

    -- ===== The Blinding Vale (Lightblossom Trinity/Ikuzz -> Lightwarden Ruia -> Ziekket) =====

    {
        spellId = 1235616, name = "Light Bolt", npc = "Lightblossom Trinity (Kezkitt)", dungeon = "The Blinding Vale",
        encounter = "Lightblossom Trinity", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt rotation.",
        verified = true, source = "verified_live_wowhead + Method.gg The Blinding Vale ability tracker",
    },
    {
        spellId = 1239821, name = "Warden's Wrath", npc = "Lightwarden Ruia", dungeon = "The Blinding Vale",
        encounter = "Lightwarden Ruia", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg The Blinding Vale ability tracker",
    },
    {
        spellId = 1247669, name = "Lightspore Shot", npc = "Ziekket adds", dungeon = "The Blinding Vale",
        encounter = "Ziekket", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt/CC casts.",
        verified = true, source = "verified_live_wowhead + Method.gg The Blinding Vale ability tracker",
    },
    {
        spellId = 1238294, name = "Disorienting Screech", npc = "Lightfeather Petalwing", dungeon = "The Blinding Vale",
        encounter = "Opening trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg The Blinding Vale ability tracker",
    },
    {
        spellId = 1301834, name = "Light Bolt Volley", npc = "Radiant Spellsower", dungeon = "The Blinding Vale",
        encounter = "Opening trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Must interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg The Blinding Vale ability tracker",
    },

    -- ===== Voidscar Arena (Taz'Rah -> Atroxus -> Charonus) =====

    {
        spellId = 1233398, name = "Mass Shriek", npc = "Killvore Screamer", dungeon = "Voidscar Arena",
        encounter = "Atroxus trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt -- AoE fear if missed.",
        verified = true, source = "verified_live_wowhead + Method.gg Voidscar Arena ability tracker",
    },
    {
        spellId = 1310324, name = "Mending Void", npc = "Voidminder", dungeon = "Voidscar Arena",
        encounter = "Charonus trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC the healing channel.",
        verified = true, source = "verified_live_wowhead + Method.gg Voidscar Arena ability tracker",
    },
    {
        spellId = 1298899, name = "Demoralizing Shout", npc = "Dominated Brawler", dungeon = "Voidscar Arena",
        encounter = "Opening trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt -- applies a harmful debuff if missed.",
        verified = true, source = "verified_live_wowhead + Method.gg Voidscar Arena ability tracker",
    },
    {
        spellId = 1299938, name = "Shadowbolt Volley", npc = "Voidtouched Magi", dungeon = "Voidscar Arena",
        encounter = "Opening trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt every cast.",
        verified = true, source = "verified_live_wowhead + Method.gg Voidscar Arena ability tracker",
    },

    -- ===== Ruby Life Pools (Melidrussa Chillworn -> Kokia Blazehoof -> Kyrakka & Erkhart Stormvein) =====

    {
        spellId = 373017, name = "Blaze Volley", npc = "Blazebound Firestorm", dungeon = "Ruby Life Pools",
        encounter = "Kokia Blazehoof", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg Ruby Life Pools ability tracker",
    },
    {
        spellId = 372808, name = "Frigid Shard", npc = "Melidrussa Chillworn", dungeon = "Ruby Life Pools",
        encounter = "Melidrussa Chillworn", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt.",
        verified = true, source = "verified_live_wowhead + Method.gg Ruby Life Pools ability tracker",
    },
    {
        spellId = 1305955, name = "Fiery Blast", npc = "Blazebound Destroyer", dungeon = "Ruby Life Pools",
        encounter = "Kokia trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt the tank-targeted cast.",
        verified = true, source = "verified_live_wowhead + Method.gg Ruby Life Pools ability tracker",
    },
    {
        spellId = 372743, name = "Ice Shield", npc = "Flashfrost Chillweaver", dungeon = "Ruby Life Pools",
        encounter = "Melidrussa trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC -- repeatedly shields an ally and grants CC immunity if missed.",
        verified = true, source = "verified_live_wowhead + Method.gg Ruby Life Pools ability tracker",
    },

    -- ===== Temple of Sethraliss (Adderis & Aspix -> Merektha -> Galvazzt -> Avatar of Sethraliss) =====

    {
        spellId = 268013, name = "Flame Shock", npc = "Twisted Hexxer", dungeon = "Temple of Sethraliss",
        encounter = "Avatar trash / Avatar of Sethraliss", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Priority interrupt. Same mob/spell appears in both the Avatar trash and boss area.",
        verified = true, source = "verified_live_wowhead + Method.gg Temple of Sethraliss ability tracker",
    },
    {
        spellId = 267027, name = "Poison Spit", npc = "Toxic Viper", dungeon = "Temple of Sethraliss",
        encounter = "Merektha add phase", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt. If missed, the resulting Poison is already tracked as a friendly dispel.",
        seeDispel = 267027, -- verified friendly POISON entry, Database/Dispels/Midnight.lua:108
        verified = true, source = "verified_live_wowhead + Method.gg Temple of Sethraliss ability tracker; cross-checked against Database/Dispels/Midnight.lua's independently-verified POISON entry",
    },
    {
        spellId = 1303535, name = "Essence Disruption", npc = "Temple Disruptor", dungeon = "Temple of Sethraliss",
        encounter = "Avatar trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt or CC immediately -- channels into an Eye of Sethraliss.",
        verified = true, source = "verified_live_wowhead + Method.gg Temple of Sethraliss ability tracker",
    },
    {
        spellId = 1314082, name = "Addle Mind", npc = "Faithless Subjugator", dungeon = "Temple of Sethraliss",
        encounter = "Merektha trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt. If cast completes it applies a Curse -- not yet in the dispel database (known gap, not guessed).",
        -- deliberately no seeDispel: this spellId is NOT present in Database/Dispels/Midnight.lua yet
        verified = true, source = "verified_live_wowhead + Method.gg Temple of Sethraliss ability tracker",
    },
    {
        spellId = 1308100, name = "Poisoned Cheap Shot", npc = "Shrouded Fang", dungeon = "Temple of Sethraliss",
        encounter = "Opening trash", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt if possible. If missed, the resulting Poison is already tracked as a friendly dispel.",
        seeDispel = 1308100, -- verified friendly POISON entry, Database/Dispels/Midnight.lua:106
        verified = true, source = "verified_live_wowhead + Method.gg Temple of Sethraliss ability tracker; cross-checked against Database/Dispels/Midnight.lua's independently-verified POISON entry",
    },

    -- ===== Kings' Rest (Golden Serpent -> Mchimba the Embalmer -> Council of Tribes -> Dazar, the First King) =====

    {
        spellId = 267273, name = "Poison Nova", npc = "Council of Tribes (Zanazal)", dungeon = "Kings' Rest",
        encounter = "Council of Tribes", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Must interrupt. If cast, applies a Poison party DoT already tracked as a friendly dispel.",
        seeDispel = 267273, -- verified friendly POISON entry, Database/Dispels/Midnight.lua:73
        verified = true, source = "verified_live_wowhead + Method.gg Kings' Rest ability tracker; cross-checked against Database/Dispels/Midnight.lua's independently-verified POISON entry",
    },
    {
        spellId = 269369, name = "Deathly Roar", npc = "Reban", dungeon = "Kings' Rest",
        encounter = "Dazar, the First King", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Must interrupt -- deals party Shadow damage and fears if completed.",
        verified = true, source = "verified_live_wowhead + Method.gg Kings' Rest ability tracker",
    },
    {
        spellId = 267763, name = "Wretched Discharge", npc = "Half-Finished Mummy", dungeon = "Kings' Rest",
        encounter = "Mchimba trash / Mchimba the Embalmer add phase", kind = "interrupt", priority = "critical", role = "everyone",
        recommendedAction = "Interrupt every cast. If missed, the resulting Disease is already tracked as a friendly dispel.",
        seeDispel = 267763, -- verified friendly DISEASE entry, Database/Dispels/Midnight.lua:74
        verified = true, source = "verified_live_wowhead + Method.gg Kings' Rest ability tracker; cross-checked against Database/Dispels/Midnight.lua's independently-verified DISEASE entry",
    },
})
