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

-- ZDecursive test support, Copyright (C) 2026 Randy Lorfing.
-- GPL-3.0-or-later; distributed without warranty. See the repository LICENSE.
-- Sanity checks for the geometry test model itself. These use small isolated
-- equations and never duplicate the addon's Options coordinates.
local m=assert(loadfile("tests/fixtures/frame-mock.lua") or loadfile("docs/tests/fixtures/frame-mock.lua"))()
m.Install(1920,1080)
local n=0
local function equal(value,want,label)n=n+1;assert(math.abs(value-want)<.001,label..": "..value.." ~= "..want)end
local root=CreateFrame("Frame","GeometryRoot",UIParent)
root:SetSize(1000,600);root:SetPoint("CENTER",UIParent,"CENTER",0,0)
equal(m.Rect(root).x,460,"root centered x");equal(m.Rect(root).y,240,"root centered y")
local child=CreateFrame("Frame",nil,root)
child:SetPoint("TOPLEFT",10,-20);child:SetPoint("BOTTOMRIGHT",-30,40)
equal(child:GetWidth(),960,"two-anchor width");equal(child:GetHeight(),540,"two-anchor height")
equal(m.Rect(child).x,470,"child left");equal(m.Rect(child).y,260,"WoW negative y moves down")
root:SetSize(1100,700)
equal(child:GetWidth(),1060,"parent resize changes anchored width");equal(child:GetHeight(),640,"parent resize changes anchored height")
local right=CreateFrame("Button",nil,child);right:SetSize(60,24);right:SetPoint("RIGHT",-8,0)
equal(m.Rect(right).x+m.Rect(right).width,m.Rect(child).x+child:GetWidth()-8,"right fixed extent")
local other=CreateFrame("Frame",nil,child);other:SetSize(100,30);other:SetPoint("LEFT",right,"RIGHT",10,0)
equal(m.Rect(other).x,m.Rect(right).x+right:GetWidth()+10,"sibling relative point")
local scroll=CreateFrame("ScrollFrame",nil,child);scroll:SetAllPoints()
local content=CreateFrame("Frame",nil,scroll);content:SetSize(child:GetWidth(),1000);scroll:SetScrollChild(content)
equal(scroll:GetVerticalScrollRange(),360,"scroll overflow")
scroll:SetVerticalScroll(130);equal(m.Rect(content).y,m.Rect(scroll).y-130,"scroll moves content upward")
child:Hide();assert(not content:IsVisible(),"ancestor visibility");child:Show();assert(content:IsVisible(),"ancestor visibility restored")
local label=child:CreateFontString(nil,"OVERLAY","GameFontHighlight")
label:SetPoint("TOPLEFT",0,0);label:SetText("This text wraps over a narrow column");label:SetWidth(80)
assert(label:GetStringHeight()>12*1.2,"estimated wrapping adds lines")
label:SetWidth(400);equal(label:GetStringHeight(),12*1.2,"wide text remains one line")
local snapshot=m.Capture(root,"model sanity")
assert(#snapshot.nodes>4 and m.JSON(snapshot):find('"simulation":true',1,true),"snapshot is explicit simulation")
print("frame-geometry-model-contract: "..n.." anchor checks and visibility/text/snapshot checks passed")
