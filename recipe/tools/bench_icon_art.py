"""The game icons the icon bench (recipe/bench/icons.html) recolours, as data URLs in bench/art/icon-sources.js.

A page opened from disk can draw an image file but not read its pixels (the browser treats each file as its own
origin); a data URL it can read. The file goes in bench/art/, with the rest of Blizzard's art: local only, never
published or shipped.

Run with: python -I recipe/tools/bench_icon_art.py
"""
import base64
import json
from pathlib import Path

BENCH = Path(__file__).resolve().parents[1] / "bench"
# INV_Scroll_03, the addon's icon today, already in the bench's icons.
ICONS = ["134939"]


def main():
    sources = {}
    for ident in ICONS:
        png = BENCH / "art" / "icons" / f"{ident}.png"
        sources[ident] = "data:image/png;base64," + base64.b64encode(png.read_bytes()).decode("ascii")
    out = BENCH / "art" / "icon-sources.js"
    out.write_text("// Written by recipe/tools/bench_icon_art.py: Blizzard's icons, local only.\n"
                   f"window.KR_ICON_SOURCES = {json.dumps(sources)};\n", encoding="utf-8")
    print(f"{len(sources)} icon(s) written to {out}")


if __name__ == "__main__":
    main()
