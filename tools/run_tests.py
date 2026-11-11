"""Every offline check of the KaLi family, before every commit: the shared code's copies match their source and the
addons' locales hold every string it uses, then each addon's own runner (quest/tools/run_tests.py,
recipe/tools/run_tests.py), whose checks are listed at their top.

Run with: python -I tools/run_tests.py [quest|recipe] [--write-needs]
Ends with ALL PASS, or FAIL and what failed (exit 1).
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali import shared  # noqa: E402
from kali.paths import QUEST, RECIPE  # noqa: E402

RUNNERS = {"quest": ("KaLi Quest", QUEST / "tools/run_tests.py"), "recipe": ("KaLi Recipe", RECIPE / "tools/run_tests.py")}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    chosen = [key for key in RUNNERS if key in sys.argv[1:]] or list(RUNNERS)
    passed_on = [arg for arg in sys.argv[1:] if arg.startswith("--")]
    failed = []
    print("== shared code ==")
    found = shared.problems()
    print("\n".join(found) if found else "every copy matches its source, and each addon's locale has every string it uses")
    if found:
        failed.append("shared code")
    for key in chosen:
        title, runner = RUNNERS[key]
        print(f"\n== {title} ==", flush=True)
        if subprocess.run([sys.executable, "-I", str(runner), *passed_on]).returncode:
            failed.append(title)
    print()
    if failed:
        print("FAIL: " + ", ".join(failed))
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
