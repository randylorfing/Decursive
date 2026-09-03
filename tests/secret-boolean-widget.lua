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

local function Check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local secretBoolean = {secret = true}

issecretvalue = function(value)
  return value == secretBoolean
end

canaccessvalue = function(value)
  return not issecretvalue(value)
end

local ns = {}
assert(loadfile("ZDecursive/MUFs.lua"))("ZDecursive", ns)

local normalize = ns.NormalizeMUFBooleanWidgetValue
Check(type(normalize) == "function", "boolean widget normalizer is exported")
Check(normalize(nil) == false, "nil normalizes to public false")
Check(normalize(false) == false, "public false remains false")
Check(normalize(true) == true, "public true remains true")
Check(normalize(secretBoolean) == secretBoolean, "secret-compatible value passes through unchanged")

local nativeConsumer = {}
function nativeConsumer:SetAlphaFromBoolean(value)
  Check(value ~= nil, "native boolean consumer never receives nil")
  self.value = value
end

nativeConsumer:SetAlphaFromBoolean(normalize(nil))
Check(nativeConsumer.value == false, "nil path reaches native consumer as false")
nativeConsumer:SetAlphaFromBoolean(normalize(true))
Check(nativeConsumer.value == true, "true path reaches native consumer unchanged")
nativeConsumer:SetAlphaFromBoolean(normalize(secretBoolean))
Check(nativeConsumer.value == secretBoolean, "secret-compatible path reaches native consumer unchanged")

io.write("secret-boolean-widget: ok\n")
