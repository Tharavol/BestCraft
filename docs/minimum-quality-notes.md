# Defaulting the order's Minimum Quality (issue #17)

## Live recon was inconclusive

Initial attempts to confirm `SetMinimumQualityIndex`'s effect in-game watched the wrong
elements: `ProfessionsCustomerOrdersFrame.Form.MinimumQuality` (a plain Frame, only region
child a static "Minimum Quality: " label) and `Form.MinimumQualityIcon` (a bare Texture).
Calling `Form:SetMinimumQualityIndex(5)` followed by `Form:UpdateMinimumQuality()` changed
neither, atomically confirmed with no time gap between before/after reads.

## Resolved by reading Blizzard's actual client source instead

`Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua`, pulled from
[Ketho/wow-ui-source-midnight-ptr](https://github.com/Ketho/wow-ui-source-midnight-ptr)
(matches this project's Midnight client target -- see `order-screen-research.md`'s client
version note). Relevant excerpts:

```lua
self.minQualityIDs = recipeID and C_TradeSkillUI.GetQualitiesForRecipe(recipeID);
```

Not `C_TradeSkillUI.GetRecipeInfo(recipeID).qualityIDs`, which live recon had been reading --
coincidentally similar-looking data, but not what Blizzard's own code calls.

```lua
function ProfessionsCustomerOrderFormMixin:SetupQualityDropdown()
    ...
    for index in ipairs(self.minQualityIDs) do
        local text = index == 1 and NONE or Professions.GetChatIconMarkupForQuality(...);
        CreateRadio(rootDescription, text, index);
    end
end
```

Index 1 is a "None" placeholder in the dropdown, not a real quality tier -- confirmed by the
order-submission code itself:

```lua
newOrderInfo.minCraftingQualityID = self.order.minQuality > 1 and self.minQualityIDs[self.order.minQuality] or 0;
```

So `#minQualityIDs` (the last index) is the highest *real* selectable tier -- that's the value
`OrderMinimumQuality.lua` passes to `SetMinimumQualityIndex`.

```lua
function ProfessionsCustomerOrderFormMixin:UpdateMinimumQuality()
    local showMinQuality = (not self.committed) and self.minQualityIDs
        and self.order.orderType ~= Enum.CraftingOrderType.Public;
    self.MinimumQuality:SetShown(showMinQuality);
end

function ProfessionsCustomerOrderFormMixin:SetMinimumQualityIndex(quality)
    self.order.minQuality = quality;
    local qualityInfo = C_TradeSkillUI.GetRecipeItemQualityInfo(self.order.spellID, quality);
    SetItemCraftingQualityOverlayOverride(self.RecraftSlot.OutputSlot, qualityInfo);
end
```

`SetMinimumQualityIndex` writes `self.order.minQuality` (the real, persisted state) and
updates `RecraftSlot.OutputSlot`'s quality overlay -- neither of which is `MinimumQualityIcon`
or the label region live recon was watching. That's why the live test looked like a no-op:
the visible feedback lives elsewhere (the dropdown's own internal `Dropdown.Text`, a child
*frame* rather than a region, invisible to a plain `:GetRegions()` walk), not in something the
recon commands happened to inspect.

## The dropdown is Guild/Personal, not "Public/Guild"

`UpdateMinimumQuality`'s `showMinQuality` check is `orderType ~= Public` -- the opposite of
issue #17's title, which assumed "Public/Guild". Public orders always submit
`minCraftingQualityID = 0` regardless of `order.minQuality` (see the submission excerpt
above, gated the same way). `OrderMinimumQuality.lua` mirrors this: it's a no-op for Public
orders, live recon on Guild and Personal drafts both showed `MinimumQuality:IsShown() == true`
consistent with this.

## Confirmed live

- `Form.SetMinimumQualityIndex` exists and is callable (confirmed in-game: printed as a real
  function, and visibly pre-selected the chosen tier once the dropdown menu was opened).
- `Form.minQualityIDs` on a real order (a 5-tier profession recipe) was `{4, 5, 6, 7, 8}` --
  five entries, matching `SetupQualityDropdown`'s `ipairs(self.minQualityIDs)` loop, with
  index 1's value (4) unused for real submission purposes (`minQuality > 1` gate).

## Still open

- The end-to-end fix (`Modules/OrderMinimumQuality.lua`) has not been confirmed in-game --
  only its individual building blocks (`SetMinimumQualityIndex` existing and being callable,
  `minQualityIDs`'s shape) were. Needs an in-game smoke test: open a Guild or Personal order
  draft for a multi-tier recipe and confirm the dropdown shows the highest tier selected
  without manual interaction, and that switching recipes re-defaults correctly.
