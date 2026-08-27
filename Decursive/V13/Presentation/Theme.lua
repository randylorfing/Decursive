--[[
    This file is part of Decursive.

    Zhaohu's Decursive v13 visual design tokens.
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

V13.Theme = {
    color = {
        canvas = { 0.035, 0.051, 0.075, 0.98 },
        surface = { 0.067, 0.094, 0.141, 0.98 },
        raised = { 0.090, 0.133, 0.192, 1.00 },
        border = { 0.169, 0.231, 0.302, 1.00 },
        text = { 0.933, 0.965, 1.000, 1.00 },
        muted = { 0.576, 0.655, 0.733, 1.00 },
        cyan = { 0.208, 0.843, 0.949, 1.00 },
        cureRed = { 1.000, 0.251, 0.361, 1.00 },
        cureBlue = { 0.341, 0.580, 1.000, 1.00 },
        success = { 0.259, 0.910, 0.608, 1.00 },
        warning = { 1.000, 0.824, 0.290, 1.00 },
        danger = { 1.000, 0.420, 0.373, 1.00 },
    },
    spacing = {
        unit = 4,
        compact = 8,
        control = 12,
        card = 16,
        section = 24,
    },
    size = {
        windowWidth = 1040,
        windowHeight = 760,
        minimumWidth = 900,
        minimumHeight = 620,
        headerHeight = 72,
        commandBarHeight = 42,
        footerHeight = 32,
        testRailWidth = 248,
        controlHeight = 28,
    },
    navigation = {
        { key = "OVERVIEW", label = "Overview" },
        { key = "MUFS", label = "MUFs" },
        { key = "CURE", label = "Cure" },
        { key = "ALERTS", label = "Alerts" },
        { key = "PROFILES", label = "Profiles" },
        { key = "SETTINGS", label = "All Settings" },
        { key = "ADVANCED", label = "Advanced" },
    },
}
