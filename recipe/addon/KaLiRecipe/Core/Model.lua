-- What the notebook knows, decided here and only here: each recipe's state for a character, the two counts, the
-- lists and their categories, who knows and who holds what, « Utilisé dans » and « Fabriqué par ». Pure: it reads the
-- saved table, the generated data and a game object (names, the current character's item counts), so the tests run it
-- on fakes. Nothing never met can show: every list starts from the recipes seen or known.
local _, ns = ...

local Model = {}
ns.Model = Model

local M = {}
M.__index = M

local EMPTY = {}
-- The game's secondary professions, after the main ones, as the professions book lists them: cooking, first aid,
-- fishing.
local SECONDARY = { [185] = 1, [129] = 2, [356] = 3 }
Model.SECONDARY = SECONDARY

-- data: { recipes, items, categories, categoryNames }: ns.RECIPES, ns.RECIPE_ITEMS, ns.CATEGORIES and this
-- language's ns.CATEGORY_NAMES. me: the current character's key.
function Model.New(db, data, game, me)
    return setmetatable({ db = db, data = data, game = game, me = me, cache = {}, index = nil }, M)
end

-- After anything noted, learned or moved between bags: lists and counts are made again on demand.
function M:Invalidate()
    self.cache = {}
end

local function cached(self, key, make)
    local v = self.cache[key]
    if v == nil then
        v = make()
        self.cache[key] = v
    end
    return v
end

-- The data's reverse links, made once: which items teach a spell, which recipes make or use an item.
local function index(self)
    if self.index then
        return self.index
    end
    local teach, product, reagent = {}, {}, {}
    for item, spell in pairs(self.data.items) do
        local list = teach[spell]
        if not list then
            list = {}
            teach[spell] = list
        end
        list[#list + 1] = item
    end
    for _, list in pairs(teach) do
        table.sort(list)
    end
    for spell, row in pairs(self.data.recipes) do
        if row[6] and row[6] ~= 0 then
            product[row[6]] = product[row[6]] or {}
            table.insert(product[row[6]], spell)
        end
        for i = 7, #row, 2 do
            reagent[row[i]] = reagent[row[i]] or {}
            table.insert(reagent[row[i]], spell)
        end
    end
    self.index = { teach = teach, product = product, reagent = reagent }
    return self.index
end

-- ---------- Recipes ----------

function M:IsRecipe(spell)
    return self.data.recipes[spell] ~= nil
end

function M:SpellForItem(item)
    return self.data.items[item]
end

-- The items that teach a recipe, lowest number first; empty for a trainer's.
function M:ItemsForSpell(spell)
    return index(self).teach[spell] or EMPTY
end

-- { spell, skill, req, yellow, gray, cat, product, reagents = { { item, count } }, item }. The required rank a trainer
-- gave wins over the recipe item's, as the trainer's is the server's own; nil when neither is known.
function M:Info(spell)
    local all = self.cache.info
    if not all then
        all = {}
        self.cache.info = all
    end
    local info = all[spell]
    if info then
        return info
    end
    local row = self.data.recipes[spell]
    if not row then
        return nil
    end
    info = { spell = spell, skill = row[1], yellow = row[3], gray = row[4], reagents = {} }
    info.product = row[6] ~= 0 and row[6] or nil
    for i = 7, #row, 2 do
        info.reagents[#info.reagents + 1] = { row[i], row[i + 1] }
    end
    info.req = self.db.reqs[spell] or (row[2] > 0 and row[2] or nil)
    info.cat = self.db.cats[spell] or (row[5] ~= 0 and row[5] or nil)
    info.item = self:ItemsForSpell(spell)[1]
    all[spell] = info
    return info
end

-- The recipe's name as the professions window gives it, or what it makes, or its number.
function M:Name(spell)
    local name = self.game:SpellName(spell)
    if name and name ~= "" then
        return name
    end
    local info = self:Info(spell)
    local item = info and (info.product or info.item)
    return item and self.game:ItemName(item) or ("#" .. tostring(spell))
end

-- ---------- Characters ----------

function M:Char(key)
    return self.db.chars[key]
end

function M:CharName(key)
    local c = self.db.chars[key]
    return c and c.name or "?"
end

-- Every character the addon has seen log in: the current one first, then by name.
function M:CharKeys()
    return cached(self, "chars", function()
        local keys = {}
        for key in pairs(self.db.chars) do
            if key ~= self.me then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys, function(a, b)
            return ns.TextLess(self:CharName(a), self:CharName(b))
        end)
        if self.db.chars[self.me] then
            table.insert(keys, 1, self.me)
        end
        return keys
    end)
end

function M:Knows(key, spell)
    local c = self.db.chars[key]
    return c ~= nil and c.known[spell] == true
end

function M:HasProf(key, skill)
    local c = self.db.chars[key]
    return c ~= nil and c.profs[skill] ~= nil
end

function M:Rank(key, skill)
    local c = self.db.chars[key]
    return c and c.profs[skill] or 0
end

function M:MaxRank(key, skill)
    local c = self.db.chars[key]
    return c and c.maxRanks[skill] or 0
end

-- A character's professions as the game lists them: main ones first, then cooking, first aid and fishing.
function M:ProfsOf(key)
    local c = self.db.chars[key]
    local list = {}
    for skill in pairs(c and c.profs or EMPTY) do
        list[#list + 1] = skill
    end
    table.sort(list, function(a, b)
        local sa, sb = SECONDARY[a] or 0, SECONDARY[b] or 0
        if sa ~= sb then
            return sa < sb
        end
        return a < b
    end)
    return list
end

-- The characters who know a recipe, the current one first.
function M:Knowers(spell)
    local out = {}
    for _, key in ipairs(self:CharKeys()) do
        if self:Knows(key, spell) then
            out[#out + 1] = key
        end
    end
    return out
end

-- How many of an item a character holds: bags, bank, total. The addon keeps recipe items only.
function M:Holds(key, item)
    local c = self.db.chars[key]
    local bags = c and c.bags[item] or 0
    local bank = c and c.bank[item] or 0
    return bags, bank, bags + bank
end

-- Who holds a recipe's items, the current character apart: mine = { bags, bank, total } or nil, alts = { { key,
-- bags, bank, total } }. Nil when nobody does.
function M:Possession(spell, key)
    key = key or self.me
    local items = self:ItemsForSpell(spell)
    if #items == 0 then
        return nil
    end
    local mine, alts = nil, {}
    for _, k in ipairs(self:CharKeys()) do
        local bags, bank = 0, 0
        for _, item in ipairs(items) do
            local b, k2 = self:Holds(k, item)
            bags, bank = bags + b, bank + k2
        end
        if bags + bank > 0 then
            local h = { key = k, bags = bags, bank = bank, total = bags + bank }
            if k == key then
                mine = h
            else
                alts[#alts + 1] = h
            end
        end
    end
    if mine or #alts > 0 then
        return { mine = mine, alts = alts }
    end
    return nil
end

-- ---------- Sightings ----------

-- A recipe's sightings of the kinds this version knows. One of a kind a later version added stays in the saved data,
-- untouched, and is left out here (docs/saved-data.md).
function M:Sightings(spell)
    local list = self.db.sightings[spell]
    if not list then
        return EMPTY
    end
    local usable = self.cache.usable
    if not usable then
        usable = {}
        self.cache.usable = usable
    end
    local out = usable[spell]
    if out then
        return out
    end
    out = list
    for _, s in ipairs(list) do
        if not ns.DB.KINDS[s.k] then
            out = {}
            for _, s2 in ipairs(list) do
                if ns.DB.KINDS[s2.k] then
                    out[#out + 1] = s2
                end
            end
            break
        end
    end
    usable[spell] = out
    return out
end

function M:Seen(spell)
    return #self:Sightings(spell) > 0
end

-- One sighting per place (DB.PlaceKey): seen again, it keeps its first date and takes the new one.
-- s = { k, npc, map, x, y, q, item, and at a vendor cost (copper), costs ({ n, item or currency, tex }) and stock (how
-- many it had left, -1 for no limit) }. Returns
-- true when it's new, and what was new: "recipe" when the notebook didn't hold it at all (never seen, known by none of
-- the characters), "place" when it did and this is a new place for it.
function M:Note(spell, s, now)
    if not (self.data.recipes[spell] and ns.DB.KINDS[s.k]) then
        return false
    end
    local what = (self:Seen(spell) or #self:Knowers(spell) > 0) and "place" or "recipe"
    local list = self.db.sightings[spell]
    if not list then
        list = {}
        self.db.sightings[spell] = list
    end
    local key = ns.DB.PlaceKey(s)
    for _, old in ipairs(list) do
        if ns.DB.PlaceKey(old) == key then
            old.t = now
            if s.map then
                old.map, old.x, old.y = s.map, s.x, s.y
            end
            -- A vendor's or trainer's price as last seen: a reputation's discount changes it. None read: the old one
            -- stays.
            if s.cost or s.costs then
                old.cost, old.costs = s.cost, s.costs
            end
            -- A vendor's stock: the highest seen, so a limited one stays known as limited (Ikar, 2026-11-13: "store the
            -- higher number in case of update ... the moment to moment has no value").
            old.stock = ns.DB.MaxStock(old.stock, s.stock)
            return false
        end
    end
    s.t, s.t0 = now, now
    list[#list + 1] = s
    self:Invalidate()
    return true, what
end

-- A recipe noted by mistake. Its mark (forgotten) keeps a copy of the notebook from bringing back what was seen before
-- now; seen again later, it's noted again. Returns whether there was anything to forget.
function M:Forget(spell, now)
    if not self.db.sightings[spell] then
        return false
    end
    self.db.sightings[spell] = nil
    now = now or time()
    self.db.forgotten[spell] = math.max(now, self.db.forgotten[spell] or 0)
    self:Invalidate()
    return true
end

function M:Sources(spell)
    local set = {}
    for _, s in ipairs(self:Sightings(spell)) do
        set[s.k] = true
    end
    return set
end

-- ---------- States and counts ----------

-- "known", "learnable" (this character's rank is enough), "toolow", or "other" (a profession it doesn't have).
function M:State(spell, key)
    key = key or self.me
    if self:Knows(key, spell) then
        return "known"
    end
    local info = self:Info(spell)
    if not info or not self:HasProf(key, info.skill) then
        return "other"
    end
    return self:Rank(key, info.skill) >= (info.req or 0) and "learnable" or "toolow"
end

-- The professions window's colours for a rank: "red" (rank too low), "optimal", "medium", "easy", "trivial".
function M:Difficulty(spell, rank, known)
    local info = self:Info(spell)
    if not info then
        return "trivial"
    end
    if not known and rank < (info.req or 0) then
        return "red"
    end
    local yellow, gray = info.yellow or 0, info.gray or 0
    if gray <= 0 or rank < yellow then
        return "optimal"
    elseif rank < math.floor((yellow + gray) / 2 + 0.5) then
        return "medium"
    elseif rank < gray then
        return "easy"
    end
    return "trivial"
end

-- Every recipe the notebook holds for a profession: seen somewhere, or known by one of the characters.
function M:SpellsOf(skill)
    return cached(self, "of" .. skill, function()
        local set, list = {}, {}
        local function add(spell)
            local info = not set[spell] and self:Info(spell)
            if info and info.skill == skill then
                set[spell] = true
                list[#list + 1] = spell
            end
        end
        for spell in pairs(self.db.sightings) do
            if self:Seen(spell) then
                add(spell)
            end
        end
        for _, c in pairs(self.db.chars) do
            for spell in pairs(c.known) do
                add(spell)
            end
        end
        table.sort(list)
        return list
    end)
end

-- The notebook's three sections for a character: « À apprendre » (seen, not known, learnable now), « Vues » (seen,
-- not known, rank too low or another profession) and « Appris » (known by any character).
function M:Split(key, skill)
    key = key or self.me
    return cached(self, "split" .. tostring(key) .. ":" .. skill, function()
        local learn, seen, known = {}, {}, {}
        for _, spell in ipairs(self:SpellsOf(skill)) do
            if self:Seen(spell) and not self:Knows(key, spell) then
                if self:State(spell, key) == "learnable" then
                    learn[#learn + 1] = spell
                else
                    seen[#seen + 1] = spell
                end
            end
            if #self:Knowers(spell) > 0 then
                known[#known + 1] = spell
            end
        end
        return { learn = learn, seen = seen, known = known }
    end)
end

-- « 7 à apprendre · 4 vues »: the two numbers, for a profession.
function M:Counts(key, skill)
    local s = self:Split(key, skill)
    return #s.learn, #s.seen
end

-- Professions this character lacks with something in the notebook: seen recipes, or another character's.
function M:Others(key)
    key = key or self.me
    local mine, set, list = {}, {}, {}
    for _, skill in ipairs(self:ProfsOf(key)) do
        mine[skill] = true
    end
    local function add(skill)
        if skill and not mine[skill] and not set[skill] then
            set[skill] = true
            list[#list + 1] = skill
        end
    end
    for spell in pairs(self.db.sightings) do
        local info = self:Seen(spell) and self:Info(spell)
        add(info and info.skill)
    end
    for k, c in pairs(self.db.chars) do
        if k ~= key then
            for skill in pairs(c.profs) do
                add(skill)
            end
        end
    end
    table.sort(list)
    return list
end

-- Seen recipes this character doesn't know, of professions it lacks: the « Autres métiers » line.
function M:OtherSeen(key)
    local n = 0
    for _, skill in ipairs(self:Others(key)) do
        local _, seen = self:Counts(key, skill)
        n = n + seen
    end
    return n
end

-- Everything in the notebook, for its footer.
function M:Total()
    return cached(self, "total", function()
        local set, n = {}, 0
        local function add(spell)
            if not set[spell] and self:IsRecipe(spell) then
                set[spell] = true
                n = n + 1
            end
        end
        for spell in pairs(self.db.sightings) do
            if self:Seen(spell) then
                add(spell)
            end
        end
        for _, c in pairs(self.db.chars) do
            for spell in pairs(c.known) do
                add(spell)
            end
        end
        return n
    end)
end

-- ---------- Categories ----------

-- The category's name: the game's when it gives one, else the data's for this language, else « Divers ».
function M:CategoryName(cat)
    if not cat then
        return ns.G("MISCELLANEOUS", "Divers")
    end
    return self.game:CategoryName(cat) or (self.data.categoryNames or EMPTY)[cat] or ns.G("MISCELLANEOUS", "Divers")
end

-- The professions window's order: the parent's place, then the category's own. « Divers » last.
local function categoryRank(self, cat)
    local c = cat and self.data.categories[cat]
    if not c then
        return 1e9, 1e9
    end
    local parent = self.data.categories[c[1]]
    return parent and parent[2] or 0, c[2]
end

-- Recipes grouped by category in the game's order, each group's recipes by required rank, then name:
-- { { id, name, spells } }.
function M:ByCategory(spells)
    local groups, order = {}, {}
    for _, spell in ipairs(spells) do
        local info = self:Info(spell)
        local cat = info and info.cat and self.data.categories[info.cat] and info.cat or false
        local g = groups[cat]
        if not g then
            g = { id = cat or nil, name = self:CategoryName(cat or nil), spells = {} }
            g.p, g.o = categoryRank(self, cat or nil)
            groups[cat] = g
            order[#order + 1] = g
        end
        g.spells[#g.spells + 1] = spell
    end
    table.sort(order, function(a, b)
        if a.p ~= b.p then
            return a.p < b.p
        elseif a.o ~= b.o then
            return a.o < b.o
        end
        return ns.TextLess(a.name, b.name)
    end)
    for _, g in ipairs(order) do
        local names = {}
        for _, spell in ipairs(g.spells) do
            names[spell] = self:Name(spell)
        end
        table.sort(g.spells, function(a, b)
            local ra, rb = self:Info(a).req or 0, self:Info(b).req or 0
            if ra ~= rb then
                return ra < rb
            end
            if names[a] ~= names[b] then
                return ns.TextLess(names[a], names[b])
            end
            return a < b
        end)
    end
    return order
end

-- The categories a profession's recipes in the notebook fall into, for the filter menu.
function M:CategoriesOf(skill)
    local groups = self:ByCategory(self:SpellsOf(skill))
    local out = {}
    for _, g in ipairs(groups) do
        out[#out + 1] = { id = g.id, name = g.name }
    end
    return out
end

-- ---------- Materials ----------

local function byName(self)
    return function(a, b)
        local na, nb = self:Name(a.spell), self:Name(b.spell)
        if na ~= nb then
            return ns.TextLess(na, nb)
        end
        return a.spell < b.spell
    end
end

-- « Utilisé dans » for a material: recipes a character knows, then recipes seen that none knows. Never another.
function M:UsedIn(item)
    local known, seen = {}, {}
    for _, spell in ipairs(index(self).reagent[item] or EMPTY) do
        local who = self:Knowers(spell)
        if #who > 0 then
            known[#known + 1] = { spell = spell, who = who }
        elseif self:Seen(spell) then
            seen[#seen + 1] = { spell = spell }
        end
    end
    table.sort(known, byName(self))
    table.sort(seen, byName(self))
    return known, seen
end

-- Every recipe in the data that makes an item, met or not: only to recognise a trainer's recipe by its item.
function M:SpellsMaking(item)
    return index(self).product[item]
end

-- « Fabriqué par » for an item: the recipes that make it that a character knows or that were seen.
function M:MadeBy(item)
    local out = {}
    for _, spell in ipairs(index(self).product[item] or EMPTY) do
        local who = self:Knowers(spell)
        local seen = self:Seen(spell)
        if #who > 0 or seen then
            out[#out + 1] = { spell = spell, who = who, seen = seen }
        end
    end
    table.sort(out, byName(self))
    return out
end

-- ---------- The game's filters, and the notebook's ----------

function M:SkillUp(spell, key)
    local info = self:Info(spell)
    return info ~= nil and self:HasProf(key, info.skill) and info.gray > 0 and self:Rank(key, info.skill) < info.gray
end

-- Every reagent in the current character's bags and bank, as the game counts them.
function M:Makeable(spell)
    local info = self:Info(spell)
    if not info or #info.reagents == 0 then
        return false
    end
    for _, r in ipairs(info.reagents) do
        if (self.game:ItemCount(r[1]) or 0) < r[2] then
            return false
        end
    end
    return true
end

local function contains(text, folded)
    return text ~= nil and ns.Fold(text):find(folded, 1, true) ~= nil
end

-- search: text, matched in the recipe's name, what it makes and its reagents, ignoring case and accents.
-- filter: { skillUp, makeable, cats = { [id or 0] = true }, sources = { [kind] = true }, owned = { mine, alt } }.
function M:Passes(spell, key, search, filter)
    local info = self:Info(spell)
    if not info then
        return false
    end
    if search and search ~= "" then
        local q = ns.Fold(search)
        local hit = contains(self:Name(spell), q) or (info.product and contains(self.game:ItemName(info.product), q))
        for _, r in ipairs(info.reagents) do
            hit = hit or contains(self.game:ItemName(r[1]), q)
        end
        if not hit then
            return false
        end
    end
    filter = filter or EMPTY
    if filter.skillUp and not self:SkillUp(spell, key) then
        return false
    end
    if filter.makeable and not self:Makeable(spell) then
        return false
    end
    -- The category as the list files it: one the data doesn't know goes under « Divers » (0), as in ByCategory.
    local cat = info.cat and self.data.categories[info.cat] and info.cat or 0
    if filter.cats and next(filter.cats) and not filter.cats[cat] then
        return false
    end
    if filter.sources and next(filter.sources) then
        local any = false
        for kind in pairs(self:Sources(spell)) do
            any = any or filter.sources[kind] == true
        end
        if not any then
            return false
        end
    end
    if filter.owned and (filter.owned.mine or filter.owned.alt) then
        local p = self:Possession(spell, key)
        if not (p and (filter.owned.mine and p.mine or filter.owned.alt and #p.alts > 0)) then
            return false
        end
    end
    return true
end

function Model.Filtered(filter)
    if type(filter) ~= "table" then
        return false
    end
    return filter.skillUp or filter.makeable or (filter.cats and next(filter.cats) ~= nil) or
        (filter.sources and next(filter.sources) ~= nil) or (filter.owned and (filter.owned.mine or filter.owned.alt)) or false
end
