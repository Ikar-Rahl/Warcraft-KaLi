# The shared code

What both KaLi addons run the same way. Each addon carries its own copy, in its `Shared/` folder, loaded in its own
namespace: a player never needs a third addon, and one addon's copy can't break the other. The copies are committed,
so what is tested is what ships.

| Source | Copied to | What it is |
| --- | --- | --- |
| `addon/Core.lua` | `<Addon>/Shared/` | Events (`ns.On`, `ns.Off`), guarded calls (`ns.SafeCall`, `ns.Call`), work once per frame (`ns.Later`), chat (`ns.Say`), the click refused in a fight with the game's own line (`ns.CombatRefused`), and saved data's helpers: a number a file can hold (`ns.Finite`: the game's Lua compares nan as equal to itself, so never `v ~= v`), a copy all the way down (`ns.DeepCopy`), a count of keys (`ns.Count`), and the sweep before saving that takes out every nan and inf (`ns.DropNonFinite`) |
| `addon/Debug.lua` | `<Addon>/Shared/` | The debug log, error capture, event tracing, and a window to copy text from, in `<Addon>DevDB`, swept of nan and inf at logout |
| `addon/SelfCheck.lua` | `<Addon>/Shared/` | The API check: what the addon takes from the game (its `Data/Needs.lua`) and what it assumes, at login and in each report |
| `addon/Report.lua` | `<Addon>/Shared/` | The bug report and its window: a link that opens a new issue (`Report.Link`), then the report to copy and paste into it |
| `addon/Commands.lua` | `<Addon>/Shared/` | The slash command dispatcher, and the commands for debugging: `debug`, `log`, `errors`, `clear`, `test`, `report` |
| `addon/Dialog.lua` | `<Addon>/Shared/` | A settings window (`ns.Dialog.New`) in the look of Blizzard's Edit Mode dialog, or of a game window as KaLi Recipe's notebook « Épuré » (`look = "window"`): folding sections, one open at a time; slider, check box, dropdown and button rows; « Annuler les modifications » to the last snapshot and « Par défaut ». KaLi Quest's dialog in Edit Mode and KaLi Recipe's options window, since 2026-11-13; each addon gives the rows, where values live and what follows a change |
| `tests/Harness.lua` | `<Addon>_Tests/Shared/` | The in-game test harness, `<Addon>Tests` |
| `tests/Locales.lua` | `<Addon>_Tests/Shared/` | Every language the addon speaks holds each English string, with English's blanks (`%s`, `%d`) in English's order; a client language picks its own, Mexican Spanish Castilian's but for its own words, any other English's |

## What an addon gives it

- `Core/Init.lua`, loaded first: `ns.TITLE`, `ns.SHORT` (the debug log's chat prefix), `ns.SLASH`, and `<Addon>Dev`.
- Its locale defines every `L.` string the shared code uses, and `ns.G`, the game's own strings; `tools/run_tests.py`
  checks the first. It also gives `ns.STRINGS` (every language's table), `ns.StringsFor(locale)` and `ns.One(n)` (the
  singular), which `tests/Locales.lua` holds.
- `Core/SelfCheck.lua` adds its assumptions with `SelfCheck.Add`, and may set `SelfCheck.AfterLogin` and
  `SelfCheck.OnBlocked`.
- `UI/Report.lua` sets `Report.URL`, `Report.StatusLines` and `Report.Sections`.
- `Core/Commands.lua` adds its commands with `Commands.Add`, sets `ns.Commands.StatusText`, then calls
  `Commands.Register`.

## Changing it

1. Edit the source here.
2. `python -I tools/sync_shared.py` writes the copies.
3. `python -I tools/run_tests.py` runs both addons' tests on it: a change here is a change to both addons. Its own
   checks are `tools/lua/smoke_shared.lua`, which each addon's runner plays on that addon's copy after its smoke
   session.
4. A fix worth keeping proven goes in `tools/breaks/shared.py`; `python -I tools/breaks.py tools/breaks/shared.py`
   checks both addons' tests catch each break. Each addon's own fixes have theirs, `tools/breaks/quest.py` and
   `tools/breaks/recipe.py`.

The fake game the tests run on (`tools/lua/fakewow.lua`) gives this build's own answer wherever its files hold one:
Forever's modified clicks from its `Bindings_Camelot.xml`, the constants where Blizzard's own Forever code reads them.
Each answer it invented instead once hid a false alarm that only the player's game showed (2026-11-11).

What stays each addon's own: its saved data and how it loads it, its start-up, its options and what they hold, its widgets, and its
probe.
