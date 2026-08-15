BestCraft
=========

World of Warcraft retail addon that adds a button to the customer-side "Place Crafting Order" screen to get you the highest-quality reagents for that order, with no guesswork about which item or rank to pick.

This is an unofficial companion addon and is not affiliated with or endorsed by Auctionator's authors.

Why
---
On the order-creation screen, Blizzard's own "Use Best Quality Reagents" checkbox already picks the best-quality reagent for each slot -- but there's no way to turn that into a shopping list. BestCraft reads the order screen's already-computed reagent choice and builds an Auctionator shopping list from it, for orders you're placing for someone else to craft (recraft orders included). No independent quality or price optimization -- just the highest quality, no guesswork.

Requirements
------------
- [Auctionator](https://www.curseforge.com/wow/addons/auctionator) must be installed and enabled.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: `World of Warcraft\_retail_\Interface\AddOns\BestCraft`

Status
------
Core feature working end-to-end (normal and recraft orders both, via a single Auctionator shopping list); polish (options panel, slash commands) still in progress. See [open issues](https://github.com/Tharavol/BestCraft/issues) and [milestones](https://github.com/Tharavol/BestCraft/milestones) for progress.

Credits
-------
Interoperates with [Auctionator](https://www.curseforge.com/wow/addons/auctionator) via its public API. Earlier versions queued normal orders into [CraftSim](https://github.com/derfloh205/CraftSim)'s CraftQueue instead of building a shopping list directly; that approach was retired (see `docs/craftsim-recipedata-notes.md`), and CraftSim is no longer a dependency.

License
-------
GPL-3.0-or-later. See [LICENSE](LICENSE).
