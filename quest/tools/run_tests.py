"""Run KaLi Quest's Lua checks outside the game, on Lua 5.1 as the game uses.

1. Every .lua file under quest/addon/ compiles.
2. Each addon loads in its TOC's order on a fake WoW API (tools/lua/fakewow.lua). A global written that isn't on
   the allowed list is reported, which catches a missing "local".
3. KaLiQuest_Tests runs: the same tests as /kq test in game.
4. quest/tools/lua/smoke.lua starts the addon and its probe as the game would and runs every slash command of both;
   then tools/lua/smoke_shared.lua checks the shared code's copy (shared/) the same way in both addons.
5. Every C_Namespace.Function the addons name exists in this build's API documentation, and every bare global
   function they call is in the game's global API list or defined by Blizzard's own Lua.
6. Every :Method( they call is a widget method in that documentation, one Blizzard's own code defines, one they
   define themselves, or a string method. A misspelt or retail-only method name fails here, not in game.
7. KaLiQuest's folder is a complete package: the TOC's fields, an icon the game can read, every listed file
   present, every file its code names inside the addon there, and no file the TOC doesn't account for.
8. KaLiQuest/Data/Needs.lua, the list of what the addon takes from the game that it checks at login, game strings
   included, is the one its code gives today. --write-needs writes it.
9. The game's numbers the addon reads that no enum of the game holds are those its own tables give: the quest tags,
   by their names in this build's QuestInfo table.
10. Every Enum table and member the addons name is in this build's docs or read by Blizzard's own code.
11. No code of the shipped addon tests a value against itself, the usual test for nan, which the game's Lua doesn't
   honour (ns.Finite does).

The checks of 1 to 8, 10 and 11 are the family's, in tools/kali/checks.py. Run with: python -I quest/tools/run_tests.py
--addons <dir> runs on a copy, for experiments: quest/addon is linked into the game.
"""
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali import checks  # noqa: E402
from kali.paths import QUEST  # noqa: E402

checks.configure(
    ADDONS=QUEST / "addon",
    NEEDS_FILE="KaLiQuest/Data/Needs.lua",
    ALLOWED_GLOBALS={
        "KaLiQuestDev", "KaLiQuestCharDB", "KaLiQuestDevDB", "SLASH_KALIQUEST1", "SLASH_KALIQUEST2",
        "KaLiQuestTests", "KaLiQuestProbeDB", "SLASH_KQPROBE1", "SLASH_KQPROBE2",
        "KaLiQuest_Binding", "KaLiQuest_OnAddonCompartmentClick", "KaLiQuest_OnAddonCompartmentEnter",
        "KaLiQuest_OnAddonCompartmentLeave", "BINDING_HEADER_KALIQUEST", "BINDING_NAME_KALIQUEST_LOCK",
        "BINDING_NAME_KALIQUEST_COLLAPSE", "BINDING_NAME_KALIQUEST_NEXT", "BINDING_NAME_KALIQUEST_PREVIOUS",
    },
)
SMOKE = QUEST / "tools/lua/smoke.lua"
# Filter.TAG's names in the game's QuestInfo table. Raid10 and Raid25 aren't in Forever's: the API check holds them
# against Enum.QuestTag in game.
TAG_NAMES = {"elite": "Elite", "life": "Life", "pvp": "PvP", "raid": "Raid", "dungeon": "Dungeon",
             "worldevent": "World Event", "legendary": "Legendary", "raid10": None, "raid25": None}


def data_problems(lua):
    """Filter.TAG, which the API check can only partly hold against the game's enums, by the names this build's
    QuestInfo table gives its IDs."""
    with open(max(checks.DB2.iterdir()) / "QuestInfo.csv", encoding="utf-8", newline="") as f:
        names = {int(row["ID"]): row["InfoName_lang"] for row in csv.DictReader(f)}
    problems, checked = [], 0
    for key, value in lua.eval("KaLiQuestDev.ns.Filter.TAG").items():
        if key not in TAG_NAMES:
            problems.append(f"data: Filter.TAG.{key} has no name to check in TAG_NAMES")
        elif TAG_NAMES[key] is not None:
            checked += 1
            if names.get(int(value)) != TAG_NAMES[key]:
                problems.append(f"data: Filter.TAG.{key} = {value} is {names.get(int(value))!r} in QuestInfo, "
                                f"not {TAG_NAMES[key]!r}")
    return problems, checked


def main():
    problems = []
    addons, rel = checks.ADDONS, checks.rel

    lua = checks.lupa.LuaRuntime(unpack_returned_tuples=True)
    sources = sorted(addons.rglob("*.lua"))
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
    package, count = checks.package_problems("KaLiQuest")
    print(f"package: {count} files, {len(package)} problems")
    problems += package
    needs_path = addons / checks.NEEDS_FILE
    shipped = [p for p in sorted((addons / "KaLiQuest").rglob("*.lua")) if p != needs_path]
    found = checks.needs(shipped, checks.documented_functions(called_by_blizzard), defined_in, templates_in, fonts_in)
    expected = checks.needs_lua(found)
    if "--write-needs" in sys.argv:
        needs_path.write_text(expected, encoding="utf-8", newline="\n")
    elif not needs_path.exists() or needs_path.read_text(encoding="utf-8") != expected:
        problems.append(f"needs: {rel(needs_path)} is out of date: run quest/tools/run_tests.py --write-needs")
    print(f"needs: {len(found['globals'])} globals, {len(found['events'])} events, {len(found['atlases'])} atlases, "
          f"{len(found['templates'])} templates, {len(found['cvars'])} CVars, {len(found['strings'])} strings")
    used_enums = checks.addon_enums(sources)
    enums = checks.enum_problems(used_enums, checks.documented_enums())
    print(f"enums: {len(used_enums)} named, {len(enums)} not in this build's docs nor Blizzard's code")
    problems += enums
    nan = checks.self_compare_problems(shipped)
    print(f"nan: {len(nan)} values compared with themselves in the shipped addon")
    problems += nan

    lua, load_addon = checks.runtime()
    load_addon("KaLiQuest")
    load_addon("KaLiQuest_Tests")
    data, checked = data_problems(lua)
    print(f"data: {checked} quest tags checked against QuestInfo, {len(data)} problems")
    problems += data
    report = lua.eval("KaLiQuestTests.Run()")
    print(report.text)
    if report.failed > 0:
        problems.append(f"tests: {report.summary}")

    lua, load_addon = checks.runtime()
    load_addon("KaLiQuest")
    load_addon("KaLiQuest_Probe")
    failures = lua.execute(SMOKE.read_text(encoding="utf-8"))
    failures = list(failures.values())
    print(f"smoke: {'PASS' if not failures else 'FAIL'}")
    problems += [f"smoke: {f}" for f in failures]
    shared_failures = checks.shared_smoke(lua, "KaLiQuest")
    print(f"shared: {'PASS' if not shared_failures else 'FAIL'}")
    problems += shared_failures
    leaks = sorted(set(lua.globals().KALI_LEAKS.values()))
    problems += [f"global written: {leak}" for leak in leaks]

    print()
    if problems:
        print("\n".join(problems))
        print(f"\nFAIL: {len(problems)} problem(s)")
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
