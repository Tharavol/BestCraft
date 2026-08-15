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
    T.Test("registers exactly the two documented checkboxes", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(#loaded.ns.Options.CHECKBOXES, 2, "expected exactly two settings")
        T.AssertTrue(FindCheckbox(loaded, "buttonEnabled") ~= nil, "expected a buttonEnabled checkbox")
        T.AssertTrue(FindCheckbox(loaded, "printOnLogin") ~= nil, "expected a printOnLogin checkbox")
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
