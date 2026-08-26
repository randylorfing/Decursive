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
if not T._LoadedFiles or not T._LoadedFiles["Dcr_utils.lua"] then
    if not DecursiveInstallCorrupted then T._FatalError("Decursive installation is corrupted! (Dcr_utils.lua not loaded)"); end;
    DecursiveInstallCorrupted = true;
    return;
end
T._LoadedFiles["Dcr_opt.lua"] = false;

local D = T.Dcr;

local function RegisterClassLocals_Once() -- {{{


    -- Make sure to never crash if some locals are missing (seen this happen on
    -- Chinese clients when relying on LOCALIZED_CLASS_NAMES_MALE constant)
    -- While that was probably caused by a badd-on redefining the constant,
    -- it's best to stay on the safe side...

    local localizedClasses = {};

    D:tcopy(localizedClasses, LocalizedClassList and LocalizedClassList(false) or FillLocalizedClassList({}, false));


    D.LC = setmetatable(localizedClasses, {__index = function(t,k) return k end});

    RegisterClassLocals_Once = nil;
end -- }}}

T._CatchAllErrors = "RegisterClassLocals_Once";      RegisterClassLocals_Once();


local L  = D.L;
local LC = D.LC;
local DC = T._C;
T._CatchAllErrors = "LibDBIcon";
local icon = LibStub("LibDBIcon-1.0", true)
T._CatchAllErrors = false;

local pairs             = _G.pairs;
local ipairs            = _G.ipairs;
local type              = _G.type;
local table             = _G.table;
local str_format        = _G.string.format;
local str_gsub          = _G.string.gsub;
local str_sub           = _G.string.sub;
local abs               = _G.math.abs;
local GetNumRaidMembers = DC.GetNumRaidMembers;
local GetNumPartyMembers= _G.GetNumSubgroupMembers;
local InCombatLockdown  = _G.InCombatLockdown;
local GetItemInfo           = _G.C_Item and _G.C_Item.GetItemInfo or _G.GetItemInfo;
local GetSpellInfo          = _G.C_Spell and _G.C_Spell.GetSpellInfo or _G.GetSpellInfo;
local GetSpellName          = _G.C_Spell and _G.C_Spell.GetSpellName or function (spellId) return (GetSpellInfo(spellId)) end;
local GetSpellDescription = _G.C_Spell and _G.C_Spell.GetSpellDescription or _G.GetSpellDescription;
local GetSpecialization = _G.GetSpecialization or (GetActiveTalentGroup or function () return nil; end);
local GetAddOnMetadata  = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata;
local _;
local tonumber          = _G.tonumber;
local TN                = function(string) return tonumber(string) or nil; end;
local C_Spell           = C_Spell;
-- Default values for the option


function D:GetDefaultsSettings()
    local DS = DC.DS;
    local DSI = DC.DSI;

    return {
        -- default settings {{{
        class = {
            -- Curring order (1 is the most important, 7 the lesser...)
            CureOrder = {
                [DC.MAGIC]      = 1,
                [DC.CURSE]      = 2,
                [DC.POISON]     = 3,
                [DC.DISEASE]    = 4,
                [DC.ENEMYMAGIC] = 5,
                [DC.CHARMED]    = 6,
                [DC.BLEED]      = 7,
            },

            UserSpells = {
                --Exemple / defaults
                [T._C.DSI["SPELL_COUNTERSPELL"]] = {
                    Types = {DC.CHARMED},
                    Better = 10,
                    Pet = false,
                    Disabled = true,
                    IsDefault = true,
                    IsItem = false,
                },
            },
        },
        locale = {
            BleedEffectsKeywords = D:GetDefaultBleedEffectsKeywords(),
        },
        global = {
            SRTLerrors = {
                ["total"] = 0
                -- "file:line" = {date, ...}
            },
            debug = false,
            NonRelease = false,
            TocExpiredDetection = false,
            LastExpirationAlert = 0,
            NewerVersionDetected = D.VersionTimeStamp,
            NewerVersionName = false,
            NewerVersionAlert = 0,
            NewVersionsBugMeNot = false,
            LastVersionAnnounce = 0,
            LastUnpackagedAlert = 0,

            -- WoW 12.1 learned protected-aura IDs are scoped by class/spec.
            -- This prevents a spell learned by one dispel toolkit from producing
            -- false alerts on a specialization that cannot remove that effect.
            SoundProtectedAuraSpellIDsBySpec = {},

            -- the key to bind the macro to
            MacroBind = false,
            NoStartMessages = false,

            MouseButtons = {
                "*%s1", -- left mouse button
                "*%s2", -- right mouse button
                "ctrl-%s1",
                "ctrl-%s2",
                "shift-%s1",
                "shift-%s2",
                "shift-%s3",
                "alt-%s1",
                "alt-%s2",
                "alt-%s3",
                "*%s4",
                "ctrl-%s4",
                "shift-%s4",
                "alt-%s4",
                "*%s5",
                "ctrl-%s5",
                "shift-%s5",
                "alt-%s5",
                "*%s3",       -- the last two entries are always target and focus
                "ctrl-%s3",
            },
            BleedAutoDetection = true,
            t_BleedEffectsIDCheck = {
                [396007] = true, -- Vicious Peck
                [396093] = true, -- Savage Leap
                [193092] = true, -- Bloodletting Sweep
                [375937] = true, -- Rending Strike
                [376997] = true, -- Savage Peck
                [381683] = true, -- Swift Stab
                [388911] = true, -- Severing Slash
                [371005] = true, -- arcane but dispellable with cauterizing flame
                [384134] = true, -- Pierce
                [394628] = true, -- Peck
                [372860] = true, -- Searing Wounds
                [393444] = true, -- Gushing Wound
                [413131] = true, -- Whirling Dagger
                [413136] = true, -- Whirling Dagger
            },
            -- The time between each MUF update
            DebuffsFrameRefreshRate = 0.10,

            -- The number of MUFs updated every DebuffsFrameRefreshRate
            DebuffsFramePerUPdate = 10,

            MFScanEverybodyTimer = 1,
            MFScanEverybodyReport = false,

            delayedDebuffOccurences = 0,
            delayedUnDebuffOccurences = 0,

        },

        profile = {
            -- this is the priority list of people to cure
            PriorityList = { },
            PriorityListClass = { },
            PrioGUIDtoNAME = { },

            -- this is the people to skip
            SkipList = { },
            SkipListClass = { },
            SkipGUIDtoNAME = { },

            -- The micro units debuffs frame
            ShowDebuffsFrame = true,

            -- Setting to hide the MUF handle (render it mouse-non-interactive)
            HideMUFsHandle = false,

            AutoHideMUFs = 1,

            -- The maximum number of MUFs to be displayed
            DebuffsFrameMaxCount = 80,

            DebuffsFrameElemScale = 1,

            DebuffsFrameElemAlpha = .35,

            DebuffsFrameElemBorderShow = true,

            -- WoW 12.1 compatibility: show the dispel-spell cooldown overlay on MUFs.
            CooldownOverlay121Enabled = true,
            CooldownOverlay121Style = "OVERLAY_TIMER",
            CooldownOverlay121Opacity = .62,
            CooldownOverlay121Numbers = true,
            CooldownPriority2Border121Enabled = true,
            CooldownBorder121Color = {1, .2, .1}, -- legacy v10 setting; priority #2 color is now taken from MF_colors[2]
            CooldownBorder121Alpha = .95,
            CooldownBorder121Thickness = 2,
            CooldownPriority2Pulse121Enabled = true,
            StatusLight121Enabled = false,
            OutOfRange121Enabled = false,
            OutOfRange121DimAmount = .60,
            OutOfRange121Color = {1, 1, 0},
            TextAlerts121Enabled = true,
            Environment121Mode = "AUTO",
            Environment121ProfilesInitialized = false,
            Environment121Profiles = {
                RAID = { OutOfRange121Enabled = true, OutOfRange121DimAmount = .45, OutOfRange121Color = {1,1,0}, CooldownOverlay121Enabled = true, CooldownOverlay121Opacity = .50, CooldownOverlay121Numbers = false, Detection121Mode = "STRICT_MANAGED", SecondaryAffliction121Enabled = true, SecondaryAffliction121Pulse = false, SharedPriorityCooldown121Enabled = true, ClearCleansedTarget121Enabled = true, TextAlerts121Enabled = true, EnvironmentChat121Enabled = true },
                MYTHIC_PLUS = { OutOfRange121Enabled = true, OutOfRange121DimAmount = .70, OutOfRange121Color = {1,1,0}, CooldownOverlay121Enabled = true, CooldownOverlay121Opacity = .70, CooldownOverlay121Numbers = true, Detection121Mode = "STRICT_MANAGED", SecondaryAffliction121Enabled = true, SecondaryAffliction121Pulse = true, SharedPriorityCooldown121Enabled = true, ClearCleansedTarget121Enabled = true, TextAlerts121Enabled = true, EnvironmentChat121Enabled = true },
                DUNGEON = { OutOfRange121Enabled = true, OutOfRange121DimAmount = .60, OutOfRange121Color = {1,1,0}, CooldownOverlay121Enabled = true, CooldownOverlay121Opacity = .60, CooldownOverlay121Numbers = true, Detection121Mode = "STRICT_MANAGED", SecondaryAffliction121Enabled = true, SecondaryAffliction121Pulse = true, SharedPriorityCooldown121Enabled = true, ClearCleansedTarget121Enabled = true, TextAlerts121Enabled = true, EnvironmentChat121Enabled = true },
                -- PvP keeps the dungeon-sized visual tuning, but disables all
                -- addon-owned center-screen text and profile chat by default.
                PVP = { OutOfRange121Enabled = true, OutOfRange121DimAmount = .60, OutOfRange121Color = {1,1,0}, CooldownOverlay121Enabled = true, CooldownOverlay121Opacity = .60, CooldownOverlay121Numbers = true, Detection121Mode = "STRICT_MANAGED", SecondaryAffliction121Enabled = true, SecondaryAffliction121Pulse = true, SharedPriorityCooldown121Enabled = true, ClearCleansedTarget121Enabled = true, TextAlerts121Enabled = false, EnvironmentChat121Enabled = false },
                OPEN_WORLD = { OutOfRange121Enabled = false, OutOfRange121DimAmount = .60, OutOfRange121Color = {1,1,0}, CooldownOverlay121Enabled = true, CooldownOverlay121Opacity = .62, CooldownOverlay121Numbers = true, Detection121Mode = "STRICT_MANAGED", SecondaryAffliction121Enabled = true, SecondaryAffliction121Pulse = true, SharedPriorityCooldown121Enabled = true, ClearCleansedTarget121Enabled = true, TextAlerts121Enabled = true, EnvironmentChat121Enabled = true },
            },

            DebuffsFrameElemBorderAlpha = .2,

            DebuffsFrameElemTieTransparency = true,

            DebuffsFramePerline = 10,
            -- v11 large-raid layout: keep the MUF grid compact (max five rows)
            -- while preserving the existing manual units-per-line setting as a fallback.
            DebuffsFrameRaidAutoLayout121 = true,

            DebuffsFrameTieSpacing = true,

            DebuffsFrameXSpacing = 3,

            DebuffsFrameYSpacing = 3,

            DebuffsFrameStickToRight = false,

            DebuffsFrameShowHelp = true,

            -- position x save
            DebuffsFrameContainer_x = false,

            -- position y save
            DebuffsFrameContainer_y = false,

            -- reverse MUFs disaplay
            DebuffsFrameGrowToTop = false,

            DebuffsFrameVerticalDisplay = false,

            -- Center text displayed on MUFs, defaults to time left
            CenterTextDisplay = '1_TLEFT',

            -- this is wether or not to show the live-list
            HideLiveList = false,

            LiveListAlpha = 0.7,

            LiveListScale = 1.0,

            -- position of the "Decursive" main bar, the live-list is anchored to this bar.
            MainBarX = false,

            MainBarY = false,

            -- This will turn on and off the sending of messages to the default chat frame
            Print_ChatFrame = true,

            -- this will send the messages to a custom frame that is moveable
            Print_CustomFrame = true,

            -- this will disable error messages
            Print_Error = true,

            -- should we scan pets
            Scan_Pets = true,

            -- should we ignore stealthed units? A useless option since a very long time.
            Ingore_Stealthed = false,

            Show_Stealthed_Status = true,

            -- how many to show in the livelist
            Amount_Of_Afflicted = 3,

            -- The live-list will only display units in range of your curring spell
            LV_OnlyInRange = true,

            -- how many seconds to "black list" someone with a failed spell
            CureBlacklist = 5.0,

            -- how often to poll for afflictions in seconds (for the live-list only)
            ScanTime = 0.3,

            -- Are prio list members protected from blacklisting?
            DoNot_Blacklist_Prio_List = false,

            -- Sound notifications. v11.0.7 moved these controls to a dedicated
            -- Sound Notifications page; v11.0.7 expands the alert-sound library.
            PlaySound = true,
            SoundFile = T._AddonPath .. "Sounds\\FemaleDispel.ogg",
            SoundNotificationPreset = "FEMALE_DISPEL",
            SoundNotificationChannel = "Master",
            SoundNotificationIgnoreSeconds = 2.0,
            PlayFailureSound = true,
            SoundProtectedAuraAlerts = true,
            SoundProtectedAuraAutoLearn = true,
            -- Live DISPEL warning is enabled for new/untouched profiles. AceDB
            -- still preserves an explicit false chosen by an existing user.
            Alert121DispelEnabled = true,
            Alert121FontSize = 48,
            -- TIMED (default): hide DISPEL after Alert121DispelDuration seconds.
            -- UNTIL_CLEARED: keep DISPEL visible while a MUF still needs a dispel.
            Alert121DispelMode = "TIMED",
            Alert121DispelDuration = 2,

            -- Hide the buttons
            HideButtons = false,

            -- Display text above in the custom frame
            CustomeFrameInsertBottom = false,

            -- Disable tooltips in affliction list
            AfflictionTooltips = true,

            -- Reverse LiveList Display
            ReverseLiveDisplay = false,

            -- Hide the "Decursive" bar
            BarHidden = true,

            -- if true then the live list will show only if the "Decursive" bar is shown
            LiveListTied = false,

            -- allow to changes the default output window
            OutputWindow = "DEFAULT_CHAT_FRAME", -- ACEDB CRASHES if we set it directly


            MiniMapIcon = {hide=true},

            -- Display a warning if no key is mapped.
            NoKeyWarn = false,

            -- Disable macro creation
            DisableMacroCreation = false,

            -- Allow Decursive's macro editing
            AllowMacroEdit = false,

            -- Those are the different colors used for the MUFs main textures
            MF_colors = {
                [1]                 =   {  .8 , 0   , 0    ,  1     }, -- red
                [2]                 =   {  .3 ,  .3 ,  .8  ,  1     }, -- blue
                [3]                 =   {  .8 ,  .5 ,  .25 ,  1     }, -- orange
                [4]                 =   { 1   , 0   , 1    ,  1     }, -- purple
                [5]                 =   { 1   , 1   , 1    ,  1     }, -- white for undefined
                [6]                 =   { 1   , 1   , 1    ,  1     }, -- white for undefined
                [7]                 =   { 1   , 1   , 1    ,  1     }, -- white for undefined
                [DC.NORMAL]         =   {  .0 ,  .3 ,  .1  ,   .9   }, -- dark green
                [DC.BLACKLISTED]    =   { 0   , 0   , 0    ,  1     }, -- black
                [DC.ABSENT]         =   {  .4 ,  .4 ,  .4  ,   .9   }, -- transparent grey
                [DC.FAR]            =   {  .4 ,  .1 ,  .4  ,   .85  }, -- transparent purple
                [DC.STEALTHED]      =   {  .4 ,  .6 ,  .4  ,  1     }, -- pale green
                [DC.CHARMED_STATUS] =   { 0   , 1   , 0    ,  1     }, -- full green
                ["COLORCHRONOS"]    =   { 0.6 , 0.1 , 0.2  ,   .6   }, -- medium red
            },

            TypeColors = {
                [DC.MAGIC]      = "FF1887DD",
                [DC.ENEMYMAGIC] = "FF98F9FF",
                [DC.CURSE]      = "FFDD22DD",
                [DC.POISON]     = "FF22DD22",
                [DC.DISEASE]    = "FF995533",
                [DC.CHARMED]    = "FFFF0000",
                [DC.BLEED]      = "FFC0B0B0",
                [DC.NOTYPE]     = "FFAAAAAA",
            },

            -- Debuffs {{{
            -- those debuffs prevent us from curing the unit
            DebuffsToIgnore = {
                [DS["Banish"]]                  = true,
                [DS["Frost Trap Aura"]]         = true,
            },

            -- thoses debuffs are in fact buffs...
            BuffDebuff = {
                [DS["DREAMLESSSLEEP"]]          = true,
                [DS["GDREAMLESSSLEEP"]]         = true,
                [(not DC.WOWC) and DS["MDREAMLESSSLEEP"] or "NONE"]         = (not DC.WOWC) and true or nil,
                [DS["DCR_LOC_MINDVISION"]]      = true,
                [(not DC.WOWC) and DS["Arcane Blast"] or "NONE"]            = (not DC.WOWC) and true or nil,
            },

            DebuffAlwaysSkipList = {
            },
            DebuffsSkipList = {
                [DS["ANCIENTHYSTERIA"]] =
                DSI["ANCIENTHYSTERIA"],
                [DS["CRIPLES"]]         =
                DSI["CRIPLES"],
                [DS["DELUSIONOFJINDO"]] =
                DSI["DELUSIONOFJINDO"],
                [DS["DUSTCLOUD"]]       =
                DSI["DUSTCLOUD"],
                [DS["IGNITE"]]          =
                DSI["IGNITE"],
                [DS["MAGMASHAKLES"]]    =
                DSI["MAGMASHAKLES"],
                [DS["DCR_LOC_SILENCE"]] =
                DSI["DCR_LOC_SILENCE"],
                [DS["SONICBURST"]]      =
                DSI["SONICBURST"],
                [DS["TAINTEDMIND"]]     =
                DSI["TAINTEDMIND"],
                [DS["WIDOWSEMBRACE"]]   =
                DSI["WIDOWSEMBRACE"],
            },

            skipByClass = {
                ["WARRIOR"] = {
                    [DS["ANCIENTHYSTERIA"]]     = true,
                    [DS["IGNITE"]]              = true,
                    [DS["TAINTEDMIND"]]         = true,
                    [DS["WIDOWSEMBRACE"]]       = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["ROGUE"] = {
                    [DS["DCR_LOC_SILENCE"]]     = true,
                    [DS["ANCIENTHYSTERIA"]]     = true,
                    [DS["IGNITE"]]              = true,
                    [DS["TAINTEDMIND"]]         = true,
                    [DS["WIDOWSEMBRACE"]]       = true,
                    [DS["SONICBURST"]]          = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["HUNTER"] = {
                    [DS["MAGMASHAKLES"]]        = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["MAGE"] = {
                    [DS["MAGMASHAKLES"]]        = true,
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["WARLOCK"] = {
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["DRUID"] = {
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["PALADIN"] = {
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["PRIEST"] = {
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["SHAMAN"] = {
                    [DS["CRIPLES"]]             = true,
                    [DS["DUSTCLOUD"]]           = true,
                    [DS["DELUSIONOFJINDO"]]     = true,
                },
                ["DEATHKNIGHT"] = {
                },
                ["MONK"] = {
                },
                ["DEMONHUNTER"] = {
                },
                ["EVOKER"] = {
                }
            },
            -- }}}




        }
    } -- }}}
end

local OptionsPostSetActions = { -- {{{
    ["debug"] = function(v)  D.debug = v end,
    ["HideMUFsHandle"] = function(v) D.MFContainerHandle:EnableMouse(not v); D:Print(v and "MUFs handle disabled" or "MUFs handle enabled"); end,
    ["AfflictionTooltips"] = function(v) for id,lvitem in ipairs(D.LiveList.ExistingPerID) do lvitem.Frame:EnableMouse(v); end end,
    ["Amount_Of_Afflicted"] = function(v) D.LiveList:RestAllPosition(); end,
    ["ScanTime"] = function(v) D:ScheduleRepeatedCall("Dcr_LLupdate", D.LiveList.Update_Display, v, D.LiveList); D:Debug("LV scan delay changed:", v); end,
    ["ReverseLiveDisplay"] = function(v) D.LiveList:RestAllPosition(); end,
    ["LiveListScale"] = function(v) D:SetLLScale(v); end,
    ["AutoHideMUFs"] = function(v) D:AutoHideShowMUFs(); end,
    ["DebuffsFrameGrowToTop"] = function(v) D.MicroUnitF:SavePos(); D.MicroUnitF:ResetAllPositions (); end,
    ["DebuffsFrameStickToRight"] = function(v) D.MicroUnitF:SavePos(); D.MicroUnitF:ResetAllPositions (); end,
    ["DebuffsFrameVerticalDisplay"] = function(v) D.MicroUnitF:ResetAllPositions (); end,
    ["DebuffsFrameMaxCount"] = function(v) D.MicroUnitF.MaxUnit = v; D.MicroUnitF:Delayed_MFsDisplay_Update(); end, -- just the number of MUFs is changed MFsDisplay_Update() is enough
    ["DebuffsFramePerline"] = function(v)  D.MicroUnitF:ResetAllPositions (); end,
    ["DebuffsFrameRaidAutoLayout121"] = function(v) D.MicroUnitF:ResetAllPositions (); end,
    ["StatusLight121Enabled"] = function(v)
        if D.Set121MUFStatusLightEnabled then D:Set121MUFStatusLightEnabled(v) end
    end,
    ["DebuffsFrameElemScale"] = function(v)
        -- Legacy scale writes update the currently active party/raid size so
        -- older configuration paths cannot be immediately undone by the
        -- context-aware sizing system.
        if D.MicroUnitF and D.MicroUnitF.SetActiveContextMUFSizePixels then
            D.MicroUnitF:SetActiveContextMUFSizePixels((tonumber(D.profile.DebuffsFrameElemScale) or 1) * (DC.MFSIZE or 20));
        else
            D.MicroUnitF:SetScale(D.profile.DebuffsFrameElemScale);
        end
    end,
    ["DebuffsFrameRefreshRate"] = function(v) D:ScheduleRepeatedCall("Dcr_MUFupdate", D.DebuffsFrame_Update, D.db.global.DebuffsFrameRefreshRate, D); D:Debug("MUFs refresh rate changed:", D.db.global.DebuffsFrameRefreshRate, v); end,
    ["MFScanEverybodyTimer"] = function(v)
        if v > 0 then
            D:ScheduleRepeatedCall("Dcr_ScanEverybody", D.ScanEveryBody, D.db.global.MFScanEverybodyTimer, D);
            D:Debug("MUFs scan every body timer changed:", D.db.global.MFScanEverybodyTimer, v);
        else
            D:CancelDelayedCall("Dcr_ScanEverybody")
            D:Debug("MUFs scan every body canceled", D.db.global.MFScanEverybodyTimer, v);
        end
    end,
    ["MFScanEverybodyReport"] = function(v)
        if D.db.global.MFScanEverybodyTimer > 0 then
            D:ScheduleRepeatedCall("Dcr_ScanEverybody", D.ScanEveryBody, D.db.global.MFScanEverybodyTimer, D);
        end
        D:Debug("MUFs scan every body reporting changed:", D.db.global.MFScanEverybodyReport, v);
    end,

    ["Scan_Pets"] = function(v) D:GroupChanged ("opt CURE_PETS"); end,
    ["PlaySound"] = function(v)
        D.Status.SoundPlayed = false;
        T._DispelNotificationIgnoreUntil = 0;
    end,
    ["DisableMacroCreation"] = function(v) if v then D:SetMacroKey (nil); D:Debug("SetMacroKey (nil)"); end end,
} -- }}}

function D.GetHandler (info, value) -- {{{
    local source = D.db.global;

    if D.db.profile[info[#info]]~=nil then

        source = D.db.profile;

    elseif D.db.class[info[#info]]~=nil then

        source = D.db.class;

    end

    return source[info[#info]];

end -- }}}
-- Used in Ace3 option table to get feedback when setting options through command line
function D.SetHandler (info, value) -- {{{


    local target = D.db.global;

    if D.db.profile[info[#info]]~=nil then

        target = D.db.profile;

    elseif D.db.class[info[#info]]~=nil then

        target = D.db.class;

    end

    target[info[#info]] = value;

    if OptionsPostSetActions[info[#info]] then
        OptionsPostSetActions[info[#info]](value);
        D:Debug("PostAction executed");
    end

    if info["uiType"] == "cmd" then

        if value == true then
            value = L["OPT_CMD_ENABLED"];
        elseif value == false then
            value = L["OPT_CMD_DISBLED"];
        end

        D:Print(D:ColorText(D:GetOPtionPath(info), "FF00DD00"), "=>", D:ColorText(value, "FF3399EE"));
    end
end -- }}}

-- Option tree (GetStaticOptions / GetOptions) lives in Decursive_Options/Dcr_opt_tree.lua
-- and is loaded on demand. Defaults, GetHandler/SetHandler, and combat helpers stay here.

function D:GetV11OptionsTable ()
    -- v11 single-UI option model. Built only after Decursive_Options loads.
    if type(D._BuildOptionsTree) == "function" then
        return D._BuildOptionsTree()
    end
    return { type = "group", name = "Decursive", args = {} }
end

function D:ExportOptions ()
    -- Zhaohu v11 single-UI build: AceConfig/AceGUI are not loaded.
    -- The mature option definitions and handlers remain an internal model
    -- consumed directly by Modern/ZD_UI.lua.
    return true;
end



function D:GetCureTypeStatus (Type)
    return self:GetCureOrderTable()[Type];
end

local TypesToUName = {
    [DC.ENEMYMAGIC]     = "MAGICCHARMED",
    [DC.MAGIC]          = "MAGIC",
    [DC.CURSE]          = "CURSE",
    [DC.POISON]         = "POISON",
    [DC.DISEASE]        = "DISEASE",
    [DC.CHARMED]        = "CHARM",
    [DC.BLEED]          = "BLEED",
}

local CureCheckBoxes = false;
function D:SetCureCheckBoxNum (Type, checkBox)
    local cureOrders = self:GetCureOrderTable();
    -- add the priority in front of the name
    if (cureOrders[Type]) then
        local cureOrder = abs(cureOrders[Type])
        checkBox.name = D:ColorText(cureOrder, cureOrders[Type] > 0 and "FF00FF00" or "FF3030F0") .. " " .. L[TypesToUName[Type]];
    else
        checkBox.name = "  " .. L[TypesToUName[Type]];
    end

end

function D:GetCureOrderTable ()
    local activeSpec = GetSpecialization();
    local generalCureOrder = D.classprofile.CureOrder;

    if not activeSpec or activeSpec == 5 then
        --[==[
        --D:Debug("No active spec, returning general cure order table:", D:tAsString(generalCureOrder));
        ]==]
        return generalCureOrder;
    else
        local specCureOrder = "CureOrder-"..activeSpec;

        if not D.classprofile[specCureOrder] then
            D:Debug("Creating specific cureorder table ", specCureOrder, " for spec:", activeSpec);
            D.classprofile[specCureOrder] = {};
            self:tcopy(D.classprofile[specCureOrder], generalCureOrder);
        end

        --[==[
        --D:Debug("returning specific cure order table ", specCureOrder, " for spec:", activeSpec, "table:", D:tAsString(D.classprofile[specCureOrder]));
        ]==]
        return D.classprofile[specCureOrder];
    end
end

function D:CheckCureOrder ()

    D:Debug("Verifying CureOrder...");

    local TempTable = {};
    local AuthorizedKeys = {
        [DC.ENEMYMAGIC]   = 1,
        [DC.MAGIC]          = 2,
        [DC.CURSE]          = 3,
        [DC.POISON]         = 4,
        [DC.DISEASE]        = 5,
        [DC.CHARMED]        = 6,
        [DC.BLEED]          = 7,
    };
    local AuthorizedValues = {
        [false] = true; -- LOL Yes, it's TRUE that FALSE is an authorized value xD
        -- Other <0  values are used when there used to be a spell...
        [1]     = DC.ENEMYMAGIC,
        [-11]   = DC.ENEMYMAGIC,
        [2]     = DC.MAGIC,
        [-12]   = DC.MAGIC,
        [3]     = DC.CURSE,
        [-13]   = DC.CURSE,
        [4]     = DC.POISON,
        [-14]   = DC.POISON,
        [5]     = DC.DISEASE,
        [-15]   = DC.DISEASE,
        [6]     = DC.CHARMED,
        [-16]   = DC.CHARMED,
        [7]     = DC.BLEED,
        [-17]   = DC.BLEED,
    };
    local GivenValues = {};


    local cureOrder = self:GetCureOrderTable();
    -- add missing entries...
    for key, value in pairs(AuthorizedKeys) do
        if nil == cureOrder[key] then
            cureOrder[key] = D.defaults.class.CureOrder[key];
        end
    end

    -- Validate existing entries
    local WrongValue = 0;
    for key, value in pairs(cureOrder) do

        if (AuthorizedKeys[key]) then -- is this a correct type ?
            if (AuthorizedValues[value] and not GivenValues[value]) then -- is this value authorized and not already given?
                GivenValues[value] = true;

            elseif (value) then -- FALSE is the only value that can be given several times
                D:Debug("Incoherent value for (key, value, Duplicate?)", key, value, GivenValues[value]);

                cureOrder[key] = -20 - WrongValue; -- if the value was wrong or already given to another type
                WrongValue = WrongValue + 1;
            end
        else
            cureOrder[key] = nil; -- remove it from the table
        end
    end

end

function D:SetCureOrder (ToChange)


    local CureOrder = self:GetCureOrderTable();
    local tmpTable = {};
    D:Debug("SetCureOrder called for prio ", CureOrder[ToChange]);

    if (ToChange) then
        -- if there is a positive value, it means we want to disable this type, set it to false (see GetCureTypeStatus())
        if (D:GetCureTypeStatus(ToChange)) then
            CureOrder[ToChange] = false;
            D:Debug("SetCureOrder(): set to false");
        else -- else if there was no value (or a negative one), add this type at the end (see GetCureTypeStatus())
            CureOrder[ToChange] = 20; -- this will cause the spell to be added at the end
            D:Debug("SetCureOrder(): set to 20");
        end
    end

    local LostSpells = {}; -- an orphanage for the lost spells :'(
    local FoundSpell = 0;

    -- re-compute the position of each spell type
    for Type, Num in pairs (CureOrder) do

        -- if we have a spell or if we did not unchecked the checkbox (note the difference between "checked" and "not unchecked")
        if (D.Status.CuringSpells[Type] and CureOrder[Type]) then
            tmpTable[abs(CureOrder[Type])] = Type; -- CureOrder[Type] can have a <0 value if the spell was lost
            FoundSpell = FoundSpell + 1;
        elseif (CureOrder[Type]) then -- if we don't have a spell for this type
            --[==[
            D:Debug("SetCureOrder(): Adding lost spell", CureOrder[Type], Type)
            ]==]
            LostSpells[abs(CureOrder[Type])] = Type;  -- save the position
        end
    end

   -- take care of the lost spells here
   -- Sort the lost spells so that they can be read in the correct order
   LostSpells = D:tSortUsingKeys(LostSpells);

   -- Place the lost spells after the found ones but with <0 values so they
   -- can be readded later using their former priorities
   local AvailableSpot = (FoundSpell + 10 + 1) * -1; -- we add 10 so that they'll be re-added after any not-lost spell...


   -- if the user requested this change, then we update the saved data else we
   -- leave it as it is so that it can go back to the previous state if the old
   -- conditions are met again
   local newCureOrder = {}
   if (ToChange) then
       newCureOrder = CureOrder
   else
        D:tcopy(newCureOrder, CureOrder)
   end

   -- D:PrintLiteral(LostSpells);
   for FormerPrio, Type in ipairs(LostSpells) do
       newCureOrder[Type] = AvailableSpot
        --[==[
        D:Debug("SetCureOrder(): old lost spell prio:", CureOrder[Type], Type)
        ]==]
       AvailableSpot = AvailableSpot - 1;
   end

    -- we sort the tables
    tmpTable = D:tSortUsingKeys(tmpTable);

    -- apply the new priority to the types we can handle, leave their negative
    -- value to the other
    for Num, Type in ipairs (tmpTable) do
        newCureOrder[Type] = Num;
    end

    --[==[
    D:Debug("SetCureOrder(): updated cure order table:", D:tAsString(newCureOrder), ToChange and "(saved)" or "(unsaved)" );
    ]==]


    -- create / update the ReversedCureOrder table (prio => type, ..., )
    D.Status.ReversedCureOrder = D:tReverse(newCureOrder);

    --[==[
    D:Debug("SetCureOrder(): ReversedCureOrder table:", D:tAsString(D.Status.ReversedCureOrder));
    ]==]


    -- Create spell priority table
    D.Status.CuringSpellsPrio = {};

    -- some shortcuts
    local CuringSpellsPrio = D.Status.CuringSpellsPrio;
    local ReversedCureOrder = D.Status.ReversedCureOrder;
    local CuringSpells  = D.Status.CuringSpells;

    local DebuffType;
    -- set the priority for each spell, Micro frames will use this to determine which button to map
    local affected = 1;
    for i=1,7 do
        DebuffType = ReversedCureOrder[i]; -- there is no gap between indexes
        if (DebuffType and not CuringSpellsPrio[ CuringSpells[DebuffType] ] ) then
            CuringSpellsPrio[ CuringSpells[DebuffType] ] = affected;
            affected = affected + 1;
        end
    end

    --[==[
    D:Debug("SetCureOrder(): updated CuringSpells table:", D:tAsString(CuringSpells));
    ]==]


    if DC.MN then
        -- we need to set the color of the new MN curve thingy:
        -- one color per spell, so we need to create a table type -> color
        local mfc = D.profile.MF_colors
        local dsc = D.Status.dsCurve
        local dtToBT = DC.DTtoBT

        local typeToColor = {}
        for Spell, Prio in pairs(D.Status.CuringSpellsPrio) do -- for each configured spell
            for typeprio, afflictionType in ipairs(D.Status.ReversedCureOrder) do
                if D.Status.CuringSpells[afflictionType] == Spell then -- handling an affliction type
                    typeToColor[afflictionType] = D:NumToColorMixin(mfc[Prio]) -- register the type to color mapping
                end
            end
        end

        --[==[
        --D:Debug("SetCureOrder(): typeToColor table:", D:tAsString(typeToColor));
        ]==]


        -- update our curve
        dsc:ClearPoints()
        dsc:AddPoint(0, D:NumToColorMixin(mfc[DC.NORMAL]))
        for affType, cm in pairs(typeToColor) do
            --[==[
            D:Debug("Adding point: ", affType, dtToBT[affType], cm)
            ]==]
            dsc:AddPoint(dtToBT[affType], cm)
        end

        --[==[
        --D:Debug("SetCureOrder(): dsCurve points:", dsc:GetPoints());
        ]==]

    end

    -- Set the spells shortcut (former decurse key)
    D:AddDelayedFunctionCall(
        "UpdateMacro", self.UpdateMacro,  -- dangerous call many add-ons hook APIs call there this should be delayed
        self)

    D:Debug("Spell changed");
    D.Status.SpellsChanged = GetTime();
    D.Status.delayedDebuffReportDisabled = true;
    if self.db.global.MFScanEverybodyTimer == 0 or self.db.global.MFScanEverybodyTimer > 1 then
        D:Debug("ScanEveryBody delayed call scheduled by SetCureOrder")
        D:ScheduleDelayedCall("scanEverybodyAfterSpellChanged", D.ScanEveryBody, 1, D)
    end

    -- If no spell is selected or none is available set Decursive icon to off
    if FoundSpell ~= 0 then
        D:Debug("icon changed to ON");
        D:SetIcon(DC.IconON);
    else
        D:Debug("icon changed to OFF");
        D:SetIcon(DC.IconOFF);
    end

    self:SetMacrosPerPrioTable("mouseover");

end

function D:ShowHideDebuffsFrame ()

    if InCombatLockdown() or not D.DcrFullyInitialized or D.Status.TestLayout then
        return
    end

    D.profile.ShowDebuffsFrame = not D.profile.ShowDebuffsFrame;

    if (D.MFContainer:IsVisible()) then
        D.MFContainer:Hide();
        D.profile.ShowDebuffsFrame = false;
    else
        D.MicroUnitF:Show();
    end

    if (not D.profile.ShowDebuffsFrame) then
        D:CancelDelayedCall("Dcr_MUFupdate");
        D:CancelDelayedCall("Dcr_ScanEverybody");
        if D.profile.HideLiveList then
            D.Status.SoundPlayed = false;
            D:Debug("ShowHideDebuffsFrame(): sound re-enabled");
        end
    else
        D:ScheduleRepeatedCall("Dcr_MUFupdate", D.DebuffsFrame_Update, D.db.global.DebuffsFrameRefreshRate, D);

        if D.db.global.MFScanEverybodyTimer > 0 then
            self:ScheduleRepeatedCall("Dcr_ScanEverybody", D.ScanEveryBody, D.db.global.MFScanEverybodyTimer, D);
        end

        D.MicroUnitF:Force_FullUpdate();
    end

    -- set Icon
    if not D.Status.HasSpell or D.profile.HideLiveList and not D.profile.ShowDebuffsFrame then
        D:SetIcon(DC.IconOFF);
    else
        D:SetIcon(DC.IconON);
    end

end

function D:ShowHideTextAnchor() --{{{
    if (DecursiveAnchor:IsVisible()) then
        DecursiveAnchor:Hide();
    else
        DecursiveAnchor:Show();
    end
end --}}}

function D:ChangeTextFrameDirection(bottom) --{{{
    local button = DecursiveAnchorDirection;
    if (bottom) then
        DecursiveTextFrame:SetInsertMode("BOTTOM");
        button:SetText("v");
    else
        DecursiveTextFrame:SetInsertMode("TOP");
        button:SetText("^");
    end
end --}}}

do -- All this block predates Ace3, it could be recoded in a much more effecicent and cleaner way now (memory POV) thanks to the "info" table given to all callbacks in Ace3.
   -- A good example would be the code creating the MUF color configuration menu or the click assigment settings right after this block.

    local DebuffsSkipList, DefaultDebuffsSkipList, skipByClass, DebuffAlwaysSkipList, DefaultSkipByClass;

    local spacer = function(num) return { name="",type="header", order = 100 + num } end;

    local error = function (...) D:ColorPrint(1, 0, 0, ...); end;

    local RemoveFunc = function (handler)


        if DefaultDebuffsSkipList[handler["Debuff"]] then
            D.profile.DebuffsSkipList[handler["Debuff"]] = false;
        else
            D.profile.DebuffsSkipList[handler["Debuff"]] = nil;
        end
        D:Debug("Removing ", handler["Debuff"], D.profile.DebuffsSkipList[handler["Debuff"]], DefaultDebuffsSkipList[handler["Debuff"]]);

        skipByClass  = D.profile.skipByClass;
        for class, debuffs in pairs (skipByClass) do
            skipByClass[class][handler["Debuff"]] = nil;
        end

        D.profile.DebuffAlwaysSkipList[handler["Debuff"]] = nil; -- remove it from the table

        D:Debug("%s removed!", handler["Debuff"]);

    end

    local AddToAlwaysSkippFunc = function (handler, v)
        DebuffAlwaysSkipList[handler["Debuff"]] = v;
    end

    local ResetFunc = function (handler)
        local DebuffName = handler["Debuff"];

        D:Debug("Resetting '%s'...", handler["Debuff"]);

        skipByClass  = D.profile.skipByClass;
        for Classe, Debuffs in pairs(skipByClass) do
            if (DefaultSkipByClass[Classe][DebuffName]) then
                skipByClass[Classe][DebuffName] = true;
            else
                skipByClass[Classe][DebuffName] = nil; -- Removes it
            end
        end
    end

    local function ClassValues(DebuffName)
        local values = {};

        for i, class in pairs (DC.ClassNumToUName) do
            if LC[class] ~= class then -- skip non existant classes in WoW classic
                values[i] = D:ColorText( LC[class], "FF"..DC.HexClassColor[class]) ..
                (DefaultSkipByClass[class][DebuffName] and D:ColorText("  *", "FFFFAA00") or "");
            end
        end

        --D:Debug(unpack (values));
        return values;

    end

    local function DebuffSubmenu (DebuffName, num, spellID)
        local classes = {};

        classes["header1"] = {
            type = "description",
            name = (L["OPT_FILTEROUTCLASSES_FOR_X"]):format(D:ColorText(DebuffName, "FF77CC33")),
            order = num,
        }
        num = num + 1;

        classes["header2"] = {
            type = "description",
            name = function ()
                local spellDesc = GetSpellDescription(spellID);
                local desc;

                --D:Debug("Dealing with spell description for ", spellID);
                if spellID ~= 0 then
                    if spellDesc == "" or not spellDesc then
                        if not C_Spell.IsSpellDataCached(spellID) then
                            C_Spell.RequestLoadSpellData(spellID);
                            desc = L["OPT_SPELL_DESCRIPTION_LOADING"];
                        else
                            desc = L["OPT_SPELL_DESCRIPTION_UNAVAILABLE"];
                        end
                    else
                        desc = spellDesc;
                    end
                else
                    desc = L["OPT_SPELLID_MISSING_READD"];
                end

                return "\n" .. D:ColorText(desc, "FFD09050");
            end,
            order = num,
        }
        num = num + 1;

        skipByClass = D.profile.skipByClass;
         classes[DebuffName] = {
             type = "multiselect",
             name = "",
             --desc = "test desc",
             values = ClassValues(DebuffName),
             order = num,
             get = "get",
             set = "set",

             handler = {
                ["Debuff"]=DebuffName,
                ["get"] = function  (handler, info, Classnum)
                    return skipByClass[DC.ClassNumToUName[Classnum]][handler["Debuff"]];
                end,
                ["set"] = function  (handler, info, Classnum, state)
                    skipByClass[DC.ClassNumToUName[Classnum]][string.trim(handler["Debuff"])] = state;
                end
            };

         };

        --classes["spacer1"] = spacer(num);

        num = num + 1;

        classes["PermIgnore"] = {
            type = "toggle",
            name = D:ColorText(L["OPT_ALWAYSIGNORE"], "FFFF9900"),
            desc = str_format(L["OPT_ALWAYSIGNORE_DESC"], DebuffName),
            handler = {
                ["Debuff"] = DebuffName,
                ["get"] = function (handler)
                    return DebuffAlwaysSkipList[handler["Debuff"]];
                end,
                ["set"] = function (handler,info,v) AddToAlwaysSkippFunc(handler,v) end,
            },
            get = "get",
            set = "set",
            order = 100 + num;

        };

        num = num + 1;

        --classes["spacer1p5"] = spacer(num);

        num = num + 1;

        classes["remove"] = {
            type = "execute",
            name = D:ColorText(L["OPT_REMOVETHISDEBUFF"], "FFFF0000"),
            desc = str_format(L["OPT_REMOVETHISDEBUFF_DESC"], DebuffName),
            handler = {
                ["Debuff"] = DebuffName,
                ["remove"] = RemoveFunc,
            },
            confirm = true,
            func = "remove",
            order = 100 + num,

        };

        num = num + 1;

        --classes["spacer2"] = spacer(num);

        num = num + 1;

        local resetDisabled = false;

        if not DefaultDebuffsSkipList[DebuffName] then
            resetDisabled = true;
        end

        classes["reset"] = {
            type = "execute",
            -- the two statements below are like (()?:) in C
            name = not resetDisabled and D:ColorText(L["OPT_RESETDEBUFF"], "FF11FF00") or L["OPT_RESETDEBUFF"],
            desc = not resetDisabled and str_format(L["OPT_RESETDTDCRDEFAULT"], DebuffName) or L["OPT_USERDEBUFF"],
            handler = {
                ["Debuff"] = DebuffName,
                ["reset"] = ResetFunc,
            },
            func = "reset";
            disabled = resetDisabled,
            order = 100 + num;

        };

        num = num + 1;

        --classes["spacer3"] = spacer(num);

        return classes;
    end



    --Entry Templates
    local function DebuffEntryGroup (DebuffName, num, spellID)
        local IsADefault = DefaultDebuffsSkipList[DebuffName] and true;
        return {
            type = "group",
            name = IsADefault and D:ColorText(DebuffName, "FFFFFFFF") or D:ColorText(DebuffName, "FF99FFFF"),
            desc = L["OPT_DEBUFFENTRY_DESC"],
            order = num,
            args = DebuffSubmenu(DebuffName, num, spellID),
        }
    end

    local AddFunc = function (spellID)
        local newDebuff = GetSpellName(spellID);
        if newDebuff then
            DebuffsSkipList[newDebuff] = spellID;
            D:Debug("'%s' added to debuff skip list", newDebuff, spellID);
        elseif not newDebuff then
            error("Can't add debuff, invalid spellID:", spellID);
        end
    end


    local ReAddDefaultsDebuffs = function ()

        for Debuff, spellID in pairs(DefaultDebuffsSkipList) do

            if not DebuffsSkipList[Debuff] then

                DebuffsSkipList[Debuff] = spellID;

                ResetFunc({["Debuff"] = Debuff});

            end
        end

    end

    local CheckDefaultsPresence = function ()
        for Debuff, _ in pairs(DefaultDebuffsSkipList) do
            if not DebuffsSkipList[Debuff] then
                return false;
            end
        end
        return true;
    end

    local DebuffHistTable = {};
    local First = "";

    local GetHistoryDebuff = function ()
        local coloredDebuffName, exists, spellID, index;

        for index=1, DC.DebuffHistoryLength do
            coloredDebuffName, spellID, exists = D:Debuff_History_Get (index, true);

            if not exists or index == 1 and coloredDebuffName == First then
                break;
            end

            if index == 1 then
                First = coloredDebuffName;
            end

            DebuffHistTable[index] = {coloredDebuffName, spellID};
            index = index + 1;
        end

        return DebuffHistTable;
    end

    local updateFilteredDebuffNames_ONCE;
    local noop = function() D:Debug("no op"); end;
    updateFilteredDebuffNames_ONCE = function ()
        local debuffSkipListCopy = {};
        local realName;
        D:tcopy(debuffSkipListCopy, DebuffsSkipList);
        for debuffName, spellID in pairs(debuffSkipListCopy) do
            if spellID ~= false then -- leave removed default spells
                if spellID ~= 0 and not C_Spell.DoesSpellExist(spellID) then
                    RemoveFunc({["Debuff"] = debuffName});
                else
                    realName = GetSpellName(spellID);
                    if realName and realName ~= debuffName then
                        DebuffsSkipList[debuffName] = nil;
                        DebuffsSkipList[realName] = spellID;
                        D:Debug(debuffName, "replaced by", realName, "for DebuffsSkipList");

                        if DebuffAlwaysSkipList[debuffName] then
                            DebuffAlwaysSkipList[debuffName] = nil;
                            DebuffAlwaysSkipList[realName] = true;
                            D:Debug(debuffName, "replaced by", realName, "for DebuffAlwaysSkipList");
                        end

                        for class, debuffs in pairs(skipByClass) do
                            if debuffs[debuffName] then
                                debuffs[debuffName] = nil;
                                debuffs[realName] = true;
                                D:Debug(debuffName, "replaced by", realName, "for class:", class);
                            end
                        end

                        D:Print((L["OPT_FILTERED_DEBUFF_RENAMED"]):format(debuffName, realName, spellID));
                    elseif not realName then
                        D:Debug(realName, "no name for spell ID", spellID, GetSpellName(spellID))
                    end
                end
            end
        end
        debuffSkipListCopy = nil;
        if realName then
            updateFilteredDebuffNames_ONCE = noop;
        end
    end

    function D:CreateFiltersMenu()
        DebuffsSkipList             = D.profile.DebuffsSkipList;
        DefaultDebuffsSkipList      = D.defaults.profile.DebuffsSkipList;

        skipByClass                 = D.profile.skipByClass;
        DebuffAlwaysSkipList        = D.profile.DebuffAlwaysSkipList;
        DefaultSkipByClass          = D.defaults.profile.skipByClass;

        local DebuffsSubMenu = {};
        local num = 1;


        DebuffsSubMenu["debuffHolder"] = {
            name = L["OPT_DEBUFFFILTER"],
            type = "group",
            order = 200,
            args = {}
        }

       updateFilteredDebuffNames_ONCE();

        for debuffName, spellID in pairs(DebuffsSkipList) do
            if false ~= spellID then
                DebuffsSubMenu.debuffHolder.args[str_gsub(debuffName, " ", "")] = DebuffEntryGroup(debuffName, num, spellID);
                num = num + 1;
            end
        end

        DebuffsSubMenu["description"] = {
            type = "description",
            name = L["OPT_DEBUFFFILTER_DESC"],
            order = 0,
        };
        num = num + 1;

        DebuffsSubMenu["add"] = {
            type = "input",
            name = D:ColorText(L["OPT_ADDDEBUFF"], "FFFF3300"),
            desc = L["OPT_ADDDEBUFF_DESC"],
            usage = L["OPT_ADDDEBUFF_USAGE"],
            get = false,
            set = function(info,v) AddFunc(tonumber(v)) end,
            validate = function(info, v)

                if tonumber(v) and C_Spell.DoesSpellExist(tonumber(v)) then
                    return 0;
                else
                    return error("'", v, "'", L["OPT_ISNOTVALID_SPELLID"]);
                end
            end,
            order = 100 + num,
        };

        num = num + 1;

        DebuffsSubMenu["addFromHist"] = {
            type = "select",
            name = L["OPT_ADDDEBUFFFHIST"], --"Add from Debuff history",
            desc = L["OPT_ADDDEBUFFFHIST_DESC"], --"Add a recently dispelled debuff",
            disabled = function () GetHistoryDebuff(); return (#DebuffHistTable == 0) end,
            values = function () return D:tMap(GetHistoryDebuff(), function (debuff) return debuff[1] end) end;
            get = function() GetHistoryDebuff(); return false; end,
            set = function(info,value)
                local debuffName, spellID = unpack(GetHistoryDebuff()[value]);
                AddFunc(spellID ~= 0 and spellID or (D:RemoveColor(debuffName) == "Test item" and 1243 or 0));
            end,
            order = 100 + num,
        };


        local ReaddIsDisabled = CheckDefaultsPresence();
        num = num + 1;
        DebuffsSubMenu["ReAddDefaults"] = {
            type = "execute",
            name = not ReaddIsDisabled and D:ColorText(L["OPT_READDDEFAULTSD"], "FFA75728") or L["OPT_READDDEFAULTSD"],
            desc = not ReaddIsDisabled and L["OPT_READDDEFAULTSD_DESC1"]
            or L["OPT_READDDEFAULTSD_DESC2"],
            func = ReAddDefaultsDebuffs,
            disabled = CheckDefaultsPresence;
            order = 100 + num,
        };

        return DebuffsSubMenu;
    end
end

do

    local tonumber = _G.tonumber;
    local L_MF_colors = {};

    local function GetNameAndDesc (ColorReason) -- {{{
        local name, desc;

        L_MF_colors = D.profile.MF_colors;

        if (type(ColorReason) == "number" and ColorReason <= 7) then

            name = D:ColorText(  ("%s (%s)"):format( L["OPT_CURE_PRIORITY_NUM"]:format(ColorReason), DC.MouseButtonsReadable[D.db.global.MouseButtons[ColorReason] ])  , D:NumToHexColor(L_MF_colors[ColorReason]));
            desc = (L["COLORALERT"]):format(DC.MouseButtonsReadable[D.db.global.MouseButtons[ColorReason] ]);

        elseif (type(ColorReason) == "number")      then
            local Text = "";

            if (ColorReason == DC.NORMAL)           then
                Text =  L["NORMAL"];

            elseif (ColorReason == DC.ABSENT)       then
                Text =  L["MISSINGUNIT"];

            elseif (ColorReason == DC.FAR)          then
                Text =  L["TOOFAR"];

            elseif (ColorReason == DC.STEALTHED)    then
                Text =  L["STEALTHED"];

            elseif (ColorReason == DC.BLACKLISTED)  then
                Text =  L["BLACKLISTED"];

            elseif (ColorReason == DC.CHARMED_STATUS) then
                Text =  L["CHARM"];
            end

            name = ("%s %s"):format(L["UNITSTATUS"], D:ColorText(Text, D:NumToHexColor(L_MF_colors[ColorReason])) );
            desc = (L["COLORSTATUS"]):format(Text);

        elseif (type(ColorReason) == "string") then


            if ColorReason == "COLORCHRONOS" then
                name = L[ColorReason];
                desc = L["COLORCHRONOS_DESC"];
            else
                name = "Additional color";
                desc = "Configure this color in the Zhaohu v11 interface.";
                --D:Debug("ColorReason:", ColorReason);
            end
        end

        return {name, desc};
    end -- }}}

    local retrieveColorReason = function(info)
        local ColorReason = str_sub(info[#info], 2);

        if tonumber(ColorReason) then
            return tonumber(ColorReason);
        else
            return ColorReason;
        end
    end

    local GetName = function (info)
        --D:Debug(GetNameAndDesc(retrieveColorReason(info))[1]);
        return GetNameAndDesc(retrieveColorReason(info))[1];
    end

    local GetDesc = function (info)
        return GetNameAndDesc(retrieveColorReason(info))[2];
    end

    local GetOrder = function (info)
        local ColorReason = retrieveColorReason(info);
        return 100 + (type(ColorReason) == "number" and ColorReason * 2 or 4096);
    end

    local function GetColor (info)
        return unpack(D.profile.MF_colors[retrieveColorReason(info)]);
    end

    local function SetColor (info, r, g, b, a)

        local ColorReason = retrieveColorReason(info);

        D.profile.MF_colors[ColorReason] = {r, g, b, (a and a or 1)};
        D.MicroUnitF:RegisterMUFcolors();
        L_MF_colors = D.profile.MF_colors;

        D.MicroUnitF:Delayed_Force_FullUpdate();

        D:Debug("MUF color setting changed:", ColorReason);
    end

    local ColorPicker = {
        type = "color",
        name = GetName,
        desc = GetDesc,
        hasAlpha = true,
        order = GetOrder,

        get = GetColor,
        set = SetColor,
    };

    function D:CreateDropDownMUFcolorsMenu(MUFsColors_args)
        L_MF_colors = D.profile.MF_colors;
        -- /dump  LibStub("AceAddon-3.0"):GetAddon("Decursive").db.profile.MF_colors
        for ColorReason, Color in pairs(L_MF_colors) do

            if not L_MF_colors[ColorReason][4] then
                D.profile.MF_colors[ColorReason][4] = 1;
            end

            -- add a separator for the different color typs when necessary.
            if (type(ColorReason) == "number" and ColorReason == DC.NORMAL) or (type(ColorReason) == "string" and ColorReason == "COLORCHRONOS") then
                MUFsColors_args["S" .. ColorReason] = {
                    type = "header",
                    name = "",
                    order = function (info) return GetOrder(info) - 1 end,
                }
                --D:Debug("Created space ", "Space" .. ColorReason, "at ", MUFsColors_args["S" .. ColorReason].order);
            end


            MUFsColors_args["c"..ColorReason] = ColorPicker;

        end
    end
end
do
    local infoPrefix = "cAffliction_";
    local orderStart = 4096 + 200;

    local function retrieveAffTypeFromInfo(info)
        return tonumber((info[#info]):sub(#infoPrefix + 1));
    end

    local function GetAffTypeName(info)
        return L[DC.TypeToLocalizableTypeNames[retrieveAffTypeFromInfo(info)]];
    end

    local function GetAffTypeDesc(info)
        local affName = L[DC.TypeToLocalizableTypeNames[retrieveAffTypeFromInfo(info)]];
        return L["OPT_SETAFFTYPECOLOR_DESC"]:format(affName);
    end

    local function GetAffTypeOrder(info)
        return orderStart + retrieveAffTypeFromInfo(info);
    end

    local function GetAffTypeColor(info)
        return unpack( D:HexColorToNum(D.profile.TypeColors[retrieveAffTypeFromInfo(info)]));
    end

    local function SetAffTypeColor(info, r, g, b, a)
        local affType = retrieveAffTypeFromInfo(info);

        D.profile.TypeColors[affType] = D:NumToHexColor({r, g, b, (a and a or 1)});
        D:Debug("Affliction type color ", affType, "set to", D.profile.TypeColors[affType]);
    end

    local afflictionColorPicker = {
        type = "color",
        name = GetAffTypeName,
        desc = GetAffTypeDesc,
        hasAlpha = true,
        order = GetAffTypeOrder,

        get = GetAffTypeColor,
        set = SetAffTypeColor,
    };

    function D:CreateAfflictionColorsMenu(MUFsColors_args)
        local TypeColors = D.profile.TypeColors;

        MUFsColors_args[infoPrefix.."0"] = {
            type = "header",
            name = "",
            order = GetAffTypeOrder,
        }

        for afflictionType, Color in pairs(TypeColors) do
            if afflictionType ~= DC.NOTYPE then
                MUFsColors_args[infoPrefix..afflictionType] = afflictionColorPicker;
            end
        end
    end

end

-- Modifiers order choosing dynamic menu creation
do

    local orderStart = 152;
    local tonumber = _G.tonumber;

    local TempTable = {};
    local i = 1;

    local function retrieveKeyComboNum (info)
        return tonumber(str_sub(info[#info], 9));
        -- #"KeyCombo" == 8
    end

    local function GetValues (info) -- {{{

        if retrieveKeyComboNum (info) == 1 then
            table.wipe(TempTable);

            for i=1, #D.db.global.MouseButtons do
                TempTable[i] = D:ColorText(DC.MouseButtonsReadable[D.db.global.MouseButtons[i]],
                        i < 7 and D:NumToHexColor(D.profile.MF_colors[i]) -- defined priorities
                        or (i >= #D.db.global.MouseButtons - 1 and "FFFFFFFF" -- target and focus
                        or "FFBBBBBB") -- other unused buttons
                    );
            end
        end

        return TempTable;
    end -- }}}

    local function GetOrder (info)
        return orderStart + retrieveKeyComboNum (info);
    end

    local OptionPrototype = {
        -- {{{
        type = "select",
        name = function (info)
            if not retrieveKeyComboNum (info) then return "" end -- needed because when called by command line, info is set to the parent

            if retrieveKeyComboNum (info) < #D.db.global.MouseButtons - 1 then
                return D:ColorText(L["OPT_CURE_PRIORITY_NUM"]:format(retrieveKeyComboNum (info)),  D:NumToHexColor(D.profile.MF_colors[retrieveKeyComboNum (info)]));
            elseif  retrieveKeyComboNum (info) == #D.db.global.MouseButtons - 1 then
                return L["OPT_MUFTARGETBUTTON"];
            else
                return L["OPT_MUFFOCUSBUTTON"];
            end
        end,
        values = GetValues,
        order = GetOrder,
        get = function (info)
            return retrieveKeyComboNum (info);
        end,
        set = function (info, value)

            local ThisKeyComboNum = retrieveKeyComboNum (info);


            if value ~= ThisKeyComboNum then -- we would destroy the table

                D:tSwap(D.db.global.MouseButtons, ThisKeyComboNum, value);

                -- force all MUFs to update their attributes
                D.Status.SpellsChanged = GetTime();
            end
        end,
        style = "dropdown",
        -- }}}
    };

    function D:CreateModifierOptionMenu ()
        local key_Combos_Select = {
            -- {{{
            ClicksAdssigmentsDesc = {
                type = "description",
                name = L["OPT_MUFMOUSEBUTTONS_DESC"],
                order = 151,
            },
            ResetClicksAdssigments = {
                type = "execute",
                confirm = true,
                name = L["OPT_RESETMUFMOUSEBUTTONS"],
                desc = L["OPT_RESETMUFMOUSEBUTTONS_DESC"],
                func = function ()
                    table.wipe(D.db.global.MouseButtons);
                    D:tcopy(D.db.global.MouseButtons, D.defaults.global.MouseButtons);
                    -- force all MUFs to update their attributes
                    D.Status.SpellsChanged = GetTime();
                end,
                order = -1,
            },
            -- }}}
        };

        for i = 1, 7 do
            key_Combos_Select["KeyCombo" .. i] = OptionPrototype;
        end

        -- create choice munu for targeting (it's always the last but one available button)
        key_Combos_Select["KeyCombo" .. #D.db.global.MouseButtons - 1] = OptionPrototype;
        -- create choice munu for focusing (it's always the last available button)
        key_Combos_Select["KeyCombo" .. #D.db.global.MouseButtons] = OptionPrototype;

        return key_Combos_Select;
    end

end

do

    local t_insert      = _G.table.insert;
    local IsSpellKnown  = nil; -- use D:isSpellReady instead

    local order = 160;

    local function isSpellUSable (spellID)

        local spell = D.classprofile.UserSpells[spellID];

        if not spell.IsItem and spellID > 0 then
            return D:isSpellReady(spellID, spell.Pet)
        else
            return D:isItemUsable(spellID * -1)
        end
    end


    local function GetColoredName(spellID)
        local spell = D.classprofile.UserSpells[spellID];

        if not spell then
            D:AddDebugText('GetColoredName(): invalid spellID:', spellID);
            return tostring(spellID);
        end

        local name = D.GetSpellOrItemInfo(spellID) or "WTF!?!";
        local color = 'FFFFFFFF';

        if spell.Disabled then
            color = 'FFAA0000';
        elseif not D.Status.CuringSpellsPrio[name] then
            color = 'FF909090';
        else
            color = 'FF00D000';
        end

        if not isSpellUSable(spellID) then
            name = ("(%s) %s"):format(L["OPT_CUSTOM_SPELL_UNAVAILABLE"], name);
            color = 'FF606060';
        end

        return D:ColorText(name .. ((spell and spell.MacroText) and "|cFFFF0000*|r" or ""), color);

    end

    local TypeOption = {
        type = "toggle",
        name = function(info) return L[info[#info]] end,
        get = function(info)
            return D:tcheckforval(D.classprofile.UserSpells[TN(info[#info-2])].Types,  DC.LocalizableTypeNamesToTypes[info[#info]])
        end,
        set = function(info, v)
            local spellTableTypes = D.classprofile.UserSpells[TN(info[#info-2])].Types
            local curetype = DC.LocalizableTypeNamesToTypes[info[#info]]
            D:Debug("TypeOption: checkingtable named:", info[#info-2], "for", info[#info], "CureType:", curetype);

            if v and not D:tcheckforval(spellTableTypes, curetype) then
                t_insert(spellTableTypes, curetype)
            elseif not v then
                D:tremovebyval(spellTableTypes, curetype);
                -- also clear the unit filtering settings if it exists
                if D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering then
                    D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering[DC.LocalizableTypeNamesToTypes[info[#info]]] = nil;
                end
            end
            if not D.classprofile.UserSpells[TN(info[#info-2])].Disabled and isSpellUSable(TN(info[#info-2])) then
                D:ScheduleDelayedCall("Dcr_Delayed_Configure", D.Configure, 2, D);
            end
        end,
        disabled = function (info) -- disable types edition if an enhancement is active (default types are not used in that case)
            if D.classprofile.UserSpells[TN(info[#info-2])] and D.classprofile.UserSpells[TN(info[#info-2])].EnhancedByCheck then
                return D.classprofile.UserSpells[TN(info[#info-2])].EnhancedByCheck();
            end

            --if DC.SpellsToUse[TN(info[#info-2])] and D:tcheckforval(DC.SpellsToUse[TN(info[#info-2])].Types, DC.LocalizableTypeNamesToTypes[info[#info]]) then
            --    return true;
            --end

            return false;
        end,
        order = function() return order; end,
    }

    local typeUnitFilteringOption = {
        type = 'select',
        style = "dropdown",
        name = function(info) return L[info[#info]] end,
        desc = L["OPT_CUSTOM_SPELL_UNIT_FILTER_DESC"],
        values = {[0] = L["OPT_CUSTOM_SPELL_UNIT_FILTER_NONE"], [1] = L["OPT_CUSTOM_SPELL_UNIT_FILTER_PLAYER"], [2] = L["OPT_CUSTOM_SPELL_UNIT_FILTER_NONPLAYER"]},
        order = function() return order; end,

        hidden = function (info)
            -- hide the option when the type is not enabled for this spell
            return not D:tcheckforval(D.classprofile.UserSpells[TN(info[#info-2])].Types,  DC.LocalizableTypeNamesToTypes[info[#info]])
        end,

        get = function(info)
            if not D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering
                or not D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering[DC.LocalizableTypeNamesToTypes[info[#info]]] then
                return 0;
            else
                return D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering[DC.LocalizableTypeNamesToTypes[info[#info]]];
            end
        end,
        set = function(info, v)
            if not D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering then
                D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering = {};
            end

            D.classprofile.UserSpells[TN(info[#info-2])].UnitFiltering[DC.LocalizableTypeNamesToTypes[info[#info]]] = v ~= 0 and v or nil;

            if not D.classprofile.UserSpells[TN(info[#info-2])].Disabled and isSpellUSable(TN(info[#info-2])) then
                D:ScheduleDelayedCall("Dcr_Delayed_Configure", D.Configure, 2, D);
            end
        end,

    }

    local SpellSubOptions = {
        type = 'group',
        name = function(info) return GetColoredName(TN(info[#info])) end,
        desc = function(info)
            if DC.SpellsToUse[TN(info[#info])] then
                return L["OPT_CUSTOM_SPELL_IS_DEFAULT"];
            end
            return "";
        end,
        order = function() return order; end,
        args = {
            -- an enable checkbox
            header = {
                type = 'header',
                name = function (info) return ("%s  (id: %d)"):format(GetColoredName(TN(info[#info - 1])), TN(info[#info - 1])); end,
                order = 0,
            },
            enable = {
                type = "toggle",
                name = L["OPT_ENABLE_A_CUSTOM_SPELL"],
                set = function(info,v)
                    D.classprofile.UserSpells[TN(info[#info-1])].Disabled = not v;
                    if v and DC.SpellsToUse[TN(info[#info-1])] then
                        D:Configure();
                        return;
                    end

                    if isSpellUSable(TN(info[#info-1])) then
                        D:ReConfigure();
                    end
                end,
                get = function(info,v)
                    return not D.classprofile.UserSpells[TN(info[#info-1])].Disabled;
                end,
                order = 100
            },
            isPet = {
                type = "toggle",
                name = L["OPT_CUSTOM_SPELL_ISPET"],
                desc = L["OPT_CUSTOM_SPELL_ISPET_DESC"];
                set = function(info,v)

                    D.classprofile.UserSpells[TN(info[#info-1])].Pet = v;

                    --if isSpellUSable(TN(info[#info-1])) then
                    D:ScheduleDelayedCall("Dcr_Delayed_Configure", D.Configure, 2, D);
                    --end
                end,
                get = function(info,v)
                    return D.classprofile.UserSpells[TN(info[#info-1])].Pet;
                end,
                hidden = function (info) return D.classprofile.UserSpells[TN(info[#info-1])].IsItem end,
                order = 105
            },
            cureTypes = {
                type = 'group',
                name = L["OPT_CUSTOM_SPELL_CURE_TYPES"],
                order = 105,
                inline = true,

                args={},
                order = 106
            },
            UnitFiltering = {
                type = 'group',
                name = L["OPT_CUSTOM_SPELL_UNIT_FILTER"],
                order = 107,
                inline = true,

                args={},
                order = 107
            },
            priority = {
                type = 'range',
                name = L["OPT_CUSTOM_SPELL_PRIORITY"],
                desc = L["OPT_CUSTOM_SPELL_PRIORITY_DESC"],
                get = function (info) return D.classprofile.UserSpells[TN(info[#info-1])].Better end,
                set = function (info, v)
                    D.classprofile.UserSpells[TN(info[#info-1])].Better = v;
                    if not D.classprofile.UserSpells[TN(info[#info-1])].Disabled then
                        D:ScheduleDelayedCall("Dcr_Delayed_Configure", D.Configure, 2, D);
                    end
                end,
                min = -10,
                max = 30,
                step = 1,
                order = 110,
            },


            MacroEdition = {
                type = 'input',
                name = L["OPT_CUSTOM_SPELL_MACRO_TEXT"],
                usage = L["OPT_CUSTOM_SPELL_MACRO_TEXT_DESC"],
                multiline = true,
                width = 'full',
                hidden = function(info,v) return not D.classprofile.UserSpells[TN(info[#info-1])].MacroText end,

                get = function(info,v)
                    return D.classprofile.UserSpells[TN(info[#info-1])].MacroText;
                end,

                set = function (info,v)
                    if v:find("UNITID") and (v:gsub("UNITID", "PARTYPET5")):len() < 256 then
                        D.classprofile.UserSpells[TN(info[#info-1])].MacroText = v;

                        if D.Status.FoundSpells[D.GetSpellOrItemInfo(TN(info[#info - 1]))] then
                            D.Status.FoundSpells[D.GetSpellOrItemInfo(TN(info[#info-1]))][5] = v;
                            D.Status.SpellsChanged = GetTime(); -- will force an update of all MUFs attributes
                            D:Debug("Attribute update triggered");
                        end
                    end
                end,

                validate = function (info, v)
                    local error = function (m) D:ColorPrint(1, 0, 0, m); return m; end;

                    if type(v) ~= 'string' then -- this should be impossible
                        return error("What did you do?!?");
                    end

                    local length = (v:gsub("UNITID", "PARTYPET5")):len()

                    if length > 255 then
                        return error((L["OPT_CUSTOM_SPELL_MACRO_TOO_LONG"]):format( length - 255));
                    end

                    if not v:find("UNITID") then
                        return error(L["OPT_CUSTOM_SPELL_MACRO_MISSING_UNITID_KEYWORD"]);
                    end

                    if not v:find(D.GetSpellOrItemInfo(TN(info[#info-1])), 0, true) then
                        T._ShowNotice(error((L["OPT_CUSTOM_SPELL_MACRO_MISSING_NOMINAL_SPELL"]):format((D.GetSpellOrItemInfo(TN(info[#info-1]))))));
                    end

                    return 0;
                end,

                order = 115
            },
            -- a delete button
            delete = {
                type = 'execute',
                name = function(info) return ("%s %q"):format(L["OPT_DELETE_A_CUSTOM_SPELL"], D.GetSpellOrItemInfo(TN(info[#info - 1])) or "BAD SPELL!") end,
                confirm = true,
                width = 'double',
                func = function (info)

                    if (#info ~= 0) then -- prevent a bug from Ace3 when someone pushes several times on the delete without confirming
                        if D.classprofile.UserSpells[TN(info[#info - 1])].IsDefault then
                            D.classprofile.UserSpells[TN(info[#info - 1])].Types = {};
                            D.classprofile.UserSpells[TN(info[#info - 1])].Hidden = true;
                        else
                            D.classprofile.UserSpells[TN(info[#info - 1])] = nil;
                        end

                        if D.Status.FoundSpells[D.GetSpellOrItemInfo(TN(info[#info - 1]))] then
                            D:Configure();
                        end
                    end
                end,
                order = -1,
            },
            -- one checkbox per type
        },

    };

    function D:CreateAddedSpellsOptionMenu (where)

        -- create type slectors
        local TypesSelector = {};

        for localizableTypeName, curetype in pairs(DC.LocalizableTypeNamesToTypes) do
            TypesSelector[localizableTypeName] = TypeOption;
            order = order + 1;
        end

        SpellSubOptions.args.cureTypes.args = TypesSelector;

        -- create unitFiltering by type
        local UnitFilteringTypeSelector = {};
        for localizableTypeName, curetype in pairs(DC.LocalizableTypeNamesToTypes) do
            UnitFilteringTypeSelector[localizableTypeName] = typeUnitFilteringOption;
            order = order + 1;
        end

        SpellSubOptions.args.UnitFiltering.args = UnitFilteringTypeSelector;

        -- create each spell option table
        for spellID, spellTable in pairs(self.classprofile.UserSpells) do
            if not spellTable.Hidden then
                where[tostring(spellID)] = SpellSubOptions;
                order = order + 1;
            end
        end

    end
end

do
    local t_BleedEffectsIDCheck = {};
    local t_DefaultBleedEffectsIDCheck = {};
    local t_CheckBleedDebuffsActiveIDs = {};
    local noCasekeywordPatterns = "";

    local tw_spell_desc_cache = setmetatable({}, {
        __index = function(table, spellID)
            --D:Debug("metatable __index called with ", spellID);
            local desc = C_Spell.DoesSpellExist(spellID) and GetSpellDescription(spellID) or L["OPT_BLEED_EFFECT_UNKNOWN_SPELL"]:format(spellID);

            if desc ~= "" then
                table[spellID] = desc;
            elseif not C_Spell.IsSpellDataCached(spellID) then
                C_Spell.RequestLoadSpellData(spellID);
                desc =  L["OPT_SPELL_DESCRIPTION_LOADING"];

                D:Debug("delayed Bleed Effect option panel refresh scheduled because of spellID: ", spellID);
                D:ScheduleDelayedCall("refreshBleedEffectList", function () D:NotifyConfigurationChanged() end, 2);

            else
                desc = L["OPT_SPELL_DESCRIPTION_UNAVAILABLE"];
                table[spellID] = desc;
            end
            --D:Debug("metatable __index called with ", spellID, "desc:", desc);
            return desc;
        end;
    });

    local tw_spell_name_cache = setmetatable({}, {
        __index = function(table, spellID)
            local spellName = C_Spell.DoesSpellExist(spellID) and D.GetSpellOrItemInfo(spellID) or false;
            table[spellID] = spellName;
            return spellName;
        end
    });
    local order = 0;

    function D:hasDescBleedEffectkeyword(desc, test_pattern, testAll)
        local P_BleedEffectsKeywords_noCase = test_pattern and test_pattern or D.Status.P_BleedEffectsKeywords_noCase;

        local hasMatch = false;

        local success, errorMessage = pcall(function()
            for pattern in P_BleedEffectsKeywords_noCase:gmatch("[^\n\r]+") do
                if desc:find(pattern) then
                    hasMatch = true;
                    if not testAll then
                        break;
                    end
                end
            end
        end);

        return hasMatch, errorMessage;
    end

    local function higlightkeywords(desc, test_pattern)
        local highlightedDesc = desc;

        if D.Status.P_BleedEffectsKeywords_noCase ~= false then
            for pattern in D.Status.P_BleedEffectsKeywords_noCase:gmatch("[^\n\r]+") do
                pcall(function()
                    highlightedDesc =
                    highlightedDesc:gsub(pattern, function (identifier) return ("|cFFFF0077%s|r"):format(identifier) end);
                end)
            end
        end

        return highlightedDesc;
    end

    local function GetBleedEffectColoredName(spellID) -- {{{
        local descHasID = D:hasDescBleedEffectkeyword(tw_spell_desc_cache[spellID]);
        local name = tw_spell_name_cache[spellID];
        local color = 'FFFFFFFF';

        if name then
            if not t_BleedEffectsIDCheck[spellID] then
                color = 'FFAA0000';
            else
                color = 'FF00D000';
            end
        else
            color = 'FFA0A0A0';
        end

        return D:ColorText(name and ((not descHasID and "|cFFFF0000?|r " or "") .. name) or L["OPT_BLEED_EFFECT_UNKNOWN_SPELL"]:format(spellID), color);
    end -- }}}

    local bleedEffectEntry = { -- {{{
        type = 'group',
        name = function(info) return GetBleedEffectColoredName(TN(info[#info])) end,
        desc = function () return false; end,
        order = function() return order; end,
        args = {
            header = {
                type = 'header',
                name = function (info)
                    return L["OPT_BLEED_EFFECT_DESCRIPTION"]:format(info[#info - 1]);
                end,
                order = 0,
            },
            desc = {
                type = 'description',
                name = function (info)
                    return higlightkeywords(tw_spell_desc_cache[TN(info[#info - 1])])
                end,
                order = 10,
            },
            isBleedEffect = {
                type = 'toggle',
                name = L["OPT_IS_BLEED_EFFECT"],
                desc = L["OPT_IS_BLEED_EFFECT_DESC"],
                set = function(info, v)
                    t_BleedEffectsIDCheck[TN(info[#info - 1])] = v;
                    t_CheckBleedDebuffsActiveIDs[TN(info[#info - 1])] = v;

                    return t_BleedEffectsIDCheck[TN(info[#info - 1])];
                end,
                get = function(info)
                    return t_BleedEffectsIDCheck[TN(info[#info - 1])];
                end,
                order = 20,
            },
            remove = {
                type = 'execute',
                name = L["OPT_DELETE_A_CUSTOM_SPELL"],
                set = function(info, v)
                    return t_BleedEffectsIDCheck[TN(info[#info - 1])]
                end,
                confirm = true,
                func = function (info)
                    local toRemove = TN(info[#info - 1]);
                    t_BleedEffectsIDCheck[toRemove] = t_DefaultBleedEffectsIDCheck[toRemove] and -1 or nil;
                    D:Debug('XXXX',t_BleedEffectsIDCheck[toRemove]  );
                    t_CheckBleedDebuffsActiveIDs[toRemove] = nil;
                end,
                order = 30,
            },


        },
    }; -- }}}

    function D:CreateBleedingDebuffsOptionMenu(where)
        t_BleedEffectsIDCheck = D.db.global.t_BleedEffectsIDCheck;
        t_DefaultBleedEffectsIDCheck = D.defaults.global.t_BleedEffectsIDCheck;
        t_CheckBleedDebuffsActiveIDs = D.Status.t_CheckBleedDebuffsActiveIDs;
        noCasekeywordPatterns = D.Status.P_BleedEffectsKeywords_noCase

        for spellID, enabled in pairs(t_BleedEffectsIDCheck) do
            if enabled ~= -1 then
                where[tostring(spellID)] = bleedEffectEntry;
            end
        end

        where["resetListToDefaults"] = {
            type = 'execute',
            name = "|cFFFF0000" .. L["OPT_RESET_DEFAULT_BLEED_EFFECTS"] .. "|r",
            desc = L["OPT_RESET_DEFAULT_BLEED_EFFECTS_DESC"],
            func = function()
                D.Status.t_CheckBleedDebuffsActiveIDs = {};
                table.wipe(D.db.global.t_BleedEffectsIDCheck);

                D:readdDefaultsBleedEffects();
            end,
            confirm = true,
            disabled = function () return not D.Status.CuringSpells[DC.BLEED] end,
            order = -1,
        };
        where["readdDefaults"] = {
            type = 'execute',
            confirm = true,
            name = L["OPT_READD_DEFAULT_BLEED_EFFECTS"],
            desc = L["OPT_READD_DEFAULT_BLEED_EFFECTS_DESC"],
            func = function()
                D:readdDefaultsBleedEffects();
            end,
            disabled = function () return not D.Status.CuringSpells[DC.BLEED] end,
            order = 0,
        };
    end

    function D:reset_t_CheckBleedDebuffsActiveIDs()
        D.Status.t_CheckBleedDebuffsActiveIDs = {};
        for spellID, isBleed in pairs(D.db.global.t_BleedEffectsIDCheck) do
            if isBleed ~= -1 then
                D.Status.t_CheckBleedDebuffsActiveIDs[spellID] = isBleed;
            end
        end
    end

    function D:GetDefaultBleedEffectsKeywords()
        local keywords;

        -- ENCOUNTER_JOURNAL_SECTION_FLAG13 is equal to Bleed but it appears that
        -- many "bleeding" effect do not contain this term but rather 'Physical' so we use both.
        if _G.STRING_SCHOOL_PHYSICAL then
            local cleanedSchoolPhysical = (_G.STRING_SCHOOL_PHYSICAL:gsub("%A", ""))

            keywords = cleanedSchoolPhysical ~= "" and cleanedSchoolPhysical or _G.STRING_SCHOOL_PHYSICAL;

            if _G.ENCOUNTER_JOURNAL_SECTION_FLAG13 then
                local cleanedEJSF13 = (_G.ENCOUNTER_JOURNAL_SECTION_FLAG13:gsub("%A", ""))

                keywords = keywords .. "\n" .. (cleanedEJSF13 ~= "" and cleanedEJSF13 or _G.ENCOUNTER_JOURNAL_SECTION_FLAG13);
            else
                keywords = keywords .. "\n" .. L["BLEED"]
            end
        end

        return keywords:trim();
    end

    function D:readdDefaultsBleedEffects()
        local defaults = D.defaults.global.t_BleedEffectsIDCheck;
        local t_BleedEffectsIDCheck = D.db.global.t_BleedEffectsIDCheck;
        local t_CheckBleedDebuffsActiveIDs = D.Status.t_CheckBleedDebuffsActiveIDs;

        for spellID, isBleed in pairs(defaults) do
            t_BleedEffectsIDCheck[spellID] = isBleed;
            t_CheckBleedDebuffsActiveIDs[spellID] = isBleed;
        end
    end
end

-- to test on 2.3 : /script D:PrintLiteral(GetBindingAction(D.db.global.MacroBind));
-- to test on 2.3 : /script D:PrintLiteral(GetBindingKey(D.CONF.MACROCOMMAND));
local SaveBindings = _G.SaveBindings or _G.AttemptToSaveBindings; -- was renamed for WOW Classic, it might happen too on retail...

function D:SetMacroKey ( key )

    -- if the key is already correctly mapped, return here.
    --if (key and key == D.db.global.MacroBind and GetBindingAction(key) == D.CONF.MACROCOMMAND) then
    if D.profile.DisableMacroCreation or key and key == D.db.global.MacroBind and D:tcheckforval({GetBindingKey(D.CONF.MACROCOMMAND)}, key) then -- change for 2.3 where GetBindingAction() is no longer working
        return;
    end

    -- if the current set key is currently mapped to Decursive macro (it means we are changing the key)
    --if (D.profile.MacroBind and GetBindingAction(D.profile.MacroBind) == D.CONF.MACROCOMMAND) then
    if (D.db.global.MacroBind and D:tcheckforval({GetBindingKey(D.CONF.MACROCOMMAND)}, D.db.global.MacroBind) ) then -- change for 2.3 where GetBindingAction() is no longer working

        -- clearing redudent mapping to Decursive macro.
        local MappedKeys = {GetBindingKey(D.CONF.MACROCOMMAND)};
        for _, key in pairs(MappedKeys) do
            D:Debug("Unlinking [%s]", key);
            SetBinding(key, nil); -- clear the binding
        end

        -- Restore previous key state
        if (D.profile.PreviousMacroKeyAction) then
            D:Debug("Previous key action restored:", D.profile.PreviousMacroKeyAction);
            if not SetBinding(D.db.global.MacroBind, D.profile.PreviousMacroKeyAction) then
                --  /script SetBinding ("BUTTON1", "CAMERAORSELECTORMOVE"); to communicate to people who accidently set BUUTON1 to our macro.
                D:Debug("Restoration failed");
            end
        end
    end


    if (key) then
        if (GetBindingAction(key) ~= "" and GetBindingAction(key) ~= D.CONF.MACROCOMMAND) then
            -- save current key assignement
            D.profile.PreviousMacroKeyAction = GetBindingAction(key)
            D:Debug("Old key action saved:", D.profile.PreviousMacroKeyAction);
            D:errln(L["MACROKEYALREADYMAPPED"], key, D.profile.PreviousMacroKeyAction);
        else
            D.profile.PreviousMacroKeyAction = false;
            D:Debug("Old key action not saved because it was mapped to nothing");
        end

        -- set
        if (SetBindingMacro(key, D.CONF.MACRONAME)) then
            D.db.global.MacroBind = key;
            D:Println(L["MACROKEYMAPPINGSUCCESS"], key);
        else
            D:errln(L["MACROKEYMAPPINGFAILED"], key);
        end
    else
        D.db.global.MacroBind = false;
        if D.profile.NoKeyWarn and not GetBindingKey(D.CONF.MACROCOMMAND) then
            D:errln(L["MACROKEYNOTMAPPED"]);
        end
    end

    -- save the bindings to disk
    if GetCurrentBindingSet()==1 or GetCurrentBindingSet()==2 then -- GetCurrentBindingSet() may return strange values when the game is loaded without WTF folder.
        SaveBindings(GetCurrentBindingSet());
    end

end

function D:AutoHideShowMUFs ()

    -- This function cannot do anything if we are fighting
    if (InCombatLockdown()) then
        -- if we are fighting, postpone the call
        D:AddDelayedFunctionCall (
        "CheckIfHideShow", self.AutoHideShowMUFs,
        self);
        return false;
    end

    if D.profile.AutoHideMUFs == 1 then
        return false;
    else
        local hideBecauseInSolo          = D.profile.AutoHideMUFs == 2 and GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0
        local hideBecauseInSoloOrParty   = D.profile.AutoHideMUFs == 3 and GetNumRaidMembers() == 0
        local hideBecauseInRaids         = D.profile.AutoHideMUFs == 4 and GetNumRaidMembers() ~= 0

        local shouldHide = hideBecauseInSolo or hideBecauseInSoloOrParty or hideBecauseInRaids

        -- local InGroup = (GetNumRaidMembers() ~= 0 or (D.profile.AutoHideMUFs ~= 3 and GetNumPartyMembers() ~= 0) );
        D:Debug("AutoHideShowMUFs:", shouldHide, hideBecauseInSolo, hideBecauseInSoloOrParty, hideBecauseInRaids);

        if shouldHide then
            -- if the frame is displayed
            if D.profile.ShowDebuffsFrame then
                -- hide it
                D:ShowHideDebuffsFrame ();
            end
        else
            -- if the frame is not displayed
            if not D.profile.ShowDebuffsFrame then
                -- show it
                D:ShowHideDebuffsFrame ();
            end
        end

        return true;
    end
end

function D:QuickAccess (CallingObject, button) -- {{{
    --D:Debug("clicked");

    if not D.Status.Enabled or InCombatLockdown() then
        return
    end

    if (not CallingObject) then
        CallingObject = "noframe";
    end

    if (button == "RightButton" and not IsShiftKeyDown()) then

        if (not IsAltKeyDown()) then
            D:Println(L["DEWDROPISGONE"]);
        else
            local modern = T.ZhaohuModern;
            if modern and modern.ToggleUI then
                modern:ToggleUI();
            else
                D:Println("Zhaohu's Decursive settings are still initializing.");
            end
        end

    elseif (button == "RightButton" and IsShiftKeyDown()) then
        D:HideBar();
    elseif (button == "LeftButton" and IsControlKeyDown()) then
        D:ShowHidePriorityListUI();
    elseif (button == "LeftButton" and IsShiftKeyDown()) then
        D:ShowHideSkipListUI();
    end

end -- }}}


T._LoadedFiles["Dcr_opt.lua"] = "@project-version@";

-- Closer
