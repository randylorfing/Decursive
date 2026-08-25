--[[
    This file is part of Decursive.

    Local dispellable aura database entries for this expansion. This file
    was solely written by Randy Lorfing.
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
--]]

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
