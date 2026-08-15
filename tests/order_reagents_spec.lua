-- order_reagents_spec.lua
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Mirrors stub_api.lua's env.Enum.CraftingOrderReagentSource / env.Enum.ItemBind -- this file
-- runs outside the addon's sandboxed environment, so it needs its own copy rather than
-- reading the addon's global.
local CraftingOrderReagentSource = { Any = 0, Customer = 1, Crafter = 2, None = 3 }
local ItemBind = { None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4 }

return function(stub, T)
    T.Test("includes a single-option slot without needing quality data", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 1, "expected one entry")
        T.AssertEqual(entries[1].itemID, 111, "expected the only option's itemID")
        T.AssertEqual(entries[1].quantity, 20, "expected quantityRequired to carry through")
        T.AssertEqual(entries[1].dataSlotIndex, 1, "expected dataSlotIndex to carry through")
        T.AssertTrue(entries[1].required, "expected required to carry through")
    end)

    T.Test("picks the highest-quality option when quality data distinguishes them", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            reagentQualities = { [201] = 2, [202] = 3 },
        })
        local schematicInfo = {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 2, required = true, quantityRequired = 5,
                    reagents = { { itemID = 201 }, { itemID = 202 } },
                },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 1, "expected one entry")
        T.AssertEqual(entries[1].itemID, 202, "expected the higher-quality itemID")
        T.AssertEqual(entries[1].quantity, 5, "expected quantityRequired to carry through")
    end)

    T.Test("skips a multi-option slot when no option reports a quality tier", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 6,
                    required = false,
                    reagents = { { itemID = 301 }, { itemID = 302 }, { itemID = 303 } },
                },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 0, "expected no entries -- ambiguous choice, not guessed")
    end)

    T.Test("skips a slot with no reagent options at all", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 1, reagents = {} },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 0, "expected no entries")
    end)

    T.Test("reports allRequiredResolved=false when a required slot has no confident pick", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
                {
                    dataSlotIndex = 2, required = true, quantityRequired = 1,
                    reagents = { { itemID = 301 }, { itemID = 302 } },
                },
            },
        }
        local entries, allRequiredResolved = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 1, "expected only the resolvable slot's entry")
        T.AssertFalse(allRequiredResolved, "expected false -- a required slot had no confident pick")
    end)

    T.Test("reports allRequiredResolved=true when only an optional slot is unresolved", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
                {
                    dataSlotIndex = 6, required = false,
                    reagents = { { itemID = 301 }, { itemID = 302 } },
                },
            },
        }
        local _, allRequiredResolved = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertTrue(allRequiredResolved, "expected true -- only an optional slot was unresolved")
    end)

    T.Test("handles multiple slots together, matching the real order's shape", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            reagentQualities = { [240974] = 2, [240975] = 3 },
        })
        -- Mirrors the real slot shapes recorded in docs/order-screen-research.md: a basic
        -- reagent slot (single option), a quality-ranked slot (two options, one quality),
        -- and the trailing optional slot with many same-quality (unranked) choices.
        local schematicInfo = {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 1, required = true, quantityRequired = 20,
                    reagents = { { itemID = 245345 } },
                },
                {
                    dataSlotIndex = 1, required = true, quantityRequired = 5,
                    reagents = { { itemID = 240974 }, { itemID = 240975 } },
                },
                {
                    dataSlotIndex = 6,
                    required = false,
                    reagents = {
                        { itemID = 246447 }, { itemID = 246448 }, { itemID = 246449 }, { itemID = 246450 },
                        { itemID = 247725 }, { itemID = 247726 }, { itemID = 260630 }, { itemID = 247788 },
                    },
                },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 2, "expected the basic and quality-ranked slots, not the optional one")
        T.AssertEqual(entries[1].itemID, 245345, "expected the basic reagent's only option")
        T.AssertEqual(entries[2].itemID, 240975, "expected the higher-quality rank")
        T.AssertEqual(entries[2].quantity, 5, "expected the quality slot's quantityRequired")
    end)

    T.Test("excludes a required, Crafter-sourced slot entirely -- not the customer's to buy", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 20, reagents = { { itemID = 111 } } },
                {
                    dataSlotIndex = 2, required = true, quantityRequired = 5,
                    orderSource = CraftingOrderReagentSource.Crafter,
                    reagents = { { itemID = 222 } },
                },
            },
        }
        local entries, allRequiredResolved = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 1, "expected only the Customer-sourced slot's entry")
        T.AssertEqual(entries[1].itemID, 111, "expected the non-Crafter-sourced reagent")
        T.AssertTrue(allRequiredResolved,
            "expected true -- a Crafter-sourced slot was never the customer's to resolve")
    end)

    T.Test("includes Customer- and Any-sourced slots normally", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 1, required = true, quantityRequired = 1,
                    orderSource = CraftingOrderReagentSource.Customer,
                    reagents = { { itemID = 111 } },
                },
                {
                    dataSlotIndex = 2, required = true, quantityRequired = 1,
                    orderSource = CraftingOrderReagentSource.Any,
                    reagents = { { itemID = 222 } },
                },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 2, "expected both Customer- and Any-sourced slots included")
    end)

    T.Test("excludes a bind-on-pickup reagent even when Customer-sourced and required", function()
        -- Matches the real bug: "Fused Vitality" had orderSource == Customer (not Crafter),
        -- so only a bindType check catches it -- confirmed in-game via zero Auctionator
        -- search results despite the order screen listing it as required.
        local loaded = stub.LoadAddon(".", "BestCraft.toc", {
            addonsLoaded = { Auctionator = true },
            itemBindTypes = { [111] = ItemBind.OnAcquire },
        })
        local schematicInfo = {
            reagentSlotSchematics = {
                {
                    dataSlotIndex = 1, required = true, quantityRequired = 20,
                    orderSource = CraftingOrderReagentSource.Customer,
                    reagents = { { itemID = 111 } },
                },
            },
        }
        local entries, allRequiredResolved = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 0, "expected the BoP reagent excluded")
        T.AssertTrue(allRequiredResolved,
            "expected true -- a BoP reagent was never purchasable, so it's not an unresolved pick")
    end)

    T.Test("includes a reagent whose bind type isn't cached yet (fails open, not BoP)", function()
        local loaded = stub.LoadAddon(".", "BestCraft.toc", { addonsLoaded = { Auctionator = true } })
        local schematicInfo = {
            reagentSlotSchematics = {
                { dataSlotIndex = 1, required = true, quantityRequired = 1, reagents = { { itemID = 111 } } },
            },
        }
        local entries = loaded.ns.OrderScreen:GetBestQualityReagentEntries(schematicInfo)
        T.AssertEqual(#entries, 1, "expected the reagent included -- unknown bind status isn't treated as BoP")
    end)
end
