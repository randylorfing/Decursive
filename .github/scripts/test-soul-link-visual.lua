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

local soulLinkSource = readFile("Decursive/Dcr_12_1_SoulLink.lua")
local deathSource = readFile("Decursive/Dcr_12_1.lua")
local initSource = readFile("Decursive/DCR_init.lua")
local optionSource = readFile("Decursive_Options/Dcr_opt_tree.lua")
local readmeSource = readFile("Decursive/README.md")

contains(soulLinkSource, "local actions = D.Status and D.Status.SmartRezActions")
excludes(soulLinkSource, "D:GetSmartRezActions", "runtime must not rebuild smart-rez ownership")
contains(soulLinkSource, "D.HasCarriedSoulLinkItem")
excludes(soulLinkSource, "C_Item.GetItemCount", "visual must use the shared carried-item helper")
excludes(soulLinkSource, "C_Item.GetItemCooldown", "action-slot cooldown must own readiness")
excludes(soulLinkSource, "C_Container.GetItemCooldown", "action-slot cooldown must own readiness")
excludes(soulLinkSource, "C_Spell.IsSpellInRange", "item spell range is not a valid known-spell query")
contains(soulLinkSource, "ActionBar.IsActionInRange")
contains(soulLinkSource, "info.isOnGCD")
excludes(soulLinkSource, "GetActionCooldownDuration", "unsupported action cooldown duration probe must not be used")
contains(soulLinkSource, "GetMacroIndexByName")
contains(soulLinkSource, "GetActionText")
contains(soulLinkSource, "ACTIONBAR_SLOT_CHANGED")
contains(soulLinkSource, "UPDATE_MACROS")
contains(soulLinkSource, "PLAYER_ENTERING_WORLD")
contains(soulLinkSource, "PLAYER_REGEN_ENABLED")
contains(soulLinkSource, "for slot = 1, MAX_ACTION_SLOTS do")
contains(soulLinkSource, "return callBoolean(ActionBar.IsActionInRange, \"range\", soulLinkActionSlot, unit)")
contains(soulLinkSource, "pcall(D.Set121MUFDeathSoulLinkRange, D, MF, inRange)")
contains(soulLinkSource, "DecursiveSoulLinkStatusFrame121")
contains(soulLinkSource, "dcrsoullinkstatus")
contains(soulLinkSource, "LAST DEAD MUF STATE")
contains(soulLinkSource, "existsCategory == \"true\"")
contains(soulLinkSource, "playerCategory == \"true\"")
contains(soulLinkSource, "selfCategory == \"false\"")
excludes(soulLinkSource, "exists == true", "raw unit predicate must not be compared")
excludes(soulLinkSource, "isPlayerUnit == true", "raw unit predicate must not be compared")
excludes(soulLinkSource, "isSelf == false", "raw unit predicate must not be compared")
contains(soulLinkSource, "MF.Decursive121SoulLinkAttemptUnit121 ~= unit")
contains(soulLinkSource, "showAlert(attempt.unit)")
contains(soulLinkSource, "never warn from this generic event")
excludes(soulLinkSource, "SetAttribute", "Soul Link feedback must not mutate secure attributes")
excludes(soulLinkSource, "RegisterForClicks", "Soul Link feedback must not change click registration")
excludes(soulLinkSource, "@mouseover", "Soul Link feedback must not rebuild secure mouseover macros")
contains(optionSource, "simple /use item:269586 macro")
contains(optionSource, "hidden or unselected bar page is fine")
contains(readmeSource, "physically present in your carried bags")
contains(readmeSource, "simple `/use item:269586` macro")

local backdropAt = assert(deathSource:find('overlay:CreateTexture(nil, "BACKGROUND")', 1, true))
local soulLinkAt = assert(deathSource:find('overlay:CreateTexture(nil, "ARTWORK")', backdropAt, true))
local skullAt = assert(deathSource:find('overlay:CreateTexture(nil, "OVERLAY")', soulLinkAt, true))
assert(backdropAt < soulLinkAt and soulLinkAt < skullAt)
contains(deathSource, "soulLinkFill:SetVertexColorFromBoolean(")
contains(deathSource, "soulLinkFill:SetAlphaFromBoolean(value, 1, 0)")
contains(deathSource, "if overlay.EnableMouse then overlay:EnableMouse(false) end")
contains(initSource, "DC.BattleRezSpellIDs = { 20484, 61999, 391054 }")
excludes(initSource:sub(
    assert(initSource:find("DC.BattleRezSpellIDs", 1, true)),
    assert(initSource:find("local function playerKnowsSpell", 1, true))
), "20707", "Soulstone must not be in the native smart-rez action list")

local SECRET_VALUE = setmetatable({}, {
    __tostring = function() error("secret value was coerced to text") end
})
local INACCESSIBLE_VALUE = {}
local combatLocked = false
local itemCount = 1
local rangeValue = true
local rangeThrows = false
local cooldownEnabled = true
local cooldownInfoActive = false
local cooldownOnGCD = false
local cooldownInfoCalls = 0
local lastRangeSlot
local actionInfoReadInCombat = false
local actionSlots = {}
local macroBodies = {}
local actionNames = {}
local macroIndexes = {}
local now = 100
local tickerCallback
local afterCallbacks = {}
local frames = {}
local shownAlert
local units = {}

function canaccessvalue(value)
    return value ~= INACCESSIBLE_VALUE
end

function issecretvalue(value)
    return value == SECRET_VALUE
end

function canaccesstable(value)
    return value ~= INACCESSIBLE_VALUE
end

function issecrettable(value)
    return value == SECRET_VALUE
end

function InCombatLockdown()
    return combatLocked
end

function GetTime()
    now = now + .01
    return now
end

function UnitExists(unit)
    return units[unit] and units[unit].exists
end

function UnitIsPlayer(unit)
    return units[unit] and units[unit].player
end

function UnitIsUnit(unit, other)
    return other == "player" and units[unit] and units[unit].selfUnit or false
end

function UnitIsDeadOrGhost(unit)
    return units[unit] and units[unit].dead
end

UIParent = {}

function CreateFrame(frameType)
    local frame = { scripts = {}, events = {}, shown = false }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:RegisterUnitEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterAllEvents()
        self.events = {}
    end
    function frame:SetScript(script, callback)
        self.scripts[script] = callback
    end
    frames[#frames + 1] = frame
    return frame
end

C_Timer = {
    After = function(_, callback)
        afterCallbacks[#afterCallbacks + 1] = callback
    end,
    NewTicker = function(_, callback)
        tickerCallback = callback
        return { Cancel = function() end }
    end
}

local function flushTimers()
    while #afterCallbacks > 0 do
        local callbacks = afterCallbacks
        afterCallbacks = {}
        for i = 1, #callbacks do callbacks[i]() end
    end
end

local function getActionInfo(slot)
    if combatLocked then
        actionInfoReadInCombat = true
        error("action-slot discovery ran in combat")
    end
    local action = actionSlots[slot]
    if not action then return nil end
    return action.actionType, action.id, action.subType
end

function GetMacroBody(macroID)
    return macroBodies[macroID]
end

function GetMacroIndexByName(name)
    return macroIndexes[name] or 0
end

C_ActionBar = {
    GetActionInfo = getActionInfo,
    GetActionText = function(slot)
        return actionNames[slot]
    end,
    IsActionInRange = function(slot, unit)
        if rangeThrows then error("mock range API error") end
        lastRangeSlot = slot
        assert(type(unit) == "string")
        return rangeValue
    end,
    GetActionCooldown = function(slot)
        assert(actionSlots[slot])
        cooldownInfoCalls = cooldownInfoCalls + 1
        return {
            isEnabled = cooldownEnabled,
            isActive = cooldownInfoActive,
            isOnGCD = cooldownOnGCD
        }
    end
}

C_Item = {
    GetItemCount = function(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)
        assert(itemID == 269586)
        assert(includeBank == false)
        assert(includeUses == false)
        assert(includeReagentBank == false)
        assert(includeAccountBank == false)
        return itemCount
    end
}

SPELL_FAILED_OUT_OF_RANGE = "OUT_OF_RANGE"
ERR_OUT_OF_RANGE = "OUT_OF_RANGE"

local D = {
    version = "v12.1.4-alpha.1",
    profile = {
        SoulLink121Enabled = true,
        Alert121SoulLinkEnabled = true
    },
    Status = {
        SmartRezActions = {
            combatSoulLink = true,
            outOfCombatSoulLink = true
        }
    },
    MicroUnitF = { UnitToMUF = {} }
}

function D:IsMUFRezEligibleUnitToken(unit)
    return type(unit) == "string" and not unit:lower():find("pet", 1, true)
end

function D:HasCarriedSoulLinkItem()
    local count = C_Item.GetItemCount(269586, false, false, false, false)
    return type(count) == "number" and count > 0
end

function D:Clear121MUFDeathSoulLinkRange(MF)
    MF.soulLinkDeathColor = "black"
end

function D:Set121MUFDeathSoulLinkRange(MF, value)
    if issecretvalue(value) then
        MF.soulLinkDeathColor = "secret-forwarded"
    elseif value == true then
        MF.soulLinkDeathColor = "green"
    elseif value == false then
        MF.soulLinkDeathColor = "yellow"
    else
        MF.soulLinkDeathColor = "black"
    end
end

function D:Set121MUFSoulLinkRangeActive(MF, active)
    MF.Decursive121SoulLinkRangeActive = active == true
end

function D:UnitName(unit)
    return unit .. "-name"
end

function D:Show121AlertWarning(message)
    shownAlert = message
end

function D:AlertDiag()
end

actionSlots[149] = { actionType = "item", id = 269586 }

local chunk = assert(loadfile("Decursive/Dcr_12_1_SoulLink.lua"))
chunk("Decursive", { Dcr = D, _C = { TWELVEONE = true, SoulLinkItemID = 269586 } })
flushTimers()
assert(type(tickerCallback) == "function")

local watcher
local failWatcher
for i = 1, #frames do
    local frame = frames[i]
    if frame.events.ACTIONBAR_SLOT_CHANGED then watcher = frame end
    if frame.events.UI_ERROR_MESSAGE then failWatcher = frame end
end
assert(watcher and type(watcher.scripts.OnEvent) == "function")
assert(failWatcher and type(failWatcher.scripts.OnEvent) == "function")

local function setDirectSlot(slot)
    actionSlots = { [slot] = { actionType = "item", id = 269586 } }
    macroBodies = {}
    actionNames = {}
    macroIndexes = {}
    assert(D:Refresh121SoulLinkActionSlot() == true)
    flushTimers()
end

local function fireWatcher(event, ...)
    watcher.scripts.OnEvent(watcher, event, ...)
end

local function resetScenario()
    combatLocked = false
    itemCount = 1
    rangeValue = true
    rangeThrows = false
    cooldownEnabled = true
    cooldownInfoActive = false
    cooldownOnGCD = false
    cooldownInfoCalls = 0
    lastRangeSlot = nil
    actionInfoReadInCombat = false
    shownAlert = nil
    units = {
        party1 = { exists = true, player = true, selfUnit = false, dead = true },
        party2 = { exists = true, player = true, selfUnit = false, dead = true },
        pet1 = { exists = true, player = false, selfUnit = false, dead = true }
    }
    D.profile.SoulLink121Enabled = true
    D.Status.SmartRezActions = {
        combatSoulLink = true,
        outOfCombatSoulLink = true
    }
    setDirectSlot(149)
    local MF = {
        CurrUnit = "party1",
        Shown = true,
        SmartRezLeftEnabled121 = true,
        SmartRezFallbackPriority2Enabled121 = false
    }
    D.MicroUnitF.UnitToMUF = { party1 = MF }
    return MF
end

local function tick()
    cooldownInfoCalls = 0
    tickerCallback()
    assert(cooldownInfoCalls <= 1, "action cooldown queried more than once in one tick")
end

-- A direct item on hidden slot 149 is discovered across all 180 real slots.
local MF = resetScenario()
local slot, kind = D:Get121SoulLinkActionSlot()
assert(slot == 149 and kind == "item")
tick()
assert(MF.soulLinkDeathColor == "green")
assert(lastRangeSlot == 149)
assert(MF.Decursive121SoulLinkRangeActive == false)
assert(MF.Decursive121SoulLinkSmartLeftReady121 == true)
assert(MF.Decursive121SoulLinkAttemptUnit121 == "party1")

rangeValue = false
tick()
assert(MF.soulLinkDeathColor == "yellow")
assert(MF.Decursive121SoulLinkRangeActive == true)

rangeValue = nil
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkRangeActive == false)

rangeValue = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "secret-forwarded")
assert(MF.Decursive121SoulLinkRangeActive == false)
local statusOK, statusText = pcall(D.Get121SoulLinkStatusText, D)
assert(statusOK, "diagnostic formatter coerced a secret value")
contains(statusText, "range=secret")
contains(statusText, "unit tokens only")
excludes(statusText, "party1-name", "diagnostics must never include character names")

MF = resetScenario()
rangeThrows = true
tick()
assert(MF.soulLinkDeathColor == "black")
statusText = D:Get121SoulLinkStatusText()
contains(statusText, "range:error")
contains(statusText, "range:error", "range API error category must be retained")

-- A normal GCD is explicitly identified by public cooldown metadata and must
-- leave Soul Link ready.
MF = resetScenario()
cooldownInfoActive = true
cooldownOnGCD = true
tick()
assert(MF.soulLinkDeathColor == "green")

-- A real item/shared cooldown remains unavailable.
MF = resetScenario()
cooldownInfoActive = true
cooldownOnGCD = false
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)

MF = resetScenario()
cooldownEnabled = false
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
cooldownEnabled = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
cooldownInfoActive = false
tick()
assert(MF.soulLinkDeathColor == "green")

MF = resetScenario()
cooldownInfoActive = true
cooldownOnGCD = nil
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
cooldownInfoActive = true
cooldownOnGCD = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
itemCount = 0
tick()
assert(MF.soulLinkDeathColor == "black")
assert(cooldownInfoCalls == 0)

-- A current-retail macro action can expose resolved item ID 269586 rather
-- than its macro index. Resolve name -> index -> body from a hidden slot.
MF = resetScenario()
actionSlots = { [172] = { actionType = "macro", id = 269586, subType = "item" } }
actionNames = { [172] = "Soul Link" }
macroIndexes = { ["Soul Link"] = 7 }
macroBodies = { [7] = "#showtooltip item:269586\n/use item:269586" }
fireWatcher("UPDATE_MACROS")
flushTimers()
slot, kind = D:Get121SoulLinkActionSlot()
assert(slot == 172 and kind == "macro")
tick()
assert(MF.soulLinkDeathColor == "green")
assert(lastRangeSlot == 172)

-- Conditional/multi-action macros are deliberately not trusted for passive range.
actionSlots = { [172] = { actionType = "macro", id = 269586, subType = "item" } }
actionNames = { [172] = "Complex Soul Link" }
macroIndexes = { ["Complex Soul Link"] = 8 }
macroBodies = { [8] = "#showtooltip\n/use [@mouseover] item:269586\n/cast Resuscitate" }
fireWatcher("UPDATE_MACROS")
flushTimers()
assert(D:Get121SoulLinkActionSlot() == nil)
tick()
assert(MF.soulLinkDeathColor == "black")

-- Prefer the direct item when both a macro and item occupy real slots.
actionSlots = {
    [10] = { actionType = "macro", id = 9 },
    [180] = { actionType = "item", id = 269586 }
}
macroBodies = { [9] = "/use item:269586" }
fireWatcher("ACTIONBAR_SLOT_CHANGED", 180)
flushTimers()
slot, kind = D:Get121SoulLinkActionSlot()
assert(slot == 180 and kind == "item")

-- Action-bar addons can emit slot-change storms for page/mouseover state while
-- protected. Retain the last OOC-verified slot and defer all discovery reads.
MF = resetScenario()
combatLocked = true
fireWatcher("ACTIONBAR_SLOT_CHANGED", 160)
slot, kind = D:Get121SoulLinkActionSlot()
assert(slot == 149 and kind == "item")
assert(actionInfoReadInCombat == false)
tick()
assert(MF.soulLinkDeathColor == "green")
combatLocked = false
actionSlots = { [160] = { actionType = "item", id = 269586 } }
fireWatcher("PLAYER_REGEN_ENABLED")
flushTimers()
slot, kind = D:Get121SoulLinkActionSlot()
assert(slot == 160 and kind == "item")
assert(actionInfoReadInCombat == false)
tick()
assert(MF.soulLinkDeathColor == "green")

-- A world transition also invalidates and discovers the current hidden slot.
actionSlots = { [175] = { actionType = "item", id = 269586 } }
fireWatcher("PLAYER_ENTERING_WORLD")
flushTimers()
assert(D:Get121SoulLinkActionSlot() == 175)

-- No real slot means the dead MUF stays black while secure click behavior is unchanged.
MF = resetScenario()
actionSlots = {}
fireWatcher("ACTIONBAR_SLOT_CHANGED", 149)
flushTimers()
assert(D:Get121SoulLinkActionSlot() == nil)
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)

-- A native shared-charge battle rez owns resurrection; Soul Link stays black.
for _, nativeName in ipairs({ "Rebirth", "Raise Ally", "Intercession" }) do
    MF = resetScenario()
    combatLocked = true
    D.Status.SmartRezActions = {
        battleRezName = nativeName,
        combatSoulLink = false,
        outOfCombatSoulLink = false
    }
    tick()
    assert(MF.soulLinkDeathColor == "black")
    assert(cooldownInfoCalls == 0)
end

-- Monk precedence: Resuscitate owns OOC, Soul Link owns combat.
MF = resetScenario()
D.Status.SmartRezActions = {
    outOfCombatRezName = "Resuscitate",
    combatSoulLink = true,
    outOfCombatSoulLink = false
}
tick()
assert(MF.soulLinkDeathColor == "black")
combatLocked = true
tick()
assert(MF.soulLinkDeathColor == "green")

-- Warlock policy: Soulstone is ignored, so Soul Link owns both states.
MF = resetScenario()
D.Status.SmartRezActions = {
    combatSoulLink = true,
    outOfCombatSoulLink = true
}
tick()
assert(MF.soulLinkDeathColor == "green")

MF = resetScenario()
MF.SmartRezLeftEnabled121 = false
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
MF.Shown = false
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
MF.CurrUnit = "pet1"
D.MicroUnitF.UnitToMUF = { pet1 = MF }
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
units.party1.player = false
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
units.party1.exists = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")
contains(D:Get121SoulLinkStatusText(), "unit exists=secret")

MF = resetScenario()
units.party1.player = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")
contains(D:Get121SoulLinkStatusText(), "player=secret")

MF = resetScenario()
units.party1.selfUnit = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")
contains(D:Get121SoulLinkStatusText(), "self=secret")

MF = resetScenario()
units.party1.dead = false
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)

MF = resetScenario()
units.party1.dead = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "green")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)
statusOK, statusText = pcall(D.Get121SoulLinkStatusText, D)
assert(statusOK, "diagnostic formatter coerced a secret death value")
contains(statusText, "dead=secret")

-- Resurrection and MUF reuse clear a previously green square.
MF = resetScenario()
tick()
assert(MF.soulLinkDeathColor == "green")
units.party1.dead = false
tick()
assert(MF.soulLinkDeathColor == "black")
MF.CurrUnit = "pet1"
D.MicroUnitF.UnitToMUF = { pet1 = MF }
tick()
assert(MF.soulLinkDeathColor == "black")

-- The compatible priority-two fallback is tracked as its exact click source.
MF = resetScenario()
MF.SmartRezLeftEnabled121 = false
MF.SmartRezFallbackPriority2Enabled121 = true
tick()
assert(MF.soulLinkDeathColor == "black")
assert(D:Begin121SoulLinkAttempt(MF, "RightButton", 2, true) == true)

-- A generic failed cast is not evidence of range and must not warn.
failWatcher.scripts.OnEvent(failWatcher, "UNIT_SPELLCAST_FAILED", "player", "cast-guid", 1259646)
assert(shownAlert == nil)

-- Only the exact installed action and stored target can identify a range error.
MF = resetScenario()
rangeValue = false
tick()
assert(D:Begin121SoulLinkAttempt(MF, "LeftButton", 1, true) == true)
MF.CurrUnit = "party2"
failWatcher.scripts.OnEvent(failWatcher, "UI_ERROR_MESSAGE", 123, SPELL_FAILED_OUT_OF_RANGE)
assert(shownAlert and shownAlert:find("party1%-name"))
assert(not shownAlert:find("party2%-name"))

MF = resetScenario()
tick()
MF.Decursive121SoulLinkAttemptUnit121 = "party2"
assert(D:Begin121SoulLinkAttempt(MF, "LeftButton", 1, true) == false)

io.write("PASS: Emergency Soul Link action-slot discovery, cooldown, range and attempt mocks\n")
