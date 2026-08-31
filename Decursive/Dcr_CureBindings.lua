--[[
    This file is part of Decursive.

    Automatic and manual secure cure-binding policy. This file was solely
    written by Randy Lorfing.
    Copyright (C) 2026 Randy Lorfing

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive. If not, see <https://www.gnu.org/licenses/>.
--]]

local addonName, T = ...
local D = T and T.Dcr
local DC = T and T._C
if not D or not DC then return end

local CureBindings = {}
T.CureBindings = CureBindings
D.CureBindings = CureBindings

local AUTO_MODE = "AUTO"
local MANUAL_MODE = "MANUAL"
local UNASSIGNED = "UNASSIGNED"

local STOCK_GESTURES = {
	"*%s1",
	"*%s2",
	"ctrl-%s1",
	"ctrl-%s2",
	"shift-%s1",
	"shift-%s2",
	"shift-%s3",
	"alt-%s1",
	"alt-%s2",
	"alt-%s3",
	"*%s4",
	"ctrl-%s4",
	"shift-%s4",
	"alt-%s4",
	"*%s5",
	"ctrl-%s5",
	"shift-%s5",
	"alt-%s5",
	"*%s3",
	"ctrl-%s3",
}

local SIMPLE_FRIENDLY_GESTURES = {
	"*%s1",
	"*%s2",
	"ctrl-%s1",
}

local MANUAL_GESTURES = {
	"*%s1",
	"*%s2",
	"ctrl-%s1",
	"ctrl-%s2",
	"shift-%s1",
	"shift-%s2",
	"alt-%s1",
	"alt-%s2",
	"*%s4",
	"*%s5",
}

local TARGET_GESTURE = "*%s3"
local FOCUS_GESTURE = "ctrl-%s3"
local PVP_BANDAGE_GESTURE = "*%s5"

local SUPPORTED_GESTURES = {}
for _, gesture in ipairs(STOCK_GESTURES) do SUPPORTED_GESTURES[gesture] = true end

local FRIENDLY_TYPES = {}
if DC.MAGIC then FRIENDLY_TYPES[DC.MAGIC] = true end
if DC.CURSE then FRIENDLY_TYPES[DC.CURSE] = true end
if DC.POISON then FRIENDLY_TYPES[DC.POISON] = true end
if DC.DISEASE then FRIENDLY_TYPES[DC.DISEASE] = true end
if DC.BLEED then FRIENDLY_TYPES[DC.BLEED] = true end

local function isCombatLocked()
	return _G.InCombatLockdown and _G.InCombatLockdown() or false
end

local function copyArray(source)
	local result = {}
	for index, value in ipairs(type(source) == "table" and source or {}) do result[index] = value end
	return result
end

local function isPublicValue(value)
	if (_G.issecretvalue and _G.issecretvalue(value))
		or (_G.canaccessvalue and not _G.canaccessvalue(value))
	then
		return false
	end
	return true
end

local function isPublicTable(value)
	if type(value) ~= "table" then return false end
	if (_G.issecrettable and _G.issecrettable(value))
		or (_G.canaccesstable and not _G.canaccesstable(value))
	then
		return false
	end
	return true
end

local function safeInteger(value)
	if not isPublicValue(value) then return nil end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
	if value % 1 ~= 0 then return nil end
	return value
end

local function safeActionID(value)
	value = safeInteger(value)
	if not value or value == 0 then return nil end
	return value
end

local function actionKeyForFoundSpell(foundSpell)
	local actionID = foundSpell and safeActionID(foundSpell[2])
	if not actionID then return nil end
	if actionID < 0 then return "item:" .. tostring(-actionID) end
	return "spell:" .. tostring(actionID)
end

local function isAreaUtility(actionID)
	local dsi = DC.DSI or {}
	return actionID == dsi.SPELL_POISON_CLEANSING_TOTEM
end

local function isPvPBandageSpell(actionID)
	local dsi = DC.DSI or {}
	return actionID == dsi.SPELL_MENDINGBANDAGE
end

local function typeLabel(debuffType)
	local localizationKey = DC.TypeToLocalizableTypeNames and DC.TypeToLocalizableTypeNames[debuffType]
	return D.L and localizationKey and D.L[localizationKey]
		or DC.TypeNames and DC.TypeNames[debuffType]
		or tostring(debuffType)
end

local function actionSort(left, right)
	if left.legacyPriority ~= right.legacyPriority then return left.legacyPriority < right.legacyPriority end
	if left.actionID ~= right.actionID then return left.actionID < right.actionID end
	return tostring(left.spellName) < tostring(right.spellName)
end

local function makeBandageItemAction(candidate)
	if type(candidate) ~= "table" then return nil end
	local itemID = safeActionID(candidate.itemID)
	if not itemID or itemID < 1 then return nil end
	return {
		actionKey = "pvp-bandage:item:" .. tostring(itemID),
		actionID = -itemID,
		spellName = candidate.itemName or ("PvP bandage item " .. tostring(itemID)),
		coveredTypes = {},
		coveredTypeLabels = {},
		legacyPriority = 99,
		category = "PVP_BANDAGE",
		isPvPBandage = true,
		bandageSource = candidate.source,
		bandageItemLevel = candidate.itemLevel,
		bandageItemLevelPublic = candidate.itemLevel ~= nil,
		bandageBag = candidate.bag,
		bandageSlot = candidate.slot,
		bandageUseSpellID = candidate.useSpellID,
	}
end

local function requestItemData(itemID)
	local itemAPI = _G.C_Item
	if type(itemAPI) == "table" and type(itemAPI.RequestLoadItemDataByID) == "function" then
		pcall(itemAPI.RequestLoadItemDataByID, itemID)
	end
end

local function carriedBagIndexes()
	local result = {}
	local seen = {}
	local bagEnum = _G.Enum and _G.Enum.BagIndex
	local first = bagEnum and safeInteger(bagEnum.Backpack) or 0
	local last = safeInteger(_G.NUM_BAG_SLOTS)
	if first and first >= 0 and last and last >= first then
		for bag = first, last do
			result[#result + 1] = bag
			seen[bag] = true
		end
	end
	local reagentBag = bagEnum and safeInteger(bagEnum.ReagentBag)
	if reagentBag and reagentBag >= 0 and not seen[reagentBag] then result[#result + 1] = reagentBag end
	table.sort(result)
	return result
end

local function publicItemLevel(itemAPI, itemID, hyperlink)
	if type(itemAPI.GetDetailedItemLevelInfo) ~= "function" then return nil end
	local itemInfo = isPublicValue(hyperlink) and hyperlink or itemID
	local ok, itemLevel = pcall(itemAPI.GetDetailedItemLevelInfo, itemInfo)
	if not ok or not isPublicValue(itemLevel) or type(itemLevel) ~= "number"
		or itemLevel ~= itemLevel or itemLevel < 0 or itemLevel == math.huge
	then
		return nil
	end
	return itemLevel
end

local function publicItemName(itemAPI, itemID)
	if type(itemAPI.GetItemInfo) ~= "function" then return nil end
	local ok, itemName = pcall(itemAPI.GetItemInfo, itemID)
	if ok and isPublicValue(itemName) and type(itemName) == "string" and itemName ~= "" then return itemName end
	return nil
end

local function candidateIsBetter(candidate, current)
	if not current then return true end
	local candidateHasLevel = candidate.itemLevel ~= nil
	local currentHasLevel = current.itemLevel ~= nil
	if candidateHasLevel ~= currentHasLevel then return candidateHasLevel end
	if candidateHasLevel and candidate.itemLevel ~= current.itemLevel then
		return candidate.itemLevel > current.itemLevel
	end
	if candidate.itemID ~= current.itemID then return candidate.itemID < current.itemID end
	if candidate.bag ~= current.bag then return candidate.bag < current.bag end
	return candidate.slot < current.slot
end

function CureBindings:ScanCarriedPvPBandages(externalItemID)
	if isCombatLocked() then return nil, nil end
	local itemAPI = _G.C_Item
	local containerAPI = _G.C_Container
	if type(itemAPI) ~= "table" or type(containerAPI) ~= "table"
		or type(itemAPI.GetItemSpell) ~= "function"
		or type(itemAPI.GetItemCount) ~= "function"
		or type(itemAPI.IsUsableItem) ~= "function"
		or type(containerAPI.GetContainerNumSlots) ~= "function"
		or type(containerAPI.GetContainerItemInfo) ~= "function"
	then
		return nil, nil
	end

	externalItemID = safeActionID(externalItemID)
	if externalItemID and externalItemID < 1 then externalItemID = nil end
	local knownUseSpellID = safeActionID(DC.DSI and DC.DSI.SPELL_MENDINGBANDAGE)
	local bestBuiltIn
	local bestExternal

	for _, bag in ipairs(carriedBagIndexes()) do
		local slotsOK, numSlots = pcall(containerAPI.GetContainerNumSlots, bag)
		numSlots = slotsOK and safeInteger(numSlots) or nil
		if numSlots and numSlots >= 0 then
			for slot = 1, numSlots do
				local infoOK, info = pcall(containerAPI.GetContainerItemInfo, bag, slot)
				if infoOK and isPublicTable(info) then
					local itemID = safeActionID(info.itemID)
					local stackCount = safeInteger(info.stackCount)
					if itemID and itemID > 0 and stackCount and stackCount > 0 then
						local spellOK, _, useSpellID = pcall(itemAPI.GetItemSpell, itemID)
						useSpellID = spellOK and safeActionID(useSpellID) or nil
						if not useSpellID then requestItemData(itemID) end
						local builtInMatch = knownUseSpellID and useSpellID == knownUseSpellID
						local externalMatch = externalItemID and itemID == externalItemID and useSpellID ~= nil
						if builtInMatch or externalMatch then
							local countOK, count = pcall(itemAPI.GetItemCount, itemID, false, false, false, false)
							count = countOK and safeInteger(count) or nil
							local usableOK, usable = pcall(itemAPI.IsUsableItem, itemID)
							if count and count > 0 and usableOK and isPublicValue(usable) and usable == true then
								local itemLevel = publicItemLevel(itemAPI, itemID, info.hyperlink)
								if itemLevel == nil then requestItemData(itemID) end
								local candidate = {
									itemID = itemID,
									itemName = publicItemName(itemAPI, itemID),
									itemLevel = itemLevel,
									bag = bag,
									slot = slot,
									useSpellID = useSpellID,
								}
								if builtInMatch and candidateIsBetter(candidate, bestBuiltIn) then bestBuiltIn = candidate end
								if externalMatch and candidateIsBetter(candidate, bestExternal) then bestExternal = candidate end
							end
						end
					end
				end
			end
		end
	end
	return bestBuiltIn, bestExternal
end

function CureBindings:GetBestPvPBandageItemAction()
	if isCombatLocked() then return self.cachedBandageItemAction end
	local externalItemID
	if type(self.pvpBandageResolver) == "function" then
		local ok, itemID = pcall(self.pvpBandageResolver)
		if ok then externalItemID = itemID end
	end
	local builtIn, external = self:ScanCarriedPvPBandages(externalItemID)
	local selected = external or builtIn
	if selected then selected.source = external and "EXTERNAL" or "BUILTIN" end
	self.cachedBandageItemAction = makeBandageItemAction(selected)
	return self.cachedBandageItemAction
end

function D:RegisterPvPBandageResolver(resolver)
	if resolver ~= nil and type(resolver) ~= "function" then return false, "invalid-resolver" end
	CureBindings.pvpBandageResolver = resolver
	if isCombatLocked() then
		CureBindings.pendingRefresh = "pvp-bandage-resolver"
	else
		CureBindings.cachedBandageItemAction = nil
		if D.DcrFullyInitialized and D.RefreshMUFActionMacros then
			D:RefreshMUFActionMacros("pvp-bandage-resolver")
		end
	end
	return true
end

function CureBindings:BuildActions(status)
	status = type(status) == "table" and status or {}
	local foundSpells = type(status.FoundSpells) == "table" and status.FoundSpells or {}
	local curingSpells = type(status.CuringSpells) == "table" and status.CuringSpells or {}
	local legacyPriorities = type(status.CuringSpellsPrio) == "table" and status.CuringSpellsPrio or {}
	local reversed = type(status.ReversedCureOrder) == "table" and status.ReversedCureOrder or {}
	local orderByType = {}
	for order, debuffType in ipairs(reversed) do orderByType[debuffType] = order end

	local byActionKey = {}
	for debuffType, spellName in pairs(curingSpells) do
		local foundSpell = spellName and foundSpells[spellName]
		local actionKey = actionKeyForFoundSpell(foundSpell)
		if actionKey then
			local action = byActionKey[actionKey]
			if not action then
				local actionID = foundSpell[2]
				action = {
					actionKey = actionKey,
					actionID = actionID,
					spellName = spellName,
					foundSpell = foundSpell,
					legacyPriority = tonumber(legacyPriorities[spellName]) or 99,
					coveredTypes = {},
					coveredTypeLabels = {},
					spellNames = {},
					firstTypeOrder = 99,
					customMacro = type(foundSpell[5]) == "string" and foundSpell[5] ~= "",
					unitFiltering = foundSpell[6],
					areaUtility = isAreaUtility(actionID),
					isPvPBandage = isPvPBandageSpell(actionID),
				}
				byActionKey[actionKey] = action
			end
			action.spellNames[spellName] = true
			local legacyPriority = tonumber(legacyPriorities[spellName]) or 99
			if legacyPriority < action.legacyPriority
				or legacyPriority == action.legacyPriority and tostring(spellName) < tostring(action.spellName)
			then
				action.legacyPriority = legacyPriority
				action.spellName = spellName
				action.foundSpell = foundSpell
			end
			action.customMacro = action.customMacro or type(foundSpell[5]) == "string" and foundSpell[5] ~= ""
			action.unitFiltering = action.unitFiltering or foundSpell[6]
			action.areaUtility = action.areaUtility or isAreaUtility(foundSpell[2])
			action.isPvPBandage = action.isPvPBandage or isPvPBandageSpell(foundSpell[2])
			action.coveredTypes[#action.coveredTypes + 1] = debuffType
			action.coveredTypeLabels[#action.coveredTypeLabels + 1] = typeLabel(debuffType)
			action.firstTypeOrder = math.min(action.firstTypeOrder, orderByType[debuffType] or 99)
			if FRIENDLY_TYPES[debuffType] then action.hasFriendlyType = true end
		end
	end

	local targetedFriendly = {}
	local pvpBandages = {}
	local additional = {}
	for _, action in pairs(byActionKey) do
		table.sort(action.coveredTypes, function(left, right)
			local leftOrder = orderByType[left] or 99
			local rightOrder = orderByType[right] or 99
			if leftOrder ~= rightOrder then return leftOrder < rightOrder end
			return left < right
		end)
		action.coveredTypeLabels = {}
		for _, debuffType in ipairs(action.coveredTypes) do
			action.coveredTypeLabels[#action.coveredTypeLabels + 1] = typeLabel(debuffType)
		end
		if action.isPvPBandage then
			action.category = "PVP_BANDAGE"
			pvpBandages[#pvpBandages + 1] = action
		elseif action.hasFriendlyType and not action.customMacro and not action.unitFiltering and not action.areaUtility then
			action.category = "FRIENDLY_CURE"
			targetedFriendly[#targetedFriendly + 1] = action
		else
			action.category = action.areaUtility and "AREA_UTILITY"
				or action.unitFiltering and "LIMITED_UTILITY"
				or action.customMacro and "CUSTOM_ACTION"
				or "ADDITIONAL_ACTION"
			additional[#additional + 1] = action
		end
	end

	table.sort(targetedFriendly, function(left, right)
		if left.firstTypeOrder ~= right.firstTypeOrder then return left.firstTypeOrder < right.firstTypeOrder end
		return actionSort(left, right)
	end)
	table.sort(pvpBandages, actionSort)
	table.sort(additional, actionSort)

	local itemBandage = #pvpBandages == 0 and self:GetBestPvPBandageItemAction() or nil
	if itemBandage then pvpBandages[#pvpBandages + 1] = itemBandage end

	local actions = {}
	for _, action in ipairs(targetedFriendly) do actions[#actions + 1] = action end
	for _, action in ipairs(additional) do actions[#actions + 1] = action end
	for _, action in ipairs(pvpBandages) do actions[#actions + 1] = action end
	for slot, action in ipairs(actions) do action.slot = slot end
	return actions
end

local function resolveLegacyGesture(profile, action)
	local legacy = type(profile.CureBindingLegacySlots) == "table" and profile.CureBindingLegacySlots or nil
	local gesture = legacy and legacy[action.legacyPriority]
	if SUPPORTED_GESTURES[gesture] then return gesture end
	return nil
end

local function nextUnusedStockGesture(used, startIndex)
	for index = startIndex or 1, #STOCK_GESTURES - 2 do
		local gesture = STOCK_GESTURES[index]
		if gesture ~= PVP_BANDAGE_GESTURE and not used[gesture] then return gesture end
	end
	return nil
end

function CureBindings:ResolveModel(status, profile)
	profile = type(profile) == "table" and profile or {}
	local mode = profile.CureBindingMode == MANUAL_MODE and MANUAL_MODE or AUTO_MODE
	local actions = self:BuildActions(status)
	local manual = type(profile.CureBindingManual) == "table" and profile.CureBindingManual or {}
	local used = { [TARGET_GESTURE] = true, [FOCUS_GESTURE] = true }
	local byGesture = {}
	local bySpell = {}
	local byType = {}
	local friendlyIndex = 0
	local hasPvPBandage = false

	for _, action in ipairs(actions) do if action.isPvPBandage then hasPvPBandage = true break end end
	if hasPvPBandage then used[PVP_BANDAGE_GESTURE] = "PVP_BANDAGE" end
	for _, action in ipairs(actions) do
		local gesture
		if mode == MANUAL_MODE then
			gesture = manual[action.actionKey]
			if gesture == nil then gesture = resolveLegacyGesture(profile, action) end
			if gesture == UNASSIGNED then gesture = nil end
		elseif action.category == "FRIENDLY_CURE" then
			friendlyIndex = friendlyIndex + 1
			gesture = SIMPLE_FRIENDLY_GESTURES[friendlyIndex]
		elseif action.isPvPBandage then
			gesture = PVP_BANDAGE_GESTURE
		else
			gesture = resolveLegacyGesture(profile, action)
			if not SUPPORTED_GESTURES[gesture] or used[gesture] then
				gesture = nextUnusedStockGesture(used, 4)
			end
		end

		local reservedForThisBandage = action.isPvPBandage and gesture == PVP_BANDAGE_GESTURE
			and used[gesture] == "PVP_BANDAGE"
		if not SUPPORTED_GESTURES[gesture] or used[gesture] and not reservedForThisBandage then gesture = nil end
		action.gesture = gesture
		action.assigned = gesture ~= nil
		if gesture then
			used[gesture] = true
			byGesture[gesture] = action.slot
		end
		for spellName in pairs(action.spellNames or { [action.spellName] = true }) do
			bySpell[spellName] = action.slot
		end
		if action.category == "FRIENDLY_CURE" then
			for _, debuffType in ipairs(action.coveredTypes) do
				if FRIENDLY_TYPES[debuffType] then byType[debuffType] = action.slot end
			end
		end
	end

	return {
		mode = mode,
		actions = actions,
		byGesture = byGesture,
		bySpell = bySpell,
		byType = byType,
		targetGesture = TARGET_GESTURE,
		focusGesture = FOCUS_GESTURE,
		pvpBandageGesture = hasPvPBandage and PVP_BANDAGE_GESTURE or nil,
	}
end

function CureBindings:Refresh(reason)
	if isCombatLocked() then
		self.pendingRefresh = reason or true
		return false, "combat"
	end
	self.pendingRefresh = nil
	local profile = D.profile or {}
	local model = self:ResolveModel(D.Status, profile)
	if model.mode == MANUAL_MODE then
		profile.CureBindingManual = type(profile.CureBindingManual) == "table" and profile.CureBindingManual or {}
		for _, action in ipairs(model.actions) do
			if profile.CureBindingManual[action.actionKey] == nil then
				local migrated = resolveLegacyGesture(profile, action)
				if migrated then profile.CureBindingManual[action.actionKey] = migrated end
			end
		end
		model = self:ResolveModel(D.Status, profile)
	end
	self.model = model
	if type(D.Status) == "table" then
		D.Status.CureBindingModel = model
		D.Status.CureBindingActions = model.actions
		D.Status.CureBindingSlotForSpell = model.bySpell
		D.Status.CureBindingSlotForType = model.byType
	end
	return true, model
end

function D:RefreshCureBindingModel(reason)
	return CureBindings:Refresh(reason)
end

function D:GetCureBindingModel()
	if not CureBindings.model then CureBindings:Refresh("lazy") end
	return CureBindings.model
end

function D:GetCureBindingActions(includeUnavailable)
	local model = self:GetCureBindingModel()
	local actions = model and copyArray(model.actions) or {}
	if includeUnavailable and self.profile and type(self.profile.CureBindingManual) == "table" then
		local seen = {}
		for _, action in ipairs(actions) do seen[action.actionKey] = true end
		local unavailable = {}
		for actionKey in pairs(self.profile.CureBindingManual) do
			if not seen[actionKey] then unavailable[#unavailable + 1] = actionKey end
		end
		table.sort(unavailable)
		for _, actionKey in ipairs(unavailable) do
			local gesture = self.profile.CureBindingManual[actionKey]
			actions[#actions + 1] = {
				actionKey = actionKey,
				spellName = actionKey,
				coveredTypeLabels = {},
				category = "UNAVAILABLE",
				gesture = SUPPORTED_GESTURES[gesture] and gesture or nil,
				available = false,
			}
		end
	end
	return actions
end

function D:GetCureBindingPriorityForSpell(spellName)
	local model = self:GetCureBindingModel()
	return model and model.bySpell and model.bySpell[spellName] or nil
end

function D:GetCureBindingPriorityForType(debuffType)
	local model = self:GetCureBindingModel()
	return model and model.byType and model.byType[debuffType] or nil
end

function D:GetCureBindingPriorityForGesture(gesture)
	local model = self:GetCureBindingModel()
	return model and model.byGesture and model.byGesture[gesture] or nil
end

function D:GetCureBindingGestureForPriority(priority)
	local model = self:GetCureBindingModel()
	local action = model and model.actions and model.actions[priority]
	return action and action.gesture or nil
end

function D:GetCureTargetGesture()
	return TARGET_GESTURE
end

function D:GetCureFocusGesture()
	return FOCUS_GESTURE
end

function D:GetSupportedCureBindingGestures()
	local result = { UNASSIGNED }
	local model = self:GetCureBindingModel()
	local bandageOwnsButton5 = model and model.pvpBandageGesture == PVP_BANDAGE_GESTURE
	for _, gesture in ipairs(MANUAL_GESTURES) do
		if gesture ~= PVP_BANDAGE_GESTURE or not bandageOwnsButton5 then
			result[#result + 1] = gesture
		end
	end
	return result
end

function D:GetAllSecureBindingGestures()
	return copyArray(STOCK_GESTURES)
end

function D:SetCureBindingMode(mode)
	if mode ~= AUTO_MODE and mode ~= MANUAL_MODE then return false, "invalid-mode" end
	if isCombatLocked() then return false, "combat" end
	if not self.profile then return false, "profile-unavailable" end
	if mode == MANUAL_MODE and self.profile.CureBindingMode ~= MANUAL_MODE then
		local current = CureBindings:ResolveModel(self.Status, self.profile)
		self.profile.CureBindingManual = type(self.profile.CureBindingManual) == "table" and self.profile.CureBindingManual or {}
		for _, action in ipairs(current.actions) do
			self.profile.CureBindingManual[action.actionKey] = action.gesture or UNASSIGNED
		end
	end
	self.profile.CureBindingMode = mode
	CureBindings:Refresh("mode")
	if self.RefreshMUFActionMacros then self:RefreshMUFActionMacros("cure-binding-mode") end
	if self.NotifyConfigurationChanged then self:NotifyConfigurationChanged() end
	return true
end

function D:SetManualCureBinding(actionKey, gesture)
	if isCombatLocked() then return false, "combat" end
	if type(actionKey) ~= "string" or actionKey == "" or #actionKey > 128 then return false, "invalid-action" end
	if gesture == nil then gesture = UNASSIGNED end
	if gesture ~= UNASSIGNED and not SUPPORTED_GESTURES[gesture] then return false, "unsupported-gesture" end
	if gesture == TARGET_GESTURE or gesture == FOCUS_GESTURE then return false, "reserved-gesture" end
	local model = self:GetCureBindingModel()
	if gesture == PVP_BANDAGE_GESTURE and model and model.pvpBandageGesture then return false, "reserved-gesture" end
	local manual = type(self.profile.CureBindingManual) == "table" and self.profile.CureBindingManual or {}
	for otherActionKey, otherGesture in pairs(manual) do
		if otherActionKey ~= actionKey and gesture ~= UNASSIGNED and otherGesture == gesture then
			local currentlyAvailable = false
			for _, action in ipairs(model and model.actions or {}) do
				if action.actionKey == otherActionKey then currentlyAvailable = true break end
			end
			if currentlyAvailable then return false, "duplicate-gesture", otherActionKey end
		end
	end
	manual[actionKey] = gesture
	self.profile.CureBindingManual = manual
	self.profile.CureBindingMode = MANUAL_MODE
	CureBindings:Refresh("manual-binding")
	if self.RefreshMUFActionMacros then self:RefreshMUFActionMacros("manual-cure-binding") end
	if self.NotifyConfigurationChanged then self:NotifyConfigurationChanged() end
	return true
end

function D:ResetCureBindingsToAutomatic()
	if isCombatLocked() then return false, "combat" end
	if not self.profile then return false, "profile-unavailable" end
	self.profile.CureBindingMode = AUTO_MODE
	self.profile.CureBindingManual = {}
	self.profile.CureBindingLegacySlots = nil
	CureBindings:Refresh("reset-automatic")
	if self.RefreshMUFActionMacros then self:RefreshMUFActionMacros("reset-cure-bindings") end
	if self.NotifyConfigurationChanged then self:NotifyConfigurationChanged() end
	return true
end

function D:AdoptLegacyMouseButtonsAsManual()
	if isCombatLocked() then return false, "combat" end
	if not self.profile or type(self.profile.MouseButtons) ~= "table" then return false, "profile-unavailable" end
	local legacy = {}
	for priority = 1, 7 do
		local gesture = self.profile.MouseButtons[priority]
		if SUPPORTED_GESTURES[gesture] then legacy[priority] = gesture end
	end
	self.profile.CureBindingLegacySlots = legacy
	self.profile.CureBindingManual = {}
	self.profile.CureBindingMode = MANUAL_MODE
	CureBindings:Refresh("advanced-bindings")
	local model = CureBindings.model
	for _, action in ipairs(model and model.actions or {}) do
		self.profile.CureBindingManual[action.actionKey] = action.gesture or UNASSIGNED
	end
	CureBindings:Refresh("advanced-bindings-final")
	if self.RefreshMUFActionMacros then self:RefreshMUFActionMacros("advanced-cure-bindings") end
	return true
end

function D:FlushPendingCureBindingRefresh()
	if not CureBindings.pendingRefresh or isCombatLocked() then return false end
	local reason = CureBindings.pendingRefresh
	CureBindings.pendingRefresh = nil
	CureBindings:Refresh(reason)
	if self.RefreshMUFActionMacros then self:RefreshMUFActionMacros("deferred-cure-bindings") end
	return true
end

function D:BuildPvPBandageMacroText(action, unit)
	if type(action) ~= "table" or not action.isPvPBandage then return nil end
	unit = type(unit) == "string" and unit or "mouseover"
	if action.actionID and action.actionID < 0 then
		return ("/use [@%s,help,exists,nodead] item:%d"):format(unit, -action.actionID)
	end
	if type(action.spellName) == "string" and action.spellName ~= "" then
		return ("/cast [@%s,help,exists,nodead] %s"):format(unit, action.spellName)
	end
	return nil
end

function D:BuildAreaUtilityMacroText(action)
	if type(action) ~= "table" or not action.areaUtility
		or type(action.spellName) ~= "string" or action.spellName == ""
	then
		return nil
	end
	return "/cast " .. action.spellName
end

CureBindings.AUTO_MODE = AUTO_MODE
CureBindings.MANUAL_MODE = MANUAL_MODE
CureBindings.UNASSIGNED = UNASSIGNED
CureBindings.STOCK_GESTURES = STOCK_GESTURES
CureBindings.TARGET_GESTURE = TARGET_GESTURE
CureBindings.FOCUS_GESTURE = FOCUS_GESTURE
CureBindings.PVP_BANDAGE_GESTURE = PVP_BANDAGE_GESTURE
