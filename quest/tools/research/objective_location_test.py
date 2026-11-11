"""Test objective location directly, instead of through FieldJournal's labels.

Answers four questions from static data, and prints a report. Writes nothing.
  1. How many quests have an objective site at all, and how many of those have known coordinates?
  2. How many of those sites are one place, rather than scattered?
  3. Where the quest's own text says where the objective is, do the coordinates agree?
  4. If quests are grouped by distance, what would a real quest log look like?

Run with: python -I quest/tools/research/objective_location_test.py
"""
import contextlib
import io
import math
import random
import re
import runpy
import statistics
import sys
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

with contextlib.redirect_stdout(io.StringIO()):
    poc = runpy.run_path(str(Path(__file__).resolve().parent / "subzone_poc.py"))

QUESTS, QDB, ITEMS = poc["QUESTS"], poc["QDB_QUESTS"], poc["QDB_ITEMS"]
npc_points, object_points, listat = poc["npc_points"], poc["object_points"], poc["listat"]
overlays, overlay_area, area_name = poc["overlays"], poc["overlay_area"], poc["area_name"]
norm, labels, is_vanilla, map_region = poc["norm"], poc["labels"], poc["is_vanilla"], poc["map_region"]
giver_point, taker_point, objective_lines = poc["giver_point"], poc["taker_point"], poc["objective_lines"]
pairwise, children_names, rows = poc["pairwise"], poc["children_names"], poc["rows"]
LAYER_W, LAYER_H = poc["LAYER_W"], poc["LAYER_H"]
map_names = {int(u["ID"]): u["Name_lang"] for u in rows("UiMap")}

RADIUS = 300  # yards around one spot that still counts as "one place"
GROUP_DISTANCE = 500  # yards: quests further apart than this never share a group


def yards(m):
    """Map width and height in yards, from the zone's world bounds."""
    if m in map_region:
        _, x0, y0, x1, y1 = map_region[m]
        if y1 > y0 and x1 > x0:
            return y1 - y0, x1 - x0
    return None


def dist(m, a, b):
    w, h = yards(m)
    return math.hypot((a[0] - b[0]) * w, (a[1] - b[1]) * h)


def objective_sets(qid):
    """One point list per objective, so a camp with many spawns can't outvote a second objective."""
    q = QUESTS.get(qid)
    if not q:
        return []
    sets = [npc_points(listat(q, 9)), object_points(listat(q, 10))]
    places = listat(q, 17)
    for i in range(0, len(places) - 1, 2):
        if isinstance(places[i], int) and isinstance(places[i + 1], list):
            p = places[i + 1]
            sets.append([(places[i], p[j] / 1000, p[j + 1] / 1000) for j in range(0, len(p) - 1, 2)])
    return [s for s in sets if s]


def best_spot(sets):
    """The spot holding the most objective weight within RADIUS yards, on the map with most weight."""
    weights = defaultdict(float)
    for s in sets:
        for p in s:
            weights[p[0]] += 1 / (len(s) * len(sets))
    usable = {m: w for m, w in weights.items() if yards(m)}
    if not usable:
        return None
    m = max(usable, key=usable.get)
    pts = [((p[1], p[2]), 1 / (len(s) * len(sets))) for s in sets for p in s if p[0] == m]
    candidates = pts if len(pts) <= 250 else random.Random(1).sample(pts, 250)
    best, best_w = None, -1
    for c, _ in candidates:
        w = sum(pw for p, pw in pts if dist(m, c, p) <= RADIUS)
        if w > best_w:
            best, best_w = c, w
    inside = [(p, pw) for p, pw in pts if dist(m, best, p) <= RADIUS]
    total = sum(pw for _, pw in inside)
    centre = (sum(p[0] * pw for p, pw in inside) / total, sum(p[1] * pw for p, pw in inside) / total)
    return {"map": m, "centre": centre, "share": best_w, "points": sum(len(s) for s in sets)}


def rects_for(m, name):
    return [r for r, ids in overlays.get(m, ()) if any(norm(area_name.get(i)) == norm(name) for i in ids)]


def distance_to_area(m, point, name):
    """Yards from a point to the nearest rectangle of the named area. None if it has no rectangle here."""
    w, h = yards(m)
    px, py = point[0] * LAYER_W, point[1] * LAYER_H
    best = None
    for l, r, t, b in rects_for(m, name):
        dx = max(l - px, 0, px - r) / LAYER_W * w
        dy = max(t - py, 0, py - b) / LAYER_H * h
        d = math.hypot(dx, dy)
        best = d if best is None else min(best, d)
    return best


# ----------------------------------------------------------------------------------------------
# Text that states where the objective is, leaving out text that names the giver or the turn-in
# ----------------------------------------------------------------------------------------------
TURN_IN = re.compile(r"\b(then|and)?\s*(return|report|bring|deliver|speak|talk|take|give|hand|show|back to|go back|for|will)\b")
GIVER = re.compile(r"^.*?\b(wants you to|needs you to|has asked you to|asks you to|would like you to|has tasked you with|wishes you to|has commissioned you to|needs|wants)\b")
ACTION = r"(kill|slay|slaughter|destroy|defeat|hunt|collect|gather|retrieve|recover|obtain|find|locate|search|explore|scout|investigate|traverse|visit|reach|plant|place|use|burn|venture|enter|go to|travel to|head to|journey to)"
LOCATIVE = r"(in|at|inside|within|near|around|on|from|into)"


def objective_clause(text):
    """The part of the objective text that describes the task, or None if it only describes a hand-in."""
    t = text.lower().replace("’", "'").replace('\\"', '"')
    if re.search(r"\breward\b", t):
        return None
    t = GIVER.sub("", t, count=1).strip()
    m = TURN_IN.search(t)
    if m and m.start() == 0:
        return None
    clause = t[:m.start()] if m else t
    return clause if re.search(rf"\b{ACTION}\b", clause) else None


def stated_place(qid, zone):
    """The one sub-zone this quest's text names as the objective's location, if exactly one."""
    clause = next(filter(None, (objective_clause(line) for line in objective_lines(qid))), None)
    if not clause:
        return None, None
    hits = set()
    for name in children_names(zone):
        key = re.sub(r"^the ", "", name.lower().replace("’", "'"))
        if len(key) < 4 or "unused" in key or " - " in key:
            continue
        pattern = rf"\b({ACTION}|{LOCATIVE})\s+(the\s+)?{re.escape(key)}\b"
        if re.search(pattern, clause):
            hits.add(norm(name))
    if len(hits) != 1:
        return None, clause
    return hits.pop(), clause


# ----------------------------------------------------------------------------------------------
# 1. Coverage
# ----------------------------------------------------------------------------------------------
sites = {}
for qid in QUESTS:
    s = objective_sets(qid)
    if s:
        spot = best_spot(s)
        if spot:
            sites[qid] = spot


def has_real_objective(qid):
    """Vanilla only: QuestieDB says whether the quest asks for anything but a hand-in or a conversation."""
    q = QDB.get(qid)
    if not isinstance(q, list):
        return None
    o = q[9] if len(q) > 9 and isinstance(q[9], list) else []
    if len(q) > 8 and q[8]:
        return True
    if any(isinstance(x, list) and x for i, x in enumerate(o) if i != 2):
        return True
    for entry in (o[2] if len(o) > 2 and isinstance(o[2], list) else []):
        item = ITEMS.get(entry[0]) if isinstance(entry, list) else None
        if isinstance(item, list) and ((len(item) > 1 and item[1]) or (len(item) > 2 and item[2]) or (len(item) > 13 and item[13])):
            return True
    return False


print("=== 1. Coverage ===")
c = Counter()
for qid, q in QUESTS.items():
    fam = "vanilla" if is_vanilla(qid) else "new"
    c[fam, "total"] += 1
    if qid in sites:
        c[fam, "objective coordinates"] += 1
    if taker_point(q):
        c[fam, "turn-in coordinates"] += 1
    if qid in sites or taker_point(q):
        c[fam, "objective or turn-in"] += 1
    real = has_real_objective(qid)
    if real is True:
        c[fam, "has an objective to go to"] += 1
        c[fam, "...of which located"] += qid in sites
    elif real is False:
        c[fam, "talk, delivery or carried item only"] += 1
        c[fam, "...of which turn-in known"] += bool(taker_point(q))
for fam in ("vanilla", "new"):
    print(fam, {k[1]: v for k, v in sorted(c.items()) if k[0] == fam})

# ----------------------------------------------------------------------------------------------
# 2. Is the objective one place?
# ----------------------------------------------------------------------------------------------
print(f"\n=== 2. Share of objective spawns within {RADIUS} yards of one spot ===")
for fam, test in (("vanilla", is_vanilla), ("new", lambda q: not is_vanilla(q))):
    shares = [s["share"] for q, s in sites.items() if test(q)]
    bands = [(0.9, 1.01, "90-100%: one place"), (0.6, 0.9, "60-90%: mostly one place"), (0.3, 0.6, "30-60%: two or three"), (0, 0.3, "under 30%: scattered")]
    print(fam, f"n={len(shares)}", {label: f"{100 * sum(lo <= x < hi for x in shares) / len(shares):.0f}%" for lo, hi, label in bands})
one_point = sum(1 for s in sites.values() if s["points"] == 1)
print("quests whose objective is a single spawn point:", one_point, "of", len(sites))

print("\n=== 2b. Every vanilla quest, by the answer it would get ===")
ONE_PLACE = 0.6
buckets = Counter()
for qid, q in QUESTS.items():
    if not is_vanilla(qid):
        continue
    if qid in sites:  # Zmap has corrections QuestieDB's raw rows lack, so any coordinates count
        buckets["objective, one place" if sites[qid]["share"] >= ONE_PLACE else "objective, several places"] += 1
    elif has_real_objective(qid) is True:
        buckets["objective, no coordinates"] += 1
    elif taker_point(q):
        buckets["nothing to do but hand in, turn-in known"] += 1
    else:
        buckets["nothing to do but hand in, turn-in unknown"] += 1
total = sum(buckets.values())
for k, v in buckets.most_common():
    print(f"  {k}: {v} ({100 * v / total:.0f}%)")

print("\n=== 2c. Why do 'objective, no coordinates' quests have none? ===")
QDB_DIR = poc["REFERENCE"] / "QuestieDB/data/Forever"
QDB_NPCS = poc["lua_long_string_table"](QDB_DIR / "foreverNpcDB.lua", "QuestieDB.npcData")
QDB_OBJECTS = poc["lua_long_string_table"](QDB_DIR / "foreverObjectDB.lua", "QuestieDB.objectData")
overworld = {int(poc["num"](r["AreaID"])) for r in poc["assign"]} - {0}


def source_ids(qid):
    """NPC and object IDs that can satisfy this quest's objectives, drops included."""
    q = QDB[qid]
    o = q[9] if len(q) > 9 and isinstance(q[9], list) else []
    npcs, objs = [], []
    for entry in (o[0] if len(o) > 0 and isinstance(o[0], list) else []):
        if isinstance(entry, list) and entry:
            npcs.append(entry[0])
    for entry in (o[1] if len(o) > 1 and isinstance(o[1], list) else []):
        if isinstance(entry, list) and entry:
            objs.append(entry[0])
    for entry in (o[2] if len(o) > 2 and isinstance(o[2], list) else []):
        item = ITEMS.get(entry[0]) if isinstance(entry, list) and entry else None
        if isinstance(item, list):
            npcs += item[1] if len(item) > 1 and isinstance(item[1], list) else []
            objs += item[2] if len(item) > 2 and isinstance(item[2], list) else []
    return npcs, objs


def spawn_zones(table, ids, index):
    zones = set()
    for i in ids:
        row = table.get(i)
        if isinstance(row, list) and len(row) > index and isinstance(row[index], dict):
            zones |= {z for z in row[index] if isinstance(z, int)}
    return zones


why = defaultdict(list)
for qid in QUESTS:
    if qid in sites or not is_vanilla(qid) or has_real_objective(qid) is not True:
        continue
    npcs, objs = source_ids(qid)
    zones = spawn_zones(QDB_NPCS, npcs, 6) | spawn_zones(QDB_OBJECTS, objs, 3)
    if not npcs and not objs:
        o = QDB[qid][9] if isinstance(QDB[qid][9], list) else []
        if len(o) > 2 and isinstance(o[2], list) and o[2]:
            why["no source but a vendor or crafting: item hand-in"].append(qid)
        elif QDB[qid][8]:
            why["reach-a-place trigger with no coordinates"].append(qid)
        else:
            why["reputation, kill credit or spell objective"].append(qid)
    elif not zones:
        why["source listed, no spawns anywhere in QuestieDB"].append(qid)
    elif zones & overworld:
        why["spawns in the open world, missing from Zmap's table: recoverable"].append(qid)
    else:
        why["spawns only in instances or cities"].append(qid)
for k, v in sorted(why.items(), key=lambda kv: -len(kv[1])):
    sample = random.Random(2).sample(v, min(8, len(v)))
    print(f"  {k}: {len(v)}. For example: " + "; ".join(QUESTS[q][0] for q in sample))

# ----------------------------------------------------------------------------------------------
# 3. Coordinates against the quest's own statement of where the objective is
# ----------------------------------------------------------------------------------------------
print("\n=== 3. Does the coordinate match the place the quest text states? ===")
truth = {}
no_rect = 0
# Read by eye before seeing any score. These name two places, or only a later step of the quest.
AMBIGUOUS = {676, 4812, 8949}
for qid, s in sites.items():
    zone = map_names.get(s["map"])
    if not zone or qid in AMBIGUOUS:
        continue
    place, _ = stated_place(qid, zone)
    if place:
        if rects_for(s["map"], place):
            truth[qid] = place
        else:
            no_rect += 1
print(f"quests whose text states a place: {len(truth) + no_rect}. Scorable, since that area has a map rectangle: {len(truth)}. Not scorable: {no_rect}")
if "--audit" in sys.argv:  # list the reference with no scores, so it can be checked by eye without seeing results
    for q, place in sorted(truth.items()):
        print(f"{q} -> {place!r}: {' '.join(objective_lines(q))[:150]}")
    sys.exit()


def old_area(qid):
    p = poc["objective_centre"](QUESTS[qid])
    return overlay_area(*p) if p else None


def new_area(qid):
    s = sites[qid]
    return overlay_area(s["map"], *s["centre"])


def score(ids, area_fn):
    answered = same = 0
    for q in ids:
        a = area_fn(q)
        if a:
            answered += 1
            same += norm(a) == truth[q]
    return answered, same


ids = list(truth)
a, s_ = score(ids, old_area)
print(f"old method, median spawn in a rectangle: answered {a}/{len(ids)}, exact name {100 * s_ / max(a, 1):.0f}%")
a, s_ = score(ids, new_area)
print(f"new method, densest spot in a rectangle: answered {a}/{len(ids)}, exact name {100 * s_ / max(a, 1):.0f}%")
ds = [distance_to_area(sites[q]["map"], sites[q]["centre"], truth[q]) for q in ids]
print("yards from the densest spot to the stated area's rectangle:")
print(f"  inside: {100 * sum(d == 0 for d in ds) / len(ds):.0f}%  within 150: {100 * sum(d <= 150 for d in ds) / len(ds):.0f}%  within 300: {100 * sum(d <= 300 for d in ds) / len(ds):.0f}%  within 600: {100 * sum(d <= 600 for d in ds) / len(ds):.0f}%  median: {statistics.median(ds):.0f}")
control = []
control_rng = random.Random(11)
for q in ids:
    m = sites[q]["map"]
    others = sorted({norm(area_name.get(i)) for _, a_ids in overlays.get(m, ()) for i in a_ids if i in area_name} - {truth[q]})
    if others:
        control.append(distance_to_area(m, sites[q]["centre"], control_rng.choice(others)))
print("control, the same spot against a random other area of that zone:")
print(f"  inside: {100 * sum(d == 0 for d in control) / len(control):.0f}%  within 150: {100 * sum(d <= 150 for d in control) / len(control):.0f}%  within 300: {100 * sum(d <= 300 for d in control) / len(control):.0f}%  within 600: {100 * sum(d <= 600 for d in control) / len(control):.0f}%  median: {statistics.median(control):.0f}")
print("\nby how concentrated the spawns are:")
for lo, hi in ((0.9, 1.01), (0.6, 0.9), (0.0, 0.6)):
    sub = [(q, d) for q, d in zip(ids, ds) if lo <= sites[q]["share"] < hi]
    if sub:
        print(f"  share {lo:.1f}-{hi:.1f}: n={len(sub)}, within 300 yards of the stated place: {100 * sum(d <= 300 for _, d in sub) / len(sub):.0f}%")



def snapped_area(qid, limit=200):
    """The densest spot's rectangle, or the nearest named rectangle within the limit. Designed after seeing this set."""
    named = new_area(qid)
    if named:
        return named
    m, centre = sites[qid]["map"], sites[qid]["centre"]
    best, best_d = None, limit
    for name in {area_name.get(i) for _, a_ids in overlays.get(m, ()) for i in a_ids if i in area_name}:
        d = distance_to_area(m, centre, name)
        if d is not None and d <= best_d:
            best, best_d = name, d
    return best


right_name = sum(1 for q in ids if new_area(q) and norm(new_area(q)) == truth[q])
right_snapped = sum(1 for q in ids if snapped_area(q) and norm(snapped_area(q)) == truth[q])
print(f"\nright area name, of all {len(ids)}: rectangles alone {right_name} ({100 * right_name / len(ids):.0f}%), with snapping {right_snapped} ({100 * right_snapped / len(ids):.0f}%)")
print("\nAll misses (over 300 yards):")
misses = [(q, d) for q, d in zip(ids, ds) if d > 300]
for q, d in misses:
    print(f"  {q} {QUESTS[q][0]!r} in {map_names[sites[q]['map']]}: text says {truth[q]!r}, {d:.0f} yards off, share {sites[q]['share']:.2f}, {sites[q]['points']} points. Text: {' '.join(objective_lines(q))[:120]}")
print("\nRight spot, wrong or no area name from the map rectangles:")
for q, d in zip(ids, ds):
    a = new_area(q)
    if d <= 300 and (not a or norm(a) != truth[q]):
        print(f"  {q}: text says {truth[q]!r}, rectangles say {a!r}, {d:.0f} yards from the stated area")

# ----------------------------------------------------------------------------------------------
# 3b. The same group metric as before, against both references, on the same quests
# ----------------------------------------------------------------------------------------------


def group_scores(pred_by_map):
    tp = fp = fn = 0
    for pairs in pred_by_map.values():
        a, b, c_ = pairwise(pairs)
        tp, fp, fn = tp + a, fp + b, fn + c_
    p = tp / (tp + fp) if tp + fp else 0
    r = tp / (tp + fn) if tp + fn else 0
    return p, r, 2 * p * r / (p + r) if p + r else 0


def spatial_clusters(qids, limit=GROUP_DISTANCE):
    """Complete linkage: every pair in a group is within the limit. Returns {questID: group number}."""
    by_map = defaultdict(list)
    for q in qids:
        by_map[sites[q]["map"]].append(q)
    out, next_id = {}, 0
    for m, qs in by_map.items():
        groups = [[q] for q in qs]
        while True:
            best, pair = limit, None
            for i, j in combinations(range(len(groups)), 2):
                d = max(dist(m, sites[a]["centre"], sites[b]["centre"]) for a in groups[i] for b in groups[j])
                if d <= best:
                    best, pair = d, (i, j)
            if not pair:
                break
            groups[pair[0]] += groups.pop(pair[1])
        for g in groups:
            for q in g:
                out[q] = next_id
            next_id += 1
    return out


def report_against(name, reference):
    ids_ = [q for q in reference if q in sites]
    spatial = spatial_clusters(ids_)
    methods = {
        "median spawn, map rectangle (the 0.42 method)": old_area,
        "densest spot, map rectangle": new_area,
        f"densest spot, grouped within {GROUP_DISTANCE} yards": lambda q: spatial[q],
    }
    print(f"\n{name}: {len(ids_)} quests")
    print(f"  {'method':52} {'answered':>9} {'precision':>10} {'recall':>7} {'F1':>6}")
    for label, fn in methods.items():
        by_map = defaultdict(list)
        answered = 0
        for q in ids_:
            pred = fn(q)
            if pred is not None:
                answered += 1
                by_map[sites[q]["map"]].append((pred if isinstance(pred, int) else norm(pred), reference[q]))
        p, r, f = group_scores(by_map)
        print(f"  {label:52} {answered:>9} {p:>10.2f} {r:>7.2f} {f:>6.2f}")


print("\n=== 3b. Group agreement, same measure as the earlier table ===")
report_against("Reference: place stated in the quest's objective text", truth)
fj = {q: norm(sub) for q, (_, sub) in labels.items()}
report_against("Reference: FieldJournal's labels", fj)

# ----------------------------------------------------------------------------------------------
# 3c. When giver and objective disagree, which one do FieldJournal's labels follow?
# ----------------------------------------------------------------------------------------------
print("\n=== 3c. Which place do FieldJournal's labels describe? ===")
tally = Counter()
for q, (_, sub) in labels.items():
    if q not in sites or q not in QUESTS:
        continue
    o = new_area(q)
    g = giver_point(QUESTS[q])
    t = taker_point(QUESTS[q])
    ga = overlay_area(*g) if g else None
    ta = overlay_area(*t) if t else None
    hub = {norm(x) for x in (ga, ta) if x}
    if not o or not hub or norm(o) in hub:
        continue
    tally["objective and hub differ"] += 1
    label = norm(sub)
    if label == norm(o):
        tally["label names the objective's area"] += 1
    elif label in hub:
        tally["label names the giver's or turn-in's area"] += 1
    else:
        tally["label names neither"] += 1
print(dict(tally))

# ----------------------------------------------------------------------------------------------
# 4. Simulated quest logs
# ----------------------------------------------------------------------------------------------
print(f"\n=== 4. Simulated logs: 8 quests from one zone, similar level, one faction, grouped within {GROUP_DISTANCE} yards ===")
ALLIANCE, HORDE = 4294967373, 8589934770
rng = random.Random(7)
candidates = defaultdict(list)
for q, s in sites.items():
    qq = QUESTS[q]
    if qq[1] <= 0 or s["share"] < 0.6:
        continue
    for side, mask in (("A", ALLIANCE), ("H", HORDE)):
        if qq[3] == 0 or qq[3] & mask == mask:
            candidates[s["map"], side].append(q)
results, named_results = [], []
for key, qs in candidates.items():
    if len(qs) < 12:
        continue
    for _ in range(30):
        centre = rng.choice(qs)
        band = [q for q in qs if abs(QUESTS[q][1] - QUESTS[centre][1]) <= 4]
        if len(band) < 8:
            continue
        log = rng.sample(band, 8)
        g = spatial_clusters(log)
        sizes = Counter(g.values())
        results.append((len(sizes), sum(v for v in sizes.values() if v >= 2) / 8))
        names = Counter(norm(new_area(q)) if new_area(q) else f"unnamed{q}" for q in log)
        named_results.append((len(names), sum(v for v in names.values() if v >= 2) / 8))
for label, res in ((f"by distance, within {GROUP_DISTANCE} yards", results), ("by named area from map rectangles", named_results)):
    print(f"{label}: {len(res)} logs. Groups per log: median {statistics.median(r[0] for r in res)} of 8 quests. Quests sharing a group: median {100 * statistics.median(r[1] for r in res):.0f}%, mean {100 * statistics.mean(r[1] for r in res):.0f}%")
