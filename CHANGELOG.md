# Changelog

All notable changes to the BestCraft addon are documented in this file.

## [Unreleased]

- Initial project scaffolding
- Hook the load-on-demand order addon (`Blizzard_ProfessionsCustomerOrders`) and locate
  `ProfessionsCustomerOrdersFrame.Form` for later milestones to build on (#1)
- Pick the highest-quality reagent per slot from the order's recipe schematic, with no
  independent optimization -- ambiguous slots (multiple choices, no quality tier) are left
  alone rather than guessed at (#2)
- Add a "+ Shopping List" button to the order screen, below `Form.PaymentContainer.ListOrderButton`
  (three earlier anchor points collided with other addons or the window's own edge -- see
  `Modules/OrderShoppingButton.lua`'s header comment for the full trail). Builds an
  Auctionator shopping list via `Auctionator.API.v1`, for every order -- recraft or not (#18).
  Earlier versions split this into two modes: normal orders queued into `CraftSim.CRAFTQ`
  (via a `CraftSim.RecipeData` built through `CraftSimAPI:GetRecipeData`, #3), and only
  recraft orders (which `CraftSim.CRAFTQ` refuses outright) got the Auctionator path. That
  split was retired in favor of a single shopping-list-only flow for every order, so CraftSim
  is no longer a dependency at all -- see `docs/craftsim-recipedata-notes.md` for the retired
  approach, kept for the record
- Refuse to build a shopping list when a required reagent slot has no confident quality pick,
  instead of silently omitting it -- the button disables and clicking shows a message rather
  than handing back an incomplete shopping list (#4). The native "Use Best Quality Reagents"
  checkbox itself needs no handling: BestCraft never reads it, always computing quality
  directly from the schematic regardless of its state
- Default the order's Minimum Quality dropdown to the recipe's highest real tier
  (`#Form.minQualityIDs`, index 1 being a "None" placeholder) on Guild and Personal orders,
  once per recipe per draft so a manual change back to None isn't re-stomped by a
  reagent-only refresh (#17). Public orders are deliberately left alone -- Blizzard hides the
  dropdown for them and always submits `minCraftingQualityID = 0` regardless
- Exclude two kinds of reagent that can never actually be bought, rather than putting them on
  the shopping list: slots sourced from the crafter (`reagentSlotSchematic.orderSource ==
  Enum.CraftingOrderReagentSource.Crafter` -- the crafter's own personal-supply materials, not
  the customer's to provide), and bind-on-pickup items regardless of who's meant to supply
  them (`C_Item.GetItemInfo`'s 14th return value == `Enum.ItemBind.OnAcquire`). Confirmed
  in-game against a real order: "Fused Vitality" was Customer-sourced (so the orderSource
  check alone missed it) but returned zero Auctionator search results -- it's simply BoP.
  Neither exclusion blocks the button/shopping list over what remains resolvable
