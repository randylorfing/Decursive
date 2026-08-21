local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end

D:RegisterDispelDBExpansion("Legion", {
    order = 6,
    retail = true,
    coverage = "seeded",
    source = "LittleWigs verified encounter handlers",
    notes = "Friendly dispels verified from Legion dungeon modules; enemy purge entries are retained but do not drive friendly sounds.",
}, {
    -- Court of Stars
    { id=212773, name="Subdue", cureType="MAGIC", target="friendly", content="Court of Stars", alert=true, source="LittleWigs" },
    { id=209413, name="Suppress", cureType="MAGIC", target="friendly", content="Court of Stars", alert=true, source="LittleWigs" },
    { id=214690, name="Cripple", cureType="MAGIC", target="friendly", content="Court of Stars", alert=true, source="LittleWigs" },
    { id=211470, name="Bewitch", cureType="MAGIC", target="friendly", content="Court of Stars", alert=true, source="LittleWigs" },
    { id=209404, name="Seal Magic", cureType="MAGIC", target="friendly", content="Court of Stars", alert=true, source="LittleWigs" },
    { id=209033, name="Fortification", cureType="ENEMYMAGIC", target="enemy", content="Court of Stars", alert=false, source="LittleWigs" },

    -- Black Rook Hold
    { id=200084, name="Soul Blade", cureType="MAGIC", target="friendly", content="Black Rook Hold", alert=true, source="LittleWigs" },

    -- Timewalking/legacy variant retained from prior database
    { id=270499, name="Frost Shock (timewalking variant)", cureType="MAGIC", target="friendly", content="Legacy/Timewalking", alert=true },
})
