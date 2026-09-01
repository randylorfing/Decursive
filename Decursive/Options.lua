local ADDON_NAME, ns = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function Addon()
  return ns.addon
end

local function ProfileValues()
  local values = {}
  for _, name in ipairs(Addon().db:GetProfiles()) do
    values[name] = name
  end
  return values
end

local function CharacterProfileValues()
  local values = {["_inherit"] = "Use account / Default"}
  for name, label in pairs(ProfileValues()) do
    values[name] = label
  end
  return values
end

local function EnvironmentValues()
  local values = {}
  for _, row in ipairs(ns.ENVIRONMENTS) do
    values[row.key] = row.label
  end
  return values
end

local function EnvGet(section, key)
  return function()
    local pack = Addon():GetEditingPack()
    return pack[section][key]
  end
end

local function EnvSet(section, key)
  return function(_, value)
    local pack = Addon():GetEditingPack()
    pack[section][key] = value
  end
end

local function EnvHeader()
  local addon = Addon()
  local env = addon:GetEditingEnvironment()
  local profile = addon.db:GetCurrentProfile()
  return string.format("Editing %s on profile %s", ns.ENV_LABELS[env] or env, profile)
end

local function GrowValues()
  return {
    LEFT = "Left",
    RIGHT = "Right",
    UP = "Up",
    DOWN = "Down",
  }
end

function ns.RegisterOptions(addon)
  local options = {
    type = "group",
    name = "Zhaohu's Decursive",
    childGroups = "tree",
    args = {
      profiles = {
        type = "group",
        name = "Profiles",
        order = 1,
        args = {
          intro = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = "Logical profiles each hold five complete environments. The resolver picks spec (if enabled and mapped), then this character, then account, then Default. Environment switching is manual in this slice.",
          },
          resolved = {
            type = "description",
            order = 2,
            name = function()
              return "Active (resolver): " .. Addon():ResolveProfileName()
            end,
          },
          current = {
            type = "select",
            name = "Editing profile",
            order = 3,
            width = "double",
            values = ProfileValues,
            get = function()
              return Addon().db:GetCurrentProfile()
            end,
            set = function(_, value)
              Addon().db:SetProfile(value)
              Addon():EnsureEnvironments()
              ns.Notify()
            end,
          },
          newName = {
            type = "input",
            name = "New profile name",
            order = 10,
            width = "double",
            get = function()
              return Addon()._newProfileName or ""
            end,
            set = function(_, value)
              Addon()._newProfileName = value
            end,
          },
          create = {
            type = "execute",
            name = "Create profile",
            order = 11,
            func = function()
              Addon():CreateProfile(Addon()._newProfileName)
              Addon()._newProfileName = ""
            end,
          },
          renameTo = {
            type = "input",
            name = "Rename current to",
            order = 12,
            width = "double",
            get = function()
              return Addon()._renameProfileTo or ""
            end,
            set = function(_, value)
              Addon()._renameProfileTo = value
            end,
          },
          rename = {
            type = "execute",
            name = "Rename profile",
            order = 13,
            func = function()
              Addon():RenameProfile(Addon()._renameProfileTo)
              Addon()._renameProfileTo = ""
            end,
          },
          delete = {
            type = "execute",
            name = "Delete current profile",
            order = 14,
            confirm = function()
              return "Delete profile " .. Addon().db:GetCurrentProfile() .. "?"
            end,
            disabled = function()
              return Addon().db:GetCurrentProfile() == "Default"
            end,
            func = function()
              Addon():DeleteCurrentProfile()
            end,
          },
          assignHeader = {
            type = "header",
            name = "Assignment",
            order = 20,
          },
          accountProfile = {
            type = "select",
            name = "Account profile",
            order = 21,
            width = "double",
            values = ProfileValues,
            get = function()
              return Addon().db.global.accountProfile or "Default"
            end,
            set = function(_, value)
              Addon().db.global.accountProfile = value
              ns.Notify()
            end,
          },
          characterProfile = {
            type = "select",
            name = "This character",
            order = 22,
            width = "double",
            values = CharacterProfileValues,
            get = function()
              local key = Addon():GetCharacterKey()
              if not key then
                return "_inherit"
              end
              return Addon().db.global.characters[key] or "\0"
            end,
            set = function(_, value)
              local key = Addon():GetCharacterKey()
              if not key then
                return
              end
              if value == "_inherit" then
                Addon().db.global.characters[key] = nil
              else
                Addon().db.global.characters[key] = value
              end
              ns.Notify()
            end,
          },
          specName = {
            type = "description",
            order = 23,
            name = function()
              local specName = Addon():GetSpecName()
              if not specName then
                return "Current spec: (unknown until in-game)"
              end
              return "Current spec: " .. specName
            end,
          },
          specEnabled = {
            type = "toggle",
            name = "Assign a profile to this spec",
            order = 24,
            width = "full",
            get = function()
              local row = Addon():GetSpecAssignment()
              return row and row.enabled or false
            end,
            set = function(_, value)
              local row = Addon():GetSpecAssignment()
              if row then
                row.enabled = value and true or false
                ns.Notify()
              end
            end,
          },
          specProfile = {
            type = "select",
            name = "Spec profile",
            order = 25,
            width = "double",
            values = ProfileValues,
            disabled = function()
              local row = Addon():GetSpecAssignment()
              return not (row and row.enabled)
            end,
            get = function()
              local row = Addon():GetSpecAssignment()
              return (row and row.profile) or "Default"
            end,
            set = function(_, value)
              local row = Addon():GetSpecAssignment()
              if row then
                row.profile = value
                ns.Notify()
              end
            end,
          },
          envHeader = {
            type = "header",
            name = "Environment",
            order = 30,
          },
          editingEnvironment = {
            type = "select",
            name = "Environment being edited",
            desc = "Values in MUFs, Cure, Alerts, and Advanced write into this pack. Manual this slice. No auto zone switch.",
            order = 31,
            width = "double",
            values = EnvironmentValues,
            get = function()
              return Addon():GetEditingEnvironment()
            end,
            set = function(_, value)
              Addon():SetEditingEnvironment(value)
            end,
          },
        },
      },
      mufs = {
        type = "group",
        name = "MUFs",
        order = 2,
        args = {
          which = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = EnvHeader,
          },
          note = {
            type = "description",
            order = 2,
            name = "Squares are not drawn in this slice. These values persist for the click-to-cure machine.",
          },
          show = {
            type = "toggle",
            name = "Show MUFs",
            order = 10,
            get = EnvGet("mufs", "show"),
            set = EnvSet("mufs", "show"),
          },
          size = {
            type = "range",
            name = "Size (px)",
            order = 11,
            min = 10,
            max = 72,
            step = 1,
            get = EnvGet("mufs", "size"),
            set = EnvSet("mufs", "size"),
          },
          spacing = {
            type = "range",
            name = "Spacing",
            order = 12,
            min = 0,
            max = 20,
            step = 1,
            get = EnvGet("mufs", "spacing"),
            set = EnvSet("mufs", "spacing"),
          },
          alpha = {
            type = "range",
            name = "Alpha",
            order = 13,
            min = 0.1,
            max = 1,
            step = 0.05,
            isPercent = true,
            get = EnvGet("mufs", "alpha"),
            set = EnvSet("mufs", "alpha"),
          },
          grow = {
            type = "select",
            name = "Grow",
            order = 14,
            values = GrowValues,
            get = EnvGet("mufs", "grow"),
            set = EnvSet("mufs", "grow"),
          },
          wrap = {
            type = "range",
            name = "Per row / column",
            order = 15,
            min = 1,
            max = 40,
            step = 1,
            get = EnvGet("mufs", "wrap"),
            set = EnvSet("mufs", "wrap"),
          },
        },
      },
      cure = {
        type = "group",
        name = "Cure",
        order = 3,
        args = {
          which = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = EnvHeader,
          },
          mode = {
            type = "select",
            name = "Click mode",
            order = 10,
            values = {AUTO = "AUTO (two-button)"},
            get = EnvGet("cure", "mode"),
            set = EnvSet("cure", "mode"),
          },
          modeHelp = {
            type = "description",
            order = 11,
            name = "AUTO maps two mouse buttons to cure. Click-to-cure buttons are not created in this slice.",
          },
          magic = {
            type = "toggle",
            name = "Magic",
            order = 20,
            get = EnvGet("cure", "magic"),
            set = EnvSet("cure", "magic"),
          },
          curse = {
            type = "toggle",
            name = "Curse",
            order = 21,
            get = EnvGet("cure", "curse"),
            set = EnvSet("cure", "curse"),
          },
          poison = {
            type = "toggle",
            name = "Poison",
            order = 22,
            get = EnvGet("cure", "poison"),
            set = EnvSet("cure", "poison"),
          },
          disease = {
            type = "toggle",
            name = "Disease",
            order = 23,
            get = EnvGet("cure", "disease"),
            set = EnvSet("cure", "disease"),
          },
          enrage = {
            type = "toggle",
            name = "Enrage",
            order = 24,
            get = EnvGet("cure", "enrage"),
            set = EnvSet("cure", "enrage"),
          },
        },
      },
      alerts = {
        type = "group",
        name = "Alerts",
        order = 4,
        args = {
          which = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = EnvHeader,
          },
          pvpText = {
            type = "toggle",
            name = "PvP text",
            desc = "Off by default.",
            order = 10,
            get = EnvGet("alerts", "pvpText"),
            set = EnvSet("alerts", "pvpText"),
          },
          text = {
            type = "toggle",
            name = "Text alerts",
            order = 11,
            get = EnvGet("alerts", "text"),
            set = EnvSet("alerts", "text"),
          },
          sound = {
            type = "toggle",
            name = "Sound alerts",
            order = 12,
            get = EnvGet("alerts", "sound"),
            set = EnvSet("alerts", "sound"),
          },
          errorSound = {
            type = "toggle",
            name = "Error sound",
            order = 13,
            get = EnvGet("alerts", "errorSound"),
            set = EnvSet("alerts", "errorSound"),
          },
        },
      },
      advanced = {
        type = "group",
        name = "Advanced",
        order = 5,
        args = {
          which = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = EnvHeader,
          },
          debug = {
            type = "toggle",
            name = "Debug chat",
            order = 10,
            get = EnvGet("advanced", "debug"),
            set = EnvSet("advanced", "debug"),
          },
          checkDelay = {
            type = "range",
            name = "Check delay (seconds)",
            order = 11,
            min = 0.05,
            max = 1,
            step = 0.05,
            get = EnvGet("advanced", "checkDelay"),
            set = EnvSet("advanced", "checkDelay"),
          },
          note = {
            type = "description",
            order = 20,
            name = "No minimap button. No Decursive_Options LoD. SavedVariables name is DecursiveRebuildDB. Does not read DecursiveDB.",
          },
        },
      },
    },
  }

  AceConfig:RegisterOptionsTable(addon.APP_NAME, options)
  addon.optionsFrame = AceConfigDialog:AddToBlizOptions(addon.APP_NAME, "Zhaohu's Decursive")
end
