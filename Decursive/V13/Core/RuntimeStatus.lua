--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 safe runtime status model.
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
local ZD = T.ZhaohuModern
local Status = {}
V13:RegisterModule("RuntimeStatus", Status)

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function Status:GetSnapshot()
    local provider = ZD and ZD.GetDetectionProviderStatus and ZD:GetDetectionProviderStatus() or {}
    local scheduler = V13.CombatScheduler
    local _, _, _, interface = GetBuildInfo()
    return {
        version = V13.version or "development",
        phase = V13.phase or "release-candidate",
        backend = (ZD and ZD.compatBackend) or "v13-hardened-compat-runtime",
        runtimeMode = "Hardened compatibility",
        interface = interface or "unknown",
        profile = ZD and ZD.GetUserProfileName and ZD:GetUserProfileName() or "Default",
        provider = provider.displayName or "Native Blizzard-managed",
        providerOperational = provider.operational ~= false,
        protectedBoundary = "Blizzard-managed; no aura-detail reads",
        inCombat = inCombat(),
        deferred = scheduler and scheduler:GetPendingCount() or 0,
    }
end

function Status:GetReport()
    local state = self:GetSnapshot()
    return table.concat({
        "Zhaohu's Decursive v13 diagnostics",
        "Version: " .. tostring(state.version),
        "Phase: " .. tostring(state.phase),
        "Runtime backend: " .. tostring(state.backend),
        "Runtime mode: " .. tostring(state.runtimeMode),
        "WoW interface: " .. tostring(state.interface),
        "Profile: " .. tostring(state.profile),
        "Detection provider: " .. tostring(state.provider),
        "Provider operational: " .. (state.providerOperational and "Yes" or "No"),
        "Protected-aura boundary: " .. tostring(state.protectedBoundary),
        "Combat lockdown: " .. (state.inCombat and "Yes" or "No"),
        "Deferred structural tasks: " .. tostring(state.deferred),
        "Protected aura contents: intentionally not inspected or reported",
    }, "\n")
end
