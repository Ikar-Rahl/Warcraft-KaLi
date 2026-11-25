"""Every offline check of the KaLi family, before every commit: the shared code's copies match their source and the
addons' locales hold every string it uses, every deliberate break still applies to the code as it is and its link can
run (tools/breaks.py runs them; --link finds a missing link), then each addon's own runner
(quest/tools/run_tests.py, recipe/tools/run_tests.py, hud/tools/run_tests.py), whose checks are listed at their top.
The three runners run side by side, each said whole in its turn: the run takes the longest one's time, KaLi HUD's.

Run with: python -I tools/run_tests.py [quest|recipe|hud] [--write-needs] [--only <part> [--at <what>]]
Every option goes to each runner as it is, with its value. Ends with ALL PASS, or FAIL and what failed (exit 1).
"""
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import breaks  # noqa: E402
from kali import shared  # noqa: E402
from kali.paths import HUD, QUEST, RECIPE  # noqa: E402

RUNNERS = {"quest": ("KaLi Quest", QUEST / "tools/run_tests.py"), "recipe": ("KaLi Recipe", RECIPE / "tools/run_tests.py"),
           "hud": ("KaLi HUD", HUD / "tools/run_tests.py")}
# The runners' options that take a value: that value is never an addon's name here.
VALUED = ("--only", "--at", "--addons")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    began = time.time()
    args = sys.argv[1:]
    named = {i for i, arg in enumerate(args) if arg in RUNNERS and (i == 0 or args[i - 1] not in VALUED)}
    chosen = [key for key in RUNNERS if key in {args[i] for i in named}] or list(RUNNERS)
    passed_on = [arg for i, arg in enumerate(args) if i not in named]
    # the runners first, side by side, while the rest is checked here; each says all into a file of its own
    running = {}
    for key in chosen:
        out = tempfile.TemporaryFile()
        running[key] = (subprocess.Popen([sys.executable, "-I", str(RUNNERS[key][1]), *passed_on], stdout=out,
                                         stderr=subprocess.STDOUT), out)
    failed = []
    print("== shared code ==")
    found = shared.problems()
    print("\n".join(found) if found else "every copy matches its source, and each addon's locale has every string it uses")
    if found:
        failed.append("shared code")
    print("\n== deliberate breaks ==")
    stale, count = breaks.stale()
    print("\n".join(stale) if stale else f"each of the {count} still applies: its text is found once where it goes, "
          "and its link can run")
    if any(": no link" in line or "whole smoke" in line or "no longer says" in line for line in stale):
        print("A link missing or gone: python -I tools/breaks.py tools/breaks/<file>.py <word> --link")
    if any("kept for nothing" in line for line in stale):
        print("Links kept for nothing: python -I tools/breaks.py tools/breaks/<file>.py --link drops them")
    if stale:
        failed.append("deliberate breaks")
    for key, (process, out) in running.items():
        title = RUNNERS[key][0]
        process.wait()
        out.seek(0)
        print(f"\n== {title} ==")
        print(out.read().decode("utf-8", errors="replace").rstrip(), flush=True)
        out.close()
        if process.returncode:
            failed.append(title)
    print(f"\n[{time.time() - began:.0f} s]")
    if failed:
        print("FAIL: " + ", ".join(failed))
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
