local function readFile(path)
    if type(io.open) ~= "function" and type(readfile) == "function" then
        return assert(readfile(path))
    end
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local source = readFile("Decursive/Dcr_12_1.lua")
local beginMarker = "-- DCR_NATIVE_DISPEL_FILTER_V1_BEGIN"
local endMarker = "-- DCR_NATIVE_DISPEL_FILTER_V1_END"
local beginAt = assert(source:find(beginMarker, 1, true)) + #beginMarker
local endAt = assert(source:find(endMarker, beginAt, true))
local filterSource = source:sub(beginAt, endAt - 1)

local harness = [[
local inaccessible = {}
local function isAccessiblePublicValue(value)
    return value ~= inaccessible
end
]] .. filterSource .. [[
return getNativeConfiguredDispelFilterString, inaccessible
]]

local loader = loadstring or load
local originalAuraUtil = _G.AuraUtil
local resolveFilter, inaccessible = assert(loader(harness, "muf-native-detection-test"))()

_G.AuraUtil = { AuraFilters = { Dispellable = "DISPELLABLE" } }
assert(resolveFilter() == "HARMFUL|DISPELLABLE")

_G.AuraUtil = nil
assert(resolveFilter() == "HARMFUL|RAID_PLAYER_DISPELLABLE")

_G.AuraUtil = { AuraFilters = { Dispellable = inaccessible } }
assert(resolveFilter() == "HARMFUL|RAID_PLAYER_DISPELLABLE")
_G.AuraUtil = originalAuraUtil

local expectedConsumers = {
    "Native verification AddAuraSlot",
    "Priority AuraContainer AddAuraSlot",
    "Native add detection priority after reconfigure",
    "Native detector AddAuraSlot",
}
for _, label in ipairs(expectedConsumers) do
    local labelAt = assert(source:find(label, 1, true))
    local callEnd = assert(source:find("options", labelAt, true))
    local call = source:sub(labelAt, callEnd)
    assert(call:find("getNativeConfiguredDispelFilterString()", 1, true))
    assert(call:find("AddAuraSlot", 1, true))
end

local detectionAt = assert(source:find("local DISPEL_TYPE_NAME_BY_DT", 1, true))
local detectionEnd = assert(source:find("local pendingNativeAttach", detectionAt, true))
local detectionSource = source:sub(detectionAt, detectionEnd - 1)
for line in detectionSource:gmatch("[^\r\n]+") do
    if not line:match("^%s*%-%-") then
        assert(not line:find("C_UnitAuras", 1, true))
        assert(not line:find("AuraUtil.ForEachAura", 1, true))
        assert(not line:find("UnitAura(", 1, true))
        assert(not line:find("GetAuraData", 1, true))
        assert(not line:find("IsShown(", 1, true))
        assert(not line:find("GetTexture(", 1, true))
    end
end

assert(source:find("candidateFilters = { includeDispelTypes = include }", 1, true))
assert(source:find("candidateFilters = { includeDispelTypes = getPriorityDispelTypeFilter(priority) }", 1, true))

io.stdout:write("OK: native DISPELLABLE gate, RAID fallback, priority type maps, and zero live aura reads\n")
