"""Where a fishing cast lands, for fishing's tooltip (UI/Hub/Infos/Skills.lua; Ikar 2026-11-18: "how to get the fishing
areas zones ?", then "Go for it, but don't show a line, add a question mark icon"). Writes Data/Fishing.lua.

The game's client has none of it: the server rolls each cast against an area's base skill, and no table of Forever's
(AreaTable, nor any other wago.tools lists) carries one. The bases are the original game's own data (Ikar 2026-11-22:
"theses are in game data"), kept below by area. The server's rule: a cast lands when the skill is at least the area's
base, with (skill - base + 5)% chance, so from base + 95 every one does: the "skill for the zone" fishing guides give
(Elwynn Forest 25, Stranglethorn Vale 225). A sub-zone's own base wins over its zone's.
They are Classic's, not measured on Forever: four that players of the fishing addon Pagle measured there (Wetlands,
Redridge Mountains, Tirisfal Glades, Darkshore) are the same; Forever's own zones (Mount Hyjal, Zephras Isle,
Riverglades, Shen'dralas) have none, and show a question mark.

Each area is found in Forever's AreaTable by its ID, never by a name: a zone by the zone maps the game assigns to it
(UiMapAssignment, UiMap of type 3); a sub-zone by its ID and its zone's map, the game naming it in the player's language
(C_Map.GetAreaInfo, matched with GetSubZoneText); a dungeon, which has no map on Forever, by its instance's map
(AreaTable's ContinentID, GetInstanceInfo's instance ID). Each must be found, and no map get two.

Run with: python -I hud/tools/make_fishing.py
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.art import BUILD  # noqa: E402
from kali.paths import REFERENCE  # noqa: E402

ADDON = ROOT / "hud/addon/KaLiHUD"
TARGET = ADDON / "Data/Fishing.lua"
DB2 = REFERENCE / "db2" / BUILD
# UiMap's type of a zone (Enum.UIMapType.Zone).
ZONE = "3"
# The continents a zone stands on; any other map an area's ContinentID names is an instance's.
CONTINENTS = {"0", "1"}
# Each area's base fishing skill, the original game's, by its ID in AreaTable (its name there, to read it by).
BASES = {
    1: -70,  # Dun Morogh
    8: 130,  # Swamp of Sorrows
    10: 55,  # Duskwood
    11: 55,  # Wetlands
    12: -70,  # Elwynn Forest
    14: -70,  # Durotar
    15: 130,  # Dustwallow Marsh
    16: 205,  # Azshara
    17: -20,  # The Barrens
    28: 205,  # Western Plaguelands
    33: 130,  # Stranglethorn Vale
    36: 130,  # Alterac Mountains
    38: -20,  # Loch Modan
    40: -20,  # Westfall
    41: 330,  # Deadwind Pass
    44: 55,  # Redridge Mountains
    45: 130,  # Arathi Highlands
    46: 330,  # Burning Steppes
    47: 205,  # The Hinterlands
    85: -70,  # Tirisfal Glades
    130: -20,  # Silverpine Forest
    139: 330,  # Eastern Plaguelands
    141: -70,  # Teldrassil
    148: -20,  # Darkshore
    215: -70,  # Mulgore
    267: 55,  # Hillsbrad Foothills
    297: 205,  # Jaguero Isle
    331: 55,  # Ashenvale
    357: 205,  # Feralas
    361: 205,  # Felwood
    400: 130,  # Thousand Needles
    405: 130,  # Desolace
    406: 55,  # Stonetalon Mountains
    440: 205,  # Tanaris
    490: 205,  # Un'Goro Crater
    493: 205,  # Moonglade
    618: 330,  # Winterspring
    718: -20,  # Wailing Caverns
    719: -20,  # Blackfathom Deeps
    796: 130,  # Scarlet Monastery
    1112: 330,  # Jademir Lake
    1222: 330,  # Hetaera's Clutch
    1227: 330,  # Bay of Storms
    1377: 330,  # Silithus
    1417: 205,  # Sunken Temple
    1497: -20,  # Undercity
    1519: -20,  # Stormwind City
    1537: -20,  # Ironforge
    1581: -20,  # The Deadmines
    1637: -20,  # Orgrimmar
    1638: -20,  # Thunder Bluff
    1657: -20,  # Darnassus
    1977: 330,  # Zul'Gurub
    2017: 330,  # Stratholme
    2057: 330,  # Scholomance
    2100: 205,  # Maraudon
    3140: 330,  # Scalebeard's Cave
}


def rows(table):
    path = DB2 / f"{table}.csv"
    if not path.exists():
        sys.exit(f"{path} is missing: save https://wago.tools/db2/{table}/csv?build={BUILD} there")
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def levels():
    """(zones, areas, instances): {zone map: (base, name)}, {area: (base, zone map, name, zone's name)},
    {instance map: (base, name)}."""
    areas = {r["ID"]: r for r in rows("AreaTable")}
    zone_maps = {r["ID"]: r["Name_lang"] for r in rows("UiMap") if r["Type"] == ZONE}
    maps_of = {}
    for r in rows("UiMapAssignment"):
        if r["UiMapID"] in zone_maps:
            maps_of.setdefault(r["AreaID"], set()).add(int(r["UiMapID"]))
    zones, subzones, instances = {}, {}, {}
    for area, base in sorted(BASES.items()):
        row = areas.get(str(area))
        assert row, f"the fishing area {area} isn't in {BUILD}'s AreaTable"
        name = row["AreaName_lang"]
        if str(area) in maps_of:
            for m in sorted(maps_of[str(area)]):
                assert m not in zones, f"two fishing bases for the map {m} ({name}) in {BUILD}"
                zones[m] = (base, name)
        elif row["ParentAreaID"] != "0":
            parent = areas.get(row["ParentAreaID"])
            found = sorted(maps_of.get(row["ParentAreaID"], ()))
            assert parent and len(found) == 1, f"the fishing sub-zone {area} ({name}) has no one zone map in {BUILD}"
            subzones[area] = (base, found[0], name, parent["AreaName_lang"])
        else:
            instance = int(row["ContinentID"])
            assert row["ContinentID"] not in CONTINENTS, f"the fishing zone {area} ({name}) has no map in {BUILD}"
            assert instance not in instances, f"two fishing bases for the instance {instance} ({name}) in {BUILD}"
            instances[instance] = (base, name)
    for area, (_, m, name, _) in subzones.items():
        assert m in zones, f"the fishing sub-zone {area} ({name})'s zone has no base of its own"
    return dict(sorted(zones.items())), subzones, dict(sorted(instances.items()))


def build():
    zones, subzones, instances = levels()
    lines = [
        f"-- Generated by hud/tools/make_fishing.py from the original game's fishing bases and Forever's data ({BUILD}):",
        "-- each area's base fishing skill, from which a cast can land; from base + 95 every one does. Don't edit.",
        "local _, ns = ...",
        "",
        "ns.FISHING = {",
        "    -- by the zone's map (UiMap)",
        "    zones = {",
    ]
    lines += [f"        [{m}] = {base}, -- {name}" for m, (base, name) in zones.items()]
    lines += [
        "    },",
        "    -- a sub-zone's own, by its area (AreaTable): { base, its zone's map }",
        "    areas = {",
    ]
    lines += [f"        [{a}] = {{ {base}, {m} }}, -- {name}, {zone}" for a, (base, m, name, zone) in subzones.items()]
    lines += [
        "    },",
        "    -- a dungeon's, by its instance's map (GetInstanceInfo)",
        "    instances = {",
    ]
    lines += [f"        [{i}] = {base}, -- {name}" for i, (base, name) in instances.items()]
    lines += ["    },", "}", ""]
    return "\n".join(lines), (len(zones), len(subzones), len(instances))


def main():
    text, (zones, subzones, instances) = build()
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print(f"written: Data/Fishing.lua, {zones} zone maps, {subzones} sub-zones, {instances} dungeons")


if __name__ == "__main__":
    main()
