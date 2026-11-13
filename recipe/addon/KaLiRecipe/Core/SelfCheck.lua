-- KaLi Recipe's part of the API check (Shared/SelfCheck.lua): what it assumes of the game's answers, tried on the
-- player's own game, again when the professions window shows a profession and when the auction house closes.
local _, ns = ...

local SelfCheck = ns.SelfCheck

local SAMPLE = 25

-- A few recipes the notebook holds, lowest numbers first, so the same ones are tried each time.
local function sample(m)
    local list = {}
    for spell in pairs(m.db.sightings) do
        list[#list + 1] = spell
    end
    local c = m:Char(m.me)
    for spell in pairs(c and c.known or {}) do
        if not m.db.sightings[spell] then
            list[#list + 1] = spell
        end
    end
    table.sort(list)
    local out = {}
    for i = 1, math.min(SAMPLE, #list) do
        out[i] = list[i]
    end
    return out
end

-- The game's numbers the addon reads, against the game's enums.
function SelfCheck.Numbers()
    local list = {
        { "Enum.ItemClass.Recipe", 9 },
        { "Enum.TooltipDataType.Item", 0 },
        { "Enum.TooltipDataType.Spell", 1 },
    }
    local wrong = {}
    for _, pair in ipairs(list) do
        local game = SelfCheck.Resolve(pair[1])
        if game ~= pair[2] then
            wrong[#wrong + 1] = string.format("%s is %s, the addon reads %s", pair[1], tostring(game), tostring(pair[2]))
        end
    end
    return #list, wrong
end

-- The data's product and reagents, against the game's own schematic for the same recipe. Also says how many the game
-- answered at all: for recipes this character hasn't learned, it may not (the plan's probe question).
function SelfCheck.Schematics()
    local m = ns.book
    local get = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic
    if not (m and get) then
        return 0, {}
    end
    local looked, answered, wrong = 0, 0, {}
    for _, spell in ipairs(sample(m)) do
        looked = looked + 1
        local s = ns.Call(get, spell, false)
        if s and (s.outputItemID or s.reagentSlotSchematics) then
            answered = answered + 1
            local info = m:Info(spell)
            local out = s.outputItemID ~= 0 and s.outputItemID or nil
            if out and info.product and out ~= info.product then
                wrong[#wrong + 1] = string.format("recipe %d makes %s, the data says %s", spell, tostring(out), tostring(info.product))
            end
            local game = {}
            for _, slot in ipairs(s.reagentSlotSchematics or {}) do
                local r = slot.reagents and slot.reagents[1]
                if r and r.itemID then
                    game[r.itemID] = slot.quantityRequired
                end
            end
            for _, r in ipairs(info.reagents) do
                if next(game) and game[r[1]] ~= r[2] then
                    wrong[#wrong + 1] = string.format("recipe %d needs %s of %d, the data says %d", spell, tostring(game[r[1]]), r[1], r[2])
                end
            end
        end
    end
    return looked, wrong, string.format("%d answered", answered)
end

-- A recipe item's required rank, from its tooltip (ITEM_MIN_SKILL, in the client's language), against the data's.
local function rankPattern()
    local f = ns.G("ITEM_MIN_SKILL", nil)
    if not f then
        return nil
    end
    -- "%s (%d) requis" becomes "^(.-) %((%d+)%) requis$": the pattern's own characters escaped, then the two fields.
    local p = f:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

function SelfCheck.Ranks()
    local m = ns.book
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    local pattern = rankPattern()
    if not (m and get and pattern) then
        return 0, {}
    end
    local looked, wrong = 0, {}
    for _, spell in ipairs(sample(m)) do
        local item = m:ItemsForSpell(spell)[1]
        local data = item and ns.Call(get, item)
        local row = ns.RECIPES[spell]
        for _, line in ipairs(data and data.lines or {}) do
            local _, rank = tostring(line.leftText or ""):match(pattern)
            rank = tonumber(rank)
            if rank then
                looked = looked + 1
                if row[2] > 0 and rank ~= row[2] then
                    wrong[#wrong + 1] = string.format("recipe item %d requires %d, the data says %d", item, rank, row[2])
                end
                break
            end
        end
    end
    return looked, wrong
end

-- Recipes the professions window lists as learned that the spellbook doesn't know: the spellbook's answer is only
-- trusted to add, so a difference is noted, not acted on.
local windowRead = { looked = 0, wrong = {} }
function SelfCheck.NoteWindow()
    local m = ns.book
    local skill = ns.Game.OpenSkill()
    windowRead.looked = windowRead.looked + 1
    if not skill then
        -- Profession 0 is the game's "none", as the window answers while it fills: nothing to say about it.
        local info = ns.Call(C_TradeSkillUI.GetBaseProfessionInfo)
        local id = info and info.professionID
        if id and id ~= 0 and #windowRead.wrong < 5 then
            windowRead.wrong[#windowRead.wrong + 1] = string.format("the professions window shows profession %s, not one of the addon's",
                tostring(id))
        end
        return
    end
    local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown
    local c = m and m:Char(m.me)
    if not (isKnown and c) then
        return
    end
    local differ = 0
    for spell in pairs(c.known) do
        if ns.RECIPES[spell] and ns.RECIPES[spell][1] == skill and not ns.Call(isKnown, spell) then
            differ = differ + 1
        end
    end
    windowRead.spellbook = string.format("profession %d: %d learned recipes the spellbook doesn't know", skill, differ)
end

SelfCheck.Add("game numbers", SelfCheck.Numbers)
SelfCheck.Add("schematics", SelfCheck.Schematics)
SelfCheck.Add("required ranks", SelfCheck.Ranks)
SelfCheck.Add("recipe items", function()
    local wrong = {}
    for item in pairs(ns.Game.unknownRecipeItems) do
        wrong[#wrong + 1] = string.format("item %d is a recipe the data doesn't know: make the data again", item)
    end
    table.sort(wrong)
    return #wrong, wrong
end)
SelfCheck.Add("skill lines", function()
    local wrong = {}
    for id, name in pairs(ns.Game.unknownSkillLines) do
        wrong[#wrong + 1] = string.format("skill line %s (%s) is none of the addon's professions", tostring(id), tostring(name))
    end
    table.sort(wrong)
    local looked = 0
    local c = ns.book and ns.book:Char(ns.book.me)
    for _ in pairs(c and c.profs or {}) do
        looked = looked + 1
    end
    return looked + #wrong, wrong
end)
SelfCheck.Add("trainers", function()
    -- A trainer lists ranks and skills too, so services that aren't recipes are expected; none recognised at all isn't.
    local t = ns.Scan.trainerStats
    local found = t.tooltip + t.product + t.name
    local wrong = {}
    if t.none > 0 and found == 0 then
        wrong[1] = string.format("no trainer service recognised as a recipe, %d tried", t.none)
    end
    return found + t.other + t.none, wrong, string.format("by tooltip %d, by item %d, by name %d, not recipes %d, unknown %d",
        t.tooltip, t.product, t.name, t.other, t.none)
end)
SelfCheck.Add("auction house", function()
    local a = ns.Scan.ah
    local wrong = {}
    if a.refused then
        wrong[1] = "the query was refused: " .. a.refused
    elseif a.queried and not a.answered and not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
        wrong[1] = "the query had no answer"
    end
    return a.queried and 1 or 0, wrong
end)
SelfCheck.Add("professions window", function()
    return windowRead.looked, windowRead.wrong, windowRead.spellbook
end)
-- The chosen sound kits play: PlaySound said it would, while the game's sound was on.
SelfCheck.Add("sounds", function()
    local s = ns.Sounds.stats
    local wrong = {}
    for kit, why in pairs(s.refused) do
        wrong[#wrong + 1] = string.format("sound kit %d: %s", kit, tostring(why))
    end
    table.sort(wrong)
    return s.played + #wrong, wrong
end)

-- The auction house's search, when the game blocks it (it wants a click).
function SelfCheck.OnBlocked(fn)
    if tostring(fn):find("SendBrowseQuery", 1, true) then
        ns.Scan.ah.refused = "blocked"
    end
end

-- The window's profession, and what it says of the spellbook, each time it shows a profession.
ns.On("TRADE_SKILL_SHOW", function()
    ns.Later("selfcheckWindow", function()
        SelfCheck.NoteWindow()
        SelfCheck.Store()
    end)
end)
ns.On("AUCTION_HOUSE_CLOSED", function()
    ns.Later("selfcheckAH", SelfCheck.Store)
end)
