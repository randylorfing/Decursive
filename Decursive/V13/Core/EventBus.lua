--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 event bus.
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
if not T or not T.ZhaohuV13 then return end

local V13 = T.ZhaohuV13
local EventBus = {
    listeners = {},
    nextToken = 0,
}
V13:RegisterModule("EventBus", EventBus)

function EventBus:Subscribe(eventName, callback, owner)
    assert(type(eventName) == "string" and eventName ~= "", "event name is required")
    assert(type(callback) == "function", "event callback is required")
    self.nextToken = self.nextToken + 1
    local token = self.nextToken
    local bucket = self.listeners[eventName] or {}
    self.listeners[eventName] = bucket
    bucket[token] = { callback = callback, owner = owner }
    return token
end

function EventBus:Unsubscribe(token)
    for _, bucket in pairs(self.listeners) do
        if bucket[token] then
            bucket[token] = nil
            return true
        end
    end
    return false
end

function EventBus:UnsubscribeOwner(owner)
    local removed = 0
    for _, bucket in pairs(self.listeners) do
        for token, listener in pairs(bucket) do
            if listener.owner == owner then
                bucket[token] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

function EventBus:Publish(eventName, ...)
    local bucket = self.listeners[eventName]
    if not bucket then return 0 end
    local arguments = { count = select("#", ...), ... }

    -- Snapshot tokens so a listener can safely subscribe/unsubscribe while an
    -- event is being delivered.
    local tokens = {}
    for token in pairs(bucket) do tokens[#tokens + 1] = token end
    table.sort(tokens)

    local delivered = 0
    for _, token in ipairs(tokens) do
        local listener = bucket[token]
        if listener then
            delivered = delivered + 1
            xpcall(function()
                listener.callback(eventName, unpack(arguments, 1, arguments.count))
            end, geterrorhandler())
        end
    end
    return delivered
end
