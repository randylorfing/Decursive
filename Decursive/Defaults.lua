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

-- One complete pack. Copied per environment. Never share table identity.
ns.PACK = {
  mufs = {
    show = true,
    size = 30,
    spacing = 2,
    alpha = 1,
    grow = "RIGHT",
    wrap = 10,
  },
  cure = {
    mode = "AUTO",
    magic = true,
    curse = true,
    poison = true,
    disease = true,
    enrage = true,
  },
  alerts = {
    pvpText = false,
    text = true,
    sound = true,
    errorSound = true,
  },
  advanced = {
    debug = false,
    checkDelay = 0.1,
  },
}

function ns.MakeEnvironments()
  local environments = {}
  for _, row in ipairs(ns.ENVIRONMENTS) do
    environments[row.key] = DeepCopy(ns.PACK)
  end
  return environments
end

ns.defaults = {
  global = {
    schema = 1,
    accountProfile = "Default",
    characters = {},
    specs = {},
  },
  char = {
    editingEnvironment = "OPEN_WORLD",
  },
  profile = {
    environments = ns.MakeEnvironments(),
  },
}
