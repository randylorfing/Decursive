--[[
    ZDecursive keyboard mouseover contract.
    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
    Licensed under the GNU General Public License version 3 or (at your option) any later version.
    Distributed without warranty. See ../LICENSE.
--]]

local function Check(value, message)
  if not value then error(message, 2) end
end

local file = assert(io.open("ZDecursive/KeyboardBindings.lua", "rb"))
local source = file:read("*a")
file:close()

local function Harness()
  local h = {frames = {}, overrides = {}, persistent = {}, combat = false,
    creates = 0, writes = 0, clears = 0, installs = 0, onDown = true, mods = {}}
  local ns = {}
  h.ns = ns
  InCombatLockdown = function() return h.combat end
  issecretvalue = function(value) return value == h.secret end
  canaccessvalue = function(value) return value ~= h.secret end
  h.secret = {}
  IsControlKeyDown = function() return h.mods.ctrl or false end
  IsShiftKeyDown = function() return h.mods.shift or false end
  IsAltKeyDown = function() return h.mods.alt or false end
  C_CVar = nil
  GetCVarBool = function(name)
    Check(name == "ActionButtonUseKeyDown", "only reads the standard press-mode CVar")
    return h.onDown
  end
  UIParent = {}
  CreateFrame = function(kind, name, parent, template)
    local frame = {name = name, attrs = {}, scripts = {}, events = {}, protected = template ~= nil}
    if template then Check(not h.combat, "no protected frame creation in combat") end
    h.creates = h.creates + 1
    h.frames[name or "events"] = frame
    local function Write()
      if frame.protected then Check(not h.combat, "no protected frame writes in combat") end
      h.writes = h.writes + 1
    end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, handler) Write(); self.scripts[event] = handler end
    function frame:SetAttribute(key, value) Write(); self.attrs[key] = value end
    function frame:RegisterForClicks(press) Write(); self.press = press end
    function frame:SetSize(width, height) Write(); self.width, self.height = width, height end
    function frame:SetPoint(...) Write() end
    function frame:EnableMouse(enabled) Write(); self.mouse = enabled end
    function frame:Show()
      Write()
      if h.failShow then h.failShow = false; error("show failed after frame creation") end
      self.shown = true
    end
    return frame
  end
  function h:Effective(key)
    local best
    for _, map in pairs(self.overrides) do
      local binding = map[key]
      if binding and (not best or binding.priority and not best.priority) then best = binding end
    end
    return best and best.action or self.persistent[key] or ""
  end
  GetBindingAction = function(key, includeOverrides)
    if h.failRead then error("binding read failed") end
    return includeOverrides and h:Effective(key) or h.persistent[key] or ""
  end
  SetOverrideBindingClick = function(owner, priority, key, button, mouse)
    Check(not h.combat, "no override mutation in combat")
    Check(priority == false, "global binding must not outrank hover bindings")
    h.installs = h.installs + 1
    local map = h.overrides[owner] or {}
    h.overrides[owner] = map
    map[key] = {priority = priority, action = "CLICK " .. button .. ":" .. mouse}
    if h.failInstall == h.installs then
      if h.returnFalse then return false end
      error("simulated failure after installing a key")
    end
    return true
  end
  ClearOverrideBindings = function(owner)
    Check(not h.combat, "no override cleanup in combat")
    h.clears = h.clears + 1
    if h.failClear then error("clear rejected") end
    h.overrides[owner] = nil
  end
  h.actions = {
    {name = "Purify", spellId = 527},
    {name = "Purify Disease", spellId = 213634},
    {name = "Dispel Magic", spellId = 528},
  }
  h.pack = {cure = {keyboardEnabled = true, keyboardKey = "F8"}}
  h.applied = h.pack
  ns.addon = {GetAppliedEnvironmentPack = function() return h.applied end}
  ns.GetKeyboardCureActions = function(pack)
    h.actionsPack = pack
    return pack.actions or h.actions
  end
  assert(load(source, "@ZDecursive/KeyboardBindings.lua"))("ZDecursive", ns)
  function h:Refresh(pack, actions)
    return self.ns.RefreshKeyboardBindings(pack or self.pack, actions or self.actions)
  end
  function h:Status() return self.ns.GetKeyboardBindingStatus() end
  function h:Event(event, name)
    local frame = self.frames.events
    Check(frame and frame.events[event], "wake-up event is registered")
    frame.scripts.OnEvent(frame, event, name)
  end
  function h:Observe(index, mods, down, mouseButton)
    self.mods = mods or {}
    local button = self.frames["ZDecursiveKeyboardCast" .. index]
    Check(button and button.scripts.PreClick, "secure button has an attempt observer")
    button.scripts.PreClick(button, mouseButton or "LeftButton", down)
  end
  -- Small secure dispatch model: WoW may fall back to an unmodified binding.
  -- Evaluate macro conditions on the hardware action, never in addon Lua.
  function h:Press(key, mods, unit, down)
    mods = mods or {}
    local prefix = (mods.alt and "ALT-" or "") .. (mods.ctrl and "CTRL-" or "") .. (mods.shift and "SHIFT-" or "")
    local action = self:Effective(prefix .. key)
    if action == "" then action = self:Effective(key) end
    local buttonName = action:match("^CLICK ([^:]+):LeftButton$")
    local button = buttonName and self.frames[buttonName]
    if not button then return nil end
    self.mods = mods
    local expectedDown = button.attrs.useOnKeyDown
    if down ~= expectedDown or button.press ~= (down and "AnyDown" or "AnyUp") then return nil end
    if button.scripts.PreClick then button.scripts.PreClick(button, "LeftButton", down) end
    local macro = button.attrs.macrotext
    local conditions = macro:match("%[(.-)%]")
    for condition in conditions:gmatch("[^,]+") do
      if condition == "@mouseover" and (not unit or unit.token ~= "mouseover") then return nil end
      if condition == "exists" and not (unit and unit.exists) then return nil end
      if condition == "help" and not (unit and unit.friendly) then return nil end
      if condition == "nodead" and unit and unit.dead then return nil end
      if condition == "nomod" and (mods.alt or mods.ctrl or mods.shift) then return nil end
      local required = condition:match("^mod:(.+)$")
      if required and not mods[required] then return nil end
      local forbidden = condition:match("^nomod:(.+)$")
      if forbidden and mods[forbidden] then return nil end
    end
    return macro:match("%] (.+)$")
  end
  return h
end

local cases = {}
local function Case(name, run) cases[#cases + 1] = {name = name, run = run} end
local FRIEND = {token = "mouseover", exists = true, friendly = true}

Case("passive module and strict keyboard normalization", function()
  local h = Harness()
  Check(h.creates == 0 and h.installs == 0, "loading the module creates no bindings or frames")
  for raw, expected in pairs({[" f8 "] = "F8", q = "Q", numpad1 = "NUMPAD1", [";"] = ";", tab = "TAB", ["   "] = "", [""] = ""}) do
    Check(h.ns.NormalizeKeyboardKey(raw) == expected, "normalizes supported base keys")
  end
  for _, value in ipairs({"CTRL-F8", "SHIFT", "ALT", "BUTTON1", "MOUSEWHEELUP", "F25", "F01", "F8\n/cast", "ESCAPE", 7, h.secret}) do
    local key, message = h.ns.NormalizeKeyboardKey(value)
    Check(key == nil and type(message) == "string", "rejects invalid or injection-shaped keyboard input")
  end
end)

Case("three actions and exact modifier guards", function()
  local h = Harness()
  Check(h:Refresh(), "enables configured bindings")
  Check(h:Status().state == "active" and #h:Status().activeBindings == 3, "reports the installed three actions")
  Check(h:Press("F8", {}, FRIEND, true) == "Purify", "base casts first action")
  Check(h:Press("F8", {ctrl = true}, FRIEND, true) == "Purify Disease", "Ctrl casts second action")
  Check(h:Press("F8", {shift = true}, FRIEND, true) == "Dispel Magic", "Shift casts third action")
  Check(h:Press("F8", {alt = true}, FRIEND, true) == nil, "Alt never falls back to a cure")
  Check(h:Press("F8", {ctrl = true, shift = true}, FRIEND, true) == nil, "combined modifiers do not choose the wrong spell")
  Check(h:Press("F8", {}, FRIEND, false) == nil, "does not cast twice on key release")
  for _, frame in pairs(h.frames) do
    if frame.protected then Check(frame.shown and frame.mouse == false, "secure click target exists without intercepting mouse input") end
  end
end)

Case("friendly living mouseover only", function()
  local h = Harness()
  h:Refresh()
  Check(h:Press("F8", {}, nil, true) == nil, "no implicit target or self fallback")
  Check(h:Press("F8", {}, {token = "target", exists = true, friendly = true}, true) == nil, "current target is not substituted")
  Check(h:Press("F8", {}, {token = "mouseover", exists = true, friendly = false}, true) == nil, "hostile mouseover cannot receive the action")
  Check(h:Press("F8", {}, {token = "mouseover", exists = true, friendly = true, dead = true}, true) == nil, "dead mouseover cannot receive the action")
end)

Case("missing modifiers never reuse the first cure", function()
  local h = Harness()
  h:Refresh(nil, {h.actions[1]})
  Check(h:Effective("CTRL-F8") == "" and h:Effective("SHIFT-F8") == "", "missing actions do not consume extra keybindings")
  Check(h:Press("F8", {ctrl = true}, FRIEND, true) == nil, "fallback base key is securely gated for missing Ctrl action")
  Check(h:Press("F8", {shift = true}, FRIEND, true) == nil, "fallback base key is securely gated for missing Shift action")
  Check(#h:Status().activeBindings == 1, "status does not invent unavailable actions")
end)

Case("conflicts reject the entire binding set", function()
  local h = Harness()
  h.persistent["CTRL-F8"] = "ACTIONBUTTON1"
  local ok = h:Refresh()
  local result = h:Status()
  Check(not ok and result.state == "conflict" and result.conflicts[1].key == "CTRL-F8", "reports the precise conflicting modifier key")
  Check(h.installs == 0 and h:Effective("F8") == "", "does not install a partial set around a conflict")
  Check(h:Effective("CTRL-F8") == "ACTIONBUTTON1", "preserves the existing binding")
end)

Case("explicit temporary override and disable restore existing binding", function()
  local h = Harness()
  h.persistent.F8 = "ACTIONBUTTON1"
  h.pack.cure.keyboardOverride = true
  h:Refresh()
  Check(h:Press("F8", {}, FRIEND, true) == "Purify", "explicit override activates")
  Check(h.persistent.F8 == "ACTIONBUTTON1", "does not rewrite the saved binding")
  h.pack.cure.keyboardEnabled = false
  h:Refresh()
  Check(h:Effective("F8") == "ACTIONBUTTON1" and #h:Status().activeBindings == 0, "disable restores the underlying binding")
  Check(h:Effective("CTRL-F8") == "" and h:Effective("SHIFT-F8") == "", "disable removes every owned modifier key")
  local clears = h.clears
  h:Refresh()
  Check(h.clears == clears, "repeated disable does not repeat protected cleanup")
end)

Case("key changes clean the old key set", function()
  local h = Harness()
  h:Refresh()
  h.pack.cure.keyboardKey = "F9"
  h:Refresh()
  Check(h:Effective("F8") == "" and h:Effective("CTRL-F8") == "", "old base and modifier keys released")
  Check(h:Press("F9", {}, FRIEND, true) == "Purify", "new key is active")
end)

Case("clearing the base key restores normal bindings", function()
  local h = Harness()
  h.persistent.F8 = "ACTIONBUTTON1"
  h.pack.cure.keyboardOverride = true
  h:Refresh()
  h.pack.cure.keyboardKey = assert(h.ns.NormalizeKeyboardKey("  "))
  h:Refresh()
  Check(h:Status().state == "unconfigured" and #h:Status().activeBindings == 0, "clearing key leaves enable preference but releases owned bindings")
  Check(h:Effective("F8") == "ACTIONBUTTON1" and h:Effective("CTRL-F8") == "", "clearing restores base binding and releases modifiers")
end)

Case("unchanged refresh is idempotent", function()
  local h = Harness()
  h:Refresh()
  local writes, installs, clears, creates = h.writes, h.installs, h.clears, h.creates
  for i = 1, 80 do h:Refresh() end
  Check(h.writes == writes and h.installs == installs and h.clears == clears and h.creates == creates, "per-MUF refresh performs no extra secure work")
end)

Case("combat keeps old actions and replays latest applied environment", function()
  local h = Harness()
  h:Refresh()
  local oldWrites, oldInstalls, oldClears = h.writes, h.installs, h.clears
  h.combat = true
  local requested = {cure = {keyboardEnabled = true, keyboardKey = "F9"}}
  Check(not h:Refresh(requested), "combat refresh is deferred")
  Check(h:Status().pending and h:Status().activeBindings[1].key == "F8", "status distinguishes pending request from previous active key")
  Check(h.writes == oldWrites and h.installs == oldInstalls and h.clears == oldClears, "combat makes no protected writes")
  h.ns.PACK = requested
  h.applied = {cure = {keyboardEnabled = true, keyboardKey = "F10"}, actions = {h.actions[2]}}
  h.combat = false
  h:Event("PLAYER_REGEN_ENABLED")
  Check(h:Effective("F8") == "" and h:Effective("F9") == "", "does not replay stale requested or editing packs")
  Check(h:Press("F10", {}, FRIEND, true) == "Purify Disease", "resolves the latest applied pack and its actions")
  Check(h.actionsPack == h.applied and not h:Status().pending, "applied pack is authoritative after combat")
end)

Case("first enable during combat and world-entry recovery", function()
  local h = Harness()
  h.combat = true
  h:Refresh()
  Check(h.creates == 1 and h.installs == 0, "only creates the nonsecure event listener in combat")
  h.combat = false
  h:Event("PLAYER_ENTERING_WORLD")
  Check(h:Status().state == "active", "world entry replays even without a regen event")
end)

Case("combat disable defers cleanup until safe", function()
  local h = Harness()
  h:Refresh()
  h.combat = true
  h.pack.cure.keyboardEnabled = false
  h:Refresh()
  Check(h:Status().pending and #h:Status().activeBindings == 3, "pending disable still reports active keys")
  h.combat = false
  h:Event("PLAYER_REGEN_ENABLED")
  Check(h:Status().state == "disabled" and h:Effective("F8") == "", "disable is replayed after combat")
end)

Case("binding updates detect hidden conflicts", function()
  local h = Harness()
  h:Refresh()
  h.persistent.F8 = "TOGGLEAUTORUN"
  h:Event("UPDATE_BINDINGS")
  Check(h:Status().state == "conflict" and h:Effective("F8") == "TOGGLEAUTORUN", "new persistent binding is not hidden behind our old override")
end)

Case("cleanup is scoped to our owner and yields to hover priority", function()
  local h = Harness()
  local other = {}
  h.overrides[other] = {F8 = {priority = true, action = "CLICK OtherAddon:LeftButton"}}
  h:Refresh()
  Check(h:Status().state == "conflict", "external temporary binding is detected without override consent")
  h.pack.cure.keyboardOverride = true
  h:Refresh()
  Check(h:Effective("F8") == "CLICK OtherAddon:LeftButton", "high-priority hover remains authoritative")
  h.pack.cure.keyboardEnabled = false
  h:Refresh()
  Check(h.overrides[other] and h:Effective("F8") == "CLICK OtherAddon:LeftButton", "cleanup never clears another owner")
end)

Case("partial install failures are cleared", function()
  for _, returnFalse in ipairs({false, true}) do
    local h = Harness()
    h.failInstall = 2
    h.returnFalse = returnFalse
    h:Refresh()
    Check(h:Status().state == "error" and #h:Status().activeBindings == 0, "failed partial install cannot claim active bindings")
    Check(h:Effective("F8") == "" and h:Effective("CTRL-F8") == "", "even a failed call that installed a key is cleaned up")
    h.failInstall = nil
    h:Refresh()
    Check(h:Status().state == "active", "next refresh can recover after an API failure")
  end
end)

Case("failed cleanup stays visible and retries", function()
  local h = Harness()
  h:Refresh()
  h.failClear = true
  h.pack.cure.keyboardEnabled = false
  h:Refresh()
  Check(h:Status().state == "error" and h:Status().cleanupPending and #h:Status().activeBindings == 3, "reports retained keys instead of claiming disable succeeded")
  h.failClear = false
  h:Event("PLAYER_REGEN_ENABLED")
  Check(h:Status().state == "disabled" and h:Effective("F8") == "", "retained ownership supports cleanup retry")
end)

Case("failed frame setup is completed on retry", function()
  local h = Harness()
  h.failShow = true
  h:Refresh()
  Check(h:Status().state == "error" and h:Effective("F8") == "", "incomplete frame setup installs no binding")
  h:Refresh()
  Check(h:Status().state == "active" and h.frames.ZDecursiveKeyboardCast1.shown, "retry finishes setup on the retained frame")
end)

Case("press mode follows CVar and waits through combat", function()
  local h = Harness()
  h:Refresh()
  h.onDown = false
  h:Event("CVAR_UPDATE", "ActionButtonUseKeyDown")
  Check(h:Press("F8", {}, FRIEND, false) == "Purify" and h:Press("F8", {}, FRIEND, true) == nil, "key-up setting updates both secure attribute and click registration")
  h.combat = true
  h.onDown = true
  h:Event("CVAR_UPDATE", "ActionButtonUseKeyDown")
  Check(h:Status().pending and h:Press("F8", {}, FRIEND, false) == "Purify", "current press mode remains intact during combat")
  h.combat = false
  h:Event("PLAYER_REGEN_ENABLED")
  Check(h:Press("F8", {}, FRIEND, true) == "Purify", "new press mode applies on combat exit")
end)

Case("invalid config and lost abilities release old bindings", function()
  local h = Harness()
  h:Refresh()
  h.pack.cure.keyboardKey = "CTRL-F8"
  h:Refresh()
  Check(h:Status().state == "invalid" and h:Effective("F8") == "", "invalid input cannot retain stale active bindings")
  h.pack.cure.keyboardKey = ""
  h:Refresh()
  Check(h:Status().state == "unconfigured", "empty configuration has a distinct status")
  h.pack.cure.keyboardKey = "F8"
  h:Refresh(nil, {})
  Check(h:Status().state == "unavailable" and #h:Status().activeBindings == 0, "no known cures means no captured keys")
  h:Refresh(nil, {{name = "Purify\n/cast Evil", spellId = 527}})
  Check(h:Status().state == "unavailable", "spell names cannot inject extra commands")
end)

Case("items, duplicate actions, and status snapshots", function()
  local h = Harness()
  h:Refresh(nil, {{name = "Cleansing item", itemId = 1234}, {name = "Cleansing item", itemId = 1234}})
  Check(h:Press("F8", {}, FRIEND, true) == "item:1234", "item cure uses a stable item ID")
  Check(h:Effective("CTRL-F8") == "", "duplicate actions do not capture another modifier")
  local result = h:Status()
  result.activeBindings[1].key = "Q"
  result.bindings[1].name = "Changed"
  Check(h:Status().activeBindings[1].key == "F8" and h:Status().bindings[1].name == "Cleansing item", "caller cannot mutate module state through status")
end)

Case("keyboard observer accepts exact modifiers and registered phase only", function()
  local h = Harness()
  h:Refresh()
  h:Observe(1, {}, true) -- An absent optional callback must be harmless.
  local attempts = {}
  h.ns.BeginKeyboardCureAttempt = function(binding) attempts[#attempts + 1] = binding end
  h.combat = true
  local writes, installs, clears = h.writes, h.installs, h.clears
  for index = 1, 3 do
    for _, mods in ipairs({{}, {ctrl = true}, {shift = true}, {alt = true}, {ctrl = true, shift = true}, {ctrl = true, alt = true}}) do
      for _, down in ipairs({false, true}) do h:Observe(index, mods, down) end
    end
  end
  Check(#attempts == 3 and attempts[1].index == 1 and attempts[2].index == 2 and attempts[3].index == 3,
    "only base-down, Ctrl-only-down, and Shift-only-down are observed")
  h:Observe(1, {}, true, "RightButton")
  h:Observe(1, {ctrl = h.secret}, true)
  Check(#attempts == 3, "rejects unexpected button and inaccessible modifier values")
  Check(h.writes == writes and h.installs == installs and h.clears == clears, "observer performs no protected writes in combat")
  h.combat = false
  h.onDown = false
  h:Refresh()
  h:Observe(1, {}, true)
  Check(#attempts == 3, "new key-up configuration rejects key-down observation")
  h:Observe(1, {}, false)
  Check(#attempts == 4, "new key-up phase is observed")
end)

Case("keyboard observer passes applied IDs and keeps callback data isolated", function()
  local h = Harness()
  local attempts = {}
  h.ns.BeginKeyboardCureAttempt = function(binding) attempts[#attempts + 1] = binding end
  h:Refresh(nil, {{name = "Purify", spellId = 527, baseId = 115450}})
  h:Observe(1, {}, true)
  Check(attempts[1].spellId == 527 and attempts[1].baseId == 115450 and attempts[1].itemId == nil
    and attempts[1].actionKey == "spell:527", "passes exact applied spell and base identity")
  attempts[1].spellId = 1
  h:Observe(1, {}, true)
  Check(attempts[2].spellId == 527, "callback cannot mutate the observer's stored metadata")
  h:Refresh(nil, {{name = "Purify", spellId = 115450, baseId = 527}})
  h:Observe(1, {}, true)
  Check(attempts[3].spellId == 115450 and attempts[3].baseId == 527 and attempts[3].actionKey == "spell:115450",
    "metadata updates when spell name remains the same but IDs change")
  h.combat = true
  h:Refresh(nil, {{name = "Purify", spellId = 213634}})
  h:Observe(1, {}, true)
  Check(attempts[4].spellId == 115450, "combat pending change retains metadata for the still-applied action")
  h.combat = false
  h:Refresh(nil, {{name = "Cure item", itemId = 1234, spellId = 5678, baseId = 5670}})
  h:Observe(1, {}, true)
  Check(attempts[5].itemId == 1234 and attempts[5].spellId == 5678 and attempts[5].baseId == 5670
    and attempts[5].actionKey == "spell:5678", "mixed item/spell action uses the same spell-first identity as MUFs")
  h:Refresh(nil, {{name = "Cure item", itemId = 1234}})
  h:Observe(1, {}, true)
  Check(attempts[6].actionKey == "item:1234", "item-only action preserves item identity")
  h.pack.cure.keyboardEnabled = false
  h:Refresh()
  h:Observe(1, {}, true)
  Check(#attempts == 6, "disabled bindings cannot report stale cure attempts")
end)

Case("optional observer failure cannot interrupt secure casting", function()
  local h = Harness()
  h:Refresh()
  h.ns.BeginKeyboardCureAttempt = function() error("observer failed") end
  Check(h:Press("F8", {}, FRIEND, true) == "Purify", "observer exception does not suppress the secure action")
  h.ns.BeginKeyboardCureAttempt = nil
  Check(h:Press("F8", {}, FRIEND, true) == "Purify", "casting remains functional without observer integration")
end)

Case("event-driven refresh updates options without per-MUF recursion", function()
  local h = Harness()
  local updates = 0
  h.ns.RefreshOptions = function()
    updates = updates + 1
    Check(updates < 4, "options refresh must not recursively invoke itself")
    h:Refresh() -- Options may rebuild MUF status; this must not refresh Options again.
  end
  h:Refresh()
  Check(updates == 0, "direct and per-MUF keyboard refresh do not redraw Options")
  h.persistent.F8 = "ACTIONBUTTON1"
  h:Event("UPDATE_BINDINGS")
  Check(updates == 1 and h:Status().state == "conflict", "binding event refreshes options after applying conflict status")
  h:Event("CVAR_UPDATE", "unrelatedCVar")
  Check(updates == 1, "unrelated CVar event does not refresh the page")
  h.combat = true
  h.onDown = false
  h:Event("CVAR_UPDATE", "ActionButtonUseKeyDown")
  Check(updates == 1, "combat does not refresh unavailable Options UI")
  h.combat = false
  h.persistent.F8 = nil
  h:Event("PLAYER_REGEN_ENABLED")
  Check(updates == 2 and h:Status().state == "active", "combat exit refreshes visible status after recovery")
end)

for _, case in ipairs(cases) do
  case.run()
  print("PASS " .. case.name)
end
print("keyboard binding contract: " .. #cases .. " cases passed")
