-- The client as the model sees it (names, counts), and the current character as the addon keeps it: professions
-- and ranks, known recipes, recipe items in bags and bank. Everything here reads the game and writes only the
-- addon's own saved table.
local _, ns = ...

local Game = {}
ns.Game = Game

-- ---------- The model's game object ----------

local world = {}
Game.World = world

function world:SpellName(spell)
    return ns.Call(C_Spell and C_Spell.GetSpellName, spell)
end

-- Item names load on demand: asked once, the game fires GET_ITEM_INFO_RECEIVED and the addon redraws.
local asked = {}
function world:ItemName(item)
    local name = ns.Call(C_Item.GetItemNameByID, item)
    if not name and not asked[item] then
        asked[item] = true
        ns.Call(C_Item.RequestLoadItemDataByID, item)
    end
    return name
end

-- Bags and bank, as the professions window counts reagents.
function world:ItemCount(item)
    return ns.Call(C_Item.GetItemCount, item, true) or 0
end

-- Places as the world map names them (Ikar's principle: « Sombrivage », not « Sombrivage (Darkshore) »).
function world:MapName(map)
    local info = ns.Call(C_Map.GetMapInfo, map)
    return info and info.name or nil
end

-- No function names an NPC from its number alone: the addon keeps the name the game gave when it was met.
function world:NPCName()
    return nil
end

function world:QuestName(id)
    local name = ns.Call(C_QuestLog.GetTitleForQuestID, id)
    return name ~= "" and name or nil
end

function world:CategoryName(cat)
    local info = ns.Call(C_TradeSkillUI.GetCategoryInfo, cat)
    return info and info.name ~= "" and info.name or nil
end

-- ---------- Small readers ----------

-- The NPC number in a creature's GUID: "Creature-0-3110-0-47-1234-0000ABCDEF" gives 1234.
function Game.NPCFromGUID(guid)
    local kind, id = tostring(guid or ""):match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
end

function Game.ItemFromLink(link)
    return tonumber(tostring(link or ""):match("|Hitem:(%d+)"))
end

-- Where the player stands: the map's number and the position on it, from 0 to 1, rounded.
function Game.Spot()
    local map = ns.Call(C_Map.GetBestMapForUnit, "player")
    if not map then
        return nil
    end
    local pos = ns.Call(C_Map.GetPlayerMapPosition, map, "player")
    local x, y
    if pos and pos.GetXY then
        x, y = pos:GetXY()
    end
    if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        return map, math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
    end
    return map
end

function Game.Key()
    return UnitGUID("player")
end

-- A profession's name: the game's for this character's own, else the client's for that skill line, else the data's.
function Game.ProfName(skill)
    local info = ns.Call(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skill)
    if info and info.professionName and info.professionName ~= "" then
        return info.professionName
    end
    local name = ns.Call(C_TradeSkillUI.GetTradeSkillDisplayName, skill)
    if name and name ~= "" then
        return name
    end
    local names = ns.PROFESSION_NAMES[ns.LOCALE] or ns.PROFESSION_NAMES.enUS
    return names[skill] or ("#" .. tostring(skill))
end

-- One of the addon's skill lines (the base professions' numbers, 185 for cooking): the number the game gave, its
-- parent's when it's an expansion's own line, or the profession's name. Lines that match none are noted for the API
-- check.
Game.unknownSkillLines = {}
function Game.Skill(id, name)
    if id and ns.PROFESSION_ICONS[id] then
        return id
    end
    local info = id and ns.Call(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
    local parent = info and info.parentProfessionID
    if parent and ns.PROFESSION_ICONS[parent] then
        return parent
    end
    if name and name ~= "" then
        local folded = ns.Fold(name)
        for _, names in pairs(ns.PROFESSION_NAMES) do
            for skill, n in pairs(names) do
                if ns.Fold(n) == folded then
                    return skill
                end
            end
        end
    end
    if id then
        Game.unknownSkillLines[id] = name or true
    end
end

function Game.ProfIcon(skill)
    return ns.PROFESSION_ICONS[skill] or 134400
end

-- ---------- The current character ----------

local function record(db)
    local key = Game.Key()
    if not key then
        return nil
    end
    local c = db.chars[key]
    if not c then
        c = { known = {}, bags = {}, bank = {}, profs = {}, maxRanks = {} }
        db.chars[key] = c
    end
    return c, key
end
Game.Record = record

-- Name and class, and the professions with their ranks, from the professions book's own functions.
function Game.ReadProfessions(db)
    local c = record(db)
    if not c then
        return false
    end
    c.name = UnitName("player") or c.name
    local _, classFile = UnitClass("player")
    c.class = classFile
    c.seen = time()
    local profs, maxes = {}, {}
    local unread = 0
    local list = { GetProfessions() }
    for i = 1, 6 do
        local index = list[i]
        if index then
            local name, _, rank, maxRank, _, _, line = GetProfessionInfo(index)
            local skillLine = Game.Skill(line, name)
            if skillLine and rank then
                profs[skillLine], maxes[skillLine] = rank, maxRank or 0
            else
                unread = unread + 1
            end
        end
    end
    -- A profession listed but not recognised may be one the character had: then none is taken as given up, as that
    -- would forget its recipes on a misreading.
    if unread > 0 then
        for skill, rank in pairs(c.profs) do
            if not profs[skill] then
                profs[skill], maxes[skill] = rank, c.maxRanks[skill] or 0
            end
        end
    end
    local changed = false
    for skill, rank in pairs(profs) do
        changed = changed or c.profs[skill] ~= rank
    end
    for skill in pairs(c.profs) do
        if not profs[skill] then
            changed = true
            -- A profession given up: what it knew is gone with it.
            for spell in pairs(c.known) do
                local row = ns.RECIPES[spell]
                if row and row[1] == skill then
                    c.known[spell] = nil
                end
            end
        end
    end
    c.profs, c.maxRanks = profs, maxes
    return changed
end

local function setKnown(c, spell, on)
    if (c.known[spell] == true) ~= on then
        c.known[spell] = on or nil
        return true
    end
    return false
end
Game.SetKnown = setKnown

-- Recipes of this character's professions the spellbook says it knows. Only adds: the professions window is the one
-- that can say a recipe isn't known.
function Game.ReadKnownSpells(db)
    local c = record(db)
    local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown
    if not c or not isKnown then
        return false
    end
    local changed = false
    for spell, row in pairs(ns.RECIPES) do
        if c.profs[row[1]] and not c.known[spell] and ns.Call(isKnown, spell) then
            changed = setKnown(c, spell, true) or changed
        end
    end
    return changed
end

-- The professions window, when it shows this character's own profession: its learned recipes, and the category
-- the game files each under. It reads the list as Blizzard's own does (GetFilteredRecipeIDs, so the window's search
-- and filters apply): a recipe listed as not learned is taken off, one not listed is left as it was. Forever lists no
-- unlearned recipe: it hides them.
function Game.ReadTradeSkill(db)
    if not (C_TradeSkillUI and ns.Call(C_TradeSkillUI.IsTradeSkillReady)) or ns.Call(C_TradeSkillUI.IsTradeSkillLinked)
        or ns.Call(C_TradeSkillUI.IsTradeSkillGuild) or ns.Call(C_TradeSkillUI.IsNPCCrafting) then
        return false
    end
    local c = record(db)
    local ids = c and ns.Call(C_TradeSkillUI.GetFilteredRecipeIDs)
    if type(ids) ~= "table" then
        return false
    end
    local changed = false
    for _, id in ipairs(ids) do
        local info = ns.Call(C_TradeSkillUI.GetRecipeInfo, id)
        if info and ns.RECIPES[id] then
            changed = setKnown(c, id, info.learned == true) or changed
            local row = ns.RECIPES[id]
            local cat = info.categoryID
            if type(cat) == "number" and cat > 0 and cat ~= row[5] and ns.CATEGORIES[cat] then
                db.cats[id] = cat
            end
        end
    end
    return changed
end

-- The bags the game counts: backpack, bags and reagent bag; the bank's while it's open. Forever's bank is the tab bank
-- (Camelot's BankFrame.lua): this character's tabs are CharacterBankTab_1 and on. The account's tabs hold what every
-- character shares, so they'd show as one character's; they're left out, as is the keyring (-1 in this build).
local function bagIDs(bank)
    local ids = {}
    local E = Enum and Enum.BagIndex
    if E then
        for name, id in pairs(E) do
            local isBank = name:find("^CharacterBankTab_%d+$") ~= nil
            local isBag = name == "Backpack" or name:find("^Bag_%d+$") ~= nil or name == "ReagentBag"
            if bank and isBank or not bank and isBag then
                ids[#ids + 1] = id
            end
        end
    elseif not bank then
        -- No enum: the backpack and its four bags. The bank's numbers aren't guessed (the old -1 is the keyring here).
        for i = 0, NUM_BAG_SLOTS or 4 do
            ids[#ids + 1] = i
        end
    end
    table.sort(ids)
    return ids
end
Game.BagIDs = bagIDs

-- Counts the recipe items in the bags or the bank; returns the counts and the items whose tooltip says this
-- character knows them already (ITEM_SPELL_KNOWN), checked once per item a session, once its tooltip has loaded.
local knownChecked = {}
local function readContainers(bank)
    local counts, knows, unknownRecipes = {}, {}, {}
    for _, bag in ipairs(bagIDs(bank)) do
        for slot = 1, ns.Call(C_Container.GetContainerNumSlots, bag) or 0 do
            local item = ns.Call(C_Container.GetContainerItemID, bag, slot)
            if item and ns.RECIPE_ITEMS[item] then
                local info = ns.Call(C_Container.GetContainerItemInfo, bag, slot)
                counts[item] = (counts[item] or 0) + (info and info.stackCount or 1)
                if not knownChecked[item] then
                    local data = ns.Call(C_TooltipInfo and C_TooltipInfo.GetBagItem, bag, slot)
                    -- Before the item's data has loaded the tooltip holds its name at most: asked again next time.
                    knownChecked[item] = data and data.lines and #data.lines > 1 or nil
                    for _, line in ipairs(data and data.lines or {}) do
                        if line.leftText == ITEM_SPELL_KNOWN then
                            knows[item] = true
                        end
                    end
                end
            elseif item then
                local _, _, _, _, _, classID = ns.Call(C_Item.GetItemInfoInstant, item)
                if classID == 9 then
                    unknownRecipes[item] = true
                end
            end
        end
    end
    return counts, knows, unknownRecipes
end

local function sameCounts(a, b)
    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- Recipe items the data doesn't know, this session: a patch added recipes, so the data needs making again.
Game.unknownRecipeItems = {}

-- Returns whether anything changed, and the recipe items now in the bags.
function Game.ReadBags(db, bank)
    local c = record(db)
    if not c then
        return false
    end
    local counts, knows, unknown = readContainers(bank)
    for item in pairs(unknown) do
        Game.unknownRecipeItems[item] = true
    end
    local changed = false
    local field = bank and "bank" or "bags"
    if not sameCounts(counts, c[field]) then
        c[field] = counts
        changed = true
    end
    if bank then
        c.bankSeen = time()
    end
    for item in pairs(knows) do
        changed = setKnown(c, ns.RECIPE_ITEMS[item], true) or changed
    end
    return changed, counts
end

-- The profession the professions window shows, as one of the addon's skill lines: the base profession's number,
-- or its parent's when the window gives an expansion's own line.
function Game.OpenSkill()
    local info = ns.Call(C_TradeSkillUI.GetBaseProfessionInfo)
    local skill = info and (Game.Skill(info.professionID, info.professionName) or Game.Skill(info.parentProfessionID,
        info.parentProfessionName))
    if skill then
        return skill
    end
    local child = ns.Call(C_TradeSkillUI.GetChildProfessionInfo)
    return child and (Game.Skill(child.parentProfessionID, child.parentProfessionName) or Game.Skill(child.professionID,
        child.professionName))
end
