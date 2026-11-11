"""Read KaLi Quest's own saved files from the game's WTF folder, and nothing else there.

Only files named KaLiQuest*.lua under a SavedVariables folder are opened, as Ikar allowed on 2026-11-06.
The game writes them at /reload, logout and exit, so run this after one of those.

Run with: python -I quest/tools/read_saved.py [probe|dev|char|all]
  probe  the probe's report, as /kqprobe show
  dev    debug log, errors and the last in-game test run
  char   each character's layout
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import GAME, use_pylib  # noqa: E402
use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
import lupa.lua51 as lupa  # noqa: E402

ACCOUNTS = GAME / "WTF/Account"
ORDER = ["environment", "protected", "sections", "log", "quests", "cvars", "atlases", "functions", "park", "row", "item", "watch",
         "collapse", "menus", "events"]


def saved_files():
    # Account files sit in Account/<name>/SavedVariables, character files in Account/<name>/<realm>/<character>/SavedVariables.
    patterns = ["*/SavedVariables/KaLiQuest*.lua", "*/*/*/SavedVariables/KaLiQuest*.lua"]
    return sorted({p for pattern in patterns for p in ACCOUNTS.glob(pattern) if p.suffix == ".lua"})


def load(path):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    env = lua.table()
    result = lua.globals().loadstring(path.read_text(encoding="utf-8", errors="replace"), "@" + path.name)
    chunk, err = result if isinstance(result, tuple) else (result, None)
    if err:
        raise SystemExit(f"{path.name}: {err}")
    lua.globals().setfenv(chunk, env)
    chunk()
    return env


def lines_of(table):
    return [table[i] for i in range(1, len(table) + 1)] if table is not None else []


def show_probe(db):
    print(f"probe: loads {db.loads}, passive checks at {db.passiveAt}")
    for entry in lines_of(db.loadLog)[-5:]:
        print(f"    load {entry.n} at {entry.at}, build {entry.build}")
    checks = db.checks
    for name in ORDER + sorted(k for k in checks.keys() if k not in ORDER):
        c = checks[name]
        if c is None:
            continue
        print(f"\n== {name} ({c.when}){' FAILED' if c.ok is False else ''} ==")
        for line in lines_of(c.lines):
            print(line)
    counts = ", ".join(f"{k} {v}" for k, v in sorted(db.eventCounts.items())) if db.eventCounts is not None else ""
    print(f"\n== events ==\ncounts: {counts}")
    for line in lines_of(db.events)[-80:]:
        print(line)


def show_dev(db):
    print(f"debug {db.debug}, events {db.events}, chat {db.chat}")
    tests = db.lastTests
    if tests is not None:
        print(f"\n== last in-game tests ({tests.when}, v{tests.version}) ==\n{tests.text}")
    print("\n== errors ==")
    for msg, e in (db.errors.items() if db.errors is not None else []):
        print(f"x{e.count} first {e.first} last {e.last} v{e.version}\n{msg}\n{e.stack}\n")
    log = lines_of(db.log)
    print(f"\n== log, last 200 of {len(log)} ==")
    for line in log[-200:]:
        print(line)


def show_char(path, db):
    print(f"{path.parent.parent.name}: version {db.version}, nextGroupID {db.nextGroupID}, autoQuestWatch option {db.options.autoQuestWatch if db.options else None}, original {db.autoQuestWatchOriginal}")
    for i in range(1, len(db.groups) + 1):
        g = db.groups[i]
        print(f"    [{g.id}] {g.name}: {list(lines_of(g.quests))}")
    if db.repeatable is not None:
        print(f"    repeatable: {sorted(db.repeatable.keys())}")


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    # A given file instead of the game's, for checking this script.
    files = [Path(sys.argv[2])] if len(sys.argv) > 2 else saved_files()
    if not files:
        raise SystemExit("No KaLiQuest saved files yet. Log in with the addon enabled, then /reload or log out.")
    for path in files:
        env = load(path)
        if what in ("probe", "all") and env.KaLiQuestProbeDB is not None:
            show_probe(env.KaLiQuestProbeDB)
        if what in ("dev", "all") and env.KaLiQuestDevDB is not None:
            show_dev(env.KaLiQuestDevDB)
        if what in ("char", "all") and env.KaLiQuestCharDB is not None:
            show_char(path, env.KaLiQuestCharDB)


main()
