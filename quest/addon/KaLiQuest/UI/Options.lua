-- The addon's page in the game's options, under AddOns. Reached from the gear on the title row, the addon
-- compartment and /kq options. Changes apply at once; the panel's Defaults button resets them all, and the last
-- row of each section resets that section's.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local category
local tips -- the tips page, under the addon's own
local sectionSettings = {} -- the section being built, for its reset row

local function refresh()
    ns.RequestRefresh()
end

local function percent(value)
    return string.format("%d %%", value)
end

local function slider(setting, key, step, tooltip, format)
    local range = ns.DB.RANGES[key]
    local options = Settings.CreateSliderOptions(range[1], range[2], step)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
    end
    Settings.CreateSlider(category, setting, options, tooltip)
    table.insert(sectionSettings, setting)
end

local function number(key, name, default, step, tooltip, format)
    local o = ns.db.options
    local setting = Settings.RegisterAddOnSetting(category, "KALIQUEST_" .. key:upper(), key, o, Settings.VarType.Number, name, default)
    setting:SetValueChangedCallback(refresh)
    slider(setting, key, step, tooltip, format)
end

-- tbl: where the value is kept, the options table unless given.
local function checkbox(key, name, default, tooltip, onChange, tbl, variable)
    local setting = Settings.RegisterAddOnSetting(category, variable or "KALIQUEST_" .. key:upper(), key, tbl or ns.db.options,
        Settings.VarType.Boolean, name, default and Settings.Default.True or Settings.Default.False)
    setting:SetValueChangedCallback(function(_, value)
        ns.SafeCall(onChange or refresh, value)
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
    table.insert(sectionSettings, setting)
end

-- values: { { value, label } }, in the list's order.
local function dropdown(key, name, default, values, tooltip)
    local o = ns.db.options
    local setting = Settings.RegisterAddOnSetting(category, "KALIQUEST_" .. key:upper(), key, o, Settings.VarType.String, name, default)
    setting:SetValueChangedCallback(refresh)
    Settings.CreateDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, v in ipairs(values) do
            container:Add(v[1], v[2])
        end
        return container:GetData()
    end, tooltip)
    table.insert(sectionSettings, setting)
end

-- Height follows Edit Mode until set here; whichever was changed last wins.
local function proxy(key, name, default, step, current)
    local o = ns.db.options
    local setting = Settings.RegisterProxySetting(category, "KALIQUEST_" .. key:upper(), Settings.VarType.Number, name, default,
        function()
            return o[key] or current()
        end,
        function(value)
            o[key] = value
            refresh()
        end)
    slider(setting, key, step, L.OPTION_LAST_WINS)
end

local function section(layout, text)
    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

-- Only settings off their default change: the tracker switch, already on, mustn't resume over Blizzard's.
local function resetRow(layout)
    local settings = sectionSettings
    sectionSettings = {}
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.OPTIONS_DEFAULTS, ns.G("RESET", "Réinitialiser"), function()
            ns.SafeCall(function()
                for _, setting in ipairs(settings) do
                    if setting:GetValue() ~= setting:GetDefaultValue() then
                        setting:SetValueToDefault()
                    end
                end
            end)
        end, L.OPTIONS_DEFAULTS_TIP, false))
    end
end

-- Each marker by the name its tooltip gives it.
local function markerName(kind)
    local names = {
        offlist = L.PAST_LIMIT_SHORT, timed = L.FILTER_V_TIMED, size = L.MARKER_GROUP_SIZE,
        dungeon = ns.G("CALENDAR_TYPE_DUNGEON", "Donjon"), raid = ns.G("RAID", "Raid"), pvp = ns.G("CALENDAR_TYPE_PVP", "JcJ"),
        repeatable = L.FILTER_V_REPEATABLE, daily = L.FILTER_V_DAILY, weekly = L.FILTER_V_WEEKLY, legendary = L.FILTER_V_LEGENDARY,
        class = ns.G("CLASS", "Classe"),
    }
    return names[kind]
end

-- Shortcuts and the rules no button shows, laid out as Blizzard's own pages: a title over a divider, white section
-- headings, then a gold label with its text wrapping beside it.
local TIP_LABEL = 110
local function buildTips()
    local f = CreateFrame("Frame")
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(L.TIPS_TITLE)
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", 0, -50)
    local bindings = table.concat({ ns.G("SETTINGS_TITLE", "Options"), ns.G("SETTINGS_KEYBINDINGS_LABEL", "Raccourcis clavier"),
        ns.G("ADDONS", "Add-ons") }, " > ")
    local above, aboveLeft
    local function place(region, left, gap)
        if above then
            region:SetPoint("TOPLEFT", above, "BOTTOMLEFT", left - aboveLeft, -gap)
        else
            region:SetPoint("TOPLEFT", left, -66)
        end
    end
    for _, s in ipairs(L.TIPS) do
        local heading = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        place(heading, 7, 18)
        heading:SetText(s.title)
        above, aboveLeft = heading, 7
        for _, r in ipairs(s.rows) do
            local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            place(label, 37, 10)
            label:SetWidth(TIP_LABEL)
            label:SetJustifyH("LEFT")
            label:SetText(r[1])
            local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, 0)
            text:SetPoint("RIGHT", f, "RIGHT", -30, 0)
            text:SetJustifyH("LEFT")
            text:SetText(r[2]:find("%s", 1, true) and r[2]:format(bindings) or r[2])
            above, aboveLeft = text, 37 + TIP_LABEL + 10
        end
    end
    return f
end

function Options.Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.TIPS_TITLE, L.TIPS_OPEN, function()
            ns.SafeCall(Options.OpenTips)
        end, L.TIPS_OPEN_TIP, true))
    end
    checkbox("tracker", L.OPTION_TRACKER, true, L.OPTION_TRACKER_TIP, function(value)
        if value then
            ns.Coverage.Resume()
        else
            ns.Tracker.SetEnabled(false)
        end
    end)
    checkbox("autoQuestWatch", ns.G("AUTO_QUEST_WATCH_TEXT", "Suivi automatique de quête"), false,
        ns.G("OPTION_TOOLTIP_AUTO_QUEST_WATCH", nil), function(value)
            ns.Tracking.SetAutoQuestWatch(value)
        end)
    checkbox("progressFlash", L.GLOW, true, L.OPTION_GLOW_TIP)
    checkbox("areaHighlight", L.AREA_HIGHLIGHT, true, L.OPTION_AREA_TIP, function()
        ns.Area.Apply()
    end)
    -- Forever doesn't load Blizzard's group finder, so there the eye couldn't open anything.
    if ns.Filter.GroupFinderAvailable() then
        checkbox("findGroup", L.OPTION_FIND_GROUP, false, ns.G("TOOLTIP_TRACKER_FIND_GROUP_BUTTON", nil))
    end
    checkbox("shareOnHover", L.OPTION_SHARE_HOVER, true, L.OPTION_SHARE_HOVER_TIP)
    resetRow(layout)

    local D = ns.DB.DEFAULTS
    section(layout, L.OPTIONS_LOOK)
    number("zoom", L.OPTION_ZOOM, D.zoom, 5, L.OPTION_ZOOM_TIP, percent)
    number("width", L.OPTION_WIDTH, D.width, 2)
    proxy("height", L.OPTION_HEIGHT, D.height, 10, function()
        return math.floor(ns.Host.Height() + 0.5)
    end)
    number("blockRest", L.OPTION_BLOCK_REST, D.blockRest, 5, nil, percent)
    number("blockCombat", L.OPTION_BLOCK_COMBAT, D.blockCombat, 5, nil, percent)
    number("blockHover", L.OPTION_BLOCK_HOVER, D.blockHover, 5, nil, percent)
    number("opacity", L.OPTION_OPACITY, D.opacity, 5, nil, percent)
    number("opacityCombat", L.OPTION_OPACITY_COMBAT, D.opacityCombat, 5, nil, percent)
    number("saturation", L.OPTION_SATURATION, D.saturation, 5, nil, percent)
    dropdown("markerStyle", L.OPTION_MARKERS, "icons", { { "icons", L.MARKERS_ICONS }, { "text", L.MARKERS_TEXT },
        { "none", L.MARKERS_NONE } }, L.OPTION_MARKERS_TIP)
    resetRow(layout)

    section(layout, L.OPTIONS_MARKERS)
    for _, kind in ipairs(ns.DB.MARKERS) do
        checkbox(kind, markerName(kind), true, L.OPTION_MARKER_TIP, nil, ns.db.options.markers, "KALIQUEST_MARKER_" .. kind:upper())
    end
    resetRow(layout)

    section(layout, L.OPTIONS_ADVANCED)
    number("titleGap", L.OPTION_TITLE_GAP, D.titleGap, 1)
    number("groupIndent", L.OPTION_GROUP_INDENT, D.groupIndent, 1)
    number("questIndent", L.OPTION_QUEST_INDENT, D.questIndent, 1)
    number("groupGap", L.OPTION_GROUP_GAP, D.groupGap, 1)
    number("barGap", L.OPTION_BAR_GAP, D.barGap, 1)
    number("markerSize", L.OPTION_MARKER_SIZE, D.markerSize, 1)
    resetRow(layout)

    section(layout, L.DIAG_TITLE)
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.DIAG_TITLE, L.DIAG_OPEN, function()
            ns.SafeCall(ns.DebugPanel.Open)
        end, L.DIAG_OPEN_TIP, true))
        layout:AddInitializer(CreateSettingsButtonInitializer(L.REPORT_TITLE, L.REPORT_OPEN, function()
            ns.SafeCall(ns.Report.Open)
        end, L.REPORT_OPEN_TIP, true))
    end

    if Settings.RegisterCanvasLayoutSubcategory then
        tips = Settings.RegisterCanvasLayoutSubcategory(category, buildTips(), L.TIPS_TITLE)
    end
    Settings.RegisterAddOnCategory(category)
end

-- The options panel can't open in combat.
local function open(target)
    if InCombatLockdown() then
        if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
            UIErrorsFrame:AddExternalErrorMessage(ns.G("ERR_NOT_IN_COMBAT", "In combat"))
        end
        return
    end
    if target then
        Settings.OpenToCategory(target:GetID())
    end
end

function Options.Open()
    open(category)
end

function Options.OpenTips()
    open(tips)
end

-- With the saved data refused, there are no options to open, so the click says why, as /kq does.
function KaLiQuest_OnAddonCompartmentClick()
    if not ns.db then
        ns.Say(string.format(L.DB_REFUSED, tostring(ns.disabled)))
        return
    end
    ns.SafeCall(Options.Open)
end

-- The compartment's entry says what a click does, as the minimap buttons of other addons do.
function KaLiQuest_OnAddonCompartmentEnter(_, button)
    ns.SafeCall(function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.TITLE)
        GameTooltip:AddLine(L.COMPARTMENT_CLICK, 1, 1, 1)
        GameTooltip:Show()
    end)
end

function KaLiQuest_OnAddonCompartmentLeave(_, button)
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end
