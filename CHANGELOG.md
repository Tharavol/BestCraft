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
  `Auctionator.API.v1`, using the same highest-quality reagent selection
