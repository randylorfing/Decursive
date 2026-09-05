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

local PRESENTATION = {
  mode = "FULL_OPAQUE",
  alpha = 1,
  slotLevelOffset = 24,
  fillLevelOffset = 40,
  managedLevelOffset = 36,
  deathLevelOffset = 44,
  cooldownLevelOffset = 48,
  readabilityLevelOffset = 64,
  rangeShadeLevelOffset = 80,
  hostParent = "NATIVE_AURA_SLOT",
  hostBounds = "INNER_FILL_FULL_BOUNDS",
  visibilityGate = "NATIVE_AURA_SLOT_PARENT",
  healthyVisibility = "INHERITED_SLOT_HIDDEN",
  afflictedVisibility = "INHERITED_SLOT_SHOWN",
  registrationStyle = "PRESERVE_ASSET",
  order = "NATIVE_SLOT_MANAGED_FILL_DEATH_COOLDOWN_READABILITY_RANGE_SHADE",
  afflictionPrecedence = "ABOVE_RANGE_SOUL_LINK_ORDINARY_MANAGED",
  nativeLifecycle = "SET_UNIT_ADD_SLOT_INITIALIZE_ENABLE_LAST",
  nativeChildrenUntouched = true,
  alphaChain = "MUF_ANCESTOR_NATIVE_SLOT_HOST_TEXTURE_PROVIDER_VERTEX",
  alphaIsolationMode = "OWNED_TEXTURE_IGNORE_PARENT_ALPHA",
  ignoreParentAlphaSupported = false,
  ignoreParentAlphaApplied = false,
  localTextureAlpha = 1,
  providerVertexAlpha = 1,
  expectedEffectiveAlpha = 1,
	paletteRefreshMode = "OWNED_SLOT_CLEAR_READD_ON_SIGNATURE_CHANGE",
	paletteSignatureMode = "DISPEL_TYPE_RGBA",
	paletteRegistrationGeneration = 0,
	paletteRefreshGeneration = 0,
	paletteRefreshFailureCount = 0,
  paletteColorMode = "MAP_FALLBACK",
  paletteCurveFailureCount = 0,
}

ns.MUF_PRESENTATION = PRESENTATION

local function DisableInteraction(frame)
  if not frame then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
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
end

local DISPEL_COLORS = {
	{"Magic", "magic"},
	{"Curse", "curse"},
	{"Poison", "poison"},
	{"Disease", "disease"},
}

local function DispelPaletteSignature(pack)
	local colors = type(pack) == "table" and pack.colors or nil
	local signature = {}
	for i = 1, #DISPEL_COLORS do
		local key = DISPEL_COLORS[i][2]
		local value = type(colors) == "table" and colors[key] or nil
		if type(value) == "table" then
			signature[#signature + 1] = key
			signature[#signature + 1] = tostring(value[1] or 1)
			signature[#signature + 1] = tostring(value[2] or 1)
			signature[#signature + 1] = tostring(value[3] or 1)
			signature[#signature + 1] = tostring(PRESENTATION.alpha)
		else
			signature[#signature + 1] = key
			signature[#signature + 1] = "UNAVAILABLE"
		end
	end
	return table.concat(signature, ":")
end

local function DispelColorMap(pack)
  if type(CreateColor) ~= "function" then
    return nil
  end
  local colors = type(pack) == "table" and pack.colors or nil
  if type(colors) ~= "table" then
    return nil
  end
  local function Color(name)
    local value = colors[name]
    if type(value) ~= "table" then
      return nil
    end
    return CreateColor(value[1] or 1, value[2] or 1, value[3] or 1, PRESENTATION.alpha)
  end
	local map = {}
	for i = 1, #DISPEL_COLORS do
		local keys = DISPEL_COLORS[i]
		map[keys[1]] = Color(keys[2])
	end
	return map
end

local curveCache = {}
local function DispelSlotCurve(dispelType, color, signature)
  if not color or not C_CurveUtil or type(C_CurveUtil.CreateColorCurve) ~= "function" then
    return nil
  end
  local cached = curveCache[dispelType]
  if cached and cached.signature == signature then return cached.curve end
  local ok, curve = pcall(function()
    local result = C_CurveUtil.CreateColorCurve()
    -- Each owned slot admits exactly one public configured dispel type.
    -- Native visibility handles absence; the constant curve handles secret tint.
    result:AddPoint(0, color)
    result:AddPoint(255, color)
    return result
  end)
  if not ok or not curve then
    PRESENTATION.paletteCurveFailureCount = PRESENTATION.paletteCurveFailureCount + 1
    return nil
  end
  curveCache[dispelType] = {signature = signature, curve = curve}
  return curve
end

local function PreserveAssetStyle()
  local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
  return styles and styles.PreserveAsset or nil
end

function ns.RaiseMUFRangeShade(owner, above)
  if InCombatLockdown and InCombatLockdown() then return false end
  local host = owner and owner.rangeShadeHost
  if not host then return false end
  local baseLevel = owner.GetFrameLevel and owner:GetFrameLevel() or 0
  local level = math.max(host:GetFrameLevel() or 0, baseLevel + PRESENTATION.rangeShadeLevelOffset)
  if above and above.GetFrameLevel then
    level = math.max(level, (above:GetFrameLevel() or 0) + 1)
  end
  host:SetFrameLevel(level)
  return true
end

function ns.ConfigureMUFRangeShade(owner, statusEnabled, borderOn)
  if not owner or (InCombatLockdown and InCombatLockdown()) then return false end
  local host = owner.rangeShadeHost
  if not host then
    host = CreateFrame("Frame", nil, owner)
    host:SetAllPoints(owner)
    DisableInteraction(host)
    if host.SetPropagateMouseClicks then host:SetPropagateMouseClicks(true) end
    -- Isolate the one gate, not its textures: all shade pieces inherit exactly
    -- the same opacity, independent of the MUF's ancestor transparency.
    if host.SetIgnoreParentAlpha then host:SetIgnoreParentAlpha(true) end
    host:SetAlpha(0)
    host.texture = host:CreateTexture(nil, "OVERLAY", nil, 7)
    host.texture:SetColorTexture(0, 0, 0, 1)
    host.statusShade = host:CreateTexture(nil, "OVERLAY", nil, 7)
    host.statusShade:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    host.statusShade:SetVertexColor(0, 0, 0, 1)
    owner.rangeShadeHost = host
  end
  local edge = borderOn == false and 1 or 0
  host.texture:ClearAllPoints()
  host.texture:SetPoint("TOPLEFT", owner, "TOPLEFT", -edge, edge)
  host.texture:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
  if owner.statusLight then host.statusShade:SetAllPoints(owner.statusLight) end
  if statusEnabled == true and owner.statusLight then host.statusShade:Show() else host.statusShade:Hide() end
  host.rangeState, host.rangeBrightness = nil, nil
  ns.RaiseMUFRangeShade(owner, owner.readabilityHost)
  host:Show()
  return true
end

function ns.ApplyMUFRangeShade(owner, inRange, enabled, brightness)
  local host = owner and owner.rangeShadeHost
  if not host then return false end
  if type(brightness) ~= "number" then brightness = 0.50 end
  brightness = math.max(0, math.min(1, brightness))
  local opacity = 1 - brightness
  local public = true
  if enabled ~= true then
    inRange = true
  elseif (type(issecretvalue) == "function" and issecretvalue(inRange))
    or (type(canaccessvalue) == "function" and not canaccessvalue(inRange)) then
    public = false
  else
    -- Unknown/unavailable ranges remain bright. Only an actual false is out.
    inRange = inRange ~= false
  end
  if public and host.rangeState == inRange and host.rangeBrightness == brightness then return true end
  host.rangeState, host.rangeBrightness = nil, nil
  local ok, applied
  if type(host.SetAlphaFromBoolean) == "function" then
    ok, applied = pcall(host.SetAlphaFromBoolean, host, inRange, 0, opacity)
  elseif type(host.SetAlpha) == "function" then
    ok, applied = pcall(host.SetAlpha, host, public and inRange == false and opacity or 0)
  else
    return false
  end
  if not ok or applied == false then return false end
  if public then host.rangeState, host.rangeBrightness = inRange, brightness end
  return true
end

function ns.InvalidateMUFRangeShade(owner)
  local host = owner and owner.rangeShadeHost
  if host then host.rangeState, host.rangeBrightness = nil, nil end
end

local function CreateFillHost(slot, bounds)
  local host = CreateFrame("Frame", nil, slot)
  host:SetAllPoints(bounds)
	host:Hide()
  DisableInteraction(host)
  local texture = host:CreateTexture(nil, "ARTWORK", nil, 7)
  texture:SetAllPoints(host)
  texture:SetColorTexture(1, 1, 1, PRESENTATION.alpha)

  local supported = type(texture.SetIgnoreParentAlpha) == "function"
  local applied = false
  if supported then
    applied = pcall(texture.SetIgnoreParentAlpha, texture, true)
  end
  PRESENTATION.ignoreParentAlphaSupported = supported
  PRESENTATION.ignoreParentAlphaApplied = applied

  if applied then
    PRESENTATION.alphaIsolationMode = "OWNED_TEXTURE_IGNORE_PARENT_ALPHA"
  elseif type(host.SetIgnoreParentAlpha) == "function" then
    applied = pcall(host.SetIgnoreParentAlpha, host, true)
    if applied then
      PRESENTATION.alphaIsolationMode = "OWNED_SLOT_CHILD_HOST_IGNORE_PARENT_ALPHA"
    end
  end
  if not applied then
    PRESENTATION.alphaIsolationMode = "UNAVAILABLE_SLOT_VISIBILITY_PRESERVED"
  end

  host.texture = texture
  host.alphaIsolationMode = PRESENTATION.alphaIsolationMode
  return host
end

function ns.ConfigureMUFDispelPresentation(slot, pack, bounds, baseLevel, owner, slotInfo)
  -- Keep the existing host/texture returns for presentation callers. The extra
  -- result lets the coordinator withhold READY until the native fill is bound.
  local existingHost = slot and slot._decursivePresentationHost
  if InCombatLockdown and InCombatLockdown() then
    return existingHost, existingHost and existingHost.texture, false, "DEFERRED_COMBAT"
  end
  local style = PreserveAssetStyle()
  if not slot or not owner or not bounds or type(CreateFrame) ~= "function" or style == nil then
    return existingHost, existingHost and existingHost.texture, false, "FAILURE"
  end
  if slot.ClearAllPoints then
    slot:ClearAllPoints()
  end
  if slot.SetAllPoints then
    slot:SetAllPoints(bounds)
  end
  DisableInteraction(slot)

  baseLevel = type(baseLevel) == "number" and baseLevel or 0
  local priority = type(slotInfo) == "table" and tonumber(slotInfo.priority) or nil
  local priorityOffset = 0
  if type(priority) ~= "number" or priority < 1 or priority > #DISPEL_COLORS then
    priority = #DISPEL_COLORS + 1
  else
    priorityOffset = #DISPEL_COLORS - priority
  end
  if slot.SetFrameLevel then
    slot:SetFrameLevel(baseLevel + PRESENTATION.slotLevelOffset + priorityOffset)
  end

  local host = slot._decursivePresentationHost
  if not host then
    host = CreateFillHost(slot, bounds)
    slot._decursivePresentationHost = host
  end
  if host.SetFrameLevel then
    host:SetFrameLevel(baseLevel + PRESENTATION.fillLevelOffset + priorityOffset)
  end
  host.texture:SetColorTexture(1, 1, 1, PRESENTATION.alpha)

  local paletteSignature = DispelPaletteSignature(pack)
  local colorMap = DispelColorMap(pack)
  local dispelType = type(slotInfo) == "table" and slotInfo.dispelType or nil
  if type(dispelType) == "string" and type(colorMap) == "table" then
    colorMap = {[dispelType] = colorMap[dispelType]}
  end
  local colorCurve = type(dispelType) == "string" and colorMap
    and DispelSlotCurve(dispelType, colorMap[dispelType], paletteSignature) or nil
  PRESENTATION.paletteColorMode = colorCurve and "NATIVE_CONSTANT_CURVE" or "MAP_FALLBACK"
  paletteSignature = paletteSignature .. ":" .. tostring(dispelType) .. ":" .. PRESENTATION.paletteColorMode
  local options = {
    showAlways = false,
    showWhenHarmful = true,
    showWhenHelpful = false,
    showWithoutDispelType = false,
    style = style,
    customDispelColorMap = colorMap,
    customDispelColorCurve = colorCurve,
  }
  if not slot.AddDispelTypeTexture then
    return host, host.texture, false, "FAILURE"
  end
  local paletteChanged = slot._decursivePresentationRegistered == true
	and slot._decursivePresentationPaletteSignature ~= paletteSignature
  if paletteChanged then
	if type(slot.ClearDispelTypeTextures) ~= "function" then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture, false, "FAILURE"
	end
	local clearOK, cleared = pcall(slot.ClearDispelTypeTextures, slot)
	if not clearOK or cleared == false then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture, false, "FAILURE"
	end
	slot._decursivePresentationRegistered = false
	host:Hide()
	PRESENTATION.paletteRefreshGeneration = PRESENTATION.paletteRefreshGeneration + 1
  end
  if not slot._decursivePresentationRegistered then
	local addOK, registrationIndex = pcall(slot.AddDispelTypeTexture, slot, host.texture, options)
	if not addOK or registrationIndex == false then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture, false, "FAILURE"
	end
	host.registrationIndex = registrationIndex
	slot._decursivePresentationRegistered = true
	slot._decursivePresentationPaletteSignature = paletteSignature
	host:Show()
	PRESENTATION.paletteRegistrationGeneration = PRESENTATION.paletteRegistrationGeneration + 1
  elseif host.Show then
	host:Show()
  end
  return host, host.texture, true, "SUCCESS"
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("MUFPresentation")
end
