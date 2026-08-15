-- order_shopping_button_spec.lua
-- SPDX-License-Identifier: MIT
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
    form.PaymentContainer = { ListOrderButton = stub.MakeFrame() }
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
    T.Test("creates a button anchored below the Form's PaymentContainer.ListOrderButton", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })

        local button = loaded.frames[#loaded.frames]
        T.AssertTrue(button ~= nil, "expected a button frame to have been created")
        T.AssertEqual(button:GetText(), "+ Shopping List", "expected the button's label")
        -- The full anchor tuple, not just the reference frame -- issue #18's in-game recon
        -- found two different anchor points that each passed a reference-frame-only
        -- assertion but still rendered wrong in practice (off-window, then overlapping a
        -- third-party addon's wider buttons in the same toolbar row).
        T.AssertEqual(button._point[1], "TOP", "expected the button's own TOP point")
        T.AssertEqual(button._point[2], fakeForm.PaymentContainer.ListOrderButton,
            "expected the button anchored to PaymentContainer.ListOrderButton")
        T.AssertEqual(button._point[3], "BOTTOM", "expected anchored to its BOTTOM")
        T.AssertTrue(button._point[5] < 0, "expected a negative y offset, growing downward")
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
