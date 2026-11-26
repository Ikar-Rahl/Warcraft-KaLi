-- What would be on the attributes' lines (UI/Hub/Infos/Stats.lua's Tried; Ikar 2026-11-25: "when hovering, it seems
-- you turn blue only the individual cards, not the whole stat lists", then "go for an implementation"). No card kept
-- open: the attributes' folder shut, an item under the pointer works nothing out; open, each line it changes says what
-- it would be, its figure alone in the blue, its name and the others as they are; the game refreshing its tooltip
-- works nothing out again; the lines as they are once it has gone. A copy on the bar follows, the folder shut. The
-- speed's line, read each second with no event of the game's, is worked out again in the water. A buff of no known
-- figure asks its question on the lines that stand on what it changes, no other; a value its sources alone make (the
-- healing taken by points) read again with it; the mana's line its two states'. In a fight, nothing worked out, and
-- the lines as they were once the game hides the values. With no saved data, an item under the pointer errs nothing.
local F = FakeWoW
-- (the game's tickers, kept to play a second passing with no event: the speed's line is read each second)
local tickers, newTicker = {}, C_Timer.NewTicker
C_Timer.NewTicker = function(every, fn, iterations)
    tickers[#tickers + 1] = fn
    return newTicker(every, fn, iterations)
end
login()
C_Timer.NewTicker = newTicker
local function second()
    for _, fn in ipairs(tickers) do
        fn()
    end
    F.RunTimers()
end
local BLUE = "|c" .. ns.Stats.WOULD_HEX
local function object(key)
    return ns.Hub.Object("KaLiHUD_Attr_" .. key)
end
local function text(key)
    return tostring(object(key).text)
end
local function blue(key, figure)
    return object(key).label .. " " .. BLUE .. figure .. "|r"
end
local function all()
    local t = {}
    for _, s in ipairs(ns.Stats.LIST) do
        t[s.key] = text(s.key)
    end
    return t
end
local function changed(before)
    local out = {}
    for _, s in ipairs(ns.Stats.LIST) do
        if text(s.key) ~= before[s.key] then
            out[#out + 1] = s.key .. " " .. text(s.key)
        end
    end
    return table.concat(out, " | ")
end
local function link(id, name)
    return "|cffffffff|Hitem:" .. id .. ":::::::::60:::::|h[Objet " .. name .. "]|h|r"
end
local function hover(id, name)
    F.Hover("Item", { id = id, hyperlink = link(id, name) })
    F.RunTimers()
end
local function gone()
    F.RunScript(GameTooltip, "OnHide")
    F.RunTimers()
end
-- how many times `fn` reads the character's auras: the sources' readings
local function readings(fn)
    local n, real = 0, C_UnitAuras.GetAuraDataByIndex
    C_UnitAuras.GetAuraDataByIndex = function(...)
        n = n + 1
        return real(...)
    end
    fn()
    C_UnitAuras.GetAuraDataByIndex = real
    return n
end
local strength, stamina = select(2, UnitStat("player", 1)), select(2, UnitStat("player", 3))
local stats = ns.Folders.ByRole("stats")
ns.StatCard.Unpin()
F.RunTimers()
local before = all()

-- a chest of 10 strength, 7 stamina and 10 defence, the folder shut: nothing worked out
F.items[2005] = { class = 4, subclass = 4, equip = "INVTYPE_CHEST" }
F.itemStats[42] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 7, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10 }
local shut = readings(function()
    hover(2005, 42)
end)
expect(shut == 0 and changed(before) == "", "a shut folder's lines are worked out (" .. shut .. " readings): "
    .. changed(before))
gone()

-- open: what each line it changes would be, in the blue, as the line writes it (the defence's most beside it)
ns.Folders.SetOpen(stats, true)
F.RunTimers()
hover(2005, 42)
local base, mod = UnitDefenseSkill("player")
expect(text("STRENGTH") == blue("STRENGTH", strength + 10) and text("STAMINA") == blue("STAMINA", stamina + 7)
    and text("DEFENSE") == blue("DEFENSE", (base + mod + 10) .. " / " .. UnitLevel("player") * 5)
    and text("HEALTH"):find(BLUE, 1, true) and text("ATTACK_AP"):find(BLUE, 1, true)
    and text("AGILITY") == before.AGILITY and text("FIRE") == before.FIRE,
    "the lines don't say what an item under the pointer would make of them: " .. changed(before))
-- what is worked out of the defence follows its 10 (Ikar 2026-11-25: "it doesn't seems to update everything"): the
-- misses and critical strikes taken, the dodge's and the parry's share of it, all they don't land; the block, at 0,
-- has none of it, and the armour's damage reduction stays
local function chance(v)
    return ns.Format.PercentOf(v, 1)
end
local past = (base + mod + 10 - UnitLevel("player") * 5) * 0.04
expect(text("MISSED") == blue("MISSED", chance(5 + past)) and text("CRITTAKEN") == blue("CRITTAKEN", chance(5 - past))
    and text("DODGE") == blue("DODGE", chance(GetDodgeChance() + 0.4))
    and text("PARRY") == blue("PARRY", chance(GetParryChance() + 0.4))
    and text("AVOIDANCE") == blue("AVOIDANCE", chance(5 + past + GetDodgeChance() + GetParryChance() + 0.8))
    and text("BLOCK") == before.BLOCK and text("ARMORCUT") == before.ARMORCUT,
    "what is worked out of the defence doesn't follow an item's: " .. changed(before))
-- the game refreshing its tooltip: nothing worked out again
local again = readings(function()
    hover(2005, 42)
end)
expect(again == 0, "the same item under the pointer is worked out again: " .. again .. " readings")
-- gone, the lines as they are at once, before any event of the game's reads them again (the review of 2026-11-26: the
-- check further down, after one, let lines left in the blue pass)
gone()
expect(changed(before) == "", "the lines stay in the blue once the tooltip has gone: " .. changed(before))
hover(2005, 42)
-- the values read again under it (5 strength come): what it would be worked out again
local unitStat = UnitStat
UnitStat = function(unit, i)
    local current, effective, raised, lowered = unitStat(unit, i)
    if i == 1 then
        return current + 5, effective + 5, raised + 5, lowered
    end
    return current, effective, raised, lowered
end
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local raised = text("STRENGTH")
UnitStat = unitStat
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(raised == blue("STRENGTH", strength + 15), "what a line would be isn't worked out again as the values change: "
    .. raised)
gone()
-- a share of the strength come under it (a blessing's tenth, with the strength it raises): the attack power's line,
-- whose own figure stays (the fake game's), says what the item's strength raised by it would give, as a new look at
-- the item does: what every line stands on (the attributes' changes, Tried.With's) worked out again too
ns.EFFECTS[999011] = "1,1;137:1:0:0:10"
hover(2005, 42)
local power = text("ATTACK_AP")
F.auras.HELPFUL[1] = { name = "Bénédiction", spellId = 999011, points = { 10 } }
F.attributes[1] = F.attributes[1] + 3
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local blessed = text("ATTACK_AP")
gone()
hover(2005, 42)
local anew = text("ATTACK_AP")
gone()
F.auras.HELPFUL[1], ns.EFFECTS[999011] = nil, nil
F.attributes[1] = F.attributes[1] - 3
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(blessed ~= power and blessed == anew, "a line whose figure stays isn't worked out again as what it stands on "
    .. "changes (a share of the strength come): " .. power .. " / " .. blessed .. " / " .. anew)
expect(changed(before) == "", "the lines aren't as they are once the tooltip has gone: " .. changed(before))
-- an event that changes no value (a stack split) works nothing out again: as many readings as with nothing tried
local idle = readings(function()
    F.Fire("BAG_UPDATE", 0)
    F.RunTimers()
end)
hover(2005, 42)
local busy = readings(function()
    F.Fire("BAG_UPDATE", 0)
    F.RunTimers()
end)
expect(busy == idle and text("STRENGTH") == blue("STRENGTH", strength + 10),
    "an event that changes no value works the lines out again: " .. busy .. " readings, " .. idle .. " with nothing "
    .. "tried; " .. text("STRENGTH"))
gone()

-- a chest of 200 armour: the damage reduction, the game's own call at the armour it would make (Ikar 2026-11-25:
-- "damage reduction too")
local armor = select(2, UnitArmor("player"))
local function cut(v)
    return C_PaperDollInfo.GetArmorEffectiveness(v, UnitEffectiveLevel("player")) * 100
end
F.items[2007] = { class = 4, subclass = 4, equip = "INVTYPE_CHEST" }
F.itemStats[46] = { RESISTANCE0_NAME = 200 }
hover(2007, 46)
expect(text("ARMOR") == blue("ARMOR", ns.Format.Number(armor + 200))
    and text("ARMORCUT") == blue("ARMORCUT", chance(cut(armor + 200))),
    "the damage reduction doesn't follow an item's armour: " .. text("ARMOR") .. " / " .. text("ARMORCUT"))
gone()

-- the cards kept open: what each value gives, as it is beside what it would be (Ikar 2026-11-25: "the output for
-- example"): the armour's share of the blows with the chest's 200, the strength's attack power and block value with
-- the other's 10
local function became(old, new)
    return "|cff808080" .. old .. "|r " .. ns.Stats.ARROW .. " " .. BLUE .. new .. "|r"
end
local function card(key, id, name)
    ns.Hub.Object("KaLiHUD_Attr_" .. key).OnClick(ns.HubButtons.Get("KaLiHUD_Attr_" .. key) or UIParent, "LeftButton")
    F.RunTimers()
    hover(id, name)
    local shown = table.concat((ns.StatCard.PinnedLines(nil, key)), "\n")
    gone()
    ns.StatCard.Unpin()
    F.RunTimers()
    return shown
end
local shown = card("ARMOR", 2007, 46)
expect(shown:find(became(ns.Format.PercentOf(cut(armor), 2), ns.Format.PercentOf(cut(armor + 200), 2)) .. "\n"
    .. ns.L.STAT_GIVES_PHYSICAL, 1, true), "the armour's card kept open doesn't say what it would give: " .. shown)
shown = card("STRENGTH", 2005, 42)
expect(shown:find(became("+" .. strength * 2, "+" .. (strength + 10) * 2) .. "\n" .. ns.G("STAT_ATTACK_POWER", "Attack Power"),
    1, true)
    and shown:find(became("+" .. math.floor(strength / 20), "+" .. math.floor((strength + 10) / 20)), 1, true),
    "the strength's card kept open doesn't say what it would give: " .. shown)
-- the damage reduction's card: its row the armour's, by the armour it would be, its figure changing (not a row gone
-- and another come, its name holding the armour: Stats.lua's `match`)
shown = card("ARMORCUT", 2007, 46)
expect(shown:find(ns.G("STAT_ARMOR", "Armor") .. " " .. ns.Format.Number(armor + 200) .. "\n"
    .. became(chance(cut(armor)), chance(cut(armor + 200))), 1, true)
    and not shown:find(became(chance(cut(armor)), "0"), 1, true),
    "the damage reduction's card kept open doesn't change its armour's row: " .. shown)
F.items[2007], F.itemStats[46] = nil, nil
-- an axe tried in the main hand, where a sword is: the critical strike without the swords' skill past the level's
-- most (125 of 115, 0.4 %), the fake knowing no axes' skill
F.items[2009] = { class = 2, subclass = 0, equip = "INVTYPE_WEAPON" }
F.itemStats[48] = {}
hover(2009, 48)
local axe = text("CRITCHANCE")
gone()
-- its card kept open: each kind of attack's, the melee's alone changing (the kind's own sources read)
shown = card("CRITCHANCE", 2009, 48)
F.items[2009], F.itemStats[48] = nil, nil
expect(axe == blue("CRITCHANCE", chance(GetCritChance() - 0.4)),
    "the critical strike doesn't follow the skill of a weapon tried: " .. axe)
expect(shown:find(became(chance(GetCritChance()), chance(GetCritChance() - 0.4)) .. "\n" .. ns.G("MELEE", "Melee"), 1,
    true) and shown:find("\n" .. chance(GetSpellCritChance()) .. "\n" .. ns.G("SPELLS", "Spells"), 1, true),
    "the critical strike's card kept open doesn't say each kind's: " .. shown)

-- a change smaller than the line's tenth (1 agility, 0.01 % of critical strike): the line as it is, the agility's
-- in the blue
local critChance, critFromStat = GetCritChance, GetCritChanceFromStat
GetCritChance = function()
    return 6.21
end
GetCritChanceFromStat = function(i, v)
    return i == 2 and v / 100 / 100 or 0
end
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local crit = text("CRITCHANCE")
F.items[2006] = { class = 4, subclass = 4, equip = "INVTYPE_WAIST" }
F.itemStats[45] = { ITEM_MOD_AGILITY_SHORT = 1 }
hover(2006, 45)
expect(text("CRITCHANCE") == crit and text("AGILITY"):find(BLUE, 1, true),
    "a change smaller than the line writes is said in the blue: " .. changed(before))
gone()
GetCritChance, GetCritChanceFromStat = critChance, critFromStat
F.items[2006], F.itemStats[45] = nil, nil
F.Fire("UNIT_AURA", "player")
F.RunTimers()

-- a copy on the bar, the folder shut: it follows
ns.Folders.SetOpen(stats, false)
local copy = ns.Hub.NewCopy("KaLiHUD_Attr_STRENGTH")
ns.Hub.PlaceAt(copy, "left", 1)
ns.Hub.Changed()
F.RunTimers()
hover(2005, 42)
expect(text("STRENGTH") == blue("STRENGTH", strength + 10) and text("STAMINA") == before.STAMINA,
    "a copy's line doesn't follow, or a shut folder's does: " .. changed(before))
gone()
ns.Hub.DeleteCopy(copy)
ns.Folders.SetOpen(stats, true)
F.RunTimers()

-- the speed's line, read each second with no event of the game's (UI/Hub/Infos/Stats.lua's MOVE): a potion of
-- swiftness tried (its buff half as fast again, running), it says what it would be running; in the water, where the
-- buff wouldn't count, as it is; out of it, what it would be again
ns.EFFECTS[999009] = "1,1;31:0:0:0:50"
ns.ITEM_USES[3010] = "999009"
F.items[3010] = { class = 0, subclass = 1 }
hover(3010, 85)
local running = text("MOVESPEED")
F.swimming = true
second()
local swimming = text("MOVESPEED")
F.swimming = false
second()
local ashore = text("MOVESPEED")
gone()
ns.EFFECTS[999009], ns.ITEM_USES[3010], F.items[3010] = nil, nil, nil
expect(running == blue("MOVESPEED", ns.Format.Percent(1.5))
    and swimming == object("MOVESPEED").label .. " " .. ns.Format.Percent(4.72 / 7) and ashore == running,
    "the speed's line doesn't say what a potion of swiftness would make of it, or still says it in the water: "
    .. running .. " / " .. swimming .. " / " .. ashore)

-- a buff of no known figure on the stamina: the question on the stamina's and the health's lines alone
ns.EFFECTS[999004] = "1,1;29:2:0:0:"
ns.ITEM_USES[3005] = "999004"
F.items[3005] = { class = 0, subclass = 2 }
hover(3005, 81)
expect(text("STAMINA") == object("STAMINA").label .. " " .. ns.Stats.UNKNOWN
    and text("HEALTH") == object("HEALTH").label .. " " .. ns.Stats.UNKNOWN
    and text("STRENGTH") == before.STRENGTH and text("FIRE") == before.FIRE,
    "a buff of no known figure on the stamina doesn't ask on its lines alone: " .. changed(before))
gone()

-- the healing taken by points, a value its sources alone make: read again with a consumable's 50
ns.EFFECTS[999005] = "1,1;115:0:0:0:50"
ns.ITEM_USES[3006] = "999005"
F.items[3006] = { class = 0, subclass = 2 }
hover(3006, 82)
expect(text("HEALTAKEN_FLAT") == blue("HEALTAKEN_FLAT", "+50"),
    "the healing taken by points doesn't say what a consumable would make of it: " .. changed(before))
gone()

-- the mana's line, both its states: a potion (12190, its buff 500 in 5 s)
local powerMax, manaRegen, manaSpirit = UnitPowerMax, GetManaRegen, GetManaRegenFromSpirit
local healthRegen, healthSpirit = GetHealthRegen, GetHealthRegenFromSpirit
UnitPowerMax = function(_, kind)
    return kind == Enum.PowerType.Mana and 500 or 100
end
GetManaRegenFromSpirit = function()
    return 6.5
end
GetManaRegen = function()
    return 8.1, 4.85
end
-- (the health's out of a fight and in one, as the game gives them: the fake's own has no figure in a fight)
GetHealthRegen = function()
    return 2, 0.5
end
GetHealthRegenFromSpirit = function()
    return 1.5
end
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local r = ns.Stats.RegenTotals("REGEN")
F.Hover("Item", { hyperlink = "|cffffffff|Hitem:12190:::::::::60:::::|h[Objet 99]|h|r" })
F.RunTimers()
expect(text("REGEN") == blue("REGEN", ns.Stats.RegenText("REGEN", r.states,
    { out = r.totals.out + 500, cast = r.totals.cast + 500 })),
    "the mana's line doesn't say what a potion would make of its two states: " .. text("REGEN"))
gone()
-- a helm of 10 spirit (Ikar 2026-11-25: "mana regen seems also to have hard time showing the new values"): the mana's
-- line out of casting by the spirit's share at 50, Forever's 6.25 + spirit / 8 a second by its ratio to the game's
-- figure at 40 (Tried.ManaFromSpirit), the share cut to a whole as the game writes it; the health's an estimate (Ikar
-- 2026-11-26: "Everything should follow, every, single, line"), the game giving its share at the spirit now alone: the
-- original server's slope for a warrior, 1.26 a point a tick of 2 s, standing three quarters of it, the game's
-- question after it (Tried.HealthFromSpirit); the spirit's card kept open the same, its mana and its health
F.items[2008] = { class = 4, subclass = 4, equip = "INVTYPE_HEAD" }
F.itemStats[47] = { ITEM_MOD_SPIRIT_SHORT = 10 }
local spirit = select(2, UnitStat("player", 5))
local function share(v)
    return math.floor(6.5 * (6.25 + v / 8) / (6.25 + spirit / 8) * 5 + 1e-6)
end
local hr = ns.Stats.RegenTotals("HEALTH_REGEN")
local function standing(more)
    return math.floor((1.5 + 1.26 / 2 * more) * 0.75 * 5 + 1e-6)
end
hover(2008, 47)
local manaLine, healthLine = text("REGEN"), text("HEALTH_REGEN")
gone()
expect(manaLine == blue("REGEN", ns.Stats.RegenText("REGEN", r.states,
    { out = r.totals.out + share(spirit + 10) - share(spirit), cast = r.totals.cast }))
    and healthLine == blue("HEALTH_REGEN", ns.Stats.RegenText("HEALTH_REGEN", hr.states, { stand = hr.totals.stand
        + standing(10) - standing(0), fight = hr.totals.fight })) .. " " .. ns.Stats.UNKNOWN,
    "the regenerations' lines don't follow a helm's spirit: " .. manaLine .. " / " .. healthLine)
shown = card("SPIRIT", 2008, 47)
expect(shown:find(became("+" .. share(spirit), "+" .. share(spirit + 10)) .. "\n" .. ns.G("MANA_REGEN", "Mana Regen"),
    1, true)
    and shown:find(became("+" .. standing(0), "+" .. standing(10) .. " " .. ns.Stats.UNKNOWN) .. "\n"
        .. ns.G("ITEM_MOD_HEALTH_REGEN_SHORT", "Health per 5 sec."), 1, true),
    "the spirit's card kept open doesn't say what a helm's spirit would give: " .. shown)
F.items[2008], F.itemStats[47] = nil, nil
-- a buff of no known figure on the spirit: the question on both regenerations (their spirit's share the game's figure,
-- which no reading of the attribute's says)
ns.EFFECTS[999007] = "1,1;29:4:0:0:"
ns.ITEM_USES[3008] = "999007"
F.items[3008] = { class = 0, subclass = 2 }
hover(3008, 83)
expect(text("REGEN") == object("REGEN").label .. " " .. ns.Stats.UNKNOWN
    and text("HEALTH_REGEN") == object("HEALTH_REGEN").label .. " " .. ns.Stats.UNKNOWN,
    "a buff of no known figure on the spirit doesn't ask on the regenerations' lines: " .. changed(before))
gone()
-- the same buff, the spirit's card kept open by a class without mana: its health asked, not said as it is (the review
-- of 2026-11-26: without the mana's reading, nothing of the card's effects said they stand on the spirit)
UnitPowerMax = function()
    return 0
end
shown = card("SPIRIT", 3008, 83)
UnitPowerMax = function(_, kind)
    return kind == Enum.PowerType.Mana and 500 or 100
end
expect(shown:find(ns.Stats.ARROW .. " " .. ns.Stats.UNKNOWN .. "\n"
    .. ns.G("ITEM_MOD_HEALTH_REGEN_SHORT", "Health per 5 sec."), 1, true),
    "with no mana, the spirit's card kept open says its health as it is under a buff of no known figure: " .. shown)
-- a drink whose mana every 5 s has no known figure: the question on the line and on the card kept open's head, not the
-- totals as they are
ns.PERIODIC[999008] = "1,1;24:0:0:5000:"
ns.ITEM_USES[3009] = "999008"
F.items[3009] = { class = 0, subclass = 2 }
ns.Hub.Object("KaLiHUD_Attr_REGEN").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_REGEN") or UIParent, "LeftButton")
F.RunTimers()
hover(3009, 84)
local head = ns.StatCard.PinnedLines()[2] or ""
expect(text("REGEN") == object("REGEN").label .. " " .. ns.Stats.UNKNOWN and head:find(ns.Stats.UNKNOWN, 1, true),
    "a drink of no known figure isn't asked on the mana's line, or on its card's head: " .. text("REGEN") .. " / "
    .. head)
gone()
ns.StatCard.Unpin()
ns.EFFECTS[999007], ns.ITEM_USES[3008], F.items[3008] = nil, nil, nil
ns.PERIODIC[999008], ns.ITEM_USES[3009], F.items[3009] = nil, nil, nil
UnitPowerMax, GetManaRegen, GetManaRegenFromSpirit = powerMax, manaRegen, manaSpirit
GetHealthRegen, GetHealthRegenFromSpirit = healthRegen, healthSpirit
F.Fire("UNIT_AURA", "player")
F.RunTimers()

-- in a fight: the lines as they were once the game hides the values, nothing worked out for what comes next
local calm = all()
hover(2005, 42)
F.EnterCombat()
F.statsSecret = true
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local hidden = changed(calm)
local fight = readings(function()
    hover(3006, 82)
end)
gone()
F.statsSecret = false
F.LeaveCombat()
F.RunTimers()
expect(hidden == "" and fight == 0, "in a fight, the lines keep what would be, or it is worked out (" .. fight
    .. " readings): " .. hidden)
ns.EFFECTS[999004], ns.ITEM_USES[3005], F.items[3005] = nil, nil, nil
ns.EFFECTS[999005], ns.ITEM_USES[3006], F.items[3006] = nil, nil, nil

-- no saved data (refused, as a newer version's is: Core/Main.lua leaves it unset all session), no line showing: an
-- item under the pointer errs nothing, as each of the game's item tooltips asks whether a line shows
ns.Folders.SetOpen(stats, false)
F.RunTimers()
local erred, db = errors(), ns.db
ns.db = nil
hover(2005, 42)
ns.db = db
gone()
expect(errors() == erred, "with no saved data, an item under the pointer errs: " .. select(2, errors()))
expect(errors() == 0, "what would be on the lines errs: " .. select(2, errors()))
