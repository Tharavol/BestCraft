-- stub_api.lua
-- SPDX-License-Identifier: MIT
--
-- Stubs the slice of the WoW API this addon touches, then loads the addon's Lua files
-- (in the order BestCraft.toc lists them) into a fresh, isolated environment per call so
-- tests don't leak state into one another.
--
-- Usage: local stub = dofile("tests/stub_api.lua")

local M = {}

-- A frame/button stand-in with the slice of the real widget API this addon's code (and its
-- tests, when building fake forms/frames by hand) actually touches. Self-contained -- no
-- captures over NewEnv's locals -- so it's usable both as CreateFrame's return value and
-- directly by specs via stub.MakeFrame() when they need a realistic fake form/button rather
-- than a bare {}.
local function MakeFrame()
    local f = { _events = {}, _shown = true, _enabled = true }
    function f:RegisterEvent(event) self._events[event] = true end
    function f:UnregisterEvent(event) self._events[event] = nil end
    function f:SetScript(scriptType, fn)
        self._scripts = self._scripts or {}
        self._scripts[scriptType] = fn
    end
    function f:GetScript(scriptType) return self._scripts and self._scripts[scriptType] end
    -- Real HookScript runs every hooked handler plus any SetScript handler, in registration
    -- order; this only needs to support multiple HookScript calls for the same event, which
    -- is all the addon code actually does.
    function f:HookScript(scriptType, fn)
        self._hooks = self._hooks or {}
        self._hooks[scriptType] = self._hooks[scriptType] or {}
        table.insert(self._hooks[scriptType], fn)
    end
    function f:FireScript(scriptType, ...)
        if self._scripts and self._scripts[scriptType] then
            self._scripts[scriptType](self, ...)
        end
        if self._hooks and self._hooks[scriptType] then
            for _, fn in ipairs(self._hooks[scriptType]) do
                fn(self, ...)
            end
        end
    end
    function f:SetPoint(...) self._point = { ... } end
    function f:SetSize(w, h) self._width, self._height = w, h end
    function f:SetWidth(w) self._width = w end
    function f:SetHeight(h) self._height = h end
    function f:SetText(text) self._text = text end
    function f:GetText() return self._text end
    function f:Show() self._shown = true end
    function f:Hide() self._shown = false end
    function f:IsShown() return self._shown end
    function f:SetEnabled(enabled) self._enabled = enabled and true or false end
    function f:IsEnabled() return self._enabled end
    return f
end

M.MakeFrame = MakeFrame

local function NewEnv(addonsLoaded, reagentQualities, itemNames)
    local frames = {}

    local api = {
        addonsLoaded = addonsLoaded or {},
        chatLog = {},
        -- itemID -> reagent quality tier (1-3), for GetItemReagentQualityByItemInfo. An
        -- itemID absent from this table returns nil, matching a reagent with no quality tier.
        reagentQualities = reagentQualities or {},
        -- itemID -> item name, for C_Item.GetItemInfo. An itemID absent from this table
        -- returns nil, matching an item whose client-side info isn't cached/known yet.
        itemNames = itemNames or {},
    }

    local env = setmetatable({}, { __index = _G })
    -- Real WoW addons' `_G` *is* the shared global table they run in. Point the stub's
    -- `_G` back at itself so a file doing `_G.Something = x` (Core.lua does, for debug
    -- access) writes into this test's isolated env instead of leaking into the real
    -- process-wide _G and bleeding into other tests.
    env._G = env
    env.CreateFrame = function(...)
        local f = MakeFrame()
        table.insert(frames, f)
        return f
    end
    env.C_AddOns = {
        IsAddOnLoaded = function(name) return api.addonsLoaded[name] == true end,
    }
    env.C_TradeSkillUI = {
        GetItemReagentQualityByItemInfo = function(itemID) return api.reagentQualities[itemID] end,
    }
    env.C_Item = {
        GetItemInfo = function(itemID) return api.itemNames[itemID] end,
    }
    -- Table+methodName variant only -- the addon never hooks a bare global function.
    env.hooksecurefunc = function(tbl, name, hookFn)
        local original = tbl[name]
        tbl[name] = function(...)
            if original then original(...) end
            hookFn(...)
        end
    end
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
-- opts.reagentQualities: optional { [itemID] = qualityTier } fed to
-- C_TradeSkillUI.GetItemReagentQualityByItemInfo.
-- opts.itemNames: optional { [itemID] = name } fed to C_Item.GetItemInfo.
function M.LoadAddon(rootDir, tocPath, opts)
    local env, api, frames = NewEnv(opts and opts.addonsLoaded, opts and opts.reagentQualities,
        opts and opts.itemNames)
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
