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

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat = false
InCombatLockdown = function()
  return combat
end

local classToken = "MONK"
local secretClass = {}
UnitClass = function()
  return "Monk", classToken
end

UnitIsConnected = function()
  return true
end

UnitIsUnit = function(left, right)
  return left == right
end

issecretvalue = function(value)
  return value == secretClass or (type(value) == "table" and value.secret == true)
end

canaccessvalue = function(value)
  return not issecretvalue(value)
end

C_ClassColor = {
  GetClassColor = function(token)
    Check(token == "MONK", "class token reaches C_ClassColor")
    return {
      GetRGBA = function()
        return 0, 1, 0.596, 1
      end,
    }
  end,
}

CreateColor = function(r, g, b, a)
  return {r, g, b, a}
end

RAID_CLASS_COLORS = {
  MONK = {r = 0, g = 1, b = 0.596},
}

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)

local clickStatus = ns.GetResolvedClickStatus()
Equal(clickStatus.mode, "AUTO", "resolved click status defaults to AUTO")
Check(clickStatus.available, "resolved click status exposes the authoritative model")
Equal(clickStatus.mappings[1].gesture, "Middle", "fixed middle gesture is reported")
Equal(clickStatus.mappings[1].action, "Target", "fixed middle target action is reported")
Equal(clickStatus.mappings[2].gesture, "Ctrl+Middle", "fixed focus gesture is reported")
Equal(clickStatus.mappings[2].action, "Focus", "fixed focus action is reported")
combat = true
local lockedClickStatus = ns.GetResolvedClickStatus()
Check(lockedClickStatus.pending, "combat status reports the existing secure rebuild as pending")
combat = false

local openWorld = ns.MakePack("OPEN_WORLD")
for _, row in ipairs(ns.ENVIRONMENTS) do
	local expectedCap = (row.key == "RAID" or row.key == "PVP") and 40 or 5
	Equal(ns.MakePack(row.key).mufs.maxUnits, expectedCap, row.label .. " fresh display cap")
end
Equal(openWorld.mufs.dimOutOfRange, true, "current Open World range default is enabled")
Equal(openWorld.colors.healthy[1], 0, "legacy healthy red")
Equal(openWorld.colors.healthy[2], 0.3, "legacy healthy green")
Equal(openWorld.colors.healthy[3], 0.1, "legacy healthy blue")
Equal(openWorld.colors.healthy[4], 0.9, "legacy healthy alpha")
Equal(openWorld.mufs.centerTransp, 0.35, "legacy healthy center opacity")
Equal(openWorld.mufs.borderTransp, 0.2, "legacy class border opacity")
Equal(openWorld.colors.dead[1], 0, "fresh death color red")
Equal(openWorld.colors.dead[2], 0, "fresh death color green")
Equal(openWorld.colors.dead[3], 0, "fresh death color blue")
Equal(openWorld.colors.dead[4], 1, "fresh death color is opaque")
local canonicalCureColors = {
  magic = {255 / 255, 7 / 255, 9 / 255, 1},
  curse = {153 / 255, 51 / 255, 255 / 255, 1},
  poison = {51 / 255, 204 / 255, 51 / 255, 1},
  disease = {255 / 255, 95 / 255, 36 / 255, 1},
}
for _, row in ipairs(ns.ENVIRONMENTS) do
  local pack = ns.MakePack(row.key)
  Equal(table.concat(pack.cure.order, ","), "magic,curse,poison,disease", row.label .. " canonical cure priority")
  for key, expected in pairs(canonicalCureColors) do
    for channel = 1, 4 do
      Equal(pack.colors[key][channel], expected[channel], row.label .. " " .. key .. " canonical channel " .. channel)
    end
  end
  Equal(pack.colors.range[1], 248 / 255, row.label .. " range remains separate from cure palette")
  Equal(pack.colors.range[4], 1, row.label .. " range remains opaque")
end

local topPriority = {"party4", "player", "party1", "partypet1", "party2", "party3", "party5"}
local capped, appliedCap, capReport = ns.ApplyMUFDisplayCap(topPriority, openWorld.mufs.maxUnits)
Equal(appliedCap, 5, "fresh cap resolves to five")
Equal(table.concat(capped, ","), "party4,player,party1,party2,party3,partypet1", "member cap keeps stable owner pet as an additional MUF")
Check(capped[2] == "player", "included player consumes one displayed slot")
Equal(capReport.eligibleMembers, 6, "cap report eligible members")
Equal(capReport.eligiblePets, 1, "cap report eligible pets")
Equal(capReport.omittedMembers, 1, "cap report omitted member")
Equal(capReport.omittedPets, 0, "cap report does not omit owner pet at member cap")

local soloRoster = {"player"}
ns.ApplyMUFDisplayCap(soloRoster, 5)
Equal(#soloRoster, 1, "solo roster remains intact")
local followerRoster = {"player", "party1", "party2", "partypet2", "party3", "party4"}
ns.ApplyMUFDisplayCap(followerRoster, 5)
Equal(table.concat(followerRoster, ","), "player,party1,party2,party3,party4,partypet2", "five-member follower roster adds pet after capped members")
local fiveMembersAndPet = {"player", "pet", "party1", "party2", "party3", "party4"}
ns.ApplyMUFDisplayCap(fiveMembersAndPet, 5)
Equal(table.concat(fiveMembersAndPet, ","), "player,party1,party2,party3,party4,pet", "screenshot fixture keeps all five members plus the enabled player pet")

local invalidPets = {"player", "pet", "pet", "party1", "partypet1", "partypet4"}
local _, _, invalidPetReport = ns.ApplyMUFDisplayCap(invalidPets, 5)
Equal(table.concat(invalidPets, ","), "player,party1,pet,partypet1", "duplicate and orphan pets never consume presentation slots")
Equal(invalidPetReport.duplicatePets, 1, "duplicate pet is diagnosed")
Equal(invalidPetReport.orphanPets, 1, "orphan pet is diagnosed")

math.randomseed(4105)
local sourceUnits = {"player", "pet", "party1", "partypet1", "party2", "partypet2", "party3", "party4"}
for iteration = 1, 64 do
	local shuffled = {}
	for i = 1, #sourceUnits do
		shuffled[i] = sourceUnits[i]
	end
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local expectedMembers = {}
	local expectedMemberSet = {}
	for i = 1, #shuffled do
		if not shuffled[i]:find("pet", 1, true) then
			expectedMembers[#expectedMembers + 1] = shuffled[i]
			expectedMemberSet[shuffled[i]] = true
		end
	end
	for i = 1, #shuffled do
		local unit = shuffled[i]
		if unit:find("pet", 1, true) then
			local owner = unit == "pet" and "player" or unit:gsub("pet", "")
			if expectedMemberSet[owner] then
				expectedMembers[#expectedMembers + 1] = unit
			end
		end
	end
	ns.ApplyMUFDisplayCap(shuffled, 5)
	Equal(table.concat(shuffled, ","), table.concat(expectedMembers, ","), "randomized member cap preserves alpha member and owner-pet order " .. iteration)
end
local raidRoster = {"raid1", "raid2", "raid3", "raid4", "raid5", "raid6"}
ns.ApplyMUFDisplayCap(raidRoster, ns.MakePack("RAID").mufs.maxUnits)
Equal(ns.MakePack("RAID").mufs.maxUnits, 40, "fresh Raid pack defaults to forty displayed members")
Equal(#raidRoster, 6, "fresh Raid cap does not truncate a six-player raid")
local pvpRoster = {"raid1", "raid2", "raid3", "raid4", "raid5", "raid6"}
ns.ApplyMUFDisplayCap(pvpRoster, ns.MakePack("PVP").mufs.maxUnits)
Equal(ns.MakePack("PVP").mufs.maxUnits, 40, "fresh PvP pack defaults to battleground capacity")
Equal(#pvpRoster, 6, "fresh PvP cap does not truncate a six-player battleground roster")
local customCapRoster = {"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7"}
ns.ApplyMUFDisplayCap(customCapRoster, 7)
Equal(#customCapRoster, 7, "custom cap above five remains supported")

local ownerSize, ownerInner = ns.GetMUFVisualMetrics(20, true, "player")
Equal(ownerSize, 20, "owner frame size")
Equal(ownerInner, 16, "owner inner size")
local petSize, petInner = ns.GetMUFVisualMetrics(20, true, "pet")
Equal(petSize, 16, "pet frame size")
Equal(petInner, 12, "pet inner size")
local largeOwnerSize = ns.GetMUFVisualMetrics(40, true, "party1")
Equal(largeOwnerSize, 40, "larger configured party frames retain their size")
for _, unit in ipairs({"pet", "partypet1", "raidpet1"}) do
  local largerPet = ns.GetMUFVisualMetrics(40, true, unit)
  Equal(largerPet, 32, unit .. " retains original Decursive's 16-to-20 proportion at larger sizes")
end

local solo = ns.ResolveMUFBaseAppearance(openWorld, "player")
Equal(solo.fillAlpha, 0.315, "solo idle effective healthy alpha")
Check(solo.borderVisible, "solo class border visible")
Equal(solo.borderRed, 0, "solo class border red")
Equal(solo.borderGreen, 1, "solo class border green")
Equal(solo.borderBlue, 0.596, "solo class border blue")
Equal(solo.borderAlpha, 0.2, "solo class border alpha")

local owner = ns.ResolveMUFBaseAppearance(openWorld, "party1")
local pet = ns.ResolveMUFBaseAppearance(openWorld, "partypet1")
Equal(owner.fillAlpha, solo.fillAlpha, "group owner healthy fill parity")
Equal(pet.fillAlpha, solo.fillAlpha, "group pet healthy fill parity")

openWorld.mufs.border = false
Check(not ns.ResolveMUFBaseAppearance(openWorld, "player").borderVisible, "class border off")
openWorld.mufs.border = true

openWorld.mufs.locked = true
local locked = ns.ResolveMUFBaseAppearance(openWorld, "player")
openWorld.mufs.locked = false
local unlocked = ns.ResolveMUFBaseAppearance(openWorld, "player")
Equal(locked.fillAlpha, unlocked.fillAlpha, "locked and unlocked use identical square paint")
Equal(locked.borderAlpha, unlocked.borderAlpha, "lock state does not select or recolor a MUF")

ns.HasActiveAddonRestriction = function()
  return true
end
local restricted = ns.ResolveMUFManagedAppearance(openWorld, "player")
Check(restricted.restrictionStatusLight, "restriction remains available to status light")
Check(not restricted.restrictionFailureFill, "restriction never paints full-square red")
Equal(restricted.afflictionAuthority, "AURA_CONTAINER", "AuraContainer remains affliction authority")
Check(restricted.rangeAboveAffliction, "whole-MUF range shade is above afflicted fill")
Check(restricted.afflictionAboveManaged, "affliction wins over ordinary managed state")

local dungeon = ns.MakePack("DUNGEON")
ns.CureSpellRangeValue = function()
  return false
end
local outOfRange = ns.ResolveMUFManagedAppearance(dungeon, "party1")
Check(outOfRange.rangeEnabled and outOfRange.inRange == false, "group out-of-range overlay preserved")
Equal(outOfRange.rangeColor[1], dungeon.colors.range[1], "range uses configured profile red")
Equal(outOfRange.rangeColor[2], dungeon.colors.range[2], "range uses configured profile green")
Equal(outOfRange.rangeColor[3], dungeon.colors.range[3], "range uses configured profile blue")
Equal(outOfRange.rangeAlpha, dungeon.mufs.dimAmount, "range uses configured dim amount")
Equal(outOfRange.rangeReason, "CONFIGURED_COLOR", "range presentation reason")
Equal(outOfRange.rangeStateSource, "PRIMARY_CURE_PUBLIC_RANGE", "range state source")
local playerRange = ns.ResolveMUFManagedAppearance(dungeon, "player")
Check(not playerRange.rangeEnabled and playerRange.inRange == true, "player MUF is always treated in range")
Equal(playerRange.rangeReason, "PLAYER_ALWAYS_IN_RANGE", "player range presentation reason")

local assignedProfileA = ns.MakePack("DUNGEON")
assignedProfileA.colors.range = {0.12, 0.34, 0.56, 0.20}
assignedProfileA.mufs.dimAmount = 0.75
local assignedProfileB = ns.MakePack("DUNGEON")
assignedProfileB.colors.range = {0.80, 0.30, 0.10, 1}
assignedProfileB.mufs.dimAmount = 0.40
local profileARange = ns.ResolveMUFRangePresentation(assignedProfileA, false, false)
local profileBRange = ns.ResolveMUFRangePresentation(assignedProfileB, false, false)
Equal(profileARange.color[1], 0.12, "assigned profile A range color")
Equal(profileARange.alpha, 0.75, "assigned profile A range dim")
Equal(profileBRange.color[1], 0.80, "assigned profile B range color")
Equal(profileBRange.alpha, 0.40, "assigned profile B range dim")
Check(profileARange.precedence == "WHOLE_MUF_SHADE_ABOVE_CONTENT", "one top shade dims affliction and readable content together")

assignedProfileA.colors.dead = {0.11, 0.22, 0.33, 0.44}
assignedProfileB.colors.dead = {0.66, 0.55, 0.44, 1}
local profileADeath = ns.ResolveMUFDeathPresentation(assignedProfileA, true, false, "PUBLIC_DEAD")
local profileBDeath = ns.ResolveMUFDeathPresentation(assignedProfileB, true, false, "PUBLIC_DEAD")
Equal(profileADeath.color[1], 0.11, "assigned profile A death color")
Equal(profileADeath.color[4], 0.44, "assigned profile A death alpha")
Equal(profileBDeath.color[1], 0.66, "assigned profile B death color")
Equal(profileADeath.precedence, "ABOVE_RANGE_AFFLICTION_SOUL_LINK", "death wins over range, affliction, and Soul Link")
Check(profileADeath.publicState and profileADeath.nativeValue == true, "public dead state activates death presentation")
local retainedDeath = ns.ResolveMUFDeathPresentation(assignedProfileA, nil, profileADeath.publicState, "API_FAILED")
Check(retainedDeath.publicState and retainedDeath.nativeValue == true, "transient unavailable death sample retains public dead state")
local aliveDeath = ns.ResolveMUFDeathPresentation(assignedProfileA, false, retainedDeath.publicState, "PUBLIC_ALIVE")
Check(not aliveDeath.publicState and aliveDeath.nativeValue == false, "explicit alive state clears death presentation immediately")

local transitions = {
  ns.ResolveMUFRangePresentation(dungeon, true, false),
  ns.ResolveMUFRangePresentation(dungeon, false, false),
  ns.ResolveMUFRangePresentation(dungeon, true, false),
}
Check(transitions[1].inRange == true and transitions[2].inRange == false and transitions[3].inRange == true, "in-out-in range transitions")
local followerRange = ns.ResolveMUFRangePresentation(dungeon, false, false)
Check(followerRange.enabled and followerRange.inRange == false, "follower pet range presentation is isolated and enabled")

local function NewRangeWidget()
  local widget = {shown = false}
  function widget:SetColorTexture(r, g, b, a)
    self.color = {r, g, b, a}
  end
  function widget:SetAlphaFromBoolean(value, onAlpha, offAlpha)
    self.booleanValue = value
    if value == true then
      self.alpha = onAlpha
    elseif value == false then
      self.alpha = offAlpha
    end
  end
  function widget:SetAlpha(alpha)
    self.alpha = alpha
  end
  function widget:Show()
    self.shown = true
  end
  function widget:Hide()
    self.shown = false
  end
  return widget
end


local function NewDeathWidget()
  local widget = {}
  function widget:SetVertexColor(r, g, b, a)
    self.color = {r, g, b, a}
  end
  function widget:SetVertexColorFromBoolean(value, onColor, offColor)
    self.booleanValue = value
    if value == true then
      self.color = onColor
    elseif value == false then
      self.color = offColor
    end
  end
  return widget
end

local deathFill = NewDeathWidget()
local deathSkull = NewDeathWidget()
Check(ns.ApplyMUFDeathPresentation(deathFill, deathSkull, profileADeath), "death presentation applies to addon-owned widgets")
Equal(deathFill.color[1], assignedProfileA.colors.dead[1], "death widget uses active pack red")
Equal(deathFill.color[4], assignedProfileA.colors.dead[4], "death widget uses active pack alpha")
Equal(deathSkull.color[1], 1, "death skull remains white and readable")
local followerDeathFill = NewDeathWidget()
local followerDeathSkull = NewDeathWidget()
local followerAlive = ns.ResolveMUFDeathPresentation(assignedProfileA, false, false, "PUBLIC_ALIVE")
ns.ApplyMUFDeathPresentation(followerDeathFill, followerDeathSkull, followerAlive)
Check(followerDeathFill.color[4] == 0 and followerDeathSkull.color[4] == 0, "alive follower clears only its own death presentation")
Equal(deathFill.color[1], assignedProfileA.colors.dead[1], "follower transition does not mutate dead owner")
UnitIsConnected = function()
  return false
end
local offlineValue, offlineSource = ns.ReadMUFDeathValue("party2")
Check(offlineValue == true and offlineSource == "PUBLIC_OFFLINE", "offline unit uses authoritative skull semantics")
UnitIsConnected = function()
  return true
end

local ownerRangeWidget = NewRangeWidget()
local ownerRangeHost = NewRangeWidget()
local followerRangeWidget = NewRangeWidget()
local followerRangeHost = NewRangeWidget()
ns.ApplyMUFRangePresentation(ownerRangeWidget, transitions[1], ownerRangeHost)
Equal(ownerRangeWidget.alpha, 1, "in-range range texture remains locally opaque")
Equal(ownerRangeHost.alpha, 0, "in-range composition host clears configured tint")
ns.ApplyMUFRangePresentation(ownerRangeWidget, transitions[2], ownerRangeHost)
Equal(ownerRangeWidget.alpha, 1, "out-of-range range texture remains locally opaque")
Equal(ownerRangeHost.alpha, 1, "out-of-range composition host remains opaque")
Equal(ownerRangeWidget.color[1], dungeon.colors.range[1], "range red remains full below the top shade")
Equal(ownerRangeWidget.color[2], dungeon.colors.range[2], "range green remains full below the top shade")
Equal(ownerRangeWidget.color[3], dungeon.colors.range[3], "range blue remains full below the top shade")
Equal(ownerRangeWidget.color[4], 1, "range texture intrinsic alpha is one")
local contrastingBase = {0.95, 0.10, 0.75}
local composed = {}
for i = 1, 3 do
  composed[i] = ownerRangeWidget.color[i] * ownerRangeWidget.color[4]
    + contrastingBase[i] * (1 - ownerRangeWidget.color[4])
  Equal(composed[i], ownerRangeWidget.color[i], "opaque range composite has zero base contribution channel " .. i)
end
ns.ApplyMUFRangePresentation(followerRangeWidget, followerRange, followerRangeHost)
Equal(followerRangeWidget.alpha, 1, "out-of-range follower texture remains locally opaque")
Equal(followerRangeHost.alpha, 1, "out-of-range follower host remains opaque")
Equal(ownerRangeHost.alpha, 1, "follower paint does not mutate owner host")
ns.ApplyMUFRangePresentation(ownerRangeWidget, transitions[3], ownerRangeHost)
Equal(ownerRangeHost.alpha, 0, "returning in range clears tint")

combat = true
ns.ApplyMUFRangePresentation(ownerRangeWidget, profileARange, ownerRangeHost)
Equal(ownerRangeWidget.alpha, 1, "combat range texture remains locally opaque")
Equal(ownerRangeHost.alpha, 1, "combat range composition host remains opaque")
ns.ApplyMUFDeathPresentation(deathFill, deathSkull, profileADeath)
Equal(deathFill.color[1], assignedProfileA.colors.dead[1], "combat death transition uses native widget without layout mutation")
combat = false

classToken = secretClass
local secretBorder = ns.ResolveMUFBaseAppearance(openWorld, "party1")
Check(not secretBorder.borderVisible, "secret class hides rather than invents a border color")
classToken = "MONK"

local secretRange = {secret = true}
ns.CureSpellRangeValue = function()
  return secretRange
end
local secretManaged = ns.ResolveMUFManagedAppearance(dungeon, "party1")
Check(secretManaged.inRange == secretRange, "secret range value passes to native boolean consumer unchanged")
local secretRangeWidget = NewRangeWidget()
local secretRangeHost = NewRangeWidget()
ns.ApplyMUFRangePresentation(secretRangeWidget, {
  enabled = secretManaged.rangeEnabled,
  inRange = secretManaged.inRange,
  color = secretManaged.rangeColor,
  alpha = secretManaged.rangeAlpha,
}, secretRangeHost)
Equal(secretRangeWidget.alpha, 1, "secret range texture remains locally opaque")
Check(secretRangeHost.booleanValue == secretRange, "secret range value reaches native parent-alpha widget unchanged")
local secretDeath = {secret = true}
local secretDeathPresentation = ns.ResolveMUFDeathPresentation(dungeon, secretDeath, true, "SECRET_NATIVE")
local secretDeathFill = NewDeathWidget()
local secretDeathSkull = NewDeathWidget()
ns.ApplyMUFDeathPresentation(secretDeathFill, secretDeathSkull, secretDeathPresentation)
Check(secretDeathFill.booleanValue == secretDeath, "secret death value reaches native fill widget unchanged")
Check(secretDeathSkull.booleanValue == secretDeath, "secret death value reaches native skull widget unchanged")
Check(secretDeathPresentation.publicState, "secret sample does not erase last public dead state")

local activeCooldown = ns.ResolveMUFCooldownPresentation(true, false, false)
Check(activeCooldown.active and not activeCooldown.suppressedBySkull, "active cooldown shows for an alive unit")
local function NewCooldownHolder()
  local holder = {alpha = -1}
  function holder:SetAlpha(alpha)
    self.alpha = alpha
  end
  function holder:SetAlphaFromBoolean(value, onAlpha, offAlpha)
    self.booleanValue = value
    if value == true then
      self.alpha = onAlpha
    elseif value == false then
      self.alpha = offAlpha
    end
  end
  return holder
end
local ownerCooldownHolder = NewCooldownHolder()
ns.ApplyMUFCooldownVisibility(ownerCooldownHolder, activeCooldown)
Equal(ownerCooldownHolder.alpha, 1, "active cooldown holder is visible")
local cooldownWhileDead = ns.ResolveMUFCooldownPresentation(true, true, true)
Check(not cooldownWhileDead.active and cooldownWhileDead.suppressedBySkull, "active cooldown is completely suppressed by skull")
Equal(cooldownWhileDead.reason, "suppressedBySkull", "skull suppression diagnostic reason")
ns.ApplyMUFCooldownVisibility(ownerCooldownHolder, cooldownWhileDead)
Equal(ownerCooldownHolder.alpha, 0, "death hides the cooldown holder instead of merely layering above it")
local cooldownStartedDead = ns.ResolveMUFCooldownPresentation(true, true, true)
Check(not cooldownStartedDead.active, "cooldown starting while dead never becomes visible")
local startedDeadHolder = NewCooldownHolder()
ns.ApplyMUFCooldownVisibility(startedDeadHolder, cooldownStartedDead)
Equal(startedDeadHolder.alpha, 0, "cooldown holder starts hidden while dead")
local activeAfterRez = ns.ResolveMUFCooldownPresentation(true, false, false)
Check(activeAfterRez.active, "unexpired current cooldown resumes after resurrection")
ns.ApplyMUFCooldownVisibility(ownerCooldownHolder, activeAfterRez)
Equal(ownerCooldownHolder.alpha, 1, "unexpired holder becomes visible after resurrection")
local expiredAfterRez = ns.ResolveMUFCooldownPresentation(false, false, false)
Check(not expiredAfterRez.active, "expired cooldown stays clear after resurrection")
ns.ApplyMUFCooldownVisibility(ownerCooldownHolder, expiredAfterRez)
Equal(ownerCooldownHolder.alpha, 0, "expired holder remains hidden after resurrection")
local followerCooldown = ns.ResolveMUFCooldownPresentation(true, false, false)
Check(followerCooldown.active and not cooldownWhileDead.active, "follower cooldown remains isolated from dead owner")
local followerCooldownHolder = NewCooldownHolder()
ns.ApplyMUFCooldownVisibility(followerCooldownHolder, followerCooldown)
Equal(followerCooldownHolder.alpha, 1, "alive follower holder stays visible while owner is dead")
local secretCooldownSkull = {secret = true}
local secretCooldown = ns.ResolveMUFCooldownPresentation(true, secretCooldownSkull, false)
local secretCooldownHolder = NewCooldownHolder()
ns.ApplyMUFCooldownVisibility(secretCooldownHolder, secretCooldown)
Check(secretCooldownHolder.booleanValue == secretCooldownSkull, "secret skull state reaches native cooldown alpha widget unchanged")
combat = true
local combatDeadCooldown = ns.ResolveMUFCooldownPresentation(true, true, true)
Check(not combatDeadCooldown.active, "combat follower/death transition suppresses cooldown without layout mutation")
ns.ApplyMUFCooldownVisibility(ownerCooldownHolder, combatDeadCooldown)
Equal(ownerCooldownHolder.alpha, 0, "repeated combat death transition keeps cooldown hidden")
combat = false

local layouts = 0
ns.LayoutMUFs = function()
  layouts = layouts + 1
end
combat = true
ns.RefreshMUFs()
Equal(layouts, 0, "combat defers MUF layout and secure mutation")
combat = false
ns.RefreshMUFs()
Equal(layouts, 1, "deferred visual refresh can run after combat")

io.write("visual-parity: ok\n")
