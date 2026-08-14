# Constructing a CraftSim.RecipeData for an order-screen recipe

> **Correction (confirmed in-game):** `CraftSim` is never published as a global -- every
> file in CraftSim's own source does `local CraftSim = select(2, ...)`, never a global
> assignment, and `/run print(CraftSim)` from another addon reads `nil`. The real external
> entry point is **`CraftSimAPI`** (`Util/API.lua`), specifically
> `CraftSimAPI:GetRecipeData(options)`, which wraps the exact same constructor options
> documented below. Everywhere below that says `CraftSim.RecipeData(options)`, read
> `CraftSimAPI:GetRecipeData(options)` instead -- kept as originally written since the
> options shape itself is unaffected, only the entry point.

Findings from reading CraftSim's source (`Classes/RecipeData.lua`, `Classes/ProfessionData.lua`)
and the sibling `ShoppingConverter` addon's `Resolver.lua`, which already reverse-engineers part
of this shape to read CraftSim's craft queue back out. Combined with the in-game recon in
`docs/order-screen-research.md`, this is the current best plan for building a `RecipeData` for
an order the player is creating (as customer), not fulfilling.

## The constructor doesn't require the player to have the profession

```lua
---@class CraftSim.RecipeData.ConstructorOptions
---@field recipeID RecipeID
---@field isRecraft? boolean
---@field isWorkOrder? boolean
---@field orderData? CraftingOrderInfo
---@field crafterData? CraftSim.CrafterData  -- default: current player character
---@field forceCache? boolean

CraftSim.RecipeData(options)  -- callable constructor, not :new(options) directly
```

(`CraftSim.RecipeData:new(options)` in `Classes/RecipeData.lua:122` — but the class is a
`CraftSimObject`, invoked as `CraftSim.RecipeData(options)`, same pattern as
`CraftSim.ReagentData(self, schematicInfo)` at `Classes/RecipeData.lua:271`.)

Do **not** pass `isWorkOrder = true` -- that flag makes the constructor pull
`ProfessionsFrame.OrdersPage.OrderView.order` (`RecipeData.lua:189`), which is the
*fulfillment*-side frame, not `ProfessionsCustomerOrdersFrame`. Pass `orderData` directly
instead.

Two load-bearing facts from `ProfessionData:new` (`Classes/ProfessionData.lua:17-64`) and
`RecipeData:new` (`Classes/RecipeData.lua:264`):

- `self.professionInfo` comes from `C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)` --
  a recipeID-keyed global lookup, not tied to whichever profession window the player has open.
- `C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)` has an explicit comment: *"is working
  even if profession is not learned on the character!"*

Both confirm building a `RecipeData` for a recipe the customer doesn't have is a supported,
intended path, not something we'd be forcing through a gap in CraftSim's design.

## SetOrder already applies customer-provided reagents -- for us, for free, maybe

```lua
function CraftSim.RecipeData:SetOrder(orderData)
    self.orderData = GUTIL:CopyTableDeep(orderData or {})
    self.isRecraft = self.orderData.isRecraft
    self.baseOperationInfo = C_TradeSkillUI.GetCraftingOperationInfoForOrder(...)
    self:ApplyOrderReagentsToSlots()
    ...
end

-- Applies optional/finishing/required-selectable reagents from `orderData.reagents` to the
-- recipe's slots. This ensures queued orders always reflect customer-provided optionals
-- (guild/personal/work orders).
function CraftSim.RecipeData:ApplyOrderReagentsToSlots() ... end
```

(`Classes/RecipeData.lua:409-450`, doc comment CraftSim's own.)

If `orderData` is passed to the constructor (or `SetOrder` called after), CraftSim reads
`orderData.reagents` -- Blizzard's own `CraftingOrderInfo.reagents` field, an array of
`CraftingOrderReagentInfo` -- and applies it to the recipe's slots itself. This is already
CraftSim's tested path for guild/personal/work orders per the comment above.

**This means BestCraft may not need to hand-build reagent allocation data at all.** If
`ProfessionsCustomerOrdersFrame.Form.order` is already populated with a `.reagents` array
reflecting the best-quality picks before the order is submitted (unconfirmed -- see below),
the entire integration could be:

```lua
local recipeData = CraftSim.RecipeData({ recipeID = recipeID, orderData = ProfessionsCustomerOrdersFrame.Form.order })
CraftSim.CRAFTQ:AddRecipe({ recipeData = recipeData })
```

## Still open

- **Is `ProfessionsCustomerOrdersFrame.Form.order` populated with `.reagents` while still
  drafting an order (pre-submission)?** This is the single fact that decides how much code
  BestCraft actually needs to write. If yes, the two-line version above may just work. If no
  (order objects might only get real content after a server round-trip on submission), BestCraft
  needs to build a `CraftingOrderReagentInfo`-shaped array itself from
  `transaction:GetAllocations()` / `slot.reagents` + `C_TradeSkillUI.GetItemReagentQualityByItemInfo`
  (both already confirmed working, see `docs/order-screen-research.md`) and pass that as
  `orderData.reagents` instead, still leaning on `ApplyOrderReagentsToSlots` to do the actual
  application.
- Exact shape of a single `CraftingOrderReagentInfo` entry (itemID/quantity/dataSlotIndex field
  names) if BestCraft ends up building the array itself.
- `ReagentData` internal shape confirmed by `ShoppingConverter/Resolver.lua:150-194` (its own
  best-effort reverse-engineering of `CraftSim.CRAFTQ.craftQueue.craftQueueItems`, used to
  recover itemID+quality when converting CraftSim's shopping list): `recipeData.reagentData`
  has `.requiredReagents` (array, each with `.hasQuality` and `.items[qualityID].item`, an Item
  object) and `:GetActiveOptionalReagents()` (method returning optional reagent entries, each
  with `.item`). Not yet needed directly if `SetOrder` handles everything, but documented here
  in case manual construction is required.
