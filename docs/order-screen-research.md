# Place Crafting Order screen: frame research

Findings from in-game `/framestack` and `/run` probes against the customer-side order
screen, on a Midnight-beta client (`professionInfo.expansionName == "Midnight"`,
`professionID = 2909`). Captured here so it survives past the session that produced it.

## The screen is not `ProfessionsFrame`

The "Place Crafting Order" window (title bar, round player portrait, Back button --
NPC-interaction chrome) is the standalone global frame **`ProfessionsCustomerOrdersFrame`**.
It is not a child of `ProfessionsFrame`, and CraftSim's existing hooks (which only touch
`ProfessionsFrame.CraftingPage.SchematicForm` and
`ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm` -- see CraftSim's
`Modules/CraftQueue/UI.lua:2106-2118`, the fulfillment-side `+ CraftQueue` button) never
touch this frame. No overlap, no conflict, but also nothing to build on top of there.

## Structure

```
ProfessionsCustomerOrdersFrame
└── Form
    ├── ReagentContainer.Reagents        -- reagent slot buttons (anonymous/pooled)
    ├── AllocateBestQualityCheckbox      -- native "Use Best Quality Reagents" toggle (default ON)
    ├── TrackRecipeCheckbox              -- anchor point CraftSim uses for its own button elsewhere
    ├── PaymentContainer.ListOrderButton -- the actual "Place Order" submit button
    ├── MinimumQualityIcon / MinimumQuality
    ├── LeftPanelBackground / RightPanelBackground
    └── transaction                      -- see below
    order                                -- current order data (nil while creating a new order)
    reagentSlotPool
```

Confirmed via:
```
/run print(ProfessionsFrame.OrdersPage.OrderView:IsVisible())      --> false (wrong frame)
/run print(ProfessionsCustomerOrdersFrame.Form.transaction ~= nil) --> true
```

## `Form.transaction` is the standard reagent transaction object

`ProfessionsCustomerOrdersFrame.Form.transaction` exposes the same
`ProfessionCraftingReagentTransaction`-shaped API CraftSim already reads/writes on the other
two screens (`GetAllocations`, `OverwriteAllocation`, `GetRecipeSchematic`,
`GetReagentSlotSchematic`, `CreateCraftingReagentInfoTbl`, `EnumerateAllocations`, etc. --
full enumerated list from `pairs()` is in the project history, not reproduced here). This
means there is no bespoke reagent-allocation API to reverse-engineer for this screen --
CraftSim's own `RecipeData`/`ReagentData` handling patterns should be directly reusable
against this transaction object instead of writing a parallel implementation.

## The native "Use Best Quality Reagents" checkbox already answers "best quality"

`AllocateBestQualityCheckbox` is checked by default. Its tooltip: *"Uncheck to always use the
lowest quality reagents available."* -- i.e. it's a binary best/worst toggle, not a
cost-aware optimizer. But because it's on by default, `transaction:GetAllocations()` at the
point the player opens this screen already holds Blizzard's own best-quality pick for every
slot -- including slots at 0 owned (the screen still shows a specific item icon for an
unowned reagent, meaning the choice of *which item*, not just *which quality tier*, is
already resolved).

**Implication for the addon:** no independent quality-selection algorithm is needed -- this
part held up. The original plan for what to *do* with that reading (translate into
`CraftSim.CRAFTQ:AddRecipe(options)`) was later retired in favor of building an Auctionator
shopping list directly for every order; see `docs/craftsim-recipedata-notes.md` and
`Modules/OrderShoppingList.lua`. This is (and remains) a translator between two data shapes,
not an optimizer -- just a different destination shape now.

## Still open (implementation-time work, not further recon)

The first two items below were about the CraftQueue-based plan and are moot now that that
whole path is retired (see the note above) -- kept for the record, not because they're still
open.

- ~~Exact shape `transaction:GetAllocations()` / `EnumerateAllocations()` returns, and how to
  map it into a `CraftSim.CraftingReagentInfo`-style table.~~
- ~~How to construct a `CraftSim.RecipeData` around a `recipeID` sourced from this order
  screen (`ProfessionsCustomerOrdersFrame.Form.order` when viewing an existing draft) rather
  than from `CraftSim.MODULES.recipeData` (which is only populated from the two screens
  CraftSim itself hooks).~~
- ~~`ProfessionsCustomerOrdersFrame` is provided by the load-on-demand
  `Blizzard_ProfessionsCustomerOrders` addon; confirm whether hooking on `ADDON_LOADED` for
  that addon name is sufficient, or whether the frame needs an `OnShow` hook too (mirroring
  how CraftSim's own `Init.lua` handles `ProfessionsFrame.OrdersPage`).~~ Confirmed sufficient:
  every module (`OrderShoppingButton.lua`, `OrderMinimumQuality.lua`, `OrderCommission.lua`)
  hooks through `OrderScreen:OnFormFound`, itself driven purely by the `ADDON_LOADED` gate in
  `OrderScreen.lua`, and all of them have worked correctly across many in-game sessions through
  v0.4.0 -- no `OnShow` hook on the frame itself has ever been needed.
