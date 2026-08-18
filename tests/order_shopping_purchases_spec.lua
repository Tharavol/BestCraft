-- order_shopping_purchases_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Same minimal in-memory Auctionator stand-in order_shopping_list_spec.lua uses for its own
-- multi-call merge tests -- issue #21's decrement only shows up across two calls sharing a
-- backing list (seed a list, then react to a purchase against it), the same shape.
local function BuildFakeAuctionator()
    local lists = {}
    local function Encode(term)
        return ("%s|%s|%d"):format(term.searchString, tostring(term.tier or 0), term.quantity)
    end
    local function Decode(searchString)
        local name, tier, quantity = searchString:match("^(.-)|(.-)|(%d+)$")
        if not name then
            return nil
        end
        return { searchString = name, tier = tonumber(tier), quantity = tonumber(quantity) }
    end
    return {
        API = {
            v1 = {
                ConvertToSearchString = function(_, term) return Encode(term) end,
                ConvertFromSearchString = function(_, searchString) return Decode(searchString) end,
                CreateShoppingList = function(_, listName, searchStrings)
                    local copy = {}
                    for i, s in ipairs(searchStrings) do copy[i] = s end
                    lists[listName] = copy
                end,
                GetShoppingListItems = function(_, listName) return lists[listName] end,
            },
        },
        Shopping = {
            ListManager = {
                GetIndexForName = function(_, listName) return lists[listName] ~= nil and 1 or nil end,
            },
        },
        _lists = lists,
    }
end

-- Seeds "BestCraft" with one line item, the way CreateShoppingList itself would.
local function SeedList(fakeAuctionator, name, tier, quantity)
    local term = { searchString = name, tier = tier, quantity = quantity }
    local searchString = fakeAuctionator.API.v1.ConvertToSearchString(nil, term)
    fakeAuctionator.API.v1.CreateShoppingList(nil, "BestCraft", { searchString })
end

return function(stub, T)
    T.Test("decrements the matching line item when a commodity purchase succeeds", function()
        local fakeAuctionator = BuildFakeAuctionator()
        SeedList(fakeAuctionator, "Fused Vitality", 3, 10)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality" },
            reagentQualities = { [111] = 3 },
            presetGlobals = { Auctionator = fakeAuctionator },
        })

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(111, 4)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED")

        T.AssertEqual(#fakeAuctionator._lists.BestCraft, 1, "expected one line item still")
        T.AssertTrue(fakeAuctionator._lists.BestCraft[1]:find("|6$") ~= nil,
            "expected quantity reduced from 10 to 6")
    end)

    T.Test("removes the line item entirely when the full quantity is purchased", function()
        local fakeAuctionator = BuildFakeAuctionator()
        SeedList(fakeAuctionator, "Fused Vitality", 3, 10)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality" },
            reagentQualities = { [111] = 3 },
            presetGlobals = { Auctionator = fakeAuctionator },
        })

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(111, 10)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED")

        T.AssertEqual(#fakeAuctionator._lists.BestCraft, 0, "expected the line item removed entirely")
    end)

    T.Test("does nothing when the purchase fails", function()
        local fakeAuctionator = BuildFakeAuctionator()
        SeedList(fakeAuctionator, "Fused Vitality", 3, 10)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality" },
            reagentQualities = { [111] = 3 },
            presetGlobals = { Auctionator = fakeAuctionator },
        })

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(111, 4)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_FAILED")
        -- A later, unrelated success event must not apply the cleared/stale pending purchase.
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED")

        T.AssertTrue(fakeAuctionator._lists.BestCraft[1]:find("|10$") ~= nil,
            "expected the list untouched after a failed purchase")
    end)

    T.Test("does nothing when no BestCraft list exists yet", function()
        local fakeAuctionator = BuildFakeAuctionator()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality" },
            presetGlobals = { Auctionator = fakeAuctionator },
        })

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(111, 4)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED") -- must not error

        T.AssertEqual(fakeAuctionator._lists.BestCraft, nil, "expected no list created")
    end)

    T.Test("does nothing for a purchase of an item not on the list", function()
        local fakeAuctionator = BuildFakeAuctionator()
        SeedList(fakeAuctionator, "Fused Vitality", 3, 10)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [222] = "Some Unrelated Commodity" },
            presetGlobals = { Auctionator = fakeAuctionator },
        })

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(222, 5)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED")

        T.AssertEqual(#fakeAuctionator._lists.BestCraft, 1, "expected the unrelated list untouched")
        T.AssertTrue(fakeAuctionator._lists.BestCraft[1]:find("|10$") ~= nil, "expected quantity unchanged")
    end)

    T.Test("does nothing when updateOnPurchaseEnabled is off", function()
        local fakeAuctionator = BuildFakeAuctionator()
        SeedList(fakeAuctionator, "Fused Vitality", 3, 10)
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemNames = { [111] = "Fused Vitality" },
            reagentQualities = { [111] = 3 },
            presetGlobals = { Auctionator = fakeAuctionator },
        })
        loaded.ns.db.settings.updateOnPurchaseEnabled = false

        loaded.env.C_AuctionHouse.ConfirmCommoditiesPurchase(111, 4)
        stub.FireEvent(loaded, "COMMODITY_PURCHASE_SUCCEEDED")

        T.AssertTrue(fakeAuctionator._lists.BestCraft[1]:find("|10$") ~= nil,
            "expected the list untouched while the setting is off")
    end)
end
