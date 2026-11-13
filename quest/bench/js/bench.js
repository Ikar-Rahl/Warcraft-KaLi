// The bench's own controls: what's on screen, the fake game's state, and the triggers.
window.Bench = (function () {
  const STORE = "testbench.settings.v1";
  // Ikar's defaults, 2026-11-07.
  const DEFAULT_SETTINGS = {
    view: "both", artSet: "1", scale: "game", background: "snow-day",
    textSize: 12, opacity: 0, height: 530, width: 310, questPOI: false, difficultyColor: true, spoken: true, foreverTint: true,
    areaHighlight: true, markerStyle: "icons", shareOnHover: true, findGroup: false, showSecure: false,
    autoQuestWatch: false, progressFlash: true,
    headerSaturation: 50, blockRest: 15, blockCombat: 15, blockHover: 40, opacityRest: 90, opacityCombat: 50,
  };
  const DEFAULT_TOKENS = { titleGap: -4, groupIndent: 0, questIndent: 40, groupGap: 5, barGap: 5, markerSize: 13 };
  // Ikar's game draws one UI unit on 1.8 screen pixels: 2160 pixels for a screen 1200 units tall.
  const GAME_PIXELS = 1.8;
  // The tracker's bottom at the default height. "Game size" shrinks if the window can't show that much.
  const UNITS_TO_SHOW = 1000;

  const B = { settings: { ...DEFAULT_SETTINGS }, tokens: { ...DEFAULT_TOKENS }, bgImage: null, selected: 22 };

  function save() {
    if (location.hash.includes("selftest")) return;
    try { localStorage.setItem(STORE, JSON.stringify({ settings: B.settings, tokens: B.tokens })); } catch (e) { /* Only a convenience. */ }
  }

  // The dropped screenshot, kept between reloads. Everything still works if this storage isn't available.
  function screenshotStore(mode, action) {
    return new Promise((resolve) => {
      try {
        const open = indexedDB.open("testbench", 1);
        open.onupgradeneeded = () => open.result.createObjectStore("files");
        open.onerror = () => resolve(null);
        open.onsuccess = () => {
          const store = open.result.transaction("files", mode).objectStore("files");
          const req = action(store);
          req.onsuccess = () => resolve(req.result);
          req.onerror = () => resolve(null);
        };
      } catch (e) {
        resolve(null);
      }
    });
  }

  function useScreenshot(blob) {
    if (B.bgImage) URL.revokeObjectURL(B.bgImage);
    B.bgImage = blob ? URL.createObjectURL(blob) : null;
    paintWorld();
    renderAll();
    syncControls();
  }

  function load() {
    try {
      const raw = JSON.parse(localStorage.getItem(STORE));
      if (raw) {
        // Settings saved before the bench used real screenshots name worlds that are gone, and other defaults changed with them.
        // autoTrack was the game's own setting, on. It's now the addon's option, which starts off.
        delete raw.settings.autoTrack;
        if (Worlds.LIST[raw.settings.background]) Object.assign(B.settings, raw.settings);
        Object.assign(B.tokens, raw.tokens);
        // The addon's own text size, down to 8, became a zoom on 2026-11-10: only Edit Mode's 12 to 20 is left.
        B.settings.textSize = Math.min(20, Math.max(12, Number(B.settings.textSize) || 12));
      }
    } catch (e) { /* Falls back to the defaults. */ }
  }

  const $ = (s) => document.querySelector(s);
  const q = () => Game.quests.get(B.selected);
  const world = () => Worlds.LIST[B.settings.background];

  function zoom() {
    if (B.settings.scale !== "game") return B.settings.scale;
    return Math.min(GAME_PIXELS / devicePixelRatio, $("#stages").clientHeight / UNITS_TO_SHOW);
  }

  function renderAll() {
    UI.artSet = B.settings.artSet;
    const root = document.documentElement.style;
    root.setProperty("--fs", B.settings.textSize + "px");
    root.setProperty("--fs-head", B.settings.textSize + 2 + "px");
    root.setProperty("--prop-fs", B.settings.textSize + "px");
    root.setProperty("--prop-fs-head", B.settings.textSize + 2 + "px");
    root.setProperty("--header-sat", B.settings.headerSaturation / 100);
    root.setProperty("--block-rest", B.settings.blockRest / 100);
    root.setProperty("--block-combat", B.settings.blockCombat / 100);
    root.setProperty("--block-hover", B.settings.blockHover / 100);
    root.setProperty("--pw", B.settings.width + "px");
    root.setProperty("--scale", zoom());
    root.setProperty("--ot-right", (B.bgImage ? 5 : world().right) + "px");
    document.body.dataset.view = B.settings.view;
    document.body.classList.toggle("no-diff", !B.settings.difficultyColor);
    BlizzardTracker.render();
    ProposalTracker.state.benchChanged = true;
    ProposalTracker.render();
  }

  // A dropped screenshot is shown as it is. Only the bench's own list knows where the game's tracker is to erase it.
  function paintWorld() {
    const keepTracker = new URLSearchParams(location.hash.slice(1)).get("erase") === "0";
    document.querySelectorAll("canvas.scene").forEach((canvas) => {
      if (B.bgImage) Worlds.paint(canvas, "dropped", B.bgImage);
      else Worlds.paint(canvas, B.settings.background, world().file, keepTracker ? [] : world().erase);
    });
  }

  // The options' Astuces page, copied from Locale.lua (TIPS, frFR).
  const TIPS = [
    ["Raccourcis", [
      ["Clic", "Ouvre la quête sur la carte."],
      ["Maj+clic", "Suit la quête, qui rejoint le groupe du haut, ou arrête de la suivre. Avec la discussion ouverte, insère son lien."],
      ["Ctrl+clic", "Sélectionne plusieurs quêtes : glisser l'une d'elles, ou son clic droit, agit sur toutes. Un clic sans Ctrl désélectionne."],
      ["Clic droit", "Les menus : Déplacer vers sur une quête, Renommer ou Supprimer sur un groupe, Tout ouvrir sur une barre."],
      ["Glisser", "Une quête vers un groupe ; un groupe, ou une barre du Journal, pour les réordonner. Lâchée sur la barre Suivi, une quête crée un groupe."],
      ["Touches", "Verrouiller, tout replier, groupe suivant et précédent : sans touche au départ, à attribuer dans Options > Raccourcis clavier > Add-ons."],
    ]],
    ["À savoir", [
      ["Suivi", "Vos groupes. Une quête dans un groupe est suivie par le jeu ; les autres restent rangées dans le Journal."],
      ["Cadenas", "Fige l'ouverture et l'ordre. Le combat verrouille jusqu'à sa fin ; un clic déverrouille ce combat seulement."],
      ["Ligne grise", "Dans le Journal, la place d'une quête rangée dans un groupe. Son bouton l'y remet."],
      ["Rouage", "Suivi automatique, lueur, quêtes de la zone, et l'annulation de la dernière suppression d'un groupe."],
      ["Hors liste", "Au-delà des 25 quêtes suivies par le jeu, une quête placée à la main reste dans son groupe, marquée."],
      ["Flèche dorée", "Les quêtes de la zone où vous êtes ; sur une barre ou un groupe, combien il en contient."],
    ]],
  ];

  // Control panel, declared as data so a new trigger is one line.
  const CONTROL_GROUPS = [
    { title: "View", rows: [
      { type: "segment", id: "view", options: [["both", "Side by side"], ["blizzard", "Blizzard"], ["proposal", "Proposal"]] },
      { type: "segment", id: "artSet", label: "Art", options: [["1", "Forever (c60)"], ["0", "Default"]] },
      { type: "select", id: "background", label: "World", options: Object.entries(Worlds.LIST).map(([id, w]) => [id, w.label]) },
      { type: "screenshot" },
      { type: "range", id: "scale", label: "Zoom", min: 0.7, max: 2.5, step: 0.05 },
      { type: "buttons", buttons: [["Game size", () => setSetting("scale", "game")]] },
    ] },
    { title: "Game state", rows: [
      { type: "combat" },
      { type: "segment", custom: "party", label: "Party", options: [[1, "Solo"], [2, "2"], [3, "3"], [5, "5"]] },
      { type: "zone" },
    ] },
    { title: "Layouts (proposal)", rows: [
      { type: "buttons", buttons: [
        ["First login", () => ProposalTracker.preset("closed")],
        ["Typical", () => ProposalTracker.preset("typical")],
        ["All open", () => ProposalTracker.preset("open")],
        ["Dungeons", () => ProposalTracker.preset("dungeons")],
        ["No groups", () => ProposalTracker.preset("empty")],
        ["Fresh install", () => ProposalTracker.preset("install")],
        ["Over 25 tracked", () => ProposalTracker.preset("over25")],
      ] },
    ] },
    { title: "Key bindings (unbound by default)", rows: [
      { type: "buttons", buttons: [
        ["Lock or unlock", () => ProposalTracker.binding("lock")],
        ["Collapse or expand all", () => ProposalTracker.binding("collapse-all")],
        ["Previous group", () => ProposalTracker.binding("previous")],
        ["Next group", () => ProposalTracker.binding("next")],
      ] },
    ] },
    { title: "Edit Mode and game options", rows: [
      { type: "tips" },
      { type: "range", id: "textSize", label: "Text size (Edit Mode). The addon's zoom isn't drawn here", min: 12, max: 20, step: 1 },
      { type: "range", id: "headerSaturation", label: "Header saturation", min: 0, max: 100, step: 5 },
      { type: "range", id: "opacity", label: "Tracker background", min: 0, max: 100, step: 5 },
      { type: "range", id: "blockRest", label: "Quest background: default", min: 0, max: 100, step: 5 },
      { type: "range", id: "blockCombat", label: "Quest background: in combat", min: 0, max: 100, step: 5 },
      { type: "range", id: "blockHover", label: "Quest background: hover or clicked", min: 0, max: 100, step: 5 },
      { type: "range", id: "opacityRest", label: "Whole tracker: out of combat", min: 0, max: 100, step: 5 },
      { type: "range", id: "opacityCombat", label: "Whole tracker: in combat", min: 0, max: 100, step: 5 },
      { type: "range", id: "width", label: "Width", min: 220, max: 400, step: 10 },
      { type: "range", id: "height", label: "Height", min: 200, max: 1000, step: 10 },
      { type: "check", id: "questPOI", label: "Map buttons (questPOI)" },
      { type: "check", id: "difficultyColor", label: "Difficulty colours" },
      { type: "check", id: "shareOnHover", label: "Share button only on hover" },
      { type: "check", id: "findGroup", label: "Group search button" },
      { type: "check", id: "areaHighlight", label: "Area highlight" },
      { type: "check", id: "progressFlash", label: "Flash when an objective updates" },
      { type: "check", id: "autoQuestWatch", label: "Auto-track quests (autoQuestWatch). Off on install" },
    ] },
    { title: "Game options: advanced", rows: [
      { type: "token", id: "titleGap", label: "Under the title", min: -6, max: 10 },
      { type: "token", id: "groupIndent", label: "Group indent", min: 0, max: 24 },
      { type: "token", id: "questIndent", label: "Quest indent", min: 20, max: 44 },
      { type: "token", id: "groupGap", label: "Above a group", min: 0, max: 16 },
      { type: "token", id: "barGap", label: "Between bars", min: 0, max: 16 },
      { type: "token", id: "markerSize", label: "Marker size", min: 10, max: 20 },
      { type: "buttons", buttons: [["Reset these", () => { Object.assign(B.tokens, DEFAULT_TOKENS); save(); buildControls(); renderAll(); }]] },
    ] },
    { title: "Triggers on a quest", rows: [
      { type: "questselect" },
      { type: "buttons", label: "Progress", buttons: [
        ["+1", () => Game.progress(B.selected, 1)],
        ["Finish objective", () => Game.completeObjective(B.selected)],
        ["Finish quest", () => Game.completeQuest(B.selected)],
        ["Undo objective", () => Game.undoObjective(B.selected)],
      ] },
      { type: "buttons", label: "State", buttons: [
        ["Fail", () => Game.setFailed(B.selected, true)],
        ["Un-fail", () => Game.setFailed(B.selected, false)],
        ["By steps", () => Game.setSequenced(B.selected, !(q() && q().sequenced))],
        ["Focus", () => Game.superTrack(B.selected)],
        ["Turn in", () => Game.turnIn(B.selected)],
        ["Abandon", () => Game.abandon(B.selected)],
      ] },
      { type: "buttons", label: "Quest item", buttons: [
        ["Usable now: enter area", () => Game.enterArea(B.selected, true)],
        ["Leave area", () => Game.enterArea(B.selected, false)],
        ["In range", () => Game.setRange(B.selected, 1)],
        ["Out of range", () => Game.setRange(B.selected, 0)],
        ["No range", () => Game.setRange(B.selected, null)],
        ["Cooldown 10 s", () => Game.startCooldown(B.selected, 10)],
      ] },
      { type: "buttons", label: "Popups, timer", buttons: [
        ["Popup: complete", () => Game.addPopup(B.selected, "COMPLETE")],
        ["Popup: offer", () => Game.addPopup(B.selected, "OFFER")],
        ["Timer 60 s", () => Game.startTimer(B.selected, 60)],
        ["Clear timers", () => Game.clearTimers()],
      ] },
      { type: "buttons", label: "Party", buttons: [
        ["Member has it", () => Game.setPartyOnQuest(B.selected, (q() ? q().party : 0) + 1)],
        ["Member lacks it", () => Game.setPartyOnQuest(B.selected, (q() ? q().party : 1) - 1)],
      ] },
      { type: "buttons", label: "The game's tracked list, as another addon might change it", buttons: [
        ["Track", () => Game.toggleWatch(B.selected, true)],
        ["Untrack", () => Game.toggleWatch(B.selected, false)],
      ] },
    ] },
    { title: "Log", rows: [
      { type: "buttons", buttons: [
        ["Accept a new quest", () => { const n = Game.accept(); if (n) { B.selected = n.id; refreshQuestSelect(); } }],
        ["Reset log", () => { Game.reset(); refreshQuestSelect(); }],
      ] },
    ] },
    { title: "Other addons", rows: [
      { type: "check", id: "spoken", label: "Spoken's ▶ button" },
      { type: "check", id: "foreverTint", label: "Forever Quest Tint's ∞ marker" },
    ] },
    { title: "Proposal options", rows: [
      { type: "segment", id: "markerStyle", label: "Markers", options: [["icons", "Icons"], ["text", "Text"], ["none", "None"]] },
      { type: "check", id: "showSecure", label: "Outline secure buttons" },
    ] },
  ];

  const { h } = UI;

  function field(label, control) {
    return h("label", { class: "ctl" }, label ? h("span", { class: "ctl-label" }, label) : null, control);
  }

  function setSetting(id, value) {
    B.settings[id] = value;
    save();
    if (id === "background") paintWorld();
    renderAll();
    // Bars and rows are measured, so what changes the stage's size needs a second pass.
    if (id === "scale" || id === "view" || id === "width") renderAll();
    syncControls();
  }

  function refreshQuestSelect() {
    const sel = $("#quest-select");
    if (!sel) return;
    if (!Game.quests.has(B.selected)) B.selected = Game.order[0];
    sel.innerHTML = "";
    Game.order.forEach((id) => {
      const quest = Game.quests.get(id);
      const opt = h("option", { value: id }, `[${quest.level}] ${quest.title}${quest.item ? " (objet)" : ""}`);
      sel.append(opt);
    });
    sel.value = B.selected;
  }

  function buildRow(row) {
    switch (row.type) {
      case "segment": {
        const wrap = h("div", { class: "seg" });
        row.options.forEach(([value, text]) => {
          const b = h("button", { type: "button", "data-seg": row.id || row.custom, "data-value": value }, text);
          b.addEventListener("click", () => {
            if (row.custom === "party") Game.setParty(value);
            else setSetting(row.id, value);
            syncControls();
          });
          wrap.append(b);
        });
        // Not a label: clicking its words would press the first button.
        return h("div", { class: "ctl" }, row.label ? h("span", { class: "ctl-label" }, row.label) : null, wrap);
      }
      case "select": {
        const sel = h("select", { "data-setting": row.id }, row.options.map(([v, t]) => h("option", { value: v }, t)));
        sel.addEventListener("change", () => setSetting(row.id, sel.value));
        return field(row.label, sel);
      }
      case "range": {
        const input = h("input", { type: "range", min: row.min, max: row.max, step: row.step, "data-setting": row.id });
        const out = h("output", { "data-out": row.id });
        input.addEventListener("input", () => setSetting(row.id, Number(input.value)));
        return field(row.label, h("span", { class: "range" }, input, out));
      }
      case "token": {
        const input = h("input", { type: "range", min: row.min, max: row.max, step: 1, value: B.tokens[row.id] });
        const out = h("output", null, B.tokens[row.id]);
        input.addEventListener("input", () => {
          B.tokens[row.id] = Number(input.value);
          out.textContent = input.value;
          save();
          ProposalTracker.render();
        });
        return field(row.label, h("span", { class: "range" }, input, out));
      }
      case "check": {
        const input = h("input", { type: "checkbox", "data-setting": row.id });
        input.addEventListener("change", () => setSetting(row.id, input.checked));
        return h("label", { class: "ctl check" }, input, h("span", null, row.label));
      }
      case "buttons": {
        return h("div", { class: "ctl" }, row.label ? h("span", { class: "ctl-label" }, row.label) : null,
          h("div", { class: "btns" }, row.buttons.map(([text, fn]) => {
            const b = h("button", { type: "button" }, text);
            b.addEventListener("click", fn);
            return b;
          })));
      }
      case "tips": {
        return h("details", { class: "ctl tips" },
          h("summary", null, "Astuces: the page behind the options' first button"),
          TIPS.map(([title, rows]) => [h("h3", null, title),
            h("dl", null, rows.map(([label, text]) => [h("dt", null, label), h("dd", null, text)]))]));
      }
      case "screenshot": {
        const b = h("button", { type: "button", id: "screenshot-clear" }, "Remove my screenshot");
        b.addEventListener("click", () => {
          screenshotStore("readwrite", (store) => store.delete("world"));
          useScreenshot(null);
        });
        return h("div", { class: "ctl" }, b);
      }
      case "combat": {
        const b = h("button", { type: "button", id: "combat-toggle", class: "combat" }, "Enter combat");
        b.addEventListener("click", () => { Game.setCombat(!Game.inCombat); syncControls(); });
        return b;
      }
      case "questselect": {
        const sel = h("select", { id: "quest-select" });
        sel.addEventListener("change", () => { B.selected = Number(sel.value); });
        return field("Quest", sel);
      }
      case "zone": {
        const zones = ["Marche de l'Ouest", "Forêt d'Elwynn", "Les Carmines", "Bois de la Pénombre"];
        const sel = h("select", { id: "zone-select" }, zones.map((z) => h("option", { value: z }, z)));
        sel.addEventListener("change", () => Game.setZone(sel.value));
        return field("Zone", sel);
      }
      default:
        return null;
    }
  }

  function buildControls() {
    const panel = $("#controls");
    panel.innerHTML = "";
    CONTROL_GROUPS.forEach((group) => {
      panel.append(h("section", { class: "ctl-group" }, h("h2", null, group.title), group.rows.map(buildRow)));
    });
    refreshQuestSelect();
    syncControls();
  }

  function syncControls() {
    const shown = (id) => (id === "scale" ? Math.round(zoom() * 100) / 100 : B.settings[id]);
    document.querySelectorAll("[data-setting]").forEach((el) => {
      const value = shown(el.dataset.setting);
      if (el.type === "checkbox") el.checked = !!value;
      else el.value = value;
    });
    document.querySelectorAll("[data-out]").forEach((el) => { el.textContent = shown(el.dataset.out); });
    document.querySelectorAll("[data-seg]").forEach((el) => {
      const key = el.dataset.seg;
      const current = key === "party" ? Game.partySize : B.settings[key];
      el.classList.toggle("on", String(current) === el.dataset.value);
    });
    const combat = $("#combat-toggle");
    if (combat) {
      combat.textContent = Game.inCombat ? "In combat: leave" : "Out of combat: enter";
      combat.classList.toggle("on", Game.inCombat);
    }
    document.body.classList.toggle("in-combat", Game.inCombat);
    const clearShot = $("#screenshot-clear");
    if (clearShot) clearShot.style.display = B.bgImage ? "" : "none";
    const zone = $("#zone-select");
    if (zone) zone.value = Game.zone;
  }

  // What the title row's gear does here. In the game it opens the addon's page under Options > AddOns.
  function revealOptions() {
    const section = [...document.querySelectorAll("#controls .ctl-group")].find((g) => g.querySelector("h2").textContent === "Edit Mode and game options");
    if (!section) return;
    section.scrollIntoView({ block: "start" });
    section.classList.remove("reveal");
    void section.offsetWidth;
    section.classList.add("reveal");
  }

  function addLog(kind, text) {
    const list = $("#log");
    if (!list) return;
    const stamp = new Date().toLocaleTimeString("en-GB");
    list.prepend(h("div", { class: "log-" + kind }, h("span", { class: "log-time" }, stamp), ` ${kind}: ${text}`));
    while (list.childNodes.length > 60) list.lastChild.remove();
  }

  // Dropping a screenshot replaces the world, until it's removed.
  function setupDrop() {
    window.addEventListener("dragover", (e) => { e.preventDefault(); document.body.classList.add("drop-target"); });
    window.addEventListener("dragleave", (e) => { if (!e.relatedTarget) document.body.classList.remove("drop-target"); });
    window.addEventListener("drop", (e) => {
      e.preventDefault();
      document.body.classList.remove("drop-target");
      const file = e.dataTransfer.files[0];
      if (!file || !file.type.startsWith("image/")) return;
      useScreenshot(file);
      screenshotStore("readwrite", (store) => store.put(file, "world"));
    });
    screenshotStore("readonly", (store) => store.get("world")).then((blob) => { if (blob) useScreenshot(blob); });
  }

  // For screenshots and sharing a state: index.html#combat=1&preset=open&quest=60&do=enterArea
  function applyHash() {
    const params = new URLSearchParams(location.hash.slice(1));
    const pick = (k) => params.get(k);
    ["view", "artSet", "background", "markerStyle"].forEach((k) => { if (pick(k)) B.settings[k] = pick(k); });
    ["textSize", "opacity", "height", "width", "scale", "headerSaturation", "blockRest", "blockCombat", "blockHover", "opacityRest", "opacityCombat"].forEach((k) => { if (pick(k)) B.settings[k] = Number(pick(k)); });
    B.settings.textSize = Math.min(20, Math.max(12, B.settings.textSize));
    ["areaHighlight", "showSecure", "questPOI", "spoken", "foreverTint"].forEach((k) => { if (pick(k)) B.settings[k] = pick(k) === "1"; });
    Object.keys(DEFAULT_TOKENS).forEach((k) => { if (pick(k)) B.tokens[k] = Number(pick(k)); });
    if (pick("preset")) ProposalTracker.preset(pick("preset"));
    if (pick("party")) Game.setParty(Number(pick("party")));
    if (pick("quest")) B.selected = Number(pick("quest"));
    if (pick("do")) pick("do").split(",").forEach((step) => {
      const [name, arg] = step.split(":");
      if (name === "enterArea") Game.enterArea(B.selected, true);
      else if (name === "outOfRange") Game.setRange(B.selected, 0);
      else if (name === "cooldown") Game.startCooldown(B.selected, Number(arg) || 10);
      else if (name === "popup") Game.addPopup(B.selected, arg || "COMPLETE");
      else if (name === "timer") Game.startTimer(B.selected, Number(arg) || 60);
      else if (name === "progress") Game.progress(B.selected, Number(arg) || 1);
      else if (name === "finish") Game.completeQuest(B.selected);
      else if (name === "focus") Game.superTrack(B.selected);
      else if (name === "unlock") { ProposalTracker.state.unlocked = true; }
      else if (name === "share") Game.share(B.selected);
      else if (name === "open") { ProposalTracker.state.open.categories[arg] = true; }
      else if (name === "search") { ProposalTracker.state.searchOpen = true; ProposalTracker.state.search = decodeURIComponent(arg || ""); }
    });
    renderAll();
    if (pick("combat") === "1") Game.setCombat(true);
  }

  // Steps that need the finished layout, such as moving rows after combat has fixed the item buttons.
  function applyHashAfterLayout() {
    new URLSearchParams(location.hash.slice(1)).get("after")?.split(",").filter(Boolean).forEach((step) => {
      const [name, arg] = step.split(":");
      if (name === "unlock") { ProposalTracker.state.unlocked = true; ProposalTracker.render(); }
      else if (name === "toggle") { const el = document.querySelector(`#prop-root [data-groupkey="${decodeURIComponent(arg)}"]`); el && el.click(); }
      else if (name === "menu" || name === "bzmenu") {
        const root = name === "menu" ? "#prop-root" : "#blizz-root";
        const el = document.querySelector(`${root} [data-action="title"][data-quest="${arg}"]`);
        if (el) {
          const r = el.getBoundingClientRect();
          el.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: r.left + 40, clientY: r.top + 8 }));
        }
      } else if (name === "drag") {
        const row = document.querySelector(`#prop-root .pt-row[data-quest="${arg}"]`);
        const r = row.getBoundingClientRect();
        row.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, button: 0, clientX: r.left + 40, clientY: r.top + 5 }));
        window.dispatchEvent(new MouseEvent("mousemove", { clientX: r.left - 60, clientY: r.top + 70 }));
      } else if (name === "dragover") {
        const r = document.querySelector(`#prop-root [data-groupkey="${decodeURIComponent(arg)}"]`).getBoundingClientRect();
        window.dispatchEvent(new MouseEvent("mousemove", { clientX: r.left + 40, clientY: r.top + r.height / 2 }));
      } else if (name === "filter") { document.querySelector("#prop-root [data-action='filter']").click(); }
      else if (name === "awake") { document.querySelector("#prop-root").parentElement.classList.add("tools-awake"); }
      else if (name === "gear") { document.querySelector("#prop-root [data-action='settings']").click(); }
      else if (name === "delete") {
        const el = document.querySelector(`#prop-root [data-groupkey="g${arg}"]`);
        el && el.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
        [...document.querySelectorAll(".menu .menu-item")].find((i) => i.textContent === "Supprimer le groupe")?.click();
        document.querySelector("#stage-prop .dialog [data-ok]")?.click();
      }
      else if (name === "tip") {
        const el = document.querySelector(`#prop-root [data-action="title"][data-quest="${arg}"]`);
        el && el.dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));
      }
      else if (name === "pick") {
        const el = document.querySelector(`#prop-root .pt-row[data-quest="${arg}"]`);
        el && el.dispatchEvent(new MouseEvent("click", { bubbles: true, ctrlKey: true }));
      }
    });
  }

  function init() {
    load();
    UI.artSet = B.settings.artSet;
    Game.onLog(addLog);
    Game.reset();
    BlizzardTracker.mount($("#blizz-root"));
    ProposalTracker.mount($("#prop-root"));
    buildControls();
    applyHash();
    Game.onChange(syncControls);
    setupDrop();
    paintWorld();
    renderAll();
    syncControls();
    let lastSize = `${innerWidth}x${innerHeight}`;
    window.addEventListener("resize", () => {
      const size = `${innerWidth}x${innerHeight}`;
      if (size === lastSize) return;
      lastSize = size;
      renderAll();
      syncControls();
    });
    document.fonts.ready.then(() => {
      renderAll();
      setTimeout(applyHashAfterLayout, 200);
      if (location.hash.includes("selftest")) {
        const script = document.createElement("script");
        script.src = "js/selftest.js";
        document.body.append(script);
      }
    });
    // Timers and cooldowns tick on screen without a game event.
    setInterval(() => {
      if (Game.timers.length) { BlizzardTracker.render(); ProposalTracker.render(); }
    }, 500);
  }

  return Object.assign(B, { init, renderAll, setSetting, revealOptions });
})();
