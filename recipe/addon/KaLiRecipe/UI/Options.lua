-- The addon's page in the game's options, under AddOns, as the bench's « In-game options » scene shows it. Changes
-- apply at once; the last row of each section resets that section's (KaLi Quest's pattern). Reached from the addon
-- compartment (right click) and /kr options.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local category
local sectionSettings = {}
-- While a section's reset row puts its settings back, so the sounds' own preview stays quiet.
local resetting = false

local function refresh()
    if ns.book then
        ns.book:Invalidate()
    end
    ns.Changed()
end

local function variable(key)
    return "KALIRECIPE_" .. key:upper()
end

local function checkbox(key, name, tooltip, onChange)
    local o = ns.db.options
    local setting = Settings.RegisterAddOnSetting(category, variable(key), key, o, Settings.VarType.Boolean, name,
        ns.DB.DEFAULTS[key] and Settings.Default.True or Settings.Default.False)
    setting:SetValueChangedCallback(function(_, value)
        ns.SafeCall(onChange or refresh, value)
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
    table.insert(sectionSettings, setting)
end

local function slider(key, name, step, tooltip)
    local o = ns.db.options
    local range = ns.DB.RANGES[key]
    local setting = Settings.RegisterAddOnSetting(category, variable(key), key, o, Settings.VarType.Number, name, ns.DB.DEFAULTS[key])
    setting:SetValueChangedCallback(function()
        ns.SafeCall(refresh)
    end)
    local options = Settings.CreateSliderOptions(range[1], range[2], step)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, setting, options, tooltip)
    table.insert(sectionSettings, setting)
end

-- values: { { value, label } }, in the list's order.
local function dropdown(key, name, values, tooltip, onChange)
    local o = ns.db.options
    local setting = Settings.RegisterAddOnSetting(category, variable(key), key, o, Settings.VarType.String, name, ns.DB.DEFAULTS[key])
    setting:SetValueChangedCallback(function(_, value)
        ns.SafeCall(onChange or refresh, value)
    end)
    Settings.CreateDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, v in ipairs(values) do
            container:Add(v[1], v[2])
        end
        return container:GetData()
    end, tooltip)
    table.insert(sectionSettings, setting)
end

local function section(layout, text)
    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

-- Only settings off their default change.
local function resetRow(layout)
    local settings = sectionSettings
    sectionSettings = {}
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.OPTIONS_DEFAULTS, ns.G("RESET", "Réinitialiser"), function()
            resetting = true
            ns.SafeCall(function()
                for _, setting in ipairs(settings) do
                    if setting:GetValue() ~= setting:GetDefaultValue() then
                        setting:SetValueToDefault()
                    end
                end
            end)
            resetting = false
        end, L.OPTIONS_DEFAULTS_TIP, false))
    end
end

function Options.Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

    section(layout, L.OPT_CHAT_SECTION)
    checkbox("chat", L.OPT_CHAT, L.OPT_CHAT_TIP)
    -- Each sound plays when it's picked, and a button under its list plays it again (Ikar, 2026-11-10), a row as
    -- Blizzard's own settings put an action under a setting.
    for _, kind in ipairs({ "recipe", "place" }) do
        local values = { { ns.Sounds.NONE, ns.G("NONE", L.SOUND_NONE) } }
        for _, c in ipairs(ns.Sounds.CHOICES[kind]) do
            values[#values + 1] = { c[1], L["SOUND_" .. c[1]] }
        end
        local upper = kind:upper()
        dropdown(ns.Sounds.OPTION[kind], L["OPT_SOUND_" .. upper], values, L["OPT_SOUND_" .. upper .. "_TIP"], function()
            if not resetting then
                ns.Sounds.Play(kind, true)
            end
        end)
        if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
            layout:AddInitializer(CreateSettingsButtonInitializer("", L.SOUND_PLAY, function()
                ns.SafeCall(ns.Sounds.Play, kind, true)
            end, L.SOUND_PLAY_TIP, false))
        end
    end
    resetRow(layout)

    section(layout, L.OPT_MARKS)
    checkbox("mKnown", L.OPT_M_KNOWN, L.OPT_M_KNOWN_TIP)
    checkbox("mLearnable", L.OPT_M_LEARNABLE, L.OPT_M_LEARNABLE_TIP)
    checkbox("mTooLow", L.OPT_M_TOOLOW, L.OPT_M_TOOLOW_TIP)
    checkbox("mOwned", L.OPT_M_OWNED, L.OPT_M_OWNED_TIP)
    checkbox("mAlt", L.OPT_M_ALT, L.OPT_M_ALT_TIP)
    checkbox("mVendor", L.OPT_M_VENDOR, L.OPT_M_VENDOR_TIP)
    checkbox("mCraft", L.OPT_M_CRAFT, L.OPT_M_CRAFT_TIP)
    checkbox("mCraftSeen", L.OPT_M_CRAFT_SEEN, L.OPT_M_CRAFT_SEEN_TIP)
    resetRow(layout)

    section(layout, L.OPT_TIPS)
    dropdown("recipeTip", L.OPT_RECIPE_TIP, { { "detailed", L.TIP_DETAILED }, { "compact", L.TIP_COMPACT }, { "off", L.TIP_OFF } },
        L.OPT_RECIPE_TIP_TIP)
    checkbox("usedIn", L.OPT_USED_IN, L.OPT_USED_IN_TIP)
    checkbox("usedInSeen", L.OPT_USED_IN_SEEN, L.OPT_USED_IN_SEEN_TIP)
    slider("usedInMax", L.OPT_USED_IN_MAX, 1)
    checkbox("priceTrainer", L.OPT_PRICE_TRAINER, L.OPT_PRICE_TRAINER_TIP)
    resetRow(layout)

    section(layout, L.OPT_NOTEBOOK)
    dropdown("style", L.OPT_STYLE, { { "clean", L.STYLE_CLEAN }, { "book", L.STYLE_BOOK } }, L.OPT_STYLE_TIP)
    checkbox("follow", L.FOLLOW, L.FOLLOW_TIP, function(value)
        ns.Follow.Set(value)
        refresh()
    end)
    slider("width", L.OPT_WIDTH, 20)
    slider("height", L.OPT_HEIGHT, 20)
    checkbox("nbOwned", L.OPT_NB_OWNED, L.OPT_NB_OWNED_TIP)
    checkbox("nbAlt", L.OPT_NB_ALT, L.OPT_NB_ALT_TIP)
    resetRow(layout)

    section(layout, L.OPT_WINDOWS)
    checkbox("a1", L.OPT_A1, L.OPT_A1_TIP)
    checkbox("a2", L.OPT_A2, L.OPT_A2_TIP)
    checkbox("showZero", L.OPT_ZERO, L.OPT_ZERO_TIP)
    checkbox("pins", L.OPT_PINS, L.OPT_PINS_TIP)
    checkbox("ah", L.OPT_AH, L.OPT_AH_TIP)
    resetRow(layout)

    section(layout, ns.G("MINIMAP_LABEL", L.OPT_MINIMAP_SECTION))
    checkbox("minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TIP, function()
        ns.MinimapButton.Refresh()
    end)
    checkbox("minimapLock", L.OPT_MINIMAP_LOCK, L.OPT_MINIMAP_LOCK_TIP)
    resetRow(layout)

    section(layout, L.OPT_DIAG)
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.REPORT_TITLE, L.REPORT_OPEN, function()
            ns.SafeCall(ns.Report.Open)
        end, L.REPORT_OPEN_TIP, true))
    end
    Settings.RegisterAddOnCategory(category)
end

-- The options panel can't open in combat.
function Options.Open()
    if InCombatLockdown() then
        if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
            UIErrorsFrame:AddExternalErrorMessage(ns.G("ERR_NOT_IN_COMBAT", "In combat"))
        end
        return
    end
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end

-- A click on any of the addon's buttons (the compartment, the minimap button, an information bar's): the notebook, or
-- the options with the right button.
function Options.Click(button)
    if not ns.db then
        ns.Say(string.format(L.DB_REFUSED, tostring(ns.disabled)))
        return
    end
    ns.SafeCall(function()
        if button == "RightButton" then
            Options.Open()
        else
            ns.Notebook.Toggle()
        end
    end)
end

-- What those buttons' tooltip says: each profession's two counts, then the hints. No total (Ikar's ruling of
-- 2026-11-09). The tooltip is already owned; an information bar shows it itself.
function Options.FillTooltip(tooltip, canDrag)
    tooltip:AddLine(ns.TITLE, 1, 1, 1)
    local m = ns.book
    if m then
        for _, skill in ipairs(m:ProfsOf(m.me)) do
            local learn, seen = m:Counts(m.me, skill)
            tooltip:AddDoubleLine(ns.Game.ProfName(skill), string.format(L.TO_LEARN, learn) .. " · " ..
                ns.Plural(seen, L.SEEN_ONE, L.SEEN_MANY), 1, 0.82, 0, 1, 1, 1)
        end
        local others = m:OtherSeen(m.me)
        if others > 0 then
            tooltip:AddDoubleLine(L.OTHER_PROFESSIONS, ns.Plural(others, L.SEEN_ONE, L.SEEN_MANY), 1, 0.82, 0, 1, 1, 1)
        end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(L.COMPARTMENT_CLICK, 0.1, 1, 0.1)
    tooltip:AddLine(L.RIGHT_CLICK_OPTIONS, 0.1, 1, 0.1)
    if canDrag then
        tooltip:AddLine(L.DRAG_MOVE, 0.1, 1, 0.1)
    end
end

-- The compartment.
function KaLiRecipe_OnAddonCompartmentClick(_, button)
    Options.Click(button)
end

function KaLiRecipe_OnAddonCompartmentEnter(_, button)
    ns.SafeCall(function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        Options.FillTooltip(GameTooltip)
        GameTooltip:Show()
    end)
end

function KaLiRecipe_OnAddonCompartmentLeave(_, button)
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end
