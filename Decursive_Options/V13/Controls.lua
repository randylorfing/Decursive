--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 settings controls.
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
V13.Options = UI

local Controls = {}
UI.Controls = Controls

local function isControlEnabled(enabledGetter)
    if type(enabledGetter) ~= "function" then return true end
    local ok, enabled = pcall(enabledGetter)
    return ok and enabled ~= false
end

local function setInteractiveState(row, enabled)
    row.controlEnabled = enabled == true
    if row.SetEnabled then row:SetEnabled(row.controlEnabled) end
    row:SetAlpha(row.controlEnabled and 1 or 0.5)
end

-- Run a setting mutation through one shared boundary.  Earlier controls
-- refreshed themselves even when a setter raised an error or returned false,
-- which made a rejected change look like an inert button.  Preserve any more
-- specific status emitted by the backend and otherwise give immediate footer
-- feedback for both success and failure.
function Controls:Apply(labelText, setter, value)
    if type(setter) ~= "function" then
        if UI.SetStatus then UI:SetStatus((labelText or "Setting") .. " is unavailable.", "error") end
        return false
    end

    local previousStatus = UI.statusText
    local ok, result = pcall(setter, value)
    if not ok then
        if UI.SetStatus then
            UI:SetStatus("Could not change " .. tostring(labelText or "setting") .. ": " .. tostring(result), "error")
        end
        return false
    end

    if result == false then
        if UI.SetStatus and (UI.statusText == previousStatus or UI.statusKind ~= "error") then
            UI:SetStatus(tostring(labelText or "Setting") .. " could not be applied.", "error")
        end
        return false
    end

    if UI.SetStatus and UI.statusText == previousStatus then
        UI:SetStatus(tostring(labelText or "Setting") .. " updated.", "success")
    end
    return true
end

local function rgba(color, alpha)
    color = color or Theme.color.text
    return color[1], color[2], color[3], alpha or color[4] or 1
end

function Controls:SetBackdrop(frame, background, border)
    frame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    frame:SetBackdropColor(rgba(background or Theme.color.surface))
    frame:SetBackdropBorderColor(rgba(border or Theme.color.border))
end

function Controls:Label(parent, text, size, color)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    local font = select(1, GameFontNormal:GetFont())
    label:SetFont(font, size or 12, "")
    label:SetText(text or "")
    label:SetTextColor(rgba(color or Theme.color.text))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

function Controls:Button(parent, text, width, onClick, style)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, Theme.size.controlHeight)
    button:RegisterForClicks("LeftButtonUp")
    self:SetBackdrop(button,
        style == "primary" and Theme.color.cyan or Theme.color.raised,
        style == "danger" and Theme.color.danger or Theme.color.border)

    -- Primary buttons keep white text in every interaction state. The first
    -- preview used the dark canvas token here, which made selected cyan
    -- actions look as though their labels had turned black.
    button.text = self:Label(button, text, 11, Theme.color.text)
    button.text:SetPoint("CENTER")

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(rgba(style == "danger" and Theme.color.danger or Theme.color.cyan))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(rgba(style == "danger" and Theme.color.danger or Theme.color.border))
    end)
    button:SetScript("OnClick", function()
        if onClick then onClick(button) end
    end)
    return button
end

function Controls:ConfirmButton(parent, text, width, onConfirm)
    local button
    button = self:Button(parent, text, width, function()
        if button.confirmArmed then
            button.confirmArmed = false
            button.confirmGeneration = (button.confirmGeneration or 0) + 1
            button.text:SetText(text)
            if onConfirm then onConfirm(button) end
            return
        end

        button.confirmArmed = true
        button.confirmGeneration = (button.confirmGeneration or 0) + 1
        local generation = button.confirmGeneration
        button.text:SetText("Click again to confirm")
        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                if button.confirmGeneration ~= generation then return end
                button.confirmArmed = false
                button.text:SetText(text)
            end)
        end
    end, "danger")
    return button
end

function Controls:Pill(parent, text, color)
    local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pill:SetHeight(24)
    self:SetBackdrop(pill, Theme.color.raised, color or Theme.color.border)
    pill.text = self:Label(pill, text, 10, color or Theme.color.text)
    pill.text:SetPoint("LEFT", 10, 0)
    pill.text:SetPoint("RIGHT", -10, 0)
    return pill
end

function Controls:Card(parent, title, description)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self:SetBackdrop(card, Theme.color.surface, Theme.color.border)
    card.title = self:Label(card, title, 14, Theme.color.text)
    card.title:SetPoint("TOPLEFT", Theme.spacing.card, -Theme.spacing.card)
    card.title:SetPoint("RIGHT", -Theme.spacing.card, 0)
    if description and description ~= "" then
        card.description = self:Label(card, description, 10, Theme.color.muted)
        card.description:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -5)
        card.description:SetPoint("RIGHT", -Theme.spacing.card, 0)
        card.description:SetWordWrap(true)
    end
    card.nextY = description and -62 or -46
    card.refreshers = {}

    function card:AddRefresher(callback)
        self.refreshers[#self.refreshers + 1] = callback
    end

    function card:Refresh()
        for _, callback in ipairs(self.refreshers) do callback() end
    end
    return card
end

function Controls:Toggle(card, labelText, description, getter, setter, enabledGetter)
    local row = CreateFrame("Button", nil, card)
    row:RegisterForClicks("LeftButtonUp")
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(description and 50 or 36)
    card.nextY = card.nextY - row:GetHeight() - Theme.spacing.compact

    row.label = self:Label(row, labelText, 11, Theme.color.text)
    row.label:SetPoint("TOPLEFT", 0, -2)
    row.label:SetPoint("RIGHT", -64, 0)
    if description then
        row.description = self:Label(row, description, 9, Theme.color.muted)
        row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.description:SetPoint("RIGHT", -64, 0)
        row.description:SetWordWrap(true)
    end

    row.track = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.track:SetSize(42, 20)
    row.track:SetPoint("RIGHT", 0, 0)
    self:SetBackdrop(row.track, Theme.color.raised, Theme.color.border)
    row.knob = row.track:CreateTexture(nil, "ARTWORK")
    row.knob:SetSize(14, 14)

    function row:Refresh()
        local enabled = getter and getter() and true or false
        setInteractiveState(self, isControlEnabled(enabledGetter))
        if enabled then
            self.track:SetBackdropColor(rgba(Theme.color.cyan))
            self.knob:SetColorTexture(rgba(Theme.color.text))
            self.knob:ClearAllPoints()
            self.knob:SetPoint("RIGHT", -3, 0)
        else
            self.track:SetBackdropColor(rgba(Theme.color.raised))
            self.knob:SetColorTexture(rgba(Theme.color.muted))
            self.knob:ClearAllPoints()
            self.knob:SetPoint("LEFT", 3, 0)
        end
    end

    row:SetScript("OnClick", function(self)
        if self.controlEnabled == false then return end
        Controls:Apply(labelText, setter, not (getter and getter()))
        card:Refresh()
    end)
    card:AddRefresher(function() row:Refresh() end)
    row:Refresh()
    return row
end

function Controls:Stepper(card, labelText, getter, setter, minimum, maximum, step, unit, enabledGetter)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(38)
    card.nextY = card.nextY - row:GetHeight() - Theme.spacing.compact

    row.label = self:Label(row, labelText, 11, Theme.color.text)
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetPoint("RIGHT", -166, 0)

    local function change(delta)
        if enabledGetter and enabledGetter() == false then return end
        local value = tonumber(getter and getter()) or minimum or 0
        value = value + delta
        if minimum then value = math.max(minimum, value) end
        if maximum then value = math.min(maximum, value) end
        Controls:Apply(labelText, setter, value)
        card:Refresh()
    end

    row.minus = self:Button(row, "-", 28, function() change(-(step or 1)) end)
    row.minus:SetPoint("RIGHT", -126, 0)
    row.value = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.value:SetSize(92, Theme.size.controlHeight)
    row.value:SetPoint("LEFT", row.minus, "RIGHT", 4, 0)
    self:SetBackdrop(row.value, Theme.color.canvas, Theme.color.border)
    row.value.text = self:Label(row.value, "", 11, Theme.color.text)
    row.value.text:SetPoint("CENTER")
    row.plus = self:Button(row, "+", 28, function() change(step or 1) end)
    row.plus:SetPoint("LEFT", row.value, "RIGHT", 4, 0)

    function row:Refresh()
        local enabled = not enabledGetter or enabledGetter() ~= false
        local value = tonumber(getter and getter()) or 0
        local display
        if (step or 1) < 1 then
            display = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
        else
            display = tostring(math.floor(value + 0.5))
        end
        self.value.text:SetText(display .. (unit and (" " .. unit) or ""))
        if self.minus.SetEnabled then self.minus:SetEnabled(enabled) end
        if self.plus.SetEnabled then self.plus:SetEnabled(enabled) end
        self:SetAlpha(enabled and 1 or 0.5)
    end
    card:AddRefresher(function() row:Refresh() end)
    row:Refresh()
    return row
end

function Controls:Cycle(card, labelText, valuesGetter, getter, setter, enabledGetter)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(38)
    card.nextY = card.nextY - row:GetHeight() - Theme.spacing.compact

    row.label = self:Label(row, labelText, 11, Theme.color.text)
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetPoint("RIGHT", -206, 0)
    row.button = self:Button(row, "", 198, function()
        if row.controlEnabled == false then return end
        local values = valuesGetter and valuesGetter() or {}
        if #values == 0 then return end
        local current = getter and getter()
        local index = 0
        for i, option in ipairs(values) do
            if option.key == current then index = i break end
        end
        index = (index % #values) + 1
        Controls:Apply(labelText, setter, values[index].key)
        card:Refresh()
    end)
    row.button:SetPoint("RIGHT", 0, 0)

    function row:Refresh()
        setInteractiveState(self, isControlEnabled(enabledGetter))
        local values = valuesGetter and valuesGetter() or {}
        local current = getter and getter()
        local display = tostring(current or "Select")
        for _, option in ipairs(values) do
            if option.key == current then display = option.label or option.key break end
        end
        self.button.text:SetText(display .. "  >")
    end
    card:AddRefresher(function() row:Refresh() end)
    row:Refresh()
    return row
end

function Controls:StatusRow(card, labelText, valueGetter, colorGetter)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(28)
    card.nextY = card.nextY - 34
    row.label = self:Label(row, labelText, 10, Theme.color.muted)
    row.label:SetPoint("LEFT", 0, 0)
    row.value = self:Label(row, "", 10, Theme.color.text)
    row.value:SetPoint("RIGHT", 0, 0)
    row.value:SetJustifyH("RIGHT")
    function row:Refresh()
        row.value:SetText(tostring(valueGetter and valueGetter() or "—"))
        row.value:SetTextColor(rgba(colorGetter and colorGetter() or Theme.color.text))
    end
    card:AddRefresher(function() row:Refresh() end)
    row:Refresh()
    return row
end

function Controls:TextInput(card, labelText, placeholder)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(60)
    card.nextY = card.nextY - row:GetHeight() - Theme.spacing.compact

    row.label = self:Label(row, labelText, 10, Theme.color.muted)
    row.label:SetPoint("TOPLEFT", 0, 0)

    row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.box:SetPoint("TOPLEFT", 0, -20)
    row.box:SetPoint("BOTTOMRIGHT", 0, 0)
    self:SetBackdrop(row.box, Theme.color.canvas, Theme.color.border)

    row.edit = CreateFrame("EditBox", nil, row.box)
    row.edit:SetPoint("TOPLEFT", 10, -2)
    row.edit:SetPoint("BOTTOMRIGHT", -10, 2)
    row.edit:SetAutoFocus(false)
    row.edit:SetFontObject(GameFontHighlight)
    row.edit:SetTextInsets(0, 0, 0, 0)
    row.edit:SetMaxLetters(64)
    row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    row.placeholder = self:Label(row.box, placeholder or "", 10, Theme.color.muted)
    row.placeholder:SetPoint("LEFT", 10, 0)
    row.edit:SetScript("OnTextChanged", function(self)
        row.placeholder:SetShown((self:GetText() or "") == "" and not self:HasFocus())
    end)
    row.edit:SetScript("OnEditFocusGained", function() row.placeholder:Hide() end)
    row.edit:SetScript("OnEditFocusLost", function(self)
        row.placeholder:SetShown((self:GetText() or "") == "")
    end)
    return row
end

function Controls:TextArea(card, labelText, height)
    height = math.max(100, tonumber(height) or 150)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", Theme.spacing.card, card.nextY)
    row:SetPoint("RIGHT", -Theme.spacing.card, 0)
    row:SetHeight(height + 20)
    card.nextY = card.nextY - row:GetHeight() - Theme.spacing.compact

    row.label = self:Label(row, labelText, 10, Theme.color.muted)
    row.label:SetPoint("TOPLEFT", 0, 0)

    row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.box:SetPoint("TOPLEFT", 0, -20)
    row.box:SetPoint("BOTTOMRIGHT", 0, 0)
    self:SetBackdrop(row.box, Theme.color.canvas, Theme.color.border)

    row.scroll = CreateFrame("ScrollFrame", nil, row.box, "UIPanelScrollFrameTemplate")
    row.scroll:SetPoint("TOPLEFT", 8, -7)
    row.scroll:SetPoint("BOTTOMRIGHT", -28, 7)
    row.edit = CreateFrame("EditBox", nil, row.scroll)
    row.edit:SetMultiLine(true)
    row.edit:SetAutoFocus(false)
    row.edit:SetFontObject(GameFontHighlightSmall)
    row.edit:SetWidth(420)
    row.edit:SetHeight(900)
    row.edit:SetTextInsets(2, 2, 2, 2)
    row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.scroll:SetScrollChild(row.edit)
    row.scroll:SetScript("OnSizeChanged", function(self, width, scrollHeight)
        row.edit:SetWidth(math.max(120, width - 4))
        row.edit:SetHeight(math.max(900, scrollHeight))
        self:UpdateScrollChildRect()
    end)
    row.edit:SetScript("OnTextChanged", function()
        row.scroll:UpdateScrollChildRect()
    end)
    row.edit:SetScript("OnCursorChanged", function(_, _, cursorY, _, cursorHeight)
        local scrollTop = row.scroll:GetVerticalScroll()
        local scrollHeight = row.scroll:GetHeight()
        if -cursorY < scrollTop then
            row.scroll:SetVerticalScroll(math.max(0, -cursorY))
        elseif -cursorY + cursorHeight > scrollTop + scrollHeight then
            row.scroll:SetVerticalScroll(-cursorY + cursorHeight - scrollHeight)
        end
    end)
    return row
end
