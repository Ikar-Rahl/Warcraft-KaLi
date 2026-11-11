# KaLi Recipe: saved data

The notebook is the one thing the addon can't get back from the game, so its saved data has rules of its own. This page is the format, those rules, and how they're checked. The code is [Core/DB.lua](../addon/KaLiRecipe/Core/DB.lua). Format 2, decided on 2026-11-10: Ikar asked for data that is "upgradable, and robust. Resilient, recoverable", with export and import to come later.

## The files

| Variable | File | Holds |
| --- | --- | --- |
| `KaLiRecipeDB` | `WTF\Account\<account>\SavedVariables\KaLiRecipe.lua` | The notebook, for every character of the account |
| `KaLiRecipeCopyDB` | `WTF\Account\<account>\<realm>\<character>\SavedVariables\KaLiRecipe.lua` | A copy of the notebook, as it was at that character's last logout |
| `KaLiRecipeDevDB` | The account file | Debug log, errors, API checks, last test run. Not part of the notebook |

The game writes the files at logout, `/reload` and quit, never during play, and not on a crash. It keeps the file before each write as `KaLiRecipe.lua.bak`.

## The notebook, format 2

Keys are numbers wherever the game has a number: recipe spells, items, NPCs, maps, quests. Never a name, so the language of the client doesn't matter.

| Key | What | If it's lost |
| --- | --- | --- |
| `version` | The format: 2 | — |
| `sightings` | `{ [spell] = { sighting, ... } }`: where and when each recipe was seen | **Gone for good.** This is the notebook |
| `forgotten` | `{ [spell] = time }`: recipes taken out with `/kr forget` | A copy could bring them back |
| `options` | Only the options the player changed. The others read their default | The player's choices |
| `names` | `{ [locale] = { npc = { [id] = name }, quest = { ... } } }`: names the game gave | Shown as « Quelqu'un » until met again |
| `reqs` | `{ [spell] = rank }`: required ranks read at trainers | Read again at the next trainer |
| `cats` | `{ [spell] = category }`: categories read in the professions window | Read again there |
| `chars` | `{ [GUID] = { name, class, seen, bankSeen, known, bags, bank, profs, maxRanks } }` | Each character's are read again at its next login (bank when it's opened) |
| `ui` | The window's position, tab and open sections; `minimap`, the minimap button's place in degrees | The window and the button go back to their default place |
| `meta` | `{ id, created, writer, written, history, setAsideDropped, nonFinite }` | — |
| `setAside` | `{ { t, at, why, v }, ... }`: what loading couldn't read, as it was | — |

**A sighting** is `{ k, t0, t, npc, map, x, y, q, item, cost, costs }`:
- `k`, the kind: `vendor`, `trainer`, `ah` (auction house), `drop` (loot), `quest` (a reward), `bags`.
- `t0` and `t`: first and last seen, in seconds (`time()`).
- `npc`, `map`, `x`, `y`, `q`: where. `x` and `y` run from 0 to 1 on `map`.
- `item`: the recipe item that was seen. Trainers have none. The recipe is worked out from it (`RECIPE_ITEMS`), so keeping the item lets a later version link the sighting again if a patch changes that.
- `cost` (copper) and `costs` (`{ { n, item or currency, tex } }`): a vendor's price at the last visit; a trainer's has `cost` only.

**`meta`** names the notebook (`id`, made once, so an import can tell its own notebook from another's) and records when it was made, which version last wrote it and when, and its last 20 events: created, upgraded, set aside, restored, merged.

## The rules

1. **Opening never loses anything.** `DB.Load` works on a copy. Every step, repair and check runs on that copy, and the copy is used only if all of them succeed. A file from a newer version, or one that fails a step, is refused: the addon stays off and the file is written back exactly as it was read.
2. **What this version doesn't understand stays, and is ignored.** A sighting of a kind a later version added, a field, an option, a key. The model doesn't show them (`Model:Sightings`), and saving keeps them. So going back a version, or importing from a newer one, loses nothing.
3. **What can't be read is set aside, never deleted.** `setAside` keeps the value as it was, where it was and why. Opening the notebook again doesn't set it aside twice. At most 500 entries are kept, the oldest going first, counted in `meta.setAsideDropped`. Caches the game fills again (`chars`' sets, `reqs`, `cats`, `names`) drop what is wrong in them.
4. **Options hold only changes.** The defaults are read through a metatable, so Blizzard's settings panel, which writes a default into a missing key, writes nothing. At logout, an option back at its default is taken out. A default changed later then reaches every player who never touched that option.
5. **One sighting per place**, by `DB.PlaceKey`: the same NPC for vendors, trainers and loot, the same quest for rewards, one for the auction house and one for the bags. A kind a later version added uses its NPC, quest and first date. Two sightings of one place merge (`DB.MergeSighting`): the earliest first date, the latest last date, and the latest visit's fields, position and price (a visit that read no price keeps the one known). This is part of the format: changing it needs a step.
6. **Every deletion leaves a mark.** `/kr forget` records the time in `forgotten`. A copy then can't bring back what was seen before it, but the recipe is noted again if it's seen afterwards. Anything that deletes later must do the same, or the copies will undo it.
7. **No number the file can't hold.** At logout, nan and inf are taken out (counted in `meta.nonFinite`): written as `nan` or `inf`, they would make the whole file unreadable. A number is judged by how it prints, never by comparing it: the game's Lua compares nan as equal to everything (`/kr test` found it, 2026-11-10).
8. **A released step never changes.** Step n turns format n − 1 into n. A step reads nothing that may change later (`DEFAULTS`, `KINDS`): what it needs is written inside it, as step 2 holds version 1's defaults. A new format adds a step, a fixture in [Fixtures.lua](../addon/KaLiRecipe_Tests/Fixtures.lua) that is never edited afterwards, and a line in this page's history.

## Startup and logout

At `ADDON_LOADED`, `DB.Open` takes the account's notebook and this character's copy:
- **Both there:** the notebook opens, and the copy is merged in. Normally that adds nothing. If the account file is older, for example a `.bak` put back, the copy completes it.
- **The account file missing:** the copy becomes the notebook, and chat says so once, at login.
- **The account file started over after the copy was written:** the merge also takes the copy's options where the new notebook has none.
- **The copy unreadable** (from a newer version): the notebook opens from the account file, and the copy is left as it is, never written over.
- **Neither there:** a first run.

At `PLAYER_LOGOUT`, `DB.BeforeSave` takes out options at their default and any nan or inf, and stamps `meta.writer` and `meta.written`. Then `DB.Copy` gives this character's file a full copy, `{ owner, at, writer, data }`. It's a separate table: the game would write a shared one twice anyway.

## What this protects against, and what it doesn't

| Case | Result |
| --- | --- |
| The account file missing or unreadable | Back from the copy of the first character that logs in |
| The account file older than it should be (`.bak`) | Completed by each character's copy as it logs in |
| A broken entry in the file | Set aside, the rest opens |
| An addon from a later format | Refused, untouched; the addon stays off |
| Going back a version within a format | Nothing lost |
| A crash or Alt-F4 | That session's changes are lost: the game writes nothing |
| Every file lost at once | Only the game's `.bak`, put back with the game closed |
| A character's copy | As old as that character's last logout |

## Export and import, later

Not implemented. The pieces are here:
- An export carries the notebook as format 2 plus a header: format, addon version, date, `meta.id`.
- An import goes through `DB.Load`, so an old export upgrades itself and a newer one is refused, then `DB.Merge` merges it. Characters from another account just add up, since they're keyed by GUID.

Still to decide: what an import of another account's notebook brings, sightings only or characters too; how to say "this is your own notebook" (`meta.id`); and forgetting a character.

## How it's checked

- **The tests** ([Test_DB.lua](../addon/KaLiRecipe_Tests/Test_DB.lua), also run in game with `/kr test`) cover:
  - the first run, refusals, a failing step, setting aside, what a later version added, options at their default;
  - step 2, the format 1 fixture (Ikar's own file of 2026-11-10), every fixture opening twice with nothing changed;
  - writing and reading back as the game does (`T.Saved`, `T.ReadSaved`);
  - merging places, dates and prices, forgetting, characters, the copy, restore and refusal;
  - the cap on what is set aside.
- **The smoke test** checks that the options page writes no default, then fires a logout: the copy is written, and no option at its default stays.
- **The restart sessions** (`recipe/tools/run_tests.py`) start new Lua states from the files the smoke test wrote:
  - with both files, the notebook reads back exactly as it was;
  - without the account file, the copy brings it back and says so;
  - with a copy from a newer version, the copy is never written over.
- **Deliberate breaks:** each of the rules above was broken once, on a copy of the addon, and each break made a check fail.
- **The player's own files:** `python -I recipe/tools/read_saved.py check` opens them with the addon's own code and writes nothing. It shows what opening would upgrade, repair or set aside, whether the notebook writes back as it reads, and what each copy would add.
- **In game:** `/kr data` shows:
  - the format, the notebook's dates and last writer;
  - what it holds and what was kept from a later version;
  - what was set aside;
  - this character's copy;
  - the last events.

  The bug report includes the same.

## History of formats

| Format | Date | Version | Change |
| --- | --- | --- | --- |
| 1 | 2026-11-10 | 0.1.0-dev | Characters, sightings, options with their defaults, names, ranks, categories, the window |
| 2 | 2026-11-10 | 0.1.0-dev | Options hold only changes; `meta`, `forgotten`, `setAside`; the per-character copy |
