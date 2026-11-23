-- KaLi HUD's check of its own stat cards (UI/Hub/Infos/StatCheck.lua; Ikar 2026-11-22: "Is there a better way to do
-- it ?", then "ok, go, and add that to the error report"). What a card can't account for is kept with what it read:
-- below 0 the addon's mistake, in red with its question; above 0 « Autres », kept too; a card that accounts for all of
-- it, nothing; the same card once, counted; /kh stats keeps every card; the bug report has them; /kh clear empties
-- them; none in a fight; a failure while keeping one leaves the card whole; the card kept open drawn again is no new
-- look; each state written as the report writes it reads back the same, without what changes from one moment to the
-- next; MAX of them, those that account for all of it going first, the last /kh stats whole. Then each card kept is
-- read again from what it kept alone, the fake's own state put out of the way first (F.Replay): the same rows, or
-- what it didn't keep shows. Then the cases met in the game (hud/tools/card_cases.py prints them from the saved
-- file), each held to what its card must say now.
local F = FakeWoW
login()
local L, Stats, StatCheck = ns.L, ns.Stats, ns.StatCheck
local Color, GOOD, BAD, Number = ns.Infos.Color, ns.Infos.GOOD, ns.Infos.BAD, ns.Format.Number
local STAT = {}
for _, s in ipairs(Stats.LIST) do
    STAT[s.key] = s
end
local function kept()
    return KaLiHUDDevDB.statChecks and KaLiHUDDevDB.statChecks.cards or {}
end
local function keptOf(key)
    local found = {}
    for _, e in ipairs(kept()) do
        if e.stat == key then
            found[#found + 1] = e
        end
    end
    return found
end
-- A card on hover, as the info bar's element draws it: its lines, its foot's with them, and the colour of the row
-- named the addon's mistake.
local function card(key)
    local name = "KaLiHUD_Attr_" .. key
    ns.Hub.Object(name).OnEnter(ns.HubButtons.Get(name) or UIParent)
    local lines, foot = table.concat((ns.StatCard.Lines()), "\n"), table.concat((ns.StatCard.Lines(true)), "\n")
    local red
    for _, text in ipairs(KaLiHUDStatCard.texts or {}) do
        if text:GetText() == L.STAT_ADDON_ERROR then
            red = text.textColor
        end
    end
    ns.Hub.Object(name).OnLeave()
    return lines, foot, red
end
local function slash(text)
    SlashCmdList.KALIHUD(text)
    F.RunTimers()
end
local function printed(text)
    for _, line in ipairs(F.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end
-- A text cut for a failure's line, never inside a letter of several bytes.
local function cut(text, n)
    return (text:sub(1, n):gsub("[\192-\255][\128-\191]*$", ""))
end
local function found(pattern)
    for spell, effects in pairs(ns.ENCHANTS) do
        if effects:find(pattern) then
            return spell
        end
    end
end

-- A human warrior of 23 (the fake's): strength 110 (105 + 5), an item's +3 and Strength of Earth's +2, all of it
-- accounted for; stamina 100 (95 + 5) whose item gives +10 and a weapon's oil some more, counted more than the game
-- gives; intellect 40 (32 + 8) with nothing that gives it.
KaLiHUDDevDB.statChecks = nil
local unitStat = UnitStat
local stats = { [3] = { 100, 100, 5, 0 }, [4] = { 40, 40, 8, 0 } }
UnitStat = function(unit, i)
    if stats[i] then
        return unpack(stats[i])
    end
    return unitStat(unit, i)
end
F.itemStats[1], F.itemQuality[1] = { ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 10 }, 2
F.auras.HELPFUL[1] = { name = "Force de la Terre", spellId = 8076, points = { 2 } }
local lines = card("STRENGTH")
expect(#kept() == 0 and lines:find("Force de la Terre", 1, true) and not lines:find(L.STAT_OTHER, 1, true),
    "a card that accounts for all of the game's figure is kept, or isn't the one meant: " .. lines)
local foot, red
lines, foot, red = card("STAMINA")
local mistake = L.STAT_ADDON_ERROR .. "\n" .. Color(Number(-5), BAD) .. " " .. Stats.UNKNOWN
expect(lines:find(mistake, 1, true) and foot:find(L.STAT_ADDON_ERROR_LESS, 1, true)
    and not lines:find(L.STAT_OTHER, 1, true) and red and red[1] == 1 and red[2] < 0.2,
    "what a card counts more than the game gives isn't the addon's mistake in red with its question: " .. foot)
local stamina = keptOf("STAMINA")[1]
expect(#kept() == 1 and stamina and stamina.count == 1 and #stamina.gaps == 1 and stamina.gaps[1].mistake
    and stamina.gaps[1].points == -5 and stamina.value.numbers[2] == 100 and stamina.state
    and KaLiHUDDevDB.statChecks.states[stamina.state], "the card's mistake isn't kept with what it read")
lines = card("INTELLECT")
expect(lines:find(L.STAT_OTHER .. "\n" .. Color("+" .. Number(8), GOOD), 1, true)
    and not lines:find(L.STAT_ADDON_ERROR, 1, true) and #keptOf("INTELLECT") == 1
    and not keptOf("INTELLECT")[1].gaps[1].mistake,
    "what's left above 0 isn't « Autres », kept, or is taken for a mistake: " .. lines)
card("STAMINA")
expect(#keptOf("STAMINA") == 1 and keptOf("STAMINA")[1].count == 2, "the same card seen again is kept twice")

-- The card kept open drawn again (its values read again, the pointer over something to try) is no new look, nor the
-- click keeping open the card its hover showed (the review of 2026-11-23: each redraw counted one).
do
    local name = "KaLiHUD_Attr_STAMINA"
    local obj, owner = ns.Hub.Object(name), ns.HubButtons.Get(name) or UIParent
    obj.OnEnter(owner)
    obj.OnClick(owner, "LeftButton")
    obj.OnLeave()
    for _ = 1, 3 do
        F.Fire("UNIT_STATS", "player")
        F.RunTimers()
    end
    local count = (keptOf("STAMINA")[1] or {}).count
    expect(ns.StatCard.Pinned() and #keptOf("STAMINA") == 1 and count == 3,
        "the card kept open counts a look each time it's drawn again: " .. tostring(count))
    ns.StatCard.Unpin()
end

-- A failure while keeping it leaves the card whole, the error kept as any other.
do
    local read = Stats.ReadState
    Stats.ReadState = function()
        error("broken on purpose: the cards' state")
    end
    stats[3] = { 101, 101, 5, 0 }
    lines = card("STAMINA")
    Stats.ReadState, stats[3] = read, { 100, 100, 5, 0 }
    expect(lines:find(L.STAT_ADDON_ERROR, 1, true) and times("broken on purpose: the cards' state") == 1,
        "a failure while keeping a card takes its sources, or isn't kept as an error: " .. lines)
    forget()
end

-- The rest of what a card reads, for the cards kept on /kh stats to be read again from: the camp's hidden auras named
-- by its text, a talent whose words state another figure than the data's (66 % at rank 2 since 71037), a passive
-- spell, a rating of the kind of attack the hit shows (the spells': 4.5 %) and an item of it, an oil on the weapon, an
-- enchantment on an item.
F.auras.HELPFUL[2] = { name = "Avantages du camp", spellId = 1229741, auraInstanceID = 41,
    says = "Obtention des avantages de camp suivants\194\160:\r\n\r\nBocal à poisson\194\160: augmentation de toutes "
        .. "les caractéristiques de 8 %.\r\n\r\n" }
F.talents, F.spellNames[415140] = { { spell = 415140, rank = 2, ranks = 3,
    says = "Augmente votre puissance d'attaque d'un montant égal à 50 % de votre intelligence." } }, "Dextérité mentale"
local endurance
for _, spell in ipairs(ns.PASSIVES) do
    if (ns.EFFECTS[spell] or ""):find(";133:") then
        endurance = spell
    end
end
F.known[endurance or 0] = true
F.ratings[CR_HIT_SPELL], F.itemStats[3] = 10, { ITEM_MOD_HIT_RATING_SHORT = 10 }
local oil = found("^STAMINA:%d+$")
F.weaponEnchants[0] = { { hasEnchant = true, enchantType = Enum.ItemEnchantType.Temporary, enchantID = oil,
    timeLeft = 600000, charges = 0 } }
F.enchants[9] = found("^INTELLECT:%d+$")
F.Fire("PLAYER_TALENT_UPDATE")
slash("stats")
-- (every card that has sources now: one with none at 0 has nothing to keep)
local all, asked, askedGaps = 0, 0, 0
for _, s in ipairs(Stats.LIST) do
    all = all + (s.sources and Stats.SourcesOf(s, true) and 1 or 0)
end
for _, e in ipairs(kept()) do
    asked, askedGaps = asked + (e.asked and 1 or 0), askedGaps + (e.asked and #e.gaps > 0 and 1 or 0)
end
local cards = StatCheck.Count()
expect(endurance and oil and F.enchants[9] and all > 10 and asked == all and askedGaps > 0
    and printed(string.format(L.STAT_CHECK_SAVED, all, askedGaps)) and keptOf("STRENGTH")[1]
    and ns.Count(KaLiHUDDevDB.statChecks.states) == 2,
    "/kh stats doesn't keep every card as it is, in one state: " .. asked .. " / " .. all .. ", " .. askedGaps)

-- Each state kept, written as the bug report writes it, reads back the same, the camp's text whole: its lines joined
-- by line breaks, its last starting with a figure (« 60 minutes restantes »), which a line break's code in fewer than
-- three figures took into it (the review of 2026-11-23: "\10" then "60" read back as "j0").
do
    local wrong, camp = {}, nil
    for id, state in pairs(KaLiHUDDevDB.statChecks.states) do
        local text = StatCheck.Literal(state)
        local read = loadstring("return " .. text)
        local back = read and read()
        if not back or StatCheck.Literal(back) ~= text then
            wrong[#wrong + 1] = id
        end
        for i, aura in ipairs(state.auras.HELPFUL or {}) do
            if aura.says then
                camp = { aura.says, back and back.auras.HELPFUL[i].says }
            end
        end
    end
    expect(#wrong == 0 and camp and camp[1]:find("\r\n60", 1, true) and camp[1] == camp[2],
        "a state kept doesn't read back as it was written: " .. table.concat(wrong, ", ") .. " "
        .. cut(string.format("%q", tostring(camp and camp[2])), 200))
end

-- What changes from one moment to the next isn't kept, which no source reads (the review of 2026-11-23: no state read
-- twice was the same, each card kept with a whole one of its own): the oil's time left, the speed the character goes
-- at and an aura's instance changed between two readings, they are one state.
do
    local first = StatCheck.Literal(Stats.ReadState())
    F.weaponEnchants[0][1].timeLeft, F.speed, F.auras.HELPFUL[1].auraInstanceID = 590000, 14, 77
    local second = StatCheck.Literal(Stats.ReadState())
    F.speed, F.auras.HELPFUL[1].auraInstanceID = nil, nil
    expect(first == second, "what changes from one moment to the next is kept in a card's state: " .. cut(first, 300)
        .. " / " .. cut(second, 300))
end

-- The bug report: a line a card, those with a gap first, and their cases.
local report = ns.Report.Text()
local section = report:match("== stat cards ==\n(.-)\n\n") or ""
expect(section:find("STAMINA", 1, true) and section:find(L.STAT_ADDON_ERROR .. " -5", 1, true)
    and section:find("case 1 = {", 1, true) and not section:find("|", 1, true)
    and section:find(string.format("%d cards kept", cards), 1, true),
    "the bug report hasn't what the cards couldn't account for: " .. cut(section, 400))

-- Each card kept, read again from what it kept alone, in a fake that is another character in all of it.
local function replay(case)
    local s = STAT[case.stat]
    local undo = F.Replay(case.state)
    local locale, v = ns.LOCALE, case.value
    ns.LOCALE = case.state.locale or locale
    local numbers, total, parts = s.numbers, s.total, s.parts
    local spec = s.sources
    local channel = spec.channel
    if numbers then
        s.numbers = function()
            return unpack(v.numbers or {})
        end
    end
    if total then
        s.total = function()
            return v.total
        end
    end
    if parts then
        s.parts = function()
            return ns.DeepCopy(v.parts or {})
        end
    end
    if channel then
        spec.channel = function()
            return v.channel
        end
    end
    F.Fire("PLAYER_TALENT_UPDATE")
    local ok, list = pcall(Stats.SourcesOf, s, true)
    s.numbers, s.total, s.parts, spec.channel = numbers, total, parts, channel
    ns.LOCALE = locale
    undo()
    F.Fire("PLAYER_TALENT_UPDATE")
    return ok, ok and (list or {}) or list
end
local OTHER = {
    level = 60, race = { "Gnome", "Gnome", 7 }, class = { "Mage", "MAGE", 8 }, form = 5, power = { 0, "MANA" },
    mana = 5000, stats = { { 50, 50, 0, 0 }, { 50, 50, 0, 0 }, { 50, 50, 0, 0 }, { 50, 50, 0, 0 }, { 50, 50, 0, 0 } },
    auras = { HELPFUL = { { name = "Bénédiction des rois", spellId = 20217, points = { 10 } } }, HARMFUL = {} },
    items = { [5] = { item = "item:2000:0", name = "Robe", quality = 4,
        stats = { ITEM_MOD_STAMINA_SHORT = 30, ITEM_MOD_INTELLECT_SHORT = 20, ITEM_MOD_HIT_RATING_SHORT = 7 } } },
    enchants = {}, talents = { { spell = 415140, rank = 3, ranks = 3, says = { 100 } } }, known = {},
    ratings = { [6] = { 70, 7 } }, move = { 0, 14, 0, 4.72 }, moving = { swimming = true },
}
local undoOther = F.Replay(OTHER)
local replayed, differ = 0, {}
for _, e in ipairs(kept()) do
    local ok, list = replay(StatCheck.Case(e))
    replayed = replayed + 1
    local now = ok and StatCheck.Literal(StatCheck.Rows(list)) or ("error: " .. tostring(list))
    if now ~= StatCheck.Literal(e.rows) then
        differ[#differ + 1] = e.stat .. ": " .. now .. " instead of " .. StatCheck.Literal(e.rows)
    end
end
undoOther()
F.Fire("PLAYER_TALENT_UPDATE")
expect(replayed >= all + 1 and #differ == 0, "a card kept, read again from what it kept, isn't the same: "
    .. cut(table.concat(differ, " / "), 1500))

-- The cases met in the game, each with what its card must leave now (expect.gaps, none unless said): printed by
-- hud/tools/card_cases.py from the saved file, kept here once their card says it right.
local CASES = {
}
local function gapsText(list)
    local out = {}
    for _, g in ipairs(list or {}) do
        out[#out + 1] = tostring(g.name) .. " " .. string.format("%.2f", g.points or 0)
    end
    return table.concat(out, ", ")
end
for i, case in ipairs(CASES) do
    local ok, list = replay(case)
    local left = ok and gapsText(StatCheck.Gaps(list)) or ("error: " .. tostring(list))
    local want = gapsText(case.expect and case.expect.gaps)
    expect(left == want, "case " .. i .. " (" .. tostring(case.name) .. ") leaves " .. left .. " instead of " .. want)
end

-- None kept in a fight: the game hides the values, and the line says so.
F.combat = true
local before = #kept()
slash("stats")
F.combat = false
expect(#kept() == before and printed(L.HIDDEN_IN_FIGHT), "/kh stats keeps cards in a fight, or doesn't say why not")

-- The newest MAX alone, and the states they're read in (stamina counted 5 more than the game gives, each time with
-- another base), no /kh stats among them.
F.auras.HELPFUL, F.weaponEnchants, F.talents, F.known, F.enchants[9] = {}, {}, {}, {}, nil
F.Fire("PLAYER_TALENT_UPDATE")
KaLiHUDDevDB.statChecks = nil
for k = 1, StatCheck.MAX + 3 do
    stats[3] = { 100 + k, 100 + k, 5, 0 }
    card("STAMINA")
end
local last = 0
for _, e in ipairs(kept()) do
    last = math.max(last, (e.value and e.value.numbers or {})[2] or 0)
end
expect(#kept() == StatCheck.MAX and #keptOf("STAMINA") == StatCheck.MAX and last == 103 + StatCheck.MAX
    and ns.Count(KaLiHUDDevDB.statChecks.states) == StatCheck.MAX,
    "more cards kept than the newest " .. StatCheck.MAX .. ": " .. #kept())

-- Past MAX, the cards that account for all of it go first, the last /kh stats' staying whole (the review of
-- 2026-11-23: each /kh stats kept a card a value, and the third pushed out the first card that couldn't account for
-- its figure). One that can't, then three /kh stats of twenty cards that can, each of another moment: it stays, with
-- the last twenty, and the newest of the others.
KaLiHUDDevDB.statChecks = nil
stats[3] = { 100, 100, 5, 0 }
card("STAMINA")
local gap, store = kept()[1], KaLiHUDDevDB.statChecks
for batch = 1, store and 3 or 0 do
    store.asks = batch
    for i = 1, 20 do
        StatCheck.Note(STAT.STRENGTH, { { name = "Pierre " .. batch .. "-" .. i, points = i, base = true } }, nil, batch,
            { level = batch })
    end
end
local lastAsked, stillThere = 0, false
for _, e in ipairs(kept()) do
    lastAsked, stillThere = lastAsked + (e.asked == 3 and 1 or 0), stillThere or e == gap
end
expect(gap and #kept() == StatCheck.MAX and stillThere and lastAsked == 20,
    "a card that can't account for its figure is pushed out by cards that can, or the last /kh stats isn't whole: "
    .. #kept() .. " kept, the gap " .. tostring(stillThere) .. ", " .. lastAsked .. " of the last /kh stats")
-- More cards that can't account for it than MAX: a /kh stats after them is kept whole all the same.
for k = 1, StatCheck.MAX + 5 do
    stats[3] = { 200 + k, 200 + k, 5, 0 }
    card("STAMINA")
end
local values = 0
for _, s in ipairs(Stats.LIST) do
    values = values + (s.sources and Stats.SourcesOf(s, true) and 1 or 0)
end
slash("stats")
local latest, ofLatest = KaLiHUDDevDB.statChecks.asks, 0
for _, e in ipairs(kept()) do
    ofLatest = ofLatest + (e.asked == latest and 1 or 0)
end
expect(#kept() == StatCheck.MAX and values > 10 and ofLatest == values,
    "a /kh stats past MAX cards that can't account for their figure isn't kept whole: " .. ofLatest .. " / " .. values)

-- /kh clear empties them, with the errors.
slash("clear")
expect(KaLiHUDDevDB.statChecks == nil and StatCheck.Count() == 0, "/kh clear leaves the cards kept")
UnitStat = unitStat
