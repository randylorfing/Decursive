--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 complete settings workspace.
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
if not Controls or not Theme or not ZD then return end

local categories = {
    {
        key = "overview", label = "Overview",
        routes = {
            { key = "general", label = "General", builder = "BuildGeneral", direct = true },
            { key = "testmode", label = "Test Lab", builder = "BuildTestMode", height = 780 },
        },
    },
    {
        key = "core", label = "Core Setup",
        routes = {
            { key = "curing", label = "Curing", builder = "BuildCuring", direct = true },
            { key = "bindings", label = "Spells & Bindings", builder = "BuildBindings", direct = true },
            { key = "lists", label = "Priority & Skip", builder = "BuildLists", height = 590 },
			{ key = "macro", label = "Macro", builder = "BuildMacro", direct = true },
        },
    },
    {
        key = "visuals", label = "Visuals & Alerts",
        routes = {
            { key = "frames", label = "Micro Unit Frames", builder = "BuildFrames", direct = true },
            { key = "cooldowns", label = "Cooldowns", builder = "BuildCooldowns", height = 540 },
            { key = "range", label = "Range & Visibility", builder = "BuildRangeVisibility", height = 670 },
            { key = "livelist", label = "Live List", builder = "BuildLiveList", direct = true },
            { key = "messages", label = "Messages & Alerts", builder = "BuildMessages", direct = true },
            { key = "sounds", label = "Sounds", builder = "BuildSounds", height = 680 },
        },
    },
    {
        key = "afflictions", label = "Afflictions",
        routes = {
            { key = "filtering", label = "Filters", builder = "BuildFiltering", direct = true },
            { key = "bleeds", label = "Bleeds", builder = "BuildBleeds", direct = true },
            { key = "integrations", label = "Detection", builder = "BuildIntegrations", height = 460 },
            { key = "dispeldb", label = "Dispel Database", builder = "BuildDispelDB", height = 850 },
        },
    },
    {
        key = "support", label = "Support",
        routes = {
            { key = "compat121", label = "12.1 Status", builder = "BuildCompatibility121", direct = true },
            { key = "diagnostics", label = "Diagnostics", builder = "BuildDiagnostics", height = 520 },
            { key = "about", label = "About", builder = "BuildAdvanced", direct = true },
        },
    },
}

local routeIndex = {}
for _, category in ipairs(categories) do
    for _, route in ipairs(category.routes) do
        route.category = category
        routeIndex[route.key] = route
    end
end

local function setButtonActive(button, active)
    if not button then return end
    local fill = active and Theme.color.raised or Theme.color.surface
    local border = active and Theme.color.cyan or Theme.color.border
    button:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    button:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    button.text:SetTextColor(unpack(active and Theme.color.text or Theme.color.muted))
end

UI:RegisterPage("SETTINGS", "All Settings", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.routeContainers = {}
    page.routePages = {}
    page.categoryButtons = {}
    page.routeButtons = {}

    page.eyebrow = Controls:Label(page, "COMPLETE CONFIGURATION", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "All Settings", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -5)
    page.subtitle = Controls:Label(page,
        "Every established Decursive option, organized inside the new v13 command center.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -5)
    page.subtitle:SetPoint("RIGHT", 0, 0)

    local categoryBar = CreateFrame("Frame", nil, page)
    categoryBar:SetPoint("TOPLEFT", 0, -70)
    categoryBar:SetPoint("TOPRIGHT", 0, -70)
    categoryBar:SetHeight(30)
    page.categoryBar = categoryBar

    for _, category in ipairs(categories) do
        local categoryKey = category.key
        local firstRouteKey = category.routes[1].key
        local button = Controls:Button(categoryBar, category.label, 140, function(self)
            page:SetRoute(self.firstRouteKey)
        end)
        button.categoryKey = categoryKey
        button.firstRouteKey = firstRouteKey
        button:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(Theme.color.cyan))
        end)
        button:SetScript("OnLeave", function(self)
            local activeRoute = routeIndex[page.currentRoute or "general"]
            setButtonActive(self, activeRoute and activeRoute.category.key == self.categoryKey)
        end)
        page.categoryButtons[categoryKey] = button
    end

    local routeBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    routeBar:SetPoint("TOPLEFT", 0, -108)
    routeBar:SetPoint("TOPRIGHT", 0, -108)
    routeBar:SetHeight(42)
    Controls:SetBackdrop(routeBar, Theme.color.surface, Theme.color.border)
    page.routeBar = routeBar

    for _, category in ipairs(categories) do
        for _, route in ipairs(category.routes) do
            local routeKey = route.key
            local button = Controls:Button(routeBar, route.label, 140, function(self)
                page:SetRoute(self.routeKey)
            end)
            button.routeKey = routeKey
            button:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(unpack(Theme.color.cyan))
            end)
            button:SetScript("OnLeave", function(self)
                setButtonActive(self, page.currentRoute == self.routeKey)
            end)
            page.routeButtons[routeKey] = button
        end
    end

    local host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", routeBar, "BOTTOMLEFT", 0, -10)
    host:SetPoint("BOTTOMRIGHT", 0, 0)
    page.host = host

    local function buildRoute(route)
        if page.routePages[route.key] then return page.routePages[route.key] end

        local container
        local buildParent
        if route.direct then
            container = CreateFrame("Frame", nil, host)
            container:SetAllPoints()
            buildParent = container
        else
            container = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
            container:SetAllPoints()
            local canvas = CreateFrame("Frame", nil, container)
            canvas:SetHeight(route.height or 720)
            canvas:SetWidth(760)
            container:SetScrollChild(canvas)
            container:SetScript("OnSizeChanged", function(_, width)
                canvas:SetWidth(math.max(640, width - 24))
            end)
            buildParent = canvas
        end

        local builder = ZD[route.builder]
        local ok, routePage = pcall(function()
            if type(builder) ~= "function" then
                error("missing settings builder " .. tostring(route.builder))
            end
            return builder(ZD, buildParent)
        end)
        if not ok or not routePage then
            local failure = Controls:Label(buildParent,
                "This settings page could not be opened: " .. tostring(routePage),
                11, Theme.color.danger)
            failure:SetPoint("TOPLEFT", 12, -12)
            failure:SetPoint("RIGHT", -12, 0)
            failure:SetWordWrap(true)
            routePage = buildParent
            UI:SetStatus("Could not open " .. route.label .. ".", "error")
        end

        page.routeContainers[route.key] = container
        page.routePages[route.key] = routePage
        return routePage
    end

    function page:LayoutNavigation()
        local width = math.max(720, self:GetWidth() or 720)
        local categoryWidth = math.floor((width - (8 * (#categories - 1))) / #categories)
        local previous
        for _, category in ipairs(categories) do
            local button = self.categoryButtons[category.key]
            button:ClearAllPoints()
            button:SetWidth(categoryWidth)
            if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
            else button:SetPoint("LEFT", 0, 0) end
            previous = button
        end

        local active = routeIndex[self.currentRoute or "general"].category
        local routeWidth = math.floor((width - 20 - (8 * (#active.routes - 1))) / #active.routes)
        previous = nil
        for _, category in ipairs(categories) do
            for _, route in ipairs(category.routes) do
                local button = self.routeButtons[route.key]
                button:ClearAllPoints()
                button:SetShown(category == active)
                if category == active then
                    button:SetWidth(routeWidth)
                    if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
                    else button:SetPoint("LEFT", 10, 0) end
                    previous = button
                end
            end
        end
    end

    function page:SetRoute(key)
        local route = routeIndex[tostring(key or "general"):lower()] or routeIndex.general
        self.currentRoute = route.key
        buildRoute(route)
        for routeKey, container in pairs(self.routeContainers) do
            container:SetShown(routeKey == route.key)
        end
        for categoryKey, button in pairs(self.categoryButtons) do
            setButtonActive(button, categoryKey == route.category.key)
        end
        for routeKey, button in pairs(self.routeButtons) do
            setButtonActive(button, routeKey == route.key)
        end
        self:LayoutNavigation()
        local routePage = self.routePages[route.key]
        if routePage and routePage.Refresh then routePage:Refresh() end
        UI.pendingLegacyRoute = nil
        UI:SetStatus(route.label .. " ready.", "success")
    end

    function page:Refresh()
        local pending = UI.pendingLegacyRoute
        if pending and pending ~= self.currentRoute then
            self:SetRoute(pending)
            return
        end
        UI.pendingLegacyRoute = nil
        local routePage = self.routePages[self.currentRoute or "general"]
        if routePage and routePage.Refresh then routePage:Refresh() end
    end

    page:SetScript("OnSizeChanged", function(self) self:LayoutNavigation() end)
    page:SetRoute(UI.pendingLegacyRoute or "general")
    return page
end, { workspace = true })
