"""Measure which quest traits the quest log's own header can reveal, from static data.

Answers, and prints a report. Writes nothing.
  1. How many class quests sit under their class's header, and how many sit under a zone?
  2. How many dungeon and raid quests sit under the instance's header, and how many under a zone?
  3. What do the French class headers look like against a French character's class name?
  4. How many quests does Questie's table correct because GetQuestTagInfo answers wrongly?

Run with: python -I quest/tools/research/quest_traits_test.py
"""
import contextlib
import csv
import io
import re
import runpy
from collections import Counter
from pathlib import Path

with contextlib.redirect_stdout(io.StringIO()):
    poc = runpy.run_path(str(Path(__file__).resolve().parent / "subzone_poc.py"))

QDB, is_vanilla, rows, ROOT, REFERENCE = poc["QDB_QUESTS"], poc["is_vanilla"], poc["rows"], poc["ROOT"], poc["REFERENCE"]

# Field positions in QuestieDB's quest rows, counted from zero.
REQUIRED_CLASSES, ZONE_OR_SORT, QUEST_FLAGS, SPECIAL_FLAGS = 6, 16, 22, 23

CLASS_SORTS = {61: "Warlock", 81: "Warrior", 82: "Shaman", 141: "Paladin", 161: "Mage", 162: "Rogue", 261: "Hunter", 262: "Priest", 263: "Druid"}
TRADE_SORTS = {24, 101, 121, 181, 182, 201, 264, 304, 324}
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024

instance_type = {int(m["ID"]): int(m["InstanceType"]) for m in rows("Map")}
# A dungeon's header can use an outdoor area ID (Uldaman, Razorfen Kraul), so match on the instance's
# name too. Instanced copies of ordinary zones are excluded: an outdoor zone with the same name wins.
instance_names = {m["MapName_lang"]: int(m["InstanceType"]) for m in rows("Map") if int(m["InstanceType"]) in (1, 2)}
outdoor_zones = {u["Name_lang"] for u in rows("UiMap")}
area_rows = rows("AreaTable")
area_label = {int(a["ID"]): a["AreaName_lang"] for a in area_rows}
area_instance = {}
for a in area_rows:
    name = a["AreaName_lang"]
    kind = instance_type.get(int(a["ContinentID"]), 0)
    if name in instance_names and name not in outdoor_zones:
        kind = instance_names[name]
    elif name in outdoor_zones:
        kind = 0
    area_instance[int(a["ID"])] = kind


def field(q, i):
    return q[i] if isinstance(q, list) and len(q) > i and isinstance(q[i], int) else 0


def is_class_quest(q):
    mask = field(q, REQUIRED_CLASSES)
    return mask != 0 and (mask & ALL_CLASSES) != ALL_CLASSES


def report(name, quests):
    print(f"\n=== {name}: {len(quests)} quests ===")
    header = Counter()
    for q in quests.values():
        z = field(q, ZONE_OR_SORT)
        if z < 0:
            sort = -z
            header["class header" if sort in CLASS_SORTS else "trade header" if sort in TRADE_SORTS else "other category header"] += 1
        elif z > 0:
            kind = area_instance.get(z)
            header["dungeon header" if kind == 1 else "raid header" if kind == 2 else "area not in AreaTable" if kind is None else "zone header"] += 1
        else:
            header["no header value"] += 1
    print("Header the log would use:", dict(header))

    class_quests = {i: q for i, q in quests.items() if is_class_quest(q)}
    under_class = sum(1 for q in class_quests.values() if -field(q, ZONE_OR_SORT) in CLASS_SORTS)
    print(f"Class-restricted quests: {len(class_quests)}. Under a class header: {under_class}. Elsewhere: {len(class_quests) - under_class}")
    other = sum(1 for q in quests.values() if -field(q, ZONE_OR_SORT) in CLASS_SORTS and not is_class_quest(q))
    print(f"Under a class header with no class restriction: {other}")

    flags = Counter()
    for q in quests.values():
        f, s = field(q, QUEST_FLAGS), field(q, SPECIAL_FLAGS)
        flags["daily"] += bool(f & 4096)
        flags["weekly"] += bool(f & 32768)
        flags["monthly"] += bool(f & 65536)
        flags["repeatable"] += bool(s & 1)
        flags["sharable flag"] += bool(f & 8)
    print("Flags:", dict(flags))
    return class_quests


vanilla = {i: q for i, q in QDB.items() if isinstance(i, int) and is_vanilla(i)}
new = {i: q for i, q in QDB.items() if isinstance(i, int) and not is_vanilla(i)}
report("Vanilla quests", vanilla)
report("New Forever quests", new)

print("\n=== Questie's tag corrections, as they apply to Era content ===")
RANK = {"Era": 0, "Tbc": 1, "Wotlk": 2, "Cata": 3, "MoP": 4, "Mop": 4, "Wod": 5, "Legion": 6}
ENTRY = re.compile(r"^\s*\[(\d+)\]\s*=\s*(.*?)\{(\d+),\s*l10n\(\"([^\"]+)\"\)\}")
COND = re.compile(r"Expansions\.Current\s*(==|<=|>=|<|>|~=)\s*Expansions\.(\w+)")
OPS = {"==": lambda a, b: a == b, "<=": lambda a, b: a <= b, ">=": lambda a, b: a >= b, "<": lambda a, b: a < b, ">": lambda a, b: a > b, "~=": lambda a, b: a != b}
tags = {}
path = REFERENCE / "Questie/Database/Corrections/questTagInfoCorrections.lua"
unknown = 0
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    m = ENTRY.match(line)
    if not m:
        continue
    qid, cond, tag, name = int(m[1]), m[2], int(m[3]), m[4]
    tests = COND.findall(cond)
    if tests and all(e in RANK for _, e in tests):
        if not all(OPS[o](0, RANK[e]) for o, e in tests):
            continue
    elif tests:
        unknown += 1
        continue
    tags.setdefault(qid, (tag, name))
print("Corrected quests that apply to Era:", len(tags), " Skipped, unknown condition:", unknown)
print("By tag:", dict(Counter(n for _, n in tags.values())))

print("\n=== Dungeon and raid quests: tag table against header ===")
for wanted, label in ((81, "Dungeon"), (62, "Raid")):
    ids = [i for i, (t, _) in tags.items() if t == wanted and i in QDB]
    where = Counter()
    for i in ids:
        z = field(QDB[i], ZONE_OR_SORT)
        kind = area_instance.get(z) if z > 0 else None
        where["instance header" if kind in (1, 2) else "category header" if z < 0 else "zone header" if z > 0 else "none"] += 1
    print(f"{label}-tagged in the correction table: {len(ids)} ->", dict(where))
under_instance = [i for i, q in QDB.items() if isinstance(i, int) and area_instance.get(field(q, ZONE_OR_SORT)) in (1, 2)]
print("Quests under an instance header:", len(under_instance), " Of which corrected to Dungeon or Raid:", sum(1 for i in under_instance if tags.get(i, (0,))[0] in (81, 62)))
used = Counter(area_label.get(field(QDB[i], ZONE_OR_SORT)) for i in under_instance)
print("Distinct instance headers those quests use:", len(used))
print("Instance headers, with quest counts:", dict(used.most_common()))
elsewhere = [i for i, (t, _) in tags.items() if t in (81, 62) and i in QDB and area_instance.get(field(QDB[i], ZONE_OR_SORT)) not in (1, 2)]
print("Tagged, but not under an instance header:", len(elsewhere), " Union with instance headers:", len(set(under_instance) | set(elsewhere)))
print("Their headers:", dict(Counter(area_label.get(field(QDB[i], ZONE_OR_SORT), "category") for i in elsewhere).most_common(25)))
print("Corrections for quests in this data, by tag:", dict(Counter(n for i, (_, n) in tags.items() if i in QDB)))

print("\n=== French class names: quest category against a character's class name ===")
db2 = REFERENCE / "db2/1.60.1.70790"
with open(db2 / "QuestSort.frFR.csv", encoding="utf-8", newline="") as f:
    sort_fr = {int(r["ID"]): r["SortName_lang"] for r in csv.DictReader(f)}
with open(db2 / "ChrClasses.frFR.csv", encoding="utf-8", newline="") as f:
    classes = {r["Filename"]: r for r in csv.DictReader(f)}
for sort, english in CLASS_SORTS.items():
    c = classes[english.upper()]
    fr = sort_fr[sort]
    print(f"{english:8} header={fr!r:14} male={c['Name_male_lang']!r:14} female={c['Name_female_lang']!r:16} matches male={fr == c['Name_male_lang']} matches female={fr == c['Name_female_lang']}")
