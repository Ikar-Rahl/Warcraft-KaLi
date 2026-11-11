# Recipe notebook: design

Now **KaLi Recipe** (see "The addon" below); first called the recipe notebook. An addon for WoW Forever (interface 16001, French client) that remembers every recipe Ikar comes across and shows how many they don't know, without spoiling recipes they have never met. Started 2026-11-09, after no existing addon fitted (see "Why not an existing addon").

## Decided

Ikar's rulings, 2026-11-09:

- **Count only what was seen.** "12 unknown" means: recipes met somewhere (vendor, trainer, auction house, drop, quest reward) that this character doesn't know. No built-in list of recipes, so nothing never met can show.
- **Every profession**, including ones the character doesn't have, and the gathering ones: on Forever they have recipes too (Minage's smelting, « Barres fondues »; « Campement » camp items for all four, with « Plan : … » recipe items).
- **Sources scanned:** vendors, trainers, the auction house, recipes that enter the bags, quest rewards.
- **Auction house:** ~~one query on the Recipes category each time the auction house opens~~. Replaced 2026-11-10: the addon never searches by itself ("it should never take control over the user"); a button, « Relever les recettes », sends that search on a click. Whatever the game lists is read, with its date.
- **"Used in" on a material's tooltip:** recipes a character knows, plus recipes met somewhere (marked as such). Never a recipe not met.
- **Display:** researched, then mocked as an HTML bench before any Lua (options below). Ikar's picks, 2026-11-09, after the first bench:
  - **The count:** « Carnet : 7 à apprendre · 4 vues » under the rank bar of the professions window (A1) and under each profession in the professions book (A2), shown at zero too: two separate numbers, learnable now and seen (Ikar, later that evening). A profession the character doesn't have counts only « vues ».
  - **Spotting goes to the chat**, nowhere else: every recipe noted at a vendor, a trainer, the auction house or on loot gets a chat line in the crafting blue, the SKILL chat type's colour (so the player's own chat colour setting). No lines in Blizzard's windows. One line per visit (decided later that evening). An in-game option turns it off.
  - **Auction house:** no prices kept (changed the same evening: Auctionator and the like already do it, and they add their lines to any item tooltip, so the addon shows a recipe's real item tooltip and they appear). The auction house is still a place where recipes are seen. On its rows, a plain white eye (`GM-icon-visible`, decided later that evening) marks a recipe this character doesn't know that a vendor seen before also sells.
  - **Markers**, all in the game's own art, each an in-game option:
    - state, top left: known (the objective tracker's small check, `Tracker-Check`), to learn at the current rank (required rank in its difficulty colour), or rank too low (in red). Nothing for a profession the character doesn't have (dropped the same evening);
    - possession, along the bottom: this character holds it, bags or bank alike (the minimap's banker, `Banker`, on a small dark disc, bottom left, decided later that evening: the backpack was too loud, and a bare brown bag vanishes on the beige recipe scrolls), and another character holds it (the friend icon, bottom right). Both can show at once;
    - no check where a list already says it: the notebook's « Appris » and the trainer's « Déjà connu ».
    - crafted items (asked by Ikar, later that evening): an item a known recipe makes carries the profession's small icon (the world quest pins' `worldquest-icon-cooking`, `-mining`…) top left, the corner that says what an item means for your professions, as retail puts its crafting marks there. Bright when this character can make it; dimmed when only another character can, or (an option) a recipe was only seen. The item's tooltip gets « Fabriqué par » before « Utilisé dans ». An in-game option, on by default;
    So the addon tracks every character's bags and bank.
  - **Loot:** record the mob's name and zone, and show them in the notebook.
  - **The addon's tooltip lines are blue** (Ikar, end of the evening: blue is the crafting colour, as in the chat): the light blue the game itself gives « Composant d'artisanat » in item tooltips, because the chat's darker SKILL blue is hard to read on a tooltip.
  - **The add-ons button entry shows no total** (Ikar, end of the evening): « Carnet de recettes », nothing more. Not an option.
  - **A recipe's tooltip:** detailed, one line or none, an in-game option, detailed by default: who knows it, who holds it, where it was seen, learned recipes included (Ikar). No auction price.
  - **« Utilisé dans »** on a material: by profession, as a list, up to N lines (default 10), with recipes seen and where each was seen, all in-game options.
  - **The notebook is D1**, a WoW-style window, colours toned down (not a Christmas tree):
    - **Not the others:** D2 (book) was close; D3 (side panel) is out.
    - **Rows:** by recipe, with the required rank as a level badge, as KaLi Quest shows quest levels.
    - **Sections:** « À apprendre » (seen, learnable at the current rank), « Vues » (seen, rank too low, or a profession the character doesn't have), then « Appris » (the game's own word, `TRADE_SKILLS_LEARNED_TAB`), collapsed by default and kept so the information can be shared. Two separate counts follow: « 7 à apprendre · 4 vues » (Ikar, later that evening). A row shows who holds the recipe, this character's banker and another character's friend icon on the same line.
    - **Search and filters:** the game's own filters, plus the notebook's.
    - **Categories** (asked by Ikar, later that evening): inside each section, recipes sit under the professions window's own categories, in its order: enchanting by piece (« Enchantements de brassards », « de bottes »…), tailoring by garment, cooking by what the food raises. The data is the game's (`TradeSkillCategory`, `SkillLineAbility.TradeSkillCategoryID`); in game, `C_TradeSkillUI.GetRecipeInfo(id).categoryID` and `GetCategoryInfo`. A recipe outside its profession's tree goes under the game's « Divers » (`MISCELLANEOUS`). The filter menu offers the categories too.
    - **Two buttons in the header** (asked by Ikar, later that evening): the hammer opens Blizzard's professions window on the profession shown (`OpenProfessionUIToSkillLine(skillLineID)`, Blizzard's own entry point), for the character's own professions; « Suivre » is a toggle, one switch for all professions (not per profession): on, the notebook opens with the professions window, hangs on its side and moves with it, shows the profession open there and follows when it changes, and closes with it (`TRADE_SKILL_SHOW`, `TRADE_SKILL_CLOSE`, `C_TradeSkillUI.GetBaseProfessionInfo`; listening only). It hangs against the window's right edge, past Forever's profession side tabs, or on its left when the screen runs out: a `SetPoint` on the notebook relative to `ProfessionsFrame`, nothing written to Blizzard's frame. The button is Forever's own arrow button alone, no word (`Profession-button-arrow-right`; its pressed art, in colour, while on; gray while off); its tooltip says what it does and whether it's on. Also an in-game option. Off by default.
    - **Two styles, one layout** (Ikar, later that evening), an in-game option « Style du carnet »: « Épuré » (Clean, the game window D1) and « Livre » (Book, the profession's quest page). Same places in both: header (profession, the rank as the classic skill bar, `UI-Character-Skills-Bar` in blue in its border, the two counts, the two buttons), search and filter, the list, a footer; profession tabs down the right edge (the classic spellbook's side tabs), own professions first. No portrait in the corner. Buttons: retail's dark Settings button (decided). Width and height are in-game sliders, « Largeur » (460 to 900) and « Hauteur » (600 to 1080), 560 by 820 by default; the rank bar gives way when narrow, and Book's parchment covers the page, cropped rather than stretched.
    - **The recipe's detail, below the list** (Ikar, later that evening: "I forgot we have a per item window. I would integrate it to the carnet. Maybe below as a section?"): a left click on a row shows the recipe under the list, as the classic professions window and quest log laid theirs out. It holds the made item (its real tooltip on hover, so Auctionator's price), the category and required rank, the reagents with have/need (hover: the material's tooltip, with « Utilisé dans »), every sighting with its date and a pin that places a waypoint, who holds it and who knows it. Click the row again or × to close. It takes only the room its content needs, up to half the notebook, then scrolls (Ikar: "minimal space, no need to waste it"): short sections sit on one line beside their label, components wrap as many to a line as fit, and « Connue de » shows only when a character knows it. The list keeps its top and the selected row stays in view. It replaces opening Blizzard's recipe window.
    - **Who holds it, in the notebook** (Ikar): the notebook's own options, apart from the item markers: the banker on rows of recipes this character holds, the friend icon for another character's, with the counts in the detail. All on by default. The words under the icons (« votre banque · Elorah ») went on 2026-11-10 (Ikar: "useless"), and the bag lost the dark square behind it in the rows: where is the detail's.
  - **D4 map pins** in the game's own icons.
- **Robust only, no fragile tinkering** ("I want robust solutions"). The addon never writes into Blizzard's frames or data: no rows of its own inside Blizzard's recipe list, and no recipe pushed into the professions window's detail pane. It draws its own pieces beside Blizzard's, and asks the game to show things through Blizzard's own entry points, such as `OpenProfessionUIToSkillLine`.

## Principles

- **Store numbers, never names.** Item, spell, NPC and map numbers only; the client names everything in its own language. ForeverArtisan and Profession Tracker both fail on the French client because they key data by English names.
- **Name places as the world map does** (`C_Map.GetMapInfo(uiMapID).name`). This build's French zone table writes some zones with their English name in parentheses (« Sombrivage (Darkshore) », « Marche de l'Ouest (Westfall) », 8 zones); the map's own names don't.
- **No spoilers.** Forever's own professions window hides unlearned recipes on purpose: its Camelot override forces "show unlearned" off and removes the filter (`Blizzard_ProfessionsTemplates/Camelot/Blizzard_Professions.lua`). The addon follows the same line.
- **Account-wide memory** (proposed): a recipe an alt saw counts as seen; "known" is per character.

## What the client gives (API dump 1.60.1)

| Need | How |
| --- | --- |
| Recipe at a vendor | `MERCHANT_SHOW`, `GetMerchantItemID`, `C_Item.GetItemInfoInstant` (class Recipe, subclass = profession) |
| Recipe at a trainer | `TRAINER_SHOW`, `GetTrainerServiceInfo`, `GetTrainerServiceSkillReq`, `GetTrainerServiceItemLink` |
| Recipe at the auction house | `C_AuctionHouse.SendBrowseQuery`, `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`, `C_AuctionHouse.GetBrowseResults` (item numbers) |
| Drops, quest rewards | Recipe items entering the bags; `GetQuestItemInfo` |
| Known or not | Own professions: `C_TradeSkillUI.GetRecipeInfo(...).learned`. A recipe item: the tooltip's "Déjà connu" (`ITEM_SPELL_KNOWN`) |
| Reagents, for "Used in" | Own professions: `C_TradeSkillUI.GetRecipeSchematic` (item numbers). Other professions: the recipe's tooltip text, in the client's language |
| Where it was | `UnitGUID("npc")` for the NPC number, `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition` |
| Taking the player there | `C_Map.SetUserWaypoint`, the game's own map pin |
| Opening the professions window | `OpenProfessionUIToSkillLine(skillLineID)` (Blizzard_Professions_Bootstrap), which calls `C_TradeSkillUI.OpenTradeSkill` |
| Following it | `TRADE_SKILL_SHOW` and `TRADE_SKILL_CLOSE`, `C_TradeSkillUI.GetBaseProfessionInfo().professionID` |
| Categories | `C_TradeSkillUI.GetRecipeInfo(id).categoryID`, `C_TradeSkillUI.GetCategoryInfo(id)` (name, parent) |
| Tooltip lines | `TooltipDataProcessor` or `OnTooltipSetItem`, both guarded (as ForeverArtisan does on this client) |

To probe in game before building: whether a trainer lists its recipes to someone without the profession; whether `GetRecipeSchematic` answers for unlearned recipes; whether `GetRecipeInfo` gives a category for recipes not learned and for other professions (if not, the addon keeps the category it saw last, or « Divers »); which skill line number `OpenProfessionUIToSkillLine` wants on Forever (185 or the expansion's 2939).

**Showing a recipe as the game does** (asked by Ikar, 2026-11-09). Blizzard has its own read-only recipe window: `Professions.InspectRecipe(recipeID)` opens `InspectRecipeFrame` (`Blizzard_Professions/Blizzard_ProfessionsInspectRecipe.lua`), the one the tracked-recipe list opens when a tracked recipe is clicked. It fills Blizzard's schematic form from `C_TradeSkillUI.GetRecipeInfo` and `GetRecipeSchematic`: the result item, the reagents with have/need counts, and the description. Any addon row can call it (notebook, map pin, our own section), so a seen recipe opens exactly like a game recipe without touching Blizzard's list. To probe: whether `GetRecipeInfo` answers for an unlearned recipe of the character's profession, for a profession the character doesn't have, and with the professions window closed. `Blizzard_Professions` loads on demand, so the addon loads it first; out of combat only. If it doesn't answer for other professions, those recipes fall back to the addon's own detail, built from the recipe item's tooltip. Superseded later that evening: Ikar folded the recipe window into the notebook, as a detail section below the list (see "Decided"). The detail needs the same data and the same probes; where `GetRecipeSchematic` doesn't answer, the reagents come from the recipe item's tooltip.

**Rejected by Ikar, 2026-11-09:** rows inside Blizzard's list (the bench's former "list section"). A click there would go through Blizzard's own selection and show the recipe in the professions window's detail pane, but only by writing into Blizzard's data provider, which Forever regenerates with unlearned recipes forced off (`Camelot/Blizzard_Professions.lua`): taint risk and a fight with Forever on every refresh. Also rejected on the same grounds: pushing a seen recipe into the professions window's own detail pane. A seen recipe shows in the notebook's own detail instead.

Found while building the bench's data (build 1.60.1.70790):

- Gathering professions have recipes on this build: Minage smelts (« Barres fondues »), and Minage, Herboristerie, Dépeçage and Pêche all make camp items (« Campement »), some from recipe items (« Plan : serre », « Plan : guide de terrain », « Plan : jardin de pierres »).
- `SkillLineAbility.MinSkillLineRank` is 1 on most rows. A recipe item's real requirement is `ItemSparse.RequiredSkillRank`. The column holds the rank for the 32 recipes the game teaches on its own (`AcquireMethod` 1, such as Forever's minor elixirs, taught with Alchemy at 1) and for 13 trainer recipes; the other 474 trainer recipes have no rank anywhere in the data (their yellow thresholds run from 20 to 250, so they aren't starting recipes): the addon reads it from the trainer with `GetTrainerServiceSkillReq`.
- Recipe item → recipe spell goes through `ItemXItemEffect` (this export of `ItemEffect` has no item column). Every recipe item also carries a learning spell (483 or 402265) to skip.
- The professions window lists recipe names, not item names: "De poussière à granules" makes "Granule de magie", and "Feu de camp basique" makes "Kit de feu de camp basique".

## Notebook looks (explored 2026-11-09)

Ikar asked for "a notebooky style, but with all the icons and other information we discussed", in five variations, then kept two: D1 as « Épuré » and the profession quest page as « Livre » (see "Decided"), and had the others deleted from the bench. Explored and dropped: Forever's two-page spellbook (`spellbook-Page-Left/Right-C60`), a ruled notebook in the quest log's leather (`book-bg`, `QuestLogBackground`), an illustrated spellbook with each recipe's result in a bronze frame (`spellbook-background-evergreen-*`, `spellbook-item-iconframe`), and a narrow pocket notebook.

« Livre » draws the profession's own quest parchment (`QuestBG-cooking`, `-enchanting`, `-tailoring`…, all twelve since 2026-11-10; `QuestBG-Parchment` only if one goes missing), with the profession sketched faintly behind the list. « Épuré » shows Forever's profession card in its inset (2026-11-10). Its text is the game's parchment ink (`PARCHMENT_MATERIAL_TEXT_COLOR`, #2E1F0F), its titles black in Morpheus, the quest-title font (file 615962).

## Display options (to mock in HTML)

The exploration bench, [bench/README.md](../bench/README.md), was built 2026-11-09 at Ikar's request ("Go for an exploration bench of the possibilities"). Ikar chose the same day (see "Decided"), and the bench now shows the chosen design. Its switches are the in-game options. Nothing is left open.

The list below is the full set that was explored.

Sorted by the three tiers of the wow-addon-ui skill: glance, hover, click.

**Glance: where the count lives.**

- A1. One line in the professions window, under the rank bar: "12 recettes vues ailleurs". An addon line beside Blizzard's frame, no Blizzard rows touched. Click opens the notebook.
- A2. In the professions book ("Métiers"): the same count under each profession. Only covers professions the character has.
- A3. Nothing at rest; reached on demand only (compartment, slash command).

**On the spot: when talking to someone or browsing.**

- B1. Vendor: one line at the bottom of the merchant window, "3 recettes ici que vous ne connaissez pas", plus a small mark on those rows.
- B2. Trainer: the same.
- B3. Auction house: the same mark on recipe rows in the results.
- B4. A recipe's tooltip, anywhere (vendor, bag, chat link): "Inconnue de vos personnages", or which character knows it, and where it was seen.

**Hover: a material.**

- C1. "Utilisé dans :" under the material's tooltip: known recipes, then recipes seen (with where).

**Click: the notebook.**

- D1. A standard window like the professions window (`ButtonFrameTemplate`), one tab per profession.
- D2. A book page, like reading a book in game (parchment `ItemTextFrame` style): a handwritten "carnet de recettes".
- D3. A side panel docked to the professions window, open only with it.
- D4. World map: a pin where recipes were seen, as an entry in the map's filter menu; a notebook line can place the game's waypoint there.

**Entry points.** The addon compartment and a slash command (the skill's default), plus A1's line.

## Why not an existing addon

Checked 2026-11-09 in game by Ikar and in code:

- **Mastercraft:** well made and translated, but built around levelling fast: the opposite of the immersion wanted.
- **ForeverArtisan:** looks like a debug menu. On a French client it never finds a vendor recipe: it looks for `"Recipe: " .. name` (`ForeverArtisan_Core/RecipeFinds.lua:222`), and French recipe items are "Recette : …". Trainer recipes work.
- **Profession Tracker:** its data is keyed by English recipe names (`Data.lua`), so on French every known recipe shows "new?" and the summary says "No recipes known yet": what remains is a copy of the vanilla list.

## The addon: KaLi Recipe

Ikar's go-ahead on 2026-11-10: "full implementation of the first version", following KaLi Quest's procedures (testing approach, style, architecture), under the name "Kali Receipe", spelled here as KaLi Quest's family: **KaLi Recipe**. Built the same day, **offline only: nothing has run in the game yet.**

**Where it is.** `recipe-notebook/addon/`: `KaLiRecipe` (the addon), `KaLiRecipe_Tests` (`/kr test`, load on demand), `KaLiRecipe_Probe` (`/krprobe`, development only, kept out of the package by `.gitignore`). Not a git repository yet. Linked into the game on 2026-11-10, with Ikar's go-ahead ("add the addon to my game"): `recipe-notebook/tools/link_addons.cmd` made three junctions in `Interface\AddOns`, `KaLiRecipe`, `KaLiRecipe_Tests` and `KaLiRecipe_Probe`; `link_addons.cmd unlink` removes them. Saved data: `KaLiRecipeDB` (account-wide: characters, sightings, options), `KaLiRecipeCopyDB` (per character: a copy of the notebook, written at logout), `KaLiRecipeDevDB` (debug log, errors, API checks), `KaLiRecipeProbeDB`. Its format and rules: [saved-data.md](saved-data.md). Slash command `/kr` (`/kalirecipe`).

**Architecture**, as KaLi Quest's: every file starts with `local _, ns = ...`; events go through `ns.On` and `ns.SafeCall`, so an error is kept, sent to the game's handler for BugSack and said once per session; frames are made without a parent, then given one; nothing is written into Blizzard's frames or tables (post-hooks and post-calls only read, and the addon's own frames ride on Blizzard's or anchor to them); decisions sit in a pure model tested on a fake game.

| File | What it holds |
| --- | --- |
| `Core/Init.lua`, `Debug.lua`, `Locale.lua` | KaLi Quest's frame: events, deferred work, `ns.Changed` (one redraw per frame), the log and errors, French strings first and the game's own through `ns.G` |
| `Data/Recipes.lua` | Made by `tools/gen_addon_data.py` from the game's tables, numbers only: recipe item to recipe spell; each recipe's skill line, required rank, thresholds, category, product and reagents; the categories and their order; the professions' icons and names |
| `Data/Needs.lua` | Made by `tools/run_lua_tests.py --write-needs`: what the addon takes from the game, for the API check |
| `Core/DB.lua` | Loading on a copy, upgrade steps, the bench's defaults, ranges, repair; a per-language cache of NPC and quest names, keyed by number |
| `Core/Model.lua` | Pure: states, the two counts, the three sections, categories in the game's order, who knows and who holds, « Utilisé dans », « Fabriqué par », search and filters, a sighting noted once per place |
| `Core/Text.lua` | Pure: dates, where a recipe was seen, where it's held |
| `Core/Game.lua` | The client as the model sees it, and the current character: professions and ranks, known recipes, recipe items in bags and bank |
| `Core/Scan.lua` | Vendors, trainers, the auction house, loot, quest rewards, bags and bank, the professions window, learned recipes |
| `Core/Sounds.lua` | The two sounds (2026-11-10): the quill and its shorter strokes, the parchments, the pick, the quiet gap |
| `Core/Commands.lua`, `SelfCheck.lua`, `Main.lua` | `/kr`; the API check and its assumptions; startup |
| `UI/Widgets.lua`, `Chat.lua`, `Tooltips.lua`, `Markers.lua`, `CountLines.lua` | Shared pieces; the chat line; tooltip lines; marks; « Carnet : … » |
| `UI/Notebook.lua`, `Detail.lua`, `Follow.lua` | The notebook, its recipe detail, « Suivre » |
| `UI/MapPins.xml`, `MapPins.lua`, `Options.lua`, `Report.lua` | Map pins; the options page and the compartment; the bug report |

**Testing**, KaLi Quest's procedure. `python -I recipe-notebook/tools/run_lua_tests.py`, from `C:\devel\WowAddons`, must end in `ALL PASS`. It loads KaLi Quest's runner and runs its checks on this addon:
- the code compiles; its C_ functions, global functions and methods exist in this build's docs or Blizzard's own code; no stray global; the package is whole; the needs list is current; the data holds together;
- what the fake would otherwise invent comes from this build (added by the review of 2026-11-10, after an invented bag table hid a real fault): every `Enum` table the addons name is put into the fake from the API docs, member for member; the addon's XML templates are built as the game builds them, so the world map's own assertions on a pin run offline; the French game strings the fake defines are the client's (`frFR.lua`); each sound on offer is a kit of this build's `SoundKit` table with a file, under its `SOUNDKIT` name, and the bench lists the same ones;
- the 59 tests of `KaLiRecipe_Tests`, the same as `/kr test` in game (the sound tests only pick, so `/kr test` makes no sound);
- the restart sessions: new Lua states started from the files the smoke session wrote at logout (both files; the account file gone; a newer copy), see [saved-data.md](saved-data.md);
- `tools/lua/smoke.lua`, a whole session on KaLi Quest's fake API plus `tools/lua/fakewow_recipe.lua`: a vendor, a trainer, the auction house, loot, a quest reward, bags and bank, the professions window and book, « Suivre », the notebook in both styles and sizes, tooltips, pins (hovered and clicked through the map's own handlers), options, the sounds at each visit, every command, the report and the probe.

117 deliberate breaks, each on a copy, are all caught (`mutate_recipe2.py`, `mutate_data.py`, `mutate_new.py`, `mutate_art.py` and `mutate_grip.py` in the session's scratchpad: the first build's 24, the review's faults put back, the sounds' rules broken, the strokes' stop and fade among them, the first in-game session's changes undone, each rule of the saved data broken once, and the second session's changes undone). The nan check written with comparisons is the one break no offline run can catch: only the game's Lua compares nan wrongly, and `/kr test` in game catches it; the first run missed one, which gave a new test. The first runs also found two faults the game would have shown: `C_TradeSkillUI.GetAllRecipeIDs` doesn't exist in this build (the addon now reads `GetFilteredRecipeIDs`, as Blizzard's own list does), and Book's parchment crop failed on an atlas without coordinates.

**My calls, not confirmed by Ikar:**
- **The generated data.** No game function says which recipe a recipe item teaches (the item's spell is the learning spell, 402265), so the addon carries the game's own links, as KaLi Quest carries `Data/Sorts.lua`. It's read only for recipes met, known or held, so nothing never met can show: that's how I read Ikar's "no built-in list". Where the game answers (a trainer's required rank, the window's categories), its answer wins. After a patch, `gen_addon_data.py` makes it again, and the API check notes any recipe item the data doesn't know.
- **The sounds** (Ikar, 2026-11-10: "one for a new recipe discovered, and a smaller one for a new source"). The game's own sound kits, played by number: they follow the player's effects volume and mute, and the addon ships no file. « Son d'une nouvelle recette » plays when a visit notes a recipe that wasn't in the notebook at all (never seen, known by none of the characters); « Son d'un nouvel endroit » when it notes a new place for one that was. One sound per visit, the same visits and recipes as the chat line (so not for quest rewards or recipes arriving in the bags, nor for recipes this character knows), and at least 3 seconds after the last, so an auction house's pages or a run of loot make one and the quill ends before another starts; the bigger may still follow the smaller when a later page brings a recipe never met. Each sound is its own option, apart from the chat line, and can be « Aucun ». Ikar listened on the bench, 2026-11-10, and kept only the quest log's quill (`IG_WRITE_QUEST`, three takes of 2.2 to 3 seconds), for a new recipe; for a new place, "any other sounds like a pencil? shorter?". The game has no other writing sound (searched in the community list of its file names: the three quill takes are the only ones), so the shorter ones are the same quill stopped early: `PlaySound` returns a handle, and `StopSound(handle, 200)` fades it out (as Blizzard's talking heads do), after 0.9 seconds (« Quelques mots ») or 0.4 (« Trait de plume », Ikar's pick for a new place, 2026-11-10). The quill is one continuous scribble with no pause, so any of its takes stops cleanly there. The other short ones are two parchments, the bags' own sounds for a paper item laid down (kit 1209) or picked up (kit 1192), which have no SOUNDKIT name: the offline checks hold them against the file each plays. Both settings offer the same five.
- **Chat, only what's new:** a recipe never seen, or a new place for it. A second visit to the same vendor says nothing. Quest rewards and recipes arriving in the bags are noted silently, as the ruling lists vendors, trainers, the auction house and loot.
- **Known** comes from the professions window (the only source allowed to take a recipe off), a trainer's « Déjà connu », a recipe item's « Déjà connu » tooltip line, `NEW_RECIPE_LEARNED`, and the spellbook (`C_SpellBook.IsSpellKnown`, which only adds).
- **Held:** recipe items only; the bank is read while it's open: this character's bank tabs. The account's tabs are left out, as what every character shares would show as one character's.
- **The compartment entry** shows the addon's title, « KaLi Recipe »; the window keeps « Carnet de recettes ». Click opens the notebook; right click, the options.
- **Map pins** use the world map's own data provider, with no entry in the map's filter menu, as that would write into Blizzard's menu. Only recipes this character doesn't know get a pin. A click places the waypoint.
- **The tooltip blue** is read from the game's own « Composant d'artisanat » line, the first time a tooltip shows one (`KaLiRecipeDevDB.reagentColor`); until then, a close light blue.
- **The icon** is the game's `INV_Scroll_03` for now; a KaLi-family icon can follow, on `testbench/icons.html`.
- **MIT**, as KaLi Quest. **No report address** yet, since there's no repository.
- **The footer** counts everything in the notebook. **A profession** the game gives under another number is recognised by its parent's number or its name.

**Assumptions about the game, and their test** (KaLi Quest's rule: each assumption is covered). The API check, `Core/SelfCheck.lua`, runs at login, when the professions window shows and when the auction house closes. It keeps its result per build, goes in each report, and says once in chat when something isn't as assumed.

| Assumption | Checked by |
| --- | --- |
| Every function, event, atlas, template and game string the addon names exists | The needs list, at login |
| `Enum.ItemClass.Recipe` is 9; tooltip data types are Item 0 and Spell 1 | "game numbers" |
| The data's product and reagents are the game's own (`GetRecipeSchematic`); also how many recipes it answers for, learned or not | "schematics", on 25 noted recipes |
| A recipe item's required rank is the data's (`ITEM_MIN_SKILL` in its tooltip) | "required ranks" |
| Every recipe item met is in the data | "recipe items" |
| `GetProfessionInfo` gives the base professions' numbers | "skill lines" |
| A trainer's recipes are recognised: by its tooltip's spell, the item it makes, or its name | "trainers", with how each was |
| The search sent by « Relever les recettes » is taken and answered | "auction house" |
| The window's profession is one of the addon's, and the spellbook agrees with its learned recipes | "professions window" |
| The chosen sound kits play: `PlaySound` says it will, while the game's sound is on; `StopSound` stops a stroke (`/krprobe sounds` notes both) | "sounds" |
| The bank is this character's bank tabs (`Enum.BagIndex.CharacterBankTab_1` on) | `/kr test`, "the bank's numbers", on the client's own enum |

**Not testable by code, to try in game:**
- where « Carnet : … » sits under the rank bar and in the book;
- the marks on vendor slots, bags, Baganator and auction rows;
- Book's parchment crop, and « Suivre »'s gap past Forever's side tabs (48);
- whether the addon's auction search fills Blizzard's browse list (Ikar's screenshot of 2026-11-10 says it does), and the marks at the quantity's end;
- the chat colour and the map pins;
- Blizzard's own bags on Forever: their code is split by game type, and the hooks only attach where `UpdateItems` exists;
- how loud the sounds are next to the game's own, at Ikar's volume settings.

**To try in game, in order:**
1. Linked on 2026-11-10 (`recipe-notebook\tools\link_addons.cmd`); a full restart of the game, as the addons are new.
2. Log in with `KaLiRecipe` and `KaLiRecipe_Probe`; `/kr test`; `/reload`. Then `python -I recipe-notebook/tools/read_saved.py` reads the probe and the API check.
3. Visit a vendor with recipes, a trainer (`/krprobe trainer` there), the auction house (`/krprobe ah`), the professions window (`/krprobe window`, then `/krprobe spellbook`), look at a recipe item's tooltip (`/krprobe tooltip <item>`), and open the bank (`/krprobe bank` there: the tab bank's numbers and what the addon read). `/krprobe sounds` plays every sound on offer, one every 3.5 seconds, and notes whether the game played it. `/reload`, and I read them.
4. Open the notebook (`/kr`) in both styles, try « Suivre » with the professions window, open the world map, and send screenshots, so I can see what the bench only approximated.
5. Listen to the sounds on the bench first (panel « Sounds »), pick in Options › KaLi Recipe › « Annonces » (each plays when picked), then visit a vendor with a recipe never seen.

**Review of 2026-11-10** (Ikar: "a full, thorough and in depth review"). Every file read, Blizzard's code checked for each frame and function the addon relies on. Fixed, each with a test or a smoke check that fails without the fix:
- **The bank was never read.** The code looked for `Enum.BagIndex.Bank` and `BankBag_N`, which this build doesn't have: Forever loads the tab bank (`Blizzard_UIPanels_Game/Camelot/BankFrame.lua`), `CharacterBankTab_1` to `_9` (6 to 14), and -1 is the keyring. The fake had invented the same names, so the tests passed. Now the character's tabs are read, and the fake's enums come from the docs.
- **Map pins would have broken.** The pin template had OnEnter and OnLeave scripts; Blizzard's `AcquirePin` asserts a pin template has none (it sets its own, which call the mixin's `OnMouseEnter`), and without `enableMouse` the pin takes no mouse at all. Now as Blizzard's pins: `enableMouse`, no scripts. The pins also grew with the map's zoom (no `SetScalingLimits`; now 1 to 1.2, as the quest offer pins). And the provider's refresh runs inside the map's loop over all providers: an error there would have stopped the map's own pins refreshing; it's now contained.
- **Errors at login and with refused data.** The scan's handlers ran on events that fire while the game loads, before `PLAYER_LOGIN` makes the model (`SKILL_LINES_CHANGED`, `BAG_UPDATE_DELAYED`), and after saved data was refused: an error each time. They now wait for the model; `Scan.AtLogin` reads what they'd have read.
- **A misread profession forgot its recipes.** A profession the game listed under a number and name the addon didn't recognise counted as given up, and its known recipes were wiped. Now none is taken as given up while one is unread.
- **The category filter** dropped a recipe whose category the professions window gave but the data doesn't hold: listed under « Divers », filtered by its raw number.
- **The detail's long lines** (a long NPC or zone name in a narrow notebook) ran past the right edge: cut with the game's ellipsis, whole on hover.
- **The « Déjà connu » check** of a recipe item in the bags was made once per session even when the tooltip hadn't loaded: now again until it has.
- **Wording:** `/kr` with an unknown command said "type /kr for help", which opens the notebook (now `/kr help`); the marks' options said « niveau » where the rest says « rang »; two English options read badly; an option's tip named the bench's invented Elorah. The bench's options page said pins were also in the map's filter menu, which they aren't.
- **Smaller:** the categories' collapse now plays the same click as the sections'; the badge falls back to the current character.

Looked at and left as they are: post-hooks and HookScript only read; frames are the addon's own, parented or anchored to Blizzard's; the compartment's call signature matches Blizzard's `AddonCompartment.lua`; Baganator's corner widget API matches the installed version's; the French game strings the fake uses are the client's.

Left for Ikar or the game:
- Blizzard's bank window gets no marks (the bags and Baganator do): Forever's tab bank has its own buttons, to hook once seen in game.
- The account's bank tabs aren't read (see "Held").
- A trainer that hides its unavailable services lists fewer recipes to note; the addon doesn't change the trainer's filter, as that's Blizzard's state.
- The notebook draws every row of the open sections at each refresh: fine for hundreds; a virtual list if it ever gets slow.
- The count lines in the professions book are at the bar's strata (HIGH, Blizzard's own for the rank bar), so they may show over a bag frame placed over the book.

**Ikar's first session in game, 2026-11-10.** `/kr test` passed and the probe found no fault. What Ikar asked for, and what changed:
- **Known recipes showed « ? » for their rank** ("a recipe already known should be in the book fully"). A trainer's recipe has no rank in the game's tables, and the trainer's list hides recipes already known unless its filter's « Déjà connu » (`USED`) is ticked; the professions window gives no rank either (`TradeSkillRecipeInfo` has none). Now the data carries the game's own rank where it has one (above), so the recipes it teaches by itself show 1; a trainer read with « Déjà connu » ticked gives the rest, since the scan already keeps the rank of every service listed; and the detail of a recipe still without one says so, in a line « Rang requis : pas encore lu : chez un maître, cochez « Déjà connu » dans son filtre ». Ikar asked whether such recipes are the starting ones, rank 0 by default: only those the game teaches by itself, so no default. Not done: ticking the trainer's filter for the player and putting it back, which would change Blizzard's state and its list's selection; Ikar's call.
- **Two « Élixir de Force mineure »** in « Appris »: two recipes of the game, 2329 (grey at 95) and Forever's 1245250 (grey at 15), both known.
- **A settings gear, top right** of the notebook, beside the close button: Blizzard's own (`questlog-icon-setting`, its highlight added at 0.4 as `UIPanelIconDropdownButtonTemplate` does); it opens the options. Ikar's next screenshot didn't show it: `ButtonFrameTemplate`'s border is a child frame at level 500 (its close button and title at 510), so a button at the frame's own level sits under the title bar. Now at the close button's level; the fake builds the template's border and close button, and the smoke test holds the gear above the border.
- **« Suivre » was a bit off** (Ikar's screenshot, measured): drawn at 24 for art of 22 (`Profession-button-arrow-right` resolves to Forever's `-c60` art, 22 by 22), its right edge 3 units past « Filtrer » below, and 5 above the middle of the title and skill bar. Now 22, in line with « Filtrer », centred on the header.
- **A tiny scroll bar in the detail** with nothing to scroll: the bar now hides when it isn't needed (`SetHideIfUnscrollable`, Blizzard's), and the detail takes 6 more pixels.
- **The rows' bag in a square, words under it:** both gone (above).
- **« Écouter » under each sound list** in the options, as Blizzard puts an action under a setting (a button row, `CreateSettingsButtonInitializer`).
- **« Fabriqué par » and « Utilisé dans » name the recipe, not where it was seen** (Ikar: "should carry the recipe, but not the source"): « vue » on the right, or who knows it. The option that put the place there went.
- **The vendor's price** ("store the cost on the vendors"): what the merchant asks, read at each visit (`C_MerchantFrame.GetItemInfo`, and `GetMerchantItemCostItem` for tokens or items), kept with the sighting and updated by the next visit, since a reputation's discount changes it; shown after the vendor in the detail and on the right of the recipe's tooltip, in the game's own coins (`GetMoneyString`).

**Saved data, format 2, 2026-11-10.** Ikar: "are the data saved coherent? This is the most critical piece. I want any future update to work well with previous data. People will also need to export and import (don't implement it now). We need the data to be upgradable, and robust. Resilient, recoverable." Their own file was coherent, and opens unchanged. Three weaknesses were found and fixed, all in [saved-data.md](saved-data.md), which is now the format's reference:
- Repair deleted what it didn't understand. Now it keeps anything from a later version and ignores it, and sets aside anything it can't read. The option pruning added earlier that day went too.
- Every default was written into the options, so a later change of a default never reached a player. Now only changes are saved.
- One file held everything, with only the game's `.bak` behind it. Now each character's file keeps a copy of the notebook, which brings it back or completes it.

The sighting's place is now a rule of the format, the same one merging uses. A forgotten recipe leaves a mark. The notebook records which version wrote it and when, and keeps a history. `/kr data` and `read_saved.py check` show its state. Ikar went ahead with "do it".

**Ikar's second session in game, 2026-11-10, evening.**
- **`/kr test` failed in game, one check:** "a nan and an inf taken out: expected 2, got 1". The game's Lua compares nan as equal to everything, so `v == v` and `v < math.huge` let it through; offline Lua compares as it should, so only the game could show it. Numbers are now judged by how they print (`DB.Finite`: digits, a point, e and signs only; nan and inf print with letters or #), and a test checks nan, inf and IDs without comparing them. Before this, a nan in the saved data would have been written, and the file would have failed to read.
- **« Suivre » still looked off, down and to the right.** Its "on" art was the button's pressed art, `Profession-button-arrow-right-pressed`, whose inner panel and arrow sit 2 pixels right and 2 down at the art's 44 (measured on the sheet). That's the look of a button held down. Now the normal art always, in colour when on and grey when off; the pressed art only while the mouse holds it, as a game button does; a highlight on hover.
- **Recipes still with « ? »**, such as « Potion de mana mineur » (2331): the trainer's recipes, as in the first session. None of Ikar's saved ranks is alchemy's, so no alchemy trainer has been read with « Déjà connu » ticked. Unchanged; whether the addon may tick that filter itself is still Ikar's call.
- **A minimap button, "ideally something that will be caught by Titan Panel"** (`UI/MinimapButton.lua`). The bars find addons through LibDataBroker-1.1, which each bar loads itself (Titan does), so no library is shipped: at login, if LibDataBroker is there, the addon registers a launcher, "KaLi Recipe", icon and name only (a data source would show a total, against the ruling of 2026-11-09). The minimap button is the addon's own, built like the common ones (the tracking border, the round background, the icon at their sizes), named `KaLiRecipeMinimapButton` so collectors such as MinimapButtonButton find it, and it goes round the edge of a round or square minimap (`GetMinimapShape`, which SexyMap defines). Both do what the compartment does: click, the notebook; right click, the options; the same tooltip. Options, a section « Minicarte »: « Bouton sur la minicarte » (on) and « Verrouiller sa place » (off); its place is `ui.minimap`, in degrees.
- **The trainer's price** ("Enseigner should have prices, dedicated option to show them or not too"): what the trainer asks, read at each visit (`GetTrainerServiceCost`), kept and updated as the vendor's, shown after « Enseignée par » in the detail and the tooltip. Its own option, « Prix des recettes enseignées », in « Infobulles », on by default. The vendor's price has no switch.
- The options said « entraîneur »; the game says « maître ».
- **"So impossible to get the level from something already trained?"** From the game, yes: no function gives a recipe's required rank (the one `requiredSkillRank` in the docs is an optional reagent slot's), the tables have none for 656 recipes, and the colour thresholds don't give it (yellow minus 25 is right for 16 of Ikar's 24 tailoring ranks, wrong for 8). WhatsTraining, installed, carries Forever's trainer ranks (MIT; all 24 of Ikar's matched, 11 of their 13 missing ones found), but Ikar ruled: **"no external data, as much as possible."** So the rank comes only from the game: its tables, or a trainer read with « Déjà connu » ticked.
- **Every profession's art, in both styles** ("add the arts to missing professions in the tabs, also add them to the minimalist design"). Book had no quest page for first aid, herbalism, mining and skinning, which got the plain one: the build has all four (`QuestBG-FirstAid`, Forever's own art, and `QuestBG-herbalism`, `-mining`, `-skinning`). Clean now shows, inside its inset, the card Forever's professions window puts behind a recipe (`Profession-background-card-<profession>`, Camelot's `GetProfessionBackgroundFormat`): dark brown, the profession sketched faintly in its bottom right, so the window keeps its dark look. It covers the inset at any size, cropped from the top and left so the drawing stays; a card the build lacks leaves the inset as it was. All 24 names are checked against the build's atlas tables.
- **The width and height can't be watched** ("the option close all others"): Blizzard's options panel is a centre window (`area = "center"`), and showing one runs `CloseWindows`, which hides every window in `UISpecialFrames`, the notebook among them. Ikar asked for Edit Mode: this build's Edit Mode manages Blizzard's own systems only (`Enum.EditModeSystem`), with no entry for an addon's window; the addons that appear there hook Blizzard's manager, through a library. Instead, at Ikar's go-ahead, a **corner grip**: Blizzard's own (`PanelResizeButtonTemplate`, the chat windows' grip), bottom right, above the window's border. The notebook is laid out again as it's dragged, held within the ranges of « Largeur » and « Hauteur », and the size is kept there in whole units when let go; docked, the notebook goes back on the professions window. The sliders stay, for exact values and the reset.
- **The auction house with Auctionator** (Ikar's two screenshots). Both faults were the addon's own, not Auctionator's: the marks went after the first cell's text, and in Blizzard's browse list the first column is the price (`GetBrowseListLayout`: price, item, quantity, favourite), whose cell has a `Text` too. The marks now go after the item's name, in the cell with an icon and a text (`AuctionHouseTableCellItemDisplayTemplate`). The fake had the same wrong row, one cell with a text, which is why the tests passed; it now builds Blizzard's four cells. « Relever les recettes » sat at the top right, over « Filtrer » and « Recherche »: it's now in the empty strip along the bottom, right of the money, and shows only with the browse list (an item's auctions, selling and Auctionator's tabs have their own buttons there). Why it showed: the addon's query went one second after opening, while Auctionator's own queries held the game's throttle, so it was refused. Now it waits until the house is quiet (no query in the throttle, nothing sent, queued, answered or listed for 2 seconds), so it never cuts into Auctionator's scans, whose results are read all the same; the button shows only if the game refuses the query, gives no answer, or is still busy after a minute.
- **"I see no button, and the addon constantly opening his page, it should never take control over the user"** (with a screenshot of the browse list, every row a recipe). The addon's search replaced whatever the house showed: it waited for 2 quiet seconds, and a quiet house is also a player reading their own results, so their search was swapped for the Recipes category. Ikar's ruling of 2026-11-09 (one search each time the house opens) is replaced: **the addon never searches by itself.** « Relever les recettes » is now always there with the browse list, bottom right, and sends the search on a click; it stays for another. It's a child of the auction house, so the house's dialogs cover it. Like the game's own search button, it doesn't wait for the throttle: the game queues what's sent. What the game lists, by the player's searches, Auctionator's scans or the button, is read as before. The whole waiting machinery went with it.
- **The marks sat over long names** (the same screenshot): after the name, held 60 short of the column's end, which on a long name is its middle. The name column fills the row and a long name runs to its end, so nothing can sit after it. The one space Blizzard leaves empty is the end of the quantity's column: its cell is 50 wide with the game's copper prices (60 less 10 of padding), the count is written from the left in a few digits, and 10 more are free before the favourite's star. The marks go there, from the right: the state at the edge, so it reads as a column, then the eye, then the bags' marks, as many as fit beside the count (with three digits, the state only); the item's tooltip says it all.
- **"Will it work as well with Auctionator and Classic? Can a user disable the auction integration?"** Auctionator, as installed (version 344): on Forever it loads its code for the modern auction house, and its searches, shopping lists and scans go through `C_AuctionHouse.SendBrowseQuery`, so the recipes they list are noted as the player's own searches are. Its result lists are its own frames, with no API to mark rows (its `Auctionator.API.v1` gives prices, searches and shopping lists), so they get no marks and no button; marking them would mean hooking its frames, against the ruling of 2026-11-09. Hovering one of its rows shows the game's item tooltip (`SetHyperlink`), with the notebook's lines. The button shows on Blizzard's « Acheter » tab, which Auctionator opens by default. Classic: the addon is built for Forever only (`## Interface: 16001`) and doesn't load on Blizzard's Classic clients; Era and its kin have the old auction house (`AuctionFrame`), Cata and Mists Classic the modern one, and the professions window, art and APIs differ more widely. A port would be its own project. (Ikar then said they meant Blizzard's own auction house, without Auctionator, by "classic": that's the one the addon is built on, Blizzard's browse list and frame, so the Classic clients part answers a question not asked.) The switch: **« À l'hôtel des ventes »**, in « Fenêtres et carte », on by default, takes away the button and the marks there; the recipes listed are still noted, since the auction house is one of the places of the ruling of 2026-11-09.
