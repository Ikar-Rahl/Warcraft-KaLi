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
   game's base fishing skill of each area found in this build (hud/tools/make_fishing.py); KaLiHUD/Data/BaseStats.lua,
   each race and class's base attributes at each level, is its generator's table (hud/tools/make_basestats.py).
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

The family's tools/run_tests.py runs this beside the other runners, while it checks the shared code's copies
(tools/sync_shared.py writes them) and the deliberate breaks. Run alone with: python -I hud/tools/run_tests.py
A whole run plays its parts side by side, each in a process of its own (checks.side_by_side): it takes the smoke's
time, not their sum.
--only <part>[,<part>] runs parts of it alone (static, tests, smoke, alone, scenarios, a scenario's name, shared,
labels; "blocks" tries each block of the smoke by itself), --at <what> narrows the part: the smoke to its one block
whose check says that text, the static checks to one (api, globals, methods, enums, needs, package, nan, secret,
effects, zones, fishing, basestats, places, sounds): see "The parts of a run" below. tools/breaks.py runs each
deliberate break against the part linked to it.
--addons <dir> runs on a copy, for experiments: hud/addon is linked into the game.
"""
import csv
import importlib
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from functools import cache
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(HERE))
from kali import checks, game  # noqa: E402
from kali.kept import files, kept, stamps  # noqa: E402

ADDON = "KaLiHUD"
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
# The dialog whose texts the labels' check measures, and what opens it and the options page after a login alone.
DIALOG = "KaLiHUDEditModeDialog"
OPENS = "FakeWoW.EnterEditMode(); KaLiHUDDev.ns.EditFrame.Select(); FakeWoW.RunTimers()"


@cache
def build_words():
    """This build's French game strings, its classes' names and Blizzard's question mark: (words, classes, mark)."""
    import make_icons
    words = make_icons.global_strings("frFR")
    with open(game.tables() / "ChrClasses.frFR.csv", encoding="utf-8", newline="") as f:
        classes = {row["Filename"]: row["Name_male_lang"] for row in csv.DictReader(f)}
    constants = (game.UI_SOURCE / "AddOns/Blizzard_FrameXMLBase/Constants.lua").read_text(encoding="utf-8")
    question = re.search(r'^QUESTION_MARK_ICON = "(.*)";', constants, re.M)
    return words, classes, question.group(1).replace("\\\\", "\\") if question else None


@cache
def built(name):
    """What hud/tools/make_<name>.py gives from this build's tables (its build()), read once a process. The effects',
    seconds of reading, are kept from one run to the next while the build's tables and their generator stay the same
    (kali/kept.py)."""
    make = importlib.import_module(f"make_{name}")
    if name != "effects":
        return make.build()
    return kept("effects", (stamps(make.DB2), files(make.__file__)), make.build)


def icons_from_build(lua):
    """Gives the fake what the folders' icon library takes from the game, as this build has it in French, the fake's
    language: the game strings its icons are named by (Data/Icons.lua's `game`), every class's name (DB2 ChrClasses)
    and Blizzard's question mark (Blizzard_FrameXMLBase's Constants.lua), so the API check finds them as in game."""
    g = lua.globals()
    words, classes, question = build_words()
    icons = (ADDONS / "KaLiHUD/Data/Icons.lua").read_text(encoding="utf-8")
    for name in re.findall(r'\bgame = "(\w+)"', icons):
        if name in words:
            g[name] = words[name]
    for filename, name in classes.items():
        g.LOCALIZED_CLASS_NAMES_MALE[filename] = name
    if question:
        g.QUESTION_MARK_ICON = question


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
    names = {}
    for name, kit in re.findall(r"^\s*(\w+)\s*=\s*(\d+)", game.SOUNDKITS.read_text(encoding="utf-8"), re.M):
        names.setdefault(name, kit)
    with open(game.tables() / "SoundKit.csv", encoding="utf-8", newline="") as f:
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
# what it finds depends on nothing another left behind (the smoke is one long session, each part of it living on what
# the parts before it left: the review of 2026-11-18). New cases go here. --only <word> runs those whose name holds
# the word and nothing else, in seconds: a deliberate break names the one that must catch it (tools/breaks.py),
# "tests" for KaLiHUD_Tests alone.
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
    """Each scenario in a game of its own, side by side in threads (lupa lets go of Python's lock while a Lua state
    runs, so each runs on a core of its own: all of them in about the time of the slowest few, not their sum): its
    problems, in the scenarios' order."""
    paths = [path for path in sorted(SCENARIOS.glob("*.lua")) if not word or word in path.stem]
    # what every game takes from the build's files, read once before the threads start: each would read it itself
    build_words(), game.modified_click_defaults(), game.map_types()
    with ThreadPoolExecutor(max(1, min(8, len(paths)))) as pool:
        found = list(pool.map(scenario_run, paths))
    return [problem for problems in found for problem in problems], len(paths)


def scenario_run(path):
    """A scenario in a game of its own: what it expected and didn't find, an error of its own, and its handlers."""
    lua, load_addon = runtime()
    load_addon("KaLiHUD")
    lua.execute(PRELUDE)
    problems = []
    try:
        lua.execute(path.read_text(encoding="utf-8"))
    except Exception as error:  # a scenario that raises proves nothing: said, with its first line
        problems.append(f"scenario {path.stem}: error: {str(error).splitlines()[0]}")
    problems += [f"scenario {path.stem}: {failure}" for failure in lua.globals().FAILURES.values()]
    return problems + handler_problems(lua)[0]


# ---------- The parts of a run ----------
# A whole run plays its parts side by side (WHOLE). --only <part>[,<part>...] runs those alone, after the compile: "static"
# (what the code names against this build's game, the package, the lists made from the code; --at one of its checks),
# "tests" (KaLiHUD_Tests), "smoke" (the long session, with what reads its game after it: the shared code's check, the
# labels, the handlers, the restart; --at the block of one of its checks), "alone" (a first run with no other addon),
# "scenarios" (all of them), a word a scenario's name holds, "shared" and "labels" (their checks after a login alone).
# A deliberate break is linked to the part that must catch it (tools/breaks.py), and runs that alone.
PARTS = ("static", "tests", "smoke", "alone", "scenarios", "shared", "labels", "blocks")
SMOKE = HUD_LUA / "smoke.lua"


def part_static(sources, at):
    needs_path = ADDONS / NEEDS_FILE
    shipped = [p for p in sorted((ADDONS / "KaLiHUD").rglob("*.lua")) if p != needs_path]
    found = checks.static_checks("KaLiHUD", sources, shipped, needs_path, "hud/tools/run_tests.py")

    def table(name, file, says, said):
        def check():
            text, count = built(name)
            path = ADDONS / f"KaLiHUD/Data/{file}"
            print(said(count))
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                return [f"{name}: {rel(path)} isn't {says}: run hud/tools/make_{name}.py"]
            return []
        return name, check

    def places():
        problems = places_problems(shipped)
        print(f"places: {len(problems)} mentions of the saved places outside the hub's own file")
        return problems

    def sounds():
        lua, load_addon = runtime()
        load_addon("KaLiHUD")
        problems, played = sound_problems(lua)
        print(f"sounds: {played} kits played, {len(problems)} not in this build")
        return problems

    import make_basestats
    return checks.run_static(found + [
        table("effects", "Effects.lua", "this build's", lambda n: f"effects: {n} spells whose auras change the sheet's attributes"),
        table("zones", "Zones.lua", "this build's", lambda n: f"zones: {n} zone maps with the levels Forever's Group Finder suggests"),
        table("fishing", "Fishing.lua", "this build's", lambda n: f"fishing: {n[0]} zone maps, {n[1]} sub-zones and {n[2]} dungeons"
              " with the original game's base fishing skill"),
        table("basestats", "BaseStats.lua", "its table's", lambda n: f"basestats: {n} classes' base attributes at levels 1 to 60,"
              f" the original game's, and {len(make_basestats.OFFSETS)} races' offsets"),
        ("places", places), ("sounds", sounds)], at)


def part_blocks():
    """Each block of the smoke's session alone, with what's always run: one that fails so stands on a block before
    it, and a deliberate break whose check it holds can't be linked to it (tools/breaks.py). Not part of a whole
    run."""
    problems = []
    for block in checks.smoke_blocks(SMOKE):
        lua, _ = checks.with_probe(runtime, ADDON)
        failures = checks.smoke_run(lua, SMOKE, block)[0]
        where = f"line {block}" if block else "none"
        print(f"block {where}: {'alone' if not failures else 'NOT ALONE: ' + failures[0][:90]}", flush=True)
        problems += [f"blocks: the block at {where} doesn't pass alone: {failures[0][:120]}"] if failures else []
    return problems


def part_smoke(at=None):
    lua, load_addon, problems, blocks = checks.smoke_part(runtime, ADDON, SMOKE, at)
    if blocks is not None:
        return problems
    problems += checks.after_smoke(lua, ADDON, DIALOG)
    bare, handed = handler_problems(lua)
    print(f"handlers: {handed} of the addon's own handed to the game in the session, {len(bare)} not guarded")
    restart = restart_problems(lua, load_addon)
    print(f"restart: {len(restart)} problems")
    return problems + bare + restart


# A whole run's parts, each in a process of its own, side by side, in the order the run says them.
WHOLE = (["--only", "static"], ["--only", "tests"], ["--only", "smoke"], ["--only", "alone"], ["--only", "scenarios"])


def main():
    run = checks.Run(PARTS, words=lambda word: any(word in path.stem for path in SCENARIOS.glob("*.lua")))
    problems, sources = checks.compile_problems(say=run.report is None)
    run.problems += problems
    if run.only is None:  # a whole run: as long as its longest part, the smoke
        started = time.time()
        for said, found in checks.side_by_side(__file__, WHOLE):
            print(said, flush=True)
            run.problems += found
        print(f"[side by side: {time.time() - started:.1f} s]")
        run.end()
        return
    run.part("static", lambda: part_static(sources, run.at))
    run.part("tests", lambda: checks.tests_part(runtime, ADDON))
    run.part("smoke", lambda: part_smoke(run.at))
    if run.only and "blocks" in run.only:
        run.part("blocks", part_blocks)

    def alone():
        found = alone_problems()
        print(f"alone: {len(found)} problems")
        return found

    run.part("alone", alone)
    # the scenarios: all of them, or those a word names
    words = [word for word in run.only or [] if word not in PARTS]
    if run.only is None or "scenarios" in run.only or words:
        started = time.time()
        for word in ([None] if run.only is None or "scenarios" in run.only else words):
            found, ran = scenario_problems(word)
            print(f"scenarios{' ' + word if word else ''}: {ran} run, {len(found)} problems")
            # (a word no scenario's name holds: checks.Run has said so)
            run.problems.extend(found)
        print(f"[scenarios: {time.time() - started:.1f} s]")
    # in a whole run, both after the smoke, on what it left (part_smoke)
    if run.only:
        run.part("shared", lambda: checks.shared_part(runtime, ADDON))
        run.part("labels", lambda: checks.labels_part(runtime, ADDON, DIALOG, OPENS))
    run.end()


if __name__ == "__main__":
    main()
