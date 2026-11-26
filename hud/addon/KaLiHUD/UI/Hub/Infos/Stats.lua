-- The character's attributes (Ikar 2026-11-16: "stats, main and secondary, all of them, folder too"; "regen"): those
-- the character sheet shows on Forever (Blizzard_UIPanels_Game's Camelot PaperDollFrameConstants), in its order and
-- by its own names, read with the same calls; power regeneration with them. Each an item of the attributes' folder,
-- its categories split by separators. Read again on the sheet's events (Ikar 2026-11-16: "Do all stats react to buffs
-- and debuffs?"), its tooltip's base and changes on hover, then where those come from (Ikar 2026-11-16: "there is no
-- list of modificators on each, from where the +10 or -2 come from"; 2026-11-17: "I don't see the effect of my
-- elixirs and buffs", then "Can we extend to include all sources?"): what the value stands on, the attributes' share
-- of it and the items' own armour, then its changes, the items, their enchantments, the sets, the buffs and debuffs,
-- the talents, the race's and the class's passive spells. Its hover is a card (UI/Hub/Infos/StatCard.lua; Ikar
-- 2026-11-19: "Go with card 1"): those on its left, on its right what the value gives ("not only the source for
-- each, but what each provide"), between them what the sheet says of it. The game hides attributes from addons
-- during a fight (secret values): each keeps what it showed before the fight, read again once it's over.
local _, ns = ...

local Infos, Hub, L, Format = ns.Infos, ns.Hub, ns.L, ns.Format
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local Stats = {}
ns.Stats = Stats

local PREFIX = "KaLiHUD_Attr_"
-- The spell schools a spell's power or critical strike is read for, the sheet's lowest of them (holy to arcane).
local SCHOOLS = { 2, 3, 4, 5, 6, 7 }

local function G(name, fallback)
    return ns.G(name, fallback)
end

-- A chance as the sheet gives it, one decimal ("%.1f%%"), in the player's way of writing numbers.
local function percent(v)
    return Format.PercentOf(v, 1)
end

local function number(v)
    return Format.Number(v)
end

-- Its value in the sheet's colours (PaperDollFrame_SetStat, PaperDollFormatStat): lowered red but under the PvP gear
-- rules, else raised green.
local function buffed(v, pos, neg)
    if (neg or 0) < 0 and not GetPVPGearStatRules() then
        return Infos.Color(number(v), Infos.BAD)
    elseif (pos or 0) > 0 then
        return Infos.Color(number(v), Infos.GOOD)
    end
    return number(v)
end

-- Raised green only, as the sheet's armour and resistances (PaperDollFrame_FormatBonusValue).
local function raised(v, bonus)
    return (bonus or 0) > 0 and Infos.Color(number(v), Infos.GOOD) or number(v)
end

-- What the sheet's tooltip adds to a value buffs, gear or a debuff change (PaperDollFormatStat,
-- PaperDollFrame_SetStatTooltip): " (base+raised -lowered)", the raise green, the fall red; nothing when unchanged.
-- The game gives each way's sum; where it comes from, the tooltip's sources below (sourcesOf).
local function changes(base, pos, neg)
    pos, neg = pos or 0, neg or 0
    if pos <= 0 and neg >= 0 then
        return nil
    end
    return " (" .. number(base) .. (pos > 0 and Infos.Color("+" .. number(pos), Infos.GOOD) or "")
        .. (neg < 0 and Infos.Color(" " .. number(neg), Infos.BAD) or "") .. ")"
end

-- One change either way (armour's, a resistance's): its base what the value is without it.
local function changedBy(effective, bonus)
    bonus = bonus or 0
    return changes(effective - bonus, max(bonus, 0), min(bonus, 0))
end

-- An attack power as the sheet's (PaperDollFrame_SetAttackPower): its effective value, never below 0, or the spell
-- power it's taken from for a class whose attack power comes from it (GetOverrideAPBySpellPower); its changes after.
local function attackPower(base, pos, neg)
    if base == nil then
        return nil
    end
    local override = ns.Plain(GetOverrideAPBySpellPower())
    if override == nil then
        return nil
    elseif override > 0 then
        local low = ns.Plain(GetSpellBonusHealing())
        for _, school in ipairs(SCHOOLS) do
            local v = ns.Plain(GetSpellBonusDamage(school))
            if v == nil or low == nil then
                return nil
            end
            low = min(low, v)
        end
        return number(max(0, low * override))
    end
    return buffed(max(0, base + (pos or 0) + (neg or 0)), pos, neg), changes(base, pos, neg)
end

-- The same, as numbers for its sources; none for a class whose attack power comes from its spell power, which no
-- source names.
local function attackNumbers(base, pos, neg)
    if base == nil or ns.Plain(GetOverrideAPBySpellPower()) ~= 0 then
        return nil
    end
    pos, neg = pos or 0, neg or 0
    return base, max(0, base + pos + neg), pos, neg
end

-- Where each value's changes come from (sourcesOf): the gear's stats, by the game's names for them
-- (C_Item.GetItemStats), a rating as the share of a percent the sheet makes of it (`rating`, the sheet's CR_ kind);
-- the auras whose spells change it (Data/Effects.lua, the game's numbers for their kinds): by points (`flat`, of a
-- percent for a chance, a haste or a speed: `percent`; their opposite for the spell penetration, the targets'
-- resistances lowered: `negate`), by a share of the whole (`share`) or of the base (`baseShare`), or by a share the
-- game's numbers don't let work out (`shareOnly`: the armour's and resistances', their base not split from the
-- gear's; the health's); `misc` what such an aura's misc must be, `schools` the spells' schools named after one that
-- doesn't change them all, `when` whether the value has sources now (mana's, for a character that has some). A melee
-- attack power on gear raises the ranged one too, as the game's sheet adds it.
local ATTRIBUTE_KEYS = { "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" }
local function schools(class)
    local bit = 2 ^ class
    return function(misc)
        return floor(misc / bit) % 2 == 1
    end
end
local function manaShown()
    local _, token = UnitPowerType("player")
    return token == "MANA"
end
local function hasMana()
    return (ns.Plain(UnitPowerMax("player", Enum.PowerType.Mana)) or 0) > 0
end
-- The power shown's own (aura 35's misc the power's kind: a rogue's Vigor, 10 energy; the full review of 2026-11-20,
-- energy and rage had no sources), the items' mana for mana alone.
local function shownPower(misc)
    return misc == (UnitPowerType("player"))
end
local function powerGear()
    return manaShown() and { "ITEM_MOD_MANA_SHORT" } or {}
end
-- How the character moves now, for the speed's sources (the original server's rule): swimming,
-- mounted or running; each kind of aura's part in it, the strongest raise of a kind alone counting ("main",
-- "nonstack"), those of "stack" multiplied, the strongest slow alone.
local SPEED_ROLES = {
    run = { [31] = "main", [129] = "stack", [171] = "nonstack" },
    mounted = { [32] = "main", [130] = "stack", [172] = "nonstack" },
    swim = { [58] = "main" },
}
local function speedRole(kind, mode)
    return kind == 33 and "slow" or SPEED_ROLES[mode][kind]
end

-- The hit chance, the critical strike and the haste are each the best of three, the melee attacks', the ranged ones'
-- and the spells' ("m", "r", "s"), as the sheet shows them; what raises one doesn't raise the others, and a buff of
-- melee haste and ranged haste has two effects, not twice the haste (Ikar 2026-11-19: "the haste value seems
-- doubled": its sources added both). So their sources are those of the one shown: the best, the first when equal.
local function best(m, r, s)
    if type(m) ~= "number" or type(r) ~= "number" or type(s) ~= "number" then
        return nil
    elseif m >= r and m >= s then
        return "m", m
    elseif r >= s then
        return "r", r
    end
    return "s", s
end
-- Each as the sheet reads it (PaperDollFrame_SetHitChance, _SetCritChance, _SetHaste): melee, ranged, spells; the
-- hit's melee the better hand's, each hand's after.
local function hitBy()
    local melee = ns.Plain(GetCombatRatingBonus(CR_HIT_MELEE))
    local ranged = ns.Plain(GetCombatRatingBonus(CR_HIT_RANGED))
    local spell = ns.Plain(GetCombatRatingBonus(CR_HIT_SPELL))
    if not (melee and ranged and spell) then
        return nil
    end
    local main, off = melee + (ns.Plain(GetHitModifier()) or 0), melee + (ns.Plain(GetOffhandHitModifier()) or 0)
    return max(main, off), ranged + (ns.Plain(GetRangedHitModifier()) or 0),
        spell + (ns.Plain(GetSpellHitModifier()) or 0), main, off
end
local function critBy()
    return ns.Plain(GetCritChance()), ns.Plain(GetRangedCritChance()), ns.Plain(GetSpellCritChance())
end
local function hasteBy()
    local ranged, ammo = ns.Plain(GetRangedHaste())
    return ns.Plain(GetMeleeHaste()), ranged and (ranged + (ammo or 0)), ns.Plain(UnitSpellHaste("player"))
end
-- A rating by the kind of attack, the game's CR_ numbers (three in a row: melee, ranged, spells).
local function ratingBy(melee, channel)
    return melee + (channel == "s" and 2 or channel == "r" and 1 or 0)
end
-- An aura that gives a combat rating (189), its misc a mask of the ratings: the bit of the CR_ number less one.
local RATING_AURA = 189

-- What the level and the class give the attack power before the attributes, by class: melee a level's and its own,
-- ranged the same; the original server's, as Forever's (Ikar's shaman
-- at 24, 2026-11-21: 2 x 24 - 20, 28, the game's base to the point once Mental Dexterity was the game's). The
-- attributes' parts are the game's own (GetAttackPowerForStat); a druid's forms give theirs by their auras. A class
-- that shoots no ranged weapon (not RANGED_CLASS) has no ranged attack power at all, Forever's unlike the original
-- server: Ikar's shaman at 24 has 0, its agility giving none (GetRangedAttackPowerForStat) and Mental Dexterity none
-- (the probe of 2026-11-21: 0 with 37 agility and 40 intellect, « Erreur de l'addon » of -35 on the card the same
-- day, Ikar: "Why error on distance power ?").
local RANGED_CLASS = { WARRIOR = true, HUNTER = true, ROGUE = true }
local LEVEL_AP = {
    WARRIOR = { 3, -20, 1, -10 }, PALADIN = { 3, -20, 0, 0 }, ROGUE = { 2, -20, 1, -10 }, HUNTER = { 2, -20, 2, -10 },
    SHAMAN = { 2, -20, 0, 0 }, DRUID = { 0, -20, 0, 0 }, MAGE = { 0, -10, 0, 0 }, PRIEST = { 0, -10, 0, 0 },
    WARLOCK = { 0, -10, 0, 0 },
}
-- What the level and the class give, their sum, then each as a row of its own (Ikar 2026-11-21, of « Base 5 »: "where
-- do this come from ?"; then "lvl can be a source on it own, like intel"; 2026-11-24: "why it is not just base = -20
-- for everyone, isn't the chaman getting attack power that a druit do not ?"): « Base » first, the -20 or -10 every
-- class of its kind has, then the level's for a class it raises, « Niveau 26 (x2) » (the same day: "base shoudl come
-- before level, and level shoudl note level x 2, not 26 x 2. clearer", then "for level, even better: Level 26 (x2)").
local function levelAP(ranged)
    local _, class = UnitClass("player")
    local f, level = LEVEL_AP[class], ns.Plain(UnitLevel("player"))
    if not (f and type(level) == "number") then
        return nil
    end
    local per, own = f[ranged and 3 or 1], f[ranged and 4 or 2]
    local rows = {}
    if own ~= 0 then
        rows[#rows + 1] = { name = L.STAT_BASE, points = own }
    end
    if per ~= 0 then
        rows[#rows + 1] = { name = string.format(G("UNIT_LEVEL_TEMPLATE", "Level %d"), level) .. " (x" .. per .. ")",
            points = per * level }
    end
    return per * level + own, rows
end
-- Where a value's base comes from, its row named after it as the game's unit tooltip names a character (Ikar
-- 2026-11-21: "each base need to be explained"): the class's own (a chance: « Chaman »), the class's at its level
-- (health, mana: « Chaman niveau 24 »), the race's and the class's at its level (an attribute: « Orc Chaman niveau
-- 24 »), the defence's skill as trained (« Niveau de compétence »); the attack power's the level's, levelAP. A value
-- whose rest is none of these (armour, resistances, regeneration: their sources all named) has « Autres » (noBase).
local function baseName(spec)
    local of = spec.baseOf
    if type(of) == "function" then
        of = of()
    end
    local class, level, race = UnitClass("player"), ns.Plain(UnitLevel("player")), UnitRace("player")
    if of == "skill" then
        return G("SKILL_LEVEL", "Skill Level")
    elseif of == "class" and class then
        return class
    elseif (of == "classLevel" or of == "all") and class and type(level) == "number" then
        local who = of == "all" and race and race .. " " .. class or class
        return string.format(G("UNIT_TYPE_LEVEL_TEMPLATE", "Level %d %s"), level, who)
    end
    return L.STAT_BASE
end
-- A value's base as a row, named after where it comes from: drawn as an attribute's part is, a source of it, though
-- the game's figure less what's named (`other`).
local function baseRow(spec, points, percent, name)
    return { name = name or baseName(spec), points = points, percent = percent == true, base = true, other = true,
        origin = true }
end
local baseRows
do
    -- A class's base mana at a level, Forever's own (Data/Effects.lua's BASE_MANA): nil for one with none.
    local manaByLevel = {}
    local function baseMana(class, level)
        local list = manaByLevel[class]
        if not list then
            list = {}
            for v in ((ns.BASE_MANA or {})[class] or ""):gmatch("%d+") do
                list[#list + 1] = tonumber(v)
            end
            manaByLevel[class] = list
        end
        return list[level]
    end
    -- A class's base health at a level, the original game's table (Data/BaseStats.lua's health): Forever's data has
    -- none, and a level 26 dwarf shaman's is the table's to the point (Ikar's card of 2026-11-23: 767, 510 of it the
    -- stamina's, 257 the table's)
    local healthByLevel = {}
    local function baseHealth(class, level)
        local list = healthByLevel[class]
        if not list then
            list = {}
            for v in ((ns.BASE_STATS and ns.BASE_STATS.health or {})[class] or ""):gmatch("%d+") do
                list[#list + 1] = tonumber(v)
            end
            healthByLevel[class] = list
        end
        return list[level]
    end
    -- A value's base as rows (baseRow): an attribute's split by the original table, below; the health's and the
    -- mana's by their tables, the class's at level 1 and what the levels since have given, no race's (theirs is a
    -- class's alone: a race gives its stamina and its intellect, whose own cards split them; Ikar 2026-11-24: "why mana
    -- and health are not broken by race, class and profession like the rest"), what the game's figure leaves of them
    -- returned second (« Autres », a source not named). No split worked backwards (Ikar 2026-11-23, of « Niveau 26
    -- (49 - 23 - 1) »: "Were does 49-23-1 come from ? and if you just backwardly calculate, then this is a useless
    -- information", "same for every single stat", "Nobody give a shit about the remainder, what, each, level, give.
    -- Period."): the game gives the whole alone. A base that is what the game's figure leaves (`left`: the
    -- health's, a chance's) wears the question mark, the foot saying what the game gives and what the card works out.
    function baseRows(spec, points, percent, left)
        local className, classFile = UnitClass("player")
        local level = ns.Plain(UnitLevel("player"))
        -- an attribute's split by the original table (Stats.BaseSplit): the race's, the class's at level 1, the levels'
        -- since; what the game's base isn't the table's, « Forever », Forever's own curve (Ikar 2026-11-23: "why now
        -- that you have the table can't you split to race, class and level ?")
        local split = spec.stat and Stats.BaseSplit and Stats.BaseSplit(spec.stat)
        local raceName = UnitRace("player")
        if split and className and raceName then
            local rows = { baseRow(spec, split.race, false, raceName) }
            rows[1].tip = { lines = { string.format(split.read and L.STAT_RACE_READ_TIP or L.STAT_RACE_TIP, raceName) } }
            if split.class ~= 0 then
                rows[#rows + 1] = baseRow(spec, split.class, false, className)
                rows[#rows].tip = { lines = { L.STAT_CLASS_TIP } }
            end
            if split.levels ~= 0 then
                rows[#rows + 1] = baseRow(spec, split.levels, false,
                    string.format(G("UNIT_LEVEL_TEMPLATE", "Level %d"), split.level))
                rows[#rows].tip = { lines = { string.format(L.STAT_LEVELS_TIP, split.level) } }
            end
            if points ~= split.total then
                -- (a measure, the game's base against the table's: not what the card can't account for, so never
                -- « Erreur de l'add-on » below 0; Ikar's report of 2026-11-23, agility's and intellect's -1 so named). No
                -- tooltip: the one saying what the original table gives at that level went (Ikar 2026-11-23: "the
                -- level 26 +1 original table is bullshit information, remove that")
                rows[#rows + 1] = baseRow(spec, points - split.total, false, L.STAT_FOREVER)
                rows[#rows].measured = true
            end
            return rows, 0
        end
        local byLevel = type(level) == "number"
            and (spec.mana and spec.mana() and baseMana or spec.healthTable and baseHealth) or nil
        local now, first = byLevel and byLevel(classFile, level), byLevel and byLevel(classFile, 1)
        if now and first and className then
            local health = byLevel == baseHealth
            local rows = { baseRow(spec, first, false, className) }
            rows[1].tip = { lines = { health and L.STAT_HEALTH_CLASS_TIP or L.STAT_MANA_CLASS_TIP } }
            if now ~= first then
                rows[2] = baseRow(spec, now - first, false, string.format(G("UNIT_LEVEL_TEMPLATE", "Level %d"), level))
                rows[2].tip = { lines = { string.format(health and L.STAT_LEVELS_TIP or L.STAT_MANA_LEVELS_TIP, level) } }
            end
            return rows, points - now
        end
        local row = baseRow(spec, points, percent)
        if left then
            local why = string.format(L.STAT_WHY_LEFT, row.name)
            row.asks, row.tip = why, { lines = { why } }
        end
        return { row }, 0
    end
end

local SOURCES = {
    -- (133 a share of the whole, the original server's TOTAL_PCT: the tauren's Endurance, a battle standard; the review
    -- of 2026-11-21, it had been a share not worked out, and every tauren's health had lost its base)
    HEALTH = { gear = { "ITEM_MOD_HEALTH_SHORT" }, flat = { [34] = true, [230] = true, [250] = true },
        share = { [133] = true } },
    -- (178 a share of its most, its misc the power's kind too: the gnome's Expansive Mind; the review of 2026-11-21)
    POWER = { gear = powerGear, flat = { [35] = true }, share = { [178] = true }, misc = shownPower },
    -- 174 and 175 a share of an attribute (its misc), the priest's Spiritual Guidance; 317 a share of the whole, the
    -- orc's Blood Fury (the full review of 2026-11-20: both had been left to « Autres »)
    SPELLPOWER = { gear = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" }, flat = { [13] = true },
        ofStat = { [174] = true }, share = { [317] = true }, schools = true },
    SPELLHEALING = { gear = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
        flat = { [135] = true }, ofStat = { [175] = true }, share = { [317] = true } },
    -- (123 on a magic school: on the armour, the armour penetration's)
    SPELLPENETRATION = { gear = { "ITEM_MOD_SPELL_PENETRATION_SHORT" }, flat = { [123] = true }, negate = true,
        schools = true, misc = function(misc) return floor(misc / 2) % 64 ~= 0 end },
    -- an aura's kind names the attacks it changes: 54 and 52 the weapons', 55 and 57 the spells', 290 both; the
    -- haste's 319 melee, 140 ranged, 192 and 342 both, 65 and 216 the spells', 193 all three; 9 melee (Juju Flurry),
    -- 557 ranged (the quivers' « Hâte »), the review of 2026-11-21
    -- (`schoolKinds`: the spells' kinds whose misc names their schools: one on some alone named with them, and nothing
    -- said left beside it, the game's figure being one school's; the review of 2026-11-23, a few holy ones had counted
    -- as all six)
    HITCHANCE = { gear = { "ITEM_MOD_HIT_RATING_SHORT" },
        rating = function(channel) return ratingBy(CR_HIT_MELEE, channel) end,
        flat = { [54] = "mr", [55] = "s" }, percent = true, channel = function() return (best(hitBy())) end,
        schoolKinds = { [55] = true } },
    CRITCHANCE = { gear = { "ITEM_MOD_CRIT_RATING_SHORT" },
        rating = function(channel) return ratingBy(CR_CRIT_MELEE, channel) end,
        flat = { [52] = "mr", [57] = "s", [290] = "mrs" }, percent = true,
        channel = function() return (best(critBy())) end, schoolKinds = { [57] = true } },
    HASTE = { gear = { "ITEM_MOD_HASTE_RATING_SHORT" },
        rating = function(channel) return ratingBy(CR_HASTE_MELEE or 18, channel) end,
        flat = { [319] = "m", [140] = "r", [192] = "mr", [342] = "mr", [65] = "s", [216] = "s", [193] = "mrs",
            [9] = "m", [557] = "r" },
        percent = true, channel = function() return (best(hasteBy())) end },
    DODGE = { gear = { "ITEM_MOD_DODGE_RATING_SHORT" }, rating = function() return CR_DODGE end, flat = { [49] = true },
        percent = true },
    PARRY = { gear = { "ITEM_MOD_PARRY_RATING_SHORT" }, rating = function() return CR_PARRY end, flat = { [47] = true },
        percent = true },
    BLOCK = { gear = { "ITEM_MOD_BLOCK_RATING_SHORT" }, rating = function() return CR_BLOCK end, flat = { [51] = true },
        percent = true },
    -- 110 a share of the regeneration, named, the game's numbers not telling what it comes to; 134 the share of it kept
    -- while casting (`keep`), of the figure in casting alone, its table's other column (Stats.RegenTable; the review of
    -- 2026-11-23: Méditation's had read as a raise of the regeneration out of casting, which it doesn't change, and no
    -- « Autres » had been worked out beside it; Innervate's two had read « +500 % »)
    REGEN = { gear = { "ITEM_MOD_MANA_REGENERATION_SHORT" }, flat = { [85] = true },
        shareOnly = { [110] = true }, keep = { [134] = true }, when = hasMana },
    -- the health's (Ikar 2026-11-21: "health regen ?"): 161 the health in five seconds, in a fight or not, 88 a share of
    -- what the spirit gives out of one (make_effects.py's review), 116 the share kept in a fight (the troll's
    -- Regeneration), its table's fight column; nothing of the race's, the class's or the level's left in it, the
    -- spirit's part the game's for them
    HEALTH_REGEN = { gear = { "ITEM_MOD_HEALTH_REGEN_SHORT" }, flat = { [161] = true }, shareOnly = { [88] = true },
        keep = { [116] = true }, noBase = true },
    -- the block value's (a card of its own, the review of 2026-11-23): the items' « Augmente de x la valeur de blocage de
    -- votre bouclier », 274 by points, 272 by a share of the whole; the shield's own block and the strength's part what
    -- it stands on (PARTS)
    BLOCKVALUE = { gear = { "ITEM_MOD_BLOCK_VALUE_SHORT" }, flat = { [274] = true }, share = { [272] = true },
        noBase = true },
    -- each kind for how the character moves (speedRole); mounted and swimming the review of 2026-11-20's
    MOVESPEED = { gear = {}, flat = { [31] = true, [129] = true, [171] = true, [32] = true, [130] = true, [172] = true,
        [58] = true, [33] = true }, percent = true, speed = true },
    -- 598 both by a share of an attribute (its misc), the shaman's Mental Dexterity of the intellect (Ikar 2026-11-21:
    -- "dexteriter mental seem not to be shown in attack power"); not of the strength or agility, which the game's own
    -- figure for them may hold (GetAttackPowerForStat, the attributes' part: Cat Form's agility)
    ATTACK_AP = { gear = { "ITEM_MOD_ATTACK_POWER_SHORT" }, flat = { [99] = true }, share = { [166] = true },
        ofStat = { [598] = true }, misc = function(misc, kind) return kind ~= 598 or misc > 1 end,
        levelPart = function() return levelAP(false) end },
    RANGED_ATTACK_AP = { gear = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
        flat = { [124] = true }, share = { [167] = true }, ofStat = { [598] = true },
        misc = function(misc, kind) return kind ~= 598 or misc > 1 and RANGED_CLASS[select(2, UnitClass("player"))] end,
        levelPart = function() return levelAP(true) end },
    -- a skill's auras on defence's skill line alone (Data/Effects.lua keeps every skill's, for the skills' own)
    DEFENSE = { gear = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" }, flat = { [30] = true, [98] = true },
        misc = function(misc) return misc == 95 end },
    -- (83 the base's points, the review of 2026-11-20's; 466 a share of the items' armour, its misc none: two debuffs,
    -- the data keeping it only where a spell has no 142 the same, the review of 2026-11-21)
    -- The original server's sum: the items' own armour by the shares of it (142, 466:
    -- the bear's and moonkin's forms, Toughness), then the agility's and the flat changes, the whole by 101's shares
    -- (`ofItems`; the review of 2026-11-21: all three had been shares not worked out, a bear's armour left unexplained)
    ARMOR = { gear = { "ITEM_MOD_EXTRA_ARMOR_SHORT" }, flat = { [674] = true, [22] = true, [83] = true },
        share = { [101] = true }, baseShare = { [142] = true, [466] = true }, ofItems = true,
        misc = function(misc, kind) return kind == 466 or schools(0)(misc) end },
    -- what gives them in this build (Ikar 2026-11-19: "expertise is 0"; the review of 2026-11-20): the expertise, 240 by
    -- points of a percent (a rogue's Weapon Expertise, a flask), its rating (CR_EXPERTISE, the tier 1 sets' four pieces
    -- of a tank) and the items' (eight); the armour ignored, 123 on the armour (Bonereaver's Edge), the penetration
    -- the armour lowered
    EXPERTISE = { gear = { "ITEM_MOD_EXPERTISE_RATING_SHORT" }, rating = function() return CR_EXPERTISE or 24 end,
        flat = { [240] = true }, percent = true, noBase = true },
    -- (280 the armour ignored by a share, Serrated Blades', Weapon Mastery's: named, whether the game's figure holds it
    -- not known, the design's open question; Ikar 2026-11-26, "fix the gaps")
    ARMORPEN = { gear = {}, flat = { [123] = true }, shareOnly = { [280] = true }, negate = true, noBase = true,
        misc = (function()
            local armour = schools(0)
            return function(misc, kind) return kind == 280 or armour(misc) end
        end)() },
}
-- Values with no base of their own, nothing but their sources: what those leave of them is « Autres », not a base
-- (sourcesOf).
for _, key in ipairs({ "HITCHANCE", "HASTE", "SPELLPOWER", "SPELLHEALING", "SPELLPENETRATION" }) do
    SOURCES[key].noBase = true
end
-- Where the others' base comes from (baseName; the attributes' with them, below): mana the class's at its level,
-- energy and rage the class's alone. The armour's and the regeneration's have none, their sources all named: what's
-- left of them is « Autres » (the resistances' too, below).
for key, of in pairs({ HEALTH = "classLevel", CRITCHANCE = "class", DODGE = "class", PARRY = "class", BLOCK = "class",
    DEFENSE = "skill" }) do
    SOURCES[key].baseOf = of
end
SOURCES.POWER.baseOf = function()
    return manaShown() and "classLevel" or "class"
end
SOURCES.POWER.mana = manaShown
SOURCES.HEALTH.healthTable = true
SOURCES.ARMOR.noBase, SOURCES.REGEN.noBase = true, true
-- What an enemy of the character's level gets against it (Ikar 2026-11-23, of the defence's column: "add the 4"),
-- worked out of the game's own figures: its parts are its sum (PARTS), nothing else changes it.
for _, key in ipairs({ "ARMORCUT", "MISSED", "AVOIDANCE", "CRITTAKEN" }) do
    SOURCES[key] = { gear = {}, flat = {}, noBase = true, percent = true }
end
-- Values whose changes multiply each other, not add up: what their sources leave isn't a figure of anything, and
-- none is said (a curse's -50 % of haste beside a buff's +10 % had left « Autres +55 % »)
SOURCES.HASTE.multiplies, SOURCES.MOVESPEED.multiplies = true, true
-- The healing taken (Ikar 2026-11-24: "add the healing taken"), the effects on the character: 118 by a share of each
-- heal, the shares multiplying each other (the original server's), and 115 by points on each heal. The game gives no
-- figure of either: the value is their own (Stats.HealTaken), nothing left beside them.
SOURCES.HEALTAKEN = { gear = {}, flat = { [118] = true }, percent = true, noBase = true, multiplies = true }
-- the healing done by a share, 136: the effects on the character (Power Infusion) and the healing talents that take in
-- all their class's main heals, which hud/tools/make_effects.py writes so (Ikar 2026-11-24: "heal power should count
-- only when it affect all spels. Or the main spells at least")
SOURCES.HEALDONE = { gear = {}, flat = { [136] = true }, percent = true, noBase = true, multiplies = true }
SOURCES.HEALTAKEN_FLAT = { gear = {}, flat = { [115] = true }, noBase = true }

-- How fast the character goes, as the sheet's (MovementSpeed_OnUpdate): running, or swimming or flying while it does,
-- a fall out of the water still swimming; a share of the base speed (BASE_MOVEMENT_SPEED, 7 yards a second).
local BASE_SPEED = 7
local wasSwimming = false
local function movement()
    local _, run, flight, swim = ns.Plain(GetUnitSpeed("player"))
    if run == nil then
        return nil
    end
    local swimming = IsSwimming("player") == true
    local speed = run
    if swimming then
        speed = swim
    elseif IsFlying("player") then
        speed = flight
    end
    if IsFalling("player") then
        if wasSwimming then
            speed, swimming = swim, true
        end
    else
        wasSwimming = swimming
    end
    -- (fifth, how it moves, for the speed's sources: speedRole)
    local mode = swimming and "swim" or (ns.Call(IsMounted) == true and "mounted") or "run"
    return (speed or 0) / BASE_SPEED, run / BASE_SPEED, (flight or 0) / BASE_SPEED, (swim or 0) / BASE_SPEED, mode
end

local function lowestSpell(read)
    local low
    for _, school in ipairs(SCHOOLS) do
        local v = read(school)
        if type(v) == "number" then
            low = low and min(low, v) or v
        end
    end
    return low
end

-- A weapon's damage as the sheet writes it (PaperDollFrame_GetDamage): "41 - 64", "120-180" from 100 up, green or red
-- when buffs change it (its bonuses `pos` and `neg`, its multiplier `pct`); its changes as the sheet's tooltip, after
-- the base damage: " (37 - 58 +4 -1 x110 %)".
local function damage(low, high, pos, neg, pct)
    if type(low) ~= "number" or type(high) ~= "number" or high <= 0 then
        return nil
    end
    local lo, hi = max(floor(low), 1), max(ceil(high), 1)
    local text = Format.Number(lo) .. ((lo < 100 and hi < 100) and " - " or "-") .. Format.Number(hi)
    pos, neg, pct = pos or 0, neg or 0, pct or 1
    if pct ~= 0 then
        local baseLow, baseHigh = low / pct - pos - neg, high / pct - pos - neg
        local base = (baseLow + baseHigh) * 0.5
        local bonus = (base + pos + neg) * pct - base
        if bonus >= 0.1 or bonus <= -0.1 then
            local parts = " (" .. Format.Number(max(floor(baseLow), 1)) .. " - " .. Format.Number(max(ceil(baseHigh), 1))
                .. (pos > 0 and Infos.Color(" +" .. number(pos), Infos.GOOD) or "")
                .. (neg < 0 and Infos.Color(" " .. number(neg), Infos.BAD) or "")
            if pct ~= 1 then
                parts = parts .. Infos.Color(" x" .. Format.Percent(pct), pct > 1 and Infos.GOOD or Infos.BAD)
            end
            return Infos.Color(text, bonus > 0 and Infos.GOOD or Infos.BAD), parts .. ")"
        end
    end
    return text
end

-- Each: key, its name, its value as text (nil: hidden from addons now, or none), and lines for its tooltip.
local LIST = {
    { key = "HEALTH", name = function() return G("HEALTH", "Health") end, value = function()
        local v = ns.Plain(UnitHealthMax("player"))
        return v and number(v)
    end },
    { key = "POWER", name = function()
        local _, token = UnitPowerType("player")
        return type(token) == "string" and _G[token] or G("MANA", "Mana")
    end, value = function()
        local v = ns.Plain(UnitPowerMax("player"))
        return v and number(v)
    end },
    { key = "STRENGTH", stat = 1 }, { key = "AGILITY", stat = 2 }, { key = "STAMINA", stat = 3 },
    { key = "INTELLECT", stat = 4 }, { key = "SPIRIT", stat = 5 },
    { key = "MAINHAND_DAMAGE", name = function() return G("INVTYPE_WEAPONMAINHAND", "Main Hand") end, value = function()
        local low, high, _, _, pos, neg, pct = ns.Plain(UnitDamage("player"))
        return damage(low, high, pos, neg, pct)
    end },
    { key = "OFFHAND_DAMAGE", name = function() return G("INVTYPE_WEAPONOFFHAND", "Off Hand") end, value = function()
        local main, _, low, high, pos, neg, pct = ns.Plain(UnitDamage("player"))
        if main == nil then
            return nil
        end
        local text, parts = damage(low, high, pos, neg, pct)
        return text or ns.G("NONE", "None"), parts
    end },
    { key = "RANGED_DAMAGE", name = function() return G("INVTYPE_RANGED", "Ranged") end, value = function()
        -- as the sheet: its multiplier only (its GetRangedDamage leaves the bonuses out)
        local speed, low, high, _, _, pct = ns.Plain(UnitRangedDamage("player"))
        if speed == nil then
            return nil
        elseif speed <= 0 then
            return ns.G("NONE", "None")
        end
        local text, parts = damage(low, high, 0, 0, pct)
        return text or ns.G("NONE", "None"), parts
    end },
    { key = "ATTACK_AP", name = function() return G("STAT_ATTACK_POWER", "Attack Power") end, value = function()
        return attackPower(ns.Plain(UnitAttackPower("player")))
    end, numbers = function()
        return attackNumbers(ns.Plain(UnitAttackPower("player")))
    end },
    { key = "RANGED_ATTACK_AP", name = function() return G("RANGED_ATTACK_POWER", "Ranged Attack Power") end, value = function()
        return attackPower(ns.Plain(UnitRangedAttackPower("player")))
    end, numbers = function()
        return attackNumbers(ns.Plain(UnitRangedAttackPower("player")))
    end },
    -- the sheet's: the best of melee, off hand, ranged and spells (PaperDollFrame_SetHitChance)
    { key = "HITCHANCE", name = function() return G("STAT_HIT_CHANCE", "Hit") end, value = function()
        local _, v = best(hitBy())
        return v and percent(v)
    end },
    -- the sheet's: the best of melee, ranged and spells (PaperDollFrame_SetCritChance)
    { key = "CRITCHANCE", name = function() return G("STAT_CRITICAL_STRIKE", "Critical Strike") end, value = function()
        local _, v = best(critBy())
        return v and percent(v)
    end },
    -- the sheet's: the best of melee, ranged with its ammunition's, and spells (PaperDollFrame_SetHaste)
    { key = "HASTE", name = function() return G("STAT_HASTE", "Haste") end, value = function()
        local _, v = best(hasteBy())
        return v and percent(v)
    end },
    -- the main hand's, the off hand's after it when there's one (PaperDollFrame_SetExpertise)
    { key = "EXPERTISE", name = function() return G("STAT_EXPERTISE", "Expertise") end, value = function()
        local main, off = ns.Plain(GetExpertise())
        if type(main) ~= "number" then
            return nil
        end
        local _, offSpeed = ns.Plain(UnitAttackSpeed("player"))
        return percent(main) .. ((offSpeed and type(off) == "number") and (" / " .. percent(off)) or "")
    end },
    { key = "ARMORPEN", name = function() return G("STAT_ARMOR_PENETRATION", "Armor Penetration") end, value = function()
        local v = ns.Plain(GetArmorPenetration())
        return v and string.format("%d", v)
    end },
    { key = "SPELLHEALING", name = function() return G("STAT_SPELLHEALING", "Bonus Healing") end, value = function()
        local v = ns.Plain(GetSpellBonusHealing())
        return v and number(v)
    end },
    { key = "SPELLPENETRATION", name = function() return G("STAT_SPELL_PENETRATION", "Spell Penetration") end, value = function()
        local v = ns.Plain(GetSpellPenetration())
        return v and number(v)
    end },
    -- regeneration: mana in five seconds, as the sheet's, while casting then not, with what the game's figures don't
    -- count (Ikar 2026-11-23: "A, a table, and everything per 5s"; a second's with the option, "Add an option to show
    -- mana as per second in the settigns menu": Stats.RegenLine); energy, rage or focus a second, the sheet's names for
    -- energy and focus
    { key = "REGEN", name = function()
        if (ns.Plain(UnitPowerMax("player", Enum.PowerType.Mana)) or 0) > 0 then
            return G("MANA_REGEN", "Mana Regen")
        end
        local _, token = UnitPowerType("player")
        if token == "ENERGY" then
            return G("STAT_ENERGY_REGEN", "Energy Regen")
        elseif token == "FOCUS" then
            return G("STAT_FOCUS_REGEN", "Focus Regen")
        end
        return L.POWER_REGEN
    end, value = function()
        if (ns.Plain(UnitPowerMax("player", Enum.PowerType.Mana)) or 0) > 0 then
            return Stats.RegenLine("REGEN")
        end
        local regen = ns.Plain(GetPowerRegen())
        return regen and Format.Decimal(regen, 1)
    end, tip = function()
        if not hasMana() then
            return L.POWER_REGEN_TIP
        end
        return Stats.PerSecond() and L.REGEN_TIP_SECOND or L.REGEN_TIP
    end },
    -- the health regained in five seconds in a fight, and standing out of one in brackets, as the mana's
    -- (GetHealthRegen, a second's: the sheet's spirit tooltip has it « x 5 »), what the game's figures don't count with
    -- it (Stats.RegenLine)
    { key = "HEALTH_REGEN", name = function() return G("ITEM_MOD_HEALTH_REGENERATION_SHORT", "Health Regeneration") end,
        value = function()
            return Stats.RegenLine("HEALTH_REGEN")
        end, tip = function() return L.HEALTH_REGEN_TIP end },
    -- the sheet's: its value out of the level's most, five a level (PaperDollFrame_SetDefense)
    { key = "DEFENSE", name = function() return G("DEFENSE", "Defense") end, value = function()
        local base, mod = ns.Plain(UnitDefenseSkill("player"))
        if base == nil then
            return nil
        end
        mod = mod or 0
        return buffed(max(0, base + mod), mod, mod) .. " / " .. number((UnitLevel("player") or 0) * 5),
            changes(base, max(mod, 0), min(mod, 0))
    end, numbers = function()
        local base, mod = ns.Plain(UnitDefenseSkill("player"))
        if base == nil then
            return nil
        end
        mod = mod or 0
        return base, max(0, base + mod), max(mod, 0), min(mod, 0)
    end },
    { key = "DODGE", name = function() return G("STAT_DODGE", "Dodge") end, value = function()
        local v = ns.Plain(GetDodgeChance())
        return v and percent(v)
    end },
    -- whole, as the sheet's (PaperDollFrame_SetBlock)
    { key = "BLOCK", name = function() return G("STAT_BLOCK", "Block") end, value = function()
        local v = ns.Plain(GetBlockChance())
        return v and Format.Percent(v / 100)
    end },
    -- what a block takes off a blow, the sheet's block tooltip's (GetShieldBlock), a value of its own (Ikar 2026-11-23:
    -- "the block value")
    { key = "BLOCKVALUE", name = function() return G("ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value") end, value = function()
        local v = ns.Plain(GetShieldBlock())
        return v and number(v)
    end },
    { key = "PARRY", name = function() return G("STAT_PARRY", "Parry") end, value = function()
        local v = ns.Plain(GetParryChance())
        return v and percent(v)
    end },
    -- green when raised, never red, as the sheet's (PaperDollFrame_SetArmor). Its sources from its whole (`total`),
    -- not from the game's split: Forever's « bonus » is the items' and the agility's armour, its base the buffs' (the
    -- probe: 10 and 798; Ikar's screenshot of 2026-11-19: 202 and 821, the items named twice, « Base -619 » and
    -- « Autres +619 »)
    { key = "ARMOR", name = function() return G("STAT_ARMOR", "Armor") end, value = function()
        local _, effective, _, bonus = ns.Plain(UnitArmor("player"))
        if effective == nil then
            return nil
        end
        return raised(effective, bonus), changedBy(effective, bonus)
    end },
    -- against an enemy of the character's level: what the armour takes off its blows (the sheet's armour tooltip's,
    -- C_PaperDollInfo.GetArmorEffectiveness), its chance to miss, all it doesn't land (missed, dodged, parried,
    -- blocked) and its chance of a critical strike (Stats.Taken)
    { key = "ARMORCUT", name = function() return L.STAT_ARMORCUT end, value = function()
        local v = Stats.ArmorCut()
        return v and percent(v)
    end, total = function() return (Stats.ArmorCut()) end },
    { key = "MISSED", name = function() return L.STAT_MISSED end, value = function()
        local t = Stats.Taken()
        return t and percent(t.miss)
    end, total = function()
        local t = Stats.Taken()
        return t and t.miss
    end },
    { key = "AVOIDANCE", name = function() return L.STAT_AVOIDANCE end, value = function()
        local t = Stats.Taken()
        return t and percent(t.avoided)
    end, total = function()
        local t = Stats.Taken()
        return t and t.avoided
    end },
    { key = "CRITTAKEN", name = function() return L.STAT_CRITTAKEN end, value = function()
        local t = Stats.Taken()
        return t and percent(t.crit)
    end, total = function()
        local t = Stats.Taken()
        return t and t.crit
    end },
    -- the healing done and taken by a share of each heal, and taken by points on each (Stats.HealShare): raised green,
    -- lowered red
    { key = "HEALDONE", name = function() return L.STAT_HEALDONE end, value = function()
        return Stats.ShareText(Stats.HealShare("HEALDONE"))
    end },
    { key = "HEALTAKEN", name = function() return L.STAT_HEALTAKEN end, value = function()
        return Stats.ShareText(Stats.HealShare("HEALTAKEN"))
    end },
    { key = "HEALTAKEN_FLAT", name = function() return L.STAT_HEALTAKEN_FLAT end, value = function()
        local v = Stats.HealShare("HEALTAKEN_FLAT")
        if not v then
            return nil
        end
        return v > 0 and Infos.Color("+" .. number(v), Infos.GOOD) or v < 0 and Infos.Color(number(v), Infos.BAD)
            or number(v)
    end },
}
for _, s in ipairs(LIST) do
    s.sources = SOURCES[s.key]
end

-- The sheet's movement speed, after the power (its general kind: HEALTH, POWER, MOVESPEED); its tooltip running and
-- swimming as the sheet's (flying it shows not on Forever: PaperDollFrame_ShowFlightSpeed).
local MOVE = { key = "MOVESPEED", name = function() return G("STAT_MOVEMENT_SPEED", "Movement Speed") end,
    sources = SOURCES.MOVESPEED,
    value = function()
        local speed = movement()
        return speed and Format.Percent(speed)
    end,
    more = function(tooltip)
        local _, run, _, swim = movement()
        if run then
            Infos.Text(tooltip, string.format(G("STAT_MOVEMENT_GROUND_TOOLTIP", "Run Speed: %d%%"), floor(run * 100 + 0.5)))
            Infos.Text(tooltip, string.format(G("STAT_MOVEMENT_SWIM_TOOLTIP", "Swim Speed: %d%%"), floor(swim * 100 + 0.5)))
        end
    end }
table.insert(LIST, 3, MOVE)

-- The sheet's resistances, last (CharacterFrame's RESISTANCE_STAT_ENTRIES: its kind « Résistances », in its order),
-- green when raised; each with its school's icon as its spell power has it, the one set with holy in it (Ikar
-- 2026-11-23: "why spell damage and resistance have different icons ?": the sheet's own atlases had been theirs).
for _, r in ipairs({
    { "ARCANE", "Arcane", 7, 6 }, { "FIRE", "Fire", 3, 2 }, { "FROST", "Frost", 5, 4 }, { "NATURE", "Nature", 4, 3 },
    { "SHADOW", "Shadow", 6, 5 },
}) do
    local class = Enum.Damageclass and Enum.Damageclass[r[2]] or r[4]
    LIST[#LIST + 1] = { key = r[1], school = class, icon = "Interface\\PaperDollInfoFrame\\SpellSchoolIcon" .. r[3],
        name = function() return G("DAMAGE_SCHOOL" .. r[3], r[2]) end,
        value = function()
            local _, _, effective, bonus = ns.Plain(UnitResistance("player", class))
            if effective == nil then
                return nil
            end
            return raised(effective, bonus), changedBy(effective, bonus)
        end,
        -- its sources from its whole, as the armour's; an item's resistance to every school too (Forever's stat 124)
        total = function()
            local _, _, effective = ns.Plain(UnitResistance("player", class))
            return effective
        end,
        sources = { gear = { "RESISTANCE" .. class .. "_NAME", "ITEM_MOD_SPELL_RESISTANCE_ALL_SCHOOLS_SHORT" },
            flat = { [22] = true, [83] = true },
            share = { [101] = true }, misc = schools(class), noBase = true } }
end

-- Each school's spell power, as the resistances (Ikar 2026-11-23: "spell power, let's have it per school, like
-- resistances"), in place of the sheet's one value, the least of them: in the resistances' order, holy, which has
-- none, last (Ikar, the same day: "and order"), each with its icon in the sheet's tooltip of it
-- (CharacterSpellBonusDamage_OnEnter's SpellSchoolIcon), its card titled with the sheet's word; its
-- sources those of its school (13's misc a mask of them), an item's spell power or spell damage and a share of an
-- attribute or of the whole all six's, so that what they leave is « Autres » (a school's alone had named its sources
-- with their schools and left nothing said); an item's damage of that school alone too, Forever's « Dégâts de feu »
-- (its items' stats 84 to 89: the Inferno Robe's, the Icicle Rod's; Ikar 2026-11-26, "fix the gaps").
for _, r in ipairs({ { "ARCANE", 7, "Arcane" }, { "FIRE", 3, "Fire" }, { "FROST", 5, "Frost" },
    { "NATURE", 4, "Nature" }, { "SHADOW", 6, "Shadow" }, { "HOLY", 2, "Holy" } }) do
    local school, inSchool = r[2], schools(r[2] - 1)
    local function name()
        return G("DAMAGE_SCHOOL" .. school, r[3])
    end
    LIST[#LIST + 1] = { key = "SPELLPOWER_" .. r[1], spellSchool = school,
        icon = "Interface\\PaperDollInfoFrame\\SpellSchoolIcon" .. school, name = name,
        title = function() return G("STAT_SPELLPOWER", "Spell Power") .. " (" .. name() .. ")" end,
        value = function()
            local v = ns.Plain(GetSpellBonusDamage(school))
            return v and number(v)
        end,
        total = function() return ns.Plain(GetSpellBonusDamage(school)) end,
        sources = { gear = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
            "ITEM_MOD_" .. r[3]:upper() .. "_DAMAGE_DONE_SHORT" }, flat = { [13] = true }, ofStat = { [174] = true },
            share = { [317] = true }, noBase = true,
            misc = function(misc, kind) return kind ~= 13 or inSchool(misc) end } }
end

-- The base attributes: the game's own names (SPELL_STAT1_NAME...), green or red when buffed; the sheet's base, its
-- value less its changes (PaperDollFrame_SetStatTooltip).
for _, s in ipairs(LIST) do
    if s.stat then
        s.name = function()
            return G("SPELL_STAT" .. s.stat .. "_NAME", s.key)
        end
        s.numbers = function()
            local current, effective, pos, neg = ns.Plain(UnitStat("player", s.stat))
            if effective == nil then
                return nil
            end
            return current - pos - neg, effective, pos, neg
        end
        s.value = function()
            local base, effective, pos, neg = s.numbers()
            if base == nil then
                return nil
            end
            return buffed(effective, pos, neg), changes(base, pos, neg)
        end
        -- (`scaledBase`: the game's base may hold its shares' part of it, sourcesOf)
        s.sources = { gear = { "ITEM_MOD_" .. ATTRIBUTE_KEYS[s.stat] .. "_SHORT" }, flat = { [29] = true },
            share = { [137] = true }, baseShare = { [80] = true }, scaledBase = true, baseOf = "all", stat = s.stat,
            misc = function(misc, kind)
                -- 137's a mask of the attributes (make_effects.py: Heart of the Wild's intellect had gone to strength)
                if kind == 137 then
                    return floor(misc / 2 ^ (s.stat - 1)) % 2 == 1
                end
                return misc == -1 or misc == s.stat - 1
            end }
    end
end

-- A value as a number, for one the game gives no base of (no `numbers`): what its named sources leave of it is its
-- base and what nothing names (sourcesOf), and nothing gives it at 0 (cardSources). The kind of attack shown's, for
-- the best of three.
local TOTALS = {
    HEALTH = function() return ns.Plain(UnitHealthMax("player")) end,
    POWER = function() return ns.Plain(UnitPowerMax("player")) end,
    MOVESPEED = function()
        local speed = movement()
        return speed and speed * 100
    end,
    HITCHANCE = function() return select(2, best(hitBy())) end,
    CRITCHANCE = function() return select(2, best(critBy())) end,
    HASTE = function() return select(2, best(hasteBy())) end,
    EXPERTISE = function() return (ns.Plain(GetExpertise())) end,
    ARMORPEN = function() return ns.Plain(GetArmorPenetration()) end,
    SPELLHEALING = function() return ns.Plain(GetSpellBonusHealing()) end,
    SPELLPENETRATION = function() return ns.Plain(GetSpellPenetration()) end,
    -- the regenerations out of a fight (standing, out of casting), cut to a whole as the sheet writes them (its
    -- « %d », the spirit's tooltip's): its spirit's part cut the same (PARTS), the two agree to the point, nothing of
    -- the cut left as « Autres » (the review of 2026-11-23: the spirit's card had said 12 of the health and the
    -- regeneration's 13, one cut and the other rounded)
    HEALTH_REGEN = function()
        local out = ns.Plain(GetHealthRegen())
        return out and floor(out * 5 + 1e-6)
    end,
    REGEN = function()
        local out = hasMana() and ns.Plain(GetManaRegen())
        return out and floor(out * 5 + 1e-6) or nil
    end,
    BLOCKVALUE = function() return ns.Plain(GetShieldBlock()) end,
    DODGE = function() return ns.Plain(GetDodgeChance()) end,
    PARRY = function() return ns.Plain(GetParryChance()) end,
    BLOCK = function() return ns.Plain(GetBlockChance()) end,
    ARMOR = function()
        local _, effective = ns.Plain(UnitArmor("player"))
        return effective
    end,
}
for _, s in ipairs(LIST) do
    s.total = s.total or TOTALS[s.key]
end

-- The folder's order: the sheet's categories, each under its title, the sheet's own (Ikar 2026-11-20, the sketch of
-- the attributes: "C'est très bien"); a column each for what the character is, how it attacks, how it stands
-- (UI/Hub/Separators.lua's titles and lines, which the player can make as these are).
local function title(key, fallback, line)
    return ns.Seeds.Title(function()
        return G(key, fallback)
    end, line)
end
local ORDER = {
    title("STAT_CATEGORY_GENERAL", "General"), "HEALTH", "POWER", "MOVESPEED",
    title("STAT_CATEGORY_PRIMARY_ATTRIBUTES", "Primary Attributes"),
    "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT",
    title("STAT_CATEGORY_WEAPONS", "Weapons", true),
    "MAINHAND_DAMAGE", "OFFHAND_DAMAGE", "RANGED_DAMAGE", "ATTACK_AP", "RANGED_ATTACK_AP",
    title("STAT_CATEGORY_MODIFIERS", "Modifiers"),
    "HITCHANCE", "CRITCHANCE", "HASTE", "EXPERTISE", "ARMORPEN", "SPELLPENETRATION",
    "HEALTH_REGEN", "REGEN",
    -- the defence a column of its own, with what an enemy of the character's level gets against it (Ikar 2026-11-23:
    -- "add the 4"); each school's spell power under the sheet's word for it (the review of that day), the resistances
    -- under it, the same schools in the same order, the last column (Ikar: "degat des sort et resistance in one
    -- column", "spell and resistance last column")
    title("STAT_CATEGORY_DEFENSE", "Defense", true), "DEFENSE", "DODGE", "BLOCK", "BLOCKVALUE", "PARRY", "ARMOR",
    "ARMORCUT", "MISSED", "AVOIDANCE", "CRITTAKEN",
    -- the healing under it, the sheet's spell healing out of its modifiers, under the game's own word (the damage
    -- meter's) (Ikar 2026-11-24: "Healing power is missing, add a category bellow defense for healing related stats")
    title("DAMAGE_METER_CATEGORY_HEALING", "Healing"), "SPELLHEALING", "HEALDONE", "HEALTAKEN", "HEALTAKEN_FLAT",
    title("STAT_SPELLPOWER", "Spell Power", true), "SPELLPOWER_ARCANE", "SPELLPOWER_FIRE", "SPELLPOWER_FROST",
    "SPELLPOWER_NATURE", "SPELLPOWER_SHADOW", "SPELLPOWER_HOLY",
    title("STAT_CATEGORY_RESISTANCE", "Resistance"), "ARCANE", "FIRE", "FROST", "NATURE", "SHADOW",
}
local function named(keys)
    local list = {}
    for _, key in ipairs(keys) do
        list[#list + 1] = type(key) == "table" and key or PREFIX .. key
    end
    return list
end
-- (the folder is locked, UI/Hub/Seeds.lua: made from this list at each login)
ns.Seeds.Contents.stats = named(ORDER)

-- What failed once isn't read again this session: an error each update would come back with every change.
local broken = {}

-- Its text, and what its tooltip adds after it (its changes).
local function read(s)
    if broken[s.key] then
        return nil
    end
    local ok, text, parts = pcall(s.value)
    if not ok then
        broken[s.key] = true
        ns.SafeCall(error, text)
        return nil
    end
    return text, parts
end

-- ---------- Where a value's changes come from ----------

-- The gear's slots, the head to the tabard (Blizzard_FrameXMLBase's INVSLOT_HEAD, INVSLOT_TABARD; its
-- INVSLOT_LAST_EQUIPPED another game mode's own).
local FIRST_SLOT, LAST_SLOT = 1, 19
local FILTERS = { "HELPFUL", "HARMFUL" }

-- What would be: the card kept open tries what is under the pointer (wouldBe, far below) by reading a value's sources
-- a second time with this set, through which the gear's links, the attributes and the talents are read. Nil but
-- during that second reading.
local WOULD
-- What is tried on the values, in one table (this file's main chunk holds as many locals as Lua lets one, its loops'
-- among them): `what`, what is under the pointer now, tried on the cards kept open and on the lines that show (try,
-- far below); `leaned`, the attributes a value's readings ask for while what it would be is worked out (wouldBe): what
-- it stands on, whose change that can't be said is its own question, and no other value's (nil but then). The lines'
-- own far below.
local Tried = {}
-- An attribute's value, the one tried's change on it while what would be is read.
local function attribute(i)
    if Tried.leaned then
        Tried.leaned[i] = true
    end
    local _, effective = ns.Plain(UnitStat("player", i))
    return effective and effective + (WOULD and WOULD.attributes and WOULD.attributes[i] or 0)
end
local function wornLink(slot)
    local link = WOULD and WOULD.links and WOULD.links[slot]
    if link ~= nil then
        return link or nil
    end
    return GetInventoryItemLink("player", slot)
end

-- A source's name after its icon, so that what it is shows at a glance: an item's, a buff's, a talent's, a passive
-- spell's, a consumable's (a name alone read as anything: Ikar 2026-11-19, of his mace « Écrasante de défense »'s
-- +3 defence, "Unclear"; of a scroll's buff « Armure », the same).
local function iconed(icon, name)
    return (type(icon) == "number" or type(icon) == "string") and ("|T" .. icon .. ":14:14|t " .. name) or name
end
local function spellIcon(spell)
    return C_Spell and C_Spell.GetSpellTexture and ns.Plain(ns.Call(C_Spell.GetSpellTexture, spell))
end

-- An item's name in its quality's colour, as the game's tooltips write it, its icon before it.
local function itemName(link, slot)
    local name = link:match("%[(.-)%]") or link
    local rank = GetInventoryItemQuality("player", slot)
    if WOULD and WOULD.links and WOULD.links[slot] then
        -- one tried in that slot: its own quality (C_Item.GetItemInfo's third)
        rank = select(4, pcall(C_Item.GetItemInfo, link))
    end
    local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[type(rank) == "number" and rank or -1]
    name = quality and quality.hex and (quality.hex .. name .. "|r") or name
    local icon = C_Item and C_Item.GetItemInfoInstant and select(6, pcall(C_Item.GetItemInfoInstant, link))
    return iconed(icon, name)
end

-- An effect's points as the game's data has them (Data/Effects.lua): a figure, or for one that grows with its
-- caster's level "<base>@<a level's>,<spell's level>,<lowest>,<highest>", worked out as the server does at the
-- character's level, held between the lowest and the highest (none: 0), less the spell's own, the product cut to a
-- whole (make_effects.py's fixed; Ikar 2026-11-19: "the description should give an answer": a druid's forms, a
-- shaman's Rockbiter, had worn the question mark); nil for none.
local function fixedPoints(fixed)
    local n = tonumber(fixed)
    if n or type(fixed) ~= "string" then
        return n
    end
    local base, per, spellLevel, lowest, highest = fixed:match("^(%-?[%d.]+)@(%-?[%d.]+),(%d+),(%d+),(%d+)$")
    if not base then
        return nil
    end
    local lvl = UnitLevel("player") or 0
    highest, lowest = tonumber(highest), tonumber(lowest)
    if highest > 0 and lvl > highest then
        lvl = highest
    elseif lvl < lowest then
        lvl = lowest
    end
    local add = (lvl - tonumber(spellLevel)) * tonumber(per)
    return tonumber(base) + (add >= 0 and floor(add) or ceil(add))
end
Stats.FixedPoints = fixedPoints

-- An aura's value for one of its spell's effects: AuraData's points, numbered by the spell's effects or by its auras
-- alone, which their count tells; when it gives none (or 0), the spell's own as the game's data has them, where they
-- are whoever casts it (an elixir's, a scroll's); nil else.
local function pointOf(aura, count, auras, index, place, fixed)
    local points = ns.Plain(aura.points)
    local v
    if type(points) == "table" then
        if #points >= count then
            v = points[index + 1]
        elseif #points == auras then
            v = points[place + 1]
        end
        v = ns.Plain(v)
    end
    if type(v) ~= "number" or v == 0 then
        v = fixedPoints(fixed)
    end
    return v
end

-- The share of a percent the sheet makes of a point of a rating (GetCombatRatingBonus over GetCombatRating). For a
-- rating the character has none of: none of it counts now (an item's rating of another kind: a critical strike's not
-- on the spells), and an item tried gives what the game's own call makes of it at the level
-- (GetCombatRatingBonusForCombatRatingValue); nil when the game says nothing of it. (The full review of 2026-11-20:
-- one point had been one percent, an item's 14 points of critical strike said +14 %; this build's items carry hit
-- and critical strike ratings, 184 and 522 of them.)
local function ratingShare(kind, tried)
    local rating, bonus = ns.Plain(GetCombatRating(kind)), ns.Plain(GetCombatRatingBonus(kind))
    if type(rating) == "number" and rating > 0 and type(bonus) == "number" then
        return bonus / rating
    elseif not (WOULD or tried) then
        return 0
    end
    local convert = GetCombatRatingBonusForCombatRatingValue
    local v = type(convert) == "function" and ns.Plain(ns.Call(convert, kind, 100))
    return type(v) == "number" and v / 100 or nil
end

-- The magic schools an aura on some of them changes, by the game's names (DAMAGE_SCHOOL2, holy, to 7, arcane); nil
-- for all of them.
local SCHOOL_NAMES = { "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
local function schoolsOf(mask)
    local names = {}
    for k = 1, 6 do
        if floor(mask / 2 ^ k) % 2 == 1 then
            names[#names + 1] = G("DAMAGE_SCHOOL" .. (k + 1), SCHOOL_NAMES[k])
        end
    end
    return #names > 0 and #names < 6 and table.concat(names, ", ") or nil
end

-- How an aura's effect of this kind changes the value, if it does: one of a kind of attack's (melee, ranged, spells)
-- only the value of that kind, `channel` the one shown.
local function wayOf(spec, kind, channel)
    local flat = spec.flat and spec.flat[kind]
    if flat then
        return (flat == true or (channel ~= nil and flat:find(channel, 1, true) ~= nil)) and "flat" or nil
    elseif spec.share and spec.share[kind] then
        return "share"
    elseif spec.baseShare and spec.baseShare[kind] then
        return "baseShare"
    elseif spec.ofStat and spec.ofStat[kind] then
        return "ofStat"
    elseif spec.shareOnly and spec.shareOnly[kind] then
        return "shareOnly"
    elseif spec.keep and spec.keep[kind] then
        return "keep"
    end
end

-- ---------- The sources that aren't auras (Ikar 2026-11-17: "Can we extend to include all sources?") ----------
-- Each from the game's own calls, what each gives from its data (Data/Effects.lua, hud/tools/make_effects.py): the
-- enchantments on the items, the sets' bonuses, the talents, the race's and the class's passive spells; and what the
-- value stands on before its changes, what the attributes give it, as the sheet's own tooltips work it out.

-- A spell's name as the game gives it.
local function spellName(spell)
    local name = C_Spell and ns.Call(C_Spell.GetSpellName, spell)
    return type(name) == "string" and name or ("#" .. tostring(spell))
end

-- An item's class, subclass and set, by its link (C_Item.GetItemInfo's 12th, 13th and 16th); nothing while the game
-- has it not.
local function itemKind(link)
    local get = C_Item and C_Item.GetItemInfo
    if type(get) ~= "function" then
        return nil
    end
    local info = { pcall(get, link) }
    if info[1] then
        return info[13], info[14], info[17]
    end
end

-- Whether bit k of one of the game's masks is set.
local function hasBit(mask, k)
    return floor(mask / 2 ^ k) % 2 == 1
end

-- The weapons' slots, Enum.WeaponSlot's (main hand, off hand, ranged) by the inventory's (INVSLOT_MAINHAND...).
local WEAPONS = { { 0, 16 }, { 1, 17 }, { 2, 18 } }

-- Whether a spell that isn't an aura the game applies counts now (Data/Effects.lua's EFFECT_NEEDS): an item of its kind
-- in a weapon's slot or the off hand (a weapon's specialisation, a shield's talent), its form or none of those it
-- leaves out (a druid's bear, a warrior's stance), a form by its number less one in the masks (GetShapeshiftFormID).
local function needsMet(spell)
    local needs = ns.EFFECT_NEEDS and ns.EFFECT_NEEDS[spell]
    for need in (needs or ""):gmatch("[^;]+") do
        local kind, a, b, c, d = need:match("^(%a):(%d+):(%d+):?(%d*):?(%d*)$")
        a, b, c, d = tonumber(a), tonumber(b), tonumber(c) or 0, tonumber(d) or 0
        if kind == "i" then
            local found = false
            for _, w in ipairs(WEAPONS) do
                local link = wornLink(w[2])
                local class, subclass = itemKind(link or "")
                if link and class == a and (b == 0 or (type(subclass) == "number" and hasBit(b, subclass))) then
                    found = true
                end
            end
            if not found then
                return false
            end
        elseif kind == "f" then
            local form = ns.Call(GetShapeshiftFormID) or 0
            local function within(low, high)
                return form > 0 and (form <= 32 and hasBit(low, form - 1) or form > 32 and hasBit(high, form - 33))
            end
            if (a ~= 0 or b ~= 0) and not within(a, b) or within(c, d) then
                return false
            end
        end
    end
    return true
end

-- A talent's value for one of its spell's effects at its rank (Data/Effects.lua's TALENT_POINTS, the trait's own curve:
-- set, or the spell's points multiplied); the spell's own points for a talent of one rank without one; nil else.
local function talentPoint(spell, rank, ranks, index, fixed)
    local points = ns.TALENT_POINTS and ns.TALENT_POINTS[spell]
    for part in (points or ""):gmatch("[^;]+") do
        local i, operation, values = part:match("^(%d+):(%d+):(.+)$")
        if tonumber(i) == index then
            local list = {}
            for v in values:gmatch("[^,]+") do
                list[#list + 1] = tonumber(v)
            end
            local v = list[min(max(rank, 1), #list)]
            if operation == "1" then
                local own = fixedPoints(fixed)
                return own and v and own * v
            end
            return v
        end
    end
    if ranks <= 1 then
        return fixedPoints(fixed)
    end
end

-- The figures the game's own words for a learned talent state at its rank (C_TooltipInfo.GetTraitEntry, the talent
-- frame's tooltip), its « 3/5 » left out: { [figure] = true } and how many, or nil where it says none (its text not
-- loaded yet: asked again next time). Ikar 2026-11-21, "review all talent, all similar assumption, can't you test them
-- ?": the probe (/khprobe talents, hud/tools/check_talents.py) found Mental Dexterity's 33, 66 and 100 % in the game's
-- words, where the data's values by rank say 50, 100 and 150; the game counts the first (its base, to the point).
local function talentSays(talent)
    if talent.says == nil and talent.entryID and C_TooltipInfo then
        local data = ns.Call(C_TooltipInfo.GetTraitEntry, talent.entryID, talent.rank)
        local found, n = {}, 0
        for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
            local text = ns.Plain(line.leftText)
            if type(text) == "string" then
                for figure in (text:gsub("%d+%s*/%s*%d+", "")):gmatch("%d+[.,]?%d*") do
                    local v = tonumber((figure:gsub(",", ".")))
                    if v and not found[v] then
                        found[v], n = true, n + 1
                    end
                end
            end
        end
        if n > 0 then
            talent.says, talent.saysCount = found, n
        end
    end
    return talent.says
end

-- A learned talent's value at its rank: the data's (talentPoint), held against the game's own words (talentSays). Kept
-- where they state it (or say nothing); else, for a talent of one effect whose words state one figure, that figure;
-- else unknown, the mark in its place rather than a figure the game doesn't give.
local function talentValue(talent, index, fixed)
    local v = talentPoint(talent.spell, talent.rank, talent.ranks, index, fixed)
    local says = talentSays(talent)
    if v == nil or not says or says[math.abs(v)] then
        return v
    end
    local _, effects = (ns.EFFECTS[talent.spell] or ""):gsub("%d+:%-?%d+:%d+:%d+:", "")
    if talent.saysCount == 1 and effects == 1 then
        local only = next(says)
        return v < 0 and -only or only
    end
    return nil
end

-- The spell's own points as the game's data has them, for a source the game gives none of (a set's, an enchantment's,
-- a passive spell's).
local function ownPoints(_, _, _, _, fixed)
    return fixedPoints(fixed)
end

-- The character's talents whose spell changes one of the sheet's values, { spell, rank, ranks, name }: Forever's
-- talents are trait nodes (Blizzard_PlayerSpells' Camelot ClassTalents), read as its talent frame reads them, the active
-- configuration's trees, each node's active rank and entry, its definition's spell. Read once, again when they change.
local talentList
local function talents()
    if WOULD and WOULD.talents then
        return WOULD.talents
    end
    if talentList then
        return talentList
    end
    local config = C_ClassTalents and ns.Call(C_ClassTalents.GetActiveConfigID)
    if not config and C_SpecializationInfo then
        local group = ns.Call(C_SpecializationInfo.GetActiveSpecGroup)
        config = group and ns.Call(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
    end
    local info = config and C_Traits and ns.Call(C_Traits.GetConfigInfo, config)
    if type(info) ~= "table" then
        return {}
    end
    local list = {}
    for _, tree in ipairs(type(info.treeIDs) == "table" and info.treeIDs or {}) do
        local nodes = ns.Call(C_Traits.GetTreeNodes, tree)
        for _, node in ipairs(type(nodes) == "table" and nodes or {}) do
            local n = ns.Call(C_Traits.GetNodeInfo, config, node)
            local rank = type(n) == "table" and tonumber(n.activeRank) or 0
            local entryID = rank > 0 and type(n.activeEntry) == "table" and n.activeEntry.entryID
            local entry = entryID and ns.Call(C_Traits.GetEntryInfo, config, entryID)
            local definition = type(entry) == "table" and entry.definitionID
                and ns.Call(C_Traits.GetDefinitionInfo, entry.definitionID)
            local spell = type(definition) == "table" and definition.spellID
            if spell and ns.EFFECTS[spell] then
                list[#list + 1] = { spell = spell, rank = rank, ranks = tonumber(n.maxRanks) or rank, entryID = entryID,
                    name = type(definition.overrideName) == "string" and definition.overrideName ~= ""
                        and definition.overrideName or spellName(spell) }
            end
        end
    end
    talentList = list
    return list
end

-- The race's and the class's passive spells the character knows (Data/Effects.lua's PASSIVES), read once, again when
-- its spells change.
local knownList
local function knownPassives()
    if knownList then
        return knownList
    end
    local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown
    if type(isKnown) ~= "function" then
        return {}
    end
    local list = {}
    for _, spell in ipairs(ns.PASSIVES or {}) do
        if ns.Call(isKnown, spell) == true then
            list[#list + 1] = spell
        end
    end
    knownList = list
    return list
end
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED" }) do
    ns.On(event, function()
        talentList, knownList = nil, nil
    end)
end

-- One spell's share of the value, as a source named `name`: each of its effects that changes it (Data/Effects.lua),
-- valued by valueOf(count, auras, index, place, fixed) (an aura's points, a talent's rank, the data's own), into the
-- tally t (sourcesOf's). Nothing when none of its effects changes the value. Into the row `into` when there's one (an
-- item's own spell, on the item's row); a new source is of the kind and the slot the tally is at (the gear's, a
-- set's: sourceRows groups them).
-- A name as plain text: no colour, no icon, for a sentence that names it.
local function nameOf(text)
    return (tostring(text):gsub("|T.-|t%s*", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- `why`: what a figure missing asks, with the source's name in it (L.STAT_WHY_CASTER unless given).
local function addSpell(t, spell, name, valueOf, into, why)
    local spec = t.spec
    local known = ns.EFFECTS and ns.EFFECTS[spell]
    local count, auras, effects = (known or ""):match("^(%d+),(%d+);(.+)$")
    local entry = into
    for kind, misc, index, place, fixed in (effects or ""):gmatch("(%d+):(%-?%d+):(%d+):(%d+):([^;]*)") do
        kind, misc = tonumber(kind), tonumber(misc)
        local way, scale = wayOf(spec, kind, t.channel), 1
        if kind == RATING_AURA then
            -- a rating: the value's own among those its mask names, worth what an item's is
            local rating = spec.rating and spec.rating(t.channel)
            way, scale = rating and hasBit(misc, rating - 1) and "flat" or nil, t.perPoint
        elseif way and spec.misc and not spec.misc(misc, kind) then
            way = nil
        end
        -- a speed's kind of how the character moves now alone (speedRole: running, mounted, swimming)
        if way and spec.speed and not speedRole(kind, t.mode) then
            way = nil
        end
        local v = way and valueOf(tonumber(count), tonumber(auras), tonumber(index), tonumber(place), fixed)
        local asks = why
        if v and scale == nil then
            -- a rating the game says nothing of now (ratingShare): what it gives unknown
            v, asks = nil, L.STAT_WHY_RATING
        elseif v then
            v = v * scale * (spec.negate and -1 or 1)
        end
        -- a share of an attribute, as points: what it gives now (Spiritual Guidance, a share of the spirit)
        local ofStat = way == "ofStat"
        if ofStat then
            local a = attribute(misc + 1)
            v, way = v and a and a * v / 100, "flat"
        end
        -- an effect worth 0 changes nothing, and is no source (the data's 0 a placeholder, Berserker Stance's attack
        -- power: it had been read as a figure missing, a question mark and nothing left said; the audit of
        -- 2026-11-19, Ikar: "other suspicious sources of unknown ?")
        if way and v ~= 0 then
            -- (what its row shows on hover on a card kept open, StatCard.lua's: the aura's or the talent's the caller
            -- set, else the item in the slot read, else the spell's own)
            entry = entry or { name = name, kind = t.kind, slot = t.slot,
                tip = t.tip or (t.slot and { slot = t.slot, spell = spell }) or { spell = spell } }
            -- (the schools of a flat change alone: a share's misc is none, Blood Fury's)
            if (spec.schools or spec.schoolKinds and spec.schoolKinds[kind]) and not entry.schools and way == "flat"
                and not ofStat then
                entry.schools = schoolsOf(misc)
                entry.name = entry.schools and (entry.name .. " (" .. entry.schools .. ")") or entry.name
            end
            if v == nil then
                -- one of its effects without an amount: what the others come to isn't the whole of it, and the row
                -- says why (Ikar 2026-11-19: "the description should give an answer")
                t.open, entry.unsure = true, true
                entry.why = entry.why or string.format(asks or L.STAT_WHY_CASTER, nameOf(entry.name))
            elseif way == "flat" then
                entry.points = (entry.points or 0) + v
                t.flat = t.flat + v
                if ofStat then
                    -- (what such shares come to, which the game may count in its base: sourcesOf)
                    entry.ofStat, t.ofStat = true, (t.ofStat or 0) + v
                end
                if spec.speed then
                    -- (each kind's, for the strongest of it: speedOf)
                    entry.speeds = entry.speeds or {}
                    entry.speeds[kind] = (entry.speeds[kind] or 0) + v
                end
            elseif way == "keep" then
                -- a share of the regeneration kept while casting, or in a fight: of the figure in that state alone,
                -- not of the one tallied here (Stats.RegenTable)
                entry.keep = (entry.keep or 0) + v / 100
            else
                entry.share = (entry.share or 0) + v / 100
                if way == "share" then
                    t.whole = t.whole * (1 + v / 100)
                    t.shares[#t.shares + 1] = entry
                elseif way == "baseShare" then
                    -- (what it comes to, once the base is known: sourcesOf)
                    t.ofBase = t.ofBase + v / 100
                    entry.baseShare = (entry.baseShare or 0) + v / 100
                else
                    t.open = true
                end
            end
        end
    end
    if entry and not into then
        t.list[#t.list + 1] = entry
    end
end

-- The hidden auras an aura's own tooltip names (Data/Effects.lua's HIDDEN_PARTS): the camp's benefits, which the game
-- gives no addon (GetPlayerAuraBySpellID gives nothing of them, Ikar's fish bowl's included) but writes a line of in
-- « Avantages du camp »'s tooltip for each the character has (Ikar 2026-11-22: "we see it in avantages de feux de
-- camps"; its tooltip read « Bocal à poisson : augmentation de toutes les caractéristiques de 8 %. »). A line that
-- starts with one's words in the client's language names it: { spell, name (the item's, before the colon), points
-- (by effect index: the line's figures, the aura's own, which can be less than the data's, Ikar's incense candle at
-- level 26, 2026-11-22), every (the seconds between two gains of mana it gives by itself: the mana well's) }. nil for
-- an aura without any, and where its tooltip's text is secret (a fight): what they give is « Autres » then, as in a
-- language the data hasn't. `from` another such table than HIDDEN_PARTS (XP_PARTS, the XP bar's); a line's words
-- anywhere in it (a meal's experience follows its attribute's sentence).
function Stats.HiddenParts(aura, from)
    from = from or ns.HIDDEN_PARTS
    local parts = from and from[ns.Plain(aura.spellId)]
    local instance = parts and ns.Plain(aura.auraInstanceID)
    local data = instance and C_TooltipInfo
        and ns.Plain(ns.Call(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", instance))
    local lines = type(data) == "table" and ns.Plain(data.lines)
    if type(lines) ~= "table" then
        return nil
    end
    local language, found = ns.LOCALE == "enGB" and "enUS" or ns.LOCALE, {}
    for _, line in ipairs(lines) do
        line = ns.Plain(line)
        local text = type(line) == "table" and ns.Plain(line.leftText)
        -- (the aura's text is one line of its tooltip, its own lines in it, "\r\n" between them in the game's data)
        for said in (type(text) == "string" and text or ""):gmatch("[^\r\n]+") do
            for _, part in ipairs(parts) do
                local start = part[language]
                local at = start and said:find(start, 1, true)
                if at then
                    local figures, points = {}, {}
                    for figure in said:sub(at + #start):gmatch("%d+[.,]?%d*") do
                        figures[#figures + 1] = tonumber((figure:gsub(",", ".")))
                    end
                    for i, n in ipairs(part.w or {}) do
                        points[i - 1] = figures[n]
                    end
                    found[#found + 1] = { spell = part[1], points = points, every = part.every,
                        name = (start:gsub("\194\160", " ")):match("^(.-)%s*:") or start }
                end
            end
        end
    end
    return found
end

-- What an enchantment gives of the value (Data/Effects.lua's ENCHANTS), as a source named `name`: its stats as the
-- gear's are, its spells' as theirs; one whose amount follows the item's level, named without it.
local function addEnchant(t, enchant, name)
    local gives = ns.ENCHANTS and ns.ENCHANTS[enchant]
    if not gives then
        return
    end
    local v, unknown = 0, nil
    for part in gives:gmatch("[^;]+") do
        local key, amount = part:match("^([^:]+):(.*)$")
        if key == "s" then
            local spell = tonumber(amount)
            if spell and not t.seen[spell] and needsMet(spell) then
                addSpell(t, spell, name, ownPoints)
            end
        elseif key then
            local stat = key:find("^RESISTANCE") and (key .. "_NAME") or ("ITEM_MOD_" .. key .. "_SHORT")
            if t.gear[stat] then
                local n = tonumber(amount)
                if n and t.perPoint then
                    v = v + n * t.perPoint
                elseif n then
                    -- (a rating the game says nothing of: ratingShare)
                    unknown = L.STAT_WHY_RATING
                else
                    unknown = L.STAT_WHY_ITEM_LEVEL
                end
            end
        end
    end
    if v ~= 0 or unknown then
        t.list[#t.list + 1] = { name = name, points = v ~= 0 and v or nil, unsure = unknown and true or nil,
            kind = t.kind, slot = t.slot, why = unknown and string.format(unknown, nameOf(name)) or nil }
        t.flat = t.flat + v
        t.open = t.open or unknown ~= nil
    end
end

-- An item's enchantment, permanent or for a while, by the slot it's on, not the item's name nor its tooltip's line
-- (Ikar 2026-11-19: "I would prefere Enchantement (bracelet) + 4, no full name of the item, just it slot suffice"):
-- « Enchantement (Poignets) », the slot in the game's words (GlobalStrings' <slot>SLOT, by inventory slot), in the
-- game's green for enchantments.
local PERMANENT = Enum.ItemEnchantType and Enum.ItemEnchantType.Permanent or 1
local SLOT_WORDS = {
    { "HEADSLOT", "Head" }, { "NECKSLOT", "Neck" }, { "SHOULDERSLOT", "Shoulders" }, { "SHIRTSLOT", "Shirt" },
    { "CHESTSLOT", "Chest" }, { "WAISTSLOT", "Waist" }, { "LEGSSLOT", "Legs" }, { "FEETSLOT", "Feet" },
    { "WRISTSLOT", "Wrist" }, { "HANDSSLOT", "Hands" }, { "FINGER0SLOT", "Finger" }, { "FINGER1SLOT", "Finger" },
    { "TRINKET0SLOT", "Trinket" }, { "TRINKET1SLOT", "Trinket" }, { "BACKSLOT", "Back" },
    { "MAINHANDSLOT", "Main Hand" }, { "SECONDARYHANDSLOT", "Off Hand" }, { "RANGEDSLOT", "Ranged" },
    { "TABARDSLOT", "Tabard" },
}
local function enchanted(slot)
    local word = SLOT_WORDS[slot]
    return Infos.Color(string.format(L.STAT_ENCHANT, word and G(word[1], word[2]) or tostring(slot)), Infos.GOOD)
end
Stats.Enchanted = enchanted

-- What a value stands on before its changes, as the sheet's own tooltips work it out (PaperDollFrame_SetStatTooltip2,
-- Camelot's): what each attribute gives it at its value now; the armour, each item's own (C_Item.GetItemStats'
-- RESISTANCE0_NAME, inferred: the sheet names no item) and the agility's. Each { name, points, percent }.
-- The agility's armour, Camelot's PaperDollFrameStats.lua's own (a local there). The attack power a point of damage
-- a second takes (the sheet's ATTACK_POWER_MAGIC_NUMBER), a point of defence's share of a percent and the strength a
-- point of block value takes (locals of PaperDollFrameStats.lua).
local ARMOR_PER_AGILITY = 2
local POWER_PER_DAMAGE, PERCENT_PER_DEFENSE, STRENGTH_PER_BLOCK = 14, 0.04, 20
-- The defence with its bonus, what is tried's change on it while what would be is read (Tried.Change); nil while the
-- game hides it.
function Tried.Defense()
    local base, mod = ns.Plain(UnitDefenseSkill("player"))
    if base == nil then
        return nil
    end
    return max(0, max(0, base + (mod or 0)) + Tried.Change("DEFENSE"))
end
-- The dodge's, the parry's or the block's chance, the sheet's (TOTALS'), what is tried's change on it with it; nil
-- while the game hides it.
function Tried.Chance(key)
    local v = TOTALS[key]()
    return type(v) == "number" and v + Tried.Change(key) or nil
end
-- What defence past the level's most adds to the dodge, the parry and the block, or takes away below it, in points
-- of a percent (0.04 a point either way: PaperDollFrameStats.lua's GetEnemyChanceToMiss, the original server's); nil
-- while the game hides it.
local function defenseShare()
    local have = Tried.Defense()
    if have == nil then
        return nil
    end
    local most = (UnitLevel("player") or 0) * 5
    return (have - most) * PERCENT_PER_DEFENSE, have, most
end
-- A part worked out of a skill against the level's most, its name with its sum (the review of 2026-11-23, Ikar's rule
-- of that day: "I told you to mark any formulas no ?"): « Défense (118 - 115) x 0,04 % ».
function Stats.PartSum(name, have, most)
    return string.format(L.STAT_PART_SUM, name, number(have), number(most), Format.PercentOf(PERCENT_PER_DEFENSE, 2))
end
-- Its share of the sheet's dodge, parry and block, either way of the level's most: the original server adds it to the
-- value it shows, as the defence's own card says (GIVES.DEFENSE); none on a value at 0, a
-- character that can't parry or block (the full review of 2026-11-20: it had been said above the most alone).
local function defensePart(list, value)
    local v, have, most = defenseShare()
    if v and (v >= 0.005 or v <= -0.005) and type(value) == "number" and value > 0 then
        list[#list + 1] = { name = Stats.PartSum(G("DEFENSE", "Defense"), have, most), points = v, percent = true,
            match = "defense" }
    end
end
-- The skill line of the weapon in a slot, as the Skills tab's (WEAPON_SKILL_LINES), a druid in a form its feral
-- combat's, nothing in the main hand its unarmed's: its value with its bonus, the level's most (five a level), its
-- name; false with no weapon of a skill there (no ranged weapon, a fishing pole), nil when it can't be read. The
-- weapon tried in the slot while what would be is read (wornLink): an axe tried in place of a mace, the axes' skill.
-- What the items tried would change of the skill line `line`, against those worn in the slots they would take: Forever's
-- items' weapon skills (their stats 90 to 105, « +3 Dagues »; Ikar 2026-11-26, "fix the gaps"); 0 while nothing is
-- tried. The fists' the fist weapons'.
Tried.SKILL_STATS = { [43] = "ITEM_MOD_SWORDS_SHORT", [44] = "ITEM_MOD_AXES_SHORT", [45] = "ITEM_MOD_BOWS_SHORT",
    [46] = "ITEM_MOD_GUNS_SHORT", [54] = "ITEM_MOD_MACES_SHORT", [55] = "ITEM_MOD_TWOHANDED_SWORDS_SHORT",
    [136] = "ITEM_MOD_STAVES_SHORT", [160] = "ITEM_MOD_TWOHANDED_MACES_SHORT", [162] = "ITEM_MOD_FIST_WEAPONS_SHORT",
    [172] = "ITEM_MOD_TWOHANDED_AXES_SHORT", [173] = "ITEM_MOD_DAGGERS_SHORT", [176] = "ITEM_MOD_THROWN_SHORT",
    [226] = "ITEM_MOD_CROSSBOWS_SHORT", [228] = "ITEM_MOD_WANDS_SHORT", [229] = "ITEM_MOD_POLEARMS_SHORT" }
function Tried.SkillChange(line)
    local key = Tried.SKILL_STATS[line]
    local links = WOULD and WOULD.links
    if not (key and links) then
        return 0
    end
    local function of(link)
        local stats = link and C_Item.GetItemStats(link)
        return type(stats) == "table" and tonumber(stats[key]) or 0
    end
    local change = 0
    for slot, link in pairs(links) do
        change = change + of(link or nil) - of(GetInventoryItemLink("player", slot))
    end
    return change
end
-- The quiver or the ammunition pouch worn in a bag's slot (an item of the kind « Carquois », 11), its link and slot; the
-- one tried in its place while what would be is read (`quiver`, itemTried).
function Tried.WornQuiver()
    for bag = 1, NUM_BAG_SLOTS or 4 do
        local slot = C_Container and C_Container.ContainerIDToInventoryID
            and ns.Call(C_Container.ContainerIDToInventoryID, bag)
        local link = type(slot) == "number" and GetInventoryItemLink("player", slot)
        local ok, _, _, _, _, _, class = pcall(C_Item.GetItemInfoInstant, link or "")
        if link and ok and class == (Enum.ItemClass and Enum.ItemClass.Quiver or 11) then
            return link, slot
        end
    end
end
function Tried.Quiver()
    if WOULD and WOULD.quiver then
        return WOULD.quiver
    end
    return (Tried.WornQuiver())
end
-- The spells of what what is tried would take off (Data/Effects.lua's ITEM_SPELLS), which the game may show as auras:
-- theirs no more (the worn items replaced or emptied, the worn quiver for one tried; Ikar 2026-11-26, "fix the gaps").
function Tried.TakenOff()
    local off = {}
    local function drop(link)
        local id = link and tonumber(link:match("item:(%-?%d+)"))
        for spell in (id and ns.ITEM_SPELLS and ns.ITEM_SPELLS[id] or ""):gmatch("%d+") do
            off[tonumber(spell)] = true
        end
    end
    for slot in pairs(WOULD and WOULD.links or {}) do
        drop(GetInventoryItemLink("player", slot))
    end
    if WOULD and WOULD.quiver then
        drop((Tried.WornQuiver()))
    end
    return off
end
local SKILL_OF_WEAPON = { Sword1H = 43, Axe1H = 44, Bows = 45, Guns = 46, Mace1H = 54, Sword2H = 55, Staff = 136,
    Mace2H = 160, Axe2H = 172, Dagger = 173, Thrown = 176, Crossbow = 226, Wand = 228, Polearm = 229, Unarmed = 162 }
local function weaponSkill(slot)
    local line
    if select(2, UnitClass("player")) == "DRUID" and (ns.Call(GetShapeshiftForm) or 0) ~= 0 then
        line = 3014
    else
        local link = wornLink(slot)
        if not link then
            line = slot == 16 and 162 or nil
        else
            local ok, _, _, _, _, _, class, subclass = pcall(C_Item.GetItemInfoInstant, link)
            local kinds = Enum.ItemWeaponSubclass
            if ok and kinds and class == (Enum.ItemClass and Enum.ItemClass.Weapon or 2) then
                for kind, skill in pairs(SKILL_OF_WEAPON) do
                    if kinds[kind] == subclass then
                        line = skill
                    end
                end
            end
        end
    end
    if not line then
        return false
    end
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
        and ns.Plain(ns.Call(C_SkillInfo.GetSkillLineInfoByID, line))
    local rank = type(info) == "table" and ns.Plain(info.rank)
    if type(rank) ~= "number" then
        return nil
    end
    return rank + (ns.Plain(info.modifier) or 0) + Tried.SkillChange(line), (UnitLevel("player") or 0) * 5,
        ns.Plain(info.name) or "?", info
end
-- A shield's block as its tooltip writes it (SHIELD_BLOCK_TEMPLATE, « Bloquer : %s »; Forever's data has no field of
-- it, the client working it out): the worn one's, the one tried's by its link; nil for none, an off hand that isn't a
-- shield.
function Stats.ShieldBlock(link)
    local template = G("SHIELD_BLOCK_TEMPLATE")
    if type(template) ~= "string" or not C_TooltipInfo then
        return nil
    end
    local before, after = template:match("^(.-)%%s(.*)$")
    if not before then
        return nil
    end
    local function plain(s)
        return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
    end
    local pattern = "^" .. plain(before) .. "(%d+)" .. plain(after) .. "$"
    local data
    if WOULD and WOULD.links and WOULD.links[17] then
        data = ns.Call(C_TooltipInfo.GetHyperlink, link)
    else
        data = ns.Call(C_TooltipInfo.GetInventoryItem, "player", 17)
    end
    for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
        local text = type(line) == "table" and ns.Plain(line.leftText)
        if type(text) == "string" then
            local n = tonumber((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")):match(pattern))
            if n then
                return n
            end
        end
    end
end
local function part(list, i, v, percent)
    if type(v) ~= "number" then
        return
    end
    if not percent then
        v = floor(v + 0.5)
    end
    if percent and (v >= 0.005 or v <= -0.005) or not percent and v ~= 0 then
        list[#list + 1] = { name = G("SPELL_STAT" .. i .. "_NAME", ATTRIBUTE_KEYS[i]), points = v, percent = percent == true }
    end
end
-- The mana the spirit gives a second (GetManaRegenFromSpirit, the game's at the spirit now), what is tried's change
-- of the spirit followed while what would be is read (Ikar 2026-11-25: "mana regen seems also to have hard time
-- showing the new values"): Forever gives every class 6.25 + spirit / 8 a second, the original server's priests' and
-- mages' sum (its shamans' 17 + spirit / 5 a tick: Ikar's dwarf shaman of 2026-11-23 had 13.75 at 60 spirit, this
-- sum's, the original's 14.5; wowsims/forever's sim, which tests the sum the same for every class, and
-- gunba/wow-forever-sim's, from the beta's hunters and paladins). The game's figure by that sum's ratio at the spirit
-- tried, whatever share of it the game raises it by (Innervate's) followed too. The spirit read, what it stands on
-- (Tried.leaned): an attribute's change that can't be said is its question.
Tried.SPIRIT_MANA = { 6.25, 1 / 8 }
function Tried.ManaFromSpirit()
    local v = ns.Plain(GetManaRegenFromSpirit())
    if type(v) ~= "number" then
        return nil
    end
    if Tried.leaned then
        Tried.leaned[5] = true
    end
    local more = WOULD and WOULD.attributes and WOULD.attributes[5] or 0
    local _, spirit = ns.Plain(UnitStat("player", 5))
    if more == 0 or type(spirit) ~= "number" then
        return v
    end
    local sum = Tried.SPIRIT_MANA
    return v * (sum[1] + max(0, spirit + more) * sum[2]) / (sum[1] + spirit * sum[2])
end
-- The health the spirit gives a second (GetHealthRegenFromSpirit, the game's at the spirit now), what is tried's change
-- of the spirit followed while what would be is read, an estimate (Ikar 2026-11-26: "Everything should follow, every,
-- single, line. Not a single exception"): no sum of Forever's is known (neither sim models it), and the original
-- server's isn't Ikar's dwarf shaman's (spirit x 0.28 - 3.6 a tick of 2 s, 34 in 5 s standing at 64 spirit where he
-- had 33); its slope for the class, a point of spirit's share of a tick, added to the game's figure. What it gives the
-- lines says the game's question mark after it (wouldBe's `estimate`); a class the original server hasn't, the
-- spirit's question alone. The spirit read, what it stands on (Tried.leaned): an attribute's change that can't be said
-- is its question.
Tried.SPIRIT_HEALTH = { WARRIOR = 1.26, ROGUE = 0.84, HUNTER = 0.43, SHAMAN = 0.28, PALADIN = 0.25, PRIEST = 0.15,
    WARLOCK = 0.12, MAGE = 0.11, DRUID = 0.11 }
function Tried.HealthFromSpirit()
    local v = ns.Plain(GetHealthRegenFromSpirit())
    if type(v) ~= "number" then
        return nil
    end
    if Tried.leaned then
        Tried.leaned[5] = true
    end
    local more = WOULD and WOULD.attributes and WOULD.attributes[5] or 0
    if more == 0 then
        return v
    end
    local slope = Tried.SPIRIT_HEALTH[select(2, UnitClass("player")) or ""]
    return slope and max(0, v + slope / 2 * more) or v
end
-- Whether what is tried (`tried`: Tried.With's) changes the spirit, the health it gives then an estimate: "estimate",
-- "unknown" for a class the original server hasn't (no slope: its figure as it is, the question alone); nil else.
function Tried.SpiritGuess(tried)
    if not (tried and tried.attributes and (tried.attributes[5] or 0) ~= 0) then
        return nil
    end
    return Tried.SPIRIT_HEALTH[select(2, UnitClass("player")) or ""] and "estimate" or "unknown"
end
-- The dodge the agility gives, a share of one (GetDodgeChanceFromAttribute, the game's at the agility now): what is
-- tried's change of the agility followed point for point.
function Tried.DodgeFromAgility()
    local v = ns.Plain(GetDodgeChanceFromAttribute())
    local _, now = ns.Plain(UnitStat("player", 2))
    local agility = attribute(2)
    if type(v) == "number" and type(now) == "number" and now > 0 and agility and agility ~= now then
        v = v * agility / now
    end
    return type(v) == "number" and v or nil
end
local PARTS = {
    HEALTH = function()
        local list, stamina = {}, attribute(3)
        local per = ns.Plain(UnitHPPerStamina("player"))
        if stamina and per then
            local first = STAMINA_BREAK or 20
            part(list, 3, min(first, stamina) + max(0, stamina - first) * per)
        end
        return list
    end,
    POWER = function()
        local list, intellect = {}, attribute(4)
        if intellect and manaShown() then
            local first, per = INTELLECT_BREAK or 20, MANA_PER_INTELLECT or 15
            part(list, 4, min(first, intellect) + max(0, intellect - first) * per)
        end
        return list
    end,
    ATTACK_AP = function()
        local list = {}
        for _, i in ipairs({ 1, 2 }) do
            local v = attribute(i)
            part(list, i, v and ns.Plain(GetAttackPowerForStat(i, v)))
        end
        return list
    end,
    RANGED_ATTACK_AP = function()
        local list = {}
        for _, i in ipairs({ 1, 2 }) do
            local v = attribute(i)
            part(list, i, v and ns.Plain(GetRangedAttackPowerForStat(i, v)))
        end
        return list
    end,
    -- the kind of attack shown: the spells' their intellect's, the weapons' their agility's, and their weapon skill
    -- against the level's most, 0.04 % a point either way: the original server adds it to the value it shows, as
    -- Forever's Skills tab says of it (GetCriticalHitChance; the full review of
    -- 2026-11-20)
    CRITCHANCE = function(channel)
        local list = {}
        if channel == "s" then
            local intellect = attribute(4)
            local spell = intellect and ns.Plain(GetSpellCritChanceFromStat(4, intellect))
            part(list, 4, spell and spell * 100, true)
        else
            local agility = attribute(2)
            local melee = agility and ns.Plain(GetCritChanceFromStat(2, agility))
            part(list, 2, melee and melee * 100, true)
            local have, most, name = weaponSkill(channel == "r" and 18 or 16)
            local v = have and (have - most) * PERCENT_PER_DEFENSE
            if v and (v >= 0.005 or v <= -0.005) then
                list[#list + 1] = { name = Stats.PartSum(string.format(L.STAT_SKILL_PART, name), have, most),
                    points = v, percent = true, match = "skill" }
            end
        end
        return list
    end,
    DODGE = function()
        local list = {}
        local v = Tried.DodgeFromAgility()
        part(list, 2, v and v * 100, true)
        defensePart(list, TOTALS.DODGE())
        return list
    end,
    PARRY = function()
        local list = {}
        defensePart(list, TOTALS.PARRY())
        return list
    end,
    BLOCK = function()
        local list = {}
        defensePart(list, TOTALS.BLOCK())
        return list
    end,
    -- (cut to a whole as the sheet's « %d » writes the spirit's, TOTALS' too)
    REGEN = function()
        local list = {}
        if hasMana() then
            local v = Tried.ManaFromSpirit()
            part(list, 5, v and floor(v * 5 + 1e-6))
        end
        return list
    end,
    -- out of a fight, standing, as the sheet takes it: three quarters of what the spirit gives
    HEALTH_REGEN = function()
        local list = {}
        local v = Tried.HealthFromSpirit()
        part(list, 5, v and floor(v * 0.75 * 5 + 1e-6))
        return list
    end,
    -- the shield's own block, as its tooltip writes it (« Bloquer : 20 », SHIELD_BLOCK_TEMPLATE: the game's data has it
    -- not), the strength's, one point in 20 as the sheet's strength tooltip says, and the point the game's figure has
    -- less than both (Ikar's screenshot of 2026-11-23: a shield's 7 and the strength's 3, the game's 9; « Erreur de
    -- l'add-on -1 » while it was left out)
    BLOCKVALUE = function()
        local list = {}
        local link = wornLink(17)
        local block = link and Stats.ShieldBlock(link)
        if block and block > 0 then
            list[#list + 1] = { name = itemName(link, 17), points = block, item = true, slot = 17 }
        end
        local strength = attribute(1)
        if strength then
            local v = floor(strength / STRENGTH_PER_BLOCK)
            if v ~= 0 then
                list[#list + 1] = { name = G("SPELL_STAT1_NAME", "Strength"), points = v }
            end
        end
        -- (with a shield alone: Ikar's druid of issue #5, 2026-11-24, no shield and 33 strength, the game's 1, the
        -- strength's point; « Autres 1 » while it was taken off there too)
        if block and block > 0 then
            list[#list + 1] = { name = L.STAT_BASE, points = -1, tip = { lines = { L.STAT_BLOCK_BASE_TIP } } }
        end
        return list
    end,
    ARMOR = function()
        local list = {}
        for slot = FIRST_SLOT, LAST_SLOT do
            local link = wornLink(slot)
            local stats = link and C_Item.GetItemStats(link)
            local v = type(stats) == "table" and tonumber(stats.RESISTANCE0_NAME)
            if v and v ~= 0 then
                list[#list + 1] = { name = itemName(link, slot), points = v, item = true, slot = slot }
            end
        end
        local agility = attribute(2)
        part(list, 2, agility and agility * ARMOR_PER_AGILITY)
        return list
    end,
    -- the defence's column's four, against an enemy of the character's level: each its sum (Ikar 2026-11-23: "add
    -- the 4"; "I told you to mark any formulas no ?"), the armour's the game's own figure of the armour it names
    -- (each row the same by what it is, its figures beside it changing: `match`, the card kept open's mergeRows)
    ARMORCUT = function()
        local cut, armor = Stats.ArmorCut()
        return cut and { { name = G("STAT_ARMOR", "Armor") .. " " .. number(armor), points = cut, percent = true,
            match = "armor" } } or {}
    end,
    MISSED = function()
        local t = Stats.Taken()
        if not t then
            return {}
        end
        local list = { { name = L.STAT_BASE, points = t.miss - (t.have - t.most) * PERCENT_PER_DEFENSE, percent = true } }
        if t.have ~= t.most then
            list[2] = { name = Stats.PartSum(G("DEFENSE", "Defense"), t.have, t.most),
                points = (t.have - t.most) * PERCENT_PER_DEFENSE, percent = true, match = "defense" }
        end
        return list
    end,
    CRITTAKEN = function()
        local t = Stats.Taken()
        if not t then
            return {}
        end
        local list = { { name = L.STAT_BASE, points = t.crit + (t.have - t.most) * PERCENT_PER_DEFENSE, percent = true } }
        if t.have ~= t.most then
            list[2] = { name = Stats.PartSum(G("DEFENSE", "Defense"), t.have, t.most),
                points = -(t.have - t.most) * PERCENT_PER_DEFENSE, percent = true, match = "defense" }
        end
        return list
    end,
    -- (the dodge, the parry and the block with what is tried's change of each: Tried.Change)
    AVOIDANCE = function()
        local t = Stats.Taken()
        if not t then
            return {}
        end
        local list = {}
        for _, r in ipairs({ { L.STAT_MISSED, t.miss }, { G("STAT_DODGE", "Dodge"), Tried.Chance("DODGE") },
            { G("STAT_PARRY", "Parry"), Tried.Chance("PARRY") }, { G("STAT_BLOCK", "Block"), Tried.Chance("BLOCK") } }) do
            if type(r[2]) == "number" and r[2] > 0 then
                list[#list + 1] = { name = r[1], points = r[2], percent = true }
            end
        end
        return list
    end,
}
for _, s in ipairs(LIST) do
    s.parts = PARTS[s.key]
end

-- The sets worn: how many pieces of each, and the sets in the slots' order.
local function wornSets()
    local sets, order = {}, {}
    for slot = FIRST_SLOT, LAST_SLOT do
        local link = wornLink(slot)
        local _, _, set = itemKind(link or "")
        if link and type(set) == "number" and set > 0 then
            if not sets[set] then
                order[#order + 1] = set
            end
            sets[set] = (sets[set] or 0) + 1
        end
    end
    return sets, order
end

-- What the next pieces of the sets worn would give of the value (Ikar 2026-11-19: "do 10, 1, 2 […], 4"): each set's
-- nearest bonus not had yet that changes it, named as the game names a set with its pieces, « Tenue de bataille
-- (2/3) », the 3 the pieces that bonus takes. Not a source: a row of its own (`next`), worked out on a tally of its
-- own and counted in none of the value's sums.
local function nextBonuses(t, sets, order)
    for _, set in ipairs(order) do
        local setName = C_Item and ns.Call(C_Item.GetItemSetInfo, set)
        local best
        for pieces, spell in (ns.ITEM_SETS and ns.ITEM_SETS[set] or ""):gmatch("(%d+):(%d+)") do
            pieces, spell = tonumber(pieces), tonumber(spell)
            if pieces > sets[set] and (not best or pieces <= best.pieces) and needsMet(spell) then
                -- (a rating not had yet: what the game makes of it, as for an item tried)
                local probe = { spec = t.spec, base = t.base, list = {}, flat = 0, whole = 1, ofBase = 0, open = false,
                    shares = {}, seen = {}, gear = t.gear, channel = t.channel, perPoint = t.triedPerPoint,
                    mode = t.mode, items = 0 }
                addSpell(probe, spell, string.format(G("ITEM_SET_NAME", "%s (%d/%d)"),
                    type(setName) == "string" and setName or "?", sets[set], pieces), ownPoints)
                local e = probe.list[1]
                if e and best and best.pieces == pieces then
                    -- two bonuses of the same pieces: one row
                    best.points = (e.points or best.points) and (best.points or 0) + (e.points or 0)
                    best.share = (e.share or best.share) and (best.share or 0) + (e.share or 0)
                    best.unsure = best.unsure or e.unsure
                    best.why = best.why or e.why
                elseif e then
                    best = e
                    best.pieces, best.kind, best.next = pieces, "set", true
                    best.percent = t.spec.percent and true or false
                end
            end
        end
        if best then
            t.list[#t.list + 1] = best
        end
    end
end

-- The speed's sources as the original server works the speed out (the full review of
-- 2026-11-20, two raises of a kind had both been counted, a mount's and a swim's none): of each kind of raise for how
-- the character moves, the strongest alone, those that stack multiplied, the better of those and the non-stacking
-- one, the strongest slow; the others said not stacking (`idle`). What the named ones leave of the speed, as a share
-- of what they come to, « Autres » (a mount whose speed the game keeps on a hidden aura); swimming from its own base
-- (4.72 yards a second, the sheet's figure against the running's 7).
local SWIM_BASE = 4.722222 / BASE_SPEED
local function speedOf(s, t)
    local strongest = {}
    for _, e in ipairs(t.list) do
        for kind, v in pairs(e.speeds or {}) do
            local role = speedRole(kind, t.mode)
            local best = strongest[role]
            if (role == "slow" and v < 0 and (not best or v < best.v))
                or ((role == "main" or role == "nonstack") and v > 0 and (not best or v > best.v)) then
                strongest[role] = { v = v, entry = e, kind = kind }
            end
        end
    end
    local stack = 1
    for _, e in ipairs(t.list) do
        if e.speeds then
            local counted, any = 0, false
            for kind, v in pairs(e.speeds) do
                local role = speedRole(kind, t.mode)
                local best = strongest[role]
                if role == "stack" then
                    stack, counted, any = stack * (1 + v / 100), counted + v, true
                elseif best and best.entry == e and best.kind == kind then
                    counted, any = counted + v, true
                end
            end
            e.points, e.idle = any and counted or nil, not any or nil
        end
    end
    local function share(role)
        return strongest[role] and strongest[role].v / 100 or 0
    end
    local expected = max(stack, 1 + share("nonstack")) * (1 + share("main")) * (1 + share("slow"))
        * (t.mode == "swim" and SWIM_BASE or 1)
    t.expected = expected
    local total = s.total and s.total()
    if type(total) == "number" and expected > 0 and not t.open and not WOULD then
        local rest = (total / 100 / expected - 1) * 100
        if rest >= 0.5 or rest <= -0.5 then
            t.list[#t.list + 1] = { name = L.STAT_OTHER, points = rest, other = true, percent = true }
        end
    end
end

-- What a value is made of, out of a fight. First what it stands on (PARTS), a base the game gives named after where
-- it comes from (baseRow: the race's, the class's, the level's). Then what changes it: each item that
-- carries some of it, by how much, in the slots' order, with its enchantment; the sets' bonuses; each buff then each
-- debuff whose spell changes it, by its points or its share (with what that share comes to when it's the one share of
-- the whole, or a share of the base); each talent at its rank, each passive spell of the race or the class known; a
-- spell met as an aura not named again as a talent's or a passive's. Then, for a value the game gives the changes' sum
-- of (`numbers`), what's left, "Others": that sum less what's named, what the shares come to set apart. None left when
-- a source's points are unknown or a share can't be worked out (the armour's), and none of a point either way beside a
-- share, the game's rounding. Nil when nothing is found. With `withNext` (the card's), what the next pieces of the sets
-- worn would give too (nextBonuses), rows that are no source. With `full`, all of it tallied though the game says
-- nothing changes the value, and the tally itself returned third: what would be is compared with it. While WOULD is
-- set, what the game's sums leave over (the base, « Autres ») is left out: they are the value's as it is.
local function sourcesOf(s, withNext, full)
    local spec = s.sources
    if ns.InCombat() or (spec.when and not spec.when()) then
        return nil
    end
    local base, effective, pos, neg
    if s.numbers then
        base, effective, pos, neg = s.numbers()
        if base == nil then
            return nil
        end
    end
    -- the kind of attack the value shows, for one that is the best of three; one asked (Tried.Change's, a card's
    -- effects for each kind)
    local channel
    if spec.channel then
        local asked = Tried.channel
        channel = asked and asked[1] == s.key and asked[2] or spec.channel()
        if not channel then
            return nil
        end
    end
    -- (the gear's stats for it: a list, or what gives the list now, the power's)
    local gearKeys = type(spec.gear) == "function" and spec.gear() or spec.gear
    local gear = {}
    for _, key in ipairs(gearKeys) do
        gear[key] = true
    end
    -- what a point of its rating gives now, and of one not had yet (ratingShare); how the character moves, for the
    -- speed (speedRole); `items`, the items' own stats, which the shares of the base raise (the original server's
    -- base value, its enchantments' and its buffs' added after)
    local perPoint, triedPerPoint = 1, 1
    if spec.rating then
        perPoint, triedPerPoint = ratingShare(spec.rating(channel)), ratingShare(spec.rating(channel), true)
    end
    local mode = spec.speed and select(5, movement()) or nil
    local t = { spec = spec, base = base, list = {}, flat = 0, whole = 1, ofBase = 0, open = false, shares = {},
        seen = {}, gear = gear, channel = channel, perPoint = perPoint, triedPerPoint = triedPerPoint, mode = mode,
        items = 0 }
    local list = t.list
    local parts = s.parts and s.parts(channel)
    -- (the game's base beside them, the attack powers': their level's rows, named after it, set below: levelPart)
    if parts and #parts > 0 then
        for _, p in ipairs(parts) do
            list[#list + 1] = { name = p.name, points = p.points, percent = p.percent == true, base = true,
                item = p.item, slot = p.slot, asks = p.asks, tip = p.tip, match = p.match }
        end
    end
    -- nothing changes it: what it stands on alone, its base where nothing is named of it (Ikar 2026-11-19: "defense
    -- has no source"), and what a set's next pieces would give. (An attribute is always tallied: a share of it may be
    -- in the game's base alone, nothing in its bonus, sourcesOf's end; the attack power too, for a share of an
    -- attribute, 598's.)
    local changes = full or not s.numbers or pos ~= 0 or neg ~= 0 or spec.scaledBase or spec.ofStat ~= nil
    if not changes and #list == 0 and base and base ~= 0 and not WOULD then
        for i, row in ipairs((baseRows(spec, base))) do
            list[i] = row
        end
    end
    if withNext and not changes then
        nextBonuses(t, wornSets())
    end
    if not changes then
        return #list > 0 and list or nil, channel
    end
    -- the auras first, so that a spell met as one isn't named again as a talent's or a passive's; not those of what is
    -- tried takes off (Tried.TakenOff)
    local auraList, off = {}, WOULD and Tried.TakenOff() or {}
    for _, filter in ipairs(FILTERS) do
        for i = 1, 255 do
            local aura = ns.Plain(C_UnitAuras.GetAuraDataByIndex("player", i, filter))
            if type(aura) ~= "table" then
                break
            end
            local spell = ns.Plain(aura.spellId)
            if not off[spell] then
                auraList[#auraList + 1] = aura
                if spell then
                    t.seen[spell] = true
                end
            end
        end
    end
    local sets, setOrder = {}, {}
    t.kind = "gear"
    for slot = FIRST_SLOT, LAST_SLOT do
        t.slot = slot
        local link = wornLink(slot)
        local stats = link and C_Item.GetItemStats(link)
        local v, unrated = 0, false
        if type(stats) == "table" then
            for _, key in ipairs(gearKeys) do
                local n = tonumber(stats[key])
                if n and n ~= 0 and not t.perPoint then
                    unrated = true
                elseif n then
                    v = v + n * t.perPoint
                end
            end
        end
        t.items = t.items + v
        -- a skill's, which the game's stats name not: the item's own line (itemLine)
        if link and spec.itemLine then
            v = v + (spec.itemLine(slot) or 0)
        end
        if link then
            -- one row an item: its stats, and its own spells while it's worn, its « Équipé : » lines, which the game's
            -- stats don't hold (Data/Effects.lua's ITEM_SPELLS; Ikar 2026-11-19: "They shoudl show"); one met as an
            -- aura left to the aura. A rating the game says nothing of: its row, without a figure
            local row = { name = itemName(link, slot), points = v ~= 0 and v or nil, kind = "gear", slot = slot,
                item = true, unsure = unrated or nil }
            if unrated then
                t.open = true
                row.why = string.format(L.STAT_WHY_RATING, nameOf(row.name))
            end
            t.flat = t.flat + v
            local id = tonumber(link:match("item:(%-?%d+)"))
            for spell in (id and ns.ITEM_SPELLS and ns.ITEM_SPELLS[id] or ""):gmatch("%d+") do
                spell = tonumber(spell)
                if not t.seen[spell] and needsMet(spell) then
                    addSpell(t, spell, row.name, ownPoints, row)
                end
            end
            if row.points or row.share or row.unsure then
                list[#list + 1] = row
            end
        end
        local enchant = link and tonumber(link:match("item:%-?%d+:(%d+)"))
        if enchant and enchant > 0 then
            addEnchant(t, enchant, enchanted(slot))
        end
        local _, _, set = itemKind(link or "")
        if link and type(set) == "number" and set > 0 then
            if not sets[set] then
                setOrder[#setOrder + 1] = set
            end
            sets[set] = (sets[set] or 0) + 1
        end
    end
    -- the quiver's or the ammunition pouch's own spells, in a bag's slot (its arrows' « Hâte », 557), the one tried in
    -- its place (Tried.Quiver; Ikar 2026-11-26, "fix the gaps"): one row, as an item's
    local quiver = Tried.Quiver()
    local quiverId = quiver and tonumber(quiver:match("item:(%-?%d+)"))
    if quiverId then
        t.slot = nil
        local row = { name = itemName(quiver, select(2, Tried.WornQuiver())), kind = "gear", item = true }
        for spell in (ns.ITEM_SPELLS and ns.ITEM_SPELLS[quiverId] or ""):gmatch("%d+") do
            spell = tonumber(spell)
            if not t.seen[spell] and needsMet(spell) then
                addSpell(t, spell, row.name, ownPoints, row)
            end
        end
        if row.points or row.share or row.unsure then
            list[#list + 1] = row
        end
    end
    -- the weapons' oils and stones, theirs for a while (the permanent ones are the items' links')
    for _, w in ipairs(WEAPONS) do
        t.slot = w[2]
        -- (not a weapon's that would be another: its oil is on the one held)
        local tried = WOULD and WOULD.links and WOULD.links[w[2]] ~= nil
        local enchants = C_Item and not tried and ns.Call(C_Item.GetWeaponEnchantInfo, w[1])
        for _, e in pairs(type(enchants) == "table" and enchants or {}) do
            local link = GetInventoryItemLink("player", w[2])
            if type(e) == "table" and e.hasEnchant and e.enchantType ~= PERMANENT and e.enchantID and link then
                addEnchant(t, e.enchantID, enchanted(w[2]))
            end
        end
    end
    -- each set's bonuses, from so many pieces worn (Data/Effects.lua's ITEM_SETS), in the game's « (2) Ensemble : »
    t.kind, t.slot = "set", nil
    for _, set in ipairs(setOrder) do
        local setName = C_Item and ns.Call(C_Item.GetItemSetInfo, set)
        for pieces, spell in (ns.ITEM_SETS and ns.ITEM_SETS[set] or ""):gmatch("(%d+):(%d+)") do
            pieces, spell = tonumber(pieces), tonumber(spell)
            if sets[set] >= pieces and not t.seen[spell] and needsMet(spell) then
                addSpell(t, spell, string.format(G("ITEM_SET_BONUS_GRAY", "(%d) Set: %s"), pieces,
                    type(setName) == "string" and setName or "?"), ownPoints)
            end
        end
    end
    if withNext then
        nextBonuses(t, sets, setOrder)
    end
    t.kind = nil
    for _, aura in ipairs(auraList) do
        local spell = ns.Plain(aura.spellId)
        if spell then
            local name = iconed(ns.Plain(aura.icon), ns.Plain(aura.name) or "?")
            -- (its row's tooltip the buff's own, with its time left; the camp's items' the camp's buff's, which names
            -- them all)
            t.tip = { aura = ns.Plain(aura.auraInstanceID), spell = spell }
            addSpell(t, spell, name, function(count, auras, index, place, fixed)
                return pointOf(aura, count, auras, index, place, fixed)
            end)
            -- the hidden auras its tooltip names (the camp's benefits): a row each, « Camp : » and the item's name with
            -- its icon (Ikar 2026-11-22: "camp: name of the item"), its figures the tooltip's, else the data's
            for _, part in ipairs(Stats.HiddenParts(aura) or {}) do
                if not t.seen[part.spell] then
                    t.seen[part.spell] = true
                    addSpell(t, part.spell, iconed(spellIcon(part.spell), string.format(L.STAT_CAMP_PART, part.name)),
                        function(count, auras, index, place, fixed)
                            return part.points[index] or ownPoints(count, auras, index, place, fixed)
                        end)
                end
            end
        end
    end
    t.tip = nil
    -- what would be drunk or eaten: its spells as auras more, unless they are on already. Their amounts are the
    -- game's data's, of a buff not had yet, given only where they are the buff's own whoever has it (make_effects.py's
    -- fixed: none that grows with a level, a class or a power; no buff's is random, its Variance 0): unmarked, an
    -- elixir's as a meal's (Ikar 2026-11-19, of an elixir's « +50 ? »: "and what is the questio namrk for here ?",
    -- then of the meals' kept marked: "never seen a random buff are you sure about that ?"); the game's question mark
    -- where the data gives no figure
    for _, spell in ipairs(WOULD and WOULD.uses or {}) do
        if not t.seen[spell] then
            addSpell(t, spell, iconed(WOULD.icon, WOULD.name), ownPoints)
        end
    end
    for _, talent in ipairs(talents()) do
        if not t.seen[talent.spell] and needsMet(talent.spell) then
            -- (its row's tooltip the talent's own, at its rank, as the talents' frame shows it)
            t.tip = { trait = talent.entryID, rank = talent.rank, spell = talent.spell }
            addSpell(t, talent.spell, iconed(spellIcon(talent.spell), talent.name) .. " ("
                .. string.format(G("TOOLTIP_TALENT_RANK", "Rank %d/%d"), talent.rank, talent.ranks) .. ")",
                function(_, _, index, _, fixed)
                    return talentValue(talent, index, fixed)
                end, nil, L.STAT_WHY_TALENT)
        end
    end
    t.tip = nil
    for _, spell in ipairs(knownPassives()) do
        if not t.seen[spell] and needsMet(spell) then
            addSpell(t, spell, iconed(spellIcon(spell), spellName(spell)) .. " " .. G("PASSIVE_PARENS", "(Passive)"),
                ownPoints)
        end
    end
    -- A value the game gives the base of (`numbers`): its base and its items' own stats, raised by the shares of the
    -- base, then its other flat changes and what's left, the whole by the shares of the whole (the original server's
    -- GetTotalStatValue: ((base + items) x base shares + the rest) x whole shares). The game's base is the value less
    -- what it calls its bonus, and an attribute's may hold its shares' part of it: the original server multiplies the
    -- bonus alone by a share of the whole (TrinityCore's UpdateStatBuffMod), and
    -- the base then holds Blessing of Kings' 10 % of it (the full review of 2026-11-20: a strength of 100 with an item's
    -- +10 and Kings showed « Base 110 » and « Autres -10 »). Which way this build splits it isn't known: the reading
    -- that leaves the less unexplained, the game's base as it is else. What each share comes to then; what's left,
    -- « Autres », none of a point either way beside a share (the game's rounding).
    if s.numbers then
        local items = t.items
        local function restOf(shown)
            return effective / t.whole - (shown + items) * (1 + t.ofBase) - (t.flat - items)
        end
        local shown = base
        if spec.scaledBase and (t.whole ~= 1 or t.ofBase ~= 0) then
            local scaled = (base / t.whole - items * t.ofBase) / (1 + t.ofBase)
            if math.abs(restOf(scaled)) < math.abs(restOf(base)) then
                shown = scaled
            end
        end
        -- The game's base, the attack power's (Ikar 2026-11-21: "you know the base ... The base shoudl now always
        -- match"): what the level and the class give (spec.levelPart, LEVEL_AP), the attributes' parts, and the shares
        -- of an attribute (598, Mental Dexterity's of the intellect: in the base, as Forever counts it, seen the same
        -- day). The level's part named after it (levelAP), no longer what's left; what the card can't account for of
        -- the game's base, « Erreur de l'addon » in red, to be reported ("add a addon mistake: and show the
        -- difference, to be reported, in red"). The bonus's rest stays « Autres ».
        if spec.levelPart and not WOULD then
            local inBase, named = t.ofStat or 0, 0
            shown = shown - inBase
            for i = #list, 1, -1 do
                local e = list[i]
                if e.ofStat then
                    e.base = true
                end
                if e.base and e.other then
                    table.remove(list, i)
                elseif e.base and not e.item and not e.percent and type(e.points) == "number" then
                    named = named + e.points
                end
            end
            local own, parts = spec.levelPart()
            local mistake = own and base - own - named or 0
            if own then
                -- (LEVEL_AP's own figures are no rest: « Base » below 0 stays itself, never « Erreur de l'add-on »;
                -- Ikar's druid, issue #5 of 2026-11-24: its -20 had read as a mistake, as every mage's, priest's and
                -- warlock's -10)
                for i = #parts, 1, -1 do
                    local row = baseRow(spec, parts[i].points)
                    row.name, row.measured = parts[i].name, true
                    table.insert(list, 1, row)
                end
            else
                own = floor(base - named + 0.5)
                if own ~= 0 then
                    table.insert(list, 1, baseRow(spec, own))
                end
            end
            if mistake >= 0.5 or mistake <= -0.5 then
                list[#list + 1] = { name = L.STAT_ADDON_ERROR, points = floor(mistake + 0.5), percent = false,
                    base = true, other = true, mistake = true }
            end
        end
        t.shownBase = shown
        for _, e in ipairs(list) do
            if e.baseShare then
                e.worth = (shown + items) * e.baseShare
            end
        end
        if #t.shares == 1 then
            t.shares[1].worth = (t.shares[1].worth or 0) + effective - effective / t.whole
        end
        if spec.scaledBase and not WOULD then
            local rows = baseRows(spec, floor(shown + 0.5))
            for i = #rows, 1, -1 do
                table.insert(list, 1, rows[i])
            end
        end
        if not t.open and not WOULD then
            local plain = t.whole == 1 and t.ofBase == 0
            local rest = floor(restOf(shown) + 0.5)
            if rest ~= 0 and (plain or rest > 1 or rest < -1) then
                list[#list + 1] = { name = L.STAT_OTHER, points = rest, other = true }
            end
        end
    end
    if spec.speed then
        speedOf(s, t)
    end
    -- a value the game gives no base of (`total`): what its named sources leave of it, so that its rows come to it
    -- (the review of 2026-11-19: a health of its stamina and gear alone, short of the class's and the level's). First,
    -- for one that has a base (health, mana, a chance), that base, named after where it comes from (baseRow: « Chaman »
    -- for the shaman's own 1.7 % of critical strike, Ikar 2026-11-21: "base et autres 1.7 ?", once « Base et
    -- autres »); « Autres » among its changes for one that has none (the hit, the haste, the armour).
    -- None while a source's points are unknown or a share can't be worked out, nor beside a source of some schools
    -- alone (a spell power is the least school's). A share of the whole (Blood Fury's of the spell power) raises all
    -- the rest: what's left of the whole without it, and what one such share comes to.
    if not s.numbers and s.total and not spec.multiplies and not t.open and (t.ofBase == 0 or spec.ofItems)
        and not WOULD then
        local total, named, partial = s.total(), t.flat, false
        -- (the items' own, which the shares of them raise: the armour's)
        local own = 0
        for _, e in ipairs(list) do
            if e.base and type(e.points) == "number" then
                named = named + e.points
                own = own + (e.item and e.points or 0)
            end
            partial = partial or e.schools ~= nil
        end
        for _, e in ipairs(list) do
            if e.baseShare then
                e.worth = own * e.baseShare
            end
        end
        named = named + own * t.ofBase
        if type(total) == "number" and #t.shares == 1 and not partial then
            t.shares[1].worth = (t.shares[1].worth or 0) + total - total / t.whole
        end
        local rest = type(total) == "number" and total / t.whole - named
        if rest and not partial
            and (spec.percent and (rest >= 0.05 or rest <= -0.05) or not spec.percent and floor(rest + 0.5) ~= 0) then
            rest = spec.percent and rest or floor(rest + 0.5)
            if spec.noBase then
                list[#list + 1] = { name = L.STAT_OTHER, points = rest, other = true, percent = spec.percent == true }
            else
                local rows, left = baseRows(spec, rest, spec.percent, true)
                for i = #rows, 1, -1 do
                    table.insert(list, 1, rows[i])
                end
                if left ~= 0 then
                    list[#list + 1] = { name = L.STAT_OTHER, points = left, other = true }
                end
            end
        end
    end
    for _, e in ipairs(list) do
        if e.percent == nil then
            e.percent = spec.percent and not e.other
        end
        -- What's left below 0, the card counting more than the game gives: the addon's own mistake most likely, in red
        -- with its question (Ikar 2026-11-22: "Autre should be Addon error with a question mark"), a base's as the
        -- attack power's is; what's left above 0 stays « Autres », a source the game may hide (the camp's). Both kept
        -- for the bug report (UI/Hub/Infos/StatCheck.lua; the same day: "ok, go, and add that to the error report").
        if e.other and not e.mistake and not e.measured and type(e.points) == "number" and e.points < 0 then
            e.name, e.mistake, e.why = L.STAT_ADDON_ERROR, true, not e.origin and L.STAT_ADDON_ERROR_LESS or nil
        end
    end
    return #list > 0 and list or nil, channel, t
end

local function signed(v, text)
    return Infos.Color((v > 0 and "+" or "") .. text, v > 0 and Infos.GOOD or Infos.BAD)
end

-- Points of a percent as the sheet writes a chance: whole, else to one decimal; below a tenth to two, which one would
-- have made 0.1 or 0 (a defence 2 points short of its most, -0.08 %).
local function percentText(v)
    if v == floor(v) then
        return Format.Percent(v / 100)
    end
    return Format.PercentOf(v, (v < 0.095 and v > -0.095) and 2 or 1)
end

-- Each source a line: its name (an item in its quality's colour, what's left grey), how much on the right; what the
-- value stands on unsigned, as a sum's terms, its changes signed.
-- A figure the game doesn't give, or that nothing has checked yet (Ikar 2026-11-19: "Put questio nmark icon to the
-- characteristic currently unknown, no lying"): the game's own question mark in its place or after it, never a blank
-- nor a figure passed off as sure; the card's foot says what the mark means.
-- The ready check's « waiting » mark, the game's own for what isn't known yet (Ikar 2026-11-19, of the map's
-- QuestionMarkContinent-Icon, a 20 by 27 marker drawn square: "she is ugly, isn't there a betetr one ?"): square,
-- and drawn at 200 points, clean at 14.
local UNKNOWN = "|A:UI-LFG-PendingMark:14:14|a"
Stats.UNKNOWN = UNKNOWN
-- The questions of the card or the tooltip being made, each once, in the order met: the mark stands only where the
-- game leaves one open, and the foot says each, what it asks and what to go by, in place of one sentence for all (Ikar
-- 2026-11-19: "questio nmark shoudl be present only when there is a question. And the description should give an
-- answer"). Nil but while one is made.
local questions
local function ask(why)
    if questions and why and not questions[why] then
        questions[why] = true
        questions[#questions + 1] = why
    end
    return UNKNOWN
end

local function rightOf(e)
    local right = {}
    -- a speed's raise the strongest of its kind leaves out (speedOf)
    if e.idle then
        return Infos.Color(L.STAT_NOT_STACKING, "ff808080")
    end
    -- a source named without what it gives: a buff growing with its caster's level, an enchantment following the
    -- item's, a talent the data has no value of
    if e.points == nil and e.share == nil and e.keep == nil and not e.base then
        return ask(e.why)
    end
    if e.base then
        right[1] = e.percent and percentText(e.points) or number(e.points)
    elseif e.points and e.points ~= 0 then
        right[#right + 1] = signed(e.points, e.percent and percentText(e.points) or number(e.points))
    end
    if e.share and e.share ~= 0 then
        right[#right + 1] = signed(e.share, Format.Percent(e.share))
        local worth = e.worth and floor(e.worth + 0.5)
        if worth and worth ~= 0 then
            right[#right + 1] = "(" .. signed(worth, number(worth)) .. ")"
        end
    end
    -- known in part (one of a spell's effects, an enchantment's stats, without an amount): the figure isn't the whole
    -- of it, and wears the mark too (the review of 2026-11-19); what's left below 0, the addon's mistake, its question;
    -- a base the card works out from what the game doesn't give (`asks`: baseRows)
    if e.unsure or (e.mistake and e.why) then
        right[#right + 1] = ask(e.why)
    elseif e.asks then
        right[#right + 1] = ask(e.asks)
    end
    return table.concat(right, " ")
end
-- A row's figure without its colours, for a row that is grey whole.
local function bare(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
-- In a tooltip itself, after its lines (a skill's); under them, what each mark asks.
local function showSources(tooltip, s)
    questions = {}
    for _, e in ipairs(sourcesOf(s) or {}) do
        -- (the addon's mistake in the card's red, MISTAKE's)
        local color = e.mistake and { 1, 0.125, 0.125 } or e.other and not e.origin and Infos.GREY or Infos.WHITE
        tooltip:AddDoubleLine(e.name, rightOf(e), color[1], color[2], color[3], 1, 1, 1)
    end
    local asked = questions
    questions = nil
    for _, why in ipairs(asked) do
        Infos.Hint(tooltip, UNKNOWN .. " " .. why)
    end
end
local brokenSources, brokenTexts = {}, {}

-- ---------- What a value is and what it gives: the sheet's own words ----------
-- (Ikar 2026-11-19: "can you show, separatly, not only the source for each, but what each provide ?") The game's
-- sheet has a text for each value, in the player's language and the class's own where there's one, with its figures
-- in: what it gives (« Augmente la puissance d'attaque de 220 »), what it is, and notes in grey. Each is built here
-- as the sheet builds it (Camelot's PaperDollFrame.lua and PaperDollFrameStats.lua, their figures worked out the
-- same way), then cut in three (cut) for the tooltip's panels. (RANGED_CLASS: with LEVEL_AP, above)
-- (POWER_PER_DAMAGE, PERCENT_PER_DEFENSE, STRENGTH_PER_BLOCK: with ARMOR_PER_AGILITY, above)

local function classFile()
    local _, file = UnitClass("player")
    return type(file) == "string" and file or ""
end
local function level()
    return UnitLevel("player") or 0
end

-- One of the game's texts with its figures in; nil when the game has it not, or a figure is hidden or missing.
local function say(text, ...)
    if type(text) ~= "string" then
        return nil
    end
    local ok, out = pcall(string.format, text, ...)
    return ok and out or nil
end

-- An attribute's, the class's own text else the default one (PaperDollFrame_SetStatTooltip2).
local function attributeText(i)
    local key, file = ATTRIBUTE_KEYS[i], classFile()
    local text = G(file .. "_" .. key .. "_TOOLTIP") or G("DEFAULT_" .. key .. "_TOOLTIP")
    local v = attribute(i)
    if not (text and v) then
        return nil
    end
    local plain = file == "WARRIOR" or file == "ROGUE"
    if i == 1 then
        return say(text, ns.Plain(GetAttackPowerForStat(1, v)), floor(v / STRENGTH_PER_BLOCK))
    elseif i == 3 then
        local first, per = STAMINA_BREAK or 20, ns.Plain(UnitHPPerStamina("player"))
        return per and say(text, tostring(min(first, v) + (max(first, v) - first) * per))
    elseif i == 4 then
        local crit = ns.Plain(GetSpellCritChanceFromStat(4, v))
        if not crit then
            return nil
        elseif plain then
            return say(text, crit * 100)
        end
        local first = INTELLECT_BREAK or 20
        return say(text, min(first, v) + (max(first, v) - first) * (MANA_PER_INTELLECT or 15), crit * 100)
    elseif i == 5 then
        -- standing, as the sheet takes it: three quarters of the spirit's health
        local health, manaOf = ns.Plain(GetHealthRegenFromSpirit()), ns.Plain(GetManaRegenFromSpirit())
        local all, manaAll = ns.Plain(GetHealthRegen()), ns.Plain(GetManaRegen())
        if not (health and manaOf and all and manaAll) then
            return nil
        end
        health = health * 0.75
        local out = plain and say(text, health * 5, all * 5) or say(text, health * 5, manaOf * 5, all * 5, manaAll * 5)
        local warning = G("SPIRIT_STANDING_WARNING")
        return out and warning and (out .. "\n\n" .. warning) or out
    end
    local dodge, crit = ns.Plain(GetDodgeChanceFromAttribute()), ns.Plain(GetCritChanceFromStat(2, v))
    local power, ranged = ns.Plain(GetAttackPowerForStat(2, v)), ns.Plain(GetRangedAttackPowerForStat(2, v))
    if not (dodge and crit) then
        return nil
    end
    dodge, crit = dodge * 100, crit * 100
    local armor = v * ARMOR_PER_AGILITY
    if file == "ROGUE" or file == "HUNTER" then
        return say(text, crit, power, ranged, armor, dodge)
    elseif file == "DRUID" then
        return say(text, crit, v, armor, dodge)
    elseif file == "WARRIOR" then
        return say(text, crit, ranged, armor, dodge)
    end
    return say(text, crit, armor, dodge)
end

-- An attack power's: the damage a second it adds to its weapons, two decimals as the sheet's.
local function powerText(text, base, pos, neg)
    if not base or ns.Plain(GetOverrideAPBySpellPower()) ~= 0 then
        return nil
    end
    return say(text, Format.Decimal(max(0, base + (pos or 0) + (neg or 0)) / POWER_PER_DAMAGE, 2))
end

-- Each value's texts as the sheet's tooltip lists them, in its order; `true` after for those that only say what the
-- value is (no figure of an effect in them).
local TEXTS = {
    HEALTH = function()
        return { G("STAT_HEALTH_TOOLTIP") }, true
    end,
    POWER = function()
        local _, token = UnitPowerType("player")
        return { type(token) == "string" and G("STAT_" .. token .. "_TOOLTIP") or nil }, true
    end,
    ATTACK_AP = function()
        return { powerText(G(classFile() .. "_MELEE_ATTACK_POWER_TOOLTIP") or G("MELEE_ATTACK_POWER_TOOLTIP"),
            ns.Plain(UnitAttackPower("player"))) }
    end,
    RANGED_ATTACK_AP = function()
        return { powerText(G("RANGED_ATTACK_POWER_TOOLTIP"), ns.Plain(UnitRangedAttackPower("player"))) }
    end,
    -- each kind of attack's, then what it takes never to miss (CharacterHitFrame_OnEnter)
    HITCHANCE = function()
        local melee, ranged, spell, main, off = hitBy()
        local list, file = {}, classFile()
        if not melee then
            return list
        end
        list[#list + 1] = main > 0 and say(G("CR_HIT_MELEE_TOOLTIP"), main) or nil
        list[#list + 1] = off ~= main and ns.Call(IsDualWielding) and say(G("CR_HIT_OFFHAND_TOOLTIP"), off) or nil
        list[#list + 1] = ranged > 0 and RANGED_CLASS[file] and say(G("CR_HIT_RANGED_TOOLTIP"), ranged) or nil
        list[#list + 1] = spell > 0 and say(G("CR_HIT_SPELL_TOOLTIP"), spell) or nil
        list[#list + 1] = say(G("CR_" .. file .. "_HIT_CAP_TOOLTIP") or G("CR_DEFAULT_HIT_CAP_TOOLTIP"), level())
        return list
    end,
    CRITCHANCE = function()
        local melee, ranged, spell = critBy()
        local list, file = {}, classFile()
        if not (melee and ranged and spell) then
            return list
        end
        list[#list + 1] = say(G("STAT_CRIT_MELEE"), melee)
        list[#list + 1] = RANGED_CLASS[file] and say(G("STAT_CRIT_RANGED"), ranged) or nil
        list[#list + 1] = say(G("STAT_CRIT_SPELL"), spell)
        list[#list + 1] = say(G("STAT_" .. file .. "_CRIT_BONUS") or G("STAT_CRIT_BONUS"))
        return list
    end,
    -- what it is first, in the game's words (Ikar 2026-11-19: "haste has no description"): its strings' own, the
    -- attacks' and the spells' for a class with mana, the attacks' alone else; not the classes' own, Mainline's
    -- (a hunter's focus, a rogue's energy, which haste doesn't touch here)
    HASTE = function()
        local melee, ranged, spell = hasteBy()
        local list = { hasMana() and G("STAT_HASTE_TOOLTIP") or G("STAT_HASTE_MELEE_TOOLTIP") }
        if not (melee and ranged and spell) then
            return list
        end
        list[#list + 1] = melee > 0 and say(G("CR_HASTE_MELEE_TOOLTIP"), melee) or nil
        list[#list + 1] = ranged > 0 and RANGED_CLASS[classFile()] and say(G("CR_HASTE_RANGED_TOOLTIP"), ranged) or nil
        list[#list + 1] = spell > 0 and say(G("CR_HASTE_SPELL_TOOLTIP"), spell) or nil
        return list
    end,
    -- the sheet's own text there: the ranged one's, whatever the weapon (its PaperDollFrame_ExpertiseOnEnter asks a
    -- `category` nothing sets)
    EXPERTISE = function()
        local main, off = ns.Plain(GetExpertise())
        if type(main) ~= "number" then
            return {}
        end
        local shown = percent(main) .. ((ns.Call(IsDualWielding) and type(off) == "number") and (" / " .. percent(off)) or "")
        return { say(G("CR_RANGED_EXPERTISE_TOOLTIP"), shown) }
    end,
    -- its first sentence, what it gives; its second, what there is to know (below 0, more damage), under
    -- RATIOS.ARMORPEN: a digit in it (« sous 0 ») would have put it with the first
    ARMORPEN = function()
        local text = say(G("ARMOR_PENETRATION_TOOLTIP"), ns.Plain(GetArmorPenetration()))
        return { text and (text:match("^(.-%.)%s") or text) }
    end,
    SPELLHEALING = function()
        return { say(G("STAT_SPELLHEALING_TOOLTIP"), ns.Plain(GetSpellBonusHealing())) }
    end,
    -- at 0 too; its « per point », a point's share of an average resistance in percent (the sheet's own puts the
    -- penetration's whole there as a fraction, 0.0 % at most values: PaperDollFrame_SetSpellPenetration)
    SPELLPENETRATION = function()
        local v, lvl = ns.Plain(GetSpellPenetration()), level()
        if not v or lvl <= 0 then
            return {}
        end
        local average = 75 / (lvl * 5)
        return { say(G("SPELL_PENETRATION_TOOLTIP"), v, average, average / 2) }
    end,
    REGEN = function()
        if hasMana() then
            -- (its « toutes les 5 secondes » not beside a second's figures: the option's, the card's tip saying it)
            local base = ns.Plain(GetManaRegen())
            return { base and not Stats.PerSecond() and say(G("MANA_REGEN_TOOLTIP"), number(floor(base * 5))) or nil },
                true
        end
        local _, token = UnitPowerType("player")
        return { (token == "ENERGY" or token == "FOCUS") and G("STAT_" .. token .. "_REGEN_TOOLTIP") or nil }, true
    end,
    -- what it has past the level's most, a share of a percent a point (PaperDollFrame_SetDefense)
    DEFENSE = function()
        local base, mod = ns.Plain(UnitDefenseSkill("player"))
        if not base then
            return {}
        end
        local share = max(max(0, base + (mod or 0)) - level() * 5, 0) * PERCENT_PER_DEFENSE
        return { say(G("DEFAULT_STATDEFENSE_TOOLTIP"), share, share) }
    end,
    DODGE = function()
        return { say(G("CR_DODGE_BASE_STAT_TOOLTIP"), ns.Plain(GetDodgeChance())) }
    end,
    PARRY = function()
        return { say(G("CR_PARRY_BASE_STAT_TOOLTIP"), ns.Plain(GetParryChance())) }
    end,
    BLOCK = function()
        return { say(G("STAT_BLOCK_VALUE_FLAT_TOOLTIP"), ns.Plain(GetBlockChance()), ns.Plain(GetShieldBlock())) }
    end,
    -- the block value's own part of the block's text, from the paragraph of its figure on (the chance's before it): the
    -- paragraph found with a figure no value has, the text then made with the real ones
    BLOCKVALUE = function()
        local text, value = G("STAT_BLOCK_VALUE_FLAT_TOOLTIP"), ns.Plain(GetShieldBlock())
        local chance = ns.Plain(GetBlockChance()) or 0
        local probe, real = say(text, chance, 987654), value and say(text, chance, value)
        if not (probe and real) then
            return {}
        end
        local function paragraphs(s)
            local list = {}
            for para in (s .. "\n\n"):gmatch("(.-)\n\n") do
                list[#list + 1] = para
            end
            return list
        end
        local at, out = nil, {}
        for i, para in ipairs(paragraphs(probe)) do
            at = at or (para:find("987654", 1, true) and i or nil)
        end
        for i, para in ipairs(paragraphs(real)) do
            if i >= (at or 1) then
                out[#out + 1] = para
            end
        end
        return { table.concat(out, "\n\n") }
    end,
    -- against one of the character's level, then against its target, then the most it can be (PaperDollFrame_SetArmor)
    ARMOR = function()
        local _, effective = ns.Plain(UnitArmor("player"))
        local list = {}
        if not effective or not C_PaperDollInfo then
            return list
        end
        local share = ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectiveness, effective, UnitEffectiveLevel("player")))
        list[#list + 1] = share and say(G("STAT_ARMOR_TOOLTIP"), share * 100) or nil
        local target = ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectivenessAgainstTarget, effective))
        list[#list + 1] = target and say(G("STAT_ARMOR_TARGET_TOOLTIP"), target * 100) or nil
        list[#list + 1] = say(G("ARMOR_MAX_EFFECTIVENESS_TOOLTIP"))
        return list
    end,
}
-- The original game's table of each race's and class's base attributes by level (Ikar 2026-11-23: "what each level
-- give ?", "crawl the internet, download all stat for each class, for each race, level by level", "go";
-- Data/BaseStats.lua; a pair it hasn't, a dwarf shaman, its class's row of the first race that has one, less that
-- race's offset, plus its own), which splits an attribute's base (baseRows). No line of what a level gave or what the
-- next will (Ikar 2026-11-23: "you still kept the Level 26 in the main state note (+1) etc, unecessary. Remove
-- thoses"), nor anything kept at a level-up for them.
do
    local rows = {}
    local function parse(text, shift)
        local levels = {}
        for part in text:gmatch("[^;]+") do
            local v = {}
            for n in part:gmatch("%-?%d+") do
                v[#v + 1] = tonumber(n) + (shift and shift[#v + 1] or 0)
            end
            levels[#levels + 1] = v
        end
        return levels
    end
    -- the character's table, by level, each its five attributes: its class's row plus its race's offset, by the race's
    -- ID (the two Skyborne share one token); nil for a race or class the table hasn't
    local function tableOf()
        local _, _, raceID = UnitRace("player")
        local _, file = UnitClass("player")
        local data = ns.BASE_STATS
        if not raceID or not file or not data then
            return nil
        end
        local key = raceID .. " " .. file
        if rows[key] == nil then
            local own, text = data.offsets[raceID], data.classes[file]
            rows[key] = own and text and parse(text, own) or false
        end
        return rows[key] or nil
    end
    -- An attribute's base at the character's level split by what makes it, from the table: the race's (20, a human's,
    -- and its offset), what the class adds at level 1, what levels 2 to this one have given, and their sum; `read`, a
    -- race offset read from Forever's sheets (the Skyborne's), not the original game's; nil without a table (Ikar
    -- 2026-11-23: "why now that you have the table can't you split to race, class and level ?").
    function Stats.BaseSplit(i)
        local t, level = tableOf(), ns.Plain(UnitLevel("player"))
        local _, _, raceID = UnitRace("player")
        local own = t and ns.BASE_STATS.offsets[raceID]
        if not (own and type(level) == "number" and t[level]) then
            return nil
        end
        local race = 20 + own[i]
        return { race = race, class = t[1][i] - race, levels = t[level][i] - t[1][i], total = t[level][i], level = level,
            read = ns.BASE_STATS.read[raceID] }
    end
end
for i, key in ipairs(ATTRIBUTE_KEYS) do
    TEXTS[key] = function()
        return { attributeText(i) }
    end
end
-- the defence's column's four: what each is, against an enemy of the character's level; the healing taken's two
for _, key in ipairs({ "ARMORCUT", "MISSED", "AVOIDANCE", "CRITTAKEN", "HEALDONE", "HEALTAKEN", "HEALTAKEN_FLAT" }) do
    TEXTS[key] = function()
        return { L["STAT_" .. key .. "_TIP"] }
    end
end
for _, s in ipairs(LIST) do
    s.texts = TEXTS[s.key]
    -- a resistance's: what it resists, and the average against one of the character's level
    -- (PaperDollFrame_SetResistanceTooltips, ExpectedSpellResistance)
    if s.school then
        s.texts = function()
            local _, _, effective = ns.Plain(UnitResistance("player", s.school))
            local lvl = level()
            if not effective or lvl <= 0 then
                return {}
            end
            return { say(G("RESISTANCE_TOOLTIP_SUBTEXT"), G("RESISTANCE_TYPE" .. s.school, ""), lvl,
                floor(0.75 * effective / (lvl * 5) * 100)) }
        end
    end
    -- a school's spell power: the sheet's text with its figure, and a warlock's pet's share of it on the school the
    -- sheet takes it from (CharacterSpellBonusDamage_OnEnter, WARLOCK_PET_BONUS: the shadow's or the fire's, the
    -- higher, or the least's when neither is above it, on both; the review of 2026-11-21: the card had none), its grey
    -- making it a note
    if s.spellSchool then
        s.texts = function()
            local by = {}
            for _, school in ipairs(SCHOOLS) do
                by[school] = ns.Plain(GetSpellBonusDamage(school))
                if type(by[school]) ~= "number" then
                    return {}
                end
            end
            local list = { say(G("STAT_SPELLPOWER_TOOLTIP"), by[s.spellSchool]) }
            if classFile() == "WARLOCK" and (s.spellSchool == 3 or s.spellSchool == 6) then
                local low = lowestSpell(function(school) return by[school] end)
                local key, damage, from = "PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG", low, s.spellSchool
                if not (by[6] == low and by[3] == low) then
                    from = by[6] > by[3] and 6 or 3
                    key = key .. (from == 6 and "_SHADOW" or "_FIRE")
                    damage = by[from]
                end
                local share = type(WARLOCK_PET_BONUS) == "table" and WARLOCK_PET_BONUS or {}
                local ap = floor(damage * (share.PET_BONUS_SPELLDMG_TO_AP or 0.17))
                local spells = floor(damage * (share.PET_BONUS_SPELLDMG_TO_SPELLDMG or 0.1))
                local text = from == s.spellSchool and (ap > 0 or spells > 0) and say(G(key), ap, spells)
                list[#list + 1] = text and text:gsub("^(|c%x%x%x%x%x%x%x%x)\n", "%1") or nil
            end
            return list
        end
    end
end

-- One of the sheet's texts cut in three: what the value gives (its paragraphs with a figure), what it is (the others),
-- and its notes, from the first paragraph holding the notes' grey on, kept whole (a grey run may span several). The
-- grey anywhere in it, not at its start alone: in English, German and Spanish a raid boss's figures open on its name
-- in red (« Raid Boss chance to: »), and went under what the value gives (the review of 2026-11-19).
local NOTE = "|[cC][fF][fF][bB][cC][bB][cC][bB][cC]"
local function cut(text, into)
    -- (Forever's French sheet ends some paragraphs on the next one's first letter, « d'un maximum de %d\n\n.Augmenté
    -- par… », the spell power's and the healing's: each such full stop put back at the end of the line before it, past
    -- the colour code opening the next; an ellipsis left as it is. Ikar 2026-11-23: "some lines start with a '.'")
    local rest = text:gsub("\n(\n?)(|c%x%x%x%x%x%x%x%x)%.([^%.])", ".\n%1%2%3"):gsub("\n(\n?)%.([^%.])", ".\n%1%2")
    while rest and rest ~= "" do
        local para, after = rest:match("^(.-)\n\n(.*)$")
        if (para or rest):find(NOTE) then
            into.notes[#into.notes + 1] = (rest:gsub("^%s+", ""))
            return
        end
        para = (para or rest):gsub("^%s+", "")
        if para ~= "" then
            -- a figure, the colours' and the grammar's codes aside (|cff20ff20, French's |2), line by line: a line
            -- without one inside a paragraph with some is something to know, and was lost with it where figures
            -- stand for the sentences (a caster's intellect and the weapon skill's rate; Ikar 2026-11-19: "go")
            local lines = { gives = {}, is = {} }
            for line in para:gmatch("[^\n]+") do
                local bare = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|%d", "")
                local kind = bare:find("%d") and "gives" or "is"
                lines[kind][#lines[kind] + 1] = line
            end
            for _, kind in ipairs({ "gives", "is" }) do
                if #lines[kind] > 0 then
                    into[kind][#into[kind] + 1] = table.concat(lines[kind], "\n")
                end
            end
        end
        rest = after
    end
end

-- ---------- The card (Ikar 2026-11-19: "Go with card 1") ----------
-- What the attributes' card shows on hover (UI/Hub/Infos/StatCard.lua draws it), in place of a tooltip: under the name
-- and the value, where the value comes from, what there is to know of it, what it gives.
local CHANNEL_WORDS = { m = { "MELEE", "Melee" }, r = { "RANGED", "Ranged" }, s = { "SPELLS", "Spells" } }

-- What a value gives, as figures, where each is a figure of something the game has a name for: an attribute's share
-- of the values it feeds (the sheet's own sums, as PARTS'), an attack power's damage a second, the armour's share of
-- the blows. The others keep the sheet's sentences.
local function tile(list, figure, caption)
    if figure and caption then
        list[#list + 1] = { figure = figure, caption = caption }
    end
end
local function whole(v)
    return type(v) == "number" and floor(v + 0.5) ~= 0 and ("+" .. number(v)) or nil
end
local function chance(v)
    return type(v) == "number" and v >= 0.05 and ("+" .. percent(v)) or nil
end
local function perSecond(kind, base, pos, neg)
    local list = {}
    if base and ns.Plain(GetOverrideAPBySpellPower()) == 0 then
        local v = max(0, base + (pos or 0) + (neg or 0)) / POWER_PER_DAMAGE
        tile(list, v >= 0.05 and ("+" .. Format.Decimal(v, 1)) or nil,
            G("DAMAGE_PER_SECOND", "Damage per second") .. " (" .. G(kind[1], kind[2]) .. ")")
    end
    return list
end
local GIVES = {
    STRENGTH = function()
        local list, v = {}, attribute(1)
        if v then
            tile(list, whole(ns.Plain(GetAttackPowerForStat(1, v))), G("STAT_ATTACK_POWER", "Attack Power"))
            -- block value too for the classes the sheet has a text of their own for
            if G(classFile() .. "_STRENGTH_TOOLTIP") then
                tile(list, whole(floor(v / STRENGTH_PER_BLOCK)), G("ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value"))
            end
        end
        return list
    end,
    AGILITY = function()
        local list, v = {}, attribute(2)
        if v then
            local crit, dodge = ns.Plain(GetCritChanceFromStat(2, v)), Tried.DodgeFromAgility()
            tile(list, chance(crit and crit * 100), G("STAT_CRITICAL_STRIKE", "Critical Strike"))
            tile(list, chance(dodge and dodge * 100), G("STAT_DODGE", "Dodge"))
            tile(list, whole(v * ARMOR_PER_AGILITY), G("STAT_ARMOR", "Armor"))
            tile(list, whole(ns.Plain(GetAttackPowerForStat(2, v))), G("STAT_ATTACK_POWER", "Attack Power"))
            tile(list, whole(ns.Plain(GetRangedAttackPowerForStat(2, v))), G("RANGED_ATTACK_POWER", "Ranged Attack Power"))
        end
        return list
    end,
    STAMINA = function()
        local list, v, per = {}, attribute(3), ns.Plain(UnitHPPerStamina("player"))
        if v and per then
            local first = STAMINA_BREAK or 20
            tile(list, whole(min(first, v) + max(0, v - first) * per), G("HEALTH", "Health"))
        end
        return list
    end,
    INTELLECT = function()
        local list, v = {}, attribute(4)
        if v then
            if hasMana() then
                local first = INTELLECT_BREAK or 20
                tile(list, whole(min(first, v) + max(0, v - first) * (MANA_PER_INTELLECT or 15)), G("MANA", "Mana"))
            end
            local crit = ns.Plain(GetSpellCritChanceFromStat(4, v))
            tile(list, chance(crit and crit * 100),
                G("STAT_CRITICAL_STRIKE", "Critical Strike") .. " (" .. G("SPELLS", "Spells") .. ")")
        end
        return list
    end,
    -- standing, as the sheet takes it: three quarters of the spirit's health; what the spirit tried would give of it an
    -- estimate, the game's question after it (Tried.HealthFromSpirit; alone for a class the original server hasn't),
    -- the mana's followed (Tried.ManaFromSpirit)
    SPIRIT = function()
        local list = {}
        -- both figures stand on the spirit, the mana's or not: a change of it that can't be said is their question
        -- (the review of 2026-11-26: a class without mana had its health said as it is under such a buff)
        if Tried.leaned then
            Tried.leaned[5] = true
        end
        local health = Tried.HealthFromSpirit()
        local caption = G("ITEM_MOD_HEALTH_REGEN_SHORT", "Health per 5 sec.")
        -- (cut to a whole as the sheet's « %d » writes them, the regenerations' cards the same)
        local figure, guess = whole(health and floor(health * 0.75 * 5 + 1e-6)), Tried.SpiritGuess(WOULD)
        if guess == "unknown" or (guess and not figure) then
            figure = ask(L.STAT_WHY_SPIRIT)
        elseif guess then
            figure = figure .. " " .. ask(L.STAT_WHY_SPIRIT)
        end
        tile(list, figure, caption)
        if hasMana() then
            local manaOf = Tried.ManaFromSpirit()
            tile(list, whole(manaOf and floor(manaOf * 5 + 1e-6)), G("MANA_REGEN", "Mana Regen"))
        end
        return list
    end,
    -- (what is tried's change of the value with it while what would be is read: Tried.Change, the card kept open's
    -- effects, Tried.Effects; the same in all of these)
    ATTACK_AP = function()
        local base, pos, neg = ns.Plain(UnitAttackPower("player"))
        return perSecond(CHANNEL_WORDS.m, base and base + Tried.Change("ATTACK_AP"), pos, neg)
    end,
    RANGED_ATTACK_AP = function()
        local base, pos, neg = ns.Plain(UnitRangedAttackPower("player"))
        return perSecond(CHANNEL_WORDS.r, base and base + Tried.Change("RANGED_ATTACK_AP"), pos, neg)
    end,
    ARMOR = function()
        local list = {}
        local _, effective = ns.Plain(UnitArmor("player"))
        effective = effective and max(0, effective + Tried.Change("ARMOR"))
        if effective and C_PaperDollInfo then
            local taken = ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectiveness, effective, UnitEffectiveLevel("player")))
            tile(list, taken and Format.PercentOf(taken * 100, 2), L.STAT_GIVES_PHYSICAL)
            local target = ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectivenessAgainstTarget, effective))
            tile(list, target and Format.PercentOf(target * 100, 2), L.STAT_GIVES_TARGET)
        end
        return list
    end,
}
-- The hit chance, the critical strike and the haste: each kind of attack's, under the game's word for it (the ranged
-- one's for the classes the sheet shows it to); none of a kind at 0.
local function byKind(m, r, s)
    local list = {}
    if m and r and s then
        tile(list, m ~= 0 and percent(m) or nil, G("MELEE", "Melee"))
        tile(list, r ~= 0 and RANGED_CLASS[classFile()] and percent(r) or nil, G("RANGED", "Ranged"))
        tile(list, s ~= 0 and percent(s) or nil, G("SPELLS", "Spells"))
    end
    return list
end
-- Each kind's with what is tried's change on it (Tried.Change, that kind's sources read).
function Tried.ByKind(key, m, r, s)
    local function with(v, channel)
        return type(v) == "number" and v + Tried.Change(key, channel) or v
    end
    return byKind(with(m, "m"), with(r, "r"), with(s, "s"))
end
GIVES.HITCHANCE = function()
    return Tried.ByKind("HITCHANCE", hitBy())
end
GIVES.CRITCHANCE = function()
    return Tried.ByKind("CRITCHANCE", critBy())
end
GIVES.HASTE = function()
    return Tried.ByKind("HASTE", hasteBy())
end
-- what a block takes off a blow: on the block's card, and the block value's own
GIVES.BLOCKVALUE = function()
    local list, v = {}, ns.Plain(GetShieldBlock())
    v = type(v) == "number" and v + Tried.Change("BLOCKVALUE") or v
    tile(list, type(v) == "number" and v > 0 and ("-" .. number(v)) or nil, L.STAT_GIVES_BLOCKED)
    return list
end
GIVES.BLOCK = function()
    local list, v = {}, ns.Plain(GetShieldBlock())
    v = type(v) == "number" and v + Tried.Change("BLOCKVALUE") or v
    tile(list, type(v) == "number" and v > 0 and number(v) or nil, G("ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value"))
    return list
end
-- what it has past the level's most, or lacks of it, against an enemy of the character's level (its weapon skill
-- five a level): as much more, or less, to dodge, parry and block, as much less, or more, to be hit, 0.04 % a point
-- either way: this build's own sums (PaperDollFrameStats.lua's GetEnemyChanceToMiss and GetEnemyCritChance, which its
-- sheet doesn't call) and the original server's, which adds it to the dodge, parry and block it shows (their
-- cards name it, defensePart). Always as figures: the sheet's sum stops at 0
-- below the most, and its sentence then said « 0.00% » (Ikar's screenshot of 2026-11-20, at 113 / 115: 0.08 % less,
-- 0.08 % more to be hit)
GIVES.DEFENSE = function()
    local list = {}
    local have = Tried.Defense()
    if have then
        local share = (have - level() * 5) * PERCENT_PER_DEFENSE
        local function signedPercent(v)
            return (v > 0.004 and "+" or v < -0.004 and "-" or "") .. Format.PercentOf(math.abs(v), 2)
        end
        tile(list, signedPercent(share),
            G("STAT_DODGE", "Dodge") .. ", " .. G("STAT_PARRY", "Parry") .. ", " .. G("STAT_BLOCK", "Block"))
        tile(list, signedPercent(-share), L.STAT_GIVES_HIT)
    end
    return list
end
-- ---------- What a point gives (Ikar 2026-11-19: "would be nice to augmenter par to show the ratio") ----------
-- Under the sheet's « Augmenté par » words, what a point of each attribute it names gives of the value, at the value
-- now, as the game's own calls work it out: the same call a hundred points further (the first points of stamina and
-- intellect give less; a chance's share of agility changes with the level); defence's past the level's most. A share
-- below 1 a point said as the points that take 1. A weapon's speed and its damage a second with it (the sheet's
-- damage tooltip, CharacterDamageFrame_OnEnter): every value has something to know (Ikar: "some characteristic don't
-- have info part").
local RATIOS = {}
do
    local STEP = 100
    local function white(text)
        return Infos.Color(text, "ffffffff")
    end
    local function short(v)
        if v >= 100 or math.abs(v - floor(v + 0.5)) < 0.05 then
            return number(v)
        end
        return Format.Decimal(v, v < 1 and 2 or 1)
    end
    -- One line: `name`'s point gives `per` of `what` (a percent's points with opts.percent), its points for 1 below
    -- 1 a point unless opts.point; after its first opts.after points, or either side of opts.around.
    local function ratio(lines, name, per, what, opts)
        opts = opts or {}
        if type(per) ~= "number" or per <= 0.0001 then
            return
        end
        local line
        if per < 1 and not opts.point then
            line = string.format(L.STAT_RATIO_POINTS, name,
                white(opts.percent and Format.Percent(0.01) or "1") .. " " .. what, white(short(1 / per)))
        else
            line = string.format(L.STAT_RATIO_POINT, name,
                white(opts.percent and Format.PercentOf(per, per < 1 and 2 or 1) or short(per)) .. " " .. what)
        end
        if opts.after then
            line = string.format(L.STAT_RATIO_AFTER, line, opts.after)
        elseif opts.around then
            line = string.format(L.STAT_RATIO_AROUND, line, number(opts.around))
        end
        lines[#lines + 1] = line
    end
    local function slope(read, v)
        if type(v) ~= "number" then
            return nil
        end
        local a, b = read(v), read(v + STEP)
        if type(a) == "number" and type(b) == "number" then
            return (b - a) / STEP
        end
    end
    local function statName(i)
        return G("SPELL_STAT" .. i .. "_NAME", ATTRIBUTE_KEYS[i])
    end
    local function power(i, lines, ranged)
        local function read(x)
            if ranged then
                return ns.Plain(GetRangedAttackPowerForStat(i, x))
            end
            return ns.Plain(GetAttackPowerForStat(i, x))
        end
        ratio(lines, statName(i), slope(read, attribute(i)),
            ranged and G("RANGED_ATTACK_POWER", "Ranged Attack Power") or G("STAT_ATTACK_POWER", "Attack Power"))
    end
    local function crit(i, lines)
        local function read(x)
            if i == 4 then
                return ns.Plain(GetSpellCritChanceFromStat(i, x))
            end
            return ns.Plain(GetCritChanceFromStat(i, x))
        end
        local per = slope(read, attribute(i))
        ratio(lines, statName(i), per and per * 100, G("STAT_CRITICAL_STRIKE", "Critical Strike")
            .. (i == 4 and (" (" .. G("SPELLS", "Spells") .. ")") or ""), { percent = true })
    end
    local function dodge(lines)
        local v, share = attribute(2), ns.Plain(GetDodgeChanceFromAttribute())
        if v and v > 0 and type(share) == "number" then
            ratio(lines, statName(2), share * 100 / v, G("STAT_DODGE", "Dodge"), { percent = true })
        end
    end
    local function armor(lines)
        ratio(lines, statName(2), ARMOR_PER_AGILITY, G("STAT_ARMOR", "Armor"))
    end
    local function health(lines)
        ratio(lines, statName(3), ns.Plain(UnitHPPerStamina("player")), G("HEALTH", "Health"),
            { after = STAMINA_BREAK or 20 })
    end
    local function mana(lines)
        if hasMana() then
            ratio(lines, statName(4), MANA_PER_INTELLECT or 15, G("MANA", "Mana"), { after = INTELLECT_BREAK or 20 })
        end
    end
    -- the classes the sheet has a strength text of their own for, as GIVES
    local function blockValue(lines)
        if G(classFile() .. "_STRENGTH_TOOLTIP") then
            ratio(lines, statName(1), 1 / STRENGTH_PER_BLOCK, G("ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value"))
        end
    end
    local function defense(lines, what)
        ratio(lines, G("DEFENSE", "Defense"), PERCENT_PER_DEFENSE, what,
            { percent = true, point = true, around = level() * 5 })
    end
    -- (the hand `slot`'s with what is tried on the card kept open, Tried.what: its speed and its damage a second as
    -- they would be, the figure as it is greyed, the arrow, the blue; Tried.Hand; Ikar 2026-11-26: "Everything should
    -- follow, every, single, line")
    local function weapon(lines, speed, low, high, slot)
        if type(speed) ~= "number" or speed <= 0 then
            return
        end
        local wouldLow, wouldHigh, wouldSpeed
        if slot and Tried.what and not ns.InCombat() then
            local was = WOULD
            WOULD = Tried.Full()
            local ok, a, b, c = pcall(Tried.Hand, slot)
            WOULD = was
            if not ok then
                error(a, 0)
            elseif type(a) == "number" then
                wouldLow, wouldHigh, wouldSpeed = a, b, c
            end
        end
        local function said(now, tried)
            return tried and tried ~= now and Stats.Became(now, tried) or white(now)
        end
        local label = G("STAT_FORMAT", "%s:")
        lines[#lines + 1] = string.format(label, G("ATTACK_SPEED_SECONDS", "Attack Speed (seconds)")) .. " "
            .. said(Format.Decimal(speed, 2), wouldSpeed and Format.Decimal(wouldSpeed, 2))
        if type(low) == "number" and type(high) == "number" then
            lines[#lines + 1] = string.format(label, G("DAMAGE_PER_SECOND", "Damage per second")) .. " "
                .. said(Format.Decimal((low + high) / 2 / speed, 1),
                    wouldLow and Format.Decimal((wouldLow + wouldHigh) / 2 / wouldSpeed, 1))
        end
    end
    RATIOS.STRENGTH = function(lines)
        power(1, lines)
        blockValue(lines)
    end
    RATIOS.AGILITY = function(lines)
        crit(2, lines)
        power(2, lines)
        power(2, lines, true)
        armor(lines)
        dodge(lines)
    end
    RATIOS.STAMINA, RATIOS.HEALTH, RATIOS.ARMOR = health, health, armor
    RATIOS.INTELLECT = function(lines)
        mana(lines)
        crit(4, lines)
    end
    RATIOS.POWER = function(lines)
        if manaShown() then
            mana(lines)
        end
    end
    RATIOS.ATTACK_AP = function(lines)
        power(1, lines)
        power(2, lines)
    end
    RATIOS.RANGED_ATTACK_AP = function(lines)
        power(1, lines, true)
        power(2, lines, true)
    end
    RATIOS.CRITCHANCE = function(lines)
        crit(2, lines)
        crit(4, lines)
    end
    RATIOS.DODGE = function(lines)
        dodge(lines)
        defense(lines, G("STAT_DODGE", "Dodge"))
    end
    RATIOS.PARRY = function(lines)
        defense(lines, G("STAT_PARRY", "Parry"))
    end
    RATIOS.BLOCK = function(lines)
        defense(lines, G("STAT_BLOCK", "Block"))
        blockValue(lines)
    end
    RATIOS.BLOCKVALUE = blockValue
    -- the weapon's skill after them, as the sheet's damage tooltip adds it (PaperDollFrame_AddWeaponSkillLine): its
    -- rank, its bonus in brackets, the most it can be trained to (the review of 2026-11-21: the card had none)
    local function skill(lines, slot)
        local _, _, name, info = weaponSkill(slot)
        local rank, mod, most = type(info) == "table" and ns.Plain(info.rank), nil, nil
        if type(rank) ~= "number" then
            return
        end
        mod, most = ns.Plain(info.modifier) or 0, ns.Plain(info.maxRank)
        lines[#lines + 1] = string.format(G("WEAPON_SKILL_PAPERDOLLFRAME_FORMAT", "%s:"), name) .. " "
            .. white(number(rank) .. (mod ~= 0 and (" (" .. number(mod) .. ")") or "")
                .. (type(most) == "number" and ("/" .. number(most)) or ""))
    end
    RATIOS.MAINHAND_DAMAGE = function(lines)
        local low, high = ns.Plain(UnitDamage("player"))
        weapon(lines, (ns.Plain(UnitAttackSpeed("player"))), low, high, 16)
        skill(lines, 16)
    end
    RATIOS.OFFHAND_DAMAGE = function(lines)
        local _, _, low, high = ns.Plain(UnitDamage("player"))
        local _, speed = ns.Plain(UnitAttackSpeed("player"))
        weapon(lines, speed, low, high, 17)
        if type(speed) == "number" and speed > 0 then
            skill(lines, 17)
        end
    end
    RATIOS.RANGED_DAMAGE = function(lines)
        local speed, low, high = ns.Plain(UnitRangedDamage("player"))
        weapon(lines, speed, low, high, 18)
        skill(lines, 18)
    end
    -- a resistance's: its points for 1 % of average resistance, against one of the character's level
    -- the « / 115 » after the defence: the skill's most at the level, 5 a level, as the sheet's maxDefense; the
    -- skill rises as the character is attacked, up to it, its bonuses on top; what the skill lacks of it (Ikar
    -- 2026-11-19: "defense I have 113 / 115, where the 115 come from ?")
    RATIOS.DEFENSE = function(lines)
        local base = ns.Plain(UnitDefenseSkill("player"))
        local lvl = level()
        if type(base) ~= "number" or lvl <= 0 then
            return
        end
        lines[#lines + 1] = string.format(L.STAT_DEFENSE_MAX, white(number(lvl * 5)), lvl)
        if base < lvl * 5 then
            lines[#lines + 1] = string.format(L.STAT_DEFENSE_SKILL, white(number(base)), white(number(lvl * 5 - base)))
        end
    end
    RATIOS.ARMORPEN = function(lines)
        local text = say(G("ARMOR_PENETRATION_TOOLTIP"), ns.Plain(GetArmorPenetration()))
        lines[#lines + 1] = text and text:match("^.-%.%s+(.+)$") or nil
    end
    RATIOS.RESISTANCE = function(lines, s)
        local lvl = level()
        if lvl > 0 then
            ratio(lines, s.name(), 75 / (lvl * 5), string.format(L.STAT_GIVES_RESIST, lvl), { percent = true })
        end
    end
end

for _, s in ipairs(LIST) do
    s.ratios = RATIOS[s.school and "RESISTANCE" or s.key]
    s.gives = GIVES[s.key]
    -- a resistance: what it resists on average, against one of the character's level (what is tried's change with
    -- it while what would be is read)
    if s.school then
        s.gives = function()
            local list = {}
            local _, _, effective = ns.Plain(UnitResistance("player", s.school))
            effective = effective and effective + Tried.Change(s.key)
            local lvl = level()
            if effective and effective > 0 and lvl > 0 then
                tile(list, Format.Percent(floor(0.75 * effective / (lvl * 5) * 100) / 100),
                    string.format(L.STAT_GIVES_RESIST, lvl))
            end
            return list
        end
    end
end

-- ---------- Caps (Ikar 2026-11-19: "find for every carachteristic any possible cap, golden value etc.", then "go for
-- the live") ----------
-- The values worth reaching that this build's own texts and sheet code state, each against the value now: reached, or
-- what's missing. Against a raid boss, never to miss: 8 % with weapons, 17 % with spells, 27 % with two weapons
-- (CR_*_HIT_CAP_TOOLTIP, which has them as text alone); no critical strike from one: the defence that takes its 5 %
-- away, three levels above, at 0.04 % a point (the sheet's GetEnemyCritChance: five a level and 140, the 440 its
-- text names at 60); never dodged by one: 6.5 % of expertise (CR_EXPERTISE_TOOLTIP); the armour's most, 75 %
-- (ARMOR_MAX_EFFECTIVENESS_TOOLTIP), the armour that gives it asked of the game's own call, value by value; a
-- resistance's most on average, 75 % at five points a level (ExpectedSpellResistance).
-- Not all of them sure, and marked so (`unsure`): Forever's Skills tab takes 0.04 % of hit, dodge and parry a point of
-- weapon skill under a raid boss's 315 (0.6 % at 300), and nothing says whether the texts' 8 %, 27 % and 6.5 % hold it
-- already; a resistance's 75 % is the original game's, no text of this one's stating it; and a raid boss's parry is
-- 16.5 % in two of the game's texts and 14 % in the one its sheet shows, no figure in its code, none tested (the
-- raids open on 2026-12-09): both given, reached at the higher. The weapons' hit too (Ikar 2026-11-19: "do 10"): 8 %
-- in the texts, 9 % in the sheet's own code (CharacterHitFrame_OnEnter's meleeMissChances, a table it doesn't read),
-- and with two weapons 19 % more of either.
local BOSS_HIT, BOSS_HIT_DUAL = { m = { 8, 9 }, s = 17 }, { 27, 28 }
local BOSS_LEVELS, BOSS_DODGE, MOST = 3, 6.5, 0.75
local BOSS_PARRY = { 14, 16.5 }
-- Against what is fought now (Ikar 2026-11-19: "do 10, 1"): an enemy of the character's level, one or two above, by
-- the same code; three above is the raid boss's. What it is missed by, with weapons and with spells (the same two
-- tables, which the sheet doesn't read: unsure), two weapons 19 % more as a raid boss's; what it dodges
-- (BASE_ENEMY_DODGE_CHANCE, which the sheet's expertise reads). Its parry: 5 % at the character's level
-- (CR_EXPERTISE_TOOLTIP), no figure above. With weapons, one or two levels above: 5.2 and 5.4 % in that table, 5.5
-- and 6 % by the original server's (0.1 % a point of a creature's defence
-- above the weapon skill, up to 10; 0.04 % in the table), which its dodge's 5.5 and 6 % follow too: both, the question
-- said (the full review of 2026-11-20).
-- The spells' miss no hit takes away (`floor`), the original server's (1 % at least): the game's texts and tables
-- give the miss itself, 17 % against a raid
-- boss; past 16 % a point of hit did nothing there. Both, reached at the higher (the review of 2026-11-21, against
-- the original server and the classic guides).
local NEAR_MISS = { m = { [0] = 5, { 5.2, 5.5 }, { 5.4, 6 } }, s = { [0] = 4, 5, 6 }, floor = 1 }
-- A need of one figure or two, more.
local function plus(need, more)
    if type(need) == "table" then
        return { need[1] + more, need[2] + more }
    end
    return need + more
end
local NEAR_DODGE, NEAR_PARRY = { [0] = 5, 5.5, 6 }, 5
local DUAL_MORE = 19
-- `why`: the question the threshold leaves open, where there is one (two figures in the game, or none); `counts`:
-- whether the line's numeral goes by it (the kind of attack the line shows; the dodge, not the parry).
local function cap(list, label, have, need, missing, why, counts)
    list[#list + 1] = { label = label, reached = have >= need, missing = missing, why = why, counts = counts }
end
-- A figure a level's rows say with no threshold (what the enemy's blows come to, the glancing blows): neither reached
-- nor missing, in no numeral.
local function fact(list, label, why)
    list[#list + 1] = { label = label, why = why, fact = true }
end
-- What the blows of an enemy of level `at` come to against the character's defence `have` (the review of 2026-11-21's
-- proposals; Ikar: "go for the glancing and crushing, tank figure"), by this build's own sums (PaperDollFrameStats.lua's
-- GetEnemyChanceToMiss, GetEnemyCritChance and GetEnemyCrushingBlowChance, which its sheet doesn't call; the original
-- server's the same): it misses 5 %, 0.04 % more a point of the defence past its weapon skill (five
-- a level), and strikes critically 5 %, as much less; its skill 15 or more past the defence's most (three levels above;
-- the defence past its most counts for nothing there), its crushing blows are 2 % a point of it less 15 (15 % at
-- three), at 150 % of the damage, out of what one roll leaves after its misses, the dodges, parries and blocks and its
-- critical strikes. The sheet's dodge, parry and block are against an enemy of the character's level
-- (CR_BLOCK_TOOLTIP); one above takes 0.04 % a point of its skill past the defence's most from each, the original
-- server's (CalculateEffectiveDodgeChance and the others' factor), no sum of this build's: asked
-- (STAT_WHY_AVOID_LEVEL). `suppress`: what an enemy above takes of a critical strike a point of weapon skill short of
-- its defence by the original server, 1 % a level (the white hits' ceiling, CAPS.CRITCHANCE). Nil when the game says
-- nothing.
local ENEMY = { crit = 5, miss = 5, crushFrom = 15, suppress = 0.2 }
function ENEMY.blows(have, at)
    local dodge, parry, block = Tried.Chance("DODGE"), Tried.Chance("PARRY"), Tried.Chance("BLOCK")
    if type(dodge) ~= "number" or type(parry) ~= "number" or type(block) ~= "number" then
        return nil
    end
    local function chance(v)
        return max(0, min(100, v))
    end
    local skill, most = at * 5, level() * 5
    local over = max(0, skill - most) * PERCENT_PER_DEFENSE
    local t = { crit = chance(ENEMY.crit + (skill - have) * PERCENT_PER_DEFENSE) }
    t.avoided = chance(chance(ENEMY.miss - (skill - have) * PERCENT_PER_DEFENSE) + chance(dodge - over)
        + chance(parry - over) + chance(block - over))
    local past = skill - min(have, most)
    t.crush = past < ENEMY.crushFrom and 0 or chance(past * 2 - ENEMY.crushFrom)
    t.crushed = min(t.crush, max(0, 100 - t.avoided - t.crit))
    return t
end
-- What an enemy of the character's level gets against it (the defence's column; ENEMY.blows): its crit, all it
-- doesn't land, and its chance to miss, 5 % and 0.04 % a point of defence either way of the level's most, as the
-- game's own sheet works it out (Camelot's GetEnemyChanceToMiss, never shown there); the defence and its most for the
-- sums; nil while the game hides them. What is tried's changes on the defence, the dodge, the parry and the block with
-- them while what would be is read (Tried.Change).
function Stats.Taken()
    local have, at = Tried.Defense(), level()
    if have == nil then
        return nil
    end
    local t = ENEMY.blows(have, at)
    if t then
        t.have, t.most = have, at * 5
        t.miss = max(0, min(100, ENEMY.miss + (have - t.most) * PERCENT_PER_DEFENSE))
    end
    return t
end
-- What the armour takes off the blows of an enemy of the character's level, in percent, the game's own (the sheet's
-- armour tooltip); and the armour. The armour what is tried would make while what would be is read, the game's own
-- call taking any (Ikar 2026-11-25: "damage reduction too").
function Stats.ArmorCut()
    local _, effective = ns.Plain(UnitArmor("player"))
    effective = type(effective) == "number" and max(0, effective + Tried.Change("ARMOR")) or effective
    local share = type(effective) == "number"
        and ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectiveness, effective, UnitEffectiveLevel("player")))
    return type(share) == "number" and share * 100 or nil, effective
end
-- The levels of enemy the game's figures go to (Ikar 2026-11-20: "met un lvl avec dans l'info box tous les lvl, la
-- liste, comment, pourquoi"; "chiffre romain"): one of the character's level (I), one and two above (II, III), a raid
-- boss three above (IV); the game has no fifth. Each its rows, from `base` the level it counts from.
local ROMAN = { "I", "II", "III", "IV" }
Stats.ROMAN = ROMAN
-- A numeral's gold, and the words « Comment » and « Pourquoi »: the game's own (NORMAL_FONT_COLOR).
local TIER = "ffffd100"
local function tiersOf(base, fill)
    local tiers = {}
    for n = 1, #ROMAN do
        local t = { above = n - 1, level = base + n - 1, boss = n == #ROMAN, rows = {} }
        fill(t.rows, t.above, t.boss, t.level)
        tiers[n] = t
    end
    return tiers
end
-- The line's numeral: the highest level whose rows that count are all reached, every level under it too; nil for
-- none.
local function numeral(caps)
    local got
    for n, t in ipairs(caps and caps.tiers or {}) do
        local any, all = false, true
        for _, c in ipairs(t.rows) do
            if c.counts then
                any, all = true, all and c.reached
            end
        end
        if not (any and all) then
            break
        end
        got = n
    end
    return got and ROMAN[got] or nil
end
-- What a weapon skill short of its most adds to the thresholds of the attacks made with it, as Forever's Skills tab
-- works it out (Camelot's SkillsFrame.lua, GetHitDodgeParryChance): 0.04 % a point the skill lacks of the target's
-- defence, five a level. The tables of the enemy at hand and the raid boss's figures are those of a skill at its most
-- (the hit's 5, 5.2, 5.4 % the same sum at one and two levels above): what the character's skill lacks of its own
-- level's most comes on top, in percent points; with the skill's name, its value and its most; 0 with no weapon of a
-- skill there, nil when it can't be read (weaponSkill).
local function weaponShort(slot)
    local have, most, name = weaponSkill(slot)
    if have == false then
        -- no weapon of a skill there (no ranged weapon, a fishing pole): nothing short, no question
        return 0
    elseif not have then
        return nil
    end
    return max(0, most - have) * PERCENT_PER_DEFENSE, name, have, most
end
-- The answer to what a skill short of its most does, under the thresholds (no question: the game's own sum).
local function shortNote(list, short, name, have, most)
    if short and short > 0 then
        list[#list + 1] = { note = string.format(L.STAT_SKILL_SHORT, name, number(have), number(most),
            "+" .. percent(short)) }
    end
end
-- The target's level when it is an enemy whose level the game gives (a skull's is none).
local function targetLevel()
    if ns.Call(UnitExists, "target") and ns.Call(UnitCanAttack, "player", "target") then
        local theirs = ns.Plain(ns.Call(UnitLevel, "target"))
        return type(theirs) == "number" and theirs > 0 and theirs or nil
    end
end
-- The armour that takes `share` of a blow from one of level `lvl`, by the game's own sum: doubled until it does, then
-- halved down to the point; nil when the game says nothing, or never gets there.
local function armorFor(share, from, lvl)
    local get = C_PaperDollInfo.GetArmorEffectiveness
    local low, high, got = from, max(from, 1), nil
    for _ = 1, 24 do
        got = ns.Plain(ns.Call(get, high, lvl))
        if not got or got >= share then
            break
        end
        low, high = high, high * 2
    end
    if not got or got < share then
        return nil
    end
    for _ = 1, 30 do
        local mid = (low + high) / 2
        local v = ns.Plain(ns.Call(get, mid, lvl))
        if not v then
            return nil
        elseif v >= share then
            high = mid
        else
            low = mid
        end
    end
    return ceil(high - 0.001)
end
-- Each threshold's row: what it is and its figure (`what`), reached or what's missing.
local function row(what, figure)
    return string.format(L.STAT_TIER_ROW, what, figure)
end
-- One of a need of two figures, the game giving both: reached at the higher, what's short of each, the question said.
local function capEither(list, what, have, few, many, why, counts)
    cap(list, row(what, string.format(L.STAT_CAP_EITHER, percentText(few), percentText(many))), have, many,
        string.format(L.STAT_CAP_EITHER, percent(max(0, few - have)), percent(many - have)), why, counts)
end
-- Each a function giving { tiers, notes, target, how, goal }: its rows level by level, what a weapon's skill short of
-- its most adds (notes), the target's rows when it is of another level than the four (armour, resistances), how the
-- figures are had and why they're worth it; nil when the value can't be read. `quick`: for the line's numeral, what's
-- missing not worked out (the armour's asks the game some fifty times).
local CAPS = {
    HITCHANCE = function()
        local m, r, s, main, off = hitBy()
        if not m then
            return nil
        end
        -- one row a kind of attack, the line's by the kind it shows (best): what never missing takes, a weapon's
        -- with what its skill lacks of its most on top (weaponShort); a question only where the game gives two
        -- figures (one or two levels above, a raid boss, with weapons), or where the weapon's skill can't be read
        local kind = best(m, r, s)
        local short, name, have, most = weaponShort(16)
        local rangedShort, rangedName, rangedHave, rangedMost = weaponShort(18)
        local unread = not short and L.STAT_WHY_SKILL_UNREAD or nil
        local rangedUnread = not rangedShort and L.STAT_WHY_SKILL_UNREAD or nil
        local ranged = RANGED_CLASS[classFile()]
        local dual = ns.Call(IsDualWielding)
        local function hit(list, word, need, value, why, more, counts)
            more = more or 0
            if type(need) == "table" then
                capEither(list, word, value, need[1] + more, need[2] + more, why, counts)
            else
                cap(list, row(word, percentText(need + more)), value, need + more, percent(need + more - value), why, counts)
            end
        end
        local caps = { notes = {}, how = L.STAT_HOW_HIT, goal = L.STAT_GOAL_HIT }
        caps.tiers = tiersOf(level(), function(list, above, boss)
            local weapons = boss and BOSS_HIT.m or NEAR_MISS.m[above]
            local spells = boss and BOSS_HIT.s or NEAR_MISS.s[above]
            local why = boss and L.STAT_WHY_BOSS_HIT or above > 0 and L.STAT_WHY_NEAR_HIT or nil
            hit(list, G("MELEE", "Melee"), weapons, m, why or unread, short, kind == "m" or kind == "r" and not ranged)
            if ranged then
                hit(list, G("RANGED", "Ranged"), weapons, r, why or rangedUnread, rangedShort, kind == "r")
            end
            hit(list, G("SPELLS", "Spells"), { spells - NEAR_MISS.floor, spells }, s, L.STAT_WHY_SPELL_FLOOR, 0,
                kind == "s")
            if dual then
                hit(list, L.STAT_CAP_DUAL, boss and BOSS_HIT_DUAL or plus(weapons, DUAL_MORE), min(main, off),
                    why or unread, short)
            end
        end)
        shortNote(caps.notes, short, name, have, most)
        if ranged and rangedName ~= name then
            shortNote(caps.notes, rangedShort, rangedName, rangedHave, rangedMost)
        end
        return caps
    end,
    -- The critical strikes white hits can hold (the review of 2026-11-21's proposals; Ikar: "go for the glancing"),
    -- where the line shows the melee's: a white hit, the main hand's automatic attack, takes one roll on a table, its
    -- misses (the hit counted, the two weapons' 19 % more), dodges (the expertise counted), glancing blows and critical
    -- strikes in that order, plain hits what's left; past what the others leave, a critical strike more takes a plain
    -- hit's place no more, lost on white hits (from behind; in front the parry takes more). The glancing blows asked of
    -- the game at each level's defence (GetGlancingBlowChance, GetGlancingBlowPenalty: the Skills tab's, which reads
    -- the main hand's skill when given none), said as a figure. An enemy above takes some critical strikes, which the
    -- sheet's must hold more: 0.2 % a level by the Skills tab (GetCriticalHitChance, 0.6 % against a raid boss), 1 %
    -- by the original server at the skill's most (ENEMY.suppress, 3 %); with the hit's two figures, both, reached at
    -- the higher. The techniques roll apart: none.
    CRITCHANCE = function()
        local m, r, s = critBy()
        local _, _, _, main = hitBy()
        if best(m, r, s) ~= "m" or not main then
            return nil
        end
        local short = weaponShort(16)
        local unread = not short and L.STAT_WHY_SKILL_UNREAD or nil
        local have = weaponSkill(16)
        short, have = short or 0, type(have) == "number" and have or level() * 5
        local expertise = ns.Plain(GetExpertise())
        expertise = type(expertise) == "number" and expertise or 0
        local dual = ns.Call(IsDualWielding)
        local what = dual and (L.STAT_TIER_WHITE_CAP .. ", " .. L.STAT_CAP_DUAL) or L.STAT_TIER_WHITE_CAP
        local caps = { notes = {}, how = L.STAT_HOW_CRIT, goal = L.STAT_GOAL_CRIT, unnumbered = true }
        caps.tiers = tiersOf(level(), function(list, above, boss, at)
            local defense = at * 5
            local glancing = ns.Plain(ns.Call(GetGlancingBlowChance, nil, defense))
            if type(glancing) ~= "number" then
                return
            end
            glancing = glancing * 100
            local penalty = ns.Plain(ns.Call(GetGlancingBlowPenalty, nil, defense))
            if glancing > 0 and type(penalty) == "number" then
                fact(list, row(L.STAT_TIER_GLANCING, string.format(L.STAT_GLANCING_FIGURE, percentText(glancing),
                    percentText(penalty * 100))))
            end
            local missed = boss and BOSS_HIT.m or NEAR_MISS.m[above]
            if dual then
                missed = boss and BOSS_HIT_DUAL or plus(missed, DUAL_MORE)
            end
            local dodged = max(0, (boss and BOSS_DODGE or NEAR_DODGE[above]) + short - expertise)
            local function ceiling(miss, taken)
                return max(0, min(100, 100 - max(0, miss + short - main) - dodged - glancing + taken))
            end
            -- what the enemy takes of the sheet's critical strike, which holds the weapon skill against the level's
            -- most already (PARTS.CRITCHANCE): by the Skills tab, its defence past that most at 0.04 % a point, the
            -- skill's either way the same; by the original server, the skill's share taken back and the defence past
            -- the skill at 0.2 % a point (3 % at 300 against a raid boss), never less
            local most = level() * 5
            local taken = (defense - most) * PERCENT_PER_DEFENSE
            local original = (have - most) * PERCENT_PER_DEFENSE
                + (defense - have) * (defense > have and ENEMY.suppress or PERCENT_PER_DEFENSE)
            local few = ceiling(type(missed) == "table" and missed[2] or missed, taken)
            local many = ceiling(type(missed) == "table" and missed[1] or missed, max(taken, original))
            if many - few > 0.005 then
                capEither(list, what, m, few, many, L.STAT_WHY_WHITE_CAP)
            else
                cap(list, row(what, percentText(few)), m, few, percent(few - m), unread)
            end
        end)
        return caps
    end,
    -- no critical strike from it: five points of defence a level of the enemy and its 5 % taken away, 0.04 % a point;
    -- what its blows come to, avoided or blocked, and where it has crushing blows, those that land and what leaves them
    -- no room: avoided or blocked, all its critical strikes leave (ENEMY.blows). The line's numeral the critical
    -- strike's alone.
    DEFENSE = function()
        local base, mod = ns.Plain(UnitDefenseSkill("player"))
        if not base then
            return nil
        end
        local have = max(0, base + (mod or 0))
        return { notes = {}, how = L.STAT_HOW_DEFENSE, goal = L.STAT_GOAL_DEFENSE,
            tiers = tiersOf(level(), function(list, above, _, at)
                local need = at * 5 + floor(ENEMY.crit / PERCENT_PER_DEFENSE + 0.5)
                cap(list, row(L.STAT_TIER_NO_CRIT, number(need)), have, need, number(need - have), nil, true)
                local blows = ENEMY.blows(have, at)
                if blows then
                    local why = above > 0 and L.STAT_WHY_AVOID_LEVEL or nil
                    fact(list, row(L.STAT_TIER_AVOID, percentText(blows.avoided)), why)
                    if blows.crush > 0 then
                        local room = 100 - blows.crit
                        -- unsure only where the dodges, parries and blocks leave it less than its chance
                        fact(list, row(L.STAT_TIER_CRUSHING, percentText(blows.crushed)),
                            blows.crushed < blows.crush and why or nil)
                        cap(list, row(L.STAT_TIER_NO_CRUSHING, string.format(L.STAT_NO_CRUSHING_FIGURE,
                            percentText(room))), blows.avoided, room, percent(room - blows.avoided), why)
                    end
                end
            end) }
    end,
    -- never dodged, the line's; never parried: 5 % at the character's level (CR_EXPERTISE_TOOLTIP's « créatures de
    -- même niveau »; the full review of 2026-11-20), a raid boss's one figure or the other, none in the game for one or
    -- two levels above; each with what the weapon's skill lacks of its most on top
    EXPERTISE = function()
        local main = ns.Plain(GetExpertise())
        if type(main) ~= "number" then
            return nil
        end
        local short, name, have, most = weaponShort(16)
        local unread = not short and L.STAT_WHY_SKILL_UNREAD or nil
        local more = short or 0
        local caps = { notes = {}, how = L.STAT_HOW_EXPERTISE, goal = L.STAT_GOAL_EXPERTISE }
        caps.tiers = tiersOf(level(), function(list, above, boss)
            local dodge = (boss and BOSS_DODGE or NEAR_DODGE[above]) + more
            cap(list, row(L.STAT_TIER_NO_DODGE, percentText(dodge)), main, dodge, percent(dodge - main), unread, true)
            if above == 0 then
                local parried = NEAR_PARRY + more
                cap(list, row(L.STAT_TIER_NO_PARRY, percentText(parried)), main, parried, percent(parried - main),
                    unread)
            elseif boss then
                capEither(list, L.STAT_TIER_NO_PARRY, main, BOSS_PARRY[1] + more, BOSS_PARRY[2] + more,
                    L.STAT_WHY_BOSS_PARRY)
            end
        end)
        shortNote(caps.notes, short, name, have, most)
        return caps
    end,
    -- the armour's most, 75 %, at each level by the game's own call, and the armour short of it
    ARMOR = function(quick)
        local _, effective = ns.Plain(UnitArmor("player"))
        local lvl = UnitEffectiveLevel("player")
        if not (effective and C_PaperDollInfo) then
            return nil
        end
        local function most(list, at, counts)
            local taken = ns.Plain(ns.Call(C_PaperDollInfo.GetArmorEffectiveness, effective, at))
            if taken then
                local need = not quick and armorFor(MOST, effective, at)
                cap(list, row(L.STAT_TIER_ARMOR, Format.Percent(MOST)), taken, MOST - 0.00005,
                    need and number(need - effective) or percent((MOST - taken) * 100), nil, counts)
            end
        end
        local caps = { notes = {}, how = L.STAT_HOW_ARMOR, goal = L.STAT_GOAL_ARMOR }
        caps.tiers = tiersOf(lvl, function(list, _, _, at)
            most(list, at, true)
        end)
        -- against the target, an enemy of another level than these four: the same call at its level, whatever it is
        local theirs = targetLevel()
        if theirs and (theirs < lvl or theirs > lvl + BOSS_LEVELS) then
            caps.target = { level = theirs, rows = {} }
            most(caps.target.rows, theirs)
        end
        return caps
    end,
}
for _, s in ipairs(LIST) do
    s.caps = CAPS[s.key]
    -- a resistance's most on average, 75 %, five points a level of the enemy; the target's of another level too
    if s.school then
        s.caps = function()
            local _, _, effective = ns.Plain(UnitResistance("player", s.school))
            if not effective or level() <= 0 then
                return nil
            end
            local function most(list, at, counts)
                cap(list, row(L.STAT_TIER_RESIST, Format.Percent(MOST)), effective, at * 5, number(at * 5 - effective),
                    L.STAT_WHY_RESIST, counts)
            end
            local caps = { notes = {}, how = L.STAT_HOW_RESIST, goal = L.STAT_GOAL_RESIST }
            caps.tiers = tiersOf(level(), function(list, _, _, at)
                most(list, at, true)
            end)
            local theirs = targetLevel()
            if theirs and (theirs < level() or theirs > level() + BOSS_LEVELS) then
                caps.target = { level = theirs, rows = {} }
                most(caps.target.rows, theirs)
            end
            return caps
        end
    end
end

-- The sources' rows: what the value stands on (the items' own under « Équipement » and their sum when there are
-- several; the base alone for a value nothing is named under), a line, then its changes under « Bonus » with their
-- sum where the game gives it.
-- A group's sum, for its name's row: where each of its rows has an amount, whole and sure; unsigned for one that
-- holds what the value stands on (the items' own armour), signed for changes alone.
local function sumOf(entries)
    local sum, stands, percents = 0, false, true
    for _, e in ipairs(entries) do
        if type(e.points) ~= "number" or e.share or e.unsure then
            return ""
        end
        sum, stands, percents = sum + e.points, stands or e.base == true, percents and e.percent == true
    end
    local text = percents and percentText(sum) or number(sum)
    return stands and text or sum ~= 0 and signed(sum, text) or ""
end

-- A group of rows under its name, the name with the group's sum where it holds several: one row alone kept its name
-- too, an item alone under no « Équipement » reading as a spell (Ikar 2026-11-19: "Unclear"). An item's own share
-- and what it adds (the same slot's, one after the other) on one row: « 300 +20 ».
local function groupRows(rows, name, entries)
    local grouped = #entries > 0
    if grouped then
        rows[#rows + 1] = { left = name, right = #entries > 1 and sumOf(entries) or "", group = true }
    end
    local last
    for _, e in ipairs(entries) do
        if last and last.entry.base and last.entry.item and e.item and not e.base and e.slot == last.entry.slot then
            last.row.right = last.row.right .. " " .. rightOf(e)
        else
            -- (on a card kept open, its hover the item's tooltip, a slot's, or its spell's: StatCard.lua's tipFor)
            local row = { left = e.name, right = rightOf(e), indent = grouped,
                tip = e.tip or (e.slot and { slot = e.slot }) or nil }
            rows[#rows + 1] = row
            last = { entry = e, row = row }
        end
    end
end

-- (Ikar 2026-11-19: "base should be first no ?"; then, of the gear's and the sets' bonuses, "They shoudl show as a
-- separate set bonus category, after equipement, could be in them, but near will simplify reading. Equipement et Set
-- d'equipement".) First the value's base, then what each attribute gives it; then all the gear gives, « Équipement »,
-- slot by slot: an item's own armour, what it adds (its stats, its « Équipé : » spells), its enchantment; next to it
-- the sets' bonuses, « Ensembles d'objets », the game's own name for them (its « Ensembles d'équipement » are the
-- outfits saved in the equipment manager); a line, then the rest under « Bonus »: buffs and debuffs, talents, passive
-- spells, what's left.
local MISTAKE = { 1, 0.125, 0.125 }
local function sourceRows(s, list)
    local rows, stands, gear, sets, rest, items = {}, {}, {}, {}, {}, 0
    local nexts = {}
    for _, e in ipairs(list) do
        if e.next then
            nexts[#nexts + 1] = e
        elseif e.base and e.item then
            gear[#gear + 1] = e
            items = items + 1
        elseif e.base then
            stands[#stands + 1] = e
        elseif e.kind == "gear" then
            gear[#gear + 1] = e
        elseif e.kind == "set" then
            sets[#sets + 1] = e
        else
            rest[#rest + 1] = e
        end
    end
    -- its base first, then what's named of it
    for _, e in ipairs(stands) do
        if e.other and not e.mistake then
            rows[#rows + 1] = { left = e.name, right = rightOf(e), color = not e.origin and Infos.GREY or nil,
                tip = e.tip }
        end
    end
    local base = s.numbers and s.numbers()
    -- (none at 0: a shaman's ranged attack power, the bracers' alone, had said « Base 0 »; the review of 2026-11-21)
    if #stands == 0 and items == 0 and base and base ~= 0 and #gear + #sets + #rest + #nexts > 0 then
        rows[#rows + 1] = { left = baseName(s.sources), right = number(base) }
    end
    for _, e in ipairs(stands) do
        if not e.other then
            rows[#rows + 1] = { left = e.name, right = rightOf(e), tip = e.tip, match = e.match }
        end
    end
    -- what the card can't account for of the game's base, in red, the foot saying it's the addon's to be reported
    for _, e in ipairs(stands) do
        if e.mistake then
            rows[#rows + 1] = { left = e.name, right = Infos.Color((e.points > 0 and "+" or "")
                .. (e.percent and percentText(e.points) or number(e.points)), Infos.BAD) .. " "
                .. ask(L.STAT_ADDON_ERROR_TIP), color = MISTAKE }
        end
    end
    -- the gear by slot, an item's own share before what it adds, its enchantment after
    local bySlot = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        for _, own in ipairs({ true, false }) do
            for _, e in ipairs(gear) do
                if e.slot == slot and (e.base == true) == own then
                    bySlot[#bySlot + 1] = e
                end
            end
        end
    end
    for _, e in ipairs(gear) do
        if not e.slot then
            bySlot[#bySlot + 1] = e
        end
    end
    groupRows(rows, L.STAT_GEAR, bySlot)
    groupRows(rows, L.STAT_SETS, sets)
    -- what a set's next pieces would give, after what the sets give: not had yet, so in grey, its figure too, and in
    -- no sum
    for _, e in ipairs(nexts) do
        rows[#rows + 1] = { left = e.name, right = bare(rightOf(e)), indent = #sets > 1, color = Infos.GREY,
            rightColor = Infos.GREY, tip = e.tip }
    end
    if #rest > 0 then
        if #rows > 0 then
            rows[#rows + 1] = { rule = true }
        end
        -- (no sum of changes that multiply each other: the haste's, the speed's)
        rows[#rows + 1] = { left = L.STAT_BONUS, right = s.sources.multiplies and "" or sumOf(rest), group = true }
        for _, e in ipairs(rest) do
            rows[#rows + 1] = { left = e.name, right = rightOf(e), indent = true,
                color = e.mistake and MISTAKE or (e.other or e.idle) and Infos.GREY or nil, tip = e.tip }
        end
    end
    return rows
end

-- The middle and the right of the card: the sheet's texts, cut; figures on the right where the value has some.
local function cardTexts(data, s)
    local into = { gives = {}, is = {}, notes = {} }
    local texts, onlyIs = {}, false
    if s.texts then
        texts, onlyIs = s.texts()
    end
    for _, text in ipairs(texts) do
        if onlyIs then
            into.is[#into.is + 1] = text
        else
            cut(text, into)
        end
    end
    -- first what's worth reaching, level by level (Ikar 2026-11-20: "dans l'info box tous les lvl, la liste,
    -- comment, pourquoi"): each level's numeral and whom it's against (the target's, when it is), its rows, reached in
    -- green or what's missing; what a weapon's skill short adds; the target of another level; how the figures are
    -- had, what the numerals are, and why they're worth reaching
    local caps = s.caps and s.caps()
    if caps then
        local function line(c)
            local said = c.label .. (c.why and (" " .. ask(c.why)) or "")
            if c.fact then
                return said
            end
            return said .. " — "
                .. (c.reached and Infos.Color(L.STAT_CAP_REACHED, Infos.GOOD)
                    or Infos.Color(string.format(L.STAT_CAP_MISSING, c.missing), "ffffffff"))
        end
        local theirs = targetLevel()
        for n, t in ipairs(caps.tiers) do
            if #t.rows > 0 then
                local who = string.format(t.boss and L.STAT_TIER_BOSS or L.STAT_TIER_LEVEL, t.level)
                    .. (theirs == t.level and (" · " .. L.STAT_TIER_TARGET) or "")
                local lines = { Infos.Color(ROMAN[n], TIER) .. " " .. who }
                for _, c in ipairs(t.rows) do
                    lines[#lines + 1] = line(c)
                end
                data.about[#data.about + 1] = { text = table.concat(lines, "\n") }
            end
        end
        for _, c in ipairs(caps.notes) do
            data.about[#data.about + 1] = { text = c.note }
        end
        if caps.target and #caps.target.rows > 0 then
            local lines = { string.format(L.STAT_CAP_TARGET, caps.target.level) }
            for _, c in ipairs(caps.target.rows) do
                lines[#lines + 1] = line(c)
            end
            data.about[#data.about + 1] = { text = table.concat(lines, "\n") }
        end
        -- (how and why on one line, their text in the game's tooltip on its hover: StatCard.lua. Ikar 2026-11-22: "crit
        -- hit defense and armor have disproportionate amount of text", then "hover to see details")
        data.about[#data.about + 1] = { text = L.STAT_DETAILS, details = {
            Infos.Color(L.STAT_TIER_HOW, TIER) .. " " .. caps.how .. " "
                .. (caps.unnumbered and L.STAT_TIERS_NONE or L.STAT_TIERS),
            Infos.Color(L.STAT_TIER_WHY, TIER) .. " " .. caps.goal } }
    end
    for _, text in ipairs(into.is) do
        data.about[#data.about + 1] = { text = text }
    end
    -- what a point of each attribute that raises it gives, under the sheet's « Augmenté par »
    local lines = {}
    if s.ratios then
        s.ratios(lines, s)
    end
    if #lines > 0 then
        data.about[#data.about + 1] = { text = table.concat(lines, "\n") }
    end
    if s.more then
        -- its own lines, as it writes them under a tooltip
        s.more({ AddLine = function(_, text)
            data.about[#data.about + 1] = { text = text, color = Infos.WHITE }
        end })
    end
    for _, text in ipairs(into.notes) do
        data.about[#data.about + 1] = { text = text }
    end
    local figures = s.gives and s.gives() or {}
    if #figures > 0 then
        data.tiles = figures
    else
        for _, text in ipairs(into.gives) do
            data.effects[#data.effects + 1] = { text = text }
        end
    end
end

-- ---------- What would be ----------
-- (Ikar 2026-11-19: "even better, update with a different color on an item, talent, consumable hover"; of the colour,
-- on the sketches, "go for the light blue".) While a card is kept open, what is under the pointer is tried on its
-- value: an item that could be worn, in its slot; a talent, at its next rank; a consumable, drunk. The value's sources
-- are read a second time with it in place (WOULD), the rows that differ said in the blue (what goes: its figure
-- greyed, an arrow, 0; what comes: its row; what changes: both figures), and the card's head says the value as it is,
-- by how much it would change and what it would be. Worked out from what the sources name: a figure that can't be,
-- the game's own question mark in its place. The blue the game's own darker one (GlobalColor's RARE_BLUE_COLOR, 0.27
-- of light where the sheet's green has 0.72; Ikar 2026-11-25, of the light blue's 0.59: "the blue is hard to
-- differenciate with the green, maybe let's make it darker").
local WOULD_HEX, WAS_HEX = "ff0091f2", "ff808080"
Stats.WOULD_HEX = WOULD_HEX

local STAT_BY_KEY = {}
for _, s in ipairs(LIST) do
    STAT_BY_KEY[s.key] = s
end

-- A value's sources as they are (`what` nil) or with `what` in place, all tallied, and the tally. What was being read
-- put back after: a value worked out inside another's reading (Tried.Change).
local function tallyWith(s, what)
    local was = WOULD
    WOULD = what
    local ok, list, _, t = pcall(sourcesOf, s, true, true)
    WOULD = was
    if not ok then
        error(list, 0)
    end
    return list or {}, t
end

-- What a tally's named sources come to: what the value stands on (the attributes' shares, the items' own), how many
-- of its sources have no amount, and the items' own alone (the armour's, which its shares raise). A share of an
-- attribute the game counts in its base (Mental Dexterity's, sourcesOf's levelPart) is in the flat changes already:
-- not again (the review of 2026-11-21: every item tried on a shaman's attack power had been short by it).
local function summed(list)
    local parts, unknown, own = 0, 0, 0
    for _, e in ipairs(list) do
        if e.base and not e.other and not e.ofStat and type(e.points) == "number" then
            parts = parts + e.points
            own = own + (e.item and e.points or 0)
        end
        if not e.next and not e.idle
            and (e.unsure or (e.points == nil and e.share == nil and e.keep == nil and not e.base)) then
            unknown = unknown + 1
        end
    end
    return parts, unknown, own
end

-- By how much `what` would change the value `s`, and whether that can't be said for sure; with the two readings. The
-- value is its base (with the parts named of it), raised by the shares of the base, then its flat changes and what
-- the game's sum leaves over, the whole by the shares of the whole: the same sum with the second reading's figures,
-- what is left over kept as it is.
local function changeOf(s, what)
    local nowList, now = tallyWith(s, nil)
    local wouldList, would = tallyWith(s, what)
    if not (now and would) then
        return nil, false, nowList, wouldList, now
    end
    local nowParts, nowUnknown, nowOwn = summed(nowList)
    local wouldParts, wouldUnknown, wouldOwn = summed(wouldList)
    -- (why it can't be said, the question the head's mark asks: a source more without a figure, a share without base)
    local unsure = wouldUnknown > nowUnknown and L.STAT_WHY_WOULD or (would.open and not now.open) and L.STAT_WHY_SHARE
        or nil
    -- (the value as it is, read so inside another's reading too: the damage reduction's, Tried.Change)
    local base, effective
    local was = WOULD
    WOULD = nil
    if s.numbers then
        base, effective = s.numbers()
    elseif s.total then
        -- (no base: what it would be is its whole and the change, the change from its sources alone)
        effective = s.total()
    end
    WOULD = was
    local delta
    if base and effective then
        -- the same sum as sourcesOf's: the base it shows, the items' own raised by the shares of the base with it
        local shown = now.shownBase or base
        local rest = effective / now.whole - (shown + now.items) * (1 + now.ofBase) - (now.flat - now.items)
        delta = ((shown + wouldParts - nowParts + would.items) * (1 + would.ofBase) + (would.flat - would.items) + rest)
            * would.whole - effective
    elseif s.sources.speed and effective and (now.expected or 0) > 0 and would.expected then
        -- (the speed's: by what its named sources would come to, the strongest of a kind alone: speedOf)
        delta = effective * (would.expected / now.expected - 1)
    elseif s.sources.ofItems then
        -- (the armour's: the items' own by their shares, the rest added, the whole by its shares)
        delta = (wouldParts + wouldOwn * would.ofBase + would.flat) * would.whole
            - (nowParts + nowOwn * now.ofBase + now.flat) * now.whole
    else
        -- (a share of the whole the same in both raises the change too: Blood Fury's of the spell power)
        delta = (wouldParts - nowParts + would.flat - now.flat) * (would.whole == now.whole and would.whole or 1)
        unsure = unsure or (would.whole ~= now.whole or would.ofBase ~= now.ofBase) and L.STAT_WHY_SHARE or nil
    end
    return delta, unsure, nowList, wouldList, now, effective
end

-- By how much the value of `key` would change with what is tried, while what would be is read (WOULD; 0 else): the
-- figures worked out of another value follow it (Ikar 2026-11-25: "when hovering an item, it doesn't seems to update
-- everything, the output for example", then "damage reduction too"): the damage reduction its armour's, the misses
-- and critical strikes taken their defence's, the avoidance its dodge's, parry's and block's, these three their
-- defence's share, a card kept open's effects their value's (Tried.Effects). The same sum as the value's own line
-- (changeOf), once for what is tried (its `changes`), its question where it can't be said with it (`changeDoubts`),
-- which what stands on it asks (Tried.leaned, wouldBe). `channel`: a kind of attack's, of a value that is the best of
-- three (a card's effects, each kind's: sourcesOf reads that kind's). With what is tried as it comes (no attributes
-- worked out yet: Tried.With's own readings), nothing, and nothing kept in it (Tried.With copies it).
function Tried.Change(key, channel)
    local w = WOULD
    if not (w and w.attributes) then
        return 0
    end
    local id = channel and (key .. " " .. channel) or key
    if Tried.leaned then
        Tried.leaned[id] = true
    end
    w.changes, w.changeDoubts = w.changes or {}, w.changeDoubts or {}
    if w.changes[id] == nil then
        local s = STAT_BY_KEY[key]
        -- (0 while it is worked out: a value standing on itself reads its own as it is)
        w.changes[id] = 0
        if s and s.sources then
            local asked = Tried.channel
            Tried.channel = channel and { key, channel } or nil
            local ok, delta, doubt = pcall(changeOf, s, w)
            WOULD, Tried.channel = w, asked
            if not ok then
                w.changes[id] = nil
                error(delta, 0)
            end
            w.changes[id], w.changeDoubts[id] = delta or 0, doubt or nil
        end
    end
    return w.changes[id]
end
-- The first question of what a figure stands on (`stands`, Tried.leaned's: an attribute's index, a value's key), in
-- what is tried's doubts; nil where every change it stands on can be said.
function Tried.DoubtOf(tried, stands)
    for i = 1, #ATTRIBUTE_KEYS do
        if stands[i] and tried.doubts and tried.doubts[i] then
            return tried.doubts[i]
        end
    end
    for id in pairs(stands) do
        local doubt = type(id) == "string" and tried.changeDoubts and tried.changeDoubts[id]
        if doubt then
            return doubt
        end
    end
end

-- What `what` would change of each attribute, for the values that stand on them, and why each change can't be said.
local function attributesWith(what)
    local deltas, doubts = {}, {}
    for i, key in ipairs(ATTRIBUTE_KEYS) do
        local a = STAT_BY_KEY[key]
        local delta, doubt = nil, nil
        if a and a.sources then
            delta, doubt = changeOf(a, what)
        end
        deltas[i] = delta or 0
        doubts[i] = doubt or nil
    end
    return deltas, doubts
end

-- `what` with what it would change of the attributes (`attributes`) and why each change can't be said (`doubts`):
-- worked out once for every value it is tried on.
function Tried.With(what)
    local tried = {}
    for k, v in pairs(what) do
        tried[k] = v
    end
    tried.attributes, tried.doubts = attributesWith(what)
    return tried
end

-- A value the sources follow a change of by an estimate alone: the health's regeneration, the game giving the spirit's
-- share of it at the spirit now alone (Tried.HealthFromSpirit, the original server's slope): "estimate", its figure
-- said with the game's question after it (Ikar 2026-11-26: "Everything should follow, every, single, line"); its
-- question alone for a class the original server hasn't, the spirit's own where its change can't be said
-- (Tried.DoubtOf: the regeneration's readings ask for the spirit). The mana's follows it (Tried.ManaFromSpirit).
local function untold(s, tried)
    local guess = s.key == "HEALTH_REGEN" and Tried.SpiritGuess(tried)
    if guess == "unknown" then
        return L.STAT_WHY_SPIRIT
    end
    return nil, guess == "estimate"
end

-- The value `s` with `what` in place (`tried`: Tried.With's of it, when already had): nil when nothing of it would
-- change; else its sources then (list), those now (now), by how much it would change (delta), what it would be where
-- the game gives its number (value), and whether that can't be said (unsure): its own question, or an attribute's it
-- stands on (one a consumable's buff of no known figure would change asks nothing of the resistances).
local function wouldBe(s, what, tried)
    tried = tried or Tried.With(what)
    local was = Tried.leaned
    Tried.leaned = {}
    local ok, delta, unsure, nowList, wouldList, _, effective = pcall(changeOf, s, tried)
    local stands = Tried.leaned
    Tried.leaned = was
    if not ok then
        error(delta, 0)
    end
    local question, estimate = untold(s, tried)
    unsure = unsure or Tried.DoubtOf(tried, stands) or question
    -- what the game's sums leave over is the value's as it is: the same in both
    for _, e in ipairs(nowList) do
        if e.other then
            wouldList[#wouldList + 1] = e
        end
    end
    -- nothing of it would change: the same sources by the same amounts, in whatever order
    local function written(list)
        local all = {}
        for _, e in ipairs(list) do
            all[#all + 1] = tostring(e.name) .. "\1" .. tostring(e.points) .. "\1" .. tostring(e.share) .. "\1"
                .. tostring(e.keep)
        end
        table.sort(all)
        return table.concat(all, "\2")
    end
    if not unsure and (not delta or (delta < 0.005 and delta > -0.005)) and written(nowList) == written(wouldList) then
        return nil
    end
    return { list = wouldList, now = nowList, delta = delta or 0, value = effective and delta and effective + delta,
        unsure = unsure, estimate = estimate and not unsure or nil }
end

-- A row's figure without its colours, for one that is said in one colour whole.
local function plainText(text)
    return ((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
-- The arrow from what is to what would be: the game's own, as its character creation writes one in a line
-- (CreateAtlasMarkup("common-icon-forwardarrow", 8, 13)); the font has no "→", which showed as an empty box (Ikar's
-- screenshot of 2026-11-19).
local ARROW = "|A:common-icon-forwardarrow:13:8:0:0|a"
Stats.ARROW = ARROW
-- A figure and what it would be.
local function became(old, new)
    return Infos.Color(old, WAS_HEX) .. " " .. ARROW .. " " .. Infos.Color(new, WOULD_HEX)
end
Stats.Became = became

-- The rows as they would be, beside those as they are (a row is the same by its name, or by what it is where its name
-- holds a figure of what is tried: `match`, the armour of the damage reduction, the defence in a sum): one that would
-- come, its figure in the blue; one whose figure would change, both; one that would go, after the row it follows now,
-- greyed, its figure down to 0. A row of a table (the regenerations', `cells`: a figure a state), each of its figures
-- so.
local function mergeRows(now, would)
    local function keyOf(row)
        if row.match then
            return "\2" .. row.match
        end
        return row.left and (plainText(row.left) .. (row.group and "\1" or "")) or nil
    end
    -- what would come: blue; what changes: what is, the arrow, what would be; what goes: down to 0
    local function come(text)
        return text ~= "" and Infos.Color(plainText(text), WOULD_HEX) or text
    end
    local function change(old, new)
        local a, b = plainText(old), plainText(new)
        return a ~= b and became(a, b ~= "" and b or "0") or new
    end
    local function gone(text)
        return plainText(text) ~= "" and became(plainText(text), "0") or text
    end
    local had, stays = {}, {}
    for _, row in ipairs(now) do
        local key = keyOf(row)
        if key then
            had[key] = had[key] or row
        end
    end
    local out, at = {}, {}
    for _, row in ipairs(would) do
        local key = keyOf(row)
        local old = key and had[key]
        if key and not old then
            row.right = row.right and come(row.right)
            for i, c in pairs(row.cells or {}) do
                row.cells[i] = come(c)
            end
        elseif old then
            stays[key] = true
            row.right = row.right and change(old.right, row.right)
            for i in pairs(row.cells or {}) do
                row.cells[i] = change((old.cells or {})[i], row.cells[i])
            end
        end
        out[#out + 1] = row
        if key then
            at[key] = #out
        end
    end
    local after = 0
    for _, row in ipairs(now) do
        local key = keyOf(row)
        if key and stays[key] then
            after = at[key] or after
        elseif key and not row.group then
            -- (a group's name gone, its rows down to one, isn't a figure lost)
            after = after + 1
            local cells
            for i, c in pairs(row.cells or {}) do
                cells = cells or {}
                cells[i] = gone(c)
            end
            table.insert(out, after, { left = plainText(row.left), right = row.right and became(plainText(row.right), "0"),
                cells = cells, indent = row.indent, color = Infos.GREY })
            for k, i in pairs(at) do
                if i >= after then
                    at[k] = i + 1
                end
            end
        end
    end
    return out
end

-- ---------- The regenerations, a figure for each state (Ikar 2026-11-23: "A, a table, and everything per 5s") ----------
-- Each source of the mana's or the health's regeneration in each state the game splits it by, every figure per 5 s as
-- its sheet's own, cut to a whole as it writes them (the mana's a second's, to a tenth, with the option: "Add an option
-- to show mana as per second in the settigns menu"): the mana out of casting and in it (the 5 s after spending mana,
-- when the spirit's stops: the game's own « hors incantation »), the health standing, seated or lying down (the
-- spirit's a third more, the sheet's standing figure three quarters of GetHealthRegenFromSpirit's: asked, the original
-- server's a half) and in a fight. A share kept while casting or in a fight (134, 116) in that state's column alone,
-- with what it comes to. Under « En plus du chiffre du jeu », what an aura gives by itself every few seconds, which the
-- game's figures don't count (Data/Effects.lua's PERIODIC: Blessing of Wisdom, Mana Spring Totem, Mana Tide, the
-- soups, a HoT, eating's health seated; the camp's well, from its tooltip, Stats.HiddenParts), its own rhythm under
-- its name when it isn't 5 s (the review of 2026-11-23: the camp's well had been the one said of 56 such spells). At
-- the foot the totals, what the line and the head show ("everything per 5s"), the game's own under the head.
do
    local MANA_STATES, HEALTH_STATES = { "out", "cast" }, { "stand", "seat", "fight" }
    -- not in that state: the game's dash, grey
    local NONE = Infos.Color("–", "ff808080")
    local EPSILON = 1e-6

    function Stats.PerSecond()
        return ns.db ~= nil and type(ns.db.options) == "table" and ns.db.options.manaPerSecond == true
    end
    -- the regenerations drawn as a table: the mana's while the character has mana, the health's
    function Stats.IsRegen(s)
        return s.key == "HEALTH_REGEN" or s.key == "REGEN" and hasMana()
    end
    -- A figure of `key`'s in its unit: per 5 s cut to a whole, a second's to a tenth.
    local function figure(key, v)
        if key == "REGEN" and Stats.PerSecond() then
            return Format.Decimal(v / 5, 1)
        end
        return number(floor(v + EPSILON))
    end
    -- one that changes the value: signed, green or red
    local function plus(key, v)
        return signed(v, figure(key, v))
    end
    -- a state first, the other in brackets: casting, or a fight, the sheet's first
    function Stats.RegenText(key, states, values)
        local first = states[#states == 2 and 2 or 3]
        return string.format("%s (%s)", figure(key, values[first]), figure(key, values[states[1]]))
    end

    -- An aura's points for one of its spell's effects (pointOf's numbering); nil where it gives none.
    local function auraPoint(aura, count, auras, index, place)
        local points = ns.Plain(aura.points)
        local v
        if type(points) == "table" then
            if #points >= count then
                v = points[index + 1]
            elseif #points == auras then
                v = points[place + 1]
            end
        end
        v = ns.Plain(v)
        return type(v) == "number" and v ~= 0 and v or nil
    end

    -- What `spell` gives by itself every few seconds of `key`'s (24 the mana's; 8, 20 and 84 the health's): each effect
    -- { per5, every, amount, eating }, its amount the aura's own, else the data's where it's the same whoever casts it,
    -- else none (its question: a HoT's grows with its caster's healing).
    local function gainsOf(key, spell, aura)
        local known = ns.PERIODIC and ns.PERIODIC[spell]
        local count, auras, effects = (known or ""):match("^(%d+),(%d+);(.+)$")
        local out = {}
        for kind, index, place, period, fixed in (effects or ""):gmatch("(%d+):(%d+):(%d+):(%d+):([^;]*)") do
            kind = tonumber(kind)
            if (key == "REGEN") == (kind == 24) then
                local amount = aura and auraPoint(aura, tonumber(count), tonumber(auras), tonumber(index),
                    tonumber(place)) or fixedPoints(fixed)
                if amount and kind == 20 then
                    -- a share of the most health
                    local most = ns.Plain(UnitHealthMax("player"))
                    amount = type(most) == "number" and most * amount / 100 or nil
                end
                local every = tonumber(period) / 1000
                if amount ~= 0 then
                    out[#out + 1] = { per5 = amount and amount * 5 / every, every = every, amount = amount,
                        eating = kind == 84 }
                end
            end
        end
        return out
    end

    -- Every such gain the character has now, and those `tried` would bring (a meal tried on a card kept open: its
    -- spells, the data's figures), each { name, per5, every, amount, eating, tip, tried, why }; none in a fight, the
    -- auras' points hidden then.
    function Stats.Gains(key, tried)
        local list, seen = {}, {}
        if ns.InCombat() then
            return list
        end
        for i = 1, 255 do
            local aura = ns.Plain(C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL"))
            if type(aura) ~= "table" then
                break
            end
            local spell = ns.Plain(aura.spellId)
            if spell then
                seen[spell] = true
                local name = iconed(ns.Plain(aura.icon), ns.Plain(aura.name) or "?")
                local tip = { aura = ns.Plain(aura.auraInstanceID), spell = spell }
                for _, g in ipairs(gainsOf(key, spell, aura)) do
                    g.name, g.tip = name, tip
                    list[#list + 1] = g
                end
                -- the camp's, which its tooltip names: its well's mana
                if key == "REGEN" then
                    for _, part in ipairs(Stats.HiddenParts(aura) or {}) do
                        local n = part.points[0]
                        if type(part.every) == "number" and part.every > 0 and type(n) == "number" and n > 0 then
                            list[#list + 1] = { name = iconed(spellIcon(part.spell),
                                string.format(L.STAT_CAMP_PART, part.name)), per5 = n * 5 / part.every,
                                every = part.every, amount = n, tip = { aura = tip.aura, spell = part.spell } }
                        end
                    end
                end
            end
        end
        for _, spell in ipairs(type(tried) == "table" and tried.uses or {}) do
            if not seen[spell] then
                for _, g in ipairs(gainsOf(key, spell, nil)) do
                    g.name, g.tried = iconed(tried.icon, tried.name or "?"), true
                    list[#list + 1] = g
                end
            end
        end
        for _, g in ipairs(list) do
            g.why = not g.per5 and string.format(L.STAT_WHY_CASTER, nameOf(g.name)) or nil
        end
        return list
    end

    -- `key`'s game figures per 5 s by state, the gains (Stats.Gains) and the totals with them, the line's and the
    -- head's; nil in a fight (the game hides its figures, the auras' points) or without mana.
    function Stats.RegenTotals(key, tried)
        if ns.InCombat() then
            return nil
        end
        local game = {}
        if key == "REGEN" then
            local base, casting = ns.Plain(GetManaRegen())
            if not hasMana() or type(base) ~= "number" or type(casting) ~= "number" then
                return nil
            end
            game.out, game.cast = base * 5, casting * 5
        else
            local out, fight = ns.Plain(GetHealthRegen())
            if type(out) ~= "number" or type(fight) ~= "number" then
                return nil
            end
            local spirit = ns.Plain(GetHealthRegenFromSpirit())
            game.stand, game.fight = out * 5, fight * 5
            game.seat = game.stand + (type(spirit) == "number" and spirit * 5 * 0.25 or 0)
        end
        local states = key == "REGEN" and MANA_STATES or HEALTH_STATES
        local gains = Stats.Gains(key, tried)
        local totals = {}
        for _, state in ipairs(states) do
            local sum = floor(game[state] + EPSILON)
            for _, g in ipairs(gains) do
                if g.per5 and (not g.eating or state == "seat") then
                    sum = sum + floor(g.per5 + EPSILON)
                end
            end
            totals[state] = sum
        end
        return { game = game, totals = totals, gains = gains, states = states }
    end

    -- The line's text, all the character gets, and the game's own for the card's head where it differs.
    function Stats.RegenLine(key)
        local r = Stats.RegenTotals(key)
        if not r then
            return nil
        end
        local total, own = Stats.RegenText(key, r.states, r.totals), Stats.RegenText(key, r.states, r.game)
        return total, own ~= total and string.format(L.STAT_GAME_FIGURE, own) or nil
    end

    -- The card's table of `s` from its tally `list` (sourcesOf's: out of casting, or standing): what the value stands
    -- on, the gear, the sets, the rest under « Bonus », what's left; what the game doesn't count; the totals; each row
    -- a figure a state. `tried`: what is tried on a card kept open, its gains among them; `was`, the table as it is,
    -- whose leftover in casting or a fight is the value's as it is, the same in both (the game's figure doesn't change
    -- with what is only tried). Also what the named flat changes and the shares kept come to, for what would be. Nil
    -- while the game hides its figures.
    function Stats.RegenTable(s, list, tried, was)
        local key = s.key
        local r = Stats.RegenTotals(key, tried)
        if not r then
            return nil
        end
        local mana, states = key == "REGEN", r.states
        local inner = mana and "cast" or "fight"
        -- the spirit's part out of casting or standing, seated (the game's call, the sheet's three quarters); with the
        -- spirit tried, while the table tried is read (regenTried), the mana's and the health's (its estimate)
        local spirit
        if mana then
            spirit = Tried.ManaFromSpirit()
        else
            spirit = Tried.HealthFromSpirit()
        end
        spirit = (type(spirit) == "number" and spirit or 0) * 5
        local base = mana and spirit or spirit * 0.75
        -- what the shares kept come to, each the cut of their sum with those before it less theirs, so that they add
        -- up; whether a figure is missing or a share isn't worked out (no « Autres » then)
        local kept, keptSum, named, open = {}, 0, 0, false
        for _, e in ipairs(list) do
            if e.keep then
                local before = floor(keptSum + EPSILON)
                keptSum = keptSum + base * e.keep
                kept[e] = floor(keptSum + EPSILON) - before
            end
            if not e.base and not e.other and not e.mistake and not e.next then
                named = named + (type(e.points) == "number" and e.points or 0)
                open = open or e.share ~= nil or e.unsure == true
                    or (e.points == nil and e.share == nil and e.keep == nil)
            end
        end
        local function cellsOf(e)
            local cells = {}
            for i, state in ipairs(states) do
                local parts = {}
                if e.points and e.points ~= 0 then
                    parts[#parts + 1] = plus(key, e.points)
                end
                if e.share and e.share ~= 0 and state ~= inner then
                    parts[#parts + 1] = signed(e.share, Format.Percent(e.share))
                end
                if e.keep and state == inner then
                    parts[#parts + 1] = Format.Percent(e.keep) .. " (" .. plus(key, kept[e] or 0) .. ")"
                end
                if e.unsure or (e.points == nil and e.share == nil and e.keep == nil) then
                    parts[#parts + 1] = ask(e.why)
                end
                cells[i] = #parts > 0 and table.concat(parts, " ") or NONE
                if e.next then
                    cells[i] = bare(cells[i])
                end
            end
            return cells
        end
        local rows, gear, sets, rest, rests = {}, {}, {}, {}, {}
        for i, e in ipairs(list) do
            if e.base and not e.other and not e.mistake then
                -- the spirit's: out of casting or standing, seated a third more (asked), 0 in casting or a fight; the
                -- health's by the spirit tried an estimate, asked standing too (Tried.HealthFromSpirit)
                local cells = {}
                for n, state in ipairs(states) do
                    if state == "seat" then
                        cells[n] = figure(key, spirit) .. " " .. ask(L.STAT_WHY_SEATED)
                    elseif state == inner then
                        cells[n] = figure(key, 0)
                    elseif not mana and Tried.SpiritGuess(WOULD) == "estimate" then
                        cells[n] = figure(key, base) .. " " .. ask(L.STAT_WHY_SPIRIT)
                    else
                        cells[n] = figure(key, base)
                    end
                end
                rows[#rows + 1] = { left = e.name, cells = cells, tip = e.tip }
            elseif e.other or e.mistake then
                rests[#rests + 1] = e
            elseif e.next or e.kind == "set" then
                sets[#sets + 1] = e
            elseif e.kind == "gear" then
                gear[#gear + 1] = { e = e, i = i }
            else
                rest[#rest + 1] = e
            end
        end
        -- the gear by slot, as the other cards' (an item's own rows in their order)
        table.sort(gear, function(a, b)
            local sa, sb = a.e.slot or 99, b.e.slot or 99
            if sa ~= sb then
                return sa < sb
            end
            return a.i < b.i
        end)
        local function group(name, entries)
            if #entries == 0 then
                return
            end
            rows[#rows + 1] = { left = name, cells = {}, group = true }
            for _, x in ipairs(entries) do
                local e = x.e or x
                rows[#rows + 1] = { left = e.name, cells = cellsOf(e), indent = true,
                    tip = e.tip or (e.slot and { slot = e.slot }) or nil, color = e.next and Infos.GREY or nil }
            end
        end
        group(L.STAT_GEAR, gear)
        group(L.STAT_SETS, sets)
        if (#rest > 0 or #rests > 0) and #rows > 0 then
            rows[#rows + 1] = { rule = true }
        end
        group(L.STAT_BONUS, rest)
        -- what's left: out of casting or standing the tally's (« Autres », the addon's mistake below 0); casting or in a
        -- fight the game's figure less what's named there, none beside a share not worked out or a figure missing
        local outer
        for _, e in ipairs(rests) do
            outer = (outer or 0) + (type(e.points) == "number" and e.points or 0)
        end
        local within
        if was then
            within = was.within
        elseif not open then
            local v = r.game[inner] - named - keptSum
            within = (v >= 0.5 or v <= -0.5) and floor(v + 0.5) or nil
        end
        if outer or within then
            local cells, wrong = {}, false
            for i, state in ipairs(states) do
                local v = state == inner and within or i == 1 and outer or nil
                if v and v < 0 then
                    wrong = true
                    cells[i] = Infos.Color(figure(key, v), Infos.BAD) .. " " .. ask(L.STAT_ADDON_ERROR_LESS)
                elseif v then
                    cells[i] = plus(key, v)
                else
                    cells[i] = ""
                end
            end
            rows[#rows + 1] = { left = wrong and L.STAT_ADDON_ERROR or L.STAT_OTHER, cells = cells, indent = #rest > 0,
                color = wrong and MISTAKE or Infos.GREY }
        end
        -- what the game's figures don't count, its rhythm under it when it isn't 5 s
        if #r.gains > 0 then
            rows[#rows + 1] = { rule = true }
            rows[#rows + 1] = { left = L.STAT_EXTRA, cells = {}, group = true }
            for _, g in ipairs(r.gains) do
                local cells = {}
                for i, state in ipairs(states) do
                    if g.eating and state ~= "seat" then
                        cells[i] = NONE
                    elseif g.per5 then
                        cells[i] = plus(key, g.per5)
                    else
                        cells[i] = ask(g.why)
                    end
                end
                rows[#rows + 1] = { left = g.name, cells = cells, indent = true, tip = g.tip }
                if g.amount and math.abs(g.every - 5) > EPSILON then
                    rows[#rows + 1] = { left = string.format(L.STAT_RHYTHM, number(floor(g.amount + 0.5)),
                        number(g.every)), cells = {}, indent = 2, small = true, color = Infos.GREY }
                end
            end
        end
        rows[#rows + 1] = { rule = true }
        local cells = {}
        for i, state in ipairs(states) do
            cells[i] = figure(key, r.totals[state])
        end
        rows[#rows + 1] = { left = L.STAT_TOTAL, cells = cells, total = true }
        return { rows = rows, totals = r.totals, game = r.game, gains = r.gains, states = states, named = named,
            spirit = spirit,
            within = within,
            keptSum = keptSum, captions = mana and { L.STAT_COL_OUT_CAST, L.STAT_COL_CASTING }
                or { L.STAT_COL_STANDING, L.STAT_COL_SEATED, L.STAT_COL_FIGHT } }
    end

    -- What `what` would make of the table of `s` (its tally `list`; `would`, wouldBe's): the table now, the table
    -- tried, each state's total; no totals where nothing of it would change. Out of casting or standing by what the
    -- tally would change, casting or in a fight by what the flat changes and the shares kept would, and the gains
    -- tried. With them why the totals can't be said: a gain tried of no known figure, which they leave out (its row
    -- asks it). `what` with the attributes' changes (Tried.With's): the table tried read with it in place (WOULD), the
    -- spirit's share and what is kept of it while casting the spirit tried's (Tried.ManaFromSpirit).
    local function regenTried(s, list, what, would)
        local now = Stats.RegenTable(s, list or {}, nil)
        local tried
        if now and what then
            local was = WOULD
            WOULD = what
            local ok, t = pcall(Stats.RegenTable, s, would and would.list or list or {}, what, now)
            WOULD = was
            if not ok then
                error(t, 0)
            end
            tried = t
        end
        if not (tried and (would or #tried.gains > #now.gains)) then
            return now
        end
        local inner = s.key == "REGEN" and "cast" or "fight"
        local totals = {}
        for i, state in ipairs(tried.states) do
            local change = state == inner and (tried.named - now.named + tried.keptSum - now.keptSum)
                or (would and would.delta or 0)
            -- (seated, the spirit's part whole where standing has three quarters of it: RegenTotals' seat)
            if state == "seat" then
                change = change + (tried.spirit - now.spirit) * 0.25
            end
            totals[state] = tried.totals[state] + change
            tried.rows[#tried.rows].cells[i] = figure(s.key, totals[state])
        end
        local unknown
        for _, g in ipairs(tried.gains) do
            if g.tried and not g.per5 then
                unknown = unknown or g.why
            end
        end
        return now, tried, totals, would and would.unsure or unknown
    end

    -- The line's figures as `what` would make them (`would`, wouldBe's), in the blue; the game's question mark
    -- where they can't be said; nil where they wouldn't change.
    function Stats.RegenLineWould(s, what, would)
        local now, tried, totals, unsure = regenTried(s, would and would.now or sourcesOf(s, true, false), what, would)
        if not totals then
            return nil
        elseif unsure then
            return UNKNOWN
        end
        local text = Stats.RegenText(s.key, tried.states, totals)
        if text == Stats.RegenText(s.key, now.states, now.totals) then
            return nil
        end
        -- (an estimate, the health's by the spirit tried: the game's question after it)
        return Infos.Color(text, WOULD_HEX) .. (would and would.estimate and " " .. UNKNOWN or "")
    end

    -- The card's table, and what `what` would make of it on a card kept open: its rows beside the table now (the
    -- blue), its totals, the head's (`data.regenWould`).
    function Stats.RegenCard(data, s, list, what, would)
        local now, tried, totals, unsure = regenTried(s, list, what, would)
        if not now then
            return false
        end
        data.sourcesTitle = L.STAT_SOURCES .. " ("
            .. ((s.key == "REGEN" and Stats.PerSecond()) and L.STAT_PER_SECOND or L.STAT_PER_5S) .. ")"
        data.sources, data.columns = now.rows, now.captions
        if not totals then
            return true
        end
        data.sources, data.wide = mergeRows(now.rows, tried.rows), true
        local was = Infos.Color(Stats.RegenText(s.key, now.states, now.totals), WAS_HEX) .. " " .. ARROW
        if unsure then
            data.regenWould = { value = ask(unsure), detail = was }
        else
            data.regenWould = { value = Infos.Color(Stats.RegenText(s.key, tried.states, totals), WOULD_HEX)
                .. (would and would.estimate and " " .. ask(L.STAT_WHY_SPIRIT) or ""), detail = was }
        end
        return true
    end
end

-- What raises the experience gained now, for the XP bar's tooltip (UI/StatusBars.lua; Ikar 2026-11-23: "the xp bar
-- shoudl also have all the bonuses listed (and the total) this include any buff to xp, sleeping bag, rewsted, camp,
-- food etc."): the rest's, the game's own state (GetRestState's share of the creatures' experience, while there is
-- rest left); each aura the data says changes it (Data/Effects.lua's XP_BONUSES: the sleeping bag's « Bien reposé »,
-- an elixir, an event's), at the aura's own figures, else the data's; the hidden ones a visible aura's tooltip writes
-- (XP_PARTS: a meal's « Bien nourri »), under that aura's name. The camp's tents add to the rest, its benefits give no
-- experience (the game's data). Each { name, kills, quests }, in percent; none in a fight, the auras' figures hidden.
function Stats.XPBonuses()
    local list = {}
    if ns.InCombat() then
        return list
    end
    local _, rest, mult = ns.Plain(GetRestState())
    if type(mult) == "number" and mult > 1 and (ns.Plain(GetXPExhaustion()) or 0) > 0 then
        list[#list + 1] = { name = type(rest) == "string" and rest or L.XP_RESTED, kills = (mult - 1) * 100, quests = 0 }
    end
    local function add(e, gives, value)
        for kind, index, data in gives:gmatch("(%a):(%d+):([%d%.]+)") do
            local v = value(tonumber(index)) or tonumber(data) or 0
            if kind == "k" then
                e.kills = e.kills + v
            else
                e.quests = e.quests + v
            end
        end
        if e.kills ~= 0 or e.quests ~= 0 then
            list[#list + 1] = e
        end
    end
    for i = 1, 255 do
        local aura = ns.Plain(C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL"))
        if type(aura) ~= "table" then
            break
        end
        local spell = ns.Plain(aura.spellId)
        local name = iconed(ns.Plain(aura.icon), ns.Plain(aura.name) or "?")
        local gives = spell and ns.XP_BONUSES and ns.XP_BONUSES[spell]
        if gives then
            local points = ns.Plain(aura.points)
            add({ name = name, kills = 0, quests = 0 }, gives, function(index)
                local v = type(points) == "table" and ns.Plain(points[index + 1])
                return type(v) == "number" and v or nil
            end)
        end
        if spell and ns.XP_PARTS and ns.XP_PARTS[spell] then
            for _, part in ipairs(Stats.HiddenParts(aura, ns.XP_PARTS) or {}) do
                local hidden = ns.XP_BONUSES and ns.XP_BONUSES[part.spell]
                if hidden then
                    -- (what the line doesn't write, none: a meal's gives the creatures' alone)
                    add({ name = name, kills = 0, quests = 0 }, hidden:gsub("(%a:%d+):[%d%.]+", "%1:0"), function(index)
                        return part.points[index]
                    end)
                end
            end
        end
    end
    return list
end

-- What raises the reputation gained with the faction `id`, for the reputation bar's tooltip (UI/StatusBars.lua; Ikar
-- 2026-11-23: "Reputation bonuses to the rep bar"), as the experience's: each aura, or passive spell known (a race's,
-- which no aura shows), the data says changes it (Data/Effects.lua's REP_BONUSES: the human's Diplomacy, +10 % with
-- every faction; Cenarion Favor, +25 % with the Cenarion Circle alone), at the aura's own figure, else the data's. Each
-- { name, share } in percent, the spells' order; none in a fight.
function Stats.RepBonuses(id)
    local list = {}
    if ns.InCombat() or type(ns.REP_BONUSES) ~= "table" then
        return list
    end
    local function add(spell, name, points)
        local v = 0
        for kind, index, data, faction in (ns.REP_BONUSES[spell] or ""):gmatch("(%a):(%d+):([%d%.]+):?(%d*)") do
            if kind == "a" or tonumber(faction) == id then
                v = v + (points and points(tonumber(index)) or tonumber(data) or 0)
            end
        end
        if v ~= 0 then
            list[#list + 1] = { name = name, share = v }
        end
    end
    local seen = {}
    for i = 1, 255 do
        local aura = ns.Plain(C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL"))
        if type(aura) ~= "table" then
            break
        end
        local spell = ns.Plain(aura.spellId)
        if spell and ns.REP_BONUSES[spell] then
            seen[spell] = true
            local points = ns.Plain(aura.points)
            add(spell, iconed(ns.Plain(aura.icon), ns.Plain(aura.name) or "?"), function(index)
                local own = type(points) == "table" and ns.Plain(points[index + 1])
                return type(own) == "number" and own ~= 0 and own or nil
            end)
        end
    end
    local isKnown, spells = C_SpellBook and C_SpellBook.IsSpellKnown, {}
    for spell in pairs(ns.REP_BONUSES) do
        spells[#spells + 1] = spell
    end
    table.sort(spells)
    for _, spell in ipairs(spells) do
        if not seen[spell] and type(isKnown) == "function" and ns.Call(isKnown, spell) == true then
            add(spell, iconed(spellIcon(spell), spellName(spell)), nil)
        end
    end
    return list
end

-- The left of the card: where the value comes from, the kind of attack after the column's title for a value that is
-- the best of three (« Sources (Mêlée) »). With `what`, the card kept open's (what is tried, Tried.what): what it
-- would change beside it, worked out anew at each drawing (an aura come or gone may change it, no value with it), kept
-- for its effects (`data.tried`, Tried.Effects). `again`: the card drawn again, no new look at it.
local function cardSources(data, s, what, again)
    local tried = what and Tried.With(what)
    data.tried = tried
    local would = tried and wouldBe(s, what, tried)
    local list, channel = sourcesOf(s, true, would ~= nil)
    -- (what it can't account for kept for the bug report, apart: a failure there leaves the card whole)
    if list and ns.StatCheck then
        ns.SafeCall(ns.StatCheck.Note, s, list, channel, nil, nil, again)
    end
    -- the regenerations: a table, a figure a state (Stats.RegenCard)
    if Stats.IsRegen(s) and Stats.RegenCard(data, s, list, tried, would) then
        return
    end
    if would then
        list = list or {}
    end
    if not list then
        -- nothing gives it, at 0: said, its column not left out (Ikar 2026-11-19: "expertise is 0")
        local v
        if s.total then
            v = s.total()
        elseif s.numbers then
            v = select(2, s.numbers())
        end
        if v == 0 and not ns.InCombat() then
            data.sourcesTitle = L.STAT_SOURCES
            data.sources = { { left = G("NONE", "None"), right = "", color = Infos.GREY } }
        end
        return
    end
    local word = channel and CHANNEL_WORDS[channel]
    data.sourcesTitle = L.STAT_SOURCES .. (word and (" (" .. G(word[1], word[2]) .. ")") or "")
    data.sources = sourceRows(s, list)
    if would then
        data.sources, data.would, data.wide = mergeRows(data.sources, sourceRows(s, would.list)), would, true
    end
end

-- What is under the pointer, for the card kept open (nil: nothing to try). An item that could be worn: in its slot
-- (a ring's, a trinket's, a one-handed weapon's first), a two-handed one emptying the off hand, a shield, an off-hand
-- weapon or a held item taking a two-handed weapon worn off with it (as the game's comparison shows both; Ikar
-- 2026-11-26: "when hovering a shield, does it also take into account the new main weapon ? in case you had a 2h
-- weapon ?"); none for one worn already. A consumable, a meal: the spells it puts on whoever uses it, where the data has some for the sheet
-- (Data/Effects.lua's ITEM_USES, a meal's buff followed from its eating); one without changes nothing. A talent: at
-- its next rank, a rank of one for one not bought.
local EQUIP_SLOTS = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_SHIELD = 17, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18,
    INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_RELIC = 18, INVTYPE_TABARD = 19,
}
local function itemTried(link)
    if type(link) ~= "string" or not (C_Item and C_Item.GetItemInfo) then
        return nil
    end
    local info = { pcall(C_Item.GetItemInfo, link) }
    if not info[1] or info[2] == nil then
        return nil
    end
    local slot = EQUIP_SLOTS[info[10] or ""]
    -- (a quiver or an ammunition pouch, in a bag's slot: in the worn one's place, Tried.Quiver)
    if info[13] == (Enum.ItemClass and Enum.ItemClass.Quiver or 11) then
        return link ~= Tried.WornQuiver() and { quiver = link } or nil
    end
    if slot then
        for worn = FIRST_SLOT, LAST_SLOT do
            if GetInventoryItemLink("player", worn) == link then
                return nil
            end
        end
        local links = { [slot] = link }
        if info[10] == "INVTYPE_2HWEAPON" then
            links[17] = false
        elseif slot == 17 then
            local worn = GetInventoryItemLink("player", 16)
            local ok, _, _, _, equip = pcall(C_Item.GetItemInfoInstant, worn or "")
            if worn and ok and equip == "INVTYPE_2HWEAPON" then
                links[16] = false
            end
        end
        return { links = links }
    end
    local id, name = tonumber(link:match("item:(%d+)")), link:match("%[(.-)%]") or tostring(info[2])
    local uses = id and ns.ITEM_USES and ns.ITEM_USES[id]
    if uses then
        local spells = {}
        for spell in uses:gmatch("%d+") do
            spells[#spells + 1] = tonumber(spell)
        end
        local icon = C_Item.GetItemInfoInstant and select(6, pcall(C_Item.GetItemInfoInstant, link))
        return { uses = spells, name = name, icon = icon }
    end
end

-- A talent not bought, by its spell: its ranks and its name, read as the talents bought are (talents, above).
local function talentUnbought(spell)
    local config = C_ClassTalents and ns.Call(C_ClassTalents.GetActiveConfigID)
    local info = config and C_Traits and ns.Call(C_Traits.GetConfigInfo, config)
    for _, tree in ipairs(type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs or {}) do
        local nodes = ns.Call(C_Traits.GetTreeNodes, tree)
        for _, node in ipairs(type(nodes) == "table" and nodes or {}) do
            local n = ns.Call(C_Traits.GetNodeInfo, config, node)
            local entryID = type(n) == "table" and (tonumber(n.activeRank) or 0) == 0 and type(n.entryIDs) == "table"
                and n.entryIDs[1]
            local entry = entryID and ns.Call(C_Traits.GetEntryInfo, config, entryID)
            local definition = type(entry) == "table" and entry.definitionID
                and ns.Call(C_Traits.GetDefinitionInfo, entry.definitionID)
            if type(definition) == "table" and definition.spellID == spell then
                return { spell = spell, rank = 1, ranks = tonumber(n.maxRanks) or 1,
                    name = type(definition.overrideName) == "string" and definition.overrideName ~= ""
                        and definition.overrideName or spellName(spell) }
            end
        end
    end
end
local function talentTried(spell)
    if type(spell) ~= "number" or not (ns.EFFECTS and ns.EFFECTS[spell]) then
        return nil
    end
    local list, found = {}, false
    for _, talent in ipairs(talents()) do
        if talent.spell == spell then
            if talent.rank >= talent.ranks then
                return nil
            end
            found = true
            list[#list + 1] = { spell = spell, rank = talent.rank + 1, ranks = talent.ranks, name = talent.name }
        else
            list[#list + 1] = talent
        end
    end
    if not found then
        local unbought = talentUnbought(spell)
        if not unbought then
            return nil
        end
        list[#list + 1] = unbought
    end
    return { talents = list }
end

-- The card kept open's effects as what is tried would make them (Ikar 2026-11-25: "when hovering an item, it doesn't
-- seems to update everything, the output for example"): its figures read again with it in place (WOULD), each the
-- same by what it is a figure of, as the sources' rows (mergeRows): one that would change, what is greyed, the arrow
-- and what would be in the blue; one that would come, in the blue; one that would go, down to 0; the game's question
-- mark where its change can't be said (an attribute's or a value's it stands on: Tried.DoubtOf; the health the
-- spirit would give, GIVES.SPIRIT). What is tried worked out anew, as its sources' (cardSources' `data.tried`).
function Tried.Effects(data, s)
    local tried = data.tried or Tried.With(Tried.what)
    local was, leaned = WOULD, Tried.leaned
    WOULD, Tried.leaned = tried, {}
    local ok, list = pcall(s.gives)
    local stands = Tried.leaned
    WOULD, Tried.leaned = was, leaned
    if not ok then
        error(list, 0)
    end
    local doubt = Tried.DoubtOf(tried, stands)
    local by, out, seen = {}, {}, {}
    for _, t in ipairs(list or {}) do
        by[plainText(t.caption)] = t
    end
    for _, t in ipairs(data.tiles) do
        local key, old = plainText(t.caption), plainText(t.figure)
        local new = by[key]
        seen[key] = true
        local figure = t.figure
        if doubt or (new and new.figure == UNKNOWN) then
            figure = Infos.Color(old, WAS_HEX) .. " " .. ARROW .. " " .. ask(doubt)
        elseif not new then
            figure = became(old, "0")
        elseif plainText(new.figure) ~= old then
            figure = became(old, plainText(new.figure))
        end
        out[#out + 1] = { figure = figure, caption = t.caption }
    end
    for _, t in ipairs(list or {}) do
        if not seen[plainText(t.caption)] then
            out[#out + 1] = { figure = doubt and ask(doubt) or Infos.Color(plainText(t.figure), WOULD_HEX),
                caption = t.caption }
        end
    end
    data.tiles = out
end

-- The card of the value `s` over `owner`. What failed once isn't read again this session, as read's. With `keep`, the
-- card a click keeps open: its foot without what a click does nor the hub's hints, the pointer not being on it.
-- `again`: the card kept open drawn again, or kept open by the click on what its hover showed, no new look at it.
local function showCard(owner, s, keep, again)
    questions = {}
    local text, parts = read(s)
    local data = { title = (s.title or s.name)(), value = text or "—", detail = text and parts or nil,
        sources = {}, about = {}, effects = {}, tiles = {}, hints = {},
        sourcesTitle = L.STAT_SOURCES, aboutTitle = L.STAT_ABOUT, effectsTitle = L.STAT_EFFECTS }
    if not text then
        data.about[1] = { text = L.HIDDEN_IN_FIGHT, color = Infos.WHITE }
    end
    if text and not brokenTexts[s.key] and not ns.SafeCall(cardTexts, data, s) then
        brokenTexts[s.key] = true
        data.about, data.effects, data.tiles = {}, {}, {}
    end
    if text and s.sources and not brokenSources[s.key]
        and not ns.SafeCall(cardSources, data, s, keep and Tried.what or nil, again) then
        brokenSources[s.key] = true
        data.sources, data.would = {}, nil
    end
    -- what it gives with what is tried, on the card kept open (Tried.Effects): what failed once left as it is
    if keep and Tried.what and #data.tiles > 0 and s.gives and not Tried.brokenEffects[s.key] and not ns.InCombat() then
        Tried.brokenEffects[s.key] = not ns.SafeCall(Tried.Effects, data, s) or nil
    end
    -- its head with what would be: the value as it is, greyed, by how much it would change, then what it would be;
    -- the game's question mark where that can't be said; the change alone where the game gives no number of the value.
    -- A regeneration's, each state's (Stats.RegenCard).
    if data.regenWould then
        data.value, data.detail = data.regenWould.value, data.regenWould.detail
    elseif data.would then
        local w, percents = data.would, s.sources.percent
        local function figure(v)
            return percents and Format.PercentOf(v, 2) or number(floor(v + 0.5))
        end
        local change = (w.delta > 0 and "+" or "") .. figure(w.delta)
        if w.unsure then
            data.value, data.detail = ask(w.unsure), Infos.Color(plainText(text), WAS_HEX) .. " " .. ARROW
        elseif w.value then
            data.value = Infos.Color(figure(w.value), WOULD_HEX)
            data.detail = Infos.Color(plainText(text), WAS_HEX) .. " " .. Infos.Color(change, WOULD_HEX) .. " "
                .. ARROW
        else
            data.detail = Infos.Color(change, WOULD_HEX)
        end
    elseif keep and text and s.would and Tried.what and not ns.InCombat() then
        -- (a hand's: what its line would say, the game's question after an estimate, said at the foot)
        local figure = s.would(Tried.Full())
        if figure then
            if figure:find(UNKNOWN, 1, true) then
                ask(L.STAT_WHY_HAND)
            end
            data.value, data.detail = figure, Infos.Color(plainText(text), WAS_HEX) .. " " .. ARROW
        end
    end
    if s.tip then
        data.about[#data.about + 1] = { text = s.tip(), color = Infos.GREY }
    end
    -- its foot: what a click does, then the hub's own hints and the element's kind, as under a tooltip
    local hints = { AddLine = function(_, text)
        data.hints[#data.hints + 1] = text
    end }
    -- (first, what each of its question marks asks, and what to go by)
    local asked = questions
    questions = nil
    for _, why in ipairs(asked) do
        hints:AddLine(UNKNOWN .. " " .. why)
    end
    if not keep then
        -- (what the clicks do, on one line)
        data.clicks = {}
        local clicks = { AddLine = function(_, text)
            data.clicks[#data.clicks + 1] = text
        end }
        clicks:AddLine(L.HINT_PIN)
        ns.HubMenus.AddHints(clicks, s.item)
    else
        hints:AddLine(L.STAT_WOULD_HINT)
    end
    data.pinned, data.key = keep == true, s.key
    ns.StatCard.Show(owner, data)
end

-- ---------- The cards kept open ----------
-- (Ikar 2026-11-19: "do 10, 1, 2 […]", a card that stays open and follows; of how it shuts, "just keep the cross, and
-- escape should close it too".) A left click on an attribute keeps its card open, and shuts it when it is (Ikar
-- 2026-11-23: "when clicking againt on a stat, it shoudl close the popup"), several at once, a click on another
-- opening its own beside the first ("add a possibility to add multiple"); each drawn again each time the values are
-- read again and when the target changes; once its cross, Escape or the click has shut it (StatCard.lua's doing),
-- nothing draws it. By the value's key.
local pinnedStat = {}
local function pin(owner, s)
    ns.StatCard.Hide()
    if pinnedStat[s.key] and ns.StatCard.Pinned(s.key) then
        ns.StatCard.Unpin(s.key)
        return
    end
    pinnedStat[s.key] = s
    showCard(owner, s, true, true)
end
ns.StatCard.OnUnpin = function(key)
    pinnedStat[key] = nil
end
local function redraw()
    for _, s in ipairs(LIST) do
        if pinnedStat[s.key] then
            showCard(nil, s, true, true)
        end
    end
end
ns.On("PLAYER_TARGET_CHANGED", function()
    ns.Later("stat card", redraw)
end)

-- ---------- What would be, on the lines ----------
-- (Ikar 2026-11-25, of the light blue on the cards kept open alone: "when hovering, it seems you turn blue only the
-- individual cards, not the whole stat lists", then "go for an implementation".) What is under the pointer is tried on
-- the lines that show too, a card kept open or not: the attributes' folder open, a copy of one of them on the bar or
-- in a list. Each says what its value would be, its figure alone in the blue, written as the line writes it,
-- where its card's head says it (the same sum, wouldBe's); the game's question mark where that can't be said; as it is
-- where nothing of it would change. Its name and its numeral stay, the thresholds read at the value as it is, as the
-- card's « À savoir »: the line keeps its place (Ikar 2026-11-15: no shape changed by the game's doing). Worked out
-- once for what is tried, not again each time the game refreshes its tooltip (five times a second: GameTooltip's
-- OnUpdate asks its owner's UpdateTooltip), a few lines a frame.

-- The lines' part of what is tried (Tried). How a line writes its figure where it isn't a whole or a chance to a
-- tenth (LIST's values, `FIGURES`): a share whole, the defence's most beside it, the off hand's expertise beside the
-- main's (every source of it the two hands': SOURCES.EXPERTISE). What each line would say of what is tried now, by its
-- value's key (`lines`, false for nothing), worked out when first asked; what is tried with the attributes' changes
-- (`full`, Tried.With's, the other values' as they are asked: Tried.Change), once for them all: both let go when what
-- is tried changes and as the values are read again (a card kept open works its own out anew). A line whose working
-- out raised an error isn't worked out again this session (`broken`), nor a card's effects (`brokenEffects`). The
-- lines waiting to be worked out, in the list's order, a few each frame (`queue`: a whole folder's, some fifty
-- readings of the sources, took a few frames' time of the game's in one).
Tried.lines, Tried.broken, Tried.queue, Tried.queued, Tried.WAIT, Tried.PER_FRAME = {}, {}, {}, {}, {}, 8
Tried.brokenEffects = {}
function Tried.Full()
    Tried.full = Tried.full or Tried.With(Tried.what)
    return Tried.full
end
Tried.FIGURES = {
    BLOCK = function(v)
        return Format.Percent(v / 100)
    end,
    MOVESPEED = function(v)
        return Format.Percent(v / 100)
    end,
    DEFENSE = function(v)
        return number(floor(v + 0.5)) .. " / " .. number((UnitLevel("player") or 0) * 5)
    end,
    EXPERTISE = function(v, delta)
        local _, off = ns.Plain(GetExpertise())
        local _, offSpeed = ns.Plain(UnitAttackSpeed("player"))
        return percent(v) .. ((offSpeed and type(off) == "number") and (" / " .. percent(off + delta)) or "")
    end,
    -- (the line's « %d »: no thousands' mark, cut to a whole, not rounded)
    ARMORPEN = function(v)
        return string.format("%d", v)
    end,
}

-- What the line of `s` would say of its value with what is tried in place (`tried`, Tried.With's): its figure in the
-- blue, the game's question mark where it can't be said, nil where it wouldn't change, or where the line's
-- figure wouldn't (a change smaller than its tenth or its whole: the card kept open says it).
function Tried.LineOf(s, tried)
    if s.would then
        return s.would(tried)
    end
    local w = wouldBe(s, Tried.what, tried)
    if Stats.IsRegen(s) then
        return Stats.RegenLineWould(s, tried, w)
    elseif not w then
        return nil
    elseif w.unsure then
        return UNKNOWN
    elseif w.delta < 0.005 and w.delta > -0.005 then
        return nil
    end
    local figure
    if w.value then
        local write = Tried.FIGURES[s.key]
        figure = write and write(w.value, w.delta) or s.sources.percent and percent(w.value)
            or number(floor(w.value + 0.5))
    else
        -- (a value its sources alone make, the healing's shares: read again with what is tried in place)
        WOULD = tried
        local ok, text = pcall(s.value)
        WOULD = nil
        if not ok then
            error(text, 0)
        end
        figure = text
    end
    if not figure then
        return UNKNOWN
    elseif plainText(figure) == plainText((read(s))) then
        return nil
    end
    return Infos.Color(plainText(figure), WOULD_HEX)
end

-- ---------- The weapons' lines, what they would be ----------
-- (Ikar 2026-11-26: "Everything should follow, every, single, line. Not a single exception. Under no cisrcumstances";
-- of the damage's share, "would degat infliger change weapon DPS ?") A hand's hits as the sheet takes them, the game's
-- figures (UnitDamage, UnitRangedDamage) changed by what is tried: its attack power's change (Tried.Change), a point a
-- second for 14 a hit at the weapon's speed (the sheet's ATTACK_POWER_MAGIC_NUMBER, POWER_PER_DAMAGE); a weapon tried
-- in the hand, its damage and its speed for the worn one's, what the base holds beside them kept (an enchantment's
-- damage, the ammunition's: the game's question after the figure, it may go with the weapon); the off hand by the
-- share of the hits the game gives it now (a first weapon there, the game's half: asked, its talents unknown). The off
-- hand or the ranged left empty, or given what is no weapon (a shield, a relic): « Aucune »; the main hand emptied, a
-- two-handed weapon taken off with what goes in the off hand, its fists (Tried.FISTS, asked). A druid in a form
-- strikes with its paws, its weapon nothing to them.

-- A weapon's damage and speed as its tooltip writes them, the one worn in `slot` or the item `link`: the line whose
-- right says its speed (« Vitesse 2,60 », SPEED) and whose left its damage (« Dégâts : 32 - 45 », DAMAGE_TEMPLATE, or
-- with its school); nil where none says them (no weapon, not read yet).
function Tried.WeaponOf(slot, link)
    if not C_TooltipInfo then
        return nil
    end
    local data
    if link then
        data = ns.Call(C_TooltipInfo.GetHyperlink, link)
    else
        data = ns.Call(C_TooltipInfo.GetInventoryItem, "player", slot)
    end
    local word = G("SPEED", "Speed")
    for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
        local left = type(line) == "table" and ns.Plain(line.leftText)
        local right = type(line) == "table" and ns.Plain(line.rightText)
        if type(left) == "string" and type(right) == "string" and right:find(word, 1, true) then
            local low, high = left:match("(%d+)[%s\194\160]*%-[%s\194\160]*(%d+)")
            local speed = tonumber(((right:match("(%d+[%.,]?%d*)") or ""):gsub(",", ".")))
            if low and speed and speed > 0 then
                return { low = tonumber(low), high = tonumber(high), speed = speed }
            end
        end
    end
end
-- A main hand emptied, its fists: the original server's 1 - 2 at 2,00, Forever's unknown (asked).
Tried.FISTS = { low = 1, high = 2, speed = 2 }
-- The ammunition a ranged weapon shoots, by its kind: arrows, bullets, none (thrown, a wand).
function Tried.Ammo(link)
    local ok, _, _, _, _, _, _, subclass = pcall(C_Item.GetItemInfoInstant, link or "")
    local kinds = Enum.ItemWeaponSubclass or {}
    if not ok then
        return nil
    elseif subclass == kinds.Bows or subclass == kinds.Crossbow then
        return "arrow"
    elseif subclass == kinds.Guns then
        return "bullet"
    end
    return "none"
end

-- The physical damage's own changes (Data/Effects.lua's 13 by points and 79 by a share, on the physical school; Ikar
-- 2026-11-26: "would degat infliger change weapon DPS ?"): what is tried would make of them beside what they make now,
-- the share of each hit a product (they multiply each other), the points a sum; and whether one tried has no figure.
function Tried.IsPhysical(misc)
    return misc % 2 == 1
end
Tried.PHYSICAL = { key = "PHYSICAL", sources = { gear = { "ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT" }, flat = { [13] = true },
    noBase = true,
    misc = Tried.IsPhysical } }
Tried.PHYSICAL_SHARE = { key = "PHYSICAL_SHARE", sources = { gear = {}, flat = { [79] = true }, percent = true,
    noBase = true, multiplies = true, misc = Tried.IsPhysical } }
function Tried.Physical(what)
    local function tally(s, with)
        local share, points, unknown = 1, 0, 0
        for _, e in ipairs((tallyWith(s, with))) do
            if type(e.points) == "number" then
                share, points = share * (1 + e.points / 100), points + e.points
            elseif not e.next then
                unknown = unknown + 1
            end
        end
        return share, points, unknown
    end
    local nowShare, _, nowUnknown = tally(Tried.PHYSICAL_SHARE, nil)
    local wouldShare, _, wouldUnknown = tally(Tried.PHYSICAL_SHARE, what)
    local _, nowPoints, nowMissing = tally(Tried.PHYSICAL, nil)
    local _, wouldPoints, wouldMissing = tally(Tried.PHYSICAL, what)
    return wouldShare / nowShare, wouldPoints - nowPoints, wouldUnknown > nowUnknown or wouldMissing > nowMissing
end

-- What the hand `slot` (16, 17, 18) would hit for with what is tried in place (WOULD): its low, its high, its speed,
-- the line's bonuses and multiplier (damage()), and whether it is an estimate; "none" where it would hold no weapon,
-- "unknown" where the weapon tried says no damage yet; nil where the game hides its figures or the hand has none and
-- gets none. The physical damage's changes tried on every hit (Tried.Physical).
function Tried.Hand(slot)
    local low, high, speed, pos, neg, pct
    if slot == 18 then
        -- (as the line: its multiplier only, GetRangedDamage leaving the bonuses out)
        speed, low, high = ns.Plain(UnitRangedDamage("player"))
        pct, pos, neg = select(6, ns.Plain(UnitRangedDamage("player"))), 0, 0
    else
        local mainLow, mainHigh, offLow, offHigh, p, n, q = ns.Plain(UnitDamage("player"))
        local mainSpeed, offSpeed = ns.Plain(UnitAttackSpeed("player"))
        if slot == 16 then
            low, high, speed = mainLow, mainHigh, mainSpeed
        else
            low, high, speed = offLow, offHigh, offSpeed
        end
        pos, neg, pct = p or 0, n or 0, q
    end
    if type(pct) ~= "number" or pct <= 0 then
        return nil
    end
    local has = type(low) == "number" and type(high) == "number" and type(speed) == "number" and speed > 0 and high > 0
    local tried = WOULD and WOULD.links and WOULD.links[slot]
    -- (the main hand emptied, a two-handed weapon taken off with what goes in the off hand: its fists, asked)
    local fists = slot == 16 and tried == false
    if tried == false and not fists then
        return "none"
    elseif tried and not fists then
        local ok, _, _, _, _, _, class = pcall(C_Item.GetItemInfoInstant, tried)
        if not ok or class ~= (Enum.ItemClass and Enum.ItemClass.Weapon or 2) then
            return "none"
        end
    end
    local power
    if slot == 18 then
        power = { ns.Plain(UnitRangedAttackPower("player")) }
    else
        power = { ns.Plain(UnitAttackPower("player")) }
    end
    if type(power[1]) ~= "number" then
        return nil
    end
    local ap = power[1] + (power[2] or 0) + (power[3] or 0)
    local more = Tried.Change(slot == 18 and "RANGED_ATTACK_AP" or "ATTACK_AP")
    local factor, points, asked = 1, 0, false
    -- (its speed by what is tried's change of that kind's haste, a quiver's, an elixir's: the game's sum of its shares)
    local quick = 1
    if WOULD then
        factor, points, asked = Tried.Physical(WOULD)
        local melee, ranged = hasteBy()
        local now = slot == 18 and ranged or melee
        local faster = Tried.Change("HASTE", slot == 18 and "r" or "m")
        if type(now) == "number" and faster ~= 0 then
            quick = (100 + now) / (100 + now + faster)
        end
    end
    -- (the line's bonuses with the points tried, the ranged line's none, as its own; the multiplier with the share's)
    local plus = slot == 18 and 0 or max(points, 0)
    local minus = slot == 18 and 0 or min(points, 0)
    local after = pct * factor
    local paws = slot ~= 18 and select(2, UnitClass("player")) == "DRUID" and (ns.Call(GetShapeshiftForm) or 0) ~= 0
    local old = has and not paws and Tried.WeaponOf(slot)
    local baseLow, baseHigh = has and low / pct - pos - neg, has and high / pct - pos - neg
    -- the off hand's share of its weapon's hits and of the power's, the game's now
    local share = 1
    if slot == 17 and old then
        share = (baseLow + baseHigh) / (old.low + old.high + 2 * ap * old.speed / POWER_PER_DAMAGE)
    end
    if (not tried and not fists) or paws then
        if not has then
            return nil
        end
        local hit = more / POWER_PER_DAMAGE * (old and old.speed or speed) * (slot == 17 and old and share or 1)
        return (baseLow + hit + pos + neg + points) * after, (baseHigh + hit + pos + neg + points) * after,
            speed * quick, pos + plus, neg + minus, after, asked or (slot == 17 and not old and more ~= 0)
    end
    local new = fists and Tried.FISTS or Tried.WeaponOf(nil, tried)
    if not new then
        return "unknown"
    end
    local enchanted = not fists and tried:match("item:%d+:(%d*)") or ""
    local estimate = fists or (enchanted ~= "" and enchanted ~= "0")
    local restLow, restHigh, hasted = 0, 0, 1
    if has and old then
        local part = ap * old.speed / POWER_PER_DAMAGE
        restLow, restHigh = baseLow - (old.low + part) * share, baseHigh - (old.high + part) * share
        hasted = speed / old.speed
        if slot == 18 then
            -- (the ammunition's by the speed, as the game adds it; another kind's unknown)
            local kept = Tried.Ammo(GetInventoryItemLink("player", 18)) == Tried.Ammo(tried)
            estimate = estimate or (not kept and (restLow >= 0.5 or restLow <= -0.5))
            restLow, restHigh = restLow * new.speed / old.speed, restHigh * new.speed / old.speed
        else
            estimate = estimate or restLow >= 0.5 or restLow <= -0.5 or restHigh >= 0.5 or restHigh <= -0.5
        end
    elseif slot == 17 then
        share, estimate = 0.5, true
    elseif slot == 18 and Tried.Ammo(tried) ~= "none" then
        -- (a first bow or gun: the ammunition it would shoot unknown)
        estimate = true
    elseif has and GetInventoryItemLink("player", slot) then
        estimate = true
    end
    local part = (ap + more) * new.speed / POWER_PER_DAMAGE
    return ((new.low + part) * share + restLow + pos + neg + points) * after,
        ((new.high + part) * share + restHigh + pos + neg + points) * after, new.speed * hasted * quick, pos + plus,
        neg + minus, after, estimate or asked
end
-- The line of a hand as Tried.Hand would make it: in the blue, the game's question after an estimate; nil where it
-- wouldn't change.
function Tried.HandLine(s, slot, tried)
    local was = WOULD
    WOULD = tried
    local ok, low, high, _, pos, neg, pct, estimate = pcall(Tried.Hand, slot)
    WOULD = was
    if not ok then
        error(low, 0)
    end
    local figure
    if low == "none" then
        figure = G("NONE", "None")
    elseif low == "unknown" then
        return UNKNOWN
    elseif type(low) == "number" then
        figure = damage(low, high, pos, neg, pct)
    end
    if not figure or plainText(figure) == plainText((read(s))) then
        return nil
    end
    return Infos.Color(plainText(figure), WOULD_HEX) .. (estimate and " " .. UNKNOWN or "")
end
STAT_BY_KEY.MAINHAND_DAMAGE.would = function(tried) return Tried.HandLine(STAT_BY_KEY.MAINHAND_DAMAGE, 16, tried) end
STAT_BY_KEY.OFFHAND_DAMAGE.would = function(tried) return Tried.HandLine(STAT_BY_KEY.OFFHAND_DAMAGE, 17, tried) end
STAT_BY_KEY.RANGED_DAMAGE.would = function(tried) return Tried.HandLine(STAT_BY_KEY.RANGED_DAMAGE, 18, tried) end

-- Whether the line of `s` shows: its own button (the attributes' folder open), or a copy's; whether any does. Asked
-- at each of the game's tooltips of an item or a spell, with no saved data too (refused, as a newer version's is, all
-- session long, or not loaded yet: Core/Main.lua): no copy then.
function Tried.Shown(s)
    local b = ns.HubButtons.Get(s.item)
    if b and b:IsVisible() then
        return true
    end
    for id, c in pairs(ns.db and ns.db.copies or {}) do
        local copy = c.of == s.item and ns.HubButtons.Get(id)
        if copy and copy:IsVisible() then
            return true
        end
    end
    return false
end
function Tried.AnyShown()
    for _, s in ipairs(LIST) do
        if (s.sources or s.would) and Tried.Shown(s) then
            return true
        end
    end
    return false
end

-- What the line of `s` says of what is tried: its figure (LineOf's), false for nothing, WAIT while it isn't worked
-- out yet (`work`: worked out now).
function Tried.Line(s, work)
    if not Tried.what or not (s.sources or s.would) or Tried.broken[s.key] or ns.InCombat() then
        return false
    end
    local got = Tried.lines[s.key]
    if got ~= nil then
        return got
    elseif not Tried.Shown(s) then
        return false
    elseif not work then
        return Tried.WAIT
    end
    local ok, figure = ns.SafeCall(function()
        return Tried.LineOf(s, Tried.Full())
    end)
    Tried.broken[s.key] = not ok or nil
    got = ok and figure or false
    Tried.lines[s.key] = got
    return got
end

-- Each line's figure let go, to be worked out again; `all`, those waiting too.
function Tried.Forget(all)
    wipe(Tried.lines)
    Tried.full = nil
    if all then
        wipe(Tried.queue)
        wipe(Tried.queued)
    end
end
function Tried.Queue(s)
    if not Tried.queued[s.key] then
        Tried.queued[s.key] = true
        Tried.queue[#Tried.queue + 1] = s
    end
    ns.Later("stat lines", Tried.Pass)
end

-- What is tried, written whole, so that the same again changes nothing.
function Tried.Key(v)
    if type(v) ~= "table" then
        return tostring(v)
    end
    local parts = {}
    for k, x in pairs(v) do
        parts[#parts + 1] = tostring(k) .. "=" .. Tried.Key(x)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
Tried.key = Tried.Key(nil)

-- What the game's tooltip shows, tried on the cards kept open and the lines that show: an item's, a spell's (a
-- talent's); nothing once it has gone. The game's own way for an addon to read its tooltips (TooltipDataProcessor's
-- post calls), read alone. Not one a card's own row shows (StatCard.lua's kaliCardTip): its talent tried there would
-- draw the card again under the pointer, and that tooltip with it. Each line as it is at once, those that show worked
-- out again for it.
local function try(what)
    local key = Tried.Key(what)
    if key == Tried.key then
        return
    end
    Tried.key, Tried.what = key, what
    ns.Later("stat card", redraw)
    Tried.Forget(true)
    for _, s in ipairs(LIST) do
        if s.line then
            Hub.Set(s.item, "text", s.line)
        end
        if what and (s.sources or s.would) and not ns.InCombat() and Tried.Shown(s) then
            Tried.Queue(s)
        end
    end
end
if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns.Guarded(function(tooltip, data)
        local owner = tooltip == GameTooltip and tooltip.GetOwner and tooltip:GetOwner()
        if owner and owner.kaliCardTip then
            return
        end
        if tooltip == GameTooltip and type(data) == "table" and (next(pinnedStat) or Tried.AnyShown()) then
            local link = ns.Plain(data.hyperlink)
            if type(link) ~= "string" and TooltipUtil and TooltipUtil.GetDisplayedItem then
                link = select(2, TooltipUtil.GetDisplayedItem(tooltip))
            end
            try(itemTried(link))
        end
    end))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, ns.Guarded(function(tooltip, data)
        local owner = tooltip == GameTooltip and tooltip.GetOwner and tooltip:GetOwner()
        if owner and owner.kaliCardTip then
            return
        end
        if tooltip == GameTooltip and type(data) == "table" and (next(pinnedStat) or Tried.AnyShown()) then
            try(talentTried(ns.Plain(data.id)))
        end
    end))
end
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnHide", ns.Guarded(function()
        try(nil)
    end))
end

-- ---------- A skill's bonus, where it comes from (Ikar 2026-11-18: "for fishing, I see only bonus +5, not the source") ----------
-- The same tally for a skill line's bonus (UI/Hub/Infos/Skills.lua): the spells whose auras change that line
-- (Data/Effects.lua's 30 and 98, their misc the line), so the buffs, the enchantments (a fishing lure for a while, the
-- gloves' « Pêche +2 »), the sets, the talents and the race's passive spells; an item's own bonus, which Forever makes
-- one of the item's stats (a fishing rod's, its stat 117) that C_Item.GetItemStats keys by no name of the game's
-- strings, read from the item's line as the game words it (TOOLTIP_ITEM_STAT_SKILL_<skill>_INCREASE, _DECREASE:
-- inferred, the strings this build's and the rods carrying the stat, unverified in game); what's left « Autres ».
-- Defence keeps its attribute's (SOURCES.DEFENSE). Each skill line's word in those strings, by SkillLine's id (checked
-- against this build's French names; jewelcrafting's line isn't in it).
local SKILL_WORDS = {
    [171] = "ALCHEMY", [44] = "AXES", [164] = "BLACKSMITHING", [45] = "BOWS", [185] = "COOKING", [226] = "CROSSBOWS",
    [173] = "DAGGERS", [118] = "DUAL_WIELDING", [333] = "ENCHANTING", [202] = "ENGINEERING", [129] = "FIRST_AID",
    [356] = "FISHING", [473] = "FIST_WEAPONS", [46] = "GUNS", [182] = "HERBALISM", [165] = "LEATHERWORKING",
    [54] = "MACES", [186] = "MINING", [229] = "POLEARMS", [393] = "SKINNING", [136] = "STAVES", [43] = "SWORDS",
    [197] = "TAILORING", [176] = "THROWN_WEAPONS", [172] = "TWO-HANDED_AXES", [160] = "TWO-HANDED_MACES",
    [55] = "TWO-HANDED_SWORDS", [228] = "WANDS",
}
Stats.SKILL_WORDS = SKILL_WORDS

-- A pattern for one of the game's strings holding one number (« %1$d » or « %d »), from its start, that number
-- caught; nil for one without it.
local function numberPattern(text)
    if type(text) ~= "string" then
        return nil
    end
    local before, after = text:match("^(.-)%%1%$d(.*)$")
    if not before then
        before, after = text:match("^(.-)%%d(.*)$")
    end
    if not before then
        return nil
    end
    local function plain(s)
        return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
    end
    return "^" .. plain(before) .. "(%d+)" .. plain(after)
end

-- What the item in `slot` gives the skill by its own line: raised by one, lowered by the other; 0 for none.
local function skillLine(word)
    local up = numberPattern(G("TOOLTIP_ITEM_STAT_SKILL_" .. word .. "_INCREASE"))
    local down = numberPattern(G("TOOLTIP_ITEM_STAT_SKILL_" .. word .. "_DECREASE"))
    if not (up or down) then
        return nil
    end
    return function(slot)
        local data = C_TooltipInfo and ns.Call(C_TooltipInfo.GetInventoryItem, "player", slot)
        local v = 0
        for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
            local text = type(line) == "table" and ns.Plain(line.leftText)
            if type(text) == "string" then
                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local n = up and tonumber(text:match(up))
                if n then
                    v = v + n
                else
                    n = down and tonumber(text:match(down))
                    v = v - (n or 0)
                end
            end
        end
        return v
    end
end

local SKILL_AURAS = { [30] = true, [98] = true }
local skillSpecs = {}
local function skillSpec(skill)
    if skill == 95 then
        return SOURCES.DEFENSE
    end
    local spec = skillSpecs[skill]
    if not spec then
        local word = SKILL_WORDS[skill]
        spec = { gear = {}, flat = SKILL_AURAS, misc = function(misc) return misc == skill end,
            itemLine = word and skillLine(word) or nil }
        skillSpecs[skill] = spec
    end
    return spec
end

-- Under a skill's tooltip, where its bonus comes from, each source a line as an attribute's: `rank` its rank before
-- it, `bonus` the bonus, as the skills tab gives them. Nothing without a bonus, nor during a fight; a skill whose
-- reading failed once isn't read again this session, as an attribute's.
local brokenSkills = {}
function Stats.ShowSkillSources(tooltip, skill, rank, bonus)
    if type(bonus) ~= "number" or bonus == 0 or type(rank) ~= "number" or brokenSkills[skill] then
        return
    end
    local s = { key = "SKILL" .. tostring(skill), sources = skillSpec(skill), numbers = function()
        return rank, rank + bonus, max(bonus, 0), min(bonus, 0)
    end }
    if not ns.SafeCall(showSources, tooltip, s) then
        brokenSkills[skill] = true
    end
end

for i, s in ipairs(LIST) do
    local name = PREFIX .. s.key
    s.item = name
    Hub.Add(name, {
        type = "data source", text = "", category = "stats", home = "stats", atlas = s.atlas, icon = s.icon,
        -- its own hover, the card, in place of a tooltip
        OnEnter = function(owner)
            -- (not beside the card kept open of the same value, which says the same)
            if not (pinnedStat[s.key] and ns.StatCard.Pinned(s.key)) then
                showCard(owner, s)
            end
        end,
        OnLeave = function()
            ns.StatCard.Hide()
        end,
        -- a left click keeps its card open
        OnClick = function(owner, button)
            if button == "LeftButton" then
                ns.SafeCall(pin, owner, s)
            end
        end,
    }, "hidden", 200 + i)
end

-- (a stat whose thresholds raised an error: not asked again this session, as a reading that failed)
local brokenCaps = {}
-- Each read again; one the game hides now keeps its last text, its name and a dash until it has one (a reload in a
-- fight).
-- The line wears, after its value, the numeral of the highest level of enemy whose thresholds it reaches (Ikar
-- 2026-11-20: "chiffre romain"), in gold; none for one that reaches none, or has none. With what is tried, its figure
-- what it would be (Tried.Line), once worked out: till then the line stays as it was (`work`: worked out now); worked
-- out again once the line reads otherwise (the speed's, read each second with no event of the game's: in the water,
-- what it would be running is no longer it). `known`: its text, read already (update's), false for none.
local function updateOne(s, work, known)
    local text, name = known, s.name()
    if text == nil then
        text = read(s)
    end
    Hub.Set(s.item, "label", name)
    if text then
        local ok, mark = false, nil
        if s.caps and not brokenCaps[s.key] then
            ok, mark = ns.SafeCall(function()
                return numeral(s.caps(true))
            end)
            brokenCaps[s.key] = not ok or nil
        end
        local tail = ok and mark and (" " .. Infos.Color(mark, TIER)) or ""
        -- (the line as it is: said again once what is tried has gone, and while a fight hides the value)
        local line = name .. " " .. text .. tail
        if line ~= s.line then
            Tried.lines[s.key] = nil
        end
        s.line = line
        local would = Tried.Line(s, work)
        if would == Tried.WAIT then
            Tried.Queue(s)
        else
            Hub.Set(s.item, "text", would and (name .. " " .. would .. tail) or s.line)
        end
    elseif s.line then
        Hub.Set(s.item, "text", s.line)
    else
        Hub.Set(s.item, "text", name .. " —")
    end
end
function Tried.Pass()
    for _ = 1, Tried.PER_FRAME do
        local s = table.remove(Tried.queue, 1)
        if not s then
            return
        end
        Tried.queued[s.key] = nil
        updateOne(s, true)
    end
    if Tried.queue[1] then
        ns.Later("stat lines", Tried.Pass)
    end
end

-- What the lines would say is worked out again only when a value has changed: the bags' and the auras' events come
-- often while an item is under the pointer, most of them changing none (a stack split, a buff of nothing the sheet
-- shows). Each value read once.
local function update()
    local texts, values = {}, {}
    for i, s in ipairs(LIST) do
        texts[i] = read(s) or false
        values[i] = tostring(texts[i])
    end
    values = table.concat(values, "\1")
    if values ~= Tried.values then
        Tried.values = values
        Tried.Forget()
    end
    for i, s in ipairs(LIST) do
        updateOne(s, nil, texts[i])
    end
    redraw()
end
-- (an option changed that changes how they read: UI/Options.lua's)
Stats.Refresh = update

-- The movement speed changes with a mount, the water, which no event of the sheet's says: read again each second too,
-- as the sheet does while it shows (its OnUpdate).
Infos.Updates(function()
    updateOne(MOVE)
end, nil, 1)

-- All read again on each of the sheet's events (PaperDollFrame_OnLoad) that can change one: a buff or a debuff come or
-- gone (UNIT_AURA: a chance, a haste or a regeneration changes with no other event), talents, gear, the quiver's
-- arrows (BAG_UPDATE), the level; with the power's kind, the form, the skills, the fight's end.
Infos.Updates(update, {
    "PLAYER_ENTERING_WORLD", "UNIT_STATS", "UNIT_AURA", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK_SPEED",
    "UNIT_ATTACK", "UNIT_SPELL_HASTE", "UNIT_RESISTANCES", "UNIT_LEVEL", "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED",
    "PLAYER_DAMAGE_DONE_MODS", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM", "SKILL_LINES_CHANGED",
    "PLAYER_REGEN_ENABLED",
})

-- ---------- What a card read of the game, for KaLi HUD's check of its cards ----------
-- (UI/Hub/Infos/StatCheck.lua keeps it beside the card's rows, to be read again offline from it alone:
-- hud/tools/lua/scenarios/cards.lua, the fake's F.Replay.) The state a value's sources are read from: the character's
-- level, race, class, form and power, its attributes, its auras (with their tooltip's text where it names hidden ones:
-- Stats.HiddenParts), its gear (each item's own stats, kind and set), the weapons' enchantments for a while, its
-- talents (with the figures their words state: talentSays) and the passive spells it knows, its ratings, how it moves.
-- Nothing that changes from one moment to the next and none of the sources read (the review of 2026-11-23: the speed
-- it went at, an oil's time left, an aura's instance, and no state read twice was the same, each card kept with a
-- whole one of its own): the speed now 0, an aura's instance where its text is kept alone (Stats.HiddenParts asks
-- it), a weapon's enchantment by its kind and id. No name of the character's nor the realm's. Out of a fight, as the
-- sources.
function Stats.ReadState()
    local function copy(t)
        local out = {}
        for k, v in pairs(type(t) == "table" and t or {}) do
            v = ns.Plain(v)
            out[k] = type(v) == "table" and copy(v) or v
        end
        return out
    end
    local _, run, flight, swim = ns.Plain(GetUnitSpeed("player"))
    local state = { level = ns.Plain(UnitLevel("player")), locale = ns.LOCALE, race = { ns.Plain(UnitRace("player")) },
        class = { ns.Plain(UnitClass("player")) }, form = ns.Plain(ns.Call(GetShapeshiftFormID)),
        power = { ns.Plain(UnitPowerType("player")) }, mana = ns.Plain(UnitPowerMax("player", Enum.PowerType.Mana)),
        stats = {}, auras = {}, items = {}, enchants = {}, talents = {}, known = {}, ratings = {},
        move = { 0, run, flight, swim }, moving = { swimming = IsSwimming("player") == true,
            flying = IsFlying("player") == true, falling = IsFalling("player") == true,
            mounted = ns.Call(IsMounted) == true } }
    for i = 1, 5 do
        state.stats[i] = { ns.Plain(UnitStat("player", i)) }
    end
    for _, filter in ipairs(FILTERS) do
        local list = {}
        state.auras[filter] = list
        for i = 1, 255 do
            local aura = ns.Plain(C_UnitAuras.GetAuraDataByIndex("player", i, filter))
            if type(aura) ~= "table" then
                break
            end
            local points, instance = ns.Plain(aura.points), ns.Plain(aura.auraInstanceID)
            local kept = { spellId = ns.Plain(aura.spellId), name = ns.Plain(aura.name), icon = ns.Plain(aura.icon),
                applications = ns.Plain(aura.applications), points = type(points) == "table" and copy(points) or nil }
            -- (the text of one whose tooltip names hidden auras, its lines one after the other, with its instance)
            if kept.spellId and instance and ns.HIDDEN_PARTS and ns.HIDDEN_PARTS[kept.spellId] then
                local data = C_TooltipInfo
                    and ns.Plain(ns.Call(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", instance))
                local lines, texts = type(data) == "table" and ns.Plain(data.lines), {}
                for _, line in ipairs(type(lines) == "table" and lines or {}) do
                    local text = type(line) == "table" and ns.Plain(line.leftText)
                    if type(text) == "string" then
                        texts[#texts + 1] = text
                    end
                end
                kept.says = #texts > 0 and table.concat(texts, "\r\n") or nil
                kept.auraInstanceID = kept.says and instance or nil
            end
            list[#list + 1] = kept
        end
    end
    for slot = FIRST_SLOT, LAST_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local class, subclass, set = itemKind(link)
            state.items[slot] = { item = link:match("|H(item:[^|]+)|h") or link, name = link:match("%[(.-)%]"),
                quality = GetInventoryItemQuality("player", slot), stats = copy(C_Item.GetItemStats(link)),
                class = class, subclass = subclass, set = set }
        end
    end
    for _, w in ipairs(WEAPONS) do
        local enchants = C_Item and ns.Call(C_Item.GetWeaponEnchantInfo, w[1])
        if type(enchants) == "table" and next(enchants) then
            local list = {}
            for k, e in pairs(enchants) do
                e = ns.Plain(e)
                if type(e) == "table" then
                    list[k] = { hasEnchant = ns.Plain(e.hasEnchant), enchantType = ns.Plain(e.enchantType),
                        enchantID = ns.Plain(e.enchantID) }
                end
            end
            state.enchants[w[1]] = list
        end
    end
    for _, t in ipairs(talents()) do
        local says, figures = talentSays(t), nil
        if says then
            figures = {}
            for v in pairs(says) do
                figures[#figures + 1] = v
            end
            table.sort(figures)
        end
        state.talents[#state.talents + 1] = { spell = t.spell, rank = t.rank, ranks = t.ranks, name = t.name,
            says = figures }
    end
    for _, spell in ipairs(knownPassives()) do
        state.known[#state.known + 1] = spell
    end
    -- (the sheet's CR_ kinds, those the character has any of)
    for kind = 1, 32 do
        local rating, bonus = ns.Plain(ns.Call(GetCombatRating, kind)), ns.Plain(ns.Call(GetCombatRatingBonus, kind))
        if (type(rating) == "number" and rating ~= 0) or (type(bonus) == "number" and bonus ~= 0) then
            state.ratings[kind] = { rating or 0, bonus or 0 }
        end
    end
    return state
end

-- What a value's own calls gave: its numbers (base, effective, raised, lowered), its total, what it stands on (its
-- parts, at the kind of attack shown, their names without colour or icon), and that kind.
function Stats.ReadValue(s, channel)
    local v = { key = s.key, channel = channel }
    if s.numbers then
        v.numbers = { ns.Plain(s.numbers()) }
    end
    if s.total then
        v.total = ns.Plain(s.total())
    end
    if s.parts then
        v.parts = {}
        for i, p in ipairs(s.parts(channel) or {}) do
            v.parts[i] = { name = nameOf(p.name), points = p.points, percent = p.percent or nil, item = p.item or nil,
                slot = p.slot }
        end
    end
    return v
end
-- (the values, and what their sources come to: StatCheck.lua's /kh stats, the scenario's cards read again)
Stats.LIST, Stats.SourcesOf = LIST, sourcesOf

-- The healing done or taken by a share of each heal, in percent, its sources' shares multiplied, or taken by points
-- on each heal (HEALTAKEN_FLAT, their sum); 0 with none; nil in a fight, as every source.
function Stats.HealShare(key)
    if ns.InCombat() then
        return nil
    end
    local share = key ~= "HEALTAKEN_FLAT"
    for _, s in ipairs(LIST) do
        if s.key == key then
            local v = share and 1 or 0
            for _, e in ipairs(sourcesOf(s) or {}) do
                if type(e.points) == "number" then
                    v = share and v * (1 + e.points / 100) or v + e.points
                end
            end
            -- (to a tenth: 0.5 x 1.1 is 0.55 less a hair)
            return share and floor((v - 1) * 1000 + 0.5) / 10 or v
        end
    end
end
-- A share in percent as the bar writes it: raised green with its sign, lowered red, whole without decimals.
function Stats.ShareText(v)
    if not v then
        return nil
    end
    local text = v == floor(v) and Format.Percent(v / 100) or Format.PercentOf(v, 1)
    return v > 0 and Infos.Color("+" .. text, Infos.GOOD) or v < 0 and Infos.Color(text, Infos.BAD) or text
end
