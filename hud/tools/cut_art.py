"""Ikar's generated cartouche sheets (hud/art/gemini-*.jpeg: ten pieces each, two columns of five on a dark ground; the
styles' own since 2026-11-17, one column of two on white, COLUMNS) cut into keyed PNGs for hud/bench/cartouche.html:
hud/bench/art/gen/<sheet>-<n>.png, and hud/bench/js/gen-data.js with each
piece's size, its ring's centre and inner radius (where the fold arrow goes), its solid rows and how it would rest on a
line.

Headless Edge decodes and keys the sheets, so no imaging library is needed. Run with:
python -I hud/tools/cut_art.py [sheet ...] (only the sheets named, e.g. gemini-13: seconds; none named, all of them)
"""
import base64
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.paths import EDGE  # noqa: E402

HUD = ROOT / "hud"
SHEETS = HUD / "art"
OUT = HUD / "bench/art/gen"
JS_OUT = HUD / "bench/js/gen-data.js"
sys.stdout.reconfigure(encoding="utf-8")
# Sheets of one column, each piece the sheet's width (Ikar 2026-11-17, the styles' cartouches: Forest, Rune; 2026-11-18,
# five each for the Steampunk and the Silver ones, then five for the Golden one and one for the Astronomy one); the rest
# two. PIECES: how many a sheet holds, ten unless said.
# Then five each matching the minimap rings (Ikar 2026-11-18: "Added the steampunk, the fire and gem one", from
# Gemini with the cartouche prompt: one column of five on white): gemini-13 the steampunk, 14 the fire, 15 the gem;
# then 16 the rune ("added the new runnic also"); 2026-11-20, 17 the rune again and 18 the astronomy, from the prompts
# with strict and free parts ("changed runic take the third for the game, and new astronomy in"): one of one; then 19
# the steampunk again, from the same prompt for a hexagon flat on top and bottom (Gemini drew octagons); 20 the
# astronomy again, one of one ("I downlaoded another one for astronomy, replace it"); 21 the steampunk again, five
# from the same prompt ("new cartouche for steam punk, number 2 and 5"); 22 the golden again, five ("new gold
# cartouche in"); 23 the astronomy again, five ("and a new astronomy, the last one"), cut as on any ground: its
# silver is near white, and taken off white its zodiac ring's light segments, reached through a gap in its outline,
# came out see-through (Ikar: "the astronomy one is corrupter"); it has no glow to take off.
COLUMNS = {"gemini-7": 1, "gemini-8": 1, "gemini-9": 1, "gemini-10": 1, "gemini-11": 1, "gemini-12": 1,
           "gemini-13": 1, "gemini-14": 1, "gemini-15": 1, "gemini-16": 1, "gemini-17": 1, "gemini-18": 1,
           "gemini-19": 1, "gemini-20": 1, "gemini-21": 1, "gemini-22": 1, "gemini-23": 1}
PIECES = {"gemini-7": 2, "gemini-8": 2, "gemini-9": 5, "gemini-10": 5, "gemini-11": 5, "gemini-12": 1,
          "gemini-13": 5, "gemini-14": 5, "gemini-15": 5, "gemini-16": 5, "gemini-17": 5, "gemini-18": 1,
          "gemini-19": 5, "gemini-20": 1, "gemini-21": 5, "gemini-22": 5, "gemini-23": 5}
# Sheets on a white ground (the Rune's, and the three from the cartouche prompt): their glows were drawn over it, so
# they're taken off it (WHITE in the page).
ON_WHITE = {"gemini-8", "gemini-13", "gemini-14", "gemini-15", "gemini-16", "gemini-17", "gemini-18", "gemini-19", "gemini-20",
            "gemini-21", "gemini-22"}
# The art outlined on a white ground (the Forest's, Ikar 2026-11-18: "some issue with half transparent part, especially
# jaring in the forest one"): its leaves had come out half see-through (taken off white as its glows), its glows a
# dark green fog, the white shaded under its vines solid and pale. Cut along the art's outlines instead (SHADE in the
# page): its shading a see-through shadow down to its outlines, its leaves solid, its glows a see-through light (they
# were dropped first, Ikar the same day: "where are they ? They all should have half see through parts").
SHADED = {"gemini-7"}
# A dark ground the art's own dark lines touch (the Silver's, the same day: "cut and massacred"): its outlines and
# grooves had gone with the ground, see-through lines across its bars and filigree. The ground only where a disc this
# big fits (OPEN in the page).
OPENED = {"gemini-10": 4}
# A ground drawn with cracks (the Silver sheet's, 2026-11-18: they stray up to 20 from its grey, measured): LO..HI for
# it, so they go with the ground. Others 8..34.
TOLERANCE = {"gemini-10": (20, 46)}
# Numbers printed beside the pieces (the Silver sheet's 1 to 5), boxes in the sheet's pixels: a blob wholly inside one
# is no art and goes; art a box reaches into stays.
NUMBERS = {"gemini-10": [(1830, 285, 1895, 360), (1830, 712, 1895, 788), (1830, 1114, 1895, 1190),
                         (1830, 1534, 1895, 1610), (1905, 1954, 1970, 2030)],
           # the Golden sheet's V1 to V5, left of its pieces (V4's bar starts at 92, under its box)
           "gemini-11": [(46, 150, 130, 203), (46, 438, 130, 493), (46, 749, 130, 803), (46, 1050, 130, 1105),
                         (46, 1340, 130, 1393)]}
# Rings painted white over their opening (the Silver sheet): white up to a soft edge, then the ring's black line; the
# white taken off inside that line (WELLS in the page), so the ring is open as the others' and its well drawn under it.
WHITE_WELLS = {"gemini-10"}
# A dark ground lit unevenly, its pieces' soft shadows on it (the Golden sheet's, 2026-11-18: 26 at its edges to 42
# under its pieces, measured): each pixel measured from the ground where it lies (VIGNETTE in the page), not from the
# sheet's edge's, so all of the ground goes clear and a shadow stays, black and see-through.
VIGNETTED = {"gemini-11"}
# A ground of one key colour, red (the Astronomy sheet's: lighter in its middle, darker down to a black band under it):
# the red taken off the art (KEY in the page), its steel and blue gems having none.
KEYED = {"gemini-12"}

# LO..HI: distance from the ground (largest channel difference) over which a pixel turns from clear to solid.
# HOLE: a flat ground-coloured patch at least this big inside a piece is a hole (the ring's, the filigree's).
# On a white ground (WHITE): a glow tints the ground the art closes in (between the Forest cartouche's vines), so a patch
# at least TINTED big and at most TINT from the ground on average is a hole too (the silver's highlights are smaller,
# measured 2026-11-17); and a pixel at least BRIGHT in its brightest channel, reached from the ground through such
# pixels, is the art's colour laid over white, taken off it (colour to alpha): as see-through as it's near white, so
# a glow fades out where it met the ground, not standing as a pale patch (the Rune cartouche's embers). The art's
# dark outlines stop it: what they close in stays solid.
# The art outlined on white (SHADE): a near-white patch the art closes in is a hole if SHADE_DEEP into it from its edge
# somewhere and its blue and red within CYAN of each other on average (the silver's highlights are thinner or cyan, the
# crest's lines thinner, the leaves' hearts yellow, measured 2026-11-18). From the ground, the reach takes a step only
# down (at most SHADOW_TOL lighter), or between two pixels at least BRIGHT: so it follows a shadow down to the
# outline and doesn't climb back into the art past a thin tip. It goes through a grey at least BRIGHT; a grey down to
# SHADOW_LO, its red and blue within NEUTRAL, greener than they are by NEUTRAL at most (from GREEN[0], by GREEN[1] of
# its green besides: a glow over the shadow; the green vines' darks are as green, darker); and the glow's green (GLOW:
# greener than its red and blue by that, at least GLOW_HI and under GLOW_TOP, its chroma under GLOW_SAT of it or its
# green under GLOW_DIM). What it reaches is a shadow and a light: black, as opaque as its brightest channel is short of
# PURE; and GLOW_RGB, as opaque as GLOW_A of its darkest channel short of white; mixed by its green over GLOW_TINT. A
# glow laid on white darkens it, so taken off white it would darken what's under it (Ikar 2026-11-18: "jaring"): it
# lights it instead.
# A dark ground the art's dark lines touch (OPEN, a disc's radius): only where the disc fits is ground, reached from the
# sheet's edge or a hole of OPEN_HOLE such middles at most LO from the ground on average; then grown back by the disc.
# A ground lit unevenly (VIGNETTE): each block of VIG_BLOCK pixels at least VIG_OPEN of them as grey as the ground
# (chroma at most VIG_GREY, red over blue at most VIG_WARM: no gold; under VIG_DARK: no gem), open ground; its ground
# those within VIG_NEAR of their upper quartile (a shadow is darker), averaged; any other block takes its neighbours',
# so under a piece the ground around it, not its gaps' shadow; laid smoothly between blocks' middles. A pixel is then
# measured from that, and by how much warmer it is, red over blue (the gold's darks are as dark as the ground, but
# brown: V4's bar end had come out a fifth see-through), and a partly clear one unmixed from it: a shadow comes out
# black, or dark brown where the gold lit it, and see-through. A patch the art closes in is a hole if at least VIG_HOLE big and on average no warmer than
# VIG_TINT, red over blue: the ground in the gaps between the scrolls is 11 to 21 (lit by them), the art's own darks 30
# and more (the Golden sheet, measured 2026-11-18); the shadows there keep a gap from being as flat as a hole elsewhere.
# A ground of one key colour (KEY): how much redder a pixel is than its green and blue, against the ground's where it
# lies (between the nearest pixels of pure key each side on its row: green and blue at most KEY_GB, red over them at
# least KEY_MIN); the art has none, so it's as see-through as it's that red, its colour what's left with the red taken
# off (under KEY_CLEAR, clear). A row with no pure key is clear (the black band under the Astronomy sheet's red).
PAGE = r"""<!doctype html><meta charset="utf-8"><pre id="export"></pre><script>
const [LO, HI] = @TOLERANCE@, HOLE = 150, WHITE = ONWHITE, TINTED = 1000, TINT = 16, BRIGHT = 200;
const MASKS = @NUMBERS@, WELLS = @WELLS@, PURE = 240, WELL_MIN = 3000, DARK = 110;
const OPEN = @OPEN@, OPEN_HOLE = 400, SHADE = @SHADE@, SHADE_DEEP = 5, CYAN = 3;
const GLOW = 12, GLOW_HI = 130, GLOW_SAT = 0.22, GLOW_DIM = 225, GLOW_TINT = [6, 20], GLOW_RGB = [150, 245, 130], GLOW_A = 0.8, GLOW_TOP = 250;
const NEUTRAL = 3, SHADOW_LO = 45, SHADOW_TOL = 6, GREEN = [80, 0.1];
const VIGNETTE = @VIGNETTE@, VIG_BLOCK = 32, VIG_GREY = 8, VIG_WARM = 4, VIG_DARK = 80, VIG_OPEN = 0.9, VIG_NEAR = 6, VIG_HOLE = 20, VIG_TINT = 25;
const KEY = @KEY@, KEY_GB = 12, KEY_MIN = 100, KEY_CLEAR = 0.04;
const img = new Image();
img.onload = () => {
  const W = img.naturalWidth, H = img.naturalHeight, N = W * H;
  const cv = document.createElement("canvas");
  cv.width = W; cv.height = H;
  const ctx = cv.getContext("2d");
  ctx.drawImage(img, 0, 0);
  const p = ctx.getImageData(0, 0, W, H).data;
  const edge = [[], [], []];
  const take = i => { for (let k = 0; k < 3; k++) edge[k].push(p[i * 4 + k]); };
  for (let x = 0; x < W; x += 2) { take(x); take((H - 1) * W + x); }
  for (let y = 0; y < H; y += 2) { take(y * W); take(y * W + W - 1); }
  const bg = edge.map(v => v.sort((a, b) => a - b)[v.length >> 1]);
  // The ground's colour where each pixel lies (VIGNETTE, above), else null: the sheet's edge's everywhere (bg).
  const field = !VIGNETTE ? null : (() => {
    const S = VIG_BLOCK, BX = Math.ceil(W / S), BY = Math.ceil(H / S), M = BX * BY;
    const val = new Float32Array(3 * M), ok = new Uint8Array(M);
    for (let by = 0; by < BY; by++) for (let bx = 0; bx < BX; bx++) {
      const lums = [], idx = [];
      for (let y = by * S; y < Math.min(H, by * S + S); y++) for (let x = bx * S; x < Math.min(W, bx * S + S); x++) {
        const i = y * W + x, r = p[4 * i], g = p[4 * i + 1], b = p[4 * i + 2], l = (r + g + b) / 3;
        if (Math.max(r, g, b) - Math.min(r, g, b) <= VIG_GREY && r - b <= VIG_WARM && l < VIG_DARK) { lums.push(l); idx.push(i); }
      }
      if (lums.length < VIG_OPEN * S * S) continue;
      const q3 = lums.slice().sort((u, v) => u - v)[Math.floor(lums.length * 0.75)], s = [0, 0, 0];
      let n = 0;
      for (let k = 0; k < lums.length; k++) {
        if (Math.abs(lums[k] - q3) > VIG_NEAR) continue;
        for (let c = 0; c < 3; c++) s[c] += p[4 * idx[k] + c];
        n++;
      }
      const m = by * BX + bx;
      for (let c = 0; c < 3; c++) val[3 * m + c] = s[c] / n;
      ok[m] = 1;
    }
    // a block with too few: its filled neighbours' mean, again till every block has one
    for (let left = M - ok.reduce((u, v) => u + v, 0); left > 0;) {
      const now = ok.slice();
      for (let by = 0; by < BY; by++) for (let bx = 0; bx < BX; bx++) {
        const m = by * BX + bx;
        if (ok[m]) continue;
        const s = [0, 0, 0];
        let n = 0;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const X = bx + dx, Y = by + dy, o = Y * BX + X;
          if (X < 0 || Y < 0 || X >= BX || Y >= BY || !ok[o]) continue;
          for (let c = 0; c < 3; c++) s[c] += val[3 * o + c];
          n++;
        }
        if (n) { for (let c = 0; c < 3; c++) val[3 * m + c] = s[c] / n; now[m] = 1; left--; }
      }
      ok.set(now);
    }
    const out = new Float32Array(3 * N);
    for (let y = 0; y < H; y++) {
      const fy = Math.min(BY - 1, Math.max(0, (y + 0.5) / S - 0.5)), y0 = Math.floor(fy), y1 = Math.min(BY - 1, y0 + 1), ty = fy - y0;
      for (let x = 0; x < W; x++) {
        const fx = Math.min(BX - 1, Math.max(0, (x + 0.5) / S - 0.5)), x0 = Math.floor(fx), x1 = Math.min(BX - 1, x0 + 1), tx = fx - x0;
        for (let c = 0; c < 3; c++)
          out[3 * (y * W + x) + c] = (1 - ty) * ((1 - tx) * val[3 * (y0 * BX + x0) + c] + tx * val[3 * (y0 * BX + x1) + c])
            + ty * ((1 - tx) * val[3 * (y1 * BX + x0) + c] + tx * val[3 * (y1 * BX + x1) + c]);
      }
    }
    return out;
  })();
  const under = (i, c) => field ? field[3 * i + c] : bg[c];
  // VIGNETTE: how much warmer too (red over blue): the gold's darks are as dark as the ground, but brown
  const warmer = i => field ? Math.abs(p[4 * i] - p[4 * i + 2] - under(i, 0) + under(i, 2)) : 0;
  const d = new Uint8Array(N);
  for (let i = 0; i < N; i++)
    d[i] = Math.round(Math.min(255, Math.max(Math.abs(p[4 * i] - under(i, 0)), Math.abs(p[4 * i + 1] - under(i, 1)), Math.abs(p[4 * i + 2] - under(i, 2)), warmer(i))));
  // How far each pixel of a mask lies from the nearest pixel out of it, in thirds of a pixel (3 straight, 4 across;
  // the sheet's edge doesn't count): 0 out of it.
  const far = mask => {
    const D = new Int32Array(N);
    for (let i = 0; i < N; i++) D[i] = mask[i] ? 1 << 29 : 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x;
      if (!D[i]) continue;
      let v = D[i];
      if (x > 0) v = Math.min(v, D[i - 1] + 3);
      if (y > 0) {
        v = Math.min(v, D[i - W] + 3);
        if (x > 0) v = Math.min(v, D[i - W - 1] + 4);
        if (x < W - 1) v = Math.min(v, D[i - W + 1] + 4);
      }
      D[i] = v;
    }
    for (let y = H - 1; y >= 0; y--) for (let x = W - 1; x >= 0; x--) {
      const i = y * W + x;
      if (!D[i]) continue;
      let v = D[i];
      if (x < W - 1) v = Math.min(v, D[i + 1] + 3);
      if (y < H - 1) {
        v = Math.min(v, D[i + W] + 3);
        if (x < W - 1) v = Math.min(v, D[i + W + 1] + 4);
        if (x > 0) v = Math.min(v, D[i + W - 1] + 4);
      }
      D[i] = v;
    }
    return D;
  };
  // Ground-like patches: ground if they reach the sheet's edge, or are a big flat hole.
  const comp = new Int32Array(N).fill(-1), ground = [], stack = new Int32Array(N);
  const inner = SHADE ? far(d.map(v => v < HI ? 1 : 0)) : null;
  for (let s = 0; s < N; s++) {
    if (d[s] >= HI || comp[s] >= 0) continue;
    const id = ground.length;
    let top = 0, n = 0, sum = 0, tint = 0, deep = 0, rim = false;
    stack[top++] = s; comp[s] = id;
    const push = j => { if (comp[j] < 0 && d[j] < HI) { comp[j] = id; stack[top++] = j; } };
    while (top) {
      const i = stack[--top], x = i % W, y = (i - x) / W;
      n++; sum += d[i];
      tint += p[4 * i + 2] - p[4 * i];
      if (SHADE && inner[i] > deep) deep = inner[i];
      if (x === 0 || y === 0 || x === W - 1 || y === H - 1) rim = true;
      if (x > 0) push(i - 1);
      if (x < W - 1) push(i + 1);
      if (y > 0) push(i - W);
      if (y < H - 1) push(i + W);
    }
    ground.push(rim || (n >= HOLE && sum / n < LO) || (WHITE && n >= TINTED && sum / n < TINT) || (SHADE && deep >= 3 * SHADE_DEEP && Math.abs(tint / n) <= CYAN)
      || (VIGNETTE && n >= VIG_HOLE && tint / n >= -VIG_TINT));
  }
  const a = new Uint8Array(N), taken = new Uint8Array(N);
  for (let i = 0; i < N; i++)
    a[i] = comp[i] < 0 || !ground[comp[i]] ? 255 : Math.round(255 * Math.min(1, Math.max(0, (d[i] - LO) / (HI - LO))));
  // The ground among pixels like it (like): the patches where a disc of radius r fits, each kept if it reaches the
  // sheet's edge or keep(its size, its mean of value) says it's a hole; then grown back by r over pixels like it. A
  // line of ground-like pixels narrower than the disc (the art's dark outlines, its grooves) stays art.
  const opened = (like, r, value, keep) => {
    const D = far(like), core = new Uint8Array(N), seen = new Uint8Array(N), list = new Int32Array(N);
    for (let s = 0; s < N; s++) {
      if (seen[s] || D[s] <= 3 * r) continue;
      let top = 0, n = 0, sum = 0, rim = false;
      stack[top++] = s; seen[s] = 1;
      while (top) {
        const i = stack[--top], x = i % W, y = (i - x) / W;
        list[n++] = i; sum += value(i);
        if (x === 0 || y === 0 || x === W - 1 || y === H - 1) rim = true;
        for (const j of [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1])
          if (j >= 0 && !seen[j] && D[j] > 3 * r) { seen[j] = 1; stack[top++] = j; }
      }
      if (rim || keep(n, sum / n)) for (let k = 0; k < n; k++) core[list[k]] = 1;
    }
    const out = far(core.map(v => 1 - v));
    return like.map((v, i) => v && out[i] <= 3 * r ? 1 : 0);
  };
  if (OPEN) {
    // A dark ground (OPEN, the disc's radius): ground-like pixels only where opened() finds the ground, turning solid
    // over LO..HI as before; an outline, a groove or an engraving's black, however dark, stays art. A hole: at least
    // OPEN_HOLE of the disc's middles, as flat as the ground.
    const g = opened(d.map(v => v < HI ? 1 : 0), OPEN, i => d[i], (n, mean) => n >= OPEN_HOLE && mean < LO);
    for (let i = 0; i < N; i++)
      a[i] = g[i] ? Math.round(255 * Math.min(1, Math.max(0, (d[i] - LO) / (HI - LO)))) : 255;
  }
  if (KEY) {
    // A key ground (above): every pixel's alpha and colour from it, kept as they are after (taken).
    const key = i => p[4 * i] - Math.min(p[4 * i + 1], p[4 * i + 2]);
    const pure = i => Math.max(p[4 * i + 1], p[4 * i + 2]) <= KEY_GB && key(i) >= KEY_MIN;
    const left = new Int32Array(W), right = new Int32Array(W), B = [0, 0, 0];
    for (let y = 0; y < H; y++) {
      const row = y * W;
      for (let x = 0, last = -1; x < W; x++) { if (pure(row + x)) last = x; left[x] = last; }
      for (let x = W - 1, next = -1; x >= 0; x--) { if (pure(row + x)) next = x; right[x] = next; }
      for (let x = 0; x < W; x++) {
        const i = row + x, l = left[x], r = right[x];
        taken[i] = 1;
        if (l < 0 && r < 0) { a[i] = 0; continue; }
        const wl = r < 0 ? 1 : l < 0 ? 0 : r === l ? 0 : (r - x) / (r - l);
        for (let c = 0; c < 3; c++)
          B[c] = (wl > 0 ? wl * p[4 * (row + l) + c] : 0) + (wl < 1 ? (1 - wl) * p[4 * (row + r) + c] : 0);
        let al = Math.min(1, 1 - key(i) / (B[0] - Math.min(B[1], B[2])));
        if (al < KEY_CLEAR) al = 0;
        a[i] = Math.round(255 * al);
        if (al > 0 && al < 1)
          for (let c = 0; c < 3; c++) p[4 * i + c] = Math.round(Math.min(255, Math.max(0, (p[4 * i + c] - (1 - al) * B[c]) / al)));
      }
    }
  }
  if (WHITE || SHADE) {
    const seen = new Uint8Array(N), hi = i => Math.max(p[4 * i], p[4 * i + 1], p[4 * i + 2]);
    const chroma = i => hi(i) - Math.min(p[4 * i], p[4 * i + 1], p[4 * i + 2]);
    let top = 0;
    for (let i = 0; i < N; i++)
      if (comp[i] >= 0 && ground[comp[i]]) { seen[i] = 1; stack[top++] = i; }
    // SHADE (above): the glow's green, a grey, a shadow's grey; each step down, or bright to bright.
    const glow = i => {
      const r = p[4 * i], g = p[4 * i + 1], b = p[4 * i + 2];
      return g - Math.max(r, b) >= GLOW && g >= GLOW_HI && g < GLOW_TOP && ((g - Math.min(r, b)) / g < GLOW_SAT || g < GLOW_DIM);
    };
    const lum = i => (p[4 * i] + p[4 * i + 1] + p[4 * i + 2]) / 3;
    const down = (i, j) => lum(j) <= lum(i) + SHADOW_TOL || (hi(i) >= BRIGHT && hi(j) >= BRIGHT);
    const grey = j => {
      const r = p[4 * j], g = p[4 * j + 1], b = p[4 * j + 2];
      const green = g - Math.max(r, b);
      return Math.abs(b - r) <= NEUTRAL && green >= -NEUTRAL && g >= SHADOW_LO
        && green <= NEUTRAL + (g >= GREEN[0] ? GREEN[1] * g : 0);
    };
    const shade = j => (hi(j) >= BRIGHT && chroma(j) < GLOW) || glow(j) || grey(j);
    const lit = new Float32Array(N);
    const reach = (i, j) => {
      if (seen[j]) return;
      if (SHADE ? down(i, j) && shade(j) : hi(j) >= BRIGHT) { seen[j] = 1; stack[top++] = j; }
    };
    while (top) {
      const i = stack[--top], x = i % W, y = (i - x) / W;
      if (SHADE) {
        const r = p[4 * i], g = p[4 * i + 1], b = p[4 * i + 2];
        const t = Math.min(1, Math.max(0, (g - Math.max(r, b) - GLOW_TINT[0]) / (GLOW_TINT[1] - GLOW_TINT[0])));
        const dark = Math.max(0, (PURE - hi(i)) / PURE), light = GLOW_A * (255 - Math.min(r, g, b)) / 255;
        const al = (1 - t) * dark + t * light;
        a[i] = Math.round(255 * al); lit[i] = al > 0 ? t * light / al : 0;
        taken[i] = 1;
      } else a[i] = d[i] < LO ? 0 : d[i];
      if (x > 0) reach(i, i - 1);
      if (x < W - 1) reach(i, i + 1);
      if (y > 0) reach(i, i - W);
      if (y < H - 1) reach(i, i + W);
    }
    // the shadow's and the light's colour, once every pixel has been looked at (their neighbours read the art's)
    if (SHADE) for (let i = 0; i < N; i++) if (taken[i]) for (let c = 0; c < 3; c++) p[4 * i + c] = Math.round(GLOW_RGB[c] * lit[i]);
  }
  // A ring painted white over its opening (WELLS): each big patch of white the ground doesn't reach, out from its
  // middle to the ring's black line (where most rays first meet a pixel darker than DARK); inside it, the white taken
  // off: clear where white, its soft edge a see-through shadow. Those pixels keep that colour (taken).
  if (WELLS) {
    const seen = new Uint8Array(N), white = i => Math.min(p[4 * i], p[4 * i + 1], p[4 * i + 2]) >= PURE;
    for (let s = 0; s < N; s++) {
      if (seen[s] || !white(s)) continue;
      let top = 0, n = 0, sx = 0, sy = 0, rim = false;
      stack[top++] = s; seen[s] = 1;
      while (top) {
        const i = stack[--top], x = i % W, y = (i - x) / W;
        n++; sx += x; sy += y;
        if (x === 0 || y === 0 || x === W - 1 || y === H - 1) rim = true;
        for (const j of [x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1])
          if (j >= 0 && !seen[j] && white(j)) { seen[j] = 1; stack[top++] = j; }
      }
      if (rim || n < WELL_MIN) continue;
      const cx = sx / n, cy = sy / n, re = Math.sqrt(n / Math.PI), reach = [];
      for (let k = 0; k < 72; k++) {
        const ang = k * Math.PI / 36;
        for (let r = re * 0.8; r < re * 1.5; r += 0.5) {
          const x = Math.round(cx + r * Math.cos(ang)), y = Math.round(cy + r * Math.sin(ang)), i = y * W + x;
          if (x < 0 || y < 0 || x >= W || y >= H) break;
          if (Math.max(p[4 * i], p[4 * i + 1], p[4 * i + 2]) < DARK) { reach.push(r); break; }
        }
      }
      if (reach.length < 36) continue;
      const R = reach.sort((u, v) => u - v)[reach.length >> 1];
      for (let y = Math.max(0, Math.floor(cy - R)); y <= Math.min(H - 1, Math.ceil(cy + R)); y++)
        for (let x = Math.max(0, Math.floor(cx - R)); x <= Math.min(W - 1, Math.ceil(cx + R)); x++) {
          if ((x - cx) ** 2 + (y - cy) ** 2 > R * R) continue;
          // black, as dark as the pixel is short of PURE: the JPEG's specks of colour in the white go with it
          const i = y * W + x, grey = (p[4 * i] + p[4 * i + 1] + p[4 * i + 2]) / 3;
          a[i] = Math.round(255 * Math.min(1, Math.max(0, (PURE - grey) / PURE))); taken[i] = 1;
          for (let c = 0; c < 3; c++) p[4 * i + c] = 0;
        }
    }
  }
  // A number printed beside the pieces (MASKS), its faint edge too (under 128, not a blob below; the Silver sheet's 2
  // stood as a ghost, Ikar 2026-11-18 taking that piece): each patch of pixels not clear wholly inside a box goes.
  if (MASKS.length) {
    const seen = new Uint8Array(N), list = new Int32Array(N);
    for (const [mx0, my0, mx1, my1] of MASKS)
      for (let y = my0; y <= Math.min(my1, H - 1); y++) for (let x = mx0; x <= Math.min(mx1, W - 1); x++) {
        const s = y * W + x;
        if (!a[s] || seen[s]) continue;
        let top = 0, n = 0, inside = true;
        stack[top++] = s; seen[s] = 1;
        while (top) {
          const i = stack[--top], ix = i % W, iy = (i - ix) / W;
          list[n++] = i;
          if (ix < mx0 || ix > mx1 || iy < my0 || iy > my1) inside = false;
          for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
            const jx = ix + dx, jy = iy + dy, j = jy * W + jx;
            if (jx >= 0 && jx < W && jy >= 0 && jy < H && a[j] && !seen[j]) { seen[j] = 1; stack[top++] = j; }
          }
        }
        if (inside) for (let k = 0; k < n; k++) a[list[k]] = 0;
      }
  }
  // Pieces: solid blobs in each half of the sheet. The big ones are bodies (two sharing most of their height are one
  // piece's, a wing apart from its ring); each other blob (a spike, a banner, a leaf its glow no longer holds on) joins
  // the body whose rows it's nearest, by its middle among bodies it reaches into, since pieces' spikes can overlap in
  // height.
  const own = new Int32Array(N).fill(-1), blobs = [], pieces = [];
  for (const [hx0, hx1] of (COLUMNS === 1 ? [[0, W]] : [[0, W >> 1], [W >> 1, W]])) {
    const first = blobs.length;
    for (let y = 0; y < H; y++) for (let x = hx0; x < hx1; x++) {
      const s = y * W + x;
      if (a[s] < 128 || own[s] >= 0) continue;
      const id = blobs.length, b = { n: 0, sy: 0, x0: x, x1: x, y0: y, y1: y };
      blobs.push(b);
      let top = 0;
      stack[top++] = s; own[s] = id;
      while (top) {
        const i = stack[--top], ix = i % W, iy = (i - ix) / W;
        b.n++; b.sy += iy;
        if (ix < b.x0) b.x0 = ix;
        if (ix > b.x1) b.x1 = ix;
        if (iy > b.y1) b.y1 = iy;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const jx = ix + dx, jy = iy + dy, j = jy * W + jx;
          if (jx >= hx0 && jx < hx1 && jy >= 0 && jy < H && own[j] < 0 && a[j] >= 128) { own[j] = id; stack[top++] = j; }
        }
      }
    }
    // a number printed beside the pieces (MASKS) is no art
    const printed = b => MASKS.some(m => b.x0 >= m[0] && b.x1 <= m[2] && b.y0 >= m[1] && b.y1 <= m[3]);
    const mine = blobs.slice(first).filter(b => b.n >= 30 && !printed(b)), big = Math.max(...mine.map(b => b.n)), bodies = [];
    mine.forEach(b => { b.cy = b.sy / b.n; });
    for (const b of mine.filter(b => b.n >= big * 0.15).sort((p, q) => p.cy - q.cy)) {
      const body = bodies.find(o => Math.min(o.y1, b.y1) - Math.max(o.y0, b.y0) >= Math.min(o.y1 - o.y0, b.y1 - b.y0) / 2);
      if (!body) { bodies.push({ y0: b.y0, y1: b.y1, n: b.n, sy: b.sy, cy: b.cy, blobs: [] }); continue; }
      body.y0 = Math.min(body.y0, b.y0); body.y1 = Math.max(body.y1, b.y1);
      body.n += b.n; body.sy += b.sy; body.cy = body.sy / body.n;
    }
    const gap = (o, b) => Math.max(0, o.y0 - b.y1, b.y0 - o.y1), mid = (o, b) => Math.abs(o.cy - b.cy);
    for (const b of mine) {
      const body = bodies.reduce((m, o) => gap(o, b) < gap(m, b) || (gap(o, b) === gap(m, b) && mid(o, b) < mid(m, b)) ? o : m);
      body.blobs.push(b);
    }
    for (const body of bodies) {
      const k = pieces.length;
      body.blobs.forEach(b => { b.piece = k; });
      const x0 = Math.max(0, Math.min(...body.blobs.map(b => b.x0)) - 2), y0 = Math.max(0, Math.min(...body.blobs.map(b => b.y0)) - 2);
      const x1 = Math.min(W, Math.max(...body.blobs.map(b => b.x1)) + 3), y1 = Math.min(H, Math.max(...body.blobs.map(b => b.y1)) + 3);
      pieces.push({ x: x0, y: y0, w: x1 - x0, h: y1 - y0 });
    }
  }
  pieces.forEach((pc, k) => {
    // Another piece's spikes reaching into this one's box stay out.
    const alpha = i => own[i] >= 0 && blobs[own[i]].piece !== k ? 0 : a[i];
    // The ring: the longest clear or black-filled run down the piece's middle with solid art above and below it.
    const cx = pc.x + (pc.w >> 1), clear = [];
    for (let y = pc.y; y < pc.y + pc.h; y++) {
      let s = 0, dark = 0;
      for (let t = -2; t <= 2; t++) {
        const i = y * W + cx + t;
        s += alpha(i);
        if (Math.max(p[4 * i], p[4 * i + 1], p[4 * i + 2]) < 14) dark++;
      }
      clear.push(s / 5 < 64 || dark >= 3);
    }
    let best = null;
    for (let y = 0; y < clear.length; y++) {
      if (!clear[y]) continue;
      let e = y;
      while (e + 1 < clear.length && clear[e + 1]) e++;
      if (y > 0 && e < clear.length - 1 && (!best || e - y > best[1] - best[0])) best = [y, e];
      y = e;
    }
    pc.ring = best ? [pc.w >> 1, (best[0] + best[1] + 1) / 2, (best[1] - best[0] + 1) / 2] : [pc.w >> 1, pc.h / 2, 0];
    // seat: the mean gap between its outline and a line laid over it, and under it, in its heights (0 = flat).
    const lo = new Int32Array(pc.w).fill(-1), hi = new Int32Array(pc.w).fill(-1);
    for (let x = 0; x < pc.w; x++) for (let y = 0; y < pc.h; y++)
      if (alpha((pc.y + y) * W + pc.x + x) >= 128) { if (lo[x] < 0) lo[x] = y; hi[x] = y; }
    const used = [...lo.keys()].filter(x => lo[x] >= 0);
    const top = Math.min(...used.map(x => lo[x])), foot = Math.max(...used.map(x => hi[x])), tall = foot - top;
    const mean = f => used.reduce((s, x) => s + f(x), 0) / used.length / tall;
    pc.box = [top, foot + 1];
    pc.mid = (lo[pc.w >> 1] + hi[pc.w >> 1] + 1) / 2;
    pc.seat = [mean(x => lo[x] - top), mean(x => foot - hi[x])].map(v => +v.toFixed(3));
    const out = document.createElement("canvas");
    out.width = pc.w; out.height = pc.h;
    const oc = out.getContext("2d"), im = oc.createImageData(pc.w, pc.h), q = im.data;
    for (let y = 0; y < pc.h; y++) for (let x = 0; x < pc.w; x++) {
      const i = (pc.y + y) * W + pc.x + x, o = (y * pc.w + x) * 4, al = alpha(i);
      q[o + 3] = al;
      // Partly clear pixels lose the ground mixed into them; a white well's, taken off its white already.
      for (let c = 0; c < 3; c++)
        q[o + c] = al === 255 || al === 0 || taken[i] ? p[4 * i + c] : under(i, c) + (p[4 * i + c] - under(i, c)) * 255 / al;
    }
    oc.putImageData(im, 0, 0);
    pc.png = out.toDataURL("image/png");
  });
  // A ring filled with an emblem shows no hole: the sheet's usual ring, on the art down the piece's middle.
  const radii = pieces.map(pc => pc.ring[2]).sort((x, y) => x - y), usual = radii[radii.length >> 1];
  for (const pc of pieces) {
    if (pc.ring[2] < usual / 2) pc.ring = [pc.w >> 1, pc.mid, usual];
    delete pc.mid;
  }
  document.getElementById("export").textContent = JSON.stringify({ W, H, bg, pieces });
};
img.src = SHEET;
</script>"""


def cut(sheet):
    work = Path(tempfile.mkdtemp(prefix="kali-cut-"))
    try:
        page = work / "cut.html"
        page.write_text(PAGE.replace("SHEET", json.dumps(sheet.as_uri()), 1)
                        .replace("COLUMNS", str(COLUMNS.get(sheet.stem, 2)), 1)
                        .replace("ONWHITE", json.dumps(sheet.stem in ON_WHITE), 1)
                        .replace("@TOLERANCE@", json.dumps(TOLERANCE.get(sheet.stem, (8, 34))), 1)
                        .replace("@NUMBERS@", json.dumps(NUMBERS.get(sheet.stem, [])), 1)
                        .replace("@WELLS@", json.dumps(sheet.stem in WHITE_WELLS), 1)
                        .replace("@OPEN@", str(OPENED.get(sheet.stem, 0)), 1)
                        .replace("@SHADE@", json.dumps(sheet.stem in SHADED), 1)
                        .replace("@VIGNETTE@", json.dumps(sheet.stem in VIGNETTED), 1)
                        .replace("@KEY@", json.dumps(sheet.stem in KEYED), 1), encoding="utf-8")
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={work / 'profile'}",
             "--allow-file-access-from-files", "--virtual-time-budget=60000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, encoding="utf-8", timeout=300)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    found = re.search(r'<pre id="export">(.+?)</pre>', result.stdout, re.S)
    if not found:
        raise SystemExit(f"{sheet.name}: the page drew nothing.\n{result.stderr[-2000:]}")
    return json.loads(found.group(1))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Only the sheets named, if any (new ones: seconds, not all of them again); the others' entries kept as they were.
    only = set(sys.argv[1:])
    sheets = sorted(SHEETS.glob("gemini-*.jpeg"))
    if only - {s.stem for s in sheets}:
        raise SystemExit(f"no such sheet: {', '.join(sorted(only - {s.stem for s in sheets}))}")
    data = {}
    if only and JS_OUT.exists():
        text = JS_OUT.read_text(encoding="utf-8")
        data = json.loads(text[text.index("{"):text.rindex("}") + 1])
    for sheet in sheets:
        if only and sheet.stem not in only:
            continue
        got = cut(sheet)
        for old in OUT.glob(f"{sheet.stem}-*.png"):
            old.unlink()
        pieces = []
        for n, pc in enumerate(got["pieces"], 1):
            dest = OUT / f"{sheet.stem}-{n}.png"
            dest.write_bytes(base64.b64decode(pc["png"].split(",", 1)[1]))
            pieces.append({"src": f"art/gen/{dest.name}", "w": pc["w"], "h": pc["h"], "ring": pc["ring"], "box": pc["box"],
                           "seat": pc["seat"]})
        data[sheet.stem] = pieces
        data = {s.stem: data[s.stem] for s in sheets if s.stem in data}
        print(f"{sheet.name}: {got['W']}x{got['H']}, ground {got['bg']}, {len(pieces)} pieces"
              + ("" if len(pieces) == PIECES.get(sheet.stem, 10) else f"  <- expected {PIECES.get(sheet.stem, 10)}"))
    JS_OUT.write_text("// Generated by hud/tools/cut_art.py. Don't edit.\nwindow.GEN_ART = "
                      + json.dumps(data, indent=1) + ";\n", encoding="utf-8", newline="\n")
    print(f"written {JS_OUT}")


if __name__ == "__main__":
    main()
