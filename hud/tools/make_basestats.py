"""Each race and class's base attributes at each level, for the attributes' cards (UI/Hub/Infos/Stats.lua; Ikar
2026-11-23: "what each level give ?", "crawl the internet, download all stat for each class, for each race, level by
level", then "go"). Writes Data/BaseStats.lua.

The game's client has none of it: the server sends a character's base whole (UnitStat), and at a level-up what that
level gave (PLAYER_LEVEL_UP). The figures are the original game's own table, the 40 race and class pairs at levels 1
to 60 (MaNGOS Zero's `player_levelstats`, kept in the reference folder as basestats/player_levelstats.sql). Forever's
eight original races take the original game's offsets (its developers, ClassicWoWCommunity/forever-bugs#414: "fixed on
our end to match Vanilla"); its two Skyborne races, their own, read from level 1 sheets (wowsims/forever's EV-0093,
2026-11-06). A pair the original game hadn't (Forever has 56, the original 40: a dwarf shaman, a human hunter, every
Skyborne) is its class's row plus its race's offset. Checked against Forever's sheets: a level 1 human warrior's
(forever-bugs#414, read the day before the fix: its seven other races' sheets are the bug's) matches; a dwarf shaman's
doesn't (level 26: agility and intellect one lower; level 60, wowsims/forever's EV-0181: strength 3 higher, agility and
intellect 3 lower), so the cards say where the game's figure isn't the table's. No other class's sheet at level 1 has
been read.

Run with: python -I hud/tools/make_basestats.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.paths import REFERENCE  # noqa: E402

TARGET = ROOT / "hud/addon/KaLiHUD/Data/BaseStats.lua"
SOURCE = REFERENCE / "basestats" / "player_levelstats.sql"
HEALTH_SOURCE = REFERENCE / "basestats" / "player_classlevelstats.sql"
# The races by their IDs, UnitRace's third (the two Skyborne share one token, UnitRace's second), and the classes by the
# token UnitClass gives.
RACES = {1: "Human", 2: "Orc", 3: "Dwarf", 4: "Night Elf", 5: "Undead", 6: "Tauren", 7: "Gnome", 8: "Troll",
         95: "High Order Skyborne", 96: "Windshaper Skyborne"}
CLASSES = {1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK",
           11: "DRUID"}
# Each race's offset on the human's (strength, agility, stamina, intellect, spirit): the original game's, which Forever
# takes again (forever-bugs#414); the Skyborne's, Forever's own, read from its level 1 sheets (EV-0093).
OFFSETS = {1: (0, 0, 0, 0, 0), 2: (3, -3, 2, -3, 3), 3: (2, -4, 3, -1, -1), 4: (-3, 5, -1, 0, 0),
           5: (-1, -2, 1, -2, 5), 6: (5, -5, 2, -5, 2), 7: (-5, 3, -1, 3, 0), 8: (1, 2, 1, -4, 1),
           95: (-3, 4, -1, 4, -3), 96: (-4, 3, 0, -1, 3)}
# the offsets read from Forever's sheets, not the original game's
READ = (95, 96)
LEVELS = 60


def curves():
    """Each class's row as a human's, by level: what most of the races that have the class agree on once their offset
    is taken off (the table holds a few race quirks: its human warrior's spirit 21 at level 1, Forever's sheet 20)."""
    rows = {}
    pattern = r"\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)"
    for m in re.finditer(pattern, SOURCE.read_text(encoding="utf-8")):
        race, cls, level, *stats = map(int, m.groups())
        rows.setdefault(CLASSES[cls], {}).setdefault(level, []).append(
            [v - o for v, o in zip(stats, OFFSETS[race])])
    out = {}
    for cls, levels in rows.items():
        assert sorted(levels) == list(range(1, LEVELS + 1)), cls
        out[cls] = []
        for level in range(1, LEVELS + 1):
            seen = levels[level]
            # each attribute's most common value; a tie goes to the lower
            out[cls].append([min(set(col), key=lambda v: (-col.count(v), v)) for col in zip(*seen)])
    return out


def health():
    """Each class's base health at levels 1 to 60, the original game's own (MaNGOS Zero's `player_classlevelstats`,
    kept beside the attributes' as basestats/player_classlevelstats.sql): a class's alone, no race's (Ikar 2026-11-24:
    "why mana and health are not broken by race, class and profession like the rest"). Checked against Forever: a
    level 26 dwarf shaman's 767 with 510 of its stamina leaves 257, the table's (Ikar's card of 2026-11-23). Forever's
    data has the mana's own table (Data/Effects.lua's BASE_MANA), not the health's."""
    rows = {}
    pattern = r"\((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)"
    for m in re.finditer(pattern, HEALTH_SOURCE.read_text(encoding="utf-8")):
        cls, level, hp, _ = map(int, m.groups())
        rows.setdefault(CLASSES[cls], {})[level] = hp
    for cls, levels in rows.items():
        assert sorted(levels) == list(range(1, LEVELS + 1)), cls
    return {cls: [levels[n] for n in range(1, LEVELS + 1)] for cls, levels in rows.items()}


def build():
    """The file's text, and how many classes it holds."""
    classes = curves()
    out = [
        "-- Generated by hud/tools/make_basestats.py from the original game's table of base attributes (MaNGOS Zero's",
        "-- player_levelstats): each race's offset on the human's by its ID (UnitRace's third), the original game's",
        "-- that Forever takes again, the Skyborne's read from Forever's level 1 sheets (`read`); each class's row as a",
        "-- human's, its strength, agility, stamina, intellect and spirit at levels 1 to 60, a level's five after a « ; ».",
        "-- A race and class's base at a level is the class's row plus the race's offset. Don't edit.",
        "local _, ns = ...",
        "",
        "ns.BASE_STATS = {",
        "    offsets = {",
    ]
    for race, offset in OFFSETS.items():
        out.append(f"        [{race}] = {{ {', '.join(map(str, offset))} }}, -- {RACES[race]}")
    out += ["    },", "    read = { " + ", ".join(f"[{race}] = true" for race in READ) + " },", "    classes = {"]
    for cls in sorted(classes):
        text = ";".join(",".join(map(str, five)) for five in classes[cls])
        out.append(f'        {cls} = "{text}",')
    out += ["    },", "    -- each class's base health at levels 1 to 60, the original game's (player_classlevelstats)",
            "    health = {"]
    for cls, levels in sorted(health().items()):
        out.append(f'        {cls} = "{",".join(map(str, levels))}",')
    out += ["    },", "}", ""]
    return "\n".join(out), len(classes)


if __name__ == "__main__":
    text, pairs = build()
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print(f"{TARGET.relative_to(ROOT)}: {pairs} classes, levels 1 to {LEVELS}")
