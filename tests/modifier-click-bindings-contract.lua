-- Based on Decursive, Copyright (C) 2006-2026 John Wellesz.
-- ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing.
-- Licensed under the GNU General Public License version 3 or later; see ../LICENSE.
-- Exercise real configuration and secure-click installation with public API stubs.
local function Check(value, message)
  if not value then error(message, 2) end
end
local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local mufsSource = Read("ZDecursive/MUFs.lua")
local access = [[
return {install = ApplyClickAttributes, clear = ClearClickAttributes, clicked = CureRowForClick}
]]

local function Harness()
  local h = {combat = false, control = false, shift = false, alt = false, writes = 0}
  InCombatLockdown = function() return h.combat end
  IsControlKeyDown = function() return h.control end
  IsShiftKeyDown = function() return h.shift end
  IsAltKeyDown = function() return h.alt end
  issecretvalue = function() return false end
  canaccessvalue = function() return true end
  GetTime = function() return 100 end
  C_Item, C_Container, C_Timer = nil, nil, nil
  h.ns = {}
  assert(load(Read("ZDecursive/Defaults.lua"), "@ZDecursive/Defaults.lua"))("ZDecursive", h.ns)
  assert(load(Read("ZDecursive/ClickBindings.lua"), "@ZDecursive/ClickBindings.lua"))("ZDecursive", h.ns)
  h.pack = h.ns.MakePack("DUNGEON")
  h.editing = h.ns.MakePack("RAID")
  h.actions = {
    {spellId = 101, name = "First Cure", types = {"magic", "disease"}},
    {spellId = 102, name = "Second Cure", types = {"curse"}},
    {spellId = 103, name = "Third Cure", types = {"poison"}},
  }
  h.ns.GetKnownCures = function() return h.actions end
  h.ns.GetSmartRezActions = function()
    if h.rez then return "Battle Rez", "Resurrection", false, false end
  end
  h.ns.addon = {
    GetAppliedEnvironmentPack = function() return h.pack end,
    GetEditingPack = function() return h.editing end,
    GetAppliedEnvironment = function() return "DUNGEON" end,
  }
  h.runtime = assert(load(mufsSource .. "\n" .. access, "@ZDecursive/MUFs.lua"))("ZDecursive", h.ns)
  h.button = {attributes = {}}
  function h.button:SetAttribute(key, value)
    Check(not h.combat, "protected attributes must never change in combat")
    h.writes = h.writes + 1
    self.attributes[key] = value
  end
  function h:Install()
    return self.runtime.install(self.button, self.pack, "party2")
  end
  function h:Set(key, value)
    Check(self.ns.SetClickBindingOverride(self.pack, key, value), "accept binding " .. key .. " = " .. value)
  end
  function h:Macro(attribute, name)
    local text = self.button.attributes[attribute]
    Check(type(text) == "string" and text:find(name, 1, true), attribute .. " must contain " .. name)
  end
  return h
end

local cases = {}
local function Case(name, callback) cases[#cases + 1] = {name, callback} end

Case("old AUTO defaults keep their gestures", function()
  local h = Harness()
  h.pack.cure.clickBindings = nil -- A profile saved before this feature.
  Check(h:Install(), "legacy profile installs")
  h:Macro("*macrotext1", "First Cure")
  h:Macro("*macrotext2", "Second Cure")
  h:Macro("ctrl-macrotext1", "Third Cure")
  Equal(h.button.attributes["*type3"], "target", "middle target remains")
  Equal(h.button.attributes["ctrl-type3"], "focus", "control middle focus remains")
  Equal(h.button.attributes["*unit3"], "party2", "target uses this MUF unit")
  Equal(h.button.attributes["ctrl-unit3"], "party2", "focus uses this MUF unit")
  Equal(h.pack.cure.clickBindings, nil, "loading old mappings need not mutate storage")
end)

Case("all forty gestures install canonical attributes", function()
  local h = Harness()
  local modifiers = {
    {"NONE", "", "*"}, {"CTRL", "ctrl-", "ctrl-"}, {"SHIFT", "shift-", "shift-"},
    {"ALT", "alt-", "alt-"}, {"CTRLSHIFT", "ctrl-shift-", "ctrl-shift-"},
    {"ALTCTRL", "alt-ctrl-", "alt-ctrl-"}, {"ALTSHIFT", "alt-shift-", "alt-shift-"},
    {"ALTCTRLSHIFT", "alt-ctrl-shift-", "alt-ctrl-shift-"},
  }
  local buttons = {"left", "right", "middle", "button4", "button5"}
  local seen = {}
  for _, modifier in ipairs(modifiers) do
    for index, button in ipairs(buttons) do
      local key = h.ns.ClickBindingKey(modifier[1], button)
      Equal(key, modifier[2] .. button, "canonical setting key")
      Check(not seen[key], "each combination is independent")
      seen[key] = true
      local prefix = modifier[3]
      h:Set(key, "CURE2")
      Check(h:Install(), "install cure override")
      Equal(h.button.attributes[prefix .. "type" .. index], "macro", key .. " cure type")
      h:Macro(prefix .. "macrotext" .. index, "Second Cure")
      for _, action in ipairs({"TARGET", "FOCUS", "ASSIST", "NONE"}) do
        h:Set(key, action)
        Check(h:Install(), "install utility override")
        Equal(h.button.attributes[prefix .. "type" .. index], action == "NONE" and "" or action:lower(), key .. " action")
        Equal(h.button.attributes[prefix .. "macrotext" .. index], nil, key .. " removes stale cure")
        Equal(h.button.cureRows[prefix .. "%s" .. index], false, key .. " blocks cure attribution")
      end
      h:Set(key, "DEFAULT")
    end
  end
  Equal(#h.ns.ClickBindingGestures, 40, "all supported button and modifier combinations are exposed")
end)

Case("middle and control middle can be reassigned independently", function()
  local h = Harness()
  h:Set("middle", "spell:101")
  h:Set("ctrl-middle", "ASSIST")
  Check(h:Install(), "install remapped middle clicks")
  h:Macro("*macrotext3", "First Cure")
  Equal(h.button.attributes["ctrl-type3"], "assist", "control middle assists")
  h:Set("middle", "DEFAULT")
  Check(h:Install(), "reset middle only")
  Equal(h.button.attributes["*type3"], "target", "reset restores target")
  Equal(h.button.attributes["ctrl-type3"], "assist", "reset retains independent control middle")
end)

Case("ordinary assignment preserves every other configured gesture", function()
  local h = Harness()
  h:Set("left", "CURE2")
  h:Set("alt-ctrl-shift-button5", "CURE1")
  h:Set("ctrl-middle", "ASSIST")
  Check(h:Install(), "install initial gestures")
  local combined = h.button.attributes["alt-ctrl-shift-macrotext5"]
  h:Set("left", "FOCUS")
  Check(h:Install(), "change only left")
  Equal(h.button.attributes["*type1"], "focus", "left changes")
  Equal(h.button.attributes["alt-ctrl-shift-macrotext5"], combined, "combined cure is preserved")
  Equal(h.button.attributes["ctrl-type3"], "assist", "control middle is preserved")
  h:Macro("*macrotext2", "Second Cure")
end)

Case("overrides take precedence over a legacy custom macro", function()
  local h = Harness()
  h.pack.advanced.allowMacroEdit = true
  h.pack.advanced.customMacro = "/say Legacy macro"
  Check(h:Install(), "install legacy custom macro")
  h:Macro("*macrotext1", "Legacy macro")
  h:Set("left", "CURE2")
  Check(h:Install(), "explicit cure replaces custom macro")
  h:Macro("*macrotext1", "Second Cure")
  h:Set("left", "TARGET")
  Check(h:Install(), "utility replaces macro")
  Equal(h.button.attributes["*type1"], "target", "target wins")
  Equal(h.button.attributes["*macrotext1"], nil, "custom macro is not left installed")
  h:Set("left", "DEFAULT")
  Check(h:Install(), "reset restores legacy custom macro")
  h:Macro("*macrotext1", "Legacy macro")
end)

Case("unavailable assigned cures clear stale macros and block fallback", function()
  local h = Harness()
  h:Set("alt-left", "spell:102")
  Check(h:Install(), "install known spell")
  h:Macro("alt-macrotext1", "Second Cure")
  table.remove(h.actions, 2)
  Check(h:Install(), "rebuild after spell loss")
  Equal(h.button.attributes["alt-type1"], "", "unavailable spell explicitly blocks secure wildcard")
  Equal(h.button.attributes["alt-macrotext1"], nil, "obsolete macro removed")
  h.alt = true
  Equal(h.runtime.clicked(h.button, "LeftButton"), nil, "unavailable spell does not attribute wildcard cooldown")
  h:Set("left", "CURE3")
  h.rez = true
  Check(h:Install(), "install absent third cure with resurrection available")
  Equal(h.button.attributes["*type1"], "", "missing third cure remains empty")
  Equal(h.button.attributes["*macrotext1"], nil, "missing third cure must not become resurrection fallback")
end)

Case("known item cures work but unrelated spells are unavailable", function()
  local h = Harness()
  h.actions = {{itemId = 201, name = "Cure Potion", types = {"poison"}}, {spellId = 202, name = "Enemy Enrage", types = {"enrage"}}}
  h:Set("alt-button4", "item:201")
  h:Set("alt-button5", "spell:202")
  Check(h:Install(), "install explicit item")
  h:Macro("alt-macrotext4", "/use")
  h:Macro("alt-macrotext4", "Cure Potion")
  Equal(h.button.attributes["alt-type5"], "", "nonfriendly action cannot become a cure")
end)

Case("manual saved assignments survive temporary overrides", function()
  local h = Harness()
  h.pack.cure.mode = "MANUAL"
  h.pack.cure.manual = {["spell:102"] = "button4", ["spell:103"] = "button5"}
  h.pack.mouse.button4, h.pack.mouse.button5 = "CURE", "CURE"
  h.pack.cure.clickBindings = nil
  Check(h:Install(), "install legacy manual map")
  h:Macro("*macrotext4", "Second Cure")
  h:Macro("*macrotext5", "Third Cure")
  h:Set("button4", "FOCUS")
  Check(h:Install(), "overlay manual mapping")
  Equal(h.button.attributes["*type4"], "focus", "new override wins")
  Equal(h.pack.cure.manual["spell:102"], "button4", "old manual storage is retained")
  h:Set("button4", "DEFAULT")
  Check(h:Install(), "remove manual overlay")
  h:Macro("*macrotext4", "Second Cure")
  h:Macro("*macrotext5", "Third Cure")
  Equal(h.pack.cure.clickBindings.button4, nil, "DEFAULT removes override key")
end)

Case("clearing removes stale action fields across all modifier prefixes", function()
  local h = Harness()
  local prefixes = {"", "*", "ctrl-", "shift-", "alt-", "ctrl-shift-", "alt-ctrl-", "alt-shift-", "alt-ctrl-shift-"}
  local fields = {"type", "spell", "macro", "macrotext", "unit"}
  for _, prefix in ipairs(prefixes) do
    for index = 1, 5 do
      for _, field in ipairs(fields) do h.button.attributes[prefix .. field .. index] = "stale" end
    end
  end
  h.runtime.clear(h.button)
  Equal(next(h.button.attributes), nil, "every stale protected action attribute is removed")
end)

Case("cooldown attribution matches exact combinations before wildcard", function()
  local h = Harness()
  h:Set("ctrl-left", "CURE2")
  h:Set("shift-left", "CURE3")
  h:Set("alt-ctrl-shift-left", "CURE1")
  h:Set("ctrl-shift-left", "NONE")
  h:Set("alt-right", "ASSIST")
  Check(h:Install(), "install modifier attribution model")
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 101, "unmodified uses wildcard")
  h.control = true
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 102, "control uses its exact cure")
  h.control, h.shift = false, true
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 103, "shift uses its exact cure")
  h.control = true
  Equal(h.runtime.clicked(h.button, "LeftButton"), nil, "explicit combination NONE blocks all fallback")
  h.alt = true
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 101, "three modifiers resolve alt-control-shift order")
  h.control, h.shift = false, false
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 101, "unspecified Alt uses wildcard")
  Equal(h.runtime.clicked(h.button, "RightButton"), nil, "utility blocks wildcard cooldown attribution")
  h.control = true
  Equal(h.runtime.clicked(h.button, "LeftButton").spellId, 101, "unspecified Alt-Control uses wildcard, not Control-only")
  Equal(h.runtime.clicked(h.button, "UnknownButton"), nil, "unknown button is harmless")
end)

Case("invalid input cannot change saved bindings", function()
  local h = Harness()
  h:Set("left", "TARGET")
  for _, pair in ipairs({{"meta-left", "FOCUS"}, {"left", "/cast injected"}, {"left", "spell:1;2"}, {"left", "CURE4"}}) do
    Equal(h.ns.SetClickBindingOverride(h.pack, pair[1], pair[2]), false, "invalid binding rejected")
  end
  Equal(h.pack.cure.clickBindings.left, "TARGET", "valid saved selection survives invalid inputs")
  Equal(h.ns.ClickBindingKey("META", "left"), nil, "unknown modifier rejected")
  Equal(h.ns.ClickBindingKey("NONE", "button6"), nil, "unsupported button rejected")
end)

Case("environment copy keeps overrides independent", function()
  local h = Harness()
  local addon = {}
  LibStub = function(name)
    if name == "AceAddon-3.0" then return {NewAddon = function() return addon end} end
    if name == "AceDB-3.0" then return {} end
    error("unexpected library " .. tostring(name))
  end
  assert(load(Read("ZDecursive/Core.lua"), "@ZDecursive/Core.lua"))("ZDecursive", h.ns)
  addon.db = {profile = {environments = {DUNGEON = h.pack, RAID = h.editing}}}
  function addon:ProfileMutationReady() return true end
  function addon:GetEnvironmentMode() return "multiple" end
  function addon:GetEditingEnvironment() return "DUNGEON" end
  function addon:GetEditingPack() return self.db.profile.environments.DUNGEON end
  function addon:RunProfileStorageTransaction(_, callback) return callback() end
  function addon:EnsureEnvironments() return true end
  function addon:MirrorMUFOrientation() end
  h:Set("ctrl-left", "CURE2")
  Check(addon:CopyEditingPackTo("RAID"), "real environment copy succeeds")
  local copied = addon.db.profile.environments.RAID
  Equal(copied.cure.clickBindings["ctrl-left"], "CURE2", "copy includes override")
  Check(copied.cure.clickBindings ~= h.pack.cure.clickBindings, "copy must own separate override table")
  Check(h.ns.SetClickBindingOverride(copied, "ctrl-left", "TARGET"), "copied binding can change")
  Equal(h.pack.cure.clickBindings["ctrl-left"], "CURE2", "copy edit cannot alter source")
  local fresh = h.ns.MakePack("RAID")
  Equal(next(fresh.cure.clickBindings), nil, "default packs do not inherit edited overrides")
end)

Case("combat defers secure updates and recovery uses applied environment", function()
  local h = Harness()
  h:Set("alt-left", "CURE2")
  Check(h:Install(), "install initial applied pack")
  local originalMacro = h.button.attributes["alt-macrotext1"]
  local originalModel = h.ns.RebuildClickModel()
  local writes = h.writes
  assert(load(Read("ZDecursive/DetectionEngine.lua"), "@ZDecursive/DetectionEngine.lua"))("ZDecursive", h.ns)
  local engine = h.ns.DetectionEngine
  engine:RegisterConsumer("MUFs", function()
    local ok = h.runtime.install(h.button, h.ns.addon:GetAppliedEnvironmentPack(), "party2")
    return ok, ok and "SUCCESS" or "DEFERRED_COMBAT", 0
  end)
  for _, name in ipairs({"Alerts", "LiveList"}) do engine:RegisterConsumer(name, function() return true, "SUCCESS", 0 end) end
  h.combat = true
  engine:OnEvent("PLAYER_REGEN_DISABLED")
  local ok, reason = h.ns.SetClickBindingOverride(h.pack, "alt-left", "TARGET")
  Equal(ok, false, "combat settings write is rejected")
  Equal(reason, "combat", "combat refusal is explicit")
  Equal(h.pack.cure.clickBindings["alt-left"], "CURE2", "combat does not mutate saved selection")
  h.actions = {h.actions[1], h.actions[3]} -- Learned actions can change during combat.
  h.editing.cure.clickBindings["alt-left"] = "FOCUS"
  h.ns.InvalidateClickModel("SPELLS_CHANGED")
  Equal(h.ns.RebuildClickModel(h.editing), originalModel, "combat retains installed click snapshot")
  Equal(h:Install(), false, "combat rejects protected reinstall")
  h.runtime.clear(h.button)
  Equal(h.writes, writes, "combat never writes protected attributes")
  Equal(h.button.attributes["alt-macrotext1"], originalMacro, "combat keeps old secure macro")
  h.combat = false
  engine:OnEvent("PLAYER_REGEN_ENABLED")
  Check(h.writes > writes, "recovery reinstalls secure bindings")
  h:Macro("alt-macrotext1", "Third Cure")
  Equal(h.button.attributes["alt-type1"], "macro", "recovery applies Dungeon, not editing Raid focus")
  Equal(engine.pending, false, "recovery completes pending transaction")
end)

local failures = 0
for _, case in ipairs(cases) do
  local ok, err = pcall(case[2])
  if ok then io.write("PASS: " .. case[1] .. "\n")
  else failures = failures + 1; io.write("FAIL: " .. case[1] .. "\n" .. tostring(err) .. "\n") end
end
Check(failures == 0, tostring(failures) .. " modifier click contract cases failed")
io.write("PASS: " .. tostring(#cases) .. " modifier click binding contract cases\n")
