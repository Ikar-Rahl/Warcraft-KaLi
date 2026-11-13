"""Build the test bench's art from Blizzard's files for this client build.

Downloads only the textures the bench draws, decodes them from BLP to PNG, and writes
quest/bench/js/atlas-data.js. Everything it fetches is cached, so a re-run is quick.

Run with: python -I quest/tools/bench_art.py
Needs the atlas tables in the reference copies' db2/<build>/ (UiTextureAtlas.csv, UiTextureAtlasMember.csv).
"""
import csv
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.art import BUILD, CASC, decode_blp, fetch, write_png  # noqa: E402
from kali.paths import GAME, QUEST, REFERENCE  # noqa: E402

DB2 = REFERENCE / "db2" / BUILD
OUT = QUEST / "bench/art"
CACHE = OUT / "_cache"
JS_OUT = QUEST / "bench/js/atlas-data.js"
sys.stdout.reconfigure(encoding="utf-8")

RAW = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/live/"

ATLASES = """
ui-questtracker-primary-objective-header ui-questtracker-secondary-objective-header
ui-questtrackerbutton-collapse-all ui-questtrackerbutton-collapse-all-pressed
ui-questtrackerbutton-expand-all ui-questtrackerbutton-expand-all-pressed
ui-questtrackerbutton-secondary-collapse ui-questtrackerbutton-secondary-collapse-pressed
ui-questtrackerbutton-secondary-expand ui-questtrackerbutton-secondary-expand-pressed
gamepad-hud-icon-filter
ui-questtrackerbutton-red-highlight ui-questtrackerbutton-yellow-highlight
ui-questtracker-tracker-check ui-questtracker-tracker-check-glow
ui-questtracker-objfx-barglow ui-questtracker-objfx-shine
ui-questtrackerbutton-questitem-frame ui-questtrackerbutton-questitem-frame-glow
ui-questtracker-objective-nub ui-questtracker-objective-fail
ui-questpoi-questnumber ui-questpoi-questnumber-supertracked
ui-questpoi-questnumber-pressed ui-questpoi-questnumber-pressed-supertracked
ui-questpoi-innerglow ui-questpoi-outerglow
quest-in-progress-icon-yellow quest-in-progress-icon-brown ui-questicon-turnin-normal
ui-questpoilegendary-questnumber ui-questpoilegendary-questbangturnin
questlog-questtypeicon-clockyellow questlog-questtypeicon-group questlog-questtypeicon-dungeon
questlog-questtypeicon-raid questlog-questtypeicon-pvp questlog-questtypeicon-daily
questlog-questtypeicon-weekly questlog-questtypeicon-legendary questlog-questtypeicon-class
questlog-questtypeicon-lock questlog-questtypeicon-questfailed
questrepeatableturnin poi-traveldirections-arrow
socialqueuing-icon-group socialqueuing-icon-eye questsharing-questlog-button
common-search-magnifyingglass common-search-clearbutton
autoquest-badgeborder
minimal-scrollbar-track-top minimal-scrollbar-track-bottom !minimal-scrollbar-track-middle
minimal-scrollbar-small-thumb-top minimal-scrollbar-small-thumb-middle minimal-scrollbar-small-thumb-bottom
minimal-scrollbar-small-thumb-top-over minimal-scrollbar-small-thumb-middle-over minimal-scrollbar-small-thumb-bottom-over
minimal-scrollbar-small-thumb-top-down minimal-scrollbar-small-thumb-middle-down minimal-scrollbar-small-thumb-bottom-down
minimal-scrollbar-arrow-top minimal-scrollbar-arrow-top-over minimal-scrollbar-arrow-top-down
minimal-scrollbar-arrow-bottom minimal-scrollbar-arrow-bottom-over minimal-scrollbar-arrow-bottom-down
common-dropdown-bg
questlog-icon-ticksquare
common-icon-undo options_horizontaldivider
communities-icon-lock gm-icon-visible covenantsanctum-renown-doublearrow
questlog-icon-setting waypoint-mappin-minimap-untracked
ui-hud-nameplates-levelindicator questnormal
waypoint-mappin-chaticon waypoint-mappin-untracked ui-hud-minimap-arrow-player playerpartyblip questblob
""".split() + """
Ping_Marker_Icon_Assist Ping_Marker_Icon_Attack Ping_Marker_Icon_NonThreat Ping_Marker_Icon_OnMyWay Ping_Marker_Icon_Threat Ping_Marker_Icon_Warning
Ping_Chat_Assist Ping_Chat_NonThreat Ping_Chat_OnMyWay Ping_Chat_Warning Ping_Map_NonThreat Ping_Map_OnMyWay Ping_Map_Assist
Ping_MapPin_NonThreat Ping_MapPin_OnMyWay Ping_MapPin_Assist Ping_Wheel_Icon_OnMyWay_Small Ping_Wheel_Icon_Assist_Small
Navigation-Tracked-Icon Navigation-Tombstone-Icon Target Target-Tracker DungeonTargetIndicator Adventures-Target-Indicator
Islands-MarkedArea QuestObjective TaskPOI-Icon TaskPOI-IconSelect Bonus-Objective-Star Rare-Elite-Star
LevelUp-Dot-Gold LevelUp-Dot-Green PlayerRaidBlip WhiteCircle-RaidBlips WhiteDotCircle-RaidBlips Warfront-AllianceDot Warfront-HordeDot
perks-radio-dot plunderstorm-new-dot-sm plunderstorm-new-dot-lg groupfinder-waitdot lootroll-pendingdot UI-Taxi-Icon-Nub Objective-Nub
AftLevelup-Dots1 UI-prey-Pip-Green common-dropdown-icon-radialtick-yellow common-dropdown-tickradial
GM-raidMarker1 GM-raidMarker2 GM-raidMarker3 GM-raidMarker4 GM-raidMarker5 GM-raidMarker6 GM-raidMarker7 GM-raidMarker8
poi-town poi-majorcity poi-door poi-lighthouse-neutral poi-rift1 poi-graveyard-neutral TaxiNode_Undiscovered taxinode_neutral
map-icon-SuramarDoor.tga ChromieMap Map-MarkedDefeated legioninvasion-map-icon-portal lorewalking-map-icon homestone-minimap-icon
housing-map-plot-player-house housing-map-plot-occupied-friend housing-map-plot-unoccupied UI-EventPoi-Cave UI-EventPoi-Horn-big
minimap-genericevent-hornicon-small trading-post-minimap-icon
friends-icon-pinned friendslist-recentallies-Pin friendslist-recentallies-Pin-yellow Waypoint-MapPin-Tracked Waypoint-MapPin-Minimap-Tracked
worldquest-tracker-questmarker worldquest-tracker-questmarker-gray worldquest-questmarker-rare Recurringactivequesticon AdventureMapIcon-Quest
VignetteLoot VignetteEventElite
delves-scenario-flag housing-dashboard-activity-listitem-flag CrossedFlags nameplates-icon-flag-neutral nameplates-icon-flag-alliance
tradeskills-star recipetoast-icon-star currency-star-shine CampCollection-icon-star wowlabs_spellbucketicon-stars
activities-incomplete-diamond activities-complete-diamond DruidEclipse-Diamond UF-Arcane-MagicDiamond
Adventurers-Followers-Uncommon-Gem Adventurers-Followers-Rare-Gem Adventurers-Followers-Epic-Gem Adventurers-Followers-Legendary-Gem
gearUpdate-arrow-bullet-point interstitial-newplayerexperience-upgrade-bullet timerunning-infographic-bullet
nameplates-icon-orb-blue nameplates-icon-orb-green nameplates-icon-orb-orange nameplates-icon-orb-purple MonkUI-LightOrb-small UF-Arcane-Orb
DruidEclipse-SolarSun DruidEclipse-LunarSun UI-prey-Scoutingmap-ring worldquest-tracker-ring shop-count-ring Relic-Rankselected-circle
PortalBlue PortalPurple shop-games-magnifyingglass hearthsteel-icon-16x16 poi-soulspiritghost
""".split()  # area-mark.html's second round of candidates for the area mark (Ikar, 2026-11-12: "find other icons")

# Files outside the atlas tables. The font comes from the build itself, the rest from a mirror.
FONTS = {"FRIZQT__.TTF": 615960}
STANDALONE = {
    "AutoQuest-Parts.png": "QUESTFRAME/AutoQuest-Parts.PNG",
    "AutoQuestToastBorder-LeftRight.png": "QUESTFRAME/AutoQuestToastBorder-LeftRight.PNG",
    "AutoQuestToastBorder-TopBot.png": "QUESTFRAME/AutoQuestToastBorder-TopBot.PNG",
    "UI-SquareButton-Up.png": "Buttons/UI-SquareButton-Up.PNG",
    "UI-SquareButton-Down.png": "Buttons/UI-SquareButton-Down.PNG",
    "ButtonHilight-Square.png": "Buttons/ButtonHilight-Square.PNG",
    # Quest item icons for the fake log.
    "icon-candle.png": "ICONS/INV_Misc_Candle_02.PNG",
    "icon-bag.png": "ICONS/INV_Misc_Bag_07.PNG",
    "icon-note.png": "ICONS/INV_Letter_15.PNG",
    "icon-potion.png": "ICONS/INV_Potion_54.PNG",
    # Icons Ikar's other addons name in their TOCs, beside ours on icons.html.
    "icon-map.png": "ICONS/INV_Misc_Map_01.PNG",
    "icon-question.png": "ICONS/INV_Misc_QuestionMark.PNG",
    "icon-book.png": "ICONS/INV_Misc_Book_09.PNG",
    "icon-zone.png": "ICONS/Achievement_Zone_EasternKingdoms_01.PNG",
    "icon-dragon.png": "ICONS/INV_Misc_Head_Dragon_01.PNG",
}

# Forever Quest Tint's marker, read from the installed addon: its crop and default tint.
INFINITY = GAME / "Interface/AddOns/ForeverQuestTint/Media/Infinity.tga"
INFINITY_CROP = (1, 63, 12, 51)
INFINITY_TINT = (0.60, 0.90, 0.95)


def write_infinity(dest):
    """An uncompressed 32-bit TGA, cropped and tinted as the addon draws it."""
    blob = INFINITY.read_bytes()
    w, h = struct.unpack_from("<HH", blob, 12)
    start = 18 + blob[0]
    top_down = blob[17] & 0x20
    left, right, top, bottom = INFINITY_CROP
    out = bytearray()
    for y in range(top, bottom):
        row = y if top_down else h - 1 - y
        for x in range(left, right):
            b, g, r, a = blob[start + (row * w + x) * 4:start + (row * w + x) * 4 + 4]
            out += bytes((int(r * INFINITY_TINT[0]), int(g * INFINITY_TINT[1]), int(b * INFINITY_TINT[2]), a))
    write_png(dest, right - left, bottom - top, bytes(out))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    JS_OUT.parent.mkdir(parents=True, exist_ok=True)

    with open(DB2 / "UiTextureAtlas.csv", encoding="utf-8", newline="") as f:
        sheets = {r["ID"]: r for r in csv.DictReader(f)}
    wanted = {name.lower() for name in ATLASES}
    # An atlas name belongs to an element. Each element has one member per sheet: 1x, 2x, and Forever's set.
    with open(DB2 / "UiTextureAtlasElement.csv", encoding="utf-8", newline="") as f:
        element_name = {r["ID"]: r["Name"].lower() for r in csv.DictReader(f) if r["Name"].lower() in wanted}
    members = {}
    with open(DB2 / "UiTextureAtlasMember.csv", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            name = element_name.get(r["UiTextureAtlasElementID"])
            if name:
                members.setdefault(name, []).append(r)

    missing = sorted(wanted - set(members))
    if missing:
        print("No atlas row for:", ", ".join(missing))

    # Per atlas and art set, keep the sharpest sheet. Logical size comes from the 1x row when there is one.
    table = {}
    used = {}
    for name, rows in sorted(members.items()):
        by_set = {}
        for r in rows:
            sheet = sheets.get(r["UiTextureAtlasID"])
            if not sheet:
                continue
            set_id = sheet["UiTextureAtlasSetID"]
            by_set.setdefault(set_id, []).append((r, sheet))
        entry = {}
        for set_id, pairs in by_set.items():
            pairs.sort(key=lambda p: int(p[1]["UiCanvasID"]) or 1)
            one_x, best = pairs[0], pairs[-1]
            r, sheet = best
            canvas = int(sheet["UiCanvasID"]) or 1
            base_canvas = int(one_x[1]["UiCanvasID"]) or 1
            fdid = sheet["FileDataID"]
            used[fdid] = (int(sheet["AtlasWidth"]), int(sheet["AtlasHeight"]))
            entry[set_id] = {
                "f": fdid,
                "sw": int(sheet["AtlasWidth"]), "sh": int(sheet["AtlasHeight"]),
                "x": int(r["CommittedLeft"]), "y": int(r["CommittedTop"]),
                "pw": int(r["CommittedRight"]) - int(r["CommittedLeft"]),
                "ph": int(r["CommittedBottom"]) - int(r["CommittedTop"]),
                "w": int(one_x[0]["Width"]) // base_canvas, "h": int(one_x[0]["Height"]) // base_canvas,
            }
        if entry:
            table[name] = entry

    for fdid, (aw, ah) in sorted(used.items()):
        png = OUT / f"sheet-{fdid}.png"
        if png.exists():
            continue
        blob = fetch(CASC.format(fdid), CACHE / f"{fdid}.blp")
        w, h, rgba = decode_blp(blob)
        write_png(png, w, h, rgba)
        print(f"sheet {fdid}: {w}x{h} (table says {aw}x{ah}), {png.stat().st_size // 1024} KB")

    for png in OUT.glob("sheet-*.png"):
        if png.stem.removeprefix("sheet-") not in used:
            png.unlink()

    for name, fdid in FONTS.items():
        fetch(CASC.format(fdid), OUT / name)
        print("font", name)

    for name, path in STANDALONE.items():
        dest = OUT / name
        if not dest.exists():
            fetch(RAW + path, dest)
            print("file", name)

    write_infinity(OUT / "addon-infinity.png")

    JS_OUT.write_text(
        "// Generated by quest/tools/bench_art.py. Don't edit.\n"
        f"// Build {BUILD}. Art sets: '0' is the default set, '1' holds Forever's c60 textures.\n"
        "window.ATLAS_DATA = " + json.dumps(table, separators=(",", ":")) + ";\n",
        encoding="utf-8", newline="\n",
    )
    print(len(table), "atlases written to", JS_OUT)


if __name__ == "__main__":
    main()
