local ADDON_NAME, ns = ...

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

ns.ENVIRONMENTS = {
  {key = "OPEN_WORLD", label = "Open World"},
  {key = "DUNGEON", label = "Dungeon"},
  {key = "MYTHIC_PLUS", label = "Mythic+"},
  {key = "RAID", label = "Raid"},
  {key = "PVP", label = "PvP"},
}

ns.ENV_SET = {}
ns.ENV_LABELS = {}
for _, row in ipairs(ns.ENVIRONMENTS) do
  ns.ENV_SET[row.key] = true
  ns.ENV_LABELS[row.key] = row.label
end

ns.PACK = {
  mufs = {
    show = true,
    locked = false,
    order = "GROUP",
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
    maxUnits = 80,
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
    dimAmount = 0.45,
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
    magic = true,
    curse = true,
    poison = true,
    disease = true,
    enrage = true,
    charm = true,
    magicCharmed = true,
    bleed = true,
    bleedDetection = true,
    doNotBlacklistPrio = true,
    curePets = true,
    skipStealthed = false,
    filterMode = "BY_ME",
    order = {"magic", "curse", "poison", "disease", "enrage", "charm", "bleed"},
  },
  mouse = {
    left = "CURE",
    right = "CURE",
    middle = "TARGET",
    button4 = "FOCUS",
    button5 = "ASSIST",
  },
  colors = {
    magic = {0.20, 0.60, 1.00, 1},
    curse = {0.60, 0.20, 1.00, 1},
    poison = {0.20, 0.80, 0.20, 1},
    disease = {1.00, 0.85, 0.20, 1},
    enrage = {1.00, 0.40, 0.10, 1},
    charm = {1.00, 0.20, 0.60, 1},
    bleed = {0.75, 0.10, 0.10, 1},
    healthy = {0, 0.3, 0.1, 0.9},
    afflicted = {0.55, 0.12, 0.12, 1},
    border = {0.05, 0.08, 0.10, 1},
    dead = {0.18, 0.18, 0.18, 1},
    range = {0.08, 0.08, 0.10, 0.70},
    stealth = {0.4, 0.6, 0.4, 1},
  },
  alerts = {
    dispelEnabled = true,
    dispelMode = "TIMED",
    dispelDuration = 2,
    dispelFontSize = 48,
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
    errorSound = false,
    nativeAuraSound = true,
    learnSpellIds = true,
    cooldown = true,
    cooldownNumbers = true,
    cooldownOpacity = 0.62,
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
}

ns.ENV_OVERRIDES = {
  OPEN_WORLD = {
    alerts = {range = false, text = true, chat = true, pvpText = false, cooldownOpacity = 0.62},
  },
  DUNGEON = {
    alerts = {range = true, text = true, chat = true, cooldownOpacity = 0.60},
  },
  MYTHIC_PLUS = {
    alerts = {range = true, text = true, chat = true, cooldownOpacity = 0.70},
  },
  RAID = {
    alerts = {range = true, text = true, chat = true, cooldownNumbers = false, cooldownOpacity = 0.50},
  },
  PVP = {
    alerts = {range = true, text = false, chat = false, pvpText = false, cooldownOpacity = 0.60},
  },
}

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
  },
  char = {
    editingEnvironment = "OPEN_WORLD",
    optionsWidth = 1100,
    optionsHeight = 780,
    optionsSimple = true,
    mufPoint = {point = "CENTER", x = 0, y = 0},
    liveListPoint = {point = "CENTER", x = 220, y = 80},
  },
  profile = {
    environments = ns.MakeEnvironments(),
    lists = {
      priority = {},
      skip = {},
    },
  },
}
