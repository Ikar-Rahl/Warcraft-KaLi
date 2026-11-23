"""A double click's icon, kept for later and used nowhere yet (Ikar 2026-11-17, of five drawn: "ok, option 4, store
it, but we won't use it for now"): the house editor's left click (housing-hotkey-icon-leftclick, 64x64 texels, as the
hints show it in place of « Clic », Core/Locale.lua), moved down and right by 5.5 texels, with two waves off its left
button's corner, a click's as tutorials draw them, two for two clicks. The waves are drawn in the set's own manner, as
its wheel-up arrow: the lit button's cream over its amber glow. No atlas of the game's draws a double click.

The waves follow the mouse's outline, measured on the game's texels: the top of a superellipse (power 2.5) centred
(30.75, 31), 19.75 texels across and 23 down, pushed 5.5 and 12 texels out, from 116 to 162 degrees and from 121 to
157 (90 the top, 180 the left), each 3.4 texels thick with round ends.

Run with: python -I hud/tools/make_double_click.py
Writes hud/art/double-click.png. To use it in the game, it goes into the addon's Media/ as a texture of its own.
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali.art import write_png  # noqa: E402
import make_icons  # noqa: E402

OUT = ROOT / "hud/art/double-click.png"
N = 64
CREAM = (255, 252, 207)          # the set's lit button
AMBER = (239, 146, 55)           # its glow
SHIFT = 5.5                      # the mouse moved down and right, for the waves' room
SAMPLES = 4                      # per texel, each way


def mouse():
    """The house editor's left click, its texels premultiplied (0..1), moved by SHIFT with bilinear sampling."""
    e = make_icons.atlases()["housing-hotkey-icon-leftclick"]
    m = max(e["members"], key=lambda m: (m["r"] - m["l"]) * (m["b"] - m["t"]))
    cw, ch, rows = make_icons.texels(m)

    def tex(x, y):
        if 0 <= x < cw and 0 <= y < ch:
            r, g, b, a = rows[y][4 * x:4 * x + 4]
            a /= 255
            return (r / 255 * a, g / 255 * a, b / 255 * a, a)
        return (0.0, 0.0, 0.0, 0.0)
    out = []
    for Y in range(N):
        row = []
        for X in range(N):
            sx, sy = X - SHIFT, Y - SHIFT
            x0, y0 = math.floor(sx), math.floor(sy)
            fx, fy = sx - x0, sy - y0
            c = [0.0] * 4
            for xx, yy, w in ((x0, y0, (1 - fx) * (1 - fy)), (x0 + 1, y0, fx * (1 - fy)),
                              (x0, y0 + 1, (1 - fx) * fy), (x0 + 1, y0 + 1, fx * fy)):
                for i, v in enumerate(tex(xx, yy)):
                    c[i] += v * w
            row.append(c)
        out.append(row)
    return out


def wave(t0, t1, push, steps=12):
    """The mouse's outline pushed out by `push`, from angle t0 to t1, as points."""
    pts = []
    for k in range(steps + 1):
        t = math.radians(t0 + (t1 - t0) * k / steps)
        c, s = math.cos(t), math.sin(t)
        x = 30.75 + (19.75 + push) * math.copysign(abs(c) ** 0.8, c)
        y = 31 - (23 + push) * math.copysign(abs(s) ** 0.8, s)
        pts.append((x + SHIFT, y + SHIFT))
    return pts


def coverage(lines, width):
    """How much of each texel the round-ended lines cover, from SAMPLES x SAMPLES points."""
    segs = [(a, b) for pts in lines for a, b in zip(pts, pts[1:])]
    r2 = (width / 2) ** 2

    def near(px, py):
        for (ax, ay), (bx, by) in segs:
            vx, vy, wx, wy = bx - ax, by - ay, px - ax, py - ay
            t = max(0.0, min(1.0, (wx * vx + wy * vy) / (vx * vx + vy * vy)))
            if (wx - t * vx) ** 2 + (wy - t * vy) ** 2 <= r2:
                return True
        return False
    return [[sum(near(X + (i + 0.5) / SAMPLES, Y + (j + 0.5) / SAMPLES)
                 for j in range(SAMPLES) for i in range(SAMPLES)) / SAMPLES ** 2 for X in range(N)] for Y in range(N)]


def blur(cov, r=2, passes=3):
    """Three box blurs, near enough a Gaussian, for the glow."""
    a = cov
    for _ in range(passes):
        a = [[sum(row[max(0, x - r):x + r + 1]) / (2 * r + 1) for x in range(N)] for row in a]
        a = [[sum(a[y][x] for y in range(max(0, Y - r), min(N, Y + r + 1))) / (2 * r + 1) for x in range(N)]
             for Y in range(N)]
    return a


def over(img, cov, rgb, alpha=1.0):
    for y in range(N):
        for x in range(N):
            a = min(1.0, cov[y][x] * alpha)
            if a > 0:
                px = img[y][x]
                img[y][x] = [rgb[0] / 255 * a + px[0] * (1 - a), rgb[1] / 255 * a + px[1] * (1 - a),
                             rgb[2] / 255 * a + px[2] * (1 - a), a + px[3] * (1 - a)]


def main():
    img = mouse()
    cov = coverage([wave(116, 162, 5.5), wave(121, 157, 12.0)], 3.4)
    over(img, [[min(1.0, v * 2.2) for v in row] for row in blur(cov)], AMBER, 0.55)
    over(img, cov, CREAM)
    data = bytearray()
    for row in img:
        for r, g, b, a in row:
            data += bytes((round(min(1, r / a) * 255), round(min(1, g / a) * 255), round(min(1, b / a) * 255),
                           round(a * 255))) if a > 0 else b"\0\0\0\0"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    write_png(OUT, N, N, bytes(data))
    print(f"wrote {OUT.relative_to(ROOT).as_posix()}, {N}x{N}")


if __name__ == "__main__":
    main()
