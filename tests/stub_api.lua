-- stub_api.lua
-- SPDX-License-Identifier: MIT
--
-- Stubs the slice of the WoW API this addon touches, then loads the addon's Lua files
-- (in the order BestCraft.toc lists them) into a fresh, isolated environment per call so
-- tests don't leak state into one another.
--
-- Usage: local stub = dofile("tests/stub_api.lua")

local M = {}

local function NewEnv(addonsLoaded)
    local frames = {}

    local function MakeFrame()
        local f = { _events = {} }
        function f:RegisterEvent(event) self._events[event] = true end
        function f:UnregisterEvent(event) self._events[event] = nil end
        function f:SetScript(scriptType, fn)
            self._scripts = self._scripts or {}
            self._scripts[scriptType] = fn
        end
        function f:GetScript(scriptType) return self._scripts and self._scripts[scriptType] end
        return f
    end

    local api = {
        addonsLoaded = addonsLoaded or {},
        chatLog = {},
    }

    local env = setmetatable({}, { __index = _G })
    env.CreateFrame = function(...)
        local f = MakeFrame()
        table.insert(frames, f)
        return f
    end
    env.C_AddOns = {
        IsAddOnLoaded = function(name) return api.addonsLoaded[name] == true end,
    }
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        table.insert(api.chatLog, table.concat(parts, " "))
    end

    return env, api, frames
end

-- Every non-comment, non-directive line in the .toc is a file to load, in order -- the
-- same rule scripts/validate-toc.lua uses, so the two can't drift apart.
local function TocFileList(tocPath)
    local handle = assert(io.open(tocPath, "r"), "could not open " .. tocPath)
    local contents = handle:read("*a")
    handle:close()

    local files = {}
    for rawLine in (contents .. "\n"):gmatch("([^\n]*)\n") do
        local line = rawLine:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            table.insert(files, line)
        end
    end
    return files
end

-- Loads the addon fresh: a new stub environment and a new shared `ns` table, exactly
-- like WoW handing each file the same addon table via `...`.
-- opts.addonsLoaded: optional set ({ CraftSim = true }) fed to C_AddOns.IsAddOnLoaded.
-- opts.presetGlobals: optional table of globals (e.g. a fake ProfessionsCustomerOrdersFrame)
-- set on the environment before any addon file executes, for frames the addon doesn't
-- create itself and must instead find already sitting in the global namespace.
function M.LoadAddon(rootDir, tocPath, opts)
    local env, api, frames = NewEnv(opts and opts.addonsLoaded)
    if opts and opts.presetGlobals then
        for k, v in pairs(opts.presetGlobals) do
            env[k] = v
        end
    end
    local ns = {}
    for _, file in ipairs(TocFileList(tocPath)) do
        local chunk = assert(loadfile(rootDir .. "/" .. file))
        setfenv(chunk, env)
        chunk("BestCraft", ns)
    end
    return { env = env, ns = ns, api = api, frames = frames }
end

-- Fires ADDON_LOADED for the given addon name against every frame that registered for it,
-- the way WoW would after any addon in the load order finishes loading.
function M.FireAddonLoaded(loaded, addonName)
    for _, f in ipairs(loaded.frames) do
        if f._events.ADDON_LOADED and f._scripts and f._scripts.OnEvent then
            f._scripts.OnEvent(f, "ADDON_LOADED", addonName)
        end
    end
end

return M
