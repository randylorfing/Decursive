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
-- Execute the real Options.lua against an anchor-solving frame model. This
-- verifies geometry and UI callbacks; it cannot prove native font rendering,
-- texture appearance, taint safety, or in-game secure behavior.
local model = assert(loadfile("tests/fixtures/frame-mock.lua") or loadfile("docs/tests/fixtures/frame-mock.lua"))()
model.Install(1920, 1080)
local fixture = assert(loadfile("tests/fixtures/options-fixture.lua") or loadfile("docs/tests/fixtures/options-fixture.lua"))()
local ns, addon = fixture.ns, fixture.addon
assert(loadfile("ZDecursive/ClickBindings.lua"))("ZDecursive",ns)
ns.GetBandageInventoryStatus = function()
  return {status="READY", activeItemID=239713, count=45, items={
    {itemID=239713,name="Bright Linen Bandage",quality=2,itemLevel=100,count=45,status="READY"},
    {itemID=239711,name="Bright Linen Bandage",quality=1,itemLevel=100,count=3,status="READY"},
    {itemID=224440,name="Weavercloth Bandage",quality=1,itemLevel=80,count=12,status="READY"},
    {itemID=194048,name="Wildercloth Bandage",quality=1,itemLevel=60,count=6,status="READY"},
  }}
end
ns.GetRuntimeLogStatus = function()return {count=4,maxEntries=250,persistent=true}end
local optionsFile = assert(io.open("ZDecursive/Options.lua", "r"))
local optionsSource = optionsFile:read("*a"); optionsFile:close()
-- Private inspection access exists only in this in-memory test chunk.
local inspect = "\nns.__geometry = {ui=ui, catalog=CATALOG, setTab=SetTab, setDestination=SetDestination, refresh=Refresh, layout=LayoutCatalog, scroll=LayoutScrollChildren}\n"
assert((loadstring or load)(optionsSource..inspect, "@ZDecursive/Options.lua"))("ZDecursive",ns)
assert(ns.ShowOptions(), "Options must open outside combat")
local access = assert(ns.__geometry)
local ui, issues, snapshots, checks = access.ui, {}, {}, 0
local function check(condition, message)
  checks = checks+1
  if not condition then issues[#issues+1] = message end
end
local function near(a,b) return math.abs(a-b)<1 end
local function finite(n) return type(n)=="number" and n==n and n>-100000 and n<100000 end
local function validRect(region, context)
  local r=model.Rect(region)
  check(finite(r.x) and finite(r.y) and finite(r.width) and finite(r.height), context..": finite bounds")
  check(r.width>=0 and r.height>=0,context..": nonnegative extent")
  return r
end
local function within(inner, outer, context, horizontalOnly)
  local a,b=validRect(inner,context),validRect(outer,context.." container")
  check(a.x>=b.x-1 and a.x+a.width<=b.x+b.width+1,context..": horizontal overflow")
  if not horizontalOnly then check(a.y>=b.y-1 and a.y+a.height<=b.y+b.height+1,context..": vertical overflow")end
end
local function separated(a,b,context)
  local x,y=model.Rect(a),model.Rect(b)
  local overlapX=math.min(x.x+x.width,y.x+y.width)-math.max(x.x,y.x)
  local overlapY=math.min(x.y+x.height,y.y+y.height)-math.max(x.y,y.y)
  check(overlapX<=1 or overlapY<=1,context..": overlap")
end
local function checkText(textRegion,context)
  if not textRegion or not textRegion:IsVisible() or textRegion:GetText()=="" then return end
  local r=validRect(textRegion,context)
  if textRegion.wordWrap==false then
    check(textRegion:GetStringWidth()<=r.width+1,context..": unwrapped text exceeds width")
  else
    check(model.TextHeight(textRegion,r.width)<=r.height+1,context..": wrapped text exceeds height")
  end
end
local function checkChrome(label)
  for _,key in ipairs({"navigation","body","envBar","profileBar","statusPage","diagnosticsPage"})do
    local region=ui[key]
    if region and region:IsVisible() then within(region,ui.frame,label.." "..key)end
  end
  local buttons={}
  for key,button in pairs(ui.navButtons or {})do
    if button:IsVisible()then
      within(button,ui.navigation,label.." navigation "..key)
      checkText(button.label,label.." navigation label "..key)
      buttons[#buttons+1]={key=key,region=button}
    end
  end
  for i=1,#buttons do for j=i+1,#buttons do separated(buttons[i].region,buttons[j].region,label.." nav "..buttons[i].key.."/"..buttons[j].key)end end
  local statusKeys={"environmentApplied","environmentEditing","environmentDetected","environmentPending"}
  for i,key in ipairs(statusKeys)do
    local region=ui[key]
    if region and region:IsVisible() and region:GetText()~="" then
      within(region,ui.frame,label.." "..key)
      for j=i+1,#statusKeys do local other=ui[statusKeys[j]];if other and other:IsVisible()and other:GetText()~=""then separated(region,other,label.." header "..key.."/"..statusKeys[j])end end
    end
  end
end
local function checkCatalog(page,label)
  local child=assert(ui.pageChildren[page],"Missing page child: "..page)
  local viewport=assert(child.scrollParent,"Missing scroll viewport: "..page)
  check(near(child:GetWidth(),viewport:GetWidth()),label..": scroll child must fit viewport width")
  local items={}
  for _,section in ipairs(ui.sections[page] or {})do
    if section.header:IsVisible()then items[#items+1]={region=section.header,label=section.group.." heading"}end
    for _,item in ipairs(section.rows)do
      local row=item.row
      if row:IsVisible()then
        local prefix=label.." / "..item.spec.label
        items[#items+1]={region=row,label=item.spec.label}
        within(row,child,prefix)
        if row.label then within(row.label,row,prefix.." label");checkText(row.label,prefix.." label")end
        local widget
        for _,bind in ipairs(ui.binds)do if bind.widget and bind.widget.parent==row then widget=bind.widget;break end end
        if widget then
          within(widget,row,prefix.." control")
          if row.label then separated(row.label,widget,prefix.." label/control")end
          if widget.kind=="FontString"then checkText(widget,prefix.." readout")end
          if widget.label then within(widget.label,widget,prefix.." control label");checkText(widget.label,prefix.." control label")end
        end
        for _,region in ipairs(row.children)do
          if region.kind=="FontString" and region~=row.label and region~=widget and region:IsVisible()then
            within(region,row,prefix.." help");checkText(region,prefix.." help")
            if row.label then separated(region,row.label,prefix.." help/label")end
            if widget then separated(region,widget,prefix.." help/control")end
          end
        end
      end
    end
  end
  if page=="mufs" and ui.previewHost and ui.previewHost:IsVisible()then items[#items+1]={region=ui.previewHost,label="preview"}end
  if page=="sorting" and ui.listsHost and ui.listsHost:IsVisible()then items[#items+1]={region=ui.listsHost,label="lists"}end
  table.sort(items,function(a,b)return model.Rect(a.region).y<model.Rect(b.region).y end)
  for i,item in ipairs(items)do
    within(item.region,child,label.." / "..item.label)
    if i>1 then separated(items[i-1].region,item.region,label.." / adjacent "..items[i-1].label.."/"..item.label)end
  end
end
local function checkNonCatalogContents(label)
  -- Scroll children deliberately exceed their viewport. Their own children
  -- must still fit the declared content extent so the last control is reachable.
  for _,region in ipairs(model.regions)do
    local parent=region.parent
    if parent and model.Descendant(region,ui.frame) and region:IsVisible()
      and parent.kind~="ScrollFrame" and region~=ui.frame
      and region.kind~="Texture" and region.kind~="FontString" then
      if parent:GetWidth()>0 and parent:GetHeight()>0 and region:GetWidth()>0 and region:GetHeight()>0 then
        within(region,parent,label.." frame "..tostring(region.name or region.id))
      end
    end
  end
end
local function resize(w,h)
  ui.frame:SetSize(w,h)
  model.Fire(ui.frame,"OnSizeChanged",w,h)
  access.scroll();access.refresh()
end
local function capture(label)
  local snapshot=model.Capture(ui.frame,label)
  snapshot.checkCount=checks
  snapshots[#snapshots+1]=snapshot
end
local function destination(key)
  local button=assert(ui.navButtons[key],"Missing destination navigation: "..key)
  model.Fire(button,"OnClick")
  check(ui.destination==key,"Navigation callback selects "..key)
end
local function page(key)
  assert(ui.pages[key],"Missing settings page: "..key)
  local button=assert(ui.navButtons["page:"..key],"Missing category navigation: "..key)
  model.Fire(button,"OnClick")
  check(ui.destination=="environment" and ui.tab==key,"Navigation callback selects "..key)
end
local function checkScrolling(key,label)
  local child=ui.pageChildren[key]
  local viewport=child.scrollParent
  model.Fire(viewport,"OnMouseWheel",-10000)
  local expected=math.max(0,child:GetHeight()-viewport:GetHeight())
  check(near(viewport:GetVerticalScroll(),expected),label..": wheel reaches content bottom")
  if expected>0 then
    check(near(model.Rect(child).y+child:GetHeight(),model.Rect(viewport).y+viewport:GetHeight()),label..": content bottom aligns with viewport at maximum scroll")
  end
  if key=="items"then capture(label.." scrolled to bottom")end
  model.Fire(viewport,"OnMouseWheel",10000)
  check(viewport:GetVerticalScroll()==0,label..": wheel returns to top")
end
local pages={"mufs","sorting","cure","color","alerts","items","advanced"}
for _,size in ipairs({{1180,820},{1100,680}})do
  resize(size[1],size[2])
  local label=size[1].."x"..size[2]
  destination("status");checkChrome(label.." status");checkNonCatalogContents(label.." status");capture(label.." Status")
  for _,key in ipairs(pages)do
    page(key)
    checkChrome(label.." "..key);checkCatalog(key,label.." "..key);capture(label.." "..key)
    checkScrolling(key,label.." "..key)
  end
  for _,key in ipairs({"addon_profiles","diagnostics"})do
    destination(key);checkChrome(label.." "..key);checkNonCatalogContents(label.." "..key);capture(label.." "..key)
  end
end
-- A full raid stresses preview wrapping; a manual Actions pack stresses row
-- visibility; distinct environments exercise status text rather than fixture
-- constants. The scanner data includes same-name crafted quality variants.
addon.db.char.editingEnvironment="RAID"
addon:GetEditingPack().cure.mode="MANUAL"
assert(ns.SetClickBindingOverride(addon:GetEditingPack(),"button5","BANDAGE"))
assert(ns.SetClickBindingOverride(addon:GetEditingPack(),"ctrl-shift-left","BANDAGE"))
fixture.environmentStatus.detectedEnvironment="MYTHIC_PLUS"
fixture.environmentStatus.pendingEnvironment="PVP"
resize(1100,680)
for _,key in ipairs({"mufs","cure","items"})do
  page(key);checkChrome("stress "..key);checkCatalog(key,"stress "..key);capture("1100x680 Raid manual "..key)
end
check(ui.simple==false,"Settings must not hide behind a global Simple mode")
page("cure")
local section=assert(ui.sections.cure[1])
local beforeHeight=ui.pageChildren.cure:GetHeight()
model.Fire(section.header,"OnClick")
check(ui.pageChildren.cure:GetHeight()<beforeHeight,"Collapsing a section reduces actual scroll extent")
for _,item in ipairs(section.rows)do check(not item.row:IsShown(),"Collapsed section hides "..item.spec.label)end
checkCatalog("cure","collapsed Actions");capture("1100x680 Actions collapsed section")
model.Fire(section.header,"OnClick")
check(near(ui.pageChildren.cure:GetHeight(),beforeHeight),"Expanding restores actual scroll extent")
-- Search must accommodate the complete catalog, not a fixed first-page list.
local function search(query)
  ui.searchBox:SetText(query)
  model.Fire(ui.searchBox,"OnTextChanged",true)
  check(ui.pages.search:IsVisible(),"Search result page is visible for "..query)
end
search("a")
local visibleResults={}
for _,resultRow in ipairs(ui.searchRows)do
  if resultRow:IsVisible()then
    visibleResults[#visibleResults+1]=resultRow
    within(resultRow,ui.searchChild,"broad search result "..resultRow.label:GetText())
    within(resultRow.label,resultRow,"search label");checkText(resultRow.label,"search label")
    within(resultRow.path,resultRow,"search category path");checkText(resultRow.path,"search category path")
  end
end
check(#visibleResults>20,"Broad search includes more than one viewport of matches")
check(ui.searchChild:GetHeight()>ui.searchChild.scrollFrame:GetHeight(),"Broad search has scrollable content")
for i=2,#visibleResults do separated(visibleResults[i-1],visibleResults[i],"Search result rows "..(i-1).."/"..i)end
capture("1100x680 Broad search")
model.Fire(ui.searchChild.scrollFrame,"OnMouseWheel",-10000)
within(visibleResults[#visibleResults],ui.searchChild.scrollFrame,"Final broad search result is reachable")
check(near(ui.searchChild.scrollbar:GetValue(),ui.searchChild.scrollFrame:GetVerticalScroll()),"Search scrollbar follows wheel position")
capture("1100x680 Broad search scrolled to bottom")
page("cure")
local targetSection=ui.sections.cure[#ui.sections.cure]
local targetItem=targetSection.rows[#targetSection.rows]
check((targetItem.offset or 0)>ui.pageChildren.cure.scrollFrame:GetHeight(),"Reveal fixture targets a setting below the first viewport")
model.Fire(targetSection.header,"OnClick")
check(not targetItem.row:IsShown(),"Search reveal fixture starts with collapsed target")
search(targetItem.spec.label)
local matchingResult
for _,resultRow in ipairs(ui.searchRows)do if resultRow:IsVisible()and resultRow.searchSpec==targetItem.spec then matchingResult=resultRow;break end end
assert(matchingResult,"Search must include a collapsed lower-section setting")
model.Fire(matchingResult,"OnMouseUp","LeftButton")
check(ui.search=="" and ui.destination=="environment" and ui.tab=="cure","Search result navigates to its Actions page")
check(ui.collapsed.cure[targetSection.group]==false and targetItem.row:IsVisible(),"Search result expands its collapsed section")
within(targetItem.row,ui.pageChildren.cure.scrollFrame,"Search reveal target must be on screen")
capture("1100x680 Search reveals collapsed lower setting")
for _,snapshot in ipairs(snapshots)do print("LAYOUT_SNAPSHOT\t"..model.JSON(snapshot))end
print("LAYOUT_RESULT\t"..model.JSON({checks=checks,issues=issues,scenarioCount=#snapshots,unknownMethods=model.unknownMethods}))
if #issues>0 then
  for i=1,math.min(#issues,40)do io.stderr:write(issues[i].."\n")end
  error("options-geometry-contract: "..#issues.." geometry failures across "..#snapshots.." scenarios")
end
print("options-geometry-contract: "..checks.." checks passed across "..#snapshots.." scenarios")
