"""Make one of the candidates on quest/bench/icons.html the addon's icon: a 64 by 64 TGA in quest/addon/KaLiQuest/Media.

Headless Edge draws the candidate and hands back its pixels; this writes them as an uncompressed 32-bit TGA,
the format most Forever addons ship their icons in. The TOC names it in ## IconTexture.

Run with: python -I quest/tools/make_icon.py <id>     (the ids are on the page, under each name)
"""
import base64
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import EDGE, QUEST, ROOT  # noqa: E402
PAGE = QUEST / "bench/icons.html"
OUT = QUEST / "addon/KaLiQuest/Media/Icon.tga"
# Tells icons.html which candidate the addon holds.
INSTALLED_JS = QUEST / "bench/js/icon-installed.js"
SIZE = 64


def render(ident):
    profile = tempfile.mkdtemp(prefix="kq-icon-")
    try:
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--virtual-time-budget=5000",
             "--dump-dom", PAGE.as_uri() + "#export=" + ident],
            capture_output=True, text=True, encoding="utf-8", timeout=120)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    found = re.search(r'<pre id="export">([A-Za-z0-9+/=]+)</pre>', result.stdout)
    if not found:
        raise SystemExit(f"No icon called {ident!r} on {PAGE.name}, or the page failed to draw it.")
    rgba = base64.b64decode(found.group(1))
    if len(rgba) != SIZE * SIZE * 4:
        raise SystemExit(f"Expected {SIZE * SIZE * 4} bytes, got {len(rgba)}.")
    return rgba


def write_tga(path, rgba):
    # Type 2, 32 bits, 8 of them alpha, rows from the bottom up.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    stride = SIZE * 4
    rows = []
    for y in range(SIZE - 1, -1, -1):
        row = bytearray(rgba[y * stride:(y + 1) * stride])
        row[0::4], row[2::4] = row[2::4], row[0::4]
        rows.append(bytes(row))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + b"".join(rows))


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    write_tga(OUT, render(sys.argv[1]))
    INSTALLED_JS.write_text("// Written by quest/tools/make_icon.py.\n"
                            f"window.KQ_ICON_INSTALLED = {json.dumps(sys.argv[1])};\n", encoding="utf-8")
    print(f"{sys.argv[1]} written to {OUT.relative_to(ROOT)}, {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
