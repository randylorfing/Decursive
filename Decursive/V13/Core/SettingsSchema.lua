--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 settings schema.
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

local _, T = ...
if not T then return end

local V13 = T.ZhaohuV13 or {}
T.ZhaohuV13 = V13

local Schema = {
    version = 1,
    entries = {},
    byKey = {},
    environmentOrder = { "OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP" },
    environmentNames = {
        OPEN_WORLD = "Open World",
        DUNGEON = "Dungeon / Follower",
        MYTHIC_PLUS = "Mythic+",
        RAID = "Raid",
        PVP = "PvP",
    },
}
V13.SettingsSchema = Schema

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = clone(child) end
    return result
end

local function add(entry)
    assert(type(entry.key) == "string" and entry.key ~= "", "setting key is required")
    assert(not Schema.byKey[entry.key], "duplicate setting key: " .. entry.key)
    Schema.entries[#Schema.entries + 1] = entry
    Schema.byKey[entry.key] = entry
end

local function boolean(key, default, page, group, label, scope)
    add({
        key = key,
        type = "boolean",
        default = default,
        page = page,
        group = group,
        label = label,
        scope = scope or "profile",
    })
end

local function number(key, default, minimum, maximum, step, unit, page, group, label, scope)
    add({
        key = key,
        type = "number",
        default = default,
        minimum = minimum,
        maximum = maximum,
        step = step,
        unit = unit,
        page = page,
        group = group,
        label = label,
        scope = scope or "profile",
    })
end

local function choice(key, default, values, page, group, label, scope)
    add({
        key = key,
        type = "choice",
        default = default,
        values = values,
        page = page,
        group = group,
        label = label,
        scope = scope or "profile",
    })
end

local function navigation(key, page, group, label)
    add({
        key = key,
        type = "navigation",
        page = page,
        group = group,
        label = label,
        scope = "navigation",
    })
end

boolean("muf.visible", true, "MUFS", "FRAME", "Show MUFs")
boolean("muf.locked", false, "MUFS", "FRAME", "Lock position")
number("muf.partySize", 20, 10, 80, 1, "px", "MUFS", "SIZE", "Party MUF size")
number("muf.raidSize", 20, 10, 80, 1, "px", "MUFS", "SIZE", "Raid MUF size")
number("muf.horizontalSpacing", 3, 0, 40, 1, "px", "MUFS", "LAYOUT", "Horizontal spacing")
number("muf.verticalSpacing", 3, 0, 40, 1, "px", "MUFS", "LAYOUT", "Vertical spacing")
boolean("muf.linkSpacing", true, "MUFS", "LAYOUT", "Link horizontal and vertical spacing")
boolean("muf.statusLight", false, "MUFS", "STATUS", "Status indicator light")
boolean("muf.tooltip", true, "MUFS", "FRAME", "MUF hover tooltip")
boolean("muf.growUp", false, "MUFS", "LAYOUT", "Grow upward")
boolean("muf.verticalLayout", false, "MUFS", "LAYOUT", "Fill columns before rows")
boolean("muf.growFromRight", false, "MUFS", "LAYOUT", "Grow from right edge")
boolean("muf.autoRaidGrid", true, "MUFS", "LAYOUT", "Automatic compact raid grid")
number("muf.maxUnits", 80, 1, 80, 1, "units", "MUFS", "LAYOUT", "Maximum MUFs")
number("muf.unitsPerLine", 10, 1, 40, 1, "units", "MUFS", "LAYOUT", "Units per line")
boolean("muf.border", true, "MUFS", "APPEARANCE", "Show MUF border")
number("muf.inactiveOpacity", 0.65, 0, 1, 0.05, "opacity", "MUFS", "APPEARANCE", "Inactive opacity")

boolean("alert.dispel.enabled", true, "ALERTS", "TEXT", "Dispel text alert")
choice("alert.dispel.mode", "TIMED", { "TIMED", "UNTIL_CLEARED" }, "ALERTS", "TEXT", "Display mode")
number("alert.dispel.duration", 2, 0.5, 30, 0.5, "seconds", "ALERTS", "TEXT", "Display duration")
number("alert.dispel.fontSize", 48, 12, 96, 1, "px", "ALERTS", "TEXT", "Text size")

boolean("alert.sound.enabled", true, "ALERTS", "SOUND", "Dispel sound")
choice("alert.sound.preset", "FEMALE_DISPEL", {
    "FEMALE_DISPEL",
    "FEMALE_DISPEL_ME",
    "FEMALE_CLEANSE",
    "FEMALE_CLEANSE_ME",
    "AFFLICTION",
    "QUICK",
    "BRIGHT_PING",
    "DOUBLE_PING",
    "TRIPLE_PING",
    "HIGH_CHIME",
    "LOW_CHIME",
    "PULSE_UP",
    "PULSE_DOWN",
    "FAILURE",
}, "ALERTS", "SOUND", "Sound")
choice("alert.sound.channel", "Master", {
    "Master", "SFX", "Music", "Ambience", "Dialog",
}, "ALERTS", "SOUND", "Sound channel")
number("alert.sound.debounce", 2, 0, 5, 0.25, "seconds", "ALERTS", "SOUND", "Group debounce")
boolean("alert.sound.failure", false, "ALERTS", "SOUND", "Cure-failure sound")

boolean("cooldown.enabled", true, "ALERTS", "COOLDOWN", "Cooldown overlay", "environment")
boolean("cooldown.numbers", true, "ALERTS", "COOLDOWN", "Countdown numbers", "environment")
number("cooldown.opacity", 0.62, 0, 1, 0.05, "opacity", "ALERTS", "COOLDOWN", "Overlay darkness", "environment")
boolean("feedback.range.enabled", true, "ALERTS", "RANGE", "Out-of-range status", "environment")
boolean("feedback.text.enabled", true, "ALERTS", "TEXT", "Text alerts", "environment")
boolean("feedback.chat.enabled", true, "ALERTS", "TEXT", "Chat status messages", "environment")

navigation("profiles.create", "PROFILES", "PROFILE", "Create profile")
navigation("profiles.copy", "PROFILES", "PROFILE", "Copy current profile")
navigation("profiles.reset", "PROFILES", "PROFILE", "Reset current profile")
navigation("profiles.import", "PROFILES", "TRANSFER", "Import profile")
navigation("profiles.export", "PROFILES", "TRANSFER", "Export profile")
navigation("advanced.diagnostics", "ADVANCED", "DIAGNOSTICS", "Runtime diagnostics")
navigation("advanced.reload", "ADVANCED", "TOOLS", "Reload UI")

Schema.environmentDefaults = {
    OPEN_WORLD = {
        ["cooldown.enabled"] = true,
        ["cooldown.numbers"] = true,
        ["cooldown.opacity"] = 0.62,
        ["feedback.range.enabled"] = false,
        ["feedback.text.enabled"] = true,
        ["feedback.chat.enabled"] = true,
    },
    DUNGEON = {
        ["cooldown.enabled"] = true,
        ["cooldown.numbers"] = true,
        ["cooldown.opacity"] = 0.60,
        ["feedback.range.enabled"] = true,
        ["feedback.text.enabled"] = true,
        ["feedback.chat.enabled"] = true,
    },
    MYTHIC_PLUS = {
        ["cooldown.enabled"] = true,
        ["cooldown.numbers"] = true,
        ["cooldown.opacity"] = 0.70,
        ["feedback.range.enabled"] = true,
        ["feedback.text.enabled"] = true,
        ["feedback.chat.enabled"] = true,
    },
    RAID = {
        ["cooldown.enabled"] = true,
        ["cooldown.numbers"] = false,
        ["cooldown.opacity"] = 0.50,
        ["feedback.range.enabled"] = true,
        ["feedback.text.enabled"] = true,
        ["feedback.chat.enabled"] = true,
    },
    PVP = {
        ["cooldown.enabled"] = true,
        ["cooldown.numbers"] = true,
        ["cooldown.opacity"] = 0.60,
        ["feedback.range.enabled"] = true,
        ["feedback.text.enabled"] = false,
        ["feedback.chat.enabled"] = false,
    },
}

function Schema:Get(key)
    return self.byKey[key]
end

function Schema:GetDefault(key)
    local entry = self.byKey[key]
    return entry and clone(entry.default) or nil
end

function Schema:BuildProfileDefaults()
    local result = { schemaVersion = self.version, values = {}, environments = {} }
    for _, entry in ipairs(self.entries) do
        if entry.scope == "profile" then
            result.values[entry.key] = clone(entry.default)
        end
    end
    for _, environment in ipairs(self.environmentOrder) do
        result.environments[environment] = clone(self.environmentDefaults[environment] or {})
    end
    return result
end

function Schema:Validate(key, value)
    local entry = self.byKey[key]
    if not entry then return false, "unknown setting" end

    if entry.type == "boolean" then
        return type(value) == "boolean", "expected boolean"
    end
    if entry.type == "number" then
        if type(value) ~= "number" then return false, "expected number" end
        if entry.minimum and value < entry.minimum then return false, "below minimum" end
        if entry.maximum and value > entry.maximum then return false, "above maximum" end
        return true
    end
    if entry.type == "choice" then
        for _, allowed in ipairs(entry.values or {}) do
            if value == allowed then return true end
        end
        return false, "invalid choice"
    end
    return false, "unsupported setting type"
end

function Schema:Search(query)
    query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local results = {}
    if query == "" then return results end
    for _, entry in ipairs(self.entries) do
        local haystack = table.concat({
            entry.key or "",
            entry.label or "",
            entry.page or "",
            entry.group or "",
        }, " "):lower()
        if haystack:find(query, 1, true) then results[#results + 1] = entry end
    end
    return results
end

function Schema:Clone(value)
    return clone(value)
end
