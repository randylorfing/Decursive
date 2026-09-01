local ADDON_NAME, ns = ...

local MAX_LEARNED = 40
local TEAL = {0.32, 0.86, 0.82}

local SOUND_DIR = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local PRESET_FILES = {
  FEMALE_DISPEL = SOUND_DIR .. "FemaleDispel.ogg",
  FEMALE_DISPEL_ME = SOUND_DIR .. "FemaleDispelMe.ogg",
  FEMALE_CLEANSE = SOUND_DIR .. "FemaleCleanse.ogg",
  FEMALE_CLEANSE_ME = SOUND_DIR .. "FemaleCleanseMe.ogg",
  AFFLICTION = SOUND_DIR .. "AfflictionAlert.ogg",
  QUICK = SOUND_DIR .. "G_NecropolisWound-fast.ogg",
  BRIGHT_PING = SOUND_DIR .. "BrightPing.ogg",
  DOUBLE_PING = SOUND_DIR .. "DoublePing.ogg",
  TRIPLE_PING = SOUND_DIR .. "TriplePing.ogg",
  HIGH_CHIME = SOUND_DIR .. "HighChime.ogg",
  LOW_CHIME = SOUND_DIR .. "LowChime.ogg",
  PULSE_UP = SOUND_DIR .. "PulseUp.ogg",
  PULSE_DOWN = SOUND_DIR .. "PulseDown.ogg",
  FAILURE = SOUND_DIR .. "FailedSpell.ogg",
}
