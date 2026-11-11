-- The notebook: one layout, two styles (Ikar, 2026-11-09): « Épuré », a game window, and « Livre », the
-- profession's quest page. Header (profession, the rank on the classic skill bar, the two counts, the hammer that
-- opens the professions window, « Suivre »), search and filter, the list in three sections by the game's own
-- categories, the selected recipe's detail below it, a footer, and profession tabs down the right edge.
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local Notebook = {}
ns.Notebook = Notebook

local frame
-- The session's view: the search text, the filter, the selected recipe. The profession, the sections' and
-- categories' open state and the position are saved (db.ui).
local view = { search = "", filter = {}, selected = nil }

local TOP, ROW, SECTION, CATEGORY, FOOT = 96, 32, 24, 20, 30

local function ui()
    return ns.db.ui
end

-- The profession shown: the one asked for, else the last, else the character's first, else any with recipes.
local function currentSkill()
    local m = ns.book
    local skill = ui().skill
    local mine, others = m:ProfsOf(m.me), m:Others(m.me)
    local ok = false
    for _, list in ipairs({ mine, others }) do
        for _, s in ipairs(list) do
            ok = ok or s == skill
        end
    end
    if ok then
        return skill
    end
    return mine[1] or others[1]
end

local function book()
    return ns.db.options.style == "book"
end

-- ---------- Pieces ----------

local function textColour(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

local function makeSection(parent)
    local b = W.Frame("Button", parent)
    b:SetHeight(SECTION)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", 4, 0)
    b.sign = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.sign:SetPoint("RIGHT", -6, 0)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 2, 1)
    b.line:SetPoint("BOTTOMRIGHT", -2, 1)
    b.line:SetColorTexture(0.6, 0.5, 0.25, 0.45)
    b:SetScript("OnClick", function(self)
        ns.SafeCall(function()
            ui().open[self.key] = not ui().open[self.key]
            if PlaySound and SOUNDKIT then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            Notebook.Refresh()
        end)
    end)
    return b
end

local function makeCategory(parent)
    local b = W.Frame("Button", parent)
    b:SetHeight(CATEGORY)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 14, 0)
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.count:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnClick", function(self)
        ns.SafeCall(function()
            local closed = ui().closedCats
            closed[self.key] = not closed[self.key] or nil
            -- The collapse sound, as the sections' and Blizzard's own collapsible headers.
            if PlaySound and SOUNDKIT then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            Notebook.Refresh()
        end)
    end)
    return b
end

local function rowMenu(owner, spell)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ns.book:Name(spell))
        local spot = W.SpotOf(spell)
        local place = root:CreateButton(L.PLACE_WAYPOINT, function()
            ns.SafeCall(W.Waypoint, spot)
        end)
        if not spot and place.SetEnabled then
            place:SetEnabled(false)
        end
        root:CreateButton(L.LINK_CHAT, function()
            ns.SafeCall(function()
                local link = W.RecipeLink(spell)
                if not W.InsertLink(link) and ChatFrameUtil and ChatFrameUtil.OpenChat then
                    ChatFrameUtil.OpenChat(link)
                end
            end)
        end)
        root:CreateButton(ns.G("CANCEL", "Annuler"), function() end)
    end)
end

local function makeRow(parent)
    local b = W.Frame("Button", parent)
    b:SetHeight(ROW)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(1, 0.82, 0, 0.14)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    b.badge = W.Badge(b, 26, 16)
    b.badge:SetPoint("LEFT", 4, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", 38, -3)
    b.name:SetJustifyH("LEFT")
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
    b.sub:SetJustifyH("LEFT")
    -- The bag alone, nothing behind it (Ikar, 2026-11-10).
    b.mine = b:CreateTexture(nil, "OVERLAY")
    b.mine:SetSize(16, 16)
    W.SetAtlas(b.mine, W.ATLAS.banker)
    b.alt = b:CreateTexture(nil, "OVERLAY")
    b.alt:SetSize(16, 16)
    W.SetAtlas(b.alt, W.ATLAS.friend)
    b:SetScript("OnClick", function(self, button)
        ns.SafeCall(function()
            if button == "RightButton" then
                rowMenu(self, self.spell)
            elseif IsModifiedClick and IsModifiedClick("CHATLINK") then
                W.InsertLink(W.RecipeLink(self.spell))
            else
                Notebook.Select(view.selected ~= self.spell and self.spell or nil)
            end
        end)
    end)
    b:SetScript("OnEnter", function(self)
        ns.SafeCall(W.RecipeTooltip, self, self.spell)
    end)
    b:SetScript("OnLeave", W.HideTooltip)
    return b
end

-- Under the recipe's name: where it was seen, "+2" for more; for « Appris », who else knows it.
local function subline(m, spell, known)
    local parts = {}
    if known and not m:Knows(m.me, spell) then
        local names = {}
        for _, key in ipairs(m:Knowers(spell)) do
            names[#names + 1] = m:CharName(key)
        end
        if #names > 0 then
            parts[#parts + 1] = string.format(L.COMPACT_KNOWN_BY, table.concat(names, ", "))
        end
    end
    local seen = m:Sightings(spell)
    if seen[1] then
        parts[#parts + 1] = ns.Text.Where(m, seen[1])
    end
    if #seen > 1 then
        parts[#parts + 1] = "+" .. (#seen - 1)
    end
    return table.concat(parts, " · ")
end

local function fillRow(b, spell, known, width)
    local m = ns.book
    local o = ns.db.options
    local ink = book()
    b.spell = spell
    b:SetWidth(width)
    b.sel:SetShown(view.selected == spell)
    W.SetBadge(b.badge, spell, m.me)
    b.name:SetText(m:Name(spell))
    textColour(b.name, ink and W.INK or (known and m:Knows(m.me, spell) and W.GRAY or W.WHITE))
    b.sub:SetText(subline(m, spell, known))
    textColour(b.sub, ink and { 0.3, 0.22, 0.12 } or W.GRAY)
    -- Who holds it: this character's bag, another character's friend icon; the detail says where (Ikar, 2026-11-10:
    -- no words under them).
    local pos = m:Possession(spell, m.me)
    local showMine = pos and pos.mine and o.nbOwned
    local showAlt = pos and #pos.alts > 0 and o.nbAlt
    b.mine:ClearAllPoints()
    b.alt:ClearAllPoints()
    if showAlt then
        b.alt:SetPoint("TOPRIGHT", -6, -2)
    end
    if showMine then
        b.mine:SetPoint("TOPRIGHT", showAlt and b.alt or b, showAlt and "TOPLEFT" or "TOPRIGHT", showAlt and -4 or -6, showAlt and 0 or -2)
    end
    b.mine:SetShown(showMine and true or false)
    b.alt:SetShown(showAlt and true or false)
    local right = (showMine and showAlt) and 46 or (showMine or showAlt) and 26 or 8
    b.name:SetPoint("RIGHT", b, "RIGHT", -right, 0)
    b.sub:SetPoint("RIGHT", b, "RIGHT", -right, 0)
end

-- ---------- Building ----------

local function makeSkillBar(parent)
    local bar = W.Frame("StatusBar", parent)
    bar:SetSize(190, 14)
    bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    bar:SetStatusBarColor(0.25, 0.25, 0.75)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)
    bar.border = bar:CreateTexture(nil, "OVERLAY")
    bar.border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    bar.border:SetPoint("TOPLEFT", -5, 5)
    bar.border:SetPoint("BOTTOMRIGHT", 5, -5)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 1)
    return bar
end

local function followTooltip(self)
    local on = ns.db.options.follow
    W.TextTooltip(self, L.FOLLOW, { { L.FOLLOW_TIP }, { on and ns.G("VIDEO_OPTIONS_ENABLED", "Activé") or
        ns.G("VIDEO_OPTIONS_DISABLED", "Désactivé"), on and { 0.1, 1, 0.1 } or W.GRAY }, { L.ALSO_IN_OPTIONS, W.GRAY } })
end

local function filterMenu(root)
    local m = ns.book
    local f = view.filter
    local function toggle(tbl, key)
        return function()
            tbl[key] = not tbl[key] or nil
            Notebook.Refresh()
        end
    end
    root:CreateCheckbox(ns.G("TRADESKILL_FILTER_HAS_SKILL_UP", "Peut faire progresser"), function()
        return f.skillUp == true
    end, toggle(f, "skillUp"))
    root:CreateCheckbox(ns.G("CRAFT_IS_MAKEABLE", "Comp. disponibles"), function()
        return f.makeable == true
    end, toggle(f, "makeable"))
    f.cats, f.sources, f.owned = f.cats or {}, f.sources or {}, f.owned or {}
    root:CreateTitle(L.FILTER_CATEGORIES)
    for _, c in ipairs(m:CategoriesOf(currentSkill() or 0)) do
        local id = c.id or 0
        root:CreateCheckbox(c.name, function()
            return f.cats[id] == true
        end, toggle(f.cats, id))
    end
    root:CreateTitle(L.FILTER_SOURCES)
    for _, kind in ipairs({ "vendor", "trainer", "ah", "drop", "quest", "bags" }) do
        root:CreateCheckbox(L["SOURCE_" .. kind], function()
            return f.sources[kind] == true
        end, toggle(f.sources, kind))
    end
    root:CreateTitle(L.FILTER_OWNED)
    root:CreateCheckbox(L.OWNED_MINE, function()
        return f.owned.mine == true
    end, toggle(f.owned, "mine"))
    root:CreateCheckbox(L.OWNED_ALT, function()
        return f.owned.alt == true
    end, toggle(f.owned, "alt"))
    root:CreateButton(L.FILTER_RESET, function()
        view.filter = {}
        Notebook.Refresh()
    end)
end

local function build()
    if frame then
        return frame
    end
    frame = W.Frame("Frame", UIParent, "ButtonFrameTemplate", "KaLiRecipeNotebook")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if frame.SetTitle then
        frame:SetTitle(L.NOTEBOOK)
    end
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not Notebook.docked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not Notebook.docked then
            local point, _, relPoint, x, y = self:GetPoint()
            ui().pos = { x, y, point, relPoint }
        end
    end)
    tinsert(UISpecialFrames, "KaLiRecipeNotebook")

    -- The corner grip (Ikar, 2026-11-10: the options' sliders can't be watched, since the options panel closes the
    -- notebook, and Edit Mode takes no addon window): Blizzard's own, the chat windows' (PanelResizeButtonTemplate).
    -- The notebook follows as it's dragged, within « Largeur » and « Hauteur »'s ranges, and keeps the size there.
    local templates = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    if templates and templates("PanelResizeButtonTemplate") and frame.SetResizable then
        local w, h = ns.DB.RANGES.width, ns.DB.RANGES.height
        frame:SetResizable(true)
        if frame.SetResizeBounds then
            frame:SetResizeBounds(w[1], h[1], w[2], h[2])
        end
        frame.grip = W.Frame("Button", frame, "PanelResizeButtonTemplate")
        frame.grip:SetPoint("BOTTOMRIGHT", -4, 4)
        -- Above the template's border, a child frame at level 500, as the gear is.
        if frame.CloseButton then
            frame.grip:SetFrameLevel(frame.CloseButton:GetFrameLevel())
        end
        frame.grip:Init(frame, w[1], h[1], w[2], h[2])
        frame.grip.resizeCallback = function(_, width, height, active)
            if active then
                local o = ns.db.options
                o.width, o.height = width, height
                ns.Later("notebookSize", Notebook.Refresh)
            end
        end
        frame.grip.resizeStoppedCallback = function()
            ns.SafeCall(Notebook.Resized)
        end
    end
    frame:SetScript("OnHide", function()
        ns.SafeCall(function()
            if ns.Follow then
                ns.Follow.NotebookHidden()
            end
        end)
    end)

    -- Top right, beside the close button: the addon's options (Ikar, 2026-11-10), in the art and highlight of
    -- Blizzard's own settings gear (UIPanelIconDropdownButtonTemplate).
    frame.gear = W.Frame("Button", frame)
    frame.gear:SetSize(15, 16)
    if frame.CloseButton then
        frame.gear:SetPoint("RIGHT", frame.CloseButton, "LEFT", -4, 0)
        -- The template's border is a child frame at level 500, its close button at 510: at the frame's own level the
        -- gear sat under the title bar (Ikar's screenshot, 2026-11-10). With the close button, above it.
        frame.gear:SetFrameLevel(frame.CloseButton:GetFrameLevel())
    else
        frame.gear:SetPoint("TOPRIGHT", -30, -5)
    end
    frame.gear.tex = frame.gear:CreateTexture(nil, "ARTWORK")
    frame.gear.tex:SetAllPoints()
    W.SetAtlas(frame.gear.tex, W.ATLAS.gear)
    frame.gear.hl = frame.gear:CreateTexture(nil, "HIGHLIGHT")
    frame.gear.hl:SetAllPoints()
    W.SetAtlas(frame.gear.hl, W.ATLAS.gear)
    frame.gear.hl:SetBlendMode("ADD")
    frame.gear.hl:SetAlpha(0.4)
    frame.gear:SetScript("OnClick", function()
        ns.SafeCall(ns.Options.Open)
    end)
    frame.gear:SetScript("OnEnter", function(self)
        W.TextTooltip(self, L.OPEN_OPTIONS)
    end)
    frame.gear:SetScript("OnLeave", W.HideTooltip)

    -- Clean: the template's inset around the list and the detail, below the header and the search.
    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", 16, -(TOP + 6))
        frame.Inset:SetPoint("BOTTOMRIGHT", -18, FOOT - 6)
        -- Over the inset's marble, under its border and the list.
        frame.card = frame.Inset:CreateTexture(nil, "BACKGROUND", nil, 1)
        frame.card:SetPoint("TOPLEFT", 3, -3)
        frame.card:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    -- Book: the profession's quest parchment over the page, cropped to cover it rather than stretched.
    frame.parchment = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    frame.parchment:SetPoint("TOPLEFT", 6, -24)
    frame.parchment:SetPoint("BOTTOMRIGHT", -6, 6)

    local head = W.Frame("Frame", frame)
    head:SetPoint("TOPLEFT", 26, -30)
    head:SetPoint("TOPRIGHT", -26, -30)
    head:SetHeight(40)
    frame.head = head
    head.title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    head.title:SetPoint("TOPLEFT", 0, 0)
    head.bar = makeSkillBar(head)
    head.bar:SetPoint("TOPLEFT", head.title, "BOTTOMLEFT", 2, -6)
    head.counts = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head.counts:SetPoint("LEFT", head.bar, "RIGHT", 10, 0)
    head.counts:SetJustifyH("LEFT")
    head.counts:SetWordWrap(false)
    -- Forever's arrow button at its own size, 22 (2026-11-10: drawn at 24 it sat high and past the filter button). Its
    -- right edge lines up with « Filtrer » below (the frame's -30, the header's -4); it's centred on the title and the
    -- skill bar, whose middle is 19 below the header's top.
    head.follow = W.Frame("Button", head)
    head.follow:SetSize(22, 22)
    head.follow:SetPoint("TOPRIGHT", -4, -8)
    head.follow.tex = head.follow:CreateTexture(nil, "ARTWORK")
    head.follow.tex:SetAllPoints()
    head.follow.hl = head.follow:CreateTexture(nil, "HIGHLIGHT")
    head.follow.hl:SetAllPoints()
    W.SetAtlas(head.follow.hl, W.ATLAS.follow)
    head.follow.hl:SetBlendMode("ADD")
    head.follow.hl:SetAlpha(0.3)
    -- The pressed art only while the mouse holds it down, as a game button does: its arrow sits a pixel right and
    -- down in its frame, which left on looked broken (Ikar, 2026-11-10). On or off is colour or gray.
    head.follow:SetScript("OnMouseDown", function(self)
        W.SetAtlas(self.tex, W.ATLAS.followDown)
    end)
    head.follow:SetScript("OnMouseUp", function(self)
        W.SetAtlas(self.tex, W.ATLAS.follow)
    end)
    head.follow:SetScript("OnClick", function()
        ns.SafeCall(function()
            ns.Follow.Set(not ns.db.options.follow)
            Notebook.Refresh()
        end)
    end)
    head.follow:SetScript("OnEnter", followTooltip)
    head.follow:SetScript("OnLeave", W.HideTooltip)
    head.hammer = W.Frame("Button", head)
    head.hammer:SetSize(19, 24)
    head.hammer:SetPoint("RIGHT", head.follow, "LEFT", -8, 0)
    head.hammer.tex = head.hammer:CreateTexture(nil, "ARTWORK")
    head.hammer.tex:SetAllPoints()
    W.SetAtlas(head.hammer.tex, W.ATLAS.hammer)
    head.hammer:SetScript("OnClick", function()
        ns.SafeCall(Notebook.OpenProfessions)
    end)
    head.hammer:SetScript("OnEnter", function(self)
        W.TextTooltip(self, L.OPEN_PROF, { { string.format(L.OPEN_PROF_TIP, ns.Game.ProfName(currentSkill() or 0)) } })
    end)
    head.hammer:SetScript("OnLeave", W.HideTooltip)

    frame.search = W.Frame("EditBox", frame, "SearchBoxTemplate")
    frame.search:SetHeight(20)
    frame.search:SetPoint("TOPLEFT", 32, -(TOP - 18))
    frame.search:SetPoint("TOPRIGHT", -132, -(TOP - 18))
    if frame.search.Instructions then
        frame.search.Instructions:SetText(L.SEARCH)
    end
    frame.search:HookScript("OnTextChanged", function(self)
        view.search = self:GetText() or ""
        ns.Later("notebookSearch", Notebook.Refresh)
    end)
    local dropdown = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("WowStyle1FilterDropdownTemplate")
    if dropdown and MenuUtil then
        frame.filter = W.Frame("DropdownButton", frame, "WowStyle1FilterDropdownTemplate")
        if frame.filter.SetupMenu then
            frame.filter:SetupMenu(function(_, root)
                ns.SafeCall(filterMenu, root)
            end)
        end
    else
        frame.filter = W.Frame("Button", frame, "UIPanelButtonTemplate")
        frame.filter:SetScript("OnClick", function(self)
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self, function(_, root)
                    ns.SafeCall(filterMenu, root)
                end)
            end
        end)
    end
    frame.filter:SetSize(94, 22)
    frame.filter:SetPoint("LEFT", frame.search, "RIGHT", 8, 0)
    if frame.filter.SetText then
        frame.filter:SetText(ns.G("FILTER", "Filtrer"))
    end

    frame.list = W.Frame("ScrollFrame", frame)
    frame.list:EnableMouseWheel(true)
    frame.content = W.Frame("Frame", frame.list)
    frame.content:SetSize(10, 10)
    frame.list:SetScrollChild(frame.content)
    frame.bar = W.Frame("EventFrame", frame, "MinimalScrollBar")
    frame.bar:SetPoint("TOPLEFT", frame.list, "TOPRIGHT", 6, 0)
    frame.bar:SetPoint("BOTTOMLEFT", frame.list, "BOTTOMRIGHT", 6, 0)
    if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
        ScrollUtil.InitScrollFrameWithScrollBar(frame.list, frame.bar)
    end
    frame.sections = W.Pool(function()
        return makeSection(frame.content)
    end)
    frame.categories = W.Pool(function()
        return makeCategory(frame.content)
    end)
    frame.rows = W.Pool(function()
        return makeRow(frame.content)
    end)
    frame.empty = frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", 8, -10)

    frame.detail = ns.Detail.New(frame)

    frame.foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.foot:SetPoint("BOTTOMLEFT", 24, 10)
    frame.foot:SetPoint("BOTTOMRIGHT", -24, 10)
    frame.foot:SetJustifyH("LEFT")

    frame.tabs = W.Pool(function()
        local t = W.Frame("Button", frame)
        t:SetSize(40, 58)
        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
        W.SetAtlas(t.bg, W.ATLAS.tab)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(28, 28)
        t.icon:SetPoint("LEFT", 4, 2)
        t.hl = t:CreateTexture(nil, "HIGHLIGHT")
        t.hl:SetAllPoints(t.icon)
        t.hl:SetColorTexture(1, 1, 1, 0.15)
        t:SetScript("OnClick", function(self)
            ns.SafeCall(Notebook.Show, self.skill)
        end)
        t:SetScript("OnEnter", function(self)
            local m, skill = ns.book, self.skill
            local learn, seen = m:Counts(m.me, skill)
            local lines = {}
            if m:HasProf(m.me, skill) then
                lines[1] = { string.format(L.RANK, m:Rank(m.me, skill), m:MaxRank(m.me, skill)) }
                lines[2] = { string.format(L.TO_LEARN, learn), W.GOLD }
            else
                lines[1] = { L.NOT_YOUR_PROFESSION }
            end
            lines[#lines + 1] = { ns.Plural(seen, L.SEEN_ONE, L.SEEN_MANY), W.GOLD }
            W.TextTooltip(self, ns.Game.ProfName(skill), lines)
        end)
        t:SetScript("OnLeave", W.HideTooltip)
        return t
    end)
    frame:Hide()
    return frame
end

-- ---------- Drawing ----------

local function drawHeader(m, skill, width)
    local head = frame.head
    local ink = book()
    head.title:SetText(ns.Game.ProfName(skill))
    if ink then
        head.title:SetTextColor(0, 0, 0)
    else
        head.title:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    end
    local own = m:HasProf(m.me, skill)
    local learn, seen = m:Counts(m.me, skill)
    local seenText = ns.Plural(seen, L.SEEN_ONE, L.SEEN_MANY)
    head.bar:SetShown(own)
    head.counts:ClearAllPoints()
    if own then
        local rank, max = m:Rank(m.me, skill), m:MaxRank(m.me, skill)
        -- The bar gives way first when the notebook is narrow, so the line never runs into the buttons.
        head.bar:SetWidth(math.max(100, math.min(190, width - 370)))
        head.bar:SetMinMaxValues(0, math.max(1, max))
        head.bar:SetValue(rank)
        head.bar.text:SetText(string.format("%d/%d", rank, max))
        head.counts:SetPoint("LEFT", head.bar, "RIGHT", 10, 0)
        head.counts:SetText(string.format(L.TO_LEARN, learn) .. " · " .. seenText)
    else
        head.counts:SetPoint("TOPLEFT", head.title, "BOTTOMLEFT", 0, -6)
        head.counts:SetText(L.NOT_YOUR_PROFESSION .. " · " .. seenText)
    end
    textColour(head.counts, ink and W.INK or W.WHITE)
    head.hammer:SetShown(own)
    local on = ns.db.options.follow
    W.SetAtlas(head.follow.tex, W.ATLAS.follow)
    head.follow.tex:SetDesaturated(not on)
    head.follow.tex:SetAlpha(on and 1 or 0.8)
end

-- An atlas covering w by h at any size, cropped rather than stretched: what spills over is cut around keepX (0 the
-- left edge kept, 0.5 the middle, 1 the right) and keepY (0 the top kept, 1 the bottom).
local function cover(texture, info, w, h, keepX, keepY)
    texture:SetTexture(info.file or info.filename)
    local aw, ah = info.width or w, info.height or h
    local scale = math.max(w / aw, h / ah)
    local cw, ch = w / (aw * scale), h / (ah * scale) -- the share of the atlas shown, each way
    local l, r = info.leftTexCoord or 0, info.rightTexCoord or 1
    local t, b = info.topTexCoord or 0, info.bottomTexCoord or 1
    local du, dv = (r - l) * (1 - cw), (b - t) * (1 - ch)
    texture:SetTexCoord(l + du * keepX, r - du * (1 - keepX), t + dv * keepY, b - dv * (1 - keepY))
end

local function atlasInfo(name)
    return name and ns.Call(C_Texture.GetAtlasInfo, name)
end

-- The profession's art: Book's quest page over the whole page, its top kept; Clean's card inside the inset, its
-- bottom right kept, where the profession is drawn.
local function drawStyle(skill)
    local ink = book()
    frame.parchment:SetShown(ink)
    if frame.Inset then
        frame.Inset:SetShown(not ink)
    end
    if ink then
        local info = atlasInfo(W.QUEST_BG[skill]) or atlasInfo(W.PARCHMENT)
        if info then
            cover(frame.parchment, info, frame:GetWidth() - 12, frame:GetHeight() - 30, 0.5, 0)
        else
            frame.parchment:SetColorTexture(0.86, 0.78, 0.6, 1)
        end
    elseif frame.card then
        local info = atlasInfo(W.CARD[skill])
        frame.card:SetShown(info ~= nil)
        if info then
            cover(frame.card, info, frame:GetWidth() - 40, frame:GetHeight() - TOP - FOOT - 6, 1, 1)
        end
    end
end

-- Lays out the list from the model; returns its height.
local function drawList(m, skill, width)
    frame.sections:ReleaseAll()
    frame.categories:ReleaseAll()
    frame.rows:ReleaseAll()
    local split = m:Split(m.me, skill)
    local key = m.me
    local function keep(list)
        local out = {}
        for _, spell in ipairs(list) do
            if m:Passes(spell, key, view.search, view.filter) then
                out[#out + 1] = spell
            end
        end
        return out
    end
    local learn, seen, known = keep(split.learn), keep(split.seen), keep(split.known)
    local y = 0
    local open = ui().open
    local closed = ui().closedCats
    local selectedShown = false
    local function section(label, list, id, isKnown)
        local s = frame.sections:Acquire()
        s.key = id
        s:SetWidth(width)
        s:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
        s.text:SetText(string.format("%s (%d)", label, #list))
        s.sign:SetText(open[id] and "–" or "+")
        if book() then
            textColour(s.text, { 0, 0, 0 })
            textColour(s.sign, { 0, 0, 0 })
        else
            textColour(s.text, W.GOLD)
            textColour(s.sign, W.GOLD)
        end
        y = y + SECTION
        if not open[id] then
            return
        end
        for _, g in ipairs(m:ByCategory(list)) do
            local ck = id .. ":" .. tostring(g.id or 0)
            local c = frame.categories:Acquire()
            c.key = ck
            c:SetWidth(width)
            c:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
            c.text:SetText((closed[ck] and "+ " or "") .. g.name)
            c.count:SetText(tostring(#g.spells))
            textColour(c.text, book() and W.INK or { 0.9, 0.9, 0.9 })
            y = y + CATEGORY
            if not closed[ck] then
                for _, spell in ipairs(g.spells) do
                    local r = frame.rows:Acquire()
                    r:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
                    fillRow(r, spell, isKnown, width)
                    if spell == view.selected then
                        selectedShown = true
                        frame.selectedTop = y
                    end
                    y = y + ROW
                end
            end
        end
    end
    if m:HasProf(m.me, skill) then
        section(L.SECTION_LEARN, learn, "learn", false)
    end
    section(L.SECTION_SEEN, seen, "seen", false)
    section(ns.G("TRADE_SKILLS_LEARNED_TAB", "Appris"), known, "known", true)
    local nothing = #learn + #seen + #known == 0
    frame.empty:SetShown(nothing)
    if nothing then
        frame.empty:SetText((view.search ~= "" or ns.Model.Filtered(view.filter)) and L.EMPTY_FILTERED or L.EMPTY)
        frame.empty:SetPoint("TOPLEFT", 8, -(y + 8))
        y = y + 30
    end
    frame.content:SetSize(width, math.max(1, y))
    return y, selectedShown
end

local function drawTabs(m, skill)
    frame.tabs:ReleaseAll()
    local y = -46
    local function add(s, dim)
        local t = frame.tabs:Acquire()
        t.skill = s
        t:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, y)
        t.icon:SetTexture(ns.Game.ProfIcon(s))
        t.icon:SetDesaturated(dim and s ~= skill)
        t.icon:SetAlpha(s == skill and 1 or 0.8)
        y = y - 50
    end
    for _, s in ipairs(m:ProfsOf(m.me)) do
        add(s, false)
    end
    y = y - 8
    for _, s in ipairs(m:Others(m.me)) do
        add(s, true)
    end
end

function Notebook.Refresh()
    if not (frame and frame:IsShown() and ns.book) then
        return
    end
    local m = ns.book
    local o = ns.db.options
    frame:SetSize(o.width, o.height)
    local skill = currentSkill()
    local width = o.width - 62
    drawStyle(skill)
    drawTabs(m, skill or 0)
    if not skill then
        frame.head:Hide()
        frame.detail:Hide()
        frame.sections:ReleaseAll()
        frame.categories:ReleaseAll()
        frame.rows:ReleaseAll()
        frame.empty:SetText(L.EMPTY)
        frame.empty:Show()
        frame.foot:SetText(ns.Plural(m:Total(), L.FOOTER_ONE, L.FOOTER_MANY))
        frame.list:SetPoint("TOPLEFT", 24, -TOP - 12)
        frame.list:SetPoint("BOTTOMRIGHT", -40, FOOT)
        return
    end
    frame.head:Show()
    drawHeader(m, skill, o.width)
    if view.selected and not (m:Info(view.selected) and m:Info(view.selected).skill == skill) then
        view.selected = nil
    end
    local _, selectedShown = drawList(m, skill, width)
    -- The detail takes what its content needs, half the room at most; the list keeps the rest and its top.
    local room = o.height - TOP - 12 - FOOT - 8
    local detailHeight = 0
    if view.selected then
        local wanted = ns.Detail.Fill(frame.detail, view.selected, width + 14, book())
        detailHeight = math.min(wanted, math.floor(room / 2))
        frame.detail:ClearAllPoints()
        frame.detail:SetPoint("BOTTOMLEFT", 24, FOOT)
        frame.detail:SetPoint("BOTTOMRIGHT", -26, FOOT)
        frame.detail:SetHeight(detailHeight)
    else
        frame.detail:Hide()
    end
    frame.list:ClearAllPoints()
    frame.list:SetPoint("TOPLEFT", 24, -TOP - 12)
    frame.list:SetPoint("BOTTOMRIGHT", -40, FOOT + detailHeight + (detailHeight > 0 and 6 or 0))
    -- The selected row stays in view.
    if selectedShown and frame.selectedTop then
        local top, h = frame.list:GetVerticalScroll() or 0, frame.list:GetHeight() or 0
        if frame.selectedTop < top then
            frame.list:SetVerticalScroll(frame.selectedTop)
        elseif h > 0 and frame.selectedTop + ROW > top + h then
            frame.list:SetVerticalScroll(frame.selectedTop + ROW - h)
        end
    end
    frame.foot:SetText(ns.Plural(m:Total(), L.FOOTER_ONE, L.FOOTER_MANY))
    textColour(frame.foot, book() and { 0.3, 0.22, 0.12 } or W.GRAY)
end

-- ---------- What others call ----------

-- Where the notebook is docked: the window and the side, for the grip to put it back.
local docking

local function place()
    frame:ClearAllPoints()
    local pos = ui().pos
    if pos then
        frame:SetPoint(pos[3] or "TOPLEFT", UIParent, pos[4] or "TOPLEFT", pos[1], pos[2])
    else
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -100)
    end
end

-- Shows the notebook on a profession, or the one it showed last.
function Notebook.Show(skill)
    build()
    if skill then
        if skill ~= ui().skill then
            view.selected = nil
        end
        ui().skill = skill
    end
    if not frame:IsShown() then
        if not Notebook.docked then
            place()
        end
        frame:Show()
    end
    Notebook.Refresh()
end

-- Opened by the player (a count line, the compartment, /kr): undocked unless « Suivre » holds it.
function Notebook.Open(skill)
    Notebook.Show(skill)
end

function Notebook.Close()
    if frame then
        frame:Hide()
    end
end

function Notebook.Toggle()
    if frame and frame:IsShown() then
        Notebook.Close()
    else
        Notebook.Open()
    end
end

function Notebook.IsShown()
    return frame ~= nil and frame:IsShown()
end

function Notebook.Select(spell)
    view.selected = spell
    Notebook.Refresh()
end

-- « Suivre » hangs the notebook on another frame (the professions window), or lets it go back to its place.
-- The grip let go: the size in whole units within the ranges, saved; docked, back on the professions window (sizing may
-- take the notebook off its anchor); else its place kept, as after a drag.
function Notebook.Resized()
    local o = ns.db.options
    local w, h = ns.DB.RANGES.width, ns.DB.RANGES.height
    o.width = math.max(w[1], math.min(w[2], math.floor(frame:GetWidth() + 0.5)))
    o.height = math.max(h[1], math.min(h[2], math.floor(frame:GetHeight() + 0.5)))
    if Notebook.docked and docking then
        Notebook.Dock(docking[1], docking[2])
    else
        local point, _, relPoint, x, y = frame:GetPoint()
        if point then
            ui().pos = { x, y, point, relPoint }
        end
    end
    Notebook.Refresh()
end

function Notebook.Dock(anchor, side)
    build()
    docking = anchor and { anchor, side } or nil
    if anchor then
        Notebook.docked = true
        frame:ClearAllPoints()
        if side == "left" then
            frame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
        else
            frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", side or 48, 0)
        end
    elseif Notebook.docked then
        Notebook.docked = false
        place()
    end
end

-- The hammer: Blizzard's own professions window on this profession, through its own entry point.
function Notebook.OpenProfessions()
    local skill = currentSkill()
    if not skill or InCombatLockdown() then
        return
    end
    if not OpenProfessionUIToSkillLine and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_Professions")
    end
    if OpenProfessionUIToSkillLine then
        OpenProfessionUIToSkillLine(skill)
    end
end

-- For the offline smoke test and the report.
function Notebook.Frame()
    return frame
end

function Notebook.View()
    return view
end

function Notebook.Start()
    ns.OnChange(Notebook.Refresh)
    ns.On("GET_ITEM_INFO_RECEIVED", function()
        ns.Later("notebookItems", Notebook.Refresh)
    end)
end
