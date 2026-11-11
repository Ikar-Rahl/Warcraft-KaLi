// A simulated game: one quest log, the combat state, and the events both trackers react to.
// Timings copy Blizzard_ObjectiveTrackerAnimTemplates.xml and the line states in its .lua.
window.Game = (function () {
  const GLOW = 760;        // GlowAnim: 0.1 delay + 0.66 scale
  const FADE_OUT = 1100;   // FadeOutAnim: 1 delay + 0.1
  const ADD = 620;         // AddAnim plus the line fade-in
  const TURN_IN = 660;     // TurnInAnim: 0.33 delay + 0.33 fade

  const G = {
    inCombat: false,
    partySize: 1,
    zone: "Marche de l'Ouest",
    superTracked: 0,
    quests: new Map(),
    order: [],             // log order
    watch: [],             // the game's tracked list. The proposal keeps it the same as what's in the player's groups
    popups: [],            // { questID, type }
    timers: [],            // { questID, ends, total }
    insideArea: new Set(),
    pool: [],
    listeners: new Set(),
    logListeners: new Set(),
  };

  const clone = (o) => JSON.parse(JSON.stringify(o));

  function makeQuest(raw) {
    const q = clone(raw);
    q.party = q.party || 0;
    q.objectives.forEach((o, i) => {
      if (o.kind !== "event") o.done = o.have >= o.need;
      o.key = i;
      o.state = o.done ? "completed" : "present";
    });
    q.complete = !!q.complete || (q.objectives.length > 0 && q.objectives.every((o) => o.done));
    q.completionShown = q.complete;
    if (q.complete) q.objectives.forEach((o) => { o.state = "faded"; });
    if (q.item) { q.item.rangeState = q.item.range ? 1 : null; q.item.cdEnds = 0; q.item.glow = 0; }
    return q;
  }

  function reset() {
    G.quests.clear();
    G.order = [];
    G.watch = [];
    G.popups = [];
    G.timers = [];
    G.insideArea.clear();
    G.inCombat = false;
    G.partySize = 1;
    G.zone = "Marche de l'Ouest";
    G.superTracked = 0;
    G.speaking = 0;
    G.pool = clone(window.FakeLog.POOL);
    window.FakeLog.QUESTS.forEach((raw) => {
      const q = makeQuest(raw);
      G.quests.set(q.id, q);
      G.order.push(q.id);
      if (raw.tracked) G.watch.push(q.id);
    });
    changed("RESET");
  }

  function changed(event, detail) {
    G.listeners.forEach((fn) => fn(event, detail));
  }

  function log(kind, text) {
    G.logListeners.forEach((fn) => fn(kind, text));
  }

  function emit(event, detail) {
    log("event", detail === undefined ? event : `${event} ${detail}`);
    changed(event, detail);
  }

  const later = (ms, fn) => setTimeout(fn, ms);

  function setObjectiveState(q, o, state) {
    o.state = state;
    if (state === "completing") {
      later(GLOW, () => {
        if (!G.quests.has(q.id) || o.state !== "completing") return;
        if (q.sequenced && !q.complete) {
          setObjectiveState(q, o, "fading");
        } else {
          o.state = "completed";
          settle(q);
        }
        emit("QUEST_LOG_UPDATE");
      });
    } else if (state === "fading") {
      later(FADE_OUT, () => {
        if (!G.quests.has(q.id) || o.state !== "fading") return;
        o.state = "faded";
        settle(q);
        emit("QUEST_LOG_UPDATE");
      });
    } else if (state === "adding") {
      later(GLOW, () => {
        if (o.state === "adding") { o.state = "present"; changed("QUEST_LOG_UPDATE"); }
      });
    }
  }

  // Runs when an objective's animation ends, as DoQuestObjectives does on its next pass.
  function settle(q) {
    if (q.complete) {
      if (q.objectives.some((o) => o.state === "completing" || o.state === "fading")) return;
      const finished = q.objectives.filter((o) => o.state === "completed");
      if (finished.length) {
        finished.forEach((o) => setObjectiveState(q, o, "fading"));
        return;
      }
      if (!q.completionShown) {
        q.completionShown = true;
        if (q.isAutoComplete) addPopup(q.id, "COMPLETE");
      }
      return;
    }
    if (q.sequenced) {
      const next = q.objectives.find((o) => !o.done && o.state === "hidden");
      if (next && !q.objectives.some((o) => o.state === "completing" || o.state === "fading")) {
        setObjectiveState(q, next, "adding");
        log("sound", "UI_QUEST_ROLLING_FORWARD_01");
      }
    }
  }

  function checkComplete(q) {
    if (q.complete || !q.objectives.length) return;
    if (q.objectives.every((o) => o.done)) {
      q.complete = true;
      q.objectives.forEach((o) => {
        if (o.state === "present" || o.state === "adding") {
          o.done = true;
          setObjectiveState(q, o, "completing");
        }
      });
      settle(q);
    }
  }

  function progress(id, amount) {
    const q = G.quests.get(id);
    if (!q || q.complete || q.failed) return;
    const o = q.objectives.find((x) => !x.done && x.state !== "hidden");
    if (!o) return;
    if (o.kind === "event") {
      o.done = true;
    } else {
      o.have = Math.min(o.need, o.have + (amount || 1));
      o.done = o.have >= o.need;
    }
    if (o.done) setObjectiveState(q, o, "completing");
    checkComplete(q);
    changed("OBJECTIVE_PROGRESS", id);
    // QuestMapFrame.lua tracks a quest whose objective moved, when autoQuestWatch is on.
    emit("QUEST_WATCH_UPDATE", id);
    if (window.Bench.settings.autoQuestWatch) toggleWatch(id, true);
    emit("QUEST_LOG_UPDATE", `${q.title}`);
  }

  function completeObjective(id) {
    const q = G.quests.get(id);
    if (!q) return;
    const o = q.objectives.find((x) => !x.done && x.state !== "hidden");
    if (o && o.kind !== "event") return progress(id, o.need);
    progress(id);
  }

  function completeQuest(id) {
    const q = G.quests.get(id);
    if (!q || q.complete) return;
    q.failed = false;
    q.objectives.forEach((o) => {
      if (o.state === "hidden") o.state = "present";
      if (o.kind !== "event") o.have = o.need;
      o.done = true;
      if (o.state === "present" || o.state === "adding") setObjectiveState(q, o, "completing");
    });
    q.complete = true;
    if (!q.objectives.length) q.completionShown = true;
    settle(q);
    changed("OBJECTIVE_PROGRESS", id);
    emit("QUEST_LOG_UPDATE", `${q.title} terminée`);
  }

  function undoObjective(id) {
    const q = G.quests.get(id);
    if (!q) return;
    const o = [...q.objectives].reverse().find((x) => x.done);
    if (!o) return;
    q.complete = false;
    q.completionShown = false;
    o.done = false;
    if (o.kind !== "event") o.have = Math.max(0, o.need - 1);
    o.state = "present";
    q.objectives.forEach((x) => { if (x.state === "faded") x.state = x.done ? "completed" : "present"; });
    emit("QUEST_LOG_UPDATE", `${q.title}: objectif annulé`);
  }

  function setFailed(id, failed) {
    const q = G.quests.get(id);
    if (!q) return;
    q.failed = failed;
    emit("QUEST_LOG_UPDATE", `${q.title}: ${failed ? "échec" : "reprise"}`);
  }

  function setSequenced(id, on) {
    const q = G.quests.get(id);
    if (!q) return;
    q.sequenced = on;
    let first = true;
    q.objectives.forEach((o) => {
      if (o.done) { o.state = on ? "faded" : "completed"; return; }
      o.state = on ? (first ? "present" : "hidden") : "present";
      first = false;
    });
    emit("QUEST_LOG_UPDATE", `${q.title}: par étapes ${on ? "oui" : "non"}`);
  }

  function turnIn(id) {
    const q = G.quests.get(id);
    if (!q) return;
    q.anim = "turnin";
    removePopup(id);
    emit("QUEST_TURNED_IN", q.title);
    later(TURN_IN, () => removeQuest(id));
  }

  function abandon(id) {
    const q = G.quests.get(id);
    if (!q) return;
    emit("QUEST_REMOVED", q.title);
    removeQuest(id);
  }

  function removeQuest(id) {
    G.quests.delete(id);
    G.order = G.order.filter((x) => x !== id);
    G.watch = G.watch.filter((x) => x !== id);
    G.timers = G.timers.filter((t) => t.questID !== id);
    G.insideArea.delete(id);
    if (G.superTracked === id) G.superTracked = 0;
    changed("QUEST_LOG_UPDATE");
  }

  function accept() {
    const raw = G.pool.shift();
    if (!raw) return log("note", "No more quests in the fake pool");
    const q = makeQuest(raw);
    q.anim = "add";
    G.quests.set(q.id, q);
    G.order.push(q.id);
    emit("QUEST_ACCEPTED", q.title);
    // Blizzard's own QUEST_ACCEPTED handler does this when autoQuestWatch is on.
    if (window.Bench.settings.autoQuestWatch) toggleWatch(q.id, true);
    later(ADD, () => { q.anim = null; changed("QUEST_LOG_UPDATE"); });
    return q;
  }

  // The game fires its event only for a real change, and refuses a 26th quest. MAX_QUEST_WATCHES is 25.
  function toggleWatch(id, on) {
    const has = G.watch.includes(id);
    const want = on === undefined ? !has : on;
    if (want === has) return;
    if (want && G.watch.length >= 25) return log("note", "The game's tracked list is full, at 25");
    G.watch = want ? [...G.watch, id] : G.watch.filter((x) => x !== id);
    emit("QUEST_WATCH_LIST_CHANGED", `${id} ${want}`);
  }

  // Only the bench's own resets use this. The real list is kept between sessions, and the addon reconciles with it at login.
  function setWatch(ids) {
    G.watch = ids.filter((id) => G.quests.has(id)).slice(0, 25);
    changed("WATCH_SET");
  }

  function superTrack(id) {
    G.superTracked = G.superTracked === id ? 0 : id;
    log("sound", G.superTracked ? "UI_MAP_WAYPOINT_SUPER_TRACK_ON" : "UI_MAP_WAYPOINT_SUPER_TRACK_OFF");
    emit("SUPER_TRACKING_CHANGED", String(G.superTracked));
  }

  function setCombat(on) {
    if (G.inCombat === on) return;
    G.inCombat = on;
    emit(on ? "PLAYER_REGEN_DISABLED" : "PLAYER_REGEN_ENABLED");
  }

  function setParty(size) {
    G.partySize = size;
    G.quests.forEach((q) => { q.party = Math.min(q.party, size - 1); });
    emit("GROUP_ROSTER_UPDATE", String(size));
  }

  function setZone(zone) {
    G.zone = zone;
    emit("ZONE_CHANGED_NEW_AREA", zone);
  }

  function setPartyOnQuest(id, count) {
    const q = G.quests.get(id);
    if (!q) return;
    q.party = Math.max(0, Math.min(count, G.partySize - 1));
    emit("UNIT_QUEST_LOG_CHANGED", `${q.title}: ${q.party}`);
  }

  // Spoken's Play button. Only the button's state and the log matter here.
  function speak(id) {
    G.speaking = G.speaking === id ? 0 : id;
    log("call", G.speaking ? `Spoken: play ${id}` : `Spoken: stop ${id}`);
    changed();
  }

  function share(id) {
    const q = G.quests.get(id);
    if (!q) return;
    q.party = Math.min(q.party + 1, G.partySize - 1);
    log("call", `QuestLogPushQuest(${id})`);
    emit("UNIT_QUEST_LOG_CHANGED", `${q.title}: partagée`);
  }

  // Quest item triggers
  function enterArea(id, inside) {
    const q = G.quests.get(id);
    if (!q) return;
    if (inside) G.insideArea.add(id); else G.insideArea.delete(id);
    if (q.item && inside) {
      q.item.glow = (q.item.glow || 0) + 1;   // a new number restarts the 6 pulses
    }
    emit("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED", `${q.title} ${inside}`);
  }

  function setRange(id, state) {
    const q = G.quests.get(id);
    if (!q || !q.item) return;
    q.item.rangeState = state;
    emit("PLAYER_TARGET_CHANGED", `${q.title}: ${state === null ? "pas de portée" : state ? "à portée" : "hors de portée"}`);
  }

  function useItem(id, fromAddonButton) {
    const q = G.quests.get(id);
    if (!q || !q.item) return;
    if (q.item.cdEnds > Date.now()) return log("note", "Item on cooldown");
    log("call", fromAddonButton ? `Secure button, type=item (${q.item.name})` : `UseQuestLogSpecialItem(${q.id})`);
    if (q.item.cooldown) startCooldown(id, q.item.cooldown);
    if (q.item.charges) q.item.charges -= 1;
    emit("BAG_UPDATE_COOLDOWN");
  }

  function startCooldown(id, seconds) {
    const q = G.quests.get(id);
    if (!q || !q.item) return;
    q.item.cdEnds = Date.now() + seconds * 1000;
    q.item.cdTotal = seconds;
    emit("BAG_UPDATE_COOLDOWN");
    later(seconds * 1000 + 20, () => changed("BAG_UPDATE_COOLDOWN"));
  }

  // Popups
  function addPopup(id, type) {
    if (G.popups.some((p) => p.questID === id)) return;
    G.popups.push({ questID: id, type, at: Date.now() });
    log("sound", "UI_AUTO_QUEST_COMPLETE");
    emit("QUEST_AUTOCOMPLETE", String(id));
  }

  function removePopup(id) {
    G.popups = G.popups.filter((p) => p.questID !== id);
    changed("QUEST_LOG_UPDATE");
  }

  // Timers
  function startTimer(id, seconds) {
    const q = G.quests.get(id);
    if (!q) return;
    G.timers = G.timers.filter((t) => t.questID !== id);
    G.timers.push({ questID: id, ends: Date.now() + seconds * 1000, total: seconds });
    emit("QUEST_TIMER_UPDATE", q.title);
  }

  function clearTimers() {
    G.timers = [];
    emit("QUEST_TIMER_UPDATE");
  }

  setInterval(() => {
    const now = Date.now();
    const expired = G.timers.filter((t) => t.ends <= now);
    if (expired.length) {
      G.timers = G.timers.filter((t) => t.ends > now);
      expired.forEach((t) => setFailed(t.questID, true));
    }
  }, 500);

  // Which quests the rules apply to
  function isShareable(q) {
    return G.partySize > 1 && q.pushable && q.party < G.partySize - 1;
  }

  // Blizzard's order of what shows under a quest's title.
  function linesFor(q) {
    const lines = [];
    const waypoint = q.id === G.superTracked && q.waypoint;
    if (q.complete) {
      q.objectives.forEach((o) => {
        if (o.state === "completing" || o.state === "completed" || o.state === "fading") {
          lines.push({ key: "o" + o.key, text: window.FakeLog.objectiveText(o), state: o.state, style: "complete", dash: false });
        }
      });
      const animating = q.objectives.some((o) => o.state === "completing");
      if (!animating && q.objectives.every((o) => o.state === "faded" || !o.state) && (q.completionShown || !q.objectives.length)) {
        if (q.isAutoComplete) {
          lines.push({ key: "qc", text: "Quête terminée", style: "normal", dash: true });
          lines.push({ key: "cc", text: "(cliquer pour terminer)", style: "normal", dash: true });
        } else if (q.completionText) {
          if (waypoint) lines.push({ key: "wp", text: `Facultatif : ${q.waypoint}`, style: "normal", dash: true });
          lines.push({ key: "qc", text: q.completionText, style: "normal", dash: false });
        } else if (q.waypoint) {
          lines.push({ key: "wp", text: q.waypoint, style: "normal", dash: true });
        } else {
          lines.push({ key: "qc", text: "À rendre", style: "complete", dash: false });
        }
      }
      return lines;
    }
    if (q.failed) {
      lines.push({ key: "failed", text: "Echec", style: "failed", dash: false });
      return lines;
    }
    if (waypoint) lines.push({ key: "wp", text: `Facultatif : ${q.waypoint}`, style: "normal", dash: true });
    q.objectives.forEach((o) => {
      if (o.state === "hidden" || o.state === "faded") return;
      const finished = o.done && (o.state === "completed" || o.state === "completing" || o.state === "fading");
      lines.push({ key: "o" + o.key, text: window.FakeLog.objectiveText(o), state: o.state,
        style: finished ? "complete" : "normal", dash: !finished });
    });
    return lines;
  }

  function difficulty(q) {
    const diff = q.level - window.FakeLog.PLAYER.level;
    if (diff >= 5) return "impossible";
    if (diff >= 3) return "verydifficult";
    if (diff >= -2) return "difficult";
    if (diff >= -(5 + Math.floor(window.FakeLog.PLAYER.level / 10))) return "standard";
    return "trivial";
  }

  return Object.assign(G, {
    reset, changed, emit, log, progress, completeObjective, completeQuest, undoObjective, setFailed, setSequenced,
    turnIn, abandon, accept, toggleWatch, setWatch, superTrack, setCombat, setParty, setZone, setPartyOnQuest, share, speak,
    enterArea, setRange, useItem, startCooldown, addPopup, removePopup, startTimer, clearTimers,
    isShareable, linesFor, difficulty,
    onChange: (fn) => G.listeners.add(fn),
    onLog: (fn) => G.logListeners.add(fn),
  });
})();
