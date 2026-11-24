-- The addon's page in the game's options, under AddOns. Reached from the gear on the title row, the addon
-- compartment and /kq options. Changes apply at once; the row under the check boxes puts them back to their defaults.
-- It's a page of the addon's own (Shared/Page.lua), in the look of Blizzard's: nothing of it goes into the game's own
-- lists of settings, where the game blamed the addon for what its Social page did (2026-11-12).
--
-- The tracker's size, place and look are set in Edit Mode only, on its own frame there (UI/EditPanel.lua): Ikar, on
-- 2026-11-13, "comme dans flare, enlever les options kali quest qui sont gérées par le mode édition, et y mettre un
-- bouton vers le mode édition". The page keeps what Edit Mode doesn't hold, and a button that goes there.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local page -- the addon's page
local tips -- the tips page, under it

local function refresh()
    ns.RequestRefresh()
end

-- A check box's row for an option: what it shows is the option, and a change is told once, to onChange or the tracker.
local function check(key, name, default, tip, onChange)
    return { kind = "check", key = key, default = default, name = name, tip = tip,
        get = function()
            return ns.db.options[key] == true
        end,
        set = function(value)
            if (ns.db.options[key] == true) ~= value then
                ns.db.options[key] = value
                ns.SafeCall(onChange or refresh, value)
            end
        end }
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

-- The page's rows, in its order, asked for when it first shows.
local function rows()
    local list = { { kind = "button", name = L.TIPS_TITLE, text = L.TIPS_OPEN, tip = L.TIPS_OPEN_TIP, click = Options.OpenTips } }
    local checks = {
        check("tracker", L.OPTION_TRACKER, true, L.OPTION_TRACKER_TIP, function(value)
            if value then
                ns.Coverage.Resume()
            else
                ns.Tracker.SetEnabled(false)
            end
        end),
        check("autoQuestWatch", ns.G("AUTO_QUEST_WATCH_TEXT", "Suivi automatique de quête"), false,
            ns.G("OPTION_TOOLTIP_AUTO_QUEST_WATCH", nil), function(value)
                ns.Tracking.SetAutoQuestWatch(value)
            end),
    }
    -- Forever doesn't load Blizzard's group finder, so there the eye couldn't open anything.
    if ns.Filter.GroupFinderAvailable() then
        checks[#checks + 1] = check("findGroup", L.OPTION_FIND_GROUP, false, ns.G("TOOLTIP_TRACKER_FIND_GROUP_BUTTON", nil))
    end
    for _, row in ipairs(checks) do
        list[#list + 1] = row
    end
    -- Only options off their default change: the tracker switch, already on, mustn't resume over Blizzard's.
    list[#list + 1] = { kind = "button", name = L.OPTIONS_DEFAULTS, text = ns.G("RESET", "Réinitialiser"), tip = L.OPTIONS_DEFAULTS_TIP,
        click = function()
            for _, row in ipairs(checks) do
                row.set(row.default)
            end
        end }
    -- Where the size and look went: Edit Mode, the tracker picked, under the game's own name for it.
    list[#list + 1] = { kind = "header", text = L.OPTIONS_LOOK }
    list[#list + 1] = { kind = "button", name = L.OPTION_EDIT_MODE, text = ns.G("HUD_EDIT_MODE_MENU", "Mode Édition"),
        tip = L.OPTION_EDIT_MODE_TIP, click = ns.EditFrame.OpenEditMode }
    -- The report alone: the diagnostics panel stays with developers, /kq diag (Ikar 2026-11-24: "kali quest still has
    -- the diagnose button, to be removed"; the gear's menu lost it 2026-11-11)
    list[#list + 1] = { kind = "header", text = L.REPORT_TITLE }
    list[#list + 1] = { kind = "button", name = L.REPORT_TITLE, text = L.REPORT_OPEN, tip = L.REPORT_OPEN_TIP, click = ns.Report.Open }
    return list
end

function Options.Register()
    if page then
        return
    end
    page = ns.Page.New({ name = ns.TITLE, rows = rows, pages = { { name = L.TIPS_TITLE, frame = buildTips() } } })
    tips = page.pages[1]
    Options.page, Options.tips = page, tips
end

-- The game's options can't open in combat: the page says so (Shared/Page.lua).
function Options.Open()
    return page ~= nil and page:Open()
end

function Options.OpenTips()
    return tips ~= nil and tips:Open()
end

-- A change made elsewhere, while the page shows.
function Options.Changed()
    if page then
        page:Refresh()
    end
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
