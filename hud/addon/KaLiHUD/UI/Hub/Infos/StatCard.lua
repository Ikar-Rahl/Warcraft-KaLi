-- The attributes' card (Ikar 2026-11-19: "make a custom 3 panel, left the input, center the value, description, tips,
-- and right effects", then of three sketches "One card, but enhance it", and of the cards "Go with card 1"): on
-- hover, in place of the game's tooltip, one plate in the HUD's own border and floor, as a folder's list. Its head the
-- name and the value, large; under it up to three columns, where the value comes from, what there is to know of it,
-- what it gives, a column with nothing to say left out; its foot the hints. It draws what it's handed
-- (UI/Hub/Infos/Stats.lua works it out) and takes no click: it stands over nothing the pointer is on.
-- A left click on an attribute keeps its card open (Ikar 2026-11-19: "do 10, 1, 2 […]", a card that stays open and
-- follows; of how it shuts, "just keep the cross, and escape should close it too"): drawn the same, over the game's
-- windows and the folders' lists and under its tooltips, until its cross, Escape or a click on the attribute again,
-- as one of the game's own windows; a drag moves it. Several at once, one a value (Ikar 2026-11-23: "when clicking
-- againt on a stat, it shoudl close the popup, and when clickinkg, it should show it on top of the stat menu. Also add
-- a possibility to add multiple (stacking bottom uo, left to right, then right to left"): each opens at the first free
-- place over the list it was clicked in (place). On one kept open, a source's row shows the game's own tooltip of what
-- it names, or how the card works its figure out (Ikar 2026-11-23: "On hover, we shoudl show the item/spell/talent
-- tooltip").
local _, ns = ...

local Infos = ns.Infos
local max = math.max

local Card = {}
ns.StatCard = Card

local GOLD, GREY, WHITE = Infos.GOLD, Infos.GREY, Infos.WHITE
-- The columns' titles and a group's name: the plate's bronze, lighter.
local LABEL = { 0.79, 0.64, 0.35 }
Card.LABEL = LABEL
-- From the plate's metal to what it holds, between columns, between a row and the next, a group's rows in from it;
-- each column's width, the room a row keeps for its figure; in the head, from the name to what follows it.
local PAD, GAP, ROW, INDENT, FIGURE, HEAD_GAP = 10, 18, 2, 10, 70, 16
local WIDTHS = { sources = 250, about = 220, effects = 220 }
-- The sources' column and its figures' room as they are, and what both take more when a row holds two figures (what
-- would be beside what is: Stats.lua's data.wide).
local SOURCES, FIGURES, WIDER = WIDTHS.sources, FIGURE, 80
-- A table's column a state (the regenerations': Stats.lua's RegenTable, data.columns), and what it takes more beside
-- what would be.
local CELL, CELL_WIDER = 74, 40
local ORDER = { "sources", "about", "effects" }
-- Where the value comes from and what it gives, each a soft light along the card's border beside its column, fading
-- in: green the first, blue the second (Ikar 2026-11-20: "a border color glow for input and output ? like green for
-- inputs, purple for outputs ? A hint, not too strong", then "switch purple to blue"). Its width, and each one's
-- colour at the border.
local GLOW_WIDTH = 36
local GLOWS = { sources = { 0.30, 0.85, 0.40, 0.22 }, effects = { 0.30, 0.55, 1.00, 0.22 } }
-- Between two of the foot's hints on its one line.
local BETWEEN = "   ·   "

-- The card being drawn: the hover's, or one of those kept open, by their value's key (`spare` those shut, a frame
-- never going, the first made taken first; `latest` the one opened last).
local frame
local hover
local pins, spare, made, latest = {}, {}, 0, nil
local PINNED = "KaLiHUDStatCardPinned"
-- Between two cards kept open, and from what they stack over.
local STACK_GAP = 4

local function build(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:Hide()
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    ns.Border.Attach(f, { level = 1 })
    -- its floor the info bar's carved channel's, as a folder's list's (UI/Hub/Folders.lua)
    local c = ns.Plate.CHANNEL
    f.Floor = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.Floor:SetColorTexture(c[1], c[2], c[3], c[4])
    f.Floor:SetAllPoints(f.KaLiBorder.Bg)
    f.texts, f.rules, f.used, f.usedRules = {}, {}, 0, 0
    f.tips, f.usedTips = {}, 0
    f.Glows = {}
    for key, c in pairs(GLOWS) do
        local g = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        g:SetColorTexture(1, 1, 1, 1)
        g:SetBlendMode("ADD")
        local lit, clear = CreateColor(c[1], c[2], c[3], c[4]), CreateColor(c[1], c[2], c[3], 0)
        if key == "sources" then
            g:SetGradient("HORIZONTAL", lit, clear)
        else
            g:SetGradient("HORIZONTAL", clear, lit)
        end
        g:Hide()
        f.Glows[key] = g
    end
    return f
end

-- A card kept open: the game's own cross on its corner, shut by it or by Escape (the game hides the windows of
-- UISpecialFrames), which tells whoever keeps it (OnUnpin, with its value's key); moved by a drag. One strata over the
-- folders' lists (HIGH, UI/Hub/Folders.lua), the one it was opened from among them, and under the tooltips.
local function buildPinned()
    made = made + 1
    local f = build(made == 1 and PINNED or (PINNED .. made))
    f.index = made
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", ns.Guarded(function(self)
        self:StartMoving()
    end))
    f:SetScript("OnDragStop", ns.Guarded(function(self)
        self:StopMovingOrSizing()
        -- (where it stands now, for the next one's place)
        local left, bottom = ns.Plain(self:GetLeft()), ns.Plain(self:GetBottom())
        if left and bottom then
            self.at = { left, bottom }
        end
    end))
    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetSize(22, 22)
    f.Close:SetPoint("CENTER", f, "TOPRIGHT", -3, -3)
    f.Close:SetScript("OnClick", ns.Guarded(function()
        f:Hide()
    end))
    -- (hidden itself: the game also tells a frame it hides when the whole interface does, Alt+Z, and the card is
    -- there again after it)
    f:SetScript("OnHide", ns.Guarded(function()
        if f:IsShown() then
            return
        end
        local key = f.key
        if key ~= nil and pins[key] == f then
            pins[key] = nil
            spare[#spare + 1] = f
        end
        f.key = nil
        if Card.OnUnpin and key ~= nil then
            Card.OnUnpin(key)
        end
    end))
    tinsert(UISpecialFrames, f:GetName())
    return f
end

-- A frame's edges in UIParent's units, left, bottom, right, top; nil while it has none.
local function edges(r)
    local own, theirs = ns.Plain(r:GetEffectiveScale()), ns.Plain(UIParent:GetEffectiveScale())
    local l, b, w, h = ns.Plain(r:GetLeft()), ns.Plain(r:GetBottom()), ns.Plain(r:GetWidth()), ns.Plain(r:GetHeight())
    if not (l and b and w and h and own and theirs and theirs > 0) then
        return nil
    end
    local s = own / theirs
    return { l * s, b * s, (l + w) * s, (b + h) * s }
end

-- Where a card kept open opens: over the folder's list it was clicked in, else over its element; the first place up
-- from there that neither that list nor another card kept open covers, then the column right of those, then left of
-- them, as far as the screen goes; over the list, as the first, where none is left. Held there, not following the
-- owner (a folder's list shuts, its buttons are laid out again); one shut leaves its place, the others staying put.
-- Each card's place is the one it was given or dragged to (`at`, its bottom left in UIParent's units).
local function boxOf(card)
    if card.at then
        return { card.at[1], card.at[2], card.at[1] + card:GetWidth(), card.at[2] + card:GetHeight() }
    end
    return edges(card)
end
local function place(f, owner)
    local under = owner and owner ~= UIParent and (ns.Folders.ListOf and ns.Folders.ListOf(owner) or owner) or nil
    local w, h = f:GetWidth(), f:GetHeight()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    -- (no element to stand over: from the middle of the screen, a third of the way up)
    local from = under and edges(under) or { (sw - w) / 2, sh / 3, (sw - w) / 2, sh / 3 }
    f:ClearAllPoints()
    local taken = { from }
    for _, other in pairs(pins) do
        local box = other ~= f and other:IsShown() and boxOf(other)
        if box then
            taken[#taken + 1] = box
        end
    end
    local x0 = math.max(0, math.min(from[1], sw - w))
    local xs, rights, lefts, ys = { x0 }, {}, {}, { from[4] + STACK_GAP }
    for _, box in ipairs(taken) do
        if box[3] + STACK_GAP > x0 then
            rights[#rights + 1] = box[3] + STACK_GAP
        end
        if box[1] - STACK_GAP - w < x0 then
            lefts[#lefts + 1] = box[1] - STACK_GAP - w
        end
        ys[#ys + 1] = box[2]
        ys[#ys + 1] = box[4] + STACK_GAP
    end
    table.sort(rights)
    table.sort(lefts, function(a, b) return a > b end)
    table.sort(ys)
    for _, x in ipairs(rights) do
        xs[#xs + 1] = x
    end
    for _, x in ipairs(lefts) do
        xs[#xs + 1] = x
    end
    local function free(x, y)
        if x < 0 or y < 0 or x + w > sw or y + h > sh then
            return false
        end
        for _, box in ipairs(taken) do
            if x < box[3] and x + w > box[1] and y < box[4] and y + h > box[2] then
                return false
            end
        end
        return true
    end
    for _, x in ipairs(xs) do
        for _, y in ipairs(ys) do
            if free(x, y) then
                f.at = { x, y }
                f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                return
            end
        end
    end
    f.at = { x0, math.max(0, math.min(from[4] + STACK_GAP, sh - h)) }
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", f.at[1], f.at[2])
end
-- (for the tests: where the card of `key` kept open stands, left, bottom, right, top)
function Card.BoxOf(key)
    local f = pins[key]
    local box = f and f:IsShown() and boxOf(f)
    if box then
        return unpack(box)
    end
end

-- The next text of the card's, in one of the game's fonts: kept from one hover to the next, a frame's texts never
-- going.
local function text(font, value, color, width)
    local f = frame
    f.used = f.used + 1
    local t = f.texts[f.used]
    if not t then
        t = f:CreateFontString(nil, "OVERLAY", font)
        f.texts[f.used] = t
    end
    t:SetFontObject(font)
    t:ClearAllPoints()
    t:SetJustifyH("LEFT")
    t:SetWordWrap(width ~= nil)
    t:SetWidth(width or 0)
    t:SetText(value or "")
    color = color or WHITE
    t:SetTextColor(color[1], color[2], color[3])
    t:Show()
    return t
end

-- A thin line across: under the head, over the foot, between a value's base and its changes, between columns.
local function rule(x, y, width, height)
    local f = frame
    f.usedRules = f.usedRules + 1
    local r = f.rules[f.usedRules]
    if not r then
        r = f:CreateTexture(nil, "ARTWORK")
        f.rules[f.usedRules] = r
    end
    r:SetColorTexture(LABEL[1], LABEL[2], LABEL[3], 0.35)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    r:SetSize(width, height)
    r:Show()
end

local function heightOf(t)
    return max(t:GetStringHeight() or 0, 10)
end

-- A column's title, then its lines from y down; the y under its last.
local function title(label, x, y)
    local t = text("GameFontNormalSmall", label, LABEL)
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    return y - heightOf(t) - 6
end

-- What a source's row names, on a card kept open, which the pointer can reach: the row lit under it, and beside the
-- card, on the side with more room, the game's own tooltip of it (an item worn, a buff, a talent, a spell, the first
-- the game can show of those the row holds) or its name, then how the card works its figure out (`lines`). A tooltip
-- shown from here is no item or talent to try on the card (Stats.lua's try: kaliCardTip).
local function rowTip(self)
    local t, f = self.tip, self:GetParent()
    self.Light:Show()
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local left, right, top = ns.Plain(f:GetLeft()) or 0, ns.Plain(f:GetRight()) or 0, ns.Plain(f:GetTop()) or 0
    local dy = (ns.Plain(self:GetTop()) or top) - top
    if UIParent:GetWidth() - right >= left then
        GameTooltip:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, dy)
    else
        GameTooltip:SetPoint("TOPRIGHT", f, "TOPLEFT", -2, dy)
    end
    local shown = false
    local function try(method, ...)
        if not shown and type(GameTooltip[method]) == "function" then
            local ok = pcall(GameTooltip[method], GameTooltip, ...)
            shown = ok and (GameTooltip:NumLines() or 0) > 0
        end
    end
    if t.slot then
        try("SetInventoryItem", "player", t.slot)
    end
    if t.aura then
        try("SetUnitAuraByAuraInstanceID", "player", t.aura)
    end
    if t.trait then
        try("SetTraitEntry", t.trait, t.rank)
    end
    if t.spell then
        try("SetSpellByID", t.spell)
    end
    if not shown then
        GameTooltip:SetText(self.name or "", GOLD[1], GOLD[2], GOLD[3])
    end
    for _, line in ipairs(t.lines or {}) do
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(line, GOLD[1], GOLD[2], GOLD[3], true)
    end
    GameTooltip:Show()
end
local function tipFor(row, x, y, width, height)
    local f = frame
    f.usedTips = f.usedTips + 1
    local r = f.tips[f.usedTips]
    if not r then
        r = CreateFrame("Frame", nil, f)
        r:EnableMouse(true)
        r.kaliCardTip = true
        r.Light = r:CreateTexture(nil, "BACKGROUND")
        r.Light:SetAllPoints()
        r.Light:SetColorTexture(1, 1, 1, 0.08)
        r.Light:Hide()
        r:SetScript("OnEnter", ns.Guarded(rowTip))
        r:SetScript("OnLeave", ns.Guarded(function(self)
            self.Light:Hide()
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end))
        -- (the card drawn again or shut under the pointer: its tooltip goes with it)
        r:SetScript("OnHide", ns.Guarded(function(self)
            self.Light:Hide()
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end))
        f.tips[f.usedTips] = r
    end
    r.tip, r.name = row.tip, row.left
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", x - 2, y + 1)
    r:SetSize(width + 4, height + ROW)
    r:Show()
end

-- Where the value comes from: each row a name and its figure on the right; a group's name in the titles' bronze, its
-- rows in from it; a line between what the value stands on and what changes it. On a card kept open, a row that names
-- something shows it on hover (tipFor). A table's (`columns`, the states' captions: the regenerations', Ikar
-- 2026-11-23: "A, a table"): each caption over its column, small, in the titles' bronze, each row a figure a state
-- (`cells`), a row in twice (`indent` 2, small: a gain's rhythm under its name).
local function sources(rows, label, x, y, width, columns, cell)
    y = title(label, x, y)
    local n = columns and #columns or 0
    if n > 0 then
        local tall = 0
        for i, caption in ipairs(columns) do
            local t = text("GameFontNormalSmall", caption, LABEL, cell - 4)
            t:SetJustifyH("RIGHT")
            t:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + width - (n - i) * cell, y)
            tall = max(tall, heightOf(t))
        end
        y = y - tall - ROW
    end
    for _, row in ipairs(rows) do
        if row.rule then
            rule(x, y - 3, width, 1)
            y = y - 8
        else
            local inX = x + (row.indent == 2 and 2 * INDENT or row.indent and INDENT or 0)
            local left = text(row.small and "GameFontHighlightSmall" or "GameFontHighlight", row.left,
                row.group and LABEL or row.color)
            left:SetPoint("TOPLEFT", frame, "TOPLEFT", inX, y)
            local height
            if row.cells then
                local tall = 0
                for i = 1, n do
                    local c = text("GameFontHighlight", row.cells[i] or "", row.rightColor)
                    c:SetJustifyH("RIGHT")
                    c:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + width - (n - i) * cell, y)
                    tall = max(tall, heightOf(c))
                end
                left:SetWidth(width - (inX - x) - n * cell - 6)
                height = max(heightOf(left), tall)
            else
                local right = text("GameFontHighlight", row.right, row.rightColor)
                right:SetJustifyH("RIGHT")
                right:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + width, y)
                -- the name cut where its figure starts, a figure wider than its room (a share, what it comes to and
                -- the question mark: « +10 % (+123) ? ») having run over it (the review of 2026-11-19)
                left:SetWidth(width - (inX - x) - max(FIGURE, math.ceil(right:GetStringWidth() or 0) + 6))
                height = max(heightOf(left), heightOf(right))
            end
            if row.tip and frame ~= hover then
                tipFor(row, x, y, width, height)
            end
            y = y - height - ROW
        end
    end
    return y
end

-- A paragraph whose text is in the game's tooltip on its hover (how a value's figures are had, why they're worth
-- reaching: Ikar 2026-11-22, "hover to see details"): bronze on the card kept open, which the pointer can reach,
-- brighter under it; grey on the hover's, which it can't (it stands over nothing the pointer is on).
local function details(t, lines)
    local f = frame
    if f == hover then
        t:SetTextColor(GREY[1], GREY[2], GREY[3])
        return
    end
    t:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
    local d = f.Details
    if not d then
        d = CreateFrame("Frame", nil, f)
        d:EnableMouse(true)
        d:SetScript("OnEnter", ns.Guarded(function(self)
            self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(f.title or "")
            for _, line in ipairs(self.lines) do
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(line, GOLD[1], GOLD[2], GOLD[3], true)
            end
            GameTooltip:Show()
        end))
        d:SetScript("OnLeave", ns.Guarded(function(self)
            self.text:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
            GameTooltip:Hide()
        end))
        -- (the card drawn again or shut under the pointer: its tooltip goes with it)
        d:SetScript("OnHide", ns.Guarded(function(self)
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end))
        f.Details = d
    end
    d.text, d.lines = t, lines
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    d:SetSize(max(math.ceil(t:GetStringWidth() or 0), 20), heightOf(t))
    d:Show()
end

-- Paragraphs down a column, each wrapped at its width: what there is to know, or what the value gives in the game's
-- own sentences.
local function paragraphs(list, label, x, y, width)
    y = title(label, x, y)
    for _, p in ipairs(list) do
        local t = text("GameFontHighlight", p.text, p.color or GOLD, width)
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        if p.details then
            details(t, p.details)
        end
        y = y - heightOf(t) - 8
    end
    return y
end

-- What the value gives as figures: each large, what it is a figure of under it.
local function tiles(list, label, x, y, width)
    y = title(label, x, y)
    for _, tile in ipairs(list) do
        local figure = text("GameFontHighlightLarge", tile.figure)
        figure:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        y = y - heightOf(figure) - 1
        local caption = text("GameFontHighlight", tile.caption, GOLD, width)
        caption:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        y = y - heightOf(caption) - 10
    end
    return y
end

-- The card over `owner` with what `data` holds: title, value, detail (its base and changes), sources (rows) under
-- sourcesTitle, about (paragraphs) under aboutTitle, tiles or effects (paragraphs) under effectsTitle, hints (a line
-- each) and clicks (one line for all). With data.pinned, the card kept open of the value data.key: placed when it
-- opens, left where it is while it shows.
function Card.Show(owner, data)
    if data.pinned then
        local key = data.key or ""
        local f = pins[key]
        if not f then
            local at
            for i, s in ipairs(spare) do
                if not at or s.index < spare[at].index then
                    at = i
                end
            end
            f = at and table.remove(spare, at) or buildPinned()
            f.key, pins[key], latest = key, f, f
        end
        frame = f
    else
        hover = hover or build("KaLiHUDStatCard")
        frame = hover
    end
    local f = frame
    -- (a table's sources a column wider a state past the first)
    local states, cell = data.columns and #data.columns or 0, CELL + (data.wide and CELL_WIDER or 0)
    WIDTHS.sources = SOURCES + (states > 0 and (states - 1) * cell + (data.wide and CELL_WIDER or 0)
        or (data.wide and WIDER or 0))
    FIGURE = FIGURES + (data.wide and WIDER or 0)
    for i = 1, f.used do
        f.texts[i]:Hide()
    end
    for i = 1, f.usedRules do
        f.rules[i]:Hide()
    end
    for i = 1, f.usedTips do
        f.tips[i]:Hide()
    end
    f.used, f.usedRules, f.usedTips = 0, 0, 0
    for _, g in pairs(f.Glows) do
        g:Hide()
    end
    if f.Details then
        f.Details:Hide()
    end
    f.title = data.title
    local edge = ns.Folders.Inset() + PAD
    local columns = {}
    for _, key in ipairs(ORDER) do
        local has = data[key] and #data[key] > 0 or (key == "effects" and data.tiles and #data.tiles > 0)
        if has then
            columns[#columns + 1] = key
        end
    end
    local width = 0
    for i, key in ipairs(columns) do
        width = width + WIDTHS[key] + (i > 1 and GAP or 0)
    end
    width = max(width, WIDTHS.sources)
    -- the head: the name, and on the right the value, what it's made of before it; the card as wide as the three need
    -- (a weapon's damage with its changes is longer than a column, and ran into its name: the review of 2026-11-19)
    local y = -edge
    local name = text("GameFontNormalLarge", data.title, GOLD)
    name:SetPoint("TOPLEFT", f, "TOPLEFT", edge, y)
    local value = text("GameFontHighlightHuge", data.value)
    value:SetJustifyH("RIGHT")
    local need = (name:GetStringWidth() or 0) + HEAD_GAP + (value:GetStringWidth() or 0)
    if data.detail and data.detail ~= "" then
        local detail = text("GameFontHighlightSmall", data.detail)
        detail:SetJustifyH("RIGHT")
        detail:SetPoint("BOTTOMRIGHT", value, "BOTTOMLEFT", -8, 2)
        need = need + (detail:GetStringWidth() or 0) + 8
    end
    width = max(width, math.ceil(need))
    value:SetPoint("TOPRIGHT", f, "TOPLEFT", edge + width, y)
    local head = max(heightOf(name), heightOf(value))
    y = y - head - 6
    local foot = y
    if #columns > 0 then
        rule(edge, y, width, 1)
        y = y - 8
        local x, top = edge, y
        for i, key in ipairs(columns) do
            if i > 1 then
                x = x + GAP
            end
            local under
            if key == "sources" then
                under = sources(data.sources, data.sourcesTitle, x, top, WIDTHS[key], data.columns, cell)
            elseif key == "about" then
                under = paragraphs(data.about, data.aboutTitle, x, top, WIDTHS[key])
            elseif data.tiles and #data.tiles > 0 then
                under = tiles(data.tiles, data.effectsTitle, x, top, WIDTHS[key])
            else
                under = paragraphs(data.effects, data.effectsTitle, x, top, WIDTHS[key])
            end
            foot = math.min(foot, under)
            x = x + WIDTHS[key]
        end
        -- a line between columns, as tall as the tallest
        x = edge
        for i = 1, #columns - 1 do
            x = x + WIDTHS[columns[i]] + GAP
            rule(x - GAP / 2, top, 1, top - foot)
        end
        -- the input's glow on the left, the output's on the right, from the head's line to the foot's, past the
        -- border's metal; none for a column the card hasn't
        local metal = max(0, ns.Folders.Inset() - 2)
        local function glow(key, side, x)
            local g = f.Glows[key]
            g:ClearAllPoints()
            g:SetPoint("TOP" .. side, f, "TOP" .. side, x, top + 8)
            g:SetPoint("BOTTOM" .. side, f, "TOP" .. side, x, foot)
            g:SetWidth(GLOW_WIDTH)
            g:Show()
        end
        if columns[1] == "sources" then
            glow("sources", "LEFT", metal)
        end
        if columns[#columns] == "effects" then
            glow("effects", "RIGHT", -metal)
        end
        y = foot
    end
    -- the foot, greyed: the hints, a line each, then what the clicks do, on one line (Ikar 2026-11-20: "the bottom
    -- hints could be displayed in one line")
    f.body, f.clicksAt, f.clicks = f.used, nil, nil
    local hints, clicks = data.hints or {}, data.clicks or {}
    if #hints > 0 or #clicks > 0 then
        rule(edge, y, width, 1)
        y = y - 6
        for _, hint in ipairs(hints) do
            local t = text("GameFontDisableSmall", hint, GREY, width)
            t:SetPoint("TOPLEFT", f, "TOPLEFT", edge, y)
            y = y - heightOf(t) - 2
        end
        if #clicks > 0 then
            local t = text("GameFontDisableSmall", table.concat(clicks, BETWEEN), GREY, width)
            t:SetPoint("TOPLEFT", f, "TOPLEFT", edge, y)
            y = y - heightOf(t) - 2
            f.clicksAt, f.clicks = f.used, clicks
        end
    end
    f:SetSize(width + 2 * edge, -y + edge)
    if f == hover then
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", owner, "TOP", 0, 4)
    elseif not f:IsShown() then
        place(f, owner)
    end
    f.owner, f.columns = owner, columns
    f:Show()
end

-- The hover's card away; the one kept open stays.
function Card.Hide()
    if hover then
        hover.owner = nil
        hover:Hide()
    end
end

-- What the hover's card stands over while it shows.
function Card.Owner()
    return hover and hover:IsShown() and hover.owner or nil
end

-- Whether the card of the value `key` is kept open, any one without it; and shut, as its cross does, all without it.
function Card.Pinned(key)
    if key ~= nil then
        return pins[key] ~= nil and pins[key]:IsShown()
    end
    for _, f in pairs(pins) do
        if f:IsShown() then
            return true
        end
    end
    return false
end
function Card.Unpin(key)
    local shut = {}
    for k, f in pairs(pins) do
        if key == nil or k == key then
            shut[#shut + 1] = f
        end
    end
    for _, f in ipairs(shut) do
        f:Hide()
    end
end
-- The cards kept open, by their value's key (for the tests).
function Card.PinnedFrame(key)
    return pins[key]
end

-- Every text a card shows now, in the order drawn, its foot's hints with them when asked (its clicks' line one hint
-- each), and the columns it has (for the tests): the hover's, the kept one's.
local function linesOf(f, hints)
    local lines = {}
    if f and f:IsShown() then
        for i = 1, hints and f.used or f.body do
            if i == f.clicksAt then
                for _, click in ipairs(f.clicks) do
                    lines[#lines + 1] = click
                end
            else
                lines[#lines + 1] = f.texts[i]:GetText() or ""
            end
        end
    end
    return lines, f and f.columns or {}
end
function Card.Lines(hints)
    return linesOf(hover, hints)
end
-- (the card kept open of `key`, else the one opened last)
function Card.PinnedLines(hints, key)
    return linesOf(key ~= nil and pins[key] or latest, hints)
end

-- A click takes it away, as it takes a tooltip (Ikar 2026-11-18: "when opening anything, the tooltip should
-- disappear"): what the click opens would stand under it. The pointer coming back brings it again. The hover's
-- alone: the one kept open stays.
ns.On("GLOBAL_MOUSE_DOWN", function()
    ns.SafeCall(Card.Hide)
end)
