-- order_shopping_button_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Tests BestCraft's own glue (button creation/anchoring, enabled-state gating, the click
-- handler's call into OrderShoppingList.lua) against a mocked Auctionator.API.v1. One path for
-- every order now (recraft or not) -- see OrderShoppingButton.lua's header comment for why the
-- earlier CraftSim.CRAFTQ-based path was retired.

local function BuildSchematic()
    return {
        reagentSlotSchematics = {
            { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
        },
    }
end

-- A required slot with no confident pick (multiple options, none reporting a quality tier) --
-- see issue #4: this must never silently produce a partial shopping list.
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
    form.AllocateBestQualityCheckbox = stub.MakeFrame()
    form.order = { isRecraft = isRecraft == true }
    form.transaction = {
        GetRecipeID = function() return 12345 end,
        GetRecipeSchematic = schematicFn or BuildSchematic,
    }
    return form
end

local function AuctionatorGlobal(createCalls)
    return {
        API = {
            v1 = {
                ConvertToSearchString = function(_, term) return term.searchString end,
                CreateShoppingList = function(_, _, searchStrings)
                    table.insert(createCalls or {}, searchStrings)
                end,
            },
        },
    }
end

return function(stub, T)
    T.Test("creates a button anchored to the bottom-right of ProfessionsCustomerOrdersFrame", function()
        local fakeForm = BuildFakeForm(stub)
        -- A separate local, not an inline table literal, so the test can assert the button
        -- was anchored to this *exact* table (the whole window), not some other frame.
        local ordersFrame = { Form = fakeForm }
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = ordersFrame },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button ~= nil, "expected a button frame to have been created")
        T.AssertEqual(button:GetText(), "+ Shopping List", "expected the button's label")
        -- Mirrors Profession Shopping List's own "Core Alloy" button anchor exactly (see
        -- OrderShoppingButton.lua's header comment for the source this was confirmed against)
        -- -- anchored to the whole window, not .Form, which two earlier anchor attempts got
        -- wrong despite each passing their own reference-frame-only assertion at the time.
        T.AssertEqual(button._point[1], "BOTTOMRIGHT", "expected the button's own BOTTOMRIGHT point")
        T.AssertEqual(button._point[2], ordersFrame,
            "expected the button anchored to ProfessionsCustomerOrdersFrame itself, not .Form")
        T.AssertTrue(button._point[3] < 0, "expected a negative x offset, inset from the right edge")
        T.AssertEqual(button._point[4], 5, "expected the same y offset Core Alloy itself uses")
    end)

    T.Test("disables the button when Auctionator isn't available", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(), "expected disabled without Auctionator.API present")
    end)

    T.Test("enables the button when Auctionator is available and reagents exist", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button:IsEnabled(), "expected enabled with Auctionator and reagents present")
    end)

    T.Test("clicking the button creates a shopping list", function()
        local fakeForm = BuildFakeForm(stub)
        local createCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                Auctionator = AuctionatorGlobal(createCalls),
            },
        })

        local button = loaded.frames[#loaded.frames]
        button:FireScript("OnClick")

        T.AssertEqual(#createCalls, 1, "expected one shopping list created")
    end)

    T.Test("re-checks enabled state when the Form's UpdateReagentSlots runs", function()
        local fakeForm = BuildFakeForm(stub)
        fakeForm.UpdateReagentSlots = function() end

        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(), "expected disabled before Auctionator became available")

        loaded.env.Auctionator = AuctionatorGlobal()
        fakeForm:UpdateReagentSlots()

        T.AssertTrue(button:IsEnabled(), "expected enabled after UpdateReagentSlots re-checked state")
    end)

    T.Test("behaves the same for recraft and non-recraft orders", function()
        for _, isRecraft in ipairs({ false, true }) do
            local fakeForm = BuildFakeForm(stub, isRecraft)
            local createCalls = {}
            local loaded = stub.LoadAddon(".", "BestCraft.toc", {
                addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
                reagentQualities = { [111] = 2 },
                itemNames = { [111] = "Some Reagent" },
                presetGlobals = {
                    ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                    Auctionator = AuctionatorGlobal(createCalls),
                },
            })

            local button = loaded.frames[#loaded.frames]
            T.AssertEqual(button:GetText(), "+ Shopping List",
                "expected the same label regardless of isRecraft=" .. tostring(isRecraft))
            T.AssertTrue(button:IsEnabled(), "expected enabled regardless of isRecraft=" .. tostring(isRecraft))

            button:FireScript("OnClick")
            T.AssertEqual(#createCalls, 1,
                "expected a shopping list created regardless of isRecraft=" .. tostring(isRecraft))
        end
    end)

    T.Test("disables the button when a required reagent has no confident pick", function()
        local fakeForm = BuildFakeForm(stub, false, BuildUnresolvedSchematic)
        local createCalls = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            itemNames = { [301] = "Option A", [302] = "Option B" },
            presetGlobals = {
                ProfessionsCustomerOrdersFrame = { Form = fakeForm },
                Auctionator = AuctionatorGlobal(createCalls),
            },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertFalse(button:IsEnabled(),
            "expected disabled with Auctionator available -- a required reagent is unresolved")

        button:FireScript("OnClick")
        T.AssertEqual(#createCalls, 0, "expected no shopping list created while a required reagent is unresolved")
    end)
end
