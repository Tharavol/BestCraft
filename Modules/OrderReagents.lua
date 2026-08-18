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

local ADDON_NAME, ns = ...

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

-- Some reagents are cheaply available from an NPC vendor even though Auctionator can also find
-- AH listings for them -- confirmed in-game against a real order (issue #20): "Lexicologist's
-- Vellum" had 39s+ AH listings, but paying that is pointless when a vendor sells it directly
-- for less. sellPrice (what a vendor *pays you*) doesn't tell you this, and class/subclass/
-- bindType/orderSource all came back identical between it and the recipe's other, genuinely
-- AH-only reagents when compared side-by-side -- none of those are usable signals.
--
-- Two signals, tried in order:
-- 1. Auctionator.API.v1.GetVendorPriceByItemID -- Auctionator's own maintained vendor-price
--    database (the same data behind its "cheaper than vendor" AH tags; confirmed via
--    CraftSim's use of it, CraftSim/DataSource/PriceAPIs.lua:185). Authoritative when it has
--    an answer, but only covers items that database actually knows about, so it's not relied
--    on alone.
-- 2. Tooltip flavor-text scan, as a fallback for whatever #1 doesn't cover -- confirmed by
--    comparing tooltip text side-by-side for a real vendor-sold and a real AH-only reagent
--    from the same recipe: Blizzard's own flavor text says "Can be purchased from vendors."
--    for the former, "Can be bought and sold on the Auction House." for the latter. Read via
--    C_TooltipInfo (not a live GameTooltip widget, which needs a real frame to anchor to),
--    scanning every line for "vendor" rather than matching the flavor text verbatim, since the
--    exact wording isn't a documented contract -- just the two samples actually seen.
local function IsVendorPurchasable(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetVendorPriceByItemID then
        local ok, vendorPrice = pcall(Auctionator.API.v1.GetVendorPriceByItemID, ADDON_NAME, itemID)
        if ok and vendorPrice then
            return true
        end
    end

    local ok, info = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or not info or not info.lines then
        return false
    end
    for _, line in ipairs(info.lines) do
        if line.leftText and line.leftText:lower():find("vendor", 1, true) then
            return true
        end
    end
    return false
end

-- Reagents already sitting in inventory shouldn't be shopped for again (issue #23) -- buying
-- more of something already owned, at the resolved quality tier, is wasted gold. Since
-- PickReagent above already resolves a slot down to one specific itemID (a different quality
-- tier of the same reagent is a different itemID, per its own comment), checking that same
-- itemID's owned count already accounts for quality with no extra tier-matching needed.
--
-- C_Item.GetItemCount(itemID, includeBank, includeCharges, includeReagentBank, includeWarband)
-- -- confirmed in use with this exact argument shape across CraftSim's own source (e.g.
-- CraftSim/Modules/CraftQueue/UI.lua:394, CraftSim/Classes/SalvageReagentSlot.lua:44). Bags are
-- always included regardless of these flags; bank, reagent bank, and Warband bank are asked
-- for too, but not "charges" (a consumable-specific concept unrelated to crafting reagent
-- stacks). Fails open to 0 (i.e. "own none") on a pcall failure, the safer default -- treating
-- an API error as "already have plenty" would risk silently dropping a genuinely needed
-- reagent from the list.
local function GetOwnedCount(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID, true, false, true, true)
    if ok and count then
        return count
    end
    return 0
end

-- Builds a flat list of { itemID, quantity, dataSlotIndex, required } from a recipe
-- schematic's *required* reagent slots only, choosing one item per slot and its needed
-- quantity (full quantityRequired minus whatever's already owned). Optional slots -- finishing
-- reagents, embellishments, and the like -- are skipped entirely regardless of whether they'd
-- resolve to a confident pick: confirmed by testing (a slot with a single, unambiguous option
-- was going straight onto the shopping list even though it's an optional finishing reagent, not
-- something the recipe actually needs) that "resolvable" and "worth shopping for" are different
-- questions, and this only ever answers the second one for *required* slots. Slots with no
-- confident choice are omitted too, not guessed. OrderShoppingList.lua reshapes the result into
-- Auctionator search strings.
--
-- Three separate reasons a required slot's reagent can still be left off the list, all
-- confirmed in-game against real orders except #3 (per user request, issue #23, not yet
-- confirmed live):
-- 1. The resolved item is bind-on-pickup (see IsBindOnPickup) -- can't be bought regardless of
--    who's meant to provide it, Customer-sourced or not (this is what actually caught "Fused
--    Vitality"; its orderSource was Customer, not Crafter, so orderSource alone didn't cover
--    it).
-- 2. The resolved item is vendor-purchasable (see IsVendorPurchasable) -- technically buyable
--    on the AH too, but pointlessly expensive there, so it's reported back separately rather
--    than silently dropped (see excludedForVendor below).
-- 3. The full quantityRequired is already owned (see GetOwnedCount) -- reported back
--    separately too (see excludedForOwned below). A *partial* owned count reduces the entry's
--    quantity instead of excluding it outright.
-- orderSource == Enum.CraftingOrderReagentSource.Crafter is checked too -- Blizzard's own
-- client source (PROFESSIONS_ORDER_CRAFTER_REQUIRED_REAGENT) says these are reagents the
-- *crafter* must personally provide, not something the customer placing the order is meant to
-- supply -- but that can only actually occur on a required slot in practice, so it's folded
-- into the same required-slot guard rather than a fourth separate reason.
-- None of these exclusions count against allRequiredResolved below -- none was ever something
-- the customer's shopping list should resolve via the AH in the first place, unlike a
-- genuinely unresolved quality pick.
---@param schematicInfo table Return value of transaction:GetRecipeSchematic()
---@param preferLowestQuality boolean? True picks the cheapest ranked reagent per slot instead
---   of the priciest -- for recipes whose output has no quality tiers to benefit from a
---   premium reagent. Falsy (the default) keeps the original highest-quality behavior.
---@return table entries
---@return boolean allRequiredResolved False if a required, purchasable-in-principle slot had no
---   confident pick -- e.g. no candidate reports a quality tier yet. Skipping such a slot
---   silently would hand back an incomplete shopping list with no indication a required
---   reagent is missing, so callers should refuse to act (rather than proceed) when this is
---   false.
---@return table excludedForVendor itemIDs left off the list because IsVendorPurchasable was
---   true -- callers should tell the player what was skipped and why (issue #20), rather than
---   silently shrinking the list with no explanation.
---@return table excludedForOwned itemIDs left off the list because the full quantityRequired
---   was already owned (issue #23) -- same reporting reasoning as excludedForVendor.
function OrderScreen:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    local entries = {}
    local excludedForVendor = {}
    local excludedForOwned = {}
    local allRequiredResolved = true
    for _, slot in ipairs((schematicInfo and schematicInfo.reagentSlotSchematics) or {}) do
        if slot.required and slot.orderSource ~= Enum.CraftingOrderReagentSource.Crafter then
            local itemID = PickReagent(slot, preferLowestQuality)
            -- Checked before IsBindOnPickup below: an item could in principle be both, and a
            -- vendor exclusion is the more informative one to report back to the player.
            if itemID and IsVendorPurchasable(itemID) then
                table.insert(excludedForVendor, itemID)
            elseif itemID and not IsBindOnPickup(itemID) then
                local neededQuantity = slot.quantityRequired - GetOwnedCount(itemID)
                if neededQuantity <= 0 then
                    table.insert(excludedForOwned, itemID)
                else
                    table.insert(entries, {
                        itemID = itemID,
                        quantity = neededQuantity,
                        dataSlotIndex = slot.dataSlotIndex,
                        required = slot.required,
                    })
                end
            elseif not itemID then
                allRequiredResolved = false
            end
        end
    end
    return entries, allRequiredResolved, excludedForVendor, excludedForOwned
end
