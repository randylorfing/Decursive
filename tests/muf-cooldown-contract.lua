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
    error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end


local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local ns = {}
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)

local square = ns.CalculateMUFCooldownTextMetrics(16, 16)
Equal(square.fontSize, 14.4, "default inner square uses an exact ninety-percent font height")

for _, row in ipairs({
  {outer = 10, inner = 6, font = 5.4},
  {outer = 20, inner = 16, font = 14.4},
  {outer = 80, inner = 76, font = 68.4},
}) do
  local frameSize, innerSize = ns.GetMUFVisualMetrics(row.outer, true, "party1")
  local metrics = ns.CalculateMUFCooldownTextMetrics(innerSize, innerSize)
  Equal(frameSize, row.outer, "member MUF keeps configured outer size " .. row.outer)
  Equal(innerSize, row.inner, "member MUF calculates bordered inner size " .. row.outer)
  Equal(metrics.fontSize, row.font, "member countdown tracks MUF size " .. row.outer)
end

local forbiddenChild = {path = "Fonts\\ARIALN.TTF", flags = "OUTLINE"}
function forbiddenChild:ClearAllPoints()
  error("forbidden child must never be re-anchored")
end
function forbiddenChild:SetPoint(...)
  self.point = {...}
end
function forbiddenChild:SetJustifyH(value)
  self.justifyH = value
end
function forbiddenChild:SetTextColor(...)
  self.textColor = {...}
end
function forbiddenChild:GetFont()
  return self.path, 9, self.flags
end
function forbiddenChild:SetFontHeight(size)
  self.fontHeight = size
end
function forbiddenChild:SetFont(path, size, flags)
  self.appliedFont = {path, size, flags}
end

local anchor = {}
local applied = ns.ApplyMUFCooldownTextMetrics(forbiddenChild, 16, 16, anchor)
Equal(applied.fontSize, 14.4, "font application uses the pure proportional metric")
Equal(forbiddenChild.point[1], "CENTER", "countdown stays centered")
Equal(forbiddenChild.point[2], anchor, "countdown stays anchored to its native aura slot")
Equal(forbiddenChild.justifyH, "CENTER", "countdown is horizontally centered")
Equal(forbiddenChild.fontHeight, 14.4, "countdown changes only the NumberFont height when supported")

local fallback = {}
for key, value in pairs(forbiddenChild) do
  if key ~= "SetFontHeight" then
    fallback[key] = value
  end
end
fallback.appliedFont = nil
ns.ApplyMUFCooldownTextMetrics(fallback, 20, 20, anchor)
Equal(fallback.appliedFont[1], forbiddenChild.path, "fallback preserves the NumberFont face")
Equal(fallback.appliedFont[2], 18, "fallback applies the exact proportional font height")
Equal(fallback.appliedFont[3], forbiddenChild.flags, "fallback preserves the NumberFont outline")

C_DurationUtil = {
  CreateDurationTextBinding = function()
    return {
      SetFontString = function(self, value) self.fontString = value end,
      SetEnabled = function(self, value) self.enabled = value end,
      SetUpdateInterval = function(self, value) self.interval = value end,
      SetZeroDurationText = function(self, value) self.zeroText = value end,
      SetExpiredText = function(self, value) self.expiredText = value end,
    }
  end,
}

local shade = {}
function shade:SetAllPoints(value) self.anchor = value end
function shade:SetColorTexture(...) self.color = {...} end

local slot = {}
function slot:ClearAllPoints() self.cleared = true end
function slot:SetAllPoints(value) self.anchor = value end
function slot:EnableMouse(value) self.mouse = value end
function slot:SetMouseClickEnabled(value) self.clicks = value end
function slot:SetMouseMotionEnabled(value) self.motion = value end
function slot:CreateTexture() return shade end
function slot:CreateFontString() return forbiddenChild end

local container = {}
function container:AddAuraSlot(_key, _filter, options)
  options.initializeFrame(slot)
  return slot
end

local gate = {container = container, holder = {}, keys = {}, bindings = {}, innerSize = 16}
local pack = {alerts = {cooldownOpacity = 0.62}, colors = {Magic = {1, 0, 0, 1}}}
local action = {types = {"Magic"}, spellId = 115450}
Check(ns.ConfigureMUFCooldownGateSlotForValidation(gate, "cooldown-main", "HARMFUL|RAID_PLAYER_DISPELLABLE", {Magic = true}, pack, action), "alpha-shaped native slot initializer succeeds")
Check(gate.keys["cooldown-main"], "successful native slot is registered")
Equal(forbiddenChild.fontHeight, 14.4, "native child receives its final size during Blizzard initialization")
Equal(#gate.bindings, 1, "native duration binding is retained")

local throwingContainer = {}
function throwingContainer:AddAuraSlot()
  error("forbidden provider")
end
local throwingGate = {container = throwingContainer, holder = {}, keys = {}, bindings = {}, innerSize = 16}
local ok, configured = pcall(ns.ConfigureMUFCooldownGateSlotForValidation, throwingGate, "cooldown-main", "HARMFUL|RAID_PLAYER_DISPELLABLE", {Magic = true}, pack, action)
Check(ok, "provider rejection is contained inside the cooldown feature")
Equal(configured, false, "provider rejection reports a scoped setup failure")

local source = Read("ZDecursive/MUFs.lua")
Check(not source:find("ResizeCooldownTextForButton", 1, true), "forbidden native children are never revisited during MUF relayout")
Check(not source:find("gate.textFrames", 1, true), "native FontStrings are not retained for later addon mutation")
Check(source:find("local addedOK, added = pcall(container.AddAuraSlot", 1, true), "Blizzard provider allocation is a scoped protected call")
Check(source:find("btn.cooldownInnerSize = inner", 1, true), "the current MUF size is captured before native slot allocation")
Check(source:find("visualSignature", 1, true), "MUF visual changes retire and recreate native slots")
Check(source:find("BeginPendingCooldown(attempt.priority, spellId, attempt)", 1, true), "successful spell event passes the exact spell ID into cooldown discovery")
Check(source:find("C_Spell.GetSpellCooldown, spellId", 1, true), "cooldown state comes from the successful spell")
Check(source:find("SetDurationBinding(gate.bindings[i], showNumbers, state and state.durationObject)", 1, true), "native DurationObject reaches the countdown binding unchanged")
Check(not source:find("local COOLDOWN_SECONDS = 8", 1, true), "countdown has no hardcoded Detox duration")
local metricStart = assert(source:find("function ns.ApplyMUFCooldownTextMetrics", 1, true))
local metricEnd = assert(source:find("function ns.GetMUFVisualMetrics", metricStart, true))
local metricSource = source:sub(metricStart, metricEnd - 1)
Check(not metricSource:find("ClearAllPoints", 1, true), "addon never clears points on Blizzard-created cooldown text")
Check(not metricSource:find("GetText", 1, true), "countdown sizing never reads potentially secret duration text")
Check(source:find("ResolveMUFCooldownPresentation(active, btn.skullNativeValue, btn.cooldownSuppressedBySkull)", 1, true), "larger countdown remains under the existing skull suppression gate")
local toc = Read("ZDecursive/ZDecursive.toc")
local packagedVersionToken = "@" .. "project-version" .. "@"
Check(toc:find("## Version: " .. packagedVersionToken, 1, true), "release version remains owned by the packager token")

io.write("muf-cooldown-contract: ok\n")
