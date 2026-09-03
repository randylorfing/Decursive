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

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local alerts = Read("ZDecursive/Alerts.lua")
local defaults = Read("ZDecursive/Defaults.lua")
local options = Read("ZDecursive/Options.lua")
local mufs = Read("ZDecursive/MUFs.lua")
local data = Read("ZDecursive/DispelData.lua")

Check(alerts:find("Enum.UnitAuraSoundTrigger", 1, true) and alerts:find("e.Added", 1, true), "native sound uses the Added landing edge")
Check(alerts:find("C_UnitAuras.AddAuraSound", 1, true), "native sound uses Blizzard's provider")
Check(alerts:find("C_UnitAuras.RemoveAuraSound", 1, true), "native sound owns explicit registration teardown")
Check(alerts:find("CuratedSpellIds", 1, true), "curated IDs are capability-filtered")
Check(alerts:find('local TYPE_KEY = {MAGIC = "magic", CURSE = "curse", DISEASE = "disease", POISON = "poison"}', 1, true), "sound capability filter is limited to four friendly cure types")
Check(not alerts:find('BLEED = "bleed"', 1, true), "Bleed cannot enter native sound registration")
Check(alerts:find("learnedStoredIgnoredCount", 1, true), "untyped learned IDs are explicitly diagnostics-only")
Check(alerts:find("addon.rosterOrderSignature", 1, true), "sound roster comes from the current committed canonical roster")
Check(alerts:find("partypet", 1, true) and alerts:find("raidpet", 1, true), "committed party and raid pets can receive native sound coverage")
Check(alerts:find("for s = 1, #spellIds do", 1, true), "sound registration uses spell-first fairness")
Check(alerts:find('binding:SetTextFormat("DISPEL", {})', 1, true), "provider text is exact DISPEL")
Check(alerts:find("Enum.DurationTextBindingProperty.ElapsedDuration", 1, true), "timed text uses native elapsed duration")
Check(alerts:find("slot:SetDispelTypeText", 1, true), "until-cleared text uses provider visibility")
Check(alerts:find('text:SetFont(fontPath, size, "THICKOUTLINE")', 1, true), "provider text uses thick outline")
Check(alerts:find("now %- attempt.startedAt > 0.80"), "Soul Link attribution expires at 0.80 seconds")
Check(alerts:find("message == SPELL_FAILED_OUT_OF_RANGE", 1, true), "Soul Link requires a range failure")
Check(alerts:find("+ 2.5", 1, true), "Soul Link warning lasts 2.5 seconds")
Check(not alerts:find('PrintLine("Dispelled', 1, true), "successful dispel text never writes to chat")
Check(alerts:find("pack.alerts.successfulDispelText ~= true", 1, true), "successful dispel text is an explicit opt-in")
Check(alerts:find('textFont:SetText("Dispelled")', 1, true), "successful dispel text has the exact requested content")
Check(mufs:find("ns.ConfigureDispelAlertSlot(slot)", 1, true), "MUF native slots register alert presentation")
Check(mufs:find("ns.BeginSoulLinkAttempt(self.unit)", 1, true), "secure MUF pre-click attributes Soul Link target")
Check(defaults:find("dispelColor = {1, 0.15, 0.15, 1}", 1, true), "alpha red is the default")
Check(defaults:find('alertPoint = {point = "TOP", x = 0, y = -160}', 1, true), "alpha anchor is the default")
Check(alerts:find('alerts.soulLinkAlert ~= false and "RANGE_FAILURE" or "OFF"', 1, true), "diagnostics report the effective Soul Link range-failure toggle")
Check(options:find("VOICE_HELP_CURE_ME", 1, true), "all alpha voice presets are selectable")
for _, token in ipairs({
  '["alerts|Dispel text alert"] = {group = "Text Alerts", simple = true}',
  '["alerts|Soul Link battle-rez warning"] = {group = "Text Alerts", simple = true}',
  '["alerts|Show successful dispel text"] = {group = "Text Alerts", simple = true}',
  '["alerts|Test Text"] = {group = "Text Alerts", simple = true}',
  'alerts = {"Text Alerts", "Sound", "Cooldown", "Chat", "Live list"}',
  "local function EnsureCatalogRenderReachability()",
  "EnsureCatalogRenderReachability()",
}) do
  Check(options:find(token, 1, true), "all text controls are reachable in Simple/full Alerts: " .. token)
end
Check(options:find("opportunity alert, not confirmation of a cure", 1, true), "landing help distinguishes opportunity from success")
Check(options:find("attributed Soul Link attempt fails out of range", 1, true), "Soul Link help distinguishes range failure")
Check(options:find("after ZDecursive confirms a successful cure", 1, true), "success help distinguishes confirmed cure")
Check(data:find("ns.CURATED_DISPEL_ALERTS", 1, true), "curated public data is loaded")
Check(not data:find('cureType = "BLEED"', 1, true), "curated native sound data excludes Bleed")
for _, forbidden in ipairs({"C_UnitAuras.GetAuraData", "GetChildren", "GetRegions", "auraInstanceID"}) do
  Check(not alerts:find(forbidden, 1, true), "alerts avoid forbidden aura access: " .. forbidden)
end

io.write("alerts-alpha-contract: ok\n")
