-- enUS.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- User-facing strings, structured for future translation even though enUS is the only locale
-- shipped for now (issue #9). A plain ns.L table -- no CraftSim L() pattern to match against,
-- since BestCraft no longer depends on or interoperates with CraftSim (see the
-- CraftSim-retirement pivot, docs/craftsim-recipedata-notes.md). Loads before Core.lua and
-- every module that shows text to the player.
--
-- Two messages ("no reagents to shop for", "a required reagent is unresolved") originally
-- existed as separate near-duplicate literals in the tooltip path (OrderShoppingButton.lua)
-- and the click-failure path (OrderShoppingList.lua) -- collapsed to single shared keys here
-- (STATUS_NO_REAGENTS, STATUS_UNRESOLVED_REQUIRED) since they were already word-for-word
-- identical, just typed out twice.

local _, ns = ...

local L = {}
ns.L = L

L.CHAT_PREFIX = "|cffff4444BestCraft|r "

L.BUTTON_LABEL = "+ Shopping List"

L.STATUS_READY = "Builds an Auctionator shopping list for this order's highest-quality reagents."
L.STATUS_NO_AUCTIONATOR = "Requires Auctionator to be installed and enabled."
L.STATUS_UNRESOLVED_REQUIRED = "Couldn't resolve every required reagent for this order yet -- "
    .. "try again once all slots have a selection."
L.STATUS_NO_REAGENTS = "No reagents to shop for on this order."

L.ERROR_NO_AUCTIONATOR = "Auctionator is required to build a shopping list for this order."
L.ERROR_UNRESOLVED_ITEM_NAMES = "Couldn't resolve item names for this order's reagents yet -- try again in a moment."
L.ERROR_CREATE_FAILED = "Couldn't create the Auctionator shopping list."

-- Confirms what was actually added and why, per feedback -- printed on every successful
-- CreateShoppingList call. %s/%s = recipe name, "Name [xN], Name [xN], ..." materials summary.
L.CHAT_LIST_CREATED = "Shopping list ready for \"%s\": %s"
L.CHAT_UNKNOWN_RECIPE = "this order"

L.CORE_REQUIRES_AUCTIONATOR = "requires Auctionator to be installed and enabled."
L.CORE_LOGIN_MESSAGE = "%s loaded. |cffaaaaaa/bestcraft|r for options."

L.SHOPPING_LIST_NAME = "BestCraft"

-- Issue #16: standardized slash commands / options panel, matching conventions from
-- Crosshairs (slash command set, COMMANDS-table dispatch) and ShoppingConverter (login
-- message toggle, Options.lua structure) -- see those repos' Core.lua/Commands.lua/Options.lua.
L.OPTIONS_TITLE = "BestCraft"
L.OPTIONS_BUTTON_ENABLED_LABEL = "Enable the order-screen shopping list button"
L.OPTIONS_BUTTON_ENABLED_TOOLTIP = "Shows or hides the \"+ Shopping List\" button on the Place Crafting "
    .. "Order screen. When off, the button is hidden entirely rather than shown disabled."
L.OPTIONS_LOGIN_MESSAGE_LABEL = "Show a message at login"
L.OPTIONS_LOGIN_MESSAGE_TOOLTIP = "Print the addon name and version to chat when you log in."
L.OPTIONS_MAX_QUALITY_LABEL = "Automatically set Minimum Quality to maximum"
L.OPTIONS_MAX_QUALITY_TOOLTIP = "On Guild and Personal orders, default the Minimum Quality dropdown to the "
    .. "recipe's highest tier (see issue #17). Turning this off leaves the dropdown at whatever the game "
    .. "itself defaults to (usually None) -- BestCraft won't touch it."

L.CMD_HELP_OPTIONS = "/bestcraft, /bestcraft options, /bestcraft config, /bestcraft gui - "
    .. "open the options panel"
L.CMD_HELP_STATUS = "/bestcraft status - show current settings"
L.CMD_HELP_VERSION = "/bestcraft version - show the addon version"
L.CMD_HELP_RESET = "/bestcraft reset - restore settings to defaults"
L.CMD_HELP_LOGIN = "/bestcraft login [on|off] - toggle the login version message"
L.CMD_HELP_MAXQUALITY = "/bestcraft maxquality [on|off] - toggle automatically setting Minimum Quality to maximum"
L.CMD_HELP_HELP = "/bestcraft help - show this list"
L.CMD_UNKNOWN = "unknown command: %s"
L.CMD_UNKNOWN_VALUE = "'%s' - expected 'on' or 'off'."
L.CMD_SETTINGS_RESET = "Settings restored to defaults."
L.CMD_COMMANDS_HEADER = "%s commands:"
L.CMD_SETTINGS_HEADER = "%s settings:"
L.CMD_SETTING_STATUS = "%s is %s."
L.CMD_SETTING_ON = "|cff00ff00on|r"
L.CMD_SETTING_OFF = "|cffff0000off|r"
L.CMD_LOGIN_LABEL = "Login message"
L.CMD_MAXQUALITY_LABEL = "Maximum quality default"
