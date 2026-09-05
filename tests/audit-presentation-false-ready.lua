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

local failPalette = false
local baseCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
  if kind ~= "AuraContainer" then return baseCreateFrame(kind, name, parent, template) end
  local container = InputFrame(parent, false)
  container.slots = {}
  function container:SetUnit(unit) self.unit = unit end
  function container:SetEnabled(enabled) self.enabled = enabled end
  function container:AddAuraSlot(key, filter, options)
    local slot = InputFrame(self, true)
    function slot:AddDispelTypeTexture(texture, info)
      if failPalette then error("injected native dispel texture rejection") end
      self.registeredTexture = texture
      return 1
    end
    function slot:ClearDispelTypeTextures() self.registeredTexture = nil end
    self.slots[key] = slot
    options.initializeFrame(slot)
    return slot
  end
  function container:SetAuraSlotFilterString() end
  function container:SetAuraSlotCandidateFilters() end
  return container
end
local timerQueue = {}
C_Timer = {After = function(delay, callback) timerQueue[#timerQueue+1] = callback end}
ns.SafeNativeSetUnit = function(container, unit)
  if combat then return false, "DEFERRED_COMBAT" end
  return pcall(container.SetUnit, container, unit)
end
ns.GetDetectionSlots = function()
  local slots = {}
  for i, name in ipairs({"Magic", "Curse", "Poison", "Disease"}) do
    slots[i] = {key=name, filter="HARMFUL|DISPELLABLE", priority=i, dispelType=name,
      candidateFilters={includeDispelTypes={[name]=true}}}
  end
  return slots
end
assert(loadfile('ZDecursive/DetectionEngine.lua'))('ZDecursive', ns)
assert(loadfile('ZDecursive/MUFPresentation.lua'))('ZDecursive', ns)
assert(loadfile('ZDecursive/MUFs.lua'))('ZDecursive', ns)
local engine = ns.DetectionEngine
local button = ns.CreateMUFVisualValidationFrame(InputFrame(nil, false))
engine:RegisterConsumer("MUFs", function()
  local ok, status = engine:AssignCarrier(button, "player")
  return ok, status, 1
end)
engine:RegisterConsumer("Alerts", function() return true, "SUCCESS", 0 end)
engine:RegisterConsumer("LiveList", function() return true, "SUCCESS", 0 end)
Check(engine:Start(), "real MUF presentation starts successfully")
local slot = button.auraContainer.slots.Poison
Check(slot._decursivePresentationRegistered, "poison fill starts registered")
Check(slot._decursivePresentationHost.shown, "poison fill host starts visible")
failPalette = true
ns.PACK.colors.poison = {0.2, 0.8, 0.2, 1}
local applied = engine:Refresh("PALETTE_CHANGE")
io.write("native texture rejection: applied=" .. tostring(applied) .. " state=" .. engine.state ..
  " pending=" .. tostring(engine.pending) .. " retry=" .. tostring(engine.retryScheduled) ..
  " poisonRegistered=" .. tostring(slot._decursivePresentationRegistered) ..
  " poisonHostShown=" .. tostring(slot._decursivePresentationHost.shown) ..
  " paletteFailures=" .. ns.MUF_PRESENTATION.paletteRefreshFailureCount .. "\n")
Check(not applied and engine.pending and engine.retryScheduled,
  "native fill registration failure must prevent READY and schedule scoped recovery")
