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

local createdTextures = {}

local function NewRegion(kind, parent, layer, sublevel)
  local region = {
    kind = kind,
    parent = parent,
    layer = layer,
    sublevel = sublevel or 0,
    shown = true,
    alpha = 1,
  }
  local function Store(_self, ...)
    _self.last = {...}
  end
  region.SetPoint = Store
  region.SetSize = Store
  region.SetAllPoints = Store
  region.ClearAllPoints = Store
  region.SetColorTexture = function(self, ...)
    self.color = {...}
  end
  region.SetVertexColor = function(self, ...)
    self.vertex = {...}
  end
  region.SetTexture = Store
  region.SetText = Store
  region.SetTextColor = Store
  region.Show = function(self)
    self.shown = true
  end
  region.Hide = function(self)
    self.shown = false
  end
  region.SetAlpha = function(self, alpha)
    self.alpha = alpha
  end
  region.SetAlphaFromBoolean = function(self, value, trueAlpha, falseAlpha)
    self.booleanValue = value
    if value == true then
      self.alpha = trueAlpha
    elseif value == false then
      self.alpha = falseAlpha
    end
  end
  region.SetVertexColorFromBoolean = function(self, value, trueColor, falseColor)
    self.booleanValue = value
    if value == true then
      self.vertex = trueColor
    elseif value == false then
      self.vertex = falseColor
    end
  end
  return region
end

local function NewFrame(parent)
  local frame = {parent = parent, frameLevel = 3, shown = true}
  local function Store(self, ...)
    self.last = {...}
  end
  frame.RegisterForClicks = Store
  frame.SetClampedToScreen = Store
  frame.SetFrameStrata = Store
  frame.SetSize = Store
  frame.SetPoint = Store
  frame.SetAllPoints = Store
  frame.EnableMouse = Store
  frame.SetMouseClickEnabled = Store
  frame.SetMouseMotionEnabled = Store
  frame.SetScript = function(self, script, callback)
    self.scripts = self.scripts or {}
    self.scripts[script] = callback
  end
  frame.GetFrameLevel = function(self)
    return self.frameLevel
  end
  frame.SetFrameLevel = function(self, value)
    self.frameLevel = value
  end
  frame.SetAlpha = function(self, value)
    self.alpha = value
  end
  frame.SetAlphaFromBoolean = function(self, value, trueAlpha, falseAlpha)
    self.booleanValue = value
    if value == true then
      self.alpha = trueAlpha
    elseif value == false then
      self.alpha = falseAlpha
    end
  end
  frame.CreateTexture = function(self, _name, layer, _template, sublevel)
    local resolved = sublevel or 0
    if type(resolved) ~= "number" or resolved < -8 or resolved > 7 then
      error("CreateTexture sublevel must be in the range -8 to 7", 2)
    end
    local texture = NewRegion("Texture", self, layer, resolved)
    createdTextures[#createdTextures + 1] = texture
    return texture
  end
  frame.CreateFontString = function(self, _name, layer)
    return NewRegion("FontString", self, layer, 0)
  end
  frame.Show = function(self)
    self.shown = true
  end
  frame.Hide = function(self)
    self.shown = false
  end
  return frame
end

CreateFrame = function(_kind, _name, parent)
  return NewFrame(parent)
end

issecretvalue = function(value)
  return type(value) == "table" and value.secret == true
end

canaccessvalue = function(value)
  return not issecretvalue(value)
end

CreateColor = function(r, g, b, a)
  return {r, g, b, a}
end

local ns = {}
assert(loadfile("ZDecursive/MUFPresentation.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)

local parent = NewFrame(nil)
local first = ns.CreateMUFVisualValidationFrame(parent)
local second = ns.CreateMUFVisualValidationFrame(parent)
Check(first and second and first ~= second, "real MUF visual constructor initializes repeatedly")
Check(#createdTextures >= 30, "all live textures initialize on two complete MUFs")
Check(first.cdTex == nil and second.cdTex == nil, "removed cooldown texture path stays absent")

for i = 1, #createdTextures do
  local sublevel = createdTextures[i].sublevel
  Check(sublevel >= -8 and sublevel <= 7, "texture " .. i .. " stays inside WoW sublevel range")
end

Equal(first.managedHost.frameLevel, 39, "managed overlays frame level")
Equal(first.deathHost.frameLevel, 47, "death host stays above range and Soul Link")
Check(first.cooldownHost == nil, "removed cooldown host path stays absent")
Equal(first.readabilityHost.frameLevel, 67, "text, raid icon, status and skull keep their existing content layer")
Check(first.rangeShadeHost.frameLevel > first.readabilityHost.frameLevel, "whole-MUF shade is above icons, text and skull")
Check(first.deadFill.parent == first.deathHost, "death fill is isolated on authoritative frame host")
Equal(first.deadFill.sublevel, 0, "death fill uses a legal texture sublevel")
Check(first.rangeHost.parent == first.managedHost and first.rangeOverlay.parent == first.rangeHost and first.soulLinkFill.parent == first.managedHost, "range composition and Soul Link stay below death")
Equal(first.rangeHost.frameLevel, first.managedHost.frameLevel, "range composition retains managed precedence")
Check(first.skullTex.parent == first.readabilityHost, "skull stays in the content layer below range dimming")

local pack = {
  colors = {dead = {0, 0, 0, 1}},
}
local dead = ns.ResolveMUFDeathPresentation(pack, true, false, "PUBLIC_DEAD")
Check(ns.ApplyMUFDeathPresentation(first.deadFill, first.skullTex, dead), "dead state applies after full initialization")
Equal(first.deadFill.vertex[4], 1, "dead fill is opaque")
Equal(first.skullTex.vertex[4], 1, "dead skull is visible")

local cooldown = ns.ResolveMUFCooldownPresentation(true, true, true)
Check(cooldown.suppressedBySkull and not cooldown.active, "dead skull suppresses cooldown")

local alive = ns.ResolveMUFDeathPresentation(pack, false, true, "PUBLIC_ALIVE")
ns.ApplyMUFDeathPresentation(first.deadFill, first.skullTex, alive)
local resumed = ns.ResolveMUFCooldownPresentation(true, false, false)
Check(resumed.active and not resumed.suppressedBySkull, "valid cooldown may resume after alive transition")
Equal(first.deadFill.vertex[4], 0, "alive transition clears death fill")
Equal(first.skullTex.vertex[4], 0, "alive transition clears skull")

local range = ns.ResolveMUFRangePresentation({colors = {range = {0.2, 0.4, 0.8, 1}}, mufs = {dimOutOfRange = true, dimAmount = 0.7}}, false, false)
ns.ApplyMUFRangePresentation(first.rangeOverlay, range, first.rangeHost)
Equal(first.rangeOverlay.alpha, 1, "out-of-range texture remains locally opaque")
Equal(first.rangeOverlay.color[4], 1, "out-of-range intrinsic texture alpha is one")
Equal(first.rangeOverlay.color[1], 0.2, "range RGB stays full before the whole-MUF shade")
ns.ApplyMUFRangeShade(first, false, true, range.alpha)
Equal(first.rangeShadeHost.alpha, 1 - range.alpha, "one top shade controls final brightness")
Equal(first.rangeHost.alpha, 1, "out-of-range composition host remains opaque")

local secret = {secret = true}
local secretDeath = ns.ResolveMUFDeathPresentation(pack, secret, false, "SECRET_NATIVE")
ns.ApplyMUFDeathPresentation(second.deadFill, second.skullTex, secretDeath)
Check(second.deadFill.booleanValue == secret and second.skullTex.booleanValue == secret, "secret death state reaches native boolean widgets unchanged")

io.write("muf-visual-init-contract: ok\n")
