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

local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)

local environments = ns.MakeEnvironments()
for _, row in ipairs(ns.ENVIRONMENTS) do
  local expectedEnabled = row.key ~= "PVP"
  Check(environments[row.key].alerts.dispelEnabled == expectedEnabled, row.key .. " has the intended landing DISPEL default")
  Check(environments[row.key].alerts.successfulDispelText == false, row.key .. " defaults success text off")
  Check(environments[row.key].alerts.soulLinkAlert == true, row.key .. " defaults Soul Link warning on")
  Check(environments[row.key].alerts.sound == expectedEnabled, row.key .. " has the intended sound default")
end

local independent = ns.MakeEnvironments()
independent.OPEN_WORLD.alerts.dispelEnabled = false
independent.DUNGEON.alerts.soulLinkAlert = false
independent.MYTHIC_PLUS.alerts.successfulDispelText = true
independent.RAID.alerts.sound = false
Check(independent.OPEN_WORLD.alerts.soulLinkAlert == true and independent.OPEN_WORLD.alerts.successfulDispelText == false and independent.OPEN_WORLD.alerts.sound == true, "landing toggle does not alter Soul Link, success, or sound")
Check(independent.DUNGEON.alerts.dispelEnabled == true and independent.DUNGEON.alerts.successfulDispelText == false and independent.DUNGEON.alerts.sound == true, "Soul Link toggle does not alter landing, success, or sound")
Check(independent.MYTHIC_PLUS.alerts.dispelEnabled == true and independent.MYTHIC_PLUS.alerts.soulLinkAlert == true and independent.MYTHIC_PLUS.alerts.sound == true, "success toggle does not alter landing, Soul Link, or sound")
Check(independent.RAID.alerts.dispelEnabled == true and independent.RAID.alerts.soulLinkAlert == true and independent.RAID.alerts.successfulDispelText == false, "sound toggle does not alter any text control")
Check(independent.PVP.alerts.dispelEnabled == false and independent.PVP.alerts.soulLinkAlert == true and independent.PVP.alerts.successfulDispelText == false and independent.PVP.alerts.sound == false, "PvP defaults only landing DISPEL and sound off")
Check(independent.SOLO.alerts.dispelEnabled == true and independent.SOLO.alerts.soulLinkAlert == true and independent.SOLO.alerts.successfulDispelText == false, "Solo retains independent text-control defaults")

local now = 1
local shown = 0
local hidden = 0
local displayedText
local displayedColor
local displayedFont
local frameTypes = {}
local scripts = {}
local eventScript
local chatLines = 0
local appliedEnvironment = "OPEN_WORLD"
local secretUnit = {}
local secretReads = 0

UIParent = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameFontNormalHuge = {
  GetFont = function()
    return STANDARD_TEXT_FONT
  end,
}
GameFontHighlightSmall = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function()
    chatLines = chatLines + 1
  end,
}

GetTime = function()
  return now
end
InCombatLockdown = function()
  return true
end
SPELL_FAILED_OUT_OF_RANGE = "Out of range"
ERR_OUT_OF_RANGE = "Out of range"
UnitName = function(unit)
  if unit == secretUnit then
    error("secret unit was read")
  end
  return unit == "party1" and "Friend" or nil
end

CreateFrame = function(frameType)
  frameTypes[#frameTypes + 1] = frameType
  local frame = {}
  function frame:SetSize() end
  function frame:SetPoint() end
  function frame:ClearAllPoints() end
  function frame:SetFrameStrata() end
  function frame:SetMovable() end
  function frame:EnableMouse() end
  function frame:RegisterForDrag() end
  function frame:SetFontObject() end
  function frame:SetJustifyH() end
  function frame:SetFading() end
  function frame:SetMaxLines() end
  function frame:SetInsertMode() end
  function frame:AddMessage()
    chatLines = chatLines + 1
  end
  function frame:GetPoint()
    return "TOP", UIParent, "TOP", 0, -160
  end
  function frame:SetScript(name, callback)
    scripts[name] = callback
    if name == "OnEvent" then
      eventScript = callback
    end
  end
  function frame:RegisterEvent() end
  function frame:Hide()
    hidden = hidden + 1
  end
  function frame:Show()
    shown = shown + 1
  end
  function frame:CreateFontString()
    local font = {}
    function font:SetAllPoints() end
    function font:SetPoint() end
    function font:SetJustifyH() end
    function font:SetIgnoreParentScale() end
    function font:SetAlpha() end
    function font:SetFont(path, size, outline)
      displayedFont = {path, size, outline}
    end
    function font:SetTextColor(red, green, blue, alpha)
      displayedColor = {red, green, blue, alpha}
    end
    function font:SetText(text)
      displayedText = text
    end
    return font
  end
  return frame
end

ns.IsAccessible = function(value)
  return value ~= secretUnit
end
ns.PublicValue = function(value)
  if value == secretUnit then
    secretReads = secretReads + 1
    return nil
  end
  return value
end
ns.addon = {
  GetAppliedEnvironmentPack = function()
    return environments[appliedEnvironment]
  end,
}

assert(loadfile("ZDecursive/Alerts.lua"))("ZDecursive", ns)

Check(ns.NotifyCureSucceeded("party1") == false, "default-off success is silent")
Check(shown == 0 and chatLines == 0, "default-off success has no UI or chat side effect")

environments.RAID.alerts.successfulDispelText = true
Check(ns.NotifyCureSucceeded("party1") == false, "editing environment does not drive runtime alerts")
Check(shown == 0, "non-applied environment stays silent")

appliedEnvironment = "RAID"
environments.RAID.alerts.dispelEnabled = false
environments.RAID.alerts.text = false
environments.RAID.alerts.soulLinkAlert = false
Check(ns.NotifyCureSucceeded(secretUnit) == true, "applied environment opt-in displays in combat-safe secret context")
Check(secretReads == 0, "successful cure never reads the secret unit payload")
Check(shown == 1, "successful cure shows exactly once")
Check(displayedText == "Dispelled", "successful cure uses exact text")
Check(displayedFont[2] == 48 and displayedFont[3] == "THICKOUTLINE", "successful cure uses configured alpha font")
Check(displayedColor[1] == 1 and displayedColor[2] == 0.15 and displayedColor[3] == 0.15, "successful cure uses configured alert color")
Check(chatLines == 0, "successful cure never writes to chat")

now = 1.1
Check(ns.NotifyCureSucceeded("party2") == false and shown == 1, "repeat success is throttled")
now = 1.21
Check(ns.NotifyCureSucceeded("party2") == true and shown == 2, "success retriggers after throttle")

environments.RAID.alerts.successfulDispelText = nil
now = 2
Check(ns.NotifyCureSucceeded("party2") == false and shown == 2, "legacy nil remains off")

local copied = ns.DeepCopy(environments.OPEN_WORLD)
copied.alerts.successfulDispelText = true
Check(copied.alerts.successfulDispelText == true and environments.OPEN_WORLD.alerts.successfulDispelText == false, "environment copy preserves independent value")
copied.alerts.dispelEnabled = false
copied.alerts.soulLinkAlert = false
Check(environments.OPEN_WORLD.alerts.dispelEnabled == true and environments.OPEN_WORLD.alerts.soulLinkAlert == true, "copied text toggles do not mutate source environment")
local resetPack = ns.MakePack("RAID")
Check(resetPack.alerts.dispelEnabled == true and resetPack.alerts.soulLinkAlert == true and resetPack.alerts.successfulDispelText == false, "environment reset restores all three text defaults")
local resetPvPPack = ns.MakePack("PVP")
Check(resetPvPPack.alerts.dispelEnabled == false and resetPvPPack.alerts.sound == false and resetPvPPack.alerts.soulLinkAlert == true and resetPvPPack.alerts.successfulDispelText == false, "PvP reset keeps landing DISPEL and sound quiet without changing the other text defaults")
local newProfile = ns.MakeEnvironments()
Check(newProfile.PVP.alerts.dispelEnabled == false and newProfile.PVP.alerts.sound == false and newProfile.PVP.alerts.soulLinkAlert == true and newProfile.PVP.alerts.successfulDispelText == false, "new profile environments use quiet PvP landing defaults")
Check(newProfile.SOLO.alerts.dispelEnabled == true and newProfile.SOLO.alerts.soulLinkAlert == true and newProfile.SOLO.alerts.successfulDispelText == false, "new Solo pack restores all three text defaults")

Check(type(scripts.OnUpdate) == "function", "success frame retains timed clear lifecycle")
now = 40
scripts.OnUpdate({Hide = function()
  hidden = hidden + 1
end})
Check(hidden >= 2, "success text clears after its configured duration")

for _, frameType in ipairs(frameTypes) do
  Check(frameType ~= "ScrollingMessageFrame", "success path does not create a chat-style message frame")
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local alertsSource = Read("ZDecursive/Alerts.lua")
local mufsSource = Read("ZDecursive/MUFs.lua")
local successStart = assert(alertsSource:find("function ns.NotifyCureSucceeded", 1, true))
local successEnd = assert(alertsSource:find("local function ShowSoulLinkWarning", successStart, true))
local successBody = alertsSource:sub(successStart, successEnd - 1)
Check(not successBody:find("PrintLine", 1, true), "success callback has no chat route")
Check(mufsSource:find('event == "UNIT_SPELLCAST_SUCCEEDED"', 1, true), "only confirmed cast success invokes the success route")
Check(not mufsSource:find('event == "UNIT_SPELLCAST_FAILED".-NotifyCureSucceeded'), "failure never invokes success text")
local landingStart = assert(alertsSource:find("function ns.ConfigureDispelAlertSlot", 1, true))
local landingEnd = assert(alertsSource:find("function ns.PlayCureFailureSound", landingStart, true))
Check(not alertsSource:sub(landingStart, landingEnd - 1):find("NotifyCureSucceeded", 1, true), "landing and aura removal never invoke success text")

-- Landing opportunity remains provider-bound and independent from success/Soul Link/sound.
local persistentAlpha
local persistentMap
local landingSlot = {}
function landingSlot:CreateFontString()
  local font = {}
  function font:SetPoint() end
  function font:SetFont() end
  function font:SetTextColor() end
  function font:SetAlpha(value)
    persistentAlpha = value
  end
  return font
end
function landingSlot:SetDispelTypeText(_font, options)
  persistentMap = options.customDispelTextMap
end
environments.RAID.alerts.dispelEnabled = true
environments.RAID.alerts.dispelMode = "UNTIL_CLEARED"
environments.RAID.alerts.text = true
environments.RAID.alerts.successfulDispelText = false
environments.RAID.alerts.soulLinkAlert = false
environments.RAID.alerts.sound = false
ns.ConfigureDispelAlertSlot(landingSlot)
Check(persistentAlpha == 1, "landing DISPEL is visible when its independent toggle is on")
Check(persistentMap.Magic == "DISPEL" and persistentMap.Curse == "DISPEL" and persistentMap.Poison == "DISPEL" and persistentMap.Disease == "DISPEL", "landing provider uses exact DISPEL text")
environments.RAID.alerts.dispelEnabled = false
ns.RefreshAlerts()
Check(persistentAlpha == 0, "landing DISPEL hides when only its own toggle is off")

-- Soul Link warning requires the attributed out-of-range edge and its independent toggle.
local consumer
ns.DetectionEngine = {
  RegisterConsumer = function(_, _name, callback)
    consumer = callback
  end,
}
ns.GetSoulLinkState = function()
  return {enabled = true}
end
environments.RAID.alerts.chat = false
environments.RAID.alerts.soulLinkAlert = true
environments.RAID.alerts.successfulDispelText = false
environments.RAID.alerts.dispelEnabled = false
environments.RAID.alerts.sound = false
ns.EnableAlerts(ns.addon)
Check(type(eventScript) == "function" and type(consumer) == "function", "Soul Link event and applied-profile refresh lifecycle are registered")
local shownBeforeSoulLink = shown
now = 50
Check(ns.BeginSoulLinkAttempt("party1") == true, "public MUF pre-click starts Soul Link attribution")
eventScript(nil, "UI_ERROR_MESSAGE", 0, SPELL_FAILED_OUT_OF_RANGE)
Check(shown == shownBeforeSoulLink + 1, "in-window out-of-range Soul Link failure shows warning")
Check(displayedText == "Battle rez: move within range of Friend!", "Soul Link warning has exact attributed text")
Check(chatLines == 0, "Soul Link respects disabled chat and exposes no payload there")

shownBeforeSoulLink = shown
now = 51
ns.BeginSoulLinkAttempt("party1")
now = 51.81
eventScript(nil, "UI_ERROR_MESSAGE", 0, SPELL_FAILED_OUT_OF_RANGE)
Check(shown == shownBeforeSoulLink, "out-of-window Soul Link failure is silent")

environments.RAID.alerts.soulLinkAlert = false
now = 52
ns.BeginSoulLinkAttempt("party1")
eventScript(nil, "UI_ERROR_MESSAGE", 0, SPELL_FAILED_OUT_OF_RANGE)
Check(shown == shownBeforeSoulLink, "Soul Link warning obeys only its own disabled toggle")
Check(ns.BeginSoulLinkAttempt(secretUnit) == false, "secret Soul Link unit is rejected without inspection")

io.write("successful-dispel-text-contract: ok\n")
