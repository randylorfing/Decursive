--[[
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ZDecursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ZDecursive. If not, see <https://www.gnu.org/licenses/>.
--]]

local _, ns = ...

-- Public curated friendly-dispel identities from Decursive v12.1.4-alpha.5
-- commit 62d18ef. Blizzard receives these public IDs through AddAuraSound.
ns.CURATED_DISPEL_ALERTS = {
  {id = 200084, cureType = "MAGIC", content = "Black Rook Hold"},
  {id = 209404, cureType = "MAGIC", content = "Court of Stars"},
  {id = 209413, cureType = "MAGIC", content = "Court of Stars"},
  {id = 211470, cureType = "MAGIC", content = "Court of Stars"},
  {id = 212773, cureType = "MAGIC", content = "Court of Stars"},
  {id = 214690, cureType = "MAGIC", content = "Court of Stars"},
  {id = 263957, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 267027, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 267273, cureType = "POISON", content = "Kings' Rest"},
  {id = 267763, cureType = "DISEASE", content = "Kings' Rest"},
  {id = 268008, cureType = "MAGIC", content = "Temple of Sethraliss"},
  {id = 268013, cureType = "MAGIC", content = "Temple of Sethraliss"},
  {id = 269686, cureType = "DISEASE", content = "Temple of Sethraliss"},
  {id = 269972, cureType = "CURSE", content = "Kings' Rest"},
  {id = 270492, cureType = "CURSE", content = "King's Rest"},
  {id = 270499, cureType = "MAGIC", content = "King's Rest"},
  {id = 270507, cureType = "POISON", content = "King's Rest"},
  {id = 270865, cureType = "POISON", content = "King's Rest"},
  {id = 270920, cureType = "MAGIC", content = "King's Rest"},
  {id = 271564, cureType = "POISON", content = "Kings' Rest"},
  {id = 272699, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 273563, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 276031, cureType = "MAGIC", content = "Kings' Rest"},
  {id = 372461, cureType = "MAGIC", content = "Neltharus"},
  {id = 372682, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 373589, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 381515, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 384161, cureType = "MAGIC", content = "Neltharus"},
  {id = 389033, cureType = "POISON", content = "Algeth'ar Academy"},
  {id = 390918, cureType = "POISON", content = "Algeth'ar Academy"},
  {id = 392641, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 392924, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 474105, cureType = "CURSE", content = "Windrunner Spire"},
  {id = 474515, cureType = "POISON", content = "Murder Row"},
  {id = 1201554, cureType = "MAGIC", content = "Murder Row"},
  {id = 1216298, cureType = "MAGIC", content = "Windrunner Spire"},
  {id = 1216590, cureType = "POISON", content = "Murder Row"},
  {id = 1216822, cureType = "POISON", content = "Windrunner Spire"},
  {id = 1217633, cureType = "MAGIC", content = "Murder Row"},
  {id = 1217973, cureType = "CURSE", content = "Murder Row"},
  {id = 1226031, cureType = "POISON", content = "Voidscar Arena"},
  {id = 1228198, cureType = "MAGIC", content = "Murder Row"},
  {id = 1234846, cureType = "POISON", content = "Den of Nalorakk"},
  {id = 1235549, cureType = "MAGIC", content = "Den of Nalorakk"},
  {id = 1238084, cureType = "MAGIC", content = "The Blinding Vale"},
  {id = 1238255, cureType = "CURSE", content = "Altar of Fangs"},
  {id = 1238801, cureType = "CURSE", content = "Den of Nalorakk"},
  {id = 1239860, cureType = "MAGIC", content = "Den of Nalorakk"},
  {id = 1245068, cureType = "MAGIC", content = "Magister's Terrace"},
  {id = 1245456, cureType = "DISEASE", content = "Murder Row"},
  {id = 1246666, cureType = "DISEASE", content = "Maisara Caverns"},
  {id = 1249238, cureType = "MAGIC", content = "Voidscar Arena"},
  {id = 1250937, cureType = "POISON", content = "The Blinding Vale"},
  {id = 1252095, cureType = "CURSE", content = "Voidscar Arena"},
  {id = 1255187, cureType = "MAGIC", content = "Magister's Terrace"},
  {id = 1258434, cureType = "CURSE", content = "Pit of Saron"},
  {id = 1258437, cureType = "MAGIC", content = "Pit of Saron"},
  {id = 1258475, cureType = "MAGIC", content = "Maisara Caverns"},
  {id = 1258806, cureType = "MAGIC", content = "Maisara Caverns"},
  {id = 1259255, cureType = "MAGIC", content = "Maisara Caverns"},
  {id = 1259365, cureType = "MAGIC", content = "The Blinding Vale"},
  {id = 1261847, cureType = "MAGIC", content = "Pit of Saron"},
  {id = 1262929, cureType = "DISEASE", content = "Pit of Saron"},
  {id = 1263971, cureType = "POISON", content = "Voidscar Arena"},
  {id = 1264186, cureType = "CURSE", content = "Pit of Saron"},
  {id = 1277557, cureType = "MAGIC", content = "Nexus Point Xenas"},
  {id = 1280330, cureType = "MAGIC", content = "Seat of the Triumvirate"},
  {id = 1282055, cureType = "MAGIC", content = "Magister's Terrace"},
  {id = 1286922, cureType = "MAGIC", content = "The Venomous Abyss", instanceID = 3004},
  {id = 1289258, cureType = "POISON", content = "Voidscar Arena"},
  {id = 1294569, cureType = "MAGIC", content = "Altar of Fangs"},
  {id = 1294815, cureType = "MAGIC", content = "Kings' Rest"},
  {id = 1294845, cureType = "POISON", content = "Altar of Fangs"},
  {id = 1296052, cureType = "MAGIC", content = "Temple of Sethraliss"},
  {id = 1296069, cureType = "DISEASE", content = "Altar of Fangs"},
  {id = 1298104, cureType = "POISON", content = "Kings' Rest"},
  {id = 1301800, cureType = "POISON", content = "The Venomous Abyss", instanceID = 3004},
  {id = 1302867, cureType = "DISEASE", content = "Altar of Fangs"},
  {id = 1303486, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 1305234, cureType = "MAGIC", content = "Ruby Life Pools"},
  {id = 1305368, cureType = "POISON", content = "Altar of Fangs"},
  {id = 1306763, cureType = "POISON", content = "Kings' Rest"},
  {id = 1306906, cureType = "POISON", content = "The Venomous Abyss", instanceID = 3004},
  {id = 1307571, cureType = "POISON", content = "Altar of Fangs"},
  {id = 1308100, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 1308148, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 1308546, cureType = "POISON", content = "Temple of Sethraliss"},
  {id = 1309980, cureType = "CURSE", content = "Altar of Fangs"},
  {id = 1310017, cureType = "CURSE", content = "Altar of Fangs"},
}
