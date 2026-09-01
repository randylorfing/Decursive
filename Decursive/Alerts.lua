local ADDON_NAME, ns = ...

local MAX_LEARNED = 40
local TEAL = {0.32, 0.86, 0.82}

local SOUND_DIR = "Interface\\AddOns\\Decursive\\Sounds\\"
local PRESET_FILES = {
  FEMALE_DISPEL = SOUND_DIR .. "FemaleDispel.ogg",
  FEMALE_DISPEL_ME = SOUND_DIR .. "FemaleDispelMe.ogg",
  FEMALE_CLEANSE = SOUND_DIR .. "FemaleCleanse.ogg",
  FEMALE_CLEANSE_ME = SOUND_DIR .. "FemaleCleanseMe.ogg",
  AFFLICTION = SOUND_DIR .. "AfflictionAlert.ogg",
  QUICK = SOUND_DIR .. "G_NecropolisWound-fast.ogg",
  BRIGHT_PING = SOUND_DIR .. "BrightPing.ogg",
  DOUBLE_PING = SOUND_DIR .. "DoublePing.ogg",
  TRIPLE_PING = SOUND_DIR .. "TriplePing.ogg",
  HIGH_CHIME = SOUND_DIR .. "HighChime.ogg",
  LOW_CHIME = SOUND_DIR .. "LowChime.ogg",
  PULSE_UP = SOUND_DIR .. "PulseUp.ogg",
  PULSE_DOWN = SOUND_DIR .. "PulseDown.ogg",
  FAILURE = SOUND_DIR .. "FailedSpell.ogg",
}

local registered = {}
local learned = {}
local eventsOn = false
local eventFrame
local pendingSync = false
local lastSoundAt = 0
local lastTextAt = 0
local textFrame
local textFont
local hideAt = 0
local printFrame

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

local function Accessible(value)
  return ns.IsAccessible(value)
end

local function Public(value)
  return ns.PublicValue(value)
end

local function SoundMessagingLocked()
  if InChatMessagingLockdown and InChatMessagingLockdown() then
    return true
  end
  return false
end

local function TriggerAdded()
  local e = Enum and Enum.UnitAuraSoundTrigger
  if e and e.Added then
    return e.Added
  end
  return 0
end

local function PackSoundFile(pack)
  local key = pack.alerts and pack.alerts.soundPreset or "FEMALE_DISPEL"
  return PRESET_FILES[key] or PRESET_FILES.FEMALE_DISPEL
end

local function PackChannel(pack)
  return (pack.alerts and pack.alerts.soundChannel) or "Master"
end

local function EnsureLearnedStore()
  local addon = Addon()
  if not addon or not addon.db or not addon.db.global then
    return learned
  end
  local store = addon.db.global.learnedDispelSpellIds
  if type(store) ~= "table" then
    store = {}
    addon.db.global.learnedDispelSpellIds = store
  end
  learned = store
  return learned
end

local function HasLearned(spellId)
  local store = EnsureLearnedStore()
  for i = 1, #store do
    if store[i] == spellId then
      return true
    end
  end
  return false
end

local function LearnSpellId(spellId)
  if type(spellId) ~= "number" or spellId <= 0 then
    return false
  end
  if not Accessible(spellId) then
    return false
  end
  if HasLearned(spellId) then
    return false
  end
  local store = EnsureLearnedStore()
  if #store >= MAX_LEARNED then
    table.remove(store, 1)
  end
  store[#store + 1] = spellId
  return true
end

local function ClearRegistrations()
  if not C_UnitAuras or not C_UnitAuras.RemoveAuraSound then
    registered = {}
    return
  end
  for i = 1, #registered do
    local id = registered[i]
    if type(id) == "number" then
      C_UnitAuras.RemoveAuraSound(id)
    end
  end
  registered = {}
end

local function RosterUnits(pack)
  if ns.BuildRoster then
    return ns.BuildRoster(pack)
  end
  return {"player"}
end

local function SyncNativeSounds()
  ClearRegistrations()
  local pack = GetPack()
  if not pack.alerts or not pack.alerts.sound or not pack.alerts.nativeAuraSound then
    pendingSync = false
    return
  end
  if not C_UnitAuras or not C_UnitAuras.AddAuraSound then
    pendingSync = false
    return
  end
  if SoundMessagingLocked() then
    pendingSync = true
    return
  end
  local store = EnsureLearnedStore()
  if #store == 0 then
    pendingSync = false
    return
  end
  local file = PackSoundFile(pack)
  local channel = PackChannel(pack)
  local trigger = TriggerAdded()
  local units = RosterUnits(pack)
  for u = 1, #units do
    local unit = units[u]
    for s = 1, #store do
      local spellId = store[s]
      local id = C_UnitAuras.AddAuraSound(trigger, {
        unitToken = unit,
        spellID = spellId,
        soundFileName = file,
        outputChannel = channel,
      })
      id = Public(id)
      if type(id) == "number" then
        registered[#registered + 1] = id
      end
    end
  end
  pendingSync = false
end

local function EnsureTextFrame()
  if textFrame then
    return
  end
  textFrame = CreateFrame("Frame", "DecursiveRebuildDispelText", UIParent)
  textFrame:SetSize(800, 80)
  textFrame:SetPoint("CENTER", 0, 120)
  textFrame:SetFrameStrata("HIGH")
  textFrame:Hide()
  textFont = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  textFont:SetAllPoints()
  textFont:SetJustifyH("CENTER")
  textFont:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
  textFrame:SetScript("OnUpdate", function(self)
    if hideAt > 0 and GetTime and GetTime() >= hideAt then
      hideAt = 0
      self:Hide()
    end
  end)
end

local function ShowDispelText(message, pack)
  if not pack.alerts or not pack.alerts.dispelEnabled then
    return
  end
  if pack.alerts.text == false and pack.alerts.pvpText ~= true then
    return
  end
  EnsureTextFrame()
  local size = pack.alerts.dispelFontSize or 48
  local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  textFont:SetFont(fontPath, size, "OUTLINE")
  textFont:SetText(message)
  textFrame:Show()
  if pack.alerts.dispelMode == "UNTIL_CLEARED" then
    hideAt = 0
  else
    hideAt = (GetTime and GetTime() or 0) + (pack.alerts.dispelDuration or 2)
  end
end

local function EnsurePrintFrame()
  if printFrame then
    return printFrame
  end
  printFrame = CreateFrame("ScrollingMessageFrame", "DecursiveRebuildPrint", UIParent)
  printFrame:SetSize(420, 140)
  printFrame:SetPoint("CENTER", 0, -180)
  printFrame:SetFontObject(GameFontHighlightSmall)
  printFrame:SetJustifyH("LEFT")
  printFrame:SetFading(true)
  printFrame:SetMaxLines(40)
  printFrame:SetInsertMode("BOTTOM")
  printFrame:EnableMouse(false)
  printFrame:Hide()
  return printFrame
end

local function PrintLine(message, isError, pack)
  if not pack.alerts then
    return
  end
  if isError and pack.alerts.printErrors == false then
    return
  end
  if not isError and pack.alerts.chat == false then
    return
  end
  local line = "|cff51dbd1Decursive|r: " .. message
  if pack.alerts.printChat ~= false then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(line)
    end
  end
  if pack.alerts.printCustom then
    local f = EnsurePrintFrame()
    f:Show()
    f:AddMessage(line)
  end
end

local function PlayPreset(pack, kind)
  if not pack.alerts or not pack.alerts.sound then
    return
  end
  local now = GetTime and GetTime() or 0
  local wait = pack.alerts.soundDebounce or 2
  if now - lastSoundAt < wait then
    return
  end
  lastSoundAt = now
  local file
  if kind == "failure" then
    file = PRESET_FILES.FAILURE
  else
    file = PackSoundFile(pack)
  end
  local channel = PackChannel(pack)
  if PlaySoundFile then
    PlaySoundFile(file, channel)
  end
end

local function UnitLabel(unit, destName)
  local publicName = Public(destName)
  if type(publicName) == "string" and publicName ~= "" then
    return publicName
  end
  if unit then
    local n = UnitName and Public(UnitName(unit))
    if type(n) == "string" and n ~= "" then
      return n
    end
  end
  return "unit"
end

local function OnSuccessfulDispel(destGUID, destName, extraSpellId, extraSpellName)
  local pack = GetPack()
  extraSpellId = Public(extraSpellId)
  extraSpellName = Public(extraSpellName)
  destName = Public(destName)
  destGUID = Public(destGUID)
  local who = UnitLabel(nil, destName)
  local what = extraSpellName
  local now = GetTime and GetTime() or 0
  if pack.alerts and pack.alerts.learnSpellIds and type(extraSpellId) == "number" then
    if LearnSpellId(extraSpellId) then
      pendingSync = true
      if not SoundMessagingLocked() then
        SyncNativeSounds()
      end
    end
  end
  if now - lastTextAt >= 0.2 then
    lastTextAt = now
    if type(what) == "string" and what ~= "" then
      ShowDispelText("Dispelled " .. what, pack)
      PrintLine("Dispelled " .. what .. " from " .. who, false, pack)
    else
      ShowDispelText("Dispelled", pack)
      PrintLine("Dispelled on " .. who, false, pack)
    end
  end
end

local function SoulLinkSpellId()
  return ns.SOUL_LINK_SPELL_ID or 1259646
end

local function ShowSoulLinkWarning(destName)
  local pack = GetPack()
  if not pack.alerts or pack.alerts.soulLinkAlert == false then
    return
  end
  local sl = ns.GetSoulLinkState and ns.GetSoulLinkState(pack)
  if not sl or sl.available ~= true then
    return
  end
  local who = UnitLabel(nil, destName)
  if who == "unit" then
    who = "your target"
  end
  ShowDispelText("Battle rez: move within range of " .. who .. "!", pack)
  PrintLine("Battle rez: move within range of " .. who, false, pack)
end

local function OnCLEU()
  if not CombatLogGetCurrentEventInfo then
    return
  end
  local _ts, subevent, _hide, sourceGUID, _sourceName, _sf, _srf, destGUID, destName, _df, _drf, spellId, spellName, _school, extraSpellId, extraSpellName = CombatLogGetCurrentEventInfo()
  subevent = Public(subevent)
  sourceGUID = Public(sourceGUID)
  local playerGUID = UnitGUID and Public(UnitGUID("player"))
  if not sourceGUID or not playerGUID or sourceGUID ~= playerGUID then
    return
  end
  if subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN" then
    OnSuccessfulDispel(destGUID, destName, extraSpellId, extraSpellName)
    return
  end
  if subevent == "SPELL_CAST_FAILED" then
    spellId = Public(spellId)
    if type(spellId) == "number" and spellId == SoulLinkSpellId() then
      ShowSoulLinkWarning(destName)
    end
  end
end

local function OnCastFailed(unit, _castGUID, spellId)
  unit = Public(unit)
  if unit ~= "player" then
    return
  end
  local pack = GetPack()
  spellId = Public(spellId)
  if type(spellId) == "number" and spellId == SoulLinkSpellId() then
    local dest
    if UnitName then
      dest = Public(UnitName("target"))
    end
    ShowSoulLinkWarning(dest)
  end
  if not pack.alerts or not pack.alerts.errorSound then
    return
  end
  PlayPreset(pack, "failure")
end

local function RegisterEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      OnCLEU()
    elseif event == "GROUP_ROSTER_UPDATE" then
      pendingSync = true
      if not SoundMessagingLocked() then
        SyncNativeSounds()
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if pendingSync then
        SyncNativeSounds()
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      pendingSync = true
      SyncNativeSounds()
    elseif event == "LOADING_SCREEN_ENABLED" then
      ClearRegistrations()
      pendingSync = true
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
      OnCastFailed(arg1, arg2, arg3)
    end
  end)
  eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("LOADING_SCREEN_ENABLED")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  local valid = true
  if C_EventUtils and C_EventUtils.IsEventValid then
    valid = C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")
  end
  if valid then
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

function ns.RefreshAlerts()
  pendingSync = true
  if SoundMessagingLocked() then
    return
  end
  SyncNativeSounds()
end


function ns.PrintAuraSoundDiagnostics(spellId, unitToken)
  local pack = GetPack()
  local store = EnsureLearnedStore()
  local lines = {
    "Decursive Aura Sound Diagnostic",
    "native AddAuraSound: " .. ((C_UnitAuras and C_UnitAuras.AddAuraSound) and "yes" or "no"),
    "sound enabled: " .. tostring(pack.alerts and pack.alerts.sound == true),
    "nativeAuraSound: " .. tostring(pack.alerts and pack.alerts.nativeAuraSound == true),
    "learned ids: " .. tostring(#store),
    "active registrations: " .. tostring(#registered),
    "chat-messaging lockdown: " .. tostring(SoundMessagingLocked()),
  }
  if #store > 0 then
    local shown = {}
    local n = math.min(#store, 12)
    for i = 1, n do
      shown[i] = tostring(store[i])
    end
    lines[#lines + 1] = "ids: " .. table.concat(shown, ", ")
  end
  spellId = tonumber(spellId)
  if type(spellId) == "number" and spellId > 0 then
    local unit = type(unitToken) == "string" and unitToken ~= "" and unitToken or "player"
    local found = false
    for i = 1, #store do
      if store[i] == spellId then
        found = true
        break
      end
    end
    lines[#lines + 1] = "query " .. unit .. ":" .. tostring(spellId) .. " learned=" .. (found and "yes" or "no")
  else
    lines[#lines + 1] = "Pair query: /zdsound <spellID> [unitToken]"
  end
  local text = table.concat(lines, "\n")
  if DEFAULT_CHAT_FRAME then
    for i = 1, #lines do
      DEFAULT_CHAT_FRAME:AddMessage("|cff51dbd1Decursive|r " .. lines[i])
    end
  end
  return text
end

function ns.EnableAlerts(_addon)
  EnsureLearnedStore()
  RegisterEvents()
  ns.RefreshAlerts()
end
