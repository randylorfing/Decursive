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

-- ZDecursive test support, Copyright (C) 2026 Randy Lorfing.
-- GPL-3.0-or-later; distributed without warranty. See the repository LICENSE.
-- Exercises the real presenter with public caller attribution supplied by MUFs.
local checks = 0
local function Check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function Read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local packs = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  Check(packs[row.key].alerts.outOfRangeDispel == true, row.key .. " enables the new range warning")
  Check(packs[row.key].mufs.dimAfflictedOutOfRange == true, row.key .. " enables afflicted dimming")
  Check(packs[row.key].mufs.dimOutOfRange == true and packs[row.key].mufs.dimAmount == 0.50,
    row.key .. " defaults unafflicted out-of-range squares to 50% brightness")
end
Check(packs.OPEN_WORLD.alerts.range == false, "old unused Open World alert preference remains unchanged")
Check(ns.MUF_APPEARANCE_SCHEMA == 9, "range brightness has the expected migration schema")
Check(packs.PVP.alerts.text == false and packs.PVP.alerts.sound == false, "PvP master preferences remain unchanged")
packs.RAID.alerts.outOfRangeDispel = false
packs.RAID.mufs.dimAfflictedOutOfRange = false
Check(packs.DUNGEON.alerts.outOfRangeDispel and packs.DUNGEON.mufs.dimAfflictedOutOfRange,
  "new environment controls have independent storage")
local copied = ns.DeepCopy(packs.RAID)
Check(copied.alerts.outOfRangeDispel == false and copied.mufs.dimAfflictedOutOfRange == false,
  "copy preserves explicit disabled choices")
Check(ns.MakePack("RAID").alerts.outOfRangeDispel and ns.MakePack("RAID").mufs.dimAfflictedOutOfRange,
  "reset restores both new defaults")
Check(ns.PREVIOUS_PVP_ALERT_DEFAULTS.outOfRangeDispel == nil,
  "historical PvP migration signature does not gain a new key")
local oldPvP = {alerts = ns.DeepCopy(ns.PREVIOUS_PVP_ALERT_DEFAULTS)}
Check(ns.MigratePvPQuietAlertDefaults(oldPvP) == 1, "historical pre-fill PvP migration remains eligible")

local now, shown, hidden, playbackCalls = 10, 0, 0, 0
local displayedText, displayedFont, displayedColor, frame, displayFont
local screenWidth, combat = 1920, true
local diagnostics, appliedPack = {}, packs.DUNGEON
local playbackResult, playbackFailure, lastFile, lastChannel = true, false
local secret = {}
UIParent = {GetWidth = function() return screenWidth end}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GetTime = function() return now end
InCombatLockdown = function() return combat end
UnitName = function() error("dispel range warning must not read unit names") end
SPELL_FAILED_OUT_OF_RANGE, ERR_OUT_OF_RANGE = "Out of range", "Out of range"
ns.IsAccessible = function(value) return value ~= secret end
ns.PublicValue = function(value) if value ~= secret then return value end end
ns.addon = {GetAppliedEnvironmentPack = function() return appliedPack end}
ns.Diagnostics = {
  AppendRuntimeMessage = function(message)
    diagnostics[#diagnostics + 1] = message
    return true
  end,
  ShowText = function() error("range failure must not open diagnostics") end,
}
PlaySoundFile = function(file, channel)
  playbackCalls = playbackCalls + 1
  lastFile, lastChannel = file, channel
  if playbackFailure then error("native playback failed") end
  return playbackResult, 44
end
CreateFrame = function(kind, name, _, template)
  Check(kind == "Frame" and template == nil, "range warning only creates an ordinary frame")
  Check(name == "DecursiveRebuildDispelText", "range uses existing shared text presentation")
  frame = {scripts = {}}
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:SetPoint() end
  function frame:ClearAllPoints() end
  function frame:SetFrameStrata() end
  function frame:SetMovable() assert(not combat, "combat must not change movement") end
  function frame:EnableMouse() assert(not combat, "combat must not change mouse behavior") end
  function frame:RegisterForDrag() assert(not combat, "combat must not change drag behavior") end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  function frame:Show() shown = shown + 1 end
  function frame:Hide() hidden = hidden + 1 end
  function frame:CreateFontString()
    local font = {anchors = {}}
    displayFont = font
    function font:SetAllPoints() error("alert font height must stay unconstrained") end
    function font:SetPoint(point) self.anchors[point] = true end
    function font:SetJustifyH() end
    function font:SetWordWrap(value) self.wordWrap = value end
    function font:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
    function font:SetFont(...) displayedFont = {...} end
    function font:SetTextColor(...) displayedColor = {...} end
    function font:SetText(value) displayedText = value end
    function font:GetUnboundedStringWidth() return #displayedText * displayedFont[2] * 0.62 end
    function font:GetStringHeight()
      local charWidth = displayedFont[2] * 0.62
      local capacity = math.max(1, math.floor((frame.width - 24) / charWidth))
      local lines, used = 1, 0
      for word in displayedText:gmatch("%S+") do
        if used > 0 and used + 1 + #word > capacity then lines, used = lines + 1, 0 end
        if used > 0 then used = used + 1 end
        used = used + #word
        while used > capacity do lines, used = lines + 1, used - capacity end
      end
      return lines * displayedFont[2] * 1.2
    end
    return font
  end
  return frame
end
local source = Read("ZDecursive/Alerts.lua")
assert(load(source .. "\nns.__rangeUIError = OnUIError; ns.__soulLinkText = ShowSoulLinkWarning", "Alerts.lua", "t", _G))("ZDecursive", ns)

local alerts = appliedPack.alerts
alerts.dispelEnabled, alerts.successfulDispelText, alerts.soulLinkAlert, alerts.range = false, false, false, false
alerts.dispelFontSize, alerts.dispelColor = 37, {0.2, 0.4, 0.6, 1}
alerts.dispelDuration, alerts.dispelMode, alerts.soundDebounce, alerts.soundChannel = 3, "UNTIL_CLEARED", 0, "Dialog"
local visual, sound = ns.NotifyCureOutOfRange()
Check(visual == true and sound == true and shown == 1 and playbackCalls == 1, "eligible attempt shows text and plays failure audio")
Check(displayedText == "OUT OF RANGE", "warning has exact text without an identity payload")
Check(displayedFont[2] == 37 and displayedColor[1] == 0.2, "warning shares configured font and color")
Check(lastFile == "Interface\\AddOns\\ZDecursive\\Sounds\\FailedSpell.ogg" and lastChannel == "Dialog",
  "warning uses existing failure sound and selected audio channel")
Check(#diagnostics == 1 and diagnostics[1] == "Dispel attempt out of range", "bounded diagnostic route receives only a static message")

now = 10.1
visual, sound = ns.NotifyCureOutOfRange()
Check(visual == false and sound == false and shown == 1 and playbackCalls == 1 and #diagnostics == 1,
  "repeat range clicks are throttled even with zero sound debounce")
alerts.successfulDispelText = true
Check(ns.NotifyCureSucceeded(secret) == true and displayedText == "Dispelled",
  "range warning debounce never suppresses a valid confirmed success")
now = 10.6
visual, sound = ns.NotifyCureOutOfRange()
Check(visual and sound and displayedText == "OUT OF RANGE", "warning can retrigger after its own delay")
local hiddenBefore = hidden
now = 13.59
frame.scripts.OnUpdate(frame)
Check(hidden == hiddenBefore, "warning remains for configured duration")
now = 13.61
frame.scripts.OnUpdate(frame)
Check(hidden == hiddenBefore + 1, "range warning stays timed even when landing text is Until cleared")

local function NextAttempt()
  now = now + 10
  return ns.NotifyCureOutOfRange()
end
local shownBefore, soundsBefore, logsBefore = shown, playbackCalls, #diagnostics
alerts.outOfRangeDispel = false
visual, sound = NextAttempt()
Check(visual == false and sound == false and shown == shownBefore and playbackCalls == soundsBefore and #diagnostics == logsBefore,
  "own disabled toggle prevents all immediate range-warning effects")
alerts.outOfRangeDispel, alerts.text = true, false
visual, sound = NextAttempt()
Check(visual == false and sound == true and shown == shownBefore and playbackCalls == soundsBefore + 1,
  "text master disables visual only and keeps independent failure audio")
alerts.text, alerts.sound = true, false
visual, sound = NextAttempt()
Check(visual == true and sound == false and playbackCalls == soundsBefore + 1, "sound master silences audio without suppressing text")
alerts.sound, alerts.errorSound = true, false
visual, sound = NextAttempt()
Check(visual == true and sound == false and playbackCalls == soundsBefore + 1, "failure toggle silences range audio")
alerts.errorSound, alerts.printErrors = true, false
logsBefore = #diagnostics
visual, sound = NextAttempt()
Check(visual and sound and #diagnostics == logsBefore, "error log toggle is honored")
alerts.printErrors, alerts.printChat = true, false
NextAttempt()
Check(#diagnostics == logsBefore, "copyable-diagnostics route toggle is honored")
alerts.printChat = true

alerts.soundDebounce = 5
now = now + 0.6
visual, sound = ns.NotifyCureOutOfRange()
Check(visual == true and sound == false, "accurate sound return reports debounce suppression")
alerts.soundDebounce = 0
playbackResult = false
visual, sound = NextAttempt()
Check(visual == true and sound == false, "failed native playback cannot suppress a later confirmed failure sound")
playbackResult = nil
Check(ns.PlayCureFailureSound() == false, "absent native success is not claimed as playback")
playbackResult = secret
Check(ns.PlayCureFailureSound() == false, "opaque playback result is rejected without interpreting it")
playbackFailure = true
Check(ns.PlayCureFailureSound() == false, "native playback exception safely reports no sound")
playbackFailure, playbackResult = false, true
Check(ns.PlayCureFailureSound() == true, "known successful playback is returned to attempt deduplication")
PlaySoundFile = nil
Check(ns.PlayCureFailureSound() == false, "unavailable playback API reports no sound")

appliedPack = packs.RAID
visual, sound = NextAttempt()
Check(visual == false and sound == false, "runtime warning follows applied environment's disabled choice")
appliedPack = packs.PVP
visual, sound = NextAttempt()
Check(visual == false and sound == false, "PvP master text and sound defaults remain quiet")
shownBefore, logsBefore = shown, #diagnostics
ns.__rangeUIError(0, SPELL_FAILED_OUT_OF_RANGE)
Check(shown == shownBefore and #diagnostics == logsBefore, "unattributed generic UI error cannot route to dispel range warning")
appliedPack = packs.DUNGEON
alerts.dispelDuration = 999
NextAttempt()
hiddenBefore = hidden
now = now + 30.01
frame.scripts.OnUpdate(frame)
Check(hidden == hiddenBefore + 1, "invalid long duration is bounded")

-- Measured public text sizes determine the shared box rather than fixed 340x80.
local function CheckFits(expected, width, size)
  Check(displayedText == expected and displayedFont[2] == size, "complete text and configured font are preserved")
  Check(frame.width <= width - 32 and frame.width >= 48, "text box stays within screen width")
  Check(frame.height >= displayFont:GetStringHeight() + 16, "text box includes every wrapped line with padding")
  Check(displayFont.anchors.TOPLEFT and displayFont.anchors.TOPRIGHT and not displayFont.anchors.BOTTOMRIGHT,
    "font width is anchored while its height remains unconstrained")
  Check(displayFont.wordWrap and displayFont.nonSpaceWrap, "long text can wrap without truncating words")
end
alerts.sound, alerts.successfulDispelText, alerts.soulLinkAlert, alerts.chat = false, true, true, false
for _, width in ipairs({1920, 640, 320}) do
  screenWidth = width
  for _, size in ipairs({12, 48, 96}) do
    alerts.dispelFontSize = size
    NextAttempt()
    CheckFits("OUT OF RANGE", width, size)
    if width == 1920 and size == 96 then
      Check(frame.width > 340 and frame.height > 80, "large range alert expands beyond both old clipping limits")
    end
    now = now + 1
    Check(ns.NotifyCureSucceeded(secret), "success still uses the shared text box")
    CheckFits("Dispelled", width, size)
    combat = false
    Check(ns.PlayTestText(appliedPack), "text preview remains available outside combat")
    combat = true
    CheckFits("DISPEL", width, size)
    ns.__soulLinkText("Averylongpublictargetname")
    CheckFits("Battle rez: move within range of Averylongpublictargetname!", width, size)
  end
end
screenWidth = secret
displayFont.GetUnboundedStringWidth = function() return secret end
displayFont.GetStringHeight = function() return secret end
alerts.dispelFontSize = 96
NextAttempt()
Check(type(frame.width) == "number" and type(frame.height) == "number" and frame.width > 340,
  "opaque measurements fall back safely without comparisons or clipping-size reuse")
print("out-of-range-alert-contract: " .. checks .. " checks passed")
