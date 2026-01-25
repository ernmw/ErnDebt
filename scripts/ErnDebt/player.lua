--[[
ErnDebt for OpenMW.
Copyright (C) Erin Pentecost 2026

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

-- This file is in charge of tracking and exposing path information.
-- Interact with it via the interface it exposes.

local MOD_NAME        = require("scripts.ErnDebt.ns")
local types           = require('openmw.types')
local core            = require('openmw.core')
local pself           = require("openmw.self")
local interfaces      = require("openmw.interfaces")
local settings        = require("scripts.ErnDebt.settings")
local async           = require("openmw.async")
local nearby          = require('openmw.nearby')

local persist         = {
    currentDebt = 5000,
    currentPaymentSkipStreak = 0,
    lastSpawnTime = core.getGameTime(),
}

local oneWeekDuration = 604800

local settingCache    = {
    interest = settings.main.interest,
    debug = settings.main.debug,
}
settings.main.subscribe(async:callback(function(_, key)
    settingCache[key] = settings.main[key]
end))

local function spawn()
    -- add missing interest
    local weeksSinceSpawn = (core.getGameTime() - persist.lastSpawnTime) / (oneWeekDuration)
    local newDebt = math.ceil(persist.currentDebt * math.exp(settingCache.interest * weeksSinceSpawn))
    if settingCache.debug then
        print("Weeks since spawn: " ..
            tostring(weeksSinceSpawn) ..
            ". Previous debt: " .. tostring(persist.currentDebt) .. ". New Debt: " .. tostring(newDebt) .. ".")
    end
    persist.currentDebt = newDebt
    persist.lastSpawnTime = core.getGameTime()
    core.sendGlobalEvent(MOD_NAME .. "onCollectorSpawn", {
        player = pself,
        currentDebt = persist.currentDebt,
        currentPaymentSkipStreak = persist.currentPaymentSkipStreak,
    })
end

local function maybeSpawn()
    if persist.lastSpawnTime + oneWeekDuration > core.getGameTime() then
        return
    end
    -- chance to not spawn the collector goes down the more you skip payments.
    local daysLate = math.ceil((core.getGameTime() - persist.lastSpawnTime - oneWeekDuration) / (24 * 60 * 60))
    local dieSize = math.min(10, 1 + daysLate + persist.currentPaymentSkipStreak)
    if settingCache.debug then
        print("Days late: " ..
            tostring(daysLate) ..
            ". Skip streak: " .. tostring(persist.currentPaymentSkipStreak) ". Spawn chance is 1 in " ..
            tostring(dieSize) .. ".")
    end
    if math.random(0, dieSize) == 0 then
        spawn()
    end
end

local function UiModeChanged(data)
    if pself.cell.isExterior and data.oldMode == 'Rest' and not data.newMode then
        maybeSpawn()
    end
end

local function onLoad(data)
    if data then
        persist = data
    end
end
local function onSave()
    return persist
end

return {
    eventHandlers = {
        UiModeChanged = UiModeChanged,
        onLoad = onLoad,
        onSave = onSave,
    },
}
