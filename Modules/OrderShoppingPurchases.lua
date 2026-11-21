-- OrderShoppingPurchases.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Decrements BestCraft's shopping list as its reagents are bought (#21), following CraftSim's
-- Shopping module: capture itemID/quantity in a ConfirmCommoditiesPurchase hook, then apply a
-- negative delta via OrderScreen.ApplyTermDeltas on COMMODITY_PURCHASE_SUCCEEDED.
-- Commodities only; individual (non-commodity) auctions aren't handled.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

-- { itemID, quantity }, cleared by the next SUCCEEDED/FAILED event. A single slot suffices:
-- the confirmation dialog is modal, so only one purchase is in flight.
local pendingPurchase

local function OnCommodityPurchaseSucceeded()
    local purchase = pendingPurchase
    pendingPurchase = nil
    if not purchase then
        return
    end

    if ns.db and not ns.db.settings.updateOnPurchaseEnabled then
        return
    end

    if not OrderScreen:IsAuctionatorAvailable() then
        return
    end

    local listManager = Auctionator.Shopping and Auctionator.Shopping.ListManager
    if not listManager or not listManager:GetIndexForName(L.SHOPPING_LIST_NAME) then
        return
    end

    -- Item info may be uncached when the purchase completes.
    local item = Item:CreateFromItemID(purchase.itemID)
    item:ContinueOnItemLoad(function()
        local itemName = item:GetItemName()
        if not itemName then
            return
        end
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(purchase.itemID)

        local ok, existingSearchStrings = pcall(Auctionator.API.v1.GetShoppingListItems, ADDON_NAME,
            L.SHOPPING_LIST_NAME)
        if not ok or not existingSearchStrings then
            return
        end

        local finalSearchStrings = OrderScreen.ApplyTermDeltas(existingSearchStrings, {
            { searchString = itemName, tier = quality, quantity = -purchase.quantity },
        })
        pcall(Auctionator.API.v1.CreateShoppingList, ADDON_NAME, L.SHOPPING_LIST_NAME, finalSearchStrings)
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
frame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
frame:SetScript("OnEvent", function(_, event)
    if event == "COMMODITY_PURCHASE_SUCCEEDED" then
        OnCommodityPurchaseSucceeded()
    else -- COMMODITY_PURCHASE_FAILED
        pendingPurchase = nil
    end
end)

hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, quantity)
    pendingPurchase = { itemID = itemID, quantity = quantity }
end)
