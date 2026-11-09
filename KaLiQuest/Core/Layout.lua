-- What the tracker draws, top to bottom: the tree cut down to what's open, with each header's count. Pure, so the
-- tests can check what shows without any frames.
local _, ns = ...

local Layout = {}
ns.Layout = Layout

-- Done out of total, as a closed header keeps showing it.
function Layout.CountText(quests)
    local done = 0
    for _, q in ipairs(quests) do
        if q.complete then
            done = done + 1
        end
    end
    return done .. "/" .. #quests
end
local countText = Layout.CountText

-- A player's group is remembered by its ID, a header of the log by its text.
function Layout.GroupOpen(open, g)
    if g.group then
        return open.groups[g.group.id] == true
    end
    return open.headers[g.name] == true
end

-- tree: from Tree.Build, with tree.extra the other sections from Sections.Read. open: the saved open state.
-- view: while filtering or searching, { passes = fn(quest), searching = bool }, else nil. Hidden quests take their
-- empty groups and bars with them, counts become matches, moved lines go, and a search opens every level holding a
-- match without touching what's saved.
-- Each line is a bar, group, quest, moved or entry line. None while the tracker is collapsed. Bars and
-- groups carry the quests they show or hold. Also returns how many quests show and how many there are.
function Layout.Lines(tree, open, view)
    local lines = {}
    local shownTotal, total = 0, 0
    if not open.tracker then
        return lines, 0, 0
    end
    local searching = view and view.searching
    local function add(line)
        lines[#lines + 1] = line
    end
    local function visible(list)
        if not view then
            return list
        end
        local out = {}
        for _, q in ipairs(list) do
            if view.passes(q) then
                out[#out + 1] = q
            end
        end
        return out
    end
    local function countOf(list)
        return view and tostring(#list) or countText(list)
    end

    -- Each group's visible quests, and the groups left to show.
    local function prepare(cat)
        local groups, all = {}, {}
        for _, g in ipairs(cat.groups) do
            local shown = visible(g.quests)
            total = total + #g.quests
            shownTotal = shownTotal + #shown
            if not view or #shown > 0 then
                groups[#groups + 1] = { g = g, shown = shown }
                for _, q in ipairs(shown) do
                    all[#all + 1] = q
                end
            end
        end
        return groups, all
    end

    local function groups(cat, list)
        for _, entry in ipairs(list) do
            local g = entry.g
            local isOpen = searching or Layout.GroupOpen(open, g)
            -- A header left with only moved quests' lines has nothing to count.
            add({ kind = "group", key = g.key, group = g.group, name = g.name, cat = cat.id, open = isOpen, quests = entry.shown,
                count = (g.group or #entry.shown > 0) and countOf(entry.shown) or "" })
            if isOpen then
                if g.group or view then
                    for n, q in ipairs(entry.shown) do
                        add({ kind = "quest", quest = q, group = g.group, last = n == #entry.shown })
                    end
                else
                    for n, e in ipairs(g.entries) do
                        add({ kind = e.moved and "moved" or "quest", quest = e.quest, last = n == #g.entries })
                    end
                end
            end
        end
    end

    -- Suivi shows with no groups too, so its + can start the first one.
    local mine = tree[1]
    local mineGroups, mineQuests = prepare(mine)
    if not view or #mineQuests > 0 then
        add({ kind = "bar", id = "mine", top = true, open = searching or open.categories.mine == true, quests = mineQuests,
            count = (#mineQuests > 0 or #mine.groups > 0) and countOf(mineQuests) or "" })
        if searching or open.categories.mine then
            groups(mine, mineGroups)
        end
    end

    local sections, journalQuests = {}, {}
    for i = 2, #tree do
        local list, all = prepare(tree[i])
        if not view or #all > 0 then
            sections[#sections + 1] = { cat = tree[i], groups = list, all = all }
            for _, q in ipairs(all) do
                journalQuests[#journalQuests + 1] = q
            end
        end
    end
    if #sections > 0 then
        add({ kind = "bar", id = "journal", top = true, open = searching or open.categories.journal == true, quests = journalQuests,
            count = #journalQuests > 0 and countOf(journalQuests) or "" })
        if searching or open.categories.journal then
            for _, s in ipairs(sections) do
                local catOpen = searching or open.categories[s.cat.id] == true
                add({ kind = "bar", id = s.cat.id, top = false, open = catOpen, quests = s.all, count = #s.all > 0 and countOf(s.all) or "" })
                if catOpen then
                    groups(s.cat, s.groups)
                end
            end
        end
    end
    -- Tracked recipes and achievements, below Journal, open until closed. They aren't quests, so a search or a
    -- filter hides them.
    if not view then
        for _, extra in ipairs(tree.extra or {}) do
            local isOpen = open.categories[extra.id] ~= false
            add({ kind = "bar", id = extra.id, top = true, extra = true, open = isOpen, count = tostring(#extra.entries) })
            if isOpen then
                for n, e in ipairs(extra.entries) do
                    add({ kind = "entry", entry = e, last = n == #extra.entries })
                end
            end
        end
    end
    return lines, shownTotal, total
end
