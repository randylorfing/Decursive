--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 compatibility core module. This file was solely written by
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

    Zhaohu's Decursive v13 — Detect • Cleanse • Protect.

    This module connects the v13 command center to the hardened compatibility
    runtime. The WoW 12.1 managed-aura engine remains the authority for aura
    visibility and this addon never attempts to recover protected aura details.
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
ZD.compatBackend = "v13-hardened-compat-runtime"
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

local ENV_DEFAULTS = D.Environment121Defaults or {
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
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        TextAlerts121Enabled = true,
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
        TextAlerts121Enabled = true,
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
        TextAlerts121Enabled = true,
        EnvironmentChat121Enabled = true,
    },
    PVP = {
        OutOfRange121Enabled = true,
        OutOfRange121DimAmount = .60,
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
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        TextAlerts121Enabled = false,
        EnvironmentChat121Enabled = false,
    },
    OPEN_WORLD = {
        OutOfRange121Enabled = false,
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
        SharedPriorityCooldown121Enabled = true,
        ClearCleansedTarget121Enabled = true,
        TextAlerts121Enabled = true,
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
    local manager = D.ProfileManager
    local profileID = manager and manager:GetActiveProfileID()
    return manager and manager:GetProfileName(profileID) or "Default"
end

function ZD:GetUserProfileID()
    return D.ProfileManager and D.ProfileManager:GetActiveProfileID() or "default"
end

function ZD:GetProfileCatalog()
    return D.ProfileManager and D.ProfileManager:GetCatalog() or {
        { id = "default", name = "Default", protected = true, deletable = false, active = true },
    }
end

function ZD:GetProfiles()
    local names = {}
    for _, profile in ipairs(self:GetProfileCatalog()) do names[#names + 1] = profile.name end
    return names
end

function ZD:GetProfileSchemaStatus()
    return D.ProfileManager and D.ProfileManager:GetSchemaStatus() or {
        readOnly = true,
        storedVersion = 0,
        supportedVersion = 0,
        message = "The profile manager is unavailable.",
    }
end

function ZD:GetProfileAssignments()
    return D.ProfileManager and D.ProfileManager:GetAssignmentSnapshot() or {
        account = "default",
        active = "default",
        perSpecEnabled = false,
    }
end

local function profileID(value)
    return D.ProfileManager and D.ProfileManager:FindProfileID(value) or nil
end

local function profileName(value)
    local id = profileID(value)
    return id and D.ProfileManager:GetProfileName(id) or nil
end

local function managerFailure(code)
    local messages = {
        ["read-only"] = "Profile data is read-only because it was created by a newer Decursive version.",
        ["combat"] = "Profile creation, reset, and deletion are unavailable during combat.",
        ["profile-limit"] = "The account profile limit of 50 has been reached.",
        ["invalid-name"] = "Enter a profile name from 1 to 48 UTF-8 bytes without control characters.",
        ["name-exists"] = "A profile with that name already exists.",
        ["protected-profile"] = "The built-in Default profile is protected.",
        ["unknown-profile"] = "The selected profile no longer exists.",
        ["character-unavailable"] = "The current character identity is not available yet.",
        ["spec-unavailable"] = "The current specialization identity is not available yet.",
    }
    return messages[code] or "The profile change could not be completed: " .. tostring(code or "unknown error")
end

function ZD:SetAccountProfile(value)
    if not self:CanConfigure() then return false end
    local id = profileID(value)
    local ok, code = D.ProfileManager:SetAssignment("account", id)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Account default profile set to " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:SetCharacterProfile(value)
    if not self:CanConfigure() then return false end
    local id = value and profileID(value) or nil
    if value and not id then self:SetStatus(managerFailure("unknown-profile"), true) return false end
    local ok, code = D.ProfileManager:SetAssignment("character", id)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus(id and ("Character profile set to " .. D.ProfileManager:GetProfileName(id) .. ".")
        or "Character now uses the account default profile.")
    return true
end

function ZD:SetSpecProfilesEnabled(enabled)
    if not self:CanConfigure() then return false end
    local ok, code = D.ProfileManager:SetPerSpecEnabled(enabled)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus(enabled and "Specialization profiles enabled." or "Specialization profiles disabled.")
    return true
end

function ZD:SetCurrentSpecProfile(value)
    if not self:CanConfigure() then return false end
    local id = value and profileID(value) or nil
    if value and not id then self:SetStatus(managerFailure("unknown-profile"), true) return false end
    local ok, code = D.ProfileManager:SetAssignment("spec", id)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus(id and ("Current specialization profile set to " .. D.ProfileManager:GetProfileName(id) .. ".")
        or "Current specialization now uses its character or account fallback.")
    return true
end

function ZD:SetUserProfile(value)
    if not self:CanConfigure() then return false end
    local id = profileID(value)
    if not id then self:SetStatus(managerFailure("unknown-profile"), true) return false end
    local ok, code = D.ProfileManager:ActivateProfile(id)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Profile switched to " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:CreateUserProfile(name)
    if not self:CanConfigure() then return false end
    local existing = type(name) == "string" and D.ProfileManager:FindProfileID(name) or nil
    if existing then return self:SetUserProfile(existing) end
    local id, code = D.ProfileManager:CreateProfile(name)
    if not id then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Created profile " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:CloneCurrentProfile(newName)
    if not self:CanConfigure() then return false end
    local sourceID = self:GetUserProfileID()
    local sourceName = D.ProfileManager:GetProfileName(sourceID)
    local id, code = D.ProfileManager:CreateProfile(newName, sourceID)
    if not id then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Copied " .. sourceName .. " to " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:CopyUserProfile(value)
    if not self:CanConfigure() then return false end
    local id = profileID(value)
    if not id then self:SetStatus(managerFailure("unknown-profile"), true) return false end
    local ok, err = D.ProfileManager:CopyProfile(self:GetUserProfileID(), id)
    if not ok then self:SetStatus(managerFailure(err), true) return false end
    self:SetStatus("Copied settings from " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:ResetUserProfile()
    if not self:CanConfigure() then return false end
    local ok, code = D.ProfileManager:ResetProfile(self:GetUserProfileID())
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Current profile reset to defaults.")
    return true
end

function ZD:RenameCurrentProfile(newName)
    if not self:CanConfigure() then return false end
    local id = self:GetUserProfileID()
    local oldName = D.ProfileManager:GetProfileName(id)
    local ok, code = D.ProfileManager:RenameProfile(id, newName)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Renamed profile " .. oldName .. " to " .. D.ProfileManager:GetProfileName(id) .. ".")
    return true
end

function ZD:HandleDeletedProfileAssignments(value)
    local id = profileID(value)
    if not id then return false end
    D.ProfileManager:RemoveAssignments(id)
    return true
end

function ZD:DeleteUserProfile(value)
    if not self:CanConfigure() then return false end
    local id = profileID(value)
    if not id then self:SetStatus(managerFailure("unknown-profile"), true) return false end
    local name = D.ProfileManager:GetProfileName(id)
    local ok, code = D.ProfileManager:DeleteProfile(id)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Deleted profile " .. name .. ". Assignments using it now use their fallback.")
    return true
end

function ZD:GetEnvironmentSetting()
    return D.ProfileManager and D.ProfileManager:GetEnvironmentMode() or "AUTO"
end

function ZD:GetActiveEnvironment()
    if D.ProfileManager then
        local profileID = D.ProfileManager:ResolveActiveProfileID()
        local active = D.ProfileManager:ResolveEnvironment(profileID)
        return active, ENV_NAMES[active] or active
    end
    return "OPEN_WORLD", ENV_NAMES.OPEN_WORLD
end

function ZD:SetEnvironmentSetting(mode)
    if not self:CanConfigure() then return false end
    if not D.ProfileManager then self:SetStatus(managerFailure("unavailable"), true) return false end
    local ok, code = D.ProfileManager:SetEnvironmentMode(mode)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Environment mode set to " .. (mode == "AUTO" and "Automatic" or (ENV_NAMES[mode] or mode)) .. ".")
    return true
end

function ZD:GetEditEnvironment()
    return D.ProfileManager and D.ProfileManager:GetEditEnvironment() or "OPEN_WORLD"
end

function ZD:SetEditEnvironment(key)
    if not self:CanConfigure() then return false end
    if not D.ProfileManager then self:SetStatus(managerFailure("unavailable"), true) return false end
    local ok, code = D.ProfileManager:SetEditEnvironment(key, true)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Editing Environment Profile: " .. (ENV_NAMES[key] or key) .. ".")
    if self.RefreshUI then self:RefreshUI() end
    return true
end

function ZD:GetEnvironmentProfile(key)
    if key and key ~= self:GetEditEnvironment() and D.ProfileManager then return nil end
    return D.profile
end

function ZD:ApplyEnvironmentProfileToRuntime(key)
    if not D.profile or key ~= self:GetEditEnvironment() then return end
    if D.Apply121RangeAppearance then D:Apply121RangeAppearance() end
    if D.Set121OutOfRangeEnabled then D:Set121OutOfRangeEnabled(D.profile.OutOfRange121Enabled ~= false) end
    if D.Apply121LineOfSightAppearance then D:Apply121LineOfSightAppearance() end
    if D.Set121LineOfSightEnabled then D:Set121LineOfSightEnabled(D.profile.LineOfSight121Enabled ~= false) end
    if D.Apply121CooldownAppearance then D:Apply121CooldownAppearance() end
    if D.Set121CooldownOverlayEnabled then D:Set121CooldownOverlayEnabled(D.profile.CooldownOverlay121Enabled ~= false) end
    if D.Refresh121SharedPriorityCooldowns then D:Refresh121SharedPriorityCooldowns() end
    if D.Apply121AlertWarningStyle then D:Apply121AlertWarningStyle() end
    if D.profile.TextAlerts121Enabled == false and D.Hide121AlertWarning then D:Hide121AlertWarning() end
end

function ZD:SetEnvironmentValue(key, setting, value)
    if not self:CanConfigure() then return false end
    if key ~= self:GetEditEnvironment() then
        local selected = self:SetEditEnvironment(key)
        if not selected then return false end
    end
    if not D.profile then return false end
    D.profile[setting] = shallowCopy(value)
    D.profile.Detection121Mode = "STRICT_MANAGED"
    self:ApplyEnvironmentProfileToRuntime(key)
    self:SetStatus((ENV_NAMES[key] or key) .. " behavior updated.")
    return true
end

function ZD:ResetEnvironmentProfile(key)
    if not self:CanConfigure() then return false end
    if not D.ProfileManager then self:SetStatus(managerFailure("unavailable"), true) return false end
    key = key or self:GetEditEnvironment()
    local profileID = D.ProfileManager:ResolveActiveProfileID()
    local ok, code = D.ProfileManager:ResetEnvironment(profileID, key)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Environment Profile " .. (ENV_NAMES[key] or key) .. " reset to defaults.")
    return true
end

function ZD:CopyEnvironmentProfile(sourceEnvironment)
    if not self:CanConfigure() then return false end
    if not D.ProfileManager then self:SetStatus(managerFailure("unavailable"), true) return false end
    local profileID = D.ProfileManager:ResolveActiveProfileID()
    local targetEnvironment = self:GetEditEnvironment()
    local ok, code = D.ProfileManager:CopyEnvironment(
        profileID, targetEnvironment, profileID, sourceEnvironment)
    if not ok then self:SetStatus(managerFailure(code), true) return false end
    self:SetStatus("Environment Profile " .. (ENV_NAMES[targetEnvironment] or targetEnvironment)
        .. " copied from " .. (ENV_NAMES[sourceEnvironment] or sourceEnvironment) .. ".")
    return true
end

function ZD:GetProfileContext()
    return D.ProfileManager and D.ProfileManager:GetContextSnapshot() or {}
end

function ZD:BeginEnvironmentEditing()
    if not D.ProfileManager then return false end
    local ok, code = D.ProfileManager:BeginEnvironmentEditing()
    if not ok then self:SetStatus(managerFailure(code), true) end
    return ok
end

function ZD:EndEnvironmentEditing()
    return D.ProfileManager and D.ProfileManager:RestoreRuntimeEnvironment() or false
end

function ZD:SetProfileOption(key, value)
    if not self:CanConfigure() then return false end
    if not D.profile then return false end

    if key == "ShowDebuffsFrame" then
        local enabled = value and true or false
        if (D.profile.ShowDebuffsFrame and true or false) ~= enabled then
            local applied
            if D.SetDebuffsFrameEnabled then
                applied = D:SetDebuffsFrameEnabled(enabled)
            elseif D.ShowHideDebuffsFrame then
                applied = D:ShowHideDebuffsFrame()
            end
            if applied == false then return false end
        end
        -- Match the mature settings behavior: an explicit Show MUFs choice
        -- disables automatic hiding so the next roster event cannot silently
        -- reverse what the user just selected.
        D.profile.AutoHideMUFs = 1
        return true
    end

    if key == "StatusLight121Enabled" then
        if D.Set121MUFStatusLightEnabled then
            return D:Set121MUFStatusLightEnabled(value and true or false) ~= false
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

function ZD:SetAfflictionPriorityColor(priority, color)
    if not self:CanConfigure() then return false end
    if not D.SetAfflictionPriorityColor or type(color) ~= "table" then
        self:SetStatus("Affliction priority colors are unavailable.", true)
        return false
    end
    local ok, reason = D:SetAfflictionPriorityColor(priority, color[1], color[2], color[3])
    if not ok then
        self:SetStatus(reason == "combat"
            and (D.L and D.L["MUF_PRIORITY_COLORS_COMBAT"] or "Affliction priority colors are locked during combat.")
            or "Affliction priority color could not be applied.", true)
        return false
    end
    self:SetStatus(reason == "deferred"
        and (D.L and D.L["MUF_PRIORITY_COLORS_DEFERRED"] or "Color saved; protected MUF visuals will refresh when restrictions end.")
        or (D.L and D.L["MUF_PRIORITY_COLORS_UPDATED"] or "Affliction priority color updated."))
    return true
end

function ZD:ResetAfflictionPriorityColors()
    if not self:CanConfigure() then return false end
    if not D.ResetAfflictionPriorityColors then return false end
    local ok, reason = D:ResetAfflictionPriorityColors()
    if not ok then
        self:SetStatus("Default affliction priority colors could not be restored.", true)
        return false
    end
    self:SetStatus(reason == "deferred"
        and (D.L and D.L["MUF_PRIORITY_COLORS_RESET_DEFERRED"] or "Default colors restored; protected MUF visuals will refresh when restrictions end.")
        or (D.L and D.L["MUF_PRIORITY_COLORS_RESET_DONE"] or "Default affliction priority colors restored."))
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
    return math.floor(((D.profile and D.profile.DebuffsFrameElemScale) or 1.5) * base + .5)
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
