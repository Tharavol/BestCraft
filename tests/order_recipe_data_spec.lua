-- order_recipe_data_spec.lua
-- SPDX-License-Identifier: MIT
--
-- Only the defensive fail-to-nil paths are covered here. Actually constructing a
-- CraftSim.RecipeData needs CraftSim's real classes (professionData, reagentData, the
-- Blizzard API they wrap) -- faking that convincingly would test the fake, not the code.
-- See docs/craftsim-recipedata-notes.md; the happy path needs an in-game check instead.

return function(stub, T)
    T.Test("returns nil when CraftSim isn't loaded", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without CraftSim")
    end)

    T.Test("returns nil when the order screen's Form hasn't been found yet", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.env.CraftSim = { RecipeData = function() error("should not be called") end }
        T.AssertEqual(loaded.ns.OrderScreen.form, nil, "sanity check: no form yet")
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without a Form")
    end)

    T.Test("returns nil when the transaction can't produce a recipeID", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.env.CraftSim = { RecipeData = function() error("should not be called") end }
        loaded.ns.OrderScreen.form = {
            transaction = {
                GetRecipeID = function() return nil end,
                GetRecipeSchematic = function() return { reagentSlotSchematics = {} } end,
                IsRecraft = function() return false end,
            },
        }
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without a recipeID")
    end)
end
