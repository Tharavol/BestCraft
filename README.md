BestCraft
=========

World of Warcraft retail addon that adds a button to the customer-side "Place Crafting Order" screen to get you the highest-quality reagents for that order, with no guesswork about which item or rank to pick.

This is an unofficial companion addon and is not affiliated with or endorsed by CraftSim's or Auctionator's authors.

Why
---
On the order-creation screen, Blizzard's own "Use Best Quality Reagents" checkbox already picks the best-quality reagent for each slot -- but there's no way to turn that into a shopping list. CraftSim already solves that problem for recipes you queue to craft yourself; BestCraft reads the order screen's already-computed reagent choice and hands it off, so you get the same shopping-list workflow for orders you're placing for someone else to craft. No independent quality or price optimization -- just the highest quality, no guesswork.

Two modes, depending on the order:
- **Normal orders**: queues the recipe into [CraftSim](https://www.curseforge.com/wow/addons/craftsim)'s CraftQueue, so CraftSim's existing shopping-list tooling tells you exactly what to buy.
- **Recraft orders**: CraftSim's CraftQueue doesn't support recraft recipes at all (recrafting needs a specific target item, which doesn't fit a customer commissioning someone else's work), so BestCraft builds an Auctionator shopping list directly instead.

Requirements
------------
- [CraftSim](https://www.curseforge.com/wow/addons/craftsim) must be installed and enabled.
- [Auctionator](https://www.curseforge.com/wow/addons/auctionator) is optional, needed only for the shopping list on recraft orders.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: `World of Warcraft\_retail_\Interface\AddOns\BestCraft`

Status
------
Core feature working end-to-end (normal and recraft orders both); polish (options panel, slash commands) still in progress. See [open issues](https://github.com/Tharavol/BestCraft/issues) and [milestones](https://github.com/Tharavol/BestCraft/milestones) for progress.

Credits
-------
Built on top of [CraftSim](https://github.com/derfloh205/CraftSim), MIT License, Copyright (c) 2023 Florian Schneider. Interoperates with [Auctionator](https://www.curseforge.com/wow/addons/auctionator) via its public API.
