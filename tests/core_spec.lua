-- core_spec.lua
-- SPDX-License-Identifier: MIT

return function(stub, T)
    T.Test("sets ns.ready when Auctionator is loaded", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        stub.FireAddonLoaded(loaded, "BestCraft")
        T.AssertTrue(loaded.ns.ready, "expected ns.ready to be true")
    end)

    T.Test("warns and leaves ns.ready unset when Auctionator is missing", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = {} })
        stub.FireAddonLoaded(loaded, "BestCraft")
        T.AssertFalse(loaded.ns.ready, "expected ns.ready to stay unset")
        T.AssertEqual(#loaded.api.chatLog, 1, "expected one warning message")
    end)

    T.Test("ignores ADDON_LOADED events for other addons", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        stub.FireAddonLoaded(loaded, "SomeOtherAddon")
        T.AssertFalse(loaded.ns.ready, "should not react to a different addon's ADDON_LOADED")
    end)
end
