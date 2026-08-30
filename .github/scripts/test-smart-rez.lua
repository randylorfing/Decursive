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

local source = readFile("Decursive/DCR_init.lua")
local frameSource = readFile("Decursive/Dcr_DebuffsFrame.lua")
local eventSource = readFile("Decursive/Dcr_Events.lua")
local soulLinkSource = readFile("Decursive/Dcr_12_1_SoulLink.lua")
local optionSource = readFile("Decursive_Options/Dcr_opt_tree.lua")

local builderStart = assert(source:find("    function D:GetKnownRezSpellName", 1, true))
local builderEnd = assert(source:find("    function D:UpdateMacro", builderStart, true))
local builderSource = source:sub(builderStart, builderEnd - 1)

DC = {
    TWELVEONE = true,
    NormalRezSpellIDs = { 50769, 7328, 2006, 2008, 115178, 361227 },
    BattleRezSpellIDs = { 20484, 61999, 391054 },
    SoulLinkItemID = 269586
}
D = {}

local knownSpells = {}
local spellNames = {}
local combatLocked = false
local carriedSoulLinkCount = 1
local itemCountArguments = {}
local debugEntries = {}
local now = 10
SECRET_VALUE = {}

function playerKnowsSpell(spellID)
    return knownSpells[spellID] == true
end

function GetSpellName(spellID)
    return spellNames[spellID]
end

function canaccessvalue(value)
    return value ~= SECRET_VALUE
end

function issecretvalue(value)
    return value == SECRET_VALUE
end

function InCombatLockdown()
    return combatLocked
end

function GetTime()
    now = now + 1
    return now
end

C_Item = {
    GetItemCount = function(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)
        itemCountArguments[#itemCountArguments + 1] = {
            itemID = itemID,
            includeBank = includeBank,
            includeUses = includeUses,
            includeReagentBank = includeReagentBank,
            includeAccountBank = includeAccountBank
        }
        return carriedSoulLinkCount
    end
}

function D:AddDebugText(...)
    debugEntries[#debugEntries + 1] = { ... }
end

local loader = loadstring or load
assert(loader(builderSource, "smart-rez-builder"))()

local function reset(known, names, soulLinkEnabled, soulLinkCount)
    knownSpells = known or {}
    spellNames = names or {}
    combatLocked = false
    carriedSoulLinkCount = soulLinkCount == nil and 1 or soulLinkCount
    itemCountArguments = {}
    debugEntries = {}
    D.profile = { SoulLink121Enabled = soulLinkEnabled ~= false }
    D.Status = {
        prio_macro = {},
        CuringSpellsPrio = {},
        FoundSpells = {},
        SpellsChanged = 1
    }
    D.DcrFullyInitialized = true
    D.MicroUnitF = { ExistingPerUNIT = {} }
    D.delayed = nil
    function D:AddDelayedFunctionCall(id, func, ...)
        self.delayed = { id = id, func = func, args = { ... } }
    end
end

local function assertMacroBudget(text, label)
    assert(#text <= 255, ("%s is %d bytes"):format(label, #text))
end

for _, spellID in ipairs(DC.NormalRezSpellIDs) do
    local name = "NormalRez" .. spellID
    reset({ [spellID] = true }, { [spellID] = name }, true)
    local combined, cureOnly, rezOnly, hasRez = D:BuildSmartRezMacroText(
        "mouseover",
        "cast",
        "Cleanse",
        false
    )
    assert(hasRez == true)
    contains(combined, "[@mouseover,help,exists,dead,nocombat] " .. name)
    contains(combined, "[@mouseover,help,exists,nodead][@mouseover,harm,exists,nodead] Cleanse")
    contains(combined, "/use [@mouseover,help,exists,dead,combat] item:269586")
    excludes(combined, "dead,nocombat] item:269586", "normal rez should not add an OOC Soul Link action")
    excludes(cureOnly, "dead,", "cure-only variant contains a dead branch")
    contains(rezOnly, "dead,nocombat")
    assertMacroBudget(combined, "normal class combined macro")
    assertMacroBudget(cureOnly, "normal class cure-only macro")
    assertMacroBudget(rezOnly, "normal class rez-only macro")
end

for _, spellID in ipairs(DC.BattleRezSpellIDs) do
    local name = "BattleRez" .. spellID
    reset({ [spellID] = true }, { [spellID] = name }, true)
    local combined, _, rezOnly, hasRez = D:BuildSmartRezMacroText(
        "mouseover",
        "cast",
        "Cleanse",
        false
    )
    assert(hasRez == true)
    contains(combined, "[@mouseover,help,exists,dead,combat][@mouseover,help,exists,dead,nocombat] " .. name)
    excludes(combined, "item:269586", "known battle rez must own both states when normal rez is absent")
    assertMacroBudget(combined, "battle class combined macro")
    assertMacroBudget(rezOnly, "battle class rez-only macro")
end

reset(
    { [50769] = true, [20484] = true },
    { [50769] = "Revive", [20484] = "Rebirth" },
    true
)
local druidMacro = D:BuildSmartRezMacroText("mouseover", "cast", "Nature's Cure", false)
contains(druidMacro, "[@mouseover,help,exists,dead,combat] Rebirth")
contains(druidMacro, "[@mouseover,help,exists,dead,nocombat] Revive")
excludes(druidMacro, "item:269586")
assertMacroBudget(druidMacro, "Druid smart macro")

reset(
    { [7328] = true, [391054] = true },
    { [7328] = "Redemption", [391054] = "Intercession" },
    true
)
local paladinMacro = D:BuildSmartRezMacroText("mouseover", "cast", "Cleanse Toxins", false)
contains(paladinMacro, "[@mouseover,help,exists,dead,combat] Intercession")
contains(paladinMacro, "[@mouseover,help,exists,dead,nocombat] Redemption")
assertMacroBudget(paladinMacro, "Paladin smart macro")

reset({}, {}, true, 0)
local absentItemMacro, absentCureOnly, absentRezOnly, absentHasRez = D:BuildSmartRezMacroText(
    "mouseover",
    "cast",
    "Remove Curse",
    false
)
assert(absentHasRez == false)
assert(absentItemMacro == absentCureOnly)
assert(absentRezOnly == "")
excludes(absentItemMacro, "item:269586")
assert(D.Status.SmartRezActions.combatSoulLink == false)
assert(D.Status.SmartRezActions.outOfCombatSoulLink == false)

reset({}, {}, true, SECRET_VALUE)
local secretItemMacro, secretCureOnly, secretRezOnly, secretHasRez = D:BuildSmartRezMacroText(
    "mouseover",
    "cast",
    "Remove Curse",
    false
)
assert(secretHasRez == false)
assert(secretItemMacro == secretCureOnly)
assert(secretRezOnly == "")
excludes(secretItemMacro, "item:269586")

reset({}, {}, true, 1)
local itemMacro, _, itemRezOnly, itemHasRez = D:BuildSmartRezMacroText(
    "mouseover",
    "cast",
    "Remove Curse",
    false
)
assert(itemHasRez == true)
contains(itemMacro, "[@mouseover,help,exists,dead,combat][@mouseover,help,exists,dead,nocombat] item:269586")
assert(D.Status.SmartRezActions.combatSoulLink == true)
assert(D.Status.SmartRezActions.outOfCombatSoulLink == true)
assertMacroBudget(itemMacro, "Soul Link-only combined macro")
assertMacroBudget(itemRezOnly, "Soul Link-only rez macro")
assert(#itemCountArguments == 1)
assert(itemCountArguments[1].itemID == 269586)
assert(itemCountArguments[1].includeBank == false)
assert(itemCountArguments[1].includeUses == false)
assert(itemCountArguments[1].includeReagentBank == false)
assert(itemCountArguments[1].includeAccountBank == false)

reset({}, {}, false)
local disabledItemMacro, disabledCureOnly, disabledRezOnly, disabledHasRez = D:BuildSmartRezMacroText(
    "mouseover",
    "cast",
    "Remove Curse",
    false
)
assert(disabledHasRez == false)
assert(disabledItemMacro == disabledCureOnly)
assert(disabledRezOnly == "")
excludes(disabledItemMacro, "item:269586")
assert(#itemCountArguments == 0)

reset({ [20707] = true }, { [20707] = "Soulstone" }, true)
local warlockMacro = D:BuildSmartRezMacroText("mouseover", "cast", "Singe Magic", true)
contains(warlockMacro, "[@mouseover,help,exists,dead,combat][@mouseover,help,exists,dead,nocombat] item:269586")
excludes(warlockMacro, "Soulstone")
assert(D.Status.SmartRezActions.combatSoulLink == true)
assert(D.Status.SmartRezActions.outOfCombatSoulLink == true)
assertMacroBudget(warlockMacro, "Warlock Soul Link macro")

reset({ [2006] = true }, { [2006] = "Resurrection" }, true)
D.Status.CuringSpellsPrio = { Cleanse = 1 }
D.Status.FoundSpells = {
    Cleanse = { false, 527, false, 0, nil, false }
}
D:SetMacrosPerPrioTable("mouseover")
assert(D.Status.prio_macro[1].smartRezAvailable == true)
assertMacroBudget(D.Status.prio_macro[1].macroText, "stored combined macro")
assertMacroBudget(D.Status.prio_macro[1].cureOnlyMacroText, "stored cure-only macro")
assertMacroBudget(D.Status.prio_macro[1].rezOnlyMacroText, "stored rez-only macro")

reset({ [2006] = true }, { [2006] = "Resurrection" }, true)
D.Status.CuringSpellsPrio = { Custom = 1 }
D.Status.FoundSpells = {
    Custom = { false, 527, false, 0, "/cast [@UNITID] User Choice", 2 }
}
D:SetMacrosPerPrioTable("mouseover")
assert(D.Status.prio_macro[1].macroText == "/cast [@mouseover] User Choice")
assert(D.Status.prio_macro[1].customMacro == true)
assert(D.Status.prio_macro[1].unitFiltering == 2)
assert(D.Status.prio_macro[1].rezOnlyMacroText == nil)

local veryLongName = string.rep("复", 70)
reset({ [2006] = true }, { [2006] = veryLongName }, true)
D.Status.CuringSpellsPrio = { Cleanse = 1 }
D.Status.FoundSpells = {
    Cleanse = { false, 527, false, 0, nil, false }
}
D:SetMacrosPerPrioTable("mouseover")
assert(D.Status.prio_macro[1].smartRezAvailable == false)
assert(D.Status.prio_macro[1].macroText == D.Status.prio_macro[1].cureOnlyMacroText)
assertMacroBudget(D.Status.prio_macro[1].macroText, "long-localization safe fallback")
assert(#debugEntries > 0)

reset({ [2006] = true }, { [2006] = "Resurrection" }, true)
local updated = 0
D.Status.CuringSpellsPrio = { Cleanse = 1 }
D.Status.FoundSpells = {
    Cleanse = { false, 527, false, 0, nil, false }
}
D.MicroUnitF.ExistingPerUNIT.party1 = {
    CurrUnit = "party1",
    UpdateAttributes = function(self, unit, doNotDelay)
        assert(unit == "party1")
        assert(doNotDelay == true)
        updated = updated + 1
    end
}
combatLocked = true
assert(D:RefreshMUFActionMacros("combat test") == false)
assert(D.delayed and D.delayed.id == "Dcr_RefreshMUFActionMacros")
assert(updated == 0)
combatLocked = false
assert(D:RefreshMUFActionMacros("ooc test") == true)
assert(updated == 1)

local bagHandlerStart = assert(eventSource:find("function D:BAG_UPDATE_DELAYED()", 1, true))
local bagHandlerEnd = assert(eventSource:find("function D:GET_ITEM_INFO_RECEIVED()", bagHandlerStart, true))
assert(loader(eventSource:sub(bagHandlerStart, bagHandlerEnd - 1), "bag-update-handler"))()

local scheduledCalls = {}
function D:Debug()
end
function D:ReConfigure()
end
function D:ScheduleDelayedCall(id, func, delay, ...)
    scheduledCalls[id] = { func = func, delay = delay, args = { ... } }
end

D:BAG_UPDATE_DELAYED()
assert(scheduledCalls.Dcr_ReConfigure)
local bagRefresh = assert(scheduledCalls.Dcr_RefreshMUFActionMacros)
assert(bagRefresh.func == D.RefreshMUFActionMacros)
assert(bagRefresh.delay == 0.5)
assert(bagRefresh.args[1] == D)
assert(bagRefresh.args[2] == "BAG_UPDATE_DELAYED")

combatLocked = true
D.delayed = nil
bagRefresh.func((table.unpack or unpack)(bagRefresh.args))
assert(D.delayed and D.delayed.id == "Dcr_RefreshMUFActionMacros")
combatLocked = false

reset({}, {}, true, 0)
D.Status.CuringSpellsPrio = { Cleanse = 1 }
D.Status.FoundSpells = {
    Cleanse = { false, 527, false, 0, nil, false }
}
D:SetMacrosPerPrioTable("mouseover")
excludes(D.Status.prio_macro[1].macroText, "item:269586")
carriedSoulLinkCount = 1
scheduledCalls = {}
D:BAG_UPDATE_DELAYED()
bagRefresh = assert(scheduledCalls.Dcr_RefreshMUFActionMacros)
combatLocked = true
D.delayed = nil
bagRefresh.func((table.unpack or unpack)(bagRefresh.args))
assert(D.delayed and D.delayed.id == "Dcr_RefreshMUFActionMacros")
combatLocked = false
D.delayed.func((table.unpack or unpack)(D.delayed.args))
contains(D.Status.prio_macro[1].macroText, "item:269586")

contains(frameSource, 'self.Frame:RegisterForClicks("AnyUp")')
contains(frameSource, 'self.Frame:SetAttribute(binding:format("type"), "macro")')
contains(frameSource, 'local physicalLeftBinding = "*%s1"')
contains(frameSource, "local physicalLeftReserved = mouseButtons[#mouseButtons - 1] == physicalLeftBinding")
contains(frameSource, "binding == physicalLeftBinding and macroData.customMacro")
contains(frameSource, "binding == physicalLeftBinding and rezEligibleUnit")
contains(frameSource, "macroData.cureOnlyMacroText or macroData.macroText")
contains(frameSource, "not macroData.customMacro")
contains(frameSource, 'D:GetBattleRezMacroText("mouseover")')
contains(frameSource, "SmartRezFallbackPriority2Enabled121")
excludes(frameSource:sub(
    assert(frameSource:find("function MicroUnitF.prototype:UpdateAttributes", 1, true)),
    assert(frameSource:find("function MicroUnitF.prototype:SetDebuffs", 1, true)) - 1
), "UnitIsDeadOrGhost", "attribute routing must not inspect live death state")

contains(eventSource, "function D:PLAYER_SPECIALIZATION_CHANGED()")
contains(eventSource, '"Dcr_RefreshMUFActionMacros"')
contains(eventSource:sub(bagHandlerStart, bagHandlerEnd - 1), '"BAG_UPDATE_DELAYED"')
contains(soulLinkSource, "local actions = D.Status and D.Status.SmartRezActions")
contains(soulLinkSource, "return actions.combatSoulLink == true")
contains(soulLinkSource, "return actions.outOfCombatSoulLink == true")
excludes(soulLinkSource, "D:GetSmartRezActions")
contains(soulLinkSource, "pcall(D.IsMUFRezEligibleUnitToken, D, unit)")
contains(soulLinkSource, "MF.SmartRezLeftEnabled121 == true")
contains(optionSource, 'D:RefreshMUFActionMacros("Soul Link option toggle")')
contains(source, "type(_G.C_SpellBook.IsSpellInSpellBook) == \"function\"")
contains(source, "_G.Enum.SpellBookSpellBank.Player")
contains(builderSource, "function D:HasCarriedSoulLinkItem()")
contains(builderSource, "DC.SoulLinkItemID,")
excludes(source:sub(builderStart, builderEnd - 1), "UnitIsDeadOrGhost")
excludes(source:sub(builderStart, builderEnd - 1), "spell:%")
excludes(source:sub(builderStart, builderEnd - 1), "RegisterForClicks")
excludes(source:sub(builderStart, builderEnd - 1), "RegisterStateDriver")

io.write("PASS: smart resurrection secure-macro mocks and source invariants\n")
