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
        if object(s.key) and text(s.key):find(BLUE, 1, true) then
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
-- a first weapon in the off hand, 20 - 30 at 1,80, none there now: no line of the off hand (Ikar 2026-11-26: Main
-- gauche with two weapons alone; no line comes under the pointer), the damage a second of both hands says it, the
-- game's half of its hits asked (its talents unknown)
F.items[3003] = { class = 2, subclass = 15, equip = "INVTYPE_WEAPONOFFHAND" }
F.linkLines[link(3003, 63)] = { { "Dégâts\194\160: 20 - 30", "Vitesse 1,80" } }
hover(3003, 63)
local both = text("MELEE_DPS")
seen()
gone()
local half = 289 * 1.8 / 14
local dps = (75 + 2 * power) / 2 / 2.6 + ((20 + half) / 2 + (30 + half) / 2) / 2 / 1.8
expect(object("OFFHAND_DAMAGE") == nil and both == object("MELEE_DPS").label .. " " .. BLUE
    .. ns.Format.Decimal(dps, 1) .. "|r " .. ns.Stats.UNKNOWN,
    "with no off-hand weapon, a first one there isn't said by the damage a second, asked, or a line of the off hand "
    .. "shows: " .. both)
-- two weapons worn (a dagger in the off hand: its line), a two-handed one tried: the off hand left empty, « Aucune »
local function equipped()
    F.Fire("PLAYER_EQUIPMENT_CHANGED")
    F.RunTimers()
end
F.items[1017] = { class = 2, subclass = 15, equip = "INVTYPE_WEAPONOFFHAND" }
equipped()
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
F.items[1017] = nil
equipped()
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
-- (the main hand named « Deux mains » with a two-handed weapon, the game's word)
local twoHand = object("MAINHAND_DAMAGE").label
gone()
expect(twoHand == ns.G("INVTYPE_2HWEAPON", "Two-Hand"), "a two-handed weapon's line isn't named so: " .. twoHand)
F.mainHand.equip, F.itemStats[16] = nil, nil
expect(bare:find(BLUE, 1, true) and bare:sub(-#ns.Stats.UNKNOWN) == ns.Stats.UNKNOWN
    and weaker == object("STRENGTH").label .. " " .. BLUE .. (select(2, UnitStat("player", 1)) - 10) .. "|r",
    "a shield tried doesn't take the two-handed weapon worn off with it: " .. bare .. " / " .. weaker)
UnitAttackSpeed, UnitDamage = attackSpeed, unitDamage
-- a bow worn, 20 - 30 at 3,00 (its section shows: Distance with a ranged weapon alone), another tried, 15 - 28 at
-- 2,90, the ranged attack power's 53: the ranged line and its damage a second, the same arrows
local wornRanged = 53 * 3 / 14
F.items[1018] = { class = 2, subclass = 2, equip = "INVTYPE_RANGED" }
F.itemLines[18] = { { "Dégâts\194\160: 20 - 30", "Vitesse 3,00" } }
UnitRangedDamage = function()
    return 3, 20 + wornRanged, 30 + wornRanged, 0, 0, 1
end
equipped()
F.items[3005] = { class = 2, subclass = 2, equip = "INVTYPE_RANGED" }
F.linkLines[link(3005, 65)] = { { "Dégâts\194\160: 15 - 28", "Vitesse 2,90" } }
hover(3005, 65)
local bow, bowDps = text("RANGED_DAMAGE"), text("RANGED_DPS")
seen()
gone()
local ranged = 53 * 2.9 / 14
expect(bow == object("RANGED_DAMAGE").label .. " " .. BLUE .. math.floor(15 + ranged) .. " - " .. math.ceil(28 + ranged)
    .. "|r" and bowDps == object("RANGED_DPS").label .. " " .. BLUE
    .. ns.Format.Decimal((43 + 2 * ranged) / 2 / 2.9, 1) .. "|r",
    "the ranged line or its damage a second doesn't say what another bow would hit for: " .. bow .. " / " .. bowDps)
-- the chest's ranged attack power on the bow's section
hover(3001, 61)
seen()
gone()
UnitRangedDamage, F.items[1018], F.itemLines[18] = rangedDamage, nil, nil
equipped()
-- (a line shown once keeps its object: what the folder holds says what shows)
local function inFolder(key)
    for _, e in ipairs(ns.Hub.InFolder(ns.Folders.ByRole("stats"))) do
        if e.name == "KaLiHUD_Attr_" .. key then
            return true
        end
    end
    return false
end
-- (its title kept in the folder, saying it doesn't show: Seeds.Title's `when`, the list's layout leaving it out)
local rangedTitle, rangedId
for _, e in ipairs(ns.Hub.InFolder(ns.Folders.ByRole("stats"))) do
    if e.isSeparator and ns.Separators.Name(e.name) == ns.G("STAT_CATEGORY_RANGED", "Ranged") then
        rangedTitle, rangedId = e.obj, e.name
    end
end
-- (and the open list draws no title there: Folders.Layout leaves it out)
local titleButton = rangedId and ns.HubButtons.Get(rangedId)
expect(not inFolder("RANGED_DAMAGE") and not inFolder("RANGED_DPS") and inFolder("MELEE_DPS")
    and rangedTitle and rangedTitle.available() == false and not (titleButton and titleButton:IsVisible()),
    "without a ranged weapon, its section's lines show, or its title doesn't say it doesn't, or is drawn")
F.items[1018] = { class = 2, subclass = 2, equip = "INVTYPE_RANGED" }
equipped()

-- what only an effect changes: a consumable each (Data/Effects.lua's ITEM_USES, the game's own items)
local function drunk(id)
    F.items[id] = { class = 0, subclass = 2 }
    F.Hover("Item", { hyperlink = "|cffffffff|Hitem:" .. id .. ":::::::::60:::::|h[Objet 98]|h|r" })
    F.RunTimers()
end
for _, case in ipairs({ { 941, "MOVESPEED" }, { 21670, "ARMORPEN" }, { 19344, "HEALDONE" }, { 211815, "HEALTAKEN" },
    { 4420, "HEALTAKEN" } }) do
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

-- the panel of 2026-11-26's lines (UI/Hub/Infos/Stats.lua's), a consumable each made for it: the threat, the thorns,
-- the damage taken's share and points; the stealth and its detection, and the creature types, shown once the character
-- has some (a buff), then followed
local function made(id, effects)
    ns.EFFECTS[900000 + id] = effects
    ns.ITEM_USES[id] = tostring(900000 + id)
end
made(3031, "1,1;10:127:0:0:-30")
made(3032, "1,1;15:8:0:0:20")
made(3033, "2,2;87:127:0:0:-10;14:127:1:1:-5")
for _, case in ipairs({ { 3031, "THREAT" }, { 3032, "THORNS" }, { 3033, "DAMAGETAKEN" } }) do
    drunk(case[1])
    seen()
    local line = text(case[2])
    gone()
    expect(line:find(BLUE, 1, true), "the line " .. case[2] .. " doesn't follow its consumable: " .. line)
end
ns.EFFECTS[900034] = "4,4;154:0:0:0:5;17:0:1:1:5;102:511:2:2:10;180:511:3:3:10"
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Sombre", spellId = 900034, icon = 1, applications = 0,
    auraInstanceID = 9201 }
F.Fire("UNIT_AURA", "player")
F.RunTimers()
local shown = object("STEALTH") and object("STEALTH_DETECT") and object("VS_UNDEAD") and object("VS_BEAST")
made(3035, "4,4;154:0:0:0:10;17:0:1:1:10;102:511:2:2:20;180:511:3:3:20")
drunk(3035)
seen()
local undead = shown and text("VS_UNDEAD")
gone()
F.auras.HELPFUL[#F.auras.HELPFUL] = nil
F.Fire("UNIT_AURA", "player")
F.RunTimers()
expect(shown and undead:find(BLUE, 1, true) and not inFolder("STEALTH") and not inFolder("VS_UNDEAD"),
    "the stealth, its detection or a creature type isn't shown with some, followed, or hidden with none: "
    .. tostring(undead))
-- the item level: the game's average, 60 over sixteen slots; a chest of level 76 tried, 61
local levelOf, average = C_Item.GetDetailedItemLevelInfo, GetAverageItemLevel
C_Item.GetDetailedItemLevelInfo = function(item)
    return tostring(item):find("item:3001:", 1, true) and 76 or 60
end
GetAverageItemLevel = function()
    return 60, 60
end
hover(3001, 61)
seen()
local level = text("ILVL")
gone()
C_Item.GetDetailedItemLevelInfo, GetAverageItemLevel = levelOf, average
expect(level == object("ILVL").label .. " " .. BLUE .. "61|r", "the item level doesn't follow a chest tried: " .. level)

-- what the first checks of the panel left out (Ikar 2026-11-26: "why the tests gaps ?")
local function card(key)
    local name = "KaLiHUD_Attr_" .. key
    ns.Hub.Object(name).OnEnter(ns.HubButtons.Get(name) or UIParent)
    local lines = table.concat((ns.StatCard.Lines(true)), "\n")
    ns.Hub.Object(name).OnLeave()
    return lines
end
local function refresh()
    F.Fire("UNIT_AURA", "player")
    F.RunTimers()
end
-- the spells' critical strike by school on its card, where a talent sets one apart (fire 9 %, the rest 1,5 %); none
-- where all are the same
local critOf = GetSpellCritChance
local same = card("CRITCHANCE")
GetSpellCritChance = function(school)
    return school == 3 and 9 or 1.5
end
local apart = card("CRITCHANCE")
GetSpellCritChance = critOf
local schools = ns.L.STAT_CRIT_SCHOOLS:match("^(.-)%%s")
expect(not same:find(schools, 1, true) and apart:find(schools, 1, true)
    and apart:find(ns.G("DAMAGE_SCHOOL3", "Fire") .. " " .. ns.Format.PercentOf(9, 1), 1, true),
    "the spells' critical strike by school isn't on the card where one differs, or is where none does: " .. apart)
-- the avoidance without the block: a block chance of 10 % changes nothing of it
local blockOf, evaded = GetBlockChance, text("AVOIDANCE")
GetBlockChance = function()
    return 10
end
refresh()
local blocking = text("AVOIDANCE")
GetBlockChance = blockOf
refresh()
expect(blocking == evaded, "the avoidance counts the block: " .. evaded .. " / " .. blocking)
-- a worn ring's attack power against the undead (Forever's item stat 128): its line shows; a ring of more tried
F.itemStats[11] = { ITEM_MOD_ATTACK_POWER_VS_UNDEAD_SHORT = 30 }
equipped()
local undeadShown = inFolder("VS_UNDEAD") and text("VS_UNDEAD")
local undeadLabel = undeadShown and object("VS_UNDEAD").label
ring(3016, 77, { ITEM_MOD_ATTACK_POWER_VS_UNDEAD_SHORT = 50 })
local undeadTried = text("VS_UNDEAD")
gone()
F.itemStats[11] = nil
equipped()
expect(undeadShown == tostring(undeadLabel) .. " "
    .. ns.Infos.Color(string.format(ns.L.STAT_VS_POWER, "30"), ns.Infos.GOOD)
    and undeadTried:find(BLUE .. string.format(ns.L.STAT_VS_POWER, "50"), 1, true) and not inFolder("VS_UNDEAD"),
    "an item's attack power against the undead isn't its line's, followed, or the line stays without it: "
    .. tostring(undeadShown) .. " / " .. tostring(undeadTried))
-- the item level, a two-handed weapon of 76 worn, the off hand empty: counted for both hands (the game's 62 over
-- sixteen slots); a chest of 76 tried, 63
local linkOf, levelOf, average = GetInventoryItemLink, C_Item.GetDetailedItemLevelInfo, GetAverageItemLevel
GetInventoryItemLink = function(unit, slot)
    if slot == 17 then
        return nil
    end
    return linkOf(unit, slot)
end
C_Item.GetDetailedItemLevelInfo = function(item)
    local s = tostring(item)
    return (s:find("item:1016:", 1, true) or s:find("item:3001:", 1, true)) and 76 or 60
end
GetAverageItemLevel = function()
    return 62, 62
end
F.mainHand.equip = "INVTYPE_2HWEAPON"
hover(3001, 61)
local twice = text("ILVL")
gone()
GetInventoryItemLink, C_Item.GetDetailedItemLevelInfo, GetAverageItemLevel = linkOf, levelOf, average
F.mainHand.equip = nil
expect(twice == object("ILVL").label .. " " .. BLUE .. "63|r",
    "the item level doesn't count a two-handed weapon for both hands: " .. twice)
-- the damage taken lowered in green: -10 % and 5 less a blow
ns.EFFECTS[900040] = "2,2;87:127:0:0:-10;14:127:1:1:-5"
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Aguerri", spellId = 900040, icon = 1, applications = 0,
    auraInstanceID = 9301 }
refresh()
local taken = text("DAMAGETAKEN")
F.auras.HELPFUL[#F.auras.HELPFUL] = nil
refresh()
expect(taken == object("DAMAGETAKEN").label .. " " .. ns.Infos.Color(ns.Format.Percent(-0.1), ns.Infos.GOOD) .. " "
    .. ns.Infos.Color("- 5", ns.Infos.GOOD), "the damage taken lowered isn't green: " .. taken)

-- what the review of 2026-11-26 found
-- the traps' detection (17's misc 1: the rogues' Detect Traps, 70) isn't the stealth's
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Détection des pièges", spellId = 2836, icon = 1, applications = 0,
    auraInstanceID = 9401 }
refresh()
local traps = inFolder("STEALTH_DETECT")
F.auras.HELPFUL[#F.auras.HELPFUL] = nil
refresh()
expect(not traps, "the traps' detection shown as the stealth's")
-- a talent learnt that gives stealth (Master of Deception, 5 at its first rank), no aura nor item with it: its line
-- shows once the points change, and goes with it
F.talents[#F.talents + 1] = { spell = 13958, rank = 1, ranks = 3 }
F.Fire("CHARACTER_POINTS_CHANGED")
F.RunTimers()
local learnt = inFolder("STEALTH")
-- (its card saying the game's points, 5 a level: Ikar 2026-11-26, "add a note that 1 level correspond to 5 points")
local stealthCard = learnt and card("STEALTH") or ""
F.talents[#F.talents] = nil
F.Fire("CHARACTER_POINTS_CHANGED")
F.RunTimers()
expect(learnt and not inFolder("STEALTH"), "a talent's stealth doesn't show its line once learnt, or stays once gone")
expect(stealthCard:find(ns.L.STAT_STEALTH_LEVEL, 1, true), "the stealth's card doesn't say 5 points make a level: "
    .. stealthCard)
-- the main hand empty, 20 % of melee haste: a sword tried strikes at its speed so hastened, the game's haste (no worn
-- weapon there to compare its speed with; Ikar 2026-11-26: "Why does it ignore haste ?")
local linkOf16, meleeHaste, lines16 = GetInventoryItemLink, GetMeleeHaste, F.itemLines[16]
GetInventoryItemLink = function(unit, slot)
    if slot == 16 then
        return nil
    end
    return linkOf16(unit, slot)
end
GetMeleeHaste = function()
    return 20
end
F.itemLines[16] = nil
hover(3002, 62)
local hastened = text("MELEE_DPS")
gone()
GetInventoryItemLink, GetMeleeHaste, F.itemLines[16] = linkOf16, meleeHaste, lines16
local swordHit = 289 * 2.8 / 14
expect(hastened == object("MELEE_DPS").label .. " " .. BLUE
    .. ns.Format.Decimal((50 + 80 + 2 * swordHit) / 2 / (2.8 * 100 / 120), 1) .. "|r",
    "a weapon tried in an empty hand ignores the haste: " .. hastened)
-- the threat's card: a school's share apart where one differs (Righteous Fury's kind, +60 % on the holy alone), the
-- line the physical's (Ikar 2026-11-26: "agreed")
ns.EFFECTS[900061] = "1,1;10:2:0:0:60"
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Fureur", spellId = 900061, icon = 1, applications = 0,
    auraInstanceID = 9502 }
refresh()
local holyCard, holyLine = card("THREAT"), text("THREAT")
F.auras.HELPFUL[#F.auras.HELPFUL] = nil
refresh()
local evenCard = card("THREAT")
local bySchool = ns.L.STAT_THREAT_SCHOOLS:match("^(.-)%%s")
expect(holyCard:find(bySchool .. ns.G("DAMAGE_SCHOOL2", "Holy") .. " +", 1, true) and not evenCard:find(bySchool, 1, true)
    and not holyLine:find("60", 1, true),
    "the threat's card doesn't give the holy's share apart, or the line takes it: " .. holyLine .. " / " .. holyCard)
-- in a fight, where the game hides the effects on the character: a spell's line its share as before the fight (+10 %
-- of fire), its points the game's live (25), the question after it (Ikar 2026-11-26: "every single stat change during
-- combat, if it is possible and permitted by blizard", then "agreed")
ns.EFFECTS[900062] = "1,1;79:4:0:0:10"
F.auras.HELPFUL[#F.auras.HELPFUL + 1] = { name = "Brasier", spellId = 900062, icon = 1, applications = 0,
    auraInstanceID = 9503 }
refresh()
local calmFire = text("SPELLPOWER_FIRE")
local spellOf = GetSpellBonusDamage
F.EnterCombat()
GetSpellBonusDamage = function(school)
    if school == 3 then
        return 25
    end
    return spellOf(school)
end
F.Fire("SPELL_POWER_CHANGED")
F.RunTimers()
local fightFire = text("SPELLPOWER_FIRE")
F.LeaveCombat()
GetSpellBonusDamage = spellOf
F.auras.HELPFUL[#F.auras.HELPFUL] = nil
refresh()
local tenFire = ns.Infos.Color("+" .. ns.Format.Percent(0.1), ns.Infos.GOOD)
expect(calmFire == object("SPELLPOWER_FIRE").label .. " " .. tenFire
    and fightFire == object("SPELLPOWER_FIRE").label .. " " .. tenFire .. " + 25 " .. ns.Stats.UNKNOWN,
    "in a fight, a spell's line doesn't keep its share, asked, beside the game's points: " .. calmFire .. " / "
    .. fightFire)
-- an elixir of no known strength: the lines that work out their own figure ask where they stand on it, as the attack
-- power does (the main hand, the damage a second, a value's change read again from what is kept: Tried.Change)
made(3036, "1,1;29:0:0:0:")
drunk(3036)
local strongPower, strongHand, strongDps = text("ATTACK_AP"), text("MAINHAND_DAMAGE"), text("MELEE_DPS")
gone()
expect(strongPower == object("ATTACK_AP").label .. " " .. ns.Stats.UNKNOWN
    and strongHand == object("MAINHAND_DAMAGE").label .. " " .. ns.Stats.UNKNOWN
    and strongDps == object("MELEE_DPS").label .. " " .. ns.Stats.UNKNOWN,
    "a line working out its own figure doesn't ask where the strength it stands on can't be said: " .. strongPower
    .. " / " .. strongHand .. " / " .. strongDps)
-- (the hand's card kept open: its speed asked too)
ns.Hub.Object("KaLiHUD_Attr_MAINHAND_DAMAGE").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_MAINHAND_DAMAGE") or UIParent,
    "LeftButton")
F.RunTimers()
drunk(3036)
local strongCard = table.concat((ns.StatCard.PinnedLines(nil, "MAINHAND_DAMAGE")), "\n")
gone()
ns.StatCard.Unpin()
F.RunTimers()
expect(strongCard:find(string.format(ns.G("STAT_FORMAT", "%s:"), ns.G("ATTACK_SPEED_SECONDS", "Attack Speed (seconds)"))
    .. " " .. ns.Infos.Color(ns.Format.Decimal(2.6, 2), ns.Stats.WAS_HEX) .. " " .. ns.Stats.ARROW .. " "
    .. ns.Stats.UNKNOWN, 1, true),
    "a hand's card kept open says its speed where the strength it stands on can't be said: " .. strongCard)
-- a worn ring's spell damage against the undead (Forever's item stat 138): on the line, and on its card in the spells'
-- column, its total under it (the card had the attack power's sources alone)
F.itemStats[11] = { ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT = 40 }
equipped()
local undeadCard = inFolder("VS_UNDEAD") and card("VS_UNDEAD") or ""
F.itemStats[11] = nil
equipped()
expect(undeadCard:find(ns.G("SPELLS", "Spells"), 1, true) and select(2, undeadCard:gsub("%+40", "")) >= 3,
    "a creature type's spell damage isn't on its card: " .. undeadCard)
-- the retired lines in no menu of the bar's, their copies alone left (the « Attributs » of its menu had listed them)
F.RunScript(ns.InfoBar.frame, "OnMouseUp", "RightButton")
expect(F.MenuItem(object("SPELLHEALING").label) == nil and F.MenuItem(object("HEALTAKEN_FLAT").label) == nil,
    "a retired line is listed in the bar's menu")
-- a spell power its sources don't all name (« Autres », the fire's 40): its card seen, kept for the bug report as any
-- card's (UI/Hub/Infos/StatCheck.lua); kept open, « Autres » stays as it is under the pointer, as on any card
local bonusOf = GetSpellBonusDamage
GetSpellBonusDamage = function(school)
    if school == 3 then
        return 40
    end
    return bonusOf(school)
end
refresh()
KaLiHUDDevDB = KaLiHUDDevDB or {}
KaLiHUDDevDB.statChecks = nil
card("SPELLPOWER_FIRE")
local noted = false
for _, e in ipairs(KaLiHUDDevDB.statChecks and KaLiHUDDevDB.statChecks.cards or {}) do
    noted = noted or e.stat == "SPELLPOWER_FIRE"
end
ns.Hub.Object("KaLiHUD_Attr_SPELLPOWER_FIRE").OnClick(ns.HubButtons.Get("KaLiHUD_Attr_SPELLPOWER_FIRE") or UIParent,
    "LeftButton")
F.RunTimers()
ring(3011, 71, { ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = 10 })
local fireCard = table.concat((ns.StatCard.PinnedLines(nil, "SPELLPOWER_FIRE")), "\n")
gone()
ns.StatCard.Unpin()
F.RunTimers()
GetSpellBonusDamage = bonusOf
refresh()
KaLiHUDDevDB.statChecks = nil
expect(noted, "a spell power's « Autres » isn't kept for the bug report as its card is seen")
expect(fireCard:find(ns.L.STAT_OTHER, 1, true)
    and not fireCard:find(ns.Stats.ARROW .. " " .. ns.Infos.Color("0", ns.Stats.WOULD_HEX), 1, true),
    "a spell power's « Autres » goes under the pointer on its card kept open: " .. fireCard)

-- every line, not one left (a retired one, out of the folder, aside)
local left = {}
for _, s in ipairs(ns.Stats.LIST) do
    if not followed[s.key] and not s.retired then
        left[#left + 1] = s.key
    end
end
expect(#left == 0, "lines that follow nothing under the pointer: " .. table.concat(left, " "))
expect(errors() == 0, "the lines that follow err: " .. select(2, errors()))
