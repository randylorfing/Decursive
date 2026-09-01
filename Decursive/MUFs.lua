local ADDON_NAME, ns = ...

local POOL_SIZE = 80
local BORDER_PX = 2
local GCD = 1.5
local WHITE = "Interface\\Buttons\\WHITE8x8"
local MACRO_BYTE_LIMIT = 255
local PVP_BANDAGE_SPELL = 212640
local SOUL_LINK_ITEM_ID = 269586

local FRIENDLY_TYPES = {
  magic = true,
  curse = true,
  poison = true,
  disease = true,
  bleed = true,
}

local MOUSE_BUTTONS = {
  {key = "left", index = 1, binding = "*%s1"},
  {key = "right", index = 2, binding = "*%s2"},
  {key = "middle", index = 3, binding = "*%s3"},
  {key = "button4", index = 4, binding = "*%s4"},
  {key = "button5", index = 5, binding = "*%s5"},
}

local AUTO_CURE_GESTURES = {
  "*%s1",
  "*%s2",
  "ctrl-%s1",
}

local TARGET_GESTURE = "*%s3"
local FOCUS_GESTURE = "ctrl-%s3"
local PVP_BANDAGE_GESTURE = "*%s5"
local PHYSICAL_LEFT = "*%s1"

local GESTURE_PREFIXES = {"", "*", "ctrl-", "shift-", "alt-"}

local header
local handle
local pool = {}
local poolReady = false
local pending = false
local eventsOn = false
local eventFrame
local cooldownUntil = 0
local cooldownSkipGUID
local rangeElapsed = 0
local mufsConfigured = false
local clickModel
local clickModelSig

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
    customDispelColorMap = (ns.GetDispelColorMap and ns.GetDispelColorMap(pack)) or DispelColorMap(pack),
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

local function DistinctFriendlyCures(pack)
  local actions = ns.GetKnownCures and ns.GetKnownCures(pack) or {}
  local out = {}
  local seen = {}
  for i = 1, #actions do
    local action = actions[i]
    local spellId = action and action.spellId
    local name = action and action.name
    if type(spellId) == "number" and not seen[spellId] and type(name) == "string" and name ~= "" then
      local types = action.types
      local friendly = false
      if type(types) == "table" then
        for t = 1, #types do
          if FRIENDLY_TYPES[types[t]] then
            friendly = true
            break
          end
        end
      end
      if friendly then
        seen[spellId] = true
        out[#out + 1] = action
      end
    end
  end
  return out
end

local function BuildSmartRezMacroText(cureCommand, cureName, cureUsesPet)
  local battleRezName, outOfCombatRezName, combatSoulLink, outOfCombatSoulLink
  if ns.GetSmartRezActions then
    battleRezName, outOfCombatRezName, combatSoulLink, outOfCombatSoulLink = ns.GetSmartRezActions(GetPack())
  end
  local hasRezAction = battleRezName ~= nil or outOfCombatRezName ~= nil or combatSoulLink or outOfCombatSoulLink
  local combatClause = "[@mouseover,help,exists,dead,combat]"
  local outOfCombatClause = "[@mouseover,help,exists,dead,nocombat]"
  local friendlyCureClause = "[@mouseover,help,exists,nodead]"
  local hostileCureClause = "[@mouseover,harm,exists,nodead]"

  local function build(includeRez, includeCure)
    local lines = {}
    local castActions = {}
    local useActions = {}
    if includeRez then
      if battleRezName and outOfCombatRezName == battleRezName then
        castActions[#castActions + 1] = combatClause .. outOfCombatClause .. " " .. battleRezName
      else
        if battleRezName then
          castActions[#castActions + 1] = combatClause .. " " .. battleRezName
        end
        if outOfCombatRezName then
          castActions[#castActions + 1] = outOfCombatClause .. " " .. outOfCombatRezName
        end
      end
      if combatSoulLink and outOfCombatSoulLink then
        useActions[#useActions + 1] = combatClause .. outOfCombatClause .. " item:269586"
      else
        if combatSoulLink then
          useActions[#useActions + 1] = combatClause .. " item:269586"
        end
        if outOfCombatSoulLink then
          useActions[#useActions + 1] = outOfCombatClause .. " item:269586"
        end
      end
    end
    if includeCure and type(cureName) == "string" and cureName ~= "" then
      local cureAction = friendlyCureClause .. hostileCureClause .. " " .. cureName
      if cureCommand == "use" then
        useActions[#useActions + 1] = cureAction
      else
        castActions[#castActions + 1] = cureAction
      end
    end
    if includeRez and hasRezAction then
      if includeCure and cureUsesPet then
        lines[#lines + 1] = "/stopcasting [@mouseover,help,exists,dead]"
      else
        lines[#lines + 1] = "/stopcasting"
      end
    elseif includeCure and not cureUsesPet then
      lines[#lines + 1] = "/stopcasting"
    end
    if #castActions > 0 then
      lines[#lines + 1] = "/cast " .. table.concat(castActions, ";")
    end
    if #useActions > 0 then
      lines[#lines + 1] = "/use " .. table.concat(useActions, ";")
    end
    return table.concat(lines, "\n")
  end

  local combined = build(true, cureName ~= nil)
  local cureOnly = build(false, cureName ~= nil)
  local rezOnly = build(true, false)
  return combined, cureOnly, rezOnly, hasRezAction
end

local function MakeCureRow(action, binding)
  if type(action) ~= "table" or type(action.name) ~= "string" or action.name == "" then
    return nil
  end
  local spellId = action.spellId or 0
  local command = "use"
  if type(spellId) == "number" and spellId > 0 then
    command = "cast"
  end
  local combined, cureOnly, rezOnly, hasRez = BuildSmartRezMacroText(command, action.name, action.pet == true)
  if type(cureOnly) ~= "string" or #cureOnly > MACRO_BYTE_LIMIT then
    return nil
  end
  local row = {
    binding = binding,
    actionKey = "spell:" .. tostring(spellId),
    spellName = action.name,
    spellId = spellId,
    cureOnlyMacroText = cureOnly,
    rezOnlyMacroText = "",
    smartRezAvailable = false,
    customMacro = false,
  }
  if type(combined) == "string" and #combined <= MACRO_BYTE_LIMIT then
    row.macroText = combined
    row.smartRezAvailable = hasRez == true
  else
    row.macroText = cureOnly
    row.smartRezAvailable = false
  end
  if type(rezOnly) == "string" and #rezOnly <= MACRO_BYTE_LIMIT then
    row.rezOnlyMacroText = rezOnly
  else
    row.rezOnlyMacroText = ""
  end
  return row
end

local function ScanPvPBandage()
  if LockedDown() then
    return clickModel and clickModel.bandage or nil
  end
  local itemAPI = C_Item
  local containerAPI = C_Container
  if type(itemAPI) ~= "table" or type(containerAPI) ~= "table" then
    return nil
  end
  if type(itemAPI.GetItemSpell) ~= "function" or type(containerAPI.GetContainerNumSlots) ~= "function" then
    return nil
  end
  local first = 0
  local last = NUM_BAG_SLOTS or 4
  local bagEnum = Enum and Enum.BagIndex
  if bagEnum and type(bagEnum.Backpack) == "number" then
    first = bagEnum.Backpack
  end
  local best
  for bag = first, last do
    local okSlots, nSlots = pcall(containerAPI.GetContainerNumSlots, bag)
    if okSlots and type(nSlots) == "number" and nSlots > 0 then
      for slot = 1, nSlots do
        local okInfo, info = pcall(containerAPI.GetContainerItemInfo, bag, slot)
        if okInfo and type(info) == "table" then
          local itemID = info.itemID
          if type(itemID) == "number" and Accessible(itemID) and itemID > 0 then
            local okSpell, _name, useSpellID = pcall(itemAPI.GetItemSpell, itemID)
            if okSpell and Accessible(useSpellID) and useSpellID == PVP_BANDAGE_SPELL then
              local count = 0
              if itemAPI.GetItemCount then
                local okCount, c = pcall(itemAPI.GetItemCount, itemID, false, false, false, false)
                if okCount and Accessible(c) and type(c) == "number" then
                  count = c
                end
              end
              if count > 0 then
                local usable = true
                if itemAPI.IsUsableItem then
                  local okUse, u = pcall(itemAPI.IsUsableItem, itemID)
                  if okUse and Accessible(u) then
                    usable = u == true
                  end
                end
                if usable then
                  best = {itemID = itemID, actionKey = "pvp-bandage:item:" .. tostring(itemID)}
                end
              end
            end
          end
        end
      end
    end
  end
  return best
end

local function CustomMacroText()
  local pack = GetPack()
  local advanced = pack.advanced
  if type(advanced) ~= "table" or advanced.allowMacroEdit ~= true then
    return nil
  end
  local text = advanced.customMacro
  if type(text) ~= "string" or text == "" then
    return nil
  end
  text = text:gsub("UNITID", "mouseover")
  if #text > MACRO_BYTE_LIMIT then
    return nil
  end
  return text
end

local function ClickSignature(pack)
  local bits = {}
  bits[#bits + 1] = pack.cure and pack.cure.mode or "AUTO"
  local mouse = pack.mouse or {}
  bits[#bits + 1] = tostring(mouse.left)
  bits[#bits + 1] = tostring(mouse.right)
  bits[#bits + 1] = tostring(mouse.middle)
  bits[#bits + 1] = tostring(mouse.button4)
  bits[#bits + 1] = tostring(mouse.button5)
  local cures = DistinctFriendlyCures(pack)
  for i = 1, #cures do
    bits[#bits + 1] = tostring(cures[i].spellId)
  end
  local advanced = pack.advanced
  if type(advanced) == "table" then
    bits[#bits + 1] = tostring(advanced.allowMacroEdit)
    bits[#bits + 1] = tostring(advanced.customMacro)
  end
  return table.concat(bits, "|")
end

local function ReservedGesture(binding)
  return binding == TARGET_GESTURE or binding == FOCUS_GESTURE
end

local function BandageRow(bandage)
  if not bandage or type(bandage.itemID) ~= "number" then
    return nil
  end
  local macro = ("/use [@mouseover,help,exists,nodead] item:%d"):format(bandage.itemID)
  if #macro > MACRO_BYTE_LIMIT then
    return nil
  end
  return {
    binding = PVP_BANDAGE_GESTURE,
    macroText = macro,
    cureOnlyMacroText = macro,
    rezOnlyMacroText = "",
    smartRezAvailable = false,
    pvpBandage = true,
    actionKey = bandage.actionKey,
  }
end

function ns.RebuildClickModel(pack)
  if LockedDown() then
    pending = true
    return clickModel
  end
  pack = pack or GetPack()
  local sig = ClickSignature(pack)
  if clickModel and clickModelSig == sig then
    return clickModel
  end
  local mode = pack.cure and pack.cure.mode
  if mode ~= "MANUAL" then
    mode = "AUTO"
  end
  local cures = DistinctFriendlyCures(pack)
  local bandage = ScanPvPBandage()
  local rows = {}
  local used = {
    [TARGET_GESTURE] = true,
    [FOCUS_GESTURE] = true,
  }
  if bandage then
    used[PVP_BANDAGE_GESTURE] = true
  end

  if mode == "AUTO" then
    for i = 1, #AUTO_CURE_GESTURES do
      local action = cures[i]
      if action then
        local row = MakeCureRow(action, AUTO_CURE_GESTURES[i])
        if row then
          rows[#rows + 1] = row
          used[row.binding] = true
        end
      end
    end
  else
    local mouse = pack.mouse or {}
    local manual = pack.cure and pack.cure.manual
    local assigned = {}
    if type(manual) == "table" then
      local keyToBinding = {
        left = "*%s1",
        right = "*%s2",
        button4 = "*%s4",
        button5 = "*%s5",
      }
      for i = 1, #cures do
        local action = cures[i]
        local actionKey = "spell:" .. tostring(action.spellId)
        local binding = keyToBinding[manual[actionKey]]
        if binding and not ReservedGesture(binding) and not used[binding] then
          if not (bandage and binding == PVP_BANDAGE_GESTURE) then
            local row = MakeCureRow(action, binding)
            if row then
              rows[#rows + 1] = row
              used[binding] = true
              assigned[action.spellId] = true
            end
          end
        end
      end
    end
    local cureIndex = 1
    for i = 1, #MOUSE_BUTTONS do
      local spec = MOUSE_BUTTONS[i]
      local binding = spec.binding
      if not ReservedGesture(binding) and not used[binding] and mouse[spec.key] == "CURE" then
        if not (bandage and binding == PVP_BANDAGE_GESTURE) then
          while cureIndex <= #cures and assigned[cures[cureIndex].spellId] do
            cureIndex = cureIndex + 1
          end
          local action = cures[cureIndex]
          if action then
            local row = MakeCureRow(action, binding)
            if row then
              rows[#rows + 1] = row
              used[binding] = true
              assigned[action.spellId] = true
              cureIndex = cureIndex + 1
            end
          end
        end
      end
    end
  end

  local bandageRow = BandageRow(bandage)
  if bandageRow then
    rows[#rows + 1] = bandageRow
  end

  local custom = CustomMacroText()
  if custom then
    local replaced = false
    for i = 1, #rows do
      if rows[i].binding == PHYSICAL_LEFT then
        rows[i].macroText = custom
        rows[i].cureOnlyMacroText = custom
        rows[i].customMacro = true
        rows[i].smartRezAvailable = false
        replaced = true
        break
      end
    end
    if not replaced then
      rows[#rows + 1] = {
        binding = PHYSICAL_LEFT,
        macroText = custom,
        cureOnlyMacroText = custom,
        rezOnlyMacroText = "",
        customMacro = true,
        smartRezAvailable = false,
      }
    end
  end

  clickModel = {
    mode = mode,
    rows = rows,
    bandage = bandage,
  }
  clickModelSig = sig
  return clickModel
end

local function SetSecure(btn, attr, value)
  if LockedDown() then
    return false
  end
  btn:SetAttribute(attr, value)
  return true
end

local function ClearClickAttributes(btn)
  if LockedDown() then
    return
  end
  for i = 1, 5 do
    for p = 1, #GESTURE_PREFIXES do
      local prefix = GESTURE_PREFIXES[p]
      btn:SetAttribute(prefix .. "type" .. i, nil)
      btn:SetAttribute(prefix .. "spell" .. i, nil)
      btn:SetAttribute(prefix .. "macro" .. i, nil)
      btn:SetAttribute(prefix .. "macrotext" .. i, nil)
      btn:SetAttribute(prefix .. "unit" .. i, nil)
    end
  end
end

local function RezEligible(unit)
  if ns.IsMUFRezEligibleUnitToken then
    return ns.IsMUFRezEligibleUnitToken(unit) == true
  end
  if type(unit) ~= "string" then
    return false
  end
  return not unit:lower():find("pet", 1, true)
end

local function ApplyClickAttributes(btn, pack, unit)
  if LockedDown() then
    pending = true
    return false
  end
  ClearClickAttributes(btn)
  SetSecure(btn, "unit", unit)
  local model = ns.RebuildClickModel(pack)
  if not model then
    return false
  end

  SetSecure(btn, TARGET_GESTURE:format("type"), "target")
  SetSecure(btn, TARGET_GESTURE:format("unit"), unit)
  SetSecure(btn, FOCUS_GESTURE:format("type"), "focus")
  SetSecure(btn, FOCUS_GESTURE:format("unit"), unit)

  local installed = {
    [TARGET_GESTURE] = true,
    [FOCUS_GESTURE] = true,
  }
  local rezOk = RezEligible(unit)
  local leftAssigned = false
  local leftReserved = false

  for i = 1, #model.rows do
    local row = model.rows[i]
    local binding = row.binding
    if binding then
      if binding == PHYSICAL_LEFT and row.customMacro then
        leftReserved = true
      end
      local macroText
      if binding == PHYSICAL_LEFT and rezOk and row.smartRezAvailable then
        macroText = row.macroText
      else
        macroText = row.cureOnlyMacroText or row.macroText
      end
      if type(macroText) == "string" and macroText ~= "" and #macroText <= MACRO_BYTE_LIMIT then
        SetSecure(btn, binding:format("type"), "macro")
        SetSecure(btn, binding:format("macrotext"), macroText)
        installed[binding] = true
        if binding == PHYSICAL_LEFT then
          leftAssigned = true
        end
      end
    end
  end

  if rezOk and not leftReserved and not leftAssigned then
    local leftover
    for i = 1, #model.rows do
      if type(model.rows[i].rezOnlyMacroText) == "string" then
        leftover = model.rows[i].rezOnlyMacroText
        break
      end
    end
    if leftover == nil then
      local _combined, _cure, rezOnly = BuildSmartRezMacroText("cast", nil, false)
      leftover = rezOnly
    end
    if leftover ~= "" and type(leftover) == "string" and #leftover <= MACRO_BYTE_LIMIT then
      SetSecure(btn, PHYSICAL_LEFT:format("type"), "macro")
      SetSecure(btn, PHYSICAL_LEFT:format("macrotext"), leftover)
      leftAssigned = true
      installed[PHYSICAL_LEFT] = true
    end
  end

  if model.mode == "MANUAL" then
    local mouse = pack.mouse or {}
    for i = 1, #MOUSE_BUTTONS do
      local spec = MOUSE_BUTTONS[i]
      local binding = spec.binding
      if not installed[binding] and not ReservedGesture(binding) then
        local action = mouse[spec.key]
        if action == "TARGET" then
          SetSecure(btn, binding:format("type"), "target")
          SetSecure(btn, binding:format("unit"), unit)
        elseif action == "FOCUS" then
          SetSecure(btn, binding:format("type"), "focus")
          SetSecure(btn, binding:format("unit"), unit)
        elseif action == "ASSIST" then
          SetSecure(btn, binding:format("type"), "assist")
          SetSecure(btn, binding:format("unit"), unit)
        end
      end
    end
  end
  return true
end

local function AttachPaint(btn, pack, unit)
  if type(unit) ~= "string" or unit == "" then
    return
  end
  if LockedDown() then
    pending = true
    return
  end
  local function initFn(frame)
    BindAuraSlot(frame, pack)
  end
  if btn.auraContainer then
    if ns.AttachDetectionContainer then
      ns.AttachDetectionContainer(btn.auraContainer, unit, pack, initFn)
    end
    return
  end
  if ns.AttachDetector then
    btn.auraContainer = ns.AttachDetector(btn.inner, unit, pack, initFn)
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
  if pack.mufs.dimOutOfRange and ns.SpellRangeState then
    local spell, spellId
    if ns.GetPrimaryCure then
      spell, spellId = ns.GetPrimaryCure(pack)
    end
    if ns.SpellRangeState(unit, spell, spellId) ~= true then
      local dim = pack.mufs.dimAmount
      if type(dim) ~= "number" then
        dim = 0.45
      end
      alpha = alpha * dim
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

local function UpdateStatusLights()
  if not poolReady then
    return
  end
  local pack = GetPack()
  local enabled = pack.mufs.statusLight
  local spell, spellId
  if ns.GetPrimaryCure then
    spell, spellId = ns.GetPrimaryCure(pack)
  end
  for i = 1, #pool do
    local btn = pool[i]
    if btn.assigned and enabled then
      btn.statusLight:Show()
      local inRange = true
      if ns.SpellRangeState then
        inRange = ns.SpellRangeState(btn.unit, spell, spellId) == true
      end
      if inRange ~= true then
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
  if poolReady then
    return true
  end
  if LockedDown() then
    return false
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
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return
  end
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
    mufsConfigured = false
    return
  end
  if not EnsureHeader() then
    pending = true
    mufsConfigured = false
    return
  end
  if not EnsurePool() then
    pending = true
    mufsConfigured = false
    return
  end

  local pack = GetPack()
  ns.RebuildClickModel(pack)
  local env = GetEnv()
  if not ShouldShowHeader(pack) then
    HideAll()
    return
  end

  local units = ns.BuildRoster and ns.BuildRoster(pack) or {}
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
      AttachPaint(btn, pack, unit)
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
  mufsConfigured = true
end

function ns.RefreshMUFs()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return
  end
  pending = false
  ns.LayoutMUFs()
end

function ns.RecoverMUFsAfterCombat()
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return false
  end
  if not EnsureHeader() then
    pending = true
    mufsConfigured = false
    return false
  end
  if not EnsurePool() then
    pending = true
    mufsConfigured = false
    return false
  end
  pending = false
  ns.LayoutMUFs()
  return mufsConfigured == true
end

function ns.MUFsConfigured()
  return mufsConfigured == true
end

local function RegisterExtraEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event)
    if event == "SPELLS_CHANGED" then
      if ns.InvalidateDetection then
        ns.InvalidateDetection()
      end
      if LockedDown() then
        pending = true
        return
      end
      clickModel = nil
      clickModelSig = nil
      ns.RefreshMUFs()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      OnCLEU()
    elseif event == "UNIT_PET" then
      if LockedDown() then
        pending = true
        return
      end
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
  if LockedDown() then
    pending = true
    mufsConfigured = false
    return
  end
  ns.RefreshMUFs()
end
