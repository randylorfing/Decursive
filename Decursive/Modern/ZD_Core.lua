--[[
    This file is part of Decursive.

    Zhaohu's Decursive v11 core module. This file was solely written by
    Randy Lorfing.
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

    Zhaohu's Decursive v11 — Detect • Cleanse • Protect.

    This module deliberately keeps the proven v10.43 Decursive backend active
    while v11 replaces the presentation and orchestration layers module by
    module.  The WoW 12.1 managed-aura engine remains the authority for aura
    visibility and never attempts to recover protected aura details.
--]]

local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if not D or not DC then return end

local ZD = T.ZhaohuModern or {}
T.ZhaohuModern = ZD
D.ZhaohuModern = ZD

ZD.version = "@project-version@"
ZD.build = "single-ui"
ZD.compatBackend = "10.43 feature engine"
ZD.editEnvironment = ZD.editEnvironment or nil
ZD.lastStatus = ZD.lastStatus or "Ready"

local ENV_ORDER = { "OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP" }
local ENV_NAMES = {
    OPEN_WORLD = "Open World",
    DUNGEON = "Dungeon / Follower",
    MYTHIC_PLUS = "Mythic+",
    RAID = "Raid",
    PVP = "PvP",
}

local ENV_DEFAULTS = {
    RAID = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .45,
        OutOfRange121Color = { 1, 1, 0 },
        LineOfSight121Enabled = true,
        LineOfSight121Color = { 1, .28, .12 },
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .50,
        CooldownOverlay121Numbers = false,
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = false,
        SharedPriorityCooldown121Enabled = false,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    MYTHIC_PLUS = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .70,
        OutOfRange121Color = { 1, 1, 0 },
        LineOfSight121Enabled = true,
        LineOfSight121Color = { 1, .28, .12 },
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .70,
        CooldownOverlay121Numbers = true,
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    DUNGEON = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
        OutOfRange121Color = { 1, 1, 0 },
        LineOfSight121Enabled = true,
        LineOfSight121Color = { 1, .28, .12 },
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .60,
        CooldownOverlay121Numbers = true,
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    PVP = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .75,
        OutOfRange121Color = { 1, 1, 0 },
        LineOfSight121Enabled = true,
        LineOfSight121Color = { 1, .28, .12 },
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .65,
        CooldownOverlay121Numbers = true,
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = false,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    OPEN_WORLD = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
        OutOfRange121Color = { 1, 1, 0 },
        LineOfSight121Enabled = true,
        LineOfSight121Color = { 1, .28, .12 },
        LineOfSight121Opacity = .78,
        LineOfSight121HoldSeconds = 2.5,
        CooldownOverlay121Enabled = true,
        CooldownOverlay121Opacity = .62,
        CooldownOverlay121Numbers = true,
        SecondaryAffliction121Enabled = true,
        SecondaryAffliction121Pulse = true,
        SharedPriorityCooldown121Enabled = false,
        ClearCleansedTarget121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
}

ZD.environmentOrder = ENV_ORDER
ZD.environmentNames = ENV_NAMES

local function shallowCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        if type(v) == "table" then
            local inner = {}
            for ik, iv in pairs(v) do inner[ik] = iv end
            out[k] = inner
        else
            out[k] = v
        end
    end
    return out
end

function ZD:SetStatus(text, isError)
    self.lastStatus = text or "Ready"
    self.lastStatusError = isError and true or false
    if self.RefreshUI then self:RefreshUI() end
end

function ZD:CanConfigure(quiet)
    if not D.DcrFullyInitialized or not D.db or not D.profile then
        if not quiet then self:SetStatus("Decursive is still initializing.", true) end
        return false
    end
    if InCombatLockdown() then
        if not quiet then self:SetStatus("Settings are locked during combat.", true) end
        return false
    end
    return true
end


function ZD:GetDetectionProviderStatus()
    if D.Get121DispelDetectionProviderStatus then
        return D:Get121DispelDetectionProviderStatus()
    end
    return {
        sessionProvider = "NATIVE",
        displayName = "Native Blizzard-managed",
        available = true,
        active = true,
        operational = true,
        reason = nil,
    }
end

function ZD:GetUserProfileName()
    if D.db and D.db.GetCurrentProfile then
        return D.db:GetCurrentProfile() or "Default"
    end
    return "Default"
end

function ZD:GetProfiles()
    local profiles = {}
    if D.db and D.db.GetProfiles then
        D.db:GetProfiles(profiles)
    end
    table.sort(profiles)
    return profiles
end

function ZD:SetUserProfile(name)
    if not self:CanConfigure() then return false end
    if type(name) ~= "string" or name == "" then return false end
    D.db:SetProfile(name)
    self:SetStatus("Profile switched to " .. name .. ".")
    return true
end

function ZD:CreateUserProfile(name)
    if not self:CanConfigure() then return false end
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then
        self:SetStatus("Enter a profile name first.", true)
        return false
    end
    D.db:SetProfile(name)
    self:SetStatus("Created profile " .. name .. ".")
    return true
end


function ZD:CloneCurrentProfile(newName)
    if not self:CanConfigure() then return false end
    newName = type(newName) == "string" and newName:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if newName == "" then
        self:SetStatus("Enter a new profile name first.", true)
        return false
    end
    local source = self:GetUserProfileName()
    if newName == source then
        self:SetStatus("Choose a different name for the copy.", true)
        return false
    end
    D.db:SetProfile(newName)
    local ok, err = pcall(D.db.CopyProfile, D.db, source)
    if not ok then
        self:SetStatus("Could not copy profile: " .. tostring(err), true)
        return false
    end
    self:SetStatus("Copied " .. source .. " to " .. newName .. ".")
    return true
end

function ZD:CopyUserProfile(sourceName)
    if not self:CanConfigure() then return false end
    if type(sourceName) ~= "string" or sourceName == "" then return false end
    local ok, err = pcall(D.db.CopyProfile, D.db, sourceName)
    if not ok then
        self:SetStatus("Could not copy profile: " .. tostring(err), true)
        return false
    end
    self:SetStatus("Copied settings from " .. sourceName .. ".")
    return true
end

function ZD:ResetUserProfile()
    if not self:CanConfigure() then return false end
    D.db:ResetProfile()
    self:SetStatus("Current profile reset to defaults.")
    return true
end

function ZD:GetEnvironmentSetting()
    return (D.profile and D.profile.Environment121Mode) or "AUTO"
end

function ZD:GetActiveEnvironment()
    if D.Get121EnvironmentMode then
        local _, active, displayName = D:Get121EnvironmentMode()
        return active or "OPEN_WORLD", displayName or ENV_NAMES[active] or active
    end
    return "OPEN_WORLD", ENV_NAMES.OPEN_WORLD
end

function ZD:SetEnvironmentSetting(mode)
    if not self:CanConfigure() then return false end
    if D.Set121EnvironmentMode then
        D:Set121EnvironmentMode(mode)
    else
        D.profile.Environment121Mode = mode
    end
    self:SetStatus("Environment mode set to " .. (mode == "AUTO" and "Automatic" or (ENV_NAMES[mode] or mode)) .. ".")
    return true
end

function ZD:GetEditEnvironment()
    local active = self:GetActiveEnvironment()
    local key = self.editEnvironment or active
    if not ENV_NAMES[key] then key = "OPEN_WORLD" end
    return key
end

function ZD:SetEditEnvironment(key)
    if ENV_NAMES[key] then
        self.editEnvironment = key
        self:SetStatus("Editing " .. ENV_NAMES[key] .. " behavior.")
        if self.RefreshUI then self:RefreshUI() end
    end
end

function ZD:GetEnvironmentProfile(key)
    key = key or self:GetEditEnvironment()
    if not D.profile then return nil end
    D.profile.Environment121Profiles = D.profile.Environment121Profiles or {}
    D.profile.Environment121Profiles[key] = D.profile.Environment121Profiles[key] or shallowCopy(ENV_DEFAULTS[key] or ENV_DEFAULTS.OPEN_WORLD)
    local env = D.profile.Environment121Profiles[key]
    env.Detection121Mode = "STRICT_MANAGED"
    return env
end

function ZD:ApplyEnvironmentProfileToRuntime(key)
    if not D.profile then return end
    local active = self:GetActiveEnvironment()
    if active ~= key then return end
    local env = self:GetEnvironmentProfile(key)
    if not env then return end

    D.profile.OutOfRange121Enabled = env.OutOfRange121Enabled ~= false
    D.profile.OutOfRange121DimAmount = env.OutOfRange121DimAmount or .60
    if type(env.OutOfRange121Color) == "table" then D.profile.OutOfRange121Color = shallowCopy(env.OutOfRange121Color) end
    D.profile.LineOfSight121Enabled = env.LineOfSight121Enabled ~= false
    if type(env.LineOfSight121Color) == "table" then D.profile.LineOfSight121Color = shallowCopy(env.LineOfSight121Color) end
    D.profile.LineOfSight121Opacity = env.LineOfSight121Opacity or .78
    D.profile.LineOfSight121HoldSeconds = env.LineOfSight121HoldSeconds or 2.5
    D.profile.CooldownOverlay121Enabled = env.CooldownOverlay121Enabled ~= false
    D.profile.CooldownOverlay121Opacity = env.CooldownOverlay121Opacity or .62
    D.profile.CooldownOverlay121Numbers = env.CooldownOverlay121Numbers ~= false
    D.profile.Detection121Mode = "STRICT_MANAGED"
    D.profile.CooldownPriority2Border121Enabled = env.SecondaryAffliction121Enabled ~= false
    D.profile.CooldownPriority2Pulse121Enabled = env.SecondaryAffliction121Pulse ~= false
    D.profile.SharedPriorityCooldown121Enabled = env.SharedPriorityCooldown121Enabled == true
    D.profile.ClearCleansedTarget121Enabled = env.ClearCleansedTarget121Enabled ~= false
    D.profile.EnvironmentChat121Enabled = env.EnvironmentChat121Enabled ~= false

    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
    if D.Set121OutOfRangeEnabled then D:Set121OutOfRangeEnabled(D.profile.OutOfRange121Enabled ~= false) end
    if D.Apply121LineOfSightAppearance then D:Apply121LineOfSightAppearance() end
    if D.Set121LineOfSightEnabled then D:Set121LineOfSightEnabled(D.profile.LineOfSight121Enabled ~= false) end
    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
    if D.Set121CooldownOverlayEnabled then D:Set121CooldownOverlayEnabled(D.profile.CooldownOverlay121Enabled ~= false) end
    if D.Refresh121SharedPriorityCooldowns then D:Refresh121SharedPriorityCooldowns() end
end

function ZD:SetEnvironmentValue(key, setting, value)
    if not self:CanConfigure() then return false end
    local env = self:GetEnvironmentProfile(key)
    if not env then return false end
    env[setting] = shallowCopy(value)
    env.Detection121Mode = "STRICT_MANAGED"
    self:ApplyEnvironmentProfileToRuntime(key)
    self:SetStatus((ENV_NAMES[key] or key) .. " behavior updated.")
    return true
end

function ZD:ResetEnvironmentProfile(key)
    if not self:CanConfigure() then return false end
    key = key or self:GetEditEnvironment()
    local defaults = ENV_DEFAULTS[key]
    local env = self:GetEnvironmentProfile(key)
    if not defaults or not env then return false end
    for k in pairs(env) do env[k] = nil end
    for setting, value in pairs(defaults) do env[setting] = shallowCopy(value) end
    env.Detection121Mode = "STRICT_MANAGED"
    self:ApplyEnvironmentProfileToRuntime(key)
    self:SetStatus((ENV_NAMES[key] or key) .. " behavior reset.")
    return true
end

function ZD:SetProfileOption(key, value)
    if not self:CanConfigure() then return false end
    if not D.profile then return false end

    if key == "ShowDebuffsFrame" then
        if (D.profile.ShowDebuffsFrame and true or false) ~= (value and true or false) and D.ShowHideDebuffsFrame then
            D:ShowHideDebuffsFrame()
        end
        return true
    end

    if key == "StatusLight121Enabled" then
        if D.Set121MUFStatusLightEnabled then
            D:Set121MUFStatusLightEnabled(value and true or false)
        else
            D.profile[key] = value and true or false
        end
        return true
    end

    local info = { "Modern", key }
    if D.SetHandler then
        D.SetHandler(info, value)
    else
        D.profile[key] = value
    end

    if D.MicroUnitF and D.MicroUnitF.Force_FullUpdate then
        if key == "DebuffsFrameElemBorderShow" or key == "DebuffsFrameElemAlpha" then
            D.MicroUnitF:Force_FullUpdate()
        end
    end
    return true
end

function ZD:SetMUFSizePixels(pixels)
    if not self:CanConfigure() then return false end
    if D.MicroUnitF and D.MicroUnitF.SetActiveContextMUFSizePixels then
        return D.MicroUnitF:SetActiveContextMUFSizePixels(pixels)
    end
    pixels = tonumber(pixels) or 20
    if pixels < 10 then pixels = 10 end
    if pixels > 80 then pixels = 80 end
    local base = DC.MFSIZE or 20
    D.profile.DebuffsFrameElemScale = pixels / base
    if D.MicroUnitF and D.MicroUnitF.SetScale then
        D.MicroUnitF:SetScale(D.profile.DebuffsFrameElemScale)
    end
    return true
end

function ZD:GetMUFSizePixels()
    if D.MicroUnitF and D.MicroUnitF.GetActiveMUFSizePixels then
        return D.MicroUnitF:GetActiveMUFSizePixels()
    end
    local base = DC.MFSIZE or 20
    return math.floor(((D.profile and D.profile.DebuffsFrameElemScale) or 1) * base + .5)
end

function ZD:SetPartyMUFSizePixels(pixels)
    if not self:CanConfigure() then return false end
    return D.MicroUnitF and D.MicroUnitF.SetContextMUFSizePixels and D.MicroUnitF:SetContextMUFSizePixels("PARTY", pixels) or false
end

function ZD:GetPartyMUFSizePixels()
    return D.MicroUnitF and D.MicroUnitF.GetContextMUFSizePixels and D.MicroUnitF:GetContextMUFSizePixels("PARTY") or self:GetMUFSizePixels()
end

function ZD:SetRaidMUFSizePixels(pixels)
    if not self:CanConfigure() then return false end
    return D.MicroUnitF and D.MicroUnitF.SetContextMUFSizePixels and D.MicroUnitF:SetContextMUFSizePixels("RAID", pixels) or false
end

function ZD:GetRaidMUFSizePixels()
    return D.MicroUnitF and D.MicroUnitF.GetContextMUFSizePixels and D.MicroUnitF:GetContextMUFSizePixels("RAID") or self:GetMUFSizePixels()
end

function ZD:GetCureEnabled(typeID)
    if not D.GetCureOrderTable then return false end
    local order = D:GetCureOrderTable()
    return order and order[typeID] ~= nil and order[typeID] ~= false
end

function ZD:ToggleCure(typeID)
    if not self:CanConfigure() then return false end
    if not D.SetCureOrder then return false end
    D:SetCureOrder(typeID)
    self:SetStatus("Curing priorities updated.")
    return true
end

function ZD:GetPlayerClassSpec()
    local localizedClass, classFile = UnitClass("player")
    local specName
    if GetSpecialization and GetSpecializationInfo then
        local spec = GetSpecialization()
        if spec then
            local _, name = GetSpecializationInfo(spec)
            specName = name
        end
    end
    return localizedClass or classFile or "Unknown", specName or "No specialization"
end

function ZD:GetCompatibilitySummary()
    local profile = self:GetUserProfileName()
    local envKey, envName = self:GetActiveEnvironment()
    local className, specName = self:GetPlayerClassSpec()
    return {
        "Zhaohu's Decursive " .. self.version,
        "Feature engine: " .. self.compatBackend,
        "User profile: " .. tostring(profile),
        "Environment: " .. tostring(envName or envKey),
        "Character: " .. tostring(specName) .. " " .. tostring(className),
        "Detection provider: " .. tostring((self:GetDetectionProviderStatus() or {}).displayName or "Native Blizzard-managed"),
    }
end


-- Route the long-standing quick-access gestures into the single v11 UI.
if D.QuickAccess and not ZD._quickAccessWrapped then
    local legacyQuickAccess = D.QuickAccess
    D.QuickAccess = function(self, callingObject, mouseButton)
        if mouseButton == "RightButton" and IsAltKeyDown() and not IsShiftKeyDown() and not InCombatLockdown() then
            if ZD.EnsureOptionsLoaded then ZD:EnsureOptionsLoaded() end
            if ZD.ToggleUI then ZD:ToggleUI() end
            return
        end
        return legacyQuickAccess(self, callingObject, mouseButton)
    end
    ZD._quickAccessWrapped = true
end

-- The old standalone priority/skip windows stay hidden as backend compatibility
-- frames, but every user-facing list command opens the v11 page instead.
if not ZD._listUIWrapped then
    D.ShowHidePriorityListUI = function()
        if ZD.EnsureOptionsLoaded and not ZD:EnsureOptionsLoaded() then return end
        if ZD.CreateUI then
            local f = ZD:CreateUI(); if f then f:Show(); ZD.listFocus = "priority"; ZD:ShowPage("lists") end
        end
    end
    D.ShowHideSkipListUI = function()
        if ZD.EnsureOptionsLoaded and not ZD:EnsureOptionsLoaded() then return end
        if ZD.CreateUI then
            local f = ZD:CreateUI(); if f then f:Show(); ZD.listFocus = "skip"; ZD:ShowPage("lists") end
        end
    end
    ZD._listUIWrapped = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if _G.DecursivePriorityListFrame then _G.DecursivePriorityListFrame:Hide() end
        if _G.DecursiveSkipListFrame then _G.DecursiveSkipListFrame:Hide() end
    end
    if ZD.RefreshUI then
        C_Timer.After(.05, function() ZD:RefreshUI() end)
    end
end)
