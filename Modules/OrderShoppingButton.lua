-- OrderShoppingButton.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Adds a "+ Shopping List" button to the order screen for every order (recraft or not), via
-- OrderShoppingList.lua. Originally two modes -- normal orders queued into CraftSim.CRAFTQ,
-- only recraft orders (which CraftSim.CRAFTQ refuses outright) got the Auctionator path -- but
-- per feedback, a single shopping-list-only flow for every order is simpler and is what's
-- wanted, so the CraftQueue path was retired even though it worked (confirmed in-game, issue
-- #18). See docs/craftsim-recipedata-notes.md for the retired approach, kept for the record.
--
-- Anchored to the bottom-right corner of ProfessionsCustomerOrdersFrame itself (the whole
-- window, not .Form), mirroring exactly how the Profession Shopping List addon anchors its own
-- "Core Alloy" quick-reorder button -- confirmed by reading that addon's actual source
-- (Slackluster/ProfessionShoppingList, modules-old/CraftingOrders.lua, still genuinely loaded
-- despite the folder name -- checked its own .toc):
--
--   app.RepeatQuickOrderButton = app:MakeButton(ProfessionsCustomerOrdersFrame, "")
--   app.RepeatQuickOrderButton:SetPoint("BOTTOMLEFT", ProfessionsCustomerOrdersFrame, 170, 5)
--
-- Three earlier anchor attempts all measured against *that* button's on-screen position
-- (visually, via screenshots) while anchoring to something else entirely -- there was never a
-- stable geometric relationship between those targets and where Core Alloy actually sits, so
-- no fixed offset could converge:
--
-- 1. Originally anchored to TrackRecipeCheckbox's *left*, mirroring how CraftSim anchors its
--    own equivalent button on the other two screens (CraftSim's Modules/CraftQueue/UI.lua:
--    2106-2118) -- but on this screen TrackRecipeCheckbox sits flush against the window's own
--    left edge, so that pushed the button off the visible window entirely (issue #18's
--    in-game recon caught this: the button existed, IsShown() was true, but it was rendering
--    out past the window, over the unit frame).
-- 2. Tried TrackRecipeCheckbox's *right* instead -- back on-window, but Profession Shopping
--    List draws its own wider Track/Untrack buttons over the native checkbox, extending
--    further right than the native frame's own bounds account for, so a fixed offset from the
--    native widget still collided with whatever else happens to share that toolbar row.
-- 3. Tried above Form.AllocateBestQualityCheckbox, then below Form.PaymentContainer.ListOrderButton
--    -- both stayed on-window with no collisions, but repeated pixel nudges against a
--    screenshot of Core Alloy never quite converged, because Core Alloy's own anchor was never
--    related to either of those elements to begin with.

local _, ns = ...

local OrderScreen = ns.OrderScreen

local BUTTON_LABEL = "+ Shopping List"
local ENABLED_TOOLTIP = "Builds an Auctionator shopping list for this order's highest-quality reagents."

-- The same three checks RefreshButtonState uses to gate SetEnabled, but returning *why* --
-- issue #8: this screen's other buttons all show a tooltip explaining themselves (see
-- GameTooltip_AddNormalLine/AddErrorLine usage throughout Blizzard's own
-- Blizzard_ProfessionsCustomerOrdersForm.lua), and this one didn't have one at all.
---@return string? reason nil when the button is/would be enabled
local function GetDisabledReason()
    if not OrderScreen:IsAuctionatorAvailable() then
        return "Requires Auctionator to be installed and enabled."
    end

    local entries, allRequiredResolved = OrderScreen:GetShoppingEntries()
    if not allRequiredResolved then
        return "Couldn't resolve every required reagent for this order yet -- "
            .. "try again once all slots have a selection."
    end
    if not entries or #entries == 0 then
        return "No reagents to shop for on this order."
    end

    return nil
end

local function RefreshButtonState(button)
    button.disabledReason = GetDisabledReason()
    button:SetEnabled(button.disabledReason == nil)
end

local function OnClick()
    local ok, message = OrderScreen:CreateShoppingList()
    if not ok then
        print("|cffff4444BestCraft|r " .. message)
    end
end

local function OnEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.disabledReason then
        GameTooltip_AddErrorLine(GameTooltip, button.disabledReason)
    else
        GameTooltip_AddNormalLine(GameTooltip, ENABLED_TOOLTIP)
    end
    GameTooltip:Show()
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function CreateButton(form)
    local button = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("BOTTOMRIGHT", ProfessionsCustomerOrdersFrame, -20, 5)
    button:SetText(BUTTON_LABEL)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)

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
