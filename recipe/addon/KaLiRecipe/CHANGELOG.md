# Changelog

## 0.9.1 (2026-11-24)

- **No GitHub account?** The bug report's window gives KaLi's mail address under the GitHub link; a click selects it, to copy. A mail with the report becomes an issue, published without your address: you get its link, and the answers come back by mail, in your language. Once the report is copied, the window says to paste it into the issue or into your mail.
- **Report a bug** on KaLi Recipe's page in the game's options (**Options > AddOns > KaLi Recipe**), under the button to its own options.
- The description: « Bugs and ideas » gives both ways to report, and « Compatibility » names Auctionator, Baganator and Titan Panel.

## 0.9.0 (2026-11-23)

First public beta: every feature is in.

### Noted where you meet them

- Recipes noted at vendors, trainers, the auction house, on loot, as quest rewards and on arriving in the bags; one chat line per visit.
- A sound when a visit notes a recipe new to the notebook, the quest log's quill, and a shorter one for a new place of a recipe already in it, the same quill stopped early: the game's own sounds, one per visit, each chosen in the options (with two parchments) or turned off. **Sound volume** sets both, from 0 to 300% of the game's own level for them, 200% by default; the game's own volumes still apply.
- The vendor's and the trainer's price for each recipe, kept with where it was seen and shown in the detail and the recipe's tooltip; the trainer's has its own option.
- A gray clock after a vendor's name when its stock of the recipe was limited, wherever the name shows.
- Hovering a vendor says whether you opened it: "visited" with how many recipes were seen there (white) or none (gray), the friend icon when only another of your characters did, "vendor never visited" in green where the game's icon shows it sells. Another character's visits count with **On another character**.
- Quest rewards as the other places: noted on the quest's offer, before you accept it, with the quest giver and where they stand (a map pin and a waypoint); read again when the game sends a reward's details late, and read from the quests already in your log. Their own chat line and sound. The game's yellow "!" for a quest offered starts each line that names the quest, and is their pin on the map.
- What each character knows (the professions window, the trainer, the spellbook, a recipe's "Already known") and holds (bags and bank), shared by all your characters.

### The notebook

- "Notebook: N to learn · N seen" in the professions window and the professions book.
- The notebook: three sections by the game's categories, search and filters, the recipe's detail below the list, two styles with each profession's art, a corner grip to resize it, **Follow the professions window** docking it on the professions window, profession tabs.

### Marks and tooltips

- Marks at vendors and in bags (and Baganator's); crafted items' profession icon. None on the auction house's rows, Blizzard's or Auctionator's: there the recipe's tooltip says it all, and the addon searches only when **Note the recipes** is clicked, never by itself.
- Tooltip lines for recipes, reagents and crafted items.

### On the map

- World map pins and waypoints.

### Options and buttons

- Options in a window of their own, in the notebook's **Clean** look, beside the notebook, which stays open as they're set: folding sections, **Revert Changes** and **Defaults**. The notebook's gear opens it; the game's settings have a button to it.
- The addon compartment; a minimap button, which can be hidden or locked; a launcher for information bars such as Titan Panel; `/kr`.
- Its own icon, in KaLi Quest's black and gold: a K and a split feather.

### Your data

- Saved data that survives: each character's file keeps a copy of the notebook, which brings it back if the account's file goes missing; nothing a later version adds is lost, and nothing unreadable is deleted, only set aside; options keep only what you changed. `/kr data` shows its state.

### Bug reports

- **Report a bug**, from the notebook's gear, the options or `/kr report`: a link that opens a new issue, then the report to copy and paste into it; with a check at login that the game still has everything the addon uses and answers as it expects. When it doesn't, a line in chat says so, once per game version, and the report keeps what it found.

### Languages

- French, English, German and Spanish (Spain's, and Mexico's with the game's own Mexican words); other clients get English.
- Switch the game's language and the notebook still names the vendors, trainers and creatures you met: in the language you met them in, until you meet them again.
- Each language reviewed:
  - The game's own words where the game has them: in the French filter, a trainer is « Maîtres de métier », as the game says.
  - The options button's tip says which window it opens.
  - English spells as the game does.
  - Each language's own typography: French's no-break spaces before : ; ? !, its ’ and « »; English “ ”; German „ “; Spanish « » and ¿ ¡. The chat lines' colon follows your language.
  - The mouse buttons are drawn as the house editor's icons in the hints and the tips.
  - One language to a file, under `Locale/`.
