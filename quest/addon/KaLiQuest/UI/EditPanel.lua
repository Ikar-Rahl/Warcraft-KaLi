-- The tracker's dialog in Edit Mode, when its frame (UI/EditFrame.lua) is picked: one dialog for all the tracker's
-- size and look, Ikar's choice on 2026-11-13 ("One dialog, FlareUI's way"), the only place they're set since the same
-- day ("comme dans flare": the options page has a button to Edit Mode instead). Made with the shared settings window
-- (Shared/Dialog.lua), from the pieces Blizzard's Edit Mode dialog is made of; its own frame, so nothing is written
-- into Blizzard's.
--
-- Changes apply and stay at once: Edit Mode's Save button lights only for Blizzard's own changes, and its exit always
-- undoes those it holds, so tying these to it would lose them. "Annuler les modifications" puts back the settings and
-- places as they were on entering Edit Mode, or at its last save.
local _, ns = ...
local L = ns.L

local EditPanel = {}
ns.EditPanel = EditPanel

local function percent(value)
    return string.format("%d %%", value)
end

local function hostHeight()
    return math.floor(ns.Host.Height() + 0.5)
end

local function blizzardBackground()
    local manager = ObjectiveTrackerManager
    local alpha = manager and type(manager.backgroundAlpha) == "number" and manager.backgroundAlpha or 0
    return math.floor(alpha * 100 + 0.5)
end

local function slider(key, name, step, format, tip, current)
    return { kind = "slider", key = key, name = name, step = step, format = format, tip = tip, current = current }
end

local function check(key, name, tip, onChange)
    return { kind = "check", key = key, name = name, tip = tip, default = true, onChange = onChange }
end

local function markers()
    return ns.db.options.markers
end

-- The sections and their rows, under the names the options page gave them, but for the opacities' shorter ones,
-- which fit Blizzard's label in two lines. markers: the row's value is in the markers' own table.
local function sections()
    local list = {
        { id = "frame", name = L.EDIT_SECTION_FRAME, rows = {
            slider("zoom", L.OPTION_ZOOM, 5, percent, L.OPTION_ZOOM_TIP),
            slider("width", L.OPTION_WIDTH, 2),
            slider("height", L.OPTION_HEIGHT, 10, nil, nil, hostHeight),
            slider("bgOpacity", L.OPTION_BG_OPACITY, 5, percent, L.OPTION_BG_OPACITY_TIP, blizzardBackground),
        } },
        { id = "opacity", name = ns.G("OPACITY", "Opacité"), rows = {
            slider("opacity", L.EDIT_OPACITY, 5, percent, L.EDIT_OPACITY_TIP),
            slider("opacityCombat", L.EDIT_OPACITY_COMBAT, 5, percent, L.EDIT_OPACITY_TIP),
            slider("blockRest", L.OPTION_BLOCK_REST, 5, percent),
            slider("blockCombat", L.OPTION_BLOCK_COMBAT, 5, percent),
            slider("blockHover", L.OPTION_BLOCK_HOVER, 5, percent),
        } },
        { id = "look", name = L.OPTIONS_LOOK, rows = {
            slider("saturation", L.OPTION_SATURATION, 5, percent),
            { kind = "choice", key = "markerStyle", name = L.OPTION_MARKERS, tip = L.OPTION_MARKERS_TIP, default = "icons",
                values = { { "icons", L.MARKERS_ICONS }, { "text", L.MARKERS_TEXT }, { "none", L.MARKERS_NONE } } },
            check("progressFlash", L.GLOW, L.OPTION_GLOW_TIP),
            check("areaHighlight", L.AREA_HIGHLIGHT, L.OPTION_AREA_TIP, function()
                ns.Area.Apply()
            end),
            check("shareOnHover", L.OPTION_SHARE_HOVER, L.OPTION_SHARE_HOVER_TIP),
        } },
        { id = "markers", name = L.OPTIONS_MARKERS, rows = {} },
        { id = "advanced", name = L.OPTIONS_ADVANCED, rows = {
            slider("titleGap", L.OPTION_TITLE_GAP, 1),
            slider("groupIndent", L.OPTION_GROUP_INDENT, 1),
            slider("questIndent", L.OPTION_QUEST_INDENT, 1),
            slider("groupGap", L.OPTION_GROUP_GAP, 1),
            slider("barGap", L.OPTION_BAR_GAP, 1),
            slider("markerSize", L.OPTION_MARKER_SIZE, 1),
        } },
    }
    for _, kind in ipairs(ns.DB.MARKERS) do
        local row = check(kind, ns.Options.MarkerName(kind), L.OPTION_MARKER_TIP)
        row.markers, row.tbl = true, markers
        table.insert(list[4].rows, row)
    end
    return list
end

local function samePositions(a, b)
    for key, p in pairs(a) do
        local q = b[key]
        if not (q and q.point == p.point and q.x == p.x and q.y == p.y) then
            return false
        end
    end
    for key in pairs(b) do
        if not a[key] then
            return false
        end
    end
    return true
end

-- Escape closes it, as Blizzard's; the arrows move the tracker, 10 at a time with Shift. Any other key goes on to the
-- game, and in a fight all do.
local function onKeyDown(_, key)
    local step = IsShiftKeyDown() and ns.EditFrame.BIG_STEP or ns.EditFrame.SMALL_STEP
    local moves = { LEFT = { -step, 0 }, RIGHT = { step, 0 }, UP = { 0, step }, DOWN = { 0, -step } }
    if key == "ESCAPE" then
        ns.EditFrame.Deselect()
        return true
    elseif moves[key] then
        ns.EditFrame.Nudge(moves[key][1], moves[key][2])
        return true
    end
    return false
end

-- Beside the tracker, on the side away from the screen's nearer edge, as Blizzard's dialog opens by its frame.
local function place(dialog)
    local holder = ns.EditFrame.Holder()
    local left, top, width = holder:GetLeft(), holder:GetTop(), holder:GetWidth()
    dialog:ClearAllPoints()
    if not (left and top) then
        dialog:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 200)
    elseif left + width / 2 > UIParent:GetWidth() / 2 then
        dialog:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 10, top)
    else
        dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + width + 10, top)
    end
end

local handle
handle = ns.Dialog.New({
    name = "KaLiQuestEditModeDialog",
    title = ns.TITLE,
    sections = sections,
    open = "frame",
    options = function()
        return ns.db.options
    end,
    defaults = ns.DB.DEFAULTS,
    ranges = ns.DB.RANGES,
    apply = function()
        ns.RequestRefresh()
    end,
    combatLock = true,
    onKeyDown = onKeyDown,
    onClose = function()
        ns.EditFrame.Deselect()
    end,
    place = place,
    -- The places, each layout's, go back with the settings.
    extra = {
        take = function()
            return ns.EditFrame.Positions()
        end,
        same = function(held)
            return samePositions(held, ns.db.editMode.positions)
        end,
        put = function(held)
            ns.EditFrame.SetPositions(held)
            ns.RequestRefresh()
        end,
    },
    buttons = {
        { key = "Revert", text = ns.G("HUD_EDIT_MODE_REVERT_CHANGES", "Annuler les modifications"), tip = L.EDIT_REVERT_TIP,
            click = function(h)
                h:Revert()
            end,
            enabled = function(h)
                return h:HasChanges()
            end },
        { key = "Divider", divider = true },
        -- Only once it was moved.
        { key = "ResetPosition", wide = true, text = ns.G("HUD_EDIT_MODE_RESET_POSITION", "Revenir à la position par défaut"),
            tip = L.EDIT_RESET_POSITION_TIP,
            click = function()
                ns.EditFrame.ResetPosition()
            end,
            enabled = function()
                return ns.EditFrame.HasPosition()
            end },
        { key = "Defaults", wide = true, text = ns.G("DEFAULTS", "Par défaut"), tip = L.EDIT_DEFAULTS_TIP,
            click = function(h)
                h:Defaults()
                ns.RequestRefresh()
            end },
    },
})
EditPanel.handle = handle

-- Settings and places as they are, for "Annuler les modifications".
function EditPanel.Snapshot()
    if ns.db then
        handle:Snapshot()
    end
end

function EditPanel.HasChanges()
    return ns.db ~= nil and handle:HasChanges()
end

function EditPanel.Revert()
    handle:Revert()
end

-- Every row back to its default. Not the place, which has its own button.
function EditPanel.Defaults()
    handle:Defaults()
    ns.RequestRefresh()
end

function EditPanel.Layout()
    handle:Layout()
end

function EditPanel.UpdateButtons()
    handle:UpdateButtons()
end

function EditPanel.Open()
    if ns.db then
        handle:Open()
    end
end

function EditPanel.Close()
    handle:Close()
end

function EditPanel.IsShown()
    return handle:IsShown()
end

-- After a change from elsewhere (a drag, the arrows, another layout, a save), the rows and buttons say so.
function EditPanel.Changed()
    handle:Changed()
end
