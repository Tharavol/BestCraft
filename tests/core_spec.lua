-- core_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- LoadAddon auto-fires ADDON_LOADED for "BestCraft" itself (see stub_api.lua's comment on
-- why) -- most tests here don't need to fire it manually. Only the addon-name-filtering test
-- below needs opts.skipAutoAddonLoaded, to control firing order/addon name itself.

return function(stub, T)
    T.Test("sets ns.ready when Auctionator is loaded", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        T.AssertTrue(loaded.ns.ready, "expected ns.ready to be true")
    end)

    T.Test("warns and leaves ns.ready unset when Auctionator is missing", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertFalse(loaded.ns.ready, "expected ns.ready to stay unset")
        T.AssertEqual(#loaded.api.chatLog, 1, "expected one warning message")
    end)

    T.Test("initializes BestCraftDB and ns.db regardless of Auctionator's presence", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertTrue(loaded.ns.db ~= nil, "expected ns.db to be set even without Auctionator")
        T.AssertTrue(loaded.ns.db.settings.buttonEnabled, "expected the buttonEnabled default")
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "expected the printOnLogin default")
        T.AssertTrue(loaded.ns.db.settings.maxQualityEnabled, "expected the maxQualityEnabled default")
        T.AssertTrue(loaded.ns.db.settings.guildCommissionEnabled, "expected the guildCommissionEnabled default")
        T.AssertTrue(loaded.ns.db.settings.updateOnPurchaseEnabled, "expected the updateOnPurchaseEnabled default")
    end)

    T.Test("ignores ADDON_LOADED events for other addons", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc",
            { addonsLoaded = { Auctionator = true }, skipAutoAddonLoaded = true })
        stub.FireAddonLoaded(loaded, "SomeOtherAddon")
        T.AssertEqual(loaded.ns.ready, nil, "should not react to a different addon's ADDON_LOADED")
        T.AssertEqual(loaded.ns.db, nil, "should not have initialized the DB yet either")
    end)

    T.Test("ns.Print prepends the chat prefix and formats like string.format", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.Print("plain message")
        loaded.ns.Print("%s and %s", "formatted", "args")
        T.AssertEqual(#loaded.api.chatLog, 3, "expected the Auctionator warning plus two ns.Print calls")
        T.AssertTrue(loaded.api.chatLog[2]:find("plain message") ~= nil, "expected the plain message")
        T.AssertTrue(loaded.api.chatLog[3]:find("formatted and args") ~= nil, "expected the formatted message")
    end)

    T.Test("ns.FormatVersion normalizes raw TOC metadata", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(loaded.ns.FormatVersion("1.2.3"), "v1.2.3", "expected a 'v' prefix added")
        T.AssertEqual(loaded.ns.FormatVersion("v1.2.3"), "v1.2.3", "expected no double 'v' prefix")
        T.AssertEqual(loaded.ns.FormatVersion("@project-version@"), "dev",
            "expected the unsubstituted packager token treated as a dev install")
        T.AssertEqual(loaded.ns.FormatVersion(nil), "dev", "expected nil treated as a dev install")
    end)

    T.Test("ns.VERSION reflects the addonVersion fed to GetAddOnMetadata", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {}, addonVersion = "2.0.0" })
        T.AssertEqual(loaded.ns.VERSION, "v2.0.0", "expected the fed version, formatted")
    end)

    T.Test("ns.ResetToDefaults restores every setting", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.db.settings.buttonEnabled = false
        loaded.ns.db.settings.printOnLogin = true
        loaded.ns.db.settings.maxQualityEnabled = false
        loaded.ns.db.settings.guildCommissionEnabled = false
        loaded.ns.db.settings.updateOnPurchaseEnabled = false

        loaded.ns.ResetToDefaults()

        T.AssertTrue(loaded.ns.db.settings.buttonEnabled, "expected buttonEnabled reset to its default")
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "expected printOnLogin reset to its default")
        T.AssertTrue(loaded.ns.db.settings.maxQualityEnabled, "expected maxQualityEnabled reset to its default")
        T.AssertTrue(loaded.ns.db.settings.guildCommissionEnabled,
            "expected guildCommissionEnabled reset to its default")
        T.AssertTrue(loaded.ns.db.settings.updateOnPurchaseEnabled,
            "expected updateOnPurchaseEnabled reset to its default")
    end)

    T.Test("ns.ResetToDefaults refreshes the order-screen button live, if it exists", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local refreshCalls = 0
        loaded.ns.RefreshShoppingButton = function() refreshCalls = refreshCalls + 1 end

        loaded.ns.ResetToDefaults()

        T.AssertEqual(refreshCalls, 1, "expected ResetToDefaults to call the exposed refresh hook")
    end)

    T.Test("ns.ResetToDefaults doesn't error when the button was never created", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertEqual(loaded.ns.RefreshShoppingButton, nil, "sanity: no button, no hook")
        loaded.ns.ResetToDefaults() -- must not error
        T.AssertTrue(true, "expected no error")
    end)

    T.Test("prints a login message only when ready and printOnLogin is set", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        loaded.ns.db.settings.printOnLogin = true
        local before = #loaded.api.chatLog

        stub.FireAddonLoaded(loaded, "SomeOtherAddon") -- sanity: not a login event, no message
        T.AssertEqual(#loaded.api.chatLog, before, "expected no message from an unrelated ADDON_LOADED")

        stub.FireEvent(loaded, "PLAYER_LOGIN")
        T.AssertEqual(#loaded.api.chatLog, before + 1, "expected one login message")
    end)

    T.Test("does not print a login message when Auctionator is missing, even with printOnLogin set", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.db.settings.printOnLogin = true
        local before = #loaded.api.chatLog

        stub.FireEvent(loaded, "PLAYER_LOGIN")
        T.AssertEqual(#loaded.api.chatLog, before,
            "expected no login message -- not ready, since Auctionator isn't present")
    end)
end
