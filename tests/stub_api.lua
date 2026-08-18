-- stub_api.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
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
    function f:SetChecked(checked) self._checked = checked and true or false end
    function f:GetChecked() return self._checked end
    -- Real CreateFontString/CreateTexture return region objects, not frames -- but every
    -- method BestCraft's own code calls on one (SetPoint, SetText/GetText) is already here,
    -- so a plain MakeFrame() stands in fine rather than a third near-identical stub type.
    function f:CreateFontString(...) return MakeFrame() end
    function f:CreateTexture(...) return MakeFrame() end
    return f
end

M.MakeFrame = MakeFrame

local function NewEnv(opts)
    opts = opts or {}
    local frames = {}

    local api = {
        addonsLoaded = opts.addonsLoaded or {},
        chatLog = {},
        -- itemID -> reagent quality tier (1-3), for GetItemReagentQualityByItemInfo. An
        -- itemID absent from this table returns nil, matching a reagent with no quality tier.
        reagentQualities = opts.reagentQualities or {},
        -- itemID -> item name, for C_Item.GetItemInfo. An itemID absent from this table
        -- returns nil, matching an item whose client-side info isn't cached/known yet.
        itemNames = opts.itemNames or {},
        -- itemID -> Enum.ItemBind value, for GetItemInfo's 14th return value (bindType). An
        -- itemID absent from this table returns nil, matching an item whose bind info isn't
        -- cached/known yet -- OrderReagents.lua's IsBindOnPickup fails open on that (not BoP).
        itemBindTypes = opts.itemBindTypes or {},
        -- itemID -> array of tooltip line strings, for C_TooltipInfo.GetItemByID. An itemID
        -- absent from this table gets a nil `info` back, matching an item whose tooltip data
        -- isn't cached yet -- OrderReagents.lua's IsVendorPurchasable fails open on that (not
        -- flagged as vendor-purchasable).
        itemTooltipLines = opts.itemTooltipLines or {},
        -- itemID -> owned count (bags+bank+reagent bank+Warband bank), for C_Item.GetItemCount.
        -- An itemID absent from this table returns 0, matching a reagent the player owns none
        -- of -- OrderReagents.lua's GetOwnedCount treats that the same as an API failure.
        itemCounts = opts.itemCounts or {},
        -- Lines shown via GameTooltip_AddNormalLine/AddErrorLine since the last SetOwner,
        -- each { kind = "Normal"|"Error", text = string }, for specs to assert tooltip content.
        tooltipLines = {},
        -- Fed to GetAddOnMetadata(_, "Version"); nil (the default) matches a dev install
        -- where the packager never substituted @project-version@.
        addonVersion = opts.addonVersion,
        -- Every Settings.OpenToCategory call's categoryID, for specs asserting a slash
        -- command or button actually opened the options panel.
        openedCategoryIDs = {},
    }

    local env = setmetatable({}, { __index = _G })
    -- Real WoW addons' `_G` *is* the shared global table they run in. Point the stub's
    -- `_G` back at itself so a file doing `_G.Something = x` (Core.lua does, for debug
    -- access) writes into this test's isolated env instead of leaking into the real
    -- process-wide _G and bleeding into other tests.
    env._G = env
    env.CreateFrame = function(frameType, ...)
        local f = MakeFrame()
        -- Real CheckButton templates (InterfaceOptionsCheckButtonTemplate etc.) always
        -- expose a .Text FontString region; Options.lua's checkboxes rely on it existing.
        if frameType == "CheckButton" then
            f.Text = MakeFrame()
        end
        table.insert(frames, f)
        return f
    end
    env.C_AddOns = {
        IsAddOnLoaded = function(name) return api.addonsLoaded[name] == true end,
        GetAddOnMetadata = function(_, field)
            if field == "Version" then return api.addonVersion end
            return nil
        end,
    }
    env.GetAddOnMetadata = env.C_AddOns.GetAddOnMetadata
    env.C_TradeSkillUI = {
        GetItemReagentQualityByItemInfo = function(itemID) return api.reagentQualities[itemID] end,
    }
    env.C_Item = {
        -- Real GetItemInfo returns 18 values (Blizzard_APIDocumentationGenerated/
        -- ItemDocumentation.lua); only itemName (1st) and bindType (14th) are anything this
        -- addon reads, so the rest are left nil rather than faked in full.
        GetItemInfo = function(itemID)
            -- Indexed explicitly (not a hand-counted run of nils) so bindType's position can't
            -- silently drift off 14 -- it did once already while writing this stub.
            local values = { [1] = api.itemNames[itemID], [14] = api.itemBindTypes[itemID] }
            return unpack(values, 1, 14)
        end,
        GetItemCount = function(itemID) return api.itemCounts[itemID] or 0 end,
    }
    env.C_TooltipInfo = {
        GetItemByID = function(itemID)
            local lines = api.itemTooltipLines[itemID]
            if not lines then
                return nil
            end
            local wrapped = {}
            for _, text in ipairs(lines) do
                table.insert(wrapped, { leftText = text })
            end
            return { lines = wrapped }
        end,
    }
    -- SetOwner clears tooltipLines (matching a real tooltip resetting its content each time
    -- it's re-anchored), the Add*Line helpers append to it, Hide is a no-op observer.
    env.GameTooltip = {
        SetOwner = function() api.tooltipLines = {} end,
        Show = function() end,
    }
    env.GameTooltip_AddNormalLine = function(_, text)
        table.insert(api.tooltipLines, { kind = "Normal", text = text })
    end
    env.GameTooltip_AddErrorLine = function(_, text)
        table.insert(api.tooltipLines, { kind = "Error", text = text })
    end
    env.GameTooltip_Hide = function() end
    -- RegisterCanvasLayoutCategory returns an object with a stable :GetID() -- Options.lua
    -- keeps that around to later call Settings.OpenToCategory(category:GetID()).
    env.Settings = {
        RegisterCanvasLayoutCategory = function(_, name)
            local category = { _id = name }
            function category:GetID() return self._id end
            return category
        end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function(categoryID) table.insert(api.openedCategoryIDs, categoryID) end,
    }
    -- Core.lua assigns SlashCmdList["BESTCRAFT"] at file-load time; this only needs to be a
    -- table for that assignment not to error -- specs exercise Commands:Dispatch directly
    -- rather than through this (Commands.lua never touches SlashCmdList itself).
    env.SlashCmdList = {}
    -- Real values (Blizzard_APIDocumentationGenerated/ProfessionConstantsDocumentation.lua and
    -- ItemConstantsDocumentation.lua), not placeholders -- so e.g. a test's
    -- Enum.CraftingOrderType.Public matches the real client.
    env.Enum = {
        CraftingOrderType = { Public = 0, Guild = 1, Personal = 2, Npc = 3 },
        CraftingOrderReagentSource = { Any = 0, Customer = 1, Crafter = 2, None = 3 },
        ItemBind = { None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4 },
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

-- Fires an arbitrary event against every frame that registered for it, the way WoW would.
local function FireEventOn(frames, event, ...)
    for _, f in ipairs(frames) do
        if f._events[event] and f._scripts and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

local function FireAddonLoadedOn(frames, addonName)
    FireEventOn(frames, "ADDON_LOADED", addonName)
end

-- Loads the addon fresh: a new stub environment and a new shared `ns` table, exactly
-- like WoW handing each file the same addon table via `...`.
-- opts.addonsLoaded: optional set ({ Auctionator = true }) fed to C_AddOns.IsAddOnLoaded.
-- opts.presetGlobals: optional table of globals (e.g. a fake ProfessionsCustomerOrdersFrame)
-- set on the environment before any addon file executes, for frames the addon doesn't
-- create itself and must instead find already sitting in the global namespace.
-- opts.reagentQualities: optional { [itemID] = qualityTier } fed to
-- C_TradeSkillUI.GetItemReagentQualityByItemInfo.
-- opts.itemNames: optional { [itemID] = name } fed to C_Item.GetItemInfo.
-- opts.itemBindTypes: optional { [itemID] = Enum.ItemBind value } fed to C_Item.GetItemInfo's
-- bindType return value.
-- opts.itemTooltipLines: optional { [itemID] = { "line1", "line2", ... } } fed to
-- C_TooltipInfo.GetItemByID.
-- opts.itemCounts: optional { [itemID] = ownedCount } fed to C_Item.GetItemCount.
-- opts.addonVersion: optional string fed to GetAddOnMetadata(_, "Version").
-- opts.skipAutoAddonLoaded: optional; when true, skips the auto-fire below entirely. Only
-- core_spec.lua's own ADDON_LOADED-handling tests need this, to control firing order/addon
-- name themselves; every other spec wants ns.db/ns.ready already resolved.
function M.LoadAddon(rootDir, tocPath, opts)
    local env, api, frames = NewEnv(opts)
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
    -- A real client fires ADDON_LOADED for an addon synchronously, right after its own files
    -- finish executing -- Core.lua's DB init (ns.db) and Auctionator gate (ns.ready) both run
    -- from that handler, so every other module that reads either (which is most of them, now
    -- that issue #16 added settings) needs this to have already happened by the time
    -- LoadAddon returns, the same as it would have in-game.
    if not (opts and opts.skipAutoAddonLoaded) then
        FireAddonLoadedOn(frames, "BestCraft")
    end
    return { env = env, ns = ns, api = api, frames = frames }
end

-- Fires ADDON_LOADED for the given addon name against every frame that registered for it,
-- the way WoW would after any addon in the load order finishes loading. Used for addons
-- *other* than BestCraft itself (e.g. Blizzard_ProfessionsCustomerOrders) -- BestCraft's own
-- ADDON_LOADED already fired once, automatically, inside LoadAddon above.
function M.FireAddonLoaded(loaded, addonName)
    FireAddonLoadedOn(loaded.frames, addonName)
end

-- Fires an arbitrary event (PLAYER_LOGIN, etc.) against every frame that registered for it.
function M.FireEvent(loaded, event, ...)
    FireEventOn(loaded.frames, event, ...)
end

return M
