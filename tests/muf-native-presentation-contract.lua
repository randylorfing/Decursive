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
    error(message or "check failed", 2)
  end
end

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local source = Read("ZDecursive/MUFs.lua")
local startAt = assert(source:find("local function BindAuraSlot", 1, true))
local endAt = assert(source:find("local function DistinctFriendlyCures", startAt, true))
local bind = source:sub(startAt, endAt - 1)

for _, token in ipairs({
  "GetRegions",
  "GetChildren",
  "SetIcon",
  "SetDurationCooldown",
  "SetApplicationCount",
  "SetDurationText",
  "SetSpellName",
  "SetDispelTypeText",
  "SetAuraSymbol",
  "SetEnabled",
  ":Hide(",
}) do
  Check(not bind:find(token, 1, true), "MUF presentation must not intercept native AuraSlot state: " .. token)
end

Check(not source:find("SuppressNativeAuraPresentation", 1, true), "native descendants remain untouched")
Check(not source:find("_decursiveHidden", 1, true), "no transparent replacement receiver objects")
Check(not source:find("ConfigureMUFNativePresentation", 1, true), "no public test seam mutates sealed slots")
Check(bind:find("ns.ConfigureMUFDispelPresentation(slot, pack, cover, baseLevel, host, slotInfo)", 1, true), "MUF delegates type and priority metadata to isolated presentation seam")
Check(bind:find('slot:SetTooltipAnchorPoint("ANCHOR_RIGHT", 8, 0)', 1, true), "presented native aura owns the MUF tooltip")
Check(bind:find("slot:SetHideTooltipInCombat(false)", 1, true), "presented aura tooltip remains available in combat")
Check(bind:find("PassClicks(slot, tooltipEnabled)", 1, true), "presented aura delegates native hover and click pass-through to the shared helper")
Check(not bind:find("slot:CreateTexture", 1, true), "MUF binder does not create or inspect native slot regions")

local passStart = assert(source:find("local function PassClicks", 1, true))
local passEnd = assert(source:find("local function ColorOf", passStart, true))
local passClicks = source:sub(passStart, passEnd - 1)
Check(passClicks:find("frame:SetMouseClickEnabled(false)", 1, true), "shared helper prevents native providers from consuming secure clicks")
Check(passClicks:find("frame:SetPropagateMouseClicks(true)", 1, true), "shared helper propagates clicks to the secure MUF")
Check(passClicks:find("frame:EnableMouse(false)", 1, true), "shared helper disables native mouse capture outside lockdown")
Check(passClicks:find("frame:SetMouseMotionEnabled(tooltipEnabled == true)", 1, true), "native hover is independent of clicks")

local presentation = Read("ZDecursive/MUFPresentation.lua")
for _, token in ipairs({
  "GetRegions",
  "GetChildren",
  "SetIcon",
  "SetDurationCooldown",
  "SetApplicationCount",
  "SetDurationText",
  "SetSpellName",
  "SetDispelTypeText",
  "SetAuraSymbol",
  "slot:Hide",
  "slot:SetAlpha",
  "slot:SetParent",
}) do
  Check(not presentation:find(token, 1, true), "presentation seam leaves native receivers untouched: " .. token)
end
Check(presentation:find('host = CreateFrame("Frame", nil, slot)', 1, true), "addon host inherits the native slot visibility gate")
Check(presentation:find("host:SetAllPoints(bounds)", 1, true), "addon host covers the full MUF inner bounds")
Check(presentation:find('host:CreateTexture(nil, "ARTWORK", nil, 7)', 1, true), "only addon child owns fill texture")
Check(presentation:find("pcall(slot.AddDispelTypeTexture, slot, host.texture, options)", 1, true), "C-side dispel binding targets addon texture")
Check(presentation:find("style = style", 1, true), "provider registration explicitly uses PreserveAsset")
Check(presentation:find("styles.PreserveAsset", 1, true), "provider style resolves from the current Retail enum")
Check(presentation:find("pcall(slot.ClearDispelTypeTextures, slot)", 1, true), "owned slot palette refresh uses the supported clear API")
Check(presentation:find("slot._decursivePresentationPaletteSignature ~= paletteSignature", 1, true), "palette refresh is signature-gated")
Check(presentation:find("PRESENTATION.alpha", 1, true), "opaque presentation alpha is centralized")
Check(presentation:find("texture.SetIgnoreParentAlpha", 1, true), "owned provider texture feature-detects parent-alpha isolation")
Check(presentation:find("pcall(texture.SetIgnoreParentAlpha, texture, true)", 1, true), "owned provider texture bypasses ancestor alpha safely")
Check(not presentation:find("owner:SetAlpha", 1, true), "MUF alpha is never changed globally")
Check(not source:find("btn.cooldownHost", 1, true), "removed cooldown host path stays absent")
Check(source:find("holder:SetFrameLevel", 1, true), "native cooldown gates have an explicit frame above fill")
Check(source:find("btn.readabilityHost:SetFrameLevel", 1, true), "raid, text, and status readability layer remains above fill")
Check(presentation:find("fillLevelOffset = 40", 1, true), "affliction frame is above ordinary managed state")
Check(presentation:find("deathLevelOffset = 44", 1, true), "death frame level is centralized above range and Soul Link")
Check(source:find("btn.deathHost:SetFrameLevel", 1, true), "death fill uses an authoritative frame host")
Check(source:find('btn.rangeHost = CreateFrame("Frame", nil, btn.managedHost)', 1, true), "range texture owns an isolated composition host")
Check(source:find("btn.rangeOverlay:SetColorTexture(COLOR_RANGE_OVERLAY[1], COLOR_RANGE_OVERLAY[2], COLOR_RANGE_OVERLAY[3], 1)", 1, true), "range texture initializes with intrinsic alpha one")
Check(source:find('ManagedSet(holder, "SetAlphaFromBoolean", NormalizeBooleanWidgetValue(inRange), 0, 1)', 1, true), "range composition host keeps native opaque visibility gating through the public setter cache")
Check(not source:find("(color[1] or 0) * dimAmount", 1, true), "underlying range color is never dimmed a second time")
Check(presentation:find("pcall(host.SetAlphaFromBoolean, host, inRange, 0, opacity)", 1, true), "whole-MUF shade owns the one range brightness gate")
Check(not source:find("texture:SetAlphaFromBoolean(NormalizeBooleanWidgetValue(inRange)", 1, true), "range texture never receives the dim alpha")
Check(source:find('btn.deadFill = btn.deathHost:CreateTexture(nil, "ARTWORK", nil, 0)', 1, true), "death texture sublevel stays inside the WoW -8..7 contract")
Check(source:find('btn.skullTex = btn.readabilityHost:CreateTexture', 1, true), "death skull remains above cooldown overlays")
Check(source:find("btn.deadFill:SetAllPoints(btn.fillTex)", 1, true), "death fill stays inside the class border")

local options = Read("ZDecursive/Options.lua")
Check(options:find('label = "Dead / ghost / offline", kind = "color", get = PathGet("colors", "dead"), set = PathSet("colors", "dead")', 1, true), "each editing environment exposes a dedicated death color picker")
Check(options:find('label = "Out of range", description = "Underlying RGB color for unafflicted out-of-range squares. Out-of-range brightness dims the whole MUF once, including affliction colors, icons and countdown numbers.", kind = "color", hasOpacity = false', 1, true), "range color picker is RGB-only")

local toc = Read("ZDecursive/ZDecursive.toc")
Check(toc:find("MUFPresentation.lua", 1, true), "presentation seam is in explicit load order")
local packagedVersionToken = "@" .. "project-version" .. "@"
local version = toc:match("## Version: ([^\r\n]+)")
Check(version == packagedVersionToken or (version and version:match("^v%d+%.%d+%.%d+%-Alpha")), "TOC carries the packager token or a rendered alpha version")

local lists = Read("ZDecursive/Lists.lua")
Check(not lists:find("DandersFrames.*SetParent"), "Danders adapter does not reparent frames")

io.write("muf-native-presentation-contract: ok\n")
