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
  ns.DiagnosticCheckpoint("module", "Alerts file start")
end

local MAX_LEARNED = 40
local TEAL = {0.32, 0.86, 0.82}

local SOUND_DIR = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local PRESET_FILES = {
  FEMALE_DISPEL = SOUND_DIR .. "FemaleDispel.ogg",
  FEMALE_DISPEL_ME = SOUND_DIR .. "FemaleDispelMe.ogg",
  FEMALE_CLEANSE = SOUND_DIR .. "FemaleCleanse.ogg",
  FEMALE_CLEANSE_ME = SOUND_DIR .. "FemaleCleanseMe.ogg",
  VOICE_DISPEL = SOUND_DIR .. "VoiceDispel.ogg",
  VOICE_CLEANSE = SOUND_DIR .. "VoiceCleanse.ogg",
  VOICE_CURE = SOUND_DIR .. "VoiceCure.ogg",
  VOICE_HELP = SOUND_DIR .. "VoiceHelp.ogg",
  VOICE_CLEANSE_ME = SOUND_DIR .. "VoiceCleanseMe.ogg",
  VOICE_CURE_ME = SOUND_DIR .. "VoiceCureMe.ogg",
  VOICE_HELP_CLEANSE_ME = SOUND_DIR .. "VoiceHelpCleanseMe.ogg",
  VOICE_HELP_CURE_ME = SOUND_DIR .. "VoiceHelpCureMe.ogg",
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

local STATUS_SUCCESS = "SUCCESS"
local STATUS_DEFERRED_COMBAT = "DEFERRED_COMBAT"
local STATUS_DEFERRED_RESTRICTED = "DEFERRED_RESTRICTED"
local STATUS_FAILURE = "FAILURE"
local MAX_REMOVE_RETRIES = 3
local MAX_REPLAY_RETRIES = 6
local REPLAY_DELAYS = {0.25, 0.5, 1, 2, 4, 8}

local registered = {}
local registeredPairs = {}
local learned = {}
local eventsOn = false
local eventFrame
local pendingSync = false
local pendingMode
local pendingReason = "NONE"
local replayScheduled = false
local replayAttempts = 0
local replayToken = 0
local replayExhausted = false
local removeRetryScheduled = false
local removeRetryAttempts = 0
local removeRetryToken = 0
local removeRetryExhausted = false
local lastSoundAt = 0
local lastTextAt = 0
local textFrame
local textFont
local hideAt = 0
local printFrame
local alertLayers = setmetatable({}, {__mode = "k"})
local soulLinkAttempt
local lastCuratedCount = 0
local lastDesiredCount = 0
local lastExactCount = 0
local lastStaleCount = 0
local lastAddFailed = 0
local lastRemoveFailed = 0
local lastReplacementFallbacks = 0
local lastSoundResult = "NEVER"
local lastSoundError = "NONE"

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

local function SoundMessagingLocked()
  local chatAPI = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  if type(chatAPI) == "function" then
    local ok, blocked = pcall(chatAPI)
    if not ok or not Accessible(blocked) or type(blocked) ~= "boolean" then
      return true, "CHAT_GATE_UNKNOWN"
    end
    return blocked == true, blocked and "CHAT_LOCKDOWN" or "OPEN"
  end
  if type(InChatMessagingLockdown) == "function" then
    local ok, blocked = pcall(InChatMessagingLockdown)
    if not ok or not Accessible(blocked) or type(blocked) ~= "boolean" then
      return true, "CHAT_GATE_UNKNOWN"
    end
    return blocked == true, blocked and "CHAT_LOCKDOWN" or "OPEN"
  end
  if type(InCombatLockdown) == "function" then
    local ok, blocked = pcall(InCombatLockdown)
    if not ok or not Accessible(blocked) then
      return true, "COMBAT_GATE_UNKNOWN"
    end
    return blocked == true, blocked and "COMBAT_LOCKDOWN" or "OPEN"
  end
  return false, "OPEN"
end

local function TriggerAdded()
  local e = Enum and Enum.UnitAuraSoundTrigger
  if e and Accessible(e.Added) and type(e.Added) == "number" then
    return e.Added
  end
  return nil
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

local SyncNativeSounds

local function SafeReason(reason)
  if type(reason) ~= "string" or reason == "" then
    return "UNSPECIFIED"
  end
  return reason:gsub("[^%w_:%-]", "_"):sub(1, 64)
end

local function RegistrationCount()
  local count = 0
  for _key in pairs(registered) do
    count = count + 1
  end
  return count
end

local function ForgetRegistration(key)
  local record = registered[key]
  if not record then
    return
  end
  registered[key] = nil
  local pairKey = record.pairKey
  if pairKey and registeredPairs[pairKey] then
    local remaining = registeredPairs[pairKey] - 1
    registeredPairs[pairKey] = remaining > 0 and remaining or nil
  end
end

local function RememberRegistration(key, record)
  if registered[key] then
    return false
  end
  registered[key] = record
  registeredPairs[record.pairKey] = (registeredPairs[record.pairKey] or 0) + 1
  return true
end

local function ResetReplayRetry()
  replayToken = replayToken + 1
  replayScheduled = false
  replayAttempts = 0
  replayExhausted = false
end

local function ResetRemoveRetry()
  removeRetryToken = removeRetryToken + 1
  removeRetryScheduled = false
  removeRetryAttempts = 0
  removeRetryExhausted = false
end

local function ScheduleReplay(reason)
  if replayScheduled then
    return true
  end
  if replayAttempts >= MAX_REPLAY_RETRIES then
    replayExhausted = true
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("AURA_SOUND_REPLAY", {
        attempt = replayAttempts,
        reason = SafeReason(reason),
        result = "EXHAUSTED",
      }, false)
    end
    return false
  end
  if not C_Timer or type(C_Timer.After) ~= "function" then
    replayExhausted = true
    return false
  end
  replayAttempts = replayAttempts + 1
  replayScheduled = true
  replayToken = replayToken + 1
  local token = replayToken
  local attempt = replayAttempts
  C_Timer.After(REPLAY_DELAYS[attempt] or REPLAY_DELAYS[#REPLAY_DELAYS], function()
    if token ~= replayToken then
      return
    end
    replayScheduled = false
    if not pendingSync then
      return
    end
    SyncNativeSounds("BOUNDED_REPLAY_" .. tostring(attempt), true, false)
  end)
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("AURA_SOUND_REPLAY", {
      attempt = attempt,
      reason = SafeReason(reason),
      result = "SCHEDULED",
    }, true)
  end
  return true
end

local function ScheduleRemoveRetry(reason)
  if removeRetryScheduled then
    return true
  end
  if removeRetryAttempts >= MAX_REMOVE_RETRIES then
    removeRetryExhausted = true
    if ns.DiagnosticRecord then
      ns.DiagnosticRecord("AURA_SOUND_REMOVE_RETRY", {
        attempt = removeRetryAttempts,
        reason = SafeReason(reason),
        result = "EXHAUSTED",
      }, false)
    end
    return false
  end
  if not C_Timer or type(C_Timer.After) ~= "function" then
    removeRetryExhausted = true
    return false
  end
  removeRetryAttempts = removeRetryAttempts + 1
  removeRetryScheduled = true
  removeRetryToken = removeRetryToken + 1
  local token = removeRetryToken
  local attempt = removeRetryAttempts
  C_Timer.After(0.5 * attempt, function()
    if token ~= removeRetryToken then
      return
    end
    removeRetryScheduled = false
    if not pendingSync then
      return
    end
    SyncNativeSounds("REMOVE_RETRY_" .. tostring(attempt), false, true)
  end)
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("AURA_SOUND_REMOVE_RETRY", {
      attempt = attempt,
      reason = SafeReason(reason),
      result = "SCHEDULED",
    }, true)
  end
  return true
end

local function CanonicalRosterToken(value)
  if not Accessible(value) or type(value) ~= "string" then
    return nil
  end
  if value == "player" or value == "pet" then
    return value
  end
  local prefix, index = value:match("^(party)(%d+)$")
  if not prefix then
    prefix, index = value:match("^(partypet)(%d+)$")
  end
  if prefix then
    index = tonumber(index)
    if index and index >= 1 and index <= 4 then
      return prefix .. tostring(index)
    end
    return nil
  end
  prefix, index = value:match("^(raid)(%d+)$")
  if not prefix then
    prefix, index = value:match("^(raidpet)(%d+)$")
  end
  if prefix then
    index = tonumber(index)
    if index and index >= 1 and index <= 40 then
      return prefix .. tostring(index)
    end
  end
  return nil
end

local function CommittedRosterUnits()
  local addon = Addon()
  if not addon then
    return nil, "ADDON_UNAVAILABLE"
  end
  local signature = addon.rosterOrderSignature
  if not Accessible(signature) or type(signature) ~= "string" then
    return nil, "ROSTER_NOT_COMMITTED"
  end
  local units = {}
  local seen = {}
  local counts = {player = 0, party = 0, raid = 0, pets = 0}
  for value in signature:gmatch("[^|]+") do
    local unit = CanonicalRosterToken(value)
    if unit and not seen[unit] then
      seen[unit] = true
      units[#units + 1] = unit
      if unit == "pet" or unit:find("pet", 1, true) then
        counts.pets = counts.pets + 1
      elseif unit == "player" then
        counts.player = counts.player + 1
      elseif unit:match("^raid%d+$") then
        counts.raid = counts.raid + 1
      else
        counts.party = counts.party + 1
      end
    end
  end
  counts.total = #units
  return units, counts
end

function ns.LearnPublicDispelAuraSpellId(spellId)
  local learnedNow = LearnSpellId(Public(spellId))
  if learnedNow then
    pendingSync = true
  end
  return learnedNow
end

local TYPE_KEY = {MAGIC = "magic", CURSE = "curse", DISEASE = "disease", POISON = "poison"}

local function CuratedSpellIds(pack)
  local capabilities = {}
  local actions = ns.GetKnownCures and ns.GetKnownCures(pack) or {}
  for i = 1, #actions do
    local types = actions[i] and actions[i].types
    for j = 1, type(types) == "table" and #types or 0 do
      capabilities[types[j]] = true
    end
  end
  local ids = {}
  local seen = {}
  local rows = ns.CURATED_DISPEL_ALERTS or {}
  for i = 1, #rows do
    local row = rows[i]
    local spellId = row and Public(row.id)
    if capabilities[TYPE_KEY[row and row.cureType]]
      and Accessible(spellId)
      and type(spellId) == "number"
      and spellId > 0
      and not seen[spellId]
    then
      ids[#ids + 1] = spellId
      seen[spellId] = true
    end
  end
  return ids
end

local function PairKey(unit, spellId)
  return unit .. "\31" .. tostring(spellId)
end

local function RegistrationKey(unit, spellId, trigger, soundFile, channel)
  return table.concat({PairKey(unit, spellId), tostring(trigger), soundFile, channel}, "\30")
end

local function CountExact(desired)
  local exact = 0
  for key in pairs(desired) do
    if registered[key] then
      exact = exact + 1
    end
  end
  return exact
end

local function RecordSoundResult(reason, result, rosterCounts)
  lastSoundResult = result
  if ns.DiagnosticRecord then
    ns.DiagnosticRecord("AURA_SOUND_RECONCILE", {
      active = RegistrationCount(),
      addFailed = lastAddFailed,
      desired = lastDesiredCount,
      exact = lastExactCount,
      party = rosterCounts and rosterCounts.party or 0,
      pets = rosterCounts and rosterCounts.pets or 0,
      player = rosterCounts and rosterCounts.player or 0,
      raid = rosterCounts and rosterCounts.raid or 0,
      reason = SafeReason(reason),
      removeFailed = lastRemoveFailed,
      result = result,
      stale = lastStaleCount,
    }, result == STATUS_SUCCESS)
  end
end

local function ClearRegistrations(reason, isRemovalRetry)
  local removeAPI = C_UnitAuras and C_UnitAuras.RemoveAuraSound
  local keys = {}
  for key in pairs(registered) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local removeFailed = 0
  lastSoundError = "NONE"
  if #keys > 0 and type(removeAPI) ~= "function" then
    removeFailed = #keys
    lastSoundError = "REMOVE_API_UNAVAILABLE"
  else
    for i = 1, #keys do
      local key = keys[i]
      local record = registered[key]
      local handle = record and Public(record.handle)
      if not Accessible(handle) or type(handle) ~= "number" then
        ForgetRegistration(key)
      else
        local ok = pcall(removeAPI, handle)
        if ok then
          ForgetRegistration(key)
        else
          removeFailed = removeFailed + 1
          lastSoundError = "REMOVE_EXCEPTION"
        end
      end
    end
  end
  lastDesiredCount = 0
  lastExactCount = 0
  lastStaleCount = RegistrationCount()
  lastAddFailed = 0
  lastRemoveFailed = removeFailed
  lastReplacementFallbacks = 0
  if removeFailed > 0 then
    pendingSync = true
    pendingMode = "clear"
    pendingReason = SafeReason(reason)
    ScheduleRemoveRetry(reason)
    RecordSoundResult(reason, STATUS_FAILURE)
    return false, STATUS_FAILURE, 0
  end
  pendingSync = false
  pendingMode = nil
  pendingReason = "NONE"
  if isRemovalRetry then
    ResetRemoveRetry()
  end
  ResetReplayRetry()
  RecordSoundResult(reason, STATUS_SUCCESS)
  return true, STATUS_SUCCESS, 0
end

local function ReconcileRegistrations(pack, units, rosterCounts, spellIds, trigger, reason)
  local soundFile = PackSoundFile(pack)
  local channel = PackChannel(pack)
  local desired = {}
  local desiredOrder = {}
  local desiredPairs = {}

  -- Spell-first ordering gives each committed unit one registration before the
  -- next spell is attempted if Blizzard imposes a transient capacity limit.
  for s = 1, #spellIds do
    local spellId = spellIds[s]
    for u = 1, #units do
      local unit = units[u]
      local pairKey = PairKey(unit, spellId)
      local key = RegistrationKey(unit, spellId, trigger, soundFile, channel)
      if not desired[key] then
        local record = {
          key = key,
          pairKey = pairKey,
          unitToken = unit,
          spellId = spellId,
          trigger = trigger,
          soundFile = soundFile,
          channel = channel,
        }
        desired[key] = record
        desiredPairs[pairKey] = true
        desiredOrder[#desiredOrder + 1] = record
      end
    end
  end

  local addFailed = 0
  local removeFailed = 0
  local replacementFallbacks = 0
  lastSoundError = "NONE"
  for i = 1, #desiredOrder do
    local record = desiredOrder[i]
    if not registered[record.key] then
      local ok, handle = pcall(C_UnitAuras.AddAuraSound, record.trigger, {
        unitToken = record.unitToken,
        spellID = record.spellId,
        soundFileName = record.soundFile,
        outputChannel = record.channel,
      })
      handle = ok and Public(handle) or nil
      if ok and Accessible(handle) and type(handle) == "number" then
        record.handle = handle
        RememberRegistration(record.key, record)
      else
        addFailed = addFailed + 1
        lastSoundError = ok and "ADD_NO_HANDLE" or "ADD_EXCEPTION"
      end
    end
  end

  if addFailed == 0 then
    local staleKeys = {}
    for key in pairs(registered) do
      if not desired[key] then
        staleKeys[#staleKeys + 1] = key
      end
    end
    table.sort(staleKeys)
    for i = 1, #staleKeys do
      local key = staleKeys[i]
      local record = registered[key]
      local handle = record and Public(record.handle)
      if not Accessible(handle) or type(handle) ~= "number" then
        ForgetRegistration(key)
      else
        local ok = pcall(C_UnitAuras.RemoveAuraSound, handle)
        if ok then
          ForgetRegistration(key)
        else
          removeFailed = removeFailed + 1
          lastSoundError = "REMOVE_EXCEPTION"
        end
      end
    end
  else
    for key, record in pairs(registered) do
      if not desired[key] and record and desiredPairs[record.pairKey] then
        replacementFallbacks = replacementFallbacks + 1
      end
    end
  end

  lastDesiredCount = #desiredOrder
  lastExactCount = CountExact(desired)
  lastStaleCount = math.max(0, RegistrationCount() - lastExactCount)
  lastAddFailed = addFailed
  lastRemoveFailed = removeFailed
  lastReplacementFallbacks = replacementFallbacks

  if addFailed > 0 then
    pendingSync = true
    pendingMode = "refresh"
    pendingReason = SafeReason(reason)
    ScheduleReplay("ADD_FAILED")
    RecordSoundResult(reason, STATUS_FAILURE, rosterCounts)
    return false, STATUS_FAILURE, 0
  end
  if removeFailed > 0 then
    pendingSync = true
    pendingMode = "refresh"
    pendingReason = SafeReason(reason)
    ScheduleRemoveRetry(reason)
    RecordSoundResult(reason, STATUS_FAILURE, rosterCounts)
    return false, STATUS_FAILURE, 0
  end
  if lastExactCount ~= lastDesiredCount or lastStaleCount ~= 0 then
    pendingSync = true
    pendingMode = "refresh"
    pendingReason = SafeReason(reason)
    ScheduleReplay("COVERAGE_MISMATCH")
    lastSoundError = "COVERAGE_MISMATCH"
    RecordSoundResult(reason, STATUS_FAILURE, rosterCounts)
    return false, STATUS_FAILURE, 0
  end

  pendingSync = false
  pendingMode = nil
  pendingReason = "NONE"
  ResetReplayRetry()
  ResetRemoveRetry()
  RecordSoundResult(reason, STATUS_SUCCESS, rosterCounts)
  return true, STATUS_SUCCESS, 0
end

local function CombatLockedPublic()
  if type(InCombatLockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(InCombatLockdown)
  return ok and Accessible(locked) and locked == true
end

SyncNativeSounds = function(reason, isReplay, isRemovalRetry)
  reason = SafeReason(reason or "REFRESH")
  local pack = GetPack()
  local alerts = type(pack) == "table" and type(pack.alerts) == "table" and pack.alerts or nil
  local enabled = alerts and alerts.sound == true and alerts.nativeAuraSound == true
  local landingTextEnabled = alerts and alerts.text ~= false and alerts.dispelEnabled ~= false
  local inactiveWithoutNativeState = not enabled
    and not landingTextEnabled
    and RegistrationCount() == 0
    and lastAddFailed == 0
    and lastRemoveFailed == 0
    and removeRetryScheduled ~= true

  -- A fully quiet Alerts consumer with no owned native state has nothing to
  -- mutate.  In particular, PvP chat lockdown must not prevent an unrelated
  -- roster transaction from committing its MUF bank.
  if inactiveWithoutNativeState then
    pendingSync = false
    pendingMode = nil
    pendingReason = "NONE"
    lastDesiredCount = 0
    lastExactCount = 0
    lastStaleCount = 0
    lastSoundError = "NONE"
    ResetReplayRetry()
    ResetRemoveRetry()
    RecordSoundResult(reason, STATUS_SUCCESS)
    return true, STATUS_SUCCESS, 0
  end

  pendingSync = true
  pendingMode = enabled and "refresh" or "clear"
  pendingReason = reason
  if not isReplay and not isRemovalRetry then
    ResetReplayRetry()
    ResetRemoveRetry()
  end

  local blocked, blockReason = SoundMessagingLocked()
  if blocked then
    lastSoundResult = CombatLockedPublic() and STATUS_DEFERRED_COMBAT or STATUS_DEFERRED_RESTRICTED
    lastSoundError = blockReason or "MUTATION_BLOCKED"
    ScheduleReplay(lastSoundError)
    RecordSoundResult(reason, lastSoundResult)
    return false, lastSoundResult, 0
  end

  if not enabled then
    return ClearRegistrations(reason, isRemovalRetry)
  end
  if not C_UnitAuras or type(C_UnitAuras.AddAuraSound) ~= "function" or type(C_UnitAuras.RemoveAuraSound) ~= "function" then
    lastSoundError = "NATIVE_API_UNAVAILABLE"
    lastSoundResult = STATUS_FAILURE
    lastDesiredCount = 0
    lastExactCount = 0
    lastStaleCount = RegistrationCount()
    lastAddFailed = 0
    lastRemoveFailed = 0
    RecordSoundResult(reason, STATUS_FAILURE)
    return false, STATUS_FAILURE, 0
  end

  local units, rosterState = CommittedRosterUnits()
  if not units then
    lastSoundError = rosterState or "ROSTER_NOT_COMMITTED"
    lastSoundResult = STATUS_DEFERRED_RESTRICTED
    ScheduleReplay(lastSoundError)
    RecordSoundResult(reason, STATUS_DEFERRED_RESTRICTED)
    return false, STATUS_DEFERRED_RESTRICTED, 0
  end
  local spellIds = CuratedSpellIds(pack)
  lastCuratedCount = #spellIds
  if #units == 0 or #spellIds == 0 then
    return ClearRegistrations(reason, isRemovalRetry)
  end
  local trigger = TriggerAdded()
  if type(trigger) ~= "number" then
    lastSoundError = "ADDED_TRIGGER_UNAVAILABLE"
    lastSoundResult = STATUS_FAILURE
    lastDesiredCount = #units * #spellIds
    lastExactCount = 0
    lastStaleCount = RegistrationCount()
    RecordSoundResult(reason, STATUS_FAILURE, rosterState)
    return false, STATUS_FAILURE, 0
  end
  return ReconcileRegistrations(pack, units, rosterState, spellIds, trigger, reason)
end

local moveMode = false

local function DispelColor(pack)
  local alerts = type(pack) == "table" and type(pack.alerts) == "table" and pack.alerts or nil
  local color = alerts and alerts.dispelColor
  if type(color) ~= "table" then
    return 1, 0.15, 0.15, 1
  end
  return tonumber(color[1]) or 1,
    tonumber(color[2]) or 0.15,
    tonumber(color[3]) or 0.15,
    tonumber(color[4]) or 1
end

local function AlertFont(pack)
  local alerts = type(pack) == "table" and type(pack.alerts) == "table" and pack.alerts or nil
  local size = math.max(12, math.min(96, tonumber(alerts and alerts.dispelFontSize) or 48))
  local fontPath = GameFontNormalHuge and select(1, GameFontNormalHuge:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  return fontPath, size
end

local function ApplyFontStyle(fontString, pack, outline)
  if not fontString then
    return
  end
  local fontPath, size = AlertFont(pack)
  local r, g, b, a = DispelColor(pack)
  fontString:SetFont(fontPath, size, outline or "THICKOUTLINE")
  fontString:SetTextColor(r, g, b, a)
end

local function SaveTextPoint()
  if not textFrame then
    return
  end
  local pack = GetPack()
  if not pack or not pack.alerts then
    return
  end
  local point, _, relPoint, x, y = textFrame:GetPoint(1)
  pack.alerts.alertPoint = {
    point = point or "TOP",
    relPoint = relPoint or point or "TOP",
    x = x or 0,
    y = y or -160,
  }
end

local function RestoreTextPoint()
  local pack = GetPack()
  local saved = pack and pack.alerts and pack.alerts.alertPoint
  if type(saved) ~= "table" or not textFrame then
    return
  end
  local point = saved.point or saved[1]
  local relPoint = saved.relPoint or saved[2] or point
  local x = saved.x or saved[3]
  local y = saved.y or saved[4]
  if type(point) == "string" and type(relPoint) == "string" then
    textFrame:ClearAllPoints()
    textFrame:SetPoint(point, UIParent, relPoint, x or 0, y or 0)
  end
end

local function ApplyMoveMode()
  if not textFrame then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  textFrame:EnableMouse(moveMode)
  textFrame:SetMovable(moveMode)
  if moveMode then
    textFrame:RegisterForDrag("LeftButton")
    textFrame:Show()
  else
    textFrame:RegisterForDrag()
  end
  return true
end

local function EnsureTextFrame()
  if textFrame then
    ApplyMoveMode()
    return
  end
  textFrame = CreateFrame("Frame", "DecursiveRebuildDispelText", UIParent)
  textFrame:SetSize(340, 80)
  textFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
  textFrame:SetFrameStrata("HIGH")
  textFrame:Hide()
  RestoreTextPoint()
  textFont = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  textFont:SetAllPoints()
  textFont:SetJustifyH("CENTER")
  ApplyFontStyle(textFont, GetPack(), "THICKOUTLINE")
  textFrame:SetScript("OnDragStart", function(self)
    if moveMode then
      self:StartMoving()
    end
  end)
  textFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveTextPoint()
  end)
  textFrame:SetScript("OnUpdate", function(self)
    if hideAt > 0 and GetTime and GetTime() >= hideAt then
      hideAt = 0
      if not moveMode then
        self:Hide()
      end
    end
  end)
  ApplyMoveMode()
end

local function ShowDispelText(message, pack)
  if not pack.alerts or not pack.alerts.dispelEnabled then
    return
  end
  if pack.alerts.text == false and pack.alerts.pvpText ~= true then
    return
  end
  EnsureTextFrame()
  ApplyFontStyle(textFont, pack, "THICKOUTLINE")
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

local function ShowCopyableAlertText(text)
  if type(text) ~= "string" then
    return false
  end
  if ns.Diagnostics and type(ns.Diagnostics.ShowText) == "function" then
    return ns.Diagnostics.ShowText(text) == true
  end
  return false
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
    ShowCopyableAlertText(line)
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

local DISPEL_TEXT_MAP = {Magic = "DISPEL", Curse = "DISPEL", Disease = "DISPEL", Poison = "DISPEL"}

function ns.ConfigureDispelAlertSlot(slot)
  if not slot or alertLayers[slot] then
    return
  end
  EnsureTextFrame()
  local pack = GetPack()
  local r, g, b, a = DispelColor(pack)
  local fontPath, size = AlertFont(pack)
  local layer = {}
  if slot.SetDurationText and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
    local text = slot:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", textFrame, "CENTER")
    text:SetFont(fontPath, size, "THICKOUTLINE")
    if text.SetIgnoreParentScale then
      text:SetIgnoreParentScale(true)
    end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    local enabled = pack.alerts.text ~= false and pack.alerts.dispelEnabled ~= false and pack.alerts.dispelMode ~= "UNTIL_CLEARED"
    local duration = pack.alerts.dispelDuration or 2
    curve:AddPoint(0, CreateColor(r, g, b, enabled and a or 0))
    curve:AddPoint(duration, CreateColor(r, g, b, 0))
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetToDefaults()
    binding:SetTextFormat("DISPEL", {})
    binding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.ElapsedDuration)
    binding:SetZeroDurationText("")
    binding:SetExpiredText("")
    binding:SetUpdateInterval(0.05)
    slot:SetDurationText(text, {binding = binding})
    layer.timed = text
    layer.curve = curve
  end
  if slot.SetDispelTypeText then
    local text = slot:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", textFrame, "CENTER")
    text:SetFont(fontPath, size, "THICKOUTLINE")
    text:SetTextColor(r, g, b, a)
    text:SetAlpha(pack.alerts.text ~= false and pack.alerts.dispelEnabled ~= false and pack.alerts.dispelMode == "UNTIL_CLEARED" and 1 or 0)
    slot:SetDispelTypeText(text, {showWhenHarmful = true, showWhenHelpful = false, showWithoutDispelType = false, customDispelTextMap = DISPEL_TEXT_MAP})
    layer.persistent = text
  end
  alertLayers[slot] = layer
end

function ns.PlayCureFailureSound()
  local pack = GetPack()
  if not pack.alerts or not pack.alerts.errorSound then
    return
  end
  PlayPreset(pack, "failure")
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

local function ShowSuccessfulDispelText(pack)
  EnsureTextFrame()
  local duration = math.max(0.5, math.min(30, tonumber(pack.alerts.dispelDuration) or 2))
  ApplyFontStyle(textFont, pack, "THICKOUTLINE")
  textFont:SetText("Dispelled")
  textFrame:Show()
  hideAt = (GetTime and GetTime() or 0) + duration
end

function ns.NotifyCureSucceeded(_unit)
  local pack = GetPack()
  if not pack.alerts or pack.alerts.successfulDispelText ~= true then
    return false
  end
  local now = GetTime and GetTime() or 0
  if now - lastTextAt < 0.2 then
    return false
  end
  lastTextAt = now
  ShowSuccessfulDispelText(pack)
  return true
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
  if sl and sl.enabled == false then
    return
  end
  local who = UnitLabel(nil, destName)
  if who == "unit" then
    who = "your target"
  end
  EnsureTextFrame()
  ApplyFontStyle(textFont, pack, "THICKOUTLINE")
  textFont:SetText("Battle rez: move within range of " .. who .. "!")
  textFrame:Show()
  hideAt = (GetTime and GetTime() or 0) + 2.5
  PrintLine("Battle rez: move within range of " .. who, false, pack)
end

function ns.BeginSoulLinkAttempt(unit)
  unit = Public(unit)
  if type(unit) ~= "string" then
    soulLinkAttempt = nil
    return false
  end
  soulLinkAttempt = {unit = unit, startedAt = GetTime and GetTime() or 0}
  return true
end

local function OnUIError(errorType, message)
  local attempt = soulLinkAttempt
  local now = GetTime and GetTime() or 0
  if not attempt or now - attempt.startedAt > 0.80 then
    return
  end
  errorType = Public(errorType)
  message = Public(message)
  if not Accessible(errorType) or not Accessible(message) then
    return
  end
  if message == SPELL_FAILED_OUT_OF_RANGE or message == ERR_OUT_OF_RANGE then
    soulLinkAttempt = nil
    local name = UnitName and Public(UnitName(attempt.unit)) or nil
    ShowSoulLinkWarning(type(name) == "string" and name or "your target")
  end
end

local function RegisterEvents()
  if eventsOn then
    return
  end
  eventsOn = true
  eventFrame = CreateFrame("Frame")
  eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "GROUP_ROSTER_UPDATE" then
      pendingSync = true
      if not SoundMessagingLocked() then
        ns.RefreshAlerts("GROUP_ROSTER_UPDATE")
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if pendingSync then
        ns.RefreshAlerts("PLAYER_REGEN_ENABLED")
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      pendingSync = true
      ns.RefreshAlerts("PLAYER_ENTERING_WORLD")
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
      if pendingSync and not SoundMessagingLocked() then
        ns.RefreshAlerts("RESTRICTION_STATE_CHANGED")
      end
    elseif event == "LOADING_SCREEN_ENABLED" then
      pendingSync = true
    elseif event == "UI_ERROR_MESSAGE" then
      OnUIError(arg1, arg2)
    end
  end)
  if not ns.DetectionEngine then
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED") then
      eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    end
  end
  eventFrame:RegisterEvent("LOADING_SCREEN_ENABLED")
  eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

function ns.RefreshAlerts(reason)
  if ns.DiagnosticModuleRefresh then
    ns.DiagnosticModuleRefresh("Alerts")
  end
  local soundOK, soundStatus, expectedCount = SyncNativeSounds(reason or "REFRESH_ALERTS", false, false)
  if not ns.AuraDisplayMutationBlocked or not ns.AuraDisplayMutationBlocked() then
    local pack = GetPack()
    RestoreTextPoint()
    if textFont then
      ApplyFontStyle(textFont, pack, "THICKOUTLINE")
    end
    local r, g, b, a = DispelColor(pack)
    local fontPath, size = AlertFont(pack)
    local enabled = pack.alerts.text ~= false and pack.alerts.dispelEnabled ~= false
    local timed = enabled and pack.alerts.dispelMode ~= "UNTIL_CLEARED"
    local duration = math.max(0.5, math.min(30, tonumber(pack.alerts.dispelDuration) or 2))
    for _slot, layer in pairs(alertLayers) do
      if layer.curve then
        layer.curve:ClearPoints()
        layer.curve:AddPoint(0, CreateColor(r, g, b, timed and a or 0))
        layer.curve:AddPoint(duration, CreateColor(r, g, b, 0))
      end
      if layer.timed then
        layer.timed:SetFont(fontPath, size, "THICKOUTLINE")
        layer.timed:SetTextColor(r, g, b, a)
      end
      if layer.persistent then
        layer.persistent:SetFont(fontPath, size, "THICKOUTLINE")
        layer.persistent:SetTextColor(r, g, b, a)
        layer.persistent:SetAlpha(enabled and not timed and 1 or 0)
      end
    end
  end
  return soundOK == true, soundStatus or STATUS_FAILURE, expectedCount or 0
end


function ns.GetAuraSoundRegistryStatus()
  return {
    active = RegistrationCount(),
    desired = lastDesiredCount,
    exact = lastExactCount,
    stale = lastStaleCount,
    addFailed = lastAddFailed,
    removeFailed = lastRemoveFailed,
    replacementFallbacks = lastReplacementFallbacks,
    pending = pendingSync == true,
    pendingMode = pendingMode or "NONE",
    pendingReason = pendingReason,
    replayPending = replayScheduled == true,
    replayAttempts = replayAttempts,
    replayExhausted = replayExhausted == true,
    removeRetryPending = removeRetryScheduled == true,
    removeRetryAttempts = removeRetryAttempts,
    removeRetryExhausted = removeRetryExhausted == true,
    result = lastSoundResult,
    errorCode = lastSoundError,
  }
end

function ns.PrintAuraSoundDiagnostics(_spellId, _unitToken)
  local pack = GetPack()
  local store = EnsureLearnedStore()
  local status = ns.GetAuraSoundRegistryStatus()
  local locked = SoundMessagingLocked()
  local lines = {
    "Decursive Aura Sound Diagnostic",
    "native AddAuraSound: " .. ((C_UnitAuras and type(C_UnitAuras.AddAuraSound) == "function") and "yes" or "no"),
    "native RemoveAuraSound: " .. ((C_UnitAuras and type(C_UnitAuras.RemoveAuraSound) == "function") and "yes" or "no"),
    "sound enabled: " .. tostring(pack.alerts and pack.alerts.sound == true),
    "nativeAuraSound: " .. tostring(pack.alerts and pack.alerts.nativeAuraSound == true),
    "stored learned ids (inactive): " .. tostring(#store),
    "coverage: " .. tostring(status.exact) .. "/" .. tostring(status.desired) .. " exact; " .. tostring(status.active) .. " active; " .. tostring(status.stale) .. " stale",
    "last reconcile: " .. tostring(status.result) .. " error=" .. tostring(status.errorCode),
    "last failures: add=" .. tostring(status.addFailed) .. " remove=" .. tostring(status.removeFailed) .. " replacement fallbacks=" .. tostring(status.replacementFallbacks),
    "pending: " .. tostring(status.pending) .. " mode=" .. tostring(status.pendingMode) .. " reason=" .. tostring(status.pendingReason),
    "bounded replay: pending=" .. tostring(status.replayPending) .. " attempts=" .. tostring(status.replayAttempts) .. "/" .. tostring(MAX_REPLAY_RETRIES) .. " exhausted=" .. tostring(status.replayExhausted),
    "removal retry: pending=" .. tostring(status.removeRetryPending) .. " attempts=" .. tostring(status.removeRetryAttempts) .. "/" .. tostring(MAX_REMOVE_RETRIES) .. " exhausted=" .. tostring(status.removeRetryExhausted),
    "chat-messaging lockdown: " .. tostring(locked),
  }
  lines[#lines + 1] = "identity details: redacted"
  local text = table.concat(lines, "\n")
  ShowCopyableAlertText(text)
  return text
end


function ns.HandleAlertsSlash(msg)
  msg = strtrim(tostring(msg or "")):lower()
  local pack = GetPack()
  if type(pack) ~= "table" then
    return
  end
  if type(pack.alerts) ~= "table" then
    pack.alerts = {}
  end
  local function Status()
    local lines = {
      "alerts status",
      "sound: " .. tostring(pack.alerts.sound == true),
      "dispelEnabled: " .. tostring(pack.alerts.dispelEnabled ~= false),
      "nativeAuraSound: " .. tostring(pack.alerts.nativeAuraSound == true),
      "chat: " .. tostring(pack.alerts.chat ~= false),
      "errorSound: " .. tostring(pack.alerts.errorSound == true),
    }
    ShowCopyableAlertText(table.concat(lines, "\n"))
  end
  if msg == "move" then
    moveMode = not moveMode
    EnsureTextFrame()
    local applied = ApplyMoveMode()
    if applied then
      local state = moveMode and "unlocked" or "locked"
      ShowCopyableAlertText("Decursive alert text " .. state .. ". Drag to move, /dcralerts move to lock.")
    else
      ShowCopyableAlertText("Decursive alert text move deferred until combat ends.")
    end
    return
  end
  if msg == "on" then
    pack.alerts.sound = true
    pack.alerts.dispelEnabled = true
    ns.RefreshAlerts()
    if ns.Notify then
      ns.Notify()
    end
    Status()
    return
  end
  if msg == "off" then
    pack.alerts.sound = false
    pack.alerts.dispelEnabled = false
    ns.RefreshAlerts()
    if ns.Notify then
      ns.Notify()
    end
    Status()
    return
  end
  if msg ~= "" and msg ~= "status" then
    ShowCopyableAlertText("Decursive Alerts Help\n/dcralerts [on|off|status|move]")
    return
  end
  Status()
end

function ns.HandleAlertDiagSlash(msg)
  msg = strtrim(tostring(msg or ""))
  ns.PrintAuraSoundDiagnostics(tonumber(msg), nil)
end

function ns.ApplyAlertMoveMode()
  EnsureTextFrame()
  ApplyMoveMode()
end

function ns.PlayTestSound(kind)
  local pack = GetPack()
  if type(pack) ~= "table" then
    return
  end
  local file
  if kind == "failure" then
    file = PRESET_FILES.FAILURE
  else
    file = PackSoundFile(pack)
  end
  local channel = PackChannel(pack)
  if PlaySoundFile and file then
    PlaySoundFile(file, channel)
  end
end

function ns.PlayTestText(packOverride)
  if type(InCombatLockdown) == "function" then
    local ok, locked = pcall(InCombatLockdown)
    if not ok or not Accessible(locked) or locked == true then
      return false, "COMBAT"
    end
  end
  local pack = type(packOverride) == "table" and packOverride or GetPack()
  if type(pack) ~= "table" or type(pack.alerts) ~= "table" then
    return false, "PACK_UNAVAILABLE"
  end
  EnsureTextFrame()
  ApplyFontStyle(textFont, pack, "THICKOUTLINE")
  textFont:SetText("DISPEL")
  textFrame:Show()
  hideAt = (GetTime and GetTime() or 0) + math.max(0.5, math.min(30, tonumber(pack.alerts.dispelDuration) or 2))
  return true, "PREVIEW"
end

function ns.EnableAlerts(_addon)
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Alerts", false)
  end
  if ns.DetectionEngine and type(ns.DetectionEngine.RegisterConsumer) == "function" then
    ns.DetectionEngine:RegisterConsumer("Alerts", function(reason)
      return ns.RefreshAlerts(reason or "ENGINE_CONSUMER")
    end)
  end
  EnsureLearnedStore()
  RegisterEvents()
  ns.RefreshAlerts()
  EnsureTextFrame()
  if ns.DiagnosticModuleEnabled then
    ns.DiagnosticModuleEnabled("Alerts", true)
  end
end

if ns.RegisterDiagnosticProvider then
  ns.RegisterDiagnosticProvider("Alerts", function()
    local frameShown = false
    if textFrame and type(textFrame.IsShown) == "function" then
      local ok, shown = pcall(textFrame.IsShown, textFrame)
      local public = ns.Diagnostics and ns.Diagnostics.SafePublicBoolean(shown) or nil
      frameShown = ok and public == true
    end
    local pack = GetPack()
    local alerts = type(pack) == "table" and type(pack.alerts) == "table" and pack.alerts or {}
    return {
      eventsRegistered = eventsOn,
      pendingRefresh = pendingSync,
      nativeRegistrations = RegistrationCount(),
      nativeDesiredRegistrations = lastDesiredCount,
      nativeExactRegistrations = lastExactCount,
      nativeStaleRegistrations = lastStaleCount,
      nativeAddFailures = lastAddFailed,
      nativeRemoveFailures = lastRemoveFailed,
      nativeReplacementFallbacks = lastReplacementFallbacks,
      nativeLastResult = lastSoundResult,
      nativeLastError = lastSoundError,
      nativePendingMode = pendingMode or "NONE",
      nativeReplayAttempts = replayAttempts,
      nativeReplayExhausted = replayExhausted,
      nativeRemoveRetryAttempts = removeRetryAttempts,
      nativeRemoveRetryExhausted = removeRetryExhausted,
      learnedStoredIgnoredCount = #EnsureLearnedStore(),
      actionableCuratedCount = lastCuratedCount,
      actionableTypeCount = 4,
      textFrameCreated = textFrame ~= nil,
      textFrameShown = frameShown,
      soundConfigured = alerts.sound == true,
      soundMode = alerts.sound == true and alerts.nativeAuraSound == true and "NATIVE_ADDED" or "OFF",
      textConfigured = alerts.dispelEnabled ~= false,
      textMode = alerts.dispelEnabled ~= false and (alerts.dispelMode == "UNTIL_CLEARED" and "PROVIDER_UNTIL_CLEARED" or "PROVIDER_TIMED") or "OFF",
      successTextMode = alerts.successfulDispelText == true and "AFTER_CONFIRMED_CURE" or "OFF",
      soulLinkMode = alerts.soulLinkAlert ~= false and "RANGE_FAILURE" or "OFF",
      providerPayloadRead = false,
      chatLockdown = SoundMessagingLocked(),
    }
  end)
end

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Alerts")
end
