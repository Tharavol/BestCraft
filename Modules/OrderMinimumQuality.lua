-- OrderMinimumQuality.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Defaults the "Minimum Quality" dropdown to the recipe's highest tier, once per recipe per
-- draft (#17). Form.minQualityIDs index 1 is a "None" placeholder, so #minQualityIDs is the
-- highest real tier (Blizzard_ProfessionsCustomerOrdersForm.lua; see
-- docs/minimum-quality-notes.md). Public orders hide the dropdown and always submit 0, so
-- they are skipped.

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- Last spellID applied per draft, so a reagent-only refresh doesn't undo a player's choice of
-- None; only a recipe change re-arms it. Weak-keyed so closed drafts don't linger.
local lastAppliedSpellIDByOrder = setmetatable({}, { __mode = "k" })

function OrderScreen:ApplyDefaultMinimumQuality()
    -- ns.db may not exist yet (see OrderShoppingButton.lua). Checked before
    -- lastAppliedSpellIDByOrder so re-enabling mid-draft applies on the next refresh.
    if ns.db and not ns.db.settings.maxQualityEnabled then
        return
    end

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
