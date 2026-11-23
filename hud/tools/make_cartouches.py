"""The cartouches Ikar picked from his own art (hud/art, cut by hud/tools/cut_art.py into hud/bench/art/gen): the fold
arrow of the chat and the damage meter sits in their ring. Writes Media/Cartouche<Id>.tga, each piece in the top left
of a 512 by 128 texture, and Data/Cartouches.lua: where in it the piece is and where its ring is.

Headless Edge scales the pieces down. Run after cut_art.py with: python -I hud/tools/make_cartouches.py [id ...]
(only the cartouches named, e.g. fire: seconds; none named, all of them)
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
TW, TH = 512, 128

# Ikar's picks (2026-11-14), two of each: id -> sheet, piece, turned over as the bench showed them (its "auto"); base,
# its flat line in the piece's pixels up from its foot, and rise, in UIParent's units, how far that line stands over
# the middle of the plate's metal on the window: fitted to Ikar's lifts in game over the chat 451 wide, the border at
# 80 % (at 125 % and 200 %: complex1 0 and -4, complex2 1 and -1, bronze1 -1 and -6, bronze2 0 and -5, steel1 -1 and
# -5, steel2 0 and -5, over bases 22.4, 4.4, 48.2, 43.7, 39.4, 39.4; then about -1.5 more at 100 % but complex2), by
# least squares over the three sizes: no straight line meets them all, the others within 0.7. Then lowered by Ikar's
# lifts at the defaults (size and border 100 %, 2026-11-15): complex1, complex2 and steel1 by 1, the others by 2.
PICKS = {
    "complex1": ("gemini-4", 8, False, 45.8, 1.74),
    "complex2": ("gemini-4", 10, False, 19.2, 1.53),
    "bronze1": ("gemini-3", 7, True, 78.4, 1.40),
    "bronze2": ("gemini-3", 1, True, 73.9, 2.40),
    "steel1": ("gemini-3", 6, True, 62.3, 0.74),
    "steel2": ("gemini-3", 3, True, 69.6, 2.40),
    # The styles' own (Ikar 2026-11-17, Data/Presets.lua: "take the top one in each"): base the Forest's bar's middle and
    # the Rune's slab's foot, measured on the cut piece; rise the others' middle, not yet tried in game. The Forest's
    # 63 less 5 since 2026-11-18: its foot 5 higher, the shadow under its ring see-through (cut_art.py's SHADED), the
    # same row on the window's line.
    "forest": ("gemini-7", 1, False, 58, 1.5),
    # The Rune's since 2026-11-18 its sheet from the cartouche prompt's fifth (Ikar: "for the rune, the last"),
    # gemini-8's top one before (a hexagon): its id kept, as the Steampunk's; base the middle of its rail, rows 301-340
    # under a foot at 475, its end caps hanging lower.
    # Since 2026-11-20 the third of a sheet from the prompt with strict and free parts (Ikar: "changed runic take the
    # third for the game"), a hexagon again: base the middle of its rail, rows 280-340 under a foot at 448.
    "rune": ("gemini-17", 3, False, 138, 1.5),
    # Then Steampunk's and Silver's (Ikar 2026-11-18: "Two new cartouche, the first for steampunk, second for the
    # silver"), the top one of each sheet as before: base the middle of its lowest long bar, measured on the cut piece
    # (Steampunk's bottom rod, rows 170-186; Silver's frame's bottom bar, 258-292), so its ring stands over the window as
    # the others' do; rise as Forest's and Rune's, not yet tried in game. The Silver's second since (Ikar the same day:
    # "10-2 would work better than 10-1, it is flatter at the bottom"), its bottom bar rows 269-305 under a foot at 361.
    # The Steampunk's since 2026-11-18 its sheet from the cartouche prompt's fifth (Ikar: "For the steampunk, the
    # last, replace the existing"), gemini-9's top one before: its id kept, so whoever chose it gets the new one; base
    # the middle of its rail, rows 360-394 under a foot at 465.
    # Since 2026-11-20 the fifth of a sheet from the prompt with strict and free parts, for a hexagon flat on top and
    # bottom (Ikar: "downloaded, use the last"; Gemini drew octagons): base the middle of its rail, rows 372-421 under
    # a foot at 433, the octagon's foot on the rail's, its end caps hanging lower.
    # Since the same evening the second of a sheet from that prompt (Ikar: "new cartouche for steam punk, number 2 and
    # 5", then "keep steampunk 1, rename it to steampunk, remove the 2"): its id kept; base the middle of its rail,
    # rows 376-423 under a foot at 436.
    "steampunk": ("gemini-21", 2, False, 36.5, 1.5),
    "silver": ("gemini-10", 2, False, 74, 1.5),
    # Then Golden's and Astronomy's (Ikar the same day: "I added arts for the gold and the astronomy version, work on
    # them"), the Golden sheet's second (its V2; Ikar the same day: "let's go with 11-2 for the gold", in place of the
    # top one) and the Astronomy sheet's one: base the middle of its lowest long bar, measured on the cut piece
    # (Golden's bottom bar, rows 202-266 over a box ending at 289, its shadow under it; Astronomy's, 301-321 over 471:
    # its ring and the spike under it hang over the window, as the Silver's do); rise as the others', not yet tried in
    # game.
    # The Golden's since 2026-11-20 the fourth of a sheet of five (Ikar: "new gold cartouche in", the fourth picked,
    # a shield over its ring, "can you remove the 3 little leaves on the bottom ? it would get too low"): base the middle
    # of its rail where it runs alone at its ends, rows 334-359 under a foot at 464.
    "golden": ("gemini-22", 4, False, 117.5, 1.5),
    # The Astronomy's since 2026-11-20 a sheet of one from the same prompt as the Rune's (Ikar: "and new astronomy
    # in"): base the middle of its bar, rows 941-1009 under a foot at 1105, its ring hanging lower.
    # Since the same day another sheet of one (Ikar: "I downlaoded another one for astronomy, replace it"), moon
    # phases in rings: base the middle of its bar, rows 889-950 under a foot at 1183, its ring and the point under it
    # hanging lower.
    # Since the same evening the last of a sheet of five ("and a new astronomy, the last one"), a twelve-sided ring
    # with the zodiac's signs: base the middle of its rail, rows 360-381 under a foot at 423, the ring hanging lower.
    "astronomy": ("gemini-23", 5, False, 52.5, 1.5),
    # Then the fire and the gem ones, from the same prompt, each matching its minimap ring (Ikar the same day: "Last for
    # fire", "4th for the gem"): base the middle of its rail, measured on the cut piece (the fire's rows 284-325 under a
    # foot at 410, its end caps hanging lower; the gem's 367-398 under 488); rise as the others', not yet tried in game.
    "fire": ("gemini-14", 5, False, 105.5, 1.5),
    "gem": ("gemini-15", 4, False, 105.5, 1.5),
}
# A ring the cut can't find, by id: its middle and inner radius, in the cut piece's pixels (the Rune's hexagon until its
# ring became round, 2026-11-18: cut_art.py had found the opening below its spike). Since 2026-11-20 the Rune's
# hexagon again, its radius its opening's half width, between its flat sides (704-919; the cut took its corners', 127),
# so the arrow stays inside; and the Astronomy's ring, its opening a little taller than wide (1075-1768 across,
# 227-964 down; the cut took its height's 369): its half width likewise; its new one's the same way (1196-1841
# across, 252-931 down; the cut took 339), until its round one of the same evening, the cut's. The Golden's since then:
# its opening round (800, 227.5, 112: 688-913 across, 115-340 down at its middle less the shield's tip, which dips 30
# into its top), the cut having taken the largest disc clear of that tip (97.5, its middle lower).
RINGS = {"rune": (812, 204, 108), "golden": (800, 227.5, 112)}
# Pieces whose well is painted into the art over all its opening, not a disc the addon draws under it: a hexagon's
# corners stand past a disc of its half width (the Rune's and the Steampunk's until their rings became round,
# 2026-11-18, the Rune's again since 2026-11-20; the Steampunk's octagon since the same day, the cut's ring its flat
# sides' half width, 142-144 each way), the Astronomy's opening a little taller than wide (the same day; round in
# its twelve-sided ring since that evening, painted all the same), and
# the Silver's soft shadow, left where
# its white was taken off (cut_art.py's WHITE_WELLS), runs out to its ring (its well alpha 0 in Data/Cartouches.lua, so
# the addon's draws nothing).
PAINTED_WELLS = {"silver", "rune", "astronomy", "steampunk"}
# Ikar 2026-11-16, each Ornate again without its blue: what its gold and its blue become, in this order after it (Recolour
# in the page), and for a part besides, what its silver scrollwork and the gold on its blue become. Silver and gold are
# the piece's own, the darker gold its gold darkened, gray the silver's colour on the blue's light, the bronze Bronze
# 2's metal, measured on its art (Bronze 1's is brass, hardly apart from the gold). Picked after trying bronze, silver
# and both golds each way: Ornate 1 in dark gold, its blue gray ("replace the blue with gray for the shading", lost in
# silver; "version 3 is good"), and inverted ("silver gold for the first"): that one's colours swapped, its gold
# leaves in its silver ones' shaded silver, its silver leaves dark gold, its scrollwork dark gold, the silver lights on
# its edges kept as on that one's gray (its gold leaves gray, its silver ones kept, "not great"; on their own light all
# of them went white, "instead of inverting"; then the art's lit silver, "too white"). Ornate 2 inverted ("bronze
# silver for the second"), its blue gray: its silver scrollwork, the art's right side, bronze too ("the right side mix
# of bronze and silver"), the braid on its ribbons silver ("the ribbon also turn the text to bronze, should be kept
# silver"), its bar bronze ("the bottom bar should be bronze too"). Same piece, so its base and rise; the ids picked
# before are kept.
VARIANTS = {
    "complex1": [("complex1darkgold", "darkgold", "gray"),
                 ("complex1silverdarkgold", "shaded", "darkgold", {"silver": "darkgold"})],
    "complex2": [("complex2bronze", "bronze", "gray", {"silver": "bronze", "trim": "silver", "bar": "bronze"}),
                 ("complex2silver", "silver", "bronze")],
}
# Picks made in their recolours only: the Ornates as drawn, with their blue, "not needed" (Ikar 2026-11-16).
RECOLOURED_ONLY = {"complex1", "complex2"}
BRONZE = "bronze2"


def ordered():
    """Each pick as (id, its PICKS entry, recolour): recolour None, or what its gold and its blue become."""
    for ident, pick in PICKS.items():
        if ident not in RECOLOURED_ONLY:
            yield ident, pick, None
        for variant, *colours in VARIANTS.get(ident, ()):
            yield variant, pick, colours


RECOLOUR_JS = r"""// The Ornate art's two colours, its gold and its blue, each given a metal: every pixel takes the target's
// colour at the same rank (OKLab: mean and spread of lightness and chroma matched, hue moved by the difference of the
// means); greys and the art's own silver stay, unless apply's opts give its silver scrollwork and the gold on its
// blue their own. A metal is described by measure(): {mL, sL, mC, sC, h}.
const Recolour = (() => {
  const lin = c => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
  const gam = c => (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);
  function toLab(r, g, b) {
    r = lin(r / 255); g = lin(g / 255); b = lin(b / 255);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
  }
  function toRgb(L, a, b) {
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
  }
  const inGamut = c => c.every(v => v >= -1e-4 && v <= 1 + 1e-4);
  // Out of the screen's colours: chroma given up, never hue or lightness.
  function fit(L, C, h) {
    L = Math.min(1, Math.max(0, L));
    let k = 1;
    if (!inGamut(toRgb(L, C * Math.cos(h), C * Math.sin(h)))) {
      let lo = 0, hi = 1;
      for (let i = 0; i < 16; i++) {
        const t = (lo + hi) / 2;
        if (inGamut(toRgb(L, C * t * Math.cos(h), C * t * Math.sin(h)))) lo = t; else hi = t;
      }
      k = lo;
    }
    return toRgb(L, C * k * Math.cos(h), C * k * Math.sin(h)).map(v => Math.round(255 * gam(Math.min(1, Math.max(0, v)))));
  }
  const smooth = (e0, e1, x) => { const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
  const DEG = Math.PI / 180;
  const angle = (h, c) => Math.abs(((h - c) / DEG + 540) % 360 - 180);
  // OKLCh hues: the art's gold about 80°, its enamel's blue about 265°, soft edges; greys (chroma under 0.03) out.
  const GOLD = 80, BLUE = 262, HALF = 45, EDGE = 20;
  function read(d) {
    const n = d.length / 4, L = new Float32Array(n), C = new Float32Array(n), H = new Float32Array(n), A = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const [l, a, b] = toLab(d[4 * i], d[4 * i + 1], d[4 * i + 2]);
      L[i] = l; C[i] = Math.hypot(a, b); H[i] = Math.atan2(b, a); A[i] = d[4 * i + 3] / 255;
    }
    return { n, L, C, H, A };
  }
  const chromatic = (px, i) => smooth(0.02, 0.045, px.C[i]) * px.A[i];
  const gold = (px, i) => chromatic(px, i) * (1 - smooth(HALF, HALF + EDGE, angle(px.H[i], GOLD * DEG)));
  const blue = (px, i) => chromatic(px, i) * (1 - smooth(HALF, HALF + EDGE, angle(px.H[i], BLUE * DEG)));
  // the art's silver: grey and lit, its dark outlines left out
  const silver = (px, i) => px.A[i] * (1 - smooth(0.015, 0.03, px.C[i])) * smooth(0.45, 0.55, px.L[i]);
  // a metal's own art: everything solid with some colour
  const metal = (px, i) => smooth(0.02, 0.045, px.C[i]) * px.A[i];
  function measure(px, weight) {
    let sw = 0, sL = 0, sC = 0, sx = 0, sy = 0;
    const w = new Float32Array(px.n);
    for (let i = 0; i < px.n; i++) {
      w[i] = weight(px, i);
      if (w[i] <= 0.5) continue;
      sw += w[i]; sL += w[i] * px.L[i]; sC += w[i] * px.C[i];
      sx += w[i] * Math.cos(px.H[i]); sy += w[i] * Math.sin(px.H[i]);
    }
    const mL = sL / sw, mC = sC / sw;
    let vL = 0, vC = 0;
    for (let i = 0; i < px.n; i++) if (w[i] > 0.5) { vL += w[i] * (px.L[i] - mL) ** 2; vC += w[i] * (px.C[i] - mC) ** 2; }
    return { n: Math.round(sw), mL, sL: Math.sqrt(vL / sw), mC, sC: Math.sqrt(vC / sw), h: Math.atan2(sy, sx) };
  }
  // Rank matching: lightness and chroma keep their place in the part's spread; hue moves by the difference of the
  // means. A part with no colour of its own (grey: the art's silver scrollwork) takes the metal's mean colour.
  const map = (L, C, h, from, to) => [to.mL + (L - from.mL) * to.sL / from.sL,
                                      from.grey ? to.mC : Math.max(0, to.mC + (C - from.mC) * to.sC / from.sC),
                                      from.grey ? to.h : h - from.h + to.h];
  // Chamfer distance to the nearest set texel, 3 a step and 4 a diagonal.
  function distance(set, w, h) {
    const d = new Float32Array(w * h);
    for (let i = 0; i < w * h; i++) d[i] = set[i] ? 0 : 1e9;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = y * w + x;
      let v = d[i];
      if (x > 0) v = Math.min(v, d[i - 1] + 3);
      if (y > 0) {
        v = Math.min(v, d[i - w] + 3);
        if (x > 0) v = Math.min(v, d[i - w - 1] + 4);
        if (x < w - 1) v = Math.min(v, d[i - w + 1] + 4);
      }
      d[i] = v;
    }
    for (let y = h - 1; y >= 0; y--) for (let x = w - 1; x >= 0; x--) {
      const i = y * w + x;
      let v = d[i];
      if (x < w - 1) v = Math.min(v, d[i + 1] + 3);
      if (y < h - 1) {
        v = Math.min(v, d[i + w] + 3);
        if (x < w - 1) v = Math.min(v, d[i + w + 1] + 4);
        if (x > 0) v = Math.min(v, d[i + w - 1] + 4);
      }
      d[i] = v;
    }
    return d;
  }
  // The set closed over its gaps up to 2 r wide: grown by r, then shrunk by r.
  function closed(set, w, h, r) {
    const near = distance(set, w, h), outside = new Uint8Array(w * h), out = new Uint8Array(w * h);
    for (let i = 0; i < w * h; i++) outside[i] = near[i] > 3 * r ? 1 : 0;
    const far = distance(outside, w, h);
    for (let i = 0; i < w * h; i++) out[i] = far[i] > 3 * r ? 1 : 0;
    return out;
  }
  // The ribbon: the blue closed over what lies on it, its braid and its runes (strokes about 5 texels wide).
  const RIBBON_GAP = 6, BRAID_GROW = 5;
  // The frame, kept as it is: the ring (its metal ends 1.17 times its inner radius out, Ornate 1 and 2) and the bar,
  // the run of rows from the foot that are solid most of the width, with the rows just over it.
  const RING_OUT = 1.18, BAR_SOLID = 0.8, BAR_OVER = 3;
  function regions(px, w, ring) {
    const h = px.n / w, frame = new Uint8Array(px.n);
    let top = h;
    for (let y = h - 1, seen = false; y >= 0; y--) {
      let solid = 0;
      for (let x = 0; x < w; x++) solid += px.A[y * w + x] > 0.8;
      if (solid >= BAR_SOLID * w) { seen = true; top = y; } else if (seen) break;
    }
    const [cx, cy, r] = ring, bar = new Uint8Array(px.n);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = y * w + x, inRing = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) < r * RING_OUT;
      bar[i] = y >= top - BAR_OVER && !inRing ? 1 : 0;
      frame[i] = bar[i] || inRing ? 1 : 0;
    }
    const isBlue = new Uint8Array(px.n);
    for (let i = 0; i < px.n; i++) isBlue[i] = blue(px, i) > 0.5 ? 1 : 0;
    const ribbon = closed(isBlue, w, h, RIBBON_GAP);
    // The gold on it, its braid: the gold the blue closes over gaps a little narrower, so the ribbon's own edge, where
    // a scroll crossing it leaves it between blue and more blue, stays out; grown back over the braid's crossings.
    const seed = closed(isBlue, w, h, RIBBON_GAP - 1);
    for (let i = 0; i < px.n; i++) seed[i] = seed[i] && gold(px, i) > 0.5 ? 1 : 0;
    const near = distance(seed, w, h), trim = new Uint8Array(px.n);
    for (let i = 0; i < px.n; i++) trim[i] = ribbon[i] && near[i] <= 3 * BRAID_GROW ? 1 : 0;
    return { frame, bar, ribbon, trim };
  }
  // The darker gold: the art's own, this much lower in OKLab lightness, its chroma this much richer (Ikar
  // 2026-11-16: "2 option of gold, like now, and darker"; darker alone, it went olive).
  const DARK_L = 0.12, DARK_C = 1.2;
  // The shaded silver: the art's silver scrollwork, shading and all, this much lower in lightness, its spread this much
  // wider (Ikar 2026-11-16, on the Ornate's lit silver: "a bit too white, should be more shaded, silvery").
  const SHADE_L = 0.09, SHADE_S = 1.5;
  // goldTo, blueTo: "silver" or "gold" (the art's own), "darkgold", "gray" (the silver's colour on the blue's light:
  // Ikar 2026-11-16, "replace the blue with gray for the shading", lost in the silver), "shaded" (with opts only), or
  // a measured metal. opts, for a part of the art besides: { w, ring: [x, y, inner radius] in the art's texels,
  // silver: what its silver scrollwork becomes (its frame kept), trim: what the gold lying on its blue becomes, bar:
  // what its bar becomes, on its scrollwork's light so the two match (Ikar 2026-11-16: "the bottom bar should be
  // bronze too") }.
  function apply(d, goldTo, blueTo, opts = {}) {
    const px = read(d), from = { gold: measure(px, gold), blue: measure(px, blue) }, own = measure(px, silver);
    const dark = Object.assign({}, from.gold, { mL: from.gold.mL - DARK_L, mC: from.gold.mC * DARK_C,
                                                sC: from.gold.sC * DARK_C });
    const named = { silver: own, gold: from.gold, darkgold: dark,
                    gray: Object.assign({}, own, { mL: from.blue.mL, sL: from.blue.sL }) };
    let reg = null, scroll = () => 0, onBar = () => 0, scrollwork = null;
    if (opts.silver || opts.trim || opts.bar) {
      reg = regions(px, opts.w, opts.ring);
      // the art's silver scrollwork: grey, out of the frame and off the ribbon, its dark outlines left out; its bar alike
      const grey = (p, i) => p.A[i] * (1 - smooth(0.02, 0.045, p.C[i])) * smooth(0.2, 0.3, p.L[i]);
      scroll = (p, i) => (reg.frame[i] || reg.ribbon[i] ? 0 : grey(p, i));
      onBar = (p, i) => (reg.bar[i] ? grey(p, i) : 0);
      scrollwork = measure(px, scroll);
      named.shaded = Object.assign({}, scrollwork, { mL: scrollwork.mL - SHADE_L, sL: scrollwork.sL * SHADE_S });
    }
    const pick = t => named[t] || t;
    const to = { gold: pick(goldTo), blue: pick(blueTo) };
    if (reg) {
      from.trim = from.gold;
      to.trim = opts.trim ? pick(opts.trim) : to.gold;
      if (opts.silver) { from.silver = Object.assign({}, scrollwork, { grey: true }); to.silver = pick(opts.silver); }
      if (opts.bar) { from.bar = Object.assign({}, scrollwork, { grey: true }); to.bar = pick(opts.bar); }
    }
    for (let i = 0; i < px.n; i++) {
      const wg = gold(px, i), wb = blue(px, i), ws = to.silver ? scroll(px, i) : 0;
      let which = wg >= wb ? "gold" : "blue", w = Math.max(wg, wb);
      if (ws > w) { which = "silver"; w = ws; }
      const wr = to.bar ? onBar(px, i) : 0;
      if (wr > w) { which = "bar"; w = wr; }
      w /= Math.max(1e-6, px.A[i]);
      if (w <= 0) continue;
      if (which === "gold" && reg && reg.trim[i]) which = "trim";
      if (to[which] === from[which]) continue;  // kept as it is
      const [L2, C2, h2] = map(px.L[i], px.C[i], px.H[i], from[which], to[which]);
      const k = Math.min(1, w);
      // blended in OKLab, so the art's edges between a recoloured part and a grey stay soft
      const a1 = px.C[i] * Math.cos(px.H[i]), b1 = px.C[i] * Math.sin(px.H[i]);
      const a2 = C2 * Math.cos(h2), b2 = C2 * Math.sin(h2);
      const L = px.L[i] + (L2 - px.L[i]) * k, a = a1 + (a2 - a1) * k, b = b1 + (b2 - b1) * k;
      const [r, g, bb] = fit(L, Math.hypot(a, b), Math.atan2(b, a));
      d[4 * i] = r; d[4 * i + 1] = g; d[4 * i + 2] = bb;
    }
    return { from, silver: own };
  }
  return { read, measure, metal, gold, blue, silver, apply, DEG };
})();
"""

PAGE = r"""<!doctype html><meta charset="utf-8"><pre id="export"></pre><script>
const PICKS = DATA, TW = @TW@, TH = @TH@;
// Clear texels take their solid neighbours' colour, so the game's filtering draws no dark fringe round the art.
function bleed(d) {
  const filled = new Uint8Array(TW * TH);
  for (let i = 0; i < TW * TH; i++) filled[i] = d[4 * i + 3] > 0 ? 1 : 0;
  for (let pass = 0; pass < 4; pass++) {
    const next = filled.slice();
    for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
      const i = y * TW + x;
      if (filled[i]) continue;
      let r = 0, g = 0, b = 0, n = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const X = x + dx, Y = y + dy, j = Y * TW + X;
        if (X < 0 || Y < 0 || X >= TW || Y >= TH || !filled[j]) continue;
        r += d[4 * j]; g += d[4 * j + 1]; b += d[4 * j + 2]; n++;
      }
      if (n) { d[4 * i] = r / n; d[4 * i + 1] = g / n; d[4 * i + 2] = b / n; next[i] = 1; }
    }
    filled.set(next);
  }
}
RECOLOUR
function base64(bytes) {
  let s = "";
  for (let i = 0; i < bytes.length; i += 32768) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 32768));
  return btoa(s);
}
const load = u => new Promise(done => { const img = new Image(); img.onload = () => done(img); img.src = u; });
function measured(img) {
  const cv = document.createElement("canvas");
  cv.width = img.naturalWidth; cv.height = img.naturalHeight;
  const c = cv.getContext("2d");
  c.drawImage(img, 0, 0);
  return Recolour.measure(Recolour.read(c.getImageData(0, 0, cv.width, cv.height).data), Recolour.metal);
}
Promise.all([Promise.all(PICKS.map(pk => load(pk.url))), Promise.all(PICKS.map(pk => pk.metal && load(pk.metal)))])
  .then(([imgs, metals]) => {
    const out = PICKS.map((pk, n) => {
      const img = imgs[n], [y0, y1] = pk.box, w = img.naturalWidth, h = y1 - y0, k = Math.min(TW / w, TH / h);
      const cv = document.createElement("canvas");
      cv.width = TW; cv.height = TH;
      const c = cv.getContext("2d");
      c.imageSmoothingQuality = "high";
      // recoloured at the art's own size, before it's scaled down
      let src = img;
      if (pk.recolour) {
        src = document.createElement("canvas");
        src.width = w; src.height = img.naturalHeight;
        const sc = src.getContext("2d");
        sc.drawImage(img, 0, 0);
        const full = sc.getImageData(0, 0, src.width, src.height);
        const metal = metals[n] && measured(metals[n]), as = m => (m === "bronze" ? metal : m);
        const [goldTo, blueTo, more] = pk.recolour;
        const opts = more && { w, ring: pk.artRing, silver: as(more.silver), trim: as(more.trim), bar: as(more.bar) };
        Recolour.apply(full.data, as(goldTo), as(blueTo), opts);
        sc.putImageData(full, 0, 0);
      }
      if (pk.flip) { c.translate(0, h * k); c.scale(1, -1); }
      c.drawImage(src, 0, y0, w, h, 0, 0, w * k, h * k);
      const data = c.getImageData(0, 0, TW, TH).data;
      // inside the ring, its dark fill cleared, its metal kept: the addon's well and arrow go there
      const [rx, ry, rr] = pk.ring.map(v => v * k);
      for (let y = Math.max(0, Math.floor(ry - rr)); y < Math.min(TH, Math.ceil(ry + rr)); y++)
        for (let x = Math.max(0, Math.floor(rx - rr)); x < Math.min(TW, Math.ceil(rx + rr)); x++) {
          const i = 4 * (y * TW + x);
          if (Math.hypot(x + 0.5 - rx, y + 0.5 - ry) > rr) continue;
          data[i + 3] *= Math.min(1, Math.max(0, (Math.max(data[i], data[i + 1], data[i + 2]) - 20) / 40));
        }
      bleed(data);
      return { k, rgba: base64(new Uint8Array(data.buffer)) };
    });
    document.getElementById("export").textContent = JSON.stringify(out);
  });
</script>"""


def gen_data():
    text = (BENCH / "js/gen-data.js").read_text(encoding="utf-8")
    return json.loads(text[text.index("{"):text.rindex("}") + 1])


def render(picks):
    work = Path(tempfile.mkdtemp(prefix="kali-cartouche-"))
    try:
        page = work / "render.html"
        page.write_text(PAGE.replace("DATA", json.dumps(picks), 1).replace("RECOLOUR", RECOLOUR_JS, 1)
                        .replace("@TW@", str(TW), 1).replace("@TH@", str(TH), 1), encoding="utf-8")
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={work / 'profile'}",
             "--allow-file-access-from-files", "--virtual-time-budget=60000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, encoding="utf-8", timeout=300)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    found = re.search(r'<pre id="export">(.+?)</pre>', result.stdout, re.S)
    if not found:
        raise SystemExit(f"the page drew nothing (run hud/tools/cut_art.py first?)\n{result.stderr[-2000:]}")
    return json.loads(found.group(1))


def write_tga(path, rgba):
    # Type 2, 32 bits, 8 of them alpha, rows from the bottom up, BGRA.
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, TW, TH, 32, 8))
    stride = TW * 4
    for y in range(TH - 1, -1, -1):
        row = bytearray(rgba[y * stride:(y + 1) * stride])
        row[0::4], row[2::4] = row[2::4], row[0::4]
        out += row
    path.write_bytes(bytes(out))


# Cartouches written as a BLP carrying its mipmaps, not a TGA (Ikar 2026-11-18, of the gem's: "some resizing artifact,
# aliasing"): the game makes no mipmaps for a TGA, so where a cartouche is drawn smaller than its texture (the gem's
# ring 61 texels across, 34 UIParent units at 100 %) its thin lines break up, TRILINEAR or not. Each level halved from
# the one above, its colour weighted by its alpha, down to 1 by 1; uncompressed BGRA (BLP2, colour encoding 3), as
# Pagle's minimap icons, which the client draws. The gem's alone so far, the finest art; the others as before.
MIPPED = {"gem"}
BLP_HEADER = 1172  # magic, type, four encoding bytes, size, 16 mip offsets and sizes, the 256-entry palette


def halve(rgba, w, h):
    """The next mip level: each texel the mean of the 2 by 2 (or 2 by 1) above it, its colour weighted by alpha (a
    clear one's the plain mean, so the colour bled under it carries down)."""
    nw, nh = max(1, w // 2), max(1, h // 2)
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        ys = (2 * y, 2 * y + 1) if h > 1 else (0,)
        for x in range(nw):
            xs = (2 * x, 2 * x + 1) if w > 1 else (0,)
            wr = wg = wb = pr = pg = pb = a = n = 0
            for sy in ys:
                for sx in xs:
                    i = (sy * w + sx) * 4
                    r, g, b, pa = rgba[i:i + 4]
                    wr += r * pa
                    wg += g * pa
                    wb += b * pa
                    pr += r
                    pg += g
                    pb += b
                    a += pa
                    n += 1
            o = (y * nw + x) * 4
            out[o:o + 4] = bytes((round(wr / a), round(wg / a), round(wb / a), round(a / n)) if a
                                 else (round(pr / n), round(pg / n), round(pb / n), 0))
    return bytes(out), nw, nh


def write_blp(path, rgba):
    """rgba: TW by TH, rows from the top. BLP2, colour encoding 3 (BGRA, rows from the top), 8 bits of alpha, alpha
    encoding 8, mipmaps present: every level down to 1 by 1."""
    levels, w, h = [], TW, TH
    while True:
        level = bytearray(rgba)
        level[0::4], level[2::4] = level[2::4], level[0::4]
        levels.append(bytes(level))
        if w == 1 and h == 1:
            break
        rgba, w, h = halve(rgba, w, h)
    offsets, at = [], BLP_HEADER
    for level in levels:
        offsets.append(at)
        at += len(level)
    pad = [0] * (16 - len(levels))
    header = b"BLP2" + struct.pack("<IBBBBII", 1, 3, 8, 8, 1, TW, TH) \
        + struct.pack("<16I", *offsets, *pad) + struct.pack("<16I", *(len(v) for v in levels), *pad) + bytes(1024)
    assert len(header) == BLP_HEADER
    path.write_bytes(header + b"".join(levels))


# The well in a ring: its metal's colour this dark, this opaque (Ikar 2026-11-14: half see-through too light, black
# too heavy).
WELL_SHADE, WELL_ALPHA = 0.2, 0.8


def well(rgba, cx, cy, r):
    """The ring's metal just outside r (texture pixels, rows from the top), averaged and darkened: r, g, b, a."""
    total, n = [0, 0, 0], 0
    for y in range(max(0, int(cy - r * 1.2)), min(TH, int(cy + r * 1.2) + 1)):
        for x in range(max(0, int(cx - r * 1.2)), min(TW, int(cx + r * 1.2) + 1)):
            i = (y * TW + x) * 4
            if r * 1.03 <= ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5 <= r * 1.15 and rgba[i + 3] > 200:
                total = [t + rgba[i + c] for c, t in enumerate(total)]
                n += 1
    return [round(t / max(n, 1) / 255 * WELL_SHADE, 3) for t in total] + [WELL_ALPHA]


# How far from its middle a painted well goes, in its ring's radii: past a hexagon's corners (1.155), short of what a
# see-through line across the ring would let it reach (the Silver's black lines, its ground hardly darker).
WELL_REACH = 1.2

# Pieces whose foot is cleared of what hangs under their ring, by id (Ikar 2026-11-20: "for the runic, can you remove
# the decoration at the bottom of the hexagone ?"), in the cut piece's pixels: the ring's middle across, the row under
# which it's cleared (the rail's foot), where the ring's outer edge is lowest, at its middle, how much higher it runs a
# texel out each side, and how far out the clearing goes. The Rune's: the plate under its hexagon and the two tabs
# beside it, the hexagon's lower edges measured where nothing hangs (rows 358 and 364 at 730 and 740, 884 and 894).
# The Golden's (Ikar 2026-11-20: "remove the 3 little leaves on the bottom ? it would get too low"): the three leaves
# hanging from the band under its ring's two curls, 743-857 across, rows 410-463, cut level with the band's foot either
# side of them (row 410 at 743 and 857; the band runs lower behind them, cut there too).
CLEARED_FEET = {"rune": (812, 341, 407, 0.6, 210), "golden": (800, 360, 410, 0, 60)}


def clear_foot(rgba, k, y0, spec):
    """What lies under the rail and outside the ring's outer edge taken off (texture pixels, rows from the top; the
    cut piece's rows from y0, k texels to its pixel), its edge soft over a texel."""
    cx, below, apex, slope, reach = spec
    out = bytearray(rgba)
    for ty in range(TH):
        y = y0 + (ty + 0.5) / k
        if y <= below:
            continue
        for tx in range(TW):
            x = (tx + 0.5) / k
            if abs(x - cx) > reach:
                continue
            keep = min(1.0, max(0.0, (apex - slope * abs(x - cx) - y) * k + 0.5))
            i = (ty * TW + tx) * 4 + 3
            out[i] = round(out[i] * keep)
    return bytes(out)


def paint_well(rgba, cx, cy, r, colour):
    """The well's colour under the art over its opening: from the ring's middle through every texel not solid, within
    WELL_REACH of its radius r, the art laid over the well (texture pixels, rows from the top)."""
    out = bytearray(rgba)
    wr, wg, wb, wa = (c * 255 for c in colour)
    seen, todo = set(), [(int(cx), int(cy))]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < TW and 0 <= y < TH) \
                or (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > (r * WELL_REACH) ** 2:
            continue
        seen.add((x, y))
        i = (y * TW + x) * 4
        a = rgba[i + 3] / 255
        if a >= 0.98:
            continue
        w = wa / 255 * (1 - a)
        total = a + w
        for c, under in enumerate((wr, wg, wb)):
            out[i + c] = round((rgba[i + c] * a + under * w) / total)
        out[i + 3] = round(total * 255)
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return bytes(out)


def main():
    data = gen_data()
    picks, entries, order = [], [], [ident for ident, _, _ in ordered()]
    # Only the cartouches named, if any (new ones: seconds, not all of them again); the others' lines kept as they were.
    only = set(sys.argv[1:])
    if only - set(order):
        raise SystemExit(f"no such cartouche: {', '.join(sorted(only - set(order)))}")
    out = ADDON / "Data/Cartouches.lua"
    kept = dict(re.findall(r"^    (\w+) = (\{ file = .*\},)$", out.read_text(encoding="utf-8"), re.M)) \
        if only and out.exists() else {}
    missing = [i for i in order if only and i not in only and i not in kept]
    if missing:
        raise SystemExit(f"{', '.join(missing)}: no line yet, name it too")
    sheet, n = PICKS[BRONZE][:2]
    metal = (BENCH / data[sheet][n - 1]["src"]).as_uri()
    for ident, (sheet, n, flip, base, rise), recolour in ordered():
        if only and ident not in only:
            continue
        pc = data[sheet][n - 1]
        y0, y1 = pc["box"]
        rx, ry, rr = RINGS.get(ident, pc["ring"])
        ring = (rx, y1 - ry if flip else ry - y0, rr)
        bronze = recolour and "bronze" in json.dumps(recolour)
        picks.append({"url": (BENCH / pc["src"]).as_uri(), "box": pc["box"], "flip": flip, "ring": ring,
                      "artRing": pc["ring"], "recolour": recolour, "metal": bronze and metal})
        entries.append((ident, pc, ring, base, rise))
    got = render(picks)
    made = {}
    for (ident, pc, (rx, ry, rr), base, rise), result in zip(entries, got):
        name = "Cartouche" + ident[0].upper() + ident[1:]
        rgba = base64.b64decode(result["rgba"])
        y0, y1 = pc["box"]
        w, h, k = pc["w"], y1 - y0, result["k"]
        if ident in CLEARED_FEET:
            rgba = clear_foot(rgba, k, y0, CLEARED_FEET[ident])
        colour = well(rgba, rx * k, ry * k, rr * k)
        if ident in PAINTED_WELLS:
            rgba = paint_well(rgba, rx * k, ry * k, rr * k, colour)
            colour = colour[:3] + [0]
        # the game finds a path with no extension as .blp before .tga: the other kind goes, so it can't be found instead
        media, kind = ADDON / "Media", "blp" if ident in MIPPED else "tga"
        (write_blp if kind == "blp" else write_tga)(media / f"{name}.{kind}", rgba)
        (media / f"{name}.{'tga' if kind == 'blp' else 'blp'}").unlink(missing_ok=True)
        wc = ", ".join(f"{v:g}" for v in colour)
        made[ident] = (f'{{ file = "Interface\\\\AddOns\\\\KaLiHUD\\\\Media\\\\{name}", w = {w}, h = {h}, '
                       f"right = {w * k / TW:.4f}, bottom = {h * k / TH:.4f}, ringX = {rx:g}, ringY = {ry:g}, ringR = {rr:g}, "
                       f"base = {base:g}, rise = {rise:g}, well = {{ {wc} }} }},")
    lines = [f"    {ident} = {made.get(ident) or kept[ident]}" for ident in order]
    (ADDON / "Data/Cartouches.lua").write_text(
        "-- Generated by hud/tools/make_cartouches.py: the cartouches from Ikar's art (hud/art), Media/Cartouche*.tga.\n"
        "-- w, h: the piece in its art's pixels; right, bottom: how much of the texture it fills; ringX, ringY, ringR:\n"
        "-- its ring's centre from the piece's top left, and inner radius, where the fold arrow goes; base: its flat line\n"
        "-- up from its foot; rise: that line over the middle of the plate's metal on the window; well: the colour inside\n"
        "-- its ring, its metal darkened. Don't edit.\n"
        "local _, ns = ...\n\n"
        "ns.CARTOUCHES = {\n" + "\n".join(lines) + "\n}\n"
        f"ns.CARTOUCHE_ORDER = {{ {', '.join(json.dumps(i) for i in order)} }}\n",
        encoding="utf-8", newline="\n")
    print(f"written: {', '.join(e[0] for e in entries)} and Data/Cartouches.lua")


if __name__ == "__main__":
    main()
