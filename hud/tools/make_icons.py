"""The icons a folder can wear (UI/Hub/IconPicker.lua): Blizzard's own atlases, picked by hand from Forever's game data
among those drawn to be read small (Ikar 2026-11-15: "an icon library to select the folder icon", the spells' icons
too big): the minimap's tracking icons, map and quest marks, raid target markers, profession, role and tool glyphs.
In categories, each icon with its name (Ikar 2026-11-16: "can you add more? And can you classify them? On hover, a
tooltip for each one with a name"). Measures where each one's art lies in its atlas (texels over 40/255 alpha, as
UI/Hub/Buttons.lua's ART), so that every icon's art comes out at the icon size, and writes Data/Icons.lua.

Run with: python -I hud/tools/make_icons.py [--sheet <page.html>]
--sheet also writes a page of the library by category, each icon's name on hover, for a look outside the game.
"""
import csv
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.art import BUILD, CASC, decode_blp, fetch, write_png  # noqa: E402
from kali.paths import REFERENCE  # noqa: E402

HUD = ROOT / "hud"
ADDON = HUD / "addon/KaLiHUD"
CACHE = HUD / "bench/art/_cache"
DB2 = REFERENCE / "db2" / BUILD
GLOBAL_STRINGS = REFERENCE / "BlizzardInterfaceResources/Resources/GlobalStrings"
OPAQUE = 40
# The folders' own colour on a white glyph (UI/Hub/Folders.lua).
TINT = (0.95, 0.8, 0.5)
# The game's names for the classes, by token (DB2 ChrClasses' Filename): Forever's nine.
CLASSES = [("WARRIOR", "Guerrier", "Warrior"), ("PALADIN", "Paladin", "Paladin"), ("HUNTER", "Chasseur", "Hunter"),
           ("ROGUE", "Voleur", "Rogue"), ("PRIEST", "Prêtre", "Priest"), ("SHAMAN", "Chaman", "Shaman"),
           ("MAGE", "Mage", "Mage"), ("WARLOCK", "Démoniste", "Warlock"), ("DRUID", "Druide", "Druid")]

# The library in the picker's order: its categories (each named by Locale/<language>.lua's ICON_GROUP_<id>), each with
# its icons, the first the folders' own. An icon: its atlas; True for a white glyph, drawn in the folder's colour; its
# name on hover: the game's own word, a GlobalStrings key, so it comes in the player's language (and in French and
# English from this build's strings when the game lacks it), ("dotted.path", "French", "English") for a word in one of
# the game's tables, or None where the game has no word for it: each language names it in its own file,
# Locale/<language>.lua's ICON_NAMES (Ikar 2026-11-21: "each language in it own file", "About icons, yes. As much as
# possible."), which this checks against the library.
LIBRARY = [
    ("tools", [
        ("AnimCreate_Icon_Folder", True, None),
        ("AnimCreate_Icon_Template", True, None),
        ("AnimCreate_Icon_Add", True, "ADD"),
        ("uitools-icon-minus", True, None),
        ("uitools-icon-close", True, "CLOSE"),
        ("uitools-icon-checkbox", True, None),
        ("AnimCreate_Icon_Text", True, None),
        ("AnimCreate_Icon_Texture", True, None),
        ("uitools-icon-settings", True, "SETTINGS"),
        ("uitools-icon-search", True, "SEARCH"),
        ("uitools-icon-refresh", True, "REFRESH"),
        ("uitools-icon-external-window", True, None),
        ("uitools-icon-collapse-window", True, None),
        ("GM-icon-menu", True, None),
        ("GM-icon-visible", True, None),
        ("uitools-icon-chevron-left", True, None),
        ("uitools-icon-chevron-right", True, None),
        ("uitools-icon-chevron-down", True, None),
        ("uitools-icon-warning", True, None),
        ("uitools-icon-warning-fill", True, None),
        ("uitools-icon-error", True, None),
        ("uitools-icon-error-fill", True, None),
        ("GM-icon-readyCheck", True, "READY_CHECK"),
        ("GM-icon-countdown", True, "COUNTDOWN"),
    ]),
    # raid target markers in the game's order (GM-raidMarker8 is its first, the star), then the pings'
    ("markers", [
        ("GM-raidMarker8", False, "RAID_TARGET_1"), ("GM-raidMarker7", False, "RAID_TARGET_2"),
        ("GM-raidMarker6", False, "RAID_TARGET_3"), ("GM-raidMarker5", False, "RAID_TARGET_4"),
        ("GM-raidMarker4", False, "RAID_TARGET_5"), ("GM-raidMarker3", False, "RAID_TARGET_6"),
        ("GM-raidMarker2", False, "RAID_TARGET_7"), ("GM-raidMarker1", False, "RAID_TARGET_8"),
        ("Ping_Marker_Icon_Attack", False, "PING_TYPE_ATTACK"),
        ("Ping_Marker_Icon_Assist", False, "PING_TYPE_ASSIST"),
        ("Ping_Marker_Icon_OnMyWay", False, "PING_TYPE_ON_MY_WAY"),
        ("Ping_Marker_Icon_Warning", False, "PING_TYPE_WARNING"),
        ("Ping_Marker_Icon_Threat", False, "PING_TYPE_THREAT"),
        ("Ping_Marker_Icon_NonThreat", False, "PING_TYPE_NOT_THREAT"),
        ("Waypoint-MapPin-Tracked", False, "MAP_PIN"),
    ]),
    ("signs", [
        ("common-icon-checkmark", False, None),
        ("common-icon-redx", False, None),
        ("common-icon-zoomin", False, "ZOOM_IN"),
        ("common-icon-zoomout", False, "ZOOM_OUT"),
        ("common-icon-search", False, None),
        ("common-icon-undo", False, None),
        ("common-icon-rotateleft", False, "ROTATE_LEFT"),
        ("common-icon-rotateright", False, "ROTATE_RIGHT"),
        ("common-icon-backarrow", False, None),
        ("common-icon-forwardarrow", False, None),
        ("common-icon-exit", False, "EXIT"),
        ("common-icon-speak", False, None),
        ("glueannouncementpopup-icon-info", False, "INFO"),
        ("map-icon-ignored-bluequestion", False, None),
        ("map-icon-ignored-blueexclaimation", False, None),
        ("perks-warning-large", False, None),
        ("perks-infinity", False, None),
        ("transmog-icon-hidden", False, None),
    ]),
    ("symbols", [
        ("PetJournal-FavoritesIcon", False, None),
        ("bonus-objective-star", False, None),
        ("rare-elite-star", False, None),
        ("creationcatalyst-32x32", False, None),
        ("go-icon-lead-applied", False, "LEADER"),
        ("delves-scenario-heart-icon", False, None),
        ("ui-achievement-shield-1", False, None),
        ("plunderstorm-icon-trophy", False, None),
        ("communities-icon-lock", False, None),
        ("keyflameon-32x32", False, None),
        ("icon-clock", False, "TIMEMANAGER_TITLE"),
        ("chromietime-32x32", False, None),
        ("levelup-icon-book", False, None),
        ("ui-hud-unitframe-player-group-guideicon", False, "GUIDE"),
        ("delves-scenario-flag", False, None),
    ]),
    # the micro menu's, in its order
    ("menus", [
        ("UI-HUD-MicroMenu-Professions-Up", False, "TRADE_SKILLS"),
        ("UI-HUD-MicroMenu-SpecTalents-Up", False, "TALENTS"),
        ("UI-HUD-MicroMenu-SpellbookAbilities-Up", False, "SPELLBOOK"),
        ("UI-HUD-MicroMenu-Achievements-Up", False, "ACHIEVEMENTS"),
        ("UI-HUD-MicroMenu-Questlog-Up", False, "QUEST_LOG"),
        ("UI-HUD-MicroMenu-Housing-Up", False, "HOUSING_MICRO_BUTTON"),
        ("UI-HUD-MicroMenu-GuildCommunities-Up", False, "GUILD_AND_COMMUNITIES"),
        ("UI-HUD-MicroMenu-Groupfinder-Up", False, "DUNGEONS_BUTTON"),
        ("UI-HUD-MicroMenu-Collections-Up", False, "RADIAL_LABEL_COLLECTIONS"),
        ("UI-HUD-MicroMenu-AdventureGuide-Up", False, "ADVENTURE_JOURNAL"),
        ("UI-HUD-MicroMenu-Shop-Up", False, "BLIZZARD_STORE"),
        ("UI-HUD-MicroMenu-GameMenu-Up", False, "MAINMENU_BUTTON"),
    ]),
    # the minimap's tracking icons, named as its tracking menu names them, then home
    ("town", [
        ("Banker", False, "MINIMAP_TRACKING_BANKER"),
        ("Auctioneer", False, "MINIMAP_TRACKING_AUCTIONEER"),
        ("Innkeeper", False, "MINIMAP_TRACKING_INNKEEPER"),
        ("Mailbox", False, "MINIMAP_TRACKING_MAILBOX"),
        ("Repair", False, "MINIMAP_TRACKING_REPAIR"),
        ("Food", False, "MINIMAP_TRACKING_VENDOR_FOOD"),
        ("Reagents", False, "MINIMAP_TRACKING_VENDOR_REAGENT"),
        ("Profession", False, "MINIMAP_TRACKING_TRAINER_PROFESSION"),
        ("Class", False, "MINIMAP_TRACKING_TRAINER_CLASS"),
        ("StableMaster", False, "MINIMAP_TRACKING_STABLEMASTER"),
        ("Barbershop-32x32", False, "MINIMAP_TRACKING_BARBER"),
        ("poi-transmogrifier", False, "MINIMAP_TRACKING_TRANSMOGRIFIER"),
        ("poi-workorders", False, None),
        ("poi-scrapper", False, None),
        ("Focus", False, None),
        ("fruit-minimap-icon", False, None),
        ("homestone-minimap-icon", False, None),
        ("housing-icon-dashboard", False, "HOUSING_SETTINGS_LABEL"),
        ("housing-icon-catalog", False, None),
        ("poi-islands-table", False, None),
    ]),
    ("travel", [
        ("FlightMaster", False, "MINIMAP_TRACKING_FLIGHTMASTER"),
        ("TaxiNode_Neutral", False, None),
        ("TaxiNode_Alliance", False, None),
        ("TaxiNode_Horde", False, None),
        ("FlightMasterFerry", False, None),
        ("poi-town", False, None),
        ("poi-majorcity", False, None),
        ("poi-hub", False, None),
        ("poi-door", False, None),
        ("poi-rift1", False, None),
        ("UI-HUD-Minimap-Arrow-Player", False, None),
        ("UI-HUD-Minimap-Arrow-Corpse", False, "CORPSE"),
        ("MiniMap-QuestArrow", False, None),
        ("poi-traveldirections-arrow", False, None),
        ("Navigation-Tombstone-Icon", False, None),
        ("dragonriding-winds", False, None),
        ("Front-Tree-Icon", False, None),
    ]),
    ("adventure", [
        ("VignetteLoot", False, "LOOT_NOUN"),
        ("VignetteLootElite", False, None),
        ("VignetteKill", False, "MAP_LEGEND_RARE"),
        ("VignetteKillElite", False, "MAP_LEGEND_RAREELITE"),
        ("vignettekillboss", False, "BOSS"),
        ("questlog-questtypeicon-dungeon", False, "LFG_TYPE_DUNGEON"),
        ("questlog-questtypeicon-raid", False, "LFG_TYPE_RAID"),
        ("DungeonSkull", False, None),
        ("delves-regular", False, "DELVE_LABEL"),
        ("delves-bountiful", False, None),
        ("delves-scenario-treasure-available", False, None),
        ("Mobile-TreasureIcon", False, None),
        ("Mobile-BonusIcon", False, None),
        ("ui-eventpoi-horn-big", False, None),
        ("ui-eventpoi-cave", False, None),
        ("ui-eventpoi-ballons", False, None),
        ("ui-eventpoi-theatretroupe", False, None),
        ("ui-eventpoi-spreadthelight", False, None),
        ("WildBattlePet", False, "MAP_LEGEND_PETBATTLE"),
    ]),
    ("quests", [
        ("QuestNormal", False, None),
        ("QuestTurnin", False, None),
        ("QuestDaily", False, None),
        ("QuestLegendary", False, None),
        ("CampaignAvailableQuestIcon", False, "QUEST_CLASSIFICATION_CAMPAIGN"),
        ("CampaignActiveQuestIcon", False, None),
        ("questlog-questtypeicon-important", False, "QUEST_CLASSIFICATION_IMPORTANT"),
        ("questlog-questtypeicon-story", False, None),
        ("questlog-questtypeicon-group", False, "GROUP"),
        ("questlog-questtypeicon-scenario", False, "TRACKER_HEADER_SCENARIO"),
        ("questlog-questtypeicon-heroic", False, None),
        ("questlog-questtypeicon-class", False, "CLASS"),
        ("questlog-questtypeicon-account", False, "ACCOUNT_QUEST_LABEL"),
        ("questlog-questtypeicon-weekly", False, "WEEKLY"),
        ("questlog-questtypeicon-monthly", False, None),
        ("questlog-questtypeicon-recurring", False, "QUEST_CLASSIFICATION_RECURRING"),
        ("questlog-questtypeicon-clockyellow", False, None),
        ("questlog-questtypeicon-questfailed", False, None),
        ("Campaign-QuestLog-LoreBook", False, None),
    ]),
    # the crafts, the gathering, the secondary ones, then what the minimap tracks
    ("professions", [
        ("Mobile-Alchemy", False, "ALCHEMY"),
        ("Mobile-Blacksmithing", False, "BLACKSMITHING"),
        ("worldquest-icon-enchanting", False, "ENCHANTING"),
        ("Mobile-Enginnering", False, "ENGINEERING"),
        ("Mobile-Inscription", False, "INSCRIPTION"),
        ("Mobile-Jewelcrafting", False, "JEWELCRAFTING"),
        ("Mobile-Leatherworking", False, "LEATHERWORKING"),
        ("Mobile-Tailoring", False, "TAILORING"),
        ("Mobile-Herbalism", False, "HERBALISM"),
        ("Mobile-Mining", False, "MINING"),
        ("Mobile-Skinning", False, "SKINNING"),
        ("Mobile-Cooking", False, "COOKING"),
        ("Mobile-FirstAid", False, "FIRST_AID"),
        ("Mobile-Fishing", False, "FISHING"),
        ("Mobile-Archeology", False, "PROFESSIONS_ARCHAEOLOGY"),
        ("professions_tracking_herb", False, None),
        ("professions_tracking_ore", False, None),
        ("professions_tracking_fish", False, None),
        ("professions-crafting-orders-icon", False, "PROFESSIONS_CRAFTING_ORDERS_TAB_NAME"),
    ]),
    ("classes", [(f"classicon-{token.lower()}", False, (f"LOCALIZED_CLASS_NAMES_MALE.{token}", fr, en))
                 for token, fr, en in CLASSES]),
    ("combat", [
        ("combat_swords-icon", False, None),
        ("skull_bones-icon", False, None),
        ("go-icon-role-header-tank", False, "TANK"),
        ("go-icon-role-header-healer", False, "HEALER"),
        ("go-icon-role-header-dps", False, "DAMAGER"),
        ("GM-icon-difficulty-normal", False, "PLAYER_DIFFICULTY1"),
        ("GM-icon-difficulty-heroic", False, "PLAYER_DIFFICULTY2"),
        ("GM-icon-difficulty-mythic", False, "PLAYER_DIFFICULTY6"),
        ("nameplates-icon-elite-gold", False, "ELITE"),
        ("nameplates-icon-elite-silver", False, None),
        ("Mobile-MechanicIcon-Lethal", False, None),
        ("Mobile-MechanicIcon-Powerful", False, None),
        ("Mobile-MechanicIcon-Curse", False, None),
        ("Mobile-MechanicIcon-Slowing", False, None),
        ("Mobile-MechanicIcon-Disorienting", False, None),
        ("honorsystem-icon-bonus", False, "HONOR"),
        ("CrossedFlags", False, None),
        ("questlog-questtypeicon-alliance", False, "FACTION_ALLIANCE"),
        ("questlog-questtypeicon-horde", False, "FACTION_HORDE"),
        ("poi-alliance", False, None),
        ("poi-horde", False, None),
    ]),
    # coins and bags, the bags' filters, the loot rolls
    ("wealth", [
        ("auctionhouse-icon-coin-gold", False, None),
        ("auctionhouse-icon-coin-silver", False, None),
        ("auctionhouse-icon-coin-copper", False, None),
        ("bag-main", False, "BAG_NAME_BACKPACK"),
        ("levelup-icon-bag", False, None),
        ("bags-icon-equipment", False, "BAG_FILTER_EQUIPMENT"),
        ("bags-icon-consumables", False, "BAG_FILTER_CONSUMABLES"),
        ("bags-icon-profession-goods", False, "BAG_FILTER_PROFESSION_GOODS"),
        ("bags-icon-reagents", False, "BAG_FILTER_REAGENTS"),
        ("bags-icon-tradegoods", False, "AUCTION_CATEGORY_TRADE_GOODS"),
        ("bags-icon-questitem", False, "BAG_FILTER_QUEST_ITEMS"),
        ("bags-icon-junk", False, "BAG_FILTER_JUNK"),
        ("lootroll-toast-icon-need-up", False, "NEED"),
        ("lootroll-toast-icon-greed-up", False, "GREED"),
        ("lootroll-toast-icon-pass-up", False, "PASS"),
        ("lootroll-toast-icon-disenchant-up", False, "ROLL_DISENCHANT"),
        ("lootroll-toast-icon-transmog-up", False, None),
        ("Perks-ShoppingCart", False, None),
    ]),
    # friends and groups, their statuses, chat and voice
    ("company", [
        ("ui-hud-unitframe-player-group-friendonlineicon", False, None),
        ("friends-icon-tab-friends", False, "FRIENDS"),
        ("friends-icon-addFriend", False, "ADD_FRIEND"),
        ("friends-icon-tab-guildmates", False, "GUILD"),
        ("friends-icon-tab-raid", False, "RAID"),
        ("friends-icon-tab-quickJoin", False, "QUICK_JOIN"),
        ("GM-icon-headcount", False, None),
        ("friends-icon-raidLead", False, "RAID_LEADER"),
        ("friends-icon-raidAssist", False, "RAID_ASSISTANT"),
        ("friends-status-online", False, "FRIENDS_LIST_ONLINE"),
        ("friends-status-away", False, "FRIENDS_LIST_AWAY"),
        ("friends-status-busy", False, "FRIENDS_LIST_BUSY"),
        ("friends-status-offline", False, "FRIENDS_LIST_OFFLINE"),
        ("common-icon-chatlink", False, None),
        ("chatframe-button-icon-voicechat", False, "CHAT_VOICE"),
        ("chatframe-button-icon-speaker-on", False, None),
        ("chatframe-button-icon-mic-on", False, None),
        ("chatframe-button-icon-headset", False, None),
        ("voicechat-icon-headphone-on", False, None),
        ("chatframe-button-icon-TTS", False, "TEXT_TO_SPEECH"),
    ]),
]


def read(name):
    with open(DB2 / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def atlases():
    """Each element (what SetAtlas takes) by its lower-case name: its own name and its members, every resolution."""
    files = {r["ID"]: int(r["FileDataID"]) for r in read("UiTextureAtlas.csv")}
    elements = {r["ID"]: {"name": r["Name"], "members": []} for r in read("UiTextureAtlasElement.csv")}
    for r in read("UiTextureAtlasMember.csv"):
        e = elements.get(r["UiTextureAtlasElementID"])
        if e:
            e["members"].append({"file": files.get(r["UiTextureAtlasID"], 0), "l": int(r["CommittedLeft"]),
                                 "r": int(r["CommittedRight"]), "t": int(r["CommittedTop"]),
                                 "b": int(r["CommittedBottom"])})
    return {e["name"].lower(): e for e in elements.values() if e["members"]}


blps = {}


def texels(m):
    """A member's texels, rows from the top: width, height, rows of RGBA bytes."""
    if m["file"] not in blps:
        blps[m["file"]] = decode_blp(fetch(CASC.format(m["file"]), CACHE / f"{m['file']}.blp"))
    w, _, rgba = blps[m["file"]]
    cw, ch = m["r"] - m["l"], m["b"] - m["t"]
    return cw, ch, [rgba[((m["t"] + y) * w + m["l"]) * 4:((m["t"] + y) * w + m["l"] + cw) * 4] for y in range(ch)]


def drawn(cw, ch, rows):
    """The box round the art (left, top, right, bottom texels), None for an empty atlas."""
    xs, ys = [], []
    for y, row in enumerate(rows):
        for x in range(cw):
            if row[4 * x + 3] > OPAQUE:
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None


def global_strings(locale):
    """This build's game strings in one language, by their global name."""
    out = {}
    for line in (GLOBAL_STRINGS / f"{locale}.lua").read_text(encoding="utf-8").splitlines():
        m = re.match(r'(?:_G\["([^"]+)"\]|([A-Za-z_]\w*)) = "(.*)";\s*$', line)
        if m:
            out[m.group(1) or m.group(2)] = m.group(3).replace('\\"', '"')
    return out


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def names_of(spec, strings, where):
    """(the game's name for it or None, French, English) from a LIBRARY name, or a problem; None: the languages' files
    name it (French and English None here)."""
    if spec is None:
        return None, None, None
    if isinstance(spec, str):
        fr, en = strings["frFR"].get(spec), strings["enUS"].get(spec)
        if not (fr and en):
            return f"{where}: {spec} isn't a game string in both frFR and enUS"
        for s in (fr, en):
            if "%" in s or "|" in s or "\\n" in s:
                return f"{where}: {spec} is a format or holds a code: {s!r}"
        return spec, fr, en
    if len(spec) == 2:
        return None, spec[0], spec[1]
    return spec


# The picker's layout (UI/Hub/IconPicker.lua), in units: icons a line, a cell, the icon in it, a category's name and
# the space under it, between categories, between columns, the columns; its colours.
PER_LINE, CELL, ICON, HEAD, HEAD_GAP, SECTION_GAP, COLUMN_GAP, COLUMNS = 8, 28, 22, 14, 3, 10, 16, 3
GROUND, EDGE, LABEL = (0.07, 0.07, 0.07), (0.32, 0.32, 0.32), (0.8, 0.7, 0.52)
# The French names of the categories (ICON_GROUP_<id>) and of the icons the game has no word for (ICON_NAMES), in the
# French file; the English file's ICON_NAMES, held against the library.
LOCALE = ADDON / "Locale/frFR.lua"
ENGLISH = ADDON / "Locale/enUS.lua"


def own_names(path):
    """A language file's ICON_NAMES: atlas to name."""
    text = path.read_text(encoding="utf-8")
    block = re.search(r"\n    ICON_NAMES = \{\n(.*?)\n    \},", text, re.S)
    return dict(re.findall(r'\["([^"]+)"\] = "([^"]*)"', block.group(1))) if block else {}


def columns_of(heights, k):
    """The picker's split: the sections in order down at most k columns, the tallest as short as can be."""
    def pack(limit):
        out, column, used = [], 1, 0
        for h in heights:
            if used and used + SECTION_GAP + h > limit:
                column, used = column + 1, 0
            used += (SECTION_GAP if used else 0) + h
            out.append(column)
        return out
    limits = sorted(sum(heights[i:j + 1]) + SECTION_GAP * (j - i)
                    for i in range(len(heights)) for j in range(i, len(heights)))
    for limit in limits:
        columns = pack(limit)
        if max(columns) <= k:
            return columns
    return [1] * len(heights)


def sheet(path, groups):
    """The library as the picker lays it out (its colours, cells, columns and split), 1.8 pixels a unit as on Ikar's
    screen, each icon's name on hover."""
    art = path.parent / "icons"
    art.mkdir(parents=True, exist_ok=True)
    # French first in the file: the first of each name
    names = {}
    for group, text in re.findall(r'ICON_GROUP_(\w+) = "([^"]*)"', LOCALE.read_text(encoding="utf-8")):
        names.setdefault(group, text)
    french = own_names(LOCALE)
    px = 1.8
    sections, n = [], 0
    for group, entries in groups:
        cells = []
        for name, box, tint, cw, ch, rows, fr in entries:
            fr = fr or french.get(name, name)
            n += 1
            l, t, r, b = box
            write_png(art / f"{n}.png", r - l, b - t, b"".join(row[4 * l:4 * r] for row in rows[t:b]))
            k = ICON * px / max(r - l, b - t)
            style = f"width:{(r - l) * k:.1f}px;height:{(b - t) * k:.1f}px" + (";filter:url(#tint)" if tint else "")
            cells.append(f'<div class="c" title="{html.escape(fr)} ({html.escape(name)})">'
                         f'<img src="icons/{n}.png" style="{style}"></div>')
        if cells:
            height = HEAD + HEAD_GAP + -(-len(cells) // PER_LINE) * CELL
            sections.append((height, f'<div class="s"><div class="h">{html.escape(names.get(group, group))}</div>'
                                     f'<div class="g">{"".join(cells)}</div></div>'))
    columns = columns_of([h for h, _ in sections], COLUMNS)
    cols = [[] for _ in range(max(columns))]
    for (_, part), c in zip(sections, columns):
        cols[c - 1].append(part)

    def rgb(c):
        return "#" + "".join(f"{round(v * 255):02x}" for v in c)
    path.write_text(f"""<!doctype html><meta charset="utf-8"><title>KaLi HUD folder icons</title><style>
body{{background:#3a3f45;margin:12px;font:{10 * px:.0f}px "Friz Quadrata TT",Georgia,serif}}
.p{{background:{rgb(GROUND)};border:1px solid {rgb(EDGE)};padding:{8 * px:.0f}px;width:max-content}}
.t{{color:{rgb(LABEL)};font-size:{12 * px:.0f}px}} .i{{color:#fff;font-size:{10 * px:.0f}px;margin:{3 * px:.0f}px 0
{8 * px:.0f}px}} .cols{{display:flex;gap:{COLUMN_GAP * px:.0f}px;align-items:flex-start}}
.col{{display:flex;flex-direction:column;gap:{SECTION_GAP * px:.0f}px}} .h{{color:{rgb(LABEL)};height:{HEAD * px:.0f}px;
margin-bottom:{HEAD_GAP * px:.0f}px}} .g{{display:grid;grid-template-columns:repeat({PER_LINE},{CELL * px:.0f}px)}}
.c{{width:{CELL * px:.0f}px;height:{CELL * px:.0f}px;display:flex;align-items:center;justify-content:center}}
.c:hover{{background:rgba(255,255,255,.1)}}
</style><svg width="0" height="0"><filter id="tint"><feColorMatrix type="matrix" values="{TINT[0]} 0 0 0 0 0 {TINT[1]}
0 0 0 0 0 {TINT[2]} 0 0 0 0 0 1 0"/></filter></svg><div class="p"><div class="t">Add-ons</div>
<div class="i">Sélectionnez une icône :</div><div class="cols">{"".join(f'<div class="col">{"".join(c)}</div>'
for c in cols)}</div></div><p style="color:#ccc;font:12px Segoe UI">{n} icons in {len(sections)} categories, as the
picker lays them out; hover one for its name</p>""", encoding="utf-8")


def main():
    known = atlases()
    strings = {locale: global_strings(locale) for locale in ("frFR", "enUS")}
    lines, groups, seen, problems = [], [], set(), []
    for group, icons in LIBRARY:
        lines.append(f"    -- {group}")
        entries = []
        for name, tint, spec in icons:
            e = known.get(name.lower())
            if not e:
                problems.append(f"{name}: no such atlas in {BUILD}")
                continue
            if name.lower() in seen:
                problems.append(f"{name}: listed twice")
            seen.add(name.lower())
            named = names_of(spec, strings, name)
            if isinstance(named, str):
                problems.append(named)
                continue
            game, fr, en = named
            m = max(e["members"], key=lambda m: (m["r"] - m["l"]) * (m["b"] - m["t"]))
            cw, ch, rows = texels(m)
            box = drawn(cw, ch, rows)
            if not box:
                problems.append(f"{name}: nothing drawn")
                continue
            l, t, r, b = box
            fields = [f'group = "{group}"'] + ([f"game = {lua_string(game)}"] if game else []) + (
                [f"fr = {lua_string(fr)}", f"en = {lua_string(en)}"] if fr else [])
            lines.append(f'    {{ "{e["name"]}", {l / cw:.3f}, {t / ch:.3f}, {r / cw:.3f}, {b / ch:.3f}, '
                         f'{"true" if tint else "false"}, ' + ", ".join(fields) + " },")
            entries.append((e["name"], box, tint, cw, ch, rows, fr))
        groups.append((group, entries))
    english = own_names(ENGLISH)
    # by the game's spelling of each atlas, as Data/Icons.lua writes it and the picker looks it up
    ours = {known[name.lower()]["name"] for _, icons in LIBRARY for name, _, spec in icons
            if spec is None and name.lower() in known}
    problems += [f"{name}: no name in {ENGLISH.relative_to(ADDON).as_posix()}'s ICON_NAMES" for name in sorted(ours - set(english))]
    problems += [f"{name}: named in {ENGLISH.relative_to(ADDON).as_posix()}'s ICON_NAMES, not in the library or named by the game"
                 for name in sorted(set(english) - ours)]
    if problems:
        raise SystemExit("\n".join(problems))
    count = sum(len(entries) for _, entries in groups)
    (ADDON / "Data/Icons.lua").write_text(
        f"-- Generated by hud/tools/make_icons.py from Forever's game data ({BUILD}): the icons a folder can wear,\n"
        "-- Blizzard's atlases in the picker's order, by category (ICON_GROUPS, each named by Locale/<language>.lua's\n"
        "-- ICON_GROUP_<id>), the first the folders' own. Each: the atlas; the part of it its art fills (left, top, right,\n"
        "-- bottom), so every icon's art comes out at the icon size; true for a white glyph, drawn in the folder's colour;\n"
        "-- its category; its name on hover: the game's own (`game`, a global's name or a dotted path into one of its\n"
        "-- tables) in the player's language, with this build's `fr` and `en` for a client without it; else each\n"
        "-- language's own, Locale/<language>.lua's ICON_NAMES. Don't edit.\n"
        "local _, ns = ...\n\n"
        "ns.ICON_GROUPS = { " + ", ".join(f'"{group}"' for group, _ in LIBRARY) + " }\n\n"
        "ns.ICONS = {\n" + "\n".join(lines) + "\n}\n",
        encoding="utf-8", newline="\n")
    print(f"written: Data/Icons.lua, {count} icons in {len(groups)} categories")
    if "--sheet" in sys.argv:
        page = Path(sys.argv[sys.argv.index("--sheet") + 1])
        sheet(page, groups)
        print(f"written: {page}")


if __name__ == "__main__":
    main()
