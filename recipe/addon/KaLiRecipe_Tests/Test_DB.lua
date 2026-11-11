-- The saved data: what loading keeps, sets aside and upgrades; options that hold only changes; the character's copy
-- that brings the notebook back; merging two copies; a file as the game writes and reads it. docs/saved-data.md.
local T = KaLiRecipeTests
local ns = KaLiRecipeDev.ns
local DB = ns.DB

-- 2026-11-11, the day after the format 1 fixture was written.
local NOW = 1794400000

local function byPlace(db)
    local out = {}
    for _, e in ipairs(db.setAside) do
        out[e.at] = e
    end
    return out
end

T.Add("DB", "a first run gets the current version and Ikar's defaults, read through and not saved", function()
    local db, fixed, aside = DB.Load(nil, NOW)
    T.Eq(db.version, DB.VERSION, "version")
    T.Eq(next(db.chars), nil, "no character yet")
    T.Eq(next(db.sightings), nil, "nothing seen yet")
    T.Eq(fixed .. "/" .. aside, "0/0", "nothing repaired or set aside")
    local o = db.options
    T.Eq(o.chat, true, "chat on")
    T.Eq(o.recipeTip, "detailed", "recipe tooltip detailed")
    T.Eq(o.usedInMax, 10, "« Utilisé dans » 10 lines")
    T.Eq(o.style, "clean", "Épuré by default")
    T.Eq(o.follow, false, "« Suivre » off by default")
    T.Eq(o.width .. "x" .. o.height, "560x820", "560 by 820")
    T.Eq(o.mCraftSeen, true, "crafted marks from seen recipes too")
    T.Eq(next(o), nil, "the saved options hold nothing: defaults are read through")
    T.Eq(db.ui.open.learn, true, "« À apprendre » open")
    T.Eq(db.ui.open.seen, true, "« Vues » open")
    T.Eq(db.ui.open.known, false, "« Appris » closed by default")
    T.Eq(type(db.meta.id), "string", "the notebook has its own name")
    T.Eq(db.meta.created, NOW, "and the day it was made")
    T.Eq(db.meta.history[1].what, "created", "its first event")
    T.Eq(#db.setAside, 0, "nothing set aside")
end)

T.Add("DB", "data from a newer addon is left untouched", function()
    local saved = { version = DB.VERSION + 1, sightings = { [2795] = { "junk" } } }
    local db, reason = DB.Load(saved)
    T.Eq(db, nil, "refused")
    T.True(reason:find(tostring(DB.VERSION + 1), 1, true), "reason names the version: " .. tostring(reason))
    T.Eq(saved.sightings[2795][1], "junk", "not repaired either")
end)

T.Add("DB", "something that isn't a table, or a version that isn't one, is refused", function()
    local db, reason = DB.Load("broken")
    T.Eq(db, nil, "refused")
    T.Eq(reason, "not a table", "reason")
    T.Eq(select(2, DB.Load({ version = "2" })), "bad version", "a version in words")
    T.Eq(select(2, DB.Load({ version = 1.5 })), "bad version", "half a version")
end)

T.Add("DB", "a failing step leaves the original alone", function()
    local step = DB.STEPS[1]
    DB.STEPS[1] = function()
        error("boom")
    end
    local saved = {}
    local ok, db, reason = pcall(DB.Load, saved)
    DB.STEPS[1] = step
    T.True(ok, "Load itself doesn't throw")
    T.Eq(db, nil, "refused")
    T.True(tostring(reason):find("step 1", 1, true), "reason names the step: " .. tostring(reason))
    T.Eq(saved.version, nil, "original untouched")
end)

T.Add("DB", "loading works on a copy, and the saved table is never changed", function()
    local saved = DB.Load(nil, NOW)
    saved.options.width = 5000
    local db = DB.Load(saved, NOW)
    T.True(db ~= saved, "a new table")
    T.Eq(db.options.width, 900, "width kept in its range")
    T.Eq(saved.options.width, 5000, "the original keeps its value")
end)

T.Add("DB", "what can't be read is set aside, with where and why; the rest is kept", function()
    local saved = {
        version = DB.VERSION,
        sightings = {
            [2795] = { { k = "vendor", npc = 4223, map = 1457, x = 0.5, y = 0.4, t = 100 }, "junk", { k = "ah", t = 5, npc = "x" }, { k = "drop" } },
            bad = { { k = "vendor", t = 1 } },
            [2543] = {},
        },
        chars = { me = { name = "Ikar", known = { [2795] = true, x = true, [7418] = "yes" }, bags = { [2889] = 2, [728] = -1 },
            profs = { [185] = 56 } }, [5] = { name = "?" } },
        options = { recipeTip = "huge", style = 3, usedInMax = 99 },
        reqs = { [7418] = 1, [2541] = "x" },
    }
    local db, fixed, aside = DB.Load(saved, NOW)
    T.Eq(#db.sightings[2795], 2, "the vendor and the auction house stay")
    T.Eq(db.sightings[2795][2].npc, nil, "the auction house's bad NPC number cleared")
    T.Eq(db.sightings.bad, nil, "a list under a bad key moved out")
    T.Eq(db.sightings[2543], nil, "an empty list dropped")
    local at = byPlace(db)
    T.Eq(at["sightings.2795[2]"] and at["sightings.2795[2]"].v, "junk", "the junk, set aside as it was")
    T.Eq(at["sightings.2795[3]"] and at["sightings.2795[3]"].v.npc, "x", "the sighting with a bad NPC, as it was")
    T.Eq(at["sightings.2795[4]"] and at["sightings.2795[4]"].why, "no date", "a sighting without a date")
    T.Eq(at["sightings.bad"] and at["sightings.bad"].v[1].k, "vendor", "the list under a bad key, whole")
    T.Eq(at["chars.5"] and at["chars.5"].why, "not a character's key", "a character under a bad key")
    T.Eq(at["options.recipeTip"] and at["options.recipeTip"].v, "huge", "an unknown choice")
    T.Eq(at["options.style"] and at["options.style"].v, 3, "a style of the wrong type")
    T.Eq(aside, 7, "seven things set aside")
    T.Eq(db.options.recipeTip, "detailed", "the default reads through")
    T.Eq(db.options.style, "clean", "and for the style")
    T.Eq(db.options.usedInMax, 20, "lines kept in their range")
    T.Eq(db.chars.me.known[2795], true, "a known recipe stays")
    T.Eq(db.chars.me.known.x, nil, "a bad known key dropped: the game reads them again")
    T.Eq(db.chars.me.bags[728], nil, "a negative count dropped")
    T.Eq(type(db.chars.me.bank), "table", "a missing bank filled")
    T.Eq(db.reqs[2541], nil, "a bad required rank dropped")
    T.Eq(db.reqs[7418], 1, "a good one kept")
    T.True(fixed >= 4, "fixes counted: " .. tostring(fixed))
    T.Eq(db.meta.history[#db.meta.history].what, "set aside", "the event noted")
    local again, _, aside2 = DB.Load(db, NOW)
    T.Eq(aside2, 0, "opened again, nothing more set aside")
    T.Eq(#again.setAside, 7, "and what was set aside stays")
end)

T.Add("DB", "what a later version added is kept as it is, and ignored", function()
    local saved = DB.Load(nil, NOW)
    saved.sightings[2795] = { { k = "mail", t = 50, t0 = 40, from = 12 }, { k = "vendor", npc = 4223, t = 60, t0 = 60, mood = "kind" } }
    saved.sightings[2543] = { { k = "mail", t = 70, t0 = 70 } }
    saved.options.someLaterOption = "on"
    saved.laterTable = { 1, 2, 3 }
    saved.chars.me = { name = "Ikar", known = {}, bags = {}, bank = {}, profs = {}, maxRanks = {}, laterField = true }
    local db, _, aside = DB.Load(saved, NOW)
    T.Eq(aside, 0, "nothing set aside")
    T.Eq(db.sightings[2795][1].k, "mail", "a sighting of another kind kept")
    T.Eq(db.sightings[2795][1].from, 12, "with its fields")
    T.Eq(db.sightings[2795][2].mood, "kind", "a field a later version added kept")
    T.Eq(db.options.someLaterOption, "on", "an option a later version added kept")
    T.Eq(db.laterTable[3], 3, "a table a later version added kept")
    T.Eq(db.chars.me.laterField, true, "a character's field kept")
    local m = ns.Model.New(db, { recipes = ns.RECIPES, items = ns.RECIPE_ITEMS, categories = ns.CATEGORIES,
        categoryNames = ns.CATEGORY_NAMES.frFR }, T.FakeGame(), "me")
    T.Eq(#m:Sightings(2795), 1, "the model shows the vendor only")
    T.Eq(m:Seen(2543), false, "a recipe seen only so isn't in this version's notebook")
    T.Eq(m:Total(), 1, "which holds one recipe")
    DB.BeforeSave(db, NOW)
    T.Eq(db.options.someLaterOption, "on", "saving keeps them")
    T.Eq(db.sightings[2543][1].k, "mail", "all of them")
end)

T.Add("DB", "options hold only what was changed, so a later change of a default reaches the player", function()
    local db = DB.Load(nil, NOW)
    db.options.chat = false
    db.options.width = 560
    DB.BeforeSave(db, NOW)
    T.Eq(rawget(db.options, "chat"), false, "a change is kept")
    T.Eq(rawget(db.options, "width"), nil, "a value at its default isn't")
    T.Eq(db.options.width, 560, "and still reads")
    T.Eq(db.meta.writer, ns.VERSION, "the file says who wrote it")
    T.Eq(db.meta.written, NOW, "and when")
    local default = DB.DEFAULTS.width
    DB.DEFAULTS.width = 600
    local ok, width, chat = pcall(function()
        local later = DB.Load(db, NOW)
        return later.options.width, later.options.chat
    end)
    DB.DEFAULTS.width = default
    T.True(ok, tostring(width))
    T.Eq(width, 600, "a new default reaches the player who never changed it")
    T.Eq(chat, false, "what they changed stays")
end)

T.Add("DB", "format 1 to 2: options at version 1's defaults go, and the two options dropped that day", function()
    local db = DB.Load({ version = 1, options = { chat = true, width = 700, usedInWhere = true, nbHoldText = false, laterOne = 1 },
        sightings = {}, chars = {} }, NOW)
    T.Same(db.options, { width = 700, laterOne = 1 }, "options")
    -- A released step reads only what it holds: today's defaults changing doesn't change what it does.
    local default = DB.DEFAULTS.width
    DB.DEFAULTS.width = 600
    local ok, later = pcall(DB.Load, { version = 1, options = { width = 560 }, sightings = {}, chars = {} }, NOW)
    DB.DEFAULTS.width = default
    T.True(ok, tostring(later))
    T.Eq(rawget(later.options, "width"), nil, "version 1's default goes, whatever today's is")
end)

T.Add("DB", "a sighting's place: one per NPC for vendors, trainers and loot, one per quest, one auction house, one bags", function()
    local P = DB.PlaceKey
    T.True(P({ k = "vendor", npc = 1 }) ~= P({ k = "vendor", npc = 2 }), "two vendors")
    T.True(P({ k = "vendor", npc = 1 }) ~= P({ k = "drop", npc = 1 }), "a vendor and its loot")
    T.Eq(P({ k = "trainer", npc = 1, map = 1 }), P({ k = "trainer", npc = 1, map = 2 }), "a trainer, wherever")
    T.True(P({ k = "quest", q = 1 }) ~= P({ k = "quest", q = 2 }), "two quests")
    T.Eq(P({ k = "ah", item = 1 }), P({ k = "ah", item = 2 }), "the auction house is one")
    T.Eq(P({ k = "bags", map = 1 }), P({ k = "bags", map = 2 }), "the bags are one")
    T.True(P({ k = "mail", t0 = 1, t = 5 }) ~= P({ k = "mail", t0 = 2, t = 5 }), "a later version's kind, by its first date")
    T.Eq(P({ k = "mail", t0 = 1, t = 5 }), P({ k = "mail", t0 = 1, t = 9 }), "seen again, still one")
end)

T.Add("DB", "a format 1 file opens with nothing lost: Ikar's of 2026-11-10", function()
    local env, err = T.ReadSaved(T.FIXTURES[1])
    T.True(env, "the file reads: " .. tostring(err))
    local old = env.KaLiRecipeDB
    local db, fixed, aside = DB.Load(old, NOW)
    T.True(db, "opened: " .. tostring(fixed))
    T.Eq(db.version, DB.VERSION, "now the current format")
    T.Eq(fixed .. "/" .. aside, "0/0", "nothing to repair, nothing set aside")
    T.Same(db.sightings, old.sightings, "sightings")
    T.Same(db.chars, old.chars, "characters")
    T.Same(db.reqs, old.reqs, "trainers' ranks")
    T.Same(db.names, old.names, "names")
    T.Same(db.ui, old.ui, "the window")
    T.Same(db.options, { follow = true }, "options: only « Suivre », the one Ikar changed")
    T.Eq(db.options.chat, true, "the others read their default")
    T.Eq(db.sightings[1257013][1].cost, 150, "Dani'ill's price")
    T.Eq(db.meta.created, 1794336483, "made on its first sighting's day")
    local last = db.meta.history[#db.meta.history]
    T.Eq(last.what .. " " .. tostring(last.from) .. ">" .. tostring(last.to), "upgraded 1>" .. DB.VERSION, "the upgrade noted")
end)

T.Add("DB", "every format's file opens, and opening it again changes nothing", function()
    local n = 0
    for v, text in pairs(T.FIXTURES) do
        n = n + 1
        local env = T.ReadSaved(text)
        T.True(env and env.KaLiRecipeDB, "format " .. v .. " reads")
        local db, _, aside = DB.Load(env.KaLiRecipeDB, NOW)
        T.True(db, "format " .. v .. " opens")
        T.Eq(aside, 0, "format " .. v .. ": nothing set aside")
        T.Same(DB.Load(db, NOW), db, "format " .. v .. " opened twice")
    end
    T.Eq(n, DB.VERSION - 1, "a file for each format before this one")
end)

-- The game's Lua compares nan as equal to everything, so this is what catches a check written with comparisons.
T.Add("DB", "nan and inf are found without comparing them", function()
    for _, v in ipairs({ 0 / 0, -(0 / 0), math.huge, -math.huge }) do
        T.True(not DB.Finite(v), "not finite: " .. tostring(v))
        T.True(not DB.IsID(v), "not an ID: " .. tostring(v))
    end
    for _, v in ipairs({ 0, -0, 1, -1.5, 0.63719999, 1794336843, 2 ^ 53, 1e300, -1e-300 }) do
        T.True(DB.Finite(v), "finite: " .. tostring(v))
    end
    T.True(DB.IsID(4161) and not DB.IsID(0) and not DB.IsID(1.5) and not DB.IsID(2 ^ 31), "IDs")
end)

T.Add("DB", "the notebook as the game writes it reads back the same", function()
    local m, db = T.NewBook()
    local s = T.Vendor()
    s.cost, s.costs, s.x = 1250, { { n = 3, item = 20558, tex = 133784 } }, 0.63719999
    m:Note(T.R.ribs, s, 1794336843)
    m:Note(T.R.stew, { k = "quest", q = 99, map = 1457, item = 728 }, 1794336900)
    m:Forget(T.R.stew, 1794337000)
    db.ui.pos = { 71.96577453613281, 88.97441864013672, "CENTER", "CENTER" }
    db.options.follow = true
    db.options.width = 0 / 0
    db.sightings[T.R.ribs][1].cost = math.huge
    DB.BeforeSave(db, NOW)
    T.Eq(db.meta.nonFinite, 2, "a nan and an inf taken out")
    local text = T.Saved("KaLiRecipeDB", db)
    for _, bad in ipairs({ "= %-?nan", "= %-?inf", "= %-?1%.#" }) do
        T.True(not text:find(bad), "no number the file can't hold: " .. bad)
    end
    local env, err = T.ReadSaved(text)
    T.True(env, "the file reads: " .. tostring(err))
    T.Same(env.KaLiRecipeDB, db, "read back")
    T.Same(DB.Load(env.KaLiRecipeDB, NOW), db, "and opened")
end)

T.Add("DB", "two copies merge: one sighting per place, the earliest first date, the latest visit's price and position", function()
    local a, b = DB.Load(nil, NOW), DB.Load(nil, NOW)
    a.sightings[2795] = { { k = "vendor", npc = 4223, map = 1457, x = 0.5, y = 0.4, t0 = 100, t = 200, cost = 1000, item = 2889 } }
    b.sightings[2795] = {
        { k = "vendor", npc = 4223, map = 1457, x = 0.52, y = 0.41, t0 = 50, t = 300, cost = 900, item = 2889 },
        { k = "ah", t0 = 150, t = 150, item = 2889 },
    }
    b.sightings[2543] = { { k = "quest", q = 99, t0 = 10, t = 10, item = 728 } }
    local s = DB.Merge(a, b)
    local v = a.sightings[2795][1]
    T.Eq(#a.sightings[2795], 2, "the vendor once, the auction house added")
    T.Eq(v.t0 .. "/" .. v.t, "50/300", "the earliest first date, the latest last date")
    T.Eq(v.cost, 900, "the latest visit's price")
    T.Eq(v.x, 0.52, "and position")
    T.Eq(a.sightings[2543][1].q, 99, "a recipe only the other saw")
    T.Eq(s, 3, "three sightings in or changed")
    T.Eq(b.sightings[2795][1].t0, 50, "the other copy left as it was")
    T.Eq(DB.Merge(a, b), 0, "merged twice: nothing more")
    local p = DB.MergeSighting({ k = "vendor", npc = 1, t0 = 1, t = 1, cost = 5 }, { k = "vendor", npc = 1, t0 = 2, t = 2 })
    T.Eq(p.cost .. "/" .. p.t, "5/2", "a later visit that read no price keeps the one known")
end)

T.Add("DB", "a recipe forgotten stays forgotten when a copy merges; seen again afterwards, it's back", function()
    local a, b = DB.Load(nil, NOW), DB.Load(nil, NOW)
    b.sightings[2795] = { { k = "vendor", npc = 4223, t0 = 100, t = 200 } }
    a.forgotten[2795] = 250
    T.Eq(DB.Merge(a, b), 0, "nothing came in")
    T.Eq(a.sightings[2795], nil, "what was seen before it was forgotten doesn't come back")
    b.sightings[2795][1].t = 300
    DB.Merge(a, b)
    T.Eq(a.sightings[2795] and a.sightings[2795][1].t, 300, "seen again after: noted")
    local c, d = DB.Load(nil, NOW), DB.Load(nil, NOW)
    c.sightings[2543] = { { k = "ah", t0 = 10, t = 10 } }
    d.forgotten[2543] = 20
    DB.Merge(c, d)
    T.Eq(c.sightings[2543], nil, "forgotten in the copy: gone here too")
    T.Eq(c.forgotten[2543], 20, "and the mark kept")
end)

T.Add("DB", "two copies merge: each character's latest record, and the names and ranks one lacks", function()
    local a, b = DB.Load(nil, NOW), DB.Load(nil, NOW)
    local function char(name, seen, rank)
        return { name = name, seen = seen, known = {}, bags = {}, bank = {}, profs = { [185] = rank }, maxRanks = {} }
    end
    a.chars.me, b.chars.me, b.chars.alt = char("Ikar", 200, 60), char("Ikar", 100, 50), char("Elorah", 150, 1)
    DB.SetName(b, "npc", 4223, "Ellandrieth")
    DB.SetName(a, "npc", 4223, "Ellandrieth, renamed")
    DB.SetName(b, "npc", 1234, "Kobold")
    b.reqs[2541] = 50
    local _, chars = DB.Merge(a, b)
    T.Eq(a.chars.me.profs[185], 60, "this one's newer record stays")
    T.Eq(a.chars.alt and a.chars.alt.name, "Elorah", "a character only the other knew")
    T.Eq(chars, 1, "one character in")
    T.Eq(DB.Name(a, "npc", 4223), "Ellandrieth, renamed", "a name this one has stays")
    T.Eq(DB.Name(a, "npc", 1234), "Kobold", "a name it lacked")
    T.Eq(a.reqs[2541], 50, "a rank it lacked")
end)

T.Add("DB", "the character's copy: the whole notebook, apart from it", function()
    local db = DB.Load(nil, NOW)
    db.sightings[2795] = { { k = "ah", t0 = 1, t = 1 } }
    local copy = DB.Copy(db, "Player-1-00000001", NOW)
    T.Eq(copy.owner .. " " .. copy.at .. " " .. copy.writer, "Player-1-00000001 " .. NOW .. " " .. ns.VERSION, "who, when, which version")
    T.True(copy.data ~= db and copy.data.sightings ~= db.sightings, "a copy, not the same tables")
    T.Same(copy.data, db, "the same content")
    T.Eq(getmetatable(copy.data.options), nil, "plain tables, as the game writes them")
end)

T.Add("DB", "startup: the account's file missing, the character's copy brings the notebook back", function()
    local db = DB.Load(nil, 1000)
    db.sightings[2795] = { { k = "vendor", npc = 4223, t0 = 1000, t = 1000 } }
    db.options.follow = true
    DB.BeforeSave(db, 1100)
    local env = T.ReadSaved(T.Saved("KaLiRecipeCopyDB", DB.Copy(db, "Player-1-00000001", 1100)))
    local back, info = DB.Open(nil, env.KaLiRecipeCopyDB, NOW)
    T.True(info.restored, "restored")
    T.Eq(info.restored.recipes, 1, "one recipe")
    T.Eq(info.restored.at, 1100, "the copy's date")
    T.Eq(info.firstRun, false, "not a first run")
    T.Eq(back.sightings[2795][1].npc, 4223, "the sighting back")
    T.Eq(back.options.follow, true, "the options back")
    T.Eq(back.meta.id, db.meta.id, "the same notebook")
    T.Eq(back.meta.history[#back.meta.history].what, "restored", "noted")
    local fresh, info2 = DB.Open(nil, nil, NOW)
    T.Eq(info2.firstRun, true, "no file and no copy: a first run")
    T.Eq(next(fresh.sightings), nil, "an empty notebook")
end)

T.Add("DB", "startup: an older account file (its .bak put back) is completed by the copy; an older copy changes nothing", function()
    local old = DB.Load(nil, 1000)
    old.sightings[2795] = { { k = "vendor", npc = 4223, t0 = 1000, t = 1000 } }
    local new = DB.Load(old, 1000)
    new.sightings[2543] = { { k = "ah", t0 = 2000, t = 2000 } }
    new.sightings[2795][1].t = 2000
    local db, info = DB.Open(old, DB.Copy(new, "Player-1-00000001", 2100), NOW)
    T.Eq(info.recovered, 2, "two sightings from the copy")
    T.Eq(db.sightings[2543] and db.sightings[2543][1].k, "ah", "the one only the copy held")
    T.Eq(db.sightings[2795][1].t, 2000, "the later visit")
    T.Eq(old.sightings[2543], nil, "the account's table untouched")
    T.Eq(db.meta.history[#db.meta.history].what, "merged", "noted")
    local db2, info2 = DB.Open(new, DB.Copy(old, "Player-1-00000001", 1100), NOW)
    T.Eq(info2.recovered, 0, "nothing from an older copy")
    T.Same(db2.sightings, new.sightings, "nothing lost")
end)

T.Add("DB", "startup: a notebook started over after the copy was written takes the copy's options; else its own stand", function()
    local before = DB.Load(nil, 1000)
    before.options.follow, before.options.chat = true, false
    local copy = DB.Copy(before, "Player-1-00000001", 1100)
    local over = DB.Load(nil, 5000)
    over.options.chat = true
    local db = DB.Open(over, copy, NOW)
    T.Eq(rawget(db.options, "follow"), true, "an option only the copy had changed comes back")
    T.Eq(rawget(db.options, "chat"), true, "one the new notebook set stays")
    local kept = DB.Load(nil, 900)
    local db2 = DB.Open(kept, copy, NOW)
    T.Eq(rawget(db2.options, "follow"), nil, "a notebook older than the copy keeps its own options: one put back to its default stays so")
end)

T.Add("DB", "startup: a copy this version can't read stays as it is, and the account's file still opens", function()
    local copy = { owner = "x", at = 1, data = { version = DB.VERSION + 1, sightings = {} } }
    local db, info = DB.Open(DB.Load(nil, 1000), copy, NOW)
    T.True(db, "the notebook opens")
    T.True(info.copyRefused and info.copyRefused:find("version", 1, true), "the copy refused: " .. tostring(info.copyRefused))
    T.Eq(copy.data.version, DB.VERSION + 1, "and untouched")
    local none, why = DB.Open({ version = DB.VERSION + 1 }, nil, NOW)
    T.Eq(none, nil, "an account file from a newer version: refused")
    T.True(tostring(why):find("version", 1, true), "with why: " .. tostring(why))
end)

T.Add("DB", "saved prices are cleaned, the sighting as it was set aside", function()
    local db = DB.Load({ version = DB.VERSION, sightings = { [2795] = { { k = "vendor", t = 1, npc = 4223, cost = "lots",
        costs = { { n = 2, item = 20558 }, "junk" } } } } }, NOW)
    local s = db.sightings[2795][1]
    T.Eq(s.cost, nil, "a price that isn't a number: cleared")
    T.Eq(#s.costs, 1, "the token kept, the junk dropped")
    T.Eq(s.costs[1].item, 20558, "with its item")
    T.Eq(db.setAside[1] and db.setAside[1].v.cost, "lots", "the sighting as it was, set aside")
    T.Eq(db.setAside[1].why, "unreadable cost, costs", "with why")
end)

T.Add("DB", "two sightings of one place in a file become one", function()
    local db = DB.Load({ version = DB.VERSION, sightings = { [2795] = { { k = "vendor", npc = 4223, t0 = 100, t = 200, cost = 5 },
        { k = "vendor", npc = 4223, t0 = 50, t = 150 }, { k = "vendor", npc = 99, t0 = 1, t = 1 } } } }, NOW)
    local s = db.sightings[2795]
    T.Eq(#s, 2, "one per vendor")
    T.Eq(s[1].t0 .. "/" .. s[1].t .. "/" .. s[1].cost, "50/200/5", "the earliest first date, the latest visit and its price")
end)

T.Add("DB", "what is set aside is capped, the oldest going first, and counted", function()
    local max = DB.SET_ASIDE_MAX
    DB.SET_ASIDE_MAX = 3
    local ok, db = pcall(DB.Load, { version = DB.VERSION, sightings = { [2795] = { "a", "b", "c", "d", "e" } } }, NOW)
    DB.SET_ASIDE_MAX = max
    T.True(ok, tostring(db))
    T.Eq(#db.setAside, 3, "three kept")
    T.Eq(db.setAside[1].v, "c", "the oldest went")
    T.Eq(db.meta.setAsideDropped, 2, "two counted")
end)

T.Add("DB", "names the game gave are kept per language, by number", function()
    local db = DB.Load(nil)
    DB.SetName(db, "npc", 4223, "Ellandrieth")
    DB.SetName(db, "npc", "x", "nobody")
    DB.SetName(db, "npc", 4224, "")
    T.Eq(DB.Name(db, "npc", 4223), "Ellandrieth", "kept")
    T.Eq(DB.Name(db, "npc", 4224), nil, "an empty name isn't")
    T.Eq(db.names[ns.LOCALE].npc.x, nil, "a bad number isn't")
end)

T.Add("DB", "the window's state: what doesn't fit goes back to its default", function()
    local function opened(ui)
        return (DB.Load({ version = DB.VERSION, ui = ui }, NOW)).ui
    end
    T.Eq(opened({ minimap = 90 }).minimap, 90, "the minimap button's place kept")
    T.Eq(opened({ minimap = -30 }).minimap, 330, "an angle brought round")
    T.Eq(opened({ minimap = "top" }).minimap, nil, "not a number: the default place")
    T.Eq(opened({ minimap = 0 / 0 }).minimap, nil, "nan: the default place")
    T.Eq(opened({ pos = { "x", 3 } }).pos, nil, "a position that isn't one")
    T.Eq(opened({ skill = 1.5 }).skill, nil, "a tab that isn't a profession")
    local ui = opened({ open = { known = "yes" } })
    T.Eq(ui.open.known, false, "a section's state that isn't one")
    T.Eq(ui.open.learn, true, "and the others at theirs")
end)
