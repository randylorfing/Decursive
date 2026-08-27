--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 combat scheduler.
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

local _, T = ...
if not T then return end

local V13 = T.ZhaohuV13 or {}
T.ZhaohuV13 = V13

local Scheduler = {
    pending = {},
    order = {},
    flushing = false,
}
V13.CombatScheduler = Scheduler

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function pack(...)
    return { count = select("#", ...), ... }
end

local function call(task)
    return xpcall(function()
        return task.callback(unpack(task.arguments, 1, task.arguments.count))
    end, geterrorhandler())
end

function Scheduler:IsDeferred(key)
    return self.pending[key] ~= nil
end

function Scheduler:GetPendingCount()
    local count = 0
    for _ in pairs(self.pending) do count = count + 1 end
    return count
end

function Scheduler:Cancel(key)
    if not self.pending[key] then return false end
    self.pending[key] = nil
    return true
end

-- Coalesce structural work by stable key. Repeated settings changes in combat
-- replace the payload instead of creating an unbounded timer/event backlog.
function Scheduler:RunOrDefer(key, callback, ...)
    assert(type(key) == "string" and key ~= "", "scheduler key is required")
    assert(type(callback) == "function", "scheduler callback is required")

    if not inCombat() and not self.flushing then
        return call({ callback = callback, arguments = pack(...) })
    end

    if not self.pending[key] then self.order[#self.order + 1] = key end
    self.pending[key] = { callback = callback, arguments = pack(...) }
    return false, "deferred"
end

function Scheduler:Flush()
    if self.flushing or inCombat() then return false end
    self.flushing = true

    local order = self.order
    self.order = {}
    for _, key in ipairs(order) do
        local task = self.pending[key]
        self.pending[key] = nil
        if task then call(task) end
        if inCombat() then break end
    end

    -- If combat restarted while flushing, retain untouched tasks and rebuild a
    -- deterministic order for the next PLAYER_REGEN_ENABLED.
    if inCombat() then
        for _, key in ipairs(order) do
            if self.pending[key] then self.order[#self.order + 1] = key end
        end
    end

    self.flushing = false
    return not inCombat()
end

function Scheduler:Initialize()
    if self.eventFrame or not CreateFrame then return end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function()
        Scheduler:Flush()
    end)
    self.eventFrame = frame
end

Scheduler:Initialize()
