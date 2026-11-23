# KaLi HUD

A bronze base along the bottom of the screen for Blizzard's action bars, the minimap, the chat and the damage meter, with an info bar at its foot, for World of Warcraft Forever.

- `addon/KaLiHUD`: the addon. Its [README](addon/KaLiHUD/README.md) says what it does and how to install it.
- `addon/KaLiHUD_Tests`: its in-game tests, run with `/kh test`. Players don't need it.
- `addon/KaLiHUD_Probe`: the in-game probe, for development only (`/khprobe`). Not shipped.
- `docs/`: the design record, [design.md](docs/design.md); the [review of 2026-11-17](docs/review-2026-11-17.md): its defects (fixed but one), its proposals and what players write about such addons; and the [review of 2026-11-18](docs/review-2026-11-18.md), of the code's stability, solidity and maintainability.
- `bench/`: the border, the cartouches and the addon's icon (`icons.html`) in a browser, to settle their look without the game. Its art (`bench/art/`) is Blizzard's and stays local. `tools/make_icon.py <id>` makes one of the icons the addon's.
- `tools/`: its test runner (`run_tests.py`; `--only <part>` runs one part of it: `static`, `tests`, `smoke`, `alone`, `scenarios` or a scenario's name), its scenarios (`lua/scenarios/`, each a short session from a game of its own), the makers of its media, icons and cartouches, and the benches' scripts.
- `art/`: the sheets the cartouches and the minimap rings are cut from, images Ikar generated with Google Gemini. Local, not published (`.gitignore`).

Found a bug? `/kh report` gives a report to copy into a [new issue](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new).

MIT licence, see [LICENSE](../LICENSE).
