-- ZDecursive test support, Copyright (C) 2026 Randy Lorfing.
-- GPL-3.0-or-later; distributed without warranty. See the repository LICENSE.
-- Offline nonsecure frame geometry model. This is not a WoW renderer or a
-- secure execution simulator. Anchor equations are solved from actual calls;
-- text metrics use deliberately conservative estimates, not installed fonts.
local M = {regions = {}, version = 0, unknownMethods = {}}
local methods = {}
local anchors = {TOPLEFT={0,0}, TOP={.5,0}, TOPRIGHT={1,0}, LEFT={0,.5}, CENTER={.5,.5}, RIGHT={1,.5}, BOTTOMLEFT={0,1}, BOTTOM={.5,1}, BOTTOMRIGHT={1,1}}
local function changed() M.version = M.version + 1 end
local function plain(text)
  return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "[icon]"):gsub("|A.-|a", "[icon]")
end
local function fontSize(template)
  template = tostring(template or "")
  if template:find("Huge") then return 20 end
  if template:find("Large") then return 16 end
  if template:find("Small") then return 11 end
  return 12
end
local function textWidth(text, size)
  local maxWidth = 0
  for line in (plain(text).."\n"):gmatch("(.-)\n") do
    local width = 0
    for char in line:gmatch(".") do
      width = width + (char:match("[ilI1%.,:;' ]") and .30 or char:match("[MW@]") and .82 or .56) * size
    end
    maxWidth = math.max(maxWidth, width)
  end
  return maxWidth
end
function M.TextHeight(region, width)
  local size, lines = region.fontSize or 12, 0
  for line in (plain(region.text).."\n"):gmatch("(.-)\n") do
    local count = 1
    if region.wordWrap ~= false and width and width > 0 then
      local used=0
      for word in line:gmatch("%S+")do
        local wordWidth=textWidth(word,size)
        local gap=used>0 and textWidth(" ",size) or 0
        if used>0 and used+gap+wordWidth>width+.001 then count=count+1;used=0;gap=0 end
        used=used+gap+wordWidth
        if used>width+.001 then local extra=math.ceil(used/width)-1;count=count+extra;used=used-extra*width end
      end
    end
    lines = lines + count
  end
  return lines * size * 1.2
end
local function solveAxis(region, axis, size, points, visiting)
  local constraints = {}
  for _, point in ipairs(points) do
    local relative = M.Rect(point.relative, visiting)
    local ownFraction, otherFraction = anchors[point.point][axis], anchors[point.relativePoint][axis]
    local base = axis == 1 and relative.x or relative.y
    local extent = axis == 1 and relative.width or relative.height
    constraints[#constraints+1] = {fraction=ownFraction, value=base+extent*otherFraction+(axis==1 and point.x or -point.y)}
  end
  for i = 1, #constraints do
    for j = i+1, #constraints do
      local a,b=constraints[i],constraints[j]
      if a.fraction ~= b.fraction then
        size = (b.value-a.value)/(b.fraction-a.fraction)
        return a.value-a.fraction*size, size
      end
    end
  end
  if constraints[1] then return constraints[1].value-constraints[1].fraction*size, size end
  local p = region.parent and M.Rect(region.parent, visiting)
  return p and (axis==1 and p.x or p.y) or 0, size
end
function M.Rect(region, visiting)
  if not region then return {x=0,y=0,width=0,height=0} end
  if region.rectVersion == M.version then return region.rect end
  if region._sliderThumb then
    local slider=region._sliderThumb;local p=M.Rect(slider,visiting)
    local ratio=(slider.value or 0)-(slider.minValue or 0)
    local range=(slider.maxValue or 1)-(slider.minValue or 0)
    ratio=range>0 and math.max(0,math.min(1,ratio/range)) or 0
    local w,h=region.width or 8,region.height or 20
    if slider.orientation=="VERTICAL" then return {x=p.x+(p.width-w)/2,y=p.y+ratio*(p.height-h),width=w,height=h} end
    return {x=p.x+ratio*(p.width-w),y=p.y+(p.height-h)/2,width=w,height=h}
  end
  visiting = visiting or {}
  assert(not visiting[region], "anchor cycle involving region "..tostring(region.name or region.id))
  visiting[region] = true
  local w=region.width or (region.kind=="FontString" and textWidth(region.text, region.fontSize or 12)) or 0
  local h=region.height or (region.kind=="FontString" and M.TextHeight(region,w)) or 0
  local x; x,w=solveAxis(region,1,w,region.points,visiting)
  if region.kind=="FontString" and not region.height then h=M.TextHeight(region,w) end
  local y; y,h=solveAxis(region,2,h,region.points,visiting)
  region.rect={x=x,y=y,width=w,height=h}
  region.rectVersion=M.version
  visiting[region]=nil
  return region.rect
end
function M.Region(kind,name,parent,template)
  local r={id=#M.regions+1,kind=kind,name=name,parent=parent,template=template,shown=true,points={},children={},scripts={},text="",fontSize=fontSize(template),scale=1,alpha=1}
  setmetatable(r,{__index=function(_,key)
    if methods[key] then return methods[key] end
    -- Unknown methods are recorded for audit. None may supply layout values.
    if type(key)=="string" and key:match("^[A-Z]") then return function() M.unknownMethods[key]=true end end
    return nil
  end})
  M.regions[#M.regions+1]=r
  if parent then parent.children[#parent.children+1]=r end
  if name then _G[name]=r end
  changed()
  return r
end
function methods:CreateTexture(name,layer,template,sublevel) local r=M.Region("Texture",name,self,template);r.layer=layer;r.sublevel=sublevel;return r end
function methods:CreateFontString(name,layer,template) local r=M.Region("FontString",name,self,template);r.layer=layer;return r end
function methods:SetPoint(point,a,b,c,d)
  local relative,relativePoint,x,y
  if type(a)=="number" or a==nil then relative=self.parent or UIParent;relativePoint=point;x=a or 0;y=b or 0
  elseif type(a)=="table" then relative=a;if type(b)=="string" then relativePoint=b;x=c or 0;y=d or 0 else relativePoint=point;x=b or 0;y=c or 0 end
  elseif type(a)=="string" then relative=_G[a];relativePoint=b or point;x=c or 0;y=d or 0 end
  assert(anchors[point] and anchors[relativePoint], "unsupported anchor "..tostring(point).."/"..tostring(relativePoint))
  local new={point=point,relative=relative,relativePoint=relativePoint,x=x,y=y}
  for i,old in ipairs(self.points) do if old.point==point then self.points[i]=new;changed();return end end
  self.points[#self.points+1]=new;changed()
end
function methods:GetPoint(i) local p=self.points[i or 1];if p then return p.point,p.relative,p.relativePoint,p.x,p.y end end
function methods:GetNumPoints() return #self.points end
function methods:ClearAllPoints() self.points={};changed() end
function methods:SetAllPoints(relative) self:ClearAllPoints();relative=relative or self.parent;self:SetPoint("TOPLEFT",relative,"TOPLEFT",0,0);self:SetPoint("BOTTOMRIGHT",relative,"BOTTOMRIGHT",0,0) end
function methods:SetSize(w,h) self.width=w;self.height=h;changed() end
function methods:SetWidth(w) self.width=w;changed() end
function methods:SetHeight(h) self.height=h;changed() end
function methods:GetWidth() return M.Rect(self).width end
function methods:GetHeight() return M.Rect(self).height end
function methods:GetSize() return self:GetWidth(),self:GetHeight() end
function methods:GetLeft() return M.Rect(self).x end
function methods:GetRight() local r=M.Rect(self);return r.x+r.width end
function methods:GetTop() return UIParent.height-M.Rect(self).y end
function methods:GetBottom() local r=M.Rect(self);return UIParent.height-r.y-r.height end
function methods:SetParent(p) self.parent=p;changed() end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetChildren() local t={};for _,v in ipairs(self.children) do if v.kind~="Texture" and v.kind~="FontString" then t[#t+1]=v end end;return (table.unpack or unpack)(t) end
function methods:GetRegions() local t={};for _,v in ipairs(self.children) do if v.kind=="Texture" or v.kind=="FontString" then t[#t+1]=v end end;return (table.unpack or unpack)(t) end
function methods:SetText(text) self.text=tostring(text or "");changed() end
function methods:GetText() return self.text end
function methods:SetFormattedText(pattern,...) self:SetText(string.format(pattern,...)) end
function methods:SetFontObject(template) self.fontSize=fontSize(template);changed() end
function methods:SetFont(file,size,flags) self.fontSize=size;self.fontFlags=flags;changed();return true end
function methods:GetFont() return "offline-font",self.fontSize,self.fontFlags end
function methods:SetWordWrap(on) self.wordWrap=on;changed() end
function methods:SetNonSpaceWrap(on) self.nonSpaceWrap=on end
function methods:GetStringWidth() return textWidth(self.text,self.fontSize) end
function methods:GetUnboundedStringWidth() return self:GetStringWidth() end
function methods:GetStringHeight() return M.TextHeight(self,self:GetWidth()) end
function methods:SetJustifyH(value) self.justifyH=value end
function methods:SetJustifyV(value) self.justifyV=value end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetBackdropColor(...) self._fill={...} end
function methods:SetBackdropBorderColor(...) self._border={...} end
function methods:SetColorTexture(...) self._fill={...} end
function methods:SetTexture(value) self.texture=value end
function methods:SetAtlas(value) self.atlas=value end
function methods:SetAlpha(value) self.alpha=value end
function methods:GetAlpha() return self.alpha end
function methods:SetScale(value) self.scale=value end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameLevel(value) self.frameLevel=value end
function methods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1) or 0 end
function methods:SetFrameStrata(value) self.strata=value end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetScript(event,callback) self.scripts[event]=callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event,callback) local old=self.scripts[event];self.scripts[event]=function(...) if old then old(...) end;return callback(...) end end
function M.Fire(region,event,...) local f=region.scripts[event];if f then return f(region,...) end end
function methods:Show() local old=self.shown;self.shown=true;if not old then M.Fire(self,"OnShow") end end
function methods:Hide() local old=self.shown;self.shown=false;if old then M.Fire(self,"OnHide") end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:SetScrollChild(child) self.scrollChild=child;child.scrollParent=self;if #child.points==0 then child:SetPoint("TOPLEFT",self,"TOPLEFT",0,0) end end
function methods:GetScrollChild() return self.scrollChild end
function methods:SetVerticalScroll(value) self.verticalScroll=value;if self.scrollChild then self.scrollChild:ClearAllPoints();self.scrollChild:SetPoint("TOPLEFT",self,"TOPLEFT",0,value) end end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight()) end
function methods:SetValue(value) local old=self.value;self.value=value;changed();if old~=value then M.Fire(self,"OnValueChanged",value) end end
function methods:GetValue() return self.value or 0 end
function methods:SetMinMaxValues(min,max) self.minValue=min;self.maxValue=max;changed() end
function methods:SetOrientation(value) self.orientation=value;changed() end
function methods:SetThumbTexture(texture)
  if type(texture)=="table" then self._thumb=texture;texture._sliderThumb=self;changed() end
end
function methods:GetMinMaxValues() return self.minValue,self.maxValue end
function methods:SetResizeBounds(minw,minh,maxw,maxh) self.resizeBounds={minw,minh,maxw,maxh} end
function methods:SetMinResize(w,h) self.resizeBounds={w,h} end
function methods:SetMaxResize(w,h) self.resizeBounds=self.resizeBounds or {};self.resizeBounds[3]=w;self.resizeBounds[4]=h end
function methods:EnableMouse(on) self.mouseEnabled=on end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetEnabled(on) self.enabled=on end
function methods:IsEnabled() return self.enabled~=false end
function methods:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function M.Descendant(region,parent) while region do if region==parent then return true end;region=region.parent end;return false end
function M.Install(width,height)
  UIParent=M.Region("Frame","UIParent");UIParent:SetSize(width,height)
  for _,name in ipairs({"GameFontHighlight","GameFontHighlightLarge","GameFontHighlightSmall","GameFontNormal","GameFontNormalLarge","GameFontDisable"}) do _G[name]=name end
  UISpecialFrames={};tinsert=table.insert;strtrim=function(v)return tostring(v or ""):match("^%s*(.-)%s*$")end
  CreateFrame=function(kind,name,parent,template)return M.Region(kind,name,parent,template)end
  InCombatLockdown=function()return false end;GetTime=function()return 100 end
  GetPhysicalScreenSize=function()return width,height end
  GameTooltip=M.Region("Frame","GameTooltip",UIParent);GameTooltip:Hide()
  UIErrorsFrame={AddMessage=function()end}
  C_Timer={After=function(_,fn)fn()end}
end
local function escape(s) return '"'..tostring(s):gsub('[%z\1-\31\\"]',function(c)local map={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'};return map[c] or string.format('\\u%04x',c:byte())end)..'"' end
function M.JSON(value)
  local typ=type(value)
  if typ=="nil" then return "null" elseif typ=="boolean" or typ=="number" then return tostring(value) elseif typ=="string" then return escape(value) end
  local out={};if #value>0 then for _,v in ipairs(value)do out[#out+1]=M.JSON(v)end;return '['..table.concat(out,',')..']' end
  for k,v in pairs(value)do out[#out+1]=escape(k)..':'..M.JSON(v)end;table.sort(out);return '{'..table.concat(out,',')..'}'
end
function M.Capture(root,label)
  local nodes={};local origin=M.Rect(root)
  for _,r in ipairs(M.regions)do
    if M.Descendant(r,root) and r:IsVisible() then
      local rect=M.Rect(r)
      if rect.width>0 and rect.height>0 then
        local clip;local p=r.parent
        while p and p~=root do if p.kind=="ScrollFrame" then local c=M.Rect(p);clip={x=c.x-origin.x,y=c.y-origin.y,width=c.width,height=c.height};break end;p=p.parent end
        nodes[#nodes+1]={id=r.id,parent=r.parent and r.parent.id,kind=r.kind,name=r.name,x=rect.x-origin.x,y=rect.y-origin.y,width=rect.width,height=rect.height,text=plain(r.text),fontSize=r.fontSize,color=r.textColor,fill=r._fill,border=r._border,alpha=r.alpha,align=r.justifyH,verticalAlign=r.justifyV,wordWrap=r.wordWrap,clip=clip}
      end
    end
  end
  return {label=label,width=origin.width,height=origin.height,nodes=nodes,simulation=true,textMetrics="Conservative estimated metrics; game fonts and secure behavior are not emulated."}
end
return M
