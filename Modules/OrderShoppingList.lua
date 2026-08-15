-- OrderShoppingList.lua
-- SPDX-License-Identifier: MIT
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

local LIST_NAME = "BestCraft"

function OrderScreen:IsAuctionatorAvailable()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

-- Returns the highest-quality reagent entries for whatever recipe is currently on the order
-- screen (recraft or not -- the schematic shape needs no special-casing here, see
-- docs/order-screen-research.md), or nil if there's no order/recipe currently loaded.
---@return table? entries
---@return boolean? allRequiredResolved See OrderReagents.lua's GetBestQualityReagentEntries.
---   nil (not false) when entries itself is nil -- there's nothing to qualify.
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

    return self:GetBestQualityReagentEntries(schematicInfo)
end

local function BuildSearchStrings(entries)
    local searchStrings = {}
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
            end
        end
    end
    return searchStrings
end

---@return boolean success
---@return string? message Set on failure, for the caller to show the player.
function OrderScreen:CreateShoppingList()
    if not self:IsAuctionatorAvailable() then
        return false, "Auctionator is required to build a shopping list for this order."
    end

    local entries, allRequiredResolved = self:GetShoppingEntries()
    if not entries then
        return false, "No reagents to shop for on this order."
    end
    if not allRequiredResolved then
        return false,
            "Couldn't resolve every required reagent for this order yet -- try again once all slots have a selection."
    end
    if #entries == 0 then
        return false, "No reagents to shop for on this order."
    end

    local searchStrings = BuildSearchStrings(entries)
    if #searchStrings == 0 then
        return false, "Couldn't resolve item names for this order's reagents yet -- try again in a moment."
    end

    -- Matches CraftSim's own CreateAuctionatorShoppingList: delete any existing list under
    -- this name first, so repeated clicks replace rather than accumulate duplicates.
    if Auctionator.Shopping and Auctionator.Shopping.ListManager
        and Auctionator.Shopping.ListManager:GetIndexForName(LIST_NAME) then
        Auctionator.Shopping.ListManager:Delete(LIST_NAME)
    end

    local ok = pcall(Auctionator.API.v1.CreateShoppingList, ADDON_NAME, LIST_NAME, searchStrings)
    if not ok then
        return false, "Couldn't create the Auctionator shopping list."
    end

    return true
end
