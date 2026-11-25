"""Run KaLi Quest's Lua checks outside the game, on Lua 5.1 as the game uses.

1. Every .lua file under quest/addon/ compiles.
2. Each addon loads in its TOC's order on a fake WoW API (tools/lua/fakewow.lua). A global written that isn't on
   the allowed list is reported, which catches a missing "local".
3. KaLiQuest_Tests runs: the same tests as /kq test in game.
4. quest/tools/lua/smoke.lua starts the addon and its probe as the game would and runs every slash command of both;
   then tools/lua/smoke_shared.lua checks the shared code's copy (shared/) the same way in every addon.
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
12. Every call of a game function whose result the API docs say may come as a secret value (a unit's GUID or name
   where identities are restricted) reads it through ns.Plain.
13. Every text of the Edit Mode dialog and of the options page fits the room its frame gives it, in each language the
   addon speaks, measured with the game's own font (tools/kali/labels.py).

The checks of 1 to 8 and 10 to 13 are the family's, in tools/kali. Run with: python -I quest/tools/run_tests.py
--addons <dir> runs on a copy, for experiments: quest/addon is linked into the game.
--only <part>[,<part>] runs parts of it alone, after the compile (tools/kali/checks.py, "The parts of a run"): static
(5 to 12, --at <check> one of them: api, globals, methods, enums, needs, package, nan, secret, data), tests (3), smoke
(4 with the shared code's and the labels' checks after it; --at <text> the smoke's one block whose check says that
text), shared (the shared code's checks after a login alone), labels (13 after a login alone). tools/breaks.py runs
each deliberate break against the part linked to it, in seconds.
"""
import csv
import sys
from functools import cache
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali import checks, game  # noqa: E402
from kali.paths import QUEST  # noqa: E402

ADDON = "KaLiQuest"
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
# The dialog whose texts the labels' check measures, and what opens it and the options page after a login alone.
DIALOG = "KaLiQuestEditModeDialog"
OPENS = "KaLiQuestDev.ns.EditFrame.OpenEditMode(); FakeWoW.RunTimers()"
# Filter.TAG's names in the game's QuestInfo table. Raid10 and Raid25 aren't in Forever's: the API check holds them
# against Enum.QuestTag in game.
TAG_NAMES = {"elite": "Elite", "life": "Life", "pvp": "PvP", "raid": "Raid", "dungeon": "Dungeon",
             "worldevent": "World Event", "legendary": "Legendary", "raid10": None, "raid25": None}


@cache
def quest_info():
    """This build's QuestInfo table: { ID: name }."""
    with open(game.tables() / "QuestInfo.csv", encoding="utf-8", newline="") as f:
        return {int(row["ID"]): row["InfoName_lang"] for row in csv.DictReader(f)}


def data_problems(lua):
    """Filter.TAG, which the API check can only partly hold against the game's enums, by the names this build's
    QuestInfo table gives its IDs."""
    names = quest_info()
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


PARTS = ("static", "tests", "smoke", "shared", "labels")


def part_static(sources, at):
    addons = checks.ADDONS
    needs_path = addons / checks.NEEDS_FILE
    shipped = [p for p in sorted((addons / ADDON).rglob("*.lua")) if p != needs_path]

    def data():
        lua, load_addon = checks.runtime()
        load_addon(ADDON)
        problems, checked = data_problems(lua)
        print(f"data: {checked} quest tags checked against QuestInfo, {len(problems)} problems")
        return problems

    found = checks.static_checks(ADDON, sources, shipped, needs_path, "quest/tools/run_tests.py")
    return checks.run_static(found + [("data", data)], at)


def part_smoke(at):
    lua, _, problems, blocks = checks.smoke_part(checks.runtime, ADDON, SMOKE, at)
    if blocks is not None:
        return problems
    return problems + checks.after_smoke(lua, ADDON, DIALOG)


def main():
    run = checks.Run(PARTS)
    problems, sources = checks.compile_problems()
    run.problems += problems
    run.part("static", lambda: part_static(sources, run.at))
    run.part("tests", lambda: checks.tests_part(checks.runtime, ADDON))
    run.part("smoke", lambda: part_smoke(run.at))
    # in a whole run, both after the smoke, on what it left (part_smoke)
    if run.only:
        run.part("shared", lambda: checks.shared_part(checks.runtime, ADDON))
        run.part("labels", lambda: checks.labels_part(checks.runtime, ADDON, DIALOG, OPENS))
    run.end()


if __name__ == "__main__":
    main()
