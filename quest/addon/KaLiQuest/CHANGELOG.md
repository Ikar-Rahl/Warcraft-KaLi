# Changelog

## 0.9.1 (2026-11-24)

- **No GitHub account?** The bug report's window gives KaLi's mail address under the GitHub link; a click selects it, to copy. A mail with the report becomes an issue, published without your address: you get its link, and the answers come back by mail, in your language. Once the report is copied, the window says to paste it into the issue or into your mail.
- The options page no longer has a diagnostics button: **Report a bug** is what you need there.
- The description: « Bugs and ideas » gives both ways to report, « Compatibility » names Spoken and Forever Quest Tint, and « Credits » honors the modders KaLi Quest owes, Questie's team and Kaliel.

## 0.9.0 (2026-11-23)

First public beta: every feature is in.

### Your groups

- A rewritten objective tracker: **Track** holds your own groups, the **Journal** the rest of your log, by category.
- Groups: create, rename, delete with undo, reorder, open one and close the others.
- Drag and drop for quests, groups and the Journal's bars; Ctrl+click acts on several quests at once.
- Shift+click tracks or untracks a quest; the game's tracking and your groups follow each other. Holding Shift or Ctrl over a quest says what a click will do.
- The Journal sorts your log's headers by their IDs, so the same way in any client language, and remembers which are open the same way.

### Find what you need

- Search and filters; markers; the quests of the area you're in; a glow on progress.

### Out of your way

- A padlock, locked by combat; four key bindings.
- Quest items, popups, timers, tracked recipes and achievements, as in Blizzard's tracker.
- Options in **Options > AddOns > KaLi Quest**, on a page of the addon's own: the tracker's switch, automatic tracking and its reset, and a **Tips** page under it. Also in the addon compartment, and with `/kq`.
- In **Edit Mode** the tracker is a frame of its own, as Blizzard's frames are: picked, dragged with snapping or moved with the arrow keys, with a place for each layout. One dialog holds all of its size and look, in folding sections, with **Revert Changes**, **Reset To Default Position** and **Defaults**. Its zoom alone sizes it, and its background's opacity is its own. Its size and look are set there only; the options page keeps the rest, with an **Edit Mode** button that opens Edit Mode with the tracker picked, as the gear's menu does.

### Safe with the game

- Blizzard's tracker comes back on an error, or when a section the addon doesn't draw fills.
- Blizzard's tracker keeps its own size, so its updates never run tainted by the addon, in a fight or out of one. KaLi Quest's tracker grows from the corner Blizzard's is held by.

### Bug reports

- **Report a bug** in the gear's menu, or `/kq report`: a link that opens a new issue, then the report to copy and paste into it, with a check that the game still has everything the addon uses and still answers as the addon expects. When it doesn't, a line in chat says so, once per game version, and the report keeps what it found.

### Languages

- French, English, German and Spanish (Spain's, and Mexico's with the game's own Mexican words); other clients get English.
- Each language reviewed:
  - The game's own words where the game has them: German calls the tracker « Questverfolgung » and Blizzard's « Questzielverfolgung », as the game does; French says « Recettes » for tracked recipes in the diagnostics; Spanish says « Recuadro » for the quest boxes' opacity.
  - The tips quote the menus they name.
  - Each language's own typography: French's no-break spaces before : ; ? !, its ’ and « »; English “ ”; German „ “; Spanish « » and ¿ ¡. The chat lines' colon follows your language.
  - The mouse buttons are drawn as the house editor's icons in the hints and the tips.
  - One language to a file, under `Locale/`.
