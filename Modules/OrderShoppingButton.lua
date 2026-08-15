-- OrderShoppingButton.lua
-- SPDX-License-Identifier: MIT
--
-- Adds a "+ Shopping List" button to the order screen for every order (recraft or not), via
-- OrderShoppingList.lua. Originally two modes -- normal orders queued into CraftSim.CRAFTQ,
-- only recraft orders (which CraftSim.CRAFTQ refuses outright) got the Auctionator path -- but
-- per feedback, a single shopping-list-only flow for every order is simpler and is what's
-- wanted, so the CraftQueue path was retired even though it worked (confirmed in-game, issue
-- #18). See docs/craftsim-recipedata-notes.md for the retired approach, kept for the record.
--
-- Anchored below Form.PaymentContainer.ListOrderButton (the "Place Order" submit button --
-- see docs/order-screen-research.md), the same way Blizzard's own "Core Alloy" specialization
-- button sits below the left panel's currency row: a fixed, uncrowded spot in the panel's own
-- empty margin rather than squeezed into a toolbar row shared with other addons. Two earlier
-- anchor attempts learned that the hard way:
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

local _, ns = ...

local OrderScreen = ns.OrderScreen

local BUTTON_LABEL = "+ Shopping List"

local function RefreshButtonState(button)
    local entries, allRequiredResolved = OrderScreen:GetShoppingEntries()
    button:SetEnabled(entries ~= nil and #entries > 0 and allRequiredResolved and OrderScreen:IsAuctionatorAvailable())
end

local function OnClick()
    local ok, message = OrderScreen:CreateShoppingList()
    if not ok then
        print("|cffff4444BestCraft|r " .. message)
    end
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function CreateButton(form)
    local button = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("TOP", form.PaymentContainer.ListOrderButton, "BOTTOM", 0, -30)
    button:SetText(BUTTON_LABEL)
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
