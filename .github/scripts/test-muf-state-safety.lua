local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local function requireText(source, text)
    assert(source:find(text, 1, true), "missing MUF state-safety contract: " .. text)
end

local function rejectText(source, text)
    assert(not source:find(text, 1, true), "unexpected MUF state-safety implementation: " .. text)
end

local utilsSource = readFile("Decursive/Dcr_12_1_Utils.lua")
local frameSource = readFile("Decursive/Dcr_DebuffsFrame.lua")
local nativeSource = readFile("Decursive/Dcr_12_1.lua")

local classStart = assert(utilsSource:find("local canaccessvalue = _G.canaccessvalue", 1, true))
local classEnd = assert(utilsSource:find("function D:IsUnitCharmedSafe", classStart, true))
local classSource = utilsSource:sub(classStart, classEnd - 1)

local SECRET = {}
local INACCESSIBLE = {}
local classes = {
    party1 = { "Warrior", "WARRIOR", 1 },
    focus = { "Mage", SECRET, 8 },
    raid1 = { INACCESSIBLE, "PRIEST", 5 },
    target = "error",
}

_G.canaccessvalue = function(value)
    return value ~= INACCESSIBLE
end
_G.issecretvalue = function(value)
    return value == SECRET
end
D = {}
UnitClass = function(unit)
    local value = classes[unit]
    if value == "error" then error("synthetic UnitClass failure") end
    if not value then return nil end
    return value[1], value[2], value[3]
end

local loader = loadstring or load
assert(loader(classSource, "muf-class-safety-test"))()

local localized, classFile, classID = D:GetUnitClassSafe("party1")
assert(localized == "Warrior" and classFile == "WARRIOR" and classID == 1)

localized, classFile, classID = D:GetUnitClassSafe("focus")
assert(localized == "Mage" and classFile == nil and classID == 8)

localized, classFile, classID = D:GetUnitClassSafe("raid1")
assert(localized == nil and classFile == "PRIEST" and classID == 5)

localized, classFile, classID = D:GetUnitClassSafe("target")
assert(localized == nil and classFile == nil and classID == nil)
assert(D:GetUnitClassSafe(nil) == nil)

requireText(frameSource, "local unitExists = accessibleCall(UnitExists, Unit)")
requireText(frameSource, "local unitVisible = accessibleCall(UnitIsVisible, Unit)")
requireText(frameSource, "local unitLevel = accessibleCall(UnitLevel, Unit)")
requireText(frameSource, "self.Color = MF_colors[self.Debuff1Prio]")
requireText(frameSource, "self.UnitStatus = AFFLICTED_NIR")
requireText(frameSource, "if self.IsCharmed then")
requireText(frameSource, "if not DC.TWELVEONE and debuffs[1] then")
requireText(frameSource, "D:GetUnitClassSafe(self.CurrUnit)")
requireText(frameSource, "D:Begin121SecureActionAttempt(frame.Object, Button, RequestedPrio)")
requireText(frameSource, "D:Begin121SoulLinkAttempt(frame.Object, Button, RequestedPrio, modifier == nil)")
requireText(frameSource, "MF.UpdateCountDown = 3")
requireText(frameSource, "SetCooldownFromDurationObject")
requireText(frameSource, "SetSpellCooldownFromDurationObject(self.CooldownFrame, Status.CuringSpells[DebuffType])")
requireText(frameSource, "SetItemCooldownFromDurationObject(self.CooldownFrame, -1 * SpellID)")

requireText(nativeSource, "local function getPriorityColor(priority)")
requireText(nativeSource, "local function setPriorityGateActive(MF, priority, active, durationObject)")
requireText(nativeSource, "SetCooldownFromDurationObject")
requireText(nativeSource, "local function attachNativeVerificationCarriers(MF, Unit)")
requireText(nativeSource, "local function rebindNativeManagedAuraOwners(MF, candidate, force)")
requireText(nativeSource, "local function nativeRangeValueForMUF(MF)")
requireText(nativeSource, "SetVertexColorFromBoolean")
requireText(nativeSource, "function D:Mark121MUFStatusFailure(unitOrMF, reason)")
requireText(nativeSource, "function D:Clear121MUFDeathSoulLinkRange(MF)")
rejectText(nativeSource, "AuraUtil.ForEachAura")

io.write("muf state-safety tests passed\n")
