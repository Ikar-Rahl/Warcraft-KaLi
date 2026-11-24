# The shared code

What the three KaLi addons run the same way. Each addon carries its own copy, in its `Shared/` folder, loaded in its
own namespace: a player never needs a fourth addon, and one addon's copy can't break another. The copies are
committed, so what is tested is what ships.

| Source | Copied to | What it is |
| --- | --- | --- |
| `addon/Core.lua` | `<Addon>/Shared/` | Events (`ns.On`, `ns.Off`: an event the client no longer has, or refuses, doesn't stop the function that registers it, and is listed by `ns.MissingEvents`, which the API check names), guarded calls (`ns.SafeCall`, `ns.Call`), a handler run every frame that stops at its first error (`ns.EveryFrame`), work once per frame (`ns.Later`), chat (`ns.Say`), the fight from its first moment (`ns.InCombat`: the game's lockdown starts just after `PLAYER_REGEN_DISABLED`, so what is drawn as a fight starts asks this, and what an addon may do asks `InCombatLockdown`), the click refused in a fight with the game's own line (`ns.CombatRefused`), a value the game may hide read as nil (`ns.Plain`: comparing a secret value, or joining it to text, is an error), and saved data's helpers: a number a file can hold (`ns.Finite`: the game's Lua compares nan as equal to itself, so never `v ~= v`), a copy all the way down (`ns.DeepCopy`), a count of keys (`ns.Count`), and the sweep before saving that takes out every nan and inf (`ns.DropNonFinite`) |
| `addon/Debug.lua` | `<Addon>/Shared/` | The debug log, error capture, event tracing (a hidden value named, never read), a window to copy text from, in `<Addon>DevDB`, swept of nan and inf at logout; and a window dragged by its body that leaves nothing in the game's own layout file (`ns.Movable`) |
| `addon/SelfCheck.lua` | `<Addon>/Shared/` | The API check: what the addon takes from the game (its `Data/Needs.lua`), what it assumes, and each event the game refused it, at login and in each report, with what didn't hold when it said so in chat kept in the build's entry (`told`); and what the game blocked or forbade the addon, kept in `<Addon>DevDB.gameWarnings` |
| `addon/Report.lua` | `<Addon>/Shared/` | The bug report and its window: a link that opens a new issue (`Report.Link`), KaLi's mail address for a player without a GitHub account (`Report.MAIL`, [tools/mail](../tools/mail/README.md)), then the report to copy and paste into it |
| `addon/Commands.lua` | `<Addon>/Shared/` | The slash command dispatcher, and the commands for debugging: `debug`, `log`, `errors`, `clear`, `test` (its result kept with the game's build), `report` |
| `addon/Dialog.lua` | `<Addon>/Shared/` | A settings window (`ns.Dialog.New`) in the look of Blizzard's Edit Mode dialog, or of a game window as KaLi Recipe's notebook « Épuré » (`look = "window"`): folding sections, one open at a time; slider, check box, dropdown and button rows, their label 100 wide and two lines as Blizzard's (a word too long for it is broken by hand, as Blizzard's German: `"Fortschritts-\nleisten"`, whole again in the row's tooltip); « Annuler les modifications » to the last snapshot and « Par défaut ». KaLi Quest's and KaLi HUD's dialogs in Edit Mode and KaLi Recipe's options window; each addon gives the rows, where values live and what follows a change |
| `addon/Page.lua` | `<Addon>/Shared/` | The addon's page in the game's options, under AddOns (`ns.Page.New`): a frame of the addon's own, laid out as Blizzard's pages at their sizes, with a title, section headings, and rows with the game's check box or button. Never Blizzard's own list of settings: what an addon puts there, the game's pages and its search then work with, and the game blames the addon for what they do (2026-11-12, KaLi Quest named for the Social page's Discord rows) |
| `tests/Harness.lua` | `<Addon>_Tests/Shared/` | The in-game test harness, `<Addon>Tests` |
| `tests/Locales.lua` | `<Addon>_Tests/Shared/` | Every language the addon speaks holds each English string, with English's blanks (`%s`, `%d`) in English's order; a client language picks its own, Mexican Spanish Castilian's but for its own words, any other English's; each language follows its own typography (French's no-break spaces and « », English “ ”, German „ “, Spanish « » and ¿ ¡) |

## What an addon gives it

- `Core/Init.lua`, loaded first: `ns.TITLE`, `ns.SHORT` (the debug log's chat prefix), `ns.SLASH`, and `<Addon>Dev`.
- Its locale defines every `L.` string the shared code uses, and `ns.G`, the game's own strings; `tools/run_tests.py`
  checks the first. It also gives `ns.STRINGS` (every language's table), `ns.StringsFor(locale)` and `ns.One(n)` (the
  singular), which `tests/Locales.lua` holds. Since 2026-11-21 its locale is `Core/Locale.lua`, the machinery, loaded
  first, and one file a language, `Locale/<language>.lua`, each putting in its own typography with `ns.Typeset`; the
  chat lines' colon is the game's own in the player's language (`ns.Colon`, `HEADER_COLON`).
- `Core/SelfCheck.lua` adds its assumptions with `SelfCheck.Add`, and may set `SelfCheck.AfterLogin` and
  `SelfCheck.OnBlocked`.
- `UI/Report.lua` sets `Report.URL`, `Report.MAIL`, `Report.StatusLines` and `Report.Sections`.
- `Core/Commands.lua` adds its commands with `Commands.Add`, sets `ns.Commands.StatusText`, then calls
  `Commands.Register`.
- `UI/Options.lua` gives `ns.Page.New` the page's rows, and calls the page's `Refresh` when an option it shows changes
  elsewhere.

## Changing it

1. Edit the source here.
2. `python -I tools/sync_shared.py` writes the copies.
3. `python -I tools/run_tests.py` runs the three addons' tests on it: a change here is a change to each addon. Its own
   checks are `tools/lua/smoke_shared.lua`, which each addon's runner plays on that addon's copy after its smoke
   session.
4. A fix worth keeping proven goes in `tools/breaks/shared.py`; `python -I tools/breaks.py tools/breaks/shared.py`
   checks every addon's tests catch each break (a break names the addons where it changes anything, when it isn't
   all three). Each addon's own fixes have theirs, `tools/breaks/quest.py`, `recipe.py` and `hud.py`.

The dialog and the options page draw their texts in rooms of Blizzard's sizes, where the game cuts what doesn't fit:
`tools/kali/labels.py` measures each text an addon gives them, in every language it speaks, with the game's own font
(each runner's "labels:" line). A label is about 13 letters a line, two lines; an options row's name one line of 195.

The fake game the tests run on (`tools/lua/fakewow.lua`) gives this build's own answer wherever its files hold one:
Forever's modified clicks from its `Bindings_Camelot.xml`, the constants where Blizzard's own Forever code reads them.
Each answer it invented instead once hid a defect that only the player's game showed: a false alarm (2026-11-11),
then, in the review of 2026-11-16, a quest already tracked answered as added, a selection box without Blizzard's own
scripts, a map that never made its protected call, a fight whose lockdown started with its event, and no secret
values. It answers as the game does on each now; what the game blocks in a fight is listed in `FakeWoW.blocked`.

What stays each addon's own: its saved data and how it loads it, its start-up, its options and what they hold, its widgets, and its
probe.
