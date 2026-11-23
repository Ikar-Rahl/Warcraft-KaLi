"""The minimap rings Ikar picked on hud/bench/minimap.html (2026-11-16), from hud/tools/cut_rings.py's cut-outs
(hud/bench/art/rings): each one a 512 by 512 Media/MinimapRing<Id>.tga (SIZES: a larger one) with its ring's centre in the middle, and
Data/MinimapRings.lua: where its map goes and how far its band reaches, both as a share of the texture's half width,
and the themes the menu groups them in.

Headless Edge scales the cut-outs down. Run after cut_rings.py with: python -I hud/tools/make_rings.py [ring ...]
(only the rings named, e.g. lava: seconds; none named, all of them)
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

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.paths import EDGE  # noqa: E402

HUD = ROOT / "hud"
BENCH = HUD / "bench"
ADDON = HUD / "addon/KaLiHUD"
SIZE = 512
# Rings drawn larger than SIZE where their art has the detail for it: the Steampunk's, from a 2048 painting of one ring
# (Ikar 2026-11-20: "the steampunk minimap look a bit weird, pixelization ?", "especially compared to the cartouche"):
# at 512 the map's ring, drawn as large as the map, stood magnified on a 4K screen, where a cartouche's art, as wide,
# covers less of it.
SIZES = {"steampunk": 1024}

# Ikar's picks and his names for them (2026-11-16: "Blizzard, Forest, Black steel, blue steel, fire, golden, mage,
# rune, steel, steampunk 1, steampunk 2, arcane crystal, nature crystal, frost crystal, fire crystal, gem, north star,
# astronomy"; his Blizzard is the game's own ring, minimapRing "blizzard"), grouped by theme ("Group them by theme"):
# theme -> [(id, the cut-out)]. The menu lists the plain rings first, KaLi's, Blizzard's and Blizzard's classic, then
# these under their themes' titles.
THEMES = [
    ("metal", [("steel", "rings-2-9"), ("blacksteel", "rings-1-2"), ("bluesteel", "rings-1-3"),
               ("golden", "rings-1-8")]),
    # fire: Ikar's own art since 2026-11-18 ("Added a new minimap art. That shoudl replace fire."), rings-1-6 before
    # lava: Ikar's too ("downlaoded another one, laya, add it as a new minimap")
    ("elements", [("forest", "rings-1-1"), ("fire", "rings-5-1"), ("lava", "rings-6-1")]),
    ("magic", [("mage", "rings-2-3"), ("rune", "rings-2-7")]),
    # clockwork: one of Ikar's own since 2026-11-20, in place of both steampunk ones (rings-3-2 and rings-3-3: "I have a
    # new steampunk minimap art that will replace the 2 currently in the plugin")
    ("clockwork", [("steampunk", "rings-7-1")]),
    ("crystal", [("arcanecrystal", "rings-3-5"), ("naturecrystal", "rings-3-6"), ("frostcrystal", "rings-3-7"),
                 ("firecrystal", "rings-3-8"), ("gem", "rings-3-9")]),
    ("sky", [("northstar", "rings-4-1"), ("astronomy", "rings-4-4")]),
]

PAGE = r"""<!doctype html><meta charset="utf-8"><pre id="export"></pre><script>
const RINGS = DATA;
const load = u => new Promise(done => { const img = new Image(); img.onload = () => done(img); img.src = u; });
// Clear texels take their solid neighbours' colour, so the game's filtering draws no dark fringe round the art.
function bleed(d, S) {
  const filled = new Uint8Array(S * S);
  for (let i = 0; i < S * S; i++) filled[i] = d[4 * i + 3] > 0 ? 1 : 0;
  for (let pass = 0; pass < 4; pass++) {
    const next = filled.slice();
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      const i = y * S + x;
      if (filled[i]) continue;
      let r = 0, g = 0, b = 0, n = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const X = x + dx, Y = y + dy, j = Y * S + X;
        if (X < 0 || Y < 0 || X >= S || Y >= S || !filled[j]) continue;
        r += d[4 * j]; g += d[4 * j + 1]; b += d[4 * j + 2]; n++;
      }
      if (n) { d[4 * i] = r / n; d[4 * i + 1] = g / n; d[4 * i + 2] = b / n; next[i] = 1; }
    }
    filled.set(next);
  }
}
function base64(bytes) {
  let s = "";
  for (let i = 0; i < bytes.length; i += 32768) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 32768));
  return btoa(s);
}
(async () => {
  const out = [];
  for (const r of RINGS) {
    const S = r.size;
    const img = await load(r.url), w = img.naturalWidth, h = img.naturalHeight;
    const src = document.createElement("canvas");
    src.width = w; src.height = h;
    const sc = src.getContext("2d");
    sc.drawImage(img, 0, 0);
    const a = sc.getImageData(0, 0, w, h).data;
    // its reach: the farthest texel with anything in it, from the ring's centre
    let reach = 0;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
      if (a[4 * (y * w + x) + 3] > 8) reach = Math.max(reach, Math.hypot(x + 0.5 - r.cx, y + 0.5 - r.cy));
    const k = (S / 2 - 1) / reach;
    const cv = document.createElement("canvas");
    cv.width = S; cv.height = S;
    const c = cv.getContext("2d");
    c.imageSmoothingQuality = "high";
    c.drawImage(img, S / 2 - r.cx * k, S / 2 - r.cy * k, w * k, h * k);
    const data = c.getImageData(0, 0, S, S).data;
    bleed(data, S);
    out.push({ k, rgba: base64(new Uint8Array(data.buffer)) });
  }
  document.getElementById("export").textContent = JSON.stringify(out);
})();
</script>"""


def render(rings):
    work = Path(tempfile.mkdtemp(prefix="kali-rings-"))
    try:
        page = work / "render.html"
        page.write_text(PAGE.replace("DATA", json.dumps(rings), 1), encoding="utf-8")
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={work / 'profile'}",
             "--allow-file-access-from-files", "--virtual-time-budget=120000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, encoding="utf-8", timeout=600)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    found = re.search(r'<pre id="export">(.+?)</pre>', result.stdout, re.S)
    if not found:
        raise SystemExit(f"the page drew nothing (run hud/tools/cut_rings.py first?)\n{result.stderr[-2000:]}")
    return json.loads(found.group(1))


def write_tga(path, rgba, size):
    # Type 2, 32 bits, 8 of them alpha, rows from the bottom up, BGRA.
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8))
    stride = size * 4
    for y in range(size - 1, -1, -1):
        row = bytearray(rgba[y * stride:(y + 1) * stride])
        row[0::4], row[2::4] = row[2::4], row[0::4]
        out += row
    path.write_bytes(bytes(out))


def file_name(ident):
    return "MinimapRing" + ident[0].upper() + ident[1:]


def main():
    text = (BENCH / "js/rings-data.js").read_text(encoding="utf-8")
    cut = {r["id"]: r for r in json.loads(text[text.index("["):text.rindex("]") + 1])}
    picks = [(ident, cut[source]) for _, rings in THEMES for ident, source in rings]
    # Only the rings named, if any (a new one: seconds, not all of them again); the others' lines kept as they were.
    only = set(sys.argv[1:])
    if only - {i for i, _ in picks}:
        raise SystemExit(f"no such ring: {', '.join(sorted(only - {i for i, _ in picks}))}")
    data = ADDON / "Data/MinimapRings.lua"
    kept = dict(re.findall(r"^    (\w+) = (\{ file = .*\},)$", data.read_text(encoding="utf-8"), re.M)) \
        if only and data.exists() else {}
    lines = []
    for ident, r in picks:
        if only and ident not in only:
            if ident not in kept:
                raise SystemExit(f"{ident} has no line yet: run python -I hud/tools/make_rings.py {ident}")
            lines.append(f"    {ident} = {kept[ident]}")
            continue
        # a page a ring: one for all, its export 1.4 MB a ring, no longer came back from headless Edge within ten
        # minutes once they were 18 (2026-11-18), where each alone takes seconds
        size = SIZES.get(ident, SIZE)
        result = render([{"url": (BENCH / r["file"]).as_uri(), "cx": r["cx"], "cy": r["cy"], "size": size}])[0]
        write_tga(ADDON / "Media" / f"{file_name(ident)}.tga", base64.b64decode(result["rgba"]), size)
        half = size / 2
        lines.append(f'    {ident} = {{ file = "Interface\\\\AddOns\\\\KaLiHUD\\\\Media\\\\{file_name(ident)}", '
                     f'inner = {r["rin"] * result["k"] / half:.4f}, band = {r["rout"] * result["k"] / half:.4f} }},')
    themes = ",\n".join(f'    {{ "{theme}", {{ {", ".join(json.dumps(i) for i, _ in rings)} }} }}' for theme, rings in THEMES)
    (ADDON / "Data/MinimapRings.lua").write_text(
        "-- Generated by hud/tools/make_rings.py: the minimap rings from Ikar's art (hud/art/minimap), Media/MinimapRing*.tga,\n"
        "-- each ring's centre in the middle of its texture. inner: where its map's edge goes, band: its band's outer\n"
        "-- edge, both as a share of the texture's half width. Don't edit.\n"
        "local _, ns = ...\n\n"
        "ns.MINIMAP_RINGS = {\n" + "\n".join(lines) + "\n}\n"
        "-- The menu's themes, in order, each its rings in order.\n"
        "ns.MINIMAP_RING_THEMES = {\n" + themes + ",\n}\n",
        encoding="utf-8", newline="\n")
    print(f"written: {len(only) or len(picks)} of {len(picks)} rings and Data/MinimapRings.lua")


if __name__ == "__main__":
    main()
