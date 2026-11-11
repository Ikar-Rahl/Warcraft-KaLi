-- What the addon takes from the game, looked for in this client (the list in Data/Needs.lua, made offline from the
-- code), and what it assumes of the game's answers, tried on the player's own game (Ikar's ruling for KaLi Quest:
-- every assumption about the game is covered by a test). Run at login, kept per build in KaLiRecipeDevDB.apiChecks,
-- and again for each bug report. It changes nothing, but says once in chat when something isn't as assumed.
local ADDON, ns = ...

local SelfCheck = {}
ns.SelfCheck = SelfCheck

local BUILDS_KEPT = 5
local WARNINGS_KEPT = 20
local SAMPLE = 25

local function resolve(name)
    local value = _G
    for part in name:gmatch("[^.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

local function anyLoaded(addons)
    if addons == "" then
        return true
    end
    for addon in addons:gmatch("[^,]+") do
        if ns.Call(C_AddOns.IsAddOnLoaded, addon) then
            return true
        end
    end
    return false
end

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
        local game = resolve(pair[1])
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
        local info = ns.Call(C_TradeSkillUI.GetBaseProfessionInfo)
        if #windowRead.wrong < 5 then
            windowRead.wrong[#windowRead.wrong + 1] = string.format("the professions window shows profession %s, not one of the addon's",
                tostring(info and info.professionID))
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

local ASSUMPTIONS = {
    { "game numbers", SelfCheck.Numbers },
    { "schematics", SelfCheck.Schematics },
    { "required ranks", SelfCheck.Ranks },
    { "recipe items", function()
        local wrong = {}
        for item in pairs(ns.Game.unknownRecipeItems) do
            wrong[#wrong + 1] = string.format("item %d is a recipe the data doesn't know: make the data again", item)
        end
        table.sort(wrong)
        return #wrong, wrong
    end },
    { "skill lines", function()
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
    end },
    { "trainers", function()
        -- A trainer lists ranks and skills too, so services that aren't recipes are expected; none recognised at all
        -- isn't.
        local t = ns.Scan.trainerStats
        local found = t.tooltip + t.product + t.name
        local wrong = {}
        if t.none > 0 and found == 0 then
            wrong[1] = string.format("no trainer service recognised as a recipe, %d tried", t.none)
        end
        return found + t.other + t.none, wrong, string.format("by tooltip %d, by item %d, by name %d, not recipes %d, unknown %d",
            t.tooltip, t.product, t.name, t.other, t.none)
    end },
    { "auction house", function()
        local a = ns.Scan.ah
        local wrong = {}
        if a.refused then
            wrong[1] = "the query was refused: " .. a.refused
        elseif a.queried and not a.answered and not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
            wrong[1] = "the query had no answer"
        end
        return a.queried and 1 or 0, wrong
    end },
    { "professions window", function()
        return windowRead.looked, windowRead.wrong, windowRead.spellbook
    end },
    -- The chosen sound kits play: PlaySound said it would, while the game's sound was on.
    { "sounds", function()
        local s = ns.Sounds.stats
        local wrong = {}
        for kit, why in pairs(s.refused) do
            wrong[#wrong + 1] = string.format("sound kit %d: %s", kit, tostring(why))
        end
        table.sort(wrong)
        return s.played + #wrong, wrong
    end },
}

function SelfCheck.Assumptions()
    local out, failing = {}, 0
    for _, a in ipairs(ASSUMPTIONS) do
        local ok, looked, wrong, note = pcall(a[2])
        if not ok then
            wrong, looked, note = { "the check failed: " .. tostring(looked) }, 0, nil
        end
        out[#out + 1] = { name = a[1], looked = looked, wrong = wrong, note = note }
        failing = failing + #wrong
    end
    return out, failing
end

local last

-- { checked, skipped, missing = { "kind name", sorted }, assumed, failing } for this client now.
function SelfCheck.Run()
    local needs = ns.NEEDS or {}
    local result = { checked = 0, skipped = 0, missing = {} }
    local function check(kind, name, present)
        result.checked = result.checked + 1
        if not present then
            result.missing[#result.missing + 1] = kind .. " " .. name
        end
    end
    for name, addons in pairs(needs.globals or {}) do
        if resolve(name) ~= nil then
            check("global", name, true)
        elseif anyLoaded(addons) then
            check("global", name, false)
        else
            result.skipped = result.skipped + 1
        end
    end
    local templateInfo = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    for name, addons in pairs(needs.templates or {}) do
        if templateInfo and anyLoaded(addons) then
            check("template", name, ns.Call(templateInfo, name) ~= nil)
        else
            result.skipped = result.skipped + 1
        end
    end
    local tests = {
        { "event", needs.events, C_EventUtils and C_EventUtils.IsEventValid, true },
        { "atlas", needs.atlases, C_Texture and C_Texture.GetAtlasInfo },
    }
    for _, t in ipairs(tests) do
        local kind, list, fn, isFlag = t[1], t[2] or {}, t[3], t[4]
        for _, name in ipairs(list) do
            if fn then
                local answer = ns.Call(fn, name)
                check(kind, name, isFlag and answer == true or not isFlag and answer ~= nil)
            else
                result.skipped = result.skipped + 1
            end
        end
    end
    for _, name in ipairs(needs.strings or {}) do
        check("string", name, type(_G[name]) == "string")
    end
    table.sort(result.missing)
    result.assumed, result.failing = SelfCheck.Assumptions()
    last = result
    return result
end

function SelfCheck.Last()
    return last
end

local current

-- Once per build and addon version. A missing game string isn't worth it: the addon has its own wording for each.
local function tell()
    local n = current.failing or 0
    for _, m in ipairs(current.missing or {}) do
        if not m:find("^string ") then
            n = n + 1
        end
    end
    if n > 0 and not current.told then
        current.told = true
        ns.Say(ns.L.API_NOT_AS_ASSUMED)
    end
end

function SelfCheck.Store()
    if not current then
        return
    end
    current.assumed, current.failing = SelfCheck.Assumptions()
    tell()
end

function SelfCheck.AtLogin()
    local result = SelfCheck.Run()
    local d = KaLiRecipeDevDB
    if type(d) ~= "table" then
        return
    end
    local _, build = GetBuildInfo()
    local list = type(d.apiChecks) == "table" and d.apiChecks or {}
    local told
    for i = #list, 1, -1 do
        if type(list[i]) ~= "table" or list[i].build == build and list[i].version == ns.VERSION then
            told = told or type(list[i]) == "table" and list[i].told or nil
            table.remove(list, i)
        end
    end
    current = { build = build, version = ns.VERSION, when = date("%Y-%m-%d %H:%M"), checked = result.checked,
        missing = result.missing, assumed = result.assumed, failing = result.failing, told = told }
    list[#list + 1] = current
    while #list > BUILDS_KEPT do
        table.remove(list, 1)
    end
    d.apiChecks = list
    tell()
end

-- A report like the last one adds to its count.
local function note(kind, text)
    local d = KaLiRecipeDevDB
    if type(d) ~= "table" then
        return
    end
    local list = type(d.gameWarnings) == "table" and d.gameWarnings or {}
    d.gameWarnings = list
    local now = date("%Y-%m-%d %H:%M:%S")
    local prev = list[#list]
    if type(prev) == "table" and prev.kind == kind and prev.text == text then
        prev.count, prev.when = (prev.count or 1) + 1, now
        return
    end
    list[#list + 1] = { when = now, kind = kind, text = tostring(text), count = 1 }
    while #list > WARNINGS_KEPT do
        table.remove(list, 1)
    end
end

function SelfCheck.WarningsText()
    local lines = {}
    local list = KaLiRecipeDevDB and KaLiRecipeDevDB.gameWarnings
    for _, w in ipairs(type(list) == "table" and list or {}) do
        lines[#lines + 1] = string.format("%s  %s  x%d  %s", tostring(w.when), tostring(w.kind), w.count or 1, tostring(w.text))
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end

ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn)
    if addon == ADDON then
        note("blocked", fn)
        if tostring(fn):find("SendBrowseQuery", 1, true) then
            ns.Scan.ah.refused = "blocked"
        end
    end
end)
ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, fn)
    if addon == ADDON then
        note("forbidden", fn)
    end
end)
ns.On("LUA_WARNING", function(_, ...)
    local n = select("#", ...)
    local text = n > 0 and select(n, ...) or nil
    if type(text) == "string" and text:find("AddOns[\\/]" .. ADDON .. "[\\/]") then
        note("warning", text)
    end
end)
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
