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

-- Public rendering caches, pass-scoped preparation, real DandersFrames callbacks,
-- and failed native setup retain their behavior while avoiding repeated work.
local function Read(path)
  local file = assert(io.open(path, "rb")); local text = file:read("*a"); file:close(); return text
end
local source = Read("ZDecursive/MUFs.lua")
local access = [[
return {
  set = ManagedSet, paint = PaintManagedOverlays, pass = function(...) return PaintManagedPass(...) end,
  queue = RequestCooldownReconcile, register = RegisterExtraEvents,
  setReconcile = function(fn) ReconcileCooldowns = fn end,
  ready = function() poolReady = true end, pool = pool,
  attach = AttachPaint, setAttachGates = function(fn) AttachCooldownGates = fn end,
  seedLayout = function(buttons, root, drag, h)
    poolReady, header, handle = true, root, drag
    for i = 1, 80 do pool[i] = buttons[i] end
    PaintSquare = function() h.paints = h.paints + 1 end
    PlaceStatusLight = function() end
    UpdateStatusLights = function() end
    AttachPaint = function() return h.nativeOK, h.nativeOK and "SUCCESS" or (h.nativeStatus or "FAILURE") end
  end,
}
]]
local function Region()
  local region = {calls = 0, attributes = {}, shown = true, width = 20}
  function region:SetAttribute(key, value)
    self.attributeCalls = (self.attributeCalls or 0) + 1
    self.attributes[key] = value
  end
  function region:SetAlpha(value) self.calls = self.calls + 1; self.alpha = value end
  function region:SetAlphaFromBoolean(value, yes, no)
    self.calls = self.calls + 1; self.nativeValue = value
    if canaccessvalue(value) then self.alpha = value and yes or no end
  end
  function region:SetVertexColorFromBoolean(value, yes, no)
    self.calls = self.calls + 1; self.nativeValue = value
    if canaccessvalue(value) then self.vertex = value and yes or no end
  end
  function region:SetColorTexture(...) self.calls = self.calls + 1; self.color = {...} end
  function region:SetTexture(value) self.calls = self.calls + 1; self.texture = value end
  function region:Show() self.calls = self.calls + 1; self.shown = true end
  function region:Hide() self.calls = self.calls + 1; self.shown = false end
  function region:IsShown() return self.shown end
  function region:GetWidth() return self.width end
  function region:SetSize(width) self.width = width end
  function region:SetScale() end
  function region:SetMovable() end
  function region:EnableMouse() end
  function region:ClearAllPoints() end
  function region:SetPoint() end
  return region
end
local function Harness()
  local h = {combat = false, timers = {}, rezCalls = 0, rangeCalls = 0, paints = 0, nativeOK = true, geometryCalls = 0}
  h.secret = setmetatable({}, {__tostring = function() error("secret serialization") end})
  InCombatLockdown = function() return h.combat end
  canaccessvalue = function(value) return not rawequal(value, h.secret) end
  issecretvalue = function(value) return rawequal(value, h.secret) end
  GetTime = function() return 100 end
  CreateColor = function(...) return {...} end
  UnitGUID, UnitIsConnected, UnitIsStealthed, GetRaidTargetIndex = nil, nil, nil, nil
  UnitIsDeadOrGhost = function() return false end
  UnitIsUnit = function(a, b) return a == b end
  UnitName = function(unit) return unit end
  UnitFullName = function(unit) return unit, "Realm" end
  GetRealmName = function() return "Realm" end
  GetNormalizedRealmName = GetRealmName
  IsInRaid = function() return false end
  IsActiveBattlefieldArena = function() return false end
  strtrim = function(s) return s:match("^%s*(.-)%s*$") end
  C_Item, C_Container = nil, nil
  C_Timer = {After = function(_, callback) h.timers[#h.timers + 1] = callback end}
  C_Spell = {IsSpellInRange = function(_, unit) h.rangeCalls = h.rangeCalls + 1; return unit == "party1" end}
  local ns = {}
  assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
  assert(loadfile("ZDecursive/ClickBindings.lua"))("ZDecursive", ns)
  h.pack = ns.MakePack("DUNGEON")
  ns.GetKnownCures = function() return {{spellId = 101, name = "Cure", types = {"magic"}}} end
  ns.GetSmartRezActions = function() h.rezCalls = h.rezCalls + 1; return nil, nil, true, true, 100, 99 end
  ns.addon = {db = {profile = {lists = {priority = {}, skip = {}}}},
    GetAppliedEnvironmentPack = function() return h.pack end,
    GetAppliedEnvironment = function() return "DUNGEON" end,
  }
  h.ns = ns
  h.runtime = assert(load(source .. "\n" .. access, "@ZDecursive/MUFs.lua"))("ZDecursive", ns)
  return h
end

do
  local h, texture, holder = Harness(), Region(), Region()
  local range = {enabled = true, inRange = false, color = {0.2, 0.4, 0.8, 1}, alpha = 0.7}
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  assert(texture.alpha == 1 and texture.color[4] == 1 and holder.alpha == 1)
  assert(texture.color[1] == 0.2, "range RGB stays full beneath the whole-MUF shade")
  local first = texture.calls + holder.calls
  assert(first == 5, "first range setup writes five presentation properties")
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  assert(texture.calls + holder.calls == first, "stable public range skips repeated setters")
  range.inRange = h.secret
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  assert(texture.calls + holder.calls == first + 2, "each secret sample passes directly to the native Boolean gate")
  assert(rawequal(holder.nativeValue, h.secret) and holder.zdManagedVisual.alpha == nil, "secret content is neither cached nor inspected")
  range.inRange = false
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  assert(holder.nativeValue == false and holder.alpha == 1, "public-to-secret-to-same-public restores public presentation")
  range.color[1] = 0.9
  h.ns.ApplyMUFRangePresentation(texture, range, holder)
  assert(texture.color[1] == 0.9, "mutated palette values invalidate only the actual setter values")
  local failing = Region()
  local succeed = failing.SetAlpha
  function failing:SetAlpha(value) error("setter rejected") end
  assert(not pcall(h.runtime.set, failing, "SetAlpha", 0.5))
  assert(not failing.zdManagedVisual, "failed setter never commits a cache entry")
  failing.SetAlpha = succeed
  assert(h.runtime.set(failing, "SetAlpha", 0.5) and failing.alpha == 0.5)
  function failing:SetAlpha(value) self.alpha = value; error("partial setter failure") end
  assert(not pcall(h.runtime.set, failing, "SetAlpha", 0.8))
  assert(failing.zdManagedVisual.alpha == nil, "throwing updates invalidate the previous successful stamp")
  failing.SetAlpha = succeed
  assert(h.runtime.set(failing, "SetAlpha", 0.5) and failing.alpha == 0.5, "old public value is restored after failed mutation")
end

do
  local h = Harness()
  for i = 1, 2 do
    h.runtime.pool[i] = {assigned = true, unit = "party" .. i, soulLinkFill = Region()}
  end
  h.runtime.ready()
  h.runtime.pass(h.pack)
  assert(h.rezCalls == 1 and h.rangeCalls == 2, "one capability sample serves both MUFs while range remains per-unit")
  h.runtime.pass(h.pack)
  assert(h.rezCalls == 2 and h.rangeCalls == 4, "next pass samples capabilities freshly")
  local calls = h.runtime.pool[1].soulLinkFill.calls
  h.runtime.pool[1].unit = "party3"
  h.runtime.pass(h.pack)
  assert(h.runtime.pool[1].soulLinkFill.calls > calls, "unit reassignment invalidates public visual stamps")
  assert(h.ns.GetPerformanceAssignedFrameCount() == 2)
end

do
  local h, events = Harness(), {}
  CreateFrame = function()
    return {RegisterEvent = function() end, SetScript = function(_, _, handler) events.handler = handler end}
  end
  h.runtime.register()
  local passes = 0
  h.runtime.setReconcile(function()
    passes = passes + 1
    if passes == 1 then
      events.handler(nil, "SPELL_UPDATE_CHARGES")
      events.handler(nil, "SPELL_UPDATE_COOLDOWN")
    end
  end)
  events.handler(nil, "SPELL_UPDATE_COOLDOWN")
  events.handler(nil, "SPELL_UPDATE_CHARGES")
  assert(passes == 0 and #h.timers == 1, "paired broadcast events coalesce until the next frame")
  table.remove(h.timers, 1)()
  assert(passes == 1 and #h.timers == 1, "reentrant event queues exactly one further pass")
  table.remove(h.timers, 1)()
  assert(passes == 2 and #h.timers == 0)
end

do
  local h = Harness()
  h.ns.DetectionEngine = {BindCarrier = function() return {}, true, "SUCCESS" end}
  h.runtime.setAttachGates(function() return false end)
  local ok, status = h.runtime.attach({inner = {}, fillTex = {}}, h.pack, "party1")
  assert(ok == false and status == "FAILURE", "cooldown provider setup failure propagates to the engine consumer")
end

for _, mode in ipairs({"native", "missing", "throws", "rejects"}) do
  local h, filtered, global = Harness(), {}, {}
  CreateFrame = function()
    local frame = {SetScript = function() end, RegisterEvent = function(_, event) global[event] = true end}
    if mode ~= "missing" then
      function frame:RegisterUnitEvent(event, ...)
        if mode == "throws" then error("unit events unavailable") end
        if mode == "rejects" then return false end
        filtered[event] = table.concat({...}, ",")
      end
    end
    return frame
  end
  h.runtime.register()
  for _, event in ipairs({"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED"}) do
    if mode == "native" then
      assert(filtered[event] == "player,pet" and not global[event], "native actor filter receives exactly the owned actors")
    else
      assert(global[event], "failed or missing actor-filter API falls back without dropping cure events")
    end
  end
end

do
  local h = Harness()
  h.units = {"player", "party1", "party2"}
  local positions = {player = 300, party1 = 100, party2 = 200}
  local callback
  DandersFrames = {RegisterCallback = function(_, _, fn) callback = fn end}
  DandersFrames_IsReady = function() return true end
  DandersFrames_GetPartyHeader, DandersFrames_GetArenaHeader = nil, nil
  DandersFrames_GetPartyConfig = function() return {growDirection = "HORIZONTAL"} end
  DandersFrames_GetFrameForUnit = function(unit)
    return {GetLeft = function() h.geometryCalls = h.geometryCalls + 1; return positions[unit] end,
      GetTop = function() return 100 end, GetWidth = function() return 80 end, GetHeight = function() return 30 end}
  end
  assert(loadfile("ZDecursive/Lists.lua"))("ZDecursive", h.ns)
  h.ns.BuildRoster = function(pack) return h.ns.ApplyUnitLists(h.units, pack) end
  h.ns.DetectionEngine = {state = "READY"}
  local buttons = {}
  for i = 1, 80 do buttons[i] = Region() end
  local function AttributeCalls()
    local calls = 0
    for i = 1, #buttons do calls = calls + (buttons[i].attributeCalls or 0) end
    return calls
  end
  h.runtime.seedLayout(buttons, Region(), Region(), h)
  local modelCalls, realModel = 0, h.ns.RebuildClickModel
  h.ns.RebuildClickModel = function(...) modelCalls = modelCalls + 1; return realModel(...) end
  assert(h.ns.RefreshMUFs())
  assert(modelCalls == 1 and h.paints == 3, "one click model preparation serves a complete layout")
  local retired, originalSet = buttons[1], buttons[1].SetAttribute
  positions.party1, positions.party2 = 200, 100
  function retired:SetAttribute(key, value)
    if key == "*unit3" and value == "party2" then error("native attribute rejection") end
    return originalSet(self, key, value)
  end
  h.nativeOK, h.nativeStatus = false, "DEFERRED_RESTRICTED"
  local applied, status = h.ns.RefreshMUFs()
  assert(applied == false and status == "FAILURE", "later native deferrals cannot downgrade a partly installed binding failure")
  assert(not retired.shown and not retired.assigned and retired.unit == nil, "failed secure owner is hidden before presenting a new unit")
  assert(retired.attributes["*unit3"] == "party1", "fixture leaves an actual stale secure action to prove quarantine is needed")
  assert(buttons[2].shown and buttons[3].shown, "healthy independent MUFs remain shown")
  retired.SetAttribute = originalSet
  h.nativeOK, h.nativeStatus = true, nil
  assert(h.ns.RefreshMUFs(), "successful full retry restores the owner")
  assert(retired.shown and retired.assigned and retired.unit == "party2" and retired.attributes["*unit3"] == "party2", "retry restores matching visual/secure unit and visibility")
  positions.party1, positions.party2 = 100, 200
  assert(h.ns.RefreshMUFs())
  local reads, paints, writes = h.geometryCalls, h.paints, AttributeCalls()
  callback("OnFramesSorted", "party")
  assert(h.geometryCalls > reads and h.paints == paints, "identical callback reads fresh geometry but skips the successful plan")
  assert(AttributeCalls() == writes, "identical callback performs zero secure attribute writes")
  positions.player, positions.party1 = 100, 300
  callback("OnFramesSorted", "party")
  assert(h.paints == paints + 3 and buttons[1].unit == "player", "changed provider order is applied")
  h.pack.mufs.size = (h.pack.mufs.size or 20) + 1
  paints, writes = h.paints, AttributeCalls()
  callback("OnFramesSorted", "party")
  assert(h.paints == paints + 3, "changed style cannot be hidden by identical order")
  assert(AttributeCalls() == writes, "a cosmetic relayout also performs zero writes to unchanged secure bindings")
  h.nativeOK = false
  h.pack.mufs.scale = 1.1
  assert(h.ns.RefreshMUFs() == false)
  h.nativeOK = true
  paints = h.paints
  callback("OnFramesSorted", "party")
  assert(h.paints == paints + 3, "a failed application is not reusable")
  h.ns.DetectionEngine.state = "RECOVERING"
  paints = h.paints
  callback("OnFramesSorted", "party")
  assert(h.paints == paints + 3, "required recovery bypasses plan reuse")
  h.ns.DetectionEngine.state = "READY"
  h.combat = true
  paints, reads = h.paints, h.geometryCalls
  callback("OnFramesSorted", "party")
  assert(h.paints == paints and h.geometryCalls == reads, "combat callback neither reads geometry nor mutates layout")
end

io.write("muf-performance-contract: ok\n")
