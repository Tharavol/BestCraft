-- order_shopping_list_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later

local function BuildFakeForm(stub, schematic)
    local form = stub.MakeFrame()
    form.TrackRecipeCheckbox = stub.MakeFrame()
    form.transaction = {
        GetRecipeID = function() return 999 end,
        GetRecipeSchematic = function() return schematic end,
    }
    return form
end

local ONE_SLOT_SCHEMATIC = {
    reagentSlotSchematics = {
        { dataSlotIndex = 1, required = true, quantityRequired = 3, reagents = { { itemID = 111 } } },
    },
}

return function(stub, T)
    T.Test("IsAuctionatorAvailable is false when Auctionator isn't present", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        T.AssertFalse(loaded.ns.OrderScreen:IsAuctionatorAvailable(), "expected false without Auctionator")
    end)

    T.Test("GetShoppingEntries returns nil without a form", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        T.AssertEqual(loaded.ns.OrderScreen:GetShoppingEntries(), nil, "expected nil without a form")
    end)

    T.Test("GetShoppingEntries reads the current schematic", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local entries = loaded.ns.OrderScreen:GetShoppingEntries()
        T.AssertEqual(#entries, 1, "expected one entry")
        T.AssertEqual(entries[1].itemID, 111, "expected the schematic's itemID")
        T.AssertEqual(entries[1].quantity, 3, "expected the schematic's quantityRequired")
    end)

    local RANKED_SCHEMATIC = {
        reagentSlotSchematics = {
            {
                dataSlotIndex = 1, required = true, quantityRequired = 5,
                reagents = { { itemID = 201 }, { itemID = 202 } },
            },
        },
    }

    T.Test("GetShoppingEntries prefers lowest quality when the recipe's output has no real tier",
        function()
            local loaded = stub.LoadAddon(".", "BestCraft.toc", {
                addonsLoaded = { Auctionator = true },
                reagentQualities = { [201] = 2, [202] = 3 },
            })
            local form = BuildFakeForm(stub, RANKED_SCHEMATIC)
            form.minQualityIDs = { 4 } -- length 1: only the "None" placeholder, no real tier
            loaded.ns.OrderScreen.form = form

            local entries = loaded.ns.OrderScreen:GetShoppingEntries()

            T.AssertEqual(entries[1].itemID, 201, "expected the lower-quality reagent")
        end)

    T.Test("GetShoppingEntries prefers highest quality when the recipe's output has real tiers",
        function()
            local loaded = stub.LoadAddon(".", "BestCraft.toc", {
                addonsLoaded = { Auctionator = true },
                reagentQualities = { [201] = 2, [202] = 3 },
            })
            local form = BuildFakeForm(stub, RANKED_SCHEMATIC)
            form.minQualityIDs = { 4, 5, 6, 7, 8 } -- real tiers beyond the None placeholder
            loaded.ns.OrderScreen.form = form

            local entries = loaded.ns.OrderScreen:GetShoppingEntries()

            T.AssertEqual(entries[1].itemID, 202, "expected the higher-quality reagent")
        end)

    T.Test("GetShoppingEntries prefers lowest quality when minQualityIDs is nil", function()
        -- Confirmed in-game (issue #19) that C_TradeSkillUI.GetQualitiesForRecipe returns nil,
        -- not a length-1 table, for a recipe with no real quality tier -- nil means "confirmed
        -- no tier," the same as length <= 1, not "not yet known."
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            reagentQualities = { [201] = 2, [202] = 3 },
        })
        local form = BuildFakeForm(stub, RANKED_SCHEMATIC)
        form.minQualityIDs = nil
        loaded.ns.OrderScreen.form = form

        local entries = loaded.ns.OrderScreen:GetShoppingEntries()

        T.AssertEqual(entries[1].itemID, 201, "expected the lower-quality reagent")
    end)

    T.Test("CreateShoppingList fails with a message when Auctionator isn't available", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil and message:find("Auctionator") ~= nil, "expected an Auctionator-related message")
    end)

    T.Test("CreateShoppingList fails with a message when there are no reagents to shop for", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            presetGlobals = { Auctionator = { API = { v1 = {} } } },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, { reagentSlotSchematics = {} })
        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil, "expected a message")
    end)

    T.Test("CreateShoppingList fails with a message when a required reagent can't be resolved", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            presetGlobals = { Auctionator = { API = { v1 = {} } } },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 1, required = true, quantityRequired = 1,
                    reagents = { { itemID = 301 }, { itemID = 302 } },
                },
            },
        })
        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil and message:find("required") ~= nil, "expected a required-reagent message")
    end)

    T.Test("CreateShoppingList fails with a message when item names can't be resolved", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            presetGlobals = { Auctionator = { API = { v1 = {} } } },
            itemNames = {}, -- itemID 111 deliberately not resolvable
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil, "expected a message")
    end)

    T.Test("CreateShoppingList builds search strings and creates the list, named BestCraft", function()
        local convertCalls = {}
        local createCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            reagentQualities = { [111] = 3 },
            itemNames = { [111] = "Glimmering Gemdust" },
            presetGlobals = {
                Auctionator = {
                    API = {
                        v1 = {
                            ConvertToSearchString = function(addonName, term)
                                table.insert(convertCalls, { addonName = addonName, term = term })
                                return "search:" .. term.searchString
                            end,
                            CreateShoppingList = function(addonName, listName, searchStrings)
                                table.insert(createCalls, {
                                    addonName = addonName, listName = listName, searchStrings = searchStrings,
                                })
                            end,
                        },
                    },
                    -- No Shopping.ListManager here: exercises the "no existing list to
                    -- delete" branch (Shopping/ListManager absent entirely, not just empty).
                },
            },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)

        local ok = loaded.ns.OrderScreen:CreateShoppingList()

        T.AssertTrue(ok, "expected success")
        T.AssertEqual(#convertCalls, 1, "expected one ConvertToSearchString call")
        T.AssertEqual(convertCalls[1].addonName, "BestCraft", "expected the addon name passed through")
        T.AssertEqual(convertCalls[1].term.searchString, "Glimmering Gemdust", "expected the resolved item name")
        T.AssertEqual(convertCalls[1].term.tier, 3, "expected the reagent quality passed as tier")
        T.AssertEqual(convertCalls[1].term.quantity, 3, "expected the schematic's quantityRequired")
        T.AssertEqual(#createCalls, 1, "expected one CreateShoppingList call")
        T.AssertEqual(createCalls[1].listName, "BestCraft",
            "expected a single unified list name, not the old recraft-specific one")
        T.AssertEqual(createCalls[1].searchStrings[1], "search:Glimmering Gemdust",
            "expected the converted search string in the list")
    end)

    T.Test("CreateShoppingList's success message names the recipe and materials added", function()
        local schematic = {
            name = "Thalassian Alchemy Coveralls",
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
                { dataSlotIndex = 2, required = true, quantityRequired = 1, reagents = { { itemID = 222 } } },
            },
        }
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality", [222] = "Kaleidoscopic Prism" },
            presetGlobals = {
                Auctionator = { API = { v1 = {
                    ConvertToSearchString = function(_, term) return term.searchString end,
                    CreateShoppingList = function() end,
                } } },
            },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, schematic)

        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()

        T.AssertTrue(ok, "expected success")
        T.AssertTrue(message:find("Thalassian Alchemy Coveralls", 1, true) ~= nil,
            "expected the recipe name in the confirmation")
        T.AssertTrue(message:find("Fused Vitality [x20]", 1, true) ~= nil,
            "expected the first material and quantity")
        T.AssertTrue(message:find("Kaleidoscopic Prism [x1]", 1, true) ~= nil,
            "expected the second material and quantity")
    end)

    T.Test("CreateShoppingList's success message falls back gracefully when the recipe has no name",
        function()
            local loaded = stub.LoadAddon(".", "BestCraft.toc", {
                addonsLoaded = { Auctionator = true },
                reagentQualities = { [111] = 3 },
                itemNames = { [111] = "Glimmering Gemdust" },
                presetGlobals = {
                    Auctionator = { API = { v1 = {
                        ConvertToSearchString = function(_, term) return term.searchString end,
                        CreateShoppingList = function() end,
                    } } },
                },
            })
            loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC) -- no .name field

            local ok, message = loaded.ns.OrderScreen:CreateShoppingList()

            T.AssertTrue(ok, "expected success")
            T.AssertTrue(message ~= nil and message ~= "", "expected a message even without a recipe name")
        end)

    T.Test("CreateShoppingList's success message notes vendor-purchasable reagents skipped", function()
        local schematic = {
            name = "Thalassian Treatise on Enchanting",
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 1, reagents = { { itemID = 111 } } },
                { dataSlotIndex = 2, required = true, quantityRequired = 1, reagents = { { itemID = 245881 } } },
            },
        }
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality", [245881] = "Lexicologist's Vellum" },
            itemTooltipLines = {
                [245881] = { "Lexicologist's Vellum", "Crafting Reagent",
                    "A parchment frequently used by Scribes. Can be purchased from vendors." },
            },
            presetGlobals = {
                Auctionator = { API = { v1 = {
                    ConvertToSearchString = function(_, term) return term.searchString end,
                    CreateShoppingList = function() end,
                } } },
            },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, schematic)

        local ok, message = loaded.ns.OrderScreen:CreateShoppingList()

        T.AssertTrue(ok, "expected success -- the non-vendor reagent still has an entry")
        T.AssertTrue(message:find("Fused Vitality", 1, true) ~= nil, "expected the shopped reagent named")
        T.AssertTrue(message:find("Skipped Lexicologist's Vellum", 1, true) ~= nil,
            "expected the vendor-skipped reagent named and why")
    end)

    T.Test("CreateShoppingList fails with a vendor-skip note when the only reagent is vendor-purchasable",
        function()
            local loaded = stub.LoadAddon(".", "BestCraft.toc", {
                addonsLoaded = { Auctionator = true },
                itemTooltipLines = {
                    [245881] = { "Lexicologist's Vellum", "Crafting Reagent",
                        "A parchment frequently used by Scribes. Can be purchased from vendors." },
                },
                presetGlobals = { Auctionator = { API = { v1 = {} } } },
            })
            loaded.ns.OrderScreen.form = BuildFakeForm(stub, {
                reagentSlotSchematics = {
                    { dataSlotIndex = 1, required = true, quantityRequired = 1, reagents = { { itemID = 245881 } } },
                },
            })

            local ok, message = loaded.ns.OrderScreen:CreateShoppingList()

            T.AssertFalse(ok, "expected failure -- nothing left to shop for")
            T.AssertTrue(message ~= nil and message:find("Skipped", 1, true) ~= nil,
                "expected the vendor-skip reason even though the list itself is empty")
        end)

    T.Test("CreateShoppingList deletes an existing list under the same name first", function()
        local deleteCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            reagentQualities = { [111] = 3 },
            itemNames = { [111] = "Glimmering Gemdust" },
            presetGlobals = {
                Auctionator = {
                    API = {
                        v1 = {
                            ConvertToSearchString = function(_, term) return term.searchString end,
                            CreateShoppingList = function() end,
                        },
                    },
                    Shopping = {
                        ListManager = {
                            GetIndexForName = function() return 1 end,
                            Delete = function(_, listName) table.insert(deleteCalls, listName) end,
                        },
                    },
                },
            },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)

        loaded.ns.OrderScreen:CreateShoppingList()

        T.AssertEqual(#deleteCalls, 1, "expected the existing list to be deleted first")
        T.AssertEqual(deleteCalls[1], "BestCraft", "expected the unified list name deleted")
    end)
end
