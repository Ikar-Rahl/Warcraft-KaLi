"""Write KaLi Recipe's Data/Recipes.lua from the game's own tables (the reference copies' db2), numbers only.

The game has no function that says which recipe a recipe item teaches, nor a trainer recipe's reagents for a
profession the character lacks, so the addon carries the game's own links between them:

- RECIPE_ITEMS[item] = the recipe spell it teaches (ItemXItemEffect, trigger 6 "learn"; the learning spell skipped);
- RECIPES[spell] = { skill line, required rank, yellow, gray, category, product, reagent, count, reagent, count, ... }:
  SkillLineAbility (skill line, thresholds, category), the required rank: ItemSparse.RequiredSkillRank of the recipe
  item that teaches it, else SkillLineAbility.MinSkillLineRank when the game teaches the recipe on its own at that
  rank (AcquireMethod 1) or the column holds a rank (above 1; it's 1 on most rows), else 0: a trainer gives that rank,
  GetTrainerServiceSkillReq; SpellEffect 24 (create item), SpellReagents;
- CATEGORIES[category] = { parent, order, skill line } and CATEGORY_NAMES[locale][category], for the categories
  the professions window shows (TradeSkillCategory).

None of it is ever shown for a recipe the player hasn't met: the addon reads it only for recipes it has seen, known
or held (Ikar's ruling of 2026-11-09, "no built-in list": nothing never met can show).

Run with: python -I recipe/tools/gen_addon_data.py. Re-run after a patch.
"""
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import RECIPE, REFERENCE  # noqa: E402

DB2 = max((REFERENCE / "db2").iterdir())
OUT = RECIPE / "addon/KaLiRecipe/Data/Recipes.lua"

LEARNING_SPELLS = {"483", "402265"}
# Every profession that has recipes on Forever, gathering ones included (smelting, « Campement »).
SKILL_LINES = {"171", "164", "185", "333", "202", "129", "356", "182", "165", "186", "393", "197"}
# The client languages the addon speaks; every other falls back to enUS. The German and Spanish tables came from
# wago.tools with &locale= on 2026-11-13, as the French ones before.
LOCALES = {"frFR": "TradeSkillCategory.frFR.csv", "enUS": "TradeSkillCategory.csv", "deDE": "TradeSkillCategory.deDE.csv",
           "esES": "TradeSkillCategory.esES.csv", "esMX": "TradeSkillCategory.esMX.csv"}
# No English SkillLine table is on disk: the English names, for other clients' fallback.
ENGLISH = {"171": "Alchemy", "164": "Blacksmithing", "185": "Cooking", "333": "Enchanting", "202": "Engineering",
           "129": "First Aid", "356": "Fishing", "182": "Herbalism", "165": "Leatherworking", "186": "Mining",
           "393": "Skinning", "197": "Tailoring"}


def read_csv(name):
    with open(DB2 / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    items = {r["ID"]: r for r in read_csv("Item.csv")}
    sparse = {r["ID"]: r for r in read_csv("ItemSparse.frFR.csv")}
    effects = {r["ID"]: r for r in read_csv("ItemEffect.csv")}

    abilities = {}
    for r in read_csv("SkillLineAbility.csv"):
        if r["SkillLine"] in SKILL_LINES:
            abilities.setdefault(r["Spell"], r)
    reagents = {}
    for r in read_csv("SpellReagents.csv"):
        pairs = [(int(r[f"Reagent_{i}"]), int(r[f"ReagentCount_{i}"] or 1)) for i in range(8)
                 if r.get(f"Reagent_{i}", "0") not in ("", "0")]
        if pairs:
            reagents[r["SpellID"]] = pairs
    makes = {}
    for r in read_csv("SpellEffect.csv"):
        if r["Effect"] == "24" and r["EffectItemType"] not in ("", "0"):
            makes.setdefault(r["SpellID"], int(r["EffectItemType"]))

    # A recipe is an ability of a profession that uses reagents or makes an item: gathering spells, ranks and
    # passive skills do neither.
    recipes = {sp: a for sp, a in abilities.items() if sp in reagents or sp in makes}

    teaches = {}
    for r in read_csv("ItemXItemEffect.csv"):
        e = effects.get(r["ItemEffectID"])
        item = items.get(r["ItemID"])
        if not e or not item or item["ClassID"] != "9" or e["TriggerType"] != "6" or e["SpellID"] in LEARNING_SPELLS:
            continue
        if e["SpellID"] in recipes:
            teaches[int(r["ItemID"])] = int(e["SpellID"])
    required = {}
    for item, sp in teaches.items():
        rank = int(sparse.get(str(item), {}).get("RequiredSkillRank") or 0)
        required[sp] = max(required.get(sp, 0), rank)
    # No recipe item: the game's own rank, for a recipe it teaches on its own at a rank (AcquireMethod 1: Forever's
    # elixirs of rank 1) or when the column holds one; a trainer's recipe has 1 there on most rows, which says nothing.
    for sp, a in recipes.items():
        low = int(a["MinSkillLineRank"] or 0)
        if not required.get(int(sp)) and (a["AcquireMethod"] == "1" and low > 0 or low > 1):
            required[int(sp)] = low

    categories = {}
    for r in read_csv("TradeSkillCategory.csv"):
        categories[r["ID"]] = (int(r["ParentTradeSkillCategoryID"] or 0), int(r["OrderIndex"] or 0), int(r["SkillLineID"] or 0))
    used = set()
    lines = [
        "-- Made by recipe/tools/gen_addon_data.py from the game's own tables, build " + DB2.name + ". Numbers only.",
        "-- Read only for recipes the player has met, known or held: nothing here is ever listed on its own.",
        "local _, ns = ...",
        "",
        f'ns.DATA_BUILD = "{DB2.name}"',
        "",
        "-- [recipe spell] = { skill line, required rank (0: a trainer's), yellow, gray, category, product, reagent, count, ... }",
        "ns.RECIPES = {",
    ]
    for sp in sorted(recipes, key=int):
        a = recipes[sp]
        cat = a.get("TradeSkillCategoryID") or "0"
        cat = int(cat) if cat in categories and categories[cat][0] != 0 else 0
        if cat:
            used.add(str(cat))
        row = [int(a["SkillLine"]), required.get(int(sp), 0), int(a["TrivialSkillLineRankLow"] or 0),
               int(a["TrivialSkillLineRankHigh"] or 0), cat, makes.get(sp, 0)]
        for item, count in reagents.get(sp, []):
            row += [item, count]
        lines.append(f"    [{sp}] = {{ {', '.join(map(str, row))} }},")
    lines += ["}", "", "-- [recipe item] = the recipe spell it teaches", "ns.RECIPE_ITEMS = {"]
    lines += [f"    [{item}] = {sp}," for item, sp in sorted(teaches.items())]
    lines += ["}", "", "-- [category] = { parent, order, skill line }: the professions window's categories, in its order", "ns.CATEGORIES = {"]
    parents = {categories[c][0] for c in used}
    for c in sorted(used | {str(p) for p in parents}, key=int):
        if c in categories:
            parent, order, skill = categories[c]
            lines.append(f"    [{c}] = {{ {parent}, {order}, {skill} }},")
    lines += ["}", "", "-- The categories' names, for when the game doesn't give them (C_TradeSkillUI.GetCategoryInfo).",
              "ns.CATEGORY_NAMES = {"]
    for locale, file in LOCALES.items():
        names = {r["ID"]: r["Name_lang"] for r in read_csv(file)}
        lines.append(f"    {locale} = {{")
        for c in sorted(used | {str(p) for p in parents}, key=int):
            if names.get(c):
                lines.append(f"        [{c}] = {lua_string(names[c])},")
        lines.append("    },")
    lines += ["}", ""]
    # Professions: icons from SkillLine, names for when the game gives none (a profession no character has).
    skill_lines = {r["ID"]: r for r in read_csv("SkillLine.frFR.csv")}
    lines += ["-- [skill line] = the profession's icon (SkillLine.SpellIconFileID)", "ns.PROFESSION_ICONS = {"]
    lines += [f"    [{s}] = {int(skill_lines[s]['SpellIconFileID'] or 0)}," for s in sorted(SKILL_LINES, key=int) if s in skill_lines]
    lines += ["}", "", "-- The professions' names, for when the game gives none.", "ns.PROFESSION_NAMES = {", "    frFR = {"]
    lines += [f"        [{s}] = {lua_string(skill_lines[s]['DisplayName_lang'])}," for s in sorted(SKILL_LINES, key=int) if s in skill_lines]
    lines += ["    },", "    enUS = {"]
    lines += [f"        [{s}] = {lua_string(ENGLISH[s])}," for s in sorted(SKILL_LINES, key=int)]
    lines += ["    },"]
    for locale in ("deDE", "esES", "esMX"):
        named = {r["ID"]: r for r in read_csv(f"SkillLine.{locale}.csv")}
        lines += [f"    {locale} = {{"]
        lines += [f"        [{s}] = {lua_string(named[s]['DisplayName_lang'])}," for s in sorted(SKILL_LINES, key=int)
                  if s in named]
        lines += ["    },"]
    lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{OUT}: {len(recipes)} recipes, {len(teaches)} recipe items, {len(used)} categories, from {DB2.name}")


sys.stdout.reconfigure(encoding="utf-8")
main()
