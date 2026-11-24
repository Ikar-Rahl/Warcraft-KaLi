# KaLi

Addons for World of Warcraft Forever, by Ikar. French first, then English, German and Spanish.

| Addon | What it does | Folder |
| --- | --- | --- |
| **KaLi Quest** | Your own quest groups, in a rewritten objective tracker | [quest/](quest/README.md) |
| **KaLi Recipe** | A notebook of the recipes you come across, without spoiling the ones you haven't met | [recipe/](recipe/README.md) |
| **KaLi HUD** | Adaptable base plate, with minimap, collapsible panels and info bar | [hud/](hud/README.md) |

To install one, copy its folder from `quest/addon/`, `recipe/addon/` or `hud/addon/` (`KaLiQuest`, `KaLiRecipe`,
`KaLiHUD`) into the game's `Interface\AddOns`. The `_Tests` and `_Probe` folders are for development; players don't
need them.

Found a bug? Each addon's `/kq report`, `/kr report` or `/kh report` window gives a link to copy: opened in a browser,
it's a [new issue](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new) whose title says which addon it's from, with
a question about what happened; then copy the report from the same window and paste it in. Without a GitHub account,
the same window gives KaLi's address, [warcraft.kali.addons@gmail.com](mailto:warcraft.kali.addons@gmail.com): a mail
with the report becomes an issue, without the sender's address, and the answers go back by mail
([tools/mail](tools/mail/README.md)).

## Layout

| Path | What it is |
| --- | --- |
| `quest/`, `recipe/`, `hud/` | One addon each: `addon/` (the addon, its in-game tests, its probe), `docs/` (its design record), `bench/` (a page to try its look without the game), `tools/` (its test runner, generators, saved-file reader) |
| `shared/` | The code the addons share: the event core, the debug log, the API check, the bug report, the slash command dispatcher, the settings window, the options page, and the in-game test harness. See [shared/README.md](shared/README.md) |
| `tools/` | What the family's development shares: one command for every check, the fake game the Lua runs on, the offline checks, the shared code's copier, the deliberate-break harness, and the links into the game |

## Developing

Needs Python 3.13, and Lua 5.1 through lupa, installed locally:
`python -I -m pip install --target tools/pylib lupa`. Run every tool from the repository's root with `python -I`.

- **Every check:** `python -I tools/run_tests.py` must end in `ALL PASS` before a commit. It checks the shared code's
  copies, then runs each addon's runner: compile, API names against this build's documentation, globals, the package,
  values the game may hide read through `ns.Plain`, the in-game tests on Lua 5.1, a smoke test that plays a whole
  session on the fake game, the shared code's own checks on each addon's copy, and every text of the dialogs and the
  options pages measured against the room it has, in each language (with the game's font from a bench's art folder;
  without it that check says so and passes). `quest`, `recipe` or `hud` runs one addon; `--write-needs` updates the
  lists of what each addon takes from the game.
- **The shared code:** edit `shared/`, never an addon's `Shared/` copy, then `python -I tools/sync_shared.py`.
- **Deliberate breaks:** `python -I tools/breaks.py <file>` plants one fault at a time in a copy of the code and checks
  the tests fail; `tools/breaks/shared.py` holds the shared code's, `quest.py`, `recipe.py` and `hud.py` each addon's
  own. A fix isn't proven until its break is caught. `tools/run_tests.py` checks each time that every break still
  applies to the code as it is, without running any.
- **The game is the ground truth:** the fake game gives this build's own answers where its files hold them, but only
  the game says what it really answers. Each addon's API check keeps what it found at login, per build, in the game's
  saved `<Addon>DevDB` (`apiChecks`, and in its `told` what didn't hold when it said so in chat), with its errors, what
  the game blocked (`gameWarnings`) and the last in-game test run (`lastTests`); read them there. An answer the fake
  invented has hidden a defect each time: when the game's records or Blizzard's source say otherwise, the fake changes
  first, then the code.
- **In the game:** `tools\link_addons.cmd` links the nine folders into `Interface\AddOns` (`unlink`, `relink`). Edits
  then show after `/reload`.

The tools read Blizzard's UI source and tables, and QuestieDB, from a `reference/` folder beside the repository; set
`KALI_REFERENCE` to put it elsewhere, and `KALI_GAME` for the game's folder.

**Never published:** Blizzard's art, sounds and font, the screenshots as taken (the CurseForge pages' pictures,
prepared, are in each addon's `docs/images/`), and data built from QuestieDB (GPL-3.0). The
benches' scripts make them locally, into folders `.gitignore` keeps out. Nor are the images KaLi HUD's cartouches and
minimap rings are cut from (`hud/art/`, generated with Google Gemini): the addon ships the pieces.

## Publishing

Each addon is published from a tag of its own (Ikar 2026-11-24: "One tag per addon. Automated publishing."):

1. Its TOC's `## Version` raised, a `## <version> (<date>)` section on top of its `CHANGELOG.md`, and
   `python -I tools/run_tests.py <addon>` ending in `ALL PASS`: GitHub can't run the tests, they read the local
   reference copies. Committed and pushed.
2. `python -I tools/release.py quest-0.9.1 --dry-run`: the tag's run without uploading anything (the zip, the
   changelog it sends, what stays by hand). "Run workflow" on the repository's Actions page does the same on GitHub,
   and tries the CurseForge token there.
3. `git tag quest-0.9.1`, then `git push origin quest-0.9.1` (`recipe-…`, `hud-…`): the
   [Publish](.github/workflows/release.yml) run checks the tag against the TOC and the changelog, checks the package,
   builds the zip, makes the GitHub release with it, then uploads it to CurseForge with the version's changelog. Each
   addon's files go up as betas until `RELEASE_TYPE` in [tools/release.py](tools/release.py) says `release` (Ikar: "We
   stay in beta for a while, but I think I will mark it released when the presentation is good in curseforge").

By hand on CurseForge, as no API reaches them (Ikar: "desc and image by hands"), and the run's summary says when: the
description, the addon's `README.md` pasted in the editor's Markdown mode, when it changed; the Gallery's pictures,
downloaded from the addon's `docs/images/`, where `python -I tools/gallery.py <addon>` writes them from the
screenshots prepared in `release/<Addon>-<version>/gallery/` beside the repository. The CurseForge token is the
repository's secret `CF_API_TOKEN`, made on authors.curseforge.com. How each page is filled:
`<addon>/docs/curseforge/README.md`.

## Licence

MIT, see [LICENSE](LICENSE). KaLi HUD's own [LICENSE](hud/addon/KaLiHUD/LICENSE) adds FlareUI's notice, for the code
adapted from it, and says where its art comes from.
