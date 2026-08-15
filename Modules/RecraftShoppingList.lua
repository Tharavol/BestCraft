-- RecraftShoppingList.lua
-- SPDX-License-Identifier: MIT
--
-- Recraft orders can't go through CraftSim.CRAFTQ:AddRecipe -- CraftSim.CRAFTQ:IsRecipeQueueable
-- explicitly refuses any recipeData.isRecraft recipe (Modules/CraftQueue/CraftQueue.lua:1303),
-- and for a real reason: recrafting needs a specific target item's GUID (RecraftSlot,
-- allocationItemGUID), which fits "I'm personally recrafting my own item," not "I'm a
-- customer commissioning someone else's recraft." So this builds an Auctionator shopping
-- list directly instead, via Auctionator.API.v1 -- Auctionator's own documented public API,
-- the same one CraftSim's own CreateAuctionatorShoppingList uses
-- (Modules/CraftQueue/CraftQueue.lua:1251,1254) and ShoppingConverter reads back out of.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen

local LIST_NAME = "BestCraft Recraft Reagents"

function OrderScreen:IsAuctionatorAvailable()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

-- Returns the highest-quality reagent entries for whatever recipe is currently on the order
-- screen (recraft or not -- the schematic shape needs no special-casing here, see
-- docs/order-screen-research.md), or nil if there's no order/recipe currently loaded.
---@return table? entries
---@return boolean? allRequiredResolved See OrderReagents.lua's GetBestQualityReagentEntries.
---   nil (not false) when entries itself is nil -- there's nothing to qualify.
function OrderScreen:GetRecraftShoppingEntries()
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
function OrderScreen:CreateRecraftShoppingList()
    if not self:IsAuctionatorAvailable() then
        return false, "Auctionator is required to build a shopping list for a recraft order."
    end

    local entries, allRequiredResolved = self:GetRecraftShoppingEntries()
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
