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

local MOD_NAME       = require("scripts.ErnDebt.ns")
local interfaces     = require("openmw.interfaces")
local pself          = require("openmw.self")

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

local function onActive()
    print("Debt collector " .. pself.recordId .. " is active.")
    interfaces.AI.startPackage({
        type = "Follow",
        cancelOther = true,
        target = collectionData.player,
    })
end

return {
    eventHandlers = {
        onInit = onInit,
        onLoad = onLoad,
        onSave = onSave,
        onActive = onActive,
    },
}
