-- KaLi HUD's settings dialog in Edit Mode (Shared/Dialog.lua), opened when the KaLi HUD bar along the foot is picked:
-- nine collapsible sections covering the style (a whole look at once, Data/Presets.lua), the plate & reach, the borders & backgrounds of our frames, per-component
-- margins (with one quick slider for all action bars), full minimap settings, window & bag folding, each status bar's
-- own (opened by clicking the bar) and the info bar. Every change applies live. Each section ends in its own
-- « Annuler » and « Par défaut »; the window's « Par défaut » asks first.
local _, ns = ...
local L = ns.L

local EditPanel = {}
ns.EditPanel = EditPanel

local function percent(value)
    return string.format("%d %%", value)
end

local function cornersLimit(value)
    return value >= ns.DB.UNLIMITED_CORNERS and L.UNLIMITED or tostring(value)
end

local function widthOrAuto(value)
    return value <= 0 and L.WIDTH_AUTO or string.format("%d", value)
end

local function slider(key, name, step, format, tip)
    return { kind = "slider", key = key, name = name, step = step, format = format, tip = tip }
end

local function check(key, name, tip, default, onChange)
    return { kind = "check", key = key, name = name, tip = tip, default = default, onChange = onChange }
end

local function choice(key, name, values, tip, onChange)
    return { kind = "choice", key = key, name = name, values = values, tip = tip, onChange = onChange }
end

-- A value changed draws the HUD again at once; Revert and Defaults, the window's and a section's, which change many,
-- draw it once after the last.
local batching, missed = false, false

local function apply()
    if batching then
        missed = true
    else
        ns.ApplyAll()
    end
end

local function applyOnce(method, h)
    batching, missed = true, false
    ns.SafeCall(method, h)
    batching = false
    if missed then
        ns.ApplyAll()
    end
end

-- Where a status bar was dragged (StatusBars.lua, ns.db.statusPlaces by "left" or "right"), its section's extra: the
-- window's « Annuler les modifications » and the section's « Annuler » put it back with the settings. Held in a table,
-- since nil, the bar along the info bar, is a place too.
local function placeExtra(name)
    local function copy(p)
        return p and { x = p.x, y = p.y, w = p.w }
    end
    return {
        take = function()
            return { copy(ns.db.statusPlaces[name]) }
        end,
        same = function(held)
            local p, q = held[1], ns.db.statusPlaces[name]
            if not (p and q) then
                return p == q
            end
            return p.x == q.x and p.y == q.y and p.w == q.w
        end,
        put = function(held)
            ns.db.statusPlaces[name] = copy(held[1])
            apply()
        end,
    }
end

-- ---------- The styles (Data/Presets.lua) ----------
-- Ikar 2026-11-16: "presets ... centered around a minimap style, and a color", and "when selecting and user have custom
-- change, a warning that the changes may be lost should be given. Only for options the preset touch."

-- The style the look is, every value it sets as it set it; else none.
local function matched()
    local o = ns.db.options
    for _, preset in ipairs(ns.PRESETS) do
        local all = true
        for _, key in ipairs(ns.PRESET_KEYS) do
            all = all and o[key] == preset[key]
        end
        if all then
            return preset
        end
    end
end

-- What the player changed among what `preset` sets, and it would replace: each value neither the one it puts nor the
-- one the style last applied put (options.preset; the first's, the defaults', when none was). None while the look is a
-- style's as it set it: going from one style to another loses nothing.
local function ownChanges(preset)
    local keys = {}
    if matched() then
        return keys
    end
    local o = ns.db.options
    local last = ns.PRESET_BY_ID[o.preset] or ns.PRESETS[1]
    for _, key in ipairs(ns.PRESET_KEYS) do
        if o[key] ~= preset[key] and o[key] ~= last[key] then
            keys[#keys + 1] = key
        end
    end
    return keys
end

local function applyPreset(preset)
    local o = ns.db.options
    for _, key in ipairs(ns.PRESET_KEYS) do
        o[key] = preset[key]
    end
    o.preset = preset.id
    apply()
end

-- Each value's name in the question, as its row says it, on one line.
local function optionName(key)
    local names = { minimapRing = L.OPT_MM_RING, borderColor = L.OPT_BORDER_COLOR, bgColor = L.OPT_BG_COLOR,
        bgStyle = L.OPT_BG_STYLE, foldArt = L.OPT_FOLD_ART, cornerStyle = L.OPT_CORNER_STYLE }
    return (names[key] or key):gsub("%-\n", ""):gsub("\n", " ")
end

-- A style picked over values the player changed asks first, naming them; a yes once a fight has greyed the window does
-- nothing, as the window's « Par défaut ».
local function askPreset(preset, keys)
    StaticPopupDialogs.KALIHUD_PRESET = StaticPopupDialogs.KALIHUD_PRESET or {
        text = L.PRESET_ASK,
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = ns.Guarded(function(_, data)
            if not ns.InCombat() then
                applyPreset(data)
                EditPanel.Changed()
            end
        end),
    }
    local names = {}
    for _, key in ipairs(keys) do
        names[#names + 1] = optionName(key)
    end
    StaticPopup_Show("KALIHUD_PRESET", L["PRESET_" .. preset.id], table.concat(names, ", "), preset)
end

-- A style picked in the window: applied at once, unless it would replace what the player changed; put back by the
-- window's or the section's buttons ("revert", "defaults"), applied without asking. "custom" holds nothing: the values
-- are put back by their own rows and the section's extra.
local function pickPreset(id, how)
    local preset = ns.PRESET_BY_ID[id]
    if not preset then
        return
    end
    local lost = how == nil and ownChanges(preset) or {}
    if #lost > 0 then
        askPreset(preset, lost)
        return
    end
    applyPreset(preset)
    if how == nil then
        EditPanel.Changed()
    end
end

-- The style row's value: the style the look is, else « Personnalisé ». It keeps nothing itself; a pick does its work in
-- pickPreset, so a style asked about and refused leaves the row as it was.
local presetProxy = setmetatable({}, {
    __index = function(_, k)
        if k == "preset" then
            local preset = matched()
            return preset and preset.id or "custom"
        end
    end,
    __newindex = function() end,
})

local function presetValues()
    local values = {}
    for _, preset in ipairs(ns.PRESETS) do
        values[#values + 1] = { preset.id, L["PRESET_" .. preset.id] }
    end
    if not matched() then
        values[#values + 1] = { "custom", L.PRESET_CUSTOM }
    end
    return values
end

-- The style section's extra: every value a style sets and the style last applied, so its « Annuler » (and the
-- window's) puts the look back as it was, a look of the player's own too.
local styleExtra = {
    take = function()
        local o, held = ns.db.options, { preset = ns.db.options.preset }
        for _, key in ipairs(ns.PRESET_KEYS) do
            held[key] = o[key]
        end
        return held
    end,
    same = function(held)
        local o = ns.db.options
        for _, key in ipairs(ns.PRESET_KEYS) do
            if o[key] ~= held[key] then
                return false
            end
        end
        return o.preset == held.preset
    end,
    put = function(held)
        local o = ns.db.options
        for _, key in ipairs(ns.PRESET_KEYS) do
            o[key] = held[key]
        end
        o.preset = held.preset
        apply()
    end,
}

local function showModes()
    return {
        { "always", L.SHOW_ALWAYS },
        { "hover", L.SHOW_HOVER },
        { "off", L.SIDE_hidden },
    }
end

local function statusKinds()
    return {
        { "xp", L.STATUS_xp },
        { "rep", L.STATUS_rep },
        { "honor", L.STATUS_honor },
        { "none", L.STATUS_none },
    }
end

-- A status bar's own section, all its settings (Ikar 2026-11-15: "make all the setting local to each bar"): what it
-- shows, its end cap, its fill, its look, its size and width, its text; then hiding the other experience bars, one
-- setting for both, and putting it back when it was dragged.
local function barSection(side, id, key)
    return { id = id, name = ns.StatusBars.Name(side), extra = placeExtra(side < 0 and "left" or "right"), rows = {
        choice(key, L.OPT_STATUS_SHOWS, statusKinds()),
        choice(key .. "Cap", L.OPT_STATUS_CAP, { { "right", L.CAP_right }, { "left", L.CAP_left },
            { "none", L.CAP_none } }, L.OPT_STATUS_CAP_TIP),
        choice(key .. "CapShape", L.OPT_STATUS_SHAPE, { { "auto", L.SHAPE_auto }, { "bevel", L.SHAPE_bevel },
            { "round", L.SHAPE_round }, { "square", L.SHAPE_square } }),
        check(key .. "Reverse", L.OPT_STATUS_REVERSE, L.OPT_STATUS_REVERSE_TIP),
        choice(key .. "Texture", L.OPT_STATUS_TEX, {
            { "forever", L.TEX_FOREVER },
            { "striped", L.TEX_STRIPED },
            { "flat", L.TEX_FLAT },
        }),
        check(key .. "Ticks", L.STATUS_TICKS),
        slider(key .. "FontSize", L.OPT_STATUS_FONT, 1, nil, L.OPT_STATUS_FONT_TIP),
        slider(key .. "Width", L.OPT_STATUS_WIDTH, 10, widthOrAuto, L.OPT_STATUS_WIDTH_TIP),
        choice(key .. "Text", L.OPT_STATUS_TEXT, {
            { "hover", L.SHOW_HOVER },
            { "always", L.SHOW_ALWAYS },
        }),
        choice(key .. "Numbers", L.OPT_STATUS_NUMBERS, {
            { "values", L.NUM_values },
            { "percent", L.NUM_percent },
            { "both", L.NUM_both },
            { "remaining", L.NUM_remaining },
        }),
        { kind = "button", name = L.OPT_STATUS_PLACE, text = L.STATUS_PUT_BACK, tip = L.STATUS_PUT_BACK_TIP,
            click = function()
                ns.StatusBars.PutBack(side)
                EditPanel.Changed()
            end },
    } }
end

-- A colour option's list: the presets, and the colour picked, if it's none of them. Worked out each time the list
-- opens: a colour just chosen with the picker has its line at once (made once, the list had none for it until a
-- reload, and showed no colour chosen).
local function colors(key, presets)
    return function()
        local values = {}
        local current, known = ns.db and ns.db.options[key], false
        for _, hex in ipairs(presets) do
            values[#values + 1] = { hex, L["COLOR_" .. hex] or hex }
            known = known or hex == current
        end
        if type(current) == "string" and not known then
            values[#values + 1] = { current, L.COLOR_CUSTOM }
        end
        return values
    end
end

local function pickColor(key)
    return { kind = "button", name = "", text = L.COLOR_PICK, width = 150, click = function()
        ns.Border.PickColor(key, function()
            EditPanel.Changed()
        end)
    end }
end

local function styles()
    local values = {}
    for _, key in ipairs(ns.Border.STYLES) do
        values[#values + 1] = { key, L["BGS_" .. key] }
    end
    return values
end

local function foldArts()
    local values = { { "arrow", L.FOLD_ART_arrow } }
    for _, id in ipairs(ns.CARTOUCHE_ORDER) do
        values[#values + 1] = { id, L["FOLD_ART_" .. id] }
    end
    return values
end

-- The map's rings: the plain ones, then Ikar's under their themes' titles (Ikar 2026-11-16: "Group them by theme").
local function minimapRings()
    local values = { { "kali", L.RING_KALI }, { "blizzard", L.RING_BLIZZARD }, { "none", L.RING_CLASSIC } }
    for _, theme in ipairs(ns.MINIMAP_RING_THEMES) do
        values[#values + 1] = { title = L["RING_THEME_" .. theme[1]] }
        for _, id in ipairs(theme[2]) do
            values[#values + 1] = { id, L["RING_" .. id] }
        end
    end
    return values
end

-- A sound's choice: none, then each of the list in its order; one picked in the window plays as it opens.
local function sections()
    return {
        -- first, open at first: a style sets up the look at once (Ikar 2026-11-16: "having presets will help speed up
        -- the setup")
        { id = "style", name = L.EDIT_SEC_STYLE, extra = styleExtra, rows = {
            { kind = "choice", key = "preset", name = L.OPT_PRESET, tip = L.OPT_PRESET_TIP, values = presetValues,
                default = ns.PRESETS[1].id, tbl = function() return presetProxy end, onChange = pickPreset,
                redraw = false },
        } },
        { id = "plate", name = L.EDIT_SEC_PLATE, rows = {
            check("plate", L.OPT_PLATE, L.OPT_PLATE_TIP),
            slider("reach", L.OPT_REACH, 5, nil, L.OPT_REACH_TIP),
            slider("bridge", L.OPT_BRIDGE, 5, nil, L.OPT_BRIDGE_TIP),
            choice("cornerStyle", L.OPT_CORNER_STYLE, { { "round", L.CORNER_round }, { "square", L.CORNER_square },
                { "bevel", L.CORNER_bevel } }, L.OPT_CORNER_STYLE_TIP),
            slider("corner", L.OPT_CORNER, 1, nil, L.OPT_CORNER_TIP),
            slider("fillet", L.OPT_FILLET, 1, nil, L.OPT_FILLET_TIP),
            slider("maxCorners", L.OPT_MAX_CORNERS, 2, cornersLimit, L.OPT_MAX_CORNERS_TIP),
            check("footGroove", L.OPT_GROOVE, L.OPT_GROOVE_TIP),
        } },
        { id = "borders", name = L.EDIT_SEC_BORDERS, rows = {
            slider("borderSize", L.OPT_BORDER_SIZE, 5, percent, L.OPT_BORDER_SIZE_TIP),
            slider("borderAlpha", L.OPT_BORDER_ALPHA, 5, percent),
            choice("borderColor", L.OPT_BORDER_COLOR, colors("borderColor", ns.Border.COLORS), L.OPT_BORDER_COLOR_TIP),
            pickColor("borderColor"),
            choice("bgStyle", L.OPT_BG_STYLE, styles(), L.OPT_BG_STYLE_TIP),
            slider("bgIntensity", L.OPT_BG_INTENSITY, 5, percent, L.OPT_BG_INTENSITY_TIP),
            choice("bgColor", L.OPT_BG_COLOR, colors("bgColor", ns.Border.BG_COLORS)),
            pickColor("bgColor"),
            slider("bgAlpha", L.OPT_BG_ALPHA, 5, percent),
            -- Blizzard's own frames round the bars, the bags and the micro menu, the windows' section's before (the
            -- review of 2026-11-20: « Fenêtres et sacs » held it and the windows' fold alone)
            check("cleanBarArt", L.OPT_CLEAN_ART, L.OPT_CLEAN_ART_TIP),
        } },
        { id = "margins", name = L.EDIT_SEC_MARGINS, rows = {
            slider("marginBars", L.OPT_MARGIN_BARS, 1, nil, L.OPT_MARGIN_BARS_TIP),
            slider("padBars", L.OPT_PAD_BARS, 1, nil, L.OPT_PAD_BARS_TIP),
            slider("marginBags", L.OPT_MARGIN_BAGS, 1, nil, L.OPT_MARGIN_BAGS_TIP),
            slider("marginStatus", L.OPT_MARGIN_STATUS, 1, nil, L.OPT_MARGIN_STATUS_TIP),
        } },
        { id = "minimap", name = L.EDIT_SEC_MINIMAP, rows = {
            check("minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TIP),
            choice("minimapRing", L.OPT_MM_RING, minimapRings(), L.OPT_MM_RING_TIP),
            check("minimapHeader", L.OPT_MM_HEADER, L.OPT_MM_HEADER_TIP),
            slider("minimapDielScale", L.OPT_MM_DIEL_SCALE, 5, percent),
            choice("minimapZoom", L.OPT_MM_ZOOM, showModes(), L.OPT_MM_ZOOM_TIP),
            -- its pockets' free places marked, from the recesses' section gone with them (Ikar 2026-11-16: "move the
            -- minimap hint under minimap category")
            check("pocketMarks", L.OPT_POCKET_MARKS, L.OPT_POCKET_MARKS_TIP),
        } },
        { id = "windows", name = L.EDIT_SEC_WINDOWS, rows = {
            check("windowFold", L.OPT_WIN_FOLD, L.OPT_WIN_FOLD_TIP),
            choice("foldArt", L.OPT_FOLD_ART, foldArts(), L.OPT_FOLD_ART_TIP),
            slider("foldArtWidth", L.OPT_FOLD_ART_SIZE, 5, percent, L.OPT_FOLD_ART_SIZE_TIP),
            slider("foldArtLift", L.OPT_FOLD_ART_LIFT, 1, nil, L.OPT_FOLD_ART_LIFT_TIP),
        } },
        barSection(-1, "barLeft", "statusLeft"),
        barSection(1, "barRight", "statusRight"),
        { id = "info", name = L.EDIT_SEC_INFO, rows = {
            check("infoBar", L.OPT_INFO_BAR, L.OPT_INFO_BAR_TIP),
            slider("infoSize", L.OPT_INFO_SIZE, 1, nil, L.OPT_INFO_SIZE_TIP),
            slider("infoSpacing", L.OPT_INFO_SPACING, 1, nil, L.OPT_INFO_SPACING_TIP),
        } },
    }
end

-- Beside Blizzard's Edit Mode window, its top level with it, on the side away from the screen's nearer edge (Ikar
-- 2026-11-15: it opened over it); where it always opened when that window has no place.
local function place(dialog)
    local manager = EditModeManagerFrame
    local left, top = manager and manager:IsShown() and manager:GetLeft(), manager and manager:GetTop()
    dialog:ClearAllPoints()
    if not (left and top) then
        dialog:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
    elseif left + manager:GetWidth() / 2 > UIParent:GetWidth() / 2 then
        dialog:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 10, top)
    else
        dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + manager:GetWidth() + 10, top)
    end
end

local function onKeyDown(_, key)
    if key == "ESCAPE" then
        ns.EditFrame.Deselect()
        return true
    end
    return false
end

-- What the dialog lists, for the tests.
EditPanel.Sections = sections

-- The window's « Par défaut » asks first, as the game's own settings do (Ikar 2026-11-16: "The Par defaut in the menu
-- should warn the user that he will lose the changes"); a section's own asks nothing. An answer given once a fight has
-- greyed the window does nothing.
local function askDefaults(h)
    StaticPopupDialogs.KALIHUD_EDIT_DEFAULTS = StaticPopupDialogs.KALIHUD_EDIT_DEFAULTS or {
        text = L.EDIT_DEFAULTS_ASK,
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = ns.Guarded(function(_, data)
            if not ns.InCombat() then
                applyOnce(data.Defaults, data)
            end
        end),
    }
    StaticPopup_Show("KALIHUD_EDIT_DEFAULTS", nil, nil, h)
end

local handle = ns.Dialog.New({
    name = "KaLiHUDEditModeDialog",
    title = ns.TITLE,
    sections = sections,
    open = "style",
    options = function()
        return ns.db.options
    end,
    defaults = ns.DB.DEFAULTS,
    ranges = ns.DB.RANGES,
    apply = apply,
    combatLock = true,
    onKeyDown = onKeyDown,
    onClose = function()
        ns.EditFrame.Deselect()
    end,
    place = place,
    -- Each section's own « Annuler » and « Par défaut », on one line, asking nothing (Ikar 2026-11-16).
    sectionButtons = {
        revert = { text = ns.G("CANCEL", "Annuler"), tip = L.EDIT_SECTION_REVERT_TIP },
        defaults = { text = ns.G("DEFAULTS", "Par défaut"), tip = L.EDIT_SECTION_DEFAULTS_TIP },
    },
    batch = function(run)
        applyOnce(run)
    end,
    buttons = {
        { key = "Revert", wide = true, text = ns.G("HUD_EDIT_MODE_REVERT_CHANGES", "Annuler les modifications"),
            tip = L.EDIT_REVERT_TIP,
            click = function(h)
                applyOnce(h.Revert, h)
            end,
            enabled = function(h)
                return h:HasChanges()
            end },
        { key = "Divider", divider = true },
        { key = "Defaults", wide = true, text = ns.G("DEFAULTS", "Par défaut"),
            tip = L.EDIT_DEFAULTS_TIP,
            click = askDefaults },
    },
})

function EditPanel.Snapshot()
    if ns.db then
        handle:Snapshot()
    end
end

function EditPanel.Revert()
    applyOnce(handle.Revert, handle)
end

-- section: the one to show open, else the one open last.
function EditPanel.Open(section)
    if ns.db then
        if section then
            handle.openSection = section
        end
        handle:Open()
    end
end

function EditPanel.Close()
    handle:Close()
end

function EditPanel.IsShown()
    return handle:IsShown()
end

function EditPanel.Changed()
    handle:Changed()
end