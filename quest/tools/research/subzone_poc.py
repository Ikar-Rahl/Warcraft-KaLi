"""Proof of concept: assign quests to sub-zones from static data, then score against FieldJournal's labels.

Reads the installed addons read-only. Prints a report and writes nothing.
    python -I quest/tools/research/subzone_poc.py
"""
import csv
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from kali.paths import GAME, REFERENCE, ROOT  # noqa: E402
DB2 = REFERENCE / "db2/1.60.1.70790"
ADDONS = GAME / "Interface/AddOns"
LAYER_W, LAYER_H = 1002, 668  # UiMapArtStyleLayer row 1, the style zone maps use

TOKEN = re.compile(r"""--[^\n]*|\s+|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_.]*|[{}=,;\[\]]""", re.S)


def tokenize(text):
    tokens, pos = [], 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            pos += 1
            continue
        pos = m.end()
        t = m.group(0)
        if not t.isspace() and not t.startswith("--"):
            tokens.append(t)
    return tokens


def parse_value(tokens, i):
    t = tokens[i]
    if t == "{":
        return parse_table(tokens, i + 1)
    if t[0] in "\"'":
        return t[1:-1], i + 1
    if t in ("true", "false"):
        return t == "true", i + 1
    if t == "nil":
        return None, i + 1
    try:
        return (float(t) if "." in t else int(t)), i + 1
    except ValueError:
        return t, i + 1


def parse_table(tokens, i):
    arr, obj = [], {}
    while tokens[i] != "}":
        t = tokens[i]
        if t in ",;":
            i += 1
        elif t == "[":
            key, i = parse_value(tokens, i + 1)
            i += 2  # "]" and "="
            obj[key], i = parse_value(tokens, i)
        elif tokens[i + 1] == "=" and t != "{":
            obj[t], i = parse_value(tokens, i + 2)
        else:
            value, i = parse_value(tokens, i)
            arr.append(value)
    return (obj if obj else arr), i + 1


def load_table(path, marker):
    text = path.read_text(encoding="utf-8", errors="replace")
    start = text.index("{", text.index(marker))
    table, _ = parse_table(tokenize(text[start:]), 1)
    return table


def rows(name):
    with open(DB2 / f"{name}.csv", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def norm(name):
    name = (name or "").lower().replace("’", "'")
    name = re.sub(r"^the ", "", name)
    return re.sub(r"[^a-z0-9 ]", "", name).strip()


# ----------------------------------------------------------------------------------------------
# The game's tables
# ----------------------------------------------------------------------------------------------
areas = {int(a["ID"]): a for a in rows("AreaTable")}
area_name = {k: a["AreaName_lang"] for k, a in areas.items()}
assign = rows("UiMapAssignment")
art_to_maps = defaultdict(set)
for r in rows("UiMapXMapArt"):
    art_to_maps[int(r["UiMapArtID"])].add(int(r["UiMapID"]))

overlays = defaultdict(list)
for o in rows("WorldMapOverlay"):
    ids = [int(num(o[f"AreaID_{i}"])) for i in range(4)]
    ids = [i for i in ids if i in area_name]
    if not ids:
        continue
    rect = (num(o["HitRectLeft"]), num(o["HitRectRight"]), num(o["HitRectTop"]), num(o["HitRectBottom"]))
    if rect[1] <= rect[0] or rect[3] <= rect[2]:
        rect = (num(o["OffsetX"]), num(o["OffsetX"]) + num(o["TextureWidth"]),
                num(o["OffsetY"]), num(o["OffsetY"]) + num(o["TextureHeight"]))
    for m in art_to_maps.get(int(o["UiMapArtID"]), ()):
        overlays[m].append((rect, ids))

map_region = {}
for r in assign:
    if int(num(r["AreaID"])) and int(r["UiMapID"]) not in map_region:
        map_region[int(r["UiMapID"])] = (int(r["MapID"]), num(r["Region_0"]), num(r["Region_1"]), num(r["Region_3"]), num(r["Region_4"]))

pois = defaultdict(list)
for p in rows("AreaPOI"):
    cont, x, y = int(num(p["ContinentID"])), num(p["Pos_0"]), num(p["Pos_1"])
    for m, (mid, x0, y0, x1, y1) in map_region.items():
        if mid == cont and x0 <= x <= x1 and y0 <= y <= y1 and x1 > x0 and y1 > y0:
            pois[m].append(((y1 - y) / (y1 - y0), (x1 - x) / (x1 - x0), p["Name_lang"]))


def overlay_area(uimap, x, y):
    """The named area whose hit rectangle holds this point; the smallest rectangle wins."""
    px, py = x * LAYER_W, y * LAYER_H
    best, best_size = None, math.inf
    for (l, r, t, b), ids in overlays.get(uimap, ()):
        if l <= px <= r and t <= py <= b:
            size = (r - l) * (b - t)
            if size < best_size:
                best, best_size = ids[0], size
    return area_name.get(best) if best else None


def nearest_overlay(uimap, x, y):
    px, py = x * LAYER_W, y * LAYER_H
    best, best_d = None, math.inf
    for (l, r, t, b), ids in overlays.get(uimap, ()):
        d = math.hypot(px - (l + r) / 2, py - (t + b) / 2)
        if d < best_d:
            best, best_d = ids[0], d
    return area_name.get(best) if best else None


def nearest_poi(uimap, x, y, limit=0.12):
    best, best_d = None, limit
    for px, py, name in pois.get(uimap, ()):
        d = math.hypot(px - x, py - y)
        if d < best_d:
            best, best_d = name, d
    return best


# ----------------------------------------------------------------------------------------------
# Quest data: Zmap's generated tables (QuestieDB plus warcraftdb, GPL-3.0) and FieldJournal's labels
# ----------------------------------------------------------------------------------------------
QUESTS = load_table(ADDONS / "Zmap/Data/Quests.lua", "ns.QUESTS")
NPCS = load_table(ADDONS / "Zmap/Data/Npcs.lua", "ns.NPCS")
OBJECTS = load_table(ADDONS / "Zmap/Data/Objects.lua", "ns.OBJECTS")


def spawns(row, start):
    """[(uiMap, x, y)] from a row's trailing uiMapID, {x1, y1, ...} pairs, as 0..1."""
    out = []
    i = start
    while i + 1 < len(row):
        m, pts = row[i], row[i + 1]
        if isinstance(m, int) and isinstance(pts, list):
            for j in range(0, len(pts) - 1, 2):
                out.append((m, pts[j] / 1000, pts[j + 1] / 1000))
        i += 2
    return out


def npc_points(ids):
    out = []
    for n in ids or []:
        if n in NPCS and isinstance(NPCS[n], list):
            out += spawns(NPCS[n], 6)
    return out


def object_points(ids):
    out = []
    for n in ids or []:
        if n in OBJECTS and isinstance(OBJECTS[n], list):
            out += spawns(OBJECTS[n], 4)
    return out


def listat(q, i):
    v = q[i] if i < len(q) else []
    return v if isinstance(v, list) else []


def giver_point(q):
    pts = npc_points(listat(q, 5)) + object_points(listat(q, 6))
    return pts[0] if pts else None


def taker_point(q):
    pts = npc_points(listat(q, 7)) + object_points(listat(q, 8))
    return pts[0] if pts else None


def objective_centre(q):
    """The median of objective spawns on the map holding most of them; 'places to reach' count too."""
    pts = npc_points(listat(q, 9)) + object_points(listat(q, 10))
    places = listat(q, 17)
    i = 0
    while i + 1 < len(places):
        if isinstance(places[i], int) and isinstance(places[i + 1], list):
            p = places[i + 1]
            pts += [(places[i], p[j] / 1000, p[j + 1] / 1000) for j in range(0, len(p) - 1, 2)]
        i += 2
    if not pts:
        return None
    m = Counter(p[0] for p in pts).most_common(1)[0][0]
    on = [p for p in pts if p[0] == m]
    return m, statistics.median(p[1] for p in on), statistics.median(p[2] for p in on)


text = (ADDONS / "FieldJournal/Lore/QuestDB.lua").read_text(encoding="utf-8", errors="replace")
labels = {}
starts = list(re.finditer(r"FieldJournal_QuestDB\[(\d+)\]\s*=\s*\{", text))
for i, m in enumerate(starts):
    body = text[m.end():starts[i + 1].start() if i + 1 < len(starts) else len(text)]
    zone = re.search(r'zone = "([^"]+)"', body)
    sub = re.search(r'subregion = "([^"]+)"', body)
    if zone and sub:
        labels[int(m.group(1))] = (zone.group(1), sub.group(1))

qt = (ADDONS / "Spoken_Quests/Data/QuestText.lua").read_text(encoding="utf-8", errors="replace")
accept_text = {}
for m in re.finditer(r'\[(\d+)\] = \{\s*accept = "((?:[^"\\]|\\.)*)"', qt):
    accept_text[int(m.group(1))] = m.group(2)

vt = (ADDONS / "ForeverQuestTint/VanillaQuests.lua").read_text(encoding="utf-8", errors="replace")
vanilla_ranges = [(int(a), int(b)) for a, b in re.findall(r"\{(\d+),(\d+)\}", vt)]


def is_vanilla(q):
    return any(a <= q <= b for a, b in vanilla_ranges)


def children_names(zone_name):
    ids = [k for k, a in areas.items() if a["AreaName_lang"] == zone_name]
    out = set()
    for k, a in areas.items():
        if int(num(a["ParentAreaID"])) in ids:
            out.add(a["AreaName_lang"])
    return out


def text_area(qid, zone):
    t = accept_text.get(qid)
    if not t:
        return None
    t = t.lower().replace("’", "'")
    hits = []
    for name in children_names(zone):
        key = re.sub(r"^the ", "", name.lower())
        pos = t.find(key)
        if pos >= 0 and "UNUSED" not in name:
            hits.append((pos, name))
    return min(hits)[1] if hits else None


def place_of(point):
    return (overlay_area(*point) or nearest_poi(*point) or nearest_overlay(*point)) if point else None


# QuestieDB's raw tables: objective text in English and French, and how objectives resolve to places.
QDB = REFERENCE / "QuestieDB"


def lua_long_string_table(path, marker):
    raw = path.read_text(encoding="utf-8", errors="replace")
    start = raw.index("{", raw.index(marker))
    table, _ = parse_table(tokenize(raw[start:]), 1)
    return table


QDB_QUESTS = lua_long_string_table(QDB / "data/Forever/foreverQuestDB.lua", "QuestieDB.questData")
QDB_ITEMS = lua_long_string_table(QDB / "data/Forever/foreverItemDB.lua", "QuestieDB.itemData")


def objective_lines(qid):
    q = QDB_QUESTS.get(qid)
    if isinstance(q, list) and len(q) > 7 and isinstance(q[7], list):
        return [t for t in q[7] if isinstance(t, str)]
    return []


def objective_text_area(qid, zone):
    t = " ".join(objective_lines(qid)).lower().replace("’", "'")
    if not t:
        return None
    hits = []
    for name in children_names(zone):
        key = re.sub(r"^the ", "", name.lower())
        pos = t.find(key)
        if pos >= 0 and "UNUSED" not in name:
            hits.append((pos, name))
    return min(hits)[1] if hits else None


# ----------------------------------------------------------------------------------------------
# Report
# ----------------------------------------------------------------------------------------------
print("=== QuestieDB raw (Era baseline, before Forever corrections) ===")
cnt = Counter()
for qid, q in QDB_QUESTS.items():
    if not isinstance(q, list):
        continue
    cnt["quests"] += 1
    obj = q[9] if len(q) > 9 else None
    trig = q[8] if len(q) > 8 else None
    ext = q[28] if len(q) > 28 else None
    if obj or trig or ext:
        cnt["has an objective reference"] += 1
    if isinstance(obj, list) and len(obj) > 2 and obj[2]:
        cnt["item objectives"] += 1
        resolved = False
        for entry in obj[2]:
            item = QDB_ITEMS.get(entry[0]) if isinstance(entry, list) else None
            if isinstance(item, list) and ((len(item) > 1 and item[1]) or (len(item) > 2 and item[2]) or (len(item) > 13 and item[13])):
                resolved = True
        cnt["item objectives with a drop or vendor source"] += resolved
    if len(q) > 16 and isinstance(q[16], int):
        cnt["zoneOrSort is a zone" if q[16] > 0 else ("zoneOrSort is a sort" if q[16] < 0 else "zoneOrSort empty")] += 1
    if objective_lines(qid):
        cnt["has objective text"] += 1
print(dict(cnt))

print("\n=== Do FieldJournal's labels name real areas? ===")
area_norm = {norm(n) for n in area_name.values()}
poi_norm = {norm(p[2]) for v in pois.values() for p in v}
subs = {s for _, s in labels.values()}
print("distinct labels:", len(subs), " are AreaTable names:", sum(1 for s in subs if norm(s) in area_norm), " are town POIs:", sum(1 for s in subs if norm(s) in poi_norm))
print("labels by zone family:", Counter("new" if not is_vanilla(q) else "vanilla" for q in labels))
print("labels on quests Zmap lacks:", sum(1 for q in labels if q not in QUESTS))

print("\n=== French text test: objective text naming a child area of the quest's zone ===")
fr_rows = {}
fr_path = QDB / "l10n/Forever/lookupQuests/frFR.lua"
if fr_path.exists():
    raw = fr_path.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r'\[(\d+)\]\s*=\s*\{\s*"((?:[^"\\]|\\.)*)"\s*,\s*(.*?)\},?\s*\n', raw):
        fr_rows[int(m.group(1))] = m.group(3)
fr_area = {}
fr_csv = DB2 / "AreaTable.frFR.csv"
if fr_csv.exists():
    with open(fr_csv, encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            fr_area[int(r["ID"])] = r["AreaName_lang"]
print("frFR quest rows parsed:", len(fr_rows), " frFR area names:", len(fr_area))
hit_en = hit_fr = both_same = tot = 0
for qid, (zone, sub) in labels.items():
    if qid not in fr_rows or qid not in QDB_QUESTS:
        continue
    tot += 1
    if objective_text_area(qid, zone):
        hit_en += 1
    zone_ids = [k for k, a in areas.items() if a["AreaName_lang"] == zone]
    t = fr_rows[qid].lower().replace("’", "'")
    found = None
    for k, a in areas.items():
        if int(num(a["ParentAreaID"])) in zone_ids and k in fr_area:
            key = re.sub(r"^(le |la |les |l')", "", fr_area[k].lower().replace("’", "'"))
            if len(key) > 3 and key in t:
                found = a["AreaName_lang"]
                break
    if found:
        hit_fr += 1
        both_same += norm(found) == norm(sub)
print(f"labelled quests tested: {tot}, English hit: {hit_en}, French hit: {hit_fr}, French hit naming the label: {both_same}")

print("\n=== Coverage ===")
qv2 = [int(r["ID"]) for r in rows("QuestV2")]
print("QuestV2 rows in the client:", len(qv2), " not vanilla:", sum(1 for q in qv2 if not is_vanilla(q)))
print("Zmap quests:", len(QUESTS), " not vanilla:", sum(1 for q in QUESTS if not is_vanilla(q)))
inv2 = set(qv2)
print("Client non-vanilla IDs that Zmap has:", sum(1 for q in inv2 if not is_vanilla(q) and q in QUESTS))
print("Zmap quests absent from QuestV2:", sum(1 for q in QUESTS if q not in inv2))
has = Counter()
for qid, q in QUESTS.items():
    v = "vanilla" if is_vanilla(qid) else "new"
    has[v, "total"] += 1
    if giver_point(q):
        has[v, "giver location"] += 1
    if taker_point(q):
        has[v, "turn-in location"] += 1
    if objective_centre(q):
        has[v, "objective location"] += 1
    if giver_point(q) or objective_centre(q):
        has[v, "any location"] += 1
for v in ("vanilla", "new"):
    tot = has[v, "total"]
    print(v, {k: f"{has[v, k]} ({100 * has[v, k] / tot:.0f}%)" for k in ("total", "giver location", "turn-in location", "objective location", "any location")})

print("\nFieldJournal labels:", len(labels), " distinct sub-regions:", len({s for _, s in labels.values()}),
      " in Zmap:", sum(1 for q in labels if q in QUESTS), " not vanilla:", sum(1 for q in labels if not is_vanilla(q)))

methods = {
    "giver in overlay rect": lambda q, z, qid: (lambda p: overlay_area(*p) if p else None)(giver_point(q)),
    "giver nearest town POI": lambda q, z, qid: (lambda p: nearest_poi(*p) if p else None)(giver_point(q)),
    "giver overlay, else town": lambda q, z, qid: (lambda p: (overlay_area(*p) or nearest_poi(*p)) if p else None)(giver_point(q)),
    "giver overlay, town, nearest overlay": lambda q, z, qid: (lambda p: (overlay_area(*p) or nearest_poi(*p) or nearest_overlay(*p)) if p else None)(giver_point(q)),
    "giver town, else overlay": lambda q, z, qid: (lambda p: (nearest_poi(*p) or overlay_area(*p) or nearest_overlay(*p)) if p else None)(giver_point(q)),
    "objectives in overlay rect": lambda q, z, qid: (lambda p: overlay_area(*p) if p else None)(objective_centre(q)),
    "turn-in in overlay rect": lambda q, z, qid: (lambda p: overlay_area(*p) if p else None)(taker_point(q)),
    "place named in quest text": lambda q, z, qid: text_area(qid, z),
    "place named in objective text": lambda q, z, qid: objective_text_area(qid, z),
    "turn-in, else giver": lambda q, z, qid: place_of(taker_point(q)) or place_of(giver_point(q)),
    "objective text, turn-in, giver": lambda q, z, qid: objective_text_area(qid, z) or place_of(taker_point(q)) or place_of(giver_point(q)),
    "any text, turn-in, giver": lambda q, z, qid: objective_text_area(qid, z) or text_area(qid, z) or place_of(taker_point(q)) or place_of(giver_point(q)),
    "turn-in, giver, nearest town only": lambda q, z, qid: (lambda p: nearest_poi(*p) if p else None)(taker_point(q) or giver_point(q)),
}


def pairwise(pairs):
    """pairs: [(predicted, truth)] in one zone. Measures whether quests are grouped alike, whatever the names."""
    tp = fp = fn = 0
    for (p1, t1), (p2, t2) in combinations(pairs, 2):
        same_p, same_t = p1 == p2, t1 == t2
        tp += same_p and same_t
        fp += same_p and not same_t
        fn += same_t and not same_p
    return tp, fp, fn


print("\n=== Agreement with FieldJournal's sub-regions ===")
print(f"{'method':38} {'answered':>9} {'same name':>10} {'group P':>8} {'group R':>8} {'group F1':>9}")
for name, fn_ in methods.items():
    answered = same = 0
    by_zone = defaultdict(list)
    for qid, (zone, sub) in labels.items():
        q = QUESTS.get(qid)
        if not q:
            continue
        pred = fn_(q, zone, qid)
        if pred:
            answered += 1
            same += norm(pred) == norm(sub)
            by_zone[zone].append((norm(pred), norm(sub)))
    tp = fp = fnn = 0
    for pairs in by_zone.values():
        a, b, c = pairwise(pairs)
        tp, fp, fnn = tp + a, fp + b, fnn + c
    p = tp / (tp + fp) if tp + fp else 0
    r = tp / (tp + fnn) if tp + fnn else 0
    f = 2 * p * r / (p + r) if p + r else 0
    total = sum(1 for q in labels if q in QUESTS)
    print(f"{name:38} {answered:>4}/{total:<4} {100 * same / max(answered, 1):>9.0f}% {p:>8.2f} {r:>8.2f} {f:>9.2f}")

print("\n=== How often do giver, objectives and turn-in sit in the same area? ===")
same_go = same_gt = same_ot = both = both_gt = both_ot = 0
dist_go = []
for qid, q in QUESTS.items():
    g, o, t = giver_point(q), objective_centre(q), taker_point(q)
    if g and o:
        a, b = overlay_area(*g), overlay_area(*o)
        if a and b:
            both += 1
            same_go += norm(a) == norm(b)
        if g[0] == o[0]:
            dist_go.append(math.hypot(g[1] - o[1], g[2] - o[2]))
    if g and t:
        a, b = place_of(g), place_of(t)
        if a and b:
            both_gt += 1
            same_gt += norm(a) == norm(b)
    if o and t:
        a, b = overlay_area(*o), overlay_area(*t)
        if a and b:
            both_ot += 1
            same_ot += norm(a) == norm(b)
print(f"giver and objectives both resolved: {both}, same area: {100 * same_go / max(both, 1):.0f}%")
print(f"giver and turn-in both resolved: {both_gt}, same area: {100 * same_gt / max(both_gt, 1):.0f}%")
print(f"objectives and turn-in both resolved: {both_ot}, same area: {100 * same_ot / max(both_ot, 1):.0f}%")
if dist_go:
    print(f"giver to objective distance, share of map width: median {statistics.median(dist_go):.2f}, 90th percentile {sorted(dist_go)[int(len(dist_go) * 0.9)]:.2f}")

print("\n=== Group sizes across all quests, by giver (overlay, town, nearest overlay) ===")
groups = defaultdict(lambda: defaultdict(list))
map_names = {int(u["ID"]): u["Name_lang"] for u in rows("UiMap")}
unplaced = 0
for qid, q in QUESTS.items():
    p = giver_point(q)
    if not p:
        unplaced += 1
        continue
    g = overlay_area(*p) or nearest_poi(*p) or nearest_overlay(*p)
    if g:
        groups[p[0]][g].append((qid, q[0]))
    else:
        unplaced += 1
counts = [len(v) for v in groups.values()]
sizes = [len(q) for v in groups.values() for q in v.values()]
print("maps with quests:", len(groups), " groups per map, median:", statistics.median(counts), " max:", max(counts))
print("quests per group, median:", statistics.median(sizes), " max:", max(sizes), " unplaced quests:", unplaced)

for m in (1429, 1436, 2521, 1411):
    print(f"\n--- {map_names.get(m, m)} ({m}) ---")
    for g, qs in sorted(groups[m].items(), key=lambda kv: -len(kv[1]))[:12]:
        print(f"  {g} ({len(qs)}): " + "; ".join(n for _, n in qs[:5]))

print("\n=== Disagreements, Elwynn and Westfall ===")
shown = 0
for qid, (zone, sub) in sorted(labels.items()):
    if zone not in ("Elwynn Forest", "Westfall") or qid not in QUESTS:
        continue
    p = giver_point(QUESTS[qid])
    pred = (overlay_area(*p) or nearest_poi(*p) or nearest_overlay(*p)) if p else None
    if pred and norm(pred) != norm(sub) and shown < 16:
        shown += 1
        print(f"  {qid} {QUESTS[qid][0]!r}: label {sub!r}, predicted {pred!r}")
