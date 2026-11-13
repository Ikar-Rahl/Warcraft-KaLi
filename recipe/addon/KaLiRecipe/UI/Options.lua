-- The options, in a window of their own beside the notebook (Ikar, 2026-11-13: "Peut-être lui donner les options dans
-- une fenêtre séparée ?", then "comme dans flare"). Blizzard's options panel is a centre window, and opening it closes
-- the notebook, so nothing set there could be watched. This one leaves the notebook open: it's the shared settings
-- window (Shared/Dialog.lua), in the look of Blizzard's Edit Mode dialog, as KaLi Quest's dialog in Edit Mode, with its
-- folding sections, one open at a time. Changes apply at once; « Annuler les modifications » puts back what was set
-- when it opened, « Par défaut » every option's default.
--
-- The window has the look of the notebook's « Épuré » style, whatever the notebook's (Ikar, 2026-11-13: "Stylise un
-- peux la fetre d'ailleur, similaire a celle des recette (pas d'option, style minimaliste)").
--
-- The addon's page in the game's options, under AddOns, is one button to it, as FlareUI's page is to FlareUI's own
-- window. Reached from the notebook's gear, a right click on the compartment, the minimap button or an information
-- bar, and /kr options.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local category

local function refresh()
    if ns.book then
        ns.book:Invalidate()
    end
    ns.Changed()
end

local function check(key, name, tip, onChange)
    return { kind = "check", key = key, name = name, tip = tip, onChange = onChange }
end

local function slider(key, name, step, tip, format)
    return { kind = "slider", key = key, name = name, step = step, tip = tip, format = format }
end

-- values: { { value, label } }, in the list's order.
local function choice(key, name, values, tip, onChange)
    return { kind = "choice", key = key, name = name, values = values, tip = tip, onChange = onChange }
end

-- The volume as the game's own Audio sliders show theirs.
local function percent(value)
    return FormatPercentage and FormatPercentage(value / 100, true) or string.format("%d%%", value)
end

-- The sections of the options page they were on, in its order, under its names.
local function sections()
    local announce = { check("chat", L.OPT_CHAT, L.OPT_CHAT_TIP) }
    -- Each sound plays when it's picked, and a button under its list plays it again (Ikar, 2026-11-10). Put back by
    -- the window's buttons, they stay quiet.
    for _, kind in ipairs({ "recipe", "place" }) do
        local values = { { ns.Sounds.NONE, ns.G("NONE", L.SOUND_NONE) } }
        for _, c in ipairs(ns.Sounds.CHOICES[kind]) do
            values[#values + 1] = { c[1], L["SOUND_" .. c[1]] }
        end
        local upper = kind:upper()
        local row = choice(ns.Sounds.OPTION[kind], L["OPT_SOUND_" .. upper], values, L["OPT_SOUND_" .. upper .. "_TIP"],
            function(_, how)
                if not how then
                    ns.Sounds.Play(kind, true)
                end
            end)
        row.redraw = false
        announce[#announce + 1] = row
        announce[#announce + 1] = { kind = "button", name = "", text = L.SOUND_PLAY, tip = L.SOUND_PLAY_TIP, click = function()
            ns.Sounds.Play(kind, true)
        end }
    end
    -- Both sounds' volume (Ikar, 2026-11-12), up to 300 % in steps of 10, silent while dragged, as the game's own
    -- Audio sliders: « Écouter » plays at the new volume. Only on a game that takes a volume.
    if ns.Sounds.CanSetVolume() then
        local volume = slider(ns.Sounds.VOLUME, L.OPT_SOUND_VOLUME, 10, L.OPT_SOUND_VOLUME_TIP, percent)
        volume.redraw = false
        announce[#announce + 1] = volume
    end
    local minimap = check("minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TIP, function()
        ns.MinimapButton.Refresh()
    end)
    minimap.redraw = false
    return {
        { id = "announce", name = L.OPT_CHAT_SECTION, rows = announce },
        { id = "marks", name = L.OPT_MARKS, rows = {
            check("mKnown", L.OPT_M_KNOWN, L.OPT_M_KNOWN_TIP),
            check("mLearnable", L.OPT_M_LEARNABLE, L.OPT_M_LEARNABLE_TIP),
            check("mTooLow", L.OPT_M_TOOLOW, L.OPT_M_TOOLOW_TIP),
            check("mOwned", L.OPT_M_OWNED, L.OPT_M_OWNED_TIP),
            check("mAlt", L.OPT_M_ALT, L.OPT_M_ALT_TIP),
            check("mCraft", L.OPT_M_CRAFT, L.OPT_M_CRAFT_TIP),
            check("mCraftSeen", L.OPT_M_CRAFT_SEEN, L.OPT_M_CRAFT_SEEN_TIP),
        } },
        { id = "tips", name = L.OPT_TIPS, rows = {
            choice("recipeTip", L.OPT_RECIPE_TIP, { { "detailed", L.TIP_DETAILED }, { "compact", L.TIP_COMPACT },
                { "off", L.TIP_OFF } }, L.OPT_RECIPE_TIP_TIP),
            check("usedIn", L.OPT_USED_IN, L.OPT_USED_IN_TIP),
            check("usedInSeen", L.OPT_USED_IN_SEEN, L.OPT_USED_IN_SEEN_TIP),
            slider("usedInMax", L.OPT_USED_IN_MAX, 1),
            check("priceTrainer", L.OPT_PRICE_TRAINER, L.OPT_PRICE_TRAINER_TIP),
        } },
        { id = "notebook", name = L.OPT_NOTEBOOK, rows = {
            choice("style", L.OPT_STYLE, { { "clean", L.STYLE_CLEAN }, { "book", L.STYLE_BOOK } }, L.OPT_STYLE_TIP),
            check("follow", L.FOLLOW, L.FOLLOW_TIP, function(value)
                ns.Follow.Set(value)
            end),
            slider("width", L.OPT_WIDTH, 20),
            slider("height", L.OPT_HEIGHT, 20),
            check("nbOwned", L.OPT_NB_OWNED, L.OPT_NB_OWNED_TIP),
            check("nbAlt", L.OPT_NB_ALT, L.OPT_NB_ALT_TIP),
        } },
        { id = "windows", name = L.OPT_WINDOWS, rows = {
            check("a1", L.OPT_A1, L.OPT_A1_TIP),
            check("a2", L.OPT_A2, L.OPT_A2_TIP),
            check("showZero", L.OPT_ZERO, L.OPT_ZERO_TIP),
            check("pins", L.OPT_PINS, L.OPT_PINS_TIP),
        } },
        { id = "minimap", name = ns.G("MINIMAP_LABEL", L.OPT_MINIMAP_SECTION), rows = {
            minimap,
            check("minimapLock", L.OPT_MINIMAP_LOCK, L.OPT_MINIMAP_LOCK_TIP),
        } },
        { id = "diag", name = L.OPT_DIAG, rows = {
            { kind = "button", name = L.REPORT_TITLE, text = L.REPORT_OPEN, tip = L.REPORT_OPEN_TIP, click = function()
                ns.Report.Open()
            end },
        } },
    }
end

-- Beside the notebook, on the side with room for it; else in the middle of the screen.
local GAP = 10
local function place(window)
    local notebook = ns.Notebook.IsShown() and ns.Notebook.Frame()
    local left, right, top = notebook and notebook:GetLeft(), notebook and notebook:GetRight(), notebook and notebook:GetTop()
    window:ClearAllPoints()
    local width = window:GetWidth()
    if left and right and top then
        if right + GAP + width <= UIParent:GetWidth() then
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + GAP, top)
            return
        elseif left - GAP - width >= 0 then
            window:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - GAP, top)
            return
        end
    end
    window:SetPoint("CENTER", UIParent, "CENTER")
end

local handle = ns.Dialog.New({
    name = "KaLiRecipeOptions",
    title = ns.TITLE,
    sections = sections,
    open = "notebook",
    look = "window",
    options = function()
        return ns.db.options
    end,
    defaults = ns.DB.DEFAULTS,
    ranges = ns.DB.RANGES,
    apply = refresh,
    escape = true,
    snapshotOnOpen = true,
    place = place,
    buttons = {
        { key = "Revert", text = ns.G("HUD_EDIT_MODE_REVERT_CHANGES", "Annuler les modifications"), tip = L.OPTIONS_REVERT_TIP,
            click = function(h)
                h:Revert()
            end,
            enabled = function(h)
                return h:HasChanges()
            end },
        { key = "Divider", divider = true },
        { key = "Defaults", wide = true, text = ns.G("DEFAULTS", "Par défaut"), tip = L.OPTIONS_ALL_DEFAULTS_TIP,
            click = function(h)
                h:Defaults()
            end },
    },
})
Options.handle = handle

-- A change from elsewhere (the notebook's « Suivre », its corner grip, what the notebook learns) shows in the window
-- too, while it's open.
function Options.Changed()
    handle:Changed()
end
ns.OnChange(Options.Changed)

-- The page under AddOns: Blizzard's options close as the window opens, with their own Close, which keeps what was set
-- and asks first when a change waits for « Appliquer »; then the window waits.
local function fromPage()
    local panel = SettingsPanel
    if panel and panel:IsShown() and panel.Close then
        pcall(panel.Close, panel, true)
        if panel:IsShown() then
            return
        end
    end
    Options.Open()
end

function Options.Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L.OPTIONS, L.OPTIONS_OPEN, function()
            ns.SafeCall(fromPage)
        end, L.OPTIONS_OPEN_TIP, true))
    end
    Settings.RegisterAddOnCategory(category)
end

-- Nothing in it is held by the game's combat rules, so it opens in a fight too.
function Options.Open()
    if ns.db then
        handle:Open()
    end
end

function Options.Close()
    handle:Close()
end

-- The notebook's gear: open, else closed.
function Options.Toggle()
    if handle:IsShown() then
        handle:Close()
    else
        Options.Open()
    end
end

function Options.IsShown()
    return handle:IsShown()
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
