# KaLi

Addons for World of Warcraft Forever, by Ikar. French first, then English, German and Spanish.

| Addon | What it does | Folder |
| --- | --- | --- |
| **KaLi Quest** | Your own quest groups, in a rewritten objective tracker | [quest/](quest/README.md) |
| **KaLi Recipe** | A notebook of the recipes you come across, without spoiling the ones you haven't met | [recipe/](recipe/README.md) |

To install one, copy its folder from `quest/addon/` or `recipe/addon/` (`KaLiQuest`, `KaLiRecipe`) into the game's
`Interface\AddOns`. The `_Tests` and `_Probe` folders are for development; players don't need them.

Found a bug? Each addon's `/kq report` or `/kr report` gives a link to copy: opened in a browser, it's a
[new issue](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new) whose title says which addon it's from, with a
question about what happened. Then copy the report from the same window and paste it in.

## Layout

| Path | What it is |
| --- | --- |
| `quest/`, `recipe/` | One addon each: `addon/` (the addon, its in-game tests, its probe), `docs/` (its design record), `bench/` (a page to try its look without the game), `tools/` (its test runner, generators, saved-file reader) |
| `shared/` | The code both addons share: the event core, the debug log, the API check, the bug report, the slash command dispatcher, and the in-game test harness. See [shared/README.md](shared/README.md) |
| `tools/` | What the family's development shares: one command for every check, the fake game the Lua runs on, the offline checks, the shared code's copier, the deliberate-break harness, and the links into the game |

## Developing

Needs Python 3.13, and Lua 5.1 through lupa, installed locally:
`python -I -m pip install --target tools/pylib lupa`. Run every tool from the repository's root with `python -I`.

- **Every check:** `python -I tools/run_tests.py` must end in `ALL PASS` before a commit. It checks the shared code's
  copies, then runs each addon's runner: compile, API names against this build's documentation, globals, the package,
  the in-game tests on Lua 5.1, a smoke test that plays a whole session on the fake game, and the shared code's own
  checks on each addon's copy. `quest` or `recipe` runs one addon; `--write-needs` updates the lists of what each
  addon takes from the game.
- **The shared code:** edit `shared/`, never an addon's `Shared/` copy, then `python -I tools/sync_shared.py`.
- **Deliberate breaks:** `python -I tools/breaks.py <file>` plants one fault at a time in a copy of the code and checks
  the tests fail; `tools/breaks/shared.py` holds the shared code's, `quest.py` and `recipe.py` each addon's own.
- **The game is the ground truth:** the fake game gives this build's own answers where its files hold them, but only
  the game says what it really answers. Each addon's API check keeps what it found at login, per build, in the game's
  saved `<Addon>DevDB` (`apiChecks`), with its errors and the last in-game test run (`lastTests`); read them there.
- **In the game:** `tools\link_addons.cmd` links the six folders into `Interface\AddOns` (`unlink`, `relink`). Edits
  then show after `/reload`.

The tools read Blizzard's UI source and tables, and QuestieDB, from a `reference/` folder beside the repository; set
`KALI_REFERENCE` to put it elsewhere, and `KALI_GAME` for the game's folder.

**Never published:** Blizzard's art, sounds and font, the screenshots, and data built from QuestieDB (GPL-3.0). The
benches' scripts make them locally, into folders `.gitignore` keeps out.

## Licence

MIT, see [LICENSE](LICENSE).
