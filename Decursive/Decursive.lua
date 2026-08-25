--[[
    This file is part of Decursive.

    Decursive (v 11.0.10) add-on for World of Warcraft UI
    Copyright (C) 2006-2026 John Wellesz (Decursive AT 2072productions.com) ( http://www.2072productions.com/to/decursive.php )
    WoW 12.1 compatibility and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

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

    This file was last updated on 2026-08-17T20:37:56Z
--]]
-------------------------------------------------------------------------------

local addonName, T = ...;
-- big ugly scary fatal error message display function {{{
if not T._FatalError then
-- the beautiful error popup : {{{ -
StaticPopupDialogs["DECURSIVE_ERROR_FRAME"] = {
    text = "|cFFFF0000Decursive Error:|r\n%s",
    button1 = "OK",
    OnAccept = function()
        return false;
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
    preferredIndex = 3,
    }; -- }}}
T._FatalError = function (TheError) T._StaticPopupDialogsWasShown = true; StaticPopup_Show ("DECURSIVE_ERROR_FRAME", TheError); end
end
-- }}}
if not T._LoadedFiles or not T._LoadedFiles["Dcr_Raid.lua"] then
    if not DecursiveInstallCorrupted then T._FatalError("Decursive installation is corrupted! (Dcr_Raid.lua not loaded)"); end;
    DecursiveInstallCorrupted = true;
    return;
end
T._LoadedFiles["Decursive.lua"] = false;

local D = T.Dcr;

local L = D.L;
local LC = D.LC;
local DC = T._C;
-------------------------------------------------------------------------------

local _G                = _G;
local pairs             = _G.pairs;
local ipairs            = _G.ipairs;
local type              = _G.type;
local table             = _G.table;
local t_sort            = _G.table.sort;
local t_wipe            = _G.table.wipe;
local UnitName          = _G.UnitName;
local UnitDebuff        = _G.UnitDebuff;
local UnitBuff          = _G.UnitBuff;
local UnitIsCharmed     = _G.UnitIsCharmed;
local UnitCanAttack     = _G.UnitCanAttack;
local UnitClass         = _G.UnitClass;
local UnitExists        = _G.UnitExists;
local GetNetStats       = _G.GetNetStats;
local canaccessvalue    = _G.canaccessvalue or function(_) return true; end
local _;

-------------------------------------------------------------------------------
-- The UI functions {{{
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- The printing functions {{{
-------------------------------------------------------------------------------

function D:Show_Cure_Order() --{{{
    self:Println("printing cure order:");
    for index, unit in ipairs(self.Status.Unit_Array) do
        self:Println( unit, " - ", self:MakePlayerName((self:UnitName(unit))) , " Index: ", index);
    end
end --}}}

-- }}}
-------------------------------------------------------------------------------

-- Show Hide FUNCTIONS -- {{{

function D:ShowHideLiveList(hide) --{{{

    if not D.DcrFullyInitialized then
        return;
    end

    -- if hide is requested or if hide is not set and the live-list is shown
    if (hide==1 or (not hide and DcrLiveList:IsVisible())) then
        D.profile.HideLiveList = true;
        DcrLiveList:Hide();
        D:CancelDelayedCall("Dcr_LLupdate");
    else
        D.profile.HideLiveList = false;
        DcrLiveList:ClearAllPoints();
        DcrLiveList:SetPoint("TOPLEFT", "DecursiveMainBar", "BOTTOMLEFT");
        DcrLiveList:Show();

        D:ScheduleRepeatedCall("Dcr_LLupdate", D.LiveList.Update_Display, D.profile.ScanTime, D.LiveList);
    end

end --}}}

-- This functions hides or shows the "Decursive" bar depending on its current
-- state, it's also able hide/show the live-list if the "tie live-list" option is active
function D:HideBar(hide) --{{{

    if not D.DcrFullyInitialized then
        return;
    end

    if (hide==1 or (not hide and DecursiveMainBar:IsVisible())) then
        if (D.profile.LiveListTied) then
            D:ShowHideLiveList(1);
        end
        D.profile.BarHidden = true;
        DecursiveMainBar:Hide();
    else
        if (D.profile.LiveListTied) then
            D:ShowHideLiveList(0);
        end
        D.profile.BarHidden = false;
        DecursiveMainBar:Show();
    end

    if DecursiveMainBar:IsVisible() and DcrLiveList:IsVisible() then
        DcrLiveList:ClearAllPoints();
        DcrLiveList:SetPoint("TOPLEFT", "DecursiveMainBar", "BOTTOMLEFT");
    else
        D:ColorPrint(0.3, 0.5, 1, L["SHOW_MSG"]);
    end

    D:NotifyConfigurationChanged();
end --}}}

function D:ShowHidePriorityListUI() --{{{

    if not D.DcrFullyInitialized then
        return;
    end

    if (DecursivePriorityListFrame:IsVisible()) then
        DecursivePriorityListFrame:Hide();
    else
        DecursivePriorityListFrame:Show();
    end
end --}}}

function D:ShowHideSkipListUI() --{{{

    if not D.DcrFullyInitialized then
        return;
    end

    if (DecursiveSkipListFrame:IsVisible()) then
        DecursiveSkipListFrame:Hide();
    else
        DecursiveSkipListFrame:Show();
    end
end --}}}

-- This shows/hides the buttons near the "Decursive" bar
function D:ShowHideButtons(UseCurrentValue) --{{{

    if not D.DcrFullyInitialized then
        return;
    end

    if not D.profile then
        return;
    end


    local DcrFrame = "DecursiveMainBar";
    local buttons = {
        DcrFrame .. "Priority",
        DcrFrame .. "Skip",
        DcrFrame .. "Hide",
    }

    local DCRframeObject = _G[DcrFrame];

    if (not UseCurrentValue) then
        D.profile.HideButtons = (not D.profile.HideButtons);
    end

    for _, ButtonName in pairs(buttons) do
        local Button = _G[ButtonName];

        if (D.profile.HideButtons) then
            Button:Hide();
            DCRframeObject.isLocked = 1;
        else
            Button:Show();
            DCRframeObject.isLocked = 0;
        end

    end

end --}}}

-- }}}


-- this resets the location of the windows
function D:ResetWindow() --{{{

    DecursiveMainBar:ClearAllPoints();
    DecursiveMainBar:SetPoint("CENTER", UIParent);
    DecursiveMainBar:Show();

    DcrLiveList:ClearAllPoints();
    DcrLiveList:SetPoint("TOPLEFT", DecursiveMainBar, "BOTTOMLEFT");
    DcrLiveList:Show();

    DecursivePriorityListFrame:ClearAllPoints();
    DecursivePriorityListFrame:SetPoint("CENTER", UIParent);

    DecursiveSkipListFrame:ClearAllPoints();
    DecursiveSkipListFrame:SetPoint("CENTER", UIParent);

    DecursivePopulateListFrame:ClearAllPoints();
    DecursivePopulateListFrame:SetPoint("CENTER", UIParent);

    D.MFContainer:ClearAllPoints();
    D.MFContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0);

    DecursiveAnchor:ClearAllPoints();
    DecursiveAnchor:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, 0);

end --}}}


local SOUND_NOTIFICATION_FILES = {
    AFFLICTION = DC.AfflictionSound,
    QUICK = T._AddonPath .. "Sounds\\G_NecropolisWound-fast.ogg",
    FAILURE = DC.FailedSound,

    -- v11.0.7 additional short combat tones.
    BRIGHT_PING = T._AddonPath .. "Sounds\\BrightPing.ogg",
    DOUBLE_PING = T._AddonPath .. "Sounds\\DoublePing.ogg",
    TRIPLE_PING = T._AddonPath .. "Sounds\\TriplePing.ogg",
    HIGH_CHIME = T._AddonPath .. "Sounds\\HighChime.ogg",
    LOW_CHIME = T._AddonPath .. "Sounds\\LowChime.ogg",
    PULSE_UP = T._AddonPath .. "Sounds\\PulseUp.ogg",
    PULSE_DOWN = T._AddonPath .. "Sounds\\PulseDown.ogg",

    -- Original synthesized voice callouts. These are deliberately short so
    -- they remain useful during combat and all pass through the same shared
    -- dispel-alert debounce gate.
    VOICE_DISPEL = T._AddonPath .. "Sounds\\VoiceDispel.ogg",
    VOICE_CLEANSE = T._AddonPath .. "Sounds\\VoiceCleanse.ogg",
    VOICE_CURE = T._AddonPath .. "Sounds\\VoiceCure.ogg",
    VOICE_HELP = T._AddonPath .. "Sounds\\VoiceHelp.ogg",
    VOICE_CLEANSE_ME = T._AddonPath .. "Sounds\\VoiceCleanseMe.ogg",
    VOICE_CURE_ME = T._AddonPath .. "Sounds\\VoiceCureMe.ogg",
    VOICE_HELP_CLEANSE_ME = T._AddonPath .. "Sounds\\VoiceHelpCleanseMe.ogg",
    VOICE_HELP_CURE_ME = T._AddonPath .. "Sounds\\VoiceHelpCureMe.ogg",

    -- v11.0.10 user-provided natural female voice callouts.
    FEMALE_DISPEL = T._AddonPath .. "Sounds\\FemaleDispel.ogg",
    FEMALE_DISPEL_ME = T._AddonPath .. "Sounds\\FemaleDispelMe.ogg",
    FEMALE_CLEANSE = T._AddonPath .. "Sounds\\FemaleCleanse.ogg",
    FEMALE_CLEANSE_ME = T._AddonPath .. "Sounds\\FemaleCleanseMe.ogg",
};

function D:GetDispelNotificationSoundFile()
    local preset = self.profile and self.profile.SoundNotificationPreset or "FEMALE_DISPEL";
    return SOUND_NOTIFICATION_FILES[preset] or (self.profile and self.profile.SoundFile) or DC.AfflictionSound;
end

function D:GetSoundNotificationChannel()
    local channel = self.profile and self.profile.SoundNotificationChannel or "Master";
    if channel ~= "Master" and channel ~= "SFX" and channel ~= "Dialog" and channel ~= "Ambience" and channel ~= "Music" then
        channel = "Master";
    end
    return channel;
end

-- Play one Decursive-owned dispel alert through one deterministic, group-wide
-- debounce gate. The first accepted alert opens a lockout window; every later
-- request during that window is discarded. Test sounds can bypass the lockout
-- without changing its timer.
function D:PlayDispelNotificationSound(reason, bypassIgnoreWindow)
    if not self.profile or not self.profile.PlaySound then return false; end

    local now = _G.GetTime();
    local ignoreSeconds = tonumber(self.profile.SoundNotificationIgnoreSeconds) or 2.0;
    if ignoreSeconds < 0 then ignoreSeconds = 0; end
    if ignoreSeconds > 10 then ignoreSeconds = 10; end

    local ignoreUntil = tonumber(T._DispelNotificationIgnoreUntil) or 0;
    if not bypassIgnoreWindow and now < ignoreUntil then
        if self.debug then
            self:Debug("Sound notification suppressed by burst window:", reason, ("%.2fs remaining"):format(ignoreUntil - now));
        end
        return false;
    end

    if not bypassIgnoreWindow then
        T._DispelNotificationIgnoreUntil = now + ignoreSeconds;
    end

    self:SafePlaySoundFile(self:GetDispelNotificationSoundFile(), self:GetSoundNotificationChannel());
    -- Live DISPEL banner is parented to AuraSlots (Show/Hide cascade). This
    -- only bumps the timed Alert warning when Decursive itself plays the sound
    -- (legacy / test / fallback paths).
    if self.Show121DispelAlertWarning and (not self.profile or self.profile.Alert121DispelEnabled ~= false) then
        self:Show121DispelAlertWarning(reason or "dispel sound", true);
    end
    if self.debug then
        self:Debug("Dispel sound scheduled by", reason or "unknown", "ignore window:", ignoreSeconds);
    end
    return true;
end

-- True when spellID is a public, actionable friendly dispel alert we already
-- register with Blizzard's AddAuraSound engine (DispelDB and/or learned IDs).
local function isPublicDispelAlertSpellID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false end
    if not canaccessvalue(spellID) then return false end
    if _G.issecretvalue and _G.issecretvalue(spellID) then return false end
    if D.IsLearnedProtectedAuraSoundSpellID and D:IsLearnedProtectedAuraSoundSpellID(spellID) then
        return true
    end
    if type(D.GetDispelDBEntry) == "function" then
        local entry = D:GetDispelDBEntry(spellID)
        if entry and entry.target == "friendly" and entry.alert ~= false then
            local key = entry.cureType
            local dcType = key and DC and DC[key]
            if dcType and D.Status and type(D.Status.CuringSpells) == "table" and D.Status.CuringSpells[dcType] then
                return true
            end
        end
    end
    return false
end

-- When Blizzard's AddAuraSound plays the auto notification, there is no Lua
-- callback. For public combat-log spell IDs that match our registered set,
-- show the DISPEL Alert warning on the same burst window — still no secret
-- aura reads.
function D:NotifyDispelAlertFromPublicAura(spellID, reason)
    if not self.profile or not self.profile.PlaySound or self.profile.SoundProtectedAuraAlerts == false then
        return false
    end
    if not isPublicDispelAlertSpellID(spellID) then return false end

    if self.IsProtectedAuraSoundEngineAvailable and self:IsProtectedAuraSoundEngineAvailable() then
        -- Audio is owned by AddAuraSound; text only here.
        if self.Show121DispelAlertWarning then
            return self:Show121DispelAlertWarning(reason or ("public aura " .. tostring(spellID)), false)
        end
        return false
    end

    -- Fallback when AddAuraSound is unavailable: sound + DISPEL banner together.
    if self.PlayDispelNotificationSound then
        return self:PlayDispelNotificationSound(reason or ("public aura " .. tostring(spellID)), false)
    end
    return false
end

function D:PlayFailureNotificationSound()
    if not self.profile or not self.profile.PlaySound or self.profile.PlayFailureSound == false then return false; end
    self:SafePlaySoundFile(DC.FailedSound, self:GetSoundNotificationChannel());
    return true;
end

function D:PlaySound (UnitID, Caller) --{{{
    if self.profile.PlaySound and not self.Status.SoundPlayed then
        local Debuffs, IsCharmed = self:UnitCurableDebuffs(UnitID, true);
        if Debuffs[1] or IsCharmed then
            -- Set the one-shot state even if the short burst window suppresses
            -- this particular call; we do not want a delayed machine-gun alert.
            self:PlayDispelNotificationSound(Caller or "legacy curable scan", false);
            self.Status.SoundPlayed = true;
        end
    end
end --}}}

-- ---------------------------------------------------------------------------
-- WoW 12.1 legacy learned protected-aura sound fallback
-- ---------------------------------------------------------------------------
-- AuraContainer/AuraButton visibility is protected and cannot be queried by
-- addon Lua. Blizzard's C_UnitAuras.AddAuraSound API can play a sound for a
-- protected aura, but it plays directly inside Blizzard and provides no callback
-- through which Decursive can apply a group-wide 2-second debounce.
--
-- Retained only as a fallback when the v11.0.10 MUF-state ID filter API is unavailable:
--   1. Learn a public aura spell ID from the player's successful SPELL_DISPEL.
--   2. On a future public SPELL_AURA_APPLIED combat-log event for that learned ID,
--      route the alert through PlayDispelNotificationSound().
--   3. The first group member opens the configured lockout window; simultaneous
--      applications to other group members are suppressed.
--
-- If Blizzard makes the combat-log spell ID secret/unavailable, Decursive does
-- not play an unthrottled fallback sound. Visual protected detection remains
-- authoritative in that case.

local function getProtectedAuraSoundContextKey()
    local classToken = select(2, _G.UnitClass("player")) or "UNKNOWN";
    local specID = 0;
    if _G.GetSpecialization and _G.GetSpecializationInfo then
        local specIndex = _G.GetSpecialization();
        if specIndex then
            local id = _G.GetSpecializationInfo(specIndex);
            if type(id) == "number" and canaccessvalue(id) then
                specID = id;
            end
        end
    end
    return classToken .. ":" .. tostring(specID);
end

-- Local per-expansion dispel database. Friendly harmful entries are eligible for
-- protected aura sounds; hostile purge entries remain in the DB but are not
-- registered against party/raid units.
local function builtinCureTypeEnabled(entry)
    if type(entry) ~= "table" then return false end
    if entry.target == "enemy" or entry.alert == false then return false end
    local key = entry.cureType
    local dcType = key and DC and DC[key]
    if not dcType then return false end
    if not D.Status or type(D.Status.CuringSpells) ~= "table" or not D.Status.CuringSpells[dcType] then
        return false
    end
    if type(D.GetCureOrderTable) == "function" then
        local order = D:GetCureOrderTable()
        if type(order) == "table" and not order[dcType] then return false end
    end
    return true
end

local function getBuiltInProtectedAuraSoundEntries()
    local out = {}
    local db = D.DispelDB and D.DispelDB.expansions
    if type(db) ~= "table" then return out end
    for expansion, bucket in pairs(db) do
        local entries = bucket and bucket.entries
        if type(entries) == "table" then
            for i = 1, #entries do
                local e = entries[i]
                if builtinCureTypeEnabled(e) then out[#out + 1] = e end
            end
        end
    end
    table.sort(out, function(a,b) return (a.id or 0) < (b.id or 0) end)
    return out
end

local function getBuiltInProtectedAuraSoundIDs()
    local out, seen = {}, {}
    local entries = getBuiltInProtectedAuraSoundEntries()
    for i = 1, #entries do
        local id = entries[i].id
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

local function getProtectedAuraSoundIDs()
    if not D.db or not D.db.global then return nil; end

    if type(D.db.global.SoundProtectedAuraSpellIDsBySpec) ~= "table" then
        D.db.global.SoundProtectedAuraSpellIDsBySpec = {};
    end

    local key = getProtectedAuraSoundContextKey();
    local ids = D.db.global.SoundProtectedAuraSpellIDsBySpec[key];
    if type(ids) ~= "table" then
        ids = {};
        D.db.global.SoundProtectedAuraSpellIDsBySpec[key] = ids;
    end

    if type(D.db.global.SoundProtectedAuraSpellIDs) == "table" and #D.db.global.SoundProtectedAuraSpellIDs > 0 then
        local seen = {};
        for i = 1, #ids do seen[ids[i]] = true; end
        for i = 1, #D.db.global.SoundProtectedAuraSpellIDs do
            local spellID = D.db.global.SoundProtectedAuraSpellIDs[i];
            if type(spellID) == "number" and spellID > 0 and not seen[spellID] then
                ids[#ids + 1] = spellID;
                seen[spellID] = true;
            end
        end
        D.db.global.SoundProtectedAuraSpellIDs = nil;
    end

    while #ids > 32 do table.remove(ids, 1); end
    return ids, key;
end

function D:GetProtectedAuraSoundContextKey()
    return getProtectedAuraSoundContextKey();
end

function D:GetProtectedAuraSoundIDs()
    return getProtectedAuraSoundIDs();
end

function D:IsLearnedProtectedAuraSoundSpellID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false; end
    if _G.issecretvalue and _G.issecretvalue(spellID) then return false; end
    if not canaccessvalue(spellID) then return false; end

    local ids = getProtectedAuraSoundIDs();
    if not ids then return false; end
    for i = 1, #ids do
        if ids[i] == spellID then return true; end
    end
    return false;
end

function D:LearnProtectedAuraSoundSpellID(spellID, source)
    if not self.profile or (self.profile.SoundProtectedAuraAutoLearn == false and source ~= "manual") then return false; end
    if type(spellID) ~= "number" or spellID <= 0 then return false; end
    if _G.issecretvalue and _G.issecretvalue(spellID) then return false; end
    if not canaccessvalue(spellID) then return false; end

    local ids, contextKey = getProtectedAuraSoundIDs();
    if not ids then return false; end
    for i = 1, #ids do
        if ids[i] == spellID then return false; end
    end

    ids[#ids + 1] = spellID;
    while #ids > 32 do table.remove(ids, 1); end

    local spellName;
    if _G.C_Spell and type(_G.C_Spell.GetSpellName) == "function" then
        local ok, value = pcall(_G.C_Spell.GetSpellName, spellID);
        if ok and value and canaccessvalue(value) then spellName = value; end
    end
    T._AuraSoundDiag = T._AuraSoundDiag or {};
    T._AuraSoundDiag.lastLearned = spellID;
    T._AuraSoundDiag.lastLearnedName = spellName;
    self:Println(("Sound Notifications: learned dispellable aura %s (%d) for %s. Blizzard aura-sound registration refreshed."):format(spellName or "spell", spellID, contextKey or "current spec"));
    if type(self.RefreshProtectedAuraSounds) == "function" then
        self:RefreshProtectedAuraSounds("learned spell " .. tostring(spellID));
    end
    return true;
end

-- ---------------------------------------------------------------------------
-- WoW 12.1 Blizzard-native protected aura sound registry
-- ---------------------------------------------------------------------------
-- C_UnitAuras.AddAuraSound(trigger, info) lets Blizzard play an addon-provided
-- sound when a known spell ID is applied to a unit token, including while aura
-- details are protected. This mirrors the architecture used by modern boss
-- mods: register public spell identities up front and let Blizzard own the
-- protected detection/playback path.
local NativeAuraSoundHandles = {};
T._AuraSoundDiag = T._AuraSoundDiag or { registered = 0, attempted = 0, lastReason = "never", lastError = nil, lastLearned = nil };

function D:IsProtectedAuraSoundEngineAvailable()
    return _G.C_UnitAuras
        and type(_G.C_UnitAuras.AddAuraSound) == "function"
        and type(_G.C_UnitAuras.RemoveAuraSound) == "function";
end

function D:ClearProtectedAuraSounds()
    if self:IsProtectedAuraSoundEngineAvailable() then
        for i = 1, #NativeAuraSoundHandles do
            local handle = NativeAuraSoundHandles[i];
            if type(handle) == "number" and canaccessvalue(handle) then
                pcall(_G.C_UnitAuras.RemoveAuraSound, handle);
            end
        end
    end
    for i = #NativeAuraSoundHandles, 1, -1 do NativeAuraSoundHandles[i] = nil; end
end

local function addUniqueUnitToken(out, seen, unit)
    if type(unit) ~= "string" or seen[unit] then return; end
    -- UnitExists is intentionally only a roster/token check here. No aura data
    -- is inspected. PLAYER is useful even when solo.
    if unit == "player" or not _G.UnitExists or _G.UnitExists(unit) then
        seen[unit] = true;
        out[#out + 1] = unit;
    end
end

function D:GetProtectedAuraSoundUnitTokens()
    local units, seen = {}, {};
    addUniqueUnitToken(units, seen, "player");

    local assigned = self.Status and self.Status.Unit_Array;
    if type(assigned) == "table" then
        for i = 1, #assigned do addUniqueUnitToken(units, seen, assigned[i]); end
    else
        for i = 1, 4 do addUniqueUnitToken(units, seen, "party" .. i); end
        for i = 1, 40 do addUniqueUnitToken(units, seen, "raid" .. i); end
    end
    return units;
end

function D:RefreshProtectedAuraSounds(reason)
    self:ClearProtectedAuraSounds();

    if not self:IsProtectedAuraSoundEngineAvailable() then return 0; end
    if not self.profile or not self.profile.PlaySound or self.profile.SoundProtectedAuraAlerts == false then return 0; end

    local learnedIDs = getProtectedAuraSoundIDs();
    local spellIDs, seen = {}, {};
    local builtIns = getBuiltInProtectedAuraSoundIDs();
    for i = 1, #builtIns do
        local id = builtIns[i]; if not seen[id] then seen[id] = true; spellIDs[#spellIDs + 1] = id; end
    end
    if type(learnedIDs) == "table" then
        for i = 1, #learnedIDs do
            local id = learnedIDs[i]; if not seen[id] then seen[id] = true; spellIDs[#spellIDs + 1] = id; end
        end
    end
    if #spellIDs == 0 then return 0; end

    local soundFile = self:GetDispelNotificationSoundFile();
    local channel = self:GetSoundNotificationChannel();
    local units = self:GetProtectedAuraSoundUnitTokens();
    local trigger = (_G.Enum and _G.Enum.UnitAuraSoundTrigger and _G.Enum.UnitAuraSoundTrigger.Added) or 0;
    local registered = 0;
    local attempted = 0;
    local lastError = nil;

    for u = 1, #units do
        local unit = units[u];
        for i = 1, #spellIDs do
            local spellID = spellIDs[i];
            if type(spellID) == "number" and spellID > 0 and canaccessvalue(spellID)
                and (not _G.issecretvalue or not _G.issecretvalue(spellID))
            then
                local info = {
                    unitToken = unit,
                    spellID = spellID,
                    soundFileName = soundFile,
                    outputChannel = channel,
                };
                attempted = attempted + 1;
                local ok, handle = pcall(_G.C_UnitAuras.AddAuraSound, trigger, info);
                if ok and type(handle) == "number" and canaccessvalue(handle) then
                    NativeAuraSoundHandles[#NativeAuraSoundHandles + 1] = handle;
                    registered = registered + 1;
                elseif not ok then
                    lastError = tostring(handle);
                else
                    lastError = "AddAuraSound returned no usable auraSoundID";
                end
            end
        end
    end

    T._AuraSoundDiag = T._AuraSoundDiag or {};
    T._AuraSoundDiag.registered = registered;
    T._AuraSoundDiag.attempted = attempted;
    T._AuraSoundDiag.lastReason = reason or "unknown";
    T._AuraSoundDiag.lastError = lastError;
    T._AuraSoundDiag.unitCount = #units;
    T._AuraSoundDiag.spellCount = #spellIDs;

    if self.debug then
        self:Debug("Native aura sounds refreshed:", registered, "/", attempted, "registrations; reason:", reason or "unknown", lastError or "");
    end
    if self.Refresh121DispelAlertSoundCache then self:Refresh121DispelAlertSoundCache() end
    return registered;
end

function D:PrintAuraSoundDiagnostics()
    local ids, key = getProtectedAuraSoundIDs();
    local diag = T._AuraSoundDiag or {};
    self:Println("--- Zhaohu Sound Diagnostics [Zhaohu-Decursive] ---");
    self:Println("Build marker: Zhaohu-Decursive");
    local builtIns = getBuiltInProtectedAuraSoundIDs();
    self:Println(("Context: %s | learned IDs: %d | built-in active: %d"):format(tostring(key or "unknown"), type(ids) == "table" and #ids or 0, #builtIns));
    if self.GetDispelDBStats then
        local ds = self:GetDispelDBStats();
        self:Println(("Local DispelDB: %d entries | %d friendly | %d enemy/purge"):format(ds.total or 0, ds.friendly or 0, ds.hostile or 0));
    end
    if #builtIns > 0 then
        local bp = {}; for i = 1, #builtIns do bp[#bp + 1] = tostring(builtIns[i]); end
        self:Println("Built-in IDs: " .. table.concat(bp, ", "));
    end
    if type(ids) == "table" and #ids > 0 then
        local parts = {};
        for i = 1, #ids do parts[#parts + 1] = tostring(ids[i]); end
        self:Println("Spell IDs: " .. table.concat(parts, ", "));
    end
    self:Println(("Native AddAuraSound: %d/%d registered | units=%s | spells=%s"):format(tonumber(diag.registered) or 0, tonumber(diag.attempted) or 0, tostring(diag.unitCount or 0), tostring(diag.spellCount or 0)));
    self:Println(("Player SPELL_DISPEL events: %d"):format(tonumber(diag.playerDispelEvents) or 0));
    if (tonumber(diag.playerDispelEvents) or 0) > 0 then
        self:Println(("Last dispelled-aura field: type=%s | accessible=%s | secret=%s"):format(
            tostring(diag.lastDispelExtraType or "nil"),
            diag.lastDispelExtraAccessible and "yes" or "no",
            diag.lastDispelExtraSecret and "yes" or "no"));
        if diag.lastDispelExtraPublicID then
            self:Println("Public dispelled aura ID: " .. tostring(diag.lastDispelExtraPublicID));
        else
            self:Println("Public dispelled aura ID: unavailable");
        end
    end
    self:Println("Last refresh: " .. tostring(diag.lastReason or "never"));
    if diag.lastLearned then self:Println("Last learned: " .. tostring(diag.lastLearnedName or "spell") .. " (" .. tostring(diag.lastLearned) .. ")"); end
    if diag.lastError then self:Println("Last AddAuraSound result: " .. tostring(diag.lastError)); end
    self:Println("-------------------------------");
end

SLASH_ZHAOHUSOUND1 = "/zdsound";
SlashCmdList["ZHAOHUSOUND"] = function()
    if D and D.PrintAuraSoundDiagnostics then D:PrintAuraSoundDiagnostics(); end
end

SLASH_ZHAOHUDB1 = "/zddb";
SlashCmdList["ZHAOHUDB"] = function()
    if D and D.PrintDispelDBDiagnostics then D:PrintDispelDBDiagnostics(); end
end


-- LIVE-LIST DISPLAY functions {{{



-- Those set the scalling of the LIVELIST container
-- SACALING FUNCTIONS {{{
-- Place the LIVELIST container according to its scale
function D:PlaceLL () -- {{{
    local UIScale       = UIParent:GetEffectiveScale()
    local FrameScale    = DecursiveMainBar:GetEffectiveScale();
    local x, y = D.profile.MainBarX, D.profile.MainBarY;

    -- check if the coordinates are correct
    if x and y and (x + 10 > UIParent:GetWidth() * UIScale or x < 0 or (-1 * y + 10) > UIParent:GetHeight() * UIScale or y > 0) then
        x = false; -- reset to default position
        T._FatalError("Decursive's bar position reset to default");
    end

    -- Executed for the very first time, then put it in the top right corner of the screen
    if (not x or not y) then
        x =    (UIParent:GetWidth()  * UIScale) / 2;
        y =  - (UIParent:GetHeight() * UIScale) / 8;

        D.profile.MainBarX = x;
        D.profile.MainBarY = y;
    end

    -- set to the scaled position
    DecursiveMainBar:ClearAllPoints();
    DecursiveMainBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x/FrameScale , y/FrameScale);
    DcrLiveList:ClearAllPoints();
    DcrLiveList:SetPoint("TOPLEFT", DecursiveMainBar, "BOTTOMLEFT");
end -- }}}

-- Save the position of the frame without its scale
function D:SaveLLPos () -- {{{
    if self.profile and DecursiveMainBar:IsVisible() then
        -- We save the unscalled position (no problem if the sacale is changed behind our back)
        self.profile.MainBarX = DecursiveMainBar:GetEffectiveScale() * DecursiveMainBar:GetLeft();
        self.profile.MainBarY = DecursiveMainBar:GetEffectiveScale() * DecursiveMainBar:GetTop() - UIParent:GetHeight() * UIParent:GetEffectiveScale();


        if self.profile.MainBarX < 0 then
            self.profile.MainBarX = 0;
        end

        if self.profile.MainBarY > 0 then
            self.profile.MainBarY = 0;
        end

        D:Debug("LL pos Saved:", self.profile.MainBarX, self.profile.MainBarY);

    end
end -- }}}

-- set the scaling of the LIVELIST container according to the user settings
function D:SetLLScale (NewScale) -- {{{

    -- save the current position without any scaling
    D:SaveLLPos ();
    -- Set the new scale
    DecursiveMainBar:SetScale(NewScale);
    DcrLiveList:SetScale(NewScale);
    -- Place the frame adapting its position to the news cale
    D:PlaceLL ();

end -- }}}
-- }}}


-- }}}

-- // }}}
-------------------------------------------------------------------------------

do
   local iterator = 1;
   local DebuffHistHashTable = {};

   function D:Debuff_History_Add( DebuffName, DebuffType, spellID)
       if not canaccessvalue(DebuffName) then  -- do not store secret value
          return;
       end
       if not DebuffHistHashTable[DebuffName] then

           -- reset iterator if out of boundaries
           if iterator > DC.DebuffHistoryLength then
               iterator = 1;
           end

           -- clean hastable if necessary before adding a new entry
           if D.DebuffHistory[iterator] and DebuffHistHashTable[D.DebuffHistory[iterator][1]] then
               DebuffHistHashTable[D.DebuffHistory[iterator][1]] = nil;
           end

           -- Register the name in the HashTable using the debuff type
           DebuffHistHashTable[DebuffName] = (DebuffType and DC.NameToTypes[DebuffType] or DC.NOTYPE);
           --D:Debug(DebuffName, DebuffHistHashTable[DebuffName]);

           -- Put this debuff in our history
           D.DebuffHistory[iterator] = {DebuffName, spellID};

           -- This is a useless comment
           iterator = iterator + 1;
       end

   end

   function D:Debuff_History_Get (Index, Colored)

       local HumanIndex = iterator - Index;

       if HumanIndex < 1 then
           HumanIndex = HumanIndex + DC.DebuffHistoryLength;
       end

       if not D.DebuffHistory[HumanIndex] then
           return "|cFF777777Empty|r", false;
       end

       if Colored then
           --D:Debug(D.DebuffHistory[HumanIndex], DebuffHistHashTable[D.DebuffHistory[HumanIndex]]);
           return D:ColorText(D.DebuffHistory[HumanIndex][1], D.profile.TypeColors[DebuffHistHashTable[D.DebuffHistory[HumanIndex][1]]]), D.DebuffHistory[HumanIndex][2], true;
       else
           return D.DebuffHistory[HumanIndex][1], D.DebuffHistory[HumanIndex][2], true;
       end
   end

end

-- Scanning functionalities {{{
-------------------------------------------------------------------------------

do

    local D                 = D;
    local C_UnitAuras       = _G.C_UnitAuras

    local filter = DC.MN and "RAID_PLAYER_DISPELLABLE" or nil

    local UnitDebuff        = (not DC.MN and _G.UnitDebuff) or function (unitToken, i)

        -- this mechanism is completely disabled in 12.1 so do nothing for now...
        if DC.TWELVEONE then
            return nil
        end

        local auraData = C_UnitAuras.GetDebuffDataByIndex(unitToken, i, filter); -- forbidden in 12.1...

        if not auraData then
			return nil;
		end

        return auraData.name,
		auraData.icon,
		auraData.applications,
		auraData.dispelName,
		auraData.duration,
		auraData.expirationTime,
		nil,
		nil,
		nil,
		auraData.spellId,
        DC.MN and auraData.auraInstanceID or nil;
    end

    D.UnitDebuff = UnitDebuff -- it's reused in dcr_events

    local UnitIsCharmed     = _G.UnitIsCharmed;
    local UnitCanAttack     = _G.UnitCanAttack;
    local GetTime           = _G.GetTime;
    local GetSpellDescription = _G.C_Spell and _G.C_Spell.GetSpellDescription or _G.GetSpellDescription;
    local IsSpellDataCached    = _G.C_Spell.IsSpellDataCached
    local RequestLoadSpellData = _G.C_Spell.RequestLoadSpellData

    local UnTrustedUnitIDs = {
        ['mouseover'] = true,
        ['target'] = true,
    };

    -- This local function only sets interesting values of UnitDebuff()
    local Name, Texture, Applications, TypeName, Duration, ExpirationTime, _, SpellID, secretMode, auraInstanceID;
    local function GetUnitDebuff  (Unit, i) --{{{

        if D.LiveList.TestItemDisplayed and UnitExists(Unit) then -- and not UnTrustedUnitIDs[Unit] then
            if i == 1 then
                Name, Texture, Applications, TypeName, Duration, ExpirationTime, SpellID = "Test item", T._AddonPath .. "iconON.tga", 2, DC.TypeNames[D.Status.ReversedCureOrder[1]], 70, (D.LiveList.TestItemDisplayed + 70), 0;
                -- D:Debug("|cFFFF0000Setting test debuff for ", Unit, " (debuff ", i, ")|r");--, Name, Texture, Applications, TypeName, Duration, ExpirationTime);
                return true;
            else
                i = i - 1;
            end
        end

        Name, Texture, Applications, TypeName, Duration, ExpirationTime, _, _, _, SpellID, auraInstanceID = UnitDebuff (Unit, i);

        secretMode = not canaccessvalue(TypeName)

        if Name then
            return true;
        else
            return false;
        end
    end --}}}

    -- there is a known maximum number of unit and a known maximum debuffs per unit so lets allocate the memory needed only once. Memory will be allocated when needed and re-used...
    local DebuffUnitCache = {};

    -- Variables are declared outside so that Lua doesn't initialize them at each call
    local Type, i, StoredDebuffIndex, CharmFound, IsCharmed;

    local DcrC = T._C; -- for faster access


    local function checkSpellIDForBleed()
        -- it appears that sometime SpellID can be nil...
        if not SpellID or D.Status.t_CheckBleedDebuffsActiveIDs[SpellID] ~= nil
            or not D.db.global.BleedAutoDetection then
            return
        end

        if not IsSpellDataCached(SpellID) then
            RequestLoadSpellData(SpellID);

        elseif D.Status.P_BleedEffectsKeywords_noCase ~= false then
            if D:hasDescBleedEffectkeyword(GetSpellDescription(SpellID)) then
                D.Status.t_CheckBleedDebuffsActiveIDs[SpellID] = true;
                D.db.global.t_BleedEffectsIDCheck[SpellID] = true;
            else
                D.Status.t_CheckBleedDebuffsActiveIDs[SpellID] = false;
            end

        end
    end

    -- This is the core debuff scanning function of Decursive
    -- This function does more than just reporting Debuffs. it also detects charmed units

    function D:GetUnitDebuffAll (Unit) --{{{
        -- create a Debuff table for this unit if there is not already one
        if not DebuffUnitCache[Unit] then
            DebuffUnitCache[Unit] = {};
        end

        -- This is just a shortcut for easier readability
        local ThisUnitDebuffs = DebuffUnitCache[Unit];

        i = 1;                  -- => to index all debuffs
        StoredDebuffIndex = 1;  -- => this index only debuffs with a type
        CharmFound = false;     -- => avoid to find that the unit is charmed again and again...


        -- test if the unit is mind controlled once
        -- The unit is not mouseover or target and it's attackable ---> it's charmed! (A new game's mechanic as been introduced where a player can become hostile but remain in control...)
        if not UnTrustedUnitIDs[Unit] and UnitCanAttack("player", Unit) then
            IsCharmed = true;
        else
            IsCharmed = false;
        end

        if self.LiveList.TestItemDisplayed and not UnTrustedUnitIDs[Unit] and (D.Status.ReversedCureOrder[1] == DC.CHARMED or D.Status.ReversedCureOrder[1] == DC.ENEMYMAGIC) then
            IsCharmed = true;
        end

        -- iterate all available debuffs
        while true do
            if not GetUnitDebuff(Unit, i) then
                if not IsCharmed or CharmFound then
                    break;
                else
                    Name = "*Charm effect*";
                    Texture = T._AddonPath .. "iconON.tga";
                    ExpirationTime = false;
                    Duration = false;
                    Applications = 0;
                    --D:AddDebugText("Charm effect without debuff", i);
                end
            end

            local isSpellIDScret = not canaccessvalue(SpellID)

            --[==[
            if isSpellIDScret then
                D:Debug("spell ids are secret, aura id: ", auraInstanceID)
            end

            if secretMode then
                D:Debug("Debuff type is secret")
            end
            ]==]

            -- 12.1 SAFE: Use safe wrapper for dispel type color
            local s_color = DC.MN and auraInstanceID and D:GetDispelTypeColorSafe(Unit, auraInstanceID)

            -- test for a type
            if not secretMode then
                if TypeName and TypeName ~= "" then
                    Type = DC.NameToTypes[TypeName];
                elseif not isSpellIDScret and DC.IS_OMNI_DEBUFF[SpellID] then -- it's a special debuff for which any dispel will work
                    TypeName = DC.TypeNames[self.Status.ReversedCureOrder[1]];
                    Type = DC.NameToTypes[TypeName]
                elseif not isSpellIDScret and self.Status.CuringSpells[DC.BLEED] then
                    checkSpellIDForBleed();
                    if D.Status.t_CheckBleedDebuffsActiveIDs[SpellID] then
                        Type = DC.NameToTypes["Bleed"]
                        TypeName = DC.TypeNames[DC.BLEED];
                    else
                        Type = false;
                    end
                else
                    Type = false;
                end
            elseif s_color then --
                -- just affect the first spell we know, it is mormally used to detect the range or button miss clicks
                -- but in MN it's no longer possible so just default to the first spell as it's better than nothing...
                TypeName = DC.TypeNames[self.Status.ReversedCureOrder[1]];
                Type = DC.NameToTypes[TypeName]
            else
                Type = false;
            end

            -- if the unit is charmed and we didn't took care of this information yet
            if IsCharmed and (not CharmFound or Type == DC.MAGIC) then
                -- If the unit has a magical debuff and we can cure it
                -- (note that the target is not friendly in that case)
                if (Type == DC.MAGIC and self.Status.CuringSpells[DC.ENEMYMAGIC]) then
                    Type = DC.ENEMYMAGIC;

                    -- NOTE: if a unit is charmed and has another magical debuff
                    -- this block will be executed...
                else -- the unit doesn't have a magical debuff or we can't remove magical debuffs
                    Type = DC.CHARMED; -- The player can't remove it anyway so just say the unit is afflicted by a charming effect
                    TypeName = DC.TypeNames[DC.CHARMED];
                end
                CharmFound = true;
            end

            -- If we found a type, register the Debuff
            if Type then
                -- Create a Debuff index entry if necessary
                if (not ThisUnitDebuffs[StoredDebuffIndex]) then
                    ThisUnitDebuffs[StoredDebuffIndex] = {};
                end

                ThisUnitDebuffs[StoredDebuffIndex].Duration       = Duration;
                ThisUnitDebuffs[StoredDebuffIndex].ExpirationTime = ExpirationTime;
                ThisUnitDebuffs[StoredDebuffIndex].Texture        = Texture;
                ThisUnitDebuffs[StoredDebuffIndex].Applications   = Applications;
                ThisUnitDebuffs[StoredDebuffIndex].TypeName       = TypeName;
                ThisUnitDebuffs[StoredDebuffIndex].Type           = Type;
                ThisUnitDebuffs[StoredDebuffIndex].Name           = Name;
                ThisUnitDebuffs[StoredDebuffIndex].SpellID        = SpellID;
                ThisUnitDebuffs[StoredDebuffIndex].auraInstanceID = auraInstanceID;
                ThisUnitDebuffs[StoredDebuffIndex].secretMode     = secretMode;
                ThisUnitDebuffs[StoredDebuffIndex].s_color        = s_color;
                ThisUnitDebuffs[StoredDebuffIndex].index          = i;

                -- we can't use i, else we wouldn't have contiguous indexes in the table
                StoredDebuffIndex = StoredDebuffIndex + 1;
            end

            i = i + 1;

            -- if a deadly debuff has been found, just forget everything...
            if not isSpellIDScret and DC.IS_DEADLY_DEBUFF[SpellID] then
                StoredDebuffIndex = 1;
                break;
            end
        end

        -- erase remaining unused entries without freeing the memory (less garbage)
        while (ThisUnitDebuffs[StoredDebuffIndex]) do
            ThisUnitDebuffs[StoredDebuffIndex].Type = false;
            StoredDebuffIndex = StoredDebuffIndex + 1;
        end

        -- if no debuff on the unit then it can't be charmed... or is it?
        -- if i == 1 then
        --    IsCharmed = false;
        -- end

        return ThisUnitDebuffs, IsCharmed;
    end --}}}
end


do
    -- see the comment about DebuffUnitCache
    local ManagedDebuffUnitCache = D.ManagedDebuffUnitCache;


    local continue_; -- if we have to ignore a debuff, this will become false
    local D = D;
    local _;
    local CureOrder;
    local sorting = function (a, b)
        local aApps = canaccessvalue(a.Applications) and a.Applications or 0
        local bApps = canaccessvalue(b.Applications) and b.Applications or 0
        return CureOrder[a.Type] * 10000 - aApps < CureOrder[b.Type] * 10000 - bApps
    end

    local NotRaidOrParty = {
        ["player"]      = true,
        ["target"]      = true,
        ["focus"]       = true,
        ["mouseover"]   = true,
    };

    local HostileHolders = {
        ["target"]      = true,
        ["focus"]       = true,
        ["mouseover"]   = true,
    };

    local function UnitFilteringTest(unit, filterValue)

        --D:Debug("UnitFilteringTest:", unit, filterValue);

        if not filterValue then
            return nil;
        end

        if filterValue==1 and unit ~= 'player' then -- for personal spells
            return true;
        elseif filterValue==2 and NotRaidOrParty[unit] then -- for spells that can't be used on oneself
            return true;
        end

    end

    D.UnitFilteringTest = UnitFilteringTest; -- I need this function elsewhere

    -- This function will return a table containing only the Debuffs we can cure excepts the one we have to ignore
    -- in different conditions.
    function D:UnitCurableDebuffs (Unit, JustOne) -- {{{

        if not Unit then
            D:AddDebugText("No unit supplied to UnitCurableDebuffs()");
            return DC.EMPTY_TABLE, false;
        end

        CureOrder = D:GetCureOrderTable();

        if not ManagedDebuffUnitCache[Unit] then
            ManagedDebuffUnitCache[Unit] = {};
        end

        local ManagedDebuffs = ManagedDebuffUnitCache[Unit]; -- shortcut for readability

        if ManagedDebuffs[1] then
            t_wipe(ManagedDebuffs);
        end

        local AllUnitDebuffs, IsCharmed = self:GetUnitDebuffAll(Unit); -- always return a table, may be empty though

        local Spells    = self.Status.CuringSpells; -- shortcut to available spells by debuff type

        for _, Debuff in ipairs(AllUnitDebuffs) do

            continue_ = true;

            if not Debuff.Type then
                continue_ = false;
                break
            end

            local nameAccessible = canaccessvalue(Debuff.Name)

            -- test if we have to ignore this debuff  {{{ --

            if UnitFilteringTest(Unit, self.Status.UnitFilteringTypes[Debuff.Type]) then
                continue_ = false; -- == skip this debuff
            end

            if nameAccessible and self.profile.DebuffsToIgnore[Debuff.Name] then
                -- these are the BAD ones... the ones that make the target immune... abort this unit
                --D:Debug("UnitCurableDebuffs(): %s is ignored", Debuff.Name);
                break; -- exit here
            end

            if nameAccessible and self.profile.BuffDebuff[Debuff.Name] then
                -- these are just ones you don't care about (sleepless deam etc...)
                continue_ = false; -- == skip this debuff
                --D:Debug("UnitCurableDebuffs(): %s is not a real debuff", Debuff.Name);
            end

            if self.Status.Combat or nameAccessible and self.profile.DebuffAlwaysSkipList[Debuff.Name] then
                local _, EnUClass = UnitClass(Unit);
                if self.profile.skipByClass[EnUClass] then
                    if  nameAccessible and self.profile.skipByClass[EnUClass][Debuff.Name] then
                        -- these are just ones you don't care about by class while in combat

                        -- This lead to a problem because once the fight is finished there are no event to trigger
                        -- a rescan of this unit, so the debuff does not appear...

                        -- solution to the above problem:

                        if not self.profile.DebuffAlwaysSkipList[Debuff.Name] then
                            self:AddDelayedFunctionCall("ReScan"..Unit, D.MicroUnitF.UpdateMUFUnit, D.MicroUnitF, Unit);
                        end

                        D:Debug("UnitCurableDebuffs(): %s is configured to be skipped", Debuff.Name);
                        continue_ = false;
                    end
                end
            end

            -- }}}


            if continue_ then
                --      self:Debug("Debuffs matters");
                -- If we are still here it means that this Debuff is something not to be ignored...


                -- We have an active curing spell for that type and we want to use it
                if Spells[Debuff.Type] and CureOrder[Debuff.Type] then
                    -- self:Debug("we can cure it");

                    -- if we do have a spell to cure
                    if Spells[Debuff.Type] then

                        -- self:Debug("It's managed");

                        ManagedDebuffs[#ManagedDebuffs + 1] = Debuff;

                        -- the live-list only reports the first debuff found and set JustOne to true
                        if JustOne then
                            break;
                        end
                    end
                end
            end
        end -- for END

        if ManagedDebuffs[1] then

            -- sort the table only if it contains more than 1 debuff
            if #ManagedDebuffs > 1 then
                t_sort(ManagedDebuffs, sorting);
            end

            if not D.UnitDebuffed[Unit] then
                D.UnitDebuffed[Unit] = true;
                D.ForLLDebuffedUnitsNum = D.ForLLDebuffedUnitsNum + 1;
            end

        else
            if D.UnitDebuffed[Unit] then
                D.UnitDebuffed[Unit] = false;
                D.ForLLDebuffedUnitsNum = D.ForLLDebuffedUnitsNum - 1;
            end
            return DC.EMPTY_TABLE, false; -- avoid race conditions
        end

        return ManagedDebuffs, IsCharmed;

    end -- // }}}

    local GetTime               = _G.GetTime;
    local Debuffs               = DC.EMPTY_TABLE; local IsCharmed = false; local Unit; local MUF; local IsDebuffed = false; local IsMUFDebuffed = false; local CheckStealth = false;
    local NoScanStatuses        = false;
    local band                  = _G.bit.band;
    --[==[
    --local debugprofilestop = _G.debugprofilestop;
    ]==]
    function D:ScanEveryBody()

        if not NoScanStatuses then
            NoScanStatuses = {[DC.ABSENT] = true, [DC.FAR] = true, [DC.BLACKLISTED] = true};
        end

        local UnitArray = self.Status.Unit_Array; local i = 1;
        local CheckStealth = self.profile.Show_Stealthed_Status;

        --[==[
        --local start = debugprofilestop();
        --D:Debug("Scanning everybody...", self.Status.delayedDebuffReportDisabled, self.db.global.MFScanEverybodyReport)
        ]==]

        while UnitArray[i] do
            Unit = UnitArray[i];
            MUF = self.MicroUnitF.UnitToMUF[Unit];

            if MUF and not NoScanStatuses[MUF.UnitStatus] then
                IsMUFDebuffed = MUF.Debuffs[1] and true or band(MUF.UnitStatus, DC.CHARMED_STATUS) == DC.CHARMED_STATUS;
                local MUFDebuffName = MUF.Debuffs[1] and MUF.Debuffs[1].Name

                Debuffs, IsCharmed = self:UnitCurableDebuffs(Unit, true); -- leaks memory in 10.2.5

                if CheckStealth then
                    self.Stealthed_Units[Unit] = self:CheckUnitStealth(Unit); -- update stealth status
                end

                IsDebuffed = (Debuffs[1] and true) or IsCharmed;
                -- If MUF disagrees
                if (IsDebuffed ~= IsMUFDebuffed) and not D:DelayedCallExixts("Dcr_Update" .. Unit) then
                    -- add counters here independently of the option so that I can monitor things using the reports sent to me.
                    -- a counter saved in the db, and a local session counter

                    if IsDebuffed then
                        self.Status.delayedDebuffOccurences = self.Status.delayedDebuffOccurences + 1;
                        self.db.global.delayedDebuffOccurences = self.db.global.delayedDebuffOccurences + 1;
                    else
                        self.Status.delayedUnDebuffOccurences = self.Status.delayedUnDebuffOccurences + 1;
                        self.db.global.delayedUnDebuffOccurences = self.db.global.delayedUnDebuffOccurences + 1;
                    end

                    if (not self.Status.delayedDebuffReportDisabled) and self.db.global.MFScanEverybodyReport then
                        if IsDebuffed then
                            self:AddDebugText("delayed debuff found by scaneveryone (you can disable this error by unchecking the `Periodic scan debug reporting` option in the MUFs performance options - see Decursive 2.7.16 release notes)", Unit, Debuffs[1].Name);
                            --D:ScheduleDelayedCall("Dcr_lateanalysis" .. Unit, self.MicroUnitF.LateAnalysis, 1, self.MicroUnitF, "ScanEveryone", Debuffs, MUF, MUF.UnitStatus);
                        else
                            self:AddDebugText("delayed UNdebuff found by scaneveryone (you can disable this error by unchecking the `Periodic scan debug reporting` option in the MUFs performance options - see Decursive 2.7.16 release notes)", Unit, MUFDebuffName, IsDebuffed, IsMUFDebuffed, MUF.UnitStatus);
                        end
                    else
                        self:Debug("delayed buff found but no-report is set")
                    end

                    self.MicroUnitF:UpdateMUFUnit(Unit, true);

                    --[==[
                    --D:Println("HAAAAAAA!!!!!");
                    ]==]
                end
            end

            i = i + 1;
        end
        self.Status.delayedDebuffReportDisabled = false; -- set to true after a reconfiguration, reset only here.

        --[==[
        --D:Debug("|cFF777777Scanning everybody...", i - 1, "units scanned in ", debugprofilestop() - start, "miliseconds|r");
        ]==]
    end


    -- a little test... the ".." way wins (6x faster than the format solution) when both sides are strings
    function D:tests()

        local test = "test1";
        local start = GetTime();
        local strings = {"string1", "string2", "strring3"};
        local teststring = "unitraid5"
        for i =1, 1000000 do
            teststring = strings[i%3 + 1];
            test = "test_"..teststring;
        end
        D:Debug("pass (\"\".. completed in:", GetTime() - start, test);

        start = GetTime();
        for i =1, 1000000 do
            local t = strings[i%3 + 1];
            test = ("test_%s"):format(teststring);
        end
        D:Debug("pass format completed in:", GetTime() - start, test);

    end

end

--local UnitBuffsCache    = {};

do
    local G_UnitBuff = _G.UnitBuff; -- In 10.2.5 UnitBuff and acolytes were deprecated and are falling back to calling C_UnitAuras functions which create a new table each time and thus leak garbage each time they return debuff info... (if only we could provide those functions with a table to use...)
    local GetAuraDataBySpellName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName or nil;
    local buffName;
    local GetCVarBool = _G.GetCVarBool

    local function auraAccessRestricted()
        return DC.MN and (InCombatLockdown() or GetCVarBool("secretAurasForced"))
    end

    local function UnitBuff(unit, BuffNameToCheck)

        local restricted = auraAccessRestricted()
            --[==[
            --D:Debug("UnitBuff", unit, BuffNameToCheck)
            ]==]
        if not restricted and GetAuraDataBySpellName and GetAuraDataBySpellName(unit, BuffNameToCheck) then
            --[==[
            D:Debug("used C_UnitAuras")
            ]==]

            -- return the aura instance id instead of true so that we can check when it's removed
            return GetAuraDataBySpellName(unit, BuffNameToCheck).auraInstanceID
        elseif not restricted and not GetAuraDataBySpellName then
            --[==[
            D:Debug("used old buff scan method")
            ]==]

            for i = 1, 40 do
                buffName = G_UnitBuff(unit, i)
                if not buffName then
                    return false
                else
                    if BuffNameToCheck == buffName then
                        return (G_UnitBuff(unit, i)) and true or false
                    end
                end
            end
        end

        return false
    end

    -- this function returns true if one of the debuff(s) passed to it is found on the specified unit
    function D:CheckUnitForBuffs(unit, BuffNamesToCheck) --{{{

        if type(BuffNamesToCheck) == "string" then

            return UnitBuff(unit, BuffNamesToCheck)

        else
            for buff in pairs(BuffNamesToCheck) do

                return UnitBuff(unit, buff)

            end
        end

        return false;
    end --}}}
end



function D:CheckUnitStealth(unit)
    return self:CheckUnitForBuffs(unit, DC.IS_STEALTH_BUFF)
end
-- }}}



T._LoadedFiles["Decursive.lua"] = "@project-version@";

-- Sin
