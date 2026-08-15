-- OrderQueueButton.lua
-- SPDX-License-Identifier: MIT
--
-- Adds a button to the order screen, anchored above Form.AllocateBestQualityCheckbox (the
-- native "Use Best Quality Reagents" checkbox -- see docs/order-screen-research.md). That
-- spot stays empty regardless of how many reagent slots a recipe has (confirmed across
-- several in-game recipes with differing reagent counts, all showing the same clear gap
-- above it), which two earlier anchor attempts didn't have:
--
-- 1. Originally anchored to TrackRecipeCheckbox's *left*, mirroring how CraftSim anchors its
--    own equivalent button on the other two screens (CraftSim's Modules/CraftQueue/UI.lua:
--    2106-2118) -- but on this screen TrackRecipeCheckbox sits flush against the window's own
--    left edge, so that pushed the button off the visible window entirely (issue #18's
--    in-game recon caught this: the button existed, IsShown() was true, but it was rendering
--    out past the window, over the unit frame).
-- 2. Tried TrackRecipeCheckbox's *right* instead -- back on-window, but a third-party addon
--    (Profession Shopping List) draws its own wider Track/Untrack buttons over the native
--    checkbox, extending further right than the native frame's own bounds account for, so a
--    fixed offset from the native widget still collided with whatever else happens to share
--    that toolbar row for a given user's addon setup.
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
    button:SetPoint("BOTTOMLEFT", form.AllocateBestQualityCheckbox, "TOPLEFT", 0, 8)
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
