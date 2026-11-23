-- The folders' and macros' icon library (Ikar 2026-11-15: "an icon library to select the folder icon"; the game's own, the macros'
-- and gear sets', holds only the spells' and items' big squares): Data/Icons.lua's icons, Blizzard's atlases drawn to
-- be read small, next to the folder's button under its name. Every one at a glance, by category (Ikar 2026-11-16: "can
-- we see them all in one panel? Even big? By category without switching?"): each category's name over its icons, the
-- categories down columns in the library's order, as many columns as the screen needs; each icon named on hover. A
-- click gives the folder that icon at once and shuts the picker (Ikar 2026-11-17: "when an icon is selected, close the
-- icon page"); the icon it wears sits on a lighter square. An icon the game lacks takes no place, a category left with
-- none no heading. Escape or the close button shuts it unchanged. A plain window (Ikar 2026-11-16: "make the background neutral, the whole window is not supposed to be fancy,
-- simple, functional and clear"): no HUD border nor material, a dark grey ground in a grey line.
local _, ns = ...

local Picker = {}
ns.IconPicker = Picker

local Buttons = ns.HubButtons
local L = ns.L
local max, min = math.max, math.min

local NAME = "KaLiHUDIconPicker"
-- Icons a line in a category; a cell and the icon in it (units); inside the edge round it all; between the picker and
-- the button.
local PER_LINE, CELL, ICON, PAD, GAP = 8, 28, 22, 8, 3
-- A category's name over its icons, the space under it; between two categories one over the other; between columns.
local HEAD, HEAD_GAP, SECTION_GAP, COLUMN_GAP = 14, 3, 10, 16
-- Columns at the least; then one more while the picker would take more of the screen's height than this.
local COLUMNS, SCREEN_SHARE = 3, 0.85
-- The categories' names and the title: the HUD's bronze, not the game's gold (Ikar 2026-11-16: "the yellow is terribly
-- yellow. Use a more tuned down color").
Picker.LABEL = { 0.8, 0.7, 0.52 }
local LABEL = Picker.LABEL
-- The ground and its edge, one pixel wide; a cell under the pointer lightened, the icon worn on a lighter square.
Picker.GROUND, Picker.EDGE = { 0.07, 0.07, 0.07, 0.95 }, { 0.32, 0.32, 0.32, 1 }
local GROUND, EDGE = Picker.GROUND, Picker.EDGE
local HOVER, WORN = { 1, 1, 1, 0.1 }, { 1, 1, 1, 0.18 }
local WHITE = { 1, 1, 1 }

local frame
-- What the open picker is for: the folder, and who to tell of a pick.
local key, pick

-- A name the game holds: a global's, or a dotted path into one of its tables ("LOCALIZED_CLASS_NAMES_MALE.WARRIOR").
local function gameWord(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return type(value) == "string" and value ~= "" and value or nil
end

-- An icon of the library's name in the player's language: the game's own word when it has it, else ours, in each
-- language's file (Locale/<language>.lua's ICON_NAMES, Ikar 2026-11-21: "About icons, yes. As much as possible."); for
-- a game word this client lacks, this build's in French or English (Data/Icons.lua's fr and en).
function Picker.Name(icon)
    local ours = type(L.ICON_NAMES) == "table" and L.ICON_NAMES[icon[1]]
    return icon.game and gameWord(icon.game) or ours or ns.LOCALE == "frFR" and icon.fr or icon.en or icon[1]
end

-- The icon the folder wears on its lighter square; nil: none.
local function mark(atlas)
    local cell
    for _, c in ipairs(frame.cells) do
        if c.atlas == atlas then
            cell = c
            break
        end
    end
    frame.current = cell
    if cell then
        frame.Worn:ClearAllPoints()
        frame.Worn:SetPoint("TOPLEFT", cell, "TOPLEFT")
        frame.Worn:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT")
    end
    frame.Worn:SetShown(cell ~= nil)
end

-- The icon picked, then the picker shut (Ikar 2026-11-17: "when an icon is selected, close the icon page").
local function onClick(cell)
    mark(cell.atlas)
    local picked = pick
    frame:Hide()
    if picked then
        ns.SafeCall(picked, cell.atlas)
    end
end

-- Its name on hover.
local function onEnter(cell)
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:SetText(Picker.Name(cell.icon), WHITE[1], WHITE[2], WHITE[3])
    GameTooltip:Show()
end

local function onLeave(cell)
    if GameTooltip:IsOwned(cell) then
        GameTooltip:Hide()
    end
end

-- A plain window's look, the picker's and the macro editor's: the dark grey ground in its grey line, one pixel wide.
function Picker.Plain(window)
    window.Ground = window:CreateTexture(nil, "BACKGROUND")
    window.Ground:SetAllPoints()
    window.Ground:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], GROUND[4])
    window.edges = {}
    -- each side: its two corners, and whether it runs across
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local line = window:CreateTexture(nil, "BORDER")
        line:SetColorTexture(EDGE[1], EDGE[2], EDGE[3], EDGE[4])
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] then
            PixelUtil.SetHeight(line, 1, 1)
        else
            PixelUtil.SetWidth(line, 1, 1)
        end
        window.edges[#window.edges + 1] = line
    end
end

local function build()
    frame = CreateFrame("Frame", NAME, UIParent)
    -- over the macro editor (Ikar 2026-11-16: from it the picker "does not open"): the editor, a toplevel window of
    -- the DIALOG layer, rises over anything of that layer when clicked, the picker it opened under it
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    -- its scripts and its cells' under the handlers' guard (ns.Guarded), the cells' made once for all of them
    frame:SetScript("OnHide", ns.Guarded(function()
        key, pick = nil, nil
        local owner = GameTooltip:GetOwner()
        if owner and owner.icon and owner:GetParent() == frame.Grid then
            GameTooltip:Hide()
        end
    end))
    local click, enter, leave = ns.Guarded(onClick), ns.Guarded(onEnter), ns.Guarded(onLeave)
    tinsert(UISpecialFrames, NAME)
    Picker.Plain(frame)
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(false)
    frame.Title:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
    frame.Hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Hint:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -3)
    frame.Hint:SetText(ns.G("MACRO_POPUP_CHOOSE_ICON", "Sélectionnez une icône :"))
    frame.Grid = CreateFrame("Frame", nil, frame)
    frame.Grid:SetFrameLevel(frame:GetFrameLevel() + 3)
    frame.Worn = frame.Grid:CreateTexture(nil, "BACKGROUND")
    frame.Worn:SetColorTexture(WORN[1], WORN[2], WORN[3], WORN[4])
    frame.Worn:Hide()
    -- every icon the game has, in the library's order, each its category's nth; the categories that have one, each
    -- with its heading
    frame.cells, frame.sections = {}, {}
    local byGroup = {}
    for _, group in ipairs(ns.ICON_GROUPS) do
        byGroup[group] = { group = group, cells = {} }
    end
    for _, icon in ipairs(ns.ICONS) do
        local c = CreateFrame("Button", nil, frame.Grid)
        c.Icon = c:CreateTexture(nil, "ARTWORK")
        local section = byGroup[icon.group]
        if section and Buttons.FitAtlas(c.Icon, icon[1], ICON) then
            c.atlas, c.icon, c.group = icon[1], icon, icon.group
            c:SetSize(CELL, CELL)
            c.Icon:SetPoint("CENTER", 0, 0)
            if icon[6] then
                c.Icon:SetVertexColor(unpack(ns.Folders.TINT))
            end
            local hover = c:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
            c:RegisterForClicks("LeftButtonUp")
            c:SetScript("OnClick", click)
            c:SetScript("OnEnter", enter)
            c:SetScript("OnLeave", leave)
            section.cells[#section.cells + 1] = c
            frame.cells[#frame.cells + 1] = c
        else
            c:Hide()
        end
    end
    for _, group in ipairs(ns.ICON_GROUPS) do
        local section = byGroup[group]
        if #section.cells > 0 then
            section.Head = frame.Grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            section.Head:SetJustifyH("LEFT")
            section.Head:SetWordWrap(false)
            section.Head:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
            section.Head:SetText(L["ICON_GROUP_" .. group])
            section.height = HEAD + HEAD_GAP + math.ceil(#section.cells / PER_LINE) * CELL
            frame.sections[#frame.sections + 1] = section
        end
    end
    frame.Close = ns.CloseButton(frame, 0, 0)
    frame.Close:SetSize(22, 22)
end

-- The sections split in their order into at most k columns, top to bottom then left to right, the tallest column as
-- short as it can be: each section's column, and that column's height.
local function split(k)
    local sections = frame.sections
    local function pack(limit)
        local column, used, tallest = 1, 0, 0
        for _, s in ipairs(sections) do
            if used > 0 and used + SECTION_GAP + s.height > limit then
                column, used = column + 1, 0
            end
            used = used + (used > 0 and SECTION_GAP or 0) + s.height
            s.column = column
            tallest = max(tallest, used)
        end
        return column, tallest
    end
    -- the limits worth trying: the heights of runs of sections, from the shortest
    local limits = {}
    for i = 1, #sections do
        local run = 0
        for j = i, #sections do
            run = run + (j > i and SECTION_GAP or 0) + sections[j].height
            limits[#limits + 1] = run
        end
    end
    table.sort(limits)
    for _, limit in ipairs(limits) do
        local columns, tallest = pack(limit)
        if columns <= k then
            return columns, tallest
        end
    end
    return pack(math.huge)
end

-- Next to the folder's button, towards the middle of the screen, its side flush with the button's; mid-screen without.
-- beside: a window it opens from (the macro editor), it stands by its side where there's room, their tops level.
local function place(owner, beside)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local pw, ph = frame:GetWidth(), frame:GetHeight()
    local x, y = (W - pw) / 2, (H - ph) / 2
    local left, top = beside and beside:IsVisible() and beside:GetLeft(), beside and beside:IsVisible() and beside:GetTop()
    if left and top then
        local k = beside:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local l, r, t = left * k, beside:GetRight() * k, top * k
        x = W - r >= pw + GAP and r + GAP or l - GAP - pw
        y = t - ph
    elseif owner and owner:IsVisible() and owner.ux then
        local bw, bh = owner:GetWidth(), owner:GetHeight()
        x = owner.ux > W / 2 and owner.ux + bw / 2 - pw or owner.ux - bw / 2
        y = owner.uy < H / 2 and owner.uy + bh / 2 + GAP or owner.uy - bh / 2 - GAP - ph
    end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", max(0, min(W - pw, x)), max(0, min(H - ph, y)))
end

-- Every category laid out: COLUMNS columns, one more while the picker would be taller than its share of the screen.
local function layout(top, edge)
    local limit = UIParent:GetHeight() * SCREEN_SHARE - top - edge
    local columns, tallest = split(COLUMNS)
    local k = COLUMNS
    while tallest > limit and k < #frame.sections do
        k = k + 1
        columns, tallest = split(k)
    end
    local colW = PER_LINE * CELL
    local y = {}
    for _, s in ipairs(frame.sections) do
        local x = (s.column - 1) * (colW + COLUMN_GAP)
        local sy = y[s.column] or 0
        s.Head:ClearAllPoints()
        s.Head:SetPoint("TOPLEFT", frame.Grid, "TOPLEFT", x, -sy)
        s.Head:SetWidth(colW)
        local gy = sy + HEAD + HEAD_GAP
        for n, c in ipairs(s.cells) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", frame.Grid, "TOPLEFT", x + ((n - 1) % PER_LINE) * CELL,
                -(gy + math.floor((n - 1) / PER_LINE) * CELL))
        end
        y[s.column] = sy + s.height + SECTION_GAP
    end
    frame.columns = columns
    return columns * colW + max(0, columns - 1) * COLUMN_GAP, tallest
end

-- The library for `id` (a folder, a macro, or the macro editor), next to its button `owner` (beside the window
-- `beside` when given), under `title`, `icon` on its lighter square; onPick(atlas) for each icon clicked.
function Picker.Open(id, owner, title, icon, onPick, beside)
    if not frame then
        build()
    end
    key, pick = id, onPick
    local inset = 1
    local edge = inset + PAD
    frame.Title:SetText(title)
    local top = edge + frame.Title:GetStringHeight() + 3 + frame.Hint:GetStringHeight() + PAD
    local gridW, gridH = layout(top, edge)
    local width = 2 * edge + gridW
    frame.Title:ClearAllPoints()
    frame.Title:SetPoint("TOPLEFT", edge, -edge)
    frame.Title:SetWidth(width - 2 * edge - 22)
    frame.Close:SetPoint("TOPRIGHT", 2 - inset, 2 - inset)
    frame.Grid:ClearAllPoints()
    frame.Grid:SetPoint("TOPLEFT", edge, -top)
    frame.Grid:SetSize(gridW, gridH)
    frame:SetSize(width, top + gridH + edge)
    mark(icon)
    place(owner, beside)
    frame:Show()
    frame:Raise()
end

-- What it's open for, for the tests; nil shut.
function Picker.Current()
    return frame and frame:IsShown() and key or nil
end

-- Shut; given a folder, only if open for it.
function Picker.Close(id)
    if frame and frame:IsShown() and (id == nil or id == key) then
        frame:Hide()
    end
end
