-- order_commission_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Mirrors stub_api.lua's env.Enum.CraftingOrderType -- this file runs outside the addon's
-- sandboxed environment, so it needs its own copy rather than reading the addon's global.
local CraftingOrderType = { Public = 0, Guild = 1, Personal = 2, Npc = 3 }

-- MoneyInputFrame's GetAmount()/SetAmount() aren't part of stub_api.lua's shared MakeFrame --
-- no other module reads a money widget, so this stays local to the one spec file that needs it
-- rather than bloating the shared stub with single-use API surface.
local function MakeTipInput(stub, initialAmount)
    local tipInput = stub.MakeFrame()
    tipInput._amount = initialAmount or 0
    function tipInput:GetAmount() return self._amount end
    function tipInput:SetAmount(amount) self._amount = amount end
    return tipInput
end

local function BuildForm(stub, overrides)
    local form = stub.MakeFrame()
    form.order = { orderType = CraftingOrderType.Guild }
    form.committed = false
    form.PaymentContainer = stub.MakeFrame()
    form.PaymentContainer.TipMoneyInputFrame = MakeTipInput(stub, 0)
    for k, v in pairs(overrides or {}) do
        form[k] = v
    end
    return form
end

return function(stub, T)
    T.Test("sets the commission to 1 silver on a Guild order when it's still 0", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub)
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100,
            "expected 100 copper (1 silver)")
    end)

    T.Test("leaves an already-set commission alone", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub)
        form.PaymentContainer.TipMoneyInputFrame:SetAmount(500)
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 500,
            "expected the existing commission left untouched")
    end)

    T.Test("bumps a manually-cleared commission back to 1 silver -- 0 is never submittable anyway",
        function()
            -- Deliberately the opposite of OrderMinimumQuality.lua's "don't re-stomp a manual
            -- change back to None": unlike None, a 0 commission is never a real destination --
            -- Blizzard's own "Place Order" button refuses to submit at 0 regardless of order
            -- type -- so there's no legitimate player choice being overridden by re-applying.
            local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
            local form = BuildForm(stub)
            loaded.ns.OrderScreen.form = form

            loaded.ns.OrderScreen:ApplyDefaultCommission()
            T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100, "expected the first default")

            form.PaymentContainer.TipMoneyInputFrame:SetAmount(0)
            loaded.ns.OrderScreen:ApplyDefaultCommission()

            T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100,
                "expected the default re-applied, not left at 0")
        end)

    T.Test("does nothing on a Public order", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub, { order = { orderType = CraftingOrderType.Public } })
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0,
            "expected the commission left at 0 -- Guild-only per issue #22")
    end)

    T.Test("does nothing on a Personal order", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub, { order = { orderType = CraftingOrderType.Personal } })
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0,
            "expected the commission left at 0 -- Guild-only per issue #22")
    end)

    T.Test("does nothing once already committed", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub, { committed = true })
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0,
            "expected no change once the order is committed")
    end)

    T.Test("does nothing without a TipMoneyInputFrame (not loaded yet)", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local form = BuildForm(stub)
        form.PaymentContainer = nil
        loaded.ns.OrderScreen.form = form

        -- Just needs not to error.
        loaded.ns.OrderScreen:ApplyDefaultCommission()
    end)

    T.Test("does nothing when guildCommissionEnabled is turned off", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.ns.db.settings.guildCommissionEnabled = false
        local form = BuildForm(stub)
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0, "expected no change -- setting is off")
    end)

    T.Test("re-applies once guildCommissionEnabled is turned back on mid-draft", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.ns.db.settings.guildCommissionEnabled = false
        local form = BuildForm(stub)
        loaded.ns.OrderScreen.form = form

        loaded.ns.OrderScreen:ApplyDefaultCommission()
        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0, "expected no change while off")

        loaded.ns.db.settings.guildCommissionEnabled = true
        loaded.ns.OrderScreen:ApplyDefaultCommission()

        T.AssertEqual(form.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100, "expected the default once re-enabled")
    end)

    T.Test("SetupDefaultCommission applies once when the Form is found", function()
        local fakeForm = stub.MakeFrame()
        fakeForm.order = { orderType = CraftingOrderType.Guild }
        fakeForm.committed = false
        fakeForm.PaymentContainer = stub.MakeFrame()
        fakeForm.PaymentContainer.TipMoneyInputFrame = MakeTipInput(stub, 0)

        stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })

        T.AssertEqual(fakeForm.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100,
            "expected the default applied once the Form was found")
    end)

    T.Test("SetupDefaultCommission re-checks when UpdateReagentSlots runs", function()
        local fakeForm = stub.MakeFrame()
        fakeForm.order = { orderType = CraftingOrderType.Public } -- not Guild yet
        fakeForm.committed = false
        fakeForm.PaymentContainer = stub.MakeFrame()
        fakeForm.PaymentContainer.TipMoneyInputFrame = MakeTipInput(stub, 0)
        fakeForm.UpdateReagentSlots = function() end

        stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        T.AssertEqual(fakeForm.PaymentContainer.TipMoneyInputFrame:GetAmount(), 0,
            "expected no change -- not a Guild order yet")

        fakeForm.order.orderType = CraftingOrderType.Guild -- player switched order type
        fakeForm:UpdateReagentSlots()

        T.AssertEqual(fakeForm.PaymentContainer.TipMoneyInputFrame:GetAmount(), 100,
            "expected the default applied once it became a Guild order")
    end)
end
