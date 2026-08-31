--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 Cure page.
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

local function localized(key, fallback)
    return D and D.L and D.L[key] or fallback
end

local function gestureLabel(gesture)
    if gesture == "UNASSIGNED" or gesture == nil then return localized("CURE_BINDING_UNASSIGNED", "Unassigned") end
    return DC and DC.MouseButtonsReadable and DC.MouseButtonsReadable[gesture] or tostring(gesture)
end

local function bindingMode()
    return D and D.profile and D.profile.CureBindingMode == "MANUAL" and "MANUAL" or "AUTO"
end

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
    page.contentHeight = 1120
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
                    local applied = ZD.ToggleCure and ZD:ToggleCure(capturedTypeID) or false
                    if applied then UI:SetStatus(labelText .. " priority updated.", "success") end
                    return applied
                end)
        end
    end

    local bindings = Controls:Card(page, localized("CURE_BINDING_CARD", "Automatic Cure Bindings"),
        localized("CURE_BINDING_DESC", "Simple Two-Button keeps targeted friendly cures first: Left, Right, then Ctrl+Left. Middle targets and Ctrl+Middle focuses. Secure changes apply only outside combat."))
    bindings:SetPoint("TOPLEFT", priorities, "BOTTOMLEFT", 0, -12)
    bindings:SetPoint("TOPRIGHT", priorities, "BOTTOMRIGHT", 0, -12)
    bindings:SetHeight(610)

    local modeRow = Controls:Cycle(bindings, localized("CURE_BINDING_MODE", "Binding mode"), function()
        return {
            { key = "AUTO", label = localized("CURE_BINDING_AUTO", "Simple Two-Button") },
            { key = "MANUAL", label = localized("CURE_BINDING_MANUAL", "Manual Cure Bindings") },
        }
    end, bindingMode, function(value)
        local ok, reason = D:SetCureBindingMode(value)
        if not ok then UI:SetStatus(reason == "combat" and localized("CURE_BINDING_COMBAT", "Cure bindings are locked during combat; the current secure layout remains active.") or tostring(reason), "error") end
        return ok
    end)

    local reset = Controls:Button(bindings, localized("CURE_BINDING_RESTORE_AUTO", "Restore Simple Two-Button"), 208, function()
        local ok, reason = D:ResetCureBindingsToAutomatic()
        if ok then
            UI:SetStatus(localized("CURE_BINDING_AUTO_RESTORED", "Automatic cure bindings restored for this environment."), "success")
            bindings:Refresh()
        else
            UI:SetStatus(reason == "combat" and localized("CURE_BINDING_COMBAT", "Cure bindings are locked during combat; the current secure layout remains active.") or tostring(reason), "error")
        end
    end)
    reset:SetPoint("TOPRIGHT", -16, -12)

    local function manualGestureValues()
        local values = {}
        for _, gesture in ipairs(D.GetSupportedCureBindingGestures and D:GetSupportedCureBindingGestures() or { "UNASSIGNED" }) do
            values[#values + 1] = { key = gesture, label = gestureLabel(gesture) }
        end
        return values
    end

    local actionRows = {}
    for slot = 1, 7 do
        local capturedSlot = slot
        local row = Controls:Cycle(bindings, "Cure slot " .. slot, manualGestureValues, function()
            local actions = D.GetCureBindingActions and D:GetCureBindingActions(true) or {}
            local action = actions[capturedSlot]
            return action and action.gesture or "UNASSIGNED"
        end, function(value)
            local actions = D.GetCureBindingActions and D:GetCureBindingActions(true) or {}
            local action = actions[capturedSlot]
            if not action then return false end
            local ok, reason = D:SetManualCureBinding(action.actionKey, value)
            if not ok then
                local message = reason == "duplicate-gesture" and localized("CURE_BINDING_DUPLICATE", "That gesture is already assigned to another available action.")
                    or reason == "reserved-gesture" and localized("CURE_BINDING_RESERVED", "That gesture is reserved for targeting, focusing, or the active PvP bandage action.")
                    or reason == "combat" and localized("CURE_BINDING_COMBAT", "Cure bindings are locked during combat; the current secure layout remains active.")
                    or tostring(reason)
                UI:SetStatus(message, "error")
            end
            return ok
        end, function()
            return bindingMode() == "MANUAL" and not (_G.InCombatLockdown and _G.InCombatLockdown())
        end)
        actionRows[slot] = row
        local originalRefresh = row.Refresh
        function row:Refresh()
            local actions = D.GetCureBindingActions and D:GetCureBindingActions(true) or {}
            local action = actions[capturedSlot]
            if action then
                local category = action.category == "AREA_UTILITY" and localized("CURE_BINDING_AREA", "Area utility")
                    or action.category == "PVP_BANDAGE" and localized("CURE_BINDING_PVP_BANDAGE", "PvP bandage")
                    or action.category == "UNAVAILABLE" and localized("CURE_BINDING_UNAVAILABLE", "Unavailable in this specialization")
                    or action.category == "FRIENDLY_CURE" and localized("CURE_BINDING_TARGETED", "Targeted cure")
                    or localized("CURE_BINDING_ADDITIONAL", "Additional action")
                local types = #action.coveredTypeLabels > 0 and table.concat(action.coveredTypeLabels, " / ") or category
                local color = D.profile and D.profile.MF_colors and D.profile.MF_colors[capturedSlot]
                local slotName = localized("CURE_BINDING_SLOT", "Slot %d"):format(capturedSlot)
                if color and D.NumToHexColor then slotName = D:ColorText(slotName, D:NumToHexColor(color)) end
                self.label:SetText(slotName .. "  ·  " .. tostring(action.spellName) .. "  ·  " .. types)
                self:Show()
            else
                self.label:SetText(localized("CURE_BINDING_EMPTY_SLOT", "No action in slot %d"):format(capturedSlot))
                self:Hide()
            end
            originalRefresh(self)
        end
    end

    local targetState = Controls:Pill(bindings,
        localized("CURE_BINDING_FIXED_ACTIONS", "Middle: target  ·  Ctrl+Middle: focus"), Theme.color.success)
    targetState:SetWidth(300)
    targetState:SetPoint("BOTTOMLEFT", 16, 16)
    local bandageHelp = Controls:Label(bindings,
        localized("CURE_BINDING_BANDAGE_HELP", "Button5 scans carried bags only. A built-in item must publicly expose the Mending Bandage use spell, have a public positive count, and be usable. Highest public item level wins; when level is unavailable, the lowest item ID and earliest bag/slot provide an honest deterministic fallback. Bank, reagent-bank, and account-bank items are ignored."),
        9, Theme.color.muted)
    bandageHelp:SetPoint("BOTTOMLEFT", 16, 47)
    bandageHelp:SetPoint("BOTTOMRIGHT", -16, 47)
    bandageHelp:SetJustifyH("LEFT")
    bandageHelp:SetWordWrap(true)
    local bandageState = Controls:Pill(bindings, "", Theme.color.muted)
    bandageState:SetWidth(330)
    bandageState:SetPoint("BOTTOMRIGHT", -16, 16)
    bindings:AddRefresher(function()
        local bandage
        for _, action in ipairs(D.GetCureBindingActions and D:GetCureBindingActions() or {}) do
            if action.isPvPBandage then bandage = action break end
        end
        local bandageText
        if bandage and bandage.actionID and bandage.actionID < 0 then
            local source = bandage.bandageSource == "EXTERNAL"
                and localized("CURE_BINDING_BANDAGE_SOURCE_EXTERNAL", "resolver")
                or localized("CURE_BINDING_BANDAGE_SOURCE_BUILTIN", "bag")
            local detail = bandage.bandageItemLevelPublic
                and localized("CURE_BINDING_BANDAGE_LEVEL", "%s iLvl %d"):format(source, bandage.bandageItemLevel)
                or localized("CURE_BINDING_BANDAGE_FALLBACK", "%s fallback"):format(source)
            bandageText = localized("CURE_BINDING_BUTTON5_DETAIL", "Button5: %s · %s")
                :format(tostring(bandage.spellName), detail)
        elseif bandage then
            bandageText = localized("CURE_BINDING_BUTTON5", "Button5: %s"):format(tostring(bandage.spellName))
        else
            bandageText = localized("CURE_BINDING_NO_BANDAGE", "Button5: no verified PvP bandage available")
        end
        bandageState.text:SetText(bandageText)
        modeRow:Refresh()
        for _, row in ipairs(actionRows) do row:Refresh() end
    end)

    function page:Refresh()
        priorities:Refresh()
        bindings:Refresh()
    end
    return page
end)
