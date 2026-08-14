-- Core.lua
-- SPDX-License-Identifier: MIT
--
-- Entry point. Confirms CraftSim is present -- this addon has nothing to do without it --
-- before any feature code runs. The actual order-screen button and CraftQueue integration
-- land in later milestones; see https://github.com/Tharavol/BestCraft/milestones

local ADDON_NAME, ns = ...

-- Debug/testing access only -- not a stable API. Lets /run reach ns.OrderScreen etc.
-- without a slash command existing yet.
_G.BestCraft = ns

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    frame:UnregisterEvent("ADDON_LOADED")

    if not C_AddOns.IsAddOnLoaded("CraftSim") then
        print("|cffff4444BestCraft|r requires CraftSim to be installed and enabled.")
        return
    end

    ns.ready = true
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)
