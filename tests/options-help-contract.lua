-- This file is part of ZDecursive, an independently maintained rebuild of Decursive.
--
-- Based on Decursive, Copyright (C) 2006-2026 John Wellesz
-- ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
-- Licensed under the GNU General Public License version 3 or later.

-- Validate the real catalog and its description assignment without building UI.
local file = assert(io.open("ZDecursive/Options.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local CATALOG =", 1, true))
local last = assert(source:find("local ROW_META =", first, true))
local env = setmetatable({ns = {}}, {__index = function(_, key)
  return _G[key] or function() return function() end end
end})
local catalog = assert(load(source:sub(first, last - 1) .. "\nreturn CATALOG", "catalog", "t", env))()
local trace
for _, spec in ipairs(catalog) do
  assert(type(spec.description) == "string" and #spec.description > 30, "Missing useful help: " .. spec.page .. "/" .. spec.label)
  if spec.label == "Automatic aura diagnostics" then trace = spec end
end
assert(trace and trace.page == "advanced" and trace.kind == "toggle", "Automatic trace toggle is reachable")
assert(source:find('["advanced|Automatic aura diagnostics"] = {group = "Diagnostics", simple = true}', 1, true), "Trace switch is visible in Simple mode")
print("options-help-contract: " .. #catalog .. " settings have descriptions")
