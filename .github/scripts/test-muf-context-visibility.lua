local function readFile(path)
    local nativeReadFile = _G and _G.readfile
    if type(io.open) ~= "function" and type(nativeReadFile) == "function" then
        return assert(nativeReadFile(path))
    end
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local function contains(text, value)
    return text:find(value, 1, true) ~= nil
end

local source = readFile("Decursive_Options/Modern/ZD_UI.lua")
local core = readFile("Decursive/Modern/ZD_Core.lua")
local shell = readFile("Decursive_Options/V13/Shell.lua")
local block = assert(source:match("%-%- MUF_CONTEXT_SIZE_VISIBILITY_BEGIN(.-)%-%- MUF_CONTEXT_SIZE_VISIBILITY_END"),
    "context-aware MUF size visibility block is missing")

local partySize = 31
local raidSize = 47
local partyWrites = 0
local raidWrites = 0
local editEnvironment = "OPEN_WORLD"

local TestZD = {
    GetEditEnvironment = function() return editEnvironment end,
    SetPartyMUFSizePixels = function(_, value)
        partyWrites = partyWrites + 1
        partySize = value
        return true
    end,
    SetRaidMUFSizePixels = function(_, value)
        raidWrites = raidWrites + 1
        raidSize = value
        return true
    end,
}
_G.ZD = TestZD

local loader = loadstring or load
assert(loader(block, "@MUF context visibility"))()

local expectations = {
    OPEN_WORLD = { true, true },
    DUNGEON = { true, false },
    MYTHIC_PLUS = { true, false },
    RAID = { false, true },
    PVP = { true, true },
}

for environment, expected in pairs(expectations) do
    editEnvironment = environment
    local beforeParty = partySize
    local beforeRaid = raidSize
    local beforePartyWrites = partyWrites
    local beforeRaidWrites = raidWrites
    local partyVisible, raidVisible = TestZD:GetMUFSizeVisibilityForEnvironment(environment)
    assert(partyVisible == expected[1], environment .. " Party visibility is wrong")
    assert(raidVisible == expected[2], environment .. " Raid visibility is wrong")
    assert(partySize == beforeParty and raidSize == beforeRaid,
        environment .. " visibility lookup mutated saved size values")
    assert(partyWrites == beforePartyWrites and raidWrites == beforeRaidWrites,
        environment .. " visibility lookup called a size setter")
end

editEnvironment = "RAID"
assert(TestZD:SetVisibleMUFSizePixels("PARTY", 60) == false)
assert(partySize == 31 and partyWrites == 0, "hidden Party control wrote data in Raid")
assert(TestZD:SetVisibleMUFSizePixels("RAID", 61) == true)
assert(raidSize == 61 and raidWrites == 1, "visible Raid control did not write in Raid")

editEnvironment = "DUNGEON"
assert(TestZD:SetVisibleMUFSizePixels("RAID", 62) == false)
assert(raidSize == 61 and raidWrites == 1, "hidden Raid control wrote data in Party/Dungeon")
assert(TestZD:SetVisibleMUFSizePixels("PARTY", 63) == true)
assert(partySize == 63 and partyWrites == 1, "visible Party control did not write in Party/Dungeon")

assert(contains(source, 'self.partySize:SetShown(partyVisible)'))
assert(contains(source, 'self.raidSize:SetShown(raidVisible)'))
assert(contains(source, 'Hidden size values stay saved. They are not deleted.'))
local editSetter = assert(core:match("function ZD:SetEditEnvironment%(key%)(.-)function ZD:GetEnvironmentProfile"))
assert(contains(editSetter, "if self.RefreshUI then self:RefreshUI() end"),
    "editing-context switches do not request an immediate UI refresh")
assert(contains(shell, "if page and page.IsShown and page:IsShown() and page.Refresh then page:Refresh() end"),
    "primary V13 UI refresh does not refresh the visible workspace")

io.write("PASS: context-aware MUF size visibility, hidden-control write guards, and data preservation\n")
