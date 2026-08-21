local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end

D:RegisterDispelDBExpansion("Dragonflight", {
    order = 9,
    retail = true,
    coverage = "seeded",
    source = "LittleWigs verified encounter handlers",
}, {
    -- Neltharus
    { id=384161, name="Mote of Combustion", cureType="MAGIC", target="friendly", content="Neltharus", alert=true, source="LittleWigs" },
    { id=372461, name="Imbued Magma", cureType="MAGIC", target="friendly", content="Neltharus", alert=true, source="LittleWigs" },

    -- Algeth'ar Academy (enemy shield; stored for future offensive dispel support)
    { id=387955, name="Celestial Shield", cureType="ENEMYMAGIC", target="enemy", content="Algeth'ar Academy", alert=false, source="LittleWigs" },
})
