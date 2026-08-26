--[[
    This file is part of Decursive.

    Zhaohu's Decursive v11 LoadOnDemand options bootstrap. This file was
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

    Zhaohu's Decursive — LoadOnDemand options bootstrap (always resident).

    The settings panel, Blizzard Settings canvas, Ace option tree, and Test Mode
    UI live in Decursive_Options. Nothing loads that companion automatically;
    this file is the single place that does (LoadOnDemand Options companion).
--]]

local addonName, T = ...
local D = T and T.Dcr
if not D then return end

local ZD = T.ZhaohuModern or {}
T.ZhaohuModern = ZD
D.ZhaohuModern = ZD

local OPTIONS_ADDON = "Decursive_Options"

local LoadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
local EnableAddOn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
local GetAddOnEnableState = C_AddOns and C_AddOns.GetAddOnEnableState
local DoesAddOnExist = C_AddOns and C_AddOns.DoesAddOnExist
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local function printErr(msg)
    if D.ColorPrint then
        D:ColorPrint(1, 0.25, 0.2, msg)
    elseif D.Println then
        D:Println(msg)
    else
        print("|cffff4020Decursive:|r " .. tostring(msg))
    end
end

local function printMsg(msg)
    if D.Println then
        D:Println(msg)
    else
        print("|cff55ffffDecursive:|r " .. tostring(msg))
    end
end

local function closeBlizzardSettings()
    if not SettingsPanel or not SettingsPanel:IsShown() then return true end
    if SettingsPanel.Close then
        SettingsPanel:Close(true)
    elseif HideUIPanel then
        HideUIPanel(SettingsPanel)
    else
        SettingsPanel:Hide()
    end
    return not SettingsPanel:IsShown()
end

-- 0 = disabled. Midnight may use one-arg or two-arg GetAddOnEnableState.
local function GetOptionsEnableState()
    if not GetAddOnEnableState then return 2 end

    local ok, state = pcall(GetAddOnEnableState, OPTIONS_ADDON)
    if ok and type(state) == "number" then return state end

    local character = UnitName and UnitName("player") or nil
    ok, state = pcall(GetAddOnEnableState, character, OPTIONS_ADDON)
    if ok and type(state) == "number" then return state end

    ok, state = pcall(GetAddOnEnableState, OPTIONS_ADDON, nil)
    if ok and type(state) == "number" then return state end

    return 2 -- unknown: treat as enabled and try LoadAddOn
end

local function UnavailableReason()
    if DoesAddOnExist and not DoesAddOnExist(OPTIONS_ADDON) then
        return "not installed (folder Interface\\AddOns\\Decursive_Options is missing)"
    end
    return nil
end

--- Load the companion, returning true once its files are in memory.
function ZD:EnsureOptionsLoaded()
    if ZD._optionsAddonLoaded then return true end
    if IsAddOnLoaded and IsAddOnLoaded(OPTIONS_ADDON) then
        ZD._optionsAddonLoaded = true
        return true
    end

    local why = UnavailableReason()
    if why then
        printErr(("Settings are unavailable: %s is %s."):format(OPTIONS_ADDON, why))
        return false
    end

    -- New LoD companions often never appear in AddOns.txt until enabled once.
    local state = GetOptionsEnableState()
    if state == 0 then
        if EnableAddOn then
            pcall(EnableAddOn, OPTIONS_ADDON)
            printMsg("Enabled Decursive_Options for this character (required for /dcr settings).")
        else
            printErr("Decursive_Options is disabled. At character select open AddOns, expand Zhaohu's Decursive, and enable Options.")
            return false
        end
    end

    local loaded, reason = LoadAddOn(OPTIONS_ADDON)
    if not loaded then
        -- One more enable+load attempt for LoD children that were never registered.
        if EnableAddOn then pcall(EnableAddOn, OPTIONS_ADDON) end
        loaded, reason = LoadAddOn(OPTIONS_ADDON)
    end
    if not loaded then
        printErr(("Could not load %s (%s). Check AddOns list for Decursive_Options."):format(OPTIONS_ADDON, tostring(reason)))
        return false
    end

    ZD._optionsAddonLoaded = true
    return true
end

local toggleStub
toggleStub = function(self)
    if not ZD:EnsureOptionsLoaded() then return end
    if ZD.ToggleUI == toggleStub then
        printErr(("%s loaded but did not provide the settings panel — its .toc may be incomplete."):format(OPTIONS_ADDON))
        return
    end
    return ZD:ToggleUI()
end
ZD.ToggleUI = toggleStub

local createStub
createStub = function(self)
    if not ZD:EnsureOptionsLoaded() then return nil end
    if ZD.CreateUI == createStub then
        printErr(("%s loaded but did not provide CreateUI."):format(OPTIONS_ADDON))
        return nil
    end
    return ZD:CreateUI()
end
ZD.CreateUI = createStub

local showPageStub
showPageStub = function(self, key)
    if not ZD:EnsureOptionsLoaded() then return end
    if ZD.ShowPage == showPageStub then return end
    return ZD:ShowPage(key)
end
ZD.ShowPage = showPageStub

function ZD:RefreshUI() end
function ZD:MarkOptionsDirty() end

function ZD:RegisterBlizzardSettingsLauncher()
    if self._blizzardLauncherRegistered then return self.blizzardSettingsCategory end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return nil
    end

    local panel = CreateFrame("Frame", "ZhaohusDecursiveBlizzardSettingsLauncher")
    panel.name = "Zhaohu's Decursive"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText("Zhaohu's Decursive")

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    note:SetPoint("TOPLEFT", 24, -60)
    note:SetPoint("TOPRIGHT", -24, -60)
    note:SetJustifyH("LEFT")
    note:SetText("Open the full settings panel for curing, Micro Unit Frames, profiles, and 12.1 status.\nThe companion Decursive_Options loads on demand the first time you open settings.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 28)
    openBtn:SetPoint("TOPLEFT", 24, -120)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        if ZD:EnsureOptionsLoaded() and ZD.ToggleUI and ZD.ToggleUI ~= toggleStub then
            local f = ZD:CreateUI()
            if f and closeBlizzardSettings() then
                f:Show()
                if ZD.ShowPage then ZD:ShowPage("dashboard") end
            end
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Zhaohu's Decursive")
    if category then
        Settings.RegisterAddOnCategory(category)
        self.blizzardSettingsCategory = category
        if category.GetID then
            self.blizzardSettingsCategoryID = category:GetID()
        else
            self.blizzardSettingsCategoryID = "Zhaohu's Decursive"
        end
        self._blizzardLauncherRegistered = true
    end
    return category
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    ZD:RegisterBlizzardSettingsLauncher()
    -- Rogue / non-dispel classes: still announce that the core loaded.
    if D and D.Println and UnitClass then
        local _, classFile = UnitClass("player")
        if classFile == "ROGUE" or classFile == "WARRIOR" or classFile == "DEMONHUNTER" or classFile == "HUNTER" then
            D:Println("Loaded. This class has no friendly dispel — use /dcr for settings. Switch to a healer to test curing/MUFs.")
        end
    end
end)
