local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end

D:RegisterDispelDBExpansion("Midnight", {
    order = 11,
    retail = true,
    coverage = "active",
    notes = "Midnight current-content dispels; friendly harmful entries drive aura sounds. Enemy purge entries are retained for future offensive-dispel features.",
}, {
    -- Midnight 12.1 / known S2 test mechanics
    { id=1294569, name="Paralyzing Shots", cureType="MAGIC", target="friendly", content="Midnight 12.1", alert=true },
    { id=474515,  name="Heartstop Poison", cureType="POISON", target="friendly", content="Midnight", alert=true },
    { id=1216590, name="Heartstop Poison (variant)", cureType="POISON", target="friendly", content="Midnight", alert=true },
    { id=1217633, name="Corroding Spittle", cureType="MAGIC", target="friendly", content="Midnight", alert=true },
    { id=1228198, name="Corroding Spittle (variant)", cureType="MAGIC", target="friendly", content="Midnight", alert=true },

    -- Midnight S1 verified Method/Wowhead M+ database - friendly harmful dispels
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
