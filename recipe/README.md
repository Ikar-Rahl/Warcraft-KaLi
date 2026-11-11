# KaLi Recipe

A notebook of the recipes you come across, for World of Warcraft Forever, without spoiling the ones you haven't met.

- `addon/KaLiRecipe`: the addon. Its [README](addon/KaLiRecipe/README.md) says what it does and how to install it.
- `addon/KaLiRecipe_Tests`: its in-game tests, run with `/kr test`. Players don't need it.
- `addon/KaLiRecipe_Probe`: the in-game probe, for development only (`/krprobe`). Not shipped.
- `docs/`: the design record ([design.md](docs/design.md)) and the saved data's rules ([saved-data.md](docs/saved-data.md)).
- `bench/`: the addon's display in a browser, with the sounds on offer and the icon's candidates
  ([README](bench/README.md)).
- `tools/`: its test runner (`run_tests.py`), the data generator, the bench's generators, the saved-file reader.

Found a bug? `/kr report` gives a report to copy into a [new issue](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues/new).

MIT licence, see [LICENSE](../LICENSE).
