-- Commands.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Slash command dispatch (issue #16), matching Crosshairs' and ShoppingConverter's own
-- Commands/Slash.lua conventions rather than inventing a new one: a table of
-- { name, help, handler } that PrintUsage is derived from, so the help text can't drift out
-- of sync with what Dispatch actually matches. "", "config" and "gui" are silent aliases of
-- "options" -- each opens the panel but carries no help text of its own, so PrintUsage
-- doesn't repeat the same line four times.
--
-- Doesn't touch the game API directly -- no CreateFrame, no SlashCmdList registration, both
-- of which stay in Core.lua -- which is what lets this module be exercised directly by
-- calling Commands:Dispatch(input), without needing to fake a slash-command event.

local _, ns = ...

local L = ns.L

local Commands = {}
ns.Commands = Commands

-- `bareToggles` controls what an empty value does: true means bare toggles the current state
-- and reports the result, matching the cross-addon convention Crosshairs' HandleDebug and
-- ShoppingConverter's Toggle both already follow for their own bare-word toggles.
local function Toggle(key, value, label, bareToggles)
    if value == "on" then
        ns.db.settings[key] = true
    elseif value == "off" then
        ns.db.settings[key] = false
    elseif value == "" then
        if bareToggles then
            ns.db.settings[key] = not ns.db.settings[key]
        end
    else
        -- Reject rather than silently ignore: an unrecognised value must not report the
        -- unchanged state as though it had applied.
        ns.Print(L.CMD_UNKNOWN_VALUE, value)
        return
    end
    ns.Print(L.CMD_SETTING_STATUS, label, ns.db.settings[key] and L.CMD_SETTING_ON or L.CMD_SETTING_OFF)
end

local function OpenPanel() ns.Options:Open() end

-- Forward-declared so the "help" entry below can close over it before its body (which needs
-- COMMANDS to exist) is assigned further down.
local PrintUsage

local COMMANDS = {
    { name = "", help = {}, handler = OpenPanel },
    { name = "options", help = { L.CMD_HELP_OPTIONS }, handler = OpenPanel },
    { name = "config", help = {}, handler = OpenPanel },
    { name = "gui", help = {}, handler = OpenPanel },
    {
        name = "status",
        help = { L.CMD_HELP_STATUS },
        handler = function()
            ns.Print(L.CMD_SETTINGS_HEADER, ns.VERSION)
            for _, definition in ipairs(ns.Options.CHECKBOXES) do
                print(("  %s: %s"):format(definition.label,
                    ns.db.settings[definition.key] and L.CMD_SETTING_ON or L.CMD_SETTING_OFF))
            end
        end,
    },
    {
        name = "version",
        help = { L.CMD_HELP_VERSION },
        handler = function() ns.Print(ns.VERSION) end,
    },
    {
        name = "reset",
        help = { L.CMD_HELP_RESET },
        handler = ns.ResetToDefaults,
    },
    {
        name = "login",
        help = { L.CMD_HELP_LOGIN },
        handler = function(_, rest) Toggle("printOnLogin", rest, L.CMD_LOGIN_LABEL, true) end,
    },
    {
        name = "help",
        help = { L.CMD_HELP_HELP },
        handler = function() PrintUsage() end,
    },
}

PrintUsage = function()
    ns.Print(L.CMD_COMMANDS_HEADER, ns.VERSION)
    for _, command in ipairs(COMMANDS) do
        for _, line in ipairs(command.help) do
            print("  " .. line)
        end
    end
end

-- `argument` keeps the original case of everything after the command word; `rest` is the
-- same text lowercased, for the on/off values the toggle commands compare against.
local function Parse(input)
    local raw = input or ""
    local command, argument = raw:match("^%s*(%S*)%s*(.-)%s*$")
    return command:lower(), argument, argument:lower()
end

function Commands:Dispatch(input)
    local command, argument, rest = Parse(input)

    for _, entry in ipairs(COMMANDS) do
        if entry.name == command then
            entry.handler(argument, rest)
            return
        end
    end

    -- A typo must be visibly a typo, never a silent fallback.
    ns.Print(L.CMD_UNKNOWN, command)
    PrintUsage()
end
