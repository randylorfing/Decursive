--[[
    This file is part of Decursive.

    Zhaohu's Decursive v11 Blizzard Settings integration. This file was
    solely written by Randy Lorfing.
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
-- Zhaohu's Decursive v11
-- Blizzard Settings -> AddOns integration (loaded with Decursive_Options).
-- A thin launcher category is registered by the resident ZD_LoadOptions.lua.
-- This file keeps the richer canvas helpers for callers that upgrade the panel.

local T = DecursiveRootTable
if not T or not T.ZhaohuModern then return end

local ZD = T.ZhaohuModern
local D = T.Dcr

local PANEL_NAME = "Zhaohu's Decursive"
local panel
local category

local function safeText(value, fallback)
    if value == nil or value == "" then return fallback or "Unknown" end
    return tostring(value)
end

local function setTextColor(fs, r, g, b)
    if fs and fs.SetTextColor then fs:SetTextColor(r, g, b) end
end

local function makeLabel(parent, text, size, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", size and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    if width then
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
    end
    fs:SetText(text or "")
    return fs
end

local function makeButton(parent, text, width, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 180, 28)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function closeBlizzardSettings()
    if not SettingsPanel or not SettingsPanel:IsShown() then return true end

    -- Do not call SettingsPanel:Hide() directly. Blizzard's Settings panel is
    -- managed by UIParent; bypassing its normal close path can leave the
    -- Escape/UI-panel stack in a stale state. Close(true) uses Blizzard's
    -- managed HideUIPanel() path while intentionally skipping the transition
    -- back to the Game Menu because the standalone v11 window is about to open.
    if SettingsPanel.Close then
        SettingsPanel:Close(true)
    elseif HideUIPanel then
        HideUIPanel(SettingsPanel)
    else
        SettingsPanel:Hide()
    end

    -- If Blizzard needs to show an unapplied-settings confirmation, leave the
    -- v11 window closed until that dialog is resolved rather than bypassing it.
    return not SettingsPanel:IsShown()
end

local function openModernPage(page)
    if not ZD.CreateUI then return end
    local f = ZD:CreateUI()
    if not f then return end
    if not closeBlizzardSettings() then return end
    f:Show()
    if page and ZD.ShowPage then ZD:ShowPage(page) end
end

local function getEnvironmentName()
    if ZD.GetActiveEnvironment then
        local _, display = ZD:GetActiveEnvironment()
        return display or "Unknown"
    end
    return "Unknown"
end

local function getProviderName()
    if ZD.GetDetectionProviderStatus then
        local st = ZD:GetDetectionProviderStatus() or {}
        return st.displayName or "Native Blizzard-managed"
    end
    return "Native Blizzard-managed"
end

local function getCharacterText()
    if ZD.GetPlayerClassSpec then
        local className, specName = ZD:GetPlayerClassSpec()
        return safeText(specName, "No specialization") .. " " .. safeText(className, "Unknown")
    end
    return "Unknown"
end

function ZD:RefreshBlizzardSettingsPanel()
    if not panel then return end

    local profile = self.GetUserProfileName and self:GetUserProfileName() or "Default"
    local provider = getProviderName()
    local environment = getEnvironmentName()

    panel.profileValue:SetText(safeText(profile, "Default"))
    panel.providerValue:SetText(provider)
    panel.environmentValue:SetText(environment)
    panel.characterValue:SetText(getCharacterText())

    local inCombat = InCombatLockdown and InCombatLockdown()
    panel.combatValue:SetText(inCombat and "Combat locked" or "Ready")
    if inCombat then
        setTextColor(panel.combatValue, 1.0, 0.35, 0.30)
    else
        setTextColor(panel.combatValue, 0.35, 0.95, 0.65)
    end

    local showMUFs = D and D.profile and D.profile.ShowDebuffsFrame
    panel.mufButton:SetText(showMUFs and "Hide Micro Unit Frames" or "Show Micro Unit Frames")
    panel.mufButton:SetEnabled(not inCombat and D and D.profile ~= nil)

    panel.providerNote:SetText("Using Zhaohu's Decursive native Blizzard 12.1 provider: direct managed-aura detection, range, cooldown membership and post-cure verification.")
    setTextColor(panel.providerNote, 0.72, 0.78, 0.86)
end

function ZD:RegisterBlizzardSettingsPanel()
    if self._blizzardSettingsRegistered then return self.blizzardSettingsCategory end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return nil
    end

    panel = CreateFrame("Frame", "ZhaohusDecursiveBlizzardSettingsPanel")
    panel.name = PANEL_NAME

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("TOPLEFT", 24, -24)
    icon:SetTexture(T._AddonPath .. "iconON.tga")

    local title = makeLabel(panel, PANEL_NAME, true, 104, -27, 520)
    if GameFontNormalHuge then title:SetFontObject(GameFontNormalHuge) end
    setTextColor(title, 0.96, 0.96, 0.98)

    local motto = makeLabel(panel, "Detect • Cleanse • Protect", false, 104, -58, 520)
    setTextColor(motto, 0.30, 0.85, 0.82)

    local version = makeLabel(panel, self.version or "v11", false, 104, -79, 520)
    setTextColor(version, 0.58, 0.64, 0.72)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.20, 0.25, 0.31, 0.9)
    divider:SetPoint("TOPLEFT", 24, -108)
    divider:SetPoint("TOPRIGHT", -24, -108)
    divider:SetHeight(1)

    local statusHeader = makeLabel(panel, "Current Status", true, 24, -132, 300)
    setTextColor(statusHeader, 0.95, 0.82, 0.25)

    local function statusRow(label, y)
        local key = makeLabel(panel, label, false, 34, y, 170)
        setTextColor(key, 0.70, 0.74, 0.80)
        local value = makeLabel(panel, "—", false, 210, y, 430)
        setTextColor(value, 0.93, 0.94, 0.96)
        return value
    end

    panel.profileValue = statusRow("User Profile", -166)
    panel.providerValue = statusRow("Detection Provider", -193)
    panel.environmentValue = statusRow("Behavior Profile", -220)
    panel.characterValue = statusRow("Character", -247)
    panel.combatValue = statusRow("Configuration State", -274)

    panel.providerNote = makeLabel(panel, "", false, 34, -306, 610)
    panel.providerNote:SetJustifyH("LEFT")

    local quickHeader = makeLabel(panel, "Quick Actions", true, 24, -356, 300)
    setTextColor(quickHeader, 0.95, 0.82, 0.25)

    makeButton(panel, "Open Zhaohu's Decursive", 220, 34, -390, function()
        openModernPage("dashboard")
    end)
    makeButton(panel, "Detection", 145, 266, -390, function()
        openModernPage("integrations")
    end)
    makeButton(panel, "Diagnostics", 145, 423, -390, function()
        openModernPage("diagnostics")
    end)

    panel.mufButton = makeButton(panel, "Show Micro Unit Frames", 220, 34, -426, function()
        if not ZD.CanConfigure or not ZD:CanConfigure() then
            ZD:RefreshBlizzardSettingsPanel()
            return
        end
        local current = D and D.profile and D.profile.ShowDebuffsFrame and true or false
        ZD:SetProfileOption("ShowDebuffsFrame", not current)
        ZD:RefreshBlizzardSettingsPanel()
    end)

    makeButton(panel, "12.1 Status", 145, 266, -426, function()
        openModernPage("compat121")
    end)
    makeButton(panel, "Profiles & Modes", 145, 423, -426, function()
        openModernPage("profiles")
    end)

    local note = makeLabel(panel,
        "This Blizzard Settings entry is a launcher and live status view. All configuration remains in the single resizable v13 command center so features are not split across two settings systems.",
        false, 34, -474, 600)
    setTextColor(note, 0.62, 0.67, 0.74)

    panel:SetScript("OnShow", function()
        ZD:RefreshBlizzardSettingsPanel()
    end)
    panel:RegisterEvent("PLAYER_ENTERING_WORLD")
    panel:RegisterEvent("GROUP_ROSTER_UPDATE")
    panel:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(self)
        if self:IsShown() then ZD:RefreshBlizzardSettingsPanel() end
    end)

    category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
    if category then
        Settings.RegisterAddOnCategory(category)
        self.blizzardSettingsCategory = category
        if category.GetID then
            self.blizzardSettingsCategoryID = category:GetID()
        else
            self.blizzardSettingsCategoryID = PANEL_NAME
        end
    end

    if not category then return nil end
    self._blizzardSettingsRegistered = true
    return category
end

function ZD:OpenBlizzardSettings()
    local cat = self:RegisterBlizzardSettingsPanel()
    if not cat or not Settings or not Settings.OpenToCategory then return false end
    local id = self.blizzardSettingsCategoryID
    if not id and cat.GetID then id = cat:GetID() end
    Settings.OpenToCategory(id or PANEL_NAME)
    return true
end

-- Resident ZD_LoadOptions already registered a thin launcher category.
-- Do not register a second canvas here (would duplicate the AddOns entry).
-- Call ZD:RegisterBlizzardSettingsPanel() only if an explicit upgrade is desired.
