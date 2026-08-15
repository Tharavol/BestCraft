-- order_screen_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- fakeForm uses stub.MakeFrame(), not a bare {}: once OrderShoppingButton.lua joins the toc,
-- every OrderScreen.form assignment also triggers button creation against it (OnFormFound
-- fires unconditionally), so it needs to behave like a real frame (HookScript etc.), not
-- just be comparable by reference.
local function MakeOrderForm(stub)
    return stub.MakeFrame()
end

return function(stub, T)
    T.Test("locates the order screen's Form when the order addon is already loaded", function()
        local fakeForm = MakeOrderForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        T.AssertEqual(loaded.ns.OrderScreen.form, fakeForm,
            "expected OrderScreen.form to be set immediately")
    end)

    T.Test("locates the Form once ADDON_LOADED fires for the order addon", function()
        local fakeForm = MakeOrderForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        T.AssertEqual(loaded.ns.OrderScreen.form, nil,
            "should not be set before the order addon loads")

        loaded.env.ProfessionsCustomerOrdersFrame = { Form = fakeForm }
        stub.FireAddonLoaded(loaded, "Blizzard_ProfessionsCustomerOrders")

        T.AssertEqual(loaded.ns.OrderScreen.form, fakeForm,
            "expected OrderScreen.form to be set after ADDON_LOADED")
    end)

    T.Test("ignores ADDON_LOADED for unrelated addons", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.env.ProfessionsCustomerOrdersFrame = { Form = stub.MakeFrame() }
        stub.FireAddonLoaded(loaded, "SomeOtherAddon")
        T.AssertEqual(loaded.ns.OrderScreen.form, nil,
            "should not react to an unrelated addon's ADDON_LOADED")
    end)

    T.Test("OnFormFound calls back immediately when the Form is already known", function()
        local fakeForm = MakeOrderForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        local calledWith
        loaded.ns.OrderScreen:OnFormFound(function(form) calledWith = form end)
        T.AssertEqual(calledWith, fakeForm, "expected the callback to fire immediately")
    end)

    T.Test("OnFormFound calls back once the Form is found later", function()
        local fakeForm = MakeOrderForm(stub)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local calledWith
        loaded.ns.OrderScreen:OnFormFound(function(form) calledWith = form end)
        T.AssertEqual(calledWith, nil, "should not fire before the Form exists")

        loaded.env.ProfessionsCustomerOrdersFrame = { Form = fakeForm }
        stub.FireAddonLoaded(loaded, "Blizzard_ProfessionsCustomerOrders")

        T.AssertEqual(calledWith, fakeForm, "expected the callback to fire once the Form is found")
    end)
end
