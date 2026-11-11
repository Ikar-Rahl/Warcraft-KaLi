"""The code the KaLi addons share, and its copies in each addon.

The source is shared/: shared/addon/*.lua goes to each addon's Shared/ folder, shared/tests/*.lua to its tests' Shared/.
Each addon carries its own copy, loaded in its own namespace, so a player never needs a third addon and an older copy
in one addon can't break the other; the copies are committed, so what is tested is what ships. A copy is its source
under a one-line header, and any difference is a problem: edit the source, then run tools/sync_shared.py.
"""
import re

from kali.paths import QUEST, RECIPE, SHARED

# The addons, each by its folder of folders and its main folder's name.
ADDONS = {"quest": (QUEST / "addon", "KaLiQuest"), "recipe": (RECIPE / "addon", "KaLiRecipe")}
HEADER = "-- Copied from shared/{} by tools/sync_shared.py: edit the source, not this copy.\n"


def sources():
    return sorted(SHARED.glob("addon/*.lua")) + sorted(SHARED.glob("tests/*.lua"))


def copy_path(source, folders, name):
    """Where an addon's copy of a shared file lives."""
    kind = source.parent.name
    return folders / (name if kind == "addon" else name + "_Tests") / "Shared" / source.name


def expected(source):
    return HEADER.format(source.relative_to(SHARED).as_posix()) + source.read_text(encoding="utf-8")


def pairs():
    """(source, addon key, copy path) for every copy."""
    for source in sources():
        for key, (folders, name) in ADDONS.items():
            yield source, key, copy_path(source, folders, name)


def sync():
    written = 0
    for source, _, copy in pairs():
        text = expected(source)
        if not copy.exists() or copy.read_text(encoding="utf-8") != text:
            copy.parent.mkdir(parents=True, exist_ok=True)
            copy.write_text(text, encoding="utf-8", newline="\n")
            written += 1
    return written


def problems():
    """A copy missing or different, a copy of a source that's gone, and a string the shared code uses that an addon's
    locale doesn't define (the game would show nil, or fail)."""
    out = []
    for source, _, copy in pairs():
        if not copy.exists():
            out.append(f"shared: {copy.relative_to(SHARED.parent).as_posix()} is missing: run tools/sync_shared.py")
        elif copy.read_text(encoding="utf-8") != expected(source):
            out.append(f"shared: {copy.relative_to(SHARED.parent).as_posix()} differs from its source: run tools/sync_shared.py")
    known = {copy for _, _, copy in pairs()}
    for folders, name in ADDONS.values():
        for copy in sorted(folders.glob("*/Shared/*.lua")):
            if copy not in known:
                out.append(f"shared: {copy.relative_to(SHARED.parent).as_posix()} has no source in shared/")
    used = set()
    for source in sources():
        used |= set(re.findall(r"\bL\.([A-Z][A-Z0-9_]*)", source.read_text(encoding="utf-8")))
    for folders, name in ADDONS.values():
        locale = (folders / name / "Core/Locale.lua").read_text(encoding="utf-8")
        defined = set(re.findall(r"^\s*([A-Z][A-Z0-9_]*)\s*=", locale, re.M))
        out += [f"shared: the shared code uses L.{key}, which {name}'s locale doesn't define" for key in sorted(used - defined)]
    return out
