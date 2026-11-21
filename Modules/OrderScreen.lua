-- OrderScreen.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Finds ProfessionsCustomerOrdersFrame.Form once its load-on-demand addon loads. See
-- docs/order-screen-research.md.

local _, ns = ...

local ORDER_ADDON = "Blizzard_ProfessionsCustomerOrders"

---@class BestCraft.OrderScreen
---@field form table? The order screen's Form once ProfessionsCustomerOrdersFrame exists.
local OrderScreen = { form = nil, formFoundCallbacks = {} }
ns.OrderScreen = OrderScreen

-- Runs callback once the Form is found (immediately if it already has been).
function OrderScreen:OnFormFound(callback)
    if self.form then
        callback(self.form)
        return
    end
    table.insert(self.formFoundCallbacks, callback)
end

local function HookForm()
    if OrderScreen.form then return end
    local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
    if not form then return end
    OrderScreen.form = form
    for _, callback in ipairs(OrderScreen.formFoundCallbacks) do
        callback(form)
    end
    OrderScreen.formFoundCallbacks = {}
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == ORDER_ADDON then
        frame:UnregisterEvent("ADDON_LOADED")
        HookForm()
    end
end)

-- Already loaded, e.g. after /reload with the Crafting Orders window open.
if C_AddOns.IsAddOnLoaded(ORDER_ADDON) then
    HookForm()
end
