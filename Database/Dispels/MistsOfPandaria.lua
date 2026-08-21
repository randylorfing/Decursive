local addonName, T = ...
local D = type(T) == "table" and T.Dcr or nil
if type(D) ~= "table" or type(D.RegisterDispelDBExpansion) ~= "function" then return end
D:RegisterDispelDBExpansion("Mists of Pandaria", { order=5, retail=true, coverage="module-ready", notes="Per-expansion module is active; encounter debuff harvesting is ongoing." }, {
})
