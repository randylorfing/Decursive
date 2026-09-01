local ADDON_NAME, ns = ...

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
  frame = nil,
  simple = true,
  collapsed = {},
}

local function Addon()
  return ns.addon
end

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
  return btn
end

local function MakeToggle(parent)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(42, 22)
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
    slider:SetValue(v)
    if step < 1 then
      valueText:SetText(string.format("%.2f", v))
    else
      valueText:SetText(tostring(math.floor(v + 0.5)))
    end
  end
  slider:SetScript("OnValueChanged", function(_, v)
    if step < 1 then
      valueText:SetText(string.format("%.2f", v))
    else
      valueText:SetText(tostring(math.floor(v + 0.5)))
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


local function MakeColorSwatch(parent)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(40, 22)
  Paint(btn, {1, 1, 1, 1}, BORDER)
  function btn:SetColor(c)
    self._c = {c[1], c[2], c[3], c[4] or 1}
    self:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
  end
  btn:SetScript("OnClick", function(self)
    local c = self._c or {1, 1, 1, 1}
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
      return
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r = c[1],
      g = c[2],
      b = c[3],
      opacity = c[4] or 1,
      hasOpacity = true,
      swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = 1
        if ColorPickerFrame.GetColorAlpha then
          a = ColorPickerFrame:GetColorAlpha()
        end
        self:SetColor({r, g, b, a})
        if self.OnValueChanged then
          self:OnValueChanged(self._c)
        end
      end,
    })
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
    if ns.RefreshMUFs then
      ns.RefreshMUFs()
    end
    if ns.RefreshAlerts then
      ns.RefreshAlerts()
    end
    if ui.RefreshPreview then
      ui.RefreshPreview()
    end
  end
end
local PAGES = {"mufs", "sorting", "cure", "color", "alerts", "advanced", "assign"}
local PAGE_LABELS = {
  mufs = "MUFs",
  sorting = "Sorting",
  cure = "Cure",
  color = "Color",
  alerts = "Alerts",
  advanced = "Advanced",
  assign = "Assign",
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
  {page = "mufs", label = "Link horizontal and vertical spacing", kind = "toggle", get = PathGet("mufs", "linkSpacing"), set = PathSet("mufs", "linkSpacing")},
  {page = "mufs", label = "Horizontal spacing", kind = "slider", min = 0, max = 100, step = 1, get = PathGet("mufs", "horizontalSpacing"), set = PathSet("mufs", "horizontalSpacing")},
  {page = "mufs", label = "Vertical spacing", kind = "slider", min = 0, max = 100, step = 1, get = PathGet("mufs", "verticalSpacing"), set = PathSet("mufs", "verticalSpacing")},
  {page = "mufs", label = "Grow upward", kind = "toggle", get = PathGet("mufs", "growUp"), set = PathSet("mufs", "growUp")},
  {page = "mufs", label = "Grow from right edge", kind = "toggle", get = PathGet("mufs", "growFromRight"), set = PathSet("mufs", "growFromRight")},
  {page = "mufs", label = "Fill columns before rows", kind = "toggle", get = PathGet("mufs", "verticalLayout"), set = PathSet("mufs", "verticalLayout")},
  {page = "mufs", label = "Maximum MUFs", kind = "slider", min = 1, max = 80, step = 1, get = PathGet("mufs", "maxUnits"), set = PathSet("mufs", "maxUnits")},
  {page = "mufs", label = "Units per line", kind = "slider", min = 1, max = 40, step = 1, get = PathGet("mufs", "unitsPerLine"), set = PathSet("mufs", "unitsPerLine")},
  {page = "mufs", label = "Show MUF border", kind = "toggle", get = PathGet("mufs", "border"), set = PathSet("mufs", "border")},
  {page = "mufs", label = "Inactive opacity", kind = "slider", min = 0, max = 1, step = 0.05, get = PathGet("mufs", "inactiveOpacity"), set = PathSet("mufs", "inactiveOpacity")},

  {page = "sorting", label = "MUF order", kind = "choice", values = ORDER_LABELS, get = PathGet("mufs", "order"), set = PathSet("mufs", "order")},
  {page = "sorting", label = "Afflicted units first", kind = "toggle", get = PathGet("sorting", "afflictedFirst"), set = PathSet("sorting", "afflictedFirst")},
  {page = "sorting", label = "Include player", kind = "toggle", get = PathGet("sorting", "includePlayer"), set = PathSet("sorting", "includePlayer")},
  {page = "sorting", label = "Include pets", kind = "toggle", get = PathGet("sorting", "includePets"), set = PathSet("sorting", "includePets")},
  {page = "sorting", label = "Center on player", kind = "toggle", get = PathGet("sorting", "centerPlayer"), set = PathSet("sorting", "centerPlayer")},
  {page = "sorting", label = "Skip dead and offline", kind = "toggle", get = PathGet("sorting", "skipDead"), set = PathSet("sorting", "skipDead")},

  {page = "cure", label = "Click mode", kind = "choice", values = {AUTO = "AUTO  ·  two-button"}, get = PathGet("cure", "mode"), set = PathSet("cure", "mode")},
  {page = "cure", label = "Magic", kind = "toggle", get = PathGet("cure", "magic"), set = PathSet("cure", "magic")},
  {page = "cure", label = "Curse", kind = "toggle", get = PathGet("cure", "curse"), set = PathSet("cure", "curse")},
  {page = "cure", label = "Poison", kind = "toggle", get = PathGet("cure", "poison"), set = PathSet("cure", "poison")},
  {page = "cure", label = "Disease", kind = "toggle", get = PathGet("cure", "disease"), set = PathSet("cure", "disease")},
  {page = "cure", label = "Enrage", kind = "toggle", get = PathGet("cure", "enrage"), set = PathSet("cure", "enrage")},

  {page = "color", label = "Magic", kind = "color", get = PathGet("colors", "magic"), set = PathSet("colors", "magic")},
  {page = "color", label = "Curse", kind = "color", get = PathGet("colors", "curse"), set = PathSet("colors", "curse")},
  {page = "color", label = "Poison", kind = "color", get = PathGet("colors", "poison"), set = PathSet("colors", "poison")},
  {page = "color", label = "Disease", kind = "color", get = PathGet("colors", "disease"), set = PathSet("colors", "disease")},
  {page = "color", label = "Enrage", kind = "color", get = PathGet("colors", "enrage"), set = PathSet("colors", "enrage")},
  {page = "color", label = "Healthy MUF", kind = "color", get = PathGet("colors", "healthy"), set = PathSet("colors", "healthy")},
  {page = "color", label = "Afflicted MUF", kind = "color", get = PathGet("colors", "afflicted"), set = PathSet("colors", "afflicted")},
  {page = "color", label = "Border", kind = "color", get = PathGet("colors", "border"), set = PathSet("colors", "border")},

  {page = "alerts", label = "Dispel text alert", kind = "toggle", get = PathGet("alerts", "dispelEnabled"), set = PathSet("alerts", "dispelEnabled")},
  {page = "alerts", label = "Display mode", kind = "choice", values = {TIMED = "Timed", UNTIL_CLEARED = "Until cleared"}, get = PathGet("alerts", "dispelMode"), set = PathSet("alerts", "dispelMode")},
  {page = "alerts", label = "Display duration", kind = "slider", min = 0.5, max = 30, step = 0.5, get = PathGet("alerts", "dispelDuration"), set = PathSet("alerts", "dispelDuration")},
  {page = "alerts", label = "Text size", kind = "slider", min = 12, max = 96, step = 1, get = PathGet("alerts", "dispelFontSize"), set = PathSet("alerts", "dispelFontSize")},
  {page = "alerts", label = "PvP text", kind = "toggle", get = PathGet("alerts", "pvpText"), set = PathSet("alerts", "pvpText")},
  {page = "alerts", label = "Text alerts", kind = "toggle", get = PathGet("alerts", "text"), set = PathSet("alerts", "text")},
  {page = "alerts", label = "Chat status messages", kind = "toggle", get = PathGet("alerts", "chat"), set = PathSet("alerts", "chat")},
  {page = "alerts", label = "Dispel sound", kind = "toggle", get = PathGet("alerts", "sound"), set = PathSet("alerts", "sound")},
  {page = "alerts", label = "Sound", kind = "choice", values = SOUND_LABELS, get = PathGet("alerts", "soundPreset"), set = PathSet("alerts", "soundPreset")},
  {page = "alerts", label = "Sound channel", kind = "choice", values = {Master = "Master", SFX = "SFX", Music = "Music", Ambience = "Ambience", Dialog = "Dialog"}, get = PathGet("alerts", "soundChannel"), set = PathSet("alerts", "soundChannel")},
  {page = "alerts", label = "Group debounce", kind = "slider", min = 0, max = 5, step = 0.25, get = PathGet("alerts", "soundDebounce"), set = PathSet("alerts", "soundDebounce")},
  {page = "alerts", label = "Cure-failure sound", kind = "toggle", get = PathGet("alerts", "errorSound"), set = PathSet("alerts", "errorSound")},
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
  {page = "mufs", label = "Show secondary affliction", kind = "toggle", get = PathGet("mufs", "secondaryAffliction"), set = PathSet("mufs", "secondaryAffliction")},
  {page = "mufs", label = "Pulse secondary affliction", kind = "toggle", get = PathGet("mufs", "pulseSecondary"), set = PathSet("mufs", "pulseSecondary")},
  {page = "mufs", label = "Share cooldown with same-priority MUFs", kind = "toggle", get = PathGet("mufs", "shareCooldown"), set = PathSet("mufs", "shareCooldown")},
  {page = "mufs", label = "Clear cleansed target immediately", kind = "toggle", get = PathGet("mufs", "clearCleansedImmediately"), set = PathSet("mufs", "clearCleansedImmediately")},
  {page = "mufs", label = "Soul Link fallback", kind = "toggle", get = PathGet("mufs", "soulLinkFallback"), set = PathSet("mufs", "soulLinkFallback")},
  {page = "mufs", label = "Secondary affliction border", kind = "toggle", get = PathGet("mufs", "secondaryBorder"), set = PathSet("mufs", "secondaryBorder")},
  {page = "mufs", label = "Tie center and border opacity", kind = "toggle", get = PathGet("mufs", "tieCenterAndBorder"), set = PathSet("mufs", "tieCenterAndBorder")},

  {page = "cure", label = "Charm", kind = "toggle", get = PathGet("cure", "charm"), set = PathSet("cure", "charm")},
  {page = "cure", label = "Magic (charmed)", kind = "toggle", get = PathGet("cure", "magicCharmed"), set = PathSet("cure", "magicCharmed")},
  {page = "cure", label = "Bleed", kind = "toggle", get = PathGet("cure", "bleed"), set = PathSet("cure", "bleed")},
  {page = "cure", label = "Bleed-effect detection", kind = "toggle", get = PathGet("cure", "bleedDetection"), set = PathSet("cure", "bleedDetection")},
  {page = "cure", label = "Do not skip priority-list units", kind = "toggle", get = PathGet("cure", "doNotBlacklistPrio"), set = PathSet("cure", "doNotBlacklistPrio")},
  {page = "cure", label = "Cure pets", kind = "toggle", get = PathGet("cure", "curePets"), set = PathSet("cure", "curePets")},
  {page = "cure", label = "Skip stealthed", kind = "toggle", get = PathGet("cure", "skipStealthed"), set = PathSet("cure", "skipStealthed")},
  {page = "cure", label = "Left click", kind = "choice", values = {CURE = "Cure", TARGET = "Target", FOCUS = "Focus", ASSIST = "Assist"}, get = PathGet("mouse", "left"), set = PathSet("mouse", "left")},
  {page = "cure", label = "Right click", kind = "choice", values = {CURE = "Cure", TARGET = "Target", FOCUS = "Focus", ASSIST = "Assist"}, get = PathGet("mouse", "right"), set = PathSet("mouse", "right")},

  {page = "color", label = "Charm", kind = "color", get = PathGet("colors", "charm"), set = PathSet("colors", "charm")},
  {page = "color", label = "Bleed", kind = "color", get = PathGet("colors", "bleed"), set = PathSet("colors", "bleed")},
  {page = "color", label = "Dead / offline", kind = "color", get = PathGet("colors", "dead"), set = PathSet("colors", "dead")},
  {page = "color", label = "Out of range", kind = "color", get = PathGet("colors", "range"), set = PathSet("colors", "range")},
  {page = "color", label = "Stealth", kind = "color", get = PathGet("colors", "stealth"), set = PathSet("colors", "stealth")},

  {page = "alerts", label = "Print to default chat", kind = "toggle", get = PathGet("alerts", "printChat"), set = PathSet("alerts", "printChat")},
  {page = "alerts", label = "Print to custom window", kind = "toggle", get = PathGet("alerts", "printCustom"), set = PathSet("alerts", "printCustom")},
  {page = "alerts", label = "Print errors", kind = "toggle", get = PathGet("alerts", "printErrors"), set = PathSet("alerts", "printErrors")},
  {page = "alerts", label = "Soul Link battle-rez warning", kind = "toggle", get = PathGet("alerts", "soulLinkAlert"), set = PathSet("alerts", "soulLinkAlert")},
  {page = "alerts", label = "Native 12.1 aura sounds", kind = "toggle", get = PathGet("alerts", "nativeAuraSound"), set = PathSet("alerts", "nativeAuraSound")},
  {page = "alerts", label = "Learn spell IDs from successful dispels", kind = "toggle", get = PathGet("alerts", "learnSpellIds"), set = PathSet("alerts", "learnSpellIds")},
  {page = "alerts", label = "Live list", kind = "toggle", get = PathGet("alerts", "liveList"), set = PathSet("alerts", "liveList")},
  {page = "alerts", label = "Live list only in range", kind = "toggle", get = PathGet("alerts", "liveListOnlyInRange"), set = PathSet("alerts", "liveListOnlyInRange")},
  {page = "alerts", label = "Live list rows", kind = "slider", min = 1, max = 20, step = 1, get = PathGet("alerts", "liveListAmount"), set = PathSet("alerts", "liveListAmount")},
  {page = "alerts", label = "Live list scan (seconds)", kind = "slider", min = 0.05, max = 1, step = 0.05, get = PathGet("alerts", "liveListScan"), set = PathSet("alerts", "liveListScan")},
  {page = "alerts", label = "Reverse live list", kind = "toggle", get = PathGet("alerts", "liveListReverse"), set = PathSet("alerts", "liveListReverse")},

  {page = "advanced", label = "Debug chat", kind = "toggle", get = PathGet("advanced", "debug"), set = PathSet("advanced", "debug")},
  {page = "advanced", label = "Check delay (seconds)", kind = "slider", min = 0.05, max = 1, step = 0.05, get = PathGet("advanced", "checkDelay"), set = PathSet("advanced", "checkDelay")},
  {page = "advanced", label = "Hide start messages", kind = "toggle", get = PathGet("advanced", "noStartMessages"), set = PathSet("advanced", "noStartMessages")},
  {page = "advanced", label = "Skip-list duration (seconds)", kind = "slider", min = 1, max = 30, step = 1, get = PathGet("advanced", "blacklistLength"), set = PathSet("advanced", "blacklistLength")},
  {page = "advanced", label = "MUF refresh rate", kind = "slider", min = 0.02, max = 0.5, step = 0.01, get = PathGet("advanced", "refreshRate"), set = PathSet("advanced", "refreshRate")},
  {page = "advanced", label = "Disable macro creation", kind = "toggle", get = PathGet("advanced", "disableMacroCreation"), set = PathSet("advanced", "disableMacroCreation")},
  {page = "advanced", label = "Allow macro editing", kind = "toggle", get = PathGet("advanced", "allowMacroEdit"), set = PathSet("advanced", "allowMacroEdit")},
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
  ["mufs|Maximum MUFs"] = {group = "Size"},
  ["mufs|Units per line"] = {group = "Size", simple = true},
  ["mufs|Link horizontal and vertical spacing"] = {group = "Spacing", simple = true},
  ["mufs|Horizontal spacing"] = {group = "Spacing", simple = true},
  ["mufs|Vertical spacing"] = {group = "Spacing", simple = true},
  ["mufs|Grow upward"] = {group = "Layout"},
  ["mufs|Grow from right edge"] = {group = "Layout"},
  ["mufs|Fill columns before rows"] = {group = "Layout"},
  ["mufs|Show MUF border"] = {group = "Look"},
  ["mufs|Inactive opacity"] = {group = "Look"},
  ["mufs|Center unit name"] = {group = "Look"},
  ["mufs|Show stealth status"] = {group = "Look"},
  ["mufs|Status indicator light"] = {group = "Status"},
  ["mufs|Dim out of range"] = {group = "Status"},
  ["mufs|Out-of-range dim"] = {group = "Status"},
  ["mufs|Show secondary affliction"] = {group = "Status"},
  ["mufs|Pulse secondary affliction"] = {group = "Status"},
  ["mufs|Share cooldown with same-priority MUFs"] = {group = "Status"},
  ["mufs|Clear cleansed target immediately"] = {group = "Status"},
  ["mufs|Soul Link fallback"] = {group = "Status"},
  ["mufs|Secondary affliction border"] = {group = "Status"},
  ["mufs|Tie center and border opacity"] = {group = "Status"},
  ["sorting|MUF order"] = {group = "Roster", simple = true},
  ["sorting|Afflicted units first"] = {group = "Roster", simple = true},
  ["sorting|Include player"] = {group = "Roster", simple = true},
  ["sorting|Include pets"] = {group = "Roster", simple = true},
  ["sorting|Center on player"] = {group = "Roster"},
  ["sorting|Skip dead and offline"] = {group = "Roster"},
  ["cure|Click mode"] = {group = "Clicks", simple = true},
  ["cure|Left click"] = {group = "Clicks"},
  ["cure|Right click"] = {group = "Clicks"},
  ["cure|Magic"] = {group = "Types", simple = true},
  ["cure|Curse"] = {group = "Types", simple = true},
  ["cure|Poison"] = {group = "Types", simple = true},
  ["cure|Disease"] = {group = "Types", simple = true},
  ["cure|Enrage"] = {group = "Types", simple = true},
  ["cure|Charm"] = {group = "Types"},
  ["cure|Magic (charmed)"] = {group = "Types"},
  ["cure|Bleed"] = {group = "Types", simple = true},
  ["cure|Bleed-effect detection"] = {group = "Rules"},
  ["cure|Do not skip priority-list units"] = {group = "Rules"},
  ["cure|Cure pets"] = {group = "Rules"},
  ["cure|Skip stealthed"] = {group = "Rules"},
  ["color|Magic"] = {group = "Afflictions", simple = true},
  ["color|Curse"] = {group = "Afflictions", simple = true},
  ["color|Poison"] = {group = "Afflictions", simple = true},
  ["color|Disease"] = {group = "Afflictions", simple = true},
  ["color|Enrage"] = {group = "Afflictions", simple = true},
  ["color|Charm"] = {group = "Afflictions"},
  ["color|Bleed"] = {group = "Afflictions", simple = true},
  ["color|Healthy MUF"] = {group = "Squares"},
  ["color|Afflicted MUF"] = {group = "Squares"},
  ["color|Border"] = {group = "Squares"},
  ["color|Dead / offline"] = {group = "Squares"},
  ["color|Out of range"] = {group = "Squares"},
  ["color|Stealth"] = {group = "Squares"},
  ["alerts|Dispel text alert"] = {group = "Dispel text", simple = true},
  ["alerts|Display mode"] = {group = "Dispel text"},
  ["alerts|Display duration"] = {group = "Dispel text"},
  ["alerts|Text size"] = {group = "Dispel text"},
  ["alerts|PvP text"] = {group = "Dispel text", simple = true},
  ["alerts|Text alerts"] = {group = "Dispel text"},
  ["alerts|Dispel sound"] = {group = "Sound", simple = true},
  ["alerts|Sound"] = {group = "Sound"},
  ["alerts|Sound channel"] = {group = "Sound"},
  ["alerts|Group debounce"] = {group = "Sound"},
  ["alerts|Cure-failure sound"] = {group = "Sound"},
  ["alerts|Native 12.1 aura sounds"] = {group = "Sound"},
  ["alerts|Learn spell IDs from successful dispels"] = {group = "Sound"},
  ["alerts|Cooldown overlay"] = {group = "Cooldown", simple = true},
  ["alerts|Countdown numbers"] = {group = "Cooldown"},
  ["alerts|Overlay darkness"] = {group = "Cooldown"},
  ["alerts|Out-of-range status"] = {group = "Cooldown"},
  ["alerts|Print to default chat"] = {group = "Chat"},
  ["alerts|Print to custom window"] = {group = "Chat"},
  ["alerts|Print errors"] = {group = "Chat"},
  ["alerts|Chat status messages"] = {group = "Chat"},
  ["alerts|Soul Link battle-rez warning"] = {group = "Chat"},
  ["alerts|Live list"] = {group = "Live list"},
  ["alerts|Live list only in range"] = {group = "Live list"},
  ["alerts|Live list rows"] = {group = "Live list"},
  ["alerts|Live list scan (seconds)"] = {group = "Live list"},
  ["alerts|Reverse live list"] = {group = "Live list"},
  ["advanced|Debug chat"] = {group = "Engine"},
  ["advanced|Check delay (seconds)"] = {group = "Engine"},
  ["advanced|Hide start messages"] = {group = "Engine"},
  ["advanced|Skip-list duration (seconds)"] = {group = "Engine"},
  ["advanced|MUF refresh rate"] = {group = "Engine"},
  ["advanced|Disable macro creation"] = {group = "Engine"},
  ["advanced|Allow macro editing"] = {group = "Engine"},
}

local GROUP_ORDER = {
  mufs = {"Display", "Size", "Spacing", "Layout", "Look", "Status"},
  sorting = {"Roster"},
  cure = {"Types", "Clicks", "Rules"},
  color = {"Afflictions", "Squares"},
  alerts = {"Dispel text", "Sound", "Cooldown", "Chat", "Live list"},
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

local PAGE_HAS_SIMPLE = {}
for _, spec in ipairs(CATALOG) do
  if spec.simple then
    PAGE_HAS_SIMPLE[spec.page] = true
  end
end


local function ShowModal(title, defaultText, onAccept)
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
  f.onAccept = onAccept
  f.confirmOnly = false
  f:Show()
  f.edit:SetFocus()
end

local function ShowConfirm(title, hint, onAccept)
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
    onAccept()
  end
  f.confirmOnly = true
  f:Show()
end

local function HideModal()
  ui.modal:Hide()
end

local function OpenChoiceMenu(anchor, values, get, set)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return
  end
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    local current = get()
    for key, label in pairs(values) do
      root:CreateRadio(label, function()
        return current == key
      end, function()
        set(key)
        ns.RefreshOptions()
      end)
    end
  end)
end

local function OpenProfileMenu(anchor, onPick, includeInherit)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return
  end
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    if includeInherit then
      root:CreateButton("Use account / Default", function()
        onPick(nil)
      end)
      root:CreateDivider()
    end
    for _, name in ipairs(Addon().db:GetProfiles()) do
      root:CreateRadio(name, function()
        return Addon().db:GetCurrentProfile() == name
      end, function()
        onPick(name)
      end)
    end
  end)
end

local function OpenEnvCopyMenu(anchor)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return
  end
  local src = Addon():GetEditingEnvironment()
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    root:CreateTitle("Copy " .. (ns.ENV_LABELS[src] or src) .. " to")
    for _, row in ipairs(ns.ENVIRONMENTS) do
      if row.key ~= src then
        root:CreateButton(row.label, function()
          Addon():CopyEditingPackTo(row.key)
        end)
      end
    end
  end)
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
    return group ~= "Display" and group ~= "Size" and group ~= "Types" and group ~= "Roster" and group ~= "Afflictions" and group ~= "Dispel text" and group ~= "Clicks"
  end
  if pageMap[group] == nil then
    return group ~= "Display" and group ~= "Size" and group ~= "Types" and group ~= "Roster" and group ~= "Afflictions" and group ~= "Dispel text" and group ~= "Clicks"
  end
  return pageMap[group]
end


local PREVIEW_COLORS = {"magic", "curse", "poison", "disease", "healthy"}

local function PreviewSize(pack, env)
  if env == "RAID" then
    return pack.mufs.raidSize or 20
  end
  if env == "DUNGEON" or env == "MYTHIC_PLUS" then
    return pack.mufs.partySize or 20
  end
  return pack.mufs.partySize or 20
end

local function RefreshPreview()
  if not ui.previewHost or not ui.previewSquares then
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
  local n = 5
  local pad = 16
  local need = n * size + (n - 1) * hSpace
  local avail = hostW - pad * 2
  local scale = 1
  if need > avail and need > 0 then
    scale = avail / need
  end
  if size * scale > 48 then
    scale = 48 / size
  end
  local draw = math.max(8, size * scale)
  local gap = hSpace * scale
  local growRight = pack.mufs.growFromRight
  local shown = pack.mufs.show ~= false
  local colors = pack.colors or {}
  local captionKind = "party"
  if env == "RAID" then
    captionKind = "raid"
  end
  if ui.previewCaption then
    ui.previewCaption:SetText(string.format("Size preview - %s %dpx - gap %dpx", captionKind, size, hSpace))
  end
  local rowWidth = n * draw + (n - 1) * gap
  local startX
  if growRight then
    startX = hostW - pad - draw
  else
    startX = pad
  end
  for i = 1, n do
    local sq = ui.previewSquares[i]
    local key = PREVIEW_COLORS[i]
    local c = colors[key] or GOLD
    sq.fill:SetColorTexture(c[1] or 0.3, c[2] or 0.8, c[3] or 0.8, shown and (c[4] or 1) or 0.22)
    local br = colors.border or {0.05, 0.08, 0.10, 1}
    sq.border:SetColorTexture(br[1], br[2], br[3], shown and 1 or 0.22)
    sq:SetSize(draw, draw)
    sq.fill:ClearAllPoints()
    sq.fill:SetPoint("CENTER")
    sq.fill:SetSize(math.max(4, draw - 4), math.max(4, draw - 4))
    sq:ClearAllPoints()
    local x
    if growRight then
      x = startX - (i - 1) * (draw + gap)
    else
      x = startX + (i - 1) * (draw + gap)
    end
    sq:SetPoint("BOTTOMLEFT", ui.previewHost, "BOTTOMLEFT", x, 10)
  end
  if ui.previewHandle then
    ui.previewHandle:SetSize(math.min(20, draw), math.min(20, draw))
    ui.previewHandle:ClearAllPoints()
    if pack.mufs.growUp then
      ui.previewHandle:SetPoint("TOPLEFT", ui.previewSquares[1], "BOTTOMLEFT", 0, 0)
    else
      ui.previewHandle:SetPoint("BOTTOMLEFT", ui.previewSquares[1], "TOPLEFT", 0, 0)
    end
    ui.previewHandle:SetShown(pack.mufs.hideHandle ~= true)
  end
end

ui.RefreshPreview = RefreshPreview

local function BuildMufPreview(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Paint(host, {0.05, 0.09, 0.12, 1}, BORDER)
  host:SetHeight(88)
  local caption = Font(host, "GameFontDisable", "Size preview")
  caption:SetPoint("TOPLEFT", 14, -8)
  caption:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  ui.previewCaption = caption
  ui.previewHost = host
  ui.previewSquares = {}
  for i = 1, 5 do
    local sq = CreateFrame("Frame", nil, host)
    sq.border = sq:CreateTexture(nil, "BACKGROUND")
    sq.border:SetAllPoints()
    sq.fill = sq:CreateTexture(nil, "ARTWORK")
    ui.previewSquares[i] = sq
  end
  local handle = CreateFrame("Frame", nil, host)
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

local function LayoutCatalog()
  if not ui.sections then
    return
  end
  for page, sections in pairs(ui.sections) do
    local y = 0
    local child = ui.pageChildren and ui.pageChildren[page]
    if page == "mufs" and ui.previewHost then
      ui.previewHost:ClearAllPoints()
      ui.previewHost:SetPoint("TOPLEFT", 0, 0)
      ui.previewHost:SetPoint("TOPRIGHT", 0, 0)
      ui.previewHost:SetHeight(88)
      ui.previewHost:Show()
      y = -96
      RefreshPreview()
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
end

local function Refresh()
  if not ui.frame then
    return
  end
  local addon = Addon()
  addon:EnsureEnvironments()
  local profile = addon.db:GetCurrentProfile()
  local env = addon:GetEditingEnvironment()
  ui.profileValue:SetText(profile)
  ui.resolved:SetText("Active Profile on login: " .. addon:ResolveProfileName())
  ui.envHint:SetText("Editing " .. (ns.ENV_LABELS[env] or env) .. " inside " .. profile)

  for key, chip in pairs(ui.envChips) do
    if key == env then
      Paint(chip, {0.07, 0.22, 0.24, 1}, GOLD)
      chip.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      Paint(chip, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      chip.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    end
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

  for key, page in pairs(ui.pages) do
    if searching then
      page:SetShown(key == "search")
    else
      page:SetShown(key == ui.tab)
    end
  end

  for _, bind in ipairs(ui.binds) do
    if bind.kind == "toggle" then
      bind.widget:SetOn(bind.get())
    elseif bind.kind == "slider" then
      bind.widget:SetNumber(bind.get())
    elseif bind.kind == "choice" then
      local v = bind.get()
      bind.widget:SetText(bind.values[v] or tostring(v))
    elseif bind.kind == "color" then
      bind.widget:SetColor(bind.get())
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
          row.label:SetText((PAGE_LABELS[spec.page] or spec.page) .. "  ·  " .. spec.label)
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
  local specName = addon:GetSpecName() or "Current spec"
  ui.assign.specLabel:SetText("This spec (" .. specName .. ")")
  local row = addon:GetSpecAssignment()
  ui.assign.specEnabled:SetOn(row and row.enabled)
  ui.assign.specProfile:SetText((row and row.profile) or "Default")
  LayoutCatalog()
  RefreshPreview()
end

ns.RefreshOptions = Refresh

function ns.IsOptionsShown()
  return ui.frame and ui.frame:IsShown()
end

local function BindRow(parent, y, spec)
  local row = MakeRow(parent, y, spec.label)
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
    widget = MakeColorSwatch(row)
    widget:SetPoint("RIGHT", -16, 0)
    widget.OnValueChanged = function(_, c)
      spec.set(c)
    end
  end
  ui.binds[#ui.binds + 1] = {kind = spec.kind, widget = widget, get = spec.get, set = spec.set, values = spec.values}
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
  if w < 900 then
    w = 900
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
  local asCard = MakeCard(assignWrap, "Who uses this profile")
  asCard:SetAllPoints()
  local asHint = Font(asCard, "GameFontDisable", "Resolver: spec (if enabled and mapped), then this character, then account, then Default.")
  asHint:SetPoint("TOPLEFT", 16, -44)
  asHint:SetWidth(760)
  asHint:SetJustifyH("LEFT")
  asHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  local rowAccount = MakeRow(asCard, -88, "Account")
  ui.assign.account = MakeButton(rowAccount, "Default", 220)
  ui.assign.account:SetPoint("RIGHT", -12, 0)
  ui.assign.account:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      if name then
        Addon().db.global.accountProfile = name
        Refresh()
      end
    end)
  end)
  local rowChar = MakeRow(asCard, -128, "This character")
  ui.assign.character = MakeButton(rowChar, "Use account / Default", 220)
  ui.assign.character:SetPoint("RIGHT", -12, 0)
  ui.assign.character:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      local key = Addon():GetCharacterKey()
      if not key then
        return
      end
      Addon().db.global.characters[key] = name
      Refresh()
    end, true)
  end)
  local rowSpecEnable = MakeRow(asCard, -168, "Assign this spec")
  ui.assign.specLabel = rowSpecEnable.label
  ui.assign.specEnabled = MakeToggle(rowSpecEnable)
  ui.assign.specEnabled:SetPoint("RIGHT", -12, 0)
  ui.assign.specEnabled.OnValueChanged = function(_, on)
    local row = Addon():GetSpecAssignment()
    if row then
      row.enabled = on
      Refresh()
    end
  end
  local rowSpec = MakeRow(asCard, -208, "Spec profile")
  ui.assign.specProfile = MakeButton(rowSpec, "Default", 220)
  ui.assign.specProfile:SetPoint("RIGHT", -12, 0)
  ui.assign.specProfile:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      local row = Addon():GetSpecAssignment()
      if row and name then
        row.profile = name
        Refresh()
      end
    end)
  end)

  local searchWrap = CreateFrame("Frame", nil, content)
  searchWrap:SetAllPoints()
  local searchCard = MakeCard(searchWrap, "Search")
  searchCard:SetAllPoints()
  ui.searchCount = Font(searchCard, "GameFontDisable", "")
  ui.searchCount:SetPoint("TOPLEFT", 16, -44)
  ui.searchCount:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  for i = 1, #CATALOG do
    local row = MakeRow(searchCard, -80, "")
    row:Hide()
    ui.searchRows[i] = row
  end
  ui.pages.search = searchWrap
end

local function SetTab(tab)
  ui.tab = tab
  ui.search = ""
  if ui.searchBox then
    ui.searchBox:SetText("")
  end
  Refresh()
end

local function BuildFrame()
  local f = CreateFrame("Frame", "DecursiveRebuildOptions", UIParent, "BackdropTemplate")
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  if f.SetResizeBounds then
    f:SetResizeBounds(900, 580, 1800, 1400)
  else
    f:SetMinResize(900, 580)
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

  ui.resolved = Font(status, "GameFontHighlightLarge", "Active Profile on login: Default")
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

  local profileBar = CreateFrame("Frame", nil, f)
  profileBar:SetPoint("TOPLEFT", 20, -116)
  profileBar:SetPoint("TOPRIGHT", -20, -116)
  profileBar:SetHeight(48)

  local profileLabel = Font(profileBar, "GameFontNormal", "PROFILE")
  profileLabel:SetPoint("LEFT", 0, 8)
  profileLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  ui.profileValue = MakeButton(profileBar, "Default", 220, "gold")
  ui.profileValue:SetPoint("LEFT", 0, -12)
  ui.profileValue:SetScript("OnClick", function(self)
    OpenProfileMenu(self, function(name)
      if name then
        Addon().db:SetProfile(name)
        Addon():EnsureEnvironments()
        Refresh()
      end
    end)
  end)

  local newBtn = MakeButton(profileBar, "New", 64, "gold")
  newBtn:SetPoint("LEFT", ui.profileValue, "RIGHT", 8, 0)
  newBtn:SetScript("OnClick", function()
    ShowModal("New profile", "", function(name)
      Addon():CreateProfile(name)
    end)
  end)

  local copyBtn = MakeButton(profileBar, "Copy", 64)
  copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
  copyBtn:SetScript("OnClick", function()
    ShowModal("Copy profile as", Addon().db:GetCurrentProfile() .. " copy", function(name)
      Addon():CopyProfile(name)
    end)
  end)

  local renameBtn = MakeButton(profileBar, "Rename", 80)
  renameBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
  renameBtn:SetScript("OnClick", function()
    ShowModal("Rename profile", Addon().db:GetCurrentProfile(), function(name)
      Addon():RenameProfile(name)
    end)
  end)

  local deleteBtn = MakeButton(profileBar, "Delete", 72, "danger")
  deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 6, 0)
  deleteBtn:SetScript("OnClick", function()
    Addon():DeleteCurrentProfile()
    Refresh()
  end)

  local resetAllBtn = MakeButton(profileBar, "Reset all", 88, "danger")
  resetAllBtn:SetPoint("RIGHT", 0, -12)
  resetAllBtn:SetScript("OnClick", function()
    ShowConfirm("Reset everything?", "Every profile, assignment, and window setting goes back to factory defaults.", function()
      Addon():ResetAllSettings()
    end)
  end)

  local envBar = CreateFrame("Frame", nil, f)
  envBar:SetPoint("TOPLEFT", 20, -176)
  envBar:SetPoint("TOPRIGHT", -20, -176)
  envBar:SetHeight(28)

  ui.envChips = {}
  local chipX = 0
  for _, row in ipairs(ns.ENVIRONMENTS) do
    local chip = MakeButton(envBar, row.label, 118)
    chip:SetPoint("TOPLEFT", chipX, 0)
    chip:SetScript("OnClick", function()
      Addon():SetEditingEnvironment(row.key)
    end)
    ui.envChips[row.key] = chip
    chipX = chipX + 126
  end

  local envResetBtn = MakeButton(envBar, "Reset env", 88)
  envResetBtn:SetPoint("TOPRIGHT", 0, 0)
  envResetBtn:SetScript("OnClick", function()
    local env = Addon():GetEditingEnvironment()
    local label = ns.ENV_LABELS[env] or env
    ShowConfirm("Reset " .. label .. "?", "Only this environment inside the current profile goes back to defaults.", function()
      Addon():ResetEditingPack()
    end)
  end)

  local envCopyBtn = MakeButton(envBar, "Copy to", 80)
  envCopyBtn:SetPoint("RIGHT", envResetBtn, "LEFT", -6, 0)
  envCopyBtn:SetScript("OnClick", function(self)
    OpenEnvCopyMenu(self)
  end)

  ui.simpleBtn = MakeButton(header, "Simple", 72, "gold")
  ui.simpleBtn:SetPoint("RIGHT", searchBox, "LEFT", -8, 0)
  ui.simpleBtn:SetScript("OnClick", function()
    ui.simple = not ui.simple
    local addon = Addon()
    if addon and addon.db then
      addon.db.char.optionsSimple = ui.simple
    end
    LayoutCatalog()
    Refresh()
  end)

  local tabBar = CreateFrame("Frame", nil, f)
  tabBar:SetPoint("TOPLEFT", 20, -214)
  tabBar:SetPoint("TOPRIGHT", -20, -214)
  tabBar:SetHeight(34)
  ui.tabs = {}
  local tabX = 0
  for _, key in ipairs(PAGES) do
    local tab = MakeButton(tabBar, PAGE_LABELS[key], 100)
    tab:SetPoint("LEFT", tabX, 0)
    tab:SetScript("OnClick", function()
      SetTab(key)
    end)
    ui.tabs[key] = tab
    tabX = tabX + 108
  end

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 20, -256)
  body:SetPoint("BOTTOMRIGHT", -20, 20)
  ui.body = body
  BuildPages(body)

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

  f:SetScript("OnShow", function()
    LayoutScrollChildren()
    Refresh()
  end)
  ui.frame = f

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local holder = CreateFrame("Frame")
    holder:SetSize(640, 200)
    local note = Font(holder, "GameFontHighlight", "Use /dcr or the button below.")
    note:SetPoint("TOPLEFT", 16, -16)
    local open = MakeButton(holder, "Open Zhaohu's Decursive", 240, "gold")
    open:SetPoint("TOPLEFT", 16, -48)
    open:SetScript("OnClick", function()
      ns.ShowOptions()
    end)
    local cat = Settings.RegisterCanvasLayoutCategory(holder, "Zhaohu's Decursive")
    Settings.RegisterAddOnCategory(cat)
  end
end

function ns.RegisterOptions(addon)
end

function ns.ShowOptions()
  if not ui.frame then
    BuildFrame()
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
end
