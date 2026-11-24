# KaLi Quest

**Sort your quests your way.** KaLi Quest redraws Blizzard's objective tracker around groups you make yourself: the quests you care about on top, the rest of your log neatly sorted below. For World of Warcraft Forever.

Install it and the tracker is there. Type `/kq options`, or open **Options > AddOns > KaLi Quest**, for the rest.

> **Beta:** every feature is in. If something doesn't work, `/kq report` gives you a ready-made bug report.

![KaLi Quest's tracker: four groups of your own under Track, the Journal folded below](https://github.com/Ikar-Rahl/Warcraft-KaLi/raw/main/quest/docs/images/01-your-groups.jpg)

---

## Your groups

- **Make your own groups** under the **Track** bar: name them, order them, open one and close the others.
- **A quest in a group is tracked by the game.** Everything else stays in the **Journal** below, sorted by zone and kind, whatever your client's language.
- **Drag and drop** a quest into a group, or a group or a Journal bar to reorder it. Drop a quest on the Track bar to start a new group.
- **Pick several quests** with Ctrl+click, then move, track or share them all at once.
- **Shift+click** tracks or untracks a quest: the game's tracking and your groups follow each other.
- **Past the game's 25 tracked quests**, a quest you placed by hand stays in its group, marked "Off list".
- **Deleted a group by mistake?** Undo it from the gear's menu.

![Three quests picked with Ctrl+click, to move them at once](https://github.com/Ikar-Rahl/Warcraft-KaLi/raw/main/quest/docs/images/02-several-quests-at-once.jpg)

## Find what you need

- **Search and filters:** ten kinds of filters (type, group size, repetition, state, difficulty, classification, story, account and faction, party, place), each choice with its count.
- **Markers** for dungeons, raids, PvP and more.
- **Quests in the area you're in** get a gold arrow; a group or a bar shows how many it holds.
- **A glow** on the quest that just progressed.

![The filter menu, each choice with its count](https://github.com/Ikar-Rahl/Warcraft-KaLi/raw/main/quest/docs/images/03-filters-with-counts.jpg)

## Out of your way

- **The padlock** freezes what's open and the order. A fight locks it until it ends.
- **Key bindings**, unbound at first: lock, collapse, next and previous group.
- **Edit Mode:** the tracker is a frame of its own, like Blizzard's. Drag it with snapping, keep a place for each layout, and set its size and look in one dialog, with a cancel.
- **Nothing lost:** quest items, popups, timers, tracked recipes and achievements show as in Blizzard's tracker.

![The tracker's Edit Mode dialog, beside the tracker](https://github.com/Ikar-Rahl/Warcraft-KaLi/raw/main/quest/docs/images/05-edit-mode.jpg)

## Safe with the game

- **Blizzard's tracker comes back by itself** if the addon meets an error, or if a tracker section it doesn't draw fills.
- **No taint:** Blizzard's tracker keeps its own size, so its updates never run tainted by the addon, in a fight or out of it.
- **Your data is kept safe:** groups are saved per character, and saved data the addon can't read, or that a newer version wrote, is left untouched.
- **Back to Blizzard's any time:** untick "KaLi Quest's tracker" in the options, or type `/kq tracker off`.
- **Nothing else to install:** no libraries, no dependencies.

## Compatibility

- **[Spoken](https://www.curseforge.com/wow/addons/spoken),** which reads quest dialogue and books aloud, works alongside KaLi Quest.
- **[Forever Quest Tint](https://www.curseforge.com/wow/addons/forever-quest-tint),** which marks the quests new to Forever, works alongside it too.

## Slash commands

| Command | What it does |
| --- | --- |
| `/kq` | Lists every command |
| `/kq options` | Opens the options |
| `/kq tracker on` / `off` | KaLi Quest's tracker, or Blizzard's |
| `/kq report` | Reports a bug |

The options' **Tips** page lists every shortcut, and what doesn't show at first glance.

## Questions

**Does it change the quest log or the map?**
No. KaLi Quest only draws the objective tracker. A click on a quest opens it on Blizzard's map.

**How do I move or resize the tracker?**
Open **Edit Mode** and click the tracker. The options page and the gear's menu have a button that opens Edit Mode with the tracker already picked.

**Are my groups shared between my characters?**
No, each character has its own groups.

**Why does a quest say "Off list"?**
The game tracks 25 quests at most. Past that, a quest you put in a group stays there, marked, instead of disappearing.

**How do I go back to Blizzard's tracker?**
Untick "KaLi Quest's tracker" in the options, or type `/kq tracker off`. Tick it again, or `/kq tracker on`, to come back.

## Languages

French, English, German and Spanish (Spain and Mexico), as your game client is set; other clients get English. Quest, place and character names come from the game itself. The German and Spanish texts are new: if a word reads wrong, tell us in a bug report.

## Install

The CurseForge app installs and updates it. By hand: put the `KaLiQuest` folder in `World of Warcraft\_forever_\Interface\AddOns`, then restart the game.

## Bugs and ideas

`/kq report`, or **Report a bug** at the bottom of the gear's menu, opens a window with a report of what the addon sees, to copy. It holds no character or realm name. Please say what you were doing and what happened.

- **With a GitHub account:** **Select the link**, copy it (Ctrl+C) and open it in your browser: a new issue opens, its questions in it. Then **Select the report**, copy it and paste it in. You can also open an issue directly: [github.com/Ikar-Rahl/Warcraft-KaLi/issues](https://github.com/Ikar-Rahl/Warcraft-KaLi/issues).
- **Without one, by mail:** click the address under the link, copy it, and write to [warcraft.kali.addons@gmail.com](mailto:warcraft.kali.addons@gmail.com) with the report pasted in. Within a few minutes your mail becomes an issue and you get its link: what you write is published there, your address never is. The answers come back to you by mail; reply to them to add to the issue.

Ideas and questions are welcome either way; by mail, say *idea* or *question* in the subject.

## Credits

KaLi Quest stands on other modders' work. What it owes each:

- **[Questie](https://www.curseforge.com/wow/addons/questie) by the Questie team**, TheCrux_BB, yttriumtyclief, Lawgon, muehedev and cheeq, and before them aerorocks99, Dyaxler and Drejjmit (GPLv3): their investigations of Forever, how saved data survives and which of its quest functions fail, which KaLi Quest's design leans on, and QuestieDB, which tested KaLi Quest while it was made. Nothing of Questie's is shipped.
- **[Kaliel's Tracker](https://www.curseforge.com/wow/addons/kaliels-tracker) by Kaliel:** the long-standing replacement tracker, the one KaLi Quest was measured against. The idea only: KaLi Quest's code is its own.

## Source and license

Open source under the MIT license: [github.com/Ikar-Rahl/Warcraft-KaLi](https://github.com/Ikar-Rahl/Warcraft-KaLi)
