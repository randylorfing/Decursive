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

local ADDON_NAME, ns = ...

if ns.DiagnosticCheckpoint then
  ns.DiagnosticCheckpoint("module", "MUFs file start")
end

local POOL_SIZE = 80
local BORDER_PX = 2
local WHITE = "Interface\\Buttons\\WHITE8x8"
local MACRO_BYTE_LIMIT = 255
local PVP_BANDAGE_SPELL = 212640
local SOUL_LINK_ITEM_ID = 269586
local SOUL_LINK_RANGE_SPELL = 1259646
local SKULL_TEXTURE = 137008
local COLOR_DEAD = {0, 0, 0, 1}
local COLOR_DEAD_CLEAR = {0, 0, 0, 0}
local COLOR_SKULL = {1, 1, 1, 1}
local COLOR_SKULL_CLEAR = {1, 1, 1, 0}
local COLOR_SL_IN = {0, 0.82, 0.18, 1}
local COLOR_SL_OUT = {1, 0.82, 0, 1}
local COLOR_FAIL = {1, 0.08, 0.08, 1}
local COLOR_READY = {0.10, 1.00, 0.24, 1}
local COLOR_CLEAR = {1, 1, 1, 0}
local COLOR_RANGE_YELLOW = {1.00, 0.82, 0.00, 1}
local COLOR_RANGE_OVERLAY = {1, 1, 0, 1}
local COLOR_STATUS_READY = {0.34, 0.34, 0.34, 0}
local STATUS_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local FRIENDLY_TYPES = {
  magic = true,
  curse = true,
  poison = true,
  disease = true,
}

local MOUSE_BUTTONS = {
  {key = "left", index = 1, binding = "*%s1"},
  {key = "right", index = 2, binding = "*%s2"},
  {key = "middle", index = 3, binding = "*%s3"},
  {key = "button4", index = 4, binding = "*%s4"},
  {key = "button5", index = 5, binding = "*%s5"},
}

local AUTO_CURE_GESTURES = {
  "*%s1",
  "*%s2",
  "ctrl-%s1",
}

local TARGET_GESTURE = "*%s3"
local FOCUS_GESTURE = "ctrl-%s3"
local PVP_BANDAGE_GESTURE = "*%s5"
local PHYSICAL_LEFT = "*%s1"

local GESTURE_PREFIXES = {"", "*", "ctrl-", "shift-", "alt-"}

local header
local handle
local pool = {}
local poolReady = false
local pending = false
local eventsOn = false
local eventFrame
local cooldownStates = {}
local cooldownPending = {}
local cooldownGeneration = {0, 0, 0}
local cureAttempt
local rangeElapsed = 0
local paintElapsed = 0
local colorObjects = {}
local mufsConfigured = false
local clickModel
local clickModelSig
local clickModelGeneration = 0
local AttachCooldownGates
local SetCooldownGateActive
local ReconcileCooldowns
local displayCapDiagnostics = {
	eligibleMembers = 0,
	eligiblePets = 0,
	displayedMembers = 0,
	displayedPets = 0,
	omittedMembers = 0,
	omittedPets = 0,
	orphanPets = 0,
	duplicatePets = 0,
	configuredCap = 0,
}

local function Addon()
  return ns.addon
end

local function GetPack()
  local addon = Addon()
  if addon and addon.GetAppliedEnvironmentPack then
    return addon:GetAppliedEnvironmentPack()
  end
  return ns.PACK
end

local function GetEnv()
  local addon = Addon()
  if addon and addon.GetAppliedEnvironment then
    return addon:GetAppliedEnvironment()
  end
  return "OPEN_WORLD"
end

local function Accessible(value)
  if value == nil then
    return true
  end
  if type(issecretvalue) == "function" and issecretvalue(value) then
    if type(canaccessvalue) == "function" then
      return canaccessvalue(value) == true
    end
    return false
  end
  return true
end

local function Public(value)
  if not Accessible(value) then
    return nil
  end
  return value
end

local function IsTrue(value)
  if not Accessible(value) then
    return false
  end
  return value == true or value == 1
end

local function LockedDown()
  return InCombatLockdown and InCombatLockdown()
end

local PASS_BUTTONS = {"LeftButton", "RightButton", "MiddleButton", "Button4", "Button5"}

local function PassClicks(frame)
  if not frame then
    return
  end
  if LockedDown() then
    return
  end
  if frame.EnableMouse then
    frame:EnableMouse(false)
  end
  if frame.SetMouseClickEnabled then
    frame:SetMouseClickEnabled(false)
  end
  if frame.SetMouseMotionEnabled then
    frame:SetMouseMotionEnabled(false)
  end
  if frame.SetPropagateMouseClicks then
    frame:SetPropagateMouseClicks(true)
  end
  if frame.SetPassThroughButtons then
    frame:SetPassThroughButtons(PASS_BUTTONS[1], PASS_BUTTONS[2], PASS_BUTTONS[3], PASS_BUTTONS[4], PASS_BUTTONS[5])
  end
end

local function ColorOf(c, fallback)
  if type(c) == "table" then
    return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
  end
  if type(fallback) == "table" then
    return fallback[1], fallback[2], fallback[3], fallback[4] or 1
  end
  return 0.12, 0.16, 0.18, 1
end

local function ColorObject(c)
  if type(c) ~= "table" or not CreateColor then
    return nil
  end
  local key = tostring(c[1] or 0) .. "," .. tostring(c[2] or 0) .. "," .. tostring(c[3] or 0) .. "," .. tostring(c[4] or 1)
  local obj = colorObjects[key]
  if not obj then
    obj = CreateColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
    colorObjects[key] = obj
  end
  return obj
end

local function NormalizeBooleanWidgetValue(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then
    return value
  end
  if value == nil then
    return false
  end
  return value
end

ns.NormalizeMUFBooleanWidgetValue = NormalizeBooleanWidgetValue

local function ApplyBooleanVertex(tex, value, onColor, offColor)
  if not tex then
    return false
  end
  value = NormalizeBooleanWidgetValue(value)
  local onObj = ColorObject(onColor)
  local offObj = ColorObject(offColor)
  if tex.SetVertexColorFromBoolean and onObj and offObj then
    tex:SetVertexColorFromBoolean(value, onObj, offObj)
    return true
  end
  if Accessible(value) then
    local c = (value == true or value == 1) and onColor or offColor
    local r, g, b, a = ColorOf(c)
    if tex.SetVertexColor then
      tex:SetVertexColor(r, g, b, a)
    end
    return true
  end
  return false
end

local function ReadDeathValue(unit)
  if type(UnitIsConnected) == "function" then
    local connectedOK, connected = pcall(UnitIsConnected, unit)
    if connectedOK and Accessible(connected) and connected == false then
      return true, "PUBLIC_OFFLINE"
    end
  end
  if type(UnitIsDeadOrGhost) ~= "function" then
    return nil, "API_UNAVAILABLE"
  end
  local ok, value = pcall(UnitIsDeadOrGhost, unit)
  if not ok then
    return nil, "API_FAILED"
  end
  if not Accessible(value) then
    return value, "SECRET_NATIVE"
  end
  if value == true or value == 1 then
    return true, "PUBLIC_DEAD"
  end
  if value == false or value == 0 then
    return false, "PUBLIC_ALIVE"
  end
  return nil, "VALUE_UNAVAILABLE"
end

ns.ReadMUFDeathValue = ReadDeathValue

local function StealthedValue(unit)
  if not UnitIsStealthed then
    return false
  end
  return UnitIsStealthed(unit)
end

local function SoulLinkRangeValue(unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  if C_Spell and C_Spell.IsSpellInRange then
    local ok, result = pcall(C_Spell.IsSpellInRange, SOUL_LINK_RANGE_SPELL, unit)
    if ok then
      return result
    end
  end
  if ns.SpellRangeState then
    return ns.SpellRangeState(unit, nil, SOUL_LINK_RANGE_SPELL)
  end
  return false
end

local function SoulLinkFallbackApplies(unit)
  if type(unit) ~= "string" then
    return false
  end
  if ns.IsMUFRezEligibleUnitToken then
    if ns.IsMUFRezEligibleUnitToken(unit) ~= true then
      return false
    end
  elseif unit:lower():find("pet", 1, true) then
    return false
  end
  if not ns.GetSmartRezActions then
    return false
  end
  local _battle, _ooc, combatSoulLink, outOfCombatSoulLink = ns.GetSmartRezActions(GetPack())
  return combatSoulLink == true or outOfCombatSoulLink == true
end

local function IdentityTooltipAllowed(pack)
  if not pack or not pack.mufs or pack.mufs.tooltip == false then
    return false
  end
  if not IsInInstance then
    return false
  end
  local inInstance, instanceType = IsInInstance()
  instanceType = Public(instanceType)
  if inInstance ~= true then
    return false
  end
  return instanceType == "party" or instanceType == "raid"
end

local function DisplayMutationBlocked()
  return LockedDown()
end

local function ApplyColor(tex, c, a)
  if not tex then
    return
  end
  local r, g, b, alpha = ColorOf(c)
  tex:SetColorTexture(r, g, b, a or alpha)
end

local function ClassBorderColor(unit)
  if UnitClass then
    local _name, classFile = UnitClass(unit)
    classFile = Public(classFile)
    if type(classFile) == "string" then
      if C_ClassColor and C_ClassColor.GetClassColor then
        local ok, color = pcall(C_ClassColor.GetClassColor, classFile)
        if ok and color then
          local red, green, blue, alpha
          if color.GetRGBA then
            local rgbaOk
            rgbaOk, red, green, blue, alpha = pcall(color.GetRGBA, color)
            if not rgbaOk then
              red, green, blue, alpha = nil, nil, nil, nil
            end
          else
            red, green, blue, alpha = color.r, color.g, color.b, color.a
          end
          if Accessible(red) and Accessible(green) and Accessible(blue)
            and type(red) == "number" and type(green) == "number" and type(blue) == "number"
          then
            return red, green, blue, type(alpha) == "number" and alpha or 1
          end
        end
      end
      if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return color.r or 1, color.g or 1, color.b or 1, 1
      end
    end
  end
  return nil
end

local function UnitPresent(unit)
  if not unit or not UnitExists then
    return unit ~= nil
  end
  local exists = UnitExists(unit)
  if not Accessible(exists) then
    return true
  end
  return exists == true
end

local function IsPlayerToken(unit)
  if unit == "player" then
    return true
  end
  if UnitIsUnit then
    local same = UnitIsUnit(unit, "player")
    if Accessible(same) and same then
      return true
    end
  end
  return false
end

local function IsPubliclyDead(unit)
  if not UnitIsDeadOrGhost then
    return false
  end
  local dead = UnitIsDeadOrGhost(unit)
  if not Accessible(dead) then
    return false
  end
  return dead == true
end

local function IsPetUnitToken(unit)
  if unit == "pet" then
    return true
  end
  if type(unit) ~= "string" then
    return false
  end
  return unit:match("^partypet%d+$") ~= nil or unit:match("^raidpet%d+$") ~= nil
end

local function InnerMUFSize(frameSize, borderOn)
  local inset = borderOn and BORDER_PX or 0
  return math.max(4, frameSize - inset * 2)
end

local COOLDOWN_TEXT_SCALE = 0.90

function ns.CalculateMUFCooldownTextMetrics(width, height)
  if type(width) ~= "number" or not Accessible(width) or width <= 0 then
    width = 1
  end
  if type(height) ~= "number" or not Accessible(height) or height <= 0 then
    height = 1
  end
  local boundedWidth = math.max(1, width)
  local boundedHeight = math.max(1, height)
  local fontSize = math.max(1, math.min(width, height) * COOLDOWN_TEXT_SCALE)
  return {
    fontSize = fontSize,
    width = boundedWidth,
    height = boundedHeight,
  }
end

function ns.ApplyMUFCooldownTextMetrics(textFrame, width, height, anchor)
  if not textFrame then
    return nil
  end
  local metrics = ns.CalculateMUFCooldownTextMetrics(width, height)
  if textFrame.SetPoint then
    if anchor then
      textFrame:SetPoint("CENTER", anchor, "CENTER")
    else
      textFrame:SetPoint("CENTER")
    end
  end
  if textFrame.SetJustifyH then
    textFrame:SetJustifyH("CENTER")
  end

  local fontHeightApplied = false
  if textFrame.SetFontHeight then
    fontHeightApplied = pcall(textFrame.SetFontHeight, textFrame, metrics.fontSize)
  end
  if not fontHeightApplied and textFrame.SetFont then
    local fontPath
    local fontFlags
    if textFrame.GetFont then
      local ok, currentPath, _currentSize, currentFlags = pcall(textFrame.GetFont, textFrame)
      if ok and Accessible(currentPath) and type(currentPath) == "string" and currentPath ~= "" then
        fontPath = currentPath
      end
      if ok and Accessible(currentFlags) and type(currentFlags) == "string" then
        fontFlags = currentFlags
      end
    end
    if not fontPath and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
      fontPath = STANDARD_TEXT_FONT
    end
    if not fontPath then
      fontPath = "Fonts\\FRIZQT__.TTF"
    end
    pcall(textFrame.SetFont, textFrame, fontPath, metrics.fontSize, fontFlags or "OUTLINE")
  end
  return metrics
end

function ns.GetMUFVisualMetrics(baseSize, borderOn, unit)
  if type(baseSize) ~= "number" then
    baseSize = 20
  end
  local frameSize = baseSize
  if IsPetUnitToken(unit) then
    frameSize = math.max(8, baseSize - 4)
  end
  return frameSize, InnerMUFSize(frameSize, borderOn)
end

function ns.GetMUFStatusLightMetrics(baseSize, enabled)
  if enabled ~= true then
    return 0, 0, 0
  end
  if type(baseSize) ~= "number" then
    baseSize = 20
  end
  local lightSize = baseSize * 0.25
  local gap = math.max(1, baseSize * 0.075)
  return lightSize, gap, lightSize + gap
end

function ns.GetMUFGridMetrics(size, hSpace, vSpace, statusLight, cols, rows)
  local _lightSize, _lightGap, reserve = ns.GetMUFStatusLightMetrics(size, statusLight)
  local horizontalStride = size + hSpace
  local verticalStride = size + vSpace + reserve
  local width = cols * size + math.max(cols - 1, 0) * hSpace
  local height = rows * size + math.max(rows - 1, 0) * (vSpace + reserve) + reserve
  return horizontalStride, verticalStride, width, height, reserve
end

function ns.CalculateMUFLayout(count, size, hSpace, vSpace, statusLight, perLine, verticalLayout, growUp, growFromRight)
  count = math.max(0, math.floor(tonumber(count) or 0))
  size = math.max(1, tonumber(size) or 20)
  hSpace = math.max(0, tonumber(hSpace) or 0)
  vSpace = math.max(0, tonumber(vSpace) or 0)
  perLine = math.max(1, math.min(40, math.floor(tonumber(perLine) or 10)))
  verticalLayout = verticalLayout == true
  growUp = growUp == true
  growFromRight = growFromRight == true

  local cols
  local rows
  if verticalLayout then
    rows = math.min(perLine, count)
    cols = math.ceil(math.max(count, 1) / perLine)
  else
    cols = math.min(perLine, count)
    rows = math.ceil(math.max(count, 1) / perLine)
  end
  if count == 0 then
    cols, rows = 1, 1
  end

  local horizontalStride, verticalStride, width, height, statusReserve = ns.GetMUFGridMetrics(
    size, hSpace, vSpace, statusLight, cols, rows
  )
  local anchor
  if growFromRight and growUp then
    anchor = "BOTTOMRIGHT"
  elseif growFromRight then
    anchor = "TOPRIGHT"
  elseif growUp then
    anchor = "BOTTOMLEFT"
  else
    anchor = "TOPLEFT"
  end
  local xDirection = growFromRight and -1 or 1
  local yDirection = growUp and 1 or -1
  local yOrigin = growUp and 0 or -statusReserve
  local positions = {}
  for i = 1, count do
    local index = i - 1
    local line = math.floor(index / perLine)
    local slot = index % perLine
    if verticalLayout then
      positions[i] = {
        x = line * horizontalStride * xDirection,
        y = yOrigin + slot * verticalStride * yDirection,
      }
    else
      positions[i] = {
        x = slot * horizontalStride * xDirection,
        y = yOrigin + line * verticalStride * yDirection,
      }
    end
  end
  return {
    count = count,
    size = size,
    perLine = perLine,
    vertical = verticalLayout,
    cols = cols,
    rows = rows,
    horizontalStride = horizontalStride,
    verticalStride = verticalStride,
    width = width,
    height = height,
    statusReserve = statusReserve,
    anchor = anchor,
    positions = positions,
  }
end

local function PixelSize(pack, env)
  local mufs = pack.mufs
  local partySize = mufs.partySize or 20
  local raidSize = mufs.raidSize or 20
  if env == "RAID" then
    return raidSize
  end
  if env == "DUNGEON" or env == "MYTHIC_PLUS" then
    return partySize
  end
  local members = GetNumGroupMembers and GetNumGroupMembers() or 0
  if type(members) ~= "number" or members <= 5 then
    return partySize
  end
  return raidSize
end

local function Spacing(pack)
  local h = pack.mufs.horizontalSpacing or 2
  local v = pack.mufs.verticalSpacing or 2
  if pack.mufs.linkSpacing then
    v = h
  end
  return h, v
end

function ns.ApplyMUFDisplayCap(units, configuredCap)
	if type(units) ~= "table" then
		return units
	end
	local maxUnits = type(configuredCap) == "number" and configuredCap or (ns.DEFAULT_MUF_DISPLAY_CAP or 5)
  maxUnits = math.floor(maxUnits)
  if maxUnits > POOL_SIZE then
    maxUnits = POOL_SIZE
	elseif maxUnits < 0 then
		maxUnits = 0
	end
	local members = {}
	local pets = {}
	local memberSet = {}
	local petSet = {}
	local duplicatePets = 0
	for i = 1, #units do
		local unit = units[i]
		if IsPetUnitToken(unit) then
			if petSet[unit] then
				duplicatePets = duplicatePets + 1
			else
				petSet[unit] = true
				pets[#pets + 1] = unit
			end
		else
			if not memberSet[unit] then
				memberSet[unit] = true
				members[#members + 1] = unit
			end
		end
	end
	local displayedMembers = math.min(#members, maxUnits)
	local displayedMemberSet = {}
	for i = 1, displayedMembers do
		displayedMemberSet[members[i]] = true
	end
	local eligiblePets = {}
	local orphanPets = 0
	for i = 1, #pets do
		local pet = pets[i]
		local owner
		if pet == "pet" then
			owner = "player"
		else
			local partyIndex = pet:match("^partypet(%d+)$")
			local raidIndex = pet:match("^raidpet(%d+)$")
			owner = partyIndex and "party" .. partyIndex or raidIndex and "raid" .. raidIndex or nil
		end
		if owner and displayedMemberSet[owner] then
			eligiblePets[#eligiblePets + 1] = pet
		else
			orphanPets = orphanPets + 1
		end
	end
	local displayedPets = math.min(#eligiblePets, math.max(0, POOL_SIZE - displayedMembers))
	for i = 1, #units do
		units[i] = nil
	end
	for i = 1, displayedMembers do
		units[#units + 1] = members[i]
	end
	for i = 1, displayedPets do
		units[#units + 1] = eligiblePets[i]
	end
	displayCapDiagnostics = {
		eligibleMembers = #members,
		eligiblePets = #eligiblePets,
		displayedMembers = displayedMembers,
		displayedPets = displayedPets,
		omittedMembers = #members - displayedMembers,
		omittedPets = #eligiblePets - displayedPets,
		orphanPets = orphanPets,
		duplicatePets = duplicatePets,
		configuredCap = maxUnits,
	}
	return units, maxUnits, displayCapDiagnostics
end

local function ShouldShowHeader(pack)
  if not pack.mufs.show then
    return false
  end
  local autoHide = pack.mufs.autoHide or "NEVER"
  if autoHide == "ALWAYS" then
    return false
  end
  if autoHide == "SOLO" then
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members == 0 then
      return false
    end
  end
  return true
end

local function GetSavedPoint()
  local addon = Addon()
  local char = addon and addon.db and addon.db.char
  if char then
    if type(char.mufPoint) ~= "table" then
      char.mufPoint = {point = "CENTER", x = 0, y = 0}
    end
    return char.mufPoint
  end
  return {point = "CENTER", x = 0, y = 0}
end

local function SavePoint()
  if not header then
    return
  end
  local point, _, _, x, y = header:GetPoint()
  local saved = GetSavedPoint()
  saved.point = point or "CENTER"
  saved.x = x or 0
  saved.y = y or 0
end

local function RestorePoint()
  if not header then
    return
  end
  local saved = GetSavedPoint()
  local point = saved.point or "CENTER"
  header:ClearAllPoints()
  header:SetPoint(point, UIParent, point, saved.x or 0, saved.y or 0)
end

local function BindAuraSlot(slot, pack, cover, slotInfo)
  if not slot then
    return
  end
  local host = cover
  if host and host.GetParent then
    host = host:GetParent() or host
  end
  local baseLevel = host and host.GetFrameLevel and host:GetFrameLevel() or 0
  if ns.ConfigureMUFDispelPresentation then
    ns.ConfigureMUFDispelPresentation(slot, pack, cover, baseLevel, host, slotInfo)
  end
  local tooltip = pack and pack.mufs and pack.mufs.tooltip ~= false
  if slot.SetTooltipAnchorPoint then
    slot:SetTooltipAnchorPoint("ANCHOR_RIGHT", 8, 0)
  end
  if slot.SetHideTooltipInCombat then
    slot:SetHideTooltipInCombat(false)
  end
  if slot.EnableMouse then
    slot:EnableMouse(tooltip)
  end
  if slot.SetMouseClickEnabled then
    slot:SetMouseClickEnabled(false)
  end
  if slot.SetPropagateMouseClicks then
    slot:SetPropagateMouseClicks(true)
  end
  if slot.SetPassThroughButtons then
    slot:SetPassThroughButtons(PASS_BUTTONS[1], PASS_BUTTONS[2], PASS_BUTTONS[3], PASS_BUTTONS[4], PASS_BUTTONS[5])
  end
  if slot.SetMouseMotionEnabled then
    slot:SetMouseMotionEnabled(tooltip)
  end
  if ns.ConfigureDispelAlertSlot then
    ns.ConfigureDispelAlertSlot(slot)
  end
end

local function DistinctFriendlyCures(pack)
  local actions = ns.GetKnownCures and ns.GetKnownCures(pack) or {}
  local out = {}
  local seen = {}
  for i = 1, #actions do
    local action = actions[i]
    local spellId = action and action.spellId
    local itemId = action and action.itemId
    local name = action and action.name
    local seenKey
    if type(spellId) == "number" and spellId > 0 then
      seenKey = "spell:" .. tostring(spellId)
    elseif type(itemId) == "number" and itemId > 0 then
      seenKey = "item:" .. tostring(itemId)
    end
    if seenKey and not seen[seenKey] and type(name) == "string" and name ~= "" then
      local types = action.types
      local friendly = false
      if type(types) == "table" then
        for t = 1, #types do
          if FRIENDLY_TYPES[types[t]] then
            friendly = true
            break
          end
        end
      end
      if friendly then
        seen[seenKey] = true
        out[#out + 1] = action
      end
    end
  end
  return out
end

local function BuildSmartRezMacroText(cureCommand, cureName, cureUsesPet)
  local battleRezName, outOfCombatRezName, combatSoulLink, outOfCombatSoulLink
  if ns.GetSmartRezActions then
    battleRezName, outOfCombatRezName, combatSoulLink, outOfCombatSoulLink = ns.GetSmartRezActions(GetPack())
  end
  local hasRezAction = battleRezName ~= nil or outOfCombatRezName ~= nil or combatSoulLink or outOfCombatSoulLink
  local combatClause = "[@mouseover,help,exists,dead,combat]"
  local outOfCombatClause = "[@mouseover,help,exists,dead,nocombat]"
  local friendlyCureClause = "[@mouseover,help,exists,nodead]"
  local hostileCureClause = "[@mouseover,harm,exists,nodead]"

  local function build(includeRez, includeCure)
    local lines = {}
    local castActions = {}
    local useActions = {}
    if includeRez then
      if battleRezName and outOfCombatRezName == battleRezName then
        castActions[#castActions + 1] = combatClause .. outOfCombatClause .. " " .. battleRezName
      else
        if battleRezName then
          castActions[#castActions + 1] = combatClause .. " " .. battleRezName
        end
        if outOfCombatRezName then
          castActions[#castActions + 1] = outOfCombatClause .. " " .. outOfCombatRezName
        end
      end
      if combatSoulLink and outOfCombatSoulLink then
        useActions[#useActions + 1] = combatClause .. outOfCombatClause .. " item:269586"
      else
        if combatSoulLink then
          useActions[#useActions + 1] = combatClause .. " item:269586"
        end
        if outOfCombatSoulLink then
          useActions[#useActions + 1] = outOfCombatClause .. " item:269586"
        end
      end
    end
    if includeCure and type(cureName) == "string" and cureName ~= "" then
      local cureAction = friendlyCureClause .. hostileCureClause .. " " .. cureName
      if cureCommand == "use" then
        useActions[#useActions + 1] = cureAction
      else
        castActions[#castActions + 1] = cureAction
      end
    end
    if includeRez and hasRezAction then
      if includeCure and cureUsesPet then
        lines[#lines + 1] = "/stopcasting [@mouseover,help,exists,dead]"
      else
        lines[#lines + 1] = "/stopcasting"
      end
    elseif includeCure and not cureUsesPet then
      lines[#lines + 1] = "/stopcasting"
    end
    if #castActions > 0 then
      lines[#lines + 1] = "/cast " .. table.concat(castActions, ";")
    end
    if #useActions > 0 then
      lines[#lines + 1] = "/use " .. table.concat(useActions, ";")
    end
    return table.concat(lines, "\n")
  end

  local combined = build(true, cureName ~= nil)
  local cureOnly = build(false, cureName ~= nil)
  local rezOnly = build(true, false)
  return combined, cureOnly, rezOnly, hasRezAction
end

local function MakeCureRow(action, binding, priority)
  if type(action) ~= "table" or type(action.name) ~= "string" or action.name == "" then
    return nil
  end
  local spellId = action.spellId or 0
  local command = "use"
  if type(spellId) == "number" and spellId > 0 then
    command = "cast"
  end
  local combined, cureOnly, rezOnly, hasRez = BuildSmartRezMacroText(command, action.name, action.pet == true)
  if type(cureOnly) ~= "string" or #cureOnly > MACRO_BYTE_LIMIT then
    return nil
  end
  local actionKey = "spell:" .. tostring(spellId)
  if (type(spellId) ~= "number" or spellId <= 0) and type(action.itemId) == "number" and action.itemId > 0 then
    actionKey = "item:" .. tostring(action.itemId)
  end
  local row = {
    binding = binding,
    priority = priority,
    actionKey = actionKey,
    spellName = action.name,
    spellId = spellId,
    baseId = action.baseId,
    types = action.types,
    cureOnlyMacroText = cureOnly,
    rezOnlyMacroText = "",
    smartRezAvailable = false,
    customMacro = false,
  }
  if type(combined) == "string" and #combined <= MACRO_BYTE_LIMIT then
    row.macroText = combined
    row.smartRezAvailable = hasRez == true
  else
    row.macroText = cureOnly
    row.smartRezAvailable = false
  end
  if type(rezOnly) == "string" and #rezOnly <= MACRO_BYTE_LIMIT then
    row.rezOnlyMacroText = rezOnly
  else
    row.rezOnlyMacroText = ""
  end
  return row
end

local function ScanPvPBandage()
  if LockedDown() then
    return clickModel and clickModel.bandage or nil
  end
  local itemAPI = C_Item
  local containerAPI = C_Container
  if type(itemAPI) ~= "table" or type(containerAPI) ~= "table" then
    return nil
  end
  if type(itemAPI.GetItemSpell) ~= "function" or type(containerAPI.GetContainerNumSlots) ~= "function" then
    return nil
  end
  local first = 0
  local last = NUM_BAG_SLOTS or 4
  local bagEnum = Enum and Enum.BagIndex
  if bagEnum and type(bagEnum.Backpack) == "number" then
    first = bagEnum.Backpack
  end
  local best
  for bag = first, last do
    local okSlots, nSlots = pcall(containerAPI.GetContainerNumSlots, bag)
    if okSlots and type(nSlots) == "number" and nSlots > 0 then
      for slot = 1, nSlots do
        local okInfo, info = pcall(containerAPI.GetContainerItemInfo, bag, slot)
        if okInfo and type(info) == "table" then
          local itemID = info.itemID
          if type(itemID) == "number" and Accessible(itemID) and itemID > 0 then
            local okSpell, _name, useSpellID = pcall(itemAPI.GetItemSpell, itemID)
            if okSpell and Accessible(useSpellID) and useSpellID == PVP_BANDAGE_SPELL then
              local count = 0
              if itemAPI.GetItemCount then
                local okCount, c = pcall(itemAPI.GetItemCount, itemID, false, false, false, false)
                if okCount and Accessible(c) and type(c) == "number" then
                  count = c
                end
              end
              if count > 0 then
                local usable = true
                if itemAPI.IsUsableItem then
                  local okUse, u = pcall(itemAPI.IsUsableItem, itemID)
                  if okUse and Accessible(u) then
                    usable = u == true
                  end
                end
                if usable then
                  best = {itemID = itemID, actionKey = "pvp-bandage:item:" .. tostring(itemID)}
                end
              end
            end
          end
        end
      end
    end
  end
  return best
end

local function CustomMacroText()
  local pack = GetPack()
  local advanced = pack.advanced
  if type(advanced) ~= "table" or advanced.allowMacroEdit ~= true then
    return nil
  end
  local text = advanced.customMacro
  if type(text) ~= "string" or text == "" then
    return nil
  end
  text = text:gsub("UNITID", "mouseover")
  if #text > MACRO_BYTE_LIMIT then
    return nil
  end
  return text
end

local function ClickSignature(pack)
  local bits = {}
  bits[#bits + 1] = pack.cure and pack.cure.mode or "AUTO"
  local mouse = pack.mouse or {}
  bits[#bits + 1] = tostring(mouse.left)
  bits[#bits + 1] = tostring(mouse.right)
  bits[#bits + 1] = tostring(mouse.middle)
  bits[#bits + 1] = tostring(mouse.button4)
  bits[#bits + 1] = tostring(mouse.button5)
  local manual = pack.cure and pack.cure.manual
  if type(manual) == "table" then
    local keys = {}
    for k, v in pairs(manual) do
      keys[#keys + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(keys)
    bits[#bits + 1] = table.concat(keys, ",")
  end
  local cures = DistinctFriendlyCures(pack)
  for i = 1, #cures do
    local action = cures[i]
    local bit = "spell:" .. tostring(action.spellId)
    if type(action.itemId) == "number" and action.itemId > 0 then
      bit = bit .. "/item:" .. tostring(action.itemId)
    end
    bits[#bits + 1] = bit
  end
  local advanced = pack.advanced
  if type(advanced) == "table" then
    bits[#bits + 1] = tostring(advanced.allowMacroEdit)
    bits[#bits + 1] = tostring(advanced.customMacro)
  end
  return table.concat(bits, "|")
end

local function ReservedGesture(binding)
  return binding == TARGET_GESTURE or binding == FOCUS_GESTURE
end

local function BandageRow(bandage)
  if not bandage or type(bandage.itemID) ~= "number" then
    return nil
  end
  local macro = ("/use [@mouseover,help,exists,nodead] item:%d"):format(bandage.itemID)
  if #macro > MACRO_BYTE_LIMIT then
    return nil
  end
  return {
    binding = PVP_BANDAGE_GESTURE,
    macroText = macro,
    cureOnlyMacroText = macro,
    rezOnlyMacroText = "",
    smartRezAvailable = false,
    pvpBandage = true,
    actionKey = bandage.actionKey,
  }
end

function ns.RebuildClickModel(pack)
  if LockedDown() then
    pending = true
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("CLICK_MODEL", {result = "DEFERRED"}, false)
    end
    return clickModel
  end
  pack = pack or GetPack()
  local sig = ClickSignature(pack)
  if clickModel and clickModelSig == sig then
    return clickModel
  end
  local mode = pack.cure and pack.cure.mode
  if mode ~= "MANUAL" then
    mode = "AUTO"
  end
  local cures = DistinctFriendlyCures(pack)
  local bandage = ScanPvPBandage()
  local rows = {}
  local used = {
    [TARGET_GESTURE] = true,
    [FOCUS_GESTURE] = true,
  }
  if bandage then
    used[PVP_BANDAGE_GESTURE] = true
  end

  if mode == "AUTO" then
    for i = 1, #AUTO_CURE_GESTURES do
      local action = cures[i]
      if action then
        local row = MakeCureRow(action, AUTO_CURE_GESTURES[i], i)
        if row then
          rows[#rows + 1] = row
          used[row.binding] = true
        end
      end
    end
  else
    local mouse = pack.mouse or {}
    local manual = pack.cure and pack.cure.manual
    local assigned = {}
    if type(manual) == "table" then
      local keyToBinding = {
        left = "*%s1",
        right = "*%s2",
        button4 = "*%s4",
        button5 = "*%s5",
      }
      for i = 1, #cures do
        local action = cures[i]
        local actionKey = "spell:" .. tostring(action.spellId)
        local itemKey
        if type(action.itemId) == "number" and action.itemId > 0 then
          itemKey = "item:" .. tostring(action.itemId)
        end
        local binding = keyToBinding[manual[actionKey]]
        if not binding and itemKey then
          binding = keyToBinding[manual[itemKey]]
        end
        if binding and not ReservedGesture(binding) and not used[binding] then
          if not (bandage and binding == PVP_BANDAGE_GESTURE) then
            local row = MakeCureRow(action, binding, i)
            if row then
              rows[#rows + 1] = row
              used[binding] = true
              assigned[action.spellId] = true
            end
          end
        end
      end
    end
    local cureIndex = 1
    for i = 1, #MOUSE_BUTTONS do
      local spec = MOUSE_BUTTONS[i]
      local binding = spec.binding
      if not ReservedGesture(binding) and not used[binding] and mouse[spec.key] == "CURE" then
        if not (bandage and binding == PVP_BANDAGE_GESTURE) then
          while cureIndex <= #cures and assigned[cures[cureIndex].spellId] do
            cureIndex = cureIndex + 1
          end
          local action = cures[cureIndex]
          if action then
            local row = MakeCureRow(action, binding, cureIndex)
            if row then
              rows[#rows + 1] = row
              used[binding] = true
              assigned[action.spellId] = true
              cureIndex = cureIndex + 1
            end
          end
        end
      end
    end
  end

  local bandageRow = BandageRow(bandage)
  if bandageRow then
    rows[#rows + 1] = bandageRow
  end

  local custom = CustomMacroText()
  if custom then
    local replaced = false
    for i = 1, #rows do
      if rows[i].binding == PHYSICAL_LEFT then
        rows[i].macroText = custom
        rows[i].cureOnlyMacroText = custom
        rows[i].customMacro = true
        rows[i].priority = nil
        rows[i].smartRezAvailable = false
        replaced = true
        break
      end
    end
    if not replaced then
      rows[#rows + 1] = {
        binding = PHYSICAL_LEFT,
        macroText = custom,
        cureOnlyMacroText = custom,
        rezOnlyMacroText = "",
        customMacro = true,
        smartRezAvailable = false,
      }
    end
  end

  clickModel = {
    mode = mode,
    rows = rows,
    bandage = bandage,
  }
  clickModelSig = sig
  clickModelGeneration = clickModelGeneration + 1
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("CLICK_MODEL", {
      mode = mode,
      mappings = #rows,
      bandage = bandage ~= nil,
      custom = custom ~= nil,
      generation = clickModelGeneration,
    }, true)
  end
  return clickModel
end

function ns.GetResolvedClickStatus()
  local pack = GetPack()
  local model = ns.RebuildClickModel(pack)
  local status = {
    mode = pack and pack.cure and pack.cure.mode == "MANUAL" and "MANUAL" or "AUTO",
    generation = clickModelGeneration,
    pending = pending == true,
    mappings = {
      {gesture = "Middle", action = "Target", kind = "TARGET"},
      {gesture = "Ctrl+Middle", action = "Focus", kind = "FOCUS"},
    },
  }
  if type(model) ~= "table" or type(model.rows) ~= "table" then
    status.available = false
    return status
  end
  status.available = true
  for i = 1, #model.rows do
    local row = model.rows[i]
    if type(row) == "table" and type(row.binding) == "string" then
      local gesture = row.binding
        :gsub("%%s", "")
        :gsub("%*", "")
        :gsub("ctrl%-", "Ctrl+")
        :gsub("shift%-", "Shift+")
        :gsub("alt%-", "Alt+")
      gesture = gesture
        :gsub("1", "Left")
        :gsub("2", "Right")
        :gsub("3", "Middle")
        :gsub("4", "Button 4")
        :gsub("5", "Button 5")
      local action = row.spellName
      local kind = "CURE"
      if row.customMacro then
        action = "Custom macro"
        kind = "CUSTOM_MACRO"
      elseif row.pvpBandage then
        action = "PvP bandage"
        kind = "PVP_BANDAGE"
      elseif type(action) ~= "string" or action == "" then
        action = "Unknown"
        kind = "UNKNOWN"
      end
      status.mappings[#status.mappings + 1] = {
        gesture = gesture,
        action = action,
        kind = kind,
        spellId = type(row.spellId) == "number" and row.spellId or nil,
      }
    end
  end
  return status
end

local function SetSecure(btn, attr, value)
  if LockedDown() then
    return false
  end
  btn:SetAttribute(attr, value)
  return true
end

local function ClearClickAttributes(btn)
  if LockedDown() then
    return
  end
  for i = 1, 5 do
    for p = 1, #GESTURE_PREFIXES do
      local prefix = GESTURE_PREFIXES[p]
      btn:SetAttribute(prefix .. "type" .. i, nil)
      btn:SetAttribute(prefix .. "spell" .. i, nil)
      btn:SetAttribute(prefix .. "macro" .. i, nil)
      btn:SetAttribute(prefix .. "macrotext" .. i, nil)
      btn:SetAttribute(prefix .. "unit" .. i, nil)
    end
  end
end

local function RezEligible(unit)
  if ns.IsMUFRezEligibleUnitToken then
    return ns.IsMUFRezEligibleUnitToken(unit) == true
  end
  if type(unit) ~= "string" then
    return false
  end
  return not unit:lower():find("pet", 1, true)
end

local function ApplyClickAttributes(btn, pack, unit)
  if LockedDown() then
    pending = true
    return false
  end
  ClearClickAttributes(btn)
  btn.cureRows = {}
  SetSecure(btn, "unit", unit)
  local model = ns.RebuildClickModel(pack)
  if not model then
    return false
  end

  SetSecure(btn, TARGET_GESTURE:format("type"), "target")
  SetSecure(btn, TARGET_GESTURE:format("unit"), unit)
  SetSecure(btn, FOCUS_GESTURE:format("type"), "focus")
  SetSecure(btn, FOCUS_GESTURE:format("unit"), unit)

  local installed = {
    [TARGET_GESTURE] = true,
    [FOCUS_GESTURE] = true,
  }
  local rezOk = RezEligible(unit)
  local leftAssigned = false
  local leftReserved = false

  for i = 1, #model.rows do
    local row = model.rows[i]
    local binding = row.binding
    if binding then
      if binding == PHYSICAL_LEFT and row.customMacro then
        leftReserved = true
      end
      local macroText
      if binding == PHYSICAL_LEFT and rezOk and row.smartRezAvailable then
        macroText = row.macroText
      else
        macroText = row.cureOnlyMacroText or row.macroText
      end
      if type(macroText) == "string" and macroText ~= "" and #macroText <= MACRO_BYTE_LIMIT then
        SetSecure(btn, binding:format("type"), "macro")
        SetSecure(btn, binding:format("macrotext"), macroText)
        installed[binding] = true
        if not row.customMacro and type(row.priority) == "number" and type(row.spellId) == "number" and row.spellId > 0 then
          btn.cureRows[binding] = row
        end
        if binding == PHYSICAL_LEFT then
          leftAssigned = true
        end
      end
    end
  end

  if rezOk and not leftReserved and not leftAssigned then
    local leftover
    for i = 1, #model.rows do
      if type(model.rows[i].rezOnlyMacroText) == "string" then
        leftover = model.rows[i].rezOnlyMacroText
        break
      end
    end
    if leftover == nil then
      local _combined, _cure, rezOnly = BuildSmartRezMacroText("cast", nil, false)
      leftover = rezOnly
    end
    if leftover ~= "" and type(leftover) == "string" and #leftover <= MACRO_BYTE_LIMIT then
      SetSecure(btn, PHYSICAL_LEFT:format("type"), "macro")
      SetSecure(btn, PHYSICAL_LEFT:format("macrotext"), leftover)
      leftAssigned = true
      installed[PHYSICAL_LEFT] = true
    end
  end

  return true
end

local function IdentitySlotOptions(btn)
  return {
    initializeFrame = function(slot)
      if slot.ClearAllPoints then
        slot:ClearAllPoints()
      end
      if slot.SetAllPoints then
        slot:SetAllPoints(btn)
      end
      if slot.SetTooltipAnchorPoint then
        slot:SetTooltipAnchorPoint("ANCHOR_RIGHT", 8, 0)
      end
      if slot.SetHideTooltipInCombat then
        slot:SetHideTooltipInCombat(false)
      end
      if slot.EnableMouse then
        slot:EnableMouse(true)
      end
      if slot.SetMouseClickEnabled then
        slot:SetMouseClickEnabled(false)
      end
      if slot.SetPropagateMouseClicks then
        slot:SetPropagateMouseClicks(true)
      end
      if slot.SetPassThroughButtons then
        slot:SetPassThroughButtons(PASS_BUTTONS[1], PASS_BUTTONS[2], PASS_BUTTONS[3], PASS_BUTTONS[4], PASS_BUTTONS[5])
      end
      if slot.SetMouseMotionEnabled then
        slot:SetMouseMotionEnabled(true)
      end
    end,
  }
end

local function IdentityFilter()
  if ns.IdentityShowAllDebuffs and ns.IdentityShowAllDebuffs() then
    return "HARMFUL"
  end
  return "HARMFUL|RAID_PLAYER_DISPELLABLE"
end

local function AddIdentityCarrier(container, filter, options)
  if not container then
    return false
  end
  local key = "identity"
  if type(container._dcrIdentityKeys) ~= "table" then
    container._dcrIdentityKeys = {}
  end
  if container._dcrIdentityKeys[key] then
    return true
  end
  if container.AddAuraSlot then
    container:AddAuraSlot(key, filter, options)
    container._dcrIdentityKeys[key] = "slot"
    return true
  end
  return false
end

local function TuneIdentityCarrier(container, options)
  if not container then
    return false
  end
  local key = "identity"
  local filter = IdentityFilter()
  if type(container._dcrIdentityKeys) ~= "table" then
    container._dcrIdentityKeys = {}
  end
  local kind = container._dcrIdentityKeys[key]
  if kind == "slot" and container.SetAuraSlotFilterString then
    container:SetAuraSlotFilterString(key, filter)
    return true
  end
  return AddIdentityCarrier(container, filter, options)
end

local function DisableIdentityTooltip(btn, _clearUnit)
  local container = btn and btn.identityContainer
  if not container then
    return true
  end
  if DisplayMutationBlocked() then
    pending = true
    return false
  end
  if container.SetEnabled then
    container:SetEnabled(false)
  end
  if container.Hide then
    container:Hide()
  end
  return true
end

local function AttachIdentityTooltip(btn, pack, unit)
  if type(unit) ~= "string" or unit == "" then
    return
  end
  if not IdentityTooltipAllowed(pack) then
    DisableIdentityTooltip(btn, true)
    return
  end
  if DisplayMutationBlocked() then
    pending = true
    return
  end
  local options = IdentitySlotOptions(btn)
  if btn.identityContainer then
    local container = btn.identityContainer
    if container.SetEnabled then
      container:SetEnabled(false)
    end
    if container.SetUnit then
      local assigned = ns.SafeNativeSetUnit(container, unit)
      if not assigned then
        pending = true
        return
      end
    end
    TuneIdentityCarrier(container, options)
    if container.SetEnabled then
      container:SetEnabled(true)
    end
    if container.Show then
      container:Show()
    end
    return
  end
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, btn, "CustomAuraContainerTemplate")
  if not ok or not container then
    return
  end
  if container.SetAllPoints then
    container:SetAllPoints(btn)
  end
  if container.EnableMouse then
    container:EnableMouse(false)
  end
  if not container.SetUnit then
    return
  end
  if not container.AddAuraSlot then
    return
  end
  if container.SetEnabled then
    container:SetEnabled(false)
  end
  local assigned = ns.SafeNativeSetUnit(container, unit)
  if not assigned then
    pending = true
    return
  end
  AddIdentityCarrier(container, IdentityFilter(), options)
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  if container.Show then
    container:Show()
  end
  btn.identityContainer = container
end

-- Runtime-faithful validation seams for the native identity carrier contract.
ns.CreateMUFIdentitySlotOptionsForValidation = IdentitySlotOptions
ns.AttachMUFIdentityTooltipForValidation = AttachIdentityTooltip
ns.DisableMUFIdentityTooltipForValidation = DisableIdentityTooltip

local function AttachPaint(btn, pack, unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  if DisplayMutationBlocked() then
    pending = true
    return false
  end
  local function initFn(frame, _key, slotInfo, configuredPack)
    BindAuraSlot(frame, configuredPack or GetPack(), btn.fillTex, slotInfo)
  end
  local engine = ns.DetectionEngine
  if engine and type(engine.BindCarrier) == "function" then
    local container, assigned, status = engine:BindCarrier("MUFs", btn.inner, unit, initFn, btn)
    btn.auraContainer = container or btn.auraContainer
    if not assigned then
      DisableIdentityTooltip(btn, true)
      return false, status or "FAILURE"
    end
  elseif btn.auraContainer then
    if ns.AttachDetectionContainer then
      ns.AttachDetectionContainer(btn.auraContainer, unit, pack, initFn)
    end
  elseif ns.AttachDetector then
    btn.auraContainer = ns.AttachDetector(btn.inner, unit, pack, initFn)
  end
  DisableIdentityTooltip(btn, true)
  if AttachCooldownGates then
    AttachCooldownGates(btn, pack, unit)
  end
  return true, "SUCCESS"
end

local function PaintRaidIcon(btn, unit)
  local icon = btn.raidIcon
  if not icon then
    return
  end
  local index
  if GetRaidTargetIndex then
    index = Public(GetRaidTargetIndex(unit))
  end
  if type(index) == "number" and index >= 1 and index <= 8 then
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(index))
    icon:Show()
  else
    icon:SetTexture(nil)
    icon:Hide()
  end
end

local function PrimaryCureRangeState(unit, pack)
  if IsPlayerToken(unit) then
    return true
  end
  if not ns.SpellRangeState then
    return true
  end
  local spell, spellId
  if ns.GetPrimaryCure then
    spell, spellId = ns.GetPrimaryCure(pack)
  end
  return ns.SpellRangeState(unit, spell, spellId)
end

local function ResolveMUFBaseAppearance(pack, unit)
  local colors = pack and pack.colors or {}
  local mufs = pack and pack.mufs or {}
  local fill = colors.healthy or {0, 0.3, 0.1, 0.9}
  local idle = type(mufs.centerTransp) == "number" and mufs.centerTransp or 0.35
  local fillAlpha = (fill[4] or 1) * idle
  if UnitIsConnected then
    local connected = UnitIsConnected(unit)
    if Accessible(connected) and connected == false then
      fillAlpha = mufs.inactiveOpacity or 0.65
    end
  end
  local red, green, blue, alpha = ClassBorderColor(unit)
  local borderVisible = mufs.border ~= false and red ~= nil
  return {
    fill = fill,
    fillAlpha = fillAlpha,
    borderVisible = borderVisible,
    borderRed = red,
    borderGreen = green,
    borderBlue = blue,
    borderAlpha = borderVisible and (mufs.borderTransp or 0.2) or 0,
    classAlpha = alpha,
  }
end

local function ResolveMUFRangePresentation(pack, inRange, isPlayer)
  local mufs = type(pack) == "table" and pack.mufs or nil
  local colors = type(pack) == "table" and pack.colors or nil
  local enabled = type(mufs) == "table" and mufs.dimOutOfRange == true and isPlayer ~= true
  local color = type(colors) == "table" and colors.range or nil
  if type(color) ~= "table" then
    color = COLOR_RANGE_OVERLAY
  end
  local alpha = type(mufs) == "table" and mufs.dimAmount or nil
  if type(alpha) ~= "number" then
    alpha = 0.60
  end
  if alpha < 0 then
    alpha = 0
  elseif alpha > 1 then
    alpha = 1
  end
  local reason = "CONFIGURED_COLOR"
  if isPlayer == true then
    reason = "PLAYER_ALWAYS_IN_RANGE"
  elseif not enabled then
    reason = "RANGE_DISABLED"
  end
  return {
    enabled = enabled,
    inRange = inRange,
    color = color,
    alpha = alpha,
    reason = reason,
    precedence = "BELOW_DISPEL_FILL",
    stateSource = "PRIMARY_CURE_PUBLIC_RANGE",
  }
end

ns.ResolveMUFRangePresentation = ResolveMUFRangePresentation

local function ApplyMUFRangePresentation(texture, range, holder)
  if not texture or type(range) ~= "table" then
    return false
  end
  holder = holder or texture
  if not range.enabled then
    if texture.SetAlpha then
      texture:SetAlpha(1)
    end
    if holder.SetAlpha then
      holder:SetAlpha(0)
    end
    if holder.Hide then
      holder:Hide()
    end
    return true
  end
  local color = type(range.color) == "table" and range.color or COLOR_RANGE_OVERLAY
  local dimAmount = type(range.alpha) == "number" and range.alpha or 0.60
  if texture.SetColorTexture then
    texture:SetColorTexture((color[1] or 0) * dimAmount, (color[2] or 0) * dimAmount, (color[3] or 0) * dimAmount, 1)
  end
  if texture.SetAlpha then
    texture:SetAlpha(1)
  end
  if texture.Show then
    texture:Show()
  end
  if holder.Show then
    holder:Show()
  end
  local inRange = range.inRange
  if holder.SetAlphaFromBoolean then
    holder:SetAlphaFromBoolean(NormalizeBooleanWidgetValue(inRange), 0, 1)
  elseif Accessible(inRange) and holder.SetAlpha then
    holder:SetAlpha((inRange == true or inRange == 1) and 0 or 1)
  elseif holder.SetAlpha then
    holder:SetAlpha(0)
  end
  return true
end

ns.ApplyMUFRangePresentation = ApplyMUFRangePresentation

local function ResolveMUFDeathPresentation(pack, deadValue, previousPublicState, stateSource)
  local colors = type(pack) == "table" and pack.colors or nil
  local color = type(colors) == "table" and colors.dead or nil
  if type(color) ~= "table" then
    color = COLOR_DEAD
  end
  local publicState = previousPublicState == true
  local nativeValue = publicState
  local reason = stateSource or "VALUE_UNAVAILABLE"
  if Accessible(deadValue) then
    if deadValue == true or deadValue == 1 then
      publicState = true
      nativeValue = true
      reason = stateSource or "PUBLIC_DEAD"
    elseif deadValue == false or deadValue == 0 then
      publicState = false
      nativeValue = false
      reason = "PUBLIC_ALIVE"
    else
      reason = stateSource or "PERSIST_LAST_PUBLIC"
    end
  else
    nativeValue = deadValue
    reason = "SECRET_NATIVE"
  end
  return {
    color = color,
    nativeValue = nativeValue,
    publicState = publicState,
    reason = reason,
    precedence = "ABOVE_RANGE_AFFLICTION_SOUL_LINK",
    stateSource = "UNIT_DEATH_OR_CONNECTION",
  }
end

ns.ResolveMUFDeathPresentation = ResolveMUFDeathPresentation

local function ApplyMUFDeathPresentation(fill, skull, presentation)
  if type(presentation) ~= "table" then
    return false
  end
  local value = presentation.nativeValue
  local color = type(presentation.color) == "table" and presentation.color or COLOR_DEAD
  local fillApplied = ApplyBooleanVertex(fill, value, color, COLOR_DEAD_CLEAR)
  local skullApplied = ApplyBooleanVertex(skull, value, COLOR_SKULL, COLOR_SKULL_CLEAR)
  return fillApplied and skullApplied
end

ns.ApplyMUFDeathPresentation = ApplyMUFDeathPresentation

local function ResolveMUFCooldownPresentation(active, skullValue, skullPublicState)
  local suppressed = skullPublicState == true
  return {
    active = active == true and not suppressed,
    skullValue = skullValue,
    suppressedBySkull = suppressed,
    reason = suppressed and "suppressedBySkull" or "available",
  }
end

ns.ResolveMUFCooldownPresentation = ResolveMUFCooldownPresentation

local function ApplyMUFCooldownVisibility(holder, presentation)
  if not holder or type(presentation) ~= "table" or not holder.SetAlpha then
    return false
  end
  local activeAlpha = presentation.active and 1 or 0
  if holder.SetAlphaFromBoolean and presentation.skullValue ~= nil then
    holder:SetAlphaFromBoolean(NormalizeBooleanWidgetValue(presentation.skullValue), 0, activeAlpha)
  else
    holder:SetAlpha(activeAlpha)
  end
  return true
end

ns.ApplyMUFCooldownVisibility = ApplyMUFCooldownVisibility

local function ResolveMUFManagedAppearance(pack, unit)
  local mufs = pack and pack.mufs or {}
  local player = IsPlayerToken(unit)
  local rangeEnabled = mufs.dimOutOfRange == true and not player
  local inRange = true
  if rangeEnabled then
    inRange = PrimaryCureRangeState(unit, pack)
  end
  local range = ResolveMUFRangePresentation(pack, inRange, player)
  return {
    restrictionFailureFill = false,
    restrictionStatusLight = ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction() or false,
    rangeEnabled = range.enabled,
    inRange = range.inRange,
    rangeColor = range.color,
    rangeAlpha = range.alpha,
    rangeReason = range.reason,
    rangeStateSource = range.stateSource,
    afflictionAuthority = "AURA_CONTAINER",
    rangeAboveAffliction = false,
    afflictionAboveManaged = true,
  }
end

ns.ResolveMUFBaseAppearance = ResolveMUFBaseAppearance
ns.ResolveMUFManagedAppearance = ResolveMUFManagedAppearance

local function PaintManagedOverlays(btn, pack, unit)
  if not btn or not btn.assigned or type(unit) ~= "string" then
    if btn then
      if btn.deadFill then
        ApplyBooleanVertex(btn.deadFill, false, COLOR_DEAD, COLOR_DEAD_CLEAR)
      end
      if btn.skullTex then
        ApplyBooleanVertex(btn.skullTex, false, COLOR_SKULL, COLOR_SKULL_CLEAR)
      end
      if btn.soulLinkFill then
        ApplyBooleanVertex(btn.soulLinkFill, false, COLOR_SL_IN, COLOR_DEAD_CLEAR)
      end
      if btn.stealthTex then
        ApplyBooleanVertex(btn.stealthTex, false, pack and pack.colors and pack.colors.stealth or COLOR_CLEAR, COLOR_DEAD_CLEAR)
      end
      if btn.failTex then
        btn.failTex:Hide()
      end
      if btn.rangeHost then
        btn.rangeHost:SetAlpha(0)
        btn.rangeHost:Hide()
      end
      if btn.raidIcon then
        btn.raidIcon:Hide()
      end
      btn.deadStateUnit = nil
      btn.deadStateGUID = nil
      btn.deadStatePublic = false
      btn.skullNativeValue = false
      btn.cooldownSuppressedBySkull = false
      if SetCooldownGateActive then
        for priority = 1, 3 do
          SetCooldownGateActive(btn, priority, cooldownStates[priority])
        end
      end
    end
    return
  end
  local colors = pack and pack.colors or {}
  if btn.deadStateUnit ~= unit then
    btn.deadStateUnit = unit
    btn.deadStateGUID = nil
    btn.deadStatePublic = false
  end
  if type(UnitGUID) == "function" then
    local ok, guid = pcall(UnitGUID, unit)
    if ok and Accessible(guid) and type(guid) == "string" then
      if btn.deadStateGUID and btn.deadStateGUID ~= guid then
        btn.deadStatePublic = false
      end
      btn.deadStateGUID = guid
    end
  end
  local deadValue, deadStateSource = ReadDeathValue(unit)
  local death = ResolveMUFDeathPresentation(pack, deadValue, btn.deadStatePublic, deadStateSource)
  local wasSuppressed = btn.cooldownSuppressedBySkull == true
  btn.deadStatePublic = death.publicState
  btn.skullNativeValue = death.nativeValue
  btn.cooldownSuppressedBySkull = death.publicState
  ApplyMUFDeathPresentation(btn.deadFill, btn.skullTex, death)
  if wasSuppressed and not btn.cooldownSuppressedBySkull and ReconcileCooldowns then
    ReconcileCooldowns()
  elseif (wasSuppressed ~= btn.cooldownSuppressedBySkull or not Accessible(death.nativeValue)) and SetCooldownGateActive then
    for priority = 1, 3 do
      SetCooldownGateActive(btn, priority, cooldownStates[priority])
    end
  end
  if btn.soulLinkFill then
    if SoulLinkFallbackApplies(unit) then
      ApplyBooleanVertex(btn.soulLinkFill, SoulLinkRangeValue(unit), COLOR_SL_IN, COLOR_SL_OUT)
      if btn.soulLinkFill.SetAlphaFromBoolean then
        btn.soulLinkFill:SetAlphaFromBoolean(NormalizeBooleanWidgetValue(death.nativeValue), 1, 0)
      elseif Accessible(deadValue) then
        btn.soulLinkFill:SetAlpha(death.publicState and 1 or 0)
      end
    else
      ApplyBooleanVertex(btn.soulLinkFill, false, COLOR_SL_IN, COLOR_DEAD_CLEAR)
      btn.soulLinkFill:SetAlpha(0)
    end
  end
  if btn.stealthTex then
    if pack.mufs.stealthStatus then
      local stealthColor = colors.stealth or {0.4, 0.6, 0.4, 1}
      ApplyBooleanVertex(btn.stealthTex, StealthedValue(unit), stealthColor, COLOR_DEAD_CLEAR)
    else
      ApplyBooleanVertex(btn.stealthTex, false, colors.stealth or COLOR_CLEAR, COLOR_DEAD_CLEAR)
    end
  end
  local managed = ResolveMUFManagedAppearance(pack, unit)
  if btn.failTex then
    -- The working MUF never paints addon restrictions as a full-square failure.
    -- Restriction/failure state belongs to the optional status light instead.
    btn.failTex:Hide()
  end
  if btn.rangeOverlay then
    ApplyMUFRangePresentation(btn.rangeOverlay, {
      enabled = managed.rangeEnabled,
      inRange = managed.inRange,
      color = managed.rangeColor,
      alpha = managed.rangeAlpha,
    }, btn.rangeHost)
  end
  PaintRaidIcon(btn, unit)
end

local function PaintSquare(btn, pack, unit)
  local borderOn = pack.mufs.border ~= false
  local appearance = ResolveMUFBaseAppearance(pack, unit)
  local fill = appearance.fill
  local w = btn:GetWidth() or 20
  local inner = InnerMUFSize(w, borderOn)
  btn.fillTex:ClearAllPoints()
  btn.fillTex:SetPoint("CENTER")
  btn.fillTex:SetSize(inner, inner)
  btn.inner:ClearAllPoints()
  btn.inner:SetPoint("CENTER")
  btn.inner:SetSize(inner, inner)
  btn.cooldownInnerSize = inner
  if btn.skullTex then
    local skull = math.max(6, math.floor(inner * 0.50 + 0.5))
    btn.skullTex:SetSize(skull, skull)
  end
  if btn.raidIcon then
    local mark = math.max(6, math.floor(inner * 0.40 + 0.5))
    btn.raidIcon:SetSize(mark, mark)
  end
  local r, g, b = appearance.borderRed, appearance.borderGreen, appearance.borderBlue
  for _, edge in ipairs({btn.outer1, btn.outer2, btn.outer3, btn.outer4}) do
    if edge then
      if appearance.borderVisible then
        edge:SetColorTexture(r, g, b, appearance.borderAlpha)
        edge:Show()
      else
        edge:Hide()
      end
    end
  end
  ApplyColor(btn.fillTex, fill, appearance.fillAlpha)
  if btn.charmTex then
    btn.charmTex:Hide()
  end
  if btn.playerMark then
    if pack.mufs.centerText and IsPlayerToken(unit) then
      btn.playerMark:SetText("P")
      btn.playerMark:Show()
    else
      btn.playerMark:SetText("")
      btn.playerMark:Hide()
    end
  end
  PaintManagedOverlays(btn, pack, unit)
end
local function PlaceStatusLight(btn, size, enabled)
  local lightSize, gap = ns.GetMUFStatusLightMetrics(size, enabled)
  local layers = {btn.statusLight, btn.statusLightRange}
  for i = 1, #layers do
    local light = layers[i]
    if light then
      light:SetSize(lightSize, lightSize)
      light:ClearAllPoints()
      light:SetPoint("BOTTOM", btn, "TOP", 0, gap)
      if enabled then
        light:Show()
      else
        light:Hide()
      end
    end
  end
end

local function UpdateStatusLights()
  if not poolReady then
    return
  end
  local pack = GetPack()
  local enabled = pack.mufs.statusLight
  for i = 1, #pool do
    local btn = pool[i]
    if btn.assigned and enabled then
      if btn.statusLight then
        btn.statusLight:Show()
      end
      if btn.statusLightRange then
        btn.statusLightRange:Show()
      end
      local restricted = ns.HasActiveAddonRestriction and ns.HasActiveAddonRestriction()
      local now = GetTime and GetTime() or 0
      local resultOn = COLOR_STATUS_READY
      if restricted then
        resultOn = COLOR_FAIL
      elseif (btn.statusUntil or 0) > now then
        if btn.statusOk then
          resultOn = COLOR_READY
        else
          resultOn = COLOR_FAIL
        end
      end
      ApplyBooleanVertex(btn.statusLight, true, resultOn, COLOR_STATUS_READY)
      local inRange = PrimaryCureRangeState(btn.unit, pack)
      ApplyBooleanVertex(btn.statusLightRange, inRange, COLOR_CLEAR, COLOR_RANGE_YELLOW)
    else
      if btn.statusLight then
        btn.statusLight:Hide()
      end
      if btn.statusLightRange then
        btn.statusLightRange:Hide()
      end
    end
  end
end

local DISPEL_TYPE_NAMES = {
  magic = "Magic",
  curse = "Curse",
  poison = "Poison",
  disease = "Disease",
}

local function MarkButtonStatus(btn, ok)
  if not btn then
    return
  end
  local now = GetTime and GetTime() or 0
  btn.statusOk = ok == true
  btn.statusUntil = now + 3
  UpdateStatusLights()
end

local function CooldownColor(pack, action)
  local key = action and action.types and action.types[1]
  local color = pack and pack.colors and pack.colors[key]
  if type(color) == "table" then
    return color[1] or 1, color[2] or 1, color[3] or 1
  end
  return 0.3, 0.65, 1
end

local function CooldownFilterMaps(actions, priority, unit)
  local native = {}
  local gap = {}
  local action = actions and actions[priority]
  local claimed = {}
  if type(actions) == "table" then
    for actionIndex = 1, priority - 1 do
      local earlierTypes = actions[actionIndex] and actions[actionIndex].types
      if type(earlierTypes) == "table" then
        for typeIndex = 1, #earlierTypes do
          claimed[earlierTypes[typeIndex]] = true
        end
      end
    end
  end
  local engineGaps = ns.GetEngineDispelGaps and ns.GetEngineDispelGaps(ns.IsPlayerUnit and ns.IsPlayerUnit(unit) == true) or nil
  local types = action and action.types
  if type(types) == "table" then
    for i = 1, #types do
      local typeKey = types[i]
      local name = DISPEL_TYPE_NAMES[typeKey]
      if name and not claimed[typeKey] then
        native[name] = true
      end
      if name and not claimed[typeKey] and type(engineGaps) == "table" and engineGaps[name] == true then
        gap[name] = true
      end
    end
  end
  return native, gap
end

local function MapHasValues(map)
  return type(map) == "table" and next(map) ~= nil
end

local cooldownFormatter

local function GetCooldownFormatter()
  if cooldownFormatter then
    return cooldownFormatter
  end
  if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum and Enum.NumericRuleFormatRounding then
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local ok = pcall(formatter.SetBreakpoints, formatter, {
      {threshold = 0, format = "%d", step = 1, rounding = Enum.NumericRuleFormatRounding.Up},
    })
    if ok then
      cooldownFormatter = formatter
      return formatter
    end
  end
  if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
    cooldownFormatter = C_StringUtil.CreateSecondsFormatter()
    return cooldownFormatter
  end
  return nil
end

local function SetDurationBinding(binding, active, durationObject)
  if not binding then
    return
  end
  if active and durationObject and binding.SetDuration then
    pcall(binding.SetDuration, binding, durationObject)
  end
  if binding.SetEnabled then
    pcall(binding.SetEnabled, binding, active == true)
  end
end

SetCooldownGateActive = function(btn, priority, state)
  local gates = btn and btn.cooldownGates
  local gate = gates and gates[priority]
  if not gate then
    return
  end
  local pack = GetPack()
  local shared = pack.mufs.shareCooldown ~= false
  local clearClicked = pack.mufs.clearCleansedImmediately ~= false
  local isClicked = state and state.targetBtn == btn
  local active = state ~= nil and btn.assigned == true and pack.alerts.cooldown ~= false
  active = active and gate.actionKey == state.actionKey
  if shared then
    active = active and (not isClicked or not clearClicked)
  else
    active = active and isClicked and not clearClicked
  end
  local presentation = ResolveMUFCooldownPresentation(active, btn.skullNativeValue, btn.cooldownSuppressedBySkull)
  active = presentation.active
  if gate.holder and gate.holder.SetAlpha then
    ApplyMUFCooldownVisibility(gate.holder, presentation)
  end
  local showNumbers = active and pack.alerts.cooldownNumbers ~= false
  for i = 1, #gate.bindings do
    SetDurationBinding(gate.bindings[i], showNumbers, state and state.durationObject)
  end
end

local function RefreshCooldownPriority(priority)
  local state = cooldownStates[priority]
  for i = 1, #pool do
    SetCooldownGateActive(pool[i], priority, state)
  end
end

local function FinishCooldown(priority, generation)
  if generation and generation ~= cooldownGeneration[priority] then
    return false
  end
  cooldownGeneration[priority] = cooldownGeneration[priority] + 1
  cooldownPending[priority] = nil
  cooldownStates[priority] = nil
  RefreshCooldownPriority(priority)
  return true
end

local function PublicCooldownState(spellId)
  if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then
    return nil
  end
  local ok, info = pcall(C_Spell.GetSpellCooldown, spellId)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local fieldsOk, active, onGCD, maxCharges = pcall(function()
    return info.isActive, info.isOnGCD, info.maxCharges
  end)
  if not fieldsOk or not Accessible(active) or type(active) ~= "boolean" or not Accessible(onGCD) or type(onGCD) ~= "boolean" then
    return nil
  end
  if not Accessible(maxCharges) or type(maxCharges) ~= "number" then
    maxCharges = nil
  end
  return {maxCharges = maxCharges}, active, onGCD
end

local function PublicChargeState(spellId, cooldownInfo)
  local maxCharges = cooldownInfo and cooldownInfo.maxCharges
  local currentCharges
  if C_Spell and type(C_Spell.GetSpellCharges) == "function" then
    local ok, info = pcall(C_Spell.GetSpellCharges, spellId)
    if ok and type(info) == "table" then
      local fieldsOk, current, maximum = pcall(function()
        return info.currentCharges, info.maxCharges
      end)
      if fieldsOk then
        if Accessible(current) and type(current) == "number" then
          currentCharges = current
        end
        if Accessible(maximum) and type(maximum) == "number" then
          maxCharges = maximum
        end
      end
    end
  end
  if type(maxCharges) ~= "number" or maxCharges <= 1 then
    return false
  end
  return true, currentCharges
end

local function CooldownDurationObject(spellId, charged)
  if not C_Spell then
    return nil
  end
  local getter = charged and C_Spell.GetSpellChargeDuration or C_Spell.GetSpellCooldownDuration
  if type(getter) ~= "function" then
    return nil
  end
  local ok, durationObject
  if charged then
    ok, durationObject = pcall(getter, spellId, true)
  else
    ok, durationObject = pcall(getter, spellId)
  end
  if ok then
    return durationObject
  end
  return nil
end

local RetryPendingCooldown

local function BeginPendingCooldown(priority, spellId, attempt)
  FinishCooldown(priority)
  local generation = cooldownGeneration[priority]
  local now = GetTime and GetTime() or 0
  cooldownPending[priority] = {
    generation = generation,
    spellId = spellId,
    actionKey = attempt.actionKey,
    targetBtn = attempt.targetBtn,
    startedAt = now,
    expiresAt = now + 2.8,
    confirmedNone = 0,
  }
  if C_Timer and C_Timer.After then
    for _, delay in ipairs({0, 0.05, 0.12, 0.25, 0.55, 1.0, 2.8}) do
      C_Timer.After(delay, function()
        RetryPendingCooldown(priority, generation)
      end)
    end
  else
    RetryPendingCooldown(priority, generation)
  end
end

RetryPendingCooldown = function(priority, generation)
  local pendingCooldown = cooldownPending[priority]
  if not pendingCooldown or pendingCooldown.generation ~= generation then
    return false
  end
  local now = GetTime and GetTime() or 0
  if now >= pendingCooldown.expiresAt then
    return FinishCooldown(priority, generation)
  end
  local info, active, onGCD = PublicCooldownState(pendingCooldown.spellId)
  if not info then
    return true
  end
  if not active or onGCD then
    pendingCooldown.confirmedNone = pendingCooldown.confirmedNone + 1
    if now - pendingCooldown.startedAt >= 0.55 and pendingCooldown.confirmedNone >= 3 then
      return FinishCooldown(priority, generation)
    end
    return true
  end
  local charged, currentCharges = PublicChargeState(pendingCooldown.spellId, info)
  if charged and currentCharges == nil then
    return true
  end
  if charged and currentCharges > 0 then
    return FinishCooldown(priority, generation)
  end
  local durationObject = CooldownDurationObject(pendingCooldown.spellId, charged)
  if not durationObject then
    return true
  end
  cooldownPending[priority] = nil
  cooldownStates[priority] = {
    generation = generation,
    spellId = pendingCooldown.spellId,
    actionKey = pendingCooldown.actionKey,
    targetBtn = pendingCooldown.targetBtn,
    durationObject = durationObject,
  }
  RefreshCooldownPriority(priority)
  return true
end

ReconcileCooldowns = function()
  for priority = 1, 3 do
    local pendingCooldown = cooldownPending[priority]
    if pendingCooldown then
      RetryPendingCooldown(priority, pendingCooldown.generation)
    end
    local state = cooldownStates[priority]
    if state then
      local info, active, onGCD = PublicCooldownState(state.spellId)
      if info then
        local charged, currentCharges = PublicChargeState(state.spellId, info)
        if not active or onGCD or (charged and type(currentCharges) == "number" and currentCharges > 0) then
          FinishCooldown(priority, state.generation)
        else
          local durationObject = CooldownDurationObject(state.spellId, charged)
          if durationObject then
            state.durationObject = durationObject
            RefreshCooldownPriority(priority)
          end
        end
      end
    end
  end
end

local function CooldownGateVisualSignature(btn, pack, action, priority)
  local innerSize = btn and btn.cooldownInnerSize or 1
  local r, g, b = CooldownColor(pack, action)
  local alpha = pack and pack.alerts and pack.alerts.cooldownOpacity or 0.62
  local actionKey = action and action.spellId or 0
  return table.concat({
    tostring(priority or 0),
    tostring(actionKey),
    tostring(innerSize),
    tostring(r),
    tostring(g),
    tostring(b),
    tostring(alpha),
  }, "|")
end

local function RetireCooldownGate(gate)
  if type(gate) ~= "table" then
    return
  end
  if type(gate.bindings) == "table" then
    for i = 1, #gate.bindings do
      local binding = gate.bindings[i]
      if binding and binding.SetEnabled then
        pcall(binding.SetEnabled, binding, false)
      end
    end
  end
  if gate.container and gate.container.SetEnabled then
    pcall(gate.container.SetEnabled, gate.container, false)
  end
  if gate.container and gate.container.Hide then
    pcall(gate.container.Hide, gate.container)
  end
  if gate.holder then
    if gate.holder.SetAlpha then
      pcall(gate.holder.SetAlpha, gate.holder, 0)
    end
    if gate.holder.Hide then
      pcall(gate.holder.Hide, gate.holder)
    end
  end
end

local function ConfigureGateSlot(gate, key, filter, include, pack, action)
  local container = gate.container
  local options = {
    initializeFrame = function(slot)
      if slot.ClearAllPoints then
        pcall(slot.ClearAllPoints, slot)
      end
      if slot.SetAllPoints then
        pcall(slot.SetAllPoints, slot, gate.holder)
      end
      PassClicks(slot)
      local shade = slot:CreateTexture(nil, "OVERLAY")
      shade:SetAllPoints(slot)
      local r, g, b = CooldownColor(pack, action)
      local alpha = pack.alerts.cooldownOpacity or 0.62
      shade:SetColorTexture(r * 0.45, g * 0.45, b * 0.45, alpha)
      if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
        local textFrame = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        textFrame:SetTextColor(1, 1, 1, 1)
        local innerSize = gate.innerSize or 1
        ns.ApplyMUFCooldownTextMetrics(textFrame, innerSize, innerSize, slot)
        local binding = C_DurationUtil.CreateDurationTextBinding()
        local formatter = GetCooldownFormatter()
        if formatter and binding.SetFormatter then
          binding:SetFormatter(formatter)
        end
        if binding.SetUpdateInterval then
          binding:SetUpdateInterval(0.05)
        end
        if binding.SetZeroDurationText then
          binding:SetZeroDurationText("")
        end
        if binding.SetExpiredText then
          binding:SetExpiredText("")
        end
        binding:SetFontString(textFrame)
        binding:SetEnabled(false)
        gate.bindings[#gate.bindings + 1] = binding
      end
    end,
    candidateFilters = {includeDispelTypes = include},
  }
  if gate.keys[key] then
    if container.SetAuraSlotFilterString then
      local filterOK = pcall(container.SetAuraSlotFilterString, container, key, filter)
      if not filterOK then
        return false
      end
    end
    if container.SetAuraSlotCandidateFilters then
      local candidatesOK = pcall(container.SetAuraSlotCandidateFilters, container, key, options.candidateFilters)
      if not candidatesOK then
        return false
      end
    end
    return true
  end
  if not container.AddAuraSlot then
    return false
  end
  local addedOK, added = pcall(container.AddAuraSlot, container, key, filter, options)
  if not addedOK or added == false then
    return false
  end
  gate.keys[key] = true
  return true
end

ns.ConfigureMUFCooldownGateSlotForValidation = ConfigureGateSlot

AttachCooldownGates = function(btn, pack, unit)
  if not btn or type(unit) ~= "string" or unit == "" or DisplayMutationBlocked() then
    return false
  end
  btn.cooldownGates = btn.cooldownGates or {}
  local actions = DistinctFriendlyCures(pack)
  for priority = 1, 3 do
    local action = actions[priority]
    local gate = btn.cooldownGates[priority]
    local visualSignature = action and CooldownGateVisualSignature(btn, pack, action, priority) or nil
    if gate and gate.visualSignature ~= visualSignature then
      RetireCooldownGate(gate)
      btn.cooldownGates[priority] = nil
      gate = nil
    end
    if action and not gate then
      local holder = CreateFrame("Frame", nil, btn)
      holder:SetAllPoints(btn.inner)
      PassClicks(holder)
      if holder.SetFrameLevel then
        local layers = ns.MUF_PRESENTATION
        holder:SetFrameLevel((btn:GetFrameLevel() or 0) + (layers and layers.cooldownLevelOffset or 48) + priority)
      end
      holder:SetAlpha(0)
      holder:Show()
      local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
      if ok and container and container.SetUnit and container.AddAuraSlot then
        container:SetAllPoints(holder)
        PassClicks(container)
        if container.SetEnabled then
          container:SetEnabled(false)
        end
        gate = {
          owner = btn,
          holder = holder,
          container = container,
          keys = {},
          bindings = {},
          innerSize = btn.cooldownInnerSize or 1,
          visualSignature = visualSignature,
        }
        btn.cooldownGates[priority] = gate
      else
        holder:SetAlpha(0)
      end
    end
    if gate then
      gate.actionKey = action and ("spell:" .. tostring(action.spellId)) or nil
      if gate.container.SetEnabled then
        gate.container:SetEnabled(false)
      end
      local assigned = ns.SafeNativeSetUnit(gate.container, unit)
      if not assigned then
        pending = true
        return false
      end
      local native, gap = CooldownFilterMaps(actions, priority, unit)
      local mainOK = ConfigureGateSlot(gate, "cooldown-main", "HARMFUL|RAID_PLAYER_DISPELLABLE", native, pack, action)
      local gapOK = ConfigureGateSlot(gate, "cooldown-gap", "HARMFUL|!RAID_PLAYER_DISPELLABLE", gap, pack, action)
      if not mainOK or not gapOK then
        RetireCooldownGate(gate)
        btn.cooldownGates[priority] = nil
        pending = true
        return false
      end
      if gate.container.SetEnabled then
        gate.container:SetEnabled(MapHasValues(native) or MapHasValues(gap))
      end
      if gate.container.Show then
        gate.container:Show()
      end
      SetCooldownGateActive(btn, priority, cooldownStates[priority])
    end
  end
  return true
end

local BUTTON_INDEX = {
  LeftButton = 1,
  RightButton = 2,
  MiddleButton = 3,
  Button4 = 4,
  Button5 = 5,
}

local function CureRowForClick(btn, button)
  local index = BUTTON_INDEX[button]
  if not index or type(btn.cureRows) ~= "table" then
    return nil
  end
  local suffix = "%s" .. tostring(index)
  if IsControlKeyDown and IsControlKeyDown() then
    local row = btn.cureRows["ctrl-" .. suffix]
    if row then
      return row
    end
  end
  if IsShiftKeyDown and IsShiftKeyDown() then
    local row = btn.cureRows["shift-" .. suffix]
    if row then
      return row
    end
  end
  if IsAltKeyDown and IsAltKeyDown() then
    local row = btn.cureRows["alt-" .. suffix]
    if row then
      return row
    end
  end
  return btn.cureRows["*" .. suffix]
end

local function BeginCureAttempt(btn, button)
  local row = CureRowForClick(btn, button)
  if not row or not btn.assigned then
    cureAttempt = nil
    return
  end
  local aliases = {}
  if type(row.spellId) == "number" and row.spellId > 0 then
    aliases[row.spellId] = true
  end
  if type(row.baseId) == "number" and row.baseId > 0 then
    aliases[row.baseId] = true
  end
  cureAttempt = {
    targetBtn = btn,
    priority = row.priority,
    actionKey = row.actionKey,
    aliasSpellIDs = aliases,
    startedAt = GetTime and GetTime() or 0,
  }
end

local function OnPlayerSpellResult(event, unit, spellId)
  unit = Public(unit)
  spellId = Public(spellId)
  local attempt = cureAttempt
  local now = GetTime and GetTime() or 0
  if unit ~= "player" or not attempt or now - attempt.startedAt > 1.5 then
    return
  end
  if type(spellId) ~= "number" or not attempt.aliasSpellIDs[spellId] then
    return
  end
  cureAttempt = nil
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    MarkButtonStatus(attempt.targetBtn, true)
    attempt.targetBtn.suppressFailureUntil = now + 2
    if ns.NotifyCureSucceeded then
      ns.NotifyCureSucceeded(attempt.targetBtn and attempt.targetBtn.unit)
    end
    BeginPendingCooldown(attempt.priority, spellId, attempt)
  else
    if (attempt.targetBtn.suppressFailureUntil or 0) > now then
      return
    end
    MarkButtonStatus(attempt.targetBtn, false)
    if ns.PlayCureFailureSound then
      ns.PlayCureFailureSound()
    end
  end
end

local function WireTooltip(btn)
  btn:SetScript("OnEnter", function(self)
    local pack = GetPack()
    if not pack.mufs.tooltip then
      return
    end
    if IdentityTooltipAllowed(pack) and self.identityContainer then
      return
    end
    local unit = self.unit
    if not unit or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end
local function CreateMUF(parent)
  local btn = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
  btn:RegisterForClicks("AnyUp")
  btn:SetClampedToScreen(true)
  btn:SetFrameStrata("MEDIUM")
  btn:SetSize(20, 20)

  -- Alpha.4 four-side 2px class border + centered fill.
  btn.outer1 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer1:SetPoint("BOTTOMLEFT")
  btn.outer1:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, 2)
  btn.outer2 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer2:SetPoint("TOPLEFT", 0, -2)
  btn.outer2:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", 2, 2)
  btn.outer3 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer3:SetPoint("TOPLEFT")
  btn.outer3:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, -2)
  btn.outer4 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer4:SetPoint("TOPRIGHT", 0, -2)
  btn.outer4:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", -2, 2)

  btn.fillTex = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
  btn.fillTex:SetPoint("CENTER")
  btn.fillTex:SetSize(16, 16)

  btn.inner = CreateFrame("Frame", nil, btn)
  btn.inner:SetPoint("CENTER")
  btn.inner:SetSize(16, 16)

  local layers = ns.MUF_PRESENTATION or {}
  btn.managedHost = CreateFrame("Frame", nil, btn)
  btn.managedHost:SetAllPoints(btn.inner)
  PassClicks(btn.managedHost)
  btn.managedHost:SetFrameLevel((btn:GetFrameLevel() or 0) + (layers.managedLevelOffset or 36))

  btn.deathHost = CreateFrame("Frame", nil, btn)
  btn.deathHost:SetAllPoints(btn.inner)
  PassClicks(btn.deathHost)
  btn.deathHost:SetFrameLevel((btn:GetFrameLevel() or 0) + (layers.deathLevelOffset or 44))

  btn.cooldownHost = CreateFrame("Frame", nil, btn)
  btn.cooldownHost:SetAllPoints(btn.inner)
  PassClicks(btn.cooldownHost)
  btn.cooldownHost:SetFrameLevel((btn:GetFrameLevel() or 0) + (layers.cooldownLevelOffset or 48))

  btn.readabilityHost = CreateFrame("Frame", nil, btn)
  btn.readabilityHost:SetAllPoints(btn)
  PassClicks(btn.readabilityHost)
  btn.readabilityHost:SetFrameLevel((btn:GetFrameLevel() or 0) + (layers.readabilityLevelOffset or 64))

  btn.charmTex = btn.readabilityHost:CreateTexture(nil, "OVERLAY", nil, 6)
  btn.charmTex:SetPoint("TOPRIGHT")
  btn.charmTex:SetSize(7, 7)
  btn.charmTex:Hide()

  btn.playerMark = btn.readabilityHost:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
  btn.playerMark:SetPoint("CENTER", 1.6, 0)
  btn.playerMark:SetPoint("BOTTOM", 0, 1)
  btn.playerMark:SetText("")
  btn.playerMark:Hide()

  btn.cdTex = btn.cooldownHost:CreateTexture(nil, "OVERLAY")
  btn.cdTex:SetAllPoints()
  btn.cdTex:SetColorTexture(0, 0, 0, 0.62)
  btn.cdTex:Hide()

  btn.cdText = btn.cooldownHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  btn.cdText:SetPoint("CENTER")
  btn.cdText:SetTextColor(1, 1, 1, 1)
  btn.cdText:Hide()

  btn.statusLight = btn.readabilityHost:CreateTexture(nil, "OVERLAY", nil, 6)
  btn.statusLight:SetTexture(STATUS_MASK)
  btn.statusLight:SetVertexColor(COLOR_READY[1], COLOR_READY[2], COLOR_READY[3], 1)
  btn.statusLight:Hide()
  btn.statusLight:SetSize(6, 6)

  btn.statusLightRange = btn.readabilityHost:CreateTexture(nil, "OVERLAY", nil, 7)
  btn.statusLightRange:SetTexture(STATUS_MASK)
  btn.statusLightRange:SetVertexColor(COLOR_CLEAR[1], COLOR_CLEAR[2], COLOR_CLEAR[3], COLOR_CLEAR[4])
  btn.statusLightRange:Hide()
  btn.statusLightRange:SetSize(6, 6)

  btn.stealthTex = btn.managedHost:CreateTexture(nil, "ARTWORK", nil, 3)
  btn.stealthTex:SetAllPoints(btn.fillTex)
  btn.stealthTex:SetColorTexture(1, 1, 1, 1)
  btn.stealthTex:SetVertexColor(0, 0, 0, 0)

  btn.failTex = btn.managedHost:CreateTexture(nil, "ARTWORK", nil, 4)
  btn.failTex:SetAllPoints(btn.fillTex)
  btn.failTex:SetColorTexture(COLOR_FAIL[1], COLOR_FAIL[2], COLOR_FAIL[3], 0.28)
  btn.failTex:Hide()

  btn.rangeHost = CreateFrame("Frame", nil, btn.managedHost)
  btn.rangeHost:SetAllPoints(btn.inner)
  PassClicks(btn.rangeHost)
  btn.rangeHost:SetFrameLevel(btn.managedHost:GetFrameLevel() or ((btn:GetFrameLevel() or 0) + (layers.managedLevelOffset or 36)))
  btn.rangeHost:SetAlpha(0)
  btn.rangeHost:Hide()

  btn.rangeOverlay = btn.rangeHost:CreateTexture(nil, "ARTWORK", nil, 5)
  btn.rangeOverlay:SetAllPoints(btn.fillTex)
  btn.rangeOverlay:SetColorTexture(COLOR_RANGE_OVERLAY[1], COLOR_RANGE_OVERLAY[2], COLOR_RANGE_OVERLAY[3], 1)
  btn.rangeOverlay:SetAlpha(1)
  btn.rangeOverlay:Show()

  btn.deadFill = btn.deathHost:CreateTexture(nil, "ARTWORK", nil, 0)
  btn.deadFill:SetAllPoints(btn.fillTex)
  btn.deadFill:SetColorTexture(1, 1, 1, 1)
  btn.deadFill:SetVertexColor(0, 0, 0, 0)

  btn.soulLinkFill = btn.managedHost:CreateTexture(nil, "ARTWORK", nil, 7)
  btn.soulLinkFill:SetAllPoints(btn.fillTex)
  btn.soulLinkFill:SetColorTexture(1, 1, 1, 1)
  btn.soulLinkFill:SetVertexColor(0, 0, 0, 0)
  btn.soulLinkFill:SetAlpha(0)

  btn.skullTex = btn.readabilityHost:CreateTexture(nil, "OVERLAY", nil, 7)
  btn.skullTex:SetPoint("CENTER", btn.fillTex, "CENTER")
  btn.skullTex:SetSize(8, 8)
  btn.skullTex:SetTexture(SKULL_TEXTURE)
  btn.skullTex:SetVertexColor(1, 1, 1, 0)

  btn.raidIcon = btn.readabilityHost:CreateTexture(nil, "OVERLAY", nil, 7)
  btn.raidIcon:SetPoint("TOPLEFT", btn.fillTex, "TOPLEFT", -1, 1)
  btn.raidIcon:SetSize(8, 8)
  btn.raidIcon:Hide()

  WireTooltip(btn)
  btn:SetScript("PreClick", function(self, button)
    if button == "LeftButton" and ns.BeginSoulLinkAttempt and SoulLinkFallbackApplies(self.unit) then
      ns.BeginSoulLinkAttempt(self.unit)
    end
    BeginCureAttempt(self, button)
  end)
  local engine = ns.DetectionEngine
  if engine and type(engine.CreateCarrier) == "function" then
    local function initFn(frame, _key, slotInfo)
      BindAuraSlot(frame, GetPack(), btn.fillTex, slotInfo)
    end
    btn.auraContainer = engine:CreateCarrier("MUFs", btn.inner, initFn, btn)
  end
  btn:Hide()
  return btn
end

-- Runtime-faithful validation seam: tests use the real visual constructor with
-- frame fakes that enforce WoW's texture sublevel contract.
ns.CreateMUFVisualValidationFrame = CreateMUF

local function EnsurePool()
  if poolReady then
    return true
  end
  if LockedDown() then
    return false
  end
  if not header then
    return false
  end
  for i = 1, POOL_SIZE do
    pool[i] = CreateMUF(header)
  end
  poolReady = true
  return true
end

local function OnHeaderUpdate(_self, elapsed)
  local pack = GetPack()
  rangeElapsed = rangeElapsed + (elapsed or 0)
  paintElapsed = paintElapsed + (elapsed or 0)
  if pack.mufs.statusLight and rangeElapsed >= 0.15 then
    rangeElapsed = 0
    UpdateStatusLights()
  end
  if paintElapsed >= 0.20 then
    paintElapsed = 0
    if poolReady then
      for i = 1, #pool do
        local btn = pool[i]
        if btn.assigned then
          PaintManagedOverlays(btn, pack, btn.unit)
        end
      end
    end
  end
end

local function EnsureHeader()
  if header then
    return true
  end
  if LockedDown() then
    return false
  end
  header = CreateFrame("Frame", "DecursiveRebuildMUFHeader", UIParent)
  header:SetSize(30, 30)
  header:SetClampedToScreen(true)
  header:SetMovable(true)
  header:EnableMouse(false)
  header:SetFrameStrata("MEDIUM")
  RestorePoint()

  -- Alpha.4 DcrMUFsContainerDragButton: 20x20 square on the top-left of the grid.
  handle = CreateFrame("Button", "DecursiveRebuildMUFHandle", header)
  handle:SetSize(20, 20)
  handle:SetClampedToScreen(true)
  handle:SetPoint("BOTTOMLEFT", header, "TOPLEFT", 0, 0)
  -- Alpha.4 handle is blank until hover. Highlight only, ADD blend.
  handle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  handle:RegisterForClicks("AnyUp")
  handle.isMoving = false
  handle:SetScript("OnMouseDown", function(self, button)
    if LockedDown() then
      return
    end
    local pack = GetPack()
    if pack.mufs.locked then
      return
    end
    if button == "LeftButton" and IsAltKeyDown and IsAltKeyDown() then
      self.isMoving = true
      header:StartMoving()
    end
  end)
  handle:SetScript("OnMouseUp", function(self, button)
    if self.isMoving and not LockedDown() then
      header:StopMovingOrSizing()
      self.isMoving = false
      SavePoint()
    elseif button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
      if ns.ShowOptions then
        ns.ShowOptions()
      end
    end
  end)
  handle:SetScript("OnHide", function(self)
    if self.isMoving and not LockedDown() then
      header:StopMovingOrSizing()
    end
    self.isMoving = false
  end)
  handle:SetScript("OnEnter", function(self)
    local pack = GetPack()
    if pack.mufs.showHelp == false then
      return
    end
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Zhaohu's Decursive")
    GameTooltip:AddLine("Alt-Left: move MUFs", 0.32, 0.86, 0.82)
    GameTooltip:AddLine("Alt-Right: options", 0.32, 0.86, 0.82)
    GameTooltip:Show()
  end)
  handle:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  header:SetScript("OnUpdate", OnHeaderUpdate)
  return true
end
local function HideAll()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return false
  end
  if header then
    header:Hide()
  end
  if not poolReady then
    return true
  end
  local cleared = true
  for i = 1, #pool do
    local btn = pool[i]
    if ns.DetectionEngine and type(ns.DetectionEngine.UnassignCarrier) == "function" then
      if not ns.DetectionEngine:UnassignCarrier(btn) then
        cleared = false
      end
    end
    btn.assigned = false
    btn.unit = nil
    PaintManagedOverlays(btn, GetPack(), nil)
    btn:SetAttribute("unit", nil)
    ClearClickAttributes(btn)
    DisableIdentityTooltip(btn, true)
    btn:Hide()
  end
  return cleared
end

function ns.ResetMUFsForWorldTransition(reason)
  if LockedDown() then
    pending = true
    mufsConfigured = false
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("MUF_WORLD_RESET", {result = "DEFERRED", reason = "COMBAT_LOCKDOWN"}, false)
    end
    return false
  end
  cureAttempt = nil
  for priority = 1, 3 do
    FinishCooldown(priority)
  end
  local cleared = HideAll() == true
  pending = false
  mufsConfigured = false
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("MUF_WORLD_RESET", {
      result = cleared and "CLEARED" or "FAIL_CLOSED",
      reason = type(reason) == "string" and reason or "WORLD_TRANSITION",
      carriers = #pool,
    }, false)
  end
  return cleared
end

function ns.LayoutMUFs()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("MUF_LAYOUT", {result = "DEFERRED", reason = "COMBAT_LOCKDOWN"}, false)
    end
    return
  end
  if not EnsureHeader() then
    pending = true
    mufsConfigured = false
    return
  end
  if not EnsurePool() then
    pending = true
    mufsConfigured = false
    return
  end

  local pack = GetPack()
  ns.RebuildClickModel(pack)
  local env = GetEnv()
  if not ShouldShowHeader(pack) then
    local hidden = HideAll() == true
    return hidden, hidden and "SUCCESS" or "FAILURE", 0
  end

  local units = ns.BuildRoster and ns.BuildRoster(pack) or {}
  ns.ApplyMUFDisplayCap(units, pack.mufs.maxUnits)
  local previouslyAssigned = 0
  for i = 1, #pool do
    if pool[i] and pool[i].assigned then
      previouslyAssigned = previouslyAssigned + 1
    end
  end

  local size = PixelSize(pack, env)
  local hSpace, vSpace = Spacing(pack)
  local perLine = pack.mufs.unitsPerLine or 10
  if perLine < 1 then
    perLine = 1
  end
  local growUp = pack.mufs.growUp
  local growFromRight = pack.mufs.growFromRight
  local verticalLayout = addon and addon.GetMUFVerticalLayout and addon:GetMUFVerticalLayout()
  if verticalLayout == nil then
    verticalLayout = pack.mufs.verticalLayout == true
  end
  local n = #units
  local layoutOK = true
  local layoutStatus = "SUCCESS"
  local layout = ns.CalculateMUFLayout(
    n,
    size,
    hSpace,
    vSpace,
    pack.mufs.statusLight,
    perLine,
    verticalLayout,
    growUp,
    growFromRight
  )
  header:SetSize(math.max(layout.width, 8), math.max(layout.height, 8))
  header:SetScale(pack.mufs.scale or 1)
  header:SetMovable(not pack.mufs.locked)
  header:Show()

  if pack.mufs.hideHandle then
    handle:Hide()
    handle:EnableMouse(false)
  else
    handle:Show()
    handle:EnableMouse(true)
  end

  for i = 1, POOL_SIZE do
    local btn = pool[i]
    local unit = units[i]
    if unit then
      local position = layout.positions[i]
      btn:ClearAllPoints()
      btn:SetPoint(layout.anchor, header, layout.anchor, position.x, position.y)
      local mufSize = ns.GetMUFVisualMetrics(size, pack.mufs.border ~= false, unit)
      btn:SetSize(mufSize, mufSize)
      btn.unit = unit
      btn.assigned = true
      ApplyClickAttributes(btn, pack, unit)
      PaintSquare(btn, pack, unit)
      PlaceStatusLight(btn, size, pack.mufs.statusLight)
      local paintOK, paintStatus = AttachPaint(btn, pack, unit)
      if not paintOK then
        layoutOK = false
        layoutStatus = paintStatus or "FAILURE"
      end
      if not ns.DetectionEngine and btn.auraContainer and btn.auraContainer.SetUnit and not DisplayMutationBlocked() then
        local assigned = ns.SafeNativeSetUnit(btn.auraContainer, unit)
        if not assigned then
          layoutOK = false
        end
      end
      btn:Show()
    else
      if ns.DetectionEngine and type(ns.DetectionEngine.UnassignCarrier) == "function" then
        if not ns.DetectionEngine:UnassignCarrier(btn) then
          layoutOK = false
        end
      end
      btn.assigned = false
      btn.unit = nil
      btn.deadStateUnit = nil
      btn.deadStateGUID = nil
      btn.deadStatePublic = false
      PaintManagedOverlays(btn, pack, nil)
      btn:SetAttribute("unit", nil)
      ClearClickAttributes(btn)
      DisableIdentityTooltip(btn, true)
      btn:Hide()
    end
  end

  if handle and not pack.mufs.hideHandle then
    local first
    for i = 1, POOL_SIZE do
      if pool[i] and pool[i].assigned then
        first = pool[i]
        break
      end
    end
    if first then
      local w = first:GetWidth() or size
      handle:SetSize(w, w)
      handle:ClearAllPoints()
      if pack.mufs.growUp then
        handle:SetPoint("TOP", first, "BOTTOM", 0, 0)
      else
        handle:SetPoint("BOTTOM", first, "TOP", 0, statusReserve)
      end
    end
  end

  UpdateStatusLights()
  for priority = 1, 3 do
    RefreshCooldownPriority(priority)
  end
  mufsConfigured = layoutOK
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("MUF_LAYOUT", {
      result = layoutOK and "APPLIED" or "FAIL_CLOSED",
      assigned = n,
      previouslyAssigned = previouslyAssigned,
      cleared = math.max(0, previouslyAssigned - n),
      rows = layout.rows,
      columns = layout.cols,
      orientation = verticalLayout and "VERTICAL" or "HORIZONTAL",
    }, false)
  end
  return layoutOK, layoutStatus, n
end

function ns.RefreshMUFs()
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("MUFs")
  end
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return
  end
  pending = false
  return ns.LayoutMUFs()
end

function ns.RecoverMUFsAfterCombat()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return false
  end
  ns.RebuildClickModel()
  if not EnsureHeader() then
    pending = true
    mufsConfigured = false
    return false
  end
  if not EnsurePool() then
    pending = true
    mufsConfigured = false
    return false
  end
  pending = false
  ns.LayoutMUFs()
  if mufsConfigured and ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("MUFs", true)
  end
  return mufsConfigured == true
end

function ns.MUFsConfigured()
  return mufsConfigured == true
end

local function RegisterExtraEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "SPELLS_CHANGED" then
      cureAttempt = nil
      for priority = 1, 3 do
        FinishCooldown(priority)
      end
      if ns.InvalidateDetection then
        ns.InvalidateDetection()
      end
      if LockedDown() then
        pending = true
        return
      end
      clickModel = nil
      clickModelSig = nil
      ns.RefreshMUFs()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
      OnPlayerSpellResult(event, arg1, arg3)
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
      ReconcileCooldowns()
    elseif event == "UNIT_PET" then
      if LockedDown() then
        pending = true
        return
      end
      ns.RefreshMUFs()
    elseif event == "RAID_TARGET_UPDATE" then
      if poolReady then
        for i = 1, #pool do
          local btn = pool[i]
          if btn.assigned then
            PaintRaidIcon(btn, btn.unit)
          end
        end
      end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
      if arg1 ~= nil then
        if ns.RememberRestrictionState then
          ns.RememberRestrictionState(arg1, arg2)
        end
      end
      if LockedDown() then
        pending = true
        return
      end
      ns.RefreshMUFs()
    end
  end)
  if not ns.DetectionEngine then
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("UNIT_PET")
  end
  eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
  local restrictionOk = true
  if C_EventUtils and C_EventUtils.IsEventValid then
    restrictionOk = C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED")
  end
  if restrictionOk and not ns.DetectionEngine then
    eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  end
end

function ns.EnableMUFs(_addon)
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("MUFs", false)
  end
  if ns.DetectionEngine and type(ns.DetectionEngine.RegisterConsumer) == "function" then
    ns.DetectionEngine:RegisterConsumer("MUFs", function()
      return ns.RefreshMUFs()
    end)
  end
  RegisterExtraEvents()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return
  end
  ns.RefreshMUFs()
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("MUFs", true)
  end
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("MUFs", function()
    local assigned = 0
    local visible = 0
    local clickInstalled = 0
    local cooldownSuppressedBySkullCount = 0
    for i = 1, #pool do
      local button = pool[i]
      if button and button.assigned == true then
        assigned = assigned + 1
        if button.cooldownSuppressedBySkull == true then
          cooldownSuppressedBySkullCount = cooldownSuppressedBySkullCount + 1
        end
        if type(button.cureRows) == "table" then
          clickInstalled = clickInstalled + 1
        end
        if type(button.IsShown) == "function" then
          local ok, shown = pcall(button.IsShown, button)
          local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(shown) or nil
          if ok and public == true then
            visible = visible + 1
          end
        end
      end
    end
    local pack = GetPack()
    local mufs = type(pack) == "table" and pack.mufs or nil
    local sorting = type(pack) == "table" and pack.sorting or nil
    local configuredDisplayCap = type(mufs) == "table" and mufs.maxUnits or (ns.DEFAULT_MUF_DISPLAY_CAP or 5)
    return {
      poolReady = poolReady,
      poolCount = #pool,
      assignedCount = assigned,
      visibleCount = visible,
		configuredDisplayCap = configuredDisplayCap,
		displayCapStage = "AFTER_SORT_MEMBER_CAP_THEN_OWNER_PETS",
		displayCapPolicy = "MEMBER_CAP_PETS_ADDITIONAL_OWNER_STABLE",
		displayCapAffectsDetection = false,
		displayCapIncludesPlayer = type(sorting) == "table" and sorting.includePlayer == true,
		displayCapIncludesPets = type(sorting) == "table" and sorting.includePets == true,
		eligibleMemberCount = displayCapDiagnostics.eligibleMembers,
		eligiblePetCount = displayCapDiagnostics.eligiblePets,
		displayedMemberCount = displayCapDiagnostics.displayedMembers,
		displayedPetCount = displayCapDiagnostics.displayedPets,
		omittedMemberCount = displayCapDiagnostics.omittedMembers,
		omittedPetCount = displayCapDiagnostics.omittedPets,
		orphanPetCount = displayCapDiagnostics.orphanPets,
		duplicatePetCount = displayCapDiagnostics.duplicatePets,
		detectionProviderType = ns.DetectionEngine and "NATIVE_AURA_CONTAINER" or "COMPATIBILITY_NATIVE_AURA_CONTAINER",
		presentationBindingType = ns.MUF_PRESENTATION and "ADDON_CHILD_DISPEL_TEXTURE" or "UNAVAILABLE",
		appliedPackType = type(pack),
      configured = mufsConfigured,
      pendingRefresh = pending,
      eventsRegistered = eventsOn,
      clickModelGeneration = clickModelGeneration,
      clickModelBuilt = clickModel ~= nil,
      clickInstalledCount = clickInstalled,
      clickRebuildPending = pending and clickModel == nil,
      presentationMode = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.mode or "UNAVAILABLE",
      presentationAlpha = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.alpha or 0,
      presentationFillLevel = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.fillLevelOffset or 0,
      presentationCooldownLevel = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.cooldownLevelOffset or 0,
      presentationHostParent = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.hostParent or "UNAVAILABLE",
      presentationHostBounds = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.hostBounds or "UNAVAILABLE",
      presentationVisibilityGate = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.visibilityGate or "UNAVAILABLE",
      presentationHealthyVisibility = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.healthyVisibility or "UNAVAILABLE",
      presentationAfflictedVisibility = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.afflictedVisibility or "UNAVAILABLE",
      presentationRegistrationStyle = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.registrationStyle or "UNAVAILABLE",
      presentationOrder = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.order or "UNAVAILABLE",
      presentationNativeLifecycle = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.nativeLifecycle or "UNAVAILABLE",
      presentationAlphaChain = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.alphaChain or "UNAVAILABLE",
      presentationAlphaIsolationMode = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.alphaIsolationMode or "UNAVAILABLE",
      presentationIgnoreParentAlphaSupported = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.ignoreParentAlphaSupported == true,
      presentationIgnoreParentAlphaApplied = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.ignoreParentAlphaApplied == true,
      presentationLocalTextureAlpha = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.localTextureAlpha or 0,
      presentationProviderVertexAlpha = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.providerVertexAlpha or 0,
      presentationExpectedEffectiveAlpha = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.expectedEffectiveAlpha or 0,
		presentationPaletteRefreshMode = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.paletteRefreshMode or "UNAVAILABLE",
		presentationPaletteSignatureMode = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.paletteSignatureMode or "UNAVAILABLE",
		presentationPaletteRegistrationGeneration = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.paletteRegistrationGeneration or 0,
		presentationPaletteRefreshGeneration = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.paletteRefreshGeneration or 0,
		presentationPaletteRefreshFailureCount = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.paletteRefreshFailureCount or 0,
      nativeChildrenUntouched = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.nativeChildrenUntouched == true,
      rangePresentationMode = "CONFIGURED_COLOR_OVERLAY",
      rangePresentationPrecedence = "BELOW_DISPEL_FILL",
      rangeColorPickerMode = "RGB_ONLY_OPAQUE",
      rangeTextureIntrinsicAlpha = 1,
      rangeDimMode = "RGB_BRIGHTNESS_MULTIPLIER",
      rangeVisibilityAlpha = "OPAQUE_ZERO_OR_ONE",
      rangeAlphaComposition = "OPAQUE_TEXTURE_TIMES_OPAQUE_VISIBLE_HOST",
      rangeParentAlphaPolicy = "NORMAL_INHERITANCE",
      afflictionPresentationPrecedence = ns.MUF_PRESENTATION and ns.MUF_PRESENTATION.afflictionPrecedence or "UNAVAILABLE",
      rangeStateSource = "PRIMARY_CURE_PUBLIC_RANGE",
      deathPresentationMode = "CONFIGURED_COLOR_WITH_SKULL",
      deathPresentationPrecedence = "ABOVE_RANGE_AFFLICTION_SOUL_LINK",
      deathStateSource = "UNIT_DEATH_OR_CONNECTION",
      deathStatePersistence = "UNTIL_PUBLIC_ALIVE_OR_UNIT_CHANGE",
      deathSkullLayer = "READABILITY_ABOVE_COOLDOWN",
      deathBorderVisibility = "OUTSIDE_INNER_FILL",
      cooldownSuppressedBySkullCount = cooldownSuppressedBySkullCount,
      cooldownSuppressionReason = "suppressedBySkull",
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("MUFs")
end
