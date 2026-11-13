local T = KaLiRecipeTests
local ns = KaLiRecipeDev.ns
local L = ns.L
local R, I = T.R, T.ITEM

local function plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function texts(lines)
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = line[1] .. (line[2] and (" | " .. line[2]) or "")
    end
    return out
end

local function has(lines, text)
    for _, line in ipairs(texts(lines)) do
        if line == text then
            return true
        end
    end
    return false
end

T.Add("Text", "dates: the day and the month's short name", function()
    local t = time({ year = 2026, month = 11, day = 9, hour = 12 })
    T.Eq(ns.Text.Date(t), string.format(L.DATE, 9, L.MONTHS[11]), "9 nov.")
    T.Eq(ns.Text.Date(nil), "?", "no date")
end)

T.Add("Text", "where a recipe was seen, with the names the game gave", function()
    local m, db = T.NewBook()
    ns.DB.SetName(db, "npc", 4223, "Ellandrieth")
    T.Eq(ns.Text.Where(m, T.Vendor()), string.format(L.WHERE_VENDOR, "Ellandrieth", "Darnassus"), "a vendor")
    T.Eq(ns.Text.Where(m, { k = "trainer", map = 1438 }), string.format(L.WHERE_TRAINER, L.SOMEONE, "Teldrassil"), "a trainer never named")
    T.Eq(ns.Text.Where(m, { k = "drop", npc = 4223 }), string.format(L.WHERE_DROP, "Ellandrieth", L.SOMEWHERE), "no map")
    T.Eq(ns.Text.Where(m, { k = "quest", q = 1 }), string.format(L.WHERE_QUEST, L.A_QUEST), "a quest never named")
    local limited, unlimited = T.Vendor(), T.Vendor()
    limited.stock, unlimited.stock = 0, -1
    T.Eq(ns.Text.Where(m, limited), string.format(L.WHERE_VENDOR, "Ellandrieth " .. ns.Text.CLOCK_MARKUP, "Darnassus"),
        "a vendor whose stock was limited: the grey clock after the name, sold out or not")
    T.Eq(ns.Text.Where(m, unlimited), string.format(L.WHERE_VENDOR, "Ellandrieth", "Darnassus"), "no limit: no clock")
    T.Eq(ns.Text.Where(m, { k = "trainer", npc = 4223, map = 1457, stock = 1 }), string.format(L.WHERE_TRAINER, "Ellandrieth", "Darnassus"),
        "only vendors have one")
    T.Eq(ns.Text.Held(1, 0) .. "|" .. ns.Text.Held(0, 2) .. "|" .. ns.Text.Held(1, 2), L.BAGS .. "|" .. L.BANK .. "|" .. L.BAGS .. L.AND .. L.BANK,
        "bags, bank, both")
    T.Eq(ns.Text.HeldIn(0, 1, false), L.HIS_BANK, "another character's bank")
end)

T.Add("Chat", "one line per visit: the count, the place, three links and the rest", function()
    local m, db = T.NewBook()
    ns.DB.SetName(db, "npc", 4223, "Ellandrieth")
    local link = function(spell)
        return "[" .. spell .. "]"
    end
    local where = { k = "vendor", npc = 4223, map = 1457 }
    T.Eq(ns.Chat.Line(m, where, {}, link), nil, "nothing new: no line")
    T.Eq(ns.Chat.Line(m, where, { 1 }, link), L.CARNET_PREFIX .. string.format(L.CHAT_ONE, 1,
        string.format(L.AT_NPC, "Ellandrieth", "Darnassus"), "[1]"), "one recipe")
    local five = ns.Chat.Line(m, where, { 1, 2, 3, 4, 5 }, link)
    T.True(five:find("[1], [2], [3]" .. string.format(L.MORE_MANY, 2), 1, true), "three links and « et 2 autres »: " .. five)
    local seen = { [2] = { k = "vendor", npc = 4223, stock = 1 }, [3] = { k = "vendor", npc = 4223, stock = -1 } }
    T.Eq(ns.Chat.Line(m, where, { 2, 3 }, link, seen), L.CARNET_PREFIX .. string.format(L.CHAT_MANY, 2,
        string.format(L.AT_NPC, "Ellandrieth", "Darnassus"), "[2] " .. ns.Text.CLOCK_MARKUP .. ", [3]"),
        "the grey clock after the link of a recipe the vendor had in limited stock")
    local loot = ns.Chat.Line(m, { k = "drop", npc = 4223, map = 1457 }, { 7 }, link)
    T.Eq(loot, L.CARNET_PREFIX .. string.format(L.CHAT_SINGLE, "[7]", string.format(L.AT_LOOT, "Ellandrieth", "Darnassus")),
        "one looted recipe: its own line")
end)

T.Add("Tooltips", "a recipe's lines: unknown, known by another character, held, seen", function()
    local m, db = T.NewBook()
    T.Eq(#ns.Tooltips.RecipeLines(m, R.robe, "off"), 0, "none: nothing")
    local lines = ns.Tooltips.RecipeLines(m, R.robe, "detailed")
    T.True(has(lines, L.UNKNOWN_TO_ALL), "unknown to all")
    db.chars.alt.known[R.robe] = true
    db.chars.alt.bank[I.robe] = 2
    ns.DB.SetName(db, "npc", 4223, "Ellandrieth")
    m:Note(R.robe, T.Vendor(), 1)
    m:Invalidate()
    lines = ns.Tooltips.RecipeLines(m, R.robe, "detailed")
    T.True(has(lines, string.format(L.KNOWN_BY, string.format(L.KNOWN_RANK, "Elorah", ns.Game.ProfName(197), 70))), "known by Elorah, with her rank")
    T.True(has(lines, string.format(L.ALT_HAS, "Elorah", 2, L.BANK)), "she has two, in the bank")
    T.True(has(lines, string.format(L.WHERE_VENDOR, "Ellandrieth", "Darnassus")), "where it was seen")
    local compact = ns.Tooltips.RecipeLines(m, R.robe, "compact")
    T.Eq(#compact, 2, "a blank and one line")
    T.True(compact[2][1]:find(string.format(L.COMPACT_SEEN, 1), 1, true), "seen once: " .. compact[2][1])
end)

T.Add("Tooltips", "a material's « Utilisé dans », by profession, at most N lines", function()
    local m, db = T.NewBook()
    local o = { usedIn = true, usedInSeen = true, usedInMax = 10, mCraft = true }
    T.Eq(#ns.Tooltips.MaterialLines(m, I.boarMeat, o), 0, "unmet: nothing")
    m:Note(R.ribs, T.Vendor(), 1)
    m:Invalidate()
    local lines = ns.Tooltips.MaterialLines(m, I.boarMeat, o)
    T.True(has(lines, L.USED_IN), "the heading")
    T.True(has(lines, ns.Game.ProfName(185)), "the profession")
    T.True(has(lines, "  Côtes de sanglier à la bière | " .. L.SEEN_WORD), "the recipe, seen, not where (Ikar, 2026-11-10)")
    lines = ns.Tooltips.MaterialLines(m, I.boarRibs, o)
    T.True(has(lines, "  " .. ns.Game.ProfName(185) .. " · Côtes de sanglier à la bière | " .. L.SEEN_WORD),
        "« Fabriqué par »: the recipe, seen, not where")
    o.usedInSeen = false
    T.Eq(#ns.Tooltips.MaterialLines(m, I.boarMeat, o), 0, "seen recipes left out on request")
    db.chars.me.known[R.ribs] = true
    m:Invalidate()
    lines = ns.Tooltips.MaterialLines(m, I.boarMeat, o)
    T.True(has(lines, "  Côtes de sanglier à la bière"), "known by me: no name on the right")
    lines = ns.Tooltips.MaterialLines(m, I.boarRibs, o)
    T.True(has(lines, L.MADE_BY), "« Fabriqué par » on what it makes")
    o.mCraft = false
    T.Eq(#ns.Tooltips.MaterialLines(m, I.boarRibs, o), 0, "and not when off")
end)

T.Add("CountLines", "« Carnet : 1 à apprendre · 1 vue », and « vues » alone for another profession", function()
    local m = T.NewBook()
    m:Note(R.ribs, T.Vendor(), 1)
    m:Note(R.stew, T.Vendor(), 1)
    m:Note(R.robe, T.Vendor(), 1)
    local text, learn, seen = ns.CountLines.Text(m, 185)
    T.Eq(learn .. "/" .. seen, "1/1", "the numbers")
    T.Eq(plain(text), L.CARNET_PREFIX .. string.format(L.TO_LEARN, 1) .. " · " .. string.format(L.SEEN_ONE, 1), "the text")
    T.Eq(plain(ns.CountLines.Text(m, 197)), L.CARNET_PREFIX .. string.format(L.SEEN_ONE, 1), "tailoring: seen only")
    T.Eq(plain(ns.CountLines.Text(m, 129)), L.CARNET_PREFIX .. string.format(L.SEEN_MANY, 0), "first aid: at zero")
end)

T.Add("MapPins", "a pin per place where an unknown recipe was seen", function()
    local m, db = T.NewBook()
    m:Note(R.ribs, T.Vendor(), 1)
    m:Note(R.stew, T.Vendor(), 1)
    m:Note(R.robe, { k = "ah" }, 1)
    local spots = ns.MapPins.Spots(m, 1457)
    T.Eq(#spots, 1, "one place")
    T.Eq(#spots[1].spells, 2, "two recipes there")
    db.chars.me.known[R.ribs] = true
    m:Invalidate()
    T.Eq(#ns.MapPins.Spots(m, 1457)[1].spells, 1, "a known one leaves the pin")
    T.Eq(#ns.MapPins.Spots(m, 1438), 0, "nothing on another map")
end)

T.Add("Game", "a profession by its number, or by its name when the game gives another number", function()
    local G = ns.Game
    T.Eq(G.Skill(185), 185, "cooking's own number")
    T.Eq(G.Skill(999999, ns.PROFESSION_NAMES.frFR[185]), 185, "an unknown number, the French name")
    T.Eq(G.Skill(999998, ns.PROFESSION_NAMES.enUS[197]), 197, "the English name")
    T.Eq(G.Skill(999997, "Archéologie"), nil, "a profession the addon doesn't cover")
    T.True(G.unknownSkillLines[999997] ~= nil, "noted for the API check")
    G.unknownSkillLines[999997] = nil
end)

T.Add("Game", "numbers read from the game's own strings", function()
    local G = ns.Game
    T.Eq(G.NPCFromGUID("Creature-0-3110-0-47-1234-0000ABCDEF"), 1234, "a creature's number")
    T.Eq(G.NPCFromGUID("Player-1234-0ABCDEF0"), nil, "a player isn't an NPC")
    T.Eq(G.NPCFromGUID(nil), nil, "no GUID")
    T.Eq(G.ItemFromLink("|cffffffff|Hitem:2889::::::::|h[Recette]|h|r"), 2889, "an item link's number")
    T.Eq(G.ItemFromLink("[plain]"), nil, "no link")
end)

T.Add("Text", "a vendor's price: the game's money, then each token; nothing for another sighting", function()
    T.Eq(ns.Text.Price({ k = "vendor", cost = 1250 }), GetMoneyString(1250), "the money, as the game writes it")
    T.Eq(ns.Text.Price({ k = "vendor", costs = { { n = 3, item = 20558, tex = 133784 } } }), "3 |T133784:0|t", "a token, its icon")
    T.Eq(ns.Text.Price({ k = "vendor", cost = 500, costs = { { n = 2, currency = 1 } } }), GetMoneyString(500) .. " 2",
        "money, then a token without its icon")
    T.Eq(ns.Text.Price({ k = "ah" }), nil, "the auction house: none")
    local lines = ns.Tooltips.RecipeLines((function()
        local m = T.NewBook()
        local s = T.Vendor()
        s.cost = 1250
        m:Note(R.ribs, s, 1)
        return m
    end)(), R.ribs, "detailed")
    local priced = false
    for _, line in ipairs(lines) do
        priced = priced or line[2] == GetMoneyString(1250)
    end
    T.True(priced, "the recipe's tooltip gives it beside the vendor")
end)
