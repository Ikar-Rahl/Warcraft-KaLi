// What both trackers share: DOM building and patching, atlases, and the pieces that are Blizzard's in both
// (map button, item button, objective lines), plus tooltips, menus and the red error text.
window.UI = (function () {
  const state = { artSet: "1" };

  function h(tag, attrs, ...children) {
    const el = document.createElement(tag);
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v === null || v === undefined || v === false) continue;
        if (k === "class") el.className = v;
        else if (k === "style") el.setAttribute("style", v);
        else if (k === "value") el.value = v;
        else el.setAttribute(k, v === true ? "" : v);
      }
    }
    for (const c of children.flat(Infinity)) {
      if (c === null || c === undefined || c === false) continue;
      el.append(c.nodeType ? c : document.createTextNode(String(c)));
    }
    return el;
  }

  // Patches `to` onto `from`, keeping elements by data-key so that CSS animations, hover and focus survive a redraw.
  function morph(from, to) {
    if (from.dataset && from.dataset.static !== undefined) return;   // Its animation was timed when it was created.
    for (const a of [...from.attributes]) if (a.name !== "id" && !to.hasAttribute(a.name)) from.removeAttribute(a.name);
    for (const a of [...to.attributes]) if (from.getAttribute(a.name) !== a.value) from.setAttribute(a.name, a.value);
    if (from.tagName === "INPUT" && from !== document.activeElement && from.value !== to.value) from.value = to.value;

    const live = [...from.childNodes];
    const wanted = [...to.childNodes];
    const keyed = new Map();
    live.forEach((n) => { if (n.nodeType === 1 && n.dataset.key) keyed.set(n.dataset.key, n); });
    let i = 0;
    for (const next of wanted) {
      let cur = from.childNodes[i];
      if (next.nodeType === 1 && next.dataset.key && keyed.has(next.dataset.key)) {
        const match = keyed.get(next.dataset.key);
        keyed.delete(next.dataset.key);
        if (match !== cur) from.insertBefore(match, cur || null);
        morph(match, next);
      } else if (cur && cur.nodeType === next.nodeType && cur.nodeName === next.nodeName && !(cur.nodeType === 1 && cur.dataset.key)) {
        if (cur.nodeType === 1) morph(cur, next);
        else if (cur.nodeValue !== next.nodeValue) cur.nodeValue = next.nodeValue;
      } else {
        from.insertBefore(next, cur || null);
      }
      i++;
    }
    while (from.childNodes.length > wanted.length) from.lastChild.remove();
  }

  function artOf(name) {
    const entry = window.ATLAS_DATA[name.toLowerCase()];
    if (!entry) { console.warn("Unknown atlas", name); return null; }
    return entry[state.artSet] || entry["0"];
  }

  // CSS for one atlas at a given size. Without a size, the atlas's own, as useAtlasSize does.
  function atlasCss(name, w, h2) {
    const art = artOf(name);
    if (!art) return "";
    const W = w === undefined ? art.w : w;
    const H = h2 === undefined ? art.h : h2;
    const sx = W / art.pw;
    const sy = H / art.ph;
    return `width:${W}px;height:${H}px;background-image:url(art/sheet-${art.f}.png);background-size:${art.sw * sx}px ${art.sh * sy}px;background-position:${-art.x * sx}px ${-art.y * sy}px;`;
  }

  function tex(name, cls, extra, w, h2) {
    return h("div", { class: "tex " + (cls || ""), style: atlasCss(name, w, h2) + (extra || "") });
  }

  // Map button: Blizzard_POIButton. 20 by 20, its art 32 by 32, centred.
  function poiButton(q, opts) {
    const selected = Game.superTracked === q.id;
    const complete = q.complete && q.completionShown;
    const legendary = q.classification === "legendary";
    const normal = legendary ? "ui-questpoilegendary-questnumber"
      : selected ? "ui-questpoi-questnumber-supertracked" : "ui-questpoi-questnumber";
    const display = complete
      ? (legendary ? "ui-questpoilegendary-questbangturnin" : "ui-questicon-turnin-normal")
      : (selected ? "quest-in-progress-icon-brown" : "quest-in-progress-icon-yellow");
    return h("div", { class: "poi", "data-action": "poi", "data-quest": q.id, "data-key": "poi", style: opts && opts.style },
      selected ? tex("ui-questpoi-outerglow", "poi-glow") : null,
      tex(normal, "poi-normal"),
      tex(display, "poi-display"),
      tex("ui-questpoi-innerglow", "poi-hover"));
  }

  // Quest item button: QuestObjectiveItemButtonTemplate.
  function itemButton(q, opts) {
    const it = q.item;
    const onCooldown = it.cdEnds > Date.now();
    const pct = onCooldown ? (it.cdEnds - Date.now()) / (it.cdTotal * 1000) : 0;
    const rangeClass = it.rangeState === 0 ? "range-out" : it.rangeState === 1 ? "range-in" : "";
    return h("div", { class: "item-btn", "data-action": "item", "data-quest": q.id, "data-tip": "item", "data-key": (opts && opts.key) || "item", style: opts && opts.style },
      it.glow ? h("div", { "data-key": "glow" + it.glow, class: "tex item-glow", style: atlasCss("ui-questtrackerbutton-questitem-frame-glow") }) : null,
      h("div", { class: "item-icon" + (onCooldown ? " cd" : ""), style: `background-image:url(art/${it.icon}.png)` }),
      onCooldown ? h("div", { class: "item-cd", "data-key": "cd" + it.cdEnds, "data-static": "", style: `--cd-dur:${(it.cdEnds - Date.now()) / 1000}s;--cd-from:${pct}` }) : null,
      tex("ui-questtrackerbutton-questitem-frame", "item-frame", "", 42, 42),
      it.charges ? h("div", { class: "item-count" }, it.charges) : null,
      rangeClass ? h("div", { class: "item-range " + rangeClass }, "●") : null,
      h("div", { class: "item-hl" }));
  }

  function findGroupButton(q) {
    return h("div", { class: "eye-btn", "data-action": "eye", "data-quest": q.id, "data-tip": "eye", "data-key": "eye" },
      tex("socialqueuing-icon-eye", "eye-icon", "", 13, 13));
  }

  // One objective line: ObjectiveTrackerAnimLineTemplate.
  function line(l) {
    const s = l.state;
    const showCheck = s === "completing" || s === "completed" || s === "fading";
    const cls = ["ot-line", "c-" + l.style, s ? "l-" + s : ""].join(" ");
    return h("div", { class: cls, "data-key": l.key },
      showCheck ? tex("ui-questtracker-tracker-check", "ot-check", "", 16, 16) : null,
      showCheck ? tex("ui-questtracker-tracker-check-glow", "ot-check-glow", "", 16, 16) : null,
      h("div", { class: "ot-dash" + (l.dash ? "" : " off") }, "- "),
      h("div", { class: "ot-text" }, l.text),
      (s === "completing" || s === "adding") ? tex("ui-questtracker-objfx-barglow", "ot-glow", "", 180, 22) : null);
  }

  // AutoScalingFontStringMixin: a one-line header shrinks to fit, down to minLineHeight 12.
  function fitHeader(el, maxWidth) {
    if (!el) return;
    el.style.maxWidth = maxWidth + "px";
    el.style.fontSize = "";
    const text = window.Bench.settings.textSize;
    let size = (el.closest(".prop") ? text : Math.max(12, text)) + 2;
    while (size > 12 && el.scrollWidth > el.clientWidth) {
      size -= 0.5;
      el.style.fontSize = size + "px";
    }
  }

  // The tag text comes from QuestUtilsOverrides on Camelot: [level+] Title (Tag).
  function titleText(q) {
    const tag = q.tag ? ` (${q.tag})` : "";
    return `[${q.level}${q.elite ? "+" : ""}] ${q.title}${tag}`;
  }

  // Other addons on Ikar's client. Spoken has no voice lines for quests new to Forever, the ones Forever Quest Tint marks.
  const hasSpoken = (q) => Bench.settings.spoken && !q.forever;

  // As Spoken_Quests/Compatibility.lua builds it: 14 by 14, the quest log's box on black at 60%.
  function spokenButton(q, right) {
    return h("div", {
      class: "edge spoken-btn" + (Game.speaking === q.id ? " playing" : ""),
      "data-action": "spoken", "data-quest": q.id, "data-key": "edge-spoken", style: `top:0;right:${right}px`,
    }, tex("questlog-icon-ticksquare", "spoken-box", "", 14, 14), h("div", { class: "spoken-glyph" }));
  }

  // Forever Quest Tint's default marker: its icon, 8 high, after the title.
  function tintMark(q) {
    return Bench.settings.foreverTint && q.forever ? h("span", { class: "fqt-mark", "data-key": "fqt" }) : null;
  }

  // Popup: AutoQuestPopUpBlockTemplate, with the parts from AutoQuest-Parts.
  function popup(p) {
    const q = Game.quests.get(p.questID);
    if (!q) return null;
    const complete = p.type === "COMPLETE";
    return h("div", { class: "aq" + (complete ? " complete" : " offer"), "data-action": "popup", "data-quest": q.id, "data-key": "popup" + q.id },
      h("div", { class: "aq-contents" },
        h("div", { class: "aq-bg" }),
        h("div", { class: "aq-border" }),
        h("div", { class: "aq-iconbg" }),
        h("div", { class: complete ? "aq-question" : "aq-exclaim" }),
        tex("autoquest-badgeborder", "aq-badge"),
        h("div", { class: "aq-top" }, complete ? "Cliquer pour terminer la quête" : "Quête découverte !"),
        h("div", { class: "aq-name" + (q.title.length > 26 ? " long" : "") }, q.title),
        !complete ? h("div", { class: "aq-bottom" }, "Cliquer pour consulter la quête") : null,
        complete ? h("div", { class: "aq-flash" }) : null,
        h("div", { class: "aq-shine" })));
  }

  function timeLeft(t) {
    const left = Math.max(0, Math.ceil((t.ends - Date.now()) / 1000));
    return `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
  }

  // QuestTimerFrame: 158 wide, 43 plus 16 per timer.
  function timerPanel() {
    if (!Game.timers.length) return null;
    return h("div", { class: "qt", "data-key": "timer", style: `height:${43 + 16 * Game.timers.length}px` },
      h("div", { class: "qt-head" }, "Temps"),
      Game.timers.map((t) => h("div", { class: "qt-row", "data-key": "t" + t.questID }, timeLeft(t))));
  }

  // Tooltip, menu and error text live in the stage's overlay.
  function overlayOf(el) {
    return el.closest(".stage").querySelector(".overlay");
  }

  function scaleOf(el) {
    return parseFloat(getComputedStyle(el.closest(".stage-inner")).zoom) || 1;
  }

  function placeInOverlay(el, overlay, x, y) {
    el.style.left = x + "px";
    el.style.top = y + "px";
    overlay.append(el);
    const z = scaleOf(overlay);
    const box = overlay.getBoundingClientRect();
    const r = el.getBoundingClientRect();
    if (r.right > box.right) el.style.left = Math.max(0, x - (r.right - box.right) / z) + "px";
    if (r.bottom > box.bottom) el.style.top = Math.max(0, y - (r.bottom - box.bottom) / z) + "px";
  }

  function hideTooltip(from) {
    (from ? [overlayOf(from)] : document.querySelectorAll(".overlay")).forEach((o) => {
      o.querySelectorAll(".gt").forEach((t) => t.remove());
    });
  }

  // lines: [{ text, color, wrap }]. side: "left" puts it to the left of the anchor, as Blizzard's party tooltip does.
  function showTooltip(anchor, lines, side) {
    const overlay = overlayOf(anchor);
    hideTooltip(anchor);
    const tip = h("div", { class: "gt" }, lines.map((l) => h("div", { class: "gt-line " + (l.color || "") }, l.text)));
    const a = anchor.getBoundingClientRect();
    const o = overlay.getBoundingClientRect();
    const z = scaleOf(anchor);
    tip.style.visibility = "hidden";
    placeInOverlay(tip, overlay, 0, 0);
    const w = tip.getBoundingClientRect().width;
    const x = side === "left" ? (a.left - o.left - w) / z : (a.right - o.left) / z;
    placeInOverlay(tip, overlay, Math.max(0, x), (a.top - o.top) / z);
    tip.style.visibility = "";
  }

  function closeMenus() {
    document.querySelectorAll(".menu").forEach((m) => m.remove());
  }

  // items: { title } | { text, onClick, disabled, checked, sub: items } | { divider }
  function openMenu(anchorEl, clientX, clientY, items, parentMenu) {
    if (!parentMenu) closeMenus();
    const overlay = overlayOf(anchorEl);
    const o = overlay.getBoundingClientRect();
    const z = scaleOf(anchorEl);
    const menu = h("div", { class: "menu" });
    for (const it of items) {
      if (it.title) { menu.append(h("div", { class: "menu-title" }, it.title)); continue; }
      if (it.divider) { menu.append(h("div", { class: "menu-div" })); continue; }
      const row = h("div", { class: "menu-item" + (it.disabled ? " disabled" : "") + (it.sub ? " has-sub" : "") + (it.checkbox ? " check" : "") },
        it.checkbox ? h("span", { class: "menu-box" + (it.checked ? " on" : "") }) : null,
        h("span", { class: "menu-text" }, it.text),
        it.count !== undefined ? h("span", { class: "menu-count" }, `(${it.count})`) : null,
        it.sub ? h("span", { class: "menu-arrow" }, "▸") : null);
      if (it.sub) {
        row.addEventListener("mouseenter", () => {
          menu.querySelectorAll(":scope ~ .menu").forEach((m) => m.remove());
          const r = row.getBoundingClientRect();
          openMenu(anchorEl, r.right - 2, r.top - 4, it.sub, menu);
        });
      } else {
        row.addEventListener("mouseenter", () => menu.querySelectorAll(":scope ~ .menu").forEach((m) => m.remove()));
        if (!it.disabled) {
          row.addEventListener("click", () => {
            if (!it.keepOpen) closeMenus();
            it.onClick && it.onClick();
          });
        }
      }
      menu.append(row);
    }
    placeInOverlay(menu, overlay, (clientX - o.left) / z, (clientY - o.top) / z);
    return menu;
  }

  document.addEventListener("mousedown", (e) => {
    if (!e.target.closest(".menu")) closeMenus();
  }, true);
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeMenus(); });

  // UIErrorsFrame: red text, top centre, fades.
  function error(fromEl, text) {
    const overlay = overlayOf(fromEl);
    overlay.querySelectorAll(".uierror").forEach((e) => e.remove());
    const el = h("div", { class: "uierror" }, text);
    overlay.append(el);
    setTimeout(() => el.remove(), 2600);
    Game.log("error", text);
  }

  // A plain stand-in for the quest details the game would open.
  function questPanel(fromEl, q, onClose) {
    const overlay = overlayOf(fromEl);
    overlay.querySelectorAll(".qpanel").forEach((e) => e.remove());
    const el = h("div", { class: "qpanel" },
      h("div", { class: "qpanel-close", "data-close": "1" }, "×"),
      h("div", { class: "qpanel-note" }, "Stand-in for QuestMapFrame_OpenToQuestDetails"),
      h("div", { class: "qpanel-title" }, q.title),
      h("div", { class: "qpanel-head" }, "Description"),
      h("div", null, q.description || ""),
      h("div", { class: "qpanel-head" }, "Objectifs"),
      q.objectives.map((o) => h("div", null, "- " + window.FakeLog.objectiveText(o))));
    el.addEventListener("click", (e) => {
      if (!e.target.dataset.close) return;
      el.remove();
      if (onClose) onClose();
    });
    overlay.append(el);
    Game.log("call", `QuestMapFrame_OpenToQuestDetails(${q.id})`);
  }

  function itemTooltip(el, q) {
    const it = q.item;
    showTooltip(el, [
      { text: it.name, color: "white" },
      { text: "Objet de quête", color: "white" },
      { text: `Utiliser : ${q.title}`, color: "green" },
    ]);
  }

  function partyTooltip(el, q) {
    const lines = [{ text: "Membre du groupe à proximité sur cette quête :", color: "gold" }];
    for (let i = 0; i < q.party; i++) {
      lines.push({ text: `Compagnon ${i + 1}`, color: "white" });
      q.objectives.forEach((o) => lines.push({ text: "- " + window.FakeLog.objectiveText(o), color: "grey" }));
    }
    if (!q.party) return false;
    showTooltip(el, lines, "left");
    return true;
  }

  return Object.assign(state, {
    h, morph, atlasCss, tex, poiButton, itemButton, findGroupButton, line, titleText, hasSpoken, spokenButton, tintMark, fitHeader, popup, timerPanel,
    showTooltip, hideTooltip, openMenu, closeMenus, error, questPanel, itemTooltip, partyTooltip, scaleOf,
  });
})();
