-- options_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later

local function FindCheckbox(loaded, key)
    for _, entry in ipairs(loaded.ns.Options.panel.checkboxes) do
        if entry.key == key then
            return entry.checkbox
        end
    end
    return nil
end

return function(stub, T)
    T.Test("registers exactly the five documented checkboxes", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(#loaded.ns.Options.CHECKBOXES, 5, "expected exactly five settings")
        T.AssertTrue(FindCheckbox(loaded, "buttonEnabled") ~= nil, "expected a buttonEnabled checkbox")
        T.AssertTrue(FindCheckbox(loaded, "printOnLogin") ~= nil, "expected a printOnLogin checkbox")
        T.AssertTrue(FindCheckbox(loaded, "maxQualityEnabled") ~= nil, "expected a maxQualityEnabled checkbox")
        T.AssertTrue(FindCheckbox(loaded, "guildCommissionEnabled") ~= nil,
            "expected a guildCommissionEnabled checkbox")
        T.AssertTrue(FindCheckbox(loaded, "updateOnPurchaseEnabled") ~= nil,
            "expected an updateOnPurchaseEnabled checkbox")
    end)

    T.Test("Open opens the registered category", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.Options:Open()
        T.AssertEqual(#loaded.api.openedCategoryIDs, 1, "expected one OpenToCategory call")
    end)

    T.Test("clicking a checkbox updates ns.db.settings", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local checkbox = FindCheckbox(loaded, "buttonEnabled")

        checkbox:SetChecked(false)
        checkbox:FireScript("OnClick")

        T.AssertFalse(loaded.ns.db.settings.buttonEnabled, "expected the setting to follow the checkbox")
    end)

    T.Test("clicking the buttonEnabled checkbox calls ns.RefreshShoppingButton, if it exists", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local refreshCalls = 0
        loaded.ns.RefreshShoppingButton = function() refreshCalls = refreshCalls + 1 end
        local checkbox = FindCheckbox(loaded, "buttonEnabled")

        checkbox:SetChecked(false)
        checkbox:FireScript("OnClick")

        T.AssertEqual(refreshCalls, 1, "expected the live-refresh hook called once")
    end)

    T.Test("clicking a checkbox with no onChange doesn't error", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local checkbox = FindCheckbox(loaded, "printOnLogin")
        checkbox:SetChecked(true)
        checkbox:FireScript("OnClick") -- must not error
        T.AssertTrue(loaded.ns.db.settings.printOnLogin, "expected the setting to still follow the checkbox")
    end)

    T.Test("RefreshWidgets syncs checkboxes from ns.db.settings", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.db.settings.printOnLogin = true

        loaded.ns.Options:RefreshWidgets()

        local checkbox = FindCheckbox(loaded, "printOnLogin")
        T.AssertTrue(checkbox:GetChecked(), "expected the checkbox to reflect the setting")
    end)

    T.Test("showing the panel refreshes the checkboxes", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.db.settings.buttonEnabled = false

        loaded.ns.Options.panel:FireScript("OnShow")

        local checkbox = FindCheckbox(loaded, "buttonEnabled")
        T.AssertFalse(checkbox:GetChecked(), "expected OnShow to pull the current setting")
    end)
end
