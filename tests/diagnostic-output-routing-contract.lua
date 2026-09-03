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

local function Check(value, message)
  if not value then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local shown = {}
local chatCount = 0
local classFile = "PRIEST"
local spellbookResult = false

issecretvalue = function()
  return false
end

canaccessvalue = function()
  return true
end

strtrim = function(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

UnitClass = function()
  return "PrivateClassName", classFile
end

UnitRace = function()
  return "PrivateRaceName", "PrivateRaceToken"
end

InCombatLockdown = function()
  return false
end

InChatMessagingLockdown = function()
  return false
end

C_AddOns = {
  GetAddOnMetadata = function()
    return "v13.1.0-alpha"
  end,
}

C_Item = {
  GetItemCount = function()
    return 1
  end,
}

C_Spell = {
  GetOverrideSpell = function(spellId)
    return spellId
  end,
  GetSpellName = function(spellId)
    return "PrivateSpell" .. tostring(spellId)
  end,
  IsSpellInRange = function()
    return true
  end,
}

C_SpellBook = {
  IsSpellInSpellBook = function()
    return spellbookResult
  end,
  IsSpellKnown = function()
    return spellbookResult
  end,
}

C_UnitAuras = {
  AddAuraSound = function()
  end,
}

Enum = {
  SpellBookSpellBank = {Player = 0, Pet = 1},
}

AuraUtil = {
  AuraFilters = {
    Dispellable = "DISPELLABLE",
    RaidPlayerDispellable = "RAID_PLAYER_DISPELLABLE",
  },
}

DEFAULT_CHAT_FRAME = {
  AddMessage = function()
    chatCount = chatCount + 1
  end,
}

local ns = {
  Diagnostics = {
    ShowText = function(text)
      shown[#shown + 1] = text
      return true
    end,
  },
  RegisterDiagnosticProvider = function()
  end,
  DiagnosticModuleLoaded = function()
  end,
}

assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local pack = ns.MakePack("OPEN_WORLD")
pack.advanced.customMacro = "/cast [@mouseover] PrivateMacro"

local addon = {
  db = {
    global = {},
    profile = {lists = {priority = {"PrivateCharacter-Realm"}, skip = {}}},
    GetCurrentProfile = function()
      return "PrivateProfile"
    end,
  },
  GetAppliedEnvironmentPack = function()
    return pack
  end,
  GetEditingEnvironment = function()
    return "OPEN_WORLD"
  end,
  GetSpecAssignment = function()
    return {enabled = true, profile = "PrivateProfile"}, 1
  end,
  GetCharacterKey = function()
    return "PrivateCharacter-Realm"
  end,
  GetSpecIndex = function()
    return 1
  end,
  GetSpecName = function()
    return "PrivateSpecName"
  end,
  EnsureSpecAssignments = function()
    return {
      [1] = {enabled = true, profile = "PrivateProfile"},
      [2] = {enabled = false, profile = "AnotherPrivateProfile"},
    }
  end,
  SpecSlotCount = function()
    return 2
  end,
  Print = function()
    chatCount = chatCount + 1
  end,
}

ns.addon = addon
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)

local routes = {
  {name = "status", callback = function() return ns.PrintAddonStatus() end},
  {name = "help", callback = function() return ns.PrintSlashHelp() end},
  {name = "identity", callback = function() return ns.PrintIdentity() end},
  {name = "diagnostics", callback = function() return ns.PrintDiagnostics() end},
  {name = "report", callback = function() return ns.PrintReport() end},
  {name = "Soul Link status", callback = function() return ns.PrintSoulLinkStatus() end},
}

local forbidden = {
  "PrivateCharacter-Realm",
  "PrivateProfile",
  "AnotherPrivateProfile",
  "PrivateSpecName",
  "PrivateClassName",
  "PrivateRaceName",
  "PrivateSpell",
  "PrivateMacro",
  "1259646",
  "269586",
  "raw|signature",
}

for i = 1, #routes do
  local route = routes[i]
  local before = #shown
  Check(route.callback() == true, route.name .. " opens the copyable diagnostics window")
  Equal(#shown, before + 1, route.name .. " opens exactly one report window")
  Equal(chatCount, 0, route.name .. " never writes diagnostics to chat")
  Check(shown[#shown]:find("\n", 1, true) ~= nil, route.name .. " output remains multiline and copyable")
  for j = 1, #forbidden do
    Check(not shown[#shown]:find(forbidden[j], 1, true), route.name .. " leaked " .. forbidden[j])
  end
end

classFile = "SHAMAN"
C_SpellBook.IsSpellInSpellBook = nil
local beforeProbe = #shown
ns.GetEngineDispelGaps(false)
Equal(#shown, beforeProbe + 1, "poison capability probe opens one copyable notice")
Equal(chatCount, 0, "poison capability probe never writes diagnostics to chat")
Check(shown[#shown]:find("Poison capability probe unavailable", 1, true) ~= nil, "poison notice is actionable")

local beforeNotification = #shown
ns.HandleSoulLinkSlash("on")
Equal(#shown, beforeNotification, "ordinary toggle notification does not replace the report window")
Equal(chatCount, 1, "ordinary toggle notification remains concise in chat")

io.write("diagnostic-output-routing-contract: ok\n")
