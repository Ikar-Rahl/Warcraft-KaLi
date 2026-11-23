"use strict";
// KaLi HUD borders bench: the KaLi border in ten looks (js/looks.js), each drawn as the addon draws it, along the
// plate's computed outline (Ikar's layout, hud/tools/bench_plate.py), round the minimap and on our frames. Pick one and
// tune it; hud/tools/make_media.py ships one look as Media/BorderKaLi.tga, drawn as procFrame draws it here.
// Art: hud/tools/bench_art.py; screenshots: hud/tools/shot.py <dir> name="look=fer&zoom=3&p.width=6&only=detail".
(async () => {
  const ART = window.HUD_ART, PLATE = window.HUD_PLATE, LOOKS = window.KALI_LOOKS;
  if (!ART || !PLATE || !LOOKS) {
    document.body.textContent = "Run hud/tools/bench_art.py and hud/tools/bench_plate.py first.";
    return;
  }

  const WORLDS = ["cave", "snow-day", "snow-dusk", "snow-night", "troll-camp", "flat"];
  const WORLD_DIR = "../../quest/bench/art/world/";
  const KEY = "kalihud-bench-metal";
  // UI/Border.lua's BACKGROUNDS
  const BACKGROUNDS = [
    ["gradient", "Dégradé"], ["flat", "Uni"], ["dialog", "Dialogue", "UI-DialogBox-Background-Dark"],
    ["marble", "Marbre", "UI-Background-Marble"], ["rock", "Roche", "UI-Background-Rock"],
  ];
  const PROFILES = [["flat", "Plat"], ["round", "Arrondi"], ["bevel", "Biseauté"], ["groove", "Creusé"], ["double", "Double filet"], ["facet", "Facettes"]];
  // Drawn into the texture; in game the border's size scales them all.
  const SHAPE = [
    ["width", "Épaisseur du métal", 0.5, 12, 0.25],
    ["profile", "Profil", PROFILES],
    ["polish", "Poli (brossé → miroir)", 0, 100, 5],
    ["lines", "Traits sombres", 0, 2, 0.1],
    ["shadow", "Ombre", 0, 8, 0.5],
  ];
  // Edit Mode's own.
  const GAME = [
    ["color", "Couleur", "color"],
    ["alpha", "Opacité", 0, 100, 5],
    ["bgTex", "Fond", BACKGROUNDS],
    ["bg", "Couleur du fond", "color"],
    ["bgAlpha", "Opacité du fond", 0, 100, 5],
  ];
  // The cards: around the minimap's left side, about the game's size on a 1440-pixel-high screen.
  const d = PLATE.dome;
  const CARD = { x0: d.cx - d.r - 290, x1: d.cx + 80, top: d.cy + d.r + 8, k: 1.2 };

  const lookOf = (id) => LOOKS.find((l) => l.id === id) || LOOKS[0];
  let stored = {};
  try { stored = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) { stored = {}; }
  const S = { world: stored.world || "snow-dusk", zoom: stored.zoom || "3", look: lookOf(stored.look).id };
  S.P = Object.assign({}, lookOf(S.look), stored.P && stored.P.id === S.look ? stored.P : {});
  const hash = new URLSearchParams(location.hash.slice(1));
  if (hash.has("only") && document.getElementById(hash.get("only"))) {
    document.body.classList.add("only");
    document.getElementById(hash.get("only")).classList.add("solo");
  }
  if (hash.has("world")) S.world = hash.get("world");
  if (hash.has("zoom")) S.zoom = hash.get("zoom");
  if (hash.has("look")) {
    S.look = lookOf(hash.get("look")).id;
    S.P = Object.assign({}, lookOf(S.look));
  }
  for (const [k, v] of hash) {
    const key = k.slice(2);
    if (k.startsWith("p.") && key in S.P) {
      const def = S.P[key];
      S.P[key] = typeof def === "number" ? +v : typeof def === "boolean" ? v === "1" : v;
    }
  }
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { /* file:// may refuse */ } };

  // ---------- images ----------
  const IM = {};
  const srcs = [...Object.values(ART.atlas), ...Object.values(ART.files)].map((a) => a.src);
  await Promise.all(srcs.map((src) => new Promise((done) => {
    const im = new Image();
    im.onload = () => { IM[src] = im; done(); };
    im.onerror = () => done();
    im.src = src;
  })));
  try { await document.fonts.load("12px Friz"); } catch (e) { /* the fallback font will do */ }
  const atlas = (name) => ART.atlas[name] && IM[ART.atlas[name].src];

  const mk = (w, h) => {
    const c = document.createElement("canvas");
    c.width = Math.max(1, Math.ceil(w));
    c.height = Math.max(1, Math.ceil(h));
    return c;
  };
  const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const css = (c, k = 1, a = 1) => `rgba(${c.map((v) => Math.round(Math.min(1, v * k) * 255)).join(",")},${a})`;

  // src's region into (x, y, w, h), a copy every tw x th (0: stretched), the last one cut as a wrapped texture is
  function tile(ctx, src, sx, sy, sw, sh, x, y, w, h, tw, th) {
    if (!src || w <= 0.001 || h <= 0.001) return;
    tw = tw || w;
    th = th || h;
    for (let yy = 0; yy < h - 0.001; yy += th) {
      const dh = Math.min(th, h - yy);
      for (let xx = 0; xx < w - 0.001; xx += tw) {
        const dw = Math.min(tw, w - xx);
        ctx.drawImage(src, sx, sy, sw * dw / tw, sh * dh / th, x + xx, y + yy, dw, dh);
      }
    }
  }

  // the game's vertex colour: the art multiplied by the colour, its alpha kept
  function tinted(src, color) {
    const c = mk(src.width, src.height), x = c.getContext("2d");
    x.drawImage(src, 0, 0);
    x.globalCompositeOperation = "multiply";
    x.fillStyle = color;
    x.fillRect(0, 0, c.width, c.height);
    x.globalCompositeOperation = "destination-in";
    x.drawImage(src, 0, 0);
    return c;
  }

  // ---------- the texture: make_media.py's border_frame and border_strip ----------
  const CELL = 32, CREST = 0.35, FACET_CREST = 0.55;
  const norm = (x, y, z) => { const l = Math.hypot(x, y, z); return [x / l, y / l, z / l]; };
  // the light's side on the screen: the top left
  const SKY = [-0.55 / Math.hypot(0.55, 0.75), -0.75 / Math.hypot(0.55, 0.75)];
  const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  const lookEdge = (P) => 2 * P.shadow + 2 * P.lines + P.width;
  const slopeOf = (profile, x) => profile === "flat" ? 0.08 * Math.cos(Math.PI * x)
    : profile === "round" ? 1.4 * Math.cos(Math.PI * x)
      : profile === "bevel" ? (x < 0.3 ? 1.6 : x > 0.7 ? -1.6 : 0)
        : profile === "groove" ? -1.4 * Math.cos(Math.PI * x)
          : profile === "double" ? 1.4 * Math.cos(Math.PI * ((2 * x) % 1))
            : profile === "facet" ? (x < 0.5 ? 1 : -1) : 0;
  // the metal's brightness where it reflects the eye towards the light (h 1), back at it (0) or away (-1): brushed,
  // soft and even; polished, a mirror of a bright sky over a dark horizon and a dim floor
  const reflect = (h, polish) => {
    const mirror = h >= 0.2 ? 0.45 + 0.55 * smooth(0.2, 0.65, h)
      : h >= 0 ? 0.2 + 0.25 * smooth(0, 0.2, h) : 0.2 + 0.18 * smooth(-0.45, -0.85, h);
    return (0.55 + 0.35 * h) * (1 - polish) + mirror * polish;
  };
  const ridgeSlope = (profile, u, crest = profile === "facet" ? FACET_CREST : CREST) => profile === "double"
    ? slopeOf(profile, u)
    : u < crest ? slopeOf(profile, u * 0.5 / crest) * 0.5 / crest
      : slopeOf(profile, 0.5 + (u - crest) * 0.5 / (1 - crest)) * 0.5 / (1 - crest);

  // a 3 x 3 cell square frame, a cell 28 px for the look's depth
  function procFrame(P) {
    const c = CELL * 7 / 8, q = c / lookEdge(P), N = 3 * c, half = N / 2, SS = 4;
    const s = P.shadow * q, l = P.lines * q, w = P.width * q, hh = half - s;
    const rr = Math.min(2 * l + w + 0.5 * q, c - s), polish = P.polish / 100, profile = P.profile;
    // the metal's arrises round off over 0.6 units, between 15 and 35 % of it
    const m = Math.min(0.35, Math.max(0.15, 0.6 / P.width));
    const sdf = (px, py) => {
      const qx = Math.abs(px - half) - (hh - rr), qy = Math.abs(py - half) - (hh - rr);
      return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - rr;
    };
    const metal = (px, py, u) => {
      if (profile === "double" && Math.abs(u - 0.5) < 0.06) return 0.1;
      const e = 0.25, gx = -(sdf(px + e, py) - sdf(px - e, py)), gy = -(sdf(px, py + e) - sdf(px, py - e));
      const gl = Math.hypot(gx, gy) || 1;
      let k = ridgeSlope(profile, u);
      if (u < m) k = Math.max(k, 1.2);
      else if (u > 1 - m) k = Math.min(k, -1.2);
      // the normal leans outwards by k (g points inwards)
      const n = norm(-k * gx / gl, -k * gy / gl, 1);
      return reflect(2 * n[2] * (n[0] * SKY[0] + n[1] * SKY[1]), polish);
    };
    const shadeAt = (px, py) => {
      const dd = -sdf(px, py);
      if (dd < 0) {
        if (s <= 0 || -dd >= s) return null;
        const t = 1 + dd / s;
        return [0, 0, 0, 0.6 * t * t];
      }
      if (dd < l) return [0.07, 0.07, 0.07, 1];
      if (dd < l + w) {
        const v = metal(px, py, (dd - l) / w);
        return [v, v, v, 1];
      }
      if (dd < 2 * l + w) return [0.12, 0.12, 0.12, 0.95];
      if (s > 0 && dd < 2 * l + w + s) {
        const t = 1 - (dd - 2 * l - w) / s;
        return [0, 0, 0, 0.55 * t * t];
      }
      return null;
    };
    const cv = mk(N, N), ctx = cv.getContext("2d"), img = ctx.createImageData(N, N), px = img.data;
    for (let j = 0; j < N; j++) {
      for (let i = 0; i < N; i++) {
        let R = 0, G = 0, B = 0, A = 0;
        for (let b = 0; b < SS; b++) {
          for (let a = 0; a < SS; a++) {
            const got = shadeAt(i + (a + 0.5) / SS, j + (b + 0.5) / SS);
            if (!got) continue;
            R += got[0] * got[3]; G += got[1] * got[3]; B += got[2] * got[3]; A += got[3];
          }
        }
        const o = (j * N + i) * 4;
        if (A > 0) {
          px[o] = Math.min(1, R / A) * 255;
          px[o + 1] = Math.min(1, G / A) * 255;
          px[o + 2] = Math.min(1, B / A) * 255;
          px[o + 3] = A / (SS * SS) * 255;
        }
      }
    }
    ctx.putImageData(img, 0, 0);
    return cv;
  }
  // Backdrop's edge file: cells L R T B TL TR BL BR, T and B stored turned
  function procStrip(frame) {
    const c = frame.width / 3, ins = CELL / 16, strip = mk(8 * CELL, CELL), x = strip.getContext("2d");
    const at = { L: [0, 1], R: [2, 1], T: [1, 0], B: [1, 2], TL: [0, 0], TR: [2, 0], BL: [0, 2], BR: [2, 2] };
    ["L", "R", "T", "B", "TL", "TR", "BL", "BR"].forEach((key, i) => {
      const cell = mk(c, c), cx = cell.getContext("2d");
      if (key === "T" || key === "B") cx.setTransform(0, -1, 1, 0, 0, c);
      cx.drawImage(frame, at[key][0] * c, at[key][1] * c, c, c, 0, 0, c, c);
      x.drawImage(cell, i * CELL, 0, CELL, CELL);
      x.drawImage(cell, i * CELL + ins, ins, CELL - 2 * ins, CELL - 2 * ins);
    });
    return strip;
  }
  // the strip read back as Backdrop reads it, inside its 1/16 insets
  function cellsOf(src) {
    const cw = src.width / 8, ix = cw / 16, iy = src.height / 16, n = cw - 2 * ix, m = src.height - 2 * iy;
    const cell = (i, turned) => {
      const c = turned ? mk(m, n) : mk(n, m), x = c.getContext("2d");
      if (turned) x.setTransform(0, 1, -1, 0, m, 0);
      x.drawImage(src, i * cw + ix, iy, n, m, 0, 0, n, m);
      return c;
    };
    return { L: cell(0), R: cell(1), T: cell(2, true), B: cell(3, true), TL: cell(4), TR: cell(5), BL: cell(6), BR: cell(7) };
  }
  // the top cell's profile across it (row 0 outside), premultiplied running sums for box filtering
  function across(cell) {
    const h = cell.height, data = cell.getContext("2d").getImageData(Math.floor(cell.width / 2), 0, 1, h).data;
    const sum = new Float64Array((h + 1) * 4);
    for (let j = 0; j < h; j++) {
      const a = data[j * 4 + 3] / 255;
      for (let c = 0; c < 3; c++) sum[(j + 1) * 4 + c] = sum[j * 4 + c] + data[j * 4 + c] / 255 * a;
      sum[(j + 1) * 4 + 3] = sum[j * 4 + 3] + a;
    }
    return { h, sum };
  }
  const textures = new Map();
  function look(P) {
    const key = SHAPE.map(([k]) => P[k]).join("|");
    if (!textures.has(key)) {
      const frame = procFrame(P), strip = procStrip(frame), cells = cellsOf(strip);
      textures.set(key, { frame, strip, cells, profile: across(cells.T) });
    }
    const e = lookEdge(P);
    return { P, tex: textures.get(key), e, out: P.shadow, inset: (P.shadow + P.lines + P.width / 2) / e };
  }

  function drawClassic(ctx, cells, x, y, w, h, e) {
    e = Math.min(e, w / 2, h / 2);
    // the sides are the same all along: stretched, they look as the game's repeat does, without the canvas' seams
    const full = (c) => [c, 0, 0, c.width, c.height];
    tile(ctx, ...full(cells.L), x, y + e, e, h - 2 * e);
    tile(ctx, ...full(cells.R), x + w - e, y + e, e, h - 2 * e);
    tile(ctx, ...full(cells.T), x + e, y, w - 2 * e, e);
    tile(ctx, ...full(cells.B), x + e, y + h - e, w - 2 * e, e);
    ctx.drawImage(cells.TL, x, y, e, e);
    ctx.drawImage(cells.TR, x + w - e, y, e, e);
    ctx.drawImage(cells.BL, x, y + h - e, e, e);
    ctx.drawImage(cells.BR, x + w - e, y + h - e, e, e);
  }

  // ---------- the plate: Geometry.Pieces and Geometry.Path's port ----------
  function roundedRect(out, x0, x1, top, a, c, off) {
    const L = x0 - off, R = x1 + off, t = top + off, bot = -off - 2;
    const a2 = a > 0 ? a + off : 0, c2 = c > 0 ? c + off : 0;
    out.push(["rect", L + a2, bot, R - c2, t]);
    if (a2 > 0) out.push(["rect", L, bot, L + a2, t - a2], ["quarter", L + a2, t - a2, a2, "TL"]);
    if (c2 > 0) out.push(["rect", R - c2, bot, R, t - c2], ["quarter", R - c2, t - c2, c2, "TR"]);
  }
  function pieces(segs, dome, off, corner, fillet) {
    const out = [];
    segs.forEach((s, i) => {
      const prev = segs[i - 1], nxt = segs[i + 1], width = s.x1 - s.x0;
      const a = prev && prev.top < s.top && !(s.dome || prev.dome) ? Math.min(corner, (s.top - prev.top) / 2, width / 2) : 0;
      const c = nxt && nxt.top < s.top && !(s.dome || nxt.dome) ? Math.min(corner, (s.top - nxt.top) / 2, width / 2) : 0;
      roundedRect(out, s.x0, s.x1, s.top, a, c, off);
      if (prev && Math.abs(prev.top - s.top) > 0.5) {
        const thisLower = s.top < prev.top, lowerTop = Math.min(s.top, prev.top), wallSeg = thisLower ? prev : s;
        const r = Math.min(fillet, Math.abs(prev.top - s.top) / 2, (thisLower ? width : prev.x1 - prev.x0) / 2) - off;
        const sx = thisLower ? 1 : -1;
        if (r > 0.2) {
          let wallX = s.x0;
          if (dome && (s.dome || prev.dome) && wallSeg.dome && lowerTop > dome.cy) {
            const k = (dome.r + fillet) ** 2 - (lowerTop + fillet - dome.cy) ** 2;
            if (k > 0) wallX = dome.cx - sx * (Math.sqrt(k) - fillet);
          }
          out.push(["fillet", wallX + sx * off, lowerTop + off, r, sx]);
        }
      }
    });
    if (dome) out.push(["disc", dome.cx, dome.cy, dome.r + off]);
    return out;
  }
  function pieceTop(p, x) {
    const [kind] = p;
    if (kind === "rect") return x >= p[1] && x <= p[3] ? p[4] : null;
    if (kind === "fillet") {
      const r = p[3], u = (x - p[1]) * p[4];
      return u >= 0 && u <= r ? p[2] + r - Math.sqrt(Math.max(0, r * r - (r - u) ** 2)) : null;
    }
    const dx = x - p[1], r = p[3];
    let lo = -r, hi = r;
    if (kind === "quarter") { lo = p[4] === "TL" ? -r : 0; hi = p[4] === "TL" ? 0 : r; }
    return dx >= lo && dx <= hi ? p[2] + Math.sqrt(Math.max(0, r * r - dx * dx)) : null;
  }
  function path(ps, W, step = 2) {
    const xs = [0, W];
    const arc = (cx, r, a0, a1) => {
      const n = Math.max(1, Math.ceil(Math.abs(a1 - a0) * r / step));
      for (let i = 0; i <= n; i++) xs.push(cx + r * Math.cos(a0 + (a1 - a0) * i / n));
    };
    for (const p of ps) {
      const r = p[3];
      if (p[0] === "rect") xs.push(p[1], p[3]);
      else if (p[0] === "quarter") arc(p[1], r, p[4] === "TL" ? Math.PI : Math.PI / 2, p[4] === "TL" ? Math.PI / 2 : 0);
      else if (p[0] === "fillet") arc(p[1] + p[4] * r, r, p[4] > 0 ? Math.PI : 0, p[4] > 0 ? 1.5 * Math.PI : -Math.PI / 2);
      else arc(p[1], r, Math.PI, 0);
    }
    const top = (x) => ps.reduce((m, p) => { const t = pieceTop(p, x); return t !== null && t > m ? t : m; }, -Infinity);
    const sorted = [...new Set(xs.filter((x) => x >= 0 && x <= W).map((x) => Math.round(x * 100) / 100))].sort((a, b) => a - b);
    const pts = [];
    const add = (x, y) => {
      const n = pts.length;
      if (n >= 2 && Math.abs(pts[n - 2] - x) < 1e-6 && Math.abs(pts[n - 1] - y) < 1e-6) return;
      if (n >= 4) {
        const [x0, y0, x1, y1] = pts.slice(n - 4);
        const len = Math.hypot(x - x0, y - y0);
        const ahead = (x1 - x0) * (x - x1) + (y1 - y0) * (y - y1) >= 0;
        if (ahead && len > 0 && Math.abs((x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)) / len < 0.01) {
          pts[n - 2] = x; pts[n - 1] = y;
          return;
        }
      }
      pts.push(x, y);
    };
    for (const x of sorted) {
      if (x > 0) add(x, top(x - 1e-3));
      if (x < W) add(x, top(x + 1e-3));
    }
    return pts;
  }
  const outlines = new Map();
  function outlineAt(off) {
    if (!outlines.has(off)) outlines.set(off, path(pieces(PLATE.segs, PLATE.dome, off, PLATE.corner, PLATE.fillet), PLATE.W));
    return outlines.get(off);
  }
  {
    const mine = outlineAt(0);
    const same = mine.length === PLATE.path.length && mine.every((v, i) => Math.abs(v - PLATE.path[i]) < 0.05);
    if (!same) document.getElementById("port-check").textContent = "⚠ le calcul du banc diffère de Geometry.Path : relancer bench_plate.py";
  }

  // ---------- the plate's edge: Geometry.Band's port, the strip drawn along the outline ----------
  function band(pts, e) {
    const segs = [];
    for (let i = 0; i + 3 < pts.length; i += 2) {
      const [x0, y0, x1, y1] = [pts[i], pts[i + 1], pts[i + 2], pts[i + 3]];
      const len = Math.hypot(x1 - x0, y1 - y0);
      if (len > 1e-6) segs.push([x0, y0, x1, y1, (y1 - y0) / len, -(x1 - x0) / len]);
    }
    const n = segs.length, ix = [], iy = [];
    for (let j = 0; j <= n; j++) {
      const a = segs[j - 1], b = segs[j];
      if (a && b) {
        const k = e / Math.max(0.05, 1 + a[4] * b[4] + a[5] * b[5]);
        ix[j] = b[0] + (a[4] + b[4]) * k; iy[j] = b[1] + (a[5] + b[5]) * k;
      } else if (b) {
        ix[j] = b[0] + b[4] * e; iy[j] = b[1] + b[5] * e;
      } else {
        ix[j] = a[2] + a[4] * e; iy[j] = a[3] + a[5] * e;
      }
    }
    const backwards = (i) => { const s = segs[i - 1]; return (ix[i] - ix[i - 1]) * (s[2] - s[0]) + (iy[i] - iy[i - 1]) * (s[3] - s[1]) < -1e-6; };
    for (let pass = 0; pass < 6; pass++) {
      let fixed = false;
      for (let i = 1; i <= n;) {
        if (backwards(i)) {
          let j = i;
          while (j < n && backwards(j + 1)) j++;
          let sx = 0, sy = 0;
          for (let k = i - 1; k <= j; k++) { sx += ix[k]; sy += iy[k]; }
          const m = j - i + 2;
          for (let k = i - 1; k <= j; k++) { ix[k] = sx / m; iy[k] = sy / m; }
          fixed = true;
          i = j + 1;
        } else i++;
      }
      if (!fixed) break;
    }
    return segs.map((s, i) => [s[0], s[1], s[2], s[3], ix[i], iy[i], ix[i + 1], iy[i + 1]]);
  }

  // the plate's edge as the game draws it: each quad two triangles over which the strip's across coordinate is
  // interpolated, each pixel written once (the quads abut), the profile averaged over the pixel as mipmaps would
  function drawBand(img, quads, prof, thick) {
    const W = img.width, H = img.height, px = img.data, s = prof.sum, h = prof.h, fw = 1 / thick;
    const F = (y, ch) => {
      if (y <= 0) return 0;
      if (y >= h) return s[h * 4 + ch];
      const j = Math.floor(y);
      return s[j * 4 + ch] + (y - j) * (s[(j + 1) * 4 + ch] - s[j * 4 + ch]);
    };
    const put = (o, f) => {
      let y0 = (f - fw / 2) * h, y1 = (f + fw / 2) * h;
      if (y1 - y0 < 1) { y0 = f * h - 0.5; y1 = f * h + 0.5; }
      const n = y1 - y0, a = (F(y1, 3) - F(y0, 3)) / n;
      for (let c = 0; c < 3; c++) px[o + c] = a > 0 ? (F(y1, c) - F(y0, c)) / n / a * 255 : 0;
      px[o + 3] = a * 255;
    };
    const tri = (ax, ay, fa, bx, by, fb, cx, cy, fc) => {
      const det = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay);
      if (Math.abs(det) < 1e-9) return;
      const x0 = Math.max(0, Math.floor(Math.min(ax, bx, cx))), x1 = Math.min(W - 1, Math.ceil(Math.max(ax, bx, cx)));
      const y0 = Math.max(0, Math.floor(Math.min(ay, by, cy))), y1 = Math.min(H - 1, Math.ceil(Math.max(ay, by, cy)));
      for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
          const qx = x + 0.5, qy = y + 0.5;
          const la = ((bx - qx) * (cy - qy) - (cx - qx) * (by - qy)) / det;
          const lb = ((cx - qx) * (ay - qy) - (ax - qx) * (cy - qy)) / det;
          if (la < -1e-6 || lb < -1e-6 || la + lb > 1 + 1e-6) continue;
          put((y * W + x) * 4, la * fa + lb * fb + (1 - la - lb) * fc);
        }
      }
    };
    for (const [p0x, p0y, p1x, p1y, m0x, m0y, m1x, m1y] of quads) {
      tri(p0x, p0y, 0, p1x, p1y, 0, m1x, m1y, 1);
      tri(p0x, p0y, 0, m1x, m1y, 1, m0x, m0y, 1);
    }
  }

  // ---------- drawing ----------
  // the background inside pathFn: the gradient from footK to topK of the colour, flat, or a texture tinted
  function fillBackground(ctx, P, pathFn, top, foot, footK, topK, k) {
    const entry = BACKGROUNDS.find((b) => b[0] === P.bgTex) || BACKGROUNDS[0], c = rgb(P.bg), a = P.bgAlpha / 100;
    const file = entry[2] && ART.files[entry[2]], im = file && IM[file.src];
    ctx.save();
    pathFn();
    ctx.clip();
    if (P.bgTex === "gradient") {
      const g = ctx.createLinearGradient(0, foot, 0, top);
      g.addColorStop(0, css(c, footK, a));
      g.addColorStop(1, css(c, topK, a));
      ctx.fillStyle = g;
      ctx.fillRect(0, Math.min(top, foot) - 1, ctx.canvas.width, Math.abs(foot - top) + 2);
    } else if (!im) {
      ctx.fillStyle = css(c, 1, a);
      ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    } else {
      const layer = mk(ctx.canvas.width, ctx.canvas.height);
      tile(layer.getContext("2d"), im, 0, 0, im.width, im.height, 0, 0, layer.width, layer.height, 256 * k, 256 * k);
      ctx.globalAlpha = a;
      ctx.drawImage(tinted(layer, P.bg), 0, 0);
    }
    ctx.restore();
  }
  // the border's layer over ctx, tinted by its colour, at its opacity
  function composite(ctx, layer, P) {
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = P.alpha / 100;
    ctx.drawImage(tinted(layer, P.color), 0, 0);
    ctx.restore();
  }

  function slotContent(ctx, s, X, Y, k) {
    const x = X(s.x), y = Y(s.y + s.h), w = s.w * k, h = s.h * k;
    if (s.kind === "status") return;
    ctx.fillStyle = "rgba(5,4,3,.45)";
    ctx.fillRect(x, y, w, h);
    const icon = atlas("UI-HUD-ActionBar-IconFrame");
    if (s.kind === "bar" && icon) {
      const size = Math.min(h - 4 * k, 36 * k), n = Math.floor((w - 4 * k) / (size + 2 * k));
      for (let i = 0; i < n; i++) {
        const bx = x + 3 * k + i * (size + 2 * k), by = y + (h - size) / 2;
        ctx.fillStyle = `hsl(${(i * 47 + s.x) % 360}, 25%, 22%)`;
        ctx.fillRect(bx + size * 0.1, by + size * 0.1, size * 0.8, size * 0.8);
        ctx.drawImage(icon, bx, by, size, size);
      }
    } else {
      ctx.fillStyle = "rgba(12,10,8,.6)";
      ctx.fillRect(x + 2 * k, y + 2 * k, w - 4 * k, h - 4 * k);
    }
  }
  function minimap(ctx, X, Y, k) {
    if (!d) return;
    const cx = X(d.cx), cy = Y(d.cy);
    const g = ctx.createRadialGradient(cx - d.mapR * k * 0.3, cy - d.mapR * k * 0.3, 0, cx, cy, d.mapR * k);
    g.addColorStop(0, "#5d6b45");
    g.addColorStop(1, "#2e3a24");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, d.mapR * k, 0, Math.PI * 2);
    ctx.fill();
    const ring = atlas("UI-HUD-Minimap-Frame");
    if (ring) {
      const r = (d.ring + 1) * k;
      ctx.drawImage(ring, cx - r, cy - r, 2 * r, 2 * r);
    }
  }
  function text(ctx, str, x, y, size, color, align) {
    ctx.font = `${size}px Friz, "Arial Narrow", Arial, sans-serif`;
    ctx.textAlign = align || "left";
    ctx.textBaseline = "middle";
    ctx.fillStyle = "#000";
    ctx.fillText(str, x + 1, y + 1);
    ctx.fillStyle = color;
    ctx.fillText(str, x, y);
  }
  // a frame of ours as UI/Border.lua draws it (in pixels, k a unit): the metal from the frame's edge, the shadow
  // outside; on a small frame the border shrinks, its metal no deeper than a quarter of the frame, the rest than half;
  // the background from the middle of the metal, the border over what it holds; a status bar sits 2 units in, under it
  function ourFrame(ctx, L, x, y, w, h, k, inner, statusBar) {
    const side = Math.min(w, h) / k, fit = Math.min(1, side / 4 / (L.e - 2 * L.out), side / 2 / (L.e - L.out));
    const edge = L.e * fit, out = L.out * fit, ins = Math.floor(edge * L.inset - out + 0.5) * k;
    fillBackground(ctx, L.P, () => { ctx.beginPath(); ctx.rect(x + ins, y + ins, w - 2 * ins, h - 2 * ins); },
      y + ins, y + h - ins, 0.55, 1.35, k);
    const pad = statusBar ? 2 * k : ins;
    if (inner) inner(x + pad, y + pad, w - 2 * pad, h - 2 * pad);
    const layer = mk(ctx.canvas.width, ctx.canvas.height), o = out * k;
    drawClassic(layer.getContext("2d"), L.tex.cells, x - o, y - o, w + 2 * o, h + 2 * o, Math.max(1, edge) * k);
    composite(ctx, layer, L.P);
  }

  // the plate between x0 and x1 (UI units), from yFoot up to yTop, at k pixels a unit
  function drawPlate(canvas, L, x0, x1, yTop, yFoot, k, extras) {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = (x1 - x0) * k * dpr;
    canvas.height = (yTop - yFoot) * k * dpr;
    canvas.style.width = (x1 - x0) * k + "px";
    canvas.style.height = (yTop - yFoot) * k + "px";
    k *= dpr;
    const ctx = canvas.getContext("2d");
    const X = (x) => (x - x0) * k, Y = (y) => (yTop - y) * k;
    const outline = outlineAt(0);
    fillBackground(ctx, L.P, () => {
      ctx.beginPath();
      ctx.moveTo(X(outline[0]), Y(yFoot - 5));
      for (let i = 0; i < outline.length; i += 2) ctx.lineTo(X(outline[i]), Y(outline[i + 1]));
      ctx.lineTo(X(outline[outline.length - 2]), Y(yFoot - 5));
      ctx.closePath();
    }, Y(Math.max(...outline.filter((_, i) => i % 2))), Y(0), 0.3, 2.25, k);
    for (const s of PLATE.slots) slotContent(ctx, s, X, Y, k);
    minimap(ctx, X, Y, k);
    // the edge, its outer side out by the shadow
    const layer = mk(canvas.width, canvas.height), lx = layer.getContext("2d"), img = lx.createImageData(layer.width, layer.height);
    const quads = band(outlineAt(L.out), L.e).map((q) => [X(q[0]), Y(q[1]), X(q[2]), Y(q[3]), X(q[4]), Y(q[5]), X(q[6]), Y(q[7])]);
    drawBand(img, quads, L.tex.profile, L.e * k);
    lx.putImageData(img, 0, 0);
    composite(ctx, layer, L.P);
    if (extras) extras(ctx, X, Y, k, L);
  }

  // the info bar along the foot, with the plaque under the minimap and the status bars, as the addon has them
  function infoBar(ctx, X, Y, k, L) {
    const T = PLATE.T;
    text(ctx, "Sacs 22/28    1 234 po    Réparations 30 %", X(14), Y(T / 2), 11 * k, "#e0e0e0");
    text(ctx, "118 ips · 54 ms    Volume 80 %", X(PLATE.W - 300), Y(T / 2), 11 * k, "#e0e0e0");
    if (d) {
      const w = (d.ring - 2) * 2, x = X(d.cx - w / 2), y = Y(T - 2);
      ourFrame(ctx, L, x, y, w * k, (T - 4) * k, k, (ix, iy, iw, ih) => {
        text(ctx, "Forêt d'Elwynn", ix + iw / 2 - 20 * k, iy + ih / 2, 11 * k, "#ffd100", "center");
        text(ctx, "21:42", ix + iw / 2 + 48 * k, iy + ih / 2, 11 * k, "#e0e0e0", "center");
      });
    }
    for (const s of PLATE.slots.filter((s) => s.kind === "status")) {
      ourFrame(ctx, L, X(s.x), Y(s.y + s.h), s.w * k, s.h * k, k, (ix, iy, iw, ih) => {
        ctx.fillStyle = s.x < (d ? d.cx : PLATE.W / 2) ? "#8f3fc0" : "#1f8f2a";
        ctx.fillRect(ix, iy, iw * 0.62, ih);
        ctx.fillStyle = "rgba(255,255,255,.18)";
        ctx.fillRect(ix, iy, iw * 0.62, Math.max(1, ih / 3));
        ctx.fillStyle = "rgba(0,0,0,.55)";
        for (let i = 1; i < 20; i++) ctx.fillRect(Math.round(ix + iw * i / 20), iy, 1, ih);
      }, true);
    }
  }

  function drawFrames(canvas, L, k) {
    const W = 760, H = 64, dpr = window.devicePixelRatio || 1;
    canvas.width = W * k * dpr;
    canvas.height = H * k * dpr;
    canvas.style.width = W * k + "px";
    canvas.style.height = H * k + "px";
    k *= dpr;
    const ctx = canvas.getContext("2d");
    ourFrame(ctx, L, 8 * k, 8 * k, 300 * k, 24 * k, k, (x, y, w, h) => {
      text(ctx, "Discussion — 3 messages", x + 8 * k, y + h / 2, 11 * k, "#cc9957");
      text(ctx, "▾", x + w - 10 * k, y + h / 2, 12 * k, "#cc9957", "center");
    });
    ourFrame(ctx, L, 320 * k, 8 * k, 26 * k, 26 * k, k, (x, y, w, h) => text(ctx, "✉", x + w / 2, y + h / 2, 14 * k, "#f2d68a", "center"));
    ourFrame(ctx, L, 354 * k, 9 * k, 28 * k, 24 * k, k, (x, y, w, h) => text(ctx, "13", x + w / 2, y + h / 2 + k, 12 * k, "#fff", "center"));
    ourFrame(ctx, L, 392 * k, 8 * k, 360 * k, 44 * k, k, (x, y, w, h) => {
      text(ctx, "Dégâts infligés", x + 6 * k, y + 9 * k, 11 * k, "#ffd100");
      ctx.fillStyle = "#c79c6e";
      ctx.fillRect(x + 4 * k, y + 18 * k, (w - 8 * k) * 0.8, 14 * k);
      text(ctx, "1. Ikar", x + 8 * k, y + 25 * k, 11 * k, "#fff");
    });
  }

  function showTexture(L) {
    const show = (canvas, src, z) => {
      canvas.width = src.width * z;
      canvas.height = src.height * z;
      const x = canvas.getContext("2d");
      x.imageSmoothingEnabled = false;
      x.drawImage(tinted(src, L.P.color), 0, 0, canvas.width, canvas.height);
    };
    show(document.getElementById("strip"), L.tex.strip, 3);
    show(document.getElementById("frame"), L.tex.frame, 2);
  }

  // ---------- the page ----------
  const cards = LOOKS.map((P, i) => {
    const b = document.createElement("button"), c = document.createElement("canvas");
    const name = document.createElement("b"), note = document.createElement("span");
    b.className = "look";
    name.textContent = `${i + 1}. ${P.name}`;
    note.textContent = P.note;
    b.append(name, c, note);
    b.addEventListener("click", () => {
      S.look = P.id;
      S.P = Object.assign({}, P);
      save();
      syncControls();
      renderAll();
    });
    document.getElementById("looks").appendChild(b);
    return { P, b, c };
  });
  for (const { P, c } of cards) drawPlate(c, look(P), CARD.x0, CARD.x1, CARD.top, 0, CARD.k, infoBar);

  const inputs = {};
  function control(box, [key, label, a, b, step]) {
    const row = document.createElement("label");
    row.append(label);
    let input;
    if (Array.isArray(a)) {
      input = document.createElement("select");
      for (const [v, name] of a) input.add(new Option(name, v));
    } else {
      input = document.createElement("input");
      if (a === "check") input.type = "checkbox";
      else if (a === "color") input.type = "color";
      else Object.assign(input, { type: "range", min: a, max: b, step });
    }
    const out = input.type === "range" ? document.createElement("output") : null;
    row.append(input);
    if (out) row.append(out);
    input.addEventListener("input", () => {
      S.P[key] = input.type === "checkbox" ? input.checked : input.type === "range" ? +input.value : input.value;
      if (out) out.textContent = input.value;
      save();
      renderAll();
    });
    box.appendChild(row);
    inputs[key] = { input, out };
  }
  SHAPE.forEach((spec) => control(document.getElementById("shape"), spec));
  GAME.forEach((spec) => control(document.getElementById("game"), spec));
  function syncControls() {
    for (const [key, { input, out }] of Object.entries(inputs)) {
      if (input.type === "checkbox") input.checked = S.P[key];
      else input.value = S.P[key];
      if (out) out.textContent = input.value;
    }
  }
  syncControls();
  document.getElementById("reset").addEventListener("click", () => {
    S.P = Object.assign({}, lookOf(S.look));
    save();
    syncControls();
    renderAll();
  });

  let pending = false;
  function renderAll() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(() => {
      pending = false;
      const L = look(S.P), base = lookOf(S.look), z = +S.zoom;
      for (const { P, b } of cards) b.classList.toggle("on", P.id === S.look);
      document.getElementById("look-name").textContent = `${LOOKS.indexOf(base) + 1}. ${base.name}`;
      document.getElementById("look-note").textContent = base.note;
      document.getElementById("look-changed").hidden = Object.keys(base).every((key) => base[key] === S.P[key]);
      document.getElementById("look-json").value = JSON.stringify(S.P);
      const width = document.querySelector("main").clientWidth - 4;
      const span = Math.min(PLATE.W, width / z * 0.98), x0 = Math.max(0, d.cx - span / 2);
      drawPlate(document.getElementById("detail"), L, x0, x0 + span, d.cy + d.r + 14, 0, z, infoBar);
      const outline = outlineAt(0), top = Math.max(...outline.filter((_, i) => i % 2));
      drawPlate(document.getElementById("overview"), L, 0, PLATE.W, top + 20, 0, Math.min(width / PLATE.W, 1), infoBar);
      drawFrames(document.getElementById("frames"), L, Math.min(z, width / 770));
      showTexture(L);
    });
  }

  const world = document.getElementById("world");
  for (const w of WORLDS) world.add(new Option(w, w));
  function applyWorld() {
    document.body.classList.toggle("flat", S.world === "flat");
    document.body.style.backgroundImage = S.world === "flat" ? "" : `url("${WORLD_DIR}${S.world}.jpg")`;
  }
  for (const id of ["world", "zoom"]) {
    const el = document.getElementById(id);
    el.value = S[id];
    el.addEventListener("input", () => {
      S[id] = el.value;
      save();
      if (id === "world") applyWorld(); else renderAll();
    });
  }
  applyWorld();
  renderAll();
})();
