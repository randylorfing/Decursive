local files = {
    "Decursive/Dcr_ProfileManager.lua",
    "Decursive/Dcr_ProfileIO.lua",
    "Decursive/Dcr_12_1.lua",
    "Decursive/Dcr_opt.lua",
    "Decursive/Dcr_DebuffsFrame.lua",
    "Decursive/DCR_init.lua",
    "Decursive/Dcr_DIAG.lua",
    "Decursive/Modern/ZD_Core.lua",
    "Decursive/V13/Core/SettingsSchema.lua",
    "Decursive_Options/V13/Shell.lua",
    "Decursive_Options/V13/Pages/Profiles.lua",
    "Decursive_Options/Modern/ZD_UI.lua",
    "Decursive_Options/Dcr_opt_tree.lua",
    ".github/scripts/test-profile-manager.lua",
}

for _, path in ipairs(files) do
    local chunk, errorMessage = loadfile(path)
    assert(chunk, path .. ": " .. tostring(errorMessage))
end

io.write("PASS: full environment variant Lua files parse\n")
