-- OrderQueueButton.lua
-- SPDX-License-Identifier: MIT
--
-- Adds a button to the order screen, anchored below Form.PaymentContainer.ListOrderButton
-- (the "Place Order" submit button -- see docs/order-screen-research.md), the same way
-- Blizzard's own "Core Alloy" specialization button sits below the left panel's currency row:
-- a fixed, uncrowded spot in the panel's own empty margin rather than squeezed into a toolbar
-- row shared with other addons. Two earlier anchor attempts learned that the hard way:
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
-- 3. Tried above Form.AllocateBestQualityCheckbox instead -- worked, no collisions, but
--    pushed into the reagent-list panel's own content area rather than sitting apart from it.
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

-- Reads Form.order.isRecraft, not transaction:IsRecraft() -- confirmed in-game on a genuine
-- recraft order draft (recraftGUID already set to a real item) that transaction:IsRecraft()
-- returns nil, not true. Blizzard's own client source never calls that method either;
-- InitSchematic branches on self.order.isRecraft throughout (see docs/order-screen-research.md
-- and docs/minimum-quality-notes.md for how that source was obtained). Before this fix, every
-- recraft order silently took the CraftQueue path instead of the Auctionator shopping-list
-- path -- issue #18 wouldn't have been testable at all until this was caught.
local function IsRecraftOrder()
    local order = OrderScreen.form and OrderScreen.form.order
    return order ~= nil and order.isRecraft == true
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
    button:SetPoint("TOP", form.PaymentContainer.ListOrderButton, "BOTTOM", 0, -34)
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
