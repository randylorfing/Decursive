local combat = false
local bagItems = {}
local itemData = {}
local requestedItemData = {}
local secretValues = {}
local inaccessibleValues = {}
local secretTables = setmetatable({}, { __mode = "k" })

_G = _G or {}
_G.InCombatLockdown = function() return combat end
_G.NUM_BAG_SLOTS = 4
_G.Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 } }
_G.issecretvalue = function(value) return secretValues[value] == true end
_G.canaccessvalue = function(value) return inaccessibleValues[value] ~= true end
_G.issecrettable = function(value) return secretTables[value] == true end
_G.canaccesstable = function(value) return secretTables[value] ~= true end
_G.C_Container = {
    GetContainerNumSlots = function(bag)
        local highest = 0
        for slot in pairs(bagItems[bag] or {}) do
            if slot > highest then highest = slot end
        end
        return highest
    end,
    GetContainerItemInfo = function(bag, slot)
        return bagItems[bag] and bagItems[bag][slot] or nil
    end,
}
_G.C_Item = {
    GetItemCount = function(itemID)
        if itemData[itemID] and itemData[itemID].countOverride ~= nil then
            return itemData[itemID].countOverride
        end
        local count = 0
        for bag = 0, 5 do
            for _, info in pairs(bagItems[bag] or {}) do
                if info.itemID == itemID then count = count + (info.stackCount or 0) end
            end
        end
        return count
    end,
    GetItemSpell = function(itemID)
        local data = itemData[itemID]
        return data and data.useSpellName or nil, data and data.useSpellID or nil
    end,
    IsUsableItem = function(itemID)
        local data = itemData[itemID]
        return data and data.usable == true or false, false
    end,
    GetDetailedItemLevelInfo = function(itemInfo)
        local itemID = type(itemInfo) == "string" and tonumber(itemInfo:match("item:(%d+)")) or itemInfo
        return itemData[itemID] and itemData[itemID].itemLevel or nil
    end,
    GetItemInfo = function(itemID)
        return itemData[itemID] and itemData[itemID].name or nil
    end,
    RequestLoadItemDataByID = function(itemID)
        requestedItemData[itemID] = true
    end,
}

local function setBagItem(bag, slot, itemID, stackCount)
    bagItems[bag] = bagItems[bag] or {}
    bagItems[bag][slot] = {
        itemID = itemID,
        stackCount = stackCount or 1,
        hyperlink = "item:" .. tostring(itemID),
    }
    return bagItems[bag][slot]
end

local function clearBagItems()
    bagItems = {}
end

local D = {
    L = {},
    profile = {
        CureBindingMode = "AUTO",
        CureBindingManual = {},
        CureBindingLegacySlots = {
            [1] = "*%s1",
            [2] = "*%s2",
            [3] = "ctrl-%s1",
            [4] = "ctrl-%s2",
            [5] = "shift-%s1",
        },
        MF_colors = {
            { 0.8, 0, 0 },
            { 0, 0.5, 1 },
            { 1, 0.5, 0 },
        },
    },
    Status = {},
}

local DC = {
    MAGIC = 1,
    CURSE = 2,
    POISON = 3,
    DISEASE = 4,
    CHARMED = 5,
    BLEED = 6,
    ENEMYMAGIC = 7,
    TypeNames = {
        [1] = "Magic",
        [2] = "Curse",
        [3] = "Poison",
        [4] = "Disease",
        [5] = "Charm",
        [6] = "Bleed",
        [7] = "Enemy magic",
    },
    DSI = {
        SPELL_POISON_CLEANSING_TOTEM = 383013,
        SPELL_MENDINGBANDAGE = 212640,
    },
}

local T = { Dcr = D, _C = DC }
local chunk = assert(loadfile("Decursive/Dcr_CureBindings.lua"))
chunk("Decursive", T)

local function found(id, macro, filter)
    return { false, id, false, 0, macro, filter }
end

local function fullStatus()
    return {
        FoundSpells = {
            Cleanse = found(100),
            CleanseAlias = found(100),
            CurseCure = found(200),
            PoisonCure = found(300),
            Purge = found(400),
            Custom = found(500, "/cast [@UNITID] Custom"),
            SelfOnly = found(600, nil, 1),
            Totem = found(383013),
            Bandage = found(212640),
        },
        CuringSpells = {
            [DC.ENEMYMAGIC] = "Purge",
            [DC.MAGIC] = "Cleanse",
            [DC.DISEASE] = "CleanseAlias",
            [DC.CURSE] = "CurseCure",
            [DC.POISON] = "PoisonCure",
            [DC.CHARMED] = "Custom",
        },
        CuringSpellsPrio = {
            Purge = 1,
            Cleanse = 2,
            CleanseAlias = 2,
            CurseCure = 3,
            PoisonCure = 4,
            Custom = 5,
        },
        ReversedCureOrder = {
            DC.ENEMYMAGIC,
            DC.MAGIC,
            DC.DISEASE,
            DC.CURSE,
            DC.POISON,
            DC.CHARMED,
        },
    }
end

D.Status = fullStatus()
assert(D:RefreshCureBindingModel("test"))
local model = D:GetCureBindingModel()
assert(model.mode == "AUTO")
assert(#model.actions == 5, "duplicate spell ID must collapse into one action")
assert(model.actions[1].spellName == "Cleanse" and model.actions[1].gesture == "*%s1")
assert(model.actions[2].spellName == "CurseCure" and model.actions[2].gesture == "*%s2")
assert(model.actions[3].spellName == "PoisonCure" and model.actions[3].gesture == "ctrl-%s1")
assert(model.actions[4].category == "ADDITIONAL_ACTION", "enemy action must follow friendly cures")
assert(model.actions[5].category == "CUSTOM_ACTION", "custom action must follow friendly cures")
assert(D:GetCureBindingPriorityForType(DC.MAGIC) == 1)
assert(D:GetCureBindingPriorityForType(DC.DISEASE) == 1)
assert(D:GetCureBindingPriorityForType(DC.CURSE) == 2)
assert(D:GetCureBindingPriorityForType(DC.POISON) == 3)
local manualGestures = {}
for _, gesture in ipairs(D:GetSupportedCureBindingGestures()) do manualGestures[gesture] = true end
assert(manualGestures["*%s5"], "manual Button5 must remain available without a verified PvP bandage")
assert(manualGestures["*%s4"], "manual Button4 must be available when the secure parser supports it")
assert(not manualGestures["shift-%s3"] and not manualGestures["ctrl-%s4"],
    "manual choices must omit gestures outside the supported user-facing set")

assert(D:SetCureBindingMode("MANUAL"))
assert(D.profile.CureBindingManual["spell:100"] == "*%s1")
assert(D:SetManualCureBinding("spell:100", "ctrl-%s4"))
local ok, reason = D:SetManualCureBinding("spell:200", "ctrl-%s4")
assert(not ok and reason == "duplicate-gesture")
assert(D:SetManualCureBinding("spell:200", "UNASSIGNED"))
model = D:GetCureBindingModel()
assert(model.actions[2].gesture == nil and model.byGesture["*%s2"] == nil)
D.profile.CureBindingManual["spell:999"] = "alt-%s1"
D.profile.CureBindingManual["spell:888"] = "alt-%s2"
local withUnavailable = D:GetCureBindingActions(true)
assert(withUnavailable[#withUnavailable - 1].actionKey == "spell:888"
    and withUnavailable[#withUnavailable].actionKey == "spell:999",
    "unavailable manual actions must have deterministic safe display order")
D.profile.CureBindingManual["spell:999"] = nil
D.profile.CureBindingManual["spell:888"] = nil

combat = true
local before = D:GetCureBindingModel()
D.Status = {
    FoundSpells = { OnlyCure = found(700) },
    CuringSpells = { [DC.MAGIC] = "OnlyCure" },
    CuringSpellsPrio = { OnlyCure = 1 },
    ReversedCureOrder = { DC.MAGIC },
}
local refreshed, combatReason = D:RefreshCureBindingModel("spec-change")
assert(not refreshed and combatReason == "combat")
assert(D:GetCureBindingModel() == before, "combat must retain the active binding model")
combat = false
assert(D:FlushPendingCureBindingRefresh())
assert(D:GetCureBindingActions()[1].spellName == "OnlyCure")

local openWorld = D.profile
local raid = { CureBindingMode = "AUTO", CureBindingManual = {} }
D.profile = raid
D.Status = fullStatus()
assert(D:RefreshCureBindingModel("raid"))
assert(D:GetCureBindingModel().mode == "AUTO")
D.profile = openWorld
assert(D:RefreshCureBindingModel("open-world"))
assert(D:GetCureBindingModel().mode == "MANUAL", "environment variants must remain isolated")

D.profile = { CureBindingMode = "AUTO", CureBindingManual = {}, CureBindingLegacySlots = {} }
D.Status = fullStatus()
D.Status.CuringSpells[DC.POISON] = "Totem"
D.Status.CuringSpellsPrio.Totem = 2
D.Status.CuringSpells[DC.CHARMED] = "Bandage"
D.Status.CuringSpellsPrio.Bandage = 3
itemData[8650] = { name = "Carried Match", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 99 }
setBagItem(0, 1, 8650)
assert(D:RefreshCureBindingModel("utility"))
model = D:GetCureBindingModel()
local sawTotem, sawBandage, bandageCount = false, false, 0
for _, action in ipairs(model.actions) do
    if action.actionID == 383013 then
        sawTotem = action.category == "AREA_UTILITY"
        assert(D:BuildAreaUtilityMacroText(action) == "/cast Totem")
    elseif action.actionID == 212640 then
        bandageCount = bandageCount + 1
        sawBandage = action.category == "PVP_BANDAGE" and action.gesture == "*%s5"
        assert(D:BuildPvPBandageMacroText(action, "mouseover"):find("nodead", 1, true))
    elseif action.isPvPBandage then
        bandageCount = bandageCount + 1
    end
end
assert(sawTotem and sawBandage and bandageCount == 1,
    "a known Mending Bandage spell action must prevent a duplicate carried-item action")
assert(D:GetCureBindingPriorityForType(DC.POISON) == nil, "area utility must not own a targeted native color slot")
manualGestures = {}
for _, gesture in ipairs(D:GetSupportedCureBindingGestures()) do manualGestures[gesture] = true end
assert(not manualGestures["*%s5"], "verified PvP bandage must reserve Button5")

D.Status = {
    FoundSpells = { OnlyCure = found(700) },
    CuringSpells = { [DC.MAGIC] = "OnlyCure" },
    CuringSpellsPrio = { OnlyCure = 1 },
    ReversedCureOrder = { DC.MAGIC },
}

clearBagItems()
itemData = {
    [8701] = { name = "Tie Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 30 },
    [8702] = { name = "Other Tie Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 30 },
    [8703] = { name = "Reagent Bag Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 40 },
    [8704] = { name = "Bank Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 100 },
}
setBagItem(0, 1, 8702, 2)
setBagItem(1, 1, 8701, 1)
setBagItem(5, 1, 8703, 1)
setBagItem(-1, 1, 8704, 1)
assert(D:RefreshCureBindingModel("built-in-multiple-bandages"))
model = D:GetCureBindingModel()
local itemBandage = model.actions[#model.actions]
assert(itemBandage.actionKey == "pvp-bandage:item:8703" and itemBandage.gesture == "*%s5")
assert(itemBandage.bandageSource == "BUILTIN" and itemBandage.bandageItemLevel == 40)
assert(itemBandage.bandageBag == 5 and itemBandage.bandageSlot == 1,
    "the carried reagent bag must be scanned while bank bags remain excluded")
assert(D:BuildPvPBandageMacroText(itemBandage, "mouseover")
    == "/use [@mouseover,help,exists,nodead] item:8703")

clearBagItems()
itemData = {
    [8802] = { name = "Fallback Two", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true },
    [8801] = { name = "Fallback One", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true },
}
setBagItem(0, 2, 8802)
setBagItem(4, 3, 8801)
assert(D:RefreshCureBindingModel("bandage-level-fallback"))
itemBandage = D:GetCureBindingModel().actions[#D:GetCureBindingModel().actions]
assert(itemBandage.actionID == -8801 and not itemBandage.bandageItemLevelPublic,
    "missing public item levels must use deterministic item ID then bag/slot fallback")
assert(requestedItemData[8801] and requestedItemData[8802], "cold item levels must request item data")

clearBagItems()
itemData = {
    [8901] = { name = "Inaccessible Level", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 777 },
}
setBagItem(0, 1, 8901)
inaccessibleValues[777] = true
assert(D:RefreshCureBindingModel("inaccessible-bandage-level"))
itemBandage = D:GetCureBindingModel().actions[#D:GetCureBindingModel().actions]
assert(itemBandage.actionID == -8901 and not itemBandage.bandageItemLevelPublic)
inaccessibleValues[777] = nil

clearBagItems()
itemData = {
    [9001] = { name = "Secret Item", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 50 },
}
local secretInfo = setBagItem(0, 1, 9001)
secretTables[secretInfo] = true
assert(D:RefreshCureBindingModel("secret-container-info"))
assert(#D:GetCureBindingModel().actions == 1, "secret container info must not become a binding")
secretTables[secretInfo] = nil
secretValues[9001] = true
assert(D:RefreshCureBindingModel("secret-item-id"))
assert(#D:GetCureBindingModel().actions == 1, "secret item IDs must not become bindings")
secretValues[9001] = nil
secretValues[212640] = true
assert(D:RefreshCureBindingModel("secret-use-spell"))
assert(#D:GetCureBindingModel().actions == 1, "secret use-spell IDs must not be compared")
secretValues[212640] = nil
itemData[9001].usable = false
assert(D:RefreshCureBindingModel("unusable-bandage"))
assert(#D:GetCureBindingModel().actions == 1, "publicly unusable items must not become bindings")
itemData[9001].usable = true
itemData[9001].countOverride = 666
inaccessibleValues[666] = true
assert(D:RefreshCureBindingModel("inaccessible-bandage-count"))
assert(#D:GetCureBindingModel().actions == 1, "inaccessible item counts must not become bindings")
inaccessibleValues[666] = nil
itemData[9001].countOverride = nil
secretValues[true] = true
assert(D:RefreshCureBindingModel("secret-bandage-usability"))
assert(#D:GetCureBindingModel().actions == 1, "secret usability results must not be inspected")
secretValues[true] = nil

itemData[9001].usable = true
itemData[9001].useSpellID = nil
requestedItemData[9001] = nil
assert(D:RefreshCureBindingModel("cold-bandage-data"))
assert(#D:GetCureBindingModel().actions == 1 and requestedItemData[9001],
    "missing use-spell data must request an item-data refresh without binding")
itemData[9001].useSpellID = 212640
assert(D:RefreshCureBindingModel("loaded-bandage-data"))
assert(D:GetCureBindingModel().actions[#D:GetCureBindingModel().actions].actionID == -9001)

clearBagItems()
assert(D:RefreshCureBindingModel("no-carried-bandage"))
assert(#D:GetCureBindingModel().actions == 1 and D:GetCureBindingModel().pvpBandageGesture == nil,
    "an out-of-combat scan with no valid carried item must clear Button5")

itemData = {
    [9101] = { name = "Combat Cache Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 60 },
}
setBagItem(0, 1, 9101)
assert(D:RefreshCureBindingModel("combat-cache-prime"))
local cachedBandage = T.CureBindings.cachedBandageItemAction
combat = true
clearBagItems()
assert(D:RegisterPvPBandageResolver(function() return 9999 end))
assert(T.CureBindings:GetBestPvPBandageItemAction() == cachedBandage,
    "combat must retain the last verified public item action")
local combatRefresh, combatRefreshReason = D:RefreshCureBindingModel("combat-bag-change")
assert(not combatRefresh and combatRefreshReason == "combat")
combat = false
assert(D:FlushPendingCureBindingRefresh())
assert(#D:GetCureBindingModel().actions == 1, "post-combat refresh must clear a removed item")
assert(D:RegisterPvPBandageResolver(nil))

clearBagItems()
itemData = {
    [9201] = { name = "Built-in Bandage", useSpellName = "Mending Bandage", useSpellID = 212640, usable = true, itemLevel = 80 },
    [9202] = { name = "Future Family", useSpellName = "Future Bandage", useSpellID = 456000, usable = true, itemLevel = 1 },
}
setBagItem(0, 1, 9201)
setBagItem(0, 2, 9202)
assert(D:RegisterPvPBandageResolver(function() return 9202 end))
assert(D:RefreshCureBindingModel("external-bandage-override"))
itemBandage = D:GetCureBindingModel().actions[#D:GetCureBindingModel().actions]
assert(itemBandage.actionID == -9202 and itemBandage.bandageSource == "EXTERNAL",
    "a verified carried external family must override the built-in match")
assert(D:RegisterPvPBandageResolver(function() return 9999 end))
assert(D:RefreshCureBindingModel("invalid-external-bandage"))
itemBandage = D:GetCureBindingModel().actions[#D:GetCureBindingModel().actions]
assert(itemBandage.actionID == -9201 and itemBandage.bandageSource == "BUILTIN",
    "an invalid external result must safely fall back to the built-in match")
assert(D:RegisterPvPBandageResolver(nil))

assert(D:ResetCureBindingsToAutomatic())
assert(D.profile.CureBindingMode == "AUTO" and next(D.profile.CureBindingManual) == nil)

if arg and arg[1] == "--self-test-failure" then
    error("intentional cure-binding harness failure")
end

io.stdout:write("OK: automatic/manual cure bindings, migration model, combat deferral, utilities, and environment isolation\n")
