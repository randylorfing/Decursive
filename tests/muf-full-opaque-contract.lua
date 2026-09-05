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
  if actual ~= expected then
    error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local secretCategory = {}

Enum = {
  CustomAuraButtonDispelTypeTextureStyle = {
    BorderWithIcon = 1,
    PreserveAsset = 3,
  },
}

CreateColor = function(r, g, b, a)
  return {r = r, g = g, b = b, a = a}
end

local textureSupportsIgnoreParentAlpha = true

local function NewTexture(parent, owner, sublevel)
  local texture = {parent = parent, owner = owner, shown = true, asset = "SOLID", sublevel = sublevel or 0, alpha = 1}
  function texture:SetAlpha(value) self.alpha = value end
  function texture:SetAllPoints(target)
    self.bounds = target or self.parent
  end
  function texture:SetColorTexture(r, g, b, a)
    self.color = {r, g, b, a}
    self.asset = "SOLID"
  end
  if textureSupportsIgnoreParentAlpha then
    function texture:SetIgnoreParentAlpha(value)
      self.ignoreParentAlpha = value == true
    end
  end
  function texture:IsIgnoringParentAlpha()
    return self.ignoreParentAlpha == true
  end
  function texture:GetEffectiveAlpha()
    local parentAlpha = self.parent and self.parent:GetEffectiveAlpha() or 1
    if self.ignoreParentAlpha then
      parentAlpha = 1
    end
    return parentAlpha * self.alpha * (self.color and self.color[4] or 1)
  end
  function texture:IsEffectivelyShown()
    return self.shown and (not self.parent or self.parent:IsEffectivelyShown())
  end
  return texture
end

local function NewFrame(parent)
  local frame = {parent = parent, shown = true, mouse = true, alpha = 1}
  function frame:SetAllPoints(target)
    self.bounds = target or self.parent
  end
  function frame:EnableMouse(value)
    self.mouse = value
  end
  function frame:SetMouseClickEnabled(value)
    self.click = value
  end
  function frame:SetMouseMotionEnabled(value)
    self.motion = value
  end
  function frame:SetFrameLevel(value)
    self.level = value
  end
  function frame:SetAlpha(value)
    self.alpha = value
  end
  function frame:Hide()
    self.shown = false
  end
  function frame:Show()
    self.shown = true
  end
  function frame:SetIgnoreParentAlpha(value)
    self.ignoreParentAlpha = value == true
  end
  function frame:GetParent()
    return self.parent
  end
  function frame:GetEffectiveAlpha()
    local parentAlpha = self.parent and self.parent:GetEffectiveAlpha() or 1
    if self.ignoreParentAlpha then
      parentAlpha = 1
    end
    return parentAlpha * self.alpha
  end
  function frame:CreateTexture(_name, _layer, _template, sublevel)
    local resolved = sublevel or 0
    if type(resolved) ~= "number" or resolved < -8 or resolved > 7 then
      error("CreateTexture sublevel must be in the range -8 to 7", 2)
    end
    local texture = NewTexture(self, "addon", resolved)
    self.createdTexture = texture
    return texture
  end
  function frame:IsEffectivelyShown()
    return self.shown and (not self.parent or self.parent:IsEffectivelyShown())
  end
  return frame
end

CreateFrame = function(_kind, _name, parent)
  return NewFrame(parent)
end

local function NewSlot(unit)
  local container = NewFrame(nil)
  container.unit = unit
  container.enabled = true
  container.assigned = true
  local slot = NewFrame(container)
  slot.shown = false
  slot.container = container
  slot.unit = unit
  slot.nativeIcon = NewTexture(slot, "native")
  slot.nativeCooldown = {owner = "native"}
  slot.nativeText = {owner = "native"}
  function slot:ClearAllPoints()
    self.bounds = nil
  end
  function slot:ClearDispelTypeTextures()
    self.registered = nil
    self.clearCount = (self.clearCount or 0) + 1
  end
  function slot:AddDispelTypeTexture(texture, options)
    self.registered = {texture = texture, options = options}
    self.addCount = (self.addCount or 0) + 1
    if options.style == nil or options.style == Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon then
      texture.asset = "BLIZZARD_BORDER_WITH_ICON"
    end
    return self.addCount
  end
  function slot:DriveNativeMatch(category)
    if category == nil then
      self.shown = false
      return
    end
    self.shown = true
    local key = category == secretCategory and "Magic" or category
    local color = self.registered.options.customDispelColorMap[key]
    self.registered.texture.color = {color.r, color.g, color.b, color.a}
  end
  return slot
end

local ns = {}
assert(loadfile("ZDecursive/MUFPresentation.lua"))("ZDecursive", ns)

local pack = {
  colors = {
    magic = {0.20, 0.60, 1.00, 0.2},
    curse = {0.60, 0.00, 1.00, 0.3},
    disease = {0.60, 0.40, 0.00, 0.4},
    poison = {0.00, 0.60, 0.00, 0.5},
    bleed = {0.80, 0.10, 0.10, 0.6},
  },
}

local slots = {
  NewSlot("player"),
  NewSlot("party1"),
  NewSlot("partypet1"),
}
local native = {}
for i = 1, #slots do
  local slot = slots[i]
  local root = NewFrame(nil)
  local owner = NewFrame(root)
  owner.unit = slot.unit
  owner.level = 0
  owner:SetAlpha(0.35)
  slot.container.parent = owner
  native[i] = {
    icon = slot.nativeIcon,
    cooldown = slot.nativeCooldown,
    text = slot.nativeText,
    add = slot.AddDispelTypeTexture,
    clear = slot.ClearDispelTypeTextures,
  }
  local bounds = {unit = slot.unit}
  local host, texture = ns.ConfigureMUFDispelPresentation(slot, pack, bounds, 0, owner)
  Check(host and texture, "presentation created for " .. slot.unit)
  Equal(host.parent, slot, "presentation host is an owned child of the native slot visibility gate")
  Equal(host.bounds, bounds, "presentation host covers the full MUF inner bounds")
  Equal(texture.bounds, host, "presentation texture covers full host")
  Equal(texture.owner, "addon", "registered texture is addon-owned")
  Equal(texture.color[4], 1, "presentation base alpha is opaque")
  Check(texture:IsIgnoringParentAlpha(), "only the addon-owned affliction texture bypasses parent alpha")
  Equal(texture:GetEffectiveAlpha(), 1, "affliction remains effectively opaque above a 0.35 MUF ancestor")
  Equal(texture.sublevel, 7, "presentation uses the highest legal WoW texture sublevel")
  Equal(host.level, 40, "fill layer offset")
  Equal(slot.level, 24, "native slot layer offset")
  Check(host.level > slot.level, "addon fill is structurally above native slot art")
  Check(host.level > ns.MUF_PRESENTATION.managedLevelOffset, "addon fill is structurally above ordinary managed overlays")
  Check(host.level < ns.MUF_PRESENTATION.deathLevelOffset, "addon fill remains below authoritative death state")
  Equal(slot.mouse, false, "slot remains noninteractive")
  Equal(slot.registered.texture, texture, "only addon texture registered")
  Equal(slot.registered.options.style, Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, "provider preserves addon solid art")
  Equal(texture.asset, "SOLID", "provider does not stamp BorderWithIcon art over the fill")
  Equal(slot.clearCount, nil, "presentation does not clear native registrations")
  Check(slot.container.shown and slot.container.enabled and slot.container.assigned, "container remains shown enabled assigned")
end

-- detect.49 real-client payload: the player was registered while Open World
-- supplied a custom red Magic color, then survived the Dungeon transition with
-- that registration. Newly assigned followers registered Dungeon's blue Magic.
-- Reinitializing the existing player slot must refresh its owned registration.
local openWorldPack = {
	colors = {
		magic = {1, 0.07450980693101883, 0.207843154668808, 1},
	},
}
local dungeonPack = {
	colors = {
		magic = {0.20, 0.60, 1.00, 1},
	},
}
local stalePlayer = NewSlot("player")
local freshFollower = NewSlot("party1")
local staleOwner = NewFrame(nil)
local freshOwner = NewFrame(nil)
stalePlayer.container.parent = staleOwner
freshFollower.container.parent = freshOwner
local staleHost, staleTexture = ns.ConfigureMUFDispelPresentation(stalePlayer, openWorldPack, {unit = "player"}, 0, staleOwner)
ns.ConfigureMUFDispelPresentation(freshFollower, dungeonPack, {unit = "party1"}, 0, freshOwner)
stalePlayer:DriveNativeMatch("Magic")
freshFollower:DriveNativeMatch("Magic")
Equal(stalePlayer.registered.options.customDispelColorMap.Magic.r, 1, "detect.49 player payload starts with Open World red Magic")
Equal(freshFollower.registered.options.customDispelColorMap.Magic.r, 0.20, "new follower payload starts with Dungeon blue Magic")
Equal(stalePlayer.clearCount, nil, "initial player registration does not clear the dedicated slot")
Equal(stalePlayer.addCount, 1, "initial player registration occurs once")

local refreshedHost, refreshedTexture = ns.ConfigureMUFDispelPresentation(stalePlayer, dungeonPack, {unit = "player"}, 0, staleOwner)
Equal(refreshedHost, staleHost, "palette refresh reuses the player owned host")
Equal(refreshedTexture, staleTexture, "palette refresh reuses the player owned texture")
Equal(stalePlayer.clearCount, 1, "changed palette clears only the dedicated player slot registration")
Equal(stalePlayer.addCount, 2, "changed palette re-adds exactly one owned registration")
Equal(stalePlayer.registered.options.customDispelColorMap.Magic.r, 0.20, "existing player receives Dungeon Magic red channel")
Equal(stalePlayer.registered.options.customDispelColorMap.Magic.g, 0.60, "existing player receives Dungeon Magic green channel")
Equal(stalePlayer.registered.options.customDispelColorMap.Magic.b, 1.00, "existing player receives Dungeon Magic blue channel")
stalePlayer:DriveNativeMatch("Magic")
Equal(stalePlayer.registered.texture.color[1], freshFollower.registered.texture.color[1], "same Magic payload paints identical player/follower red")
Equal(stalePlayer.registered.texture.color[2], freshFollower.registered.texture.color[2], "same Magic payload paints identical player/follower green")
Equal(stalePlayer.registered.texture.color[3], freshFollower.registered.texture.color[3], "same Magic payload paints identical player/follower blue")

ns.ConfigureMUFDispelPresentation(stalePlayer, dungeonPack, {unit = "player"}, 0, staleOwner)
Equal(stalePlayer.clearCount, 1, "unchanged palette never clears again")
Equal(stalePlayer.addCount, 2, "unchanged palette never appends a duplicate registration")
Equal(stalePlayer.unit, "player", "palette refresh never changes the native player assignment")

slots[2]:DriveNativeMatch(secretCategory)
Check(not slots[1]._decursivePresentationHost.texture:IsEffectivelyShown(), "healthy player remains unpainted")
Check(slots[2]._decursivePresentationHost.texture:IsEffectivelyShown(), "only matching party MUF paints")
Check(not slots[3]._decursivePresentationHost.texture:IsEffectivelyShown(), "healthy pet remains unpainted")
local magic = slots[2].registered.texture.color
Equal(magic[1], 0.20, "secret C-side magic red")
Equal(magic[2], 0.60, "secret C-side magic green")
Equal(magic[3], 1.00, "secret C-side magic blue")
Equal(magic[4], 1, "secret C-side match remains opaque")

local function TopVisibleLayer(layers)
  local top
  for i = 1, #layers do
    local layer = layers[i]
    if layer.shown and (not top or layer.level > top.level) then
      top = layer
    end
  end
  return top
end

-- detect.46's first-refresh failure: both MUFs use the same native provider and
-- receive the same red match, but a transient blue range layer at level 36
-- covered only one because the old affliction host was at level 25. Clearing
-- and reapplying after range settled made both appear red.
local firstPack = {
  colors = {
    magic = {1, 0, 0, 1},
    range = {0, 0.45, 1, 1},
  },
}
local firstSlots = {NewSlot("party1"), NewSlot("party2")}
local firstHosts = {}
for i = 1, #firstSlots do
  local owner = NewFrame(nil)
  firstSlots[i].container.parent = owner
  firstHosts[i] = ns.ConfigureMUFDispelPresentation(firstSlots[i], firstPack, {unit = firstSlots[i].unit}, 0, owner)
  firstSlots[i]:DriveNativeMatch("Magic")
end
local redLayer1 = {name = "AFFLICTION_RED", level = firstHosts[1].level, shown = firstHosts[1].texture:IsEffectivelyShown()}
local redLayer2 = {name = "AFFLICTION_RED", level = firstHosts[2].level, shown = firstHosts[2].texture:IsEffectivelyShown()}
local rangeSettled = {name = "RANGE_BLUE", level = ns.MUF_PRESENTATION.managedLevelOffset, shown = false}
local rangeTransient = {name = "RANGE_BLUE", level = ns.MUF_PRESENTATION.managedLevelOffset, shown = true}
Equal(TopVisibleLayer({redLayer1, rangeSettled}).name, "AFFLICTION_RED", "first same-provider MUF paints red")
Equal(TopVisibleLayer({redLayer2, rangeTransient}).name, "AFFLICTION_RED", "transient initial blue managed state cannot cover the second same-provider affliction")
local detect46Red = {name = "AFFLICTION_RED", level = 25, shown = true}
Equal(TopVisibleLayer({detect46Red, rangeTransient}).name, "RANGE_BLUE", "detect.46 ordering reproduces the initial red-versus-blue failure")

for i = 1, #firstSlots do
  firstSlots[i]:DriveNativeMatch(nil)
  Check(not firstHosts[i].texture:IsEffectivelyShown(), "release clears the provider-gated fill " .. i)
  local reboundHost, reboundTexture = ns.ConfigureMUFDispelPresentation(firstSlots[i], firstPack, {unit = "rebound" .. i}, 0, firstHosts[i].parent)
  Equal(reboundHost, firstHosts[i], "rebind reuses the owned slot child " .. i)
  Equal(reboundTexture, firstHosts[i].texture, "rebind reuses the registered provider texture " .. i)
  Equal(firstSlots[i].addCount, 1, "rebind never duplicates provider registration " .. i)
  firstSlots[i]:DriveNativeMatch("Magic")
  Check(firstHosts[i].texture:IsEffectivelyShown(), "reapply after release restores only the active provider fill " .. i)
end

math.randomseed(4701)
for iteration = 1, 64 do
  local slotIndex = math.random(2)
  local transientManaged = math.random(2) == 1
  local providerLayer = {
    name = "AFFLICTION_RED",
    level = firstHosts[slotIndex].level,
    shown = firstHosts[slotIndex].texture:IsEffectivelyShown(),
  }
  local managedLayer = {
    name = "RANGE_OR_SOUL_LINK",
    level = ns.MUF_PRESENTATION.managedLevelOffset,
    shown = transientManaged,
  }
  Equal(TopVisibleLayer({managedLayer, providerLayer}).name, "AFFLICTION_RED", "random pool/setup order preserves affliction precedence " .. iteration)
end

slots[2]:DriveNativeMatch(nil)
slots[3]:DriveNativeMatch("Poison")
Check(not slots[2]._decursivePresentationHost.texture:IsEffectivelyShown(), "removed match clears old MUF through provider ownership")
Check(slots[3]._decursivePresentationHost.texture:IsEffectivelyShown(), "new pet match paints only pet MUF")
Equal(slots[3].registered.texture.color[4], 1, "configured poison fill forced opaque")

slots[3].restricted = true
slots[3]:DriveNativeMatch(nil)
slots[3]:DriveNativeMatch(secretCategory)
Check(slots[3]._decursivePresentationHost.texture:IsEffectivelyShown(), "C-side provider drives the owned fill during combat restriction")
Equal(slots[3]._decursivePresentationHost.texture.asset, "SOLID", "combat refresh preserves the full-square asset")
Equal(slots[3]._decursivePresentationHost.texture:GetEffectiveAlpha(), 1, "combat refresh remains effectively opaque")

for category, expected in pairs({
  Magic = {0.20, 0.60, 1.00},
  Curse = {0.60, 0.00, 1.00},
  Disease = {0.60, 0.40, 0.00},
  Poison = {0.00, 0.60, 0.00},
}) do
  slots[3]:DriveNativeMatch(category)
  local color = slots[3].registered.texture.color
  Equal(color[1], expected[1], category .. " red")
  Equal(color[2], expected[2], category .. " green")
  Equal(color[3], expected[3], category .. " blue")
  Equal(color[4], 1, category .. " alpha")
end
Check(slots[3].registered.options.customDispelColorMap.Enrage == nil, "hostile Enrage has no actionable provider color")
Check(slots[3].registered.options.customDispelColorMap.Bleed == nil, "Bleed has no actionable provider color")
Check(slots[3].registered.options.customDispelColorMap.Charm == nil, "legacy Charm has no actionable provider color")

local oldHost = slots[3]._decursivePresentationHost
local oldTexture = oldHost.texture
ns.ConfigureMUFDispelPresentation(slots[3], pack, {unit = "pet"}, 0, oldHost.parent)
Equal(slots[3]._decursivePresentationHost, oldHost, "repeated setup reuses presentation child")
Equal(slots[3].registered.texture, oldTexture, "repeated setup reuses addon texture")
Equal(slots[3].addCount, 1, "repeated setup does not duplicate provider registration")
Equal(slots[3].unit, "partypet1", "presentation setup never reassigns native unit")
Equal(oldTexture:GetEffectiveAlpha(), 1, "repeated setup preserves parent-alpha isolation")

textureSupportsIgnoreParentAlpha = false
local fallbackRoot = NewFrame(nil)
local fallbackOwner = NewFrame(fallbackRoot)
fallbackOwner:SetAlpha(0.35)
local fallbackSlot = NewSlot("party4")
fallbackSlot.container.parent = fallbackOwner
local fallbackHost, fallbackTexture = ns.ConfigureMUFDispelPresentation(fallbackSlot, pack, {unit = "party4"}, 0, fallbackOwner)
Equal(fallbackHost.parent, fallbackSlot, "fallback remains under the native visibility gate")
Equal(fallbackTexture:GetEffectiveAlpha(), 1, "owned slot-child host fallback avoids the 0.35 MUF ancestor")
Equal(fallbackSlot.registered.texture, fallbackTexture, "fallback registers only the addon-owned replacement texture")
Equal(ns.MUF_PRESENTATION.alphaIsolationMode, "OWNED_SLOT_CHILD_HOST_IGNORE_PARENT_ALPHA", "fallback mode is diagnostic")

textureSupportsIgnoreParentAlpha = true
local restoreRoot = NewFrame(nil)
local restoreOwner = NewFrame(restoreRoot)
restoreOwner:SetAlpha(0.35)
local restoreSlot = NewSlot("party5")
restoreSlot.container.parent = restoreOwner
ns.ConfigureMUFDispelPresentation(restoreSlot, pack, {unit = "party5"}, 0, restoreOwner)

local detect45Owner = NewFrame(nil)
detect45Owner:SetAlpha(0.35)
local detect45Slot = NewSlot("party6")
detect45Slot.container.parent = detect45Owner
local detect45Host = NewFrame(detect45Owner)
local detect45Texture = NewTexture(detect45Host, "addon", 7)
detect45Texture:SetColorTexture(1, 1, 1, 1)
detect45Texture:SetIgnoreParentAlpha(true)
Check(not detect45Slot:IsEffectivelyShown(), "healthy native slot is hidden")
Check(detect45Texture:IsEffectivelyShown(), "detect.45 owner-parented texture escapes the hidden native slot")
Equal(detect45Texture:GetEffectiveAlpha(), 1, "detect.45 escaped healthy texture becomes fully white")

local function EffectiveAlpha(parentAlpha, localAlpha, ignoreParentAlpha)
  return (ignoreParentAlpha and 1 or parentAlpha) * localAlpha
end

Equal(EffectiveAlpha(0.35, 1, false), 0.35, "detect.44 composition reproduces the translucent parent times local result")
Equal(EffectiveAlpha(0.35, 1, true), 1, "affliction alone bypasses the parent-alpha multiplier")
Equal(EffectiveAlpha(0.35, 0.60, false), 0.21, "range keeps intentional normal alpha composition")
Equal(EffectiveAlpha(0.35, 1, false), 0.35, "Soul Link keeps intentional normal alpha composition")
Equal(EffectiveAlpha(0.35, 1, false), 0.35, "death keeps intentional normal alpha composition")
Equal(EffectiveAlpha(0.35, 0.62, false), 0.217, "cooldown keeps intentional normal alpha composition")

for i = 1, #slots do
  local slot = slots[i]
  Equal(slot.nativeIcon, native[i].icon, "native icon identity unchanged")
  Equal(slot.nativeCooldown, native[i].cooldown, "native cooldown identity unchanged")
  Equal(slot.nativeText, native[i].text, "native text identity unchanged")
  Equal(slot.AddDispelTypeTexture, native[i].add, "native AddDispelTypeTexture method unchanged")
  Equal(slot.ClearDispelTypeTextures, native[i].clear, "native clear method unchanged")
end

Check(ns.MUF_PRESENTATION.nativeChildrenUntouched, "diagnostic native-child contract")
Equal(ns.MUF_PRESENTATION.hostParent, "NATIVE_AURA_SLOT", "diagnostic host ownership contract")
Equal(ns.MUF_PRESENTATION.hostBounds, "INNER_FILL_FULL_BOUNDS", "diagnostic full-bounds contract")
Equal(ns.MUF_PRESENTATION.visibilityGate, "NATIVE_AURA_SLOT_PARENT", "diagnostic visibility gate")
Equal(ns.MUF_PRESENTATION.healthyVisibility, "INHERITED_SLOT_HIDDEN", "diagnostic healthy visibility")
Equal(ns.MUF_PRESENTATION.afflictedVisibility, "INHERITED_SLOT_SHOWN", "diagnostic afflicted visibility")
Equal(ns.MUF_PRESENTATION.registrationStyle, "PRESERVE_ASSET", "diagnostic registration-style contract")
Equal(ns.MUF_PRESENTATION.alphaChain, "MUF_ANCESTOR_NATIVE_SLOT_HOST_TEXTURE_PROVIDER_VERTEX", "diagnostic alpha-chain contract")
Check(ns.MUF_PRESENTATION.ignoreParentAlphaSupported, "diagnostic records Retail region-method support")
Check(ns.MUF_PRESENTATION.ignoreParentAlphaApplied, "diagnostic records owned-texture isolation")
Equal(ns.MUF_PRESENTATION.alphaIsolationMode, "OWNED_TEXTURE_IGNORE_PARENT_ALPHA", "diagnostic alpha-isolation mode")
Equal(ns.MUF_PRESENTATION.localTextureAlpha, 1, "diagnostic local texture alpha")
Equal(ns.MUF_PRESENTATION.providerVertexAlpha, 1, "diagnostic provider vertex alpha")
Equal(ns.MUF_PRESENTATION.expectedEffectiveAlpha, 1, "diagnostic expected effective alpha")
Equal(ns.MUF_PRESENTATION.paletteRefreshMode, "OWNED_SLOT_CLEAR_READD_ON_SIGNATURE_CHANGE", "diagnostic palette refresh mode")
Equal(ns.MUF_PRESENTATION.paletteSignatureMode, "DISPEL_TYPE_RGBA", "diagnostic palette signature mode")
Check(ns.MUF_PRESENTATION.paletteRefreshGeneration >= 1, "diagnostic records palette refreshes")
Equal(ns.MUF_PRESENTATION.paletteRefreshFailureCount, 0, "diagnostic records no palette refresh failures")
Check(ns.MUF_PRESENTATION.cooldownLevelOffset > ns.MUF_PRESENTATION.fillLevelOffset, "cooldown layer is above fill")
Check(ns.MUF_PRESENTATION.readabilityLevelOffset > ns.MUF_PRESENTATION.fillLevelOffset, "readability layer is above fill")
Check(ns.MUF_PRESENTATION.fillLevelOffset > ns.MUF_PRESENTATION.managedLevelOffset, "affliction is above range, Soul Link, and ordinary managed state")
Check(ns.MUF_PRESENTATION.deathLevelOffset > ns.MUF_PRESENTATION.fillLevelOffset, "death remains authoritative over affliction")
Equal(ns.MUF_PRESENTATION.afflictionPrecedence, "ABOVE_RANGE_SOUL_LINK_ORDINARY_MANAGED", "diagnostic affliction precedence")
Equal(ns.MUF_PRESENTATION.mode, "FULL_OPAQUE", "presentation mode")

io.write("muf-full-opaque-contract: ok\n")
