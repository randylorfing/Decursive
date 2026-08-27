--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 notification presentation bridge.
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
local D = T.Dcr
local Bridge = {
    backend = "v13-hardened-compat-runtime",
}
V13:RegisterModule("NotificationBridge", Bridge)

-- The settings application talks only to this semantic preview surface. Each
-- method invokes the same production renderer, sound selection or MUF visual
-- entry point used by the runtime instead of maintaining test-only behavior.
function Bridge:PreviewDispelText()
    if not D or not D.Test121DispelAlertWarning then return false end
    return D:Test121DispelAlertWarning() and true or false
end

function Bridge:PreviewSound()
    if not D or not D.PlayDispelNotificationSound then return false end
    D:PlayDispelNotificationSound("v13 settings test", true)
    return true
end

function Bridge:PreviewCooldown()
    if not D or not D.Test121MUFVisuals then return false end
    D:Test121MUFVisuals("all")
    return true
end

function Bridge:GetCapabilities()
    return {
        text = D and type(D.Test121DispelAlertWarning) == "function" or false,
        sound = D and type(D.PlayDispelNotificationSound) == "function" or false,
        cooldown = D and type(D.Test121MUFVisuals) == "function" or false,
    }
end
