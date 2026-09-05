-- ZDecursive, based on Decursive, Copyright (C) 2006-2026 John Wellesz.
-- ZDecursive rebuild and maintenance, Copyright (C) 2026 Randy Lorfing.
-- GPL-3.0-or-later; distributed without warranty. See the repository LICENSE.
-- Controlled model data for the actual Options.lua geometry contract.
local diagnosticEvents = {}
local ns = {}
assert(loadfile("ZDecursive/Defaults.lua"))("ZDecursive", ns)
local environments = ns.MakeEnvironments()
local environmentStatus = {
  available = true,
  appliedEnvironment = "OPEN_WORLD",
  detectedEnvironment = "OPEN_WORLD",
  environmentMode = "multiple",
  editingEnvironment = "OPEN_WORLD",
}
local addon = {
  db = {
    profile = {environments = environments},
    global = {accountProfile = "Default", characters = {}, specs = {}, schema = 3},
    char = {editingEnvironment = "OPEN_WORLD", optionsSimple = true},
  },
}
function addon:GetEditingEnvironment()
  return self.db.char.editingEnvironment
end
function addon:GetEditingPack()
  return self.db.profile.environments[self:GetEditingEnvironment()]
end
function addon:GetAppliedEnvironmentPack()
  return self.db.profile.environments.OPEN_WORLD
end
function addon:GetUIProfileStatus()
  return {available = true, actualProfile = "Default", resolvedProfile = "Default", resolvedTier = "default"}
end
function addon:GetEnvironmentProfileStatus()
  environmentStatus.editingEnvironment = self:GetEditingEnvironment()
  return environmentStatus
end
function addon:GetEnvironmentMode()
  return environmentStatus.environmentMode
end
function addon:SetEnvironmentMode(mode)
  environmentStatus.environmentMode = mode
  self.db.char.editingEnvironment = mode == "solo" and "SOLO" or "OPEN_WORLD"
  return true, "selected"
end
function addon:EnsureEnvironments() end
function addon:GetCurrentProfileName() return "Default" end
function addon:GetProfileNames() return {"Default"} end
function addon:GetCharacterKey() return nil end
function addon:GetSpecIndex() return 1 end
function addon:GetSpecName() return "Test specialization" end
function addon:SpecSlotCount() return 4 end
function addon:EnsureSpecAssignments() return {} end
function addon:GetSpecAssignment() return {enabled = false, profile = "Default"} end
function addon:SetEditingEnvironment(environment)
  if not ns.ENV_SET[environment] then
    return false, "env"
  end
  self.db.char.editingEnvironment = environment
  return true, "selected"
end
ns.addon = addon
ns.GetKnownCures = function()
  return {{name = "Test Cure", spellId = 123, types = {"magic"}}}
end
ns.GetResolvedClickStatus = function()
  return {
    available = true,
    mode = "AUTO",
    pending = false,
    mappings = {
      {gesture = "Middle", action = "Target", kind = "TARGET"},
      {gesture = "Ctrl+Middle", action = "Focus", kind = "FOCUS"},
    },
  }
end
ns.RegisterDiagnosticProvider = function(_, callback)
  ns.optionsDiagnosticProvider = callback
end
ns.DiagnosticModuleLoaded = function() end
ns.DiagnosticModuleEnabled = function() end
ns.DiagnosticModuleRefresh = function() end
ns.DiagnosticRecord = function(kind, fields)
  diagnosticEvents[#diagnosticEvents + 1] = {kind = kind, fields = fields}
end


return {ns=ns, addon=addon, environmentStatus=environmentStatus}
