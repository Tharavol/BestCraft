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

read_globals = {
    "C_AddOns",
    "C_TradeSkillUI",
    "CraftSimAPI",
    "CreateFrame",
    "hooksecurefunc",

    -- Blizzard's load-on-demand Crafting Orders customer frame. See
    -- docs/order-screen-research.md for how it was identified.
    "ProfessionsCustomerOrdersFrame",
}
