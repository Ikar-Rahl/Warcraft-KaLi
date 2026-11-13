"""Build the exploration bench's data and art from the game's tables and QuestieDB's Forever data.

Writes recipe/bench/js/data.js and the PNGs in recipe/bench/art/. Everything fetched is
cached, so a re-run is quick. Real: item, spell, NPC and zone names (the client's French tables), reagents,
skill ranks, vendors and where they stand (QuestieDB), icons and map tiles (this build). Invented: which
recipes Ikar met where, auction house prices and dates, and the second character.

Run with: python -I recipe/tools/bench_data.py
"""
import csv
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.art import CASC, decode_blp, fetch, write_png  # noqa: E402
from kali.paths import QUEST, RECIPE, REFERENCE  # noqa: E402

DB2 = REFERENCE / "db2/1.60.1.70790"
QDB = REFERENCE / "QuestieDB"
BENCH = RECIPE / "bench"
ART = BENCH / "art"
CACHE = ART / "_cache"

LEARNING_SPELLS = {"483", "402265"}
PROFESSIONS = {  # skill line -> recipe item subclass
    "185": 5, "333": 8, "197": 2, "171": 6, "165": 1, "164": 4, "202": 3, "129": 7, "356": 9,
    # Gathering: Forever gives them recipes too (smelting; camp items, « Campement », with « Plan : » items).
    "186": 0, "182": 0, "393": 0,
}
# Zones Ikar's character has been to (screenshots, quest log), in the order the bench prefers them.
VISITED = [1657, 141, 148, 1537, 1, 38, 1519, 12]
MAPS = {1657: (1457, "2172"), 141: (1438, "2180")}  # zone -> (UiMap, UiMapArt) drawn on the bench's map

CHARACTER = {
    "name": "Ikar Rahl", "level": 13, "zone": 1657,
    # Ranks and known recipes as Ikar's screenshots of 2026-11-09 show them.
    "profs": {"333": 18, "185": 56},
    "known_names": {
        # The list shows recipe names: "De poussière à granules" makes the item "Granule de magie".
        "333": ["De poussière à granules", "Bâtonnet runique en cuivre", "Ench. de bracelets (Déviation mineure)",
                "Enchantement de brassards (Endurance médiocre)", "Baguette d’entraînement de novice"],
        "185": ["Viande de sanglier rôtie", "Goujon brillant", "Viande d’ours fumée", "Feu de camp basique",
                "Côtes de sanglier à la bière", "Viande de loup épicée", "Oeufs aux herbes",
                "Viande de loup grillée"],
    },
}
# Secourisme has nothing seen yet: the one count at zero, so « Carnet : 0 » can be judged.
ALT = {"name": "Elorah", "level": 22, "profs": {"197": 70, "186": 50, "129": 40}, "invented": True}
QUOTA = {"185": 7, "333": 5, "197": 4, "171": 3, "165": 3, "164": 2, "202": 2, "129": 2, "186": 2, "182": 2, "393": 2, "356": 2}

TOKEN = re.compile(r"""\s*(?:(\{)|(\})|(\[)|(\])|(=)|([,;])|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"|(nil|true|false))""")


def lua_value(text):
    """Parse one Lua table literal (numbers, strings, nil, nested tables) without running it."""
    toks = []
    pos = 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m or m.end() == pos:
            if text[pos:].strip() == "":
                break
            raise ValueError(f"bad Lua at {pos}: {text[pos:pos + 40]!r}")
        pos = m.end()
        g = m.groups()
        if g[0]: toks.append("{")
        elif g[1]: toks.append("}")
        elif g[2]: toks.append("[")
        elif g[3]: toks.append("]")
        elif g[4]: toks.append("=")
        elif g[5]: toks.append(",")
        elif g[6] is not None: toks.append(("n", float(g[6]) if "." in g[6] or "e" in g[6].lower() else int(g[6])))
        elif g[7] is not None: toks.append(("s", unescape(g[7])))
        elif g[8] is not None: toks.append(("s", unescape(g[8])))
        else: toks.append(("k", {"nil": None, "true": True, "false": False}[g[9]]))
    it = iter(toks + [None])
    cur = [next(it)]

    def advance():
        cur[0] = next(it)

    def value():
        t = cur[0]
        if t == "{":
            advance()
            return table()
        advance()
        return t[1]

    def table():
        items, keyed = [], {}
        while cur[0] != "}":
            if cur[0] == "[":
                advance()
                k = value()
                assert cur[0] == "]"; advance()
                assert cur[0] == "="; advance()
                keyed[k] = value()
            else:
                items.append(value())
            if cur[0] == ",":
                advance()
        advance()
        if not keyed:
            return items
        for i, v in enumerate(items, 1):
            keyed[i] = v
        return keyed

    return value()


def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def lua_rows(path, wanted=None):
    """Rows of a QuestieDB file, one `[id] = {...},` per line; only the wanted IDs are parsed."""
    rows = {}
    line_re = re.compile(r"^\[(\d+)\] = (\{.*\}),?\s*$")
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = line_re.match(line)
            if m and (wanted is None or int(m.group(1)) in wanted):
                rows[int(m.group(1))] = m.group(2)
    return rows


ATLASES = """
Profession-ProgressBar-BG-c60 Profession-ProgressBar-frame-c60 Profession-Ring-Frame-c60
Profession-icon-Expand-c60 Profession-icon-shrink-c60 Profession-checkbox-c60 Profession-square-frame-c60
Profession-square-frame-slot-c60 Profession-button-red-crossmark-c60 Profession-button-red-crossmark-pressed-c60
Profession-page-box-c60 Profession-Background-Template2 common-insideframe
QuestBG-Classic VendorGossipIcon TrainerGossipIcon Profession Innkeeper
Waypoint-MapPin-Tracked Waypoint-MapPin-Untracked Waypoint-MapPin-Highlight Waypoint-MapPin-ChatIcon
bags-newitem bags-glow-white bags-icon-tradegoods collections-icon-favorites poi-workorders Professions-Crafting-Orders-Icon
common-search-magnifyingglass common-dropdown-bg UI-HUD-MicroMenu-Professions-Up UI-HUD-Minimap-Tracking-Up
Professions-recipe-header-left Professions-recipe-header-middle Professions-recipe-header-right
Professions-recipe-header-collapse Professions-recipe-header-expand
UI-HUD-Nameplates-LevelIndicator Tracker-Check groupfinder-icon-friend Banker GM-icon-visible
SpellBook-SkillLineTab
QuestBG-Parchment QuestBG-cooking QuestBG-enchanting QuestBG-tailoring QuestBG-alchemy QuestBG-leatherworking
QuestBG-blacksmithing QuestBG-engineering QuestBG-fishing
worldquest-icon-alchemy worldquest-icon-blacksmithing worldquest-icon-cooking worldquest-icon-enchanting worldquest-icon-engineering
worldquest-icon-firstaid worldquest-icon-fishing worldquest-icon-herbalism worldquest-icon-leatherworking worldquest-icon-mining
worldquest-icon-skinning worldquest-icon-tailoring Professions-Crafting-Orders-Icon
Navigation-Tracked-Arrow Navigation-Tracked-Icon Focus-Tracker Target-Tracker
UI-HUD-Minimap-Arrow-QuestTracking Profession-button-arrow-right Profession-button-arrow-right-pressed DialogNew-ForwardArrow
Waypoint-MapPin-ButtonToggle Lightlink Darklink Lightlink-active MiniMap-QuestArrow
UI-SquareButtonBrown-Up common-button-square-gray-up common-button-tertiary-normal-small common-button-tertiary-hover-small
128-RedButton-Left 128-RedButton-Right 128-GoldRedButton-Left questlog-icon-setting
auctionhouse-icon-clock questlog-questtypeicon-clockyellow clock-icon worldquest-icon-clock
""".split()


def atlas_table(names):
    """The atlases' places on their sheets, per art set, and fetch each sheet as a PNG (as quest/tools/bench_art.py does)."""
    sheets = {r["ID"]: r for r in read_csv("UiTextureAtlas.csv")}
    wanted = {n.lower() for n in names}
    element = {r["ID"]: r["Name"].lower() for r in read_csv("UiTextureAtlasElement.csv") if r["Name"].lower() in wanted}
    members = {}
    for r in read_csv("UiTextureAtlasMember.csv"):
        n = element.get(r["UiTextureAtlasElementID"])
        if n:
            members.setdefault(n, []).append(r)
    missing = sorted(wanted - set(members))
    if missing:
        print("  no atlas row for:", ", ".join(missing))
    table, used = {}, set()
    for name, rows in sorted(members.items()):
        by_set = {}
        for r in rows:
            sh = sheets.get(r["UiTextureAtlasID"])
            if sh:
                by_set.setdefault(sh["UiTextureAtlasSetID"], []).append((r, sh))
        entry = {}
        for set_id, pairs in by_set.items():
            pairs.sort(key=lambda p: int(p[1]["UiCanvasID"]) or 1)
            (r1, sh1), (r, sh) = pairs[0], pairs[-1]
            base = int(sh1["UiCanvasID"]) or 1
            used.add(sh["FileDataID"])
            entry[set_id] = {"f": sh["FileDataID"], "sw": int(sh["AtlasWidth"]), "sh": int(sh["AtlasHeight"]),
                             "x": int(r["CommittedLeft"]), "y": int(r["CommittedTop"]),
                             "pw": int(r["CommittedRight"]) - int(r["CommittedLeft"]),
                             "ph": int(r["CommittedBottom"]) - int(r["CommittedTop"]),
                             "w": int(r1["Width"]) // base, "h": int(r1["Height"]) // base}
        table[name] = entry
    (ART / "sheets").mkdir(exist_ok=True)
    for fdid in sorted(used):
        png = ART / "sheets" / f"{fdid}.png"
        if not png.exists():
            w, h, rgba = decode_blp(fetch(CASC.format(fdid), CACHE / f"{fdid}.blp"))
            write_png(png, w, h, rgba)
    return table


CATEGORY_PARENTS = {}


def read_csv(name):
    with open(DB2 / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def category_of(ability):
    """The recipe's category in the professions window, or None outside the profession's own tree."""
    cid = (ability or {}).get("TradeSkillCategoryID") or "0"
    return int(cid) if cid != "0" and CATEGORY_PARENTS.get(cid, "0") != "0" else None


def norm(s):
    return s.replace("’", "'").replace("î", "i").lower().strip()


def main():
    ART.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    (ART / "icons").mkdir(exist_ok=True)
    (ART / "map").mkdir(exist_ok=True)

    items_db2 = {r["ID"]: r for r in read_csv("Item.csv")}
    sparse = {r["ID"]: r for r in read_csv("ItemSparse.frFR.csv")}
    spell_name = {r["ID"]: r["Name_lang"] for r in read_csv("SpellName.frFR.csv")}
    skill_name = {r["ID"]: r["DisplayName_lang"] for r in read_csv("SkillLine.frFR.csv")}
    skill_icon = {r["ID"]: r["SpellIconFileID"] for r in read_csv("SkillLine.frFR.csv")}
    area_name = {r["ID"]: r["AreaName_lang"] for r in read_csv("AreaTable.frFR.csv")}
    # The world map's names (UiMap), which the addon would use (C_Map.GetMapInfo). This build's zone table writes
    # some zones with their English name in parentheses ("Sombrivage (Darkshore)"); the map says "Sombrivage".
    uimap_name = {r["ID"]: r["Name_lang"] for r in read_csv("UiMap.frFR.csv")}
    uimap_type = {r["ID"]: r["Type"] for r in read_csv("UiMap.csv")}
    zone_map = {}
    for r in sorted(read_csv("UiMapAssignment.csv"), key=lambda r: int(r["OrderIndex"] or 0)):
        if uimap_type.get(r["UiMapID"]) == "3":
            zone_map.setdefault(r["AreaID"], r["UiMapID"])
    place_name = lambda area: uimap_name.get(zone_map.get(str(area), ""), area_name.get(str(area), str(area)))
    # The professions window's own categories (TradeSkillCategory), by the recipe's SkillLineAbility row.
    categories_db2 = {r["ID"]: r for r in read_csv("TradeSkillCategory.frFR.csv")}
    CATEGORY_PARENTS.update({k: r["ParentTradeSkillCategoryID"] for k, r in categories_db2.items()})
    effects = {r["ID"]: r["SpellID"] for r in read_csv("ItemEffect.csv")}
    abilities = {}
    for r in read_csv("SkillLineAbility.csv"):
        if r["SkillLine"] in PROFESSIONS:
            abilities.setdefault(r["Spell"], r)
    reagents = {}
    for r in read_csv("SpellReagents.csv"):
        pairs = [(int(r[f"Reagent_{i}"]), int(r[f"ReagentCount_{i}"])) for i in range(8) if r.get(f"Reagent_{i}", "0") not in ("", "0")]
        reagents[r["SpellID"]] = pairs

    # Recipe item -> the spell it teaches.
    teaches = {}
    for r in read_csv("ItemXItemEffect.csv"):
        sp = effects.get(r["ItemEffectID"])
        if sp and sp not in LEARNING_SPELLS and r["ItemID"] in items_db2 and items_db2[r["ItemID"]]["ClassID"] == "9":
            teaches[r["ItemID"]] = sp
    taught_by_item = {sp: it for it, sp in teaches.items()}

    # MinSkillLineRank is 1 throughout this build's table. A recipe item carries the real requirement; a trainer
    # recipe's is server-side (the addon reads it with GetTrainerServiceSkillReq), so the bench estimates it from
    # the yellow threshold, as classic recipes usually sit 40 below it.
    def required(sp):
        it = taught_by_item.get(sp)
        if it and sparse.get(it, {}).get("RequiredSkillRank"):
            return int(sparse[it]["RequiredSkillRank"])
        low = int(abilities.get(sp, {}).get("TrivialSkillLineRankLow") or 1)
        return max(1, low - 40)

    # QuestieDB: recipe items (vendors, drops) and the NPCs involved.
    item_rows = lua_rows(QDB / "data/Forever/foreverItemDB.lua", {int(i) for i in teaches})
    qitems = {i: lua_value(t) for i, t in item_rows.items()}
    npc_ids = set()
    for row in qitems.values():
        for idx in (1, 13):  # npcDrops, vendors (0-based positions of keys 2 and 14)
            if len(row) > idx and isinstance(row[idx], list):
                npc_ids.update(n for n in row[idx] if isinstance(n, int))
    npc_rows = {i: lua_value(t) for i, t in lua_rows(QDB / "data/Forever/foreverNpcDB.lua").items()}
    npc_fr = {i: lua_value(t) for i, t in lua_rows(QDB / "l10n/Forever/lookupNpcs/frFR.lua").items()}

    def npc_info(nid):
        row = npc_rows.get(nid)
        if not row:
            return None
        spawns = row[6] if len(row) > 6 and isinstance(row[6], dict) else {}
        friendly = row[12] if len(row) > 12 else None
        fr = npc_fr.get(nid) or []
        return {"spawns": spawns, "friendly": friendly or "", "subEn": row[13] if len(row) > 13 else None,
                "name": (fr[0] if fr and fr[0] else row[0]), "title": (fr[1] if len(fr) > 1 and fr[1] else row[13] if len(row) > 13 else None)}

    def visited_spot(info):
        for z in VISITED:
            pts = info["spawns"].get(z)
            if pts:
                return z, pts[0]
        return None

    # Ikar's known recipes, by the names the screenshots show.
    known = {}
    for skill, names in CHARACTER["known_names"].items():
        pool = {norm(spell_name.get(sp, "")): sp for sp, a in abilities.items() if a["SkillLine"] == skill}
        for n in names:
            sp = pool.get(norm(n))
            if sp:
                known[sp] = skill
            else:
                print("  known recipe not found:", n)

    sightings = []
    used_recipes = set(known)

    def add_sighting(kind, item, spell, npc=None, zone=None, xy=None, **extra):
        s = {"kind": kind, "recipe": int(spell), "item": int(item) if item else None}
        if npc:
            s["npc"] = npc
        if zone:
            s["zone"] = zone
        if xy:
            s["x"], s["y"] = round(xy[0], 1), round(xy[1], 1)
        s.update(extra)
        sightings.append(s)
        used_recipes.add(spell)

    # Vendors: every recipe item a friendly vendor sells in a visited zone, cheapest ranks first.
    by_skill = {}
    for item, spell in teaches.items():
        a = abilities.get(spell)
        q = qitems.get(int(item))
        if not a or not q or len(q) < 14 or not isinstance(q[13], list):
            continue
        rank = required(spell)
        if rank > 125:
            continue
        spots = []
        for nid in q[13]:
            info = npc_info(nid)
            if info and "A" in info["friendly"]:
                v = visited_spot(info)
                if v:
                    spots.append((VISITED.index(v[0]), nid, v))
        if spots:
            spots.sort()
            by_skill.setdefault(a["SkillLine"], []).append((spots[0][0], rank, int(item), spell, spots[:2]))
    for skill, rows in by_skill.items():
        rows.sort()
        picked = [r for r in rows if r[3] in known]  # vendors of recipes Ikar knows, to show them as known
        must = [r for r in rows if r[2] == 6326]  # Recette : Maquereau ombré, the one Ikar looked for
        rest = [r for r in rows if r not in picked and r not in must]
        for _, rank, item, spell, spots in must + rest[:max(0, QUOTA.get(skill, 0) - len(must))] + picked:
            for _, nid, (zone, xy) in spots:
                add_sighting("vendor", item, spell, npc=nid, zone=zone, xy=xy, date="2026-11-0" + str(3 + len(sightings) % 6))

    # Trainers in Darnassus: what each lists, up to rank 125.
    trainer_for = {"185": (r"Cook|Chef", 1657), "333": (r"Enchant", 1657), "197": (r"Tailor", 1657), "171": (r"Alchem", 1657), "186": (r"Mining", 1537)}
    for skill, (sub, tzone) in trainer_for.items():
        # A trainer: npcFlags has the trainer bit (16), and the title names the profession.
        trainers = [nid for nid, row in npc_rows.items()
                    if len(row) > 14 and isinstance(row[13], str) and re.search(sub, row[13])
                    and isinstance(row[14], int) and row[14] & 16 and isinstance(row[6], dict) and tzone in row[6]]
        if not trainers:
            print("  no trainer for", sub, "in", tzone)
            continue
        nid = sorted(trainers)[0]
        info = npc_info(nid)
        listed = sorted((required(sp), sp) for sp, a in abilities.items()
                        if a["SkillLine"] == skill and a["AcquireMethod"] == "0" and sp not in taught_by_item
                        and required(sp) <= 100 and sp in spell_name and reagents.get(sp)
                        # Gray at 25 or less marks oddities (faction banners, mana wells), not trainer recipes.
                        and int(a["TrivialSkillLineRankHigh"] or 0) > 25)
        for rank, sp in listed[:12]:
            add_sighting("trainer", None, sp, npc=nid, zone=tzone, xy=info["spawns"][tzone][0], date="2026-11-08", rank=rank)

    # Auction house: three recipes nobody sells, seen on the Recipes page.
    ah = []
    for item, spell in teaches.items():
        a = abilities.get(spell)
        q = qitems.get(int(item))
        if a and q and (len(q) < 14 or not q[13]) and a["SkillLine"] in ("197", "165", "171") and 20 <= required(spell) <= 125:
            ah.append((a["SkillLine"], required(spell), int(item), spell))
    seen_skill = set()
    for skill, rank, item, spell in sorted(ah):
        if skill not in seen_skill:
            seen_skill.add(skill)
            add_sighting("ah", item, spell, price=4500 + rank * 350, date="2026-11-07", zone=1657)

    # Two drops, looted from mobs in visited zones, for two different professions.
    dropped_skills = set()
    for item, spell in sorted(teaches.items(), key=lambda p: (required(p[1]) if p[1] in abilities else 999, int(p[0]))):
        q = qitems.get(int(item))
        skill = abilities.get(spell, {}).get("SkillLine")
        if not q or not isinstance(q[1], list) or spell in used_recipes or skill in dropped_skills:
            continue
        hit = next((((info := npc_info(n)), visited_spot(info), n) for n in q[1] if npc_info(n) and visited_spot(npc_info(n))), None)
        if hit:
            info, (zone, xy), nid = hit
            add_sighting("drop", item, spell, npc=nid, zone=zone, xy=xy, date=f"2026-11-0{6 - len(dropped_skills)}", from_name=info["name"])
            dropped_skills.add(skill)
            if len(dropped_skills) == 2:
                break

    # The second character, invented: knows the cheapest tailoring and first aid recipes.
    alt_known = []
    for skill, n in (("197", 12), ("186", 3), ("129", 3)):
        rank = ALT["profs"][skill]
        mine = sorted((required(sp), sp) for sp, a in abilities.items()
                      if a["SkillLine"] == skill and required(sp) <= rank and sp in spell_name and reagents.get(sp))
        alt_known += [sp for _, sp in mine[:n]]
    used_recipes.update(alt_known)

    # A showcase vendor for the bench, invented: one slot per marker case for Ikar (Cuisine 56), all real recipes.
    def bucket(sp, rank):
        a = abilities[sp]
        y, g = int(a["TrivialSkillLineRankLow"] or 0), int(a["TrivialSkillLineRankHigh"] or 0)
        if rank < required(sp):
            return "red"
        if rank < y:
            return "optimal"
        if rank < round((y + g) / 2):
            return "medium"
        return "easy" if rank < g else "trivial"
    # Only recipe items with a French name in this build's tables, and recipes with real difficulty thresholds.
    cook = sorted((required(sp), int(it), sp) for it, sp in teaches.items()
                  if abilities.get(sp, {}).get("SkillLine") == "185" and sp in spell_name
                  and sparse.get(it, {}).get("Display_lang") and int(abilities[sp]["TrivialSkillLineRankLow"] or 0) > 0)
    taken = set()

    def pick(test):
        for _, it, sp in cook:
            if sp not in taken and test(sp):
                taken.add(sp)
                return it, sp
        return None
    cooking_for_alt = next(s["item"] for s in sightings if s["kind"] == "vendor" and abilities[str(s["recipe"])]["SkillLine"] == "185"
                           and str(s["recipe"]) not in known and s["item"] != 6326 and bucket(str(s["recipe"]), 56) == "red")
    taken.add(teaches[str(cooking_for_alt)])
    vendor_seen = {str(s["recipe"]) for s in sightings if s["kind"] == "vendor"}
    showcase_spec = [
        ("known", pick(lambda sp: sp in known)),
        ("known_bags", pick(lambda sp: sp in known)),
        ("optimal", pick(lambda sp: sp not in known and bucket(sp, 56) == "optimal")),
        ("medium", pick(lambda sp: sp not in known and bucket(sp, 56) == "medium")),
        ("easy", pick(lambda sp: sp not in known and bucket(sp, 56) in ("easy", "trivial"))),
        # Seen at a real vendor too, so the notebook lists it with both possession icons (Ikar's bags, Elorah's bank).
        ("learnable_bags", pick(lambda sp: sp not in known and bucket(sp, 56) in ("optimal", "medium") and sp in vendor_seen)
         or pick(lambda sp: sp not in known and bucket(sp, 56) in ("optimal", "medium"))),
        ("toolow", pick(lambda sp: sp not in known and bucket(sp, 56) == "red")),
        ("toolow_alt", (cooking_for_alt, teaches[str(cooking_for_alt)])),
    ]
    showcase_spec = [(case, p) for case, p in showcase_spec if p]
    for _, (it, sp) in showcase_spec:
        used_recipes.add(sp)
    print("  showcase:", [(case, spell_name.get(sp)) for case, (it, sp) in showcase_spec])

    # What each recipe makes (SpellEffect 24, create item); enchantments make none.
    makes = {}
    for r in read_csv("SpellEffect.csv"):
        if r["Effect"] == "24" and r["SpellID"] in used_recipes and r["EffectItemType"] not in ("", "0"):
            makes.setdefault(r["SpellID"], int(r["EffectItemType"]))

    # Everything the bench names: recipes, their reagents, recipe items, what they make.
    recipes = {}
    item_ids = set()
    for sp in used_recipes:
        a = abilities.get(sp, {})
        rg = reagents.get(sp, [])
        item_ids.update(i for i, _ in rg)
        it = taught_by_item.get(sp)
        if it:
            item_ids.add(int(it))
        if sp in makes:
            item_ids.add(makes[sp])
        recipes[sp] = {"name": spell_name.get(sp, f"#{sp}"), "skill": a.get("SkillLine"), "makes": makes.get(sp),
                       "min": required(sp) if a else 0, "minEstimated": sp not in taught_by_item,
                       "yellow": int(a.get("TrivialSkillLineRankLow") or 0), "gray": int(a.get("TrivialSkillLineRankHigh") or 0),
                       "reagents": rg, "item": int(it) if it else None, "cat": category_of(a)}
    for s in sightings:
        if s.get("item"):
            item_ids.add(s["item"])

    # Bags: the reagents most recipes share, plus the looted recipe.
    use_count = {}
    for sp in used_recipes:
        for i, _ in reagents.get(sp, []):
            use_count[i] = use_count.get(i, 0) + 1
    bag = [i for i, _ in sorted(use_count.items(), key=lambda p: (-p[1], p[0]))[:14]]
    bag += [s["item"] for s in sightings if s["kind"] == "drop"]

    items = {}
    for i in sorted(item_ids):
        sp = sparse.get(str(i), {})
        items[i] = {"name": sp.get("Display_lang") or f"#{i}", "quality": int(sp.get("OverallQualityID") or 1),
                    "icon": items_db2.get(str(i), {}).get("IconFileDataID"), "sell": int(sp.get("SellPrice") or 0),
                    "buy": int(sp.get("BuyPrice") or 0), "class": int(items_db2.get(str(i), {}).get("ClassID") or 0),
                    "subclass": int(items_db2.get(str(i), {}).get("SubclassID") or 0),
                    "slot": int(items_db2.get(str(i), {}).get("InventoryType") or 0),
                    "stack": int(sp.get("Stackable") or 1)}

    npcs = {}
    for s in sightings:
        n = s.get("npc")
        if n and n not in npcs:
            info = npc_info(n)
            npcs[n] = {"name": info["name"], "title": info["title"]}

    profs = {sk: {"name": skill_name.get(sk, sk), "icon": skill_icon.get(sk)} for sk in PROFESSIONS}

    # Icons and map tiles.
    icon_ids = {v["icon"] for v in items.values() if v["icon"]} | {p["icon"] for p in profs.values() if p["icon"]}
    for fdid in sorted(icon_ids):
        png = ART / "icons" / f"{fdid}.png"
        if not png.exists():
            try:
                w, h, rgba = decode_blp(fetch(CASC.format(fdid), CACHE / f"{fdid}.blp"))
                write_png(png, w, h, rgba)
            except Exception as e:
                print("  icon", fdid, e)
    maps = {}
    tiles = [r for r in read_csv("UiMapArtTile.csv") if r["LayerIndex"] == "0"]
    for zone, (uimap, art) in MAPS.items():
        mine = [r for r in tiles if r["UiMapArtID"] == art]
        for r in mine:
            png = ART / "map" / f"{r['FileDataID']}.png"
            if not png.exists():
                w, h, rgba = decode_blp(fetch(CASC.format(r["FileDataID"]), CACHE / f"{r['FileDataID']}.blp"))
                write_png(png, w, h, rgba)
        maps[zone] = {"uiMap": uimap, "name": place_name(zone),
                      "tiles": [[int(r["RowIndex"]), int(r["ColIndex"]), r["FileDataID"]] for r in mine]}

    zones = {z: place_name(z) for z in VISITED}
    # Categories used by the bench's recipes, with the game's order. A recipe outside the profession's own tree
    # (none, or Season of Discovery's) gets none: the bench files it under the game's « Divers » (MISCELLANEOUS).
    categories = {}
    for r in recipes.values():
        if r["cat"]:
            c = categories_db2[str(r["cat"])]
            categories[r["cat"]] = {"name": c["Name_lang"], "order": int(c["OrderIndex"] or 0)}
    atlases = atlas_table(ATLASES)

    # Invented: the auction house's Recipes page on Ikar's last visit. The three AH-only recipes, and resold vendor
    # recipes, some listed twice so a lowest price stands out.
    ah_items = [(s["item"], s["recipe"]) for s in sightings if s["kind"] == "ah"]
    # Two recipes Ikar knows are resold too, so the "known" marker shows on the auction house.
    resold = list(dict.fromkeys((s["item"], s["recipe"]) for s in sightings if s["kind"] == "vendor" and str(s["recipe"]) in known))[:2]
    for s in sightings:
        if s["kind"] == "vendor" and (s["item"], s["recipe"]) not in resold and len(resold) < 8:
            resold.append((s["item"], s["recipe"]))
    listings = []
    for k, (item, spell) in enumerate(ah_items + resold):
        base = next((s["price"] for s in sightings if s["kind"] == "ah" and s["item"] == item), None) or max(80, items.get(item, {}).get("buy", 100) * 3)
        listings.append({"item": item, "recipe": int(spell), "price": base, "qty": 1 + k % 3})
        if k % 2 == 0:
            listings.append({"item": item, "recipe": int(spell), "price": int(base * 1.35), "qty": 1})
    # Invented inventories: Ikar Rahl carries what was looted; Elorah keeps an auction pattern in her bank and a cooking
    # recipe in her bags, which Ikar could learn: the "on another character" case.
    looted = [s["item"] for s in sightings if s["kind"] == "drop"]
    in_ikar_bags = [int(it) for case, (it, sp) in showcase_spec if case in ("known_bags", "learnable_bags")]
    camp = lambda sp: CATEGORY_PARENTS.get(abilities.get(sp, {}).get("TradeSkillCategoryID", "0"), "0") != "0" and         categories_db2[abilities[sp]["TradeSkillCategoryID"]]["Name_lang"] == "Campement"
    known_make = next(makes[sp] for sp in sorted(known) if sp in makes and abilities.get(sp, {}).get("SkillLine") == "185" and not camp(sp))
    alt_make = next(makes[sp] for sp in alt_known if sp in makes and abilities[sp]["SkillLine"] == "186" and not camp(sp))
    seen_make = next(makes[str(s["recipe"])] for s in sightings if str(s["recipe"]) in makes and str(s["recipe"]) not in known
                     and abilities[str(s["recipe"])]["SkillLine"] == "185")
    crafted = {known_make: 4, alt_make: 6, seen_make: 2}
    print("  crafted in Ikar's bags:", crafted)
    holdings = {
        "main": {"bags": {**{i: 2 + (i % 17) for i in bag if i not in looted}, **{i: 1 for i in looted + in_ikar_bags}, **crafted}, "bank": {}},
        # The learnable recipe in Ikar's bags has a twin in Elorah's bank: the "held by both" case.
        "alt": {"bags": {cooking_for_alt: 1}, "bank": {ah_items[-1][0]: 1, **{int(it): 1 for case, (it, sp) in showcase_spec if case == "learnable_bags"}}},
    }
    # The showcase's last two slots: another profession's pattern Elorah keeps in her bank, and one nobody holds.
    other_plain = next(s for s in sightings if s["kind"] == "vendor" and abilities[str(s["recipe"])]["SkillLine"] not in ("185", "333"))
    showcase = [{"item": int(it), "recipe": int(sp), "case": case} for case, (it, sp) in showcase_spec]
    showcase += [{"item": ah_items[-1][0], "recipe": int(ah_items[-1][1]), "case": "other_alt"},
                 {"item": other_plain["item"], "recipe": other_plain["recipe"], "case": "other"}]
    for i in (cooking_for_alt, ah_items[-1][0]):
        if i not in items:
            sp_ = sparse.get(str(i), {})
            items[i] = {"name": sp_.get("Display_lang"), "quality": int(sp_.get("OverallQualityID") or 1), "icon": items_db2.get(str(i), {}).get("IconFileDataID"),
                        "sell": int(sp_.get("SellPrice") or 0), "buy": int(sp_.get("BuyPrice") or 0), "class": 9, "subclass": 0, "slot": 0}
    # The game's font and Ikar's world screenshots, from KaLi Quest's bench (local only: they show names).
    (ART / "world").mkdir(exist_ok=True)
    for src in [QUEST / "bench/art/FRIZQT__.TTF", *sorted((QUEST / "bench/art/world").glob("*.jpg"))]:
        dest = ART / ("world" if src.suffix == ".jpg" else "") / src.name
        if src.exists() and not dest.exists():
            dest.write_bytes(src.read_bytes())
    # The classic skill bar: UI-Character-Skills-Bar and UI-Character-Skills-BarBorder.
    for name, fdid in (("skills-bar", 136570), ("skills-barborder", 136571)):
        png = ART / f"{name}.png"
        if not png.exists():
            w, h, rgba = decode_blp(fetch(CASC.format(fdid), CACHE / f"{fdid}.blp"))
            write_png(png, w, h, rgba)
    # Morpheus, the font of quest titles on parchment (QuestFont_30 and kin), for the paper styles of the notebook.
    if not (ART / "MORPHEUS.TTF").exists():
        fetch(CASC.format(615962), ART / "MORPHEUS.TTF")
    data = {
        "atlases": atlases,
        "character": {k: v for k, v in CHARACTER.items() if k != "known_names"} | {"known": sorted(int(s) for s in known)},
        "alt": ALT | {"known": [int(s) for s in alt_known]},
        "professions": profs, "recipes": recipes, "categories": categories, "items": items, "npcs": npcs, "zones": zones,
        "maps": maps, "sightings": sightings, "bag": bag, "holdings": holdings, "showcase": showcase,
        "ah": {"date": "2026-11-07", "listings": listings},
    }
    out = BENCH / "js/data.js"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("// Generated by recipe/tools/bench_data.py. Don't edit.\n"
                   "// Real: names, reagents, ranks, vendors and their places, icons, map. Invented: what was seen\n"
                   "// where and when, auction prices, the second character (Elorah).\n"
                   "window.BENCH_DATA = " + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + ";\n",
                   encoding="utf-8", newline="\n")
    kinds = {}
    for s in sightings:
        kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
    print(f"recipes {len(recipes)}, items {len(items)}, npcs {len(npcs)}, sightings {kinds}, known {len(known)}, icons {len(icon_ids)}")


if __name__ == "__main__":
    main()
