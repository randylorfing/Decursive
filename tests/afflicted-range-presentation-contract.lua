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

-- One owner-level range gate dims the full MUF, including native cooldown text,
-- while singleton dispel providers keep their own visibility and opaque tint.
local function Read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local combat, allocations, rangeCalls = false, 0, 0
local range, lastSpell, lastUnit = nil, nil, nil
local dead, connected = false, true
local secret = setmetatable({}, {__eq = function() error("secret comparison") end, __tostring = function() error("secret serialization") end})
InCombatLockdown = function() return combat end
issecretvalue = function(value) return rawequal(value, secret) end
canaccessvalue = function(value) return not rawequal(value, secret) end
CreateColor = function(r, g, b, a) return {r = r, g = g, b = b, a = a} end
Enum = {CustomAuraButtonDispelTypeTextureStyle = {PreserveAsset = 3}}
C_Spell = {IsSpellInRange = function(spell, unit)
  rangeCalls, lastSpell, lastUnit = rangeCalls + 1, spell, unit
  return range
end}
UnitIsDeadOrGhost = function() return dead end
UnitIsConnected = function() return connected end
local function Frame(parent)
  local frame = {parent = parent, alpha = 1, shown = true, level = parent and parent.level + 1 or 0, calls = 0, points = {}}
  function frame:GetParent() return self.parent end
  function frame:SetAllPoints(bounds) self.bounds = bounds end
  function frame:ClearAllPoints() self.points = {} end
  function frame:SetPoint(...) self.points[#self.points + 1] = {...} end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:GetWidth() return self.width end
  function frame:SetFrameLevel(level) assert(not combat, "no combat frame-level mutation"); self.level = level end
  function frame:GetFrameLevel() return self.level end
  function frame:SetFrameStrata() assert(not combat) end
  function frame:RegisterForClicks() assert(not combat) end
  function frame:SetClampedToScreen() assert(not combat) end
  function frame:SetScript(event, callback) self.scripts = self.scripts or {}; self.scripts[event] = callback end
  function frame:EnableMouse(value) assert(not combat, "no combat mouse mutation"); self.mouse = value end
  function frame:SetMouseClickEnabled(value) assert(not combat, "no combat mouse mutation"); self.click = value end
  function frame:SetMouseMotionEnabled(value) assert(not combat, "no combat mouse mutation"); self.motion = value end
  function frame:SetPropagateMouseClicks(value) assert(not combat); self.propagate = value end
  function frame:SetIgnoreParentAlpha(value) assert(not combat); self.ignore = value end
  function frame:SetAlpha(alpha) self.alpha = alpha end
  function frame:Hide() self.shown = false end
  function frame:Show() self.shown = true end
  function frame:IsEffectivelyShown() return self.shown and (not self.parent or self.parent:IsEffectivelyShown()) end
  function frame:GetEffectiveAlpha() return self.alpha * (self.ignore and 1 or (self.parent and self.parent:GetEffectiveAlpha() or 1)) end
  function frame:GetChildren() error("native children must never be enumerated") end
  function frame:GetRegions() error("native regions must never be enumerated") end
  function frame:SetColorTexture(...) self.color = {...} end
  function frame:SetTexture(texture) self.asset = texture end
  function frame:SetVertexColor(...) self.vertex = {...} end
  function frame:SetVertexColorFromBoolean(value, yes, no)
    self.nativeVertexValue = value
    if not rawequal(value, secret) then self.vertex = value and yes or no end
  end
  function frame:SetAlphaFromBoolean(value, yes, no)
    self.calls = self.calls + 1
    if self.fail then error("native shade setter failed") end
    self.nativeValue, self.yes, self.no = value, yes, no
    if not rawequal(value, secret) then self.alpha = value and yes or no end
  end
  function frame:CreateTexture(_, layer, _, sublevel)
    assert(not combat, "all shade creation is out of combat")
    sublevel = sublevel or 0
    assert(sublevel >= -8 and sublevel <= 7)
    allocations = allocations + 1
    local texture = Frame(self)
    texture.layer, texture.sublevel = layer, sublevel
    return texture
  end
  function frame:CreateFontString(_, layer)
    local font = self:CreateTexture(nil, layer, nil, 0)
    function font:SetText(text) self.text = text end
    function font:SetTextColor(...) self.textColor = {...} end
    function font:SetFontHeight(height) self.fontHeight = height end
    return font
  end
  return frame
end
CreateFrame = function(_, _, parent) assert(not combat); return Frame(parent) end
local function Slot(owner)
  local slot = Frame(owner)
  slot.shown = false
  function slot:AddDispelTypeTexture(texture, options)
    assert(not combat, "provider registration is never changed in combat")
    self.texture, self.options = texture, options
    return 1
  end
  function slot:ClearDispelTypeTextures() self.texture = nil end
  return slot
end
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/Detection.lua"))("ZDecursive", ns)
assert(loadfile("ZDecursive/MUFPresentation.lua"))("ZDecursive", ns)
local runtime = assert(load(Read("ZDecursive/MUFs.lua") .. "\nreturn {update=UpdateMUFRange, paint=PaintManagedOverlays, bind=BindAuraSlot, healthy=PrimaryCureRangeState, status=PlaceStatusLight}"))("ZDecursive", ns)
local pack = ns.MakePack("DUNGEON")
ns.GetPrimaryCure = function() return "Actual cure", 101 end
ns.SpellRangeState = function() error("range must not use a generic healing probe") end
local owner = ns.CreateMUFVisualValidationFrame(nil)
owner.alpha, owner.assigned, owner.unit = 0.35, true, "party1"
owner:Show()
local shade = owner.rangeShadeHost
assert(shade and shade.parent == owner and shade.bounds == owner)
assert(shade.mouse == false and shade.click == false and shade.motion == false and shade.propagate == true, "top shade passes clicks and hover to existing MUF/native tooltip")
assert(shade.ignore and not shade.texture.ignore and not shade.statusShade.ignore, "one isolated host gate controls every shade texture")
assert(shade.texture.color[1] == 0 and shade.texture.color[4] == 1 and shade.alpha == 0)
assert(shade.level > owner.readabilityHost.level and shade.level > owner.deathHost.level, "whole shade is above skull, raid marker, player text and managed overlays")
assert(shade.texture.points[1][2] == owner and shade.texture.points[2][2] == owner, "shade includes full button and class border")
runtime.status(owner, 20, true, true)
assert(shade.statusShade.shown and shade.statusShade.bounds == owner.statusLight, "top shade follows status light bounds outside the MUF")
assert(shade.statusShade.asset == owner.statusLight.asset and shade.statusShade.vertex[1] == 0, "status shade matches the light mask without filling the empty gap")
assert(owner.statusLight.points[1][3] == "TOP" and owner.statusLight.points[1][5] > 0)
runtime.status(owner, 20, false, false)
assert(not shade.statusShade.shown and shade.texture.points[1][4] == -1 and shade.texture.points[1][5] == 1, "borderless shade covers the raid marker's one-pixel left/top overflow")
runtime.status(owner, 20, true, true)
assert(shade.texture.points[1][4] == 0 and shade.texture.points[1][5] == 0, "reenabling the border restores exact outer bounds")
local slots, hosts = {}, {}
local names = {"Magic", "Curse", "Poison", "Disease"}
for i, name in ipairs(names) do
  slots[i] = Slot(owner)
  assert(runtime.bind(slots[i], pack, owner.fillTex, {key = name, dispelType = name, priority = i}))
  local host = slots[i]._decursivePresentationHost
  hosts[i] = host
  assert(host.parent == slots[i] and host.texture.layer == "ARTWORK" and host.texture.ignore)
  assert(host.rangeShade == nil and owner._decursiveDispelHosts == nil, "per-slot shades and registry are gone, preventing stacked dim")
  assert(host.level == owner.level + 40 + 4 - i and host.level < shade.level)
  assert(not host.texture:IsEffectivelyShown(), "native empty slot still hides only its own fill")
  local count = 0
  for _ in pairs(slots[i].options.customDispelColorMap) do count = count + 1 end
  assert(count == 1 and slots[i].options.customDispelColorMap[name], "singleton native type palette is preserved")
  slots[i]:Show()
  assert(host.texture:IsEffectivelyShown() and host.texture:GetEffectiveAlpha() == 1, "afflicted fill remains opaque before the whole-MUF shade")
end
range = false
local reads = rangeCalls
runtime.paint(owner, pack, owner.unit)
assert(rangeCalls == reads + 1, "healthy color and whole-MUF shade share exactly one range query per paint")
assert(lastSpell == 101 and lastUnit == "party1", "range samples the exact primary cure and assigned unit")
assert(shade.alpha == 0.5 and shade.texture:GetEffectiveAlpha() == 0.5 and shade.statusShade:GetEffectiveAlpha() == 0.5, "one gate gives both shade pieces half opacity despite ancestor alpha 0.35")
for i, host in ipairs(hosts) do
  local color = slots[i].options.customDispelColorMap[names[i]]
  assert(color.r * (1 - shade.texture:GetEffectiveAlpha()) == color.r * 0.5, "every affliction becomes exactly fifty percent brightness")
  slots[i]:Hide()
end
runtime.paint(owner, pack, owner.unit)
assert(shade.texture:IsEffectivelyShown(), "unafflicted MUF receives the same shade independently of every native slot")
assert(owner.rangeOverlay.color[1] == pack.colors.range[1] and owner.rangeOverlay.color[4] == 1, "healthy RGB stays full and opaque below the shade")
assert(owner.rangeOverlay.color[1] * (1 - shade.alpha) == pack.colors.range[1] * 0.5, "healthy brightness is half, never quarter")
local calls = shade.calls
runtime.paint(owner, pack, owner.unit)
assert(shade.calls == calls, "unchanged public range and brightness skip repeated native writes")
pack.mufs.dimAmount = 0.75
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0.25 and shade.calls == calls + 1 and owner.rangeOverlay.color[1] == pack.colors.range[1], "changing brightness updates only the shade, not underlying RGB")
pack.mufs.dimAmount = nil
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0.5, "missing brightness defaults to fifty percent")
pack.mufs.dimAmount = 0.5
range = true
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0, "in-range restores full brightness")
range = nil
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0 and owner.rangeHost.alpha == 0, "unknown stays bright without a false out-of-range color")
range = false
pack.mufs.dimOutOfRange = false
reads = rangeCalls
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0 and rangeCalls == reads, "disabled whole-MUF dim clears shade without unnecessary range reads")
pack.mufs.dimOutOfRange, pack.mufs.dimAfflictedOutOfRange = true, false
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0.5, "obsolete afflicted-only setting cannot split whole-MUF behavior")
combat, range = true, secret
local created = allocations
calls = shade.calls
runtime.paint(owner, pack, owner.unit)
runtime.paint(owner, pack, owner.unit)
assert(shade.calls == calls + 2 and rawequal(shade.nativeValue, secret) and rawequal(owner.rangeHost.nativeValue, secret), "opaque range goes unchanged to native sinks without comparison")
assert(shade.rangeState == nil and shade.rangeBrightness == nil and allocations == created, "combat updates do not cache secrets, allocate, or mutate secure presentation")
range = false
runtime.paint(owner, pack, owner.unit)
assert(shade.nativeValue == false and shade.alpha == 0.5, "public state restores after an opaque sample")
shade.fail = true
assert(not ns.ApplyMUFRangeShade(owner, true, true, 0.5) and shade.rangeState == nil)
shade.fail = nil
assert(ns.ApplyMUFRangeShade(owner, false, true, 0.5) and shade.alpha == 0.5, "failed setter cannot poison the last-public cache")
local oldLevel = shade.level
assert(not ns.ConfigureMUFRangeShade(owner, true, true) and not ns.RaiseMUFRangeShade(owner, Frame(nil)) and shade.level == oldLevel, "geometry and levels never mutate during combat")
dead = true
runtime.paint(owner, pack, owner.unit)
assert(owner.skullTex.vertex.a == 1 and shade.alpha == 0.5, "public dead target keeps its skull below the requested range dim")
dead, connected = false, false
runtime.paint(owner, pack, owner.unit)
assert(owner.skullTex.vertex.a == 1 and shade.alpha == 0.5, "offline target keeps its skull while known false cure range dims everything")
connected = true
owner.assigned = false
runtime.paint(owner, pack, nil)
assert(shade.alpha == 0, "retiring a MUF clears the previous shade")
combat, range, owner.assigned, owner.unit = false, nil, true, "party2"
runtime.paint(owner, pack, owner.unit)
assert(lastUnit == "party2" and shade.alpha == 0, "pool reuse starts from the new unit's unknown range")
-- Exercise the actual native cooldown slot initializer with a high frame level
-- (manual cure catalogs may exceed the AUTO priority count).
local slot = Slot(owner)
slot.level = shade.level + 10
local gate = {owner = owner, holder = Frame(owner), container = Frame(owner), keys = {}, bindings = {}, innerSize = 16}
function gate.container:AddAuraSlot(_, _, options) options.initializeFrame(slot); return true end
C_DurationUtil = {CreateDurationTextBinding = function()
  return {SetFontString = function(self, font) self.font = font end, SetEnabled = function() end}
end}
assert(ns.ConfigureMUFCooldownGateSlotForValidation(gate, "cooldown-main", "HARMFUL", {Magic = true}, pack, {spellId = 101, types = {"magic"}}))
assert(shade.level > slot.level and gate.bindings[1].font.parent == slot, "top shade is above the real native countdown font's owned slot, including high priorities")
ns.ConfigureMUFRangeShade(owner, true, true)
assert(shade.level > slot.level, "layout style refresh never lowers shade beneath existing cooldowns")
range = false
runtime.paint(owner, pack, owner.unit)
assert(shade.alpha == 0.5 and shade.level > owner.readabilityHost.level)
for _, environment in ipairs(ns.ENVIRONMENTS) do
  local defaults = ns.MakePack(environment.key)
  assert(defaults.mufs.dimOutOfRange == true and defaults.mufs.dimAmount == 0.5, "all environments start at fifty-percent whole-MUF dimming")
end
assert(ns.GetMUFVisualMetrics(20, true, "partypet1") == 16, "staged original-style eighty-percent pet sizing is preserved")
io.write("afflicted-range-presentation-contract: ok (whole MUF range shade)\n")