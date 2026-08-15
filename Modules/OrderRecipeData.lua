-- OrderRecipeData.lua
-- SPDX-License-Identifier: MIT
--
-- Builds a CraftSim.RecipeData for the order screen's current recipe, with its reagent
-- slots pre-filled to the highest-quality choice from OrderReagents.lua.
--
-- Goes through CraftSimAPI:GetRecipeData(), not CraftSim.RecipeData directly -- CraftSim's
-- internal addon table is never published as a global (confirmed in-game: `CraftSim` reads
-- as nil from another addon's context), only CraftSimAPI (Util/API.lua) is, and its
-- GetRecipeData wraps the exact same constructor options.
--
-- Does NOT pass `orderData` to the constructor / RecipeData:SetOrder() -- confirmed in-game
-- that SetOrder unconditionally calls C_TradeSkillUI.GetCraftingOperationInfoForOrder(...,
-- self.orderData.orderID, ...), which throws when orderID is nil, i.e. for any order that
-- hasn't been submitted yet (see docs/craftsim-recipedata-notes.md). Reagent choices are
-- applied afterwards instead, via RecipeData:SetReagentsByCraftingReagentInfoTbl(), which
-- only touches reagent allocation and never calls that API.
--
-- Unlike OrderReagents.lua's slot-selection logic, this cannot be meaningfully unit tested
-- without CraftSim's real classes loaded, so it leans on pcall the same way ShoppingConverter
-- does around CraftSim internals it doesn't control: best-effort, fails closed to nil rather
-- than a half-built RecipeData.

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- Returns a CraftSim.RecipeData for the order screen's current recipe with its reagent
-- slots set to the highest-quality choice, or nil if CraftSim isn't ready, no order/recipe
-- is currently loaded on the form, or construction fails for any reason.
---@return table? recipeData
---@return boolean? allRequiredResolved False if a required reagent slot had no confident
---   pick -- see OrderReagents.lua's GetBestQualityReagentEntries. The returned recipeData
---   still reflects whatever slots *did* resolve; callers should treat it as incomplete
---   rather than discard it outright, since the player may still want to see what's known.
---   nil (not false) when recipeData itself is nil -- there's nothing to qualify.
function OrderScreen:BuildRecipeData()
    if not (CraftSimAPI and CraftSimAPI.GetRecipeData) then
        return nil
    end

    local form = self.form
    local transaction = form and form.transaction
    if not transaction then
        return nil
    end

    local ok, recipeID, schematicInfo, isRecraft = pcall(function()
        return transaction:GetRecipeID(), transaction:GetRecipeSchematic(), transaction:IsRecraft()
    end)
    if not ok or not recipeID or not schematicInfo then
        return nil
    end

    local constructOk, recipeData = pcall(CraftSimAPI.GetRecipeData, CraftSimAPI, {
        recipeID = recipeID,
        isRecraft = isRecraft,
    })
    if not constructOk or not recipeData then
        return nil
    end

    local reagentEntries, allRequiredResolved = self:GetBestQualityReagentEntries(schematicInfo)
    local craftingReagentInfoTbl = {}
    for _, entry in ipairs(reagentEntries) do
        table.insert(craftingReagentInfoTbl, { reagent = { itemID = entry.itemID }, quantity = entry.quantity })
    end

    local setOk = pcall(recipeData.SetReagentsByCraftingReagentInfoTbl, recipeData, craftingReagentInfoTbl)
    if not setOk then
        return nil
    end

    return recipeData, allRequiredResolved
end
