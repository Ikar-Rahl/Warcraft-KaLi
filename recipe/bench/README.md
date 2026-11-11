# Recipe notebook: exploration bench

The recipe notebook addon's display, in every place it shows itself, before any Lua is written. It first explored every option; since Ikar's picks of 2026-11-09 ([design.md](../docs/design.md), "Decided") it shows the chosen design, and its switches are what the in-game options would offer, plus the few points still open.

**To open it, double-click `index.html`.** It needs no install or server; use Chrome or Edge.

## What it's for

| Use it for | Don't trust it for |
| --- | --- |
| Where the count, marks, tooltip lines and notebook sit, and how they read | Pixel-exact frames: the windows are approximated in CSS |
| Wording, in French, at the game's text sizes | Whether the API calls behind each piece work on Forever: that's the probe's job |
| How many lines a tooltip grows by, with real recipes and reagents | Exact font rendering. The font is the game's, but the browser draws it |

## Controls

- **Scene:** the professions window, the professions book, a vendor, a trainer, the auction house, the bags (hover a material), the world map, the notebook, the add-ons button, and the addon's page in the game's options.
- **Vendor:** the default is the bench's showcase, an invented vendor with one real recipe per marker case (known, known and in the bags, learnable in each difficulty colour, learnable and held by both characters, rank too low, rank too low and on Elorah, another profession on Elorah, another profession held by nobody), with a legend beside it. The other vendors are real.
- **Character:**
  - **Ikar Rahl:** Enchantement 18 and Cuisine 56, with the recipes Ikar's screenshots show.
  - **Elorah:** invented, a tailor and miner (Couture 70, Minage 50) with Secourisme 40 and no first aid recipe seen: the bench's one count at zero. She keeps a cooking recipe in her bags, and a pattern and a cooking recipe in her bank. The last one is also in Ikar's bags: the "held by both" case. Ikar's bags hold three crafted items: one he can make, a copper bar only Elorah can, a fish from a recipe only seen.
- **Chat:** every recipe noted (vendor, trainer, auction house, loot) gets one line per visit in the chat, in the game's SKILL blue.
- **Sounds** (added 2026-11-10): every sound the in-game options offer, to listen to before choosing. ▶ plays one; a click on its name picks it, and « Hear the chosen pair » plays both as a visit would. They're the game's own files, each at its kit's in-game volume, so they compare as they will in game (the game then applies the player's effects volume). Each line gives the sound's length and what the game plays it for.
  - The game has a single writing sound, the quest log's quill (three takes of 2.2 to 3 seconds). Ikar kept it, 2026-11-10, for a new recipe. The shorter ones are the same quill stopped after 0.9 or 0.4 seconds, fading out over 0.2 seconds, as the addon does it in game with `StopSound`. Two parchments, the bags' own sounds for a paper item laid down or picked up, are the other short ones.
  - **New recipe** (« Son d'une nouvelle recette »): when a visit notes a recipe that wasn't in the notebook yet. Ikar's pick: « Plume qui écrit », the whole quill.
  - **New place** (« Son d'un nouvel endroit »): when a visit notes a new place for a recipe already in the notebook. Ikar's pick: « Trait de plume », the 0.4-second stroke.
  - Both settings offer the same five sounds, or « Aucun ». One sound per visit, at least 3 seconds after the last, so the quill ends before another starts; the bigger can follow the smaller when a later auction house page brings a recipe never met.
  The same lists are on the options page scene, under « Annonces ».
- **Markers:**
  - top left, the state: the objective tracker's small check if known, the required rank in its difficulty colour if learnable, in red if the rank is too low. Nothing for another profession;
  - bottom left, the minimap's banker on a small dark disc if this character holds it (bags or bank alike); bottom right, the friend icon if another character does. Both can show;
  - on the auction house, a white eye on recipes this character doesn't know that a vendor seen before also sells.
  - the notebook's « Appris » rows and the trainer's « Déjà connu » rows carry no check: the list already says it.
  - top left of an item a recipe makes: the profession's small icon, bright if this character can make it, dimmed otherwise.
  Each is a switch, as in game.
- **Tooltips:**
  - **A recipe's tooltip:** detailed (the default), one line, or none. Detailed shows who knows it, who holds it and where it was seen. No auction price: the addon shows the recipe's real item tooltip, so Auctionator and the like add their own lines.
  - **« Utilisé dans » on a material:** by profession, as a list, up to 6, 10 or 15 lines. Recipes seen but not known can be included, and where they were seen can be added.
  - **Colour:** the addon's tooltip lines are light blue, the game's own blue for « Composant d'artisanat » (decided).
- **Windows:** the switches for « Carnet : N » in the professions window and the professions book, showing it at zero, and map pins. Each shows in one place only, so switching one takes you there (zero: Elorah's Secourisme).
- **The notebook:** one layout, two styles, switched under Notebook in the panel (an in-game option): Clean (« Épuré », the game window) and Book (« Livre », the profession's quest page). See [design.md](../docs/design.md).
  - **Layout:** the header holds the profession, its rank on the classic skill bar, the two counts (to learn, seen), the hammer (opens the professions window on it) and « Suivre », Forever's arrow button alone (a toggle, one switch for all professions: the notebook opens with the professions window, hangs on its side and follows the profession open there; drag the window's title bar and the notebook moves along). Below: search and filter, the list, and the selected recipe's detail. Profession tabs run down the right edge, the character's own first. Filters: the game's own ("Peut faire progresser", "Comp. disponibles", the categories), plus sources and possession. Width and height: sliders under Notebook in the panel, and in the in-game options.
  - **Rows:** « À apprendre » (learnable now) and « Vues » (rank too low, or not this character's profession) are open; « Appris » is collapsed (the game's own word, `TRADE_SKILLS_LEARNED_TAB`). Inside each, the professions window's own categories, in its order, each collapsible. Each row shows the required rank as a level badge, where it was seen, and who holds it: your banker, another character's friend icon, with where written under them. Each is a notebook option.
  - **Clicks:** a left click shows the recipe's detail below the list: the item it makes, reagents with have/need, every sighting with a waypoint pin, who holds it, who knows it. Click again or × to close. It takes only the height its content needs, up to half the notebook. A right click opens a menu: place a waypoint, link it in chat.
- **In-game options:** a mock of the addon's page in Options › Add-ons. It's live: its switches are the bench's.
- **View:** four of Ikar's world screenshots, or drop your own onto the page.

State is remembered between reloads. A URL hash sets it too, for screenshots, with `hover` and `click` acting on an element after drawing, and `zoom=x,y,scale` showing one point of the stage up close: `index.html#reset=1&scene=notebook&nbSkill=185&inspect=7752`, or `#reset=1&scene=merchant&zoom=40,140,2.2` for the vendor's markers.

## How it stays honest

- **Real:**
  - item, recipe, NPC and zone names, from the client's French tables (`ItemSparse`, `SpellName`, `AreaTable`) and QuestieDB's French NPC names;
  - reagents (`SpellReagents`), yellow and gray thresholds (`SkillLineAbility`), a recipe item's required skill, and what each recipe makes (`SpellEffect`);
  - which vendors sell which recipe, and where each vendor and trainer stands (QuestieDB's Forever data);
  - icons, the Darnassus and Teldrassil map tiles, the fonts (Friz Quadrata, and Morpheus for paper headings), the recipe categories (`TradeSkillCategory`), place names as the world map gives them (`UiMap`), and the game's textures (pins, parchments, spellbook pages, recipe headers);
  - Ikar's known recipes and ranks, from Ikar's screenshots of 2026-11-09.
- **Invented:**
  - which of those recipes Ikar met, and when;
  - the auction house listings and their prices (shown as the game shows them; the addon keeps none);
  - both characters' bags and banks, and the supplies on vendors' shelves;
  - Elorah.
- **Estimated:** a trainer recipe's required skill. This build's `SkillLineAbility` has `MinSkillLineRank` at 1 on most rows, so the bench uses the yellow threshold minus 40. The addon would read the real value from the trainer with `GetTrainerServiceSkillReq`.
- **Approximated:** every window's frame (professions window, vendor, trainer, auction house, map, professions book, compartment, tooltip). Most of Forever's `Profession-*-c60` pieces aren't atlases in this build's tables, so the frames are drawn in CSS from the game's colours and sizes. Judge placement and wording, not pixels.

## Files

| Path | What it is |
| --- | --- |
| `js/data.js` | Generated by `../tools/bench_data.py`: recipes, items, NPCs, sightings, atlases, maps |
| `js/model.js` | What the addon would know: who knows what, what was seen where, the counts, "Utilisé dans" |
| `js/ui.js` | Element builder, atlases, tooltips, the wordings |
| `js/scenes.js` | The ten scenes and the addon's pieces in each |
| `js/notebook.js` | The notebook: one layout, two styles |
| `js/bench.js` | The control panel and state |
| `js/sounds.js` | Generated by `../tools/bench_sounds.py` from the addon's `Core/Sounds.lua` and this build's sound tables: each sound's kit, labels, volume, files and length |
| `css/game.css`, `css/bench.css` | The game side, and the bench around it |
| `icons.html`, `js/icons-recipe.js` | The addon icon's candidates (2026-11-11): KaLi Quest's « Noir et or » with a sign of recipes after the K, drawn with KaLi Quest's own parts (`../../testbench/js/icons.js`), at the game's sizes and beside KaLi Quest's icon. The game's scroll is recoloured from its own pixels, read from `art/icon-sources.js` (`python -I recipe-notebook/tools/bench_icon_art.py`: a page opened from disk can't read an image file's pixels) |
| `art/` | Generated: icons, map tiles, texture sheets, the fonts, Ikar's world screenshots |

Rebuild the data and art with `python -I recipe-notebook/tools/bench_data.py` from `C:\devel\WowAddons` (cached, quick on a re-run), and the sounds with `python -I recipe-notebook/tools/bench_sounds.py` (into `art/sounds/`; `run_lua_tests.py` fails when they no longer match the addon's list). `python -I recipe-notebook/tools/shot.py <dir> name="<hash>"` screenshots states in headless Edge.

## Licences

`art/` holds Blizzard's textures, icons, map tiles, sounds and font, for local development only. `art/world/` holds Ikar's screenshots, which show character names. QuestieDB's data is GPL-3.0. Don't publish any of it, or ship it with the addon.
