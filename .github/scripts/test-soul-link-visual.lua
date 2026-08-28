local function readFile(path)
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

contains(soulLinkSource, "local actions = D.Status and D.Status.SmartRezActions")
excludes(soulLinkSource, "D:GetSmartRezActions", "runtime must not rebuild smart-rez ownership")
contains(soulLinkSource, "C_Item and C_Item.GetItemCooldown")
contains(soulLinkSource, "or C_Container and C_Container.GetItemCooldown")
excludes(soulLinkSource, "GetSpellCharges", "shared charges must not determine Soul Link ownership")
excludes(soulLinkSource, "GetSpellCooldown", "native spell cooldown must not determine Soul Link ownership")
excludes(soulLinkSource, "SetAttribute", "Soul Link feedback must not mutate secure attributes")
excludes(soulLinkSource, "RegisterForClicks", "Soul Link feedback must not change click registration")
excludes(soulLinkSource, "@mouseover", "Soul Link feedback must not rebuild secure mouseover macros")
contains(soulLinkSource, "return rawBoolean(C_Spell.IsSpellInRange, SOUL_LINK_SPELL_ID, unit)")
contains(soulLinkSource, "D:Set121MUFDeathSoulLinkRange(MF, inRange)")
contains(soulLinkSource, "MF.Decursive121SoulLinkAttemptUnit121 ~= unit")
contains(soulLinkSource, "showAlert(attempt.unit)")
contains(soulLinkSource, "never warn from this generic event")

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

local SECRET_VALUE = {}
local INACCESSIBLE_VALUE = {}
local combatLocked = false
local itemCount = 1
local cooldownStart = 0
local cooldownDuration = 0
local cooldownEnable = 1
local cooldownCalls = 0
local rangeValue = true
local now = 100
local tickerCallback
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

function CreateFrame()
    local frame = { scripts = {}, events = {} }
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
    NewTicker = function(_, callback)
        tickerCallback = callback
        return { Cancel = function() end }
    end
}

C_Item = {
    GetItemCount = function(itemID)
        assert(itemID == 269586)
        return itemCount
    end,
    GetItemCooldown = function(itemID)
        assert(itemID == 269586)
        cooldownCalls = cooldownCalls + 1
        return cooldownStart, cooldownDuration, cooldownEnable
    end
}

C_Spell = {
    IsSpellInRange = function(spellID, unit)
        assert(spellID == 1259646)
        assert(type(unit) == "string")
        return rangeValue
    end,
    GetSpellCharges = function()
        error("Soul Link runtime queried shared charges")
    end,
    GetSpellCooldown = function()
        error("Soul Link runtime queried a native spell cooldown")
    end
}

SPELL_FAILED_OUT_OF_RANGE = "OUT_OF_RANGE"
ERR_OUT_OF_RANGE = "OUT_OF_RANGE"

local D = {
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

local chunk = assert(loadfile("Decursive/Dcr_12_1_SoulLink.lua"))
chunk("Decursive", { Dcr = D, _C = { TWELVEONE = true } })
assert(type(tickerCallback) == "function")
assert(frames[2] and type(frames[2].scripts.OnEvent) == "function")

local function resetScenario()
    combatLocked = false
    itemCount = 1
    cooldownStart = 0
    cooldownDuration = 0
    cooldownEnable = 1
    cooldownCalls = 0
    rangeValue = true
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
    cooldownCalls = 0
    tickerCallback()
    assert(cooldownCalls <= 1, "item cooldown queried more than once in one Soul Link tick")
end

local MF = resetScenario()
tick()
assert(MF.soulLinkDeathColor == "green")
assert(MF.Decursive121SoulLinkRangeActive == false)
assert(MF.Decursive121SoulLinkSmartLeftReady121 == true)
assert(MF.Decursive121SoulLinkAttemptUnit121 == "party1")
assert(cooldownCalls == 1)

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

MF = resetScenario()
cooldownStart, cooldownDuration = 50, 60
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)

MF = resetScenario()
cooldownEnable = 0
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
cooldownStart = SECRET_VALUE
tick()
assert(MF.soulLinkDeathColor == "black")

MF = resetScenario()
itemCount = 0
tick()
assert(MF.soulLinkDeathColor == "black")
assert(cooldownCalls == 0)

-- A native shared-charge battle rez permanently owns resurrection. Its
-- cooldown/usability never changes the exact cached Soul Link action.
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
    assert(cooldownCalls == 0)
end

-- Monk precedence: normal resurrection owns OOC, Soul Link owns combat.
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

-- Warlock policy: Soulstone is ignored and the installed item action owns
-- both states, just like a class with no native or normal resurrection.
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
units.party1.dead = false
tick()
assert(MF.soulLinkDeathColor == "black")
assert(MF.Decursive121SoulLinkSmartLeftReady121 == false)

-- Resurrection and MUF reuse must clear a previously green square.
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
frames[2].scripts.OnEvent(frames[2], "UNIT_SPELLCAST_FAILED", "player", "cast-guid", 1259646)
assert(shownAlert == nil)

-- Only the exact installed action and stored target can arm/identify a range
-- error. MUF reassignment after the click must not rename that cast target.
MF = resetScenario()
rangeValue = false
tick()
assert(D:Begin121SoulLinkAttempt(MF, "LeftButton", 1, true) == true)
MF.CurrUnit = "party2"
frames[2].scripts.OnEvent(frames[2], "UI_ERROR_MESSAGE", 123, SPELL_FAILED_OUT_OF_RANGE)
assert(shownAlert and shownAlert:find("party1%-name"))
assert(not shownAlert:find("party2%-name"))

MF = resetScenario()
tick()
MF.Decursive121SoulLinkAttemptUnit121 = "party2"
assert(D:Begin121SoulLinkAttempt(MF, "LeftButton", 1, true) == false)

io.write("PASS: Emergency Soul Link exact-action readiness, range color and attempt mocks\n")
