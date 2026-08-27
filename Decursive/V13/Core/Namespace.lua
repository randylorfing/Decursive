--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 namespace.
    Copyright (C) 2026 Randy Lorfing

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive.  If not, see <https://www.gnu.org/licenses/>.
--]]

local addonName, T = ...
if not T then return end

local V13 = T.ZhaohuV13 or {}
T.ZhaohuV13 = V13

V13.addonName = addonName
local GetAddOnMetadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
V13.version = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "development"
V13.schemaVersion = 1
local normalizedVersion = tostring(V13.version):gsub("^v", "")
V13.phase = normalizedVersion:match("^%d+%.%d+%.%d+$") and "production" or "release-candidate"
V13.ready = false
V13.modules = V13.modules or {}

function V13:RegisterModule(name, module)
    assert(type(name) == "string" and name ~= "", "module name is required")
    assert(type(module) == "table", "module table is required")
    assert(not self.modules[name], "duplicate v13 module: " .. name)
    self.modules[name] = module
    return module
end

function V13:GetModule(name)
    return self.modules[name]
end
