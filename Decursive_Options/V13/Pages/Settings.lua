--[[
    This file is part of Decursive.

    Task-oriented environment-profile settings workspaces.
    Copyright (C) 2026 Randy Lorfing

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive. If not, see <https://www.gnu.org/licenses/>.
--]]

local T = DecursiveRootTable
if not T or not T.ZhaohuV13 or not T.ZhaohuV13.Options then return end

local V13 = T.ZhaohuV13
local UI = V13.Options
local Controls = UI.Controls
local Theme = V13.Theme
local ZD = T.ZhaohuModern
local D = T.Dcr
if not Controls or not Theme or not ZD or not D then return end

local taskPages = {
    MUFS = {
        label = "MUF Setup",
        routes = {
            { key = "units", label = "Units & Visibility", builder = "BuildRangeVisibility", height = 700 },
            { key = "frames", label = "Layout & Appearance", builder = "BuildFrames", direct = true },
            { key = "cooldowns", label = "Range / LoS / Cooldowns", builder = "BuildCooldowns", height = 560 },
            { key = "livelist", label = "Live List", builder = "BuildLiveList", direct = true },
        },
    },
    CURE = {
        label = "Cures & Mouse Bindings",
        routes = {
            { key = "bindings", label = "Automatic / Manual", builder = "BuildBindings", direct = true },
            { key = "curing", label = "Cure Order & Priority", builder = "BuildCuring", direct = true },
            { key = "lists", label = "Priority & Skip Lists", builder = "BuildLists", height = 610 },
            { key = "actions", label = "Custom / Additional Actions", builder = "BuildBindings", direct = true },
            { key = "macro", label = "Mouseover Macro", builder = "BuildMacro", direct = true },
        },
    },
    ALERTS = {
        label = "Alerts & Feedback",
        routes = {
            { key = "messages", label = "Alerts & Feedback", builder = "BuildMessages", direct = true },
            { key = "sounds", label = "Sounds", builder = "BuildSounds", height = 700 },
        },
    },
    ADVANCED = {
        label = "Advanced & Diagnostics",
        routes = {
            { key = "general", label = "Profile Settings", builder = "BuildGeneral", direct = true },
            { key = "filtering", label = "Affliction Filtering", builder = "BuildFiltering", direct = true },
            { key = "bleeds", label = "Bleed Detection", builder = "BuildBleeds", direct = true },
            { key = "integrations", label = "Detection & Integrations", builder = "BuildIntegrations", height = 480 },
            { key = "dispeldb", label = "Dispel Database", builder = "BuildDispelDB", height = 870 },
            { key = "testmode", label = "Test Lab", builder = "BuildTestMode", height = 800 },
            { key = "compat121", label = "12.1 Status", builder = "BuildCompatibility121", direct = true },
            { key = "diagnostics", label = "Diagnostics", builder = "BuildDiagnostics", height = 540 },
            { key = "about", label = "About", builder = "BuildAdvanced", direct = true },
        },
    },
}

local routeOwners = {}
for pageKey, definition in pairs(taskPages) do
    for _, route in ipairs(definition.routes) do
        routeOwners[route.key] = { page = pageKey, route = route.key }
    end
end
UI.environmentTaskRoutes = routeOwners

local function setButtonActive(button, active)
    if not button then return end
    local fill = active and Theme.color.raised or Theme.color.surface
    local border = active and Theme.color.cyan or Theme.color.border
    button:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    button:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    button.text:SetTextColor(unpack(active and Theme.color.text or Theme.color.muted))
end

local function registerTaskPage(pageKey, definition)
    UI:RegisterPage(pageKey, definition.label, function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page.routeContainers = {}
        page.routePages = {}
        page.routeButtons = {}

        page.eyebrow = Controls:Label(page,
            "DECURSIVE PROFILE  >  ENVIRONMENT PROFILE  >  " .. string.upper(definition.label),
            9, Theme.color.cyan)
        page.eyebrow:SetPoint("TOPLEFT", 0, -2)
        page.title = Controls:Label(page, definition.label, 20, Theme.color.text)
        page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -5)
        page.subtitle = Controls:Label(page, "", 10, Theme.color.muted)
        page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -5)
        page.subtitle:SetPoint("RIGHT", 0, 0)

        local routeBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
        routeBar:SetPoint("TOPLEFT", 0, -70)
        routeBar:SetPoint("TOPRIGHT", 0, -70)
        routeBar:SetHeight(#definition.routes > 5 and 84 or 44)
        Controls:SetBackdrop(routeBar, Theme.color.surface, Theme.color.border)
        page.routeBar = routeBar

        for _, route in ipairs(definition.routes) do
            local routeKey = route.key
            local button = Controls:Button(routeBar, route.label, 140, function(self)
                page:SetRoute(self.routeKey)
            end)
            button.routeKey = routeKey
            page.routeButtons[routeKey] = button
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
                if type(builder) ~= "function" then error("missing settings builder " .. tostring(route.builder)) end
                return builder(ZD, buildParent)
            end)
            if not ok or not routePage then
                local failure = Controls:Label(buildParent,
                    "This environment-profile settings page could not be opened: " .. tostring(routePage),
                    11, Theme.color.danger)
                failure:SetPoint("TOPLEFT", 12, -12)
                failure:SetPoint("RIGHT", -12, 0)
                failure:SetWordWrap(true)
                routePage = buildParent
            end
            page.routeContainers[route.key] = container
            page.routePages[route.key] = routePage
            return routePage
        end

        function page:LayoutNavigation()
            local width = math.max(720, self:GetWidth() or 720)
            local columns = math.min(5, #definition.routes)
            local buttonWidth = math.floor((width - 20 - 8 * (columns - 1)) / columns)
            for index, route in ipairs(definition.routes) do
                local button = self.routeButtons[route.key]
                button:ClearAllPoints()
                button:SetWidth(buttonWidth)
                local column = (index - 1) % columns
                local row = math.floor((index - 1) / columns)
                button:SetPoint("TOPLEFT", 10 + column * (buttonWidth + 8), -8 - row * 36)
            end
        end

        function page:SetRoute(key)
            local selected = definition.routes[1]
            for _, route in ipairs(definition.routes) do
                if route.key == key then selected = route break end
            end
            self.currentRoute = selected.key
            buildRoute(selected)
            for routeKey, container in pairs(self.routeContainers) do
                container:SetShown(routeKey == selected.key)
            end
            for routeKey, button in pairs(self.routeButtons) do
                setButtonActive(button, routeKey == selected.key)
            end
            local routePage = self.routePages[selected.key]
            if routePage and routePage.SetTab and ZD.pendingOptionTab then
                routePage:SetTab(ZD.pendingOptionTab)
                ZD.pendingOptionTab = nil
            end
            if routePage and routePage.Refresh then routePage:Refresh() end
            UI.pendingTaskRoute = nil
            UI:SetStatus(selected.label .. " — editing the selected Environment Profile.", "success")
        end

        function page:Refresh()
            local context = ZD.GetProfileContext and ZD:GetProfileContext() or {}
            local environment = V13.SettingsSchema.environmentNames[context.editEnvironment]
                or context.editEnvironment or "Open World"
            local profile = context.profileName or "Default"
            self.subtitle:SetText("Decursive Profile: " .. profile
                .. "  |  Editing Environment Profile: " .. environment
                .. ". Every control below is stored in this complete environment configuration.")
            local pending = UI.pendingTaskRoute
            if pending and pending ~= self.currentRoute then
                self:SetRoute(pending)
                return
            end
            UI.pendingTaskRoute = nil
            local routePage = self.routePages[self.currentRoute]
            if routePage and routePage.Refresh then routePage:Refresh() end
        end

        page:SetScript("OnSizeChanged", function(self) self:LayoutNavigation() end)
        page:LayoutNavigation()
        page:SetRoute(UI.pendingTaskRoute or definition.routes[1].key)
        return page
    end, { workspace = true })
end

for pageKey, definition in pairs(taskPages) do registerTaskPage(pageKey, definition) end
