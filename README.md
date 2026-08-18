BestCraft
=========

World of Warcraft retail addon that adds a button to the customer-side "Place Crafting Order" screen to get you the right-quality reagents for that order, with no guesswork about which item or rank to pick.

This is an unofficial companion addon and is not affiliated with or endorsed by Auctionator's authors.

Why
---
On the order-creation screen, Blizzard's own "Use Best Quality Reagents" checkbox already picks the best-quality reagent for each slot -- but there's no way to turn that into a shopping list. BestCraft reads the order screen's already-computed reagent choice and builds an Auctionator shopping list from it, for orders you're placing for someone else to craft (recraft orders included).

- **Right quality, no guesswork.** Highest-quality reagent per slot -- except when the recipe's crafted output has no quality tiers of its own, where paying extra buys nothing, so BestCraft picks the cheapest reagent instead.
- **Only what you actually need to buy.** Optional/finishing reagent slots are left off the list entirely; reagents already sitting in your bags, bank, reagent bank, or Warband bank are excluded (or their needed quantity reduced); reagents cheaply available from an NPC vendor are excluded too -- with a chat note explaining what was skipped and why.
- **Builds up, doesn't reset.** Clicking the button for a second order merges into the existing list instead of replacing it -- shared reagents get their quantities summed, not duplicated.
- **Stays current as you shop.** The list updates live as you buy reagents on the Auction House, so it always reflects what's still outstanding.
- **One less manual step per order.** Guild orders default their commission to 1 silver when it's still 0, and Guild/Personal orders default their Minimum Quality requirement to the recipe's highest tier.

Requirements
------------
- [Auctionator](https://www.curseforge.com/wow/addons/auctionator) must be installed and enabled.

Installation
------------
Copy the folder to your World of Warcraft installation:

- Windows: `World of Warcraft\_retail_\Interface\AddOns\BestCraft`

Configuration
-------------
`/bestcraft` (or `/bestcraft options`) opens the options panel -- five settings, all on by default: enabling the order-screen button, a login message, automatically defaulting the order's Minimum Quality to maximum, defaulting a Guild order's commission to 1 silver, and updating the shopping list live as purchases are made. Other commands: `/bestcraft status`, `/bestcraft version`, `/bestcraft reset`, `/bestcraft login [on|off]`, `/bestcraft maxquality [on|off]`, `/bestcraft guildcommission [on|off]`, `/bestcraft updateonpurchase [on|off]`, `/bestcraft help`.

Status
------
Feature-complete for a v1.0.0 release: normal and recraft orders both, via a single Auctionator shopping list that stays in sync as orders are added and reagents are bought, plus an options panel and slash commands. See [open issues](https://github.com/Tharavol/BestCraft/issues) and [milestones](https://github.com/Tharavol/BestCraft/milestones) for progress.

Credits
-------
Interoperates with [Auctionator](https://www.curseforge.com/wow/addons/auctionator) via its public API. Earlier versions queued normal orders into [CraftSim](https://github.com/derfloh205/CraftSim)'s CraftQueue instead of building a shopping list directly; that approach was retired (see `docs/craftsim-recipedata-notes.md`), and CraftSim is no longer a dependency.

License
-------
GPL-3.0-or-later. See [LICENSE](LICENSE).
