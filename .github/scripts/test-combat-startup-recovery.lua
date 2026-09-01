local function readFile(path)
    if type(_G.readfile) == "function" then return assert(_G.readfile(path)) end
    local handle, openError = io.open(path, "rb")
    assert(handle, openError)
    local text, readError = handle:read("*a")
    local closed, closeError = handle:close()
    assert(text, readError)
    assert(closed, closeError)
    return text
end

local function markedSection(source, firstMarker, lastMarker)
    local first = assert(source:find(firstMarker, 1, true), "missing " .. firstMarker)
    local last = assert(source:find(lastMarker, first, true), "missing " .. lastMarker)
    local bodyStart = assert(source:find("\n", first, true)) + 1
    return source:sub(bodyStart, last - 1)
end

local function before(source, first, second, label)
    local firstAt = assert(source:find(first, 1, true), "missing " .. first)
    local secondAt = assert(source:find(second, 1, true), "missing " .. second)
    assert(firstAt < secondAt, label or (first .. " must precede " .. second))
end

local initSource = readFile("Decursive/DCR_init.lua")
local eventSource = readFile("Decursive/Dcr_Events.lua")
local mufSource = readFile("Decursive/Dcr_DebuffsFrame.lua")
local raidSource = readFile("Decursive/Dcr_Raid.lua")
local optionSource = readFile("Decursive_Options/V13/Pages/MUFs.lua")

local setConfigurationStart = assert(initSource:find("function D:SetConfiguration()", 1, true))
local statusReset = assert(initSource:find("D.Status = {}", setConfigurationStart, true))
local combatGuard = assert(initSource:find("return D:RequestConfigurationAfterCombat(\"SetConfiguration\")", setConfigurationStart, true))
assert(combatGuard < statusReset, "SetConfiguration must stop before clearing runtime and secure macro state")
before(initSource, "local configured = D:Init()", "D.DcrFullyInitialized = true", "initialization must follow successful Init/Configure")
before(initSource, "if InCombatLockdown and InCombatLockdown() then\n        return D:RequestConfigurationAfterCombat(\"Init\")", "D.MicroUnitF:Show()", "Init must guard protected visibility before touching the MUF tree")
assert(initSource:find("local configured = D:Configure()", 1, true))
assert(initSource:find("if configured ~= true then return false end", 1, true))

before(eventSource, "self.ProfileManager:HandleCombatEnded()", "self:RunPostCombatRecovery(\"PLAYER_REGEN_ENABLED\")")
before(eventSource, "self:RunPostCombatRecovery(\"PLAYER_REGEN_ENABLED\")", "self:FlushModernSecureUIDirty(\"PLAYER_REGEN_ENABLED\")")
assert(eventSource:find("for Id, FuncAndArgs in pairs (status.DelayedFunctionCalls) do", 1, true), "unrelated legacy queue must remain isolated")
assert(mufSource:find('"Create"..Unit, self.Create,\n        self, Unit, ID)', 1, true), "delayed Create must retain its receiver")
before(raidSource, "if InCombatLockdown and InCombatLockdown() then\n        self.PendingMUFOrderMode = mode", "self.profile.MUFOrderMode = mode", "MUF order must not persist while layout is protected")
assert(raidSource:find("function D:ApplyPendingMUFOrderMode()", 1, true))
assert(optionSource:find("MUF order will be applied after combat.", 1, true))

local coordinatorSource = markedSection(initSource, "-- DCR_COMBAT_RECOVERY_BEGIN", "-- DCR_COMBAT_RECOVERY_END")
local mufRecoverySource = markedSection(mufSource, "-- DCR_COMBAT_MUF_RECOVERY_BEGIN", "-- DCR_COMBAT_MUF_RECOVERY_END")
local loader = loadstring or load
local combatLocked = true

function InCombatLockdown()
    return combatLocked
end

local function installRuntime()
    D = {}
    MicroUnitF = {
        ExistingPerUNIT = {},
        MaxUnit = 5,
    }
    assert(loader(coordinatorSource, "combat-recovery-coordinator"))()
    assert(loader(mufRecoverySource, "combat-muf-recovery"))()
    D.MicroUnitF = MicroUnitF
    return D, MicroUnitF
end

local runtime, frames = installRuntime()
local priorSecureState = { type = "macro", unit = "party1", macrotext = "/cast Old Cure" }
assert(runtime:RequestConfigurationAfterCombat("combat reload") == false)
assert(runtime.PendingConfigurationAfterCombat == true)
assert(priorSecureState.macrotext == "/cast Old Cure", "combat deferral altered the last valid secure state")

local order = {}
runtime.SetConfiguration = function(self)
    assert(not InCombatLockdown(), "configuration ran in combat")
    order[#order + 1] = "configuration"
    self.profile = { ShowDebuffsFrame = true }
    self.Status = {
        Unit_Array = { "party1" },
        UnitNum = 1,
        prio_macro = {
            [1] = { macroText = "/cast [@party1,help,nodead] Cleanse", binding = "*%s1" },
        },
    }
    self.DcrFullyInitialized = true
    self.PendingConfigurationAfterCombat = nil
    return true
end
runtime.FlushPendingCureBindingRefresh = function()
    order[#order + 1] = "bindings"
    return true
end
frames.PendingContextMUFScale121 = true
frames.ApplyContextMUFScale = function(self)
    order[#order + 1] = "scale"
    self.PendingContextMUFScale121 = nil
    return true
end
runtime.GetPendingMUFOrderMode = function(self)
    return self.pendingOrder
end
runtime.pendingOrder = "RAID"
runtime.ApplyPendingMUFOrderMode = function(self)
    order[#order + 1] = "order"
    self.pendingOrder = nil
    return true
end
runtime.GetUnitArray = function()
    return true
end
frames.Create = function(self, unit, index)
    order[#order + 1] = "create"
    local MF = {
        CurrUnit = unit,
        ID = index,
        Frame = { attributes = {} },
    }
    MF.UpdateAttributes = function(frame)
        order[#order + 1] = "attributes"
        local macro = assert(runtime.Status.prio_macro[1].macroText)
        frame.Frame.attributes.type = "macro"
        frame.Frame.attributes.unit = frame.CurrUnit
        frame.Frame.attributes.macrotext = macro
        return true
    end
    self.ExistingPerUNIT[unit] = MF
    return MF
end
frames.MFsDisplay_Update = function()
    order[#order + 1] = "layout"
    return true
end

combatLocked = false
assert(runtime:RunPostCombatRecovery("PLAYER_REGEN_ENABLED") == true)
assert(runtime.DcrFullyInitialized == true)
assert(runtime.PendingCombatMUFRecovery == nil)
local recovered = assert(frames.ExistingPerUNIT.party1)
assert(recovered.Frame.attributes.type == "macro")
assert(recovered.Frame.attributes.unit == "party1")
assert(type(recovered.Frame.attributes.macrotext) == "string" and recovered.Frame.attributes.macrotext ~= "")
assert(table.concat(order, ",") == "configuration,bindings,scale,order,create,attributes,layout", "unexpected recovery order: " .. table.concat(order, ","))

local failed = installRuntime()
failed.SetConfiguration = function(self)
    self.DcrFullyInitialized = false
    return false
end
failed:RequestConfigurationAfterCombat("forced failure")
assert(failed:RunPostCombatRecovery("PLAYER_REGEN_ENABLED") == false)
assert(failed.DcrFullyInitialized ~= true)
assert(failed.PendingConfigurationAfterCombat == true)
assert(failed.PendingCombatMUFRecovery == true)

io.write("combat startup recovery tests passed\n")
