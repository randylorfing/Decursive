--[[
    This file is part of Decursive.

    Profile import/export helpers. This file was solely written by
    Randy Lorfing.
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

    Uses AceSerializer-3.0 and intentionally operates on the active AceDB profile only.
--]]

local addonName, T = ...
local D = T and T.Dcr
if not D then return end

local Serializer = LibStub("AceSerializer-3.0", true)
local FORMAT = "DECursiveProfile"
local FORMAT_VERSION = 1
local MAX_IMPORT_BYTES = 256 * 1024
local MAX_IMPORT_DEPTH = 16
local MAX_IMPORT_NODES = 20000
local MAX_STRING_BYTES = 4096
local MAX_KEY_BYTES = 256
local MAX_LIST_ENTRIES = 100

local function cloneValue(value, copies)
    if type(value) ~= "table" then return value end
    copies = copies or {}
    if copies[value] then return copies[value] end

    local result = {}
    copies[value] = result
    for key, child in pairs(value) do
        result[cloneValue(key, copies)] = cloneValue(child, copies)
    end
    return result
end

local function copyInto(dst, src)
    for key in pairs(dst) do dst[key] = nil end
    local copies = {}
    for key, value in pairs(src) do
        dst[cloneValue(key, copies)] = cloneValue(value, copies)
    end
end

local function finiteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function inspectSerializedText(text)
    -- AceSerializer itself walks nested tables recursively. Bound its wire
    -- structure before Deserialize so a hostile paste cannot reach that
    -- recursion with an excessively deep or multi-root payload.
    local compact = text:gsub("[%c ]", "")
    local sawHeader = false
    local rootStarted = false
    local rootClosed = false
    local sawTerminator = false
    local depth = 0
    local nodes = 0

    for control in compact:gmatch("(%^.)([^^]*)") do
        if not sawHeader then
            if control ~= "^1" then return false, "invalid serializer header" end
            sawHeader = true
        elseif control == "^^" then
            if not rootClosed or depth ~= 0 then return false, "incomplete serialized profile" end
            sawTerminator = true
            break
        elseif rootClosed then
            return false, "the export contains more than one root value"
        elseif not rootStarted then
            if control ~= "^T" then return false, "the export root must be a table" end
            rootStarted = true
            depth = 1
            nodes = 1
        elseif control == "^T" then
            depth = depth + 1
            nodes = nodes + 1
            if depth > MAX_IMPORT_DEPTH then return false, "the profile is nested too deeply" end
        elseif control == "^t" then
            depth = depth - 1
            if depth < 0 then return false, "the profile contains an unmatched table marker" end
            if depth == 0 then rootClosed = true end
        else
            nodes = nodes + 1
        end

        if nodes > MAX_IMPORT_NODES then
            return false, "the profile contains too many values"
        end
    end

    if not sawHeader or not rootStarted or not rootClosed or not sawTerminator then
        return false, "incomplete serialized profile"
    end
    return true
end

local function inspectSerializedGraph(root)
    local stack = { { value = root, depth = 1 } }
    local seen = {}
    local nodes = 0

    while #stack > 0 do
        local current = table.remove(stack)
        local value = current.value
        local valueType = type(value)
        nodes = nodes + 1
        if nodes > MAX_IMPORT_NODES then
            return false, "the profile contains too many values"
        end

        if valueType == "table" then
            if seen[value] then
                return false, "cyclic or shared table references are not supported"
            end
            seen[value] = true
            if current.depth > MAX_IMPORT_DEPTH then
                return false, "the profile is nested too deeply"
            end

            for key, child in pairs(value) do
                local keyType = type(key)
                if keyType ~= "string" and keyType ~= "number" then
                    return false, "the profile contains an unsupported table key"
                end
                if keyType == "string" and (#key > MAX_KEY_BYTES or key:find("\0", 1, true)) then
                    return false, "the profile contains an invalid table key"
                end
                if keyType == "number" and not finiteNumber(key) then
                    return false, "the profile contains an invalid numeric key"
                end

                local childType = type(child)
                if childType == "table" then
                    stack[#stack + 1] = { value = child, depth = current.depth + 1 }
                elseif childType == "string" then
                    if #child > MAX_STRING_BYTES or child:find("\0", 1, true) then
                        return false, "the profile contains an invalid or oversized string"
                    end
                    nodes = nodes + 1
                elseif childType == "number" then
                    if not finiteNumber(child) then
                        return false, "the profile contains an invalid number"
                    end
                    nodes = nodes + 1
                elseif childType == "boolean" then
                    nodes = nodes + 1
                else
                    return false, "the profile contains an unsupported value type"
                end
                if nodes > MAX_IMPORT_NODES then
                    return false, "the profile contains too many values"
                end
            end
        end
    end

    return true
end

local NUMBER_RANGES = {
    AutoHideMUFs = { 1, 4, true },
    DebuffsFrameMaxCount = { 1, 80, true },
    DebuffsFrameElemScale = { 0.5, 4 },
    DebuffsFrameElemAlpha = { 0, 1 },
    DebuffsFramePartyPixelSize121 = { 10, 80, true },
    DebuffsFrameRaidPixelSize121 = { 10, 80, true },
    CooldownOverlay121Opacity = { 0, 1 },
    CooldownBorder121Alpha = { 0, 1 },
    CooldownBorder121Thickness = { 1, 8 },
    OutOfRange121DimAmount = { 0, 1 },
    LineOfSight121Opacity = { 0, 1 },
    LineOfSight121HoldSeconds = { 0, 10 },
    DebuffsFrameElemBorderAlpha = { 0, 1 },
    DebuffsFramePerline = { 1, 40, true },
    DebuffsFrameXSpacing = { 0, 50 },
    DebuffsFrameYSpacing = { 0, 50 },
    LiveListAlpha = { 0, 1 },
    LiveListScale = { 0.5, 3 },
    Amount_Of_Afflicted = { 1, 40, true },
    CureBlacklist = { 0, 30 },
    ScanTime = { 0.05, 5 },
    SoundNotificationIgnoreSeconds = { 0, 10 },
    Alert121FontSize = { 8, 96, true },
    Alert121DispelDuration = { 0.5, 30 },
    V11WindowWidth = { 900, 1600, true },
    V11WindowHeight = { 680, 1100, true },
    MainBarX = { -100000, 100000 },
    MainBarY = { -100000, 100000 },
    DebuffsFrameContainer_x = { -100000, 100000 },
    DebuffsFrameContainer_y = { -100000, 100000 },
}

local ENUM_VALUES = {
    MUFOrderMode = { GROUP = true, PRIORITY = true, DANDERSFRAMES = true },
    Environment121Mode = { AUTO = true, RAID = true, MYTHIC_PLUS = true, DUNGEON = true, PVP = true, OPEN_WORLD = true },
    Detection121Mode = { STRICT_MANAGED = true },
    Alert121DispelMode = { TIMED = true, UNTIL_CLEARED = true },
    SoundNotificationChannel = { Master = true, SFX = true, Dialog = true, Ambience = true, Music = true },
    CenterTextDisplay = { ["1_TLEFT"] = true, ["2_TELAPSED"] = true, ["3_STACKS"] = true, ["4_NONE"] = true },
}

local COORDINATE_KEYS = {
    MainBarX = true,
    MainBarY = true,
    DebuffsFrameContainer_x = true,
    DebuffsFrameContainer_y = true,
}

local EXTENSION_SCHEMA = {
    Alert121Color = "color",
    Alert121Point = "anchor",
    Alert121DispelDuration2sMigrated = "boolean",
    Alert121SoulLinkEnabled = "boolean",
    ClearCleansedTarget121Enabled = "boolean",
    DcrIdentityShowAllDebuffs = "boolean",
    DebuffsFramePartyPixelSize121 = "number",
    DebuffsFrameRaidPixelSize121 = "number",
    Detection121Mode = "string",
    EnvironmentChat121Enabled = "boolean",
    LineOfSight121Color = "color",
    LineOfSight121Enabled = "boolean",
    LineOfSight121HoldSeconds = "number",
    LineOfSight121Opacity = "number",
    OpenWorldRangeDisabled121Migrated = "boolean",
    PreviousMacroKeyAction = "string_or_false",
    PvPTextAlertsDefaultOff121Migrated = "boolean",
    RemainingTargetCooldown121Migrated = "boolean",
    SharedPriorityCooldown121Enabled = "boolean",
    SoulLink121Enabled = "boolean",
    V11WindowWidth = "number",
    V11WindowHeight = "number",
    MacroBind = "string_or_false",
}

local LIST_KEYS = {
    PriorityList = true,
    SkipList = true,
}

local LOOKUP_KEYS = {
    PriorityListClass = true,
    PrioGUIDtoNAME = true,
    SkipListClass = true,
    SkipGUIDtoNAME = true,
}

local BOOLEAN_MAP_KEYS = {
    DebuffsToIgnore = true,
    BuffDebuff = true,
    DebuffAlwaysSkipList = true,
}

local function settingPath(path, key)
    return path .. "." .. tostring(key)
end

local function validateNumber(key, value, path)
    if not finiteNumber(value) then return nil, path .. " must be a finite number" end
    local range = NUMBER_RANGES[key]
    local minimum = range and range[1] or -1000000
    local maximum = range and range[2] or 1000000
    if value < minimum or value > maximum then
        return nil, path .. " is outside the supported range"
    end
    if range and range[3] and value % 1 ~= 0 then
        return nil, path .. " must be a whole number"
    end
    return value
end

local function validateColor(value, fallback, path)
    if type(value) ~= "table" then return nil, path .. " must be a color table" end
    local result = cloneValue(fallback or { 1, 1, 1, 1 })
    local componentCount = #result
    if componentCount ~= 3 and componentCount ~= 4 then componentCount = 4 end

    for key, component in pairs(value) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > componentCount then
            return nil, path .. " contains an invalid color component"
        end
        if not finiteNumber(component) or component < 0 or component > 1 then
            return nil, settingPath(path, key) .. " must be between 0 and 1"
        end
        result[key] = component
    end
    return result
end

local function isColorDefault(value)
    if type(value) ~= "table" then return false end
    local count = #value
    if count ~= 3 and count ~= 4 then return false end
    for key, component in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > count or type(component) ~= "number" then return false end
    end
    return true
end

local validateAgainstDefault

local function mergeFixedTable(defaults, imported, path, context)
    if type(imported) ~= "table" then return nil, path .. " must be a table" end
    if isColorDefault(defaults) then return validateColor(imported, defaults, path) end

    local result = cloneValue(defaults)
    for key, value in pairs(imported) do
        if defaults[key] ~= nil then
            local validated, err = validateAgainstDefault(value, defaults[key], key, settingPath(path, key), context)
            if err then return nil, err end
            result[key] = validated
        else
            context.ignored = context.ignored + 1
        end
    end
    return result
end

validateAgainstDefault = function(value, defaultValue, key, path, context)
    local expectedType = type(defaultValue)
    if expectedType == "table" then
        return mergeFixedTable(defaultValue, value, path, context)
    end

    if COORDINATE_KEYS[key] and value == false then return false end
    if COORDINATE_KEYS[key] and type(value) == "number" then
        return validateNumber(key, value, path)
    end
    if type(value) ~= expectedType then
        return nil, path .. " has the wrong value type"
    end
    if expectedType == "number" then return validateNumber(key, value, path) end
    if expectedType == "string" then
        local allowed = ENUM_VALUES[key]
        if allowed and not allowed[value] then return nil, path .. " has an unsupported value" end
    end
    return value
end

local function validateList(imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a list" end
    local result = {}
    local count = 0
    local maximumIndex = 0
    for key, value in pairs(imported) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > MAX_LIST_ENTRIES then
            return nil, path .. " contains an invalid list index"
        end
        if type(value) == "string" then
            if #value > MAX_KEY_BYTES then return nil, settingPath(path, key) .. " is too long" end
        elseif type(value) == "number" then
            if not finiteNumber(value) or value % 1 ~= 0 or value < -1000 or value > 1000 then
                return nil, settingPath(path, key) .. " is not a supported list entry"
            end
        else
            return nil, settingPath(path, key) .. " has the wrong value type"
        end
        result[key] = value
        count = count + 1
        if key > maximumIndex then maximumIndex = key end
    end
    if count ~= maximumIndex then return nil, path .. " must not contain gaps" end
    return result
end

local function validateLookup(imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a lookup table" end
    local result = {}
    local count = 0
    for key, value in pairs(imported) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then return nil, path .. " contains an invalid key" end
        if keyType == "number" and (not finiteNumber(key) or key % 1 ~= 0 or key < -1000 or key > 1000) then
            return nil, path .. " contains an invalid numeric key"
        end
        if type(value) ~= "string" or #value > MAX_KEY_BYTES then
            return nil, settingPath(path, key) .. " must be a short string"
        end
        result[key] = value
        count = count + 1
        if count > 300 then return nil, path .. " contains too many entries" end
    end
    return result
end

local function mergeBooleanMap(defaults, imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a lookup table" end
    local result = cloneValue(defaults)
    for key, value in pairs(imported) do
        if type(key) ~= "string" or #key > MAX_KEY_BYTES or type(value) ~= "boolean" then
            return nil, path .. " contains an invalid entry"
        end
        result[key] = value
    end
    return result
end

local function mergeDebuffMap(defaults, imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a lookup table" end
    local result = cloneValue(defaults)
    for key, value in pairs(imported) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then return nil, path .. " contains an invalid key" end
        if keyType == "number" and (not finiteNumber(key) or key % 1 ~= 0 or key < 1 or key > 2147483647) then
            return nil, path .. " contains an invalid legacy index"
        end
        local valueType = type(value)
        if valueType == "number" then
            if not finiteNumber(value) or value % 1 ~= 0 or value < 0 or value > 2147483647 then
                return nil, settingPath(path, key) .. " contains an invalid spell ID"
            end
        elseif valueType == "string" then
            if #value > MAX_KEY_BYTES then return nil, settingPath(path, key) .. " is too long" end
        elseif valueType ~= "boolean" then
            return nil, settingPath(path, key) .. " has the wrong value type"
        end
        result[key] = value
    end
    return result
end

local function mergeSkipByClass(defaults, imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a lookup table" end
    local result = cloneValue(defaults)
    for classToken, entries in pairs(imported) do
        if type(classToken) ~= "string" or #classToken > 32 or type(entries) ~= "table" then
            return nil, path .. " contains an invalid class entry"
        end
        local classResult = cloneValue(result[classToken] or {})
        for debuffName, enabled in pairs(entries) do
            if type(debuffName) ~= "string" or #debuffName > MAX_KEY_BYTES or type(enabled) ~= "boolean" then
                return nil, settingPath(path, classToken) .. " contains an invalid debuff entry"
            end
            classResult[debuffName] = enabled
        end
        result[classToken] = classResult
    end
    return result
end

local function mergeMFColors(defaults, imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a color lookup" end
    local result = cloneValue(defaults)
    for key, color in pairs(imported) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then return nil, path .. " contains an invalid color key" end
        local fallback = result[key] or { 1, 1, 1, 1 }
        local validated, err = validateColor(color, fallback, settingPath(path, key))
        if err then return nil, err end
        result[key] = validated
    end
    return result
end

local function mergeTypeColors(defaults, imported, path)
    if type(imported) ~= "table" then return nil, path .. " must be a color lookup" end
    local result = cloneValue(defaults)
    for key, color in pairs(imported) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 0 or key > 65535 then
            return nil, path .. " contains an invalid affliction type"
        end
        if type(color) ~= "string" or not color:match("^%x%x%x%x%x%x%x%x$") then
            return nil, settingPath(path, key) .. " must be an eight-digit hexadecimal color"
        end
        result[key] = color
    end
    return result
end

local function mergeMinimapSettings(defaults, imported, path, context)
    if type(imported) ~= "table" then return nil, path .. " must be a table" end
    local result = cloneValue(defaults)
    local booleanKeys = { hide = true, lock = true, showInCompartment = true }
    for key, value in pairs(imported) do
        if booleanKeys[key] then
            if type(value) ~= "boolean" then return nil, settingPath(path, key) .. " must be true or false" end
            result[key] = value
        elseif key == "minimapPos" then
            local validated, err = validateNumber(nil, value, settingPath(path, key))
            if err or validated < 0 or validated > 360 then return nil, settingPath(path, key) .. " is outside the supported range" end
            result[key] = validated
        elseif key == "radius" then
            local validated, err = validateNumber(nil, value, settingPath(path, key))
            if err or validated < 0 or validated > 200 then return nil, settingPath(path, key) .. " is outside the supported range" end
            result[key] = validated
        else
            context.ignored = context.ignored + 1
        end
    end
    return result
end

local ANCHOR_POINTS = {
    TOP = true, TOPLEFT = true, TOPRIGHT = true,
    BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
    LEFT = true, RIGHT = true, CENTER = true,
}

local function validateAnchor(imported, path, context)
    if type(imported) ~= "table" then return nil, path .. " must be an anchor table" end
    local result = { point = "CENTER", x = 0, y = 0 }
    for key, value in pairs(imported) do
        if key == "point" then
            if type(value) ~= "string" or not ANCHOR_POINTS[value] then return nil, settingPath(path, key) .. " is invalid" end
            result.point = value
        elseif key == "x" or key == "y" then
            local validated, err = validateNumber(nil, value, settingPath(path, key))
            if err or validated < -100000 or validated > 100000 then return nil, settingPath(path, key) .. " is outside the supported range" end
            result[key] = validated
        else
            context.ignored = context.ignored + 1
        end
    end
    return result
end

local function validateExtension(key, value, path, context)
    local schema = EXTENSION_SCHEMA[key]
    if schema == "boolean" then
        if type(value) ~= "boolean" then return nil, path .. " must be true or false" end
        return value
    elseif schema == "number" then
        return validateNumber(key, value, path)
    elseif schema == "string" then
        if type(value) ~= "string" then return nil, path .. " must be a string" end
        local allowed = ENUM_VALUES[key]
        if allowed and not allowed[value] then return nil, path .. " has an unsupported value" end
        return value
    elseif schema == "string_or_false" then
        if value == false then return false end
        if type(value) ~= "string" or #value > MAX_KEY_BYTES then return nil, path .. " must be false or a short string" end
        return value
    elseif schema == "color" then
        return validateColor(value, { 1, 1, 1 }, path)
    elseif schema == "anchor" then
        return validateAnchor(value, path, context)
    end
    return nil, path .. " has no supported schema"
end

local function buildValidatedProfile(addon, imported)
    if type(addon.defaults) ~= "table" or type(addon.defaults.profile) ~= "table" then
        return nil, "Decursive profile defaults are unavailable"
    end

    local defaults = cloneValue(addon.defaults.profile)
    if type(addon.Environment121Defaults) == "table" then
        defaults.Environment121Profiles = cloneValue(addon.Environment121Defaults)
    end

    local result = cloneValue(defaults)
    local context = { ignored = 0 }
    for key, value in pairs(imported) do
        if type(key) ~= "string" then
            context.ignored = context.ignored + 1
        elseif LIST_KEYS[key] then
            local validated, err = validateList(value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif LOOKUP_KEYS[key] then
            local validated, err = validateLookup(value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif BOOLEAN_MAP_KEYS[key] then
            local validated, err = mergeBooleanMap(defaults[key] or {}, value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif key == "DebuffsSkipList" then
            local validated, err = mergeDebuffMap(defaults[key] or {}, value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif key == "skipByClass" then
            local validated, err = mergeSkipByClass(defaults[key] or {}, value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif key == "MF_colors" then
            local validated, err = mergeMFColors(defaults[key] or {}, value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif key == "TypeColors" then
            local validated, err = mergeTypeColors(defaults[key] or {}, value, "profile." .. key)
            if err then return nil, err end
            result[key] = validated
        elseif key == "MiniMapIcon" then
            local validated, err = mergeMinimapSettings(defaults[key] or {}, value, "profile." .. key, context)
            if err then return nil, err end
            result[key] = validated
        elseif defaults[key] ~= nil then
            local validated, err = validateAgainstDefault(value, defaults[key], key, "profile." .. key, context)
            if err then return nil, err end
            result[key] = validated
        elseif EXTENSION_SCHEMA[key] then
            local validated, err = validateExtension(key, value, "profile." .. key, context)
            if err then return nil, err end
            result[key] = validated
        else
            -- Old profile exports can retain settings removed by later releases.
            -- They are accepted for compatibility but never applied blindly.
            context.ignored = context.ignored + 1
        end
    end

    return result, nil, context.ignored
end

local function shortError(value)
    local message = tostring(value or "unknown error"):gsub("[\r\n]+", " ")
    if #message > 300 then message = message:sub(1, 300) .. "..." end
    return message
end

function D:GetProfileExportString()
    if not Serializer or not self.db or type(self.db.profile) ~= "table" then
        return ""
    end

    local payload = {
        format = FORMAT,
        version = FORMAT_VERSION,
        addon = "Decursive",
        addonVersion = self.version or "unknown",
        interface = select(4, GetBuildInfo()),
        profileName = self.db:GetCurrentProfile(),
        profile = self.db.profile,
    }

    local ok, serialized = pcall(Serializer.Serialize, Serializer, payload)
    if not ok then
        self.ProfileIOStatus = "|cffff3333Export failed:|r " .. tostring(serialized)
        return ""
    end
    self.ProfileIOStatus = "|cff55ff55Profile export ready.|r"
    return serialized
end

function D:SetProfileImportBuffer(text)
    self.ProfileImportBuffer = type(text) == "string" and text or ""
end

function D:GetProfileImportBuffer()
    return self.ProfileImportBuffer or ""
end

function D:ImportProfileString(text)
    if InCombatLockdown() then
        self.ProfileIOStatus = "|cffff3333Profiles cannot be imported during combat.|r"
        return false
    end
    if not Serializer then
        self.ProfileIOStatus = "|cffff3333AceSerializer-3.0 is unavailable.|r"
        return false
    end
    if type(text) ~= "string" or text:match("^%s*$") then
        self.ProfileIOStatus = "|cffff3333Paste a Decursive profile string first.|r"
        return false
    end
    if #text > MAX_IMPORT_BYTES then
        self.ProfileIOStatus = "|cffff3333Import failed:|r the profile string is too large."
        return false
    end
    if not self.db or type(self.db.profile) ~= "table" or type(self.SetConfiguration) ~= "function" then
        self.ProfileIOStatus = "|cffff3333Import failed:|r Decursive is not ready to apply a profile."
        return false
    end

    local wireOK, wireError = inspectSerializedText(text)
    if not wireOK then
        self.ProfileIOStatus = "|cffff3333Import failed:|r " .. shortError(wireError) .. "."
        return false
    end

    local callOK, deserializeOK, payload = pcall(Serializer.Deserialize, Serializer, text)
    if not callOK or not deserializeOK then
        self.ProfileIOStatus = "|cffff3333Import failed:|r invalid serialized data."
        return false
    end
    if type(payload) ~= "table" or payload.format ~= FORMAT or payload.version ~= FORMAT_VERSION or type(payload.profile) ~= "table" then
        self.ProfileIOStatus = "|cffff3333Import failed:|r this is not a supported Decursive profile export."
        return false
    end

    local graphOK, graphError = inspectSerializedGraph(payload)
    if not graphOK then
        self.ProfileIOStatus = "|cffff3333Import failed:|r " .. shortError(graphError) .. "."
        return false
    end

    local candidate, validationError, ignored = buildValidatedProfile(self, payload.profile)
    if not candidate then
        self.ProfileIOStatus = "|cffff3333Import failed:|r " .. shortError(validationError) .. "."
        return false
    end

    local previousProfile = cloneValue(self.db.profile)
    local previousCatchAllErrors = T._CatchAllErrors
    local applyOK, applyError = pcall(function()
        -- Preserve AceDB's profile table identity; several parts of Decursive
        -- cache D.profile and expect that root object to remain stable.
        copyInto(self.db.profile, candidate)
        if self:SetConfiguration() ~= true then
            error("SetConfiguration did not complete", 0)
        end
    end)
    T._CatchAllErrors = previousCatchAllErrors

    if not applyOK then
        local rollbackOK, rollbackError = pcall(function()
            copyInto(self.db.profile, previousProfile)
            if self:SetConfiguration() ~= true then
                error("SetConfiguration did not complete while restoring the previous profile", 0)
            end
        end)
        T._CatchAllErrors = previousCatchAllErrors

        if rollbackOK then
            self.ProfileIOStatus = "|cffff3333Import failed; the previous profile was restored:|r " .. shortError(applyError)
        else
            self.ProfileIOStatus = "|cffff3333Import and rollback both failed. Reload the UI before changing settings:|r "
                .. shortError(applyError) .. " / " .. shortError(rollbackError)
        end
        return false
    end

    self.ProfileImportBuffer = ""
    if ignored and ignored > 0 then
        self.ProfileIOStatus = ("|cff55ff55Profile imported successfully.|r %d obsolete or unsupported setting(s) were ignored."):format(ignored)
    else
        self.ProfileIOStatus = "|cff55ff55Profile imported successfully.|r"
    end
    return true
end

function D:GetProfileIOStatus()
    return self.ProfileIOStatus or "Exports contain only the active AceDB profile. Global, locale, and class-scoped data are not overwritten."
end
