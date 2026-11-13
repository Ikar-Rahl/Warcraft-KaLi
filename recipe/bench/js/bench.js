// The control panel: scenes, characters, and the switches still open. Ikar's choices of 2026-11-09 are the defaults.
// State is remembered in localStorage; a URL hash (#scene=merchant&hover=.mitem:nth-child(2)) sets it too.
(function () {
  const { h } = U;
  const KEY = "recipe-notebook-bench-v7"; // v7: recipe detail in the notebook, its size, possession options (stale choices are dropped)
  // What the in-game options would hold (the "Par défaut" button of the options scene resets these).
  const OPTIONS = {
    a1: true, a2: true, showZero: true,
    chat: true,
    mKnown: true, mLearnable: true, mTooLow: true, mOwned: true, mAlt: true, mCraft: true, mCraftSeen: true,
    b4: "detailed", c1: true, c1Seen: true, c1Max: 10, d4: true,
    nbStyle: "clean", follow: false, nbW: 560, nbH: 820, nbOwned: true, nbAlt: true,
    // The two sounds (2026-11-10): the addon's own defaults, from js/sounds.js.
    soundRecipe: (window.SOUNDS && SOUNDS.defaults.recipe) || "none", soundPlace: (window.SOUNDS && SOUNDS.defaults.place) || "none",
    // « Volume des sons » (2026-11-12): both sounds, in percent of their in-game volume, 200 by default (2026-11-13).
    soundVolume: 200,
  };
  window.BENCH_DEFAULTS_OPTIONS = OPTIONS;
  const DEFAULTS = {
    // The showcase vendor by default: one real recipe per marker case.
    scene: "professions", char: "main", profSkill: "185", vendor: "showcase", trainer: "", mapZone: "1657", world: "cave",
    ...OPTIONS,
    nbOpen: false, nbSkill: "", nbSearch: "", nbFilter: {}, nbMenu: false, nbLearnOpen: true, nbSeenOpen: true, nbKnownOpen: false,
    nbCatClosed: {}, nbFollowClosed: "", nbSel: null, profX: 48, profY: 100,
    rowMenu: null, mapMenu: false, waypoint: null,
  };
  let S = { ...DEFAULTS };
  try { Object.assign(S, JSON.parse(localStorage.getItem(KEY) || "{}")); } catch (e) { /* private window: defaults */ }
  let customWorld = null, zoom = null;

  function fromHash() {
    const p = new URLSearchParams(location.hash.slice(1));
    if (p.get("reset")) S = { ...DEFAULTS };
    for (const [k, v] of p) {
      if (k === "hover" || k === "reset" || k === "click" || k === "zoom") continue;
      S[k] = v === "1" || v === "true" ? true : v === "0" || v === "false" ? false : typeof DEFAULTS[k] === "number" ? Number(v) : v;
    }
    // zoom=x,y,scale: show that point of the stage at that scale (for checking small art in screenshots).
    zoom = p.get("zoom") ? p.get("zoom").split(",").map(Number) : null;
    return { hover: p.get("hover"), click: p.get("click") };
  }

  function set(patch) {
    Object.assign(S, patch);
    try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { /* not remembered */ }
    render();
  }
  const ctx = () => ({ S, set, char: S.char });

  // ---------- Panel ----------
  const seg = (key, options) => h("div.seg", {}, options.map(([v, label]) =>
    h("button" + (S[key] === v ? ".on" : ""), { onclick: () => set({ [key]: v }) }, label)));
  // A checkbox; `go` is where its effect shows (a scene, and more), applied when it's switched.
  const check = (key, label, hint, go) => h("div.opt", {}, h("label.check", {}, h("input", { type: "checkbox", ...(S[key] ? { checked: "" } : {}), onchange: (e) => set({ ...(go || {}), [key]: e.target.checked }) }), h("span", {}, h("span.lab", {}, label), hint ? h("span.hint", {}, hint) : null)));
  const WINDOWS = [
    ["a1", "Count in the professions window", "Professions window, under the rank bar", { scene: "professions" }],
    ["a2", "Count in the professions book", "Professions book, under each profession", { scene: "pbook" }],
    ["showZero", "Show it at zero", "Elorah's Secourisme, the bench's only count at 0", { scene: "professions", char: "alt", profSkill: "129" }],
    ["d4", "Pins on the world map", "World map", { scene: "map" }],
  ];
  const opt = (label, hint, control) => h("div.opt", {}, label ? h("span.lab", {}, label) : null, hint ? h("span.hint", {}, hint) : null, control);

  function panel() {
    const p = document.getElementById("panel");
    p.replaceChildren();
    p.append(h("h1", {}, "Recipe notebook · bench"),
      h("p.lead", {}, "Ikar's choices of 9 Nov are built in; the switches below are what the in-game options would offer, plus what's still open. Hover rows and items; click counts, notebook rows (right click too) and pins."));

    p.append(h("h2", {}, "Scene"), h("div.seg.scenes", {}, Object.entries(SCENES).map(([k, sc]) => h("button" + (S.scene === k ? ".on" : ""), { onclick: () => set({ scene: k, mapMenu: false, rowMenu: null, nbMenu: false }) }, sc.label))));
    p.append(opt("Character", "Elorah is invented: a tailor (and first aid, nothing seen yet) who keeps a cooking recipe in her bags, and a pattern and a cooking recipe in her bank.", seg("char", [["main", M.chars.main.name + " (Ench. 18, Cuisine 56)"], ["alt", M.chars.alt.name + " (Couture 70, Secourisme 40)"]])));

    if (S.scene === "merchant") {
      const sel = h("select", { onchange: (e) => set({ vendor: e.target.value }) }, M.vendors().map((s) => {
        const n = M.npc(s.npc);
        return h("option", { value: s.npc, ...(String(S.vendor) === String(s.npc) ? { selected: "" } : {}) }, `${n.name} · ${n.title} · ${M.zone(s.zone)}`);
      }));
      p.append(opt("Vendor", "Real vendors that sell recipes, in places Ikar has been.", sel));
    }
    if (S.scene === "trainer") {
      const sel = h("select", { onchange: (e) => set({ trainer: e.target.value }) }, M.trainers().map((s) => {
        const n = M.npc(s.npc);
        return h("option", { value: s.npc, ...(String(S.trainer) === String(s.npc) ? { selected: "" } : {}) }, `${n.name} · ${n.title}`);
      }));
      p.append(opt("Trainer", "Darnassus. Me'lynn and Ainethil teach professions Ikar doesn't have.", sel));
    }
    if (S.scene === "map") p.append(opt("Map", null, seg("mapZone", Object.entries(M.D.maps).map(([z, m]) => [z, m.name]))));

    p.append(h("div.note", {}, "Decided: « Carnet : N » under the rank bar and in the professions book, shown at zero too. Every spotting goes to the chat in the crafting blue. Recipe tooltip: detailed, compact or none in game, detailed by default. « Utilisé dans » by profession, up to 10, with recipes seen and where. Notebook in two styles, by recipe, level badges, « Appris » collapsed, search and filters, the recipe's detail below the list, size in the options; « Suivre » is Forever's arrow button and hangs it on the professions window; dark buttons. Map pins in game icons. Tooltip lines in the crafting light blue. No total on the add-ons button entry. Known: the tracker's small check. No auction prices kept."));

    p.append(h("h2", {}, "Chat"));
    p.append(check("chat", "Announce recipes noted", "Vendor, trainer, auction house, loot. One line per visit."));

    // The sounds: every one the in-game options offer, to hear and pick.
    p.append(h("h2", {}, "Sounds"));
    if (!window.SOUNDS) {
      p.append(h("div.note.warn", {}, "js/sounds.js is missing: run python -I recipe/tools/bench_sounds.py from the repository's root."));
    } else {
      p.append(h("div.hint", { style: { fontSize: "11px", color: "#8b919b" } }, `The game's own sounds, each at its in-game volume, so they compare as in game. The game has one writing sound, the quest log's quill: the shorter ones are that quill stopped early, fading out over ${SOUNDS.fade} s, as the addon does it in game. One per visit: the bigger when it notes a recipe that wasn't in the notebook, the smaller for a new place of one that was, at least ${SOUNDS.quiet} s after the last. ▶ plays; a click on a name picks it, as the in-game option does (Options › KaLi Recipe › « ${SOUNDS.options.fr.OPT_CHAT_SECTION} »).`));
      for (const [kind, title, optKey, word] of [["recipe", "New recipe", "soundRecipe", "OPT_SOUND_RECIPE"], ["place", "New place", "soundPlace", "OPT_SOUND_PLACE"]]) {
        const list = h("div.sounds");
        const row = (key, label, sub) => h("div.snd" + (S[optKey] === key ? ".on" : ""), {},
          key === "none" ? h("span.play.off", {}, "▶") : h("button.play", { title: "Play", onclick: () => U.playSound(kind, key) }, "▶"),
          h("span.name", { onclick: () => { set({ [optKey]: key }); U.playSound(kind, key); } }, h("span.lab", {}, label), sub ? h("span.hint", {}, sub) : null));
        list.append(row("none", SOUNDS.options.fr.SOUND_NONE, "No sound for this one"));
        for (const c of SOUNDS.kinds[kind]) {
          const secs = c.stop ? `${c.stop} s + ${SOUNDS.fade} s fade` : c.takes.map((t) => t.seconds + " s").join(" / ");
          const pick = c.key === SOUNDS.defaults[kind] ? " · Ikar's pick" : "";
          list.append(row(c.key, c.fr, `${c.en} · ${secs} · volume ${c.volume} · ${c.use}${pick}`));
        }
        p.append(opt(`${title} (« ${SOUNDS.options.fr[word]} »)`, null, list));
      }
      p.append(opt(`Volume (« Volume des sons »)`, "Both sounds, in percent of their in-game volume, as the in-game slider does it: 200% by default, each at most full. 0%: none.",
        h("label.range", {}, h("input", { type: "range", min: 0, max: 300, step: 10, value: S.soundVolume, onchange: (e) => set({ soundVolume: Number(e.target.value) }) }),
          h("span.val", {}, S.soundVolume + "%"))));
      p.append(h("div.opt", {}, h("div.seg", {},
        h("button", { onclick: () => { U.playSound("recipe", S.soundRecipe); setTimeout(() => U.playSound("place", S.soundPlace), 3200); } }, "Hear the chosen pair"))));
    }

    p.append(h("h2", {}, "Markers"));
    p.append(h("div.hint", { style: { fontSize: "11px", color: "#8b919b" } }, "Top left: state. Bottom left: you hold it. Bottom right: another character does. Both can show. The showcase vendor has every case."));
    p.append(check("mKnown", "Known (the tracker's small check)", "Not in the notebook's « Appris » list or the trainer's « Déjà connu »: those already say it."));
    p.append(check("mLearnable", "To learn: required rank, in its difficulty colour"), check("mTooLow", "Rank too low: required rank in red"));
    p.append(check("mOwned", "You hold it, bags or bank alike (the banker, on a dark disc)"));
    p.append(check("mAlt", "Another character holds it (friend icon)"));
    p.append(check("mCraft", "Crafted items: the profession's small icon, top left", "Bright: this character can make it. Dimmed: another character can. Hover for « Fabriqué par ». Shows in: the bags.", { scene: "bags" }));
    p.append(check("mCraftSeen", "Crafted items: also from recipes only seen", null, { scene: "bags" }));

    p.append(h("h2", {}, "Tooltips"));
    p.append(opt("Recipe tooltip", "All three are in-game options; detailed by default. No auction price: Auctionator and the like add theirs, because the addon shows the recipe's real item tooltip.", seg("b4", [["detailed", "detailed"], ["compact", "one line"], ["off", "none"]])));
    p.append(check("c1", "« Utilisé dans » on materials"), check("c1Seen", "Include recipes seen, not known"));
    p.append(opt("Lines at most", null, seg("c1Max", [[6, "6"], [10, "10"], [15, "15"]])));

    p.append(h("h2", {}, "Windows"));
    p.append(h("div.hint", { style: { fontSize: "11px", color: "#8b919b" } }, "Each shows in one place only; switching one takes you there."));
    for (const [key, label, where, patch] of WINDOWS) p.append(check(key, label, "Shows in: " + where, patch));

    p.append(h("h2", {}, "Notebook"));
    p.append(opt("Style", "An in-game option (« Style du carnet »). Same layout in both: only the skin changes.",
      h("div.seg", {}, Object.entries(NOTEBOOK.STYLES).map(([k, st]) => h("button" + (S.nbStyle === k ? ".on" : ""), { onclick: () => set({ nbStyle: k, rowMenu: null, nbMenu: false, ...(S.scene === "professions" || S.scene === "notebook" ? {} : { scene: "notebook" }) }) }, `${st.label} (« ${st.fr} »)`)))));
    p.append(check("follow", "Follow the professions window (« Suivre »)", "One switch for all professions, also Forever's arrow button in the notebook's header. The notebook hangs on the window: drag the window's title bar and it moves along. Shows in: the professions window.", { scene: "professions" }));
    // Width and height: in-game sliders (« Largeur », « Hauteur »).
    const range = (key, label, [min, max]) => h("label.range", {}, h("span.lab", {}, label),
      h("input", { type: "range", min, max, step: 20, value: S[key], onchange: (e) => set({ [key]: Number(e.target.value), nbOpen: true }) }), h("span.val", {}, String(S[key])));
    p.append(opt("Size", "In-game sliders, « Largeur » and « Hauteur ». The list and the detail share the height.", h("div", {}, range("nbW", "Width", NOTEBOOK.LIMITS.W), range("nbH", "Height", NOTEBOOK.LIMITS.H))));
    p.append(check("nbOwned", "Rows: you hold it (banker)", "And how many, in the recipe's detail. The notebook's own option, apart from the item markers.", { nbOpen: true }));
    p.append(check("nbAlt", "Rows: another character holds it (friend)", "And who has how many, in the detail.", { nbOpen: true }));
    p.append(h("div.opt", {}, h("div.seg", {}, h("button" + (S.nbOpen ? ".on" : ""), { onclick: () => set({ nbOpen: !S.nbOpen, nbMenu: false, rowMenu: null }) }, S.nbOpen ? "Close the notebook" : "Open the notebook"))));

    p.append(h("h2", {}, "View"));
    p.append(opt("World", "Or drop your own screenshot anywhere on the page.", seg("world", [["cave", "cave"], ["troll-camp", "troll camp"], ["snow-day", "snow"], ["snow-night", "night"]].concat(customWorld ? [["custom", "yours"]] : []))));
    p.append(h("div.seg", {}, h("button", { onclick: () => { try { localStorage.removeItem(KEY); } catch (e) { /* nothing */ } S = { ...DEFAULTS }; render(); } }, "Reset everything")));

    p.append(h("hr"));
    p.append(h("div.note", {}, "Real: names (the client's French), reagents, ranks, what each recipe makes, vendors and where they stand (QuestieDB), icons, map tiles."),
      h("div.note", {}, "Invented: what Ikar saw where and when, auction listings and prices, inventories, vendor supplies, trainer ranks (estimated), Elorah."),
      h("div.note.warn", {}, "Frames are CSS approximations around the game's font, icons and textures. Judge placement and wording, not pixels."));
  }

  // ---------- Stage ----------
  function fit() {
    const wrap = document.getElementById("stage-wrap"), stage = document.getElementById("stage");
    if (zoom) { const [zx, zy, zs] = zoom; stage.style.transform = `translate(${-zx * zs}px, ${-zy * zs}px) scale(${zs})`; return; }
    const s = Math.min(wrap.clientWidth / 2133, wrap.clientHeight / 1200);
    stage.style.transform = `translate(${(wrap.clientWidth - 2133 * s) / 2}px, ${(wrap.clientHeight - 1200 * s) / 2}px) scale(${s})`;
  }

  function render() {
    U.untip();
    U.soundVolume = (S.soundVolume ?? 200) / 100;
    panel();
    const stage = document.getElementById("stage");
    const focused = document.activeElement && document.activeElement.classList.contains("search-in");
    const kept = [".nbbody", ".nbdet .dbody", ".setbody"].map((q) => [q, (stage.querySelector(q) || {}).scrollTop || 0]);
    stage.replaceChildren();
    const world = h("div.world");
    world.style.backgroundImage = `url(${S.world === "custom" && customWorld ? customWorld : `art/world/${S.world}.jpg`})`;
    stage.append(world);
    const sc = SCENES[S.scene] || SCENES.professions;
    let caption = "";
    try { caption = sc.draw(ctx(), stage); } catch (e) { caption = "Error: " + e.message; console.error(e); }
    document.getElementById("caption").innerHTML = `<b>${sc.label}</b> · ${caption || ""}`;
    if (focused) { const s = stage.querySelector(".search-in"); if (s) { s.focus(); s.setSelectionRange(s.value.length, s.value.length); } }
    for (const [q, top] of kept) { const el = stage.querySelector(q); if (el) el.scrollTop = top; }
    const body = stage.querySelector(".nbbody"), sel = body && body.querySelector(".nbrow.sel");
    if (sel && sel.offsetTop + sel.offsetHeight > body.scrollTop + body.clientHeight) body.scrollTop = sel.offsetTop + sel.offsetHeight - body.clientHeight + 4;
    fit();
  }

  window.addEventListener("dragover", (e) => { e.preventDefault(); document.body.classList.add("dragging"); });
  window.addEventListener("dragleave", () => document.body.classList.remove("dragging"));
  window.addEventListener("drop", (e) => {
    e.preventDefault(); document.body.classList.remove("dragging");
    const file = e.dataTransfer.files[0];
    if (!file || !file.type.startsWith("image/")) return;
    const r = new FileReader();
    r.onload = () => { customWorld = r.result; set({ world: "custom" }); };
    r.readAsDataURL(file);
  });
  window.addEventListener("resize", fit);
  window.addEventListener("hashchange", () => { const a = fromHash(); render(); act(a); });

  // For screenshots: hover or click an element of the stage after it's drawn.
  function act(a) {
    setTimeout(() => {
      if (a.click) { const el = document.querySelector("#stage " + a.click); if (el) el.click(); }
      setTimeout(() => { if (a.hover) { const el = document.querySelector("#stage " + a.hover); if (el) el.dispatchEvent(new Event("mouseenter")); } }, 30);
    }, 30);
  }

  document.getElementById("view").append(h("div.drop-hint", {}, "Drop a screenshot to use it as the world"));
  const a = fromHash();
  render();
  act(a);
})();
