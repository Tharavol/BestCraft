-- enUS.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- User-facing strings (#9). Loads before Core.lua and every module that shows text.

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

-- %s/%s = recipe name, "Name [xN], ..." materials summary.
L.CHAT_LIST_CREATED = "Shopping list ready for \"%s\": %s"
L.CHAT_UNKNOWN_RECIPE = "this order"

-- #20, #23. %s = comma-joined item names. Appended directly, so leads with a space.
L.CHAT_SKIPPED_VENDOR = " Skipped %s -- available from a vendor."

L.CHAT_SKIPPED_OWNED = " Skipped %s -- already own enough."

L.CORE_REQUIRES_AUCTIONATOR = "requires Auctionator to be installed and enabled."
L.CORE_LOGIN_MESSAGE = "%s loaded. |cffaaaaaa/bestcraft|r for options."

L.SHOPPING_LIST_NAME = "BestCraft"

-- Slash commands and options panel (#16).
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
L.OPTIONS_GUILD_COMMISSION_LABEL = "Default Guild order commission to 1 silver"
L.OPTIONS_GUILD_COMMISSION_TOOLTIP = "On a Guild order, sets the commission to 1 silver whenever it's still 0 "
    .. "(see issue #22). Blizzard's own \"Place Order\" button already refuses to submit at 0 regardless, so "
    .. "this just saves the extra manual step. Turning this off leaves the commission at whatever the game "
    .. "itself defaults to -- BestCraft won't touch it."
L.OPTIONS_UPDATE_ON_PURCHASE_LABEL = "Update the shopping list as items are purchased"
L.OPTIONS_UPDATE_ON_PURCHASE_TOOLTIP = "As a commodity reagent from BestCraft's own shopping list is bought "
    .. "on the Auction House, reduce (or remove) its line item on the list by the amount bought (see issue "
    .. "#21). Turning this off leaves the list exactly as built until the next click."

L.CMD_HELP_OPTIONS = "/bestcraft, /bestcraft options, /bestcraft config, /bestcraft gui - "
    .. "open the options panel"
L.CMD_HELP_STATUS = "/bestcraft status - show current settings"
L.CMD_HELP_VERSION = "/bestcraft version - show the addon version"
L.CMD_HELP_RESET = "/bestcraft reset - restore settings to defaults"
L.CMD_HELP_LOGIN = "/bestcraft login [on|off] - toggle the login version message"
L.CMD_HELP_MAXQUALITY = "/bestcraft maxquality [on|off] - toggle automatically setting Minimum Quality to maximum"
L.CMD_HELP_GUILDCOMMISSION = "/bestcraft guildcommission [on|off] - toggle defaulting a Guild order's "
    .. "commission to 1 silver"
L.CMD_HELP_UPDATEONPURCHASE = "/bestcraft updateonpurchase [on|off] - toggle updating the shopping list as "
    .. "items are purchased"
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
L.CMD_GUILDCOMMISSION_LABEL = "Guild commission default"
L.CMD_UPDATEONPURCHASE_LABEL = "Update list on purchase"
