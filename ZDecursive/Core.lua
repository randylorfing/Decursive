local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

local Decursive = AceAddon:NewAddon("Decursive", "AceConsole-3.0", "AceEvent-3.0")
ns.addon = Decursive

Decursive.APP_NAME = "Decursive"

local function Notify()
  if ns.InvalidateDetection then
    ns.InvalidateDetection()
  end
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  if ns.RefreshAlerts then
    ns.RefreshAlerts()
  end
  if ns.RefreshLiveList then
    ns.RefreshLiveList()
  end
end

ns.Notify = Notify

function Decursive:OnInitialize()
  self.db = AceDB:New("DecursiveRebuildDB", ns.defaults, true)
  self:EnsureEnvironments()
  ns.RegisterOptions(self)
  if ns.RegisterLists then
    ns.RegisterLists(self)
  end
  self:RegisterChatCommand("dcr", "OpenOptions")
  self:RegisterChatCommand("zd", "OpenOptions")
  self:RegisterChatCommand("zdecursive", "OpenOptions")
  if self.UnregisterChatCommand then
    self:UnregisterChatCommand("decursive")
  end
  SlashCmdList["ACECONSOLE_DECURSIVE"] = nil
  _G["SLASH_ACECONSOLE_DECURSIVE1"] = nil
  SlashCmdList["DECURSIVE"] = nil
  _G["SLASH_DECURSIVE1"] = nil
  if type(hash_SlashCmdList) == "table" then
    hash_SlashCmdList["/DECURSIVE"] = nil
    hash_SlashCmdList["/decursive"] = nil
  end
  self:RegisterChatCommand("dcrsoullink", function(msg)
    if ns.HandleSoulLinkSlash then
      ns.HandleSoulLinkSlash(msg)
    end
  end)
  self:RegisterChatCommand("dcrsoullinkstatus", function()
    if ns.PrintSoulLinkStatus then
      ns.PrintSoulLinkStatus()
    end
  end)
  self:RegisterChatCommand("zdsound", function(msg)
    local spellText, unitToken = tostring(msg or ""):match("^%s*(%d+)%s*(%S*)")
    if ns.PrintAuraSoundDiagnostics then
      ns.PrintAuraSoundDiagnostics(tonumber(spellText), unitToken)
    end
  end)
  self:RegisterChatCommand("dcrstatus", function()
    if ns.PrintAddonStatus then
      ns.PrintAddonStatus()
    end
  end)
  self:RegisterChatCommand("dcrhelp", function()
    if ns.PrintSlashHelp then
      ns.PrintSlashHelp()
    end
  end)
  self:RegisterChatCommand("dcrdiag", function()
    if ns.PrintDiagnostics then
      ns.PrintDiagnostics()
    end
  end)
  self:RegisterChatCommand("dcrreset", function(msg)
    self:HandleResetSlash(msg)
  end)
  self:RegisterChatCommand("dcridentity", function()
    if ns.PrintIdentity then
      ns.PrintIdentity()
    end
  end)
  self:RegisterChatCommand("dcralerts", function(msg)
    if ns.HandleAlertsSlash then
      ns.HandleAlertsSlash(msg)
    end
  end)
  self:RegisterChatCommand("dcrreport", function()
    if ns.PrintReport then
      ns.PrintReport()
    elseif ns.PrintDiagnostics then
      ns.PrintDiagnostics()
    end
  end)
  self:RegisterChatCommand("dcralertdiag", function(msg)
    if ns.HandleAlertDiagSlash then
      ns.HandleAlertDiagSlash(msg)
    elseif ns.PrintAuraSoundDiagnostics then
      ns.PrintAuraSoundDiagnostics()
    end
  end)
end

function Decursive:OnEnable()
  if self.UnregisterChatCommand then
    self:UnregisterChatCommand("decursive")
  end
  self:EnsureSpecAssignments()
  self:ApplyResolvedProfile("login")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
  if ns.EnableDetection then
    ns.EnableDetection()
  end
  if ns.EnableMUFs then
    ns.EnableMUFs(self)
  end
  if ns.EnableAlerts then
    ns.EnableAlerts(self)
  end
  if ns.EnableLiveList then
    ns.EnableLiveList(self)
  end
end

function Decursive:OnGroupRosterUpdate()
  if ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  if ns.RefreshAlerts then
    ns.RefreshAlerts()
  end
  if ns.RefreshLiveList then
    ns.RefreshLiveList()
  end
end

function Decursive:OnRegenEnabled()
  self:EnsureEnvironments()
  if ns.InvalidateDetection then
    ns.InvalidateDetection()
  end
  if ns.RebuildClickModel then
    ns.RebuildClickModel()
  end
  if ns.RecoverMUFsAfterCombat then
    ns.RecoverMUFsAfterCombat()
  elseif ns.RefreshMUFs then
    ns.RefreshMUFs()
  end
  if ns.RefreshAlerts then
    ns.RefreshAlerts()
  end
  if ns.ApplyAlertMoveMode then
    ns.ApplyAlertMoveMode()
  end
  if ns.RefreshLiveList then
    ns.RefreshLiveList()
  end
end

function Decursive:OnEnteringWorld()
  self:EnsureSpecAssignments()
  self:ApplyResolvedProfile("world")
  if ns.ApplyAlertMoveMode then
    ns.ApplyAlertMoveMode()
  end
end

function Decursive:OnSpecChanged()
  self:EnsureSpecAssignments()
  if ns.ScheduleFollowerRosterGuard then
    ns.ScheduleFollowerRosterGuard()
  end
  if ns.IsOptionsShown and ns.IsOptionsShown() then
    return
  end
  self:ApplyResolvedProfile("spec")
end

function Decursive:OpenOptions()
  ns.ShowOptions()
end

function Decursive:GetCharacterKey()
  local name = UnitName("player")
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
  if not name or name == "" or not realm or realm == "" then
    return nil
  end
  realm = realm:gsub("%s+", "")
  return name .. "-" .. realm
end

function Decursive:GetSpecIndex()
  local spec
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    spec = C_SpecializationInfo.GetSpecialization()
  elseif GetSpecialization then
    spec = GetSpecialization()
  end
  if not spec or spec == 0 then
    return nil
  end
  return spec
end

function Decursive:GetSpecName(spec)
  spec = spec or self:GetSpecIndex()
  if not spec then
    return nil
  end
  local id, name
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    id, name = C_SpecializationInfo.GetSpecializationInfo(spec)
  elseif GetSpecializationInfo then
    id, name = GetSpecializationInfo(spec)
  end
  return name or ("Spec " .. tostring(spec))
end

function Decursive:ProfileExists(name)
  if not name or name == "" then
    return false
  end
  for _, existing in ipairs(self.db:GetProfiles()) do
    if existing == name then
      return true
    end
  end
  return false
end

function Decursive:ResolveProfileName()
  local key = self:GetCharacterKey()
  local spec = self:GetSpecIndex()
  local g = self.db.global
  if key and spec then
    local specMap = g.specs[key]
    local row = specMap and specMap[spec]
    if row and row.enabled and self:ProfileExists(row.profile) then
      return row.profile
    end
  end
  if key then
    local charProfile = g.characters[key]
    if self:ProfileExists(charProfile) then
      return charProfile
    end
  end
  if self:ProfileExists(g.accountProfile) then
    return g.accountProfile
  end
  return "Default"
end

function Decursive:ApplyResolvedProfile(_reason)
  local name = self:ResolveProfileName()
  if self.db:GetCurrentProfile() ~= name then
    self.db:SetProfile(name)
  end
  self:EnsureEnvironments()
  Notify()
end

function Decursive:EnsureLists()
  local lists = self.db.profile.lists
  if type(lists) ~= "table" then
    self.db.profile.lists = {
      priority = {},
      skip = {},
    }
    return
  end
  if type(lists.priority) ~= "table" then
    lists.priority = {}
  end
  if type(lists.skip) ~= "table" then
    lists.skip = {}
  end
end

function Decursive:EnsureEnvironments()
  ns.lastMacroDrops = 0
  self:EnsureLists()
  local environments = self.db.profile.environments
  if type(environments) ~= "table" then
    self.db.profile.environments = ns.MakeEnvironments()
    environments = self.db.profile.environments
  end
  for _, row in ipairs(ns.ENVIRONMENTS) do
    if type(environments[row.key]) ~= "table" then
      environments[row.key] = ns.MakePack(row.key)
    else
      self:FillMissing(environments[row.key], ns.PACK)
    end
    if ns.DropOversizedMacros then
      ns.DropOversizedMacros(environments[row.key])
    end
  end
end

function Decursive:FillMissing(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = ns.DeepCopy(v)
      else
        self:FillMissing(dst[k], v)
      end
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function Decursive:GetEditingEnvironment()
  local env = self.db.char.editingEnvironment
  if not ns.ENV_SET[env] then
    env = "OPEN_WORLD"
    self.db.char.editingEnvironment = env
  end
  self:EnsureEnvironments()
  return env
end

function Decursive:GetEditingPack()
  local env = self:GetEditingEnvironment()
  return self.db.profile.environments[env]
end

function Decursive:SetEditingEnvironment(env)
  if ns.ENV_SET[env] then
    self.db.char.editingEnvironment = env
    self:EnsureEnvironments()
    Notify()
  end
end

function Decursive:ResetEditingPack()
  local env = self:GetEditingEnvironment()
  self.db.profile.environments[env] = ns.MakePack(env)
  Notify()
  return true
end

function Decursive:CopyEditingPackTo(targetEnv)
  if not ns.ENV_SET[targetEnv] then
    return false, "env"
  end
  local src = self:GetEditingEnvironment()
  if src == targetEnv then
    return false, "same"
  end
  self:EnsureEnvironments()
  self.db.profile.environments[targetEnv] = ns.DeepCopy(self:GetEditingPack())
  Notify()
  return true
end

function Decursive:ResetCurrentProfile()
  self.db.profile.environments = ns.MakeEnvironments()
  self.db.profile.lists = {
    priority = {},
    skip = {},
  }
  Notify()
  return true
end

function Decursive:ResetAllSettings()
  self.db:ResetDB("Default")
  self:EnsureEnvironments()
  Notify()
  return true
end

function Decursive:CreateProfile(name)
  name = strtrim(name or "")
  if name == "" then
    return false, "empty"
  end
  if self:ProfileExists(name) then
    return false, "exists"
  end
  self.db:SetProfile(name)
  self:EnsureEnvironments()
  Notify()
  return true
end

function Decursive:CopyProfile(name)
  name = strtrim(name or "")
  local oldName = self.db:GetCurrentProfile()
  if name == "" or name == oldName then
    return false, "empty"
  end
  if self:ProfileExists(name) then
    return false, "exists"
  end
  self.db:SetProfile(name)
  self.db:CopyProfile(oldName, true)
  self:EnsureEnvironments()
  Notify()
  return true
end

function Decursive:RenameProfile(newName)
  newName = strtrim(newName or "")
  local oldName = self.db:GetCurrentProfile()
  if newName == "" or newName == oldName then
    return false, "empty"
  end
  if self:ProfileExists(newName) then
    return false, "exists"
  end
  self.db:SetProfile(newName)
  self.db:CopyProfile(oldName, true)
  self:RetargetAssignments(oldName, newName)
  if oldName ~= "Default" then
    self.db:DeleteProfile(oldName, true)
  end
  self:EnsureEnvironments()
  Notify()
  return true
end

function Decursive:DeleteCurrentProfile()
  local name = self.db:GetCurrentProfile()
  if name == "Default" then
    return false, "default"
  end
  self.db:SetProfile("Default")
  self.db:DeleteProfile(name, true)
  self:RetargetAssignments(name, "Default")
  self:EnsureEnvironments()
  Notify()
  return true
end

function Decursive:RetargetAssignments(oldName, newName)
  local g = self.db.global
  if g.accountProfile == oldName then
    g.accountProfile = newName
  end
  for key, profileName in pairs(g.characters) do
    if profileName == oldName then
      g.characters[key] = newName
    end
  end
  for key, specMap in pairs(g.specs) do
    if type(specMap) == "table" then
      for spec, row in pairs(specMap) do
        if type(row) == "table" and row.profile == oldName then
          row.profile = newName
        end
      end
    end
  end
end

function Decursive:SpecSlotCount()
  local count
  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations then
    count = C_SpecializationInfo.GetNumSpecializations()
  elseif GetNumSpecializations then
    count = GetNumSpecializations()
  end
  if type(count) ~= "number" or count < 1 then
    count = 4
  end
  if count > 4 then
    count = 4
  end
  return count
end

function Decursive:EnsureSpecAssignments()
  local key = self:GetCharacterKey()
  if not key then
    return nil
  end
  local specMap = self.db.global.specs[key]
  if type(specMap) ~= "table" then
    specMap = {}
    self.db.global.specs[key] = specMap
  end
  for spec = 1, self:SpecSlotCount() do
    if type(specMap[spec]) ~= "table" then
      specMap[spec] = {enabled = false, profile = "Default"}
    end
  end
  return specMap
end

function Decursive:GetSpecAssignment(specIndex)
  local key = self:GetCharacterKey()
  if not key then
    return nil, nil
  end
  local specMap = self:EnsureSpecAssignments()
  local spec = specIndex or self:GetSpecIndex()
  if not spec or not specMap then
    return nil, nil
  end
  local row = specMap[spec]
  if type(row) ~= "table" then
    row = {enabled = false, profile = "Default"}
    specMap[spec] = row
  end
  return row, spec
end

function Decursive:HandleResetSlash(msg)
  msg = strtrim(tostring(msg or "")):lower()
  if msg == "" or msg == "pack" or msg == "env" then
    local env = self:GetEditingEnvironment()
    self:ResetEditingPack()
    self:Print("reset pack " .. tostring(env))
    return
  end
  if msg == "profile" then
    self:ResetCurrentProfile()
    self:Print("reset profile " .. tostring(self.db:GetCurrentProfile()))
    return
  end
  if msg == "all" then
    self:ResetAllSettings()
    self:Print("reset all settings")
    return
  end
  self:Print("/dcrreset [pack|profile|all]")
end
