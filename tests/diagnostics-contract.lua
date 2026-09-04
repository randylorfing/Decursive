--[[
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ZDecursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ZDecursive. If not, see <https://www.gnu.org/licenses/>.
--]]

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function Equal(actual, expected, message)
  Check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local secretValue = setmetatable({secret = true}, {
  __tostring = function()
    error("secret value was stringified")
  end,
})

issecretvalue = function(value)
  return rawequal(value, secretValue)
end

canaccessvalue = function(value)
  return not issecretvalue(value)
end

local combat = false
InCombatLockdown = function()
  return combat
end
InChatMessagingLockdown = function()
  return combat
end

GetBuildInfo = function()
  return "12.1.0", "63305", "Sep 2026", 120100
end

C_AddOns = {
  GetAddOnMetadata = function(_name, field)
    if field == "Version" then
      return "13.0.0-detect.30"
    end
    if field == "Interface" then
      return "120100"
    end
  end,
  IsAddOnLoaded = function()
    return true
  end,
  GetAddOnInfo = function()
    return "ZDecursive", "Zhaohu's Decursive", "Detect Dispel Protect", true, "NONE", "INSECURE"
  end,
  GetAddOnEnableState = function()
    return 2
  end,
}

UnitName = function()
  return "Character"
end

C_EventUtils = {
  IsEventValid = function()
    return true
  end,
}

local frames = {}
local function Region()
  local region = {shown = false, text = "", setTextCount = 0}
  local methods = {
    "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor", "SetTextInsets", "SetMultiLine",
    "SetAutoFocus", "SetFontObject", "SetWidth", "SetCursorPosition", "ClearFocus",
    "SetScrollChild", "SetHeight", "SetFont",
  }
  for i = 1, #methods do
    region[methods[i]] = function()
    end
  end
  function region:SetScript(kind, callback)
    self.scripts = self.scripts or {}
    self.scripts[kind] = callback
  end
  function region:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
  end
  function region:CreateFontString()
    return Region()
  end
  function region:SetText(value)
    self.text = value
    self.setTextCount = self.setTextCount + 1
  end
  function region:GetText()
    return self.text
  end
  function region:Show()
    self.shown = true
  end
  function region:Hide()
    self.shown = false
  end
  function region:IsShown()
    return self.shown
  end
  return region
end

CreateFrame = function(frameType, name, parent, template)
  local frame = Region()
  frame.frameType = frameType
  frame.name = name
  frame.parent = parent
  frame.template = template
  frames[#frames + 1] = frame
  return frame
end

UIParent = Region()
GameMenuFrame = Region()
GameMenuButtonAddons = Region()
SlashCmdList = {}

local ns = {}
assert(loadfile("ZDecursive/Diagnostics.lua"))("ZDecursive", ns)
local diagnostics = ns.Diagnostics
local initialLogCount = diagnostics.GetLogCount()
local windowBeforeNotice = diagnostics.GetWindow()
Check(diagnostics.AppendRuntimeMessage("Battle rez range warning emitted"), "sanitized notice is accepted")
Equal(diagnostics.GetLogCount(), initialLogCount + 1, "notice is appended to bounded runtime log")
Equal(diagnostics.GetWindow(), windowBeforeNotice, "notice does not create or replace diagnostics window")
Check(diagnostics.BuildReport():find("Battle rez range warning emitted", 1, true) ~= nil, "notice appears in copyable report")
Check(not diagnostics.AppendRuntimeMessage(secretValue), "secret notice is rejected")

local tocFile = assert(io.open("ZDecursive/ZDecursive.toc", "rb"))
local toc = tocFile:read("*a")
tocFile:close()
local embedsAt = assert(toc:find("embeds.xml", 1, true))
local diagnosticsAt = assert(toc:find("Diagnostics.lua", 1, true))
local defaultsAt = assert(toc:find("Defaults.lua", 1, true))
local coreAt = assert(toc:find("Core.lua", 1, true))
local detectionAt = assert(toc:find("Detection.lua", 1, true))
local engineAt = assert(toc:find("DetectionEngine.lua", 1, true))
local presentationAt = assert(toc:find("MUFPresentation.lua", 1, true))
local mufsAt = assert(toc:find("MUFs.lua", 1, true))
Check(embedsAt < diagnosticsAt and diagnosticsAt < defaultsAt and diagnosticsAt < coreAt, "Diagnostics loads after libraries and before ordinary modules")
Check(detectionAt < engineAt and engineAt < presentationAt and presentationAt < mufsAt, "MUF presentation seam loads between engine and consumer")

local diagnosticFile = assert(io.open("ZDecursive/Diagnostics.lua", "rb"))
local diagnosticSource = diagnosticFile:read("*a")
diagnosticFile:close()
Check(not diagnosticSource:find("UNIT_AURA", 1, true), "diagnostics does not register UNIT_AURA")
Check(not diagnosticSource:find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), "diagnostics does not parse combat log")
Check(not diagnosticSource:lower():find("seterrorhandler", 1, true), "diagnostics does not replace the error handler")
Check(not diagnosticSource:find('SetScript("OnUpdate"', 1, true), "diagnostics does not poll OnUpdate")

local providerFiles = {
  Core = "ZDecursive/Core.lua",
  Detection = "ZDecursive/Detection.lua",
  DetectionEngine = "ZDecursive/DetectionEngine.lua",
  MUFs = "ZDecursive/MUFs.lua",
  Lists = "ZDecursive/Lists.lua",
  LiveList = "ZDecursive/LiveList.lua",
  Alerts = "ZDecursive/Alerts.lua",
  Options = "ZDecursive/Options.lua",
}
for name, path in pairs(providerFiles) do
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  Check(source:find('RegisterDiagnosticProvider("' .. name .. '"', 1, true) ~= nil, name .. " registers a diagnostics provider")
end

Check(type(SlashCmdList.ZDECURSIVEDIAGNOSTICS) == "function", "slash callback exists before Core")
Equal(SLASH_ZDECURSIVEDIAGNOSTICS1, "/zdiag", "short diagnostic slash")
Equal(SLASH_ZDECURSIVEDIAGNOSTICS2, "/zdiagnostics", "long diagnostic slash")

local snapshot = diagnostics.BuildSnapshot()
Check(snapshot.ace.addonObject == false, "Core-absent snapshot")
Check(snapshot.ace.libStub == false and snapshot.ace.aceAddon == false and snapshot.ace.aceDB == false, "Ace-absent snapshot")
Equal(snapshot.rawDatabase.presence, "absent", "DB-absent snapshot")

DecursiveRebuildDB = "malformed"
snapshot = diagnostics.BuildSnapshot()
Equal(snapshot.rawDatabase.valueType, "string", "malformed DB type")
Equal(snapshot.rawDatabase.schema, "malformed", "malformed DB schema")

DecursiveRebuildDB = {global = {schema = 99}}
snapshot = diagnostics.BuildSnapshot()
Equal(snapshot.rawDatabase.schema, 99, "forward DB schema number")
Equal(snapshot.rawDatabase.forwardSchema, "forward", "forward DB status")

DecursiveRebuildDB = secretValue
snapshot = diagnostics.BuildSnapshot()
Equal(snapshot.rawDatabase.valueType, "secret", "secret DB type")
Equal(snapshot.rawDatabase.presence, "present", "secret DB presence")
DecursiveRebuildDB = {global = {schema = 99}}

ns.RegisterDiagnosticProvider("Throwing", function()
  error("C:\\Users\\Private\\addon.lua:42: Character-Realm")
end)
snapshot = diagnostics.BuildSnapshot()
Check(snapshot.providers.Throwing.providerFailure == true, "throwing provider is isolated")

ns.RegisterDiagnosticProvider("Secrets", function()
  return {opaque = secretValue}
end)
local report = diagnostics.BuildReport()
Check(report:find("<secret>", 1, true) ~= nil, "secret value is represented safely")

ns.RegisterDiagnosticProvider("PrivateData", function()
  return {
    path = "C:\\Users\\Private\\SavedVariables.lua",
    identity = "Character-Realm",
  }
end)
report = diagnostics.BuildReport()
Check(report:find("C:\\Users", 1, true) == nil, "filesystem path is absent")
Check(report:find("Character-Realm", 1, true) == nil, "character identity is absent")
Check(report:find("<redacted>", 1, true) ~= nil, "private strings are redacted")

local libStubObject = setmetatable({}, {
  __call = function(_self, name)
    if name == "AceAddon-3.0" or name == "AceDB-3.0" then
      return {}
    end
  end,
})
LibStub = libStubObject
ns.addon = {db = {GetCurrentProfile = function() return "PrivateProfile" end}}
diagnostics.State.coreInitialize = "success"
diagnostics.State.coreEnable = "success"
ns.RegisterDiagnosticProvider("Core", function()
  return {
    aceDBBound = true,
    currentProfileAvailable = true,
    resolvedAssignmentTier = "account",
    environmentPackID = "OPEN_WORLD",
    appliedEnvironment = "OPEN_WORLD",
    resolvedEnvironment = "DUNGEON",
    detectedEnvironment = "DUNGEON",
    environmentMode = "multiple",
    pendingEnvironment = "DUNGEON",
    editingEnvironment = "RAID",
    environmentResolutionReason = "PARTY_INSTANCE",
    environmentResolutionTier = "instance",
    environmentContextAPI = "GLOBAL_GET_INSTANCE_INFO",
    environmentContextReady = true,
    environmentRetryCount = 0,
    environmentRetryPending = false,
    profileResolvePending = false,
    profileChangeGeneration = 4,
    worldEntryRecoveryGeneration = 1,
    worldEntryRecoveryPending = false,
    worldEntryRecoveryReason = "NONE",
    worldEntryRecoveryRetryPolicy = "BOUNDED_TIMER_SAME_WORLD_TOKEN",
    worldEntryRecoveryRetryCount = 1,
    worldEntryRecoveryRetryPending = false,
    worldEntryRecoveryRetryExhausted = false,
  }
end)
snapshot = diagnostics.BuildSnapshot()
Check(snapshot.ace.aceAddon and snapshot.ace.aceDB and snapshot.ace.addonObject, "fully initialized Ace snapshot")
Check(snapshot.providers.Core.currentProfileAvailable, "fully initialized Core provider")
Check(snapshot.addon.loaded == true and snapshot.addon.enabled == true and snapshot.addon.loadable == true, "addon runtime status")
Equal(snapshot.addon.loadableReason, "NONE", "addon loadability reason")

ns.RegisterDiagnosticProvider("Detection", function()
  return {
    attachments = 2,
    attachmentPendingCombat = false,
    attachmentPendingRestriction = false,
    actionableTypeCount = 4,
    enabledActionableTypeCount = 4,
    knownCureActionCount = 2,
    customCureActionCount = 0,
    rosterTokenCounts = {player = 1, party = 1, raid = 0, pets = 1, total = 3},
  }
end)
ns.RegisterDiagnosticProvider("DetectionEngine", function()
  return {
    engineVersion = 1,
    providerType = "NATIVE_AURA_CONTAINER",
    presentationType = "NATIVE_SLOT_CALLBACK",
    appliedPackType = "table",
    lifecycleState = "READY",
    lifecycleGeneration = 4,
    configurationGeneration = 3,
    assignmentGeneration = 6,
    refreshGeneration = 2,
    carrierGeneration = 5,
    slotCreationGeneration = 5,
    providerRefreshGeneration = 8,
    presentationRegisteredSlotCount = 3,
    presentationVisibilityGatedSlotCount = 3,
    configuredCarrierCount = 5,
    assignedCarrierCount = 3,
    carrierCategoryCounts = {player = 1, party = 1, raid = 0, pets = 1, other = 0},
    carrierShownCount = 5,
    carrierAlphaPublicCount = 5,
    carrierAlphaZeroCount = 0,
    carrierMouseEnabledCount = 0,
    slotProviderRefreshGeneration = 8,
    combatEntryGeneration = 1,
    nativeCombatGeneration = 1,
    regenSeenGeneration = 1,
    regenReconcileGeneration = 1,
    pendingReconcile = false,
    pendingAssignmentCount = 0,
    pendingReason = "NONE",
    failureCount = 0,
    lastFailure = "NONE",
    consumerStates = {
      MUFs = {registered = true, available = true, refreshes = 2, failures = 0},
      LiveList = {registered = true, available = true, refreshes = 2, failures = 0},
      Alerts = {registered = true, available = true, refreshes = 2, failures = 0},
    },
    consumerMUFs = {registered = true, available = true, refreshes = 2, failures = 0},
    consumerLiveList = {registered = true, available = true, refreshes = 2, failures = 0},
    consumerAlerts = {registered = true, available = true, refreshes = 2, failures = 0},
  }
end)
ns.RegisterDiagnosticProvider("MUFs", function()
  return {
    poolCount = 5,
    assignedCount = 3,
    visibleCount = 3,
    configuredDisplayCap = 5,
    displayCapStage = "AFTER_SORT_MEMBER_CAP_THEN_OWNER_PETS",
    displayCapPolicy = "MEMBER_CAP_PETS_ADDITIONAL_OWNER_STABLE",
    displayCapAffectsDetection = false,
    displayCapIncludesPlayer = true,
    displayCapIncludesPets = true,
    orphanPetCount = 0,
    duplicatePetCount = 0,
    eligibleMemberCount = 5,
    eligiblePetCount = 1,
    displayedMemberCount = 5,
    displayedPetCount = 0,
    omittedMemberCount = 0,
    omittedPetCount = 1,
    detectionProviderType = "NATIVE_AURA_CONTAINER",
    presentationBindingType = "ADDON_CHILD_DISPEL_TEXTURE",
    presentationVisibilityGate = "NATIVE_AURA_SLOT_PARENT",
    presentationHealthyVisibility = "INHERITED_SLOT_HIDDEN",
    presentationAfflictedVisibility = "INHERITED_SLOT_SHOWN",
    presentationBindingType = "ADDON_CHILD_DISPEL_TEXTURE",
    appliedPackType = "table",
    clickModelGeneration = 2,
    clickInstalledCount = 3,
    clickRebuildPending = false,
    pendingRefresh = false,
    presentationMode = "FULL_OPAQUE",
    presentationAlpha = 1,
    presentationFillLevel = 40,
    presentationCooldownLevel = 48,
    presentationHostParent = "MUF_BUTTON",
    presentationHostBounds = "INNER_FILL_FULL_BOUNDS",
    presentationRegistrationStyle = "PRESERVE_ASSET",
    presentationOrder = "NATIVE_SLOT_MANAGED_FILL_DEATH_COOLDOWN_READABILITY",
    presentationNativeLifecycle = "SET_UNIT_ADD_SLOT_INITIALIZE_ENABLE_LAST",
    presentationAlphaChain = "MUF_ANCESTOR_HOST_TEXTURE_PROVIDER_VERTEX",
    presentationAlphaIsolationMode = "OWNED_TEXTURE_IGNORE_PARENT_ALPHA",
    presentationIgnoreParentAlphaSupported = true,
    presentationIgnoreParentAlphaApplied = true,
    presentationLocalTextureAlpha = 1,
    presentationProviderVertexAlpha = 1,
    presentationExpectedEffectiveAlpha = 1,
		presentationPaletteRefreshMode = "OWNED_SLOT_CLEAR_READD_ON_SIGNATURE_CHANGE",
		presentationPaletteSignatureMode = "DISPEL_TYPE_RGBA",
		presentationPaletteRegistrationGeneration = 7,
		presentationPaletteRefreshGeneration = 2,
		presentationPaletteRefreshFailureCount = 0,
    nativeChildrenUntouched = true,
    rangePresentationMode = "CONFIGURED_COLOR_OVERLAY",
    rangePresentationPrecedence = "BELOW_DISPEL_FILL",
    rangeColorPickerMode = "RGB_ONLY_OPAQUE",
    rangeTextureIntrinsicAlpha = 1,
    rangeDimMode = "RGB_BRIGHTNESS_MULTIPLIER",
    rangeVisibilityAlpha = "OPAQUE_ZERO_OR_ONE",
    rangeAlphaComposition = "OPAQUE_TEXTURE_TIMES_OPAQUE_VISIBLE_HOST",
    rangeParentAlphaPolicy = "NORMAL_INHERITANCE",
    afflictionPresentationPrecedence = "ABOVE_RANGE_SOUL_LINK_ORDINARY_MANAGED",
    rangeStateSource = "PRIMARY_CURE_PUBLIC_RANGE",
    deathPresentationMode = "CONFIGURED_COLOR_WITH_SKULL",
    deathPresentationPrecedence = "ABOVE_RANGE_AFFLICTION_SOUL_LINK",
    deathStateSource = "UNIT_DEATH_OR_CONNECTION",
    deathStatePersistence = "UNTIL_PUBLIC_ALIVE_OR_UNIT_CHANGE",
    deathSkullLayer = "READABILITY_ABOVE_COOLDOWN",
    deathBorderVisibility = "OUTSIDE_INNER_FILL",
    cooldownSuppressedBySkullCount = 1,
    cooldownSuppressionReason = "suppressedBySkull",
  }
end)
ns.RegisterDiagnosticProvider("Lists", function()
  return {
    dandersFramesLoaded = false,
    dandersFramesReady = false,
    dandersAdapterRegistered = false,
    configuredSortMode = "DANDERSFRAMES",
    effectiveSortMode = "GROUP",
    environmentPackID = "OPEN_WORLD",
    profileChangeGeneration = 4,
    priorityRevision = 2,
    sortCacheGeneration = 3,
    sortSignatureGeneration = 3,
    pendingSortRefresh = false,
    pendingConfiguredMode = "unknown",
  }
end)
ns.RegisterDiagnosticProvider("LiveList", function()
  return {eventsRegistered = true, visibleRows = 2, pendingRefresh = false}
end)
ns.RegisterDiagnosticProvider("Alerts", function()
  return {
    eventsRegistered = true,
    pendingRefresh = false,
    chatLockdown = false,
    actionableTypeCount = 4,
    actionableCuratedCount = 16,
    learnedStoredIgnoredCount = 0,
  }
end)
ns.RegisterDiagnosticProvider("Options", function()
  return {
    frameCreated = true,
    frameShown = false,
    simpleMode = true,
    currentPageAvailable = true,
    architectureVersion = 1,
    defaultDestination = "STATUS",
    currentDestination = "STATUS",
    environmentWorkspace = false,
    addonProfilesSeparate = true,
    environmentSubmenuCount = 6,
    environmentSubmenu = {"OPEN_WORLD", "DUNGEON", "MYTHIC_PLUS", "RAID", "PVP", "SOLO"},
    environmentMode = "multiple",
    multipleEnvironmentCount = 5,
    soloEnvironmentCount = 1,
    fullEnvironmentPageCount = 6,
    quickBindingCount = 6,
    shortcutOnlyCount = 1,
    combatReadOnly = false,
    searchAvailable = true,
    simpleModeAvailable = true,
    statusPanels = {"CURRENT_SETUP", "DISPEL_CAPABILITY", "CLICK_MAPPINGS", "QUICK_BINDINGS"},
  }
end)
snapshot = diagnostics.BuildSnapshot()
for name in pairs(providerFiles) do
  Check(snapshot.providerAvailability[name] == true, "normal snapshot provider " .. name)
end

combat = true
snapshot = diagnostics.BuildSnapshot()
Check(snapshot.lockdown.combat == true and snapshot.lockdown.chat == true, "combat snapshot")
combat = false

diagnostics.ClearRuntimeLog()
diagnostics.SetLogLimitForTests(3)
for i = 1, 7 do
  diagnostics.Checkpoint("runtime", "bounded checkpoint " .. tostring(i))
end
Equal(diagnostics.GetLogCount(), 3, "ring truncates to configured bound")
diagnostics.ClearRuntimeLog()
Equal(diagnostics.GetLogCount(), 0, "clear empties the runtime ring")

Check(diagnostics.TryInstallMenuButton(), "game menu button wiring")
Check(diagnostics.GetMenuButton() ~= nil, "menu button retained")

Check(diagnostics.Show(), "diagnostic window opens")
local window = diagnostics.GetWindow()
Check(window and window.editBox and window.refreshButton and window.clearButton and window.closeButton, "window controls exist")
local before = window.editBox.setTextCount
diagnostics.RefreshWindow()
diagnostics.RefreshWindow()
Check(window.editBox.setTextCount == before + 2, "repeated refresh updates the same EditBox")

report = diagnostics.BuildReport()
local required = {
  "diagnostics.addon.version",
  "diagnostics.addon.interface",
  "diagnostics.addon.build",
  "diagnostics.addon.loaded",
  "diagnostics.addon.enabled",
  "diagnostics.addon.loadable",
  "diagnostics.addon.loadableReason",
  "diagnostics.boot.phase",
  "diagnostics.boot.lastMilestone",
  "diagnostics.ace.aceAddon",
  "diagnostics.ace.addonObject",
  "diagnostics.rawDatabase.schema",
  "diagnostics.rawDatabase.forwardSchema",
  "diagnostics.lockdown.combat",
  "diagnostics.lockdown.chat",
  "diagnostics.modules.MUFs.loaded",
  "diagnostics.modules.MUFs.enabled",
  "diagnostics.providers.Core.aceDBBound",
  "diagnostics.providers.Core.currentProfileAvailable",
  "diagnostics.providers.Core.resolvedAssignmentTier",
  "diagnostics.providers.Core.environmentPackID",
  "diagnostics.providers.Core.appliedEnvironment",
  "diagnostics.providers.Core.resolvedEnvironment",
  "diagnostics.providers.Core.detectedEnvironment",
  "diagnostics.providers.Core.environmentMode",
  "diagnostics.providers.Core.pendingEnvironment",
  "diagnostics.providers.Core.editingEnvironment",
  "diagnostics.providers.Core.environmentResolutionReason",
  "diagnostics.providers.Core.environmentResolutionTier",
  "diagnostics.providers.Core.environmentContextAPI",
  "diagnostics.providers.Core.environmentContextReady",
  "diagnostics.providers.Core.environmentRetryCount",
  "diagnostics.providers.Core.environmentRetryPending",
  "diagnostics.providers.Core.profileResolvePending",
  "diagnostics.providers.Core.profileChangeGeneration",
  "diagnostics.providers.Core.worldEntryRecoveryGeneration",
  "diagnostics.providers.Core.worldEntryRecoveryPending",
  "diagnostics.providers.Core.worldEntryRecoveryReason",
  "diagnostics.providers.Core.worldEntryRecoveryRetryPolicy",
  "diagnostics.providers.Core.worldEntryRecoveryRetryCount",
  "diagnostics.providers.Core.worldEntryRecoveryRetryPending",
  "diagnostics.providers.Core.worldEntryRecoveryRetryExhausted",
  "diagnostics.providers.Detection.rosterTokenCounts",
  "diagnostics.providers.Detection.attachmentPendingCombat",
  "diagnostics.providers.Detection.actionableTypeCount",
  "diagnostics.providers.Detection.enabledActionableTypeCount",
  "diagnostics.providers.Detection.knownCureActionCount",
  "diagnostics.providers.Detection.customCureActionCount",
  "diagnostics.providers.DetectionEngine.engineVersion",
  "diagnostics.providers.DetectionEngine.providerType",
  "diagnostics.providers.DetectionEngine.presentationType",
  "diagnostics.providers.DetectionEngine.appliedPackType",
  "diagnostics.providers.DetectionEngine.lifecycleState",
  "diagnostics.providers.DetectionEngine.configurationGeneration",
  "diagnostics.providers.DetectionEngine.assignmentGeneration",
  "diagnostics.providers.DetectionEngine.refreshGeneration",
  "diagnostics.providers.DetectionEngine.configuredCarrierCount",
  "diagnostics.providers.DetectionEngine.assignedCarrierCount",
  "diagnostics.providers.DetectionEngine.slotCreationGeneration",
  "diagnostics.providers.DetectionEngine.providerRefreshGeneration",
  "diagnostics.providers.DetectionEngine.presentationRegisteredSlotCount",
  "diagnostics.providers.DetectionEngine.presentationVisibilityGatedSlotCount",
  "diagnostics.providers.DetectionEngine.carrierCategoryCounts",
  "diagnostics.providers.DetectionEngine.carrierShownCount",
  "diagnostics.providers.DetectionEngine.carrierAlphaZeroCount",
  "diagnostics.providers.DetectionEngine.carrierMouseEnabledCount",
  "diagnostics.providers.DetectionEngine.slotProviderRefreshGeneration",
  "diagnostics.providers.DetectionEngine.combatEntryGeneration",
  "diagnostics.providers.DetectionEngine.nativeCombatGeneration",
  "diagnostics.providers.DetectionEngine.regenSeenGeneration",
  "diagnostics.providers.DetectionEngine.regenReconcileGeneration",
  "diagnostics.providers.DetectionEngine.pendingReconcile",
  "diagnostics.providers.DetectionEngine.pendingAssignmentCount",
  "diagnostics.providers.DetectionEngine.failureCount",
  "diagnostics.providers.DetectionEngine.consumerMUFs.available",
  "diagnostics.providers.DetectionEngine.consumerLiveList.available",
  "diagnostics.providers.DetectionEngine.consumerAlerts.available",
  "diagnostics.providers.MUFs.poolCount",
  "diagnostics.providers.MUFs.assignedCount",
  "diagnostics.providers.MUFs.visibleCount",
  "diagnostics.providers.MUFs.configuredDisplayCap",
  "diagnostics.providers.MUFs.displayCapStage",
  "diagnostics.providers.MUFs.displayCapPolicy",
  "diagnostics.providers.MUFs.displayCapAffectsDetection",
  "diagnostics.providers.MUFs.displayCapIncludesPlayer",
  "diagnostics.providers.MUFs.displayCapIncludesPets",
  "diagnostics.providers.MUFs.presentationBindingType",
  "diagnostics.providers.MUFs.presentationVisibilityGate",
  "diagnostics.providers.MUFs.presentationHealthyVisibility",
  "diagnostics.providers.MUFs.presentationAfflictedVisibility",
  "diagnostics.providers.MUFs.orphanPetCount",
  "diagnostics.providers.MUFs.duplicatePetCount",
  "diagnostics.providers.MUFs.eligibleMemberCount",
  "diagnostics.providers.MUFs.eligiblePetCount",
  "diagnostics.providers.MUFs.displayedMemberCount",
  "diagnostics.providers.MUFs.displayedPetCount",
  "diagnostics.providers.MUFs.omittedMemberCount",
  "diagnostics.providers.MUFs.omittedPetCount",
  "diagnostics.providers.MUFs.detectionProviderType",
  "diagnostics.providers.MUFs.presentationBindingType",
  "diagnostics.providers.MUFs.appliedPackType",
  "diagnostics.providers.MUFs.clickModelGeneration",
  "diagnostics.providers.MUFs.clickInstalledCount",
  "diagnostics.providers.MUFs.clickRebuildPending",
  "diagnostics.providers.MUFs.presentationMode",
  "diagnostics.providers.MUFs.presentationAlpha",
  "diagnostics.providers.MUFs.presentationFillLevel",
  "diagnostics.providers.MUFs.presentationCooldownLevel",
  "diagnostics.providers.MUFs.presentationHostParent",
  "diagnostics.providers.MUFs.presentationHostBounds",
  "diagnostics.providers.MUFs.presentationRegistrationStyle",
  "diagnostics.providers.MUFs.presentationOrder",
  "diagnostics.providers.MUFs.presentationNativeLifecycle",
  "diagnostics.providers.MUFs.presentationAlphaChain",
  "diagnostics.providers.MUFs.presentationAlphaIsolationMode",
  "diagnostics.providers.MUFs.presentationIgnoreParentAlphaSupported",
  "diagnostics.providers.MUFs.presentationIgnoreParentAlphaApplied",
  "diagnostics.providers.MUFs.presentationLocalTextureAlpha",
  "diagnostics.providers.MUFs.presentationProviderVertexAlpha",
  "diagnostics.providers.MUFs.presentationExpectedEffectiveAlpha",
	"diagnostics.providers.MUFs.presentationPaletteRefreshMode",
	"diagnostics.providers.MUFs.presentationPaletteSignatureMode",
	"diagnostics.providers.MUFs.presentationPaletteRegistrationGeneration",
	"diagnostics.providers.MUFs.presentationPaletteRefreshGeneration",
	"diagnostics.providers.MUFs.presentationPaletteRefreshFailureCount",
  "diagnostics.providers.MUFs.nativeChildrenUntouched",
  "diagnostics.providers.MUFs.rangePresentationMode",
  "diagnostics.providers.MUFs.rangePresentationPrecedence",
  "diagnostics.providers.MUFs.rangeColorPickerMode",
  "diagnostics.providers.MUFs.rangeTextureIntrinsicAlpha",
  "diagnostics.providers.MUFs.rangeDimMode",
  "diagnostics.providers.MUFs.rangeVisibilityAlpha",
  "diagnostics.providers.MUFs.rangeAlphaComposition",
  "diagnostics.providers.MUFs.rangeParentAlphaPolicy",
  "diagnostics.providers.MUFs.afflictionPresentationPrecedence",
  "diagnostics.providers.MUFs.rangeStateSource",
  "diagnostics.providers.MUFs.deathPresentationMode",
  "diagnostics.providers.MUFs.deathPresentationPrecedence",
  "diagnostics.providers.MUFs.deathStateSource",
  "diagnostics.providers.MUFs.deathStatePersistence",
  "diagnostics.providers.MUFs.deathSkullLayer",
  "diagnostics.providers.MUFs.deathBorderVisibility",
  "diagnostics.providers.MUFs.cooldownSuppressedBySkullCount",
  "diagnostics.providers.MUFs.cooldownSuppressionReason",
  "diagnostics.providers.LiveList.pendingRefresh",
  "diagnostics.providers.Alerts.chatLockdown",
  "diagnostics.providers.Alerts.actionableTypeCount",
  "diagnostics.providers.Alerts.actionableCuratedCount",
  "diagnostics.providers.Alerts.learnedStoredIgnoredCount",
  "diagnostics.providers.Lists.dandersFramesLoaded",
  "diagnostics.providers.Lists.dandersAdapterRegistered",
  "diagnostics.providers.Lists.configuredSortMode",
  "diagnostics.providers.Lists.effectiveSortMode",
  "diagnostics.providers.Lists.environmentPackID",
  "diagnostics.providers.Lists.profileChangeGeneration",
  "diagnostics.providers.Lists.priorityRevision",
  "diagnostics.providers.Lists.sortCacheGeneration",
  "diagnostics.providers.Lists.sortSignatureGeneration",
  "diagnostics.providers.Lists.pendingSortRefresh",
  "diagnostics.providers.Lists.pendingConfiguredMode",
  "diagnostics.providers.Options.architectureVersion",
  "diagnostics.providers.Options.defaultDestination",
  "diagnostics.providers.Options.currentDestination",
  "diagnostics.providers.Options.environmentWorkspace",
  "diagnostics.providers.Options.addonProfilesSeparate",
  "diagnostics.providers.Options.environmentSubmenuCount",
  "diagnostics.providers.Options.environmentSubmenu.1",
  "diagnostics.providers.Options.environmentSubmenu.5",
  "diagnostics.providers.Options.environmentSubmenu.6",
  "diagnostics.providers.Options.environmentMode",
  "diagnostics.providers.Options.multipleEnvironmentCount",
  "diagnostics.providers.Options.soloEnvironmentCount",
  "diagnostics.providers.Options.fullEnvironmentPageCount",
  "diagnostics.providers.Options.quickBindingCount",
  "diagnostics.providers.Options.shortcutOnlyCount",
  "diagnostics.providers.Options.combatReadOnly",
  "diagnostics.providers.Options.searchAvailable",
  "diagnostics.providers.Options.simpleModeAvailable",
  "diagnostics.providers.Options.statusPanels.1",
  "diagnostics.providers.Options.statusPanels.4",
  "diagnostics.recent",
}
for i = 1, #required do
  Check(report:find(required[i], 1, true) ~= nil, "report field " .. required[i])
end

io.write("diagnostics-contract: ok\n")
