// Shared pieces: element builder, atlases, tooltips, and the addon's wordings.
(function () {
  const U = {};

  U.h = (tag, attrs, ...kids) => {
    const [name, ...cls] = tag.split(".");
    const el = document.createElement(name || "div");
    if (cls.length) el.className = cls.join(" ");
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === "style" && typeof v === "object") Object.assign(el.style, v);
      else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else if (k === "html") el.innerHTML = v;
      else el.setAttribute(k, v);
    }
    for (const kid of kids.flat()) if (kid != null && kid !== false) el.append(kid.nodeType ? kid : document.createTextNode(kid));
    return el;
  };
  U.abs = (el, x, y, w, hgt) => {
    Object.assign(el.style, { position: "absolute", left: x + "px", top: y + "px" });
    if (w != null) el.style.width = w + "px";
    if (hgt != null) el.style.height = hgt + "px";
    return el;
  };

  // An atlas from Blizzard's sheets, drawn at w by h (defaults to its logical size). Set '1' is Forever's c60 art.
  U.atlas = (name, w, hgt, extra) => {
    const a = M.atlas(name);
    const el = U.h("span", { class: "atlas", style: { display: "inline-block", flex: "none" } });
    if (!a) return el;
    const e = a["1"] || a["0"];
    w = w || e.w; hgt = hgt || e.h;
    const sx = w / e.pw, sy = hgt / e.ph;
    Object.assign(el.style, {
      width: w + "px", height: hgt + "px", backgroundImage: `url(art/sheets/${e.f}.png)`,
      backgroundSize: `${e.sw * sx}px ${e.sh * sy}px`, backgroundPosition: `${-e.x * sx}px ${-e.y * sy}px`, ...(extra || {}),
    });
    return el;
  };
  U.icon = (fdid, size) => U.h("span.icon", { style: { width: size + "px", height: size + "px", backgroundImage: `url(${M.iconUrl(fdid)})` } });
  U.itemIcon = (itemId, size) => U.icon((M.item(itemId) || {}).icon, size);
  U.profIcon = (skill, size) => U.icon((M.prof(skill) || {}).icon, size);

  // Tooltip lines: { l, r, cls, rcls, h (header), sp (spacer), wrap }.
  let tipEl = null;
  U.tip = (anchor, lines, side) => {
    U.untip();
    const stage = document.getElementById("stage");
    tipEl = U.h("div.tip");
    for (const ln of lines) {
      if (ln.sp) { tipEl.append(U.h("div.sp")); continue; }
      const row = U.h("div.row" + (ln.h ? ".h" : "") + (ln.wrap ? ".wrap" : ""));
      row.append(U.h("span", { class: ln.cls || "white", html: ln.l }));
      if (ln.r) row.append(U.h("span.r", { class: "r " + (ln.rcls || "white"), html: ln.r }));
      tipEl.append(row);
    }
    stage.append(tipEl);
    const scale = stage.getBoundingClientRect().width / stage.offsetWidth;
    const sr = stage.getBoundingClientRect(), ar = anchor.getBoundingClientRect();
    const ax = (ar.left - sr.left) / scale, ay = (ar.top - sr.top) / scale, aw = ar.width / scale, ahh = ar.height / scale;
    const tw = tipEl.offsetWidth, th = tipEl.offsetHeight;
    let x = side === "left" ? ax - tw - 4 : side === "below" ? ax : ax + aw + 4;
    let y = side === "below" ? ay + ahh + 4 : ay;
    if (x + tw > stage.offsetWidth - 4) x = ax - tw - 4;
    if (y + th > stage.offsetHeight - 4) y = stage.offsetHeight - th - 4;
    U.abs(tipEl, Math.max(4, x), Math.max(4, y));
  };
  U.untip = () => { if (tipEl) tipEl.remove(); tipEl = null; };
  U.hover = (el, fn, side) => {
    el.addEventListener("mouseenter", () => U.tip(el, fn(), side));
    el.addEventListener("mouseleave", U.untip);
    return el;
  };

  // How the addon words its count. Each option is a candidate to compare.
  U.WORDINGS = {
    vues: { label: "« 12 recettes vues ailleurs »", one: "{n} recette vue ailleurs", many: "{n} recettes vues ailleurs" },
    inconnues: { label: "« 12 recettes inconnues repérées »", one: "{n} recette inconnue repérée", many: "{n} recettes inconnues repérées" },
    notees: { label: "« 12 recettes notées »", one: "{n} recette notée", many: "{n} recettes notées" },
    carnet: { label: "« Carnet : 12 »", one: "Carnet : {n}", many: "Carnet : {n}" },
  };
  U.count = (n, wording) => {
    const w = U.WORDINGS[wording] || U.WORDINGS.vues;
    return M.plural(n, w.one, w.many).replace(/^(\d+)/, '<span class="n">$1</span>');
  };
  U.hereLine = (n, wording) => wording === "carnet"
    ? `Carnet : <span class="n">${n}</span> ${n === 1 ? "nouvelle recette" : "nouvelles recettes"} ici`
    : `<span class="n">${n}</span> ${n === 1 ? "recette ici que vous ne connaissez pas" : "recettes ici que vous ne connaissez pas"}`;

  // Where a sighting was, in a few words.
  U.where = (s, short) => {
    const z = M.zone(s.zone);
    if (s.kind === "ah") return `Hôtel des ventes, ${M.date(s.date)}` + (short ? "" : ` · ${M.money(s.price)}`);
    const n = M.npc(s.npc) || {};
    if (s.kind === "drop") return `Ramassée sur ${s.from_name || n.name}, ${z}`;
    const who = n.name + (short ? "" : ` <${n.title}>`).replace(/</g, "&lt;").replace(/>/g, "&gt;");
    return `${s.kind === "trainer" ? "Enseignée par" : "Vendue par"} ${who}, ${z}`;
  };

  // The addon's sounds (js/sounds.js, made by tools/bench_sounds.py): the game's own files, each at its kit's volume so
  // they compare as in game. A kit with several takes plays one at random, as the game does. A sound with a stop fades
  // out from then over SOUNDS.fade seconds, as the addon's StopSound(handle, fade) does.
  U.sound = (kind, key) => (window.SOUNDS && SOUNDS.kinds[kind] || []).find((c) => c.key === key) || null;
  let playing = null, timers = [];
  const hush = () => {
    timers.forEach(clearTimeout); timers = [];
    if (playing) { playing.pause(); playing = null; }
  };
  U.playSound = (kind, key) => {
    const c = U.sound(kind, key);
    hush();
    if (!c || !c.takes.length) return;
    const take = c.takes[Math.floor(Math.random() * c.takes.length)];
    const audio = new Audio(take.file);
    const volume = Math.max(0, Math.min(1, c.volume));
    audio.volume = volume;
    playing = audio;
    audio.play().catch(() => { /* the browser wants a click first: the next click plays */ });
    if (c.stop) {
      const fade = (SOUNDS.fade || 0.2) * 1000, steps = 10;
      for (let i = 1; i <= steps; i++) {
        timers.push(setTimeout(() => { audio.volume = volume * (1 - i / steps); if (i === steps) audio.pause(); }, c.stop * 1000 + fade * i / steps));
      }
    }
  };

  window.U = U;
})();
