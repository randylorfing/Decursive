--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Profiles workspace.
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
local L = D and D.L

local function localized(key, fallback)
	return L and L[key] or fallback
end

local USE_ACCOUNT_PROFILE = "__USE_ACCOUNT_PROFILE__"
local USE_CHARACTER_PROFILE = "__USE_CHARACTER_PROFILE__"

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
	for _, profile in ipairs(ZD.GetProfileCatalog and ZD:GetProfileCatalog() or {}) do
		result[#result + 1] = { key = profile.id, label = profile.name }
	end
	if #result == 0 then result[1] = { key = "default", label = "Default" } end
	return result
end

local function profileLabel(profileID)
	if not profileID then return nil end
	for _, profile in ipairs(ZD.GetProfileCatalog and ZD:GetProfileCatalog() or {}) do
		if profile.id == profileID then return profile.name end
	end
	return tostring(profileID)
end

local function profileExists(name)
	return type(name) == "string" and D.ProfileManager and D.ProfileManager:FindProfileID(name) ~= nil or false
end

local function profilesWritable()
	local status = ZD.GetProfileSchemaStatus and ZD:GetProfileSchemaStatus() or {}
	return status.readOnly ~= true
end

local function assignmentValues(inheritKey, inheritLabel)
	local result = {}
	if inheritKey then
		result[#result + 1] = {
			key = inheritKey,
			label = inheritLabel,
		}
	end
	for _, profile in ipairs(profileValues()) do result[#result + 1] = profile end
	return result
end

local function deletableProfileValues()
	local result = {}
	for _, profile in ipairs(ZD.GetProfileCatalog and ZD:GetProfileCatalog() or {}) do
		if profile.deletable then result[#result + 1] = { key = profile.id, label = profile.name } end
	end
	return result
end

local function setRouteButtonActive(button, active)
	if not button then return end
	local fill = active and Theme.color.raised or Theme.color.surface
	local border = active and Theme.color.cyan or Theme.color.border
	button:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
	button:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	button.text:SetTextColor(unpack(active and Theme.color.text or Theme.color.muted))
end

UI:RegisterPage("PROFILES", "Profiles", function(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page.routes = {}
	page.routeFrames = {}
	page.routeButtons = {}

	function page:RegisterRoute(key, label, height)
		self.routes[key] = { key = key, label = label, height = height }
	end

	page:RegisterRoute("DECURSIVE",
		localized("PROFILE_DECURSIVE_PAGE", "Decursive Profiles"), 1330)
	page:RegisterRoute("ENVIRONMENT",
		localized("PROFILE_ENVIRONMENT_PAGE", "Environment Profiles"), 1040)

	page.eyebrow = Controls:Label(page, "PROFILES", 9, Theme.color.cyan)
	page.eyebrow:SetPoint("TOPLEFT", 0, -2)
	page.title = Controls:Label(page,
		localized("PROFILE_WORKSPACE_TITLE", "Profiles without guesswork"),
		20, Theme.color.text)
	page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
	page.subtitle = Controls:Label(page,
		localized("PROFILE_WORKSPACE_DESC", "Manage saved setups separately from the rules that select them."),
		10, Theme.color.muted)
	page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)
	page.subtitle:SetPoint("RIGHT", -8, 0)

	local routeBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
	routeBar:SetPoint("TOPLEFT", 0, -82)
	routeBar:SetPoint("TOPRIGHT", -8, -82)
	routeBar:SetHeight(72)
	Controls:SetBackdrop(routeBar, Theme.color.surface, Theme.color.border)
	page.routeBar = routeBar
	local schemaWarning = Controls:Pill(routeBar,
		localized("PROFILE_FUTURE_SCHEMA", "Newer profile data detected. Profile changes are read-only."), Theme.color.warning)
	schemaWarning:SetWidth(500)
	schemaWarning:SetPoint("TOP", 0, -6)
	page.schemaWarning = schemaWarning

	local decursiveRoute = Controls:Button(routeBar,
		localized("PROFILE_DECURSIVE_PAGE", "Decursive Profiles"), 284, function()
			page:SetRoute("DECURSIVE")
		end)
	decursiveRoute:SetPoint("BOTTOMLEFT", 10, 6)
	decursiveRoute:SetPoint("BOTTOMRIGHT", routeBar, "BOTTOM", -4, 6)
	page.routeButtons.DECURSIVE = decursiveRoute

	local environmentRoute = Controls:Button(routeBar,
		localized("PROFILE_ENVIRONMENT_PAGE", "Environment Profiles"), 284, function()
			page:SetRoute("ENVIRONMENT")
		end)
	environmentRoute:SetPoint("BOTTOMLEFT", routeBar, "BOTTOM", 4, 6)
	environmentRoute:SetPoint("BOTTOMRIGHT", -10, 6)
	page.routeButtons.ENVIRONMENT = environmentRoute

	local decursive = CreateFrame("Frame", nil, page)
	decursive:SetPoint("TOPLEFT", routeBar, "BOTTOMLEFT", 0, -12)
	decursive:SetPoint("TOPRIGHT", routeBar, "BOTTOMRIGHT", 0, -12)
	decursive:SetHeight(1180)
	page.routeFrames.DECURSIVE = decursive

	local decursiveHeading = Controls:Label(decursive,
		localized("PROFILE_DECURSIVE_PAGE", "Decursive Profiles"), 16, Theme.color.text)
	decursiveHeading:SetPoint("TOPLEFT", 0, 0)
	local decursiveDescription = Controls:Label(decursive,
		localized("PROFILE_DECURSIVE_PAGE_DESC", "Create, switch, protect, and transfer complete Decursive setups."),
		10, Theme.color.muted)
	decursiveDescription:SetPoint("TOPLEFT", decursiveHeading, "BOTTOMLEFT", 0, -5)
	decursiveDescription:SetPoint("RIGHT", -8, 0)

	local named = Controls:Card(decursive,
		localized("PROFILE_NAMED_CARD", "Named profile"),
		localized("PROFILE_NAMED_CARD_DESC", "Switching profiles changes the complete Decursive setup."))
	named:SetPoint("TOPLEFT", 0, -52)
	named:SetPoint("TOPRIGHT", -8, -52)
	named:SetHeight(300)
	local currentProfileCycle = Controls:Cycle(named, localized("PROFILE_CURRENT", "Current profile"), profileValues,
		function() return ZD.GetUserProfileID and ZD:GetUserProfileID() or "default" end,
		function(value)
			local applied = ZD.SetUserProfile and ZD:SetUserProfile(value) or false
			if applied then UI:SetStatus("Profile switched.", "success") end
			return applied
		end, profilesWritable)
	local nameInput = Controls:TextInput(named,
		localized("PROFILE_NAME", "Profile name"),
		localized("PROFILE_NAME_EXAMPLE", "Example: Mythic Healer"))
	nameInput.edit:SetMaxLetters(48)
	local createProfile = Controls:Button(named,
		localized("PROFILE_CREATE_SWITCH", "Create / Switch"), 150, function()
			local name = nameInput.edit:GetText() or ""
			if ZD.CreateUserProfile and ZD:CreateUserProfile(name) then
				nameInput.edit:SetText("")
				UI:SetStatus("Profile created or selected.", "success")
				page:Refresh()
			else
				UI:SetStatus(ZD.lastStatus or "Enter a valid profile name outside combat.", "error")
			end
		end, "primary")
	createProfile:SetPoint("BOTTOMLEFT", 16, 54)
	local copyProfile = Controls:Button(named,
		localized("PROFILE_COPY_CURRENT", "Copy Current"), 140, function()
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
				UI:SetStatus(ZD.lastStatus or "Enter a new profile name outside combat.", "error")
			end
		end)
	copyProfile:SetPoint("LEFT", createProfile, "RIGHT", 8, 0)
	local resetProfile = Controls:ConfirmButton(named,
		localized("PROFILE_RESET_CURRENT", "Reset Current Profile"), 180, function()
			if ZD.ResetUserProfile and ZD:ResetUserProfile() then
				UI:SetStatus("Current profile reset.", "warning")
				page:Refresh()
			end
		end)
	resetProfile:SetPoint("BOTTOMLEFT", 16, 16)
	local renameProfile = Controls:Button(named,
		localized("PROFILE_RENAME_BUTTON", "Rename Current"), 150, function()
			local name = nameInput.edit:GetText() or ""
			if ZD.RenameCurrentProfile and ZD:RenameCurrentProfile(name) then
				nameInput.edit:SetText("")
				UI:SetStatus(localized("PROFILE_RENAME_SUCCESS", "Current profile renamed."), "success")
				page:Refresh()
			else
				UI:SetStatus(ZD.lastStatus or "Enter a new profile name outside combat.", "error")
			end
		end)
	renameProfile:SetPoint("LEFT", resetProfile, "RIGHT", 8, 0)

	local deleteSelection
	local function getDeleteSelection()
		local values = deletableProfileValues()
		if #values == 0 then
			deleteSelection = nil
			return nil
		end
		for _, profile in ipairs(values) do
			if profile.key == deleteSelection then return deleteSelection end
		end
		deleteSelection = values[1].key
		return deleteSelection
	end

	local deletion = Controls:Card(decursive,
		localized("PROFILE_DELETE_UNUSED", "Delete an unused profile"),
		localized("PROFILE_DELETE_UNUSED_DESC", "Default is protected. Character and specialization assignments fall back safely."))
	deletion:SetPoint("TOPLEFT", named, "BOTTOMLEFT", 0, -12)
	deletion:SetPoint("TOPRIGHT", named, "BOTTOMRIGHT", 0, -12)
	deletion:SetHeight(170)
	Controls:Cycle(deletion,
		localized("PROFILE_DELETE_SELECTION", "Profile to delete"),
		deletableProfileValues,
		getDeleteSelection,
		function(value)
			deleteSelection = value
			return true
		end,
		function() return #deletableProfileValues() > 0 end)
	local deleteProfile = Controls:ConfirmButton(deletion,
		localized("PROFILE_DELETE_BUTTON", "Delete Selected Profile"), 190, function()
			local name = getDeleteSelection()
			if name and ZD.DeleteUserProfile and ZD:DeleteUserProfile(name) then
				deleteSelection = nil
				UI:SetStatus(localized("PROFILE_DELETE_SUCCESS", "Profile deleted; assignments now use their fallback."), "warning")
				page:Refresh()
			end
		end)
	deleteProfile:SetPoint("BOTTOMLEFT", 16, 16)

	local export = Controls:Card(decursive,
		localized("PROFILE_EXPORT_CARD", "Export complete Decursive Profile"),
		localized("PROFILE_EXPORT_CARD_DESC", "Generate one portable string containing all five complete Environment Profiles."))
	export:SetPoint("TOPLEFT", deletion, "BOTTOMLEFT", 0, -12)
	export:SetPoint("TOPRIGHT", deletion, "BOTTOMRIGHT", 0, -12)
	export:SetHeight(275)
	local exportText = Controls:TextArea(export,
		localized("PROFILE_EXPORT_STRING", "Profile string"), 120)
	local generate = Controls:Button(export,
		localized("PROFILE_EXPORT_GENERATE", "Generate & Select"), 170, function()
			local value = D.GetProfileExportString and D:GetProfileExportString() or ""
			exportText.edit:SetText(value)
			exportText.edit:HighlightText()
			exportText.edit:SetFocus()
			UI:SetStatus(value ~= "" and "Export ready. Press Ctrl+C to copy." or "Profile export failed.", value ~= "" and "success" or "error")
		end, "primary")
	generate:SetPoint("BOTTOMLEFT", 16, 16)

	local import = Controls:Card(decursive,
		localized("PROFILE_IMPORT_CARD", "Import complete Decursive Profile"),
		localized("PROFILE_IMPORT_CARD_DESC", "Import transactionally replaces all five Environment Profiles, including class and specialization cure settings. Account assignments, locale, diagnostics, and caches are not overwritten."))
	import:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -12)
	import:SetPoint("TOPRIGHT", export, "BOTTOMRIGHT", 0, -12)
	import:SetHeight(320)
	local importText = Controls:TextArea(import,
		localized("PROFILE_IMPORT_STRING", "Paste a Decursive profile string"), 140)
	local importButton = Controls:ConfirmButton(import,
		localized("PROFILE_IMPORT_BUTTON", "Import Into Current Profile"), 225, function()
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

	local environment = CreateFrame("Frame", nil, page)
	environment:SetPoint("TOPLEFT", routeBar, "BOTTOMLEFT", 0, -12)
	environment:SetPoint("TOPRIGHT", routeBar, "BOTTOMRIGHT", 0, -12)
	environment:SetHeight(560)
	page.routeFrames.ENVIRONMENT = environment

	local environmentHeading = Controls:Label(environment,
		localized("PROFILE_ENVIRONMENT_PAGE", "Environment Profiles"), 16, Theme.color.text)
	environmentHeading:SetPoint("TOPLEFT", 0, 0)
	local environmentDescription = Controls:Label(environment,
		localized("PROFILE_ENVIRONMENT_PAGE_DESC", "A Decursive Profile contains five complete Environment Profiles. Select one below and choose Edit to open all of its settings."),
		10, Theme.color.muted)
	environmentDescription:SetPoint("TOPLEFT", environmentHeading, "BOTTOMLEFT", 0, -5)
	environmentDescription:SetPoint("RIGHT", -8, 0)
	environmentDescription:SetWordWrap(true)

	local assignments = Controls:Card(environment,
		localized("PROFILE_RUNTIME_ASSIGNMENTS", "Runtime assignments"),
		localized("PROFILE_RUNTIME_ASSIGNMENTS_DESC", "Choose account-wide, character, and specialization selection metadata. Gameplay settings remain inside the five Environment Profiles."))
	assignments:SetPoint("TOPLEFT", 0, -52)
	assignments:SetPoint("TOPRIGHT", -8, -52)
	assignments:SetHeight(285)
	Controls:Cycle(assignments,
		localized("PROFILE_ACCOUNT_DEFAULT", "Account-wide default Decursive Profile"),
		function() return assignmentValues() end,
		function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			return state.account or "default"
		end,
		function(value)
			return ZD.SetAccountProfile and ZD:SetAccountProfile(value) or false
		end, profilesWritable)
	Controls:Cycle(assignments,
		localized("PROFILE_CHARACTER_ASSIGNMENT", "This character"),
		function()
			return assignmentValues(USE_ACCOUNT_PROFILE,
				localized("PROFILE_USE_ACCOUNT_DEFAULT", "Use account default"))
		end,
		function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			return state.character or USE_ACCOUNT_PROFILE
		end,
		function(value)
			if value == USE_ACCOUNT_PROFILE then value = nil end
			return ZD.SetCharacterProfile and ZD:SetCharacterProfile(value) or false
		end, profilesWritable)
	Controls:Toggle(assignments,
		localized("PROFILE_SPEC_ENABLED", "Per-specialization profiles"),
		localized("PROFILE_SPEC_ENABLED_DESC", "When enabled, changing specialization selects its assigned profile."),
		function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			return state.perSpecEnabled == true
		end,
		function(value)
			return ZD.SetSpecProfilesEnabled and ZD:SetSpecProfilesEnabled(value) or false
		end, profilesWritable)
	Controls:Cycle(assignments,
		localized("PROFILE_CURRENT_SPEC", "Current specialization"),
		function()
			return assignmentValues(USE_CHARACTER_PROFILE,
				localized("PROFILE_USE_CHARACTER_ASSIGNMENT", "Use character assignment"))
		end,
		function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			if state.perSpecEnabled ~= true then return USE_CHARACTER_PROFILE end
			return state.spec or USE_CHARACTER_PROFILE
		end,
		function(value)
			if value == USE_CHARACTER_PROFILE then value = nil end
			return ZD.SetCurrentSpecProfile and ZD:SetCurrentSpecProfile(value) or false
		end,
		function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			return profilesWritable() and state.perSpecEnabled == true
		end)
	Controls:StatusRow(assignments,
		localized("PROFILE_SPEC_ASSIGNMENT_STATE", "Specialization assignment state"), function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			if state.perSpecEnabled == true then
				return state.spec and ("Active: " .. (profileLabel(state.spec) or "Unknown"))
					or localized("PROFILE_SPEC_USES_FALLBACK", "Active: character/account fallback")
			end
			return state.storedSpec and ("Saved, inactive: " .. (profileLabel(state.storedSpec) or "Unknown"))
				or localized("PROFILE_SPEC_DISABLED", "Disabled")
		end, function()
			local state = ZD.GetProfileAssignments and ZD:GetProfileAssignments() or {}
			return state.perSpecEnabled == true and Theme.color.success or Theme.color.muted
		end)

	local behavior = Controls:Card(environment,
		localized("PROFILE_AUTOMATIC_BEHAVIOR", "Five complete Environment Profiles"),
		localized("PROFILE_AUTOMATIC_BEHAVIOR_DESC", "Every setting is independent in Open World, Party/Dungeon, Mythic+, Raid and PvP. Automatic precedence is PvP > Raid > Mythic+ > Party/Dungeon > Open World."))
	behavior:SetPoint("TOPLEFT", assignments, "BOTTOMLEFT", 0, -12)
	behavior:SetPoint("TOPRIGHT", assignments, "BOTTOMRIGHT", 0, -12)
	behavior:SetHeight(430)
	Controls:Cycle(behavior,
		localized("PROFILE_ACTIVATION_MODE", "Activation mode"),
		function() return environmentValues end,
		function() return ZD.GetEnvironmentSetting and ZD:GetEnvironmentSetting() or "AUTO" end,
		function(value)
			local applied = ZD.SetEnvironmentSetting and ZD:SetEnvironmentSetting(value) or false
			if applied then UI:SetStatus("Environment activation updated.", "success") end
			return applied
		end)
	Controls:StatusRow(behavior,
		localized("PROFILE_CURRENTLY_ACTIVE", "Currently active"), function()
			if not ZD.GetActiveEnvironment then return "Open World" end
			local _, name = ZD:GetActiveEnvironment()
			return name or "Open World"
		end, function() return Theme.color.success end)
	local selectedEnvironment = ZD.GetEditEnvironment and ZD:GetEditEnvironment() or "OPEN_WORLD"
	local configurationRow = CreateFrame("Frame", nil, behavior)
	configurationRow:SetPoint("TOPLEFT", 16, behavior.nextY)
	configurationRow:SetPoint("RIGHT", -16, 0)
	configurationRow:SetHeight(62)
	behavior.nextY = behavior.nextY - 70
	configurationRow.label = Controls:Label(configurationRow, "Environment Profiles", 10, Theme.color.muted)
	configurationRow.label:SetPoint("TOPLEFT", 0, 0)
	configurationRow.buttons = {}
	local previousEnvironmentButton
	for _, entry in ipairs(editEnvironmentValues) do
		local environmentKey = entry.key
		local environmentLabel = entry.label
		local button = Controls:Button(configurationRow, entry.label, 88, function()
			selectedEnvironment = environmentKey
			behavior:Refresh()
			UI:SetStatus("Selected Environment Profile: " .. environmentLabel .. ".", "success")
		end)
		button.environmentKey = environmentKey
		button:SetPoint("TOP", 0, -26)
		if previousEnvironmentButton then button:SetPoint("LEFT", previousEnvironmentButton, "RIGHT", 6, 0)
		else button:SetPoint("LEFT", 0, 0) end
		configurationRow.buttons[environmentKey] = button
		previousEnvironmentButton = button
	end
	behavior:AddRefresher(function()
		for environmentKey, button in pairs(configurationRow.buttons) do
			setRouteButtonActive(button, environmentKey == selectedEnvironment)
		end
	end)

	local editSelected = Controls:Button(behavior, "Edit Selected Environment Profile", 240, function()
		if ZD.SetEditEnvironment and ZD:SetEditEnvironment(selectedEnvironment) then
			UI:SetStatus("Editing Environment Profile: "
				.. (V13.SettingsSchema.environmentNames[selectedEnvironment] or selectedEnvironment) .. ".", "success")
			UI:ShowPage("OVERVIEW")
		end
	end, "primary")
	editSelected:SetPoint("TOPLEFT", 16, behavior.nextY)
	behavior.nextY = behavior.nextY - 42

	local copySource = "OPEN_WORLD"
	Controls:Cycle(behavior,
		localized("PROFILE_COPY_ENVIRONMENT_SOURCE", "Copy settings from"),
		function() return editEnvironmentValues end,
		function() return copySource end,
		function(value) copySource = value return true end)

	local copyEnvironment = Controls:ConfirmButton(behavior,
		localized("PROFILE_COPY_ENVIRONMENT", "Copy Into Selected"), 180, function()
			local selected = ZD.SetEditEnvironment and ZD:SetEditEnvironment(selectedEnvironment)
			if selected and ZD.CopyEnvironmentProfile and ZD:CopyEnvironmentProfile(copySource) then
				UI:SetStatus("Copied Environment Profile " .. (V13.SettingsSchema.environmentNames[copySource] or copySource)
					.. " into " .. (V13.SettingsSchema.environmentNames[selectedEnvironment] or selectedEnvironment) .. ".", "success")
				page:Refresh()
			end
		end)
	copyEnvironment:SetPoint("BOTTOMLEFT", 16, 16)

	local resetEnvironment = Controls:ConfirmButton(behavior,
		localized("PROFILE_RESET_ENVIRONMENT", "Reset Selected to Defaults"), 220, function()
			local selected = ZD.SetEditEnvironment and ZD:SetEditEnvironment(selectedEnvironment)
			if selected and ZD.ResetEnvironmentProfile and ZD:ResetEnvironmentProfile(selectedEnvironment) then
				UI:SetStatus("Environment Profile "
					.. (V13.SettingsSchema.environmentNames[selectedEnvironment] or selectedEnvironment)
					.. " reset to defaults.", "warning")
				page:Refresh()
			end
		end)
	resetEnvironment:SetPoint("LEFT", copyEnvironment, "RIGHT", 8, 0)

	function page:SetRoute(route)
		route = tostring(route or "DECURSIVE"):upper()
		if route == "DECURSIVE_PROFILES" or route == "PROFILES" or route == "SHARING" then
			route = "DECURSIVE"
		elseif route == "ENVIRONMENT_PROFILES" or route == "ENVIRONMENTPROFILES" then
			route = "ENVIRONMENT"
		end
		if not self.routeFrames[route] then route = "DECURSIVE" end

		self.currentRoute = route
		for routeKey, frame in pairs(self.routeFrames) do
			frame:SetShown(routeKey == route)
		end
		for routeKey, button in pairs(self.routeButtons) do
			setRouteButtonActive(button, routeKey == route)
		end
		self.contentHeight = self.routes[route].height
		if UI.frame and UI.currentPage == "PROFILES" then
			UI.frame.content:SetHeight(self.contentHeight)
			UI.frame.scroller:SetVerticalScroll(0)
		end
		UI.pendingProfilesRoute = nil
		self:Refresh()
		UI:SetStatus((route == "ENVIRONMENT"
			and localized("PROFILE_ENVIRONMENT_PAGE", "Environment Profiles")
			or localized("PROFILE_DECURSIVE_PAGE", "Decursive Profiles")) .. " ready.", "success")
	end

	function page:Refresh()
		local schema = ZD.GetProfileSchemaStatus and ZD:GetProfileSchemaStatus() or {}
		self.schemaWarning:SetShown(schema.readOnly == true)
		if schema.readOnly and schema.message then self.schemaWarning.text:SetText(schema.message) end
		local writable = schema.readOnly ~= true
		nameInput.edit:SetEnabled(writable)
		createProfile:SetEnabled(writable)
		copyProfile:SetEnabled(writable)
		resetProfile:SetEnabled(writable)
		renameProfile:SetEnabled(writable)
		deleteProfile:SetEnabled(writable and #deletableProfileValues() > 0)
		importButton:SetEnabled(writable)
		currentProfileCycle:Refresh()
		if self.currentRoute == "ENVIRONMENT" then
			assignments:Refresh()
			behavior:Refresh()
		else
			named:Refresh()
			deletion:Refresh()
		end
	end

	page:SetRoute(UI.pendingProfilesRoute or "DECURSIVE")
	return page
end)
