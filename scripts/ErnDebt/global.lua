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
local mwvars          = require("scripts.ErnDebt.mwvars")
local gearup          = require("scripts.ErnDebt.gearup")
local world           = require("openmw.world")
local types           = require("openmw.types")
local util            = require("openmw.util")

local collectorScript = "scripts\\ErnDebt\\debtcollector.lua"

local function newDebtCollector(data, recordId)
    -- update mw vars from lua.
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncurrentdebt] = data.currentDebt
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncollectorskilled] = data.collectorsKilled
    world.mwscript.getGlobalVariables(data.player)[mwvars.erncurrentpaymentskipstreak] = data.currentPaymentSkipStreak

    -- make the npc
    local new = world.createObject(recordId, 1)
    new:addScript(collectorScript, data)
    -- move it behind the player

    print("Spawning new debt collector " .. recordId .. " at " .. data.cellId .. ": " .. tostring(data.position) .. ".")
    new:teleport(world.getCellById(data.cellId),
        util.vector3(data.position.x, data.position.y, data.position.z),
        {
            onGround = true,
        })

    local pcLevel = types.Actor.stats.level(data.player).current
    gearup.gearupNPCs({ new }, pcLevel + data.collectorsKilled)
end

local function onCollectorSpawn(data)
    local player = data.player
    local currentDebt = data.currentDebt
    local currentPaymentSkipStreak = data.currentPaymentSkipStreak

    newDebtCollector(data, "tolvise othralen")
end

local function onCollectorDespawn(data)
    data.npc:removeScript(collectorScript)
    if not data.dead then
        -- remove the collector if not dead
        data.npc.enabled = false
        data.npc:remove()
    end
    -- pass through if we paid some debt. mwscript must set this value.
    data.justPaidAmount = world.mwscript.getGlobalVariables(data.player)[mwvars.ernjustpaidamount]
    data.player:sendEvent(MOD_NAME .. "onCollectorDespawn", data)
end

local function onActivate(object, actor)
    if not types.Player.objectIsInstance(actor) then
        return
    end
    if not types.Door.objectIsInstance(object) then
        return
    end
    if not types.Door.isTeleport(object) then
        return
    end
    if types.Lockable.isLocked(object) then
        return
    end
    local destCell = types.Door.destCell(object)
    if (destCell ~= nil) and
        (destCell.isExterior or destCell:hasTag("QuasiExterior")) then
        -- The player is leaving an internal cell and entering an exterior cell.
        actor:sendEvent(MOD_NAME .. "onExitingInterior", { door = object })
    end
end

return {
    eventHandlers = {
        [MOD_NAME .. "onCollectorSpawn"] = onCollectorSpawn,
        [MOD_NAME .. "onCollectorDespawn"] = onCollectorDespawn,
    },
    engineHandlers = {
        onActivate = onActivate
    }
}
