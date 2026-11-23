"""Deliberate breaks: plant one fault at a time in a copy of the code, and see the tests fail. A fault they don't see
is a gap in them; a fix proven this way stays proven.

Run with: python -I tools/breaks.py <breaks file> [word] [--link] [--slice i/n]
The breaks file is Python and sets BREAKS = [(name, path, old, new), ...]. path is the repository's, under
quest/addon/, recipe/addon/, hud/addon/ or shared/; old must be found exactly once there, and becomes new. A break in
shared/ goes into each addon's copy, and each addon's tests must catch it; a further item that is a tuple, such as
("quest",) or ("quest", "recipe"), limits it to the addons where it changes anything (a hook only one addon sets, a
part only some use). With a word, only the breaks whose name holds it run.
Each run works on a copy in a temporary folder: the repository, linked into the game, is never touched.
A runner that hasn't finished after HUNG seconds is stopped, the break caught: its tests never pass (a loop the break
let run forever held a whole run, 2026-11-17).
Exits 1 when a break goes unnoticed.

A break is linked to the test that must catch it, and runs that alone (Ikar 2026-11-18: "Link each break with test on
interest, and run only those"; a break replayed its addon's whole run, minutes each, hours for a file of them). For a
runner made of parts (PARTS: KaLi HUD's, hud/tools/run_tests.py --only <part>) the link is the part, and in its smoke
the block whose check caught it (--at <what the check says>): seconds. A link is found once, by --link, which tries
the parts in turn on each break that has none and keeps what it finds in tools/breaks/links/<breaks file>.json; a
break may name its own as a further item, "test:<part>" (a scenario's name is one). The block a link names must pass
alone on the code as it is, or a failure of its own would pass for the break caught: tried once for each block met, the
whole part run in its place when it doesn't (--blocks-stand: not tried, for a run made just after the runner's own
`--only blocks` passed, which tries them all). A break with no link runs the whole runner, as all did.
--slice i/n takes each nth break from the ith, for several runs side by side; each keeps its links in a file of its
own, and --merge gathers them.

A break whose old text the code no longer holds proves nothing, and only running it, which takes minutes, said so:
tools/run_tests.py asks stale() each time, which reads every breaks file and runs none.
"""
import json
import re
import runpy
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali import shared  # noqa: E402
from kali.paths import ROOT  # noqa: E402

RUNNERS = {"quest": ROOT / "quest/tools/run_tests.py", "recipe": ROOT / "recipe/tools/run_tests.py",
           "hud": ROOT / "hud/tools/run_tests.py"}
# A runner's whole run takes a few minutes; ten times that is a loop that never ends. One part of it alone takes a
# minute at the most on a busy machine: five are a loop.
HUNG = 1200
PART_HUNG = 300
# The runners made of parts, each run alone with --only, in the order --link tries them: the quickest and the likeliest
# first. Together they are the whole run.
PARTS = {"hud": ("smoke", "tests", "scenarios", "alone", "static")}
# Files whose breaks the unit tests catch more often than not: tried first there.
UNIT_FIRST = ("Core/DB.lua", "Core/Geometry.lua", "Core/Format.lua")
LINKS = ROOT / "tools/breaks/links"
BLOCK = re.compile(r"\(the block at line ([\d, ]+) alone\)|\((no block), what stands between them\)")


def targets(path, only=None):
    """(addon key, the file's path inside the addon's folder of folders) for each place the break goes."""
    parts = Path(path).parts
    if parts[0] in RUNNERS and parts[1] == "addon":
        return [(parts[0], Path(*parts[2:]))]
    if parts[0] == "shared":
        source = ROOT / path
        return [(key, shared.copy_path(source, folders, name).relative_to(folders))
                for key, (folders, name) in shared.ADDONS.items() if not only or key in only]
    raise SystemExit(f"{path}: not under quest/addon/, recipe/addon/, hud/addon/ or shared/")


def extras(rest):
    """A break's items past its four: the addons a shared one is limited to (a tuple), and its own link, the part that
    must catch it ("test:<part>")."""
    only = next((item for item in rest if isinstance(item, tuple)), None)
    test = next((item[len("test:"):] for item in rest if isinstance(item, str) and item.startswith("test:")), None)
    return only, test


def stale():
    """(what's wrong, how many breaks) over every file of tools/breaks: a break whose old text isn't found exactly once
    in each place it goes, one that changes nothing, two under one name. Reads only."""
    problems, count = [], 0
    for file in sorted((ROOT / "tools/breaks").glob("*.py")):
        names = set()
        for name, path, old, new, *rest in runpy.run_path(str(file))["BREAKS"]:
            count += 1
            where = f"tools/breaks/{file.name}: {name}"
            if name in names:
                problems.append(f"{where}: a second break under that name")
            names.add(name)
            if old == new:
                problems.append(f"{where}: changes nothing")
            for key, inside in targets(path, extras(rest)[0]):
                found = (shared.ADDONS[key][0] / inside).read_text(encoding="utf-8").count(old)
                if found != 1:
                    problems.append(f"{where}: its text is found {found} times in {key}'s {inside.as_posix()}")
    return problems, count


def first_problem(output):
    """What the runner listed first: its problems come after a blank line and end at the blank line before its FAIL
    count. The needs list out of date is passed over when something else is listed too: any break that changes which
    of the game's names the code uses trips it, and it says nothing of the test meant for the break. A runner stopped
    by a Lua error has no list: the error's own line then, else its last line."""
    lines = output.splitlines()
    end = next((i for i, line in enumerate(lines) if line.startswith("FAIL:")), None)
    if end is None:
        return next((line.strip() for line in lines if "LuaError:" in line), lines[-1] if lines else "")
    while end > 0 and lines[end - 1] == "":
        end -= 1
    blank = max((i for i, line in enumerate(lines[:end]) if line == ""), default=-1)
    listed = lines[blank + 1:end]
    return next((line for line in listed if not line.startswith("needs:")), listed[0] if listed else lines[-1])


def arguments(link):
    """What a link asks of its runner: its part alone, and in it the block of what its check says."""
    if not link or link.get("part") in (None, "all"):
        return []
    return ["--only", link["part"]] + (["--at", link["at"]] if link.get("at") else [])


def runner(key, args, addons=None):
    """A runner's run, on a copy or on the code as it is: (it failed, what it listed first, all it said)."""
    command = [sys.executable, "-I", str(RUNNERS[key])] + (["--addons", str(addons)] if addons else []) + list(args)
    hung = PART_HUNG if args else HUNG
    # A runner's error output may come in Windows' own encoding: read whatever it is.
    try:
        done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=hung)
    except subprocess.TimeoutExpired:
        return True, f"its tests didn't finish in {hung // 60} minutes: stopped", ""
    output = (done.stdout or "") + (done.stderr or "")
    return done.returncode != 0, first_problem(output), output


def run(key, inside, old, new, link=None):
    """(caught, why, all the runner said) for a break against its link's test, the whole run with none; caught None
    when old isn't there exactly once."""
    folders = shared.ADDONS[key][0]
    work = Path(tempfile.mkdtemp(prefix="kali-break-"))
    try:
        copy = work / "addon"
        shutil.copytree(folders, copy)
        target = copy / inside
        text = target.read_text(encoding="utf-8")
        if text.count(old) != 1:
            return None, f"found {text.count(old)} times in {key}'s {inside.as_posix()}", ""
        target.write_text(text.replace(old, new), encoding="utf-8", newline="\n")
        return runner(key, arguments(link), copy)
    finally:
        shutil.rmtree(work, ignore_errors=True)


# The blocks tried alone on the code as it is, this run: { (addon key, block) = it passes }.
alone = {}


def stands(key, link, output):
    """Whether the block the runner kept for this link passes alone on the code as it is: a break caught there is
    caught by the break. True too where the runner kept no block (the whole part ran)."""
    kept = BLOCK.search(output)
    if not kept or "--blocks-stand" in sys.argv:
        return True
    block = kept.group(1) or kept.group(2)
    if (key, block) not in alone:
        failed, _, _ = runner(key, arguments(link))
        alone[(key, block)] = not failed
    return alone[(key, block)]


def linked(key, inside, old, new, link):
    """A break against its link: (caught, why, the link used). A link to a block that doesn't stand alone falls back
    on its whole part."""
    caught, why, output = run(key, inside, old, new, link)
    if caught and link and link.get("at") and not stands(key, link, output):
        link = {"part": link["part"]}
        caught, why, output = run(key, inside, old, new, link)
    return caught, why, link


def find_link(key, inside, old, new):
    """The link of a break that has none, for a runner made of parts: each part in turn, the first that catches it;
    in the smoke, the block of the check that caught it, when it catches it alone too. (link, why), link None when
    no part does."""
    parts = list(PARTS[key])
    if inside.as_posix().endswith(UNIT_FIRST) and "tests" in parts:
        parts.remove("tests")
        parts.insert(0, "tests")
    for part in parts:
        caught, why, _ = run(key, inside, old, new, {"part": part})
        if caught is None:
            return None, why
        if not caught:
            continue
        if part == "scenarios":
            named = re.match(r"scenario (\S+):", why)
            return {"part": named.group(1) if named else part}, why
        if part == "smoke" and why.startswith("smoke: "):
            # what the check said: its runner finds the block by as much of it as the session's source holds
            link = {"part": part, "at": why[len("smoke: "):][:100].rstrip()}
            again, _, output = run(key, inside, old, new, link)
            if again and BLOCK.search(output) and stands(key, link, output):
                return link, why
        return {"part": part}, why
    return None, "no part of its runner catches it"


def links_file(stem, cut=None):
    return LINKS / (f"{stem}.json" if not cut else f"{stem}.part{cut[0]}of{cut[1]}.json")


def read_links(stem):
    """Every link kept for a breaks file, those of runs side by side included."""
    links = {}
    for file in sorted(LINKS.glob(f"{stem}*.json")):
        links.update(json.loads(file.read_text(encoding="utf-8")))
    return links


def write_links(stem, links, cut=None):
    LINKS.mkdir(parents=True, exist_ok=True)
    links_file(stem, cut).write_text(json.dumps(links, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                     encoding="utf-8", newline="\n")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    flags = {"--link", "--merge", "--blocks-stand"}
    args = [a for a in sys.argv[1:] if a not in flags]
    cut = None
    if "--slice" in args:
        at = args.index("--slice")
        cut = tuple(int(n) for n in args[at + 1].split("/"))
        del args[at:at + 2]
    if not args:
        raise SystemExit(__doc__)
    stem = Path(args[0]).stem
    breaks = runpy.run_path(args[0])["BREAKS"]
    links = read_links(stem)
    if "--merge" in sys.argv:
        # the links of runs side by side into the file's own, those of breaks no longer there dropped
        names = {b[0] for b in breaks}
        write_links(stem, {name: link for name, link in links.items() if name in names})
        for file in LINKS.glob(f"{stem}.part*.json"):
            file.unlink()
        print(f"links: {len(read_links(stem))} of {len(breaks)} breaks linked")
        return
    word = args[1] if len(args) > 1 else None
    chosen = [b for b in breaks if not word or word in b[0]]
    # a slice is cut from the whole list, before what's linked is left out: runs side by side start at different
    # moments, and one that left out what another had linked meanwhile took a different slice of what was left
    if cut:
        chosen = chosen[cut[0] - 1::cut[1]]
    if "--link" in sys.argv:
        # only those that have none: one linked, or naming its own test, was run when it got it
        chosen = [b for b in chosen if b[0] not in links and not extras(b[4:])[1]
                  and Path(b[1]).parts[0] in PARTS]
    found = {}
    missed = skipped = 0
    for name, path, old, new, *rest in chosen:
        only, test = extras(rest)
        started = time.time()
        results, used = [], None
        for key, inside in targets(path, only):
            link = {"part": test} if test else links.get(name) if key in PARTS and path.startswith(key) else None
            if link is None and key in PARTS and path.startswith(key) and "--link" in sys.argv:
                link, why = find_link(key, inside, old, new)
                if link:
                    # kept at once: a run stopped half way has lost nothing
                    found[name] = link
                    write_links(stem, found if cut else {**links, **found}, cut)
                results.append((key, link is not None, why))
            else:
                caught, why, link = linked(key, inside, old, new, link)
                results.append((key, caught, why))
            used = link or used
        if any(caught is None for _, caught, _ in results):
            skipped += 1
            print(f"SKIP: {name}  ({'; '.join(why for _, caught, why in results if caught is None)})", flush=True)
            continue
        gaps = [key for key, caught, _ in results if not caught]
        missed += bool(gaps)
        how = "; ".join(f"{key}: {why[:110]}" for key, caught, why in results if caught)
        by = f"  [{used['part']}{', its block' if used.get('at') else ''}, {time.time() - started:.0f} s]" if used else ""
        print(f"{'MISSED by ' + ', '.join(gaps) if gaps else 'caught'}: {name}  {how}{by}", flush=True)
    print(f"\n{len(chosen) - missed - skipped}/{len(chosen)} caught" + (f", {skipped} skipped" if skipped else "")
          + (f"; {len(found)} linked" if found else ""))
    sys.exit(1 if missed or skipped else 0)


if __name__ == "__main__":
    main()
