"""What each spell's auras change among the character sheet's attributes, from Forever's game data (DB2 SpellEffect),
for the attributes' tooltips to name each change's source (UI/Hub/Infos/Stats.lua; Ikar 2026-11-16: "there is no
list of modificators on each, from where the +10 or -2 come from", "I don't see the effect of my elixirs and buffs";
2026-11-17: "Can we extend to include all sources?"). Writes Data/Effects.lua.

Kept: a spell's effects on its difficulty 0 that apply an aura of one of these kinds (the game's own numbers):
29 an attribute by points, 80 an attribute's base by a share (their misc the attribute's index from 0, -1 all), 137
an attribute by a share, written with its second misc, a mask of the attributes, 0 all, as the modern server reads it
(TrinityCore's HandleModTotalPercentStat: its first misc is 0 on eighteen spells of other attributes, Heart of the
Wild's intellect, Lightning Reflexes' agility; the review of 2026-11-20); 99 and 124 the melee and ranged attack power by points, 166 and 167 by a share; 674 the armour
by points (its misc 1); 22 the armour or resistances by points, 101 by a share (its misc a mask of the schools, 1 the
armour, 2 holy to 64 arcane); 30 and 98 a skill by points (its misc the skill line, SkillLine's: defence's 95 for
its attribute, every other for the skills' own tooltips, UI/Hub/Infos/Skills.lua; Ikar 2026-11-18: "for fishing, I
see only bonus +5, not the source");
34, 230 and 250 the health by points, 133 by a share; 35 a power by points (its misc the power's kind, 0 mana); 13
the damage by points (its misc its schools: the spells', and the weapons' physical, which the weapons' lines follow
under the pointer, Ikar 2026-11-26: "Everything should follow, every, single, line"), 79 by a share (the same misc),
135 their healing; 123 the targets' resistances (the spell penetration, its points below 0), on one magic school at least; 54
and 55 the chance to hit with weapons and spells, 52 and 57 to strike critically with them, 290 with both, 49 to
dodge, 47 to parry, 51 to block, by points of a percent; the haste by a share, each kind its attacks' (Ikar
2026-11-19: "the haste value seems doubled": one buff's melee and ranged haste are two effects, not twice the
haste): 319 the melee one, 140 the ranged one, 192 and 342 both, 65 and 216 the spells', 193 all three; 189 a combat
rating by points (its misc a mask of the ratings, the bit of the game's CR_ number less one: kept with one the sheet
shows, defence, dodge, parry, block, hit, critical strike, haste or expertise); 85 the mana in five seconds (its misc
0), 110 and 134 its regeneration by a share, the second while casting (their misc 0, mana); 142 the armour's base by a
share (its misc 1); the speed by a share (the original server's rule): 31, 129 and 171
running, 32, 130 and 172 mounted, 58 swimming, 33 lowered. The full review of 2026-11-20 (Ikar: "Do a full review of
the characteristic and it calculation"), each kind checked against the spells this build has of it: 240 the
expertise by points of a percent; 83 the armour's or resistances' base by points (misc as 22's); 123 on the armour
too (misc 1: armour ignored, the armour penetration); 174 and 175 the spells' damage and healing by a share of an
attribute, written with the attribute as its misc (174's own misc the schools, kept on all six magic ones, its second
the attribute; 175's the attribute); 317 the spell power by a share. 598 the attack power, melee and ranged, by a share
of an attribute (its misc the attribute's index from 0): the shaman's Mental Dexterity, of the intellect (Ikar
2026-11-21: "dexteriter mental seem not to be shown in attack power"), the hunter's Careful Aim, Cat Form's of the agility.
The review of every kind left out, the same day (Ikar: "review all others"): 9 the melee attack speed by a share (Juju
Flurry), 557 the ranged one (the quivers' and ammo pouches' « Hâte »), 466 the armour from items by a share, where the
spell has no 142 (the bear's and moonkin's forms and Toughness have both, the same share: two debuffs, « Brèche
furieuse » and « Condamnation à mort », have it alone), 178 a power's most by a share (its misc the power's kind: the gnome's Expansive Mind).
The health's regeneration, once it had a value of its own (Ikar 2026-11-21: "health regen ?"): 161 the health in five
seconds, in a fight or not (Demon Skin and Armor, the Troll's Blood elixirs, items' « Rend x points de vie »), 88 its
regeneration out of a fight by a share (Pure Water, Rage, Drain Life's -100 %); 116, the share kept in a fight
(Combat Endurance, the troll's Regeneration), since the regeneration's card has a column for a fight (Ikar 2026-11-23:
"A, a table, and everything per 5s"). The block value, once it had a card (the same day): 274 by points (« Augmente de
x la valeur de blocage de votre bouclier »), 272 by a share.
The others change nothing the sheet's values show: spells' modifiers, procs, damage done or taken, against a creature
kind, threat, crowd control. 593, the
chance to be dodged and parried lowered (sets' « Expertise augmentée »), left out: whether the game's expertise holds it
isn't known.
For each: its index among the spell's effects and its place among the spell's auras, since the game's aura data
(AuraData's points) may number either way, with the spell's count of each, which tells them apart in game; and its
points as the data gives them where they're the aura's own whoever casts it (no points by level, no scaling), for when
the game gives none.

The sources that aren't auras on the player (Ikar 2026-11-17, "all sources"), from the same data:
- TALENT_POINTS: a talent's value at each of its ranks (Forever's talents are trait nodes: TraitDefinition's spell,
  TraitDefinitionEffectPoints' curve for an effect, CurvePoint's rank and value), the game giving no points for a
  talent; "<effect index>:<operation, 0 set, 1 multiply>:<rank 1's>,<rank 2's>,...".
- ENCHANTS: what an enchantment on an item gives (SpellItemEnchantment): a stat by the game's own name for it, the
  part between ITEM_MOD_ and _SHORT that C_Item.GetItemStats keys an item's by ("STRENGTH:7"), a resistance by its
  RESISTANCE<n>_NAME ("RESISTANCE2:10"), the armour as an item's bonus armour ("EXTRA_ARMOR:24"), an empty amount
  where the game scales it to the item's level; or the spell it puts on its wearer ("s:12345"), kept in EFFECTS.
- ITEM_SETS: the spells a set gives from so many of its pieces worn (ItemSetSpell), "<pieces>:<spell>;...".
- ITEM_SPELLS: an item's own spells while it's worn, its « Équipé : » lines (ItemXItemEffect's ItemEffect, on equip:
  trigger 1), kept in EFFECTS, "<spell>;...". C_Item.GetItemStats gives an item's stats, not those (Ikar 2026-11-19,
  of the review's 186 such bonuses that nothing named: "They shoudl show").
- ITEM_USES: the spells an item puts on whoever uses it (the same tables, on use: trigger 0), kept in EFFECTS: an
  elixir's, a scroll's, a flask's. What the card kept open tries when one is under the pointer (Ikar 2026-11-19:
  "update with a different color on an item, talent, consumable hover"). A meal's buff isn't its use's own spell:
  eating is, which gives the buff after a while by one of its effects (SpellEffect's EffectTriggerSpell); the spells
  a use gives rise to that way are followed, twice at most, and kept with it (Ikar, of meals said not to work: "wait,
  why meal does not work ?").
- PASSIVES: the race's and class's passive spells (SkillLineAbility's, SpellMisc's passive attribute) kept in EFFECTS,
  talents' left out: the game says which the character knows (C_SpellBook.IsSpellKnown).
- EFFECT_NEEDS: what one of those spells needs to count, not being an aura the game applies (SpellEquippedItems,
  SpellShapeshift): "i:<item class>:<subclass mask>" a weapon or armour of a kind worn (a weapon specialisation, a
  shield), "f:<forms mask>:<forms mask past 32>:<forms left out>:<past 32>" a form (or none of some).
- BASE_MANA: a class's base mana by level, what its mana stands on before the intellect (PlayerExpectedStat's, the
  game's own; Ikar 2026-11-21, of the bases: "what is the logic from 24 to 40 ? same for everything"). The game's
  data has no such table of the attributes or the health: the server sends their sum.

- HIDDEN_PARTS: the hidden auras a visible one's text names, each by the start of its line in each language: the
  camp's « Avantages du camp » 1229741 and its benefits (Ikar 2026-11-22: "we see it in avantages de feux de camps").
  The client gives addons none of them (GetPlayerAuraBySpellID: nothing for any, Ikar's fish bowl's included, Ikar's
  check of the same day). But it writes each one's line, "$?a<spell>[<line>][]" in the visible one's text, in that
  aura's tooltip while the character has it (C_TooltipInfo.GetUnitBuffByAuraInstanceID: « Bocal à poisson :
  augmentation de toutes les caractéristiques de 8 %. », the same check). Its figures there are the aura's own
  ("$<spell>w<n>"), which can be less than the data's: each effect's `w` says which of them is its. The camp's mana
  well among them since 2026-11-23, its `every` the seconds between two of its gains: the game's regeneration figure
  doesn't count it, so the card says it on top (Ikar: "the mana regen do not takeinto account buff camp, why ?").
- XP_BONUSES: the spells that change the experience gained, from creatures (aura 200) and from quests (291), with the
  data's figures; XP_PARTS, those of them hidden, by the visible aura whose tooltip writes their line, as
  HIDDEN_PARTS (a meal's « Bien nourri » writes « Expérience gagnée en éliminant des adversaires augmentée de 5 % »).
  The XP bar's tooltip lists them (Ikar 2026-11-23: "the xp bar shoudl also have all the bonuses listed (and the
  total) this include any buff to xp, sleeping bag, rewsted, camp, food etc.").
- PERIODIC: what an aura gives by itself every few seconds, which the game's regeneration figures don't count (the
  review of 2026-11-23: Blessing of Wisdom, Mana Spring Totem, Mana Tide and the soups give mana so, as the camp's
  well, and no card said it): 24 mana (its misc 0), 8 health, 20 a share of the most health, each with its period;
  84 the health in 5 s while eating. Its points as EFFECTS' (none where they grow with the caster's power: a HoT's).
  An item used counts its own (ITEM_USES): a meal tried on a card kept open.
- REP_BONUSES: the spells that change the reputation gained (Ikar 2026-11-23: "Reputation bonuses to the rep bar"):
  156 with every faction (the human's Diplomacy), 190 with one, its misc the faction (Cenarion Favor).

The tables beyond SpellEffect, SkillLine and SkillLineAbility come from wago.tools: --fetch downloads those missing
into the reference copies' db2 folder for this build, the Spell table in each language HIDDEN_PARTS speaks.

Run with: python -I hud/tools/make_effects.py [--fetch]
"""
import csv
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.art import BUILD  # noqa: E402
from kali.paths import REFERENCE  # noqa: E402

ADDON = ROOT / "hud/addon/KaLiHUD"
TARGET = ADDON / "Data/Effects.lua"
DB2 = REFERENCE / "db2" / BUILD
DEFENSE = 95
ARMOR_AND_SCHOOLS = 1 | 2 | 4 | 8 | 16 | 32 | 64
MAGIC = 2 | 4 | 8 | 16 | 32 | 64
ANY = {133, 135, 34, 230, 250, 54, 55, 52, 57, 290, 49, 47, 51, 319, 192, 140, 342, 65, 216, 193, 31, 129, 33, 171,
       32, 130, 172, 58, 240, 317, 9, 557, 466, 178, 161, 88, 116, 272, 274,
       # the healing taken, 118 by a share, 115 by points on each heal (Ikar 2026-11-24: "add the healing taken"); the
       # healing done by a share, 136 (Power Infusion), with the talents of HEAL_TALENTS
       118, 115, 136,
       # the panel of 2026-11-26 (Ikar: "add the threat and damage reduction", "add camo", "add epine", "a whole row
       # maybe for attack againt a type"): 10 the threat by a share (its misc the schools), 87 the damage taken by a
       # share and 14 by points (the same misc), 15 the damage done back to who strikes (thorns, spikes), 154 the
       # stealth's level and 17 its detection, 102 and 131 the melee and ranged attack power against a creature type
       # (its misc a mask of the types), 180 the spells' damage against one
       10, 87, 14, 15, 154, 17, 102, 131, 180}
# The classes' main heals, by their first rank, under their class's number in SpellClassOptions (6 the priest's, 7 the
# druid's, 11 the shaman's, 10 the paladin's): a talent that raises healing by a share (108, on the amount, misc 0, or
# over time, 22) counts as healing done (136) when its effects' spell codes take in every one of them (Ikar 2026-11-24:
# "heal power should count only when it affect all spels. Or the main spells at least"): Spiritual Healing,
# Purification, Gift of Nature, Healing Light; not those of one spell (Improved Renew) or some (Twin Disciplines).
MAIN_HEALS = {6: (2050, 2054, 2060, 2061, 139, 596), 7: (5185, 8936, 774, 740), 11: (331, 8004, 1064),
              10: (635, 19750)}
HEAL_SHARE, HEALING_DONE = 108, 136
# The combat ratings the sheet shows a value of, as aura 189's mask has them: the bit of the game's CR_ number less
# one (defence 2, dodge 3, parry 4, block 5, hit 6 to 8, critical strike 9 to 11, haste 18 to 20, expertise 24: the
# tier 1 sets' four pieces of a tank).
RATINGS = sum(1 << (cr - 1) for cr in (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 18, 19, 20, 24))
# The tables this needs from wago.tools, beyond those the family's tools already keep.
FETCHED = ("SpellItemEnchantment", "ItemSetSpell", "SpellMisc", "SpellEquippedItems", "SpellShapeshift",
           "TraitDefinition", "TraitDefinitionEffectPoints", "CurvePoint", "SpellLevels", "PlayerExpectedStat",
           "SpellClassOptions")
# The classes by the game's number (ChrClasses), as UnitClass names them.
CLASS_FILES = {1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK",
               11: "DRUID"}
# SpellMisc's Attributes_0: a passive spell (SPELL_ATTR0_PASSIVE).
PASSIVE = 0x40
# SpellMisc's Attributes_0: an aura the client shows no one, addons included (SPELL_ATTR0_DO_NOT_DISPLAY).
HIDDEN = 0x80
# The auras of the experience gained, from creatures and from quests; a power gained every few seconds by itself.
XP_KILLS, XP_QUESTS, ENERGIZE = 200, 291, 24
# What an aura gives by itself every few seconds (PERIODIC): mana (24, misc 0), health (8), a share of the most health
# (20), eating's health in 5 s (84, its period the server's own five seconds).
PERIODIC_KINDS, EATING, EATING_PERIOD = {24, 8, 20, 84}, 84, 5000
# The auras of the reputation gained: with every faction, with one (its misc).
REP_ALL, REP_ONE = 156, 190
# The languages the addon speaks, for HIDDEN_PARTS' lines: the Spell table in each (Spell.csv the English one's).
LANGUAGES = ("enUS", "frFR", "deDE", "esES", "esMX")
# An item's stats by the game's number (the ItemModType the item and enchantment tables use), each by its name in
# ITEM_MOD_<name>_SHORT, the key C_Item.GetItemStats gives it; the resistances by RESISTANCE<school>_NAME's school.
STATS = {
    0: "MANA", 1: "HEALTH", 3: "AGILITY", 4: "STRENGTH", 5: "INTELLECT", 6: "SPIRIT", 7: "STAMINA",
    12: "DEFENSE_SKILL_RATING", 13: "DODGE_RATING", 14: "PARRY_RATING", 15: "BLOCK_RATING", 31: "HIT_RATING",
    32: "CRIT_RATING", 35: "RESILIENCE_RATING", 36: "HASTE_RATING", 37: "EXPERTISE_RATING", 38: "ATTACK_POWER",
    39: "RANGED_ATTACK_POWER", 41: "SPELL_HEALING_DONE", 42: "SPELL_DAMAGE_DONE", 43: "MANA_REGENERATION",
    44: "ARMOR_PENETRATION_RATING", 45: "SPELL_POWER", 46: "HEALTH_REGEN", 47: "SPELL_PENETRATION",
    48: "BLOCK_VALUE", 50: "EXTRA_ARMOR",
}
RESISTANCE_STATS = {51: 2, 52: 4, 53: 1, 54: 5, 55: 3, 56: 6}
# Each number's word in the enchantments' English names, where one names it: the list above checked against the
# game's own data, as the defence's skill line is.
STAT_WORDS = {3: "Agility", 4: "Strength", 5: "Intellect", 6: "Spirit", 7: "Stamina", 12: "Defense", 13: "Dodge",
              32: "Critical", 38: "Attack Power", 0: "Mana", 1: "Health", 51: "Fire Resistance",
              52: "Frost Resistance", 54: "Shadow Resistance", 55: "Nature Resistance", 56: "Arcane Resistance"}
SCHOOL_WORDS = {0: "Armor", 1: "Holy", 2: "Fire", 3: "Nature", 4: "Frost", 5: "Shadow", 6: "Arcane"}


def spell_table(lang):
    """The Spell table's file in a language, the English one's without its name."""
    return "Spell" if lang == "enUS" else f"Spell.{lang}"


def fetch():
    """The tables missing from the reference copies, downloaded for this build."""
    DB2.mkdir(parents=True, exist_ok=True)
    wanted = [(table, table, "") for table in FETCHED]
    wanted += [(spell_table(lang), "Spell", "" if lang == "enUS" else f"&locale={lang}") for lang in LANGUAGES]
    for name, table, locale in wanted:
        path = DB2 / f"{name}.csv"
        if not path.exists():
            url = f"https://wago.tools/db2/{table}/csv?build={BUILD}{locale}"
            # (a client's name, as kali/art.py's: the site refuses Python's own, 403)
            req = urllib.request.Request(url, headers={"User-Agent": "wow-addon-testbench"})
            with urllib.request.urlopen(req, timeout=120) as r:
                path.write_bytes(r.read())
            print(f"fetched: {name}")


def rows(table):
    path = DB2 / f"{table}.csv"
    if not path.exists():
        sys.exit(f"{path} is missing: run python -I hud/tools/make_effects.py --fetch")
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def kept(aura, misc, second=0):
    """Whether an aura of this kind on this misc (and its second) changes one of the sheet's attributes or a skill the
    tooltips name sources of."""
    if aura in (29, 80, 137):
        return -1 <= misc <= 4
    if aura in (99, 124, 166, 167):
        return True
    if aura == 674:
        return misc == 1
    if aura in (22, 83, 101):
        return misc & ARMOR_AND_SCHOOLS != 0
    if aura in (30, 98):
        return misc > 0
    if aura in (13, 79):
        return misc & (MAGIC | 1) != 0
    if aura == 123:
        return misc & (MAGIC | 1) != 0
    if aura == 280:
        # the armour ignored by a share (Serrated Blades, Weapon Mastery): named on the armour penetration's card
        return True
    if aura == 174:
        return misc & MAGIC == MAGIC and 0 <= second <= 4
    if aura in (175, 598):
        return 0 <= misc <= 4
    if aura == 35:
        return True
    if aura in (85, 110, 134):
        return misc == 0
    if aura == 142:
        return misc == 1
    if aura == 189:
        return misc & RATINGS != 0
    return aura in ANY


_LEVELS = {}


def levels(spell):
    """A spell's levels (SpellLevels): the level it is of, the lowest and the highest its caster's counts at (0: none);
    (0, 0, 0) for a spell with none."""
    if not _LEVELS:
        for r in rows("SpellLevels"):
            if r["DifficultyID"] == "0":
                _LEVELS[int(r["SpellID"])] = (int(r["SpellLevel"] or 0), int(r["BaseLevel"] or 0),
                                              int(r["MaxLevel"] or 0))
    return _LEVELS.get(spell, (0, 0, 0))


def fixed(row):
    """The effect's points as the data gives them, when they're the aura's own whoever casts it; else "". A 0 written
    "0": a blank is a figure missing, which the card marks, and 0 points are none (the audit of 2026-11-19: Berserker
    Stance's attack power, 0, was marked as unknown). Points that grow with the caster's level written as their sum,
    "<base>@<a level's>,<spell's level>,<lowest>,<highest>": the server's, base + a level's × (the caster's level held
    between lowest and highest, less the spell's), its product cut to a whole; the card works it out at the
    character's (Ikar 2026-11-19: "questio nmark shoudl be present only when there is a question. And the description
    should give an answer"; a druid's forms, a shaman's Rockbiter, checked: Dire Bear Form 120 + 3 a level from 40,
    180 at 60, 3 a level as the original game's)."""
    per = float(row["EffectRealPointsPerLevel"] or 0)
    if row["ScalingClass"] not in ("", "0") or float(row["Coefficient"] or 0) != 0:
        return ""
    v = float(row["EffectBasePointsF"] or 0)
    if per != 0:
        spell_level, lowest, highest = levels(int(row["SpellID"]))
        return f"{number(v) or 0}@{number(per)},{spell_level},{lowest},{highest}"
    return "0" if v == 0 else number(v)


def number(v):
    """A value as the file writes it: whole without its point, else as Python writes it; "" for 0."""
    return "" if v == 0 else (str(int(v)) if v == int(v) else repr(v))


def heal_talents():
    """The talents whose healing share takes in all their class's main heals (MAIN_HEALS): each one's effect kept as
    the healing done's, its share on the amount first."""
    def masks(r, prefix):
        return [int(r[f"{prefix}{i}"] or 0) & 0xFFFFFFFF for i in range(4)]
    options = {int(r["SpellID"]): (int(r["SpellClassSet"]), masks(r, "SpellClassMask_"))
               for r in rows("SpellClassOptions")}
    talents = {int(d["SpellID"] or 0) for d in rows("TraitDefinition")}
    shares = defaultdict(list)
    for r in rows("SpellEffect"):
        if (r["DifficultyID"] == "0" and r["EffectAura"] == str(HEAL_SHARE) and r["EffectMiscValue_0"] in ("0", "22")
                and int(r["SpellID"]) in talents):
            shares[int(r["SpellID"])].append(r)
    out = {}
    for spell, found in sorted(shares.items()):
        main = MAIN_HEALS.get(options.get(spell, (None,))[0])
        codes = [masks(r, "EffectSpellClassMask_") for r in found]

        def covered(heal, codes=codes):
            own = options.get(heal)
            return own is not None and any(any(a & b for a, b in zip(code, own[1])) for code in codes)
        if main and all(covered(heal) for heal in main):
            first = min(found, key=lambda r: (r["EffectMiscValue_0"] != "0", int(r["EffectIndex"])))
            out[spell] = int(first["EffectIndex"])
    return out


def effects():
    """Each spell with an effect kept: its effects' count, its auras' count, and those effects."""
    skills = {row["ID"]: row["DisplayName_lang"] for row in rows("SkillLine.frFR")}
    assert skills.get(str(DEFENSE)) == "Défense", f"skill {DEFENSE} isn't defence in {BUILD}: {skills.get(str(DEFENSE))}"
    spells = {}
    for row in rows("SpellEffect"):
        if row["DifficultyID"] == "0":
            spells.setdefault(int(row["SpellID"]), []).append(row)
    out = {}
    healers = heal_talents()
    for spell, found in sorted(spells.items()):
        found.sort(key=lambda r: int(r["EffectIndex"]))
        auras = [r for r in found if r["EffectAura"] != "0"]
        parts = []
        for place, r in enumerate(auras):
            aura, misc = int(r["EffectAura"]), int(r["EffectMiscValue_0"] or 0)
            second = int(r["EffectMiscValue_1"] or 0)
            if aura == HEAL_SHARE and healers.get(spell) == int(r["EffectIndex"]):
                # (a healing talent that takes in its class's main heals: as the healing done's, on every school)
                parts.append(f"{HEALING_DONE}:127:{r['EffectIndex']}:{place}:{fixed(r)}")
                continue
            # (466 beside a 142 of the same spell its twin, the same share: the forms', Toughness'; alone on two
            # debuffs only)
            twin = aura == 466 and any(x["EffectAura"] == "142" for x in auras)
            if kept(aura, misc, second) and not twin:
                # (174's attribute is its second misc, its first the schools, all of them; 137's attributes its
                # second, a mask, 0 all)
                if aura == 174:
                    misc = second
                elif aura == 137:
                    misc = second or 31
                parts.append(f"{aura}:{misc}:{r['EffectIndex']}:{place}:{fixed(r)}")
        if parts:
            count = max(int(r["EffectIndex"]) for r in found) + 1
            out[spell] = f"{count},{len(auras)};" + ";".join(parts)
    return out


def talent_points(kept_spells):
    """Each talent's spell kept, its values by rank: effect index, operation, the curve's values from rank 1."""
    curves = defaultdict(list)
    for r in rows("CurvePoint"):
        curves[r["CurveID"]].append((float(r["Pos_0"]), float(r["Pos_1"])))
    by_definition = defaultdict(list)
    for r in rows("TraitDefinitionEffectPoints"):
        by_definition[r["TraitDefinitionID"]].append(r)
    out, talents = {}, set()
    for d in rows("TraitDefinition"):
        spell = int(d["SpellID"] or 0)
        if not spell:
            continue
        talents.add(spell)
        if spell not in kept_spells:
            continue
        parts = []
        for p in sorted(by_definition.get(d["ID"], []), key=lambda p: int(p["EffectIndex"])):
            points = sorted(curves.get(p["CurveID"], []))
            ranks = [v for rank, v in points if rank >= 1]
            if ranks:
                parts.append(f"{p['EffectIndex']}:{p['OperationType']}:" + ",".join(number(v) or "0" for v in ranks))
        if parts and spell not in out:
            out[spell] = ";".join(parts)
    return out, talents


def enchants(kept_spells):
    """Each enchantment that gives a sheet's value: its stats by the game's names, a resistance, its spells."""
    found = defaultdict(set)
    names = {}
    out = {}
    for r in rows("SpellItemEnchantment"):
        parts = []
        for i in range(3):
            kind, arg = int(r[f"Effect_{i}"] or 0), int(r[f"EffectArg_{i}"] or 0)
            points = number(float(r[f"EffectPointsMin_{i}"] or 0))
            if kind == 5:
                if arg in STATS:
                    parts.append(f"{STATS[arg]}:{points}")
                elif arg in RESISTANCE_STATS:
                    parts.append(f"RESISTANCE{RESISTANCE_STATS[arg]}:{points}")
                else:
                    continue
                found[arg].add(r["Name_lang"])
            elif kind == 4:
                parts.append(f"EXTRA_ARMOR:{points}" if arg == 0 else f"RESISTANCE{arg}:{points}")
                found[("school", arg)].add(r["Name_lang"])
            elif kind == 3 and arg in kept_spells:
                parts.append(f"s:{arg}")
        if parts:
            out[int(r["ID"])] = ";".join(parts)
            names[int(r["ID"])] = r["Name_lang"]
    # The stats' numbers checked against the enchantments' own English names
    for arg, word in STAT_WORDS.items():
        if arg in found:
            assert any(word in n for n in found[arg]), f"stat {arg} isn't {word} in {BUILD}: {sorted(found[arg])[:5]}"
    for school, word in SCHOOL_WORDS.items():
        if ("school", school) in found:
            assert any(word in n for n in found[("school", school)]), \
                f"school {school} isn't {word} in {BUILD}: {sorted(found[('school', school)])[:5]}"
    return dict(sorted(out.items()))


def item_sets(kept_spells):
    """Each set whose pieces give a sheet's value: the pieces needed and the spell, fewest first."""
    out = defaultdict(list)
    for r in rows("ItemSetSpell"):
        spell = int(r["SpellID"] or 0)
        if spell in kept_spells:
            out[int(r["ItemSetID"])].append((int(r["Threshold"] or 0), spell))
    return {s: ";".join(f"{n}:{spell}" for n, spell in sorted(set(v))) for s, v in sorted(out.items())}


def item_spells(kept_spells, trigger="1"):
    """Each item whose own spells while worn (or, trigger 0, once used) give a sheet's value, by item. A use's spell
    with those it gives rise to (a meal's buff, by the eating's periodic effect), two steps away at most."""
    on_equip = {int(r["ID"]): int(r["SpellID"] or 0) for r in rows("ItemEffect") if r["TriggerType"] == trigger}
    gives = defaultdict(set)
    if trigger == "0":
        for r in rows("SpellEffect"):
            if r["DifficultyID"] == "0" and int(r["EffectTriggerSpell"] or 0):
                gives[int(r["SpellID"])].add(int(r["EffectTriggerSpell"]))
    out = defaultdict(set)
    for r in rows("ItemXItemEffect"):
        spell = on_equip.get(int(r["ItemEffectID"]))
        reached, edge = {spell}, {spell}
        for _ in range(2):
            edge = {t for s in edge for t in gives.get(s, ())} - reached
            reached |= edge
        for found in reached:
            if found in kept_spells:
                out[int(r["ItemID"])].add(found)
    return {i: ";".join(str(spell) for spell in sorted(v)) for i, v in sorted(out.items())}


def passives(kept_spells, talents):
    """The passive spells a race or a class learns, kept, talents' left out."""
    passive = {int(r["SpellID"]) for r in rows("SpellMisc") if r["DifficultyID"] in ("", "0")
               and int(r["Attributes_0"] or 0) & PASSIVE}
    learnt = {int(r["Spell"]) for r in rows("SkillLineAbility")}
    return sorted((passive & learnt & set(kept_spells)) - talents)


def needs(spells):
    """What each of these spells needs to count when it isn't an aura the game applies: an item worn, a form."""
    out = defaultdict(list)
    for r in rows("SpellEquippedItems"):
        spell, cls = int(r["SpellID"]), int(r["EquippedItemClass"] or -1)
        if spell in spells and cls >= 0:
            out[spell].append(f"i:{cls}:{int(r['EquippedItemSubclass'] or 0)}")
    for r in rows("SpellShapeshift"):
        spell = int(r["SpellID"])
        masks = [int(r[k] or 0) for k in ("ShapeshiftMask_0", "ShapeshiftMask_1", "ShapeshiftExclude_0",
                                          "ShapeshiftExclude_1")]
        if spell in spells and any(masks):
            out[spell].append("f:" + ":".join(str(m) for m in masks))
    return {s: ";".join(sorted(set(v))) for s, v in sorted(out.items())}


def base_mana():
    """Each class's base mana by level, from 1 on, for one that has some."""
    by = defaultdict(dict)
    for r in rows("PlayerExpectedStat"):
        token = CLASS_FILES.get(int(r["ClassID"]))
        if token and r["ContentSetID"] == "0":
            by[token][int(r["Level"])] = int(r["BaseMana"])
    out = {}
    for token, levels in sorted(by.items()):
        assert sorted(levels) == list(range(1, max(levels) + 1)), token
        if any(levels.values()):
            out[token] = ",".join(str(levels[n]) for n in range(1, max(levels) + 1))
    return out


def energizers():
    """The spells that give mana by themselves every few seconds (a periodic gain of it, aura 24 on mana), by the
    seconds between two: the camp's mana well, 29 every 5 s, which the game's regeneration figure doesn't count (Ikar
    2026-11-23: "the mana regen do not takeinto account buff camp, why ?")."""
    out = {}
    for r in rows("SpellEffect"):
        if (r["DifficultyID"] in ("", "0") and r["EffectAura"] == str(ENERGIZE) and r["EffectMiscValue_0"] == "0"
                and int(r["EffectAuraPeriod"] or 0) > 0):
            out.setdefault(int(r["SpellID"]), int(r["EffectAuraPeriod"]) / 1000)
    return out


def xp_bonuses():
    """The spells that change the experience gained, "k:<effect index>:<points>" from creatures, "q:..." from quests,
    the data's points, a share in percent (Ikar 2026-11-23: "the xp bar shoudl also have all the bonuses listed (and
    the total) this include any buff to xp, sleeping bag, rewsted, camp, food etc.")."""
    out = defaultdict(list)
    for r in rows("SpellEffect"):
        if r["DifficultyID"] in ("", "0") and r["EffectAura"] in (str(XP_KILLS), str(XP_QUESTS)):
            kind = "k" if r["EffectAura"] == str(XP_KILLS) else "q"
            points = float(r["EffectBasePointsF"] or 0)
            out[int(r["SpellID"])].append((int(r["EffectIndex"]), f"{kind}:{r['EffectIndex']}:{points:g}"))
    return {spell: ";".join(text for _, text in sorted(parts)) for spell, parts in sorted(out.items())}


def periodic():
    """Each spell giving mana or health by itself every few seconds: its effects' count, its auras' count, and those
    effects, "<kind>:<effect index>:<place among its auras>:<period, ms>:<points>", the points as EFFECTS' (none where
    they grow with the caster's power). Eating's period the server's five seconds; a gain without a period none."""
    spells = defaultdict(list)
    for r in rows("SpellEffect"):
        if r["DifficultyID"] in ("", "0"):
            spells[int(r["SpellID"])].append(r)
    out = {}
    for spell, found in sorted(spells.items()):
        found.sort(key=lambda r: int(r["EffectIndex"]))
        auras = [r for r in found if r["EffectAura"] != "0"]
        parts = []
        for place, r in enumerate(auras):
            aura = int(r["EffectAura"])
            if aura not in PERIODIC_KINDS or (aura == ENERGIZE and r["EffectMiscValue_0"] not in ("", "0")):
                continue
            period = EATING_PERIOD if aura == EATING else int(r["EffectAuraPeriod"] or 0)
            if period > 0:
                parts.append(f"{aura}:{r['EffectIndex']}:{place}:{period}:{fixed(r)}")
        if parts:
            count = max(int(r["EffectIndex"]) for r in found) + 1
            out[spell] = f"{count},{len(auras)};" + ";".join(parts)
    return out


def rep_bonuses():
    """The spells that change the reputation gained, "a:<effect index>:<percent>" with every faction,
    "f:<effect index>:<percent>:<faction>" with one, the data's figures."""
    out = defaultdict(list)
    for r in rows("SpellEffect"):
        if r["DifficultyID"] in ("", "0") and r["EffectAura"] in (str(REP_ALL), str(REP_ONE)):
            points = float(r["EffectBasePointsF"] or 0)
            text = f"a:{r['EffectIndex']}:{points:g}" if r["EffectAura"] == str(REP_ALL) else \
                f"f:{r['EffectIndex']}:{points:g}:{int(r['EffectMiscValue_0'] or 0)}"
            out[int(r["SpellID"])].append((int(r["EffectIndex"]), text))
    return {spell: ";".join(text for _, text in sorted(parts)) for spell, parts in sorted(out.items())}


def hidden_parts(wanted, every=None):
    """The hidden auras, among `wanted`, that a visible one's text names, each with the start of its line in each
    language: what its "$?a<spell>[<line>][]" holds before its first figure, the line the client writes in the visible
    one's tooltip while the character has that aura (its start anywhere in that line: a meal's experience follows its
    attribute's sentence). And which of the line's figures each of its effects has: the line writes them as
    "$<spell>w<n>", the aura's own amount on the character, not the data's (Forever gives less at a low level: Ikar's
    incense candle, +25 in the data, 2026-11-22). An effect the line doesn't write takes the figure of an earlier one
    of the same aura and points (the lute's resistances but the first), else none (0). With `every` (energizers'), the
    seconds between two of its gains."""
    every = every or {}
    attributes = {int(r["SpellID"]): int(r["Attributes_0"] or 0) for r in rows("SpellMisc")
                  if r["DifficultyID"] in ("", "0")}
    hidden = {s for s, a in attributes.items() if a & HIDDEN and not a & PASSIVE and s in wanted}
    texts = {lang: {int(r["ID"]): r["AuraDescription_lang"] for r in rows(spell_table(lang))} for lang in LANGUAGES}
    effects_of = {}
    for r in rows("SpellEffect"):
        if r["DifficultyID"] in ("", "0"):
            effects_of.setdefault(int(r["SpellID"]), []).append(r)
    out = {}
    for spell, text in sorted(texts["enUS"].items()):
        if attributes.get(spell, 0) & HIDDEN:
            continue
        parts = []
        for part in dict.fromkeys(int(p) for p in re.findall(r"\$\?a(\d+)\[", text)):
            starts = {}
            for lang in LANGUAGES:
                said = re.search(r"\$\?a" + str(part) + r"\[([^\]$]+)", texts[lang].get(spell, ""))
                if said and said.group(1).strip():
                    starts[lang] = said.group(1)
            if part in hidden and starts:
                # the n-th figure of its line is its "w<n>" in every language, or the addon can't tell them apart
                written = set()
                for lang in LANGUAGES:
                    line = re.search(r"\$\?a" + str(part) + r"\[([^\]]*)\]", texts[lang].get(spell, ""))
                    order = [int(n) for n in re.findall(r"\$" + str(part) + r"w(\d)", line.group(1))] if line else []
                    assert order == list(range(1, len(order) + 1)), (spell, part, lang, order)
                    written.update(order)
                which, same = [], {}
                for e in sorted(effects_of.get(part, []), key=lambda e: int(e["EffectIndex"])):
                    n = int(e["EffectIndex"]) + 1
                    key = (e["EffectAura"], e["EffectBasePointsF"])
                    which.append(n if n in written else same.get(key, 0))
                    same.setdefault(key, which[-1])
                parts.append((part, starts, which, every.get(part)))
        if parts:
            out[spell] = parts
    return out


def lua_string(text):
    """The text as a Lua string."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def build():
    found = effects()
    points, talents = talent_points(found)
    gives = enchants(found)
    sets = item_sets(found)
    worn = item_spells(found)
    timed = periodic()
    used = item_spells(set(found) | set(timed), "0")
    learnt = passives(found, talents)
    sources = set(points) | set(learnt) | {int(s.split(":")[1]) for v in sets.values() for s in v.split(";")}
    sources |= {int(p[2:]) for v in gives.values() for p in v.split(";") if p.startswith("s:")}
    sources |= talents & set(found)
    sources |= {int(spell) for v in worn.values() for spell in v.split(";")}
    wants = needs(sources)
    lines = [
        f"-- Generated by hud/tools/make_effects.py from Forever's game data ({BUILD}): what each spell's auras change",
        "-- among the character sheet's attributes, for their tooltips' sources (UI/Hub/Infos/Stats.lua). Each spell:",
        '-- "<its effects' + "'" + ' count>,<its auras' + "'" + ' count>;<aura>:<misc>:<effect index>:<place among its auras>:',
        "-- <its points when they're its own whoever casts it>;...\", an aura by the game's number (hud/tools/make_effects.py",
        "-- lists them: 29 an attribute, 99 and 124 the attack powers, 674 the armour, 22 the resistances, 13 the spells'",
        "-- damage...). Don't edit.",
        "local _, ns = ...",
        "",
        "ns.EFFECTS = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in found.items()]
    lines += ["}", ""]
    lines += [
        "-- A talent's values by rank: \"<effect index>:<0 set, 1 multiply>:<rank 1's>,<rank 2's>,...;...\".",
        "ns.TALENT_POINTS = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in sorted(points.items())]
    lines += ["}", ""]
    lines += [
        "-- An enchantment's stats, by the game's names (ITEM_MOD_<name>_SHORT, RESISTANCE<n>_NAME; the armour as bonus",
        "-- armour), \"<name>:<amount>\", no amount where it follows the item's level; its spells, \"s:<spell>\".",
        "ns.ENCHANTS = {",
    ]
    lines += [f'    [{e}] = "{text}",' for e, text in gives.items()]
    lines += ["}", ""]
    lines += [
        "-- A set's spells from so many pieces worn: \"<pieces>:<spell>;...\".",
        "ns.ITEM_SETS = {",
    ]
    lines += [f'    [{s}] = "{text}",' for s, text in sets.items()]
    lines += ["}", ""]
    lines += [
        "-- An item's own spells while it's worn (its « Équipé : » lines): \"<spell>;...\".",
        "ns.ITEM_SPELLS = {",
    ]
    lines += [f'    [{i}] = "{text}",' for i, text in worn.items()]
    lines += ["}", ""]
    lines += [
        "-- The spells an item puts on whoever uses it (an elixir's, a scroll's): \"<spell>;...\".",
        "ns.ITEM_USES = {",
    ]
    lines += [f'    [{i}] = "{text}",' for i, text in used.items()]
    lines += ["}", ""]
    lines += ["-- The passive spells a race or a class learns, the talents' left out.", "ns.PASSIVES = {"]
    for i in range(0, len(learnt), 12):
        lines.append("    " + " ".join(f"{s}," for s in learnt[i:i + 12]))
    lines += ["}", ""]
    lines += [
        "-- What such a spell needs to count: \"i:<item class>:<subclass mask>\" an item of a kind worn, \"f:<forms>:<forms",
        "-- past 32>:<forms left out>:<past 32>\" a form, masks by the form's number less one.",
        "ns.EFFECT_NEEDS = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in wants.items()]
    lines += ["}", ""]
    mana = base_mana()
    lines += [
        "-- A class's base mana by level, from 1 on: \"<level 1's>,<level 2's>,...\".",
        "ns.BASE_MANA = {",
    ]
    lines += [f'    {token} = "{text}",' for token, text in mana.items()]
    lines += ["}", ""]
    gains = energizers()
    hidden = hidden_parts(set(found) | set(gains), gains)

    def parts_lines(table):
        out = []
        for spell, parts in table.items():
            out.append(f"    [{spell}] = {{")
            for part, starts, which, seconds in parts:
                said = ", ".join(f"{lang} = {lua_string(start)}" for lang, start in starts.items())
                then = f", every = {seconds:g}" if seconds else ""
                out.append(f"        {{ {part}, {said}, w = {{ {', '.join(str(n) for n in which)} }}{then} }},")
            out.append("    },")
        return out
    lines += [
        "-- The hidden auras a visible one's text names, which the client gives no addon but writes a line of in the",
        "-- visible one's tooltip while the character has it (the camp's « Avantages du camp »): by visible spell,",
        "-- { <hidden spell>, <the start of its line> by language, w = { which of the line's figures each effect has,",
        "-- in the effects' order, 0 for none }, every = <the seconds between two gains of mana it gives by itself> }.",
        "ns.HIDDEN_PARTS = {",
    ]
    lines += parts_lines(hidden)
    lines += ["}", ""]
    xp = xp_bonuses()
    xp_hidden = hidden_parts(set(xp))
    lines += [
        "-- The spells that change the experience gained, from creatures \"k:<effect index>:<percent>\", from quests",
        "-- \"q:...\", the data's figures.",
        "ns.XP_BONUSES = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in xp.items()]
    lines += ["}", ""]
    lines += [
        "-- Those hidden, by the visible aura whose tooltip writes their line (a meal's « Bien nourri »), as",
        "-- HIDDEN_PARTS.",
        "ns.XP_PARTS = {",
    ]
    lines += parts_lines(xp_hidden)
    lines += ["}", ""]
    lines += [
        "-- What an aura gives by itself every few seconds, which the game's regeneration figures don't count: \"<its",
        "-- effects' count>,<its auras' count>;<kind>:<effect index>:<place among its auras>:<period, ms>:<points>;...\",",
        "-- 24 mana, 8 health, 20 a share of the most health, 84 the health in 5 s while eating; no points where they",
        "-- grow with the caster's power.",
        "ns.PERIODIC = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in timed.items()]
    lines += ["}", ""]
    rep = rep_bonuses()
    lines += [
        "-- The spells that change the reputation gained, with every faction \"a:<effect index>:<percent>\", with one",
        "-- \"f:<effect index>:<percent>:<faction>\", the data's figures.",
        "ns.REP_BONUSES = {",
    ]
    lines += [f'    [{spell}] = "{text}",' for spell, text in rep.items()]
    lines += ["}", ""]
    counts = {"talents": len(points), "enchants": len(gives), "sets": len(sets), "items": len(worn),
              "uses": len(used),
              "passives": len(learnt), "needs": len(wants), "mana classes": len(mana),
              "hidden parts": sum(len(parts) for parts in hidden.values()), "xp bonuses": len(xp),
              "xp parts": sum(len(parts) for parts in xp_hidden.values()), "timed gains": len(timed),
              "rep bonuses": len(rep)}
    build.counts = counts
    return "\n".join(lines), len(found)


def main():
    if "--fetch" in sys.argv:
        fetch()
    text, count = build()
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    extra = ", ".join(f"{n} {k}" for k, n in build.counts.items())
    print(f"written: Data/Effects.lua, {count} spells, {extra}")


if __name__ == "__main__":
    main()
