--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Overview page.
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

UI:RegisterPage("OVERVIEW", "Overview", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    page.eyebrow = Controls:Label(page, "COMMAND CENTER", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "Decursive at a glance", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "Current cure readiness, environment behavior and the controls you use most.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local readiness = Controls:Card(page, "Runtime readiness",
        "The 12.1 engine fails closed when a required capability is unavailable.")
    readiness:SetPoint("TOPLEFT", 0, -82)
    readiness:SetPoint("TOPRIGHT", -8, -82)
    readiness:SetHeight(210)
    Controls:StatusRow(readiness, "Detection", function()
        local state = ZD.GetDetectionProviderStatus and ZD:GetDetectionProviderStatus() or {}
        return state.operational == false and "Needs attention" or "Operational"
    end, function()
        local state = ZD.GetDetectionProviderStatus and ZD:GetDetectionProviderStatus() or {}
        return state.operational == false and Theme.color.danger or Theme.color.success
    end)
    Controls:StatusRow(readiness, "Provider", function()
        local state = ZD.GetDetectionProviderStatus and ZD:GetDetectionProviderStatus() or {}
        return state.displayName or "Native Blizzard-managed"
    end)
    Controls:StatusRow(readiness, "Current profile", function()
        return ZD.GetUserProfileName and ZD:GetUserProfileName() or "Default"
    end)
    Controls:StatusRow(readiness, "Environment", function()
        if not ZD.GetActiveEnvironment then return "Open World" end
        local _, name = ZD:GetActiveEnvironment()
        return name or "Open World"
    end)

    local quick = Controls:Card(page, "Quick controls",
        "These are profile settings. Environment overrides remain separate.")
    quick:SetPoint("TOPLEFT", readiness, "BOTTOMLEFT", 0, -12)
    quick:SetPoint("TOPRIGHT", readiness, "BOTTOMRIGHT", 0, -12)
    quick:SetHeight(205)
    Controls:Toggle(quick, "Show Micro Unit Frames", nil,
        function() return D.profile and D.profile.ShowDebuffsFrame end,
        function(value) return ZD:SetProfileOption("ShowDebuffsFrame", value) end)
    Controls:Toggle(quick, "Dispel text alert", nil,
        function() return D.profile and D.profile.Alert121DispelEnabled ~= false end,
        function(value)
            if not D.profile then return false end
            D.profile.Alert121DispelEnabled = value and true or false
            if D.Refresh121DispelAlertWarning then D:Refresh121DispelAlertWarning() end
            return true
        end)
    Controls:Toggle(quick, "Dispel sound", nil,
        function() return D.profile and D.profile.PlaySound ~= false end,
        function(value)
            if not D.profile then return false end
            D.profile.PlaySound = value and true or false
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("v13 overview") end
            return true
        end)

    function page:Refresh()
        readiness:Refresh()
        quick:Refresh()
    end
    return page
end)
