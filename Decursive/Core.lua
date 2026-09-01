local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local Decursive = AceAddon:NewAddon("Decursive", "AceConsole-3.0", "AceEvent-3.0")
ns.addon = Decursive

Decursive.APP_NAME = "Decursive"

local function Notify()
  AceConfigRegistry:NotifyChange(Decursive.APP_NAME)
end

ns.Notify = Notify

function Decursive:OnInitialize()
  self.db = AceDB:New("DecursiveRebuildDB", ns.defaults, true)
  self:EnsureEnvironments()
  ns.RegisterOptions(self)
  self:RegisterChatCommand("dcr", "OpenOptions")
  self:RegisterChatCommand("decursive", "OpenOptions")
end

function Decursive:OnEnable()
  self:ApplyResolvedProfile("login")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
end

function Decursive:OnEnteringWorld()
  self:ApplyResolvedProfile("world")
end

function Decursive:OnSpecChanged()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[self.APP_NAME] then
    return
  end
  self:ApplyResolvedProfile("spec")
end

function Decursive:OpenOptions()
  AceConfigDialog:SetDefaultSize(self.APP_NAME, 720, 580)
  AceConfigDialog:Open(self.APP_NAME)
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

function Decursive:EnsureEnvironments()
  local environments = self.db.profile.environments
  if type(environments) ~= "table" then
    self.db.profile.environments = ns.MakeEnvironments()
    return
  end
  for _, row in ipairs(ns.ENVIRONMENTS) do
    if type(environments[row.key]) ~= "table" then
      environments[row.key] = ns.DeepCopy(ns.PACK)
    else
      self:FillMissing(environments[row.key], ns.PACK)
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

function Decursive:GetSpecAssignment()
  local key = self:GetCharacterKey()
  local spec = self:GetSpecIndex()
  if not key or not spec then
    return nil, nil
  end
  local specMap = self.db.global.specs[key]
  if not specMap then
    specMap = {}
    self.db.global.specs[key] = specMap
  end
  local row = specMap[spec]
  if type(row) ~= "table" then
    row = {enabled = false, profile = "Default"}
    specMap[spec] = row
  end
  return row, spec
end
