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

local MOD_NAME  = require("scripts.ErnDebt.ns")
local mwvars    = require("scripts.ErnDebt.mwvars")
local gearup    = require("scripts.ErnDebt.gearup")
local world     = require("openmw.world")
local types     = require("openmw.types")
local util      = require("openmw.util")

local persist   = {}

-- can't spawn too far, because the actor won't notice the player.
local spawnDist = 500

local function newDebtCollector(data, recordId)
    -- update mw vars from lua.
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncurrentdebt] = data.currentDebt
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncollectorskilled] = data.collectorsKilled
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncurrentpaymentskipstreak] = data.currentPaymentSkipStreak

    -- make the npc
    local new = world.createObject(recordId, 1)
    new:addScript("scripts\\ErnDebt\\debtcollector.lua", data)
    -- move it behind the player
    local backward = data.player.rotation:apply(util.vector3(0.0, -1.0, 0.0)):normalize()
    local location = data.player.position + backward * spawnDist + util.vector3(0.0, 0.0, spawnDist)
    print("Spawning new debt collector " .. recordId .. " at " .. tostring(location) .. ".")
    new:teleport(data.player.cell,
        location,
        {
            onGround = true,
        })

    local pcLevel = types.Actor.stats.level(data.player).current
    gearup.gearupNPC(new, pcLevel + data.collectorsKilled)
end

local function onCollectorSpawn(data)
    local player = data.player
    local currentDebt = data.currentDebt
    local currentPaymentSkipStreak = data.currentPaymentSkipStreak

    newDebtCollector(data, "fargoth")
end

local function onCollectorDespawn(data)
    -- remove the collector
    data.npc.enabled = false
    data.npc:remove()
    -- pass through if we paid some debt. mwscript must set this value.
    data.justPaidAmount = world.mwscript.getGlobalVariables(data.player)[mwvars.ernjustpaidamount]
    data.data.player.sendEvent(MOD_NAME .. "onCollectorDespawn", data)
end

return {
    eventHandlers = {
        [MOD_NAME .. "onCollectorSpawn"] = onCollectorSpawn,
        [MOD_NAME .. "onCollectorDespawn"] = onCollectorDespawn,
    },
}
