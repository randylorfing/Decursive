local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end

D:RegisterDispelDBExpansion("Midnight", {
    order = 11,
    retail = true,
    coverage = "active",
    notes = "Midnight current-content dispels; friendly harmful entries drive aura sounds. Enemy purge entries are retained for future offensive-dispel features. Season 2 (patch 12.1, launched 2026-08-18) entries below are sourced from a community spell-ID/dispel-type dataset, 10-sample Wowhead-spot-checked with a 10/10 match rate; boss/trash attribution is metadata-only (not stored in this schema) and was left out where guides didn't confirm it. Two entries with an unresolved buff-vs-debuff direction conflict (a 'Bound by Shadow' friendly-Magic candidate and an 'Accumulate Charge' enemy-purge candidate) were deliberately omitted rather than guessed; a 'Rend' entry with zero attribution and a collision-prone generic name was also dropped.",
}, {
    -- ===== Season 2 (12.1) Mythic+ rotation =====

    -- Altar of Fangs (new dungeon)
    { id=1294569, name="Paralyzing Shots", cureType="MAGIC", target="friendly", content="Altar of Fangs", alert=true },
    { id=1294845, name="Corrosive Fangs", cureType="POISON", target="friendly", content="Altar of Fangs", alert=true },
    { id=1296069, name="Regurgitate", cureType="DISEASE", target="friendly", content="Altar of Fangs", alert=true },
    { id=1302867, name="Festering Gash", cureType="DISEASE", target="friendly", content="Altar of Fangs", alert=true },
    { id=1305368, name="Spiteful Venom", cureType="POISON", target="friendly", content="Altar of Fangs", alert=true },
    { id=1307571, name="Envenom", cureType="POISON", target="friendly", content="Altar of Fangs", alert=true },
    { id=1309980, name="Cursed", cureType="CURSE", target="friendly", content="Altar of Fangs", alert=true },
    { id=1310017, name="Twisted Curse", cureType="CURSE", target="friendly", content="Altar of Fangs", alert=true },
    { id=1238255, name="Whirling Spirit", cureType="CURSE", target="friendly", content="Altar of Fangs", alert=true },

    -- Murder Row
    { id=474515,  name="Heartstop Poison", cureType="POISON", target="friendly", content="Murder Row", alert=true },
    { id=1216590, name="Heartstop Poison (variant)", cureType="POISON", target="friendly", content="Murder Row", alert=true },
    { id=474740,  name="Murder in a Row", cureType="BLEED", target="friendly", content="Murder Row", alert=true },
    { id=1217633, name="Corroding Spittle", cureType="MAGIC", target="friendly", content="Murder Row", alert=true },
    { id=1228198, name="Corroding Spittle (variant)", cureType="MAGIC", target="friendly", content="Murder Row", alert=true },
    { id=1217973, name="Curse of Doom", cureType="CURSE", target="friendly", content="Murder Row", alert=true },
    { id=1216300, name="Cutpurse", cureType="BLEED", target="friendly", content="Murder Row", alert=true },
    { id=1295035, name="Glaive Toss", cureType="BLEED", target="friendly", content="Murder Row", alert=true },
    { id=1295427, name="Flay", cureType="BLEED", target="friendly", content="Murder Row", alert=true },
    { id=1311136, name="Sharp Nail", cureType="BLEED", target="friendly", content="Murder Row", alert=true },
    { id=1201554, name="Seduction", cureType="MAGIC", target="friendly", content="Murder Row", alert=true },
    { id=1245456, name="Blightspore Burst", cureType="DISEASE", target="friendly", content="Murder Row", alert=true },
    { id=1229433, name="Fel Crazed", cureType="ENEMYMAGIC", target="enemy", content="Murder Row", alert=false },

    -- Den of Nalorakk
    { id=1234846, name="Toxic Spores", cureType="POISON", target="friendly", content="Den of Nalorakk", alert=true },
    { id=1235549, name="Glacial Torment", cureType="MAGIC", target="friendly", content="Den of Nalorakk", alert=true },
    { id=1239860, name="Cryo Surge", cureType="MAGIC", target="friendly", content="Den of Nalorakk", alert=true },
    { id=1238439, name="Razor Dive", cureType="BLEED", target="friendly", content="Den of Nalorakk", alert=true },
    { id=1238801, name="Insatiable Hunger", cureType="CURSE", target="friendly", content="Den of Nalorakk", alert=true },
    { id=1297696, name="Healing Breeze", cureType="ENEMYMAGIC", target="enemy", content="Den of Nalorakk", alert=false },

    -- The Blinding Vale
    { id=1235865, name="Thornblade", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1238076, name="Thornblade (variant)", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1241058, name="Grievous Thrash", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1247746, name="Thornspike", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1259365, name="Bloodthorn Roots", cureType="MAGIC", target="friendly", content="The Blinding Vale", alert=true },
    { id=1242135, name="Grievous Gash", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1237267, name="Incise", cureType="BLEED", target="friendly", content="The Blinding Vale", alert=true },
    { id=1238084, name="Spore Spines", cureType="MAGIC", target="friendly", content="The Blinding Vale", alert=true },
    { id=1250937, name="Toxic Spew", cureType="POISON", target="friendly", content="The Blinding Vale", alert=true },
    { id=1238581, name="Spiny Shield", cureType="ENEMYMAGIC", target="enemy", content="The Blinding Vale", alert=false },

    -- Voidscar Arena
    { id=1226031, name="Poison Splash", cureType="POISON", target="friendly", content="Voidscar Arena", alert=true },
    { id=1289258, name="Corrosive Essence", cureType="POISON", target="friendly", content="Voidscar Arena", alert=true },
    { id=1249238, name="Fire Spit", cureType="MAGIC", target="friendly", content="Voidscar Arena", alert=true },
    { id=1263971, name="Lingering Poison", cureType="POISON", target="friendly", content="Voidscar Arena", alert=true },
    { id=1267894, name="Savage Leap", cureType="BLEED", target="friendly", content="Voidscar Arena", alert=true },
    { id=1299133, name="Ferocious Leap", cureType="BLEED", target="friendly", content="Voidscar Arena", alert=true },
    { id=1311778, name="Rip and Slice", cureType="BLEED", target="friendly", content="Voidscar Arena", alert=true },
    { id=1252095, name="Curse of Dread", cureType="CURSE", target="friendly", content="Voidscar Arena", alert=true },
    { id=1250043, name="Melt Armor", cureType="ENEMYMAGIC", target="enemy", content="Voidscar Arena", alert=false },

    -- Kings' Rest (returning, BfA)
    { id=266191,  name="Whirling Axe", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=266231,  name="Severing Axe", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=267273,  name="Poison Nova", cureType="POISON", target="friendly", content="Kings' Rest", alert=true },
    { id=267763,  name="Wretched Discharge", cureType="DISEASE", target="friendly", content="Kings' Rest", alert=true },
    { id=269972,  name="Hex Volley", cureType="CURSE", target="friendly", content="Kings' Rest", alert=true },
    -- Hex (270492), Frost Shock (270499), and Bind Soul (270920) are already
    -- registered in BattleForAzeroth.lua for King's Rest; not duplicated here.
    { id=271564,  name="Lingering Fluid", cureType="POISON", target="friendly", content="Kings' Rest", alert=true },
    { id=276031,  name="Pit of Despair", cureType="MAGIC", target="friendly", content="Kings' Rest", alert=true },
    { id=1294815, name="Shadowfrost Bolt", cureType="MAGIC", target="friendly", content="Kings' Rest", alert=true },
    { id=1297781, name="Sudden Rupture", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=1297918, name="Mortal Bleed", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=1298104, name="Putrid Seekers", cureType="POISON", target="friendly", content="Kings' Rest", alert=true },
    { id=1301851, name="Bloodthirsty Axe", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=1302945, name="Impaling Spear", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=1303490, name="Savage Maul", cureType="BLEED", target="friendly", content="Kings' Rest", alert=true },
    { id=1306763, name="Serpent Strike", cureType="POISON", target="friendly", content="Kings' Rest", alert=true },
    { id=270901,  name="Unholy Mending", cureType="ENEMYMAGIC", target="enemy", content="Kings' Rest", alert=false },

    -- Ruby Life Pools (returning, Dragonflight)
    { id=372682,  name="Primal Chill", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=373589,  name="Primal Chill (variant)", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=1305234, name="Cold Claws", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=372796,  name="Blazing Rush", cureType="BLEED", target="friendly", content="Ruby Life Pools", alert=true },
    { id=381515,  name="Stormslam", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=392641,  name="Rolling Thunder", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=392924,  name="Shock Blast", cureType="MAGIC", target="friendly", content="Ruby Life Pools", alert=true },
    { id=373972,  name="Blaze of Glory", cureType="ENEMYMAGIC", target="enemy", content="Ruby Life Pools", alert=false },
    { id=378420,  name="Harden", cureType="ENEMYMAGIC", target="enemy", content="Ruby Life Pools", alert=false },
    { id=381535,  name="Heavy Impacts", cureType="ENEMYMAGIC", target="enemy", content="Ruby Life Pools", alert=false },
    { id=391031,  name="Stormcloud Barrier", cureType="ENEMYMAGIC", target="enemy", content="Ruby Life Pools", alert=false },

    -- Temple of Sethraliss (returning, BfA)
    { id=1291399, name="Serrated Charge", cureType="BLEED", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=1296052, name="Imbued Conduction", cureType="MAGIC", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=1308100, name="Poisoned Cheap Shot", cureType="POISON", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=1308148, name="Cytotoxin", cureType="POISON", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=267027,  name="Poison Spit", cureType="POISON", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=1303486, name="Caustic Stomp", cureType="POISON", target="friendly", content="Temple of Sethraliss", alert=true },
    { id=1308546, name="Venomous Slash", cureType="POISON", target="friendly", content="Temple of Sethraliss", alert=true },

    -- ===== Prior season (S1) content, no longer in the Season 2 M+ rotation =====
    -- Kept for reference / non-M+ content (Delves, world content, etc.); not verified against Season 2 sources.
    { id=390918,  name="Detonation Seeds", cureType="POISON", target="friendly", content="Algeth'ar Academy", alert=true },
    { id=389033,  name="Lasher Toxin", cureType="POISON", target="friendly", content="Algeth'ar Academy", alert=true },
    { id=396716,  name="Splinterbark", cureType="BLEED", target="friendly", content="Algeth'ar Academy", alert=true },

    { id=1255187, name="Holy Fire", cureType="MAGIC", target="friendly", content="Magister's Terrace", alert=true },
    { id=1282055, name="Ethereal Shackles", cureType="MAGIC", target="friendly", content="Magister's Terrace", alert=true },
    { id=1245068, name="Consuming Void", cureType="MAGIC", target="friendly", content="Magister's Terrace", alert=true },
    { id=1252909, name="Arcane Blade", cureType="ENEMYMAGIC", target="enemy", content="Magister's Terrace", alert=false },
    { id=1254306, name="Power Word: Shield", cureType="ENEMYMAGIC", target="enemy", content="Magister's Terrace", alert=false },
    { id=1248689, name="Hastening Ward", cureType="ENEMYMAGIC", target="enemy", content="Magister's Terrace", alert=false },

    { id=1258475, name="Magma Surge", cureType="MAGIC", target="friendly", content="Maisara Caverns", alert=true },
    { id=1258806, name="Ritual Firebrand", cureType="MAGIC", target="friendly", content="Maisara Caverns", alert=true },
    { id=1259255, name="Spirit Rend", cureType="MAGIC", target="friendly", content="Maisara Caverns", alert=true },
    { id=1246666, name="Infected Pinions", cureType="DISEASE", target="friendly", content="Maisara Caverns", alert=true },

    { id=1249815, name="Transference", cureType="ENEMYMAGIC", target="enemy", content="Nexus Point Xenas", alert=false },
    { id=1277557, name="Burning Radiance", cureType="MAGIC", target="friendly", content="Nexus Point Xenas", alert=true },

    { id=1258434, name="Curse of Torment", cureType="CURSE", target="friendly", content="Pit of Saron", alert=true },
    { id=1258437, name="Permeating Cold", cureType="MAGIC", target="friendly", content="Pit of Saron", alert=true },
    { id=1258448, name="Necromantic Infusion", cureType="ENEMYMAGIC", target="enemy", content="Pit of Saron", alert=false },
    { id=1264186, name="Shadowbind", cureType="CURSE", target="friendly", content="Pit of Saron", alert=true },
    { id=1261847, name="Cryostomp", cureType="MAGIC", target="friendly", content="Pit of Saron", alert=true },
    { id=1262929, name="Rotting Strikes", cureType="DISEASE", target="friendly", content="Pit of Saron", alert=true },

    { id=1262526, name="Abyssal Enhancement", cureType="ENEMYMAGIC", target="enemy", content="Seat of the Triumvirate", alert=false },
    { id=1280330, name="Rift Essence", cureType="MAGIC", target="friendly", content="Seat of the Triumvirate", alert=true },

    { id=1254670, name="Rushing Winds", cureType="ENEMYMAGIC", target="enemy", content="Skyreach", alert=false },
    { id=1273356, name="Solar Barrier", cureType="ENEMYMAGIC", target="enemy", content="Skyreach", alert=false },
    { id=1254475, name="Blade Rush", cureType="BLEED", target="friendly", content="Skyreach", alert=true },
    { id=1254380, name="Shear", cureType="BLEED", target="friendly", content="Skyreach", alert=true },

    { id=1216298, name="Soul Torment", cureType="MAGIC", target="friendly", content="Windrunner Spire", alert=true },
    { id=1216860, name="Bolstering Flames", cureType="ENEMYMAGIC", target="enemy", content="Windrunner Spire", alert=false },
    { id=1216822, name="Poison Spray", cureType="POISON", target="friendly", content="Windrunner Spire", alert=true },
    { id=474105,  name="Curse of Darkness", cureType="CURSE", target="friendly", content="Windrunner Spire", alert=true },
})
