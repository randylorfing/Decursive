--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Cure page.. This file was solely written by Randy Lorfing.
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
local DC = T._C

local cureTypes = {
    { key = "MAGIC", label = "Magic" },
    { key = "POISON", label = "Poison" },
    { key = "DISEASE", label = "Disease" },
    { key = "CURSE", label = "Curse" },
    { key = "CHARMED", label = "Charm / mind control" },
    { key = "BLEED", label = "Bleed rules" },
}

UI:RegisterPage("CURE", "Cure", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.eyebrow = Controls:Label(page, "CURE ENGINE", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "What your current specialization can clean", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "Priorities remain specialization-aware and secure clicks are rebuilt outside combat.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local priorities = Controls:Card(page, "Affliction priorities",
        "Enabled types are ordered by the established Decursive cure engine.")
    priorities:SetPoint("TOPLEFT", 0, -82)
    priorities:SetPoint("TOPRIGHT", -8, -82)
    priorities:SetHeight(390)

    for _, cureType in ipairs(cureTypes) do
        local typeID = DC and DC[cureType.key]
        if typeID then
            local capturedTypeID = typeID
            local labelText = cureType.label
            Controls:Toggle(priorities, labelText, nil,
                function() return ZD.GetCureEnabled and ZD:GetCureEnabled(capturedTypeID) end,
                function()
                    if ZD.ToggleCure then ZD:ToggleCure(capturedTypeID) end
                    UI:SetStatus(labelText .. " priority updated.", "success")
                end)
        end
    end

    local bindings = Controls:Card(page, "Secure click bindings",
        "Left, right, middle, Button4/Button5 and modifier bindings remain supported. The full binding editor is the next cure-page migration step.")
    bindings:SetPoint("TOPLEFT", priorities, "BOTTOMLEFT", 0, -12)
    bindings:SetPoint("TOPRIGHT", priorities, "BOTTOMRIGHT", 0, -12)
    bindings:SetHeight(140)
    local state = Controls:Pill(bindings, "CURRENT BINDINGS REMAIN ACTIVE", Theme.color.success)
    state:SetWidth(220)
    state:SetPoint("BOTTOMLEFT", 16, 16)

    function page:Refresh()
        priorities:Refresh()
    end
    return page
end)
