# Constructing a CraftSim.RecipeData for an order-screen recipe

**Retired.** This approach (`Modules/OrderRecipeData.lua`, since deleted) queued normal orders
into `CraftSim.CRAFTQ` while only recraft orders (which `CraftSim.CRAFTQ` refuses outright) got
an Auctionator shopping list. It worked, confirmed in-game (issue #18) -- but per feedback, a
single shopping-list-only flow for every order (`Modules/OrderShoppingList.lua`) is simpler and
is what's wanted, so this whole path (and the CraftSim dependency it required) was dropped.
Kept here for the record, same as this doc's own "What didn't work" section below.

## Former approach (was implemented in Modules/OrderRecipeData.lua)

```lua
local recipeData = CraftSimAPI:GetRecipeData({ recipeID = recipeID, isRecraft = isRecraft })
recipeData:SetReagentsByCraftingReagentInfoTbl(craftingReagentInfoTbl)
-- craftingReagentInfoTbl: { { reagent = { itemID = X }, quantity = N }, ... }
```

No `orderData` is passed to the constructor. Two corrections below explain why, both found
by running the straightforward-looking version in-game and reading the actual error instead
of assuming it would work.

### Correction 1: use CraftSimAPI, not the internal CraftSim table

`CraftSim` is never published as a global -- confirmed in-game (`/run print(CraftSim)` from
another addon's context reads `nil`) and confirmed by grepping CraftSim's own source: every
file does `local CraftSim = select(2, ...)`, never a global assignment. The real external
entry point is **`CraftSimAPI`** (`Util/API.lua`), which exposes:

```lua
function CraftSimAPI:GetRecipeData(options) return CraftSim.RecipeData(options) end
function CraftSimAPI:GetCraftSim() return CraftSim end  -- full internal table, if ever needed
```

`GetRecipeData` wraps the exact same constructor options documented below, so this only
changes the entry point, not the options shape.

### Correction 2: don't pass `orderData` -- SetOrder needs a real, submitted order

The original plan (see "What didn't work" below) was to pass `orderData = { reagents = ... }`
to the constructor and let `RecipeData:SetOrder()` apply it. Confirmed in-game this throws:

```
attempt to index global 'CraftSim' ...   -- (before Correction 1 was found)
bad argument #3 to '?' (Usage: local info = C_TradeSkillUI.GetCraftingOperationInfoForOrder(
    recipeID, craftingReagents, orderID, applyConcentration))
```

`RecipeData:SetOrder(orderData)` unconditionally calls
`C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipeID, {}, self.orderData.orderID, ...)`
(`Classes/RecipeData.lua:412-413`). A draft order being created on
`ProfessionsCustomerOrdersFrame` has no `orderID` yet -- that's only assigned after a server
round-trip on submission -- so `self.orderData.orderID` is `nil` and the API rejects it. This
path only works for an *already-submitted* order (which matches its doc comment: "guild/
personal/work orders" -- all cases where a real order already exists).

### The working alternative: SetReagentsByCraftingReagentInfoTbl

```lua
---@param craftingReagentInfoTbl CraftingReagentInfo[]
function CraftSim.RecipeData:SetReagentsByCraftingReagentInfoTbl(craftingReagentInfoTbl)
    ...
    self:SetOptionalReagents(optionalReagentIDs)
    local reagentListItems = GUTIL:Map(requiredReagents, function(craftingReagentInfo)
        return CraftSim.ReagentListItem(craftingReagentInfo.reagent.itemID, craftingReagentInfo.quantity,
            craftingReagentInfo.reagent.currencyID)
    end)
    self:SetReagents(reagentListItems)
end
```

(`Classes/RecipeData.lua:494-520`.) This only touches reagent allocation -- no order object,
no `GetCraftingOperationInfoForOrder` call. `SetReagents` (`RecipeData.lua:470-491`) walks
`self.reagentData.requiredReagents`, and for each slot's possible item variants
(`reagent.items`, keyed by the item's own itemID -- both a plain basic reagent and each
quality rank of a ranked reagent live here, distinguished by `.hasQuality`), matches against
the passed list by itemID and sets that specific item's quantity. Passing our chosen
highest-quality itemID with its slot's `quantityRequired` allocates the full required amount
to that specific rank, leaving the other ranks at zero -- which is exactly "pick the best
rank, no partial-quality guesswork."

`CraftSim.OPTIONAL_REAGENT_DATA` (`Data/OptionalReagentData.lua`, ~3450 lines) is a static
list of known optional/finishing reagent itemIDs (things like enchant essences) used to route
entries into `SetOptionalReagents` instead of `SetReagents`. Our modifying/quality-ranked
itemIDs are a different category and shouldn't collide with it, though this hasn't been
independently confirmed beyond "the in-game test didn't complain."

## What didn't work: the orderData/SetOrder path

Kept for the record, so nobody re-tries this. The `RecipeData.ConstructorOptions` type does
have an `orderData? CraftingOrderInfo` field, and `RecipeData:SetOrder()` /
`ApplyOrderReagentsToSlots()` (`RecipeData.lua:409-463`) genuinely does apply
`orderData.reagents` to a recipe's slots -- this is real, tested CraftSim code, just for a
different situation (an order that already exists) than ours (a draft that doesn't exist yet).

Also checked and ruled out along the way: `ProfessionsCustomerOrdersFrame.Form.order` exists
as a table pre-submission, but its `.reagents` field is `nil` at that point -- confirmed
in-game -- so there was never a "free" version of this path available for a draft order
regardless of the `SetOrder` issue above.

## Confirmed end-to-end in-game

Walked `rd.reagentData.requiredReagents` after a real `BuildRecipeData()` call: every
quality-ranked slot has the higher-ranked item variant at its full required quantity and the
lower rank at zero; single-variant basic slots got their full required quantity directly.
`SetReagentsByCraftingReagentInfoTbl` does exactly what its use here needed.

## Still open

- Whether the resulting `recipeData` behaves correctly once handed to
  `CraftSim.CRAFTQ:AddRecipe` (does its shopping-list generation pick up these reagent
  choices the same way it would for a normally-queued recipe?) -- needs an in-game check
  once that wiring exists.
- Recraft orders specifically (issue #15): schematic shape was already confirmed to need no
  special handling (see `docs/order-screen-research.md`), but this construction path hasn't
  been tried against a real recraft order yet.
- `ReagentData` internal shape as reverse-engineered by `ShoppingConverter/Resolver.lua:150-194`
  (`recipeData.reagentData.requiredReagents[n].items[qualityID].item`,
  `reagentData:GetActiveOptionalReagents()`) -- not needed directly given the above, but
  documented here in case a future issue needs to read a RecipeData back out rather than
  build one.
