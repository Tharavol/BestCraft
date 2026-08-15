# Changelog

All notable changes to the BestCraft addon are documented in this file.

## [Unreleased]

- Initial project scaffolding
- Hook the load-on-demand order addon (`Blizzard_ProfessionsCustomerOrders`) and locate
  `ProfessionsCustomerOrdersFrame.Form` for later milestones to build on (#1)
- Pick the highest-quality reagent per slot from the order's recipe schematic, with no
  independent optimization -- ambiguous slots (multiple choices, no quality tier) are left
  alone rather than guessed at (#2)
- Build a `CraftSim.RecipeData` for the order's recipe with those reagent choices applied,
  via `CraftSimAPI:GetRecipeData` + `RecipeData:SetReagentsByCraftingReagentInfoTbl` (#3) --
  confirmed end-to-end in-game
- Add a "+ CraftQueue" button to the order screen, anchored to `Form.TrackRecipeCheckbox`
  like CraftSim's own equivalent button on the other two screens; enabled only when
  `CraftSim.CRAFTQ:IsRecipeQueueable` agrees; clicking calls `CraftSim.CRAFTQ:AddRecipe`
- Recraft orders: since CraftSim's CraftQueue doesn't support recraft recipes at all, the
  button switches to "+ Shopping List" and builds an Auctionator shopping list directly via
  `Auctionator.API.v1`, using the same highest-quality reagent selection (#18)
- Refuse to queue or build a shopping list when a required reagent slot has no confident
  quality pick, instead of silently omitting it -- the button disables and clicking shows a
  message rather than handing back an incomplete recipeData/shopping list (#4). The native
  "Use Best Quality Reagents" checkbox itself needs no handling: BestCraft never reads it,
  always computing quality directly from the schematic regardless of its state
- Default the order's Minimum Quality dropdown to the recipe's highest real tier
  (`#Form.minQualityIDs`, index 1 being a "None" placeholder) on Guild and Personal orders,
  once per recipe per draft so a manual change back to None isn't re-stomped by a
  reagent-only refresh (#17). Public orders are deliberately left alone -- Blizzard hides the
  dropdown for them and always submits `minCraftingQualityID = 0` regardless
