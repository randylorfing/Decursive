--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Alerts page.. This file was solely written by Randy Lorfing.
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
--]]

local T = DecursiveRootTable
if not T or not T.ZhaohuV13 or not T.ZhaohuV13.Options then return end

local V13 = T.ZhaohuV13
local UI = V13.Options
local Controls = UI.Controls
local Theme = V13.Theme
local D = T.Dcr
local ZD = T.ZhaohuModern
local DC = T._C
local addonPath = T._AddonPath or "Interface\\AddOns\\Decursive\\"

local textModes = {
    { key = "TIMED", label = "Timed" },
    { key = "UNTIL_CLEARED", label = "Until cleared" },
}

local soundPresets = {
    { key = "FEMALE_DISPEL", label = "Female Voice - Dispel" },
    { key = "FEMALE_DISPEL_ME", label = "Female Voice - Dispel me" },
    { key = "FEMALE_CLEANSE", label = "Female Voice - Cleanse" },
    { key = "FEMALE_CLEANSE_ME", label = "Female Voice - Cleanse me" },
    { key = "AFFLICTION", label = "Tone - Affliction Alert" },
    { key = "QUICK", label = "Tone - Quick Pulse" },
    { key = "BRIGHT_PING", label = "Tone - Bright Ping" },
    { key = "DOUBLE_PING", label = "Tone - Double Ping" },
    { key = "TRIPLE_PING", label = "Tone - Triple Ping" },
    { key = "HIGH_CHIME", label = "Tone - High Chime" },
    { key = "LOW_CHIME", label = "Tone - Low Chime" },
    { key = "PULSE_UP", label = "Tone - Rising Pulse" },
    { key = "PULSE_DOWN", label = "Tone - Falling Pulse" },
    { key = "FAILURE", label = "Tone - Short Alert" },
}

local soundChannels = {
    { key = "Master", label = "Master" },
    { key = "SFX", label = "Sound Effects" },
    { key = "Dialog", label = "Dialog" },
    { key = "Ambience", label = "Ambience" },
    { key = "Music", label = "Music" },
}

local soundFiles = {
    AFFLICTION = DC and DC.AfflictionSound,
    QUICK = addonPath .. "Sounds\\G_NecropolisWound-fast.ogg",
    FAILURE = DC and DC.FailedSound,
    BRIGHT_PING = addonPath .. "Sounds\\BrightPing.ogg",
    DOUBLE_PING = addonPath .. "Sounds\\DoublePing.ogg",
    TRIPLE_PING = addonPath .. "Sounds\\TriplePing.ogg",
    HIGH_CHIME = addonPath .. "Sounds\\HighChime.ogg",
    LOW_CHIME = addonPath .. "Sounds\\LowChime.ogg",
    PULSE_UP = addonPath .. "Sounds\\PulseUp.ogg",
    PULSE_DOWN = addonPath .. "Sounds\\PulseDown.ogg",
    FEMALE_DISPEL = addonPath .. "Sounds\\FemaleDispel.ogg",
    FEMALE_DISPEL_ME = addonPath .. "Sounds\\FemaleDispelMe.ogg",
    FEMALE_CLEANSE = addonPath .. "Sounds\\FemaleCleanse.ogg",
    FEMALE_CLEANSE_ME = addonPath .. "Sounds\\FemaleCleanseMe.ogg",
}

local function refreshText()
    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
    if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
end

local function environment()
    return ZD.GetEnvironmentProfile and ZD:GetEnvironmentProfile() or nil
end

UI:RegisterPage("ALERTS", "Alerts", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.contentHeight = 1200
    page.eyebrow = Controls:Label(page, "ALERTS & FEEDBACK", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "One event, one presentation path", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "Live alerts and the Test Center use the same size, duration and sound settings.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local text = Controls:Card(page, "Dispel text",
        "Default timed warning: DISPEL for exactly two seconds.")
    text:SetPoint("TOPLEFT", 0, -82)
    text:SetPoint("TOPRIGHT", -8, -82)
    text:SetHeight(260)
    Controls:Toggle(text, "Enable dispel text", nil,
        function() return D.profile and D.profile.Alert121DispelEnabled ~= false end,
        function(value)
            if D.profile then D.profile.Alert121DispelEnabled = value and true or false end
            refreshText()
        end)
    Controls:Cycle(text, "Display mode", function() return textModes end,
        function() return D.profile and D.profile.Alert121DispelMode or "TIMED" end,
        function(value)
            if D.profile then D.profile.Alert121DispelMode = value end
            refreshText()
        end)
    Controls:Stepper(text, "Display duration",
        function() return D.profile and D.profile.Alert121DispelDuration or 2 end,
        function(value)
            if D.profile then D.profile.Alert121DispelDuration = value end
            refreshText()
        end, 0.5, 30, 0.5, "sec")
    Controls:Stepper(text, "Text size",
        function() return D.profile and D.profile.Alert121FontSize or 48 end,
        function(value)
            if D.profile then D.profile.Alert121FontSize = value end
            refreshText()
        end, 12, 96, 1, "px")

    local sound = Controls:Card(page, "Dispel sound",
        "Blizzard plays successfully armed exact-ID alerts on aura Added. Continuing stacks stay silent; Test Sound checks only file/channel playback, and the debounce below applies only to public fallbacks.")
    sound:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    sound:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 0, -12)
    sound:SetHeight(310)
    Controls:Toggle(sound, "Enable sound", nil,
        function() return D.profile and D.profile.PlaySound ~= false end,
        function(value)
            if D.profile then D.profile.PlaySound = value and true or false end
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("v13 sound toggle") end
        end)
    Controls:Cycle(sound, "Alert sound", function() return soundPresets end,
        function() return D.profile and D.profile.SoundNotificationPreset or "FEMALE_DISPEL" end,
        function(value)
            if not D.profile then return end
            D.profile.SoundNotificationPreset = value
            D.profile.SoundFile = soundFiles[value] or (DC and DC.AfflictionSound)
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("v13 sound preset") end
        end)
    Controls:Cycle(sound, "Output channel", function() return soundChannels end,
        function() return D.profile and D.profile.SoundNotificationChannel or "Master" end,
        function(value)
            if D.profile then D.profile.SoundNotificationChannel = value end
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("v13 sound channel") end
        end)
    Controls:Stepper(sound, "Fallback debounce",
        function() return D.profile and D.profile.SoundNotificationIgnoreSeconds or 2 end,
        function(value)
            if D.profile then D.profile.SoundNotificationIgnoreSeconds = value end
        end, 0, 5, 0.25, "sec")
    Controls:Toggle(sound, "Cure-failure sound", nil,
        function() return D.profile and D.profile.PlayFailureSound == true end,
        function(value) if D.profile then D.profile.PlayFailureSound = value and true or false end end)

    local feedback = Controls:Card(page, "Environment feedback",
        "These switches apply to the environment selected on the Profiles page.")
    feedback:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -12)
    feedback:SetPoint("TOPRIGHT", sound, "BOTTOMRIGHT", 0, -12)
    feedback:SetHeight(235)
    Controls:StatusRow(feedback, "Editing", function()
        local key = ZD.GetEditEnvironment and ZD:GetEditEnvironment() or "OPEN_WORLD"
        return V13.SettingsSchema.environmentNames[key] or key
    end, function() return Theme.color.cyan end)
    Controls:Toggle(feedback, "On-screen text alerts", nil,
        function() local env = environment(); return not env or env.TextAlerts121Enabled ~= false end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "TextAlerts121Enabled", value) end)
    Controls:Toggle(feedback, "Chat status messages", nil,
        function() local env = environment(); return not env or env.EnvironmentChat121Enabled ~= false end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "EnvironmentChat121Enabled", value) end)
    Controls:Toggle(feedback, "Out-of-range indication", nil,
        function() local env = environment(); return env and env.OutOfRange121Enabled == true end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "OutOfRange121Enabled", value) end)

    local cooldown = Controls:Card(page, "MUF cooldown overlay",
        "Environment override for the profile currently being edited.")
    cooldown:SetPoint("TOPLEFT", feedback, "BOTTOMLEFT", 0, -12)
    cooldown:SetPoint("TOPRIGHT", feedback, "BOTTOMRIGHT", 0, -12)
    cooldown:SetHeight(205)
    Controls:Toggle(cooldown, "Enable overlay", nil,
        function() local env = environment(); return not env or env.CooldownOverlay121Enabled ~= false end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "CooldownOverlay121Enabled", value) end)
    Controls:Toggle(cooldown, "Countdown numbers", nil,
        function() local env = environment(); return not env or env.CooldownOverlay121Numbers ~= false end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "CooldownOverlay121Numbers", value) end)
    Controls:Stepper(cooldown, "Overlay darkness",
        function() local env = environment(); return env and env.CooldownOverlay121Opacity or 0.62 end,
        function(value) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(), "CooldownOverlay121Opacity", value) end,
        0, 1, 0.05, "")

    function page:Refresh()
        text:Refresh()
        sound:Refresh()
        feedback:Refresh()
        cooldown:Refresh()
    end
    return page
end)
