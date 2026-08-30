local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local function requireText(source, text)
    assert(source:find(text, 1, true), "missing Dcr_12_1 local-budget contract: " .. text)
end

local function forbidText(source, text)
    assert(not source:find(text, 1, true), "retained unnecessary file-scope local: " .. text)
end

local source = readFile("Decursive/Dcr_12_1.lua")

for _, declaration in ipairs({
    "local C_UnitAuras = _G.C_UnitAuras",
    "local UnitClass = _G.UnitClass",
    "local GetSpecialization = _G.GetSpecialization",
    "local GetSpecializationInfo = _G.GetSpecializationInfo",
    "local GetBuildInfo = _G.GetBuildInfo",
    "local PATCH_VERSION = \"@project-version@\"",
    "local PROVIDER_NATIVE = \"NATIVE\"",
    "local C_ChallengeMode = _G.C_ChallengeMode",
    "local function getAlertColor()",
}) do
    forbidText(source, declaration)
end

requireText(source, "local challengeMode = _G.C_ChallengeMode")
requireText(source, "local unitClass = _G.UnitClass")
requireText(source, "local getSpecialization = _G.GetSpecialization")
requireText(source, "local getBuildInfo = _G.GetBuildInfo")
requireText(source, "Patch version: |cFF55DDDD@project-version@|r")

io.write("Dcr_12_1 local-budget tests passed\n")
