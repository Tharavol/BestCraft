-- OrderShoppingList.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Builds an Auctionator shopping list for the order screen's current recipe -- every order,
-- not just recraft ones. Originally recraft-only: CraftSim.CRAFTQ:IsRecipeQueueable explicitly
-- refuses any recipeData.isRecraft recipe (Modules/CraftQueue/CraftQueue.lua:1303), for a real
-- reason (recrafting needs a specific target item's GUID, which fits "I'm personally
-- recrafting my own item," not "I'm a customer commissioning someone else's recraft"), so
-- recraft orders got their own Auctionator-only path while normal orders queued into
-- CraftSim.CRAFTQ instead. Confirmed in-game (issue #18) that the CraftQueue path actually
-- worked -- but per feedback, a single shopping-list-only flow for every order is simpler and
-- is what's wanted, so that's now the only path; see docs/craftsim-recipedata-notes.md for the
-- retired CraftQueue-based approach, kept for the record.
--
-- Builds via Auctionator.API.v1 -- Auctionator's own documented public API, the same one
-- CraftSim's own CreateAuctionatorShoppingList used (Modules/CraftQueue/CraftQueue.lua:
-- 1251,1254) and ShoppingConverter reads back out of.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

function OrderScreen:IsAuctionatorAvailable()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

-- Returns the chosen reagent entries for whatever recipe is currently on the order screen
-- (recraft or not -- the schematic shape needs no special-casing here, see
-- docs/order-screen-research.md), or nil if there's no order/recipe currently loaded.
--
-- Prefers the lowest-quality reagent per slot, not the highest, when the recipe's *output*
-- has no quality tiers of its own -- confirmed against a real order (Thalassian Treatise on
-- Enchanting) that a recipe like this exists and that paying for premium reagents buys
-- nothing there, since the crafted result can't rank up regardless. Detected via
-- Form.minQualityIDs, the same per-recipe data issue #17's Minimum Quality default already
-- reads (index 1 is a "None" placeholder, not a real tier -- see
-- docs/minimum-quality-notes.md -- so #minQualityIDs <= 1 means no real tier exists at all).
---@return table? entries
---@return boolean? allRequiredResolved See OrderReagents.lua's GetChosenReagentEntries.
---   nil (not false) when entries itself is nil -- there's nothing to qualify.
---@return string? recipeName schematicInfo.name, for the chat confirmation on success.
function OrderScreen:GetShoppingEntries()
    local form = self.form
    local transaction = form and form.transaction
    if not transaction then
        return nil
    end

    local ok, schematicInfo = pcall(transaction.GetRecipeSchematic, transaction)
    if not ok or not schematicInfo then
        return nil
    end

    -- Only when minQualityIDs is confirmed present with no real tier (see the header comment)
    -- -- NOT merely when it's nil/not-yet-known (a load-order edge case OrderMinimumQuality.lua
    -- also has to guard against). Preferring lowest quality by default whenever this data
    -- simply isn't ready yet would risk silently under-quality-ing a genuinely ranked recipe;
    -- staying with the historical highest-quality default when uncertain just costs a bit more
    -- on an unranked one instead -- the safer failure mode of the two.
    local minQualityIDs = form.minQualityIDs
    local preferLowestQuality = minQualityIDs ~= nil and #minQualityIDs <= 1

    local entries, allRequiredResolved = self:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    return entries, allRequiredResolved, schematicInfo.name
end

-- Builds Auctionator search strings and a parallel "Name [xN], Name [xN], ..." human-readable
-- summary of the same entries together, so each entry's item name is only looked up once.
---@return table searchStrings
---@return string summary
local function BuildSearchStringsAndSummary(entries)
    local searchStrings = {}
    local summaryParts = {}
    for _, entry in ipairs(entries) do
        local itemName = C_Item.GetItemInfo(entry.itemID)
        if itemName then
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(entry.itemID)
            local ok, searchString = pcall(Auctionator.API.v1.ConvertToSearchString, ADDON_NAME, {
                searchString = itemName,
                tier = quality,
                quantity = entry.quantity,
                isExact = true,
            })
            if ok and searchString then
                table.insert(searchStrings, searchString)
                table.insert(summaryParts, ("%s [x%d]"):format(itemName, entry.quantity))
            end
        end
    end
    return searchStrings, table.concat(summaryParts, ", ")
end

---@return boolean success
---@return string? message On failure, why. On success, a chat-ready confirmation of the
---   recipe and materials added (issue feedback: the player asked what was added and why).
function OrderScreen:CreateShoppingList()
    if not self:IsAuctionatorAvailable() then
        return false, L.ERROR_NO_AUCTIONATOR
    end

    local entries, allRequiredResolved, recipeName = self:GetShoppingEntries()
    if not entries then
        return false, L.STATUS_NO_REAGENTS
    end
    if not allRequiredResolved then
        return false, L.STATUS_UNRESOLVED_REQUIRED
    end
    if #entries == 0 then
        return false, L.STATUS_NO_REAGENTS
    end

    local searchStrings, summary = BuildSearchStringsAndSummary(entries)
    if #searchStrings == 0 then
        return false, L.ERROR_UNRESOLVED_ITEM_NAMES
    end

    -- Matches CraftSim's own CreateAuctionatorShoppingList: delete any existing list under
    -- this name first, so repeated clicks replace rather than accumulate duplicates.
    if Auctionator.Shopping and Auctionator.Shopping.ListManager
        and Auctionator.Shopping.ListManager:GetIndexForName(L.SHOPPING_LIST_NAME) then
        Auctionator.Shopping.ListManager:Delete(L.SHOPPING_LIST_NAME)
    end

    local ok = pcall(Auctionator.API.v1.CreateShoppingList, ADDON_NAME, L.SHOPPING_LIST_NAME, searchStrings)
    if not ok then
        return false, L.ERROR_CREATE_FAILED
    end

    return true, L.CHAT_LIST_CREATED:format(recipeName or L.CHAT_UNKNOWN_RECIPE, summary)
end
