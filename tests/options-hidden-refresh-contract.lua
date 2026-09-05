--[[
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ZDecursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ZDecursive. If not, see <https://www.gnu.org/licenses/>.
--]]

-- Execute the actual view path. Hidden runtime notifications must not re-read
-- UI status/catalog values; opening again must display the latest model.
local model = assert(loadfile("tests/fixtures/frame-mock.lua"))()
model.Install(1920,1080)
local fixture=assert(loadfile("tests/fixtures/options-fixture.lua"))()
local ns, addon=fixture.ns, fixture.addon
local reads=0
local original=addon.GetUIProfileStatus
function addon:GetUIProfileStatus() reads=reads+1; return original(self) end
local file=assert(io.open("ZDecursive/Options.lua","rb"))
local source=file:read("*a"); file:close()
local inspect=assert((loadstring or load)(source.."\nreturn {ui=ui}","@Options-hidden-test"))("ZDecursive",ns)
assert(ns.ShowOptions())
local before=reads
ns.RefreshOptions()
assert(reads>before, "visible options update immediately")
inspect.ui.frame:Hide()
before=reads
addon:SetEditingEnvironment("PVP")
for i=1,10 do ns.RefreshOptions() end
assert(reads==before and inspect.ui.needsRefresh, "hidden refreshes do no UI status work")
assert(ns.ShowOptions())
assert(reads>before and not inspect.ui.needsRefresh, "Show refreshes the current model")
assert(inspect.ui.environmentEditing:GetText():find("PvP",1,true), "latest editing environment displayed")
print("options-hidden-refresh-contract: ok")
