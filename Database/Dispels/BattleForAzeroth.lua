local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end
D:RegisterDispelDBExpansion("Battle for Azeroth", { order=7, retail=true, coverage="seeded" }, {
    { id=270920, name="Bind Soul", cureType="MAGIC", target="friendly", content="King's Rest", alert=true },
    { id=270865, name="Hidden Blade", cureType="POISON", target="friendly", content="King's Rest", alert=true },
    { id=270492, name="Hex", cureType="CURSE", target="friendly", content="King's Rest", alert=true },
    { id=270499, name="Frost Shock", cureType="MAGIC", target="friendly", content="King's Rest", alert=true },
    { id=270507, name="Poison Barrage", cureType="POISON", target="friendly", content="King's Rest", alert=true },
})
