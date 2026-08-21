-- Decursive profile import/export helpers.
-- Uses AceSerializer-3.0 and intentionally operates on the active AceDB profile only.

local addonName, T = ...
local D = T and T.Dcr
if not D then return end

local Serializer = LibStub("AceSerializer-3.0", true)
local FORMAT = "DECursiveProfile"
local FORMAT_VERSION = 1

local function copyInto(dst, src)
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do
        if type(v) == "table" then
            local t = {}
            dst[k] = t
            copyInto(t, v)
        else
            dst[k] = v
        end
    end
end

function D:GetProfileExportString()
    if not Serializer or not self.db or type(self.db.profile) ~= "table" then
        return ""
    end

    local payload = {
        format = FORMAT,
        version = FORMAT_VERSION,
        addon = "Decursive",
        addonVersion = self.version or "unknown",
        interface = select(4, GetBuildInfo()),
        profileName = self.db:GetCurrentProfile(),
        profile = self.db.profile,
    }

    local ok, serialized = pcall(Serializer.Serialize, Serializer, payload)
    if not ok then
        self.ProfileIOStatus = "|cffff3333Export failed:|r " .. tostring(serialized)
        return ""
    end
    self.ProfileIOStatus = "|cff55ff55Profile export ready.|r"
    return serialized
end

function D:SetProfileImportBuffer(text)
    self.ProfileImportBuffer = type(text) == "string" and text or ""
end

function D:GetProfileImportBuffer()
    return self.ProfileImportBuffer or ""
end

function D:ImportProfileString(text)
    if InCombatLockdown() then
        self.ProfileIOStatus = "|cffff3333Profiles cannot be imported during combat.|r"
        return false
    end
    if not Serializer then
        self.ProfileIOStatus = "|cffff3333AceSerializer-3.0 is unavailable.|r"
        return false
    end
    if type(text) ~= "string" or text:match("^%s*$") then
        self.ProfileIOStatus = "|cffff3333Paste a Decursive profile string first.|r"
        return false
    end

    local ok, payload = Serializer:Deserialize(text)
    if not ok then
        self.ProfileIOStatus = "|cffff3333Import failed:|r invalid serialized data."
        return false
    end
    if type(payload) ~= "table" or payload.format ~= FORMAT or payload.version ~= FORMAT_VERSION or type(payload.profile) ~= "table" then
        self.ProfileIOStatus = "|cffff3333Import failed:|r this is not a supported Decursive profile export."
        return false
    end

    -- Preserve AceDB's profile table identity; several parts of Decursive cache D.profile.
    copyInto(self.db.profile, payload.profile)
    self.ProfileImportBuffer = ""
    self.ProfileIOStatus = "|cff55ff55Profile imported successfully.|r"

    -- Rebuild all runtime shortcuts and managed 12.1 state using the imported values.
    self:SetConfiguration()
    return true
end

function D:GetProfileIOStatus()
    return self.ProfileIOStatus or "Exports contain only the active AceDB profile. Global, locale, and class-scoped data are not overwritten."
end
