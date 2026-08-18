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

-- Was `loaded.frames[#loaded.frames]` (the last frame created during LoadAddon) until issue
-- #21 added a module (OrderShoppingPurchases.lua) that creates its own frame for an event
-- listener, loading after this one -- which broke the "the button is always last" coincidence
-- these tests relied on. Found by label instead, which stays correct regardless of what any
-- later-loading module creates.
local function FindButton(loaded)
    for i = #loaded.frames, 1, -1 do
        local frame = loaded.frames[i]
        if frame.GetText and frame:GetText() == loaded.ns.L.BUTTON_LABEL then
            return frame
        end
    end
    return nil
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

        local button = FindButton(loaded)
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
        local button = FindButton(loaded)
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
        local button = FindButton(loaded)
        T.AssertTrue(button:IsEnabled(), "expected enabled with Auctionator and reagents present")
    end)

    T.Test("hides the button entirely when buttonEnabled is off, rather than graying it out", function()
        local fakeForm = BuildFakeForm(stub)
        fakeForm.UpdateReagentSlots = function() end
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = FindButton(loaded)
        T.AssertTrue(button:IsShown(), "sanity: shown by default")

        loaded.ns.db.settings.buttonEnabled = false
        fakeForm:UpdateReagentSlots()

        T.AssertFalse(button:IsShown(), "expected hidden -- per feedback, not just disabled")
    end)

    T.Test("re-shows the button once buttonEnabled is turned back on", function()
        local fakeForm = BuildFakeForm(stub)
        fakeForm.UpdateReagentSlots = function() end
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = FindButton(loaded)

        loaded.ns.db.settings.buttonEnabled = false
        fakeForm:UpdateReagentSlots()
        T.AssertFalse(button:IsShown(), "sanity: hidden while off")

        loaded.ns.db.settings.buttonEnabled = true
        fakeForm:UpdateReagentSlots()
        T.AssertTrue(button:IsShown(), "expected shown again once re-enabled")
    end)

    T.Test("unchecking buttonEnabled in the options panel hides the button immediately", function()
        -- No fakeForm.UpdateReagentSlots hook here, deliberately -- confirmed in-game that the
        -- button didn't update until the order window was closed and reopened, i.e. the order
        -- screen's own OnShow/UpdateReagentSlots events (which this test never fires) weren't
        -- what was supposed to drive this refresh in the first place.
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = FindButton(loaded)
        T.AssertTrue(button:IsShown(), "sanity: shown by default")

        local checkbox
        for _, entry in ipairs(loaded.ns.Options.panel.checkboxes) do
            if entry.key == "buttonEnabled" then checkbox = entry.checkbox end
        end
        checkbox:SetChecked(false)
        checkbox:FireScript("OnClick")

        T.AssertFalse(button:IsShown(), "expected the options-panel checkbox to hide the button directly")
    end)

    T.Test("tooltip explains the button when enabled", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = FindButton(loaded)
        button:FireScript("OnEnter")

        T.AssertEqual(#loaded.api.tooltipLines, 1, "expected one tooltip line")
        T.AssertEqual(loaded.api.tooltipLines[1].kind, "Normal", "expected a Normal line, not an error")
    end)

    T.Test("tooltip explains why the button is disabled without Auctionator", function()
        local fakeForm = BuildFakeForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            reagentQualities = { [111] = 2 },
            itemNames = { [111] = "Some Reagent" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        local button = FindButton(loaded)
        button:FireScript("OnEnter")

        T.AssertEqual(#loaded.api.tooltipLines, 1, "expected one tooltip line")
        T.AssertEqual(loaded.api.tooltipLines[1].kind, "Error", "expected an Error line")
        T.AssertTrue(loaded.api.tooltipLines[1].text:find("Auctionator") ~= nil,
            "expected the Auctionator-related reason")
    end)

    T.Test("tooltip explains why the button is disabled when a required reagent is unresolved", function()
        local fakeForm = BuildFakeForm(stub, false, BuildUnresolvedSchematic)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            itemNames = { [301] = "Option A", [302] = "Option B" },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm }, Auctionator = AuctionatorGlobal() },
        })
        local button = FindButton(loaded)
        button:FireScript("OnEnter")

        T.AssertEqual(loaded.api.tooltipLines[1].kind, "Error", "expected an Error line")
        T.AssertTrue(loaded.api.tooltipLines[1].text:find("required") ~= nil,
            "expected the unresolved-required-reagent reason")
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

        local button = FindButton(loaded)
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

        local button = FindButton(loaded)
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

            local button = FindButton(loaded)
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

        local button = FindButton(loaded)
        T.AssertFalse(button:IsEnabled(),
            "expected disabled with Auctionator available -- a required reagent is unresolved")

        button:FireScript("OnClick")
        T.AssertEqual(#createCalls, 0, "expected no shopping list created while a required reagent is unresolved")
    end)
end
