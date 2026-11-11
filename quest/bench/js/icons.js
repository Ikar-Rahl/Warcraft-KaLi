// Candidates for the addon's icon, drawn in a 64 by 64 space. tools/scripts/make_icon.py exports one as the TGA.
window.KQIcons = (() => {
  const GOLD = [[0, "#fff8cc"], [0.28, "#ffd94d"], [0.68, "#efa300"], [1, "#a35a00"]];
  const DIM_GOLD = [[0, "#f3dfa6"], [0.4, "#c8902a"], [1, "#5e3500"]];
  const SILVER = [[0, "#ffffff"], [0.35, "#e4e9f0"], [0.72, "#9ca8b7"], [1, "#4d5868"]];
  const STEEL = [[0, "#dcedff"], [0.45, "#7ea6dc"], [1, "#22406f"]];
  const BRONZE = [[0, "#d6a066"], [0.5, "#8e5824"], [1, "#43240a"]];
  const SHINE = [[0, "rgba(255,255,255,0.55)"], [0.45, "rgba(255,255,255,0)"], [1, "rgba(80,30,0,0.25)"]];

  function rng(seed) {
    return () => {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function linear(ctx, x0, y0, x1, y1, stops) {
    const g = ctx.createLinearGradient(x0, y0, x1, y1);
    stops.forEach(([s, c]) => g.addColorStop(s, c));
    return g;
  }

  function radial(ctx, x0, y0, r0, x1, y1, r1, stops) {
    const g = ctx.createRadialGradient(x0, y0, r0, x1, y1, r1);
    stops.forEach(([s, c]) => g.addColorStop(s, c));
    return g;
  }

  function shadow(ctx, blur, y, alpha = 0.7) {
    ctx.shadowColor = `rgba(0,0,0,${alpha})`;
    ctx.shadowBlur = blur;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = y;
  }

  function noShadow(ctx) {
    ctx.shadowColor = "transparent";
  }

  // The quest mark: a tapered bar with rounded ends, then a dot. Adds to the current path, clockwise.
  function bangShape(ctx, cx, top, h) {
    const wt = h * 0.155, wb = h * 0.085, barH = h * 0.69, r = wt * 0.55, dotR = h * 0.12;
    ctx.moveTo(cx - wt, top + r);
    ctx.quadraticCurveTo(cx - wt, top, cx - wt + r, top);
    ctx.lineTo(cx + wt - r, top);
    ctx.quadraticCurveTo(cx + wt, top, cx + wt, top + r);
    ctx.lineTo(cx + wb, top + barH - wb);
    ctx.arc(cx, top + barH - wb, wb, 0, Math.PI);
    ctx.closePath();
    ctx.moveTo(cx + dotR, top + h - dotR);
    ctx.arc(cx, top + h - dotR, dotR, 0, Math.PI * 2);
  }

  function bangPath(ctx, cx, top, h) {
    ctx.beginPath();
    bangShape(ctx, cx, top, h);
  }

  function bang(ctx, cx, top, h, o = {}) {
    ctx.save();
    ctx.lineJoin = "round";
    bangPath(ctx, cx, top, h);
    if (o.shadow !== false) shadow(ctx, h * 0.07, h * 0.035);
    ctx.lineWidth = o.outline ?? Math.max(1.2, h * 0.075);
    ctx.strokeStyle = o.edge || "#231100";
    ctx.stroke();
    noShadow(ctx);
    ctx.fillStyle = linear(ctx, 0, top, 0, top + h, o.colors || GOLD);
    ctx.fill();
    ctx.clip();
    ctx.fillStyle = linear(ctx, cx - h * 0.16, 0, cx + h * 0.1, 0,
      [[0, "rgba(255,255,255,0.6)"], [0.5, "rgba(255,255,255,0)"], [1, "rgba(80,30,0,0.25)"]]);
    ctx.fillRect(cx - h * 0.3, top - 2, h * 0.6, h + 4);
    ctx.restore();
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
  }

  // A square icon like the game's own: painted ground, darker edges, a thin rim.
  function tile(ctx, ground, content) {
    ctx.save();
    roundRect(ctx, 1, 1, 62, 62, 5);
    ctx.clip();
    ground();
    ctx.fillStyle = radial(ctx, 30, 26, 12, 32, 32, 46, [[0, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0.6)"]]);
    ctx.fillRect(0, 0, 64, 64);
    content();
    ctx.restore();
    roundRect(ctx, 1.5, 1.5, 61, 61, 5);
    ctx.lineWidth = 3;
    ctx.strokeStyle = "#0b0805";
    ctx.stroke();
    roundRect(ctx, 3.5, 3.5, 57, 57, 3.5);
    ctx.lineWidth = 1;
    ctx.strokeStyle = "rgba(255,236,190,0.22)";
    ctx.stroke();
  }

  function parchment(ctx, x, y, w, h, seed, dark = 0) {
    ctx.fillStyle = radial(ctx, x + w * 0.4, y + h * 0.32, 1, x + w * 0.5, y + h * 0.5, Math.max(w, h) * 0.75,
      [[0, dark ? "#e2cc98" : "#f7e8c2"], [0.55, dark ? "#c2a26b" : "#dcc28e"], [1, dark ? "#7d5a2c" : "#9c7642"]]);
    ctx.fillRect(x, y, w, h);
    const r = rng(seed);
    ctx.lineCap = "round";
    for (let i = 0; i < 70; i++) {
      const px = x + r() * w, py = y + r() * h, a = r() * Math.PI, len = 1.5 + r() * 4;
      ctx.strokeStyle = `rgba(90,55,15,${0.05 + r() * 0.1})`;
      ctx.lineWidth = 0.6 + r() * 0.6;
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(px + Math.cos(a) * len, py + Math.sin(a) * len);
      ctx.stroke();
    }
  }

  function ribbon(ctx, x, y0, y1, color) {
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(x - 2.6, y0);
    ctx.lineTo(x + 2.6, y0);
    ctx.lineTo(x + 2.6, y1);
    ctx.lineTo(x, y1 - 3);
    ctx.lineTo(x - 2.6, y1);
    ctx.closePath();
    shadow(ctx, 1.5, 1, 0.6);
    ctx.fillStyle = color;
    ctx.fill();
    noShadow(ctx);
    ctx.fillStyle = linear(ctx, x - 2.6, 0, x + 2.6, 0, [[0, "rgba(255,255,255,0.3)"], [0.5, "rgba(255,255,255,0)"], [1, "rgba(0,0,0,0.35)"]]);
    ctx.fill();
    ctx.lineWidth = 1;
    ctx.strokeStyle = "rgba(20,5,0,0.85)";
    ctx.stroke();
    ctx.restore();
  }

  // Clockwise, like the quest mark, so overlapping parts fill as one shape.
  function polygon(ctx, points) {
    ctx.moveTo(points[0][0], points[0][1]);
    points.slice(1).forEach(([x, y]) => ctx.lineTo(x, y));
    ctx.closePath();
  }

  function paintItem(ctx, item, how) {
    if (item.text) {
      ctx.font = item.font;
      ctx.textAlign = "left";
      ctx.textBaseline = "alphabetic";
      if (how === "stroke") ctx.strokeText(item.text, item.x, item.y);
      else ctx.fillText(item.text, item.x, item.y);
      return;
    }
    ctx.beginPath();
    item.path(ctx);
    ctx[how]();
  }

  // Letters and shapes with the quest mark's finish: dark outline and drop shadow, then a gradient with a shine on the left.
  function emblem(ctx, items, o = {}) {
    ctx.save();
    ctx.lineJoin = "round";
    shadow(ctx, o.blur ?? 2.5, o.drop ?? 1.3);
    ctx.strokeStyle = o.edge || "#231100";
    ctx.lineWidth = o.outline ?? 3;
    items.forEach((item) => paintItem(ctx, item, "stroke"));
    ctx.restore();
    const layer = document.createElement("canvas");
    layer.width = ctx.canvas.width;
    layer.height = ctx.canvas.height;
    const g = layer.getContext("2d");
    g.setTransform(ctx.getTransform());
    for (const item of items) {
      g.globalCompositeOperation = "source-over";
      g.fillStyle = linear(g, 0, item.top, 0, item.bottom, item.colors || o.colors || GOLD);
      paintItem(g, item, "fill");
      g.globalCompositeOperation = "source-atop";
      g.fillStyle = linear(g, item.left, 0, item.right, 0, SHINE);
      g.fillRect(item.left, item.top - 2, item.right - item.left, item.bottom - item.top + 4);
    }
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(layer, 0, 0);
    ctx.restore();
  }

  const FONTS = { friz: ["normal", '"Friz"'], serif: ["bold", "Georgia"] };

  // A K whose capital stands cap high on the baseline, its ink starting at x.
  function letterK(ctx, font, cap, x, baseline) {
    if (font === "drawn") return drawnK(x, baseline, cap);
    const [weight, family] = FONTS[font];
    ctx.font = `${weight} 100px ${family}`;
    const css = `${weight} ${(100 * cap / ctx.measureText("K").actualBoundingBoxAscent).toFixed(2)}px ${family}`;
    ctx.font = css;
    const m = ctx.measureText("K");
    const width = m.actualBoundingBoxLeft + m.actualBoundingBoxRight;
    return { text: "K", font: css, x: x + m.actualBoundingBoxLeft, y: baseline, left: x, right: x + width, top: baseline - cap, bottom: baseline, width };
  }

  // A K cut from straight strokes, so the file owes nothing to a font.
  function drawnK(x, baseline, cap) {
    const t = baseline - cap, s = cap * 0.25, w = cap * 0.8;
    return {
      path: (c) => {
        polygon(c, [[x, t], [x + s, t], [x + s, baseline], [x, baseline]]);
        polygon(c, [[x + s - 0.5, t + cap * 0.4], [x + w - cap * 0.27, t], [x + w + cap * 0.03, t], [x + s - 0.5, t + cap * 0.7]]);
        polygon(c, [[x + s + cap * 0.06, t + cap * 0.52], [x + s + cap * 0.26, t + cap * 0.36], [x + w + cap * 0.05, baseline], [x + w - cap * 0.26, baseline]]);
      },
      left: x, right: x + w + cap * 0.05, top: t, bottom: baseline, width: w + cap * 0.05,
    };
  }

  function mark(cx, top, h) {
    return { path: (c) => bangShape(c, cx, top, h), left: cx - h * 0.155, right: cx + h * 0.155, top, bottom: top + h, width: h * 0.31 };
  }

  // K then the quest mark, centred, on one baseline; raised puts a smaller mark's top level with the K's.
  function kBang(ctx, o) {
    const width = letterK(ctx, o.font, o.cap, 0, o.baseline).width;
    const markWidth = o.mark * 0.31;
    const x = 32 - (width + o.gap + markWidth) / 2;
    const k = letterK(ctx, o.font, o.cap, x, o.baseline);
    const m = mark(x + width + o.gap + markWidth / 2, o.raised ? o.baseline - o.cap : o.baseline - o.mark, o.mark);
    k.colors = o.kColors;
    m.colors = o.markColors;
    emblem(ctx, [k, m], o);
  }

  // A null edge draws a bare line with no outline or shadow, thin enough to fade out at 20 px.
  function brackets(ctx, inset, len, colors = GOLD, edge = "#1b0d00", width = 2.6) {
    const far = 64 - inset;
    ctx.save();
    ctx.lineCap = "square";
    ctx.lineJoin = "miter";
    if (edge) shadow(ctx, 2, 1);
    for (const [x, y, sx, sy] of [[inset, inset, 1, 1], [far, inset, -1, 1], [inset, far, 1, -1], [far, far, -1, -1]]) {
      ctx.beginPath();
      ctx.moveTo(x, y + sy * len);
      ctx.lineTo(x, y);
      ctx.lineTo(x + sx * len, y);
      if (edge) {
        ctx.lineWidth = width + 1.9;
        ctx.strokeStyle = edge;
        ctx.stroke();
      }
      ctx.lineWidth = width;
      ctx.strokeStyle = linear(ctx, 0, y - 3, 0, y + sy * len, colors);
      ctx.stroke();
    }
    ctx.restore();
  }

  const GROUND = {
    dark(ctx) {
      ctx.fillStyle = radial(ctx, 32, 30, 4, 32, 32, 40, [[0, "#323846"], [1, "#0d0f14"]]);
      ctx.fillRect(0, 0, 64, 64);
    },
    parchment(ctx) {
      parchment(ctx, 0, 0, 64, 64, 7);
    },
    blue(ctx) {
      ctx.fillStyle = radial(ctx, 30, 26, 3, 32, 32, 44, [[0, "#2f5aa6"], [1, "#0a1430"]]);
      ctx.fillRect(0, 0, 64, 64);
    },
    black(ctx) {
      ctx.fillStyle = radial(ctx, 30, 26, 3, 32, 32, 44, [[0, "#2a2b30"], [1, "#060607"]]);
      ctx.fillRect(0, 0, 64, 64);
    },
    red(ctx) {
      ctx.fillStyle = radial(ctx, 30, 26, 3, 32, 32, 44, [[0, "#9e2129"], [1, "#2c0508"]]);
      ctx.fillRect(0, 0, 64, 64);
    },
    // The tracker's picked rows: a gold wash and a gold left edge.
    picked(ctx) {
      GROUND.dark(ctx);
      ctx.fillStyle = "rgba(255,196,64,0.14)";
      ctx.fillRect(0, 0, 64, 64);
      ctx.fillStyle = linear(ctx, 0, 4, 0, 60, [[0, "rgba(255,222,130,0.9)"], [1, "rgba(200,130,20,0.9)"]]);
      ctx.fillRect(3, 3, 3, 58);
    },
  };

  // Sélection's square: a ground, gold corners, then what they hold.
  function framed(ctx, o, content) {
    tile(ctx, () => GROUND[o.ground || "dark"](ctx), () => {
      brackets(ctx, o.inset ?? 10, o.len ?? 12, o.bracketColors, o.bracketEdge, o.bracketWidth);
      content();
    });
  }

  // The quest mark is the K's stem: arm and leg grow from its bar, the leg lands level with its dot.
  function ligature(ctx) {
    const cx = 24, top = 12, h = 40;
    const item = {
      path: (c) => {
        bangShape(c, cx, top, h);
        polygon(c, [[cx + 3.5, top + 13], [cx + 17, top], [cx + 25, top], [cx + 4, top + 21]]);
        polygon(c, [[cx + 7.5, top + 17], [cx + 12.5, top + 11.5], [cx + 26, top + h], [cx + 18, top + h]]);
      },
      left: cx - 7, right: cx + 26, top, bottom: top + h,
    };
    emblem(ctx, [item]);
  }

  const K = { font: "friz", cap: 30, mark: 30, gap: 2, baseline: 47 };

  const INKS = {
    gold: { colors: GOLD, edge: "#231100" },
    blue: { colors: [[0, "#eef7ff"], [0.3, "#8cc4ff"], [0.68, "#2f74e0"], [1, "#0e347f"]], edge: "#06122e" },
    red: { colors: [[0, "#ffe2d8"], [0.3, "#ff7a5c"], [0.68, "#d42a1e"], [1, "#6a0a06"]], edge: "#2a0303" },
    silver: { colors: SILVER, edge: "#10141a" },
  };

  // Monogramme's way: corners as thin as its rule, so at 20 px only the K! is left.
  function thin(ground, ink) {
    const { colors, edge } = INKS[ink];
    return (ctx) => framed(ctx, { ground, inset: 6, len: 11, bracketColors: colors, bracketEdge: null, bracketWidth: 1.2 },
      () => kBang(ctx, { ...K, cap: 38, mark: 38, baseline: 51, colors, edge }));
  }

  const GROUND_NAMES = { black: "Black", red: "Red", blue: "Blue" };
  const THIN = [
    ["noir-or", "Noir et or", "black", "gold"],
    ["noir-bleu", "Noir et bleu", "black", "blue"],
    ["rouge-or", "Rouge et or", "red", "gold"],
    ["rouge-bleu", "Rouge et bleu", "red", "blue"],
    ["bleu-rouge", "Bleu et rouge", "blue", "red"],
    ["noir-argent", "Noir et argent", "black", "silver"],
    ["bleu-argent", "Bleu et argent", "blue", "silver"],
  ].map(([id, name, ground, ink]) => ({
    id: "kq-" + id, name, note: `${GROUND_NAMES[ground]} ground, ${ink} K! and corners.`, draw: thin(ground, ink),
  }));

  const KBANG = [
    {
      id: "k-friz", name: "K! Friz", note: "Sélection with K!, the K in Friz Quadrata, the game's own lettering.",
      draw(ctx) { framed(ctx, {}, () => kBang(ctx, K)); },
    },
    {
      id: "k-serif", name: "K! Georgia", note: "A heavier serif K.",
      draw(ctx) { framed(ctx, {}, () => kBang(ctx, { ...K, font: "serif" })); },
    },
    {
      id: "k-taille", name: "K! taillé", note: "A K cut from straight strokes, like the quest mark. No font involved.",
      draw(ctx) { framed(ctx, {}, () => kBang(ctx, { ...K, font: "drawn", cap: 29, mark: 30 })); },
    },
    {
      id: "k-grand", name: "K! grand", note: "Smaller corners pushed to the edge, bigger letters: for the compartment's 16 px.",
      draw(ctx) { framed(ctx, { inset: 6, len: 10, bracketWidth: 2.2 }, () => kBang(ctx, { ...K, cap: 37, mark: 37, baseline: 51 })); },
    },
    {
      id: "k-argent", name: "K! argent", note: "Silver K and corners, gold quest mark: the name, then the quest.",
      draw(ctx) {
        framed(ctx, { bracketColors: SILVER, bracketEdge: "#0d1118" }, () => kBang(ctx, { ...K, kColors: SILVER, edge: "#14100c" }));
      },
    },
    {
      id: "k-parchemin", name: "K! parchemin", note: "On Parchemin's sheet, with bronze corners.",
      draw(ctx) { framed(ctx, { ground: "parchment", bracketColors: BRONZE, bracketEdge: "#2a1405" }, () => kBang(ctx, K)); },
    },
    {
      id: "k-bleu", name: "K! bleu", note: "Gold on deep blue, steel corners.",
      draw(ctx) { framed(ctx, { ground: "blue", bracketColors: STEEL, bracketEdge: "#071027" }, () => kBang(ctx, K)); },
    },
    {
      id: "k-choisi", name: "K! choisi", note: "Behind it, the tracker's own picked look: a gold wash and a gold left edge.",
      draw(ctx) { framed(ctx, { ground: "picked" }, () => kBang(ctx, K)); },
    },
    {
      id: "k-exposant", name: "K exposant", note: "A big K, the quest mark raised beside it like an exponent.",
      draw(ctx) { framed(ctx, {}, () => kBang(ctx, { ...K, cap: 34, mark: 19, gap: 1.5, baseline: 49, raised: true })); },
    },
    {
      id: "k-ligature", name: "K-!", note: "One sign: the quest mark is the K's stem.",
      draw(ctx) { framed(ctx, { inset: 9, len: 11 }, () => ligature(ctx)); },
    },
  ];

  const FIRST = [
    {
      id: "parchemin", name: "Parchemin", note: "The quest mark on a sheet of parchment: what every quest giver wears, as an icon.",
      draw(ctx) {
        tile(ctx, () => parchment(ctx, 0, 0, 64, 64, 7), () => bang(ctx, 32, 8, 48));
      },
    },
    {
      id: "journal", name: "Journal", note: "The quest log with three bookmarks: your groups, inside the journal.",
      draw(ctx) {
        ribbon(ctx, 24, 48, 61, "#b3242c");
        ribbon(ctx, 32, 48, 63, "#2b5cb5");
        ribbon(ctx, 40, 48, 60, "#2e8a3a");
        ctx.save();
        shadow(ctx, 3, 1.5);
        roundRect(ctx, 14, 8, 42, 46, 3);
        ctx.fillStyle = "#e6d6ad";
        ctx.fill();
        noShadow(ctx);
        ctx.strokeStyle = "rgba(110,80,40,0.55)";
        ctx.lineWidth = 0.7;
        for (let y = 50.5; y < 54; y += 1.4) {
          ctx.beginPath();
          ctx.moveTo(15, y);
          ctx.lineTo(55, y);
          ctx.stroke();
        }
        for (let x = 52.5; x < 56; x += 1.4) {
          ctx.beginPath();
          ctx.moveTo(x, 9);
          ctx.lineTo(x, 53);
          ctx.stroke();
        }
        roundRect(ctx, 14, 8, 42, 46, 3);
        ctx.lineWidth = 1.2;
        ctx.strokeStyle = "#2a1508";
        ctx.stroke();
        shadow(ctx, 2, 1);
        roundRect(ctx, 8, 4, 44, 47, 3.5);
        ctx.fillStyle = linear(ctx, 8, 4, 52, 51, [[0, "#8e4a24"], [0.5, "#6b3014"], [1, "#3f190a"]]);
        ctx.fill();
        noShadow(ctx);
        ctx.lineWidth = 1.4;
        ctx.strokeStyle = "#1e0b03";
        ctx.stroke();
        ctx.fillStyle = linear(ctx, 8, 0, 16, 0, [[0, "#2d1206"], [1, "#55240f"]]);
        ctx.fillRect(9, 5, 6.5, 45);
        for (const y of [11, 42]) {
          ctx.fillStyle = linear(ctx, 0, y, 0, y + 3, GOLD);
          ctx.fillRect(9, y, 6.5, 2.6);
        }
        roundRect(ctx, 19, 9, 29, 37, 2);
        ctx.lineWidth = 1;
        ctx.strokeStyle = "rgba(240,190,80,0.55)";
        ctx.stroke();
        for (const [cx, cy, sx, sy] of [[52, 4, -1, 1], [52, 51, -1, -1]]) {
          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.lineTo(cx + sx * 9, cy);
          ctx.lineTo(cx, cy + sy * 9);
          ctx.closePath();
          ctx.fillStyle = linear(ctx, cx - 9, cy, cx, cy + sy * 9, GOLD);
          ctx.fill();
          ctx.lineWidth = 1;
          ctx.strokeStyle = "#2a1400";
          ctx.stroke();
        }
        ctx.restore();
        bang(ctx, 33.5, 12, 30);
      },
    },
    {
      id: "feuillets", name: "Feuillets", note: "Three quest sheets held together: a group.",
      draw(ctx) {
        for (const [angle, dark] of [[-17, 1], [15, 1], [0, 0]]) {
          ctx.save();
          ctx.translate(32, 58);
          ctx.rotate(angle * Math.PI / 180);
          shadow(ctx, 3, 1.5);
          ctx.fillStyle = "#000";
          ctx.fillRect(-15, -52, 30, 45);
          noShadow(ctx);
          parchment(ctx, -15, -52, 30, 45, 11 + angle, dark);
          ctx.lineWidth = 1.3;
          ctx.strokeStyle = "#3a2410";
          ctx.strokeRect(-15, -52, 30, 45);
          ctx.restore();
        }
        bang(ctx, 32, 11, 33);
      },
    },
    {
      id: "banniere", name: "Bannière", note: "A banner with the quest mark: your own colours on your quests.",
      draw(ctx) {
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(15, 9);
        ctx.lineTo(49, 9);
        ctx.lineTo(49, 60);
        ctx.lineTo(32, 50);
        ctx.lineTo(15, 60);
        ctx.closePath();
        shadow(ctx, 3, 1.5);
        ctx.fillStyle = linear(ctx, 0, 9, 0, 60, [[0, "#3f6cc4"], [0.5, "#1e3a80"], [1, "#0f1f4c"]]);
        ctx.fill();
        noShadow(ctx);
        ctx.fillStyle = linear(ctx, 15, 0, 49, 0,
          [[0, "rgba(0,0,0,0.35)"], [0.2, "rgba(255,255,255,0.08)"], [0.45, "rgba(0,0,0,0.12)"], [0.75, "rgba(255,255,255,0.07)"], [1, "rgba(0,0,0,0.4)"]]);
        ctx.fill();
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = "#08102a";
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(18.5, 11);
        ctx.lineTo(45.5, 11);
        ctx.lineTo(45.5, 54);
        ctx.lineTo(32, 46);
        ctx.lineTo(18.5, 54);
        ctx.closePath();
        ctx.lineWidth = 1.6;
        ctx.strokeStyle = "#e2b443";
        ctx.stroke();
        shadow(ctx, 2, 1);
        roundRect(ctx, 9, 5, 46, 5, 2.5);
        ctx.fillStyle = linear(ctx, 0, 5, 0, 10, GOLD);
        ctx.fill();
        noShadow(ctx);
        ctx.lineWidth = 1;
        ctx.strokeStyle = "#2a1400";
        ctx.stroke();
        for (const x of [8, 56]) {
          ctx.beginPath();
          ctx.arc(x, 7.5, 3.6, 0, Math.PI * 2);
          ctx.fillStyle = radial(ctx, x - 1, 6.5, 0.5, x, 7.5, 3.6, GOLD);
          ctx.fill();
          ctx.stroke();
        }
        ctx.restore();
        bang(ctx, 32, 15, 29);
      },
    },
    {
      id: "medaillon", name: "Médaillon", note: "A round seal in gold and red, like a guild crest. Small, a red disc with ! can pass for a warning.",
      draw(ctx) {
        ctx.save();
        ctx.beginPath();
        ctx.arc(32, 32, 30, 0, Math.PI * 2);
        shadow(ctx, 3, 1.5);
        ctx.fillStyle = linear(ctx, 10, 4, 54, 60, [[0, "#ffe9a0"], [0.35, "#e2a52a"], [0.7, "#a5640c"], [1, "#5a3000"]]);
        ctx.fill();
        noShadow(ctx);
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = "#2a1400";
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(32, 32, 23, 0, Math.PI * 2);
        ctx.fillStyle = radial(ctx, 27, 25, 2, 32, 32, 24, [[0, "#b8323a"], [0.6, "#7a1219"], [1, "#3d070b"]]);
        ctx.fill();
        ctx.lineWidth = 2;
        ctx.strokeStyle = "#2a0a04";
        ctx.stroke();
        for (let i = 0; i < 8; i++) {
          const a = i * Math.PI / 4 + Math.PI / 8;
          const x = 32 + Math.cos(a) * 26.6, y = 32 + Math.sin(a) * 26.6;
          ctx.beginPath();
          ctx.arc(x, y, 1.6, 0, Math.PI * 2);
          ctx.fillStyle = "#fff0b8";
          ctx.fill();
          ctx.lineWidth = 0.8;
          ctx.strokeStyle = "#4a2800";
          ctx.stroke();
        }
        ctx.restore();
        bang(ctx, 32, 12, 39);
      },
    },
    {
      id: "suivi", name: "Suivi", note: "The tracker itself in miniature: a header, then three quests.",
      draw(ctx) {
        tile(ctx, () => {
          ctx.fillStyle = linear(ctx, 0, 0, 0, 64, [[0, "#2f384b"], [1, "#10141c"]]);
          ctx.fillRect(0, 0, 64, 64);
        }, () => {
          ctx.fillStyle = linear(ctx, 6, 0, 58, 0, [[0, "#e0aa38"], [0.6, "rgba(160,110,20,0.75)"], [1, "rgba(120,80,10,0)"]]);
          roundRect(ctx, 6, 8, 52, 10, 2);
          ctx.fill();
          ctx.fillStyle = "rgba(255,240,200,0.55)";
          ctx.fillRect(7, 8.5, 40, 1);
          [[24, 33], [37, 27], [50, 30]].forEach(([y, w]) => {
            bang(ctx, 14, y - 1, 13, { outline: 1.4 });
            roundRect(ctx, 22, y + 3, w, 5, 2.5);
            ctx.fillStyle = "rgba(236,226,200,0.9)";
            ctx.fill();
          });
        });
      },
    },
    {
      id: "sceau", name: "Sceau", note: "A wax seal stamped with the quest mark. Small, a red disc with ! can pass for a warning.",
      draw(ctx) {
        ctx.save();
        ctx.beginPath();
        for (let i = 0; i <= 96; i++) {
          const a = i / 96 * Math.PI * 2;
          const r = 27.5 + 1.5 * Math.sin(a * 9 + 0.6) + 0.9 * Math.sin(a * 5 + 2);
          const x = 32 + Math.cos(a) * r, y = 32 + Math.sin(a) * r;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        shadow(ctx, 3, 1.5);
        ctx.fillStyle = radial(ctx, 24, 21, 2, 32, 32, 31, [[0, "#e6503f"], [0.55, "#a8221a"], [1, "#5a0b07"]]);
        ctx.fill();
        noShadow(ctx);
        ctx.lineWidth = 1.2;
        ctx.strokeStyle = "#2c0503";
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(32, 32, 19.5, 0, Math.PI * 2);
        ctx.lineWidth = 2.6;
        ctx.strokeStyle = "rgba(60,0,0,0.6)";
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(32, 32, 21.2, Math.PI * 1.05, Math.PI * 1.6);
        ctx.lineWidth = 1;
        ctx.strokeStyle = "rgba(255,190,170,0.45)";
        ctx.stroke();
        ctx.restore();
        bang(ctx, 32, 14, 36);
      },
    },
    {
      id: "selection", name: "Sélection", note: "The quest mark held in a frame's corners: quests you pick and sort.",
      draw(ctx) {
        framed(ctx, {}, () => bang(ctx, 32, 12, 40));
      },
    },
    {
      id: "monogramme", name: "Monogramme", note: "KQ in gold on red: the name, for those who read icons.",
      draw(ctx) {
        tile(ctx, () => {
          ctx.fillStyle = radial(ctx, 26, 22, 3, 32, 32, 44, [[0, "#8a2229"], [1, "#2a070a"]]);
          ctx.fillRect(0, 0, 64, 64);
        }, () => {
          roundRect(ctx, 7, 7, 50, 50, 2);
          ctx.lineWidth = 1.2;
          ctx.strokeStyle = "rgba(235,185,80,0.6)";
          ctx.stroke();
          ctx.save();
          ctx.font = "bold 31px Georgia, 'Times New Roman', serif";
          ctx.textAlign = "center";
          ctx.textBaseline = "alphabetic";
          shadow(ctx, 2, 1.2);
          ctx.lineJoin = "round";
          ctx.lineWidth = 3;
          ctx.strokeStyle = "#1e0900";
          ctx.strokeText("KQ", 32, 43);
          noShadow(ctx);
          ctx.fillStyle = linear(ctx, 0, 20, 0, 44, GOLD);
          ctx.fillText("KQ", 32, 43);
          ctx.restore();
        });
      },
    },
    {
      id: "eventail", name: "Éventail", note: "Three quest marks fanned out: several quests, held as one.",
      draw(ctx) {
        for (const [angle, colors] of [[-16, DIM_GOLD], [16, DIM_GOLD], [0, GOLD]]) {
          ctx.save();
          ctx.translate(32, 86);
          ctx.rotate(angle * Math.PI / 180);
          bang(ctx, 0, -80, 44, { colors });
          ctx.restore();
        }
      },
    },
  ];

  function render(entry, size) {
    const c = document.createElement("canvas");
    c.width = c.height = size;
    const ctx = c.getContext("2d");
    ctx.scale(size / 64, size / 64);
    entry.draw(ctx);
    return c;
  }

  // What the game shows: the 64 px file, scaled down.
  function shrink(source, size) {
    const c = document.createElement("canvas");
    c.width = c.height = size;
    const ctx = c.getContext("2d");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(source, 0, 0, size, size);
    return c;
  }

  const GROUPS = [
    { title: "Thin corners, bigger K!, in seven colours: Ikar's asks on 2026-11-08", prefix: "C", list: THIN },
    { title: "Sélection with K!, Ikar's pick on 2026-11-08", prefix: "K", list: KBANG },
    { title: "First round", prefix: "", list: FIRST },
  ];
  const LIST = [...THIN, ...KBANG, ...FIRST];

  // The drawing parts, for the family's other icons (KaLi Recipe's bench draws its candidates with them).
  const parts = { tile, framed, brackets, emblem, letterK, mark, polygon, linear, radial, shadow, noShadow, GOLD, SILVER, BRONZE, INKS, K, SHINE };
  return { GROUPS, LIST, render, shrink, parts, byId: (id) => LIST.find((e) => e.id === id) };
})();
