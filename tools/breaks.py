"""Deliberate breaks: plant one fault at a time in a copy of the code, and see the tests fail. A fault they don't see
is a gap in them; a fix proven this way stays proven.

Run with: python -I tools/breaks.py <breaks file> [word]
The breaks file is Python and sets BREAKS = [(name, path, old, new), ...]. path is the repository's, under
quest/addon/, recipe/addon/ or shared/; old must be found exactly once there, and becomes new. A break in shared/ goes
into each addon's copy, and each addon's tests must catch it; a fifth item, ("quest",) or ("recipe",), limits it to
the addons where it changes anything (a hook only one addon sets). With a word, only the breaks whose name holds it run.
Each run works on a copy in a temporary folder: the repository, linked into the game, is never touched.
Exits 1 when a break goes unnoticed.
"""
import runpy
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali import shared  # noqa: E402
from kali.paths import ROOT  # noqa: E402

RUNNERS = {"quest": ROOT / "quest/tools/run_tests.py", "recipe": ROOT / "recipe/tools/run_tests.py"}


def targets(path, only=None):
    """(addon key, the file's path inside the addon's folder of folders) for each place the break goes."""
    parts = Path(path).parts
    if parts[0] in ("quest", "recipe") and parts[1] == "addon":
        return [(parts[0], Path(*parts[2:]))]
    if parts[0] == "shared":
        source = ROOT / path
        return [(key, shared.copy_path(source, folders, name).relative_to(folders))
                for key, (folders, name) in shared.ADDONS.items() if not only or key in only]
    raise SystemExit(f"{path}: not under quest/addon/, recipe/addon/ or shared/")


def first_problem(output):
    """What the runner listed first after its blank line, before its FAIL count; else its last line."""
    lines = output.splitlines()
    end = next((i for i, line in enumerate(lines) if line.startswith("FAIL:")), len(lines))
    blank = max((i for i, line in enumerate(lines[:end]) if line == ""), default=end - 1)
    return lines[blank + 1] if blank + 1 < end else (lines[-1] if lines else "")


def run(name, key, inside, old, new):
    """True when the addon's tests catch the break, None when old isn't there exactly once."""
    folders = shared.ADDONS[key][0]
    work = Path(tempfile.mkdtemp(prefix="kali-break-"))
    try:
        copy = work / "addon"
        shutil.copytree(folders, copy)
        target = copy / inside
        text = target.read_text(encoding="utf-8")
        if text.count(old) != 1:
            return None, f"found {text.count(old)} times in {key}'s {inside.as_posix()}"
        target.write_text(text.replace(old, new), encoding="utf-8", newline="\n")
        # A runner's error output may come in Windows' own encoding: read whatever it is.
        done = subprocess.run([sys.executable, "-I", str(RUNNERS[key]), "--addons", str(copy)],
                              capture_output=True, text=True, encoding="utf-8", errors="replace")
        return done.returncode != 0, first_problem((done.stdout or "") + (done.stderr or ""))[:110]
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    breaks = runpy.run_path(sys.argv[1])["BREAKS"]
    word = sys.argv[2] if len(sys.argv) > 2 else None
    chosen = [b for b in breaks if not word or word in b[0]]
    missed = skipped = 0
    for name, path, old, new, *only in chosen:
        results = [(key, *run(name, key, inside, old, new)) for key, inside in targets(path, only[0] if only else None)]
        if any(caught is None for _, caught, _ in results):
            skipped += 1
            print(f"SKIP: {name}  ({'; '.join(why for _, caught, why in results if caught is None)})", flush=True)
            continue
        gaps = [key for key, caught, _ in results if not caught]
        missed += bool(gaps)
        how = "; ".join(f"{key}: {why}" for key, caught, why in results if caught)
        print(f"{'MISSED by ' + ', '.join(gaps) if gaps else 'caught'}: {name}  {how}", flush=True)
    print(f"\n{len(chosen) - missed - skipped}/{len(chosen)} caught" + (f", {skipped} skipped" if skipped else ""))
    sys.exit(1 if missed or skipped else 0)


if __name__ == "__main__":
    main()
