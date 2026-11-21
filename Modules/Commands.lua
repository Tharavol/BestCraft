-- Commands.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Slash command dispatch (#16). PrintUsage is derived from COMMANDS so help can't drift from
-- Dispatch. "", "config" and "gui" are silent aliases of "options". SlashCmdList registration
-- stays in Core.lua so tests can call Commands:Dispatch directly.

local _, ns = ...

local L = ns.L

local Commands = {}
ns.Commands = Commands

-- bareToggles: an empty value flips the current state.
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
        -- Reject, so an unchanged state isn't reported as though it applied.
        ns.Print(L.CMD_UNKNOWN_VALUE, value)
        return
    end
    ns.Print(L.CMD_SETTING_STATUS, label, ns.db.settings[key] and L.CMD_SETTING_ON or L.CMD_SETTING_OFF)
end

local function OpenPanel() ns.Options:Open() end

-- Forward-declared: the "help" entry closes over it, and its body needs COMMANDS.
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
        name = "maxquality",
        help = { L.CMD_HELP_MAXQUALITY },
        handler = function(_, rest) Toggle("maxQualityEnabled", rest, L.CMD_MAXQUALITY_LABEL, true) end,
    },
    {
        name = "guildcommission",
        help = { L.CMD_HELP_GUILDCOMMISSION },
        handler = function(_, rest) Toggle("guildCommissionEnabled", rest, L.CMD_GUILDCOMMISSION_LABEL, true) end,
    },
    {
        name = "updateonpurchase",
        help = { L.CMD_HELP_UPDATEONPURCHASE },
        handler = function(_, rest) Toggle("updateOnPurchaseEnabled", rest, L.CMD_UPDATEONPURCHASE_LABEL, true) end,
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

-- argument keeps original case; rest is lowercased for on/off comparisons.
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

    ns.Print(L.CMD_UNKNOWN, command)
    PrintUsage()
end
