-- OrderQueueButton.lua
-- SPDX-License-Identifier: MIT
--
-- Adds a "+ CraftQueue" button to the order screen, anchored the same way CraftSim anchors
-- its own equivalent button on the other two screens (to the left of TrackRecipeCheckbox --
-- see CraftSim's Modules/CraftQueue/UI.lua:2106-2118, and docs/order-screen-research.md for
-- why ProfessionsCustomerOrdersFrame.Form has its own TrackRecipeCheckbox to anchor to).
--
-- Reaches CraftSim.CRAFTQ through CraftSimAPI:GetCraftSim() -- there's no CraftSimAPI
-- wrapper for AddRecipe specifically, so this is the documented "get the whole table" escape
-- hatch (Util/API.lua:20-22), not a reach into something unpublished the way the old
-- CraftSim.RecipeData attempt was (see docs/craftsim-recipedata-notes.md).

local _, ns = ...

local OrderScreen = ns.OrderScreen

local BUTTON_LABEL = "+ CraftQueue"

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

local function RefreshButtonState(button)
    local craftQueue = GetCraftQueue()
    if not craftQueue then
        button:SetEnabled(false)
        return
    end

    local recipeData = OrderScreen:BuildRecipeData()
    local queueableOk, queueable = pcall(craftQueue.IsRecipeQueueable, craftQueue, recipeData)
    button:SetEnabled(recipeData ~= nil and queueableOk and queueable == true)
end

local function OnClick()
    local craftQueue = GetCraftQueue()
    if not craftQueue then
        return
    end

    local recipeData = OrderScreen:BuildRecipeData()
    if not recipeData then
        print("|cffff4444BestCraft|r couldn't read this order's recipe.")
        return
    end

    local queueableOk, queueable = pcall(craftQueue.IsRecipeQueueable, craftQueue, recipeData)
    if not queueableOk or not queueable then
        print("|cffff4444BestCraft|r this recipe can't be queued (recraft orders, for example, " ..
            "aren't supported by CraftSim's CraftQueue).")
        return
    end

    craftQueue:AddRecipe({ recipeData = recipeData })
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function CreateButton(form)
    local button = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("RIGHT", form.TrackRecipeCheckbox, "LEFT", -18, 0)
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
