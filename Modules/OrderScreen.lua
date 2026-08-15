-- OrderScreen.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Hooks the load of Blizzard's load-on-demand Crafting Orders customer frame
-- (ProfessionsCustomerOrdersFrame), so later milestones have a safe, confirmed point to
-- attach reagent-reading and button-creation code to. See docs/order-screen-research.md
-- for how this frame was identified.

local _, ns = ...

local ORDER_ADDON = "Blizzard_ProfessionsCustomerOrders"

---@class BestCraft.OrderScreen
---@field form table? The order screen's Form once ProfessionsCustomerOrdersFrame exists.
local OrderScreen = { form = nil, formFoundCallbacks = {} }
ns.OrderScreen = OrderScreen

-- Registers a callback to run once the order screen's Form is found (immediately, if it
-- already has been). Needed because the Form is only known to exist after an ADDON_LOADED
-- event this module already listens for -- other modules (e.g. the queue button) can't
-- assume OrderScreen.form is set yet at their own file's load time.
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

-- The order addon may already be loaded by the time this file runs, e.g. reloading the
-- UI while the Crafting Orders window is already open.
if C_AddOns.IsAddOnLoaded(ORDER_ADDON) then
    HookForm()
end
