# Working in this repository (AI agents)

The owner's time is what counts. Each minute they wait on a tool run is wasted. Work in seconds, not minutes.

## Rules

1. **Do only what changed.** Generators take names: run them on the new thing alone. A full rebuild only when a step
   they all share changed.
2. **Test the narrowest part that covers the change**, once:
   - code: `python -I hud/tools/run_tests.py --only static` (~20 s), then `--only smoke` (~1 min);
   - art or a data table only: `--only static`;
   - `--only blocks` (~10 min) only when the plate's layout code changed, in the background;
   - breaks: only the new or changed ones, `python -I tools/breaks.py tools/breaks/hud.py "<word>"`, in the
     background, on a snapshot copy (the run edits files). Each break is linked to a scenario (`"test:<name>"`, about
     1 s) or to the smoke block its link file keeps, never to the whole smoke (`"test:smoke"`, 37 s, run twice); a
     check no scenario makes goes into one. A change's breaks run in one pass (several words: a filtered copy of the
     breaks file under the same name, so its links apply), never one run per break;
   - the full suite once, at the end of a task, never after each step. A change's tests and breaks together stay under
     5 minutes (Ikar 2026-11-23: "Tests for an addon shoudl be 5min max total").
3. **Never sit waiting** on a run over a minute: start it in the background and go on, or report.
4. **Timebox.** A run that takes twice its usual time is stopped, not waited out. Time one piece alone, find the cause,
   fix it once. Never relaunch the same slow run to see whether it passes.
5. **Look once.** One check of a result, at the size it ships. No series of probes for a cosmetic doubt.
6. **No extra scope.** No refactor, feature or clean-up nobody asked for; one line in the report instead.
7. **Ask only when the answer changes what you do.** Otherwise take the obvious choice and say which.
8. **Report short:** what changed, what was checked, what wasn't (nothing is seen in game until the owner does), links
   to the files. No account of dead ends.
9. **Other sessions** may work in this tree: one message to them before editing `hud/tools` or the fakes; never two
   sessions on one file.

## Recipes

### Add or replace a minimap ring (~1 minute)

1. Copy the art to `hud/art/minimap/rings-N.jpeg` ("downloaded": the newest image in Downloads).
2. In `hud/tools/cut_rings.py`, `GRIDS`: `"rings-N": (1, 1, ["Name"])`. Its ground coloured (a rim of it round the
   cut-out): add it to `TINTED`. Its ring as dark as its ground: `CIRCLE`.
3. `python -I hud/tools/cut_rings.py rings-N` (~6 s); look once at `hud/bench/art/rings/rings-N-1.png`.
4. In `hud/tools/make_rings.py`, `THEMES`: `("<id>", "rings-N-1")` in its theme. To replace a ring, change its source
   and keep its id, so whoever chose it gets the new one.
5. `python -I hud/tools/make_rings.py <id>` (~8 s).
6. A new ring: `RING_<id>` in each language's file, `hud/addon/KaLiHUD/Locale/frFR.lua`, `enUS.lua`, `deDE.lua` and
   `esES.lua` (one language a file since 2026-11-21).
7. `--only static`, then `--only smoke`.
8. One line in `hud/docs/design.md` (Minimap) and in the changelog.

### Regenerate a data table

`hud/tools/make_effects.py`, `make_zones.py`, `make_fishing.py`: run it, then `--only static`, which checks the file
against its generator.
