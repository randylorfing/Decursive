--[[
    This file is part of Decursive.

    Decursive (v 11.0.10) add-on for World of Warcraft UI
    Copyright (C) 2006-2025 John Wellesz (Decursive AT 2072productions.com) ( http://www.2072productions.com/to/decursive.php )

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive.  If not, see <https://www.gnu.org/licenses/>.

    Decursive is inspired from the original "Decursive v1.9.4" by Patrick Bohnet (Quu).
    The original "Decursive 1.9.4" is in public domain ( www.quutar.com )

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY.

    This file was last updated on 2026-08-22T00:00:00Z
--]]
-------------------------------------------------------------------------------
-- Zhaohu's Decursive - encounter mechanic alerts (interrupts, purges, tank busters)
--
-- Pilot scope: Altar of Fangs only (Database/Encounters/Midnight.lua). This is a
-- second, independent alert path from the friendly-dispel MUF squares: those cover
-- YOUR party's debuffs, this covers ENEMY casts you react to. See EncounterDB_Core.lua.
--
-- Detection is native-first and always-on (UNIT_SPELLCAST_START on boss1-5/target/
-- focus), matching the addon's existing "native provider parity" philosophy: no
-- external addon is required for the core feature. DBM, if installed, is used only
-- as an OPTIONAL supplementary early-warning signal via its public callback API
-- (detection-only, same boundary already held for DandersFrames) -- it never gates
-- or replaces the native path.
--
-- Only verified=true EncounterDB entries alert by default; unverified entries
-- (single-source, not yet spot-checked) are loaded but suppressed so the addon
-- never confidently flags a mechanic it hasn't actually confirmed.
local addonName, T = ...
local D = T and T.Dcr
if type(D) ~= "table" then return end

local PRIORITY_COLOR = {
    critical = { 1.00, .08, .08, 1.00 }, -- matches Dcr_12_1.lua STATUS_FAILED
    high     = { 1.00, .82, 0.00, 1.00 }, -- matches Dcr_12_1.lua STATUS_RANGE
}

local WATCHED_UNITS = { "boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus" }

local function getSpellTexture(spellId)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and tex then return tex end
    end
    if type(GetSpellTexture) == "function" then
        local ok, tex = pcall(GetSpellTexture, spellId)
        if ok then return tex end
    end
    return 134400 -- question-mark icon fallback
end

----------------------------------------------------------------
-- Alert frame
----------------------------------------------------------------

local alertFrame

local function ensureAlertFrame()
    if alertFrame then return alertFrame end

    local f = CreateFrame("Frame", "DecursiveEncounterAlert", UIParent, "BackdropTemplate")
    f:SetSize(280, 54)
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    f:SetFrameStrata("HIGH")
    f:Hide()
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8X8]],
            edgeFile = [[Interface\Buttons\WHITE8X8]],
            edgeSize = 2,
        })
        f:SetBackdropColor(.08, .095, .115, .96) -- matches Modern/ZD_UI.lua panel color
    end

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(38, 38)
    icon:SetPoint("LEFT", f, "LEFT", 8, 0)
    f.Icon = icon

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetJustifyH("LEFT")
    f.Title = title

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWidth(220)
    f.Subtitle = subtitle

    alertFrame = f
    return f
end

local activeCast -- { unit, castID, spellId, expireAt }

local function hideAlert(unit, castID)
    if not alertFrame or not activeCast then return end
    if unit and activeCast.unit ~= unit then return end
    if castID and activeCast.castID and activeCast.castID ~= castID then return end
    activeCast = nil
    alertFrame:Hide()
end

local function announceAlert(entry)
    -- Same text-alert convention as the environment-mode chat messages at
    -- Dcr_12_1.lua:544 (D:Println, gated by EnvironmentChat121Enabled).
    if not D.Println then return end
    if D.profile and D.profile.EnvironmentChat121Enabled == false then return end

    local colorCode = entry.priority == "critical" and "|cFFFF1414" or "|cFFFFD200"
    D:Println(("%sDecursive: %s (%s) -- %s|r"):format(
        colorCode, entry.name or "?", entry.npc or "?", entry.recommendedAction or "Interrupt"))
end

local function showAlert(unit, castID, spellId, entry)
    local f = ensureAlertFrame()
    local color = PRIORITY_COLOR[entry.priority] or PRIORITY_COLOR.high

    if f.SetBackdropBorderColor then
        f:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
    end
    f.Icon:SetTexture(getSpellTexture(spellId))
    f.Title:SetText(entry.name or "")
    f.Title:SetTextColor(color[1], color[2], color[3])
    f.Subtitle:SetText((entry.npc and (entry.npc .. " -- ") or "") .. (entry.recommendedAction or ""))

    activeCast = { unit = unit, castID = castID, spellId = spellId }
    f:Show()
    announceAlert(entry)
end

----------------------------------------------------------------
-- Native detection (always-on, no external addon required)
----------------------------------------------------------------

local function checkUnitCast(unit)
    if not UnitExists(unit) then return end
    local name, _, _, _, _, _, castID, notInterruptible, spellId = UnitCastingInfo(unit)
    if not name or notInterruptible then return end

    local entry = D:GetEncounterDBEntry(spellId)
    if not entry or entry.kind ~= "interrupt" or entry.verified ~= true then return end

    showAlert(unit, castID, spellId, entry)
end

local nativeWatcher = CreateFrame("Frame")
for _, unit in ipairs(WATCHED_UNITS) do
    nativeWatcher:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    nativeWatcher:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    nativeWatcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    nativeWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
end

nativeWatcher:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_SPELLCAST_START" then
        checkUnitCast(unit)
    else
        hideAlert(unit)
    end
end)

----------------------------------------------------------------
-- Optional DBM early-warning bridge (detection-only, never required)
----------------------------------------------------------------

local function tryHookDBM()
    local DBM = _G.DBM
    if type(DBM) ~= "table" or type(DBM.RegisterCallback) ~= "function" then return end
    if D.profile and D.profile.EncounterAlertsDBMBridgeEnabled == false then return end

    DBM:RegisterCallback("DBM_TimerBegin", function(_, _, _, _, _, _, spellId)
        local entry = spellId and D:GetEncounterDBEntry(tonumber(spellId))
        if entry and entry.kind == "interrupt" and entry.verified == true and D.Debug then
            -- Supplementary heads-up only; the native cast-bar alert above remains
            -- authoritative for interrupt timing. Surfaced via Debug for the pilot
            -- rather than a second visual alert, to avoid double-alerting.
            D:Debug(("EncounterDB: DBM flagged upcoming %s (%s)"):format(entry.name, entry.npc))
        end
    end)
end

local dbmHookFrame = CreateFrame("Frame")
dbmHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
dbmHookFrame:SetScript("OnEvent", function(self)
    tryHookDBM()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
