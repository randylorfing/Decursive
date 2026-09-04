--[[
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.
    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
    Licensed under the GNU General Public License version 3 or (at your option) any later version.
    Distributed without warranty. See ../LICENSE.
--]]

local ADDON_NAME, ns = ...

local owner, eventFrame
local buttons = {}
local observedBindings = {}
local active = {}
local ownsOverrides = false
local signature
local refreshing = false
local lastPack, lastActions
local status = {state = "disabled", message = "Keyboard mouseover casting is off.", pending = false}
local PREFIXES = {"", "CTRL-", "SHIFT-"}
local MODIFIERS = {"nomod", "mod:ctrl,nomod:alt,nomod:shift", "mod:shift,nomod:alt,nomod:ctrl"}
local NAMED_KEYS = {
  SPACE = true, TAB = true, ENTER = true, BACKSPACE = true,
  DELETE = true, INSERT = true, HOME = true, END = true, PAGEUP = true, PAGEDOWN = true,
  UP = true, DOWN = true, LEFT = true, RIGHT = true,
  NUMPADDECIMAL = true, NUMPADDIVIDE = true, NUMPADMULTIPLY = true,
  NUMPADMINUS = true, NUMPADPLUS = true, NUMPADENTER = true,
}

local function Accessible(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then return false end
  return type(canaccessvalue) ~= "function" or canaccessvalue(value)
end

function ns.NormalizeKeyboardKey(raw)
  if not Accessible(raw) or type(raw) ~= "string" or #raw > 32 then
    return nil, "Enter one keyboard key, such as F8 or NUMPAD1."
  end
  local key = raw:match("^%s*(.-)%s*$"):upper()
  if key == "" then return "" end
  local functionKey = key:match("^F([1-9]%d?)$")
  if key:match("^[A-Z0-9]$") or key:match("^NUMPAD[0-9]$") or NAMED_KEYS[key]
    or (functionKey and tonumber(functionKey) <= 24)
    or (#key == 1 and ("`-=[]\\;',./"):find(key, 1, true)) then
    return key
  end
  return nil, "Use a base keyboard key without Ctrl, Shift, Alt, mouse buttons, or mouse wheel."
end

local function CopyBindings(bindings)
  local copy = {}
  for i, binding in ipairs(bindings) do
    copy[i] = {key = binding.key, name = binding.name, spellId = binding.spellId, itemId = binding.itemId}
  end
  return copy
end

function ns.GetKeyboardBindingStatus()
  local result = {}
  for key, value in pairs(status) do
    if type(value) ~= "table" then result[key] = value end
  end
  result.bindings = CopyBindings(status.bindings or {})
  result.activeBindings = CopyBindings(active)
  result.cleanupPending = status.state == "error" and ownsOverrides
  result.conflicts = {}
  for i, conflict in ipairs(status.conflicts or {}) do
    result.conflicts[i] = {key = conflict.key, action = conflict.action}
  end
  return result
end

local function SetStatus(state, message, desired, conflicts)
  status = {
    state = state, message = message, pending = state == "pending",
    configuredKey = desired and desired.key or "",
    enabled = desired and desired.enabled or false,
    pressMode = desired and (desired.onDown and "down" or "up") or nil,
    bindings = desired and desired.bindings or {}, conflicts = conflicts or {},
  }
end

local function PressOnDown()
  local reader = C_CVar and C_CVar.GetCVarBool or GetCVarBool
  if type(reader) ~= "function" then return true end
  local ok, value = pcall(reader, "ActionButtonUseKeyDown")
  if not ok or not Accessible(value) then return true end
  return value == true or value == 1
end

local function PositiveID(value)
  return Accessible(value) and type(value) == "number" and value > 0 and value < 2147483648 and value == math.floor(value)
end

local function BuildDesired(pack, actions)
  local cure = type(pack) == "table" and type(pack.cure) == "table" and pack.cure or {}
  local desired = {enabled = cure.keyboardEnabled == true, override = cure.keyboardOverride == true,
    bindings = {}, onDown = PressOnDown()}
  if not desired.enabled then return desired, "disabled", "Keyboard mouseover casting is off." end
  local key, keyError = ns.NormalizeKeyboardKey(cure.keyboardKey)
  desired.key = key
  if not key or key == "" then
    local unconfigured = cure.keyboardKey == nil or key == ""
    return desired, unconfigured and "unconfigured" or "invalid",
      unconfigured and "Choose a keyboard key to enable mouseover casting." or keyError
  end
  local seen = {}
  for index = 1, 3 do
    local action = type(actions) == "table" and actions[index]
    if type(action) == "table" then
      local item = PositiveID(action.itemId) and action.itemId or nil
      local spell = PositiveID(action.spellId) and action.spellId or nil
      local base = PositiveID(action.baseId) and action.baseId or nil
      local name = Accessible(action.name) and type(action.name) == "string" and action.name or nil
      -- These names come from the known friendly-cure catalog. Never turn custom
      -- profile data into additional macro commands or conditional clauses.
      if name and #name > 0 and #name <= 160 and not name:find("[%c%[%];|/\\]") and (item or spell) then
        local identity = (spell and "spell:" .. spell) or "item:" .. item
        if not seen[identity] then
          seen[identity] = true
          local macro = (item and "/use " or "/cast ") .. "[@mouseover,help,exists,nodead," .. MODIFIERS[index] .. "] "
            .. (item and "item:" .. item or name)
          if #macro <= 255 then
            desired.bindings[#desired.bindings + 1] = {
              index = index, key = PREFIXES[index] .. key, name = name, spellId = spell, itemId = item,
              baseId = base, actionKey = identity, macro = macro, buttonName = "ZDecursiveKeyboardCast" .. index,
            }
          end
        end
      end
    end
  end
  if #desired.bindings == 0 then return desired, "unavailable", "No known friendly cure is available for this environment." end
  return desired
end

local function ClearOwned()
  if owner and ownsOverrides then
    local ok, result = pcall(ClearOverrideBindings, owner)
    if not ok or result == false then return false end
  end
  active = {}
  observedBindings = {}
  ownsOverrides = false
  signature = nil
  return true
end

local function Failure(message, desired)
  local cleared = ClearOwned()
  SetStatus("error", message .. (cleared and " Your normal keybindings are restored."
    or " Keyboard bindings could not be cleared; reload after leaving combat."), desired)
  return false, ns.GetKeyboardBindingStatus()
end

local function IsOwnedAction(key, action)
  for _, binding in ipairs(active) do
    if binding.key == key and action == "CLICK " .. binding.buttonName .. ":LeftButton" then return true end
  end
  return false
end

local function FindConflicts(desired)
  local conflicts = {}
  if desired.override then return conflicts end
  for _, binding in ipairs(desired.bindings) do
    local seen = {}
    -- The persistent binding is still a conflict when hidden by our own override.
    -- Checking both also preserves temporary bindings owned by another addon.
    for _, includeOverrides in ipairs({false, true}) do
      local ok, action = pcall(GetBindingAction, binding.key, includeOverrides)
      if not ok or not Accessible(action) or (action ~= nil and type(action) ~= "string") then return nil end
      if action and action ~= "" and not IsOwnedAction(binding.key, action) and not seen[action] then
        seen[action] = true
        conflicts[#conflicts + 1] = {key = binding.key, action = action}
      end
    end
  end
  return conflicts
end

local function RefreshApplied()
  if refreshing then return end
  local refreshed = false
  local addon = ns.addon
  if addon and type(addon.GetAppliedEnvironmentPack) == "function" then
    local pack = addon:GetAppliedEnvironmentPack()
    if type(pack) == "table" and type(ns.GetKeyboardCureActions) == "function" then
      ns.RefreshKeyboardBindings(pack, ns.GetKeyboardCureActions(pack))
      refreshed = true
    end
  elseif lastPack then
    ns.RefreshKeyboardBindings(lastPack, lastActions)
    refreshed = true
  end
  -- Refresh the visible status after event-driven changes, never from the
  -- per-MUF refresh path (Options may itself ask MUFs for their current model).
  if refreshed and not InCombatLockdown() and type(ns.RefreshOptions) == "function" then ns.RefreshOptions() end
end

local function ObserveKeyboardClick(button, mouseButton, down)
  local observed = observedBindings[button]
  if not observed or mouseButton ~= "LeftButton" or not Accessible(down) or down ~= observed.onDown
    or type(ns.BeginKeyboardCureAttempt) ~= "function" then return end
  if type(IsControlKeyDown) ~= "function" or type(IsShiftKeyDown) ~= "function" or type(IsAltKeyDown) ~= "function" then return end
  local ctrl, shift, alt = IsControlKeyDown(), IsShiftKeyDown(), IsAltKeyDown()
  if not Accessible(ctrl) or not Accessible(shift) or not Accessible(alt) then return end
  ctrl, shift, alt = ctrl == true or ctrl == 1, shift == true or shift == 1, alt == true or alt == 1
  local binding = observed.binding
  if alt or ctrl ~= (binding.index == 2) or shift ~= (binding.index == 3) then return end
  -- Only observe the attempt. Blizzard alone evaluates the mouseover condition
  -- and casts; the MUF result tracker waits for the matching success event.
  pcall(ns.BeginKeyboardCureAttempt, {
    index = binding.index, spellId = binding.spellId, baseId = binding.baseId,
    itemId = binding.itemId, actionKey = binding.actionKey,
  })
end

local function EnsureEvents()
  if eventFrame or type(CreateFrame) ~= "function" then return end
  eventFrame = CreateFrame("Frame")
  for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "CVAR_UPDATE"}) do
    eventFrame:RegisterEvent(event)
  end
  eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "CVAR_UPDATE" and (type(name) ~= "string" or name:lower() ~= "actionbuttonusekeydown") then return end
    RefreshApplied()
  end)
end

local function Apply(desired, inactiveState, inactiveMessage)
  if inactiveState and not ownsOverrides then
    SetStatus(inactiveState, inactiveMessage, desired)
    return true, ns.GetKeyboardBindingStatus()
  end
  if InCombatLockdown() then
    SetStatus("pending", "Keyboard changes will apply after combat; the previous bindings remain active.", desired)
    return false, ns.GetKeyboardBindingStatus()
  end
  if inactiveState then
    if not ClearOwned() then return Failure("Could not disable keyboard mouseover casting.", desired) end
    SetStatus(inactiveState, inactiveMessage, desired)
    return true, ns.GetKeyboardBindingStatus()
  end
  if type(GetBindingAction) ~= "function" or type(SetOverrideBindingClick) ~= "function"
    or type(ClearOverrideBindings) ~= "function" or type(CreateFrame) ~= "function" then
    return Failure("The secure keyboard binding API is unavailable.", desired)
  end
  local conflicts = FindConflicts(desired)
  if not conflicts then return Failure("Could not check existing keybindings.", desired) end
  if #conflicts > 0 then
    if not ClearOwned() then return Failure("Could not restore the conflicting keys.", desired) end
    local labels = {}
    for _, conflict in ipairs(conflicts) do labels[#labels + 1] = conflict.key .. ": " .. conflict.action end
    SetStatus("conflict", "Key already bound (" .. table.concat(labels, "; ") .. "). Choose another key or allow temporary overrides.", desired, conflicts)
    return false, ns.GetKeyboardBindingStatus()
  end
  local parts = {desired.onDown and "down" or "up"}
  for _, binding in ipairs(desired.bindings) do
    parts[#parts + 1] = binding.key .. "=" .. binding.macro .. "|" .. binding.actionKey .. "|" .. tostring(binding.baseId or 0)
  end
  local nextSignature = table.concat(parts, "\n")
  if signature ~= nextSignature then
    if not ClearOwned() then return Failure("Could not replace the previous keyboard bindings.", desired) end
    local ok = pcall(function()
      owner = owner or CreateFrame("Frame", "ZDecursiveKeyboardBindingOwner", UIParent)
      for _, binding in ipairs(desired.bindings) do
        local button = buttons[binding.index]
        if not button then
          button = CreateFrame("Button", binding.buttonName, UIParent, "SecureActionButtonTemplate")
          buttons[binding.index] = button
        end
        -- Repeat initialization after a failed setup; a created frame may have
        -- survived even though the previous transaction could not finish it.
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, -100)
        button:EnableMouse(false)
        button:Show()
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", binding.macro)
        button:SetAttribute("useOnKeyDown", desired.onDown)
        button:RegisterForClicks(desired.onDown and "AnyDown" or "AnyUp")
        button:SetScript("PreClick", ObserveKeyboardClick)
      end
      for _, binding in ipairs(desired.bindings) do
        -- Normal priority lets another addon's secure hover bindings take precedence.
        -- Mark ownership before the API call, which can fail after a partial write.
        ownsOverrides = true
        observedBindings[buttons[binding.index]] = {binding = binding, onDown = desired.onDown}
        local result = SetOverrideBindingClick(owner, false, binding.key, binding.buttonName, "LeftButton")
        if result == false then error("keyboard override rejected") end
        active[#active + 1] = binding
      end
    end)
    if not ok then return Failure("Could not apply keyboard mouseover casting.", desired) end
    signature = nextSignature
  end
  local labels = {}
  for _, binding in ipairs(active) do labels[#labels + 1] = binding.key .. ": " .. binding.name end
  SetStatus("active", table.concat(labels, "; ") .. ". Friendly living mouseover only. Missing cure modifiers are unassigned.", desired)
  return true, ns.GetKeyboardBindingStatus()
end

function ns.RefreshKeyboardBindings(pack, actions)
  if refreshing then return false, ns.GetKeyboardBindingStatus() end
  lastPack, lastActions = pack, actions
  EnsureEvents()
  local desired, state, message = BuildDesired(pack, actions)
  refreshing = true
  local success, result = Apply(desired, state, message)
  refreshing = false
  return success, result
end
