-- The tracker's tree, from the log and the player's groups: Suivi's groups, then Journal's categories, each
-- with its headers. Pure, so the UI and /kq tree draw the same thing and tests can check it.
local _, ns = ...

local Tree = {}
ns.Tree = Tree

local function byName(a, b)
    return ns.TextLess(a.name, b.name)
end

-- The log's header, or Divers for a quest listed before any header.
function Tree.HeaderName(q)
    if q.header == nil or q.header == "" then
        return ns.G("MISCELLANEOUS", "Divers")
    end
    return q.header
end

-- The saved order, then any category it doesn't name, so none goes missing.
local function fullOrder(categoryOrder, byCategory)
    local order, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    for _, id in ipairs(categoryOrder or {}) do
        add(id)
    end
    for _, id in ipairs(ns.Categories.ORDER) do
        add(id)
    end
    local rest = {}
    for id in pairs(byCategory) do
        if not seen[id] then
            rest[#rest + 1] = id
        end
    end
    table.sort(rest)
    for _, id in ipairs(rest) do
        add(id)
    end
    return order
end

-- quests: records by ID. order: IDs in log order. groups: the saved groups. zone: the current zone's name.
-- categoryOrder: Journal's order, or nil for the default.
function Tree.Build(quests, order, groups, zone, categoryOrder)
    local placed = {}
    local mine = { id = "mine", groups = {} }
    for _, g in ipairs(groups) do
        local list = {}
        for _, id in ipairs(g.quests) do
            placed[id] = true
            if quests[id] then
                list[#list + 1] = quests[id]
            end
        end
        mine.groups[#mine.groups + 1] = { key = "g" .. g.id, group = g, name = g.name, quests = list }
    end

    -- A quest in one of the player's groups leaves an entry where it would have been.
    local byCategory = {}
    for _, id in ipairs(order) do
        local q = quests[id]
        local headers = byCategory[q.category]
        if not headers then
            headers = { list = {}, byName = {} }
            byCategory[q.category] = headers
        end
        local name = Tree.HeaderName(q)
        local h = headers.byName[name]
        if not h then
            h = { key = "h" .. name, name = name, quests = {}, entries = {}, kind = q.headerKind, headerKey = q.headerKey }
            headers.byName[name] = h
            headers.list[#headers.list + 1] = h
        end
        h.entries[#h.entries + 1] = { quest = q, moved = placed[id] == true }
        if not placed[id] then
            h.quests[#h.quests + 1] = q
        end
    end

    local tree = { mine }
    for _, id in ipairs(fullOrder(categoryOrder, byCategory)) do
        local headers = byCategory[id] and byCategory[id].list or {}
        if id == "world" then
            -- The zone you're in first, the rest alphabetical: the game re-sorts its log for the map it shows.
            table.sort(headers, function(a, b)
                local az, bz = a.name == zone, b.name == zone
                if az ~= bz then
                    return az
                end
                return ns.TextLess(a.name, b.name)
            end)
        elseif id == "classprof" then
            table.sort(headers, function(a, b)
                local ao, bo = a.kind == "ownclass", b.kind == "ownclass"
                if ao ~= bo then
                    return ao
                end
                return ns.TextLess(a.name, b.name)
            end)
        else
            table.sort(headers, byName)
        end
        if #headers > 0 then
            tree[#tree + 1] = { id = id, groups = headers }
        end
    end
    return tree
end

-- A plain-text view, for /kq tree and for reading the tree in tests.
function Tree.Text(tree, isWatched)
    local lines = {}
    for _, cat in ipairs(tree) do
        lines[#lines + 1] = ns.CategoryName(cat.id)
        for _, g in ipairs(cat.groups) do
            lines[#lines + 1] = "    " .. g.name .. (g.kind and ("  (" .. g.kind .. ")") or "")
            for _, e in ipairs(g.entries or {}) do
                local q = e.quest
                lines[#lines + 1] = string.format("        %s[%d] %s  #%d", e.moved and "~ " or "", q.level or 0, q.title or "?", q.id)
            end
            if not g.entries then
                for _, q in ipairs(g.quests) do
                    local mark = isWatched and not isWatched(q.id) and "  (" .. ns.L.PAST_LIMIT_SHORT .. ")" or ""
                    lines[#lines + 1] = string.format("        [%d] %s  #%d%s", q.level or 0, q.title or "?", q.id, mark)
                end
            end
        end
    end
    return table.concat(lines, "\n")
end
