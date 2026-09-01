local ADDON_NAME, ns = ...

local POOL_SIZE = 80
local BORDER_PX = 2
local GCD = 1.5
local DISPEL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local CLASS_DISPEL = {
  PALADIN = {4987, 213644},
  PRIEST = {527, 213634},
  DRUID = {88423, 2782},
  SHAMAN = {77130, 51886},
  MONK = {115450, 218164},
  EVOKER = {360823, 365585, 374251},
  MAGE = {475},
  WARLOCK = {89808},
}

local MOUSE_BUTTONS = {
  {key = "left", index = 1},
  {key = "right", index = 2},
  {key = "middle", index = 3},
  {key = "button4", index = 4},
  {key = "button5", index = 5},
}

local header
local handle
local pool = {}
local poolReady = false
local pending = false
local eventsOn = false
local eventFrame
local cureName
local cureId
local cooldownUntil = 0
local cooldownSkipGUID
local rangeElapsed = 0

local function Addon()
  return ns.addon
end

local function GetPack()
  local addon = Addon()
  if addon and addon.GetEditingPack then
    return addon:GetEditingPack()
  end
  return ns.PACK
end

local function GetEnv()
  local addon = Addon()
  if addon and addon.GetEditingEnvironment then
    return addon:GetEditingEnvironment()
  end
  return "OPEN_WORLD"
end

local function Accessible(value)
  if value == nil then
    return true
  end
  if type(issecretvalue) == "function" and issecretvalue(value) then
    if type(canaccessvalue) == "function" then
      return canaccessvalue(value) == true
    end
    return false
  end
  return true
end

local function Public(value)
  if not Accessible(value) then
    return nil
  end
  return value
end

local function IsTrue(value)
  if not Accessible(value) then
    return false
  end
  return value == true or value == 1
end

local function LockedDown()
  return InCombatLockdown and InCombatLockdown()
end

local function ColorOf(c, fallback)
  if type(c) == "table" then
    return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
  end
  if type(fallback) == "table" then
    return fallback[1], fallback[2], fallback[3], fallback[4] or 1
  end
  return 0.12, 0.16, 0.18, 1
end

local function ApplyColor(tex, c, a)
  if not tex then
    return
  end
  local r, g, b, alpha = ColorOf(c)
  tex:SetColorTexture(r, g, b, a or alpha)
end

local function ClassBorderColor(unit, fallback)
  if UnitClass then
    local _name, classFile = UnitClass(unit)
    classFile = Public(classFile)
    if type(classFile) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
      local c = RAID_CLASS_COLORS[classFile]
      return c.r or 1, c.g or 1, c.b or 1, 1
    end
  end
  return ColorOf(fallback)
end

local function UnitPresent(unit)
  if not unit or not UnitExists then
    return unit ~= nil
  end
  local exists = UnitExists(unit)
  if not Accessible(exists) then
    return true
  end
  return exists == true
end

local function IsPlayerToken(unit)
  if unit == "player" then
    return true
  end
  if UnitIsUnit then
    local same = UnitIsUnit(unit, "player")
    if Accessible(same) and same then
      return true
    end
  end
  return false
end

local function IsPubliclyDead(unit)
  if not UnitIsDeadOrGhost then
    return false
  end
  local dead = UnitIsDeadOrGhost(unit)
  if not Accessible(dead) then
    return false
  end
  return dead == true
end

local function PlayerClassFile()
  local classFile
  if UnitClass then
    local _name, file = UnitClass("player")
    classFile = Public(file)
  end
  return classFile
end

local function SpellKnown(spellId)
  if C_SpellBook then
    if C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId)) then
      return true
    end
    local banks = Enum and Enum.SpellBookSpellBank
    if banks then
      if C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId, banks.Player)) then
        return true
      end
      if C_SpellBook.IsSpellKnown and IsTrue(C_SpellBook.IsSpellKnown(spellId, banks.Pet)) then
        return true
      end
    end
    if C_SpellBook.IsSpellInSpellBook and IsTrue(C_SpellBook.IsSpellInSpellBook(spellId)) then
      return true
    end
    if C_SpellBook.IsSpellKnownOrInSpellBook and IsTrue(C_SpellBook.IsSpellKnownOrInSpellBook(spellId)) then
      return true
    end
  end
  if IsPlayerSpell and IsTrue(IsPlayerSpell(spellId)) then
    return true
  end
  if IsSpellKnown and IsTrue(IsSpellKnown(spellId)) then
    return true
  end
  if IsSpellKnown and IsTrue(IsSpellKnown(spellId, true)) then
    return true
  end
  return false
end

local function SpellName(spellId)
  local name
  if C_Spell and C_Spell.GetSpellName then
    name = C_Spell.GetSpellName(spellId)
  elseif C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if type(info) == "table" then
      name = info.name
    end
  end
  if type(name) == "string" and Accessible(name) and name ~= "" then
    return name
  end
  return nil
end

local function FirstKnown(ids)
  if type(ids) ~= "table" then
    return nil, nil
  end
  for i = 1, #ids do
    local id = ids[i]
    if SpellKnown(id) then
      local name = SpellName(id)
      if name then
        return name, id
      end
    end
  end
  return nil, nil
end

local function ResolveCureSpell()
  if cureName then
    return cureName, cureId
  end
  local classFile = PlayerClassFile()
  if type(classFile) == "string" and CLASS_DISPEL[classFile] then
    cureName, cureId = FirstKnown(CLASS_DISPEL[classFile])
    if cureName then
      return cureName, cureId
    end
  end
  for _, ids in pairs(CLASS_DISPEL) do
    local name, id = FirstKnown(ids)
    if name then
      cureName, cureId = name, id
      return cureName, cureId
    end
  end
  return nil, nil
end

local function PixelSize(pack, env)
  local mufs = pack.mufs
  local partySize = mufs.partySize or 20
  local raidSize = mufs.raidSize or 20
  if env == "RAID" then
    return raidSize
  end
  if env == "DUNGEON" or env == "MYTHIC_PLUS" then
    return partySize
  end
  local members = GetNumGroupMembers and GetNumGroupMembers() or 0
  if type(members) ~= "number" or members <= 5 then
    return partySize
  end
  return raidSize
end

local function Spacing(pack)
  local h = pack.mufs.horizontalSpacing or 2
  local v = pack.mufs.verticalSpacing or 2
  if pack.mufs.linkSpacing then
    v = h
  end
  return h, v
end

local function ShouldShowHeader(pack)
  if not pack.mufs.show then
    return false
  end
  local autoHide = pack.mufs.autoHide or "NEVER"
  if autoHide == "ALWAYS" then
    return false
  end
  if autoHide == "SOLO" then
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members == 0 then
      return false
    end
  end
  return true
end

local function TryDandersUnits()
  local df = _G.DandersFrames
  if type(df) ~= "table" then
    return nil
  end
  local names = {"GetOrderedUnits", "GetUnitOrder", "GetRoster", "GetRosterUnits", "GetUnitList"}
  local fn
  for i = 1, #names do
    local candidate = df[names[i]]
    if type(candidate) == "function" then
      fn = candidate
      break
    end
  end
  if not fn and type(df.API) == "table" then
    for i = 1, #names do
      local candidate = df.API[names[i]]
      if type(candidate) == "function" then
        fn = candidate
        df = df.API
        break
      end
    end
  end
  if not fn then
    return nil
  end
  local ok, result = pcall(fn, df)
  if not ok or type(result) ~= "table" then
    return nil
  end
  local units = {}
  for i = 1, #result do
    local row = result[i]
    local unit
    if type(row) == "string" then
      unit = row
    elseif type(row) == "table" then
      unit = row.unit or row.unitToken or row.token
      if not unit and row.GetAttribute then
        unit = row:GetAttribute("unit")
      end
    end
    if type(unit) == "string" and Accessible(unit) then
      units[#units + 1] = unit
    end
  end
  if #units == 0 then
    return nil
  end
  return units
end

local function AppendUnit(units, seen, unit, pack)
  if type(unit) ~= "string" or seen[unit] then
    return
  end
  if not UnitPresent(unit) then
    return
  end
  if pack.sorting.includePlayer == false and IsPlayerToken(unit) then
    return
  end
  if pack.sorting.skipDead and IsPubliclyDead(unit) then
    return
  end
  seen[unit] = true
  units[#units + 1] = unit
end

local function AppendPet(units, seen, owner, pack)
  if not pack.sorting.includePets then
    return
  end
  local pet
  if owner == "player" then
    pet = "playerpet"
  elseif owner:find("^party%d+$") then
    pet = owner .. "pet"
  elseif owner:find("^raid%d+$") then
    pet = owner .. "pet"
  end
  if pet then
    AppendUnit(units, seen, pet, pack)
  end
end

local function BuildRoster(pack)
  local units = {}
  local seen = {}
  local order = pack.mufs.order or "GROUP"
  if order == "DANDERSFRAMES" then
    local danders = TryDandersUnits()
    if danders then
      for i = 1, #danders do
        AppendUnit(units, seen, danders[i], pack)
        AppendPet(units, seen, danders[i], pack)
      end
      return units
    end
  end
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do
      local unit = "raid" .. i
      AppendUnit(units, seen, unit, pack)
      AppendPet(units, seen, unit, pack)
    end
    return units
  end
  if pack.sorting.includePlayer ~= false then
    AppendUnit(units, seen, "player", pack)
    AppendPet(units, seen, "player", pack)
  end
  if IsInGroup and IsInGroup() then
    for i = 1, 4 do
      local unit = "party" .. i
      AppendUnit(units, seen, unit, pack)
      AppendPet(units, seen, unit, pack)
    end
  end
  return units
end

local function GetSavedPoint()
  local addon = Addon()
  local char = addon and addon.db and addon.db.char
  if char then
    if type(char.mufPoint) ~= "table" then
      char.mufPoint = {point = "CENTER", x = 0, y = 0}
    end
    return char.mufPoint
  end
  return {point = "CENTER", x = 0, y = 0}
end

local function SavePoint()
  if not header then
    return
  end
  local point, _, _, x, y = header:GetPoint()
  local saved = GetSavedPoint()
  saved.point = point or "CENTER"
  saved.x = x or 0
  saved.y = y or 0
end

local function RestorePoint()
  if not header then
    return
  end
  local saved = GetSavedPoint()
  local point = saved.point or "CENTER"
  header:ClearAllPoints()
  header:SetPoint(point, UIParent, point, saved.x or 0, saved.y or 0)
end

local function DispelColorMap(pack)
  if not CreateColor then
    return nil
  end
  local colors = pack.colors
  if type(colors) ~= "table" then
    return nil
  end
  local function C(c)
    if type(c) ~= "table" then
      return nil
    end
    return CreateColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
  end
  local map = {
    Magic = C(colors.magic),
    Curse = C(colors.curse),
    Poison = C(colors.poison),
    Disease = C(colors.disease),
    Enrage = C(colors.enrage),
    Charm = C(colors.charm),
    Bleed = C(colors.bleed),
    None = C(colors.afflicted),
  }
  return map
end

local function BindAuraSlot(slot, pack)
  if not slot then
    return
  end
  slot:ClearAllPoints()
  slot:SetAllPoints()
  if slot.EnableMouse then
    slot:EnableMouse(false)
  end
  local tex = slot._decursiveFill
  if not tex then
    tex = slot:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(slot)
    tex:SetTexture(WHITE)
    tex:SetVertexColor(1, 1, 1, 1)
    slot._decursiveFill = tex
  end
  local options = {
    showWhenHarmful = true,
    showWhenHelpful = false,
    showWithoutDispelType = false,
    customDispelColorMap = DispelColorMap(pack),
  }
  local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
  if styles and styles.PreserveAsset then
    options.style = styles.PreserveAsset
  end
  if slot.ClearDispelTypeTextures then
    slot:ClearDispelTypeTextures()
  end
  if slot.AddDispelTypeTexture then
    slot:AddDispelTypeTexture(tex, options)
  elseif slot.SetAuraBorder then
    slot:SetAuraBorder(tex, options)
  elseif slot.SetIcon then
    slot:SetIcon(tex)
  end
end

local function MakeAuraContainer(parent)
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  if ok and container then
    return container
  end
  ok, container = pcall(CreateFrame, "AuraContainer", nil, parent)
  if ok and container then
    return container
  end
  return nil
end

local function AttachAuraContainer(btn, pack)
  if btn.auraContainer then
    if btn.auraContainer.SetEnabled then
      btn.auraContainer:SetEnabled(true)
    end
    return
  end
  if btn.auraSkipped then
    return
  end
  local container = MakeAuraContainer(btn.inner)
  if not container then
    btn.auraSkipped = true
    return
  end
  container:SetAllPoints(btn.inner)
  if container.EnableMouse then
    container:EnableMouse(false)
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  btn.auraContainer = container
  local unit = btn.unit or "player"
  if container.SetUnit then
    container:SetUnit(unit)
  end
  -- AuraButton config only in initializeFrame. Do not touch the slot after AddAuraSlot.
  if container.AddAuraSlot then
    container:AddAuraSlot("dispel", DISPEL_FILTER, {
      initializeFrame = function(frame)
        BindAuraSlot(frame, pack)
      end,
    })
  end
end

local function ClearClickAttributes(btn)
  for i = 1, 5 do
    btn:SetAttribute("type" .. i, nil)
    btn:SetAttribute("spell" .. i, nil)
    btn:SetAttribute("macro" .. i, nil)
    btn:SetAttribute("macrotext" .. i, nil)
  end
end

local function ApplyAction(btn, index, action, spell)
  if action == "CURE" then
    if spell then
      btn:SetAttribute("type" .. index, "spell")
      btn:SetAttribute("spell" .. index, spell)
    end
    return
  end
  if action == "TARGET" then
    btn:SetAttribute("type" .. index, "target")
    return
  end
  if action == "FOCUS" then
    btn:SetAttribute("type" .. index, "focus")
    return
  end
  if action == "ASSIST" then
    btn:SetAttribute("type" .. index, "assist")
    return
  end
end

local function ApplyClickAttributes(btn, pack, unit)
  ClearClickAttributes(btn)
  btn:SetAttribute("unit", unit)
  local spell = ResolveCureSpell()
  local mouse = pack.mouse or {}
  local mode = pack.cure and pack.cure.mode
  if mode == "AUTO" then
    if spell then
      ApplyAction(btn, 1, "CURE", spell)
      ApplyAction(btn, 2, "CURE", spell)
    else
      ApplyAction(btn, 1, mouse.left or "TARGET", spell)
      ApplyAction(btn, 2, mouse.right or "TARGET", spell)
    end
    ApplyAction(btn, 3, mouse.middle, spell)
    ApplyAction(btn, 4, mouse.button4, spell)
    ApplyAction(btn, 5, mouse.button5, spell)
    return
  end
  for i = 1, #MOUSE_BUTTONS do
    local row = MOUSE_BUTTONS[i]
    ApplyAction(btn, row.index, mouse[row.key], spell)
  end
end

local function PaintSquare(btn, pack, unit)
  local colors = pack.colors or {}
  local borderOn = pack.mufs.border ~= false
  local dead = IsPubliclyDead(unit)
  local fill = colors.healthy
  if dead then
    fill = colors.dead or fill
  end
  local w = btn:GetWidth() or 20
  local petminus = 0
  if type(unit) == "string" and unit:find("pet") then
    petminus = 4
  end
  local inset = borderOn and BORDER_PX or 0
  local inner = math.max(4, w - inset * 2)
  btn.fillTex:ClearAllPoints()
  btn.fillTex:SetPoint("CENTER")
  btn.fillTex:SetSize(inner, inner)
  btn.inner:ClearAllPoints()
  btn.inner:SetPoint("CENTER")
  btn.inner:SetSize(inner, inner)
  local r, g, b, a = ClassBorderColor(unit, colors.border)
  for _, edge in ipairs({btn.outer1, btn.outer2, btn.outer3, btn.outer4}) do
    if edge then
      if borderOn then
        edge:SetColorTexture(r, g, b, pack.mufs.borderTransp or 0.2)
        edge:Show()
      else
        edge:Hide()
      end
    end
  end
  local idle = pack.mufs.centerTransp
  if type(idle) ~= "number" then
    idle = 0.35
  end
  local alpha = (fill[4] or 1) * idle
  if dead then
    alpha = pack.mufs.inactiveOpacity or 0.65
  elseif UnitIsConnected then
    local connected = UnitIsConnected(unit)
    if Accessible(connected) and connected == false then
      alpha = pack.mufs.inactiveOpacity or 0.65
    end
  end
  ApplyColor(btn.fillTex, fill, alpha)
  if btn.charmTex then
    btn.charmTex:Hide()
  end
  if btn.playerMark then
    if pack.mufs.centerText and IsPlayerToken(unit) then
      btn.playerMark:SetText("P")
      btn.playerMark:Show()
    else
      btn.playerMark:SetText("")
      btn.playerMark:Hide()
    end
  end
end

local function PlaceStatusLight(btn, size, enabled)
  local light = btn.statusLight
  if not light then
    return
  end
  local q = math.max(4, math.floor(size / 4))
  light:SetSize(q, q)
  light:ClearAllPoints()
  light:SetPoint("BOTTOM", btn, "TOP", 0, 1)
  if enabled then
    light:Show()
  else
    light:Hide()
  end
end

local function SpellInRange(unit, spell, spellId)
  local result
  if C_Spell and C_Spell.IsSpellInRange then
    if spellId then
      result = C_Spell.IsSpellInRange(spellId, unit)
    elseif spell then
      result = C_Spell.IsSpellInRange(spell, unit)
    end
  elseif IsSpellInRange and spell then
    result = IsSpellInRange(spell, unit)
  end
  if not Accessible(result) then
    return nil
  end
  if result == false or result == 0 then
    return false
  end
  if result == true or result == 1 then
    return true
  end
  return nil
end

local function UpdateStatusLights()
  if not poolReady then
    return
  end
  local pack = GetPack()
  local enabled = pack.mufs.statusLight
  local spell, spellId = ResolveCureSpell()
  for i = 1, #pool do
    local btn = pool[i]
    if btn.assigned and enabled then
      btn.statusLight:Show()
      local inRange = SpellInRange(btn.unit, spell, spellId)
      if inRange == false then
        btn.statusLight:SetColorTexture(1, 0.92, 0.2, 1)
      else
        btn.statusLight:SetColorTexture(0.25, 0.85, 0.4, 1)
      end
    elseif btn.statusLight then
      btn.statusLight:Hide()
    end
  end
end

local function HideCooldown(btn)
  if btn.cdTex then
    btn.cdTex:Hide()
  end
  if btn.cdText then
    btn.cdText:SetText("")
    btn.cdText:Hide()
  end
end

local function UpdateCooldowns()
  if not poolReady then
    return
  end
  local now = GetTime and GetTime() or 0
  if cooldownUntil <= now then
    cooldownUntil = 0
    cooldownSkipGUID = nil
    for i = 1, #pool do
      HideCooldown(pool[i])
    end
    return
  end
  local pack = GetPack()
  if not pack.alerts.cooldown then
    for i = 1, #pool do
      HideCooldown(pool[i])
    end
    return
  end
  local remain = cooldownUntil - now
  local opacity = pack.alerts.cooldownOpacity or 0.62
  local showNumbers = pack.alerts.cooldownNumbers
  for i = 1, #pool do
    local btn = pool[i]
    local skip = false
    if cooldownSkipGUID and btn.unit and UnitGUID then
      local guid = Public(UnitGUID(btn.unit))
      if guid and guid == cooldownSkipGUID then
        skip = true
      end
    end
    if not btn.assigned or skip then
      HideCooldown(btn)
    else
      btn.cdTex:SetColorTexture(0, 0, 0, opacity)
      btn.cdTex:Show()
      if showNumbers then
        btn.cdText:SetText(string.format("%.1f", remain))
        btn.cdText:Show()
      else
        btn.cdText:SetText("")
        btn.cdText:Hide()
      end
    end
  end
end

local function OnPlayerDispel(destGUID)
  local pack = GetPack()
  if not pack.alerts.cooldown then
    return
  end
  cooldownUntil = (GetTime and GetTime() or 0) + GCD
  cooldownSkipGUID = destGUID
  UpdateCooldowns()
end

local function OnCLEU()
  if not CombatLogGetCurrentEventInfo then
    return
  end
  local _timestamp, subevent, _hideCaster, sourceGUID, _sourceName, _sourceFlags, _sourceRaidFlags, destGUID = CombatLogGetCurrentEventInfo()
  subevent = Public(subevent)
  if subevent ~= "SPELL_DISPEL" then
    return
  end
  sourceGUID = Public(sourceGUID)
  local playerGUID = UnitGUID and Public(UnitGUID("player"))
  if not sourceGUID or not playerGUID or sourceGUID ~= playerGUID then
    return
  end
  OnPlayerDispel(Public(destGUID))
end

local function WireTooltip(btn)
  btn:SetScript("OnEnter", function(self)
    local pack = GetPack()
    if not pack.mufs.tooltip then
      return
    end
    local unit = self.unit
    if not unit or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

local function CreateMUF(parent)
  local btn = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
  btn:RegisterForClicks("AnyUp")
  btn:SetClampedToScreen(true)
  btn:SetFrameStrata("MEDIUM")
  btn:SetSize(20, 20)

  -- Alpha.4 four-side 2px class border + centered fill.
  btn.outer1 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer1:SetPoint("BOTTOMLEFT")
  btn.outer1:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, 2)
  btn.outer2 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer2:SetPoint("TOPLEFT", 0, -2)
  btn.outer2:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", 2, 2)
  btn.outer3 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer3:SetPoint("TOPLEFT")
  btn.outer3:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, -2)
  btn.outer4 = btn:CreateTexture(nil, "BORDER", nil, 1)
  btn.outer4:SetPoint("TOPRIGHT", 0, -2)
  btn.outer4:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", -2, 2)

  btn.fillTex = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
  btn.fillTex:SetPoint("CENTER")
  btn.fillTex:SetSize(16, 16)

  btn.inner = CreateFrame("Frame", nil, btn)
  btn.inner:SetPoint("CENTER")
  btn.inner:SetSize(16, 16)

  btn.charmTex = btn:CreateTexture(nil, "OVERLAY", nil, 6)
  btn.charmTex:SetPoint("TOPRIGHT")
  btn.charmTex:SetSize(7, 7)
  btn.charmTex:Hide()

  btn.playerMark = btn:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
  btn.playerMark:SetPoint("CENTER", 1.6, 0)
  btn.playerMark:SetPoint("BOTTOM", 0, 1)
  btn.playerMark:SetText("")
  btn.playerMark:Hide()

  btn.cdTex = btn:CreateTexture(nil, "OVERLAY")
  btn.cdTex:SetAllPoints()
  btn.cdTex:SetColorTexture(0, 0, 0, 0.62)
  btn.cdTex:Hide()

  btn.cdText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  btn.cdText:SetPoint("CENTER")
  btn.cdText:SetTextColor(1, 1, 1, 1)
  btn.cdText:Hide()

  btn.statusLight = btn:CreateTexture(nil, "OVERLAY")
  btn.statusLight:SetColorTexture(0.25, 0.85, 0.4, 1)
  btn.statusLight:Hide()
  btn.statusLight:SetSize(6, 6)

  WireTooltip(btn)
  btn:Hide()
  return btn
end

local function EnsurePool()
  if poolReady or LockedDown() then
    return poolReady
  end
  if not header then
    return false
  end
  for i = 1, POOL_SIZE do
    pool[i] = CreateMUF(header)
  end
  poolReady = true
  return true
end

local function OnHeaderUpdate(_self, elapsed)
  if cooldownUntil > 0 then
    UpdateCooldowns()
  end
  local pack = GetPack()
  if pack.mufs.statusLight then
    rangeElapsed = rangeElapsed + (elapsed or 0)
    if rangeElapsed >= 0.15 then
      rangeElapsed = 0
      UpdateStatusLights()
    end
  end
end

local function EnsureHeader()
  if header then
    return true
  end
  if LockedDown() then
    return false
  end
  header = CreateFrame("Frame", "DecursiveRebuildMUFHeader", UIParent)
  header:SetSize(30, 30)
  header:SetClampedToScreen(true)
  header:SetMovable(true)
  header:EnableMouse(false)
  header:SetFrameStrata("MEDIUM")
  RestorePoint()

  -- Alpha.4 DcrMUFsContainerDragButton: 20x20 square on the top-left of the grid.
  handle = CreateFrame("Button", "DecursiveRebuildMUFHandle", header)
  handle:SetSize(20, 20)
  handle:SetClampedToScreen(true)
  handle:SetPoint("BOTTOMLEFT", header, "TOPLEFT", 0, 0)
  -- Alpha.4 handle is blank until hover. Highlight only, ADD blend.
  handle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  handle:RegisterForClicks("AnyUp")
  handle.isMoving = false
  handle:SetScript("OnMouseDown", function(self, button)
    if LockedDown() then
      return
    end
    local pack = GetPack()
    if pack.mufs.locked then
      return
    end
    if button == "LeftButton" and IsAltKeyDown and IsAltKeyDown() then
      self.isMoving = true
      header:StartMoving()
    end
  end)
  handle:SetScript("OnMouseUp", function(self, button)
    if self.isMoving and not LockedDown() then
      header:StopMovingOrSizing()
      self.isMoving = false
      SavePoint()
    elseif button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
      if ns.ShowOptions then
        ns.ShowOptions()
      end
    end
  end)
  handle:SetScript("OnHide", function(self)
    if self.isMoving and not LockedDown() then
      header:StopMovingOrSizing()
    end
    self.isMoving = false
  end)
  handle:SetScript("OnEnter", function(self)
    local pack = GetPack()
    if pack.mufs.showHelp == false then
      return
    end
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Zhaohu's Decursive")
    GameTooltip:AddLine("Alt-Left: move MUFs", 0.32, 0.86, 0.82)
    GameTooltip:AddLine("Alt-Right: options", 0.32, 0.86, 0.82)
    GameTooltip:Show()
  end)
  handle:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  header:SetScript("OnUpdate", OnHeaderUpdate)
  return true
end

local function HideAll()
  if header then
    header:Hide()
  end
  if not poolReady then
    return
  end
  for i = 1, #pool do
    local btn = pool[i]
    btn.assigned = false
    btn.unit = nil
    btn:SetAttribute("unit", nil)
    ClearClickAttributes(btn)
    btn:Hide()
  end
end

function ns.LayoutMUFs()
  if LockedDown() then
    pending = true
    return
  end
  if not EnsureHeader() then
    pending = true
    return
  end
  if not EnsurePool() then
    pending = true
    return
  end

  local pack = GetPack()
  local env = GetEnv()
  if not ShouldShowHeader(pack) then
    HideAll()
    return
  end

  local units = BuildRoster(pack)
  local maxUnits = pack.mufs.maxUnits or POOL_SIZE
  if maxUnits > POOL_SIZE then
    maxUnits = POOL_SIZE
  end
  if maxUnits < 0 then
    maxUnits = 0
  end
  if #units > maxUnits then
    for i = #units, maxUnits + 1, -1 do
      units[i] = nil
    end
  end

  local size = PixelSize(pack, env)
  local hSpace, vSpace = Spacing(pack)
  local perLine = pack.mufs.unitsPerLine or 10
  if perLine < 1 then
    perLine = 1
  end
  local growUp = pack.mufs.growUp
  local growFromRight = pack.mufs.growFromRight
  local verticalLayout = pack.mufs.verticalLayout
  local n = #units
  local cols
  local rows
  if verticalLayout then
    rows = math.min(perLine, n)
    cols = math.ceil(math.max(n, 1) / perLine)
  else
    cols = math.min(perLine, n)
    rows = math.ceil(math.max(n, 1) / perLine)
  end
  if n == 0 then
    cols, rows = 1, 1
  end
  local width = cols * size + math.max(cols - 1, 0) * hSpace
  local height = rows * size + math.max(rows - 1, 0) * vSpace
  header:SetSize(math.max(width, 8), math.max(height, 8))
  header:SetScale(pack.mufs.scale or 1)
  header:SetMovable(not pack.mufs.locked)
  header:Show()

  if pack.mufs.hideHandle then
    handle:Hide()
    handle:EnableMouse(false)
  else
    handle:Show()
    handle:EnableMouse(true)
  end

  local anchor
  if growFromRight and growUp then
    anchor = "BOTTOMRIGHT"
  elseif growFromRight then
    anchor = "TOPRIGHT"
  elseif growUp then
    anchor = "BOTTOMLEFT"
  else
    anchor = "TOPLEFT"
  end
  local xDir = growFromRight and -1 or 1
  local yDir = growUp and 1 or -1

  for i = 1, POOL_SIZE do
    local btn = pool[i]
    local unit = units[i]
    if unit then
      local index = i - 1
      local line
      local slot
      if verticalLayout then
        line = math.floor(index / perLine)
        slot = index % perLine
        btn:ClearAllPoints()
        btn:SetPoint(anchor, header, anchor, line * (size + hSpace) * xDir, slot * (size + vSpace) * yDir)
      else
        line = math.floor(index / perLine)
        slot = index % perLine
        btn:ClearAllPoints()
        btn:SetPoint(anchor, header, anchor, slot * (size + hSpace) * xDir, line * (size + vSpace) * yDir)
      end
      local mufSize = size
      if type(unit) == "string" and unit:find("pet") then
        mufSize = math.max(8, size - 4)
      end
      btn:SetSize(mufSize, mufSize)
      btn.unit = unit
      btn.assigned = true
      ApplyClickAttributes(btn, pack, unit)
      PaintSquare(btn, pack, unit)
      PlaceStatusLight(btn, size, pack.mufs.statusLight)
      AttachAuraContainer(btn, pack)
      if btn.auraContainer and btn.auraContainer.SetUnit then
        btn.auraContainer:SetUnit(unit)
      end
      btn:Show()
    else
      btn.assigned = false
      btn.unit = nil
      btn:SetAttribute("unit", nil)
      ClearClickAttributes(btn)
      btn:Hide()
    end
  end

  if handle and not pack.mufs.hideHandle then
    local first
    for i = 1, POOL_SIZE do
      if pool[i] and pool[i].assigned then
        first = pool[i]
        break
      end
    end
    if first then
      local w = first:GetWidth() or size
      handle:SetSize(w, w)
      handle:ClearAllPoints()
      if pack.mufs.growUp then
        handle:SetPoint("TOP", first, "BOTTOM", 0, 0)
      else
        handle:SetPoint("BOTTOM", first, "TOP", 0, 0)
      end
    end
  end

  UpdateStatusLights()
  UpdateCooldowns()
end

function ns.RefreshMUFs()
  if LockedDown() then
    pending = true
    return
  end
  pending = false
  ns.LayoutMUFs()
end

local function RegisterExtraEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event)
    if event == "SPELLS_CHANGED" then
      cureName = nil
      cureId = nil
      ns.RefreshMUFs()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      OnCLEU()
    elseif event == "UNIT_PET" then
      ns.RefreshMUFs()
    end
  end)
  eventFrame:RegisterEvent("SPELLS_CHANGED")
  eventFrame:RegisterEvent("UNIT_PET")
  local valid = true
  if C_EventUtils and C_EventUtils.IsEventValid then
    valid = C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")
  end
  if valid then
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

function ns.EnableMUFs(_addon)
  RegisterExtraEvents()
  ns.RefreshMUFs()
end
