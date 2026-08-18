# Changelog

All notable changes to the BestCraft addon are documented in this file.

## [Unreleased]

- Initial project scaffolding
- Hook the load-on-demand order addon (`Blizzard_ProfessionsCustomerOrders`) and locate
  `ProfessionsCustomerOrdersFrame.Form` for later milestones to build on (#1)
- Pick the highest-quality reagent per slot from the order's recipe schematic, with no
  independent optimization -- ambiguous slots (multiple choices, no quality tier) are left
  alone rather than guessed at (#2)
- Add a "+ Shopping List" button to the order screen, anchored to the bottom-right of
  `ProfessionsCustomerOrdersFrame` itself -- mirroring exactly how the Profession Shopping
  List addon anchors its own "Core Alloy" quick-reorder button, confirmed by reading that
  addon's actual source (three earlier anchor points measured pixels against a screenshot of
  that button while anchoring to something else entirely, so nothing converged -- see
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
- Relicensed from MIT to GPL-3.0-or-later, now that CraftSim (MIT-licensed) is no longer a
  dependency or a source of any code this addon builds on
- Add a tooltip to the shopping-list button, matching this screen's own convention
  (`GameTooltip_AddNormalLine`/`AddErrorLine`, confirmed against Blizzard's client source):
  explains what it does when enabled, and why it's disabled when it isn't (#8)
- Move every user-facing string into `Locales/enUS.lua` (a plain `ns.L` table), structured for
  future translation even though enUS is the only locale shipped for now (#9). Along the way,
  collapsed two pairs of near-duplicate literals that had been typed out separately in the
  tooltip and click-failure paths but were word-for-word identical
- Add `/bestcraft` slash commands (`options`/`config`/`gui`, `status`, `version`, `reset`,
  `login [on|off]`, `help`) and an options panel (enable/disable the order-screen button,
  toggle a login version message), plus `BestCraftDB` saved variables -- matching Crosshairs'
  and ShoppingConverter's own Commands/Options.lua conventions rather than inventing new ones
  (#16). The button-enabled setting is checked defensively (`ns.db and not ...`, not just
  `not ...`): if `Blizzard_ProfessionsCustomerOrders` is already loaded by the time BestCraft's
  own files start executing, the order-screen button can be created before Core.lua's own
  `ADDON_LOADED` handler (and thus `ns.db`) exists yet
- Add a third setting/checkbox/`/bestcraft maxquality [on|off]` command to turn off
  automatically defaulting the order's Minimum Quality to maximum (issue #17's feature) --
  on by default, matching that feature's original always-on behavior before this became
  optional. Same defensive `ns.db and not ...` guard as buttonEnabled, for the same
  load-order reason, and checked before touching the per-recipe "already applied" tracking so
  re-enabling mid-draft doesn't leave a recipe permanently skipped
- Confirmed in-game and changed per feedback: turning off "Enable the order-screen shopping
  list button" now hides the button entirely (`Hide()`/`Show()`) instead of graying it out --
  a deliberate "don't show this" choice, unlike the other (still grayed-out-with-tooltip)
  reasons the button can be temporarily unusable (no Auctionator, unresolved reagent)
- Toggling "Enable the order-screen shopping list button" (or running `/bestcraft reset`) now
  shows/hides the button immediately if the order window is already open, rather than only
  taking effect the next time it's closed and reopened -- confirmed in-game that the button
  didn't update live, since it only re-evaluated on the order screen's own OnShow/
  UpdateReagentSlots events, neither of which fires just because a setting changed elsewhere.
  `ns.RefreshShoppingButton` exposes the button's own refresh function for exactly this
- Print a chat confirmation on a successful shopping list, not just on failure -- the recipe
  name and a "Name [xN], ..." summary of every material added, per feedback ("what was added
  and why"). `CreateShoppingList` now returns a message on both outcomes; the click handler
  just prints whatever comes back rather than branching on success/failure
- Prefer the *lowest*-quality reagent per slot instead of the highest, for a recipe whose
  crafted output has no quality tiers of its own -- confirmed against a real order (Thalassian
  Treatise on Enchanting) that paying for premium reagents buys nothing there, since the
  result can't rank up regardless. Detected via `Form.minQualityIDs` (the same per-recipe data
  issue #17 already reads), and only when that data is confirmed to show no real tier --
  *not* merely when it isn't known yet, which stays on the historical highest-quality default
  as the safer failure mode. `GetBestQualityReagentEntries` renamed to `GetChosenReagentEntries`
  to keep the name honest now that "best" doesn't always mean highest
- Fixed: the lowest-quality-reagent preference above never actually triggered for a genuinely
  unranked recipe on a Public order (issue #19) -- `C_TradeSkillUI.GetQualitiesForRecipe`
  confirmed in-game to return `nil` outright for a recipe with no quality tiers, not a
  length-1 table, so the old `minQualityIDs ~= nil and #minQualityIDs <= 1` guard silently fell
  through to the highest-quality default on exactly the recipes it was meant to catch. `nil` is
  now treated the same as "confirmed no real tier"
- Exclude reagents that are cheaply available from an NPC vendor from the shopping list, with a
  chat note explaining what was skipped and why (issue #20) -- confirmed in-game that
  Auctionator can find real AH listings for these too, but paying that price is pointless when
  a vendor sells the same item directly for less. No client API answers "is this vendor-sold"
  directly (`sellPrice` is what a vendor *pays you*, not evidence a vendor *sells* it, and
  item class/subclass/bindType/orderSource all came back identical between a real vendor-sold
  reagent and the recipe's other, genuinely AH-only ones) -- detected instead via
  `Auctionator.API.v1.GetVendorPriceByItemID` (Auctionator's own maintained vendor-price
  database, the same data behind its "cheaper than vendor" AH tags), falling back to
  `C_TooltipInfo.GetItemByID` and scanning for "vendor" in the item's own flavor text for
  whatever that database doesn't cover (Blizzard's own tooltip says "Can be purchased from
  vendors." for these, confirmed side-by-side against an AH-only reagent from the same recipe)
- Exclude reagents already owned (bags, bank, reagent bank, Warband bank) from the shopping
  list, reducing the needed quantity by what's already owned rather than shopping for the full
  amount every time (issue #23) -- via `C_Item.GetItemCount(itemID, true, false, true, true)`,
  the same argument shape confirmed in use across CraftSim's own source. A fully-covered
  reagent is skipped entirely and named in the same "Skipped X -- ..." chat note #20 introduced
  ("already own enough"), rather than silently shrinking the list with no explanation
- Building a shopping list for a second order now merges into the first order's list instead of
  discarding it (issue #24): a reagent both orders need gets its quantity summed rather than
  duplicated as a second line item, and a reagent only one order needs is simply added.
  Confirmed working via `Auctionator.API.v1.GetShoppingListItems`/`ConvertFromSearchString`/
  `ConvertToSearchString`/`CreateShoppingList` -- the same read-compare-write pattern CraftSim's
  own `AddSearchTermToShoppingList` uses (`Modules/Shopping/Shopping.lua:135-189`), generalized
  here into signed-quantity deltas so multiple entries merge in one pass. Re-clicking the button
  for the *same* order updates that order's own line items instead of doubling them on every
  click -- each order's last contribution is tracked (weak-keyed by the order object, the same
  pattern `OrderMinimumQuality.lua` already uses for its own per-draft state) and undone before
  the new contribution merges in, preserving the idempotency the old delete-then-recreate
  approach gave a single order while extending real merging to genuinely different orders
- Fixed: optional/finishing reagent slots (`reagentSlotSchematic.required == false` --
  embellishments and the like) were going onto the shopping list whenever they happened to
  resolve to an unambiguous pick, even though they're not something the recipe actually needs
  (issue #25) -- `GetChosenReagentEntries` checked `required` only to decide whether an
  *unresolved* slot should block the button, never to decide whether a *resolved* one belonged
  on the list at all. Confirmed by testing #23/#24 against a real order with a single-option
  optional slot. Now gated on `slot.required` up front, so an optional slot is never considered
  for the list regardless of how confidently it would otherwise resolve
