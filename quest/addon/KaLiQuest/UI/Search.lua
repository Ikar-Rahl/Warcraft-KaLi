-- The title row's search and filter, the search box under the title, and the status line, from filter-search.md.
-- They only hide rows: nothing moves, no group changes, and what's open stays saved as it was. Refused in combat,
-- where secure item buttons couldn't follow; text typed as a fight starts applies when it ends.
local _, ns = ...
local L = ns.L
local Shared = ns.Tracker.Shared

local Search = {}
ns.Search = Search

local filterButton, searchButton, box, status, clearLink
local open = false
local query = "" -- as typed
local applied = "" -- as the rows show it: held while in combat

local function filters()
    return ns.db.filters
end

function Search.Searching()
    return ns.Filter.Searching(applied)
end

function Search.Filtering()
    return ns.Filter.Active(filters())
end

local function refusedInCombat()
    if InCombatLockdown() then
        Shared.refuse("combat")
        return true
    end
    return false
end

local function closeBox()
    open = false
    query = ""
    -- In combat the rows keep what they show until the fight ends, as with typed text.
    if not InCombatLockdown() then
        applied = ""
    end
    if box then
        box:SetText("")
        box:ClearFocus()
        box:Hide()
    end
    ns.RequestRefresh()
end

local function toggleBox()
    if refusedInCombat() then
        return
    end
    if open then
        closeBox()
        return
    end
    open = true
    box:Show()
    box:SetFocus()
    ns.RequestRefresh()
end

local function clearAll()
    if refusedInCombat() then
        return
    end
    wipe(filters())
    closeBox()
end

-- A quest's values for the filter, and the labels the game gives some of them, for the whole log.
local function traitsOfLog(quests)
    local ctx = { zone = GetZoneText(), inParty = IsInGroup() }
    local all, names = {}, {}
    for id, q in pairs(quests) do
        if not q.leaving then
            all[id] = ns.Filter.Traits(q, ctx, names)
        end
    end
    return all, names
end

local function filterMenu(owner)
    if refusedInCombat() then
        return
    end
    local quests = ns.QuestLog.Read(ns.categories.Classify)
    local all, names = traitsOfLog(quests)
    Shared.menu(owner, function(description)
        description:CreateTitle(ns.G("FILTER", "Filtre"))
        for _, cat in ipairs(ns.Filter.MenuEntries(all, filters())) do
            description:CreateTitle(ns.Filter.CategoryLabel(cat.id))
            for _, entry in ipairs(cat.entries) do
                local label = string.format("%s (%d)", ns.Filter.ValueLabel(entry.value, names), entry.count)
                description:CreateCheckbox(label, function()
                    local set = filters()[cat.id]
                    return set ~= nil and set[entry.value] == true
                end, Shared.guarded(function()
                    if refusedInCombat() then
                        return
                    end
                    local set = filters()[cat.id] or {}
                    filters()[cat.id] = set
                    set[entry.value] = not set[entry.value] or nil
                    if not next(set) then
                        filters()[cat.id] = nil
                    end
                    ns.RequestRefresh()
                end))
            end
        end
        description:CreateDivider()
        local clear = description:CreateButton(ns.G("CLEAR_ALL", "Tout effacer"), Shared.guarded(function()
            if refusedInCombat() then
                return
            end
            wipe(filters())
            ns.RequestRefresh()
        end))
        if clear.SetEnabled then
            clear:SetEnabled(Search.Filtering())
        end
    end)
end

-- A lit copy over a button's own art, as the gear's, for while its search or filter is active.
local function lit(b, atlas, size)
    b.Lit = b:CreateTexture(nil, "OVERLAY")
    b.Lit:SetAtlas(atlas, false)
    b.Lit:SetSize(size[1], size[2])
    b.Lit:SetPoint("CENTER")
    b.Lit:SetBlendMode("ADD")
    b.Lit:SetVertexColor(1, 0.82, 0)
    b.Lit:Hide()
end

-- Both are plain icons, as the gear, padlock and collapse arrow, Ikar's ruling on 2026-11-07: no red button.
local function plainButton(tools, atlas, size, x)
    local s = Shared
    local b = s.newFrame("Button", tools)
    b:SetSize(18, 18)
    b:SetPoint("RIGHT", x, 0)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAtlas(atlas, false)
    b.Icon:SetSize(size, size)
    b.Icon:SetPoint("CENTER")
    -- Hover adds a copy on top, as Blizzard's highlights do, since a colour above 1 doesn't brighten.
    b.Bright = b:CreateTexture(nil, "HIGHLIGHT")
    b.Bright:SetAtlas(atlas, false)
    b.Bright:SetSize(size, size)
    b.Bright:SetPoint("CENTER")
    b.Bright:SetBlendMode("ADD")
    b.Bright:SetAlpha(0.3)
    lit(b, atlas, { size, size })
    b:SetScript("OnLeave", s.guarded(s.hideTip))
    return b
end

local function hoverTip(text)
    return Shared.guarded(function(self)
        Shared.wake()
        Shared.simpleTip(self, text)
    end)
end

function Search.BuildButtons(tools)
    local s = Shared
    filterButton = plainButton(tools, "gamepad-hud-icon-filter", 14, -21)
    filterButton:SetScript("OnClick", s.guarded(filterMenu))
    filterButton:SetScript("OnEnter", hoverTip(ns.G("FILTER", "Filtre")))

    searchButton = plainButton(tools, "common-search-magnifyingglass", 16, -41)
    searchButton:SetScript("OnClick", s.guarded(toggleBox))
    searchButton:SetScript("OnEnter", hoverTip(ns.G("SEARCH", "Recherche")))
    return filterButton, searchButton
end

function Search.DrawButtons()
    local edit = Shared.EditMode()
    filterButton.Lit:SetShown(Search.Filtering())
    searchButton.Lit:SetShown(open or Search.Searching())
    filterButton:EnableMouse(not edit)
    searchButton:EnableMouse(not edit)
end

function Search.Build(fixed)
    local s = Shared
    box = s.newFrame("EditBox", fixed, "SearchBoxTemplate")
    box:SetAutoFocus(false)
    box:SetHeight(20)
    box:SetMaxLetters(60)
    box:HookScript("OnTextChanged", s.guarded(function(self)
        query = self:GetText() or ""
        -- In combat the rows keep what they show; the text applies when the fight ends.
        if not InCombatLockdown() then
            applied = query
        end
        ns.RequestRefresh()
    end))
    box:SetScript("OnEscapePressed", s.guarded(closeBox))
    box:SetScript("OnEnterPressed", s.guarded(function(self)
        self:ClearFocus()
    end))
    if box.clearButton then
        box.clearButton:HookScript("OnClick", s.guarded(closeBox))
    end
    box:Hide()

    status = fixed:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.784, 0.784, 0.784)
    clearLink = s.newFrame("Button", fixed)
    clearLink:SetHeight(12)
    clearLink.Text = clearLink:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    clearLink.Text:SetPoint("LEFT")
    clearLink.Text:SetText(ns.G("CLEAR_ALL", "Tout effacer"))
    clearLink:SetScript("OnClick", s.guarded(clearAll))
    clearLink:SetScript("OnEnter", s.guarded(function(self)
        s.wake()
        self.Text:SetTextColor(1, 1, 1)
    end))
    clearLink:SetScript("OnLeave", s.guarded(function(self)
        self.Text:SetTextColor(1, 0.82, 0)
    end))

    ns.On("PLAYER_REGEN_ENABLED", function()
        if applied ~= query then
            applied = query
            ns.RequestRefresh()
        end
    end)
end

-- While searching or filtering, which quests pass. nil otherwise, so the tree shows as saved.
function Search.View(tree, quests)
    local searching = Search.Searching()
    local filtering = Search.Filtering()
    if not (searching or filtering) then
        return nil
    end
    local traits, names = traitsOfLog(quests)
    local groupName = {}
    for _, g in ipairs(tree[1] and tree[1].groups or {}) do
        for _, q in ipairs(g.quests) do
            groupName[q.id] = g.name
        end
    end
    local cache = {}
    local function passes(q)
        if q.leaving then
            return false
        end
        local cached = cache[q.id]
        if cached ~= nil then
            return cached
        end
        local t = traits[q.id] or {}
        local ok = ns.Filter.Passes(t, filters())
        if ok and searching then
            local lines = {}
            for i = 1, q.logIndex and GetNumQuestLeaderBoards(q.logIndex) or 0 do
                lines[#lines + 1] = (GetQuestLogLeaderBoard(i, q.logIndex))
            end
            ok = ns.Filter.Matches(ns.Filter.SearchText(q, groupName[q.id], t, lines, names), applied)
        end
        cache[q.id] = ok
        return ok
    end
    return { passes = passes, searching = searching }
end

-- The search box, then the status line while anything is hidden, from top down. Returns the height used.
function Search.Layout(fixed, hiding, shownCount, totalCount, top)
    local width = Shared.Width()
    top = top or 0
    local y = top
    if open then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", fixed, "TOPLEFT", 7, -y)
        box:SetWidth(width - 14)
        box:Show()
        y = y + 20 + 4
    else
        box:Hide()
    end
    if hiding then
        y = y + 2
        local text
        if shownCount == 0 then
            text = ns.G("QUEST_LOG_NO_RESULTS", "Aucun résultat trouvé")
        else
            text = string.format(shownCount > 1 and L.SHOWN_MANY or L.SHOWN_ONE, shownCount, totalCount)
        end
        status:SetText(text .. " · ")
        status:ClearAllPoints()
        status:SetPoint("TOPLEFT", fixed, "TOPLEFT", 7, -y)
        status:Show()
        clearLink:Show()
        clearLink:ClearAllPoints()
        clearLink:SetPoint("TOPLEFT", fixed, "TOPLEFT", 7 + status:GetStringWidth(), -y)
        clearLink:SetWidth(clearLink.Text:GetStringWidth() + 2)
        clearLink:EnableMouse(not Shared.EditMode())
        y = y + (status:GetStringHeight() or 12) + 6
    else
        status:Hide()
        clearLink:Hide()
    end
    return y - top
end

-- For the offline smoke test.
function Search.State()
    return { open = open, query = query, applied = applied, box = box, status = status, clear = clearLink,
        filterButton = filterButton, searchButton = searchButton }
end
