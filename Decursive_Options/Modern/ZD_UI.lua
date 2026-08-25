--[[
    This file is part of Decursive.

    Zhaohu's Decursive v11 modern configuration UI. This file was solely
    written by Randy Lorfing.
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
-- Zhaohu's Decursive v11 modern configuration UI (LoadOnDemand companion).
-- Companion `...` is NOT Decursive's private table; use DecursiveRootTable.
local T = DecursiveRootTable
local D = T and T.Dcr
local DC = T and T._C
local ZD = T and T.ZhaohuModern
if not D or not DC or not ZD then return end

local abs = math.abs
local floor = math.floor
local format = string.format
local unpack = unpack

-- v12 Options skin — charcoal chrome with Decursive teal.
-- Intentionally different from the old teal-on-slate v11 card panel.
local C = {
    bg = { .08, .08, .08, .96 },
    panel = { .12, .12, .12, 1 },
    card = { .16, .16, .16, 1 },
    element = { .18, .18, .18, 1 },
    hover = { .22, .22, .22, 1 },
    border = { .25, .25, .25, 1 },
    text = { .90, .90, .90, 1 },
    muted = { .58, .58, .58, 1 },
    accent = { .18, .82, .72, 1 },       -- Decursive teal
    accentDim = { .10, .42, .38, 1 },
    accent2 = { .95, .55, .22, 1 },      -- warm secondary (raid-adjacent cue)
    danger = { .95, .35, .35, 1 },
    off = { .28, .28, .28, 1 },
    navActive = { .14, .14, .14, 1 },
    titleBar = { .10, .10, .10, 1 },
    selected = { .12, .28, .26, 1 },
}

local function setColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

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
    b:SetSize(width or 140, height or 26)
    local fill = C.element
    local textColor = C.text
    if kind == "danger" then
        fill = C.danger
        textColor = { 1, 1, 1, 1 }
    elseif kind == "primary" then
        fill = C.accent
        textColor = { .06, .10, .10, 1 }
    end
    makeBackdrop(b, fill, C.border)
    b.text = label(b, text, 11, textColor, "CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        if kind == "primary" then
            self:SetBackdropColor(C.accent[1] * 1.08, C.accent[2] * 1.08, C.accent[3] * 1.08, 1)
        elseif kind == "danger" then
            self:SetBackdropBorderColor(1, 1, 1, .35)
        else
            self:SetBackdropColor(C.hover[1], C.hover[2], C.hover[3], 1)
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)
    b.SetLabel = function(self, value) self.text:SetText(value or "") end
    return b
end

local function section(parent, title, y, height)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", 0, y)
    f:SetHeight(height)
    makeBackdrop(f, C.card, C.border)
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    f.title = label(f, title, 13, C.text, "TOPLEFT", 16, -12)
    return f
end

local function switch(parent, text, y, getter, setter, description)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", -16, y)
    row:SetHeight(description and 48 or 32)

    row.title = label(row, text, 12, C.text, "TOPLEFT", 0, -2)
    if description then
        row.desc = label(row, description, 10, C.muted, "TOPLEFT", 0, -20)
        row.desc:SetPoint("RIGHT", -64, 0)
        row.desc:SetJustifyH("LEFT")
    end

    local sw = CreateFrame("Button", nil, row, "BackdropTemplate")
    sw:SetSize(40, 18)
    sw:SetPoint("TOPRIGHT", 0, -2)
    makeBackdrop(sw, C.off, C.border)
    sw.knob = sw:CreateTexture(nil, "OVERLAY")
    sw.knob:SetSize(14, 14)
    sw.knob:SetColorTexture(.96, .97, .99, 1)

    function sw:Refresh()
        local on = getter and getter() and true or false
        if on then
            self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("RIGHT", -2, 0)
        else
            self:SetBackdropColor(C.off[1], C.off[2], C.off[3], 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("LEFT", 2, 0)
        end
        self.on = on
    end

    sw:SetScript("OnClick", function(self)
        if not ZD:CanConfigure() then return end
        if setter then setter(not (getter and getter())) end
        self:Refresh()
        ZD:RefreshUI()
    end)
    sw:Refresh()
    row.control = sw
    return row
end

local function snapRangeValue(value, minValue, maxValue, step)
    value = tonumber(value) or minValue
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    step = tonumber(step) or 1
    if step > 0 then
        value = minValue + floor(((value - minValue) / step) + .5) * step
    end
    -- Trim floating-point noise without throwing away legitimate fine steps.
    return tonumber(format("%.6f", value)) or value
end

local function formatRangeValue(value, isPercent, suffix)
    local shown = isPercent and ((tonumber(value) or 0) * 100) or (tonumber(value) or 0)
    local text = format("%g", tonumber(format("%.4f", shown)) or shown)
    if isPercent then return text .. "%" end
    return text .. (suffix or "")
end

local function parseRangeValue(text, isPercent)
    text = tostring(text or ""):gsub("%%", ""):gsub(",", ".")
    local value = tonumber(text)
    if value == nil then return nil end
    if isPercent then value = value / 100 end
    return value
end

-- Add an exact-value spinner to a Slider.  The same control also gives every
-- v11 slider mouse-wheel stepping.  WoW sliders created without a template do
-- not reliably inherit an orientation, so this helper explicitly forces
-- HORIZONTAL; that fixes the centered/non-draggable thumb seen in alpha.11.
local function addRangeStepper(row, track, minValue, maxValue, step, isPercent, suffix, isDisabled)
    track:SetOrientation("HORIZONTAL")
    track:EnableMouse(true)
    track:EnableMouseWheel(true)

    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(126, 24)
    holder:SetPoint("TOPRIGHT", 0, -1)

    local minus = button(holder, "-", 24, 24, nil)
    minus:SetPoint("LEFT", 0, 0)

    local edit = CreateFrame("EditBox", nil, holder, "BackdropTemplate")
    edit:SetSize(72, 24)
    edit:SetPoint("LEFT", minus, "RIGHT", 3, 0)
    makeBackdrop(edit, C.bg, C.border)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetJustifyH("CENTER")
    edit:EnableMouseWheel(true)

    local plus = button(holder, "+", 24, 24, nil)
    plus:SetPoint("LEFT", edit, "RIGHT", 3, 0)

    local function blocked()
        if isDisabled and isDisabled() then return true end
        return not ZD:CanConfigure(true)
    end

    local function refresh(value)
        edit._refreshing = true
        edit:SetText(formatRangeValue(snapRangeValue(value, minValue, maxValue, step), isPercent, suffix))
        edit:HighlightText(0, 0)
        edit._refreshing = false
    end

    local function setValue(value)
        if blocked() then
            refresh(track:GetValue())
            return
        end
        track:SetValue(snapRangeValue(value, minValue, maxValue, step))
    end

    local function stepValue(direction)
        setValue((tonumber(track:GetValue()) or minValue) + (step * direction))
    end

    minus:SetScript("OnClick", function() stepValue(-1) end)
    plus:SetScript("OnClick", function() stepValue(1) end)
    track:SetScript("OnMouseWheel", function(_, delta) stepValue(delta > 0 and 1 or -1) end)
    edit:SetScript("OnMouseWheel", function(_, delta) stepValue(delta > 0 and 1 or -1) end)
    edit:SetScript("OnEnterPressed", function(self)
        local value = parseRangeValue(self:GetText(), isPercent)
        if value ~= nil then setValue(value) else refresh(track:GetValue()) end
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        refresh(track:GetValue())
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnEditFocusLost", function(self)
        if self._refreshing then return end
        local value = parseRangeValue(self:GetText(), isPercent)
        if value ~= nil then setValue(value) else refresh(track:GetValue()) end
    end)

    function holder:Refresh(value)
        refresh(value)
    end
    holder.edit = edit
    holder.minus = minus
    holder.plus = plus
    return holder
end

local function slider(parent, text, y, minValue, maxValue, step, getter, setter, suffix, isPercent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", -16, y)
    row:SetHeight(56)
    row.title = label(row, text, 12, C.text, "TOPLEFT", 0, 0)

    local track = CreateFrame("Slider", nil, row)
    track:SetPoint("TOPLEFT", 0, -30)
    track:SetPoint("TOPRIGHT", 0, -30)
    track:SetHeight(18)
    track:SetOrientation("HORIZONTAL")
    track:SetMinMaxValues(minValue, maxValue)
    track:SetValueStep(step)
    if track.SetObeyStepOnDrag then track:SetObeyStepOnDrag(true) end

    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetPoint("LEFT", 0, 0)
    track.bg:SetPoint("RIGHT", 0, 0)
    track.bg:SetHeight(4)
    setColor(track.bg, C.off)

    track.fill = track:CreateTexture(nil, "ARTWORK")
    track.fill:SetPoint("LEFT", 0, 0)
    track.fill:SetHeight(4)
    setColor(track.fill, C.accent)

    track:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = track:GetThumbTexture()
    if thumb then thumb:SetSize(18, 18) end

    local stepper = addRangeStepper(row, track, minValue, maxValue, step, isPercent == true, suffix, function() return false end)
    row.title:SetPoint("RIGHT", stepper, "LEFT", -10, 0)
    row.title:SetJustifyH("LEFT")

    local function display(v)
        v = snapRangeValue(v, minValue, maxValue, step)
        stepper:Refresh(v)
        local width = track:GetWidth()
        if width and width > 0 and maxValue > minValue then
            local p = (v - minValue) / (maxValue - minValue)
            track.fill:SetWidth(math.max(1, width * p))
        end
    end

    function track:Refresh()
        local v = snapRangeValue(getter and getter() or minValue, minValue, maxValue, step)
        self._refreshing = true
        self:SetValue(v)
        self._refreshing = false
        display(v)
    end

    track:SetScript("OnValueChanged", function(self, value)
        local rounded = snapRangeValue(value, minValue, maxValue, step)
        display(rounded)
        if not self._refreshing and ZD:CanConfigure(true) and setter then
            setter(rounded)
            ZD:SetStatus(text .. " updated.")
        end
    end)
    track:SetScript("OnSizeChanged", function(self) display(self:GetValue()) end)
    track:Refresh()
    row.control = track
    row.stepper = stepper
    return row
end


local function colorPickerRow(parent, text, y, getter, setter, description)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", -16, y)
    row:SetHeight(description and 52 or 36)
    row.title = label(row, text, 12, C.text, "TOPLEFT", 0, -2)
    if description then
        row.desc = label(row, description, 10, C.muted, "TOPLEFT", 0, -22)
        row.desc:SetPoint("RIGHT", -130, 0)
        row.desc:SetJustifyH("LEFT")
    end
    local sw = button(row, "Color", 112, 28, nil)
    sw:SetPoint("TOPRIGHT", 0, -2)
    sw.sample = sw:CreateTexture(nil, "ARTWORK")
    sw.sample:SetSize(18, 18); sw.sample:SetPoint("LEFT", 7, 0)
    sw.text:ClearAllPoints(); sw.text:SetPoint("LEFT", 32, 0)
    local function read()
        local c = getter and getter() or {1,1,1}
        if type(c) ~= "table" then c = {1,1,1} end
        return c[1] or 1, c[2] or 1, c[3] or 1
    end
    function row:Refresh()
        local r,g,b = read(); sw.sample:SetColorTexture(r,g,b,1)
    end
    sw:SetScript("OnClick", function()
        if not ZD:CanConfigure() then return end
        local r,g,b = read()
        local picker = { r=r, g=g, b=b, hasOpacity=false }
        local function commit()
            local nr,ng,nb = ColorPickerFrame:GetColorRGB()
            if setter then setter({nr,ng,nb}) end
            sw.sample:SetColorTexture(nr,ng,nb,1)
        end
        picker.swatchFunc=commit
        picker.cancelFunc=function(previous)
            if type(previous)=="table" and setter then
                setter({previous.r or r, previous.g or g, previous.b or b})
                row:Refresh()
            end
        end
        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(picker) else ColorPickerFrame:Show() end
    end)
    row:Refresh()
    row.control = row
    return row
end

local function cycleButton(parent, text, y, values, getKey, setKey)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", -16, y)
    row:SetHeight(38)
    row.title = label(row, text, 12, C.text, "LEFT", 0, 0)
    local b = button(row, "", 190, 28, nil)
    b:SetPoint("RIGHT", 0, 0)

    function b:Refresh()
        local key = getKey()
        local display = key
        for _, item in ipairs(values()) do
            if item.key == key then display = item.name break end
        end
        self.current = key
        self:SetLabel(display or "Unknown")
    end

    b:SetScript("OnClick", function(self)
        if not ZD:CanConfigure() then return end
        local list = values()
        if #list == 0 then return end
        local idx = 1
        for i, item in ipairs(list) do
            if item.key == self.current then idx = i break end
        end
        idx = idx + 1
        if idx > #list then idx = 1 end
        setKey(list[idx].key)
        self:Refresh()
        ZD:RefreshUI()
    end)
    b:Refresh()
    row.control = b
    return row
end

local function editBox(parent, width, height, multiline)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetSize(width, height)
    makeBackdrop(holder, C.panel, C.border)

    if not multiline then
        local edit = CreateFrame("EditBox", nil, holder)
        edit:SetPoint("TOPLEFT", 8, -4)
        edit:SetPoint("BOTTOMRIGHT", -8, 4)
        edit:SetAutoFocus(false)
        edit:SetMultiLine(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetTextInsets(2, 2, 2, 2)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        holder.edit = edit
        return holder
    end

    local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(width - 48)
    edit:SetHeight(900)
    edit:SetTextInsets(2, 2, 2, 2)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function()
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(edit)
    holder.edit = edit
    holder.scroll = scroll
    return holder
end

local function pageFrame(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    return p
end

-- ---------------------------------------------------------------------------
-- Native v11 option renderer
-- ---------------------------------------------------------------------------
-- Decursive's mature option definitions are used as a data/behavior model only.
-- AceConfigDialog is never opened or registered by v11. Every option is rendered
-- inside this window so there is one settings experience.

local function optionInfo(path, option, handler)
    local info = {
        [0] = D.name,
        appName = D.name,
        uiName = "ZhaohuV11",
        uiType = "modern",
        option = option,
        handler = handler,
        arg = option and option.arg or nil,
        type = option and option.type or nil,
    }
    for i, key in ipairs(path) do info[i] = key end
    return info
end

local function inheritedSpec(value, fallback)
    if value ~= nil then return value end
    return fallback
end

local function invokeOption(spec, handler, info, ...)
    if type(spec) == "function" then
        return pcall(spec, info, ...)
    elseif type(spec) == "string" and type(handler) == "table" and type(handler[spec]) == "function" then
        return pcall(handler[spec], handler, info, ...)
    end
    return true, spec
end

local function optionValue(spec, handler, info, default, ...)
    if spec == nil then return default end
    local ok, value, b, c, d = invokeOption(spec, handler, info, ...)
    if not ok then return default end
    if value == nil then return default, b, c, d end
    return value, b, c, d
end

local function optionName(option, handler, info, fallback)
    local name = optionValue(option.name, handler, info, fallback or "")
    if name == nil or name == "" then name = fallback or "" end
    return tostring(name)
end

local function attachTooltip(frame, title, desc)
    if not desc or desc == "" then return end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(tostring(desc), .72, .78, .86, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function sortedOptionArgs(args, plugins)
    -- Match AceConfig's plugin precedence without loading AceConfig itself:
    -- plugin entries win when they use the same key as a base option.
    local items, seen = {}, {}
    for _, plugin in pairs(plugins or {}) do
        if type(plugin) == "table" then
            for key, option in pairs(plugin) do
                if not seen[key] and type(option) == "table" then
                    seen[key] = true
                    items[#items + 1] = { key = key, option = option }
                end
            end
        end
    end
    for key, option in pairs(args or {}) do
        if not seen[key] and type(option) == "table" then
            seen[key] = true
            items[#items + 1] = { key = key, option = option }
        end
    end
    table.sort(items, function(a, b)
        local ao = tonumber(a.option.order) or 100
        local bo = tonumber(b.option.order) or 100
        if ao ~= bo then return ao < bo end
        return tostring(a.key) < tostring(b.key)
    end)
    return items
end

local function normalizeSelectValues(values)
    local out = {}
    if type(values) ~= "table" then return out end
    for key, name in pairs(values) do
        out[#out + 1] = { key = key, name = tostring(name) }
    end
    table.sort(out, function(a, b)
        if type(a.key) == "number" and type(b.key) == "number" then return a.key < b.key end
        return tostring(a.key) < tostring(b.key)
    end)
    return out
end

local function setDisabledVisual(frame, disabled)
    if not frame then return end
    frame:SetAlpha(disabled and .42 or 1)
    if frame.EnableMouse then frame:EnableMouse(not disabled) end
end

local function showConfirm(message, action)
    StaticPopupDialogs["ZHAOHU_DECURSIVE_V11_CONFIRM"] = StaticPopupDialogs["ZHAOHU_DECURSIVE_V11_CONFIRM"] or {
        text = "%s",
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(self, data) if type(data) == "function" then data() end end,
    }
    StaticPopup_Show("ZHAOHU_DECURSIVE_V11_CONFIRM", message or "Are you sure?", nil, action)
end

local function makeOptionScrollPage(parent)
    local p = pageFrame(parent)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -62)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetWidth(650)
    canvas:SetHeight(1)
    scroll:SetScrollChild(canvas)
    p.optionScroll = scroll
    p.optionCanvas = canvas
    p._rendered = {}
    return p
end

-- ---------------------------------------------------------------------------
-- Widget pool (v11.0.11)
-- ---------------------------------------------------------------------------
-- WoW never destroys frames, so the previous render model - CreateFrame in a
-- loop, then drop the references on rebuild - leaked a full widget tree on
-- every page rebuild/refresh. The pool below recycles frames per widget kind.
--
-- Each pooled kind registers two functions:
--   create()             -> builds a bare, unwired frame (called only when the
--                           free list for that kind is empty)
--   bind(frame, ctx)     -> (re)wires an acquired frame to the current option;
--                           MUST overwrite every script/closure the widget uses
--                           so a recycled frame never retains a previous
--                           option's setter. This is the correctness-critical
--                           half: a mis-bound recycled toggle would silently
--                           drive the wrong setting.
--
-- Only widget kinds present in poolKinds are pooled. Any widget still created
-- through the legacy CreateFrame path is tracked as "unpooled" and simply
-- hidden on release, exactly as before, so this scaffold can be rolled out one
-- kind at a time.
local poolKinds = {}

local function ensurePool(page)
    if not page._pool then
        page._pool = { free = {}, active = {} }
    end
    return page._pool
end

-- Acquire a pooled frame of `kind`, binding it to `ctx`. Falls back to nil if
-- the kind is not registered (caller then uses its legacy path).
local function acquirePooled(page, kind, ctx)
    local spec = poolKinds[kind]
    if not spec then return nil end
    local pool = ensurePool(page)
    pool.free[kind] = pool.free[kind] or {}
    pool.active[kind] = pool.active[kind] or {}

    local frame = table.remove(pool.free[kind])
    if not frame then
        frame = spec.create(page.optionCanvas)
        frame._poolKind = kind
    end
    frame:Show()
    spec.bind(frame, ctx)
    pool.active[kind][#pool.active[kind] + 1] = frame
    return frame
end

-- Track a frame created through the legacy (unpooled) path so it is hidden on
-- the next release. Identical behaviour to the old trackRendered.
local function trackRendered(page, frame)
    page._rendered[#page._rendered + 1] = frame
    return frame
end

-- Release everything rendered for `page`: pooled frames return to their free
-- list for reuse; unpooled frames are hidden (and remain allocated, as before).
local function hideRendered(page)
    for _, frame in ipairs(page._rendered or {}) do
        if frame and frame.Hide then frame:Hide() end
    end
    page._rendered = {}

    local pool = page._pool
    if pool then
        for kind, list in pairs(pool.active) do
            pool.free[kind] = pool.free[kind] or {}
            for i = #list, 1, -1 do
                local frame = list[i]
                list[i] = nil
                if frame then
                    -- Do not clear OnClick on the pooled row here.  The pooled
                    -- toggle row is a plain Frame (only row._switch is a Button),
                    -- so SetScript("OnClick") is not a supported script type on
                    -- the row and causes the settings rebuild to abort.  The
                    -- switch handler is installed once and reads only fields that
                    -- bind() refreshes for each option, so it is safe to preserve.
                    frame:Hide()
                    frame:ClearAllPoints()
                    pool.free[kind][#pool.free[kind] + 1] = frame
                end
            end
        end
    end
end

local function optionSet(page, option, state, info, value, ...)
    local extraArgs = { ... }
    local setSpec = inheritedSpec(option.set, state.set)
    if setSpec == nil then return false end

    if option.validate then
        local ok, validation = invokeOption(option.validate, option.handler or state.handler, info, value)
        if not ok then
            ZD:SetStatus("Validation failed: " .. tostring(validation), true)
            return false
        end
        if validation ~= true and validation ~= 0 then
            ZD:SetStatus(type(validation) == "string" and validation or "That value is not valid.", true)
            return false
        end
    end

    local function apply()
        local ok, err = invokeOption(setSpec, option.handler or state.handler, info, value, unpack(extraArgs))
        if not ok then
            ZD:SetStatus("Could not change setting: " .. tostring(err), true)
            return
        end
        ZD:SetStatus("Setting updated.")
        page._needsRebuild = true
        ZD:RefreshUI()
    end

    local confirm = option.confirm
    if confirm then
        local message
        if option.confirmText then
            message = tostring(option.confirmText)
        elseif confirm == true then
            message = "Apply " .. optionName(option, option.handler or state.handler, info, "this change") .. "?"
        elseif type(confirm) == "function" then
            local ok, result = invokeOption(confirm, option.handler or state.handler, info, value)
            message = ok and tostring(result or "Are you sure?") or "Are you sure?"
        else
            message = tostring(confirm)
        end
        showConfirm(message, apply)
    else
        apply()
    end
    return true
end

-- Pooled "toggle" widget. create() builds the bare row + switch once; bind()
-- re-wires it to whatever option is being rendered this pass. Every field the
-- OnClick/refresh closures read (frame._read, frame._info, ...) is reassigned
-- in bind, and the OnClick is reinstalled, so a recycled row can never fire a
-- previous option's setter.
poolKinds["toggle"] = {
    create = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row._title = label(row, "", 12, C.text, "TOPLEFT", 0, -2)
        row._desc = label(row, "", 10, C.muted, "TOPLEFT", 0, -21)
        row._desc:SetJustifyH("LEFT")

        local sw = CreateFrame("Button", nil, row, "BackdropTemplate")
        sw:SetSize(44, 22)
        sw:SetPoint("TOPRIGHT", 0, -2)
        makeBackdrop(sw, C.off, C.border)
        sw.knob = sw:CreateTexture(nil, "OVERLAY")
        sw.knob:SetSize(16, 16)
        sw.knob:SetColorTexture(.96, .97, .99, 1)
        row._switch = sw

        function row:_Refresh()
            local on = self._read and self._read() and true or false
            if on then
                self._switch:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
                self._switch.knob:ClearAllPoints(); self._switch.knob:SetPoint("RIGHT", -3, 0)
            else
                self._switch:SetBackdropColor(C.off[1], C.off[2], C.off[3], 1)
                self._switch.knob:ClearAllPoints(); self._switch.knob:SetPoint("LEFT", 3, 0)
            end
        end

        sw:SetScript("OnClick", function()
            if row._disabled or not ZD:CanConfigure() then return end
            optionSet(row._page, row._option, row._state, row._info, not (row._read and row._read()))
            row:_Refresh()
        end)
        return row
    end,

    bind = function(row, ctx)
        row._page = ctx.page
        row._option = ctx.option
        row._state = ctx.state
        row._info = ctx.info
        row._disabled = ctx.isDisabled
        local getSpec = ctx.getSpec
        local handler = ctx.handler
        local info = ctx.info
        row._read = function()
            local ok, value = invokeOption(getSpec, handler, info)
            return ok and value and true or false
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ctx.indent + 8, ctx.y)
        row:SetPoint("TOPRIGHT", -8, ctx.y)
        row:SetHeight(ctx.desc ~= "" and 48 or 34)

        row._title:SetText(ctx.name)
        if ctx.desc ~= "" then
            row._desc:Show()
            row._desc:SetText(tostring(ctx.desc))
            row._desc:SetWidth(500 - ctx.indent)
        else
            row._desc:SetText("")
            row._desc:Hide()
        end

        row:_Refresh()
        setDisabledVisual(row, ctx.isDisabled)
        attachTooltip(row, ctx.name, ctx.desc)
    end,
}

local function renderOptions(page, group, path, inherited, y, depth, skipKeys)
    local canvas = page.optionCanvas
    local groupHandler = group.handler or inherited.handler
    local groupInfo = optionInfo(path, group, groupHandler)
    local parentHidden = inherited.hidden == true
    local hidden = parentHidden or optionValue(group.hidden, groupHandler, groupInfo, false) == true
    if hidden then return y end
    local parentDisabled = inherited.disabled == true
    local disabled = parentDisabled or optionValue(group.disabled, groupHandler, groupInfo, false) == true
    local state = {
        handler = groupHandler,
        get = inheritedSpec(group.get, inherited.get),
        set = inheritedSpec(group.set, inherited.set),
        disabled = disabled,
        hidden = hidden,
    }

    local indent = math.min(depth * 14, 56)
    for _, item in ipairs(sortedOptionArgs(group.args, group.plugins)) do
        local key, option = item.key, item.option
        if not (skipKeys and skipKeys[key]) and not option.guiHidden then
            local childPath = {}
            for i, v in ipairs(path) do childPath[i] = v end
            childPath[#childPath + 1] = key
            local handler = option.handler or state.handler
            local info = optionInfo(childPath, option, handler)
            local isHidden = state.hidden or optionValue(option.hidden, handler, info, false) == true
            if not isHidden then
                local isDisabled = state.disabled or optionValue(option.disabled, handler, info, false) == true
                local name = optionName(option, handler, info, tostring(key))
                local desc = optionValue(option.desc, handler, info, "")
                local kind = option.type or "description"

                if kind == "group" then
                    local head = trackRendered(page, CreateFrame("Frame", nil, canvas, "BackdropTemplate"))
                    head:SetPoint("TOPLEFT", indent, y)
                    head:SetPoint("TOPRIGHT", -8, y)
                    head:SetHeight(38)
                    makeBackdrop(head, depth == 0 and C.card or C.panel, C.border)
                    label(head, name, depth == 0 and 15 or 13, depth == 0 and C.accent or C.text, "LEFT", 12, 0)
                    attachTooltip(head, name, desc)
                    y = y - 46
                    y = renderOptions(page, option, childPath, state, y, depth + 1, nil)
                    y = y - 8
                elseif kind == "header" then
                    local fs = trackRendered(page, label(canvas, name, 12, C.accent, "TOPLEFT", indent + 8, y))
                    fs:SetWidth(610 - indent)
                    y = y - 30
                elseif kind == "description" then
                    local fs = trackRendered(page, label(canvas, name, 11, C.muted, "TOPLEFT", indent + 8, y))
                    fs:SetWidth(610 - indent)
                    fs:SetJustifyH("LEFT")
                    fs:SetWordWrap(true)
                    local h = math.max(22, (fs.GetStringHeight and fs:GetStringHeight() or 18) + 8)
                    y = y - h
                elseif kind == "toggle" then
                    -- Pooled path (v11.0.11): recycled instead of re-allocated.
                    local row = acquirePooled(page, "toggle", {
                        page = page, option = option, state = state, info = info,
                        handler = handler, isDisabled = isDisabled,
                        getSpec = inheritedSpec(option.get, state.get),
                        name = name, desc = desc, indent = indent, y = y,
                    })
                    y = y - row:GetHeight() - 6
                elseif kind == "range" then
                    local row = trackRendered(page, CreateFrame("Frame", nil, canvas))
                    row:SetPoint("TOPLEFT", indent + 8, y); row:SetPoint("TOPRIGHT", -8, y); row:SetHeight(66)
                    local title = label(row, name, 12, C.text, "TOPLEFT", 0, -2)
                    local s = CreateFrame("Slider", nil, row)
                    s:SetPoint("TOPLEFT", 0, -34); s:SetPoint("TOPRIGHT", 0, -34); s:SetHeight(18)
                    s:SetOrientation("HORIZONTAL")
                    local minV = optionValue(option.min, handler, info, 0)
                    local maxV = optionValue(option.max, handler, info, 100)
                    local step = optionValue(option.step, handler, info, 1)
                    s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
                    local bg = s:CreateTexture(nil,"BACKGROUND"); bg:SetPoint("LEFT"); bg:SetPoint("RIGHT"); bg:SetHeight(4); setColor(bg,C.off)
                    local fill = s:CreateTexture(nil,"ARTWORK"); fill:SetPoint("LEFT"); fill:SetHeight(4); setColor(fill,C.accent)
                    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                    local thumb = s:GetThumbTexture(); if thumb then thumb:SetSize(18,18) end
                    local getSpec = inheritedSpec(option.get, state.get)
                    local ok, current = invokeOption(getSpec, handler, info); current = ok and tonumber(current) or minV
                    current = snapRangeValue(current, minV, maxV, step)

                    local stepper = addRangeStepper(row, s, minV, maxV, step, option.isPercent == true, nil, function() return isDisabled end)
                    title:SetPoint("RIGHT", stepper, "LEFT", -10, 0); title:SetJustifyH("LEFT")

                    local function display(v)
                        v = snapRangeValue(v, minV, maxV, step)
                        stepper:Refresh(v)
                        local w=s:GetWidth(); if w and w>0 and maxV>minV then fill:SetWidth(math.max(1,w*((v-minV)/(maxV-minV)))) end
                    end
                    s._refreshing = true; s:SetValue(current); s._refreshing = false
                    display(current)
                    s:SetScript("OnValueChanged", function(self,v)
                        local rounded = snapRangeValue(v, minV, maxV, step)
                        display(rounded)
                        if not self._refreshing and not isDisabled and ZD:CanConfigure(true) then
                            local setSpec = inheritedSpec(option.set, state.set)
                            local okSet, err = invokeOption(setSpec, handler, info, rounded)
                            if not okSet then
                                ZD:SetStatus("Could not change setting: "..tostring(err), true)
                            else
                                ZD:SetStatus(name .. " updated.")
                            end
                        end
                    end)
                    s:SetScript("OnSizeChanged", function() display(s:GetValue()) end)
                    setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y = y - 74
                elseif kind == "select" then
                    local row = trackRendered(page, CreateFrame("Frame", nil, canvas))
                    row:SetPoint("TOPLEFT", indent + 8, y); row:SetPoint("TOPRIGHT", -8, y); row:SetHeight(38)
                    label(row,name,12,C.text,"LEFT",0,0)
                    local b = button(row,"",220,28,nil); b:SetPoint("RIGHT",0,0)
                    local getSpec = inheritedSpec(option.get, state.get)
                    local function values()
                        local raw = optionValue(option.values, handler, info, {})
                        return normalizeSelectValues(raw)
                    end
                    local function current()
                        local ok,v=invokeOption(getSpec,handler,info); return ok and v or nil
                    end
                    local function refresh()
                        local cur=current(); b.current=cur; local display=tostring(cur or "")
                        for _,v in ipairs(values()) do if v.key==cur then display=v.name break end end
                        b:SetLabel(display)
                    end
                    b:SetScript("OnClick",function()
                        if isDisabled or not ZD:CanConfigure() then return end
                        local list=values(); if #list==0 then return end
                        local idx=0; for i,v in ipairs(list) do if v.key==b.current then idx=i break end end
                        idx=idx+1; if idx>#list then idx=1 end
                        optionSet(page,option,state,info,list[idx].key); refresh()
                    end)
                    refresh(); setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y=y-46
                elseif kind == "input" then
                    local multiline = option.multiline and option.multiline ~= false
                    local h = multiline and 156 or 64
                    local row = trackRendered(page, CreateFrame("Frame", nil, canvas))
                    row:SetPoint("TOPLEFT",indent+8,y); row:SetPoint("TOPRIGHT",-8,y); row:SetHeight(h)
                    label(row,name,12,C.text,"TOPLEFT",0,-2)
                    local box=editBox(row, multiline and 520 or 420, multiline and 94 or 34, multiline)
                    box:SetPoint("TOPLEFT",0,-28)
                    local getSpec=inheritedSpec(option.get, state.get)
                    local ok,v=invokeOption(getSpec,handler,info); box.edit:SetText(ok and tostring(v or "") or "")
                    local apply=button(row,"Apply",82,28,function()
                        if isDisabled or not ZD:CanConfigure() then return end
                        optionSet(page,option,state,info,box.edit:GetText())
                    end,"primary")
                    apply:SetPoint("TOPLEFT", multiline and 532 or 432, -31)
                    if not multiline then box.edit:SetScript("OnEnterPressed",function(self) apply:Click(); self:ClearFocus() end) end
                    setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y=y-h-8
                elseif kind == "execute" then
                    local row = trackRendered(page, CreateFrame("Frame", nil, canvas))
                    row:SetPoint("TOPLEFT",indent+8,y); row:SetPoint("TOPRIGHT",-8,y); row:SetHeight(desc ~= "" and 56 or 38)
                    local b=button(row,name,math.min(300,math.max(150,#name*7+30)),30,nil, option.confirm and "danger" or nil)
                    b:SetPoint("TOPLEFT",0,0)
                    if desc ~= "" then local d=label(row,tostring(desc),10,C.muted,"TOPLEFT",0,-35); d:SetWidth(580-indent); d:SetJustifyH("LEFT") end
                    b:SetScript("OnClick",function()
                        if isDisabled or not ZD:CanConfigure() then return end
                        local function run()
                            local ok,err=invokeOption(option.func,handler,info)
                            if not ok then ZD:SetStatus("Action failed: "..tostring(err),true) else ZD:SetStatus("Action completed.") end
                            page._needsRebuild=true; ZD:RefreshUI()
                        end
                        if option.confirm then
                            local msg=option.confirmText or (option.confirm==true and ("Run "..name.."?") or tostring(option.confirm))
                            showConfirm(msg,run)
                        else run() end
                    end)
                    setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y=y-row:GetHeight()-8
                elseif kind == "color" then
                    local row = trackRendered(page, CreateFrame("Frame", nil, canvas))
                    -- Color rows use two distinct lines when alpha is available:
                    --   line 1 = option name + Edit Color button
                    --   line 2 = Alpha label + slider + exact-value stepper
                    -- The old RIGHT anchor vertically centered Edit Color in the full
                    -- 70px row, placing it directly on top of the alpha controls.
                    row:SetPoint("TOPLEFT",indent+8,y); row:SetPoint("TOPRIGHT",-8,y); row:SetHeight(option.hasAlpha and 80 or 40)
                    label(row,name,12,C.text,"TOPLEFT",0,-2)
                    local getSpec=inheritedSpec(option.get, state.get)
                    local ok,r,g,b,a=invokeOption(getSpec,handler,info); if not ok then r,g,b,a=1,1,1,1 end; a=a or 1
                    local sw=button(row,"Edit Color",110,28,nil); sw:SetPoint("TOPRIGHT",0,-1)
                    sw.sample=sw:CreateTexture(nil,"ARTWORK"); sw.sample:SetSize(18,18); sw.sample:SetPoint("LEFT",6,0); sw.sample:SetColorTexture(r or 1,g or 1,b or 1,a or 1)
                    sw.text:ClearAllPoints(); sw.text:SetPoint("LEFT",30,0)
                    if option.hasAlpha then
                        local alphaText=label(row,"Alpha",10,C.muted,"TOPLEFT",0,-47)
                        local alphaSlider=CreateFrame("Slider",nil,row)
                        alphaSlider:SetPoint("TOPLEFT",72,-48); alphaSlider:SetPoint("TOPRIGHT",-142,-48); alphaSlider:SetHeight(14)
                        alphaSlider:SetOrientation("HORIZONTAL")
                        alphaSlider:SetMinMaxValues(0,1); alphaSlider:SetValueStep(.05); if alphaSlider.SetObeyStepOnDrag then alphaSlider:SetObeyStepOnDrag(true) end
                        alphaSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                        alphaSlider:SetValue(a or 1)
                        local alphaStepper = addRangeStepper(row, alphaSlider, 0, 1, .05, true, nil, function() return isDisabled end)
                        alphaStepper:ClearAllPoints(); alphaStepper:SetPoint("TOPRIGHT", 0, -40)
                        alphaStepper:Refresh(a or 1)
                        alphaSlider:SetScript("OnValueChanged",function(self,value)
                            if isDisabled or not ZD:CanConfigure(true) then return end
                            local okA,ar,ag,ab=invokeOption(getSpec,handler,info); if not okA then return end
                            local setSpec=inheritedSpec(option.set,state.set)
                            local okSet,err=invokeOption(setSpec,handler,info,ar or 1,ag or 1,ab or 1,value)
                            if okSet then alphaStepper:Refresh(value) else ZD:SetStatus("Could not change alpha: "..tostring(err),true) end
                        end)
                    end
                    sw:SetScript("OnClick",function()
                        if isDisabled or not ZD:CanConfigure() then return end
                        local ok2,cr,cg,cb,ca=invokeOption(getSpec,handler,info); if not ok2 then cr,cg,cb,ca=1,1,1,1 end; ca=ca or 1
                        local picker = {
                            r=cr,g=cg,b=cb, opacity=ca, hasOpacity=option.hasAlpha == true,
                        }
                        local function commit()
                            local nr,ng,nb=ColorPickerFrame:GetColorRGB()
                            local na=ca
                            if option.hasAlpha and ColorPickerFrame.GetColorAlpha then na=ColorPickerFrame:GetColorAlpha() end
                            local setSpec=inheritedSpec(option.set, state.set)
                            local okSet,err=invokeOption(setSpec,handler,info,nr,ng,nb,na)
                            if not okSet then ZD:SetStatus("Could not change color: "..tostring(err),true) else sw.sample:SetColorTexture(nr,ng,nb,na); ZD:SetStatus("Color updated.") end
                        end
                        picker.swatchFunc=commit; picker.opacityFunc=commit
                        picker.cancelFunc=function(previous)
                            if type(previous)=="table" then
                                local setSpec=inheritedSpec(option.set, state.set)
                                invokeOption(setSpec,handler,info,previous.r or cr,previous.g or cg,previous.b or cb,previous.opacity or ca)
                            end
                        end
                        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(picker) else ColorPickerFrame:Show() end
                    end)
                    setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y=y-(option.hasAlpha and 88 or 48)
                elseif kind == "multiselect" then
                    local title=trackRendered(page,label(canvas,name,12,C.text,"TOPLEFT",indent+8,y)); title:SetWidth(600-indent)
                    y=y-28
                    local values=normalizeSelectValues(optionValue(option.values,handler,info,{}))
                    for _,entry in ipairs(values) do
                        local row=trackRendered(page,CreateFrame("Frame",nil,canvas))
                        row:SetPoint("TOPLEFT",indent+22,y); row:SetPoint("TOPRIGHT",-8,y); row:SetHeight(30)
                        label(row,entry.name,11,C.text,"LEFT",0,0)
                        local sw=CreateFrame("Button",nil,row,"BackdropTemplate"); sw:SetSize(38,20); sw:SetPoint("RIGHT",0,0); makeBackdrop(sw,C.off,C.border)
                        local function read() local ok2,val=invokeOption(option.get,handler,info,entry.key); return ok2 and val and true or false end
                        local function refresh() local on=read(); sw:SetBackdropColor(on and C.accent[1] or C.off[1],on and C.accent[2] or C.off[2],on and C.accent[3] or C.off[3],1) end
                        sw:SetScript("OnClick",function() if isDisabled or not ZD:CanConfigure() then return end; local ok2,err=invokeOption(option.set,handler,info,entry.key,not read()); if not ok2 then ZD:SetStatus(tostring(err),true) else ZD:SetStatus("Filter updated.") end; refresh() end)
                        refresh(); setDisabledVisual(row,isDisabled)
                        y=y-34
                    end
                    y=y-4
                elseif kind == "keybinding" then
                    local row=trackRendered(page,CreateFrame("Frame",nil,canvas))
                    row:SetPoint("TOPLEFT",indent+8,y); row:SetPoint("TOPRIGHT",-8,y); row:SetHeight(42)
                    label(row,name,12,C.text,"LEFT",0,0)
                    local getSpec=inheritedSpec(option.get, state.get)
                    local b=button(row,"",220,28,nil); b:SetPoint("RIGHT",0,0)
                    local function refresh() local ok2,key=invokeOption(getSpec,handler,info); b:SetLabel(ok2 and (key or "Not bound") or "Not bound") end
                    b:SetScript("OnClick",function(self)
                        if isDisabled or not ZD:CanConfigure() then return end
                        self:SetLabel("Press a keyâ€¦"); self:EnableKeyboard(true); if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                        self:SetScript("OnKeyDown",function(btn,key)
                            if key=="ESCAPE" then btn:EnableKeyboard(false); btn:SetScript("OnKeyDown",nil); refresh(); return end
                            if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
                            local bind=""; if IsControlKeyDown() then bind=bind.."CTRL-" end; if IsShiftKeyDown() then bind=bind.."SHIFT-" end; if IsAltKeyDown() then bind=bind.."ALT-" end; bind=bind..key
                            btn:EnableKeyboard(false); btn:SetScript("OnKeyDown",nil); optionSet(page,option,state,info,bind); refresh()
                        end)
                    end)
                    refresh(); setDisabledVisual(row,isDisabled); attachTooltip(row,name,desc)
                    y=y-50
                else
                    local fs=trackRendered(page,label(canvas,name,11,C.muted,"TOPLEFT",indent+8,y)); fs:SetWidth(600-indent)
                    y=y-28
                end
            end
        end
    end
    return y
end

function ZD:BuildOptionGroupPage(parent, groupKey, titleText, subtitleText, skipKeys)
    local p = makeOptionScrollPage(parent)
    self:PageTitle(p, titleText, subtitleText)
    p.groupKey = groupKey
    p.skipKeys = skipKeys
    function p:Rebuild()
        hideRendered(self)
        local ok, model = pcall(D.GetV11OptionsTable, D)
        if not ok or type(model) ~= "table" or not model.args then
            local e=trackRendered(self,label(self.optionCanvas,"The settings model is not available yet.",12,C.danger,"TOPLEFT",8,-8)); e:SetWidth(620)
            self.optionCanvas:SetHeight(80); return
        end
        local group=model.args[groupKey]
        if type(group)~="table" then
            local e=trackRendered(self,label(self.optionCanvas,"This settings section is unavailable.",12,C.danger,"TOPLEFT",8,-8)); e:SetWidth(620)
            self.optionCanvas:SetHeight(80); return
        end
        local inherited={handler=model.handler,get=model.get,set=model.set,disabled=false,hidden=false}
        local y=renderOptions(self,group,{groupKey},inherited,-8,0,skipKeys)
        self.optionCanvas:SetHeight(math.max(520, -y + 24))
        self._needsRebuild=false
    end
    function p:Refresh() if self._needsRebuild then self:Rebuild() end end
    p:Rebuild()
    return p
end

local function resolveOptionPath(model, path)
    local node = model
    for _, key in ipairs(path or {}) do
        node = node and node.args and node.args[key]
        if type(node) ~= "table" then return nil end
    end
    return node
end

function ZD:BuildTabbedOptionPathPage(parent, titleText, subtitleText, tabs, initialTab)
    local p = makeOptionScrollPage(parent)
    self:PageTitle(p, titleText, subtitleText)
    p.tabs = tabs or {}
    p.activeTab = initialTab or (tabs and tabs[1] and tabs[1].key)

    local tabBar = CreateFrame("Frame", nil, p)
    tabBar:SetPoint("TOPLEFT", 0, -62)
    tabBar:SetPoint("TOPRIGHT", 0, -62)
    tabBar:SetHeight(36)
    p.tabButtons = {}

    local x = 0
    for _, tab in ipairs(p.tabs) do
        local w = tab.width or math.max(110, math.min(180, (#tab.name * 7) + 28))
        local b = button(tabBar, tab.name, w, 30, function()
            p.activeTab = tab.key
            p._needsRebuild = true
            p:Rebuild()
        end)
        b:SetPoint("TOPLEFT", x, -2)
        p.tabButtons[tab.key] = b
        x = x + w + 8
    end

    p.optionScroll:ClearAllPoints()
    p.optionScroll:SetPoint("TOPLEFT", 0, -106)
    p.optionScroll:SetPoint("BOTTOMRIGHT", -22, 0)

    local function activeSpec()
        for _, tab in ipairs(p.tabs) do if tab.key == p.activeTab then return tab end end
        return p.tabs[1]
    end

    function p:SetTab(key)
        for _, tab in ipairs(self.tabs) do
            if tab.key == key then self.activeTab = key; self._needsRebuild = true; self:Rebuild(); return true end
        end
    end

    function p:Rebuild()
        hideRendered(self)
        local tab = activeSpec()
        if not tab then self.optionCanvas:SetHeight(80); return end
        for key,b in pairs(self.tabButtons) do
            if key == tab.key then
                b:SetBackdropColor(C.accent[1]*.35,C.accent[2]*.35,C.accent[3]*.35,1)
                b:SetBackdropBorderColor(unpack(C.accent))
            else
                b:SetBackdropColor(C.card[1],C.card[2],C.card[3],C.card[4])
                b:SetBackdropBorderColor(unpack(C.border))
            end
        end
        local ok, model = pcall(D.GetV11OptionsTable, D)
        if not ok or type(model) ~= "table" then self.optionCanvas:SetHeight(80); return end
        local group = resolveOptionPath(model, tab.path)
        if type(group) ~= "table" then
            local e=trackRendered(self,label(self.optionCanvas,"This subsection is unavailable.",12,C.danger,"TOPLEFT",8,-8)); e:SetWidth(620)
            self.optionCanvas:SetHeight(80); return
        end
        local inherited={handler=model.handler,get=model.get,set=model.set,disabled=false,hidden=false}
        -- inherit handlers/get/set through ancestors
        local node=model
        for _, key in ipairs(tab.path or {}) do
            node=node.args[key]
            inherited.handler=node.handler or inherited.handler
            inherited.get=inheritedSpec(node.get,inherited.get)
            inherited.set=inheritedSpec(node.set,inherited.set)
            inherited.disabled=inherited.disabled or optionValue(node.disabled,inherited.handler,optionInfo(tab.path,node,inherited.handler),false)==true
        end
        local y=renderOptions(self,group,tab.path,inherited,-8,0,tab.skipKeys)
        self.optionCanvas:SetHeight(math.max(520,-y+24))
        self._needsRebuild=false
    end
    function p:Refresh() if self._needsRebuild then self:Rebuild() end end
    p:Rebuild()
    return p
end

-- ---------------------------------------------------------------------------
-- Global settings search
-- ---------------------------------------------------------------------------
-- Search is intentionally independent of the page renderer. It indexes both
-- the mature Decursive option model and the native v11-only controls so one
-- field can find settings anywhere in the single v11 UI.

local SEARCH_PAGE_NAMES = {
    dashboard = "Dashboard",
    general = "General",
    sounds = "Sound Notifications",
    frames = "Micro Unit Frames",
    curing = "Curing",
    bleeds = "Bleed Management",
    cooldowns = "Cooldowns",
    range = "Range & Visibility",
    bindings = "Spells & Bindings",
    filtering = "Affliction Filters",
    livelist = "Live List",
    messages = "Messages",
    macro = "Macro",
    profiles = "Profiles & Modes",
    sharing = "Import / Export",
    lists = "Priority & Skip",
    integrations = "Detection",
    testmode = "Test Mode",
    compat121 = "12.1 Status",
    diagnostics = "Diagnostics",
    dispeldb = "Dispel Database",
    about = "About",
}

local SEARCH_GROUP_TO_PAGE = {
    general = "general",
    SoundNotifications = "sounds",
    MicroFrameOpt = "frames",
    CureOptions = "curing",
    DebuffSkip = "filtering",
    livelistoptions = "livelist",
    MessageOptions = "messages",
    Macro = "macro",
    Compatibility121 = "compat121",
    About = "about",
}

local SEARCH_NATIVE_ENTRIES = {
    dashboard = {
        { "User profile", "profile character AceDB setup" },
        { "Environment", "automatic mode Open World Dungeon Follower Mythic+ Raid PvP" },
        { "Test MUFs", "micro unit frames diagnostics preview" },
    },
    testmode = {
        { "Test Mode", "preview cooldown status light layout stress" },
        { "Preview All Visible MUFs", "cooldown overlay status lights" },
        { "Test Layout", "placeholder slots raid spacing" },
        { "Soul Link Alert", "alert warning battle rez Soul Link banner" },
        { "DISPEL alert", "DISPEL alert warning timed duration until cleared" },
    },
    frames = {
        { "Show MUFs", "micro unit frames display hide" },
        { "Status indicator light", "status light range fail success spacing" },
        { "Lock position", "micro unit frames move unlock handle" },
    },
    bleeds = {
        { "Bleed discovery", "bleed auto detection keywords effects" },
        { "Bleed keywords", "description keywords discovery" },
        { "Known bleed effects", "bleed spell IDs manual list" },
        { "Add bleed effect", "bleed spell ID" },
    },
    range = {
        { "Out of range", "range dim overlay color" },
        { "Line of sight", "LoS failed cleanse overlay color visibility" },
        { "LoS color", "line of sight blocked color" },
        { "LoS hold time", "line of sight failed cast duration" },
    },
    cooldowns = {
        { "Editing behavior", "environment Open World Dungeon Follower Mythic+ Raid PvP" },
        { "Cooldown overlay", "remaining dispel targets shaded cooldown" },
        { "Countdown numbers", "cooldown text timer" },
        { "Overlay opacity", "cooldown transparency" },
        { "Secondary-affliction border", "priority border multiple dispels" },
        { "Pulse secondary border", "priority border animation" },
        { "Share same-priority cooldown", "shared cooldown priority" },
        { "Reset this behavior", "environment behavior defaults" },
    },
    bindings = {
        { "Active cure assignments", "Magic Poison Disease Curse Charm cleanse dispel" },
        { "Secure mouse assignments", "Left Right Middle Button4 Button5 click casting" },
        { "Modifier bindings", "Shift Ctrl Control Alt mouse click" },
        { "Custom spells and items", "add cure spell item ability" },
        { "Internal macro", "UNITID custom spell macro" },
        { "Cure types", "Magic Poison Disease Curse Charm" },
        { "Spell priority", "priority cure assignment" },
        { "Unit filtering", "player only other friendly units" },
    },
    profiles = {
        { "User profile", "AceDB profile character setup" },
        { "Create / Switch", "new profile profile management" },
        { "Copy Current", "clone duplicate profile" },
        { "Reset Current", "profile defaults reset" },
        { "Environment Mode", "Automatic Open World Dungeon Follower Mythic+ Raid PvP provider profile" },
        { "Mode selection", "environment behavior override automatic" },
    },
    sharing = {
        { "Generate Export", "profile share serialize copy" },
        { "Import Into Current Profile", "profile paste import sharing" },
    },
    lists = {
        { "Priority List", "priority players units add target move order" },
        { "Skip List", "ignore players units add target remove" },
        { "Add Target", "priority skip current target" },
        { "Clear Priority List", "remove all priority" },
        { "Clear Skip List", "remove all skip ignore" },
    },
    integrations = {
        { "Detection", "native Blizzard-managed AuraContainers provider status" },
        { "Detection provider", "Native Blizzard-managed Decursive source of truth" },
    },
    compat121 = {
        { "Managed aura status", "WoW 12.1 protected aura secret values" },
        { "Dispel resolver", "refresh detected dispel 12.1" },
        { "MUF visual tests", "selected all micro unit frames diagnostics" },
    },
    diagnostics = {
        { "Run Self-Diagnostic", "diagnostics test compatibility" },
        { "Print 12.1 Status", "managed aura diagnostics chat" },
        { "Reload UI", "reload interface" },
    },
    about = {
        { "Version", "build alpha credits license" },
        { "Credits", "authors contributors" },
    },
}

local function cleanSearchText(value)
    local text = tostring(value or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[\r\n\t]+", " "):gsub("%s+", " ")
    return text
end

local function lowerSearchText(value)
    return cleanSearchText(value):lower()
end

function ZD:BuildSearchIndex(force)
    if self.searchIndex and not force then return self.searchIndex end

    local entries, seen = {}, {}
    local function add(page, name, context, keywords)
        name = cleanSearchText(name)
        if name == "" or not SEARCH_PAGE_NAMES[page] then return end
        context = cleanSearchText(context)
        keywords = cleanSearchText(keywords)
        local signature = page .. "\031" .. name .. "\031" .. context
        if seen[signature] then return end
        seen[signature] = true
        local pageName = SEARCH_PAGE_NAMES[page]
        entries[#entries + 1] = {
            page = page,
            pageName = pageName,
            label = name,
            context = context,
            search = lowerSearchText(pageName .. " " .. name .. " " .. context .. " " .. keywords),
            labelSearch = lowerSearchText(name),
            pageSearch = lowerSearchText(pageName),
        }
    end

    -- Every page is itself searchable.
    for page, pageName in pairs(SEARCH_PAGE_NAMES) do
        add(page, pageName, "Page", pageName)
    end

    -- Native v11 controls that do not live in the legacy option model.
    for page, pageEntries in pairs(SEARCH_NATIVE_ENTRIES) do
        for _, entry in ipairs(pageEntries) do
            add(page, entry[1], "Native v11 setting", entry[2])
        end
    end

    -- Index all settings that are still backed by the mature Decursive option
    -- model. This is read-only metadata inspection; no setting getters/setters
    -- are changed and no protected aura data is touched.
    local ok, model = pcall(D.GetV11OptionsTable, D)
    if ok and type(model) == "table" and type(model.args) == "table" then
        local function walk(page, group, path, inheritedHandler, parentName, depth)
            if type(group) ~= "table" or depth > 10 then return end
            local handler = group.handler or inheritedHandler or model.handler
            for _, item in ipairs(sortedOptionArgs(group.args, group.plugins)) do
                local key, option = item.key, item.option
                local childPath = {}
                for i, v in ipairs(path) do childPath[i] = v end
                childPath[#childPath + 1] = key
                local optionHandler = option.handler or handler
                local info = optionInfo(childPath, option, optionHandler)
                local name = optionName(option, optionHandler, info, tostring(key))
                local desc = optionValue(option.desc, optionHandler, info, "")
                local context = parentName or SEARCH_PAGE_NAMES[page]
                if option.type == "group" then
                    add(page, name, context, tostring(key) .. " " .. tostring(desc or ""))
                    walk(page, option, childPath, optionHandler, name, depth + 1)
                elseif option.type ~= "header" and option.type ~= "description" then
                    add(page, name, context, tostring(key) .. " " .. tostring(desc or ""))
                end
            end
        end

        for groupKey, page in pairs(SEARCH_GROUP_TO_PAGE) do
            local group = model.args[groupKey]
            if type(group) == "table" then
                walk(page, group, { groupKey }, model.handler, SEARCH_PAGE_NAMES[page], 0)
            end
        end
    end

    self.searchIndex = entries
    return entries
end

function ZD:FindSearchResults(query, limit)
    query = lowerSearchText(query)
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return {} end

    local words = {}
    for word in query:gmatch("%S+") do words[#words + 1] = word end
    local matches = {}
    for _, entry in ipairs(self:BuildSearchIndex()) do
        local allWords = true
        for _, word in ipairs(words) do
            if not entry.search:find(word, 1, true) then allWords = false break end
        end
        if allWords then
            local score = 0
            if entry.labelSearch == query then score = score + 1000 end
            if entry.labelSearch:find(query, 1, true) then score = score + 400 end
            if entry.labelSearch:sub(1, #query) == query then score = score + 250 end
            if entry.pageSearch == query then score = score + 200 end
            if entry.pageSearch:find(query, 1, true) then score = score + 80 end
            score = score - (#entry.label * .01)
            matches[#matches + 1] = { entry = entry, score = score }
        end
    end

    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.entry.pageName ~= b.entry.pageName then return a.entry.pageName < b.entry.pageName end
        return a.entry.label < b.entry.label
    end)

    local out = {}
    for i = 1, math.min(limit or 8, #matches) do out[i] = matches[i].entry end
    return out
end

function ZD:UpdateSearchResults(query)
    local f = self.frame
    if not f or not f.searchResults then return end
    local panel = f.searchResults
    local results = self:FindSearchResults(query, #panel.rows)
    panel.matches = results

    if #results == 0 then
        panel:Hide()
        return
    end

    for i, row in ipairs(panel.rows) do
        local result = results[i]
        if result then
            row.result = result
            row.title:SetText(result.label)
            local path = result.pageName
            if result.context and result.context ~= "" and result.context ~= "Page" and result.context ~= result.pageName then
                path = path .. "  â€º  " .. result.context
            end
            row.path:SetText(path)
            row:Show()
        else
            row.result = nil
            row:Hide()
        end
    end
    panel:SetHeight(8 + (#results * 36))
    panel:Show()
end

function ZD:OpenSearchResult(result)
    if not result then return end
    self:ShowPage(result.page)
    if self.frame and self.frame.searchBox then
        self.frame.searchBox.edit:SetText("")
        self.frame.searchBox.edit:ClearFocus()
    end
    if self.frame and self.frame.searchResults then self.frame.searchResults:Hide() end
    self:SetStatus("Search opened " .. result.pageName .. " - " .. result.label .. ".")
end

function ZD:CreateUI()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "ZhaohusDecursiveModernFrame", UIParent, "BackdropTemplate")
    local savedW = D.profile and tonumber(D.profile.V11WindowWidth) or 900
    local savedH = D.profile and tonumber(D.profile.V11WindowHeight) or 620
    savedW = math.max(760, math.min(savedW or 900, 1400))
    savedH = math.max(520, math.min(savedH or 620, 1000))
    f:SetSize(savedW, savedH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(760, 520, 1400, 1000) else
        if f.SetMinResize then f:SetMinResize(760,520) end
        if f.SetMaxResize then f:SetMaxResize(1400,1000) end
    end
    f:EnableMouse(true)
    makeBackdrop(f, C.bg, C.border)
    f:Hide()
    self.frame = f

    if UISpecialFrames then
        local registered = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == f:GetName() then registered = true break end
        end
        if not registered then table.insert(UISpecialFrames, f:GetName()) end
    end

    -- Slim DF-style title bar (not the old tall branded header).
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(32)
    makeBackdrop(titleBar, C.titleBar, C.border)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.titleBar = titleBar

    local accentStrip = titleBar:CreateTexture(nil, "ARTWORK")
    accentStrip:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    accentStrip:SetPoint("BOTTOMLEFT", 0, 0)
    accentStrip:SetPoint("BOTTOMRIGHT", 0, 0)
    accentStrip:SetHeight(2)

    titleBar.title = label(titleBar, "Zhaohu's Decursive", 14, C.accent, "LEFT", 14, 1)
    titleBar.version = label(titleBar, tostring(self.version or ""), 11, C.muted, "LEFT", 0, 1)
    titleBar.version:ClearAllPoints()
    titleBar.version:SetPoint("LEFT", titleBar.title, "RIGHT", 10, 0)

    local close = button(titleBar, "X", 24, 22, function() f:Hide() end)
    close:SetPoint("RIGHT", -8, 0)

    local toolbar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    toolbar:SetPoint("TOPLEFT", 0, -32)
    toolbar:SetPoint("TOPRIGHT", 0, -32)
    toolbar:SetHeight(40)
    makeBackdrop(toolbar, C.panel, C.border)
    f.toolbar = toolbar
    toolbar.motto = label(toolbar, "Detect  ·  Cleanse  ·  Protect", 11, C.muted, "LEFT", 14, 0)

    local searchBox = editBox(toolbar, 280, 26, false)
    searchBox:SetPoint("RIGHT", -14, 0)
    searchBox.edit:SetMaxLetters(80)
    searchBox.placeholder = label(searchBox, "Search settings...", 11, C.muted, "LEFT", 10, 0)
    f.searchBox = searchBox

    local searchResults = CreateFrame("Frame", nil, f, "BackdropTemplate")
    searchResults:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -4)
    searchResults:SetWidth(420)
    searchResults:SetHeight(10)
    searchResults:SetFrameLevel(toolbar:GetFrameLevel() + 20)
    makeBackdrop(searchResults, C.panel, C.border)
    searchResults:Hide()
    searchResults.rows = {}
    f.searchResults = searchResults

    for i = 1, 12 do
        local row = CreateFrame("Button", nil, searchResults, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 4, -4 - ((i - 1) * 36))
        row:SetPoint("TOPRIGHT", -4, -4 - ((i - 1) * 36))
        row:SetHeight(34)
        makeBackdrop(row, C.element, C.border)
        row.title = label(row, "", 11, C.text, "TOPLEFT", 10, -4)
        row.title:SetPoint("RIGHT", -10, 0)
        row.title:SetJustifyH("LEFT")
        row.path = label(row, "", 9, C.muted, "BOTTOMLEFT", 10, 4)
        row.path:SetPoint("RIGHT", -10, 0)
        row.path:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.hover[1], C.hover[2], C.hover[3], 1)
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(C.element[1], C.element[2], C.element[3], 1)
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
        row:SetScript("OnClick", function(self) ZD:OpenSearchResult(self.result) end)
        row:Hide()
        searchResults.rows[i] = row
    end

    searchBox.edit:SetScript("OnEditFocusGained", function(self)
        searchBox.placeholder:Hide()
        ZD:UpdateSearchResults(self:GetText())
    end)
    searchBox.edit:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then searchBox.placeholder:Show() end
        C_Timer.After(0.12, function()
            if f.searchResults and not (f.searchBox and f.searchBox.edit and f.searchBox.edit:HasFocus()) then
                f.searchResults:Hide()
            end
        end)
    end)
    searchBox.edit:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" and not self:HasFocus() then searchBox.placeholder:Show() else searchBox.placeholder:Hide() end
        if #text >= 2 then ZD:UpdateSearchResults(text) else searchResults:Hide() end
    end)
    searchBox.edit:SetScript("OnEnterPressed", function(self)
        local first = f.searchResults and f.searchResults.matches and f.searchResults.matches[1]
        if first then ZD:OpenSearchResult(first) else self:ClearFocus() end
    end)
    searchBox.edit:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
        searchResults:Hide()
    end)

    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 0, -72)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(200)
    makeBackdrop(sidebar, C.panel, C.border)
    f.sidebar = sidebar

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 20, -16)
    content:SetPoint("BOTTOMRIGHT", -20, 40)
    f.content = content

    local status = CreateFrame("Frame", nil, f, "BackdropTemplate")
    status:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    status:SetPoint("BOTTOMRIGHT", 0, 0)
    status:SetHeight(28)
    makeBackdrop(status, C.titleBar, C.border)
    status.text = label(status, "Ready", 11, C.muted, "LEFT", 14, 0)
    status.combat = label(status, "", 11, C.danger, "RIGHT", -14, 0)
    f.status = status

    self.pages = {}
    self.navButtons = {}

    local navGroups = {
        { title = "OVERVIEW", items = {
            { "dashboard", "Dashboard" }, { "general", "General" }, { "testmode", "Test Mode" },
        }},
        { title = "CURING", items = {
            { "curing", "Curing" }, { "bleeds", "Bleed Management" },
            { "bindings", "Spells & Bindings" }, { "filtering", "Affliction Filters" },
            { "lists", "Priority & Skip" },
        }},
        { title = "DISPLAY", items = {
            { "frames", "Micro Unit Frames" }, { "cooldowns", "Cooldowns" },
            { "range", "Range & Visibility" }, { "livelist", "Live List" },
        }},
        { title = "PROFILES", items = {
            { "profiles", "Profiles & Modes" }, { "sharing", "Import / Export" },
            { "integrations", "Detection" },
        }},
        { title = "SYSTEM", items = {
            { "sounds", "Sound Notifications" }, { "messages", "Messages" }, { "macro", "Macro" },
            { "compat121", "12.1 Status" }, { "diagnostics", "Diagnostics" },
            { "dispeldb", "Dispel Database" }, { "about", "About" },
        }},
    }
    self.navNames = {}
    for _, group in ipairs(navGroups) do for _, item in ipairs(group.items) do self.navNames[item[1]] = item[2] end end
    self:BuildSearchIndex(true)

    local navScroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", 4, -6)
    navScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local navChild = CreateFrame("Frame", nil, navScroll)
    navChild:SetWidth(160)
    navChild:SetHeight(760)
    navScroll:SetScrollChild(navChild)
    f.navScroll = navScroll

    local y = -4
    for _, group in ipairs(navGroups) do
        local head = label(navChild, group.title, 9, C.muted, "TOPLEFT", 10, y)
        head:SetWidth(148); head:SetJustifyH("LEFT")
        y = y - 18
        for _, item in ipairs(group.items) do
            local key, name = item[1], item[2]
            local b = CreateFrame("Button", nil, navChild, "BackdropTemplate")
            b:SetSize(156, 24)
            b:SetPoint("TOPLEFT", 4, y)
            makeBackdrop(b, C.panel, C.panel)
            b._pageKey = key
            b.accent = b:CreateTexture(nil, "ARTWORK")
            b.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
            b.accent:SetPoint("TOPLEFT", 0, 0)
            b.accent:SetPoint("BOTTOMLEFT", 0, 0)
            b.accent:SetWidth(3)
            b.accent:Hide()
            b.text = label(b, name, 11, C.text, "LEFT", 12, 0)
            b.text:SetJustifyH("LEFT")
            b:SetScript("OnEnter", function(btn)
                if ZD.currentPage ~= btn._pageKey then
                    btn:SetBackdropColor(C.hover[1], C.hover[2], C.hover[3], 1)
                    btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
                end
            end)
            b:SetScript("OnLeave", function(btn)
                if ZD.currentPage == btn._pageKey then
                    btn:SetBackdropColor(C.selected[1], C.selected[2], C.selected[3], 1)
                    btn:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], .55)
                else
                    btn:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
                    btn:SetBackdropBorderColor(C.panel[1], C.panel[2], C.panel[3], 1)
                end
            end)
            b:SetScript("OnClick", function(btn) self:ShowPage(btn._pageKey) end)
            self.navButtons[key] = b
            y = y - 26
        end
        y = y - 8
    end
    navChild:SetHeight(math.max(720, -y + 10))

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(18,18); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() if not InCombatLockdown() then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        if D.profile then D.profile.V11WindowWidth=f:GetWidth(); D.profile.V11WindowHeight=f:GetHeight() end
    end)
    f.resizeGrip = grip
    f:SetScript("OnSizeChanged", function(self,w,h)
        if self:IsShown() and D.profile and not InCombatLockdown() then
            D.profile.V11WindowWidth=math.floor(w+.5); D.profile.V11WindowHeight=math.floor(h+.5)
        end
    end)

    f:SetScript("OnShow", function()
        ZD:RefreshUI()
        ZD:ShowPage(ZD.currentPage or "dashboard")
    end)

    self:ShowPage("dashboard")
    return f
end

function ZD:SetNavActive(key)
    for k, b in pairs(self.navButtons or {}) do
        if k == key then
            b:SetBackdropColor(C.selected[1], C.selected[2], C.selected[3], 1)
            b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], .55)
            if b.accent then
                b.accent:SetWidth(4)
                b.accent:Show()
            end
            if b.text then b.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1) end
        else
            b:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
            b:SetBackdropBorderColor(C.panel[1], C.panel[2], C.panel[3], 1)
            if b.accent then b.accent:Hide() end
            if b.text then b.text:SetTextColor(C.text[1], C.text[2], C.text[3], 1) end
        end
    end
end

function ZD:PageTitle(page, title, subtitle)
    page.pageTitle = label(page, title, 18, C.text, "TOPLEFT", 0, 0)
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    rule:SetPoint("TOPLEFT", 0, -24)
    rule:SetSize(48, 2)
    page.pageSubtitle = label(page, subtitle or "", 11, C.muted, "TOPLEFT", 0, -34)
    page.pageSubtitle:SetPoint("RIGHT", 0, 0)
    page.pageSubtitle:SetJustifyH("LEFT")
end

function ZD:BuildDashboard(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Dashboard", "Lean combat core + on-demand settings. One panel for the full cure assistant.")

    local cards = {}
    local cardW = 205
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, p, "BackdropTemplate")
        c:SetSize(cardW, 96)
        c:SetPoint("TOPLEFT", (i - 1) * (cardW + 12), -72)
        makeBackdrop(c, C.card, C.border)
        local strip = c:CreateTexture(nil, "ARTWORK")
        strip:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        strip:SetPoint("TOPLEFT", 0, 0)
        strip:SetPoint("TOPRIGHT", 0, 0)
        strip:SetHeight(2)
        c.caption = label(c, "", 10, C.muted, "TOPLEFT", 14, -14)
        c.value = label(c, "", 15, C.text, "TOPLEFT", 14, -36)
        c.detail = label(c, "", 10, C.muted, "TOPLEFT", 14, -62)
        cards[i] = c
    end
    p.cards = cards

    local architecture = section(p, "How this build works", -186, 150)
    local lines = {
        "• Combat path stays resident: Blizzard-managed AuraContainers, secure MUFs, profiles.",
        "• Decursive uses native Blizzard-managed AuraContainers only for dispel detection.",
        "• Decursive_Options loads only when you open settings.",
        "• User profiles (AceDB) and environment modes (Open World / M+ / Raid…) stay separate.",
    }
    for i, text in ipairs(lines) do
        label(architecture, text, 11, i == 1 and C.accent or C.text, "TOPLEFT", 18, -38 - ((i - 1) * 24))
    end

    local actions = section(p, "Quick Actions", -374, 118)
    local b1 = button(actions, "Open Test Mode", 150, 30, function()
        ZD:ShowPage("testmode")
    end, "primary")
    b1:SetPoint("TOPLEFT", 18, -48)
    local b2 = button(actions, "Profiles & Modes", 160, 30, function() ZD:ShowPage("profiles") end)
    b2:SetPoint("LEFT", b1, "RIGHT", 12, 0)
    local b3 = button(actions, "All MUF Settings", 170, 30, function() ZD:ShowPage("frames") end)
    b3:SetPoint("LEFT", b2, "RIGHT", 12, 0)

    function p:Refresh()
        local profile = ZD:GetUserProfileName()
        local envKey, envName = ZD:GetActiveEnvironment()
        local className, specName = ZD:GetPlayerClassSpec()
        cards[1].caption:SetText("USER PROFILE")
        cards[1].value:SetText(profile)
        cards[1].detail:SetText("AceDB character setup")
        cards[2].caption:SetText("ENVIRONMENT")
        cards[2].value:SetText(envName or envKey)
        cards[2].detail:SetText(ZD:GetEnvironmentSetting() == "AUTO" and "Automatic detection" or "Manual override")
        cards[3].caption:SetText("CHARACTER")
        cards[3].value:SetText(specName)
        cards[3].detail:SetText(className .. " • managed aura mode")
    end
    p:Refresh()
    return p
end

function ZD:BuildFrames(parent)
    local skipDisplay = {
        Environment121Mode=true, Environment121ActiveProfile=true, Detection121Mode=true,
        SecondaryAffliction121Enabled=true, SecondaryAffliction121Pulse=true,
        SharedPriorityCooldown121Enabled=true, ClearCleansedTarget121Enabled=true,
        EnvironmentChat121Enabled=true, ProfileBehaviorHint121=true, ResetEnvironment121Profile=true,
        OutOfRange121Enabled=true, OutOfRange121DimAmount=true, OutOfRange121Color=true,
        ResetOutOfRange121Color=true, CooldownOverlay121Enabled=true, CooldownOverlay121Opacity=true,
        CooldownOverlay121Numbers=true, CooldownPriority2Border121Enabled=true,
        CooldownBorder121Alpha=true, CooldownBorder121Thickness=true,
        CooldownPriority2Pulse121Enabled=true, StatusLight121Enabled=true, Test121MUFSelect=true,
        Test121MUFVisualsOne=true, Test121MUFVisualsAll=true,
    }
    local p = self:BuildTabbedOptionPathPage(parent, "Micro Unit Frames",
        "MUF settings are separated by purpose. Party and Raid can use different MUF sizes, large raids can auto-reflow into a compact grid. Optional status lights sit above each square (yellow range, red fail, green success); turning them off restores the original tighter party/raid spacing.", {
            {key="layout", name="Layout & Display", path={"MicroFrameOpt","displayOpts"}, skipKeys=skipDisplay, width=145},
            {key="spacing", name="Spacing & Opacity", path={"MicroFrameOpt","AdvDispOptions"}, width=155},
            {key="colors", name="Colors", path={"MicroFrameOpt","MUFsColors"}, width=105},
            {key="performance", name="Performance", path={"MicroFrameOpt","PerfOptions"}, width=120},
        }, "layout")

    local basics = section(p, "Frame Basics", -146, 138)
    p.basicShow = switch(basics, "Show MUFs", -34,
        function() return D.profile and D.profile.ShowDebuffsFrame end,
        function(v) ZD:SetProfileOption("ShowDebuffsFrame", v) end)
    p.basicLock = switch(basics, "Lock position", -68,
        function() return D.profile and D.profile.HideMUFsHandle end,
        function(v) ZD:SetProfileOption("HideMUFsHandle", v) end)
    p.basicStatusLight = switch(basics, "Status indicator light", -102,
        function() return D.profile and D.profile.StatusLight121Enabled == true end,
        function(v)
            if D.Set121MUFStatusLightEnabled then
                D:Set121MUFStatusLightEnabled(v)
            else
                ZD:SetProfileOption("StatusLight121Enabled", v)
            end
        end,
        "Small circle above each MUF for range/fail/success. Off hides the light and restores pre-status-light party/raid spacing.")

    -- MUF size was previously unreachable from the UI: the underlying
    -- DebuffsFrameElemScale option is marked hidden/guiHidden in the classic
    -- Dcr_opt.lua tree (for the old options panel), and this page's "Layout &
    -- Display" tab auto-generates its controls from that same tree, so it
    -- inherited the hidden flag too -- even though this page's own intro
    -- text already promised "Party and Raid can use different MUF sizes."
    -- Built as a dedicated section using ZD:Get/SetPartyMUFSizePixels and
    -- ZD:Get/SetRaidMUFSizePixels (Modern/ZD_Core.lua), which already existed
    -- and worked, just had no control wired to them anywhere.
    local sizeSection = section(p, "MUF Size", -260, 176)
    p.partySize = slider(sizeSection, "Party MUF size (px)", -34, 10, 80, 1,
        function() return ZD:GetPartyMUFSizePixels() end,
        function(v) ZD:SetPartyMUFSizePixels(v) end, "px")
    p.raidSize = slider(sizeSection, "Raid MUF size (px)", -92, 10, 80, 1,
        function() return ZD:GetRaidMUFSizePixels() end,
        function(v) ZD:SetRaidMUFSizePixels(v) end, "px")

    p.optionScroll:ClearAllPoints(); p.optionScroll:SetPoint("TOPLEFT",0,-480); p.optionScroll:SetPoint("BOTTOMRIGHT",-22,0)
    local oldRefresh=p.Refresh
    function p:Refresh()
        if p.basicShow and p.basicShow.control then p.basicShow.control:Refresh() end
        if p.basicLock and p.basicLock.control then p.basicLock.control:Refresh() end
        if p.basicStatusLight and p.basicStatusLight.control then p.basicStatusLight.control:Refresh() end
        if p.partySize and p.partySize.control then p.partySize.control:Refresh() end
        if p.raidSize and p.raidSize.control then p.raidSize.control:Refresh() end
        if oldRefresh then oldRefresh(self) end
    end
    return p
end

function ZD:BuildCuring(parent)
    return self:BuildOptionGroupPage(parent, "CureOptions", "Curing",
        "Core cure behavior and cure priorities. Bleed discovery/management now has its own page.", { BleedEffects = true })
end

function ZD:BuildBleeds(parent)
    return self:BuildTabbedOptionPathPage(parent, "Bleed Management",
        "Manage bleed discovery separately from normal Magic/Poison/Disease/Curse curing.", {
            {key="discovery", name="Discovery & Keywords", path={"CureOptions","BleedEffects"}, skipKeys={knownBleedingEffects=true}, width=170},
            {key="known", name="Known Bleed Effects", path={"CureOptions","BleedEffects","knownBleedingEffects"}, width=170},
        }, "discovery")
end

function ZD:BuildCooldowns(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Cooldowns", "Cooldown feedback is separate from range and visibility feedback.")
    local envCycleValues=function()
        local out={}
        for _,key in ipairs(ZD.environmentOrder) do out[#out+1]={key=key,name=ZD.environmentNames[key]} end
        return out
    end
    p.editEnv=cycleButton(p,"Editing behavior",-68,envCycleValues,function() return ZD:GetEditEnvironment() end,function(key) ZD:SetEditEnvironment(key) end)
    local visual=section(p,"Remaining-target Cooldown Feedback",-112,300)
    p.overlay=switch(visual,"Cooldown overlay on remaining targets",-44,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.CooldownOverlay121Enabled~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"CooldownOverlay121Enabled",v) end)
    p.numbers=switch(visual,"Countdown numbers",-82,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.CooldownOverlay121Numbers~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"CooldownOverlay121Numbers",v) end)
    p.opacity=slider(visual,"Overlay opacity",-126,.10,1,.05,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.CooldownOverlay121Opacity or .62 end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"CooldownOverlay121Opacity",v) end,nil,true)
    p.shared=switch(visual,"Show cooldown on other active targets",-188,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.SharedPriorityCooldown121Enabled==true end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"SharedPriorityCooldown121Enabled",v) end)
    p.secondary=switch(visual,"Secondary-affliction border",-226,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.SecondaryAffliction121Enabled~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"SecondaryAffliction121Enabled",v) end)
    p.pulse=switch(visual,"Pulse secondary border",-264,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.SecondaryAffliction121Pulse~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"SecondaryAffliction121Pulse",v) end)
    local reset=button(p,"Reset this behavior",160,30,function() ZD:ResetEnvironmentProfile(ZD:GetEditEnvironment()) end)
    reset:SetPoint("TOPLEFT",0,-428)
    function p:Refresh()
        p.editEnv.control:Refresh(); p.overlay.control:Refresh(); p.numbers.control:Refresh(); p.opacity.control:Refresh()
        p.shared.control:Refresh(); p.secondary.control:Refresh(); p.pulse.control:Refresh()
    end
    return p
end

function ZD:BuildRangeVisibility(parent)
    local p=pageFrame(parent)
    self:PageTitle(p,"Range & Visibility","Range is continuously evaluated when public. Line of sight is marked only after your cleanse fails for LoS.")
    local envCycleValues=function()
        local out={}
        for _,key in ipairs(ZD.environmentOrder) do out[#out+1]={key=key,name=ZD.environmentNames[key]} end
        return out
    end
    p.editEnv=cycleButton(p,"Editing behavior",-68,envCycleValues,function() return ZD:GetEditEnvironment() end,function(key) ZD:SetEditEnvironment(key) end)

    local range=section(p,"Out of Range",-112,220)
    p.rangeEnabled=switch(range,"Dim out-of-range units",-42,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.OutOfRange121Enabled~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"OutOfRange121Enabled",v) end,
        "Uses your configured friendly cure spells when their range result is publicly accessible.")
    p.rangeDim=slider(range,"Range overlay opacity",-104,.10,1,.05,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.OutOfRange121DimAmount or .60 end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"OutOfRange121DimAmount",v) end,nil,true)
    p.rangeColor=colorPickerRow(range,"Out-of-range color",-170,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.OutOfRange121Color or {1,1,0} end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"OutOfRange121Color",v) end)

    local los=section(p,"Line of Sight",-348,266)
    p.losEnabled=switch(los,"Show failed line-of-sight state",-42,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.LineOfSight121Enabled~=false end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"LineOfSight121Enabled",v) end,
        "Triggered only after your own cleanse receives WoW's line-of-sight failure. It does not guess LoS from range.")
    p.losColor=colorPickerRow(los,"Line-of-sight color",-104,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.LineOfSight121Color or {1,.28,.12} end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"LineOfSight121Color",v) end)
    p.losOpacity=slider(los,"LoS overlay opacity",-148,.20,1,.05,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.LineOfSight121Opacity or .78 end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"LineOfSight121Opacity",v) end,nil,true)
    p.losHold=slider(los,"LoS indicator hold time",-208,.5,8,.5,
        function() local e=ZD:GetEnvironmentProfile(); return e and e.LineOfSight121HoldSeconds or 2.5 end,
        function(v) ZD:SetEnvironmentValue(ZD:GetEditEnvironment(),"LineOfSight121HoldSeconds",v) end," sec")
    function p:Refresh()
        p.editEnv.control:Refresh(); p.rangeEnabled.control:Refresh(); p.rangeDim.control:Refresh(); p.rangeColor:Refresh()
        p.losEnabled.control:Refresh(); p.losColor:Refresh(); p.losOpacity.control:Refresh(); p.losHold.control:Refresh()
    end
    return p
end

function ZD:BuildProfiles(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Profiles & Modes", "Two layers: your AceDB user profile holds everything; environment modes swap behavior blocks inside it.")

    local callout = section(p, "Do not confuse these", -66, 78)
    local calloutText = label(callout, "User profile = which saved setup is active (Default, Healer, etc.).  Environment = Open World / M+ / Raid / PvP behavior inside that profile.", 11, C.text, "TOPLEFT", 18, -40)
    calloutText:SetWidth(620)

    local function profileValues()
        local out = {}
        for _, name in ipairs(ZD:GetProfiles()) do out[#out + 1] = { key = name, name = name } end
        if #out == 0 then out[1] = { key = ZD:GetUserProfileName(), name = ZD:GetUserProfileName() } end
        return out
    end
    p.profileCycle = cycleButton(p, "User profile", -158, profileValues,
        function() return ZD:GetUserProfileName() end,
        function(name) ZD:SetUserProfile(name) end)

    local user = section(p, "Profile Management", -202, 172)
    user.nameBox = editBox(user, 270, 36, false)
    user.nameBox:SetPoint("TOPLEFT", 18, -48)
    user.nameBox.edit:SetText("")
    local create = button(user, "Create / Switch", 140, 30, function()
        ZD:CreateUserProfile(user.nameBox.edit:GetText())
        user.nameBox.edit:SetText("")
    end, "primary")
    create:SetPoint("LEFT", user.nameBox, "RIGHT", 12, 0)
    local copy = button(user, "Copy Current", 130, 30, function()
        ZD:CloneCurrentProfile(user.nameBox.edit:GetText())
        user.nameBox.edit:SetText("")
    end)
    copy:SetPoint("TOPLEFT", 18, -100)
    local reset = button(user, "Reset Current", 130, 30, function() ZD:ResetUserProfile() end, "danger")
    reset:SetPoint("LEFT", copy, "RIGHT", 12, 0)
    label(user, "Tip: Import / Export is safer for explicit sharing between characters.", 10, C.muted, "BOTTOMLEFT", 18, 12)

    local modeValues = function()
        return {
            { key = "AUTO", name = "Automatic" },
            { key = "OPEN_WORLD", name = "Open World" },
            { key = "DUNGEON", name = "Dungeon / Follower" },
            { key = "MYTHIC_PLUS", name = "Mythic+" },
            { key = "RAID", name = "Raid" },
            { key = "PVP", name = "PvP" },
        }
    end
    local behavior = section(p, "Environment Mode", -388, 176)
    p.modeCycle = cycleButton(behavior, "Mode selection", -46, modeValues,
        function() return ZD:GetEnvironmentSetting() end,
        function(key) ZD:SetEnvironmentSetting(key) end)
    p.modeCycle:ClearAllPoints()
    p.modeCycle:SetPoint("TOPLEFT", 16, -46)
    p.modeCycle:SetPoint("TOPRIGHT", -16, -46)
    p.activeText = label(behavior, "", 12, C.accent, "TOPLEFT", 18, -96)
    p.modeHelp = label(behavior, "", 10, C.muted, "TOPLEFT", 18, -122)
    p.modeHelp:SetWidth(600)

    function p:Refresh()
        p.profileCycle.control:Refresh()
        p.modeCycle.control:Refresh()
        local _, envName = ZD:GetActiveEnvironment()
        p.activeText:SetText("Currently active: " .. tostring(envName))
        p.modeHelp:SetText("Automatic mode distinguishes Open World, normal/follower dungeons, Mythic+, Raid and PvP without changing your user profile.")
    end
    return p
end

function ZD:BuildSharing(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Import / Export", "Share only the active AceDB user profile, including its environment behavior blocks.")

    local export = section(p, "Export", -66, 206)
    export.box = editBox(export, 598, 105, true)
    export.box:SetPoint("TOPLEFT", 18, -44)
    local generate = button(export, "Generate Export", 150, 28, function()
        local text = D.GetProfileExportString and D:GetProfileExportString() or ""
        export.box.edit:SetText(text or "")
        export.box.edit:HighlightText()
        export.box.edit:SetFocus()
        ZD:SetStatus("Export generated. Press Ctrl+C to copy it.")
    end, "primary")
    generate:SetPoint("BOTTOMLEFT", 18, 14)

    local import = section(p, "Import", -286, 224)
    import.box = editBox(import, 598, 112, true)
    import.box:SetPoint("TOPLEFT", 18, -44)
    local importBtn = button(import, "Import Into Current Profile", 220, 28, function()
        if not ZD:CanConfigure() then return end
        if D.ImportProfileString then
            local ok = D:ImportProfileString(import.box.edit:GetText())
            if ok then
                import.box.edit:SetText("")
                ZD:SetStatus("Profile imported successfully.")
            else
                ZD:SetStatus(D.GetProfileIOStatus and D:GetProfileIOStatus() or "Import failed.", true)
            end
        end
    end, "primary")
    importBtn:SetPoint("BOTTOMLEFT", 18, 14)
    label(import, "Import replaces settings in the active user profile. Global and class-scoped data remain untouched.", 10, C.muted, "BOTTOMLEFT", 254, 20)

    function p:Refresh() end
    return p
end

function ZD:BuildLists(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Priority & Skip Lists", "Manage, reorder and remove units here. The old standalone list windows are no longer used.")

    local function move(kind, index, destination)
        if not ZD:CanConfigure() then return end
        local list = kind == "priority" and D.profile.PriorityList or D.profile.SkipList
        if not list or not list[index] then return end
        local count = #list
        local newIndex = index
        if destination == "up" then newIndex = math.max(1, index - 1)
        elseif destination == "down" then newIndex = math.min(count, index + 1)
        elseif destination == "top" then newIndex = 1
        elseif destination == "bottom" then newIndex = count end
        if newIndex ~= index then
            local value = table.remove(list, index)
            table.insert(list, newIndex, value)
            D.Status.PrioChanged = true
            D:GroupChanged("v11 list reorder")
            ZD:SetStatus((kind == "priority" and "Priority" or "Skip") .. " list reordered.")
        end
        p:Refresh()
    end

    local function listName(kind, value)
        if value == "player" then return DC.MyName or UnitName("player") or "player" end
        local names = kind == "priority" and D.profile.PrioGUIDtoNAME or D.profile.SkipGUIDtoNAME
        return (names and names[value]) or tostring(value)
    end

    local function buildListCard(titleText, kind, x)
        local card = CreateFrame("Frame", nil, p, "BackdropTemplate")
        card:SetPoint("TOPLEFT", x, -66)
        card:SetSize(318, 474)
        makeBackdrop(card, C.card, C.border)
        label(card, titleText, 14, C.text, "TOPLEFT", 14, -14)

        local add = button(card, "Add Target", 108, 28, function()
            if not ZD:CanConfigure() then return end
            local ok = kind == "priority" and D:AddTargetToPriorityList() or D:AddTargetToSkipList()
            ZD:SetStatus(ok and ("Target added to " .. kind .. " list.") or "Target could not be added.", not ok)
            p:Refresh()
        end, "primary")
        add:SetPoint("TOPLEFT", 14, -42)
        local clear = button(card, "Clear", 78, 28, function()
            if not ZD:CanConfigure() then return end
            showConfirm("Clear the entire " .. titleText .. "?", function()
                if kind == "priority" then D:ClearPriorityList() else D:ClearSkipList() end
                ZD:SetStatus(titleText .. " cleared.")
                p:Refresh()
            end)
        end, "danger")
        clear:SetPoint("LEFT", add, "RIGHT", 8, 0)

        -- Role-based priority: mixes freely with individual "Add Target"
        -- entries in the same list (raiding tends to want specific people
        -- pinned; dungeons tend to want "tanks/healers first" in general) --
        -- see D:AddRoleToPriorityList in Dcr_lists.lua. Priority list only;
        -- skipping by whole role isn't part of this request.
        local scrollTopOffset = -82
        if kind == "priority" then
            local function roleButton(roleName, roleLabel, xOffset)
                local b = button(card, roleLabel, 90, 26, function()
                    if not ZD:CanConfigure() then return end
                    local ok = D:AddRoleToPriorityList(roleName)
                    ZD:SetStatus(ok and (roleLabel .. " added to priority list.") or (roleLabel .. " could not be added (already in list?)."), not ok)
                    p:Refresh()
                end)
                b:SetPoint("TOPLEFT", xOffset, -74)
            end
            roleButton("TANK", "Tank", 14)
            roleButton("HEALER", "Healer", 108)
            roleButton("DAMAGER", "DPS", 202)
            scrollTopOffset = -108
        end

        local scroll = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, scrollTopOffset)
        scroll:SetPoint("BOTTOMRIGHT", -28, 12)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetWidth(270); child:SetHeight(1)
        scroll:SetScrollChild(child)
        card.listChild = child
        card.rows = {}
        card.kind = kind
        return card
    end

    p.priorityCard = buildListCard("Priority List", "priority", 0)
    p.skipCard = buildListCard("Skip List", "skip", 330)

    local function rebuildCard(card)
        for _, row in ipairs(card.rows) do row:Hide() end
        card.rows = {}
        local list = card.kind == "priority" and D.profile.PriorityList or D.profile.SkipList
        list = list or {}
        local y = -2
        for i, value in ipairs(list) do
            local row = CreateFrame("Frame", nil, card.listChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 0, y); row:SetSize(266, 36)
            makeBackdrop(row, C.panel, C.border)
            local nm = label(row, format("%d. %s", i, listName(card.kind, value)), 10, C.text, "LEFT", 8, 0)
            nm:SetWidth(100); nm:SetJustifyH("LEFT")
            -- Plain ASCII labels (UTF-8 arrows were corrupted to mojibake in this file).
            local up = button(row, "Up", 28, 24, function() move(card.kind, i, "up") end); up:SetPoint("LEFT", 112, 0)
            local down = button(row, "Dn", 28, 24, function() move(card.kind, i, "down") end); down:SetPoint("LEFT", 142, 0)
            local top = button(row, "Top", 32, 24, function() move(card.kind, i, "top") end); top:SetPoint("LEFT", 172, 0)
            local bottom = button(row, "End", 32, 24, function() move(card.kind, i, "bottom") end); bottom:SetPoint("LEFT", 206, 0)
            local remove = button(row, "X", 22, 24, function()
                if not ZD:CanConfigure() then return end
                if card.kind == "priority" then D:RemoveIDFromPriorityList(i) else D:RemoveIDFromSkipList(i) end
                ZD:SetStatus("List entry removed.")
                p:Refresh()
            end, "danger"); remove:SetPoint("LEFT", 240, 0)
            card.rows[#card.rows + 1] = row
            y = y - 40
        end
        if #list == 0 then
            local empty = CreateFrame("Frame", nil, card.listChild)
            empty:SetPoint("TOPLEFT", 0, -8); empty:SetSize(266, 40)
            label(empty, "No units in this list.", 11, C.muted, "CENTER", 0, 0)
            card.rows[#card.rows + 1] = empty
            y = -54
        end
        card.listChild:SetHeight(math.max(360, -y + 8))
    end

    function p:Refresh()
        rebuildCard(p.priorityCard)
        rebuildCard(p.skipCard)
    end
    p:Refresh()
    return p
end

function ZD:BuildBindings(parent)
    local p = makeOptionScrollPage(parent)
    self:PageTitle(p, "Spells & Mouse Bindings", "Configure cure spells and secure MUF mouse assignments without leaving the v11 interface.")
    p.optionScroll:ClearAllPoints()
    p.optionScroll:SetPoint("TOPLEFT", 0, -62)
    p.optionScroll:SetPoint("BOTTOMRIGHT", -22, 0)
    p.expandedSpellID = nil

    local function clearDynamic()
        hideRendered(p)
    end

    local function getModel()
        local ok, model = pcall(D.GetV11OptionsTable, D)
        if not ok or type(model) ~= "table" or type(model.args) ~= "table" then return nil end
        local group = model.args.CustomSpells
        if type(group) ~= "table" or type(group.args) ~= "table" then return nil end
        return model, group
    end

    local function buildInfo(path, option, handler)
        return optionInfo(path, option, handler)
    end

    local function runSet(model, group, option, path, value, ...)
        if not ZD:CanConfigure() then return false end
        if type(option) ~= "table" then return false end
        local handler = option.handler or group.handler or model.handler
        local info = buildInfo(path, option, handler)
        if option.validate then
            local ok, validation = invokeOption(option.validate, handler, info, value)
            if not ok then
                ZD:SetStatus("Validation failed: " .. tostring(validation), true)
                return false
            end
            if validation ~= true and validation ~= 0 then
                ZD:SetStatus(type(validation) == "string" and validation or "That value is not valid.", true)
                return false
            end
        end
        local setSpec = option.set or group.set or model.set
        local ok, err = invokeOption(setSpec, handler, info, value, ...)
        if not ok then
            ZD:SetStatus("Could not change setting: " .. tostring(err), true)
            return false
        end
        ZD:SetStatus("Setting updated.")
        return true
    end

    local function runGet(model, group, option, path, ...)
        if type(option) ~= "table" then return nil end
        local handler = option.handler or group.handler or model.handler
        local info = buildInfo(path, option, handler)
        local getSpec = option.get or group.get or model.get
        local ok, value = invokeOption(getSpec, handler, info, ...)
        if not ok then return nil end
        return value
    end

    local function runExecute(model, group, option, path)
        if not ZD:CanConfigure() then return false end
        if type(option) ~= "table" or not option.func then return false end
        local handler = option.handler or group.handler or model.handler
        local info = buildInfo(path, option, handler)
        local ok, err = invokeOption(option.func, handler, info)
        if not ok then
            ZD:SetStatus("Action failed: " .. tostring(err), true)
            return false
        end
        ZD:SetStatus("Action completed.")
        return true
    end

    local function spellDisplayName(spellID)
        local name = D.GetSpellOrItemInfo and D.GetSpellOrItemInfo(spellID)
        if not name or name == "" then name = "Unknown spell / item" end
        return name
    end

    local function mouseReadable(code)
        return (DC.MouseButtonsReadable and DC.MouseButtonsReadable[code]) or tostring(code or "Unassigned")
    end

    local function showChoicePopup(anchor, items, selectedKey, onSelect)
        if ZD._choicePopup then ZD._choicePopup:Hide() end
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetFrameStrata("TOOLTIP")
        popup:SetFrameLevel(500)
        popup:SetSize(270, math.min(430, 18 + (#items * 27)))
        popup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
        popup:SetClampedToScreen(true)
        makeBackdrop(popup, C.bg, C.border)
        ZD._choicePopup = popup

        local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetWidth(226)
        child:SetHeight(math.max(1, #items * 27))
        scroll:SetScrollChild(child)

        local y = 0
        for _, item in ipairs(items) do
            local choice = button(child, item.name, 222, 24, function()
                popup:Hide()
                if onSelect then onSelect(item.key) end
            end, item.key == selectedKey and "primary" or nil)
            choice:SetPoint("TOPLEFT", 0, -y)
            choice.text:SetJustifyH("LEFT")
            choice.text:ClearAllPoints()
            choice.text:SetPoint("LEFT", 8, 0)
            y = y + 27
        end
        popup:SetScript("OnHide", function(self)
            if ZD._choicePopup == self then ZD._choicePopup = nil end
        end)
    end

    local function compactToggle(parentFrame, x, y, width, text, getter, setter)
        local b = button(parentFrame, "", width, 28, nil)
        b:SetPoint("TOPLEFT", x, y)
        b.title = text
        function b:Refresh()
            local on = getter and getter() and true or false
            self.on = on
            self:SetLabel((on and "âœ“  " or "â—‹  ") .. text)
            if on then
                self:SetBackdropColor(C.accent[1] * .45, C.accent[2] * .45, C.accent[3] * .45, 1)
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
            else
                self:SetBackdropColor(C.card[1], C.card[2], C.card[3], C.card[4])
                self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end
            self.text:SetJustifyH("LEFT")
            self.text:ClearAllPoints()
            self.text:SetPoint("LEFT", 9, 0)
        end
        b:SetScript("OnClick", function(self)
            if not ZD:CanConfigure() then return end
            if setter then setter(not self.on) end
            self:Refresh()
        end)
        b:Refresh()
        return b
    end

    local function assignmentSummary()
        local lines = {}
        local byPriority = {}
        for spellName, prio in pairs((D.Status and D.Status.CuringSpellsPrio) or {}) do
            if type(prio) == "number" then byPriority[prio] = spellName end
        end
        for prio = 1, 7 do
            local spellName = byPriority[prio]
            if spellName then
                local types = {}
                for _, afflictionType in ipairs((D.Status and D.Status.ReversedCureOrder) or {}) do
                    if D.Status.CuringSpells and D.Status.CuringSpells[afflictionType] == spellName then
                        local locKey = DC.TypeToLocalizableTypeNames and DC.TypeToLocalizableTypeNames[afflictionType]
                        types[#types + 1] = (D.L and locKey and D.L[locKey]) or (DC.TypeNames and DC.TypeNames[afflictionType]) or tostring(afflictionType)
                    end
                end
                local click = D.db and D.db.global and D.db.global.MouseButtons and mouseReadable(D.db.global.MouseButtons[prio]) or "Unassigned"
                lines[#lines + 1] = format("Priority %d  â€¢  %s  â€¢  %s  â†’  %s", prio, table.concat(types, " / "), click, spellName)
            end
        end
        if #lines == 0 then lines[1] = "No active cure assignments are currently available for this class/spec." end
        return lines
    end

    local function typeEntries()
        local ordered, seen = {}, {}
        for _, afflictionType in ipairs((D.Status and D.Status.ReversedCureOrder) or {}) do
            local locKey = DC.TypeToLocalizableTypeNames and DC.TypeToLocalizableTypeNames[afflictionType]
            if locKey and not seen[locKey] then
                seen[locKey] = true
                ordered[#ordered + 1] = { key = locKey, type = afflictionType, name = (D.L and D.L[locKey]) or (DC.TypeNames and DC.TypeNames[afflictionType]) or locKey }
            end
        end
        for locKey, afflictionType in pairs(DC.LocalizableTypeNamesToTypes or {}) do
            if not seen[locKey] then
                seen[locKey] = true
                ordered[#ordered + 1] = { key = locKey, type = afflictionType, name = (D.L and D.L[locKey]) or (DC.TypeNames and DC.TypeNames[afflictionType]) or locKey }
            end
        end
        return ordered
    end

    function p:Rebuild()
        clearDynamic()
        local model, group = getModel()
        if not model then
            local err = trackRendered(p, label(p.optionCanvas, "The spell/binding configuration model is unavailable.", 12, C.danger, "TOPLEFT", 8, -8))
            err:SetWidth(620)
            p.optionCanvas:SetHeight(90)
            return
        end

        local y = -8

        -- Active assignment summary -------------------------------------------------
        local summary = trackRendered(p, CreateFrame("Frame", nil, p.optionCanvas, "BackdropTemplate"))
        summary:SetPoint("TOPLEFT", 0, y)
        summary:SetPoint("TOPRIGHT", -8, y)
        local summaryLines = assignmentSummary()
        local summaryHeight = 72 + (#summaryLines * 21)
        summary:SetHeight(summaryHeight)
        makeBackdrop(summary, C.card, C.border)
        label(summary, "Active Cure Assignments", 14, C.text, "TOPLEFT", 16, -14)
        label(summary, "What each cure priority currently does on your character.", 10, C.muted, "TOPLEFT", 16, -36)
        for i, lineText in ipairs(summaryLines) do
            local fs = label(summary, lineText, 10, i == 1 and C.accent or C.text, "TOPLEFT", 18, -58 - ((i - 1) * 21))
            fs:SetWidth(590)
            fs:SetJustifyH("LEFT")
        end
        if D.Get121CooldownDispelSpell then
            local id, name = D:Get121CooldownDispelSpell()
            local detected = label(summary, id and ("12.1 cooldown dispel: " .. tostring(name or "Unknown") .. " (" .. tostring(id) .. ")") or "12.1 cooldown dispel: None", 10, id and C.accent or C.danger, "BOTTOMLEFT", 18, 12)
            detected:SetWidth(590)
        end
        y = y - summaryHeight - 12

        -- Mouse assignments ---------------------------------------------------------
        local mouseCard = trackRendered(p, CreateFrame("Frame", nil, p.optionCanvas, "BackdropTemplate"))
        mouseCard:SetPoint("TOPLEFT", 0, y)
        mouseCard:SetPoint("TOPRIGHT", -8, y)
        mouseCard:SetHeight(390)
        makeBackdrop(mouseCard, C.card, C.border)
        label(mouseCard, "Secure MUF Mouse Assignments", 14, C.text, "TOPLEFT", 16, -14)
        local mouseDesc = label(mouseCard, "Choose which mouse/modifier combination activates each cure priority. Selecting an in-use combo swaps the two assignments, preventing duplicate secure bindings.", 10, C.muted, "TOPLEFT", 16, -36)
        mouseDesc:SetWidth(470); mouseDesc:SetJustifyH("LEFT"); mouseDesc:SetWordWrap(true)

        local resetMouse = button(mouseCard, "Reset Bindings", 118, 28, function()
            if not ZD:CanConfigure() then return end
            showConfirm("Reset all MUF mouse assignments to their defaults?", function()
                local opt = group.args.MouseBindings and group.args.MouseBindings.args and group.args.MouseBindings.args.ResetClicksAdssigments
                if opt and runExecute(model, group, opt, { "CustomSpells", "MouseBindings", "ResetClicksAdssigments" }) then p:Rebuild() end
            end)
        end, "danger")
        resetMouse:SetPoint("TOPRIGHT", -16, -14)

        local mouseButtons = (D.db and D.db.global and D.db.global.MouseButtons) or {}
        local mouseChoices = {}
        for i, code in ipairs(mouseButtons) do mouseChoices[#mouseChoices + 1] = { key = i, name = mouseReadable(code) } end
        local bindingRows = { 1, 2, 3, 4, 5, 6, 7, math.max(1, #mouseButtons - 1), #mouseButtons }
        local seenRows = {}
        local rowY = -88
        for _, comboIndex in ipairs(bindingRows) do
            if comboIndex > 0 and mouseButtons[comboIndex] and not seenRows[comboIndex] then
                seenRows[comboIndex] = true
                local row = trackRendered(p, CreateFrame("Frame", nil, mouseCard))
                row:SetPoint("TOPLEFT", 16, rowY)
                row:SetPoint("TOPRIGHT", -16, rowY)
                row:SetHeight(30)
                local actionName
                if comboIndex <= 7 then actionName = "Priority " .. comboIndex
                elseif comboIndex == #mouseButtons - 1 then actionName = "Target unit"
                else actionName = "Focus unit" end
                label(row, actionName, 11, C.text, "LEFT", 0, 0)
                local pick = button(row, mouseReadable(mouseButtons[comboIndex]), 246, 26, nil)
                pick:SetPoint("RIGHT", 0, 0)
                pick.text:SetJustifyH("LEFT"); pick.text:ClearAllPoints(); pick.text:SetPoint("LEFT", 9, 0)
                pick:SetScript("OnClick", function(self)
                    if not ZD:CanConfigure() then return end
                    showChoicePopup(self, mouseChoices, comboIndex, function(choiceIndex)
                        if choiceIndex == comboIndex then return end
                        local opt = group.args.MouseBindings and group.args.MouseBindings.args and group.args.MouseBindings.args["KeyCombo" .. comboIndex]
                        if opt and runSet(model, group, opt, { "CustomSpells", "MouseBindings", "KeyCombo" .. comboIndex }, choiceIndex) then
                            p:Rebuild()
                        end
                    end)
                end)
                rowY = rowY - 32
            end
        end
        y = y - mouseCard:GetHeight() - 12

        -- Add spell -----------------------------------------------------------------
        local addCard = trackRendered(p, CreateFrame("Frame", nil, p.optionCanvas, "BackdropTemplate"))
        addCard:SetPoint("TOPLEFT", 0, y)
        addCard:SetPoint("TOPRIGHT", -8, y)
        addCard:SetHeight(150)
        makeBackdrop(addCard, C.card, C.border)
        label(addCard, "Add a Custom Spell or Item", 14, C.text, "TOPLEFT", 16, -14)
        local addDesc = label(addCard, "Enter a spell name, spell ID or usable item. Decursive validates it with the existing cure engine before adding it.", 10, C.muted, "TOPLEFT", 16, -37)
        addDesc:SetWidth(590); addDesc:SetJustifyH("LEFT")
        local addBox = editBox(addCard, 455, 34, false)
        addBox:SetPoint("TOPLEFT", 16, -64)
        local addButton = button(addCard, "Add", 112, 34, function()
            local value = addBox.edit:GetText() or ""
            local opt = group.args.AddCustomSpell
            if opt and runSet(model, group, opt, { "CustomSpells", "AddCustomSpell" }, value) then
                addBox.edit:SetText("")
                p:Rebuild()
            end
        end, "primary")
        addButton:SetPoint("LEFT", addBox, "RIGHT", 10, 0)
        addBox.edit:SetScript("OnEnterPressed", function(self)
            addButton:Click()
            self:ClearFocus()
        end)
        local macroOpt = group.args.IsMacro
        local macroToggle = compactToggle(addCard, 16, -108, 270, "Create editable internal macro", function()
            return macroOpt and runGet(model, group, macroOpt, { "CustomSpells", "IsMacro" })
        end, function(v)
            if macroOpt then runSet(model, group, macroOpt, { "CustomSpells", "IsMacro" }, v) end
        end)
        attachTooltip(macroToggle, "Editable internal macro", "For advanced users: when adding a spell, create Decursive's internal macro text so it can be customized. The macro must continue to contain UNITID.")
        y = y - addCard:GetHeight() - 12

        -- Existing spells ------------------------------------------------------------
        local spellIDs = {}
        for spellID, spellData in pairs((D.classprofile and D.classprofile.UserSpells) or {}) do
            if type(spellID) == "number" and type(spellData) == "table" and not spellData.Hidden then spellIDs[#spellIDs + 1] = spellID end
        end
        table.sort(spellIDs, function(a, b)
            local an, bn = spellDisplayName(a), spellDisplayName(b)
            if an == bn then return a < b end
            return an < bn
        end)

        local spellHeading = trackRendered(p, label(p.optionCanvas, "Configured Cure Spells / Items", 14, C.text, "TOPLEFT", 4, y))
        local spellCount = trackRendered(p, label(p.optionCanvas, tostring(#spellIDs) .. " configured", 10, C.muted, "TOPRIGHT", -12, y - 2))
        y = y - 28

        if #spellIDs == 0 then
            local empty = trackRendered(p, CreateFrame("Frame", nil, p.optionCanvas, "BackdropTemplate"))
            empty:SetPoint("TOPLEFT", 0, y); empty:SetPoint("TOPRIGHT", -8, y); empty:SetHeight(70)
            makeBackdrop(empty, C.card, C.border)
            label(empty, "No custom cure spells are configured for this class.", 11, C.muted, "CENTER", 0, 0)
            y = y - 82
        end

        local typeList = typeEntries()
        for _, spellID in ipairs(spellIDs) do
            local spellData = D.classprofile.UserSpells[spellID]
            local holder = group.args.CustomSpellsHolder
            local spellGroup = holder and holder.args and holder.args[tostring(spellID)]
            local expanded = p.expandedSpellID == spellID
            local hasMacro = spellData and spellData.MacroText ~= nil
            local enabledTypeCount = 0
            for _, typeEntry in ipairs(typeList) do
                if D:tcheckforval(spellData.Types or {}, typeEntry.type) then enabledTypeCount = enabledTypeCount + 1 end
            end
            local expandedHeight = 0
            if expanded then
                expandedHeight = 270 + (enabledTypeCount * 34) + (hasMacro and 150 or 0)
            end
            local cardHeight = 58 + expandedHeight
            local card = trackRendered(p, CreateFrame("Frame", nil, p.optionCanvas, "BackdropTemplate"))
            card:SetPoint("TOPLEFT", 0, y)
            card:SetPoint("TOPRIGHT", -8, y)
            card:SetHeight(cardHeight)
            makeBackdrop(card, C.card, C.border)

            local name = spellDisplayName(spellID)
            local titleText = label(card, name, 13, spellData.Disabled and C.muted or C.text, "TOPLEFT", 16, -13)
            titleText:SetWidth(315); titleText:SetJustifyH("LEFT")
            local tagParts = { "ID " .. tostring(spellID) }
            if spellData.IsItem then tagParts[#tagParts + 1] = "Item" end
            if spellData.IsDefault then tagParts[#tagParts + 1] = "Built-in" else tagParts[#tagParts + 1] = "Custom" end
            if spellData.Pet then tagParts[#tagParts + 1] = "Pet" end
            label(card, table.concat(tagParts, "  â€¢  "), 9, C.muted, "TOPLEFT", 16, -36)

            local configure = button(card, expanded and "Collapse" or "Configure", 92, 28, function()
                p.expandedSpellID = expanded and nil or spellID
                p:Rebuild()
            end)
            configure:SetPoint("TOPRIGHT", -16, -15)

            local enableOpt = spellGroup and spellGroup.args and spellGroup.args.enable
            local enable = compactToggle(card, 376, -15, 104, "Enabled", function()
                if not enableOpt then return not spellData.Disabled end
                return runGet(model, group, enableOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "enable" })
            end, function(v)
                if enableOpt and runSet(model, group, enableOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "enable" }, v) then
                    titleText:SetTextColor(unpack(v and C.text or C.muted))
                end
            end)

            if expanded and spellGroup and spellGroup.args then
                local contentTop = -72
                label(card, "Cure Types", 11, C.accent, "TOPLEFT", 16, contentTop)
                local chipX, chipY = 16, contentTop - 24
                for _, typeEntry in ipairs(typeList) do
                    local typeOpt = spellGroup.args.cureTypes and spellGroup.args.cureTypes.args and spellGroup.args.cureTypes.args[typeEntry.key]
                    if typeOpt then
                        local chip = compactToggle(card, chipX, chipY, 138, typeEntry.name, function()
                            return runGet(model, group, typeOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "cureTypes", typeEntry.key })
                        end, function(v)
                            if runSet(model, group, typeOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "cureTypes", typeEntry.key }, v) then p:Rebuild() end
                        end)
                        local typeHandler = typeOpt.handler or group.handler or model.handler
                        local typeInfo = buildInfo({ "CustomSpells", "CustomSpellsHolder", tostring(spellID), "cureTypes", typeEntry.key }, typeOpt, typeHandler)
                        local disabled = optionValue(typeOpt.disabled, typeHandler, typeInfo, false) == true
                        setDisabledVisual(chip, disabled)
                        chipX = chipX + 146
                        if chipX > 470 then chipX = 16; chipY = chipY - 34 end
                    end
                end

                local afterTypesY = chipY - 44
                local priorityOpt = spellGroup.args.priority
                if priorityOpt then
                    local prioRow = CreateFrame("Frame", nil, card)
                    prioRow:SetPoint("TOPLEFT", 16, afterTypesY)
                    prioRow:SetPoint("TOPRIGHT", -16, afterTypesY)
                    prioRow:SetHeight(52)
                    label(prioRow, "Spell priority", 11, C.text, "TOPLEFT", 0, 0)
                    local prioSlider = CreateFrame("Slider", nil, prioRow)
                    prioSlider:SetPoint("TOPLEFT", 0, -29); prioSlider:SetPoint("TOPRIGHT", 0, -29); prioSlider:SetHeight(18)
                    prioSlider:SetOrientation("HORIZONTAL")
                    prioSlider:SetMinMaxValues(-10, 30); prioSlider:SetValueStep(1); if prioSlider.SetObeyStepOnDrag then prioSlider:SetObeyStepOnDrag(true) end
                    local bg = prioSlider:CreateTexture(nil, "BACKGROUND"); bg:SetPoint("LEFT"); bg:SetPoint("RIGHT"); bg:SetHeight(4); setColor(bg, C.off)
                    local fill = prioSlider:CreateTexture(nil, "ARTWORK"); fill:SetPoint("LEFT"); fill:SetHeight(4); setColor(fill, C.accent)
                    prioSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                    local currentPriority = tonumber(runGet(model, group, priorityOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "priority" })) or 10
                    local prioStepper = addRangeStepper(prioRow, prioSlider, -10, 30, 1, false, nil, function() return false end)
                    prioStepper:Refresh(currentPriority)
                    prioSlider._refreshing = true; prioSlider:SetValue(currentPriority); prioSlider._refreshing = false
                    local function refreshFill(v)
                        prioStepper:Refresh(v)
                        local width = prioSlider:GetWidth()
                        if width and width > 0 then fill:SetWidth(math.max(1, width * ((v + 10) / 40))) end
                    end
                    refreshFill(currentPriority)
                    prioSlider:SetScript("OnValueChanged", function(self, value)
                        local rounded = math.floor(value + .5)
                        refreshFill(rounded)
                        if not self._refreshing and ZD:CanConfigure(true) then
                            runSet(model, group, priorityOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "priority" }, rounded)
                        end
                    end)
                    prioSlider:SetScript("OnSizeChanged", function() refreshFill(prioSlider:GetValue()) end)
                    afterTypesY = afterTypesY - 64
                end

                if not spellData.IsItem then
                    local petOpt = spellGroup.args.isPet
                    if petOpt then
                        compactToggle(card, 16, afterTypesY, 190, "Pet ability", function()
                            return runGet(model, group, petOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "isPet" })
                        end, function(v)
                            runSet(model, group, petOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "isPet" }, v)
                        end)
                    end
                end

                local deleteOpt = spellGroup.args.delete
                local remove = button(card, spellData.IsDefault and "Disable / Hide Built-in" or "Remove Spell", spellData.IsDefault and 168 or 120, 28, function()
                    local text = spellData.IsDefault and ("Hide the built-in spell â€œ" .. name .. "â€ from Decursive?") or ("Remove â€œ" .. name .. "â€ from Decursive?")
                    showConfirm(text, function()
                        if deleteOpt and runExecute(model, group, deleteOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "delete" }) then
                            p.expandedSpellID = nil
                            p:Rebuild()
                        end
                    end)
                end, "danger")
                remove:SetPoint("TOPRIGHT", -16, afterTypesY)
                afterTypesY = afterTypesY - 42

                -- Unit filtering only appears for cure types enabled on this spell.
                if enabledTypeCount > 0 then
                    label(card, "Unit Filtering", 11, C.accent, "TOPLEFT", 16, afterTypesY)
                    afterTypesY = afterTypesY - 25
                    for _, typeEntry in ipairs(typeList) do
                        if D:tcheckforval(spellData.Types or {}, typeEntry.type) then
                            local filterOpt = spellGroup.args.UnitFiltering and spellGroup.args.UnitFiltering.args and spellGroup.args.UnitFiltering.args[typeEntry.key]
                            if filterOpt then
                                local filterRow = CreateFrame("Frame", nil, card)
                                filterRow:SetPoint("TOPLEFT", 16, afterTypesY)
                                filterRow:SetPoint("TOPRIGHT", -16, afterTypesY)
                                filterRow:SetHeight(28)
                                label(filterRow, typeEntry.name, 10, C.text, "LEFT", 0, 0)
                                local filterNames = { [0] = "Any friendly unit", [1] = "Player only", [2] = "Other units only" }
                                local filterButton = button(filterRow, "", 170, 25, nil)
                                filterButton:SetPoint("RIGHT", 0, 0)
                                local function currentFilter()
                                    return tonumber(runGet(model, group, filterOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "UnitFiltering", typeEntry.key })) or 0
                                end
                                local function refreshFilter()
                                    filterButton:SetLabel(filterNames[currentFilter()] or "Any friendly unit")
                                end
                                filterButton:SetScript("OnClick", function()
                                    if not ZD:CanConfigure() then return end
                                    local nextValue = currentFilter() + 1
                                    if nextValue > 2 then nextValue = 0 end
                                    if runSet(model, group, filterOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "UnitFiltering", typeEntry.key }, nextValue) then refreshFilter() end
                                end)
                                refreshFilter()
                                afterTypesY = afterTypesY - 34
                            end
                        end
                    end
                    afterTypesY = afterTypesY - 4
                end

                local macroOpt = spellGroup.args.MacroEdition
                if macroOpt and hasMacro then
                    label(card, "Internal Macro", 11, C.accent, "TOPLEFT", 16, afterTypesY)
                    local macroHint = label(card, "Must contain UNITID. Changes update the secure MUF action for this spell.", 9, C.muted, "TOPLEFT", 16, afterTypesY - 20)
                    macroHint:SetWidth(590)
                    local macroBox = editBox(card, 590, 92, true)
                    macroBox:SetPoint("TOPLEFT", 16, afterTypesY - 40)
                    local currentMacro = runGet(model, group, macroOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "MacroEdition" }) or spellData.MacroText or ""
                    macroBox.edit:SetHeight(80)
                    macroBox.edit:SetText(currentMacro)
                    macroBox.edit:SetScript("OnEditFocusLost", function(self)
                        local newText = self:GetText() or ""
                        if newText ~= currentMacro and ZD:CanConfigure(true) then
                            if runSet(model, group, macroOpt, { "CustomSpells", "CustomSpellsHolder", tostring(spellID), "MacroEdition" }, newText) then currentMacro = newText end
                        end
                    end)
                end
            end

            y = y - cardHeight - 10
        end

        p.optionCanvas:SetHeight(math.max(560, -y + 24))
    end

    function p:Refresh()
        -- This page rebuilds only when its data model changes. Status-bar refreshes
        -- must not recreate controls while the player is typing or dragging sliders.
    end

    p:Rebuild()
    return p
end

function ZD:BuildIntegrations(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Detection", "Decursive uses the native Blizzard-managed AuraContainer provider for dispel detection.")

    local statusCard = section(p, "Detection Status", -66, 120)
    p.providerName = label(statusCard, "", 12, C.accent, "TOPLEFT", 18, -44)
    p.providerDetail = label(statusCard, "", 11, C.muted, "TOPLEFT", 18, -72)
    p.providerDetail:SetPoint("RIGHT", -18, 0)
    p.providerDetail:SetJustifyH("LEFT")

    local contract = section(p, "What Decursive owns", -202, 196)
    local contractLines = {
        "MUFs (Micro Unit Frames): layout, sizing, colors, and unit order.",
        "Secure curing: cure spell mapping, mouse bindings, and target handling.",
        "Cooldown overlays, timers, and remaining-target feedback.",
        "Status lights: gray ready, yellow range, red failed/uncleared, green successful cleanse.",
        "Environment behavior profiles (Open World / Dungeon / Mythic+ / Raid / PvP).",
    }
    for i, text in ipairs(contractLines) do
        local fs = label(contract, "• " .. text, 11, i == 1 and C.accent or C.text, "TOPLEFT", 18, -38 - ((i - 1) * 29))
        fs:SetPoint("RIGHT", -18, 0)
        fs:SetJustifyH("LEFT")
    end

    function p:Refresh()
        local st = ZD:GetDetectionProviderStatus() or {}
        local name = st.displayName or "Native Blizzard-managed"
        p.providerName:SetText("Session provider: " .. tostring(name))
        p.providerName:SetTextColor(unpack(C.accent))
        p.providerDetail:SetText("Dispel detection uses Blizzard-managed AuraContainers. No external provider is required.")
        p.providerDetail:SetTextColor(unpack(C.muted))
    end
    p:Refresh()
    return p
end

function ZD:BuildCompatibility121(parent)
    return self:BuildOptionGroupPage(parent, "Compatibility121", "12.1 Status", "Managed-aura status, dispel resolver refresh and safe MUF visual test controls.")
end

function ZD:BuildDiagnostics(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Diagnostics", "Check the compatibility state without reading protected aura details.")

    local state = section(p, "Current State", -66, 236)
    p.lines = {}
    for i = 1, 6 do p.lines[i] = label(state, "", 11, i == 1 and C.accent or C.text, "TOPLEFT", 18, -40 - ((i - 1) * 27)) end

    local actions = section(p, "Tools", -316, 150)
    local a1 = button(actions, "Run Self-Diagnostic", 180, 30, function()
        if T._SelfDiagnostic then T._SelfDiagnostic(true, true) end
    end, "primary")
    a1:SetPoint("TOPLEFT", 18, -50)
    local a2 = button(actions, "Print 12.1 Status", 170, 30, function()
        if D.Get121CompatibilityStatusText then D:Println(D:Get121CompatibilityStatusText()) end
    end)
    a2:SetPoint("LEFT", a1, "RIGHT", 12, 0)
    local a3 = button(actions, "Reload UI", 120, 30, function() ReloadUI() end)
    a3:SetPoint("LEFT", a2, "RIGHT", 12, 0)

    function p:Refresh()
        local lines = ZD:GetCompatibilitySummary()
        for i = 1, #p.lines do p.lines[i]:SetText(lines[i] or "") end
    end
    return p
end

function ZD:BuildDispelDB(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Dispel Database", "Local per-expansion dispellable-spell database used by the 12.1 aura-sound engine.")

    local summary = section(p, "Database Summary", -66, 116)
    p.summary1 = label(summary, "", 12, C.accent, "TOPLEFT", 18, -42)
    p.summary2 = label(summary, "", 11, C.text, "TOPLEFT", 18, -70)
    p.summary2:SetWidth(760); p.summary2:SetJustifyH("LEFT")

    local box = section(p, "Expansion Coverage", -198, 510)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -38)
    scroll:SetPoint("BOTTOMRIGHT", -30, 14)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(760)
    child:SetHeight(450)
    scroll:SetScrollChild(child)
    p.dbChild = child
    p.dbLines = {}

    local actions = section(p, "Tools", -724, 92)
    local b1 = button(actions, "Print Database Status", 180, 30, function()
        if D.PrintDispelDBDiagnostics then D:PrintDispelDBDiagnostics() end
    end, "primary")
    b1:SetPoint("TOPLEFT", 18, -44)
    local b2 = button(actions, "Print Sound Status", 160, 30, function()
        if D.PrintAuraSoundDiagnostics then D:PrintAuraSoundDiagnostics() end
    end)
    b2:SetPoint("LEFT", b1, "RIGHT", 12, 0)

    function p:Refresh()
        local stats = D.GetDispelDBStats and D:GetDispelDBStats() or { total=0, friendly=0, hostile=0, expansions={} }
        p.summary1:SetText(("%d total entries    %d friendly alerts    %d enemy/purge records"):format(stats.total or 0, stats.friendly or 0, stats.hostile or 0))
        p.summary2:SetText("Friendly entries that match your current spec's cure types are pre-registered with Blizzard. Expansion modules can grow independently for Timewalking and legacy content.")

        for i = 1, #p.dbLines do p.dbLines[i]:Hide() end
        local list = D.GetDispelDBExpansionList and D:GetDispelDBExpansionList() or {}
        local y = -8
        for i = 1, #list do
            local row = list[i]
            local st = row.stats or {}
            local line = p.dbLines[i]
            if not line then
                line = label(child, "", 11, C.text, "TOPLEFT", 8, y)
                line:SetWidth(720)
                line:SetJustifyH("LEFT")
                p.dbLines[i] = line
            end
            line:ClearAllPoints(); line:SetPoint("TOPLEFT", 8, y); line:Show()
            local typeParts = {}
            local preferred = {"MAGIC","POISON","DISEASE","CURSE","BLEED","ENEMYMAGIC"}
            for _, k in ipairs(preferred) do
                local n = st.types and st.types[k] or 0
                if n and n > 0 then typeParts[#typeParts+1] = k .. ":" .. n end
            end
            local typeText = #typeParts > 0 and table.concat(typeParts, "  ") or "no entries yet"
            line:SetText(("%s  â€”  %d total / %d friendly / %d enemy  [%s]   %s"):format(row.key, st.total or 0, st.friendly or 0, st.hostile or 0, st.coverage or "unknown", typeText))
            if (st.total or 0) > 0 then line:SetTextColor(unpack(C.text)) else line:SetTextColor(unpack(C.muted)) end
            y = y - 34
        end
        child:SetHeight(math.max(450, -y + 20))
    end

    p:Refresh()
    return p
end

function ZD:BuildAdvanced(parent)
    return self:BuildOptionGroupPage(parent, "About", "About", "Version information, credits and project information.")
end

function ZD:BuildGeneral(parent)
    return self:BuildOptionGroupPage(parent, "general", "General", "General behavior, tooltips, minimap, startup and profile controls.")
end

function ZD:BuildSounds(parent)
    local p = pageFrame(parent)
    self:PageTitle(p, "Sound Notifications", "Play an alert when a Decursive MUF changes from clean to an actionable red/blue afflicted state.")

    local SOUND_FILES = {
        AFFLICTION = DC.AfflictionSound,
        QUICK = T._AddonPath .. "Sounds\\G_NecropolisWound-fast.ogg",
        FAILURE = DC.FailedSound,
        BRIGHT_PING = T._AddonPath .. "Sounds\\BrightPing.ogg",
        DOUBLE_PING = T._AddonPath .. "Sounds\\DoublePing.ogg",
        TRIPLE_PING = T._AddonPath .. "Sounds\\TriplePing.ogg",
        HIGH_CHIME = T._AddonPath .. "Sounds\\HighChime.ogg",
        LOW_CHIME = T._AddonPath .. "Sounds\\LowChime.ogg",
        PULSE_UP = T._AddonPath .. "Sounds\\PulseUp.ogg",
        PULSE_DOWN = T._AddonPath .. "Sounds\\PulseDown.ogg",
        FEMALE_DISPEL = T._AddonPath .. "Sounds\\FemaleDispel.ogg",
        FEMALE_DISPEL_ME = T._AddonPath .. "Sounds\\FemaleDispelMe.ogg",
        FEMALE_CLEANSE = T._AddonPath .. "Sounds\\FemaleCleanse.ogg",
        FEMALE_CLEANSE_ME = T._AddonPath .. "Sounds\\FemaleCleanseMe.ogg",
    }

    local function soundValues()
        return {
            { key="FEMALE_DISPEL", name="Female Voice â€” Dispel" },
            { key="FEMALE_DISPEL_ME", name="Female Voice â€” Dispel me" },
            { key="FEMALE_CLEANSE", name="Female Voice â€” Cleanse" },
            { key="FEMALE_CLEANSE_ME", name="Female Voice â€” Cleanse me" },
            { key="AFFLICTION", name="Tone â€” Affliction Alert" },
            { key="QUICK", name="Tone â€” Quick Pulse" },
            { key="BRIGHT_PING", name="Tone â€” Bright Ping" },
            { key="DOUBLE_PING", name="Tone â€” Double Ping" },
            { key="TRIPLE_PING", name="Tone â€” Triple Ping" },
            { key="HIGH_CHIME", name="Tone â€” High Chime" },
            { key="LOW_CHIME", name="Tone â€” Low Chime" },
            { key="PULSE_UP", name="Tone â€” Rising Pulse" },
            { key="PULSE_DOWN", name="Tone â€” Falling Pulse" },
            { key="FAILURE", name="Tone â€” Short Alert" },
        }
    end

    local function channelValues()
        return {
            { key="Master", name="Master" },
            { key="SFX", name="Sound Effects" },
            { key="Dialog", name="Dialog" },
            { key="Ambience", name="Ambience" },
            { key="Music", name="Music" },
        }
    end

    local alerts = section(p, "Affliction Alert", -66, 236)
    p.soundEnabled = switch(alerts, "Enable sound notifications", -44,
        function() return D.profile and D.profile.PlaySound end,
        function(v)
            if D.profile then D.profile.PlaySound = v and true or false end
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound enable changed") end
        end,
        "For known dispellable Spell IDs, Blizzard plays the selected sound when the aura is applied to an assigned group unit.")

    p.soundChoice = cycleButton(alerts, "Dispel alert sound", -112, soundValues,
        function() return (D.profile and D.profile.SoundNotificationPreset) or "FEMALE_DISPEL" end,
        function(key)
            if not D.profile then return end
            D.profile.SoundNotificationPreset = key
            D.profile.SoundFile = SOUND_FILES[key] or DC.AfflictionSound
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound preset changed") end
        end)

    p.channelChoice = cycleButton(alerts, "Output channel", -158, channelValues,
        function() return (D.profile and D.profile.SoundNotificationChannel) or "Master" end,
        function(key)
            if D.profile then D.profile.SoundNotificationChannel = key end
            if D.RefreshProtectedAuraSounds then D:RefreshProtectedAuraSounds("sound channel changed") end
        end)

    local test = button(alerts, "Test Sound", 150, 30, function()
        if not D.profile or not D.profile.PlaySound then
            ZD:SetStatus("Enable sound notifications first.", true)
            return
        end
        local file = D.profile.SoundFile or SOUND_FILES[D.profile.SoundNotificationPreset or "FEMALE_DISPEL"] or DC.AfflictionSound
        if D.PlayDispelNotificationSound then
            D:PlayDispelNotificationSound("settings test", true)
        elseif D.SafePlaySoundFile then
            D:SafePlaySoundFile(file, D.profile.SoundNotificationChannel or "Master")
        elseif PlaySoundFile then
            PlaySoundFile(file, D.profile.SoundNotificationChannel or "Master")
        end
        ZD:SetStatus("Played selected dispel alert sound.")
    end, "primary")
    test:SetPoint("BOTTOMLEFT", 18, 14)

    local behavior = section(p, "Square Trigger", -316, 178)
    local rule = label(behavior,
        "12.1 engine: known dispellable Spell ID applied â†’ Blizzard plays the selected alert.\nThe protected red/blue square remains independently managed by Blizzard.",
        12, C.text, "TOPLEFT", 18, -42)
    rule:SetPoint("RIGHT", -18, 0)
    rule:SetJustifyH("LEFT")

    p.triggerState = label(behavior, "", 11, C.accent, "BOTTOMLEFT", 18, 18)
    p.triggerState:SetPoint("RIGHT", -18, 0)
    p.triggerState:SetJustifyH("LEFT")

    local failure = section(p, "Cure Failure", -510, 120)
    p.failureSound = switch(failure, "Play cure-failure sound", -42,
        function() return D.profile and D.profile.PlayFailureSound end,
        function(v) if D.profile then D.profile.PlayFailureSound = v and true or false end end,
        "Optional short sound after a failed cleanse attempt. This is separate from the red/blue-square alert.")

    function p:Refresh()
        if p.soundEnabled and p.soundEnabled.control and p.soundEnabled.control.Refresh then p.soundEnabled.control:Refresh() end
        if p.soundChoice and p.soundChoice.control and p.soundChoice.control.Refresh then p.soundChoice.control:Refresh() end
        if p.channelChoice and p.channelChoice.control and p.channelChoice.control.Refresh then p.channelChoice.control:Refresh() end
        if p.failureSound and p.failureSound.control and p.failureSound.control.Refresh then p.failureSound.control:Refresh() end
        local active = D.Is121MUFStateSoundEngineAvailable and D:Is121MUFStateSoundEngineAvailable()
        if active then
            p.triggerState:SetText("Trigger engine: Active â€” MUF-linked affliction monitoring")
            p.triggerState:SetTextColor(unpack(C.accent))
        else
            p.triggerState:SetText("Trigger engine: Waiting for MUFs / initialization")
            p.triggerState:SetTextColor(unpack(C.muted))
        end
    end
    p:Refresh()
    return p
end

function ZD:BuildFiltering(parent)
    return self:BuildTabbedOptionPathPage(parent, "Affliction Filters",
        "Adding/removing filter rules is separated from the potentially long list of existing ignored afflictions.", {
            {key="rules", name="Filter Rules", path={"DebuffSkip"}, skipKeys={debuffHolder=true}, width=125},
            {key="ignored", name="Ignored Afflictions", path={"DebuffSkip","debuffHolder"}, width=155},
        }, "rules")
end

function ZD:BuildLiveList(parent)
    return self:BuildOptionGroupPage(parent, "livelistoptions", "Live List", "All Live List display, sizing, ordering and test controls.")
end

function ZD:BuildMessages(parent)
    return self:BuildOptionGroupPage(parent, "MessageOptions", "Messages", "Notifications (chat / custom text) vs Alert warnings (Soul Link battle-rez banner).")
end

function ZD:BuildMacro(parent)
    return self:BuildOptionGroupPage(parent, "Macro", "Macro", "Mouse-over macro creation, key binding and macro editing behavior.")
end

local builders = {
    dashboard = "BuildDashboard",
    general = "BuildGeneral",
    sounds = "BuildSounds",
    frames = "BuildFrames",
    curing = "BuildCuring",
    bleeds = "BuildBleeds",
    cooldowns = "BuildCooldowns",
    range = "BuildRangeVisibility",
    bindings = "BuildBindings",
    filtering = "BuildFiltering",
    livelist = "BuildLiveList",
    messages = "BuildMessages",
    macro = "BuildMacro",
    profiles = "BuildProfiles",
    sharing = "BuildSharing",
    lists = "BuildLists",
    integrations = "BuildIntegrations",
    testmode = "BuildTestMode",
    compat121 = "BuildCompatibility121",
    diagnostics = "BuildDiagnostics",
    dispeldb = "BuildDispelDB",
    about = "BuildAdvanced",
}

function ZD:ShowPage(key)
    local f = self:CreateUI()

    -- Build the destination before hiding the currently visible page.  This
    -- prevents a blank content pane while a lazily-created page initializes.
    if not self.pages[key] then
        local method = builders[key]
        if method and self[method] then self.pages[key] = self[method](self, f.content) end
    end

    local page = self.pages[key]
    if not page then return end

    -- Show first so layout-dependent controls have a live parent.  Most page
    -- builders already perform their initial build.  On later visits honor the
    -- page's Refresh contract instead of force-calling Rebuild: some complex
    -- pages (notably Spells & Bindings) deliberately make Refresh a no-op so
    -- navigation cannot tear down/recreate their secure control trees.
    page:Show()
    if page.Refresh then
        local ok, err = pcall(page.Refresh, page)
        if not ok then
            self:SetStatus("Could not refresh " .. tostring(self.navNames and self.navNames[key] or key) .. ": " .. tostring(err), true)
        end
    elseif page.Rebuild then
        local ok, err = pcall(page.Rebuild, page)
        if not ok then
            self:SetStatus("Could not rebuild " .. tostring(self.navNames and self.navNames[key] or key) .. ": " .. tostring(err), true)
        end
    end

    -- Now hide every other registered content page.  This preserves the
    -- overlap fix without blanking the destination during its initialization.
    for _, existingPage in pairs(self.pages or {}) do
        if existingPage ~= page and existingPage and existingPage.Hide then existingPage:Hide() end
    end
    page:Show()

    self.currentPageFrame = page
    self.currentPage = key
    self:SetNavActive(key)
end

function ZD:MarkOptionsDirty()
    self.searchIndex = nil
    for _, page in pairs(self.pages or {}) do
        if page and page.optionCanvas then page._needsRebuild = true end
    end
    self:RefreshUI()
end

function ZD:RefreshUI()
    if not self.frame then return end
    if self.frame.status then
        local color = self.lastStatusError and C.danger or C.muted
        self.frame.status.text:SetTextColor(unpack(color))
        self.frame.status.text:SetText(self.lastStatus or "Ready")
        self.frame.status.combat:SetText(InCombatLockdown() and "COMBAT LOCKED" or "")
    end
    if self.currentPageFrame and self.currentPageFrame.Refresh then
        self.currentPageFrame:Refresh()
    end
end

function ZD:ToggleUI()
    local f = self:CreateUI()
    if f:IsShown() then f:Hide() else f:Show() end
end

