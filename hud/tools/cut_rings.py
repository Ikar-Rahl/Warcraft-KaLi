"""Ikar's generated minimap rings (hud/art/minimap/rings-*.jpeg: a grid of rings, each with its name under it, on a grey
ground; or one ring alone on a coloured ground, which its edges are then cleared of) cut into keyed PNGs for
hud/bench/minimap.html: hud/bench/art/rings/<sheet>-<n>.png, and hud/bench/js/rings-data.js with each ring's name, its
centre, the inner radius where the map goes and the outer one. A ring painted a little oval is squeezed round. Blizzard's own ring (hud/bench/art/atlas/UI-HUD-Minimap-Frame.png, already keyed) is measured the
same way, for comparison.

Headless Edge decodes, keys and measures the sheets, so no imaging library is needed. Run with:
python -I hud/tools/cut_rings.py [sheet ...]   (only the sheets named, e.g. rings-6: seconds; none named, all of them)
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
SHEETS = HUD / "art/minimap"
BLIZZARD = HUD / "bench/art/atlas/UI-HUD-Minimap-Frame.png"
OUT = HUD / "bench/art/rings"
JS_OUT = HUD / "bench/js/rings-data.js"
sys.stdout.reconfigure(encoding="utf-8")

# Each sheet: its grid and the names written under its rings, row by row (Ikar's downloads of 2026-11-16, in order).
GRIDS = {
    "rings-1": (3, 3, ["Elven", "Gothic", "Cyber", "Steampunk", "Frost", "Volcanic", "Runic", "Royal", "Void"]),
    "rings-2": (3, 3, ["Elven", "Gothic", "Cyber", "Frost", "Volcanic", "Steampunk", "Runic", "Crystal", "Silver"]),
    "rings-3": (3, 3, ["Steampunk 1", "Steampunk 2", "Steampunk 3", "Steampunk 4", "Crystal 1", "Crystal 2",
                       "Crystal 3", "Crystal 4", "Crystal 5"]),
    "rings-4": (5, 1, ["Star 1", "Star 2", "Star 3", "Star 4", "Star 5"]),
    # one ring alone, no name under it, on a blue ground (Ikar 2026-11-18: "Added a new minimap art. That shoudl
    # replace fire.")
    "rings-5": (1, 1, ["Volcanic 2"]),
    # one ring alone on a ground as dark as its rock (Ikar 2026-11-18: "downlaoded another one, laya, add it as a new
    # minimap")
    "rings-6": (1, 1, ["Lava"]),
    # one ring alone on white (Ikar 2026-11-20: "I have a new steampunk minimap art that will replace the 2 currently
    # in the plugin", then "you didn't update the steampunk minimap")
    "rings-7": (1, 1, ["Steampunk"]),
}
# Sheets on a coloured ground, which tints the art's edges (a blue rim round rings-5's): there the ground taken out.
TINTED = {"rings-5"}
# Sheets whose ring is as dark as its ground, cut by its circle rather than by colour.
CIRCLE = {"rings-6"}
# Rings painted inside their band, a nebula or constellations (Ikar 2026-11-16: "the partial opacity of star 2, 3 and
# 5"): keyed there as a glow, see-through, rather than as a solid.
GLOW = {"rings-4": [2, 3, 5]}
# Sheets whose rings stand off their cell's middle: each cell taken this much wider each side (Star 1 runs 25 texels
# into Star 2's fifth of the sheet), what of a neighbour's ring that brings in cleared.
SPILL = {"rings-4": 40}

PAGE = r"""<!doctype html><meta charset="utf-8"><pre id="export"></pre><script>
const SHEETS = DATA;
// LO..HI: distance from the cell's ground (largest channel difference) over which a pixel turns from clear to solid.
// HOLE: a flat ground-coloured patch at least this big inside a ring is its hole.
const LO = 8, HI = 34, HOLE = 400, SOLID = 128;
const load = u => new Promise(done => { const img = new Image(); img.onload = () => done(img); img.src = u; });
const median = v => { const s = Float64Array.from(v).sort(); return s.length ? s[s.length >> 1] : NaN; };

// One cell keyed: its alpha, the ground being what reaches the cell's edge or a big flat hole.
function key(p, W, x0, y0, w, h) {
  const at = (x, y) => 4 * ((y0 + y) * W + x0 + x), border = [[], [], []];
  for (let x = 0; x < w; x++) for (const y of [0, h - 1]) for (let k = 0; k < 3; k++) border[k].push(p[at(x, y) + k]);
  for (let y = 0; y < h; y++) for (const x of [0, w - 1]) for (let k = 0; k < 3; k++) border[k].push(p[at(x, y) + k]);
  const bg = border.map(median), n = w * h, d = new Uint8Array(n);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = at(x, y);
    d[y * w + x] = Math.max(Math.abs(p[i] - bg[0]), Math.abs(p[i + 1] - bg[1]), Math.abs(p[i + 2] - bg[2]));
  }
  const comp = new Int32Array(n).fill(-1), ground = [], stack = new Int32Array(n);
  for (let s = 0; s < n; s++) {
    if (d[s] >= HI || comp[s] >= 0) continue;
    const id = ground.length;
    let top = 0, count = 0, sum = 0, rim = false;
    stack[top++] = s; comp[s] = id;
    const push = j => { if (comp[j] < 0 && d[j] < HI) { comp[j] = id; stack[top++] = j; } };
    while (top) {
      const i = stack[--top], x = i % w, y = (i - x) / w;
      count++; sum += d[i];
      if (x === 0 || y === 0 || x === w - 1 || y === h - 1) rim = true;
      if (x > 0) push(i - 1);
      if (x < w - 1) push(i + 1);
      if (y > 0) push(i - w);
      if (y < h - 1) push(i + w);
    }
    ground.push(rim || (count >= HOLE && sum / count < LO));
  }
  const a = new Uint8Array(n);
  for (let i = 0; i < n; i++)
    a[i] = comp[i] < 0 || !ground[comp[i]] ? 255 : Math.round(255 * Math.min(1, Math.max(0, (d[i] - LO) / (HI - LO))));
  a.bg = bg;
  return a;
}

// Inside a painted ring's band (glow), the ground taken out of each texel: the least alpha that, over the ground,
// gives the texel back ("colour to alpha"), under a floor its noise doesn't pass; what stands out from the ground by
// HARD_LO..HARD_HI (its lines and stars) solid all the same. The band's inner edge: where that solid starts, going out
// from the centre (the median of 360 rays), a hair inside it all blended to the band as keyed.
const HARD_LO = 40, HARD_HI = 90, FLOOR = 0.05, EASE = 6;
function glow(p, W, ox, oy, b, bg) {
  const B = bg.map(v => v / 255), n = b.w * b.h, at = (x, y) => 4 * ((oy + y) * W + ox + x);
  const dist = (x, y) => { const i = at(x, y); return Math.max(...[0, 1, 2].map(k => Math.abs(p[i + k] - bg[k]))); };
  const edge = [];
  for (let k = 0; k < 360; k++) {
    const t = k * Math.PI / 180;
    for (let r = 0; r < b.m.rout; r += 0.5) {
      const x = Math.round(b.m.cx + r * Math.cos(t)), y = Math.round(b.m.cy + r * Math.sin(t));
      if (x >= 0 && y >= 0 && x < b.w && y < b.h && dist(x, y) >= HARD_HI) { edge.push(r); break; }
    }
  }
  const band = median(edge), rgb = new Uint8ClampedArray(3 * n);
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
    const j = y * b.w + x, i = at(x, y), C = [p[i] / 255, p[i + 1] / 255, p[i + 2] / 255];
    const t = Math.min(1, Math.max(0, (Math.hypot(x - b.m.cx, y - b.m.cy) - (band - EASE)) / EASE));
    let raw = 0;
    for (let k = 0; k < 3; k++)
      raw = Math.max(raw, C[k] > B[k] ? (C[k] - B[k]) / (1 - B[k]) : (B[k] - C[k]) / B[k]);
    const soft = Math.min(1, Math.max(0, (raw - FLOOR) / (1 - FLOOR)));
    const hard = Math.min(1, Math.max(0, (dist(x, y) - HARD_LO) / (HARD_HI - HARD_LO)));
    const aNew = Math.max(soft, hard), aOld = b.a[j] / 255, alpha = aOld * t + aNew * (1 - t);
    for (let k = 0; k < 3; k++) {
      const un = aNew > 0.004 ? B[k] + (C[k] - B[k]) / aNew : C[k];
      rgb[3 * j + k] = Math.round(255 * (C[k] * t + Math.min(1, Math.max(0, un)) * (1 - t)));
    }
    b.a[j] = Math.round(255 * alpha);
  }
  b.rgb = rgb;
  b.band = band;
  // its map's edge: where the band is solid round most of the way, not where a line painted inside is first met
  for (let r = 0; r < b.m.rout; r += 0.5) {
    let solid = 0;
    for (let k = 0; k < 360; k++) {
      const t = k * Math.PI / 180, x = Math.round(b.m.cx + r * Math.cos(t)), y = Math.round(b.m.cy + r * Math.sin(t));
      if (x >= 0 && y >= 0 && x < b.w && y < b.h && b.a[y * b.w + x] >= SOLID) solid++;
    }
    if (solid >= 180) { b.rin = r; break; }
  }
}

// On a coloured ground (TINTED), the texels of the art's edges mix the ground in, a rim of it the key keeps solid (a
// texel 40 off the ground by its largest channel, still more ground than art): each texel within RIM of the ground
// takes the colour of the art just inside it (the nearest texel deeper than RIM), and the share of that colour it holds
// over the ground for its alpha, never more than the key's. The art's own colours, deeper in, as painted.
const RIM = 5, REACH = RIM + 3;
function untint(p, W, ox, oy, b, bg) {
  const n = b.w * b.h, depth = new Uint8Array(n).fill(255), queue = new Int32Array(n);
  let head = 0, tail = 0;
  for (let j = 0; j < n; j++) if (b.a[j] === 0) { depth[j] = 0; queue[tail++] = j; }
  while (head < tail) {
    const j = queue[head++], x = j % b.w, y = (j - x) / b.w;
    if (depth[j] >= RIM + 1) continue;
    for (const [X, Y] of [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]) {
      const k = Y * b.w + X;
      if (X >= 0 && Y >= 0 && X < b.w && Y < b.h && depth[k] === 255) { depth[k] = depth[j] + 1; queue[tail++] = k; }
    }
  }
  const at = (x, y) => 4 * ((oy + y) * W + ox + x), rgb = new Uint8ClampedArray(3 * n);
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
    const j = y * b.w + x, i = at(x, y);
    for (let k = 0; k < 3; k++) rgb[3 * j + k] = p[i + k];
    if (depth[j] === 0 || depth[j] > RIM) continue;
    // the art inside: the nearest texel deeper than the rim, else the deepest near (a spike's thin tip)
    let best = -1, bestD = Infinity, deep = -1;
    for (let dy = -REACH; dy <= REACH; dy++) for (let dx = -REACH; dx <= REACH; dx++) {
      const X = x + dx, Y = y + dy, k = Y * b.w + X;
      if (X < 0 || Y < 0 || X >= b.w || Y >= b.h || depth[k] === 0) continue;
      const d2 = dx * dx + dy * dy;
      if (depth[k] > RIM && d2 < bestD) { best = k; bestD = d2; }
      if (deep < 0 || depth[k] > depth[deep]) deep = k;
    }
    const f = at(best >= 0 ? best % b.w : deep % b.w, best >= 0 ? (best - best % b.w) / b.w : (deep - deep % b.w) / b.w);
    const F = [p[f], p[f + 1], p[f + 2]], FB = F.map((v, k) => v - bg[k]), CB = [0, 1, 2].map(k => p[i + k] - bg[k]);
    const len = FB[0] * FB[0] + FB[1] * FB[1] + FB[2] * FB[2];
    if (len < 40 * 40) continue;
    const share = Math.min(1, Math.max(0, (CB[0] * FB[0] + CB[1] * FB[1] + CB[2] * FB[2]) / len));
    b.a[j] = Math.min(b.a[j], Math.round(255 * share));
    for (let k = 0; k < 3; k++) rgb[3 * j + k] = F[k];
  }
  b.rgb = rgb;
}

// A ring on a ground as dark as its stone (CIRCLE: the lava ring's rock lies 4 to 8 off its ground, a colour key would
// see through it): cut by its shape instead. Its two dark outlines, what stands EDGE off the ground, met along rays and
// fitted as circles (measure, below), the band between them kept whole, the soft shadow outside them left out.
const EDGE = 15;
function circleKey(p, W, x0, y0, w, h) {
  const at = (x, y) => 4 * ((y0 + y) * W + x0 + x), border = [[], [], []];
  for (let x = 0; x < w; x++) for (const y of [0, h - 1]) for (let k = 0; k < 3; k++) border[k].push(p[at(x, y) + k]);
  for (let y = 0; y < h; y++) for (const x of [0, w - 1]) for (let k = 0; k < 3; k++) border[k].push(p[at(x, y) + k]);
  const bg = border.map(median), strong = new Uint8Array(w * h), a = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = at(x, y);
    const d = Math.max(Math.abs(p[i] - bg[0]), Math.abs(p[i + 1] - bg[1]), Math.abs(p[i + 2] - bg[2]));
    strong[y * w + x] = d >= EDGE ? 255 : 0;
  }
  const m = measure(strong, w, h, w / 2, h / 2), clamp = v => Math.min(1, Math.max(0, v));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const r = Math.hypot(x - m.cx, y - m.cy);
    a[y * w + x] = Math.round(255 * clamp(m.rout + 0.5 - r) * clamp(r - m.rin + 0.5));
  }
  a.bg = bg;
  return a;
}

// The ring's rows: the tallest run of rows with art in them (its name is a shorter run under it).
function ringRows(a, w, h) {
  const has = y => { let c = 0; for (let x = 0; x < w; x++) if (a[y * w + x] >= 96 && ++c >= 2) return true; return false; };
  const runs = [];
  let start = -1, last = -99;
  for (let y = 0; y < h; y++) if (has(y)) {
    if (y - last > 10) { if (start >= 0) runs.push([start, last]); start = y; }
    last = y;
  }
  if (start >= 0) runs.push([start, last]);
  return runs.reduce((b, r) => (r[1] - r[0] > b[1] - b[0] ? r : b));
}

// Centre and radii: the outer edge met coming in along 360 rays, fitted with a circle (ornaments, out of line with
// the rest, dropped); the inner one, the first solid met going out from that centre, by its median. A ring whose
// inside isn't clear (painted) has its map's edge put at 0.88 of its outer radius.
function measure(a, w, h, cx, cy) {
  const solid = (x, y) => { x = Math.round(x); y = Math.round(y); return x >= 0 && y >= 0 && x < w && y < h && a[y * w + x] >= SOLID; };
  const far = Math.hypot(w, h) / 2 + 2;
  let pts = [];
  for (let k = 0; k < 360; k++) {
    const t = k * Math.PI / 180, ux = Math.cos(t), uy = Math.sin(t);
    for (let r = far; r > 0; r -= 0.5) if (solid(cx + ux * r, cy + uy * r)) { pts.push([cx + ux * r, cy + uy * r]); break; }
  }
  let R = 0;
  for (let pass = 0; pass < 4; pass++) {
    // Kasa: x² + y² + Dx + Ey + F = 0, least squares
    let sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0, sz = 0, sxz = 0, syz = 0;
    for (const [x, y] of pts) {
      const z = x * x + y * y;
      sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y; sz += z; sxz += x * z; syz += y * z;
    }
    const n = pts.length, M = [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]], v = [-sxz, -syz, -sz];
    const det = m => m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                     + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
    const D0 = det(M), col = (j) => M.map((row, i) => row.map((c, k) => (k === j ? v[i] : c)));
    const Dx = det(col(0)) / D0, Ey = det(col(1)) / D0, F = det(col(2)) / D0;
    cx = -Dx / 2; cy = -Ey / 2; R = Math.sqrt(cx * cx + cy * cy - F);
    const res = pts.map(([x, y]) => Math.hypot(x - cx, y - cy) - R), mad = median(res.map(Math.abs)) || 1;
    pts = pts.filter((_, i) => Math.abs(res[i]) <= 2.5 * mad + 0.5);
  }
  const inner = [];
  for (let k = 0; k < 360; k++) {
    const t = k * Math.PI / 180, ux = Math.cos(t), uy = Math.sin(t);
    for (let r = 0; r < R; r += 0.5) if (solid(cx + ux * r, cy + uy * r)) { inner.push(r); break; }
  }
  let rin = median(inner);
  const painted = !(rin > 0.55 * R);
  if (painted) rin = 0.88 * R;
  return { cx, cy, rin, rout: R, painted };
}

// Gauss-Jordan on an augmented matrix: its solution.
function solve(M) {
  const n = M.length;
  for (let i = 0; i < n; i++) {
    let p = i;
    for (let r = i + 1; r < n; r++) if (Math.abs(M[r][i]) > Math.abs(M[p][i])) p = r;
    [M[i], M[p]] = [M[p], M[i]];
    for (let r = 0; r < n; r++) if (r !== i) {
      const f = M[r][i] / M[i][i];
      for (let k = i; k <= n; k++) M[r][k] -= f * M[i][k];
    }
  }
  return M.map((row, i) => row[n] / row[i]);
}

// An ellipse along the sheet's axes through edges' points ([x, y, edge]), q (x - cx)² + (y - cy)² = R², its centre and
// stretch shared, each edge its own R. What isn't the band only ever pushes its outer edge (0) out (ornaments, a shadow
// cast) and its inner edge (1) in (a key hung in the hole, gears inside): each edge's points that far off on that side
// dropped, pass after pass, so the fit hugs its clean envelope. stretch: how much wider than tall.
function ellipse(pts) {
  const sign = [1, -1], edges = [...new Set(pts.map(p => p[2]))], n = 3 + edges.length;
  let q = 1, cx = 0, cy = 0;
  for (let pass = 0; pass < 12; pass++) {
    // q x² + D x + E y + F_edge = -y², least squares
    const M = Array.from({ length: n }, () => new Float64Array(n + 1));
    for (const [x, y, g] of pts) {
      const row = [x * x, x, y, ...edges.map(e => (e === g ? 1 : 0))];
      for (let i = 0; i < n; i++) {
        for (let j = 0; j < n; j++) M[i][j] += row[i] * row[j];
        M[i][n] -= row[i] * y * y;
      }
    }
    const s = solve(M), R = [];
    q = s[0]; cx = -s[1] / (2 * q); cy = -s[2] / 2;
    edges.forEach((e, k) => { R[e] = Math.sqrt(q * cx * cx + cy * cy - s[3 + k]); });
    const res = pts.map(([x, y, g]) => (Math.sqrt(q * (x - cx) ** 2 + (y - cy) ** 2) - R[g]) * sign[g]);
    const mad = [0, 1].map(g => median(res.filter((_, i) => pts[i][2] === g).map(Math.abs)) || 1);
    const kept = pts.filter((p, i) => res[i] <= Math.max(1, mad[p[2]]) && res[i] >= -(3 * mad[p[2]] + 1));
    if (kept.length === pts.length) break;
    pts = kept;
  }
  return { cx, cy, stretch: 1 / Math.sqrt(q) };
}

// The ring's circle as painted, which isn't always round (Ikar 2026-11-16: "not all are perfectly round ... the full
// art is not a circle, doesn't have to be, but there is a circle"; the crystals and gears 2 to 5 % wider than tall):
// its band's outer edge and its inner one met along 720 rays from the circle measured (an outer edge a neighbour's
// clearing made, `cut`, left out), each fitted alone and both together. outer, inner: each one's stretch alone.
function oval(a, cut, w, h, m) {
  const at = (x, y) => { x = Math.round(x); y = Math.round(y); return x >= 0 && y >= 0 && x < w && y < h ? y * w + x : -1; };
  const solid = (x, y) => { const i = at(x, y); return i >= 0 && a[i] >= SOLID; };
  const far = Math.hypot(w, h) / 2 + 2, pts = [];
  for (let k = 0; k < 720; k++) {
    const t = k * Math.PI / 360, ux = Math.cos(t), uy = Math.sin(t);
    for (let r = far; r > 0; r -= 0.5) if (solid(m.cx + ux * r, m.cy + uy * r)) {
      let clipped = false;
      for (let d = 0.5; d <= 4; d += 0.5) { const i = at(m.cx + ux * (r + d), m.cy + uy * (r + d)); if (i >= 0 && cut[i]) clipped = true; }
      if (!clipped) pts.push([m.cx + ux * r, m.cy + uy * r, 0]);
      break;
    }
    for (let r = 0; r < m.rout; r += 0.5)
      if (solid(m.cx + ux * r, m.cy + uy * r)) { pts.push([m.cx + ux * r, m.cy + uy * r, 1]); break; }
  }
  return Object.assign(ellipse(pts), { outer: ellipse(pts.filter(p => p[2] === 0)).stretch,
                                       inner: ellipse(pts.filter(p => p[2] === 1)).stretch });
}

// The cut-out (`piece`, the ring `b` measured `m`) drawn round: squeezed along its long axis till its ellipse is a
// circle, then measured again. Kept as it is: one round to within 0.2 % (Blizzard's among them); one whose two edges
// don't agree on its shape to within 2 % (the stars: their shadow, cast below, lies in the hole at the top and outside
// at the bottom, and alpha alone can't tell it from the band); one whose inside is painted (a glow's too), its outer
// edge alone no measure of its circle.
const ROUND = 0.002, AGREE = 0.02;
function squeeze(piece, b, m) {
  const o = m.painted || m.band ? { stretch: 1, outer: 1, inner: 1 } : oval(b.a, b.cut, b.w, b.h, m);
  const kept = { canvas: piece, m, stretch: 1, measured: o };
  if (Math.abs(o.stretch - 1) < ROUND || Math.abs(o.outer / o.inner - 1) > AGREE) return kept;
  const sx = Math.min(1, 1 / o.stretch), sy = Math.min(1, o.stretch);
  const w = Math.ceil(b.w * sx), h = Math.ceil(b.h * sy), cv = document.createElement("canvas");
  cv.width = w; cv.height = h;
  const c = cv.getContext("2d");
  c.imageSmoothingQuality = "high";
  c.drawImage(piece, 0, 0, b.w * sx, b.h * sy);
  const d = c.getImageData(0, 0, w, h).data, a = new Uint8Array(w * h);
  for (let i = 0; i < w * h; i++) a[i] = d[4 * i + 3];
  // a texel's middle at its index: x maps to (x + 0.5) sx - 0.5
  return { canvas: cv, m: measure(a, w, h, (o.cx + 0.5) * sx - 0.5, (o.cy + 0.5) * sy - 0.5), stretch: o.stretch,
           measured: o };
}

(async () => {
  const out = [];
  for (const sh of SHEETS) {
    const img = await load(sh.url), W = img.naturalWidth, H = img.naturalHeight;
    const cv = document.createElement("canvas");
    cv.width = W; cv.height = H;
    const c = cv.getContext("2d");
    c.drawImage(img, 0, 0);
    const p = c.getImageData(0, 0, W, H).data;
    // First each ring cut out and fitted, the name under it cleared; then what a neighbour's ring reaches into its cell
    // cleared, now that the neighbours are fitted too.
    const cells = [];
    for (let r = 0; r < sh.rows; r++) for (let q = 0; q < sh.cols; q++) {
      const n = r * sh.cols + q, x0 = Math.max(0, Math.floor(q * W / sh.cols) - sh.spill), y0 = Math.floor(r * H / sh.rows);
      const w = Math.min(W, Math.floor((q + 1) * W / sh.cols) + sh.spill) - x0, h = Math.floor((r + 1) * H / sh.rows) - y0;
      // cut: what of the cell a neighbour's clearing took (below), so its edge there isn't read as the ring's
      let a;
      const cut = new Uint8Array(w * h);
      if (sh.keyed) {
        a = new Uint8Array(w * h);
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) a[y * w + x] = p[4 * ((y0 + y) * W + x0 + x) + 3];
      } else a = sh.circle ? circleKey(p, W, x0, y0, w, h) : key(p, W, x0, y0, w, h);
      const [ry0, ry1] = sh.keyed ? [0, h - 1] : ringRows(a, w, h);
      // The ring's box in the cell, its alpha cut out and measured.
      const crop = () => {
        let bx0 = w, bx1 = -1, by0 = h, by1 = -1;
        for (let y = ry0; y <= ry1; y++) for (let x = 0; x < w; x++) if (a[y * w + x] >= 96) {
          bx0 = Math.min(bx0, x); bx1 = Math.max(bx1, x); by0 = Math.min(by0, y); by1 = Math.max(by1, y);
        }
        const M = 14, b = { x0: Math.max(0, bx0 - M), y0: Math.max(0, by0 - M) };
        b.w = Math.min(w - 1, bx1 + M) - b.x0 + 1; b.h = Math.min(h - 1, by1 + M) - b.y0 + 1;
        b.a = new Uint8Array(b.w * b.h);
        b.cut = new Uint8Array(b.w * b.h);
        for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
          b.a[y * b.w + x] = a[(b.y0 + y) * w + b.x0 + x];
          b.cut[y * b.w + x] = cut[(b.y0 + y) * w + b.x0 + x];
        }
        b.m = measure(b.a, b.w, b.h, b.w / 2, b.h / 2);
        return b;
      };
      let b = crop();
      // The name under it, when it sits too close to be a run of its own: strong pieces wholly outside the ring and
      // under it (not just under its centre: Star 2's planet, low on its orbit, is the ring's), cleared with their halo.
      if (!sh.keyed) {
        const n2 = b.w * b.h, seen = new Uint8Array(n2), stack = new Int32Array(n2), gone = [];
        for (let s = 0; s < n2; s++) {
          if (seen[s] || b.a[s] < 200) continue;
          const px = [];
          let top = 0, near = Infinity, minY = Infinity;
          stack[top++] = s; seen[s] = 1;
          while (top) {
            const i = stack[--top], x = i % b.w, y = (i - x) / b.w;
            px.push(i); minY = Math.min(minY, y); near = Math.min(near, Math.hypot(x - b.m.cx, y - b.m.cy));
            for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
              const X = x + dx, Y = y + dy, j = Y * b.w + X;
              if (X >= 0 && Y >= 0 && X < b.w && Y < b.h && !seen[j] && b.a[j] >= 200) { seen[j] = 1; stack[top++] = j; }
            }
          }
          if (near > b.m.rout * 1.02 && minY > b.m.cy + 0.9 * b.m.rout) gone.push(...px);
        }
        const HALO = 8;
        for (const i of gone) {
          const x = i % b.w, y = (i - x) / b.w;
          for (let dy = -HALO; dy <= HALO; dy++) for (let dx = -HALO; dx <= HALO; dx++) {
            const X = b.x0 + x + dx, Y = b.y0 + y + dy;
            if (X >= 0 && Y >= 0 && X < w && Y < h && Math.hypot(X - b.x0 - b.m.cx, Y - b.y0 - b.m.cy) > b.m.rout)
              a[Y * w + X] = 0;
          }
        }
        if (gone.length) b = crop();
      }
      cells.push({ n, q, r, x0, y0, w, h, a, cut, crop, b,
                   at: { x: x0 + b.x0 + b.m.cx, y: y0 + b.y0 + b.m.cy, R: b.m.rout } });
    }
    // A neighbour's ring in the cell: within its outer edge and a margin for its shadow (NEIGHBOUR: the cells are
    // close in Ikar's star sheet, Star 2's band 15 texels from Star 1's), and nearer its outer edge than the ring's own.
    // Off the ring's own band alone, its own rim and shadow on that side went with the neighbour (Star 1's, 15 texels
    // over a fifth of its right side; Ikar 2026-11-16: "it seems not all are perfectly round").
    const NEIGHBOUR = 12;
    for (const cell of cells) {
      if (sh.keyed) break;
      let cleared = false;
      for (const o of cells) {
        if (o === cell || o.r !== cell.r || Math.abs(o.q - cell.q) !== 1) continue;
        for (let y = 0; y < cell.h; y++) for (let x = 0; x < cell.w; x++) {
          const X = cell.x0 + x, Y = cell.y0 + y, i = y * cell.w + x;
          const toOther = Math.hypot(X - o.at.x, Y - o.at.y) - o.at.R;
          if (cell.a[i] && toOther <= NEIGHBOUR && toOther < Math.hypot(X - cell.at.x, Y - cell.at.y) - cell.at.R) {
            cell.a[i] = 0; cell.cut[i] = 1; cleared = true;
          }
        }
      }
      if (cleared) cell.b = cell.crop();
    }
    for (const { n, x0, y0, a, b } of cells) {
      if (sh.glow.includes(n + 1)) {
        glow(p, W, x0 + b.x0, y0 + b.y0, b, a.bg);
        b.m = Object.assign(measure(b.a, b.w, b.h, b.m.cx, b.m.cy), { band: b.band, rin: b.rin });
      } else if (sh.tinted) {
        untint(p, W, x0 + b.x0, y0 + b.y0, b, a.bg);
        b.m = measure(b.a, b.w, b.h, b.m.cx, b.m.cy);
      }
      const cw = b.w, ch = b.h, cx0 = b.x0, cy0 = b.y0;
      const piece = document.createElement("canvas");
      piece.width = cw; piece.height = ch;
      const pc = piece.getContext("2d"), im = pc.createImageData(cw, ch);
      for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
        const s = 4 * ((y0 + cy0 + y) * W + x0 + cx0 + x), t = 4 * (y * cw + x);
        for (let k = 0; k < 3; k++) im.data[t + k] = b.rgb ? b.rgb[3 * (y * cw + x) + k] : p[s + k];
        im.data[t + 3] = b.a[y * cw + x];
      }
      pc.putImageData(im, 0, 0);
      const { canvas, m, stretch, measured } = squeeze(piece, b, b.m);
      out.push({ sheet: sh.id, n: n + 1, name: sh.names[n], w: canvas.width, h: canvas.height,
                 png: canvas.toDataURL("image/png"), cx: +m.cx.toFixed(1), cy: +m.cy.toFixed(1),
                 rin: +m.rin.toFixed(1), rout: +m.rout.toFixed(1), painted: m.painted, band: m.band && +m.band.toFixed(1),
                 stretch: +stretch.toFixed(4),
                 measured: [measured.stretch, measured.outer, measured.inner].map(v => +v.toFixed(4)) });
    }
  }
  document.getElementById("export").textContent = JSON.stringify(out);
})();
</script>"""


def render(sheets):
    work = Path(tempfile.mkdtemp(prefix="kali-rings-"))
    try:
        page = work / "render.html"
        page.write_text(PAGE.replace("DATA", json.dumps(sheets), 1), encoding="utf-8")
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={work / 'profile'}",
             "--allow-file-access-from-files", "--virtual-time-budget=120000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, encoding="utf-8", timeout=600)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    found = re.search(r'<pre id="export">(.+?)</pre>', result.stdout, re.S)
    if not found:
        raise SystemExit(f"the page drew nothing\n{result.stderr[-2000:]}")
    return json.loads(found.group(1))


def main():
    sheets = [{"id": "blizzard", "url": BLIZZARD.as_uri(), "cols": 1, "rows": 1, "names": ["Blizzard"], "keyed": True,
               "glow": [], "spill": 0, "tinted": False, "circle": False}]
    for ident, (cols, rows, names) in GRIDS.items():
        path = SHEETS / f"{ident}.jpeg"
        if path.exists():
            sheets.append({"id": ident, "url": path.as_uri(), "cols": cols, "rows": rows, "names": names, "keyed": False,
                           "glow": GLOW.get(ident, []), "spill": SPILL.get(ident, 0), "tinted": ident in TINTED,
                           "circle": ident in CIRCLE})
        else:
            print(f"missing: {path}")
    # Only the sheets named, if any (a new one: seconds, not all of them again); the others' rows kept as they were.
    only = set(sys.argv[1:])
    order = [s["id"] for s in sheets]
    if only - set(order):
        raise SystemExit(f"no such sheet: {', '.join(sorted(only - set(order)))} (sheets: {', '.join(order)})")
    OUT.mkdir(parents=True, exist_ok=True)
    rings = []
    # a page a sheet: one for all of them, its export grown with the two big rings of 2026-11-18, no longer came back
    # from headless Edge within ten minutes, where each sheet alone takes seconds; written once all are back
    found = [r for sheet in sheets if not only or sheet["id"] in only for r in render([sheet])]
    for ring in found:
        name = f"{ring['sheet']}-{ring['n']}.png"
        (OUT / name).write_bytes(base64.b64decode(ring.pop("png").split(",", 1)[1]))
        rings.append({"id": f"{ring['sheet']}-{ring['n']}", "file": f"art/rings/{name}", **ring})
    done = list(rings)
    if only and JS_OUT.exists():
        text = JS_OUT.read_text(encoding="utf-8")
        rings += [r for r in json.loads(text[text.index("["):text.rindex("]") + 1]) if r["sheet"] not in only]
        rings.sort(key=lambda r: (order.index(r["sheet"]) if r["sheet"] in order else len(order), r["n"]))
    JS_OUT.write_text("// Generated by hud/tools/cut_rings.py: Ikar's minimap rings, keyed (art/rings), and where each one's\n"
                      "// map goes: centre (cx, cy) and inner radius (rin) in its PNG's pixels; rout, its outer radius;\n"
                      "// painted, its inside not clear (rin then guessed); stretch, how much wider than tall it was\n"
                      "// painted, its PNG squeezed round.\n"
                      "const RINGS = " + json.dumps(rings, ensure_ascii=False, indent=1) + ";\n",
                      encoding="utf-8", newline="\n")
    for r in done:
        both, outer, inner = r.pop("measured")
        print(f"{r['id']:12} {r['name']:12} {r['w']}x{r['h']} rin {r['rin']} rout {r['rout']} squeezed {r['stretch']}"
              f" (measured {both}, outer edge {outer}, inner {inner})"
              f"{' painted' if r['painted'] else ''}{' glow, band from ' + str(r['band']) if r.get('band') else ''}")


if __name__ == "__main__":
    main()
