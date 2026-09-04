-- This file is part of ZDecursive, an independently maintained rebuild of Decursive.
--
-- Based on Decursive, Copyright (C) 2006-2026 John Wellesz
-- ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing
-- Licensed under the GNU General Public License version 3 or later.

local function Read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local source = Read("ZDecursive/MUFs.lua")
local gateStart = assert(source:find("local function IsPubliclyDeadUnit", 1, true))
local gateEnd = assert(source:find("local function ClickSignature", gateStart, true))
local gateSource = source:sub(gateStart, gateEnd - 1)
local values = {living = false, dead = true, secret = {secret = true}}
local env = setmetatable({
  ns = {GetSmartRezActions = function() return nil, nil, true, true end},
  IsTrue = function(value) return value == true end,
  SoulLinkFallbackApplies = function() return true end,
  UnitIsDeadOrGhost = function(unit) return values[unit] end,
  GetPack = function() return {} end,
}, {__index = _G})
assert(load(gateSource, "soul-link-gate", "t", env))()
local should = assert(env.ns.ShouldBeginSoulLinkAttemptForValidation)
assert(not should("living"), "living dispel never arms battle-rez attribution")
assert(should("dead"), "publicly dead unit can arm Soul Link attribution")
assert(not should("secret"), "non-public death state fails closed")
assert(not should(nil), "invalid unit fails closed")
print("soul-link-attribution-contract: ok")
