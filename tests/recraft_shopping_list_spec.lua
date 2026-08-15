-- recraft_shopping_list_spec.lua
-- SPDX-License-Identifier: MIT

local function BuildFakeForm(stub, schematic)
    local form = stub.MakeFrame()
    form.TrackRecipeCheckbox = stub.MakeFrame()
    form.transaction = {
        GetRecipeID = function() return 999 end,
        GetRecipeSchematic = function() return schematic end,
        IsRecraft = function() return true end,
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
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        T.AssertFalse(loaded.ns.OrderScreen:IsAuctionatorAvailable(), "expected false without Auctionator")
    end)

    T.Test("GetRecraftShoppingEntries returns nil without a form", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        T.AssertEqual(loaded.ns.OrderScreen:GetRecraftShoppingEntries(), nil, "expected nil without a form")
    end)

    T.Test("GetRecraftShoppingEntries reads the current schematic", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local entries = loaded.ns.OrderScreen:GetRecraftShoppingEntries()
        T.AssertEqual(#entries, 1, "expected one entry")
        T.AssertEqual(entries[1].itemID, 111, "expected the schematic's itemID")
        T.AssertEqual(entries[1].quantity, 3, "expected the schematic's quantityRequired")
    end)

    T.Test("CreateRecraftShoppingList fails with a message when Auctionator isn't available", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local ok, message = loaded.ns.OrderScreen:CreateRecraftShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil and message:find("Auctionator") ~= nil, "expected an Auctionator-related message")
    end)

    T.Test("CreateRecraftShoppingList fails with a message when there are no reagents to shop for", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true },
            presetGlobals = { Auctionator = { API = { v1 = {} } } },
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, { reagentSlotSchematics = {} })
        local ok, message = loaded.ns.OrderScreen:CreateRecraftShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil, "expected a message")
    end)

    T.Test("CreateRecraftShoppingList fails with a message when a required reagent can't be resolved", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true },
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
        local ok, message = loaded.ns.OrderScreen:CreateRecraftShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil and message:find("required") ~= nil, "expected a required-reagent message")
    end)

    T.Test("CreateRecraftShoppingList fails with a message when item names can't be resolved", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true },
            presetGlobals = { Auctionator = { API = { v1 = {} } } },
            itemNames = {}, -- itemID 111 deliberately not resolvable
        })
        loaded.ns.OrderScreen.form = BuildFakeForm(stub, ONE_SLOT_SCHEMATIC)
        local ok, message = loaded.ns.OrderScreen:CreateRecraftShoppingList()
        T.AssertFalse(ok, "expected failure")
        T.AssertTrue(message ~= nil, "expected a message")
    end)

    T.Test("CreateRecraftShoppingList builds search strings and creates the list", function()
        local convertCalls = {}
        local createCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true },
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

        local ok = loaded.ns.OrderScreen:CreateRecraftShoppingList()

        T.AssertTrue(ok, "expected success")
        T.AssertEqual(#convertCalls, 1, "expected one ConvertToSearchString call")
        T.AssertEqual(convertCalls[1].addonName, "BestCraft", "expected the addon name passed through")
        T.AssertEqual(convertCalls[1].term.searchString, "Glimmering Gemdust", "expected the resolved item name")
        T.AssertEqual(convertCalls[1].term.tier, 3, "expected the reagent quality passed as tier")
        T.AssertEqual(convertCalls[1].term.quantity, 3, "expected the schematic's quantityRequired")
        T.AssertEqual(#createCalls, 1, "expected one CreateShoppingList call")
        T.AssertEqual(createCalls[1].searchStrings[1], "search:Glimmering Gemdust",
            "expected the converted search string in the list")
    end)

    T.Test("CreateRecraftShoppingList deletes an existing list under the same name first", function()
        local deleteCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true },
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

        loaded.ns.OrderScreen:CreateRecraftShoppingList()

        T.AssertEqual(#deleteCalls, 1, "expected the existing list to be deleted first")
    end)
end
