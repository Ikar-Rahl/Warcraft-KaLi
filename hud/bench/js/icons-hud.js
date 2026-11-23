// KaLi HUD's icon candidates (Ikar, 2026-11-23: "an icon for kali hud ... similarly [to the 2 other] ... 10 proposals
// ... explore the graphic possible concepts"). The family's frame stays: KaLi Quest's « Noir et or », a black tile, thin
// gold corners and a gold K in Friz Quadrata, as KaLi Recipe's « Plume fendue » kept it. What changes is the sign: here
// it says what KaLi HUD is, a bronze base along the screen's foot, the minimap in a dome at its centre, the bars on it,
// two progress bars and an info bar at its foot. A 64 by 64 space, as the game's file.
window.KHIcons = (() => {
  const P = KQIcons.parts;
  const GOLD = P.GOLD;
  // The plate's own bronze, d6b386 (Data/Look.lua's colour), at the gradient's heart: the « bronze » ink.
  const BRONZE = [[0, "#fff6e6"], [0.3, "#edd5b0"], [0.68, "#c89f69"], [1, "#5c3f1c"]];
  const INKS = { gold: GOLD, bronze: BRONZE };
  const EDGE = "#231100";
  // KaLi Quest's K: 38 high, 2 from its sign; the pair keeps within 46 across, clear of the corners, as KaLi Recipe's.
  const CAP = 38, GAP = 2, ROOM = 46;
  const INK_LINE = "rgba(60,28,0,0.6)";
  const TAU = Math.PI * 2;

  function letter(ctx, ch, cap, x, baseline) {
    ctx.font = '100px "Friz"';
    const css = `${(100 * cap / ctx.measureText(ch).actualBoundingBoxAscent).toFixed(2)}px "Friz"`;
    ctx.font = css;
    const m = ctx.measureText(ch);
    const width = m.actualBoundingBoxLeft + m.actualBoundingBoxRight;
    return { text: ch, font: css, x: x + m.actualBoundingBoxLeft, y: baseline, left: x, right: x + width, top: baseline - cap, bottom: baseline, width };
  }

  function line(ctx, points, width, color = INK_LINE) {
    ctx.beginPath();
    ctx.moveTo(points[0][0], points[0][1]);
    points.slice(1).forEach(([x, y]) => ctx.lineTo(x, y));
    ctx.lineWidth = width;
    ctx.strokeStyle = color;
    ctx.stroke();
  }

  // Sub-paths: clockwise adds, a hole goes the other way (the fill is nonzero).
  function circle(c, cx, cy, r, hole = false) {
    c.moveTo(cx + r, cy);
    c.arc(cx, cy, r, 0, TAU, hole);
  }

  function box(items) {
    return {
      left: Math.min(...items.map((i) => i.left)), right: Math.max(...items.map((i) => i.right)),
      top: Math.min(...items.map((i) => i.top)), bottom: Math.max(...items.map((i) => i.bottom)),
    };
  }

  // The dome's outline as the plate draws it: a disc on an arch up to its centre, the arch on a wider foot, concave
  // where they meet; the map a round window in it. cx, cy: the disc's centre; r: its radius; hole: the map's; foot:
  // the plate's top, left and right, bottom.
  function domePath(c, o) {
    const { cx, cy, r, hole, footTop, left, right, bottom, fillet, round } = o;
    // A wing narrower than its fillet and corner shares its width between them; none, and the arch's side runs down.
    const wing = (w) => { const f = Math.max(0, Math.min(fillet, w / 2)); return [f, Math.max(0, Math.min(round, w - f))]; };
    const [fr, rr] = wing(right - (cx + r)), [fl, rl] = wing((cx - r) - left);
    c.moveTo(cx - r, cy);
    c.arc(cx, cy, r, Math.PI, 0);
    c.lineTo(cx + r, footTop - fr);
    c.quadraticCurveTo(cx + r, footTop, cx + r + fr, footTop);
    c.lineTo(right - rr, footTop);
    c.quadraticCurveTo(right, footTop, right, footTop + rr);
    c.lineTo(right, bottom);
    c.lineTo(left, bottom);
    c.lineTo(left, footTop + rl);
    c.quadraticCurveTo(left, footTop, left + rl, footTop);
    c.lineTo(cx - r - fl, footTop);
    c.quadraticCurveTo(cx - r, footTop, cx - r, footTop - fl);
    c.closePath();
    if (hole) circle(c, cx, cy, hole, true);
  }

  // Each sign: its width for a height of 1 (ratio), how tall it stands against the K (scale, 1 = cap high, centred on
  // the K's middle), and make(x, top, h): its shapes, h high from top, its ink starting at x, fine lines in detail().

  // 1. The minimap in its dome on the plate: KaLi HUD's own outline, small.
  // The plate runs well past the disc on both sides, low, or the outline reads as a padlock (tried 2026-11-23).
  const dome = {
    ratio: 1.04,
    make(x, top, h) {
      const w = 1.04 * h, cx = x + w / 2, r = 0.3 * h, cy = top + r, footTop = top + h * 0.68;
      const o = { cx, cy, r, hole: r * 0.6, footTop, left: x, right: x + w, bottom: top + h, fillet: h * 0.1, round: h * 0.07 };
      return [{
        path: (c) => domePath(c, o),
        detail(ctx) {
          // The info bar along the plate's foot.
          line(ctx, [[x + h * 0.08, top + h * 0.86], [x + w - h * 0.08, top + h * 0.86]], h * 0.04);
        },
        left: x, right: x + w, top, bottom: top + h, width: w,
      }];
    },
  };

  // 2. The minimap: its ring and the player's arrow at the centre.
  const minimap = {
    ratio: 1, scale: 0.9,
    make(x, top, h) {
      const R = h / 2, cx = x + R, cy = top + R, inner = R * 0.72;
      const s = R * 0.62;
      // The game's player arrow: a head with a notch, pointing north.
      const arrow = [[0, -1], [0.62, 0.78], [0, 0.42], [-0.62, 0.78]].map(([px, py]) => [cx + px * s, cy + py * s - s * 0.06]);
      return [
        { path: (c) => { circle(c, cx, cy, R); circle(c, cx, cy, inner, true); }, left: x, right: x + h, top, bottom: top + h, width: h },
        { path: (c) => P.polygon(c, arrow), left: cx - s * 0.62, right: cx + s * 0.62, top: cy - s, bottom: cy + s * 0.78 },
      ];
    },
  };

  // 3. A compass rose: what the minimap is, the north point longer.
  const rose = {
    ratio: 0.6,
    make(x, top, h) {
      const w = 0.6 * h, cx = x + w / 2, cy = top + h * 0.5, q = h * 0.085;
      const N = [cx, top], E = [x + w, cy], S = [cx, top + h], W = [x, cy];
      const NE = [cx + q, cy - q], SE = [cx + q, cy + q], SW = [cx - q, cy + q], NW = [cx - q, cy - q];
      return [{
        path: (c) => P.polygon(c, [N, NE, E, SE, S, SW, W, NW]),
        detail(ctx) {
          // Each point's right half in shade, as compass roses are drawn.
          ctx.fillStyle = "rgba(70,30,0,0.38)";
          for (const tri of [[N, [cx, cy], NE], [E, [cx, cy], SE], [S, [cx, cy], SW], [W, [cx, cy], NW]]) {
            ctx.beginPath();
            P.polygon(ctx, tri);
            ctx.fill();
          }
        },
        left: x, right: x + w, top, bottom: top + h, width: w,
      }];
    },
  };

  // 4. Action buttons: two columns of three, the bars the plate holds.
  const buttons = {
    ratio: 0.64,
    make(x, top, h) {
      const g = h * 0.06, s = (h - 2 * g) / 3, w = 2 * s + g, r = s * 0.16;
      const cells = [];
      for (let row = 0; row < 3; row++) for (let col = 0; col < 2; col++) cells.push([x + col * (s + g), top + row * (s + g)]);
      return cells.map(([bx, by]) => ({
        path: (c) => c.roundRect(bx, by, s, s, r),
        detail(ctx) {
          // The button's bevel: a darker inner square.
          ctx.beginPath();
          ctx.roundRect(bx + s * 0.22, by + s * 0.22, s * 0.56, s * 0.56, r * 0.6);
          ctx.lineWidth = h * 0.024;
          ctx.strokeStyle = "rgba(60,28,0,0.5)";
          ctx.stroke();
        },
        left: bx, right: bx + s, top: by, bottom: by + s, width: w,
      }));
    },
  };

  // 5. The two progress bars, experience and reputation, part filled.
  const gauges = {
    ratio: 1.15, scale: 0.66,
    make(x, top, h) {
      const w = 1.15 * h, bh = h * 0.38, frame = h * 0.08;
      const bars = [[top, 0.68], [top + h - bh, 0.38]];
      const items = [];
      for (const [by, full] of bars) {
        const ix = x + frame, iy = by + frame, iw = w - 2 * frame, ih = bh - 2 * frame;
        items.push({
          path: (c) => {
            c.roundRect(x, by, w, bh, bh * 0.3);
            c.moveTo(ix, iy);
            c.lineTo(ix, iy + ih);
            c.lineTo(ix + iw, iy + ih);
            c.lineTo(ix + iw, iy);
            c.closePath();
          },
          left: x, right: x + w, top: by, bottom: by + bh, width: w,
        });
        const gap = h * 0.045;
        items.push({
          path: (c) => c.rect(ix + gap, iy + gap, (iw - 2 * gap) * full, ih - 2 * gap),
          left: ix, right: ix + iw * full, top: iy, bottom: iy + ih,
        });
      }
      return items;
    },
  };

  // 6. A head-up display's sight, where the word comes from: a ring, four ticks and a dot.
  const sight = {
    ratio: 1, scale: 0.9,
    make(x, top, h) {
      const R = h * 0.38, cx = x + h / 2, cy = top + h / 2, t = h * 0.085, inner = R - h * 0.085, reach = h * 0.2;
      return [{
        path: (c) => {
          circle(c, cx, cy, R);
          circle(c, cx, cy, inner, true);
          c.rect(cx - t / 2, top, t, reach + (h / 2 - R));
          c.rect(cx - t / 2, top + h - reach - (h / 2 - R), t, reach + (h / 2 - R));
          c.rect(x, cy - t / 2, reach + (h / 2 - R), t);
          c.rect(x + h - reach - (h / 2 - R), cy - t / 2, reach + (h / 2 - R), t);
          circle(c, cx, cy, h * 0.065);
        },
        left: x, right: x + h, top, bottom: top + h, width: h,
      }];
    },
  };

  const width = (sign, h) => sign.ratio * (sign.scale ?? 1) * h;

  // The K then the sign, centred on one baseline; smaller when the pair needs more than ROOM.
  function kSign(ctx, sign, ink) {
    const kr = letter(ctx, "K", 100, 0, 100).width / 100;
    const sr = width(sign, 1);
    const cap = Math.min(CAP, (ROOM - GAP) / (kr + sr));
    const baseline = 32 + cap / 2;
    const kw = kr * cap, x = 32 - (kw + GAP + sr * cap) / 2;
    const k = letter(ctx, "K", cap, x, baseline);
    const h = cap * (sign.scale ?? 1);
    const items = sign.make(x + kw + GAP, baseline - cap + (cap - h) / 2, h);
    items.forEach((i) => { i.colors = ink; });
    P.emblem(ctx, [k, ...items], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.lineCap = "round";
    items.forEach((i) => i.detail && i.detail(ctx));
    ctx.restore();
  }

  // The K in the HUD itself, rather than beside a sign of it.

  // 7. The K standing on the plate, raised where the minimap's dome would be.
  function plinth(ctx, ink) {
    const cap = 30, baseline = 42.5;
    const kw = letter(ctx, "K", cap, 0, baseline).width;
    const k = letter(ctx, "K", cap, 32 - kw / 2, baseline);
    const low = 50, high = 45, bottom = 56, left = 10, right = 54, mid0 = 20, mid1 = 44, f = 2.6, rr = 2;
    const plate = {
      path: (c) => {
        c.moveTo(left, low + rr);
        c.quadraticCurveTo(left, low, left + rr, low);
        c.lineTo(mid0 - f, low);
        c.quadraticCurveTo(mid0, low, mid0, low - f);
        c.lineTo(mid0, high + rr);
        c.quadraticCurveTo(mid0, high, mid0 + rr, high);
        c.lineTo(mid1 - rr, high);
        c.quadraticCurveTo(mid1, high, mid1, high + rr);
        c.lineTo(mid1, low - f);
        c.quadraticCurveTo(mid1, low, mid1 + f, low);
        c.lineTo(right - rr, low);
        c.quadraticCurveTo(right, low, right, low + rr);
        c.lineTo(right, bottom);
        c.lineTo(left, bottom);
        c.closePath();
      },
      detail(c) { line(c, [[left + 2.5, 53.6], [right - 2.5, 53.6]], 1); },
      left, right, top: high, bottom, colors: ink,
    };
    P.emblem(ctx, [k, plate], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.lineCap = "round";
    plate.detail(ctx);
    ctx.restore();
  }

  // 8. The K in the map's window: the dome is the icon, the K where the minimap is.
  function kInDome(ctx, ink) {
    // A smaller disc than the plate allows, so the plate shows as wings either side: else it reads as a bell.
    const cx = 32, cy = 27.5, r = 17.5;
    const o = { cx, cy, r, hole: 13.6, footTop: 46.5, left: 9.5, right: 54.5, bottom: 55, fillet: 4, round: 2.4 };
    const dome = { path: (c) => domePath(c, o), left: o.left, right: o.right, top: cy - r, bottom: o.bottom, colors: ink };
    const cap = 17;
    const kw = letter(ctx, "K", cap, 0, 0).width;
    const k = letter(ctx, "K", cap, cx - kw / 2, cy + cap / 2);
    P.emblem(ctx, [dome, k], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.lineCap = "round";
    line(ctx, [[o.left + 2.5, 52.4], [o.right - 2.5, 52.4]], 1);
    ctx.restore();
  }

  // 9. The HUD in miniature, as KaLi Quest's « Suivi » drew its tracker: the plate along the foot, the dome at its
  // centre, two rows of buttons each side and the info bar under them; the K above, in the screen's free space.
  function screen(ctx, ink) {
    const cx = 32, cy = 41.5, r = 8;
    const o = { cx, cy, r, hole: 5.4, footTop: 44.5, left: 10, right: 54, bottom: 55.5, fillet: 2, round: 1.6 };
    const plate = { path: (c) => domePath(c, o), left: o.left, right: o.right, top: cy - r, bottom: o.bottom, colors: ink };
    const cap = 22;
    const kw = letter(ctx, "K", cap, 0, 0).width;
    const k = letter(ctx, "K", cap, cx - kw / 2, 30);
    P.emblem(ctx, [k, plate], { colors: GOLD, edge: EDGE });
    ctx.save();
    ctx.fillStyle = "rgba(50,22,0,0.62)";
    for (const [x0, dir] of [[12, 1], [52, -1]]) {
      for (let row = 0; row < 2; row++) {
        for (let i = 0; i < 3; i++) {
          ctx.beginPath();
          ctx.roundRect(x0 + dir * i * 4 - (dir < 0 ? 3 : 0), 46.5 + row * 3.6, 3, 2.8, 0.5);
          ctx.fill();
        }
      }
    }
    ctx.lineCap = "round";
    line(ctx, [[o.left + 2, 54], [o.right - 2, 54]], 1.1);
    ctx.restore();
  }

  // 10. One sign, as « K-! » and « K-plume » were: the K's arm and leg spring from the minimap's ring on its stem.
  function kDome(ctx, ink) {
    const top = 13, base = 51, stem0 = 13.5, stem1 = 21.5;
    const cx = 28.5, cy = 32, R = 8.6, hole = 4.6, hw = 3.9;
    const limb = (angle, endY) => {
      const u = [Math.cos(angle), Math.sin(angle)], n = [-u[1], u[0]], start = R * 0.78;
      const s = [cx + u[0] * start, cy + u[1] * start];
      const along = (endY - s[1]) / u[1];
      const e = [s[0] + u[0] * along, endY];
      // Each edge runs to the line y = endY, so the stroke ends flat, as the K's own.
      const edge = (side) => {
        const p0 = [s[0] + n[0] * hw * side, s[1] + n[1] * hw * side];
        const t = (endY - p0[1]) / u[1];
        return [p0, [p0[0] + u[0] * t, endY]];
      };
      const [a0, a1] = edge(1), [b0, b1] = edge(-1);
      return { points: [a0, a1, b1, b0], end: e };
    };
    const arm = limb(Math.atan2(-(cy - top), 49 - cx), top);
    const leg = limb(Math.atan2(base - cy, 50 - cx), base);
    const strokes = {
      path: (c) => {
        P.polygon(c, [[stem0, top], [stem1, top], [stem1, base], [stem0, base]]);
        P.polygon(c, arm.points);
        P.polygon(c, leg.points);
      },
      left: stem0, right: 54, top, bottom: base,
    };
    const ring = {
      path: (c) => { circle(c, cx, cy, R); circle(c, cx, cy, hole, true); },
      left: cx - R, right: cx + R, top: cy - R, bottom: cy + R, colors: ink,
    };
    // The limbs' polygons must turn the same way as the stem's, or they'd cut it: fix their winding.
    for (const shape of [arm, leg]) {
      const pts = shape.points;
      const area = pts.reduce((a, p, i) => a + p[0] * pts[(i + 1) % pts.length][1] - pts[(i + 1) % pts.length][0] * p[1], 0);
      if (area < 0) pts.reverse();
    }
    P.emblem(ctx, [strokes, ring], { colors: GOLD, edge: EDGE });
  }

  // KaLi Quest's « Noir et or » frame: black ground, thin gold corners pushed to the edge.
  function framed(ctx, content) {
    P.framed(ctx, { ground: "black", inset: 6, len: 11, bracketColors: GOLD, bracketEdge: null, bracketWidth: 1.2 }, content);
  }

  // H1 again (Ikar, 2026-11-23: "the dome is good, but it look like a lockpad"; "the K need to be of the same size, so
  // we need to find how to squich something in"). The K is KaLi Quest's own: 38 high on the 51 baseline, at K!'s place
  // (its ink from 7.6 to 42.6, measured), or centred where the dome stands behind all of it. Beside it, only the quest
  // mark's 12 px are left; but its open side, between arm and leg, holds a disc some 20 across, and the dome can stand
  // behind it: the dome is drawn first, the K last, its dark edge and shadow over the dome.

  function questK(ctx, centred) {
    const kw = letter(ctx, "K", CAP, 0, 51).width;
    return letter(ctx, "K", CAP, centred ? 32 - kw / 2 : 32 - (kw + GAP + 0.31 * CAP) / 2, 51);
  }

  function domeItem(o, colors) {
    return { path: (c) => domePath(c, o), left: o.left, right: o.right, top: o.cy - o.r, bottom: o.bottom, colors };
  }

  // The info bar: a dark line along the plate's foot.
  function infoBar(ctx, o, y) {
    ctx.save();
    ctx.lineCap = "round";
    line(ctx, [[o.left + 2.2, y], [o.right - 2.2, y]], 1);
    ctx.restore();
  }

  // Over the dome alone, the K's edge is wider: a dark gap that parts gold from gold (with its usual 3 they merged into
  // one shape; wider everywhere, the K looked heavier than its siblings': both tried 2026-11-23).
  function kOver(ctx, back, k, between) {
    P.emblem(ctx, back, { colors: GOLD, edge: EDGE });
    if (between) between(ctx);
    ctx.save();
    ctx.beginPath();
    back.forEach((item) => item.path(ctx));
    ctx.clip();
    ctx.font = k.font;
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    ctx.lineJoin = "round";
    ctx.lineWidth = 6;
    ctx.strokeStyle = "#0b0602";
    ctx.strokeText(k.text, k.x, k.y);
    ctx.restore();
    P.emblem(ctx, [k], { colors: GOLD, edge: EDGE });
  }

  // The minimap's glass in the window, the player's arrow on it: a filled window has no shackle to read.
  function glass(ctx, cx, cy, r, ink) {
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, TAU);
    ctx.fillStyle = P.radial(ctx, cx - r * 0.3, cy - r * 0.35, 0.5, cx, cy, r, [[0, "#33413a"], [1, "#0a0d0b"]]);
    ctx.fill();
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = EDGE;
    ctx.stroke();
    ctx.restore();
    const s = r * 0.66;
    const pts = [[0, -1], [0.62, 0.78], [0, 0.42], [-0.62, 0.78]].map(([px, py]) => [cx + px * s, cy + py * s + s * 0.06]);
    P.emblem(ctx, [{ path: (c) => P.polygon(c, pts), left: cx - s * 0.62, right: cx + s * 0.62, top: cy - s, bottom: cy + s * 0.84, colors: ink }],
      { colors: GOLD, edge: EDGE, outline: 1.6, blur: 1, drop: 0.6 });
  }

  // The dome as a backdrop: the same metal, darker, so the K stands out in front.
  const DIM = {
    gold: [[0, "#a07b33"], [0.45, "#684816"], [1, "#2c1b05"]],
    bronze: [[0, "#9c8466"], [0.45, "#624d34"], [1, "#2b2013"]],
  };

  // The frame's corners but one (0 top left, 1 top right, 2 bottom left, 3 bottom right), as P.framed draws them.
  function framedBut(ctx, skip, content) {
    const clear = [[0, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0)"]];
    P.framed(ctx, { ground: "black", inset: 6, len: 11, bracketColors: clear, bracketEdge: null, bracketWidth: 1.2 }, () => {
      const inset = 6, len = 11, far = 64 - inset;
      ctx.save();
      ctx.lineCap = "square";
      ctx.lineJoin = "miter";
      ctx.lineWidth = 1.2;
      [[inset, inset, 1, 1], [far, inset, -1, 1], [inset, far, 1, -1], [far, far, -1, -1]].forEach(([x, y, sx, sy], i) => {
        if (i === skip) return;
        ctx.beginPath();
        ctx.moveTo(x, y + sy * len);
        ctx.lineTo(x, y);
        ctx.lineTo(x + sx * len, y);
        ctx.strokeStyle = P.linear(ctx, 0, y - 3, 0, y + sy * len, GOLD);
        ctx.stroke();
      });
      ctx.restore();
      content();
    });
  }

  // Each: (ctx, ink colours, ink name) inside the frame.
  const ITERATIONS = [
    ["v", "Dans le V", (ctx, ink) => {
      const o = { cx: 42, cy: 30, r: 10, hole: 6.2, footTop: 44, left: 9.5, right: 56, bottom: 52.5, fillet: 2.8, round: 2 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => infoBar(c, o, 49.5));
    }, "The disc in the K's open side, between arm and leg; its arch and the plate behind the leg, the plate along the K's whole foot."],
    ["v-carte", "Dans le V, carte", (ctx, ink) => {
      const o = { cx: 42, cy: 30, r: 10, hole: 0, footTop: 44, left: 9.5, right: 56, bottom: 52.5, fillet: 2.8, round: 2 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => { infoBar(c, o, 49.5); glass(c, 42, 30, 6.4, ink); });
    }, "The same, the window filled with the minimap's dark glass and the player's arrow: no hole, so no shackle."],
    ["plaque", "Sur la plaque", (ctx, ink) => {
      const o = { cx: 42.5, cy: 29, r: 10, hole: 6.2, footTop: 51.5, left: 9.5, right: 56, bottom: 55.5, fillet: 2.5, round: 1.5 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => infoBar(c, o, 53.6));
    }, "The K standing on the plate, a thin band under its foot; the dome rises from it behind the leg, its disc in the K's open side."],
    ["demi", "Coupole basse", (ctx, ink) => {
      const o = { cx: 43.5, cy: 41, r: 11, hole: 6.6, footTop: 43.5, left: 9.5, right: 56, bottom: 52.5, fillet: 2.5, round: 2 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => infoBar(c, o, 49.5));
    }, "Only the dome's top half shows, sunk in the plate at the K's foot, the map's window half in the plate as on screen. Low and wide: nothing like a padlock's shackle."],
    ["derriere", "Grand, derrière", (ctx, ink) => {
      const o = { cx: 42.5, cy: 26, r: 12, hole: 7.6, footTop: 44, left: 9.5, right: 56, bottom: 52.5, fillet: 2.8, round: 2 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => infoBar(c, o, 49.5));
    }, "A bigger dome, behind the K's arm and leg, its window seen through the K's open side."],
    // A whole disc on a plate this small read as a padlock again (tried 2026-11-23): low cupolas, as « Coupole basse ».
    ["exposant", "Exposant", (ctx, ink) => {
      const o = { cx: 47.5, cy: 22, r: 7, hole: 4, footTop: 23.8, left: 38, right: 56.5, bottom: 28.5, fillet: 1.8, round: 1.2 };
      P.emblem(ctx, [questK(ctx), domeItem(o, ink)], { colors: GOLD, edge: EDGE });
    }, "A small low cupola on its plate beside the K's arm, raised like an exponent (as KaLi Quest's « K exposant »). Small: a speck at 16 px."],
    ["coin", "Au coin", (ctx, ink) => {
      const o = { cx: 48, cy: 46, r: 9, hole: 5.4, footTop: 48, left: 34, right: 58.5, bottom: 56.5, fillet: 2, round: 1.6 };
      kOver(ctx, [domeItem(o, ink)], questK(ctx), (c) => infoBar(c, o, 53.2));
    }, "A low cupola in the bottom right corner, in place of that corner's bracket, its plate behind the K's foot: the HUD at the foot of the screen."],
    ["tenu", "Tenu", (ctx, ink) => {
      const ring = { path: (c) => { circle(c, 40.5, 30, 12.5); circle(c, 40.5, 30, 8, true); }, left: 28, right: 53, top: 17.5, bottom: 42.5, colors: ink };
      const plate = { path: (c) => c.roundRect(9.5, 50.5, 46, 4.8, 1.5), left: 9.5, right: 55.5, top: 50.5, bottom: 55.3, colors: ink };
      P.emblem(ctx, [ring, plate, questK(ctx)], { colors: GOLD, edge: EDGE });
    }, "One shape: the K's arm and leg hold the minimap's ring, the K stands on the plate. No arch, so no padlock body, but it reads « KO »."],
    ["fond", "Toile de fond", (ctx, ink, name) => {
      const o = { cx: 32, cy: 28, r: 17, hole: 12, footTop: 44, left: 10, right: 54, bottom: 54.5, fillet: 3, round: 2 };
      kOver(ctx, [domeItem(o, DIM[name])], questK(ctx, true), (c) => infoBar(c, o, 51.5));
    }, "The whole dome behind the K, centred, in a darker metal so the K reads in front. The dome is unmistakable; the K's sign is gone."],
    ["contour", "Contour", (ctx, ink) => {
      const o = { cx: 32, cy: 28, r: 17, hole: 12, footTop: 44, left: 10, right: 54, bottom: 54.5, fillet: 3, round: 2 };
      ctx.save();
      ctx.beginPath();
      domePath(ctx, o);
      ctx.lineWidth = 1.3;
      ctx.lineJoin = "round";
      ctx.strokeStyle = P.linear(ctx, 0, o.cy - o.r, 0, o.bottom, ink);
      ctx.stroke();
      ctx.restore();
      P.emblem(ctx, [questK(ctx, true)], { colors: GOLD, edge: EDGE });
    }, "The dome drawn as a thin line, as fine as the corners, behind the centred K. Light; at 16 px only the K is left."],
  ];

  const SIGNS = [
    ["dome", "Dôme", dome, "The minimap in its dome on the plate, the info bar along its foot: KaLi HUD's own outline, small. Wider than the quest mark, so the K is smaller."],
    ["minicarte", "Minicarte", minimap, "The minimap's ring and the player's arrow: what everyone knows from the game. Round, so the K is smaller still."],
    ["rose", "Rose des vents", rose, "A compass rose, its points shaded on one side: the map without drawing the map."],
    ["boutons", "Boutons", buttons, "Six action buttons, two by three: the bars the plate holds. Can also read as a bag's slots."],
    ["jauges", "Jauges", gauges, "The two progress bars, experience and reputation, part filled."],
    ["visee", "Visée", sight, "A head-up display's sight, where the word HUD comes from (a fighter pilot's glass). Can read as a target mark."],
  ];

  const COMPOSITIONS = [
    ["socle", "Socle", plinth, "The K standing on the plate, raised in the middle where the dome is: the base under it, the info bar along its foot."],
    ["k-dome", "K au dôme", kInDome, "The dome is the icon, the K in the map's window. One bold shape, but the K is small."],
    ["ecran", "Écran", screen, "The HUD in miniature, as KaLi Quest's « Suivi » drew its tracker: plate, dome, two rows of buttons each side, the info bar; the K above."],
    ["k-anneau", "K-anneau", kDome, "One sign, as « K-! » and « K-plume »: the K's arm and leg spring from the minimap's ring on its stem. Drawn, not Friz."],
  ];

  function build(ink) {
    const tag = ink === "gold" ? "" : "-" + ink;
    const signs = SIGNS.map(([id, name, sign, note], i) => ({
      id: "kh-" + id + tag, base: "kh-" + id, number: `H${i + 1}`, name, note,
      draw(ctx) { framed(ctx, () => kSign(ctx, sign, INKS[ink])); },
    }));
    const compositions = COMPOSITIONS.map(([id, name, fn, note], i) => ({
      id: "kh-" + id + tag, base: "kh-" + id, number: `H${SIGNS.length + i + 1}`, name, note,
      draw(ctx) { framed(ctx, () => fn(ctx, INKS[ink])); },
    }));
    const iterations = ITERATIONS.map(([id, name, fn, note], i) => ({
      id: "kh-dome-" + id + tag, base: "kh-dome-" + id, number: `H1.${i + 1}`, name, note,
      draw(ctx) { (id === "coin" ? (c, f) => framedBut(c, 3, f) : framed)(ctx, () => fn(ctx, INKS[ink], ink)); },
    }));
    const groups = [
      { key: "iterations", title: "H1 again: the dome, and KaLi Quest's K at its own size (Ikar's ask on 2026-11-23)", list: iterations },
      { key: "signs", title: "First round: K and a sign of the HUD, in KaLi Quest's « Noir et or »", list: signs },
      { key: "compositions", title: "First round: the K in the HUD itself", list: compositions },
    ];
    groups.forEach((g) => g.list.forEach((e) => { e.group = g.key; }));
    return groups;
  }

  const BY_INK = { gold: build("gold"), bronze: build("bronze") };
  const LIST = [...BY_INK.gold, ...BY_INK.bronze].flatMap((g) => g.list);

  // The icon the TOC names until a pick: hud/tools/make_media.py's icon(64), a bronze dome on its plate, drawn here
  // pixel by pixel from the same formula (x, y from the bottom left, 0 to 1).
  const BEFORE = {
    id: "current", name: "Before", number: "",
    note: "hud/tools/make_media.py's placeholder, a bronze dome on its plate: the TOC's icon until a pick.",
    draw(ctx) {
      const size = ctx.canvas.width, img = ctx.createImageData(size, size);
      const bronze = [0.651, 0.490, 0.271], light = [0.800, 0.600, 0.341], dark = [0.06, 0.05, 0.04];
      for (let py = 0; py < size; py++) {
        for (let px = 0; px < size; px++) {
          const x = (px + 0.5) / size, y = 1 - (py + 0.5) / size;
          const d = Math.hypot(x - 0.5, y - 0.36), plate = y < 0.36, domeIn = d < 0.42;
          let rgba = null;
          if (!(plate || domeIn) || y < 0.08) rgba = null;
          else if (d > 0.24 && d < 0.30) { const k = 0.5 + 0.5 * y; rgba = bronze.map((b, i) => b + (light[i] - b) * k).concat(1); }
          else if (d <= 0.24) rgba = dark.concat(1);
          else {
            const rim = Math.min(domeIn && y >= 0.36 ? Math.abs(d - 0.42) : 1, plate && d >= 0.42 ? Math.abs(y - 0.36) : 1, y - 0.08);
            if (rim < 0.035) rgba = bronze.concat(1);
            else { const g = 0.05 + 0.06 * y; rgba = [g * 1.15, g, g * 0.8, 1]; }
          }
          if (rgba) {
            const o = (py * size + px) * 4;
            img.data[o] = rgba[0] * 255; img.data[o + 1] = rgba[1] * 255; img.data[o + 2] = rgba[2] * 255; img.data[o + 3] = 255;
          }
        }
      }
      ctx.putImageData(img, 0, 0);
    },
  };

  return { INKS: Object.keys(INKS), BY_INK, LIST, BEFORE, byId: (id) => (id === "current" ? BEFORE : LIST.find((e) => e.id === id)) };
})();
