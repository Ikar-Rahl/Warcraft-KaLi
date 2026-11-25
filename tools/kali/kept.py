"""What the test runners make from the game's files, kept on disk from one run to the next: Blizzard's source read
through, the API docs' lists, a data table built again to be held against the addon's. A result is used again only
while what it was made from is the same: every file it reads, by path, time and size, and the code that reads them. A
file changed, added or gone, or the code edited, makes it again.

Kept in tools/.cache/ (git leaves it out), a file a result: deleting the folder costs one slow run, nothing else.
"""
import hashlib
import os
import pickle
from functools import cache

from kali.paths import ROOT

FOLDER = ROOT / "tools/.cache"


@cache
def stamps(folder, suffixes=(), deep=True):
    """(path, time, size) of each file of the folder, and of its sub-folders when deep, whose name ends with one of the
    suffixes, in any case (every file with none), sorted. Walked once a process."""
    found, waiting = [], [os.fspath(folder)]
    while waiting:
        with os.scandir(waiting.pop()) as entries:
            for entry in entries:
                if entry.is_dir(follow_symlinks=False):
                    if deep:
                        waiting.append(entry.path)
                elif not suffixes or entry.name.lower().endswith(suffixes):
                    stat = entry.stat(follow_symlinks=False)
                    found.append((entry.path, stat.st_mtime_ns, stat.st_size))
    return tuple(sorted(found))


def files(*paths):
    """(path, time, size) of each file: the code that makes a result is part of what it is made from."""
    out = []
    for path in paths:
        stat = os.stat(path)
        out.append((os.fspath(path), stat.st_mtime_ns, stat.st_size))
    return tuple(out)


def kept(name, inputs, make):
    """make()'s result, kept in tools/.cache/<name>.pickle with what it was made from (inputs: stamps() and files()):
    read back while the inputs are the same, else made again and kept. Runs side by side may make it at the same time:
    each writes a file of its own, then moves it into place."""
    key = hashlib.sha256(repr(inputs).encode("utf-8")).hexdigest()
    path = FOLDER / f"{name}.pickle"
    try:
        with open(path, "rb") as f:
            stored, value = pickle.load(f)
        if stored == key:
            return value
    except Exception:  # none kept yet, or a file that can't be read back: made again
        pass
    value = make()
    part = FOLDER / f"{name}.{os.getpid()}.part"
    try:
        FOLDER.mkdir(parents=True, exist_ok=True)
        with open(part, "wb") as f:
            pickle.dump((key, value), f, pickle.HIGHEST_PROTOCOL)
        os.replace(part, path)
    except OSError:  # another run's copy in its place, open to be read: that one stays
        try:
            os.remove(part)
        except OSError:
            pass
    return value
