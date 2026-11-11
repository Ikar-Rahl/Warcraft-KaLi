// KaLi Recipe's icon candidates (Ikar, 2026-11-11: "something similar to KaLi Quest in design, so a K followed with
// ... something"). KaLi Quest's icon is « Noir et or »: a black tile, thin gold corners, a gold K in Friz Quadrata and
// the quest mark. Here the same tile, corners and K, drawn with KaLi Quest's own parts, and a sign of recipes in place
// of the quest mark. A 64 by 64 space, as the game's file.
window.KRIcons = (() => {
  const P = KQIcons.parts;
  const GOLD = P.GOLD;
  // The game's own « Composant d'artisanat » blue, 0.4 / 0.733 / 1 (read in game, KaLiRecipeDevDB.reagentColor), at
  // the gradient's heart.
  const BLUE = [[0, "#f2fbff"], [0.3, "#a9dcff"], [0.68, "#66bbff"], [1, "#1a5591"]];
  const EDGE = "#231100";
  // KaLi Quest's K: as tall as its quest mark, 38 high on a 51 baseline, 2 apart. The K and its sign keep within 46
  // across, as K! does (44), clear of the corners.
  const CAP = 38, GAP = 2, ROOM = 46;

  function letter(ctx, ch, cap, x, baseline) {
    ctx.font = '100px "Friz"';
    const css = `${(100 * cap / ctx.measureText(ch).actualBoundingBoxAscent).toFixed(2)}px "Friz"`;
    ctx.font = css;
    const m = ctx.measureText(ch);
    const width = m.actualBoundingBoxLeft + m.actualBoundingBoxRight;
    return { text: ch, font: css, x: x + m.actualBoundingBoxLeft, y: baseline, left: x, right: x + width, top: baseline - cap, bottom: baseline, width };
  }

  function line(ctx, points, width, color) {
    ctx.beginPath();
    ctx.moveTo(points[0][0], points[0][1]);
    points.slice(1).forEach(([x, y]) => ctx.lineTo(x, y));
    ctx.lineWidth = width;
    ctx.strokeStyle = color;
    ctx.stroke();
  }

  const INK_LINE = "rgba(60,28,0,0.6)";

  // Each sign: (x, top, h) gives its shape, h high from top, its ink starting at x, and fine lines drawn over it.

  // A quill, nib down to the left, as the quest log's own: the notebook is written, and its sound is that quill's.
  function quill(x, top, h) {
    const w = h * 0.44;
    const T = [x + w * 0.96, top], N = [x + w * 0.04, top + h];
    const dx = N[0] - T[0], dy = N[1] - T[1], L = Math.hypot(dx, dy);
    const n = [-dy / L, dx / L];
    const at = (t, off) => [T[0] + dx * t + n[0] * off, T[1] + dy * t + n[1] * off];
    const VANE = 0.74, A = h * 0.17, B = h * 0.1, S = h * 0.024;
    const peak = 0.6 / 1.05, most = Math.pow(peak, 0.6) * Math.pow(1 - peak, 0.45);
    const vane = (u) => Math.pow(u, 0.6) * Math.pow(1 - u, 0.45) / most;
    const notch = (u, c, depth) => 1 - depth * Math.max(0, 1 - Math.abs(u - c) / 0.05);
    const sideA = (u) => A * vane(u) * notch(u, 0.5, 0.5) * notch(u, 0.7, 0.45);
    const sideB = (u) => B * vane(u) * notch(u, 0.62, 0.5);
    const STEPS = 48;
    return [{
      path(c) {
        c.moveTo(...at(0, 0));
        for (let i = 1; i <= STEPS; i++) c.lineTo(...at(i / STEPS * VANE, -Math.max(S, sideB(i / STEPS))));
        c.lineTo(...at(0.9, -S));
        c.lineTo(...at(1, 0));
        c.lineTo(...at(0.9, S));
        for (let i = STEPS; i >= 1; i--) c.lineTo(...at(i / STEPS * VANE, Math.max(S, sideA(i / STEPS))));
        c.closePath();
      },
      detail(ctx) {
        line(ctx, [at(0.08, 0), at(0.88, 0)], h * 0.022, INK_LINE);
        line(ctx, [at(0.93, 0), at(0.985, 0)], h * 0.018, INK_LINE);
      },
      left: x, right: x + w, top, bottom: top + h, width: w,
    }];
  }

  // A feather along a curve from its tip T to its nib N. o: bend (how far the curve pulls aside, as a share of its
  // length; positive towards the upper left), vane (where the barbs stop, 0 to 1), a and b (the upper-left and
  // lower-right sides at their widest), notchA and notchB ([where, how deep] cuts between barbs), shaft (the bare quill's
  // half width), nib (where the nib starts to taper).
  function feather(T, N, o) {
    const dx = N[0] - T[0], dy = N[1] - T[1];
    const bend = o.bend || 0;
    const C = [(T[0] + N[0]) / 2 - dy * bend, (T[1] + N[1]) / 2 + dx * bend];
    const pt = (t) => {
      const s = 1 - t;
      return [s * s * T[0] + 2 * s * t * C[0] + t * t * N[0], s * s * T[1] + 2 * s * t * C[1] + t * t * N[1]];
    };
    const nrm = (t) => {
      const s = 1 - t, a = 2 * s * (C[0] - T[0]) + 2 * t * (N[0] - C[0]), b = 2 * s * (C[1] - T[1]) + 2 * t * (N[1] - C[1]);
      const l = Math.hypot(a, b);
      return [-b / l, a / l];
    };
    const at = (t, off) => {
      const p = pt(t), q = nrm(t);
      return [p[0] + q[0] * off, p[1] + q[1] * off];
    };
    const VANE = o.vane ?? 0.74, NIB = o.nib ?? 0.9, S = o.shaft;
    const peak = 0.6 / 1.05, most = Math.pow(peak, 0.6) * Math.pow(1 - peak, 0.45);
    const vane = (u) => Math.pow(u, 0.6) * Math.pow(1 - u, 0.45) / most;
    const cut = (u, list) => (list || []).reduce((k, [c, d]) => k * (1 - d * Math.max(0, 1 - Math.abs(u - c) / 0.05)), 1);
    const sideA = (u) => o.a * vane(u) * cut(u, o.notchA);
    const sideB = (u) => o.b * vane(u) * cut(u, o.notchB);
    const STEPS = 48;
    return {
      at,
      path(c) {
        c.moveTo(...at(0, 0));
        for (let i = 1; i <= STEPS; i++) c.lineTo(...at(i / STEPS * VANE, -Math.max(S, sideB(i / STEPS))));
        c.lineTo(...at(NIB, -S));
        c.lineTo(...at(1, 0));
        c.lineTo(...at(NIB, S));
        for (let i = STEPS; i >= 1; i--) c.lineTo(...at(i / STEPS * VANE, Math.max(S, sideA(i / STEPS))));
        c.closePath();
      },
      // The quill's spine along the vane, and the nib's slit.
      lines(ctx, h, slit = true) {
        const spine = [];
        for (let t = 0.08; t <= NIB - 0.02; t += 0.02) spine.push(at(t, 0));
        line(ctx, spine, h * 0.022, INK_LINE);
        if (slit) line(ctx, [at(NIB + 0.03, 0), at(0.985, 0)], h * 0.018, INK_LINE);
      },
    };
  }

  const box = (x, top, w, h, more) => Object.assign({ left: x, right: x + w, top, bottom: top + h, width: w }, more);

  // The quest mark's own shape: the quill is its bar, a drop of ink its dot.
  function quillDrop(x, top, h) {
    const w = h * 0.42, r = h * 0.1, cx = x + w * 0.3, cy = top + h - r;
    const f = feather([x + w * 0.97, top], [cx, top + h * 0.655],
      { a: h * 0.15, b: h * 0.09, shaft: h * 0.024, notchA: [[0.5, 0.5], [0.7, 0.45]], notchB: [[0.62, 0.5]] });
    return [
      box(x, top, w, h, { path: f.path, detail: (ctx) => f.lines(ctx, h) }),
      box(x, top, w, h, {
        path(c) {
          c.moveTo(cx, cy - 2 * r);
          c.bezierCurveTo(cx + r * 0.25, cy - 1.45 * r, cx + r, cy - 0.95 * r, cx + r, cy);
          c.arc(cx, cy, r, 0, Math.PI);
          c.bezierCurveTo(cx - r, cy - 0.95 * r, cx - r * 0.25, cy - 1.45 * r, cx, cy - 2 * r);
          c.closePath();
        },
      }),
    ];
  }

  // A broad feather on a curve, more barbs cut: a real goose quill.
  function quillCurved(x, top, h) {
    const w = h * 0.5;
    const f = feather([x + w * 0.98, top], [x + w * 0.05, top + h], {
      bend: -0.09, vane: 0.8, a: h * 0.19, b: h * 0.12, shaft: h * 0.026,
      notchA: [[0.34, 0.4], [0.54, 0.55], [0.72, 0.45]], notchB: [[0.48, 0.45], [0.68, 0.4]],
    });
    return [box(x, top, w, h, { path: f.path, detail: (ctx) => f.lines(ctx, h) })];
  }

  // Cut from straight lines, one side shaded: crisp at 16 px, as « K! taillé » was for KaLi Quest.
  function quillCut(x, top, h) {
    const w = h * 0.42, A = h * 0.17, B = h * 0.11, S = h * 0.026;
    const f = feather([x + w * 0.96, top], [x + w * 0.04, top + h], { a: 0, b: 0, shaft: S });
    const at = f.at;
    const shaded = [at(0, 0), at(0.4, -B), at(0.6, -B * 0.8), at(0.74, -S), at(0.74, 0)];
    return [box(x, top, w, h, {
      path: (c) => P.polygon(c, [at(0, 0), at(0.4, -B), at(0.6, -B * 0.8), at(0.74, -S), at(0.9, -S), at(1, 0), at(0.9, S),
        at(0.74, S), at(0.67, A * 0.7), at(0.61, A * 0.3), at(0.57, A * 0.95), at(0.38, A)]),
      detail(ctx) {
        ctx.beginPath();
        P.polygon(ctx, shaded);
        ctx.fillStyle = "rgba(70,30,0,0.3)";
        ctx.fill();
        f.lines(ctx, h);
      },
    })];
  }

  // Standing in its inkwell.
  function quillInk(x, top, h) {
    const w = h * 0.56, bw = h * 0.5, bh = h * 0.25, by = top + h - bh;
    const nw = h * 0.24, ny = by - h * 0.06, lw = h * 0.31, lh = h * 0.055, ly = ny - lh * 0.6;
    const f = feather([x + w * 0.98, top], [x + bw * 0.46, by + bh * 0.4],
      { vane: 0.62, a: h * 0.14, b: h * 0.085, shaft: h * 0.024, notchA: [[0.45, 0.5], [0.6, 0.4]], notchB: [[0.55, 0.45]] });
    const cx = x + bw / 2;
    return [
      box(x, top, w, h, { path: f.path, detail: (ctx) => f.lines(ctx, h, false) }),
      box(x, top, w, h, {
        path(c) {
          c.roundRect(cx - lw / 2, ly, lw, lh, lh / 2);
          c.rect(cx - nw / 2, ny, nw, bh);
          c.roundRect(x, by, bw, bh, h * 0.07);
        },
        detail(ctx) {
          line(ctx, [[cx - lw / 2 + 1, ly + 0.3], [cx + lw / 2 - 1, ly + 0.3]], h * 0.03, INK_LINE);
          line(ctx, [[x + bw * 0.12, by + bh * 0.3], [x + bw * 0.88, by + bh * 0.3]], h * 0.022, "rgba(60,28,0,0.45)");
        },
      }),
    ];
  }

  // Writing: the nib at the end of a stroke of ink.
  function quillWriting(x, top, h) {
    const w = h * 0.6, nx = x + w * 0.16, ny = top + h * 0.74;
    const f = feather([x + w * 0.98, top], [nx, ny],
      { a: h * 0.15, b: h * 0.09, shaft: h * 0.024, notchA: [[0.5, 0.5], [0.7, 0.45]], notchB: [[0.62, 0.5]] });
    const ex = x + w, ey = top + h * 0.9;
    const along = (s) => [nx + (ex - nx) * s, ny + (ey - ny) * s + h * 0.07 * Math.sin(2 * Math.PI * s)];
    const thick = (s) => h * 0.05 * Math.pow(Math.sin(Math.PI * Math.min(1, s * 1.15)), 0.6) + h * 0.008;
    const N = 32;
    return [
      box(x, top, w, h, { path: f.path, detail: (ctx) => f.lines(ctx, h) }),
      box(x, top, w, h, {
        path(c) {
          const up = [], down = [];
          for (let i = 0; i <= N; i++) {
            const [px, py] = along(i / N), t = thick(i / N);
            up.push([px, py - t]);
            down.push([px, py + t]);
          }
          P.polygon(c, [...up, ...down.reverse()]);
        },
      }),
    ];
  }

  // One sign: the quill is the K's arm, its nib in the stem, as « K-! » made the quest mark the K's stem.
  function kQuill(ctx) {
    const cap = 40, baseline = 32 + cap / 2, t = baseline - cap, s = cap * 0.21, w = cap * 0.8;
    const span = w + cap * 0.12, x = 32 - span / 2;
    const k = box(x, t, span, cap, {
      path(c) {
        P.polygon(c, [[x, t], [x + s, t], [x + s, baseline], [x, baseline]]);
        P.polygon(c, [[x + s + cap * 0.04, t + cap * 0.55], [x + s + cap * 0.24, t + cap * 0.4], [x + w + cap * 0.05, baseline],
          [x + w - cap * 0.26, baseline]]);
      },
    });
    const f = feather([x + span, t - cap * 0.02], [x + s - 0.5, t + cap * 0.6],
      { vane: 0.72, a: cap * 0.15, b: cap * 0.09, shaft: cap * 0.03, notchA: [[0.5, 0.5], [0.7, 0.45]], notchB: [[0.62, 0.5]] });
    const q = box(x, t, span, cap, { path: f.path });
    P.emblem(ctx, [k, q], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.lineCap = "round";
    f.lines(ctx, cap, false);
    ctx.restore();
  }

  // ---------- Feathers in other styles (Ikar, 2026-11-11: "other quills, just different feather stylised") ----------

  // An axis from the tip T to the nib N on a cubic curve; at(t, off) is the point off to its side (positive: upper left).
  function axis(T, C1, C2, N) {
    const pt = (t, i) => { const s = 1 - t; return s * s * s * T[i] + 3 * s * s * t * C1[i] + 3 * s * t * t * C2[i] + t * t * t * N[i]; };
    const dt = (t, i) => { const s = 1 - t; return 3 * s * s * (C1[i] - T[i]) + 6 * s * t * (C2[i] - C1[i]) + 3 * t * t * (N[i] - C2[i]); };
    return (t, off) => {
      const a = dt(t, 0), b = dt(t, 1), l = Math.hypot(a, b);
      return [pt(t, 0) - b / l * off, pt(t, 1) + a / l * off];
    };
  }
  // A straight axis, or one pulled aside by bend (a share of its length) at its two thirds: s-shaped when they differ.
  function bent(T, N, bend1 = 0, bend2 = bend1) {
    const dx = N[0] - T[0], dy = N[1] - T[1];
    const third = (k, b) => [T[0] + dx * k - dy * b, T[1] + dy * k + dx * b];
    return axis(T, third(1 / 3, bend1), third(2 / 3, bend2), N);
  }

  const PEAK = 0.6 / 1.05, MOST = Math.pow(PEAK, 0.6) * Math.pow(1 - PEAK, 0.45);
  const POINTED = (u) => Math.pow(u, 0.6) * Math.pow(1 - u, 0.45) / MOST;

  // The feather's outline. o: a, b (each side at its widest), vane, nib, shaft, profile (0 to 1 along the vane),
  // notchA, notchB ([where, depth, width]: a depth of 1 cuts to the quill), sweep (the barbs lean towards the tip, the
  // more the further out), wave (a ripple along the edges).
  function outline(at, o) {
    const V = o.vane ?? 0.74, NIB = o.nib ?? 0.9, S = o.shaft, STEPS = 72;
    const prof = o.profile || POINTED, profA = o.profileA || prof, profB = o.profileB || prof;
    const cut = (u, list) => (list || []).reduce((k, [c, d, wd = 0.05]) => k * (1 - d * Math.max(0, 1 - Math.abs(u - c) / wd)), 1);
    const ripple = (u) => 1 + (o.wave || 0) * Math.sin(u * Math.PI * (o.waves || 6));
    const edge = (u, sign, big, list) => {
      const w = Math.max(S, big * (sign > 0 ? profA : profB)(u) * cut(u, list) * ripple(u));
      return at(Math.max(0, u * V - (o.sweep || 0) * (w / big)), sign * w);
    };
    const pts = [at(0, 0)];
    for (let i = 1; i <= STEPS; i++) pts.push(edge(i / STEPS, -1, o.b, o.notchB));
    pts.push(...(o.nibPoints ? o.nibPoints(at, NIB, S) : [at(NIB, -S), at(1, 0), at(NIB, S)]));
    for (let i = STEPS; i >= 1; i--) pts.push(edge(i / STEPS, 1, o.a, o.notchA));
    return pts;
  }

  const area = (pts) => pts.reduce((s, p, i) => { const q = pts[(i + 1) % pts.length]; return s + p[0] * q[1] - q[0] * p[1]; }, 0);
  const turnedLike = (pts, model) => (Math.sign(area(pts)) === Math.sign(area(model)) ? pts : [...pts].reverse());

  // Made at any size, then fitted: its height to h, its left edge to x. items: each a list of polygons, filled as one;
  // lines: fine ink { pts, w } with w a share of h.
  function fitted(make) {
    const g = make();
    const all = g.items.flat(2).concat((g.lines || []).flatMap((l) => l.pts));
    const minX = Math.min(...all.map((p) => p[0])), maxX = Math.max(...all.map((p) => p[0]));
    const minY = Math.min(...g.items.flat(2).map((p) => p[1])), maxY = Math.max(...g.items.flat(2).map((p) => p[1]));
    return (x, top, h) => {
      const s = h / (maxY - minY), w = (maxX - minX) * s;
      const map = (p) => [x + (p[0] - minX) * s, top + (p[1] - minY) * s];
      return g.items.map((polys, i) => box(x, top, w, h, {
        path: (c) => polys.forEach((p) => P.polygon(c, p.map(map))),
        detail: i === 0 ? (ctx) => {
          (g.shades || []).forEach((sh) => {
            ctx.beginPath();
            P.polygon(ctx, sh.pts.map(map));
            ctx.fillStyle = sh.color;
            ctx.fill();
          });
          (g.lines || []).forEach((l) => line(ctx, l.pts.map(map), h * l.w, l.color || INK_LINE));
        } : undefined,
      }));
    };
  }

  const spine = (at, from, to) => Array.from({ length: 30 }, (_, i) => at(from + (to - from) * i / 29, 0));
  const LEAN = [[0.42, 0], [0.02, 1]];

  // Chevrons: the vane cut right through, both sides together, every barb group leaning to the tip.
  const quillChevrons = fitted(() => {
    const at = bent(...LEAN);
    const cuts = [0.22, 0.34, 0.46, 0.58, 0.7].map((c) => [c, 1, 0.022]);
    return {
      items: [[outline(at, { a: 0.15, b: 0.15, shaft: 0.022, notchA: cuts, notchB: cuts, sweep: 0.13 })]],
      lines: [{ pts: spine(at, 0.06, 0.88), w: 0.02 }, { pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 }],
    };
  });

  // Split: a smooth vane with two deep splits, as feathers part.
  const quillSplit = fitted(() => {
    const at = bent(...LEAN, 0.04);
    return {
      items: [[outline(at, { a: 0.18, b: 0.12, shaft: 0.024, sweep: 0.1,
        notchA: [[0.44, 0.97, 0.035], [0.63, 0.95, 0.035]], notchB: [[0.56, 0.95, 0.035]] })]],
      lines: [{ pts: spine(at, 0.06, 0.88), w: 0.022 }, { pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 }],
    };
  });

  // Round: a short broad feather, its tip rounded.
  const quillRound = fitted(() => {
    const at = bent([0.46, 0], [0.04, 1], -0.05);
    const profile = (u) => (u < 0.3 ? Math.sqrt(1 - (1 - u / 0.3) ** 2) : Math.pow(1 - (u - 0.3) / 0.7, 0.75));
    return {
      items: [[outline(at, { a: 0.2, b: 0.16, shaft: 0.026, vane: 0.7, profile, notchA: [[0.62, 0.55, 0.05]], sweep: 0.06 })]],
      lines: [{ pts: spine(at, 0.1, 0.88), w: 0.022 }, { pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 }],
    };
  });

  // Slender: the long thin quill of a calligrapher, barbs mostly on one side.
  const quillSlender = fitted(() => {
    const at = bent([0.36, 0], [0.02, 1], 0.05);
    return {
      items: [[outline(at, { a: 0.095, b: 0.042, shaft: 0.018, vane: 0.8, nib: 0.92, sweep: 0.05,
        notchA: [[0.55, 0.6, 0.04]], notchB: [[0.68, 0.6, 0.04]] })]],
      lines: [{ pts: spine(at, 0.05, 0.9), w: 0.016 }, { pts: [at(0.94, 0), at(0.99, 0)], w: 0.014 }],
    };
  });

  // Wavy: an s-shaped quill, its edges rippling.
  const quillWavy = fitted(() => {
    const at = bent([0.44, 0], [0.04, 1], 0.13, -0.1);
    return {
      items: [[outline(at, { a: 0.17, b: 0.11, shaft: 0.024, wave: 0.14, waves: 5, sweep: 0.06, notchA: [[0.66, 0.6, 0.04]] })]],
      lines: [{ pts: spine(at, 0.06, 0.88), w: 0.022 }, { pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 }],
    };
  });

  // Line art: the feather drawn as an outline with its quill and a few barbs, hollow inside.
  const quillLines = fitted(() => {
    const at = bent(...LEAN, 0.03);
    const A = 0.18, B = 0.12, TH = 0.034, V = 0.74;
    const outer = outline(at, { a: A, b: B, shaft: 0.024, notchA: [[0.66, 0.55, 0.05]] });
    const inner = [];
    for (let i = 0; i <= 40; i++) {
      const u = 0.07 + 0.88 * i / 40;
      inner.push(at(u * V, -Math.max(0.006, B * POINTED(u) - TH)));
    }
    for (let i = 40; i >= 0; i--) {
      const u = 0.07 + 0.88 * i / 40;
      const notch = 1 - 0.55 * Math.max(0, 1 - Math.abs(u - 0.66) / 0.05);
      inner.push(at(u * V, Math.max(0.006, A * POINTED(u) * notch - TH)));
    }
    const strip = (pts) => turnedLike(pts, outer);
    const quill = strip([at(0.05, -TH * 0.45), at(0.9, -TH * 0.45), at(0.9, TH * 0.45), at(0.05, TH * 0.45)]);
    const barb = (t, side, w) => strip([at(t, 0), at(t - 0.06, side * w), at(t - 0.06 + 0.035, side * w), at(t + 0.035, 0)]);
    return {
      items: [[outer, turnedLike(inner, outer).reverse(), quill,
        barb(0.3, 1, A * 0.82 - TH), barb(0.48, 1, A * 0.86 - TH), barb(0.38, -1, B * 0.8 - TH), barb(0.56, -1, B * 0.75 - TH)]],
      lines: [{ pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 }],
    };
  });

  // ---------- Ikar's two references (2026-11-11) ----------
  // Drawn after the two stock feathers Ikar showed, not traced from them: their style, our geometry.

  // A cut-out line along the quill, from..to, off to one side, pointed at both ends: holes in the shape.
  function slot(at, from, to, off, half) {
    const a = [], b = [];
    for (let i = 0; i <= 32; i++) {
      const t = from + (to - from) * i / 32, w = half * Math.pow(Math.sin(Math.PI * i / 32), 0.4);
      a.push(at(t, off - w));
      b.push(at(t, off + w));
    }
    return [...a, ...b.reverse()];
  }
  const holes = (outer, list) => list.map((h) => turnedLike(h, outer).reverse());

  // Barb groups, tip to base: each starts at its point and runs back along a long edge to the quill, then a narrow gap
  // and the next point. n groups between from and to; outside them, the plain shape.
  function barbs(from, to, n, base = POINTED) {
    const L = (to - from) / n;
    return (u) => {
      if (u < from || u > to) return base(u);
      const f = ((u - from) % L) / L;
      return base(u) * (f < 0.84 ? 1 - 0.8 * f / 0.84 : 0.2 + 0.8 * (f - 0.84) / 0.16);
    };
  }

  // The first: a feather of deep pointed barb groups leaning to the tip, the quill a fine line cut through it, on a thin
  // stalk; hook: its tip curls over to the right, a crescent thick at the top and fine at its end.
  function hookFeather(hook) {
    return fitted(() => {
      const at = bent([0.46, 0], [0, 1], 0.05);
      const outer = outline(at, { a: 0.22, b: 0.17, shaft: 0.016, vane: 0.82, nib: 0.95, sweep: 0.16,
        profileA: barbs(0.16, 0.97, 5), profileB: barbs(0.24, 0.97, 4) });
      const polys = [outer, ...holes(outer, [slot(at, 0.16, 0.82, 0, 0.014)])];
      if (hook) {
        const arcOf = (c, r, from, to) => Array.from({ length: 33 }, (_, i) => {
          const t = (from + (to - from) * i / 32) * Math.PI / 180;
          return [c[0] + r * Math.cos(t), c[1] + r * Math.sin(t)];
        });
        const crescent = [...arcOf([0.55, 0.12], 0.2, 212, 382), ...arcOf([0.58, 0.165], 0.145, 382, 212)];
        polys.push(turnedLike(crescent, outer));
      }
      return { items: [polys] };
    });
  }

  // The second: a long pointed leaf on an s, three fine slits on one side and one on the other, the quill two fine cut
  // lines, a short stem ending in a bead. sharp: a longer, thinner point.
  function leafFeather(sharp) {
    return fitted(() => {
      const at = sharp ? axis([0.68, 0], [0.4, 0.24], [0.28, 0.7], [0.36, 1]) : axis([0.6, 0], [0.38, 0.22], [0.3, 0.7], [0.36, 1]);
      const rise = sharp ? 2.1 : 1.5;
      const profile = (u) => Math.pow(Math.sin(Math.PI * Math.pow(u, rise)), 0.85);
      const outer = outline(at, { a: sharp ? 0.17 : 0.19, b: sharp ? 0.13 : 0.15, shaft: 0.02, vane: 0.9, nib: 0.97, sweep: 0.08,
        profile, notchA: [[0.42, 0.55, 0.012], [0.54, 0.5, 0.012], [0.66, 0.45, 0.012]], notchB: [[0.76, 0.45, 0.014]] });
      const end = at(1, 0), bead = Array.from({ length: 24 }, (_, i) => {
        const t = i / 24 * Math.PI * 2;
        return [end[0] + 0.028 * Math.cos(t), end[1] - 0.012 + 0.028 * Math.sin(t)];
      });
      return { items: [[outer, ...holes(outer, [slot(at, 0.44, 0.95, 0, 0.011), slot(at, 0.6, 0.93, -0.034, 0.007)]),
        turnedLike(bead, outer)]] };
    });
  }

  // ---------- Twelve more feathers (Ikar, 2026-11-11: "F2 still is the better so far. But see other stylization") ----------

  const NIB_SLIT = (at) => ({ pts: [at(0.93, 0), at(0.985, 0)], w: 0.018 });
  // The outline's half on side B, closed along the quill: for a second tone.
  const halfB = (pts, at, steps = 72) => [...pts.slice(0, steps + 3), ...spine(at, 0, 1).reverse()];
  // An ellipse around the quill at t: across, along.
  function oval(at, t, across, along, n = 36) {
    const c = at(t, 0), q = at(t, 1), r = at(Math.min(1, t + 0.001), 0);
    const nx = q[0] - c[0], ny = q[1] - c[1], dl = Math.hypot(r[0] - c[0], r[1] - c[1]);
    const dx = (r[0] - c[0]) / dl, dy = (r[1] - c[1]) / dl;
    return Array.from({ length: n }, (_, i) => {
      const a = i / n * Math.PI * 2;
      return [c[0] + dx * along * Math.cos(a) + nx * across * Math.sin(a), c[1] + dy * along * Math.cos(a) + ny * across * Math.sin(a)];
    });
  }
  // A curling wisp of down from p, heading ang (radians), turning by curl along its length, tapering.
  function wisp(p, ang, len, wid, curl) {
    const up = [], down = [];
    let [x, y] = p;
    for (let i = 0; i <= 14; i++) {
      const s = i / 14, a = ang + curl * s, th = wid * Math.pow(1 - s, 0.8) + 0.002;
      up.push([x - Math.sin(a) * th, y + Math.cos(a) * th]);
      down.push([x + Math.sin(a) * th, y - Math.cos(a) * th]);
      x += Math.cos(a) * len / 14;
      y += Math.sin(a) * len / 14;
    }
    return [...up, ...down.reverse()];
  }
  // Rounded lobes along the edge, from..to, n of them, dipping to low between.
  const lobes = (from, to, n, low, base = POINTED, power = 0.5) => (u) => {
    if (u < from || u > to) return base(u);
    const L = (to - from) / n, f = ((u - from) % L) / L;
    return base(u) * (low + (1 - low) * Math.pow(Math.sin(Math.PI * f), power));
  };
  const F2_LIKE = { shaft: 0.024, sweep: 0.1, notchA: [[0.44, 0.97, 0.035], [0.63, 0.95, 0.035]], notchB: [[0.56, 0.95, 0.035]] };

  // [id, name, note, make]: make gives fitted()'s items, lines and shades.
  const MORE = [
    ["fendue-ample", "Fendue ample", "F2 broader and more curved, three splits on one side and two on the other.", () => {
      const at = bent(...LEAN, 0.08);
      return {
        items: [[outline(at, { a: 0.22, b: 0.15, shaft: 0.024, sweep: 0.12,
          notchA: [[0.36, 0.95, 0.03], [0.52, 0.97, 0.03], [0.68, 0.95, 0.03]], notchB: [[0.46, 0.95, 0.03], [0.64, 0.95, 0.03]] })]],
        lines: [{ pts: spine(at, 0.06, 0.88), w: 0.022 }, NIB_SLIT(at)],
      };
    }],
    ["fendue-nervure", "Fendue, nervure creuse", "F2, its quill a fine line cut through the vane, as in your first feather.", () => {
      const at = bent(...LEAN, 0.04);
      const outer = outline(at, { a: 0.18, b: 0.12, ...F2_LIKE });
      return { items: [[outer, ...holes(outer, [slot(at, 0.1, 0.8, 0, 0.014)])]], lines: [NIB_SLIT(at)] };
    }],
    ["fendue-deux-tons", "Fendue, deux tons", "F2 with one side a darker gold, split along the quill: the classic emblem shading.", () => {
      const at = bent(...LEAN, 0.04);
      const outer = outline(at, { a: 0.18, b: 0.12, ...F2_LIKE });
      return {
        items: [[outer]], shades: [{ pts: halfB(outer, at), color: "rgba(110,45,0,0.42)" }],
        lines: [{ pts: spine(at, 0.06, 0.88), w: 0.016 }, NIB_SLIT(at)],
      };
    }],
    ["remige", "Rémige", "A wing's flight feather: a narrow leading edge, a broad rounded trailing side, one split.", () => {
      const at = bent([0.4, 0], [0.04, 1], 0.07);
      const round = (u) => (u < 0.22 ? Math.sqrt(1 - (1 - u / 0.22) ** 2) : Math.pow(1 - Math.pow((u - 0.22) / 0.78, 2.2), 0.6));
      return {
        items: [[outline(at, { a: 0.24, b: 0.055, shaft: 0.022, vane: 0.8, sweep: 0.08, profileA: round, notchA: [[0.56, 0.85, 0.03]] })]],
        lines: [{ pts: spine(at, 0.04, 0.9), w: 0.02 }, NIB_SLIT(at)],
      };
    }],
    ["calame", "Calame", "The writing quill itself: a short smooth vane, the bare quill, a nib cut to a point with its slit and hole.", () => {
      const at = bent([0.44, 0], [0.02, 1], 0.04);
      const nibPoints = (a, NIB, S) => [a(NIB, -S), a(NIB + 0.06, -S * 0.35), a(1, 0), a(NIB + 0.03, S * 0.95), a(NIB, S)];
      const outer = outline(at, { a: 0.18, b: 0.12, shaft: 0.034, vane: 0.66, nib: 0.84, sweep: 0.08, notchA: [[0.55, 0.9, 0.035]], nibPoints });
      return {
        items: [[outer, ...holes(outer, [oval(at, 0.885, 0.013, 0.016)])]],
        lines: [{ pts: spine(at, 0.06, 0.84), w: 0.02 }, { pts: [at(0.9, 0), at(0.99, 0)], w: 0.014 }],
      };
    }],
    ["goutte", "Goutte", "Broad and round at the base, drawn out to a sharp point, two short splits.", () => {
      const at = bent([0.48, 0], [0.1, 1], 0.05);
      const drop = (u) => (u < 0.72 ? Math.pow(Math.sin(Math.PI / 2 * Math.pow(u / 0.72, 1.6)), 0.9) : Math.sqrt(1 - ((u - 0.72) / 0.28) ** 2));
      return {
        items: [[outline(at, { a: 0.2, b: 0.18, shaft: 0.022, vane: 0.86, nib: 0.95, profile: drop, sweep: 0.07,
          notchA: [[0.5, 0.75, 0.03]], notchB: [[0.62, 0.75, 0.03]] })]],
        lines: [{ pts: spine(at, 0.08, 0.92), w: 0.02 }],
      };
    }],
    ["paon", "Paon", "A peacock's feather: the eye near the tip cut as a ring, a fine fringe below.", () => {
      const at = bent([0.42, 0], [0.04, 1], 0.05);
      const prof = (u) => (u < 0.42 ? Math.pow(Math.sin(Math.PI * u / 0.42), 0.55)
        : 0.38 * Math.pow(Math.max(0, 1 - (u - 0.42) / 0.58), 0.5) * (1 + 0.28 * Math.sin(u * Math.PI * 34)));
      const outer = outline(at, { a: 0.21, b: 0.21, shaft: 0.02, vane: 0.8, profile: prof, sweep: 0.06 });
      const tEye = 0.21 * 0.8;
      return {
        items: [[outer, ...holes(outer, [oval(at, tEye, 0.12, 0.15)]), turnedLike(oval(at, tEye, 0.065, 0.085), outer)]],
        lines: [{ pts: spine(at, 0.36, 0.88), w: 0.02 }, NIB_SLIT(at)],
      };
    }],
    ["panache", "Panache", "A hat's plume: rising, then drooping over to the right, its edges scalloped.", () => {
      const at = axis([0.86, 0.5], [0.78, -0.12], [0.12, -0.02], [0.06, 1]);
      return {
        items: [[outline(at, { a: 0.15, b: 0.12, shaft: 0.022, vane: 0.78, sweep: 0.08,
          profileA: lobes(0.08, 0.98, 8, 0.72), profileB: lobes(0.12, 0.98, 7, 0.72) })]],
        lines: [{ pts: spine(at, 0.06, 0.88), w: 0.02 }, NIB_SLIT(at)],
      };
    }],
    ["gravee", "Gravée", "Engraved: the barbs drawn as fine lines across a smooth feather, as an old print does.", () => {
      const at = bent(...LEAN, 0.05);
      const outer = outline(at, { a: 0.2, b: 0.15, shaft: 0.024, sweep: 0.08, notchA: [[0.58, 0.8, 0.03]] });
      const hatch = [];
      for (let u = 0.1; u <= 0.94; u += 0.05) {
        for (const [side, big] of [[1, 0.2], [-1, 0.15]]) {
          const w = big * POINTED(u) * 0.86;
          if (w > 0.03) hatch.push({ pts: [at(u * 0.74, side * 0.018), at(Math.max(0, u * 0.74 - 0.07), side * w)], w: 0.012 });
        }
      }
      return { items: [[outer]], lines: [{ pts: spine(at, 0.04, 0.88), w: 0.024 }, ...hatch, NIB_SLIT(at)] };
    }],
    ["flamme", "Flamme", "Its barbs as tongues of flame, leaning hard to a flicking tip.", () => {
      const at = bent([0.46, 0], [0.04, 1], 0.12, -0.06);
      return {
        items: [[outline(at, { a: 0.2, b: 0.15, shaft: 0.022, vane: 0.8, sweep: 0.26,
          profileA: lobes(0.14, 0.98, 5, 0.3, POINTED, 0.45), profileB: lobes(0.22, 0.98, 4, 0.3, POINTED, 0.45) })]],
        lines: [{ pts: spine(at, 0.1, 0.88), w: 0.02 }, NIB_SLIT(at)],
      };
    }],
    ["art-deco", "Art déco", "Straight and even, its edges in steps, the quill cut through: an Art Deco ornament.", () => {
      const at = bent([0.36, 0], [0.04, 1]);
      const steps = (u) => POINTED(Math.min(0.999, (Math.floor(u * 7) + 0.5) / 7));
      const outer = outline(at, { a: 0.17, b: 0.17, shaft: 0.022, vane: 0.8, profile: steps });
      return { items: [[outer, ...holes(outer, [slot(at, 0.08, 0.8, 0, 0.014)])]], lines: [NIB_SLIT(at)] };
    }],
    ["duvet", "Duvet", "A smooth vane above, curls of down where it meets the quill.", () => {
      const at = bent(...LEAN, 0.05);
      const outer = outline(at, { a: 0.19, b: 0.14, shaft: 0.024, vane: 0.66, sweep: 0.1, notchA: [[0.56, 0.95, 0.035]] });
      const down = [];
      [[0.62, 1, 0.15, 0.9], [0.69, 1, 0.13, 1.1], [0.76, 1, 0.1, 1.2], [0.64, -1, 0.12, -0.9], [0.72, -1, 0.1, -1.1]].forEach(([t, side, len, curl]) => {
        const c = at(t, 0), q = at(t, side), r = at(t + 0.01, 0);
        const nx = q[0] - c[0], ny = q[1] - c[1], d = Math.hypot(r[0] - c[0], r[1] - c[1]);
        const dx = (r[0] - c[0]) / d, dy = (r[1] - c[1]) / d;
        const ang = Math.atan2(ny * 0.75 + dy * 0.65, nx * 0.75 + dx * 0.65);
        down.push(turnedLike(wisp(c, ang, len, 0.02, curl * 0.9), outer));
      });
      return { items: [[outer, ...down]], lines: [{ pts: spine(at, 0.06, 0.88), w: 0.022 }, NIB_SLIT(at)] };
    }],
  ];

  // ---------- Six angular feathers (Ikar, 2026-11-11: "more angular shapes, like if it was trimmed") ----------
  // Straight edges only: corners as [t along the quill from tip to nib, offset across it, positive to the upper left].
  // Lit from the upper left, as the K: side B in a darker gold.
  const corners = (at, list) => list.map(([t, off]) => at(t, off));
  const DARK = "rgba(110,45,0,0.42)";
  const shadeB = (at, sideB) => ({ pts: [...corners(at, sideB), ...spine(at, 0, 1).reverse()], color: DARK });

  const ANGULAR = [
    ["fendue-taillee", "Fendue taillée", "F2 cut from straight lines, its splits sharp V's, one side in the darker gold.", () => {
      const at = bent(...LEAN, 0.03);
      const B = [[0, 0], [0.1, -0.075], [0.26, -0.118], [0.36, -0.12], [0.46, -0.016], [0.42, -0.104], [0.53, -0.094],
        [0.63, -0.055], [0.72, -0.022], [0.9, -0.022], [1, 0]];
      const A = [[0.9, 0.024], [0.72, 0.024], [0.62, 0.085], [0.47, 0.142], [0.57, 0.018], [0.52, 0.122], [0.32, 0.168],
        [0.42, 0.018], [0.37, 0.148], [0.2, 0.14], [0.08, 0.08]];
      return { items: [[corners(at, [...B, ...A])]], shades: [shadeB(at, B)], lines: [NIB_SLIT(at)] };
    }],
    ["facettes", "Facettes", "Low-poly: straight edges, each facet its own shade of gold, lit from the upper left.", () => {
      const at = bent(...LEAN);
      const B = [[0.12, -0.08], [0.3, -0.13], [0.5, -0.12], [0.66, -0.07], [0.76, -0.024]];
      const A = [[0.08, 0.08], [0.22, 0.15], [0.42, 0.17], [0.62, 0.12], [0.76, 0.03]];
      const shape = [[0, 0], ...B, [0.92, -0.022], [1, 0], [0.92, 0.024], ...[...A].reverse()];
      const shades = [];
      const facets = (list, tones) => {
        let prev = [0, 0];
        list.forEach((p, i) => {
          shades.push({ pts: corners(at, [[prev[0], 0], prev, p]), color: tones[(2 * i) % tones.length] });
          shades.push({ pts: corners(at, [[prev[0], 0], p, [p[0], 0]]), color: tones[(2 * i + 1) % tones.length] });
          prev = p;
        });
      };
      facets(B, ["rgba(110,45,0,0.5)", "rgba(110,45,0,0.28)", "rgba(110,45,0,0.6)", "rgba(110,45,0,0.34)"]);
      facets(A, ["rgba(255,246,214,0.34)", "rgba(110,45,0,0.1)", "rgba(255,246,214,0.14)", "rgba(110,45,0,0.2)"]);
      return { items: [[corners(at, shape)]], shades, lines: [NIB_SLIT(at)] };
    }],
    ["empennage", "Empennage", "Trimmed like an arrow's fletching: the top cut on a slant, a long straight edge, a step at the back.", () => {
      const at = bent([0.38, 0], [0.06, 1]);
      const B = [[0, 0], [0.04, -0.075], [0.58, -0.075], [0.74, -0.022], [0.9, -0.022], [1, 0]];
      const A = [[0.9, 0.024], [0.76, 0.024], [0.7, 0.1], [0.64, 0.12], [0.6, 0.19], [0.1, 0.19]];
      const barbs = [];
      for (let t = 0.2; t <= 0.6; t += 0.1) barbs.push({ pts: [at(t, 0.02), at(t - 0.07, 0.17)], w: 0.012 });
      return { items: [[corners(at, [...B, ...A])]], shades: [shadeB(at, B)],
        lines: [{ pts: spine(at, 0.02, 0.9), w: 0.016 }, ...barbs, NIB_SLIT(at)] };
    }],
    ["losange", "Losange", "A diamond: straight to its widest, a sharp V cut on each side, the quill cut through, two tones.", () => {
      const at = bent([0.36, 0], [0.04, 1]);
      const B = [[0, 0], [0.34, -0.16], [0.46, -0.12], [0.52, -0.03], [0.5, -0.1], [0.76, -0.024], [0.92, -0.022], [1, 0]];
      const A = [[0.92, 0.024], [0.76, 0.024], [0.56, 0.1], [0.58, 0.03], [0.52, 0.12], [0.34, 0.16]];
      const outer = corners(at, [...B, ...A]);
      return { items: [[outer, ...holes(outer, [slot(at, 0.06, 0.74, 0, 0.012)])]], shades: [shadeB(at, B)], lines: [NIB_SLIT(at)] };
    }],
    ["dents", "Dents de scie", "Straight teeth all along both sides, each pointing to the tip, as a cut-paper feather.", () => {
      const at = bent(...LEAN, 0.03);
      const teeth = [[0.02, 0.07], [0.1, 0.04], [0.12, 0.13], [0.22, 0.07], [0.24, 0.17], [0.36, 0.09], [0.38, 0.17], [0.5, 0.09],
        [0.52, 0.14], [0.63, 0.07], [0.65, 0.09], [0.76, 0.024]];
      const B = [[0, 0], ...teeth.map(([t, w]) => [t + 0.05, -w * 0.72]), [0.92, -0.022], [1, 0]];
      const A = [[0.92, 0.024], ...[...teeth].reverse()];
      return { items: [[corners(at, [...B, ...A])]], shades: [shadeB(at, B)],
        lines: [{ pts: spine(at, 0.03, 0.9), w: 0.016 }, NIB_SLIT(at)] };
    }],
    ["rognee", "Rognée", "A writer's quill, trimmed: the vane cut straight and squared off on a slant, the rest stripped, a cut nib.", () => {
      const at = bent([0.4, 0], [0.04, 1]);
      const B = [[0.06, -0.08], [0.5, -0.08], [0.58, -0.032], [0.84, -0.032], [0.9, -0.012], [1, 0]];
      const A = [[0.87, 0.03], [0.84, 0.032], [0.62, 0.032], [0.54, 0.13], [0, 0.13]];
      const outer = corners(at, [...B, ...A]);
      const barbs = [];
      for (let t = 0.12; t <= 0.5; t += 0.08) {
        barbs.push({ pts: [at(t, 0.022), at(t - 0.06, 0.12)], w: 0.012 }, { pts: [at(t + 0.03, -0.022), at(t - 0.01, -0.075)], w: 0.012 });
      }
      return { items: [[outer, ...holes(outer, [oval(at, 0.86, 0.012, 0.014)])]], shades: [shadeB(at, [[0, 0], ...B])],
        lines: [{ pts: spine(at, 0.02, 0.84), w: 0.016 }, ...barbs, { pts: [at(0.88, 0), at(0.99, 0)], w: 0.014 }] };
    }],
  ];

  // ---------- The game's scroll, recoloured (Ikar, 2026-11-11: "not an invented parchemin, a good copy") ----------
  // INV_Scroll_03 itself, the addon's icon today: its own pixels, the dark ground taken out, each shade mapped onto the
  // K's gold, so the drawing, its shading and its three-quarter view are the game's. Blizzard's art: the bench keeps it
  // local; shipping it in the addon's file is Ikar's call.
  const TONES = [[0, [64, 28, 0]], [0.3, [176, 98, 6]], [0.58, [240, 170, 30]], [0.8, [255, 218, 100]], [1, [255, 249, 218]]];
  const FLAT = [0.1, 0.4, 0.68, 0.95];
  let art = null;

  function canvasOf(w, h = w) {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    return c;
  }

  function tone(t) {
    for (let i = 1; i < TONES.length; i++) {
      if (t <= TONES[i][0]) {
        const [t0, c0] = TONES[i - 1], [t1, c1] = TONES[i], k = (t - t0) / (t1 - t0);
        return c0.map((v, j) => Math.round(v + (c1[j] - v) * k));
      }
    }
    return TONES[TONES.length - 1][1];
  }

  // Where the drawing is: its box, from the alpha.
  function bounds(c) {
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
    let x0 = c.width, y0 = c.height, x1 = 0, y1 = 0;
    for (let y = 0; y < c.height; y++) {
      for (let x = 0; x < c.width; x++) {
        if (d[(y * c.width + x) * 4 + 3] > 80) {
          x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1);
        }
      }
    }
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
  }

  // The icon at 4 times its size, smoothed, then recoloured: the dark ground gone (the red seal and ribbon kept, though
  // darker), each shade onto the gold, or onto four flat tones.
  function recolour(img, flat) {
    const UP = 4, N = img.width * UP, CROP = 5 * UP;
    const c = canvasOf(N), g = c.getContext("2d");
    g.imageSmoothingQuality = "high";
    g.drawImage(img, 0, 0, N, N);
    const image = g.getImageData(0, 0, N, N), d = image.data;
    const lum = new Float32Array(N * N), alpha = new Float32Array(N * N);
    const seen = [];
    for (let i = 0; i < N * N; i++) {
      const x = i % N, y = Math.floor(i / N);
      const r = d[i * 4], gr = d[i * 4 + 1], b = d[i * 4 + 2];
      const l = 0.299 * r + 0.587 * gr + 0.114 * b, red = r - Math.max(gr, b);
      const inside = x >= CROP && y >= CROP && x < N - CROP && y < N - CROP;
      const a = inside ? Math.min(1, Math.max(0, Math.max(l - 48, red - 40) / 28)) : 0;
      // Faint pixels are the icon's own vignette, not the scroll.
      alpha[i] = a < 0.2 ? 0 : a;
      lum[i] = l + Math.max(0, red) * 0.35;
      if (alpha[i] > 0.9) seen.push(lum[i]);
    }
    seen.sort((p, q) => p - q);
    // Flat tones from smoothed shades, so the painting's grain doesn't speckle them.
    if (flat) {
      for (let pass = 0; pass < 2; pass++) {
        for (const [dx, dy] of [[1, 0], [0, 1]]) {
          const src = lum.slice();
          for (let y = 0; y < N; y++) {
            for (let x = 0; x < N; x++) {
              let sum = 0, n = 0;
              for (let k = -4; k <= 4; k++) {
                const xx = x + dx * k, yy = y + dy * k;
                if (xx >= 0 && yy >= 0 && xx < N && yy < N) { sum += src[yy * N + xx]; n++; }
              }
              lum[y * N + x] = sum / n;
            }
          }
        }
      }
    }
    const lo = seen[Math.floor(seen.length * 0.02)], hi = seen[Math.floor(seen.length * 0.98)];
    for (let i = 0; i < N * N; i++) {
      let t = Math.min(1, Math.max(0, (lum[i] - lo) / (hi - lo)));
      if (flat) t = FLAT[Math.min(3, Math.floor(t * 4))];
      const [r, gr, b] = tone(t);
      d[i * 4] = r; d[i * 4 + 1] = gr; d[i * 4 + 2] = b; d[i * 4 + 3] = Math.round(alpha[i] * 255);
    }
    g.putImageData(image, 0, 0);
    return c;
  }

  function turned(c, degrees) {
    const a = degrees * Math.PI / 180, size = Math.ceil(c.width * 1.5), out = canvasOf(size), g = out.getContext("2d");
    g.translate(size / 2, size / 2);
    g.rotate(a);
    g.drawImage(c, -c.width / 2, -c.height / 2);
    return out;
  }

  function withBounds(c) {
    return { c, b: bounds(c) };
  }

  async function ready() {
    const src = window.KR_ICON_SOURCES && window.KR_ICON_SOURCES["134939"];
    if (art || !src) return;
    const img = new Image();
    img.src = src;
    await img.decode();
    const gold = recolour(img, false), flat = recolour(img, true);
    art = { gold: withBounds(gold), flat: withBounds(flat), upright: withBounds(turned(gold, -32)) };
  }

  // The drawing in the box (x, y, w, h) of the 64 space, with the K's dark edge around it and its shadow.
  function drawArt(ctx, a, x, y, w, h) {
    const { c, b } = a;
    const edge = canvasOf(c.width, c.height), e = edge.getContext("2d");
    e.drawImage(c, 0, 0);
    e.globalCompositeOperation = "source-in";
    e.fillStyle = EDGE;
    e.fillRect(0, 0, c.width, c.height);
    const k = w / b.w, R = 0.75 / k;
    ctx.save();
    P.shadow(ctx, 2.5, 1.3);
    for (let i = 0; i < 12; i++) {
      const t = i / 12 * Math.PI * 2;
      ctx.drawImage(edge, b.x + Math.cos(t) * R, b.y + Math.sin(t) * R, b.w, b.h, x, y, w, h);
      if (i === 0) P.noShadow(ctx);
    }
    ctx.drawImage(c, b.x, b.y, b.w, b.h, x, y, w, h);
    ctx.restore();
  }

  // The K, then the scroll beside it, as tall as rise times the K, both within ROOM.
  function kArt(ctx, which, rise) {
    if (!art) return;
    const a = art[which], ratio = a.b.w / a.b.h;
    const kr = letter(ctx, "K", 100, 0, 100).width / 100;
    const cap = Math.min(CAP, (ROOM + 2 - GAP) / (kr + ratio * rise));
    const sh = cap * rise, sw = sh * ratio, total = kr * cap + GAP + sw, x = 32 - total / 2, baseline = 32 + cap / 2;
    P.emblem(ctx, [letter(ctx, "K", cap, x, baseline)], { colors: GOLD, edge: EDGE });
    drawArt(ctx, a, x + kr * cap + GAP, baseline - cap / 2 - sh / 2, sw, sh);
  }

  // The scroll as large as the game draws it, the K in the corner it leaves empty.
  function artLarge(ctx) {
    if (!art) return;
    const a = art.gold, w = 46, h = w * a.b.h / a.b.w;
    drawArt(ctx, a, 64 - 7 - w, 64 - 7 - h, w, h);
    P.emblem(ctx, [letter(ctx, "K", 25, 8, 33)], { colors: GOLD, edge: EDGE });
  }

  // A recipe as the game's items show one: a sheet between two rolls.
  function scroll(x, top, h) {
    const w = h * 0.38, roll = h * 0.17;
    return [{
      path(c) {
        c.roundRect(x, top, w, roll, roll / 2);
        c.rect(x + w * 0.12, top + roll * 0.5, w * 0.76, h - roll);
        c.roundRect(x, top + h - roll, w, roll, roll / 2);
      },
      detail(ctx) {
        line(ctx, [[x + w * 0.12, top + roll + 0.6], [x + w * 0.88, top + roll + 0.6]], h * 0.03, INK_LINE);
        line(ctx, [[x + w * 0.12, top + h - roll - 0.6], [x + w * 0.88, top + h - roll - 0.6]], h * 0.03, INK_LINE);
        [[0.37, 0.76], [0.48, 0.66], [0.59, 0.76], [0.7, 0.58]].forEach(([y, end]) =>
          line(ctx, [[x + w * 0.27, top + h * y], [x + w * end, top + h * y]], h * 0.028, "rgba(60,28,0,0.5)"));
        for (const cy of [top + roll / 2, top + h - roll / 2]) {
          ctx.beginPath();
          ctx.arc(x + w - roll / 2, cy, roll * 0.22, 0, Math.PI * 2);
          ctx.lineWidth = h * 0.022;
          ctx.strokeStyle = INK_LINE;
          ctx.stroke();
        }
      },
      left: x, right: x + w, top, bottom: top + h, width: w,
    }];
  }

  // The notebook itself, closed, its ribbon hanging out.
  function notebook(x, top, h) {
    const w = h * 0.5, bh = h * 0.9;
    return [{
      path(c) {
        c.roundRect(x, top, w, bh, h * 0.07);
        P.polygon(c, [[x + w * 0.56, top + bh - 1], [x + w * 0.78, top + bh - 1], [x + w * 0.78, top + h],
          [x + w * 0.67, top + h - h * 0.06], [x + w * 0.56, top + h]]);
      },
      detail(ctx) {
        line(ctx, [[x + w * 0.2, top + 1.2], [x + w * 0.2, top + bh - 1.2]], h * 0.03, INK_LINE);
        ctx.beginPath();
        ctx.roundRect(x + w * 0.34, top + bh * 0.13, w * 0.52, bh * 0.74, 1.2);
        ctx.lineWidth = h * 0.024;
        ctx.strokeStyle = "rgba(60,28,0,0.5)";
        ctx.stroke();
      },
      left: x, right: x + w, top, bottom: top + h, width: w,
    }];
  }

  // A round flask: what alchemy makes, the best-known craft of all, though only one profession's.
  function flask(x, top, h) {
    const r = h * 0.28, w = 2 * r, cx = x + r, cy = top + h - r;
    const neck = h * 0.2, lipW = h * 0.32, lipH = h * 0.08;
    return [{
      path(c) {
        c.roundRect(cx - lipW / 2, top, lipW, lipH, lipH / 2);
        c.rect(cx - neck / 2, top + lipH * 0.5, neck, h - 2 * r + r * 0.4);
        c.moveTo(cx + r, cy);
        c.arc(cx, cy, r, 0, Math.PI * 2);
      },
      detail(ctx) {
        const y = cy - r * 0.15, half = Math.sqrt(r * r - (r * 0.15) ** 2);
        line(ctx, [[cx - half + 1.4, y], [cx + half - 1.4, y]], h * 0.03, INK_LINE);
        ctx.beginPath();
        ctx.arc(cx + r * 0.35, cy + r * 0.38, r * 0.13, 0, Math.PI * 2);
        ctx.lineWidth = h * 0.02;
        ctx.strokeStyle = "rgba(60,28,0,0.45)";
        ctx.stroke();
      },
      left: x, right: x + w, top, bottom: top + h, width: w,
    }];
  }

  // A hammer, tilted: making things, though it reads as smithing first.
  function hammer(x, top, h) {
    const turn = 28 * Math.PI / 180, cos = Math.cos(turn), sin = Math.sin(turn);
    const head = [[-12, -18.5], [-4, -21.5], [9, -21.5], [9, -11], [-4, -11], [-12, -14]];
    const handle = [[-1.7, -12], [1.7, -12], [2.1, 22], [-2.1, 22]];
    const grips = [[[-2, 13], [2, 13]], [[-2, 16.5], [2, 16.5]], [[-2.1, 20], [2.1, 20]]];
    const turned = (p) => [p[0] * cos - p[1] * sin, p[0] * sin + p[1] * cos];
    const all = [...head, ...handle].map(turned);
    const minX = Math.min(...all.map((p) => p[0])), maxX = Math.max(...all.map((p) => p[0]));
    const minY = Math.min(...all.map((p) => p[1])), maxY = Math.max(...all.map((p) => p[1]));
    const s = h / (maxY - minY);
    const place = (p) => { const [a, b] = turned(p); return [x + (a - minX) * s, top + (b - minY) * s]; };
    const w = (maxX - minX) * s;
    return [{
      path(c) {
        P.polygon(c, head.map(place));
        P.polygon(c, handle.map(place));
      },
      detail(ctx) {
        grips.forEach((g) => line(ctx, g.map(place), h * 0.025, "rgba(60,28,0,0.5)"));
        line(ctx, [place([5, -21]), place([5, -11.5])], h * 0.025, INK_LINE);
      },
      left: x, right: x + w, top, bottom: top + h, width: w,
    }];
  }

  // ℞, the apothecary's sign, read "recipe": the Latin word that starts a prescription. An R in Friz, its leg crossed.
  // Two letters need a smaller K than K!'s.
  function rx(ctx) {
    return (x, top, h) => {
      const R = letter(ctx, "R", h, x, top + h);
      const W = R.width, base = top + h, t = h * 0.13;
      const cross = {
        path: (c) => P.polygon(c, [[R.left + W * 0.4, base + h * 0.06], [R.left + W * 0.4 + t, base + h * 0.06],
          [R.right + h * 0.1, base - h * 0.42], [R.right + h * 0.1 - t, base - h * 0.42]]),
        left: R.left + W * 0.4, right: R.right + h * 0.1, top: base - h * 0.42, bottom: base + h * 0.06,
      };
      return Object.assign([R, cross], { width: R.right + h * 0.1 - x });
    };
  }

  const width = (items) => items.width ?? Math.max(...items.map((i) => i.right)) - Math.min(...items.map((i) => i.left));

  // The K then the sign, centred on one baseline, as tall as each other; smaller when the pair needs more than ROOM.
  function kSign(ctx, sign, signInk) {
    const make = typeof sign === "function" && sign.length === 1 ? sign(ctx) : sign;
    const kr = letter(ctx, "K", 100, 0, 100).width / 100, sr = width(make(0, 0, 100)) / 100;
    const cap = Math.min(CAP, (ROOM - GAP) / (kr + sr));
    const baseline = 32 + cap / 2;
    const kw = kr * cap, total = kw + GAP + sr * cap, x = 32 - total / 2;
    const k = letter(ctx, "K", cap, x, baseline);
    const items = make(x + kw + GAP, baseline - cap, cap);
    items.forEach((i) => { i.colors = signInk; });
    P.emblem(ctx, [k, ...items], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.lineCap = "round";
    items.forEach((i) => i.detail && i.detail(ctx));
    ctx.restore();
  }

  // KaLi Quest's « Noir et or » frame: black ground, thin gold corners pushed to the edge.
  function framed(ctx, content) {
    P.framed(ctx, { ground: "black", inset: 6, len: 11, bracketColors: GOLD, bracketEdge: null, bracketWidth: 1.2 }, content);
  }

  const SIGNS = [
    ["plume", "Plume", quill, "A quill, nib down: the notebook is written in, and its sound is the quest log's quill."],
    ["parchemin", "Parchemin", scroll, "A sheet between two rolls: what a recipe is in the game, on every vendor and in every bag."],
    ["ordonnance", "℞", rx, "℞, the old sign for « recipe » (Latin for « take »), on prescriptions. Reads as KR too, the name. Two letters, so smaller."],
    ["carnet", "Carnet", notebook, "The notebook itself, closed, its ribbon hanging out."],
    ["fiole", "Fiole", flask, "A flask: the best-known craft, though alchemy's own."],
    ["marteau", "Marteau", hammer, "A hammer: making things, though it reads as smithing first."],
  ];

  const GOLD_SET = SIGNS.map(([id, name, sign, note]) => ({
    id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); },
  }));
  const BLUE_SET = SIGNS.map(([id, name, sign]) => ({
    id: "kr-" + id + "-bleu", name: name + " bleu", note: "Gold K and corners, the sign in the craft blue the notebook's lines use in tooltips.",
    draw(ctx) { framed(ctx, () => kSign(ctx, sign, BLUE)); },
  }));

  const QUILL_SET = [
    ["plume-goutte", "Plume et goutte", quillDrop, "The quest mark's own shape: the quill is the bar, a drop of ink the dot."],
    ["plume-courbe", "Plume courbe", quillCurved, "A broad goose quill on a curve, more barbs cut."],
    ["plume-taillee", "Plume taillée", quillCut, "Cut from straight lines, one side shaded, for a crisp shape at 16 px."],
    ["plume-encrier", "Plume et encrier", quillInk, "Standing in its inkwell. Wider, so the K is a little smaller."],
    ["plume-ecrit", "Plume qui écrit", quillWriting, "Its nib at the end of a stroke of ink: the notebook being written."],
  ].map(([id, name, sign, note]) => ({
    id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); },
  }));
  QUILL_SET.push({
    id: "kr-k-plume", name: "K-plume", note: "One sign: the quill is the K's arm, its nib in the stem, as « K-! » was for KaLi Quest.",
    draw(ctx) { framed(ctx, () => kQuill(ctx)); },
  });

  const WOW_SET = [
    { id: "kr-parchemin-jeu", name: "Parchemin du jeu", draw: (ctx) => kArt(ctx, "gold", 1.2),
      note: "The game's own scroll, INV_Scroll_03, its shades mapped onto the K's gold; beside it, the K is smaller." },
    { id: "kr-parchemin-jeu-aplats", name: "Parchemin du jeu, aplats", draw: (ctx) => kArt(ctx, "flat", 1.2),
      note: "The same in four flat tones of gold: closer to an emblem, as the K is." },
    { id: "kr-parchemin-jeu-redresse", name: "Parchemin du jeu, redressé", draw: (ctx) => kArt(ctx, "upright", 1.25),
      note: "The same turned 32° upright, the view unchanged: narrower, so the K is bigger." },
    { id: "kr-parchemin-jeu-grand", name: "Parchemin du jeu en grand", draw: artLarge,
      note: "The scroll as big as the game draws it, the K in the corner it leaves free. Small, the K is hard to read." },
  ].map((e) => ({ ...e, draw(ctx) { framed(ctx, () => e.draw(ctx)); } }));

  const STYLE_SET = [
    ["plume-chevrons", "Plume à chevrons", quillChevrons, "The vane cut right through into chevrons, each leaning to the tip."],
    ["plume-fendue", "Plume fendue", quillSplit, "A smooth vane with two deep splits, as feathers part."],
    ["plume-ronde", "Plume ronde", quillRound, "Short and broad, its tip rounded."],
    ["plume-fine", "Plume fine", quillSlender, "A calligrapher's long thin quill, barbs mostly on one side."],
    ["plume-ondulee", "Plume ondulée", quillWavy, "An s-shaped quill, its edges rippling."],
    ["plume-trait", "Plume au trait", quillLines, "Drawn in lines: the outline, the quill and four barbs, hollow inside."],
  ].map(([id, name, sign, note]) => ({
    id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); },
  }));

  const REF_SET = [
    ["plume-crochet", "Plume à crochet", hookFeather(true), "After Ikar's first feather: pointed barb groups leaning to the tip, the tip hooked, the quill a fine line cut through."],
    ["plume-barbes", "Plume à barbes", hookFeather(false), "The same barbs and cut quill, the tip straight: narrower, so the K is bigger."],
    ["plume-feuille", "Plume en feuille", leafFeather(false), "After Ikar's second feather: a long pointed leaf on an s, fine slits, the quill two cut lines, a bead at the stem."],
    ["plume-feuille-pointue", "Plume en feuille, pointue", leafFeather(true), "The same with a longer, thinner point."],
  ].map(([id, name, sign, note]) => ({
    id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); },
  }));

  const MORE_SET = MORE.map(([id, name, note, make]) => {
    const sign = fitted(make);
    return { id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); } };
  });

  const ANGULAR_SET = ANGULAR.map(([id, name, note, make]) => {
    const sign = fitted(make);
    return { id: "kr-" + id, name, note, draw(ctx) { framed(ctx, () => kSign(ctx, sign, GOLD)); } };
  });

  const GROUPS = [
    { title: "Six angular feathers, as if trimmed: Ikar's ask on 2026-11-11", prefix: "H", list: ANGULAR_SET },
    { title: "Twelve more feathers, the first three after F2: Ikar's ask on 2026-11-11", prefix: "G", list: MORE_SET },
    { title: "After Ikar's two feathers: 2026-11-11", prefix: "A", list: REF_SET },
    { title: "Six feathers in other styles: Ikar's ask on 2026-11-11", prefix: "F", list: STYLE_SET },
    { title: "The game's scroll, in one colour: Ikar's ask on 2026-11-11", prefix: "W", list: WOW_SET },
    { title: "Six more quills: Ikar's ask on 2026-11-11", prefix: "Q", list: QUILL_SET },
    { title: "K and a sign of recipes, in KaLi Quest's « Noir et or »", prefix: "R", list: GOLD_SET },
    { title: "The same, the sign in the craft blue", prefix: "B", list: BLUE_SET },
  ];
  const LIST = [...ANGULAR_SET, ...MORE_SET, ...REF_SET, ...STYLE_SET, ...WOW_SET, ...QUILL_SET, ...GOLD_SET, ...BLUE_SET];
  return { GROUPS, LIST, ready, byId: (id) => LIST.find((e) => e.id === id) };
})();
