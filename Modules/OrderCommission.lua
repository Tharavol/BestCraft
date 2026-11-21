-- OrderCommission.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Defaults the commission on Guild orders to 1 silver while it is still 0 (#22). A 0 tip
-- blocks "Place Order" (PROFESSIONS_ORDER_MUST_TIP), so 0 is never a deliberate choice and no
-- once-per-draft tracking is needed. Blizzard's own market-based default only raises a 0 tip
-- when Public listings exist, so the two don't conflict.
--
-- MoneyInputFrame amounts are in copper.
local COMMISSION_DEFAULT_COPPER = 100

local _, ns = ...

local OrderScreen = ns.OrderScreen

function OrderScreen:ApplyDefaultCommission()
    -- ns.db may not exist yet (see OrderShoppingButton.lua).
    if ns.db and not ns.db.settings.guildCommissionEnabled then
        return
    end

    local form = self.form
    local order = form and form.order
    if not order or form.committed then
        return
    end
    if order.orderType ~= Enum.CraftingOrderType.Guild then
        return
    end

    local tipInput = form.PaymentContainer and form.PaymentContainer.TipMoneyInputFrame
    if not tipInput then
        return
    end

    if tipInput:GetAmount() <= 0 then
        tipInput:SetAmount(COMMISSION_DEFAULT_COPPER)
    end
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function SetupDefaultCommission(form)
    local function Apply() OrderScreen:ApplyDefaultCommission() end

    form:HookScript("OnShow", Apply)
    if form.UpdateReagentSlots then
        hooksecurefunc(form, "UpdateReagentSlots", Apply)
    end

    Apply()
end

OrderScreen:OnFormFound(SetupDefaultCommission)
