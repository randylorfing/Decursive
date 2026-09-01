local function readFile(path)
    if type(readfile) == "function" then
        return assert(readfile(path))
    end
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local function contains(text, needle, label)
    assert(text:find(needle, 1, true), label or ("missing " .. needle))
end

local function excludes(text, needle, label)
    assert(not text:find(needle, 1, true), label or ("unexpected " .. needle))
end

local initSource = readFile("Decursive/DCR_init.lua")
local frameSource = readFile("Decursive/Dcr_DebuffsFrame.lua")
local eventSource = readFile("Decursive/Dcr_Events.lua")
local diagSource = readFile("Decursive/Decursive.lua")
local schedulerSource = readFile("Decursive/V13/Core/CombatScheduler.lua")

-- Source contracts: recovery is one ordered PLAYER_REGEN_ENABLED flush.
contains(initSource, "function D:RecoverSecureMUFsAfterCombat(reason)")
contains(initSource, "function D:MarkConfigurationReady(reason)")
contains(initSource, "D.Status.ConfigureComplete = false")
contains(initSource, "self.Status.ConfigureComplete = true")
contains(initSource, "if D.Status.ConfigureComplete then")
contains(initSource, 'D:MarkConfigurationReady("SetConfiguration")')
excludes(initSource, "D.DcrFullyInitialized = true; -- everything should be OK")

contains(eventSource, "self:RecoverSecureMUFsAfterCombat(\"PLAYER_REGEN_ENABLED\")")
local regenStart = assert(eventSource:find("function D:PLAYER_REGEN_ENABLED()", 1, true))
local regenProfile = assert(eventSource:find("if self.ProfileManager then", regenStart, true))
assert(eventSource:find("RecoverSecureMUFsAfterCombat", regenStart, true) < regenProfile,
    "PLAYER_REGEN_ENABLED must recover MUFs before other regen flushes")

contains(diagSource, "initialized=%s | configure=%s | combat=%s")
contains(diagSource, "status.ConfigureComplete == true")

-- Create queues self so a delayed factory is not Create(Unit, ID).
local createStart = assert(frameSource:find("function MicroUnitF:Create(Unit, ID)", 1, true))
local createEnd = assert(frameSource:find("function MicroUnitF:MFUsableNumber", createStart, true))
local createSource = frameSource:sub(createStart, createEnd - 1)
contains(createSource, "self, Unit, ID")
excludes(createSource, "\"Create\"..Unit, self.Create,\n        Unit, ID")

-- Init must not EnableMouse / Hide the protected MUF tree in lockdown.
local initFnStart = assert(initSource:find("function D:Init()", 1, true))
local initFnEnd = assert(initSource:find("function D:ReConfigure()", initFnStart, true))
local initFn = initSource:sub(initFnStart, initFnEnd - 1)
contains(initFn, "elseif not (InCombatLockdown and InCombatLockdown()) then")
contains(initFn, "D.MFContainer:Hide()")
contains(initFn, "Dcr_InitMUFHandleMouse")
assert(initFn:find("EnableMouse(not D.profile.HideMUFsHandle)", 1, true),
    "Init still applies handle mouse state out of combat")

-- Pre-existing combat clicks stay installed: attribute writes stay gated.
local attribStart = assert(frameSource:find("function MicroUnitF.prototype:SetUnstableAttribute", 1, true))
local attribEnd = assert(frameSource:find("function MicroUnitF.prototype:SetDebuffs", attribStart, true))
local attribSource = frameSource:sub(attribStart, attribEnd - 1)
contains(attribSource, "if InCombatLockdown and InCombatLockdown() then return false; end")
contains(attribSource, "if InCombatLockdown() then")
excludes(attribSource, "UnitIsDeadOrGhost")

-- Do not add a CombatScheduler MUF recovery consumer.
excludes(schedulerSource, "RecoverSecureMUFsAfterCombat")
excludes(schedulerSource, "MicroUnitF")
excludes(initSource, "RunOrDefer")
excludes(eventSource, "RunOrDefer")
excludes(eventSource, "CombatScheduler")

-- Behavioral mock: combat /reload then regen recovers in a defined order.
local recoverStart = assert(initSource:find("function D:RecoverSecureMUFsAfterCombat(reason)", 1, true))
local recoverEnd = assert(initSource:find("function D:SetSpellsTranslations", recoverStart, true))
-- RecoverSecureMUFsAfterCombat sits before SetSpellsTranslations only if we
-- inserted it immediately after Configure. Fall back to the next top-level
-- function if the file order changes.
if recoverEnd < recoverStart then
    recoverEnd = #initSource
end

local combatLocked = true
local order = {}
local setAttributeCalls = {}
local createCalls = {}
local configureCalls = 0
local setCureOrderCalls = 0
local smartRezRebuilds = 0

function InCombatLockdown()
    return combatLocked
end

D = {
    DcrFullyInitialized = false,
    Groups_datas_are_invalid = true,
    profile = { ShowDebuffsFrame = true },
    Status = {
        ConfigureComplete = false,
        prio_macro = {},
        Unit_Array = { "player", "party1" },
        UnitNum = 2,
        SmartRezActions = nil,
    },
    MicroUnitF = {
        MaxUnit = 40,
        ExistingPerUNIT = {},
        Show = function(self)
            assert(not InCombatLockdown(), "Show must not mutate the protected tree in lockdown")
            order[#order + 1] = "Show"
            return true
        end,
        Create = function(self, unit, id)
            if InCombatLockdown() then
                order[#order + 1] = "Create-deferred"
                return false
            end
            assert(self == D.MicroUnitF, "Create must receive MicroUnitF as self")
            createCalls[#createCalls + 1] = { unit = unit, id = id }
            order[#order + 1] = "Create:" .. tostring(unit)
            local MF = {
                CurrUnit = unit,
                attributes = {},
                UpdateAttributes = function(mf, appliedUnit, doNotDelay)
                    if InCombatLockdown() then
                        order[#order + 1] = "UpdateAttributes-skipped"
                        return false
                    end
                    assert(D.Status.ConfigureComplete == true, "UpdateAttributes before Configure completed")
                    assert(D.Status.SmartRezActions ~= nil, "UpdateAttributes before SmartRez rebuild")
                    assert(D.Status.prio_macro[1] ~= nil, "UpdateAttributes before SetCureOrder")
                    assert(D.Status.prio_macro[1].smartRezAvailable == true,
                        "first post-regen UpdateAttributes installed cure-only macros")
                    mf.attributes.macrotext = D.Status.prio_macro[1].macroText
                    mf.attributes.unit = appliedUnit
                    order[#order + 1] = "UpdateAttributes:" .. tostring(appliedUnit)
                    return mf
                end,
            }
            self.ExistingPerUNIT[unit] = MF
            return MF
        end,
        MFsDisplay_Update = function()
            order[#order + 1] = "MFsDisplay_Update"
            return true
        end,
    },
}

function D:Configure()
    if InCombatLockdown() then
        self.Status.ConfigureComplete = false
        order[#order + 1] = "Configure-deferred"
        return false
    end
    configureCalls = configureCalls + 1
    order[#order + 1] = "Configure"
    self.Status.ConfigureComplete = true
    self:GetSmartRezActions()
    self:SetCureOrder()
    return true
end

function D:GetSmartRezActions()
    if InCombatLockdown() then
        if type(self.Status.SmartRezActions) == "table" then
            return self.Status.SmartRezActions.battleRezName,
                self.Status.SmartRezActions.outOfCombatRezName,
                self.Status.SmartRezActions.combatSoulLink,
                self.Status.SmartRezActions.outOfCombatSoulLink
        end
        return nil, nil, false, false
    end
    smartRezRebuilds = smartRezRebuilds + 1
    self.Status.SmartRezActions = {
        battleRezName = nil,
        outOfCombatRezName = "Resurrection",
        combatSoulLink = true,
        outOfCombatSoulLink = false,
    }
    order[#order + 1] = "GetSmartRezActions"
    return nil, "Resurrection", true, false
end

function D:SetCureOrder()
    setCureOrderCalls = setCureOrderCalls + 1
    local battleRezName, outOfCombatRezName, combatSoulLink = self:GetSmartRezActions()
    local hasRez = battleRezName ~= nil or outOfCombatRezName ~= nil or combatSoulLink
    self.Status.prio_macro[1] = {
        macroText = hasRez and "/cast [@mouseover,help,exists,dead,nocombat] Resurrection\n/cast [@mouseover,help,exists,nodead] Cleanse" or "/cast [@mouseover] Cleanse",
        cureOnlyMacroText = "/cast [@mouseover] Cleanse",
        smartRezAvailable = hasRez == true,
        binding = "*%s1",
    }
    order[#order + 1] = hasRez and "SetCureOrder:rez" or "SetCureOrder:cure-only"
end

function D:MarkConfigurationReady()
    if InCombatLockdown() then return false end
    if not (self.Status and self.Status.ConfigureComplete) then return false end
    local firstReady = not self.DcrFullyInitialized
    self.DcrFullyInitialized = true
    order[#order + 1] = firstReady and "MarkConfigurationReady:first" or "MarkConfigurationReady:repeat"
    return true
end

function D:GetUnitArray()
    order[#order + 1] = "GetUnitArray"
    self.Groups_datas_are_invalid = false
end

function D:AddDelayedFunctionCall()
end

local recoverSource = initSource:sub(recoverStart, recoverEnd - 1)
-- The extracted body references MarkConfigurationReady and helpers that the
-- mock already defines. Load only the recovery function.
local loader = loadstring or load
assert(loader(recoverSource, "recover-secure-mufs"))()

-- InCombatLockdown skips Create / SetAttribute / recovery writes.
combatLocked = true
D.DcrFullyInitialized = false
D.Status.ConfigureComplete = false
D.Status.prio_macro = {}
D.Status.SmartRezActions = nil
assert(D:RecoverSecureMUFsAfterCombat("combat") == false)
assert(D.DcrFullyInitialized == false, "initialized=yes must not mean Configure succeeded")
assert(D.Status.ConfigureComplete == false)
assert(next(D.MicroUnitF.ExistingPerUNIT) == nil, "Create must not run in lockdown")
assert(#setAttributeCalls == 0)

-- Combat /reload: Configure deferred, squares absent, empty SmartRez cache.
assert(D:Configure() == false)
assert(D:GetSmartRezActions() == nil)
assert(D.Status.SmartRezActions == nil)
D.MicroUnitF:Create("player", 1)
assert(D.MicroUnitF.ExistingPerUNIT.player == nil)

-- Regen: ordered Configure/SetCureOrder then Show/Create then UpdateAttributes.
order = {}
combatLocked = false
assert(D:RecoverSecureMUFsAfterCombat("PLAYER_REGEN_ENABLED") == true)
assert(D.Status.ConfigureComplete == true)
assert(D.DcrFullyInitialized == true)
assert(configureCalls == 1)
assert(smartRezRebuilds >= 1)
assert(setCureOrderCalls >= 1)
assert(D.MicroUnitF.ExistingPerUNIT.player, "player MUF missing after regen")
assert(D.MicroUnitF.ExistingPerUNIT.party1, "party1 MUF missing after regen")
assert(D.MicroUnitF.ExistingPerUNIT.player.attributes.macrotext:find("Resurrection", 1, true),
    "installed macrotext is cure-only after regen")
assert(D.MicroUnitF.ExistingPerUNIT.party1.attributes.macrotext:find("Resurrection", 1, true))

local function firstIndex(label)
    for i, step in ipairs(order) do
        if step == label or step:sub(1, #label) == label then
            return i
        end
    end
    error("missing recovery step " .. label)
end

local configureAt = firstIndex("Configure")
local rezAt = firstIndex("SetCureOrder:rez")
local showAt = firstIndex("Show")
local createAt = firstIndex("Create:")
local attribAt = firstIndex("UpdateAttributes:")
assert(configureAt < rezAt, "SetCureOrder must follow Configure on first recovery")
assert(rezAt < showAt, "Show must follow Configure/SetCureOrder")
assert(showAt < createAt, "Create must follow Show")
assert(createAt < attribAt, "UpdateAttributes must follow Create")
excludes(table.concat(order, ","), "SetCureOrder:cure-only",
    "empty in-combat SmartRez cache leaked into the first post-regen apply")

-- Pre-existing in-combat clicks: installed macrotext is left alone in lockdown.
combatLocked = true
local preexisting = D.MicroUnitF.ExistingPerUNIT.player.attributes.macrotext
local gated = {
    Frame = {
        SetAttribute = function(_, key, value)
            setAttributeCalls[#setAttributeCalls + 1] = { key = key, value = value }
        end,
    },
    usedAttributes = {},
    LastAttribUpdate = 0,
}
function gated:SetUnstableAttribute(attribute, value)
    if InCombatLockdown and InCombatLockdown() then return false end
    self.Frame:SetAttribute(attribute, value)
    return true
end
assert(gated:SetUnstableAttribute("macrotext", "should-not-write") == false)
assert(#setAttributeCalls == 0)
assert(D.MicroUnitF.ExistingPerUNIT.player.attributes.macrotext == preexisting)

-- Already-configured regen still rebuilds SmartRez before UpdateAttributes.
combatLocked = false
D.Status.SmartRezActions = nil
D.Status.prio_macro = {}
order = {}
assert(D:RecoverSecureMUFsAfterCombat("PLAYER_REGEN_ENABLED") == true)
assert(firstIndex("GetSmartRezActions") < firstIndex("SetCureOrder:rez"))
assert(firstIndex("SetCureOrder:rez") < firstIndex("UpdateAttributes:"))
assert(D.Status.prio_macro[1].smartRezAvailable == true)

io.write("PASS: combat /reload MUF recovery order, lockdown skips, and H3 rez rebuild\n")
