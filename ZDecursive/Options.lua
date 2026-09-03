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

if ns.DiagnosticCheckpoint then
  ns.DiagnosticCheckpoint("module", "Options file start")
end

local GOLD = {0.32, 0.86, 0.82, 1}
local GOLD_DIM = {0.32, 0.86, 0.82, 0.32}
local TEXT = {0.88, 0.93, 0.96, 1}
local MUTED = {0.50, 0.60, 0.66, 1}
local BG = {0.045, 0.07, 0.095, 0.97}
local HEADER = {0.07, 0.11, 0.15, 1}
local CARD = {0.09, 0.13, 0.17, 1}
local BORDER = {0.16, 0.34, 0.40, 0.85}
local TAB_IDLE = {0.10, 0.14, 0.18, 1}
local DANGER = {0.75, 0.28, 0.22, 1}

local ui = {
  tab = "mufs",
  destination = "status",
  frame = nil,
  simple = true,
  collapsed = {},
}

local OPTIONS_ARCHITECTURE_VERSION = 1
local OPTIONS_DEFAULT_DESTINATION = "STATUS"
local ENVIRONMENT_SUBMENU_ORDER = {"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP", "SOLO"}
local QUICK_BINDING_COUNT = 6
local SHORTCUT_ONLY_COUNT = 1
local WORKSPACE_LEFT = 204
local WORKSPACE_RIGHT = -20
local WORKSPACE_TOP = -116
local WORKSPACE_BOTTOM = 20
local WORKSPACE_GAP = 8
local PROFILE_BODY_GAP = 12
local SIDEBAR_HEADING_WIDTH = 146
local PROFILE_MODE_LABEL_WIDTH = 96
local PROFILE_MODE_GAP = 12
local PROFILE_MODE_BUTTON_GAP = 6
local OPTIONS_COMBAT_MESSAGE = "ZDecursive Options cannot be opened during combat."
local OPTIONS_COMBAT_NOTICE_SECONDS = 2
local lastOptionsCombatNotice

local ReportProfileAction
local SetDestination
local RefreshStatusPage
local RefreshDiagnosticsPage

local function AnchorWorkspaceFrame(frame, topLeft, topRight, gap)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, -(gap or 0))
  frame:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT", 0, -(gap or 0))
end

local function LayoutWorkspace(destination)
  if not ui.body then
    return
  end
  ui.body:ClearAllPoints()
  if destination == "environment" then
    AnchorWorkspaceFrame(ui.body, ui.tabBar, ui.tabBar, WORKSPACE_GAP)
  elseif destination == "addon_profiles" then
    AnchorWorkspaceFrame(ui.body, ui.profileBar, ui.profileBar, PROFILE_BODY_GAP)
  else
    ui.body:SetPoint("TOPLEFT", WORKSPACE_LEFT, WORKSPACE_TOP)
    ui.body:SetPoint("TOPRIGHT", WORKSPACE_RIGHT, WORKSPACE_TOP)
  end
  ui.body:SetPoint("BOTTOMRIGHT", WORKSPACE_RIGHT, WORKSPACE_BOTTOM)
end

local function Addon()
  return ns.addon
end

local function OptionsCombatReadOnly()
  if type(InCombatLockdown) ~= "function" then
    return false
  end
  local ok, value = pcall(InCombatLockdown)
  return ok and value == true
end

local function ShowOptionsCombatNotice()
  local now
  if type(GetTime) == "function" then
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then
      now = value
    end
  end
  if lastOptionsCombatNotice ~= nil then
    if not now or now - lastOptionsCombatNotice < OPTIONS_COMBAT_NOTICE_SECONDS then
      return false
    end
  end
  lastOptionsCombatNotice = now or 0
  if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
    UIErrorsFrame:AddMessage(OPTIONS_COMBAT_MESSAGE, 1, 0.15, 0.15, 1)
  end
  return true
end

local function OptionsAccessAllowed(source, notify)
  if not OptionsCombatReadOnly() then
    return true
  end
  if ns.CloseOptionsForCombat then
    ns.CloseOptionsForCombat(source or "OPTIONS_ACCESS")
  end
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("options_open_blocked", {source = source or "OPTIONS_ACCESS"}, false)
  end
  if notify ~= false then
    ShowOptionsCombatNotice()
  end
  return false
end

ns.OptionsAccessAllowed = OptionsAccessAllowed

local function ColorTex(tex, c, a)
  tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end

local function Paint(frame, fill, border)
  if not frame.SetBackdrop then
    Mixin(frame, BackdropTemplateMixin)
    frame:OnBackdropLoaded()
  end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
  if border then
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
  else
    frame:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

local function Font(parent, template, text, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetText(text or "")
  if r then
    fs:SetTextColor(r, g, b)
  else
    fs:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  end
  fs:SetJustifyH("LEFT")
  return fs
end

local function MakeButton(parent, label, width, kind)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width or 88, 28)
  local fill = TAB_IDLE
  local border = BORDER
  if kind == "gold" then
    fill = {0.07, 0.22, 0.22, 1}
    border = GOLD
  elseif kind == "danger" then
    fill = {0.18, 0.08, 0.07, 1}
    border = DANGER
  end
  Paint(btn, fill, border)
  local fs = Font(btn, "GameFontNormal", label)
  fs:SetPoint("CENTER")
  if kind == "gold" then
    fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  elseif kind == "danger" then
    fs:SetTextColor(0.95, 0.55, 0.45)
  else
    fs:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  end
  btn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
  end)
  btn:SetScript("OnLeave", function(self)
    local b = border
    self:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
  end)
  btn.label = fs
  function btn:SetText(text)
    self.label:SetText(text)
  end
  function btn:GetText()
    return self.label:GetText()
  end
  function btn:SetInteractionEnabled(enabled)
    self:EnableMouse(enabled == true)
    if enabled then
      self.label:SetTextColor(kind == "gold" and GOLD[1] or TEXT[1], kind == "gold" and GOLD[2] or TEXT[2], kind == "gold" and GOLD[3] or TEXT[3])
    else
      self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
  end
  return btn
end

local function MakeToggle(parent)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(42, 22)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
  Paint(btn, {0.18, 0.18, 0.2, 1}, {0.3, 0.3, 0.32, 1})
  local knob = btn:CreateTexture(nil, "OVERLAY")
  knob:SetColorTexture(0.75, 0.75, 0.75, 1)
  knob:SetSize(16, 16)
  knob:SetPoint("LEFT", 3, 0)
  btn.knob = knob
  btn._on = false
  function btn:SetOn(on)
    self._on = not not on
    if self._on then
      Paint(self, {0.07, 0.24, 0.24, 1}, GOLD)
      self.knob:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
      self.knob:ClearAllPoints()
      self.knob:SetPoint("RIGHT", -3, 0)
    else
      Paint(self, {0.18, 0.18, 0.2, 1}, {0.3, 0.3, 0.32, 1})
      self.knob:SetColorTexture(0.75, 0.75, 0.75, 1)
      self.knob:ClearAllPoints()
      self.knob:SetPoint("LEFT", 3, 0)
    end
  end
  btn:SetScript("OnClick", function(self)
    self:SetOn(not self._on)
    if self.OnValueChanged then
      self:OnValueChanged(self._on)
    end
  end)
  return btn
end

local function MakeSlider(parent, minV, maxV, step)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(280, 28)
  local slider = CreateFrame("Slider", nil, holder, "BackdropTemplate")
  slider:SetPoint("LEFT", 0, 0)
  slider:SetSize(220, 8)
  Paint(slider, {0.18, 0.18, 0.2, 1}, {0.3, 0.28, 0.22, 1})
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  thumb:SetSize(14, 14)
  slider:SetThumbTexture(thumb)
  local valueText = Font(holder, "GameFontHighlight", "")
  valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
  valueText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  holder.slider = slider
  holder.valueText = valueText
  function holder:SetNumber(v)
    holder._suppress = true
    slider:SetValue(v)
    holder._suppress = false
    if step < 1 then
      valueText:SetText(string.format("%.2f", v))
    else
      valueText:SetText(tostring(math.floor(v + 0.5)))
    end
  end
  function holder:SetEnabled(on)
    slider:EnableMouse(not not on)
    if on then
      thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
      valueText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      thumb:SetColorTexture(0.35, 0.40, 0.42, 1)
      valueText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
  end
  slider:SetScript("OnValueChanged", function(_, v)
    if step < 1 then
      valueText:SetText(string.format("%.2f", v))
    else
      valueText:SetText(tostring(math.floor(v + 0.5)))
    end
    if holder._suppress then
      return
    end
    if holder.OnValueChanged then
      holder:OnValueChanged(v)
    end
  end)
  return holder
end

local function MakeRow(parent, y, label)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(40)
  row:SetPoint("TOPLEFT", 16, y)
  row:SetPoint("TOPRIGHT", -16, y)
  local name = Font(row, "GameFontHighlight", label)
  name:SetPoint("LEFT", 8, 0)
  name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  row.label = name
  return row
end

local function MakeCard(parent, title)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Paint(card, CARD, BORDER)
  if title then
    local h = Font(card, "GameFontNormalLarge", title)
    h:SetPoint("TOPLEFT", 16, -14)
    h:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    card.title = h
  end
  return card
end


local function MakeColorSwatch(parent, hasOpacity)
  local alphaEnabled = hasOpacity ~= false
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(40, 22)
  Paint(btn, {1, 1, 1, 1}, BORDER)
  function btn:SetColor(c)
    local alpha = alphaEnabled and (c[4] or 1) or 1
    self._c = {c[1], c[2], c[3], alpha}
    self:SetBackdropColor(c[1], c[2], c[3], alpha)
  end
  btn:SetScript("OnClick", function(self)
    local c = self._c or {1, 1, 1, 1}
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
      return
    end
    local picker = {
      r = c[1],
      g = c[2],
      b = c[3],
      hasOpacity = alphaEnabled,
      swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = 1
        if alphaEnabled and ColorPickerFrame.GetColorAlpha then
          a = ColorPickerFrame:GetColorAlpha()
        end
        self:SetColor({r, g, b, a})
        if self.OnValueChanged then
          self:OnValueChanged(self._c)
        end
      end,
    }
    if alphaEnabled then
      picker.opacity = c[4] or 1
    end
    ColorPickerFrame:SetupColorPickerAndShow(picker)
  end)
  return btn
end

local function Pack()
  return Addon():GetEditingPack()
end

local function PathGet(section, key)
  return function()
    return Pack()[section][key]
  end
end

local function PathSet(section, key)
  return function(value)
    Pack()[section][key] = value
    if ns.InvalidateDetection then
      ns.InvalidateDetection()
    end
    local engine = ns.DetectionEngine
    if engine and type(engine.Refresh) == "function" then
      if ns.InvalidateUnitSort then
        ns.InvalidateUnitSort("options")
      end
      engine:Refresh("OPTIONS")
    else
      if ns.RequestUnitSortRefresh then
        ns.RequestUnitSortRefresh("options")
      elseif ns.RefreshMUFs then
        ns.RefreshMUFs()
      end
      if ns.RefreshAlerts then
        ns.RefreshAlerts()
      end
      if ns.RefreshLiveList then
        ns.RefreshLiveList()
      end
    end
    if ui.RefreshPreview then
      ui.RefreshPreview()
    end
  end
end

local function GetSharedMUFOrientation()
  local addon = Addon()
  return addon and addon.GetMUFVerticalLayout and addon:GetMUFVerticalLayout() or false
end

local function SetSharedMUFOrientation(value)
  local addon = Addon()
  if not addon or not addon.SetMUFOrientation then
    return
  end
  addon:SetMUFOrientation(value == true and "VERTICAL" or "HORIZONTAL")
  if ui.RefreshPreview then
    ui.RefreshPreview()
  end
end

local function GetMUFOrder()
  if ns.GetPendingMUFOrder then
    local pending = ns.GetPendingMUFOrder()
    if pending then
      return pending
    end
  end
  if ns.GetConfiguredMUFOrder then
    return ns.GetConfiguredMUFOrder(Pack())
  end
  return Pack().mufs.order
end

local function SetMUFOrder(value)
  if ns.SetConfiguredMUFOrder then
    ns.SetConfiguredMUFOrder(Pack(), value)
  else
    Pack().mufs.order = value
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
  end
  if ui.RefreshPreview then
    ui.RefreshPreview()
  end
end

local MOUSE_ACTIONS = {CURE = "Cure", TARGET = "Target", FOCUS = "Focus", ASSIST = "Assist"}
local RESERVED_MOUSE = {middle = "TARGET"}

local function NotifyPack()
  if ns.InvalidateDetection then
    ns.InvalidateDetection()
  end
  if ns.RebuildClickModel then
    ns.RebuildClickModel()
  end
  local engine = ns.DetectionEngine
  if engine and type(engine.Refresh) == "function" then
    engine:Refresh("OPTIONS_PACK")
  else
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    if ns.RefreshAlerts then
      ns.RefreshAlerts()
    end
    if ns.RefreshLiveList then
      ns.RefreshLiveList()
    end
  end
  if ui.RefreshPreview then
    ui.RefreshPreview()
  end
end

local function SetClickMode(value)
  if value ~= "AUTO" and value ~= "MANUAL" then
    return
  end
  local pack = Pack()
  if type(pack.cure) ~= "table" then
    pack.cure = {}
  end
  pack.cure.mode = value
  NotifyPack()
end

local function SetMouseAction(key)
  return function(value)
    if RESERVED_MOUSE[key] then
      value = RESERVED_MOUSE[key]
    end
    if value ~= "CURE" and value ~= "TARGET" and value ~= "FOCUS" and value ~= "ASSIST" then
      return
    end
    local pack = Pack()
    if type(pack.mouse) ~= "table" then
      pack.mouse = {}
    end
    pack.mouse[key] = value
    NotifyPack()
  end
end

local function AfterPackChange()
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  if ns.RefreshAlerts then
    ns.RefreshAlerts()
  end
  if ns.RefreshLiveList then
    ns.RefreshLiveList()
  end
  if ui.RefreshPreview then
    ui.RefreshPreview()
  end
end

local MACRO_BYTE_LIMIT = 255

local CUSTOM_TYPE_LABELS = {
  magic = "Magic",
  curse = "Curse",
  poison = "Poison",
  disease = "Disease",
}

local pendingCustomType = "magic"

local function KnownCustomType(key)
  if type(key) ~= "string" then
    return nil
  end
  key = string.lower(key)
  if CUSTOM_TYPE_LABELS[key] then
    return key
  end
  return nil
end

local function CustomSpellSummary()
  local pack = Pack()
  if not ns.EnsureCustomSpells then
    return "none"
  end
  local list = ns.EnsureCustomSpells(pack)
  if type(list) ~= "table" or #list == 0 then
    return "none"
  end
  local parts = {}
  for i = 1, #list do
    local row = list[i]
    if type(row) == "table" and row.spellId then
      local label = tostring(row.spellId)
      local effectiveTypes = ns.GetActionableCureTypes and ns.GetActionableCureTypes(row.types) or {}
      if #effectiveTypes > 0 then
        label = label .. " (" .. table.concat(effectiveTypes, "/") .. ")"
      else
        label = label .. " (ignored legacy type)"
      end
      parts[#parts + 1] = label
    end
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

local function ParseCustomSpellInput(value)
  local spellId
  local types = {}
  if type(value) == "number" then
    spellId = value
  elseif type(value) == "string" then
    for token in string.gmatch(value, "%S+") do
      local id = tonumber(token)
      local key = KnownCustomType(token)
      if not spellId and id then
        spellId = id
      elseif key then
        types[#types + 1] = key
      end
    end
  end
  if #types == 0 then
    types[1] = KnownCustomType(pendingCustomType) or "magic"
  end
  return spellId, types
end

local function AddCustomSpellFromUI(value)
  local pack = Pack()
  if not ns.AddCustomSpell then
    return
  end
  local spellId, types = ParseCustomSpellInput(value)
  local ok, err = ns.AddCustomSpell(pack, spellId, types)
  local addon = Addon()
  if ok then
    if addon and addon.Print then
      addon:Print("custom spell added")
    end
  elseif addon and addon.Print then
    addon:Print("custom spell not added (" .. tostring(err or "id") .. ")")
  end
  NotifyPack()
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
end

local function RemoveCustomSpellFromUI(value)
  local pack = Pack()
  if not ns.RemoveCustomSpell then
    return
  end
  local removed = ns.RemoveCustomSpell(pack, value)
  local addon = Addon()
  if addon and addon.Print then
    if removed then
      addon:Print("custom spell removed")
    else
      addon:Print("custom spell not found")
    end
  end
  NotifyPack()
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
end

local function MacroPreview(text)
  if type(text) ~= "string" or text == "" then
    return "empty"
  end
  if #text > 40 then
    return string.sub(text, 1, 40) .. "..."
  end
  return text
end

local function SetCustomMacro(value)
  if type(value) ~= "string" then
    value = ""
  end
  local pack = Pack()
  if type(pack.advanced) ~= "table" then
    pack.advanced = {}
  end
  if pack.advanced.allowMacroEdit ~= true then
    return
  end
  if value ~= "" and not string.find(value, "UNITID", 1, true) then
    local addon = Addon()
    if addon and addon.Print then
      addon:Print("custom macro needs UNITID")
    end
    return
  end
  local measured = value
  if value ~= "" then
    measured = string.gsub(value, "UNITID", "PARTYPET5")
  end
  if #measured > MACRO_BYTE_LIMIT then
    pack.advanced.customMacro = nil
    local addon = Addon()
    if addon and addon.Print then
      addon:Print("custom macro dropped (over 255 bytes)")
    end
  else
    pack.advanced.customMacro = value
  end
  if ns.DropOversizedMacros then
    ns.DropOversizedMacros(pack)
  end
  AfterPackChange()
end

local function SyncSpacingWidgets()
  local linked = Pack().mufs.linkSpacing
  for _, bind in ipairs(ui.binds or {}) do
    if bind.label == "Horizontal spacing" or bind.label == "Vertical spacing" then
      if bind.widget and bind.widget.SetNumber then
        bind.widget:SetNumber(bind.get())
      end
    end
    if bind.label == "Vertical spacing" and bind.widget and bind.widget.SetEnabled then
      bind.widget:SetEnabled(not linked)
    end
  end
end

local function SetLinkSpacing(on)
  local pack = Pack().mufs
  pack.linkSpacing = not not on
  if pack.linkSpacing then
    pack.verticalSpacing = pack.horizontalSpacing or 2
  end
  AfterPackChange()
  SyncSpacingWidgets()
end

local function SetLinkedSpacing(key)
  return function(value)
    local pack = Pack().mufs
    pack[key] = value
    if pack.linkSpacing then
      pack.horizontalSpacing = value
      pack.verticalSpacing = value
    end
    AfterPackChange()
    SyncSpacingWidgets()
  end
end

local EDITOR_PAGES = {"mufs", "sorting", "cure", "color", "alerts", "advanced"}
local PAGES = {"mufs", "sorting", "cure", "color", "alerts", "advanced", "assign"}
local PAGE_LABELS = {
  mufs = "MUFs",
  sorting = "Sorting",
  cure = "Cure",
  color = "Color",
  alerts = "Alerts",
  advanced = "Advanced",
  assign = "Decursive Profiles",
}

local ORDER_LABELS = {
  GROUP = "Group / roster",
  PRIORITY = "Decursive priority",
  DANDERSFRAMES = "DandersFrames",
}

local SOUND_LABELS = {
  FEMALE_DISPEL = "Female Dispel",
  FEMALE_DISPEL_ME = "Female Dispel Me",
  FEMALE_CLEANSE = "Female Cleanse",
  FEMALE_CLEANSE_ME = "Female Cleanse Me",
  VOICE_DISPEL = "Voice Dispel",
  VOICE_CLEANSE = "Voice Cleanse",
  VOICE_CURE = "Voice Cure",
  VOICE_HELP = "Voice Help",
  VOICE_CLEANSE_ME = "Voice Cleanse Me",
  VOICE_CURE_ME = "Voice Cure Me",
  VOICE_HELP_CLEANSE_ME = "Voice Help, Cleanse Me",
  VOICE_HELP_CURE_ME = "Voice Help, Cure Me",
  AFFLICTION = "Affliction",
  QUICK = "Quick",
  BRIGHT_PING = "Bright ping",
  DOUBLE_PING = "Double ping",
  TRIPLE_PING = "Triple ping",
  HIGH_CHIME = "High chime",
  LOW_CHIME = "Low chime",
  PULSE_UP = "Pulse up",
  PULSE_DOWN = "Pulse down",
  FAILURE = "Failure",
}

local CATALOG = {
  {page = "mufs", label = "Show MUFs", kind = "toggle", get = PathGet("mufs", "show"), set = PathSet("mufs", "show")},
  {page = "mufs", label = "Lock position", kind = "toggle", get = PathGet("mufs", "locked"), set = PathSet("mufs", "locked")},
  {page = "mufs", label = "MUF hover tooltip", kind = "toggle", get = PathGet("mufs", "tooltip"), set = PathSet("mufs", "tooltip")},
  {page = "mufs", label = "Status indicator light", kind = "toggle", get = PathGet("mufs", "statusLight"), set = PathSet("mufs", "statusLight")},
  {page = "mufs", label = "Party MUF size", kind = "slider", min = 10, max = 80, step = 1, get = PathGet("mufs", "partySize"), set = PathSet("mufs", "partySize")},
  {page = "mufs", label = "Raid MUF size", kind = "slider", min = 10, max = 80, step = 1, get = PathGet("mufs", "raidSize"), set = PathSet("mufs", "raidSize")},
  {page = "mufs", label = "Link horizontal and vertical spacing", kind = "toggle", get = PathGet("mufs", "linkSpacing"), set = SetLinkSpacing},
  {page = "mufs", label = "Horizontal spacing", kind = "slider", min = 0, max = 100, step = 1, get = PathGet("mufs", "horizontalSpacing"), set = SetLinkedSpacing("horizontalSpacing")},
  {page = "mufs", label = "Vertical spacing", kind = "slider", min = 0, max = 100, step = 1, get = PathGet("mufs", "verticalSpacing"), set = SetLinkedSpacing("verticalSpacing")},
  {page = "mufs", label = "Grow upward", kind = "toggle", get = PathGet("mufs", "growUp"), set = PathSet("mufs", "growUp")},
  {page = "mufs", label = "Grow from right edge", kind = "toggle", get = PathGet("mufs", "growFromRight"), set = PathSet("mufs", "growFromRight")},
  {page = "mufs", label = "Vertical orientation (all environment profiles)", description = "Shared by all six environment profiles. On fills columns before rows; Off fills rows before columns.", kind = "toggle", get = GetSharedMUFOrientation, set = SetSharedMUFOrientation},
  {page = "mufs", label = "Maximum displayed MUFs", description = "Caps non-pet MUF members after sorting. Enabled pets are additional and follow their displayed owners; detection is not limited.", kind = "slider", min = 1, max = 80, step = 1, get = PathGet("mufs", "maxUnits"), set = PathSet("mufs", "maxUnits")},
  {page = "mufs", label = "Units per line", kind = "slider", min = 1, max = 40, step = 1, get = PathGet("mufs", "unitsPerLine"), set = PathSet("mufs", "unitsPerLine")},
  {page = "mufs", label = "Show MUF border", kind = "toggle", get = PathGet("mufs", "border"), set = PathSet("mufs", "border")},
  {page = "mufs", label = "Inactive opacity", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("mufs", "inactiveOpacity"), set = PathSet("mufs", "inactiveOpacity")},

  {page = "sorting", label = "MUF order", kind = "choice", values = ORDER_LABELS, get = GetMUFOrder, set = SetMUFOrder},
  {page = "sorting", label = "Include player", kind = "toggle", get = PathGet("sorting", "includePlayer"), set = PathSet("sorting", "includePlayer")},
  {page = "sorting", label = "Include pets", kind = "toggle", get = PathGet("sorting", "includePets"), set = PathSet("sorting", "includePets")},
  {page = "sorting", label = "Center on player", kind = "toggle", get = PathGet("sorting", "centerPlayer"), set = PathSet("sorting", "centerPlayer")},
  {page = "sorting", label = "Skip dead and offline", kind = "toggle", get = PathGet("sorting", "skipDead"), set = PathSet("sorting", "skipDead")},

  {page = "cure", label = "Click mode", kind = "choice", values = {AUTO = "AUTO - priority bindings", MANUAL = "MANUAL - per-button"}, get = PathGet("cure", "mode"), set = SetClickMode},
  {page = "cure", label = "Detection filter", kind = "choice", values = {BY_ME = "By me - known targeted cures", ALL = "All actionable - four cure types"}, get = PathGet("cure", "filterMode"), set = PathSet("cure", "filterMode")},
  {page = "cure", label = "Magic", kind = "toggle", get = PathGet("cure", "magic"), set = PathSet("cure", "magic")},
  {page = "cure", label = "Curse", kind = "toggle", get = PathGet("cure", "curse"), set = PathSet("cure", "curse")},
  {page = "cure", label = "Poison", kind = "toggle", get = PathGet("cure", "poison"), set = PathSet("cure", "poison")},
  {page = "cure", label = "Disease", kind = "toggle", get = PathGet("cure", "disease"), set = PathSet("cure", "disease")},

  {page = "color", label = "Magic", kind = "color", get = PathGet("colors", "magic"), set = PathSet("colors", "magic")},
  {page = "color", label = "Curse", kind = "color", get = PathGet("colors", "curse"), set = PathSet("colors", "curse")},
  {page = "color", label = "Poison", kind = "color", get = PathGet("colors", "poison"), set = PathSet("colors", "poison")},
  {page = "color", label = "Disease", kind = "color", get = PathGet("colors", "disease"), set = PathSet("colors", "disease")},
  {page = "color", label = "Healthy MUF", kind = "color", get = PathGet("colors", "healthy"), set = PathSet("colors", "healthy")},
  {page = "color", label = "Afflicted MUF", kind = "color", get = PathGet("colors", "afflicted"), set = PathSet("colors", "afflicted")},
  {page = "color", label = "Healthy center opacity", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("mufs", "centerTransp"), set = PathSet("mufs", "centerTransp")},
  {page = "color", label = "Class border opacity", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("mufs", "borderTransp"), set = PathSet("mufs", "borderTransp")},

  {page = "alerts", label = "Dispel text alert", description = "Shows red 'DISPEL' when Blizzard's provider reports a dispellable aura landing. This is an opportunity alert, not confirmation of a cure.", kind = "toggle", get = PathGet("alerts", "dispelEnabled"), set = PathSet("alerts", "dispelEnabled")},
  {page = "alerts", label = "Show successful dispel text", description = "Shows 'Dispelled' on screen after ZDecursive confirms a successful cure. This is independent of the landing DISPEL and Soul Link alerts and never writes to chat.", kind = "toggle", get = PathGet("alerts", "successfulDispelText"), set = PathSet("alerts", "successfulDispelText")},
  {page = "alerts", label = "Display mode", kind = "choice", values = {TIMED = "Timed", UNTIL_CLEARED = "Until cleared"}, get = PathGet("alerts", "dispelMode"), set = PathSet("alerts", "dispelMode")},
  {page = "alerts", label = "Display duration", kind = "slider", min = 0.5, max = 30, step = 0.5, get = PathGet("alerts", "dispelDuration"), set = PathSet("alerts", "dispelDuration")},
  {page = "alerts", label = "Text size", kind = "slider", min = 12, max = 96, step = 1, get = PathGet("alerts", "dispelFontSize"), set = PathSet("alerts", "dispelFontSize")},
  {page = "alerts", label = "Text color", kind = "color", get = PathGet("alerts", "dispelColor"), set = PathSet("alerts", "dispelColor")},
  {page = "alerts", label = "Test Text", description = "Previews the editing environment's DISPEL text without changing settings or native sound registrations.", kind = "button", buttonLabel = "Test", run = function()
    if OptionsAccessAllowed("ALERT_TEXT_TEST") and ns.PlayTestText then
      ns.PlayTestText(Pack())
    end
  end},
  {page = "alerts", label = "PvP text", kind = "toggle", get = PathGet("alerts", "pvpText"), set = PathSet("alerts", "pvpText")},
  {page = "alerts", label = "Text alerts", kind = "toggle", get = PathGet("alerts", "text"), set = PathSet("alerts", "text")},
  {page = "alerts", label = "Chat status messages", kind = "toggle", get = PathGet("alerts", "chat"), set = PathSet("alerts", "chat")},
  {page = "alerts", label = "Dispel sound", kind = "toggle", get = PathGet("alerts", "sound"), set = PathSet("alerts", "sound")},
  {page = "alerts", label = "Sound", kind = "choice", values = SOUND_LABELS, get = PathGet("alerts", "soundPreset"), set = PathSet("alerts", "soundPreset")},
  {page = "alerts", label = "Sound channel", kind = "choice", values = {Master = "Master", SFX = "SFX", Music = "Music", Ambience = "Ambience", Dialog = "Dialog"}, get = PathGet("alerts", "soundChannel"), set = PathSet("alerts", "soundChannel")},
  {page = "alerts", label = "Lua fallback debounce", description = "Applies only to Lua fallback and failure sounds. Blizzard-native aura landing sounds are independently provider-owned.", kind = "slider", min = 0, max = 5, step = 0.25, get = PathGet("alerts", "soundDebounce"), set = PathSet("alerts", "soundDebounce")},
  {page = "alerts", label = "Cure-failure sound", kind = "toggle", get = PathGet("alerts", "errorSound"), set = PathSet("alerts", "errorSound")},
  {page = "alerts", label = "Test Sound", kind = "button", run = function()
    if ns.PlayTestSound then
      ns.PlayTestSound()
    end
  end},
  {page = "alerts", label = "Cooldown overlay", kind = "toggle", get = PathGet("alerts", "cooldown"), set = PathSet("alerts", "cooldown")},
  {page = "alerts", label = "Countdown numbers", kind = "toggle", get = PathGet("alerts", "cooldownNumbers"), set = PathSet("alerts", "cooldownNumbers")},
  {page = "alerts", label = "Overlay darkness", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("alerts", "cooldownOpacity"), set = PathSet("alerts", "cooldownOpacity")},
  {page = "alerts", label = "Out-of-range status", kind = "toggle", get = PathGet("alerts", "range"), set = PathSet("alerts", "range")},

  {page = "mufs", label = "Auto-hide MUFs", kind = "choice", values = {NEVER = "Never", SOLO = "When solo", ALWAYS = "Always hide"}, get = PathGet("mufs", "autoHide"), set = PathSet("mufs", "autoHide")},
  {page = "mufs", label = "Hide move handle", kind = "toggle", get = PathGet("mufs", "hideHandle"), set = PathSet("mufs", "hideHandle")},
  {page = "mufs", label = "Show help text", kind = "toggle", get = PathGet("mufs", "showHelp"), set = PathSet("mufs", "showHelp")},
  {page = "mufs", label = "Center unit name", kind = "toggle", get = PathGet("mufs", "centerText"), set = PathSet("mufs", "centerText")},
  {page = "mufs", label = "Show stealth status", kind = "toggle", get = PathGet("mufs", "stealthStatus"), set = PathSet("mufs", "stealthStatus")},
  {page = "mufs", label = "MUF scale", kind = "slider", min = 0.5, max = 2, step = 0.05, get = PathGet("mufs", "scale"), set = PathSet("mufs", "scale")},
  {page = "mufs", label = "Dim out of range", kind = "toggle", get = PathGet("mufs", "dimOutOfRange"), set = PathSet("mufs", "dimOutOfRange")},
  {page = "mufs", label = "Out-of-range dim", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("mufs", "dimAmount"), set = PathSet("mufs", "dimAmount")},
  {page = "mufs", label = "Share cooldown with same-priority MUFs", kind = "toggle", get = PathGet("mufs", "shareCooldown"), set = PathSet("mufs", "shareCooldown")},
  {page = "mufs", label = "Clear cleansed target immediately", kind = "toggle", get = PathGet("mufs", "clearCleansedImmediately"), set = PathSet("mufs", "clearCleansedImmediately")},
  {page = "mufs", label = "Soul Link fallback", kind = "toggle", get = PathGet("mufs", "soulLinkFallback"), set = PathSet("mufs", "soulLinkFallback")},
  {page = "mufs", label = "Tie center and border opacity", kind = "toggle", get = PathGet("mufs", "tieCenterAndBorder"), set = PathSet("mufs", "tieCenterAndBorder")},

  {page = "cure", label = "Cure pets", kind = "toggle", get = PathGet("cure", "curePets"), set = PathSet("cure", "curePets")},
  {page = "cure", label = "Custom spell type", kind = "choice", values = CUSTOM_TYPE_LABELS, get = function() return pendingCustomType end, set = function(value)
    pendingCustomType = KnownCustomType(value) or "magic"
  end},
  {page = "cure", label = "Add custom dispel spell", kind = "text", get = function() return "" end, set = AddCustomSpellFromUI},
  {page = "cure", label = "Remove custom dispel spell", kind = "text", get = CustomSpellSummary, set = RemoveCustomSpellFromUI},
  {page = "cure", label = "Left click", kind = "choice", values = MOUSE_ACTIONS, get = PathGet("mouse", "left"), set = SetMouseAction("left")},
  {page = "cure", label = "Right click", kind = "choice", values = MOUSE_ACTIONS, get = PathGet("mouse", "right"), set = SetMouseAction("right")},
  {page = "cure", label = "Middle click", kind = "choice", values = MOUSE_ACTIONS, get = PathGet("mouse", "middle"), set = SetMouseAction("middle")},
  {page = "cure", label = "Button 4", kind = "choice", values = MOUSE_ACTIONS, get = PathGet("mouse", "button4"), set = SetMouseAction("button4")},
  {page = "cure", label = "Button 5", kind = "choice", values = MOUSE_ACTIONS, get = PathGet("mouse", "button5"), set = SetMouseAction("button5")},

  {page = "color", label = "Dead / ghost / offline", kind = "color", get = PathGet("colors", "dead"), set = PathSet("colors", "dead")},
  {page = "color", label = "Out of range", description = "RGB color only. Out-of-range dim controls brightness exactly once.", kind = "color", hasOpacity = false, get = PathGet("colors", "range"), set = PathSet("colors", "range")},
  {page = "color", label = "Stealth", kind = "color", get = PathGet("colors", "stealth"), set = PathSet("colors", "stealth")},

  {page = "alerts", label = "Show in copyable diagnostics", kind = "toggle", get = PathGet("alerts", "printChat"), set = PathSet("alerts", "printChat")},
  {page = "alerts", label = "Print to custom window", kind = "toggle", get = PathGet("alerts", "printCustom"), set = PathSet("alerts", "printCustom")},
  {page = "alerts", label = "Print errors", kind = "toggle", get = PathGet("alerts", "printErrors"), set = PathSet("alerts", "printErrors")},
  {page = "alerts", label = "Soul Link battle-rez warning", description = "Shows a battle-rez range warning only after an attributed Soul Link attempt fails out of range. It is not an affliction or cure-success alert.", kind = "toggle", get = PathGet("alerts", "soulLinkAlert"), set = PathSet("alerts", "soulLinkAlert")},
  {page = "alerts", label = "Native 12.1 aura sounds", kind = "toggle", get = PathGet("alerts", "nativeAuraSound"), set = PathSet("alerts", "nativeAuraSound")},
  {page = "alerts", label = "Live list", kind = "toggle", get = PathGet("alerts", "liveList"), set = PathSet("alerts", "liveList")},
  {page = "alerts", label = "Live list only in range", kind = "toggle", get = PathGet("alerts", "liveListOnlyInRange"), set = PathSet("alerts", "liveListOnlyInRange")},
  {page = "alerts", label = "Live list rows", kind = "slider", min = 1, max = 20, step = 1, get = PathGet("alerts", "liveListAmount"), set = PathSet("alerts", "liveListAmount")},
  {page = "alerts", label = "Live list scan (seconds)", kind = "slider", min = 0.05, max = 1, step = 0.05, get = PathGet("alerts", "liveListScan"), set = PathSet("alerts", "liveListScan")},
  {page = "alerts", label = "Reverse live list", kind = "toggle", get = PathGet("alerts", "liveListReverse"), set = PathSet("alerts", "liveListReverse")},
  {page = "alerts", label = "Live list scale", kind = "slider", min = 0.5, max = 2, step = 0.05, get = PathGet("alerts", "liveListScale"), set = PathSet("alerts", "liveListScale")},
  {page = "alerts", label = "Live list opacity", kind = "slider", min = 0.2, max = 1, step = 0.05, get = PathGet("alerts", "liveListAlpha"), set = PathSet("alerts", "liveListAlpha")},

  {page = "advanced", label = "Allow macro editing", kind = "toggle", get = PathGet("advanced", "allowMacroEdit"), set = PathSet("advanced", "allowMacroEdit")},
  {page = "advanced", label = "Custom macro", kind = "text", get = PathGet("advanced", "customMacro"), set = SetCustomMacro},
}


local ROW_META = {
  ["mufs|Show MUFs"] = {group = "Display", simple = true},
  ["mufs|Lock position"] = {group = "Display", simple = true},
  ["mufs|MUF hover tooltip"] = {group = "Display", simple = true},
  ["mufs|Auto-hide MUFs"] = {group = "Display", simple = true},
  ["mufs|Hide move handle"] = {group = "Display"},
  ["mufs|Show help text"] = {group = "Display"},
  ["mufs|Party MUF size"] = {group = "Size", simple = true, hideEnv = {RAID = true}},
  ["mufs|Raid MUF size"] = {group = "Size", simple = true, hideEnv = {MYTHIC_PLUS = true, DUNGEON = true}},
  ["mufs|MUF scale"] = {group = "Size"},
  ["mufs|Maximum displayed MUFs"] = {group = "Size"},
  ["mufs|Units per line"] = {group = "Size", simple = true},
  ["mufs|Link horizontal and vertical spacing"] = {group = "Spacing", simple = true},
  ["mufs|Horizontal spacing"] = {group = "Spacing", simple = true},
  ["mufs|Vertical spacing"] = {group = "Spacing", simple = true},
  ["mufs|Grow upward"] = {group = "Layout"},
  ["mufs|Grow from right edge"] = {group = "Layout"},
  ["mufs|Vertical orientation (all environment profiles)"] = {group = "Layout"},
  ["mufs|Show MUF border"] = {group = "Look"},
  ["mufs|Inactive opacity"] = {group = "Look"},
  ["mufs|Center unit name"] = {group = "Look"},
  ["mufs|Show stealth status"] = {group = "Look"},
  ["mufs|Status indicator light"] = {group = "Status"},
  ["mufs|Dim out of range"] = {group = "Status"},
  ["mufs|Out-of-range dim"] = {group = "Status"},
  ["mufs|Share cooldown with same-priority MUFs"] = {group = "Status"},
  ["mufs|Clear cleansed target immediately"] = {group = "Status"},
  ["mufs|Soul Link fallback"] = {group = "Status"},
  ["mufs|Tie center and border opacity"] = {group = "Status"},
  ["sorting|MUF order"] = {group = "Roster", simple = true},
  ["sorting|Include player"] = {group = "Roster", simple = true},
  ["sorting|Include pets"] = {group = "Roster", simple = true},
  ["sorting|Center on player"] = {group = "Roster"},
  ["sorting|Skip dead and offline"] = {group = "Roster"},
  ["cure|Click mode"] = {group = "Clicks", simple = true},
  ["cure|Detection filter"] = {group = "Clicks", simple = true},
  ["cure|Left click"] = {group = "Clicks"},
  ["cure|Right click"] = {group = "Clicks"},
  ["cure|Middle click"] = {group = "Clicks"},
  ["cure|Button 4"] = {group = "Clicks"},
  ["cure|Button 5"] = {group = "Clicks"},
  ["cure|Magic"] = {group = "Types", simple = true},
  ["cure|Curse"] = {group = "Types", simple = true},
  ["cure|Poison"] = {group = "Types", simple = true},
  ["cure|Disease"] = {group = "Types", simple = true},
  ["cure|Cure pets"] = {group = "Rules"},
  ["cure|Add custom dispel spell"] = {group = "Custom", simple = true},
  ["cure|Remove custom dispel spell"] = {group = "Custom", simple = true},
  ["color|Magic"] = {group = "Afflictions", simple = true},
  ["color|Curse"] = {group = "Afflictions", simple = true},
  ["color|Poison"] = {group = "Afflictions", simple = true},
  ["color|Disease"] = {group = "Afflictions", simple = true},
  ["color|Healthy MUF"] = {group = "Squares"},
  ["color|Afflicted MUF"] = {group = "Squares"},
  ["color|Healthy center opacity"] = {group = "Squares"},
  ["color|Class border opacity"] = {group = "Squares"},
  ["color|Dead / ghost / offline"] = {group = "Squares"},
  ["color|Out of range"] = {group = "Squares", simple = true},
  ["color|Stealth"] = {group = "Squares"},
  ["alerts|Dispel text alert"] = {group = "Text Alerts", simple = true},
  ["alerts|Soul Link battle-rez warning"] = {group = "Text Alerts", simple = true},
  ["alerts|Show successful dispel text"] = {group = "Text Alerts", simple = true},
  ["alerts|Display mode"] = {group = "Text Alerts"},
  ["alerts|Display duration"] = {group = "Text Alerts"},
  ["alerts|Text size"] = {group = "Text Alerts"},
  ["alerts|Text color"] = {group = "Text Alerts"},
  ["alerts|Test Text"] = {group = "Text Alerts", simple = true},
  ["alerts|PvP text"] = {group = "Text Alerts", simple = true},
  ["alerts|Text alerts"] = {group = "Text Alerts"},
  ["alerts|Dispel sound"] = {group = "Sound", simple = true},
  ["alerts|Sound"] = {group = "Sound"},
  ["alerts|Sound channel"] = {group = "Sound"},
  ["alerts|Lua fallback debounce"] = {group = "Sound"},
  ["alerts|Cure-failure sound"] = {group = "Sound"},
  ["alerts|Test Sound"] = {group = "Sound", simple = true},
  ["alerts|Native 12.1 aura sounds"] = {group = "Sound"},
  ["alerts|Cooldown overlay"] = {group = "Cooldown", simple = true},
  ["alerts|Countdown numbers"] = {group = "Cooldown"},
  ["alerts|Overlay darkness"] = {group = "Cooldown"},
  ["alerts|Out-of-range status"] = {group = "Cooldown"},
  ["alerts|Show in copyable diagnostics"] = {group = "Diagnostics"},
  ["alerts|Print to custom window"] = {group = "Chat"},
  ["alerts|Print errors"] = {group = "Chat"},
  ["alerts|Chat status messages"] = {group = "Chat"},
  ["alerts|Live list"] = {group = "Live list", simple = true},
  ["alerts|Live list only in range"] = {group = "Live list"},
  ["alerts|Live list rows"] = {group = "Live list", simple = true},
  ["alerts|Live list scan (seconds)"] = {group = "Live list"},
  ["alerts|Reverse live list"] = {group = "Live list"},
  ["alerts|Live list scale"] = {group = "Live list"},
  ["alerts|Live list opacity"] = {group = "Live list"},
  ["advanced|Allow macro editing"] = {group = "Engine"},
  ["advanced|Custom macro"] = {group = "Engine"},
}

local GROUP_ORDER = {
  mufs = {"Display", "Size", "Spacing", "Layout", "Look", "Status"},
  sorting = {"Roster"},
  cure = {"Types", "Clicks", "Rules", "Custom"},
  color = {"Afflictions", "Squares"},
  alerts = {"Text Alerts", "Sound", "Cooldown", "Chat", "Live list"},
  advanced = {"Engine"},
}

for _, spec in ipairs(CATALOG) do
  local meta = ROW_META[spec.page .. "|" .. spec.label]
  if meta then
    spec.group = meta.group
    spec.simple = meta.simple
    spec.hideEnv = meta.hideEnv
  else
    spec.group = spec.group or "More"
  end
end

local function EnsureCatalogRenderReachability()
  local known = {}
  for page, groups in pairs(GROUP_ORDER) do
    known[page] = {}
    for _, group in ipairs(groups) do
      known[page][group] = true
    end
  end
  for _, spec in ipairs(CATALOG) do
    local groups = GROUP_ORDER[spec.page]
    local pageKnown = known[spec.page]
    if groups and pageKnown and not pageKnown[spec.group] then
      groups[#groups + 1] = spec.group
      pageKnown[spec.group] = true
    end
  end
end

EnsureCatalogRenderReachability()

local PAGE_HAS_SIMPLE = {}
for _, spec in ipairs(CATALOG) do
  if spec.simple then
    PAGE_HAS_SIMPLE[spec.page] = true
  end
end


local function ShowModal(title, defaultText, onAccept)
  if not OptionsAccessAllowed("PROFILE_MODAL") then
    return false
  end
  local f = ui.modal
  f.title:SetText(title)
  f.edit:SetText(defaultText or "")
  f.edit:HighlightText()
  f.edit:Show()
  if f.hint then
    f.hint:SetText("")
    f.hint:Hide()
  end
  if f.ok then
    f.ok:SetText("Save")
  end
  f.onAccept = function(value)
    if OptionsAccessAllowed("PROFILE_MODAL_ACCEPT") then
      onAccept(value)
    end
  end
  f.confirmOnly = false
  f:Show()
  f.edit:SetFocus()
  return true
end

local function ShowConfirm(title, hint, onAccept)
  if not OptionsAccessAllowed("PROFILE_CONFIRM") then
    return false
  end
  local f = ui.modal
  f.title:SetText(title)
  f.edit:SetText("")
  f.edit:Hide()
  if f.hint then
    f.hint:SetText(hint or "")
    f.hint:Show()
  end
  if f.ok then
    f.ok:SetText("Reset")
  end
  f.onAccept = function()
    if OptionsAccessAllowed("PROFILE_CONFIRM_ACCEPT") then
      onAccept()
    end
  end
  f.confirmOnly = true
  f:Show()
  return true
end

local function HideModal()
  ui.modal:Hide()
end

local function OpenChoiceMenu(anchor, values, get, set)
  if not OptionsAccessAllowed("CHOICE_MENU") then
    return false
  end
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return false
  end
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    local current = get()
    for key, label in pairs(values) do
      root:CreateRadio(label, function()
        return current == key
      end, function()
        if OptionsAccessAllowed("CHOICE_MENU_SELECT") then
          set(key)
          ns.RefreshOptions()
        end
      end)
    end
  end)
  return true
end

local function OpenProfileMenu(anchor, onPick, includeInherit)
  if not OptionsAccessAllowed("PROFILE_MENU") then
    return false
  end
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return false
  end
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    local status = Addon():GetUIProfileStatus()
    local actual = status and status.available and status.actualProfile or nil
    if includeInherit then
      root:CreateButton("Use account / Default", function()
        if OptionsAccessAllowed("PROFILE_NAVIGATION") then
          onPick(nil)
        end
      end)
      root:CreateDivider()
    end
    for _, name in ipairs(Addon():GetProfileNames()) do
      root:CreateRadio(name, function()
        return actual == name
      end, function()
        if OptionsAccessAllowed("PROFILE_NAVIGATION") then
          onPick(name)
        end
      end)
    end
  end)
  return true
end

local function OpenEnvCopyMenu(anchor)
  if not OptionsAccessAllowed("ENVIRONMENT_COPY_MENU") then
    return false
  end
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return false
  end
  if Addon():GetEnvironmentMode() ~= "multiple" then
    return false
  end
  local src = Addon():GetEditingEnvironment()
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    root:CreateTitle("Copy " .. (ns.ENV_LABELS[src] or src) .. " to")
    for _, row in ipairs(ns.MULTIPLE_ENVIRONMENTS) do
      if row.key ~= src then
        root:CreateButton(row.label, function()
          if OptionsAccessAllowed("ENVIRONMENT_COPY_SELECT") then
            local ok, state = Addon():CopyEditingPackTo(row.key)
            ReportProfileAction(ok, state, "Environment copied.")
          end
        end)
      end
    end
  end)
  return true
end

local function MatchesSearch(label)
  local q = ui.search or ""
  if q == "" then
    return true
  end
  return string.find(string.lower(label), q, 1, true) ~= nil
end


local function RowVisible(spec)
  local env = Addon():GetEditingEnvironment()
  if spec.hideEnv and spec.hideEnv[env] then
    return false
  end
  local searching = ui.search and ui.search ~= ""
  if searching then
    return true
  end
  if ui.simple and not spec.simple and PAGE_HAS_SIMPLE[spec.page] then
    return false
  end
  return true
end

local function IsCollapsed(page, group)
  if ui.simple then
    return false
  end
  local pageMap = ui.collapsed[page]
  if not pageMap then
    return group ~= "Display" and group ~= "Size" and group ~= "Types" and group ~= "Roster" and group ~= "Afflictions" and group ~= "Text Alerts" and group ~= "Clicks" and group ~= "Live list"
  end
  if pageMap[group] == nil then
    return group ~= "Display" and group ~= "Size" and group ~= "Types" and group ~= "Roster" and group ~= "Afflictions" and group ~= "Text Alerts" and group ~= "Clicks" and group ~= "Live list"
  end
  return pageMap[group]
end


local PREVIEW_MAX_UNITS = 40
local PREVIEW_CAPTION_HEIGHT = 22
local PREVIEW_PADDING = 12
local PREVIEW_PARTY_MIN_CONTENT_HEIGHT = 64
local PREVIEW_PARTY_MAX_CONTENT_HEIGHT = 86
local PREVIEW_RAID_MIN_CONTENT_HEIGHT = 88
local PREVIEW_RAID_MAX_CONTENT_HEIGHT = 152
local PREVIEW_SEPARATOR = string.char(194, 183)
local PREVIEW_STATES = {
  {key = "magic"},
  {key = "curse"},
  {key = "poison"},
  {key = "disease"},
  {key = "healthy"},
}
local LayoutCatalog

local function PreviewSize(pack, env)
  if env == "RAID" then
    return pack.mufs.raidSize or 20
  end
  if env == "DUNGEON" or env == "MYTHIC_PLUS" then
    return pack.mufs.partySize or 20
  end
  return pack.mufs.partySize or 20
end

local function PreviewCount(pack, env)
  local configured = tonumber(pack and pack.mufs and pack.mufs.maxUnits)
  local defaultCount = ns.DEFAULT_MUF_DISPLAY_CAP or 5
  local largeGroup = env == "RAID" or env == "PVP"
  if largeGroup and (configured == nil or configured == defaultCount) then
    return PREVIEW_MAX_UNITS
  end
  configured = math.floor(configured or defaultCount)
  if largeGroup then
    return math.max(1, math.min(PREVIEW_MAX_UNITS, configured))
  end
  return math.max(1, math.min(defaultCount, configured))
end

ns.GetMUFPreviewCount = PreviewCount

function ns.CalculateMUFPreviewGeometry(layout, configuredScale, hostWidth, minContentHeight, maxContentHeight, handleHeight, handleBelow)
  if type(layout) ~= "table" or type(layout.positions) ~= "table" then
    return nil
  end
  minContentHeight = math.max(1, tonumber(minContentHeight) or PREVIEW_PARTY_MIN_CONTENT_HEIGHT)
  maxContentHeight = math.max(minContentHeight, tonumber(maxContentHeight) or PREVIEW_PARTY_MAX_CONTENT_HEIGHT)
  local availableWidth = math.max(1, (tonumber(hostWidth) or 960) - PREVIEW_PADDING * 2)
  configuredScale = math.max(0.05, tonumber(configuredScale) or 1)
  handleHeight = math.max(0, tonumber(handleHeight) or 0)
  local scaledWidth = math.max(1, (tonumber(layout.width) or 1) * configuredScale)
  local scaledHeight = math.max(1, ((tonumber(layout.height) or 1) + handleHeight) * configuredScale)
  local fit = math.min(1, availableWidth / scaledWidth, maxContentHeight / scaledHeight)
  local previewScale = configuredScale * fit
  local minX
  local minY
  for i = 1, #layout.positions do
    local position = layout.positions[i]
    minX = minX and math.min(minX, position.x) or position.x
    minY = minY and math.min(minY, position.y) or position.y
  end
  minX = minX or 0
  minY = minY or 0
  local drawnWidth = (tonumber(layout.width) or 1) * previewScale
  local layoutDrawnHeight = (tonumber(layout.height) or 1) * previewScale
  local handleDrawnHeight = handleHeight * previewScale
  local drawnHeight = layoutDrawnHeight + handleDrawnHeight
  local contentHeight = math.max(minContentHeight, math.min(maxContentHeight, drawnHeight))
  local verticalCenter = (contentHeight - drawnHeight) * 0.5
  return {
    scale = previewScale,
    drawSize = (tonumber(layout.size) or 20) * previewScale,
    drawnWidth = drawnWidth,
    drawnHeight = drawnHeight,
    layoutDrawnHeight = layoutDrawnHeight,
    handleDrawnHeight = handleDrawnHeight,
    availableWidth = availableWidth,
    availableHeight = contentHeight,
    contentHeight = contentHeight,
    hostHeight = PREVIEW_CAPTION_HEIGHT + PREVIEW_PADDING * 2 + contentHeight,
    originX = PREVIEW_PADDING + (availableWidth - drawnWidth) * 0.5 - minX * previewScale,
    originY = PREVIEW_PADDING + verticalCenter + (handleBelow and handleDrawnHeight or 0) - minY * previewScale,
  }
end

local function TeardownMUFPreview()
  if type(ui.previewSquares) == "table" then
    for i = 1, #ui.previewSquares do
      ui.previewSquares[i]:Hide()
    end
  end
  if ui.previewHandle then
    ui.previewHandle:Hide()
  end
  ui.previewVisibleCount = 0
end

local function PreviewStateColor(pack, state)
  local colors = pack.colors or {}
  local mufs = pack.mufs or {}
  local color = colors[state.key] or GOLD
  local alpha = color[4] or 1
  if state.key == "healthy" then
    alpha = mufs.inactiveOpacity or alpha
  end
  return color[1] or 0.3, color[2] or 0.8, color[3] or 0.8, alpha
end

local function MUFPreviewActive()
  return ui.destination == "environment" and ui.tab == "mufs" and (not ui.search or ui.search == "")
end

local function RefreshPreview()
  if not ui.previewHost or not ui.previewSquares then
    return
  end
  if not MUFPreviewActive() then
    TeardownMUFPreview()
    return
  end
  local addon = Addon()
  if not addon then
    return
  end
  local pack = addon:GetEditingPack()
  local env = addon:GetEditingEnvironment()
  local size = PreviewSize(pack, env)
  local hSpace = pack.mufs.horizontalSpacing or 2
  local vSpace = pack.mufs.verticalSpacing or 2
  if pack.mufs.linkSpacing then
    vSpace = hSpace
  end
  local hostW = ui.previewHost:GetWidth()
  if not hostW or hostW < 100 then
    hostW = 960
  end
  local n = PreviewCount(pack, env)
  local perLine = math.max(1, math.min(PREVIEW_MAX_UNITS, math.floor(tonumber(pack.mufs.unitsPerLine) or 10)))
  local verticalLayout = addon.GetMUFVerticalLayout and addon:GetMUFVerticalLayout() or false
  local layout = ns.CalculateMUFLayout and ns.CalculateMUFLayout(
    n,
    size,
    hSpace,
    vSpace,
    pack.mufs.statusLight,
    perLine,
    verticalLayout,
    pack.mufs.growUp,
    pack.mufs.growFromRight
  )
  if type(layout) ~= "table" then
    TeardownMUFPreview()
    return
  end
  local minContentHeight = env == "RAID" and PREVIEW_RAID_MIN_CONTENT_HEIGHT or PREVIEW_PARTY_MIN_CONTENT_HEIGHT
  local maxContentHeight = env == "RAID" and PREVIEW_RAID_MAX_CONTENT_HEIGHT or PREVIEW_PARTY_MAX_CONTENT_HEIGHT
  local handleHeight = pack.mufs.hideHandle ~= true and size or 0
  local geometry = ns.CalculateMUFPreviewGeometry(layout, pack.mufs.scale, hostW, minContentHeight, maxContentHeight, handleHeight, pack.mufs.growUp == true)
  if not geometry then
    TeardownMUFPreview()
    return
  end
  local oldHeight = ui.previewHeight
  ui.previewHeight = geometry.hostHeight
  ui.previewHost:SetHeight(geometry.hostHeight)
  if oldHeight and math.abs(oldHeight - geometry.hostHeight) > 0.01 and not ui.layoutCatalogActive and LayoutCatalog then
    LayoutCatalog()
    return
  end
  local previewScale = geometry.scale
  local draw = geometry.drawSize
  local shown = pack.mufs.show ~= false
  local colors = pack.colors or {}
  if ui.previewCaption then
    if env == "RAID" then
      ui.previewCaption:SetText(string.format("Raid preview " .. PREVIEW_SEPARATOR .. " %d units " .. PREVIEW_SEPARATOR .. " %d per line", n, perLine))
    else
      ui.previewCaption:SetText(string.format("Party preview " .. PREVIEW_SEPARATOR .. " %d units", n))
    end
  end
  local borderColor = colors.border or {0.05, 0.08, 0.10, 1}
  for i = 1, n do
    local sq = ui.previewSquares[i]
    local state = PREVIEW_STATES[(i - 1) % #PREVIEW_STATES + 1]
    local red, green, blue, alpha = PreviewStateColor(pack, state)
    sq.fill:SetColorTexture(red, green, blue, shown and alpha or 0.22)
    sq.border:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], shown and 1 or 0.22)
    sq:SetSize(draw, draw)
    sq.fill:ClearAllPoints()
    sq.fill:SetPoint("CENTER")
    local inset = math.max(1, math.min(2, draw * 0.12))
    sq.fill:SetSize(math.max(1, draw - inset * 2), math.max(1, draw - inset * 2))
    sq:ClearAllPoints()
    local position = layout.positions[i]
    sq:SetPoint("BOTTOMLEFT", ui.previewHost, "BOTTOMLEFT", geometry.originX + position.x * previewScale, geometry.originY + position.y * previewScale)
    local lightSize, lightGap = ns.GetMUFStatusLightMetrics(size, pack.mufs.statusLight)
    if lightSize > 0 then
      sq.light:SetSize(math.max(1, lightSize * previewScale), math.max(1, lightSize * previewScale))
      sq.light:ClearAllPoints()
      sq.light:SetPoint("BOTTOM", sq, "TOP", 0, lightGap * previewScale)
      sq.light:Show()
    else
      sq.light:Hide()
    end
    sq:Show()
  end
  for i = n + 1, #ui.previewSquares do
    ui.previewSquares[i]:Hide()
  end
  ui.previewVisibleCount = n
  if ui.previewHandle then
    local hw = math.max(4, draw)
    ui.previewHandle:SetSize(hw, hw)
    ui.previewHandle.fill:SetSize(math.max(4, hw - 4), math.max(4, hw - 4))
    ui.previewHandle:ClearAllPoints()
    if pack.mufs.growUp then
      ui.previewHandle:SetPoint("TOP", ui.previewSquares[1], "BOTTOM", 0, 0)
    else
      ui.previewHandle:SetPoint("BOTTOM", ui.previewSquares[1], "TOP", 0, 0)
    end
    ui.previewHandle:SetShown(pack.mufs.hideHandle ~= true)
  end
end

ui.RefreshPreview = RefreshPreview
ui.TeardownMUFPreview = TeardownMUFPreview

local function BuildMufPreview(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Paint(host, {0.05, 0.09, 0.12, 1}, BORDER)
  host:SetHeight(PREVIEW_CAPTION_HEIGHT + PREVIEW_PADDING * 2 + PREVIEW_PARTY_MIN_CONTENT_HEIGHT)
  host:EnableMouse(false)
  local caption = Font(host, "GameFontDisable", "Party preview " .. PREVIEW_SEPARATOR .. " 5 units")
  caption:SetPoint("TOPLEFT", 14, -8)
  caption:SetPoint("TOPRIGHT", -14, -8)
  caption:SetWordWrap(false)
  caption:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  ui.previewCaption = caption
  ui.previewHost = host
  ui.previewSquares = {}
  for i = 1, PREVIEW_MAX_UNITS do
    local sq = CreateFrame("Frame", nil, host)
    sq:EnableMouse(false)
    sq.border = sq:CreateTexture(nil, "BACKGROUND")
    sq.border:SetAllPoints()
    sq.fill = sq:CreateTexture(nil, "ARTWORK")
    sq.light = sq:CreateTexture(nil, "OVERLAY")
    sq.light:SetColorTexture(0.20, 1, 0.35, 1)
    sq:Hide()
    ui.previewSquares[i] = sq
  end
  local handle = CreateFrame("Frame", nil, host)
  handle:EnableMouse(false)
  handle:SetSize(20, 20)
  handle.border = handle:CreateTexture(nil, "BACKGROUND")
  handle.border:SetAllPoints()
  handle.border:SetColorTexture(0.05, 0.08, 0.10, 1)
  handle.fill = handle:CreateTexture(nil, "ARTWORK")
  handle.fill:SetPoint("CENTER")
  handle.fill:SetSize(16, 16)
  handle.fill:SetColorTexture(0.12, 0.16, 0.18, 1)
  ui.previewHandle = handle
end


local function RefreshListPanel()
  if ui.prioText and ns.ListSummary then
    ui.prioText:SetText(ns.ListSummary("priority"))
  end
  if ui.skipText and ns.ListSummary then
    ui.skipText:SetText(ns.ListSummary("skip"))
  end
end

ns.RefreshListPanel = RefreshListPanel

local function MakeListColumn(parent, which, title)
  local col = CreateFrame("Frame", nil, parent)
  local head = Font(col, "GameFontNormal", title)
  head:SetPoint("TOPLEFT", 8, -4)
  head:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local function Slash(cmd)
    return function()
      if ns.HandleListSlash then
        ns.HandleListSlash(which, cmd)
      end
      RefreshListPanel()
    end
  end
  local addBtn = MakeButton(col, "Add target", 92, "gold")
  addBtn:SetPoint("TOPLEFT", 8, -28)
  addBtn:SetScript("OnClick", Slash("add"))
  local remBtn = MakeButton(col, "Remove target", 110)
  remBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
  remBtn:SetScript("OnClick", Slash("remove"))
  local clearBtn = MakeButton(col, "Clear", 64, "danger")
  clearBtn:SetPoint("LEFT", remBtn, "RIGHT", 6, 0)
  clearBtn:SetScript("OnClick", Slash("clear"))
  local body = Font(col, "GameFontHighlight", "(empty)")
  body:SetPoint("TOPLEFT", 8, -64)
  body:SetPoint("TOPRIGHT", -8, -64)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetHeight(88)
  body:SetWordWrap(true)
  body:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  return col, body
end

local function BuildListsPanel(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Paint(host, {0.05, 0.09, 0.12, 1}, BORDER)
  host:SetHeight(220)
  local caption = Font(host, "GameFontDisable", "Skip list units are never shown. Priority order applies when MUF order is Decursive priority. Lists are per profile, not per environment.")
  caption:SetPoint("TOPLEFT", 14, -8)
  caption:SetPoint("TOPRIGHT", -14, -8)
  caption:SetJustifyH("LEFT")
  caption:SetHeight(28)
  caption:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  local left, prioText = MakeListColumn(host, "priority", "Priority list")
  left:SetPoint("TOPLEFT", 8, -40)
  left:SetPoint("BOTTOMRIGHT", host, "BOTTOM", -4, 8)
  local right, skipText = MakeListColumn(host, "skip", "Skip list")
  right:SetPoint("TOPLEFT", host, "TOP", 4, -40)
  right:SetPoint("BOTTOMRIGHT", -8, 8)
  ui.listsHost = host
  ui.prioText = prioText
  ui.skipText = skipText
end

LayoutCatalog = function()
  if not ui.sections then
    return
  end
  ui.layoutCatalogActive = true
  for page, sections in pairs(ui.sections) do
    local y = 0
    local child = ui.pageChildren and ui.pageChildren[page]
    if page == "mufs" and ui.previewHost then
      if MUFPreviewActive() then
        ui.previewHost:ClearAllPoints()
        ui.previewHost:SetPoint("TOPLEFT", 0, 0)
        ui.previewHost:SetPoint("TOPRIGHT", 0, 0)
        ui.previewHost:Show()
        RefreshPreview()
        y = -((ui.previewHeight or ui.previewHost:GetHeight()) + 8)
      else
        ui.previewHost:Hide()
        TeardownMUFPreview()
      end
    end
    for _, section in ipairs(sections) do
      local visibleRows = {}
      for _, item in ipairs(section.rows) do
        if RowVisible(item.spec) then
          visibleRows[#visibleRows + 1] = item
        else
          item.row:Hide()
        end
      end
      if #visibleRows == 0 then
        section.header:Hide()
      else
        section.header:Show()
        section.header:ClearAllPoints()
        section.header:SetPoint("TOPLEFT", 0, y)
        section.header:SetPoint("TOPRIGHT", 0, y)
        local collapsed = IsCollapsed(page, section.group)
        local mark = collapsed and "+" or "-"
        section.header.label:SetText(mark .. "  " .. section.group)
        y = y - 32
        if collapsed then
          for _, item in ipairs(visibleRows) do
            item.row:Hide()
          end
        else
          for _, item in ipairs(visibleRows) do
            item.row:Show()
            item.row:ClearAllPoints()
            item.row:SetPoint("TOPLEFT", 12, y)
            item.row:SetPoint("TOPRIGHT", -12, y)
            y = y - 40
          end
        end
      end
    end
    if page == "sorting" and ui.listsHost then
      ui.listsHost:ClearAllPoints()
      ui.listsHost:SetPoint("TOPLEFT", 0, y - 8)
      ui.listsHost:SetPoint("TOPRIGHT", 0, y - 8)
      ui.listsHost:SetHeight(220)
      ui.listsHost:Show()
      y = y - 236
      RefreshListPanel()
    end
    local hint = ui.pageHints and ui.pageHints[page]
    if hint then
      if ui.simple then
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", 16, y - 8)
        hint:SetPoint("TOPRIGHT", -16, y - 8)
        hint:SetText("Click Simple (top right) to show all options for this environment.")
        hint:Show()
        y = y - 28
      else
        hint:Hide()
      end
    end
    if child then
      child:SetHeight(math.max(80, -y + 16))
    end
  end
  if ui.simpleBtn then
    if ui.simple then
      ui.simpleBtn:SetText("Simple")
    else
      ui.simpleBtn:SetText("All")
    end
  end
  ui.layoutCatalogActive = false
end

local function Refresh()
  if OptionsCombatReadOnly() then
    if ns.CloseOptionsForCombat then
      ns.CloseOptionsForCombat("OPTIONS_REFRESH")
    end
    return false
  end
  if not ui.frame then
    return false
  end
  local addon = Addon()
  local statusOK, profileStatus = pcall(addon.GetUIProfileStatus, addon)
  local environmentOK, environmentStatus = pcall(addon.GetEnvironmentProfileStatus, addon)
  if not statusOK or type(profileStatus) ~= "table" or not profileStatus.available then
    local reason = statusOK and profileStatus and profileStatus.blockedReason or "core-unavailable"
    ui.profileValue:SetText("Unavailable")
    ui.resolved:SetText("Active profile: unavailable (" .. tostring(reason) .. ")")
    ui.resolved:SetTextColor(DANGER[1], DANGER[2], DANGER[3])
    ui.envHint:SetText("Profile storage unavailable")
    if ui.profileActive then
      ui.profileActive:SetText("Active profile: unavailable")
      ui.profilePending:SetText("Pending after combat: none")
      ui.profileSource:SetText("Resolved source: unavailable")
    end
    if ui.environmentApplied then
      ui.environmentApplied:SetText("Applied: Unknown")
      ui.environmentEditing:SetText("Editing: Unknown")
      ui.environmentDetected:SetText("Detected: Unknown")
      ui.environmentPending:SetText("")
    end
    if RefreshStatusPage then
      RefreshStatusPage(profileStatus, environmentStatus)
    end
    LayoutCatalog()
    return
  end
  addon:EnsureEnvironments()
  local profile = profileStatus.actualProfile
  local env = addon:GetEditingEnvironment()
  local appliedEnvironment = environmentOK and type(environmentStatus) == "table" and environmentStatus.appliedEnvironment or "unknown"
  local detectedEnvironment = environmentOK and type(environmentStatus) == "table" and environmentStatus.detectedEnvironment or "unknown"
  local pendingEnvironment = environmentOK and type(environmentStatus) == "table" and environmentStatus.pendingEnvironment or nil
  local environmentMode = environmentOK and type(environmentStatus) == "table" and environmentStatus.environmentMode or "multiple"
  local appliedLabel = ns.ENV_LABELS[appliedEnvironment] or "Unknown"
  local detectedLabel = ns.ENV_LABELS[detectedEnvironment] or "Unknown"
  local editingLabel = ns.ENV_LABELS[env] or "Unknown"
  ui.profileValue:SetText(profile)
  ui.resolved:SetText("Active profile: " .. profile)
  ui.resolved:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  ui.envHint:SetText("Editing " .. (ns.ENV_LABELS[env] or env) .. " inside " .. profile)
  if ui.environmentApplied then
    ui.environmentApplied:SetText("Applied: " .. appliedLabel)
    ui.environmentEditing:SetText("Editing: " .. editingLabel)
    ui.environmentDetected:SetText("Detected: " .. detectedLabel)
    if pendingEnvironment then
      ui.environmentPending:SetText("Pending after combat: " .. (ns.ENV_LABELS[pendingEnvironment] or "Unknown"))
    else
      ui.environmentPending:SetText("")
    end
  end
  if ui.routingMultiple then
    ui.routingMultiple:SetText(environmentMode == "multiple" and "Multiple (active)" or "Multiple")
    ui.routingSolo:SetText(environmentMode == "solo" and "Solo (active)" or "Solo")
    ui.routingMultiple:SetInteractionEnabled(true)
    ui.routingSolo:SetInteractionEnabled(true)
  end
  if ui.profileActive then
    ui.profileActive:SetText("Active profile: " .. profile)
    ui.profilePending:SetText("Pending after combat: " .. (profileStatus.pendingProfile or "none"))
    ui.profileSource:SetText("Resolved source: " .. profileStatus.resolvedTier .. " -> " .. profileStatus.resolvedProfile)
  end
  if RefreshStatusPage then
    RefreshStatusPage(profileStatus, environmentStatus)
  end

  local chipX = 0
  for _, row in ipairs(ns.ENVIRONMENTS) do
    local key = row.key
    local chip = ui.envChips[key]
    local visible = (environmentMode == "solo" and key == "SOLO")
      or (environmentMode == "multiple" and ns.MULTIPLE_ENV_SET[key] == true)
    chip:SetShown(visible)
    chip:ClearAllPoints()
    if visible then
      chip:SetPoint("TOPLEFT", chipX, -24)
      chipX = chipX + 126
    end
    chip:SetText(ns.ENV_LABELS[key] or key)
    if key == env then
      Paint(chip, {0.07, 0.22, 0.24, 1}, GOLD)
      chip.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      Paint(chip, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      chip.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    end
  end
  if ui.envCopyBtn then
    ui.envCopyBtn:SetShown(environmentMode == "multiple")
  end

  local navY = ui.environmentNavStartY or -84
  for _, row in ipairs(ns.ENVIRONMENTS) do
    local button = ui.navButtons and ui.navButtons["environment:" .. row.key]
    local visible = (environmentMode == "solo" and row.key == "SOLO")
      or (environmentMode == "multiple" and ns.MULTIPLE_ENV_SET[row.key] == true)
    if button then
      button:SetShown(visible)
      button:ClearAllPoints()
      if visible then
        button:SetPoint("TOPLEFT", 20, navY)
        navY = navY - 34
      end
    end
  end
  if ui.addonProfilesNav then
    ui.addonProfilesNav:ClearAllPoints()
    ui.addonProfilesNav:SetPoint("TOPLEFT", 12, navY - 10)
  end
  if ui.diagnosticsNav then
    ui.diagnosticsNav:ClearAllPoints()
    ui.diagnosticsNav:SetPoint("TOPLEFT", 12, navY - 44)
  end

  local searching = ui.search and ui.search ~= ""
  for key, tab in pairs(ui.tabs) do
    local active = (not searching and key == ui.tab) or (searching and key == "search")
    if searching then
      active = key == "search"
    else
      active = key == ui.tab
    end
    if active then
      Paint(tab, {0.06, 0.20, 0.22, 1}, GOLD)
      tab.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      Paint(tab, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      tab.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
  end

  local destination = searching and "search" or ui.destination
  LayoutWorkspace(destination)
  if ui.profileBar then
    ui.profileBar:SetShown(destination == "addon_profiles")
  end
  if ui.envBar then
    ui.envBar:SetShown(destination == "environment")
  end
  if ui.tabBar then
    ui.tabBar:SetShown(destination == "environment")
  end
  if ui.simpleBtn then
    ui.simpleBtn:SetShown(destination == "environment")
  end
  if ui.body then
    ui.body:SetShown(destination ~= "status" and destination ~= "diagnostics")
  end
  if ui.statusPage then
    ui.statusPage:SetShown(destination == "status")
  end
  if ui.diagnosticsPage then
    ui.diagnosticsPage:SetShown(destination == "diagnostics")
    if destination == "diagnostics" and RefreshDiagnosticsPage then
      RefreshDiagnosticsPage()
    end
  end
  for key, page in pairs(ui.pages) do
    if destination == "search" then
      page:SetShown(key == "search")
    elseif destination == "addon_profiles" then
      page:SetShown(key == "assign")
    elseif destination == "environment" then
      page:SetShown(key == ui.tab and key ~= "assign")
    else
      page:Hide()
    end
  end
  for key, button in pairs(ui.navButtons or {}) do
    local active = key == destination
    if key:find("environment:", 1, true) == 1 then
      local environment = key:sub(13)
      active = destination == "environment" and environment == env
    end
    if active then
      Paint(button, {0.06, 0.20, 0.22, 1}, GOLD)
      button.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      Paint(button, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      button.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
  end

  for _, bind in ipairs(ui.binds) do
    if bind.kind == "toggle" then
      bind.widget:SetOn(bind.get())
    elseif bind.kind == "slider" then
      bind.widget:SetNumber(bind.get())
      if bind.label == "Vertical spacing" and bind.widget.SetEnabled then
        bind.widget:SetEnabled(not Pack().mufs.linkSpacing)
      end
    elseif bind.kind == "choice" then
      local v = bind.get()
      bind.widget:SetText(bind.values[v] or tostring(v))
    elseif bind.kind == "color" then
      bind.widget:SetColor(bind.get())
    elseif bind.kind == "text" then
      if bind.label == "Custom macro" then
        local advanced = Pack().advanced
        if type(advanced) ~= "table" or advanced.allowMacroEdit ~= true then
          bind.widget:SetText("locked")
        else
          bind.widget:SetText(MacroPreview(bind.get()))
        end
      elseif bind.get then
        bind.widget:SetText(MacroPreview(bind.get() or ""))
      end
    end
  end

  if searching then
    local y = -16
    local n = 0
    for _, row in ipairs(ui.searchRows) do
      row:Hide()
    end
    for i, spec in ipairs(CATALOG) do
      if MatchesSearch(spec.label) or MatchesSearch(PAGE_LABELS[spec.page] or "") then
        n = n + 1
        local row = ui.searchRows[n]
        if row then
          row.searchSpec = spec
          row.label:SetText((PAGE_LABELS[spec.page] or spec.page) .. " - " .. spec.label)
          row:SetPoint("TOPLEFT", 16, y)
          row:Show()
          y = y - 36
        end
      end
    end
    ui.searchCount:SetText(n .. " matches")
  end

  local key = addon:GetCharacterKey()
  ui.assign.account:SetText(addon.db.global.accountProfile or "Default")
  local charProfile = key and addon.db.global.characters[key]
  ui.assign.character:SetText(charProfile or "Use account / Default")
  if addon.EnsureSpecAssignments then
    addon:EnsureSpecAssignments()
  end
  local currentSpec = addon.GetSpecIndex and addon:GetSpecIndex()
  local specCount = 4
  if addon.SpecSlotCount then
    specCount = addon:SpecSlotCount()
  end
  for spec = 1, 4 do
    local slot = ui.assign.specs and ui.assign.specs[spec]
    if slot then
      if spec <= specCount then
        slot.row:Show()
        local specName = addon:GetSpecName(spec) or ("Spec " .. spec)
        local tag = "Dormant spec"
        if spec == currentSpec then
          tag = "This spec"
        end
        slot.label:SetText(tag .. " (" .. specName .. ")")
        local specRow = addon:GetSpecAssignment(spec)
        slot.enabled:SetOn(specRow and specRow.enabled)
        slot.profile:SetText((specRow and specRow.profile) or "Default")
      else
        slot.row:Hide()
      end
    end
  end
  LayoutCatalog()
  RefreshPreview()
  RefreshListPanel()
  return true
end

ns.RefreshOptions = function()
  if OptionsCombatReadOnly() then
    return false
  end
  Refresh()
  return true
end

local PROFILE_ERRORS = {
  combat = "Profile and environment structure cannot change during combat.",
  profile = "That profile is unavailable.",
  ["invalid-name"] = "Use a unique profile name of 1 to 48 bytes without control characters.",
  exists = "A profile with that name already exists.",
  ["profile-limit"] = "The 50-profile limit has been reached.",
  default = "The Default profile cannot be renamed or deleted.",
  env = "That environment is unavailable.",
  same = "Choose a different destination environment.",
  ["forward-schema"] = "Settings were created by a newer schema; profile changes are disabled.",
  ["unsupported-schema"] = "This settings schema is not supported by the current build.",
  ["malformed-schema"] = "The settings schema marker is malformed; profile changes are disabled.",
  ["malformed-storage"] = "Profile assignment storage is malformed; no change was made.",
  storage = "Profile storage is unavailable; no change was made.",
  transaction = "The profile change failed and was rolled back.",
}

ReportProfileAction = function(ok, state, successText)
  Refresh()
  if not ui.profileAction then
    return ok, state
  end
  if ok then
    ui.profileAction:SetText(successText or "Profile change applied.")
    ui.profileAction:SetTextColor(0.35, 1, 0.55)
  else
    ui.profileAction:SetText(PROFILE_ERRORS[state] or "No profile change was made.")
    ui.profileAction:SetTextColor(DANGER[1], DANGER[2], DANGER[3])
  end
  return ok, state
end

function ns.IsOptionsShown()
  return ui.frame and ui.frame:IsShown()
end

local function BindRow(parent, y, spec)
  local row = MakeRow(parent, y, spec.label)
  if type(spec.description) == "string" and spec.description ~= "" then
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(spec.label)
      GameTooltip:AddLine(spec.description, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  local widget
  if spec.kind == "toggle" then
    widget = MakeToggle(row)
    widget:SetPoint("RIGHT", -12, 0)
    widget.OnValueChanged = function(_, on)
      spec.set(on)
    end
  elseif spec.kind == "slider" then
    widget = MakeSlider(row, spec.min, spec.max, spec.step)
    widget:SetPoint("RIGHT", -12, 0)
    widget.OnValueChanged = function(_, v)
      spec.set(v)
    end
  elseif spec.kind == "choice" then
    widget = MakeButton(row, "", 200)
    widget:SetPoint("RIGHT", -12, 0)
    widget:SetScript("OnClick", function(self)
      OpenChoiceMenu(self, spec.values, spec.get, spec.set)
    end)
  elseif spec.kind == "color" then
    widget = MakeColorSwatch(row, spec.hasOpacity)
    widget:SetPoint("RIGHT", -16, 0)
    widget.OnValueChanged = function(_, c)
      spec.set(c)
    end
  elseif spec.kind == "text" then
    widget = MakeButton(row, "empty", 220)
    widget:SetPoint("RIGHT", -12, 0)
    widget:SetScript("OnClick", function()
      if spec.label == "Custom macro" then
        local advanced = Pack().advanced
        if type(advanced) ~= "table" or advanced.allowMacroEdit ~= true then
          return
        end
      end
      ShowModal(spec.label, spec.get() or "", spec.set)
    end)
  elseif spec.kind == "button" then
    widget = MakeButton(row, spec.buttonLabel or "Test", 88, "gold")
    widget:SetPoint("RIGHT", -12, 0)
    widget:SetScript("OnClick", function()
      if spec.run then
        spec.run()
      end
    end)
  end
  ui.binds[#ui.binds + 1] = {kind = spec.kind, widget = widget, get = spec.get, set = spec.set, values = spec.values, label = spec.label}
  return row
end

local function MakeScrollPage(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetAllPoints()
  local child = CreateFrame("Frame", nil, scroll)
  child:SetWidth(parent:GetWidth() > 0 and parent:GetWidth() or 820)
  child:SetHeight(40)
  scroll:SetScrollChild(child)
  ui.scrollChildren[#ui.scrollChildren + 1] = child
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = math.max(0, child:GetHeight() - self:GetHeight())
    local pos = self:GetVerticalScroll() - delta * 40
    if pos < 0 then
      pos = 0
    end
    if pos > range then
      pos = range
    end
    self:SetVerticalScroll(pos)
  end)
  return child
end

local function SpellIconMarkup(spellId)
  if type(spellId) ~= "number" or (ns.IsAccessible and not ns.IsAccessible(spellId)) then
    return ""
  end
  local icon
  if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
    local ok, value = pcall(C_Spell.GetSpellTexture, spellId)
    if ok and (type(value) == "number" or type(value) == "string") and (not ns.IsAccessible or ns.IsAccessible(value)) then
      icon = value
    end
  end
  if not icon and C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if ok and type(info) == "table" then
      local value = info.iconID
      if (type(value) == "number" or type(value) == "string") and (not ns.IsAccessible or ns.IsAccessible(value)) then
        icon = value
      end
    end
  end
  if not icon then
    return ""
  end
  return "|T" .. tostring(icon) .. ":16:16:0:0|t "
end

local function BuildStatusPage(parent)
  local wrap = CreateFrame("Frame", nil, parent)
  wrap:SetAllPoints()
  local child = MakeScrollPage(wrap)
  child:SetHeight(680)

  local current = MakeCard(child, "Current setup")
  current:SetPoint("TOPLEFT", 0, 0)
  current:SetPoint("TOPRIGHT", 0, 0)
  current:SetHeight(168)
  ui.statusCurrent = Font(current, "GameFontHighlight", "Loading current setup...")
  ui.statusCurrent:SetPoint("TOPLEFT", 16, -42)
  ui.statusCurrent:SetPoint("RIGHT", -16, 0)
  ui.statusCurrent:SetJustifyH("LEFT")
  ui.statusCurrent:SetJustifyV("TOP")

  local capability = MakeCard(child, "Dispel capability")
  capability:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -10)
  capability:SetPoint("TOPRIGHT", current, "BOTTOMRIGHT", 0, -10)
  capability:SetHeight(130)
  ui.statusCapability = Font(capability, "GameFontHighlight", "Unknown")
  ui.statusCapability:SetPoint("TOPLEFT", 16, -42)
  ui.statusCapability:SetPoint("RIGHT", -16, 0)
  ui.statusCapability:SetJustifyH("LEFT")
  ui.statusCapability:SetJustifyV("TOP")

  local mappings = MakeCard(child, "Click mappings")
  mappings:SetPoint("TOPLEFT", capability, "BOTTOMLEFT", 0, -10)
  mappings:SetPoint("TOPRIGHT", capability, "BOTTOMRIGHT", 0, -10)
  mappings:SetHeight(166)
  ui.statusMappings = Font(mappings, "GameFontHighlight", "Unknown")
  ui.statusMappings:SetPoint("TOPLEFT", 16, -42)
  ui.statusMappings:SetPoint("RIGHT", -16, 0)
  ui.statusMappings:SetJustifyH("LEFT")
  ui.statusMappings:SetJustifyV("TOP")

  local quick = MakeCard(child, "Quick bindings")
  quick:SetPoint("TOPLEFT", mappings, "BOTTOMLEFT", 0, -10)
  quick:SetPoint("TOPRIGHT", mappings, "BOTTOMRIGHT", 0, -10)
  quick:SetHeight(132)
  local quickHint = Font(quick, "GameFontDisable", "Changes the editing Environment Profile. Read-only in combat.")
  quickHint:SetPoint("TOPLEFT", 16, -40)
  quickHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  ui.quickBindingButtons = {}
  local quickSpecs = {
    {label = "AUTO", run = function() SetClickMode("AUTO") end},
    {label = "MANUAL", run = function() SetClickMode("MANUAL") end},
    {label = "Left: cure", run = SetMouseAction("left")},
    {label = "Right: cure", run = SetMouseAction("right")},
    {label = "Button 4: cure", run = SetMouseAction("button4")},
    {label = "Button 5: cure", run = SetMouseAction("button5")},
  }
  local previous
  for i = 1, #quickSpecs do
    local spec = quickSpecs[i]
    local modeButton = i <= 2
    local button = MakeButton(quick, spec.label, i <= 2 and 78 or 112, i == 1 and "gold" or nil)
    button:SetPoint("TOP", 0, -68)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
      button:SetPoint("LEFT", 16, 0)
    end
    button:SetScript("OnClick", function()
      if OptionsCombatReadOnly() then
        return
      end
      if modeButton then
        spec.run()
      else
        spec.run("CURE")
      end
      Refresh()
    end)
    ui.quickBindingButtons[#ui.quickBindingButtons + 1] = button
    previous = button
  end
  local openCure = MakeButton(quick, "Open full Cure settings", 178)
  openCure:SetPoint("TOPLEFT", 16, -102)
  openCure:SetScript("OnClick", function()
    ui.tab = "cure"
    SetDestination("environment")
  end)
  ui.statusCureShortcut = openCure
  ui.statusPage = wrap
end

RefreshStatusPage = function(profileStatus, environmentStatus)
  if not ui.statusPage then
    return
  end
  local addon = Addon()
  local combatReadOnly = OptionsCombatReadOnly()
  local appliedEnvironment = environmentStatus and environmentStatus.appliedEnvironment or "unknown"
  local editingEnvironment = addon and addon.GetEditingEnvironment and addon:GetEditingEnvironment() or "unknown"
  local pendingEnvironment = environmentStatus and environmentStatus.pendingEnvironment
  local detectedEnvironment = environmentStatus and environmentStatus.detectedEnvironment or "unknown"
  local environmentMode = environmentStatus and environmentStatus.environmentMode or "multiple"
  local specName = addon and addon.GetSpecName and addon:GetSpecName() or nil
  local currentLines = {
    "Decursive Profile: " .. tostring(profileStatus and profileStatus.actualProfile or "Unknown"),
    "Mode: " .. (environmentMode == "solo" and "Solo" or "Multiple"),
    "Detected Environment: " .. tostring(ns.ENV_LABELS[detectedEnvironment] or "Unknown"),
    "Applied Environment Profile: " .. tostring(ns.ENV_LABELS[appliedEnvironment] or "Unknown"),
    "Editing Environment Profile: " .. tostring(ns.ENV_LABELS[editingEnvironment] or "Unknown"),
    "Pending after combat: " .. tostring(pendingEnvironment and (ns.ENV_LABELS[pendingEnvironment] or "Unknown") or "None"),
    "Specialization: " .. tostring(specName or "Unknown") .. "   Options: " .. (combatReadOnly and "Read-only (combat)" or "Writable"),
  }
  ui.statusCurrent:SetText(table.concat(currentLines, "\n"))

  local appliedPack = addon and addon.GetAppliedEnvironmentPack and addon:GetAppliedEnvironmentPack() or nil
  local actions = ns.GetKnownCures and ns.GetKnownCures(appliedPack) or nil
  local capabilityLines = {}
  if type(actions) ~= "table" then
    capabilityLines[1] = "Unknown - authoritative cure model is unavailable."
  elseif #actions == 0 then
    capabilityLines[1] = "No known public cure spell is available for the current setup."
  else
    for i = 1, math.min(#actions, 4) do
      local action = actions[i]
      local name = type(action) == "table" and action.name or nil
      local types = type(action) == "table" and action.types or nil
      local categories = type(types) == "table" and table.concat(types, "/") or "unknown"
      capabilityLines[#capabilityLines + 1] = SpellIconMarkup(action and action.spellId) .. tostring(name or "Unknown") .. "  [" .. categories .. "]"
    end
    if #actions > 4 then
      capabilityLines[#capabilityLines + 1] = "+ " .. tostring(#actions - 4) .. " more known action(s)"
    end
  end
  ui.statusCapability:SetText(table.concat(capabilityLines, "\n"))

  local clickStatus = ns.GetResolvedClickStatus and ns.GetResolvedClickStatus() or nil
  local mappingLines = {"Mode: " .. tostring(clickStatus and clickStatus.mode or "Unknown")}
  if clickStatus and clickStatus.pending then
    mappingLines[#mappingLines + 1] = "Secure update: pending after combat"
  end
  local mappings = clickStatus and clickStatus.mappings
  if type(mappings) == "table" and #mappings > 0 then
    for i = 1, math.min(#mappings, 6) do
      local row = mappings[i]
      mappingLines[#mappingLines + 1] = tostring(row.gesture or "Unknown") .. ": " .. SpellIconMarkup(row.spellId) .. tostring(row.action or "Unknown")
    end
    if #mappings > 6 then
      mappingLines[#mappingLines + 1] = "+ " .. tostring(#mappings - 6) .. " more resolved mapping(s)"
    end
  else
    mappingLines[#mappingLines + 1] = "Resolved mappings: Unknown"
  end
  ui.statusMappings:SetText(table.concat(mappingLines, "\n"))
  for i = 1, #(ui.quickBindingButtons or {}) do
    ui.quickBindingButtons[i]:SetInteractionEnabled(not combatReadOnly)
  end
end

local function LayoutScrollChildren()
  if not ui.body then
    return
  end
  local inner = ui.body:GetWidth()
  if not inner or inner < 200 then
    inner = 1040
  end
  for _, child in ipairs(ui.scrollChildren or {}) do
    child:SetWidth(inner)
  end
end

local function SaveFrameSize()
  local addon = Addon()
  if not addon or not addon.db or not ui.frame then
    return
  end
  addon.db.char.optionsWidth = math.floor(ui.frame:GetWidth() + 0.5)
  addon.db.char.optionsHeight = math.floor(ui.frame:GetHeight() + 0.5)
end

local function ApplySavedSize(f)
  local addon = Addon()
  local w = 1100
  local h = 780
  if addon and addon.db and addon.db.char then
    w = addon.db.char.optionsWidth or w
    h = addon.db.char.optionsHeight or h
  end
  if w <= 920 and h <= 660 then
    w = 1100
    h = 780
  end
  if w < 1100 then
    w = 1100
  end
  if h < 580 then
    h = 580
  end
  f:SetSize(w, h)
end

local function BuildPages(content)
  ui.pages = {}
  ui.binds = {}
  ui.assign = {}
  ui.searchRows = {}
  ui.scrollChildren = {}

  ui.sections = {}
  ui.pageChildren = {}
  ui.pageHints = {}
  for _, pageKey in ipairs(PAGES) do
    local wrap = CreateFrame("Frame", nil, content)
    wrap:SetAllPoints()
    local child = MakeScrollPage(wrap)
    ui.pageChildren[pageKey] = child
    ui.pages[pageKey] = wrap
    if pageKey == "assign" then
      ui.sections[pageKey] = {}
    else
      local grouped = {}
      local order = GROUP_ORDER[pageKey] or {}
      for _, spec in ipairs(CATALOG) do
        if spec.page == pageKey then
          local g = spec.group or "More"
          if not grouped[g] then
            grouped[g] = {}
          end
          grouped[g][#grouped[g] + 1] = spec
        end
      end
      local sections = {}
      for _, groupName in ipairs(order) do
        local specs = grouped[groupName]
        if specs then
          local header = CreateFrame("Button", nil, child, "BackdropTemplate")
          header:SetHeight(28)
          Paint(header, {0.07, 0.11, 0.14, 1}, BORDER)
          local hl = Font(header, "GameFontNormal", groupName)
          hl:SetPoint("LEFT", 12, 0)
          hl:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
          header.label = hl
          header.group = groupName
          header.page = pageKey
          header:SetScript("OnClick", function(self)
            if ui.simple then
              return
            end
            ui.collapsed[self.page] = ui.collapsed[self.page] or {}
            local now = IsCollapsed(self.page, self.group)
            ui.collapsed[self.page][self.group] = not now
            LayoutCatalog()
          end)
          local rows = {}
          for _, spec in ipairs(specs) do
            local row = BindRow(child, -40, spec)
            rows[#rows + 1] = {row = row, spec = spec}
          end
          sections[#sections + 1] = {group = groupName, header = header, rows = rows}
        end
      end
      ui.sections[pageKey] = sections
      if pageKey == "mufs" then
        BuildMufPreview(child)
      end
      if pageKey == "sorting" then
        BuildListsPanel(child)
      end
      local hint = Font(child, "GameFontHighlight", "Click Simple (top right) to show all options for this environment.")
      hint:SetJustifyH("LEFT")
      hint:SetHeight(18)
      hint:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
      hint:Hide()
      ui.pageHints[pageKey] = hint
    end
  end

  local assignWrap = ui.pages.assign
  local assignChild = assignWrap:GetChildren()
  -- rebuild assign as custom assignment controls on top of empty catalog
  local asCard = MakeCard(assignWrap, "Decursive Profiles and assignments")
  asCard:SetAllPoints()
  ui.profileActive = Font(asCard, "GameFontHighlightLarge", "Active profile: unavailable")
  ui.profileActive:SetPoint("TOPLEFT", 16, -42)
  ui.profileActive:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  ui.profilePending = Font(asCard, "GameFontHighlight", "Pending after combat: none")
  ui.profilePending:SetPoint("TOPLEFT", 16, -64)
  ui.profilePending:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  ui.profileSource = Font(asCard, "GameFontHighlight", "Resolved source: unavailable")
  ui.profileSource:SetPoint("TOPLEFT", 16, -84)
  ui.profileSource:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  ui.profileAction = Font(asCard, "GameFontHighlight", "")
  ui.profileAction:SetPoint("TOPRIGHT", -16, -64)
  ui.profileAction:SetWidth(360)
  ui.profileAction:SetJustifyH("RIGHT")
  local asHint = Font(asCard, "GameFontDisable", "Resolver: spec (if enabled and mapped), then this character, then account, then Default.")
  asHint:SetPoint("TOPLEFT", 16, -108)
  asHint:SetWidth(760)
  asHint:SetJustifyH("LEFT")
  asHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  local rowAccount = MakeRow(asCard, -140, "Account")
  ui.assign.account = MakeButton(rowAccount, "Default", 220)
  ui.assign.account:SetPoint("RIGHT", -12, 0)
  ui.assign.account:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      if name then
        local ok, state = Addon():SetAccountProfileAssignment(name)
        ReportProfileAction(ok, state, "Account assignment updated.")
      end
    end)
  end)
  local rowChar = MakeRow(asCard, -180, "This character")
  ui.assign.character = MakeButton(rowChar, "Use account / Default", 220)
  ui.assign.character:SetPoint("RIGHT", -12, 0)
  ui.assign.character:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      local ok, state = Addon():SetCharacterProfileAssignment(name)
      ReportProfileAction(ok, state, "Character assignment updated.")
    end, true)
  end)
  ui.assign.specs = {}
  for spec = 1, 4 do
    local y = -220 - (spec - 1) * 40
    local row = MakeRow(asCard, y, "Spec " .. spec)
    local enabled = MakeToggle(row)
    enabled:SetPoint("RIGHT", -12, 0)
    local profile = MakeButton(row, "Default", 180)
    profile:SetPoint("RIGHT", enabled, "LEFT", -8, 0)
    local captured = spec
    enabled.OnValueChanged = function(_, on)
      local ok, state = Addon():SetSpecProfileAssignmentEnabled(captured, on)
      ReportProfileAction(ok, state, "Specialization assignment updated.")
    end
    profile:SetScript("OnClick", function(self)
      OpenProfileMenu(self, function(name)
        if name then
          local ok, state = Addon():SetSpecProfileAssignment(captured, name)
          ReportProfileAction(ok, state, "Specialization profile updated.")
        end
      end)
    end)
    ui.assign.specs[spec] = {
      row = row,
      label = row.label,
      enabled = enabled,
      profile = profile,
    }
  end

  local searchWrap = CreateFrame("Frame", nil, content)
  searchWrap:SetAllPoints()
  local searchCard = MakeCard(searchWrap, "Search")
  searchCard:SetAllPoints()
  ui.searchCount = Font(searchCard, "GameFontDisable", "")
  ui.searchCount:SetPoint("TOPLEFT", 16, -44)
  ui.searchCount:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  for i = 1, #CATALOG do
    local row = MakeRow(searchCard, -80, "")
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(self)
      local spec = self.searchSpec
      if spec and spec.page and spec.page ~= "assign" then
        ui.tab = spec.page
        SetDestination("environment")
      end
    end)
    row:Hide()
    ui.searchRows[i] = row
  end
  ui.pages.search = searchWrap
end

local function SetTab(tab)
  if not OptionsAccessAllowed("TAB_NAVIGATION") then
    return false
  end
  TeardownMUFPreview()
  ui.tab = tab
  ui.destination = "environment"
  ui.search = ""
  if ui.searchBox then
    ui.searchBox:SetText("")
  end
  Refresh()
  return true
end

SetDestination = function(destination, environment)
  if not OptionsAccessAllowed("PAGE_NAVIGATION") then
    return false, "combat"
  end
  TeardownMUFPreview()
  if destination == "environment" and environment then
    local ok, state = Addon():SetEditingEnvironment(environment)
    if not ok then
      ReportProfileAction(ok, state, nil)
      return false, state
    end
  end
  if destination ~= "status" and destination ~= "environment" and destination ~= "addon_profiles" and destination ~= "diagnostics" then
    destination = "status"
  end
  ui.destination = destination
  ui.search = ""
  if ui.searchBox then
    ui.searchBox:SetText("")
  end
  Refresh()
  return true, destination
end

local function BuildDiagnosticsPage(parent)
  local wrap = CreateFrame("Frame", nil, parent)
  wrap:SetAllPoints()
  local card = MakeCard(wrap, "Persistent Diagnostics")
  card:SetAllPoints()
  local help = Font(card, "GameFontHighlight", "Critical roster and transition records are always retained in a bounded, privacy-conscious SavedVariable. Verbose monitoring is opt-in. No character names, GUIDs, profile names, or aura identifiers are recorded.")
  help:SetPoint("TOPLEFT", 16, -42)
  help:SetPoint("TOPRIGHT", -16, -42)
  help:SetJustifyH("LEFT")
  help:SetWordWrap(true)
  ui.diagnosticsStatus = Font(card, "GameFontHighlight", "Diagnostics unavailable")
  ui.diagnosticsStatus:SetPoint("TOPLEFT", 16, -104)
  ui.diagnosticsStatus:SetPoint("TOPRIGHT", -16, -104)
  ui.diagnosticsStatus:SetJustifyH("LEFT")

  local health = MakeButton(card, "Run Health Check", 150, "gold")
  health:SetPoint("TOPLEFT", 16, -176)
  health:SetScript("OnClick", function()
    if not OptionsAccessAllowed("DIAGNOSTICS_HEALTH") then
      return
    end
    if ns.Diagnostics and type(ns.Diagnostics.RunHealthCheck) == "function" then
      ns.Diagnostics.RunHealthCheck(true)
    end
    RefreshDiagnosticsPage()
  end)

  local start = MakeButton(card, "Start verbose", 120)
  start:SetPoint("TOPLEFT", 16, -212)
  start:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.SetVerbose(true)
      ns.PersistentDiagnostics.Record("MONITOR", {state = "STARTED"}, false)
    end
    RefreshDiagnosticsPage()
  end)
  local stop = MakeButton(card, "Stop verbose", 120)
  stop:SetPoint("LEFT", start, "RIGHT", 8, 0)
  stop:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.Record("MONITOR", {state = "STOPPED"}, false)
      ns.PersistentDiagnostics.SetVerbose(false)
    end
    RefreshDiagnosticsPage()
  end)
  local mark = MakeButton(card, "Mark", 90)
  mark:SetPoint("LEFT", stop, "RIGHT", 8, 0)
  mark:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.HandleCommand("mark")
    end
    RefreshDiagnosticsPage()
  end)
  local monitor = MakeButton(card, "Monitor snapshot", 140)
  monitor:SetPoint("LEFT", mark, "RIGHT", 8, 0)
  monitor:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.HandleCommand("monitor")
    end
    RefreshDiagnosticsPage()
  end)
  local export = MakeButton(card, "Copy/export", 110)
  export:SetPoint("LEFT", monitor, "RIGHT", 8, 0)
  export:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.HandleCommand("export")
    end
  end)
  local clear = MakeButton(card, "Clear", 90)
  clear:SetPoint("LEFT", export, "RIGHT", 8, 0)
  clear:SetScript("OnClick", function()
    if ns.PersistentDiagnostics then
      ns.PersistentDiagnostics.Clear()
    end
    RefreshDiagnosticsPage()
  end)
  local flush = Font(card, "GameFontDisable", "After reproducing the issue, run /zdiag mark and then /reload. WoW does not flush SavedVariables to disk continuously.")
  flush:SetPoint("TOPLEFT", 16, -260)
  flush:SetPoint("TOPRIGHT", -16, -260)
  flush:SetJustifyH("LEFT")
  flush:SetWordWrap(true)
  ui.diagnosticsPage = wrap
end

RefreshDiagnosticsPage = function()
  if not ui.diagnosticsStatus then
    return
  end
  local persistent = ns.PersistentDiagnostics
  local status = persistent and persistent.Status and persistent.Status() or nil
  if type(status) ~= "table" then
    ui.diagnosticsStatus:SetText("Persistent diagnostics are unavailable.")
    return
  end
  local health = ns.Diagnostics and ns.Diagnostics.GetLastHealthCheckSummary
    and ns.Diagnostics.GetLastHealthCheckSummary() or nil
  ui.diagnosticsStatus:SetText(table.concat({
    "Schema: " .. tostring(status.schema) .. "    Session: " .. tostring(status.session),
    "Verbose: " .. (status.verbose and "On" or "Off"),
    "Critical: " .. tostring(status.criticalEntries) .. " entries / " .. tostring(status.criticalBytes) .. " bytes",
    "Verbose: " .. tostring(status.verboseEntries) .. " entries / " .. tostring(status.verboseBytes) .. " bytes",
    "Last health: " .. (type(health) == "table" and tostring(health.verdict) or "Not run"),
  }, "\n"))
end

local function BuildFrame()
  if not OptionsAccessAllowed("FRAME_BUILD") then
    return nil
  end
  local f = CreateFrame("Frame", "DecursiveRebuildOptions", UIParent, "BackdropTemplate")
  f:Hide()
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  if f.SetResizeBounds then
    f:SetResizeBounds(1100, 580, 1800, 1400)
  else
    f:SetMinResize(1100, 580)
    f:SetMaxResize(1800, 1400)
  end
  ApplySavedSize(f)
  Paint(f, BG, BORDER)
  tinsert(UISpecialFrames, f:GetName())

  local accent = f:CreateTexture(nil, "BORDER")
  accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  accent:SetPoint("TOPLEFT", 1, -1)
  accent:SetPoint("TOPRIGHT", -1, -1)
  accent:SetHeight(2)

  local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 1, -3)
  header:SetPoint("TOPRIGHT", -1, -3)
  header:SetHeight(108)
  Paint(header, HEADER)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
  end)

  local title = Font(header, "GameFontHighlightLarge", "Zhaohu's Decursive")
  title:SetPoint("TOPLEFT", 22, -12)
  title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local subtitle = Font(header, "GameFontDisable", "Detect Dispel Protect")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  local status = CreateFrame("Frame", nil, header, "BackdropTemplate")
  status:SetPoint("BOTTOMLEFT", 8, 8)
  status:SetPoint("BOTTOMRIGHT", -8, 8)
  status:SetHeight(36)
  Paint(status, {0.06, 0.18, 0.20, 1}, GOLD)
  local statusTick = status:CreateTexture(nil, "ARTWORK")
  statusTick:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  statusTick:SetPoint("TOPLEFT", 0, 0)
  statusTick:SetPoint("BOTTOMLEFT", 0, 0)
  statusTick:SetWidth(4)

  ui.envHint = Font(status, "GameFontHighlightLarge", "Editing Open World inside Default")
  ui.envHint:SetPoint("LEFT", 16, 0)
  ui.envHint:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  ui.resolved = Font(status, "GameFontHighlightLarge", "Active profile: unavailable")
  ui.resolved:SetPoint("RIGHT", -16, 0)
  ui.resolved:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

  local close = MakeButton(header, "Close", 72)
  close:SetPoint("TOPRIGHT", -16, -14)
  close:SetScript("OnClick", function()
    f:Hide()
  end)

  local searchBox = CreateFrame("EditBox", nil, header, "BackdropTemplate")
  searchBox:SetSize(188, 28)
  searchBox:SetPoint("RIGHT", close, "LEFT", -12, 0)
  searchBox:SetAutoFocus(false)
  searchBox:SetFontObject(GameFontHighlight)
  searchBox:SetTextInsets(10, 10, 0, 0)
  searchBox:SetMaxLetters(40)
  Paint(searchBox, {0.05, 0.08, 0.10, 1}, BORDER)
  searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    self:SetText("")
    ui.search = ""
    Refresh()
  end)
  searchBox:SetScript("OnTextChanged", function(self)
    if not OptionsAccessAllowed("SEARCH") then
      return
    end
    ui.search = string.lower(strtrim(self:GetText() or ""))
    Refresh()
  end)
  ui.searchBox = searchBox
  local searchPh = Font(searchBox, "GameFontDisable", "Search settings")
  searchPh:SetPoint("LEFT", 10, 0)
  searchPh:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  searchBox:SetScript("OnEditFocusGained", function()
    searchPh:Hide()
  end)
  searchBox:SetScript("OnEditFocusLost", function(self)
    if strtrim(self:GetText() or "") == "" then
      searchPh:Show()
    end
  end)

  local navigation = CreateFrame("Frame", nil, f, "BackdropTemplate")
  navigation:SetPoint("TOPLEFT", 20, -116)
  navigation:SetPoint("BOTTOMLEFT", 20, 20)
  navigation:SetWidth(170)
  Paint(navigation, CARD, BORDER)
  ui.navigation = navigation
  ui.navButtons = {}
  local navY = -16
  local statusNav = MakeButton(navigation, "Status", 146, "gold")
  statusNav:SetPoint("TOPLEFT", 12, navY)
  statusNav:SetScript("OnClick", function()
    SetDestination("status")
  end)
  ui.navButtons.status = statusNav
  navY = navY - 44
  local environmentLabel = Font(navigation, "GameFontNormalSmall", "ENVIRONMENT PROFILES")
  environmentLabel:SetPoint("TOPLEFT", 12, navY)
  environmentLabel:SetWidth(SIDEBAR_HEADING_WIDTH)
  environmentLabel:SetWordWrap(false)
  environmentLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  navY = navY - 24
  ui.environmentNavStartY = navY
  for i = 1, #ENVIRONMENT_SUBMENU_ORDER do
    local environment = ENVIRONMENT_SUBMENU_ORDER[i]
    local button = MakeButton(navigation, ns.ENV_LABELS[environment] or environment, 138)
    button:SetPoint("TOPLEFT", 20, navY)
    button:SetScript("OnClick", function()
      SetDestination("environment", environment)
    end)
    ui.navButtons["environment:" .. environment] = button
    navY = navY - 34
  end
  navY = navY - 10
  local addonProfilesNav = MakeButton(navigation, "Decursive Profiles", 146)
  addonProfilesNav:SetPoint("TOPLEFT", 12, navY)
  addonProfilesNav:SetScript("OnClick", function()
    SetDestination("addon_profiles")
  end)
  ui.navButtons.addon_profiles = addonProfilesNav
  ui.addonProfilesNav = addonProfilesNav
  local diagnosticsNav = MakeButton(navigation, "Diagnostics", 146)
  diagnosticsNav:SetPoint("TOPLEFT", 12, navY - 44)
  diagnosticsNav:SetScript("OnClick", function()
    SetDestination("diagnostics")
  end)
  ui.navButtons.diagnostics = diagnosticsNav
  ui.diagnosticsNav = diagnosticsNav

  local profileBar = CreateFrame("Frame", nil, f)
  profileBar:SetPoint("TOPLEFT", WORKSPACE_LEFT, WORKSPACE_TOP)
  profileBar:SetPoint("TOPRIGHT", WORKSPACE_RIGHT, WORKSPACE_TOP)
  profileBar:SetHeight(48)
  ui.profileBar = profileBar

  local profileLabel = Font(profileBar, "GameFontNormal", "PROFILE")
  profileLabel:SetPoint("LEFT", 0, 8)
  profileLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  ui.profileValue = MakeButton(profileBar, "Default", 220, "gold")
  ui.profileValue:SetPoint("LEFT", 0, -12)
  ui.profileValue:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      if name then
        local ok, state = Addon():ActivateProfile(name)
        ReportProfileAction(ok, state, "Profile activated.")
      end
    end)
  end)

  local newBtn = MakeButton(profileBar, "New", 64, "gold")
  newBtn:SetPoint("LEFT", ui.profileValue, "RIGHT", 8, 0)
  newBtn:SetScript("OnClick", function()
    ShowModal("New profile", "", function(name)
      local ok, state = Addon():CreateProfile(name)
      ReportProfileAction(ok, state, "Profile created and activated.")
    end)
  end)

  local copyBtn = MakeButton(profileBar, "Copy", 64)
  copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
  copyBtn:SetScript("OnClick", function()
    ShowModal("Copy profile as", Addon():GetCurrentProfileName() .. " copy", function(name)
      local ok, state = Addon():CopyProfile(name)
      ReportProfileAction(ok, state, "Profile copied and activated.")
    end)
  end)

  local renameBtn = MakeButton(profileBar, "Rename", 80)
  renameBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
  renameBtn:SetScript("OnClick", function()
    ShowModal("Rename profile", Addon():GetCurrentProfileName(), function(name)
      local ok, state = Addon():RenameProfile(name)
      ReportProfileAction(ok, state, "Profile renamed.")
    end)
  end)

  local deleteBtn = MakeButton(profileBar, "Delete", 72, "danger")
  deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 6, 0)
  deleteBtn:SetScript("OnClick", function()
    if not OptionsAccessAllowed("PROFILE_DELETE") then
      return
    end
    local ok, state = Addon():DeleteCurrentProfile()
    ReportProfileAction(ok, state, "Profile deleted; Default activated.")
  end)

  local resetAllBtn = MakeButton(profileBar, "Reset all", 88, "danger")
  resetAllBtn:SetPoint("RIGHT", 0, -12)
  resetAllBtn:SetScript("OnClick", function()
    ShowConfirm("Reset everything?", "Every profile, assignment, and window setting goes back to factory defaults.", function()
      local ok, state = Addon():ResetAllSettings()
      ReportProfileAction(ok, state, "All settings reset.")
    end)
  end)

  local envBar = CreateFrame("Frame", nil, f)
  envBar:SetPoint("TOPLEFT", WORKSPACE_LEFT, WORKSPACE_TOP)
  envBar:SetPoint("TOPRIGHT", WORKSPACE_RIGHT, WORKSPACE_TOP)
  envBar:SetHeight(88)
  ui.envBar = envBar

  ui.environmentApplied = Font(envBar, "GameFontNormalLarge", "Applied: Open World")
  ui.environmentApplied:SetPoint("TOPLEFT", 0, 0)
  ui.environmentApplied:SetTextColor(0.35, 1, 0.55)
  ui.environmentEditing = Font(envBar, "GameFontHighlight", "Editing: Open World")
  ui.environmentEditing:SetPoint("LEFT", ui.environmentApplied, "RIGHT", 18, 0)
  ui.environmentDetected = Font(envBar, "GameFontDisable", "Detected: Open World")
  ui.environmentDetected:SetPoint("LEFT", ui.environmentEditing, "RIGHT", 18, 0)
  ui.environmentPending = Font(envBar, "GameFontDisable", "")
  ui.environmentPending:SetPoint("TOPRIGHT", 0, -2)
  ui.environmentPending:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  ui.envChips = {}
  local chipX = 0
  for _, row in ipairs(ns.ENVIRONMENTS) do
    local chip = MakeButton(envBar, row.label, 118)
    chip:SetPoint("TOPLEFT", chipX, -24)
    chip:SetScript("OnClick", function()
      if not OptionsAccessAllowed("ENVIRONMENT_NAVIGATION") then
        return
      end
      local ok, state = Addon():SetEditingEnvironment(row.key)
      ReportProfileAction(ok, state, "Editing environment changed.")
    end)
    ui.envChips[row.key] = chip
    chipX = chipX + 126
  end

  local envResetBtn = MakeButton(envBar, "Reset env", 88)
  envResetBtn:SetPoint("TOPRIGHT", 0, -24)
  envResetBtn:SetScript("OnClick", function()
    local env = Addon():GetEditingEnvironment()
    local label = ns.ENV_LABELS[env] or env
    ShowConfirm("Reset " .. label .. "?", "Only this environment inside the current profile goes back to defaults.", function()
      local ok, state = Addon():ResetEditingPack()
      ReportProfileAction(ok, state, label .. " reset to defaults.")
    end)
  end)

  local envCopyBtn = MakeButton(envBar, "Copy to", 80)
  envCopyBtn:SetPoint("RIGHT", envResetBtn, "LEFT", -6, 0)
  envCopyBtn:SetScript("OnClick", function(self)
    OpenEnvCopyMenu(self)
  end)
  ui.envCopyBtn = envCopyBtn

  local profileModeLabel = Font(envBar, "GameFontNormal", "PROFILE MODE")
  profileModeLabel:SetPoint("TOPLEFT", 0, -60)
  profileModeLabel:SetWidth(PROFILE_MODE_LABEL_WIDTH)
  profileModeLabel:SetWordWrap(false)
  profileModeLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  ui.profileModeLabel = profileModeLabel
  ui.routingMultiple = MakeButton(envBar, "Multiple", 118)
  ui.routingMultiple:SetPoint("LEFT", profileModeLabel, "RIGHT", PROFILE_MODE_GAP, 0)
  ui.routingMultiple:SetScript("OnClick", function()
    if not OptionsAccessAllowed("PROFILE_MODE") then
      return
    end
    local ok, state = Addon():SetEnvironmentMode("multiple")
    ReportProfileAction(ok, state, "Multiple environment mode selected.")
  end)
  ui.routingSolo = MakeButton(envBar, "Solo", 100)
  ui.routingSolo:SetPoint("LEFT", ui.routingMultiple, "RIGHT", PROFILE_MODE_BUTTON_GAP, 0)
  ui.routingSolo:SetScript("OnClick", function()
    if not OptionsAccessAllowed("PROFILE_MODE") then
      return
    end
    local ok, state = Addon():SetEnvironmentMode("solo")
    ReportProfileAction(ok, state, "Solo environment mode selected.")
  end)

  ui.simpleBtn = MakeButton(header, "Simple", 72, "gold")
  ui.simpleBtn:SetPoint("RIGHT", searchBox, "LEFT", -8, 0)
  ui.simpleBtn:SetScript("OnClick", function()
    if not OptionsAccessAllowed("SIMPLE_MODE") then
      return
    end
    ui.simple = not ui.simple
    local addon = Addon()
    if addon and addon.db then
      addon.db.char.optionsSimple = ui.simple
    end
    LayoutCatalog()
    Refresh()
  end)

  local tabBar = CreateFrame("Frame", nil, f)
  AnchorWorkspaceFrame(tabBar, envBar, envBar, WORKSPACE_GAP)
  tabBar:SetHeight(34)
  ui.tabBar = tabBar
  ui.tabs = {}
  local tabX = 0
  for _, key in ipairs(EDITOR_PAGES) do
    local tab = MakeButton(tabBar, PAGE_LABELS[key], 100)
    tab:SetPoint("LEFT", tabX, 0)
    tab:SetScript("OnClick", function()
      SetTab(key)
    end)
    ui.tabs[key] = tab
    tabX = tabX + 108
  end

  local body = CreateFrame("Frame", nil, f)
  ui.body = body
  LayoutWorkspace("environment")
  BuildPages(body)

  local statusHost = CreateFrame("Frame", nil, f)
  statusHost:SetPoint("TOPLEFT", 204, -116)
  statusHost:SetPoint("BOTTOMRIGHT", -20, 20)
  BuildStatusPage(statusHost)

  local diagnosticsHost = CreateFrame("Frame", nil, f)
  diagnosticsHost:SetPoint("TOPLEFT", 204, -116)
  diagnosticsHost:SetPoint("BOTTOMRIGHT", -20, 20)
  BuildDiagnosticsPage(diagnosticsHost)

  local grip = CreateFrame("Button", nil, f)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetSize(18, 18)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    LayoutScrollChildren()
    SaveFrameSize()
  end)
  f:SetScript("OnSizeChanged", function()
    LayoutScrollChildren()
    RefreshPreview()
  end)

  local modal = CreateFrame("Frame", nil, f, "BackdropTemplate")
  modal:SetFrameStrata("DIALOG")
  modal:SetAllPoints()
  Paint(modal, {0, 0, 0, 0.55})
  local box = CreateFrame("Frame", nil, modal, "BackdropTemplate")
  box:SetSize(420, 160)
  box:SetPoint("CENTER")
  Paint(box, HEADER, GOLD)
  modal.title = Font(box, "GameFontHighlightLarge", "")
  modal.title:SetPoint("TOPLEFT", 20, -18)
  modal.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  modal.hint = Font(box, "GameFontDisable", "")
  modal.hint:SetPoint("TOPLEFT", 20, -52)
  modal.hint:SetWidth(380)
  modal.hint:SetJustifyH("LEFT")
  modal.hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  modal.hint:Hide()
  local edit = CreateFrame("EditBox", nil, box, "BackdropTemplate")
  edit:SetSize(380, 32)
  edit:SetPoint("TOP", 0, -56)
  edit:SetAutoFocus(false)
  edit:SetFontObject(GameFontHighlight)
  edit:SetTextInsets(10, 10, 0, 0)
  Paint(edit, {0.07, 0.07, 0.09, 1}, BORDER)
  edit:SetScript("OnEscapePressed", HideModal)
  edit:SetScript("OnEnterPressed", function(self)
    if modal.onAccept then
      if modal.confirmOnly then
        modal.onAccept()
      else
        modal.onAccept(self:GetText())
      end
    end
    HideModal()
  end)
  modal.edit = edit
  local ok = MakeButton(box, "Save", 88, "gold")
  modal.ok = ok
  ok:SetPoint("BOTTOMRIGHT", -20, 16)
  ok:SetScript("OnClick", function()
    if modal.onAccept then
      if modal.confirmOnly then
        modal.onAccept()
      else
        modal.onAccept(edit:GetText())
      end
    end
    HideModal()
  end)
  local cancel = MakeButton(box, "Cancel", 88)
  cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  cancel:SetScript("OnClick", HideModal)
  modal:Hide()
  ui.modal = modal

  f:SetScript("OnShow", function(self)
    if not OptionsAccessAllowed("FRAME_SHOW") then
      self:Hide()
      return
    end
    LayoutScrollChildren()
    Refresh()
  end)
  f:SetScript("OnHide", function()
    TeardownMUFPreview()
  end)
  ui.frame = f

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local holder = CreateFrame("Frame")
    holder:SetSize(640, 200)
    holder:SetScript("OnShow", function(self)
      if not OptionsAccessAllowed("INTERFACE_OPTIONS") then
        self:Hide()
      end
    end)
    local note = Font(holder, "GameFontHighlight", "Use /zdecursive, /zd, or /dcr or the button below.")
    note:SetPoint("TOPLEFT", 16, -16)
    local open = MakeButton(holder, "Open Zhaohu's Decursive", 240, "gold")
    open:SetPoint("TOPLEFT", 16, -48)
    open:SetScript("OnClick", function()
      ns.ShowOptions()
    end)
    local cat = Settings.RegisterCanvasLayoutCategory(holder, "Zhaohu's Decursive")
    Settings.RegisterAddOnCategory(cat)
  end
  return f
end

function ns.RegisterOptions(addon)
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Options", true)
  end
end

function ns.ShowOptions()
  if not OptionsAccessAllowed("SHOW_OPTIONS") then
    return false, "combat"
  end
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("Options")
  end
  if not ui.frame then
    if not BuildFrame() then
      return false, "combat"
    end
  else
    ApplySavedSize(ui.frame)
  end
  local addon = Addon()
  if addon and addon.db and addon.db.char and addon.db.char.optionsSimple ~= nil then
    ui.simple = addon.db.char.optionsSimple
  end
  ui.frame:Show()
  LayoutScrollChildren()
  Refresh()
  return true, "shown"
end

function ns.ToggleOptions()
  if not OptionsAccessAllowed("TOGGLE_OPTIONS") then
    return false, "combat"
  end
  if ui.frame and ui.frame:IsShown() then
    ui.frame:Hide()
    return true, "hidden"
  end
  return ns.ShowOptions()
end

function ns.CloseOptionsForCombat(source)
  if not OptionsCombatReadOnly() or not ui.frame or not ui.frame:IsShown() then
    return false
  end
  TeardownMUFPreview()
  if ui.modal then
    ui.modal:Hide()
    ui.modal.onAccept = nil
  end
  if ui.searchBox then
    ui.searchBox:ClearFocus()
  end
  ui.search = ""
  ui.frame:Hide()
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("options_closed_for_combat", {source = source or "PLAYER_REGEN_DISABLED"}, false)
  end
  return true
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("Options", function()
    local shown = false
    if ui.frame and type(ui.frame.IsShown) == "function" then
      local ok, value = pcall(ui.frame.IsShown, ui.frame)
      local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(value) or nil
      shown = ok and public == true
    end
    local health = ns.Diagnostics and ns.Diagnostics.GetLastHealthCheckSummary
      and ns.Diagnostics.GetLastHealthCheckSummary() or nil
    return {
      frameCreated = ui.frame ~= nil,
      frameShown = shown,
      simpleMode = ui.simple == true,
      currentPageAvailable = type(ui.destination) == "string" and ui.destination ~= "",
      architectureVersion = OPTIONS_ARCHITECTURE_VERSION,
      defaultDestination = OPTIONS_DEFAULT_DESTINATION,
      currentDestination = tostring(ui.destination or "status"):upper(),
      environmentWorkspace = ui.destination == "environment",
      addonProfilesSeparate = true,
      environmentSubmenuCount = #ENVIRONMENT_SUBMENU_ORDER,
      environmentSubmenu = ENVIRONMENT_SUBMENU_ORDER,
      environmentMode = Addon() and Addon().GetEnvironmentMode and Addon():GetEnvironmentMode() or "multiple",
      multipleEnvironmentCount = #ns.MULTIPLE_ENVIRONMENTS,
      soloEnvironmentCount = 1,
      fullEnvironmentPageCount = #EDITOR_PAGES,
      quickBindingCount = QUICK_BINDING_COUNT,
      shortcutOnlyCount = SHORTCUT_ONLY_COUNT,
      combatReadOnly = OptionsCombatReadOnly(),
      healthCheckAvailable = ns.Diagnostics and type(ns.Diagnostics.RunHealthCheck) == "function" or false,
      lastHealthVerdict = type(health) == "table" and health.verdict or "NOT_RUN",
      searchAvailable = true,
      simpleModeAvailable = true,
      statusPanels = {"CURRENT_SETUP", "DISPEL_CAPABILITY", "CLICK_MAPPINGS", "QUICK_BINDINGS"},
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Options")
end
