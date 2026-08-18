-- OrderShoppingList.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Builds an Auctionator shopping list for the order screen's current recipe -- every order,
-- not just recraft ones. Originally recraft-only: CraftSim.CRAFTQ:IsRecipeQueueable explicitly
-- refuses any recipeData.isRecraft recipe (Modules/CraftQueue/CraftQueue.lua:1303), for a real
-- reason (recrafting needs a specific target item's GUID, which fits "I'm personally
-- recrafting my own item," not "I'm a customer commissioning someone else's recraft"), so
-- recraft orders got their own Auctionator-only path while normal orders queued into
-- CraftSim.CRAFTQ instead. Confirmed in-game (issue #18) that the CraftQueue path actually
-- worked -- but per feedback, a single shopping-list-only flow for every order is simpler and
-- is what's wanted, so that's now the only path; see docs/craftsim-recipedata-notes.md for the
-- retired CraftQueue-based approach, kept for the record.
--
-- Builds via Auctionator.API.v1 -- Auctionator's own documented public API, the same one
-- CraftSim's own CreateAuctionatorShoppingList used (Modules/CraftQueue/CraftQueue.lua:
-- 1251,1254) and ShoppingConverter reads back out of.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

-- Tracks each order's last shopping-list contribution (issue #24), so re-clicking the button
-- for the same order updates its own line items instead of doubling them, while a genuinely
-- different order needing the same reagent still adds on top rather than replacing it. Same
-- weak-keyed-by-order pattern as OrderMinimumQuality.lua's lastAppliedSpellIDByOrder, for the
-- same reason: closed drafts shouldn't linger. See ApplyTermDeltas/CreateShoppingList below.
local lastContributionByOrder = setmetatable({}, { __mode = "k" })

function OrderScreen:IsAuctionatorAvailable()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

-- Returns the chosen reagent entries for whatever recipe is currently on the order screen
-- (recraft or not -- the schematic shape needs no special-casing here, see
-- docs/order-screen-research.md), or nil if there's no order/recipe currently loaded.
--
-- Prefers the lowest-quality reagent per slot, not the highest, when the recipe's *output*
-- has no quality tiers of its own -- confirmed against a real order (Thalassian Treatise on
-- Enchanting) that a recipe like this exists and that paying for premium reagents buys
-- nothing there, since the crafted result can't rank up regardless. Detected via
-- Form.minQualityIDs, the same per-recipe data issue #17's Minimum Quality default already
-- reads (index 1 is a "None" placeholder, not a real tier -- see
-- docs/minimum-quality-notes.md -- so #minQualityIDs <= 1 means no real tier exists at all;
-- nil means the same thing, not "not yet known" -- see GetShoppingEntries below, issue #19).
---@return table? entries
---@return boolean? allRequiredResolved See OrderReagents.lua's GetChosenReagentEntries.
---   nil (not false) when entries itself is nil -- there's nothing to qualify.
---@return string? recipeName schematicInfo.name, for the chat confirmation on success.
---@return table? excludedForVendor See OrderReagents.lua's GetChosenReagentEntries.
---@return table? excludedForOwned See OrderReagents.lua's GetChosenReagentEntries.
function OrderScreen:GetShoppingEntries()
    local form = self.form
    local transaction = form and form.transaction
    if not transaction then
        return nil
    end

    local ok, schematicInfo = pcall(transaction.GetRecipeSchematic, transaction)
    if not ok or not schematicInfo then
        return nil
    end

    -- nil means "no real tier," not "not yet known" -- confirmed in-game against a real
    -- Public order (issue #19, "Thalassian Treatise on Enchanting"): Blizzard's own
    -- `self.minQualityIDs = recipeID and C_TradeSkillUI.GetQualitiesForRecipe(recipeID)` (see
    -- OrderMinimumQuality.lua's header comment) runs unconditionally once a recipe is loaded,
    -- independent of order type, so by the time GetShoppingEntries runs (a recipe/transaction
    -- already resolved -- see the guard above) this has already settled one way or the other.
    -- A prior version of this check required minQualityIDs to be non-nil with length <= 1,
    -- reasoning nil might mean "not loaded yet" -- but GetQualitiesForRecipe genuinely returns
    -- nil (not an empty/length-1 table) for a recipe with no quality tiers at all, so that
    -- version silently fell through to the highest-quality default on exactly the recipes this
    -- was meant to catch.
    local minQualityIDs = form.minQualityIDs
    local preferLowestQuality = minQualityIDs == nil or #minQualityIDs <= 1

    local entries, allRequiredResolved, excludedForVendor, excludedForOwned =
        self:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    return entries, allRequiredResolved, schematicInfo.name, excludedForVendor, excludedForOwned
end

-- Builds Auctionator search strings, a parallel "Name [xN], Name [xN], ..." human-readable
-- summary, and the raw term tables underneath both (for ApplyTermDeltas' merge below) from the
-- same entries together, so each entry's item name is only looked up once.
---@return table searchStrings
---@return string summary
---@return table terms Array of { searchString, tier, quantity, isExact } -- the term tables
---   ConvertToSearchString/ConvertFromSearchString both use, parallel to searchStrings.
local function BuildSearchStringsAndSummary(entries)
    local searchStrings = {}
    local terms = {}
    local summaryParts = {}
    for _, entry in ipairs(entries) do
        local itemName = C_Item.GetItemInfo(entry.itemID)
        if itemName then
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(entry.itemID)
            local term = {
                searchString = itemName,
                tier = quality,
                quantity = entry.quantity,
                isExact = true,
            }
            local ok, searchString = pcall(Auctionator.API.v1.ConvertToSearchString, ADDON_NAME, term)
            if ok and searchString then
                table.insert(searchStrings, searchString)
                table.insert(terms, term)
                table.insert(summaryParts, ("%s [x%d]"):format(itemName, entry.quantity))
            end
        end
    end
    return searchStrings, table.concat(summaryParts, ", "), terms
end

-- Applies signed quantity deltas to an existing shopping list's search strings: a delta
-- matching an existing line (same item name and quality tier, ignoring quantity -- the same
-- matching Auctionator itself uses, confirmed via CraftSim's working read-compare-write
-- pattern, CraftSim/Modules/Shopping/Shopping.lua:135-189's AddSearchTermToShoppingList) has
-- its quantity adjusted by delta.quantity; a positive delta with no match becomes a new line,
-- a negative delta with no match is a no-op (nothing to subtract from -- see CreateShoppingList
-- below, where this happens if a previous contribution's line was deleted by the player in the
-- meantime). A line whose quantity is adjusted to zero or below is dropped entirely.
--
-- Returns the full array to pass to CreateShoppingList, which replaces a list's *entire*
-- contents with whatever array it's given (see this file's own earlier header comment) -- so
-- passing back every existing line plus the deltas applied is how a merge happens without ever
-- calling a per-item Alter/Delete API.
---@param existingSearchStrings table
---@param deltaTerms table Array of { searchString, tier, quantity } -- quantity is signed.
---@return table result
local function ApplyTermDeltas(existingSearchStrings, deltaTerms)
    local lines = {}
    for i, searchString in ipairs(existingSearchStrings) do
        local ok, term = pcall(Auctionator.API.v1.ConvertFromSearchString, ADDON_NAME, searchString)
        -- Unparseable (shouldn't normally happen) is kept as an opaque passthrough line, via
        -- _raw, so nothing real already on the player's list is silently dropped.
        lines[i] = (ok and term) or { _raw = searchString }
    end

    for _, delta in ipairs(deltaTerms) do
        local matched
        for _, line in ipairs(lines) do
            if not line._raw and line.searchString == delta.searchString and (line.tier or 0) == (delta.tier or 0) then
                matched = line
                break
            end
        end
        if matched then
            matched.quantity = (matched.quantity or 0) + delta.quantity
        elseif delta.quantity > 0 then
            table.insert(lines, { searchString = delta.searchString, tier = delta.tier, quantity = delta.quantity })
        end
    end

    local result = {}
    for _, line in ipairs(lines) do
        if line._raw then
            table.insert(result, line._raw)
        elseif line.quantity and line.quantity > 0 then
            local ok, searchString = pcall(Auctionator.API.v1.ConvertToSearchString, ADDON_NAME, {
                searchString = line.searchString,
                tier = line.tier,
                quantity = line.quantity,
                isExact = true,
            })
            if ok and searchString then
                table.insert(result, searchString)
            end
        end
    end
    return result
end

-- Exposed as a plain field (not a colon method -- ApplyTermDeltas never uses self) so
-- OrderShoppingPurchases.lua can reuse it for issue #21's purchase-driven decrements, the same
-- delta-application machinery built here for issue #24's merge. Call as
-- OrderScreen.ApplyTermDeltas(existingSearchStrings, deltaTerms), not with a colon.
OrderScreen.ApplyTermDeltas = ApplyTermDeltas

---@param terms table
---@return table negated Same terms with quantity sign flipped, for undoing a prior contribution.
local function NegateTerms(terms)
    local negated = {}
    for i, term in ipairs(terms) do
        negated[i] = { searchString = term.searchString, tier = term.tier, quantity = -term.quantity }
    end
    return negated
end

-- Names every itemID in an exclusion list (vendor-purchasable, issue #20; already owned, issue
-- #23) for a chat note explaining why the list is shorter than the recipe's full reagent
-- count -- "" when nothing was excluded, so callers can append it unconditionally without an
-- extra branch.
---@param excluded table? itemIDs
---@param template string L.CHAT_SKIPPED_VENDOR or L.CHAT_SKIPPED_OWNED -- one %s for the names.
---@return string note
local function BuildSkippedNote(excluded, template)
    if not excluded or #excluded == 0 then
        return ""
    end
    local names = {}
    for _, itemID in ipairs(excluded) do
        table.insert(names, C_Item.GetItemInfo(itemID) or ("item " .. itemID))
    end
    return template:format(table.concat(names, ", "))
end

---@return boolean success
---@return string? message On failure, why. On success, a chat-ready confirmation of the
---   recipe and materials added (issue feedback: the player asked what was added and why),
---   plus a note of anything skipped as vendor-purchasable (issue #20) or already owned
---   (issue #23).
function OrderScreen:CreateShoppingList()
    if not self:IsAuctionatorAvailable() then
        return false, L.ERROR_NO_AUCTIONATOR
    end

    local entries, allRequiredResolved, recipeName, excludedForVendor, excludedForOwned = self:GetShoppingEntries()
    if not entries then
        return false, L.STATUS_NO_REAGENTS
    end
    if not allRequiredResolved then
        return false, L.STATUS_UNRESOLVED_REQUIRED
    end
    local skippedNote = BuildSkippedNote(excludedForVendor, L.CHAT_SKIPPED_VENDOR)
        .. BuildSkippedNote(excludedForOwned, L.CHAT_SKIPPED_OWNED)
    if #entries == 0 then
        return false, L.STATUS_NO_REAGENTS .. skippedNote
    end

    local searchStrings, summary, terms = BuildSearchStringsAndSummary(entries)
    if #searchStrings == 0 then
        return false, L.ERROR_UNRESOLVED_ITEM_NAMES
    end

    -- Merge into an existing list under this name rather than replacing it (issue #24), so a
    -- second order's click adds to the first order's list instead of discarding it. Existing
    -- items keyed by the same item+tier get their quantity summed; anything else on the
    -- player's list is left alone.
    --
    -- This order's own *previous* contribution (if any) is undone first via a negated delta,
    -- so re-clicking the button for the same order updates its own line items instead of
    -- endlessly doubling them on every click -- the same guarantee the old delete-then-recreate
    -- approach gave for a single order, now extended to work alongside genuine cross-order
    -- merging. order is keyed by identity (the order screen's own order object), the same
    -- weak-table pattern OrderMinimumQuality.lua uses to track per-draft state.
    local order = self.form and self.form.order
    local finalSearchStrings = searchStrings

    local listManager = Auctionator.Shopping and Auctionator.Shopping.ListManager
    local existingIndex = listManager and listManager:GetIndexForName(L.SHOPPING_LIST_NAME)
    if existingIndex then
        local ok, existingSearchStrings = pcall(Auctionator.API.v1.GetShoppingListItems, ADDON_NAME,
            L.SHOPPING_LIST_NAME)
        if ok and existingSearchStrings then
            local deltas = {}
            if order and lastContributionByOrder[order] then
                for _, negated in ipairs(NegateTerms(lastContributionByOrder[order])) do
                    table.insert(deltas, negated)
                end
            end
            for _, term in ipairs(terms) do
                table.insert(deltas, term)
            end
            finalSearchStrings = ApplyTermDeltas(existingSearchStrings, deltas)
        end
        -- else: reading the existing list failed -- falls through to finalSearchStrings =
        -- searchStrings (this order's items alone), the same failure mode a missing/absent
        -- ListManager already has below.
    end

    local ok = pcall(Auctionator.API.v1.CreateShoppingList, ADDON_NAME, L.SHOPPING_LIST_NAME, finalSearchStrings)
    if not ok then
        return false, L.ERROR_CREATE_FAILED
    end

    if order then
        lastContributionByOrder[order] = terms
    end

    local message = L.CHAT_LIST_CREATED:format(recipeName or L.CHAT_UNKNOWN_RECIPE, summary)
    return true, message .. skippedNote
end
