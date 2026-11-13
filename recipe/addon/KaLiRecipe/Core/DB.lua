-- Saved data: the notebook, account-wide (KaLiRecipeDB), so a recipe one character saw counts for all and each
-- character's bags and known recipes show on the others; and a copy of it in each character's own file
-- (KaLiRecipeCopyDB), which brings it back when the account's file is missing and completes it when the account's file
-- is older. Numbers only as keys: recipe spells, items, NPCs, maps, quests. The format and its rules are in
-- docs/saved-data.md; in short:
-- - Loading never loses what was noted. Upgrades and repairs run on a copy that replaces the original only if every
--   step succeeds, and data from a newer addon is left alone.
-- - What this version doesn't understand stays as it is and is ignored: a sighting of a kind a later version added,
--   a field, an option, a key.
-- - What can't be read is set aside (setAside), with where it was and why, never deleted.
-- - Options hold only what the player changed. A default is read through, so a later change of a default reaches them.
-- - A sighting is one per place (DB.PlaceKey): two copies of the notebook, and later an import, merge by it.
-- - A deletion leaves a mark (forgotten), or a copy would bring the deleted thing back.
local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 2

-- Ikar's picks of 2026-11-09, on the bench (its OPTIONS), as the in-game defaults. Read through, never saved: the
-- options table holds what the player changed. Gone on 2026-11-13 with the auction house's marks: mVendor and ah. A file
-- that still holds them keeps them, unread, as for any option this version doesn't know.
DB.DEFAULTS = {
    chat = true,
    mKnown = true, mLearnable = true, mTooLow = true, mOwned = true, mAlt = true, mCraft = true, mCraftSeen = true,
    recipeTip = "detailed", usedIn = true, usedInSeen = true, usedInMax = 10,
    style = "clean", follow = false, width = 560, height = 820, nbOwned = true, nbAlt = true,
    a1 = true, a2 = true, showZero = true, pins = true, priceTrainer = true, minimap = true, minimapLock = false,
    soundRecipe = ns.Sounds.DEFAULTS.recipe, soundPlace = ns.Sounds.DEFAULTS.place, soundVolume = 200,
}
-- The game's own settings write a default into the table when its key is nil (Blizzard_Setting.lua): read through,
-- the default is there, so they write nothing.
local OPTIONS = { __index = DB.DEFAULTS }

-- The options page's ranges, which loading also keeps saved numbers in.
DB.RANGES = { width = { 460, 900 }, height = { 600, 1080 }, usedInMax = { 3, 20 }, soundVolume = { 0, 300 } }
DB.CHOICES = { recipeTip = { detailed = true, compact = true, off = true }, style = { clean = true, book = true },
    soundRecipe = ns.Sounds.Keys("recipe"), soundPlace = ns.Sounds.Keys("place") }

-- Where a recipe can be seen. Ikar's ruling of 2026-11-09: vendors, trainers, the auction house, loot, quest
-- rewards and recipes arriving in the bags.
DB.KINDS = { vendor = true, trainer = true, ah = true, drop = true, quest = true, bags = true }

-- At most this many things set aside, the oldest going first (counted in meta.setAsideDropped): only a broken file or a
-- bug writing nonsense every session fills it.
DB.SET_ASIDE_MAX = 500
-- The notebook's own history: its last events.
DB.HISTORY_MAX = 20

-- Shared/Core.lua's, which KaLi Quest's saved data uses too: a copy all the way down, how many keys a table holds, and
-- a number the file can hold, read from how it prints, not by comparing it (the game's Lua compares nan as equal to
-- itself and to everything: found by /kr test in game, 2026-11-10).
local deepCopy, count, finite = ns.DeepCopy, ns.Count, ns.Finite
DB.Finite = finite

local function isID(v)
    return finite(v) and v > 0 and v < 2 ^ 31 and math.floor(v) == v
end
DB.IsID = isID

local function tableOr(v)
    return type(v) == "table" and v or {}
end

-- ---------- Sightings: one per place ----------

-- A sighting's place, which makes it one: the same NPC for vendors, trainers and loot, the same quest for rewards,
-- one for the auction house and one for the bags. A kind a later version added: its NPC, quest and first date, so the
-- same sighting in two copies is still one. Part of the saved format: a change needs a step.
function DB.PlaceKey(s)
    local k = s.k
    if k == "vendor" or k == "trainer" or k == "drop" then
        return k .. ":" .. tostring(s.npc)
    elseif k == "quest" then
        return k .. ":" .. tostring(s.q)
    elseif k == "ah" or k == "bags" then
        return k
    end
    return tostring(k) .. ":" .. tostring(s.npc) .. ":" .. tostring(s.q) .. "@" .. tostring(s.t0 or s.t)
end

local function firstDate(s)
    return finite(s.t0) and s.t0 or s.t
end

-- A vendor's stock from two readings: the highest, -1 (no limit) below any count; nil when neither read one.
function DB.MaxStock(a, b)
    if a == nil or b == nil then
        return a == nil and b or a
    end
    return math.max(a, b)
end

-- Two sightings of one place as one, as Model's Note keeps a place seen again: the first date the earliest, the last the
-- latest, and from the latest visit its fields, its position when it has one and its price when it read one. Neither
-- is changed.
function DB.MergeSighting(a, b)
    local new, old = a, b
    if b.t > a.t then
        new, old = b, a
    end
    local out = deepCopy(old)
    for k, v in pairs(new) do
        out[k] = deepCopy(v)
    end
    local place = new.map ~= nil and new or old
    out.map, out.x, out.y = place.map, place.x, place.y
    local priced = (new.cost ~= nil or new.costs ~= nil) and new or old
    out.cost, out.costs = priced.cost, deepCopy(priced.costs)
    out.stock = DB.MaxStock(a.stock, b.stock)
    out.t0 = math.min(firstDate(a), firstDate(b))
    out.t = new.t
    return out
end

-- ---------- The notebook's history ----------

function DB.Event(db, now, what, fields)
    local e = fields and deepCopy(fields) or {}
    e.t, e.what, e.by = now, what, ns.VERSION
    local h = db.meta.history
    h[#h + 1] = e
    while #h > DB.HISTORY_MAX do
        table.remove(h, 1)
    end
end

-- ---------- Upgrades ----------

-- Step n turns version n - 1 into version n, on the copy Load works on. A released step never changes, and reads no
-- table that may change later (DEFAULTS, KINDS): what it needs is written in it. A new format adds a step, a
-- fixture (KaLiRecipe_Tests/Fixtures.lua) and a line in docs/saved-data.md.
DB.STEPS = {
    [1] = function(db)
        db.chars = db.chars or {}
        db.sightings = db.sightings or {}
    end,
    -- 2026-11-10. Version 1 wrote every option, defaults too, so a default changed later never reached a player: what
    -- equals version 1's default goes, and the two options version 1 dropped that day. The notebook gets its own name,
    -- dates and history, a mark for each recipe forgotten (so a copy can't bring it back) and a place for what is set
    -- aside.
    [2] = function(db, now)
        local v1 = { chat = true, mKnown = true, mLearnable = true, mTooLow = true, mOwned = true, mAlt = true, mVendor = true,
            mCraft = true, mCraftSeen = true, recipeTip = "detailed", usedIn = true, usedInSeen = true, usedInMax = 10,
            style = "clean", follow = false, width = 560, height = 820, nbOwned = true, nbAlt = true, a1 = true, a2 = true,
            showZero = true, pins = true, soundRecipe = "quill", soundPlace = "stroke" }
        if type(db.options) == "table" then
            for key, v in pairs(v1) do
                if db.options[key] == v then
                    db.options[key] = nil
                end
            end
            db.options.usedInWhere, db.options.nbHoldText = nil, nil
        end
        local created = now
        for _, list in pairs(tableOr(db.sightings)) do
            for _, s in pairs(tableOr(list)) do
                local t = type(s) == "table" and (s.t0 or s.t)
                if finite(t) and t < created then
                    created = t
                end
            end
        end
        if db.meta == nil then
            db.meta = { created = created, history = {} }
        end
        if db.forgotten == nil then
            db.forgotten = {}
        end
        if db.setAside == nil then
            db.setAside = {}
        end
    end,
}

-- ---------- Loading ----------

-- A list's entries in order. What isn't under a whole number is set aside: a list with holes or names in it is broken.
local function listOf(t, where, aside)
    local keys, out = {}, {}
    for k, v in pairs(t) do
        if finite(k) and k >= 1 and math.floor(k) == k then
            keys[#keys + 1] = k
        else
            aside(where .. "." .. tostring(k), "not in the list", v)
        end
    end
    table.sort(keys)
    for i, k in ipairs(keys) do
        out[i] = t[k]
    end
    return out
end

-- A set of IDs { [id] = true }, or of counts { [id] = n }. These are caches the game fills again (the character's
-- recipes, bags and bank at its next login, required ranks at a trainer), so what is wrong in them is dropped.
local function cleanSet(t, counts)
    local out, fixed = {}, 0
    for k, v in pairs(tableOr(t)) do
        if isID(k) and (counts and finite(v) and v > 0 or not counts and v == true) then
            out[k] = v
        else
            fixed = fixed + 1
        end
    end
    return out, fixed
end

-- A frame's anchor points, the only names SetPoint takes.
local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true,
    BOTTOM = true, BOTTOMRIGHT = true }

-- The tables the code reads, there and of the right kind, and options and window state it can use. Not an upgrade:
-- it fills gaps, and sets aside a value it can't use.
function DB.Shape(db, aside, now)
    for _, key in ipairs({ "sightings", "chars", "reqs", "cats", "names", "forgotten", "options", "ui", "meta" }) do
        if type(db[key]) ~= "table" then
            if db[key] ~= nil then
                aside(key, "not a table", db[key])
            end
            db[key] = {}
        end
    end
    local meta = db.meta
    if type(meta.id) ~= "string" then
        meta.id = string.format("%x-%x", math.floor(now), math.random(0, 0x7fffffff))
    end
    if not finite(meta.created) then
        meta.created = now
    end
    if type(meta.history) ~= "table" then
        meta.history = {}
    end
    -- Options: a value this version can't use is set aside and the default reads through. An option it doesn't have
    -- stays, untouched: a later version's.
    local o = db.options
    for key, default in pairs(DB.DEFAULTS) do
        local v = o[key]
        if v ~= nil then
            if type(v) ~= type(default) or (type(v) == "number" and not finite(v)) then
                aside("options." .. key, "not a " .. type(default), v)
                o[key] = nil
            elseif DB.CHOICES[key] and not DB.CHOICES[key][v] then
                aside("options." .. key, "not a choice of this version", v)
                o[key] = nil
            elseif DB.RANGES[key] then
                local range = DB.RANGES[key]
                o[key] = math.max(range[1], math.min(range[2], math.floor(v + 0.5)))
            end
        end
    end
    -- The window's state: what doesn't fit goes back to its default, as the window would put it.
    local ui = db.ui
    ui.open = tableOr(ui.open)
    for section, default in pairs({ learn = true, seen = true, known = false }) do
        if type(ui.open[section]) ~= "boolean" then
            ui.open[section] = default
        end
    end
    ui.closedCats = tableOr(ui.closedCats)
    if ui.skill ~= nil and not isID(ui.skill) then
        ui.skill = nil
    end
    -- The notebook's place: x, y, and the anchor points the window gave (SetPoint fails on any other name).
    local pos = ui.pos
    if pos ~= nil and not (type(pos) == "table" and finite(pos[1]) and finite(pos[2]) and (pos[3] == nil or POINTS[pos[3]])
        and (pos[4] == nil or POINTS[pos[4]])) then
        ui.pos = nil
    end
    -- The minimap button's place: an angle in degrees around the minimap.
    if ui.minimap ~= nil then
        ui.minimap = finite(ui.minimap) and ui.minimap % 360 or nil
    end
end

-- A sighting of a kind this version knows: its fields readable, or cleared. Returns the names of those cleared.
local function cleanSighting(s)
    local bad = {}
    for _, field in ipairs({ "npc", "map", "q", "item" }) do
        if s[field] ~= nil and not isID(s[field]) then
            s[field] = nil
            bad[#bad + 1] = field
        end
    end
    if (s.x ~= nil or s.y ~= nil) and not (finite(s.x) and finite(s.y)) then
        s.x, s.y = nil, nil
        bad[#bad + 1] = "x, y"
    end
    -- A vendor's stock: -1 for no limit, else the count it had.
    if s.stock ~= nil and not (finite(s.stock) and s.stock >= -1) then
        s.stock = nil
        bad[#bad + 1] = "stock"
    end
    -- A vendor's price: copper, and the tokens or items of an extended cost.
    if s.cost ~= nil and not (finite(s.cost) and s.cost >= 0) then
        s.cost = nil
        bad[#bad + 1] = "cost"
    end
    if s.costs ~= nil then
        local clean = {}
        for _, c in pairs(type(s.costs) == "table" and s.costs or {}) do
            if type(c) == "table" and finite(c.n) then
                c.item = isID(c.item) and c.item or nil
                c.currency = isID(c.currency) and c.currency or nil
                c.tex = finite(c.tex) and c.tex or nil
                clean[#clean + 1] = c
            end
        end
        if type(s.costs) ~= "table" or #clean ~= count(s.costs) then
            bad[#bad + 1] = "costs"
        end
        s.costs = #clean > 0 and clean or nil
    end
    return #bad > 0 and table.concat(bad, ", ") or nil
end

-- Keeps what was noted usable whatever happened to the file. A sighting it can't read is set aside; one of a kind it
-- doesn't know is kept as it is; two of one place become one. Returns how many things it fixed.
function DB.Repair(db, aside)
    local fixed = 0
    local sightings = {}
    for spell, list in pairs(db.sightings) do
        local where = "sightings." .. tostring(spell)
        if not isID(spell) then
            aside(where, "not a recipe number", list)
        elseif type(list) ~= "table" then
            aside(where, "not a list", list)
        else
            local keep, at = {}, {}
            for i, s in ipairs(listOf(list, where, aside)) do
                local here = where .. "[" .. i .. "]"
                if type(s) ~= "table" then
                    aside(here, "not a sighting", s)
                elseif not finite(s.t) then
                    aside(here, "no date", s)
                elseif type(s.k) ~= "string" then
                    aside(here, "no kind", s)
                else
                    if DB.KINDS[s.k] then
                        local original = deepCopy(s)
                        local bad = cleanSighting(s)
                        if bad then
                            aside(here, "unreadable " .. bad, original)
                        end
                    end
                    if s.t0 ~= nil and not finite(s.t0) then
                        s.t0 = nil
                    end
                    if s.t0 == nil then
                        s.t0 = s.t
                        fixed = fixed + 1
                    end
                    local key = DB.PlaceKey(s)
                    if at[key] then
                        keep[at[key]] = DB.MergeSighting(keep[at[key]], s)
                        fixed = fixed + 1
                    else
                        keep[#keep + 1] = s
                        at[key] = #keep
                    end
                end
            end
            if #keep > 0 then
                sightings[spell] = keep
            end
        end
    end
    db.sightings = sightings
    local chars = {}
    for key, c in pairs(db.chars) do
        if type(key) ~= "string" then
            aside("chars." .. tostring(key), "not a character's key", c)
        elseif type(c) ~= "table" then
            aside("chars." .. key, "not a character", c)
        else
            local n
            c.known, n = cleanSet(c.known)
            fixed = fixed + n
            c.bags, n = cleanSet(c.bags, true)
            fixed = fixed + n
            c.bank, n = cleanSet(c.bank, true)
            fixed = fixed + n
            c.profs, n = cleanSet(c.profs, true)
            fixed = fixed + n
            c.maxRanks = cleanSet(c.maxRanks, true)
            if type(c.name) ~= "string" then
                c.name = "?"
            end
            if c.seen ~= nil and not finite(c.seen) then
                c.seen = nil
            end
            if c.bankSeen ~= nil and not finite(c.bankSeen) then
                c.bankSeen = nil
            end
            chars[key] = c
        end
    end
    db.chars = chars
    local n
    db.reqs, n = cleanSet(db.reqs, true)
    fixed = fixed + n
    db.cats, n = cleanSet(db.cats, true)
    fixed = fixed + n
    db.forgotten, n = cleanSet(db.forgotten, true)
    fixed = fixed + n
    -- Names the game gave, per language: { [locale] = { [kind] = { [id] = name } } }. A cache, met again in game.
    local names = {}
    for locale, kinds in pairs(db.names) do
        if type(locale) == "string" and type(kinds) == "table" then
            names[locale] = {}
            for kind, ids in pairs(kinds) do
                if type(kind) == "string" and type(ids) == "table" then
                    local clean = {}
                    for id, name in pairs(ids) do
                        if isID(id) and type(name) == "string" then
                            clean[id] = name
                        else
                            fixed = fixed + 1
                        end
                    end
                    names[locale][kind] = clean
                else
                    fixed = fixed + 1
                end
            end
        else
            fixed = fixed + 1
        end
    end
    db.names = names
    return fixed
end

-- Returns the data to use, how many things Repair fixed and how many it set aside; or nil and a reason when the saved
-- table must be left untouched. The data is always a new table, so the caller stores what this returns.
function DB.Load(saved, now)
    now = now or time()
    local fresh = saved == nil
    if fresh then
        saved = {}
    elseif type(saved) ~= "table" then
        return nil, "not a table"
    end
    local version = saved.version or 0
    if not finite(version) or version < 0 or math.floor(version) ~= version then
        return nil, "bad version"
    end
    if version > DB.VERSION then
        return nil, "version " .. version .. " > " .. DB.VERSION
    end
    local data = deepCopy(saved)
    for v = version + 1, DB.VERSION do
        local ok, err = pcall(DB.STEPS[v], data, now)
        if not ok then
            return nil, "step " .. v .. ": " .. tostring(err)
        end
        data.version = v
    end
    local ok, fixed, setAside = pcall(function()
        local list = {}
        if type(data.setAside) == "table" then
            for _, e in ipairs(listOf(data.setAside, "setAside", function(at, why, v)
                list[#list + 1] = { t = now, at = at, why = why, v = v }
            end)) do
                list[#list + 1] = type(e) == "table" and e or { t = now, at = "setAside", why = "not an entry", v = e }
            end
        elseif data.setAside ~= nil then
            list[1] = { t = now, at = "setAside", why = "not a list", v = data.setAside }
        end
        data.setAside = list
        local n = 0
        local function aside(at, why, v)
            list[#list + 1] = { t = now, at = at, why = why, v = deepCopy(v) }
            n = n + 1
        end
        DB.Shape(data, aside, now)
        local repaired = DB.Repair(data, aside)
        local dropped = 0
        while #list > DB.SET_ASIDE_MAX do
            table.remove(list, 1)
            dropped = dropped + 1
        end
        if dropped > 0 then
            data.meta.setAsideDropped = (finite(data.meta.setAsideDropped) and data.meta.setAsideDropped or 0) + dropped
        end
        if fresh then
            DB.Event(data, now, "created")
        elseif version < DB.VERSION then
            DB.Event(data, now, "upgraded", { from = version, to = DB.VERSION })
        end
        if n > 0 then
            DB.Event(data, now, "set aside", { n = n })
        end
        return repaired, n
    end)
    if not ok then
        return nil, "repair: " .. tostring(fixed)
    end
    setmetatable(data.options, OPTIONS)
    return data, fixed, setAside
end

-- ---------- Copies: the character's, and later an import ----------

-- Another copy of a notebook into this one, both loaded: every sighting either holds, one per place; a recipe
-- forgotten in either stays forgotten for what was seen before; each character's latest record; names, required
-- ranks and categories this one lacks. settings: the other's options too, where this one has none (a notebook started
-- over). The other is left as it was. Returns how many sightings came in or changed, and how many characters.
function DB.Merge(into, from, settings)
    local sightings, chars = 0, 0
    for spell, t in pairs(from.forgotten) do
        if (into.forgotten[spell] or 0) < t then
            into.forgotten[spell] = t
        end
    end
    for spell, list in pairs(from.sightings) do
        local gone = into.forgotten[spell]
        local mine = into.sightings[spell]
        local at = {}
        for i, s in ipairs(mine or {}) do
            at[DB.PlaceKey(s)] = i
        end
        for _, s in ipairs(list) do
            if not (gone and s.t <= gone) then
                local key = DB.PlaceKey(s)
                local i = at[key]
                if not i then
                    if not mine then
                        mine = {}
                        into.sightings[spell] = mine
                    end
                    mine[#mine + 1] = deepCopy(s)
                    at[key] = #mine
                    sightings = sightings + 1
                elseif s.t > mine[i].t or firstDate(s) < firstDate(mine[i]) then
                    mine[i] = DB.MergeSighting(mine[i], s)
                    sightings = sightings + 1
                end
            end
        end
    end
    -- What was seen before a recipe was forgotten goes, wherever it came from.
    for spell, gone in pairs(into.forgotten) do
        local list = into.sightings[spell]
        if list then
            local keep = {}
            for _, s in ipairs(list) do
                if s.t > gone then
                    keep[#keep + 1] = s
                end
            end
            into.sightings[spell] = #keep > 0 and keep or nil
        end
    end
    for key, c in pairs(from.chars) do
        local mine = into.chars[key]
        if not mine or (c.seen or 0) > (mine.seen or 0) then
            into.chars[key] = deepCopy(c)
            chars = chars + 1
        end
    end
    for locale, kinds in pairs(from.names) do
        into.names[locale] = into.names[locale] or {}
        for kind, ids in pairs(kinds) do
            local t = into.names[locale][kind] or {}
            into.names[locale][kind] = t
            for id, name in pairs(ids) do
                if t[id] == nil then
                    t[id] = name
                end
            end
        end
    end
    for _, key in ipairs({ "reqs", "cats" }) do
        for id, v in pairs(from[key]) do
            if into[key][id] == nil then
                into[key][id] = v
            end
        end
    end
    if settings then
        for key, v in pairs(from.options) do
            if rawget(into.options, key) == nil then
                into.options[key] = deepCopy(v)
            end
        end
    end
    return sightings, chars
end

-- What the current character's file keeps: the whole notebook as it is written, who keeps it and when.
function DB.Copy(db, owner, now)
    return { owner = owner, at = now, writer = ns.VERSION, data = deepCopy(db) }
end

-- The notebook to use at startup, from the account's file and the current character's copy. Returns it and what
-- happened, or nil and why the account's file can't be used: both are then left untouched.
-- info: fixed and setAside, by loading; firstRun; restored { at, recipes } when the account's file was missing and the
-- copy brought the notebook back; recovered, the sightings and characters the copy added; copy { at, writer, recipes };
-- copyRefused, why the copy can't be read (it then stays as it is, and isn't written over).
function DB.Open(account, copy, now)
    now = now or time()
    local data, fixed, setAside = DB.Load(account, now)
    if not data then
        return nil, fixed
    end
    local info = { fixed = fixed, setAside = setAside, recovered = 0 }
    local other
    if type(copy) == "table" and copy.data ~= nil then
        local why
        other, why = DB.Load(copy.data, now)
        if other then
            info.copy = { at = finite(copy.at) and copy.at or nil, writer = copy.writer, recipes = count(other.sightings) }
        else
            info.copyRefused = why
        end
    end
    if other and account == nil then
        data = other
        info.restored = { at = info.copy.at, recipes = info.copy.recipes }
        DB.Event(data, now, "restored", { from = "copy", at = info.copy.at })
    elseif other then
        local startedOver = info.copy.at ~= nil and data.meta.created > info.copy.at
        local s, c = DB.Merge(data, other, startedOver)
        info.recovered = s + c
        if s + c > 0 then
            DB.Event(data, now, "merged", { from = "copy", sightings = s, chars = c })
        end
    end
    info.firstRun = account == nil and not info.restored
    return data, info
end

-- ---------- Saving ----------

-- At logout, the last event before the game writes the files: options back at their default go, no number the file
-- can't hold stays (a nan or an inf would make the file unreadable: Shared/Core.lua's DropNonFinite), and the file says
-- who wrote it and when.
function DB.BeforeSave(db, now)
    -- nan and inf first: the game's Lua finds a nan equal to every number, so the defaults below would take it for
    -- one left at its default, and it would go uncounted (found by /kr test, 2026-11-11).
    local n = ns.DropNonFinite(db)
    if n > 0 then
        db.meta.nonFinite = (finite(db.meta.nonFinite) and db.meta.nonFinite or 0) + n
    end
    local o = db.options
    for key, default in pairs(DB.DEFAULTS) do
        if rawget(o, key) == default then
            o[key] = nil
        end
    end
    db.meta.writer, db.meta.written = ns.VERSION, now
end

-- ---------- Names ----------

-- A per-language cache of names the game gave: NPCs and quests, which no function names again from their number
-- alone. Keyed by number; a client in another language starts its own.
function DB.Name(db, kind, id)
    local byLocale = db.names[ns.LOCALE]
    local t = byLocale and byLocale[kind]
    return t and t[id]
end

function DB.SetName(db, kind, id, name)
    if not (isID(id) and type(name) == "string" and name ~= "") then
        return
    end
    db.names[ns.LOCALE] = db.names[ns.LOCALE] or {}
    local byLocale = db.names[ns.LOCALE]
    byLocale[kind] = byLocale[kind] or {}
    byLocale[kind][id] = name
end
