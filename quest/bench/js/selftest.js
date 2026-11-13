// Behaviour checks for the bench, run by opening index.html#selftest. It clicks through the real page and reports
// in the page title and in #selftest-out. It checks the simulation against the plan, not the game itself.
(async function () {
  const results = [];
  const errors = [];
  window.addEventListener("error", (e) => errors.push(e.message));
  // A headless browser may never run a fade, so opacities are read at their end value.
  document.head.append(UI.h("style", null, "*, *::before { transition: none !important; }"));

  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const check = (name, ok, info) => results.push({ name, ok: !!ok, info });
  const B = "#blizz-root";
  const P = "#prop-root";
  const all = (sel) => [...document.querySelectorAll(sel)];
  const one = (sel) => document.querySelector(sel);
  const rows = () => all(`${P} .pt-row`);
  const rowIDs = () => rows().map((r) => Number(r.dataset.quest));
  const PT = ProposalTracker;

  function fresh(preset) {
    Game.reset();
    PT.preset(preset);
    UI.closeMenus();
    document.querySelectorAll(".uierror, .qpanel").forEach((e) => e.remove());
  }

  function click(el, opts) {
    if (!el) return check(`Click target missing, after: ${results.length ? results[results.length - 1].name : "start"}`, false);
    el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, ...opts }));
  }
  const bar = (cat) => one(`${P} .pt-bar[data-cat="${cat}"]`);
  const group = (key) => one(`${P} [data-groupkey="${key}"]`);
  const secureBtn = (id) => one(`.secure-layer [data-quest="${id}"]`);
  const slot = (id) => one(`${P} [data-slot="${id}"]`);

  Bench.settings.height = 1000;
  Bench.settings.view = "both";
  Bench.renderAll();

  // Blizzard
  fresh("closed");
  check("Blizzard draws one block per tracked quest", all(`${B} .ot-block`).length === Game.watch.length, all(`${B} .ot-block`).length);
  click(one(`${B} [data-action="collapse-module"]`));
  check("Blizzard: collapsing the section hides its blocks", all(`${B} .ot-block`).length === 0);
  click(one(`${B} [data-action="collapse-module"]`));
  check("Blizzard: expanding brings them back", all(`${B} .ot-block`).length === Game.watch.length);
  const firstTracked = Game.watch[0];
  click(one(`${B} [data-action="title"][data-quest="${firstTracked}"]`), { shiftKey: true });
  check("Blizzard: Shift-click untracks", !Game.watch.includes(firstTracked));
  click(one(`${B} [data-action="title"][data-quest="${Game.watch[0]}"]`));
  check("Blizzard: a plain click opens the quest's details", one("#stage-blizz .qpanel"));
  Game.setCombat(true);
  const before = all(`${B} .ot-block`).length;
  click(one(`${B} [data-action="collapse-module"]`));
  check("Blizzard: no lock in combat", all(`${B} .ot-block`).length === 0 && before > 0);
  click(one(`${B} [data-action="collapse-module"]`));
  Game.setCombat(false);
  Game.order.slice(0, 22).forEach((id) => Game.toggleWatch(id, true));
  Bench.settings.height = 400;
  BlizzardTracker.render();
  const cut = all(`${B} .ot-block`).filter((b) => b.style.display === "none").length;
  check("Blizzard: a block that doesn't fit is cut", cut > 0, cut);
  Bench.settings.height = 1000;
  Bench.renderAll();

  // Tree
  fresh("closed");
  check("Everything starts collapsed: no quest rows", rows().length === 0);
  const bars = all(`${P} .pt-bar`).map((b) => b.dataset.cat);
  check("Bars show in the plan's order, Suivi first, then Journal", bars.join() === "mine,journal,world,classprof,instances,events,pvp,misc", bars.join());
  click(bar("world"));
  check("Opening a bar shows its groups, not its quests", all(`${P} .pt-group`).length > 0 && rows().length === 0);
  click(group("hMarche de l'Ouest"));
  check("Opening a group shows its quests", rows().length > 0, rows().length);
  check("Quests show objectives with no further click", one(`${P} .pt-row .ot-line`));
  click(one(`${P} .pt-row[data-action="title"]`));
  check("A plain click opens the quest's details", one("#stage-prop .qpanel"));
  click(group("hMarche de l'Ouest"));
  click(group("hMarche de l'Ouest"));
  check("Reopening keeps working", rows().length > 0);

  fresh("open");
  const ids = rowIDs();
  check("Every quest in the log appears", ids.length === Game.order.length, `${ids.length} of ${Game.order.length}`);
  check("No quest appears twice", new Set(ids).size === ids.length);
  check("The current zone is listed first in Monde", one(`${P} [data-key="cat-world"] .pt-group`).textContent.includes(Game.zone));
  Game.setZone("Les Carmines");
  check("A zone change reorders Monde's groups", one(`${P} [data-key="cat-world"] .pt-group`).textContent.includes("Les Carmines"));
  check("A zone change leaves the player's groups alone", one(`${P} [data-key="cat-mine"] .pt-group`).textContent.includes("À faire maintenant"));

  // Markers
  fresh("open");
  const rowOf = (id) => one(`${P} .pt-row[data-quest="${id}"]`);
  const dungeonRow = rowOf(214);
  check("No dungeon icon on a row inside Donjons et raids", dungeonRow.querySelectorAll(".mk").length === 0);
  PT.state.groups[0].quests.push(214);
  Game.toggleWatch(214, true);
  PT.render();
  check("The dungeon icon appears once the quest is in Suivi", rowOf(214).querySelectorAll(".mk").length === 1);
  check("Repeatable shows an icon", rowOf(7881).querySelectorAll(".mk").length === 1);
  check("Title text drops (Donjon) by default", !rowOf(214).textContent.includes("(Donjon)"));
  check("Blizzard's title keeps (Donjon)", one(`${B} .ot-block[data-quest="214"]`).textContent.includes("(Donjon)"));

  // Share button
  fresh("open");
  check("Solo: no share button", all(`${P} .share-btn`).length === 0);
  Game.setParty(2);
  const share = one(`${P} .share-btn[data-quest="12"]`);
  check("In a group: a share button on a shareable quest", share);
  check("Not on a quest that can't be shared", !one(`${P} .share-btn[data-quest="9"]`));
  click(share);
  check("It leaves once the party member has the quest", !one(`${P} .share-btn[data-quest="12"]`));
  check("The quest then shows [2]", rowOf(12).textContent.includes("[2]"));
  Game.setParty(1);

  // Combat lock
  fresh("closed");
  check("The padlock is there out of combat, open", one(`${P} .pt-lock.open`));
  Game.setCombat(true);
  check("Combat shuts it", one(`${P} .pt-lock.shut`));
  click(bar("world"));
  check("Locked: a bar doesn't open", !PT.state.open.categories.world);
  check("Locked: no red error text for that", !one("#stage-prop .uierror"));
  click(one(`${P} .pt-lock`));
  check("The padlock unlocks", PT.state.unlocked);
  click(bar("world"));
  check("Unlocked: a bar opens in combat", PT.state.open.categories.world);
  click(group("hMarche de l'Ouest"));
  check("Unlocked: a group opens in combat", rows().length > 0);
  Game.setCombat(false);
  check("After combat it's open again", one(`${P} .pt-lock.open`));
  Game.setCombat(true);
  check("The next fight locks again", !PT.state.unlocked);
  click(one(`${P} [data-action="filter"]`));
  check("Filter is refused in combat", one("#stage-prop .uierror"));
  document.querySelectorAll(".uierror").forEach((e) => e.remove());
  click(one(`${P} [data-action="search"]`));
  check("Search is refused in combat", one("#stage-prop .uierror") && !PT.state.searchOpen);
  click(one(`${P} .pt-row[data-action="title"]`));
  check("Details are refused in combat", !one("#stage-prop .qpanel"));
  Game.setCombat(false);

  // Item buttons over rows
  fresh("closed");
  PT.state.open.categories.mine = true;
  PT.state.open.groups[1] = true;
  PT.state.open.categories.world = true;
  PT.state.open.headers["Marche de l'Ouest"] = true;
  PT.render();
  const btn = secureBtn(60);
  check("An item button exists for a visible quest", btn);
  check("It isn't inside the rows or the scroll frame", btn && !btn.closest(".pt-row") && !btn.closest(".pt-scroll") && !btn.closest(P));
  const posOut = btn.style.top;
  check("Out of combat it lines up with its row", slot(60).classList.contains("covered"));
  check("A closed group has no item button", !secureBtn(1579));
  Game.setCombat(true);
  check("In combat the button stays in place", secureBtn(60).style.top === posOut);
  check("And stays lined up while nothing moved", slot(60).classList.contains("covered"));
  click(one(`${P} .pt-lock`));
  // A new group above it moves the row.
  const spacer = { id: 98, name: "Au-dessus", quests: [] };
  PT.state.groups.unshift(spacer);
  PT.render();
  check("When its row moves, the button doesn't follow", secureBtn(60).style.top === posOut);
  check("It dims instead", secureBtn(60).style.opacity === "0.45");
  check("The row shows a grey icon that does nothing", !slot(60).classList.contains("covered"));
  PT.state.groups = PT.state.groups.filter((g) => g !== spacer);
  PT.render();
  click(group("g1"));
  check("Closing its group in an unlocked fight leaves the button there", secureBtn(60) && secureBtn(60).style.top === posOut);
  check("Dimmed, because it can't be hidden", secureBtn(60) && secureBtn(60).style.opacity === "0.45");
  click(secureBtn(60));
  check("And it still works", Game.quests.get(60).item.cdEnds > Date.now());
  click(group("g1"));
  click(bar("classprof"));
  click(group("hPêche"));
  check("An item opened in combat has no real button", !secureBtn(1579) && slot(1579));
  Game.setCombat(false);
  check("After combat, it gets a real one", secureBtn(1579));
  check("And everything lines up again", slot(60).classList.contains("covered") && secureBtn(60).style.opacity === "");

  // Item triggers
  fresh("closed");
  PT.state.open.categories.mine = true;
  PT.state.open.groups[1] = true;
  PT.render();
  Game.enterArea(60, true);
  check("Entering the area glows on Blizzard's button", one(`${B} .ot-block[data-quest="60"] .item-glow`));
  check("And on the proposal's", one('.secure-layer [data-quest="60"] .item-glow'));
  Game.setRange(60, 0);
  check("Out of range: red dot", one('.secure-layer [data-quest="60"] .range-out'));
  Game.setRange(60, 1);
  check("In range: grey dot", one('.secure-layer [data-quest="60"] .range-in'));
  Game.setRange(60, null);
  check("No range: no dot", !one('.secure-layer [data-quest="60"] .item-range'));
  click(secureBtn(60));
  check("Clicking uses it and starts the cooldown", one('.secure-layer [data-quest="60"] .item-cd'));
  await wait(50);
  const cdEl = one('.secure-layer [data-quest="60"] .item-cd');
  Game.changed("QUEST_LOG_UPDATE");
  check("A redraw doesn't restart the cooldown", one('.secure-layer [data-quest="60"] .item-cd') === cdEl);

  // Scrolling
  fresh("open");
  Bench.settings.height = 400;
  Bench.renderAll();
  const scroll = one(`${P} .pt-scroll`);
  check("The list overflows at this height", scroll.scrollHeight > scroll.clientHeight, `${scroll.scrollHeight} > ${scroll.clientHeight}`);
  check("The scrollbar shows", one(`${P} .pt-sb`).style.display !== "none");
  const wheel = () => scroll.dispatchEvent(new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 100 }));
  wheel();
  check("The wheel scrolls", scroll.scrollTop > 0);
  Game.setCombat(true);
  const top = scroll.scrollTop;
  wheel();
  check("Locked: the wheel does nothing", scroll.scrollTop === top);
  click(one(`${P} .pt-lock`));
  wheel();
  check("Unlocked: the wheel scrolls", scroll.scrollTop > top);
  Game.setCombat(false);
  Bench.settings.height = 1000;
  fresh("closed");
  Bench.renderAll();
  check("No scrollbar when everything fits", one(`${P} .pt-sb`).style.display === "none");

  // Search and filter
  fresh("closed");
  click(one(`${P} [data-action="search"]`));
  const input = one(`${P} .pt-search-input`);
  check("The search box opens", input);
  const type = (text) => {
    input.value = text;
    input.dispatchEvent(new Event("input", { bubbles: true }));
  };
  type("elite");
  check("Search ignores accents and opens what it finds", rowIDs().includes(176) && rowIDs().includes(19), rowIDs().join());
  check("And hides the rest", !rowIDs().includes(9));
  check("The count shows", one(`${P} .pt-status`).textContent.includes("sur"));
  type("pierre bois");
  check("Words match in any order, in objectives", rowIDs().includes(1654), rowIDs().join());
  type("zzzz");
  check("No match says so", one(`${P} .pt-status`).textContent.includes("Aucun résultat"));
  type("");
  check("Clearing restores the closed state", rows().length === 0);
  check("Search doesn't change saved open state", !PT.state.open.categories.world);

  fresh("open");
  PT.state.filters = { type: { Donjon: true } };
  PT.render();
  check("A filter hides other quests", rowIDs().every((id) => Game.quests.get(id).tagID === 81), rowIDs().join());
  PT.state.filters = { type: { Donjon: true }, state: { "À rendre": true } };
  PT.render();
  check("Across categories, a quest needs both", rows().length === 0);
  PT.state.filters = { type: { Donjon: true, "Élite": true } };
  PT.render();
  check("Within a category, either will do", rowIDs().includes(176) && rowIDs().includes(214));
  check("Filters don't move anything", PT.state.groups[0].quests.includes(60));
  click(one(`${P} .pt-status .pt-link`));
  check("Tout effacer clears them", !Object.keys(PT.state.filters).length && rows().length === Game.order.length);

  // Dragging
  fresh("open");
  async function drag(from, to, side) {
    if (!from || !to) return check(`Drag target missing, after: ${results[results.length - 1].name}`, false);
    const a = from.getBoundingClientRect();
    const b = to.getBoundingClientRect();
    const down = { bubbles: true, cancelable: true, button: 0, clientX: a.left + 30, clientY: a.top + 5 };
    from.dispatchEvent(new MouseEvent("mousedown", down));
    const toY = side === "top" ? b.top + 2 : side === "bottom" ? b.bottom - 2 : b.top + b.height / 2;
    window.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: a.left + 40, clientY: a.top + 20 }));
    window.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: b.left + 40, clientY: toY }));
    window.dispatchEvent(new MouseEvent("mouseup", { bubbles: true, clientX: b.left + 40, clientY: toY }));
    await wait(5);
  }
  await drag(one(`${P} .pt-row[data-quest="12"] .ot-head`), group("g2"));
  check("Dropping a quest on a group adds it there", PT.state.groups[1].quests.includes(12), PT.state.groups[1].quests.join());
  await drag(one(`${P} .pt-row[data-quest="22"] .ot-head`), one(`${P} .pt-row[data-quest="60"]`), "top");
  check("Dropping on a row reorders", PT.state.groups[0].quests[0] === 22, PT.state.groups[0].quests.join());
  const beforeGroups = PT.state.groups.map((g) => g.id).join();
  await drag(group("g2"), group("g1"), "top");
  check("Groups can be reordered", PT.state.groups[0].id === 2, `${beforeGroups} -> ${PT.state.groups.map((g) => g.id).join()}`);
  await drag(bar("misc"), bar("world"), "top");
  check("Bars can be reordered", PT.state.categoryOrder && PT.state.categoryOrder.indexOf("misc") < PT.state.categoryOrder.indexOf("world"), (PT.state.categoryOrder || []).join());
  await drag(one(`${P} .pt-row[data-quest="9"] .ot-head`), one(`${P} .pt-bar[data-cat="events"]`));
  check("Dropping outside the player's groups cancels", !!PT.state.groups.find((g) => g.quests.includes(9)));
  Game.setCombat(true);
  const groupsNow = JSON.stringify(PT.state.groups);
  await drag(one(`${P} .pt-row[data-quest="91"] .ot-head`), group("g1"));
  check("Dragging is refused in combat", JSON.stringify(PT.state.groups) === groupsNow);
  Game.setCombat(false);

  // Picking several quests with Ctrl+click
  fresh("open");
  const inGroup = (id) => PT.state.groups.some((g) => g.quests.includes(id));
  const [p1, p2, p3] = rowIDs().filter((id) => !inGroup(id));
  const head = (id) => rowOf(id).querySelector(".ot-head");
  const picked = (id) => rowOf(id) && rowOf(id).classList.contains("picked");
  const rightClick = (el) => el.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  const menuItem = (text) => all(".menu .menu-item").find((i) => i.querySelector(".menu-text").textContent === text);
  click(head(p1), { ctrlKey: true });
  check("Ctrl+click picks a quest, without opening it", picked(p1) && !one("#stage-prop .qpanel"));
  click(head(p2), { ctrlKey: true });
  click(head(p3), { ctrlKey: true });
  click(head(p3), { ctrlKey: true });
  check("Again unpicks it", picked(p1) && picked(p2) && !picked(p3));
  rightClick(rowOf(p2));
  check("A picked row's menu speaks for all of them", all(".menu .menu-title").some((t) => t.textContent === "2 quêtes sélectionnées") && menuItem("Suivre ces quêtes") && !menuItem("Arrêter le suivi"));
  menuItem("Déplacer vers").dispatchEvent(new MouseEvent("mouseenter"));
  menuItem(PT.state.groups[1].name).click();
  await wait(5);
  check("Déplacer vers moves them all, in order, tracked", PT.state.groups[1].quests.slice(-2).join() === `${p1},${p2}` && Game.watch.includes(p1) && Game.watch.includes(p2), PT.state.groups[1].quests.join());
  check("They stay picked", picked(p1) && picked(p2));
  rightClick(rowOf(p1));
  menuItem("Arrêter le suivi").click();
  await wait(5);
  check("Arrêter le suivi takes them all out", !inGroup(p1) && !inGroup(p2) && !Game.watch.includes(p1) && !Game.watch.includes(p2));
  await drag(head(p1), group("g1"));
  check("Dragging a picked row carries every picked quest", PT.state.groups[0].quests.slice(-2).join() === `${p1},${p2}`, PT.state.groups[0].quests.join());
  const firstOfG1 = PT.state.groups[0].quests[0];
  await drag(head(p2), rowOf(firstOfG1), "top");
  check("Dropped on a row, they go before it, still in order", PT.state.groups[0].quests.slice(0, 3).join() === `${p1},${p2},${firstOfG1}`, PT.state.groups[0].quests.join());
  const groupsBefore = PT.state.groups.length;
  await drag(head(p1), bar("mine"));
  const newest = PT.state.groups[PT.state.groups.length - 1];
  check("On Suivi's bar, they start a group together", PT.state.groups.length === groupsBefore + 1 && newest.quests.join() === `${p1},${p2}`);
  PT.state.renaming = null;
  PT.render();
  await drag(head(p3), group("g2"));
  check("A row that isn't picked drags alone", PT.state.groups[1].quests.includes(p3) && newest.quests.join() === `${p1},${p2}`);
  Game.setCombat(true);
  rightClick(rowOf(p1));
  menuItem("Déplacer vers").dispatchEvent(new MouseEvent("mouseenter"));
  menuItem(PT.state.groups[0].name).click();
  check("Moving them is refused in combat", newest.quests.join() === `${p1},${p2}` && one("#stage-prop .uierror"));
  click(head(p1));
  check("Any click without Ctrl ends the picking", !one(`${P} .pt-row.picked`));
  click(head(p1), { ctrlKey: true });
  check("Picking works in combat, as it moves nothing", picked(p1));
  Game.setCombat(false);
  document.querySelectorAll(".uierror, .qpanel").forEach((e) => e.remove());
  click(group("g" + newest.id));
  click(group("g" + newest.id));
  check("A picked row that closes away is let go", !picked(p1));

  // Groups
  fresh("open");
  PT.state.groups.push({ id: 99, name: "Vide", quests: [] });
  PT.render();
  const del = PT.state.groups[0];
  const moved = del.quests.slice();
  PT.state.groups = PT.state.groups.filter((g) => g !== del);
  PT.render();
  check("A deleted group's quests return to their automatic place", moved.every((id) => rowIDs().includes(id)));

  // Lifecycle
  fresh("open");
  const milice = () => Game.quests.get(12);
  Game.toggleWatch(12, true);
  await wait(5);
  Game.progress(12, 7);
  check("Finishing an objective shows the check animation", one(`${P} .pt-row[data-quest="12"] .l-completing`));
  check("On Blizzard's too", one(`${B} .ot-block[data-quest="12"] .l-completing`));
  await wait(2200);
  check("A finished quest ends on À rendre", rowOf(12).textContent.includes("À rendre"), rowOf(12).textContent);
  check("Its count rises", milice().complete);
  Game.turnIn(12);
  check("Turn-in plays its animation", rowOf(12).classList.contains("a-turnin"));
  await wait(800);
  check("Then the row leaves", !rowOf(12));

  Bench.settings.autoQuestWatch = false;
  fresh("closed");
  const beforeCount = bar("world").querySelector(".pt-count").textContent;
  const accepted = Game.accept();
  check("A new quest opens nothing", rows().length === 0, accepted.title);
  check("Its closed header's count rises", bar("world").querySelector(".pt-count").textContent !== beforeCount);
  check("And glows once", bar("world").classList.contains("a-barflash"));

  fresh("closed");
  Game.setCombat(true);
  const heldCount = bar("world").querySelector(".pt-count").textContent;
  Game.accept();
  check("Accepted in combat: the row change waits", bar("world").querySelector(".pt-count").textContent === heldCount);
  Game.setCombat(false);
  check("It appears after combat", bar("world").querySelector(".pt-count").textContent !== heldCount);

  fresh("closed");
  Game.superTrack(60);
  check("Focusing opens the quest's group and category", rowIDs().includes(60));
  Game.superTrack(60);

  fresh("closed");
  Game.addPopup(22, "COMPLETE");
  check("A popup shows on Blizzard's tracker", one(`${B} .aq.complete`));
  check("And above the bars on the proposal", one(`${P} .pt-popups .aq.complete`));
  click(one(`${P} .pt-popups .aq`));
  check("Clicking removes it", !one(`${P} .aq`) && !one(`${B} .aq`));

  fresh("closed");
  const titleTop = one(`${P} .ot-title`).getBoundingClientRect().top;
  Game.startTimer(9, 60);
  check("A timer shows on both", one(`${P} .qt`) && one(`${B} .qt`));
  check("It pushes the title down", one(`${P} .ot-title`).getBoundingClientRect().top > titleTop);
  check("A timed quest gets the clock marker", (() => { PT.preset("open"); return rowOf(9).querySelectorAll(".mk").length === 1; })());
  Game.clearTimers();

  // Sequenced
  fresh("open");
  Game.setSequenced(92, false);
  Game.quests.get(89).objectives.forEach((o) => { o.done = false; if (o.have >= o.need) o.have = 0; });
  Game.setSequenced(89, true);
  const lineCount = () => rowOf(89).querySelectorAll(".ot-line").length;
  check("A sequenced quest shows one objective", lineCount() === 1, lineCount());
  Game.completeObjective(89);
  await wait(2600);
  check("The next objective appears after the first fades", rowOf(89).textContent.includes("Vis en fer") && !rowOf(89).textContent.includes("Clou en fer"), rowOf(89).textContent);

  // Largest text size, longest French strings
  fresh("open");
  PT.state.open.categories.pvp = true;
  Bench.settings.textSize = 20;
  Bench.renderAll();
  const twoLines = (root) => all(`${root} .ot-head-text`).every((t) => t.offsetHeight <= 22 * 2 * 1.08 + 3);
  check("Text 20: titles stop at two lines, on the proposal", twoLines(P));
  check("Text 20: titles stop at two lines, on Blizzard's", twoLines(B));
  const fits = (sel) => all(sel).every((t) => t.scrollWidth <= t.clientWidth);
  check("Text 20: bar labels fit, on the proposal", fits(`${P} .ot-bar-text`), all(`${P} .ot-bar-text`).map((t) => `${t.textContent} ${t.scrollWidth}/${t.clientWidth}`).join(", "));
  check("Text 20: bar labels fit, on Blizzard's", fits(`${B} .ot-bar-text`));
  check("Text 20: the title fits", fits(`${P} .ot-title-text`) && fits(`${B} .ot-title-text`));
  Bench.settings.textSize = 12;
  Bench.renderAll();

  // A dropped screenshot replaces the world
  const png = await (await fetch("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")).blob();
  const dt = new DataTransfer();
  dt.items.add(new File([png], "world.png", { type: "image/png" }));
  window.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: dt }));
  await wait(50);
  const scene = one("#stage-prop canvas.scene");
  check("Dropping a screenshot uses it as the world", scene.dataset.world === "dropped");
  click(one("#screenshot-clear"));
  await wait(50);
  check("It can be removed", scene.dataset.world === Bench.settings.background);

  // The world is a real screenshot at the game's true size, with the game's own tracker painted out
  check("Every world is an image at the game's height", Object.values(Worlds.LIST).every((w) => w.file.endsWith(".jpg")) && scene.style.height === "1200px");
  check("The tracker sits where it does in the screenshots", getComputedStyle(one("#prop-root")).top === "286px");

  // The scrollbar: right of the rows, on screen, and invisible unless scrolling
  fresh("open");
  Bench.settings.height = 400;
  Bench.renderAll();
  await wait(50);
  const sb = one(`${P} .pt-sb`);
  const sbBox = sb.getBoundingClientRect();
  const rootBox = one(P).getBoundingClientRect();
  const stageBox = one("#stage-prop .stage-inner").getBoundingClientRect();
  check("The scrollbar is right of the rows", sbBox.left >= rootBox.right);
  check("Its arrows are on screen", one(`${P} .pt-sb-up`).getBoundingClientRect().right <= stageBox.right, `${one(`${P} .pt-sb-up`).getBoundingClientRect().right} <= ${stageBox.right}`);
  const unitsFromEdge = (root, stage) => (one(stage).getBoundingClientRect().right - one(root).getBoundingClientRect().right) / UI.scaleOf(one(root));
  check("Blizzard's tracker keeps its real position", Math.abs(unitsFromEdge(B, "#stage-blizz .stage-inner") - 5) < 1, unitsFromEdge(B, "#stage-blizz .stage-inner"));
  check("The panel sits 12 further in", Math.abs(unitsFromEdge(P, "#stage-prop .stage-inner") - 17) < 1, unitsFromEdge(P, "#stage-prop .stage-inner"));
  check("It's invisible at rest", !sb.classList.contains("scrolling"));
  one(`${P} .pt-scroll`).dispatchEvent(new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 100 }));
  check("It shows while scrolling", one(`${P} .pt-sb`).classList.contains("scrolling"));
  Bench.renderAll();
  check("A redraw while scrolling keeps it", one(`${P} .pt-sb`).classList.contains("scrolling"));
  await wait(900);
  check("It goes away after scrolling", !one(`${P} .pt-sb`).classList.contains("scrolling"));
  Bench.settings.height = 700;
  Bench.renderAll();

  // The width option moves only the proposal, and its bars and rows follow
  fresh("open");
  const widthBefore = one(P).getBoundingClientRect().width;
  const blizzBefore = one(B).getBoundingClientRect().width;
  Bench.settings.width = 340;
  Bench.renderAll();
  await wait(50);
  const scale = UI.scaleOf(one(P));
  check("Width: the panel grows", Math.abs(one(P).getBoundingClientRect().width - 340 * scale) < 1 && one(P).getBoundingClientRect().width > widthBefore);
  check("Width: bars follow", Math.abs(one(`${P} .pt-bar`).getBoundingClientRect().width - 340 * scale) < 1);
  check("Width: the bar art stretches", Math.abs(one(`${P} .pt-bar .bar-bg`).getBoundingClientRect().width - 380 * scale) < 1);
  check("Width: rows follow", rows().every((r) => r.querySelector(".ot-head").getBoundingClientRect().width > 0) && Math.max(...rows().map((r) => r.querySelector(".ot-head").getBoundingClientRect().width)) > (260 - 30) * scale);
  check("Width: Blizzard's stays 260", Math.abs(one(B).getBoundingClientRect().width - blizzBefore) < 1);
  Bench.settings.width = 260;
  Bench.renderAll();

  // Other addons: Spoken's button on every voiced quest, Forever Quest Tint's marker on the others
  fresh("open");
  await wait(20);
  const voiced = rows().filter((r) => !Game.quests.get(Number(r.dataset.quest)).forever);
  const marked = rows().filter((r) => Game.quests.get(Number(r.dataset.quest)).forever);
  check("Spoken's button is on every voiced quest", voiced.length > 0 && voiced.every((r) => r.querySelector(".spoken-btn")));
  check("It isn't on a quest new to Forever", marked.length > 0 && marked.every((r) => !r.querySelector(".spoken-btn")));
  check("Forever Quest Tint marks those instead", marked.every((r) => r.querySelector(".fqt-mark")) && voiced.every((r) => !r.querySelector(".fqt-mark")));
  const playRow = voiced.find((r) => r.querySelector(".spoken-btn"));
  const playBox = playRow.querySelector(".spoken-btn").getBoundingClientRect();
  check("It sits at the row's far right", Math.abs(playBox.right - playRow.getBoundingClientRect().right) < 1);
  const withItem = rows().find((r) => r.querySelector(".item-slot") && r.querySelector(".spoken-btn"));
  check("An item button doesn't sit under it", withItem && withItem.querySelector(".item-slot").getBoundingClientRect().right <= withItem.querySelector(".spoken-btn").getBoundingClientRect().left);
  const titleBefore = one(".qpanel");
  click(playRow.querySelector(".spoken-btn"));
  await wait(20);
  check("Clicking it plays, not the quest's details", Game.speaking === Number(playRow.dataset.quest) && one(".qpanel") === titleBefore);
  check("It shows it's playing", one(`${P} .pt-row[data-quest="${Game.speaking}"] .spoken-btn`).classList.contains("playing"));
  click(one(`${P} .pt-row[data-quest="${Game.speaking}"] .spoken-btn`));
  Bench.settings.spoken = false;
  Bench.settings.foreverTint = false;
  Bench.renderAll();
  check("Both can be turned off", !one(`${P} .spoken-btn`) && !one(`${B} .spoken-btn`) && !one(`${P} .fqt-mark`) && !one(`${B} .fqt-mark`));
  Bench.settings.spoken = true;
  Bench.settings.foreverTint = true;
  Bench.renderAll();

  // Text size is Edit Mode's alone since 2026-11-10, 12 to 20 on both trackers; the addon's zoom isn't drawn here
  fresh("open");
  const textOf = (root) => parseFloat(getComputedStyle(one(root)).fontSize);
  const at12 = [textOf(P), textOf(B)];
  Bench.settings.textSize = 16;
  Bench.renderAll();
  await wait(20);
  check("Text 16: both trackers draw it", Math.abs(textOf(P) / at12[0] - 16 / 12) < 0.02 && Math.abs(textOf(B) / at12[1] - 16 / 12) < 0.02, `${textOf(P)} and ${textOf(B)} against ${at12}`);
  const sizeInput = one("#controls [data-setting='textSize']");
  check("The text size slider is Edit Mode's, 12 to 20", !!sizeInput && sizeInput.min === "12" && sizeInput.max === "20", sizeInput && `${sizeInput.min} to ${sizeInput.max}`);
  Bench.settings.textSize = 12;
  Bench.renderAll();

  // The sober style: one title colour, with the level as a coloured number on a plain rectangle
  const titleColours = () => new Set(rows().map((r) => getComputedStyle(r.querySelector(".ot-head")).color)).size;
  const difficulties = new Set(rows().map((r) => Game.difficulty(Game.quests.get(Number(r.dataset.quest))))).size;
  check("Test rows have several difficulties", difficulties > 1, difficulties);
  check("Every title has one colour", titleColours() === 1, titleColours());
  const row60 = () => rowOf(60);
  check("The level is a badge, out of the title", row60().querySelector(".pt-level").textContent === String(Game.quests.get(60).level) && !row60().querySelector(".ot-head-text").textContent.includes("["));
  check("An elite quest's badge has a +", rowOf(176).querySelector(".pt-level").textContent.endsWith("+"));
  const lefts = rows().map((r) => r.querySelector(".pt-level").getBoundingClientRect().right);
  check("The badges line up", Math.max(...lefts) - Math.min(...lefts) < 1);
  const longTitle = rowOf(239).querySelector(".ot-head");
  check("The badge doesn't sit over the title", rowOf(239).querySelector(".pt-gutter").getBoundingClientRect().right <= longTitle.getBoundingClientRect().left);
  check("Badges and blocks have square corners", getComputedStyle(row60().querySelector(".pt-level")).borderRadius === "0px" && getComputedStyle(row60(), "::before").borderRadius === "0px");

  const badgeStyles = () => rows().map((r) => getComputedStyle(r.querySelector(".pt-level")));
  const distinct = (values) => new Set(values).size;
  check("The number's colour shows the difficulty", distinct(badgeStyles().map((b) => b.color)) === difficulties);
  check("Every number is on the same background", distinct(badgeStyles().map((b) => b.backgroundColor)) === 1);
  const plateSheet = window.ATLAS_DATA["ui-hud-nameplates-levelindicator"][UI.artSet || "1"].f;
  check("It's Forever's nameplate level art, Ikar's pick", badgeStyles().every((b) => b.backgroundImage.includes(`sheet-${plateSheet}`)));
  Bench.settings.difficultyColor = false;
  Bench.renderAll();
  check("With difficulty colours off, every number has one colour", distinct(badgeStyles().map((b) => b.color)) === 1);
  Bench.settings.difficultyColor = true;
  Bench.renderAll();

  // The panel's real controls, which the checks above go around
  const optionsGroup = all("#controls .ctl-group").find((g) => g.querySelector("h2").textContent === "Edit Mode and game options");
  for (const id of ["textSize", "headerSaturation", "blockRest", "blockCombat", "blockHover", "opacityRest", "opacityCombat", "width"]) {
    const input = optionsGroup.querySelector(`[data-setting="${id}"]`);
    if (!input) {
      check(`${id} is in the game options`, false);
      continue;
    }
    const before = Bench.settings[id];
    input.value = input.min;
    input.dispatchEvent(new Event("input", { bubbles: true }));
    const moved = Bench.settings[id] === Number(input.min);
    input.value = before;
    input.dispatchEvent(new Event("input", { bubbles: true }));
    check(`${id} is in the game options and its slider works`, moved && Bench.settings[id] === before);
  }
  check("The discarded badges, padlocks and one-line popups have no control left", !one("[data-seg='badgeStyle']") && !one("[data-seg='noticeStyle']") && !one("[data-setting='levelBadge']") && !one("[data-setting='lockStyle']"));
  const tipsText = one(".ctl.tips") ? one(".ctl.tips").textContent : "";
  check("The game options show the Astuces page: shortcuts, rules, and where to bind the keys", tipsText.includes("Ctrl+clic") && tipsText.includes("Cadenas") && tipsText.includes("Options > Raccourcis clavier > Add-ons"));
  const textMarkers = one("#controls [data-seg='markerStyle'][data-value='text']");
  click(textMarkers);
  textMarkers.closest(".ctl").querySelector(".ctl-label").click();
  check("Clicking the name of a row of buttons presses none of them", Bench.settings.markerStyle === "text");
  click(one("#controls [data-seg='markerStyle'][data-value='icons']"));

  // Header saturation, on the proposal only
  Bench.settings.headerSaturation = 30;
  Bench.renderAll();
  check("Header saturation: bars and title follow", getComputedStyle(one(`${P} .ot-bar`)).filter.includes("0.3") && getComputedStyle(one(`${P} .ot-title`)).filter.includes("0.3"), getComputedStyle(one(`${P} .ot-bar`)).filter);
  check("Header saturation: Blizzard's stays as it is", getComputedStyle(one(`${B} .ot-bar`)).filter === "none");
  Bench.settings.headerSaturation = 40;
  Bench.renderAll();

  // Quest blocks: a strength for each state
  const blockOpacity = (id) => Number(getComputedStyle(rowOf(id), "::before").opacity);
  Bench.settings.blockRest = 20;
  Bench.settings.blockCombat = 40;
  Bench.settings.blockHover = 70;
  Bench.renderAll();
  await wait(200);
  check("Blocks: the default strength", Math.abs(blockOpacity(60) - 0.2) < 0.01, blockOpacity(60));
  Game.setCombat(true);
  await wait(200);
  check("Blocks: the combat strength", Math.abs(blockOpacity(60) - 0.4) < 0.01, blockOpacity(60));
  Game.setCombat(false);
  click(rowOf(60).querySelector(".ot-head"));
  await wait(200);
  check("Blocks: clicked uses the hover strength", Math.abs(blockOpacity(60) - 0.7) < 0.01, blockOpacity(60));
  check("Blocks: other rows stay at the default", Math.abs(blockOpacity(9) - 0.2) < 0.01, blockOpacity(9));
  click(one("#stage-prop .qpanel-close"));
  await wait(200);
  check("Blocks: closing the details ends it", Math.abs(blockOpacity(60) - 0.2) < 0.01, blockOpacity(60));
  const box = (el) => el.getBoundingClientRect();
  const blockLeft = box(rowOf(60)).left + parseFloat(getComputedStyle(rowOf(60), "::before").left);
  check("Blocks: the background reaches the level column", blockLeft <= box(rowOf(60).querySelector(".pt-gutter")).left + 1);
  Bench.settings.blockRest = 25;
  Bench.settings.blockCombat = 15;
  Bench.settings.blockHover = 50;

  // The whole tracker's opacity, in and out of combat, with its item buttons
  Bench.settings.opacityRest = 80;
  Bench.settings.opacityCombat = 30;
  Bench.renderAll();
  await wait(350);
  const trackerAlpha = () => Number(getComputedStyle(one(P)).opacity);
  const layerAlpha = () => Number(getComputedStyle(one("#stage-prop .secure-layer")).opacity);
  check("Tracker opacity: out of combat", Math.abs(trackerAlpha() - 0.8) < 0.01, trackerAlpha());
  check("Tracker opacity: item buttons follow", Math.abs(layerAlpha() - 0.8) < 0.01, layerAlpha());
  Game.setCombat(true);
  await wait(350);
  check("Tracker opacity: in combat", Math.abs(trackerAlpha() - 0.3) < 0.01, trackerAlpha());
  check("Tracker opacity: item buttons follow in combat", Math.abs(layerAlpha() - 0.3) < 0.01, layerAlpha());
  Game.setCombat(false);
  Bench.settings.opacityRest = 100;
  Bench.settings.opacityCombat = 100;
  Bench.renderAll();
  check("Blizzard's tracker isn't affected", getComputedStyle(one(B)).opacity === "1");

  // With the area highlight off, a closed group shows no mark, even for a quest whose item is usable: Ikar's ruling on 2026-11-08
  fresh("typical");
  Bench.settings.areaHighlight = false;
  Bench.renderAll();
  PT.state.open.groups[1] = false;
  Bench.renderAll();
  Game.enterArea(60, true);
  await wait(20);
  check("Highlight off: a closed group shows no mark, even for a quest whose item is usable", !group("g1").querySelector(".pt-here"));
  Bench.settings.areaHighlight = true;
  Bench.renderAll();
  check("Highlight on: the closed group counts that quest", group("g1").querySelector(".pt-here"));
  Bench.settings.areaHighlight = false;
  Game.enterArea(60, false);

  // The whole box answers to click, right click and drag
  fresh("open");
  await wait(20);
  click(rowOf(60).querySelector(".ot-text"));
  check("Clicking an objective opens the quest's details", one("#stage-prop .qpanel"));
  document.querySelectorAll(".qpanel").forEach((e) => e.remove());
  click(rowOf(60).querySelector(".pt-level"));
  check("Clicking the badge does too", one("#stage-prop .qpanel"));
  document.querySelectorAll(".qpanel").forEach((e) => e.remove());
  PT.state.selected = 0;
  rowOf(60).querySelector(".ot-text").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  check("Right-clicking an objective opens the quest's menu", one(".menu"));
  UI.closeMenus();
  const lineOf22 = rowOf(22).querySelector(".ot-text");
  const from22 = lineOf22.getBoundingClientRect();
  lineOf22.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true, button: 0, clientX: from22.left + 5, clientY: from22.top + 3 }));
  window.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: from22.left + 40, clientY: from22.top + 30 }));
  const ghost = one("#stage-prop .drag-box");
  check("Dragging an objective picks up the quest", ghost);
  check("The whole box follows the cursor", ghost && ghost.querySelector(".pt-level") && ghost.querySelector(".ot-line") && ghost.querySelector(".ot-head-text"));
  check("The box stays with the point it was grabbed by", ghost && Math.abs(ghost.getBoundingClientRect().left - (from22.left + 40 - (from22.left + 5 - rowOf(22).getBoundingClientRect().left))) < 2);
  check("The source row dims", rowOf(22).classList.contains("dragging"));
  Bench.renderAll();
  check("It stays dimmed through a redraw", rowOf(22).classList.contains("dragging"));
  check("The box doesn't stop a drop landing", ghost && getComputedStyle(ghost.querySelector(".pt-row"), "::before").pointerEvents === "none");
  window.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
  await wait(5);
  check("Letting go removes it", !one("#stage-prop .drag-box"));
  await drag(rowOf(22).querySelector(".ot-text"), rowOf(60), "top");
  check("Dropping from an objective reorders", PT.state.groups[0].quests[0] === 22, PT.state.groups[0].quests.join());

  // Popups and the timer: centred, and sized by the text up to the panel's width
  fresh("typical");
  Game.addPopup(239, "COMPLETE");
  Game.startTimer(9, 60);
  Bench.settings.width = 340;
  Bench.renderAll();
  await wait(20);
  const zoomed = UI.scaleOf(one(P));
  const centreOf = (el) => (el.getBoundingClientRect().left + el.getBoundingClientRect().right) / 2;
  const centred = (el) => Math.abs(centreOf(el) - centreOf(one(P))) < 1.5;
  const popupEl = () => one(`${P} .pt-popups .aq`);
  const timerEl = () => one(`${P} .qt`);
  check("The popup is centred", centred(popupEl()), `${centreOf(popupEl())} against ${centreOf(one(P))}`);
  check("The timer is centred", centred(timerEl()), `${centreOf(timerEl())} against ${centreOf(one(P))}`);
  check("The timer leaves the title room", one(`${P} .ot-title`).getBoundingClientRect().top >= timerEl().getBoundingClientRect().bottom - 1);
  const heightAt = async (size) => {
    Bench.settings.textSize = size;
    Bench.renderAll();
    await wait(10);
    return [popupEl().getBoundingClientRect().height, timerEl().getBoundingClientRect().height];
  };
  const [popup12, timer12] = await heightAt(12);
  const [popup16, timer16] = await heightAt(16);
  check("The popup scales with the text", Math.abs(popup16 / popup12 - 16 / 12) < 0.05, popup16 / popup12);
  check("The timer scales with the text", Math.abs(timer16 / timer12 - 16 / 12) < 0.05, timer16 / timer12);
  check("Both are still centred at 16", centred(popupEl()) && centred(timerEl()));
  Bench.settings.width = 260;
  await heightAt(20);
  const insidePanel = (el) => el.getBoundingClientRect().width <= one(P).getBoundingClientRect().width + 1;
  check("At text 20 they stop at the panel's width", insidePanel(popupEl()) && insidePanel(timerEl()), `${popupEl().getBoundingClientRect().width} and ${timerEl().getBoundingClientRect().width} against ${one(P).getBoundingClientRect().width}`);
  check("And stay centred", centred(popupEl()) && centred(timerEl()));
  check("The timer still leaves the title room", one(`${P} .ot-title`).getBoundingClientRect().top >= timerEl().getBoundingClientRect().bottom - 1);
  check("Blizzard's keep their fixed size", Math.abs(one(`${B} .aq`).getBoundingClientRect().height - 68 * zoomed) < 1);
  await heightAt(12);
  Game.clearTimers();
  Bench.renderAll();

  // While a quest is dragged, the player's groups light up, the one under the cursor more so
  fresh("open");
  const wrapOf = (key) => group(key).closest(".pt-groupwrap");
  const alpha = (css) => Number(css.match(/[\d.]+/g)[3] || 0);
  const glow = (key) => alpha(getComputedStyle(wrapOf(key), "::before").backgroundColor);
  const moveTo = (el, y) => {
    const r = el.getBoundingClientRect();
    window.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: r.left + 40, clientY: y === undefined ? r.top + r.height / 2 : y }));
  };
  const pickUp = (el) => {
    const r = el.getBoundingClientRect();
    el.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true, button: 0, clientX: r.left + 30, clientY: r.top + 5 }));
    window.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: r.left + 40, clientY: r.top + 20 }));
  };
  check("At rest, no group is lit", glow("g1") === 0 && glow("g2") === 0, `${glow("g1")} and ${glow("g2")}`);
  pickUp(rowOf(12).querySelector(".ot-head"));
  check("Dragging a quest lights every player's group", glow("g1") > 0 && glow("g2") > 0, `${glow("g1")} and ${glow("g2")}`);
  check("And not the automatic ones", glow("hMarche de l'Ouest") === 0);
  check("And the Suivi bar, for a new group", alpha(getComputedStyle(bar("mine")).backgroundColor) > 0);
  moveTo(group("g2"));
  check("Over a group's header, it lights up more", glow("g2") > glow("g1"), `${glow("g2")} against ${glow("g1")}`);
  moveTo(rowOf(60));
  check("Over a row in a group, that group lights up more", glow("g1") > glow("g2"), `${glow("g1")} against ${glow("g2")}`);
  check("And the line shows where the quest will land", one("#stage-prop .drag-line").style.display === "block");
  Bench.renderAll();
  check("A redraw keeps all of that", glow("g1") > glow("g2") && glow("g2") > 0, `${glow("g1")} against ${glow("g2")}`);
  moveTo(group("g1"), group("g1").getBoundingClientRect().bottom + 1);
  check("The gap under a group's header is part of it", glow("g1") > glow("g2") && one("#stage-prop .drag-line").style.display === "none");
  moveTo(bar("mine"));
  check("Over the bar, it lights up more", alpha(getComputedStyle(bar("mine")).backgroundColor) > glow("g1"));
  moveTo(group("g1"), group("g1").getBoundingClientRect().bottom + 1);
  window.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
  await wait(5);
  check("Dropping in that gap adds the quest to the group", PT.state.groups[0].quests.includes(12), PT.state.groups[0].quests.join());
  check("Letting go ends the lighting", glow("g1") === 0 && glow("g2") === 0, `${glow("g1")} and ${glow("g2")}`);
  pickUp(group("g2"));
  check("Dragging a group lights nothing", glow("g1") === 0);
  window.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
  await wait(5);

  // The grey line a quest leaves in its own section
  fresh("typical");
  const movedOf = (id) => one(`${P} .pt-moved[data-quest="${id}"]`);
  const blockEdgeOf = (row) => row.getBoundingClientRect().left + parseFloat(getComputedStyle(row, "::before").left) * UI.scaleOf(one(P));
  const brightness = (css) => css.match(/[\d.]+/g).slice(0, 3).reduce((sum, v) => sum + Number(v), 0);
  check("A quest in a group leaves a line in its section", movedOf(9) && movedOf(22));
  check("It isn't a second row", all(`${P} .pt-row[data-quest="9"]`).length === 1 && rowOf(9).dataset.group === "1");
  check("It's greyer than a title", brightness(getComputedStyle(movedOf(9)).color) < brightness(getComputedStyle(rowOf(12).querySelector(".ot-head")).color));
  check("It holds no objectives or item button", !movedOf(9).querySelector(".ot-line, [data-slot]"));
  check("The section's count leaves it out", group("hMarche de l'Ouest").querySelector(".pt-count").textContent.endsWith("/3"), group("hMarche de l'Ouest").querySelector(".pt-count").textContent);
  const sectionLines = () => all(`${P} .pt-groupwrap`).find((w) => w.contains(group("hMarche de l'Ouest"))).querySelectorAll(".pt-row, .pt-moved");
  check("It keeps the quest's place in the section", sectionLines()[0].dataset.quest === "9", [...sectionLines()].map((l) => l.dataset.quest).join());
  check("Forever Quest Tint marks it too, as it scans every title", movedOf(22).querySelector(".fqt-mark"));
  Bench.settings.textSize = 20;
  Bench.renderAll();
  check("A long title stays on one line", movedOf(22).getBoundingClientRect().height < 20 * 1.5 * UI.scaleOf(one(P)), movedOf(22).getBoundingClientRect().height);
  Bench.settings.textSize = 12;
  Bench.renderAll();
  click(movedOf(9));
  check("Clicking it opens the quest's details", one("#stage-prop .qpanel"));
  click(one("#stage-prop .qpanel-close"));
  movedOf(9).dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  check("Right-clicking it opens the quest's menu", one(".menu") && one(".menu").textContent.includes("Arrêter le suivi"));
  UI.closeMenus();
  Game.setCombat(true);
  click(movedOf(9));
  check("In combat, clicking it is refused, as on a row", !one("#stage-prop .qpanel"));
  click(movedOf(9).querySelector(".pt-moved-back"));
  check("In combat, its button is refused", PT.state.groups[0].quests.includes(9));
  Game.setCombat(false);
  document.querySelectorAll(".uierror").forEach((e) => e.remove());
  click(movedOf(9).querySelector(".pt-moved-back"));
  check("Its button brings the quest back", !PT.state.groups[0].quests.includes(9) && rowOf(9).dataset.group === "" && !movedOf(9));
  check("Back in the same place", sectionLines()[0].dataset.quest === "9", [...sectionLines()].map((l) => l.dataset.quest).join());
  check("Its button doesn't open the details", !one("#stage-prop .qpanel"));
  await drag(rowOf(12).querySelector(".ot-head"), group("g1"));
  check("Dragging a quest to a group leaves a line", movedOf(12));
  fresh("open");
  const events = Game.order.filter((id) => Game.quests.get(id).category === "events");
  PT.state.groups[0].quests.push(...events);
  PT.render();
  check("A section left with only lines stays", bar("events") && events.every((id) => movedOf(id)));
  check("And counts nothing", bar("events").querySelector(".pt-count").textContent === "");
  PT.state.search = "bougies";
  PT.render();
  check("Search hides the lines", !one(`${P} .pt-moved`) && rowOf(60));
  PT.state.search = "";
  PT.render();

  // Options moved to the game options, and the new ones
  fresh("open");
  const groupTitled = (title) => all("#controls .ctl-group").find((g) => g.querySelector("h2").textContent === title);
  const gameOptions = groupTitled("Edit Mode and game options");
  check("The share option is in the game options", gameOptions.querySelector("[data-setting='shareOnHover']"));
  check("The group search button is off by default, Ikar's defaults", Bench.settings.findGroup === false && !rowOf(176).querySelector(".eye-btn"));
  gameOptions.querySelector("[data-setting='findGroup']").click();
  check("A group with a search button shows it once the option is on", rowOf(176).querySelector(".eye-btn") && Bench.settings.findGroup === true);
  gameOptions.querySelector("[data-setting='findGroup']").click();
  check("The group search option hides it again", !rowOf(176).querySelector(".eye-btn") && Bench.settings.findGroup === false);
  check("Collapse-all is the bars' double arrow, pointing down while open, Ikar's ruling", one(`${P} .pt-min .pt-arrow.open`) && !one(`${P} .pt-tools .hl`));
  check("The filter is a plain icon, as the magnifying glass", one(`${P} .pt-tool.pt-filter`));
  const advanced = groupTitled("Game options: advanced");
  check("The six polish sliders are in the advanced options", advanced && advanced.querySelectorAll("input[type='range']").length === 6);
  check("Under the title is one of them", advanced.textContent.includes("Under the title"));
  check("Between quests is gone", !advanced.textContent.includes("Between quests"));
  check("No polish group is left", !groupTitled("Polish (proposal)"));
  check("The area highlight is in the game options", gameOptions.querySelector("[data-setting='areaHighlight']"));
  const indentSlider = [...advanced.querySelectorAll(".ctl")].find((c) => c.textContent.includes("Group indent")).querySelector("input");
  indentSlider.value = 10;
  indentSlider.dispatchEvent(new Event("input", { bubbles: true }));
  check("A polish slider still works", Bench.tokens.groupIndent === 10, Bench.tokens.groupIndent);
  [...advanced.querySelectorAll("button")].find((b) => b.textContent === "Reset these").click();
  check("And they reset", Bench.tokens.groupIndent === 0, Bench.tokens.groupIndent);

  // Quests touch, with a thin line on top of each and one more under the last
  fresh("typical");
  const zoomNow = () => UI.scaleOf(one(P));
  const gapBetween = (a, b) => b.getBoundingClientRect().top - a.getBoundingClientRect().bottom;
  check("Two quests' backgrounds touch", Math.abs(gapBetween(rowOf(60), rowOf(9)) - 6 * zoomNow()) < 1, gapBetween(rowOf(60), rowOf(9)));
  const topLine = (row) => row.querySelector(":scope > .pt-sep.top");
  const bottomLine = (row) => row.querySelector(":scope > .pt-sep.bottom");
  check("The first quest in a group has a line above it", topLine(rowOf(60)));
  check("The next one has too", topLine(rowOf(9)));
  check("Only the last has one below it", !bottomLine(rowOf(60)) && !bottomLine(rowOf(9)) && bottomLine(rowOf(22)));
  check("It's thin", topLine(rowOf(9)).getBoundingClientRect().height <= 1 * zoomNow() + 0.5, topLine(rowOf(9)).getBoundingClientRect().height);
  check("It spans the background", Math.abs(topLine(rowOf(9)).getBoundingClientRect().left - blockEdgeOf(rowOf(9))) < 1);
  check("It's half as bright", getComputedStyle(topLine(rowOf(9))).opacity === "0.5" && getComputedStyle(bottomLine(rowOf(22))).opacity === "0.5");
  const lineGap = 3 * zoomNow();
  check("The top line is as far above its quest as the bottom one is below", Math.abs(rowOf(60).getBoundingClientRect().top - topLine(rowOf(60)).getBoundingClientRect().top - lineGap) < 1 && Math.abs(bottomLine(rowOf(22)).getBoundingClientRect().top - rowOf(22).getBoundingClientRect().bottom - lineGap) < 1);
  check("Grey lines get them too", one(`${P} .pt-moved[data-quest="22"] > .pt-sep.top`) && one(`${P} .pt-moved[data-quest="9"] > .pt-sep.top`));
  fresh("open");
  const listsWithRows = all(`${P} .pt-groupwrap`).filter((w) => w.querySelector(":scope > .pt-row, :scope > .pt-moved"));
  check("Every open list has a line per entry and one to close it", listsWithRows.length > 0 && listsWithRows.every((w) => w.querySelectorAll(".pt-sep").length === w.querySelectorAll(":scope > .pt-row, :scope > .pt-moved").length + 1));
  pickUp(rowOf(22).querySelector(".ot-head"));
  const draggedLines = all("#stage-prop .drag-box .pt-sep");
  check("Dragging's copy of a quest draws none", draggedLines.length === 2 && draggedLines.every((el) => getComputedStyle(el).display === "none"), draggedLines.length);
  window.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
  await wait(5);

  // The eye on each group focuses it
  fresh("open");
  check("Every group has an eye", all(`${P} .pt-group`).every((g) => g.querySelector(".pt-focus")));
  click(group("g1").querySelector(".pt-focus"));
  check("It leaves that group the only one open", rows().length === PT.state.groups[0].quests.length && rows().every((r) => r.dataset.group === "1"), rowIDs().join());
  click(group("g1").querySelector(".pt-focus"));
  check("A second click doesn't close it", rows().length === PT.state.groups[0].quests.length);
  fresh("typical");
  click(group("hForêt d'Elwynn").querySelector(".pt-focus"));
  check("It opens a group that was closed", rowOf(176) && !rowOf(12), rowIDs().join());

  // Journal
  fresh("typical");
  const tracked = () => PT.state.groups.flatMap((g) => g.quests);
  check("Journal holds every other category", all(`${P} .pt-journal .pt-subbar`).length === all(`${P} .pt-bar`).length - 2 && !bar("mine").closest(".pt-journal"));
  check("Its count is every quest not in a group", bar("journal").querySelector(".pt-count").textContent.endsWith("/" + (Game.order.length - tracked().length)), bar("journal").querySelector(".pt-count").textContent);
  click(bar("journal"));
  check("Collapsing it hides all of them", !bar("world") && !rowOf(12));
  check("Suivi stays as it was", rowOf(60));
  Game.setCombat(true);
  click(bar("journal"));
  check("In combat it's locked like any bar", !bar("world"));
  Game.setCombat(false);
  PT.state.search = "lardeur";
  PT.render();
  check("Search still reaches inside it", rowOf(176));
  PT.state.search = "";
  PT.render();
  Game.superTrack(12);
  check("Focusing a quest in it opens it", rowOf(12));
  Game.superTrack(12);
  click(bar("journal"));
  const journalCount = bar("journal").querySelector(".pt-count").textContent;
  Game.accept();
  check("A new quest makes it glow while it's closed", bar("journal").classList.contains("a-barflash") && bar("journal").querySelector(".pt-count").textContent !== journalCount);
  fresh("typical");
  const orderBefore = (PT.state.categoryOrder || []).join();
  await drag(bar("misc"), bar("journal"));
  check("A category can't be dropped on Journal", (PT.state.categoryOrder || []).join() === orderBefore);
  await drag(bar("journal"), bar("mine"), "top");
  check("Journal and Suivi keep their places", all(`${P} .pt-bar`)[0].dataset.cat === "mine" && all(`${P} .pt-bar`)[1].dataset.cat === "journal");

  // Being in a group is what tracked means
  fresh("typical");
  const sameSet = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
  check("The game's list is what's in the groups", sameSet(Game.watch, tracked()), Game.watch.join());
  check("So Blizzard's tracker shows just those", all(`${B} .ot-block`).length === tracked().length);
  await drag(rowOf(12).querySelector(".ot-head"), group("g1"));
  check("Moving a quest into a group tracks it", Game.watch.includes(12));
  check("And Blizzard's tracker shows it", one(`${B} .ot-block[data-quest="12"]`));
  click(one(`${P} .pt-moved[data-quest="12"] .pt-moved-back`));
  check("Bringing it back stops tracking it", !Game.watch.includes(12));
  Game.toggleWatch(12, true);
  await wait(5);
  check("Tracked from outside: it joins the top group", PT.state.groups[0].quests.includes(12), PT.state.groups[0].quests.join());
  Game.toggleWatch(12, false);
  await wait(5);
  check("Untracked from outside: it leaves its group", !tracked().includes(12) && rowOf(12).dataset.group === "");
  const placedBefore = JSON.stringify(PT.state.groups);
  Game.toggleWatch(9, false);
  Game.toggleWatch(9, true);
  await wait(5);
  check("Off and on within a frame, as DialogueUI does, changes nothing", JSON.stringify(PT.state.groups) === placedBefore, JSON.stringify(PT.state.groups));
  Game.toggleWatch(12, true);
  Game.toggleWatch(12, false);
  await wait(5);
  check("On and off within a frame changes nothing", JSON.stringify(PT.state.groups) === placedBefore, JSON.stringify(PT.state.groups));
  PT.state.groups.reverse();
  PT.render();
  Game.toggleWatch(12, true);
  await wait(5);
  check("Whichever group is on top takes it", PT.state.groups[0].id === 2 && PT.state.groups[0].quests.includes(12), PT.state.groups[0].quests.join());
  group("g2").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  check("And no group is marked for new quests any more", !one(".menu").textContent.includes("nouvelles"));
  UI.closeMenus();
  Game.setCombat(true);
  Game.toggleWatch(102, true);
  await wait(5);
  check("In combat its row waits", !tracked().includes(102));
  Game.setCombat(false);
  await wait(5);
  check("It moves when combat ends", tracked().includes(102));

  fresh("typical");
  click(rowOf(12), { shiftKey: true });
  check("Shift-click tracks", Game.watch.includes(12) && tracked().includes(12));
  check("Without opening the details", !one("#stage-prop .qpanel"));
  click(rowOf(12), { shiftKey: true });
  check("Shift-click again stops tracking", !Game.watch.includes(12) && !tracked().includes(12));
  rowOf(12).dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  check("A quest out of the groups offers Suivre quête", one(".menu") && one(".menu").textContent.includes("Suivre quête"));
  UI.closeMenus();
  Bench.settings.questPOI = true;
  Bench.renderAll();
  click(rowOf(12).querySelector(".poi"));
  check("Its map button tracks it, as Blizzard's does", tracked().includes(12) && Game.superTracked === 12);
  Game.superTrack(12);
  Bench.settings.questPOI = false;
  Bench.renderAll();

  fresh("empty");
  check("With no groups, nothing is tracked", Game.watch.length === 0);
  check("The Suivi bar still shows, for its +", bar("mine") && bar("mine").querySelector(".pt-add"));
  check("With nothing to count", bar("mine").querySelector(".pt-count").textContent === "");
  Game.toggleWatch(12, true);
  await wait(5);
  check("Tracking a quest then creates a group in the client's language", PT.state.groups.length === 1 && PT.state.groups[0].name === "Quêtes" && PT.state.groups[0].quests[0] === 12, JSON.stringify(PT.state.groups));
  check("Which shows it, open", rowOf(12) && rowOf(12).dataset.group === String(PT.state.groups[0].id));
  Game.toggleWatch(102, true);
  await wait(5);
  check("And the next one joins it", PT.state.groups.length === 1 && PT.state.groups[0].quests.includes(102));

  fresh("closed");
  Bench.settings.autoQuestWatch = true;
  const autoTracked = Game.accept();
  await wait(5);
  check("Auto-tracking puts a new quest in a group", tracked().includes(autoTracked.id));
  check("Without opening anything", rows().length === 0);
  Bench.settings.autoQuestWatch = false;
  const notTracked = Game.accept();
  await wait(5);
  check("With auto-tracking off, it stays in Journal", !tracked().includes(notTracked.id));

  fresh("typical");
  Bench.settings.height = 400;
  Game.order.slice().forEach((id) => Game.toggleWatch(id, true));
  await wait(5);
  check("The game stops tracking at 25", Game.watch.length === 25, Game.watch.length);
  check("So its limit caps what auto-joins a group", tracked().length === 25, tracked().length);
  const overLimit = Game.order.find((id) => !tracked().includes(id));
  PT.state.open.categories.world = true;
  Game.quests.get(overLimit) && PT.preset("open");
  Game.order.slice().forEach((id) => Game.toggleWatch(id, true));
  await wait(5);
  const extra = Game.order.find((id) => !tracked().includes(id));
  await drag(rowOf(extra).querySelector(".ot-head"), group("g1"));
  check("A 26th quest placed by hand stays in its group", tracked().includes(extra));
  check("Though the game's list stays at 25", Game.watch.length === 25 && !Game.watch.includes(extra));
  Bench.settings.height = 1000;

  fresh("typical");
  PT.preset("install");
  check("A fresh install puts what the game tracks in Quêtes", PT.state.groups.length === 1 && PT.state.groups[0].name === "Quêtes" && PT.state.groups[0].quests.length === window.FakeLog.QUESTS.filter((q) => q.tracked).length, JSON.stringify(PT.state.groups));
  await wait(5);
  fresh("typical");
  const deletedQuests = PT.state.groups[1].quests.slice();
  PT.state.groups[1].id === 2 && group("g2").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  [...document.querySelectorAll(".menu *")].find((el) => el.children.length === 0 && el.textContent === "Supprimer le groupe").click();
  document.querySelector("#stage-prop .dialog [data-ok]").click();
  check("Deleting a group stops tracking its quests", deletedQuests.every((id) => !Game.watch.includes(id)));
  check("It leaves no line behind", !one(`${P} .pt-deleted`) && !one(P).textContent.includes("À faire plus tard"));
  const undoItem = () => all(".menu.gear-menu .menu-item").find((i) => i.textContent === "Annuler la suppression de « À faire plus tard »");
  Game.setCombat(true);
  group("g1").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  [...document.querySelectorAll(".menu *")].find((el) => el.children.length === 0 && el.textContent === "Supprimer le groupe").click();
  check("Deleting is refused in combat, with the game's message", group("g1") && !one("#stage-prop .dialog") && one("#stage-prop .uierror"));
  document.querySelectorAll(".uierror").forEach((e) => e.remove());
  click(one(`${P} .pt-gear`));
  check("Undo is refused in combat, with the gear", !undoItem() && !group("g2") && one("#stage-prop .uierror"));
  Game.setCombat(false);
  click(one(`${P} .pt-gear`));
  check("The gear's menu offers the undo first", undoItem() && one(".menu.gear-menu .menu-item") === undoItem());
  undoItem().click();
  await wait(5);
  check("Undo brings the group back in its place", PT.state.groups[1] && PT.state.groups[1].id === 2 && group("g2"), PT.state.groups.map((g) => g.id).join());
  check("With its quests, tracked again", deletedQuests.every((id) => PT.state.groups[1].quests.includes(id) && Game.watch.includes(id)));
  click(one(`${P} .pt-gear`));
  check("And the menu no longer offers it", one(".menu.gear-menu") && !undoItem());
  UI.closeMenus();
  group("g2").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  [...document.querySelectorAll(".menu *")].find((el) => el.children.length === 0 && el.textContent === "Supprimer le groupe").click();
  document.querySelector("#stage-prop .dialog [data-ok]").click();
  await wait(5);
  Game.toggleWatch(deletedQuests[0], true);
  await wait(5);
  click(one(`${P} .pt-gear`));
  undoItem().click();
  await wait(5);
  check("A quest that joined another group since stays there", PT.state.groups[0].quests.includes(deletedQuests[0]) && !PT.state.groups[1].quests.includes(deletedQuests[0]));

  // The lock
  fresh("typical");
  const openBefore = JSON.stringify(PT.state.open);
  click(one(`${P} .pt-lock`));
  check("The padlock locks out of combat", PT.state.locked && one(`${P} .pt-lock.shut`));
  click(bar("world"));
  click(group("hMarche de l'Ouest"));
  click(bar("journal"));
  click(group("g1").querySelector(".pt-focus"));
  click(one(`${P} [data-action="collapse-all"]`));
  check("Locked: bars, groups, the eye and collapse all do nothing", JSON.stringify(PT.state.open) === openBefore);
  check("Locked: and no error text", !one("#stage-prop .uierror"));
  await drag(rowOf(12).querySelector(".ot-head"), group("g1"));
  check("Locked: dragging does nothing", !tracked().includes(12) && !one("#stage-prop .drag-box"));
  click(rowOf(12).querySelector(".ot-head"));
  check("Locked: a quest still opens its details", one("#stage-prop .qpanel"));
  click(one("#stage-prop .qpanel-close"));
  Bench.settings.height = 300;
  Bench.renderAll();
  await wait(20);
  one(`${P} .pt-scroll`).dispatchEvent(new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 100 }));
  check("Locked: scrolling still works", one(`${P} .pt-scroll`).scrollTop > 0);
  one(`${P} .pt-scroll`).scrollTop = 0;
  Bench.settings.height = 1000;
  Bench.renderAll();
  Game.setCombat(true);
  Game.setCombat(false);
  check("A fight doesn't undo the player's lock", PT.state.locked && one(`${P} .pt-lock.shut`));
  Game.superTrack(176);
  check("Locked: focusing a quest opens nothing yet", !rowOf(176));
  click(one(`${P} .pt-lock`));
  check("The padlock unlocks again", !PT.state.locked && one(`${P} .pt-lock.open`));
  check("And the focused quest's group then opens", rowOf(176));
  Game.superTrack(176);
  click(bar("world"));
  check("Unlocked: bars work", JSON.stringify(PT.state.open) !== openBefore);

  // The + on the Suivi bar
  fresh("typical");
  const groupCount = () => PT.state.groups.length;
  const addButton = () => bar("mine").querySelector(".pt-add");
  check("Only the Suivi bar has a +", all(`${P} .pt-add`).length === 1 && addButton());
  click(addButton());
  check("It makes a group, at the end", groupCount() === 3 && PT.state.groups[2].name === "Nouveau groupe" && PT.state.groups[2].quests.length === 0);
  check("Named in place", one(`${P} .pt-rename`));
  check("Without closing the bar", PT.state.open.categories.mine);
  check("And the group starts open and tracks nothing new", PT.state.open.groups[PT.state.groups[2].id] && sameSet(Game.watch, tracked()));
  PT.state.renaming = null;
  PT.render();
  fresh("closed");
  click(addButton());
  check("On a closed bar, it opens the bar to show the new group", PT.state.open.categories.mine && one(`${P} .pt-rename`));
  PT.state.renaming = null;
  PT.render();
  fresh("empty");
  click(addButton());
  check("With no groups, it makes the first", groupCount() === 1 && one(`${P} .pt-rename`));
  PT.state.renaming = null;
  PT.render();
  fresh("typical");
  click(one(`${P} .pt-lock`));
  const flashesBefore = PT.state.lockFlash;
  click(addButton());
  check("Locked, it does nothing and flashes the padlock", groupCount() === 2 && PT.state.lockFlash > flashesBefore);
  click(one(`${P} .pt-lock`));
  Game.setCombat(true);
  click(addButton());
  check("In combat, it's refused with the game's message", groupCount() === 2 && one("#stage-prop .uierror"));
  click(one(`${P} .pt-lock`));
  click(addButton());
  check("Even unlocked for the fight", groupCount() === 2);
  Game.setCombat(false);
  bar("mine").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 300, clientY: 300 }));
  Game.setCombat(true);
  [...document.querySelectorAll(".menu *")].find((el) => el.children.length === 0 && el.textContent === "Nouveau groupe").click();
  check("The bar's menu is refused in combat too", groupCount() === 2);
  Game.setCombat(false);

  // Names
  fresh("open");
  check("The first section is called Suivi", bar("mine").querySelector(".pt-bar-text").textContent === "Suivi");
  check("The tracker shows no English", !/\b(Tracked|Track|Mes groupes|Groups?|Quests?|Objectives?|Search|Filter)\b/.test(one(P).textContent), (one(P).textContent.match(/\b(Tracked|Track|Mes groupes|Groups?|Quests?|Objectives?|Search|Filter)\b/) || [])[0]);

  // Double arrows on the right of bars and groups
  fresh("typical");
  const arrowOf = (el) => el.querySelector(":scope > .pt-arrow");
  const centreX = (el) => { const r = el.getBoundingClientRect(); return (r.left + r.right) / 2; };
  const rightOf = (el) => el.getBoundingClientRect().right;
  check("The proposal has no + or - toggles left", !one(`${P} .pt-toggle`) && !one(`${P} .btn-sec`));
  check("Every bar and group has an arrow", all(`${P} .pt-bar, ${P} .pt-group`).every(arrowOf));
  check("Closed points left, open points down", arrowOf(group("g2")).matches(":not(.open)") && arrowOf(group("g1")).matches(".open") && arrowOf(bar("mine")).matches(".open") && arrowOf(bar("instances")).matches(":not(.open)"));
  check("Open is the same art turned a quarter", getComputedStyle(arrowOf(group("g1")).querySelector(".tex")).transform !== "none" && getComputedStyle(arrowOf(group("g2")).querySelector(".tex")).transform === "none");
  check("Group and bar arrows line up", Math.abs(centreX(arrowOf(group("g1"))) - centreX(arrowOf(bar("mine")))) < 1, `${centreX(arrowOf(group("g1")))} and ${centreX(arrowOf(bar("mine")))}`);
  check("And so do their counts", Math.abs(rightOf(group("g1").querySelector(".pt-count")) - rightOf(bar("mine").querySelector(".pt-count"))) < 1);
  check("The group's name still starts to the left", group("g1").querySelector(".pt-group-name").getBoundingClientRect().left < group("g1").querySelector(".pt-focus").getBoundingClientRect().left);
  check("The eye is left of the count", rightOf(group("g1").querySelector(".pt-focus")) <= group("g1").querySelector(".pt-count").getBoundingClientRect().left + 0.5);
  click(arrowOf(group("g2")));
  check("Clicking an arrow opens its group", PT.state.open.groups[2] && arrowOf(group("g2")).matches(".open"));
  click(arrowOf(bar("instances")));
  check("And its bar", PT.state.open.categories.instances && arrowOf(bar("instances")).matches(".open"));

  // The padlock shows which state it's in
  fresh("typical");
  const shackle = () => getComputedStyle(one(`${P} .pt-shackle`)).transform;
  check("Unlocked, the padlock's shackle is lifted", shackle() !== "none", shackle());
  check("Unlocked, no bright copy", !one(`${P} .pt-lock .pt-lock-add`));
  click(one(`${P} .pt-lock`));
  check("Locked, it's closed", shackle() === "none", shackle());
  check("Locked, a copy added on top makes it much brighter", one(`${P} .pt-lock .pt-lock-add`) && getComputedStyle(one(`${P} .pt-lock .pt-lock-add`)).mixBlendMode === "plus-lighter");
  click(one(`${P} .pt-lock`));
  Game.setCombat(true);
  check("In combat, it's closed", shackle() === "none", shackle());
  click(one(`${P} .pt-lock`));
  check("Unlocked for the fight, it's lifted", shackle() !== "none", shackle());
  Game.setCombat(false);

  // A short glow when an objective updates
  fresh("typical");
  Game.progress(60, 1);
  check("Progress makes the quest's row glow", rowOf(60).classList.contains("a-progress"));
  await wait(800);
  check("Once", !rowOf(60).classList.contains("a-progress"));
  const flashOption = () => groupTitled("Edit Mode and game options").querySelector("[data-setting='progressFlash']");
  flashOption().click();
  Game.progress(60, 1);
  check("The option turns it off", !rowOf(60).classList.contains("a-progress"));
  flashOption().click();
  fresh("closed");
  Game.progress(60, 1);
  check("Inside a closed group, the closed bar glows", bar("mine").classList.contains("a-barflash"));
  await wait(1000);

  // The tracker background: the rows stay inside it, and only the bars' art, which has its own backing, goes past it
  fresh("open");
  Game.addPopup(239, "COMPLETE");
  Game.addPopup(102, "OFFER");
  Game.startTimer(9, 60);
  Game.enterArea(60, true);
  Bench.settings.areaHighlight = true;
  Bench.renderAll();
  await wait(20);
  const nineBox = (root) => one(`${root} .ot-nine`).getBoundingClientRect();
  const unitsLeftOf = (root) => (one(root).getBoundingClientRect().left - nineBox(root).left) / UI.scaleOf(one(root));
  check("Background: Blizzard's starts 30 left of its frame", Math.abs(unitsLeftOf(B) - 30) < 0.5, unitsLeftOf(B));
  check("Background: the proposal's starts 5 left of the rows", Math.abs(unitsLeftOf(P) - 5) < 0.5, unitsLeftOf(P));
  const rightGap = (root, stage) => (one(stage).getBoundingClientRect().right - nineBox(root).right) / UI.scaleOf(one(root));
  check("Background: both end at the same place on screen", Math.abs(rightGap(B, "#stage-blizz .stage-inner") - rightGap(P, "#stage-prop .stage-inner")) < 0.5, `${rightGap(B, "#stage-blizz .stage-inner")} and ${rightGap(P, "#stage-prop .stage-inner")}`);
  const blockEdge = (row) => row.getBoundingClientRect().left + parseFloat(getComputedStyle(row, "::before").left) * UI.scaleOf(one(P));
  const pastLeft = () => {
    const edge = nineBox(P).left - 0.5;
    const parts = all(`${P} *`)
      .filter((el) => !el.closest(".ot-nine, .bar-bg") && !el.matches(".pt-scroll") && el.getClientRects().length && el.getBoundingClientRect().left < edge)
      .map((el) => el.className);
    return [...new Set(parts)].concat(rows().some((r) => blockEdge(r) < edge) ? ["quest block"] : []);
  };
  for (const size of [12, 16, 20]) {
    for (const buttons of [false, true]) {
      Bench.settings.textSize = size;
      Bench.settings.questPOI = buttons;
      Bench.renderAll();
      await wait(10);
      const state = `at text ${size}, map buttons ${buttons ? "on" : "off"}`;
      check(`Background: nothing passes its left edge ${state}`, !pastLeft().length, pastLeft().join(", "));
      check(`Blocks: each covers its level ${state}`, rows().every((r) => blockEdge(r) <= r.querySelector(".pt-level").getBoundingClientRect().left + 1));
    }
  }
  Bench.settings.textSize = 12;
  Bench.settings.questPOI = false;
  Bench.settings.areaHighlight = false;
  Bench.settings.height = 300;
  Bench.renderAll();
  await wait(20);
  check("Background: the scrollbar's arrows are inside its right edge", one(`${P} .pt-sb-up`).getBoundingClientRect().right <= nineBox(P).right + 0.5, `${one(`${P} .pt-sb-up`).getBoundingClientRect().right} <= ${nineBox(P).right}`);
  Bench.settings.height = 1000;
  fresh("typical");
  Bench.renderAll();

  // Auto-tracking: the addon's option, off on install
  const autoOption = () => groupTitled("Edit Mode and game options").querySelector("[data-setting='autoQuestWatch']");
  check("Auto-tracking is an option in the game options", autoOption());
  Bench.settings.autoQuestWatch = true;
  fresh("install");
  check("A fresh install turns auto-tracking off", Bench.settings.autoQuestWatch === false);
  check("And the option shows it off", autoOption() && !autoOption().checked);
  const offAccepted = Game.accept();
  await wait(5);
  check("So a new quest stays under Journal", !tracked().includes(offAccepted.id) && !Game.watch.includes(offAccepted.id));
  autoOption().click();
  check("The option turns it back on", Bench.settings.autoQuestWatch === true);
  const onAccepted = Game.accept();
  await wait(5);
  check("Then a new quest joins the top group", tracked().includes(onAccepted.id));
  fresh("typical");
  const journalQuest = 12;
  check("La milice du peuple starts under Journal", !tracked().includes(journalQuest));
  Game.progress(journalQuest, 1);
  await wait(5);
  check("With it on, progress tracks a Journal quest, as Blizzard's quest map does", tracked().includes(journalQuest));
  autoOption().click();
  fresh("typical");
  Game.progress(journalQuest, 1);
  await wait(5);
  check("With it off, progress leaves it under Journal", Bench.settings.autoQuestWatch === false && !tracked().includes(journalQuest));

  // The gear on the title row: a menu, as the quest log's gear has
  fresh("typical");
  const gear = () => one(`${P} .pt-gear`);
  const optionsShown = () => groupTitled("Edit Mode and game options").classList.contains("reveal");
  const unreveal = () => groupTitled("Edit Mode and game options").classList.remove("reveal");
  const gearMenu = () => one(".menu.gear-menu");
  const gearItem = (text) => gearMenu() && [...gearMenu().querySelectorAll(".menu-item")].find((i) => i.textContent === text);
  const SWITCHES = ["Suivi automatique de quête", "Lueur lors d'une progression", "Signaler les quêtes de la zone"];
  check("The title row has a gear", gear() && gear().querySelector(".tex"));
  check("Left of the padlock", gear().getBoundingClientRect().right <= one(`${P} .pt-lock`).getBoundingClientRect().left + 0.5);
  check("Clear of the title", one(`${P} .ot-title-text`).getBoundingClientRect().right <= gear().getBoundingClientRect().left);
  check("Out of combat it's bright: a second copy added on top", one(`${P} .pt-gear .pt-gear-add`) && getComputedStyle(one(`${P} .pt-gear .pt-gear-add`)).mixBlendMode === "plus-lighter");
  click(gear());
  check("Clicking it opens a menu", gearMenu());
  check("Three switches, then Options", SWITCHES.every((t) => gearItem(t) && gearItem(t).classList.contains("check")) && gearItem("Options"));
  check("Then Signaler un bug last, and no Diagnostic: it's on the options page, as in game",
    [...gearMenu().querySelectorAll(".menu-item")].map((i) => i.textContent).slice(-2).join("|") === "Options|Signaler un bug"
    && !gearItem("Diagnostic"));
  const autoBefore = Bench.settings.autoQuestWatch;
  gearItem(SWITCHES[0]).click();
  check("A switch changes its option, and the menu stays open", Bench.settings.autoQuestWatch === !autoBefore && gearMenu());
  check("Showing the new state", gearItem(SWITCHES[0]).querySelector(".menu-box").classList.contains("on") === Bench.settings.autoQuestWatch);
  check("The panel's checkbox follows", groupTitled("Edit Mode and game options").querySelector("[data-setting='autoQuestWatch']").checked === Bench.settings.autoQuestWatch);
  gearItem(SWITCHES[0]).click();
  unreveal();
  gearItem("Options").click();
  check("Options opens the addon's page: on the bench, Edit Mode and game options", optionsShown() && !gearMenu());
  click(one(`${P} .pt-lock`));
  click(gear());
  check("It works while locked", gearMenu() && PT.state.locked);
  UI.closeMenus();
  click(one(`${P} .pt-lock`));
  Game.setCombat(true);
  click(gear());
  check("In combat it's refused with the game's message", !gearMenu() && one("#stage-prop .uierror"));
  check("And greyed, without the bright copy", gear().classList.contains("disabled") && !one(`${P} .pt-gear .pt-gear-add`) && getComputedStyle(gear()).filter.includes("grayscale"));
  Game.setCombat(false);
  check("Bright again after combat", one(`${P} .pt-gear .pt-gear-add`) && !gear().classList.contains("disabled"));
  unreveal();

  // Key bindings, each doing what its click does
  fresh("typical");
  const bindingButton = (text) => [...groupTitled("Key bindings (unbound by default)").querySelectorAll("button")].find((b) => b.textContent === text);
  check("The panel has the four key bindings", ["Lock or unlock", "Collapse or expand all", "Previous group", "Next group"].every(bindingButton));
  bindingButton("Next group").click();
  check("Next group opens the one after the open one, and closes the rest", PT.state.open.groups[2] && !PT.state.open.groups[1] && !PT.state.open.headers["Marche de l'Ouest"]);
  bindingButton("Next group").click();
  check("Then wraps round to the first", PT.state.open.groups[1] && !PT.state.open.groups[2]);
  bindingButton("Previous group").click();
  check("Previous wraps back to the last", PT.state.open.groups[2] && !PT.state.open.groups[1]);
  PT.state.open.categories.mine = false;
  PT.state.open.tracker = false;
  PT.render();
  bindingButton("Next group").click();
  check("It opens the tracker and Suivi if they're closed", PT.state.open.tracker && PT.state.open.categories.mine && rowOf(60));
  bindingButton("Lock or unlock").click();
  check("Lock or unlock locks", PT.state.locked && one(`${P} .pt-lock.shut`));
  const openLocked = JSON.stringify(PT.state.open);
  bindingButton("Next group").click();
  bindingButton("Collapse or expand all").click();
  check("Locked, the others change nothing", JSON.stringify(PT.state.open) === openLocked);
  bindingButton("Lock or unlock").click();
  bindingButton("Collapse or expand all").click();
  check("Collapse or expand all collapses", !PT.state.open.tracker && !rows().length);
  bindingButton("Collapse or expand all").click();
  check("And expands", PT.state.open.tracker && rows().length);

  // The title's buttons stay quiet until the pointer is over the tracker
  fresh("typical");
  const toolsOpacity = () => Number(getComputedStyle(one(`${P} .pt-tools`)).opacity);
  one(P).dispatchEvent(new MouseEvent("mouseleave"));
  check("At rest the title's buttons are at half", Math.abs(toolsOpacity() - 0.5) < 0.01, toolsOpacity());
  one(P).dispatchEvent(new MouseEvent("mouseenter"));
  check("Over the tracker they come up", toolsOpacity() === 1, toolsOpacity());
  one(P).dispatchEvent(new MouseEvent("mouseleave"));
  PT.state.layer.dispatchEvent(new MouseEvent("mouseenter"));
  check("Over an item button too", toolsOpacity() === 1, toolsOpacity());
  PT.state.layer.dispatchEvent(new MouseEvent("mouseleave"));
  check("And go quiet again when it leaves", Math.abs(toolsOpacity() - 0.5) < 0.01, toolsOpacity());

  // A quest placed past the game's 25 says so
  fresh("over25");
  const offList = tracked().filter((id) => !Game.watch.includes(id));
  const onList = tracked().filter((id) => Game.watch.includes(id));
  const atlasOf = (name) => UI.atlasCss(name, Bench.tokens.markerSize, Bench.tokens.markerSize);
  const pinCss = () => atlasOf("waypoint-mappin-minimap-untracked");
  const firstMarker = (id) => rowOf(id) && rowOf(id).querySelector(".mk");
  check("Over 25 tracked: two quests are in a group but off the game's list", offList.length === 2 && Game.watch.length === 25, offList.join());
  check("Each shows the untracked map pin first", offList.every((id) => firstMarker(id) && firstMarker(id).getAttribute("style") === pinCss()));
  check("Quests on the list don't", onList.every((id) => !rowOf(id) || !firstMarker(id) || firstMarker(id).getAttribute("style") !== pinCss()));
  rowOf(offList[0]).dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));
  check("Its tooltip says why", one("#stage-prop .gt") && one("#stage-prop .gt").textContent.includes("Au-delà des 25 quêtes suivies par le jeu"));
  UI.hideTooltip();
  Bench.settings.markerStyle = "text";
  Bench.renderAll();
  check("As text, it reads (Hors liste)", rowOf(offList[0]).textContent.includes("(Hors liste)"));
  Bench.settings.markerStyle = "icons";
  Bench.renderAll();

  // Suivi tucks under the title
  fresh("typical");
  const units = (px) => px / UI.scaleOf(one(P));
  const suiviGap = () => units(bar("mine").getBoundingClientRect().top - one(`${P} .ot-title`).getBoundingClientRect().bottom);
  const blizzGap = units(one(`${B} .ot-bar`).getBoundingClientRect().top - one(`${B} .ot-title`).getBoundingClientRect().bottom);
  check("Blizzard's first bar is 6 under its title", Math.abs(blizzGap - 6) < 0.5, blizzGap);
  check("Suivi starts 4 into the title's height, 10 closer than Blizzard's", Math.abs(suiviGap() + 4) < 0.5, suiviGap());
  const lockBox = one(`${P} .pt-lock`).getBoundingClientRect();
  const atLockBottom = document.elementFromPoint(lockBox.left + lockBox.width / 2, lockBox.bottom - 1);
  check("The title's buttons stay on top of it", atLockBottom && atLockBottom.closest(".pt-lock"), atLockBottom && atLockBottom.className);
  click(one(`${P} [data-action="search"]`));
  const searchBox = one(`${P} .pt-search`).getBoundingClientRect();
  check("With the search box open, it drops below the title", searchBox.top >= one(`${P} .ot-title`).getBoundingClientRect().bottom - 0.5, units(searchBox.top - one(`${P} .ot-title`).getBoundingClientRect().bottom));
  check("And Suivi below the search box", bar("mine").getBoundingClientRect().top >= searchBox.bottom - 0.5);
  click(one(`${P} [data-action="search"]`));
  check("Closing it tucks Suivi back", Math.abs(suiviGap() + 4) < 0.5, suiviGap());
  fresh("open");
  Bench.settings.height = 400;
  Bench.renderAll();
  one(`${P} .pt-scroll`).scrollTop = 300;
  PT.render();
  const clipTop = () => {
    const inset = parseFloat((getComputedStyle(one(`${P} .pt-scroll`)).clipPath.match(/inset\(([\d.]+)px/) || [])[1] || 0);
    return one(`${P} .pt-scroll`).getBoundingClientRect().top + inset * UI.scaleOf(one(P));
  };
  check("Scrolled rows stop at the title's lower edge", Math.abs(clipTop() - one(`${P} .ot-title`).getBoundingClientRect().bottom) < 0.5, units(clipTop() - one(`${P} .ot-title`).getBoundingClientRect().bottom));
  check("And so does the scrollbar", one(`${P} .pt-sb`).getBoundingClientRect().top >= one(`${P} .ot-title`).getBoundingClientRect().bottom - 0.5);
  Bench.settings.height = 1000;
  Bench.renderAll();

  // Finish
  check("No script errors", errors.length === 0, errors.join(" | "));

  const failed = results.filter((r) => !r.ok);
  const lines = results.map((r) => `${r.ok ? "PASS" : "FAIL"}  ${r.name}${r.ok || r.info === undefined ? "" : "   -> " + r.info}`);
  const out = document.createElement("pre");
  out.id = "selftest-out";
  out.textContent = `RESULT ${results.length - failed.length}/${results.length}\n` + lines.join("\n");
  out.style.cssText = "position:fixed;inset:20px;overflow:auto;background:#000;color:#ddd;z-index:9999;padding:12px;font:12px Consolas,monospace";
  document.body.append(out);
  document.title = `${failed.length ? "FAIL" : "PASS"} ${results.length - failed.length}/${results.length}`;
})();
