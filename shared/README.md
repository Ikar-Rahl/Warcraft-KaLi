# The shared code

What both KaLi addons run the same way. Each addon carries its own copy, in its `Shared/` folder, loaded in its own
namespace: a player never needs a third addon, and one addon's copy can't break the other. The copies are committed,
so what is tested is what ships.

| Source | Copied to | What it is |
| --- | --- | --- |
| `addon/Core.lua` | `<Addon>/Shared/` | Events (`ns.On`, `ns.Off`), guarded calls (`ns.SafeCall`, `ns.Call`), work once per frame (`ns.Later`), chat (`ns.Say`) |
| `addon/Debug.lua` | `<Addon>/Shared/` | The debug log, error capture, event tracing, and a window to copy text from, in `<Addon>DevDB` |
| `addon/SelfCheck.lua` | `<Addon>/Shared/` | The API check: what the addon takes from the game (its `Data/Needs.lua`) and what it assumes, at login and in each report |
| `addon/Report.lua` | `<Addon>/Shared/` | The bug report and its window |
| `addon/Commands.lua` | `<Addon>/Shared/` | The slash command dispatcher, and the commands for debugging: `debug`, `log`, `errors`, `clear`, `test`, `report` |
| `tests/Harness.lua` | `<Addon>_Tests/Shared/` | The in-game test harness, `<Addon>Tests` |

## What an addon gives it

- `Core/Init.lua`, loaded first: `ns.TITLE`, `ns.SHORT` (the debug log's chat prefix), `ns.SLASH`, and `<Addon>Dev`.
- Its locale defines every `L.` string the shared code uses; `tools/run_tests.py` checks it.
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
   checks both addons' tests catch each break.

What stays each addon's own: its saved data and how it loads it, its start-up, its options page, its widgets, and its
probe.
