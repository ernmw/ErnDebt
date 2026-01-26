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

local types       = require('openmw.types')
local aux_util    = require('openmw_aux.util')
local world       = require("openmw.world")
local MOD_NAME    = require("scripts.ErnDebt.ns")

local SLOT        = types.Actor.EQUIPMENT_SLOT

local gearByLevel = {
    [1] = {
        equipment = {
            [SLOT.Helmet] = { "bonemold_helm" },
            [SLOT.Cuirass] = { "netch_leather_boiled_cuirass" },
            [SLOT.CarriedRight] = { "chitin club", "chitin war axe", "chitin dagger", "iron saber" },
            [SLOT.Shirt] = { "common_shirt_01", "common_shirt_02", "common_shirt_03", "common_shirt_04", "common_shirt_05" },
            [SLOT.Pants] = { "common_pants_01", "common_pants_02", "common_pants_03", "common_pants_04", "common_pants_05" },
            [SLOT.LeftGauntlet] = { "cloth bracer left" },
            [SLOT.RightGauntlet] = { "cloth bracer right" },
            [SLOT.Boots] = { "netch_leather_boots" },
        },
        extra = { "p_recall_s" },
    },
    [2] = {
        equipment = {
            [SLOT.Helmet] = { "chitin_mask_helm" },
            [SLOT.Cuirass] = { "nordic_ringmail_cuirass" },
            [SLOT.Greaves] = { "netch_leather_greaves" },
            [SLOT.CarriedRight] = { "spiked club", "iron war axe", "iron dagger", "iron broadsword" },
            [SLOT.LeftGauntlet] = { "iron_gauntlet_left" },
            [SLOT.RightGauntlet] = { "iron_gauntlet_right" },
            [SLOT.Boots] = { "chitin boots" },
        },
        extra = { "p_fortify_fatigue_s" },
    },
}

local function mergeGear(pcLevel)
    local merged = { equipment = {}, extra = {} }
    for gearLevel, gearGroup in pairs(gearByLevel) do
        if gearLevel <= pcLevel then
            for slot, items in pairs(gearGroup.equipment) do
                if not merged.equipment[slot] then
                    merged.equipment[slot] = {}
                end
                for _, item in pairs(items) do
                    table.insert(merged.equipment[slot], item)
                end
            end
            for _, item in pairs(gearGroup.extra) do
                table.insert(merged.extra, item)
            end
        end
    end
    print("merged gear table: " .. aux_util.deepToString(merged, 4))
    return merged
end

local function selectRecordFromList(recordList)
    if #recordList == 0 then
        return nil
    end
    local idx = math.random(1, #recordList)
    local recordId = recordList[idx]
    local valid = types.Armor.records[recordId] or types.Potion.records[recordId] or types.Clothing.records[recordId] or
        types.Weapon.records[recordId]
    if not valid then
        table.remove(recordList, idx)
        return selectRecordFromList(recordList)
    end
end

local function gearupNPC(npc, pcLevel)
    local inventory = npc.type.inventory(npc)
    local gearTable = mergeGear(pcLevel)
    local toEquip = {}
    -- now select entries from the table
    for slot, itemList in gearTable.equipment do
        local itemRecordId = selectRecordFromList(itemList)
        if itemRecordId then
            local equipmentObject = world.createObject(itemRecordId)
            equipmentObject:moveInto(inventory)
            toEquip[slot] = equipmentObject
        end
    end

    npc.sendEvent(MOD_NAME .. "onEquip", toEquip)
end

return {
    gearupNPC = gearupNPC,
}
