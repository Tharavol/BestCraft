-- OrderReagents.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Picks a reagent for each slot of the order screen's recipe schematic (see
-- docs/order-screen-research.md). Highest quality by default; lowest when the recipe's output
-- has no quality tiers, since premium reagents buy nothing there (OrderShoppingList.lua).
-- Quality comes from each slot's candidate list, not AllocateBestQualityCheckbox or
-- transaction:GetAllocations().

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen

-- Multiple candidates are either quality ranks of one reagent (pick by tier) or distinct
-- reagents with no tier (e.g. essence flavors), which are left unresolved rather than guessed.
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
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(candidate.itemID)
        if quality and quality > 0 then
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

-- BoP items can't be on the AH even when Customer-sourced (e.g. "Fused Vitality"). bindType is
-- GetItemInfo's 14th return; uncached items return nothing and fail open (not excluded).
local function IsBindOnPickup(itemID)
    local bindType = select(14, C_Item.GetItemInfo(itemID))
    return bindType == Enum.ItemBind.OnAcquire
end

-- Vendor-sold reagents also have pricier AH listings (#20). sellPrice, class, bindType and
-- orderSource don't distinguish them. Tries Auctionator's vendor-price database first, then
-- scans tooltip lines for "vendor" (flavor text "Can be purchased from vendors."; the wording
-- isn't a documented contract, so no exact match).
local function IsVendorPurchasable(itemID)
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetVendorPriceByItemID then
        local ok, vendorPrice = pcall(Auctionator.API.v1.GetVendorPriceByItemID, ADDON_NAME, itemID)
        if ok and vendorPrice then
            return true
        end
    end

    local info = C_TooltipInfo.GetItemByID(itemID)
    if not info or not info.lines then
        return false
    end
    for _, line in ipairs(info.lines) do
        if line.leftText and line.leftText:lower():find("vendor", 1, true) then
            return true
        end
    end
    return false
end

-- Owned count (#23); each quality tier is its own itemID, so no tier matching is needed.
-- Args: itemID, includeBank, includeCharges, includeReagentBank, includeWarband.
local function GetOwnedCount(itemID)
    return C_Item.GetItemCount(itemID, true, false, true, true)
end

-- Settles a slot PickReagent couldn't resolve, when the answer doesn't depend on which
-- candidate the player meant (#26, e.g. two BoP sparks):
-- - "owned": enough of any one candidate is owned.
-- - "unbuyable": every candidate is BoP (an empty list or uncached candidate is not).
-- Returns nil when the slot is genuinely unresolved.
---@return string? outcome "owned" or "unbuyable"
---@return number? itemID The owned candidate, for outcome == "owned"
local function SettleAmbiguousSlot(slot)
    local reagents = slot.reagents
    if not reagents or #reagents == 0 then
        return nil
    end

    -- Without quantityRequired, "owned" can't be judged.
    if slot.quantityRequired then
        for _, candidate in ipairs(reagents) do
            if GetOwnedCount(candidate.itemID) >= slot.quantityRequired then
                return "owned", candidate.itemID
            end
        end
    end

    for _, candidate in ipairs(reagents) do
        if not IsBindOnPickup(candidate.itemID) then
            return nil
        end
    end
    return "unbuyable"
end

-- Builds { itemID, quantity, dataSlotIndex, required } entries from required slots only
-- (optional/finishing slots are never shopped for), quantity being quantityRequired minus the
-- owned count. Crafter-sourced slots are skipped (the crafter supplies them). A resolved
-- reagent is left off when it is vendor-purchasable (#20), BoP, or fully owned (#23); none of
-- these count against allRequiredResolved.
---@param schematicInfo table Return value of transaction:GetRecipeSchematic()
---@param preferLowestQuality boolean? Pick the lowest ranked reagent instead of the highest.
---@return table entries
---@return boolean allRequiredResolved False if a required slot had no confident pick; callers
---   should refuse to act rather than build an incomplete list.
---@return table excludedForVendor itemIDs skipped as vendor-purchasable, for the chat note.
---@return table excludedForOwned itemIDs skipped as already owned, for the chat note.
function OrderScreen:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    local entries = {}
    local excludedForVendor = {}
    local excludedForOwned = {}
    local allRequiredResolved = true
    for _, slot in ipairs((schematicInfo and schematicInfo.reagentSlotSchematics) or {}) do
        if slot.required and slot.orderSource ~= Enum.CraftingOrderReagentSource.Crafter then
            local itemID = PickReagent(slot, preferLowestQuality)
            -- Before the BoP check: a vendor exclusion is the more useful one to report.
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
                local outcome, ownedItemID = SettleAmbiguousSlot(slot)
                if outcome == "owned" then
                    table.insert(excludedForOwned, ownedItemID)
                elseif not outcome then
                    allRequiredResolved = false
                end
            end
        end
    end
    return entries, allRequiredResolved, excludedForVendor, excludedForOwned
end
