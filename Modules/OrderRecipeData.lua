-- OrderRecipeData.lua
-- SPDX-License-Identifier: MIT
--
-- Builds a CraftSim.RecipeData for the order screen's current recipe, with its reagent
-- slots pre-filled to the highest-quality choice from OrderReagents.lua. Relies on
-- CraftSim.RecipeData:SetOrder() (via the `orderData` constructor option) to apply those
-- choices itself -- see docs/craftsim-recipedata-notes.md for why that's CraftSim's own
-- tested path for customer-provided order reagents, not something reimplemented here.
--
-- Goes through CraftSimAPI:GetRecipeData(), not CraftSim.RecipeData directly -- CraftSim's
-- internal addon table is never published as a global (confirmed in-game: `CraftSim` reads
-- as nil from another addon's context), only CraftSimAPI (Util/API.lua) is, and its
-- GetRecipeData wraps the exact same constructor options.
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

    local reagentEntries = self:GetBestQualityReagentEntries(schematicInfo)

    local constructOk, recipeData = pcall(CraftSimAPI.GetRecipeData, CraftSimAPI, {
        recipeID = recipeID,
        orderData = {
            reagents = reagentEntries,
            isRecraft = isRecraft,
        },
    })

    if not constructOk or not recipeData then
        return nil
    end

    return recipeData
end
