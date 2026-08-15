-- Core.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Entry point. Confirms Auctionator is present -- this addon has nothing to do without it,
-- since every order (recraft or not) is handled by building an Auctionator shopping list --
-- before any feature code runs. CraftSim was an earlier hard dependency (the original design
-- queued normal orders into CraftSim.CRAFTQ); that path was retired in favor of always using
-- Auctionator directly, so CraftSim is no longer required at all. See
-- docs/craftsim-recipedata-notes.md for the retired approach, kept for the record.
--
-- Also owns saved variables, the shared ns.Print/ns.VERSION helpers, and the login message --
-- structured to match Crosshairs' and ShoppingConverter's own Core.lua (issue #16), rather
-- than inventing a new convention. DB init isn't gated on Auctionator being present: the
-- options panel and slash commands should still work (read status, see what's needed) even
-- before Auctionator is installed -- only ns.ready (the order-screen button's own gate) is.

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME

-- Debug/testing access only -- not a stable API. Lets /run reach ns.OrderScreen etc.
-- without a slash command existing yet.
_G.BestCraft = ns

local L = ns.L

function ns.Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print(L.CHAT_PREFIX .. msg)
end

-- Returns a display-ready version string with exactly one leading "v", or "dev" when running
-- from a git clone (the packager never substituted @project-version@). Split from the
-- metadata-read call below so this half is pure and unit-testable without stubbing
-- C_AddOns.GetAddOnMetadata -- matches ShoppingConverter/Version.lua's FormatVersion.
function ns.FormatVersion(raw)
    if type(raw) ~= "string" or raw == "" or raw:match("^@.-@$") then
        return "dev"
    end
    if raw:match("^[vV]") then
        return raw
    end
    return "v" .. raw
end

local GetAddOnMetadataCompat = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = ns.FormatVersion(GetAddOnMetadataCompat(ADDON_NAME, "Version"))

--------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------

-- Shared with Commands.lua's `reset` and Options.lua's checkboxes, so none of the three can
-- drift out of sync about what the defaults are.
ns.DEFAULT_SETTINGS = {
    buttonEnabled = true,
    -- Off by default: unsolicited login spam is the most common complaint about small addons
    -- (matches ShoppingConverter's own reasoning and default for the same setting).
    printOnLogin = false,
    -- On by default: matches issue #17's original behavior (always applied) before this
    -- became optional.
    maxQualityEnabled = true,
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

-- Shared by the options panel's checkboxes (each just sets its own key) and
-- "/bestcraft reset", so a wholesale reset can't drift from what a single-setting change does.
function ns.ResetToDefaults()
    for key, value in pairs(ns.DEFAULT_SETTINGS) do
        ns.db.settings[key] = value
    end
    if ns.Options and ns.Options.RefreshWidgets then
        ns.Options:RefreshWidgets()
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
        -- Gated on ns.ready, not just the setting: an unconditional "loaded" message right
        -- after the ADDON_LOADED handler already printed "requires Auctionator" would be a
        -- confusing non-sequitur, not a second independent notice.
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
