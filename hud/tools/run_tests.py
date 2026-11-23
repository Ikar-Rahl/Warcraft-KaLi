"""Run KaLi HUD's checks outside the game, on Lua 5.1 as the game uses. The family's checks (tools/kali/checks.py):
1. Every .lua file under hud/addon/ compiles.
2. Every C_ function, bare global function and :Method( the addon calls exists in this build's API docs or Blizzard's
   own code; every Enum it names is the docs' own or one Blizzard's code reads.
3. KaLiHUD's folder is a complete package: the TOC's fields, its icon, every listed file, every texture its code
   names, no stray file; every sound it plays is a kit of this build's SoundKit table.
4. KaLiHUD/Data/Needs.lua, what the addon takes from the game for its in-game API check, is the one its code gives
   today. --write-needs writes it. KaLiHUD/Data/Effects.lua, what each spell's auras change among the sheet's
   attributes, is the one this build's game data gives (hud/tools/make_effects.py writes it); KaLiHUD/Data/Zones.lua,
   the zones' levels its Group Finder suggests, too (hud/tools/make_zones.py); KaLiHUD/Data/Fishing.lua, the original
   game's base fishing skill of each area found in this build (hud/tools/make_fishing.py).
5. No code of the shipped addon tests a value against itself, the usual test for nan, which the game's Lua doesn't
   honour; and every call of a game function whose result the API docs say may come as a secret value (the player's
   speed in a fight) reads it through ns.Plain.
6. KaLiHUD_Tests runs: the same tests as /kh test in game.
7. hud/tools/lua/smoke.lua starts the addon and its probe as the game would, plays a session and runs every slash
   command; then tools/lua/smoke_shared.lua checks the shared code's copy.
8. The next session starts from the file the smoke wrote, as the game reads it: nothing repaired, nothing lost, and a
   login without error (the smoke ends with a folder left open, which raised one).
9. Every text of the Edit Mode dialog and of the options page fits the room its frame gives it, in each language the
   addon speaks, measured with the game's own font (tools/kali/labels.py).
10. KaLi HUD as the only addon installed, with no library of other addons': a login and a short session without error,
    then LibDataBroker arriving with an addon loaded later.
11. Every handler the addon's own files hand the game in a session (a script, a hook, a callback, a menu's entry) is
    guarded, and the saved places are named in the hub's own file alone (handler_problems, places_problems).
12. Each scenario of hud/tools/lua/scenarios/, a short session from a game started for it alone.

The family's tools/run_tests.py runs this after checking the shared code's copies (tools/sync_shared.py writes them).
Run alone with: python -I hud/tools/run_tests.py
--only <part>[,<part>] runs parts of it alone (static, tests, smoke, alone, scenarios, a scenario's name; "blocks"
tries each block of the smoke by itself), --at <text> the smoke's one block whose check says that text: see "The
parts of a run" below. tools/breaks.py runs each deliberate break against the part linked to it.
--addons <dir> runs on a copy, for experiments: hud/addon is linked into the game.
"""
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(HERE))
from kali import checks, labels  # noqa: E402

HUD_LUA = HERE / "lua"
NEEDS_FILE = "KaLiHUD/Data/Needs.lua"
ALLOWED_GLOBALS = {
    "KaLiHUDDev", "KaLiHUDDB", "KaLiHUDDevDB", "SLASH_KALIHUD1", "SLASH_KALIHUD2", "KaLiHUDTests",
    "KaLiHUDProbeDB", "SLASH_KALIHUDPROBE1",
    "KaLiHUD_OnAddonCompartmentClick", "KaLiHUD_OnAddonCompartmentEnter", "KaLiHUD_OnAddonCompartmentLeave",
    "KaLiHUDHolder", "KaLiHUDEditModeDialog", "KaLiHUD_BagBarToggle", "KaLiHUDIconPicker",
    "KaLiHUD_Binding", "BINDING_HEADER_KALIHUD", "BINDING_NAME_KALIHUD_UNDO", "BINDING_NAME_KALIHUD_REDO",
}
# GameTooltip's own, which Blizzard's Lua calls but neither defines nor documents (NumLines: TooltipUtil.lua's).
checks.configure(ADDONS=ROOT / "hud/addon", NEEDS_FILE=NEEDS_FILE, ALLOWED_GLOBALS=ALLOWED_GLOBALS, ENGINE_METHODS={"AddDoubleLine", "IsOwned", "NumLines"})
lupa, rel = checks.lupa, checks.rel
ADDONS = checks.ADDONS


def icons_from_build(lua):
    """Gives the fake what the folders' icon library takes from the game, as this build has it in French, the fake's
    language: the game strings its icons are named by (Data/Icons.lua's `game`), every class's name (DB2 ChrClasses)
    and Blizzard's question mark (Blizzard_FrameXMLBase's Constants.lua), so the API check finds them as in game."""
    import make_icons
    g = lua.globals()
    words = make_icons.global_strings("frFR")
    icons = (ADDONS / "KaLiHUD/Data/Icons.lua").read_text(encoding="utf-8")
    for name in re.findall(r'\bgame = "(\w+)"', icons):
        if name in words:
            g[name] = words[name]
    with open(max(checks.DB2.iterdir()) / "ChrClasses.frFR.csv", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            g.LOCALIZED_CLASS_NAMES_MALE[row["Filename"]] = row["Name_male_lang"]
    constants = (checks.UI_SOURCE / "AddOns/Blizzard_FrameXMLBase/Constants.lua").read_text(encoding="utf-8")
    question = re.search(r'^QUESTION_MARK_ICON = "(.*)";', constants, re.M)
    if question:
        g.QUESTION_MARK_ICON = question.group(1).replace("\\\\", "\\")


def runtime():
    """The family's fake game, KaLi HUD's part of it, and a loader for an addon's files in its TOC's order."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(checks.FAKE.read_text(encoding="utf-8"))
    checks.fake_from_build(lua)
    lua.execute((HUD_LUA / "fakewow_hud.lua").read_text(encoding="utf-8"))
    icons_from_build(lua)
    loader = lua.execute(checks.LOADER)
    allowed = lua.table_from({name: True for name in ALLOWED_GLOBALS})

    def load_addon(addon):
        ns = lua.table()
        for path in checks.toc_files(addon):
            loader(rel(path), path.read_text(encoding="utf-8"), addon, ns, allowed)
        return ns

    return lua, load_addon


def sound_problems(lua):
    """Every sound the addon plays (Init.lua's FOLD_SOUNDS and FOLDER_SOUNDS) is a kit of this build's SoundKit table,
    by number or by its name in Blizzard's SOUNDKIT."""
    text = (checks.UI_SOURCE / "AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua").read_text(encoding="utf-8")
    names = {}
    for name, kit in re.findall(r"^\s*(\w+)\s*=\s*(\d+)", text, re.M):
        names.setdefault(name, kit)
    with open(max(checks.DB2.iterdir()) / "SoundKit.csv", encoding="utf-8", newline="") as f:
        kits = {row["ID"] for row in csv.DictReader(f)}
    ns = lua.eval("KaLiHUDDev.ns")
    problems, count = [], 0
    for table in ("FOLD_SOUNDS", "FOLDER_SOUNDS"):
        for key, pair in ns[table].items():
            for kit in pair.values():
                count += 1
                found = names.get(kit) if isinstance(kit, str) else str(int(kit))
                if found not in kits:
                    problems.append(f"sounds: {table}.{key}: {kit} isn't a sound kit of this build")
    return problems, count


def restart_problems(lua, load_addon):
    """The session after the smoke's, in a new Lua state, from the file it wrote at logout, written and read back as
    the game does (KaLiHUD_Tests' Saved): the same data, nothing repaired, and a login without error."""
    if not lua.globals().KaLiHUDTests:
        load_addon("KaLiHUD_Tests")
    text = lua.eval("KaLiHUDTests.Saved")("KaLiHUDDB", lua.globals().KaLiHUDDB)
    lua2, load2 = runtime()
    load2("KaLiHUD")
    load2("KaLiHUD_Tests")
    lua2.execute(text)
    lua2.execute('FakeWoW.Fire("ADDON_LOADED", "KaLiHUD")')
    info = lua2.eval("KaLiHUDDev.ns.dbInfo")
    if not info:
        return [f"restart: refused: {lua2.eval('KaLiHUDDev.ns.disabled')}"]
    problems = []
    if info.fixed != 0:
        problems.append(f"restart: {info.fixed} values repaired in a file the addon wrote")
    again = lua2.eval("KaLiHUDTests.Saved")("KaLiHUDDB", lua2.globals().KaLiHUDDB)
    if again != text:
        problems.append("restart: the saved data doesn't open as it was written")
    lua2.execute('FakeWoW.Fire("PLAYER_LOGIN"); FakeWoW.Fire("PLAYER_ENTERING_WORLD"); FakeWoW.RunTimers()')
    error = lua2.eval("next(KaLiHUDDevDB.errors or {})")
    if error:
        problems.append(f"restart: error at login: {error}")
    if lua2.eval("KaLiHUDDev.ns.Plate.textures or 0") == 0:
        problems.append("restart: no plate drawn")
    return problems


def alone_problems():
    """KaLi HUD as the only addon installed, as a new player has it: no LibStub, no LibDataBroker, no LibDBIcon, no other
    addon's button on the map. A login and a short session without error; then the library arriving with an addon loaded
    later, on demand: its objects shown and followed, ours offered to it. The smoke's game always has the library from
    the start; the review of 2026-11-17 tried this by hand."""
    lua, load_addon = runtime()
    load_addon("KaLiHUD")
    lua.execute('''
        local F = FakeWoW
        F.stub, LibStub = LibStub, nil
        for _, name in ipairs({ "LibDBIcon10_Spoken", "AutoBiographerMinimapButton", "KaLiRecipeMinimapButton", "HandyNotesPin12" }) do
            local f = _G[name]
            if f then
                f:Hide()
                f:SetParent(nil)
                _G[name] = nil
            end
        end
        F.Fire("ADDON_LOADED", "KaLiHUD")
        F.Fire("PLAYER_LOGIN")
        F.Fire("PLAYER_ENTERING_WORLD")
        F.RunTimers()
        local ns = KaLiHUDDev.ns
        local shown = 0
        for _, b in pairs(ns.HubButtons.All()) do
            if b:IsShown() then
                shown = shown + 1
            end
        end
        ALONE = { shown = shown, gold = ns.InfoBar.Placed("KaLiHUD_Gold") ~= nil }
        -- a short session: values change, a folder opens, the padlock turns, a drag, a fight
        ns.Items.Update()
        ns.Infos.Update()
        local id = ns.Folders.ByRole("stats")
        ns.Folders.SetOpen(id, true)
        F.RunTimers()
        ns.Hub.SetLocked(false)
        F.RunTimers()
        F.cursorX, F.cursorY = 1300, 10
        ns.HubDrag.Begin("KaLiHUD_Gold")
        ns.HubDrag.Finish()
        F.RunTimers()
        F.EnterCombat()
        F.RunTimers()
        F.LeaveCombat()
        F.RunTimers()
        ns.Hub.SetLocked(true)
        F.RunTimers()
        ALONE.session = next(KaLiHUDDevDB.errors or {})
        -- the library comes with an addon loaded later
        LibStub = F.stub
        local late = F.ldb:NewDataObject("Tardif", { type = "data source", label = "Tardif", text = "1" })
        F.Fire("ADDON_LOADED", "Tardif")
        F.RunTimers()
        late.text = "2"
        F.RunTimers()
        local b = ns.HubButtons.Get("Tardif")
        ALONE.entry = ns.Hub.Entry("Tardif") ~= nil
        ALONE.ours = F.ldb.objects.KaLiHUD_Gold ~= nil
        ALONE.followed = b ~= nil and tostring(b.Text:GetText()):find("2", 1, true) ~= nil
        ALONE.late = next(KaLiHUDDevDB.errors or {})
    ''')
    alone = lua.eval("ALONE")
    problems = []
    if alone.session:
        problems.append(f"alone: error with no other addon: {alone.session}")
    if not alone.gold or alone.shown < 20:
        problems.append(f"alone: the bar isn't drawn with no other addon: {alone.shown} buttons shown")
    if alone.late and not alone.session:
        problems.append(f"alone: error as the library comes later: {alone.late}")
    if not alone.entry:
        problems.append("alone: an object of the library come with a later addon isn't shown")
    if not alone.ours:
        problems.append("alone: our items aren't offered to the library come with a later addon")
    if not alone.followed:
        problems.append("alone: an object of the library come later isn't followed as it changes")
    return problems


# ---------- Scenarios ----------
# A scenario is a file of hud/tools/lua/scenarios/: a short session of its own, from a game started for it alone, so
# what it finds depends on nothing another left behind (the smoke is one session of six thousand lines, each part of
# it living on what the parts before it left: the review of 2026-11-18). New cases go here. --scenario <word> runs
# those whose name holds the word and nothing else, in seconds: a deliberate break names the one that must catch it
# (tools/breaks.py), "tests" for KaLiHUD_Tests alone.
SCENARIOS = HUD_LUA / "scenarios"
PRELUDE = r'''
local F = FakeWoW
FAILURES = {}
function expect(ok, what)
    if not ok then
        FAILURES[#FAILURES + 1] = tostring(what)
    end
end
ns = KaLiHUDDev.ns
-- A login as the game does it; with saved data given first (KaLiHUDDB), from that.
function login()
    F.Fire("ADDON_LOADED", "KaLiHUD")
    F.Fire("PLAYER_LOGIN")
    F.Fire("PLAYER_ENTERING_WORLD")
    F.RunTimers()
end
-- The errors the addon kept: how many distinct ones, and their messages.
function errors()
    local all = {}
    for message in pairs(KaLiHUDDevDB and KaLiHUDDevDB.errors or {}) do
        all[#all + 1] = message
    end
    table.sort(all)
    return #all, table.concat(all, " | ")
end
-- The stack kept with the first error whose message holds `text`.
function stackOf(text)
    for message, e in pairs(KaLiHUDDevDB and KaLiHUDDevDB.errors or {}) do
        if message:find(text, 1, true) then
            return tostring(e.stack)
        end
    end
    return ""
end
-- How many times the errors whose message holds `text` were kept, all together.
function times(text)
    local n = 0
    for message, e in pairs(KaLiHUDDevDB and KaLiHUDDevDB.errors or {}) do
        if message:find(text, 1, true) then
            n = n + (e.count or 0)
        end
    end
    return n
end
function forget()
    KaLiHUDDevDB.errors = {}
end
-- How many of the hub's elements the last layout put on the bar.
function onBar()
    local n = 0
    for _, e in ipairs(ns.Hub.Entries()) do
        if ns.InfoBar.Placed(e.name) then
            n = n + 1
        end
    end
    return n
end
-- A script of a frame run as the game runs it, whatever it raises caught: true when nothing got out of it.
function runs(frame, script, ...)
    return (pcall(F.RunScript, frame, script, ...))
end
'''
HANDLERS = r'''
local out = {}
for fn in pairs(FakeWoW.handlers or {}) do
    local info = debug.getinfo(fn, "S")
    out[#out + 1] = info.source .. "|" .. info.linedefined .. "|" .. info.lastlinedefined
end
return table.concat(out, "\n")
'''
# A handler's line that needs no guard of its own: a guarded call (its result kept, perhaps), or what only chooses
# whether to make one.
GUARDED_LINE = re.compile(r"^(?:|if .+ then|elseif .+ then|else|end[),]*|return|"
                          r"(?:local )?(?:[\w.]+ = (?:not )?)?ns\.(?:SafeCall|Later|EveryFrame)\(.*\)?)$")
ONE_LINE = re.compile(r"function\s*\([^)]*\)\s*(.*?)\s*end[),]*\s*$")


def handler_problems(lua):
    """Every function the session handed the game to call later on the player's doing (the fake's F.handlers: a
    frame's script, a hook, a callback of the game's registry, what a menu's entry does) is guarded: it is ns.Guarded's
    own wrapper (the shared code's, not looked into), or one of KaLi HUD's own files' that does nothing but guarded
    calls. An error in any other goes to the game's handler alone: the addon's log and its bug report never have it."""
    problems, count = set(), 0
    for record in str(lua.execute(HANDLERS) or "").splitlines():
        source, first, last = record.rsplit("|", 2)
        at = source.find("KaLiHUD/")
        if at < 0 or not source[at:].startswith(("KaLiHUD/Core/", "KaLiHUD/UI/")):
            continue
        count += 1
        first, last = int(first), int(last)
        lines = (ADDONS / source[at:]).read_text(encoding="utf-8").splitlines()
        if first == last:
            one = ONE_LINE.search(lines[first - 1])
            body = [one.group(1)] if one else ["?"]
        else:
            body = lines[first:last - 1]
        body = [checks.strip_lua(line).strip() for line in body]
        if not all(GUARDED_LINE.match(line) for line in body):
            problems.add(f"handlers: {source[at:]}:{first}: a handler that isn't under ns.Guarded, nor only guarded calls")
    return sorted(problems), count


def places_problems(shipped):
    """The saved places (`db.items`) are named in UI/Hub/Hub.lua, which writes them, and Core/DB.lua, which repairs
    them at load: nowhere else in the shipped addon (the review of 2026-11-18: eighteen writes in six files)."""
    problems = []
    for path in shipped:
        if path.name in ("Hub.lua", "DB.lua"):
            continue
        code = checks.strip_lua(path.read_text(encoding="utf-8"))
        for number, line in enumerate(code.splitlines(), 1):
            if re.search(r"\bdb\.items\b", line):
                problems.append(f"places: {rel(path)}:{number}: the saved places named outside UI/Hub/Hub.lua")
    return problems


def scenario_problems(word=None):
    """Each scenario in a game of its own: what it expected and didn't find, an error of its own, and its handlers."""
    problems, ran = [], 0
    for path in sorted(SCENARIOS.glob("*.lua")):
        if word and word not in path.stem:
            continue
        ran += 1
        lua, load_addon = runtime()
        load_addon("KaLiHUD")
        lua.execute(PRELUDE)
        try:
            lua.execute(path.read_text(encoding="utf-8"))
        except Exception as error:  # a scenario that raises proves nothing: said, with its first line
            problems.append(f"scenario {path.stem}: error: {str(error).splitlines()[0]}")
        problems += [f"scenario {path.stem}: {failure}" for failure in lua.globals().FAILURES.values()]
        problems += handler_problems(lua)[0]
    return problems, ran


# ---------- The parts of a run ----------
# A whole run is its parts one after the other. --only <part>[,<part>...] runs those alone, after the compile: "static"
# (what the code names against this build's game, the package, the lists made from the code), "tests" (KaLiHUD_Tests),
# "smoke" (the long session, with what reads its game after it: the shared code's check, the labels, the handlers, the
# restart), "alone" (a first run with no other addon), "scenarios" (all of them), or a word a scenario's name holds.
# A deliberate break is linked to the part that must catch it (tools/breaks.py), and runs that alone.
PARTS = ("static", "tests", "smoke", "alone", "scenarios")


def compile_problems():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    sources, problems = sorted(ADDONS.rglob("*.lua")), []
    for path in sources:
        result = lua.globals().loadstring(path.read_text(encoding="utf-8"), "@" + rel(path))
        if isinstance(result, tuple) and result[1]:
            problems.append(f"compile: {result[1]}")
    print(f"compile: {len(sources)} files")
    return problems, sources


def part_static(sources):
    problems = []
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
    used_enums = checks.addon_enums(sources)
    enums = checks.enum_problems(used_enums, checks.documented_enums())
    print(f"enums: {len(used_enums)} named, {len(enums)} not in this build's docs nor Blizzard's code")
    problems += enums

    needs_path = ADDONS / NEEDS_FILE
    shipped = [p for p in sorted((ADDONS / "KaLiHUD").rglob("*.lua")) if p != needs_path]
    found = checks.needs(shipped, checks.documented_functions(called_by_blizzard), defined_in, templates_in, fonts_in)
    expected = checks.needs_lua(found)
    if "--write-needs" in sys.argv:
        needs_path.parent.mkdir(parents=True, exist_ok=True)
        needs_path.write_text(expected, encoding="utf-8", newline="\n")
    elif not needs_path.exists() or needs_path.read_text(encoding="utf-8") != expected:
        problems.append(f"needs: {rel(needs_path)} is out of date: run hud/tools/run_tests.py --write-needs")
    print(f"needs: {len(found['globals'])} globals, {len(found['events'])} events, {len(found['atlases'])} atlases, "
          f"{len(found['templates'])} templates, {len(found['cvars'])} CVars, {len(found['strings'])} strings")
    import make_effects
    effects, spells = make_effects.build()
    effects_path = ADDONS / "KaLiHUD/Data/Effects.lua"
    if not effects_path.exists() or effects_path.read_text(encoding="utf-8") != effects:
        problems.append(f"effects: {rel(effects_path)} isn't this build's: run hud/tools/make_effects.py")
    print(f"effects: {spells} spells whose auras change the sheet's attributes")
    import make_zones
    zones, zone_maps = make_zones.build()
    zones_path = ADDONS / "KaLiHUD/Data/Zones.lua"
    if not zones_path.exists() or zones_path.read_text(encoding="utf-8") != zones:
        problems.append(f"zones: {rel(zones_path)} isn't this build's: run hud/tools/make_zones.py")
    print(f"zones: {zone_maps} zone maps with the levels Forever's Group Finder suggests")
    import make_fishing
    fishing, (fishing_zones, fishing_subzones, fishing_instances) = make_fishing.build()
    fishing_path = ADDONS / "KaLiHUD/Data/Fishing.lua"
    if not fishing_path.exists() or fishing_path.read_text(encoding="utf-8") != fishing:
        problems.append(f"fishing: {rel(fishing_path)} isn't this build's: run hud/tools/make_fishing.py")
    print(f"fishing: {fishing_zones} zone maps, {fishing_subzones} sub-zones and {fishing_instances} dungeons with the"
          " original game's base fishing skill")
    import make_basestats
    basestats, pairs = make_basestats.build()
    basestats_path = ADDONS / "KaLiHUD/Data/BaseStats.lua"
    if not basestats_path.exists() or basestats_path.read_text(encoding="utf-8") != basestats:
        problems.append(f"basestats: {rel(basestats_path)} isn't its table's: run hud/tools/make_basestats.py")
    print(f"basestats: {pairs} classes' base attributes at levels 1 to 60, the original game's, and "
          f"{len(make_basestats.OFFSETS)} races' offsets")
    package, count = checks.package_problems("KaLiHUD")
    print(f"package: {count} files, {len(package)} problems")
    problems += package
    nan = checks.self_compare_problems(shipped)
    print(f"nan: {len(nan)} values compared with themselves in the shipped addon")
    problems += nan
    secret, hidden = checks.secret_problems(shipped)
    print(f"secret: {hidden} calls whose result the game may hide, {len(secret)} not read through ns.Plain")
    problems += secret
    places = places_problems(shipped)
    print(f"places: {len(places)} mentions of the saved places outside the hub's own file")
    problems += places
    return problems


def part_tests():
    lua, load_addon = runtime()
    load_addon("KaLiHUD")
    load_addon("KaLiHUD_Tests")
    report = lua.eval("KaLiHUDTests.Run()")
    print(report.text)
    return [f"tests: {report.summary}"] if report.failed > 0 else []


def smoke_session(at=None):
    """The smoke's session, whole; or, for a text one of its checks says (`at`), with only the block that holds that
    check: the session's blocks (each a line `do` alone, to its `end`) are scopes of their own, so one left out takes
    no name another needs, and what stands between the blocks is always run (a block the rest stands on says so after
    its `do`, and is never left out). Whether a block can stand without those before it is for who asks to know:
    `--only blocks` tries each on the code as it is, and tools/breaks.py the one it means to use. A text no block
    holds, among what's always run: no block at all. `at` a number: the block that starts at that line.
    Returns the source, and the lines of the blocks kept (none: an empty list); None for the whole session."""
    text = (HUD_LUA / "smoke.lua").read_text(encoding="utf-8")
    if at is None or at == "":
        return text, None
    if isinstance(at, str):
        # what a check says often ends in what it found ("...: 3 for 2"): the longest start of the text that the
        # session's source holds, a score of letters at the least
        while len(at) > 20 and at not in text:
            at = at[:-1]
    lines = text.split("\n")
    starts = [i for i, line in enumerate(lines) if line == "do"]
    # every block that says the text: two checks may say the same words
    kept = []
    for start in starts:
        end = next(j for j in range(start + 1, len(lines)) if lines[j].startswith("end"))
        if start + 1 == at or isinstance(at, str) and any(at in line for line in lines[start:end + 1]):
            kept.append(start)
    if not kept and not (at == 0 or isinstance(at, str) and any(at in line for line in lines)):
        return text, None
    for start in starts:
        if start not in kept:
            lines[start] = "if false then"
    return "\n".join(lines), [start + 1 for start in kept]


def smoke_blocks():
    """The lines the session's blocks start at (smoke_session), 0 first for none of them."""
    lines = (HUD_LUA / "smoke.lua").read_text(encoding="utf-8").split("\n")
    return [0] + [i + 1 for i, line in enumerate(lines) if line == "do"]


def part_blocks():
    """Each block of the smoke's session alone, with what's always run: one that fails so stands on a block before
    it, and a deliberate break whose check it holds runs the whole session (tools/breaks.py). Not part of a whole
    run: some minutes."""
    problems = []
    for block in smoke_blocks():
        lua, load_addon = runtime()
        load_addon("KaLiHUD")
        if (ADDONS / "KaLiHUD_Probe").exists():
            load_addon("KaLiHUD_Probe")
        try:
            failures = list(lua.execute(smoke_session(block)[0]).values())
        except Exception as error:
            failures = [f"error: {str(error).splitlines()[0]}"]
        where = f"line {block}" if block else "none"
        print(f"block {where}: {'alone' if not failures else 'NOT ALONE: ' + failures[0][:90]}", flush=True)
        problems += [f"blocks: the block at {where} doesn't pass alone: {failures[0][:120]}"] if failures else []
    return problems


def part_smoke(at=None):
    problems = []
    lua, load_addon = runtime()
    load_addon("KaLiHUD")
    sounds, played = sound_problems(lua)
    print(f"sounds: {played} kits played, {len(sounds)} not in this build")
    problems += sounds
    if (ADDONS / "KaLiHUD_Probe").exists():
        load_addon("KaLiHUD_Probe")
    session, blocks = smoke_session(at)
    failures = list(lua.execute(session).values())
    print(f"smoke: {'PASS' if not failures else 'FAIL'}"
          + (f" (the block at line {', '.join(map(str, blocks))} alone)" if blocks
             else " (no block, what stands between them)" if blocks is not None else ""))
    problems += [f"smoke: {f}" for f in failures]
    if blocks is not None:
        return problems
    shared_failures = checks.shared_smoke(lua, "KaLiHUD")
    print(f"shared smoke: {'PASS' if not shared_failures else 'FAIL'}")
    problems += shared_failures
    misfits, measured = labels.problems(lua, "KaLiHUDDev", "KaLiHUDEditModeDialog")
    print(measured)
    problems += misfits
    leaks = sorted(set(lua.globals().KALI_LEAKS.values()))
    problems += [f"global written: {leak}" for leak in leaks]
    bare, handed = handler_problems(lua)
    print(f"handlers: {handed} of the addon's own handed to the game in the session, {len(bare)} not guarded")
    problems += bare
    restart = restart_problems(lua, load_addon)
    print(f"restart: {len(restart)} problems")
    problems += restart
    return problems


def main():
    import time
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None
    problems, sources = compile_problems()

    def part(name, run):
        if only is None or name in only:
            started = time.time()
            found = run()
            problems.extend(found)
            print(f"[{name}: {time.time() - started:.1f} s]")

    part("static", lambda: part_static(sources))
    part("tests", part_tests)
    # --at <text>: of the smoke, the block whose check says that text alone (smoke_session)
    at = sys.argv[sys.argv.index("--at") + 1] if "--at" in sys.argv else None
    at = int(at) if at and at.isdigit() else at
    part("smoke", lambda: part_smoke(at))
    if only and "blocks" in only:
        part("blocks", part_blocks)

    def alone():
        found = alone_problems()
        print(f"alone: {len(found)} problems")
        return found

    part("alone", alone)
    # the scenarios: all of them, or those a word names
    words = [word for word in only or [] if word not in PARTS and word != "blocks"]
    if only is None or "scenarios" in only or words:
        started = time.time()
        for word in ([None] if only is None or "scenarios" in only else words):
            found, ran = scenario_problems(word)
            print(f"scenarios{' ' + word if word else ''}: {ran} run, {len(found)} problems")
            problems.extend(found if ran else [f"scenarios: none named {word}"])
        print(f"[scenarios: {time.time() - started:.1f} s]")

    print()
    if problems:
        print("\n".join(problems))
        print(f"\nFAIL: {len(problems)} problem(s)")
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
