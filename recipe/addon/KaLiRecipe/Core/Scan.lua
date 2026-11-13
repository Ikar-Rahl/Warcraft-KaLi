-- Where recipes are met, each read when the game opens it: vendors, trainers, the auction house, loot, quest rewards
-- and the bags; and what the character knows, from the professions window and the spellbook. Every read writes only
-- the addon's own table, through the model, and one visit makes at most one chat line.
local _, ns = ...

local Scan = {}
ns.Scan = Scan

local Game = ns.Game

-- Every handler waits for the model: events that fire while the game loads, before PLAYER_LOGIN makes it
-- (SKILL_LINES_CHANGED, BAG_UPDATE_DELAYED), or after the saved data was refused, change nothing. Scan.AtLogin reads
-- what the first ones would have.
local function on(event, fn)
    ns.On(event, function(...)
        if ns.book then
            fn(...)
        end
    end)
end

local function later(key, fn)
    ns.Later(key, function()
        if ns.book then
            fn()
        end
    end)
end

-- How each trainer recipe was recognised this session, for the API check: by the tooltip's spell, by the item it
-- makes, by its name, or not at all.
Scan.trainerStats = { tooltip = 0, product = 0, name = 0, other = 0, none = 0 }
-- The auction house: when the addon's own query went out, and whether results came after it.
Scan.ah = { queried = nil, answered = nil, refused = nil }

local function changed()
    ns.book:Invalidate()
    ns.Changed()
end

-- Notes a sighting; a new one this character doesn't know joins the visit's chat line and sound.
local function note(visit, spell, s)
    local m = ns.book
    local isNew, what = m:Note(spell, s, time())
    if isNew and visit and not m:Knows(m.me, spell) then
        visit:Add(spell, what, s)
    end
    return isNew
end

local function npcOf(unit)
    local npc = Game.NPCFromGUID(UnitGUID(unit))
    if npc then
        ns.DB.SetName(ns.db, "npc", npc, UnitName(unit))
    end
    return npc
end

-- ---------- Vendors ----------

-- What the vendor asks for slot i (Ikar, 2026-11-10: "store the cost"): the money, in copper, and each token or item
-- of an extended cost, { n, item or currency, tex }, as the merchant window reads them.
function Scan.MerchantPrice(i)
    local info = ns.Call(C_MerchantFrame and C_MerchantFrame.GetItemInfo, i)
    if type(info) ~= "table" then
        return nil, nil
    end
    local costs
    if info.hasExtendedCost then
        for c = 1, ns.Call(GetMerchantItemCostInfo, i) or 0 do
            local tex, n, link = ns.Call(GetMerchantItemCostItem, i, c)
            if type(n) == "number" and n > 0 then
                local currency = type(link) == "string" and tonumber(link:match("currency:(%d+)"))
                costs = costs or {}
                costs[#costs + 1] = { n = n, item = not currency and Game.ItemFromLink(link) or nil, currency = currency,
                    tex = type(tex) == "number" and tex or nil }
            end
        end
    end
    return (type(info.price) == "number" and info.price > 0) and info.price or nil, costs
end

-- How many the vendor has left of slot i, as the game gives it (numAvailable): -1 when there's no limit, else the
-- count, 0 once sold out. Ikar, 2026-11-13: "we should store the full information when visiting"; the notebook keeps
-- the highest seen at each vendor (Model's Note).
function Scan.MerchantStock(i)
    local info = ns.Call(C_MerchantFrame and C_MerchantFrame.GetItemInfo, i)
    local n = type(info) == "table" and info.numAvailable
    if ns.Finite(n) and n >= -1 then
        return math.floor(n)
    end
end

local merchant
local function scanMerchant()
    if not merchant then
        return
    end
    local any = false
    for i = 1, GetMerchantNumItems() or 0 do
        local item = GetMerchantItemID(i)
        local spell = item and ns.RECIPE_ITEMS[item]
        if spell then
            local cost, costs = Scan.MerchantPrice(i)
            any = note(merchant.visit, spell, { k = "vendor", npc = merchant.npc, map = merchant.map, x = merchant.x, y = merchant.y,
                item = item, cost = cost, costs = costs, stock = Scan.MerchantStock(i) }) or any
        elseif item then
            local _, _, _, _, _, classID = ns.Call(C_Item.GetItemInfoInstant, item)
            if classID == 9 then
                Game.unknownRecipeItems[item] = true
            end
        end
    end
    if any then
        changed()
    end
end

on("MERCHANT_SHOW", function()
    local npc = npcOf("npc")
    local map, x, y = Game.Spot()
    merchant = { npc = npc, map = map, x = x, y = y }
    merchant.visit = ns.Chat.Visit({ k = "vendor", npc = npc, map = map })
    scanMerchant()
end)
on("MERCHANT_UPDATE", function()
    later("merchant", scanMerchant)
end)
on("MERCHANT_CLOSED", function()
    if merchant then
        merchant.visit:Flush()
    end
    merchant = nil
end)

-- ---------- Trainers ----------

local function bySpellName(name, skill)
    local folded = ns.Fold(name)
    local found
    for spell, row in pairs(ns.RECIPES) do
        if (not skill or row[1] == skill) and ns.Fold(ns.book.game:SpellName(spell)) == folded then
            if found then
                return nil -- two recipes share the name: no guess
            end
            found = spell
        end
    end
    return found
end

-- The trainer's profession, by the skill its recipes require: the name the game gives in GetTrainerServiceSkillReq.
local function skillByName(name)
    if not name then
        return nil
    end
    local folded = ns.Fold(name)
    for skill in pairs(ns.PROFESSION_ICONS) do
        if ns.Fold(Game.ProfName(skill)) == folded then
            return skill
        end
    end
end

-- A trainer service's recipe spell: the tooltip's spell first, then the one recipe that makes its item, then its
-- name among the trainer's profession's recipes.
function Scan.TrainerSpell(i, name, skill)
    local data = ns.Call(C_TooltipInfo and C_TooltipInfo.GetTrainerService, i)
    if data and type(data.id) == "number" then
        -- A spell that isn't a recipe: the profession's next rank, a gathering skill.
        return ns.RECIPES[data.id] and data.id or nil, ns.RECIPES[data.id] and "tooltip" or "other"
    end
    local item = Game.ItemFromLink(ns.Call(GetTrainerServiceItemLink, i))
    local makers = item and ns.book:SpellsMaking(item)
    if makers then
        local fit = {}
        for _, spell in ipairs(makers) do
            if not skill or ns.RECIPES[spell][1] == skill then
                fit[#fit + 1] = spell
            end
        end
        if #fit == 1 then
            return fit[1], "product"
        end
    end
    local spell = name and bySpellName(name, skill)
    if spell then
        return spell, "name"
    end
    return nil, "none"
end

local trainer
local function scanTrainer()
    if not trainer or (IsTradeskillTrainer and not IsTradeskillTrainer()) then
        return
    end
    local c = Game.Record(ns.db)
    local any = false
    for i = 1, GetNumTrainerServices() or 0 do
        local name, _, kind = GetTrainerServiceInfo(i)
        if name and kind ~= "header" and not trainer.done[i .. name] then
            trainer.done[i .. name] = true
            local skillName, rank = GetTrainerServiceSkillReq(i)
            local skill = skillByName(skillName)
            local spell, how = Scan.TrainerSpell(i, name, skill)
            Scan.trainerStats[how] = Scan.trainerStats[how] + 1
            if spell then
                if type(rank) == "number" and rank > 0 and ns.db.reqs[spell] ~= rank then
                    ns.db.reqs[spell] = rank
                    any = true
                end
                if kind == "used" and c then
                    any = Game.SetKnown(c, spell, true) or any
                end
                -- What the trainer asks, in copper, as its window reads it (Ikar, 2026-11-10). Nothing noted when free.
                local cost = ns.Call(GetTrainerServiceCost, i)
                cost = type(cost) == "number" and cost > 0 and cost or nil
                any = note(trainer.visit, spell, { k = "trainer", npc = trainer.npc, map = trainer.map, x = trainer.x, y = trainer.y,
                    cost = cost }) or any
            end
        end
    end
    if any then
        changed()
    end
end

on("TRAINER_SHOW", function()
    local npc = npcOf("npc")
    local map, x, y = Game.Spot()
    trainer = { npc = npc, map = map, x = x, y = y, done = {} }
    trainer.visit = ns.Chat.Visit({ k = "trainer", npc = npc, map = map })
    scanTrainer()
end)
on("TRAINER_UPDATE", function()
    later("trainer", scanTrainer)
end)
on("TRAINER_CLOSED", function()
    if trainer then
        trainer.visit:Flush()
    end
    trainer = nil
end)

-- ---------- The auction house ----------

local ah
local function readBrowse()
    local results = ns.Call(C_AuctionHouse and C_AuctionHouse.GetBrowseResults)
    if not (ah and results) then
        return
    end
    if Scan.ah.queried and not Scan.ah.answered then
        Scan.ah.answered = time()
    end
    local any = false
    for _, r in ipairs(results) do
        local item = r.itemKey and r.itemKey.itemID
        local spell = item and ns.RECIPE_ITEMS[item]
        if spell then
            any = note(ah.visit, spell, { k = "ah", item = item }) or any
        end
    end
    if any then
        changed()
    end
end

-- A search on the whole Recipes category, sent only by a click on the addon's button. It was sent by itself when the
-- house opened (the ruling of 2026-11-09), and replaced whatever the player was looking at, their own searches
-- included. Ikar, 2026-11-10: "it should never take control over the user". Like the game's own search button, it
-- doesn't wait for the game's throttle: the game queues it.
function Scan.QueryAuctions()
    local AH = C_AuctionHouse
    if not (AH and AH.SendBrowseQuery and Enum.ItemClass) then
        return false
    end
    local sorts = {}
    if Enum.AuctionHouseSortOrder then
        sorts[1] = { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false }
    end
    local ok, err = pcall(AH.SendBrowseQuery, { searchString = "", sorts = sorts, filters = {},
        itemClassFilters = { { classID = Enum.ItemClass.Recipe } } })
    Scan.ah.queried, Scan.ah.answered = time(), nil
    if not ok then
        Scan.ah.refused = tostring(err)
    end
    return ok
end

-- Opening the house sends nothing. What the game lists, by the player's searches, Auctionator's scans or the addon's
-- button, is read as it comes, recipes and all.
on("AUCTION_HOUSE_SHOW", function()
    ah = { visit = ns.Chat.Visit({ k = "ah" }) }
end)
for _, event in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" }) do
    on(event, readBrowse)
end
on("AUCTION_HOUSE_CLOSED", function()
    if ah then
        ah.visit:Flush()
    end
    ah = nil
end)

-- ---------- Loot ----------

local function sourceName(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        if guid and UnitGUID(unit) == guid then
            return UnitName(unit)
        end
    end
end

on("LOOT_READY", function()
    local map, x, y = Game.Spot()
    local visit
    local any = false
    for slot = 1, GetNumLootItems() or 0 do
        local item = Game.ItemFromLink(GetLootSlotLink(slot))
        local spell = item and ns.RECIPE_ITEMS[item]
        if spell then
            local guid = ns.Call(GetLootSourceInfo, slot)
            local npc = Game.NPCFromGUID(guid)
            if npc then
                ns.DB.SetName(ns.db, "npc", npc, sourceName(guid))
            end
            visit = visit or ns.Chat.Visit({ k = "drop", npc = npc, map = map })
            any = note(visit, spell, { k = "drop", npc = npc, map = map, x = x, y = y, item = item }) or any
        end
    end
    if visit then
        visit:Flush()
    end
    if any then
        changed()
    end
end)

-- ---------- Quest rewards ----------

local function scanQuest()
    local q = ns.Call(GetQuestID)
    if not q or q == 0 then
        return
    end
    ns.DB.SetName(ns.db, "quest", q, ns.Call(GetTitleText))
    local map = Game.Spot()
    local any = false
    for _, kind in ipairs({ "reward", "choice" }) do
        local n = kind == "reward" and GetNumQuestRewards() or GetNumQuestChoices()
        for i = 1, n or 0 do
            local item = Game.ItemFromLink(GetQuestItemLink(kind, i))
            local spell = item and ns.RECIPE_ITEMS[item]
            if spell then
                any = note(nil, spell, { k = "quest", q = q, map = map, item = item }) or any
            end
        end
    end
    if any then
        changed()
    end
end
on("QUEST_DETAIL", scanQuest)
on("QUEST_COMPLETE", scanQuest)

-- ---------- Bags and bank ----------

local bankOpen = false

local function readBags()
    local db = ns.db
    local any, counts = Game.ReadBags(db, false)
    if bankOpen then
        any = Game.ReadBags(db, true) or any
    end
    -- A recipe that arrived in the bags without being seen anywhere: mail, a trade, a crafted scroll.
    local map, x, y = Game.Spot()
    for item in pairs(counts or {}) do
        local spell = ns.RECIPE_ITEMS[item]
        if spell and not ns.book:Seen(spell) then
            any = note(nil, spell, { k = "bags", map = map, x = x, y = y, item = item }) or any
        end
    end
    if any then
        changed()
    end
end
Scan.ReadBags = readBags

on("BAG_UPDATE_DELAYED", function()
    later("bags", readBags)
end)
on("BANKFRAME_OPENED", function()
    bankOpen = true
    later("bags", readBags)
end)
on("PLAYERBANKSLOTS_CHANGED", function()
    later("bags", readBags)
end)
on("BANKFRAME_CLOSED", function()
    bankOpen = false
end)

-- ---------- What the character knows ----------

local function readTradeSkill()
    if Game.ReadTradeSkill(ns.db) then
        changed()
    else
        ns.Changed()
    end
end
on("TRADE_SKILL_SHOW", function()
    later("tradeskill", readTradeSkill)
end)
on("TRADE_SKILL_LIST_UPDATE", function()
    later("tradeskill", readTradeSkill)
end)
on("TRADE_SKILL_DATA_SOURCE_CHANGED", function()
    later("tradeskill", readTradeSkill)
end)
on("NEW_RECIPE_LEARNED", function(_, spell)
    local c = Game.Record(ns.db)
    if c and ns.RECIPES[spell] and Game.SetKnown(c, spell, true) then
        changed()
    end
end)
-- The professions as the game lists them. A list empty while the character had professions may be the game not ready:
-- read once more a little later, and believed only if still empty then.
local recheckPending = false
local function readProfessions()
    local any, unsure = Game.ReadProfessions(ns.db)
    if unsure and not recheckPending then
        recheckPending = true
        C_Timer.After(Game.EMPTY_RECHECK, function()
            recheckPending = false
            ns.SafeCall(function()
                if ns.book and Game.ReadProfessions(ns.db, true) then
                    changed()
                end
            end)
        end)
    end
    return any
end
Scan.ReadProfessions = readProfessions

on("SKILL_LINES_CHANGED", function()
    later("professions", function()
        if readProfessions() then
            changed()
        end
    end)
end)
on("LEARNED_SPELL_IN_SKILL_LINE", function()
    later("spells", function()
        if Game.ReadKnownSpells(ns.db) then
            changed()
        end
    end)
end)

-- At login: the character's professions and bags at once, the spellbook a moment later, once it has loaded.
function Scan.AtLogin()
    readProfessions()
    readBags()
    C_Timer.After(3, function()
        ns.SafeCall(function()
            readProfessions()
            Game.ReadKnownSpells(ns.db)
            changed()
        end)
    end)
end
