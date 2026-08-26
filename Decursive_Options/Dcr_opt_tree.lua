--[[
    This file is part of Decursive.

    Decursive Options - AceConfig-shaped option tree (LoadOnDemand). This
    file was solely written by Randy Lorfing.
    Copyright (C) 2026 Randy Lorfing

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

    Defaults, GetHandler/SetHandler, and combat helpers remain in Decursive/Dcr_opt.lua.
    Companion `...` is NOT Decursive's private table; use DecursiveRootTable.
--]]
local T = DecursiveRootTable
local D = T and T.Dcr
local DC = T and T._C
if not D or not DC then return end
local L  = D.L or LibStub("AceLocale-3.0"):GetLocale("Decursive", true)
local LC = D.LC
local addonName = T._AddonName or "Decursive"
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local table = _G.table
local str_format = _G.string.format
local tonumber = _G.tonumber
local TN = function(string) return tonumber(string) or nil end
local InCombatLockdown = _G.InCombatLockdown
local GetItemInfo = _G.C_Item and _G.C_Item.GetItemInfo or _G.GetItemInfo
local GetSpellInfo = _G.C_Spell and _G.C_Spell.GetSpellInfo or _G.GetSpellInfo
local GetSpellName = _G.C_Spell and _G.C_Spell.GetSpellName or function(spellId) return (GetSpellInfo(spellId)) end
local GetAddOnMetadata = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
local C_Spell = _G.C_Spell

local CombatWarning = {
    type = "description",
    name = D:ColorText(L["OPT_OPTIONS_DISABLED_WHILE_IN_COMBAT"], "FFFF0000"),
    order = 0,
    disabled = false,
    hidden = function() return not D.Status.Combat end,
};

local SpellAssignmentsTexts = {};
local CustomSpellMacroEditingAllowed = false;
local function GetStaticOptions ()

    local function validateSpellInput(info, v)  -- {{{

        D:Debug("Validating spell id", v);
        local error = function (m) D:ColorPrint(1, 0, 0, m); return m; end;

        local isItem = nil;
        local isPetAbility = nil;

        -- We got a spell ID directly
        if tonumber(v) then
            v = tonumber(v);
            -- test if it's valid
            if not GetSpellName(v) and not (GetItemInfo(v)) then
                return error(L["OPT_INPUT_SPELL_BAD_INPUT_ID"]);
            end

            isItem = not GetSpellName(v);

        elseif D:GetSpellFromLink(v) then
            -- We got a spell link!
            v, isPetAbility = D:GetSpellFromLink(v);
        elseif D:GetItemFromLink(v) then
            -- We got a item link!
            isItem = true;
            v = D:GetItemFromLink(v);
        elseif type(v) == 'string' and (D:GetSpellUsefulInfoIfKnown(v)) then -- not a number, not a spell link, then a spell name?
            -- We got a spell name!
            D:Debug(v, "is a spell name in our book:", D:GetSpellUsefulInfoIfKnown(v));
            local id, isPet = D:GetSpellUsefulInfoIfKnown(v);
            v = id;
            isPetAbility = isPet;
        elseif type(v) == 'string' and (GetItemInfo(v)) then
            D:Debug(v, "is a item name:", GetItemInfo(v));
            -- We got an item name!
            isItem = true;
            v = D:GetItemFromLink(select(2, GetItemInfo(v)));
        else
            return error(L["OPT_INPUT_SPELL_BAD_INPUT_NOT_SPELL"]);
        end

        if not isItem and v > 0xfffff then
            v = bit.band(0xfffff, v);
        end

        -- avoid spellID/itemID collisions
        if isItem then
            v = -1 * v;
        end

        -- It's a deleted default spell
        if D.classprofile.UserSpells[v] and not D.classprofile.UserSpells[v].Hidden then
            D:Debug(v);
            return error(L["OPT_INPUT_SPELL_BAD_INPUT_ALREADY_HERE"]);
        end

        -- The spell is part of the default set and the user doesn't want to change the macro
        if DC.SpellsToUse[v] and not CustomSpellMacroEditingAllowed then
            return error(L["OPT_INPUT_SPELL_BAD_INPUT_DEFAULT_SPELL"]);
        end

        return 0, v, isItem, isPetAbility;
    end -- }}}

    return {
        -- {{{
        type = "group",
        name = D.name,

        get = D.GetHandler,
        set = D.SetHandler,
        hidden = function () return not D:IsEnabled(); end,
        disabled = function () return not D:IsEnabled(); end,
        args = {
            -- Command line only {{{
            -- enable and disable
            enable = {
                type = 'toggle',
                name = L["OPT_ENABLEDECURSIVE"],
                hidden = function() return D:IsEnabled(); end,
                disabled = function() return D:IsEnabled(); end,
                set = function() D.Status.Enabled = D:Enable(); return D.Status.Enabled; end,
                get = function() return D:IsEnabled(); end,
                order = -2,
            },
            disable = {
                type = 'toggle',
                guiHidden  = true,
                disabled = function() return not D:IsEnabled(); end,
                name = 'disable',
                set = function() D.Status.Enabled = not D:Disable(); return not D.Status.Enabled; end,
                get = function() return not D:IsEnabled(); end,
                order = -3,
            },
            HideMUFsHandle = {
                type = 'toggle',
                name = L["OPT_HIDEMUFSHANDLE"],
                desc = L["OPT_HIDEMUFSHANDLE_DESC"],
                guiHidden = D.profile and not D.profile.HideMUFsHandle,
                disabled = function() return not D:IsEnabled() or not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1; end,
                get = function(info) return not D.MFContainerHandle:IsMouseEnabled(); end,
                order = -4,
            },
            debug = {
                type = "toggle",
                guiHidden = not D.debug,
                name = L["OPT_ENABLEDEBUG"],
                desc = L["OPT_ENABLEDEBUG_DESC"],
                order = -5,
            },
            -- Atticus Ross rules!
            -- }}}

            general = {
                -- {{{
                type = 'group',
                name = L["OPT_GENERAL"],
                order = 0,
                icon = DC.IconON,
                args = {
                    version = {
                        type = 'description',
                        name = D.version,
                        image = DC.IconON,
                        order = 0,
                    },
                    newVersion = {
                        type = 'description',
                        name = "|cFFEE0022" .. (L["NEW_VERSION_ALERT"]):format(D.db.global.NewerVersionName or "none", date("%Y-%m-%d", D.db.global.NewerVersionDetected)) .. "|r",
                        hidden = function() return not D.db.global.NewerVersionName end,
                        order = 2,
                    },
                    ShowDebuffsFrame = {
                        type = "toggle",
                        name = L["OPT_SHOWMFS"],
                        desc = L["OPT_SHOWMFS_DESC"],
                        set = function()
                            D:ShowHideDebuffsFrame ();
                            if D.profile.AutoHideMUFs ~= 1 then
                                D.profile.AutoHideMUFs = 1;
                                D:ColorPrint(1, 0, 0, L["OPT_AUTOHIDEMFS"] .. " -> " .. L["OPT_HIDEMFS_NEVER"]);
                            end
                        end,
                        disabled = function() return D.Status.Combat end,
                        order = 5,
                    },
                    AutoHideMUFs = {
                        type = "select",
                        style = "dropdown",
                        name = L["OPT_AUTOHIDEMFS"],
                        desc = L["OPT_AUTOHIDEMFS_DESC"] .. "\n\n" .. ("%s: %s\n%s: %s\n%s: %s\n%s: %s"):format(
                            D:ColorText(L["OPT_HIDEMFS_NEVER"], "FF88CCAA"), L["OPT_HIDEMFS_NEVER_DESC"]
                            , D:ColorText(L["OPT_HIDEMFS_SOLO"], "FF88CCAA"), L["OPT_HIDEMFS_SOLO_DESC"]
                            , D:ColorText(L["OPT_HIDEMFS_GROUP"], "FF88CCAA"), L["OPT_HIDEMFS_GROUP_DESC"]
                            , D:ColorText(L["OPT_HIDEMFS_RAID"], "FF88CCAA"), L["OPT_HIDEMFS_RAID_DESC"]),
                        values = {L["OPT_HIDEMFS_NEVER"], L["OPT_HIDEMFS_SOLO"], L["OPT_HIDEMFS_GROUP"], L["OPT_HIDEMFS_RAID"]},
                        order = 6,
                    },
                    HideLiveList = {
                        type = "toggle",
                        name = L["OPT_ENABLE_LIVELIST"],
                        desc = L["OPT_ENABLE_LIVELIST_DESC"],
                        set = function()
                            D:ShowHideLiveList()
                            if D.profile.HideLiveList and not D.profile.ShowDebuffsFrame or not D.Status.HasSpell then
                                D:SetIcon(DC.IconOFF);
                            else
                                D:SetIcon(DC.IconON);
                            end
                        end,
                        get = function () return not D.profile.HideLiveList end,
                        order = 7,
                    },
                    AfflictionTooltips = {
                        type = "toggle",
                        disabled = function() return D.profile.HideLiveList and not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1 or not D:IsEnabled(); end,
                        name = L["SHOW_TOOLTIP"],
                        desc = L["OPT_SHOWTOOLTIP_DESC"],
                        order = 20,
                    },
                    minimap = {
                        type = "toggle",
                        name = L["OPT_SHOWMINIMAPICON"],
                        desc = L["OPT_SHOWMINIMAPICON_DESC"],
                        get = function() return not D.profile.MiniMapIcon or not D.profile.MiniMapIcon.hide end,
                        set = function(info,v)
                            local hide = not v;
                            D.profile.MiniMapIcon.hide = hide;
                            if hide then
                                icon:Hide("Decursive");
                            else
                                icon:Show("Decursive");
                            end
                        end,
                        order = 30,
                    },
                    CureBlacklist = {
                        type = 'range',
                        name = L["BLACK_LENGTH"],
                        desc = L["OPT_BLACKLENTGH_DESC"],
                        min = 0,
                        max = 20,
                        step = 0.1,
                        order = 40,
                    },
                    SysOps = {
                        type = 'header',
                        name = "",
                        order = 50
                    },
                    TestItemDisplayed = {
                        type = "toggle",
                        name = L["OPT_CREATE_VIRTUAL_DEBUFF"],
                        desc = L["OPT_CREATE_VIRTUAL_DEBUFF_DESC"],
                        get = function() return  D.LiveList.TestItemDisplayed end,
                        set = function()
                            if not D.LiveList.TestItemDisplayed then
                                D.LiveList:DisplayTestItem();
                            else
                                D.LiveList:HideTestItem();
                            end
                        end,
                        disabled = function() return D.profile.HideLiveList and not D.profile.ShowDebuffsFrame or not D.Status.HasSpell or not D.Status.Enabled end,
                        order = 60
                    },
                    NoStartMessages = {
                        type = "toggle",
                        name = L["OPT_NOSTARTMESSAGES"],
                        desc = L["OPT_NOSTARTMESSAGES_DESC"],
                        order = 70
                    },
                    NewerVersionAlerts ={
                        type = "toggle",
                        name = L["OPT_NEWVERSIONBUGMENOT"],
                        desc = L["OPT_NEWVERSIONBUGMENOT_DESC"],
                        get = function() return not D.db.global.NewVersionsBugMeNot end,
                        set = function(info,v)
                            D.db.global.NewVersionsBugMeNot = v == false and D.VersionTimeStamp or false;
                        end,
                        order = 75
                    },
                    report = {
                        type = "execute",
                        name = D:ColorText(L["DECURSIVE_DEBUG_REPORT_SHOW"], "FFFF0000"),
                        desc = L["DECURSIVE_DEBUG_REPORT_SHOW_DESC"],
                        func = function ()
                            if T.ZhaohuModern and T.ZhaohuModern.frame then T.ZhaohuModern.frame:Hide(); end
                            if GameTooltip:IsShown() then GameTooltip:Hide(); end
                            T._ShowDebugReport();
                        end,
                        hidden = function() return  #T._DebugTextTable < 1 end,
                        order = 1000
                    },

                    GlorfindalMemorium = {
                        type = "execute",
                        name = D:ColorText(L["GLOR1"], "FF" .. D:GetClassHexColor( "WARRIOR" )),
                        desc = L["GLOR2"],
                        width = 'double',
                        func = function ()

                        -- {{{
                            if T.ZhaohuModern and T.ZhaohuModern.frame then T.ZhaohuModern.frame:Hide(); end
                            if GameTooltip:IsShown() then GameTooltip:Hide(); end
                            if not D.MemoriumFrame then
                                D.MemoriumFrame = CreateFrame("Frame", nil, UIParent);
                                local f = D.MemoriumFrame;
                                local w = 512; local h = 390;

                                f:SetFrameStrata("TOOLTIP");
                                f:EnableKeyboard(true);
                                f:SetScript("OnKeyUp", function (frame, event, arg1, arg2) D.MemoriumFrame:Hide(); end);
                                --[[
                                f:SetScript("OnShow",
                                function ()
                                -- I wanted to make the shadow to move over the marble very slowly as clouds
                                -- I tried to make it rotate but the way I found would only make it rotate around its origin (which is rarely useful)
                                -- so leaving it staedy for now... if someone got an idea, let me know.
                                D:ScheduleRepeatingEvent("Dcr_GlorMoveShadow",
                                function (f)
                                local cos, sin = math.cos, math.sin;
                                f.Shadow.Angle = f.Shadow.Angle + 1;
                                if f.Shadow.Angle == 360 then f.Shadow.Angle = 0; end
                                local angle = math.rad(f.Shadow.Angle);
                                D:SetCoords(f.Shadow, cos(angle), sin(angle), 0, -sin(angle), cos(angle), 0);

                                end
                                , 1/50, f);
                                end);
                                f:SetScript("OnHide", function() D:CancelDelayedCall("Dcr_GlorMoveShadow"); end)
                                --]]

                                f:SetWidth(w);
                                f:SetHeight(h);
                                f.tTL = f:CreateTexture(nil,"BACKGROUND")
                                f.tTL:SetTexture("Interface\\ItemTextFrame\\ItemText-Marble-TopLeft")
                                f.tTL:SetWidth(w - w / 5);
                                f.tTL:SetHeight(h - h / 3);
                                f.tTL:SetTexCoord(0, 1, 5/256, 1);
                                f.tTL:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -10);

                                f.tTR = f:CreateTexture(nil,"BACKGROUND")
                                f.tTR:SetTexture("Interface\\ItemTextFrame\\ItemText-Marble-TopRight")
                                f.tTR:SetWidth(w / 5 - 3);
                                f.tTR:SetHeight(h - h / 3);
                                f.tTR:SetTexCoord(0, 1, 5/256, 1);
                                f.tTR:SetPoint("TOPLEFT", f.tTL, "TOPRIGHT", 0, 0);

                                f.tBL = f:CreateTexture(nil,"BACKGROUND")
                                f.tBL:SetTexture("Interface\\ItemTextFrame\\ItemText-Marble-BotLeft")
                                f.tBL:SetWidth(w - w / 5);
                                f.tBL:SetHeight(h / 3 - 20);
                                f.tBL:SetTexCoord(0,1,0, 408/512);
                                f.tBL:SetPoint("TOPLEFT", f.tTL, "BOTTOMLEFT", 0, 0);

                                f.tBR = f:CreateTexture(nil,"BACKGROUND")
                                f.tBR:SetTexture("Interface\\ItemTextFrame\\ItemText-Marble-BotRight")
                                f.tBR:SetWidth(w / 5 - 3);
                                f.tBR:SetHeight(h / 3 - 20);
                                f.tBR:SetTexCoord(0,1,0, 408/512);
                                f.tBR:SetPoint("TOPLEFT", f.tBL, "TOPRIGHT", 0, 0);

                                f.Shadow = f:CreateTexture(nil, "ARTWORK");
                                f.Shadow:SetTexture("Interface\\TabardFrame\\TabardFrameBackground")
                                f.Shadow:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -9);
                                f.Shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 9);
                                f.Shadow:SetAlpha(0.1);

                                ---[[
                                f.fB = f:CreateTexture(nil,"OVERLAY")
                                f.fB:SetTexture(T._AddonPath .. "Textures\\GoldBorder")
                                f.fB:SetTexCoord(5/512, 324/512, 6/512, 287/512);
                                f.fB:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
                                f.fB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
                                --]]

                                f.FSt = f:CreateFontString(nil,"OVERLAY", "MailTextFontNormal");
                                f.FSt:SetFont("Fonts\\MORPHEUS.TTF", 18 );
                                f.FSt:SetTextColor(0.18, 0.12, 0.06, 1);
                                f.FSt:SetPoint("TOPLEFT", f.tTL, "TOPLEFT", 5, -20);
                                f.FSt:SetPoint("TOPRIGHT", f.tTR, "TOPRIGHT", -5, -20);
                                f.FSt:SetJustifyH("CENTER");
                                f.FSt:SetText(L["GLOR3"]);
                                f.FSt:SetAlpha(0.80);

                                f.FSc = f:CreateFontString(nil,"OVERLAY", "MailTextFontNormal");
                                f.FSc:SetFont("Fonts\\MORPHEUS.TTF", 15 );
                                f.FSc:SetTextColor(0.18, 0.12, 0.06, 1);
                                f.FSc:SetHeight(h - 30 - 60);
                                f.FSc:SetPoint("TOP", f.FSt, "BOTTOM", 0, -28);
                                f.FSc:SetPoint("LEFT", f.tTL, "LEFT", 30, 0);
                                f.FSc:SetPoint("RIGHT", f.tTR, "RIGHT", -30, 0);
                                f.FSc:SetJustifyH("CENTER");
                                f.FSc:SetJustifyV("TOP");
                                f.FSc:SetSpacing(5);

                                f.FSc:SetText(L["GLOR4"]);


                                f.FSc:SetAlpha(0.80);

                                f.FSl = f:CreateFontString(nil,"OVERLAY", "MailTextFontNormal");
                                f.FSl:SetFont("Fonts\\MORPHEUS.TTF", 15 );
                                f.FSl:SetTextColor(0.18, 0.12, 0.06, 1);
                                f.FSl:SetJustifyH("LEFT");
                                f.FSl:SetJustifyV("BOTTOM");
                                f.FSl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 33);
                                f.FSl:SetAlpha(0.80);
                                f.FSl:SetText(L["GLOR5"]);

                                f:SetPoint("CENTER",0,0);

                            end
                            D.MemoriumFrame:Show();

                            --[[

                            In remembrance of Bertrand Sense
                            1969 - 2007


                            Friendship and affection can take their roots anywhere, those
                            who met Glorfindal in World of Warcraft knew a man of great
                            commitment and a charismatic leader.

                            He was in life as he was in game, selfless, generous, dedicated
                            to his friends and most of all, a passionate man.

                            He left us at the age of 38 leaving behind him not just
                            anonymous players in a virtual world, but a group of true
                            friends who will miss him forever.

                            He will always be remembered...

                            --

                            En souvenir de Bertrand Sense
                            1969 - 2007

                            L'amitié et l'affection peuvent prendre naissance n'importe où,
                            ceux qui ont rencontré Glorfindal dans World Of Warcraft on
                            connu un homme engagé et un leader charismatique.

                            Il était dans la vie comme dans le jeux, désintéressé,
                            généreux, dévoué envers les siens et surtout un homme passionné.

                            Il nous a quitté à l'âge de 38 ans laissant derrière lui pas
                            seulement des joueurs anonymes dans un monde virtuel, mais un
                            groupe de véritables amis à qui il manquera eternellement.

                            On ne l'oubliera jamais...

                            --]]
                            -- }}}
                        end,
                        order = 100,
                    },
                }
            }, -- }}}

            SoundNotifications = {
                type = "group",
                name = "Sound Notifications",
                desc = "Configure MUF affliction alerts, burst suppression, output channel and cure-failure feedback.",
                order = 5,
                disabled = function() return not D:IsEnabled(); end,
                args = {
                    intro = {
                        type = "description",
                        name = "For WoW 12.1 protected auras, Decursive registers public DispelDB and learned spell IDs for the units assigned to its MUFs. Blizzard detects the protected application and plays the selected sound natively. Decursive never reads managed-button visibility or protected aura details.",
                        order = 1,
                    },
                    PlaySound = {
                        type = "toggle",
                        name = "Enable sound notifications",
                        desc = "Master switch for Decursive dispel and cure-failure sound notifications.",
                        get = function() return D.profile.PlaySound ~= false end,
                        set = function(info, value)
                            D.profile.PlaySound = value and true or false;
                            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound enable changed"); end
                        end,
                        order = 10,
                    },
                    SoundNotificationPreset = {
                        type = "select",
                        style = "dropdown",
                        name = "Dispel alert sound",
                        desc = "Choose the sound used for a new dispel alert.",
                        values = {
                            AFFLICTION = "Tone — Affliction Alert (classic)",
                            QUICK = "Tone — Quick Pulse",
                            FAILURE = "Tone — Short Alert",
                            BRIGHT_PING = "Tone — Bright Ping",
                            DOUBLE_PING = "Tone — Double Ping",
                            TRIPLE_PING = "Tone — Triple Ping",
                            HIGH_CHIME = "Tone — High Chime",
                            LOW_CHIME = "Tone — Low Chime",
                            PULSE_UP = "Tone — Rising Pulse",
                            PULSE_DOWN = "Tone — Falling Pulse",
                            VOICE_DISPEL = "Voice — Dispel",
                            VOICE_CLEANSE = "Voice — Cleanse",
                            VOICE_CURE = "Voice — Cure",
                            VOICE_HELP = "Voice — Help",
                            VOICE_CLEANSE_ME = "Voice — Cleanse me",
                            VOICE_CURE_ME = "Voice — Cure me",
                            VOICE_HELP_CLEANSE_ME = "Voice — Help, cleanse me",
                            VOICE_HELP_CURE_ME = "Voice — Help, cure me",
                            FEMALE_DISPEL = "Female Voice — Dispel",
                            FEMALE_DISPEL_ME = "Female Voice — Dispel me",
                            FEMALE_CLEANSE = "Female Voice — Cleanse",
                            FEMALE_CLEANSE_ME = "Female Voice — Cleanse me",
                        },
                        get = function() return D.profile.SoundNotificationPreset or "FEMALE_DISPEL" end,
                        set = function(info, value)
                            D.profile.SoundNotificationPreset = value;
                            local files = {
                                AFFLICTION = DC.AfflictionSound,
                                QUICK = T._AddonPath .. "Sounds\\G_NecropolisWound-fast.ogg",
                                FAILURE = DC.FailedSound,
                                BRIGHT_PING = T._AddonPath .. "Sounds\\BrightPing.ogg",
                                DOUBLE_PING = T._AddonPath .. "Sounds\\DoublePing.ogg",
                                TRIPLE_PING = T._AddonPath .. "Sounds\\TriplePing.ogg",
                                HIGH_CHIME = T._AddonPath .. "Sounds\\HighChime.ogg",
                                LOW_CHIME = T._AddonPath .. "Sounds\\LowChime.ogg",
                                PULSE_UP = T._AddonPath .. "Sounds\\PulseUp.ogg",
                                PULSE_DOWN = T._AddonPath .. "Sounds\\PulseDown.ogg",
                                VOICE_DISPEL = T._AddonPath .. "Sounds\\VoiceDispel.ogg",
                                VOICE_CLEANSE = T._AddonPath .. "Sounds\\VoiceCleanse.ogg",
                                VOICE_CURE = T._AddonPath .. "Sounds\\VoiceCure.ogg",
                                VOICE_HELP = T._AddonPath .. "Sounds\\VoiceHelp.ogg",
                                VOICE_CLEANSE_ME = T._AddonPath .. "Sounds\\VoiceCleanseMe.ogg",
                                VOICE_CURE_ME = T._AddonPath .. "Sounds\\VoiceCureMe.ogg",
                                VOICE_HELP_CLEANSE_ME = T._AddonPath .. "Sounds\\VoiceHelpCleanseMe.ogg",
                                VOICE_HELP_CURE_ME = T._AddonPath .. "Sounds\\VoiceHelpCureMe.ogg",
                                FEMALE_DISPEL = T._AddonPath .. "Sounds\\FemaleDispel.ogg",
                                FEMALE_DISPEL_ME = T._AddonPath .. "Sounds\\FemaleDispelMe.ogg",
                                FEMALE_CLEANSE = T._AddonPath .. "Sounds\\FemaleCleanse.ogg",
                                FEMALE_CLEANSE_ME = T._AddonPath .. "Sounds\\FemaleCleanseMe.ogg",
                            };
                            D.profile.SoundFile = files[value] or DC.AfflictionSound;
                            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound preset changed"); end
                        end,
                        disabled = function() return not D.profile.PlaySound end,
                        order = 20,
                    },
                    SoundNotificationChannel = {
                        type = "select",
                        style = "dropdown",
                        name = "Output channel",
                        desc = "Choose which WoW audio channel carries Decursive notifications. Master stays audible even when Sound Effects are disabled.",
                        values = { Master = "Master", SFX = "Sound Effects", Dialog = "Dialog", Ambience = "Ambience", Music = "Music" },
                        get = function() return D.profile.SoundNotificationChannel or "Master" end,
                        set = function(info, value)
                            D.profile.SoundNotificationChannel = value;
                            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound channel changed"); end
                        end,
                        disabled = function() return not D.profile.PlaySound end,
                        order = 30,
                    },
                    SoundNotificationIgnoreSeconds = {
                        type = "range",
                        name = "Burst ignore window",
                        desc = "Debounce Decursive-owned public-event fallback alerts for this many seconds. Blizzard-native protected aura sounds are registered and played per matching aura.",
                        min = 0,
                        max = 5,
                        step = 0.25,
                        disabled = function() return not D.profile.PlaySound end,
                        order = 40,
                    },
                    PlayFailureSound = {
                        type = "toggle",
                        name = "Play cure-failure sound",
                        desc = "Play the short failure sound when an attempted cleanse fails. The master sound switch must also be enabled.",
                        disabled = function() return not D.profile.PlaySound end,
                        order = 50,
                    },
                    testSound = {
                        type = "execute",
                        name = "Test dispel alert",
                        desc = "Play the currently selected dispel alert immediately. The test bypasses the burst ignore timer.",
                        func = function() if D.PlayDispelNotificationSound then D:PlayDispelNotificationSound("settings test", true); else D:SafePlaySoundFile(D.profile.SoundFile or DC.AfflictionSound, D.profile.SoundNotificationChannel or "Master"); end end,
                        disabled = function() return not D.profile.PlaySound end,
                        order = 60,
                    },
                    mufTriggerHeader = {
                        type = "header",
                        name = "WoW 12.1 Native Aura Trigger",
                        order = 100,
                    },
                    mufTriggerStatus = {
                        type = "description",
                        name = function()
                            local available = D.Is121MUFStateSoundEngineAvailable and D:Is121MUFStateSoundEngineAvailable();
                            if available then
                                return "Trigger engine: |cff55ff55Active — Blizzard AddAuraSound|r\nTracks: assigned Decursive MUFs\nInput: public DispelDB and learned spell IDs\nBehavior: Blizzard detects and plays registered protected aura sounds without exposing aura state to addon Lua.";
                            end
                            return "Trigger engine: |cffffaa00Unavailable on this client|r\nThe selected sound can still be tested, but protected live-aura sound requires Blizzard's AddAuraSound API.";
                        end,
                        order = 105,
                    },
                    protectedHeader = {
                        type = "header",
                        name = "Aura Sound Spell-ID Pool",
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 200,
                    },
                    SoundProtectedAuraAlerts = {
                        type = "toggle",
                        name = "Enable Blizzard native aura sounds",
                        desc = "Register DispelDB and learned spell IDs with Blizzard so matching protected auras play the selected live-combat sound.",
                        get = function() return D.profile.SoundProtectedAuraAlerts ~= false end,
                        set = function(info, value)
                            D.profile.SoundProtectedAuraAlerts = value and true or false;
                            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("native aura sound toggle changed"); end
                        end,
                        disabled = function() return not D.profile.PlaySound end,
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 210,
                    },
                    SoundProtectedAuraAutoLearn = {
                        type = "toggle",
                        name = "Learn Spell IDs from successful dispels",
                        desc = "When you successfully dispel an aura and the combat log exposes its public Spell ID, remember it for the current class/spec and immediately register it with Blizzard. The first-ever occurrence can be silent; later occurrences use Blizzard-native sound detection.",
                        disabled = function() return not D.profile.PlaySound or not D.profile.SoundProtectedAuraAlerts end,
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 220,
                    },
                    protectedStatus = {
                        type = "description",
                        name = function()
                            local ids, contextKey = {}, "current spec";
                            if D.GetProtectedAuraSoundIDs then
                                local currentIDs, currentKey = D:GetProtectedAuraSoundIDs();
                                if type(currentIDs) == "table" then ids = currentIDs; end
                                if currentKey then contextKey = currentKey; end
                            end
                            local count = #ids;
                            local recent = {};
                            if type(ids) == "table" then
                                for i = math.max(1, #ids - 7), #ids do
                                    local id = ids[i];
                                    local spellName;
                                    if _G.C_Spell and type(_G.C_Spell.GetSpellName) == "function" then
                                        local ok, value = pcall(_G.C_Spell.GetSpellName, id);
                                        if ok and value and (not _G.canaccessvalue or _G.canaccessvalue(value)) then spellName = value; end
                                    end
                                    recent[#recent + 1] = ("%d — %s"):format(id, spellName or "Unknown spell");
                                end
                            end
                            local recentText = #recent > 0 and ("\nRecent learned IDs:\n" .. table.concat(recent, "\n")) or "";
                            return ("Native engine: Blizzard AddAuraSound\nCurrent learning context: %s\nLearned protected aura spell IDs: %d%s\n\nBuilt-in DispelDB IDs and learned public IDs are registered for assigned MUF units. If an aura is not in either pool and WoW hides its Spell ID, that occurrence remains visual-only until its public ID can be learned or added."):format(contextKey, count, recentText);
                        end,
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 230,
                    },
                    addProtectedSpellID = {
                        type = "input",
                        name = "Add protected aura Spell ID",
                        desc = "Manually add a known dispellable debuff Spell ID for the current class/spec. Decursive immediately registers it with Blizzard's native aura-sound engine for assigned group units.",
                        get = function() return "" end,
                        set = function(info, value)
                            local id = tonumber(value);
                            if id and id > 0 and D.LearnProtectedAuraSoundSpellID then
                                D:LearnProtectedAuraSoundSpellID(id, "manual");
                            else
                                D:Println("Sound Notifications: enter a valid numeric spell ID.");
                            end
                        end,
                        disabled = function() return not D.profile.PlaySound or not D.profile.SoundProtectedAuraAlerts end,
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 240,
                    },
                    clearProtectedSpellIDs = {
                        type = "execute",
                        name = "Clear learned aura IDs",
                        desc = "Remove all automatically/manually learned protected aura spell IDs for the current class/spec.",
                        func = function()
                            local ids = D.GetProtectedAuraSoundIDs and D:GetProtectedAuraSoundIDs();
                            if type(ids) == "table" then
                                for i = #ids, 1, -1 do table.remove(ids, i); end
                            end
                            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("learned IDs cleared") end
                            D:Println("Sound Notifications: learned protected aura spell IDs cleared for the current class/spec.");
                        end,
                        disabled = function() local ids = D.GetProtectedAuraSoundIDs and D:GetProtectedAuraSoundIDs(); return type(ids) ~= "table" or #ids == 0 end,
                        hidden = function() return D.Is121MUFVisibilitySoundDriverEnabled and D:Is121MUFVisibilitySoundDriverEnabled() end,
                        order = 250,
                    },
                },
            },

            livelistoptions = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_LIVELIST"], "FF22EE33"),
                desc = L["OPT_LIVELIST_DESC"] .. "\n",
                hidden = function () return not D:IsEnabled(); end,
                disabled = function () return not D:IsEnabled(); end,
                handler = {
                    ["disabled"] = function() return D.profile.HideLiveList; end,
                },
                order = 10,

                args = {
                    description = {
                        type = "description",
                        name = L["OPT_LIVELIST_DESC"],
                        order = 0,
                    },
                    TestItemDisplayed = {
                        type = "toggle",
                        name = L["OPT_CREATE_VIRTUAL_DEBUFF"],
                        desc = L["OPT_CREATE_VIRTUAL_DEBUFF_DESC"],
                        get = function() return  D.LiveList.TestItemDisplayed end,
                        set = function()
                            if not D.LiveList.TestItemDisplayed then
                                D.LiveList:DisplayTestItem();
                            else
                                D.LiveList:HideTestItem();
                            end
                        end,
                        disabled = function() return D.profile.HideLiveList and not D.profile.ShowDebuffsFrame or not D.Status.HasSpell or not D.Status.Enabled end,
                        order = -1
                    },
                    LV_OnlyInRange = {
                        type = "toggle",
                        name = L["OPT_LVONLYINRANGE"],
                        desc = L["OPT_LVONLYINRANGE_DESC"],
                        disabled = "disabled",
                        order = 100
                    },
                    Amount_Of_Afflicted = {
                        type = 'range',
                        name = L["AMOUNT_AFFLIC"],
                        desc = L["OPT_AMOUNT_AFFLIC_DESC"],
                        min = 1,
                        max = D.CONF.MAX_LIVE_SLOTS,
                        step = 1,
                        disabled = "disabled",
                        order = 104,
                    },
                    ScanTime = {
                        type = 'range',
                        name = L["SCAN_LENGTH"],
                        desc = L["OPT_SCANLENGTH_DESC"],
                        min = 0.1,
                        max = 1,
                        step = 0.1,
                        disabled = "disabled",
                        order = 106,
                    },
                    ReverseLiveDisplay = {
                        type = "toggle",
                        name = L["REVERSE_LIVELIST"],
                        desc = L["OPT_REVERSE_LIVELIST_DESC"],
                        disabled = "disabled",
                        order = 107
                    },
                    LiveListScale = {
                        type = 'range',
                        disabled = function() return D.profile.HideLiveList or D.profile.BarHidden end,
                        name = L["OPT_LLSCALE"],
                        desc = L["OPT_LLSCALE_DESC"],
                        min = 0.3,
                        max = 4,
                        step = 0.01,
                        isPercent = true,
                        order = 1009,
                    },
                    AlphaLL = {
                        type = 'range',
                        disabled = function() return D.profile.HideLiveList or D.profile.BarHidden end,
                        name = L["OPT_LLALPHA"],
                        desc = L["OPT_LLALPHA_DESC"],
                        get = function() return 1 - D.profile.LiveListAlpha end,
                        set = function(info,v)
                            if (v ~= D.profile.LiveListAlpha) then
                                D.profile.LiveListAlpha = 1 - v;
                                DecursiveMainBar:SetAlpha(D.profile.LiveListAlpha);
                                DcrLiveList:SetAlpha(D.profile.LiveListAlpha);
                            end
                        end,
                        min = 0,
                        max = 0.8,
                        step = 0.01,
                        isPercent = true,
                        order = 1010,
                    },
                },
            }, -- // }}}

            MessageOptions = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_MESSAGES"], "FF229966"),
                desc = "Notifications (chat / custom text) and Alert warnings (Soul Link battle-rez banner).",
                order = 20,
                disabled = function() return  not D.Status.Enabled end,
                args = {
                    description = {
                        name = "Decursive has two on-screen text systems:\n• |cFFFFFFFFNotifications|r — status / cure messages in chat or the custom text window.\n• |cFFFFD200Alert warnings|r — large center banners (Soul Link battle-rez range). These are not the same as notifications.",
                        order = 1,
                        type = "description",
                    },
                    NotificationsHeader = {
                        type = "header",
                        name = "Notifications",
                        order = 100,
                    },
                    Print_ChatFrame = {
                        type = "toggle",
                        width = 'full',
                        name =  L["PRINT_CHATFRAME"],
                        desc = L["OPT_CHATFRAME_DESC"],
                        order = 120
                    },
                    Print_CustomFrame = {
                        type = "toggle",
                        width = 'full',
                        name =  L["PRINT_CUSTOM"],
                        desc = L["OPT_PRINT_CUSTOM_DESC"],
                        order = 121
                    },
                    Print_Error = {
                        type = "toggle",
                        width = 'full',
                        name =  L["PRINT_ERRORS"],
                        desc =  L["OPT_PRINT_ERRORS_DESC"],
                        order = 122
                    },
                    ShowCustomFAnchor = {
                        type = "toggle",
                        width = 'full',
                        name =  "Show notification text anchor",
                        desc = "Shows the Decursive Text Anchor used to position notification messages (the custom text window). This is not the purple Alert warning anchor.",
                        get = function() return DecursiveAnchor:IsVisible() end,
                        set = function()
                            D:ShowHideTextAnchor();
                        end,
                        order = 123
                    },
                    AlertWarningsHeader = {
                        type = "header",
                        name = "Alert warnings",
                        order = 200,
                    },
                    Alert121SoulLinkEnabled = {
                        type = "toggle",
                        width = 'full',
                        name = "Soul Link battle-rez alert warning",
                        desc = "Show the Alert warning banner when you attempt a battle-rez (Soul Link) out of range. Turning this off only disables the banner — battle-rez click-to-use itself is controlled separately under Curing.",
                        get = function() return not D.profile or D.profile.Alert121SoulLinkEnabled ~= false end,
                        set = function(info, value) D.profile.Alert121SoulLinkEnabled = value and true or false end,
                        order = 210,
                    },
                    Alert121DispelEnabled = {
                        type = "toggle",
                        width = 'full',
                        name = "DISPEL alert warning",
                        desc = "Show DISPEL when Blizzard's managed Micro Unit Frame aura slot finds a dispellable affliction. Enabled by default. WoW owns the protected detection; Decursive never reads secret aura data.",
                        get = function() return not D.profile or D.profile.Alert121DispelEnabled ~= false end,
                        set = function(info, value)
                            D.profile.Alert121DispelEnabled = value and true or false
                            if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
                        end,
                        order = 215,
                    },
                    Alert121DispelMode = {
                        type = "select",
                        width = 'full',
                        name = "DISPEL alert duration mode",
                        desc = "Timed (default): show DISPEL for the duration below, then hide — even if a dispel is still needed. Until cleared: keep DISPEL on screen while any MUF still needs a dispel.",
                        values = {
                            TIMED = "Timed (hide after duration)",
                            UNTIL_CLEARED = "Until no dispel is needed",
                        },
                        get = function()
                            local mode = D.profile and D.profile.Alert121DispelMode
                            if mode == "UNTIL_CLEARED" then return "UNTIL_CLEARED" end
                            return "TIMED"
                        end,
                        set = function(info, value)
                            D.profile.Alert121DispelMode = (value == "UNTIL_CLEARED") and "UNTIL_CLEARED" or "TIMED"
                            if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
                        end,
                        disabled = function() return D.profile and D.profile.Alert121DispelEnabled == false end,
                        order = 216,
                    },
                    Alert121DispelDuration = {
                        type = "range",
                        name = "DISPEL alert duration",
                        desc = "How long DISPEL stays on screen in Timed mode (default 2 seconds). Also used by the Test DISPEL button.",
                        min = 0.5,
                        max = 15,
                        step = 0.5,
                        get = function() return tonumber(D.profile and D.profile.Alert121DispelDuration) or 2 end,
                        set = function(info, value)
                            D.profile.Alert121DispelDuration = value
                            if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
                        end,
                        disabled = function()
                            if D.profile and D.profile.Alert121DispelEnabled == false then return true end
                            local mode = D.profile and D.profile.Alert121DispelMode
                            return mode == "UNTIL_CLEARED"
                        end,
                        order = 217,
                    },
                    Show121AlertAnchor = {
                        type = "toggle",
                        width = 'full',
                        name = "Show alert warning position",
                        desc = "Shows the purple Alert warning anchor used by DISPEL and Soul Link banners. Toggle off to lock. Same as |cFFFFFFFF/dcralerts move|r. Not the notification text anchor.",
                        get = function() return D.Get121AlertAnchor and D:Get121AlertAnchor():IsShown() end,
                        set = function()
                            if D.Set121AlertMoveMode and D.Get121AlertAnchor then
                                D:Set121AlertMoveMode(not D:Get121AlertAnchor():IsShown())
                            end
                        end,
                        order = 220
                    },
                    TestSoulLinkAlert = {
                        type = 'execute',
                        name = "Test Soul Link alert warning",
                        desc = "Shows a sample Soul Link Alert warning banner.",
                        func = function()
                            if D.Test121SoulLinkAlert then D:Test121SoulLinkAlert() end
                        end,
                        order = 230,
                    },
                    TestDispelAlert = {
                        type = 'execute',
                        name = "Test DISPEL alert warning",
                        desc = "Shows DISPEL on the Alert warning banner using your current duration setting (default 2 seconds). Preview works even when the live warning is disabled.",
                        func = function()
                            if D.Test121DispelAlertWarning then
                                D:Test121DispelAlertWarning()
                            elseif D.Show121DispelAlertWarning then
                                D:Show121DispelAlertWarning("options test", true)
                            end
                        end,
                        order = 235,
                    },
                    Alert121FontSize = {
                        type = 'range',
                        name = "Alert warning text size",
                        desc = "Font size for Alert warning banners (DISPEL and Soul Link). Default 48.",
                        min = 16,
                        max = 96,
                        step = 2,
                        get = function() return (D.profile.Alert121FontSize) or 48 end,
                        set = function(info, value)
                            D.profile.Alert121FontSize = value
                            if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle()
                            elseif D.Apply121SoulLinkAlertStyle then D:Apply121SoulLinkAlertStyle() end
                        end,
                        order = 240,
                    },
                    Alert121Color = {
                        type = "color",
                        name = "Alert warning text color",
                        desc = "Color of Alert warning banner text (DISPEL and Soul Link).",
                        hasAlpha = false,
                        get = function()
                            local c = D.profile.Alert121Color or {1, 0.15, 0.15}
                            return c[1], c[2], c[3]
                        end,
                        set = function(info, r, g, b)
                            D.profile.Alert121Color = {r, g, b}
                            if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle()
                            elseif D.Apply121SoulLinkAlertStyle then D:Apply121SoulLinkAlertStyle() end
                        end,
                        order = 250,
                    },
                    PrintAlertDiag = {
                        type = 'execute',
                        name = "Show alert diagnostic log",
                        desc = "Prints the last 25 alert-system decisions to your default chat frame (always the same window). Same as |cFFFFFFFF/dcralertdiag|r.",
                        func = function() if D.PrintAlertDiag then D:PrintAlertDiag(25) end end,
                        order = 260,
                    },
                }
            }, -- }}}

            MicroFrameOpt = {
                -- {{{
                type = "group",
                --childGroups = "tab",
                name = D:ColorText(L["OPT_MFSETTINGS"], "FFBBCC33"),
                desc = L["OPT_MFSETTINGS_DESC"],
                disabled = function () return not D:IsEnabled(); end,
                hidden = function () return not D:IsEnabled() end,
                order = 30,
                args = {
                    hint = {
                        type = 'description',
                        name = D:ColorText(L["OPT_MUFHANDLE_HINT"], "FF00EF00"),
                        order = 0,
                    },
                    displayOpts = {
                        type = "group",
                        inline = true,
                        name = L["OPT_DISPLAYOPTIONS"],
                        desc = L["OPT_MFSETTINGS_DESC"],
                        handler = {
                            ["disabled"] = function () return D.Status.Combat; end,
                        },
                        order = 1,
                        disabled = function () return not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1; end,
                        args = {
                            -- {{{
                            DebuffsFrameGrowToTop = {
                                type = "toggle",
                                name = L["OPT_GROWDIRECTION"],
                                desc = L["OPT_GROWDIRECTION_DESC"],
                                disabled = "disabled",
                                order = 1300,
                            },
                            DebuffsFrameStickToRight = {
                                type = "toggle",
                                name = L["OPT_STICKTORIGHT"],
                                desc = L["OPT_STICKTORIGHT_DESC"],
                                disabled = "disabled",
                                order = 1310,
                            },
                            DebuffsFrameVerticalDisplay = {
                                type = "toggle",
                                name = L["OPT_MUFSVERTICALDISPLAY"],
                                desc = L["OPT_MUFSVERTICALDISPLAY_DESC"],
                                disabled = "disabled",
                                order = 1315,
                            },
                            StatusLight121Enabled = {
                                type = "toggle",
                                width = 'full',
                                name = "Status indicator light",
                                desc = "Show the small circle above each MUF for range (yellow), failed/uncleared cure (red), and successful cleanse (green). Turning this off hides the light and restores the original party/raid MUF spacing from before status lights were added.",
                                get = function() return D.profile and D.profile.StatusLight121Enabled == true end,
                                set = function(info, value)
                                    if D.Set121MUFStatusLightEnabled then
                                        D:Set121MUFStatusLightEnabled(value and true or false)
                                    else
                                        D.profile.StatusLight121Enabled = value and true or false
                                    end
                                end,
                                disabled = "disabled",
                                order = 1317,
                            },
                            DebuffsFrameElemBorderShow = {
                                type = "toggle",
                                name = L["OPT_SHOWBORDER"],
                                desc = L["OPT_SHOWBORDER_DESC"],
                                order = 1350,
                            },
                            Environment121Mode = {
                                type = 'select',
                                name = "Environment mode",
                                desc = "Automatically tune Decursive for Raid, Mythic+, Dungeon, PvP, or Open World. Automatic detects the current activity. Manual choices lock Decursive to that environment profile until changed.",
                                values = {
                                    AUTO = "Automatic",
                                    RAID = "Raid",
                                    MYTHIC_PLUS = "Mythic+",
                                    DUNGEON = "Dungeon",
                                    PVP = "PvP",
                                    OPEN_WORLD = "Open World",
                                },
                                get = function()
                                    if D.Get121EnvironmentMode then return select(1, D:Get121EnvironmentMode()) end
                                    return D.profile.Environment121Mode or "AUTO"
                                end,
                                set = function(info, value)
                                    if D.Set121EnvironmentMode then D:Set121EnvironmentMode(value) else D.profile.Environment121Mode = value end
                                end,
                                disabled = function()
                                    if D.Status.Combat then return true end
                                    return false
                                end,
                                order = 1349,
                            },
                            Environment121ActiveProfile = {
                                type = 'description',
                                name = function()
                                    if D.Get121EnvironmentMode then
                                        local setting, active, displayName = D:Get121EnvironmentMode()
                                        local suffix = setting == "AUTO" and " (automatic)" or " (manual)"
                                        return "|cFF55DDDDActive profile: " .. (displayName or active or "Open World") .. suffix .. "|r\nDetection, reaction, range, and cooldown settings below are saved separately for the active environment profile."
                                    end
                                    return ""
                                end,
                                order = 1350,
                            },
                            Detection121Mode = {
                                type = 'description',
                                name = "|cFF55DDDDDetection policy: Strict Managed|r\nWoW 12.1 dispel detection always uses Blizzard AuraContainer/AuraButton filtering. Legacy aura enumeration is disabled on 12.1 so protected/secret aura data is never required.",
                                order = 1350.10,
                            },
                            SecondaryAffliction121Enabled = {
                                type = 'toggle',
                                name = "Show secondary simultaneous affliction",
                                desc = "Allow a second simultaneous dispellable affliction to use the managed secondary border. This affects newly initialized managed MUFs; /reload is recommended after changing it.",
                                get = function() return D.profile.CooldownPriority2Border121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("SecondaryAffliction121Enabled", v) end
                                    D.profile.CooldownPriority2Border121Enabled = v
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.20,
                            },
                            SecondaryAffliction121Pulse = {
                                type = 'toggle',
                                name = "Pulse secondary affliction",
                                desc = "Pulse the secondary-affliction border for this environment profile. /reload is recommended after changing live managed-border behavior.",
                                get = function() return D.profile.CooldownPriority2Pulse121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("SecondaryAffliction121Pulse", v) end
                                    D.profile.CooldownPriority2Pulse121Enabled = v
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownPriority2Border121Enabled == false end,
                                order = 1350.30,
                            },
                            SharedPriorityCooldown121Enabled = {
                                type = 'toggle',
                                name = "Share cooldown with same-priority afflicted MUFs",
                                desc = "When enabled, other units still requiring the same Decursive curing priority may receive the shared cooldown indication. Matching is performed by Blizzard managed dispel-type filters; protected aura details are not read by addon Lua.",
                                get = function() return D.profile.SharedPriorityCooldown121Enabled == true end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("SharedPriorityCooldown121Enabled", v) else D.profile.SharedPriorityCooldown121Enabled = v end
                                    if D.Refresh121SharedPriorityCooldowns then D:Refresh121SharedPriorityCooldowns() end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.40,
                            },
                            ClearCleansedTarget121Enabled = {
                                type = 'toggle',
                                name = "Clear cleansed target visual immediately",
                                desc = "The successfully cleansed MUF always clears immediately and is never given a cooldown overlay. Other still-dispellable MUFs receive the cooldown overlay while your cure is unavailable.",
                                get = function() return D.profile.ClearCleansedTarget121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("ClearCleansedTarget121Enabled", v) else D.profile.ClearCleansedTarget121Enabled = v end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.50,
                            },
                            TextAlerts121Enabled = {
                                type = 'toggle',
                                name = "Show on-screen text alerts",
                                desc = "Master switch for Decursive's DISPEL and Soul Link center-screen text in this environment profile. PvP defaults off. Sound notifications and MUF indicators are unaffected, and options previews still display.",
                                get = function() return D.profile.TextAlerts121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("TextAlerts121Enabled", v) else D.profile.TextAlerts121Enabled = v end
                                    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
                                    if not v and D.Hide121AlertWarning then D:Hide121AlertWarning() end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.55,
                            },
                            EnvironmentChat121Enabled = {
                                type = 'toggle',
                                name = "Announce environment/profile changes",
                                desc = "Print a Decursive message when automatic or manual environment selection changes the active behavior profile.",
                                get = function() return D.profile.EnvironmentChat121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("EnvironmentChat121Enabled", v) else D.profile.EnvironmentChat121Enabled = v end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.60,
                            },
                            ProfileBehaviorHint121 = {
                                type = 'description',
                                name = "|cFFAAAAAAThese controls are stored in the active environment profile. Unsafe options that attempt to read protected/secret aura details are intentionally not provided.|r",
                                order = 1350.70,
                            },
                            ResetEnvironment121Profile = {
                                type = 'execute',
                                name = "Reset active environment profile",
                                desc = "Restore the recommended range and cooldown defaults for the environment profile currently being edited.",
                                func = function()
                                    if D.Reset121EnvironmentProfile then D:Reset121EnvironmentProfile() end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1350.5,
                            },
                            OutOfRange121Enabled = {
                                type = 'toggle',
                                name = "Dim MUFs when out of range",
                                desc = "Inside dungeons, raids, battlegrounds, and arenas, dim the MUF while that unit is outside normal friendly-spell range. Range feedback is always suppressed in the open world.",
                                get = function() return D.profile.OutOfRange121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("OutOfRange121Enabled", v) else D.profile.OutOfRange121Enabled = v end
                                    if D.Set121OutOfRangeEnabled then D:Set121OutOfRangeEnabled(v) end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1351,
                            },
                            OutOfRange121DimAmount = {
                                type = 'range',
                                name = "Out-of-range dim amount",
                                desc = "Controls how strongly out-of-range MUFs are darkened. Higher values make the priority color darker.",
                                min = 0.10,
                                max = 0.90,
                                step = 0.05,
                                isPercent = true,
                                get = function() return D.profile.OutOfRange121DimAmount or .60 end,
                                set = function(info, value)
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("OutOfRange121DimAmount", value) else D.profile.OutOfRange121DimAmount = value end
                                    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.OutOfRange121Enabled == false end,
                                order = 1352,
                            },
                            OutOfRange121Color = {
                                type = 'color',
                                name = "Out-of-range overlay color",
                                desc = "Choose the tint placed over an out-of-range MUF. Yellow is the default so an out-of-range unit is immediately recognizable.",
                                hasAlpha = false,
                                get = function()
                                    local c = D.profile.OutOfRange121Color or {1, 1, 0}
                                    return c[1] or 0, c[2] or 0, c[3] or 0
                                end,
                                set = function(info, r, g, b)
                                    local c = {r, g, b}
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("OutOfRange121Color", c) else D.profile.OutOfRange121Color = c end
                                    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.OutOfRange121Enabled == false end,
                                order = 1353,
                            },
                            ResetOutOfRange121Color = {
                                type = 'execute',
                                name = "Reset out-of-range color",
                                desc = "Restore the default yellow range tint and 60% range overlay amount.",
                                func = function()
                                    if D.Set121EnvironmentVisualSetting then
                                        D:Set121EnvironmentVisualSetting("OutOfRange121Color", {1, 1, 0})
                                        D:Set121EnvironmentVisualSetting("OutOfRange121DimAmount", .60)
                                    else
                                        D.profile.OutOfRange121Color = {1, 1, 0}
                                        D.profile.OutOfRange121DimAmount = .60
                                    end
                                    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1354,
                            },
                            CooldownOverlay121Enabled = {
                                type = "toggle",
                                name = "Dispel cooldown on remaining targets",
                                desc = "After you cleanse one MUF, that square clears immediately. If other MUFs still need the same cure priority, they receive the faded cooldown overlay and countdown until your dispel is ready again.",
                                get = function() return D.profile.CooldownOverlay121Enabled ~= false end,
                                set = function(info, value)
                                    local v = value and true or false;
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("CooldownOverlay121Enabled", v) else D.profile.CooldownOverlay121Enabled = v end
                                    if D.Set121CooldownOverlayEnabled then
                                        D:Set121CooldownOverlayEnabled(v);
                                    end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1355,
                            },
                            SoulLink121Enabled = {
                                type = "toggle",
                                name = "Battle rez on dead allies",
                                desc = "Clicking a dead ally's square tries your battle-rez spell (if you know one), then falls back to the Emergency Soul Link item (Midnight Engineering), instead of the useless cure-spell click. Also shows a persistent yellow dot on that square, and an on-screen alert if you try while out of the item's 5-yard range.",
                                get = function() return not D.profile or D.profile.SoulLink121Enabled ~= false end,
                                set = function(info, value)
                                    D.profile.SoulLink121Enabled = value and true or false
                                    if D.UpdateMacro then D:UpdateMacro() end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1355.5,
                            },
                            CooldownOverlay121Opacity = {
                                type = 'range',
                                name = "Inner cooldown priority tint opacity",
                                desc = "Adjust the opacity of the faded priority-color cooldown tint shown on other still-dispellable MUFs while your cure is on cooldown.",
                                min = 0.10,
                                max = 1,
                                step = 0.05,
                                isPercent = true,
                                get = function() return D.profile.CooldownOverlay121Opacity or .62 end,
                                set = function(info, value)
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("CooldownOverlay121Opacity", value) else D.profile.CooldownOverlay121Opacity = value end
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false end,
                                order = 1356,
                            },
                            CooldownOverlay121Numbers = {
                                type = 'toggle',
                                name = "Show cooldown countdown number",
                                desc = "Show the white numeric cooldown countdown on other still-dispellable MUFs after a successful cleanse.",
                                get = function() return D.profile.CooldownOverlay121Numbers ~= false end,
                                set = function(info, value)
                                    local v = value and true or false
                                    if D.Set121EnvironmentVisualSetting then D:Set121EnvironmentVisualSetting("CooldownOverlay121Numbers", v) else D.profile.CooldownOverlay121Numbers = v end
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false end,
                                order = 1357,
                            },
                            CooldownPriority2Border121Enabled = {
                                type = 'toggle',
                                name = "Show secondary-affliction border",
                                desc = "Show one border only when the same target has a second simultaneous dispellable affliction. Blizzard supplies that affliction's priority color.",
                                get = function() return D.profile.CooldownPriority2Border121Enabled ~= false end,
                                set = function(info, value)
                                    D.profile.CooldownPriority2Border121Enabled = value and true or false;
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false end,
                                order = 1358,
                            },
                            CooldownBorder121Alpha = {
                                type = 'range',
                                name = "Secondary border opacity",
                                desc = "Adjust the opacity of the secondary-affliction border.",
                                min = .1,
                                max = 1,
                                step = .05,
                                isPercent = true,
                                get = function() return D.profile.CooldownBorder121Alpha or .95 end,
                                set = function(info, value)
                                    D.profile.CooldownBorder121Alpha = value;
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false or D.profile.CooldownPriority2Border121Enabled == false end,
                                order = 1359,
                            },
                            CooldownBorder121Thickness = {
                                type = 'range',
                                name = "Secondary border thickness",
                                desc = "Adjust the thickness of the one secondary-affliction border around each MUF.",
                                min = 1,
                                max = 5,
                                step = 1,
                                get = function() return D.profile.CooldownBorder121Thickness or 2 end,
                                set = function(info, value)
                                    D.profile.CooldownBorder121Thickness = value;
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false or D.profile.CooldownPriority2Border121Enabled == false end,
                                order = 1360,
                            },
                            CooldownPriority2Pulse121Enabled = {
                                type = 'toggle',
                                name = "Pulse secondary-affliction border",
                                desc = "Pulse the border when a target has a second simultaneous dispellable affliction. This also applies to the MUF visual test.",
                                get = function() return D.profile.CooldownPriority2Pulse121Enabled ~= false end,
                                set = function(info, value)
                                    D.profile.CooldownPriority2Pulse121Enabled = value and true or false;
                                    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
                                end,
                                disabled = function() return D.Status.Combat or D.profile.CooldownOverlay121Enabled == false or D.profile.CooldownPriority2Border121Enabled == false end,
                                order = 1360.5,
                            },
                            Test121MUFSelect = {
                                type = 'select',
                                name = "MUF square to test",
                                desc = "Choose one currently visible Micro Unit Frame to preview by itself.",
                                values = function()
                                    if D.Get121MUFTestChoices then return D:Get121MUFTestChoices() end
                                    return { [1] = "No visible MUFs" }
                                end,
                                get = function()
                                    if D.Get121MUFTestIndex then return D:Get121MUFTestIndex() end
                                    return 1
                                end,
                                set = function(info, value)
                                    if D.Set121MUFTestIndex then D:Set121MUFTestIndex(value) end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1361,
                            },
                            Test121MUFVisualsOne = {
                                type = 'execute',
                                name = "Test selected MUF square",
                                desc = "Preview the two-layer model: primary affliction in the inner square and one pulsing border for a second simultaneous affliction.",
                                func = function()
                                    if D.Test121MUFVisuals then D:Test121MUFVisuals("one", D:Get121MUFTestIndex()) end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1362,
                            },
                            Test121MUFVisualsAll = {
                                type = 'execute',
                                name = "Test ALL MUF squares",
                                desc = "Preview the two-layer model on every visible MUF: inner square for the primary affliction and one pulsing border for a second simultaneous affliction.",
                                func = function()
                                    if D.Test121MUFVisuals then D:Test121MUFVisuals("all") end
                                end,
                                disabled = function() return D.Status.Combat end,
                                order = 1363,
                            },
                            CenterTextDisplay = {
                                type = "select",
                                style = "dropdown",
                                name = L["OPT_CENTERTEXT"],
                                desc = L["OPT_CENTERTEXT_DESC"],
                                values = {["1_TLEFT"] = L["OPT_CENTERTEXT_TIMELEFT"], ["2_TELAPSED"] = L["OPT_CENTERTEXT_ELAPSED"], ["3_STACKS"] = L["OPT_CENTERTEXT_STACKS"], ["4_NONE"] = L["OPT_CENTERTEXT_DISABLED"]},
                                order = 1365,
                            },
                            Show_Stealthed_Status = {
                                type = "toggle",
                                name =  L["OPT_SHOW_STEALTH_STATUS"],
                                desc = L["OPT_SHOW_STEALTH_STATUS_DESC"],
                                order = 1370,
                                disabled = false,
                            },
                            AfflictionTooltips = {
                                type = "toggle",
                                name = L["SHOW_TOOLTIP"],
                                desc = L["OPT_SHOWTOOLTIP_DESC"],
                                disabled = function() return D.profile.HideLiveList and not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1 end,
                                order = 1400,
                            },
                            DebuffsFrameShowHelp = {
                                type = "toggle",
                                name = L["OPT_SHOWHELP"],
                                desc = L["OPT_SHOWHELP_DESC"],
                                disabled = false,
                                order = 1450,
                            },
                            DebuffsFrameMaxCount = {
                                type = 'range',
                                name = L["OPT_MAXMFS"],
                                desc = L["OPT_MAXMFS_DESC"],
                                min = 1,
                                max = 82,
                                step = 1,
                                disabled = "disabled",
                                order = 1500,
                            },
                            DebuffsFramePerline = {
                                type = 'range',
                                name = L["OPT_UNITPERLINES"],
                                desc = L["OPT_UNITPERLINES_DESC"],
                                min = 1,
                                max = 40,
                                step = 1,
                                disabled = "disabled",
                                order = 1600,
                            },
                            DebuffsFrameRaidAutoLayout121 = {
                                type = 'toggle',
                                name = "Automatic raid grid",
                                desc = "For raids larger than 5 players, automatically reflow MUFs into a compact grid of at most five rows. A 40-player raid becomes 8 columns by 5 rows. Decursive controls unit order and grid shape.",
                                disabled = "disabled",
                                order = 1605,
                            },
                            DebuffsFramePartyPixelSize121 = {
                                type = 'range',
                                name = "Party MUF size (pixels)",
                                desc = "Size of each Micro Unit Frame when you are not in a raid. This includes normal parties, dungeons, Mythic+, follower dungeons, open world, and solo play. It applies immediately in those contexts; while in a raid it is saved for the next non-raid context.",
                                min = 10,
                                max = 80,
                                step = 1,
                                get = function()
                                    if D.MicroUnitF and D.MicroUnitF.GetContextMUFSizePixels then
                                        return D.MicroUnitF:GetContextMUFSizePixels("PARTY");
                                    end
                                    return math.floor((D.profile.DebuffsFrameElemScale or 1) * (DC.MFSIZE or 20) + 0.5);
                                end,
                                set = function(info, value)
                                    if D.Status.Combat then return false end
                                    if D.MicroUnitF and D.MicroUnitF.SetContextMUFSizePixels then
                                        return D.MicroUnitF:SetContextMUFSizePixels("PARTY", value);
                                    end
                                    return false;
                                end,
                                disabled = "disabled",
                                order = 1780,
                            },
                            DebuffsFrameRaidPixelSize121 = {
                                type = 'range',
                                name = "Raid MUF size (pixels)",
                                desc = "Size of each Micro Unit Frame whenever WoW reports that you are in a raid. It applies immediately in a raid; outside a raid it is saved and applies automatically the next time you join one.",
                                min = 10,
                                max = 80,
                                step = 1,
                                get = function()
                                    if D.MicroUnitF and D.MicroUnitF.GetContextMUFSizePixels then
                                        return D.MicroUnitF:GetContextMUFSizePixels("RAID");
                                    end
                                    return math.floor((D.profile.DebuffsFrameElemScale or 1) * (DC.MFSIZE or 20) + 0.5);
                                end,
                                set = function(info, value)
                                    if D.Status.Combat then return false end
                                    if D.MicroUnitF and D.MicroUnitF.SetContextMUFSizePixels then
                                        return D.MicroUnitF:SetContextMUFSizePixels("RAID", value);
                                    end
                                    return false;
                                end,
                                disabled = "disabled",
                                order = 1785,
                            },
                            ResetDebuffsFrameContextPixelSizes121 = {
                                type = 'execute',
                                name = "Reset Party & Raid sizes (20 px)",
                                desc = "Reset both Party and Raid Micro Unit Frame sizes to Decursive's original 20 pixel size.",
                                func = function()
                                    if D.Status.Combat then return end
                                    if D.MicroUnitF and D.MicroUnitF.SetContextMUFSizePixels then
                                        D.MicroUnitF:SetContextMUFSizePixels("PARTY", 20);
                                        D.MicroUnitF:SetContextMUFSizePixels("RAID", 20);
                                        D.MicroUnitF:ApplyContextMUFScale();
                                    end
                                end,
                                disabled = "disabled",
                                order = 1790,
                            },
                            -- Retained internally for backward compatibility. The v11 UI
                            -- exposes the separate Party/Raid pixel controls above.
                            DebuffsFramePixelSize = {
                                type = 'range',
                                name = "MUF square size (pixels)",
                                desc = "Legacy single MUF size control.",
                                min = 10,
                                max = 80,
                                step = 1,
                                hidden = true,
                                guiHidden = true,
                                get = function()
                                    if D.MicroUnitF and D.MicroUnitF.GetActiveMUFSizePixels then
                                        return D.MicroUnitF:GetActiveMUFSizePixels();
                                    end
                                    return math.floor((D.profile.DebuffsFrameElemScale or 1) * (DC.MFSIZE or 20) + 0.5);
                                end,
                                set = function(info, value)
                                    if D.Status.Combat then return end
                                    if D.MicroUnitF and D.MicroUnitF.SetActiveContextMUFSizePixels then
                                        D.MicroUnitF:SetActiveContextMUFSizePixels(value);
                                    end
                                end,
                                disabled = "disabled",
                                order = 1795,
                            },
                            ResetDebuffsFramePixelSize = {
                                type = 'execute',
                                name = "Reset MUF size (20 px)",
                                desc = "Legacy single-size reset.",
                                hidden = true,
                                guiHidden = true,
                                func = function()
                                    if D.Status.Combat then return end
                                    if D.MicroUnitF and D.MicroUnitF.SetActiveContextMUFSizePixels then
                                        D.MicroUnitF:SetActiveContextMUFSizePixels(20);
                                    end
                                end,
                                disabled = "disabled",
                                order = 1796,
                            },
                            DebuffsFrameElemScale = {
                                type = 'range',
                                name = L["OPT_MFSCALE"],
                                desc = L["OPT_MFSCALE_DESC"],
                                hidden = true,
                                guiHidden = true,
                                min = 0.3,
                                max = 4,
                                step = 0.01,
                                isPercent = true,
                                disabled = "disabled",
                                order = 1800,
                            },
                            DebuffsFrameElemAlpha = {
                                type = 'range',
                                name = L["OPT_MFALPHA"],
                                desc = L["OPT_MFALPHA_DESC"],
                                get = function() return 1 - D.profile.DebuffsFrameElemAlpha end,
                                set = function(info,v)
                                    D.SetHandler(info, 1 - v);
                                    D.profile.DebuffsFrameElemBorderAlpha = (1 - v) / 2;
                                end,
                                disabled = function() return D.Status.Combat or not D.profile.DebuffsFrameElemTieTransparency end,
                                min = 0,
                                max = 1,
                                step = 0.01,
                                isPercent = true,
                                order = 1900,
                            },
                            TestLayout = {
                                type = "toggle",
                                name = L["OPT_TESTLAYOUT"],
                                desc = L["OPT_TESTLAYOUT_DESC"],
                                get = function() return D.Status.TestLayout end,
                                set = function(info,v)
                                    D.Status.TestLayout = v;
                                    D:GroupChanged("Test Layout");
                                end,
                                disabled = function() return D.Status.Combat or not D.profile.ShowDebuffsFrame end,
                                order = 1950,
                            },
                            TestLayoutUNum = {
                                type = 'range',
                                name = L["OPT_TESTLAYOUTUNUM"],
                                desc = L["OPT_TESTLAYOUTUNUM_DESC"],
                                get = function() return D.Status.TestLayoutUNum end,
                                set = function(info,v)
                                    D.Status.TestLayoutUNum = v;
                                    D:GroupChanged("Test Layout num changed");
                                end,
                                disabled = function() return D.Status.Combat or not D.profile.ShowDebuffsFrame or not D.Status.TestLayout end,
                                min = 1,
                                max = 82,
                                step = 1,
                                order = 2000,
                            },
                            -- }}}
                        },
                    },

                    AdvDispOptions = {
                        type = "group",
                        inline = true,
                        name = L["OPT_ADVDISP"],
                        desc = L["OPT_ADVDISP_DESC"],
                        order = 2,
                        disabled = function () return not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1; end,
                        args = {
                            -- {{{
                            TransparencyOpts = {
                                type = 'group',
                                inline = true,
                                order = 1,
                                name = " ",
                                args = {
                                    DebuffsFrameElemTieTransparency = {
                                        type = "toggle",
                                        name = L["OPT_TIECENTERANDBORDER"],
                                        desc = L["OPT_TIECENTERANDBORDER_OPT"],
                                        set = function(info,v)
                                            D.SetHandler(info,v);
                                            if v then
                                                D.profile.DebuffsFrameElemBorderAlpha = (D.profile.DebuffsFrameElemAlpha / 2);
                                            end
                                        end,
                                        order = 100
                                    },
                                    DebuffsFrameElemBorderAlpha = {
                                        type = 'range',
                                        name = L["OPT_BORDERTRANSP"],
                                        desc = L["OPT_BORDERTRANSP_DESC"],
                                        get = function() return 1 - D.profile.DebuffsFrameElemBorderAlpha end,
                                        set = function(info,v)
                                            D.SetHandler(info,1 - v);
                                        end,
                                        disabled = function() return D.profile.DebuffsFrameElemTieTransparency end,
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        isPercent = true,
                                        order = 102,
                                    },
                                    DebuffsFrameElemAlpha = {
                                        type = 'range',
                                        name = L["OPT_CENTERTRANSP"],
                                        desc = L["OPT_CENTERTRANSP_DESC"],
                                        get = function() return 1 - D.profile.DebuffsFrameElemAlpha end,
                                        set = function(info,v)
                                            D.SetHandler(info,1 - v);

                                            if D.profile.DebuffsFrameElemTieTransparency then
                                                D.profile.DebuffsFrameElemBorderAlpha = (1 - v) / 2;
                                            end
                                        end,
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        isPercent = true,
                                        order = 101,
                                    },
                                },
                            },
                            SpacingOpts = {
                                type = 'group',
                                inline = true,
                                name = " ",
                                order = 2,
                                disabled = function() return D.Status.Combat end,
                                args = {
                                    combatwarning = CombatWarning,
                                    DebuffsFrameTieSpacing = {
                                        type = "toggle",
                                        name = L["OPT_TIEXYSPACING"],
                                        desc = L["OPT_TIEXYSPACING_DESC"] .. "\n\nWhen enabled, Vertical spacing is locked and follows Horizontal spacing.",
                                        set = function(info,v)
                                            D.SetHandler(info, v);
                                            if v then
                                                D.profile.DebuffsFrameYSpacing = D.profile.DebuffsFrameXSpacing;
                                            end
                                            D.MicroUnitF:ResetAllPositions ();
                                            return true;
                                        end,
                                        order = 104
                                    },
                                    DebuffsFrameXSpacing = {
                                        type = 'range',
                                        name = L["OPT_XSPACING"],
                                        desc = function()
                                            if D.profile.DebuffsFrameTieSpacing then
                                                return L["OPT_XSPACING_DESC"] .. "\n\nSpacing is tied, so this value also controls vertical spacing.";
                                            end
                                            return L["OPT_XSPACING_DESC"];
                                        end,
                                        set = function(info,v)
                                            D.SetHandler(info, v);
                                            if D.profile.DebuffsFrameTieSpacing then
                                                D.profile.DebuffsFrameYSpacing = v;
                                            end
                                            D.MicroUnitF:ResetAllPositions ();
                                            return true;
                                        end,
                                        min = 0,
                                        max = 100,
                                        step = 1,
                                        order = 105,
                                    },
                                    DebuffsFrameYSpacing = {
                                        type = 'range',
                                        name = L["OPT_YSPACING"],
                                        desc = L["OPT_YSPACING_DESC"],
                                        get = function(info)
                                            if D.profile.DebuffsFrameTieSpacing then
                                                return D.profile.DebuffsFrameXSpacing;
                                            end
                                            return D.GetHandler(info);
                                        end,
                                        set = function(info,v)
                                            D.SetHandler(info, v);

                                            D.MicroUnitF:ResetAllPositions ();
                                            return true;
                                        end,
                                        disabled = function() return D.Status.Combat or D.profile.DebuffsFrameTieSpacing end,
                                        min = 0,
                                        max = 100,
                                        step = 1,
                                        order = 106,
                                    }, -- }}}
                                },
                            },
                        },
                    },

                    MUFsColors = {
                        type = "group",
                        name = L["OPT_MUFSCOLORS"],
                        desc = L["OPT_MUFSCOLORS_DESC"],
                        order = 3,
                        disabled = function() return D.Status.Combat or not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1;end,
                        hidden = function () return not D:IsEnabled(); end,
                        args = {
                            description = {
                                type = 'description',
                                name = L["OPT_MUFSCOLORS_DESC"],
                                order = 0,
                            },
                            separationLine = {
                                type = 'header',
                                name = "",
                                order = 1,
                            },
                        },
                    },

                    PerfOptions = {
                        type = "group",
                        name = L["OPT_MFPERFOPT"],
                        order = 3,
                        disabled = function () return not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1; end,
                        args = {
                            -- {{{
                            Warning = {
                                type = "description",
                                name = D:ColorText(L["OPT_PERFOPTIONWARNING"], "FFFF0000"),
                                order = 2500,
                            },
                            DebuffsFrameRefreshRate = {
                                type = 'range',
                                name = L["OPT_MFREFRESHRATE"],
                                desc = L["OPT_MFREFRESHRATE_DESC"],
                                min = 0.017,
                                max = 1,
                                step = 0.01,
                                order = 2600,
                            },
                            DebuffsFramePerUPdate = {
                                type = 'range',
                                name = L["OPT_MFREFRESHSPEED"],
                                desc = L["OPT_MFREFRESHSPEED_DESC"],
                                min = 1,
                                max = 82,
                                step = 1,
                                order = 2700,
                            },
                            MFScanEverybodyTimer = {
                                type = 'range',
                                name = L["OPT_PERIODICRESCAN"],
                                desc = L["OPT_PERIODICRESCAN_DESC"],
                                min = 0, -- 0 will disable it
                                max = 60,
                                step = 1,
                                order = 2800,
                            },
                            MFScanEverybodyReport = {
                                type = "toggle",
                                name = L["OPT_PERIODICRESCAN_REPORT"],
                                desc = L["OPT_PERIODICRESCAN_REPORT_DESC"],
                                order = 2900,
                            },
                        },
                    }, -- }}}
                },
            }, -- }}}

            CureOptions = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_CURINGOPTIONS"], "FFFF5533"),
                desc = L["OPT_CURINGOPTIONS_DESC"],
                order = 40,
                disabled = function(info)
                    if info[#info] ~= "CureOptions" then
                        return D.Status.Combat
                    else
                        return false;
                    end
                end,
                --childGroups = 'tab',
                args = {
                    description = {name = L["OPT_CURINGOPTIONS_DESC"], order = 1, type = "description", disabled = false,},
                    DoNot_Blacklist_Prio_List = {
                        type = "toggle",
                        width = 'full',
                        name =  L["DONOT_BL_PRIO"],
                        desc = L["OPT_DONOTBLPRIO_DESC"],
                        order = 131
                    },
                    Scan_Pets = {
                        type = "toggle",
                        width = 'full',
                        name = L["CURE_PETS"],
                        desc = L["OPT_CUREPETS_DESC"],
                        order = 133
                    },

                    CureOrder = {
                        type="group",
                        name = L["OPT_CURINGORDEROPTIONS"],
                        order = 139,
                        inline = true,
                        disabled = function(info)
                            if info[#info] ~= "CureOrder" then
                                return D.Status.Combat
                            else
                                return false;
                            end
                        end,
                        args = {
                            combatwarning = CombatWarning,
                            description = {
                                type = "description",
                                name = L["OPT_CURINGOPTIONS_EXPLANATION"],
                                order = 140,
                            },
                            CureMagic = {
                                type = "toggle",
                                name = "  "..L["MAGIC"],
                                desc = L["OPT_MAGICCHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.MAGIC) end,
                                set = function()
                                    D:SetCureOrder (DC.MAGIC);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.MAGIC] or D.Status.Combat end,
                                order = 141
                            },
                            CureEnemyMagic = {
                                type = "toggle",
                                name = "  "..L["MAGICCHARMED"],
                                desc = L["OPT_MAGICCHARMEDCHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.ENEMYMAGIC) end,
                                set = function()
                                    D:SetCureOrder (DC.ENEMYMAGIC);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.ENEMYMAGIC] or D.Status.Combat end,
                                order = 142
                            },
                            CurePoison = {
                                type = "toggle",
                                name = "  "..L["POISON"],
                                desc = L["OPT_POISONCHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.POISON) end,
                                set = function()
                                    D:SetCureOrder (DC.POISON);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.POISON] or D.Status.Combat end,
                                order = 143
                            },
                            CureDisease = {
                                type = "toggle",
                                name = "  "..L["DISEASE"],
                                desc = L["OPT_DISEASECHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.DISEASE) end,
                                set = function()
                                    D:SetCureOrder (DC.DISEASE);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.DISEASE] or D.Status.Combat end,
                                order = 144
                            },
                            CureCurse = {
                                type = "toggle",
                                name = "  "..L["CURSE"],
                                desc = L["OPT_CURSECHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.CURSE) end,
                                set = function()
                                    D:SetCureOrder (DC.CURSE);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.CURSE] or D.Status.Combat end,
                                order = 145
                            },
                            CureCharmed = {
                                type = "toggle",
                                name = "  "..L["CHARM"],
                                desc = L["OPT_CHARMEDCHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.CHARMED) end,
                                set = function()
                                    D:SetCureOrder (DC.CHARMED);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.CHARMED] or D.Status.Combat end,
                                order = 146
                            },
                            CureBleed = {
                                type = "toggle",
                                name = "  "..L["BLEED"],
                                desc = L["OPT_BLEEDCHECK_DESC"],
                                get = function() return D:GetCureTypeStatus(DC.BLEED) end,
                                set = function()
                                    D:SetCureOrder (DC.BLEED);
                                end,
                                disabled = function() return not D.Status.CuringSpells[DC.BLEED] or D.Status.Combat end,
                                order = 147
                            },

                        },
                    },
                    BleedEffects = {
                        type = 'group',
                        name = L["OPT_BLEED_EFFECT_HOLDER"],
                        desc = L["OPT_BLEED_EFFECT_HOLDER_DESC"],
                        order = 175,
                        --inline = true,
                        childGroups = 'tab',
                        args = {
                            enableDetection = {
                                type = 'toggle',
                                width = 'full',
                                name = L["OPT_ENABLE_BLEED_EFFECTS_DETECTION"],
                                desc = L["OPT_ENABLE_BLEED_EFFECTS_DETECTION_DESC"],
                                get = function() return D.db.global.BleedAutoDetection; end,
                                set = function(info, v) D.db.global.BleedAutoDetection = v end,
                                disabled = function () return not D.Status.CuringSpells[DC.BLEED] end,
                                order = 0,
                            },
                            bleedkeywords = {
                                type = 'input',
                                multiline = true,
                                name = L["OPT_BLEED_EFFECT_IDENTIFIERS"],
                                desc = L["OPT_BLEED_EFFECT_IDENTIFIERS_DESC"],
                                width = 1.5,
                                get = function(info)
                                    return D.db.locale.BleedEffectsKeywords and D.db.locale.BleedEffectsKeywords or "";
                                end,
                                set = function(info, v)
                                    local oldValue = D.db.locale.BleedEffectsKeywords;
                                    local value = v:trim() ~= "" and v:trim() or false;

                                    -- remove empty lines and trim each line
                                    local cleanedValue = value and value:gsub("[\n\r]%s*[\n\r]", "\n"):gsub("[\n\r]%s+", "\n"):gsub("%s+[\n\r]", "\n") or false;

                                    D.db.locale.BleedEffectsKeywords = cleanedValue and cleanedValue or D.defaults.locale.BleedEffectsKeywords;

                                    local newValueOrDefault = D.db.locale.BleedEffectsKeywords;

                                    if newValueOrDefault:trim() ~= "" then
                                        if oldValue ~= newValueOrDefault then
                                            D.Status.P_BleedEffectsKeywords_noCase = D:makeNoCasePattern(newValueOrDefault);
                                            -- if the identifier changes we need to reset the active table
                                            -- so that new stuff can be found if previously ignored
                                            D:reset_t_CheckBleedDebuffsActiveIDs();
                                        end
                                    else
                                        D.Status.P_BleedEffectsKeywords_noCase = false;
                                    end
                                end,
                                validate = function(info, v)
                                    -- test for pattern match exceptions
                                    -- Note that Lua does not validate patterns before using them so they may crash depending
                                    -- on the string being search so we search the provided input text to increase our changes
                                    -- of getting a match but there is no guarantee, there are protections embeded in hasDescBleedEffectkeyword
                                    local _, errorMessage = D:hasDescBleedEffectkeyword(v, D:makeNoCasePattern(v), true);
                                    if not errorMessage then
                                        return true;
                                    else
                                        local cleanedError = errorMessage:gsub("^[^:]+:%d+:%s*", "");
                                        T._ShowNotice(cleanedError);
                                        return cleanedError
                                    end
                                end,
                                disabled = function() return not D.db.global.BleedAutoDetection or not D.Status.CuringSpells[DC.BLEED]; end,

                                order = 10,
                            },
                            sep1 = {
                                type = 'header',
                                name = "",
                                order = 11,
                            },
                            addBleedEffect = {
                                type = 'input',
                                name = L["OPT_ADD_BLEED_EFFECT_ID"],
                                desc = L["OPT_ADD_BLEED_EFFECT_ID_DESC"],
                                set = function(info, v)
                                    D.db.global.t_BleedEffectsIDCheck[TN(v)] = true;
                                    D.Status.t_CheckBleedDebuffsActiveIDs[TN(v)] = true;
                                end,
                                validate = function(info, v)
                                    return TN(v) ~= nil and C_Spell.DoesSpellExist(TN(v)) and 0 or D:ColorPrint(1, 0, 0, L["OPT_BLEED_EFFECT_BAD_SPELLID"]);
                                end,
                                disabled = function () return not D.Status.CuringSpells[DC.BLEED] end,
                                order = 20,
                            },
                            knownBleedingEffects = {
                                type = 'group',
                                width = 'full',
                                name = L["OPT_KNOWN_BLEED_EFFECTS"],
                                order = 40,
                                args = {},

                            },
                        },
                    },
                },
            }, -- }}}

            CustomSpells = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_CUSTOMSPELLS"], "FF00DDDD"),
                desc = L["OPT_CUSTOMSPELLS_DESC"],
                order = 50,
                childGroups = 'tab',
                cmdHidden = true,
                disabled = function(info)
                    if info[#info] ~= "CustomSpells" then
                        return D.Status.Combat
                    else
                        return false;
                    end
                end,
                args = {
                    combatwarning = CombatWarning,
                    explanation = {
                        type = 'description',
                        name = L["OPT_CUSTOMSPELLS_DESC"],
                        order = 1,
                        disabled = false,
                    },
                   CurrentAssignments = {
                        type = 'description',
                        name = function()
                            local MouseButtons = D.db.global.MouseButtons;
                             table.wipe(SpellAssignmentsTexts);
                             SpellAssignmentsTexts[1] = "\n" .. D:ColorText(L["OPT_CUSTOMSPELLS_EFFECTIVE_ASSIGNMENTS"], "FFEEEE33");

                              for Spell, Prio in pairs(D.Status.CuringSpellsPrio) do

                                  local SpellCuredTypes = {};
                                  for typeprio, afflictionType in ipairs(D.Status.ReversedCureOrder) do

                                      if D.Status.CuringSpells[afflictionType] == Spell then
                                          table.insert(SpellCuredTypes, L[DC.TypeToLocalizableTypeNames[afflictionType]])
                                      end
                                  end

                                  SpellCuredTypes = table.concat (SpellCuredTypes, " - ");

                                  SpellAssignmentsTexts[Prio + 1] = str_format(
                                  "\n    %s -> %s%s", D:ColorText(("%s - %s - (%s)"
                                  ):format(
                                  L["OPT_CURE_PRIORITY_NUM"]:format(Prio), SpellCuredTypes, DC.MouseButtonsReadable[MouseButtons[Prio]]
                                  ), D:NumToHexColor(D.profile.MF_colors[Prio])), Spell, (D.Status.FoundSpells[Spell] and D.Status.FoundSpells[Spell][5]) and "|cFFFF0000*|r" or "");
                              end
                              return table.concat(SpellAssignmentsTexts, "\n");
                        end,
                        order = 2,
                    },

                    DetectedDispel121 = {
                        type = 'description',
                        name = function()
                            if D.Get121CooldownDispelSpell then
                                local id, name = D:Get121CooldownDispelSpell();
                                if id then
                                    return "|cFF55DDDD12.1 cooldown dispel detected:|r " .. (name or "Unknown") .. " |cFF888888(" .. tostring(id) .. ")|r";
                                end
                            end
                            return "|cFF55DDDD12.1 cooldown dispel detected:|r |cFFFF5555None|r";
                        end,
                        order = 3,
                    },

                    AddCustomSpell = { -- {{{
                        type = 'input',
                        name = L["OPT_ADD_A_CUSTOM_SPELL"],
                        usage = L["OPT_ADD_A_CUSTOM_SPELL_DESC"],
                        order = 155,
                        width = 'double',
                        set = function(info, v)

                            local errorn, isItem, isPetAbility;
                            errorn, v, isItem, isPetAbility = validateSpellInput(info, v);
                            if errorn ~= 0 then D:Debug("XXXX AHHHHHHHHHHHHHHH!!!!!", errorn); return false end

                            if not D.classprofile.UserSpells[v] or D.classprofile.UserSpells[v].Hidden and CustomSpellMacroEditingAllowed then
                                D:Debug("Adding", v);
                                D.classprofile.UserSpells[v] = {
                                    Types = {},
                                    Better = 10,
                                    Pet = isPetAbility,
                                    Disabled = false,
                                    IsItem = isItem,
                                };

                                if CustomSpellMacroEditingAllowed then

                                    D.classprofile.UserSpells[v].MacroText = ("/stopcasting\n/%s [@UNITID,help][@UNITID,harm]%s"):format(
                                        isItem and "use" or "cast",
                                        D.GetSpellOrItemInfo(v)
                                    );

                                    -- If it's a default spell, then copy the spell settings
                                    if DC.SpellsToUse[v] then
                                        D:tcopy(D.classprofile.UserSpells[v].Types, DC.SpellsToUse[v].Types) -- Types is a table, protect the original
                                        D.classprofile.UserSpells[v].Pet                = DC.SpellsToUse[v].Pet;
                                        D.classprofile.UserSpells[v].EnhancedBy         = DC.SpellsToUse[v].EnhancedBy;
                                        D.classprofile.UserSpells[v].EnhancedByCheck    = DC.SpellsToUse[v].EnhancedByCheck;
                                        D.classprofile.UserSpells[v].Enhancements       = DC.SpellsToUse[v].Enhancements;
                                        if DC.SpellsToUse[v].UnitFiltering then
                                            D.classprofile.UserSpells[v].UnitFiltering = {};
                                            D:tcopy(D.classprofile.UserSpells[v].UnitFiltering, DC.SpellsToUse[v].UnitFiltering) -- UnitFiltering is a table, protect the original
                                        end
                                    end

                                end

                            elseif D.classprofile.UserSpells[v].IsDefault and D.classprofile.UserSpells[v].Hidden then
                                D:Debug("Reactivating", v);
                                D.classprofile.UserSpells[v].Hidden = false;
                                D.classprofile.UserSpells[v].MacroText = nil;
                            end

                            CustomSpellMacroEditingAllowed = false; -- reset macro check box
                        end,
                        validate = validateSpellInput,
                    }, -- }}}

                    IsMacro = {
                        type = 'toggle',
                        name = L["OPT_CUSTOM_SPELL_ALLOW_EDITING"],
                        desc = L["OPT_CUSTOM_SPELL_ALLOW_EDITING_DESC"],
                        order = 160,
                        width = 'full',
                        get = function() return CustomSpellMacroEditingAllowed; end,
                        set = function(info, v) CustomSpellMacroEditingAllowed = v; end,
                    },



                    CustomSpellsHolder = {
                        type = 'group',
                        name = L["OPT_CUSTOMSPELLS"],
                        order = 165,
                        args = {},
                    },

                    MouseBindings = {
                        type = "group",
                        name = L["OPT_MUFMOUSEBUTTONS"],
                        desc = L["OPT_MUFMOUSEBUTTONS_DESC"],
                        order = 170,
                        disabled = function() return D.Status.Combat or not D.profile.ShowDebuffsFrame and D.profile.AutoHideMUFs == 1; end,
                        hidden = function() return not D:IsEnabled(); end,
                        args = {},
                    }
                },
            }, -- }}}

            Compatibility121 = {
                type = "group",
                name = D:ColorText("12.1 Status", "FF55DDDD"),
                desc = "Status and visual tests for the WoW 12.1 Decursive compatibility layer.",
                order = 55,
                args = {
                    Status = {
                        type = 'description',
                        name = function()
                            if D.Get121CompatibilityStatusText then
                                return D:Get121CompatibilityStatusText();
                            end
                            return "WoW 12.1 compatibility layer is not available.";
                        end,
                        order = 1,
                    },
                    Refresh = {
                        type = 'execute',
                        name = "Refresh detected dispel",
                        desc = "Re-resolve the friendly curing spell used by the cooldown overlay and refresh its display.",
                        func = function()
                            if D.Refresh121DispelResolver then D:Refresh121DispelResolver() end
                        end,
                        disabled = function() return D.Status.Combat end,
                        order = 10,
                    },
                    TestMUFSelect = {
                        type = 'select',
                        name = "MUF square to test",
                        desc = "Choose one currently visible Micro Unit Frame to test independently.",
                        values = function()
                            if D.Get121MUFTestChoices then return D:Get121MUFTestChoices() end
                            return { [1] = "No visible MUFs" }
                        end,
                        get = function()
                            if D.Get121MUFTestIndex then return D:Get121MUFTestIndex() end
                            return 1
                        end,
                        set = function(info, value)
                            if D.Set121MUFTestIndex then D:Set121MUFTestIndex(value) end
                        end,
                        disabled = function() return D.Status.Combat end,
                        order = 20,
                    },
                    TestVisualsOne = {
                        type = 'execute',
                        name = "Test selected MUF square",
                        desc = "Test only the selected MUF for 8 seconds. This is visual-only and never inspects protected aura data or casts a spell.",
                        func = function()
                            if D.Test121MUFVisuals then D:Test121MUFVisuals("one", D:Get121MUFTestIndex()) end
                        end,
                        disabled = function() return D.Status.Combat end,
                        order = 21,
                    },
                    TestVisualsAll = {
                        type = 'execute',
                        name = "Test ALL MUF squares",
                        desc = "Test every currently visible MUF simultaneously for 8 seconds. This is visual-only and never inspects protected aura data or casts a spell.",
                        func = function()
                            if D.Test121MUFVisuals then D:Test121MUFVisuals("all") end
                        end,
                        disabled = function() return D.Status.Combat end,
                        order = 22,
                    },
                    DiagnosticHint = {
                        type = 'description',
                        name = "\nFor the original Decursive diagnostic report, use |cFFFFFFFF/dcrdiag|r. The 12.1 status page intentionally reports only public addon/spell state and never protected aura details.",
                        order = 30,
                    },
                },
            },

            DebuffSkip = {
                -- {{{
                type = "group",
                hidden = function () return not D:IsEnabled(); end,
                disabled = function () return not D:IsEnabled(); end,
                name = D:ColorText(L["OPT_DEBUFFFILTER"], "FF99CCAA"),
                desc = L["OPT_DEBUFFFILTER_DESC"],
                order = 60,
                childGroups= "tab",
                args = {}
            }, -- }}}

            Macro = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_MACROOPTIONS"], "FFCC99BB"),
                desc = L["OPT_MACROOPTIONS_DESC"],
                order = 70,
                disabled = function() return not D.Status.Enabled or D.Status.Combat end,
                args = {
                    description = {name = L["OPT_MACROOPTIONS_DESC"], order = 1, type = "description"},
                    SetKey = {
                        type = "keybinding",
                        name = L["OPT_MACROBIND"],
                        desc = L["OPT_MACROBIND_DESC"],
                        get = function ()
                            local key = (GetBindingKey(D.CONF.MACROCOMMAND));
                            D.db.global.MacroBind = key;
                            return key;
                        end,
                        set = function (info,key)
                            if key ~= "BUTTON1" and key ~= "BUTTON2" then
                                D:SetMacroKey ( key );
                            end
                        end,
                        disabled = function () return D.profile.DisableMacroCreation end,
                        order = 200,
                    },
                    NoKeyWarn = {
                        type = "toggle",
                        name = L["OPT_NOKEYWARN"],
                        desc = L["OPT_NOKEYWARN_DESC"],
                        disabled = function () return D.profile.DisableMacroCreation end,
                        order = 300
                    },
                    AllowMacroEdit = {
                        type = "toggle",
                        name = L["OPT_ALLOWMACROEDIT"],
                        desc = L["OPT_ALLOWMACROEDIT_DESC"],
                        disabled = function () return D.profile.DisableMacroCreation end,
                        order = 350
                    },
                    DisableMacroCreation = {
                        type = "toggle",
                        name = L["OPT_DISABLEMACROCREATION"],
                        desc = L["OPT_DISABLEMACROCREATION_DESC"],
                        order = 400
                    }
                }
            }, -- }}}

            About = {
                -- {{{
                type = "group",
                name = D:ColorText(L["OPT_ABOUT"], "FFFFFFFF"),
                order = -1,
                args = {
                    -- Decursive vxx by x released on XX
                    Title = {
                        type = 'description',
                        name = (
                                    "\n\n\n\nDecursive |cFFDD0000 v%s |r by |cFFDD0000 %s |r released on |cFFDD0000 %s |r"..
                                    "\n\n      |cFF55DDDD %s |r"..
                                    "\n\n|cFFDDDD00 %s|r:\n   %s"..
                                    "\n\n|cFFDDDD00 %s|r:\n   %s"..
                                    "\n\n|cFFDDDD00 %s|r:\n   %s"..
                                    "\n\n|cFFDDDD00 %s|r:\n   %s"..
                                    "\n\n|cFFDDDD00 %s|r:\n   %s\n\n   %s\n\n   %s"
                                ):format(
                                    "@project-version@", "Randy Lorfing", ("@project-date-iso@"):sub(1,10),
                                    L["ABOUT_NOTES"],
                                    L["ABOUT_LICENSE"],         GetAddOnMetadata(addonName, "X-License") or 'All Rights Reserved',
                                    L["ABOUT_SHAREDLIBS"],      GetAddOnMetadata(addonName, "X-Embeds")  or 'GetAddOnMetadata() failure',
                                    L["ABOUT_OFFICIALWEBSITE"], GetAddOnMetadata(addonName, "X-Website") or 'GetAddOnMetadata() failure',
                                    L["ABOUT_AUTHOREMAIL"],     GetAddOnMetadata(addonName, "X-eMail")   or 'GetAddOnMetadata() failure',
                                    L["ABOUT_CREDITS"]
                                    ,    "Decursive is inspired from the original \"Decursive v1.9.4\" released in 2006 by Patrick Bohnet (Quutar of Earthen Ring (US))"
                                    ,    "John Wellesz (Decursive AT 2072productions.com) took over Decursive after its first year and maintained and developed it for nearly 20 years, from 2006 to 2025."
                                    ,    GetAddOnMetadata(addonName, "X-Credits") or 'GetAddOnMetadata() failure'
                                ),
                        order = 0,
                    },
                    Sep1 = {
                        type = "header",
                        name = "",
                        order = 5,
                    },
                    CheckVersions = {
                        type = "execute",
                        name = L["OPT_CHECKOTHERPLAYERS"],
                        desc = L["OPT_CHECKOTHERPLAYERS_DESC"],
                        disabled = function () return InCombatLockdown() or GetTime() - T.LastVCheck < 60; end,
                        func = function ()
                            if D:AskVersion() then D.versions = false; end
                            if GameTooltip:IsShown() then GameTooltip:Hide(); end
                        end,
                        order = 10,
                    },
                    VersionsDisplay = {
                        type = "description",
                        name = D.ReturnVersions,
                        hidden = function () return not D.versions; end,
                        order = 30,
                    },

                },
            }, -- }}}
        },
    } -- }}}
end

local function GetOptions()

    local options = GetStaticOptions();

    local CureCheckBoxes = {
        [DC.ENEMYMAGIC]     = options.args.CureOptions.args.CureOrder.args.CureEnemyMagic,
        [DC.MAGIC]          = options.args.CureOptions.args.CureOrder.args.CureMagic,
        [DC.CURSE]          = options.args.CureOptions.args.CureOrder.args.CureCurse,
        [DC.POISON]         = options.args.CureOptions.args.CureOrder.args.CurePoison,
        [DC.DISEASE]        = options.args.CureOptions.args.CureOrder.args.CureDisease,
        [DC.CHARMED]        = options.args.CureOptions.args.CureOrder.args.CureCharmed,
        [DC.BLEED]          = options.args.CureOptions.args.CureOrder.args.CureBleed,
    }

    -- Add the number infront of the checkboxes
    for Type, CheckBox in pairs(CureCheckBoxes) do
        D:SetCureCheckBoxNum(Type, CheckBox);
    end

    -- create per class filters menus
    options.args.DebuffSkip.args = D:CreateFiltersMenu();
    -- create MUF color configuration menus
    D:CreateDropDownMUFcolorsMenu(options.args.MicroFrameOpt.args.MUFsColors.args);
    -- add the affliction color pickers there too
    D:CreateAfflictionColorsMenu(options.args.MicroFrameOpt.args.MUFsColors.args);
    -- create MUF's mouse buttons configuration menus
    options.args.CustomSpells.args.MouseBindings.args = D:CreateModifierOptionMenu();
    -- create curring spells addition submenus
    D:CreateAddedSpellsOptionMenu(options.args.CustomSpells.args.CustomSpellsHolder.args);
    -- create bleeding debuffs addition submenus
    D:CreateBleedingDebuffsOptionMenu(options.args.CureOptions.args.BleedEffects.args.knownBleedingEffects.args);

    -- Create profile options
    options.args.general.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(D.db);
    options.args.general.args.profiles.order = -1;
    options.args.general.args.profiles.inline = true;
    options.args.general.args.profiles.hidden = function() return not D:IsEnabled(); end;
    options.args.general.args.profiles.disabled = function() return D.Status.Combat or not D:IsEnabled(); end;

    -- Zhaohu 12.1: profile sharing uses the existing AceDB profile plus AceSerializer.
    options.args.general.args.profiles.args.DecursiveProfileIO = {
        type = 'group',
        name = 'Import / Export',
        desc = 'Share the active Decursive profile without overwriting global, locale, or class-scoped data.',
        order = 90,
        inline = true,
        args = {
            CurrentProfile = {
                type = 'description',
                name = function()
                    local name = D.db and D.db:GetCurrentProfile() or 'Unknown'
                    return '|cff55ffffCurrent profile:|r |cffffffff' .. tostring(name) .. '|r'
                end,
                order = 1,
            },
            ExportProfile = {
                type = 'input',
                name = 'Export current profile',
                desc = 'Copy this text to share or back up the active Decursive profile.',
                multiline = 8,
                width = 'full',
                get = function() return D:GetProfileExportString() end,
                set = function() end,
                order = 10,
            },
            ImportProfile = {
                type = 'input',
                name = 'Import profile',
                desc = 'Paste a Decursive profile export here, then click Import.',
                multiline = 8,
                width = 'full',
                get = function() return D:GetProfileImportBuffer() end,
                set = function(info, value) D:SetProfileImportBuffer(value) end,
                order = 20,
            },
            ImportButton = {
                type = 'execute',
                name = 'Import',
                desc = 'Replace the settings in the active profile with the pasted profile data.',
                confirm = 'Importing will replace the settings in your current Decursive profile. Continue?',
                func = function() D:ImportProfileString(D:GetProfileImportBuffer()) end,
                disabled = function()
                    return InCombatLockdown() or D:GetProfileImportBuffer():match('^%s*$') ~= nil
                end,
                order = 30,
            },
            IOStatus = {
                type = 'description',
                name = function() return D:GetProfileIOStatus() end,
                order = 40,
            },
        },
    };

    if DC.CATACLYSM or not DC.WOWC then
        -- AceDB already enhanced at Decursive OnEnable; only wire options UI here.
        local LibDualSpec = LibStub('LibDualSpec-1.0');
        if options.args.general.args.profiles then
            LibDualSpec:EnhanceOptions(options.args.general.args.profiles, D.db);
        end
    end

    return options;

end

-- Expose builder for GetV11OptionsTable
D._BuildOptionsTree = GetOptions

