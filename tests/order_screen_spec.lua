-- order_screen_spec.lua
-- SPDX-License-Identifier: MIT

return function(stub, T)
    T.Test("locates the order screen's Form when the order addon is already loaded", function()
        local fakeForm = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { CraftSim = true, Blizzard_ProfessionsCustomerOrders = true },
            presetGlobals = { ProfessionsCustomerOrdersFrame = { Form = fakeForm } },
        })
        T.AssertEqual(loaded.ns.OrderScreen.form, fakeForm,
            "expected OrderScreen.form to be set immediately")
    end)

    T.Test("locates the Form once ADDON_LOADED fires for the order addon", function()
        local fakeForm = {}
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        T.AssertEqual(loaded.ns.OrderScreen.form, nil,
            "should not be set before the order addon loads")

        loaded.env.ProfessionsCustomerOrdersFrame = { Form = fakeForm }
        stub.FireAddonLoaded(loaded, "Blizzard_ProfessionsCustomerOrders")

        T.AssertEqual(loaded.ns.OrderScreen.form, fakeForm,
            "expected OrderScreen.form to be set after ADDON_LOADED")
    end)

    T.Test("ignores ADDON_LOADED for unrelated addons", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { CraftSim = true } })
        loaded.env.ProfessionsCustomerOrdersFrame = { Form = {} }
        stub.FireAddonLoaded(loaded, "SomeOtherAddon")
        T.AssertEqual(loaded.ns.OrderScreen.form, nil,
            "should not react to an unrelated addon's ADDON_LOADED")
    end)
end
