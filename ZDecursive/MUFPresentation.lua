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
  hostParent = "NATIVE_AURA_SLOT",
  hostBounds = "INNER_FILL_FULL_BOUNDS",
  visibilityGate = "NATIVE_AURA_SLOT_PARENT",
  healthyVisibility = "INHERITED_SLOT_HIDDEN",
  afflictedVisibility = "INHERITED_SLOT_SHOWN",
  registrationStyle = "PRESERVE_ASSET",
  order = "NATIVE_SLOT_MANAGED_FILL_DEATH_COOLDOWN_READABILITY",
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
}

ns.MUF_PRESENTATION = PRESENTATION

local function DisableInteraction(frame)
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

local function PreserveAssetStyle()
  local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
  return styles and styles.PreserveAsset or nil
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
  local style = PreserveAssetStyle()
  if not slot or not owner or not bounds or type(CreateFrame) ~= "function" or style == nil then
    return nil
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
  local options = {
    showAlways = false,
    showWhenHarmful = true,
    showWhenHelpful = false,
    showWithoutDispelType = false,
    style = style,
    customDispelColorMap = colorMap,
  }
  if not slot.AddDispelTypeTexture then
    return nil
  end
  local paletteChanged = slot._decursivePresentationRegistered == true
	and slot._decursivePresentationPaletteSignature ~= paletteSignature
  if paletteChanged then
	if type(slot.ClearDispelTypeTextures) ~= "function" then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture
	end
	local clearOK = pcall(slot.ClearDispelTypeTextures, slot)
	if not clearOK then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture
	end
	slot._decursivePresentationRegistered = false
	host:Hide()
	PRESENTATION.paletteRefreshGeneration = PRESENTATION.paletteRefreshGeneration + 1
  end
  if not slot._decursivePresentationRegistered then
	local addOK, registrationIndex = pcall(slot.AddDispelTypeTexture, slot, host.texture, options)
	if not addOK or registrationIndex == false then
		PRESENTATION.paletteRefreshFailureCount = PRESENTATION.paletteRefreshFailureCount + 1
		return host, host.texture
	end
	host.registrationIndex = registrationIndex
	slot._decursivePresentationRegistered = true
	slot._decursivePresentationPaletteSignature = paletteSignature
	host:Show()
	PRESENTATION.paletteRegistrationGeneration = PRESENTATION.paletteRegistrationGeneration + 1
  elseif host.Show then
	host:Show()
  end
  return host, host.texture
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("MUFPresentation")
end
