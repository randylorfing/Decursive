--[[
    This file is part of Decursive.

    Decursive_Options Test Mode / live MUF preview chrome. This file was
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

    Owns the settings-panel UI only. Secure MUFs and visual preview APIs
    remain resident in Decursive (Dcr_12_1 / Dcr_Raid Status.TestLayout).
--]]

local T = DecursiveRootTable
local D = T and T.Dcr
local DC = T and T._C
local ZD = T and T.ZhaohuModern
if not D or not DC or not ZD then return end

local C = {
    text = { .935, .960, .985, 1 },
    muted = { .535, .615, .715, 1 },
    accent = { .170, .785, .885, 1 },
    card = { .070, .090, .128, 1 },
    border = { .155, .195, .265, 1 },
    danger = { .955, .355, .405, 1 },
}

local function makeBackdrop(frame, color, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function label(parent, text, size, color, anchor, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", size and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetPoint(anchor or "TOPLEFT", x or 0, y or 0)
    fs:SetText(text or "")
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function button(parent, text, width, height, onClick, kind)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 140, height or 30)
    local color = kind == "danger" and C.danger or (kind == "primary" and C.accent or C.card)
    makeBackdrop(b, color, C.border)
    b.text = label(b, text, 12, C.text, "CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)
    return b
end

local function section(parent, title, y, height)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", 0, y)
    f:SetHeight(height)
    makeBackdrop(f, C.card, C.border)
    local wash = f:CreateTexture(nil, "BACKGROUND")
    wash:SetColorTexture(.09, .113, .155, .45)
    wash:SetPoint("TOPLEFT", 1, -1)
    wash:SetPoint("TOPRIGHT", -1, -1)
    wash:SetHeight(34)
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    f.title = label(f, title, 14, C.text, "TOPLEFT", 16, -14)
    return f
end

--- Options-owned Test Mode page. Drives resident preview/layout APIs only.
function ZD:BuildTestMode(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p:Hide()

    if ZD.PageTitle then
        ZD:PageTitle(p, "Test Lab", "Preview visual states and alert warnings without changing secure cure ownership.")
    else
        label(p, "Test Lab", 20, C.text, "TOPLEFT", 0, 0)
    end

    local visuals = section(p, "Status Light & Cooldown Preview", -82, 146)
    local vhelp = label(visuals, "Cycles cooldown overlays and status-light borders on visible MUFs for ~8 seconds.", 10, C.muted, "TOPLEFT", 18, -40)
    vhelp:SetWidth(600)

    local previewAll = button(visuals, "Preview All Visible MUFs", 200, 30, function()
        if InCombatLockdown and InCombatLockdown() then
            ZD:SetStatus("Test Mode is locked in combat.", true)
            return
        end
        if D.Test121MUFVisuals then
            D:Test121MUFVisuals("all")
            ZD:SetStatus("Previewing cooldown overlays on all visible MUFs.")
        end
    end, "primary")
    previewAll:SetPoint("TOPLEFT", 18, -68)

    local previewOne = button(visuals, "Preview Selected Square", 190, 30, function()
        if InCombatLockdown and InCombatLockdown() then
            ZD:SetStatus("Test Mode is locked in combat.", true)
            return
        end
        if D.Test121MUFVisuals then
            D:Test121MUFVisuals("one", D.Get121MUFTestIndex and D:Get121MUFTestIndex())
            ZD:SetStatus("Previewing the selected MUF square.")
        end
    end)
    previewOne:SetPoint("LEFT", previewAll, "RIGHT", 12, 0)

    local layout = section(p, "Layout Stress Test", -240, 176)
    local lhelp = label(layout, "Fills the MUF grid with placeholder slots so you can tune spacing and raid auto-layout without a full group.", 10, C.muted, "TOPLEFT", 18, -40)
    lhelp:SetWidth(600)

    local toggleLayout = button(layout, "Toggle Test Layout", 170, 30, function()
        if InCombatLockdown and InCombatLockdown() then
            ZD:SetStatus("Test layout cannot change in combat.", true)
            return
        end
        D.Status = D.Status or {}
        D.Status.TestLayout = not D.Status.TestLayout
        if D.Status.TestLayout and (not D.Status.TestLayoutUNum or D.Status.TestLayoutUNum < 1) then
            D.Status.TestLayoutUNum = 25
        end
        if D.GroupChanged then D:GroupChanged("TestMode") end
        ZD:SetStatus(D.Status.TestLayout and ("Test layout ON (" .. tostring(D.Status.TestLayoutUNum) .. " slots).") or "Test layout OFF.")
        if p.Refresh then p:Refresh() end
    end, "primary")
    toggleLayout:SetPoint("TOPLEFT", 18, -68)

    local minus = button(layout, "−5 slots", 90, 30, function()
        if InCombatLockdown and InCombatLockdown() then return end
        D.Status = D.Status or {}
        D.Status.TestLayoutUNum = math.max(5, (tonumber(D.Status.TestLayoutUNum) or 25) - 5)
        if D.Status.TestLayout and D.GroupChanged then D:GroupChanged("TestMode") end
        if p.Refresh then p:Refresh() end
    end)
    minus:SetPoint("LEFT", toggleLayout, "RIGHT", 12, 0)

    local plus = button(layout, "+5 slots", 90, 30, function()
        if InCombatLockdown and InCombatLockdown() then return end
        D.Status = D.Status or {}
        local maxSlots = (MAX_RAID_MEMBERS or 40)
        D.Status.TestLayoutUNum = math.min(maxSlots, (tonumber(D.Status.TestLayoutUNum) or 25) + 5)
        if D.Status.TestLayout and D.GroupChanged then D:GroupChanged("TestMode") end
        if p.Refresh then p:Refresh() end
    end)
    plus:SetPoint("LEFT", minus, "RIGHT", 8, 0)

    p.layoutStatus = label(layout, "", 12, C.accent, "TOPLEFT", 18, -112)
    p.hint = label(layout, "Tip: open Micro Unit Frames while Test Layout is on to adjust size, spacing and opacity live.", 10, C.muted, "TOPLEFT", 18, -140)
    p.hint:SetWidth(600)

    local soul = section(p, "Alert Warning Previews", -428, 96)
    local soulBtn = button(soul, "Preview Soul Link Alert", 200, 30, function()
        if D.Test121SoulLinkAlert then
            D:Test121SoulLinkAlert()
            ZD:SetStatus("Soul Link alert preview triggered.")
        else
            ZD:SetStatus("Soul Link preview is unavailable on this client.", true)
        end
    end)
    soulBtn:SetPoint("TOPLEFT", 18, -43)

    local dispelBtn = button(soul, "Preview DISPEL Alert", 200, 30, function()
        local shown = D.Test121DispelAlertWarning and D:Test121DispelAlertWarning()
        if shown then
            local duration = D.Get121DispelAlertDuration and D:Get121DispelAlertDuration() or 2
            ZD:SetStatus(("DISPEL alert preview shown for %.1f seconds."):format(duration))
        else
            ZD:SetStatus("DISPEL alert preview is unavailable on this client.", true)
        end
    end, "primary")
    dispelBtn:SetPoint("LEFT", soulBtn, "RIGHT", 12, 0)

    local previewHint = label(soul, "Previews ignore the live toggle and debounce, but use your current text style and duration.", 9, C.muted, "BOTTOMLEFT", 18, 8)
    previewHint:SetPoint("RIGHT", -18, 0)

    function p:Refresh()
        D.Status = D.Status or {}
        local on = D.Status.TestLayout and true or false
        local n = tonumber(D.Status.TestLayoutUNum) or 25
        p.layoutStatus:SetText(on and ("Test layout active — " .. n .. " placeholder slots") or "Test layout inactive — using live roster")
    end
    p:Refresh()
    return p
end

-- Public ownership helpers (DF-style stubs that Options can extend).
ZD.TestMode = ZD.TestMode or {}
function ZD.TestMode:IsActive()
    return (D.Status and D.Status.TestLayout) and true or false
end
function ZD.TestMode:ToggleLayout()
    if InCombatLockdown and InCombatLockdown() then return false end
    D.Status = D.Status or {}
    D.Status.TestLayout = not D.Status.TestLayout
    if D.GroupChanged then D:GroupChanged("TestMode") end
    return D.Status.TestLayout
end
