// Our proposal, from docs/organiser-design.md: every quest in a tree of category > group > quest,
// with markers, quick share, scrolling, the combat lock, search, filter, menus and dragging.
window.ProposalTracker = (function () {
  const { h, tex, atlasCss } = UI;
  const STORE = "testbench.proposal.v1";
  const ERR_NOT_IN_COMBAT = "Impossible de faire ceci tout en combattant.";

  // Everything the tracker shows is in the client's language, from the game's own strings where it has them.
  const CATEGORIES = {
    mine: "Suivi",           // TRACK_QUEST_ABBREV
    journal: "Journal",
    world: "Monde",
    classprof: "Classe et métiers",
    instances: "Donjons et raids",
    events: "Évènements",
    pvp: "Champs de bataille",
    misc: "Divers",
  };
  const DEFAULT_ORDER = ["mine", "world", "classprof", "instances", "events", "pvp", "misc"];
  const FIRST_GROUP_NAME = "Quêtes"; // QUESTS_LABEL, since a group called Suivi would sit inside the Suivi section

  const S = {
    root: null,
    groups: [],
    nextGroupID: 3,
    categoryOrder: null,
    open: { tracker: true, categories: {}, groups: {}, headers: {} },
    filters: {},
    search: "",
    searchOpen: false,
    locked: false,         // the player's own lock, kept between sessions
    unlocked: false,       // this fight only: combat locks the tracker, and this lets the player back in
    watchDirty: new Set(), // quests whose tracked state changed in the game's list, settled on the next frame
    renaming: null,
    flash: {},
    secure: new Map(),     // questID -> { x, y }. Fixed during combat, like a real secure button
    heldBack: new Set(),   // quests accepted during combat, drawn when it ends
    pendingFocus: 0,
    drag: null,
    justDragged: false,
    lockFlash: 0,
    scrollInset: 0,        // how far the list's top is clipped, so scrolled rows stop at the title's lower edge
    deleted: null,         // the last deleted group, until it's undone or another one is deleted. Not saved
    picked: new Set(),     // quests picked with Ctrl+click, until a click without it. Not saved
  };

  // Saved layout

  function save() {
    if (location.hash.includes("selftest")) return;
    try {
      localStorage.setItem(STORE, JSON.stringify({
        groups: S.groups, nextGroupID: S.nextGroupID,
        categoryOrder: S.categoryOrder, open: S.open, filters: S.filters, locked: S.locked,
      }));
    } catch (e) { /* Only a convenience. */ }
  }

  function load() {
    try {
      const raw = JSON.parse(localStorage.getItem(STORE));
      if (raw && raw.groups) {
        Object.assign(S, raw);
        if (S.open.categories.journal === undefined) S.open.categories.journal = true;
        // Layouts saved while this group still had its English name.
        S.groups.forEach((g) => { if (g.name === "Tracked") g.name = FIRST_GROUP_NAME; });
        return true;
      }
    } catch (e) { /* Falls back to the default layout. */ }
    return false;
  }

  function preset(name) {
    S.groups = JSON.parse(JSON.stringify(window.FakeLog.GROUPS));
    S.nextGroupID = 3;
    S.categoryOrder = null;
    S.filters = {};
    S.search = "";
    S.searchOpen = false;
    S.deleted = null;
    S.picked = new Set();
    S.open = { tracker: true, categories: {}, groups: {}, headers: {} };
    if (name === "typical") {
      S.open.categories = { mine: true, world: true };
      S.open.groups = { 1: true };
      S.open.headers = { "Marche de l'Ouest": true };
    } else if (name === "open") {
      Object.keys(CATEGORIES).forEach((c) => { S.open.categories[c] = true; });
      S.groups.forEach((g) => { S.open.groups[g.id] = true; });
      Game.order.forEach((id) => { S.open.headers[Game.quests.get(id).header] = true; });
    } else if (name === "dungeons") {
      S.open.categories = { instances: true };
      S.open.headers = { "Les Mortemines": true };
    } else if (name === "empty" || name === "install") {
      S.groups = [];
    } else if (name === "over25") {
      // Placed by hand past the game's limit, so the last two are in a group but off the game's list.
      const placed = new Set(S.groups.flatMap((g) => g.quests));
      const last = S.groups[S.groups.length - 1];
      Game.order.filter((id) => !placed.has(id)).slice(0, 27 - placed.size).forEach((id) => last.quests.push(id));
      S.open.categories = { mine: true };
      S.groups.forEach((g) => { S.open.groups[g.id] = g === last; });
    }
    S.open.categories.journal = true;
    if (name === "install") {
      // A first run: no saved groups, whatever the game was already tracking, and the addon's auto-tracking option at its default, off.
      Bench.setSetting("autoQuestWatch", false);
      Game.setWatch(window.FakeLog.QUESTS.filter((q) => q.tracked).map((q) => q.id));
      Game.watch.forEach(placeTracked);
    } else {
      syncWatch();
    }
    save();
    render();
  }

  // Rules

  // Combat always locks, until the player unlocks that fight. Out of combat, it's the player's own lock.
  const locked = () => (Game.inCombat ? !S.unlocked : S.locked);
  const searching = () => S.search.trim().length > 0;
  const filtering = () => Object.values(S.filters).some((set) => Object.keys(set).length > 0);

  function refusedInCombat() {
    if (!Game.inCombat) return false;
    UI.error(S.root, ERR_NOT_IN_COMBAT);
    return true;
  }

  function refusedByLock() {
    if (!locked()) return false;
    S.lockFlash++;
    render();
    Game.log("note", Game.inCombat ? "Locked in combat. Click the padlock to unlock for this fight" : "Locked. Click the padlock to unlock");
    return true;
  }

  function groupOf(id) {
    return S.groups.find((g) => g.quests.includes(id));
  }

  // Search: ignores case and accents, words in any order.
  const fold = (s) => String(s).normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();

  function searchText(q) {
    const g = groupOf(q.id);
    return fold([q.title, q.description, q.completionText, q.header, g && g.name, q.tag, q.level, q.id, CATEGORIES[q.category],
      ...q.objectives.map(window.FakeLog.objectiveText), q.repeatable && "répétable", q.elite && "élite", q.item && q.item.name, q.complete && "à rendre"].filter(Boolean).join(" "));
  }

  // Filter: the categories of filter-search.md. OR within one, AND across them.
  const DIFF_LABEL = { trivial: "Grise", standard: "Verte", difficult: "Jaune", verydifficult: "Orange", impossible: "Rouge" };
  const FILTERS = [
    { id: "type", label: "Type", values: (q) => [q.elite && "Élite", q.tagID === 81 && "Donjon", q.tagID === 62 && "Raid", q.tagID === 41 && "JcJ", q.legendary && "Légendaire"] },
    { id: "size", label: "Groupe", values: (q) => [q.suggestedGroup > 1 && `Groupe de ${q.suggestedGroup}`] },
    { id: "repeat", label: "Répétition", values: (q) => [q.repeatable ? "Répétable" : "Non répétable"] },
    { id: "state", label: "État", values: (q) => [q.failed ? "Échec" : q.complete ? "À rendre" : "En cours", Game.timers.some((t) => t.questID === q.id) && "Chronométrée", q.item && "Avec objet", q.sequenced && "Par étapes"] },
    { id: "diff", label: "Difficulté", order: Object.values(DIFF_LABEL), values: (q) => [DIFF_LABEL[Game.difficulty(q)]] },
    { id: "party", label: "Groupe de joueurs", values: (q) => [q.party > 0 && "Un membre l'a aussi", Game.partySize > 1 && q.pushable && "Partageable", q.canFindGroup && "Peut trouver un groupe"] },
    { id: "place", label: "Lieu", values: (q) => [q.header === Game.zone && "Zone actuelle"] },
  ];

  function passes(q) {
    if (searching()) {
      const text = searchText(q);
      if (!fold(S.search).split(/\s+/).filter(Boolean).every((w) => text.includes(w))) return false;
    }
    for (const f of FILTERS) {
      const ticked = Object.keys(S.filters[f.id] || {});
      if (!ticked.length) continue;
      const vals = f.values(q).filter(Boolean);
      if (!ticked.some((t) => vals.includes(t))) return false;
    }
    return true;
  }

  // Tree

  function buildTree() {
    const visible = (id) => Game.quests.has(id) && !S.heldBack.has(id);
    const placed = new Set();
    S.groups.forEach((g) => g.quests.forEach((id) => placed.add(id)));

    // A quest in one of the player's groups leaves an entry where it would have been, so its section keeps a line for it.
    const auto = {};
    Game.order.filter(visible).forEach((id) => {
      const q = Game.quests.get(id);
      const cat = auto[q.category] || (auto[q.category] = new Map());
      if (!cat.has(q.header)) cat.set(q.header, { quests: [], entries: [] });
      const header = cat.get(q.header);
      header.entries.push({ q, moved: placed.has(id) });
      if (!placed.has(id)) header.quests.push(q);
    });

    // Suivi always comes first. The rest sit inside Journal, in the player's order.
    const order = ["mine", ...(S.categoryOrder || DEFAULT_ORDER).filter((c) => c !== "mine")];
    return order.map((id) => {
      if (id === "mine") {
        return {
          id, groups: S.groups.map((g) => ({
            key: "g" + g.id, group: g, name: g.name, quests: g.quests.filter(visible).map((x) => Game.quests.get(x)),
          })),
        };
      }
      const headers = [...(auto[id] || new Map()).entries()].map(([name, header]) => ({ key: "h" + name, name, ...header }));
      if (id === "world") {
        // The zone you're in first, the rest alphabetical, as the addon: the game re-sorts its log for the map it shows.
        headers.sort((a, b) => (b.name === Game.zone) - (a.name === Game.zone) || a.name.localeCompare(b.name, "fr"));
      } else if (id === "classprof") {
        headers.sort((a, b) => (b.entries[0].q.classHeader ? 1 : 0) - (a.entries[0].q.classHeader ? 1 : 0) || a.name.localeCompare(b.name, "fr"));
      } else {
        headers.sort((a, b) => a.name.localeCompare(b.name, "fr"));
      }
      return { id, groups: headers };
    });
  }

  const isOpenGroup = (g) => (g.group ? S.open.groups[g.group.id] : S.open.headers[g.name]);

  function markers(q, inMine) {
    const m = [];
    // Past the game's 25, a quest stays in its group but the game doesn't count it as tracked.
    if (inMine && !Game.watch.includes(q.id)) m.push({ atlas: "waypoint-mappin-minimap-untracked", label: "Au-delà des 25 quêtes suivies par le jeu", short: "Hors liste" });
    if (Game.timers.some((t) => t.questID === q.id)) m.push({ atlas: "questlog-questtypeicon-clockyellow", label: "Chronométrée" });
    if (q.suggestedGroup > 1) m.push({ atlas: "questlog-questtypeicon-group", label: `Groupe de ${q.suggestedGroup}`, number: q.suggestedGroup });
    if (q.tagID === 81 && (inMine || q.category !== "instances")) m.push({ atlas: "questlog-questtypeicon-dungeon", label: "Donjon" });
    if (q.tagID === 62 && (inMine || q.category !== "instances")) m.push({ atlas: "questlog-questtypeicon-raid", label: "Raid" });
    if (q.tagID === 41 && (inMine || q.category !== "pvp")) m.push({ atlas: "questlog-questtypeicon-pvp", label: "JcJ" });
    if (q.repeatable) m.push({ atlas: "questrepeatableturnin", label: "Répétable" });
    if (q.frequency === 1) m.push({ atlas: "questlog-questtypeicon-daily", label: "Quotidienne" });
    if (q.frequency === 2) m.push({ atlas: "questlog-questtypeicon-weekly", label: "Hebdomadaire" });
    if (q.legendary) m.push({ atlas: "questlog-questtypeicon-legendary", label: "Légendaire" });
    if (inMine && q.classHeader) m.push({ atlas: "questlog-questtypeicon-class", label: "Classe" });
    return m;
  }

  // In combat, a finished quest keeps its lines until the fight ends, so rows don't move.
  function linesOf(q) {
    if (Game.inCombat && q.complete && q.objectives.length) {
      return q.objectives.map((o) => ({
        key: "o" + o.key, text: window.FakeLog.objectiveText(o), style: "complete", dash: false,
        state: o.state === "completing" ? "completing" : "completed",
      }));
    }
    return Game.linesFor(q);
  }

  // The level sits in a column left of the title, so a wrapped title keeps its left edge. Its colour is the difficulty.
  const badgeColumn = () => Math.ceil(Bench.settings.textSize * 1.75);
  const rowIndent = () => Math.max(Bench.tokens.questIndent, badgeColumn() + (Bench.settings.questPOI ? 26 : 5));
  // How far a row's background reaches left of its text. With map buttons on, the level sits 24 further out, past them.
  const rowGutter = () => badgeColumn() + (Bench.settings.questPOI ? 24 : 0);

  // Quests touch: each background reaches 3 past its row, so this gap leaves none. A thin line of the game's art tops
  // each entry, and one more closes the list.
  const ROW_GAP = 6;

  function separator(edge) {
    const width = Bench.settings.width - rowIndent() + rowGutter() + 7 + 2;
    return h("div", { class: "tex pt-sep " + edge, "data-key": "sep-" + edge, style: atlasCss("options_horizontaldivider", width, 1) });
  }

  // Every bar and group shows its state the same way, at the right of its line. The game's double arrow points left
  // when closed. Open turns it a quarter to point down, which Texture:SetRotation does in game.
  function toggleArrow(open) {
    return h("div", { class: "pt-arrow" + (open ? " open" : ""), "data-key": "arrow" }, tex("covenantsanctum-renown-doublearrow", "", "", 9, 12));
  }

  // On Forever's own nameplate level art, stretched to the text as the nameplates stretch it: Ikar's pick on 2026-11-08.
  function levelBadge(q, diff) {
    const w = badgeColumn();
    const ht = Math.round(Bench.settings.textSize * 1.3);
    const colour = Bench.settings.difficultyColor ? `color:var(--diff-${diff});` : "";
    return h("div", { class: "pt-gutter" + (Bench.settings.questPOI ? " with-poi" : ""), "data-key": "gutter", style: `width:${w}px` },
      h("span", { class: "pt-level", "data-key": "level", style: colour + atlasCss("ui-hud-nameplates-levelindicator", w, ht) + `line-height:${ht}px;` },
        `${q.level}${q.elite ? "+" : ""}`));
  }

  // Popups and timers grow with the text, but stop at the panel's width so they stay on screen.
  const fullScale = (artWidth) => Math.min(Bench.settings.textSize / 12, Bench.settings.width / artWidth);

  // How far a timer pushes the tracker's title down.
  const timerRoom = () => (Game.timers.length ? (43 + 16 * Game.timers.length + 10) * fullScale(158) : 0);

  function openDetails(q) {
    S.selected = q.id;
    UI.questPanel(S.root, q, () => { S.selected = 0; render(); });
    render();
  }

  // Rendering

  function questRow(q, ctx) {
    const inMine = !!ctx.group;
    const hasEye = Bench.settings.findGroup && q.canFindGroup && !q.complete;
    const hasItem = q.item && !(q.complete && !q.showItemWhenComplete);
    const canShare = Game.isShareable(q);
    const spoken = UI.hasSpoken(q);
    let right = 0;
    const frames = [];
    // Spoken keeps the far right, where it is on Blizzard's tracker. Everything else lines up to its left.
    if (spoken) {
      frames.push(UI.spokenButton(q, 0));
      right -= 14 + 2;
    }
    if (hasEye) {
      frames.push(h("div", { class: "edge", "data-key": "edge-eye", style: `top:-2px;right:${-right - 5}px` }, UI.findGroupButton(q)));
      right += 5 - 30 - 2;
    }
    if (hasItem) {
      frames.push(h("div", { class: "edge item-slot", "data-key": "edge-item", "data-slot": q.id, style: `top:0;right:${-right}px;--icon:url(art/${q.item.icon}.png)` }));
      right -= 26 + 2;
    }
    if (canShare) {
      frames.push(h("div", { class: "edge share-btn", "data-action": "share", "data-quest": q.id, "data-tip": "share", "data-key": "edge-share", style: `top:2px;right:${-right}px` },
        tex("questsharing-questlog-button", "share-frame", "", 22, 22),
        tex("socialqueuing-icon-group", "share-icon", "", 15, 13)));
      right -= 22 + 2;
    }

    const style = Bench.settings.markerStyle;
    const allMarkers = style === "none" ? [] : markers(q, inMine);
    const shown = allMarkers.slice(0, 3);
    const size = Bench.tokens.markerSize;
    const markerNodes = shown.map((m, i) => style === "text"
      ? h("span", { class: "mk-text", "data-key": "mk" + i }, m.number ? `(${m.number})` : `(${m.short || m.label})`)
      : h("span", { class: "mk", "data-key": "mk" + i, style: atlasCss(m.atlas, size, size) }, m.number ? h("span", { class: "mk-num" }, m.number) : null));

    const indent = rowIndent();
    const inner = Bench.settings.width - indent + right;
    // Spoken's button is only as tall as the title, so alone it leaves the objective lines their full width.
    const linesWidth = frames.length === (spoken ? 1 : 0) ? Bench.settings.width - indent : inner;
    const area = Bench.settings.areaHighlight && Game.insideArea.has(q.id);
    const anim = q.anim === "turnin" ? " a-turnin" : q.anim === "add" ? " a-add" : "";
    const diff = Game.difficulty(q);
    // Markers hold on to the title's last word, so they never wrap onto a line alone.
    const title = q.title;
    const tint = UI.tintMark(q);
    const lastWord = markerNodes.length || tint ? title.lastIndexOf(" ") + 1 : title.length;
    const selected = S.selected === q.id || Game.superTracked === q.id;
    // The whole box answers to click, right click and drag, not only its title.
    return h("div", {
      class: "ot-block pt-row" + anim + (area ? " in-area" : "") + (selected ? " selected" : "") + (S.picked.has(q.id) ? " picked" : "") + (S.flash["q" + q.id] ? " a-rowflash" : "") + (S.flash["p" + q.id] ? " a-progress" : ""),
      "data-key": "q" + q.id, "data-quest": q.id, "data-group": ctx.group ? ctx.group.id : "", "data-action": "title", "data-drag": "quest",
      style: `--gutter:${rowGutter()}px;margin-left:${indent}px;margin-top:${ROW_GAP}px`,
    },
      separator("top"),
      ctx.last ? separator("bottom") : null,
      h("div", { class: "ot-head", style: `width:${inner}px` },
        levelBadge(q, diff),
        Bench.settings.questPOI ? UI.poiButton(q) : null,
        h("div", { class: "ot-head-text", "data-key": "text" },
          area ? tex("poi-traveldirections-arrow", "here-arrow", "", 9, 12) : null,
          q.party ? h("span", { class: "ot-party" }, `[${q.party + 1}] `) : null,
          h("span", { class: "pt-title-text" }, title.slice(0, lastWord)),
          lastWord < title.length ? h("span", { class: "pt-title-end" }, title.slice(lastWord), tint, markerNodes.length ? h("span", { class: "mk-strip" }, markerNodes) : null) : null)),
      h("div", { class: "ot-lines", style: `width:${linesWidth}px` }, linesOf(q).map(UI.line)),
      frames,
      tex("ui-questtracker-objfx-barglow", "ot-headglow", "", 240, 20));
  }

  // The line a quest leaves in its own section once it's in one of the player's groups. Clicks and menu are the quest's own.
  function movedLine(q, last) {
    return h("div", { class: "pt-moved", "data-key": "moved" + q.id, "data-action": "title", "data-quest": q.id, style: `--gutter:${rowGutter()}px;margin-left:${rowIndent()}px;margin-top:${ROW_GAP}px` },
      separator("top"),
      last ? separator("bottom") : null,
      h("span", { class: "pt-moved-title", "data-key": "title" }, q.title, UI.tintMark(q)),
      h("div", { class: "pt-moved-back", "data-action": "bring-back", "data-quest": q.id, "data-tip": "bring-back", "data-key": "back", style: atlasCss("common-icon-undo", 14, 14) }));
  }

  function countText(list) {
    if (searching() || filtering()) return String(list.length);
    return `${list.filter((q) => q.complete).length}/${list.length}`;
  }

  // With the highlight off, headers count nothing, a quest with an item included: Ikar's ruling on 2026-11-08.
  function hereCount(list) {
    if (!Bench.settings.areaHighlight) return 0;
    return list.filter((q) => Game.insideArea.has(q.id)).length;
  }

  function groupHeader(g, category) {
    const open = isOpenGroup(g);
    const key = g.group ? "gid" + g.group.id : "hdr" + g.name;
    const list = g.visible;
    const here = hereCount(list);
    const renaming = g.group && S.renaming === g.group.id;
    return h("div", {
      class: "pt-group" + (g.group ? " mine" : "") + (S.flash[g.key] ? " a-headerflash" : ""),
      "data-key": key, "data-action": "toggle-group", "data-groupkey": g.key, "data-drag": g.group ? "group" : "", style: `margin-top:${Bench.tokens.groupGap}px;padding-left:${Bench.tokens.groupIndent}px`,
    },
      renaming
        ? h("input", { class: "pt-rename", "data-key": "rename", value: g.group.name, maxlength: "40" })
        : h("div", { class: "pt-group-name" }, g.name),
      here ? h("div", { class: "pt-here" }, tex("poi-traveldirections-arrow", "", "", 8, 10), String(here)) : null,
      h("div", { class: "pt-focus", "data-action": "focus-group", "data-groupkey": g.key, "data-tip": "focus", "data-key": "focus" }, tex("gm-icon-visible", "", "", 16, 16)),
      // A section left with only moved quests' lines has nothing to count.
      h("div", { class: "pt-count", "data-key": "count" }, g.group || list.length ? countText(list) : ""),
      toggleArrow(open));
  }

  // Suivi and Journal are the two top sections and keep their place. The bars inside Journal can be dragged.
  function categoryBar(cat, all) {
    const top = cat.id === "mine" || cat.id === "journal";
    const open = S.open.categories[cat.id];
    const here = hereCount(all);
    return h("div", { class: "ot-bar pt-bar" + (top ? "" : " pt-subbar") + (S.flash["c" + cat.id] ? " a-barflash" : ""), "data-key": "bar", "data-action": "toggle-cat", "data-cat": cat.id, "data-drag": top ? "" : "bar" },
      tex("ui-questtracker-secondary-objective-header", "bar-bg", "", Bench.settings.width + 40, 30),
      h("div", { class: "ot-bar-text pt-bar-text" }, CATEGORIES[cat.id]),
      h("div", { class: "pt-bar-right", "data-key": "right" },
        cat.id === "mine" ? h("div", { class: "pt-add", "data-action": "new-group", "data-tip": "new-group", "data-key": "add" }, tex("ui-questtrackerbutton-secondary-expand", "", "", 14, 14)) : null,
        here ? h("div", { class: "pt-here", "data-key": "here" }, tex("poi-traveldirections-arrow", "", "", 8, 10), String(here)) : null,
        h("div", { class: "pt-count", "data-key": "count" }, all.length || (cat.id === "mine" && S.groups.length) ? countText(all) : "")),
      toggleArrow(open));
  }

  function renderList() {
    const tree = buildTree();
    const searchOn = searching();
    const hiding = searchOn || filtering();
    let totalShown = 0;
    let total = 0;
    const section = (cat, gap) => {
      cat.groups.forEach((g) => {
        total += g.quests.length;
        g.visible = hiding ? g.quests.filter(passes) : g.quests;
        totalShown += g.visible.length;
      });
      const groups = hiding ? cat.groups.filter((g) => g.visible.length) : cat.groups;
      const all = groups.flatMap((g) => g.visible);
      // Suivi shows with no groups too, so its + and dropping on its bar can start the first one.
      const exists = cat.id === "mine" || groups.length > 0;
      if (!exists || (hiding && !all.length)) return null;
      const catOpen = searchOn || S.open.categories[cat.id];
      const groupNodes = catOpen ? groups.map((g) => {
        const open = searchOn || isOpenGroup(g);
        // Search and filters only list quests, which are already in their groups, so they hide the moved lines.
        const rows = hiding || g.group
          ? g.visible.map((q, i, list) => questRow(q, { group: g.group, last: i === list.length - 1 }))
          : g.entries.map((e, i, list) => (e.moved ? movedLine(e.q, i === list.length - 1) : questRow(e.q, { group: null, last: i === list.length - 1 })));
        return h("div", { class: "pt-groupwrap" + (g.group ? " mine" : ""), "data-key": "wrap-" + g.key },
          groupHeader(g, cat),
          open ? rows : null);
      }) : null;
      const node = h("section", { class: "pt-cat", "data-key": "cat-" + cat.id, style: gap ? `margin-top:${Bench.tokens.barGap}px` : "" },
        categoryBar(cat, all),
        groupNodes);
      return { node, all };
    };
    const [mine, ...logCategories] = tree;
    const mineSection = section(mine, false);
    const logSections = logCategories.map((cat) => section(cat, true)).filter(Boolean);
    const out = mineSection ? [mineSection.node] : [];
    if (logSections.length) {
      const logQuests = logSections.flatMap((s) => s.all);
      out.push(h("section", { class: "pt-cat pt-journal", "data-key": "cat-journal", style: out.length ? `margin-top:${Bench.tokens.barGap}px` : "" },
        categoryBar({ id: "journal" }, logQuests),
        searchOn || S.open.categories.journal ? logSections.map((s) => s.node) : null));
    }
    return { nodes: out, totalShown, total, hiding, searchOn };
  }

  // The closed padlock cut at its body's top edge: unlocking swings the shackle open on its right leg, Ikar's pick on
  // 2026-11-08. Locked, a second copy added on top makes it much brighter, as the gear's.
  function padlockArt() {
    const parts = [tex("communities-icon-lock", "pt-shackle", "", 14, 17), tex("communities-icon-lock", "pt-lockbody", "", 14, 17)];
    return locked() ? [...parts, tex("communities-icon-lock", "pt-lock-add", "", 14, 17)] : parts;
  }

  function titleRow() {
    return h("div", { class: "ot-title", "data-key": "title", style: `margin-top:${timerRoom()}px` },
      tex("ui-questtracker-primary-objective-header", "bar-bg", "", Bench.settings.width + 40, 40),
      h("div", { class: "ot-title-text" }, "Tous les objectifs"),
      h("div", { class: "pt-tools", "data-key": "tools" },
        h("div", { class: "pt-tool pt-gear" + (Game.inCombat ? " disabled" : ""), "data-action": "settings", "data-tip": "settings", "data-key": "gear" },
          tex("questlog-icon-setting", "", "", 15, 16),
          // The game has no bright gear, so a second copy is added on top, as the template's own highlight does.
          Game.inCombat ? null : tex("questlog-icon-setting", "pt-gear-add", "", 15, 16)),
        h("div", {
          class: "pt-lock" + (locked() ? " shut" : " open") + (S.lockFlash ? ` flash${S.lockFlash % 2}` : ""),
          "data-action": "lock", "data-tip": "lock", "data-key": "lock",
        }, padlockArt()),
        h("div", { class: "pt-tool" + (S.searchOpen || searching() ? " active" : ""), "data-action": "search", "data-tip": "search-btn", "data-key": "search" },
          tex("common-search-magnifyingglass", "", "", 16, 16)),
        h("div", { class: "pt-tool pt-filter" + (filtering() ? " active" : ""), "data-action": "filter", "data-tip": "filter-btn", "data-key": "filter" },
          tex("gamepad-hud-icon-filter", "", "", 14, 14)),
        // Collapse-all is the bars' double arrow, Ikar's ruling on 2026-11-07, not Blizzard's red button.
        h("div", { class: "pt-tool pt-min", "data-action": "collapse-all", "data-key": "min" }, toggleArrow(S.open.tracker))));
  }

  function render() {
    if (!S.root) return;
    const list = renderList();
    const topExtra = timerRoom();
    const popups = Game.popups.map(UI.popup).filter(Boolean);
    const hasContent = Game.order.length > 0;
    const showStatus = S.open.tracker && list.hiding;
    // Suivi tucks under the title. The search box, status and popups would overlap it, so with any of them it's Blizzard's 6.
    const fixedShown = S.searchOpen || showStatus || popups.length > 0;
    const gap = fixedShown ? Math.max(6, Bench.tokens.titleGap) : Bench.tokens.titleGap;
    const bodyTop = 32 + gap + topExtra;
    // The list reaches 6 above its first bar for the bar's art. Tucked under the title, scrolled rows stop at the title's lower edge.
    S.scrollInset = fixedShown ? 0 : Math.max(0, 6 - gap);
    const statusText = list.totalShown === 0
      ? "Aucun résultat trouvé"
      : `${list.totalShown} quête${list.totalShown > 1 ? "s" : ""} affichée${list.totalShown > 1 ? "s" : ""} sur ${list.total}`;
    const tree = h("div", { class: "ot prop" + (Game.inCombat ? " in-combat" : "") + (Bench.settings.shareOnHover ? " share-on-hover" : ""), style: `height:${Bench.settings.height}px;opacity:${trackerOpacity()};--aq-scale:${fullScale(236)};--qt-scale:${fullScale(158)}` },
      h("div", { class: "ot-nine", style: `opacity:${Bench.settings.opacity / 100}` }),
      UI.timerPanel(),
      hasContent ? titleRow() : null,
      hasContent && S.open.tracker ? h("div", { class: "pt-body", "data-key": "body", style: `top:${bodyTop}px;height:${Bench.settings.height - bodyTop}px` },
        h("div", { class: "pt-fixed", "data-key": "fixed" },
          S.searchOpen ? h("div", { class: "pt-search", "data-key": "searchbox" },
            tex("common-search-magnifyingglass", "pt-search-icon", "", 14, 14),
            h("input", { class: "pt-search-input", "data-key": "input", placeholder: "Recherche", value: S.search }),
            S.search ? h("div", { class: "pt-search-clear", "data-action": "search-clear", "data-key": "clear", style: atlasCss("common-search-clearbutton", 14, 14) }) : null) : null,
          showStatus ? h("div", { class: "pt-status", "data-key": "status" },
            statusText, " · ",
            h("span", { class: "pt-link", "data-action": "clear-all", "data-key": "clear" }, "Tout effacer")) : null,
          popups.length ? h("div", { class: "pt-popups", "data-key": "popups" }, popups) : null),
        h("div", { class: "pt-scroll", "data-key": "scroll", style: S.scrollInset ? `clip-path:inset(${S.scrollInset}px 0 0 0)` : "" }, h("div", { class: "pt-scroll-inner", "data-key": "inner" }, list.nodes)),
        scrollbar()) : null);
    UI.morph(S.root, tree);
    afterLayout();
  }

  function scrollbar() {
    return h("div", { class: "pt-sb" + (S.scrolling ? " scrolling" : ""), "data-key": "sb" },
      h("div", { class: "pt-sb-up", "data-action": "sb-up", "data-key": "up" },
        tex("minimal-scrollbar-arrow-top", "n"), tex("minimal-scrollbar-arrow-top-over", "o")),
      h("div", { class: "pt-sb-track", "data-key": "track" },
        tex("minimal-scrollbar-track-top", "cap-top"),
        h("div", { class: "pt-sb-track-mid tex", "data-key": "mid" }),
        tex("minimal-scrollbar-track-bottom", "cap-bottom"),
        h("div", { class: "pt-sb-thumb", "data-key": "thumb" },
          tex("minimal-scrollbar-small-thumb-top", "t n"), tex("minimal-scrollbar-small-thumb-top-over", "t o"),
          h("div", { class: "m tex", "data-key": "m" }),
          tex("minimal-scrollbar-small-thumb-bottom", "b n"), tex("minimal-scrollbar-small-thumb-bottom-over", "b o"))),
      h("div", { class: "pt-sb-down", "data-action": "sb-down", "data-key": "down" },
        tex("minimal-scrollbar-arrow-bottom", "n"), tex("minimal-scrollbar-arrow-bottom-over", "o")));
  }

  const trackerOpacity = () => (Game.inCombat ? Bench.settings.opacityCombat : Bench.settings.opacityRest) / 100;

  function afterLayout() {
    // A redraw mustn't undo what a drag has marked.
    if (S.drag && S.drag.dimmed) S.drag.dimmed.forEach((el) => el.classList.add("dragging"));
    // Only rows on screen stay picked: a closed group, a search or a quest leaving drops them.
    S.picked.forEach((id) => { if (!S.root.querySelector(`.pt-row[data-quest="${id}"]`)) S.picked.delete(id); });
    if (S.drag && S.drag.drop && S.drag.drop.into) S.drag.drop.into.classList.add("drop-into");
    S.root.classList.toggle("drop-targets", !!(S.drag && S.drag.active && S.drag.kind === "quest"));
    const width = Bench.settings.width;
    UI.fitHeader(S.root.querySelector(".ot-title-text"), width - 110);
    S.root.querySelectorAll(".pt-bar").forEach((bar) => {
      UI.fitHeader(bar.querySelector(".pt-bar-text"), width - 7 - 20 - bar.querySelector(".pt-bar-right").offsetWidth - 6);
    });
    updateScrollbar();
    syncSecure();
    applyNine();
    const input = S.root.querySelector(".pt-rename");
    if (input && document.activeElement !== input) { input.focus(); input.select(); }
  }

  function applyNine() {
    const nine = S.root.querySelector(".ot-nine");
    const scroll = S.root.querySelector(".pt-scroll");
    if (!scroll) { nine.style.height = "42px"; return; }
    const z = UI.scaleOf(S.root);
    const top = S.root.getBoundingClientRect().top;
    const inner = scroll.querySelector(".pt-scroll-inner").getBoundingClientRect();
    const bottom = Math.min(inner.bottom, scroll.getBoundingClientRect().bottom);
    nine.style.height = (bottom - top) / z + 10 + "px";
  }

  // Scrolling

  function updateScrollbar() {
    const scroll = S.root.querySelector(".pt-scroll");
    const sb = S.root.querySelector(".pt-sb");
    if (!scroll || !sb) return;
    const body = S.root.querySelector(".pt-body");
    const fixed = S.root.querySelector(".pt-fixed");
    const z = UI.scaleOf(S.root);
    const contentH = scroll.scrollHeight;
    const viewH = scroll.clientHeight;
    const over = contentH > viewH + 1;
    sb.style.display = over ? "" : "none";
    if (!over) { scroll.scrollTop = 0; return; }
    const top = (scroll.getBoundingClientRect().top - body.getBoundingClientRect().top) / z + S.scrollInset;
    const barH = viewH - S.scrollInset;
    sb.style.top = top + "px";
    sb.style.height = barH + "px";
    const track = sb.querySelector(".pt-sb-track");
    const trackH = barH - 2 * 15;
    track.style.height = trackH + "px";
    sb.querySelector(".pt-sb-track-mid").setAttribute("style", atlasCss("!minimal-scrollbar-track-middle", 8, Math.max(0, trackH - 16)));
    const thumbH = Math.max(23, Math.round((viewH / contentH) * trackH));
    const thumb = sb.querySelector(".pt-sb-thumb");
    thumb.style.height = thumbH + "px";
    thumb.querySelector(".m").setAttribute("style", atlasCss("minimal-scrollbar-small-thumb-middle", 8, Math.max(0, thumbH - 16)));
    const span = trackH - thumbH;
    thumb.style.top = Math.round((scroll.scrollTop / (contentH - viewH)) * span) + "px";
    fixed.dataset.over = "1";
  }

  function scrollBy(dy) {
    const scroll = S.root.querySelector(".pt-scroll");
    if (!scroll) return;
    // Scrolling moves rows away from their item buttons, which is only a problem in combat. The player's own lock allows it.
    if (Game.inCombat && refusedByLock()) return;
    scroll.scrollTop += dy;
    showScrollbar();
    updateScrollbar();
    syncSecure();
  }

  // The bar is invisible unless the list is scrolling or the pointer is on it.
  function showScrollbar() {
    const setShown = (on) => {
      S.scrolling = on;
      const sb = S.root.querySelector(".pt-sb");
      if (sb) sb.classList.toggle("scrolling", on);
    };
    setShown(true);
    clearTimeout(S.scrollbarTimer);
    S.scrollbarTimer = setTimeout(() => setShown(false), 800);
  }

  // Item buttons sit over their rows and never inside them, as in the plan's Combat section. Out of combat they
  // follow each layout. In combat they can't move, show or hide, so they stay where they were.
  function syncSecure() {
    const layer = S.layer;
    const scroll = S.root.querySelector(".pt-scroll");
    const z = UI.scaleOf(S.root);
    const rootBox = layer.getBoundingClientRect();
    const view = scroll ? scroll.getBoundingClientRect() : null;
    const viewTop = view ? view.top + S.scrollInset * z : 0;
    const slots = new Map();
    S.root.querySelectorAll("[data-slot]").forEach((slot) => {
      const r = slot.getBoundingClientRect();
      const visible = view && r.top >= viewTop - 1 && r.bottom <= view.bottom + 1 && r.width > 0;
      slots.set(Number(slot.dataset.slot), { el: slot, visible, x: (r.left - rootBox.left) / z, y: (r.top - rootBox.top) / z });
    });

    // Changing the bench itself, such as its scale or height, isn't a game event, so it repositions them even in combat.
    if (!Game.inCombat || S.benchChanged) {
      S.benchChanged = false;
      const previous = S.secure;
      S.secure = new Map();
      slots.forEach((s, id) => { if (s.visible) S.secure.set(id, { x: s.x, y: s.y }); });
      // A button whose row closed during this fight stays on screen until combat ends.
      if (Game.inCombat) previous.forEach((pos, id) => { if (!S.secure.has(id)) S.secure.set(id, pos); });
    }

    const nodes = [];
    S.secure.forEach((pos, id) => {
      const q = Game.quests.get(id);
      if (!q || !q.item) return;
      const s = slots.get(id);
      const aligned = s && s.visible && Math.abs(s.x - pos.x) < 1 && Math.abs(s.y - pos.y) < 1;
      if (aligned) s.el.classList.add("covered");
      nodes.push(UI.itemButton(q, {
        key: "sec" + id,
        style: `left:${pos.x}px;top:${pos.y}px;${aligned ? "" : "opacity:.45;"}`,
      }));
    });
    // Item buttons aren't the tracker's children, so they follow its opacity separately. SetAlpha isn't protected.
    UI.morph(layer, h("div", { class: "secure-layer" + (Bench.settings.showSecure ? " show-secure" : ""), style: `opacity:${trackerOpacity()}` }, nodes));
  }

  // Actions

  function toggleCategory(id) {
    S.open.categories[id] = !S.open.categories[id];
    Game.log("sound", "IG_MAINMENU_OPTION_CHECKBOX_ON");
    save();
    render();
  }

  function toggleGroupKey(key) {
    if (key[0] === "g") {
      const id = Number(key.slice(1));
      S.open.groups[id] = !S.open.groups[id];
    } else {
      const name = key.slice(1);
      S.open.headers[name] = !S.open.headers[name];
    }
    Game.log("sound", "IG_MAINMENU_OPTION_CHECKBOX_ON");
    save();
    render();
  }

  function flash(key, ms) {
    S.flash[key] = true;
    setTimeout(() => { delete S.flash[key]; render(); }, ms || 900);
  }

  function parentsOf(id) {
    const q = Game.quests.get(id);
    const g = groupOf(id);
    return g ? { cat: "mine", key: "g" + g.id } : { cat: q.category, key: "h" + q.header };
  }

  function openParents(id) {
    const p = parentsOf(id);
    S.open.categories[p.cat] = true;
    if (p.cat !== "mine") S.open.categories.journal = true;
    if (p.key[0] === "g") S.open.groups[Number(p.key.slice(1))] = true;
    else S.open.headers[p.key.slice(1)] = true;
    save();
  }

  function parentsOpen(id) {
    const p = parentsOf(id);
    const groupOpen = p.key[0] === "g" ? S.open.groups[Number(p.key.slice(1))] : S.open.headers[p.key.slice(1)];
    return (p.cat === "mine" || S.open.categories.journal) && S.open.categories[p.cat] && groupOpen;
  }

  function flashParents(id) {
    const p = parentsOf(id);
    flash(p.key);
    flash("c" + p.cat);
    if (p.cat !== "mine") flash("cjournal");
  }

  function applyPendingFocus() {
    if (!S.pendingFocus || locked()) return;
    openParents(S.pendingFocus);
    S.pendingFocus = 0;
  }

  // Several quests move together, in the order given, so picked ones stay side by side where they land.
  function moveQuests(ids, groupID, index) {
    S.groups.forEach((g) => { g.quests = g.quests.filter((x) => !ids.includes(x)); });
    const g = S.groups.find((x) => x.id === groupID);
    if (g) {
      g.quests.splice(index === undefined || index > g.quests.length ? g.quests.length : index, 0, ...ids);
      S.open.categories.mine = true;
      flash("g" + g.id);
    }
    // Being in one of the player's groups is what tracked means. Past the game's limit of 25, the quest still stays in its group.
    ids.forEach((id) => Game.toggleWatch(id, !!g));
    save();
    render();
  }

  function moveQuest(id, groupID, index) {
    moveQuests([id], groupID, index);
  }

  // The picked quests in the order their rows are drawn.
  function pickedInOrder() {
    return [...S.root.querySelectorAll(".pt-row")].map((r) => Number(r.dataset.quest)).filter((id) => S.picked.has(id));
  }

  // The bench has no game list to keep between reloads, so its layout decides.
  function syncWatch() {
    Game.setWatch(S.groups.flatMap((g) => g.quests));
  }

  // A quest the game has started tracking goes to the top group. With no groups, it starts one.
  function placeTracked(id) {
    let target = S.groups[0];
    if (!target) {
      target = { id: S.nextGroupID++, name: FIRST_GROUP_NAME, quests: [] };
      S.groups.push(target);
      S.open.categories.mine = true;
      S.open.groups[target.id] = true;
    }
    target.quests.push(id);
    if (!parentsOpen(id)) flashParents(id);
  }

  function track(id) {
    trackAll([id]);
  }

  function trackAll(ids) {
    ids.forEach((id) => {
      placeTracked(id);
      Game.toggleWatch(id, true);
    });
    save();
    render();
  }

  // The list can change and change back within a frame, as DialogueUI does to wake other addons, so only where it ends up counts.
  function watchChanged(id) {
    S.watchDirty.add(id);
    clearTimeout(S.watchTimer);
    S.watchTimer = setTimeout(settleWatch, 0);
  }

  function settleWatch() {
    if (Game.inCombat) return;
    S.watchDirty.forEach((id) => {
      if (!Game.quests.has(id)) return;
      const watched = Game.watch.includes(id);
      const g = groupOf(id);
      if (watched && !g) placeTracked(id);
      else if (!watched && g) g.quests = g.quests.filter((x) => x !== id);
    });
    S.watchDirty.clear();
    save();
    render();
  }

  // questIDs: one quest, several, or none.
  function newGroup(questIDs) {
    const id = S.nextGroupID++;
    S.groups.push({ id, name: "Nouveau groupe", quests: [] });
    S.open.categories.mine = true;
    S.open.groups[id] = true;
    S.renaming = id;
    if (questIDs) moveQuests([].concat(questIDs), id); else { save(); render(); }
  }

  function askDelete(group) {
    if (refusedInCombat()) return;
    const doDelete = () => {
      if (refusedInCombat()) return;
      S.deleted = { group, index: S.groups.indexOf(group), open: !!S.open.groups[group.id] };
      S.groups = S.groups.filter((g) => g !== group);
      group.quests.forEach((id) => Game.toggleWatch(id, false));
      save();
      render();
    };
    if (!group.quests.length) return doDelete();
    const overlay = S.root.closest(".stage").querySelector(".overlay");
    overlay.querySelectorAll(".dialog").forEach((d) => d.remove());
    const box = h("div", { class: "dialog" },
      h("div", null, `Supprimer le groupe « ${group.name} » ? Ses quêtes reprennent leur place automatique et ne sont plus suivies.`),
      h("div", { class: "dialog-btns" },
        h("button", { "data-ok": "1" }, "Accepter"),
        h("button", null, "Annuler")));
    box.addEventListener("click", (e) => {
      if (e.target.tagName !== "BUTTON") return;
      if (e.target.dataset.ok) doDelete();
      box.remove();
    });
    overlay.append(box);
  }

  // Its quests come back unless they've joined another group since, and are tracked again.
  function undoDelete() {
    const d = S.deleted;
    if (!d || refusedInCombat()) return;
    S.deleted = null;
    const group = { ...d.group, quests: d.group.quests.filter((id) => !groupOf(id)) };
    S.groups.splice(Math.min(d.index, S.groups.length), 0, group);
    S.open.groups[group.id] = d.open;
    group.quests.filter((id) => Game.quests.has(id)).forEach((id) => Game.toggleWatch(id, true));
    flash("g" + group.id);
    save();
    render();
  }

  // Key bindings, unbound by default as addon bindings are. Each does what its click does.
  function binding(name) {
    if (name === "lock") toggleLock();
    else if (name === "collapse-all") toggleAll();
    else stepGroup(name === "next" ? 1 : -1);
  }

  // Opens the player's next or previous group and closes the others, as the eye does.
  function stepGroup(dir) {
    if (!S.groups.length || refusedByLock()) return;
    const current = S.groups.findIndex((g) => S.open.groups[g.id]);
    const from = current < 0 ? (dir > 0 ? -1 : 0) : current;
    const target = S.groups[(from + dir + S.groups.length) % S.groups.length];
    S.open.tracker = true;
    S.open.categories.mine = true;
    focusGroup("g" + target.id);
  }

  function toggleLock() {
    if (Game.inCombat) {
      S.unlocked = !S.unlocked;
      Game.log("note", S.unlocked ? "Unlocked until this fight ends" : "Locked again");
    } else {
      S.locked = !S.locked;
      Game.log("note", S.locked ? "Locked" : "Unlocked");
      save();
      applyPendingFocus();
    }
    render();
  }

  function toggleAll() {
    if (refusedByLock()) return;
    S.open.tracker = !S.open.tracker;
    Game.log("sound", "IG_MAINMENU_OPTION_CHECKBOX_ON");
    save();
    render();
  }

  // Menus

  function questMenu(q, e) {
    const g = groupOf(q.id);
    const guard = (fn) => () => { if (!refusedInCombat()) fn(); };
    UI.openMenu(S.root, e.clientX, e.clientY, [
      { title: q.title },
      { text: Game.superTracked === q.id ? "Supprimer le marquage" : "Focalisation", onClick: () => Game.superTrack(q.id) },
      { text: "Ouvrir les détails de la quête", onClick: guard(() => openDetails(q)) },
      { text: "Ouvrir la carte des quêtes", onClick: guard(() => openDetails(q)) },
      q.pushable && Game.partySize > 1 ? { text: "Partage de quête", onClick: () => Game.share(q.id) } : null,
      { divider: true },
      { text: "Déplacer vers", sub: [
        ...S.groups.map((x) => ({ text: x.name, disabled: g === x, onClick: guard(() => moveQuest(q.id, x.id)) })),
        { text: "Nouveau groupe", onClick: guard(() => newGroup(q.id)) },
      ] },
      g ? { text: "Arrêter le suivi", onClick: guard(() => moveQuest(q.id, null)) } : { text: "Suivre quête", onClick: guard(() => track(q.id)) },
      { divider: true },
      { text: "Abandon", onClick: () => Game.abandon(q.id) },
    ].filter(Boolean));
  }

  // The menu of a picked row while several are picked: what makes sense for them all. No abandon: the game asks for
  // each quest on its own.
  function pickedMenu(ids, e) {
    const guard = (fn) => () => { if (!refusedInCombat()) fn(); };
    const tracked = ids.filter((id) => groupOf(id));
    const loose = ids.filter((id) => !groupOf(id));
    const shareable = Game.partySize > 1 ? ids.filter((id) => Game.quests.get(id).pushable) : [];
    UI.openMenu(S.root, e.clientX, e.clientY, [
      { title: `${ids.length} quêtes sélectionnées` },
      { text: "Déplacer vers", sub: [
        ...S.groups.map((x) => ({ text: x.name, onClick: guard(() => moveQuests(ids, x.id)) })),
        { text: "Nouveau groupe", onClick: guard(() => newGroup(ids)) },
      ] },
      loose.length ? { text: "Suivre ces quêtes", onClick: guard(() => trackAll(loose)) } : null,
      tracked.length ? { text: "Arrêter le suivi", onClick: guard(() => moveQuests(tracked, null)) } : null,
      shareable.length ? { text: "Partager ces quêtes", onClick: () => shareable.forEach((id) => Game.share(id)) } : null,
      { divider: true },
      { text: "Désélectionner", onClick: () => { S.picked.clear(); render(); } },
    ].filter(Boolean));
  }

  // Focuses a group: it opens, and every other group closes. The menu's Fermer les autres and the eye on each group both do this.
  function closeOthers(key) {
    if (refusedByLock()) return;
    focusGroup(key);
  }

  function focusGroup(key) {
    S.groups.forEach((g) => { S.open.groups[g.id] = "g" + g.id === key; });
    Object.keys(S.open.headers).forEach((n) => { S.open.headers[n] = "h" + n === key; });
    if (key[0] === "h") S.open.headers[key.slice(1)] = true;
    save();
    render();
  }

  function groupMenu(key, e) {
    if (key[0] === "g") {
      const group = S.groups.find((g) => "g" + g.id === key);
      UI.openMenu(S.root, e.clientX, e.clientY, [
        { title: group.name },
        { text: "Renommer", onClick: () => { S.renaming = group.id; render(); } },
        { text: "Nouveau groupe", onClick: () => { if (!refusedInCombat()) newGroup(); } },
        { text: "Fermer les autres", onClick: () => closeOthers(key) },
        { divider: true },
        { text: "Supprimer le groupe", onClick: () => askDelete(group) },
      ]);
    } else {
      UI.openMenu(S.root, e.clientX, e.clientY, [
        { title: key.slice(1) },
        { text: "Fermer les autres", onClick: () => closeOthers(key) },
      ]);
    }
  }

  function barMenu(id, e) {
    const setAll = (open) => {
      if (refusedByLock()) return;
      S.open.categories[id] = open;
      buildTree().filter((c) => (id === "journal" ? c.id !== "mine" : c.id === id)).forEach((cat) => {
        S.open.categories[cat.id] = open;
        cat.groups.forEach((g) => {
          if (g.group) S.open.groups[g.group.id] = open;
          else S.open.headers[g.name] = open;
        });
      });
      save();
      render();
    };
    UI.openMenu(S.root, e.clientX, e.clientY, [
      { title: CATEGORIES[id] },
      { text: "Tout ouvrir", onClick: () => setAll(true) },
      { text: "Tout fermer", onClick: () => setAll(false) },
      id === "mine" ? { text: "Nouveau groupe", onClick: () => { if (!refusedInCombat()) newGroup(); } } : null,
    ].filter(Boolean));
  }

  function filterMenu(anchor) {
    const r = anchor.getBoundingClientRect();
    const quests = Game.order.map((id) => Game.quests.get(id));
    const items = [];
    for (const f of FILTERS) {
      const counts = new Map();
      quests.forEach((q) => f.values(q).filter(Boolean).forEach((v) => counts.set(v, (counts.get(v) || 0) + 1)));
      const ticked = S.filters[f.id] || {};
      if (counts.size < 2 && !Object.keys(ticked).length) continue;
      items.push({ title: f.label });
      const entries = [...counts.entries()];
      if (f.order) entries.sort((a, b) => f.order.indexOf(a[0]) - f.order.indexOf(b[0]));
      entries.forEach(([value, count]) => items.push({
        text: value, count, checkbox: true, checked: !!ticked[value], keepOpen: true,
        onClick: () => {
          const set = S.filters[f.id] || (S.filters[f.id] = {});
          if (set[value]) delete set[value]; else set[value] = true;
          save();
          render();
          filterMenu(S.root.querySelector(".pt-filter"));
        },
      }));
    }
    items.push({ divider: true }, { text: "Tout effacer", disabled: !filtering(), onClick: () => { S.filters = {}; save(); render(); } });
    UI.openMenu(S.root, r.left, r.bottom + 2, items);
  }

  // Like the quest log's own gear: the undo of a deleted group while there is one, a few switches, then the addon's
  // page in the game's options, its diagnostics and the bug report, which on the bench only log their call. A deleted
  // group leaves no line: Ikar's ruling on 2026-11-08.
  function gearMenu() {
    const r = S.root.querySelector(".pt-gear").getBoundingClientRect();
    const toggle = (id) => () => { Bench.setSetting(id, !Bench.settings[id]); gearMenu(); };
    const undo = S.deleted ? [{ text: `Annuler la suppression de « ${S.deleted.group.name} »`, onClick: undoDelete }, { divider: true }] : [];
    const menu = UI.openMenu(S.root, r.left, r.bottom + 2, [
      ...undo,
      { text: "Suivi automatique de quête", checkbox: true, checked: Bench.settings.autoQuestWatch, keepOpen: true, onClick: toggle("autoQuestWatch") },
      { text: "Lueur lors d'une progression", checkbox: true, checked: Bench.settings.progressFlash, keepOpen: true, onClick: toggle("progressFlash") },
      { text: "Signaler les quêtes de la zone", checkbox: true, checked: Bench.settings.areaHighlight, keepOpen: true, onClick: toggle("areaHighlight") },
      { divider: true },
      { text: "Options", onClick: () => { Game.log("call", "Settings.OpenToCategory(categoryID)"); Bench.revealOptions(); } },
      { text: "Diagnostic", onClick: () => Game.log("call", "ns.DebugPanel.Open()") },
      { text: "Signaler un bug", onClick: () => Game.log("call", "ns.Report.Open()") },
    ]);
    menu.classList.add("gear-menu");
  }

  // Events

  function click(e) {
    if (S.justDragged) { S.justDragged = false; return; }
    const target = e.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    const q = Game.quests.get(Number(target.dataset.quest));
    switch (action) {
      case "collapse-all":
        toggleAll();
        break;
      case "toggle-cat":
        if (e.target.closest("input")) return;
        if (refusedByLock()) return;
        toggleCategory(target.dataset.cat);
        break;
      case "toggle-group":
        if (e.target.closest("input")) return;
        if (refusedByLock()) return;
        toggleGroupKey(target.dataset.groupkey);
        break;
      case "focus-group":
        closeOthers(target.dataset.groupkey);
        break;
      case "new-group":
        if (refusedInCombat() || refusedByLock()) return;
        newGroup();
        break;
      case "lock":
        toggleLock();
        break;
      case "search":
        if (refusedInCombat()) return;
        S.searchOpen = !S.searchOpen;
        if (!S.searchOpen) S.search = "";
        render();
        if (S.searchOpen) S.root.querySelector(".pt-search-input").focus();
        break;
      case "settings":
        // The options panel can't open in combat. It changes nothing in the tracker, so the lock doesn't stop it.
        if (refusedInCombat()) return;
        gearMenu();
        break;
      case "search-clear":
        S.search = "";
        S.searchOpen = false;
        render();
        break;
      case "filter":
        if (refusedInCombat()) return;
        filterMenu(target);
        break;
      case "clear-all":
        S.search = "";
        S.searchOpen = false;
        S.filters = {};
        save();
        render();
        break;
      case "poi":
        if (!q) return;
        // POIButton.lua tracks an untracked quest before focusing it, so this one joins a group.
        if (!groupOf(q.id) && !refusedInCombat()) track(q.id);
        Game.superTrack(q.id);
        break;
      case "share":
        if (q) Game.share(q.id);
        break;
      case "spoken":
        if (q) Game.speak(q.id);
        break;
      case "bring-back":
        if (!q || refusedInCombat()) return;
        flash("q" + q.id);
        moveQuest(q.id, null);
        break;
      case "item":
        if (q) Game.useItem(q.id, true);
        break;
      case "eye":
        if (q) Game.log("call", `LFGListUtil_FindQuestGroup(${q.id})`);
        break;
      case "popup":
        if (!q) return;
        Game.log("call", q.complete ? `ShowQuestComplete(${q.id})` : `ShowQuestOffer(${q.id})`);
        Game.removePopup(q.id);
        if (q.complete) Game.turnIn(q.id);
        break;
      case "title":
        if (!q) return;
        // Ctrl+click picks or unpicks a row. It moves nothing, so combat and the padlock allow it.
        if (e.ctrlKey && target.classList.contains("pt-row")) {
          if (S.picked.has(q.id)) S.picked.delete(q.id); else S.picked.add(q.id);
          render();
          return;
        }
        if (S.picked.size) {
          S.picked.clear();
          render();
        }
        if (e.shiftKey) {
          if (refusedInCombat()) return;
          if (groupOf(q.id)) moveQuest(q.id, null); else track(q.id);
        } else if (q.isAutoComplete && q.complete) {
          Game.removePopup(q.id);
          Game.log("call", `ShowQuestComplete(${q.id})`);
          Game.turnIn(q.id);
        } else if (!refusedInCombat()) {
          openDetails(q);
        }
        break;
      case "sb-up":
        scrollBy(-40);
        break;
      case "sb-down":
        scrollBy(40);
        break;
      default:
    }
  }

  function contextmenu(e) {
    const el = e.target;
    const title = el.closest("[data-action='title']");
    const group = el.closest("[data-action='toggle-group']");
    const bar = el.closest("[data-action='toggle-cat']");
    if (!title && !group && !bar) return;
    e.preventDefault();
    const id = title && Number(title.dataset.quest);
    if (title && title.classList.contains("pt-row") && S.picked.has(id) && S.picked.size > 1) pickedMenu(pickedInOrder(), e);
    else if (title) questMenu(Game.quests.get(id), e);
    else if (group) groupMenu(group.dataset.groupkey, e);
    else barMenu(bar.dataset.cat, e);
  }

  function rowTooltip(title, q) {
    if (title.classList.contains("pt-moved")) return UI.showTooltip(title, [{ text: `Dans le groupe « ${groupOf(q.id).name} »`, color: "white" }], "left");
    const inMine = !!groupOf(q.id);
    const lines = [];
    markers(q, inMine).forEach((m) => lines.push({ text: m.label, color: "white" }));
    if (q.party) {
      lines.push({ text: "Membre du groupe à proximité sur cette quête :", color: "gold" });
      for (let i = 0; i < q.party; i++) lines.push({ text: `Compagnon ${i + 1}`, color: "white" });
    }
    if (q.pushable && Game.partySize > 1) lines.push({ text: "Partageable", color: "grey" });
    if (!S.groups.length) lines.push({ text: "Clic droit : Déplacer vers un groupe", color: "green" });
    if (!lines.length) return UI.hideTooltip(S.root);
    UI.showTooltip(title.closest(".ot-block"), lines, "left");
  }

  function hover(e) {
    const tip = e.target.closest("[data-tip]");
    const title = e.target.closest("[data-action='title']");
    if (tip) {
      const q = Game.quests.get(Number(tip.dataset.quest));
      const kind = tip.dataset.tip;
      if (kind === "item") return UI.itemTooltip(tip, q);
      if (kind === "eye") return UI.showTooltip(tip, [{ text: "Trouver un groupe", color: "white" }]);
      if (kind === "share") return UI.showTooltip(tip, [{ text: "Partage de quête", color: "white" }]);
      if (kind === "bring-back") return UI.showTooltip(tip, [{ text: "Remettre ici", color: "white" }]);
      if (kind === "focus") return UI.showTooltip(tip, [{ text: "Fermer les autres", color: "white" }]);
      if (kind === "new-group") return UI.showTooltip(tip, [{ text: "Nouveau groupe", color: "white" }]);
      if (kind === "search-btn") return UI.showTooltip(tip, [{ text: "Recherche", color: "white" }]);
      if (kind === "filter-btn") return UI.showTooltip(tip, [{ text: "Filtre", color: "white" }]);
      if (kind === "settings") return UI.showTooltip(tip, [{ text: "Options", color: "white" }]);
      if (kind === "lock") {
        const fight = Game.inCombat;
        return UI.showTooltip(tip, locked()
          ? [{ text: fight ? "Verrouillé en combat" : "Verrouillé", color: "white" }, { text: fight ? "Cliquer pour déverrouiller jusqu'à la fin du combat" : "Cliquer pour déverrouiller", color: "gold" }]
          : [{ text: fight ? "Déverrouillé pour ce combat" : "Déverrouillé", color: "white" }, { text: "Cliquer pour verrouiller", color: "gold" }]);
      }
    }
    if (title) return rowTooltip(title, Game.quests.get(Number(title.dataset.quest)));
    UI.hideTooltip(S.root);
  }

  function input(e) {
    if (e.target.classList.contains("pt-search-input")) {
      S.search = e.target.value;
      render();
    }
  }

  function keydown(e) {
    if (e.target.classList.contains("pt-rename")) {
      if (e.key === "Enter") { commitRename(e.target.value); e.preventDefault(); }
      else if (e.key === "Escape") { S.renaming = null; render(); }
    } else if (e.target.classList.contains("pt-search-input")) {
      if (e.key === "Escape") { S.search = ""; S.searchOpen = false; render(); }
      else if (e.key === "Enter") e.target.blur();
    }
  }

  function commitRename(value) {
    const name = value.trim();
    const group = S.groups.find((g) => g.id === S.renaming);
    S.renaming = null;
    if (group && name) group.name = name;
    save();
    render();
  }

  function focusout(e) {
    if (e.target.classList.contains("pt-rename") && S.renaming) commitRename(e.target.value);
  }

  // Dragging: quests into the player's groups, groups among themselves, bars among themselves.

  function pointerDown(e) {
    if (e.button !== 0) return;
    const thumb = e.target.closest(".pt-sb-thumb");
    if (thumb) return startThumbDrag(e);
    const source = e.target.closest("[data-drag]");
    if (!source || !source.dataset.drag || e.target.closest("input, .poi, .edge, .pt-arrow, .pt-add, .pt-focus")) return;
    S.drag = { kind: source.dataset.drag, source, startX: e.clientX, startY: e.clientY, active: false };
    window.addEventListener("mousemove", pointerMove);
    window.addEventListener("mouseup", pointerUp);
  }

  function startThumbDrag(e) {
    if (Game.inCombat && refusedByLock()) return;
    e.preventDefault();
    const scroll = S.root.querySelector(".pt-scroll");
    const startY = e.clientY;
    const startTop = scroll.scrollTop;
    const thumb = S.root.querySelector(".pt-sb-thumb");
    const track = S.root.querySelector(".pt-sb-track");
    const span = track.getBoundingClientRect().height - thumb.getBoundingClientRect().height;
    const range = scroll.scrollHeight - scroll.clientHeight;
    const move = (ev) => {
      scroll.scrollTop = startTop + ((ev.clientY - startY) / span) * range;
      showScrollbar();
      updateScrollbar();
      syncSecure();
    };
    const up = () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", up);
    };
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", up);
  }

  // A quest's whole box follows the cursor, held where it was grabbed. Groups and bars show their name.
  function dragGhost(d) {
    if (d.kind === "quest") {
      const z = UI.scaleOf(S.root);
      const r = d.source.getBoundingClientRect();
      d.grab = { x: (d.startX - r.left) / z, y: (d.startY - r.top) / z };
      const box = d.source.cloneNode(true);
      box.style.margin = "0";
      box.style.width = r.width / z + "px";
      return h("div", { class: "ot prop drag-box" }, box, d.ids.length > 1 ? h("div", { class: "drag-count" }, String(d.ids.length)) : null);
    }
    return h("div", { class: "drag-ghost" }, d.kind === "group" ? d.source.querySelector(".pt-group-name").textContent : d.source.querySelector(".ot-bar-text").textContent);
  }

  function pointerMove(e) {
    const d = S.drag;
    if (!d) return;
    if (!d.active) {
      if (Math.abs(e.clientX - d.startX) + Math.abs(e.clientY - d.startY) < 5) return;
      if (refusedInCombat()) { cancelDrag(); return; }
      if (refusedByLock()) {
        // Letting go shouldn't then count as a click on the row.
        S.justDragged = true;
        window.addEventListener("mouseup", () => setTimeout(() => { S.justDragged = false; }, 0), { once: true });
        cancelDrag();
        return;
      }
      d.active = true;
      // A picked row carries every picked quest with it. Any other row goes alone.
      if (d.kind === "quest") {
        const id = Number(d.source.closest(".pt-row").dataset.quest);
        d.ids = S.picked.has(id) && S.picked.size > 1 ? pickedInOrder() : [id];
      }
      const overlay = S.root.closest(".stage").querySelector(".overlay");
      d.ghost = dragGhost(d);
      d.line = h("div", { class: "drag-line" });
      overlay.append(d.ghost, d.line);
      d.dimmed = d.kind === "quest" ? d.ids.map((x) => S.root.querySelector(`.pt-row[data-quest="${x}"]`)).filter(Boolean)
        : [d.kind === "group" ? d.source.closest(".pt-groupwrap") : d.source.closest(".pt-cat")];
      d.dimmed.forEach((el) => el.classList.add("dragging"));
      S.root.classList.toggle("drop-targets", d.kind === "quest");
      UI.hideTooltip(S.root);
    }
    const overlay = S.root.closest(".stage").querySelector(".overlay");
    const box = overlay.getBoundingClientRect();
    const z = UI.scaleOf(S.root);
    d.ghost.style.left = (e.clientX - box.left) / z + (d.grab ? -d.grab.x : 12) + "px";
    d.ghost.style.top = (e.clientY - box.top) / z + (d.grab ? -d.grab.y : 4) + "px";
    d.drop = findDrop(d, e);
    S.root.querySelectorAll(".drop-into").forEach((x) => x.classList.remove("drop-into"));
    d.line.style.display = "none";
    if (d.drop) {
      if (d.drop.into) d.drop.into.classList.add("drop-into");
      if (d.drop.el) {
        const r = d.drop.el.getBoundingClientRect();
        d.line.style.display = "block";
        d.line.style.left = (r.left - box.left) / z + "px";
        d.line.style.width = r.width / z + "px";
        d.line.style.top = ((d.drop.after ? r.bottom : r.top) - box.top) / z - 1 + "px";
      }
    }
  }

  function findDrop(d, e) {
    const el = document.elementFromPoint(e.clientX, e.clientY);
    if (!el || !S.root.contains(el)) return null;
    if (d.kind === "quest") {
      // The whole of a player's group is one target, as it's all lit: its header, its rows and the gaps between them.
      const wrap = el.closest(".pt-groupwrap.mine");
      const row = el.closest(".pt-row");
      if (row && row.dataset.group) {
        const r = row.getBoundingClientRect();
        return { type: "row", el: row, into: wrap, group: Number(row.dataset.group), quest: Number(row.dataset.quest), after: e.clientY > r.top + r.height / 2 };
      }
      if (wrap) return { type: "group", into: wrap, group: Number(wrap.querySelector(".pt-group").dataset.groupkey.slice(1)) };
      const bar = el.closest(".pt-bar[data-cat='mine']");
      if (bar) return { type: "new", into: bar };
      return null;
    }
    if (d.kind === "group") {
      const groupEl = el.closest(".pt-group.mine");
      if (!groupEl || groupEl === d.source) return null;
      const r = groupEl.getBoundingClientRect();
      return { type: "reorder-group", el: groupEl, group: Number(groupEl.dataset.groupkey.slice(1)), after: e.clientY > r.top + r.height / 2 };
    }
    const bar = el.closest(".pt-subbar");
    if (!bar || bar === d.source) return null;
    const r = bar.getBoundingClientRect();
    return { type: "reorder-bar", el: bar, cat: bar.dataset.cat, after: e.clientY > r.top + r.height / 2 };
  }

  function cancelDrag() {
    const d = S.drag;
    if (d) {
      d.ghost && d.ghost.remove();
      d.line && d.line.remove();
      if (d.dimmed) d.dimmed.forEach((el) => el.classList.remove("dragging"));
    }
    S.root.querySelectorAll(".drop-into").forEach((x) => x.classList.remove("drop-into"));
    S.root.classList.remove("drop-targets");
    S.drag = null;
    window.removeEventListener("mousemove", pointerMove);
    window.removeEventListener("mouseup", pointerUp);
  }

  function pointerUp() {
    const d = S.drag;
    const wasActive = d && d.active;
    const drop = d && d.drop;
    const kind = d && d.kind;
    const source = d && d.source;
    const ids = d && d.ids;
    cancelDrag();
    if (!wasActive) return;
    S.justDragged = true;
    setTimeout(() => { S.justDragged = false; }, 0);
    if (!drop) return;
    if (kind === "quest") {
      if (drop.type === "group") moveQuests(ids, drop.group);
      else if (drop.type === "new") newGroup(ids);
      else if (drop.type === "row") {
        // Counted without the moving quests, so dropping on one of them leaves it where it was.
        const g = S.groups.find((x) => x.id === drop.group);
        const before = g.quests.slice(0, g.quests.indexOf(drop.quest)).filter((x) => !ids.includes(x)).length;
        moveQuests(ids, drop.group, before + (drop.after && !ids.includes(drop.quest) ? 1 : 0));
      }
    } else if (kind === "group") {
      const moving = S.groups.find((g) => "g" + g.id === source.dataset.groupkey);
      const rest = S.groups.filter((g) => g !== moving);
      rest.splice(rest.findIndex((g) => g.id === drop.group) + (drop.after ? 1 : 0), 0, moving);
      S.groups = rest;
      save();
      render();
    } else {
      const order = (S.categoryOrder || DEFAULT_ORDER).filter((c) => c !== source.dataset.cat);
      order.splice(order.indexOf(drop.cat) + (drop.after ? 1 : 0), 0, source.dataset.cat);
      S.categoryOrder = order;
      save();
      render();
    }
  }

  // Game events

  function onGame(event, detail) {
    if (event === "PLAYER_REGEN_ENABLED") {
      S.unlocked = false;
      S.lockFlash = 0;
      S.heldBack.clear();
      applyPendingFocus();
      settleWatch();
    } else if (event === "PLAYER_REGEN_DISABLED") {
      S.unlocked = false;
      if (S.drag) cancelDrag();
    } else if (event === "QUEST_ACCEPTED") {
      const id = Game.order[Game.order.length - 1];
      if (Game.inCombat) {
        S.heldBack.add(id);
      } else if (!parentsOpen(id)) {
        flashParents(id);
      }
    } else if (event === "QUEST_WATCH_LIST_CHANGED") {
      watchChanged(parseInt(detail, 10));
    } else if (event === "OBJECTIVE_PROGRESS" && Bench.settings.progressFlash) {
      flash("p" + detail, 700);
      if (!parentsOpen(detail)) flashParents(detail);
    } else if (event === "SUPER_TRACKING_CHANGED" && Game.superTracked) {
      if (locked()) S.pendingFocus = Game.superTracked;
      else openParents(Game.superTracked);
    } else if (event === "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED" && Bench.settings.areaHighlight) {
      const name = detail || "";
      if (name.endsWith("true")) {
        Game.insideArea.forEach((id) => {
          const q = Game.quests.get(id);
          if (!q || !name.startsWith(q.title)) return;
          flash("q" + id);
          flashParents(id);
        });
      }
    } else if (event === "RESET") {
      S.secure = new Map();
      S.heldBack.clear();
      S.unlocked = false;
      S.watchDirty.clear();
      syncWatch();
    }
    render();
  }

  function mount(el) {
    S.root = el;
    // On the stage rather than in the tracker, as secure buttons are on UIParent.
    S.layer = h("div", { class: "secure-layer" });
    el.parentElement.insertBefore(S.layer, el.nextSibling);
    S.layer.addEventListener("click", click);
    S.layer.addEventListener("mouseover", hover);
    S.layer.addEventListener("mouseleave", () => UI.hideTooltip(S.root));
    if (location.hash.includes("selftest") || !load()) preset("typical");
    else syncWatch();
    el.addEventListener("click", click);
    el.addEventListener("contextmenu", contextmenu);
    el.addEventListener("mouseover", hover);
    el.addEventListener("mouseleave", () => UI.hideTooltip(S.root));
    el.addEventListener("input", input);
    el.addEventListener("keydown", keydown);
    el.addEventListener("focusout", focusout);
    el.addEventListener("mousedown", pointerDown);
    // The title's buttons stay quiet until the pointer is over the tracker or its item buttons.
    [el, S.layer].forEach((x) => {
      x.addEventListener("mouseenter", () => el.parentElement.classList.add("tools-awake"));
      x.addEventListener("mouseleave", () => el.parentElement.classList.remove("tools-awake"));
    });
    el.addEventListener("wheel", (e) => {
      if (!e.target.closest(".pt-body")) return;
      const scroll = S.root.querySelector(".pt-scroll");
      if (!scroll || scroll.scrollHeight <= scroll.clientHeight) return;
      e.preventDefault();
      scrollBy(e.deltaY > 0 ? 40 : -40);
    }, { passive: false });
    Game.onChange(onGame);
    render();
  }

  return { mount, render, preset, binding, state: S };
})();
