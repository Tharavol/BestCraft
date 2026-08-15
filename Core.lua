-- Core.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Entry point. Confirms Auctionator is present -- this addon has nothing to do without it,
-- since every order (recraft or not) is handled by building an Auctionator shopping list --
-- before any feature code runs. CraftSim was an earlier hard dependency (the original design
-- queued normal orders into CraftSim.CRAFTQ); that path was retired in favor of always using
-- Auctionator directly, so CraftSim is no longer required at all. See
-- docs/craftsim-recipedata-notes.md for the retired approach, kept for the record.

local ADDON_NAME, ns = ...

-- Debug/testing access only -- not a stable API. Lets /run reach ns.OrderScreen etc.
-- without a slash command existing yet.
_G.BestCraft = ns

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    frame:UnregisterEvent("ADDON_LOADED")

    if not C_AddOns.IsAddOnLoaded("Auctionator") then
        print("|cffff4444BestCraft|r requires Auctionator to be installed and enabled.")
        return
    end

    ns.ready = true
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)
