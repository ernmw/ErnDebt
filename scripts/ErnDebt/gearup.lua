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

local types        = require('openmw.types')
local aux_util     = require('openmw_aux.util')
local world        = require("openmw.world")
local MOD_NAME     = require("scripts.ErnDebt.ns")
local SLOT         = types.Actor.EQUIPMENT_SLOT

-- https://en.uesp.net/wiki/Tamriel_Data:Armor
--https://en.uesp.net/wiki/Tamriel_Data:Clothing

local commonPants  = { "common_pants_01", "common_pants_02", "common_pants_03", "common_pants_04", "common_pants_05",
    "T_Com_Cm_Pants_01",
    "T_Com_Cm_Pants_02",
    "T_Com_Cm_Pants_03",
    "T_Com_Cm_Pants_04" }
local commonShirts = { "common_shirt_01", "common_shirt_02", "common_shirt_03", "common_shirt_04", "common_shirt_05",
    "T_Com_Cm_Shirt_03", "T_Com_Cm_Shirt_04" }
local cheapExtras  = { "Potion_Local_Brew_01", "p_restore_health_b", "p_fortify_fatigue_s", "p_fortify_health_s",
    "potion_comberry_wine_01", "p_magicka_resistance_b", "p_lightning shield_s", "p_fire_shield_s", "p_frost_shield_s" }

-- a random package is chosen, provided it meets the requirements.
-- at least one element in each primitive list must be in the base game.
local gearPackages = {
    {
        name = "1h grunt",
        level = 1,
        equipment = {
            [SLOT.Helmet] = { "bonemold_helm", "T_De_Bonemold_HelmOpen_01" },
            [SLOT.Cuirass] = {
                "netch_leather_boiled_cuirass",
                "T_De_Netch_Cuirass_01",
                "T_De_Netch_Cuirass_02",
                "T_De_Netch_Cuirass_03" },
            [SLOT.CarriedRight] = { "chitin club", "chitin war axe", "chitin dagger", "iron saber", "T_Com_Farm_Hatchet_01" },
            [SLOT.CarriedLeft] = { "chitin_shield", "netch_leather_shield" },
            [SLOT.Shirt] = commonShirts,
            [SLOT.Pants] = commonPants,
            [SLOT.LeftGauntlet] = { "common_glove_left_01" },
            [SLOT.RightGauntlet] = { "common_glove_right_01" },
            [SLOT.Boots] = {
                "netch_leather_boots",
                "T_Imp_Cm_BootsCol_01",
                "T_Imp_Cm_BootsCol_02",
                "T_Imp_Cm_BootsCol_03",
                "T_Imp_Cm_BootsCol_04" },
        },
        extra = cheapExtras,
        spells = { { "noise", "hearth heal" }, { "restore strength", "stamina" } },
    },
    {
        name = "2h grunt",
        level = 1,
        equipment = {
            [SLOT.LeftPauldron] = { "T_De_Chitin_PauldrL_01", "chitin pauldron - left" },
            [SLOT.RightPauldron] = { "T_De_Chitin_PauldrR_01", "chitin pauldron - right" },
            [SLOT.Helmet] = { "chitin_mask_helm", "T_Com_Iron_Helm_01" },
            [SLOT.Cuirass] = { "nordic_ringmail_cuirass" },
            [SLOT.Greaves] = { "netch_leather_greaves", "T_Imp_StuddedLeather_Greaves_01" },
            [SLOT.CarriedRight] = { "iron battle axe", "iron warhammer", "iron claymore", "iron halberd", "T_Com_Iron_Longhammer_01", "T_Com_Iron_Daikatana_01" },
            [SLOT.Shirt] = commonShirts,
            [SLOT.Pants] = commonPants,
            [SLOT.LeftGauntlet] = { "iron_gauntlet_left" },
            [SLOT.RightGauntlet] = { "iron_gauntlet_right" },
            [SLOT.Boots] = { "chitin boots", "T_De_Guarskin_Boots_01" },
        },
        extra = cheapExtras,
        spells = { { "wearying touch", "weakness" }, {} },
    },
    {
        name = "ranged grunt",
        level = 1,
        equipment = {
            [SLOT.Helmet] = { "netch_leather_boiled_helm", "T_Imp_Cm_HatColWest_01" },
            [SLOT.Cuirass] = { "netch_leather_cuirass", "T_De_NetchRogue_Cuirass_01", },
            [SLOT.CarriedRight] = { "chitin short bow" },
            [SLOT.Ammunition] = { "chitin arrow" },
            [SLOT.Shirt] = commonShirts,
            [SLOT.Pants] = commonPants,
            [SLOT.LeftGauntlet] = { "common_glove_left_01" },
            [SLOT.RightGauntlet] = { "T_Nor_Leather1_BarcerR_01", "right leather bracer", "cloth bracer left" },
            [SLOT.Boots] = {
                "netch_leather_boots",
                "chitin boots" },
        },
        extra = cheapExtras,
        spells = { { "bound dagger", "summon scamp" }, { "shockball", "flamebolt", "frost bolt" }, },
    },
}

local function selectGearPackage(pcLevel)
    local allowed = {}
    for _, package in pairs(gearPackages) do
        if package.level <= pcLevel then
            table.insert(allowed, package)
        end
    end
    local idx = math.random(1, #allowed)
    return allowed[idx]
end

local function equipmentValidator(recordId)
    return (types.Armor.records[recordId] or types.Clothing.records[recordId] or types.Weapon.records[recordId]) ~= nil
end

local function extrasValidator(recordId)
    return (types.Potion.records[recordId]) ~= nil
end

---@param recordList string[]
---@param validator fun(a : string): boolean
---@return nil
local function selectRecordFromList(recordList, validator)
    if #recordList == 0 then
        return nil
    end
    local idx = math.random(1, #recordList)
    local recordId = recordList[idx]
    if not validator(recordId) then
        table.remove(recordList, idx)
        return selectRecordFromList(recordList, validator)
    end
    return recordId
end

local function gearupNPC(npc, pcLevel)
    local inventory = npc.type.inventory(npc)
    local gearTable = selectGearPackage(pcLevel)
    local toEquip = {}
    -- now select entries from the table and send to the npc.
    for slot, itemList in pairs(gearTable.equipment) do
        local itemRecordId = selectRecordFromList(itemList, equipmentValidator)
        if itemRecordId then
            local count = slot == SLOT.Ammunition and math.random(10, 20) or 1
            local equipmentObject = world.createObject(itemRecordId, count)
            equipmentObject:moveInto(inventory)
            toEquip[slot] = equipmentObject
        else
            print("nothing for slot" .. tostring(slot))
        end
    end
    print("equip table: " .. aux_util.deepToString(toEquip, 4))
    npc:sendEvent(MOD_NAME .. "onEquip", toEquip)

    -- insert an extra thing
    local itemRecordId = selectRecordFromList(gearTable.extra, extrasValidator)
    if itemRecordId then
        local equipmentObject = world.createObject(itemRecordId)
        equipmentObject:moveInto(inventory)
    end

    -- add spells
    if #gearTable.spells > 0 then
        local spellGroupIdx = math.random(1, #gearTable.spells)
        for _, spellId in pairs(gearTable.spells[spellGroupIdx]) do
            npc.type.spells(npc):add(spellId)
        end
    end
end

return {
    gearupNPC = gearupNPC,
}
