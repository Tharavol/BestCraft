-- OrderCommission.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Defaults the order screen's commission (tip) to 1 silver on Guild orders whenever it's still
-- 0 (issue #22).
--
-- Confirmed by reading Blizzard's actual client source for this expansion (Ketho/
-- wow-ui-source-midnight-ptr, matching this project's Midnight target -- see
-- docs/order-screen-research.md's client version note), specifically
-- Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua:
--
--   self.PaymentContainer.TipMoneyInputFrame:SetOnValueChangedCallback(
--       GenerateClosure(self.UpdateTotalPrice, self));
--   ...
--   function ...:UpdateListOrderButton()
--       ...
--       elseif self.PaymentContainer.TipMoneyInputFrame:GetAmount() <= 0 then
--           enabled = false;
--           errorText = PROFESSIONS_ORDER_MUST_TIP;
--
-- A tip of 0 already blocks "Place Order" outright, for every order type -- so there's no
-- submittable state this addon takes away by nudging 0 up to 1 silver. Unlike Minimum
-- Quality's "None" (a real, persistent choice OrderMinimumQuality.lua deliberately doesn't
-- re-stomp), 0 tip is never a destination, only a starting point that has to change before
-- the order can be placed at all -- so this doesn't need that module's "already applied once"
-- tracking; it's safe to just keep checking "is it still 0" on every relevant refresh.
--
-- Guild-order-only, per the request that prompted this: Public orders usually already have a
-- market of existing listings for Blizzard's own commission suggestion (below) to work from,
-- and Personal orders are typically a pre-arranged price with a specific person, not a flat
-- default. Blizzard's client actually already tries a smarter, market-based default for every
-- non-recraft order type, Guild included --
--
--   function ...:RequestCurrentListingsForCommission()
--       local request = { orderType = Enum.CraftingOrderType.Public, ... }
--       ...
--       if #orders > 0 and self.PaymentContainer.TipMoneyInputFrame:GetAmount() == 0 then
--           local defaultCommission = math.min(topPayingOrder.tipAmount + 100, maxGold);
--           self.PaymentContainer.TipMoneyInputFrame:SetAmount(defaultCommission);
--       end
--
-- -- but only fires (async, after a server round trip) when *Public* listings for that recipe
-- exist to compare against; it's a no-op and leaves the tip at 0 otherwise. This addon's flat
-- 1-silver default only ever matters as the fallback for that empty-market case -- confirmed
-- in-game not yet, but the two can't meaningfully conflict: Blizzard's own default only ever
-- raises a still-0 tip, same direction as this one, and any order this addon actually changes
-- is one Blizzard's own request already had nothing to suggest for.
--
-- 100 copper = 1 silver -- MoneyInputFrame's GetAmount()/SetAmount() are always in copper.
local COMMISSION_DEFAULT_COPPER = 100

local _, ns = ...

local OrderScreen = ns.OrderScreen

-- Exposed on OrderScreen (rather than kept local-only) so tests can call it directly against
-- a hand-built fake form, the same pattern as the rest of this addon's testable logic.
function OrderScreen:ApplyDefaultCommission()
    -- Guarded on ns.db existing at all, not just the setting -- same reasoning as
    -- OrderMinimumQuality.lua's own maxQualityEnabled check: if Blizzard_ProfessionsCustomerOrders
    -- was already loaded by the time BestCraft's own files started executing, this can run
    -- (via OnFormFound's eager callback) before Core.lua's own ADDON_LOADED handler -- and thus
    -- ns.db -- exists yet. Falls through rather than treating "not yet known" as "disabled",
    -- matching ns.DEFAULT_SETTINGS.guildCommissionEnabled = true.
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
