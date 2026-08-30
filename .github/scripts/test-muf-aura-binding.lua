local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local source = readFile("Decursive/Dcr_12_1.lua")
local beginMarker = "-- DCR_NATIVE_MUF_BINDING_V1_BEGIN"
local endMarker = "-- DCR_NATIVE_MUF_BINDING_V1_END"
local beginAt = assert(source:find(beginMarker, 1, true)) + #beginMarker
local endAt = assert(source:find(endMarker, beginAt, true))
local bindingSource = source:sub(beginAt, endAt - 1)

local harness = [[
local SECRET = {}
local combatLocked = false
local function isAccessiblePublicValue(value)
    return value ~= SECRET
end
local function nativeConfigurationBlocked()
    return combatLocked
end
local function safe(_, fn, ...)
    local ok, a = pcall(fn, ...)
    if not ok then return false end
    return true, a
end
]] .. bindingSource .. [[
return {
    secret = SECRET,
    expected = establishExpectedMUFUnit,
    collect = collectNativeManagedCarriers,
    enable = setNativeContainerEnabled,
    rebind = rebindNativeManagedAuraOwners,
    setCombat = function(value) combatLocked = value end,
}
]]

local loader = loadstring or load
local api = assert(loader(harness, "muf-binding-test"))()

local function newContainer(role)
    local container = {
        role = role,
        calls = 0,
        enabled = true,
        shown = true,
        operations = {},
    }
    function container:SetUnit(unit)
        self.operations[#self.operations + 1] = "SetUnit:" .. unit
        if self.failSetUnit then error("synthetic SetUnit failure") end
        self.calls = self.calls + 1
        self.boundUnit = unit
    end
    function container:SetEnabled(enabled)
        self.operations[#self.operations + 1] = "SetEnabled:" .. tostring(enabled)
        self.enabled = enabled
    end
    function container:Show()
        self.operations[#self.operations + 1] = "Show"
        self.shown = true
    end
    function container:Hide()
        self.operations[#self.operations + 1] = "Hide"
        self.shown = false
    end
    return container
end

local function newMUF(unit)
    return {
        CurrUnit = unit,
        ManagedAuraContainer = newContainer("detector"),
        Decursive121PriorityGateContainers = {
            newContainer("cooldown-1"),
            newContainer("cooldown-2"),
            newContainer("cooldown-3"),
        },
        Decursive121VerificationNativeContainers = {
            newContainer("verification-1"),
            newContainer("verification-2"),
            newContainer("verification-3"),
        },
    }
end

local party1 = newMUF("party1")
local party2 = newMUF("party2")
assert(api.rebind(party1, "party1", false) == true)
assert(api.rebind(party2, "party2", false) == true)

-- Repeating an ordinary update must not churn SetUnit calls.
local party1Calls = party1.ManagedAuraContainer.calls
assert(api.rebind(party1, "party1", false) == true)
assert(party1.ManagedAuraContainer.calls == party1Calls)

-- A stale/wrong caller token cannot replace the MUF's fixed public owner.
assert(api.rebind(party1, "party2", false) == true)
assert(party1.Decursive121ExpectedUnit == "party1")
assert(party1.ManagedAuraContainer.boundUnit == "party1")
assert(party1.Decursive121RejectedUnit == "party2")

-- Model Blizzard's per-unit presence decision. One afflicted unit may activate
-- only its own detector; the other MUF cannot fan out from the same aura.
local afflicted = { party2 = true }
local function detectorVisible(MF)
    return afflicted[MF.ManagedAuraContainer.boundUnit] == true
end
assert(detectorVisible(party1) == false)
assert(detectorVisible(party2) == true)

-- Disable/re-enable restores every unit first, then enables before showing.
local party2Carriers = api.collect(party2)
for i = 1, #party2Carriers do
    local container = party2Carriers[i].container
    api.enable(container, false)
    container.operations = {}
end
assert(api.rebind(party2, "party2", true) == true)
for i = 1, #party2Carriers do
    local container = party2Carriers[i].container
    assert(api.enable(container, true) == true)
    assert(container.operations[1] == "SetUnit:party2")
    assert(container.operations[2] == "SetEnabled:true")
    assert(container.operations[3] == "Show")
end

-- A partial SetUnit failure disables the complete owner bank fail-closed.
party2.Decursive121PriorityGateContainers[2].failSetUnit = true
assert(api.rebind(party2, "party2", true) == false)
assert(party2.Decursive121NativeBindingValid == false)
for i = 1, #party2Carriers do
    local container = party2Carriers[i].container
    assert(container.enabled == false)
    assert(container.shown == false)
end

-- Secret/inaccessible candidates are ignored even outside combat.
local secretMUF = {}
assert(api.expected(secretMUF, api.secret) == nil)
api.setCombat(false)
assert(api.rebind(secretMUF, api.secret, false) == false)

-- The live lifecycle restores unit ownership and filters before enabling.
local applyAt = assert(source:find("function T._ApplyModernSecureUIEnabled121", 1, true))
local shutdownAt = assert(source:find("function D:ShutdownModernSecureUI", applyAt, true))
local lifecycle = source:sub(applyAt, shutdownAt - 1)
local attachAt = assert(lifecycle:find("attachNativeManagedAura(MF, expectedUnit)", 1, true))
local rebindAt = assert(lifecycle:find("rebindNativeManagedAuraOwners(MF, expectedUnit, true)", 1, true))
local filtersAt = assert(lifecycle:find("refreshNativeCarrierFilters(MF)", 1, true))
local enableAt = assert(lifecycle:find("setNativeContainerEnabled(carriers[i].container, true)", 1, true))
assert(attachAt < rebindAt and rebindAt < filtersAt and filtersAt < enableAt)

io.stdout:write("OK: fixed MUF native-owner binding, no fan-out, and lifecycle ordering\n")
