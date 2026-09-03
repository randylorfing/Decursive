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
  ns.DiagnosticCheckpoint("module", "LiveList file start")
end

local MAX_ROWS = 20
local ROW_W = 180
local ROW_H = 32
local ICON = 32
local HANDLE_H = 18
local TEAL = {0.32, 0.86, 0.82, 1}
local TEXT = {0.88, 0.93, 0.96, 1}
local MUTED = {0.50, 0.60, 0.66, 1}

local TYPE_LABELS = {
  Magic = "Magic",
  Curse = "Curse",
  Poison = "Poison",
  Disease = "Disease",
  None = "Afflicted",
}

local header
local handle
local pool = {}
local poolReady = false
local pending = false
local eventsOn = false
local eventFrame
local scanElapsed = 0

local function Addon()
  return ns.addon
end

local function GetPack()
  local addon = Addon()
  if addon and addon.GetAppliedEnvironmentPack then
    return addon:GetAppliedEnvironmentPack()
  end
  return ns.PACK
end

local function Accessible(value)
  return ns.IsAccessible(value)
end

local function Public(value)
  return ns.PublicValue(value)
end

local function LockedDown()
  return InCombatLockdown and InCombatLockdown()
end

local function IsPubliclyDead(unit)
  return ns.IsUnitDeadPublic(unit)
end

local function ResolveCureSpell()
  return ns.GetPrimaryCure(GetPack())
end

local function SpellInRange(unit, spell, spellId)
  return ns.SpellRangeState(unit, spell, spellId)
end

local function BuildRoster(pack)
  return ns.BuildRoster(pack)
end

local function FilterRange(units, pack)
  return ns.FilterRosterRange(units, pack)
end

local function GetSavedPoint()
  local addon = Addon()
  local char = addon and addon.db and addon.db.char
  if char then
    if type(char.liveListPoint) ~= "table" then
      char.liveListPoint = {point = "CENTER", x = 220, y = 80}
    end
    return char.liveListPoint
  end
  return {point = "CENTER", x = 220, y = 80}
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
  header:SetPoint(point, UIParent, point, saved.x or 220, saved.y or 80)
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

local function BindLiveSlot(slot)
  if not slot then
    return
  end
  if slot._decursiveLiveBound then
    return
  end
  slot._decursiveLiveBound = true
  slot:ClearAllPoints()
  slot:SetSize(ICON, ICON)
  slot:SetPoint("TOPLEFT", 0, 0)
  if slot.EnableMouse then
    slot:EnableMouse(false)
  end

  local icon = slot:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON, ICON)
  icon:SetPoint("TOPLEFT", 0, 0)
  if slot.SetIcon then
    slot:SetIcon(icon)
  end

  local count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  count:SetTextColor(1, 0.12, 0.22)
  if slot.SetApplicationCount then
    slot:SetApplicationCount(count, {})
  end

  local dur = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  dur:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, 1)
  dur:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  if slot.SetDurationText then
    slot:SetDurationText(dur, {})
  end

  local spell = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  spell:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -14)
  spell:SetWidth(110)
  spell:SetJustifyH("LEFT")
  spell:SetTextColor(0.32, 0.86, 0.82)
  if slot.SetSpellName then
    slot:SetSpellName(spell)
  end

  local dtype = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dtype:SetPoint("TOPLEFT", icon, "TOPRIGHT", 78, -2)
  dtype:SetWidth(64)
  dtype:SetJustifyH("RIGHT")
  dtype:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
  if slot.SetDispelTypeText then
    slot:SetDispelTypeText(dtype, {
      showWhenHarmful = true,
      showWhenHelpful = false,
      showWithoutDispelType = false,
      customDispelTextMap = TYPE_LABELS,
    })
  end
end

local function AttachAuraContainer(row)
  if row.auraSkipped then
    return false
  end
  local unit = row.unit
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  local function initSlot(frame)
    BindLiveSlot(frame)
  end
  local engine = ns.DetectionEngine
  if engine and type(engine.BindCarrier) == "function" then
    local container, assigned, status = engine:BindCarrier("LiveList", row, unit, initSlot, row)
    row.auraContainer = container or row.auraContainer
    if assigned and row.auraContainer then
      row._dcrDetectUnit = unit
    end
    return assigned == true, status or (assigned and "SUCCESS" or "FAILURE")
  end
  if row.auraContainer then
    local container = row.auraContainer
    if container.SetUnit and row._dcrDetectUnit ~= unit then
      local assigned, status = ns.SafeNativeSetUnit(container, unit)
      if not assigned then
        pending = true
        return false, status == "DEFERRED_RESTRICTION" and "DEFERRED_RESTRICTED" or status
      end
      row._dcrDetectUnit = unit
    end
    if ns.ApplyDetectionSlots then
      ns.ApplyDetectionSlots(container, GetPack(), initSlot, unit)
    end
    if container.SetEnabled then
      container:SetEnabled(true)
    end
    return true
  end
  if LockedDown() then
    pending = true
    return false
  end
  if ns.AttachDetector then
    local container = ns.AttachDetector(row, unit, GetPack(), initSlot)
    if container then
      row.auraContainer = container
      row._dcrDetectUnit = unit
    else
      row.auraSkipped = true
    end
    return row.auraContainer ~= nil
  end
  local container = MakeAuraContainer(row)
  if not container then
    row.auraSkipped = true
    return false
  end
  container:SetAllPoints(row)
  if container.EnableMouse then
    container:EnableMouse(false)
  end
  if container.SetUnit then
    local assigned, status = ns.SafeNativeSetUnit(container, unit)
    if not assigned then
      pending = true
      return false, status == "DEFERRED_RESTRICTION" and "DEFERRED_RESTRICTED" or status
    end
  end
  if ns.ApplyDetectionSlots then
    ns.ApplyDetectionSlots(container, GetPack(), initSlot, unit)
  elseif container.AddAuraSlot then
    container:AddAuraSlot("dispel", ns.NATIVE_DISPEL_FILTER or "HARMFUL|RAID_PLAYER_DISPELLABLE", {
      initializeFrame = initSlot,
    })
  end
  if container.SetEnabled then
    container:SetEnabled(true)
  end
  row.auraContainer = container
  row._dcrDetectUnit = unit
  return true
end

local function ClassColor(unit)
  if not UnitClass then
    return TEXT[1], TEXT[2], TEXT[3]
  end
  local _name, classFile = UnitClass(unit)
  classFile = Public(classFile)
  if type(classFile) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return c.r or TEXT[1], c.g or TEXT[2], c.b or TEXT[3]
  end
  return TEXT[1], TEXT[2], TEXT[3]
end

local function UnitLabel(unit)
  if UnitName then
    local name = Public(UnitName(unit))
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return unit
end

local function PaintRow(row, pack, unit)
  local colors = pack.colors or {}
  local dead = IsPubliclyDead(unit)
  local fill = colors.healthy or {0.05, 0.09, 0.12, 1}
  if dead then
    fill = colors.dead or fill
  end
  local spell, spellId = ResolveCureSpell()
  local inRange = SpellInRange(unit, spell, spellId)
  if inRange == false then
    fill = colors.range or fill
  end
  row.bg:SetColorTexture(fill[1] or 0.05, fill[2] or 0.09, fill[3] or 0.12, fill[4] or 0.92)
  local r, g, b = ClassColor(unit)
  if dead then
    r, g, b = MUTED[1], MUTED[2], MUTED[3]
  end
  row.nameFS:SetText(UnitLabel(unit))
  row.nameFS:SetTextColor(r, g, b)
  row.tokenFS:SetText(unit)
  row.tokenFS:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  if inRange == false then
    row.rangeFS:SetText("oor")
    row.rangeFS:SetTextColor(1, 0.85, 0.2)
  elseif dead then
    row.rangeFS:SetText("dead")
    row.rangeFS:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  else
    row.rangeFS:SetText("")
  end
end

local function WireRow(row)
  row:RegisterForClicks("AnyUp")
  row:SetAttribute("*type1", "target")
  row:SetAttribute("*type2", "focus")
  row:SetAttribute("*type3", "assist")
  row:SetScript("OnEnter", function(self)
    local unit = self.unit
    if not unit or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

local function CreateRow(parent)
  local row = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate,BackdropTemplate")
  row:SetSize(ROW_W, ROW_H)
  row:EnableMouse(true)
  row:SetClampedToScreen(true)

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:SetColorTexture(0.045, 0.07, 0.095, 0.92)

  row.edge = row:CreateTexture(nil, "BORDER")
  row.edge:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.35)
  row.edge:SetPoint("LEFT")
  row.edge:SetPoint("TOP")
  row.edge:SetPoint("BOTTOM")
  row.edge:SetWidth(2)

  row.nameFS = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.nameFS:SetPoint("TOPLEFT", ICON + 6, -4)
  row.nameFS:SetWidth(96)
  row.nameFS:SetJustifyH("LEFT")
  row.nameFS:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

  row.tokenFS = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.tokenFS:SetPoint("TOPLEFT", ICON + 6, -16)
  row.tokenFS:SetWidth(110)
  row.tokenFS:SetJustifyH("LEFT")
  row.tokenFS:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  row.rangeFS = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.rangeFS:SetPoint("BOTTOMRIGHT", -6, 3)
  row.rangeFS:SetJustifyH("RIGHT")
  row.rangeFS:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  WireRow(row)
  local engine = ns.DetectionEngine
  if engine and type(engine.CreateCarrier) == "function" then
    row.auraContainer = engine:CreateCarrier("LiveList", row, BindLiveSlot, row)
  end
  row:Hide()
  return row
end

local function EnsurePool()
  if poolReady then
    return true
  end
  if not header then
    return false
  end
  if LockedDown() then
    pending = true
    return false
  end
  for i = 1, MAX_ROWS do
    pool[i] = CreateRow(header)
  end
  poolReady = true
  return true
end

local function HideUnused(fromIndex)
  if LockedDown() then
    pending = true
    return false
  end
  if not poolReady then
    return true
  end
  local cleared = true
  for i = fromIndex, MAX_ROWS do
    local row = pool[i]
    if ns.DetectionEngine and type(ns.DetectionEngine.UnassignCarrier) == "function" then
      if not ns.DetectionEngine:UnassignCarrier(row) then
        cleared = false
      end
    end
    row.assigned = false
    row.unit = nil
    row:SetAttribute("unit", nil)
    row:Hide()
  end
  return cleared
end

local function HideAll()
  if LockedDown() then
    pending = true
    return false
  end
  if header then
    header:Hide()
  end
  return HideUnused(1)
end

local function LayoutRows(units, pack)
  if LockedDown() then
    pending = true
    return false, "DEFERRED_COMBAT"
  end
  local reverse = pack.alerts.liveListReverse
  local n = #units
  local height = HANDLE_H + math.max(n, 0) * (ROW_H + 1)
  local layoutOK = true
  local layoutStatus = "SUCCESS"
  header:SetSize(ROW_W, math.max(height, HANDLE_H))
  handle:ClearAllPoints()
  if reverse then
    handle:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  else
    handle:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
  end

  for i = 1, MAX_ROWS do
    local row = pool[i]
    local unit = units[i]
    if unit then
      row.unit = unit
      row.assigned = true
      row:SetAttribute("unit", unit)
      row:ClearAllPoints()
      local offset = HANDLE_H + (i - 1) * (ROW_H + 1)
      if reverse then
        row:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, offset)
      else
        row:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -offset)
      end
      PaintRow(row, pack, unit)
      local attached, status = AttachAuraContainer(row)
      if not attached then
        layoutOK = false
        layoutStatus = status or "FAILURE"
      end
      row:Show()
    else
      if ns.DetectionEngine and type(ns.DetectionEngine.UnassignCarrier) == "function" then
        if not ns.DetectionEngine:UnassignCarrier(row) then
          layoutOK = false
        end
      end
      row.assigned = false
      row.unit = nil
      row:SetAttribute("unit", nil)
      row:Hide()
    end
  end
  return layoutOK, layoutStatus
end

local function OnHeaderUpdate(_self, elapsed)
  local pack = GetPack()
  if not pack.alerts or not pack.alerts.liveList then
    return
  end
  local scan = pack.alerts.liveListScan or 0.2
  if scan < 0.05 then
    scan = 0.05
  end
  scanElapsed = scanElapsed + (elapsed or 0)
  if scanElapsed < scan then
    return
  end
  scanElapsed = 0
  if not poolReady then
    return
  end
  for i = 1, MAX_ROWS do
    local row = pool[i]
    if row.assigned and row.unit then
      PaintRow(row, pack, row.unit)
    end
  end
  if pack.alerts.liveListOnlyInRange then
    local units = FilterRange(BuildRoster(pack), pack)
    local amount = pack.alerts.liveListAmount or 7
    if amount > MAX_ROWS then
      amount = MAX_ROWS
    end
    if amount < 1 then
      amount = 1
    end
    local changed = false
    for i = 1, MAX_ROWS do
      local want
      if i <= amount then
        want = units[i]
      end
      if pool[i].unit ~= want then
        changed = true
        break
      end
    end
    if changed then
      ns.LayoutLiveList()
    end
  end
end

local function EnsureHeader()
  if header then
    return true
  end
  if LockedDown() then
    pending = true
    return false
  end
  header = CreateFrame("Frame", "DecursiveRebuildLiveList", UIParent)
  header:SetSize(ROW_W, HANDLE_H)
  header:SetClampedToScreen(true)
  header:SetMovable(true)
  header:EnableMouse(false)
  header:SetFrameStrata("MEDIUM")
  RestorePoint()

  handle = CreateFrame("Button", "DecursiveRebuildLiveListHandle", header, "BackdropTemplate")
  handle:SetSize(ROW_W, HANDLE_H)
  handle:SetPoint("TOPLEFT")
  handle:EnableMouse(true)
  handle:RegisterForClicks("AnyUp")
  handle.bg = handle:CreateTexture(nil, "BACKGROUND")
  handle.bg:SetAllPoints()
  handle.bg:SetColorTexture(0.07, 0.11, 0.15, 0.97)
  handle.accent = handle:CreateTexture(nil, "BORDER")
  handle.accent:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 1)
  handle.accent:SetPoint("TOPLEFT")
  handle.accent:SetPoint("TOPRIGHT")
  handle.accent:SetHeight(2)
  handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  handle.label:SetPoint("LEFT", 8, -1)
  handle.label:SetText("Live List")
  handle.label:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
  handle.isMoving = false
  handle:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not LockedDown() then
      self.isMoving = true
      header:StartMoving()
    end
  end)
  handle:SetScript("OnMouseUp", function(self, button)
    if LockedDown() then
      if self.isMoving then
        self.stopMovingPending = true
        pending = true
      end
      self.isMoving = false
      return
    end
    if self.isMoving then
      header:StopMovingOrSizing()
      self.isMoving = false
      SavePoint()
    elseif button == "RightButton" then
      if ns.ShowOptions then
        ns.ShowOptions()
      end
    end
  end)
  handle:SetScript("OnHide", function(self)
    if self.isMoving then
      if LockedDown() then
        self.stopMovingPending = true
        pending = true
      else
        header:StopMovingOrSizing()
      end
    end
    self.isMoving = false
  end)
  handle:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Zhaohu's Decursive")
    GameTooltip:AddLine("Live List  ·  drag to move", TEAL[1], TEAL[2], TEAL[3])
    GameTooltip:AddLine("Right-click: options", TEAL[1], TEAL[2], TEAL[3])
    GameTooltip:AddLine("Rows show unit tokens when names are secret.", MUTED[1], MUTED[2], MUTED[3])
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

function ns.LayoutLiveList()
  local pack = GetPack()
  if LockedDown() then
    pending = true
    return false, "DEFERRED_COMBAT", 0
  end
  if handle and handle.stopMovingPending and header then
    header:StopMovingOrSizing()
    handle.stopMovingPending = nil
    SavePoint()
  end
  if not pack.alerts or not pack.alerts.liveList then
    if header then
      local hidden = HideAll() == true
      return hidden, hidden and "SUCCESS" or "FAILURE", 0
    end
    pending = false
    return true, "SUCCESS", 0
  end
  if not EnsureHeader() then
    pending = true
    return
  end
  if not EnsurePool() then
    pending = true
    return
  end

  local units = FilterRange(BuildRoster(pack), pack)
  local amount = pack.alerts.liveListAmount or 7
  if amount > MAX_ROWS then
    amount = MAX_ROWS
  end
  if amount < 1 then
    amount = 1
  end
  if #units > amount then
    for i = #units, amount + 1, -1 do
      units[i] = nil
    end
  end

  header:SetScale(pack.alerts.liveListScale or 1)
  header:SetAlpha(pack.alerts.liveListAlpha or 1)
  header:Show()
  local layoutOK, layoutStatus = LayoutRows(units, pack)
  pending = false
  return layoutOK, layoutStatus, #units
end

function ns.RefreshLiveList()
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("LiveList")
  end
  pending = false
  return ns.LayoutLiveList()
end

local function RegisterEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  if ns.DetectionEngine then
    return
  end
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event)
    if event == "SPELLS_CHANGED" then
      ns.RefreshLiveList()
    elseif event == "UNIT_PET" then
      ns.RefreshLiveList()
    elseif event == "GROUP_ROSTER_UPDATE" then
      ns.RefreshLiveList()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if pending then
        ns.RefreshLiveList()
      end
    end
  end)
  eventFrame:RegisterEvent("SPELLS_CHANGED")
  eventFrame:RegisterEvent("UNIT_PET")
  eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ns.EnableLiveList(_addon)
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("LiveList", false)
  end
  if ns.DetectionEngine and type(ns.DetectionEngine.RegisterConsumer) == "function" then
    ns.DetectionEngine:RegisterConsumer("LiveList", function()
      return ns.RefreshLiveList()
    end)
  end
  RegisterEvents()
  ns.RefreshLiveList()
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("LiveList", true)
  end
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("LiveList", function()
    local visibleRows = 0
    for i = 1, #pool do
      local row = pool[i]
      if row and type(row.IsShown) == "function" then
        local ok, shown = pcall(row.IsShown, row)
        local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(shown) or nil
        if ok and public == true then
          visibleRows = visibleRows + 1
        end
      end
    end
    local headerShown = false
    if header and type(header.IsShown) == "function" then
      local ok, shown = pcall(header.IsShown, header)
      local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(shown) or nil
      headerShown = ok and public == true
    end
    local pack = GetPack()
    return {
      eventsRegistered = eventsOn,
      poolReady = poolReady,
      poolCount = #pool,
      visibleRows = visibleRows,
      headerShown = headerShown,
      pendingRefresh = pending,
      configuredEnabled = type(pack) == "table" and type(pack.alerts) == "table" and pack.alerts.liveList == true,
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("LiveList")
end
