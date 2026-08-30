--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 settings shell.
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
if not T or not T.ZhaohuV13 or not T.ZhaohuV13.Theme then return end

local V13 = T.ZhaohuV13
local Theme = V13.Theme
local UI = V13.Options or {}
local Controls = UI.Controls
local D = T.Dcr
local ZD = T.ZhaohuModern
if not Controls or not D or not ZD then return end

V13.Options = UI
UI.pageDefinitions = UI.pageDefinitions or {}
UI.pages = UI.pages or {}
UI.currentPage = UI.currentPage or "OVERVIEW"
UI.statusText = UI.statusText or "Ready"

local MAX_SEARCH_RESULTS = 6

local function localized(key, fallback)
    return D.L and D.L[key] or fallback
end

function UI:RegisterPage(key, label, builder, options)
    self.pageDefinitions[key] = {
        label = label,
        builder = builder,
        workspace = options and options.workspace == true,
    }
end

function UI:SetStatus(message, kind)
    self.statusText = tostring(message or "Ready")
    self.statusKind = kind
    self:RefreshStatus()
end

function UI:RefreshStatus()
    if not self.frame or not self.frame.footer then return end
    local footer = self.frame.footer
    local color = Theme.color.muted
    if self.statusKind == "error" then color = Theme.color.danger end
    if self.statusKind == "warning" then color = Theme.color.warning end
    if self.statusKind == "success" then color = Theme.color.success end
    footer.status:SetText(self.statusText)
    footer.status:SetTextColor(color[1], color[2], color[3], color[4])
    footer.combat:SetText(InCombatLockdown and InCombatLockdown() and "SETTINGS LOCKED IN COMBAT" or "CHANGES APPLY IMMEDIATELY")
    footer.combat:SetTextColor(unpack(InCombatLockdown and InCombatLockdown()
        and Theme.color.warning or Theme.color.muted))
end

local function addToSpecialFrames(frame)
    if not UISpecialFrames then return end
    for _, name in ipairs(UISpecialFrames) do
        if name == frame:GetName() then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
end

local function updateContext(frame)
    local profile = ZD.GetUserProfileName and ZD:GetUserProfileName() or "Default"
    local _, environment = ZD.GetActiveEnvironment and ZD:GetActiveEnvironment() or nil, "Open World"
    if ZD.GetActiveEnvironment then
        local _, display = ZD:GetActiveEnvironment()
        environment = display or environment
    end
    frame.header.context.text:SetText(profile .. "  /  " .. environment)
end

local function buildTestRail(parent)
    local rail = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rail:SetPoint("TOPRIGHT", -Theme.spacing.card, -Theme.spacing.card)
    rail:SetPoint("BOTTOMRIGHT", -Theme.spacing.card, Theme.spacing.card)
    rail:SetWidth(Theme.size.testRailWidth)
    Controls:SetBackdrop(rail, Theme.color.surface, Theme.color.border)

    rail.eyebrow = Controls:Label(rail, "LIVE TEST CENTER", 9, Theme.color.cyan)
    rail.eyebrow:SetPoint("TOPLEFT", 16, -16)
    rail.title = Controls:Label(rail, "Preview the real behavior", 13, Theme.color.text)
    rail.title:SetPoint("TOPLEFT", rail.eyebrow, "BOTTOMLEFT", 0, -7)
    rail.note = Controls:Label(rail,
        "Tests call the same presentation and sound APIs used by live events.",
        9, Theme.color.muted)
    rail.note:SetPoint("TOPLEFT", rail.title, "BOTTOMLEFT", 0, -7)
    rail.note:SetPoint("RIGHT", -16, 0)
    rail.note:SetWordWrap(true)

    local textButton = Controls:Button(rail, "Preview Dispel Text", 216, function()
        local notifications = V13:GetModule("NotificationBridge")
        local shown = notifications and notifications:PreviewDispelText()
        UI:SetStatus(shown and "Dispel text preview started." or "Dispel text preview unavailable.", shown and "success" or "error")
    end, "primary")
    textButton:SetPoint("TOPLEFT", 16, -112)

    local soundButton = Controls:Button(rail, "Test Selected Sound", 216, function()
        local notifications = V13:GetModule("NotificationBridge")
        if notifications and notifications:PreviewSound() then
            UI:SetStatus("Played selected dispel sound.", "success")
        else
            UI:SetStatus("Sound test is not available yet.", "error")
        end
    end)
    soundButton:SetPoint("TOPLEFT", textButton, "BOTTOMLEFT", 0, -8)

    local cooldownButton = Controls:Button(rail, "Preview Cooldown", 216, function()
        local notifications = V13:GetModule("NotificationBridge")
        if notifications and notifications:PreviewCooldown() then
            UI:SetStatus("Cooldown preview started.", "success")
        else
            UI:SetStatus("Cooldown preview is not available yet.", "error")
        end
    end)
    cooldownButton:SetPoint("TOPLEFT", soundButton, "BOTTOMLEFT", 0, -8)

    rail.runtime = Controls:Label(rail, "RUNTIME", 9, Theme.color.cyan)
    rail.runtime:SetPoint("TOPLEFT", cooldownButton, "BOTTOMLEFT", 0, -32)
    rail.provider = Controls:Label(rail, "Native Blizzard-managed", 10, Theme.color.text)
    rail.provider:SetPoint("TOPLEFT", rail.runtime, "BOTTOMLEFT", 0, -8)
    rail.provider:SetPoint("RIGHT", -16, 0)
    rail.provider:SetWordWrap(true)
    rail.safety = Controls:Label(rail, "12.1 protected-aura safe", 10, Theme.color.success)
    rail.safety:SetPoint("TOPLEFT", rail.provider, "BOTTOMLEFT", 0, -8)
    rail.safety:SetPoint("RIGHT", -16, 0)
    return rail
end

function UI:RefreshSearchResults(query, resetSelection)
    local frame = self.frame
    local panel = frame and frame.searchResults
    if not panel then return {} end

    local results = ZD.FindSearchResults and ZD:FindSearchResults(query, MAX_SEARCH_RESULTS) or {}
    frame.searchMatches = results
    if resetSelection then frame.searchSelection = 1 end
    frame.searchSelection = math.max(1, math.min(frame.searchSelection or 1, math.max(1, #results)))

    if query == "" or #results == 0 then
        panel:Hide()
        return results
    end

    for index, row in ipairs(panel.rows) do
        local result = results[index]
        row.result = result
        row:SetShown(result ~= nil)
        if result then
            row.title:SetText(result.label or localized("SEARCH", "Search"))
            row.route:SetText(result.pageName or result.page or "")
            local selected = index == frame.searchSelection
            row:SetBackdropBorderColor(unpack(selected and Theme.color.cyan or Theme.color.border))
        end
    end
    panel:SetHeight(8 + #results * 36)
    panel:Show()
    return results
end

function UI:MoveSearchSelection(delta)
    local frame = self.frame
    local results = frame and frame.searchMatches or {}
    if #results == 0 then return false end
    frame.searchSelection = ((frame.searchSelection or 1) - 1 + delta) % #results + 1
    self:RefreshSearchResults(frame.search and frame.search:GetText() or "")
    return true
end

function UI:SelectSearchResult(result)
    local frame = self.frame
    if not result and frame then result = (frame.searchMatches or {})[frame.searchSelection or 1] end
    if type(result) ~= "table" or type(result.page) ~= "string" then return false end
    UI:OpenLegacyRoute(result.page)
    self:SetStatus((localized("SEARCH", "Search") .. ": " .. (result.label or result.pageName or result.page)), "success")
    if frame and frame.search then frame.search:ClearFocus() end
    if frame and frame.searchResults then frame.searchResults:Hide() end
    return true
end

function UI:CreateShell()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "ZhaohusDecursiveV13Frame", UIParent, "BackdropTemplate")
    frame:SetSize(Theme.size.windowWidth, Theme.size.windowHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(Theme.size.minimumWidth, Theme.size.minimumHeight, 1500, 1050)
    end
    Controls:SetBackdrop(frame, Theme.color.canvas, Theme.color.border)
    addToSpecialFrames(frame)
    self.frame = frame

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(Theme.size.headerHeight)
    Controls:SetBackdrop(header, Theme.color.surface, Theme.color.border)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not InCombatLockdown or not InCombatLockdown() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.header = header

    header.eyebrow = Controls:Label(header, "ZHAOHU'S DECURSIVE", 9, Theme.color.cyan)
    header.eyebrow:SetPoint("TOPLEFT", 18, -13)
    header.title = Controls:Label(header, "Detect  /  Cleanse  /  Protect", 18, Theme.color.text)
    header.title:SetPoint("TOPLEFT", header.eyebrow, "BOTTOMLEFT", 0, -6)

    header.close = Controls:Button(header, "X", 30, function() frame:Hide() end)
    header.close:SetPoint("RIGHT", -16, 0)
    header.context = Controls:Pill(header, "Default  /  Open World", Theme.color.cyan)
    header.context:SetWidth(190)
    header.context:SetPoint("RIGHT", header.close, "LEFT", -10, 0)

    local search = CreateFrame("EditBox", nil, header, "BackdropTemplate")
    search:SetSize(286, 30)
    search:SetPoint("RIGHT", header.context, "LEFT", -10, 0)
    search:SetAutoFocus(false)
    search:SetFontObject(GameFontHighlight)
    search:SetTextInsets(12, 12, 0, 0)
    Controls:SetBackdrop(search, Theme.color.canvas, Theme.color.border)
    search.placeholder = Controls:Label(search, "Search settings...", 10, Theme.color.muted)
    search.placeholder:SetPoint("LEFT", 12, 0)
    search:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self.placeholder:Show() end
    end)
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.placeholder:SetShown(text == "" and not self:HasFocus())
        UI:RefreshSearchResults(text, true)
    end)
    search:SetScript("OnEnterPressed", function(self)
        if UI:SelectSearchResult() then return end
        local results = V13.SettingsSchema and V13.SettingsSchema:Search(self:GetText()) or {}
        local match = results[1]
        if match then
            UI:ShowPage(match.page)
            UI:SetStatus("Opened " .. (match.label or match.key) .. ".", "success")
            self:ClearFocus()
        else
            UI:SetStatus("No setting matched that search.", "warning")
        end
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if frame.searchResults then frame.searchResults:Hide() end
    end)
    search:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then UI:MoveSearchSelection(-1) end
        if key == "DOWN" then UI:MoveSearchSelection(1) end
    end)
    frame.search = search

    local searchResults = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    searchResults:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -4)
    searchResults:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -4)
    searchResults:SetHeight(8)
    searchResults:SetFrameStrata("DIALOG")
    searchResults:SetFrameLevel(header:GetFrameLevel() + 20)
    searchResults:SetClampedToScreen(true)
    Controls:SetBackdrop(searchResults, Theme.color.surface, Theme.color.border)
    searchResults.rows = {}
    for index = 1, MAX_SEARCH_RESULTS do
        local row = CreateFrame("Button", nil, searchResults, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 36)
        row:SetPoint("TOPRIGHT", -4, -4 - (index - 1) * 36)
        row:SetHeight(32)
        row:RegisterForClicks("LeftButtonUp")
        Controls:SetBackdrop(row, Theme.color.canvas, Theme.color.border)
        row.title = Controls:Label(row, "", 10, Theme.color.text)
        row.title:SetPoint("LEFT", 8, 0)
        row.title:SetPoint("RIGHT", -96, 0)
        row.route = Controls:Label(row, "", 9, Theme.color.muted)
        row.route:SetPoint("RIGHT", -8, 0)
        row.route:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self) UI:SelectSearchResult(self.result) end)
        row:SetScript("OnEnter", function(self)
            if self.result then self:SetBackdropBorderColor(unpack(Theme.color.cyan)) end
        end)
        row:SetScript("OnLeave", function(self)
            local selected = self.result and self.result == (frame.searchMatches or {})[frame.searchSelection or 1]
            self:SetBackdropBorderColor(unpack(selected and Theme.color.cyan or Theme.color.border))
        end)
        row:Hide()
        searchResults.rows[index] = row
    end
    searchResults:Hide()
    frame.searchResults = searchResults
    frame.searchMatches = {}
    frame.searchSelection = 1

    local commandBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    commandBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    commandBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    commandBar:SetHeight(Theme.size.commandBarHeight)
    Controls:SetBackdrop(commandBar, Theme.color.canvas, Theme.color.border)
    frame.commandBar = commandBar
    frame.navButtons = {}

    local previous
    for _, item in ipairs(Theme.navigation) do
        -- WoW's Lua runtime reuses generic-for control variables. Store the
        -- destination on the button instead of closing over `item`, otherwise
        -- every command-bar button can resolve to the final navigation entry.
        local navigationKey = item.key
        local button = CreateFrame("Button", nil, commandBar)
        button:RegisterForClicks("LeftButtonUp")
        button:SetHeight(Theme.size.commandBarHeight - 2)
        button:SetWidth(navigationKey == "PROFILES" and 108 or 96)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 2, 0)
        else button:SetPoint("LEFT", 12, 0) end
        button.label = Controls:Label(button, item.label:upper(), 10, Theme.color.muted)
        button.label:SetPoint("CENTER")
        button.line = button:CreateTexture(nil, "ARTWORK")
        button.line:SetHeight(2)
        button.line:SetPoint("BOTTOMLEFT", 8, 0)
        button.line:SetPoint("BOTTOMRIGHT", -8, 0)
        button.line:SetColorTexture(unpack(Theme.color.cyan))
        button.line:Hide()
        button.navigationKey = navigationKey
        button:SetScript("OnClick", function(self) UI:ShowPage(self.navigationKey) end)
        button:SetScript("OnEnter", function(self)
            if UI.currentPage ~= self.navigationKey then self.label:SetTextColor(unpack(Theme.color.text)) end
        end)
        button:SetScript("OnLeave", function(self)
            if UI.currentPage ~= self.navigationKey then self.label:SetTextColor(unpack(Theme.color.muted)) end
        end)
        frame.navButtons[navigationKey] = button
        previous = button
    end

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", commandBar, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", 0, Theme.size.footerHeight)
    frame.body = body
    frame.testRail = buildTestRail(body)

    local scroller = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroller:SetPoint("TOPLEFT", Theme.spacing.card, -Theme.spacing.card)
    scroller:SetPoint("BOTTOMLEFT", Theme.spacing.card, Theme.spacing.card)
    scroller:SetPoint("RIGHT", frame.testRail, "LEFT", -Theme.spacing.section, 0)
    frame.scroller = scroller

    local content = CreateFrame("Frame", nil, scroller)
    content:SetHeight(760)
    content:SetWidth(620)
    scroller:SetScrollChild(content)
    scroller:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(math.max(420, width - 2))
    end)
    frame.content = content

    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(Theme.size.footerHeight)
    Controls:SetBackdrop(footer, Theme.color.surface, Theme.color.border)
    footer.status = Controls:Label(footer, "Ready", 9, Theme.color.muted)
    footer.status:SetPoint("LEFT", 14, 0)
    footer.combat = Controls:Label(footer, "CHANGES APPLY IMMEDIATELY", 9, Theme.color.muted)
    footer.combat:SetPoint("CENTER")
    footer.version = Controls:Label(footer, "v13 candidate  /  WoW 12.1", 9, Theme.color.muted)
    footer.version:SetPoint("RIGHT", -14, 0)
    frame.footer = footer

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetScript("OnMouseDown", function()
        if not InCombatLockdown or not InCombatLockdown() then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

    frame:SetScript("OnShow", function()
        updateContext(frame)
        UI:ShowPage(UI.currentPage)
        UI:RefreshStatus()
    end)
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
    frame:SetScript("OnKeyDown", function(self, key)
        local focusSearch = key == "F" and IsControlKeyDown and IsControlKeyDown()
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not focusSearch) end
        if focusSearch then
            search:SetFocus()
            search:HighlightText()
        end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        if not frame:IsShown() then return end
        updateContext(frame)
        UI:RefreshStatus()
        local page = UI.pages[UI.currentPage]
        if page and page.Refresh then page:Refresh() end
    end)
    frame:Hide()
    return frame
end

function UI:ShowPage(key)
    local frame = self:CreateShell()
    local definition = self.pageDefinitions[key]
    if not definition then
        key = "OVERVIEW"
        definition = self.pageDefinitions[key]
    end
    if not definition then return end

    local page = self.pages[key]
    if not page then
        page = definition.builder(definition.workspace and frame.body or frame.content)
        self.pages[key] = page
    end
    for pageKey, existing in pairs(self.pages) do
        existing:SetShown(pageKey == key)
    end
    for navKey, button in pairs(frame.navButtons) do
        local active = navKey == key
        button.line:SetShown(active)
        button.label:SetTextColor(unpack(active and Theme.color.cyan or Theme.color.muted))
    end
    self.currentPage = key
    frame.scroller:SetShown(not definition.workspace)
    frame.testRail:SetShown(not definition.workspace)
    if definition.workspace then
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", Theme.spacing.card, -Theme.spacing.card)
        page:SetPoint("BOTTOMRIGHT", -Theme.spacing.card, Theme.spacing.card)
    else
        frame.content:SetHeight(page.contentHeight or 760)
        frame.scroller:SetVerticalScroll(0)
    end
    if page.Refresh then page:Refresh() end
end

function UI:Open(page)
    local frame = self:CreateShell()
    frame:Show()
    self:ShowPage(page or self.currentPage)
end

function UI:Toggle()
    local frame = self:CreateShell()
    if frame:IsShown() then frame:Hide() else self:Open() end
end

local LEGACY_ROUTES = {
    general = true, sounds = true, frames = true, curing = true, bleeds = true,
    cooldowns = true, range = true, bindings = true, filtering = true,
    livelist = true, messages = true, macro = true, profiles = true,
    sharing = true, lists = true, integrations = true, testmode = true,
    compat121 = true, diagnostics = true, dispeldb = true, about = true,
}

function UI:OpenLegacyRoute(route)
    route = tostring(route or "dashboard"):lower()
    if route == "dashboard" then
        return self:Open("OVERVIEW")
    end
    if not LEGACY_ROUTES[route] then route = "general" end
    self.pendingLegacyRoute = route
    local frame = self:CreateShell()
    frame:Show()
    self:ShowPage("SETTINGS")
    local page = self.pages.SETTINGS
    if page and page.SetRoute then page:SetRoute(route) end
end

-- The v13 shell is the only user-facing settings window. The mature settings
-- model and its page builders remain loaded behind the new shell so bindings,
-- custom spells, lists and every established option stay available.
function UI:InstallAsPrimary()
    ZD.CreateUI = function() return UI:CreateShell() end
    ZD.ShowPage = function(_, key)
        key = tostring(key or "OVERVIEW")
        local upper = key:upper()
        if UI.pageDefinitions[upper] then return UI:ShowPage(upper) end
        return UI:OpenLegacyRoute(key)
    end
    ZD.ToggleUI = function() return UI:Toggle() end
    ZD.SetStatus = function(_, message, isError)
        UI:SetStatus(message, isError and "error" or "success")
    end
    ZD.MarkOptionsDirty = function()
        ZD.searchIndex = nil
        local settings = UI.pages.SETTINGS
        if settings then
            local activeRoutePage = settings.routePages
                and settings.routePages[settings.currentRoute or "general"]
            for _, page in pairs(settings.routePages or {}) do
                if page and page ~= activeRoutePage and page.optionCanvas then
                    page._needsRebuild = true
                end
            end
        end
        ZD:RefreshUI()
    end
    ZD.RefreshUI = function()
        local frame = UI.frame
        if not frame or not frame:IsShown() then return end
        UI:RefreshStatus()
        local page = UI.pages[UI.currentPage]
        if page and page.IsShown and page:IsShown() and page.Refresh then page:Refresh() end
    end
end

UI:InstallAsPrimary()
