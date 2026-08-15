-- order_recipe_data_spec.lua
-- SPDX-License-Identifier: MIT
--
-- Only the defensive fail-to-nil paths are covered here. Actually constructing a
-- CraftSim.RecipeData needs CraftSim's real classes (professionData, reagentData, the
-- Blizzard API they wrap) -- faking that convincingly would test the fake, not the code.
-- See docs/craftsim-recipedata-notes.md; the happy path needs an in-game check instead.

return function(stub, T)
    T.Test("returns nil when CraftSimAPI isn't available", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without CraftSimAPI")
    end)

    T.Test("returns nil when the order screen's Form hasn't been found yet", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.env.CraftSimAPI = { GetRecipeData = function() error("should not be called") end }
        T.AssertEqual(loaded.ns.OrderScreen.form, nil, "sanity check: no form yet")
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without a Form")
    end)

    T.Test("returns nil when the transaction can't produce a recipeID", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.env.CraftSimAPI = { GetRecipeData = function() error("should not be called") end }
        loaded.ns.OrderScreen.form = {
            transaction = {
                GetRecipeID = function() return nil end,
                GetRecipeSchematic = function() return { reagentSlotSchematics = {} } end,
                IsRecraft = function() return false end,
            },
        }
        T.AssertEqual(loaded.ns.OrderScreen:BuildRecipeData(), nil, "expected nil without a recipeID")
    end)

    T.Test("constructs without orderData and applies reagents via SetReagentsByCraftingReagentInfoTbl", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })

        local getRecipeDataArgs
        local setReagentsArgs
        -- Forward-declared: a local's scope only begins after its whole `local x = ...`
        -- statement, so a `mockRecipeData` referenced *inside* that same initializer would
        -- resolve to an outer/global mockRecipeData (nil here), not this table.
        local mockRecipeData
        mockRecipeData = {
            SetReagentsByCraftingReagentInfoTbl = function(self, tbl)
                T.AssertEqual(self, mockRecipeData, "expected method call, self bound correctly")
                setReagentsArgs = tbl
            end,
        }
        loaded.env.CraftSimAPI = {
            GetRecipeData = function(_, options)
                getRecipeDataArgs = options
                return mockRecipeData
            end,
        }

        loaded.ns.OrderScreen.form = {
            transaction = {
                GetRecipeID = function() return 12345 end,
                GetRecipeSchematic = function()
                    return {
                        reagentSlotSchematics = {
                            {
                                dataSlotIndex = 1, required = true, quantityRequired = 20,
                                reagents = { { itemID = 111 } },
                            },
                        },
                    }
                end,
                IsRecraft = function() return false end,
            },
        }

        local result, allRequiredResolved = loaded.ns.OrderScreen:BuildRecipeData()

        T.AssertEqual(result, mockRecipeData, "expected the constructed RecipeData to be returned")
        T.AssertTrue(allRequiredResolved, "expected true -- the only slot resolved")
        T.AssertEqual(getRecipeDataArgs.recipeID, 12345, "expected recipeID passed to GetRecipeData")
        T.AssertEqual(getRecipeDataArgs.orderData, nil, "expected no orderData -- see the RecipeData notes doc")
        T.AssertEqual(getRecipeDataArgs.isRecraft, false, "expected isRecraft passed through")
        T.AssertEqual(#setReagentsArgs, 1, "expected one reagent entry")
        T.AssertEqual(setReagentsArgs[1].reagent.itemID, 111, "expected itemID nested under .reagent")
        T.AssertEqual(setReagentsArgs[1].quantity, 20, "expected quantityRequired carried through")
    end)

    T.Test("reports allRequiredResolved=false when a required slot has no confident pick", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })

        local mockRecipeData = { SetReagentsByCraftingReagentInfoTbl = function() end }
        loaded.env.CraftSimAPI = { GetRecipeData = function() return mockRecipeData end }

        loaded.ns.OrderScreen.form = {
            transaction = {
                GetRecipeID = function() return 12345 end,
                GetRecipeSchematic = function()
                    return {
                        reagentSlotSchematics = {
                            {
                                dataSlotIndex = 1, required = true, quantityRequired = 1,
                                reagents = { { itemID = 301 }, { itemID = 302 } },
                            },
                        },
                    }
                end,
                IsRecraft = function() return false end,
            },
        }

        local result, allRequiredResolved = loaded.ns.OrderScreen:BuildRecipeData()

        T.AssertEqual(result, mockRecipeData, "expected the constructed RecipeData still returned")
        T.AssertFalse(allRequiredResolved, "expected false -- the required slot had no confident pick")
    end)
end
