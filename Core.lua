-- Core.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Entry point: saved variables, ns.Print/ns.VERSION, login message, Auctionator check.
-- DB init is not gated on Auctionator so options and slash commands still work without it;
-- only ns.ready (the order-screen button's gate) is.

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME

-- Debug/testing access only, not a stable API.
_G.BestCraft = ns

local L = ns.L

function ns.Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print(L.CHAT_PREFIX .. msg)
end

-- One leading "v", or "dev" when @project-version@ was never substituted (git clone).
function ns.FormatVersion(raw)
    if type(raw) ~= "string" or raw == "" or raw:match("^@.-@$") then
        return "dev"
    end
    if raw:match("^[vV]") then
        return raw
    end
    return "v" .. raw
end

ns.VERSION = ns.FormatVersion(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))

--------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------

ns.DEFAULT_SETTINGS = {
    buttonEnabled = true,
    printOnLogin = false,
    maxQualityEnabled = true,
    guildCommissionEnabled = true,
    updateOnPurchaseEnabled = true,
}

local function InitializeDB()
    BestCraftDB = BestCraftDB or {}
    local db = BestCraftDB

    db.settings = db.settings or {}
    for key, value in pairs(ns.DEFAULT_SETTINGS) do
        if db.settings[key] == nil then
            db.settings[key] = value
        end
    end

    ns.db = db
end

function ns.ResetToDefaults()
    for key, value in pairs(ns.DEFAULT_SETTINGS) do
        ns.db.settings[key] = value
    end
    if ns.Options and ns.Options.RefreshWidgets then
        ns.Options:RefreshWidgets()
    end
    -- The order window may already be open.
    if ns.RefreshShoppingButton then
        ns.RefreshShoppingButton()
    end
    ns.Print(L.CMD_SETTINGS_RESET)
end

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    frame:UnregisterEvent("ADDON_LOADED")

    InitializeDB()

    if not C_AddOns.IsAddOnLoaded("Auctionator") then
        ns.Print(L.CORE_REQUIRES_AUCTIONATOR)
        return
    end

    ns.ready = true
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        -- Not after "requires Auctionator" was already printed.
        if ns.ready and ns.db.settings.printOnLogin then
            ns.Print(L.CORE_LOGIN_MESSAGE, ns.VERSION)
        end
    end
end)

--------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------

SLASH_BESTCRAFT1 = "/bestcraft"
SlashCmdList["BESTCRAFT"] = function(input)
    ns.Commands:Dispatch(input)
end
