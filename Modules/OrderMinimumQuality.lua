-- OrderMinimumQuality.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Defaults the order screen's "Minimum Quality" dropdown to the recipe's highest available
-- tier, once per recipe per draft, so the crafter is required to deliver best quality by
-- default (issue #17) -- the same "just the highest, no guesswork" idea as the reagent
-- selection in OrderReagents.lua, applied to the order's own quality requirement instead.
--
-- Unlike the reagent-selection work, live in-game recon of SetMinimumQualityIndex's effect
-- was inconclusive -- it doesn't touch MinimumQualityIcon or the label that was being watched
-- at all, so calling it appeared to do nothing. This was instead confirmed by reading
-- Blizzard's actual client source for this expansion (Ketho/wow-ui-source-midnight-ptr,
-- matching this project's Midnight target -- see docs/order-screen-research.md's client
-- version note), specifically
-- Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua:
--
--   self.minQualityIDs = recipeID and C_TradeSkillUI.GetQualitiesForRecipe(recipeID)
--
--   function ...:SetupQualityDropdown()
--       ...
--       for index in ipairs(self.minQualityIDs) do
--           local text = index == 1 and NONE or ...
--           ...
--       end
--   end
--
--   function ...:UpdateMinimumQuality()
--       local showMinQuality = (not self.committed) and self.minQualityIDs
--           and self.order.orderType ~= Enum.CraftingOrderType.Public
--       self.MinimumQuality:SetShown(showMinQuality)
--   end
--
--   function ...:SetMinimumQualityIndex(quality)
--       self.order.minQuality = quality
--       local qualityInfo = C_TradeSkillUI.GetRecipeItemQualityInfo(self.order.spellID, quality)
--       SetItemCraftingQualityOverlayOverride(self.RecraftSlot.OutputSlot, qualityInfo)
--   end
--
-- Index 1 is a "None" placeholder, not a real tier -- confirmed by the order-submission code
-- itself: `minCraftingQualityID = order.minQuality > 1 and minQualityIDs[order.minQuality] or 0`.
-- So `#minQualityIDs` (the last index) is the highest *real* selectable tier, which is what
-- SetMinimumQualityIndex below is called with.
--
-- The dropdown is shown for Guild and Personal orders and hidden for Public orders --
-- backwards from issue #17's title, which assumed "Public/Guild". Public orders always submit
-- minCraftingQualityID = 0 regardless of order.minQuality (see UpdateMinimumQuality above and
-- the submission code's own orderType check), so this deliberately does nothing for them.

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- Tracks the last recipe (spellID) this was applied for, per order draft object, so a
-- reagent-only refresh (UpdateReagentSlots also fires for those, not just recipe changes --
-- see OrderShoppingButton.lua's own comment on why it hooks that method) doesn't re-stomp a
-- minimum quality the player deliberately changed back to None. Only an actual recipe change
-- on the same draft re-arms it. Weak-keyed so closed drafts don't linger.
local lastAppliedSpellIDByOrder = setmetatable({}, { __mode = "k" })

-- Exposed on OrderScreen (rather than kept local-only) so tests can call it directly against
-- a hand-built fake form, the same pattern as the rest of this addon's testable logic.
function OrderScreen:ApplyDefaultMinimumQuality()
    local form = self.form
    local order = form and form.order
    if not order or form.committed then
        return
    end
    if order.orderType == Enum.CraftingOrderType.Public then
        return
    end

    local minQualityIDs = form.minQualityIDs
    if not minQualityIDs or #minQualityIDs <= 1 then
        return
    end

    if lastAppliedSpellIDByOrder[order] == order.spellID then
        return
    end
    lastAppliedSpellIDByOrder[order] = order.spellID

    if not order.minQuality or order.minQuality <= 1 then
        form:SetMinimumQualityIndex(#minQualityIDs)
    end
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function SetupMinimumQualityDefault(form)
    local function Apply() OrderScreen:ApplyDefaultMinimumQuality() end

    form:HookScript("OnShow", Apply)
    if form.UpdateReagentSlots then
        hooksecurefunc(form, "UpdateReagentSlots", Apply)
    end

    Apply()
end

OrderScreen:OnFormFound(SetupMinimumQualityDefault)
