--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Profiles page.
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
local ZD = T.ZhaohuModern
local D = T.Dcr

local environmentValues = {
    { key = "AUTO", label = "Automatic" },
    { key = "OPEN_WORLD", label = "Open World" },
    { key = "DUNGEON", label = "Dungeon / Follower" },
    { key = "MYTHIC_PLUS", label = "Mythic+" },
    { key = "RAID", label = "Raid" },
    { key = "PVP", label = "PvP" },
}

local editEnvironmentValues = {
    { key = "OPEN_WORLD", label = "Open World" },
    { key = "DUNGEON", label = "Dungeon / Follower" },
    { key = "MYTHIC_PLUS", label = "Mythic+" },
    { key = "RAID", label = "Raid" },
    { key = "PVP", label = "PvP" },
}

local function profileValues()
    local result = {}
    for _, name in ipairs(ZD.GetProfiles and ZD:GetProfiles() or {}) do
        result[#result + 1] = { key = name, label = name }
    end
    if #result == 0 then result[1] = { key = "Default", label = "Default" } end
    return result
end

local function profileExists(name)
    for _, profile in ipairs(profileValues()) do
        if profile.key == name then return true end
    end
    return false
end

UI:RegisterPage("PROFILES", "Profiles", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.contentHeight = 1280
    page.eyebrow = Controls:Label(page, "PROFILES & ENVIRONMENTS", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "Your setup, adapted to the content", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "Named profiles and automatic environment behavior remain separate.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local named = Controls:Card(page, "Named profile",
        "Switching profiles changes the complete user setup.")
    named:SetPoint("TOPLEFT", 0, -82)
    named:SetPoint("TOPRIGHT", -8, -82)
    named:SetHeight(300)
    Controls:Cycle(named, "Current profile", profileValues,
        function() return ZD.GetUserProfileName and ZD:GetUserProfileName() or "Default" end,
        function(value)
            local applied = ZD.SetUserProfile and ZD:SetUserProfile(value) or false
            if applied then
                UI:SetStatus("Switched to profile " .. value .. ".", "success")
            end
            return applied
        end)
    local nameInput = Controls:TextInput(named, "Profile name", "Example: Mythic Healer")
    local createProfile = Controls:Button(named, "Create / Switch", 150, function()
        local name = nameInput.edit:GetText() or ""
        if ZD.CreateUserProfile and ZD:CreateUserProfile(name) then
            nameInput.edit:SetText("")
            UI:SetStatus("Profile created or selected.", "success")
            page:Refresh()
        else
            UI:SetStatus("Enter a valid profile name outside combat.", "error")
        end
    end, "primary")
    createProfile:SetPoint("BOTTOMLEFT", 16, 54)
    local copyProfile = Controls:Button(named, "Copy Current", 140, function()
        local name = (nameInput.edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if profileExists(name) then
            UI:SetStatus("Choose a new name; that profile already exists.", "warning")
            return
        end
        if ZD.CloneCurrentProfile and ZD:CloneCurrentProfile(name) then
            nameInput.edit:SetText("")
            UI:SetStatus("Current profile copied to " .. name .. ".", "success")
            page:Refresh()
        else
            UI:SetStatus("Enter a new profile name outside combat.", "error")
        end
    end)
    copyProfile:SetPoint("LEFT", createProfile, "RIGHT", 8, 0)
    local resetProfile = Controls:ConfirmButton(named, "Reset Current Profile", 180, function()
        if ZD.ResetUserProfile and ZD:ResetUserProfile() then
            UI:SetStatus("Current profile reset.", "warning")
            page:Refresh()
        end
    end)
    resetProfile:SetPoint("BOTTOMLEFT", 16, 16)

    local behavior = Controls:Card(page, "Automatic behavior",
        "Automatic mode follows Open World, Dungeon/Follower, Mythic+, Raid and PvP.")
    behavior:SetPoint("TOPLEFT", named, "BOTTOMLEFT", 0, -12)
    behavior:SetPoint("TOPRIGHT", named, "BOTTOMRIGHT", 0, -12)
    behavior:SetHeight(230)
    Controls:Cycle(behavior, "Activation mode", function() return environmentValues end,
        function() return ZD.GetEnvironmentSetting and ZD:GetEnvironmentSetting() or "AUTO" end,
        function(value)
            local applied = ZD.SetEnvironmentSetting and ZD:SetEnvironmentSetting(value) or false
            if applied then UI:SetStatus("Environment activation updated.", "success") end
            return applied
        end)
    Controls:StatusRow(behavior, "Currently active", function()
        if not ZD.GetActiveEnvironment then return "Open World" end
        local _, name = ZD:GetActiveEnvironment()
        return name or "Open World"
    end, function() return Theme.color.success end)
    Controls:Cycle(behavior, "Edit environment", function() return editEnvironmentValues end,
        function() return ZD.GetEditEnvironment and ZD:GetEditEnvironment() or "OPEN_WORLD" end,
        function(value)
            local applied = ZD.SetEditEnvironment and ZD:SetEditEnvironment(value) or false
            if applied then
                UI:SetStatus("Editing " .. (V13.SettingsSchema.environmentNames[value] or value) .. ".", "success")
            end
            return applied
        end)

    local resetEnvironment = Controls:ConfirmButton(behavior, "Reset Edited Environment", 190, function()
        local key = ZD.GetEditEnvironment and ZD:GetEditEnvironment() or "OPEN_WORLD"
        if ZD.ResetEnvironmentProfile and ZD:ResetEnvironmentProfile(key) then
            UI:SetStatus((V13.SettingsSchema.environmentNames[key] or key) .. " reset.", "warning")
            page:Refresh()
        end
    end)
    resetEnvironment:SetPoint("BOTTOMLEFT", 16, 16)

    local export = Controls:Card(page, "Export active profile",
        "Generate a portable string containing only the current AceDB user profile.")
    export:SetPoint("TOPLEFT", behavior, "BOTTOMLEFT", 0, -12)
    export:SetPoint("TOPRIGHT", behavior, "BOTTOMRIGHT", 0, -12)
    export:SetHeight(275)
    local exportText = Controls:TextArea(export, "Profile string", 120)
    local generate = Controls:Button(export, "Generate & Select", 170, function()
        local value = D.GetProfileExportString and D:GetProfileExportString() or ""
        exportText.edit:SetText(value)
        exportText.edit:HighlightText()
        exportText.edit:SetFocus()
        UI:SetStatus(value ~= "" and "Export ready. Press Ctrl+C to copy." or "Profile export failed.", value ~= "" and "success" or "error")
    end, "primary")
    generate:SetPoint("BOTTOMLEFT", 16, 16)

    local import = Controls:Card(page, "Import into active profile",
        "Import replaces the active profile's settings. Global, locale and class-scoped data are not overwritten.")
    import:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -12)
    import:SetPoint("TOPRIGHT", export, "BOTTOMRIGHT", 0, -12)
    import:SetHeight(320)
    local importText = Controls:TextArea(import, "Paste a Decursive profile string", 140)
    local importButton = Controls:ConfirmButton(import, "Import Into Current Profile", 225, function()
        local value = importText.edit:GetText() or ""
        if D.SetProfileImportBuffer then D:SetProfileImportBuffer(value) end
        local ok = D.ImportProfileString and D:ImportProfileString(value)
        if ok then
            importText.edit:SetText("")
            UI:SetStatus("Profile imported successfully.", "success")
            page:Refresh()
        else
            UI:SetStatus(D.GetProfileIOStatus and D:GetProfileIOStatus() or "Profile import failed.", "error")
        end
    end)
    importButton:SetPoint("BOTTOMLEFT", 16, 16)
    local importState = Controls:Pill(import, "DOUBLE CONFIRMATION REQUIRED", Theme.color.warning)
    importState:SetWidth(220)
    importState:SetPoint("LEFT", importButton, "RIGHT", 10, 0)

    function page:Refresh()
        named:Refresh()
        behavior:Refresh()
    end
    return page
end)
