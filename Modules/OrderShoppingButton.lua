-- OrderShoppingButton.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- "+ Shopping List" button on the order screen (#18). Anchored to the bottom-right of
-- ProfessionsCustomerOrdersFrame itself (not .Form), on the same row as Profession Shopping
-- List's "Core Alloy" button, which anchors BOTTOMLEFT of that frame at (170, 5).

local _, ns = ...

local OrderScreen = ns.OrderScreen
local L = ns.L

-- Why the button is disabled, for its tooltip (#8). buttonEnabled hides it instead.
---@return string? reason nil when the button is/would be enabled
local function GetDisabledReason()
    if not OrderScreen:IsAuctionatorAvailable() then
        return L.STATUS_NO_AUCTIONATOR
    end

    local entries, allRequiredResolved = OrderScreen:GetShoppingEntries()
    if not allRequiredResolved then
        return L.STATUS_UNRESOLVED_REQUIRED
    end
    if not entries or #entries == 0 then
        return L.STATUS_NO_REAGENTS
    end

    return nil
end

local function RefreshButtonState(button)
    -- ns.db may not exist yet if the order addon loaded before ours (OnFormFound runs
    -- eagerly); treat that as the default (shown).
    if ns.db and not ns.db.settings.buttonEnabled then
        button:Hide()
        return
    end
    button:Show()

    button.disabledReason = GetDisabledReason()
    button:SetEnabled(button.disabledReason == nil)
end

local function OnClick()
    -- The message is either the confirmation or the failure reason.
    local _, message = OrderScreen:CreateShoppingList()
    if message then
        ns.Print(message)
    end
end

local function OnEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.disabledReason then
        GameTooltip_AddErrorLine(GameTooltip, button.disabledReason)
    else
        GameTooltip_AddNormalLine(GameTooltip, L.STATUS_READY)
    end
    GameTooltip:Show()
end

---@param form table ProfessionsCustomerOrdersFrame.Form
local function CreateButton(form)
    local button = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("BOTTOMRIGHT", ProfessionsCustomerOrdersFrame, -20, 5)
    button:SetText(L.BUTTON_LABEL)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)

    local function Refresh() RefreshButtonState(button) end

    -- For setting changes while the window is open (Options.lua, ResetToDefaults).
    ns.RefreshShoppingButton = Refresh

    form:HookScript("OnShow", Refresh)
    -- No event fires on recipe or allocation changes; the form calls UpdateReagentSlots on both.
    if form.UpdateReagentSlots then
        hooksecurefunc(form, "UpdateReagentSlots", Refresh)
    end

    Refresh()
end

OrderScreen:OnFormFound(CreateButton)
