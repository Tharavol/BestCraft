-- OrderScreen.lua
-- SPDX-License-Identifier: MIT
--
-- Hooks the load of Blizzard's load-on-demand Crafting Orders customer frame
-- (ProfessionsCustomerOrdersFrame), so later milestones have a safe, confirmed point to
-- attach reagent-reading and button-creation code to. See docs/order-screen-research.md
-- for how this frame was identified.

local _, ns = ...

local ORDER_ADDON = "Blizzard_ProfessionsCustomerOrders"

---@class BestCraft.OrderScreen
---@field form table? The order screen's Form once ProfessionsCustomerOrdersFrame exists.
local OrderScreen = { form = nil }
ns.OrderScreen = OrderScreen

local function HookForm()
    if OrderScreen.form then return end
    local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
    if not form then return end
    OrderScreen.form = form
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
