--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Advanced page.. This file was solely written by Randy Lorfing.
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
local RuntimeStatus = V13:GetModule("RuntimeStatus")

UI:RegisterPage("ADVANCED", "Advanced", function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.contentHeight = 1080
    page.eyebrow = Controls:Label(page, "ADVANCED", 9, Theme.color.cyan)
    page.eyebrow:SetPoint("TOPLEFT", 0, -2)
    page.title = Controls:Label(page, "Diagnostics without protected-data risk", 20, Theme.color.text)
    page.title:SetPoint("TOPLEFT", page.eyebrow, "BOTTOMLEFT", 0, -6)
    page.subtitle = Controls:Label(page,
        "Lifecycle, registration and build health only—never protected aura contents.",
        10, Theme.color.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)

    local runtime = Controls:Card(page, "Runtime health",
        "The v13 command center uses the hardened secure-MUF runtime and Blizzard-managed 12.1 aura providers.")
    runtime:SetPoint("TOPLEFT", 0, -82)
    runtime:SetPoint("TOPRIGHT", -8, -82)
    runtime:SetHeight(300)
    Controls:StatusRow(runtime, "Release phase", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.phase or "release-candidate"
    end, function() return Theme.color.cyan end)
    Controls:StatusRow(runtime, "Combat backend", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.backend or "v13-hardened-compat-runtime"
    end)
    Controls:StatusRow(runtime, "Runtime mode", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.runtimeMode or "Hardened compatibility"
    end, function() return Theme.color.success end)
    Controls:StatusRow(runtime, "Detection provider", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.provider or "Native Blizzard-managed"
    end, function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.providerOperational == false and Theme.color.danger or Theme.color.success
    end)
    Controls:StatusRow(runtime, "Protected-aura boundary", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return state.protectedBoundary or "Blizzard-managed"
    end)
    Controls:StatusRow(runtime, "Deferred structural work", function()
        local state = RuntimeStatus and RuntimeStatus:GetSnapshot() or {}
        return tostring(state.deferred or 0)
    end)

    local tools = Controls:Card(page, "Safe tools",
        "Diagnostics print public configuration and lifecycle state to chat.")
    tools:SetPoint("TOPLEFT", runtime, "BOTTOMLEFT", 0, -12)
    tools:SetPoint("TOPRIGHT", runtime, "BOTTOMRIGHT", 0, -12)
    tools:SetHeight(175)
    local selfTest = Controls:Button(tools, "Run Self-Diagnostic", 175, function()
        if T._SelfDiagnostic then
            T._SelfDiagnostic(true, true)
            UI:SetStatus("Self-diagnostic sent to chat.", "success")
        else
            UI:SetStatus("Self-diagnostic is unavailable.", "error")
        end
    end, "primary")
    selfTest:SetPoint("TOPLEFT", 16, -68)
    local status = Controls:Button(tools, "Print 12.1 Status", 160, function()
        if D.Get121CompatibilityStatusText and D.Println then
            D:Println(D:Get121CompatibilityStatusText())
            UI:SetStatus("12.1 status sent to chat.", "success")
        end
    end)
    status:SetPoint("LEFT", selfTest, "RIGHT", 8, 0)
    local reload = Controls:ConfirmButton(tools, "Reload UI", 120, function()
        if ReloadUI then ReloadUI() end
    end)
    reload:SetPoint("LEFT", status, "RIGHT", 8, 0)

    local report = Controls:Card(page, "Copyable v13 report",
        "This report intentionally excludes aura names, durations, stacks and visibility state.")
    report:SetPoint("TOPLEFT", tools, "BOTTOMLEFT", 0, -12)
    report:SetPoint("TOPRIGHT", tools, "BOTTOMRIGHT", 0, -12)
    report:SetHeight(310)
    local reportText = Controls:TextArea(report, "Runtime report", 150)
    local refreshReport = Controls:Button(report, "Refresh & Select", 160, function()
        reportText.edit:SetText(RuntimeStatus and RuntimeStatus:GetReport() or "Runtime status unavailable.")
        reportText.edit:HighlightText()
        reportText.edit:SetFocus()
        UI:SetStatus("Safe runtime report selected. Press Ctrl+C to copy.", "success")
    end, "primary")
    refreshReport:SetPoint("BOTTOMLEFT", 16, 16)

    local boundary = Controls:Card(page, "12.1 guardrails",
        "Blizzard owns protected aura state. v13 only records public lifecycle and registration health; unknown secret auras remain visual-only.")
    boundary:SetPoint("TOPLEFT", report, "BOTTOMLEFT", 0, -12)
    boundary:SetPoint("TOPRIGHT", report, "BOTTOMRIGHT", 0, -12)
    boundary:SetHeight(150)
    local safe = Controls:Pill(boundary, "PROTECTED-AURA BOUNDARY ENFORCED", Theme.color.success)
    safe:SetWidth(270)
    safe:SetPoint("BOTTOMLEFT", 16, 16)

    function page:Refresh()
        runtime:Refresh()
        if reportText.edit:GetText() == "" then
            reportText.edit:SetText(RuntimeStatus and RuntimeStatus:GetReport() or "Runtime status unavailable.")
        end
    end
    return page
end)
