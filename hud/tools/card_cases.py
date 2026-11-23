"""The stat cards KaLi HUD kept in game (UI/Hub/Infos/StatCheck.lua: each card that couldn't account for all of the
game's figure, with what it read; every card on /kh stats), as cases for hud/tools/lua/scenarios/cards.lua. Ikar
2026-11-22: "ok, go, and add that to the error report".

Without a number: a line a card kept, in the bug report's order (those that can't account for all of it first, the
last seen first). With one: that card as a case, its state joined, to paste into the scenario's CASES once its card
says it right, with what it must leave then (expect.gaps: none, unless the game hides a source). The addon's own
StatCheck.lua, loaded here, writes it as it writes the report. Writes nothing.
Run with: python -I hud/tools/card_cases.py [number] [path to KaLiHUD.lua]
The saved file is the account's, under the game's folder (KALI_GAME), written at a /reload or a logout.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.paths import GAME, use_pylib  # noqa: E402

use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
from lupa.lua51 import LuaRuntime  # noqa: E402

STATCHECK = ROOT / "hud/addon/KaLiHUD/UI/Hub/Infos/StatCheck.lua"
# What StatCheck.lua needs of the addon to load and to write: the saved table, finite numbers, the errors' clear.
LOAD = """
return function(code, saved)
    local ns = { DevDB = function() return saved end, Debug = { Clear = function() end } }
    function ns.Finite(v)
        return type(v) == "number" and not tostring(v):find("[^%d%.,eE%+%-]")
    end
    local chunk = assert(loadstring(code, "@StatCheck.lua"))
    chunk("KaLiHUD", ns)
    return ns.StatCheck
end
"""
# The saved file read as data: its own globals, nothing of the runtime's.
READ = """
return function(text)
    local env = {}
    local chunk = assert(loadstring(text, "@KaLiHUD.lua"))
    setfenv(chunk, env)
    chunk()
    return env
end
"""


def saved_file(args):
    for a in args:
        if not a.isdigit():
            return Path(a)
    found = sorted((GAME / "WTF/Account").glob("*/SavedVariables/KaLiHUD.lua"), key=lambda p: p.stat().st_mtime)
    if not found:
        sys.exit("no KaLiHUD.lua under the game's WTF folder: /reload in game first")
    return found[-1]


def main():
    args = sys.argv[1:]
    number = next((int(a) for a in args if a.isdigit()), None)
    path = saved_file(args)
    lua = LuaRuntime(unpack_returned_tuples=True)
    env = lua.execute(READ)(path.read_text(encoding="utf-8"))
    dev = env.KaLiHUDDevDB
    if not dev or not dev.statChecks or not dev.statChecks.cards:
        sys.exit(f"{path}: no stat card kept")
    check = lua.execute(LOAD)(STATCHECK.read_text(encoding="utf-8"), dev)
    cards, kept = check.Sorted()
    if number is None:
        for line in str(check.Text()).split("\n"):
            if not line.startswith("case "):
                print(line)
        return
    e = cards[number]
    if e is None:
        sys.exit(f"no card {number}: {len(cards)} kept")
    case = check.Case(e, kept)
    state = case.state or {}
    case.name = f"{e.stat}, level {state.level}, {e.last} (build {e.build})"
    case.expect = lua.eval("{ gaps = {} }")
    print(check.Literal(case) + ",")


if __name__ == "__main__":
    main()
