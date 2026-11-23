"""KaLi HUD's own textures, white or greyscale so the code colours them, written as 32-bit TGA the game reads:
- Media/Disc.tga: a disc filling the square, for the dome and the plate's rounded corners.
- Media/Fillet.tga: a square with a quarter disc cut out, centred on its top right corner, for the concave curves
  where a lower plate meets a higher one.
- Media/Bevel.tga: a square's lower right half, for the plate's bevelled corners and concave cuts.
- Media/Shadow.tga: a soft round shadow, dark through its middle, for the one the minimap casts on the plate.
- Media/Ring.tga: a crisp thin 3D metallic ring (dark outer rim, bright crest, warm body, dark inner lip).
- Media/BandKaLi.tga: the KaLi border across, outside first, once for each way an edge faces (64 blocks of 32, lit
  from the top left; 2048 x 4, the same down its length), in one of the borders bench's looks (hud/bench/js/looks.js;
  LOOK below, or --look <id>), grey for the border colour to tint: the plate's edge and the map's ring are drawn with
  it along their outlines; Data/Look.lua tells the addon the look's depth and its colour, the default. The bronze
  look is faceted (two flat faces meeting at a sharp crest past the metal's middle) and mirror-polished, as Blizzard's
  minimap and portrait rings (Ikar 2026-11-16, tried in game as options, then baked in).
- Media/BandThin.tga: the status bars' thin border (looks.js' KALI_THIN), the same way.
- Media/BandGrain.tga: specks over the KaLi border's metal, lighter (white) and darker (black) by their alpha, as
  FlareUI's borders carry (measured 2026-11-14: about 5 % either way); 16 across the band, 64 rows along it.
- Media/Bar.tga: a glazed horizontal bar texture in FlareUI's spirit, tinted by each status bar's colour.
- Media/BarStriped.tga: the same glazed profile with diagonal ribs.
- Media/Chevron.tga: the windows' fold arrow, a round-capped V pointing down.
- Media/Lock.tga & Media/Unlock.tga: padlock icons at the right end of the info bar for locking/unlocking slot drag.
Not the addon's icon, Media/Icon.tga: since 2026-11-23 hud/tools/make_icon.py writes it from the bench's icons.html
(it was a bronze dome on its plate, drawn here).

Run with: python -I hud/tools/make_media.py [--look <id>]
"""
import json
import math
import random
import struct
import sys
from pathlib import Path

MEDIA = Path(__file__).resolve().parents[1] / "addon/KaLiHUD/Media"


def tga(path, width, height, pixel):
    """pixel(x, y) -> (r, g, b, a) in 0..1, x and y from the bottom left, at the pixel's centre."""
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8))
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixel((x + 0.5) / width, (y + 0.5) / height)
            out += bytes(round(max(0.0, min(1.0, c)) * 255) for c in (b, g, r, a))
    path.write_bytes(bytes(out))


def tga_rows(path, width, height, rows):
    """rows: top to bottom, each a list of (r, g, b, a) in 0..1."""
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8))
    for row in reversed(rows):
        for r, g, b, a in row:
            out += bytes(round(max(0.0, min(1.0, c)) * 255) for c in (b, g, r, a))
    path.write_bytes(bytes(out))


def edge(distance, size):
    """Coverage of a pixel whose centre is `distance` (in texture widths) inside a shape's edge."""
    return max(0.0, min(1.0, distance * size + 0.5))


def seg_dist(px, py, x0, y0, x1, y1):
    vx, vy = x1 - x0, y1 - y0
    wx, wy = px - x0, py - y0
    denom = vx * vx + vy * vy
    t = 0.0 if denom <= 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / denom))
    return math.hypot(px - (x0 + t * vx), py - (y0 + t * vy))


def disc(size):
    return lambda x, y: (1, 1, 1, edge((1 - math.hypot(x * 2 - 1, y * 2 - 1)) / 2, size))


def fillet(size):
    return lambda x, y: (1, 1, 1, edge(math.hypot(1 - x, 1 - y) - 1, size))


def bevel(size):
    return lambda x, y: (1, 1, 1, edge((x - y) / math.sqrt(2), size))


# Masks turned left for right: a mask in game doesn't take a mirrored SetTexCoord (Ikar 2026-11-14: black corners).
def fillet_mirror(size):
    return lambda x, y: (1, 1, 1, edge(math.hypot(x, 1 - y) - 1, size))


def bevel_mirror(size):
    return lambda x, y: (1, 1, 1, edge((1 - x - y) / math.sqrt(2), size))


def shadow():
    def px(x, y):
        t = min(1.0, max(0.0, (math.hypot(x * 2 - 1, y * 2 - 1) - 0.35) / 0.65))
        return (1, 1, 1, (1 - t * t * (3 - 2 * t)) ** 1.6)

    return px


def ring(size):
    """Crisp thin 3D metallic ring (~4% thickness): dark inner shadow lip, bright bevel crest, dark outer rim."""
    inner, outer = 0.90, 0.99

    def px(x, y):
        dx, dy = x * 2 - 1, y * 2 - 1
        r = math.hypot(dx, dy)
        a_in = edge((r - inner) / 2, size)
        a_out = edge((outer - r) / 2, size)
        a = a_in * a_out
        if a <= 0:
            return (0, 0, 0, 0)
        t = max(0.0, min(1.0, (r - inner) / (outer - inner)))
        light = 0.12 * ((dy - dx * 0.35) / max(r, 0.001))
        if t < 0.22:
            lum = 0.08 + 0.24 * (t / 0.22)
        elif t < 0.58:
            k = (t - 0.22) / 0.36
            lum = 0.78 + 0.22 * math.sin(k * math.pi) + light
        elif t < 0.82:
            k = (t - 0.58) / 0.24
            lum = 0.90 - 0.30 * k + light * 0.5
        else:
            k = (t - 0.82) / 0.18
            lum = 0.28 * (1.0 - 0.75 * k)
        lum = max(0.0, min(1.0, lum))
        return (lum, lum, lum, a)

    return px


# The KaLi border shipped: one of the borders bench's looks, by its id.
LOOK = "bronze"
LOOKS_JS = Path(__file__).resolve().parents[1] / "bench/js/looks.js"
LOOK_LUA = MEDIA.parent / "Data/Look.lua"
# Where a ridge peaks across the metal, from the outside: a short face catching the light, a long slope inwards. A
# faceted one, as Blizzard's rings: its wide outer face catching the light, its crest past the middle.
CREST, FACET_CREST = 0.35, 0.55
# The light's side on the screen: the top left, as Blizzard's minimap ring is lit (brightest at 120 to 150 degrees).
SKY = (-0.55 / math.hypot(0.55, 0.75), -0.75 / math.hypot(0.55, 0.75))
# The band file holds the profile once for each way an edge can face, DIRS blocks of TEXELS across.
DIRS, TEXELS = 64, 32
# The shadows' strength outside and inside, and how much more the side away from the light casts.
SHADOW_OUT, SHADOW_IN, CAST = 0.85, 0.75, 0.35


def _js(name):
    text = LOOKS_JS.read_text(encoding="utf-8")
    at = text.index(f"window.{name} =") + len(f"window.{name} =")
    return json.JSONDecoder().raw_decode(text[at:].lstrip())[0]


def looks():
    return _js("KALI_LOOKS")


def look_edge(P):
    """The border's depth in UI units at 100 %: the shadow outside, a line, the metal, a line, the shadow inside."""
    return 2 * P["shadow"] + 2 * P["lines"] + P["width"]


def _norm(x, y, z):
    n = math.sqrt(x * x + y * y + z * z)
    return (x / n, y / n, z / n)


def _slope(profile, x):
    """The metal's slope across it, x from its outer side (0) to its inner side (1)."""
    if profile == "flat":
        return 0.08 * math.cos(math.pi * x)
    if profile == "round":
        return 1.4 * math.cos(math.pi * x)
    if profile == "bevel":
        return 1.6 if x < 0.3 else -1.6 if x > 0.7 else 0
    if profile == "groove":
        return -1.4 * math.cos(math.pi * x)
    if profile == "double":
        return 1.4 * math.cos(math.pi * ((2 * x) % 1))
    if profile == "facet":
        return 1.0 if x < 0.5 else -1.0
    return 0


def _smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def reflect(h, polish):
    """The metal's brightness where it reflects the eye towards the light (h 1), back at it (0) or away (-1): brushed,
    soft and even; polished, a mirror of a bright sky over a dark horizon and a dim floor."""
    if h >= 0.2:
        mirror = 0.45 + 0.55 * _smooth(0.2, 0.65, h)
    elif h >= 0:
        mirror = 0.2 + 0.25 * _smooth(0, 0.2, h)
    else:
        mirror = 0.2 + 0.18 * _smooth(-0.45, -0.85, h)
    return (0.55 + 0.35 * h) * (1 - polish) + mirror * polish


def ridge_slope(profile, u):
    if profile == "double":
        return _slope(profile, u)
    crest = FACET_CREST if profile == "facet" else CREST
    if u < crest:
        return _slope(profile, u * 0.5 / crest) * 0.5 / crest
    return _slope(profile, 0.5 + (u - crest) * 0.5 / (1 - crest)) * 0.5 / (1 - crest)


def frame_shader(P, c, outward=None):
    """The look's square frame, 3 cells of c px for its depth, as bench.js' procFrame draws it: shade(px, py) from its
    top left, (r, g, b, a) or None outside it. outward: (x, y), y down, the way the edge faces for its light and its
    shadows; the frame's own when None."""
    q = c / look_edge(P)
    half = 3 * c / 2
    s, l, w = P["shadow"] * q, P["lines"] * q, P["width"] * q
    hh = half - s
    rr = min(2 * l + w + 0.5 * q, c - s)
    polish, profile, corners = P["polish"] / 100, P["profile"], P.get("corners", "round")
    # the metal's arrises round off over 0.6 units, between 15 and 35 % of it
    m = min(0.35, max(0.15, 0.6 / P["width"]))
    # an edge facing away from the light casts more outside, one facing it more on the plate
    away = -(outward[0] * SKY[0] + outward[1] * SKY[1]) if outward else 0

    # rr: the round corner's radius, or the bevel's side
    def sdf(px, py):
        ax, ay = abs(px - half), abs(py - half)
        if corners == "round":
            qx, qy = ax - (hh - rr), ay - (hh - rr)
            return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - rr
        qx, qy = ax - hh, ay - hh
        box = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0)
        if corners == "bevel":
            return max(box, (ax + ay - 2 * hh + rr) / math.sqrt(2))
        return box

    def metal(px, py, u):
        if profile == "double" and abs(u - 0.5) < 0.06:
            return 0.1
        if outward:
            gx, gy, gl = -outward[0], -outward[1], 1
        else:
            e = 0.25
            gx, gy = -(sdf(px + e, py) - sdf(px - e, py)), -(sdf(px, py + e) - sdf(px, py - e))
            gl = math.hypot(gx, gy) or 1
        k = ridge_slope(profile, u)
        if u < m:
            k = max(k, 1.2)
        elif u > 1 - m:
            k = min(k, -1.2)
        # the normal leans outwards by k (g points inwards)
        nx, ny, nz = _norm(-k * gx / gl, -k * gy / gl, 1)
        return reflect(2 * nz * (nx * SKY[0] + ny * SKY[1]), polish)

    def shade(px, py):
        d = -sdf(px, py)
        if d < 0:
            if s <= 0 or -d >= s:
                return None
            t = 1 + d / s
            return (0, 0, 0, min(1, SHADOW_OUT * t ** 1.5 * (1 + CAST * away)))
        if d < l:
            return (0.07, 0.07, 0.07, 1)
        if d < l + w:
            v = metal(px, py, (d - l) / w)
            return (v, v, v, 1)
        if d < 2 * l + w:
            return (0.12, 0.12, 0.12, 0.95)
        if s > 0 and d < 2 * l + w + s:
            t = 1 - (d - 2 * l - w) / s
            return (0, 0, 0, min(1, SHADOW_IN * t ** 1.5 * (1 - CAST * away)))
        return None

    return shade


def band_profile(P, n=TEXELS, length=4):
    """The border across, its frame's top edge in the middle, outside on the left, once for each way an edge faces:
    block i faces i * 360 / DIRS degrees counter-clockwise from the right. (n * DIRS) x length rows, all alike."""
    ss = 8
    row = []
    for i in range(DIRS):
        a = 2 * math.pi * i / DIRS
        shade = frame_shader(P, n, (math.cos(a), -math.sin(a)))
        for j in range(n):
            R = G = B = A = 0.0
            for b in range(ss):
                got = shade(1.5 * n, j + (b + 0.5) / ss)
                if got:
                    R += got[0] * got[3]
                    G += got[1] * got[3]
                    B += got[2] * got[3]
                    A += got[3]
            row.append((R / A, G / A, B / A, A / ss) if A > 0 else (0, 0, 0, 0))
    return n * DIRS, length, [row] * length


def write_look(P, thin):
    """Data/Look.lua: what the addon needs of the look the band draws, its colour and corners the options' defaults;
    and of the status bars' thin border."""
    def depth(B):
        e = look_edge(B)
        return e, B["shadow"], (B["shadow"] + B["lines"] + B["width"] / 2) / e

    e, out, inset = depth(P)
    te, tout, tinset = depth(thin)
    LOOK_LUA.write_text(
        "-- Generated by hud/tools/make_media.py: the look Media/BandKaLi.tga draws, one of the borders bench's\n"
        "-- (hud/bench/js/looks.js). edge: its depth at 100 %; out: how far it stands outside the plate's outline;\n"
        "-- inset: where a frame's background starts, in edges; dirs, texels: the band files hold the profile once for\n"
        "-- each way an edge faces, dirs blocks texels wide; thin: the status bars' border. Don't edit.\n"
        "local _, ns = ...\n\n"
        "ns.LOOK = {\n"
        f'    id = "{P["id"]}", edge = {e:g}, out = {out:g}, inset = {inset:.4f}, corners = "{P["corners"]}",\n'
        f"    dirs = {DIRS}, texels = {TEXELS},\n"
        f'    color = "{P["color"][1:]}", alpha = {P["alpha"]:g},\n'
        f"    thin = {{ edge = {te:g}, out = {tout:g}, inset = {tinset:.4f} }},\n"
        "}\n", encoding="utf-8", newline="\n")


def bar_profile(y):
    """Vertical enamel/metal glaze from bottom (0) to top (1), neutral greyscale for SetStatusBarColor."""
    if y < 0.14:
        return 0.38 + 0.26 * (y / 0.14)
    if y < 0.64:
        return 0.64 + 0.28 * ((y - 0.14) / 0.50)
    if y < 0.84:
        k = (y - 0.64) / 0.20
        return 0.92 + 0.08 * math.sin(k * math.pi)
    return 0.88 - 0.20 * ((y - 0.84) / 0.16)


def bar_forever():
    def px(x, y):
        lum = bar_profile(y)
        grain = 0.012 * math.sin(x * math.pi * 16) * math.cos(y * math.pi * 6)
        v = max(0.0, min(1.0, lum + grain))
        return (v, v, v, 1.0)

    return px


def bar_striped():
    def px(x, y):
        lum = bar_profile(y)
        stripe = 0.5 + 0.5 * math.cos((x * 8 + y * 2) * 2 * math.pi)
        v = max(0.0, min(1.0, lum * (0.86 + 0.16 * stripe)))
        return (v, v, v, 1.0)

    return px


def band_grain(P, n=16, length=64):
    """Specks over the band's metal, between its dark lines: white ones lighten, black ones darken, by their alpha;
    none off the metal. Seeded, so every run draws the same."""
    e = look_edge(P)
    lo, hi = (P["shadow"] + P["lines"]) / e, (P["shadow"] + P["lines"] + P["width"]) / e
    rng = random.Random(7)
    rows = []
    for _ in range(length):
        row = []
        for j in range(n):
            u = (j + 0.5) / n
            cover = max(0.0, min(1.0, min(u - lo, hi - u) * n + 0.5))
            g = max(-1.0, min(1.0, rng.gauss(0, 0.5)))
            c = 1.0 if g > 0 else 0.0
            row.append((c, c, c, abs(g) * 0.6 * cover))
        rows.append(row)
    return n, length, rows


def padlock(size, open_shackle=False):
    """Crisp white padlock silhouette (tinted gold/grey in game) with keyhole cut-out."""
    def px(x, y):
        bx = max(0.0, abs(x - 0.50) - 0.21)
        by = max(0.0, abs(y - 0.33) - 0.14)
        body_d = 0.07 - math.hypot(bx, by)
        a_body = edge(body_d, size)

        kh_circle = 0.055 - math.hypot(x - 0.50, y - 0.36)
        kh_slot = min(0.028 - abs(x - 0.50), y - 0.22, 0.36 - y)
        a_hole = edge(max(kh_circle, kh_slot), size)
        a_body = max(0.0, a_body - a_hole)

        stroke = 0.052
        if not open_shackle:
            if y >= 0.64:
                sd = abs(math.hypot(x - 0.50, y - 0.64) - 0.16)
            elif y >= 0.48:
                sd = min(abs(x - 0.34), abs(x - 0.66))
            else:
                sd = 1.0
        else:
            cx, cy, r = 0.56, 0.68, 0.15
            if y >= cy:
                sd = abs(math.hypot(x - cx, y - cy) - r)
            else:
                d_right = seg_dist(x, y, cx + r, 0.48, cx + r, cy)
                d_left = seg_dist(x, y, cx - r, 0.63, cx - r, cy)
                sd = min(d_right, d_left)
        a_shackle = edge(stroke - sd, size)
        if y < 0.52 and a_body > 0.5:
            a_shackle = 0.0

        a = max(a_body, a_shackle)
        if a <= 0:
            return (0, 0, 0, 0)
        lum = 0.85 + 0.15 * y
        return (lum, lum, lum, a)

    return px


def chevron(size):
    """Downward V-chevron centred in the square, round-capped: the windows' fold arrow."""
    ax, ay, bx, by, cx, cy, radius = 0.24, 0.60, 0.50, 0.34, 0.76, 0.60, 0.068

    def px(x, y):
        d = min(seg_dist(x, y, ax, ay, bx, by), seg_dist(x, y, bx, by, cx, cy))
        return (1.0, 1.0, 1.0, edge(radius - d, size))

    return px


def main():
    MEDIA.mkdir(parents=True, exist_ok=True)
    tga(MEDIA / "Disc.tga", 256, 256, disc(256))
    tga(MEDIA / "Fillet.tga", 256, 256, fillet(256))
    tga(MEDIA / "Bevel.tga", 256, 256, bevel(256))
    tga(MEDIA / "FilletMirror.tga", 256, 256, fillet_mirror(256))
    tga(MEDIA / "BevelMirror.tga", 256, 256, bevel_mirror(256))
    tga(MEDIA / "Shadow.tga", 128, 128, shadow())
    tga(MEDIA / "Ring.tga", 256, 256, ring(256))
    pick = sys.argv[sys.argv.index("--look") + 1] if "--look" in sys.argv else LOOK
    look, thin = next(P for P in looks() if P["id"] == pick), _js("KALI_THIN")
    tga_rows(MEDIA / "BandKaLi.tga", *band_profile(look))
    tga_rows(MEDIA / "BandThin.tga", *band_profile(dict(thin, corners="round")))
    tga_rows(MEDIA / "BandGrain.tga", *band_grain(look))
    write_look(look, thin)
    for old in ("BorderKaLiFine", "BorderKaLi", "BorderKaLiSquare", "BorderKaLiBevel", "BorderThin", "BorderThinSquare",
                "BorderThinBevel", "GrainBrushed", "GrainHammered", "GrainLeather", "GrainStone", "GrainLinen",
                "NotchKaLi", "BandKaLiFacet", "BandKaLiMatte", "BandKaLiGloss", "BandKaLiFacetMatte",
                "BandKaLiFacetGloss", "Fade"):
        (MEDIA / f"{old}.tga").unlink(missing_ok=True)
    tga(MEDIA / "Bar.tga", 128, 32, bar_forever())
    tga(MEDIA / "BarStriped.tga", 128, 32, bar_striped())
    tga(MEDIA / "Chevron.tga", 32, 32, chevron(32))
    tga(MEDIA / "Lock.tga", 32, 32, padlock(32, False))
    tga(MEDIA / "Unlock.tga", 32, 32, padlock(32, True))
    print(f"written: Disc, Fillet, Bevel, FilletMirror, BevelMirror, Shadow, Ring, BandKaLi ({pick}), BandThin, "
          "BandGrain, Data/Look.lua, Bar, BarStriped, Chevron, Lock, Unlock")


if __name__ == "__main__":
    main()
