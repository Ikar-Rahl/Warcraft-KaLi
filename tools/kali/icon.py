"""An addon's icon, from one of the candidates its bench's icons.html draws: a 64 by 64 TGA in the addon's Media folder.

Headless Edge draws the candidate and hands back its pixels (the page's #export=<id>); this writes them as an
uncompressed 32-bit TGA, the format most Forever addons ship their icons in. The TOC names it in ## IconTexture.
Each addon's tools/make_icon.py says which page, which file, and which variable tells the page what the addon holds.
"""
import base64
import json
import re
import shutil
import struct
import subprocess
import tempfile

from .paths import EDGE, ROOT

SIZE = 64


def render(page, ident):
    profile = tempfile.mkdtemp(prefix="kali-icon-")
    try:
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--virtual-time-budget=5000",
             "--dump-dom", page.as_uri() + "#export=" + ident],
            capture_output=True, text=True, encoding="utf-8", timeout=120)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    found = re.search(r'<pre id="export">([A-Za-z0-9+/=]+)</pre>', result.stdout)
    if not found:
        raise SystemExit(f"No icon called {ident!r} on {page.name}, or the page failed to draw it "
                         "(its font, in the bench's art/, is made by the bench's art script).")
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


def install(argv, page, out, installed_js, variable, tool, usage):
    """Write candidate argv[1] to out, and tell the page (installed_js) which one the addon now holds."""
    if len(argv) != 2:
        raise SystemExit(usage)
    ident = argv[1]
    write_tga(out, render(page, ident))
    installed_js.write_text(f"// Written by {tool}.\nwindow.{variable} = {json.dumps(ident)};\n",
                            encoding="utf-8", newline="\n")
    print(f"{ident} written to {out.relative_to(ROOT).as_posix()}, {out.stat().st_size} bytes")
