-- OrderQueueButton.lua
-- SPDX-License-Identifier: MIT
--
-- Adds a button to the order screen, anchored the same way CraftSim anchors its own
-- equivalent button on the other two screens (to the left of TrackRecipeCheckbox -- see
-- CraftSim's Modules/CraftQueue/UI.lua:2106-2118, and docs/order-screen-research.md for why
-- ProfessionsCustomerOrdersFrame.Form has its own TrackRecipeCheckbox to anchor to).
--
-- Two modes, chosen per order:
-- - Normal orders: "+ CraftQueue", reaches CraftSim.CRAFTQ through CraftSimAPI:GetCraftSim()
--   (no CraftSimAPI wrapper for AddRecipe specifically, so this is the documented "get the
--   whole table" escape hatch, Util/API.lua:20-22 -- not a reach into something unpublished
--   the way the old CraftSim.RecipeData attempt was, see docs/craftsim-recipedata-notes.md).
-- - Recraft orders: "+ Shopping List", via RecraftShoppingList.lua -- CraftSim.CRAFTQ won't
--   accept recraft recipes at all (see that file's header comment), so there's no queue
--   entry to make here, just an Auctionator shopping list.

local _, ns = ...

local OrderScreen = ns.OrderScreen

local QUEUE_LABEL = "+ CraftQueue"
local RECRAFT_LABEL = "+ Shopping List"

local function IsRecraftOrder()
    local transaction = OrderScreen.form and OrderScreen.form.transaction
    if not transaction then
        return false
    end
    local ok, isRecraft = pcall(transaction.IsRecraft, transaction)
    return ok and isRecraft == true
end

---@return table? craftQueue CraftSim.CRAFTQ, or nil if CraftSimAPI/CraftSim aren't ready
local function GetCraftQueue()
    if not (CraftSimAPI and CraftSimAPI.GetCraftSim) then
        return nil
    end
    local ok, craftSim = pcall(CraftSimAPI.GetCraftSim, CraftSimAPI)
    if not ok or not craftSim then
        return nil
    end
    return craftSim.CRAFTQ
end

local function RefreshRecraftState(button)
    button:SetText(RECRAFT_LABEL)
    local entries, allRequiredResolved = OrderScreen:GetRecraftShoppingEntries()
    button:SetEnabled(entries ~= nil and #entries > 0 and allRequiredResolved and OrderScreen:IsAuctionatorAvailable())
end

local function RefreshQueueState(button)
    button:SetText(QUEUE_LABEL)
    local craftQueue = GetCraftQueue()
    if not craftQueue then
        button:SetEnabled(false)
        return
    end

    local recipeData, allRequiredResolved = OrderScreen:BuildRecipeData()
    local queueableOk, queueable = pcall(craftQueue.IsRecipeQueueable, craftQueue, recipeData)
    button:SetEnabled(recipeData ~= nil and allRequiredResolved and queueableOk and queueable == true)
end

local function RefreshButtonState(button)
    if IsRecraftOrder() then
        RefreshRecraftState(button)
    else
        RefreshQueueState(button)
    end
end

local function OnClickRecraft()
    local ok, message = OrderScreen:CreateRecraftShoppingList()
    if not ok then
        print("|cffff4444BestCraft|r " .. message)
    end
end

local function OnClickQueue()
    local craftQueue = GetCraftQueue()
    if not craftQueue then
        return
    end

    local recipeData, allRequiredResolved = OrderScreen:BuildRecipeData()
    if not recipeData then
        print("|cffff4444BestCraft|r couldn't read this order's recipe.")
        return
    end
    if not allRequiredResolved then
        print("|cffff4444BestCraft|r couldn't resolve every required reagent for this order yet -- "
            .. "try again once all slots have a selection.")
        return
    end

    local queueableOk, queueable = pcall(craftQueue.IsRecipeQueueable, craftQueue, recipeData)
    if not queueableOk or not queueable then
        print("|cffff4444BestCraft|r this recipe can't be queued.")
        return
    end

    craftQueue:AddRecipe({ recipeData = recipeData })
end

local function OnClick()
    if IsRecraftOrder() then
        OnClickRecraft()
    else
        OnClickQueue()
    end
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function CreateButton(form)
    local button = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("RIGHT", form.TrackRecipeCheckbox, "LEFT", -18, 0)
    button:SetText(QUEUE_LABEL)
    button:SetScript("OnClick", OnClick)

    local function Refresh() RefreshButtonState(button) end

    form:HookScript("OnShow", Refresh)
    -- The order screen doesn't fire a change event when the player picks a different
    -- recipe or reagent allocation -- UpdateReagentSlots is what it calls internally on
    -- both, so hooking it (rather than relying on OnShow alone) is what actually keeps the
    -- button's enabled state in sync while the screen stays open. Matches CraftSim's own
    -- documented reason for hooking specific methods instead of events on this UI family
    -- (Modules/Modules.lua:78: "SchematicForm:Init or tab OnClick does not fire").
    if form.UpdateReagentSlots then
        hooksecurefunc(form, "UpdateReagentSlots", Refresh)
    end

    Refresh()
end

OrderScreen:OnFormFound(CreateButton)
