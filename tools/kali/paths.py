"""Where things are: the repository, and what stays outside it.

The reference copies (Blizzard's UI source and tables, QuestieDB...) are large and partly not ours to publish, so they
live beside the repository, in its parent folder's reference/, as on Ikar's machine (C:\\devel\\WowAddons). The game is
where Ikar's is. Either can be moved with an environment variable: KALI_REFERENCE, KALI_GAME, KALI_EDGE.

A script imports this after putting tools/ on its path (python -I leaves the script's own folder out):
    sys.path.insert(0, str(Path(__file__).resolve().parents[N] / "tools"))
    from kali.paths import ROOT, REFERENCE
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = Path(os.environ.get("KALI_REFERENCE", ROOT.parent / "reference"))
GAME = Path(os.environ.get("KALI_GAME", r"C:\devel\World of Warcraft\_forever_"))
EDGE = Path(os.environ.get("KALI_EDGE", r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"))
# The Lua 5.1 runtime the test runners use: python -I -m pip install --target tools/pylib lupa
PYLIB = ROOT / "tools/pylib"

QUEST = ROOT / "quest"
RECIPE = ROOT / "recipe"
SHARED = ROOT / "shared"


def use_pylib():
    """Puts the local Lua runtime on the path, once."""
    if str(PYLIB) not in sys.path:
        sys.path.insert(0, str(PYLIB))
