-- « Carnet : 7 à apprendre · 4 vues » under the rank bar of the professions window (A1) and under each profession in
-- the professions book (A2), shown at zero too unless the option says otherwise. Each is the addon's own small
-- button, anchored to Blizzard's bar and shown with it through script post-hooks: nothing is written to Blizzard's
-- frames. A click opens the notebook on that profession.
local _, ns = ...
local L = ns.L
local W = ns.Widgets

local CountLines = {}
ns.CountLines = CountLines

local function white(text)
    return (text:gsub("^(%d+)", "|cffffffff%1|r"))
end

-- The line's text and its two numbers, for a profession; for one this character lacks, only « vues ».
function CountLines.Text(m, skill)
    local learn, seen = m:Counts(m.me, skill)
    local seenText = white(ns.Plural(seen, L.SEEN_ONE, L.SEEN_MANY))
    if not m:HasProf(m.me, skill) then
        return L.CARNET_PREFIX .. seenText, learn, seen
    end
    return L.CARNET_PREFIX .. white(string.format(L.TO_LEARN, learn)) .. " · " .. seenText, learn, seen
end

local function tooltip(self)
    local m, skill = ns.book, self.skill
    if not skill then
        return
    end
    local learn, seen = m:Counts(m.me, skill)
    local lines = {}
    if m:HasProf(m.me, skill) then
        lines[1] = { string.format(learn == 1 and L.LEARN_TIP_ONE or L.LEARN_TIP_MANY, learn, ns.Game.ProfName(skill)) }
        lines[2] = { ns.Plural(seen, L.SEEN_TIP_ONE, L.SEEN_TIP_MANY) }
    else
        lines[1] = { ns.Plural(seen, L.SEEN_OTHER_TIP_ONE, L.SEEN_OTHER_TIP_MANY) }
    end
    lines[#lines + 1] = { " " }
    lines[#lines + 1] = { L.CLICK_OPEN, { 0.1, 1, 0.1 } }
    W.TextTooltip(self, L.NOTEBOOK, lines, "ANCHOR_BOTTOM")
end

local function makeLine()
    local b = W.Frame("Button", UIParent)
    b:SetFrameStrata("HIGH")
    b:SetSize(240, 14)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints()
    b.text:SetTextColor(0.7, 0.7, 0.7)
    b:SetScript("OnClick", function(self)
        ns.SafeCall(function()
            if self.skill then
                ns.Notebook.Open(self.skill)
            elseif self.others then
                ns.Notebook.Open(ns.book:Others(ns.book.me)[1])
            end
        end)
    end)
    b:SetScript("OnEnter", function(self)
        ns.SafeCall(tooltip, self)
    end)
    b:SetScript("OnLeave", W.HideTooltip)
    b:Hide()
    return b
end

-- Shows the line for a skill, or hides it: the option, the anchor's visibility and « Afficher aussi à zéro ».
local function show(line, skill, visible, option)
    local o = ns.db.options
    if not (visible and skill and o[option] and ns.book) then
        line:Hide()
        return
    end
    local text, learn, seen = CountLines.Text(ns.book, skill)
    if learn + seen == 0 and not o.showZero then
        line:Hide()
        return
    end
    line.skill = skill
    line.text:SetText(text)
    line:Show()
end

-- ---------- A1: the professions window ----------

local windowLine
local function refreshWindow()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local bar = page and page.RankBar
    if not bar then
        return
    end
    windowLine = windowLine or makeLine()
    windowLine:ClearAllPoints()
    windowLine:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    windowLine.text:SetJustifyH("CENTER")
    show(windowLine, ns.Game.OpenSkill(), ProfessionsFrame:IsVisible() and page:IsVisible() and bar:IsVisible(), "a1")
end

-- ---------- A2: the professions book, standalone and inside the professions window ----------

local SLOTS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" }
local books = {} -- [book frame] = { lines = { [slot] = line }, others = line }

local function refreshBook(book)
    local entry = books[book]
    local content = book.ProfessionsContentFrame
    if not (entry and content) then
        return
    end
    local visible = book:IsVisible()
    for _, key in ipairs(SLOTS) do
        local slot = content[key]
        if slot and slot.StatusBar then
            local line = entry.lines[key] or makeLine()
            entry.lines[key] = line
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", slot.StatusBar, "BOTTOMLEFT", 0, -2)
            line.text:SetJustifyH("LEFT")
            local skill = slot.skillLine and ns.Game.Skill(slot.skillLine, slot.skillName)
            show(line, skill, visible and slot:IsVisible() and slot.StatusBar:IsVisible(), "a2")
        end
    end
    -- The professions this character lacks: one line, for what was seen of them.
    local anchor = content.SecondaryProfession1
    if anchor then
        entry.others = entry.others or makeLine()
        local line = entry.others
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 8, -4)
        line.text:SetJustifyH("LEFT")
        local n = ns.book and ns.book:OtherSeen(ns.book.me) or 0
        if visible and ns.db.options.a2 and (n > 0 or ns.db.options.showZero) then
            line.skill, line.others = nil, true
            line.text:SetText(string.format(L.OTHERS_LINE, white(ns.Plural(n, L.SEEN_ONE, L.SEEN_MANY))))
            line:Show()
        else
            line:Hide()
        end
    end
end

local function hideBook(book)
    local entry = books[book]
    for _, line in pairs(entry and entry.lines or {}) do
        line:Hide()
    end
    if entry and entry.others then
        entry.others:Hide()
    end
end

local function watchBook(book)
    if not book or books[book] then
        return
    end
    books[book] = { lines = {} }
    book:HookScript("OnShow", function()
        ns.Later("book", function()
            refreshBook(book)
        end)
    end)
    book:HookScript("OnHide", function()
        ns.SafeCall(hideBook, book)
    end)
end

local hookedWindow = false
local function watchWindow()
    if hookedWindow or not (ProfessionsFrame and ProfessionsFrame.CraftingPage) then
        return
    end
    hookedWindow = true
    local function later()
        ns.Later("countWindow", refreshWindow)
    end
    ProfessionsFrame:HookScript("OnShow", later)
    ProfessionsFrame:HookScript("OnHide", later)
    ProfessionsFrame.CraftingPage:HookScript("OnShow", later)
    ProfessionsFrame.CraftingPage:HookScript("OnHide", later)
    watchBook(ProfessionsFrame.BookPage)
end

function CountLines.Refresh()
    refreshWindow()
    for book in pairs(books) do
        if book:IsVisible() then
            refreshBook(book)
        else
            hideBook(book)
        end
    end
end

function CountLines.Start()
    watchWindow()
    watchBook(ProfessionsBookFrame)
    ns.On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_Professions" then
            watchWindow()
        elseif name == "Blizzard_ProfessionsBook" then
            watchBook(ProfessionsBookFrame)
        end
    end)
    for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED" }) do
        ns.On(event, function()
            ns.Later("countLines", CountLines.Refresh)
        end)
    end
    ns.On("TRADE_SKILL_CLOSE", function()
        ns.Later("countLines", CountLines.Refresh)
    end)
    ns.OnChange(CountLines.Refresh)
end
