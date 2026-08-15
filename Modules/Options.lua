-- Options.lua
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Options panel (issue #16), matching Crosshairs' and ShoppingConverter's own Options.lua
-- conventions rather than inventing a new one: Settings.RegisterCanvasLayoutCategory +
-- Settings.RegisterAddOnCategory, a CHECKBOXES table Commands.lua's `status` reuses so the
-- two entry points can't list different settings under different labels. Thin by design --
-- there's no tunable optimization behavior in this addon, just a handful of on/off settings.
-- A definition's optional `onChange` (matching Crosshairs' own AddCheckbox(label, tooltip,
-- dbKey, onChange) signature) fires after the setting is written, for a setting whose effect
-- needs to be visible immediately rather than waiting for its own next natural refresh --
-- confirmed in-game that buttonEnabled needed this: toggling it didn't take effect until the
-- order window was closed and reopened.

local _, ns = ...

local L = ns.L

local Options = {}
ns.Options = Options

-- Exposed as Options.CHECKBOXES so Commands.lua's `status` can list the same toggles under
-- the same labels without a second hand-maintained copy.
local CHECKBOXES = {
    {
        key = "buttonEnabled",
        label = L.OPTIONS_BUTTON_ENABLED_LABEL,
        tooltip = L.OPTIONS_BUTTON_ENABLED_TOOLTIP,
        onChange = function()
            if ns.RefreshShoppingButton then ns.RefreshShoppingButton() end
        end,
    },
    {
        key = "printOnLogin",
        label = L.OPTIONS_LOGIN_MESSAGE_LABEL,
        tooltip = L.OPTIONS_LOGIN_MESSAGE_TOOLTIP,
    },
    {
        key = "maxQualityEnabled",
        label = L.OPTIONS_MAX_QUALITY_LABEL,
        tooltip = L.OPTIONS_MAX_QUALITY_TOOLTIP,
    },
}
Options.CHECKBOXES = CHECKBOXES

local function CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = L.OPTIONS_TITLE

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.OPTIONS_TITLE)

    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    versionText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
    versionText:SetText(ns.VERSION)

    local checkboxes = {}
    local anchor = title
    for _, definition in ipairs(CHECKBOXES) do
        local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == title and -2 or 0, -12)
        checkbox.Text:SetText(definition.label)
        checkbox.tooltipText = definition.label
        checkbox.tooltipRequirement = definition.tooltip
        checkbox:SetScript("OnClick", function(self)
            ns.db.settings[definition.key] = self:GetChecked() and true or false
            if definition.onChange then definition.onChange() end
        end)
        checkboxes[#checkboxes + 1] = { checkbox = checkbox, key = definition.key }
        anchor = checkbox
    end
    -- Exposed for tests to reach the checkbox frames directly by key, without guessing their
    -- position among every frame stub_api.lua's CreateFrame ever created.
    panel.checkboxes = checkboxes

    function panel.RefreshWidgets()
        for _, entry in ipairs(checkboxes) do
            entry.checkbox:SetChecked(ns.db.settings[entry.key] and true or false)
        end
    end

    panel:SetScript("OnShow", panel.RefreshWidgets)

    return panel
end

-- Registered once at load: the category needs to exist for the Settings window to list it
-- any time the player opens it, not just while the order screen is open.
function Options:Register()
    self.panel = CreatePanel()
    local category = Settings.RegisterCanvasLayoutCategory(self.panel, L.OPTIONS_TITLE)
    Settings.RegisterAddOnCategory(category)
    self.category = category
end

-- Opens the Settings window straight to this panel, e.g. from /bestcraft options.
function Options:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end

-- Shared by ns.ResetToDefaults (Core.lua) and anything else that changes a setting out from
-- under an already-open panel, so a stale checkbox can't sit checked/unchecked opposite to
-- what /bestcraft reset or /bestcraft login just set.
function Options:RefreshWidgets()
    if self.panel and self.panel.RefreshWidgets then
        self.panel.RefreshWidgets()
    end
end

Options:Register()
