-- KaLi HUD's regenerations as tables (UI/Hub/Infos/Stats.lua's RegenTable; Ikar 2026-11-23: "A, a table, and
-- everything per 5s"): a figure a state, the mana out of casting and in it, the health standing, seated and in a
-- fight; what an aura gives by itself every few seconds under « En plus du chiffre du jeu », its rhythm under it; a
-- share kept while casting in that column alone, Innervate's two apart; the totals, on the line too, the game's own
-- under the head; the mana a second's with the option ("Add an option to show mana as per second"). With them, from
-- the same review: the block value's card, the parts worked out with their sums, the reputation bar's bonuses.
local F = FakeWoW
login()
local L, Stats, Number, Card = ns.L, ns.Stats, ns.Format.Number, ns.StatCard
local Percent = ns.Format.Percent
local function button(key)
    return ns.HubButtons.Get("KaLiHUD_Attr_" .. key) or UIParent
end
-- a card's lines as they show, without colours, icons or the question mark's markup
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t%s*", ""):gsub("|A.-|a", "?"))
end
local function hover(key)
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnEnter(button(key))
    local lines = {}
    for i, line in ipairs((Card.Lines(true))) do
        lines[i] = plain(line)
    end
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnLeave()
    return table.concat(lines, "\n"), lines
end
-- these lines one after the other somewhere in the card
local function row(lines, ...)
    local want = { ... }
    for i = 1, #lines - #want + 1 do
        local all = true
        for j, w in ipairs(want) do
            all = all and lines[i + j - 1] == w
        end
        if all then
            return true
        end
    end
    return false
end
local function line(key)
    return plain(ns.HubButtons.Get("KaLiHUD_Attr_" .. key) and F.Shows(ns.HubButtons.Get("KaLiHUD_Attr_" .. key)) or "")
end
local function refresh()
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
end
local spirit = ns.G("SPELL_STAT5_NAME", "SPIRIT")

-- the mana's: the spirit's 32 out of casting, 0 in it; an item's +8 in both; Mage Armor's 50 % kept while casting in
-- that column alone, what it keeps (16); Blessing of Wisdom's 12 every 5 s and Mana Spring's 4 every 2 s (10) in both,
-- its rhythm under it; nothing left; the totals 62 and 46, the line's, the game's 40 and 24 under the head
local powerMax, manaRegen, manaSpirit = UnitPowerMax, GetManaRegen, GetManaRegenFromSpirit
UnitPowerMax = function(_, kind)
    return kind == Enum.PowerType.Mana and 500 or 100
end
-- (the spirit's 32.5 cut to 32 as the sheet's « %d », its figure the game's 40.5 and 24.25 cut the same: nothing of the
-- cut left as « Autres » or as the addon's mistake)
GetManaRegenFromSpirit = function()
    return 6.5
end
GetManaRegen = function()
    return 8.1, 4.85
end
F.itemStats[1] = { ITEM_MOD_MANA_REGENERATION_SHORT = 8 }
F.auras.HELPFUL[1] = { name = "Armure du mage", spellId = 6117, points = { 5, 50 } }
F.auras.HELPFUL[2] = { name = "Bénédiction de sagesse", spellId = 19742, points = { 12 } }
F.auras.HELPFUL[3] = { name = "Fontaine de mana", spellId = 5677, points = { 4 } }
refresh()
local t, lines = hover("REGEN")
local mana = row(lines, L.STAT_COL_OUT_CAST, L.STAT_COL_CASTING) and row(lines, spirit, "32", "0")
    and row(lines, "Objet 1", "+8", "+8") and row(lines, "Armure du mage", "–", Percent(0.5) .. " (+16)")
    and row(lines, "Bénédiction de sagesse", "+12", "+12") and row(lines, "Fontaine de mana", "+10", "+10")
    and row(lines, string.format(L.STAT_RHYTHM, "4", "2"))
    and row(lines, L.STAT_TOTAL, "62", "46") and not t:find(L.STAT_OTHER, 1, true)
    and not t:find(L.STAT_ADDON_ERROR, 1, true)
    and t:find(string.format(L.STAT_GAME_FIGURE, "24 (40)"), 1, true) and t:find(L.STAT_PER_5S, 1, true)
expect(mana and line("REGEN"):find("46 (62)", 1, true),
    "the mana's regeneration isn't a table of its states, what comes on its own beside it, totals on the line: "
    .. t .. " / " .. line("REGEN"))
-- what the game's figure in casting leaves of what's named there (5 of its 29): « Autres » in that column
GetManaRegen = function()
    return 8.1, 5.85
end
refresh()
t, lines = hover("REGEN")
expect(row(lines, L.STAT_OTHER, "", "+5"), "what's left of the mana's figure in casting isn't said: " .. t)
GetManaRegen = function()
    return 8.1, 4.85
end
-- the camp's mana well, from its tooltip, on top
F.auras.HELPFUL[4] = { name = "Avantages du camp", spellId = 1229741, auraInstanceID = 41,
    says = "Obtention des avantages de camp suivants\194\160:\r\n\r\nPuits de mana\194\160: rend 29 points de mana "
        .. "toutes les 5\194\160s." }
refresh()
t, lines = hover("REGEN")
F.auras.HELPFUL[4] = nil
refresh()
expect(row(lines, string.format(L.STAT_CAMP_PART, "Puits de mana"), "+29", "+29") and row(lines, L.STAT_TOTAL, "91", "75"),
    "the camp's mana well isn't on top of the mana's regeneration: " .. t)

-- a potion tried on the card kept open (12190, its buff 15822: 300 every 3 s, 500 in 5): its row in each state, the
-- totals as they would be, the head with them
ns.Hub.Object("KaLiHUD_Attr_REGEN").OnClick(button("REGEN"), "LeftButton")
F.RunTimers()
F.Hover("Item", { hyperlink = "|cffffffff|Hitem:12190:::::::::60:::::|h[Objet 99]|h|r" })
F.RunTimers()
local kept = {}
for i, text in ipairs((Card.PinnedLines(true))) do
    kept[i] = plain(text)
end
local triedText = table.concat(kept, "\n")
F.RunScript(GameTooltip, "OnHide")
F.RunTimers()
Card.Unpin()
expect(row(kept, "Objet 99", "+500", "+500") and row(kept, L.STAT_TOTAL, "62 ? 562", "46 ? 546")
    and triedText:find("546 (562)", 1, true),
    "a potion tried on the mana's card doesn't give what it would in each state: " .. triedText)
-- a ring tried (+5 mana every 5 s): its row in both states, the totals by it, nothing of it left in casting as
-- « Autres » or as the addon's mistake (what the game's figure leaves is the value's as it is)
F.items[5030], F.itemStats[30] = { equip = "INVTYPE_FINGER" }, { ITEM_MOD_MANA_REGENERATION_SHORT = 5 }
ns.Hub.Object("KaLiHUD_Attr_REGEN").OnClick(button("REGEN"), "LeftButton")
F.RunTimers()
F.Hover("Item", { hyperlink = "|cffffffff|Hitem:5030:::::::::60:::::|h[Objet 30]|h|r" })
F.RunTimers()
kept = {}
for i, text in ipairs((Card.PinnedLines(true))) do
    kept[i] = plain(text)
end
triedText = table.concat(kept, "\n")
F.RunScript(GameTooltip, "OnHide")
F.RunTimers()
Card.Unpin()
F.items[5030], F.itemStats[30] = nil, nil
expect(row(kept, "Objet 30", "+5", "+5") and row(kept, L.STAT_TOTAL, "62 ? 67", "46 ? 51")
    and not triedText:find(L.STAT_ADDON_ERROR, 1, true) and not triedText:find(L.STAT_OTHER, 1, true),
    "a ring tried on the mana's card doesn't give what it would in each state: " .. triedText)

-- a second's, with the option: the line, the table, its title
ns.db.options.manaPerSecond = true
Stats.Refresh()
F.RunTimers()
local second = line("REGEN")
t, lines = hover("REGEN")
ns.db.options.manaPerSecond = false
Stats.Refresh()
F.RunTimers()
local Decimal = ns.Format.Decimal
expect(second:find(Decimal(9.2, 1) .. " (" .. Decimal(12.4, 1) .. ")", 1, true)
    and row(lines, L.STAT_TOTAL, Decimal(12.4, 1), Decimal(9.2, 1)) and t:find(L.STAT_PER_SECOND, 1, true),
    "the option doesn't show the mana's regeneration a second's: " .. second .. " / " .. t)

-- Innervate's two apart: +400 % out of casting, 100 % kept in it; nothing said left beside a share not worked out
F.auras.HELPFUL[1], F.auras.HELPFUL[2], F.auras.HELPFUL[3] = { name = "Innervation", spellId = 29166,
    points = { 100, 400 } }, nil, nil
refresh()
t, lines = hover("REGEN")
expect(row(lines, "Innervation", "+" .. Percent(4), Percent(1) .. " (+32)") and not t:find(L.STAT_OTHER, 1, true)
    and not t:find("+500", 1, true), "Innervate's two shares aren't each in its state: " .. t)

-- a meal tried on a card kept open: what its buff gives every 5 s (Nightfin Soup's « Régénération de mana », 8), the
-- totals with it
local regen
for _, s in ipairs(Stats.LIST) do
    regen = s.key == "REGEN" and s or regen
end
F.auras.HELPFUL[1] = nil
refresh()
local now = Stats.RegenTable(regen, {}, nil)
local soup = Stats.RegenTable(regen, {}, { uses = { 18194 }, name = "Soupe d'aileron de nuit" })
expect(now and soup and soup.totals.out == now.totals.out + 8 and soup.totals.cast == now.totals.cast + 8,
    "a meal tried doesn't add what its buff gives every 5 s: " .. tostring(now and now.totals.out) .. " / "
    .. tostring(soup and soup.totals.out))
UnitPowerMax, GetManaRegen, GetManaRegenFromSpirit = powerMax, manaRegen, manaSpirit
F.itemStats[1] = nil

-- the health's: the spirit's 15 standing, 20 seated (asked), 0 in a fight; Demon Skin's +5 in each; eating's 17
-- seated alone; Renew's 41 every 3 s (68) in each, its rhythm under it; nothing left; the totals 88, 110 and 73
local healthRegen, healthSpirit = GetHealthRegen, GetHealthRegenFromSpirit
GetHealthRegen = function()
    return 4, 1
end
GetHealthRegenFromSpirit = function()
    return 4, 0
end
F.auras.HELPFUL[1] = { name = "Peau de démon", spellId = 696, points = { 120, 5 } }
F.auras.HELPFUL[2] = { name = "Nourriture", spellId = 433, points = { 17 } }
F.auras.HELPFUL[3] = { name = "Rénovation", spellId = 139, points = { 41 } }
refresh()
t, lines = hover("HEALTH_REGEN")
local health = row(lines, L.STAT_COL_STANDING, L.STAT_COL_SEATED, L.STAT_COL_FIGHT) and row(lines, spirit, "15", "20 ?", "0")
    and row(lines, "Peau de démon", "+5", "+5", "+5") and row(lines, "Nourriture", "–", "+17", "–")
    and row(lines, "Rénovation", "+68", "+68", "+68") and row(lines, string.format(L.STAT_RHYTHM, "41", "3"))
    and row(lines, L.STAT_TOTAL, "88", "110", "73") and not t:find(L.STAT_OTHER, 1, true)
    and t:find(L.STAT_WHY_SEATED, 1, true) and t:find(string.format(L.STAT_GAME_FIGURE, "5 (20)"), 1, true)
expect(health and line("HEALTH_REGEN"):find("73 (88)", 1, true),
    "the health's regeneration isn't a table of its states, eating seated alone, a HoT on its rhythm: " .. t .. " / "
    .. line("HEALTH_REGEN"))
-- the troll's Regeneration: 20 % more standing and seated, 20 % kept in a fight (3)
F.auras.HELPFUL[1], F.auras.HELPFUL[2], F.auras.HELPFUL[3] = { name = "Régénération", spellId = 20555,
    points = { 20, 20 } }, nil, nil
refresh()
t, lines = hover("HEALTH_REGEN")
expect(row(lines, "Régénération", "+" .. Percent(0.2), "+" .. Percent(0.2),
    Percent(0.2) .. " (+3)"), "a share kept in a fight isn't in its column: " .. t)
F.auras.HELPFUL[1] = nil
GetHealthRegen, GetHealthRegenFromSpirit = healthRegen, healthSpirit
refresh()

-- the block value: the shield's own as its tooltip writes it (20), the strength's (110 / 20, 5), an item's +11, the
-- point the game's figure has less (Ikar's screenshot of 2026-11-23: 7 and 3 made 9); nothing left of the game's 35;
-- what a block takes off a blow
local shieldBlock = GetShieldBlock
GetShieldBlock = function()
    return 35
end
F.itemLines[17] = { "Bloquer\194\160: 20" }
F.itemStats[6] = { ITEM_MOD_BLOCK_VALUE_SHORT = 11 }
refresh()
t, lines = hover("BLOCKVALUE")
GetShieldBlock = shieldBlock
F.itemLines[17], F.itemStats[6] = nil, nil
refresh()
expect(row(lines, "Objet 17", "20") and row(lines, ns.G("SPELL_STAT1_NAME", "Strength"), "5")
    and row(lines, L.STAT_BASE, "-1") and row(lines, "Objet 6", "+11") and not t:find(L.STAT_OTHER, 1, true)
    and not t:find(L.STAT_ADDON_ERROR, 1, true) and t:find("-" .. Number(35), 1, true),
    "the block value's card isn't the shield's, the strength's and the items' own: " .. t)

-- a part worked out of a skill against the level's most, with its sum: the defence's 143 of 115 on the dodge; 113,
-- under its most, -0.08 %, and none on a block at 0; the swords' 125 of 115 on the critical strike
t = hover("DODGE")
local over = t:find(plain(Stats.PartSum(ns.G("DEFENSE", "Defense"), 143, 115)), 1, true)
local defenseSkill = UnitDefenseSkill
UnitDefenseSkill = function()
    return 110, 3
end
refresh()
local under
t, lines = hover("DODGE")
under = row(lines, plain(Stats.PartSum(ns.G("DEFENSE", "Defense"), 113, 115)), plain(ns.Format.PercentOf(-0.08, 2)))
local block = hover("BLOCK")
UnitDefenseSkill = defenseSkill
refresh()
local crit = hover("CRITCHANCE")
expect(over and under and not block:find(ns.G("DEFENSE", "Defense") .. " (", 1, true)
    and crit:find(plain(Stats.PartSum(string.format(L.STAT_SKILL_PART, "Épées"), 125, 115)), 1, true),
    "a part worked out of a skill doesn't write its sum, or the defence's is on a block at 0: " .. t .. " / " .. block
    .. " / " .. crit)

-- the defence's column's four, against an enemy of the character's level (the fake's defence 143 of 115): each its
-- sum, nothing left; the miss 5 % and 28 points' 1.12 %, the critical strike 5 % less them
local four = {}
for _, key in ipairs({ "ARMORCUT", "MISSED", "AVOIDANCE", "CRITTAKEN" }) do
    four[key] = hover(key)
end
local defenseSum = plain(Stats.PartSum(ns.G("DEFENSE", "Defense"), 143, 115))
local fine = true
for _, card in pairs(four) do
    fine = fine and not card:find(L.STAT_OTHER, 1, true) and not card:find(L.STAT_ADDON_ERROR, 1, true)
end
expect(fine and four.MISSED:find(defenseSum, 1, true) and four.CRITTAKEN:find(defenseSum, 1, true)
    and four.MISSED:find(plain(ns.Format.PercentOf(6.1)), 1, true)
    and four.CRITTAKEN:find(plain(ns.Format.PercentOf(3.9)), 1, true)
    and four.AVOIDANCE:find(L.STAT_MISSED, 1, true) and four.ARMORCUT:find(ns.G("STAT_ARMOR", "Armor"), 1, true),
    "the defence's four aren't their sums: " .. table.concat({ four.ARMORCUT, four.MISSED, four.AVOIDANCE,
        four.CRITTAKEN }, " / "))

-- a school's spell power, its card titled with the sheet's word and its school; its icon its resistance's
t, lines = hover("SPELLPOWER_SHADOW")
expect(lines[1] == ns.G("STAT_SPELLPOWER", "Spell Power") .. " (" .. ns.G("DAMAGE_SCHOOL6", "Shadow") .. ")",
    "a school's spell power card isn't titled with its school: " .. t)
expect(ns.Hub.Object("KaLiHUD_Attr_SHADOW").icon == ns.Hub.Object("KaLiHUD_Attr_SPELLPOWER_SHADOW").icon,
    "a resistance's icon isn't its school's spell power's")

-- an attributes' folder as an earlier build left it, before the schools' spell power, the block value and the
-- defence's four (the one value in their place, the resistances last, a separator gone): the next login makes it as
-- the code does, locked (UI/Hub/Seeds.lua), with no mark of its own
local Hub, stats = ns.Hub, ns.Folders.ByRole("stats")
local function names()
    local list = {}
    for _, e in ipairs(Hub.InFolder(stats)) do
        list[#list + 1] = e.isSeparator and ("|" .. (ns.Separators.Name(e.name) or "")
            .. (ns.Separators.StartsLine(e.name) and "+" or "")) or (e.name:gsub("^KaLiHUD_", ""))
    end
    return table.concat(list, " ")
end
local made, items = names(), ns.db.items
local regenAt, firstAt = items.KaLiHUD_Attr_REGEN.order, items.KaLiHUD_Attr_SPELLPOWER_ARCANE.order
for id in pairs(ns.db.separators) do
    local e = items[id]
    if e and e.folder == stats and e.order > items.KaLiHUD_Attr_CRITTAKEN.order and e.order < firstAt then
        ns.Separators.Drop(id)
    end
end
for i, key in ipairs({ "ARCANE", "FIRE", "FROST", "NATURE", "SHADOW" }) do
    items["KaLiHUD_Attr_" .. key].order = 1000 + i
end
for _, key in ipairs({ "SPELLPOWER_HOLY", "SPELLPOWER_FIRE", "SPELLPOWER_NATURE", "SPELLPOWER_FROST",
    "SPELLPOWER_SHADOW", "SPELLPOWER_ARCANE", "BLOCKVALUE", "ARMORCUT", "MISSED", "AVOIDANCE", "CRITTAKEN" }) do
    items["KaLiHUD_Attr_" .. key] = nil
end
items.KaLiHUD_Attr_SPELLPOWER = { side = "folder", folder = stats, order = regenAt - 1 }
Hub.Changed()
local old = names()
ns.Seeds.Run()
F.RunTimers()
expect(names() == made and old ~= made,
    "an attributes' folder an earlier build left isn't made as the code makes it at the next login: " .. names()
    .. " / " .. made)

-- the reputation bar: the human's Diplomacy, known (+10 %), everywhere; Cenarion Favor (+25 %) on the Cenarion
-- Circle's alone; their sum, marked, where both are
F.known[1225485], F.spellNames[1225485] = true, "Diplomatie"
F.auras.HELPFUL[1] = { name = "Faveur cénarienne", spellId = 30754, points = { 25 } }
local function repTip()
    local bar = ns.StatusBars.bars[1]
    F.RunScript(bar, "OnEnter")
    local tip = table.concat(F.tooltip.lines, "\n")
    F.RunScript(bar, "OnLeave")
    return tip
end
local function plus(v)
    return "+" .. ns.Format.Percent(v / 100)
end
local darnassus = repTip()
local faction = F.faction
F.faction = { name = "Cercle cénarien", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000,
    currentStanding = 4000, factionID = 609 }
ns.StatusBars.Refresh()
local circle = repTip()
F.faction = faction
ns.StatusBars.Refresh()
F.known[1225485], F.spellNames[1225485], F.auras.HELPFUL[1] = nil, nil, nil
expect(darnassus:find(L.REP_BONUSES, 1, true) and darnassus:find("Diplomatie\n" .. plus(10), 1, true)
    and not darnassus:find("Faveur", 1, true)
    and circle:find("Faveur cénarienne\n" .. plus(25), 1, true) and circle:find("Diplomatie\n" .. plus(10), 1, true)
    and circle:find(L.XP_TOTAL .. " " .. Stats.UNKNOWN .. "\n" .. plus(35), 1, true),
    "the reputation bar doesn't list what raises the reputation gained with its faction: " .. darnassus .. " / " .. circle)
local count = errors()
expect(count == 0, "errors: " .. select(2, errors()))
