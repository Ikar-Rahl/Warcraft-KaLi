local T = KaLiQuestTests
local ns = KaLiQuestDev.ns

local function quest(id, header, category, kind)
    return { id = id, title = "Q" .. id, level = 10, header = header, category = category, headerKind = kind }
end

local function sample()
    local list = {
        quest(1, "Forêt d'Elwynn", "world", "zone"),
        quest(2, "Marche de l'Ouest", "world", "zone"),
        quest(3, "Les Mortemines", "instances", "instance"),
        quest(4, "Forgeron", "classprof", "profession"),
        quest(5, "Guerrier", "classprof", "ownclass"),
        quest(6, "Marche de l'Ouest", "world", "zone"),
        quest(7, "Cavernes des lamentations", "instances", "instance"),
    }
    local quests, order = {}, {}
    for _, q in ipairs(list) do
        quests[q.id] = q
        order[#order + 1] = q.id
    end
    return quests, order
end

local function names(cat)
    local out = {}
    for _, g in ipairs(cat.groups) do
        out[#out + 1] = g.name
    end
    return out
end

T.Add("Tree", "Suivi first, then Journal's categories with quests, in order", function()
    local quests, order = sample()
    local tree = ns.Tree.Build(quests, order, {}, "Marche de l'Ouest")
    local ids = {}
    for _, cat in ipairs(tree) do
        ids[#ids + 1] = cat.id
    end
    T.List(ids, { "mine", "world", "classprof", "instances" }, "empty categories don't show")
end)

T.Add("Tree", "the current zone comes first in Monde", function()
    local quests, order = sample()
    local tree = ns.Tree.Build(quests, order, {}, "Marche de l'Ouest")
    T.List(names(tree[2]), { "Marche de l'Ouest", "Forêt d'Elwynn" }, "zone first")
end)

T.Add("Tree", "Monde's other zones are alphabetical, as the game re-sorts its log for the map it shows", function()
    local quests, order = {}, {}
    for i, header in ipairs({ "Marche de l'Ouest", "Sombrivage (Darkshore)", "Forêt d'Elwynn", "Bois de la Pénombre" }) do
        quests[i], order[i] = quest(i, header, "world", "zone"), i
    end
    T.List(names(ns.Tree.Build(quests, order, {}, "Forêt d'Elwynn")[2]),
        { "Forêt d'Elwynn", "Bois de la Pénombre", "Marche de l'Ouest", "Sombrivage (Darkshore)" }, "the zone you're in, then the rest")
    T.List(names(ns.Tree.Build(quests, order, {}, "Ailleurs")[2]),
        { "Bois de la Pénombre", "Forêt d'Elwynn", "Marche de l'Ouest", "Sombrivage (Darkshore)" }, "in a zone with no quest")
end)

T.Add("Tree", "the player's class comes first in Classe et métiers, dungeons alphabetical", function()
    local quests, order = sample()
    local tree = ns.Tree.Build(quests, order, {}, "")
    T.List(names(tree[3]), { "Guerrier", "Forgeron" }, "class first")
    T.List(names(tree[4]), { "Cavernes des lamentations", "Les Mortemines" }, "alphabetical")
end)

T.Add("Tree", "a quest in a group leaves a moved entry in its section", function()
    local quests, order = sample()
    local groups = { { id = 1, name = "A", quests = { 6, 99 } } }
    local tree = ns.Tree.Build(quests, order, groups, "Marche de l'Ouest")
    T.Eq(#tree[1].groups[1].quests, 1, "the group shows only quests in the log")
    local west = tree[2].groups[1]
    T.Eq(#west.entries, 2, "two entries")
    T.Eq(west.entries[2].moved, true, "6 is marked moved")
    T.Eq(#west.quests, 1, "one quest left to draw")
end)

T.Add("Tree", "the text view lists every level", function()
    local quests, order = sample()
    local text = ns.Tree.Text(ns.Tree.Build(quests, order, { { id = 1, name = "A", quests = { 1 } } }, ""))
    T.True(text:find("A", 1, true) and text:find("#1", 1, true) and text:find("~ [10] Q1", 1, true), text)
end)

T.Add("Tree", "alphabetical order ignores accents and case", function()
    local list = {
        quest(1, "Solstice d'été", "events", "event"),
        quest(2, "Éruption de Blackrock", "events", "event"),
        quest(3, "foire de Sombrelune", "events", "event"),
        quest(4, "Fête lunaire", "events", "event"),
    }
    local quests, order = {}, {}
    for _, q in ipairs(list) do
        quests[q.id] = q
        order[#order + 1] = q.id
    end
    local tree = ns.Tree.Build(quests, order, {}, "")
    T.List(names(tree[2]), { "Éruption de Blackrock", "Fête lunaire", "foire de Sombrelune", "Solstice d'été" }, "É with the E's")
end)

T.Add("Tree", "a saved category order missing a category still shows it", function()
    local quests, order = sample()
    local tree = ns.Tree.Build(quests, order, {}, "", { "instances", "world" })
    local ids = {}
    for _, cat in ipairs(tree) do
        ids[#ids + 1] = cat.id
    end
    T.List(ids, { "mine", "instances", "world", "classprof" }, "the saved order first, then the rest")
end)

T.Add("Tree", "a quest listed before any header goes under Divers", function()
    local quests, order = { [1] = quest(1, nil, "misc", "none") }, { 1 }
    local tree = ns.Tree.Build(quests, order, {}, "")
    T.List(names(tree[2]), { ns.G("MISCELLANEOUS", "Divers") }, "named")
end)
