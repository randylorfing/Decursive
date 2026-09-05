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

local ADDON_NAME, ns = ...

if ns.DiagnosticCheckpoint then
  ns.DiagnosticCheckpoint("module", "Defaults file start")
end

local function DeepCopy(src)
  if type(src) ~= "table" then
    return src
  end
  local out = {}
  for k, v in pairs(src) do
    out[k] = DeepCopy(v)
  end
  return out
end

ns.DeepCopy = DeepCopy

ns.MULTIPLE_ENVIRONMENTS = {
  {key = "OPEN_WORLD", label = "Open World"},
  {key = "DUNGEON", label = "Dungeon"},
  {key = "MYTHIC_PLUS", label = "Mythic+"},
  {key = "RAID", label = "Raid"},
  {key = "PVP", label = "PvP"},
}

ns.ENVIRONMENTS = {}
for _, row in ipairs(ns.MULTIPLE_ENVIRONMENTS) do
  ns.ENVIRONMENTS[#ns.ENVIRONMENTS + 1] = row
end
ns.ENVIRONMENTS[#ns.ENVIRONMENTS + 1] = {key = "SOLO", label = "Solo"}

ns.ENV_SET = {}
ns.ENV_LABELS = {}
for _, row in ipairs(ns.ENVIRONMENTS) do
  ns.ENV_SET[row.key] = true
  ns.ENV_LABELS[row.key] = row.label
end
ns.MULTIPLE_ENV_SET = {}
for _, row in ipairs(ns.MULTIPLE_ENVIRONMENTS) do
  ns.MULTIPLE_ENV_SET[row.key] = true
end

ns.ENVIRONMENT_MODE_SCHEMA = 1
ns.MUF_ORIENTATION_SCHEMA = 1
ns.PVP_ALERT_DEFAULTS_SCHEMA = 1

ns.ACTIONABLE_CURE_TYPES = {"magic", "curse", "poison", "disease"}
ns.ACTIONABLE_CURE_TYPE_SET = {}
for _, key in ipairs(ns.ACTIONABLE_CURE_TYPES) do
  ns.ACTIONABLE_CURE_TYPE_SET[key] = true
end

ns.DEFAULT_MUF_DISPLAY_CAP = 5
ns.DEFAULT_RAID_MUF_DISPLAY_CAP = 40
ns.DEFAULT_PVP_MUF_DISPLAY_CAP = 40
ns.LEGACY_MUF_DISPLAY_CAP = 80
ns.DEFAULT_RANGE_COLOR = {248 / 255, 200 / 255, 3 / 255, 1}
ns.CANONICAL_CURE_ORDER = {"magic", "curse", "poison", "disease"}
ns.CANONICAL_CURE_COLORS = {
  magic = {255 / 255, 7 / 255, 9 / 255, 1},
  curse = {153 / 255, 51 / 255, 255 / 255, 1},
  poison = {51 / 255, 204 / 255, 51 / 255, 1},
  disease = {255 / 255, 95 / 255, 36 / 255, 1},
}
ns.PREVIOUS_CURE_COLORS = {
  magic = {0.20, 0.60, 1.00, 1},
  curse = {0.60, 0.20, 1.00, 1},
  poison = {0.20, 0.80, 0.20, 1},
  disease = {1.00, 0.85, 0.20, 1},
}

ns.PACK = {
  mufs = {
    show = true,
    locked = false,
    order = "AUTO",
    partySize = 20,
    raidSize = 20,
    horizontalSpacing = 2,
    verticalSpacing = 2,
    linkSpacing = true,
    statusLight = false,
    tooltip = true,
    growUp = false,
    verticalLayout = false,
    growFromRight = false,
    maxUnits = ns.DEFAULT_MUF_DISPLAY_CAP,
    unitsPerLine = 10,
    border = true,
    inactiveOpacity = 0.65,
    autoHide = "NEVER",
    hideHandle = false,
    showHelp = true,
    centerText = false,
    stealthStatus = true,
    scale = 1.5,
    dimOutOfRange = true,
    dimAmount = 0.50,
    dimAfflictedOutOfRange = true,
    secondaryAffliction = true,
    pulseSecondary = false,
    shareCooldown = true,
    clearCleansedImmediately = true,
    announceEnvChange = false,
    soulLinkFallback = true,
    secondaryBorder = true,
    secondaryBorderOpacity = 0.8,
    secondaryBorderThickness = 2,
    pulseSecondaryBorder = false,
    tieCenterAndBorder = true,
    borderTransp = 0.2,
    centerTransp = 0.35,
  },
  sorting = {
    afflictedFirst = true,
    includePlayer = true,
    includePets = true,
    centerPlayer = false,
    skipDead = false,
  },
  cure = {
    mode = "AUTO",
    bandageMode = "AUTO",
    bandageItemID = 0,
    bandageLowStockEnabled = false,
    bandageLowStockThreshold = 5,
    manual = {},
    clickBindings = {},
    keyboardEnabled = false,
    keyboardKey = "",
    keyboardOverride = false,
    magic = true,
    curse = true,
    poison = true,
    disease = true,
    doNotBlacklistPrio = true,
    curePets = true,
    skipStealthed = false,
    filterMode = "BY_ME",
    order = DeepCopy(ns.CANONICAL_CURE_ORDER),
  },
  mouse = {
    left = "CURE",
    right = "CURE",
    middle = "TARGET",
    button4 = "FOCUS",
    button5 = "ASSIST",
  },
  colors = {
    magic = DeepCopy(ns.CANONICAL_CURE_COLORS.magic),
    curse = DeepCopy(ns.CANONICAL_CURE_COLORS.curse),
    poison = DeepCopy(ns.CANONICAL_CURE_COLORS.poison),
    disease = DeepCopy(ns.CANONICAL_CURE_COLORS.disease),
    enrage = {1.00, 0.40, 0.10, 1},
    charm = {1.00, 0.20, 0.60, 1},
    bleed = {0.75, 0.10, 0.10, 1},
    healthy = {0, 0.3, 0.1, 0.9},
    afflicted = {0.55, 0.12, 0.12, 1},
    border = {0.05, 0.08, 0.10, 1},
    dead = {0, 0, 0, 1},
    range = DeepCopy(ns.DEFAULT_RANGE_COLOR),
    stealth = {0.4, 0.6, 0.4, 1},
  },
  alerts = {
    dispelEnabled = true,
    successfulDispelText = false,
    outOfRangeDispel = true,
    dispelMode = "TIMED",
    dispelDuration = 2,
    dispelFontSize = 48,
    dispelColor = {1, 0.15, 0.15, 1},
    alertPoint = {point = "TOP", x = 0, y = -160},
    pvpText = false,
    text = true,
    chat = true,
    printChat = true,
    printCustom = false,
    printErrors = true,
    sound = true,
    soundPreset = "FEMALE_DISPEL",
    soundChannel = "Master",
    soundDebounce = 2,
    errorSound = true,
    nativeAuraSound = true,
    learnSpellIds = true,
    cooldown = true,
    cooldownNumbers = true,
    cooldownOpacity = 0,
    range = true,
    soulLinkAlert = true,
    liveList = false,
    liveListOnlyInRange = true,
    liveListAmount = 7,
    liveListScan = 0.2,
    liveListReverse = false,
    liveListScale = 1,
    liveListAlpha = 1,
  },
  advanced = {
    autoAuraTrace = true,
    debug = false,
    checkDelay = 0.1,
    noStartMessages = true,
    blacklistLength = 5,
    refreshRate = 0.1,
    refreshSpeed = 20,
    periodicRescan = false,
    disableMacroCreation = false,
    allowMacroEdit = false,
    customMacro = "",
    noKeyWarn = false,
  },
  customSpells = {},
}

ns.PREVIOUS_PVP_ALERT_DEFAULTS = DeepCopy(ns.PACK.alerts)
-- Keep the historical signature independent of newly introduced defaults.
ns.PREVIOUS_PVP_ALERT_DEFAULTS.outOfRangeDispel = nil
ns.PREVIOUS_PVP_ALERT_DEFAULTS.range = true
ns.PREVIOUS_PVP_ALERT_DEFAULTS.text = false
ns.PREVIOUS_PVP_ALERT_DEFAULTS.chat = false
ns.PREVIOUS_PVP_ALERT_DEFAULTS.pvpText = false
ns.PREVIOUS_PVP_ALERT_DEFAULTS.cooldownOpacity = 0.60

local function ExactDefaultValue(current, expected)
  if type(current) ~= type(expected) then
    return false
  end
  if type(expected) ~= "table" then
    return current == expected
  end
  for key, value in pairs(expected) do
    if not ExactDefaultValue(current[key], value) then
      return false
    end
  end
  for key in pairs(current) do
    if expected[key] == nil then
      return false
    end
  end
  return true
end

function ns.HasPreviousPvPAlertDefaults(pack)
  return type(pack) == "table"
    and type(pack.alerts) == "table"
    and ExactDefaultValue(pack.alerts, ns.PREVIOUS_PVP_ALERT_DEFAULTS)
end

function ns.MigratePvPQuietAlertDefaults(pack)
  if not ns.HasPreviousPvPAlertDefaults(pack) then
    return 0
  end
  pack.alerts.dispelEnabled = false
  pack.alerts.sound = false
  return 1
end

ns.ENV_OVERRIDES = {
  OPEN_WORLD = {
    mufs = {dimOutOfRange = true},
    alerts = {range = false, text = true, chat = true, pvpText = false},
  },
  DUNGEON = {
    alerts = {range = true, text = true, chat = true},
  },
  MYTHIC_PLUS = {
    alerts = {range = true, text = true, chat = true},
  },
  RAID = {
    mufs = {maxUnits = ns.DEFAULT_RAID_MUF_DISPLAY_CAP},
    alerts = {range = true, text = true, chat = true},
  },
  PVP = {
    mufs = {maxUnits = ns.DEFAULT_PVP_MUF_DISPLAY_CAP},
    alerts = {
      range = true,
      dispelEnabled = false,
      text = false,
      chat = false,
      pvpText = false,
      sound = false,
    },
  },
}

ns.MUF_APPEARANCE_SCHEMA = 9

local function ColorEquals(color, red, green, blue, alpha)
  return type(color) == "table"
    and color[1] == red
    and color[2] == green
    and color[3] == blue
    and color[4] == alpha
end

local function ExactColorEquals(left, right)
  return type(right) == "table"
    and ColorEquals(left, right[1], right[2], right[3], right[4])
end

function ns.MigrateCanonicalCurePalette(pack)
  if type(pack) ~= "table" then
    return 0
  end
  local migrated = 0
  local colors = rawget(pack, "colors")
  if type(colors) ~= "table" then
    pack.colors = DeepCopy(ns.PACK.colors)
    colors = pack.colors
    migrated = migrated + 1
  else
    for _, key in ipairs(ns.CANONICAL_CURE_ORDER) do
      local current = rawget(colors, key)
      if current == nil or (
        not ExactColorEquals(current, ns.CANONICAL_CURE_COLORS[key])
        and ExactColorEquals(current, ns.PREVIOUS_CURE_COLORS[key])
      ) then
        colors[key] = DeepCopy(ns.CANONICAL_CURE_COLORS[key])
        migrated = migrated + 1
      end
    end
    if rawget(colors, "range") == nil then
      colors.range = DeepCopy(ns.DEFAULT_RANGE_COLOR)
      migrated = migrated + 1
    end
  end
  local cure = rawget(pack, "cure")
  if type(cure) ~= "table" then
    pack.cure = DeepCopy(ns.PACK.cure)
    migrated = migrated + 1
  elseif rawget(cure, "order") == nil then
    cure.order = DeepCopy(ns.CANONICAL_CURE_ORDER)
    migrated = migrated + 1
  end
  return migrated
end

function ns.HasObsoleteOpenWorldAppearance(pack)
  if type(pack) ~= "table" or type(pack.mufs) ~= "table" or type(pack.colors) ~= "table" then
    return false
  end
  local mufs = pack.mufs
  return mufs.dimOutOfRange == true
    and mufs.dimAmount == 0.60
    and mufs.centerTransp == 0.35
    and mufs.borderTransp == 0.2
    and mufs.border == true
    and mufs.partySize == 20
    and mufs.raidSize == 20
    and mufs.scale == 1.5
    and ColorEquals(pack.colors.healthy, 0, 0.3, 0.1, 0.9)
    and ColorEquals(pack.colors.border, 0.05, 0.08, 0.10, 1)
end

function ns.HasObsoleteDeathColor(pack)
  return type(pack) == "table"
    and type(pack.colors) == "table"
    and ColorEquals(pack.colors.dead, 0.18, 0.18, 0.18, 1)
end

function ns.HasLegacyMUFDisplayCap(pack)
  return type(pack) == "table"
    and type(pack.mufs) == "table"
    and pack.mufs.maxUnits == ns.LEGACY_MUF_DISPLAY_CAP
end

function ns.HasPriorDefaultRaidMUFDisplayCap(pack)
  return type(pack) == "table"
    and type(pack.mufs) == "table"
    and pack.mufs.maxUnits == ns.DEFAULT_MUF_DISPLAY_CAP
end

function ns.HasPriorDefaultPvPMUFDisplayCap(pack)
  return type(pack) == "table"
    and type(pack.mufs) == "table"
    and pack.mufs.maxUnits == ns.DEFAULT_MUF_DISPLAY_CAP
end

function ns.HasLegacyRangeAlpha(pack)
  return type(pack) == "table"
    and type(pack.mufs) == "table"
    and type(pack.colors) == "table"
    and pack.mufs.dimAmount == 0.60
    and ColorEquals(pack.colors.range, 0.08, 0.08, 0.10, 0.70)
end

function ns.HasLegacyRangeDefault(pack)
  if type(pack) ~= "table" or type(pack.mufs) ~= "table" or type(pack.colors) ~= "table" then
    return false
  end
  if ColorEquals(pack.colors.range, 0.08, 0.08, 0.10, 1) then
    return true
  end
  return pack.mufs.dimAmount == 0.60
    and ColorEquals(pack.colors.range, 0.08, 0.08, 0.10, 0.70)
end

function ns.ApplyEnvironmentOverrides(pack, env)
  local overrides = ns.ENV_OVERRIDES[env]
  if not overrides then
    return pack
  end
  for section, values in pairs(overrides) do
    if type(pack[section]) == "table" then
      for k, v in pairs(values) do
        pack[section][k] = v
      end
    end
  end
  return pack
end

function ns.MakePack(env)
  local pack = DeepCopy(ns.PACK)
  if env then
    ns.ApplyEnvironmentOverrides(pack, env)
  end
  return pack
end

function ns.MakeEnvironments()
  local environments = {}
  for _, row in ipairs(ns.ENVIRONMENTS) do
    environments[row.key] = ns.MakePack(row.key)
  end
  return environments
end

ns.defaults = {
  global = {
    schema = 3,
    accountProfile = "Default",
    characters = {},
    specs = {},
    identityShowAllDebuffs = false,
  },
  char = {
    editingEnvironment = "OPEN_WORLD",
    multipleEditingEnvironment = "OPEN_WORLD",
    optionsWidth = 1100,
    optionsHeight = 780,
    optionsSimple = true,
    mufPoint = {point = "CENTER", x = 0, y = 0},
    liveListPoint = {point = "CENTER", x = 220, y = 80},
  },
  profile = {
    routingMode = "multiple",
    environmentModeSchema = ns.ENVIRONMENT_MODE_SCHEMA,
    pvpAlertDefaultsSchema = ns.PVP_ALERT_DEFAULTS_SCHEMA,
    mufOrientation = "HORIZONTAL",
    mufOrientationSchema = ns.MUF_ORIENTATION_SCHEMA,
    environments = ns.MakeEnvironments(),
    lists = {
      priority = {},
      skip = {},
    },
  },
}

if ns.DiagnosticModuleLoaded then
  ns.DiagnosticModuleLoaded("Defaults")
end
