local function readFile(path)
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

io.write("live-list startup sentinel tests passed\n")
