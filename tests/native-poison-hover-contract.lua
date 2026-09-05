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


-- Exercise the real MUF constructor and its native-slot initializer. Native aura
-- contents/visibility live in the test driver, never in addon-readable payloads.
local combat = false
InCombatLockdown = function() return combat end
Enum = {CustomAuraButtonDispelTypeTextureStyle = {PreserveAsset = 3}}
local frames = {}
local nativeTypes = {}
local initialized = {}
local ns = {PACK = {
  mufs = {tooltip = true},
  colors = {magic = {1, 0, 0, 1}, curse = {0.6, 0, 1, 1},
    poison = {0, 1, 0, 1}, disease = {1, 0.3, 0, 1}},
}}
local mouseWrites = 0
local function InputFrame(parent, native)
  local frame = NewFrame(parent)
  frame.click = native == true
  frame.motion = native == true
  function frame:EnableMouse(value)
    Check(not combat, 'EnableMouse is not rewritten in combat')
    Check(not native or value ~= true, 'native tooltip never broadly re-enables clicks')
    self.click, self.motion = value, value
    mouseWrites = mouseWrites + 1
  end
  function frame:SetMouseClickEnabled(value) self.click = value end
  function frame:SetMouseMotionEnabled(value)
    Check(not combat, 'mouse motion is not rewritten in combat')
    self.motion = value
    mouseWrites = mouseWrites + 1
  end
  function frame:SetPropagateMouseClicks(value) self.propagate = value end
  function frame:SetPassThroughButtons(...) self.passButtons = {...} end
  function frame:GetParent() return self.parent end
  function frame:ClearAllPoints() end
  function frame:SetTooltipAnchorPoint(...) self.tooltipAnchor = {...} end
  function frame:SetHideTooltipInCombat(value) self.hideTooltipInCombat = value end
  function frame:AddDispelTypeTexture() return 1 end
  if native then
    function frame:SetScript() error('addon must not replace native tooltip scripts') end
  end
  frames[#frames + 1] = frame
  return frame
end
CreateFrame = function(kind, _name, parent, template)
  local frame = InputFrame(parent, false)
  if template == 'SecureUnitButtonTemplate' then frame.click = true end
  return frame
end
ns.DetectionEngine = {
  CreateCarrier = function(_self, bank, parent, initialize, owner)
    Equal(bank, 'MUFs', 'actual MUF native carrier bank')
    local carrier = InputFrame(parent, false)
    local slots = {}
    for priority, dispelType in ipairs({'Magic', 'Curse', 'Poison', 'Disease'}) do
      local slot = InputFrame(carrier, true)
      local info = {priority = priority, dispelType = dispelType}
      nativeTypes[slot] = dispelType
      initialize(slot, dispelType, info)
      slot.shown = false
      slots[#slots + 1] = slot
      initialized[#initialized + 1] = {frame = slot, callback = initialize, info = info}
    end
    carrier.slots = slots
    return carrier
  end,
}
assert(loadfile('ZDecursive/MUFPresentation.lua'))('ZDecursive', ns)
assert(loadfile('ZDecursive/MUFs.lua'))('ZDecursive', ns)
local button = ns.CreateMUFVisualValidationFrame(InputFrame(nil, false))
button.shown = true
local slots = button.auraContainer.slots
local poison = slots[3]
Equal(poison.motion, true, 'poison slot receives native tooltip hover')
Equal(poison.click, false, 'poison slot cannot consume dispel clicks')
Equal(poison.hideTooltipInCombat, false, 'native poison tooltip remains allowed in combat')
Equal(poison.tooltipAnchor[1], 'ANCHOR_RIGHT', 'native tooltip retains its anchor')

local function HoverWinner()
  local winner
  for _, slot in ipairs(slots) do
    if slot.shown and slot.motion and (not combat or not slot.hideTooltipInCombat) then
      if not winner or slot.frameLevel > winner.frameLevel then winner = slot end
    end
  end
  return winner and nativeTypes[winner] or nil
end
local function CheckClickThrough()
  for _, slot in ipairs(slots) do
    Equal(slot.click, false, 'every native type passes all mouse gestures through')
    Equal(slot.propagate, true, 'click propagation stays enabled')
    Equal(table.concat(slot.passButtons, ','), 'LeftButton,RightButton,MiddleButton,Button4,Button5', 'all physical buttons pass through')
    Equal(slot._decursivePresentationHost.click, false, 'fill overlay remains noninteractive')
    Equal(slot._decursivePresentationHost.motion, false, 'fill overlay cannot cover native hover')
  end
  Equal(button.click, true, 'secure MUF remains the click target')
end

for _, locked in ipairs({false, true}) do
  combat = locked
  poison.shown = true
  Equal(HoverWinner(), 'Poison', 'native provider displays the poison tooltip')
  CheckClickThrough()
  slots[1].shown = true
  Equal(HoverWinner(), 'Magic', 'native tooltip follows visible cure priority')
  slots[1].shown = false
  Equal(HoverWinner(), 'Poison', 'poison tooltip resumes after higher priority clears')
  poison.shown = false
  Equal(HoverWinner(), nil, 'cleared poison has no stale tooltip')
end

poison.shown = true
local before = mouseWrites
for _, entry in ipairs(initialized) do entry.callback(entry.frame, 'refresh', entry.info) end
Equal(mouseWrites, before, 'combat refresh preserves the initialized hover mode')
Equal(HoverWinner(), 'Poison', 'tooltip still works after a combat refresh')
CheckClickThrough()

combat = false
ns.PACK.mufs.tooltip = false
for _, entry in ipairs(initialized) do entry.callback(entry.frame, 'refresh', entry.info) end
Equal(HoverWinner(), nil, 'applied environment tooltip-off disables native hover')
CheckClickThrough()
ns.PACK.mufs.tooltip = true
for _, entry in ipairs(initialized) do entry.callback(entry.frame, 'refresh', entry.info) end
Equal(HoverWinner(), 'Poison', 'applied environment tooltip-on restores native hover')
CheckClickThrough()
io.write('native-poison-hover-contract: ok\n')
