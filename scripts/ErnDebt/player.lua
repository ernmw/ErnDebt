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
local core            = require('openmw.core')
local pself           = require("openmw.self")
local settings        = require("scripts.ErnDebt.settings")
local async           = require("openmw.async")

local persist         = {
    justSpawned = false,
    currentDebt = 5000,
    currentPaymentSkipStreak = 0,
    collectorsKilled = 0,
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
    persist.currentPaymentSkipStreak = persist.currentPaymentSkipStreak + 1
    core.sendGlobalEvent(MOD_NAME .. "onCollectorSpawn", {
        player = pself,
        currentDebt = persist.currentDebt,
        currentPaymentSkipStreak = persist.currentPaymentSkipStreak,
        collectorsKilled = persist.collectorsKilled,
    })
end

local function maybeSpawn()
    if persist.currentDebt <= 0 then
        return
    end
    if persist.justSpawned then
        return
    end

    if persist.lastSpawnTime + (oneWeekDuration / 2) > core.getGameTime() then
        return
    end
    -- chance to not spawn the collector goes down the more you skip payments.
    local daysLate = math.ceil((core.getGameTime() - persist.lastSpawnTime - oneWeekDuration) / (24 * 60 * 60))
    local chance = math.max(5, 5 * daysLate + 3 * persist.currentPaymentSkipStreak)
    if settingCache.debug then
        print("Days late: " ..
            tostring(daysLate) ..
            ". Skip streak: " .. tostring(persist.currentPaymentSkipStreak) .. ". Spawn chance is " ..
            tostring(chance) .. "%.")
    end
    if math.random(0, 100) < chance then
        spawn()
    end
end

local function UiModeChanged(data)
    if pself.cell.isExterior and data.oldMode == 'Rest' and not data.newMode then
        maybeSpawn()
    end
end

local function onCollectorDespawn(data)
    persist.justSpawned = false
    if data.dead then
        if settingCache.debug then
            print("Collector killed.")
        end
        persist.collectorsKilled = persist.collectorsKilled + 1
    end
    if data.justPaidAmount <= 0 then
        if settingCache.debug then
            print("Payment skipped.")
        end
    else
        if settingCache.debug then
            print("Paid " .. tostring(data.justPaidAmount) .. ".")
        end
        persist.currentPaymentSkipStreak = 0
        persist.currentDebt = persist.currentDebt - data.justPaidAmount
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
        [MOD_NAME .. "onCollectorDespawn"] = onCollectorDespawn,
        UiModeChanged = UiModeChanged,
    },
    engineHandlers = {
        onLoad = onLoad,
        onSave = onSave,
    },
}
