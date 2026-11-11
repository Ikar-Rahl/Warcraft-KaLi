// The notebook: one layout, two styles (Ikar, 2026-11-09): « Épuré » (Clean, the game window D1) and « Livre »
// (Book, a quest page per profession). The style is an in-game option; nothing moves between them.
// Layout: header (profession, rank, the two counts, « open the professions window » and « follow »), search and
// filter, the list, then the selected recipe's detail below it (the classic TradeSkillFrame's and quest log's layout:
// list on top, detail underneath); a footer; profession tabs down the right edge, the character's own first.
// Width and height are in-game options. With « Suivre » on, it hangs on the professions window and moves with it.
// The list: « À apprendre » (learnable now), « Vues » (seen, rank too low or another profession), « Appris »
// (collapsed), each by the game's own categories. Per recipe: the rank badge, where it was seen, who holds it.
// Left click shows the recipe's detail below the list; right click, the addon's menu.
(function () {
  const { h, abs, atlas, hover } = U;
  const SH = window.SH;
  // In-game options « Largeur » and « Hauteur », in UI units.
  const LIMITS = { W: [460, 900], H: [600, 1080] };
  const clamp = (v, [lo, hi]) => Math.max(lo, Math.min(hi, Number(v) || lo));
  const size = (S) => ({ W: clamp(S.nbW ?? 560, LIMITS.W), H: clamp(S.nbH ?? 820, LIMITS.H) });

  // ---------- The model ----------

  function passes(ctx, spell) {
    const { S } = ctx, c = ctx.char, f = S.nbFilter || {};
    const r = M.recipe(spell);
    const q = (S.nbSearch || "").trim().toLowerCase();
    if (q && !r.name.toLowerCase().includes(q) && !r.reagents.some(([i]) => ((M.item(i) || {}).name || "").toLowerCase().includes(q))) return false;
    if (f.skillUp && !M.skillUp(spell, c)) return false;
    if (f.makeable && !M.makeable(spell, c)) return false;
    if (f.cats && f.cats.length && !f.cats.includes(M.category(spell).id)) return false;
    if (f.sources && f.sources.length && ![...M.sourcesOf(spell)].some((k) => f.sources.includes(k))) return false;
    if (f.owned && f.owned.length) { const p = M.possession(spell, c); if (!p || !((f.owned.includes("mine") && p.mine) || (f.owned.includes("alt") && p.alts.length))) return false; }
    return true;
  }

  const counts = (c, k) => M.split(c, k);

  function model(ctx) {
    const { S } = ctx, c = ctx.char, by = M.unknownSeen(c);
    const mine = M.profsOf(c);
    const others = Object.keys(M.D.professions).filter((k) => !mine.includes(k) && ((by[k] || []).length || Object.values(M.chars).some((ch) => ch.id !== c && k in ch.profs)));
    const skill = S.nbSkill && (mine.includes(S.nbSkill) || others.includes(S.nbSkill)) ? S.nbSkill : mine[0];
    const n = counts(c, skill);
    const known = Object.keys(M.D.recipes).filter((sp) => String(M.recipe(sp).skill) === String(skill) && M.knownByAny(sp));
    const keep = (a) => a.filter((sp) => passes(ctx, sp));
    const f = S.nbFilter || {};
    return {
      c, mine, others, skill, own: mine.includes(skill), rank: M.rankOf(c, skill), n,
      filtered: Object.values(f).some((v) => (Array.isArray(v) ? v.length : v)),
      learn: M.byCategory(keep(n.learn)), seen: M.byCategory(keep(n.seen)), known: M.byCategory(keep(known)),
      nLearn: keep(n.learn).length, nSeen: keep(n.seen).length, nKnown: keep(known).length, total: M.countAll(c),
    };
  }

  // ---------- Pieces ----------

  // Where it was seen; for a learned recipe, also who else knows it. Learned recipes keep their sources (Ikar).
  function subline(ctx, spell, known) {
    const c = ctx.char, others = M.knowers(spell).filter((k) => k.id !== c), seen = M.sightingsOf(spell);
    return [known && others.length && !M.isKnown(spell, c) ? `connue de ${others.map((k) => k.name).join(", ")}` : "",
      seen[0] ? SH.whereLine(seen[0]) : "", seen.length > 1 ? `+${seen.length - 1}` : ""].filter(Boolean).join(" · ");
  }

  // Who holds the recipe's item, each an option of the notebook's own (Ikar): this character (the bag), another
  // character (the friend icon). No words under them (Ikar, 2026-11-10): the detail says where.
  const place = (hh) => (hh.bags && hh.bank ? "sacs et banque" : hh.bags ? "vos sacs" : "votre banque");
  function holding(ctx, spell) {
    const { S } = ctx, pos = M.possession(spell, ctx.char);
    if (!pos) return null;
    const icons = [];
    if (pos.mine && S.nbOwned) icons.push(SH.held());
    if (pos.alts.length && S.nbAlt) icons.push(atlas("groupfinder-icon-friend", 16, 16));
    if (!icons.length) return null;
    return h("div.nbhold", {}, h("span.nbmk", {}, ...icons));
  }

  function row(ctx, spell, known, sel) {
    const r = M.recipe(spell), sub = subline(ctx, spell, known);
    const el = h("div.nbrow" + (known ? ".kn" : "") + (sel ? ".sel" : ""), { "data-spell": spell },
      h("span.lvlcol", {}, SH.badge(spell, ctx.char, 26)),
      h("div.nbtxt", {}, h("div.nm", {}, r.name), sub ? h("div.sb", { html: sub }) : null),
      holding(ctx, spell));
    hover(el, () => SH.recipeTip(r.item, spell, ctx), "right");
    el.addEventListener("click", () => ctx.set({ nbSel: sel ? null : spell, rowMenu: null, nbMenu: false }));
    el.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      const fr = el.closest(".nbframe"), b = fr.getBoundingClientRect(), sc = b.width / fr.offsetWidth;
      ctx.set({ rowMenu: { spell, x: (e.clientX - b.left) / sc, y: (e.clientY - b.top) / sc }, nbMenu: false });
    });
    return el;
  }

  // The header's two buttons. The hammer: Blizzard's professions window on this profession
  // (OpenProfessionUIToSkillLine), for the character's own professions. « Suivre »: one switch for all professions;
  // on, the notebook opens with the professions window, hangs on its side, moves with it, and shows the profession
  // open there (TRADE_SKILL_SHOW, TRADE_SKILL_CLOSE, C_TradeSkillUI.GetBaseProfessionInfo; it only listens).
  // « Suivre » is Forever's own arrow button, alone (Ikar): pressed and in colour when on, gray when off.
  function buttons(ctx, m) {
    const on = !!ctx.S.follow;
    const out = h("div.nbbtns");
    if (m.own) {
      const open = h("span.nbbtn.icon", { onclick: () => ctx.set({ scene: "professions", profSkill: m.skill, nbOpen: true, nbFollowClosed: "", rowMenu: null, nbMenu: false }) },
        atlas("ui-hud-micromenu-professions-up", 15, 19));
      out.append(hover(open, () => [{ l: "Ouvrir la fenêtre des métiers", cls: "white", h: true }, { l: `La fenêtre du jeu, sur ${M.prof(m.skill).name}.`, cls: "lgray", wrap: true }], "right"));
    }
    const follow = h("span.nbfollow" + (on ? ".on" : ""), { onclick: () => ctx.set({ follow: !on, nbFollowClosed: "" }) },
      atlas(on ? "profession-button-arrow-right-pressed" : "profession-button-arrow-right", 24, 24, on ? {} : { filter: "grayscale(1) brightness(.8)" }));
    out.append(hover(follow, () => [{ l: "Suivre la fenêtre des métiers", cls: "white", h: true },
      { l: "Le carnet s’ouvre avec la fenêtre des métiers, se range contre elle et la suit, sur le métier qui y est ouvert.", cls: "lgray", wrap: true },
      { l: on ? "Activé" : "Désactivé", cls: on ? "green" : "gray" }, { l: "Aussi dans Options › Add-ons.", cls: "gray" }], "right"));
    return out;
  }

  function header(ctx, m) {
    const c = m.n, seen = `${c.seen.length} vue${c.seen.length > 1 ? "s" : ""}`;
    // The bar gives way first when the notebook is narrow, so the line never wraps into the search box.
    const barW = Math.max(100, Math.min(190, size(ctx.S).W - 370));
    const rank = m.own
      ? h("div.ps", {}, h("div.skillbar", { style: { width: barW + "px" } }, h("div.fill", { style: { width: Math.min(100, m.rank / 75 * 100) + "%" } }), h("span.txt", {}, `${m.rank}/75`)), h("span", {}, `${c.learn.length} à apprendre · ${seen}`))
      : h("div.ps", {}, `Métier que ce personnage n’a pas · ${seen}`);
    return h("div.nbhead", {}, h("div", {}, h("div.pt", {}, M.prof(m.skill).name), rank), buttons(ctx, m));
  }

  function tools(ctx, m) {
    const el = h("input.search-in.flow", { value: ctx.S.nbSearch || "", placeholder: "Rechercher une recette ou un composant" });
    el.addEventListener("input", (e) => { ctx.S.nbSearch = e.target.value; clearTimeout(window.__nbT); window.__nbT = setTimeout(() => ctx.set({}), 250); });
    const filter = h("span.nbbtn", { onclick: (e) => { e.stopPropagation(); ctx.set({ nbMenu: !ctx.S.nbMenu, rowMenu: null }); } }, m.filtered ? "Filtrer ▸ •" : "Filtrer ▸");
    return h("div.nbtools", {}, el, filter);
  }

  function list(ctx, m, sel) {
    const { S } = ctx, closed = S.nbCatClosed || {}, out = [];
    const sec = (label, n, open, key, groups, known, tag) => {
      out.push(h("div.nbsec", { onclick: () => ctx.set({ [key]: !open, rowMenu: null }) }, h("span", {}, `${label} (${n})`), h("span.tog", {}, open ? "–" : "+")));
      if (!open) return;
      for (const g of groups) {
        const ck = tag + g.id, shut = !!closed[ck];
        out.push(h("div.nbcat" + (shut ? ".shut" : ""), { onclick: () => ctx.set({ nbCatClosed: { ...closed, [ck]: !shut } }) }, h("span.cn", {}, g.name), h("span.n", {}, String(g.spells.length))));
        if (!shut) for (const sp of g.spells) out.push(row(ctx, sp, known, String(sp) === sel));
      }
    };
    if (m.own) sec("À apprendre", m.nLearn, S.nbLearnOpen, "nbLearnOpen", m.learn, false, "l");
    sec("Vues", m.nSeen, S.nbSeenOpen, "nbSeenOpen", m.seen, false, "s");
    // « Appris »: TRADE_SKILLS_LEARNED_TAB, the professions window's own word.
    sec("Appris", m.nKnown, S.nbKnownOpen, "nbKnownOpen", m.known, true, "k");
    if (!m.nLearn && !m.nSeen && !m.nKnown) out.push(h("div.nbempty", {}, S.nbSearch || m.filtered ? "Aucune recette ne correspond." : "Rien de noté pour ce métier."));
    return out;
  }

  // The selected recipe, below the list (Ikar: the separate recipe window folded into the notebook). It takes only the
  // room its content needs (Ikar), up to half the notebook, then scrolls: short sections sit on one line with their label.
  // In game: the made item's icon shows its real tooltip (so Auctionator's price), reagents from
  // C_TradeSkillUI.GetRecipeSchematic, and the frame's height is the sum of its lines.
  function detail(ctx, spell) {
    const { S } = ctx, c = ctx.char, r = M.recipe(spell), out = r.makes ? M.item(r.makes) : null;
    const ic = out ? U.itemIcon(r.makes, 32) : U.profIcon(r.skill, 32);
    hover(ic, () => (out ? SH.materialTip(r.makes, ctx) : SH.recipeTip(r.item, spell, ctx)), "right");
    const sub = [M.category(spell).name, out && out.name !== r.name ? r.name : ""].filter(Boolean).join(" · ");
    const el = h("div.nbdet", {},
      h("div.dh", {}, ic,
        h("div.dt", {}, h("div", { class: "dn q" + (out ? out.quality ?? 1 : 1) }, out ? out.name : r.name), h("div.ds", {}, SH.badge(spell, c, 24), h("span", {}, sub))),
        hover(h("span.dx", { onclick: () => ctx.set({ nbSel: null }) }, "×"), () => [{ l: "Fermer le détail", cls: "white" }], "right")));
    const body = h("div.dbody");
    // A line: the label in its column, the value wrapping beside it. A label repeated down a list is left blank.
    const line = (t, ...kids) => h("div.dl", {}, h("span.dk", {}, t || ""), h("div.dv", {}, ...kids));

    // Components: chips that wrap, as many to a line as fit.
    if (r.reagents.length) {
      body.append(line("Composants :", ...r.reagents.map(([i, n]) => {
        const have = M.holds(c, i).total;
        return hover(h("span.dr", {}, U.itemIcon(i, 18), h("span", { class: have >= n ? "white" : "gray" }, `${have}/${n} ${(M.item(i) || {}).name}`)), () => SH.materialTip(i, ctx), "right");
      })));
    }

    // Every sighting, one line each; a pin places a waypoint where the map knows the spot.
    const seen = M.sightingsOf(spell);
    seen.forEach((s, k) => {
      const where = SH.whereLine(s) + (s.kind === "ah" ? "" : ` · ${M.date(s.date)}`);
      const canPin = s.zone && M.D.maps[String(s.zone)] && s.x != null;
      const pin = canPin ? hover(h("span.pin", { onclick: () => ctx.set({ scene: "map", mapZone: String(s.zone), waypoint: { x: s.x, y: s.y, zone: String(s.zone), npc: s.npc } }) },
        atlas("waypoint-mappin-tracked", 14, 14)), () => [{ l: "Placer un repère", cls: "white", h: true }, { l: `${M.zone(s.zone)} (${Math.round(s.x)}, ${Math.round(s.y)})`, cls: "lgray" }], "right") : null;
      body.append(line(k ? "" : "Vue :", h("span.dr", {}, h("span", { html: where }), pin)));
    });

    // Who holds it, as the options say, on one line.
    const pos = M.possession(spell, c), holds = [];
    if (pos && pos.mine && S.nbOwned) holds.push(h("span.dr", {}, SH.held(), h("span", {}, `${pos.mine.total} dans ${pos.mine.bags && pos.mine.bank ? "vos sacs et votre banque" : place(pos.mine)}`)));
    if (pos && S.nbAlt) for (const a of pos.alts) holds.push(h("span.dr", {}, atlas("groupfinder-icon-friend", 16, 16), h("span", {}, `${a.c.name} : ${a.h.total} dans ${a.h.bags && a.h.bank ? "ses sacs et sa banque" : a.h.bags ? "ses sacs" : "sa banque"}`)));
    if (holds.length) body.append(line("Sur vos personnages :", ...holds));

    // Who knows it: only when someone does (the section already says this character doesn't).
    const who = M.knowers(spell);
    if (who.length) body.append(line("Connue de :", h("span", {}, who.map((k) => `${k.id === c ? "ce personnage" : k.name} (${M.rankOf(k.id, r.skill)})`).join(", "))));
    el.append(body);
    return el;
  }

  // The classic spellbook's side tabs, down the right edge, in both styles.
  function tabs(ctx, m) {
    const el = h("div.sidetabs");
    const tab = (k, dim) => {
      const n = counts(ctx.char, k);
      const t = h("div.sidetab" + (k === m.skill ? ".on" : "") + (dim ? ".dim" : ""), { onclick: () => ctx.set({ nbSkill: k, rowMenu: null, nbMenu: false }) },
        atlas("spellbook-skilllinetab", 40, 58, { position: "absolute", left: 0, top: 0 }), h("span.ti", { style: { backgroundImage: `url(${M.iconUrl(M.prof(k).icon)})` } }));
      return hover(t, () => [{ l: M.prof(k).name, cls: "white", h: true },
        { l: m.mine.includes(k) ? `Rang ${M.rankOf(ctx.char, k)}/75` : "Métier que ce personnage n’a pas", cls: "lgray" },
        ...(m.mine.includes(k) ? [{ l: `${n.learn.length} à apprendre`, cls: "gold" }] : []), { l: `${n.seen.length} vue${n.seen.length > 1 ? "s" : ""}`, cls: "gold" }], "right");
    };
    el.append(...m.mine.map((k) => tab(k)), h("div.gap"), ...m.others.map((k) => tab(k, true)));
    return el;
  }

  // Menus are Blizzard's Menu API in game: the game's dark look in both styles.
  function filterMenu(ctx, m, W) {
    const { S } = ctx, f = S.nbFilter || {};
    const setF = (patch) => ctx.set({ nbFilter: { ...f, ...patch } });
    const toggleIn = (key, v) => { const a = new Set(f[key] || []); a.has(v) ? a.delete(v) : a.add(v); setF({ [key]: [...a] }); };
    const box = (on) => h("span.box", {}, on ? "✓" : "");
    const it = (label, on, fn, indent) => h("div.it", { onclick: fn, style: { cursor: "pointer", paddingLeft: indent ? "14px" : "0" } }, box(on), label);
    const el = abs(h("div.menu", { style: { minWidth: "250px" } }), W - 290, 132);
    el.append(it("Peut faire progresser", f.skillUp, () => setF({ skillUp: !f.skillUp })), it("Comp. disponibles", f.makeable, () => setF({ makeable: !f.makeable })));
    el.append(h("div.hd", {}, "Catégories"));
    M.byCategory(Object.keys(M.D.recipes).filter((sp) => String(M.recipe(sp).skill) === String(m.skill)))
      .forEach((g) => el.append(it(g.name, (f.cats || []).includes(g.id), () => toggleIn("cats", g.id), true)));
    el.append(h("div.hd", {}, "Sources"));
    Object.entries(M.SOURCES).forEach(([k, v]) => el.append(it(v, (f.sources || []).includes(k), () => toggleIn("sources", k), true)));
    el.append(h("div.hd", {}, "Possession"));
    [["mine", "Sur ce personnage"], ["alt", "Sur un autre personnage"]].forEach(([k, v]) => el.append(it(v, (f.owned || []).includes(k), () => toggleIn("owned", k), true)));
    el.append(h("div.it", { style: { cursor: "pointer", marginTop: "4px" }, onclick: () => ctx.set({ nbFilter: {} }) }, h("span.gold", {}, "Tout réinitialiser")));
    return el;
  }

  function rowMenu(ctx, rm, W) {
    const s = M.sightingsOf(rm.spell).find((x) => x.zone && M.D.maps[String(x.zone)] && x.x != null);
    const el = abs(h("div.menu", { style: { minWidth: "200px" } }), Math.min(rm.x + 4, W - 210), rm.y + 4);
    el.append(h("div.hd", {}, M.recipe(rm.spell).name));
    const it = (label, fn, off) => h("div.it", { onclick: off ? null : fn, style: { cursor: off ? "default" : "pointer", color: off ? "#777" : "#fff" } }, label);
    el.append(it("Placer un repère", () => ctx.set({ scene: "map", mapZone: String(s.zone), waypoint: { x: s.x, y: s.y, zone: String(s.zone), npc: s.npc }, rowMenu: null }), !s));
    el.append(it("Lier dans la discussion", () => ctx.set({ rowMenu: null })));
    el.append(it("Annuler", () => ctx.set({ rowMenu: null })));
    return el;
  }

  // ---------- The window ----------

  // Book: each profession's own quest parchment, with the profession sketched behind the list. It covers the page
  // at any size, cropped rather than stretched (in game, SetTexCoord inside the atlas's own coordinates).
  const QUESTBG = { 185: "questbg-cooking", 333: "questbg-enchanting", 197: "questbg-tailoring", 171: "questbg-alchemy", 165: "questbg-leatherworking", 164: "questbg-blacksmithing", 202: "questbg-engineering", 356: "questbg-fishing" };
  const STYLES = { clean: { label: "Clean", fr: "Épuré" }, book: { label: "Book", fr: "Livre" } };

  function parchment(name, bw, bh) {
    const a = M.atlas(name), e = a && (a["1"] || a["0"]);
    const bg = abs(h("div.nbbg"), 8, 28, bw, bh);
    if (!e) return bg;
    const k = Math.max(bw / e.w, bh / e.h), w = Math.round(e.w * k), hh = Math.round(e.h * k);
    bg.append(atlas(name, w, hh, { position: "absolute", left: Math.round((bw - w) / 2) + "px", top: "0px" }));
    return bg;
  }

  // `opts.docked`: « Suivre » hung it on the professions window.
  function draw(ctx, x, y, opts) {
    const { S } = ctx, { W, H } = size(S);
    const m = model(ctx), book = S.nbStyle === "book";
    const f = SH.frame(x, y, W, H, "Carnet de recettes", {
      cls: "nbframe nbwin " + (book ? "nb-book" : "nb-clean") + (opts && opts.docked ? " docked" : ""),
      onclose: () => ctx.set({ nbOpen: false, nbMenu: false, rowMenu: null, nbFollowClosed: S.profSkill || "" }),
      gear: () => ctx.set({ scene: "options" }),
    });
    f.append(book ? parchment(QUESTBG[m.skill] || "questbg-parchment", W - 16, H - 34) : abs(h("div.inset"), 10, 32, W - 20, H - 42));
    f.append(abs(header(ctx, m), 30, 46, W - 60), abs(tools(ctx, m), 30, 102, W - 60));
    // The detail shows only for a recipe of the profession shown; the list keeps its top, so rows don't move.
    const sel = S.nbSel && M.recipe(S.nbSel) && String(M.recipe(S.nbSel).skill) === String(m.skill) ? String(S.nbSel) : null;
    // The list takes what the detail leaves (the detail: its content's height, half the room at most).
    const top = 138, bodyH = H - 48 - top;
    f.append(abs(h("div.nbsplit", {}, h("div.nbbody", {}, ...list(ctx, m, sel)), sel ? detail(ctx, sel) : null), 24, top, W - 46, bodyH));
    f.append(abs(h("div.nbfoot", {}, `${m.total} recettes dans le carnet · seulement ce que vous avez croisé`), 30, H - 38, W - 60));
    f.append(abs(tabs(ctx, m), W - 2, 46));
    if (S.nbMenu) f.append(filterMenu(ctx, m, W));
    if (S.rowMenu) f.append(rowMenu(ctx, S.rowMenu, W));
    return { el: f, w: W + 40 };
  }

  window.NOTEBOOK = { STYLES, LIMITS, size, draw, counts };
})();
