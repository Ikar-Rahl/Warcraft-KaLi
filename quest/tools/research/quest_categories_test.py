"""Measure the tracker's broad categories and row markers against static quest data.

Answers, and prints a report. Writes nothing.
  1. Where does each vanilla quest land, going by the quest log's header?
  2. Which quests does the header hide something about (class, profession, dungeon)?
  3. Which markers would still show, once a row's position already says the rest?

Run with: python -I quest/tools/research/quest_categories_test.py
"""
import contextlib
import csv
import io
import re
import runpy
import sys
from collections import Counter
from pathlib import Path

with contextlib.redirect_stdout(io.StringIO()):
    poc = runpy.run_path(str(Path(__file__).resolve().parent / "subzone_poc.py"))
QDB, is_vanilla, rows, ROOT, REFERENCE = poc["QDB_QUESTS"], poc["is_vanilla"], poc["rows"], poc["ROOT"], poc["REFERENCE"]
sys.stdout.reconfigure(encoding="utf-8")

# Field positions in QuestieDB's quest rows, counted from zero.
NAME, REQUIRED_CLASSES, ZONE_OR_SORT, REQUIRED_SKILL, QUEST_FLAGS, SPECIAL_FLAGS = 0, 6, 16, 17, 22, 23
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024

CLASS_SORTS = {61, 81, 82, 141, 161, 162, 261, 262, 263}
TRADE_SORTS = {24, 101, 121, 181, 182, 201, 264, 304, 324}
EVENT_SORTS = {22, 364, 365, 366, 368, 369, 641, 644}
BATTLEGROUNDS = {"Alterac Valley", "Warsong Gulch", "Arathi Basin"}

CATEGORY_NAMES = {
    "world": "Monde",
    "instances": "Donjons et raids",
    "classprof": "Classe et métiers",
    "events": "Évènements",
    "pvp": "Champs de bataille",
    "misc": "Divers",
}

db2 = REFERENCE / "db2/1.60.1.70790"
with open(db2 / "QuestSort.frFR.csv", encoding="utf-8", newline="") as f:
    sort_fr = {int(r["ID"]): r["SortName_lang"] for r in csv.DictReader(f)}
with open(db2 / "AreaTable.frFR.csv", encoding="utf-8", newline="") as f:
    area_fr = {int(r["ID"]): r["AreaName_lang"] for r in csv.DictReader(f)}

# As in quest_traits_test.py: match instances by name, and an outdoor zone with the same name wins.
map_rows = rows("Map")
instance_type = {int(m["ID"]): int(m["InstanceType"]) for m in map_rows}
instance_names = {m["MapName_lang"]: int(m["InstanceType"]) for m in map_rows if int(m["InstanceType"]) in (1, 2)}
outdoor_zones = {u["Name_lang"] for u in rows("UiMap")}
area_rows = rows("AreaTable")
area_en = {int(a["ID"]): a["AreaName_lang"] for a in area_rows}
area_kind = {}
for a in area_rows:
    name = a["AreaName_lang"]
    kind = instance_type.get(int(a["ContinentID"]), 0)
    if name in instance_names and name not in outdoor_zones:
        kind = instance_names[name]
    elif name in outdoor_zones:
        kind = 0
    area_kind[int(a["ID"])] = kind
battleground_areas = {i for i, n in area_en.items() if n in BATTLEGROUNDS}


def num(q, i):
    v = q[i] if isinstance(q, list) and len(q) > i else None
    return v if isinstance(v, int) else 0


def header_name(q):
    z = num(q, ZONE_OR_SORT)
    if z < 0:
        return sort_fr.get(-z, f"sort {-z}")
    return area_fr.get(z, area_en.get(z, "none"))


def category(q):
    z = num(q, ZONE_OR_SORT)
    if z < 0:
        s = -z
        if s in CLASS_SORTS or s in TRADE_SORTS:
            return "classprof"
        return "events" if s in EVENT_SORTS else "misc"
    if z == 0:
        return "misc"
    if z in battleground_areas:
        return "pvp"
    return "instances" if area_kind.get(z) in (1, 2) else "world"


# Tags, from Questie's correction table, as they apply to Era content.
RANK = {"Era": 0, "Tbc": 1, "Wotlk": 2, "Cata": 3, "MoP": 4, "Mop": 4, "Wod": 5, "Legion": 6}
ENTRY = re.compile(r"^\s*\[(\d+)\]\s*=\s*(.*?)\{(\d+),\s*l10n\(\"([^\"]+)\"\)\}")
COND = re.compile(r"Expansions\.Current\s*(==|<=|>=|<|>|~=)\s*Expansions\.(\w+)")
OPS = {"==": lambda a, b: a == b, "<=": lambda a, b: a <= b, ">=": lambda a, b: a >= b, "<": lambda a, b: a < b, ">": lambda a, b: a > b, "~=": lambda a, b: a != b}
path = REFERENCE / "Questie/Database/Corrections/questTagInfoCorrections.lua"
tags = {}
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    m = ENTRY.match(line)
    if not m:
        continue
    qid, cond, name = int(m[1]), m[2], m[4]
    tests = COND.findall(cond)
    if tests and not (all(e in RANK for _, e in tests) and all(OPS[o](0, RANK[e]) for o, e in tests)):
        continue
    tags.setdefault(qid, name)

vanilla = {i: q for i, q in QDB.items() if isinstance(i, int) and is_vanilla(i)}
cat = {i: category(q) for i, q in vanilla.items()}
total = len(vanilla)

print(f"=== Categories, by log header, for {total} vanilla quests ===")
for key, n in Counter(cat.values()).most_common():
    print(f"{CATEGORY_NAMES[key]:20} {n:5}  {100 * n / total:.1f}%")
for key in ("events", "pvp", "misc", "classprof"):
    print(f"\n{CATEGORY_NAMES[key]}:", Counter(header_name(vanilla[i]) for i, c in cat.items() if c == key).most_common())
print("\nDistinct headers:", {CATEGORY_NAMES[k]: len({header_name(vanilla[i]) for i, c in cat.items() if c == k}) for k in CATEGORY_NAMES})

print("\n=== What a header doesn't reveal ===")
class_quests = [i for i, q in vanilla.items() if num(q, REQUIRED_CLASSES) and (num(q, REQUIRED_CLASSES) & ALL_CLASSES) != ALL_CLASSES]
print("Class-restricted:", len(class_quests), dict(Counter(CATEGORY_NAMES[cat[i]] for i in class_quests)))
skill_quests = [i for i, q in vanilla.items() if isinstance(q[REQUIRED_SKILL] if len(q) > REQUIRED_SKILL else None, list)]
print("Needs a profession skill:", len(skill_quests), dict(Counter(CATEGORY_NAMES[cat[i]] for i in skill_quests)))
tagged = {i: t for i, t in tags.items() if i in vanilla}
outside = [i for i, t in tagged.items() if t in ("Dungeon", "Raid") and cat[i] != "instances"]
print("Tagged Dungeon or Raid, outside the instance category:", len(outside), dict(Counter(CATEGORY_NAMES[cat[i]] for i in outside)))
print("Tagged PvP, outside battlegrounds:", sum(1 for i, t in tagged.items() if t == "PvP" and cat[i] != "pvp"))
print("Inside the instance category, not tagged:", sum(1 for i, c in cat.items() if c == "instances" and tagged.get(i) not in ("Dungeon", "Raid")))

print("\n=== Markers left once position says the rest ===")
per_row, which = Counter(), Counter()
for i, q in vanilla.items():
    icons = []
    tag = tagged.get(i)
    if tag in ("Dungeon", "Raid") and cat[i] != "instances":
        icons.append(tag)
    if tag == "PvP" and cat[i] != "pvp":
        icons.append(tag)
    if tag == "World Event" and cat[i] != "events":
        icons.append(tag)
    if num(q, SPECIAL_FLAGS) & 1:
        icons.append("Repeatable")
    if num(q, QUEST_FLAGS) & 4096:
        icons.append("Daily")
    if num(q, QUEST_FLAGS) & 32768:
        icons.append("Weekly")
    per_row[len(icons)] += 1
    which.update(icons)
print("Icons per row:", {k: f"{v} ({100 * v / total:.1f}%)" for k, v in sorted(per_row.items())})
print("Which:", which.most_common())
print("Repeatable, by category:", dict(Counter(CATEGORY_NAMES[cat[i]] for i, q in vanilla.items() if num(q, SPECIAL_FLAGS) & 1)))
print("Elite, as + in the level:", sum(1 for t in tagged.values() if t == "Elite"))
print("Not measurable here: group size, timed, usable item, party members. QuestieDB doesn't hold them, or they change live.")
