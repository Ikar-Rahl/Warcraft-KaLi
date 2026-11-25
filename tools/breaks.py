"""Deliberate breaks: plant one fault at a time in a copy of the code, and see the tests fail. A fault they don't see
is a gap in them; a fix proven this way stays proven.

Run with: python -I tools/breaks.py <breaks file> [word...] [--link] [--jobs N] [--links-only] [--no-budget]
The breaks file is Python and sets BREAKS = [(name, path, old, new, ...), ...]. path is the repository's, under
quest/addon/, recipe/addon/, hud/addon/ or shared/; old must be found exactly once there, and becomes new. A break in
shared/ goes into each addon's copy, and each addon's tests must catch it; a further item that is a tuple, such as
("quest",) or ("quest", "recipe"), limits it to the addons where it changes anything (a hook only one addon sets, a
part only some use). With words, only the breaks whose name holds one of them run.
Each break runs on a copy in a temporary folder: the repository, linked into the game, is never touched.
Exits 1 when a break goes unnoticed, or when one can't run as it should (aborted, named, before anything runs).

How it stays quick (Ikar 2026-11-23: "Tests for an addon shoudl be 5min max total"; 2026-11-24: "If a break run the
whole suite, abort instatly, you have faield and fix it"):
- Each break runs only the part of its runner that must catch it, its link: a part of the runner (--only <part>, the
  runners' "The parts of a run"), narrowed by --at to one block of the smoke or one static check; a scenario of
  KaLi HUD's by its name. A second or two. Never a whole runner, never the whole smoke: before anything runs, a break
  with no link, or one to the whole smoke, or to a smoke's line that no longer is, aborts the run, named.
- Each runner is kept running in workers (tools/kali/worker.py), each on its own copy of the addon, side by side
  (--jobs, eight at the most): no break pays Python's start or the reading of the game's files.
- Before any break, each link the breaks use runs once on the code as it is, and must pass: a part that fails on its
  own would pass for every break caught (a smoke's block that no longer stands alone, a scenario broken). One that
  fails aborts the run, named, with what it said.
- A run stops once BUDGET seconds have gone, five minutes, and names the breaks it left (--no-budget: a whole sweep
  Ikar asks for).
- A runner's part that hasn't answered after ten times its own run on the code as it is (half a minute at the least) is
  stopped: the break caught, its tests never pass (a loop the break let run forever held a whole run, 2026-11-17).

A break's link is its own further item "test:<part>" or "test:<part>@<at>" (a scenario's name is a part; at, a text
of the smoke's block or a static check's name), or the one --link found, kept in tools/breaks/links/<breaks file>.json,
{ break: { addon: { "part": ..., "at": ... } } }, an addon each (a shared break has one in each). --link finds the
links that are missing, those to the whole smoke and those gone stale: for each, the runner's quick parts in turn (the
unit tests, the shared code's checks, the labels, the first run alone, the scenarios), then the whole smoke once, for
the block its first failure came from (each failure says it: checks.smoke_run), which must catch it alone too, then the
static checks. A break no part catches alone aborts the run: its check goes into a scenario, or a block of its own.
--link also drops the links kept for nothing: for a break gone or renamed, for an addon it no longer goes into, or for
one that names its own "test:". --links-only runs no break: each link used, on the code as it is.

A break whose old text the code no longer holds proves nothing: tools/run_tests.py asks stale() each time, which reads
every breaks file and its links, and runs nothing. It names the links kept for nothing too.
"""
import difflib
import json
import os
import queue
import re
import runpy
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali import checks, shared  # noqa: E402
from kali.paths import ROOT  # noqa: E402
from kali.worker import MARK  # noqa: E402

RUNNERS = {"quest": ROOT / "quest/tools/run_tests.py", "recipe": ROOT / "recipe/tools/run_tests.py",
           "hud": ROOT / "hud/tools/run_tests.py"}
WORKER = ROOT / "tools/kali/worker.py"
SMOKES = {"quest": ROOT / "quest/tools/lua/smoke.lua", "recipe": ROOT / "recipe/tools/lua/smoke.lua",
          "hud": ROOT / "hud/tools/lua/smoke.lua"}
SCENARIOS = ROOT / "hud/tools/lua/scenarios"
# Each runner's parts (its run_tests.py, PARTS): what a link may name. "smoke" only with a block (--at).
PARTS = {"quest": ("static", "tests", "smoke", "shared", "labels"),
         "recipe": ("static", "tests", "smoke", "shared", "labels", "restart"),
         "hud": ("static", "tests", "smoke", "alone", "scenarios", "shared", "labels")}
# The order --link tries them in: the quickest and likeliest first; the whole smoke, for its block, then the static
# checks last (a break that changes which of the game's names the code uses trips the needs list, which says nothing
# of the test meant for it).
SEARCH = {"quest": ("tests", "shared", "labels", "smoke", "static"),
          "recipe": ("tests", "shared", "labels", "smoke", "restart", "static"),
          "hud": ("tests", "shared", "labels", "alone", "scenarios", "smoke", "static")}
LINKS = ROOT / "tools/breaks/links"
BUDGET = 300
# A worker's first run reads the game's files, which takes a while: given that long at the least.
COLD = 300
JOBS = min(8, max(1, (os.cpu_count() or 2) // 2))
# A fresh worker after this many runs: memory kept in bounds.
RECYCLE = 150
NO_LINK = ("Fix: run tools/breaks.py <file> <word> --link, which finds each one's quick part, or name it as the "
           "break's \"test:<part>\" (a scenario of hud/tools/lua/scenarios/, a check put into one).")


# ---------- Breaks and their links ----------

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
    """A break's items past its four: the addons a shared one is limited to (a tuple), and its own link
    ("test:<part>" or "test:<part>@<at>"), as a link."""
    only = next((item for item in rest if isinstance(item, tuple)), None)
    test = next((item[len("test:"):] for item in rest if isinstance(item, str) and item.startswith("test:")), None)
    if test is None:
        return only, None
    part, _, at = test.partition("@")
    return only, {"part": part, **({"at": at} if at else {})}


def read_links(stem):
    """The links kept for a breaks file: { break: { addon: link } }."""
    path = LINKS / f"{stem}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def write_links(stem, links):
    LINKS.mkdir(parents=True, exist_ok=True)
    (LINKS / f"{stem}.json").write_text(json.dumps(links, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                        encoding="utf-8", newline="\n")


def link_of(links, name, key, own):
    """The link a break runs against in an addon: its own, or the one kept."""
    return own or links.get(name, {}).get(key)


def unused_links(breaks, links):
    """The links kept for a breaks file that no break runs: [(break, addon, why)], one kept for no break of that name,
    for an addon the break doesn't go into, or for a break that names its own "test:"."""
    goes, own = {}, set()
    for name, path, _, _, *rest in breaks:
        only, test = extras(rest)
        if test:
            own.add(name)
        goes.setdefault(name, set()).update(key for key, _ in targets(path, only))
    unused = []
    for name, by_addon in sorted(links.items()):
        for key in sorted(by_addon):
            if name not in goes:
                unused.append((name, key, "no break of that name"))
            elif name in own:
                unused.append((name, key, "the break names its own test:"))
            elif key not in goes[name]:
                unused.append((name, key, f"the break doesn't go into {key}"))
    return unused


def scenario_named(word):
    return any(word in path.stem for path in SCENARIOS.glob("*.lua"))


def blocks_of(key, at):
    """The smoke's blocks a text names (checks.smoke_session): a tuple of their lines, () for what stands between
    them; LookupError when no line says it."""
    return checks.blocks_kept(SMOKES[key], at)


def link_problem(key, link):
    """Why a link can't be run as it is (None: it can): none, the whole smoke, a part the runner hasn't, a smoke's line
    that no longer is."""
    if not link:
        return "no link"
    part, at = link.get("part"), link.get("at")
    if part == "smoke" and at in (None, ""):
        return "linked to the whole smoke"
    if part not in PARTS[key] and not (key == "hud" and part != "blocks" and scenario_named(part)):
        return f"linked to {part}, no part of {key}'s runner"
    if part == "scenarios":
        return "linked to every scenario: name the one"
    if part == "smoke":
        try:
            blocks_of(key, at)
        except LookupError:
            return f"linked to a line the smoke no longer says: {at[:60]}"
        except checks.LayoutError as wrong:
            return str(wrong)
    return None


def same_run(key, link):
    """What a link runs, as one: two texts of one block are the same run."""
    at = link.get("at")
    if link["part"] == "smoke":
        at = blocks_of(key, at)
    return key, link["part"], at


def arguments(link):
    """The runner's arguments for a link; at 0 is the smoke's own lines, no block."""
    at = link.get("at")
    return ["--only", link["part"]] + (["--at", str(at)] if at not in (None, "") else [])


def block_text(key, line, said, at=None):
    """A text that names the smoke's block at `line`, for a link: the longest stretch of what its check said that a
    line of the statement it came from holds (`at`, the session's line that was running: checks.smoke_run), else a
    line of that statement, then the same over the whole block; one only that block holds first. A text of the
    statement stays with its check when the block is cut up."""
    _, lines, blocks = checks.smoke_layout(SMOKES[key], SMOKES[key].stat().st_mtime_ns)
    start = line - 1
    end = next((last for first, last, _ in blocks if first == start), None)
    if end is None:
        return None
    statement = []
    if at and start < at - 1 < end:
        indent = len(lines[at - 1]) - len(lines[at - 1].lstrip())
        statement = [lines[at - 1]]
        for code in lines[at:end]:
            if code.strip() and len(code) - len(code.lstrip()) <= indent:
                break
            statement.append(code)
    candidates = []
    for scope in (statement, lines[start + 1:end]):
        texts = []
        for code in scope:
            match = difflib.SequenceMatcher(None, said, code, autojunk=False).find_longest_match(0, len(said), 0,
                                                                                                  len(code))
            if match.size >= 20:
                texts.append((match.size, code[match.b:match.b + match.size].strip()))
        candidates += [text for _, text in sorted(texts, reverse=True)]
        candidates += [code.strip() for code in scope if len(code.strip()) >= 20]
    named = []
    for text in candidates:
        try:
            blocks = blocks_of(key, text[:100])
        except LookupError:
            continue
        if blocks == (line,):
            return text[:100]
        if line in blocks:
            named.append(text[:100])
    return named[0] if named else None


def stale():
    """(what's wrong, how many breaks) over every file of tools/breaks: a break whose old text isn't found exactly once
    in each place it goes, one that changes nothing, two under one name, a link that can't be run as it is, a link
    kept for nothing (unused_links). Reads only."""
    problems, count, read = [], 0, {}

    def text_of(path):
        if path not in read:
            read[path] = path.read_text(encoding="utf-8")
        return read[path]

    for file in sorted((ROOT / "tools/breaks").glob("*.py")):
        names = set()
        links = read_links(file.stem)
        breaks = runpy.run_path(str(file))["BREAKS"]
        problems += [f"tools/breaks/links/{file.stem}.json: {name}: {key}: kept for nothing ({why})"
                     for name, key, why in unused_links(breaks, links)]
        for name, path, old, new, *rest in breaks:
            count += 1
            where = f"tools/breaks/{file.name}: {name}"
            if name in names:
                problems.append(f"{where}: a second break under that name")
            names.add(name)
            if old == new:
                problems.append(f"{where}: changes nothing")
            only, own = extras(rest)
            for key, inside in targets(path, only):
                found = text_of(shared.ADDONS[key][0] / inside).count(old)
                if found != 1:
                    problems.append(f"{where}: its text is found {found} times in {key}'s {inside.as_posix()}")
                why = link_problem(key, link_of(links, name, key, own))
                if why:
                    problems.append(f"{where}: {key}: {why}")
    return problems, count


# ---------- What a runner said ----------

def first_problem(output):
    """What the runner listed first: its problems come after a blank line and end at the blank line before its FAIL
    count. The needs list out of date is passed over when something else is listed too: any break that changes which
    of the game's names the code uses trips it, and it says nothing of the test meant for the break. A runner stopped
    by a Lua error has no list: the error's own line then, else its last line."""
    lines = output.splitlines()
    end = next((i for i, line in enumerate(lines) if line.startswith("FAIL:")), None)
    if end is None:
        return next((line.strip() for line in lines if "LuaError:" in line or "Error:" in line),
                    lines[-1] if lines else "")
    while end > 0 and lines[end - 1] == "":
        end -= 1
    blank = max((i for i, line in enumerate(lines[:end]) if line == ""), default=-1)
    listed = lines[blank + 1:end]
    return next((line for line in listed if not line.startswith("needs:")), listed[0] if listed else lines[-1])


# ---------- Workers ----------

class Worker:
    """A runner kept running on a copy of its addon (tools/kali/worker.py), started again as needed."""

    def __init__(self, key):
        self.key = key
        self.work = Path(tempfile.mkdtemp(prefix=f"kali-break-{key}-"))
        self.copy = self.work / "addon"
        shutil.copytree(shared.ADDONS[key][0], self.copy, ignore=shutil.ignore_patterns("__pycache__"))
        self.proc = None
        self.served = 0

    def start(self):
        self.err = open(self.work / "worker.err", "a", encoding="utf-8", errors="replace")
        self.proc = subprocess.Popen([sys.executable, "-I", str(WORKER), str(RUNNERS[self.key]), str(self.copy)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.err, text=True,
                                     encoding="ascii", errors="replace", bufsize=1)
        self.replies = queue.Queue()
        self.served = 0
        threading.Thread(target=self.read, args=(self.proc, self.replies), daemon=True).start()

    @staticmethod
    def read(proc, replies):
        for line in proc.stdout:
            if line.startswith(MARK):
                replies.put(json.loads(line[len(MARK):]))
        replies.put(None)

    def stop(self):
        if self.proc:
            self.proc.kill()
            self.proc.wait()
            self.proc = None
            self.err.close()

    def close(self):
        self.stop()
        shutil.rmtree(self.work, ignore_errors=True)

    def ask(self, args, hung):
        """The runner's answer to its arguments: (its exit code, all it said); code None when it hung."""
        if self.proc is None or self.proc.poll() is not None:
            self.stop()
            self.start()
        hung = max(hung, COLD) if self.served == 0 else hung
        try:
            self.proc.stdin.write(json.dumps(args) + "\n")
            self.proc.stdin.flush()
        except OSError:  # it had ended: a fresh one
            self.stop()
            self.start()
            self.proc.stdin.write(json.dumps(args) + "\n")
            self.proc.stdin.flush()
        try:
            reply = self.replies.get(timeout=hung)
        except queue.Empty:
            self.stop()
            return None, f"its tests didn't finish in {hung:.0f} s: stopped"
        if reply is None:
            self.stop()
            said = (self.work / "worker.err").read_text(encoding="utf-8", errors="replace").strip().splitlines()
            return 1, "the worker ended: " + (said[-1] if said else "nothing said")
        self.served += 1
        if self.served >= RECYCLE:
            self.stop()
        return reply["code"], reply["output"]

    def run(self, args, plant=None, hung=COLD):
        """(failed, what it said first, all it said, seconds) for the runner's arguments, a break planted first (inside,
        old, new) and taken out after; failed None when the break's text isn't there exactly once."""
        started = time.time()
        target = original = None
        if plant:
            inside, old, new = plant
            target = self.copy / inside
            original = target.read_bytes()
            text = original.decode("utf-8").replace("\r\n", "\n")
            if text.count(old) != 1:
                return None, f"found {text.count(old)} times in {self.key}'s {inside.as_posix()}", "", 0
            target.write_text(text.replace(old, new), encoding="utf-8", newline="\n")
        try:
            code, output = self.ask(args, hung)
        finally:
            if plant:
                target.write_bytes(original)
        seconds = time.time() - started
        if code is None:
            return True, output, output, seconds
        return code != 0, first_problem(output), output, seconds


class Lanes:
    """Workers side by side, up to `jobs` for each addon, each taking the next job of its addon's."""

    def __init__(self, jobs):
        self.jobs = jobs
        self.pools = {}
        self.lock = threading.Lock()

    def run(self, work, deadline=None, failed=lambda error: (None, f"breaks.py: {error!r}", "", 0)):
        """work: [(key, job)], job(worker) giving a result. The results in work's order; None for a job not begun
        before the deadline; failed(error) for one that raised (a skip, never a break caught)."""
        results = [None] * len(work)
        queues = {}
        for at, (key, job) in enumerate(work):
            queues.setdefault(key, queue.Queue()).put((at, job))
        threads = []
        for key, jobs in queues.items():
            pool = self.pools.setdefault(key, [])
            wanted = min(self.jobs, jobs.qsize())
            while len(pool) < wanted:
                pool.append(Worker(key))
            for worker in pool[:wanted]:
                thread = threading.Thread(target=self.lane, args=(worker, jobs, results, deadline, failed),
                                          daemon=True)
                thread.start()
                threads.append(thread)
        for thread in threads:
            thread.join()
        return results

    @staticmethod
    def lane(worker, jobs, results, deadline, failed):
        while not (deadline and time.time() > deadline):
            try:
                at, job = jobs.get_nowait()
            except queue.Empty:
                return
            try:
                results[at] = job(worker)
            except Exception as error:  # this tool's own fault, not the break's: said, never counted caught
                results[at] = failed(error)

    def say(self, line):
        with self.lock:
            print(line, flush=True)

    def close(self):
        for pool in self.pools.values():
            for worker in pool:
                worker.close()


# ---------- A run ----------

def abort(names, why, fix=NO_LINK):
    print(f"\nABORTED, nothing more run: {len(names)} {why}:")
    for name in names[:25]:
        print(f"  {name}")
    if len(names) > 25:
        print(f"  ... and {len(names) - 25} more")
    print(fix)
    sys.exit(1)


def baselines(lanes, runs):
    """Each run a link asks, on the code as it is: { run: seconds }; aborts naming those that fail, a break caught by
    them proving nothing."""
    order = sorted(runs, key=str)
    started = time.time()

    def job(run):
        def go(worker):
            return worker.run(arguments(runs[run]))
        return go

    results = lanes.run([(run[0], job(run)) for run in order])
    failing = [f"{run[0]}: {arguments(runs[run])}: {why[:140]}" for run, (failed, why, _, _) in zip(order, results)
               if failed]
    if failing:
        abort(failing, "link(s) that fail on the code as it is", "Fix the part first (its block, its scenario), "
              "then run the breaks again.")
    print(f"links: {len(order)} run on the code as it is, all pass, in {time.time() - started:.0f} s", flush=True)
    return {run: result[3] for run, result in zip(order, results)}


# The smoke's blocks run on the code as it is, this run: { (addon, blocks): whether they pass }.
clean_blocks = {}
clean_lock = threading.Lock()


def stands(key, link, worker):
    """Whether the smoke's block a link names passes on the code as it is (once a run for each block)."""
    run = (key, blocks_of(key, link["at"]))
    with clean_lock:
        known = clean_blocks.get(run)
    if known is None:
        known = not worker.run(arguments(link))[0]
        with clean_lock:
            clean_blocks[run] = known
    return known


def search(key, inside, old, new, worker):
    """A link for a break that has none: the quick parts in turn (SEARCH), the first that catches it; in the smoke,
    the block of the check that caught it, when it catches it alone too and stands alone; a scenario by its name; a
    static check by its own. (link, why): link None when none does, why then what the runs said."""
    plant = (inside, old, new)
    said = []
    for part in SEARCH[key]:
        caught, why, output, _ = worker.run(["--only", part], plant)
        if caught is None:
            return None, why
        if not caught:
            continue
        if part == "scenarios":
            named = re.match(r"scenario (\S+):", why)
            if named:
                return {"part": named.group(1)}, why
            said.append(f"scenarios: {why[:80]}")
            continue
        if part == "static":
            return {"part": "static", "at": checks.static_check_of(why)}, why
        if part == "smoke":
            # the block its first failure came from (checks.smoke_run), by a text of it; 0, the lines between them
            first = checks.FIRST_FROM.search(output)
            if not first:
                said.append(f"smoke, after the session: {why[:80]}")
                continue
            if first.group(2):
                link = {"part": "smoke", "at": 0}
            else:
                text = block_text(key, int(first.group(1)), why[len("smoke: "):] if why.startswith("smoke: ") else why,
                                  int(first.group(3)) if first.group(3) else None)
                if not text:
                    said.append(f"smoke, no text names its block at line {first.group(1)}: {why[:80]}")
                    continue
                link = {"part": "smoke", "at": text}
            again, _, _, _ = worker.run(arguments(link), plant)
            alone = stands(key, link, worker)
            if again and alone:
                return link, why
            said.append(f"smoke, its block {'fails on its own' if not alone else 'passes with the break'}: {why[:80]}")
            continue
        return {"part": part}, why
    return None, "; ".join(said) or "no part of its runner catches it"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    flags = {"--link", "--no-budget", "--links-only"}
    args = [a for a in sys.argv[1:] if a not in flags]
    jobs = JOBS
    if "--jobs" in args:
        at = args.index("--jobs")
        jobs = int(args[at + 1])
        del args[at:at + 2]
    if not args:
        raise SystemExit(__doc__)
    stem = Path(args[0]).stem
    breaks = runpy.run_path(args[0])["BREAKS"]
    words = args[1:]
    chosen = [b for b in breaks if not words or any(word in b[0] for word in words)]
    links = read_links(stem)
    began = time.time()
    # (break, addon key, file inside, old, new, link or None)
    tasks = []
    for name, path, old, new, *rest in chosen:
        only, own = extras(rest)
        for key, inside in targets(path, only):
            tasks.append((name, key, inside, old, new, link_of(links, name, key, own), own))
    lanes = Lanes(jobs)
    try:
        if "--link" in sys.argv:
            unused = unused_links(breaks, links)
            for name, key, _ in unused:
                del links[name][key]
                if not links[name]:
                    del links[name]
            if unused:
                write_links(stem, links)
                print(f"links: {len(unused)} kept for nothing dropped", flush=True)
            link_breaks(stem, links, tasks, lanes)
            return
        # Before anything runs: a break with no link, or one to the whole smoke, or to a line gone, aborts the run.
        refused = [f"{name} ({key}: {why})" for name, key, _, _, _, link, _ in tasks
                   for why in [link_problem(key, link)] if why]
        if refused:
            abort(refused, "break(s) that would run a whole suite, or can't run as they are")
        runs = {}
        for _, key, _, _, _, link, _ in tasks:
            runs.setdefault(same_run(key, link), link)
        took = baselines(lanes, runs)
        if "--links-only" in sys.argv:
            return
        deadline = None if "--no-budget" in sys.argv else began + BUDGET

        def job(task):
            name, key, inside, old, new, link, _ = task

            def go(worker):
                hung = max(30, 10 * took[same_run(key, link)])
                return worker.run(arguments(link), (inside, old, new), hung)
            return go

        results = lanes.run([(task[1], job(task)) for task in tasks], deadline)
        report(chosen, tasks, results, began)
    finally:
        lanes.close()


def report(chosen, tasks, results, began):
    by_break = {}
    for task, result in zip(tasks, results):
        by_break.setdefault(task[0], []).append((task, result))
    missed = skipped = 0
    left = []
    for name, *_ in chosen:
        done = by_break.get(name, [])
        if any(result is None for _, result in done):
            left.append(name)
            continue
        if any(result[0] is None for _, result in done):
            skipped += 1
            print(f"SKIP: {name}  ({'; '.join(r[1] for _, r in done if r[0] is None)})")
            continue
        gaps = [task[1] for task, result in done if not result[0]]
        missed += bool(gaps)
        how = "; ".join(f"{task[1]}: {result[1][:100]}" for task, result in done if result[0])
        by = ", ".join(f"{task[5]['part']}{'@' if task[5].get('at') else ''} {result[3]:.1f} s" for task, result in done)
        print(f"{'MISSED by ' + ', '.join(gaps) if gaps else 'caught'}: {name}  {how}  [{by}]")
    ran = len(chosen) - len(left)
    print(f"\n{ran - missed - skipped}/{ran} caught" + (f", {skipped} skipped" if skipped else "")
          + f" in {time.time() - began:.0f} s")
    if left:
        print(f"BUDGET: {BUDGET} s gone, {len(left)} breaks not run: {'; '.join(left[:10])}"
              + (" ..." if len(left) > 10 else ""))
    sys.exit(1 if missed or skipped or left else 0)


def link_breaks(stem, links, tasks, lanes):
    """--link: a link for each break that has none, or one to the whole smoke, or one gone stale; each kept as soon as
    it is found, and each break so linked run with it (caught: no need to run it again)."""
    wanted = [task for task in tasks if link_problem(task[1], task[5]) and not task[6]]
    owned = [task[0] for task in tasks if task[6] and link_problem(task[1], task[6])]
    if owned:
        abort(owned, "break(s) whose own \"test:\" link can't be run as it is", "Fix: change or take out the break's "
              "own \"test:\" item, then link it.")
    if not wanted:
        print("links: every break chosen has one")
        return
    print(f"links: {len(wanted)} to find, {lanes.jobs} side by side for each addon", flush=True)
    started = time.time()
    # every part searched passes on the code as it is, or each break would seem caught by it
    keys = sorted({task[1] for task in wanted})
    baselines(lanes, {(key, part, None): {"part": part} for key in keys for part in SEARCH[key]})
    found = {}

    def job(task):
        name, key, inside, old, new, _, _ = task

        def go(worker):
            t = time.time()
            link, why = search(key, inside, old, new, worker)
            if link:
                with lanes.lock:
                    links.setdefault(name, {})[key] = link
                    write_links(stem, links)
                    found[(name, key)] = link
            lanes.say(f"{'linked' if link else 'NOT LINKED'}: {name} ({key}) "
                      f"{('-> ' + link['part'] + ('@' + str(link['at'])[:50] if link.get('at') else '')) if link else ''}"
                      f"  {why[:110]}  [{time.time() - t:.0f} s]")
            return link, why
        return go

    results = lanes.run([(task[1], job(task)) for task in wanted], failed=lambda error: (None, f"breaks.py: {error!r}"))
    unlinked = [f"{task[0]} ({task[1]}: {why[:100]})" for task, (link, why) in zip(wanted, results) if not link]
    print(f"\nlinks: {len(found)} of {len(wanted)} found in {time.time() - started:.0f} s; each break so linked was "
          "caught by it alone: no need to run it again")
    if unlinked:
        abort(unlinked, "break(s) no quick part catches alone", "Fix: put the check that catches each one into a "
              "scenario (hud/tools/lua/scenarios/) or a block of its own, and name it as the break's \"test:<part>\".")


if __name__ == "__main__":
    main()
