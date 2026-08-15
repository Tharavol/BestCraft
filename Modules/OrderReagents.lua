-- OrderReagents.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Picks a reagent for each slot on the order screen's recipe schematic, with no independent
-- optimization -- see docs/order-screen-research.md for how this shape was confirmed in-game
-- (docs/craftsim-recipedata-notes.md also covers it, cross referenced against CraftSim's own
-- source, though that doc's specific RecipeData-construction path was later retired -- see
-- OrderShoppingList.lua).
--
-- Highest quality by default, but lowest when the recipe's *output* has no quality tiers at
-- all -- confirmed by user testing against a real order (Thalassian Treatise on Enchanting):
-- paying extra for premium reagents buys nothing if the crafted result can't rank up, so
-- OrderShoppingList.lua passes preferLowestQuality=true in that case (see its own comment for
-- how it's detected, reusing the same Form.minQualityIDs data issue #17's work already reads).
--
-- Deliberately does not read `AllocateBestQualityCheckbox` or `transaction:GetAllocations()`
-- at all: quality is picked directly from each slot's candidate list
-- (C_TradeSkillUI.GetItemReagentQualityByItemInfo), independent of whatever the native
-- checkbox is set to -- the checkbox being off doesn't change anything here, there's no
-- unresolved case to handle for it.

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- A slot's `reagents` array lists every item choice valid for that slot. Multiple entries
-- can mean either quality ranks of the same reagent (pick the highest or lowest, depending on
-- preferLowestQuality) or genuinely distinct reagent choices with no quality tier at all (e.g.
-- different enchant essence flavors) -- picking between those would be guessing at player
-- intent, not reading an answer the game already computed, so those are left alone rather
-- than guessed at.
local function PickReagent(slot, preferLowestQuality)
    local reagents = slot.reagents
    if not reagents or #reagents == 0 then
        return nil
    end

    if #reagents == 1 then
        return reagents[1].itemID
    end

    local pickedItemID, pickedQuality
    local anyQuality = false
    for _, candidate in ipairs(reagents) do
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, candidate.itemID)
        if ok and quality and quality > 0 then
            anyQuality = true
            local better = not pickedQuality
                or (preferLowestQuality and quality < pickedQuality)
                or (not preferLowestQuality and quality > pickedQuality)
            if better then
                pickedQuality = quality
                pickedItemID = candidate.itemID
            end
        end
    end

    if anyQuality then
        return pickedItemID
    end

    return nil
end

-- Bind-on-pickup items can never be sold on the auction house, full stop -- confirmed in-game
-- against a real order: a required, Customer-sourced reagent ("Fused Vitality", orderSource ==
-- Enum.CraftingOrderReagentSource.Customer, so NOT caught by the orderSource check below)
-- still returned zero Auctionator search results, because the item itself is BoP. bindType is
-- C_Item.GetItemInfo's 14th return value (Blizzard_APIDocumentationGenerated/
-- ItemDocumentation.lua); MayReturnNothing == true for uncached items, in which case this
-- returns nil and fails open (not excluded) -- an occasional un-filtered BoP item if data
-- hasn't loaded yet is the same failure mode as today, not a regression, whereas excluding on
-- unknown status risks dropping a legitimately purchasable reagent whose info just hasn't
-- cached yet.
local function IsBindOnPickup(itemID)
    local bindType = select(14, C_Item.GetItemInfo(itemID))
    return bindType == Enum.ItemBind.OnAcquire
end

-- Builds a flat list of { itemID, quantity, dataSlotIndex, required } from a recipe
-- schematic's reagent slots, choosing one item per slot and its full required quantity. Slots
-- with no confident choice are omitted, not guessed. OrderShoppingList.lua reshapes this into
-- Auctionator search strings.
--
-- Two separate reasons a slot can be excluded, both confirmed in-game against real orders:
-- 1. orderSource == Enum.CraftingOrderReagentSource.Crafter -- Blizzard's own client source
--    (PROFESSIONS_ORDER_CRAFTER_REQUIRED_REAGENT) says these are reagents the *crafter* must
--    personally provide, not something the customer placing the order is meant to supply.
-- 2. The resolved item is bind-on-pickup (see IsBindOnPickup) -- can't be bought regardless of
--    who's meant to provide it, Customer-sourced or not (this is what actually caught "Fused
--    Vitality"; its orderSource was Customer, not Crafter, so #1 alone didn't cover it).
-- Neither kind of exclusion counts against allRequiredResolved below -- neither was ever
-- something the customer's shopping list could resolve in the first place, unlike a genuinely
-- unresolved quality pick.
---@param schematicInfo table Return value of transaction:GetRecipeSchematic()
---@param preferLowestQuality boolean? True picks the cheapest ranked reagent per slot instead
---   of the priciest -- for recipes whose output has no quality tiers to benefit from a
---   premium reagent. Falsy (the default) keeps the original highest-quality behavior.
---@return table entries
---@return boolean allRequiredResolved False if a *required*, purchasable-in-principle slot had
---   no confident pick -- e.g. an optional reagent's ranked choice was never touched by the
---   player, or no candidate reports a quality tier yet. Skipping such a slot silently would
---   hand back an incomplete shopping list with no indication a required reagent is missing,
---   so callers should refuse to act (rather than proceed) when this is false. Unresolved
---   *optional* slots (required == false) don't affect this -- they're expected to be
---   skippable.
function OrderScreen:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    local entries = {}
    local allRequiredResolved = true
    for _, slot in ipairs((schematicInfo and schematicInfo.reagentSlotSchematics) or {}) do
        if slot.orderSource ~= Enum.CraftingOrderReagentSource.Crafter then
            local itemID = PickReagent(slot, preferLowestQuality)
            if itemID and not IsBindOnPickup(itemID) then
                table.insert(entries, {
                    itemID = itemID,
                    quantity = slot.quantityRequired,
                    dataSlotIndex = slot.dataSlotIndex,
                    required = slot.required,
                })
            elseif slot.required and not itemID then
                allRequiredResolved = false
            end
        end
    end
    return entries, allRequiredResolved
end
