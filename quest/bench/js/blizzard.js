// A reconstruction of Blizzard's objective tracker on Forever, quests only: the title, one "Quêtes" section,
// popups, tracked blocks and the timer panel. Numbers come from Blizzard_ObjectiveTracker in the forever branch.
window.BlizzardTracker = (function () {
  const { h, tex } = UI;
  const S = { collapsed: false, moduleCollapsed: false, root: null };

  function block(q) {
    const hasEye = q.canFindGroup && !q.complete;
    const hasItem = q.item && !(q.complete && !q.showItemWhenComplete);
    // AddRightEdgeFrame: eye first at TOPRIGHT 5, 2, then the item to its left. Lines narrow by the same amount.
    let right = 0;
    const frames = [];
    if (hasEye) {
      frames.push(h("div", { class: "edge", "data-key": "edge-eye", style: `top:-2px;right:-5px` }, UI.findGroupButton(q)));
      right = 5 - 30 - 2;
    }
    if (hasItem) {
      // Alone, at the block's TOPRIGHT. With the eye, RIGHT anchored to the eye's LEFT at -2, and centred on it.
      frames.push(h("div", { class: "edge", "data-key": "edge-item", style: `top:0;right:${hasEye ? 27 : 0}px` }, UI.itemButton(q)));
      right -= 26 + 2;
    }
    // Spoken anchors to the block's top right whatever else is there, and nothing narrows for it.
    if (UI.hasSpoken(q)) frames.push(UI.spokenButton(q, 0));
    const inner = 240 + right;
    const showPOI = Bench.settings.questPOI;
    const animating = q.anim === "turnin" ? " a-turnin" : q.anim === "add" ? " a-add" : "";
    return h("div", { class: "ot-block" + animating, "data-key": "q" + q.id, "data-quest": q.id, style: `--d:var(--diff-${Game.difficulty(q)});--dh:var(--diff-${Game.difficulty(q)}-hl)` },
      h("div", { class: "ot-head", "data-action": "title", "data-quest": q.id, style: `width:${inner}px` },
        showPOI ? UI.poiButton(q) : null,
        h("div", { class: "ot-head-text", "data-key": "text" },
          q.party ? h("span", { class: "ot-party" }, `[${q.party + 1}] `) : null,
          UI.titleText(q), UI.tintMark(q))),
      h("div", { class: "ot-lines", style: `width:${inner}px` }, Game.linesFor(q).map(UI.line)),
      frames,
      tex("ui-questtracker-objfx-barglow", "ot-headglow", "", 240, 20));
  }

  function render() {
    const tracked = Game.watch.map((id) => Game.quests.get(id)).filter(Boolean);
    const popups = Game.popups.map(UI.popup).filter(Boolean);
    const hasModule = tracked.length > 0 || popups.length > 0;
    const timer = UI.timerPanel();
    const topExtra = timer ? 43 + 16 * Game.timers.length + 10 : 0;
    const showBlocks = !S.collapsed && !S.moduleCollapsed;
    const tree = h("div", { class: "ot blizz", style: `height:${Bench.settings.height}px` },
      h("div", { class: "ot-nine", style: `opacity:${Bench.settings.opacity / 100}` }),
      timer,
      hasModule ? h("div", { class: "ot-title", "data-key": "title", style: `margin-top:${topExtra}px` },
        tex("ui-questtracker-primary-objective-header", "bar-bg"),
        h("div", { class: "ot-title-text" }, "Tous les objectifs"),
        h("div", { class: "btn-min", "data-action": "collapse-all", "data-key": "min" },
          tex(S.collapsed ? "ui-questtrackerbutton-expand-all" : "ui-questtrackerbutton-collapse-all", "up"),
          tex(S.collapsed ? "ui-questtrackerbutton-expand-all-pressed" : "ui-questtrackerbutton-collapse-all-pressed", "down"),
          tex("ui-questtrackerbutton-red-highlight", "hl"))) : null,
      hasModule && !S.collapsed ? h("div", { class: "ot-module", "data-key": "module" },
        h("div", { class: "ot-bar", "data-key": "bar" },
          tex("ui-questtracker-secondary-objective-header", "bar-bg"),
          h("div", { class: "ot-bar-text" }, "Quêtes"),
          h("div", { class: "btn-sec", "data-action": "collapse-module", "data-key": "min" },
            tex(S.moduleCollapsed ? "ui-questtrackerbutton-secondary-expand" : "ui-questtrackerbutton-secondary-collapse", "up"),
            tex(S.moduleCollapsed ? "ui-questtrackerbutton-secondary-expand-pressed" : "ui-questtrackerbutton-secondary-collapse-pressed", "down"),
            tex("ui-questtrackerbutton-yellow-highlight", "hl"))),
        showBlocks ? h("div", { class: "ot-contents", "data-key": "contents" }, popups, tracked.map(block)) : null) : null);
    UI.morph(S.root, tree);
    UI.fitHeader(S.root.querySelector(".ot-title-text"), 208);
    UI.fitHeader(S.root.querySelector(".ot-bar-text"), 200);
    truncate();
    applyNine();
  }

  // CanFitBlock: a block that doesn't fit is cut, along with everything after it.
  function truncate() {
    const contents = S.root.querySelector(".ot-contents");
    if (!contents) return;
    const limit = S.root.getBoundingClientRect().top + Bench.settings.height * UI.scaleOf(S.root);
    let cut = false;
    for (const b of contents.children) {
      b.style.display = "";
      if (cut || b.getBoundingClientRect().bottom > limit) {
        cut = true;
        b.style.display = "none";
      }
    }
  }

  // The background's bottom follows the last thing shown, at bottomModulePadding 10.
  function applyNine() {
    const nine = S.root.querySelector(".ot-nine");
    const items = [...S.root.querySelectorAll(".ot-block, .ot-bar, .ot-title")].filter((e) => e.style.display !== "none");
    const z = UI.scaleOf(S.root);
    const top = S.root.getBoundingClientRect().top;
    const bottom = items.reduce((m, e) => Math.max(m, e.getBoundingClientRect().bottom), top);
    nine.style.height = (bottom - top) / z + 10 + "px";
  }

  function menu(q, e) {
    const inGroup = Game.partySize > 1;
    UI.openMenu(S.root, e.clientX, e.clientY, [
      { title: q.title },
      { text: Game.superTracked === q.id ? "Supprimer le marquage" : "Focalisation", onClick: () => Game.superTrack(q.id) },
      { text: "Ouvrir les détails de la quête", onClick: () => UI.questPanel(S.root, q) },
      { text: "Ouvrir la carte des quêtes", onClick: () => UI.questPanel(S.root, q) },
      { text: "Arrêter le suivi", onClick: () => Game.toggleWatch(q.id, false) },
      q.pushable && inGroup ? { text: "Partage de quête", onClick: () => Game.share(q.id) } : null,
      { text: "Abandon", onClick: () => Game.abandon(q.id) },
    ].filter(Boolean));
  }

  function click(e) {
    const target = e.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;
    const q = Game.quests.get(Number(target.dataset.quest));
    if (action === "collapse-all") { S.collapsed = !S.collapsed; Game.log("sound", "IG_MAINMENU_OPTION_CHECKBOX_ON"); render(); }
    else if (action === "collapse-module") { S.moduleCollapsed = !S.moduleCollapsed; Game.log("sound", "IG_MAINMENU_OPTION_CHECKBOX_ON"); render(); }
    else if (action === "poi" && q) {
      if (e.shiftKey) Game.toggleWatch(q.id, false); else Game.superTrack(q.id);
    } else if (action === "item" && q) Game.useItem(q.id);
    else if (action === "eye" && q) Game.log("call", `LFGListUtil_FindQuestGroup(${q.id})`);
    else if (action === "spoken" && q) Game.speak(q.id);
    else if (action === "popup" && q) {
      Game.log("call", q.complete ? `ShowQuestComplete(${q.id})` : `ShowQuestOffer(${q.id})`);
      Game.removePopup(q.id);
      if (q.complete) Game.turnIn(q.id);
    } else if (action === "title" && q) {
      if (e.shiftKey) Game.toggleWatch(q.id, false);
      else if (q.isAutoComplete && q.complete) { Game.removePopup(q.id); Game.log("call", `ShowQuestComplete(${q.id})`); Game.turnIn(q.id); }
      else UI.questPanel(S.root, q);
    }
  }

  function contextmenu(e) {
    const target = e.target.closest("[data-action='title']");
    if (!target) return;
    e.preventDefault();
    menu(Game.quests.get(Number(target.dataset.quest)), e);
  }

  // Blizzard shows party progress on hover in a group, left of the block.
  function hover(e) {
    const tip = e.target.closest("[data-tip]");
    const title = e.target.closest("[data-action='title']");
    if (tip && tip.dataset.tip === "item") {
      UI.itemTooltip(tip, Game.quests.get(Number(tip.dataset.quest)));
    } else if (tip && tip.dataset.tip === "eye") {
      UI.showTooltip(tip, [{ text: "Trouver un groupe", color: "white" }]);
    } else if (title && Game.partySize > 1) {
      if (!UI.partyTooltip(title.closest(".ot-block"), Game.quests.get(Number(title.dataset.quest)))) UI.hideTooltip(S.root);
    } else {
      UI.hideTooltip(S.root);
    }
  }

  function mount(el) {
    S.root = el;
    el.addEventListener("click", click);
    el.addEventListener("contextmenu", contextmenu);
    el.addEventListener("mouseover", hover);
    el.addEventListener("mouseleave", () => UI.hideTooltip(S.root));
    Game.onChange(render);
    render();
  }

  return { mount, render, state: S };
})();
