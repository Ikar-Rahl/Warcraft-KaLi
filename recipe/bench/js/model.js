// What the addon would know, derived from js/data.js: who knows what, what was seen where, the counts.
// Everything is keyed by number, as the addon would store it; names come from the data (the client's French).
(function () {
  const D = window.BENCH_DATA;
  const str = String;

  const chars = {
    main: { id: "main", name: D.character.name, level: D.character.level, profs: D.character.profs, known: new Set(D.character.known.map(str)) },
    alt: { id: "alt", name: D.alt.name, level: D.alt.level, profs: D.alt.profs, known: new Set(D.alt.known.map(str)), invented: true },
  };

  const M = {
    D, chars,
    recipe: (id) => D.recipes[str(id)],
    item: (id) => D.items[str(id)],
    // "showcase" is the bench's invented vendor, one slot per marker case.
    npc: (id) => (id === "showcase" ? { name: "Vitrine du banc", title: "Tous les cas de marques" } : D.npcs[str(id)]),
    prof: (skill) => D.professions[str(skill)],
    zone: (z) => D.zones[str(z)] || (D.maps[str(z)] || {}).name || "",
    atlas: (name) => D.atlases[name.toLowerCase()],
    iconUrl: (fdid) => (fdid ? `art/icons/${fdid}.png` : ""),
  };

  // Recipe IDs seen anywhere, and each recipe's sightings (the addon's account-wide memory).
  const sightingsBy = new Map();
  for (const s of D.sightings) {
    const k = str(s.recipe);
    if (!sightingsBy.has(k)) sightingsBy.set(k, []);
    sightingsBy.get(k).push(s);
  }
  M.sightingsOf = (spell) => sightingsBy.get(str(spell)) || [];
  M.allSeen = () => [...sightingsBy.keys()];

  M.knowers = (spell) => Object.values(chars).filter((c) => c.known.has(str(spell)));
  M.isKnown = (spell, charId) => chars[charId].known.has(str(spell));
  M.knownByAny = (spell) => M.knowers(spell).length > 0;
  M.hasProf = (charId, skill) => str(skill) in chars[charId].profs;
  M.rankOf = (charId, skill) => chars[charId].profs[str(skill)] || 0;
  // A recipe's category in the professions window (TradeSkillCategory), with the game's order. Recipes outside
  // the profession's own tree go under the game's « Divers » (MISCELLANEOUS), last.
  const MISC = { id: 0, name: "Divers", order: 1e6 };
  M.category = (spell) => { const id = M.recipe(spell).cat; return id && D.categories[str(id)] ? { id, ...D.categories[str(id)] } : MISC; };
  // Recipes grouped by category, categories in the game's order, recipes by required rank then name.
  M.byCategory = (spells) => {
    const groups = new Map();
    for (const sp of spells) {
      const c = M.category(sp);
      if (!groups.has(c.id)) groups.set(c.id, { ...c, spells: [] });
      groups.get(c.id).spells.push(sp);
    }
    const out = [...groups.values()].sort((a, b) => a.order - b.order || a.name.localeCompare(b.name, "fr"));
    for (const g of out) g.spells.sort((a, b) => M.recipe(a).min - M.recipe(b).min || M.recipe(a).name.localeCompare(M.recipe(b).name, "fr"));
    return out;
  };
  // A character's professions as the game lists them: main professions first, then the secondary ones.
  const SECONDARY = ["185", "129", "356"];
  M.profsOf = (charId) => Object.keys(chars[charId].profs).sort((a, b) => SECONDARY.indexOf(a) - SECONDARY.indexOf(b) || a - b);

  // "Unknown" = seen somewhere and not known by this character. Nothing else exists for the addon.
  M.unknownSeen = (charId) => {
    const by = {};
    for (const spell of M.allSeen()) {
      if (M.isKnown(spell, charId)) continue;
      const r = M.recipe(spell);
      (by[r.skill] = by[r.skill] || []).push(spell);
    }
    for (const k in by) by[k].sort((a, b) => M.recipe(a).min - M.recipe(b).min || M.recipe(a).name.localeCompare(M.recipe(b).name, "fr"));
    return by;
  };
  M.countFor = (charId, skill) => (M.unknownSeen(charId)[str(skill)] || []).length;
  M.countOther = (charId) => {
    const by = M.unknownSeen(charId);
    return Object.keys(by).filter((k) => !M.hasProf(charId, k)).reduce((n, k) => n + by[k].length, 0);
  };
  // A profession's two counts (Ikar, 2026-11-09): learnable now, and seen but not learnable yet (rank too low, or a
  // profession this character doesn't have).
  M.split = (charId, skill) => {
    const all = M.unknownSeen(charId)[str(skill)] || [];
    const learn = all.filter((sp) => M.state(sp, charId) === "learnable");
    return { learn, seen: all.filter((sp) => !learn.includes(sp)) };
  };
  // What makes an item: recipes known by a character or seen somewhere (never one the account hasn't met).
  M.madeBy = (itemId) => Object.keys(D.recipes).filter((sp) => D.recipes[sp].makes === Number(itemId))
    .map((sp) => ({ spell: sp, who: M.knowers(sp), seen: sightingsBy.has(sp) })).filter((x) => x.who.length || x.seen);
  M.countAll = (charId) => Object.values(M.unknownSeen(charId)).reduce((n, a) => n + a.length, 0);

  // Difficulty colour of a recipe for a rank, as the professions window colours it.
  // A known recipe is never red: the bench's required ranks for trainer recipes are estimates.
  M.difficulty = (spell, rank, known) => {
    const r = M.recipe(spell);
    if (!known && rank < r.min) return "red";
    if (rank < r.yellow) return "d-optimal";
    if (rank < Math.round((r.yellow + r.gray) / 2)) return "d-medium";
    if (rank < r.gray) return "d-easy";
    return "d-trivial";
  };

  // "Used in" for a material: recipes a character knows, then recipes seen that nobody knows. Never anything else.
  M.usedIn = (itemId) => {
    const known = [], seen = [];
    const id = Number(itemId);
    for (const [spell, r] of Object.entries(D.recipes)) {
      if (!r.reagents.some(([i]) => i === id)) continue;
      const who = M.knowers(spell);
      if (who.length) known.push({ spell, who });
      else if (sightingsBy.has(spell)) seen.push({ spell });
    }
    const byName = (a, b) => M.recipe(a.spell).name.localeCompare(M.recipe(b.spell).name, "fr");
    return { known: known.sort(byName), seen: seen.sort(byName) };
  };

  // A vendor's shelf: the recipes seen there, plus supplies a vendor of that trade would stock (invented filler).
  const FILLER = [
    [/cuisinier|Commerçant|recettes de cuisine/i, ["Epices douces"]],
    [/tailleur|artisanat|générales/i, ["Bobine de fil grossier", "Bobine de fil raffiné", "Teinture rouge", "Teinture bleue"]],
    [/enchanteur/i, ["Fiole vide"]],
    [/alchimie/i, ["Fiole vide"]],
  ];
  M.vendors = () => {
    const out = new Map([["showcase", { kind: "vendor", npc: "showcase", zone: 1657 }]]);
    for (const s of D.sightings) if (s.kind === "vendor" && !out.has(s.npc)) out.set(s.npc, s);
    return [...out.values()];
  };
  M.shelf = (npcId) => {
    if (npcId === "showcase") return D.showcase.map((e) => ({ item: e.item, recipe: e.recipe, case: e.case }));
    const recipes = D.sightings.filter((s) => s.kind === "vendor" && s.npc === npcId).map((s) => ({ item: s.item, recipe: s.recipe }));
    const title = (M.npc(npcId) || {}).title || "";
    const names = (FILLER.find(([re]) => re.test(title)) || [null, []])[1];
    const fill = Object.entries(D.items).filter(([, it]) => names.includes(it.name)).map(([id]) => ({ item: Number(id) }));
    return [...fill, ...recipes];
  };
  M.trainers = () => {
    const out = new Map();
    for (const s of D.sightings) if (s.kind === "trainer" && !out.has(s.npc)) out.set(s.npc, s);
    return [...out.values()];
  };
  M.trainerList = (npcId) => D.sightings.filter((s) => s.kind === "trainer" && s.npc === npcId).map((s) => s.recipe);
  M.trainerSkill = (npcId) => M.recipe(M.trainerList(npcId)[0]).skill;

  // Inventories (bags and bank) of every character: the addon would record them at BAG_UPDATE and at the bank.
  M.holds = (charId, itemId) => {
    const h = (D.holdings || {})[charId] || {};
    const bags = (h.bags || {})[str(itemId)] || 0, bank = (h.bank || {})[str(itemId)] || 0;
    return { bags, bank, total: bags + bank };
  };
  M.holders = (itemId) => Object.values(chars).map((c) => ({ c, h: M.holds(c.id, itemId) })).filter((x) => x.h.total > 0);

  // No auction prices are kept: Auctionator and the like add theirs to any item tooltip the addon shows.
  // Vendors where a recipe was seen: the auction house's eye says it can be bought there instead.
  M.vendorSightings = (spell) => M.sightingsOf(spell).filter((s) => s.kind === "vendor");

  // Where a recipe stands for a character: known, learnable now, rank too low, or another profession.
  M.state = (spell, charId) => {
    const r = M.recipe(spell);
    if (M.isKnown(spell, charId)) return "known";
    if (!M.hasProf(charId, r.skill)) return "other";
    return M.rankOf(charId, r.skill) >= r.min ? "learnable" : "toolow";
  };
  // Possession of a recipe's item: this character's (bags or bank, it doesn't matter which), and other characters'.
  // Both can be true at once.
  M.possession = (spell, charId) => {
    const it = M.recipe(spell).item;
    if (!it) return null;
    const mine = M.holds(charId, it).total ? M.holds(charId, it) : null;
    const alts = M.holders(it).filter((x) => x.c.id !== charId);
    return mine || alts.length ? { mine, alts } : null;
  };

  // The game's own filters, as Forever's professions window offers them, plus the notebook's.
  M.skillUp = (spell, charId) => M.hasProf(charId, M.recipe(spell).skill) && M.rankOf(charId, M.recipe(spell).skill) < M.recipe(spell).gray;
  M.makeable = (spell, charId) => M.recipe(spell).reagents.every(([i, n]) => M.holds(charId, i).total >= n);
  M.slotOf = (spell) => { const out = M.recipe(spell).makes; return out ? (M.item(out) || {}).slot || 0 : 0; };
  M.sourcesOf = (spell) => new Set(M.sightingsOf(spell).map((s) => s.kind));
  M.SLOTS = { 4: "Chemise", 5: "Torse", 6: "Taille", 7: "Jambes", 8: "Pieds", 10: "Mains", 12: "Bijou", 16: "Dos", 18: "Sac", 20: "Torse", 26: "À distance" };
  M.SOURCES = { vendor: "Marchands", trainer: "Entraîneurs", ah: "Hôtel des ventes", drop: "Butin" };

  // Money as the game writes it: gold, silver, copper with coin icons.
  M.money = (copper) => {
    const g = Math.floor(copper / 10000), s = Math.floor((copper % 10000) / 100), c = copper % 100;
    const parts = [];
    if (g) parts.push(`${g}<span class="coin g"></span>`);
    if (s || (g && c)) parts.push(`${s}<span class="coin s"></span>`);
    if (c || !parts.length) parts.push(`${c}<span class="coin c"></span>`);
    return parts.join("");
  };
  M.date = (iso) => {
    const d = new Date(iso + "T12:00:00");
    return d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
  };
  M.plural = (n, one, many) => (n === 1 ? one : many).replace("{n}", n);

  window.M = M;
})();
