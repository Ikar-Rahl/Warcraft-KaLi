local T = KaLiQuestTests
local ns = KaLiQuestDev.ns

local function quest(id, header, category, complete)
    return { id = id, title = "Q" .. id, level = 10, header = header, category = category, headerKind = "zone", complete = complete }
end

-- Two zones and a dungeon, with group A holding quest 2.
local function sample(groups)
    local list = {
        quest(1, "Forêt d'Elwynn", "world", true),
        quest(2, "Forêt d'Elwynn", "world"),
        quest(3, "Marche de l'Ouest", "world"),
        quest(4, "Les Mortemines", "instances"),
    }
    local quests, order = {}, {}
    for _, q in ipairs(list) do
        quests[q.id] = q
        order[#order + 1] = q.id
    end
    return ns.Tree.Build(quests, order, groups or { { id = 1, name = "A", quests = { 2 } } }, "Forêt d'Elwynn")
end

local function fresh()
    return ns.DB.Load(nil).open
end

local function kinds(lines)
    local out = {}
    for _, line in ipairs(lines) do
        local what = line.id or line.name or (line.quest and line.quest.id)
        out[#out + 1] = line.kind .. ":" .. tostring(what)
    end
    return out
end

T.Add("Layout", "at first everything is closed except Journal, so its categories show", function()
    local lines = ns.Layout.Lines(sample(), fresh())
    T.List(kinds(lines), { "bar:mine", "bar:journal", "bar:world", "bar:instances" }, "bars only")
    T.Eq(lines[1].count, "0/1", "Suivi counts its quests")
    T.Eq(lines[2].count, "1/3", "Journal counts done out of the rest")
end)

T.Add("Layout", "an open group shows its quests, the last one marked", function()
    local open = fresh()
    open.categories.mine = true
    open.groups[1] = true
    local lines = ns.Layout.Lines(sample(), open)
    T.List(kinds(lines), { "bar:mine", "group:A", "quest:2", "bar:journal", "bar:world", "bar:instances" }, "quest under its group")
    T.Eq(lines[3].last, true, "last in its group")
    T.Eq(lines[2].group.id, 1, "the player's group")
end)

T.Add("Layout", "a header holding a moved quest shows a moved line in its place", function()
    local open = fresh()
    open.categories.world = true
    open.headers["Forêt d'Elwynn"] = true
    local lines = ns.Layout.Lines(sample(), open)
    T.List(kinds(lines), { "bar:mine", "bar:journal", "bar:world", "group:Forêt d'Elwynn", "quest:1", "moved:2",
        "group:Marche de l'Ouest", "bar:instances" }, "moved line in log order")
    T.Eq(lines[4].count, "1/1", "the moved quest isn't counted")
    T.Eq(lines[6].last, true, "the moved line closes the list")
end)

T.Add("Layout", "bars and groups carry the quests they hold, open or closed, moved ones in their group only", function()
    local open = fresh()
    open.categories.world = true
    local lines = ns.Layout.Lines(sample(), open)
    local function ids(line)
        local out = {}
        for _, q in ipairs(line.quests or {}) do
            out[#out + 1] = q.id
        end
        return out
    end
    T.List(ids(lines[1]), { 2 }, "Suivi")
    T.List(ids(lines[2]), { 1, 3, 4 }, "Journal")
    T.List(ids(lines[3]), { 1, 3 }, "Monde")
    T.List(ids(lines[4]), { 1 }, "a closed zone group, without the moved quest")
end)

T.Add("Layout", "a header left with only moved quests has no count", function()
    local open = fresh()
    open.categories.world = true
    local lines = ns.Layout.Lines(sample({ { id = 1, name = "A", quests = { 3 } } }), open)
    T.Eq(lines[5].name, "Marche de l'Ouest", "the header still shows")
    T.Eq(lines[5].count, "", "with nothing to count")
end)

T.Add("Layout", "Suivi shows with no groups, and an empty group counts 0/0", function()
    local lines = ns.Layout.Lines(sample({}), fresh())
    T.Eq(lines[1].kind .. lines[1].id, "barmine", "Suivi first")
    T.Eq(lines[1].count, "", "nothing to count")
    local open = fresh()
    open.categories.mine = true
    lines = ns.Layout.Lines(sample({ { id = 1, name = "A", quests = {} } }), open)
    T.Eq(lines[2].count, "0/0", "empty group")
end)

T.Add("Layout", "closing Journal hides its categories, collapsing the tracker hides everything", function()
    local open = fresh()
    open.categories.journal = false
    T.List(kinds(ns.Layout.Lines(sample(), open)), { "bar:mine", "bar:journal" }, "Journal closed")
    open.tracker = false
    T.Eq(#ns.Layout.Lines(sample(), open), 0, "nothing under a collapsed title")
end)
