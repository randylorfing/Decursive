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
	page.contentHeight = 880

    page.eyebrow = Controls:Label(page, "DECURSIVE PROFILE  >  ENVIRONMENT PROFILE", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "Environment Profile Overview", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "The selected Environment Profile is a complete independent Decursive configuration.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local readiness = Controls:Card(page, "Runtime readiness",
        "The 12.1 engine fails closed when a required capability is unavailable.")
    readiness:SetPoint("TOPLEFT", 0, -82)
    readiness:SetPoint("TOPRIGHT", -8, -82)
    readiness:SetHeight(240)
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
    Controls:StatusRow(readiness, "Editing Environment Profile", function()
		local context = ZD.GetProfileContext and ZD:GetProfileContext() or {}
		return V13.SettingsSchema.environmentNames[context.editEnvironment]
			or context.editEnvironment or "Open World"
    end, function() return Theme.color.warning end)
    Controls:StatusRow(readiness, "Active Environment Profile", function()
		local context = ZD.GetProfileContext and ZD:GetProfileContext() or {}
		return V13.SettingsSchema.environmentNames[context.activeEnvironment]
			or context.activeEnvironment or "Open World"
    end)

    local quick = Controls:Card(page, "Quick controls",
        "These controls are stored directly in the Environment Profile named above.")
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

	local categories = Controls:Card(page, "Complete Environment Profile settings",
		"Choose a task area. Every page continues editing this same Environment Profile.")
	categories:SetPoint("TOPLEFT", quick, "BOTTOMLEFT", 0, -12)
	categories:SetPoint("TOPRIGHT", quick, "BOTTOMRIGHT", 0, -12)
	categories:SetHeight(165)
	local muf = Controls:Button(categories, "MUF Setup", 130, function() UI:ShowPage("MUFS") end, "primary")
	muf:SetPoint("TOPLEFT", 16, -82)
	local cure = Controls:Button(categories, "Cures & Mouse Bindings", 190, function() UI:ShowPage("CURE") end)
	cure:SetPoint("LEFT", muf, "RIGHT", 8, 0)
	local alerts = Controls:Button(categories, "Alerts & Feedback", 150, function() UI:ShowPage("ALERTS") end)
	alerts:SetPoint("BOTTOMLEFT", 16, 16)
	local advanced = Controls:Button(categories, "Advanced & Diagnostics", 190, function() UI:ShowPage("ADVANCED") end)
	advanced:SetPoint("LEFT", alerts, "RIGHT", 8, 0)

    function page:Refresh()
        readiness:Refresh()
        quick:Refresh()
    end
    return page
end)
