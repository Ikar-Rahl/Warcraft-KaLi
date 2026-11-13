-- The addon's page in the game's options, under AddOns. Reached from the gear on the title row, the addon
-- compartment and /kq options. Changes apply at once; the panel's Defaults button resets them all, and the last
-- row of a section resets that section's.
--
-- The tracker's size, place and look are set in Edit Mode only, on its own frame there (UI/EditPanel.lua): Ikar, on
-- 2026-11-13, "comme dans flare, enlever les options kali quest qui sont gérées par le mode édition, et y mettre un
-- bouton vers le mode édition". The page keeps what Edit Mode doesn't hold, and a button that goes there.
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

local function checkbox(key, name, default, tooltip, onChange)
    local setting = Settings.RegisterAddOnSetting(category, "KALIQUEST_" .. key:upper(), key, ns.db.options,
        Settings.VarType.Boolean, name, default and Settings.Default.True or Settings.Default.False)
    setting:SetValueChangedCallback(function(_, value)
        ns.SafeCall(onChange or refresh, value)
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
    table.insert(sectionSettings, setting)
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

-- Each marker by the name its tooltip gives it, for Edit Mode's dialog.
local function markerName(kind)
    local names = {
        offlist = L.PAST_LIMIT_SHORT, timed = L.FILTER_V_TIMED, size = L.MARKER_GROUP_SIZE,
        dungeon = ns.G("CALENDAR_TYPE_DUNGEON", "Donjon"), raid = ns.G("RAID", "Raid"), pvp = ns.G("CALENDAR_TYPE_PVP", "JcJ"),
        repeatable = L.FILTER_V_REPEATABLE, daily = L.FILTER_V_DAILY, weekly = L.FILTER_V_WEEKLY, legendary = L.FILTER_V_LEGENDARY,
        class = ns.G("CLASS", "Classe"),
    }
    return names[kind]
end
Options.MarkerName = markerName

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
    -- Forever doesn't load Blizzard's group finder, so there the eye couldn't open anything.
    if ns.Filter.GroupFinderAvailable() then
        checkbox("findGroup", L.OPTION_FIND_GROUP, false, ns.G("TOOLTIP_TRACKER_FIND_GROUP_BUTTON", nil))
    end
    resetRow(layout)

    -- Where the size and look went: Edit Mode, the tracker picked, under the game's own name for it.
    section(layout, L.OPTIONS_LOOK)
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.OPTION_EDIT_MODE, ns.G("HUD_EDIT_MODE_MENU", "Mode Édition"),
            function()
                ns.SafeCall(ns.EditFrame.OpenEditMode)
            end, L.OPTION_EDIT_MODE_TIP, true))
    end

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
    if ns.CombatRefused() then
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
