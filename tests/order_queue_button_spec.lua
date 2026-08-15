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

-- A required slot with no confident pick (multiple options, none reporting a quality tier) --
-- see issue #4: this must never silently produce a partial recipeData/shopping list.
local function BuildUnresolvedSchematic()
    return {
        reagentSlotSchematics = {
            {
                dataSlotIndex = 1, required = true, quantityRequired = 1,
                reagents = { { itemID = 301 }, { itemID = 302 } },
            },
        },
    }
end

local function BuildFakeForm(stub, isRecraft, schematicFn)
    local form = stub.MakeFrame()
    form.TrackRecipeCheckbox = stub.MakeFrame()
    form.transaction = {
        GetRecipeID = function() return 12345 end,
        GetRecipeSchematic = schematicFn or BuildSchematic,
        IsRecraft = function() return isRecraft == true end,
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

    T.Test("disables the button when the recipe isn't queueable", function()
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

    T.Test("shows the shopping-list label and disables without Auctionator, on a recraft order", function()
        local fakeForm = BuildFakeForm(stub, true)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertEqual(button:GetText(), "+ Shopping List", "expected the recraft label")
        T.AssertFalse(button:IsEnabled(), "expected disabled without Auctionator")
    end)

    T.Test("enables the recraft button when Auctionator is available and reagents exist", function()
        local fakeForm = BuildFakeForm(stub, true)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                Auctionator = { API = { v1 = {
                    ConvertToSearchString = function(_, term) return term.searchString end,
                    CreateShoppingList = function() end,
                } } },
            },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button:IsEnabled(), "expected enabled with Auctionator and reagents present")
    end)

    T.Test("clicking the recraft button creates a shopping list instead of calling AddRecipe", function()
        local fakeForm = BuildFakeForm(stub, true)
        local createCalls = {}
        local craftQueueTouched = false
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                Auctionator = { API = { v1 = {
                    ConvertToSearchString = function(_, term) return term.searchString end,
                    CreateShoppingList = function(_, _, searchStrings) table.insert(createCalls, searchStrings) end,
                } } },
                -- Present to prove the recraft path never touches it, per
                -- CraftSim.CRAFTQ:IsRecipeQueueable rejecting recraft recipes outright.
                CraftSimAPI = {
                    GetRecipeData = function() craftQueueTouched = true end,
                    GetCraftSim = function() craftQueueTouched = true end,
                },
            },
        })

        local button = loaded.frames[#loaded.frames]
        button:FireScript("OnClick")

        T.AssertEqual(#createCalls, 1, "expected one shopping list created")
        T.AssertFalse(craftQueueTouched, "expected the CraftQueue path never touched for a recraft order")
    end)

    T.Test("disables the queue button when a required reagent has no confident pick", function()
        local fakeForm = BuildFakeForm(stub, false, BuildUnresolvedSchematic)
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
        T.AssertFalse(button:IsEnabled(),
            "expected disabled despite a queueable recipe -- a required reagent is unresolved")

        button:FireScript("OnClick")
        T.AssertEqual(#addRecipeCalls, 0, "expected no AddRecipe call while a required reagent is unresolved")
    end)

    T.Test("disables the recraft button when a required reagent has no confident pick", function()
        local fakeForm = BuildFakeForm(stub, true, BuildUnresolvedSchematic)
        local createCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            itemNames = { [301] = "Option A", [302] = "Option B" },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                Auctionator = { API = { v1 = {
                    ConvertToSearchString = function(_, term) return term.searchString end,
                    CreateShoppingList = function(_, _, searchStrings) table.insert(createCalls, searchStrings) end,
                } } },
            },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(),
            "expected disabled with Auctionator available -- a required reagent is unresolved")

        button:FireScript("OnClick")
        T.AssertEqual(#createCalls, 0, "expected no shopping list created while a required reagent is unresolved")
    end)
end
