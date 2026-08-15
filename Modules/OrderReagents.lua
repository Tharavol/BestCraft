-- OrderReagents.lua
-- SPDX-License-Identifier: MIT
--
-- Picks the highest-quality reagent for each slot on the order screen's recipe schematic,
-- with no independent optimization -- see docs/order-screen-research.md for how this shape
-- was confirmed in-game (docs/craftsim-recipedata-notes.md also covers it, cross referenced
-- against CraftSim's own source, though that doc's specific RecipeData-construction path was
-- later retired -- see OrderShoppingList.lua).
--
-- Deliberately does not read `AllocateBestQualityCheckbox` or `transaction:GetAllocations()`
-- at all: quality is picked directly from each slot's candidate list
-- (C_TradeSkillUI.GetItemReagentQualityByItemInfo), independent of whatever the native
-- checkbox is set to. BestCraft's whole purpose is handing back the highest-quality shopping
-- list regardless of the order's own quality setting (see README's "Why"), so the checkbox
-- being off doesn't change anything here -- there's no unresolved case to handle for it.

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
-- required quantity. Slots with no confident choice are omitted, not guessed.
-- OrderShoppingList.lua reshapes this into Auctionator search strings.
---@param schematicInfo table Return value of transaction:GetRecipeSchematic()
---@return table entries
---@return boolean allRequiredResolved False if a *required* slot had no confident pick --
---   e.g. an optional reagent's ranked choice was never touched by the player, or no
---   candidate reports a quality tier yet. Skipping such a slot silently would hand back an
---   incomplete recipeData/shopping list with no indication a required reagent is missing,
---   so callers should refuse to act (rather than proceed) when this is false. Unresolved
---   *optional* slots (required == false) don't affect this -- they're expected to be
---   skippable.
function OrderScreen:GetBestQualityReagentEntries(schematicInfo)
    local entries = {}
    local allRequiredResolved = true
    for _, slot in ipairs((schematicInfo and schematicInfo.reagentSlotSchematics) or {}) do
        local itemID = PickBestReagent(slot)
        if itemID then
            table.insert(entries, {
                itemID = itemID,
                quantity = slot.quantityRequired,
                dataSlotIndex = slot.dataSlotIndex,
                required = slot.required,
            })
        elseif slot.required then
            allRequiredResolved = false
        end
    end
    return entries, allRequiredResolved
end
