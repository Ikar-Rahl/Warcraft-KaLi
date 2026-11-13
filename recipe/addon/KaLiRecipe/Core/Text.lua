-- Words the addon builds from what it noted: dates, where a recipe was seen, where an item is held. Pure apart
-- from the model's game object, which names NPCs, maps and quests.
local _, ns = ...
local L = ns.L

local Text = {}
ns.Text = Text

-- "9 nov.": the day and the month's short name, as the bench and the game's own short dates write them.
function Text.Date(t)
    local d = type(t) == "number" and date("*t", t)
    if not d then
        return "?"
    end
    return string.format(L.DATE, d.day, L.MONTHS[d.month] or tostring(d.month))
end

local function npcName(m, id)
    return id and (ns.DB.Name(m.db, "npc", id) or m.game:NPCName(id)) or L.SOMEONE
end

-- A vendor seen with a limited stock of the recipe (Ikar, 2026-11-13: "we want to know if it is limited or not ...
-- gray clock icon will suffice"): the auction house's clock, grey, after the vendor's name, wherever it's written.
-- Only that: no count, no « épuisé ».
Text.CLOCK = "auctionhouse-icon-clock"
Text.CLOCK_MARKUP = "|A:" .. Text.CLOCK .. ":12:12:0:0:128:128:128|a"

function Text.Limited(s)
    return type(s) == "table" and s.k == "vendor" and type(s.stock) == "number" and s.stock >= 0
end

local function vendorName(m, s)
    local name = npcName(m, s.npc)
    return Text.Limited(s) and name .. " " .. Text.CLOCK_MARKUP or name
end

local function placeName(m, map)
    return map and m.game:MapName(map) or L.SOMEWHERE
end

local function questName(m, id)
    return id and (m.game:QuestName(id) or ns.DB.Name(m.db, "quest", id)) or L.A_QUEST
end

-- Where a sighting was: "Vendue par Ellandrieth, Darnassus", "Hôtel des ventes, le 9 nov.".
function Text.Where(m, s)
    if s.k == "vendor" then
        return string.format(L.WHERE_VENDOR, vendorName(m, s), placeName(m, s.map))
    elseif s.k == "trainer" then
        return string.format(L.WHERE_TRAINER, npcName(m, s.npc), placeName(m, s.map))
    elseif s.k == "drop" then
        return string.format(L.WHERE_DROP, npcName(m, s.npc), placeName(m, s.map))
    elseif s.k == "ah" then
        return string.format(L.WHERE_AH, Text.Date(s.t))
    elseif s.k == "quest" then
        return string.format(L.WHERE_QUEST, questName(m, s.q))
    end
    return string.format(L.WHERE_BAGS, placeName(m, s.map))
end

-- What a vendor or a trainer asked for the recipe (Ikar, 2026-11-10), as their windows write it: the money with the
-- game's coins (GetMoneyString), then each token or item a vendor also asked, "3 |T…|t". nil for another sighting, none
-- noted, or a trainer's while its option is off.
function Text.Price(s)
    if s.k == "trainer" and not (ns.db and ns.db.options.priceTrainer) then
        return nil
    end
    local parts = {}
    if type(s.cost) == "number" and s.cost > 0 and GetMoneyString then
        parts[#parts + 1] = GetMoneyString(s.cost)
    end
    for _, c in ipairs(type(s.costs) == "table" and s.costs or {}) do
        parts[#parts + 1] = c.tex and string.format("%d |T%d:0|t", c.n, c.tex) or tostring(c.n)
    end
    return #parts > 0 and table.concat(parts, " ") or nil
end

-- The chat's "chez Ellandrieth (Darnassus)" and the like, for one visit.
function Text.At(m, s)
    if s.k == "vendor" then
        return string.format(L.AT_NPC, vendorName(m, s), placeName(m, s.map))
    elseif s.k == "trainer" then
        return string.format(L.AT_NPC, npcName(m, s.npc), placeName(m, s.map))
    elseif s.k == "drop" then
        return string.format(L.AT_LOOT, npcName(m, s.npc), placeName(m, s.map))
    elseif s.k == "ah" then
        return L.AT_AH
    elseif s.k == "quest" then
        return string.format(L.AT_QUEST, questName(m, s.q))
    end
    return L.AT_BAGS
end

-- "sacs", "banque" or "sacs et banque", for the tooltip's "Vous en avez 2 (sacs et banque)".
function Text.Held(bags, bank)
    if bags > 0 and bank > 0 then
        return L.BAGS .. L.AND .. L.BANK
    end
    return bags > 0 and L.BAGS or L.BANK
end

-- The detail's "vos sacs et votre banque" (mine) or "ses sacs" (another character's).
function Text.HeldIn(bags, bank, mine)
    if bags > 0 and bank > 0 then
        return mine and L.YOUR_BOTH or L.HIS_BOTH
    elseif bags > 0 then
        return mine and L.YOUR_BAGS or L.HIS_BAGS
    end
    return mine and L.YOUR_BANK or L.HIS_BANK
end

function Text.Join(list, sep)
    return table.concat(list, sep or ", ")
end
