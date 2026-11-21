-- OrderShoppingList.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Builds an Auctionator shopping list (via Auctionator.API.v1) for the order screen's current
-- recipe, recraft or not (#18). API.v1 calls raise on bad input, hence the pcalls.

local ADDON_NAME, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

-- Each order's last contribution (#24), so re-clicking replaces it instead of doubling it.
-- Weak-keyed so closed drafts don't linger.
local lastContributionByOrder = setmetatable({}, { __mode = "k" })

function OrderScreen:IsAuctionatorAvailable()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

-- Chosen reagent entries for the current recipe, or nil if none is loaded. Prefers the
-- lowest quality when the output has no quality tiers (e.g. Thalassian Treatise on Enchanting).
---@return table? entries
---@return boolean? allRequiredResolved See GetChosenReagentEntries; nil when entries is nil.
---@return string? recipeName schematicInfo.name, for the chat confirmation on success.
---@return table? excludedForVendor See OrderReagents.lua's GetChosenReagentEntries.
---@return table? excludedForOwned See OrderReagents.lua's GetChosenReagentEntries.
function OrderScreen:GetShoppingEntries()
    local form = self.form
    local transaction = form and form.transaction
    if not transaction then
        return nil
    end

    local schematicInfo = transaction:GetRecipeSchematic()
    if not schematicInfo then
        return nil
    end

    -- Index 1 is a "None" placeholder (docs/minimum-quality-notes.md). nil means no tiers, not
    -- "not loaded yet": GetQualitiesForRecipe returns nil for tierless recipes (#19).
    local minQualityIDs = form.minQualityIDs
    local preferLowestQuality = minQualityIDs == nil or #minQualityIDs <= 1

    local entries, allRequiredResolved, excludedForVendor, excludedForOwned =
        self:GetChosenReagentEntries(schematicInfo, preferLowestQuality)
    return entries, allRequiredResolved, schematicInfo.name, excludedForVendor, excludedForOwned
end

-- Search strings, a "Name [xN], ..." summary, and the underlying term tables, in one pass.
---@return table searchStrings
---@return string summary
---@return table terms { searchString, tier, quantity, isExact }, parallel to searchStrings.
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

-- Applies signed quantity deltas to a list's search strings. A delta matches a line by name
-- and tier (as Auctionator does); unmatched positive deltas add a line, unmatched negative ones
-- are ignored, and lines at zero or below are dropped. Returns the full array, since
-- CreateShoppingList replaces a list's entire contents.
---@param existingSearchStrings table
---@param deltaTerms table Array of { searchString, tier, quantity } -- quantity is signed.
---@return table result
local function ApplyTermDeltas(existingSearchStrings, deltaTerms)
    local lines = {}
    for i, searchString in ipairs(existingSearchStrings) do
        local ok, term = pcall(Auctionator.API.v1.ConvertFromSearchString, ADDON_NAME, searchString)
        -- Unparseable lines pass through untouched.
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

-- Plain field, not a method: OrderShoppingPurchases.lua calls OrderScreen.ApplyTermDeltas(...).
OrderScreen.ApplyTermDeltas = ApplyTermDeltas

---@param terms table
---@return table negated Same terms with quantity negated.
local function NegateTerms(terms)
    local negated = {}
    for i, term in ipairs(terms) do
        negated[i] = { searchString = term.searchString, tier = term.tier, quantity = -term.quantity }
    end
    return negated
end

-- Chat note naming excluded itemIDs (#20, #23); "" when none, so callers can always append it.
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
---@return string? message Failure reason, or the chat confirmation plus any skipped-items note.
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

    -- Merge into the existing list (#24), first undoing this order's previous contribution.
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
        -- On a read failure, falls back to this order's items alone.
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
