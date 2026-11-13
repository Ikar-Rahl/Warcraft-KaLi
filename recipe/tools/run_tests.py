"""Run KaLi Recipe's Lua checks outside the game, on Lua 5.1 as the game uses.

The checks of 1, 2, 5, 6, 7 and 11, and the enums' of 9, are the family's (tools/kali/checks.py, first written for KaLi
Quest):
1. Every .lua file under recipe/addon/ compiles.
2. Each addon loads in its TOC's order on the fake WoW API (tools/lua/fakewow.lua, then this addon's
   recipe/tools/lua/fakewow_recipe.lua). A global written that isn't on the allowed list is reported.
3. KaLiRecipe_Tests runs: the same tests as /kr test in game.
4. recipe/tools/lua/smoke.lua starts the addon and its probe as the game would, plays a session and runs
   every slash command of both; then tools/lua/smoke_shared.lua checks the shared code's copy (shared/) the same
   way in both addons.
5. Every C_ function, bare global function and :Method( the addons call exists in this build's API docs or
   Blizzard's own code.
6. KaLiRecipe's folder is a complete package: the TOC's fields, an icon the game can read, every listed file
   present, every file its code names inside the addon (the minimap button's icon) there, no stray file.
7. KaLiRecipe/Data/Needs.lua, what the addon takes from the game for its in-game API check, is the one its code gives
   today. --write-needs writes it.
8. The generated data holds together: its build is the tables', every recipe item teaches a recipe in it, every
   category a recipe names is in it.
9. What the fake would otherwise invent comes from this build: every Enum table the addons name is the API docs' own,
   member for member (the bank's bag numbers were invented once, and wrong), or one Blizzard's own code reads; the
   modified clicks' keys are Forever's defaults (Bindings_Camelot.xml); the addon's XML templates are built as the
   game builds them (mixin, mouse, scripts), so the world map's own checks on a pin run offline; the French game
   strings the fake defines are the client's (BlizzardInterfaceResources' frFR.lua).
10. Each sound the options offer (Core/Sounds.lua) is a kit of this build's SoundKit table, with a file, under the name
   Blizzard's SOUNDKIT gives it or playing the file the addon names; one stopped early stops within its shortest take;
   the bench's list (recipe/bench/js/sounds.js, recipe/tools/bench_sounds.py) is the same.
11. No code of the shipped addon tests a value against itself, the usual test for nan, which the game's Lua doesn't
   honour (ns.Finite does).
12. The sessions after the smoke's start from the files it wrote, as the game reads them (restart_problems).

Run with: python -I recipe/tools/run_tests.py
--addons <dir> runs on a copy, for experiments: recipe/addon is linked into the game.
"""
import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali import checks  # noqa: E402
from kali.paths import RECIPE, REFERENCE  # noqa: E402

RECIPE_LUA = RECIPE / "tools/lua"
NEEDS_FILE = "KaLiRecipe/Data/Needs.lua"
ALLOWED_GLOBALS = {
    "KaLiRecipeDev", "KaLiRecipeDB", "KaLiRecipeDevDB", "KaLiRecipeCopyDB", "SLASH_KALIRECIPE1", "SLASH_KALIRECIPE2",
    "KaLiRecipeTests", "KaLiRecipeProbeDB", "SLASH_KRPROBE1", "SLASH_KRPROBE2",
    "KaLiRecipe_OnAddonCompartmentClick", "KaLiRecipe_OnAddonCompartmentEnter", "KaLiRecipe_OnAddonCompartmentLeave",
    "KaLiRecipeMapPinMixin", "KaLiRecipeMinimapButton",
}
# GameTooltip's own methods, which neither the docs nor Blizzard's Lua define but Blizzard's Lua calls (SetItemByID in
# 23 files, SetSpellByID in 33, AddDoubleLine in the achievement UI and others).
checks.configure(ADDONS=RECIPE / "addon", NEEDS_FILE=NEEDS_FILE, ALLOWED_GLOBALS=ALLOWED_GLOBALS,
                 ENGINE_METHODS={"AddDoubleLine", "SetItemByID", "SetSpellByID"})
lupa, ADDONS, rel = checks.lupa, checks.ADDONS, checks.rel


API_DOCS = checks.API_DOCS
DB2 = max((REFERENCE / "db2").iterdir())
FRENCH = REFERENCE / "BlizzardInterfaceResources/Resources/GlobalStrings/frFR.lua"
SOUNDKIT_LUA = REFERENCE / "wow-ui-source/Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua"
BENCH_SOUNDS = RECIPE / "bench/js/sounds.js"
UI_NS = "{http://www.blizzard.com/wow/ui/}"


def to_lua(lua, value):
    """A Python value as a Lua one, nested tables included."""
    if isinstance(value, dict):
        t = lua.table()
        for k, v in value.items():
            t[k] = to_lua(lua, v)
        return t
    if isinstance(value, (list, tuple)):
        return to_lua(lua, {i + 1: v for i, v in enumerate(value)})
    return value


# The family's enum check (tools/kali/checks.py); the fake gets the docs' own tables for those the addons name.
ENUMS = checks.documented_enums()
USED_ENUMS = checks.addon_enums(sorted(ADDONS.rglob("*.lua")))


def xml_templates(path):
    """The virtual templates an XML file defines, as the fake builds them: { name: { kind, mixin, mouse, scripts } }."""
    out = {}
    for el in ET.parse(path).getroot():
        if el.get("virtual") == "true" and el.get("name"):
            scripts = {s.tag.replace(UI_NS, ""): s.get("method") or s.get("function") or "(inline)"
                       for s in el.findall(f"{UI_NS}Scripts/*")}
            out[el.get("name")] = {"kind": el.tag.replace(UI_NS, ""), "mixin": el.get("mixin") or "",
                                   "mouse": el.get("enableMouse") == "true", "scripts": scripts}
    return out


def runtime():
    """The fake API, KaLi Quest's and this addon's, and a loader for an addon's files: Lua files run, XML files give
    their virtual templates to the fake's CreateFrame. The Enum tables the addons name are put in from this build's
    docs before the recipe fake loads."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(checks.FAKE.read_text(encoding="utf-8"))
    checks.fake_from_build(lua)
    enum = lua.globals().Enum
    for name in USED_ENUMS:
        if name in ENUMS:
            enum[name] = to_lua(lua, ENUMS[name])
    lua.execute((RECIPE_LUA / "fakewow_recipe.lua").read_text(encoding="utf-8"))
    loader = lua.execute(checks.LOADER)
    allowed = lua.table_from({name: True for name in ALLOWED_GLOBALS})
    templates = lua.globals().FakeWoW.xmlTemplates

    def load_addon(addon, namespace=None):
        ns = namespace if namespace is not None else lua.table()
        for path in checks.toc_files(addon):
            if path.suffix.lower() == ".lua":
                loader(rel(path), path.read_text(encoding="utf-8"), addon, ns, allowed)
            elif path.suffix.lower() == ".xml":
                for name, t in xml_templates(path).items():
                    templates[name] = to_lua(lua, t)
        return ns

    return lua, load_addon


def french_strings():
    """The French client's global strings: { name: text }."""
    out = {}
    for name, text in re.findall(r'^(\w+) = "((?:[^"\\]|\\.)*)";$', FRENCH.read_text(encoding="utf-8"), re.M):
        out[name] = text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
    return out


def string_problems(lua, read_by_addon):
    """The fake's French game strings, those it defines and those the addon reads, against the client's."""
    french = french_strings()
    defined = set(re.findall(r'^([A-Z][A-Z0-9_]+) = "', (RECIPE_LUA / "fakewow_recipe.lua").read_text(encoding="utf-8"), re.M))
    problems = []
    for name in sorted(defined | set(read_by_addon)):
        fake = lua.globals()[name]
        if name not in french:
            if name in defined:
                problems.append(f"strings: the fake's {name} isn't a French client string")
        elif isinstance(fake, str) and fake != french[name]:
            problems.append(f"strings: the fake's {name} is {fake!r}, the client's {french[name]!r}")
    return problems, len(defined | set(read_by_addon))


def sound_problems(lua):
    """Core/Sounds.lua's choices against this build's sound tables, and the bench's copy."""
    names = {k: int(v) for k, v in re.findall(r"^\s*([A-Z0-9_]+)\s*=\s*(\d+)", SOUNDKIT_LUA.read_text(encoding="utf-8"), re.M)}
    with open(DB2 / "SoundKit.csv", encoding="utf-8", newline="") as f:
        kits = {int(r["ID"]): float(r["VolumeFloat"]) for r in csv.DictReader(f)}
    own = lua.eval("KaLiRecipeDev.ns.Sounds.KIT_VOLUME")
    files = {}
    with open(DB2 / "SoundKitEntry.csv", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            files.setdefault(int(r["SoundKitID"]), set()).add(int(r["FileDataID"]))
    choices = lua.eval("KaLiRecipeDev.ns.Sounds.CHOICES")
    problems, listed = [], {}
    for kind in ("recipe", "place"):
        keys = set()
        for c in choices[kind].values():
            key, kit, check, stop = c[1], c[2], c[3], c[4]
            listed.setdefault(kind, []).append([key, kit, stop])
            if key in keys:
                problems.append(f"sounds: {kind} {key} twice")
            keys.add(key)
            if isinstance(check, str):
                if names.get(check) != kit:
                    problems.append(f"sounds: {key}: SOUNDKIT.{check} is {names.get(check)}, the addon plays {kit}")
            elif check not in files.get(kit, ()):
                problems.append(f"sounds: {key}: kit {kit} doesn't play file {check}")
            if kit not in kits:
                problems.append(f"sounds: {key}: kit {kit} isn't in this build's SoundKit table")
            elif kit not in files:
                problems.append(f"sounds: {key}: kit {kit} has no file in this build")
            # « Volume des sons » asks a share of the kit's own volume: a wrong one and 95 % may be louder than 100 %.
            if kit in kits and (own[kit] is None or abs(own[kit] - kits[kit]) > 1e-6):
                problems.append(f"sounds: {key}: Sounds.KIT_VOLUME[{kit}] is {own[kit]}, the SoundKit table's {kits[kit]}")
            if stop is not None and not 0 < stop < 2:
                problems.append(f"sounds: {key}: stopped after {stop} s, not within the quill's shortest take (2.2 s)")
    if not BENCH_SOUNDS.exists():
        problems.append("sounds: no bench/js/sounds.js: run python -I recipe/tools/bench_sounds.py")
    else:
        bench = json.loads(BENCH_SOUNDS.read_text(encoding="utf-8").split("=", 1)[1].strip().rstrip(";"))
        if {k: [[c["key"], c["kit"], c.get("stop")] for c in v] for k, v in bench["kinds"].items()} != listed:
            problems.append("sounds: bench/js/sounds.js isn't the addon's list: run python -I recipe/tools/bench_sounds.py")
    return problems, sum(len(v) for v in listed.values())


def data_problems():
    """Data/Recipes.lua: made from the tables on disk, and whole."""
    text = (ADDONS / "KaLiRecipe/Data/Recipes.lua").read_text(encoding="utf-8")
    problems = []
    build = re.search(r'ns\.DATA_BUILD = "([^"]+)"', text)
    tables = max((REFERENCE / "db2").iterdir()).name
    if not build or build.group(1) != tables:
        problems.append(f"data: Data/Recipes.lua is from {build and build.group(1)}, the tables are {tables}: run gen_addon_data.py")
    recipes_part, rest = text.split("ns.RECIPE_ITEMS", 1)
    items_part, cats_part = rest.split("ns.CATEGORIES", 1)
    recipes = {int(a): [int(x) for x in b.split(",")] for a, b in re.findall(r"^\s+\[(\d+)\] = \{ ([\d, ]+) \},$", recipes_part, re.M)}
    items = {int(a): int(b) for a, b in re.findall(r"^\s+\[(\d+)\] = (\d+),$", items_part, re.M)}
    cats = {int(a) for a in re.findall(r"^\s+\[(\d+)\] = \{", cats_part.split("ns.CATEGORY_NAMES")[0], re.M)}
    problems += [f"data: recipe item {i} teaches {s}, not in RECIPES" for i, s in items.items() if s not in recipes]
    problems += [f"data: recipe {s} names category {r[4]}, not in CATEGORIES" for s, r in recipes.items() if r[4] and r[4] not in cats]
    problems += [f"data: recipe {s} has an odd reagent list" for s, r in recipes.items() if (len(r) - 6) % 2]
    return problems, len(recipes), len(items)


SAID_RESTORED = """(function()
    local head = KaLiRecipeDev.ns.L.DB_RESTORED:match("^[^%%]*")
    for _, line in ipairs(FakeWoW.printed) do
        if line:find(head, 1, true) then
            return true
        end
    end
    return false
end)()"""


def restart_problems(lua, load_addon):
    """The sessions after the smoke's, each in a new Lua state as each login is, from the files it wrote at logout,
    written and read back as the game does (KaLiRecipe_Tests' Saved): the client sets the saved variables after the
    addon's files run, then fires ADDON_LOADED.
    1. Both files: the notebook opens as it was saved: nothing repaired, set aside or taken from the copy.
    2. The account's file gone: the character's copy brings the notebook back and says so once; written at logout,
       the notebook opens again from its own file with nothing more to take.
    3. A copy from a newer version: the notebook opens from the account's file, and the copy isn't written over.
    4. An account file from a newer version: refused, both files left as they are, the API check still made at login."""
    if not lua.globals().KaLiRecipeTests:
        load_addon("KaLiRecipe_Tests")
    g = lua.globals()
    saved = lua.eval("KaLiRecipeTests.Saved")
    if not g.KaLiRecipeCopyDB:
        return ["restart: the smoke session wrote no character copy"], 0
    account = saved("KaLiRecipeDB", g.KaLiRecipeDB)
    copy = saved("KaLiRecipeCopyDB", g.KaLiRecipeCopyDB)
    sightings = saved("sightings", g.KaLiRecipeDB.sightings)
    options = saved("options", g.KaLiRecipeDB.options)
    problems = []

    def start(texts, before=""):
        lua2, load2 = runtime()
        load2("KaLiRecipe")
        load2("KaLiRecipe_Tests")
        for text in texts:
            lua2.execute(text)
        lua2.execute(before)
        lua2.execute('FakeWoW.Fire("ADDON_LOADED", "KaLiRecipe")')
        return lua2, lua2.eval("KaLiRecipeDev.ns.dbInfo"), lua2.eval("KaLiRecipeTests.Saved")

    def login(lua2, what):
        lua2.execute('FakeWoW.Fire("PLAYER_LOGIN"); FakeWoW.RunTimers()')
        error = lua2.eval("next(KaLiRecipeDevDB.errors or {})")
        if error:
            problems.append(f"restart, {what}: error at login: {error}")

    def logout(lua2, sv):
        lua2.execute('FakeWoW.Fire("PLAYER_LOGOUT")')
        g2 = lua2.globals()
        return sv("KaLiRecipeDB", g2.KaLiRecipeDB), sv("KaLiRecipeCopyDB", g2.KaLiRecipeCopyDB)

    def diff(lua2, text, name):
        expected = lua2.eval("KaLiRecipeTests.ReadSaved")(text)[name]
        return lua2.eval("KaLiRecipeTests.Diff")(expected, lua2.globals()[name], name)

    s, info, sv = start([account, copy])
    if not info:
        problems.append(f"restart, both files: refused: {s.eval('KaLiRecipeDev.ns.disabled')}")
    else:
        if sv("KaLiRecipeDB", s.globals().KaLiRecipeDB) != account:
            problems.append(f"restart, both files: not the notebook saved: {diff(s, account, 'KaLiRecipeDB')}")
        if (info.fixed, info.setAside, info.recovered) != (0, 0, 0) or info.restored or info.copyRefused:
            problems.append(f"restart, both files: repaired {info.fixed}, set aside {info.setAside}, from the copy "
                            f"{info.recovered}, restored {info.restored is not None}, copy refused {info.copyRefused}")
        login(s, "both files")

    s, info, sv = start([copy])
    if not (info and info.restored):
        problems.append("restart, no account file: the copy didn't bring the notebook back")
    else:
        if sv("sightings", s.globals().KaLiRecipeDB.sightings) != sightings:
            problems.append("restart, no account file: the sightings brought back aren't the ones saved")
        if sv("options", s.globals().KaLiRecipeDB.options) != options:
            problems.append("restart, no account file: the options brought back aren't the ones saved")
        login(s, "no account file")
        if not s.eval(SAID_RESTORED):
            problems.append("restart, no account file: nothing said in chat")
        restored, recopied = logout(s, sv)
        s, info, sv = start([restored, recopied])
        if not info or (info.fixed, info.setAside, info.recovered) != (0, 0, 0) or info.restored:
            problems.append("restart, after a restore: the notebook's own file doesn't open as it was saved")

    s, info, sv = start([account, copy], "KaLiRecipeCopyDB.data.version = 99")
    if not (info and info.copyRefused):
        problems.append("restart, a newer copy: not refused")
    else:
        login(s, "a newer copy")
        _, kept = logout(s, sv)
        if "[\"version\"] = 99" not in kept or sv("sightings", s.globals().KaLiRecipeCopyDB.data.sightings) != sightings:
            problems.append("restart, a newer copy: written over")

    # An account file from a newer version: refused, and both files are left as they are; the API check still runs at
    # login, as KaLi Quest's does.
    s, info, sv = start([account, copy], "KaLiRecipeDB.version = 99")
    if info or not s.eval("KaLiRecipeDev.ns.disabled"):
        problems.append("restart, a newer account file: not refused")
    else:
        login(s, "a newer account file")
        if not s.eval("type(KaLiRecipeDevDB.apiChecks) == 'table' and #KaLiRecipeDevDB.apiChecks > 0"):
            problems.append("restart, a newer account file: no API check at login")
        kept_account, kept_copy = logout(s, sv)
        if "[\"version\"] = 99" not in kept_account or sv("sightings", s.globals().KaLiRecipeDB.sightings) != sightings:
            problems.append("restart, a newer account file: written over")
        if kept_copy != copy:
            problems.append("restart, a newer account file: the character's copy written over")
    return problems, 5


def main():
    problems = []
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    sources = sorted(ADDONS.rglob("*.lua"))
    for path in sources:
        result = lua.globals().loadstring(path.read_text(encoding="utf-8"), "@" + rel(path))
        if isinstance(result, tuple) and result[1]:
            problems.append(f"compile: {result[1]}")
    print(f"compile: {len(sources)} files")
    called_by_blizzard, defined_by_blizzard, methods_by_blizzard, defined_in, templates_in, fonts_in = checks.ui_source_names()
    unknown, known = checks.unknown_api_calls(sources, called_by_blizzard)
    print(f"api: {known} documented C_ functions, {len(unknown)} unknown names used")
    problems += [f"api not in this build's docs: {u}" for u in unknown]
    unknown_globals = checks.unknown_global_calls(sources, defined_by_blizzard)
    print(f"globals: {len(unknown_globals)} unknown global functions called")
    problems += [f"global function not in the game: {u}" for u in unknown_globals]
    unknown_methods = checks.unknown_method_calls(sources, methods_by_blizzard)
    print(f"methods: {len(unknown_methods)} unknown method names called")
    problems += [f"method not in the game: {u}" for u in unknown_methods]
    package, count = checks.package_problems("KaLiRecipe")
    print(f"package: {count} files, {len(package)} problems")
    problems += package
    needs_path = ADDONS / NEEDS_FILE
    shipped = [p for p in sorted((ADDONS / "KaLiRecipe").rglob("*.lua")) if p != needs_path and "Data" not in p.parts]
    found = checks.needs(shipped, checks.documented_functions(called_by_blizzard), defined_in, templates_in, fonts_in)
    expected = checks.needs_lua(found)
    if "--write-needs" in sys.argv:
        needs_path.write_text(expected, encoding="utf-8", newline="\n")
    elif not needs_path.exists() or needs_path.read_text(encoding="utf-8") != expected:
        problems.append(f"needs: {rel(needs_path)} is out of date: run recipe/tools/run_tests.py --write-needs")
    print(f"needs: {len(found['globals'])} globals, {len(found['events'])} events, {len(found['atlases'])} atlases, "
          f"{len(found['templates'])} templates, {len(found['cvars'])} CVars, {len(found['strings'])} strings")
    data, n_recipes, n_items = data_problems()
    print(f"data: {n_recipes} recipes, {n_items} recipe items, {len(data)} problems")
    problems += data
    enums = checks.enum_problems(USED_ENUMS, ENUMS)
    print(f"enums: {len(USED_ENUMS)} named, {len(enums)} not in this build's docs nor Blizzard's code")
    problems += enums
    nan = checks.self_compare_problems(shipped)
    print(f"nan: {len(nan)} values compared with themselves in the shipped addon")
    problems += nan

    lua, load_addon = runtime()
    load_addon("KaLiRecipe")
    strings, n_strings = string_problems(lua, found["strings"])
    sounds, n_sounds = sound_problems(lua)
    print(f"strings: {n_strings} French game strings against the client's, {len(strings)} problems")
    print(f"sounds: {n_sounds} offered, against this build's tables and the bench's list, {len(sounds)} problems")
    problems += strings + sounds
    load_addon("KaLiRecipe_Tests")
    report = lua.eval("KaLiRecipeTests.Run()")
    print(report.text)
    if report.failed > 0:
        problems.append(f"tests: {report.summary}")

    lua, load_addon = runtime()
    load_addon("KaLiRecipe")
    if (ADDONS / "KaLiRecipe_Probe").exists():
        load_addon("KaLiRecipe_Probe")
    failures = lua.execute((RECIPE_LUA / "smoke.lua").read_text(encoding="utf-8"))
    failures = list(failures.values())
    print(f"smoke: {'PASS' if not failures else 'FAIL'}")
    problems += [f"smoke: {f}" for f in failures]
    shared_failures = checks.shared_smoke(lua, "KaLiRecipe")
    print(f"shared: {'PASS' if not shared_failures else 'FAIL'}")
    problems += shared_failures
    leaks = sorted(set(lua.globals().KALI_LEAKS.values()))
    problems += [f"global written: {leak}" for leak in leaks]
    restart, sessions = restart_problems(lua, load_addon)
    print(f"restart: {sessions} sessions from the files the smoke wrote, {len(restart)} problems")
    problems += restart

    print()
    if problems:
        print("\n".join(problems))
        print(f"\nFAIL: {len(problems)} problem(s)")
        sys.exit(1)
    print("ALL PASS")


# read_saved.py check imports runtime() from here, to open the player's files with the addon's own code.
if __name__ == "__main__":
    main()
