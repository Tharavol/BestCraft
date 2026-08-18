std = "lua51"
max_line_length = 120

-- The luarocks CI action installs into .luarocks/ inside the workspace, so
-- `luacheck .` would otherwise lint the toolchain along with the addon.
exclude_files = {".luarocks/**", ".luarocks", "lua_modules/**"}

-- WoW event handlers always receive (self, event, ...); ignore unused args
-- entirely since callbacks must match Blizzard's fixed signatures.
ignore = {
    "212", -- unused argument
}

-- Matches Crosshairs'/ShoppingConverter's own .luacheckrc split (issue #16): SavedVariables
-- DB name and SLASH_*/SlashCmdList are write-able globals, everything else is read-only.
globals = {
    -- SavedVariables declared in the .toc
    "BestCraftDB",

    "SLASH_BESTCRAFT1",
    "SlashCmdList",
}

read_globals = {
    "C_AddOns",
    "C_Item",
    "C_TooltipInfo",
    "C_TradeSkillUI",
    "CreateFrame",
    "Enum",
    "GameTooltip",
    "GameTooltip_AddErrorLine",
    "GameTooltip_AddNormalLine",
    "GameTooltip_Hide",
    "GetAddOnMetadata",
    "hooksecurefunc",
    "Settings",

    -- Blizzard's load-on-demand Crafting Orders customer frame. See
    -- docs/order-screen-research.md for how it was identified.
    "ProfessionsCustomerOrdersFrame",

    -- Auctionator's addon table -- the addon's sole dependency, see
    -- Modules/OrderShoppingList.lua.
    "Auctionator",
}
