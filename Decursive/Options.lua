local ADDON_NAME, ns = ...

local GOLD = {0.93, 0.74, 0.28, 1}
local GOLD_DIM = {0.93, 0.74, 0.28, 0.35}
local TEXT = {0.93, 0.91, 0.86, 1}
local MUTED = {0.58, 0.56, 0.50, 1}
local BG = {0.055, 0.06, 0.08, 0.97}
local HEADER = {0.09, 0.095, 0.12, 1}
local CARD = {0.11, 0.12, 0.145, 1}
local BORDER = {0.32, 0.27, 0.16, 0.9}
local TAB_IDLE = {0.14, 0.145, 0.17, 1}
local DANGER = {0.75, 0.28, 0.22, 1}

local ui = {
  tab = "mufs",
  frame = nil,
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
    fill = {0.22, 0.17, 0.08, 1}
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
      Paint(self, {0.28, 0.21, 0.08, 1}, GOLD)
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
  row:SetSize(820, 36)
  row:SetPoint("TOPLEFT", 16, y)
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

local PAGES = {"mufs", "cure", "alerts", "advanced", "assign"}
local PAGE_LABELS = {
  mufs = "MUFs",
  cure = "Cure",
  alerts = "Alerts",
  advanced = "Advanced",
  assign = "Assignment",
}

local function GrowLabel(key)
  local map = {LEFT = "Left", RIGHT = "Right", UP = "Up", DOWN = "Down"}
  return map[key] or key
end

local function ShowModal(title, defaultText, onAccept)
  local f = ui.modal
  f.title:SetText(title)
  f.edit:SetText(defaultText or "")
  f.edit:HighlightText()
  f.onAccept = onAccept
  f:Show()
  f.edit:SetFocus()
end

local function HideModal()
  ui.modal:Hide()
end

local function RefreshPreview()
  local pack = Addon():GetEditingPack()
  local size = pack.mufs.size
  local spacing = pack.mufs.spacing
  local squares = ui.previewSquares
  for i = 1, 5 do
    local sq = squares[i]
    sq:SetSize(size, size)
    sq:ClearAllPoints()
    if i == 1 then
      sq:SetPoint("LEFT", ui.previewHost, "LEFT", 8, 0)
    else
      sq:SetPoint("LEFT", squares[i - 1], "RIGHT", spacing, 0)
    end
    if pack.mufs.show then
      sq:SetAlpha(pack.mufs.alpha)
    else
      sq:SetAlpha(0.2)
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
  local pack = addon:GetEditingPack()

  ui.profileValue:SetText(profile)
  ui.resolved:SetText("Active on login: " .. addon:ResolveProfileName())
  ui.envHint:SetText("Editing " .. (ns.ENV_LABELS[env] or env) .. " inside " .. profile)

  for key, chip in pairs(ui.envChips) do
    if key == env then
      Paint(chip, {0.24, 0.18, 0.08, 1}, GOLD)
      chip.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
      Paint(chip, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      chip.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    end
  end

  for key, tab in pairs(ui.tabs) do
    if key == ui.tab then
      Paint(tab, {0.2, 0.16, 0.08, 1}, GOLD)
      tab.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
      ui.pages[key]:Show()
    else
      Paint(tab, TAB_IDLE, {0.25, 0.25, 0.28, 1})
      tab.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
      ui.pages[key]:Hide()
    end
  end

  ui.mufs.show:SetOn(pack.mufs.show)
  ui.mufs.size:SetNumber(pack.mufs.size)
  ui.mufs.spacing:SetNumber(pack.mufs.spacing)
  ui.mufs.alpha:SetNumber(pack.mufs.alpha)
  ui.mufs.wrap:SetNumber(pack.mufs.wrap)
  ui.mufs.grow:SetText(GrowLabel(pack.mufs.grow))
  RefreshPreview()

  ui.cure.mode:SetText("AUTO  ·  two-button")
  ui.cure.magic:SetOn(pack.cure.magic)
  ui.cure.curse:SetOn(pack.cure.curse)
  ui.cure.poison:SetOn(pack.cure.poison)
  ui.cure.disease:SetOn(pack.cure.disease)
  ui.cure.enrage:SetOn(pack.cure.enrage)

  ui.alerts.pvpText:SetOn(pack.alerts.pvpText)
  ui.alerts.text:SetOn(pack.alerts.text)
  ui.alerts.sound:SetOn(pack.alerts.sound)
  ui.alerts.errorSound:SetOn(pack.alerts.errorSound)

  ui.advanced.debug:SetOn(pack.advanced.debug)
  ui.advanced.checkDelay:SetNumber(pack.advanced.checkDelay)

  ui.assign.account:SetText(addon.db.global.accountProfile or "Default")
  local key = addon:GetCharacterKey()
  local charProfile = key and addon.db.global.characters[key]
  ui.assign.character:SetText(charProfile or "Use account / Default")
  local specName = addon:GetSpecName() or "Current spec"
  ui.assign.specLabel:SetText("This spec (" .. specName .. ")")
  local row = addon:GetSpecAssignment()
  ui.assign.specEnabled:SetOn(row and row.enabled)
  ui.assign.specProfile:SetText((row and row.profile) or "Default")
end

ns.RefreshOptions = Refresh

function ns.IsOptionsShown()
  return ui.frame and ui.frame:IsShown()
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

local function OpenGrowMenu(anchor)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    return
  end
  MenuUtil.CreateContextMenu(anchor, function(_, root)
    for _, key in ipairs({"RIGHT", "LEFT", "DOWN", "UP"}) do
      root:CreateRadio(GrowLabel(key), function()
        return Addon():GetEditingPack().mufs.grow == key
      end, function()
        Addon():GetEditingPack().mufs.grow = key
        Refresh()
      end)
    end
  end)
end

local function SetTab(tab)
  ui.tab = tab
  Refresh()
end

local function BuildPages(content)
  ui.pages = {}
  ui.mufs = {}
  ui.cure = {}
  ui.alerts = {}
  ui.advanced = {}
  ui.assign = {}

  local mufs = CreateFrame("Frame", nil, content)
  mufs:SetAllPoints()
  ui.pages.mufs = mufs
  local mufsCard = MakeCard(mufs, "Micro unit frames")
  mufsCard:SetPoint("TOPLEFT", 0, 0)
  mufsCard:SetPoint("BOTTOMRIGHT", 0, 0)
  local hint = Font(mufsCard, "GameFontDisable", "Paint only this slice. These values persist for the click-to-cure machine.")
  hint:SetPoint("TOPLEFT", 16, -40)
  hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  ui.previewHost = CreateFrame("Frame", nil, mufsCard, "BackdropTemplate")
  ui.previewHost:SetPoint("TOPLEFT", 16, -68)
  ui.previewHost:SetSize(788, 84)
  Paint(ui.previewHost, {0.07, 0.075, 0.09, 1}, GOLD_DIM)
  ui.previewSquares = {}
  for i = 1, 5 do
    local sq = ui.previewHost:CreateTexture(nil, "ARTWORK")
    sq:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    ui.previewSquares[i] = sq
  end

  local y = -168
  local rowShow = MakeRow(mufsCard, y, "Show MUFs")
  ui.mufs.show = MakeToggle(rowShow)
  ui.mufs.show:SetPoint("RIGHT", -12, 0)
  ui.mufs.show.OnValueChanged = function(_, on)
    Addon():GetEditingPack().mufs.show = on
    RefreshPreview()
  end

  y = y - 40
  local rowSize = MakeRow(mufsCard, y, "Size")
  ui.mufs.size = MakeSlider(rowSize, 10, 72, 1)
  ui.mufs.size:SetPoint("RIGHT", -12, 0)
  ui.mufs.size.OnValueChanged = function(_, v)
    Addon():GetEditingPack().mufs.size = math.floor(v + 0.5)
    RefreshPreview()
  end

  y = y - 40
  local rowSpacing = MakeRow(mufsCard, y, "Spacing")
  ui.mufs.spacing = MakeSlider(rowSpacing, 0, 20, 1)
  ui.mufs.spacing:SetPoint("RIGHT", -12, 0)
  ui.mufs.spacing.OnValueChanged = function(_, v)
    Addon():GetEditingPack().mufs.spacing = math.floor(v + 0.5)
    RefreshPreview()
  end

  y = y - 40
  local rowAlpha = MakeRow(mufsCard, y, "Alpha")
  ui.mufs.alpha = MakeSlider(rowAlpha, 0.1, 1, 0.05)
  ui.mufs.alpha:SetPoint("RIGHT", -12, 0)
  ui.mufs.alpha.OnValueChanged = function(_, v)
    Addon():GetEditingPack().mufs.alpha = v
    RefreshPreview()
  end

  y = y - 40
  local rowGrow = MakeRow(mufsCard, y, "Grow")
  ui.mufs.grow = MakeButton(rowGrow, "Right", 140)
  ui.mufs.grow:SetPoint("RIGHT", -12, 0)
  ui.mufs.grow:SetScript("OnClick", function(self)
    OpenGrowMenu(self)
  end)

  y = y - 40
  local rowWrap = MakeRow(mufsCard, y, "Per row / column")
  ui.mufs.wrap = MakeSlider(rowWrap, 1, 40, 1)
  ui.mufs.wrap:SetPoint("RIGHT", -12, 0)
  ui.mufs.wrap.OnValueChanged = function(_, v)
    Addon():GetEditingPack().mufs.wrap = math.floor(v + 0.5)
  end

  local cure = CreateFrame("Frame", nil, content)
  cure:SetAllPoints()
  ui.pages.cure = cure
  local cureCard = MakeCard(cure, "Cure")
  cureCard:SetPoint("TOPLEFT", 0, 0)
  cureCard:SetPoint("BOTTOMRIGHT", 0, 0)
  local cureHint = Font(cureCard, "GameFontDisable", "AUTO maps two mouse buttons to cure. Buttons are not created in this slice.")
  cureHint:SetPoint("TOPLEFT", 16, -40)
  cureHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  y = -80
  local rowMode = MakeRow(cureCard, y, "Click mode")
  ui.cure.mode = Font(rowMode, "GameFontHighlight", "AUTO  ·  two-button")
  ui.cure.mode:SetPoint("RIGHT", -16, 0)
  ui.cure.mode:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local cureToggles = {
    {key = "magic", label = "Magic"},
    {key = "curse", label = "Curse"},
    {key = "poison", label = "Poison"},
    {key = "disease", label = "Disease"},
    {key = "enrage", label = "Enrage"},
  }
  for i, spec in ipairs(cureToggles) do
    local row = MakeRow(cureCard, -80 - i * 40, spec.label)
    local tog = MakeToggle(row)
    tog:SetPoint("RIGHT", -12, 0)
    tog.OnValueChanged = function(_, on)
      Addon():GetEditingPack().cure[spec.key] = on
    end
    ui.cure[spec.key] = tog
  end

  local alerts = CreateFrame("Frame", nil, content)
  alerts:SetAllPoints()
  ui.pages.alerts = alerts
  local alertsCard = MakeCard(alerts, "Alerts")
  alertsCard:SetPoint("TOPLEFT", 0, 0)
  alertsCard:SetPoint("BOTTOMRIGHT", 0, 0)
  local alertHint = Font(alertsCard, "GameFontDisable", "PvP text is off by default.")
  alertHint:SetPoint("TOPLEFT", 16, -40)
  alertHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  local alertToggles = {
    {key = "pvpText", label = "PvP text"},
    {key = "text", label = "Text alerts"},
    {key = "sound", label = "Sound alerts"},
    {key = "errorSound", label = "Error sound"},
  }
  for i, spec in ipairs(alertToggles) do
    local row = MakeRow(alertsCard, -40 - i * 40, spec.label)
    local tog = MakeToggle(row)
    tog:SetPoint("RIGHT", -12, 0)
    tog.OnValueChanged = function(_, on)
      Addon():GetEditingPack().alerts[spec.key] = on
    end
    ui.alerts[spec.key] = tog
  end

  local advanced = CreateFrame("Frame", nil, content)
  advanced:SetAllPoints()
  ui.pages.advanced = advanced
  local advCard = MakeCard(advanced, "Advanced")
  advCard:SetPoint("TOPLEFT", 0, 0)
  advCard:SetPoint("BOTTOMRIGHT", 0, 0)
  local advHint = Font(advCard, "GameFontDisable", "No minimap. SavedVariables is DecursiveRebuildDB. Does not read DecursiveDB.")
  advHint:SetPoint("TOPLEFT", 16, -40)
  advHint:SetWidth(760)
  advHint:SetJustifyH("LEFT")
  advHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  local rowDebug = MakeRow(advCard, -88, "Debug chat")
  ui.advanced.debug = MakeToggle(rowDebug)
  ui.advanced.debug:SetPoint("RIGHT", -12, 0)
  ui.advanced.debug.OnValueChanged = function(_, on)
    Addon():GetEditingPack().advanced.debug = on
  end
  local rowDelay = MakeRow(advCard, -128, "Check delay (seconds)")
  ui.advanced.checkDelay = MakeSlider(rowDelay, 0.05, 1, 0.05)
  ui.advanced.checkDelay:SetPoint("RIGHT", -12, 0)
  ui.advanced.checkDelay.OnValueChanged = function(_, v)
    Addon():GetEditingPack().advanced.checkDelay = v
  end

  local assign = CreateFrame("Frame", nil, content)
  assign:SetAllPoints()
  ui.pages.assign = assign
  local asCard = MakeCard(assign, "Who uses this profile")
  asCard:SetPoint("TOPLEFT", 0, 0)
  asCard:SetPoint("BOTTOMRIGHT", 0, 0)
  local asHint = Font(asCard, "GameFontDisable", "Resolver: spec (if enabled and mapped), then this character, then account, then Default.")
  asHint:SetPoint("TOPLEFT", 16, -40)
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
  end
end

local function BuildFrame()
  local f = CreateFrame("Frame", "DecursiveRebuildOptions", UIParent, "BackdropTemplate")
  f:SetSize(900, 640)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
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
  header:SetHeight(64)
  Paint(header, HEADER)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
  end)

  local title = Font(header, "GameFontNormalHuge", "Zhaohu's Decursive")
  title:SetPoint("LEFT", 22, 8)
  title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local subtitle = Font(header, "GameFontDisable", "Profile first. Options live inside the profile you are editing.")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  local close = MakeButton(header, "Close", 72)
  close:SetPoint("RIGHT", -16, 0)
  close:SetScript("OnClick", function()
    f:Hide()
  end)

  local profileBar = CreateFrame("Frame", nil, f)
  profileBar:SetPoint("TOPLEFT", 20, -80)
  profileBar:SetPoint("TOPRIGHT", -20, -80)
  profileBar:SetHeight(48)

  local profileLabel = Font(profileBar, "GameFontNormal", "PROFILE")
  profileLabel:SetPoint("LEFT", 0, 8)
  profileLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  ui.profileValue = MakeButton(profileBar, "Default", 240, "gold")
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

  local newBtn = MakeButton(profileBar, "New", 72, "gold")
  newBtn:SetPoint("LEFT", ui.profileValue, "RIGHT", 10, 0)
  newBtn:SetScript("OnClick", function()
    ShowModal("New profile", "", function(name)
      Addon():CreateProfile(name)
    end)
  end)

  local renameBtn = MakeButton(profileBar, "Rename", 88)
  renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)
  renameBtn:SetScript("OnClick", function()
    ShowModal("Rename profile", Addon().db:GetCurrentProfile(), function(name)
      Addon():RenameProfile(name)
    end)
  end)

  local deleteBtn = MakeButton(profileBar, "Delete", 80, "danger")
  deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 8, 0)
  deleteBtn:SetScript("OnClick", function()
    Addon():DeleteCurrentProfile()
    Refresh()
  end)

  ui.resolved = Font(profileBar, "GameFontDisable", "")
  ui.resolved:SetPoint("RIGHT", 0, -12)
  ui.resolved:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  local envBar = CreateFrame("Frame", nil, f)
  envBar:SetPoint("TOPLEFT", 20, -136)
  envBar:SetPoint("TOPRIGHT", -20, -136)
  envBar:SetHeight(36)
  ui.envHint = Font(envBar, "GameFontDisable", "")
  ui.envHint:SetPoint("TOPLEFT", 0, 0)
  ui.envHint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  ui.envChips = {}
  local chipX = 0
  for i, row in ipairs(ns.ENVIRONMENTS) do
    local chip = MakeButton(envBar, row.label, 118)
    chip:SetPoint("TOPLEFT", chipX, -14)
    chip:SetScript("OnClick", function()
      Addon():SetEditingEnvironment(row.key)
    end)
    ui.envChips[row.key] = chip
    chipX = chipX + 126
  end

  local tabBar = CreateFrame("Frame", nil, f)
  tabBar:SetPoint("TOPLEFT", 20, -186)
  tabBar:SetPoint("TOPRIGHT", -20, -186)
  tabBar:SetHeight(34)
  ui.tabs = {}
  local tabX = 0
  for _, key in ipairs(PAGES) do
    local tab = MakeButton(tabBar, PAGE_LABELS[key], 120)
    tab:SetPoint("LEFT", tabX, 0)
    tab:SetScript("OnClick", function()
      SetTab(key)
    end)
    ui.tabs[key] = tab
    tabX = tabX + 128
  end

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 20, -230)
  content:SetPoint("BOTTOMRIGHT", -20, 20)
  BuildPages(content)

  local modal = CreateFrame("Frame", nil, f, "BackdropTemplate")
  modal:SetFrameStrata("DIALOG")
  modal:SetAllPoints()
  Paint(modal, {0, 0, 0, 0.55})
  local box = CreateFrame("Frame", nil, modal, "BackdropTemplate")
  box:SetSize(420, 160)
  box:SetPoint("CENTER")
  Paint(box, HEADER, GOLD)
  modal.title = Font(box, "GameFontNormalLarge", "")
  modal.title:SetPoint("TOPLEFT", 20, -18)
  modal.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
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
      modal.onAccept(self:GetText())
    end
    HideModal()
  end)
  modal.edit = edit
  local ok = MakeButton(box, "Save", 88, "gold")
  ok:SetPoint("BOTTOMRIGHT", -20, 16)
  ok:SetScript("OnClick", function()
    if modal.onAccept then
      modal.onAccept(edit:GetText())
    end
    HideModal()
  end)
  local cancel = MakeButton(box, "Cancel", 88)
  cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  cancel:SetScript("OnClick", HideModal)
  modal:Hide()
  ui.modal = modal

  f:SetScript("OnShow", Refresh)
  ui.frame = f

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local holder = CreateFrame("Frame")
    holder:SetSize(640, 200)
    local note = Font(holder, "GameFontHighlight", "Use /dcr or the button below. Options live inside the selected profile.")
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
  BuildFrame()
end

function ns.ShowOptions()
  if not ui.frame then
    BuildFrame()
  end
  ui.frame:Show()
  Refresh()
end
