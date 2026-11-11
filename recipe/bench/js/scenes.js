// The scenes: each draws one place in the game where the addon shows itself, with the options applied.
// ctx = { S (state), set(patch) (changes state and redraws), char (current character id) }.
// Choices Ikar made on 2026-11-09 are fixed here; what's still open is a switch (see bench.js).
(function () {
  const { h, abs, atlas, icon, itemIcon, profIcon, hover } = U;
  const S_W = 2133, S_H = 1200;
  const SKILL_BLUE = "#5555ff"; // the chat's default SKILL colour; in game, ChatTypeInfo.SKILL, so the player's own setting

  // ---------- Small pieces ----------

  const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const link = (itemId, fallback) => {
    const it = M.item(itemId);
    return it ? `<span class="q${it.quality ?? 1}">[${esc(it.name)}]</span>` : `<span class="gold">[${esc(fallback)}]</span>`;
  };
  const recipeLink = (spell) => (M.recipe(spell).item ? link(M.recipe(spell).item) : `<span class="gold">[${esc(M.recipe(spell).name)}]</span>`);

  // The recipe's required rank as quests show their level: a coloured number on Forever's nameplate level art.
  function badge(spell, c, w) {
    const r = M.recipe(spell), st = M.state(spell, c);
    const cls = st === "other" ? "gray" : M.difficulty(spell, M.rankOf(c, r.skill), st === "known");
    const b = atlas("ui-hud-nameplates-levelindicator", w || 26, 16);
    b.classList.add("lvl", cls);
    b.textContent = String(r.min);
    return b;
  }

  // Markers on a recipe, all from the game's own art: its state top left, then who holds its item along the bottom,
  // this character on the left, another character on the right. Each kind is an option.
  // Decided 2026-11-09: the objective tracker's small check for "known"; the friend icon for another character.
  const check = () => atlas("tracker-check", 16, 16);
  // Decided the same evening: the minimap's banker for "you hold it" (bags or bank alike), on a small dark disc
  // because recipe icons are beige scrolls; and a plain white eye (GM tools) on the auction house.
  const OUTLINE = "drop-shadow(0 0 1px #000) drop-shadow(0 0 1px #000) drop-shadow(0 0 0.5px #000)";
  const held = () => h("span.held", {}, atlas("banker", 16, 16, { filter: OUTLINE }));
  const eye = () => atlas("gm-icon-visible", 18, 18, { filter: OUTLINE });

  // An item a recipe makes: the profession's small icon (the world quest pins'), top left, the corner that says what an
  // item means for your professions. Bright when this character can make it; dimmed when only another character can,
  // or a recipe was only seen (an option). Asked by Ikar, 2026-11-09.
  const PROF_ICON = { 171: "alchemy", 164: "blacksmithing", 185: "cooking", 333: "enchanting", 202: "engineering", 129: "firstaid", 356: "fishing", 182: "herbalism", 165: "leatherworking", 186: "mining", 393: "skinning", 197: "tailoring" };
  function crafted(itemId, c, S) {
    if (!S.mCraft) return [];
    const made = M.madeBy(itemId).filter((x) => x.who.length || S.mCraftSeen);
    if (!made.length) return [];
    const best = made.find((x) => x.who.some((w) => w.id === c)) || made.find((x) => x.who.length) || made[0];
    const mine = best.who.some((w) => w.id === c);
    const el = h("span.held.craft" + (mine ? "" : ".dim"), {}, atlas(`worldquest-icon-${PROF_ICON[M.recipe(best.spell).skill]}`, 18, 14, { filter: OUTLINE }));
    return [abs(h("span.mk", {}, el), -1, -1)];
  }

  function markers(spell, c, S, mode) {
    const st = M.state(spell, c), pos = M.possession(spell, c);
    let top = null;
    if (st === "known" && S.mKnown) top = check();
    else if (st === "learnable" && S.mLearnable) top = badge(spell, c, 24);
    else if (st === "toolow" && S.mTooLow) top = badge(spell, c, 24);
    const mine = pos && pos.mine && S.mOwned ? held() : null;
    const alt = pos && pos.alts.length && S.mAlt ? atlas("groupfinder-icon-friend", 16, 16) : null;
    if (mode === "inline") return [top, mine, alt].filter(Boolean);
    // On an item slot (37 by 37), inside it: state top left, yours bottom left, another character's bottom right.
    const out = [];
    if (top) out.push(abs(h("span.mk", {}, top), -2, -2));
    if (mine) out.push(abs(h("span.mk", {}, mine), 1, 19));
    if (alt) out.push(abs(h("span.mk", {}, alt), 21, 20));
    return out;
  }

  // ---------- Tooltips ----------

  // A recipe's tooltip: the game's lines for its item (or the trainer's), then the addon's.
  function recipeTip(itemId, spell, ctx) {
    const { S } = ctx, c = ctx.char, r = M.recipe(spell), it = M.item(itemId) || null;
    const prof = M.prof(r.skill).name, rank = M.rankOf(c, r.skill);
    const ok = M.hasProf(c, r.skill) && rank >= r.min;
    const lines = [{ l: esc(it ? it.name : r.name), cls: it ? "q" + (it.quality ?? 1) : "white", h: true }];
    lines.push({ l: `${prof} (${r.min}) requis${r.minEstimated && !it ? " · estimé dans le banc" : ""}`, cls: ok ? "white" : "red" });
    if (it && M.isKnown(spell, c)) lines.push({ l: "Déjà connu", cls: "red" });
    if (it) lines.push({ l: `Utiliser : Vous apprend à fabriquer « ${esc(r.name)} ».`, cls: "green", wrap: true });
    if (r.reagents.length) {
      lines.push({ sp: true });
      lines.push({ l: "Composants : " + r.reagents.map(([i, n]) => esc((M.item(i) || {}).name) + (n > 1 ? ` (${n})` : "")).join(", "), cls: "white", wrap: true });
    }
    if (it && it.sell) lines.push({ l: "Prix de vente : " + M.money(it.sell), cls: "white" });
    return lines.concat(addonRecipeLines(spell, ctx));
  }

  function addonRecipeLines(spell, ctx) {
    const { S } = ctx, c = ctx.char, r = M.recipe(spell);
    if (S.b4 === "off") return [];
    // The addon's lines in the light blue the game gives « Composant d’artisanat »: blue, the crafting colour (decided).
    const col = "addon", head = "addon";
    const others = M.knowers(spell).filter((k) => k.id !== c), mine = M.isKnown(spell, c);
    const pos = M.possession(spell, c), seen = M.sightingsOf(spell);
    const out = [{ sp: true }];
    if (S.b4 === "compact") {
      const bits = [mine ? "connue" : others.length ? `connue de ${others.map((k) => k.name).join(", ")}` : "inconnue"];
      if (seen.length) bits.push(`vue ${seen.length} fois`);
      if (pos && pos.mine) bits.push("sur vous");
      if (pos && pos.alts.length) bits.push(`sur ${pos.alts.map((a) => a.c.name).join(", ")}`);
      out.push({ l: "Carnet : " + bits.join(" · "), cls: head });
      return out;
    }
    out.push({ l: "Carnet", cls: head });
    if (!mine) out.push({ l: others.length ? "Connue de " + others.map((k) => `${k.name} (${M.prof(r.skill).name} ${M.rankOf(k.id, r.skill)})`).join(", ") : "Inconnue de vos personnages", cls: col, wrap: true });
    // Where the item is, bags and bank alike; no price: Auctionator and the like add theirs to the item tooltip.
    const place = (hh) => [hh.bags ? "sacs" : "", hh.bank ? "banque" : ""].filter(Boolean).join(" et ");
    if (pos && pos.mine) out.push({ l: `Vous en avez ${pos.mine.total} (${place(pos.mine)})`, cls: col });
    if (pos) pos.alts.forEach((a) => out.push({ l: `${a.c.name} en a ${a.h.total} (${place(a.h)})`, cls: col }));
    seen.slice(0, 4).forEach((s) => out.push({ l: whereLine(s), cls: col, wrap: true }));
    if (seen.length > 4) out.push({ l: `… et ${seen.length - 4} autres`, cls: "gray" });
    return out;
  }

  function whereLine(s) {
    const n = M.npc(s.npc) || {}, z = M.zone(s.zone);
    if (s.kind === "vendor") return `Vendue par ${esc(n.name)}, ${z}`;
    if (s.kind === "trainer") return `Enseignée par ${esc(n.name)}, ${z}`;
    if (s.kind === "drop") return `Butin de ${esc(s.from_name || n.name)}, ${z}`;
    return `Hôtel des ventes, le ${M.date(s.date)}`;
  }

  // A material's tooltip, then « Utilisé dans » by profession, as a list.
  function materialTip(itemId, ctx) {
    const { S } = ctx, it = M.item(itemId) || {}, c = ctx.char;
    const lines = [{ l: esc(it.name), cls: "q" + (it.quality ?? 1), h: true }, ...(it.class === 7 ? [{ l: "Composant d’artisanat", cls: "addon" }] : [])];
    if (it.sell) lines.push({ l: "Prix de vente : " + M.money(it.sell), cls: "white" });
    const made = M.madeBy(itemId);
    if (S.mCraft && made.length) {
      const hd = "addon";
      lines.push({ sp: true }, { l: "Fabriqué par :", cls: hd });
      for (const x of made) {
        const r = M.recipe(x.spell), s0 = M.sightingsOf(x.spell)[0];
        lines.push({ l: `  ${M.prof(r.skill).name} · ${esc(r.name)}`, r: x.who.length ? x.who.map((w) => w.name).join(", ") : (s0 ? whereLine(s0).replace(/^(Vendue|Enseignée) par /, "") : "vue"), cls: x.who.length ? "white" : "gray", rcls: "gray" });
      }
    }
    if (!S.c1) return lines;
    const u = M.usedIn(itemId);
    const rows = u.known.map((k) => ({ spell: k.spell, who: k.who })).concat(S.c1Seen ? u.seen.map((k) => ({ spell: k.spell, seen: true })) : []);
    if (!rows.length) return lines;
    const head = "addon";
    lines.push({ sp: true }, { l: "Utilisé dans :", cls: head });
    const by = {};
    for (const r of rows) (by[M.recipe(r.spell).skill] = by[M.recipe(r.spell).skill] || []).push(r);
    // The character's own professions first.
    const order = Object.keys(by).sort((a, b) => (M.hasProf(c, b) - M.hasProf(c, a)) || M.prof(a).name.localeCompare(M.prof(b).name, "fr"));
    let shown = 0;
    for (const skill of order) {
      if (shown >= S.c1Max) break;
      lines.push({ l: M.prof(skill).name, cls: "gold" });
      for (const r of by[skill]) {
        if (shown >= S.c1Max) break;
        const rec = M.recipe(r.spell);
        const mine = r.who && r.who.some((w) => w.id === c);
        const right = r.seen ? "vue" : mine ? "" : r.who.map((w) => w.name).join(", ");
        lines.push({ l: "  " + esc(rec.name), r: right, cls: r.seen ? "gray" : "white", rcls: "gray" });
        shown++;
      }
    }
    if (rows.length > shown) lines.push({ l: `… et ${rows.length - shown} autres`, cls: "gray" });
    return lines;
  }

  // ---------- Frames ----------

  function frame(x, y, w, hgt, title, opts) {
    const f = abs(h("div.frame" + (opts && opts.cls ? "." + opts.cls : "")), x, y, w, hgt);
    f.append(h("div.titlebar", {}, title));
    f.append(h("div.close", { onclick: opts && opts.onclose }, "×"));
    // The addon's options gear beside the close button (the notebook's, Ikar 2026-11-10): Blizzard's own settings gear.
    if (opts && opts.gear) f.append(hover(h("span.gear", { onclick: opts.gear }, atlas("questlog-icon-setting", 15, 16)), () => [{ l: "Options de KaLi Recipe", cls: "white" }], "right"));
    if (opts && opts.portrait) {
      const p = h("div.portrait");
      if (opts.portrait.fdid) p.style.backgroundImage = `url(${M.iconUrl(opts.portrait.fdid)})`;
      f.append(p);
    }
    return f;
  }

  // The chat frame, over the screenshot's own: a game line or two for context, then the addon's, in SKILL blue.
  function chat(stage, ctx, lines) {
    if (!ctx.S.chat || !lines.length) return;
    const box = abs(h("div.chatbox"), 24, 860, 680, 214);
    const all = [
      { t: "Votre compétence en Cuisine est maintenant de 56.", c: SKILL_BLUE },
      { t: "[1. Général - Darnassus] Lyssia : quelqu’un pour les grottes de la Lune ?", c: "#ffc0c0" },
      ...lines.map((t) => (typeof t === "string" ? { t, c: SKILL_BLUE } : t)),
    ];
    for (const ln of all.slice(-9)) box.append(h("div", { style: { color: ln.c }, html: ln.t }));
    stage.append(box);
  }

  // Decided: one line per visit, whatever the number of recipes noted.
  function chatForSightings(ctx, sightings, where) {
    const c = ctx.char;
    const fresh = sightings.filter((s) => !M.isKnown(s.recipe, c));
    if (!fresh.length) return [];
    const names = fresh.slice(0, 3).map((s) => recipeLink(s.recipe)).join(", ") + (fresh.length > 3 ? ` et ${fresh.length - 3} autre${fresh.length > 4 ? "s" : ""}` : "");
    return [`Carnet : ${fresh.length} recette${fresh.length > 1 ? "s" : ""} notée${fresh.length > 1 ? "s" : ""} ${where} : ${names}.`];
  }

  // The count line « Carnet : 11 », under the rank bar and in the professions book. Click opens the notebook there.
  // « Carnet : 7 à apprendre · 4 vues » (Ikar, 2026-11-09: two separate numbers). Click opens the notebook there.
  const twoCounts = (c, skill) => {
    const n = M.split(c, skill), a = n.learn.length, v = n.seen.length;
    return { a, v, html: M.hasProf(c, skill) ? `<span class="n">${a}</span> à apprendre · <span class="n">${v}</span> vue${v > 1 ? "s" : ""}` : `<span class="n">${v}</span> vue${v > 1 ? "s" : ""}` };
  };
  function countLine(ctx, skill, x, y, w) {
    const { S } = ctx, t = twoCounts(ctx.char, skill);
    if (!t.a && !t.v && !S.showZero) return null;
    const el = abs(h("div.nb-line.link.gray", { html: `Carnet : ${t.html}`, onclick: () => openNotebook(ctx, skill) }), x, y, w);
    if (w) el.style.textAlign = "center";
    return hover(el, () => [
      { l: "Carnet de recettes", cls: "white", h: true },
      { l: `${t.a} recette${t.a > 1 ? "s" : ""} de ${M.prof(skill).name} à apprendre à votre rang.`, cls: "lgray", wrap: true },
      { l: `${t.v} vue${t.v > 1 ? "s" : ""} dont le rang requis est plus haut.`, cls: "lgray", wrap: true },
      { sp: true }, { l: "Clic : ouvrir le carnet", cls: "green" },
    ], "below");
  }
  const openNotebook = (ctx, skill) => ctx.set({ nbOpen: true, nbSkill: String(skill || ctx.S.nbSkill) });

  // ---------- The notebook (notebook.js), over any scene ----------

  // `dock` ({x, y}): « Suivre » hangs the notebook on the professions window, which it then moves with.
  function overlays(ctx, stage, x, dock) {
    if (ctx.S.nbOpen || dock) stage.append(NOTEBOOK.draw(ctx, dock ? dock.x : x, dock ? dock.y : 80, { docked: !!dock }).el);
  }

  // ---------- Scenes ----------

  function professions(ctx, stage) {
    const { S } = ctx, c = ctx.char, ch = M.chars[c];
    const mine = M.profsOf(c);
    const skill = mine.includes(S.profSkill) ? S.profSkill : mine[0];
    const rank = ch.profs[skill];
    // Where the player dragged it (its title bar, in the bench); Blizzard's default spot otherwise.
    const W = 673, H = 594, X = S.profX ?? 48, Y = S.profY ?? 100;
    const f = frame(X, Y, W, H, M.prof(skill).name, { cls: "prof", portrait: { fdid: M.prof(skill).icon } });
    f.append(h("div.rankbar", {}, h("div.fill", { style: { width: (rank / 75 * 100) + "%" } }), h("div.txt", {}, `${M.prof(skill).name} : ${rank}/75`)));
    if (S.a1) { const l = countLine(ctx, skill, 106, 52, W - 212); if (l) f.append(l); }
    f.append(abs(h("div.search", {}, "Recherche"), 14, 74, 170), abs(h("div.btn", {}, "Filtrer ▸"), 190, 73));
    const list = h("div.inset.list");
    // The game's categories (TradeSkillCategory), in its order.
    const known = [...ch.known].filter((sp) => String(M.recipe(sp).skill) === String(skill));
    let first = null;
    for (const g of M.byCategory(known)) {
      list.append(h("div.cat", {}, g.name, h("span.tog", {}, "–")));
      for (const sp of g.spells) { first = first || sp; list.append(h("div", { class: "rec " + M.difficulty(sp, rank, true) + (sp === first ? " sel" : "") }, M.recipe(sp).name)); }
    }
    f.append(list);
    const det = h("div.inset.detail");
    if (first) {
      const r = M.recipe(first);
      det.append(abs(r.makes ? itemIcon(r.makes, 40) : profIcon(skill, 40), 14, 14), abs(h("div.fs14.white", {}, r.makes ? M.item(r.makes).name : r.name), 64, 16), abs(h("div.fs11", { html: `<span class="gold">Catégorie :</span> <span class="white">${M.category(first).name}</span>` }), 64, 36));
      det.append(abs(h("div.fs11.gold", {}, "Composants :"), 14, 76));
      r.reagents.forEach(([i, cnt], k) => {
        const have = M.holds(c, i).total;
        det.append(hover(abs(h("div", { style: { display: "flex", gap: "6px", alignItems: "center" } }, itemIcon(i, 30), h("span", { class: "fs11 " + (have >= cnt ? "white" : "gray") }, `${have} / ${cnt} ${M.item(i).name}`)), 14, 96 + k * 36, 330), () => materialTip(i, ctx), "right"));
      });
    }
    f.append(det, abs(h("div.btn.off", {}, "Tout créer"), 300, H - 34), abs(h("div.btn.off", {}, "Créer"), W - 110, H - 34));
    stage.append(f);
    const tabs = abs(h("div.tabstrip"), X + W + 4, Y);
    for (const k of mine) tabs.append(h("div.tab" + (k === skill ? ".on" : ""), { style: { backgroundImage: `url(${M.iconUrl(M.prof(k).icon)})`, cursor: "pointer" }, onclick: () => ctx.set({ profSkill: k, nbFollowClosed: "" }) }));
    stage.append(tabs);
    // « Suivre » (one switch): the notebook opens with the professions window, on the profession open there.
    const follows = !!S.follow && S.nbFollowClosed !== skill;
    if (follows) { S.nbSkill = skill; S.nbOpen = true; }
    // Docked: against the window's right, past its profession tabs; on its left when the screen runs out.
    // In game: SetPoint on the notebook only, relative to ProfessionsFrame (nothing written to Blizzard's frame).
    const nbw = NOTEBOOK.size(S).W + 40, right = X + W + 52;
    overlays(ctx, stage, right, follows && { x: right + nbw <= S_W ? right : X - nbw - 8, y: Y });
    // Drag the title bar: the window moves, and a docked notebook with it.
    const bar = f.querySelector(".titlebar");
    bar.style.cursor = "move";
    bar.addEventListener("mousedown", (e) => {
      e.preventDefault(); U.untip();
      const sc = f.getBoundingClientRect().width / f.offsetWidth, x0 = e.clientX, y0 = e.clientY;
      const els = [f, tabs, stage.querySelector(".nbframe.docked")].filter(Boolean).map((el) => [el, parseFloat(el.style.left), parseFloat(el.style.top)]);
      let dx = 0, dy = 0;
      const move = (ev) => { dx = (ev.clientX - x0) / sc; dy = (ev.clientY - y0) / sc; for (const [el, l, t] of els) Object.assign(el.style, { left: l + dx + "px", top: t + dy + "px" }); };
      const up = () => {
        removeEventListener("mousemove", move); removeEventListener("mouseup", up);
        ctx.set({ profX: Math.round(Math.max(0, Math.min(S_W - W, X + dx))), profY: Math.round(Math.max(0, Math.min(S_H - H, Y + dy))) });
      };
      addEventListener("mousemove", move); addEventListener("mouseup", up);
    });
    return follows ? `Professions window: ${M.prof(skill).name} ${rank}/75. « Suivre » is on: the notebook hangs on the window, on ${M.prof(skill).name}. Drag the window's title bar: the notebook moves with it. Switch profession and it follows.`
      : `Professions window: ${M.prof(skill).name} ${rank}/75. « Carnet : N » under the rank bar opens the notebook at this profession.`;
  }

  function pbook(ctx, stage) {
    const { S } = ctx, c = ctx.char, ch = M.chars[c];
    const X = 48, Y = 100, W = 540, H = 520;
    const mine = M.profsOf(c);
    const f = frame(X, Y, W, H, "Métiers", { cls: "pbook", portrait: { fdid: M.prof(mine[0]).icon } });
    const RANKS = (r) => (r < 75 ? "Apprenti" : r < 150 ? "Compagnon" : r < 225 ? "Expert" : "Artisan");
    mine.forEach((k, i) => {
      const r = ch.profs[k];
      const card = abs(h("div.card"), 20, 44 + i * 150, W - 40, 120);
      const col = h("div", {}, h("div.fs16.gold", {}, M.prof(k).name), h("div.fs11.lgray", {}, RANKS(r)),
        h("div.bar", {}, h("div.fill", { style: { width: (r / 75 * 100) + "%" } }), h("div.txt", {}, `${r}/75`)));
      if (S.a2) { const t = twoCounts(c, k); if (t.a || t.v || S.showZero) col.append(h("div.fs11.gray.link", { style: { marginTop: "8px" }, html: `Carnet : ${t.html}`.replace(/class="n"/g, 'class="white"'), onclick: () => openNotebook(ctx, k) })); }
      card.append(profIcon(k, 56), col);
      f.append(card);
    });
    if (S.a2) { const o = M.countOther(c); if (o || S.showZero) f.append(abs(h("div.fs11.gray.link", { html: `Autres métiers, carnet : <span class="white">${o}</span> vue${o > 1 ? "s" : ""}`, onclick: () => openNotebook(ctx, Object.keys(M.unknownSeen(c)).find((k) => !M.hasProf(c, k))) }), 30, H - 40)); }
    stage.append(f);
    overlays(ctx, stage, X + W + 30);
    return "Professions book (approximated): A2, « Carnet : N » under each profession, and one line for the others.";
  }

  function merchant(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const vendors = M.vendors();
    const v = vendors.find((s) => String(s.npc) === String(S.vendor)) || vendors[0];
    const n = M.npc(v.npc);
    const X = 48, Y = 100, W = 336, H = 444;
    const f = frame(X, Y, W, H, n.name, { cls: "merchant" });
    f.append(abs(h("div.fs11.lgray", { style: { textAlign: "center" } }, `<${n.title}>`), 0, 30, W));
    const grid = h("div.items");
    for (const e of M.shelf(v.npc).slice(0, 10)) {
      const it = M.item(e.item) || {};
      const slot = h("div.slot", { style: { backgroundImage: `url(${M.iconUrl(it.icon)})` } });
      const row = h("div.mitem", {}, slot, h("div", {}, h("div", { class: "nm q" + (it.quality ?? 1) }, it.name), h("div.pr.white", { html: M.money(it.buy || 0) })));
      if (e.recipe) {
        const r = M.recipe(e.recipe);
        if (!M.hasProf(c, r.skill) || M.rankOf(c, r.skill) < r.min) row.classList.add("unusable");
        slot.append(...markers(e.recipe, c, S));
        hover(row, () => recipeTip(e.item, e.recipe, ctx), "right");
      } else hover(row, () => materialTip(e.item, ctx), "right");
      grid.append(row);
    }
    f.append(grid, h("div.footer", {}, abs(h("div.fs11.lgray", {}, "Page 1 de 1"), 4, 6), abs(h("div.fs12.white", { html: M.money(58023) }), W - 120, 6)));
    stage.append(f);
    if (v.npc === "showcase") {
      stage.append(legend(ctx, M.shelf("showcase"), X + W + 24, Y));
      overlays(ctx, stage, X + W + 460);
      return `The bench's showcase vendor, invented: one real recipe per marker case for ${M.chars[c].name}. The legend on its right is the bench's, not the game's.`;
    }
    chat(stage, ctx, chatForSightings(ctx, M.D.sightings.filter((s) => s.kind === "vendor" && s.npc === v.npc), `chez ${esc(n.name)} (${M.zone(v.zone)})`));
    overlays(ctx, stage, X + W + 30);
    return `Vendor ${n.name}, ${M.zone(v.zone)}: real recipe items (QuestieDB), supplies invented. Spotting goes to the chat, in the SKILL blue.`;
  }

  // The bench's own legend for the showcase (not game UI): what each slot shows for the current character, and why.
  function legend(ctx, shelf, x, y) {
    const { S } = ctx, c = ctx.char;
    const COLOUR = { "d-optimal": "orange", "d-medium": "yellow", "d-easy": "green", "d-trivial": "gray" };
    const box = abs(h("div.bench-legend"), x, y, 420);
    box.append(h("div.lh", {}, `What each slot shows for ${M.chars[c].name}`));
    shelf.forEach((e, i) => {
      const r = M.recipe(e.recipe), st = M.state(e.recipe, c), pos = M.possession(e.recipe, c);
      const what = st === "known" ? (S.mKnown ? "known → check" : "known → (known marker off)")
        : st === "learnable" ? `learnable now, ${COLOUR[M.difficulty(e.recipe, M.rankOf(c, r.skill))]} → rank badge`
        : st === "toolow" ? `needs ${r.min}, rank too low → red rank badge`
        : "another profession → no state marker";
      const who = [pos && pos.mine ? ` + in your ${[pos.mine.bags ? "bags" : "", pos.mine.bank ? "bank" : ""].filter(Boolean).join(" and ")} → sack, bottom left` : "",
        pos && pos.alts.length ? ` + ${pos.alts.map((x) => x.c.name).join(", ")} holds one → friend, bottom right` : ""].join("");
      box.append(h("div.li", {}, h("span.n", {}, String(i + 1)), h("span", {}, h("b", {}, (M.item(e.item) || {}).name), h("br"), what + who)));
    });
    box.append(h("div.lf", {}, "Slots are numbered left to right, top to bottom. Switch the character to see Elorah's side."));
    return box;
  }

  function trainer(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const t = M.trainers().find((s) => String(s.npc) === String(S.trainer)) || M.trainers()[0];
    const n = M.npc(t.npc), skill = M.trainerSkill(t.npc);
    const has = M.hasProf(c, skill), rank = M.rankOf(c, skill);
    const X = 48, Y = 100, W = 384, H = 512;
    const f = frame(X, Y, W, H, n.name, { cls: "trainer", portrait: { fdid: M.prof(skill).icon } });
    f.append(abs(h("div.fs11.lgray", { style: { textAlign: "center" } }, `<${n.title}>`), 0, 30, W));
    f.append(abs(h("div.fs11", { style: { textAlign: "center" }, html: has ? `<span class="gold">${M.prof(skill).name} :</span> ${rank}/75` : `<span class="red">Vous n’avez pas appris ce métier.</span>` }), 0, 44, W));
    const list = h("div.inset.tlist");
    const spells = M.trainerList(t.npc);
    for (const [label, test, cls] of [["Disp.", (sp) => M.state(sp, c) === "learnable", "green"], ["Indisp.", (sp) => ["toolow", "other"].includes(M.state(sp, c)), "red"], ["Déjà connu", (sp) => M.state(sp, c) === "known", "gray"]]) {
      const g = spells.filter(test);
      if (!g.length) continue;
      list.append(h("div.trow.gold", {}, label));
      for (const sp of g) {
        const mk = markers(sp, c, { ...S, mKnown: false }, "inline");
        const row = h("div", { class: "trow " + cls, style: { paddingLeft: "6px", gap: "6px" } }, h("span", { style: { width: "26px", display: "inline-flex" } }, ...mk), M.recipe(sp).name);
        hover(row, () => recipeTip(null, sp, ctx), "right");
        list.append(row);
      }
    }
    f.append(list, h("div.inset.tdetail", {}, h("div.fs12.gold", {}, "Coût : ", h("span", { html: M.money(250) }))), abs(h("div.btn" + (has ? "" : ".off"), {}, "Apprendre"), W - 120, H - 34));
    stage.append(f);
    chat(stage, ctx, chatForSightings(ctx, M.D.sightings.filter((s) => s.kind === "trainer" && s.npc === t.npc), `chez ${esc(n.name)} (${esc(n.title)})`));
    overlays(ctx, stage, X + W + 30);
    return `Trainer ${n.name}: the profession's real trainer recipes up to rank 100; required ranks are estimates.`;
  }

  function ah(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const X = 48, Y = 100, W = 820, H = 538;
    const f = frame(X, Y, W, H, "Hôtel des ventes", { cls: "ah" });
    f.append(abs(h("div.search", {}, "Recettes"), 200, 34, 300), abs(h("div.btn", {}, "Rechercher"), 510, 33));
    const cats = h("div.inset.cats");
    ["Armes", "Armures", "Conteneurs", "Consommables", "Artisanat", "Recettes", "· Travail du cuir", "· Couture", "· Ingénierie", "· Forge", "· Cuisine", "· Alchimie", "· Secourisme", "· Enchantement", "Divers"].forEach((t) =>
      cats.append(h("div", { class: t.startsWith("·") ? "lgray fs11" : t === "Recettes" ? "on" : "gold" }, t)));
    f.append(cats, h("div.hdr", {}, h("span", { style: { width: "380px", paddingLeft: "40px" } }, "Nom"), h("span", { style: { width: "70px" } }, "Niv."), h("span", { style: { width: "90px" } }, "Disponible"), h("span", { style: { marginLeft: "auto" } }, "Prix unitaire")));
    const rows = h("div.rows");
    for (const l of M.D.ah.listings) {
      const it = M.item(l.item) || {};
      // The eye: a recipe this account saw at a vendor, so it needn't be bought here (unless this character knows it).
      const atVendor = S.mVendor && !M.isKnown(l.recipe, c) && M.vendorSightings(l.recipe).length ? eye() : null;
      const ic = h("span", { style: { position: "relative", display: "inline-flex" } }, U.icon(it.icon, 24));
      const row = h("div.arow", {}, h("span", { style: { width: "380px", display: "flex", gap: "8px", alignItems: "center" } }, ic, h("span", { class: "q" + (it.quality ?? 1) }, it.name), ...markers(l.recipe, c, S, "inline"), atVendor),
        h("span.white", { style: { width: "70px" } }, String(M.recipe(l.recipe).min)), h("span.white", { style: { width: "90px" } }, String(l.qty)),
        h("span", { style: { marginLeft: "auto" }, class: "white", html: M.money(l.price) }));
      hover(row, () => recipeTip(l.item, l.recipe, ctx), "right");
      rows.append(row);
    }
    f.append(rows);
    stage.append(f);
    const lines = chatForSightings(ctx, M.D.sightings.filter((s) => s.kind === "ah"), "à l’hôtel des ventes");
    chat(stage, ctx, lines);
    overlays(ctx, stage, X + W + 20);
    return "Auction house (approximated): one query on the Recipes page when it opens notes what it lists. No prices are kept: Auctionator and the like add theirs to the recipe's item tooltip. The eye: also sold by a vendor seen before.";
  }

  function bags(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const H_ = D_h();
    const items = Object.keys(H_.bags).map(Number).concat(Object.keys(H_.bank).map(Number));
    const X = S_W - 560, Y = 420, W = 192, H = 32 + Math.ceil(items.length / 4) * 42 + 30;
    const f = frame(X, Y, W, H, "Sac à dos", { cls: "bag" });
    const grid = h("div.grid");
    for (const id of items) {
      const it = M.item(id) || {}, n = M.holds(c, id).total;
      const slot = h("div.slot", { style: { backgroundImage: `url(${M.iconUrl(it.icon)})` } }, it.class === 9 ? null : h("span.count", {}, String(n)));
      const rec = Object.entries(M.D.recipes).find(([, r]) => r.item === id);
      // In your own bags, "you hold it" says nothing: only the state and another character's copy.
      if (rec) slot.append(...markers(rec[0], c, { ...S, mOwned: false }));
      else slot.append(...crafted(id, c, S));
      hover(slot, () => (rec ? recipeTip(id, rec[0], ctx) : materialTip(id, ctx)), "left");
      grid.append(slot);
    }
    f.append(grid, abs(h("div.fs11.white", { html: M.money(84213) }), 10, H - 24));
    stage.append(f);
    const looted = M.D.sightings.filter((s) => s.kind === "drop" && M.holds(c, s.item).total);
    // The game's loot line (LOOT_ITEM_SELF, in the chat's loot green), then the addon's.
    chat(stage, ctx, looted.flatMap((s) => [{ t: `Vous recevez le butin : ${link(s.item)}.`, c: "#00aa00" }, `Carnet : ${recipeLink(s.recipe)} notée, butin de ${esc(s.from_name)} (${M.zone(s.zone)}).`]));
    overlays(ctx, stage, 760);
    return `${M.chars[c].name}'s bags: hover a material for « Utilisé dans », or a recipe for its markers and lines. Contents invented.`;
    function D_h() { return (M.D.holdings[c] || { bags: {}, bank: {} }); }
  }

  function map(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const zone = M.D.maps[S.mapZone] ? S.mapZone : "1657";
    const mp = M.D.maps[zone];
    const MW = 1002, MH = 668, W = MW + 12, H = MH + 36;
    const X = Math.round((S_W - W) / 2), Y = 70;
    const f = frame(X, Y, W, H, mp.name, { cls: "mapf" });
    const canvas = abs(h("div.canvas"), 6, 28, MW, MH);
    const tiles = h("div.tiles");
    for (const [row, col, fdid] of mp.tiles) tiles.append(abs(h("img", { src: `art/map/${fdid}.png` }), col * 256, row * 256));
    canvas.append(tiles);
    if (S.d4) {
      const spots = new Map();
      for (const s of M.D.sightings) {
        if (String(s.zone) !== zone || s.kind === "ah" || s.x == null || M.isKnown(s.recipe, c)) continue;
        const k = s.npc + ":" + s.kind;
        if (!spots.has(k)) spots.set(k, { s, recipes: [] });
        spots.get(k).recipes.push(s.recipe);
      }
      for (const { s, recipes } of spots.values()) {
        const n = M.npc(s.npc) || {};
        const w = abs(h("div.pinw", {}, atlas(s.kind === "trainer" ? "profession" : "poi-workorders", 22, 22)), s.x / 100 * MW, s.y / 100 * MH);
        hover(w, () => [{ l: esc(n.name), cls: "white", h: true }, { l: esc(`<${n.title}>`), cls: "lgray" }, { sp: true },
          { l: `Carnet : ${recipes.length} recette${recipes.length > 1 ? "s" : ""} pas encore apprise${recipes.length > 1 ? "s" : ""}`, cls: "addon" },
          ...recipes.slice(0, 8).map((sp) => ({ l: "  " + esc(M.recipe(sp).name), r: String(M.recipe(sp).min), cls: "white", rcls: M.difficulty(sp, M.rankOf(c, M.recipe(sp).skill)) })),
          ...(recipes.length > 8 ? [{ l: `… et ${recipes.length - 8} autres`, cls: "gray" }] : []), { sp: true }, { l: "Clic : placer un repère", cls: "green" }], "right");
        w.onclick = () => ctx.set({ waypoint: { x: s.x, y: s.y, zone, npc: s.npc } });
        canvas.append(w);
      }
    }
    if (S.waypoint && S.waypoint.zone === zone) canvas.append(abs(h("div.pinw", { style: { pointerEvents: "none" } }, atlas("waypoint-mappin-tracked", 34, 34)), S.waypoint.x / 100 * MW, S.waypoint.y / 100 * MH - 14));
    f.append(canvas, abs(h("div.btn", { onclick: () => ctx.set({ mapMenu: !S.mapMenu }), style: { cursor: "pointer" } }, "Filtre ▾"), W - 100, 34));
    if (S.mapMenu) {
      const menu = abs(h("div.menu"), W - 240, 60);
      const item = (label, on, onclick) => h("div.it", { onclick, style: { cursor: onclick ? "pointer" : "default" } }, h("span.box", {}, on ? "✓" : ""), label);
      menu.append(h("div.hd", {}, "Afficher :"), item("Quêtes", true), item("Objectifs de suivi", true), item(h("span.addon", {}, "Recettes croisées (Carnet)"), S.d4, () => ctx.set({ d4: !S.d4 })));
      f.append(menu);
    }
    f.append(abs(h("div.fs11.lgray", {}, `Carte réelle de ${mp.name} (tuiles de ce build). Positions des PNJ : QuestieDB.`), 14, H - 2));
    stage.append(f);
    return `World map of ${mp.name}: D4, a pin in the game's own icons where this character saw recipes it doesn't know.`;
  }

  function notebook(ctx, stage) {
    ctx.S.nbOpen = true;
    overlays(ctx, stage, 380);
    const st = NOTEBOOK.STYLES[ctx.S.nbStyle] || NOTEBOOK.STYLES.clean;
    return `The notebook, ${st.label} style (« ${st.fr} » in the options): learnable now, seen, then « Appris » (collapsed), by the game's categories. Header: the hammer opens the professions window, « Suivre » follows it. Left click a recipe: its detail below the list (click again or × to close); right click: the actions. Size: Notebook in the panel.`;
  }

  function compartment(ctx, stage) {
    const { S } = ctx, c = ctx.char;
    const bx = S_W - 182, by = 22;
    stage.append(abs(h("div.compartment-btn"), bx, by));
    stage.lastChild.textContent = "8";
    const menu = abs(h("div.menu", { style: { minWidth: "230px" } }), bx - 220, by + 26);
    const entry = (label, fdid, opts) => {
      const el = h("div.it", { style: { height: "24px" } }, U.icon(fdid, 18), h("span", { html: label }));
      if (opts && opts.tip) hover(el, opts.tip, "left");
      if (opts && opts.onclick) { el.style.cursor = "pointer"; el.onclick = opts.onclick; }
      return el;
    };
    const profs = M.profsOf(c);
    menu.append(entry("Auctionator", M.prof("164").icon), entry("KaLi Quest", M.prof("185").icon), entry("Pagle", M.prof("356").icon),
      entry("Carnet de recettes", M.prof("333").icon, {
        onclick: () => openNotebook(ctx, profs[0]),
        tip: () => [{ l: "Carnet de recettes", cls: "white", h: true }, ...profs.map((k) => ({ l: M.prof(k).name, r: twoCounts(c, k).html.replace(/<[^>]+>/g, ""), cls: "gold", rcls: "white" })),
          { l: "Autres métiers", r: `${M.countOther(c)} vues`, cls: "gold", rcls: "white" }, { sp: true }, { l: "Clic : ouvrir le carnet", cls: "green" }, { l: "Clic droit : options", cls: "green" }],
      }));
    stage.append(menu);
    overlays(ctx, stage, 700);
    return "The add-ons button by the minimap (approximated). Its entry opens the notebook; hover for the counts.";
  }

  // The addon's page in the game's Options › Add-ons: what the player can turn on and off. Live: it drives the bench.
  function options(ctx, stage) {
    const { S } = ctx;
    const X = 330, Y = 60, W = 1100, H = 960;
    const f = frame(X, Y, W, H, "Options", { cls: "settings" });
    const left = h("div.inset.setnav", {}, h("div.gold.fs13", {}, "Jeu"), h("div.lgray.fs12", {}, "Add-ons"), ...["Auctionator", "KaLi Quest"].map((t) => h("div.fs12.lgray", { style: { paddingLeft: "12px" } }, t)), h("div.fs12.white.on", { style: { paddingLeft: "12px" } }, "KaLi Recipe"), h("div.fs12.lgray", { style: { paddingLeft: "12px" } }, "Pagle"));
    f.append(left);
    const body = h("div.setbody");
    const sec = (t) => body.append(h("div.sethd", {}, t));
    const chk = (key, label, tip) => body.append(hover(h("div.setrow", { onclick: () => ctx.set({ [key]: !S[key] }) }, h("span.white.fs12", {}, label), h("span.setbox", {}, S[key] ? "✓" : "")), () => [{ l: label, cls: "white", h: true }, { l: tip, cls: "lgray", wrap: true }], "right"));
    const pick = (key, label, choices) => body.append(h("div.setrow", {}, h("span.white.fs12", {}, label), h("span.setdd", { onclick: () => { const i = choices.findIndex(([v]) => v === S[key]); ctx.set({ [key]: choices[(i + 1) % choices.length][0] }); } }, (choices.find(([v]) => v === S[key]) || choices[0])[1] + "  ▾")));
    // Blizzard's slider with steppers (MinimalSliderWithSteppersTemplate): ◀ track ▶ and the value.
    const slider = (key, label, min, max, step = 1) => {
      const v = S[key], pct = (v - min) / (max - min) * 100;
      const setv = (nv) => ctx.set({ [key]: Math.max(min, Math.min(max, Math.round(nv / step) * step)) });
      const track = h("span.settrack", { onclick: (e) => { const b = e.currentTarget.getBoundingClientRect(); setv(min + (e.clientX - b.left) / b.width * (max - min)); } },
        h("span.fill", { style: { width: pct + "%" } }), h("span.thumb", { style: { left: pct + "%" } }));
      body.append(h("div.setrow", {}, h("span.white.fs12", {}, label), h("span.setslider", {}, h("span.step", { onclick: () => setv(v - step) }, "◀"), track, h("span.step", { onclick: () => setv(v + step) }, "▶"), h("span.white.fs12.val", {}, String(v)))));
    };
    // A sound list, as Blizzard's dropdown: picking one plays it, as in game.
    const pickSound = (kind, key) => {
      const o = window.SOUNDS ? SOUNDS.options.fr : {};
      const word = kind === "recipe" ? "OPT_SOUND_RECIPE" : "OPT_SOUND_PLACE";
      const choices = [["none", o.SOUND_NONE || "Aucun"], ...(window.SOUNDS ? SOUNDS.kinds[kind].map((c) => [c.key, c.fr]) : [])];
      const sel = h("select.setsel", { onclick: (e) => e.stopPropagation(), onchange: (e) => { ctx.set({ [key]: e.target.value }); U.playSound(kind, e.target.value); } },
        choices.map(([v, l]) => h("option", { value: v, ...(S[key] === v ? { selected: "" } : {}) }, l)));
      body.append(hover(h("div.setrow", {}, h("span.white.fs12", {}, o[word] || word), sel), () => [{ l: o[word], cls: "white", h: true }, { l: o[word + "_TIP"], cls: "lgray", wrap: true }], "right"));
      // Under it, « Écouter », as Blizzard's settings put an action under a setting (Ikar, 2026-11-10).
      body.append(h("div.setrow", {}, h("span", {}), h("span.setdd", { onclick: () => U.playSound(kind, S[key]) }, "Écouter")));
    };
    sec("Annonces");
    chk("chat", "Annoncer les recettes notées", "Chez un marchand, un entraîneur, à l’hôtel des ventes ou sur un butin, une ligne dans la discussion, dans la couleur des métiers.");
    pickSound("recipe", "soundRecipe");
    pickSound("place", "soundPlace");
    sec("Marques sur les recettes");
    chk("mKnown", "Apprises", "La petite coche du suivi des objectifs, sur les recettes que ce personnage connaît.");
    chk("mLearnable", "À apprendre", "Le rang requis, dans la couleur de difficulté.");
    chk("mTooLow", "Rang insuffisant", "Le rang requis, en rouge.");
    chk("mOwned", "Sur ce personnage", "L’icône du banquier en bas à gauche, quand ce personnage l’a, dans ses sacs ou en banque.");
    chk("mAlt", "Sur un autre personnage", "L’icône d’ami en bas à droite, quand un autre de vos personnages l’a. Les deux peuvent se voir ensemble.");
    chk("mVendor", "Vue chez un marchand", "À l’hôtel des ventes, un œil sur les recettes déjà vues chez un marchand : inutile de les payer plus cher.");
    chk("mCraft", "Objets fabriqués", "La petite icône du métier en haut à gauche des objets qu’une recette connue fabrique : vive si ce personnage sait le faire, atténuée sinon.");
    chk("mCraftSeen", "Y compris par les recettes vues", "Aussi les objets d’une recette vue mais pas apprise.");
    sec("Infobulles");
    pick("b4", "Infobulle d’une recette", [["detailed", "Détaillée"], ["compact", "Une ligne"], ["off", "Rien"]]);
    chk("c1", "« Utilisé dans » sur les composants", "Les recettes connues de vos personnages, par métier.");
    chk("c1Seen", "Y ajouter les recettes croisées", "En gris, après les connues.");
    slider("c1Max", "Lignes au plus", 3, 20);
    sec("Carnet");
    pick("nbStyle", "Style du carnet", Object.entries(NOTEBOOK.STYLES).map(([k, st]) => [k, st.fr]));
    chk("follow", "Suivre la fenêtre des métiers", "Le carnet s’ouvre avec la fenêtre des métiers, se range contre elle et la suit, sur le métier qui y est ouvert.");
    slider("nbW", "Largeur", ...NOTEBOOK.LIMITS.W, 20);
    slider("nbH", "Hauteur", ...NOTEBOOK.LIMITS.H, 20);
    chk("nbOwned", "Sur ce personnage", "L’icône du banquier sur la ligne d’une recette que ce personnage a, et combien dans le détail.");
    chk("nbAlt", "Sur vos autres personnages", "L’icône d’ami sur la ligne, et qui en a combien dans le détail.");
    sec("Fenêtres et carte");
    chk("a1", "« Carnet : N » dans la fenêtre des métiers", "Sous la barre de rang. Un clic ouvre le carnet.");
    chk("a2", "« Carnet : N » dans le livre des métiers", "Sous chaque métier, et une ligne pour les autres.");
    chk("showZero", "Afficher aussi à zéro", "Sinon, rien ne s’affiche tant qu’il n’y a rien à dire.");
    chk("d4", "Épingles sur la carte du monde", "Là où une recette que ce personnage ne connaît pas a été vue.");
    f.append(body);
    f.append(abs(h("div.btn", { style: { cursor: "pointer" }, onclick: () => ctx.set({ ...window.BENCH_DEFAULTS_OPTIONS }) }, "Par défaut"), W - 130, H - 34));
    stage.append(f);
    return "The addon's page in Options › Add-ons (approximated, Blizzard's vertical layout). It's live: its switches are the bench's.";
  }

  window.SH = { S_W, S_H, esc, badge, markers, held, eye, check, recipeTip, whereLine, materialTip, frame, openNotebook };

  window.SCENES = {
    professions: { label: "Professions window", draw: professions },
    pbook: { label: "Professions book", draw: pbook },
    merchant: { label: "Vendor", draw: merchant },
    trainer: { label: "Trainer", draw: trainer },
    ah: { label: "Auction house", draw: ah },
    bags: { label: "Bags (hover)", draw: bags },
    map: { label: "World map", draw: map },
    notebook: { label: "Notebook", draw: notebook },
    compartment: { label: "Add-ons button", draw: compartment },
    options: { label: "In-game options", draw: options },
  };
})();
