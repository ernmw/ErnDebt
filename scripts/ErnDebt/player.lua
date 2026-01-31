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
local mwjournal       = require("scripts.ErnDebt.mwjournal")
local interfaces      = require("openmw.interfaces")
local ui              = require('openmw.ui')
local util            = require('openmw.util')
local types           = require('openmw.types')
local localization    = core.l10n(MOD_NAME)

-- can't spawn too far, because the actor won't notice the player.
local spawnDist       = 600

local persist         = {
    justWarned = false,
    justSpawned = false,
    currentDebt = 5000,
    currentPaymentSkipStreak = 0,
    collectorsKilled = 0,
    lastSpawnTime = core.getGameTime(),
    conversationsSinceLastSpawn = 0,
    -- enabled is true if we are allowed to spawn collectors via the quest state
    enabled = true,
}

local oneWeekDuration = 604800

local settingCache    = {
    interest = settings.main.interest,
    debug = settings.main.debug,
}
settings.main.subscribe(async:callback(function(_, key)
    settingCache[key] = settings.main[key]
end))

local function log(var)
    if settingCache.debug then
        print(var)
    end
end

local function currentGold()
    return pself.type.inventory(pself):countOf("gold_001")
end

local function spawn(cell, position)
    -- add missing interest
    local weeksSinceSpawn = (core.getGameTime() - persist.lastSpawnTime) / (oneWeekDuration)
    local newDebt = math.ceil(persist.currentDebt * math.exp(settingCache.interest * weeksSinceSpawn))
    log("Weeks since spawn: " ..
        tostring(weeksSinceSpawn) ..
        ". Previous debt: " .. tostring(persist.currentDebt) .. ". New Debt: " .. tostring(newDebt) .. ".")
    persist.currentDebt = newDebt
    persist.lastSpawnTime = core.getGameTime()
    persist.currentPaymentSkipStreak = persist.currentPaymentSkipStreak + 1
    persist.justWarned = false
    persist.conversationsSinceLastSpawn = 0
    local minPayment = math.min(persist.currentDebt, 500 * persist.currentPaymentSkipStreak)

    ui.showMessage(localization("collectorSpawnedMessage", { currentDebt = persist.currentDebt, minPayment = minPayment }))

    core.sendGlobalEvent(MOD_NAME .. "onCollectorSpawn", {
        player = pself,
        cellId = cell.id,
        position = { x = position.x, y = position.y, z = position.z },
        currentDebt = persist.currentDebt,
        currentPaymentSkipStreak = persist.currentPaymentSkipStreak,
        collectorsKilled = persist.collectorsKilled,
        playerGold = currentGold(),
        minPayment = minPayment,
    })
end

local function shouldSpawn()
    log("shouldSpawn()")
    if not persist.enabled then
        return false
    end
    if persist.currentDebt <= 0 then
        return false
    end
    if persist.justSpawned then
        return false
    end

    if (not settingCache.debug) and persist.lastSpawnTime + oneWeekDuration > core.getGameTime() then
        return false
    end
    -- chance to not spawn the collector goes down the more you skip payments.
    local daysLate = math.ceil((core.getGameTime() - persist.lastSpawnTime - oneWeekDuration) / (24 * 60 * 60))
    local chance = math.max(5,
        3 * daysLate + 5 * persist.currentPaymentSkipStreak + (persist.conversationsSinceLastSpawn or 0))
    if settingCache.debug then
        chance = 50
    end
    log("Days late: " ..
        tostring(daysLate) ..
        ". Skip streak: " .. tostring(persist.currentPaymentSkipStreak) .. ". Spawn chance is " ..
        tostring(chance) .. "%.")
    if math.random(0, 100) < chance then
        return true
    elseif chance > 40 and not persist.justWarned then
        persist.justWarned = true
        ui.showMessage(localization("beingWatchedMessage", {}))
    end
    return false
end


local function UiModeChanged(data)
    --- Talking with people makes you easier to track.
    if data.newMode == "Dialogue" then
        persist.conversationsSinceLastSpawn = persist.conversationsSinceLastSpawn + 1
    end
end

local function onCollectorDespawn(data)
    persist.justSpawned = false
    if data.dead then
        log("Collector killed.")
        persist.collectorsKilled = persist.collectorsKilled + 1
    end
    if data.justPaidAmount <= 0 then
        log("Payment skipped.")
    else
        log("Paid " .. tostring(data.justPaidAmount) .. ".")
        persist.currentPaymentSkipStreak = 0
        persist.currentDebt = persist.currentDebt - data.justPaidAmount
    end
end

local function ensureQuestStarted()
    local quest = types.Player.quests(pself)[mwjournal.questId]
    if quest.stage <= 0 then
        log("starting quest")
        quest:addJournalEntry(1, pself)
    end
end

local function onQuestUpdate(questId, stage)
    if questId == mwjournal.questId then
        persist.enabled = mwjournal.enabled(stage)
        log("quest stage change: " ..
            tostring(mwjournal.questStages[stage]) .. ", enabled: " .. tostring(persist.enabled))
    end
end

local function onExitingInterior(data)
    log("exiting interior. current cell: " .. tostring(pself.cell.id))
    ensureQuestStarted()
    if not shouldSpawn() then
        return
    end
    local destCell = types.Door.destCell(data.door)
    local destPosition = types.Door.destPosition(data.door)
    local destRotation = types.Door.destRotation(data.door)
    local forward = destRotation:apply(util.vector3(0.0, 1.0, 0.0)):normalize() * spawnDist
    spawn(destCell, destPosition + forward)
end

local function onStartDialogue(data)
    interfaces.UI.addMode("Dialogue", data)
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
        [MOD_NAME .. "onExitingInterior"] = onExitingInterior,
        [MOD_NAME .. "onStartDialogue"] = onStartDialogue,
        UiModeChanged = UiModeChanged,
    },
    engineHandlers = {
        onLoad = onLoad,
        onSave = onSave,
        onQuestUpdate = onQuestUpdate,
    },
}
