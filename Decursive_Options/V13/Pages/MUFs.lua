--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 MUF page.. This file was solely written by Randy Lorfing.
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

local function setProfile(key, value)
    if ZD.SetProfileOption then ZD:SetProfileOption(key, value)
    elseif D.profile then D.profile[key] = value end
end

UI:RegisterPage("MUFS", "MUFs", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.contentHeight = 1300
    page.eyebrow = Controls:Label(page, "MICRO UNIT FRAMES", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "Familiar squares, cleaner controls", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "The MUFs keep their established appearance and movement behavior.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local basics = Controls:Card(page, "Frame behavior",
        "Secure frame structure changes are applied outside combat.")
    basics:SetPoint("TOPLEFT", 0, -82)
    basics:SetPoint("TOPRIGHT", -8, -82)
    basics:SetHeight(255)
    Controls:Toggle(basics, "Show MUFs", nil,
        function() return D.profile and D.profile.ShowDebuffsFrame end,
        function(value) setProfile("ShowDebuffsFrame", value) end)
    Controls:Toggle(basics, "Lock position", "Unlock to move the established MUF handle.",
        function() return D.profile and D.profile.HideMUFsHandle == true end,
        function(value) setProfile("HideMUFsHandle", value) end)
    Controls:Toggle(basics, "Status indicator light",
        "When disabled, the original tight Decursive spacing is restored.",
        function() return D.profile and D.profile.StatusLight121Enabled == true end,
        function(value) setProfile("StatusLight121Enabled", value) end)
    Controls:Toggle(basics, "MUF hover tooltip",
        "Blizzard renders aura details in dungeon and raid combat. PvP keeps the safe unit/help tooltip only.",
        function() return not D.profile or D.profile.AfflictionTooltips ~= false end,
        function(value) setProfile("AfflictionTooltips", value) end)

    local size = Controls:Card(page, "Size", "Party and Raid keep independent pixel sizes.")
    size:SetPoint("TOPLEFT", basics, "BOTTOMLEFT", 0, -12)
    size:SetPoint("TOPRIGHT", basics, "BOTTOMRIGHT", 0, -12)
    size:SetHeight(160)
    Controls:Stepper(size, "Party MUF size",
        function() return ZD:GetPartyMUFSizePixels() end,
        function(value) ZD:SetPartyMUFSizePixels(value) end, 10, 80, 1, "px")
    Controls:Stepper(size, "Raid MUF size",
        function() return ZD:GetRaidMUFSizePixels() end,
        function(value) ZD:SetRaidMUFSizePixels(value) end, 10, 80, 1, "px")

    local spacing = Controls:Card(page, "Spacing", "Each axis is independent unless linked.")
    spacing:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -12)
    spacing:SetPoint("TOPRIGHT", size, "BOTTOMRIGHT", 0, -12)
    spacing:SetHeight(205)
    Controls:Toggle(spacing, "Link horizontal and vertical spacing", nil,
        function() return D.profile and D.profile.DebuffsFrameTieSpacing == true end,
        function(value) setProfile("DebuffsFrameTieSpacing", value) end)
    Controls:Stepper(spacing, "Horizontal spacing",
        function() return D.profile and D.profile.DebuffsFrameXSpacing or 3 end,
        function(value)
            setProfile("DebuffsFrameXSpacing", value)
            if D.profile and D.profile.DebuffsFrameTieSpacing then
                setProfile("DebuffsFrameYSpacing", value)
            end
        end, 0, 40, 1, "px")
    Controls:Stepper(spacing, "Vertical spacing",
        function() return D.profile and D.profile.DebuffsFrameYSpacing or 3 end,
        function(value)
            setProfile("DebuffsFrameYSpacing", value)
            if D.profile and D.profile.DebuffsFrameTieSpacing then
                setProfile("DebuffsFrameXSpacing", value)
            end
        end, 0, 40, 1, "px")

    local layout = Controls:Card(page, "Grid layout",
        "These keep the original Decursive flow controls and compact raid behavior.")
    layout:SetPoint("TOPLEFT", spacing, "BOTTOMLEFT", 0, -12)
    layout:SetPoint("TOPRIGHT", spacing, "BOTTOMRIGHT", 0, -12)
    layout:SetHeight(345)
    Controls:Toggle(layout, "Grow upward", nil,
        function() return D.profile and D.profile.DebuffsFrameGrowToTop == true end,
        function(value) setProfile("DebuffsFrameGrowToTop", value) end)
    Controls:Toggle(layout, "Grow from right edge", nil,
        function() return D.profile and D.profile.DebuffsFrameStickToRight == true end,
        function(value) setProfile("DebuffsFrameStickToRight", value) end)
    Controls:Toggle(layout, "Fill columns before rows", nil,
        function() return D.profile and D.profile.DebuffsFrameVerticalDisplay == true end,
        function(value) setProfile("DebuffsFrameVerticalDisplay", value) end)
    Controls:Toggle(layout, "Automatic compact raid grid", "Large raids reflow to a maximum of five rows.",
        function() return D.profile and D.profile.DebuffsFrameRaidAutoLayout121 ~= false end,
        function(value) setProfile("DebuffsFrameRaidAutoLayout121", value) end)
    Controls:Stepper(layout, "Maximum MUFs",
        function() return D.profile and D.profile.DebuffsFrameMaxCount or 80 end,
        function(value) setProfile("DebuffsFrameMaxCount", value) end, 1, 82, 1, "")
    Controls:Stepper(layout, "Units per line",
        function() return D.profile and D.profile.DebuffsFramePerline or 10 end,
        function(value) setProfile("DebuffsFramePerline", value) end, 1, 40, 1, "")

    local appearance = Controls:Card(page, "Appearance",
        "Priority colors stay recognizable; these tune the inactive MUF surface.")
    appearance:SetPoint("TOPLEFT", layout, "BOTTOMLEFT", 0, -12)
    appearance:SetPoint("TOPRIGHT", layout, "BOTTOMRIGHT", 0, -12)
    appearance:SetHeight(160)
    Controls:Toggle(appearance, "Show MUF border", nil,
        function() return not D.profile or D.profile.DebuffsFrameElemBorderShow ~= false end,
        function(value) setProfile("DebuffsFrameElemBorderShow", value) end)
    Controls:Stepper(appearance, "Inactive opacity",
        function() return 1 - (D.profile and D.profile.DebuffsFrameElemAlpha or .35) end,
        function(value)
            setProfile("DebuffsFrameElemAlpha", 1 - value)
            if D.profile and D.profile.DebuffsFrameElemTieTransparency ~= false then
                D.profile.DebuffsFrameElemBorderAlpha = (1 - value) / 2
            end
            if D.MicroUnitF and D.MicroUnitF.Force_FullUpdate then D.MicroUnitF:Force_FullUpdate() end
        end, 0, 1, 0.05, "")

    function page:Refresh()
        basics:Refresh()
        size:Refresh()
        spacing:Refresh()
        layout:Refresh()
        appearance:Refresh()
    end
    return page
end)
