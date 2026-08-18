-- OrderShoppingPurchases.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Keeps BestCraft's own Auctionator shopping list in sync as its reagents get bought,
-- decrementing (or removing) the matching line item as each purchase completes -- issue #21,
-- the same behavior CraftSim's own Shopping module already has for its own list, confirmed by
-- reading its actual source (CraftSim/Modules/Shopping/Shopping.lua):
--
--   hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, quantity)
--       CraftSim.SHOPPING:OnConfirmCommoditiesPurchase(itemID, quantity);
--   end);
--
--   function CraftSim.SHOPPING:OnConfirmCommoditiesPurchase(itemID, boughtQuantity)
--       ...
--       self.purchasedItem = { item = Item:CreateFromItemID(itemID), quantity = boughtQuantity };
--   end
--
--   function CraftSim.SHOPPING:COMMODITY_PURCHASE_SUCCEEDED()
--       ... reads the list back (GetShoppingListItems), finds the matching line by parsed
--       ... name+tier (ConvertFromSearchString), subtracts the bought quantity, then either
--       ... AlterShoppingListItem (still > 0 left) or DeleteShoppingListItem (nothing left)
--
--   function CraftSim.SHOPPING:COMMODITY_PURCHASE_FAILED()
--       self:ResetQuickBuyCache() -- clears pending state, no list change
--
-- Adapted for BestCraft's own single named list instead of a whole craft queue, and reusing
-- OrderScreen.ApplyTermDeltas (OrderShoppingList.lua, built for issue #24's merge logic) with
-- a single negative-quantity delta rather than CraftSim's own per-item Alter/Delete calls -- a
-- purchase is just another delta against the list, the same as adding a new order's reagents
-- is, so this doesn't need its own separate read-compare-write implementation.
--
-- Commodities only (C_AuctionHouse.ConfirmCommoditiesPurchase / COMMODITY_PURCHASE_SUCCEEDED)
-- -- the stackable, region-wide-priced AH market virtually every crafting reagent actually
-- trades on, and the only path CraftSim's own working implementation covers either. Individual
-- (non-commodity) listings, a distinct and much rarer purchase path, aren't handled.
--
-- C_AuctionHouse is a base client API, not load-on-demand like ProfessionsCustomerOrdersFrame
-- (OrderScreen.lua), so this hooks it directly at file-load time -- no OnFormFound-style gate
-- needed.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

-- { itemID, quantity } captured by the ConfirmCommoditiesPurchase hook below, consumed (and
-- cleared either way) by whichever of COMMODITY_PURCHASE_SUCCEEDED/_FAILED fires next. A
-- single slot, not a queue -- matches CraftSim's own self.purchasedItem, and the client only
-- ever has one commodity purchase in flight at a time (the confirmation dialog is modal).
local pendingPurchase

local function OnCommodityPurchaseSucceeded()
    local purchase = pendingPurchase
    pendingPurchase = nil
    if not purchase then
        return
    end

    -- Guarded on ns.db existing at all, not just the setting -- same reasoning as every other
    -- toggleable behavior in this addon (e.g. OrderCommission.lua): falls through rather than
    -- treating "not yet known" as "disabled," matching
    -- ns.DEFAULT_SETTINGS.updateOnPurchaseEnabled = true.
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

    -- Item info can be uncached the instant a purchase completes -- ContinueOnItemLoad is the
    -- same wait CraftSim's own equivalent code does for exactly this reason, rather than
    -- reading C_Item.GetItemInfo synchronously and risking a nil name here.
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
    else -- COMMODITY_PURCHASE_FAILED -- clear the pending state, no list change
        pendingPurchase = nil
    end
end)

hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, quantity)
    pendingPurchase = { itemID = itemID, quantity = quantity }
end)
