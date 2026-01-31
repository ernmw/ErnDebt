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

local MOD_NAME       = require("scripts.ErnDebt.ns")
local interfaces     = require("openmw.interfaces")
local pself          = require("openmw.self")
local util           = require('openmw.util')
local core           = require('openmw.core')
local aux_util       = require('openmw_aux.util')

local collectionData = {}

local function onInit(initData)
    print("Debt collector " .. pself.recordId .. " initialized.")
    if initData ~= nil then
        collectionData = initData
    end
end
local function onLoad(data)
    if data then
        collectionData = data
    end
end
local function onSave()
    return collectionData
end

local function printAIPackages()
    local pkgs = {}
    interfaces.AI.forEachPackage(function(pkg)
        table.insert(pkgs, pkg.type)
    end)
    print(aux_util.deepToString(pkgs, 3))
end

local function onActive()
    print("Debt collector " .. pself.recordId .. " is active.")
    -- Adjust dispo and fight
    pself.type.stats.ai.fight(pself).base = 70
    local startDisposition = pself.type.getBaseDisposition(pself, collectionData.player)
    pself.type.modifyBaseDisposition(pself, collectionData.player, 30 - startDisposition)
    -- Remove AI so we have full control
    interfaces.AI.removePackages()
end

local function onInactive()
    core.sendGlobalEvent(MOD_NAME .. "onCollectorDespawn", {
        player = collectionData.player,
        npc = pself,
        dead = pself.type.isDead(pself)
    })
end

local function onEquip(data)
    pself.type.setEquipment(pself, data)
end

local dialogueStarted = false
local delay = 0
local lastAIPackage = nil
local function onUpdate(dt)
    if dialogueStarted then
        return
    end
    if dt <= 0 then
        return
    end
    delay = delay + dt
    local active = interfaces.AI.getActivePackage()
    local activeType = active and active.type or nil
    local packageChanged = activeType ~= lastAIPackage

    -- debug print
    if packageChanged then
        lastAIPackage = activeType
        if lastAIPackage then
            print(pself.recordId .. " onUpdate - " .. tostring(active.type) .. ", " .. tostring(active.target))
            printAIPackages()
        else
            print(pself.recordId .. " onUpdate - no ai")
            printAIPackages()
        end
    end

    -- make the bodyguards also attack
    if packageChanged and activeType == "Combat" then
        for _, guard in ipairs(collectionData.guards) do
            print(guard.recordId .. " notifying bodyguard to attack")
            guard:sendEvent("StartAIPackage", { type = "Combat", target = active.target, cancelOther = true })
        end
    end

    local dontInterrupt = { Combat = true, Wander = true, Pursue = true }
    if dontInterrupt[activeType] then
        return
    end

    local distanceToPlayer = (collectionData.player.position - pself.position):length2()
    if distanceToPlayer > 100 * 100 then
        if delay > 1 then
            interfaces.AI.startPackage({
                type = "Travel",
                destPosition = collectionData.player.position,
                cancelOther = true,
                isRepeat = false
            })
            delay = 0
        end
    else
        -- we are close. start dialogue.
        interfaces.AI.removePackages("Travel")
        collectionData.player:sendEvent(MOD_NAME .. "onStartDialogue", { target = pself })
        dialogueStarted = true
    end
end


return {
    eventHandlers = {
        [MOD_NAME .. "onEquip"] = onEquip,
    },
    engineHandlers = {
        onInit = onInit,
        onLoad = onLoad,
        onSave = onSave,
        onUpdate = onUpdate,
        onActive = onActive,
        onInactive = onInactive,
    },
}
