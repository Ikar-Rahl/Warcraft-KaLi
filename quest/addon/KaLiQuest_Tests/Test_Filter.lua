local T = KaLiQuestTests
local ns = KaLiQuestDev.ns
local Filter = ns.Filter

T.Add("Filter", "a search needs every word, in any order, ignoring case and accents", function()
    local text = Filter.Plain("Les Champs de MORT — Éliminez 10 gnolls")
    T.True(Filter.Matches(text, "gnolls mort"), "two words in any order")
    T.True(Filter.Matches(text, "eliminez"), "accent folded")
    T.True(not Filter.Matches(text, "mort kobolds"), "one word missing fails")
    T.True(not Filter.Matches(text, "   "), "spaces only match nothing")
end)

T.Add("Filter", "a search reads text, not codes, and takes ( and % literally", function()
    local text = Filter.Plain("|cffff0000Rouge|r |Hitem:5000|h[Masque]|h |TInterface\\Icons\\X:0|t (50%)")
    T.True(Filter.Matches(text, "rouge masque"), "colour and link codes gone")
    T.True(not Filter.Matches(text, "ffff0000"), "the colour code itself isn't searched")
    T.True(not Filter.Matches(text, "icons"), "nor a texture path")
    T.True(Filter.Matches(text, "(50%)"), "magic characters are plain")
end)

T.Add("Filter", "ticks in one category are any of, across categories all of", function()
    local traits = { ["repeat"] = { daily = true }, state = { progress = true } }
    T.True(Filter.Passes(traits, {}), "nothing ticked lets everything through")
    T.True(Filter.Passes(traits, { ["repeat"] = { daily = true, weekly = true } }), "daily or weekly")
    T.True(not Filter.Passes(traits, { ["repeat"] = { weekly = true } }), "weekly only")
    T.True(not Filter.Passes(traits, { ["repeat"] = { daily = true }, state = { ready = true } }), "daily and ready")
    T.True(Filter.Passes(traits, { ["repeat"] = { daily = true }, state = {} }), "an emptied category is ignored")
    T.True(Filter.Active({ state = { ready = true } }) and not Filter.Active({ state = {} }), "active only with a tick")
end)

T.Add("Filter", "the menu lists categories with a choice, in order, with counts", function()
    local all = {
        [1] = { ["repeat"] = { daily = true }, size = { size5 = true }, state = { progress = true } },
        [2] = { ["repeat"] = { once = true }, size = { size10 = true }, state = { progress = true } },
        [3] = { ["repeat"] = { daily = true }, size = { size2 = true }, state = { progress = true } },
    }
    local menu = Filter.MenuEntries(all, {})
    local ids = {}
    for _, cat in ipairs(menu) do
        ids[#ids + 1] = cat.id
    end
    T.List(ids, { "size", "repeat" }, "state has one value, so it's left out")
    T.List({ menu[1].entries[1].value, menu[1].entries[2].value, menu[1].entries[3].value }, { "size2", "size5", "size10" },
        "sizes sort by number")
    T.Eq(menu[2].entries[1].value .. menu[2].entries[1].count, "daily2", "daily first, counted")
    menu = Filter.MenuEntries(all, { state = { ready = true } })
    T.Eq(menu[3] and menu[3].id, "state", "a ticked category stays, so it can be unticked")
    T.Eq(menu[3].entries[2].value .. menu[3].entries[2].count, "ready0", "with its ticked value at 0")
    T.True(menu[3].entries[2].ticked, "shown ticked")
end)

T.Add("Filter", "every value has a label", function()
    -- ns.L gives back the key itself when a string is missing, so that's what a missing label looks like.
    local function real(label)
        return type(label) == "string" and label ~= "" and not label:find("^FILTER_")
    end
    for _, cat in ipairs(Filter.CATEGORIES) do
        T.True(real(Filter.CategoryLabel(cat.id)), "category " .. cat.id)
        for _, value in ipairs(cat.values or {}) do
            T.True(real(Filter.ValueLabel(value)), "value " .. value)
        end
    end
    T.True(not real(Filter.ValueLabel("nosuchvalue")), "a missing label is caught")
    T.Eq(Filter.ValueLabel("size5"), string.format(ns.L.FILTER_V_SIZE, 5), "group size")
    T.Eq(Filter.ValueLabel("tag21", { tag21 = "Classe" }), "Classe", "the game's own name")
end)

-- Layout under a view ------------------------------------------------------------------------------------------

local function quest(id, header, category, complete)
    return { id = id, title = "Q" .. id, level = 10, header = header, category = category, headerKind = "zone", complete = complete }
end

local function sample()
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
    return ns.Tree.Build(quests, order, { { id = 1, name = "A", quests = { 2 } } }, "Forêt d'Elwynn")
end

local function kinds(lines)
    local out = {}
    for _, line in ipairs(lines) do
        local what = line.id or line.name or (line.quest and line.quest.id)
        out[#out + 1] = line.kind .. ":" .. tostring(what)
    end
    return out
end

local function only(...)
    local keep = {}
    for i = 1, select("#", ...) do
        keep[select(i, ...)] = true
    end
    return function(q)
        return keep[q.id] == true
    end
end

T.Add("Filter", "a filter hides quests, their empty headers and bars, and counts what's left", function()
    local open = ns.DB.Load(nil).open
    open.categories.world = true
    open.headers["Forêt d'Elwynn"] = true
    local lines, shown, total = ns.Layout.Lines(sample(), open, { passes = only(1, 4) })
    T.List(kinds(lines), { "bar:mine", "bar:journal", "bar:world", "group:Forêt d'Elwynn", "quest:1", "bar:instances" },
        "Marche de l'Ouest goes, and the moved line with it")
    T.Eq(lines[2].count, "2", "a count is how many show")
    T.Eq(shown .. "/" .. total, "2/4", "two of four")
    T.True(not open.categories.instances, "a closed level stays closed")
end)

T.Add("Filter", "a filter keeps Suivi and the player's groups, to drag quests into, matches or not", function()
    local open = ns.DB.Load(nil).open
    open.categories.mine = true
    local tree = sample()
    tree[1].groups[2] = { key = "g2", group = { id = 2, name = "B", quests = {} }, name = "B", quests = {} }
    local lines = ns.Layout.Lines(tree, open, { passes = only(4) })
    T.List(kinds(lines), { "bar:mine", "group:A", "group:B", "bar:journal", "bar:instances" }, "both groups, A's quest hidden")
    T.Eq(lines[1].count .. " " .. lines[2].count .. " " .. lines[3].count, "0 0 0", "each counts its matches: none")
    T.True(not (lines[2].open or lines[3].open), "and stays as it was left, closed")
    lines = ns.Layout.Lines(sample(), ns.DB.Load(nil).open, { passes = only(4) })
    T.Eq(kinds(lines)[1], "bar:mine", "Suivi stays when closed too, to start a group on")
    open = ns.DB.Load(nil).open
    lines = ns.Layout.Lines(ns.Tree.Build({}, {}, {}, ""), open, { passes = only() })
    T.List(kinds(lines), { "bar:mine" }, "and with no group at all, for its +")
end)

T.Add("Filter", "a search opens every level holding a match, without saving it", function()
    local open = ns.DB.Load(nil).open
    local lines = ns.Layout.Lines(sample(), open, { passes = only(2, 4), searching = true })
    T.List(kinds(lines), { "bar:mine", "group:A", "quest:2", "bar:journal", "bar:instances", "group:Les Mortemines", "quest:4" },
        "all open")
    T.True(not (open.categories.mine or open.groups[1] or open.categories.instances), "nothing saved")
    lines = ns.Layout.Lines(sample(), open, { passes = only(4), searching = true })
    T.List(kinds(lines), { "bar:mine", "bar:journal", "bar:instances", "group:Les Mortemines", "quest:4" },
        "Suivi, without a match, stays as it was left")
    open.categories.mine = true
    lines = ns.Layout.Lines(sample(), open, { passes = only(4), searching = true })
    T.Eq(kinds(lines)[2], "group:A", "Suivi left open shows its group")
    T.True(lines[2].open == false, "which, without a match, stays as it was left too")
end)
