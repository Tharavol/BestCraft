-- order_minimum_quality_spec.lua
-- SPDX-License-Identifier: MIT

-- Mirrors stub_api.lua's env.Enum.CraftingOrderType -- this file runs outside the addon's
-- sandboxed environment, so it needs its own copy rather than reading the addon's global.
local CraftingOrderType = { Public = 0, Guild = 1, Personal = 2, Npc = 3 }

local function BuildForm(stub, overrides)
    local form = stub.MakeFrame()
    form.order = { spellID = 111, orderType = CraftingOrderType.Guild, minQuality = 1 }
    form.minQualityIDs = { 4, 5, 6, 7, 8 }
    form.committed = false
    for k, v in pairs(overrides or {}) do
        form[k] = v
    end
    return form
end

return function(stub, T)
    T.Test("sets the index to the last minQualityIDs entry on a Guild order", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub)
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 1, "expected one SetMinimumQualityIndex call")
        T.AssertEqual(setCalls[1], 5, "expected the last index (#minQualityIDs)")
    end)

    T.Test("does nothing on a Public order", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub,
            { order = { spellID = 111, orderType = CraftingOrderType.Public, minQuality = 1 } })
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 0, "expected no SetMinimumQualityIndex call for a Public order")
    end)

    T.Test("applies on a Personal order too -- the dropdown isn't Public-only despite the name", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub,
            { order = { spellID = 111, orderType = CraftingOrderType.Personal, minQuality = 1 } })
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 1, "expected the default applied -- Personal orders show the dropdown too")
    end)

    T.Test("does nothing once already committed", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub, { committed = true })
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 0, "expected no call once the order is committed")
    end)

    T.Test("does nothing without minQualityIDs (recipe not yet loaded)", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub)
        form.minQualityIDs = nil -- a table literal with a nil value drops the key entirely,
        -- so this has to be set after the fact rather than passed via BuildForm's overrides
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 0, "expected no call without minQualityIDs")
    end)

    T.Test("does nothing when minQualityIDs only has the None placeholder", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub, { minQualityIDs = { 4 } })
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 0, "expected no call with only a None option to pick from")
    end)

    T.Test("does not re-apply on a second call for the same recipe (respects a manual change back to None)", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub)
        form.SetMinimumQualityIndex = function(_, index)
            table.insert(setCalls, index)
            form.order.minQuality = index
        end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()
        T.AssertEqual(#setCalls, 1, "expected the first call to apply the default")

        -- Simulates the player manually setting it back to None, then a reagent-only refresh
        -- (UpdateReagentSlots fires for those too, not just recipe changes).
        form.order.minQuality = 1
        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 1, "expected no second call -- same recipe already defaulted once")
    end)

    T.Test("re-applies once the recipe (spellID) changes on the same draft", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub)
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()
        T.AssertEqual(#setCalls, 1, "expected the first recipe's default applied")

        form.order.spellID = 222
        form.order.minQuality = 1
        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 2, "expected a second call after switching to a different recipe")
    end)

    T.Test("does not override a minQuality the player already chose above None", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local setCalls = {}
        local form = BuildForm(stub, { order = { spellID = 111, orderType = CraftingOrderType.Guild, minQuality = 2 } })
        form.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultMinimumQuality()

        T.AssertEqual(#setCalls, 0, "expected no call -- the order already has a non-None minQuality")
    end)

    T.Test("SetupMinimumQualityDefault applies once when the Form is found", function()
        local fakeForm = stub.MakeFrame()
        -- OrderShoppingButton.lua's own OnFormFound hook also fires and needs this to anchor
        -- its button against -- see order_screen_spec.lua's header comment for why.
        fakeForm.PaymentContainer = { ListOrderButton = stub.MakeFrame() }
        fakeForm.order = { spellID = 111, orderType = CraftingOrderType.Guild, minQuality = 1 }
        fakeForm.minQualityIDs = { 4, 5, 6, 7, 8 }
        fakeForm.committed = false
        local setCalls = {}
        fakeForm.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end

        stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })

        T.AssertEqual(#setCalls, 1, "expected the default applied once the Form was found")
    end)

    T.Test("SetupMinimumQualityDefault re-checks when UpdateReagentSlots runs", function()
        local fakeForm = stub.MakeFrame()
        fakeForm.PaymentContainer = { ListOrderButton = stub.MakeFrame() }
        fakeForm.order = { spellID = 111, orderType = CraftingOrderType.Guild, minQuality = 1 }
        fakeForm.minQualityIDs = nil -- not loaded yet when the Form is first found
        fakeForm.committed = false
        fakeForm.UpdateReagentSlots = function() end
        local setCalls = {}
        fakeForm.SetMinimumQualityIndex = function(_, index) table.insert(setCalls, index) end

        stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        T.AssertEqual(#setCalls, 0, "expected no call before minQualityIDs is populated")

        fakeForm.minQualityIDs = { 4, 5, 6, 7, 8 }
        fakeForm:UpdateReagentSlots()

        T.AssertEqual(#setCalls, 1, "expected the default applied once minQualityIDs became available")
    end)
end
