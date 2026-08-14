-- order_queue_button_spec.lua
-- SPDX-License-Identifier: MIT
--
-- Tests BestCraft's own glue (button creation/anchoring, enabled-state gating, the click
-- handler's calls into CraftSim.CRAFTQ) against a mocked CraftSimAPI/CraftQueue. Unlike
-- OrderRecipeData's happy path, this doesn't need CraftSim's real classes -- IsRecipeQueueable
-- and AddRecipe are called on whatever object CraftSimAPI:GetCraftSim().CRAFTQ resolves to,
-- so a plain mock table is a faithful enough stand-in for what this addon's own code does
-- with it.

local function BuildSchematic()
    return {
        reagentSlotSchematics = {
            { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
        },
    }
end

local function BuildFakeForm(stub)
    local form = stub.MakeFrame()
    form.TrackRecipeCheckbox = stub.MakeFrame()
    form.transaction = {
        GetRecipeID = function() return 12345 end,
        GetRecipeSchematic = BuildSchematic,
        IsRecraft = function() return false end,
    }
    return form
end

return function(stub, T)
    T.Test("creates a button anchored to the Form's TrackRecipeCheckbox", function()
        local fakeForm = BuildFakeForm(stub)
        -- Forward-declared for the same reason as order_recipe_data_spec.lua's mock: a
        -- self-referencing initializer would capture a stray outer/global instead of this
        -- table.
        local mockRecipeData
        mockRecipeData = { isRecraft = false, SetReagentsByCraftingReagentInfoTbl = function() end }
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                CraftSimAPI = {
                    GetRecipeData = function() return mockRecipeData end,
                    GetCraftSim = function()
                        return { CRAFTQ = { IsRecipeQueueable = function() return true end } }
                    end,
                },
            },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button ~= nil, "expected a button frame to have been created")
        T.AssertEqual(button:GetText(), "+ CraftQueue", "expected the button's label")
        T.AssertEqual(button._point[2], fakeForm.TrackRecipeCheckbox,
            "expected the button anchored to TrackRecipeCheckbox")
    end)

    T.Test("disables the button when CraftSimAPI isn't available", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(), "expected the button disabled without CraftSimAPI")
    end)

    T.Test("disables the button when the recipe isn't queueable (e.g. recraft)", function()
        local fakeForm = BuildFakeForm(stub)
        local mockRecipeData
        mockRecipeData = { isRecraft = true, SetReagentsByCraftingReagentInfoTbl = function() end }
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                CraftSimAPI = {
                    GetRecipeData = function() return mockRecipeData end,
                    GetCraftSim = function()
                        return { CRAFTQ = { IsRecipeQueueable = function(_, rd) return not rd.isRecraft end } }
                    end,
                },
            },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(), "expected the button disabled for a non-queueable recipe")
    end)

    T.Test("enables the button and clicking it calls CRAFTQ:AddRecipe", function()
        local fakeForm = BuildFakeForm(stub)
        local mockRecipeData
        mockRecipeData = { isRecraft = false, SetReagentsByCraftingReagentInfoTbl = function() end }
        local addRecipeCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                CraftSimAPI = {
                    GetRecipeData = function() return mockRecipeData end,
                    GetCraftSim = function()
                        return {
                            CRAFTQ = {
                                IsRecipeQueueable = function() return true end,
                                AddRecipe = function(_, options) table.insert(addRecipeCalls, options) end,
                            },
                        }
                    end,
                },
            },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button:IsEnabled(), "expected the button enabled for a queueable recipe")

        button:FireScript("OnClick")

        T.AssertEqual(#addRecipeCalls, 1, "expected exactly one AddRecipe call")
        T.AssertEqual(addRecipeCalls[1].recipeData, mockRecipeData, "expected the built recipeData passed through")
    end)

    T.Test("clicking a non-queueable recipe does not call AddRecipe", function()
        local fakeForm = BuildFakeForm(stub)
        local mockRecipeData
        mockRecipeData = { isRecraft = true, SetReagentsByCraftingReagentInfoTbl = function() end }
        local addRecipeCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                CraftSimAPI = {
                    GetRecipeData = function() return mockRecipeData end,
                    GetCraftSim = function()
                        return {
                            CRAFTQ = {
                                IsRecipeQueueable = function() return false end,
                                AddRecipe = function(_, options) table.insert(addRecipeCalls, options) end,
                            },
                        }
                    end,
                },
            },
        })

        local button = loaded.frames[#loaded.frames]
        button:FireScript("OnClick")

        T.AssertEqual(#addRecipeCalls, 0, "expected no AddRecipe call for a non-queueable recipe")
    end)

    T.Test("re-checks enabled state when the Form's UpdateReagentSlots runs", function()
        local fakeForm = BuildFakeForm(stub)
        local queueable = false
        local mockRecipeData
        mockRecipeData = { isRecraft = false, SetReagentsByCraftingReagentInfoTbl = function() end }
        fakeForm.UpdateReagentSlots = function() end

        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                CraftSimAPI = {
                    GetRecipeData = function() return mockRecipeData end,
                    GetCraftSim = function()
                        return { CRAFTQ = { IsRecipeQueueable = function() return queueable end } }
                    end,
                },
            },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(), "expected disabled before the recipe became queueable")

        queueable = true
        fakeForm:UpdateReagentSlots()

        T.AssertTrue(button:IsEnabled(), "expected enabled after UpdateReagentSlots re-checked state")
    end)
end
