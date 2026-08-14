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
  confirmed end-to-end in-game; not yet wired to a button or to `CraftSim.CRAFTQ:AddRecipe`
