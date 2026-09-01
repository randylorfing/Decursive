local function readFile(path)
    if type(readfile) == "function" then
        return assert(readfile(path))
    end
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    file:close()
    return text
end

local function requireText(source, text)
    assert(source:find(text, 1, true), "missing startup sentinel contract: " .. text)
end

local files = {
    "Decursive/Dcr_DebuffsFrame.lua",
    "Decursive/Dcr_DebuffsFrame.xml",
    "Decursive/Dcr_LiveList.lua",
    "Decursive/Dcr_LiveList.xml",
}

for _, path in ipairs(files) do
    local source = readFile(path)
    requireText(source, "local function StartupMarkerState(fileName)")
    requireText(source, "=not-started")
    requireText(source, "=started-not-completed")
    requireText(source, "T._StartupActiveFile")
end

local debuffsLua = readFile(files[1])
requireText(debuffsLua, "StartupMarkerState(\"Dcr_lists.lua\")")
requireText(debuffsLua, "StartupMarkerState(\"Dcr_lists.xml\")")
requireText(debuffsLua, "T._StartupActiveFile = \"Dcr_DebuffsFrame.lua\"")

local debuffsXml = readFile(files[2])
requireText(debuffsXml, "StartupMarkerState(\"Dcr_DebuffsFrame.lua\")")
requireText(debuffsXml, "T._StartupActiveFile = \"Dcr_DebuffsFrame.xml\"")

local liveListLua = readFile(files[3])
requireText(liveListLua, "StartupMarkerState(\"Dcr_DebuffsFrame.lua\")")
requireText(liveListLua, "StartupMarkerState(\"Dcr_DebuffsFrame.xml\")")
requireText(liveListLua, "T._StartupActiveFile = \"Dcr_LiveList.lua\"")

local liveListXml = readFile(files[4])
requireText(liveListXml, "StartupMarkerState(\"Dcr_LiveList.lua\")")
requireText(liveListXml, "T._StartupActiveFile = \"Dcr_LiveList.xml\"")
requireText(liveListXml, 'name="DcrLiveList" frameStrata="LOW" toplevel="true" enableMouse="true" movable="true" hidden="true"')

local initSource = readFile("Decursive/DCR_init.lua")
local liveListScale = assert(initSource:find("DcrLiveList:SetScale(D.profile.LiveListScale)", 1, true))
local liveListDecision = assert(initSource:find("if (D.profile.HideLiveList) then", liveListScale, true))
local between = initSource:sub(liveListScale, liveListDecision - 1)
assert(not between:find("DcrLiveList:Show()", 1, true), "LiveList must remain hidden until the profile visibility decision")

io.write("live-list startup sentinel tests passed\n")
