"""Read KaLi Recipe's own saved files from the game's WTF folder, and nothing else there (KaLi Quest's rule).

Only files named KaLiRecipe*.lua under an account's SavedVariables folder, and the characters' KaLiRecipe.lua (the
notebook's copies), are opened, and only read. The game writes them at /reload, logout and exit, so run this after one
of those.

Run with: python -I recipe/tools/read_saved.py [probe|dev|notebook|check|all]
  probe     the probe's report, as /krprobe show
  dev       the API check, errors, game warnings, the last in-game test run, the log's end
  notebook  characters (numbers only), what was seen, by profession
  check     the notebook and each character's copy, opened by the addon's own code: what it would upgrade, repair or
            set aside, and whether it writes back as it reads (docs/saved-data.md)
"""
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import GAME, use_pylib  # noqa: E402

use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
import lupa.lua51 as lupa  # noqa: E402

ACCOUNTS = GAME / "WTF/Account"


def saved_files():
    return sorted(p for p in ACCOUNTS.glob("*/SavedVariables/KaLiRecipe*.lua") if p.suffix == ".lua")


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


def py(v):
    if hasattr(v, "items"):
        return {k: py(x) for k, x in v.items()}
    return v


def show(title, value, indent=""):
    if isinstance(value, dict):
        print(f"{indent}{title}:")
        for k in sorted(value, key=str):
            show(str(k), value[k], indent + "  ")
    else:
        print(f"{indent}{title}: {value}")


def when(t):
    return datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M") if isinstance(t, (int, float)) else "never"


def check():
    """Each account's notebook and every character's copy, opened by the addon's own code (Core/DB.lua, on the offline
    fake run_tests.py builds), writing nothing: what opening would upgrade, repair or set aside, whether the
    notebook writes back as it reads, and what each copy holds against it. Exits 1 when a file can't be opened."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import run_tests as rt  # noqa: E402

    lua, load_addon = rt.runtime()
    load_addon("KaLiRecipe")
    load_addon("KaLiRecipe_Tests")
    T = lua.globals().KaLiRecipeTests
    DB = lua.eval("KaLiRecipeDev.ns.DB")
    count = lua.eval("function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end")
    sightings = lua.eval("function(db) local n = 0 for _, l in pairs(db.sightings or {}) do n = n + #l end return n end")
    bad = 0
    for account in sorted(p for p in ACCOUNTS.iterdir() if p.is_dir()):
        path = account / "SavedVariables/KaLiRecipe.lua"
        copies = sorted(account.glob("*/*/SavedVariables/KaLiRecipe.lua"))
        if not path.exists() and not copies:
            continue
        print(f"== account {account.name}")
        saved = None
        if not path.exists():
            print("  notebook: no file")
        else:
            env = T.ReadSaved(path.read_text(encoding="utf-8", errors="replace"))
            saved = env and env.KaLiRecipeDB
            if not saved:
                print("  notebook: THE FILE DOESN'T READ (the game would see none)")
                bad += 1
        if saved:
            meta = saved.meta
            print(f"  notebook: format {saved.version}, last written by {meta and meta.writer or 'a version that does not say'} on "
                  f"{when(meta and meta.written)}; recipes {count(saved.sightings)}, sightings {sightings(saved)}, "
                  f"characters {count(saved.chars)}, options saved {count(saved.options)}")
            result = DB.Load(saved)
            db, fixed, aside = (tuple(result) + (None, None))[:3] if isinstance(result, tuple) else (result, 0, 0)
            if not db:
                print(f"  OPENING REFUSED, the file left as it is: {fixed}")
                bad += 1
            else:
                upgraded = f", upgraded from format {saved.version}" if saved.version != db.version else ""
                print(f"  opens: format {db.version}{upgraded}, repaired {fixed}, set aside {aside}")
                for i in range(1, len(db.setAside) + 1):
                    e = db.setAside[i]
                    print(f"    set aside {when(e.t)} {e.at}: {e.why}")
                for part in ("sightings", "chars", "reqs", "names"):
                    d = T.Diff(saved[part], db[part], part)
                    print(f"  {part}: {'as in the file' if not d else 'changed, first: ' + d}")
                back = T.ReadSaved(T.Saved("KaLiRecipeDB", db))
                d = T.Diff(db, back and back.KaLiRecipeDB, "KaLiRecipeDB")
                print("  writes back as it reads" if not d else f"  WRITES BACK DIFFERENT: {d}")
                bad += 1 if d else 0
        for n, cp in enumerate(copies, 1):
            env = T.ReadSaved(cp.read_text(encoding="utf-8", errors="replace"))
            copy = env and env.KaLiRecipeCopyDB
            if not copy:
                print(f"  character {n}: {'no copy in its file' if env else 'ITS FILE DOES NOT READ'}")
                continue
            result = DB.Open(saved, copy)
            data, info = tuple(result) if isinstance(result, tuple) else (result, None)
            if not data:
                print(f"  character {n}: copy of {when(copy.at)}; opening refused: {info}")
                continue
            held = f"copy of {when(copy.at)} by {copy.writer}, recipes {count(copy.data and copy.data.sightings)}"
            if info.copyRefused:
                print(f"  character {n}: {held}; can't be read, left as it is: {info.copyRefused}")
            elif info.restored:
                print(f"  character {n}: {held}; would bring the notebook back")
            else:
                print(f"  character {n}: {held}; would add {info.recovered} to the notebook")
    sys.exit(1 if bad else 0)


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what == "check":
        check()
        return
    files = saved_files()
    if not files:
        print("No KaLiRecipe saved file yet: log in with the addon, then /reload.")
        return
    for path in files:
        env = load(path)
        print(f"== {path.parent.parent.name}/{path.name}")
        if what in ("probe", "all") and env["KaLiRecipeProbeDB"]:
            show("probe", py(env["KaLiRecipeProbeDB"]))
        dev = env["KaLiRecipeDevDB"] and py(env["KaLiRecipeDevDB"])
        if what in ("dev", "all") and dev:
            for key in ("apiChecks", "errors", "gameWarnings", "lastTests", "reagentColor"):
                if key in dev:
                    show(key, dev[key])
            log = dev.get("log") or {}
            for i in sorted(log)[-40:]:
                print("  log:", log[i])
        db = env["KaLiRecipeDB"] and py(env["KaLiRecipeDB"])
        if what in ("notebook", "all") and db:
            for n, (key, c) in enumerate(sorted((db.get("chars") or {}).items()), 1):
                print(f"character {n}: professions {c.get('profs')}, knows {len(c.get('known') or {})}, "
                      f"recipe items bags {c.get('bags')}, bank {c.get('bank')}")
            seen = db.get("sightings") or {}
            print(f"recipes seen: {len(seen)}")
            for spell in sorted(seen):
                places = seen[spell]
                print(f"  {spell}: " + ", ".join(f"{s.get('k')} npc {s.get('npc')} map {s.get('map')}" for s in places.values()))
            show("options", db.get("options") or {})


main()
