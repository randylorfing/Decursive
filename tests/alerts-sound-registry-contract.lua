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

local function Check(value, message)
  if not value then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function Count(map)
  local count = 0
  for _key in pairs(map) do
    count = count + 1
  end
  return count
end

local timerQueue = {}
local chatLocked = false
local combatLocked = false
local now = 100
local diagnosticsText = {}

DEFAULT_CHAT_FRAME = {
  AddMessage = function()
    error("Alerts diagnostics and help must never write to chat")
  end,
}

C_Timer = {
  After = function(_delay, callback)
    timerQueue[#timerQueue + 1] = callback
  end,
}

local function RunNextTimer()
  local callback = table.remove(timerQueue, 1)
  if callback then
    callback()
  end
  return callback ~= nil
end

local function DrainTimers(limit)
  local count = 0
  while #timerQueue > 0 and count < (limit or 40) do
    RunNextTimer()
    count = count + 1
  end
  return count
end

C_ChatInfo = {
  InChatMessagingLockdown = function()
    return chatLocked
  end,
}

InCombatLockdown = function()
  return combatLocked
end

GetTime = function()
  return now
end

strtrim = function(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

UIParent = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameFontNormalHuge = {
  GetFont = function()
    return STANDARD_TEXT_FONT, 48, ""
  end,
}

local namedFrames = {}

local function NewFontString()
  local font = {}
  function font:SetAllPoints()
  end
  function font:SetJustifyH(value)
    self.justify = value
  end
  function font:SetTextColor(r, g, b, a)
    self.color = {r, g, b, a}
  end
  function font:SetFont(path, size, outline)
    self.font = {path, size, outline}
  end
  function font:SetText(value)
    self.text = value
  end
  function font:SetPoint(...)
    self.point = {...}
  end
  function font:SetAlpha(value)
    self.alpha = value
  end
  function font:SetIgnoreParentScale(value)
    self.ignoreParentScale = value
  end
  return font
end

CreateFrame = function(_kind, name)
  local frame = {shown = true, scripts = {}, fonts = {}}
  function frame:SetSize(width, height)
    self.width = width
    self.height = height
  end
  function frame:SetPoint(...)
    self.point = {...}
  end
  function frame:GetPoint()
    return "TOP", UIParent, "TOP", 0, -160
  end
  function frame:ClearAllPoints()
    self.point = nil
  end
  function frame:SetFrameStrata(value)
    self.strata = value
  end
  function frame:Hide()
    self.shown = false
  end
  function frame:Show()
    self.shown = true
  end
  function frame:IsShown()
    return self.shown
  end
  function frame:EnableMouse(value)
    self.mouse = value
  end
  function frame:SetMovable(value)
    self.movable = value
  end
  function frame:RegisterForDrag(...)
    self.drag = {...}
  end
  function frame:SetScript(script, callback)
    self.scripts[script] = callback
  end
  function frame:CreateFontString()
    local font = NewFontString()
    self.fonts[#self.fonts + 1] = font
    return font
  end
  if name then
    namedFrames[name] = frame
  end
  return frame
end

CreateColor = function(r, g, b, a)
  return {r, g, b, a}
end

Enum = {
  UnitAuraSoundTrigger = {Added = 17},
  LuaCurveType = {Step = 1},
  DurationTextBindingProperty = {ElapsedDuration = 1},
}

C_CurveUtil = {
  CreateColorCurve = function()
    local curve = {points = {}}
    function curve:SetType(value)
      self.curveType = value
    end
    function curve:AddPoint(time, color)
      self.points[#self.points + 1] = {time, color}
    end
    function curve:ClearPoints()
      self.points = {}
    end
    return curve
  end,
}

C_DurationUtil = {
  CreateDurationTextBinding = function()
    local binding = {}
    function binding:SetToDefaults()
    end
    function binding:SetTextFormat(value)
      self.format = value
    end
    function binding:SetTextColorCurve(curve)
      self.curve = curve
    end
    function binding:SetZeroDurationText(value)
      self.zero = value
    end
    function binding:SetExpiredText(value)
      self.expired = value
    end
    function binding:SetUpdateInterval(value)
      self.interval = value
    end
    return binding
  end,
}

local activeHandles = {}
local addCalls = {}
local removeCalls = {}
local nextHandle = 1000
local addFailuresRemaining = 0
local removeFailuresRemaining = 0

C_UnitAuras = {
  AddAuraSound = function(trigger, info)
    addCalls[#addCalls + 1] = {
      trigger = trigger,
      unitToken = info.unitToken,
      spellID = info.spellID,
      soundFileName = info.soundFileName,
      outputChannel = info.outputChannel,
    }
    if addFailuresRemaining > 0 then
      addFailuresRemaining = addFailuresRemaining - 1
      error("simulated add failure")
    end
    nextHandle = nextHandle + 1
    activeHandles[nextHandle] = addCalls[#addCalls]
    return nextHandle
  end,
  RemoveAuraSound = function(handle)
    removeCalls[#removeCalls + 1] = handle
    if removeFailuresRemaining > 0 then
      removeFailuresRemaining = removeFailuresRemaining - 1
      error("simulated remove failure")
    end
    activeHandles[handle] = nil
  end,
}

local function MakePack(preset, enabled)
  return {
    cure = {magic = true, curse = false, poison = true, disease = false},
    alerts = {
      sound = enabled ~= false,
      nativeAuraSound = true,
      soundPreset = preset or "FEMALE_DISPEL",
      soundChannel = "Master",
      text = true,
      dispelEnabled = true,
      dispelMode = "TIMED",
      dispelDuration = 2,
      dispelFontSize = 31,
      dispelColor = {0.2, 0.4, 0.6, 0.8},
      alertPoint = {point = "TOP", relPoint = "TOP", x = 0, y = -160},
    },
  }
end

local currentPack = MakePack("FEMALE_DISPEL", true)
local ns = {
  IsAccessible = function()
    return true
  end,
  PublicValue = function(value)
    return value
  end,
  AuraDisplayMutationBlocked = function()
    return false
  end,
  CURATED_DISPEL_ALERTS = {
    {id = 1001, cureType = "MAGIC"},
    {id = 1002, cureType = "POISON"},
    {id = 1003, cureType = "BLEED"},
  },
  GetKnownCures = function()
    return {{types = {"magic", "poison"}}}
  end,
  Diagnostics = {
    ShowText = function(text)
      diagnosticsText[#diagnosticsText + 1] = text
      return true
    end,
  },
  addon = {
    db = {global = {learnedDispelSpellIds = {9999}}},
    rosterOrderSignature = "player|party1|partypet1",
    GetAppliedEnvironmentPack = function()
      return currentPack
    end,
  },
}

assert(loadfile("ZDecursive/Alerts.lua"))("ZDecursive", ns)

local ok, status = ns.RefreshAlerts("INITIAL")
Check(ok and status == "SUCCESS", "initial native sound reconcile succeeds")
local registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.active, 6, "committed player, party member, and pet receive both curated spells")
Equal(registry.desired, 6, "desired coverage is exact")
Equal(#addCalls, 6, "six unique native registrations are added")
for i = 1, 3 do
  Equal(addCalls[i].spellID, 1001, "spell-first ordering covers every unit for the first spell")
end
for i = 4, 6 do
  Equal(addCalls[i].spellID, 1002, "spell-first ordering then advances to the second spell")
end
Equal(addCalls[1].unitToken, "player", "committed player order is preserved")
Equal(addCalls[2].unitToken, "party1", "committed party order is preserved")
Equal(addCalls[3].unitToken, "partypet1", "committed party pet is included")
for i = 1, #addCalls do
  Check(addCalls[i].spellID ~= 1003 and addCalls[i].spellID ~= 9999, "only curated actionable IDs are registered")
  Equal(addCalls[i].trigger, 17, "native registration uses UnitAuraSoundTrigger.Added")
end

ns.RefreshAlerts("IDEMPOTENT")
Equal(#addCalls, 6, "an unchanged reconcile creates no duplicate registrations")
Equal(Count(activeHandles), 6, "unchanged active registry remains unique")

ns.addon.rosterOrderSignature = "raid1|raidpet1|raid2"
currentPack = MakePack("FEMALE_DISPEL", true)
ns.RefreshAlerts("RAID_SWITCH")
registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.active, 6, "raid switch replaces party coverage exactly")
local activeUnits = {}
for _handle, record in pairs(activeHandles) do
  activeUnits[record.unitToken] = true
end
Check(activeUnits.raid1 and activeUnits.raidpet1 and activeUnits.raid2, "committed raid members and raid pets are covered")
Check(not activeUnits.player and not activeUnits.party1, "stale party bindings are removed after raid additions succeed")

local addsBeforeReplacement = #addCalls
currentPack.alerts.soundPreset = "DOUBLE_PING"
addFailuresRemaining = 1
ok, status = ns.RefreshAlerts("REPLACEMENT_FAILURE")
Check(not ok and status == "FAILURE", "replacement add failure is not reported as success")
registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.active, 11, "successful new bindings and all six old fallbacks remain after one replacement fails")
Check(registry.replacementFallbacks >= 1, "replacement fallback retention is diagnosed")
Equal(#removeCalls, 6, "no stale removal occurs after a replacement add failure")
Check(#addCalls > addsBeforeReplacement, "replacement additions were attempted")

addFailuresRemaining = 0
ok, status = ns.RefreshAlerts("REPLACEMENT_RECOVERY")
Check(ok and status == "SUCCESS", "replacement retry reaches exact coverage")
registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.active, 6, "old replacement fallbacks are removed after every desired add succeeds")
Equal(registry.stale, 0, "replacement recovery leaves no stale bindings")
DrainTimers()

currentPack.alerts.sound = false
local removesBeforeOff = #removeCalls
ok, status = ns.RefreshAlerts("TOGGLE_OFF")
Check(ok and status == "SUCCESS", "turning sound off clears owned handles immediately")
Equal(Count(activeHandles), 0, "sound off leaves no active native registrations")
Check(#removeCalls > removesBeforeOff, "sound off invokes RemoveAuraSound")

currentPack.alerts.sound = true
ns.RefreshAlerts("REARM_FOR_REMOVE_RETRY")
Equal(Count(activeHandles), 6, "sound can be rearmed")
currentPack.alerts.sound = false
removeFailuresRemaining = 100
ok, status = ns.RefreshAlerts("REMOVE_FAILURE")
Check(not ok and status == "FAILURE", "failed teardown is not reported as success")
for _attempt = 1, 10 do
  if not RunNextTimer() then
    break
  end
end
registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.removeRetryAttempts, 3, "RemoveAuraSound retries are bounded")
Check(registry.removeRetryExhausted, "bounded removal exhaustion is diagnosed")
Equal(#timerQueue, 0, "removal retry exhaustion does not keep scheduling timers")
Check(registry.active > 0, "failed removals retain their owned handles for a later retry")

removeFailuresRemaining = 0
ns.RefreshAlerts("REMOVE_RECOVERY")
Equal(Count(activeHandles), 0, "a later external refresh completes retained teardown")

currentPack.alerts.sound = true
chatLocked = true
combatLocked = true
local addsBeforeDeferred = #addCalls
ok, status = ns.RefreshAlerts("COMBAT_DEFER")
Check(not ok and status == "DEFERRED_COMBAT", "combat chat lockdown returns typed deferral")
Equal(#addCalls, addsBeforeDeferred, "restricted refresh retains state without native mutation")
registry = ns.GetAuraSoundRegistryStatus()
Check(registry.pending and registry.replayPending, "restricted refresh schedules bounded replay")
chatLocked = false
combatLocked = false
Check(RunNextTimer(), "deferred replay timer exists")
registry = ns.GetAuraSoundRegistryStatus()
Check(registry.result == "SUCCESS" and registry.active == 6, "deferred replay reconciles after restriction clears")
DrainTimers()

currentPack.alerts.sound = false
currentPack.alerts.text = false
ok, status = ns.RefreshAlerts("PVP_QUIET_PREPARE")
Check(ok and status == "SUCCESS", "quiet PvP preparation clears native sound registrations")
Equal(Count(activeHandles), 0, "quiet PvP preparation owns no native sound handles")
chatLocked = true
local quietTimerBaseline = #timerQueue
ok, status = ns.RefreshAlerts("PVP_QUIET_RESTRICTED")
Check(ok and status == "SUCCESS", "fully quiet PvP with zero handles is healthy during chat lockdown")
registry = ns.GetAuraSoundRegistryStatus()
Equal(registry.active, 0, "quiet restricted PvP owns zero native sound handles")
Equal(registry.desired, 0, "quiet restricted PvP desires zero native sound handles")
Check(not registry.pending and not registry.replayPending, "quiet restricted PvP schedules no native mutation")
Equal(#timerQueue, quietTimerBaseline, "quiet restricted PvP schedules no replay timer")

currentPack.alerts.text = true
ok, status = ns.RefreshAlerts("PVP_TEXT_ON_RESTRICTED")
Check(not ok and status == "DEFERRED_RESTRICTED", "enabled landing text preserves scoped restriction deferral")
chatLocked = false
currentPack.alerts.text = false
DrainTimers()

currentPack.alerts.sound = true
ok, status = ns.RefreshAlerts("PVP_STALE_PREPARE")
Check(ok and status == "SUCCESS", "stale-handle scenario creates native sound registrations")
Check(Count(activeHandles) > 0, "stale-handle scenario owns native sound handles")
currentPack.alerts.sound = false
chatLocked = true
ok, status = ns.RefreshAlerts("PVP_STALE_RESTRICTED")
Check(not ok and status == "DEFERRED_RESTRICTED", "quiet settings with stale handles still defer restricted teardown")
Check(Count(activeHandles) > 0, "restricted teardown retains owned native sound handles")
chatLocked = false
ok, status = ns.RefreshAlerts("PVP_STALE_RECOVERY")
Check(ok and status == "SUCCESS", "stale native handles clear after restriction ends")
Equal(Count(activeHandles), 0, "stale recovery owns no native sound handles")
currentPack.alerts.sound = true
currentPack.alerts.text = true
DrainTimers()

local slot = {fonts = {}}
function slot:CreateFontString()
  local font = NewFontString()
  self.fonts[#self.fonts + 1] = font
  return font
end
function slot:SetDurationText(font, options)
  self.durationFont = font
  self.durationOptions = options
end
function slot:SetDispelTypeText(font, options)
  self.dispelFont = font
  self.dispelOptions = options
end

ns.ConfigureDispelAlertSlot(slot)
Equal(slot.durationFont.font[2], 31, "native timed DISPEL text uses configured size")
Equal(slot.durationFont.font[3], "THICKOUTLINE", "native timed DISPEL text uses alpha outline style")
Equal(slot.dispelFont.color[1], 0.2, "native persistent DISPEL text uses configured red channel")
Equal(slot.dispelFont.color[4], 0.8, "native persistent DISPEL text uses configured alpha")

currentPack.alerts.dispelFontSize = 52
currentPack.alerts.dispelColor = {0.7, 0.1, 0.2, 0.9}
ns.RefreshAlerts("STYLE_SWITCH")
Equal(slot.durationFont.font[2], 52, "applied-environment refresh updates timed text size")
Equal(slot.dispelFont.font[2], 52, "applied-environment refresh updates persistent text size")
Equal(slot.durationFont.color[1], 0.7, "applied-environment refresh updates timed text color")
Equal(slot.dispelFont.color[4], 0.9, "applied-environment refresh updates persistent text alpha")

local activeBeforePreview = ns.GetAuraSoundRegistryStatus().active
local savedColor = currentPack.alerts.dispelColor
local savedSize = currentPack.alerts.dispelFontSize
ok, status = ns.PlayTestText(currentPack)
Check(ok and status == "PREVIEW", "Test Text renders outside combat")
local previewFrame = namedFrames.DecursiveRebuildDispelText
Check(previewFrame and previewFrame.fonts[1].text == "DISPEL", "Test Text uses the exact configured alert text")
Equal(previewFrame.fonts[1].font[2], 52, "Test Text uses editing-pack size")
Equal(previewFrame.fonts[1].color[1], 0.7, "Test Text uses editing-pack color")
Equal(ns.GetAuraSoundRegistryStatus().active, activeBeforePreview, "Test Text does not mutate native sound registrations")
Check(currentPack.alerts.dispelColor == savedColor and currentPack.alerts.dispelFontSize == savedSize, "Test Text does not mutate profile settings")

combatLocked = true
ok, status = ns.PlayTestText(currentPack)
Check(not ok and status == "COMBAT", "Test Text is explicitly guarded during combat")

combatLocked = false
ns.HandleAlertsSlash("status")
Check(diagnosticsText[#diagnosticsText]:find("alerts status", 1, true), "Alerts status opens in the copyable diagnostics window")
ns.HandleAlertsSlash("unknown-command")
Check(diagnosticsText[#diagnosticsText]:find("Decursive Alerts Help", 1, true), "invalid-command help opens in the copyable diagnostics window")
ns.HandleAlertsSlash("move")
Check(diagnosticsText[#diagnosticsText]:find("alert text", 1, true), "move status opens in the copyable diagnostics window")
ns.PrintAuraSoundDiagnostics()
Check(diagnosticsText[#diagnosticsText]:find("Decursive Aura Sound Diagnostic", 1, true), "sound diagnostics open in the copyable diagnostics window")

currentPack.alerts.sound = false
currentPack.alerts.text = false
chatLocked = false
combatLocked = false
ok, status = ns.RefreshAlerts("BG_ENGINE_PREPARE")
Check(ok and status == "SUCCESS" and Count(activeHandles) == 0, "BG engine contract begins with quiet zero-handle Alerts state")
chatLocked = true

local baseCreateFrame = CreateFrame
local function NewBGSlot()
  local slot = {shown = true}
  function slot:EnableMouse()
  end
  function slot:SetMouseClickEnabled()
  end
  function slot:SetMouseMotionEnabled()
  end
  function slot:IsShown()
    return self.shown
  end
  return slot
end

local function NewBGContainer()
  local container = {shown = false, enabled = false, mouse = false, slots = {}}
  function container:SetAllPoints()
  end
  function container:EnableMouse(value)
    self.mouse = value
  end
  function container:SetMouseClickEnabled()
  end
  function container:SetMouseMotionEnabled()
  end
  function container:SetEnabled(value)
    self.enabled = value
  end
  function container:SetUnit(unit)
    self.unit = unit
  end
  function container:AddAuraSlot(key, _filter, info)
    local slot = NewBGSlot()
    self.slots[key] = slot
    if info and info.initializeFrame then
      info.initializeFrame(slot)
    end
    return slot
  end
  function container:SetAuraSlotFilterString()
  end
  function container:SetAuraSlotCandidateFilters()
  end
  function container:Show()
    self.shown = true
  end
  function container:Hide()
    self.shown = false
  end
  function container:IsShown()
    return self.shown
  end
  function container:GetAlpha()
    return 1
  end
  function container:IsMouseEnabled()
    return self.mouse
  end
  return container
end

CreateFrame = function(kind, name, parent, template)
  if kind == "AuraContainer" and template == "CustomAuraContainerTemplate" then
    return NewBGContainer(parent)
  end
  return baseCreateFrame(kind, name, parent, template)
end

ns.GetDetectionSlots = function()
  return {{
    key = "magic",
    filter = "HARMFUL|DISPELLABLE",
    candidateFilters = {includeDispelTypes = {Magic = true}},
    dispelType = "Magic",
    priority = 1,
  }}
end
ns.SafeNativeSetUnit = function(container, unit)
  if combatLocked then
    return false, "DEFERRED_COMBAT"
  end
  local assigned = pcall(container.SetUnit, container, unit)
  return assigned, assigned and "ASSIGNED" or "UNIT_ASSIGN_FAILED"
end
ns.HasActiveAddonRestriction = function()
  return chatLocked
end
ns.InvalidateDetection = function()
end
ns.ScheduleFollowerRosterGuard = function()
end

assert(loadfile("ZDecursive/DetectionEngine.lua"))("ZDecursive", ns)
local engine = ns.DetectionEngine
local bgOwners = {}
local bgParents = {}
local function RegisterBGPresentation(slot)
  slot._decursivePresentationRegistered = true
  slot._decursivePresentationHost = {
    GetParent = function()
      return slot
    end,
  }
end
engine:RegisterConsumer("MUFs", function()
  for i = 1, 9 do
    bgOwners[i] = bgOwners[i] or {}
    bgParents[i] = bgParents[i] or {}
    local _container, assigned = engine:BindCarrier("MUFs", bgParents[i], "raid" .. tostring(i), RegisterBGPresentation, bgOwners[i])
    if assigned ~= true then
      return false, "FAILURE", 9
    end
  end
  return true, "SUCCESS", 9
end)
engine:RegisterConsumer("Alerts", function(reason)
  return ns.RefreshAlerts(reason or "BG_ALERTS_CONSUMER")
end)
engine:RegisterConsumer("LiveList", function()
  return true, "SUCCESS", 0
end)
Check(engine:Start(), "restricted quiet PvP transaction commits its raid MUF bank")
local bgReport = engine:GetDiagnostics()
Equal(bgReport.consumerAlerts.expectedCount, 0, "quiet Alerts consumer reports expected zero")
Check(bgReport.consumerAlerts.available, "quiet Alerts consumer is healthy/not-applicable")
Equal(bgReport.consumerMUFs.expectedCount, 9, "BG MUF consumer expects all nine public raid units")
Equal(bgReport.consumerMUFs.desired, 9, "BG transaction desires all nine raid MUFs")
Equal(bgReport.consumerMUFs.active, 9, "BG transaction activates all nine raid MUFs")
Equal(bgReport.consumerMUFs.configured, 9, "BG transaction configures all nine raid MUFs")
Equal(bgReport.consumerMUFs.shown, 9, "BG transaction shows all nine raid MUFs")

local alertsSource = assert(io.open("ZDecursive/Alerts.lua", "rb")):read("*a")
Check(not alertsSource:find("DEFAULT_CHAT_FRAME", 1, true), "Alerts contains no legacy chat diagnostic fallback")
local optionsSource = assert(io.open("ZDecursive/Options.lua", "rb")):read("*a")
Check(optionsSource:find("Show in copyable diagnostics", 1, true), "Alerts output setting names its copyable destination")
Check(not optionsSource:find("Print to default chat", 1, true), "Options does not advertise removed Alerts chat output")

io.write("alerts-sound-registry-contract: ok\n")
