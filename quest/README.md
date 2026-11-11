# KaLi Quest

Your own quest groups, in a rewritten objective tracker, for World of Warcraft Forever.

- `addon/KaLiQuest`: the addon. Its [README](addon/KaLiQuest/README.md) says what it does and how to install it.
- `addon/KaLiQuest_Tests`: its in-game tests, run with `/kq test`. Players don't need it.
- `addon/KaLiQuest_Probe`: the in-game probe, for development only (`/kqprobe`). Not shipped.
- `docs/`: the design record; [organiser-design.md](docs/organiser-design.md) is the plan.
- `bench/`: the tracker beside Blizzard's, in a browser, to polish its look without the game
  ([README](bench/README.md)).
- `tools/`: its test runner (`run_tests.py`), the data generators, the icon maker, the saved-file reader, and the
  location research of 2026-11-06 (`research/`).

Found a bug? **Signaler un bug (Report a bug)**, the last line of the tracker's gear menu, or `/kq report`, gives a
report to copy into a [new issue](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new).

MIT licence, see [LICENSE](../LICENSE).
