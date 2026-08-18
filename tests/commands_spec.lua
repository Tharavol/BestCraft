-- commands_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Exercises Commands:Dispatch directly rather than through SlashCmdList -- Commands.lua never
-- touches the game API itself (see its own header comment), so there's no slash-command event
-- to fake.

return function(stub, T)
    T.Test("bare, options, config and gui all open the options panel", function()
        for _, input in ipairs({ "", "options", "config", "gui" }) do
            local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
            loaded.ns.Commands:Dispatch(input)
            T.AssertEqual(#loaded.api.openedCategoryIDs, 1, "expected the panel opened for '" .. input .. "'")
        end
    end)

    T.Test("status prints the version and every checkbox setting", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local before = #loaded.api.chatLog

        loaded.ns.Commands:Dispatch("status")

        T.AssertTrue(#loaded.api.chatLog > before, "expected status output")
        local combined = table.concat(loaded.api.chatLog, "\n")
        T.AssertTrue(combined:find(loaded.ns.VERSION, 1, true) ~= nil, "expected the version in the output")
        for _, definition in ipairs(loaded.ns.Options.CHECKBOXES) do
            T.AssertTrue(combined:find(definition.label, 1, true) ~= nil,
                "expected '" .. definition.label .. "' in the status output")
        end
    end)

    T.Test("version prints ns.VERSION", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {}, addonVersion = "3.1.4" })
        loaded.ns.Commands:Dispatch("version")
        T.AssertTrue(loaded.api.chatLog[#loaded.api.chatLog]:find("v3.1.4", 1, true) ~= nil,
            "expected the formatted version")
    end)

    T.Test("reset restores every setting to its default", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        loaded.ns.db.settings.buttonEnabled = false
        loaded.ns.db.settings.printOnLogin = true

        loaded.ns.Commands:Dispatch("reset")

        T.AssertTrue(loaded.ns.db.settings.buttonEnabled, "expected buttonEnabled reset")
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "expected printOnLogin reset")
    end)

    T.Test("login on/off sets printOnLogin explicitly", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })

        loaded.ns.Commands:Dispatch("login on")
        T.AssertTrue(loaded.ns.db.settings.printOnLogin, "expected 'login on' to set it true")

        loaded.ns.Commands:Dispatch("login off")
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "expected 'login off' to set it false")
    end)

    T.Test("bare login toggles the current state", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "sanity: starts false")

        loaded.ns.Commands:Dispatch("login")
        T.AssertTrue(loaded.ns.db.settings.printOnLogin, "expected the first bare toggle to flip it on")

        loaded.ns.Commands:Dispatch("login")
        T.AssertFalse(loaded.ns.db.settings.printOnLogin, "expected the second bare toggle to flip it back off")
    end)

    T.Test("maxquality on/off sets maxQualityEnabled explicitly", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })

        loaded.ns.Commands:Dispatch("maxquality off")
        T.AssertFalse(loaded.ns.db.settings.maxQualityEnabled, "expected 'maxquality off' to set it false")

        loaded.ns.Commands:Dispatch("maxquality on")
        T.AssertTrue(loaded.ns.db.settings.maxQualityEnabled, "expected 'maxquality on' to set it true")
    end)

    T.Test("bare maxquality toggles the current state", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertTrue(loaded.ns.db.settings.maxQualityEnabled, "sanity: starts true")

        loaded.ns.Commands:Dispatch("maxquality")
        T.AssertFalse(loaded.ns.db.settings.maxQualityEnabled, "expected the first bare toggle to flip it off")

        loaded.ns.Commands:Dispatch("maxquality")
        T.AssertTrue(loaded.ns.db.settings.maxQualityEnabled, "expected the second bare toggle to flip it back on")
    end)

    T.Test("guildcommission on/off sets guildCommissionEnabled explicitly", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })

        loaded.ns.Commands:Dispatch("guildcommission off")
        T.AssertFalse(loaded.ns.db.settings.guildCommissionEnabled, "expected 'guildcommission off' to set it false")

        loaded.ns.Commands:Dispatch("guildcommission on")
        T.AssertTrue(loaded.ns.db.settings.guildCommissionEnabled, "expected 'guildcommission on' to set it true")
    end)

    T.Test("bare guildcommission toggles the current state", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertTrue(loaded.ns.db.settings.guildCommissionEnabled, "sanity: starts true")

        loaded.ns.Commands:Dispatch("guildcommission")
        T.AssertFalse(loaded.ns.db.settings.guildCommissionEnabled, "expected the first bare toggle to flip it off")

        loaded.ns.Commands:Dispatch("guildcommission")
        T.AssertTrue(loaded.ns.db.settings.guildCommissionEnabled,
            "expected the second bare toggle to flip it back on")
    end)

    T.Test("updateonpurchase on/off sets updateOnPurchaseEnabled explicitly", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })

        loaded.ns.Commands:Dispatch("updateonpurchase off")
        T.AssertFalse(loaded.ns.db.settings.updateOnPurchaseEnabled,
            "expected 'updateonpurchase off' to set it false")

        loaded.ns.Commands:Dispatch("updateonpurchase on")
        T.AssertTrue(loaded.ns.db.settings.updateOnPurchaseEnabled,
            "expected 'updateonpurchase on' to set it true")
    end)

    T.Test("bare updateonpurchase toggles the current state", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        T.AssertTrue(loaded.ns.db.settings.updateOnPurchaseEnabled, "sanity: starts true")

        loaded.ns.Commands:Dispatch("updateonpurchase")
        T.AssertFalse(loaded.ns.db.settings.updateOnPurchaseEnabled,
            "expected the first bare toggle to flip it off")

        loaded.ns.Commands:Dispatch("updateonpurchase")
        T.AssertTrue(loaded.ns.db.settings.updateOnPurchaseEnabled,
            "expected the second bare toggle to flip it back on")
    end)

    T.Test("login with an unrecognized value is rejected, not silently ignored", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        local before = loaded.ns.db.settings.printOnLogin

        loaded.ns.Commands:Dispatch("login maybe")

        T.AssertEqual(loaded.ns.db.settings.printOnLogin, before, "expected the setting unchanged")
        T.AssertTrue(loaded.api.chatLog[#loaded.api.chatLog]:find("maybe") ~= nil,
            "expected the rejected value echoed back")
    end)

    T.Test("an unknown command prints an error and the usage list", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local before = #loaded.api.chatLog

        loaded.ns.Commands:Dispatch("bogus")

        T.AssertTrue(loaded.api.chatLog[before + 1]:find("bogus") ~= nil, "expected the unknown command echoed back")
        T.AssertTrue(#loaded.api.chatLog > before + 1, "expected the usage list printed after the error")
    end)

    T.Test("help prints the usage list", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local before = #loaded.api.chatLog
        loaded.ns.Commands:Dispatch("help")
        T.AssertTrue(#loaded.api.chatLog > before + 1, "expected multiple lines of usage")
    end)
end
