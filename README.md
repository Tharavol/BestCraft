BestCraft
=========

World of Warcraft retail addon that adds a button to the customer-side "Place Crafting Order" screen to queue the highest-quality reagents for that order into [CraftSim](https://www.curseforge.com/wow/addons/craftsim)'s CraftQueue, so CraftSim's existing shopping-list tooling tells you exactly what to buy.

This is an unofficial companion addon and is not affiliated with or endorsed by CraftSim's author.

Why
---
On the order-creation screen, Blizzard's own "Use Best Quality Reagents" checkbox already picks the best-quality reagent for each slot -- but there's no way to turn that into a shopping list. CraftSim already solves that problem for recipes you queue to craft yourself; BestCraft reads the order screen's already-computed reagent choice and hands it to CraftSim's CraftQueue, so you get the same shopping-list workflow for orders you're placing for someone else to craft. No independent quality or price optimization -- just the highest quality, no guesswork.

Requirements
------------
- [CraftSim](https://www.curseforge.com/wow/addons/craftsim) must be installed and enabled.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: `World of Warcraft\_retail_\Interface\AddOns\BestCraft`

Status
------
Early development -- the order-screen button and CraftQueue integration aren't built yet. See [open issues](https://github.com/Tharavol/BestCraft/issues) and [milestones](https://github.com/Tharavol/BestCraft/milestones) for progress.

Credits
-------
Built on top of [CraftSim](https://github.com/derfloh205/CraftSim), MIT License, Copyright (c) 2023 Florian Schneider.
