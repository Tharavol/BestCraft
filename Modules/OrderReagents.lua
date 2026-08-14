-- OrderReagents.lua
-- SPDX-License-Identifier: MIT
--
-- Picks the highest-quality reagent for each slot on the order screen's recipe schematic,
-- with no independent optimization -- see docs/order-screen-research.md and
-- docs/craftsim-recipedata-notes.md for how this shape was confirmed in-game and cross
-- referenced against CraftSim's own source.

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- A slot's `reagents` array lists every item choice valid for that slot. Multiple entries
-- can mean either quality ranks of the same reagent (pick the highest) or genuinely
-- distinct reagent choices with no quality tier at all (e.g. different enchant essence
-- flavors) -- picking between those would be guessing at player intent, not reading an
-- answer the game already computed, so those are left alone rather than guessed at.
local function PickBestReagent(slot)
    local reagents = slot.reagents
    if not reagents or #reagents == 0 then
        return nil
    end

    if #reagents == 1 then
        return reagents[1].itemID
    end

    local bestItemID, bestQuality
    local anyQuality = false
    for _, candidate in ipairs(reagents) do
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, candidate.itemID)
        if ok and quality and quality > 0 then
            anyQuality = true
            if not bestQuality or quality > bestQuality then
                bestQuality = quality
                bestItemID = candidate.itemID
            end
        end
    end

    if anyQuality then
        return bestItemID
    end

    return nil
end

-- Builds a flat list of { itemID, quantity, dataSlotIndex, required } from a recipe
-- schematic's reagent slots, choosing the highest-quality item per slot and its full
-- required quantity. Slots with no confident choice are omitted, not guessed. Callers
-- reshape this into whatever specific CraftSim.RecipeData method needs -- see
-- docs/craftsim-recipedata-notes.md for why that ended up being
-- SetReagentsByCraftingReagentInfoTbl, not the orderData/SetOrder path this shape was
-- originally built for.
---@param schematicInfo table Return value of transaction:GetRecipeSchematic()
function OrderScreen:GetBestQualityReagentEntries(schematicInfo)
    local entries = {}
    for _, slot in ipairs((schematicInfo and schematicInfo.reagentSlotSchematics) or {}) do
        local itemID = PickBestReagent(slot)
        if itemID then
            table.insert(entries, {
                itemID = itemID,
                quantity = slot.quantityRequired,
                dataSlotIndex = slot.dataSlotIndex,
                required = slot.required,
            })
        end
    end
    return entries
end
