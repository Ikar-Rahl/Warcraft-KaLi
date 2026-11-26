-- Every line of the attributes' folder follows what is under the pointer (Ikar 2026-11-26: "Everything should follow,
-- every, single, line. Not a single exception. Under no cisrcumstances"): for each, something that changes it, and
-- the line says what it would be, in the blue; at the end, a line none of them turned blue fails, a new line too.
-- The hands' figures checked (UI/Hub/Infos/Stats.lua's Tried.Hand), and the health's regeneration by the spirit,
-- an estimate, the game's question after it (Tried.HealthFromSpirit).
local F = FakeWoW
login()
local BLUE = "|c" .. ns.Stats.WOULD_HEX
local function object(key)
    return ns.Hub.Object("KaLiHUD_Attr_" .. key)
end
local function text(key)
    return tostring(object(key).text)
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
-- (the health's regeneration standing and in a fight, and the spirit's share of it, as the game gives them: the fake's
-- own has none)
GetHealthRegen = function()
    return 2, 0.5
end
GetHealthRegenFromSpirit = function()
    return 1.5
end
ns.StatCard.Unpin()
ns.Folders.SetOpen(ns.Folders.ByRole("stats"), true)
F.RunTimers()
-- each line said in the blue so far
local followed = {}
local function seen()
    for _, s in ipairs(ns.Stats.LIST) do
        if text(s.key):find(BLUE, 1, true) then
            followed[s.key] = true
        end
    end
end

-- a chest of everything an item can carry
F.items[3001] = { class = 4, subclass = 4, equip = "INVTYPE_CHEST" }
F.itemStats[61] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 10,
    ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPIRIT_SHORT = 10, ITEM_MOD_HEALTH_SHORT = 50, ITEM_MOD_MANA_SHORT = 50,
    ITEM_MOD_ATTACK_POWER_SHORT = 20, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 20, ITEM_MOD_HIT_RATING_SHORT = 10,
    ITEM_MOD_CRIT_RATING_SHORT = 10, ITEM_MOD_HASTE_RATING_SHORT = 10, ITEM_MOD_EXPERTISE_RATING_SHORT = 10,
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10, ITEM_MOD_DODGE_RATING_SHORT = 10, ITEM_MOD_PARRY_RATING_SHORT = 10,
    ITEM_MOD_BLOCK_RATING_SHORT = 10, ITEM_MOD_BLOCK_VALUE_SHORT = 10, ITEM_MOD_HEALTH_REGEN_SHORT = 5,
    ITEM_MOD_MANA_REGENERATION_SHORT = 5, ITEM_MOD_SPELL_POWER_SHORT = 10, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10,
    ITEM_MOD_SPELL_PENETRATION_SHORT = 10, RESISTANCE0_NAME = 100, RESISTANCE2_NAME = 10, RESISTANCE3_NAME = 10,
    RESISTANCE4_NAME = 10, RESISTANCE5_NAME = 10, RESISTANCE6_NAME = 10 }
hover(3001, 61)
seen()
local spirited, struck = text("HEALTH_REGEN"), text("MAINHAND_DAMAGE")
gone()
expect(struck:find(BLUE, 1, true), "the main hand doesn't follow the attack power the chest raises: " .. struck)
expect(spirited:find(BLUE, 1, true) and spirited:sub(-#ns.Stats.UNKNOWN) == ns.Stats.UNKNOWN,
    "the health's regeneration doesn't follow the chest's spirit, an estimate asked: " .. spirited)

-- a helm of 10 spirit, the health's regeneration's card kept open: its spirit's row standing an estimate, asked; its
-- total seated by the whole spirit's share (standing three quarters of it), the game's figures cut to a whole first
F.items[3006] = { class = 4, subclass = 4, equip = "INVTYPE_HEAD" }
F.itemStats[66] = { ITEM_MOD_SPIRIT_SHORT = 10 }
local function standing(more)
    return math.floor((1.5 + 1.26 / 2 * more) * 0.75 * 5 + 1e-6)
end
ns.Hub.Object("KaLiHUD_Attr_HEALTH_REGEN").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_HEALTH_REGEN") or UIParent,
    "LeftButton")
F.RunTimers()
hover(3006, 66)
local regenCard = table.concat((ns.StatCard.PinnedLines(nil, "HEALTH_REGEN")), "\n")
gone()
ns.StatCard.Unpin()
F.RunTimers()
local seatNow = math.floor(2 * 5 + 1.5 * 5 * 0.25 + 1e-6)
local seated = math.floor(seatNow + standing(10) - standing(0) + 1.26 / 2 * 10 * 5 * 0.25 + 1e-6)
expect(regenCard:find(ns.Stats.Became(standing(0), standing(10) .. " " .. ns.Stats.UNKNOWN), 1, true)
    and regenCard:find(ns.Stats.Became(seatNow, seated), 1, true),
    "the health's regeneration's card doesn't follow a helm's spirit, an estimate asked: " .. regenCard)
-- a class the original server hasn't: no slope, the question alone
local unitClass = UnitClass
UnitClass = function()
    return "Moine", "MONK", 10
end
hover(3006, 66)
local monk = text("HEALTH_REGEN")
gone()
UnitClass = unitClass
expect(monk == object("HEALTH_REGEN").label .. " " .. ns.Stats.UNKNOWN,
    "a class with no known slope says its health's regeneration under a helm's spirit: " .. monk)

-- the hands (UI/Hub/Infos/Stats.lua's Tried.Hand): the sword worn, 30 - 45 at 2,60, its hits the game's with the
-- attack power's 289 (a point a second for 14 a hit); one of 50 - 80 at 2,80 tried in its place
local power = 289 * 2.6 / 14
F.itemLines[16] = { { "Dégâts\194\160: 30 - 45", "Vitesse 2,60" } }
local unitDamage, attackSpeed, rangedDamage = UnitDamage, UnitAttackSpeed, UnitRangedDamage
UnitDamage = function()
    return 30 + power, 45 + power, 0, 0, 0, 0, 1
end
F.items[3002] = { class = 2, subclass = 7, equip = "INVTYPE_WEAPON" }
F.linkLines[link(3002, 62)] = { { "Dégâts\194\160: 50 - 80", "Vitesse 2,80" } }
hover(3002, 62)
local sword = text("MAINHAND_DAMAGE")
seen()
gone()
local tried = 289 * 2.8 / 14
expect(sword == object("MAINHAND_DAMAGE").label .. " " .. BLUE .. math.floor(50 + tried) .. "-"
    .. math.ceil(80 + tried) .. "|r", "the main hand doesn't say what a sword tried would hit for: " .. sword)
-- its card kept open: its head what the line says, its speed and its damage a second as they would be
ns.Hub.Object("KaLiHUD_Attr_MAINHAND_DAMAGE").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_MAINHAND_DAMAGE") or UIParent,
    "LeftButton")
F.RunTimers()
hover(3002, 62)
local shown = table.concat((ns.StatCard.PinnedLines(nil, "MAINHAND_DAMAGE")), "\n")
gone()
ns.StatCard.Unpin()
F.RunTimers()
local Format = ns.Format
expect(shown:find(BLUE .. math.floor(50 + tried) .. "-" .. math.ceil(80 + tried) .. "|r", 1, true)
    and shown:find(ns.Stats.Became(Format.Decimal(2.6, 2), Format.Decimal(2.8, 2)), 1, true)
    and shown:find(ns.Stats.Became(Format.Decimal((75 + 2 * power) / 2 / 2.6, 1),
        Format.Decimal((130 + 2 * tried) / 2 / 2.8, 1)), 1, true),
    "the main hand's card kept open doesn't say what a sword tried would make of it: " .. shown)
-- worn with an enchantment's 2 more on each hit, in the base the game gives: kept for the sword tried, asked (it may
-- go with the weapon)
UnitDamage = function()
    return 32 + power, 47 + power, 0, 0, 0, 0, 1
end
hover(3002, 62)
local kept = text("MAINHAND_DAMAGE")
gone()
expect(kept == object("MAINHAND_DAMAGE").label .. " " .. BLUE .. math.floor(52 + tried) .. "-" .. math.ceil(82 + tried)
    .. "|r " .. ns.Stats.UNKNOWN, "the main hand doesn't keep, asked, what its base holds beside the weapon: " .. kept)
-- a druid in a form strikes with its paws: a weapon tried changes nothing of its hits
local druid, shapeshift = UnitClass, GetShapeshiftForm
UnitClass = function()
    return "Druidesse", "DRUID", 11
end
GetShapeshiftForm = function()
    return 3
end
hover(3002, 62)
local paws = text("MAINHAND_DAMAGE")
gone()
UnitClass, GetShapeshiftForm = druid, shapeshift
UnitDamage = function()
    return 30 + power, 45 + power, 0, 0, 0, 0, 1
end
expect(not paws:find(BLUE, 1, true), "a druid in a form has a weapon tried change its hits: " .. paws)
-- a first weapon in the off hand, 20 - 30 at 1,80: the game's half of its hits, asked (its talents unknown)
F.items[3003] = { class = 2, subclass = 15, equip = "INVTYPE_WEAPONOFFHAND" }
F.linkLines[link(3003, 63)] = { { "Dégâts\194\160: 20 - 30", "Vitesse 1,80" } }
hover(3003, 63)
local dagger = text("OFFHAND_DAMAGE")
seen()
gone()
local half = 289 * 1.8 / 14
expect(dagger == object("OFFHAND_DAMAGE").label .. " " .. BLUE .. math.floor((20 + half) / 2) .. " - "
    .. math.ceil((30 + half) / 2) .. "|r " .. ns.Stats.UNKNOWN,
    "the off hand doesn't say what a first weapon there would hit for, asked: " .. dagger)
-- two weapons worn, a two-handed one tried: the off hand left empty, « Aucune »
UnitAttackSpeed = function()
    return 2.6, 1.8
end
UnitDamage = function()
    return 30 + power, 45 + power, 25, 35, 0, 0, 1
end
F.items[3004] = { class = 2, subclass = 8, equip = "INVTYPE_2HWEAPON" }
F.linkLines[link(3004, 64)] = { { "Dégâts\194\160: 90 - 140", "Vitesse 3,60" } }
hover(3004, 64)
local emptied = text("OFFHAND_DAMAGE")
seen()
gone()
expect(emptied == object("OFFHAND_DAMAGE").label .. " " .. BLUE .. ns.G("NONE", "None") .. "|r",
    "the off hand isn't left empty by a two-handed weapon tried: " .. emptied)
-- a shield tried there: no weapon in it, « Aucune »
F.items[3007] = { class = 4, subclass = 6, equip = "INVTYPE_SHIELD" }
hover(3007, 67)
local shielded = text("OFFHAND_DAMAGE")
gone()
expect(shielded == object("OFFHAND_DAMAGE").label .. " " .. BLUE .. ns.G("NONE", "None") .. "|r",
    "the off hand isn't left empty by a shield tried: " .. shielded)
-- a two-handed weapon worn, its 10 strength, a shield tried: the weapon comes off with it (the game's comparison shows
-- both; Ikar 2026-11-26: "when hovering a shield, does it also take into account the new main weapon ?"), the
-- strength without its 10, the main hand its fists, asked
UnitAttackSpeed = function()
    return 2.6, nil
end
UnitDamage = function()
    return 30 + power, 45 + power, 0, 0, 0, 0, 1
end
F.mainHand.equip, F.itemStats[16] = "INVTYPE_2HWEAPON", { ITEM_MOD_STRENGTH_SHORT = 10 }
hover(3007, 67)
local bare, weaker = text("MAINHAND_DAMAGE"), text("STRENGTH")
gone()
F.mainHand.equip, F.itemStats[16] = nil, nil
expect(bare:find(BLUE, 1, true) and bare:sub(-#ns.Stats.UNKNOWN) == ns.Stats.UNKNOWN
    and weaker == object("STRENGTH").label .. " " .. BLUE .. (select(2, UnitStat("player", 1)) - 10) .. "|r",
    "a shield tried doesn't take the two-handed weapon worn off with it: " .. bare .. " / " .. weaker)
UnitAttackSpeed, UnitDamage = attackSpeed, unitDamage
-- a first bow, 15 - 28 at 2,90, the ranged attack power's 53: its arrows unknown, asked
F.items[3005] = { class = 2, subclass = 2, equip = "INVTYPE_RANGED" }
F.linkLines[link(3005, 65)] = { { "Dégâts\194\160: 15 - 28", "Vitesse 2,90" } }
hover(3005, 65)
local bow = text("RANGED_DAMAGE")
seen()
gone()
local ranged = 53 * 2.9 / 14
expect(bow == object("RANGED_DAMAGE").label .. " " .. BLUE .. math.floor(15 + ranged) .. " - " .. math.ceil(28 + ranged)
    .. "|r " .. ns.Stats.UNKNOWN,
    "the ranged line doesn't say what a first bow would hit for, asked: " .. bow)

-- what only an effect changes: a consumable each (Data/Effects.lua's ITEM_USES, the game's own items)
local function drunk(id)
    F.items[id] = { class = 0, subclass = 2 }
    F.Hover("Item", { hyperlink = "|cffffffff|Hitem:" .. id .. ":::::::::60:::::|h[Objet 98]|h|r" })
    F.RunTimers()
end
for _, case in ipairs({ { 941, "MOVESPEED" }, { 21670, "ARMORPEN" }, { 19344, "HEALDONE" }, { 211815, "HEALTAKEN" },
    { 4420, "HEALTAKEN_FLAT" } }) do
    drunk(case[1])
    seen()
    local line = text(case[2])
    gone()
    expect(line:find(BLUE, 1, true), "the line " .. case[2] .. " doesn't follow item " .. case[1] .. ": " .. line)
end

-- the physical damage's own changes on the hands (Tried.Physical; Ikar 2026-11-26: "would degat infliger change weapon
-- DPS ?"): a share of each hit, item 19337's +100 % on every school, and points on each, item 5206's +1 physical
local low, high = UnitDamage("player")
drunk(19337)
seen()
local doubled = text("MAINHAND_DAMAGE")
gone()
drunk(5206)
local sharper = text("MAINHAND_DAMAGE")
gone()
expect(doubled == object("MAINHAND_DAMAGE").label .. " " .. BLUE .. math.floor(low * 2) .. "-" .. math.ceil(high * 2)
    .. "|r" and sharper == object("MAINHAND_DAMAGE").label .. " " .. BLUE .. math.floor(low + 1) .. " - "
    .. math.ceil(high + 1) .. "|r", "the main hand doesn't follow the physical damage's share or points tried: "
    .. doubled .. " / " .. sharper)

-- a character with mana: the chest's intellect, spirit and mana every 5 s on its mana and its regeneration
local powerType, powerMax, manaRegen = UnitPowerType, UnitPowerMax, GetManaRegen
UnitPowerType = function()
    return 0, "MANA"
end
UnitPowerMax = function(_, kind)
    return (kind == nil or kind == Enum.PowerType.Mana) and 500 or 0
end
GetManaRegen = function()
    return 8.1, 4.85
end
F.Fire("UNIT_AURA", "player")
F.RunTimers()
hover(3001, 61)
seen()
local mana, regen = text("POWER"), text("REGEN")
gone()
UnitPowerType, UnitPowerMax, GetManaRegen = powerType, powerMax, manaRegen
expect(mana:find(BLUE, 1, true) and regen:find(BLUE, 1, true), "a mana user's lines don't follow the chest: " .. mana
    .. " / " .. regen)
-- the gaps (Ikar 2026-11-26: "fix the gaps"), a ring each in the ring's slot: Forever's items' fire damage (its stat
-- 85) on the fire's spell power alone, physical damage (83) on the hands, a resistance to every school (124) on each,
-- a weapon skill (« +5 Épées », the sword worn) on the critical strike
local function ring(id, name, stats)
    F.items[id] = { class = 4, subclass = 0, equip = "INVTYPE_FINGER" }
    F.itemStats[name] = stats
    hover(id, name)
end
ring(3011, 71, { ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = 10 })
local fire, frost = text("SPELLPOWER_FIRE"), text("SPELLPOWER_FROST")
gone()
ring(3012, 72, { ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT = 5 })
local hit = text("MAINHAND_DAMAGE")
gone()
ring(3013, 73, { ITEM_MOD_SPELL_RESISTANCE_ALL_SCHOOLS_SHORT = 10 })
local resisted = text("FIRE"):find(BLUE, 1, true) and text("SHADOW"):find(BLUE, 1, true)
gone()
ring(3014, 74, { ITEM_MOD_SWORDS_SHORT = 5 })
local skilled = text("CRITCHANCE")
gone()
local mainLow, mainHigh = UnitDamage("player")
expect(fire:find(BLUE, 1, true) and not frost:find(BLUE, 1, true)
    and hit == object("MAINHAND_DAMAGE").label .. " " .. BLUE .. math.floor(mainLow + 5) .. " - "
        .. math.ceil(mainHigh + 5) .. "|r" and resisted and skilled:find(BLUE, 1, true),
    "an item's school damage, physical damage, resistance to every school or weapon skill isn't followed: " .. fire
    .. " / " .. frost .. " / " .. hit .. " / " .. tostring(resisted) .. " / " .. skilled)
-- worn, a ring whose own +30 attack power the game shows as a buff (item 18537's), another tried in its place: the
-- buff goes with it
F.itemIDs[11], F.items[18537] = 18537, { class = 4, subclass = 0, equip = "INVTYPE_FINGER" }
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Puissance", spellId = 1318938, icon = 1, applications = 0,
    auraInstanceID = 9101 }
F.Fire("UNIT_AURA", "player")
F.RunTimers()
ring(3015, 75, {})
local stripped = text("ATTACK_AP")
gone()
F.itemIDs[11], F.auras.HELPFUL[#F.auras.HELPFUL] = nil, nil
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(stripped:find(BLUE, 1, true), "a ring tried keeps the worn one's own buff: " .. stripped)
-- a quiver worn in a bag's slot (the Light Quiver, +10 % of ranged haste with a bow), the Quickdraw Quiver tried in its
-- place (+13 %): the haste follows
local rangedHaste = GetRangedHaste
GetRangedHaste = function()
    return 10, 0
end
F.itemIDs[31] = 2101
F.items[2101] = { class = 11, subclass = 2, equip = "INVTYPE_BAG" }
F.items[8217] = { class = 11, subclass = 2, equip = "INVTYPE_BAG" }
F.items[1018] = { class = 2, subclass = 2, equip = "INVTYPE_RANGED" }
F.Fire("UNIT_AURA", "player")
F.RunTimers()
F.Hover("Item", { id = 8217, hyperlink = link(8217, 76) })
F.RunTimers()
local quick = text("HASTE")
gone()
-- the bow's card kept open, its speed 3,00 with the 10 %: 3,00 x 110 / 113 with the 13 %
UnitRangedDamage = function()
    return 3, 20, 30, 0, 0, 1
end
ns.Hub.Object("KaLiHUD_Attr_RANGED_DAMAGE").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_RANGED_DAMAGE") or UIParent,
    "LeftButton")
F.RunTimers()
F.Hover("Item", { id = 8217, hyperlink = link(8217, 76) })
F.RunTimers()
local bowCard = table.concat((ns.StatCard.PinnedLines(nil, "RANGED_DAMAGE")), "\n")
gone()
ns.StatCard.Unpin()
F.RunTimers()
UnitRangedDamage = rangedDamage
expect(bowCard:find(ns.Stats.Became(ns.Format.Decimal(3, 2), ns.Format.Decimal(3 * 110 / 113, 2)), 1, true),
    "a quiver tried doesn't change the bow's speed on its card: " .. bowCard)
GetRangedHaste, F.itemIDs[31], F.items[1018] = rangedHaste, nil, nil
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(quick:find(BLUE .. "13", 1, true),
    "a quiver tried in the worn one's place doesn't change the haste: " .. quick)
-- a talent whose armour ignored is a share (Serrated Blades, 280): named, what it comes to not known, asked
F.talents[#F.talents + 1] = { spell = 14171, rank = 0, ranks = 3 }
F.Hover("Spell", { id = 14171 })
F.RunTimers()
local ignored = text("ARMORPEN")
gone()
F.talents[#F.talents] = nil
expect(ignored == object("ARMORPEN").label .. " " .. ns.Stats.UNKNOWN,
    "a talent ignoring a share of the armour isn't asked on the armour penetration: " .. ignored)

-- every line, not one left
local left = {}
for _, s in ipairs(ns.Stats.LIST) do
    if not followed[s.key] then
        left[#left + 1] = s.key
    end
end
expect(#left == 0, "lines that follow nothing under the pointer: " .. table.concat(left, " "))
expect(errors() == 0, "the lines that follow err: " .. select(2, errors()))
